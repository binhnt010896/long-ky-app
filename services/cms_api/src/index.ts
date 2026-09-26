import { Hono } from 'hono';
import { cors } from 'hono/cors';

import { AuthError, requireUser } from './auth';
import {
  ConflictError,
  commitFiles,
  getContentAtHead,
  getLatestPublishRun,
  triggerPublish,
} from './github';
import { MediaError, getMedia, putMedia } from './media';
import type { Env } from './types';

const app = new Hono<{ Bindings: Env }>();

// CORS locked to the deployed CMS's own origin, plus any localhost origin
// (Flutter web's dev server picks a random port each run) so local dev can
// talk to the live Worker without redeploying it every time.
app.use('*', async (c, next) =>
  cors({
    origin: (origin) => {
      if (origin === c.env.CMS_ORIGIN) return origin;
      if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) return origin;
      return null;
    },
  })(c, next),
);

// Every route below needs a signed-in, allowlisted caller. The CMS's own
// sign-in page (not this Worker) is what's actually reachable without a
// token — every API call is refused without one.
app.use('*', async (c, next) => {
  try {
    await requireUser(c.req.raw, c.env);
  } catch (e) {
    if (e instanceof AuthError) return c.json({ error: e.message }, e.status as 401 | 403);
    throw e;
  }
  await next();
});

app.get('/content', async (c) => {
  const result = await getContentAtHead(c.env);
  return c.json(result);
});

app.post('/commit', async (c) => {
  const body = await c.req.json();
  try {
    const result = await commitFiles(c.env, body);
    return c.json(result);
  } catch (e) {
    if (e instanceof ConflictError) {
      return c.json({ error: 'main moved since this draft was loaded — reload and retry' }, 409);
    }
    throw e;
  }
});

app.put('/media', async (c) => {
  const path = c.req.query('path');
  if (!path) return c.json({ error: 'path is required' }, 400);
  const body = c.req.raw.body;
  if (!body) return c.json({ error: 'request body is required' }, 400);

  const contentType = c.req.header('Content-Type') ?? '';
  const contentLengthHeader = c.req.header('Content-Length');
  const contentLength = contentLengthHeader ? Number(contentLengthHeader) : null;

  try {
    await putMedia(c.env, path, body, contentType, contentLength);
    return c.json({ ok: true });
  } catch (e) {
    if (e instanceof MediaError) return c.json({ error: e.message }, e.status as 413 | 415);
    throw e;
  }
});

app.get('/media', async (c) => {
  const path = c.req.query('path');
  if (!path) return c.json({ error: 'path is required' }, 400);
  try {
    const obj = await getMedia(c.env, path);
    return new Response(obj.body, {
      headers: { 'Content-Type': obj.httpMetadata?.contentType ?? 'application/octet-stream' },
    });
  } catch (e) {
    if (e instanceof MediaError) return c.json({ error: e.message }, e.status as 404);
    throw e;
  }
});

app.post('/publish', async (c) => {
  const body = await c.req.json().catch(() => ({}));
  await triggerPublish(c.env, Boolean((body as { dryRun?: boolean }).dryRun));
  return c.json({ ok: true });
});

app.get('/publish/status', async (c) => {
  const status = await getLatestPublishRun(c.env);
  return c.json(status);
});

export default app;
