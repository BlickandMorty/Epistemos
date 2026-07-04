import { test } from "node:test";
import assert from "node:assert/strict";
import { mintSession, verifySession } from "../src/tokens.ts";
import type { Config } from "../src/config.ts";

const config: Config = {
  port: 8787,
  sessionJwtSecret: "test-secret-at-least-32-bytes-long-xxxxx",
  sessionTtlSeconds: 3600,
  appleBundleId: "com.epistemos.appstore",
  appleIssuerId: "",
  appleKeyId: "",
  applePrivateKey: "",
  appleEnvironment: "Sandbox",
  upstreamProvider: "anthropic",
  upstreamBaseUrl: "https://api.anthropic.com",
  upstreamApiKey: "",
  upstreamModel: "claude-sonnet-4-6",
};

test("mint → verify round-trips the claims", async () => {
  const minted = await mintSession(config, {
    appAccountToken: "11111111-2222-3333-4444-555555555555",
    originalTransactionId: "2000000000000001",
    productId: "app.epistemos.agent.monthly",
  });
  assert.ok(minted.token.length > 20);
  assert.ok(Date.parse(minted.expiresAt) > Date.now());

  const claims = await verifySession(config, minted.token);
  assert.equal(claims.originalTransactionId, "2000000000000001");
  assert.equal(claims.productId, "app.epistemos.agent.monthly");
  assert.equal(claims.appAccountToken, "11111111-2222-3333-4444-555555555555");
});

test("a token signed with a different secret fails verification", async () => {
  const minted = await mintSession(config, {
    appAccountToken: null,
    originalTransactionId: "2000000000000002",
    productId: "app.epistemos.agent.monthly",
  });
  const otherConfig = { ...config, sessionJwtSecret: "a-completely-different-secret-value-yyyy" };
  await assert.rejects(() => verifySession(otherConfig, minted.token));
});

test("expiresAt honors the configured TTL", async () => {
  const shortConfig = { ...config, sessionTtlSeconds: 60 };
  const minted = await mintSession(shortConfig, {
    appAccountToken: null,
    originalTransactionId: "2000000000000003",
    productId: "app.epistemos.agent.monthly",
  });
  const ttl = (Date.parse(minted.expiresAt) - Date.now()) / 1000;
  assert.ok(ttl > 50 && ttl <= 61, `ttl ${ttl}`);
});
