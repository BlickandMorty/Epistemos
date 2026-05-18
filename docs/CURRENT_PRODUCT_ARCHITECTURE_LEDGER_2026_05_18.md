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


## §5. Agent system

(rows will land here — `agent_core/src/agent_loop.rs`, `agent_core/src/agent_runtime/`, `agent_core/src/bridge.rs`, `StreamingDelegate`, `AgentViewModel`, `AgentBlueprint`, AgentRunTimeline, `Omega/MCPBridge`, etc.)

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
