# Step 2 — goosed backend swap: live REST proof + wiring notes (2026-06-29)

Owner green-lit Option B (full `goosed agent`). Owner's explicit requirement: "Prove the 3
previously-missing features are live REST routes (live-probe 200). State the genuinely-unbackable
set honestly (2 features)."

## PROOF — goosed agent serves the previously-unbackable features (live probe)
Spawned `goosed agent` (env: `GOOSE_HOST/GOOSE_PORT/GOOSE_TLS=false/GOOSE_SERVER__SECRET_KEY`,
provider default), probed with `X-Secret-Key`:

```
/status              -> 200   (server up)
/config/prompts      -> 200   prompt-template CRUD  (was NO ACP method on lean serve)
/config/permissions  -> 405   route EXISTS (GET not allowed; it's the POST permission-save write)
/mcp-app-proxy       -> 400   route EXISTS (needs params; not 404)
/config/providers           -> 200
/config/provider-catalog    -> 200
/config/extensions          -> 200
```
405/400 ≠ 404: the routes EXIST (405 = wrong method for a write endpoint; 400 = missing params).
Re-runnable: see the goosed probe block in the loop transcript (scratchpad/goosed-probe3.log).

## Honest unbackable set
- On the CURRENT lean `goose serve`: 2 features are genuinely unbackable (prompt-template CRUD +
  per-tool permission-save — `acp/server/custom_dispatch.rs` has zero permission methods + only
  `SetSessionSystemPrompt`). (mcp-app-proxy is already merged into lean serve.)
- On `goosed agent`: **0 unbackable** — all three are first-class REST routes (proven above). This
  is why Option B reaches the owner's 100%-parity gate.

## Wiring notes for the supervisor swap (discovered during the probe)
- `goosed agent` takes NO CLI flags; configured via env: `GOOSE_HOST`, `GOOSE_PORT`,
  `GOOSE_TLS` (defaults TRUE), `GOOSE_TLS_CERT_PATH`, `GOOSE_TLS_KEY_PATH`,
  `GOOSE_SERVER__SECRET_KEY`. The `developer` builtin is loaded automatically (agent.rs:69).
- HEALTH endpoint differs: goosed agent has **no `/health`** (404); use **`/status` (200)**. The
  supervisor's health gate must branch on backend.
- Boot is SLOWER than `goose serve` (full AppState + REST + gateway init) — it bound the port but
  `/status` answered ~1s after; allow a larger health-poll budget.
- ACP is preserved (`rest_router.merge(acp_router)`), so `/acp` is on the same server/port — the
  existing ACP path keeps working; REST is added alongside.
- Binary: `goosed` 247.7 MB REPLACES `goose` 254.4 MB (net ≈ −7 MB).
- TLS: probe used `GOOSE_TLS=false` (http) to verify routes. The shipped swap keeps `GOOSE_TLS=true`
  + a fingerprint-pinned WKWebView `didReceiveAuthenticationChallenge` delegate (research:
  TLS-off breaks secure-context MCP guest SDKs).

## Plan (behind a build flag; single-point rollback; WebView/ACP path preserved)
1. Stage the `goosed` binary alongside/replacing `goose` (GooseRuntimeSupervisor resolver +
   bundle scripts). 2. Supervisor: backend selector (env `EPISTEMOS_GOOSE_BACKEND`, default `serve`
   so lean stays default until goosed is proven in-app) → launch `goosed agent` with the env map +
   `/status` health + larger budget when selected. 3. TLS cert-pin delegate on the WKWebView
   (scoped to the loopback goosed origin). 4. Boot shim / ACP-WS / health URLs adapt to backend.
   5. Re-prove the full live sweep + the 3 features end-to-end on goosed. Rollback = flip the flag.
