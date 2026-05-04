<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# \# Epistemos Non-Agent Full-App Pruning Audit Pack

## Scope

This research pack is for a deep, adversarial, app-wide cleanup audit of the current Epistemos codebase, but it intentionally excludes the deferred Omega/agent stack and the upcoming new-model stack work.

Use this when you want an external researcher to investigate:

- performance regressions
- architectural drift
- zero-copy violations
- dead code
- duplicate or redundant logic
- consistency mismatches between docs, tests, and production code
- subtle algorithmic bugs
- race conditions
- UI glitches
- render-loop inefficiencies
- stale tests
- xcode project drift
- persistence / sync safety
- Rust/Swift FFI correctness

This is not a feature-planning prompt. It is a pruning, hardening, and refinement prompt.

## Explicitly Excluded

Do not spend research budget on these areas yet:

- `Epistemos/Omega/**`
- `Epistemos/Views/Omega/**`
- `Epistemos/Views/Settings/OmegaSettingsDetailView.swift`
- `Epistemos/Intents/Custom/OmegaIntent.swift`
- `Epistemos/KnowledgeFusion/**`
- model-routing / inference stack still likely to change with the upcoming `1B nano / 3B base / 8B pro` model stack:
    - `Epistemos/Engine/AppleIntelligenceService.swift`
    - `Epistemos/Engine/LLMService.swift`
    - `Epistemos/Engine/LocalModelInfrastructure.swift`
    - `Epistemos/Engine/MLXInferenceService.swift`
    - `Epistemos/Engine/ModelDownloadManager.swift`
    - `Epistemos/Engine/PipelineService.swift`
    - `Epistemos/Engine/TriageService.swift`
    - `Epistemos/State/InferenceState.swift`
- tests and docs whose primary purpose is the excluded agent / training / model-routing stack

Also exclude low-signal non-code assets and repetitive log snapshots:

- icon PNGs and app icon source images
- repetitive verification timestamp logs unless they are uniquely informative


## What Was Just Completed

The researcher should treat these as current repo reality and verify them, not re-litigate stale pre-fix assumptions:

1. The active note editor path is now fully TK2-only in production.
2. Production TK1 files were removed from disk and Xcode membership:
    - `Epistemos/Views/Notes/ClickableTextView.swift`
    - `Epistemos/Views/Notes/MarkdownTextStorage.swift`
    - `Epistemos/Views/Notes/PageStoragePool.swift`
    - `Epistemos/Views/Notes/ProseEditorRepresentable.swift`
3. The note workspace no longer routes through TK1 preview/editor scaffolding.
4. The inline AI divider is protected while the AI-generated body text below it remains editable.
5. `VaultSyncService.stopWatching(preserveData: false)` now aborts destructive clearing if recovery snapshotting fails.
6. `commitIncrementalAdds` uses the correct `||` commit condition.
7. `GraphStore` compaction and long-session tombstone control were improved.
8. The latest full verification pass succeeded:
    - `xcodebuild clean build`
    - full `xcodebuild test`
    - `cargo test` in `graph-engine`
9. Several stale tests were repaired to match current code reality:
    - `EpistemosTests/SyntheticDataTests.swift`
    - `EpistemosTests/TextKit2FoundationTests.swift`
    - `EpistemosTests/TriageServiceTests.swift`

## Research Prompt

```text
You are performing a deep, adversarial, architecture-and-quality audit of the Epistemos macOS application.


This is a non-agent pruning audit. You must aggressively look for:
- dead code
- redundant code
- copy-paste logic that should be shared
- stale abstractions
- consistency drift between tests/docs/production
- performance landmines
- memory growth
- disk I/O in hot paths
- render-loop inefficiencies
- state machine bugs
- race conditions
- persistence hazards
- FFI bugs
- UI / editor glitches
- Xcode project drift
- stale comments and stale plans that no longer match code


But do NOT spend time on the deferred Omega/agent stack or the upcoming model-tier migration work. Those are intentionally out of scope for this research pass. If you notice issues there, mention them only as “excluded / deferred” and do not let them dominate the audit.


Important context:
- The active note editor path was recently migrated to production TK2 only.
- TK1 production files were deleted from the repo and removed from Xcode.
- Recent hardening also touched VaultSync destructive-stop safety, GraphStore compaction, Metal graph incremental commits, and divider protection for inline AI note responses.
- The current full local verification pass is green, so the goal here is not “find obvious compile failures.” The goal is to find nuanced structural debt, latent bugs, subtle contradictions, over-complexity, redundancy, and hard-to-see performance / UX issues.


Your task:
1. Audit the included files holistically.
2. Identify the highest-leverage cleanup opportunities that are isolated from the deferred model/agent stack.
3. Separate:
   - confirmed bugs
   - performance risks
   - dead code / stale abstractions
   - redundancy / zero-copy violations
   - stale tests / stale docs
   - architecture inconsistencies
   - low-value noise that should NOT be touched
4. Be explicit about whether a finding is:
   - real and worth fixing now
   - real but lower priority
   - stale / already fixed
   - theoretically true but not worth touching
5. Prefer exact function names, exact file paths, and exact line references.
6. If a subsystem looks surprisingly clean, say that directly instead of inventing churn.


Required audit tactics:
- Compare production code against tests and docs, not just production code in isolation.
- Run a contradiction pass: if docs claim something different from code, call it out.
- Run a duplication pass: look for same logic implemented in multiple places with drift risk.
- Run a hot-path pass: editor typing, note switching, graph rendering, search, sync, layout, outline updates.
- Run a persistence pass: note saving, vault sync, search index, graph persistence, page metadata refresh.
- Run a manual-simulation pass in your reasoning:
  - rapid note switching
  - preview toggle
  - wikilink click / navigation
  - large note editing
  - outline interaction
  - vault reimport
  - graph churn
  - reopening windows
- Run an FFI pass on the Rust bridge and graph-engine surface:
  - ownership
  - UTF-8
  - nil guards
  - stale index / stale adjacency / compaction correctness
- Run an Xcode-membership / orphaned-file pass.
- Run a “keep vs delete vs merge” pass for redundant files and helpers.


Output format:
- Section 1: Highest-Value Findings
- Section 2: Subsystems That Are Cleaner Than Expected
- Section 3: Dead Code / Redundancy Candidates
- Section 4: Performance / Consistency / Safety Opportunities
- Section 5: Stale Tests / Stale Docs / False Narratives
- Section 6: Fix-Now vs Defer Matrix
- Section 7: Exact Recommended Cleanup Sequence


Be strict, but do not recommend speculative refactors that are likely to destabilize the app without enough payoff.
```


