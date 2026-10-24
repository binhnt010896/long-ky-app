import { Hono } from 'hono';
import { cors } from 'hono/cors';

import { buildMime } from './mail';

/** Everything the Worker reads from wrangler.toml. */
export interface Env {
  /** Cloudflare Email Routing `send_email` binding, locked to FEEDBACK_TO. */
  FEEDBACK_EMAIL: { send(message: unknown): Promise<void> };
  FEEDBACK_FROM: string;
  FEEDBACK_TO: string;
  /** Optional Workers rate-limit binding; absent in tests and local dev. */
  RATE_LIMITER?: { limit(opts: { key: string }): Promise<{ success: boolean }> };
}

export const MAX_SUBJECT = 200;
export const MAX_BODY = 4000;
const SUBJECT_PREFIX = '[Long Ký] ';

export type Sender = (env: Env, raw: string) => Promise<void>;

const sendViaCloudflare: Sender = async (env, raw) => {
  // Only exists inside the Workers runtime, so it is imported when needed.
  const { EmailMessage } = await import('cloudflare:email');
  await env.FEEDBACK_EMAIL.send(new EmailMessage(env.FEEDBACK_FROM, env.FEEDBACK_TO, raw));
};

/** The report, if [json] is one; otherwise why not. */
export function parseReport(
  json: unknown,
): { subject: string; body: string } | { error: string } {
  if (typeof json !== 'object' || json === null) return { error: 'expected a JSON object' };
  const { subject, body } = json as Record<string, unknown>;
  if (typeof subject !== 'string' || typeof body !== 'string') {
    return { error: 'subject and body must be strings' };
  }
  // A header value: one line only, or a sender could inject headers.
  if (/[\r\n]/.test(subject)) return { error: 'subject must be a single line' };
  if (!subject.startsWith(SUBJECT_PREFIX) || subject.length > MAX_SUBJECT) {
    return { error: 'invalid subject' };
  }
  if (body.trim().length === 0 || body.length > MAX_BODY) return { error: 'invalid body' };
  return { subject, body };
}

export function createApp(send: Sender = sendViaCloudflare) {
  const app = new Hono<{ Bindings: Env }>();

  // A public endpoint by design (readers have no account), so any origin may
  // post — the web build is served from its own domain.
  app.use('*', cors({ origin: '*', allowMethods: ['POST', 'OPTIONS'] }));

  app.post('/feedback', async (c) => {
    if (c.env.RATE_LIMITER) {
      const key = c.req.header('CF-Connecting-IP') ?? 'unknown';
      const { success } = await c.env.RATE_LIMITER.limit({ key });
      if (!success) return c.json({ error: 'too many reports, try again later' }, 429);
    }

    const json = await c.req.json().catch(() => null);
    const report = parseReport(json);
    if ('error' in report) return c.json({ error: report.error }, 400);

    const raw = buildMime({
      from: c.env.FEEDBACK_FROM,
      to: c.env.FEEDBACK_TO,
      subject: report.subject,
      body: report.body,
    });
    try {
      await send(c.env, raw);
    } catch (e) {
      console.error('feedback send failed', e);
      return c.json({ error: 'could not send' }, 502);
    }
    return c.json({ ok: true });
  });

  return app;
}

export default createApp();
