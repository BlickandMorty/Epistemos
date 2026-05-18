---
state: current-product-architecture-ledger
created_on: 2026-05-18
authority:
  - docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md §4 T09 (acceptance bar)
  - docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md
  - docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md
purpose: |
  Anti-drift product ledger. Every named Epistemos subsystem gets a status, lane, evidence path, missing proof, next action, and falsifier — so future audits cannot promote "file exists" to a feature claim, and cannot collapse research lanes into product paths by accident.
discipline: |
  - Status taxonomy is closed: `current-wired` / `visible-working` / `visible-broken` / `hidden-working` / `hidden-dead` / `implemented-not-wired` / `feature-gated` / `scaffold-only` / `not-implemented` / `excluded-speculative`.
  - Lane taxonomy is closed: `MAS` (current app, Tier 1 ON by default) / `Pro` (direct distribution, Tier 2 bundled / OFF by default) / `Research` (Helios / Omega / Vault gates) / `Infrastructure` (composition + tooling, no user feature) / `Vault` (preserved-speculation only) / `R0` (governing doctrine, not code).
  - "File exists" is never `current-wired`; `current-wired` requires a caller chain ending at a user-reachable surface.
  - "Implemented + caller chain" but no UI surface → `hidden-working`.
  - "Implemented + UI surface that user sees" → `visible-working` (must survive WRV: Wired, Reachable, Visible, Verified).
  - "Implemented + UI surface that the user reaches but the surface is wrong / broken" → `visible-broken`.
  - "Caller chain exists, but the caller is dead code" → `hidden-dead`.
  - "Module compiles, exports types, but nothing else calls it" → `implemented-not-wired`.
  - "Compiles behind a feature flag / env var that is OFF by default" → `feature-gated`.
  - "Only a sketch / stub / TODO list" → `scaffold-only`.
  - "Nothing in the repo yet" → `not-implemented`.
  - "Research idea preserved but explicitly excluded from product right now" → `excluded-speculative`.
  - Every `visible-working` claim must cite either a screenshot path, an XCUITest filename, or an explicit user-step list that reaches the surface.
  - Every row that crosses a terminal boundary that has not yet merged links to a `W-NN` row in `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md`.
  - Every row whose acceptance is gated by a measurement (latency, ULP, recall, copy-count, etc.) names the falsifier (existing or `NOT IMPLEMENTED`).
---

# Current Product Architecture Ledger — 2026-05-18

> **What this doc is.** A row-by-row classification of every named Epistemos subsystem, written so that "we built X" cannot drift into "X ships" by vibes. It is the floor on the truth surface — not the ceiling. The ceiling is the no-compromise endgame in `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md`.
>
> **What this doc is NOT.** It is not a roadmap (that's the prompt deck). It is not a backlog (that's `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md`). It is not a feature-completeness claim — every row carries a falsifier so a green status can be falsified by anyone with a terminal.

## §0. Row schema

| Column | Required content |
|---|---|
| **Subsystem** | Canonical name (the name used in canon — not the file path). |
| **Status** | One of the 10 closed-vocabulary tokens listed in `discipline` above. |
| **Lane** | One of `MAS` / `Pro` / `Research` / `Infrastructure` / `Vault` / `R0`. |
| **User entry / caller chain** | Path from the user's first input to the code (or "none — substrate-internal"). |
| **Evidence** | File path + line range OR `git log` SHA + commit subject (proof the code/doc exists). Multiple sources OK. |
| **Missing proof** | What would have to be true for status to upgrade (e.g. "no XCUITest reaches this row"; "no caller in production paths"; "F-XYZ not yet measured on M2 Pro"). |
| **Next action** | Smallest canonical advancement that would move the row. Should be a single PR-sized task. |
| **Falsifier** | Named gate that can prove this row wrong. May be `NOT IMPLEMENTED` — that itself is a useful classification. |
| **Cross-links** | `W-NN` rows in the wiring backlog; sibling subsystems; doctrine docs. |

## §1. Foundational composition / orchestration

These are not features — they are the substrate that runs every feature. They are classified first because misclassifying them poisons every downstream row.

### Subsystem: AppBootstrap

