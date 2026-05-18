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

### Subsystem: MLXInferenceService (actor)

| Field | Value |
|---|---|
| **Status** | `visible-working` |
| **Lane** | `MAS` |
| **User entry / caller chain** | User submits chat / asks for note continuation / triggers `.continue` / `.outline` / etc. → `ChatCoordinator` → `LLMService` / `PipelineService` → `MLXInferenceService.run(...)` actor methods → MLX-Swift container loads model from disk → streams tokens back → `StreamingDelegate` → `ChatState.messages`. Instantiated at `Epistemos/App/AppBootstrap.swift:1725` `let localInferenceService = MLXInferenceService(snapshot: inference.hardwareCapabilitySnapshot)`. |
| **Evidence** | `Epistemos/Engine/MLXInferenceService.swift:1453` `actor MLXInferenceService: LocalMLXRuntime` (2590 lines). Side actors: `LocalMLXRequestGate` (line 269 — serializes one-at-a-time inference), `LocalMLXClient` (line 513 — `RoutedLocalRuntimeClient` for run + cancel). Idle-unload schedule at lines 336-372 (16 GB: 6→4 s, 24 GB: 10→6 s, etc. per CLAUDE.md perf wave). Memory-pressure handler at lines 1163-1195 drops `persistentSSMSession` on `.warning`. `MetalRuntimeManager.deepUnload()` called from `performUnload` at line 1493. |
| **Missing proof** | (a) No XCUITest measures end-to-end first-token-latency on M2 Pro 16 GB across the small / medium / large model class — the idle-unload thresholds + ChatSession warmup are heuristics, not budget-gated by a falsifier. (b) No assertion that the `LocalMLXRequestGate`'s queue never grows unbounded under rapid resubmit. (c) `persistentSSMSession` drop on warning was added for memory pressure but no test asserts the next request rebuilds it cleanly. |
| **Next action** | Add `MLXFirstTokenBudgetTests.swift` that loads the canonical Qwen3.5-MLX-4bit container, runs 10 cold-start prompts, and asserts p95 first-token-latency ≤ a documented M2 Pro budget (e.g. 3.0 s) — calibrated, not aspirational. |
| **Falsifier** | `F-MLX-FirstTokenLatency-M2Pro` (NOT IMPLEMENTED): the calibrated p95 budget test. |
| **Cross-links** | [[TriageService]]; [[LocalAgentLoop]]; CLAUDE.md "Swift Memory + Energy Hardening" §`MLXInferenceService.swift:336-372`; AGENTS.md §"TriageService — AI Routing". |

### Subsystem: TriageService

| Field | Value |
|---|---|
| **Status** | `visible-working` |
| **Lane** | `MAS` |
| **User entry / caller chain** | User triggers AI operation (rewrite / summarize / continue / outline / expand / analyze / ask) → `LLMService.process(...)` → `TriageService.triage(operation:complexity:...)` (line 1095 / 1109) decides between Apple Intelligence and local Qwen → returns `TriageDecision` (line 1743) → caller dispatches to chosen runtime. Instantiated at `Epistemos/App/AppBootstrap.swift:1878`. |
| **Evidence** | `Epistemos/Engine/TriageService.swift:953` `final class TriageService` (2536 lines). Methods: `triage` (line 1095 + 1109 overload), `triageGeneral` (line 1324), `routeDecisionForNotes` (line 1588 + 1602), `routeDecisionForGeneral` (line 1618). Operation→tier mapping documented in `AGENTS.md` §"TriageService — AI Routing" with explicit complexity scores (rewrite 0.25, summarize 0.20, ..., analyze 0.60). |
| **Missing proof** | (a) The decision boundary between "light enough → Apple Intelligence" and "→ local Qwen" is a heuristic tied to `complexity` score — no fixture corpus measures actual routing accuracy on real notes (the operation-tier matrix in AGENTS.md is the spec, but no test asserts production matches it). (b) No fallback test: if Apple Intelligence is unavailable (older macOS, opt-out, hardware ineligible), does the routing degrade to local Qwen without UI surprise? |
| **Next action** | Add `TriageRoutingFixtureTests.swift` with 50+ representative operations + complexity inputs and assert each routes to the documented tier per AGENTS.md. |
| **Falsifier** | `F-Triage-OperationTierParity` (NOT IMPLEMENTED): the fixture-based parity test. |
| **Cross-links** | [[MLXInferenceService]]; AGENTS.md §"TriageService — AI Routing"; AGENTS.md §"Service Architecture". |

## §5. Agent system

### Subsystem: agent_core::agent_loop (Rust)

| Field | Value |
|---|---|
| **Status** | `current-wired` |
| **Lane** | `MAS` (cloud-model agent path) |
| **User entry / caller chain** | User chats with a cloud-capable model (Claude / OpenAI compatible / Perplexity) → Swift `StreamingDelegate` invokes the FFI bridge → `bridge.rs` calls `run_agent_loop(...)` (`agent_loop.rs:151`) with an `AgentConfig` (line 65) → loop iterates: provider call → tool dispatch → cache check → next turn → returns `AgentResult` (line 113) → streamed back to Swift. |
| **Evidence** | `agent_core/src/agent_loop.rs:151` `pub async fn run_agent_loop(...)` (1481 lines). Types: `Effort` enum (21), `McpServerConfig` (29), `PermissionConfig` (36), `AgentConfig` (65), `AgentResult` (113), `AgentError` enum (122). FFI invocations from `bridge.rs`, providers (`claude.rs`, `openai.rs`, `openai_compatible.rs`, `perplexity.rs`), tools (`workspace_search.rs`, `delegate_task.rs`), MCP (`mcp/url_servers.rs`). Swift side: `Epistemos/Bridge/StreamingDelegate.swift`, `Epistemos/LocalAgent/HermesLocalAgentCompatibility.swift` (legacy adapter), `LocalAgentCommandDispatcher.swift`, `LocalAgentConfigToggleCommands.swift`. |
| **Missing proof** | (a) CLAUDE.md mandates "AGENT DECIDES TERMINATION. max_turns is a safety rail, not a schedule. Trust stop_reason == 'end_turn'" — no test asserts agent_loop respects this rule under pathological provider responses (e.g., tool_use forever); (b) "PRESERVE THINKING BLOCKS" rule: no property test that verifies thinking blocks + signatures are passed through unchanged when `stop_reason == "tool_use"`; (c) Cancellation: `cancel_agent_session` exists in bridge.rs:1040 but the cooperative-cancel point inside `run_agent_loop` is not stress-tested for guaranteed quiescence within a budget. |
| **Next action** | T11 `agent_runtime_v2` is the eventual typed/budgeted/witnessed replacement. For T09's purposes this row is `current-wired` and the gaps go on the wiring backlog for T11 to consume. |
| **Falsifier** | `F-AgentLoop-ThinkingBlocksPassthrough` (NOT IMPLEMENTED): property test that round-trips a `stop_reason="tool_use"` response through the loop and asserts byte-identical preservation of every `thinking` block + signature. `F-AgentLoop-CancelLatency` (NOT IMPLEMENTED): time-bounded cancellation test. |
| **Cross-links** | [[bridge.rs]] (below); [[agent_runtime]] (below); CLAUDE.md "NON-NEGOTIABLE CONSTRAINTS — PRESERVE THINKING BLOCKS / STREAM EVERYTHING / AGENT DECIDES TERMINATION"; T11 (`agent_runtime_v2` successor). |

### Subsystem: agent_core::agent_runtime (renamed from `hermes/` 2026-05-05)

| Field | Value |
|---|---|
| **Status** | `current-wired` |
| **Lane** | `MAS` |
| **User entry / caller chain** | Local model chat with native grammar (`LocalToolGrammar.supportsLocalAgentLoop = true`) → `LocalAgentLoop.run` (Swift actor) → emits Hermes-format prompt via `prompt_format.rs` → model streams tokens → `function_call.rs` parses `<tool_call>` / `<think>` grammar → `skills.rs` routes to skill registry → `procedural_memory.rs` records → `self_evolution.rs` proposes ladder rungs. |
| **Evidence** | `agent_core/src/agent_runtime/mod.rs:1-20` documents the rename. 6 submodules: `function_call.rs` (239 lines), `procedural_memory.rs` (196 lines), `prompt_format.rs` (184 lines), `self_evolution.rs` (102 lines), `skills.rs` (25 lines — consolidation boundary, re-exports from `crate::skill_router`, `crate::storage::skills_registry`, `crate::tools::skills`), `mod.rs` (20 lines). Total ownership surface: 766 lines + reexported skill code. Removal record at `docs/_archive/hermes-removal-2026-05-05/README.md`. `mod.rs` explicitly notes Hermes-3 prompt grammar (`<tools>`, `<tool_call>`, `<think>`) is still emitted because the local model speaks that format (Nous Research spec, not the removed subprocess). |
| **Missing proof** | (a) `skills.rs` is a 25-line *consolidation boundary* — the doc comment says "the legacy skill router, registry store, and tool facade still live in their original files while the migration stays behavior-preserving." The migration is incomplete: a future tick should audit whether new call sites actually route through this module or whether they still call the legacy modules directly. (b) `EpistemosTests/HermesPromptFormatGuardTests.swift` exists — verify it asserts grammar preservation; if it does, this is a strong falsifier we can name explicitly. (c) `self_evolution.rs` is small (102 lines) — verify it isn't `scaffold-only` and has actual call sites. |
| **Next action** | Future tick: classify each agent_runtime submodule (`function_call`, `prompt_format`, `procedural_memory`, `self_evolution`, `skills`) individually rather than as one row — each may have a different status (e.g., `self_evolution` could be `feature-gated` or `scaffold-only`). |
| **Falsifier** | `F-AgentRuntime-HermesPromptParity` (PARTIAL — `HermesPromptFormatGuardTests.swift` exists per `rg`; verify scope in a future tick). `F-AgentRuntime-SkillsRouteConsolidation` (NOT IMPLEMENTED): grep gate that asserts new agent-runtime callers go through `agent_runtime::skills::*` not the legacy `crate::skill_router::*` directly. |
| **Cross-links** | [[agent_loop.rs]]; [[LocalAgentLoop]] (Swift); `docs/_archive/hermes-removal-2026-05-05/README.md`; CLAUDE.md FILE MAP §"Rust agent_core — In-process agent runtime"; T11 (`agent_runtime_v2` is the *new* governed executor — distinct from this consolidation-boundary module). |

### Subsystem: agent_core::bridge (Rust↔Swift FFI surface)

