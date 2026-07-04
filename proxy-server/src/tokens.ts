// Short-lived session tokens (Plan 1-MAS §5). A signed JWT bound to the
// StoreKit appAccountToken (proxy rate-limiting) + the verified original
// transaction id. TTL is short; the client refreshes below ~20% remaining.

import { SignJWT, jwtVerify } from "jose";
import type { Config } from "./config.ts";

export interface SessionClaims {
  appAccountToken: string | null;
  originalTransactionId: string;
  productId: string;
}

export interface MintedSession {
  token: string;
  expiresAt: string; // ISO8601 — matches EpistemosProxySession.expiresAt
}

function secretKey(config: Config): Uint8Array {
  return new TextEncoder().encode(config.sessionJwtSecret);
}

export async function mintSession(
  config: Config,
  claims: SessionClaims,
): Promise<MintedSession> {
  const now = Math.floor(Date.now() / 1000);
  const exp = now + config.sessionTtlSeconds;
  const token = await new SignJWT({
    aat: claims.appAccountToken ?? undefined,
    otid: claims.originalTransactionId,
    pid: claims.productId,
  })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt(now)
    .setExpirationTime(exp)
    .setSubject(claims.originalTransactionId)
    .sign(secretKey(config));

  return { token, expiresAt: new Date(exp * 1000).toISOString() };
}

export async function verifySession(
  config: Config,
  token: string,
): Promise<SessionClaims> {
  const { payload } = await jwtVerify(token, secretKey(config), {
    algorithms: ["HS256"],
  });
  return {
    appAccountToken: (payload.aat as string | undefined) ?? null,
    originalTransactionId: payload.sub as string,
    productId: payload.pid as string,
  };
}
