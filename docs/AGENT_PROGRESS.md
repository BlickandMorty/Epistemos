# Agent System Implementation Progress

Last updated: 2026-04-19 | Chat transparency sprint (Batches A-J) landed on `codex/runtime-input-audit` — routing UX, Codex cloud-quality fix, agent thinking-delta wiring, empty-stream guard, QwQ-32B flagship reasoner, effective-model badge (data + UI).

Canonical release-hardening plan:
- `docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md` is the authoritative release-focused plan that reconciles later research, blocker handoffs, and verification requirements.

## 2026-04-19 Reasoning Trace Continuation ✅
- [x] `3c17ac95` — note chat now persists `thinkingTrace` / `thinkingDurationSeconds` through its SwiftData round-trip; reloading a note no longer drops the assistant's collapsible thought trail
- [x] Verification: focused `xcodebuild ... -only-testing:EpistemosTests/NoteChatStateTests` passed on the warmed `/tmp/epistemos-mlx-load-stall` path
- [x] `79e70e52` — graph chat (`NodeInspectorState` + `HologramSearchSidebar`) now captures `reasoningSink` deltas, shows a live/persisted `ThinkingTrailView`, and stamps the final thought trace onto the assistant transcript instead of keeping reasoning invisible
- [x] Verification: the new `RuntimeValidationTests.graphChatPreservesReasoningTracesSeparately()` source guard passed; the broader `RuntimeValidationTests` suite still has one unrelated pre-existing failure (`bootstrapThrottlesRefreshAndRuntimeSerializesTurns()`)
- [ ] Remaining user-visible transcript surfaces to audit next: `PinnedInspector` node chat, `CodeEditorView` code-explain/ask flows, then lower-priority `DialogueChatState` persistence

## 2026-04-20 Handoff Correction ⚠️
- Later manual testing contradicted several earlier "fixed" claims.
- Do not treat Fast-mode local thinking, app-crash, Qwen Coder freeze, "thinks forever, never answers," or thinking-in-main-bubble as fully closed without fresh live verification.
- Authoritative correction notes now live in:
  - `docs/handoffs/2026-04-20-claude-to-codex-session-handoff.md` §9
  - `docs/architecture/MASTER_PLAN_2026-04-19.md` §20
- External April 19 context docs added a stricter ship contract: scope the dirty tree, declare the exact batch and files first, `xcodegen` after new Swift files, refresh `DerivedData`, build the actual `Epistemos` scheme, launch the app, and verify the fix visually before calling it shipped. See `MASTER_PLAN_2026-04-19.md` §21.
- Immediate verification priorities:
  - Fast mode must not auto-route to always-thinking families like DeepSeek / GGUF Qwopus
  - GPT-5.4 and DeepSeek reasoning must stay in the thinking UI on both direct-cloud and Rust-agent paths
  - attached-note / attached-essay flow must not emit fake `read_file` JSON or ask for file paths when content is already resolved

## 2026-04-19 Continuation ✅
- [x] `d29984e6` — Fast mode now excludes always-thinking local families from automatic routing/fallback and explicitly disables thinking on smaller Qwen 3.5 variants
- [x] `daa05e65` — non-stream OpenAI-compatible responses no longer treat `reasoning_content` as answer text; Fast no longer falls back to always-thinking-only local installs; `qwen25Coder7B` participates in the thinking-loop guard
- [x] `366d659a` — Rust Codex/OpenAI agent requests now send `tool_choice: "auto"` and `parallel_tool_calls: true`, matching the upstream Codex Responses contract more closely
- [x] `151abe31` — main chat now shows `Loading <model>…` before the first token so slow local loads stop looking like a dead freeze
- [x] Verification:
  - `TriageServiceTests` focused run passed after the Fast/runtime-guard batch
  - `CloudStreamingParserTests` + `TriageServiceTests` focused run passed (37 tests / 2 suites)
  - `cargo test --manifest-path agent_core/Cargo.toml --lib` passed (512/512)
  - `ChatPresentationTests` still contains one unrelated pre-existing source-guard failure (`tool preview cards start collapsed`), but the new loading-state source guard itself passed in the broader run

