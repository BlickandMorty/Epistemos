# KINDRED — Deliberate pre-build review (Claude, 2026-07-06)

ID: EPI-RP-05-KINDRED · Codename: KINDRED · 1Code/Experimental only
Reviewed: the dual-plan wave (plan + prompt + 14-file spine + the dual research report), juxtaposed
against the live repo via a 5-auditor verification fan-out + 1 deep-research pass (Rive licensing).
**Verdict: GO — with the amendments below.** The research's external facts are the cleanest of any
wave so far (every claimed 1Code dependency verified, zero fabrications), and the audit CLOSED four
of its eight open questions. The corrections are placement/reality, not architecture.

## A. What the audit CONFIRMED (research validated — build on it)
- **KF5 1Code facts: 100% confirmed** against `.research-clones/1code`: electron ~39.4.0,
  @anthropic-ai/claude-agent-sdk 0.2.45 (exact pin), react 19.2.1, trpc ^11.7.1 + trpc-electron,
  drizzle-orm ^0.45.1, better-sqlite3 ^12.6.2, jotai/zustand, ai ^6 + @ai-sdk/react ^3, node-pty,
  xterm+addons, monaco ^0.55.1, @zed-industries/codex-acp 0.9.3, @git-diff-view/react, @pierre/diffs.
  `openspec/` exists. The clone already carries local epistemos-* additions + `headless/dist/onecode-shim.js`.
- **Open Q2 CLOSED (streaming):** tRPC **subscription `claude.chat`** (claude.ts:824-857, returns
  `observable<UIMessageChunk>`) wrapped by AI-SDK `IPCChatTransport` (ipc-chat-transport.ts:212
  subscribes; **`reconnectToStream` at :521**). `claude.onMessage` as a name is REFUTED.
  `hasActiveClaudeSessions` (:299) + `abortAllClaudeSessions` (:304) confirmed.