| Field | Value |
|---|---|
| **Status** | `current-wired` |
| **Lane** | `Infrastructure` |
| **User entry / caller chain** | Every Swift call into Rust agent_core goes through this file's UniFFI/extern surface. Includes: agent loop trigger, session cancel, MCP catalog, NightBrain scheduler, R15 callback-loop benchmark, memory-pressure dispatch, route preview, provenance/ledger access, vault operations. |
| **Evidence** | `agent_core/src/bridge.rs` (3535 lines). Notable exports: `agent_core_policy_profile` (line 253), `preview_provider_route` (640), `nightbrain_canonical_task_names` (654), `nightbrain_preview_admission` (659), `nightbrain_register_canonical_tasks` (724), `nightbrain_live_registered_task_names` (741), `nightbrain_run_live_registered_tasks` (760), `nightbrain_preempt_live_scheduler` (789), `nightbrain_reset_live_scheduler` (805), `route_capture_contract` (826), `route_variant_b_schema_json` (855), `cancel_agent_session` (1040), `active_session_count` (1045), `run_r15_true_rust_callback_loop_benchmark` (1058), `respond_to_memory_pressure` (1111). |
| **Missing proof** | (a) UniFFI generates `.uniffi` bindings — no regression test asserts the generated Swift surface matches the documented FFI export list in CLAUDE.md (so a Rust-side rename can silently break Swift callers between builds). (b) Memory-pressure FFI `respond_to_memory_pressure` returns a `MemoryPressureReliefFFI` struct — but Swift side's `RuntimeDiagnosticsMonitor` only logs the relief metrics; the metrics aren't surfaced in any Diagnostics row (potential row for `hidden-working`). |
| **Next action** | Add `FFISymbolDriftTests.swift` (Swift side) that runs `nm` on the linked Rust dylib + asserts every documented FFI export is present and the no-extra-symbols invariant holds. Out of scope for T09; goes on the wiring backlog. |
| **Falsifier** | `F-FFI-SymbolDrift` (NOT IMPLEMENTED): nm-based symbol drift test. |
| **Cross-links** | [[agent_loop.rs]]; CLAUDE.md "FFI Boundary (Swift <-> Rust)"; AGENTS.md §"FFI Boundary"; `EpistemosTests/FFISafetyTests.swift` (already exists — scope to verify). |

## §5c. Omega / MCP

### Subsystem: Omega::MCPBridge (Swift) + omega-mcp (Rust crate)

| Field | Value |
|---|---|
| **Status** | `current-wired` (core JSON-RPC + builtin tools); `feature-gated` (PTY + github + web_search subsystems are bounded by Pro tier / capability admission). |
| **Lane** | `MAS` (core tool dispatch); `Pro` (browser, PTY, github) |
| **User entry / caller chain** | User selects an MCP-backed action / agent tool requests a builtin tool → `MCPBridge.swift:235` `final class MCPBridge` routes via the FFI surface in `omega-mcp/src/uniffi_exports.rs` (387 lines, 17+ `pub fn` entry points: `parse_jsonrpc_request`, `jsonrpc_success`/`error`, `validate_tool_args`, `builtin_tools_json`, `execute_vault_tool`, `execute_graph_tool`, `execute_git_tool` (cfg-gated alt at line 112), `execute_github_tool`, `execute_web_search_tool`, `execute_memory_tool`, `generate_heuristic_plan`, `get_default_agents_json`, `evaluate_risk_confirmation`). Wired into `withAppEnvironment` (`AppEnvironment.swift:33` — `.environment(bootstrap.mcpBridge)`). |
| **Evidence** | `Epistemos/Omega/MCPBridge.swift` (502 lines). `omega-mcp/src/`: `dispatcher.rs` (614), `catalog.rs` (509), `vault.rs` (571), `github.rs` (712), `uniffi_exports.rs` (387), `moa.rs` (327), `web_search.rs` (654), `orchestrator.rs` (795), `pty.rs` (662), `graph_tools.rs` (663), `bin/uniffi_bindgen.rs` (3) — **10537 lines total**. CLAUDE.md FILE MAP §"Rust omega-mcp crate" names dispatcher, catalog, vault.ops as the canonical surface. |
| **Missing proof** | (a) PTY (`omega-mcp/src/pty.rs`, 662 lines) is a subprocess gateway — CLAUDE.md "DO NOT — Use Ollama, llama-server, or any subprocess for INFERENCE OR ORCHESTRATION" applies. PTY for *tool execution* (e.g., shell commands) is allowed; verify the security hardening from `agent_core/src/security.rs::harden_cli_subprocess` covers every PTY spawn site. (b) `github.rs` (712 lines) and `web_search.rs` (654 lines) are Pro-tier — no Settings UI labels them as Pro-only (W-32 unbuilt). (c) MCP server hosting (per CLAUDE.md "Swift owns: MCP server hosting") is separate from this client-side bridge; verify the host-side path is captured in another row. |
| **Next action** | T09 scope: classify; out-of-scope to fix. Future tick: split this row into per-tool-class rows (vault tools, graph tools, git tools, github tools, web_search tools, memory tools, agents) since each has different lane / status / gate. |
| **Falsifier** | `F-OmegaMCP-PTYSecurityHardening` (NOT IMPLEMENTED): grep gate asserting every `omega-mcp/src/pty.rs` spawn site invokes `agent_core::security::harden_cli_subprocess`. `F-OmegaMCP-ProToolGating` (NOT IMPLEMENTED): runtime test that asserts github / web_search tool execution requires Pro-tier capability. |
| **Cross-links** | [[bridge.rs]] (separate from this — `omega-mcp` has its own UniFFI surface); [[AppEnvironment]]; CLAUDE.md FILE MAP §"Rust omega-mcp crate"; CLAUDE.md "Subprocess Hardening (security 2026-04-28)" §"mcp/client (arbitrary user MCP servers)"; AGENTS.md §"Patterns to Follow". |

## §9a. Native Note Editor (TextKit 2 path — distinct from §9 Epdoc)

### Subsystem: ProseEditor stack (`ProseEditorView` + `ProseEditorRepresentable2` + `ProseTextView2` + `MarkdownContentStorage` + `NoteChatState` + `NoteWindowManager`)

| Field | Value |
|---|---|
| **Status** | `visible-working` (writes); `visible-broken` (4 documented anti-patterns historically; current fix status partial — see Missing proof) |
| **Lane** | `MAS` |
| **User entry / caller chain** | User opens a markdown note in a window → `NoteWindowManager.swift:230` `final class NoteWindowManager` builds the window → `ProseEditorView.swift` (551 lines) is the SwiftUI shell → `ProseEditorRepresentable2:19` `struct: NSViewRepresentable` (1595 lines) bridges TextKit 2 → `ProseTextView2.swift:44` `final class: NSTextView` (2517 lines) handles wikilink + AI context menu + structural edits + divider protection → `MarkdownContentStorage.swift:10` `final class: NSObject, NSTextContentStorageDelegate` (1219 lines) provides structural + inline markdown styling for the TK2 stack → AI streaming through `NoteChatState.swift:44` `final class NoteChatState` (948 lines) inserts tokens into NSTextStorage below a `---` divider with 60ms buffering. |
| **Evidence** | 7541 lines total across 6 files. `Coordinator2` (inside `ProseEditorRepresentable2`) owns: binding sync debounce (300ms — AGENTS.md §"Patterns to Follow"), table alignment, AI callbacks (`onStreamStart`, `onTokenFlush`, `onAccept`, `onDiscard`), fold/indent helpers, transclusion overlay coordination. AGENTS.md §"Note Editor Internals — ProseEditorRepresentable2 + ProseTextView2" is the canonical narrative. Test surfaces: `NoteEditorLayoutTests.swift`, `EpdocVisibilitySourceGuardTests.swift`, `ChatPresentationTests.swift`. |
| **Missing proof** | **AGENTS.md §"Critical Anti-Patterns" documents 4 specific failure modes on this surface, each of which T09 surfaces as a falsifier candidate:** (1) **The Binding Cascade** — Coordinator writes `parent.text` → SwiftUI `onChange` → `page.needsVaultSync = true` → `@Query` refetches → `NoteTabView` re-evaluates → `loadBody()` (disk read on every re-eval) → race with next callback. Documented fix: 300ms binding-sync debounce + no sync during AI streaming. (2) **The Zone Protection Gap** — `shouldChangeTextIn` guards AI zone only during `isStreaming` → after streaming ends but before accept/discard, edits above divider don't adjust offset → stale offset → data loss on accept. Documented fix: guard whenever `hasDivider` is true. (3) **The Multi-Turn Double Insertion** — second query with `hasDivider=true` appends raw tokens without prompt header separator. Documented fix: track `lastFlushedTurnCount` and insert header on increment. (4) **The Unpersisted Dirty Flag** — `page.needsVaultSync = true` without `modelContext.save()` works in memory but `@Query(filter: ...needsVaultSync == true)` never sees it. Documented fix: always `try? modelContext.save()` immediately. *None of these documented fixes have an explicit regression test asserting the bug class cannot recur.* |
| **Next action** | Out of T09 scope. Future tick(s): each anti-pattern becomes its own falsifier row + regression XCUITest. Highest-leverage one is likely the Binding Cascade because it pierces multiple subsystems (Coordinator → SwiftUI → SwiftData @Query → SDPage state). |
| **Falsifier** | `F-ProseEditor-BindingCascade` (NOT IMPLEMENTED): XCUITest that types 100 chars rapidly and asserts `loadBody()` runs ≤ N times (not per-keystroke). `F-ProseEditor-ZoneProtection` (NOT IMPLEMENTED): test that types above divider after streaming ends (pre-accept) and asserts offset stays in sync. `F-ProseEditor-MultiTurnHeader` (NOT IMPLEMENTED): test that runs 3 sequential AI queries on the same note and asserts each turn's tokens are preceded by an inserted header separator. `F-ProseEditor-DirtyFlagPersistence` (NOT IMPLEMENTED): test that sets `page.needsVaultSync = true` + asserts a subsequent `@Query` filter call returns the page within one runloop tick (the documented fix proves `modelContext.save()` is called immediately). |
| **Cross-links** | [[Epdoc]] (parallel Tiptap web-view path — distinct surface for `.epdoc` files); [[ChatState]] (chat presentation co-state); [[VaultSyncService]] (SDPage persistence sink); AGENTS.md §"Critical Anti-Patterns" all 4 items; AGENTS.md §"Note Editor Internals"; AGENTS.md §"NoteChatState — Per-Note AI Chat"; AGENTS.md §"Patterns to Avoid"; AGENTS.md §"SwiftUI + AppKit Bridge". |

## §9. Notes / Editor / Epdoc

### Subsystem: Epdoc (`EpdocDocument` + `EpdocEditorChromeView` + js-editor Tiptap bundle)

