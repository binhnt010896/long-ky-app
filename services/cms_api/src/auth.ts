import { createRemoteJWKSet, jwtVerify } from 'jose';

import type { Env } from './types';

export class AuthError extends Error {
  status: number;
  constructor(message: string, status = 401) {
    super(message);
    this.status = status;
  }
}

/** The claims this Worker actually cares about from a Firebase ID token. */
export interface IdTokenClaims {
  email?: string;
  email_verified?: boolean;
}

/** Verifies a Firebase ID token's signature/issuer/audience and returns its
 * claims. A separate, injectable type from [requireUser] below so tests can
 * swap in a fake verifier — the real implementation needs a live fetch to
 * Google's JWKS endpoint, which a unit test shouldn't depend on. */
export type IdTokenVerifier = (token: string, projectId: string) => Promise<IdTokenClaims>;

// Firebase ID tokens are signed with Google's own "securetoken" service
// account keys — this is Google's own published JWKS for verifying them,
// not anything specific to this project. Cached across requests by [jose]
// itself (respects the JWKS response's own cache headers).
const GOOGLE_SECURETOKEN_JWKS = createRemoteJWKSet(
  new URL(
    'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
  ),
);

export const verifyFirebaseIdToken: IdTokenVerifier = async (token, projectId) => {
  const { payload } = await jwtVerify(token, GOOGLE_SECURETOKEN_JWKS, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
  });
  return payload as IdTokenClaims;
};

/** Verifies the request's `Authorization: Bearer <Firebase ID token>` header
 * and checks the token's email against [Env.ALLOWED_EMAILS]. Returns the
 * verified email on success; throws [AuthError] (401 for "not a valid
 * caller", 403 for "valid caller, not allowed") on anything else — a
 * missing header, a garbled/expired/foreign token, an unverified email, or
 * an email that isn't on the allowlist.
 *
 * [verify] defaults to the real Google-JWKS check but can be swapped for a
 * fake in tests. */
export async function requireUser(
  request: Request,
  env: Env,
  verify: IdTokenVerifier = verifyFirebaseIdToken,
): Promise<string> {
  const header = request.headers.get('Authorization');
  if (!header || !header.startsWith('Bearer ')) {
    throw new AuthError('Missing bearer token');
  }
  const token = header.slice('Bearer '.length).trim();
  if (!token) {
    throw new AuthError('Missing bearer token');
  }

  let claims: IdTokenClaims;
  try {
    claims = await verify(token, env.FIREBASE_PROJECT_ID);
  } catch {
    // Deliberately one message for "malformed", "wrong project", "expired",
    // and "signed by someone else" — none of that detail should leak to an
    // unauthenticated caller.
    throw new AuthError('Invalid or expired token');
  }

  if (!claims.email || claims.email_verified !== true) {
    throw new AuthError('Token has no verified email');
  }

  const allowed = env.ALLOWED_EMAILS.split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  if (!allowed.includes(claims.email.toLowerCase())) {
    throw new AuthError(`${claims.email} is not allowed to use the CMS`, 403);
  }

  return claims.email;
}