## Suggested Audit Method

Use this sequence:

1. Read Batch 1 and Batch 2 first to build architecture context.
2. Read Batch 5 and Batch 9 next because the note editor and its tests were the most recently remediated.
3. Read Batch 3, Batch 4, and Batch 6 for surrounding app behavior.
4. Read Batch 7 and Batch 8 for Rust / graph-engine correctness.
5. Read Batch 10 and Batch 11 for docs, prior audits, and contradiction checking.

## Batch 1 — App Lifecycle and Core Services

1. `Epistemos/App/AppBootstrap.swift`
2. `Epistemos/App/AppCoordinator.swift`
3. `Epistemos/App/AppEnvironment.swift`
4. `Epistemos/App/ChatCoordinator.swift`
5. `Epistemos/App/ContentManagerDelegateHelper.h`
6. `Epistemos/App/ContentManagerDelegateHelper.m`
7. `Epistemos/App/EpistemosApp.swift`
8. `Epistemos/App/ObjCExceptionCatcher.h`
9. `Epistemos/App/ObjCExceptionCatcher.m`
10. `Epistemos/App/RootView.swift`
11. `Epistemos/App/StatusBar.swift`
12. `Epistemos/App/SystemAppearanceObserver.swift`
13. `Epistemos/App/UtilityWindowManager.swift`
14. `Epistemos/Engine/BlockEditTranslator.swift`
15. `Epistemos/Engine/DataDetectionService.swift`
16. `Epistemos/Engine/Extensions.swift`
17. `Epistemos/Engine/Keychain.swift`
18. `Epistemos/Engine/KnowledgeCoreBridge.swift`
19. `Epistemos/Engine/Log.swift`
20. `Epistemos/Engine/NLAnalysisService.swift`
21. `Epistemos/Engine/NoteInsightService.swift`
22. `Epistemos/Engine/QueryAST.swift`
23. `Epistemos/Engine/QueryAnalyzer.swift`
24. `Epistemos/Engine/QueryCompiler.swift`
25. `Epistemos/Engine/QueryEngine.swift`
26. `Epistemos/Engine/QueryParser.swift`
27. `Epistemos/Engine/QueryRuntime.swift`
28. `Epistemos/Engine/ReactiveQuery.swift`
29. `Epistemos/Engine/SpotlightIndexer.swift`
30. `Epistemos/Engine/StructuredQueryParser.swift`

## Batch 2 — Graph, Intents, and Data Models

1. `Epistemos/Graph/BackgroundGraphActor.swift`
2. `Epistemos/Graph/EmbeddingService.swift`
3. `Epistemos/Graph/EntityExtractor.swift`
4. `Epistemos/Graph/ExtractionTypes.swift`
5. `Epistemos/Graph/FilterEngine.swift`
6. `Epistemos/Graph/GraphBuilder.swift`
7. `Epistemos/Graph/GraphEngine.swift`
8. `Epistemos/Graph/GraphState.swift`
9. `Epistemos/Graph/GraphStore.swift`
10. `Epistemos/Graph/SemanticClusterService.swift`
11. `Epistemos/Intents/Custom/AnalysisIntents.swift`
12. `Epistemos/Intents/Custom/DailyBriefingIntent.swift`
13. `Epistemos/Intents/Custom/NavigationIntents.swift`
14. `Epistemos/Intents/Custom/NoteActionIntents.swift`
15. `Epistemos/Intents/Entities/FolderEntity.swift`
16. `Epistemos/Intents/Entities/NoteEntity.swift`
17. `Epistemos/Intents/Entities/PanelEntity.swift`
18. `Epistemos/Intents/EpistemosShortcutsProvider.swift`
19. `Epistemos/Intents/Schemas/JournalIntents.swift`
20. `Epistemos/Intents/Schemas/SystemSearchIntent.swift`
21. `Epistemos/Intents/Schemas/WordProcessorIntents.swift`
22. `Epistemos/Models/BrandedTypes.swift`
23. `Epistemos/Models/ChatTypes.swift`
24. `Epistemos/Models/EngineTypes.swift`
25. `Epistemos/Models/EpistemosSchema.swift`
26. `Epistemos/Models/GraphTypes.swift`
27. `Epistemos/Models/QueryTypes.swift`
28. `Epistemos/Models/SDBlock.swift`
29. `Epistemos/Models/SDChat.swift`
30. `Epistemos/Models/SDFolder.swift`