- **Open Q3/Q4 CLOSED (schema):** `sub_chats` = id/name/chat_id(FK cascade)/**session_id**(:75)/
  **stream_id**(:76 — "Track in-progress streams")/mode("plan"|"agent")/messages(JSON text)/
  timestamps. `chats` carries worktree_path/branch/base_branch/pr_url/pr_number. The minichat's
  continuity design (shared sessionId + stream resume) is fully grounded.
- **Open Q1 CLOSED (Rive):** runtimes (rive-ios, @rive-app/canvas) are **MIT, free for commercial**
  ([rive.app/runtimes](https://rive.app/runtimes)); only the authoring/export tier is paid —
  **Cadet $9/mo** ([rive.app/pricing](https://rive.app/pricing)). D4b verdict STANDS; SVG fallback
  not needed for licensing. Rive is NOT yet a dependency — add the RiveRuntime SPM product to the
  **Epistemos target only** in project.yml (never AppStore), then `xcodegen generate`.
- **The presence piggyback seam exists and is exact:** the `/host` WebSocket
  (`ExperimentalHostBridge.swift:50-73`) — persistent, reconnecting, backend→Swift JSON frames
  `{callId, kind, payload}`; adding `kind: "presence:state"` is a ONE-CASE change to
  `handle(kind:payload:)` (:84). Secondary web-side lane: the `/push` bus + `epistemos:push`
  CustomEvent (onecode-shim.js:97-124).
- **Supervisor reality supports the minichat:** ONE Node child, pid+start-time ledgered
  (`AgentSurfaceChildLedger`), swept on start, reaped on quit (EpistemosApp.swift:1332). The backend
  serves SPA+tRPC+/push+/host on one origin — **a second WKWebView shares it; sessions are
  server-side.** No second backend, ever.
- **UniFFI callback pattern exists to copy** (if the Rust lane is ever activated):
  `AgentEventDelegate` (bridge.rs:83, the only callback_interface) + `StreamingDelegate.swift`.
- **CompanionRegistry (companions.rs) is built-but-dormant** with its dispatch capability already
  registered — the natural K7 wiring point for lineage bookkeeping.

## B. Binding amendments (found by juxtaposition — encoded in the spine headers + plan appendix)

### B1 — Presence bus placement: hub = SWIFT, producers = Node backend (+ native)
`agent_core` has **zero** connection to the 1Code backend (grep: no 1code/trpc hits;
ExperimentalAgent/*.swift has zero agent_core references). For a 1Code-only feature, run-state
events originate in the **Node backend** (claude-agent-sdk events inside claude.ts). Routing them
Node→Swift→Rust→Swift would be a pointless double-hop. **v1 architecture:** producers = the Node
backend (electron-shim emits `presence:state` frames on `/host`) + native events (KEELSTONE
reconcile states per its F3 seam); **hub = `CompanionState.swift`** (@Observable, clock-guarded,
Yjs rules); consumers = SwiftUI surfaces + both WebViews. `run_state.rs`/`presence.rs` remain as
the **wire schema** both sides mirror (and the future June-side lane), not v1 code. K1/K2 rewritten
accordingly (see prompt addendum).

### B2 — K0 is largely ALREADY LANDED (KEELSTONE delivered the flags)
Commit `8a1ca87d1`: `KINDRED_ENABLED` + `EPISTEMOS_EXPERIMENTAL` are on ALL THREE Epistemos-target
configs (project.yml :117/:124/:135), absent from AppStore (:250/:255); `Epistemos/App/
AppSurface.swift` ships both surface `#error` guards; the shared `AgentSurface/` runtime trio
exists. **K0 reduces to:** the KINDRED-specific guard pair (`CompanionEditGate.swift` — flag+surface
combos), the `#if KINDRED_ENABLED` file-wrapping sweep, and the CI leak-detector job. Note the
implication: the main dev target now ALWAYS builds with KINDRED on; "defaults row" in CI = the
AppStore target build + symbol scan.

### B3 — CompanionModel: EXTENSION, never rewrite (and the doctrine amendment is explicit)
The live model is 479 lines (id/.unique, name, tagline, bodyKindRaw, accentHex, identityHash,
createdAt, lastInteractedAt, archivedAt + the CompanionBodyKind grammar); lifecycle lives in
`CompanionState.swift`; there is NO VersionedSchema and users have persisted rows
(seedDefaultIfEmpty guarantees ≥1). Rules: new fields land as **optional/defaulted** properties
(lightweight migration); never rename/remove/retype; coupled call sites = CompanionRosterEntry
(:287-297), CompanionCreationFlow.swift:322 (deleted in K7), identityHash recompute (:99),
DeterministicPRNG seed. **The v1.6 "cosmetic-only" doctrine comment (CompanionModel.swift:7-11) is
deliberately superseded — rewrite that comment to the bound-vs-gated doctrine in the same commit.**

### B4 — JS bundle gating: native-injection gate (single webpack bundle reality)
js-editor builds ONE **webpack** bundle (not esbuild — the repo CLAUDE.md is stale) shared by both
targets, with no DefinePlugin/env mechanism. v1 honest gate: `embodied-presence.ts`/
`presence-bridge.ts` are **inert unless the Swift side injects the companion bootstrap** (a
`#if KINDRED_ENABLED` user-script/bridge handle). MAS never injects → no companion behavior.
Follow-up option if stricter exclusion is desired: a DefinePlugin variant staging a second bundle
for the AppStore target (weigh against the "stable resource graph across schemes" design).

### B5 — Minichat: reuse THE backend; fix the single-webview bridge assumption
`ExperimentalStateBridge.shared.webView` is a single weak ref (last-set wins) — the minichat
requires **per-webview routing** (registry keyed by webview identity); each webview already gets
its own shim WKUserScript injection (webview-local — fine). `/host` presence frames are app-global,
which is correct for presence.

### B6 — Two producers, one suggestion schema (LUMENLENS seam nuance)
The `SuggestionPayload` inbound path has TWO producers: June/MAS = agent_core via UniFFI
(AgentEventDelegate pattern); 1Code/KINDRED = the Node backend via the Experimental bridges. One
schema, two producers — LUMENLENS owns the schema; KINDRED feeds it from Node.

## C. Cross-plan dependencies (order binds)
KEELSTONE Phases 0–4 → LUMENLENS L0–L5 (esp. L1 SuggestionAdapter + L5 ledger) → KINDRED K4/K5.
K0 (residual) + K1–K3 (presence hub, /host frames, Rive render) can proceed in parallel with
LUMENLENS. SIGILRY (Plan 4) feeds the `.riv` artboard identity work (K3).

## D. Landing/handoff — owner decision still open
The research recommends **(c)**: landing = view/select/query-only roster + "currently editing"
state + minimal select-to-query chat; the `+` deep-links into the 1Code creator. Options (a)/(b)
preserved in the plan. **Owner confirms before K7.**
