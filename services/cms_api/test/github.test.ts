import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';

import { ConflictError, commitFiles, decodeBase64Utf8, getContentAtHead } from '../src/github';
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

describe('getContentAtHead', () => {
  it('reads every content/**/*.json file at head, ignoring everything else', async () => {
    const fetchFn = mockFetch({
      [`GET ${api('/git/ref/heads/main')}`]: { json: { object: { sha: 'head-sha' } } },
      [`GET ${api('/git/commits/head-sha')}`]: { json: { tree: { sha: 'tree-sha' } } },
      [`GET ${api('/git/trees/tree-sha?recursive=1')}`]: {
        json: {
          tree: [
            { path: 'content/au-lac.json', type: 'blob', sha: 'blob-1' },
            { path: 'content/eras/notes.md', type: 'blob', sha: 'blob-2' },
            { path: 'README.md', type: 'blob', sha: 'blob-3' },
          ],
        },
      },
      [`GET ${api('/git/blobs/blob-1')}`]: {
        json: { content: btoa('{"slug":"au-lac"}'), encoding: 'base64' },
      },
    });

    const result = await getContentAtHead(testEnv, fetchFn);

    expect(result.sha).toBe('head-sha');
    expect(Object.keys(result.files)).toEqual(['content/au-lac.json']);
    expect(result.files['content/au-lac.json']).toBe('{"slug":"au-lac"}');
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