| Field | Value |
|---|---|
| **Status** | `visible-working` |
| **Lane** | `MAS` |
| **User entry / caller chain** | User opens a `.epdoc` file → `EpdocDocument` (`public final class EpdocDocument: NSDocument, @unchecked Sendable` at `Epistemos/Engine/EpdocDocument.swift:57`, 648 lines) loads the document → `EpdocEditorChromeController` (`public final class` at `EpdocEditorChromeView.swift:94`, 928 lines) constructs the chrome → `EpdocEditorChromeView` (`public struct View` at line 371) renders the Tiptap WKWebView → `EpdocWebViewShared.processPool` static `WKProcessPool` collapses N WKContent processes (CLAUDE.md perf wave). Toolbar at `EpdocEditorToolbar.swift` (366 lines). Floating panels: `Epdoc{Slash,Bubble,KaTeX,BlockContext,InsertLink,BlockGutter,ComplexityMeter,ThoughtAttachedBadge}*`. Paste classifier: `EpdocPasteClassifier.swift` (210 lines). Block templates: `EpdocBlockTemplateStore.swift` (139 lines). JS bundle source: `js-editor/` (package.json + src/ + scripts/ + webpack.config.js) built via `build-tiptap-bundle.sh` content-hash gated on `package-lock.json`. |
| **Evidence** | All files above + CLAUDE.md FILE MAP §"Swift Epdoc (W7.17 — Tiptap chrome)" + §"JS Bundle (Tiptap editor)" + §"Swift Memory + Energy Hardening" §`EpdocEditorChromeView.swift:27-45` (process-pool sharing) + §"`EpdocEditorChromeView.swift:330-365`" (dismantle hook releases userContentController + AP1 display link + autosave + dispatch closure) + §"Wave 2026-04-29" §`EpdocEditorChromeView.swift:312-318` (`config.websiteDataStore = .nonPersistent()`) + §`EpdocEditorChromeView.swift:40-77` (`liveWebViewCount` atomic registry + `resetPoolIfIdle()` on memory pressure). |
| **Missing proof** | (a) The js-editor build is content-hash gated on `package-lock.json` — CI must `npm ci` before xcodebuild to keep the hash gate honest (per CLAUDE.md §"JS Bundle (Tiptap editor)"); verify CI does this. (b) The "Editor bundle health" Settings row (`EditorBundleHealthRow` per CLAUDE.md) reads bundle path size + last-build timestamp — verify the row is wired in `SettingsView` and updates on bundle rebuild. (c) Tiptap bundle is loaded from `Epistemos.app/Contents/Resources/Editor/` — CLAUDE.md "NEVER spawn npm at runtime — MAS sandbox + hardened runtime block subprocess execution from a notarized app" — confirm no `Process()` spawn references `npm` anywhere in Epistemos/. |
| **Next action** | Out of T09 scope. Future tick: classify each floating panel as a sub-row (slash menu, bubble menu, KaTeX preview, block-context menu, etc.) — they have different visibility / wiring status. |
| **Falsifier** | `F-Epdoc-NoRuntimeNpm` (NOT IMPLEMENTED): grep gate asserting `rg "Process\\(\\)" Epistemos/Views/Epdoc Epistemos/Engine` returns zero matches that reference `npm` / `node` / bundle-rebuild. `F-Epdoc-BundleHealthRowWired` (NOT IMPLEMENTED): XCUITest opening Settings → "Editor bundle health" and asserting the row renders bundle path + size + timestamp. |
| **Cross-links** | [[AppBootstrap]] (instantiates `EditorBundleHealthRow` consumers); CLAUDE.md §"Swift Epdoc (W7.17 — Tiptap chrome)" + §"JS Bundle (Tiptap editor)" + §"Wave 2026-04-29 perf additions"; AGENTS.md §"Note Editor Internals" (note: Epdoc is the Tiptap web-view path; `ProseEditorView.swift` / `ProseTextView2.swift` is the parallel native TextKit 2 path). |

## §5b. Streaming surface

### Subsystem: StreamingDelegate (Swift)

| Field | Value |
|---|---|
| **Status** | `current-wired` |
| **Lane** | `MAS` / `Infrastructure` |
| **User entry / caller chain** | Chat / agent turn launches Rust agent loop via FFI → Rust streams events back via UniFFI callbacks → `StreamingDelegate` instance receives `onThinkingDelta`, `onTextDelta`, `onToolInputDelta`, `onToolStarted`, `onToolCompleted`, `onSubagentSpawned`, etc. → yields to `AsyncStream<AgentStreamEvent>.Continuation` → SwiftUI consumer iterates via `for await` → updates `ChatState.messages` per delta. |
| **Evidence** | `Epistemos/Bridge/StreamingDelegate.swift:515` `nonisolated final class StreamingDelegate: AgentStreamEventDelegate, @unchecked Sendable` (884 lines total). Side types defined earlier in the same file: `ToolConfig` (44), `ToolSchemaFFI` (59), `ToolExecutionResultFFI` (67), `AgentConfigFFI` (73), `ReasoningTrajectoryMetricsFFI` (88), `AgentResultFFI` (99). Per-token signpost on `onTextDelta` (line 533-540) instruments the highest-frequency UniFFI callback — matches CLAUDE.md "STREAM EVERYTHING. Forward every token to the delegate immediately. No buffering." |
| **Missing proof** | (a) `pendingPermissions` (line 517) and `permissionResults` (518) under `NSLock` (519) implement a 300s blocking permission wait — no timeout-stress test asserts behavior when 300s expires. (b) The `@unchecked Sendable` annotation means the type's internal mutability is unchecked by the compiler — relies on `NSLock` discipline; no TSAN test verifies this. (c) `continuation.yield` is unbounded under the default `AsyncStream` buffering — CLAUDE.md "DO NOT — Use AsyncStream with .unbounded buffering — use .bufferingNewest(256)" — verify the construction site of `StreamingDelegate` uses bufferingNewest. |
| **Next action** | Locate the `AsyncStream` constructor that produces this delegate's `continuation`; confirm `bufferingPolicy: .bufferingNewest(256)` is passed. If not, that's a CLAUDE.md rule violation surfaced by this row. (Out of T09 scope to fix — flagged for the wiring backlog.) |
| **Falsifier** | `F-Streaming-AsyncStreamBuffering` (NOT IMPLEMENTED): grep gate / lint that fails the build if any `AsyncStream<AgentStreamEvent>` construction site omits the `.bufferingNewest(256)` policy. |
| **Cross-links** | [[agent_loop.rs]]; [[bridge.rs]]; CLAUDE.md "DO NOT — Use AsyncStream with .unbounded buffering"; CLAUDE.md "STREAM EVERYTHING"; AGENTS.md §"Patterns to Avoid". |



| Field | Value |
|---|---|
| **Status** | `visible-working` |
| **Lane** | `MAS` |
| **User entry / caller chain** | User chats with a local model that has `LocalToolGrammar.supportsLocalAgentLoop` enabled → `ConfidenceRouter.isEligibleForLocalAgentLoop(...)` (line 195) checks profile → `InferenceState.canRouteToLocalAgentLoop(for:)` (line 4940) gates → `ChatCoordinator.runCommandCenterLocalAgentPath(...)` → factory at `LocalAgentLoop.swift:230` builds the actor with `mlxGenerator` + repair generator → `LocalAgentLoop.run(...)` (line 255) iterates grammar-constrained tool calls → streams `AgentEvent` back. Production callers verified: `AgentRuntime`, `DeviceAgentService`, `ToolTierBridge`, `IMessageDriverService`, `ChatCoordinator`. |
| **Evidence** | `Epistemos/LocalAgent/LocalAgentLoop.swift:64` `actor LocalAgentLoop` (2158 lines). Companion: `LocalAgentPromptBuilder.swift` (207 lines — Swift-side canonical prompt builder; CLAUDE.md names this + `LocalAgentGatewayPolicy.swift` as the canonical local-agent path replacing the purged Hermes subprocess). `ConfidenceRouter.swift` (227 lines, line 82 + 195 eligibility gating). `IncrementalToolCallDetector.swift` parses grammar tokens. 6 test instantiations in `LocalAgentLoopTests.swift`. AppBootstrap line 2389 logs `local-agent-loop=OK\|BLOCKED` based on `LocalToolGrammar.supportsLocalAgentLoop`. |
| **Missing proof** | (a) `supportsLocalAgentLoop` is per-model — some local models have HONEST grammar support, others fall back to "soft guidance" (CLAUDE.md "HONEST CAPABILITY GATING"); no Settings UI exposes this per-model state (W-12 unbuilt). (b) No invariant test asserts that when `LocalToolGrammar.supportsLocalAgentLoop = false`, the loop never silently degrades to a fake agent capability — the AGENTS-bible rule "Never fake agent capability for local models" needs a grep gate. (c) Streaming buffer bounds under high-token-rate models are not stress-tested. |
| **Next action** | Out of scope for T09. T11 (`agent_runtime_v2`) handles the typed/budgeted/witnessed executor replacing this surface for governed paths. W-12 surfaces the per-model honesty badge. |
| **Falsifier** | `F-LocalAgent-FakeCapabilityGuard` (NOT IMPLEMENTED): grep gate that asserts no code path returns `true` from agent-eligibility when the underlying `LocalToolGrammar` returns `false`. |
| **Cross-links** | [[MLXInferenceService]]; [[ConfidenceRouter]] (to be classified); [[LocalAgentPromptBuilder]] (to be classified); `W-12` (per-model HONEST/EXPERIMENTAL/OFF badges); T11 (`agent_runtime_v2` — the eventual successor). CLAUDE.md "NO SIDECAR" + "Hermes namespace fully purged 2026-05-05" doctrine. |


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


## §6. Cognitive DAG + Provenance

### Subsystem: cognitive_dag schema (`node.rs` + `edge.rs` + `storage.rs` + `merkle.rs` + `redb_store.rs`)

| Field | Value |
|---|---|
| **Status** | `current-wired` |
| **Lane** | `MAS` (typed event substrate) |
| **User entry / caller chain** | Every meaningful Rust event (claim commit, evidence commit, skill load, procedure record) calls into `cognitive_dag::dispatch::*` which writes typed Nodes + Edges into the global `DagStore`. Swift `RustCognitiveDagClient` (`Epistemos/Engine/RustCognitiveDagClient.swift`) wraps the FFI; `ProvenanceConsoleProjectionService` and `MutationOpLogReplay` consume DAG state in Swift. |
| **Evidence** | `agent_core/src/cognitive_dag/node.rs:222` `pub enum NodeKind` (612 lines incl. side types `NodeId`/`Timestamp`/`Hash`/`AuthorRef`/`MimeType`/`ClaimScope`/`SourceRef`). `edge.rs:33` `pub enum EdgeKind` (473 lines; also `EdgeKindSelector`, `MemoryTier`, `AnnotationKind`, `EdgeSignature`, `EdgeId`, `Edge`). `storage.rs:42` `pub trait DagStore: Send + Sync`, `storage.rs:112` `pub struct InMemoryDagStore` (899 lines). `redb_store.rs` (677 lines — persistent storage). `merkle.rs` (148 lines — root hash). `mod.rs` (176 lines — re-exports). Usage count: `rg "NodeKind::"` = 102 callers, `rg "EdgeKind::"` = 103 callers across `agent_core/src/`. |
| **Missing proof** | (a) The 10 NodeKind variants + 10 EdgeKind variants are documented in CLAUDE.md FILE MAP but no test enumerates the variants and asserts the count + names match the doctrine (`docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md`); (b) `EdgeSignature([u8; 32])` is a fixed-size signature — the storage trait's `put_edge` is "capability-bound (CD-005)" per CLAUDE.md, but no end-to-end test confirms an unsigned edge cannot be persisted via the `DagStore` API; (c) Merkle root parity between in-memory and redb stores is asserted in `epistemos_trace verify-replay` but no CI gate exists per W-row inventory. |
| **Next action** | Future tick (deep hardening): add `CognitiveDagSchemaInvariantTests.rs` that enumerates all `NodeKind` + `EdgeKind` variants via match-exhaustiveness and asserts the counts (10 + 10) — drift-detection gate. |
| **Falsifier** | `F-CognitiveDag-SchemaVariantCount` (NOT IMPLEMENTED): the match-exhaustive variant-count test. `F-CognitiveDag-MerkleRootParity` (PARTIAL — `epistemos_trace verify-replay` exists but no CI gate). |
| **Cross-links** | [[cognitive_dag::dispatch]]; [[cognitive_dag::macaroons]]; [[provenance::ledger]]; CLAUDE.md FILE MAP §"Rust agent_core — V2.1 Cognitive DAG (Phase 8.A-8.G)"; `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md`. |

### Subsystem: cognitive_dag::dispatch (auto-invoke)

