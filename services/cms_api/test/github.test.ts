import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';

import {
  ConflictError,
  commitFiles,
  decodeBase64Utf8,
  getContentAtHead,
  hasSuccessfulDryRunFor,
  triggerPublish,
} from '../src/github';
import type { Env } from '../src/types';

const testEnv = env as unknown as Env;
const repo = `/repos/${testEnv.GITHUB_OWNER}/${testEnv.GITHUB_REPO}`;
const api = (path: string) => `https://api.github.com${repo}${path}`;

/** A fake `fetch` keyed by `"METHOD url"` — every call the code under test
 * makes must have a matching entry, or the mock throws (so a test can never
 * silently pass by hitting the real network). */
function mockFetch(handlers: Record<string, { status?: number; json?: unknown }>): typeof fetch {
  return (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : (input as URL | Request).toString();
    const method = init?.method ?? 'GET';
    const key = `${method} ${url}`;
    const handler = handlers[key];
    if (!handler) throw new Error(`Unexpected fetch in test: ${key}`);
    return new Response(handler.json === undefined ? null : JSON.stringify(handler.json), {
      status: handler.status ?? 200,
    });
  }) as typeof fetch;
}

/** A `fetch` that also records every call it serves, so a test can assert how
 * many subrequests a Worker request really spends (Workers Free allows 50). */
function recordingFetch(
  handlers: Record<string, { status?: number; json?: unknown }>,
  calls: string[],
): typeof fetch {
  const inner = mockFetch(handlers);
  return (async (input: RequestInfo | URL, init?: RequestInit) => {
    calls.push(`${init?.method ?? 'GET'} ${typeof input === 'string' ? input : input.toString()}`);
    return inner(input, init);
  }) as typeof fetch;
}

const gqlUrl = 'https://api.github.com/graphql';
const blobNode = (text: string | null, opts: { oid?: string; isTruncated?: boolean } = {}) => ({
  oid: opts.oid ?? 'oid',
  text,
  isTruncated: opts.isTruncated ?? false,
});

describe('getContentAtHead', () => {
  it('reads every content/**/*.json file at head, ignoring everything else', async () => {
    const fetchFn = mockFetch({
      [`GET ${api('/git/ref/heads/main')}`]: { json: { object: { sha: 'head-sha' } } },
      [`POST ${gqlUrl}`]: {
        json: {
          data: {
            repository: {
              object: {
                entries: [
                  { name: 'au-lac.json', object: blobNode('{"slug":"au-lac"}') },
                  { name: 'FIELD-REFERENCE.md', object: blobNode('# notes') },
                  {
                    name: 'eras',
                    object: {
                      entries: [{ name: 'ba-trieu.json', object: blobNode('{"slug":"ba-trieu"}') }],
                    },
                  },
                ],
              },
            },
          },
        },
      },
    });

    const result = await getContentAtHead(testEnv, fetchFn);

    expect(result.sha).toBe('head-sha');
    expect(Object.keys(result.files).sort()).toEqual([
      'content/au-lac.json',
      'content/eras/ba-trieu.json',
    ]);
    expect(result.files['content/au-lac.json']).toBe('{"slug":"au-lac"}');
  });

  it('pins the GraphQL read to the head commit, so files and sha cannot disagree', async () => {
    let body: { variables: { expr: string } } | undefined;
    const fetchFn = (async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = input.toString();
      if (url === gqlUrl) {
        body = JSON.parse(init!.body as string);
        return new Response(JSON.stringify({ data: { repository: { object: { entries: [] } } } }));
      }
      return new Response(JSON.stringify({ object: { sha: 'abc123' } }));
    }) as typeof fetch;

    await getContentAtHead(testEnv, fetchFn);

    expect(body?.variables.expr).toBe('abc123:content');
  });

  it('re-reads only the truncated files through the blob endpoint', async () => {
    const big = '{"events":"' + 'x'.repeat(50) + '"}';
    const calls: string[] = [];
    const fetchFn = recordingFetch(
      {
        [`GET ${api('/git/ref/heads/main')}`]: { json: { object: { sha: 'head-sha' } } },
        [`POST ${gqlUrl}`]: {
          json: {
            data: {
              repository: {
                object: {
                  entries: [
                    { name: 'small.json', object: blobNode('{"a":1}') },
                    {
                      name: 'events.json',
                      object: blobNode('{"events":"xx', { oid: 'big-oid', isTruncated: true }),
                    },
                  ],
                },
              },
            },
          },
        },
        [`GET ${api('/git/blobs/big-oid')}`]: {
          json: { content: btoa(big), encoding: 'base64' },
        },
      },
      calls,
    );

    const result = await getContentAtHead(testEnv, fetchFn);

    expect(result.files['content/events.json']).toBe(big);
    expect(result.files['content/small.json']).toBe('{"a":1}');
    // ref + graphql + the one truncated blob — not one request per file.
    expect(calls).toHaveLength(3);
  });

  it('spends three subrequests however many files there are', async () => {
    const calls: string[] = [];
    const entries = Array.from({ length: 200 }, (_, i) => ({
      name: `f${i}.json`,
      object: blobNode(`{"i":${i}}`),
    }));
    const fetchFn = recordingFetch(
      {
        [`GET ${api('/git/ref/heads/main')}`]: { json: { object: { sha: 'head-sha' } } },
        [`POST ${gqlUrl}`]: { json: { data: { repository: { object: { entries } } } } },
      },
      calls,
    );

    const result = await getContentAtHead(testEnv, fetchFn);

    expect(Object.keys(result.files)).toHaveLength(200);
    expect(calls).toHaveLength(2);
  });

  it('fails loudly on a GraphQL error rather than returning a partial draft', async () => {
    const fetchFn = mockFetch({
      [`GET ${api('/git/ref/heads/main')}`]: { json: { object: { sha: 'head-sha' } } },
      [`POST ${gqlUrl}`]: { json: { data: null, errors: [{ message: 'Something went wrong' }] } },
    });

    await expect(getContentAtHead(testEnv, fetchFn)).rejects.toThrow(/Something went wrong/);
  });

  it('fails loudly on a directory nested deeper than the query expands', async () => {
    const fetchFn = mockFetch({
      [`GET ${api('/git/ref/heads/main')}`]: { json: { object: { sha: 'head-sha' } } },
      [`POST ${gqlUrl}`]: {
        json: {
          data: {
            repository: {
              // An unexpanded directory comes back as an empty object.
              object: { entries: [{ name: 'deep', object: {} }] },
            },
          },
        },
      },
    });

    await expect(getContentAtHead(testEnv, fetchFn)).rejects.toThrow(/nests deeper/);
  });
});

