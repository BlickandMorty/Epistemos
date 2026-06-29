# WebView-host adversarial review — owner-symptom root causes (2026-06-29)

Independent adversarial review of the OWNER-FACING Goose surface (`GooseWebSurfaceView` +
`GooseACPEventBridge` lifecycle) targeting the owner's reported intermittent symptoms. It found the
likely ROOT CAUSES — real live bugs, not stale-build artifacts. Shared root cause: `.running` and
bridge-`.connected` are reached ASYNCHRONOUSLY, but the surface only reacted to the FIRST poll of
each and had no observer to re-drive load / connect / post-sync reload.

## Findings → fixes (all committed; build green)

| # | Sev | Finding | Owner symptom | Fix |
|---|-----|---------|---------------|-----|
| H1 | HIGH | `loadWhenReady` polls `.running` for a fixed 26s; `onChange(.running)` was a no-op. goosed's readiness budget is 45s → the poll ALWAYS gives up first → surface stuck on placeholder forever, Restart button hidden (status is `.running`) | "Apps/Session-History/chat loading failures that never self-heal" | `handleRuntimeStatusChange(.running)` now drives the surface via an idempotent `driveSurface(connection:)` (guarded by `drivenConnectionKey` so the fast path never double-loads). Late `.running` now loads. |
| H2 | HIGH | The ACP bridge can terminally fail (N consecutive reconnects during a brief goose blip) while the supervisor stays `.running`; nothing re-drives `connect`, and provider key-sync only runs on a fresh connect → credentials never re-mirror | "providers not auto-loading", "Failed to load provider credentials", "model-picker errors" | new `onChange(acpBridge.status)` → `handleBridgeStatusChange`: when the bridge is `.failed`/`.disconnected` but the runtime is `.running`, re-drive `connectNativeACP` (idempotent; fires once per terminal-fail transition, not a spin) |
| H3 | HIGH | Startup race: the WebView loads in PARALLEL with the native key-sync and is never reloaded after the keys land → the SPA reads Goose's credential state before sync and caches "Failed to load provider credentials" | "Settings→Auth: Failed to load provider credentials" (strongest match) | bridge bumps a new `providersSyncedGeneration` after sync+activate; new `onChange` → `reloadSurfaceAfterProviderSync` reloads the SPA once per connection so it re-reads populated state |
| M2 | MED | `healthCheck` had no request timeout (default 60s) → a hung-but-listening goose isn't detected for ~minutes | "loading failures" that linger | `healthCheck` now sets `timeoutInterval = 5` (matches `goosedStatusCheck`) |
| M3 | MED | The first `listGooseProviders` after `initialize` can fail while Goose warms up → every key skipped `providerInventoryUnavailable`, result discarded → credentials unmirrored for the whole session | "Failed to load provider credentials", "providers not auto-loading" | new `syncProviderKeys` retries the sync up to 4× with 0.5s backoff when the inventory was unreachable |
| L1 | LOW | `customACPStatusLabel` showed "blocked: N" instead of "ready" when connected with any benign diagnostic | owner expects exactly "custom ACP Goose ready" | `.connected` now reads exactly "ready" (diagnostics surfaced separately; false-green still impossible) |
| L3 | LOW | `restartSurface` had no re-entrancy guard (double-tap overlaps two restarts) | — | `isRestarting` guard |

Deferred (separate follow-up, lower risk/impact): M1 (a transient permission/elicitation send error
flips `.connected → .failed` false-red while the socket is fine), L2 (onDisappear's non-awaited
disconnect can clobber a fast reappear-reconnect).

## Verified CORRECT by the review (NOT owner-symptom sources)
- No false-GREEN "ready": both labels gate "ready" strictly on `.connected` after `initialize()`.
- Transient socket drop recovers within the 6-attempt budget (fresh transport + re-init + re-sync).
- Supersede/disconnect close the previous client — no WS leak.
- The native Models view is robust (generation-guarded + 20s timeout + atomic capture).

## Net
H1+H2+H3 are the three that most plausibly produced the owner's "intermittent
providers/credentials/loading failures that don't self-heal." The fix makes the supervisor-status
and bridge-status observers the authoritative, idempotent drivers of connect→load→post-sync-reload —
WITHOUT rewriting the working WebView/ACP path (the fast path is unchanged; these only add recovery
for the async-late and failure cases). Re-runnable proof of the underlying ACP data path stays green
(`goose-acp-live-probe.sh`); the in-app recovery behavior needs an owner smoke test (kill+restart
goose serve with Goose open → surface recovers instead of sticking).
