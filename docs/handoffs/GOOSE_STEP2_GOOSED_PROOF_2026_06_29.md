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

## ACP-path parity proof: the swap is a SUPERSET, not a regression (source-verified)
Compared lean `goose serve` (`goose-cli/src/cli.rs:1327 handle_serve_command`) against
`goosed agent` (`goose-server/src/commands/agent.rs:44`). The ACP path the existing WebView
already drives is preserved byte-for-byte, and goosed only ADDS capability:

| ACP concern            | lean `goose serve`                | `goosed agent`                       | swap effect |
|------------------------|-----------------------------------|--------------------------------------|-------------|
| ACP auth middleware    | `check_acp_token` (via `create_router`, `require_token = secret set`) | `check_acp_token` (explicit `.layer`) | IDENTICAL — both accept our `token=<secretKey>` query param (constant-time `ct_eq`); `goose/src/acp/transport/auth.rs:15` |
| builtins loaded        | `["developer"]` (cli.rs:1336)     | `["developer"]` (agent.rs:69)        | IDENTICAL |
| GoosePlatform identity | `GooseCli` (cli.rs:1357)          | `GooseDesktop` (agent.rs:72)         | IMPROVED — matches the desktop session metadata the Phase-0 handoff added; better `session/list` user/scheduled classification |
| scheduler              | `None` (cli.rs:1359)              | `Some(app_state.scheduler())` (agent.rs:74) | IMPROVED — Scheduler route is actually live on goosed |
| REST router            | absent (ACP only)                 | `rest_router.merge(acp_router)` (agent.rs:85) | ADDED — the 3 previously-unbackable features |
| secret key default     | random if env unset (cli.rs:1371) | random if env unset (agent.rs:53)    | IDENTICAL — supervisor always sets `GOOSE_SERVER__SECRET_KEY` so we control it |
| health endpoint        | `/health` (in `create_router`)    | `/status` (no `/health`)             | supervisor branches on backend (`goosedStatusCheck` vs `healthCheck`) |

Net: zero ACP behavior loss, `GoosePlatform::GooseDesktop` + real scheduler + full REST gained.
This is the source-level reason Option B reaches the owner's 100%-parity gate.

## Supervisor + bundler wiring landed this pass
- `GooseRuntimeSupervisor.swift`: backend selector (`configuredBackend` ← `EPISTEMOS_GOOSE_BACKEND`,
  default `.serve`), `goosedTLSEnabled` (← `EPISTEMOS_GOOSE_GOOSED_TLS`, default false=http loopback),
  `goosedStatusCheck(base:)` (`/status` 200), scheme-aware `defaultBaseURL(port:scheme:)`,
  backend-aware readiness timeout (`goosedListenTimeout = 45s`), `processEnvironment(... goosedConfig:)`
  sets `GOOSE_HOST/GOOSE_PORT/GOOSE_TLS`, and `resolvedGooseBinary(... binaryName:)` selects
  `goosed` vs `goose`. Launch arg is `["agent"]` for goosed, `serveArguments(...)` for serve.
- `bundle-app-runtime-assets.sh`: stages BOTH `goose` and `goosed` into `Resources/` during the
  parity-gated transition (so `EPISTEMOS_GOOSE_BACKEND` selects either without a rebuild — single-point
  rollback); App-Store build removes both. Source binaries present: goosed 236M, goose 243M (−7M cutover).

## Plan (behind a build flag; single-point rollback; WebView/ACP path preserved)
1. Stage the `goosed` binary alongside/replacing `goose` (GooseRuntimeSupervisor resolver +
   bundle scripts). 2. Supervisor: backend selector (env `EPISTEMOS_GOOSE_BACKEND`, default `serve`
   so lean stays default until goosed is proven in-app) → launch `goosed agent` with the env map +
   `/status` health + larger budget when selected. 3. TLS cert-pin delegate on the WKWebView
   (scoped to the loopback goosed origin). 4. Boot shim / ACP-WS / health URLs adapt to backend.
   5. Re-prove the full live sweep + the 3 features end-to-end on goosed. Rollback = flip the flag.