| Field | Value |
|---|---|
| **Status** | `current-wired` |
| **Lane** | `Infrastructure` |
| **User entry / caller chain** | `EpistemosApp.swift` `@main` → instantiates `AppBootstrap` in `WindowGroup` body → calls `withAppEnvironment(bootstrap)` on every root view. |
| **Evidence** | `Epistemos/App/AppBootstrap.swift` (3902 lines; @MainActor `final class AppBootstrap` at line ~700; instantiates 30+ services — eventBus, chatState, pipelineState, uiState, notesUI, inferenceState, localModelManager, dailyBriefState, threadState, graphState, dialogueChatState, agentCommandCenterState, agentChatState, rawThoughtsState, contextualShadowsState, agentAuthorityStore, hardwareTierManager, instantRecallService, overseerAuditState, MLXInferenceService, LocalGGUFInProcessRuntime, SSMStateService, etc.). `Epistemos/App/AppEnvironment.swift:11-50` is the canonical injection extension; every root view consumes it. CLAUDE.md "App Bootstrap" section names it the single bootstrap surface. |
| **Missing proof** | (a) No cold-launch budget test asserts "AppBootstrap.init() ≤ X ms on M2 Pro 16GB"; (b) No invariant test asserts "every `withAppEnvironment` consumer in the codebase matches the AppEnvironment.swift list" (the prior "Environment Sync Drift" bug class from AGENTS.md). |
| **Next action** | Add an XCTest that snapshots the keys returned by `AppBootstrap`'s `Mirror(reflecting:)` and fails when the list drifts from `AppEnvironment.swift`'s `withAppEnvironment` body — closes the documented drift bug class. |
| **Falsifier** | `F-AppBootstrap-EnvDrift` (NOT IMPLEMENTED): drift test as above. `F-AppBootstrap-ColdLaunch` (NOT IMPLEMENTED): cold-launch budget on M2 Pro — `< 2.0s` to first interactive frame. |
| **Cross-links** | `AppEnvironment` (below); `EpistemosApp.swift` `@main`; AGENTS.md §"Critical Anti-Patterns — The Environment Sync Drift". |

### Subsystem: AppEnvironment

| Field | Value |
|---|---|
| **Status** | `current-wired` |
| **Lane** | `Infrastructure` |
| **User entry / caller chain** | Every root SwiftUI scene calls `<view>.withAppEnvironment(bootstrap)`. Confirmed call sites: `Epistemos/App/EpistemosApp.swift:91,99,157,209` (4 scenes — main WindowGroup, sheet, secondary window, QuickCaptureView), `Epistemos/Views/MiniChat/MiniChatWindowController.swift:106`, `Epistemos/Views/Landing/QuitSavePanelController.swift:105`, `Epistemos/Views/Notes/NoteWindowManager.swift:394,499` (2 — editor + read-only version). Total ≥ 8 production callers, all top-level scene/window roots. |
| **Evidence** | `Epistemos/App/AppEnvironment.swift:11-50` — single `extension View { func withAppEnvironment(_:) }` injecting 32 environment values (uiState, chatState, pipelineState, notesUI, eventBus, inferenceState, preparedModelRegistryState, localModelManager, llmService, triageService, vaultSync, vaultChatMutator, dailyBriefState, threadState, graphState, queryEngine, physicsCoordinator, dialogueChatState, orchestratorState, mcpBridge, channelRegistry, constrainedDecoding, hardwareTierManager, ghostBrainCoauthor, epistemosConfig, iMessageDriver (gated by `#if !EPISTEMOS_APP_STORE`), agentCommandCenterState, agentChatState, chatApprovalQueue, overseerAuditState, textCapturePipeline, rawThoughtsState, contextualShadowsState). |
| **Missing proof** | (a) No compile-time / lint check asserts that every `AppBootstrap` stored property of type `@Observable` is injected by `withAppEnvironment` — the "Environment Sync Drift" anti-pattern in `AGENTS.md` is exactly this drift; (b) `EPISTEMOS_APP_STORE` conditional means the App Store build silently drops `iMessageDriver` — there is no test asserting that App Store consumers don't read `@Environment(IMessageDriverService.self)` in a path that's reachable in the App Store flavor. |
| **Next action** | Add a `AppEnvironmentDriftTests.swift` that uses `Mirror(reflecting: bootstrap)` to enumerate every `@Observable`/service property and assert each one appears in the `withAppEnvironment` body (or is explicitly opt-out-listed). Same test gates the App Store flavor against reading App-Store-excluded environment values. |
| **Falsifier** | `F-AppEnv-Drift` (NOT IMPLEMENTED): the test above. |
| **Cross-links** | [[AppBootstrap]]; AGENTS.md §"Critical Anti-Patterns — The Environment Sync Drift". Future doc: `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md` notes the lazy-init pattern that intentionally keeps some services out of `withAppEnvironment` until first user-action — that pattern is the legitimate opt-out the drift test must whitelist. |

