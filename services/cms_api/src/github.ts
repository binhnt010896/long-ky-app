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

/** How many directory levels below `content/` the GraphQL query expands
 * (`content/eras/x.json` is one). A directory deeper than this would be
 * missing from the load, so the walk below fails loudly if it meets one. */
const CONTENT_TREE_DEPTH = 4;

/** One query for the whole content tree: every entry's name, and every blob's
 * `text`. GraphQL can't say "recurse", so the nesting is spelled out to
 * [CONTENT_TREE_DEPTH]. */
function contentTreeQuery(): string {
  const blob = '... on Blob { oid text isTruncated }';
  const tree = (depth: number): string =>
    depth === 0 ? blob : `... on Tree { entries { name object { ${tree(depth - 1)} } } } ${blob}`;
  return (
    'query($owner:String!,$repo:String!,$expr:String!){ ' +
    'repository(owner:$owner,name:$repo){ ' +
    `object(expression:$expr){ ${tree(CONTENT_TREE_DEPTH)} } } }`
  );
}

interface GqlBlob {
  oid: string;
  text: string | null;
  isTruncated: boolean;
}
interface GqlNode extends Partial<GqlBlob> {
  entries?: { name: string; object: GqlNode | null }[];
}

/** Reads every `content/**\/*.json` file at `main`'s current head. Returns
 * the head commit's sha (the CMS's "baseSha" for a later [commitFiles]
 * call) alongside each file's raw text, keyed by its repo-relative path.
 *
 * Cloudflare Workers Free allows 50 subrequests per request, and the old
 * loader spent one per file plus three (exactly 50 at 47 files). This spends
 * three, however many files there are:
 *   1. the head sha (REST);
 *   2. one GraphQL query for the whole `content/` tree, pinned to that exact
 *      commit (`<sha>:content`) so the files and the sha can never disagree;
 *   3. one REST blob read per *truncated* file. GraphQL cuts a blob's `text`
 *      off somewhere below ~790 KB (measured: a 787,843-byte file came back
 *      `isTruncated: true`; a 305 KB one did not), and `events.json` is
 *      bigger than that. Today that is zero or one extra request. */
export async function getContentAtHead(
  env: Env,
  fetchFn: FetchFn = fetch,
): Promise<{ sha: string; files: Record<string, string> }> {
  const repo = `/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}`;

  const ref = (await ghFetch(env, `${repo}/git/ref/heads/main`, {}, fetchFn)) as {
    object: { sha: string };
  };
  const headSha = ref.object.sha;

  const gql = (await ghFetch(
    env,
    '/graphql',
    {
      method: 'POST',
      body: {
        query: contentTreeQuery(),
        variables: { owner: env.GITHUB_OWNER, repo: env.GITHUB_REPO, expr: `${headSha}:content` },
      },
    },
    fetchFn,
  )) as {
    data?: { repository?: { object: GqlNode | null } | null } | null;
    errors?: { message: string }[];
  };
  if (gql.errors?.length || !gql.data?.repository) {
    throw new GitHubApiError(
      `GitHub GraphQL content read failed: ${gql.errors?.map((e) => e.message).join('; ') ?? 'no data'}`,
      502,
    );
  }

  const files: Record<string, string> = {};
  const needsBlobRead: { path: string; oid: string }[] = [];

  const walk = (node: GqlNode | null, path: string): void => {
    if (!node) return;
    if (node.entries) {
      for (const e of node.entries) walk(e.object, `${path}/${e.name}`);
      return;
    }
    // A directory below the expanded depth comes back as an empty object
    // (neither `entries` nor a blob's `oid`) — never drop it silently.
    if (node.oid === undefined) {
      throw new GitHubApiError(`content/ nests deeper than ${CONTENT_TREE_DEPTH} levels at ${path}`, 502);
    }
    if (!path.endsWith('.json')) return;
    if (node.isTruncated || node.text == null) {
      needsBlobRead.push({ path, oid: node.oid });
    } else {
      files[path] = node.text;
    }
  };
  walk(gql.data.repository.object, 'content');

  await Promise.all(
    needsBlobRead.map(async ({ path, oid }) => {
      const blob = (await ghFetch(env, `${repo}/git/blobs/${oid}`, {}, fetchFn)) as {
        content: string;
        encoding: string;
      };
      files[path] = blob.encoding === 'base64' ? decodeBase64Utf8(blob.content) : blob.content;
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

/** Triggers `.github/workflows/publish-content.yml` on `main`. [mode]
 * defaults to `incremental` (Cycle K) — only what actually changed since
 * the last publish. [expectedSha], when given, makes a real (non-dry-run)
 * publish refuse to run if `main` has moved past it — the workflow's own
 * "Refuse to publish over a moved main" step. */
export async function triggerPublish(
  env: Env,
  dryRun: boolean,
  fetchFn: FetchFn = fetch,
  mode: 'incremental' | 'full' = 'incremental',
  expectedSha?: string,
): Promise<void> {
  const repo = `/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}`;
  await ghFetch(
    env,
    `${repo}/actions/workflows/publish-content.yml/dispatches`,
    {
      method: 'POST',
      // workflow_dispatch inputs are always strings.
      body: {
        ref: 'main',
        inputs: {
          dry_run: String(dryRun),
          mode,
          ...(expectedSha ? { expected_sha: expectedSha } : {}),
        },
      },
    },
    fetchFn,
  );
}

export interface PublishRunStatus {
  status: string; // "queued" | "in_progress" | "completed" | …
  conclusion: string | null; // "success" | "failure" | null while running
  htmlUrl: string;
  createdAt: string;
  headSha: string;
  /** The run's display title, e.g. "dry run (incremental) a1b2c3d" — see
   * the workflow's `run-name`. Used to tell a dry run from a real publish
   * without needing the original dispatch inputs back. */
  title: string;
}

type GhRun = {
  status: string;
  conclusion: string | null;
  html_url: string;
  created_at: string;
  head_sha: string;
  display_title: string;
};

function toStatus(run: GhRun): PublishRunStatus {
  return {
    status: run.status,
    conclusion: run.conclusion,
    htmlUrl: run.html_url,
    createdAt: run.created_at,
    headSha: run.head_sha,
    title: run.display_title,
  };
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
  )) as { workflow_runs: GhRun[] };
  const run = runs.workflow_runs[0];
  return run ? toStatus(run) : null;
}

/** True when the most recent successful dry run among the last 15 publish
 * runs was for [sha] — the CMS's "Publish for real" gate (decision K3):
 * publishing should require a dry run of *this exact* content, not just
 * "some run succeeded at some point," which today's weaker check allows. */
export async function hasSuccessfulDryRunFor(
  env: Env,
  sha: string,
  fetchFn: FetchFn = fetch,
): Promise<boolean> {
  const repo = `/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}`;
  const runs = (await ghFetch(
    env,
    `${repo}/actions/workflows/publish-content.yml/runs?per_page=15`,
    {},
    fetchFn,
  )) as { workflow_runs: GhRun[] };
  return runs.workflow_runs.some(
    (r) =>
      r.head_sha === sha &&
      r.conclusion === 'success' &&
      r.display_title.startsWith('dry run'),
  );
}
