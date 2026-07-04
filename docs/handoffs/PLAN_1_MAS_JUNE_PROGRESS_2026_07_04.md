# Plan 1-MAS (Vendor June) — Honest Progress Ledger · 2026-07-04

MAS-agent loop, sibling of the PRO/OpenChamber track. Architecture per the
2026-07-04 owner correction: **June's real web UI, vendored like OpenChamber,
backend swapped to in-process engines.** Fork: `~/dev/june-epistemos` pinned at
upstream `a626597` + `epistemos/` overlay (all Epistemos changes are NEW files;
one PATCH_LEDGER row: bun.lock).

## Post-build polish + hardening pass (2026-07-04, own-lane recursive loop)

After Phases 0-3 landed, a deep-verify loop (7 gaps found+fixed, 2 clean passes)
then a recursive integration-polish loop ran, own-lane only. **12 polish/
hardening rounds landed**, each on a gated green build + four-lens mini-pass:

1. Seamless shell — placeholder + WebView background use June's own canvas
   colours (both appearances); styled failure state + working Try Again;
   `window.open`/`target=_blank` externals open in the default browser.
2. Per-session engine lane persists across relaunch (`Session.model`), revalidated;
   delete forgets state + cancels the running turn.
3. All-chats sheet updates live (`@Observable` store).
4. Keyboard focus hands off to June on Agent-tab entry (window-attached guard).
5. `sessionModels` dict eliminated — the persisted record is the source of truth
   (unbounded growth structurally gone).
6. Relative timestamps in the all-chats rows — parity with June's own sidebar.
7. Mascot "agent working" signal verified wired end-to-end (not a dead path).
8. June's `prefers-color-scheme` pinned to the Epistemos theme, not the OS
   (a dark app theme on a light OS no longer renders June light).
9. Shim `hostInvoke` 30s timeout — a native non-reply degrades, never hangs June.
10. Accessibility labels on the loading + failure states.
11. Reveal fade honours Reduce Motion, matching app-wide behaviour.
12. Session titles capped at the store boundary (both create + rename paths).

Also: Apple-FM guardrail trip now falls back to GGUF (§2); honest external-open
commands wired; a CSP (same-origin only) on the `june://` page; user-facing
engine-error copy; a stale-`failureMessage` retry bug fixed. Hardening
disposition across the pass: **0 HIGH, 0 open real MED** (proxy circuit breaker
deferred-with-rationale to the Phase-4 proxy wiring). The own-lane surface is
polished + hardened end-to-end; the only substantive remaining work is
owner-gated (see below).

## Phase status (§9)

| Phase | Code | Build | Runtime evidence | Acceptance |
|-------|------|-------|------------------|------------|
| 0(a) June-in-WKWebView | done | — | Real onboarding + full main shell + nav across views render in a plain WKWebView (spike screenshots); full echo agent turn streamed into June's real transcript; Swift-side bridge contract runtime-proven via `--host-send` spike | **Owner glance pending** |
| 0(b) agent_core turn · 0(c) llama.cpp | reused from first pass (PASS per PLAN_1_MAS_FINALIZATION_2026_07_03) | — | — | PASS |
| 1 Vendor + adapter | done (`4b977aab5`) | BUILD SUCCEEDED (iso-DD) | Bridge contract proven in spike; real classes compiled, **not yet exercised in-app** | **BLOCKED on in-app run** (below) + owner confirm |
| 2 Cloud lane + engine chip | done (`c69a97ddf`, `bfafb7875`) | BUILD SUCCEEDED | Local lanes stream via proven backends; cloud = real SSE client, honestly gated on a Keychain session | Local turn provable in-app; **cloud turn blocked on deployed proxy (owner infra)** |
| 3 Chrome + landing | done (`28b757a51`, `38a7c9a1e`) | BUILD SUCCEEDED | Intents ride June's own menu-bar contract (verified in source); pill/all-chats/mascot-seam built | **In-app run + owner checkpoint pending**; §7 wave-landing visual check at acceptance |
| 4 Paywall + ingest + tools | not started | — | — | **Parked on owner design question** (below) |
| 5 MLX retirement + submission | not started | — | — | Parked until Phases 1-3 owner-confirmed |

## The one blocking dependency

