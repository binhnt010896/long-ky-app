import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';

import { AuthError, requireUser } from '../src/auth';
import type { Env } from '../src/types';

const testEnv = env as unknown as Env;

function request(headers: Record<string, string> = {}): Request {
  return new Request('https://cms-api.example/content', { headers });
}

describe('requireUser', () => {
  it('refuses a request with no Authorization header', async () => {
    await expect(requireUser(request(), testEnv)).rejects.toThrow(AuthError);
  });

  it('refuses a non-Bearer Authorization header', async () => {
    await expect(
      requireUser(request({ Authorization: 'Basic dXNlcjpwYXNz' }), testEnv),
    ).rejects.toThrow(AuthError);
  });

  it('refuses a token a foreign/garbled signature check rejects', async () => {
    const verify = async () => {
      throw new Error('signature verification failed');
    };
    await expect(
      requireUser(request({ Authorization: 'Bearer garbage' }), testEnv, verify),
    ).rejects.toThrow(/invalid or expired/i);
  });

  it('refuses a verified token with no email claim', async () => {
    const verify = async () => ({});
    await expect(
      requireUser(request({ Authorization: 'Bearer x' }), testEnv, verify),
    ).rejects.toThrow(/no verified email/i);
  });

  it('refuses a verified token whose email is not marked verified', async () => {
    const verify = async () => ({ email: 'binhnt.010896@gmail.com', email_verified: false });
    await expect(
      requireUser(request({ Authorization: 'Bearer x' }), testEnv, verify),
    ).rejects.toThrow(/no verified email/i);
  });

  it('refuses a verified, verified-email token not on the allowlist', async () => {
    const verify = async () => ({ email: 'someone-else@gmail.com', email_verified: true });
    const err = await requireUser(request({ Authorization: 'Bearer x' }), testEnv, verify).catch(
      (e) => e,
    );
    expect(err).toBeInstanceOf(AuthError);
    expect((err as AuthError).status).toBe(403);
  });

  it('accepts a verified token for an allowlisted email (case-insensitive)', async () => {
    const verify = async () => ({
      email: 'BinhNT.010896@gmail.com',
      email_verified: true,
    });
    const email = await requireUser(request({ Authorization: 'Bearer x' }), testEnv, verify);
    expect(email).toBe('BinhNT.010896@gmail.com');
  });
});
