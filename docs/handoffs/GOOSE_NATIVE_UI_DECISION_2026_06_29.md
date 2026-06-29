# Goose UI architecture — native Epistemos UI decision (2026-06-29)

Owner stated the ideal: **higher-quality UI + more UI control for Epistemos, even if harder.**
A 4-angle multi-agent research workflow (feasibility/backend, effort/phasing, quality/control,
MAS/risk) was run. Verdict below. Composes with the backend question: **a native UI and
"switch to `goosed agent`" are the same decision pointing the same way.**

## Verdict: GREEN-LIGHT a native UI — as a flagged, per-route, parity-gated migration (NOT a rewrite)

It is feasible, directly serves the owner's goal, and the expensive plumbing is **already built
and probe-verified**. The honest cost is **parity drift + owning two front-ends for months** —
real, multi-week, and only containable by a test harness (not discipline).

### Why it's feasible (~90% native, hybrid for the rest)
- **~7/10 route families are pure ACP and already have a working native client:**
  `GooseACPClient.swift` (633 lines) + `GooseACPProtocol.swift` (1146) + `GooseACPEventBridge.swift`
  already speak ~28 ACP methods; `GooseACPNativePromptPanels.swift` already renders
  permission/elicitation in SwiftUI. The live probe confirms the methods (catalog 106,
  session new/prompt/stream/end_turn, sources/*, config/extensions/list). So Models, Chat, Auth,
  Sessions, Recipes, Skills, Scheduler, Extensions-read are native-renderable on EXISTING plumbing.
- **3 features have no ACP method** (Prompts editor, per-tool Permission-save, Apps/MCP) — they live
  only in goosed's REST router. MCP-app guest UI is HTML-over-proxy by spec (even Goose renders it
  in a webview) → "native" there = hosting one small WKWebView panel, not the whole app.

### Backend: a true-parity native UI needs `goosed agent`, not lean `goose serve`
`goosed agent` = `rest_router.merge(acp_router)` (one port, one secret, strict superset). It is
**additive** — only adds REST on top of ACP, does NOT break the WebView path. Lean `goose serve`
structurally cannot serve the 3 gap features → it's a dead end for 100% parity. So committing to
native + full parity = committing to `goosed agent` (swap it as its own reviewed step when the
first REST-dependent route lands).

### The strongest concrete argument for native
Going native eventually retires the **3,385-line `stage-goose-web-ui.sh`** (which injects
TypeScript into upstream Goose source at build time) — the single biggest version-bump fragility,
and the likely root of "owner still sees issues" (a graft silently breaking on an upstream change).
It also removes the 1024-line JS↔native affordance bridge + remote-origin WebView from App Review.

### Phased plan (WebView stays working throughout — no silent Phase 1)
- **Phase 0 — Router + toggle (build first):** `GooseSurfaceRouter` resolves each route to
  `.native` or `.web` via `UserDefaults` + env `EPISTEMOS_GOOSE_NATIVE_ROUTES`, **defaulting EVERY
  route to `.web`**. `GooseSurfaceContainerView` owns native chrome + swaps body between a native
  route view and the untouched `GooseWebSurfaceView`. One shared ACP connection. Identical behavior
  to today until a route is explicitly promoted.
- **Slice 1 — native Models (S, Low risk):** the green-light proof. SwiftUI picker over
  `listGooseProviderCatalog()` (106 live) + supported-models + read/saveGooseDefaults. Fixes the
  concrete model-switch parity pain (task #9), near-zero blast radius.
- **Slice 2 — native Chat (M):** the quality prize. Needs a streaming reducer
  (`GooseACPEventBridge` line 269 today only stashes `lastSessionUpdate` — it does NOT accumulate a
  transcript) folding the FULL event taxonomy (text/thought/toolCall/usage), rendered via existing
  `ChatTranscriptPresentation` + `ArtifactBlockView` + `TaggedMarkdownTextView`; composer reuses
  `ChatComposerKeyboard`.
- **Slice 3+ — Auth (M; resolve Keychain-vs-goose-config first), Sessions (S/M), Extensions-read
  (S), Recipes/Skills/Scheduler (M each).**
- **Permanent web (until a goosed-REST client is built):** Prompts editor, Permission-save, MCP-app.

### Effort + risks (blunt)
- Hard 60% (typed ACP client, protocol, event bridge, native prompt panels, probe, test suites) is
  DONE. Remaining = **weeks of focused SwiftUI**, not a from-scratch rewrite. The iceberg is
  **Settings** (33 REST import sites under `components/settings`).
- **#1 risk: parity drift** — the WebView IS Goose (parity-by-construction); native must
  re-implement every surface + silently falls behind on Goose bumps. Mitigation must be MECHANICAL.
- ACP is `_goose/unstable/*` (names can churn vs stable REST) → GOLDEN RULE (live-enumerate) + probe
  in CI on every Goose bump. Streaming fidelity (reduce full taxonomy, not just text deltas).
  Maintenance doubling until WebView retires.
- **De-risk:** keep WebView as the shipped default AND parity oracle; per-route parity tests against
  `scripts/goose-acp-live-probe.*` (CI fails if the probe reaches a route the native view doesn't
  bind); golden-rule grep test; forbid new transport code except the one goosed-REST client.
- **MAS:** native does NOT solve the subprocess story (goose/goosed is still a launched server), but
  it removes the JS↔native bridge + remote WebView content from App Review scrutiny.

### Smallest valuable first step
Phase 0 (router + container, all routes default `.web`) **+ Slice 1 (native Models)**. Effort S,
risk Low, proves the seam end-to-end, fixes model-switch pain, changes nothing else. If that slice
doesn't feel clearly higher-quality in your hands, you've spent very little to learn the full native
bet isn't worth the weeks that follow — the honest test.

## Backend verdict (separate 4-option research, 3 judges, 2–1) — CONVERGES on goosed

A parallel scored research (A lean-ACP-graft / B full-goosed / C hybrid / D native-swift, judged by
parity-first, security/MAS-first, maintenance-first lenses) returned **Option B — full `goosed
agent`** (2 judges B, 1 judge A on a pure-security lens but with B a close #2). This is the SAME
backend the native-UI plan needs. Source-verified facts (these correct earlier assumptions):

- **goosed = `rest_router.merge(acp_router)`** (`goose-server/commands/agent.rs:85`) — full REST +
  the BYTE-IDENTICAL ACP router the lean serve already uses. The 3 "gaps" are first-class REST
  routes, all live-probed 200 (prompts CRUD, `POST /config/permissions`, `/mcp-app-proxy`).
- **CORRECTION — binary is a SWAP, net ≈ −7 MB, NOT +247 MB.** goosed (247.7 MB) *replaces* the
  goose binary already bundled (254.4 MB). My earlier Path-B plan's "+247 MB" was wrong.
- **CORRECTION — `mcp-app-proxy` IS in lean `goose serve`** (`acp/transport/mod.rs:141`
  `.merge(mcp_app_proxy::routes)`). So the residual no-ACP set on lean serve is **2 features
  (per-tool Permission-save + prompt-template CRUD), not 3** — both confirmed unbackable on ACP
  (`custom_dispatch.rs` has zero permission methods, only `SetSessionSystemPrompt`).
- **Zero new subprocess/syscall class** (no `Command::new` in goose-server; tunnel/gateway are
  network-only `tokio::spawn`); required entitlements already ship; the notarized-sandbox-spawns-
  helper constraint is identical to today. MAS = net-neutral-to-better.
- **Security tradeoff (honest):** B exposes the full ~115-endpoint REST (incl. config/secret
  read-write) to the WebView, vs lean serve's minimal `/acp`+`/health`+`/status`. BUT ACP already
  grants shell exec via the developer extension (a strictly higher capability than config edits), so
  B widens an already-trusted, secret-key-gated, nav-gated, loopback surface — it adds no new
  catastrophic class. Mitigate with: keep TLS + a fingerprint-pinned `didReceiveAuthenticationChallenge`
  delegate (NOT blanket-accept; NOT TLS-off, which breaks secure-context MCP guest SDKs), convert
  serve flags to `GOOSE_HOST/GOOSE_PORT/GOOSE_TLS` env, enforce secret-key + nav-gate hygiene.
- **C disqualified:** `PermissionManager` is a process-global `LazyLock` that reads `permission.yaml`
  ONCE and never reloads → any 2-process model persists-but-doesn't-apply a saved permission (a
  silently-degraded control). **D lowest parity:** would hardcode prompt defaults (violates GOLDEN
  RULE) + write to the same stale-cached `permission.yaml`.

**Crucial synergy with native UI:** the security downside of B (full REST exposed to an *untrusted
WebView*) SHRINKS as routes go native — native Swift consumes the REST/ACP directly (trusted code),
not via the WebView. So native-UI + goosed actually *improves* the security profile over time AND
hits 100% parity. The two decisions reinforce each other.

## Unified recommendation
**Backend → switch to `goosed agent` (Option B).** **UI → green-light a phased, flagged,
parity-gated native Epistemos UI.** Together they deliver the owner's stated goals: higher-quality +
more-controlled UI, 100% feature parity (no faked/hidden features), net-smaller bundle, no-worse MAS,
and removal of the 3,385-line graft that is the likely root of "still sees issues." First step stays
small + reversible (router defaulting all routes to `.web` + native Models slice; backend swap as its
own reviewed step when the first REST-only route lands).

### Status
This is a **plan to green-light**, not started — the current directive says preserve the WebView
path + don't start Phase 1. Building Phase 0 router + Slice 1 (and the goosed swap) begins only on
explicit owner go-ahead.

> ⚠️ SUPERSEDED 2026-06-29: owner GREEN-LIT — Plan 1 is now ON Phase 1. Decision locked to **Option 1
> (native FRAME only; chat + the rest stay WebView, RESKINNED indistinguishable from native; route
> migration STOPS after Models — no native chat)**. The per-route native-migration framing above is
> historical except for Models.

## ⚛️ NATIVENESS & UNIFIED LOOK (binding 2026-06-29 — see `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`)
Goose joins the ONE unified Apple-native look (AppKit + WebView + Goose CONVERGE; shared SF Pro `-apple-system` +
shadcn Apple tokens (Action Blue #0066cc) + macOS HIG + macOS-26 Liquid Glass + EXACT SwiftUI springs). **Split:**
NATIVE = frame (window/nav-rail/launcher/permission pop-ups) + Models. WEB-reskinned PERMANENT = chat/sessions/
settings/recipes/skills/scheduler/MCP-app → RETHEME Goose's existing shadcn/Radix/Tailwind + tune its framer-motion
to the verified springs; transparent-over-glass (drawsBackground=false, `EpdocKaTeXPreview.swift:79`) over real
Liquid Glass (`GlassModifiers.swift`/`UnifiedFrostedGlass.swift`; window already isOpaque=false at
`AgentSurfaceWindowController.swift:37`). Deeply fluid ProMotion + MINIMAL; SF Symbols native-chrome-only (web keeps
lucide restyled); GRAPH untouched. CODE-RESEARCH + RESEARCH-BETWEEN-IMPLEMENTATION (read before edit, exhaustive,
no-contradiction). Full verified stack/tokens/springs/glass/code-to-lift: `docs/research/GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md`.