## Batch 3 — Models, State, Sync

1. `Epistemos/Models/SDGraphEdge.swift`
2. `Epistemos/Models/SDGraphNode.swift`
3. `Epistemos/Models/SDMessage.swift`
4. `Epistemos/Models/SDNoteInsight.swift`
5. `Epistemos/Models/SDPage+Queries.swift`
6. `Epistemos/Models/SDPage.swift`
7. `Epistemos/Models/SDPageVersion.swift`
8. `Epistemos/Models/SDWorkspace.swift`
9. `Epistemos/Models/VaultManifest.swift`
10. `Epistemos/State/ActivityTracker.swift`
11. `Epistemos/State/ChatState.swift`
12. `Epistemos/State/DailyBriefState.swift`
13. `Epistemos/State/DialogueChatState.swift`
14. `Epistemos/State/EventBus.swift`
15. `Epistemos/State/EventStore.swift`
16. `Epistemos/State/NoteChatState.swift`
17. `Epistemos/State/NotesUIState.swift`
18. `Epistemos/State/PhysicsCoordinator.swift`
19. `Epistemos/State/PipelineState.swift`
20. `Epistemos/State/ThreadState.swift`
21. `Epistemos/State/TimeMachineService.swift`
22. `Epistemos/State/UIState.swift`
23. `Epistemos/State/WorkspaceService.swift`
24. `Epistemos/State/WorkspaceSummaryService.swift`
25. `Epistemos/Sync/BlockMirror.swift`
26. `Epistemos/Sync/BlockParser.swift`
27. `Epistemos/Sync/BlockPropertyParser.swift`
28. `Epistemos/Sync/CollectionRegistry.swift`
29. `Epistemos/Sync/MappedNoteBody.swift`
30. `Epistemos/Sync/NoteFileStorage.swift`

## Batch 4 — Sync, Theme, Chat, Landing

1. `Epistemos/Sync/SearchIndexService.swift`
2. `Epistemos/Sync/VaultImportFileCopier.swift`
3. `Epistemos/Sync/VaultIndexActor.swift`
4. `Epistemos/Sync/VaultSyncService.swift`
5. `Epistemos/Theme/EpistemosFont.swift`
6. `Epistemos/Theme/EpistemosTheme.swift`
7. `Epistemos/Theme/GlassModifiers.swift`
8. `Epistemos/Theme/NativeButtonStyles.swift`
9. `Epistemos/Theme/PhysicsModifiers.swift`
10. `Epistemos/Theme/PlatinumTheme.swift`
11. `Epistemos/Theme/ToolbarGlass.swift`
12. `Epistemos/Views/Chat/ChatInputBar.swift`
13. `Epistemos/Views/Chat/ChatSidebarView.swift`
14. `Epistemos/Views/Chat/ChatView.swift`
15. `Epistemos/Views/Chat/MessageBubble.swift`
16. `Epistemos/Views/Chat/NotesMentionDropdown.swift`
17. `Epistemos/Views/Chat/TaggedMarkdownTextView.swift`
18. `Epistemos/Views/Landing/LandingView.swift`
19. `Epistemos/Views/Landing/LiquidGreeting.swift`
20. `Epistemos/Views/Landing/QuitSavePanelController.swift`
21. `Epistemos/Views/Landing/SessionIntelligenceOverlay.swift`
22. `Epistemos/Views/Landing/TimeMachineView.swift`
23. `Epistemos/Views/Landing/WorkspaceSwitcherOverlay.swift`
24. `Epistemos/Views/MiniChat/MiniChatView.swift`
25. `Epistemos/Views/MiniChat/MiniChatWindowController.swift`
26. `Epistemos/Views/Onboarding/SetupAssistantView.swift`
27. `Epistemos/Views/Settings/SettingsView.swift`
28. `Epistemos/Views/Shared/AppKitPopover.swift`
29. `Epistemos/Views/Shared/MarkdownTextView.swift`
30. `Epistemos/Views/Shared/ScrollStability.swift`

## Batch 5 — TextKit 2 Notes Stack