| Field | Value |
|---|---|
| **Status** | `current-wired` |
| **Lane** | `MAS` |
| **User entry / caller chain** | Production hooks invoked from 5 verified call sites: (1) `provenance/ledger.rs:516` `dispatch::on_evidence_committed`; (2) `provenance/ledger.rs:581` `dispatch::on_claim_committed`; (3) `skill_router.rs:59` `dispatch::on_skills_loaded`; (4) `agent_runtime/procedural_memory.rs:93` `dispatch::on_procedure_recorded`; (5) `bridge.rs:3206` `dispatch::cognitive_dag_store()` for FFI store access. Each call writes typed Nodes/Edges into the global DAG via process-local sentinel-cap signing. |
| **Evidence** | `agent_core/src/cognitive_dag/dispatch.rs` (598 lines). Imports macaroons at line 28 (`use super::macaroons::{issue, restrict, Caveat, Macaroon}`). System-mirror capability hash derived from a process-local macaroon at lines 474-491 (the doc comment explicitly retires the older "0xE5 sentinel" pattern: "A2: was a 0xE5 sentinel; now derived from a process-local macaroon"). Tests `system_mirror_capability_hash_is_process_stable` + `system_mirror_macaroon_root_key_has_entropy` + `system_mirror_macaroon_carries_dispatch_authority` (visible at lines 472-505). `tracing` instrumentation at lines 207/234/276/327/378 with `target: "cognitive_dag::dispatch"`. |
| **Missing proof** | (a) The 5 production hooks fire on commit but no integration test reads back the DAG state and asserts the expected edges materialized for a fixture sequence (e.g. "evidence committed → exactly 1 SupportsBy edge added"); (b) The sentinel-cap registration is "first use" — no test asserts what happens under concurrent first-use races. |
| **Next action** | Future hardening tick. |
| **Falsifier** | `F-CognitiveDag-DispatchProductionHooks` (NOT IMPLEMENTED): integration test that runs through commit_claim / commit_evidence / record_skill / record_procedure and asserts the expected dispatch-emitted Edge counts. |
| **Cross-links** | [[cognitive_dag schema]]; [[cognitive_dag::macaroons]]; [[provenance::ledger]]; CLAUDE.md FILE MAP §"Auto-invoke dispatch (sentinel-cap registered on first use)". |

### Subsystem: cognitive_dag::macaroons

| Field | Value |
|---|---|
| **Status** | `current-wired` (correction — see CLAUDE.md drift note below) |
| **Lane** | `MAS` (Infrastructure under DAG capability signing) |
| **User entry / caller chain** | `cognitive_dag::dispatch.rs:28` imports `{issue, restrict, Caveat, Macaroon}` and uses them to derive the system-mirror capability hash at lines 474-491 — process-local macaroon root key signs every dispatch-emitted edge. |
| **Evidence** | `agent_core/src/cognitive_dag/macaroons.rs` (930 lines). Public surface: `Caveat` enum (42), `Macaroon` struct (76), `issue` (159), `restrict` (196), `delegate` (222), `verify_macaroon` (234), `evaluate_caveats` (254), `RuntimeContext` (348), `VerifyError` (356), `CaveatViolation` (362), `revoke_macaroon_in_dag` (395). Re-exported via `cognitive_dag/mod.rs:52`. |
| **Missing proof** | **CLAUDE.md drift detected.** CLAUDE.md FILE MAP §"Rust agent_core — V2.1 Cognitive DAG (Phase 8.A-8.G)" says: "Macaroon-style capabilities (orphan until Phase 8.H wires them into dispatch)". But `cognitive_dag/dispatch.rs:28` already imports macaroons and the tests at dispatch.rs:472-505 prove the system-mirror macaroon signs every dispatch-emitted edge. **Either CLAUDE.md is stale or "Phase 8.H" landed silently.** This row's contribution: surface the doc-drift; T09's job is classification, not CLAUDE.md edits (CLAUDE.md is touched by app-code lanes, out of T09 scope). Append W-row recommendation: update CLAUDE.md to reflect macaroons-in-dispatch wiring. |
| **Next action** | Append a new W-row to `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` recommending the CLAUDE.md FILE MAP correction. (Done in a separate iter — see iter-22.) |
| **Falsifier** | `F-Macaroon-ProcessLocalKeyEntropy` (PASS — `dispatch.rs::system_mirror_macaroon_root_key_has_entropy` already exists and asserts the root key is not 0x00/0xE5/0xFF sentinels). `F-Macaroon-CaveatExhaustive` (NOT IMPLEMENTED): match-exhaustive test asserting every `CaveatViolation` arm is reachable from at least one rejection path. |
| **Cross-links** | [[cognitive_dag::dispatch]]; CLAUDE.md FILE MAP §"V2.1 Cognitive DAG" (STALE — macaroons no longer orphan); future W-row "update CLAUDE.md macaroons claim". |

### Subsystem: agent_core::provenance (ClaimLedger + ReplayBundle)

| Field | Value |
|---|---|
| **Status** | `current-wired` (ClaimLedger as in-memory global); `visible-working` (Provenance Console projection on Swift side) |
| **Lane** | `MAS` |
| **User entry / caller chain** | Rust path: every Claim commit goes through `ClaimLedger::commit_claim` which (a) writes to the in-memory ledger with retraction-walk depth ≤ 16 bounded, (b) auto-fires `cognitive_dag::dispatch::on_claim_committed` (`ledger.rs:581`), (c) propagates retractions via deterministic BFS. Swift path: `RustProvenanceLedgerClient` (`Epistemos/Engine/RustProvenanceLedgerClient.swift`) wraps the FFI surface (`bridge.rs:2980-3008` — global `RwLock<ClaimLedger>` accessed via `provenance_ledger()`); `ProvenanceConsoleProjectionService` (`Epistemos/Engine/ProvenanceConsoleProjectionService.swift`) projects ledger snapshots into the Provenance Console UI. Replay path: `epistemos_trace verify-replay <bundle>` reconstructs a `LedgerSnapshot` from a `.epbundle` and verifies BLAKE3 integrity + DAG merkle parity. |
| **Evidence** | `agent_core/src/provenance/ledger.rs` (1495 lines): `ClaimLedger` with `MAX_RETRACTION_WALK_DEPTH = 16`, deterministic BTreeSet output, sorted-BFS for byte-equal `RetractionReport`. `agent_core/src/provenance/replay.rs` (1248 lines): `ReplayBundle` + `LedgerSnapshot` + `DagSnapshot` embedding (schema v1 / v2); `to_epbundle_bytes()` / `from_epbundle_bytes()` for `.epbundle` IO. `agent_core/src/bin/epistemos_trace.rs` Phase-1 / 8.F CLI. CLI fixture generator at `agent_core/examples/generate_sample_epbundle.rs`. CLAUDE.md FILE MAP cites 10 ledger unit tests + 7 ReplayBundle unit tests + 6 e2e CLI integration tests (`agent_core/tests/epistemos_trace_e2e.rs`). |
| **Missing proof** | (a) ClaimLedger is process-global behind an `RwLock` — under heavy multi-session load the write lock could become a contention point; no contention benchmark exists. (b) `MAX_RETRACTION_WALK_DEPTH = 16` is a hard bound — fixture corpus that probes the depth-17+ behavior (graceful truncation vs. silent drop) is not enumerated. (c) The Swift `ProvenanceConsoleProjectionService` projects to a console UI — verify the console has a row in Settings or Diagnostics (W-25/W-03 backlog) and isn't `hidden-working` from the user. |
| **Next action** | Future tick: classify `ProvenanceConsoleProjectionService` separately (likely `hidden-working` or `visible-working` depending on whether a Settings row exposes it). T09 scope: this row stays as a consolidated current-wired/visible-working hybrid. |
| **Falsifier** | `F-Provenance-RetractionDeterminism` (PASS — 10 ledger unit tests per CLAUDE.md). `F-Provenance-BundleIntegrity` (PASS — `epistemos_trace verify` Phase-1 + `verify-replay` Phase-8.F integration tests). `F-Provenance-ConsoleVisibility` (NOT IMPLEMENTED): XCUITest asserting Provenance Console renders ≥ 1 ACS-anchored claim on a fixture run (gated by W-03 / W-25). |
| **Cross-links** | [[cognitive_dag::dispatch]] (auto-fires on commit); CLAUDE.md FILE MAP §"Rust Provenance Ledger + ReplayBundle + epistemos-trace (Phase 1 — 2026-04-28)"; `W-03` (ClaimLedger ACS-anchor); `W-25` (Provenance Console ACS-anchor column). |


## §7. SCOPE-Rex + Cognitive Weight Class + ACS + UAS

### Subsystem: agent_core::scope_rex::answer_packet (AnswerPacket V6.2 substrate)

| Field | Value |
|---|---|
| **Status** | `current-wired` (Rust + Swift mirror); `visible-broken` (Brain Panel surface — per T22B prompt) |
| **Lane** | `MAS` |
| **User entry / caller chain** | Cloud / local agent turn → Rust side fills an `AnswerPacket` (`answer_packet.rs:247`) with `claim_kind`, `attention_mode`, `residency_signal`, `vrm_label` and witnessed-state / semantic-delta / mutation-envelope IDs → produced via `scope_rex::produce` (`produce.rs`, 306 lines) → serialized to canonical JSON → FFI returns to Swift `RustAnswerPacketProducerClient` → `AnswerPacketEmitter` (Swift) renders into chat row state. Swift mirror types live in `Epistemos/Models/AnswerPacket.swift`. |
| **Evidence** | `agent_core/src/scope_rex/answer_packet.rs` (579 lines). Public surface: `AnswerPacketId` (70), `WitnessedStateId` (84), `SemanticDeltaId` (96), `MutationEnvelopeId` (108), `VrmLabel` enum (131), `AttentionMode` enum (165), `ResidencySignal` (207), `AnswerPacket` struct (247). Sibling modules in `scope_rex/`: `ontology.rs` (150 lines — `OntologyValidator` trait at line 85, `OntologyViolation` at 44, `VerificationReport` at 55, `NoOpOntologyValidator` at 92), `produce.rs` (306), `witnessed_state.rs` (206), `residency.rs` (411), `btm_semantic.rs` (466), `feature_observatory.rs` (137). Swift counterparts: `RustAnswerPacketProducerClient.swift`, `AnswerPacketEmitter.swift`, `Epistemos/Models/AnswerPacket.swift`, `ChatTypes.swift`. Tests: `AnswerPacketEmitterTests.swift`, `RustAnswerPacketProducerClientTests.swift`, `XPCStreamingScaffoldGuardTests.swift`. |
| **Missing proof** | (a) AnswerPacket IS being emitted by the Rust side per T2's W-14 row marked PARTIAL (substrate complete, per-message persistence verification pending); (b) The Brain Panel surface that should render `claim_kind` / `confidence` / `citations` badges on every chat reply is **`visible-broken`** per T22B's mission — the substrate has the data; the UI does not surface it consistently. (c) Fake-citation rejection requires the source ID to be cross-validated against Eidos hits — Eidos V0 (T10) is not yet built, so fake citations cannot currently be rejected by construction. |
| **Next action** | T22B owns the Brain Panel chat-row badge wiring. T2 W-14 owns the per-message persistence assertion test. T09's job here is the classification: AnswerPacket *substrate* is `current-wired`; AnswerPacket *visibility* surface is `visible-broken`. |
| **Falsifier** | `F-AnswerPacket-PerMessageEmission` (W-14 PARTIAL — substrate complete; persistence count gate pending). `F-AnswerPacket-FakeCitationRejection` (NOT IMPLEMENTED until T10 Eidos V0 lands — gated). `F-AnswerPacket-ClaimKindSchemaParity` (NOT IMPLEMENTED): test asserting Rust `VrmLabel` enum + Swift `AnswerPacket.swift` claim_kind variants stay byte-equal after round-trip JSON serialization. |
| **Cross-links** | [[ChatCoordinator]]; [[StreamingDelegate]]; `W-14` (AnswerPacket runtime emission); `W-27` (chat-row badge); T10 (Eidos V0 — closed citations); T22B (Brain Panel closed citations). CLAUDE.md "AnswerPacketEmitter" reference. |

