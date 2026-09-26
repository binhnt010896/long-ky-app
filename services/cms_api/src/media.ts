import type { Env } from './types';

export class MediaError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

// Matches the media types content/ actually holds (see .gitignore's list and
// gen_media_manifest.dart's `_mediaExtensions`) — not an open upload endpoint.
const ALLOWED_CONTENT_TYPES = new Set([
  'image/png',
  'image/jpeg',
  'image/gif',
  'image/webp',
  'video/mp4',
]);

// Generous enough for any real era image or short cover video, small enough
// that a mistaken upload can't quietly fill the bucket.
const MAX_MEDIA_BYTES = 100 * 1024 * 1024;

/** Streams an original into `long-ky-sources` at [path] (e.g.
 * `eras/au-lac/cover.png`, mirroring content/'s own layout). Throws
 * [MediaError] (415/413) for a disallowed type or an oversized upload —
 * checked before ever touching R2.
 *
 * If [path] already exists, the old original is copied to
 * `_replaced/<timestamp>/<path>` first — `long-ky-sources` has no
 * versioning of its own, and a CMS replace is otherwise a silent,
 * unrecoverable overwrite (H-4/H3's explicit decision). The backup copy is
 * best-effort: a failure to back up doesn't block the new upload, since an
 * admin fixing a broken image shouldn't be stuck because a backup write
 * failed. */
export async function putMedia(
  env: Env,
  path: string,
  body: ReadableStream | ArrayBuffer,
  contentType: string,
  contentLength: number | null,
): Promise<void> {
  if (!ALLOWED_CONTENT_TYPES.has(contentType)) {
    throw new MediaError(`Unsupported content type: ${contentType}`, 415);
  }
  if (contentLength !== null && contentLength > MAX_MEDIA_BYTES) {
    throw new MediaError(
      `File too large (${contentLength} bytes, max ${MAX_MEDIA_BYTES})`,
      413,
    );
  }

  const existing = await env.SOURCES_BUCKET.get(path);
  if (existing) {
    const backupPath = `_replaced/${new Date().toISOString().replace(/[:.]/g, '-')}/${path}`;
    try {
      await env.SOURCES_BUCKET.put(backupPath, existing.body, {
        httpMetadata: existing.httpMetadata,
      });
    } catch {
      // Best-effort — see the doc comment above.
    }
  }

  await env.SOURCES_BUCKET.put(path, body, { httpMetadata: { contentType } });
}

/** Reads an original back from `long-ky-sources` — used for the CMS's media
 * previews of art that hasn't been published (and so isn't on the public
 * `long-ky-content` CDN) yet. Throws [MediaError] (404) if it doesn't exist. */
export async function getMedia(env: Env, path: string): Promise<R2ObjectBody> {
  const obj = await env.SOURCES_BUCKET.get(path);
  if (!obj) {
    throw new MediaError(`Not found: ${path}`, 404);
  }
  return obj;
}