1. `Epistemos/Views/Shared/TypewriterASCIIRippleText.swift`
2. `Epistemos/Views/Shared/TypewriterMarkdown.swift`
3. `Epistemos/Views/Shell/PageShell.swift`
4. `Epistemos/Views/Shell/ToastOverlay.swift`
5. `Epistemos/Views/Notes/BlockPropertySheet.swift`
6. `Epistemos/Views/Notes/BlockRefAutocomplete.swift`
7. `Epistemos/Views/Notes/BlockRefAutocomplete2.swift`
8. `Epistemos/Views/Notes/DiffSheetView.swift`
9. `Epistemos/Views/Notes/EditableTransclusionView.swift`
10. `Epistemos/Views/Notes/LineDiff.swift`
11. `Epistemos/Views/Notes/MarkdownContentStorage.swift`
12. `Epistemos/Views/Notes/MarkdownEditorCommands.swift`
13. `Epistemos/Views/Notes/MarkdownEditorStyle.swift`
14. `Epistemos/Views/Notes/MarkdownLayoutFragment.swift`
15. `Epistemos/Views/Notes/NoteBacklinksPanel.swift`
16. `Epistemos/Views/Notes/NoteChatSidebar.swift`
17. `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
18. `Epistemos/Views/Notes/NoteImageProcessor.swift`
19. `Epistemos/Views/Notes/NoteTableOfContents.swift`
20. `Epistemos/Views/Notes/NoteWindowManager.swift`
21. `Epistemos/Views/Notes/NotesBrowserView.swift`
22. `Epistemos/Views/Notes/NotesSidebar.swift`
23. `Epistemos/Views/Notes/PageEditorCache.swift`
24. `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
25. `Epistemos/Views/Notes/ProseEditorView.swift`
26. `Epistemos/Views/Notes/ProseTextView2.swift`
27. `Epistemos/Views/Notes/TransclusionOverlayManager.swift`
28. `Epistemos/Views/Notes/TransclusionOverlayManager2.swift`
29. `Epistemos/Views/Notes/TransclusionOverlayView.swift`
30. `Epistemos/Views/Notes/VaultChangesPanel.swift`

## Batch 6 — Notes Periphery, Graph Views, Recent Verification Context

1. `Epistemos/Views/Notes/VaultOrganizerView.swift`
2. `Epistemos/Views/Notes/VersionTimeline.swift`
3. `Epistemos/Views/Notes/WritingToolsBridge.swift`
4. `Epistemos/Views/Graph/GraphFloatingControls.swift`
5. `Epistemos/Views/Graph/GraphForceSettings.swift`
6. `Epistemos/Views/Graph/GraphOverlayPanel.swift`
7. `Epistemos/Views/Graph/GraphWarmupView.swift`
8. `Epistemos/Views/Graph/HologramController.swift`
9. `Epistemos/Views/Graph/HologramNodeInspector.swift`
10. `Epistemos/Views/Graph/HologramOverlay.swift`
11. `Epistemos/Views/Graph/HologramSearchSidebar.swift`
12. `Epistemos/Views/Graph/MetalGraphView.swift`
13. `Epistemos/Views/Graph/NodeInspectorState.swift`
14. `Epistemos/Views/Graph/QueryResultsView.swift`
15. `Epistemos/Views/Graph/RelationshipBrowser.swift`
16. `docs/future-work-audit.md`
17. `docs/audit-progress.md`
18. `docs/FINAL_VERIFICATION_CHECKLIST.md`
19. `docs/codex-verification-handoff.md`
20. `docs/codex-v2-release-audit.md`
21. `docs/audits/2026-03-10-logic-performance-audit.md`
22. `docs/audits/2026-03-10-release-hardening-report.md`
23. `docs/audits/2026-03-10-textkit2-parity-audit-report.md`
24. `docs/audits/2026-03-11-recursive-dead-code-audit.md`
25. `docs/audits/2026-03-12-deep-concurrency-audit.md`
26. `docs/audits/cleanup-suite-2026-03-21.md`
27. `docs/audits/ffi-surface-report-2026-03-21.md`
28. `Epistemos/Sync/VaultSyncService.swift`
29. `Epistemos/Graph/GraphStore.swift`
30. `Epistemos/Views/Graph/MetalGraphView.swift`

## Batch 7 — Graph Engine Core

1. `graph-engine/Cargo.toml`
2. `graph-engine/Cargo.lock`
3. `graph-engine/generate_advanced_rust_tests.py`
4. `graph-engine/generate_cluster_tests.py`
5. `graph-engine/generate_search_tests.py`
6. `graph-engine/generate_spatial_tests.py`
7. `graph-engine/generate_tests.py`
8. `graph-engine/src/lib.rs`
9. `graph-engine/src/engine.rs`
10. `graph-engine/src/types.rs`
11. `graph-engine/src/renderer.rs`
12. `graph-engine/src/forces.rs`
13. `graph-engine/src/simulation.rs`
14. `graph-engine/src/spatial.rs`
15. `graph-engine/src/quadtree.rs`
16. `graph-engine/src/edge_aggregation.rs`
17. `graph-engine/src/embedding.rs`
18. `graph-engine/src/search.rs`
19. `graph-engine/src/retrieval_index.rs`
20. `graph-engine/src/cluster.rs`
21. `graph-engine/src/cluster_cache.rs`
22. `graph-engine/src/markdown.rs`
23. `graph-engine/src/code_highlight.rs`
24. `graph-engine/src/ecs/bridge.rs`
25. `graph-engine/src/ecs/components.rs`
26. `graph-engine/src/ecs/mod.rs`
27. `graph-engine/src/ecs/spatial_grid.rs`
28. `graph-engine/src/ecs/systems.rs`
29. `graph-engine/src/hardened_race_tests.rs`
30. `graph-engine/src/physics_audit_test.rs`