describe('decodeBase64Utf8', () => {
  it('round-trips Vietnamese diacritics, including GitHub-style line-wrapped base64', () => {
    const text = '{"title":"Âu Lạc — Hai Bà Trưng, Đinh Tiên Hoàng, Nguyễn"}';
    const bytes = new TextEncoder().encode(text);
    const b64 = btoa(String.fromCharCode(...bytes));
    const wrapped = b64.replace(/(.{60})/g, '$1\n');

    expect(decodeBase64Utf8(wrapped)).toBe(text);
  });
});

describe('commitFiles', () => {
  it('throws ConflictError without writing anything if main has moved', async () => {
    let writesAttempted = 0;
    const fetchFn = mockFetch({
      [`GET ${api('/git/ref/heads/main')}`]: { json: { object: { sha: 'someone-elses-sha' } } },
    });
    const countingFetch: typeof fetch = async (...args) => {
      const url = args[0].toString();
      if (args[1]?.method && args[1].method !== 'GET') writesAttempted++;
      return fetchFn(url as never, args[1]);
    };

    await expect(
      commitFiles(
        testEnv,
        { baseSha: 'stale-sha', files: { 'content/au-lac.json': '{}' }, message: 'edit' },
        countingFetch,
      ),
    ).rejects.toThrow(ConflictError);
    expect(writesAttempted).toBe(0);
  });

  it('creates one blob, one tree, one commit, and fast-forwards the ref', async () => {
    const fetchFn = mockFetch({
      [`GET ${api('/git/ref/heads/main')}`]: { json: { object: { sha: 'base-sha' } } },
      [`GET ${api('/git/commits/base-sha')}`]: { json: { tree: { sha: 'base-tree-sha' } } },
      [`POST ${api('/git/blobs')}`]: { json: { sha: 'new-blob-sha' } },
      [`POST ${api('/git/trees')}`]: { json: { sha: 'new-tree-sha' } },
      [`POST ${api('/git/commits')}`]: { json: { sha: 'new-commit-sha' } },
      [`PATCH ${api('/git/refs/heads/main')}`]: { status: 204 },
    });

    const result = await commitFiles(
      testEnv,
      {
        baseSha: 'base-sha',
        files: { 'content/au-lac.json': '{"slug":"au-lac","order":2}' },
        message: 'fix(content): bump Âu Lạc order',
      },
      fetchFn,
    );

    expect(result.sha).toBe('new-commit-sha');
  });

  it('propagates a GitHub API error (e.g. a 422 tree conflict) rather than swallowing it', async () => {
    const fetchFn = mockFetch({
      [`GET ${api('/git/ref/heads/main')}`]: { json: { object: { sha: 'base-sha' } } },
      [`GET ${api('/git/commits/base-sha')}`]: { json: { tree: { sha: 'base-tree-sha' } } },
      [`POST ${api('/git/blobs')}`]: { json: { sha: 'new-blob-sha' } },
      [`POST ${api('/git/trees')}`]: { status: 422, json: { message: 'invalid tree' } },
    });

    await expect(
      commitFiles(
        testEnv,
        { baseSha: 'base-sha', files: { 'content/au-lac.json': '{}' }, message: 'edit' },
        fetchFn,
      ),
    ).rejects.toThrow(/422/);
  });
});

