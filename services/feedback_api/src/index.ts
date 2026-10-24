import { Hono } from 'hono';
import { cors } from 'hono/cors';

/** Everything the Worker reads from wrangler.toml. */
export interface Env {
  /** Resend API key — the one secret; `wrangler secret put RESEND_API_KEY`. */
  RESEND_API_KEY: string;
  FEEDBACK_FROM: string;
  FEEDBACK_TO: string;
  /** Optional Workers rate-limit binding; absent in tests and local dev. */
  RATE_LIMITER?: { limit(opts: { key: string }): Promise<{ success: boolean }> };
}

export const MAX_SUBJECT = 200;
export const MAX_BODY = 4000;
const SUBJECT_PREFIX = '[Long Ký] ';

export type Sender = (env: Env, report: { subject: string; body: string }) => Promise<void>;

/** Plain text from FEEDBACK_FROM to FEEDBACK_TO. No reply_to: the reader
 * never gives us an address, and nothing here asks for one. */
const sendViaResend: Sender = async (env, { subject, body }) => {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: env.FEEDBACK_FROM,
      to: [env.FEEDBACK_TO],
      subject,
      text: body,
    }),
  });
  if (!res.ok) throw new Error(`Resend ${res.status}: ${await res.text()}`);
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

export function createApp(send: Sender = sendViaResend) {
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

    try {
      await send(c.env, report);
    } catch (e) {
      console.error('feedback send failed', e);
      return c.json({ error: 'could not send' }, 502);
    }
    return c.json({ ok: true });
  });

  return app;
}

export default createApp();
