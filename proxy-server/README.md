# Epistemos MAS Proxy — reference server (Plan 1-MAS §5 / §11 R4)

The **server side** of the Surface B paywall. The app (`EpistemosProxyClient` +
`AgentSubscriptionService`) is the client; this is the receipt-gated proxy it
talks to. **Deploy this separately** (any Node 20+ host) — it is not part of
the Mac app bundle and holds the provider API keys that must never ship in the
binary.

## Contract (exactly what the client expects)

| Endpoint | Request | Response |
|---|---|---|
| `POST /v1/auth/verify-receipt` | `{ "storekit_jws": "<JWS>", "app_account_token": "<uuid?>" }` | `{ "token": "<jwt>", "expiresAt": "<ISO8601>" }` |
| `POST /v1/chat/completions` | OpenAI-compatible body, `Authorization: Bearer <token>` | SSE stream (OpenAI-compatible `data:` chunks) |
| `POST /v1/webhooks/appstore` | App Store Server Notifications V2 (`signedPayload` JWS) | `200` (idempotent, prompt) |

`agent_core`'s `OpenAICompatibleProvider` points its base URL at
`{PROXY_BASE}/v1`; the short-lived token is the bearer. The client refreshes
the token below ~20% of its TTL (`EpistemosProxySession.needsRefresh`).

## Why each piece

- **verify-receipt** validates the StoreKit 2 `Transaction` JWS against Apple
  (App Store Server API — the `.p8` key + x5c chain to Apple's root; the
  deprecated `verifyReceipt` is never used), confirms an active entitlement,
  then mints a short-lived JWT bound to the `appAccountToken` for
  rate-limiting. Provider keys never leave the server.
- **chat/completions** authenticates the JWT, then streams from the real
  provider (Anthropic/OpenAI) with the server-held key. OpenAI-compatible in
  and out so the in-app `OpenAICompatibleProvider` needs no special casing.
- **webhook** consumes App Store Server Notifications V2 to revoke/refresh
  entitlements on renewal/cancel/refund (respond 2xx promptly; idempotent).

## Configure (env)

```
PORT=8787
SESSION_JWT_SECRET=<32+ random bytes, base64>   # signs the short-lived tokens
SESSION_TTL_SECONDS=3600
APPLE_BUNDLE_ID=com.epistemos.appstore
APPLE_ISSUER_ID=<App Store Connect issuer id>
APPLE_KEY_ID=<.p8 key id>
APPLE_PRIVATE_KEY=<contents of the .p8, PEM>    # App Store Server API auth
APPLE_ENVIRONMENT=Production                      # or Sandbox
UPSTREAM_PROVIDER=anthropic                        # anthropic | openai
UPSTREAM_BASE_URL=https://api.anthropic.com
UPSTREAM_API_KEY=<the provider key — server-only>
UPSTREAM_MODEL=claude-sonnet-4-6
```

## Run

```
npm install
npm run build && npm start      # or: npm run dev
```

## Status

Reference implementation of the full contract. **The App Store Server API JWS
verification path (`src/appstore.ts`) needs real Apple credentials to run
end-to-end** — with `APPLE_ENVIRONMENT=Sandbox` and a sandbox StoreKit
purchase from the app, it completes the P3 acceptance (purchase → token →
cloud turn). Without credentials it starts and serves, and
`verify-receipt` returns a clear 500 naming the missing env.