### Subsystem: agent_core::scope_rex::{kernels, kv, metal, retrieval} (Research-lane sub-modules)

| Field | Value |
|---|---|
| **Status** | `implemented-not-wired` (kernels, retrieval/hopfield); `feature-gated` (kv/direct_gate); `scaffold-only` (metal/asa_index, metal/softmax) |
| **Lane** | `Research` (capability-ceiling falsifier territory; NOT MAS until F-* gates pass) |
| **User entry / caller chain** | None directly — these are substrate primitives consumed only by research lanes + falsifier harnesses. No production code in `Epistemos/` or `chat / vault / agent runtime` reads them. |
| **Evidence** | `agent_core/src/scope_rex/kernels/` (mod.rs 27 + t_mac.rs 177 + bitnet.rs 179 + sparse_ternary_gemm.rs 255 = 638 lines). `agent_core/src/scope_rex/kv/` (mod.rs 8 + direct_gate.rs 290 = 298 lines — T13 F-KV-Direct-Gate territory). `agent_core/src/scope_rex/metal/` (mod.rs 25 + asa_index.rs 371 + softmax.rs 275 = 671 lines — Metal compute kernels). `agent_core/src/scope_rex/retrieval/` (mod.rs 8 + hopfield.rs 265 = 273 lines — Hopfield-style retrieval primitive). |
| **Missing proof** | (a) The endgame prompt deck §0 + §3 explicitly forbids these from being treated as product: ModelSurgery, Active Rank-One runtime, 70B local cocktail execution, runtime VPD training, p-adic / sheaf hot-path replacements — kernels + retrieval/hopfield are Research-tier substrate that **must not** be promoted to MAS without falsifier passes. (b) `kv/direct_gate` is T13's F-KV-Direct gate substrate — Codex terminal. (c) Metal kernels in `metal/` are W-41 territory (5 Metal kernels deferred) — T3 Phase C + Apple-platform external work. |
| **Next action** | These remain `Research` lane until F-* falsifiers pass. T09's job here is just the lane discipline: do not let `kernels` / `kv` / `metal` / `retrieval` drift into MAS classification by accident. |
| **Falsifier** | `F-KV-Direct-Gate` (T13 owner); `F-ULP-Oracle` (T12 owner, touches `eml_ir/`); `F-PageGather-Baseline` + `F-PageGather-Scatter` + `F-SemiseparableBlockScan` + `F-LocalRecallIsland` (T23B handbook coverage; some not yet implemented). |
| **Cross-links** | T12 F-ULP Oracle (Codex); T13 F-KV-Direct Gate (Codex); T23B M2 Pro Falsifier Handbook (Codex); `W-41` (5 Metal kernels); `W-42` (F-KV-Direct-Gate PASS); endgame prompt deck §3 "Do not build now as product" list. |


## §8. Halo / Shadow / Contextual Shadows

### Subsystem: Halo (Swift — HaloController + HaloButton + ShadowPanel)

| Field | Value |
|---|---|
| **Status** | `visible-working` |
| **Lane** | `MAS` |
| **User entry / caller chain** | User clicks the Halo button anywhere a context surface exists → `HaloButton` (`Epistemos/Views/Halo/HaloButton.swift`) toggles the panel → `ShadowPanel` (`ShadowPanel.swift` + `ShadowPanelContent.swift`) requests results from `HaloController.search(...)` → `ShadowSearchService.search` (actor at line 198) wraps the FFI client → `RustShadowFFIClient.search` calls the Rust `epistemos-shadow` dylib → results stream back, panel renders RRF-fused lexical + semantic hits with snippets. `ProseEditorRepresentable2` (Notes) embeds Halo invocation surface too. |
| **Evidence** | `Epistemos/Engine/HaloController.swift:75` `public final class HaloController` (349 lines; line 63 `NullHaloTelemetry: HaloTelemetry, Sendable`). `Epistemos/Engine/ShadowSearchService.swift:198` `public actor ShadowSearchService: ShadowSearchServicing` (579 lines). `Epistemos/Engine/ShadowIndexingService.swift` (163 lines). UI surfaces in `Epistemos/Views/Halo/{HaloButton,ShadowPanel,ShadowPanelContent}.swift`. Tests: `HaloUITests.swift` (W8 row in CLAUDE.md FILE MAP §"Swift Halo (W8 — Contextual Shadows)"). |
| **Missing proof** | (a) Halo's "Contextual Shadows" surface is one of the few places where vault retrieval is *already* visible — but it shares the underlying BM25/HNSW pipeline that drives ChatCoordinator's broken `LIMIT N` failure mode. Need a fixture XCUITest that proves Halo on the F-VaultRecall-50 corpus returns the *expected* top-5 hits across all 50 queries; (b) `NullHaloTelemetry` exists as the default but no production telemetry sink is verified plumbed in. |
| **Next action** | Out of T09 scope. T21 owns the upstream vault.rs Fix-C drop; T22B owns Brain Panel parity. T09's job is the classification: Halo as a surface is visible-working; the *signal* it consumes inherits whatever the upstream RRF + Tantivy + HNSW pipeline produces. |
| **Falsifier** | `F-Halo-VaultRecall-50` (NOT IMPLEMENTED): XCUITest that opens Halo for each of the 50 fixture queries and asserts top-5 contains the expected gold note. Distinct from `F-VaultRecall-50` (which measures vault.rs hybrid_search end-to-end). |
| **Cross-links** | [[ShadowSearchService]]; [[RustShadowFFIClient]]; [[ShadowVaultBootstrapper]]; [[ChatCoordinator]]; `W-20` (provenance cards in Halo / ChatInputBar); F-VaultRecall-50. CLAUDE.md §"Swift Halo (W8 — Contextual Shadows)". |

### Subsystem: epistemos-shadow (Rust crate — Tantivy BM25 + usearch HNSW + RRF fusion)

| Field | Value |
|---|---|
| **Status** | `current-wired` (Rust); `visible-working` (Halo surface) |
| **Lane** | `MAS` |
| **User entry / caller chain** | Swift `RustShadowFFIClient` (524 lines) binds 10 `@_silgen_name` FFI entry points: `shadow_handle_open_at` (line 15), `shadow_handle_retain` (20), `shadow_handle_release` (25), `shadow_handle_search` (30), `shadow_handle_insert` (39), `shadow_handle_remove` (45), `shadow_handle_flush` (51), `shadow_handle_stats` (56), `shadow_handle_last_timings_json` (62), `shadow_handle_free_string` (68). `AppBootstrap.initializeShadowBackendIfReady` calls `RustShadowFFIClient.openAt(<vault>/.epcache/shadow)` and `ShadowVaultBootstrapper` (`public actor ShadowVaultBootstrapper` at `ShadowVaultBootstrapper.swift:74`, 298 lines) crawls `<vault>/notes/**/*.md` + `<vault>/chats/**/*.json` to populate the index. |
| **Evidence** | `epistemos-shadow/src/` (3651 lines total): `lib.rs` 332, `state.rs` 624, `honest_handle.rs` 613, `error.rs` 49. Backend submodules: `backend/mod.rs` 585, `backend/lexical_index.rs` 407 (Tantivy 0.22 BM25, `WRITER_HEAP_BYTES = 15 MB` per CLAUDE.md perf wave), `backend/vector_index.rs` 481 (usearch 2.24 HNSW), `backend/rrf.rs` 401 (RRF k=60 source-of-truth at line 22 `RRF_K_DEFAULT` — mirrored by Swift `Phase3FusionConsts.K_RRF=60`), `backend/embedder.rs` 159. cdylib build per `build-epistemos-shadow.sh`. |
| **Missing proof** | (a) The crate is a separate cdylib (not the `agent_core` static lib) — build orchestration across Swift's `xcodebuild` and the Rust dylib is documented in `build-epistemos-shadow.sh` but no CI gate prevents version drift between the crate's exported FFI symbols and the Swift `@_silgen_name` declarations. (b) `RRF_K_DEFAULT = 60` in Rust must equal `Phase3FusionConsts.K_RRF = 60` in Swift — `EpistemosTests/RRFFusionQueryTests.swift` already includes a K_RRF parity probe per CLAUDE.md, but verify it actually compares to the Rust constant (not a Swift-only mirror). |
| **Next action** | Out of T09 scope. The FFI symbol drift falsifier overlaps with the `agent_core::bridge` row's `F-FFI-SymbolDrift` proposal. |
| **Falsifier** | `F-ShadowFFI-SymbolDrift` (NOT IMPLEMENTED): nm gate on `libepistemos_shadow.dylib` confirming the 10 documented `shadow_handle_*` exports exist and no others. `F-Shadow-RRFParityWithSearchIndexService` (PARTIAL — Swift `RRFFusionQueryTests.swift` includes K_RRF probe; verify it compares against the Rust source). |
| **Cross-links** | [[Halo (Swift)]]; [[SearchIndexService]] (Swift-side RRF fusion shares the k=60 constant); [[bridge.rs]]; `W-04` (page-gather → vault.rs); `W-20` (provenance cards across surfaces). CLAUDE.md §"Halo Shadow index (W8.4 / W8.7)" + §"Swift Halo (W8 — Contextual Shadows)". |

## §10. LSP + Knowledge Fusion

### Subsystem: agent_core::lsp_runtime (in-process LSP — V2.3)

| Field | Value |
|---|---|
| **Status** | `feature-gated` |
| **Lane** | `Pro` (Pro-tier code intelligence surface) |
| **User entry / caller chain** | When the `lsp-runtime` cargo feature is enabled at build time → Swift side `RustLSPTransport.swift` (252 lines) drives the Rust `LspKernel` via FFI exports `lsp_send_message_json` + `lsp_poll_response_json` → `LSPClient.swift` (473 lines) routes per-document `didOpen` / `didChange` / `hover` / `definition` requests → `LSPMessage.swift` (362 lines) codec handles JSON-RPC framing. The subprocess transport (`LSPServerProcess`) was DELETED 2026-05-05 in the V2.3 close-out (commit `813c15dd` per CLAUDE.md). |
| **Evidence** | `agent_core/src/lsp_runtime/mod.rs` (1161 lines): `LspKernel` handles `initialize` / `didOpen` / `didChange` / `hover` / `definition` via tree-sitter Rust + Swift. Feature flag in `agent_core/Cargo.toml:29`: `lsp-runtime = ["tower-lsp", "tree-sitter", "tree-sitter-rust", "tree-sitter-swift"]`. FFI exports gated at `agent_core/src/bridge.rs:3120`, `3158`, `3178` (all `#[cfg(feature = "lsp-runtime")]`). CLAUDE.md FILE MAP §"Rust agent_core — In-process LSP runtime (V2.3)" + §"Swift LSP (V2.3 — in-process Rust transport)". |
| **Missing proof** | (a) Feature-gated means **default build does NOT include LSP** — no Settings UI surfaces the gate state to the user; (b) tree-sitter Rust + Swift parsers are bundled when the feature is on — verify they don't bloat the binary unacceptably when enabled in MAS builds; (c) `LSPServerProcess` deletion (commit `813c15dd`) eliminated subprocess transport — verify no dead code remains in Swift that references the deleted process transport (the `LSPTransport.swift` protocol seam survives; the subprocess impl is gone). |
| **Next action** | Out of T09 scope. The Pro-tier classification is correct — LSP belongs in Pro (direct-distribution) builds, not in MAS (App Store-sandboxed) builds by default because tree-sitter parsers + tower-lsp aren't App Store-compliant out of the box. Confirm via the EPISTEMOS_APP_STORE conditional pattern used in `AppEnvironment.swift:39-41`. |
| **Falsifier** | `F-LSP-FeatureGateRespected` (NOT IMPLEMENTED): build-time test asserting the default `cargo build -p agent_core` excludes the LSP symbols, and `cargo build -p agent_core --features lsp-runtime` includes them. `F-LSP-SubprocessTransportGone` (NOT IMPLEMENTED): grep gate that asserts no Swift file references the deleted `LSPServerProcess` symbol. |
| **Cross-links** | [[bridge.rs]] (`#[cfg(feature = "lsp-runtime")]` exports); CLAUDE.md §"Rust agent_core — In-process LSP runtime (V2.3)"; CLAUDE.md §"Swift LSP (V2.3 — in-process Rust transport)" — both name the canonical files. |