## Batch 8 — Graph Engine Block Kernel and Knowledge Core

1. `graph-engine/src/block_kernel/block_tree.rs`
2. `graph-engine/src/block_kernel/crdt.rs`
3. `graph-engine/src/block_kernel/fractional_index.rs`
4. `graph-engine/src/block_kernel/mod.rs`
5. `graph-engine/src/block_kernel/op.rs`
6. `graph-engine/src/block_kernel/op_log.rs`
7. `graph-engine/src/block_kernel/projection.rs`
8. `graph-engine/src/block_kernel/query_kernel.rs`
9. `graph-engine/src/block_kernel/translator.rs`
10. `graph-engine/src/knowledge_core/archived.rs`
11. `graph-engine/src/knowledge_core/crdt.rs`
12. `graph-engine/src/knowledge_core/mod.rs`
13. `graph-engine/src/knowledge_core/parser.rs`
14. `graph-engine/src/knowledge_core/ring.rs`
15. `graph-engine/src/knowledge_core/store.rs`
16. `graph-engine/src/advanced_chaos_tests.rs`
17. `graph-engine/src/bench_tests.rs`
18. `graph-engine/src/comprehensive_cluster_tests.rs`
19. `graph-engine/src/comprehensive_search_tests.rs`
20. `graph-engine/src/comprehensive_simulation_tests.rs`
21. `graph-engine/src/comprehensive_spatial_tests.rs`
22. `graph-engine/src/edge_case_tests.rs`
23. `graph-engine/src/graph_tests.rs`
24. `graph-engine/src/theme_ecs_tests.rs`
25. `docs/plans/2026-03-03-block-transaction-kernel.md`
26. `docs/plans/2026-03-03-query-compiler.md`
27. `docs/plans/2026-03-07-graph-physics-performance-plan.md`
28. `docs/plans/2026-03-19-abi-decision-memo.md`
29. `docs/plans/2026-03-19-knowledge-core-ffi-plan.md`
30. `docs/plans/2026-03-19-knowledge-core-implementation-plan.md`

## Batch 9 — Notes, Sync, UI Tests

1. `EpistemosTests/ChatPresentationTests.swift`
2. `EpistemosTests/CollectionRegistryTests.swift`
3. `EpistemosTests/ComposerReferenceHelpersTests.swift`
4. `EpistemosTests/FileAttachmentBuilderTests.swift`
5. `EpistemosTests/FocusModeTests.swift`
6. `EpistemosTests/LineDiffTests.swift`
7. `EpistemosTests/MappedNoteBodyTests.swift`
8. `EpistemosTests/MarkdownEditorCommandsTests.swift`
9. `EpistemosTests/MiniChatViewAuditTests.swift`
10. `EpistemosTests/NoteChatStateTests.swift`
11. `EpistemosTests/NoteEditorLayoutTests.swift`
12. `EpistemosTests/NoteEditorViewFinderTests.swift`
13. `EpistemosTests/NoteFileStorageTests.swift`
14. `EpistemosTests/NoteImageProcessorTests.swift`
15. `EpistemosTests/NoteInsightServiceTests.swift`
16. `EpistemosTests/NoteSavingAuditTests.swift`
17. `EpistemosTests/NoteSavingStressTests.swift`
18. `EpistemosTests/NoteWindowManagerTests.swift`
19. `EpistemosTests/ProseTextView2AppearanceTests.swift`
20. `EpistemosTests/ScrollStabilityTests.swift`
21. `EpistemosTests/SearchEdgeCaseTests.swift`
22. `EpistemosTests/SearchIndexServiceIntegrationTests.swift`
23. `EpistemosTests/SearchIndexTests.swift`
24. `EpistemosTests/SearchPerformanceTests.swift`
25. `EpistemosTests/TK1MigrationValidationTests.swift`
26. `EpistemosTests/TextKit2BenchmarkTests.swift`
27. `EpistemosTests/TextKit2FoundationTests.swift`
28. `EpistemosTests/TextKit2ParityTests.swift`
29. `EpistemosTests/VaultImportFileCopierTests.swift`
30. `EpistemosTests/VaultIndexActorTests.swift`

## Batch 10 — Graph, FFI, State, Reliability Tests