### Subsystem: EpistemosApp (`@main`)

| Field | Value |
|---|---|
| **Status** | `current-wired` |
| **Lane** | `Infrastructure` |
| **User entry / caller chain** | macOS launches the app binary → SwiftUI runtime instantiates `EpistemosApp` via `@main` → its `body: some Scene` constructs WindowGroup(s) → each one wraps content in `.withAppEnvironment(bootstrap)`. |
| **Evidence** | `Epistemos/App/EpistemosApp.swift:826-827` `@main / struct EpistemosApp: App`; declares 4+ scene bodies at lines 43/62/85/256 and the main `var body: some Scene` at line 857; `var body: some Commands` at line 1223; total 1334 lines. References `RuntimeDiagnosticsMonitor`, holds the global `DispatchSourceMemoryPressure` handler (CLAUDE.md cites lines 572-602 / 600-606 for level-1/level-2 memory pressure FFI dispatch to `respond_to_memory_pressure`). |
| **Missing proof** | (a) No XCUITest asserts cold launch reaches first interactive frame without a sheet-stuck / approval-gate-stuck state; (b) The 4 `withAppEnvironment` call sites are hand-maintained — if a fifth scene is added without `.withAppEnvironment(bootstrap)` the runtime crashes when a view tries to read `@Environment(SomeState.self)` (the AGENTS.md drift bug). The same drift test that protects AppEnvironment also protects this surface. |
| **Next action** | Same drift test as [[AppEnvironment]] — extend it to scan `EpistemosApp.swift` for every `WindowGroup`/`Window`/`Settings` scene and assert each has a `.withAppEnvironment(bootstrap)` in its body. |
| **Falsifier** | `F-AppEnv-Drift` (NOT IMPLEMENTED). |
| **Cross-links** | [[AppBootstrap]]; [[AppEnvironment]]; CLAUDE.md "Swift Memory + Energy Hardening" section on the `EpistemosApp.swift:572-602` memory-pressure FFI wiring. |

## §2. State surface

### Subsystem: ChatState

| Field | Value |
|---|---|
| **Status** | `visible-working` |
| **Lane** | `MAS` |
| **User entry / caller chain** | User opens chat tab / mini-chat / sidebar → SwiftUI view reads `@Environment(ChatState.self)` → view body re-evaluates on `isStreaming` / `activeChatId` / `messages` changes. Wired into `withAppEnvironment` (`AppEnvironment.swift:15`). |
| **Evidence** | `Epistemos/State/ChatState.swift:228-229` `@MainActor @Observable final class ChatState` (1667 lines). Owns `isStreaming` (line 234), `activeChatId` (line 262), `messages: [ChatMessage]` (line 273), plus brain section, captured-input cache, display-paced text buffer. 10 view consumers verified via `rg "@Environment(ChatState.self)"` (ChatView, NoteChatSidebar, MiniChatView, ProseEditorView, GraphWorkspaceContainer, etc.). |
| **Missing proof** | (a) No invariant test asserts `messages` list stays bounded under a long chat (memory ceiling); (b) No test asserts `activeChatId` is non-nil whenever a view tries to render messages (the implicit precondition is unenforced); (c) No XCUITest screenshots the streaming → ended → user-resubmit cycle on M2 Pro. |
| **Next action** | Add `ChatStateInvariantTests.swift` that runs the lifecycle (createChat → setActive → appendMessage × N → endStream → reset) and asserts message-buffer growth is bounded by the explicit `fetchLimit = 200` used in `SDChat.recentChatsDescriptor` (CLAUDE.md cites this in Wave 2026-04-29 perf additions). |
| **Falsifier** | `F-ChatState-MessagesUnbounded` (NOT IMPLEMENTED): the bounded-growth test above. |
| **Cross-links** | [[AppEnvironment]]; [[PipelineState]] (chat presentation co-state); CLAUDE.md "Swift Memory + Energy Hardening" §`SDPage+Queries.swift:106-114` — the persisted-side bound that ChatState should mirror in memory. |