### Subsystem: KnowledgeFusion (CloudKnowledgeDistillationService + Alignment + SyntheticData)

| Field | Value |
|---|---|
| **Status** | `visible-working` (lazy-init; reached when user enables KTO training / synthetic-data generation); some sub-paths `feature-gated` |
| **Lane** | `Pro` (training + distillation are Pro-tier; Tier 2 bundled / OFF by default) |
| **User entry / caller chain** | User opens KnowledgeFusion UI (`Epistemos/KnowledgeFusion/UI/KnowledgeFusionViewModel.swift`) → triggers `CloudKnowledgeDistillationService` job → service uses `SyntheticData/SyntheticDataGenerator` + `InstructionBacktranslator` + `ODIATraceGenerator` to produce traces → `Alignment/KTOTrainer` (`actor KTOTrainer` at line 19) runs KTO objective via `TrainingScheduler` (`final class` at line 16) → `FeedbackLogger` + `CSISafeguard` gate writes → results materialized via lazy-init pathway. Lazy-init at `AppBootstrap.swift:1570-1578` (cloudKnowledgeDistillationService) + `:1557-1561` (noteInsightService), per CLAUDE.md Wave 2026-04-29: "Defers 6-15 MB until first user-action access". |
| **Evidence** | `Epistemos/KnowledgeFusion/` (10338 lines total). `CloudKnowledgeDistillationService.swift:17` `actor CloudKnowledgeDistillationService`. `Alignment/`: `KTOTrainer.swift` (198 lines, actor + `KTOTrainingResult: Sendable` at line 5), `TrainingScheduler.swift` (377), `FeedbackLogger.swift` (336), `CSISafeguard.swift` (107). `SyntheticData/`: `ODIATraceGenerator.swift` (121), `InstructionBacktranslator.swift` (218), `SyntheticDataGenerator.swift` (166), `TraceDataMixer.swift` (67), `QualityCurator.swift` (276). UI: `KnowledgeFusionViewModel.swift`. Tests: `KTOAlignmentTests.swift`, `InstantRecallTests.swift`, `AdapterManagementTests.swift`. |
| **Missing proof** | (a) **Doctrine tension**: AGENTS.md §"TriageService" says "no cloud fallback in the live app" + endgame deck §3 forbids "hidden cloud escalation" in MAS. KnowledgeFusion does cloud distillation — verify it's reachable ONLY through an explicit user-consent flag, never an automatic chat-turn path. (b) `KTOTrainer` is `actor`-bound; verify it never runs on `@MainActor` (training would block UI). (c) `CSISafeguard` is named for the CSI safety check (Camera/Screen/Input — privacy-sensitive surfaces) — verify it's actually evaluated *before* any distillation write to the corpus. |
| **Next action** | Out of T09 scope. Future tick: split into per-subsystem rows (Alignment, SyntheticData, CSISafeguard, CloudKnowledgeDistillationService) — each warrants its own classification. |
| **Falsifier** | `F-KnowledgeFusion-CloudGatedByUserConsent` (NOT IMPLEMENTED): runtime gate test asserting `CloudKnowledgeDistillationService` never invoked without explicit user consent flag. `F-KTOTrainer-NotOnMainActor` (NOT IMPLEMENTED). `F-CSISafeguard-PreWritePath` (NOT IMPLEMENTED): integration test that any distillation write invokes `CSISafeguard.evaluate(...)` first. |
| **Cross-links** | [[AppBootstrap]] (lazy init at 1557-1561 + 1570-1578); [[TriageService]] (separate routing — local only); CLAUDE.md "Wave 2026-04-29 perf additions"; endgame deck §3 "Do not build now as product" + §0 Tier table. |

## §10c. Subprocess hardening (security)

### Subsystem: `agent_core::security::harden_cli_subprocess` (env-clear + allowlist + denylist + kill_on_drop + process_group)

| Field | Value |
|---|---|
| **Status** | `current-wired` |
| **Lane** | `Infrastructure` (security primitive consumed by every subprocess spawn) |
| **User entry / caller chain** | Any code path that spawns a subprocess for tool execution → must call `harden_cli_subprocess(&mut cmd)` (line 937) before `.spawn()`. Variants: `harden_cli_subprocess_extending(cmd, &[extra_var_names])` (line 949 — extends allowlist with named env vars), `harden_cli_subprocess_std(cmd)` (line 976 — sync `std::process::Command` variant). |
| **Evidence** | `agent_core/src/security.rs:937` `pub fn harden_cli_subprocess(...)`. Production callers verified: `agent_core/src/tirith.rs`, `agent_core/src/tools/imessage.rs`, `agent_core/src/tools/browser.rs`, `agent_core/src/tools/registry.rs`, `agent_core/src/tools/cli_passthrough.rs`, `agent_core/src/mcp/client.rs`, `agent_core/src/tools/media.rs`, `agent_core/src/tools/apple.rs`, `agent_core/src/tools/terminal.rs` (10 sites per CLAUDE.md §"Subprocess Hardening"). CLAUDE.md cites the canonical 10-var allowlist (PATH, HOME, USER, LOGNAME, TMPDIR, LANG, LC_ALL, LC_CTYPE, TERM, TZ) + 24-vector denylist (LD_PRELOAD, all DYLD_*, MallocStackLogging family, NODE_OPTIONS, PYTHONPATH/HOME/STARTUP, RUBYOPT/RUBYLIB, PERL5OPT/PERL5LIB) + `kill_on_drop(true)` + `process_group(0)` on Unix. 4 tests cover real-subprocess LD_PRELOAD + DEBUG leak prevention, PATH preservation, allowlist/denylist disjoint invariant, doctrine-named-vector presence. |
| **Missing proof** | (a) The 10 documented spawn-site list in CLAUDE.md is a snapshot — no CI gate asserts that EVERY new `Command::new(...)` site in `agent_core/src/` invokes `harden_cli_subprocess`; (b) `terminal.rs` had its own pre-existing equivalent hardening per CLAUDE.md — verify the duplicate code path was consolidated or document why it stays separate; (c) `omega-mcp/src/pty.rs` (662 lines) is a parallel subprocess gateway — confirm it also routes through this hardening (cross-row: [[Omega::MCPBridge + omega-mcp]] flagged the same falsifier as `F-OmegaMCP-PTYSecurityHardening`). |
| **Next action** | Out of T09 scope. The most impactful next action is a CI lint that fails the build when any new `Command::new` or `tokio::process::Command::new` in `agent_core/src/` is not preceded by a `harden_cli_subprocess` call. |
| **Falsifier** | `F-Security-SubprocessHardeningGate` (NOT IMPLEMENTED): `cargo clippy --workspace` *forbidden* per disk pressure rules; alternative: a Rust integration test using `syn` to walk the crate AST and assert every `Command::new(...)` is followed within the same function by a `harden_cli_subprocess*` call. `F-Security-AllowlistDenylistDisjoint` (PASS — existing unit test in `security.rs` per CLAUDE.md "allowlist/denylist disjoint invariant"). `F-Security-LDPreloadBlocked` (PASS — existing real-subprocess test per CLAUDE.md "4 tests including a real subprocess that proves LD_PRELOAD + DEBUG don't leak through"). |
| **Cross-links** | [[Omega::MCPBridge + omega-mcp]] (`F-OmegaMCP-PTYSecurityHardening` cross-row); CLAUDE.md §"Subprocess Hardening (security 2026-04-28)"; AGENTS.md §"NON-NEGOTIABLE CONSTRAINTS — NO SIDECAR" (subprocess for tool execution is the exception — and must be hardened). |

## §11. Graph

### Subsystem: Graph (Swift `GraphState` + `GraphStore` + `GraphBuilder` + `MetalGraphView` + `graph-engine/` Rust crate)

| Field | Value |
|---|---|
| **Status** | `visible-working` |
| **Lane** | `MAS` |
| **User entry / caller chain** | User opens the graph view → `GraphState` (`Epistemos/Graph/GraphState.swift:642` `final class GraphState`, 3498 lines) holds engine handle + pending node/edge queue + mode (`.global` / `.page(nodeId:)`) → `GraphBuilder` (662 lines) builds the subgraph from vault state (quotes, sources, wikilinks as ephemeral nodes) → `GraphStore` (`final class GraphStore` at line 83, 1278 lines) provides compact Int-indexed adjacency lookup → `MetalGraphView` (`struct: NSViewRepresentable` at line 558, 2646 lines) + `MetalGraphNSView` (`final class: NSView` at line 591) renders via Metal compute shaders → `HologramController` + `HologramOverlay` (290 lines + others) overlays. FFI: 42 functions in `graph-engine-bridge/graph_engine.h` (AGENTS.md §"FFI Boundary"). Cross-view signaling: `PhysicsCoordinator` (`@Observable` singleton in `Epistemos/State/PhysicsCoordinator.swift`) carries `graphHoveredNodeId` between Metal view and sidebar rows (zero-cost when idle per AGENTS.md). |
| **Evidence** | Swift: 5438 lines across GraphState/GraphStore/GraphBuilder; 2936 lines across MetalGraphView/HologramController; `SemanticClusterService.swift:69-156` parallelized via `DispatchQueue.concurrentPerform` (CLAUDE.md Wave 2026-04-29). Rust: `graph-engine/src/` 102270 lines including `knowledge_core/` (mod.rs 370 + parser.rs 386 — `KnowledgeCore` at line 119, `KnowledgeCoreError` enum at 50, `KnowledgeCoreTransportStats` at 42), `ecs/` (mod.rs 668 with `pub struct World` at line 15 + systems.rs 400 + components.rs 140 + bridge.rs 276 + spatial_grid.rs 279), `motion/curl.rs` 472 + `motion/waves.rs` 561. Wired into `withAppEnvironment` at `AppEnvironment.swift:28` (`.environment(bootstrap.graphState)`) + `:30` (`.environment(bootstrap.physicsCoordinator)`). |
| **Missing proof** | (a) AGENTS.md §"GraphState — FFI Bridge" cites `engineHandle: OpaquePointer?` + `pendingNodes` / `pendingEdges` queues → no test asserts the pending-queue drains within a bounded number of render-loop ticks under bulk-insert pressure; (b) Rust ECS World at `graph-engine/src/ecs/mod.rs:15` is the simulation kernel — no falsifier measures simulation step-cost on M2 Pro; (c) `MetalGraphNSView.mouseMoved` writes to `PhysicsCoordinator.graphHoveredNodeId` — per AGENTS.md "Zero cost when idle (no timers, no per-frame work)" — verify no `repeatForever` animations remain (AGENTS.md §"Patterns to Avoid"). |
| **Next action** | Future tick: split this row into per-component rows (`GraphState`, `GraphStore`, `GraphBuilder`, `MetalGraphView`, `graph-engine::knowledge_core`, `graph-engine::ecs`, `graph-engine::motion`) — each warrants its own classification. |
| **Falsifier** | `F-Graph-PendingQueueBounded` (NOT IMPLEMENTED): test that bulk-inserts 10k pending nodes and asserts the queue drains within ≤ N render ticks. `F-Graph-NoRepeatForever` (NOT IMPLEMENTED): grep gate asserting no `.repeatForever` in `Epistemos/Views/Graph/`. `F-Graph-PhysicsStepBudget-M2Pro` (NOT IMPLEMENTED): Rust benchmark measuring ECS World step cost on a representative graph; pinned to M2 Pro per hardware floor. |
| **Cross-links** | [[AppEnvironment]] (binds GraphState + PhysicsCoordinator); AGENTS.md §"GraphState — FFI Bridge" + §"GraphStore — Compact Storage" + §"PhysicsCoordinator — Cross-View State" + §"FFI Boundary (Swift <-> Rust)" + §"Critical Anti-Patterns — The Binding Cascade"; CLAUDE.md Wave 2026-04-29 §`SemanticClusterService.swift:69-156`. `W-26` (Cognitive DAG visualizer in `Epistemos/Views/Graph/` — gated on T3 + T6 merges). |