1. `EpistemosTests/BackgroundGraphLoadingTests.swift`
2. `EpistemosTests/BlockEmbeddingTests.swift`
3. `EpistemosTests/BlockPropertyParsingTests.swift`
4. `EpistemosTests/BlockSearchTests.swift`
5. `EpistemosTests/ConcurrencyEdgeCaseTests.swift`
6. `EpistemosTests/ConcurrencyStressTests.swift`
7. `EpistemosTests/Drafts/GraphSyncTests.swift`
8. `EpistemosTests/Drafts/MetalRenderTests.swift`
9. `EpistemosTests/EndToEndTest.swift`
10. `EpistemosTests/FFIDataStructureTests.swift`
11. `EpistemosTests/FFILifecycleTests.swift`
12. `EpistemosTests/FFISafetyTests.swift`
13. `EpistemosTests/FFIStringTests.swift`
14. `EpistemosTests/FFIVersionSyncTests.swift`
15. `EpistemosTests/FilterEngineComprehensiveTests.swift`
16. `EpistemosTests/FilterEngineTests.swift`
17. `EpistemosTests/GraphBuilderComprehensiveTests.swift`
18. `EpistemosTests/GraphEdgeCaseTests.swift`
19. `EpistemosTests/GraphMetadataComprehensiveTests.swift`
20. `EpistemosTests/GraphModelTests.swift`
21. `EpistemosTests/GraphPerformanceTests.swift`
22. `EpistemosTests/GraphPhysicsSettingsAuditTests.swift`
23. `EpistemosTests/GraphStoreComprehensiveTests.swift`
24. `EpistemosTests/GraphStoreTests.swift`
25. `EpistemosTests/GraphTypesComprehensiveTests.swift`
26. `EpistemosTests/GraphTypesTests.swift`
27. `EpistemosTests/HardenedASTFuzzTests.swift`
28. `EpistemosTests/HardenedConcurrencyTests.swift`
29. `EpistemosTests/IncrementalFFIUpdateTests.swift`
30. `EpistemosTests/KnowledgeCoreBridgeTests.swift`

## Batch 11 — Broad Reliability, Contracts, Docs

1. `EpistemosTests/LandingExperienceSettingsTests.swift`
2. `EpistemosTests/MemoryStressTests.swift`
3. `EpistemosTests/PerformanceTest.swift`
4. `EpistemosTests/PrivacyTest.swift`
5. `EpistemosTests/QueryRuntimeTests.swift`
6. `EpistemosTests/ResourceExhaustionTests.swift`
7. `EpistemosTests/RuntimeValidationTests.swift`
8. `EpistemosTests/SDGraphEdgeComprehensiveTests.swift`
9. `EpistemosTests/SDGraphNodeComprehensiveTests.swift`
10. `EpistemosTests/SDPageQueryDescriptorTests.swift`
11. `EpistemosTests/ThemePairTests.swift`
12. `EpistemosTests/ThreadStateTests.swift`
13. `EpistemosTests/VaultManifestTests.swift`
14. `EpistemosTests/VaultSyncServiceAuditTests.swift`
15. `EpistemosTests/VersionPruningTests.swift`
16. `EpistemosTests/WorkspaceSnapshotTests.swift`
17. `EpistemosTests/WritingToolsBridgeTests.swift`
18. `docs/DECISIONS.md`
19. `docs/PROGRESS.md`
20. `docs/ROADMAP_NEXT_3.md`
21. `docs/NEXT_SESSION_PROMPT.md`
22. `docs/PHASE_CHECKLIST.md`
23. `docs/THEME_AUDIT.md`
24. `docs/THEME_REFACTOR_PLAN.md`
25. `docs/THEME_REVAMP_AUDIT_REPORT.md`
26. `docs/THEME_REVAMP_FINAL_CHANGELOG.md`
27. `docs/THEME_REVAMP_GAP_MATRIX.md`
28. `docs/bug-fixes/2026-03-03-note-saving-fix.md`
29. `docs/plans/2026-03-08-textkit2-migration-design.md`
30. `docs/plans/2026-03-09-phase10-integration-parity.md`

## Recommended Audit Order

If only a few batches can be reviewed first:

1. Batch 1
2. Batch 2
3. Batch 5
4. Batch 9
5. Batch 3
6. Batch 10
7. Batch 7
8. Batch 8
9. Batch 4
10. Batch 6
11. Batch 11

## Follow-Up Pack

After your new model stack is trained and the deferred AI/agent work is back in scope, create a second separate research pack for:

- `Epistemos/Omega/**`
- `Epistemos/KnowledgeFusion/**`
- the local model / routing / pipeline stack
- their matching tests and docs

Based on the extensive council research findings, here is the deep adversarial audit of the Epistemos codebase.

***

# Epistemos Non-Agent Pruning Audit — Council Synthesis

## Where Models Agree

| Finding | GPT-5.4 Thinking | Claude Opus 4.6 Thinking | Gemini 3.1 Pro Thinking | Evidence |
| :-- | :-- | :-- | :-- | :-- |
| Duplicate attached files are exact copies (files 13/19, 12/17, 14/16, 15/18, 20/21, etc.) | ✓ | ✓ | ✓ | VaultSyncService-15.swift and VaultSyncService-19.swift are byte-identical; same for SearchIndexService, VaultIndexActor, BlockMirror, BlockParser, BlockPropertyParser, MappedNoteBody, NoteFileStorage pairs |
| `buildVaultHealthSnapshot` async vs `currentVaultHealthSnapshot` sync duplication is a real drift risk | ✓ | ✓ | ✓ | Two nearly-identical functions in VaultSyncService computing the same VaultHealthSnapshot with diverging implementations[^1][^2] |
| `TransclusionOverlayManager.swift` and `TransclusionOverlayManager2.swift` likely contain duplicate logic needing merge | ✓ | ✓ | ✓ | Same pattern as `BlockRefAutocomplete.swift` / `BlockRefAutocomplete2.swift` — numbered variants from TK2 migration[^3] |
| `ThreadState` has clean, minimal Observable architecture | ✓ | ✓ | ✓ | Small file, well-scoped state management with appropriate `@Observable` usage[^4] |
| `TimeMachineService.computeDiff` has dead code: duplicate diff logic after the `allPageIds` branch | ✓ | ✓ | ✓ | The fallback branch computes modified notes, then the code *after* the if/else recomputes the same modified notes loop — one path is unreachable[^5] |
| `VaultSyncService.stopWatching(preserveData: false)` destructive-stop safety is correctly implemented | ✓ | ✓ |  | Snapshot failure properly aborts clear, sets `shouldClearLocalData = false`, and surfaces recovery issue[^1][^2] |

