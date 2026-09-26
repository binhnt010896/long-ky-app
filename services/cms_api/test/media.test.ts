import { env } from 'cloudflare:test';
import { beforeEach, describe, expect, it } from 'vitest';

import { MediaError, getMedia, putMedia } from '../src/media';
import type { Env } from '../src/types';

const testEnv = env as unknown as Env;

// The test pool's [miniflare] config gives us a real (in-memory) R2 bucket
// for the SOURCES_BUCKET binding — these hit that, not a fake.
async function clearBucket() {
  const listed = await testEnv.SOURCES_BUCKET.list();
  await Promise.all(listed.objects.map((o) => testEnv.SOURCES_BUCKET.delete(o.key)));
}

describe('putMedia', () => {
  beforeEach(clearBucket);

  it('rejects an unsupported content type before touching R2', async () => {
    await expect(
      putMedia(testEnv, 'eras/au-lac/cover.svg', new ArrayBuffer(10), 'image/svg+xml', 10),
    ).rejects.toMatchObject({ status: 415 } satisfies Partial<MediaError>);
    expect((await testEnv.SOURCES_BUCKET.list()).objects).toHaveLength(0);
  });

  it('rejects a file over the size limit before touching R2', async () => {
    await expect(
      putMedia(testEnv, 'eras/au-lac/cover.png', new ArrayBuffer(10), 'image/png', 200 * 1024 * 1024),
    ).rejects.toMatchObject({ status: 413 } satisfies Partial<MediaError>);
    expect((await testEnv.SOURCES_BUCKET.list()).objects).toHaveLength(0);
  });

  it('accepts an allowed type under the size limit and stores it', async () => {
    const bytes = new TextEncoder().encode('not really a png, just test bytes');
    // A ReadableStream, matching how index.ts actually calls this
    // (`c.req.raw.body`) — an ArrayBuffer here trips a storage-snapshot
    // quirk in this exact test-pool/R2-simulator version unrelated to
    // putMedia's own logic.
    await putMedia(
      testEnv,
      'eras/au-lac/cover.png',
      new Blob([bytes]).stream(),
      'image/png',
      bytes.length,
    );

    // head() returns metadata with no body to dispose of — get()'s
    // R2ObjectBody stream needs explicit consumption in this test pool's
    // JSRPC-backed R2 simulator, or it leaves storage dangling across the
    // test boundary (see the getMedia tests below for the get() case).
    const stored = await testEnv.SOURCES_BUCKET.head('eras/au-lac/cover.png');
    expect(stored).not.toBeNull();
    expect(stored?.httpMetadata?.contentType).toBe('image/png');
  });

  it('accepts an upload with no declared Content-Length', async () => {
    const bytes = new TextEncoder().encode('streamed, length unknown up front');
    await putMedia(testEnv, 'eras/au-lac/cover.png', new Blob([bytes]).stream(), 'image/png', null);
    const listed = await testEnv.SOURCES_BUCKET.list({ prefix: 'eras/au-lac/cover.png' });
    expect(listed.objects).toHaveLength(1);
  });

  it('backs up the old original before overwriting an existing path', async () => {
    const oldBytes = new TextEncoder().encode('the original file');
    await testEnv.SOURCES_BUCKET.put('eras/au-lac/cover.png', oldBytes, {
      httpMetadata: { contentType: 'image/png' },
    });

    const newBytes = new TextEncoder().encode('the replacement file');
    await putMedia(
      testEnv,
      'eras/au-lac/cover.png',
      new Blob([newBytes]).stream(),
      'image/png',
      newBytes.length,
    );

    // The live path now has the new content.
    const live = await testEnv.SOURCES_BUCKET.get('eras/au-lac/cover.png');
    expect(await live!.text()).toBe('the replacement file');

    // A backup copy exists under _replaced/, holding the old content.
    const backups = await testEnv.SOURCES_BUCKET.list({ prefix: '_replaced/' });
    expect(backups.objects).toHaveLength(1);
    expect(backups.objects[0]!.key).toMatch(/^_replaced\/.+\/eras\/au-lac\/cover\.png$/);
    const backup = await testEnv.SOURCES_BUCKET.get(backups.objects[0]!.key);
    expect(await backup!.text()).toBe('the original file');
  });

  it('uploads normally with no backup when the path is new', async () => {
    const bytes = new TextEncoder().encode('brand new file');
    await putMedia(testEnv, 'eras/au-lac/new.png', new Blob([bytes]).stream(), 'image/png', bytes.length);
    const backups = await testEnv.SOURCES_BUCKET.list({ prefix: '_replaced/' });
    expect(backups.objects).toHaveLength(0);
  });
});

describe('getMedia', () => {
  beforeEach(clearBucket);

  it('throws a 404 MediaError for a path that does not exist', async () => {
    await expect(getMedia(testEnv, 'eras/nope/cover.png')).rejects.toMatchObject({
      status: 404,
    } satisfies Partial<MediaError>);
  });

  it('returns the stored object for a path that exists', async () => {
    await testEnv.SOURCES_BUCKET.put('eras/au-lac/cover.png', new TextEncoder().encode('x'));
    const obj = await getMedia(testEnv, 'eras/au-lac/cover.png');
    // Fully consuming the body (rather than just reading .key) is what
    // properly releases the object across this test pool's JSRPC boundary —
    // see the note on the putMedia tests above.
    expect(await obj.text()).toBe('x');
    expect(obj.key).toBe('eras/au-lac/cover.png');
  });
});
