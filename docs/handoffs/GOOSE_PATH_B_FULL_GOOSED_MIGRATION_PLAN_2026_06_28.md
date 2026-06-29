# Path B — Migration plan: switch Goose runtime to the full `goosed agent` server

Owner chose "graft ACP gaps now + plan Path B". This is the concrete, reviewed
plan to switch Epistemos from the lean `goose serve` (ACP-only) to the full
`goosed agent` server (REST **and** ACP), which makes the entire upstream Goose UI
work natively — including the no-ACP-method gaps (Prompts editor, per-tool
Permission save) and the MCP-app `/mcp-app-proxy`. **Do NOT flip this silently —
it is a deliberate, owner-confirmed Phase-0 architecture change.**

## Why it works
- `goosed agent` = `goose-server/commands/agent.rs::run` → `rest_router.merge(acp_router)`
  → serves the **full REST API AND `/acp`** on one server. **Verified**: the ACP
  path is preserved (acp_router merged in), so the working WebView/ACP path is NOT
  lost — REST is added alongside it.
- The Web UI `@/api` client is **already** pointed at the goosed host via the boot
  shim (`window.electron.getGoosedHostPort()` → `epistemosGoose.baseURL`,
  `getSecretKey`). So once the server actually serves REST, every dead-REST call
  works with no per-call grafting.

## Required changes (in order)
1. **Bundle/stage the `goosed` binary** (~247 MB, alongside or replacing the ~254 MB
   `goose`). `GooseWebUIResolver`-style staging to App Support + bundle; add to
   xcodegen resources + the Bundle-Runtime-Assets script.
2. **`GooseRuntimeSupervisor`**: launch `goosed agent` (not `goose serve`). Set
   `GOOSE_SERVER__SECRET_KEY` env (already done). Resolve the port: `goosed agent`
   logged `https://127.0.0.1:3000` — confirm whether port is env/flag-configurable
   (`AppState::new(settings.tls)`, `settings`); if fixed, handle the 3000 occupied-
   port + the existing `portReleaseGrace` logic; if configurable, keep the dynamic
   port. Update `serveArguments`, `defaultBaseURL`, health/ACP-URL derivation.
3. **TLS**: `goosed agent` defaults to HTTPS (`settings.tls`). Two options —
   (a) **disable TLS for loopback** if `settings.tls` supports it (simplest: keeps
   the http:// boot baseURL + WKWebView has no cert issue), or (b) keep HTTPS and
   add a `WKNavigationDelegate didReceiveAuthenticationChallenge` that trusts the
   goosed self-signed localhost cert (scoped to 127.0.0.1). Prefer (a) if available.
4. **Boot shim (`GooseWebBootShim`)**: point `epistemosGoose.baseURL` + the derived
   ACP URL at the goosed host (scheme/port from step 2-3). `window.electron`
   already exposes `getGoosedHostPort`/`getSecretKey`/`getAcpUrl` — just feed them
   the goosed endpoints.
5. **Health/ACP URLs**: update `GooseRuntimeSupervisor.defaultBaseURL`/`healthURL`/
   ACP-WS-URL + the `decidePolicy` loopback allowlist (already loopback-only) and
   the `acpAndHealthURLs` test for the new scheme/port.
6. **Grafts**: the existing ACP grafts keep working (their `USE_ACP_CHAT` branch is
   unaffected). Optionally, later, simplify by letting the now-live REST handle the
   currently-grafted calls — but NOT in this migration (preserve working path).
7. **Remove the Path-A honest-gates** (none shipped yet besides toolsCache-via-ACP,
   which still works) — Prompts/Permission-save would work via REST, so no gating
   needed under Path B.

## Risks / open questions to resolve during implementation
- **MAS sandbox — RESEARCHED 2026-06-28, verdict FAVORABLE (was the gating risk).**
  Source-level check of `goose-server/src/commands/agent.rs` + `routes/gateway.rs`:
  - `goosed agent`'s extra tasks (tunnel, gateways) are **network-only**
    `tokio::spawn` futures that open TLS connections — **zero** `Command::new` /
    `process::Command` / `cloudflared` / `ngrok` external-process spawning. This is
    the decisive fact vs CLAUDE.md's hard rule ("MAS sandbox + hardened runtime
    block **subprocess execution** from a notarized app"): `goosed agent` is the
    SAME launched-local-server shape as today's already-accepted `goose serve` — it
    does NOT spawn further subprocesses, so it adds no new sidecar category.
  - The two entitlements its extra tasks need are **already shipped**:
    `com.apple.security.network.client` (outbound tunnel/gateway TLS) +
    `com.apple.security.network.server` (loopback bind), both in
    `Epistemos/Epistemos.entitlements`. Debug builds disable the App Sandbox
    entirely (`Epistemos-Debug.entitlements`), so Path B works in Debug regardless.
  - **Caveats (named, not blockers):** (a) the outbound tunnel/gateway *widens the
    network surface* a MAS reviewer sees vs the lean ACP server — worth a Pro/MAS
    boundary note even though loopback REST stays secret-key-auth'd + nav-gated;
    (b) the shared "is a launched `goose`/`goosed` binary MAS-distributable AT ALL"
    question (Gate 5, still open) is **unchanged** — it applies equally to today's
    `goose serve`, so Path B does NOT regress it. Disabling the tunnel/gateway
    auto-start (they're opt-in features Epistemos never surfaces) would shrink the
    surface back to parity if MAS review flags it.
- **Security surface**: the full localhost REST is exposed to the WebView (still
  secret-key-auth'd + loopback-only + nav-gated by `decidePolicy`). Acceptable
  given the WebView already has goosed access via ACP, but it IS a wider surface.
- **TLS in WKWebView**: self-signed localhost cert handling (step 3) is the main
  technical risk; (a) http loopback avoids it.
- **Port 3000 fixed?**: confirm; affects occupied-port handling.
- **Binary size**: +247 MB if bundling goosed in addition to goose (or swap if the
  ACP path can also come from goosed and `goose` is no longer needed).

## Validation (gated on the shared test bundle unblocking)
- Re-prove the full Goose sweep (provider/session/custom/prompt/route) against
  `goosed agent`.
- Add a live test that the previously-404 REST (`/prompts`, `/agent/tools`,
  `/config/*`) now returns 200 through the configured client.
- Manual: the 6 audit gaps (Prompts, Permission-save, MCP-app, etc.) now function.

## Rollback
Single-point: revert `GooseRuntimeSupervisor` to `goose serve` + the boot baseURL.
The ACP grafts remain valid, so rollback restores today's working ACP-only surface
with zero data migration.

## Recommendation
Sequence: (1) ~~confirm MAS-sandbox viability of `goosed agent` (the gating risk)~~
**DONE 2026-06-28 — verdict favorable (no new subprocess surface; required network
entitlements already shipped); see the MAS bullet above**,
(2) confirm TLS-off-for-loopback or implement the cert-trust delegate, (3) do the
supervisor/boot/staging changes behind a build flag so Path A stays the default
until Path B is proven, (4) validate end-to-end once the test bundle unblocks,
(5) owner flips the flag.