## §12. Settings UI / Diagnostics

### Subsystem: Settings UI Diagnostics rows (consolidated)

| Field | Value |
|---|---|
| **Status** | `visible-working` (the rows that exist render); but the *Substrate Health Panel* aggregate (W-29) is `not-implemented`; multiple individual rows are wired only `PARTIAL` per CROSS_TERMINAL_WIRING_BACKLOG. |
| **Lane** | `MAS` |
| **User entry / caller chain** | User opens Settings → "Diagnostics" / "General" section → individual HealthRow views render. The huge `Epistemos/Views/Settings/SettingsView.swift` (3763 lines) is the root container; ProvenanceConsoleView (39 lines) launches into the deeper console. |
| **Evidence** | 12 HealthRow files verified in `Epistemos/Views/Settings/`: `EditorBundleHealthRow.swift` (Tiptap bundle), `SearchFusionHealthRow.swift` (RRF fusion observability), `AnswerPacketHealthRow.swift:36` `public struct AnswerPacketHealthRow: View` (W-14 ladder), `APIKeysHealthRow.swift:26` (Keychain key status), `ArenaHealthRow.swift:11` (model arena state), `OpLogProjectionHealthRow.swift:10` (op-log replay), `CLIDiscoveryHealthRow.swift:24` (Pro CLI passthrough adapters), `RuntimeTruthHealthRow.swift:32` (runtime witness state), `ProcessMemoryHealthRow.swift:92` (memory pressure metrics), `DeploymentProfileHealthRow.swift:19` (App Store vs direct profile), `CognitiveDagHealthRow.swift`, `ShadowSearchHealthRow.swift`. Plus broader detail views: `AgentControlSettingsView`, `AmbientFrequencySettingsView`, `AuthoritySettingsView`, `ChannelsSettingsView`, `HELIOSv5SettingsView`, `IMessageDriverSettingsView` (gated by `#if !EPISTEMOS_APP_STORE`), `ModelVaultsSettingsView`, `OmegaSettingsDetailView`, `OverseerSettingsView`, `PerformanceSettingsSection`, `ProvenanceConsoleView`, `AgentSectionDetailView`, `PrivacyDetailView`, `CognitiveSettingsSection`. |
| **Missing proof** | (a) **No unified "Substrate Health" panel** — the endgame deck §4 T22 (Substrate Health Panel) calls for one panel surfacing agent runtime + model constellation + vault recall + EML floor + UAS-ACS + cognitive DAG + provenance + falsifier status. Per W-29 in the wiring backlog this is NOT-STARTED. The 12 individual rows exist but are scattered across Settings sub-views. (b) **No Experimental Features panel** (W-32 — flags like `EPISTEMOS_RRF_FUSION_V1`, `epistemos.localAgent.powerUserMode` have no UI). (c) `ActiveConstellationRow` referenced in W-11 backlog exists but LIVE binding to `ConfidenceRouter` + `MLXInferenceService` may be incomplete (W-11 marked PARTIAL). |
| **Next action** | Out of T09 scope. T22 + T22B + T27 own the consolidation; W-29 / W-32 are user-visibility unblockers. |
| **Falsifier** | `F-Diagnostics-AllHealthRowsLoad` (NOT IMPLEMENTED): XCUITest opening Settings and asserting every HealthRow renders without crashes on a fresh-launch vault. `F-Diagnostics-SubstrateHealthPanel` (NOT IMPLEMENTED): per-W-29 acceptance bar. |
| **Cross-links** | [[AppBootstrap]]; [[AppEnvironment]]; [[StreamingDelegate]]; W-11 (ActiveConstellationRow live binding); W-13 (power-user mode toggle); W-14 (AnswerPacketHealthRow non-zero count); W-17 (LocalAgentDiagnostics rendering); W-21 (Vault recall health row); W-29 (unified Substrate Health panel); W-32 (Experimental Features panel); W-33 (Substrate Drift Monitor). |


## §13. Research-only modules (lane = Research / Vault)

### Subsystem: agent_core::research (substrate research lanes — consolidated row)

| Field | Value |
|---|---|
| **Status** | per-lane mix: `current-wired` (`eml_integration/` — T7 deliverable, observatory + potential surfaced); `feature-gated` (`ternary/` — kernel kind / activation-tap / kv_fingerprint / steering / pack / residual_island / fused_rmsnorm — gated until F-* falsifiers pass); `implemented-not-wired` (`a2ui/`, `acs/`, `cognition_observatory/`, `continual_learning/`, `eml/`, `hyperdynamic_schemas/`, `paper_registry/`, `sherry_lattice/`, `ane_direct/`, `koopman.rs`, `tropical.rs`, `rwkv7.rs`, `mamba3.rs`, `belnap.rs`, `attention_sinks.rs`, `hybrid_memory.rs`, `compute_steering.rs`, `brain_routing.rs`, `confidence_floors.rs`, `substrate_independence.rs`, `interrupt_calibration.rs`, `test_time_regression.rs`, `para_lens.rs`, `nano_training_recipe.rs`, `action_to_eml.rs`, `biometric_gate.rs`, `nightbrain_tasks.rs`, `run_ledger.rs`); **`scope-locked-do-not-touch`** (`operator_ir/`, `scan_ir/`, `tropical_ir/` — T5 in-flight). |
| **Lane** | `Research` (capability-ceiling falsifier territory; some sub-paths `Vault` for preserved-speculation) |
| **User entry / caller chain** | None as product. These modules feed falsifier harnesses (F-ULP, F-KV-Direct, F-70B-Cocktail, F-PageGather, etc.) and Cognition Observatory diagnostics (W-07 future Settings row). MAS chat / vault / agent paths do NOT call these directly — and per AGENTS.md "no hidden cloud escalation" + endgame deck §3 "Do not build now as product" they must not become hot-path dependencies until their falsifiers pass on M2 Pro 16GB. |
| **Evidence** | Subdirectories under `agent_core/src/research/`: `a2ui/` 220K, `acs/` 104K, `ane_direct/` 36K, `cognition_observatory/` 92K, `continual_learning/` 136K, `eml/` 48K, `hyperdynamic_schemas/` 48K, `paper_registry/` 56K, `sherry_lattice/` 68K, `ternary/` 140K. Top-level files: `mamba3.rs`, `test_time_regression.rs`, `belnap.rs`, `rwkv7.rs`, `tropical.rs`, `koopman.rs`, `biometric_gate.rs`, `para_lens.rs`, `brain_routing.rs`, `confidence_floors.rs`, `substrate_independence.rs`, `attention_sinks.rs`, `hybrid_memory.rs`, `nano_training_recipe.rs`, `compute_steering.rs`, `run_ledger.rs`, `action_to_eml.rs`, `interrupt_calibration.rs`, `nightbrain_tasks.rs`. T5-locked: `operator_ir/`, `scan_ir/`, `tropical_ir/`. CLAUDE.md FILE MAP references `eml_integration/observatory.rs` + `eml_integration/potential.rs` (T7 deliverable; consumed by W-07 + W-08). |
| **Missing proof** | (a) Each of these 30+ research files / subdirs needs its own per-row classification in a future tick. T09 consolidates them here to (1) pin the lane discipline, (2) prevent any of them from drifting into MAS without a falsifier pass, (3) flag T5's frozen paths. (b) `paper_registry/` and `hyperdynamic_schemas/` deserve close audit — they may be ready for promotion to MAS as typed metadata layers (T17B + T18B territory). (c) `cognition_observatory/` is a 92K-line surface — verify its `observatory.rs` (T7) actually reaches `Settings → Diagnostics → "EML energy live readout"` (W-07 marked NOT-STARTED in backlog). |
| **Next action** | Future tick: enumerate every research subdir in its own row; T7 lands the eml_integration → observatory plumbing through W-07 (separate terminal). Append W-rows as cross-terminal needs surface. |
| **Falsifier** | Per-module falsifiers already named in T23B (M2 Pro Falsifier Handbook — Codex terminal): F-ULP-Oracle, F-KV-Direct-Gate, F-70B-Local-Cocktail-Lite, F-Eidos-ClosedCitation, F-VaultRecall-50, F-PageGather-Baseline + Scatter, F-UAS-CopyCount, F-ACS-AnchorLookup, F-InterruptScore-CPU, F-PacketRouter1bit, F-ControllerKernelPack, F-SemiseparableBlockScan, F-LocalRecallIsland, F-WBO-DriftLedger. T09 references those rather than re-defining them. |
| **Cross-links** | [[scope_rex::{kernels, kv, metal, retrieval}]] (parallel Research lane in scope_rex); CLAUDE.md FILE MAP §"Rust Provenance Ledger" cites `epistemos_trace verify-replay` which depends on research/run_ledger.rs. T5 (`codex/t5-emlir-2026-05-16`): operator_ir + scan_ir + tropical_ir frozen — append W-row before any cross-cut. T7: `eml_integration/` — W-07 + W-08. T17B: lattice/WBO register. T18B: ACS admission. T23B: M2 Pro Falsifier Handbook (full enumeration). |


## §14. Delete / Hide / Merge / Keep / Build-next lists

These lists emerge from the row classifications above. They are explicit
recommendations, not actions — T09 only proposes; the user authorizes.

### §14.1 DELETE candidates

Code paths whose existence is **net-harmful** because they (a) drift the canon, or (b) hold a "scaffold-only" surface that's been overtaken by a wired alternative. None proposed yet — every row classified so far either earned `current-wired` or is correctly preserved as `Research` lane. The most likely delete candidate (`LSPServerProcess` subprocess transport) already shipped a deletion (commit `813c15dd`, 2026-05-05 per CLAUDE.md) — `F-LSP-SubprocessTransportGone` grep gate flagged in iter-27 ensures it doesn't drift back.

### §14.2 HIDE candidates (`hidden-dead` or `hidden-working` sub-properties — surface, don't delete)