### Subsystem: UIState

| Field | Value |
|---|---|
| **Status** | `visible-working` |
| **Lane** | `MAS` |
| **User entry / caller chain** | Every shell, sidebar, tab bar, settings panel reads `@Environment(UIState.self)`. Wired into `withAppEnvironment` (`AppEnvironment.swift:14`). |
| **Evidence** | `Epistemos/State/UIState.swift:249-250` `@MainActor @Observable final class UIState` (625 lines). 102 view consumers verified via `rg "@Environment(UIState.self)" --type=swift \| wc -l` (PageShell, ChatView, RootView, SettingsView, NotesSidebar, OutlineNavigatorView, etc.). Side-types: `LandingGreetingEntry` (line 40) and `LandingGreetingPhrase` (line 72) implement landing surface persistence. |
| **Missing proof** | (a) 102 consumers means UIState is a god-state — no test asserts that any single property change re-renders only the views that actually depend on that property (Observation framework should handle this, but no regression guard); (b) No test inventories what UIState owns vs. what should live in a more local @Observable. |
| **Next action** | Inventory UIState's properties; mark which ones are read by ≤ 3 views and consider hoisting them out into more local state (mechanical refactor, deferred — for now this row's task is just to document the concentration risk). Add `UIStateOwnershipManifest.md` listing each property → consumer-count. |
| **Falsifier** | `F-UIState-GodState` (NOT IMPLEMENTED): a documented manifest + lint that forbids new UIState properties whose consumer-count is < 3 unless explicitly justified. |
| **Cross-links** | [[AppEnvironment]]; AGENTS.md §"Patterns to Follow — `@MainActor @Observable` for all state classes". |

### Subsystem: PipelineState