**The in-app acceptance run** (June renders in the Agent tab → send a turn →
on-device answer → relaunch → session survives → chrome check) has been blocked
all session: the PRO track's app instance holds the shared app-group container
(two Epistemos.app processes risk container corruption). The MAS build at
`~/.cache/epistemos-dd-mas/Build/Products/Debug/Epistemos.app` is fully
self-contained (bundled June assets, engines, chrome). **An owner launch
satisfies the same acceptance** — the look sign-off is the owner's per §12.

## Key facts discovered (corrections to the plan's estimates)

- Real command seam = ~111 typed commands in `src/lib/tauri.ts` (plan said 13 —
  grep undercount), but ONE `__TAURI_INTERNALS__` polyfill intercepts all;
  boot needs 17. Window-API coupling is *shallower* than the ~30 estimate.
- `loadFileURL` cannot work — WebKit silently CORS-blocks ES-module scripts on
  file://; assets are served over a `june://` WKURLSchemeHandler (which also
  provides the pinnable origin the hardening doctrine wants).
- June's agent transport is one JSON-RPC-over-WebSocket client; the shim's
  WebSocket stand-in serves it with zero upstream edits. Event vocabulary maps
  ~1:1 onto the engine-delegate shape.
- June's chrome-intent API already exists (its Tauri menu-bar contract):
  new-session / open-session / open-settings — zero fork overlay for chrome.
- R6 fonts: dist ships 5 commercial woff2 (Berkeley Mono, ABC Diatype, Martina
  Plantijn) — excluded at staging AND 404'd by the scheme handler; Apple-bundled
  fallbacks + injected `local()` faces keep every family resolving.
- Resources-glob flattening collides (`Multiple commands produce index.html`);
  bundling rides `bundle-app-runtime-assets.sh` (`bundle_june_web()`, AppStore-
  gated) from the self-gitignored `.june-web-stage/`.

## Hardening dispositions (per-phase, four-lens)

- Phase 1: 0 HIGH / 2 MED (os_accounts placeholder → Phase 4; delta batching →
  once perf producer has data) / 2 LOW.
- Phases 2-3: 0 HIGH / 1 MED-DEFERRED (proxy circuit breaker — lands with
  Phase-4 wiring; engine is single-shot with honest errors until the proxy
  exists) / 4 LOW (all cosmetic or bounded; details in the loop-state memory).

## Perf ([agent_surface] budgets)

Producer landed (`3163a174d`): signposts + JuneAgentPerfMetrics + a Settings →
Diagnostics HealthRow (cold 1500ms / warm 100ms / first-token 1200ms, honest
nils until exercised). Numbers arrive with the first in-app run.

## Shared files touched (PRO sibling rebase notes)

- `LandingView.swift` — 3 lines, MAS side of the .agent `#if` only.
- `SubstrateHealthPanel.swift` — 3 additive lines (JuneAgentHealthRow, EmptyView
  stub on Pro).
- `RootView.swift` — 22 additive lines (MAS pill branch, mutually exclusive
  with the Pro pill).
- `bundle-app-runtime-assets.sh` — 1 function + 1 call line, AppStore-gated.
- Never staged: `.gitignore` (PRO-dirty), anything under `.research-clones/`.

## Parked owner questions

1. **Phase-4 purchase UI**: June's account/billing UI expects its own
   `os_accounts` backend. Map StoreKit onto June's AccountGate look, or use a
   native purchase sheet? (Receipt-exchange client + cloud engine are already
   wired underneath either answer.)
2. **Phase-5 MLX deletion** awaits Phases 1-3 acceptance confirmation.
3. Pre-existing uncommitted tree items NOT touched by this agent:
   `AgentWorkspaceView.swift` (modified) + `JuneWorkspaceStyle.swift`
   (untracked) — residue of the rejected native-look session; owner to keep or
   drop.

## Evidence index

Spike screenshots: session scratchpad `june-spike/{june-spike,june-main-shell,
june-agent-turn}.png`. Fork commits: `46476c3`→`f86d833`+ (overlay). Epistemos
commits: `4b977aab5`, `a36858133`, `c69a97ddf`, `3163a174d`, `bfafb7875`,
`28b757a51`, `38a7c9a1e`. Live agent-facing ledger: memory
`plan1-mas-june-loop-state`.