- **[[PipelineState]]** `currentError` (iter-6): read by zero non-test files. Two options: (a) wire into a `ChatView` error banner; (b) delete the property + `setError(_:)`. Either is a one-PR fix. Current state is the exact drift this ledger guards against.
- **Provenance Console projection** ([[agent_core::provenance]]): the Swift `ProvenanceConsoleProjectionService` exists and projects ledger snapshots, but it's not clear which Settings sub-view actually instantiates the Provenance Console for the user. Likely `hidden-working` until W-25 wires the ACS-anchor column visibly.

### §14.3 MERGE candidates

- **Diagnostics rows** (12 HealthRow files): per W-29 these should consolidate into one "Substrate Health" Settings panel. Today they are 12 islands. T22 owns the merge; T09 just surfaces the need.
- **Vault retrieval surfaces** (3 distinct codebases): Swift `VaultSyncService.searchIndex` / Swift `SearchIndexService.search` / Rust `vault.rs::hybrid_search` — three retrieval entry points, three score scales, three different "first 7 notes" failure modes. T21 owns the contract that unifies them.

### §14.4 KEEP (currently classified `current-wired` or `visible-working` and on the spine)

This is the load-bearing list: every row that, if removed, would break user-visible value or block a downstream merge.

- [[AppBootstrap]], [[AppEnvironment]], [[EpistemosApp]] — composition spine.
- [[ChatState]], [[UIState]], [[PipelineState]] — chat presentation spine.
- [[ChatCoordinator]] — chat-turn orchestrator (visible-broken downstream of vault.rs, but the seam itself is canonical).
- [[VaultSyncService]], [[SearchIndexService]] — vault read paths.
- [[MLXInferenceService]], [[TriageService]], [[LocalAgentLoop]] — inference + routing + local-agent spine.
- [[agent_loop.rs]], [[agent_runtime]], [[bridge.rs]], [[StreamingDelegate]] — agent core + FFI surface.
- [[cognitive_dag schema]], [[cognitive_dag::dispatch]], [[cognitive_dag::macaroons]] — typed-event substrate.
- [[agent_core::provenance]] — ClaimLedger + ReplayBundle.
- [[scope_rex::answer_packet]] — V6.2 AnswerPacket emission.
- [[Halo (Swift)]], [[epistemos-shadow]] — contextual shadows surface.
- [[Epdoc]] — Tiptap editor chrome.
- [[Omega::MCPBridge + omega-mcp]] — tool dispatch (core).

### §14.5 BUILD-NEXT (top P0/P1 falsifier-driven work that flips current rows to verified)

Ordered by leverage:

1. **`F-VaultRecall-50`** (T21 in-flight; W-19 / W-20 / W-22 / W-23 — vault.rs Fix-C drop + ChatCoordinator Vault Context Contract + Brain Panel surface). Flips [[ChatCoordinator]] from `visible-broken` to `visible-working` and unblocks every retrieval-dependent feature.
2. **`F-AppEnv-Drift`** (proposed in iter-2/3 — Mirror-based test asserting every AppBootstrap @Observable property is in `withAppEnvironment`). Cheap, single-PR; guards a known bug class (AGENTS.md "Environment Sync Drift").
3. **W-12** — per-model HONEST / EXPERIMENTAL / OFF badges in model picker. Flips [[LocalAgentLoop]] capability-honesty from doctrine to UI-visible.
4. **W-14** — AnswerPacket per-message persistence assertion test. Flips [[scope_rex::answer_packet]]'s W-14 from PARTIAL to DONE.
5. **W-46** (from this ledger iter-22) — update CLAUDE.md FILE MAP to reflect macaroons-in-dispatch wiring. Doc-only honesty fix.
6. **`F-MLX-FirstTokenLatency-M2Pro`** — calibrated p95 budget test. Without this the local-inference idle-unload heuristics are unfalsifiable.
7. **`F-Streaming-AsyncStreamBuffering`** — grep gate for `.bufferingNewest(256)` on AsyncStream construction (CLAUDE.md "DO NOT" rule).
8. **W-29 Substrate Health Panel** — consolidate 12 HealthRow islands. T22 owner.

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
| 2026-05-18 | iter-11 | Classified `MLXInferenceService` (actor) as `visible-working` / `MAS`; named `F-MLX-FirstTokenLatency-M2Pro`. | T09 loop |
| 2026-05-18 | iter-12 | Classified `TriageService` as `visible-working` / `MAS`; named `F-Triage-OperationTierParity`. | T09 loop |
| 2026-05-18 | iter-13 | Classified `LocalAgentLoop` (actor) as `visible-working` / `MAS`; flagged W-12 + fake-capability guard gap. | T09 loop |
| 2026-05-18 | iter-14 | Classified Rust `agent_core::agent_loop` as `current-wired` / `MAS`; named F-AgentLoop-ThinkingBlocksPassthrough + F-AgentLoop-CancelLatency. | T09 loop |
| 2026-05-18 | iter-15 | Classified Rust `agent_core::agent_runtime` (ex-hermes/) as `current-wired` / `MAS`; flagged skills.rs as 25-line consolidation boundary still mid-migration. | T09 loop |
| 2026-05-18 | iter-16 | Classified Rust `agent_core::bridge` (3535-line FFI surface) as `current-wired` / `Infrastructure`; named F-FFI-SymbolDrift. | T09 loop |
| 2026-05-18 | iter-17 | Classified `StreamingDelegate` (Swift, line 515) as `current-wired` / `MAS+Infrastructure`; flagged AsyncStream-buffering CLAUDE.md rule that may be silently violated at construction site. | T09 loop |
| 2026-05-18 | iter-18 | Classified `cognitive_dag` schema (`node`+`edge`+`storage`+`merkle`+`redb_store`) as `current-wired` / `MAS`; 102+103 NodeKind/EdgeKind callers verified. | T09 loop |
| 2026-05-18 | iter-19 | Classified `cognitive_dag::dispatch` as `current-wired` / `MAS`; verified 5 production hooks at `provenance/ledger.rs:516,581`, `skill_router.rs:59`, `agent_runtime/procedural_memory.rs:93`, `bridge.rs:3206`. | T09 loop |
| 2026-05-18 | iter-20 | Classified `cognitive_dag::macaroons` as `current-wired` (CORRECTION — CLAUDE.md FILE MAP stale; macaroons no longer "orphan until Phase 8.H" — dispatch.rs:28 imports them and tests at dispatch.rs:472-505 prove sign-every-edge wiring). | T09 loop |
| 2026-05-18 | iter-21 | Classified `agent_core::provenance` (ClaimLedger + ReplayBundle) as `current-wired` (Rust) / `visible-working` (Swift Provenance Console projection); auto-fires dispatch on commit at `ledger.rs:516,581`. | T09 loop |
| 2026-05-18 | iter-22 | Appended `W-46` to `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` §12B requesting `CLAUDE.md` macaroons-orphan claim correction. | T09 loop |
| 2026-05-18 | iter-23 | Classified `scope_rex::answer_packet` (579 lines) as `current-wired` (substrate) / `visible-broken` (Brain Panel surface) / `MAS`; cross-linked W-14/27, T10, T22B. | T09 loop |
| 2026-05-18 | iter-24 | Classified `scope_rex::{kernels, kv, metal, retrieval}` (1880 lines combined) as `Research` lane (`implemented-not-wired` / `feature-gated` / `scaffold-only` mix); pinned lane-discipline boundary so they cannot drift into MAS without F-* passes. | T09 loop |
| 2026-05-18 | iter-25 | Classified Halo (Swift: HaloController + ShadowSearchService + UI) as `visible-working` / `MAS`; flagged inheritance of upstream vault-recall failure. | T09 loop |
| 2026-05-18 | iter-26 | Classified `epistemos-shadow` Rust crate (3651 lines: Tantivy + usearch + RRF k=60) as `current-wired` / `MAS`; 10 FFI exports + cdylib drift surface. | T09 loop |
| 2026-05-18 | iter-27 | Classified `agent_core::lsp_runtime` (1161 lines, in-process LSP V2.3, subprocess transport deleted 2026-05-05) as `feature-gated` / `Pro`; cfg-feature-gated at bridge.rs:3120/3158/3178. | T09 loop |
| 2026-05-18 | iter-28 | Classified `Omega::MCPBridge` (Swift, 502 lines) + `omega-mcp` Rust crate (10537 lines, 17+ pub fn uniffi exports) as `current-wired` / `MAS` (core) + `feature-gated` / `Pro` (github/web_search/PTY). | T09 loop |
| 2026-05-18 | iter-29 | Classified Epdoc (EpdocDocument 648 + EpdocEditorChromeView 928 + EpdocEditorToolbar 366 + EpdocPasteClassifier 210 + EpdocBlockTemplateStore 139 + js-editor Tiptap bundle) as `visible-working` / `MAS`; flagged `F-Epdoc-NoRuntimeNpm` + `F-Epdoc-BundleHealthRowWired`. | T09 loop |
| 2026-05-18 | iter-30 | Cleaned 3 duplicate empty section placeholders (`§5 Agent`, `§9 Notes/Editor/Epdoc`, `§10 LSP+KF`) — `minimum correction only` per cadence step 8. | T09 loop |
| 2026-05-18 | iter-31 | Classified KnowledgeFusion (10338 lines total: Alignment/KTOTrainer + TrainingScheduler + FeedbackLogger + CSISafeguard + SyntheticData/* + CloudKnowledgeDistillationService) as `visible-working` / `Pro` (lazy-init); 3 falsifiers named (CloudGatedByUserConsent, KTOTrainer-NotOnMainActor, CSISafeguard-PreWritePath). | T09 loop |
| 2026-05-18 | iter-32 | Classified §12 Settings UI Diagnostics rows (12 HealthRow files + 3763-line SettingsView root + 15 detail views) as `visible-working` per-row / `not-implemented` for the W-29 unified Substrate Health panel. | T09 loop |
| 2026-05-18 | iter-33 | Populated §14 Delete / Hide / Merge / Keep / Build-next lists — acceptance bar floor reached. | T09 loop |
| 2026-05-18 | iter-34 | Classified §11 Graph (Swift 5438 + Metal view 2936 + graph-engine Rust 102270) as `visible-working` / `MAS`; 3 falsifiers named (pending-queue-bounded, no-repeat-forever, ECS-step-budget M2 Pro). | T09 loop |
| 2026-05-18 | iter-35 | Classified §13 Research-only modules consolidated row covering 10 subdirs + 18 top-level files in `agent_core/src/research/`; pinned T5-frozen paths; cross-linked T7/T17B/T18B/T23B per-falsifier ownership. | T09 loop |
| 2026-05-18 | iter-36 | Deep-hardening cleanup: removed duplicate §12 header introduced by iter-34 Graph row insert. | T09 loop |
| 2026-05-18 | iter-37 | Classified §9a native ProseEditor stack (7541 lines: ProseEditorView 551 + ProseEditorRepresentable2 1595 + ProseTextView2 2517 + MarkdownContentStorage 1219 + NoteWindowManager 711 + NoteChatState 948) as `visible-working` MAS; surfaced AGENTS.md's 4 documented anti-patterns as 4 named falsifiers (Binding Cascade, Zone Protection Gap, Multi-Turn Header, Dirty Flag Persistence). | T09 loop |
| 2026-05-18 | iter-38 | Classified §10c `agent_core::security::harden_cli_subprocess` (3 variants at lines 937/949/976; 10 spawn-site callers verified per CLAUDE.md) as `current-wired` / `Infrastructure`; flagged F-Security-SubprocessHardeningGate as the missing CI lint asserting new `Command::new` sites invoke hardening. | T09 loop |