| Field | Value |
|---|---|
| **Status** | `visible-working` |
| **Lane** | `MAS` |
| **User entry / caller chain** | User submits chat input → `PipelineService` calls `PipelineState.startProcessing()` → `ChatView` reads `pipeline.isProcessing` and gates the composer / shows the processing indicator → on completion, `completeProcessing()` reverts. Wired into `withAppEnvironment` (`AppEnvironment.swift:16`). |
| **Evidence** | `Epistemos/State/PipelineState.swift:6-28` `@MainActor @Observable final class PipelineState` (28 lines — minimal: `isProcessing`, `currentError`, 4 methods). Two visible consumers in `Epistemos/Views/Chat/ChatView.swift` lines 180 + 526 (`@Environment(PipelineState.self) private var pipeline`), reading `pipeline.isProcessing` at lines 247 / 255 / 318 / 362 / 487 / 545 / 595 (resubmit gating, streaming indicator, agent-executing branch). Test coverage in `EpistemosTests/PipelineServiceTests.swift` asserts state transitions at lines 218/219/264/265/589/590/1816/1820/1881/1882. |
| **Missing proof** | (a) `currentError` is set by `setError(_:)` but no view code surfaces it — confirmed by `rg "pipeline\.currentError"` returning only test asserts; this is a `hidden-dead` sub-property inside a `visible-working` parent state; (b) No race test asserts that rapid submit → cancel → submit doesn't leave `isProcessing = true` permanently. |
| **Next action** | Either wire `currentError` into a visible ChatView error banner, or delete the property — the current state is "code exists, no surface" which is exactly the drift this ledger guards against. (Defer the choice to a future tick — this row's job is to flag it.) |
| **Falsifier** | `F-PipelineState-OrphanError` (NOT IMPLEMENTED): grep gate that fails if `pipeline.currentError` is read by zero non-test files. |
| **Cross-links** | [[ChatState]] (composer co-state); [[AppEnvironment]]. |


### Subsystem: ChatCoordinator

| Field | Value |
|---|---|
| **Status** | `visible-broken` |
| **Lane** | `MAS` |
| **User entry / caller chain** | User types in chat composer → `ChatView` submits via `PipelineService` → `ChatCoordinator.handleQuery(...)` (line 1620) or `handleCommandCenterSubmission(...)` (line 287) → `buildContextAttachments(...)` (line 4034) resolves attached + implicit vault notes via `vaultSync.searchIndex(query:)` → runs through `runRustAgentPath` (line 2400) or `runCommandCenterLocalAgentPath` (line 1035) → streams via `StreamingDelegate` back to `ChatState` → `ChatView` renders. |
| **Evidence** | `Epistemos/App/ChatCoordinator.swift:11` `final class ChatCoordinator` (5587 lines). Instantiated in `Epistemos/App/AppBootstrap.swift:1964` (production) + 3 test instantiations in `EpistemosTests/PipelineServiceTests.swift`. State callers: `NoteChatState`, `CommandCenterDiagnostics`, `AgentCommandCenterState`, `ChatState`, `AgentChatState`, `OverseerAuditState`, `PromptTreePreferences`, `Engine/PromptTree.swift` — all in production paths. |
| **Missing proof** | (a) The Vault Context Contract is **not enforced** at this seam — `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` documents the "first 7 irrelevant notes" failure traced through `vaultSync.searchIndex(query:)` → `vault.rs` (root cause is upstream Fix-B + Fix-C in `agent_core/src/storage/vault.rs`, but ChatCoordinator is the surface where the user sees the broken output). (b) No trace is emitted to `RunEventLog` with lexical / semantic / graph / recency / MMR component scores — `chatState.loadedNoteIds` is set but no provenance card is surfaced beyond the title list. (c) No XCUITest reproduces the failure on the F-VaultRecall-50 fixture corpus. |
| **Next action** | Out-of-scope for T09 — this row's classification is the deliverable. T21 (`codex/t21-vault-recall-contract-2026-05-18`) owns the fix at `vault.rs` + this seam; T22B owns the Brain Panel surface. T09's job is to mark this row `visible-broken` so the wiring backlog is honest. |
| **Falsifier** | `F-VaultRecall-50` (in flight under T21 per `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md`). PASS = ≥ 95% top-1 exact-title recall on the 50-item fixture corpus. |
| **Cross-links** | [[ChatState]]; [[VaultSyncService]] (to be classified); [[SearchIndexService]] (to be classified); `W-19` (ChatCoordinator Vault Context Contract enforcement), `W-20` (provenance cards), `W-22` (vault returns `Vec<UasAddress>`), `W-23` (Vault Context Contract enforced everywhere). |

## §3. AI / inference services

(rows will land here — `MLXInferenceService`, `LocalGGUFInProcessRuntime`, `TriageService`, `LLMService`, `PipelineService`, `ConfidenceRouter`, `LocalAgentPromptBuilder`, `LocalAgentLoop`, etc.)

## §4. Vault / retrieval / search

### Subsystem: VaultSyncService (Swift)

| Field | Value |
|---|---|
| **Status** | `visible-working` |
| **Lane** | `MAS` |
| **User entry / caller chain** | User picks vault folder via onboarding → `VaultSyncService.requestVaultAccess()` resolves a security-scoped bookmark → `VaultSyncService.startSync()` crawls notes + chats → import progress visible via `vaultSync.importProgress` snapshot. Read APIs: `findNotesByTitle(_:)` (line 2894), `fetchNoteBodies(ids:)` (line 2889), `searchIndex(query:)` (line 2903), `searchFull` / `searchFullAsync` (lines 2923 / 2940), `searchBlocksAsync` (line 2971). Wired into `withAppEnvironment` (`AppEnvironment.swift:24`); consumed by `ChatCoordinator.buildContextAttachments` (line 4044-4051), `NotesSidebar`, `VaultOrganizerView`, etc. |
| **Evidence** | `Epistemos/Sync/VaultSyncService.swift:274-275` `@MainActor @Observable final class VaultSyncService` (4257 lines). Side types: `VaultSyncConflict` (line 18), `VaultBookmarkStartupValidation` (line 25), `VaultHealthSnapshot` (line 31), `VaultRecoveryIssue` (line 73), `VaultImportProgressSnapshot` (line 110). Tested in `VaultSyncServiceAuditTests.swift` and downstream `SearchIndexServiceIntegrationTests.swift`. |
| **Missing proof** | (a) Service itself is visible-working (vault import, conflict detection, bookmark restoration, note enumeration all reach the UI); but the *retrieval ranking honesty* is the `visible-broken` claim that ChatCoordinator surfaces — see [[ChatCoordinator]]. The VaultSyncService row is *not* the place to fix that — `searchIndex` and `searchFull` delegate to `SearchIndexService`, and the agent-side vault tool delegates to `agent_core::storage::vault::VaultStore`. (b) No XCUITest verifies bookmark restoration after a forced unmount; (c) The `nonisolated` boundaries on `searchFull` are not stress-tested for actor-reentrance. |
| **Next action** | Out of scope for T09. Document in this ledger that the *service* is `visible-working`; the *retrieval honesty* is `visible-broken` at the downstream Rust + Swift index layers ([[vault.rs (agent_core)]], [[SearchIndexService]]). T21 owns the fixes. |
| **Falsifier** | `F-VaultSync-BookmarkRestore` (NOT IMPLEMENTED): XCUITest that unmounts the vault drive mid-session and confirms graceful re-prompt without data loss. The retrieval falsifier is `F-VaultRecall-50` (in flight under T21). |
| **Cross-links** | [[ChatCoordinator]]; [[SearchIndexService]]; [[vault.rs (agent_core)]]; `W-04` (page-gather → vault.rs); `W-19` (Vault Context Contract). |

### Subsystem: SearchIndexService (Swift, GRDB / FTS5)

| Field | Value |
|---|---|
| **Status** | `visible-working` (core path); `feature-gated` (`fusedSearch` RRF path) |
| **Lane** | `MAS` |
| **User entry / caller chain** | User triggers any UI search → `QueryEngine` / `QueryRuntime` → `SearchIndexService.search(query:limit:)` (line 509) or `.searchAsync` (line 592) → SQL against GRDB FTS5. RRF-fused path: `fusedSearch` (line 886) / `fusedSearchAsync` (line 993), guarded by `RRFFusionFlags.isEnabled` reading env-var `EPISTEMOS_RRF_FUSION_V1`. Consumed by `NightBrainService`, `AppBootstrap` (warm-up), `QueryRuntime`, `QueryEngine`, `ReadableBlocksIndex`. |
| **Evidence** | `Epistemos/Sync/SearchIndexService.swift:28` `actor SearchIndexService` (2171 lines). Phase-1 schema `installVaultIDColumn` lives here; Phase-4 fusion path consults `RRFFusionQuery.sql` (`Epistemos/Sync/RRFFusionQuery.swift`, 461 lines). PRAGMA tuning at lines 204-228 (cache_size 8 MB, mmap_size 256 MiB per CLAUDE.md Wave 2026-04-29). Memory-pressure relief at lines 298-322 (`releaseMemoryPressureCaches`). Settings diagnostics surface: `SearchFusionHealthRow.swift` (1 Hz polling). |
| **Missing proof** | (a) Non-fused `search` / `searchFull` is the default; fused path requires explicit env var → most users never see RRF in production. The `RRFFusionFlags.isEnabled` flag has no Settings UI (W-32 unified Experimental panel is unbuilt). (b) `SearchFusionHealthRow` shows last-query latency + per-source hits, but if the flag is OFF the row reads "fusion disabled" — verified path exists but is feature-gated dark. (c) No regression test that the EXPLAIN plan still uses `VIRTUAL TABLE INDEX` after future schema migrations (the Phase-2 regex gate `VIRTUAL TABLE INDEX \d+:M\d+` is a critical invariant). |
| **Next action** | Out of scope for T09. T-row owners: `W-32` Experimental Features panel will give the RRF flag a Settings toggle; T21 / T22B touch retrieval honesty downstream. |
| **Falsifier** | `F-RRFFusion-DefaultOff` (PASS — currently true; documents the gate state, doesn't fail). `F-RRFFusion-VTableIndex` (PARTIAL — regex test exists in `RRFFusionQueryTests.swift`, no CI gate prevents future drift). |
| **Cross-links** | [[VaultSyncService]]; [[ChatCoordinator]]; `W-19` (ChatCoordinator Vault Context Contract); `W-32` (Experimental Features panel). |

### Subsystem: vault.rs (agent_core::storage::vault::VaultStore)

| Field | Value |
|---|---|
| **Status** | `visible-broken` |
| **Lane** | `MAS` (used by agent tool calls + context loader); `Research` (Fix-B partial, Fix-C pending = T21 scope) |
| **User entry / caller chain** | Local agent or cloud agent tool call → `agent_core/src/context_loader.rs:408` invokes `VaultBackend::hybrid_search(objective, 3, &[])` → `VaultStore::hybrid_search` (Rust) → Tantivy BM25 lexical search → results streamed back to agent → agent cites them in chat reply. |
| **Evidence** | `agent_core/src/storage/vault.rs:155` `pub struct VaultStore`; `impl VaultBackend for VaultStore` at line 545; `hybrid_search` impl at line 546-616 (794 lines total in file). **Fix-B applied**: lines 562-571 strip chatter via `strip_query_chatter` (line 55) and switch to `query_parser.set_conjunction_by_default()` (line 570) for short queries (≤ 3 surviving terms). Commit lineage: "F-VaultRecall-50 Fix B (iter 81, 2026-05-16)". **Fix-C NOT applied**: line 606 still has `score: (score as f64).clamp(0.0, 1.0)` — the diagnosis doc explicitly identifies this clamp as suppressing real BM25 signal. |
| **Missing proof** | (a) `hybrid_search` is a misnomer — the `VaultStore` implementation is **lexical-only BM25**. The default `hybrid_search` trait method delegates to itself (line 106), so no semantic / graph / recency / MMR fusion happens at this layer. The `F-VaultRecall-50` 50-item fixture has not passed end-to-end. (b) `context_loader.rs:408` hardcodes `limit = 3` — caller path that surfaces "first 7 irrelevant notes" likely accumulates multiple `limit=3` calls and shows their union without re-ranking. (c) No falsifier currently runs in CI; `F-VaultRecall-50` requires the fixture corpus + Fix-C drop + verification harness which T21 owns. |
| **Next action** | T21 (`codex/t21-vault-recall-contract-2026-05-18`) owns: drop the `(score as f64).clamp(0.0, 1.0)` at line 606 (Fix-C); land the semantic + graph + recency + MMR fusion at this seam OR rename `hybrid_search` to `lexical_search` and add a real `hybrid_search` wrapper above. T09's job is the classification. |
| **Falsifier** | `F-VaultRecall-50` (in flight under T21): ≥ 95% top-1 exact-title recall on 50-item fixture; current pass rate unmeasured. |
| **Cross-links** | [[ChatCoordinator]]; [[VaultSyncService]]; [[SearchIndexService]]; `W-01` (vault notes carry `UasAddress`); `W-04` (page-gather wired to vault.rs); `W-19` (Vault Context Contract); `W-22` (vault returns `Vec<UasAddress>`); `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` (Fix-A/B/C plan). |


## §5. Agent system

(rows will land here — `agent_core/src/agent_loop.rs`, `agent_core/src/agent_runtime/`, `agent_core/src/bridge.rs`, `StreamingDelegate`, `AgentViewModel`, `AgentBlueprint`, AgentRunTimeline, `Omega/MCPBridge`, etc.)

## §6. Cognitive DAG + Provenance

(rows will land here — `agent_core/src/cognitive_dag/` 8.A-8.G, `agent_core/src/provenance/ledger.rs`, `ReplayBundle`, macaroons, `epistemos_trace` CLI, `epistemos_doctrine_lint` CLI, etc.)

## §7. SCOPE-Rex + Cognitive Weight Class + ACS + UAS

(rows will land here — `agent_core/src/scope_rex/`, `agent_core/src/uas/` (if present), Cognitive Weight Class enforcement, ACS admission, etc.)

## §8. Halo / Shadow / Contextual Shadows

(rows will land here — `Epistemos/Engine/HaloController.swift`, `ShadowSearchService`, `ShadowIndexingService`, `epistemos-shadow` crate, `RustShadowFFIClient`, `ShadowVaultBootstrapper`, etc.)

## §9. Notes / Editor / Epdoc

(rows will land here — `ProseEditorView`, `ProseEditorRepresentable2`, `ProseTextView2`, `MarkdownContentStorage`, `EpdocEditorChromeView`, `js-editor/` Tiptap bundle, `EpdocPasteClassifier`, `EpdocBlockTemplateStore`, etc.)

## §10. LSP + Knowledge Fusion

(rows will land here — `agent_core/src/lsp_runtime/`, `LSPClient`, `RustLSPTransport`, knowledge-fusion services if present, etc.)

## §11. Graph

(rows will land here — `GraphState`, `GraphStore`, `GraphBuilder`, `graph-engine/` Rust crate, `MetalGraphView`, `HologramController`, `PhysicsCoordinator`, `SemanticClusterService`, etc.)

## §12. Settings UI / Diagnostics

(rows will land here — `SettingsView`, `EditorBundleHealthRow`, `SearchFusionHealthRow`, `ActiveConstellationRow`, `AnswerPacketHealthRow`, `LocalAgentDiagnostics`, etc.)

## §13. Research-only modules (lane = Research / Vault)

(rows will land here — `agent_core/src/research/eml_integration/`, `agent_core/src/research/operator_ir/` (T5-locked, do not touch), `agent_core/src/research/scan_ir/` (T5-locked), `agent_core/src/research/tropical_ir/` (T5-locked), KV-Direct, EML-IR, Lattice/WBO types when T17B lands, ACS admission types when T18B lands, etc.)

## §14. Delete / Hide / Merge / Keep / Build-next lists

(populated only after the per-subsystem rows above stabilize)

## §15. Cross-doc references

- `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` — prompt deck (mission source-of-truth).
- `docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md` — substrate handoff (doctrine + rules).
- `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` — 45 W-NN wiring rows post-merge.
- `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` — master fusion canon.
- `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` — UAS-ACS unified canon.
- `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md` — Fix-B / Fix-C diagnosis driving T21.
- `AGENTS.md` — engineering bible (golden rules + critical anti-patterns).
- `CLAUDE.md` — non-negotiable constraints + FILE MAP.

## §16. Change log

| Date | Iter | Change | Author |
|---|---|---|---|
| 2026-05-18 | iter-1 | Initial scaffold; classified `AppBootstrap` as `current-wired` / `Infrastructure`. | T09 loop |
| 2026-05-18 | iter-2 | Classified `AppEnvironment` as `current-wired` / `Infrastructure`; named `F-AppEnv-Drift` falsifier. | T09 loop |
| 2026-05-18 | iter-3 | Classified `EpistemosApp` (`@main`) as `current-wired` / `Infrastructure`. | T09 loop |
| 2026-05-18 | iter-4 | Classified `ChatState` as `visible-working` / `MAS`; flagged unbounded-messages risk. | T09 loop |
| 2026-05-18 | iter-5 | Classified `UIState` as `visible-working` / `MAS`; flagged god-state concentration (102 consumers). | T09 loop |
| 2026-05-18 | iter-6 | Classified `PipelineState` as `visible-working` / `MAS`; flagged `currentError` as orphan sub-property. | T09 loop |
| 2026-05-18 | iter-7 | Classified `ChatCoordinator` as `visible-broken` / `MAS`; cross-linked W-19/20/22/23 + F-VaultRecall-50. | T09 loop |
| 2026-05-18 | iter-8 | Classified `VaultSyncService` (Swift) as `visible-working` / `MAS`; separated service from retrieval honesty. | T09 loop |
| 2026-05-18 | iter-9 | Classified `SearchIndexService` (actor) as `visible-working` + `fusedSearch` sub-path as `feature-gated`. | T09 loop |
| 2026-05-18 | iter-10 | Classified `vault.rs` (Rust `VaultStore`) as `visible-broken`; verified Fix-B applied at line 570, Fix-C NOT applied at line 606; `hybrid_search` is BM25-only misnomer. | T09 loop |
