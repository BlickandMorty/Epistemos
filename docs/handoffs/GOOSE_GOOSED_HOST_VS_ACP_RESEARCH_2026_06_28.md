# Research: "Why not just use the goosed host?" — goosed REST vs ACP grafting (2026-06-28)

Owner asked to research the best method for the residual no-ACP-method gaps
(prompts, permissions, MCP-app) and "just go with the goosed host." Researched
the actual goose source + tested live binaries. Findings:

## What Epistemos runs today
- `GooseRuntimeSupervisor` launches **`goose serve --host --port --with-builtin`**.
- `goose serve` = "Start ACP server over HTTP and WebSocket" → it uses
  `goose::acp::transport::create_router` (LEAN, by design).
- **Verified by direct probe** of a live `goose serve`: only `/acp` (WebSocket),
  `/health` (200), `/status` (200) respond. **Everything REST 404s**:
  `/prompts`, `/config/providers`, `/agent/tools`, `/config/read`, `/reply` → 404.
- So the "dead REST" premise is **correct** — `goose serve` genuinely does not
  serve the REST API. Grafting onto ACP was the right call for this server.

## The @/api client is already pointed at goosed
- `renderer.tsx` does `client.setConfig({ baseUrl: window.electron.getGoosedHostPort(),
  headers: { 'X-Secret-Key': window.electron.getSecretKey() }})`.
- Epistemos's boot shim (`GooseWebBootShim`) **already shims `window.electron`**
  with `getGoosedHostPort → epistemosGoose.baseURL` (goosed `http://127.0.0.1:3284`)
  and `getSecretKey`. So the client config is NOT the blocker — the **server**
  (`goose serve`) not exposing REST is.

## The full REST server EXISTS but is a different binary/architecture
- The full server is **`goosed agent`** (`goose-server` crate, `commands/agent.rs::run`:
  `rest_router.merge(acp_router)`) — REST **and** ACP together. The `goosed` binary
  IS built (`target/.../release/goosed`).
- BUT it listens on **`https://127.0.0.1:3000`** (TLS, fixed port) and exposes the
  **full REST surface**. `goose serve` (ACP) is HTTP + lean.

## ACP SDK capability (verified — 59 methods)
- **No permission method at all** → gap #3 PermissionModal-save has no ACP path.
- **Only `sessionSystemPromptSet`** (no prompt-template CRUD) → gap #6 Prompts has no ACP path.
- `toolsCall_unstable` + `resourcesRead_unstable` DO exist → gap #5 MCP-app IS ACP-graftable.
- `toolsList_unstable` exists (gap #1/#3-load) but needs client-side extension filtering.

## The fork (this is genuinely an owner architecture decision)
- **Path A — keep lean ACP `goose serve` (current, the directive's "preserve the
  WebView/ACP path"):** secure, minimal surface. The no-ACP-method gaps (prompts,
  permissions-save) CANNOT be served → honest-gate them (hide the broken controls
  in ACP mode). MCP-app/tools can still be ACP-grafted.
- **Path B — switch the runtime to `goosed agent` (full REST+ACP, owner's "goosed
  host"):** the upstream UI works almost entirely NATIVELY (prompts, permissions,
  MCP-app, everything) with little/no grafting. Cost: it REVERSES the deliberate
  ACP-only design, exposes the full localhost REST surface to the WebView (still
  secret-key-auth'd + loopback-only + nav-gated), is HTTPS:3000 (TLS cert + port
  rework in the supervisor/boot/health/ACP-URL plumbing), and is a Phase-0-level
  change that must be re-tested end-to-end (the shared test bundle is currently
  blocked by another agent, so it can't be validated this moment).

## Recommendation
Path B is the owner's instinct and would maximize feature-completeness, but it is
a real architecture change (different binary, TLS, full REST surface) that
contradicts the standing "preserve the working WebView/ACP path" constraint and
can't be safely validated while the test bundle is blocked. It should be a
deliberate, owner-confirmed switch — not a silent flip. Path A keeps today's
secure working surface and honestly gates the 2 truly-unbackable controls.