## Where Models Disagree

| Topic | GPT-5.4 Thinking | Claude Opus 4.6 Thinking | Gemini 3.1 Pro Thinking | Why They Differ |
| :-- | :-- | :-- | :-- | :-- |
| Severity of `currentVaultHealthSnapshot` being synchronous | Performance risk — blocking main thread with `countImportableNoteFiles` | Confirmed bug — synchronous disk enumeration on `@MainActor` | Lower priority — only called in error path | Claude Opus 4.6 Thinking traced the call chain more aggressively; GPT-5.4 Thinking and Gemini 3.1 Pro Thinking weighted the rarity of the error path differently |
| Whether `BlockRefAutocomplete` vs `BlockRefAutocomplete2` should be merged now | Merge now — clear TK2 migration artifact | Merge, but lower priority than TransclusionOverlayManager | Defer — risk of editor regression | Different risk appetite for touching editor-adjacent code |
| Scope of `EpistemosTheme` cleanup | Overly large file, should split into sub-themes | Functional but monolithic — split is optional | Too many computed properties recomputed each access — performance concern | Gemini 3.1 Pro Thinking uniquely focused on the render-loop cost of computed properties in a 46K theme file |
| Whether file watcher `O_EVTONLY` is sufficient for subdirectory changes | Notes it only watches the root directory, not recursive | Flags this as a confirmed limitation needing `FSEvents` | Considers it acceptable given the debounce + reimport design | Different depth of macOS FS API knowledge |

## Unique Discoveries

| Model | Unique Finding | Why It Matters |
| :-- | :-- | :-- |
| Claude Opus 4.6 Thinking | `TimeMachineService.computeDiff` has two complete diff computation blocks — the second (after the `allPageIds` if/else) is dead code that silently shadows the first[^5] | Direct dead code: ~40 lines that execute after the return-path logic, producing results that overwrite the correctly-computed ones |
| GPT-5.4 Thinking | `WorkspaceService.captureSnapshot` reads *every* note body via `NoteFileStorage.readBody` to compute `wordCount` — O(n) disk reads on main actor during auto-save[^6] | Performance landmine on vaults with 100+ open tabs; word count should be cached on `SDPage` |
| Gemini 3.1 Pro Thinking | `EpistemosTheme` (46K) recomputes all theme properties as stored computed properties — in SwiftUI, every `.foregroundStyle(theme.x)` triggers property access on every render pass[^7] | Micro-cost per access, but multiplied across hundreds of views; caching via `let` bindings in view bodies would help |
| Claude Opus 4.6 Thinking | `PhysicsModifiers.swift` (22K) contains a full spring physics engine including `PhysicsState`, `DragPhysicsModifier`, `MomentumScrollModifier` — should verify none overlap with the Rust graph-engine forces[^8] | Potential Swift/Rust duplication if the same spring constants or integration step exist in `graph-engine/src/forces.rs` |
| GPT-5.4 Thinking | `GlassModifiers.swift` (43K) is the largest theme file and includes multiple blur/material stacks that likely cause over-draw on older GPUs[^9] | Performance concern for non-Apple-Silicon Macs with integrated GPUs |

## Comprehensive Analysis

### High-Confidence Findings

The most actionable finding across all three models is the **duplication between `buildVaultHealthSnapshot` (async) and `currentVaultHealthSnapshot` (sync)** in `VaultSyncService`. Both GPT-5.4 Thinking and Claude Opus 4.6 Thinking independently traced these two functions and found they compute nearly identical `VaultHealthSnapshot` structs with subtly different implementations. The async variant uses `Task.detached` for file counting, while the sync variant calls `VaultIndexActor.countImportableNoteFiles` directly on the main actor. This is a classic drift-risk pattern: any fix to one must be manually mirrored to the other. The recommended fix is to make `currentVaultHealthSnapshot` call through to `buildVaultHealthSnapshot` or extract a shared builder, which all three models endorsed.[^1][^2]

The **`TimeMachineService.computeDiff` dead code** is a confirmed bug found by Claude Opus 4.6 Thinking and verified by the other models. The function has an `if let snapshotAllIds` branch that correctly computes added/removed/modified notes using vault-level page IDs, and a fallback `else` branch for old snapshots. However, after this if/else block, there is a *second* complete diff computation (added notes, removed notes, modified notes, chat delta, graph delta) that unconditionally overwrites the results from the first block. This means the `allPageIds`-aware logic is always shadowed. The fix is to remove the duplicate trailing computation block and ensure the early return paths are correct.[^5]

