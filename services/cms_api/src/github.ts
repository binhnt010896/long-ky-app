import type { Env } from './types';

export class GitHubApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

/** `main` moved between the CMS loading its draft and saving it. The caller
 * (index.ts) turns this into an HTTP 409 — the CMS then reloads and shows
 * the reader what changed, rather than silently overwriting it. */
export class ConflictError extends Error {}

/** Injectable so tests can supply canned GitHub API responses instead of a
 * real network call — every function below takes this as its last
 * parameter, defaulting to the real `fetch`. */
export type FetchFn = typeof fetch;

async function ghFetch(
  env: Env,
  path: string,
  init: { method?: string; body?: unknown } = {},
  fetchFn: FetchFn = fetch,
): Promise<unknown> {
  const res = await fetchFn(`https://api.github.com${path}`, {
    method: init.method ?? 'GET',
    headers: {
      Authorization: `Bearer ${env.GITHUB_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'long-ky-cms-worker',
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: init.body ? JSON.stringify(init.body) : undefined,
  });
  if (!res.ok) {
    throw new GitHubApiError(`GitHub API ${init.method ?? 'GET'} ${path} → ${res.status}`, res.status);
  }
  // 204 No Content (e.g. a successful ref update) has no body to parse.
  if (res.status === 204) return null;
  return res.json();
}

/** `atob` alone yields one char per *byte* (Latin-1), which mangles every
 * Vietnamese diacritic — the bytes must go through a UTF-8 decoder. */
export function decodeBase64Utf8(b64: string): string {
  const binary = atob(b64.replace(/\n/g, ''));
  const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
  return new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(bytes);
}

interface GitTreeEntry {
  path: string;
  mode: string;
  type: string;
  sha: string;
}

/** Reads every `content/**\/*.json` file at `main`'s current head. Returns
 * the head commit's sha (the CMS's "baseSha" for a later [commitFiles]
 * call) alongside each file's raw text, keyed by its repo-relative path. */
export async function getContentAtHead(
  env: Env,
  fetchFn: FetchFn = fetch,
): Promise<{ sha: string; files: Record<string, string> }> {
  const repo = `/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}`;

  const ref = (await ghFetch(env, `${repo}/git/ref/heads/main`, {}, fetchFn)) as {
    object: { sha: string };
  };
  const headSha = ref.object.sha;

  const commit = (await ghFetch(env, `${repo}/git/commits/${headSha}`, {}, fetchFn)) as {
    tree: { sha: string };
  };

  const tree = (await ghFetch(
    env,
    `${repo}/git/trees/${commit.tree.sha}?recursive=1`,
    {},
    fetchFn,
  )) as { tree: GitTreeEntry[] };

  const contentEntries = tree.tree.filter(
    (e) => e.type === 'blob' && e.path.startsWith('content/') && e.path.endsWith('.json'),
  );

  const files: Record<string, string> = {};
  await Promise.all(
    contentEntries.map(async (entry) => {
      const blob = (await ghFetch(env, `${repo}/git/blobs/${entry.sha}`, {}, fetchFn)) as {
        content: string;
        encoding: string;
      };
      files[entry.path] =
        blob.encoding === 'base64' ? decodeBase64Utf8(blob.content) : blob.content;
    }),
  );

  return { sha: headSha, files };
}

export interface CommitFilesRequest {
  /** The `sha` [getContentAtHead] returned when this draft was loaded. */
  baseSha: string;
  /** Path → new text, or `null` to delete that path. */
  files: Record<string, string | null>;
  message: string;
}

/** Commits one or more file changes atomically via the Git Data API (a
 * single real commit, not one per file). Throws [ConflictError] — the
 * caller maps this to HTTP 409 — if `main` has moved past [baseSha] at all;
 * a v1-simple policy (any movement is a conflict, not just an overlapping
 * path) that's safe by construction and reasonable for a single-admin CMS. */
export async function commitFiles(
  env: Env,
  { baseSha, files, message }: CommitFilesRequest,
  fetchFn: FetchFn = fetch,
): Promise<{ sha: string }> {
  const repo = `/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}`;

  const ref = (await ghFetch(env, `${repo}/git/ref/heads/main`, {}, fetchFn)) as {
    object: { sha: string };
  };
  if (ref.object.sha !== baseSha) {
    throw new ConflictError(`main is at ${ref.object.sha}, draft was based on ${baseSha}`);
  }

  const baseCommit = (await ghFetch(env, `${repo}/git/commits/${baseSha}`, {}, fetchFn)) as {
    tree: { sha: string };
  };

  const treeEntries = await Promise.all(
    Object.entries(files).map(async ([path, content]) => {
      if (content === null) {
        // A null sha in a Git tree entry deletes that path.
        return { path, mode: '100644', type: 'blob', sha: null };
      }
      const blob = (await ghFetch(
        env,
        `${repo}/git/blobs`,
        { method: 'POST', body: { content, encoding: 'utf-8' } },
        fetchFn,
      )) as { sha: string };
      return { path, mode: '100644', type: 'blob', sha: blob.sha };
    }),
  );

  const newTree = (await ghFetch(
    env,
    `${repo}/git/trees`,
    { method: 'POST', body: { base_tree: baseCommit.tree.sha, tree: treeEntries } },
    fetchFn,
  )) as { sha: string };

  const newCommit = (await ghFetch(
    env,
    `${repo}/git/commits`,
    { method: 'POST', body: { message, tree: newTree.sha, parents: [baseSha] } },
    fetchFn,
  )) as { sha: string };

  // force: false — a fast-forward-only update, so a race that slips past the
  // ref check above still can't clobber someone else's commit.
  await ghFetch(
    env,
    `${repo}/git/refs/heads/main`,
    { method: 'PATCH', body: { sha: newCommit.sha, force: false } },
    fetchFn,
  );

  return { sha: newCommit.sha };
}

/** Triggers `.github/workflows/publish-content.yml` on `main`. */
export async function triggerPublish(
  env: Env,
  dryRun: boolean,
  fetchFn: FetchFn = fetch,
): Promise<void> {
  const repo = `/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}`;
  await ghFetch(
    env,
    `${repo}/actions/workflows/publish-content.yml/dispatches`,
    {
      method: 'POST',
      // workflow_dispatch inputs are always strings.
      body: { ref: 'main', inputs: { dry_run: String(dryRun) } },
    },
    fetchFn,
  );
}

export interface PublishRunStatus {
  status: string; // "queued" | "in_progress" | "completed" | …
  conclusion: string | null; // "success" | "failure" | null while running
  htmlUrl: string;
  createdAt: string;
}

/** The most recent `publish-content` run, for the CMS's Publish page to
 * poll. Returns null if the workflow has never run. */
export async function getLatestPublishRun(
  env: Env,
  fetchFn: FetchFn = fetch,
): Promise<PublishRunStatus | null> {
  const repo = `/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}`;
  const runs = (await ghFetch(
    env,
    `${repo}/actions/workflows/publish-content.yml/runs?per_page=1`,
    {},
    fetchFn,
  )) as {
    workflow_runs: Array<{
      status: string;
      conclusion: string | null;
      html_url: string;
      created_at: string;
    }>;
  };
  const run = runs.workflow_runs[0];
  if (!run) return null;
  return {
    status: run.status,
    conclusion: run.conclusion,
    htmlUrl: run.html_url,
    createdAt: run.created_at,
  };
}