describe('triggerPublish', () => {
  it('defaults to incremental mode and omits expectedSha when not given', async () => {
    let sentBody: unknown;
    const fetchFn = mockFetch({
      [`POST ${api('/actions/workflows/publish-content.yml/dispatches')}`]: { status: 204 },
    });
    const capturingFetch: typeof fetch = async (input, init) => {
      sentBody = init?.body ? JSON.parse(init.body as string) : undefined;
      return fetchFn(input, init);
    };

    await triggerPublish(testEnv, true, capturingFetch);

    expect(sentBody).toEqual({
      ref: 'main',
      inputs: { dry_run: 'true', mode: 'incremental' },
    });
  });

  it('passes mode and expectedSha through when given', async () => {
    let sentBody: unknown;
    const fetchFn = mockFetch({
      [`POST ${api('/actions/workflows/publish-content.yml/dispatches')}`]: { status: 204 },
    });
    const capturingFetch: typeof fetch = async (input, init) => {
      sentBody = init?.body ? JSON.parse(init.body as string) : undefined;
      return fetchFn(input, init);
    };

    await triggerPublish(testEnv, false, capturingFetch, 'full', 'abc1234');

    expect(sentBody).toEqual({
      ref: 'main',
      inputs: { dry_run: 'false', mode: 'full', expected_sha: 'abc1234' },
    });
  });
});

describe('hasSuccessfulDryRunFor', () => {
  it('is true only for a successful dry run of exactly that sha', async () => {
    const fetchFn = mockFetch({
      [`GET ${api('/actions/workflows/publish-content.yml/runs?per_page=15')}`]: {
        json: {
          workflow_runs: [
            {
              status: 'completed',
              conclusion: 'success',
              html_url: 'https://x',
              created_at: 'now',
              head_sha: 'good-sha',
              display_title: 'dry run (incremental) good-sh',
            },
          ],
        },
      },
    });

    expect(await hasSuccessfulDryRunFor(testEnv, 'good-sha', fetchFn)).toBe(true);
    expect(await hasSuccessfulDryRunFor(testEnv, 'other-sha', fetchFn)).toBe(false);
  });

  it('ignores a real publish run — only a dry run satisfies the gate', async () => {
    const fetchFn = mockFetch({
      [`GET ${api('/actions/workflows/publish-content.yml/runs?per_page=15')}`]: {
        json: {
          workflow_runs: [
            {
              status: 'completed',
              conclusion: 'success',
              html_url: 'https://x',
              created_at: 'now',
              head_sha: 'the-sha',
              display_title: 'publish (incremental) the-sha',
            },
          ],
        },
      },
    });

    expect(await hasSuccessfulDryRunFor(testEnv, 'the-sha', fetchFn)).toBe(false);
  });

  it('ignores a failed dry run', async () => {
    const fetchFn = mockFetch({
      [`GET ${api('/actions/workflows/publish-content.yml/runs?per_page=15')}`]: {
        json: {
          workflow_runs: [
            {
              status: 'completed',
              conclusion: 'failure',
              html_url: 'https://x',
              created_at: 'now',
              head_sha: 'the-sha',
              display_title: 'dry run (incremental) the-sha',
            },
          ],
        },
      },
    });

    expect(await hasSuccessfulDryRunFor(testEnv, 'the-sha', fetchFn)).toBe(false);
  });
});
