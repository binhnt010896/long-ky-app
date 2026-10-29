import { Hono } from 'hono';
import { cors } from 'hono/cors';

import { type Mail, SUBJECT_PREFIX, parseReport, parseTesterRequest } from './report';

/** Everything the Worker reads from wrangler.toml. */
export interface Env {
  /** Resend API key — the one secret; `wrangler secret put RESEND_API_KEY`. */
  RESEND_API_KEY: string;
  FEEDBACK_FROM: string;
  FEEDBACK_TO: string;
  /** Optional Workers rate-limit binding; absent in tests and local dev. */
  RATE_LIMITER?: { limit(opts: { key: string }): Promise<{ success: boolean }> };
}

export type Sender = (env: Env, mail: Mail) => Promise<void>;

/** Plain text from FEEDBACK_FROM to FEEDBACK_TO. App reports carry no
 * reply_to: the reader never gives us an address, and nothing asks for one. */
const sendViaResend: Sender = async (env, { subject, body, replyTo }) => {
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
      ...(replyTo ? { reply_to: replyTo } : {}),
    }),
  });
  if (!res.ok) throw new Error(`Resend ${res.status}: ${await res.text()}`);
};

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

  // Landing page "Google Play · Closed Testing": the visitor leaves the email
  // of their Google account, help@ adds it to the Play test list by hand and
  // replies (reply_to is the visitor).
  app.post('/tester', async (c) => {
    if (c.env.RATE_LIMITER) {
      const key = c.req.header('CF-Connecting-IP') ?? 'unknown';
      const { success } = await c.env.RATE_LIMITER.limit({ key });
      if (!success) return c.json({ error: 'too many requests, try again later' }, 429);
    }

    const json = await c.req.json().catch(() => null);
    const req = parseTesterRequest(json);
    if ('error' in req) return c.json({ error: req.error }, 400);
    if (req.bot) return c.json({ ok: true });

    try {
      await send(c.env, {
        subject: `${SUBJECT_PREFIX}Closed testing (Android): ${req.email}`,
        body: [
          'Please add this Google account to the Play closed test, then reply.',
          '',
          `Email: ${req.email}`,
          `Page language: ${req.lang}`,
          `Sent: ${new Date().toISOString()}`,
        ].join('\n'),
        replyTo: req.email,
      });
    } catch (e) {
      console.error('tester send failed', e);
      return c.json({ error: 'could not send' }, 502);
    }
    return c.json({ ok: true });
  });

  return app;
}

export default createApp();
