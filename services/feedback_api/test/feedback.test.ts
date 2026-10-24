import { describe, expect, it, vi } from 'vitest';

import { type Env, MAX_BODY, createApp } from '../src/index';

const env = {
  RESEND_API_KEY: 're_test',
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

describe('Resend request', () => {
  it('goes admin@ → help@ as plain text with no reply_to', async () => {
    const fetchMock = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(new Response('{"id":"x"}', { status: 200 }));
    const res = await post(createApp(), good);
    expect(res.status).toBe(200);
    const [url, init] = fetchMock.mock.calls[0]!;
    expect(url).toBe('https://api.resend.com/emails');
    expect((init!.headers as Record<string, string>).Authorization).toBe('Bearer re_test');
    expect(JSON.parse(init!.body as string)).toEqual({
      from: 'admin@long-ky.com',
      to: ['help@long-ky.com'],
      subject: good.subject,
      text: good.body,
    });
    fetchMock.mockRestore();
  });

  it('502 when Resend refuses', async () => {
    const fetchMock = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(new Response('nope', { status: 403 }));
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const res = await post(createApp(), good);
    expect(res.status).toBe(502);
    fetchMock.mockRestore();
  });
});

describe('POST /feedback', () => {
  it('sends one email and says ok', async () => {
    const send = vi.fn().mockResolvedValue(undefined);
    const res = await post(createApp(send), good);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true });
    expect(send).toHaveBeenCalledOnce();
    expect(send.mock.calls[0]![1]).toEqual(good);
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