## 2026-04-19 Chat Transparency + QwQ-32B ✅
- [x] Batch A `254312cd` — chat routing UX: explicit stack popover, settings ↔ picker sync, Codex GPT-5.4 preservation on fast mode (no silent Mini downgrade)
- [x] Batch B `18664605` — Codex ChatGPT backend stops receiving GPT-5 native reasoning/verbosity controls (root cause of typo-heavy prose on that path) + "use polished grammar" baseline nudge
- [x] Batch C `06cc013e` — agent path now routes `.thinkingDelta` into `AgentChatState.appendStreamingThinking` with full lifecycle state (popover, resetOnStreamStart / newSession)
- [x] Batch D `9cf31cf7` — `ChatState` + `AgentChatState` `completeProcessing` surface empty streams as actionable errors instead of ghost assistant bubbles
- [x] Plan doc `eb5a0edb` — CHAT_TRANSPARENCY_PLAN_2026-04-19.md with P1/P2/P3 research-backed backlog
- [x] Batch G `526b7279` — mirror the agent-side thinking lifecycle tests onto `ChatState` so the main chat path has explicit regression coverage
- [x] Batch H `98897428` — QwQ 32B flagship on-device reasoner added to the catalog, leads `.thinking` preferredOrder ahead of DeepSeek R1 7B on 24GB+ Macs
- [x] Batch I `5ddd6db9` — every assistant turn captures `resolvedModelLabel` at completion via new `InferenceState.effectiveModelLabel(for:)` helper; all four completion call sites plumbed
- [x] Batch J `cfad9a99` — `EffectiveModelBadge` renders a small sparkle-pill under each assistant reply showing the actual model that answered (the Perplexity #1 research pattern: transparent routing)
- [x] Verification: 7-suite sanity sweep (`AgentChatStateTests`, `ChatPresentationTests`, `CloudProviderAuthServiceTests`, `LocalModelInfrastructureTests`, `PipelineServiceTests`, `RuntimeValidationTests`, `TriageServiceTests`) all green

**Open:** OpenThinker3-7B catalog entry (needs Python MLX conversion step we can't run autonomously — wait for a community `mlx-community/OpenThinker3-7B-*-mlx` upload or run the conversion manually). Gemma 4 loader port (multi-file Swift MLX work in `LocalPackages/mlx-swift-lm/` — too big for autonomous landing, tracked in MASTER_MODEL_STACK_PLAN.md §3.a).

**Next-session P1 continuation:** typed error surfaces (401/429/content-policy/tool-failure), context side panel (NotebookLM + Continue.dev hybrid), and click-through routing rationale ("why this model?") on the new model badge — all specified in CHAT_TRANSPARENCY_PLAN_2026-04-19.md.

## 2026-04-15 PLAN_V2 Research Integration + Sessions 0-6 ✅
- [x] Committed Phase 7 Step 9: Graph Chat receiver wired end-to-end through ACC and Rust compile path (GraphState → ACC → ChatCoordinator → Rust GraphContext passthrough)
- [x] Integrated §23-§27 into PLAN_V2.md from 5-model research synthesis: Code Editor Architecture Truth, Agent Streaming Data Plane, Graph Zero-Copy Rendering, Implementation Sessions, Anti-Pattern Register
- [x] Fixed P1 beach ball: recompute_semantic_neighbors off main thread via Mutex + Task.detached
- [x] Fixed P0 Vec drop malloc: allocator mismatch in graph_engine_free_prepared_retrieval_candidates replaced with into_boxed_slice/Box::from_raw pattern
- [x] Fixed P2 pinned inspector freeze: force_alive engine flag bypasses idle skip when pinned panels exist
- [x] Session 0: Editor doc-truth audit — reconciled CODE_EDITOR_FEATURE_AUDIT.md with live code (3 verified, 4 partial, 1 reverted)
- [x] Session 1: Benchmark harness — os_signpost instrumentation on graph/streaming FFI + criterion benches in graph-engine + BENCHMARK_BASELINES.csv
- [x] Session 2: Swift 6 concurrency hardening — 6 force unwraps removed, isFinite guard added, no try! violations found
- [x] Session 3: Graph BoltFFI typed buffer prototype — bolt_bridge.rs with BoltNodeRecord/BoltEdgeRecord/BoltPositionRecord behind bolt-graph feature flag, 10 tests
- [x] Session 5: syntax-core crate scaffolding — tree-sitter + ropey, 7 #[repr(C)] FFI types, rope bridge, token registry, generation counter, 21 tests, criterion benchmarks
- [x] Session 6: Agent streaming instrumentation — signposts on StreamingDelegate + ChatCoordinator event path
- [x] Final audit: 2978 Rust tests (2456 graph-engine + 501 agent_core + 21 syntax-core), Swift BUILD SUCCEEDED, 331 critical tests in 15 suites all pass

## 2026-04-03 Main Chat Markdown Tightening ✅
- [x] `TaggedMarkdownTextView` now groups consecutive list items into a single render run so main chat and mini chat no longer space bullets like separate paragraphs
- [x] Chat markdown parsing now preserves nested list indentation, task-list items, and nested blockquote depth for the shared chat renderer
- [x] Main chat and mini chat both pick up the change automatically because `MessageBubble` and `MiniChatView` already share `TaggedMarkdownTextView`
- [x] Added focused `ChatPresentationTests` coverage for nested/task-list parsing and grouped list-run rendering
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-chat-format-dd test -only-testing:EpistemosTests/ChatPresentationTests`

## 2026-04-03 Inference Post-Query Memory Release Audit ✅
- [x] `DisplayPacedTextBuffer.reset(...)` now supports an explicit release-capacity path so oversized buffered assistant text does not keep its backing storage after the turn ends
- [x] `ChatState` now drops retained `streamingText` / pending-buffer capacity on new chat, completion, cancellation, error, and clear paths instead of only resetting content length
- [x] `NoteChatState` now releases retained inline-response / stream-buffer capacity on submission reset, accept, discard, and clear paths so large note-chat turns do not linger in idle heap state
- [x] Added a focused `NoteChatStateTests` regression plus a `RuntimeValidationTests` source guard covering the release-capacity reset wiring
- [x] Focused verification passed: `cargo test --manifest-path graph-engine/Cargo.toml`
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-idle-memory-dd test -only-testing:EpistemosTests/NoteChatStateTests -only-testing:EpistemosTests/PipelineServiceTests/ChatStateLocalMessageTests/startNewChatClearsPendingAttachmentsAndContext -only-testing:EpistemosTests/PipelineServiceTests/ChatStateLocalMessageTests/clearMessagesDropsPendingAttachmentsAndContext -only-testing:EpistemosTests/RuntimeValidationTests`
- [x] Recursive focused audit reached 3 successive clean no-edit passes for the post-query memory slice

## 2026-04-03 Graph Overlay Idle Memory Fix ✅
- [x] `HologramOverlay.hide()` now keeps the fast reopen path only for a bounded 10-second window, then tears down the hidden Metal graph window instead of retaining GPU resources indefinitely at idle
- [x] `HologramOverlay` now cancels any pending hidden teardown when the overlay is shown again, force-closed, or re-entered in mini mode, so the retention policy does not race normal graph lifecycle transitions
- [x] `HologramOverlay.showMini()` now tears down any previously soft-hidden full overlay before cold-starting mini mode, preventing a second hidden Metal graph instance from lingering in memory
- [x] Added `GraphOverlayRetentionPolicyTests` plus a `RuntimeValidationTests` source guard so the scheduled hidden teardown behavior remains enforced
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' test -only-testing:EpistemosTests/GraphOverlayRetentionPolicyTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`

## 2026-04-03 Runtime Idle Memory Trims ✅
- [x] `LocalMLXRuntimeTuning` now produces a separate `idleMemoryPolicy`, and `MLXInferenceService` switches between full request budgets and a much smaller idle budget so cached Metal pages are trimmed immediately after each local turn instead of staying at inference-size while idle
- [x] `MLXInferenceService` now starts cold in the smaller idle budget, reapplies the active budget before warm reuse, and returns to the idle budget on unload/runtime-condition updates
- [x] `NotesSidebar` search caches now use a bounded query-retention policy (`maxCachedQueries = 12`) for both title and body results, preventing long sessions from accumulating unbounded cached search payloads
- [x] Added runtime guards for the MLX idle-budget path and the bounded sidebar cache retention
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-idle-memory-dd test -only-testing:EpistemosTests/TriageServiceTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`

## 2026-04-03 Instant Recall Wake Freeze Fix ✅
- [x] `InstantRecallService` now shares a reusable rebuild helper and exposes `rebuildIndexAsync(...)`, which runs the Rust clear-and-reinsert pass inside `Task.detached(priority: .utility)` instead of holding `MainActor` for the full vault snapshot rebuild
- [x] `VaultSyncService.rebuildInstantRecallIndex(...)` now resolves the service on `MainActor` and awaits the async rebuild path, so post-wake/file-watcher vault reimports no longer force the heavy Instant Recall rebuild loop through `MainActor.run`
- [x] Added a behavior regression in `InstantRecallTests` for async stale-document replacement plus a `RuntimeValidationTests` source guard that keeps the vault watcher on the off-main rebuild path
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' test -only-testing:EpistemosTests/InstantRecallServiceTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`
- [x] Follow-on subsystem verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' test -only-testing:EpistemosTests/VaultSyncServiceAuditTests -quiet`

## 2026-04-03 Phase A Provider Selection Slice ✅
- [x] `InferenceState` now tracks an explicit `activeAIProvider`, remembers the last selected cloud model per provider, and falls back to local Qwen when the user switches to `Local Only`
- [x] Runtime model pickers now expose a dedicated `AI Provider` section and scope the `Cloud Models` list to the active provider instead of showing every cloud catalog at once
- [x] Inference Settings now expose the same provider selector so provider choice and credential setup stay aligned across toolbar + settings surfaces
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-active-provider-dd test -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/InferenceCloudSelectionTests -quiet`

## 2026-04-02 Recursive Runtime Audit ✅
- [x] Fresh macOS app build passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
- [x] Current Rust sweeps passed: `agent_core` 144 passed, `graph-engine` 2451 passed / 8 ignored, `omega-mcp` 126 passed, `omega-ax` 12 passed
- [x] `omega-mcp/src/pty.rs` now ignores echoed `__EPPWD__$(pwd)` command text and waits for the expanded marker line before updating `working_dir`
- [x] Added a PTY regression test covering echoed working-directory markers, and `omega-mcp` stays fully green after the fix
- [x] Hardening verification docs now reflect the live Hermes posture: Hermes remains an intentional managed subprocess boundary, not an unwired orphan-cleanup gap
- [x] `CloudKnowledgeDistillationService` now fast-paths inline-only note bodies, and XCTest hosts skip `MainThreadWatchdog.install()`, so the 10,025-note distillation stress suite no longer emits false hang diagnostics
- [x] `CloudKnowledgeDistillationService` now propagates source-note and recent-chat load failures instead of silently compiling empty model vaults
- [x] `HermesSubprocessManager` now supports dynamic stdout handler updates plus disconnect callbacks, and pending `HermesMCPClient` requests fail immediately when Hermes exits
- [x] `HermesSubprocessManager` now preserves the final stderr line from fast subprocess crashes, so diagnostics survive quick Hermes exits
- [x] `HermesSubprocessManager` now keeps relaunches blocked until graceful shutdown actually finishes, and `restart()` waits for the old subprocess to exit before relaunching
- [x] `HermesSubprocessManager` watchdog now waits for an actual ping response, so hung Hermes subprocesses terminate instead of looking healthy just because stdin is still writable
- [x] `HermesSubprocessManager.healthCheck(...)` now requires a live bridge ping before reporting Hermes healthy, so setup/repair flows no longer trust import-only success
- [x] `NightBrainService` now defers runs when `SearchIndexService` or `AgentGraphMemory` are unavailable instead of checkpointing those jobs as fake successes
- [x] `NightBrainService` now retains its initial `EventStore` for the full run, so checkpoint/completion durability cannot disappear mid-pipeline if the provider goes nil later
- [x] `AgentHeartbeatService` now monitors Hermes through a bounded post-dispatch window and defers the run if the subprocess drops before that window completes
- [x] `OrphanSubprocessCleanup` now snapshots descendant subprocess trees with `proc_listchildpids` and kills the full tree instead of only the tracked parent PID
- [x] `HermesSubprocessManager` now uses descendant-tree cleanup from the normal `terminate()` path when orphan cleanup is available, and the old fake `terminateProcessGroup()` API is gone
- [x] `NightBrainService` now routes checkpoint vacuum, artifact dedupe, and workspace snapshot compaction through the run's captured `EventStore`, and cloud knowledge distillation now defers if no distillation job is wired
- [x] `ActivityTracker` crash-recovery is now actually wired into launch/teardown, so flushed activity events are recovered at startup and durably cached on orderly shutdown
- [x] `ActivityTracker` now logs flush-directory failures explicitly, merges recovered cache contents with any already-recorded in-memory events, and no longer swallows idle-loop cancellation or page-title fetch failures with `try?`
- [x] `WorkspaceSummaryService` now fails loudly on summary-loop sleep interruption plus workspace fetch/save/page-title fetch failures instead of silently swallowing them with `try?`
- [x] `WorkspaceService` now fails loudly on auto-save, auto-restore, restore-delay, diff, save/load, and list persistence failures instead of silently swallowing them with `try?`
- [x] `TimeMachineService` now logs and fail-closes note/chat/page/graph fetch failures through shared helpers instead of silent empty or zero fallbacks
- [x] `EventStore` now fails closed on database-directory creation, logs `jobs_completed` JSON encode/decode failures, logs event payload encode failures, and closes SQLite on `quick_check` prepare failure
- [x] `EpistemosConfig` now fails closed on malformed capture allowlist/blocklist JSON and logs explicit capture-filter decode/encode failures instead of silently treating bad JSON as empty arrays
- [x] `AppBootstrap` now logs startup integrity, welcome-back summary, deferred startup delay, database reset cleanup, and Instant Recall seed snapshot failures instead of swallowing them with `try?`
- [x] `ModelProfileManager` now logs model-profile save failures instead of silently ignoring `context.save()`
- [x] `UIState` now logs malformed landing-greeting decode/encode failures, sanitizes corrupted greeting defaults back to an empty valid library, logs toast-dismissal timer failures, and `LandingGreetingResolver` now logs note-insight fetch failures instead of silently skipping them
- [x] Focused verification passed: `CloudKnowledgeDistillationTests` (8), `HermesMCPClientTests` (11), combined Cloud Knowledge + Hermes rerun (19 tests / 2 suites), NightBrain + Hermes + validation rerun (137 tests / 3 suites), `RuntimeValidationTests` (117), and `omega-mcp` cargo tests (126)
- [x] Follow-on focused verification passed: `NightBrainCheckpointResumeTests` + `OrphanSubprocessCleanupTests` + `RuntimeValidationTests` (130 tests) and `HermesMCPClientTests` (11)
- [x] Focused Hermes setup verification passed: `HermesHealthResult` suite rerun
- [x] Warm Xcode reruns now passed for `AgentHeartbeatTests` and the broader Hermes/NightBrain/runtime-validation slice
- [x] Focused tracker/runtime-validation verification passed twice: `ActivityTrackerTests` + `RuntimeValidationTests`
- [x] Focused persistence verification passed: `WorkspaceServicePersistenceTests` + `TimeMachineServiceTests` + `RuntimeValidationTests` (141 tests / 3 suites), `RuntimeValidationTests` rerun (131 tests), and `EventStoreSchemaTests` (7)
- [x] Follow-on focused verification passed: `xcodebuild ... build -quiet` and `xcodebuild ... test -only-testing:EpistemosTests/EpistemosConfigTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`
- [x] Follow-on focused verification passed: `xcodebuild ... test -only-testing:EpistemosTests/EpistemosConfigTests -only-testing:EpistemosTests/LandingExperienceSettingsTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`
- [x] Cloud Knowledge model vaults are now injected into live cloud, Apple Intelligence, and Hermes session-start prompts via `KnowledgeProfileStore.augmentedSystemPrompt(...)`
- [x] `AppleIntelligenceService` now caches Foundation Models sessions by the effective normalized system prompt and reapplies injected prompt context after context-window recycling
- [x] Focused Cloud Knowledge runtime wiring verification passed: isolated rerun of `CloudKnowledgeDistillationTests` + `AgentHeartbeatTests` + `RuntimeValidationTests` (150 tests / 3 suites)
- [x] `AgentHeartbeatService` no longer spins after cancellation in its post-dispatch monitoring loop, and `AppSupervisor` no longer swallows detached sleep cancellation in health-check/restart paths
- [x] Focused supervisor/heartbeat verification passed three consecutive times on an isolated DerivedData path: `AgentHeartbeatTests` + `SupervisorTests` + `RuntimeValidationTests`
- [x] `AmbientCaptureService` no longer swallows debounce cancellation, now logs malformed AX-tree payload failures, and no longer silently drops secret-redaction regex compilation failures
- [x] Focused ambient-capture verification passed three consecutive times on an isolated DerivedData path: `AmbientCaptureTests` + `RuntimeValidationTests`
- [x] `ProseEditorView` now logs save/fetch failures on live note persistence paths, schedules note-body writes before flush-page fetches, and avoids creating dangling wikilink duplicates after hidden fetch failures
- [x] `NoteChatState`, `DiskStyleCache`, and `AgentViewModel` now fail loudly on persisted history/cache/session-state load-write corruption instead of silently swallowing those note/agent persistence failures
- [x] Focused persistence hardening verification passed on an isolated DerivedData path: `NoteChatStateTests` + `NoteEditorLayoutTests` + `RuntimeValidationTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `StartupAutoDiscovery` now logs config-read, `.hermes` creation, model-cache inspection, and fallback `SearchIndexService` bootstrap failures instead of silently degrading startup discovery
- [x] `NoteInsightService`, `NotesSidebar`, `HologramNodeInspector`, `TimeMachineView`, and `DialogueChatState` now fail loudly on the remaining live fetch/save/debounce/restore seams from this audit slice instead of hiding them behind `try?`
- [x] Focused startup/runtime hardening verification passed on the warmed DerivedData path: `HermesSubprocessTests` + `NoteChatStateTests` + `RuntimeValidationTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `VaultIndexActor` now uses explicit fetch/save/file-I/O helpers for live indexing, manifest, spotlight, and migration paths instead of silently collapsing SwiftData and file-system failures behind `try?`
- [x] `LandingView` now logs welcome-back presentation/search-focus scheduling failures, welcome-back summary note save failures, and recent-chat fetch failures, and it cancels the deferred welcome-back presentation intentionally on dismiss/disappear
- [x] Focused vault/landing hardening verification passed on the warmed DerivedData path: `VaultIndexActorTests` + `RuntimeValidationTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `VaultSyncService` now routes live health-snapshot fetches, SQLite signature probes, dirty-page fetches, version-capture fetch/counts, move-page lookup, and maintenance timer sleeps through explicit helpers instead of silent `try?` fallbacks
- [x] `ChatCoordinator`, `MiniChatView`, `MiniChatWindowController`, `QueryRuntime`, `VaultChatMutator`, and `VaultRegistry` now log live fetch/search/read failures explicitly instead of silently collapsing those chat/runtime seams
- [x] `ExecutionCheckpointManager` and `NotesAgent` now log checkpoint directory/decode/remove failures plus note-agent argument-parse, fetch, and save failures instead of swallowing them behind `try?`
- [x] Focused chat/vault/Omega hardening verification passed on the warmed DerivedData path: `RuntimeValidationTests` + `VaultSyncServiceAuditTests` + `MiniChatViewAuditTests` + `QueryRuntimeTests` + `VaultChatMutatorTests` + `OmegaAgentTests` + `PipelineServiceTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `SessionIntelligenceOverlay` now uses bounded `fetchLimit = 1` title lookups for note/chat command actions instead of full-page/full-chat vault scans on the interactive landing overlay path
- [x] Focused performance guard verification passed on the warmed DerivedData path: `NonAgentPruningValidationTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `AgentViewModel` now shares one explicit computer-action mutation enrichment helper across click/type/keys/scroll actions instead of duplicating 300 ms AX sampling logic in each tool path
- [x] `ProgressStore` now enumerates only real session directories through shared helpers, logs directory/decode failures explicitly, and ignores stray files when listing sessions
- [x] `HarnessRegistry` and `HarnessLab` now reuse shared nonisolated ISO-8601 timestamp helpers instead of recreating formatters across candidate/proposal/evaluation/materialization paths
- [x] Recursive perf verification passed after one refinement-loop fix to `HarnessLabTime` isolation: `ProgressStoreTests`, then `HarnessSubsystemTests` + `RuntimeValidationTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs on the isolated DerivedData path
- [x] `SessionIntelligenceOverlay` now resolves “open it” note-history lookups through extracted candidate titles plus open-note checks and bounded fetches instead of scanning every `SDPage` row in command history fallback paths
- [x] `LiquidGreeting` now uses shared deterministic timing helpers and an explicit pause helper instead of per-character `Int.random(...)` sleeps across the landing typewriter loop
- [x] Added focused landing optimization coverage in `LandingOptimizationTests`, plus source guards in `NonAgentPruningValidationTests` and `ThemePairTests`
- [x] Recursive landing perf verification passed after one refinement-loop fix to `SessionIntelligenceNoteLookup` isolation: `LandingOptimizationTests` + `NonAgentPruningValidationTests` + `ThemePairTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs on the isolated DerivedData path
- [x] `LocalModelManager.refreshFromDisk()` now persists the local model manifest only when legacy/missing-install cleanup actually changed `installRecords`, instead of rewriting the manifest on no-op refreshes
- [x] `pruneMissingInstalls()` and `purgeLegacyNonQwenInstalls()` now report whether they changed the record set so refresh cleanup persists at most once per pass
- [x] Added a real `LocalModelInfrastructureTests` manifest-modification-date regression plus a `RuntimeValidationTests` guard for the conditional-persist structure
- [x] Recursive local-model perf verification passed on an isolated DerivedData path: `LocalModelInfrastructureTests` + `RuntimeValidationTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs
- [x] `SessionIntelligenceOverlay.summarizeChats()` now orders grouped chats deterministically and batch-loads chat titles for the selected groups instead of fetching one `SDChat` row per summary entry
- [x] Added a real `LandingOptimizationTests` chat-summary ordering regression plus a `NonAgentPruningValidationTests` guard that keeps the landing overlay from regressing back to per-chat title fetch loops
- [x] Recursive landing chat-summary verification passed after one refinement-loop fix to a source-guard key-path escape: `LandingOptimizationTests` + `NonAgentPruningValidationTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs on the isolated DerivedData path
- [x] `SessionIntelligenceOverlay` now shares explicit note-presentation/dismiss timing helpers plus a bounded auto-save workspace-summary helper instead of repeating raw delayed create/open and fallback fetch paths on the landing command surface
- [x] `WorkspaceSwitcherOverlay` now routes load/dismiss flows through one shared post-dismiss helper instead of repeating 150 ms delayed tasks
- [x] `AgentViewModel` now routes the remaining cron keepalive/admin refresh sleep through an explicit helper and shared interval instead of an inline raw 60-second delay loop
- [x] Final audited non-Hermes perf verification passed on `/tmp/epistemos-codex-final-perf-round`: `LandingOptimizationTests` + `NonAgentPruningValidationTests` + `RuntimeValidationTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs

## 2026-04-02 Cloud Knowledge Distillation Wiring ✅
- [x] `CloudKnowledgeDistillationService` now loads recent chats from SwiftData by default when no provider override is supplied
- [x] Distillation source-note loading no longer silently caps at 10,000 pages
- [x] Untagged domain-map fallback now preserves real concept recency via `RankedConcept.lastUpdatedAt`
- [x] NightBrain treats failed cloud-knowledge or search-index maintenance jobs as interrupted runs instead of falsely checkpointing/completing them
- [x] Focused verification passed: `CloudKnowledgeDistillationTests` + `NightBrainCheckpointResumeTests` = 14 tests in 2 suites, 0 failures

## 2026-04-01 Verification Closure ✅
- [x] Full hosted Swift rerun passed: `test-without-building` completed 3051 tests across 418 suites with 0 failures
- [x] Fresh cached macOS app build passed: `xcodebuild ... build` returned `BUILD SUCCEEDED`
- [x] Fresh Rust sweeps passed: `graph-engine` 2448 passed / 0 failed / 8 ignored, `agent_core` 141 passed / 0 failed, `omega-mcp` 125 passed / 0 failed, `omega-ax` 12 passed / 0 failed
- [x] `agent_core/src/shared_memory.rs` tests now serialize process-global `ShmPool` access and reset the pool before/after each test, eliminating the parallel `shm_pool_cleanup_all` race

## 2026-04-01 Harness + Power Follow-Up ✅
- [x] `AgentViewModel` now prepares harness session state before recording user intent, so the first turn no longer drops the objective from trace/progress capture
- [x] `AgentViewModel` now records final model output and runs `CompletionChecker` at session end
- [x] `VaultSyncService` now observes `PowerGuard` mode changes and restarts maintenance timers when `.full` mode returns
- [x] `DualBrainRouter` now requires a dedicated ANE backend before reporting dual-brain active
- [x] Focused verification passed: `RuntimeValidationTests` + `VaultSyncServiceAuditTests` + `DeviceAgentServiceTests` = 140 tests in 3 suites, 0 failures

## 2026-04-01 Tool Gate Follow-Up ✅
- [x] HermesSubprocessManager now normalizes `HOME` + `PATH`, exports `HERMES_ENV_TYPE=local`, keeps `TERMINAL_ENV=local`, and creates `~/.hermes` before launching Hermes
- [x] `epistemos_bridge.py` now logs the loaded Hermes tool names to stderr after session setup and includes `available_tools` in live session payloads
- [x] `AgentViewModel` now feeds the live Hermes tool list into HarnessIntegration when it is available instead of always sending an empty tool set
- [x] Bridge + Swift session parsing tests added for the loaded-tool payload path

## 2026-04-01 Auto-Discovery Pass ✅
- [x] `AppBootstrap` now runs a startup auto-discovery pass before `InferenceState` initializes, so env/config credentials can seed Keychain without manual setup
- [x] Startup discovery now scans `~/.config/epistemos/config.toml` and `~/.epistemos/config.toml`, creates `~/.hermes` if missing, logs optional browser/web/model availability, and degrades gracefully when pieces are absent
- [x] Hermes tool-gate env export now includes Browserbase credentials so discovered browser config actually reaches the subprocess
- [x] Focused Swift tests cover config parsing, env/keychain precedence, config import, `agent-browser` detection, and model cache discovery

## Sprint Agent-1: The Living Loop ✅
- [x] agent_core crate with all 13 source files
- [x] Full SSE state machine with thinking/signature preservation
- [x] Parallel tool execution (futures::try_join_all)
- [x] Agent-decides termination (stop_reason == end_turn)
- [x] UniFFI bridge with AgentEventDelegate callback interface
- [x] All verification greps pass

## Sprint Agent-2: Local Agent System ✅
- [x] HermesPromptBuilder, LocalToolGrammar, LocalAgentLoop, ConfidenceRouter
- [x] canActAsAgent=false enforced for weak models
- [x] 20/20 focused tests pass

## Sprint Agent-3: MCP + Computer Use ✅
- [x] Rust-authoritative tool catalog (26 tools, 5 agents)
- [x] Vault-focused MCP surface (read/write/list/search)
- [x] AX-first computer-use path hardened
- [x] Device backend execution seam closed
- [x] Focused tests pass

## Sprint Agent-4: Multi-Provider + Polish ✅
- [x] Routed provider preview + honest auto bridge resolution
- [x] Perplexity Sonar streaming provider with citations
- [x] OpenAI-compatible provider (openai.rs — SSE streaming, tool calls, 16 tests) (2026-03-31)
- [x] Full context compaction loop → Sprint Omega-1 Task 3 (compaction.rs)
- [x] Metal thinking glow shader for OmegaPanel → Sprint Omega-4
- [x] Full validation checklist passes (449 Rust tests, Swift BUILD SUCCEEDED) (2026-03-31)

---

## Sprint Omega-1: Foundation Integration ✅ (2026-03-29)
- [x] Task 1: prompt_caching.rs — cache_control breakpoints (~85% cost reduction)
- [x] Task 2: think.rs — zero-cost reasoning tool
- [x] Task 3: compaction.rs — 4-phase context compaction (boundary protect → tool replace → summarize → fold)
- [x] Task 4: security.rs — credential redaction + command risk + output scanning
- [x] Task 5: MCP stdio transport in omega-mcp
- [x] Task 6: Full compilation + test sweep passes (164 Rust tests, 0 failures)

## Sprint Omega-2: Hermes Subprocess Bridge ✅ (2026-03-29)
- [x] HermesSubprocessManager.swift — spawn/manage/kill via Foundation Process
- [x] HermesMCPClient.swift — MCP stdio client to Hermes
- [x] EpistemosMCPServer.swift — MCP stdio server exposing macOS tools
- [x] Pipe-based watchdog heartbeat for zombie prevention
- [x] Process group management for clean shutdown
- [x] Integration with AppBootstrap lifecycle
- [x] Hermes health check on launch

## Sprint Omega-3: AXorcist Computer Use ✅ (2026-03-29)
- [x] Replace raw AXUIElement code with AXorcist SPM dependency
- [x] Ghost OS-style MCP tools (see, click, type, scroll, keys, screenshot)
- [x] ScreenCaptureKit pipeline with buffer dropping (<200ms target)
- [x] TCC permission management UI
- [x] AX-first with vision fallback pattern

## Sprint Omega-4: Skills + Memory + Polish (2026-03-29)
- [x] SKILL.md progressive disclosure (metadata → instructions → resources)
- [x] Post-task auto-skill creation
- [x] 3-layer progressive memory retrieval
- [x] Overnight Note Research — NightBrain-scheduled deep research on flagged notes with morning summary
- [x] Usage cost dashboard
- [x] Slash-command palette (/plan, /research, /review)
- [x] Metal thinking glow shader for OmegaPanel
- [x] Full validation checklist passes (3/3 recursive clean)
- [x] All Rust tests pass (371 tests, 0 failures)

## Sprint Omega-5: Living Vault Memory Engine (in progress)
- [x] Task 1: diff_engine.rs — unified text diff, JSON pointer diff, and 3-line fuzzy patch apply (2026-03-30)
- [x] Task 2: memory_classifier.rs — ADD/UPDATE/DELETE/NOOP vault write classifier with compact prompt + local/Haiku dispatch hint + contradiction planner (2026-03-30)
- [x] Task 3: memory_decay.rs — Ebbinghaus decay + garbage collection with pinned/access-aware batch decay (2026-03-30)
- [x] Task 4: cross_propagation.rs — Tantivy/file-scan reference detection with atomic secondary patch rollback (2026-03-30)
- [x] Task 5: vault_git.rs — git-backed atomic vault commits with history + diff_between support (2026-03-30)
- [x] Task 6: ConversationPersistence.swift — JSONL + markdown conversation persistence (2026-03-30)
- [x] Task 7: VaultChatMutator.swift — diff staging + approval flow (2026-03-30)
- [x] Task 8: VaultRegistry.swift / vault_registry.rs — multi-vault identity mapping (2026-03-30)
- [x] Task 9: Full compilation + integration verification (2026-03-30)

## Agent Integration Session (2026-03-30) ✅
Items 1-15 from `docs/AGENT_INTEGRATION_SESSION_PLAN.md` — all building clean.

### Do First Tier ✅
- [x] Item 6: ToolLoopDetector wired into Hermes bridge tool_completed events (2026-03-30)
- [x] Item 5: AgentDepthLimiter wired into Hermes bridge tool_started/completed for delegate tools (2026-03-30)
- [x] Item 15: CredentialRedactor — 9 patterns, wired into vault_search + vault_read (2026-03-30)
- [x] Item 14: CostTracker — micro-dollar precision, March 2026 pricing, wired into complete events (2026-03-30)
- [x] Item 8: ContextCompiler — U-curve reordering on vault_search results (2026-03-30)

### Do Second Tier ✅
- [x] Item 13: MemoryThreatScanner — role hijack + exfiltration + invisible unicode, wired into vault tools (2026-03-30)
- [x] Item 12: ShadowGitCheckpoint — GIT_DIR/WORK_TREE separation, 10s timeout, auto-checkpoint (2026-03-30)
- [x] Item 3: NightBrain menu bar agent mode — config + delegate + Settings toggle (2026-03-30)
- [x] Item 7: Living Vault Rust FFI exports — classify_vault_memory, decay_memory_nodes, gc_memory_nodes (2026-03-30)

### Do Third Tier ✅
- [x] Item 4: SkillStoreView — 7 categories, search, detail sheet, native + Hermes skills (2026-03-30)
- [x] Item 9: QLoRATrainer prefers composed train_final.jsonl over raw shards (2026-03-30)
- [x] Item 1: HTTP/SSE transport via NWListener for MCP payloads >50KB (2026-03-30)
- [x] Item 2: recovery.rs (7 tests) + HexViewerView with Rust FFI (2026-03-30)

### Gemini Deep Analysis Integration ✅
- [x] Evaluated 6 proposals from OpenClaw/Hermes comparative analysis (2026-03-30)
- [x] Accepted: Heartbeat Memory Distillation (Item 20), Sub-Agent Context Scoping (Item 21)
- [x] Rejected: A2UI (already SwiftUI), PyO3 (wrong direction), Zero-Trust WS (local app), Docker Proxy (deferred)
- [x] Updated AGENT_INTEGRATION_SESSION_PLAN.md, MASTER_SESSION_PROMPT.md, AGENT_PROGRESS.md

### Do Next Tier (Gemini analysis upgrades) ✅
- [x] Item 20: NightBrain Heartbeat Memory Distillation — memoryDistillation job in NightBrainService, calls AgentGraphMemory.distillMemory() with Ebbinghaus decay + GC (2026-03-30)
- [x] Item 21: Sub-Agent Hierarchical Context Scoping — context_scope parameter in delegate_tool.py, 3 role-specific context files (terminal, research, file) in hermes-agent/contexts/ (2026-03-30)

## Sprint Omega-6: Context Compiler + Graph Visualizer ✅ (2026-03-31)
- [x] Task 1: context_compiler.rs — prompt DAG with cache-optimal assembly (2026-03-30)
- [x] Task 2: skill_router.rs — TF-IDF skill selection (7 tests) (2026-03-30, verified 2026-03-31)
- [x] Task 3: example_bank.rs — few-shot retrieval + Jaccard quality ranking (6 tests) (2026-03-30, verified 2026-03-31)
- [x] Task 4: GraphDataModel.swift — execution trace → graph subgraph conversion (2026-03-30, verified 2026-03-31)
- [x] Task 5: AgentGraphView.swift — Canvas-based DAG with hierarchical layout (2026-03-30, verified 2026-03-31)
- [x] Task 6: SemanticZoomController.swift — 5-level semantic zoom + control strip (2026-03-30, verified 2026-03-31)
- [x] Task 7: NodeDetailPanel.swift — node inspector with metadata grid (2026-03-30, verified 2026-03-31)
- [x] Full verification: 449 Rust tests pass, Swift BUILD SUCCEEDED (2026-03-31)

## Sprint Omega-7: Paperclip/Lambda Fusion (2026-03-31)
- [x] Task 1: chunk_reduce.rs — parallel split/map/reduce tool (13 tests, λ-RLM pattern) (2026-03-31)
- [x] Task 2: Think-block streaming UI — <think> token parser + blurred ChainOfThoughtBubble (2026-03-31)
- [x] Task 3: CostTracker 3-tier budget — session + per-agent + rolling daily + pre-turn gating (2026-03-31)
- [x] Task 4: AgentHeartbeatService — NSBackgroundActivityScheduler heartbeat with budget gating (2026-03-31)
- [x] Task 5: openai.rs — OpenAI Chat Completions SSE provider (16 tests) (2026-03-31)
- [x] Task 6: PTY test stabilization — environment-robust working_dir assertion (2026-03-31)
- [x] Full verification: 449 Rust tests, 0 failures; Swift BUILD SUCCEEDED (2026-03-31)

## Runtime Input Audit Continuation (2026-04-19)
- [x] `ChatCoordinator` attachment contract now treats attached notes/files as already resolved context and explicitly forbids asking the user for a path or re-upload when `Content:` is already present (`783a9651`)
- [x] `InferenceState` now normalizes stale/persisted Gemma 4 preview chat selections back to `qwen3_4B4Bit` on both selection and state load, closing the remaining Gemma leak into live chat state (`ac37571e`)
- [x] `AssistantToolbarAskBar`, `NoteDetailWorkspaceView`, `MiniChatView`, and `CommandBarView` now surface explicit `Loading <model>…` affordances before first visible token so cold local loads no longer read as silent freezes outside main chat (`43092ae5`)
- [x] `LocalModelToolbarMenu` and `SettingsView` now drop duplicate/noisy runtime affordances: only one `Open Settings` entry point remains in the chat picker, the redundant `Active Tier` row is gone, and per-row loader warnings no longer spam the local model list (`0befc7c5`)
- [x] `AgentCommandCenterState` local-brain mode exposure now matches the real runtime contract — always-thinking fast-incompatible locals like `qwen25Coder7B` no longer advertise Fast, and ACC specialist defaults now prefer safer local brains first (`695ce712`)
- [x] `OpenAICompatibleChatSupport` now enforces a fallback `max_tokens` budget of 4096 whenever the caller leaves it at zero, preventing compatible providers from silently running unbounded (`b19a768e`)
- [x] `LocalModelInfrastructure`, `RootView`, `SettingsView`, and `ModelAboutSheet` now separate `This Mac`, `Chat Memory`, and `Model Files` for `qwen25Coder7B`; the coder tier uses a 24 GB interactive floor in user-facing guidance (`1563ad8d`)
- [x] `qwen25Coder7B` is no longer part of the shipping optional baseline and is hidden from the release chat picker until the freeze path is live-verified (`b587dda4`)
- [x] `AgentChatState` and `AgentChatView` now route inline `<think>` blocks into the agent thinking popover and persist the captured reasoning trail onto finalized agent turns (`6f9d863c`)
- [ ] Still needs live launched-app verification: `qwen25Coder7B` cold-load UX, direct-cloud and Rust-agent thinking separation, and any remaining crash repros
