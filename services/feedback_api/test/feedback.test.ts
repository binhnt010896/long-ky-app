import { describe, expect, it, vi } from 'vitest';

import { type Env, MAX_BODY, createApp } from '../src/index';
import { buildMime } from '../src/mail';

const env = {
  FEEDBACK_EMAIL: { send: vi.fn() },
  FEEDBACK_FROM: 'admin@long-ky.com',
  FEEDBACK_TO: 'help@long-ky.com',
} as Env;

const good = {
  subject: '[Long Ký] Báo sai sót: Trần Hưng Đạo (person tran-hung-dao)',
  body: 'Sai ở đâu: Nội dung\nGhi chú: Sai năm',
};

function post(app: ReturnType<typeof createApp>, payload: unknown, e: Env = env) {
  return app.request(
    '/feedback',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: typeof payload === 'string' ? payload : JSON.stringify(payload),
    },
    e,
  );
}

function decodeBody(raw: string): string {
  const b64 = raw.split('\r\n\r\n')[1]!.replace(/\s/g, '');
  return new TextDecoder().decode(Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)));
}

describe('buildMime', () => {
  const raw = buildMime({
    from: 'admin@long-ky.com',
    to: 'help@long-ky.com',
    subject: good.subject,
    body: good.body,
    messageId: 'fixed',
    date: new Date('2026-10-24T00:00:00Z'),
  });

  it('addresses admin@ → help@ with no Reply-To', () => {
    expect(raw).toContain('From: admin@long-ky.com\r\n');
    expect(raw).toContain('To: help@long-ky.com\r\n');
    expect(raw).not.toMatch(/reply-to/i);
    expect(raw).toContain('Message-ID: <fixed@long-ky.com>');
  });

  it('keeps Vietnamese intact in subject and body', () => {
    const enc = raw.match(/Subject: =\?UTF-8\?B\?(.+)\?=/)![1]!;
    expect(new TextDecoder().decode(Uint8Array.from(atob(enc), (c) => c.charCodeAt(0)))).toBe(
      good.subject,
    );
    expect(decodeBody(raw)).toBe(good.body);
  });

  it('wraps body lines at 76 characters', () => {
    const long = buildMime({
      from: 'a@b.c',
      to: 'd@e.f',
      subject: 'x',
      body: 'Ế'.repeat(500),
    });
    for (const line of long.split('\r\n')) expect(line.length).toBeLessThanOrEqual(76 + 40);
    expect(decodeBody(long)).toBe('Ế'.repeat(500));
  });
});

describe('POST /feedback', () => {
  it('sends one email and says ok', async () => {
    const send = vi.fn().mockResolvedValue(undefined);
    const res = await post(createApp(send), good);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true });
    expect(send).toHaveBeenCalledOnce();
    expect(decodeBody(send.mock.calls[0]![1] as string)).toBe(good.body);
  });

  it.each([
    ['not JSON', 'nope'],
    ['not an object', '[]'],
    ['missing body', { subject: good.subject }],
    ['header injection', { ...good, subject: `${good.subject}\r\nBcc: x@y.z` }],
    ['wrong prefix', { ...good, subject: 'Hello' }],
    ['empty body', { ...good, body: '  ' }],
    ['body too long', { ...good, body: 'x'.repeat(MAX_BODY + 1) }],
  ])('400 for %s, and sends nothing', async (_name, payload) => {
    const send = vi.fn();
    const res = await post(createApp(send), payload);
    expect(res.status).toBe(400);
    expect(send).not.toHaveBeenCalled();
  });

  it('502 when the mail relay fails', async () => {
    const send = vi.fn().mockRejectedValue(new Error('boom'));
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const res = await post(createApp(send), good);
    expect(res.status).toBe(502);
  });

  it('429 when rate limited', async () => {
    const send = vi.fn();
    const limited = {
      ...env,
      RATE_LIMITER: { limit: async () => ({ success: false }) },
    } as Env;
    const res = await post(createApp(send), good, limited);
    expect(res.status).toBe(429);
    expect(send).not.toHaveBeenCalled();
  });

  it('allows any origin (the web build posts cross-origin)', async () => {
    const res = await post(createApp(vi.fn()), good);
    expect(res.headers.get('access-control-allow-origin')).toBe('*');
  });
});
