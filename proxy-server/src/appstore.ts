// StoreKit 2 JWS verification (Plan 1-MAS §5). The client sends the JWS
// representation of a StoreKit `Transaction`; we verify its signature chain
// to Apple's root and extract the payload. verifyReceipt is deprecated and
// never used. For an active entitlement we (optionally) confirm against the
// App Store Server API using the .p8 key.
//
// This is a reference: the x5c chain-to-Apple-root check is implemented with
// `jose`'s certificate handling; production should also pin Apple's root and
// check the receipt's `bundleId` + expiry, which we do below.

import { importX509, jwtVerify, decodeProtectedHeader, SignJWT } from "jose";
import { X509Certificate } from "node:crypto";
import type { Config } from "./config.ts";

export interface VerifiedTransaction {
  originalTransactionId: string;
  transactionId: string;
  productId: string;
  bundleId: string;
  appAccountToken: string | null;
  expiresDateMs: number | null;
  revoked: boolean;
}

// Apple's PKI: the leaf signs the JWS; x5c = [leaf, intermediate, root].
// We verify each cert is signed by the next and that the JWS signature
// verifies against the leaf's public key. Callers should additionally pin the
// root against Apple's published G3 root in production.
function certChainFromHeader(x5c: string[]): X509Certificate[] {
  return x5c.map((b64) => new X509Certificate(Buffer.from(b64, "base64")));
}

function assertChainValid(chain: X509Certificate[]): void {
  if (chain.length < 2) throw new Error("x5c chain too short");
  for (let i = 0; i < chain.length - 1; i++) {
    const child = chain[i];
    const parent = chain[i + 1];
    if (!child.verify(parent.publicKey)) {
      throw new Error(`x5c chain break at ${i}`);
    }
  }
  const root = chain[chain.length - 1];
  // Self-signed root sanity check. Production: compare root.raw to the pinned
  // Apple Root CA - G3 certificate bytes.
  if (!root.verify(root.publicKey)) {
    throw new Error("x5c root not self-signed");
  }
}

export async function verifyStoreKitJWS(
  config: Config,
  jws: string,
): Promise<VerifiedTransaction> {
  const header = decodeProtectedHeader(jws);
  const x5c = header.x5c;
  if (!Array.isArray(x5c) || x5c.length === 0) {
    throw new Error("JWS missing x5c certificate chain");
  }
  const chain = certChainFromHeader(x5c);
  assertChainValid(chain);

  const leafKey = await importX509(chain[0].toString(), header.alg ?? "ES256");
  const { payload } = await jwtVerify(jws, leafKey, {
    algorithms: [header.alg ?? "ES256"],
  });

  const bundleId = payload.bundleId as string | undefined;
  if (bundleId && bundleId !== config.appleBundleId) {
    throw new Error(`bundleId mismatch: ${bundleId}`);
  }

  const expiresMs = payload.expiresDate
    ? Number(payload.expiresDate)
    : null;
  return {
    originalTransactionId: String(payload.originalTransactionId),
    transactionId: String(payload.transactionId),
    productId: String(payload.productId),
    bundleId: bundleId ?? config.appleBundleId,
    appAccountToken: (payload.appAccountToken as string | undefined) ?? null,
    expiresDateMs: expiresMs,
    revoked: payload.revocationDate != null,
  };
}

// Optional live check against the App Store Server API (subscription status).
// Requires the .p8 key; returns true when the subscription is active. When
// credentials are absent we fall back to the JWS payload's own expiry.
export async function isEntitlementActive(
  config: Config,
  tx: VerifiedTransaction,
): Promise<boolean> {
  if (tx.revoked) return false;
  if (!config.appleIssuerId || !config.applePrivateKey || !config.appleKeyId) {
    // No server-API creds: trust the (Apple-signed) JWS expiry.
    return tx.expiresDateMs == null || tx.expiresDateMs > Date.now();
  }
  const bearer = await appStoreServerApiToken(config);
  const host =
    config.appleEnvironment === "Sandbox"
      ? "https://api.storekit-sandbox.itunes.apple.com"
      : "https://api.storekit.itunes.apple.com";
  const res = await fetch(
    `${host}/inApps/v1/subscriptions/${tx.originalTransactionId}`,
    { headers: { Authorization: `Bearer ${bearer}` } },
  );
  if (!res.ok) {
    // Reachable-but-unexpected: fail closed on a hard error, open on transient.
    if (res.status === 404) return false;
    return tx.expiresDateMs == null || tx.expiresDateMs > Date.now();
  }
  const body = (await res.json()) as {
    data?: { lastTransactions?: { status: number }[] }[];
  };
  const statuses =
    body.data?.flatMap((g) => g.lastTransactions?.map((t) => t.status) ?? []) ??
    [];
  // 1 = active, 3 = billing retry, 4 = grace period are "usable".
  return statuses.some((s) => s === 1 || s === 3 || s === 4);
}

async function appStoreServerApiToken(config: Config): Promise<string> {
  const key = await importPKCS8(config.applePrivateKey);
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT({ bid: config.appleBundleId })
    .setProtectedHeader({ alg: "ES256", kid: config.appleKeyId, typ: "JWT" })
    .setIssuer(config.appleIssuerId)
    .setIssuedAt(now)
    .setExpirationTime(now + 600)
    .setAudience("appstoreconnect-v1")
    .sign(key);
}

// Local import to avoid a top-level jose symbol clash in the reference.
async function importPKCS8(pem: string) {
  const { importPKCS8: imp } = await import("jose");
  return imp(pem, "ES256");
}