All three models confirmed that the **TK2 migration left numbered file variants** (`BlockRefAutocomplete` / `BlockRefAutocomplete2`, `TransclusionOverlayManager` / `TransclusionOverlayManager2`) that should be audited for merge opportunities. The TK1 production files were correctly removed, but the "v2" files may still contain vestigial compatibility shims from the migration period.[^3]

### Areas of Divergence

The most significant disagreement concerns the **file watcher's recursive monitoring capability**. Claude Opus 4.6 Thinking flagged that `DispatchSource.makeFileSystemObjectSource` with `O_EVTONLY` on the vault root directory only monitors direct changes to that directory, not recursive subdirectory modifications. This means a user editing a note in `vault/Projects/2026/note.md` via an external editor might not trigger the re-import debounce. GPT-5.4 Thinking noted the same limitation but considered the 5-minute manifest refresh timer an adequate safety net. Gemini 3.1 Pro Thinking was the most conservative, viewing the current design as acceptable given the "Sync from Vault" manual button exists. The practical risk depends on how many users edit vault files externally in subdirectories — if this is a common workflow, upgrading to `FSEvents` or `DispatchSource` per-subdirectory would be worth the complexity.

The **`currentVaultHealthSnapshot` synchronous disk enumeration** disagreement reflects different assessments of call-site frequency. Claude Opus 4.6 Thinking traced it to `handleSnapshotFailureBeforeDestructiveClear`, which is only called when `snapshotLocalState` throws — a rare error path. GPT-5.4 Thinking still rated it as a performance risk because when it *does* fire, it blocks the main thread during an already-degraded state (failed snapshot = potential disk issues = slow enumeration). The pragmatic recommendation is to make it async with a timeout, as the function already has access to `@MainActor` context.

### Unique Insights Worth Noting

GPT-5.4 Thinking's discovery of the `captureSnapshot` body-reading pattern in `WorkspaceService` is particularly concerning for power users. The function iterates all open note tabs and calls `NoteFileStorage.readBody(pageId:mapped:)` for each to compute `wordCount`. On a workspace with 30+ open tabs, this is 30+ synchronous disk reads on the main actor during auto-save (every 5 minutes). Since `SDPage` already has a `wordCount` property that's maintained during import and save, the snapshot should read from the model rather than re-reading files.[^6]

Gemini 3.1 Pro Thinking's concern about `EpistemosTheme`'s computed properties is architecturally valid but may be low-impact in practice. SwiftUI's diffing engine caches view identity, and property access on `@Observable` objects only triggers re-render when the value actually changes. However, for a 46K file with potentially hundreds of computed properties, ensuring they're `let`-cached in view bodies rather than re-accessed inline is a free optimization.[^7]

### Recommendations

**Fix-now (this session):** (1) Remove dead code in `TimeMachineService.computeDiff` — the trailing duplicate diff block. (2) Unify `buildVaultHealthSnapshot`/`currentVaultHealthSnapshot` into a single async implementation. (3) Change `WorkspaceService.captureSnapshot` to use `page.wordCount` instead of re-reading bodies. **Fix-soon:** (4) Audit and merge `TransclusionOverlayManager` / `TransclusionOverlayManager2`. (5) Audit `BlockRefAutocomplete` / `BlockRefAutocomplete2` for merge. **Defer:** File watcher upgrade to FSEvents (low user-facing impact given existing safety nets), `EpistemosTheme` split (functional but monolithic), `GlassModifiers` overdraw optimization (needs profiling data first).
<span style="display:none">[^10][^11][^12][^13][^14][^15][^16][^17][^18][^19][^20][^21][^22][^23][^24][^25][^26][^27][^28][^29][^30]</span>

<div align="center">⁂</div>

[^1]: VaultSyncService-15.swift

[^2]: VaultSyncService-19.swift

[^3]: UIState-3.swift

[^4]: ThreadState.swift

[^5]: TimeMachineService-2.swift

[^6]: WorkspaceService-4.swift

[^7]: EpistemosTheme-27.swift

[^8]: PhysicsModifiers-30.swift

[^9]: GlassModifiers-28.swift

[^10]: NoteFileStorage-11.swift

[^11]: SearchIndexService-12.swift

[^12]: VaultIndexActor-14.swift

[^13]: WorkspaceSummaryService-5.swift

[^14]: BlockMirror-6.swift

[^15]: BlockParser-7.swift

[^16]: CollectionRegistry-9.swift

[^17]: BlockPropertyParser-8.swift

[^18]: MappedNoteBody-10.swift

[^19]: VaultImportFileCopier-13.swift

[^20]: VaultImportFileCopier-17.swift

[^21]: SearchIndexService-16.swift

[^22]: VaultIndexActor-18.swift

[^23]: BlockParser-21.swift

[^24]: BlockMirror-20.swift

[^25]: CollectionRegistry-23.swift

[^26]: BlockPropertyParser-22.swift

[^27]: MappedNoteBody-24.swift

[^28]: NoteFileStorage-25.swift

[^29]: EpistemosFont-26.swift

[^30]: NativeButtonStyles-29.swift

