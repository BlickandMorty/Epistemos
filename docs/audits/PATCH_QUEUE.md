# Patch Queue

Date: 2026-04-28

Rule: implement only safe P0/P1 patches from this queue. Do not start P2 or deferred feature work until the relevant P0/P1 gates are green. Manual-only Phase S tasks are tracked but deferred per user instruction.

## Dependencies

- Patch 1 must run before any MAS ship claim.
- Patch 2 must run before Documents are visible.
- Patch 3 and Patch 4 can run in either order.
- Patch 5 must run before Raw Thoughts is default-on.
- Patch 6 must run before claiming code editor 4k-line fluidity.
- Patch 7 must run before broad artifact search/graph claims.
- Patch 8 can run after the core P1 tests exist.

## Patch 1: MAS Privacy And Unsafe-Surface Profile Gate

Priority:
P0

Status:
Verified for the code-level MAS unsafe-surface gate on 2026-04-28. Fresh MAS build passed in `/tmp/epistemos_mas_tcc_build.log` (`** BUILD SUCCEEDED **`, `EXIT:0`). Binary audit passed in `/tmp/epistemos_mas_tcc_binary_audit.log`: no ScreenCaptureKit, AXorcist, `omega_ax`, or Python runtime link/bundle hit; no dangerous `libomega_mcp` process/PTY symbols. Source gate passed in `/tmp/epistemos_mas_tcc_source_gate.log` and verified App Store branches in `OmegaPermissions.swift` and `TCCPermissionState.swift` omit ScreenCaptureKit/Apple Events APIs. Caveat: `xcodebuild -only-testing:EpistemosTests/ProductionHardeningTests` executed 0 Swift Testing tests, so the source/binary gate is the authoritative proof until test selection is fixed.

Goal:
Prove the Mac App Store build hides or stubs unsafe automation and that Settings/Privacy copy matches entitlements and PrivacyInfo.

Files:
- `Epistemos/AppStore/AppStoreComputerUseStubs.swift`
- `Epistemos/Omega/OmegaPermissions.swift`
- `Epistemos/Omega/Vision/TCCPermissionState.swift`
- `Epistemos/Omega/Vision/ScreenCaptureService.swift`
- `Epistemos/Epistemos-AppStore.entitlements`
- `Epistemos/Resources/PrivacyInfo.xcprivacy`
- `Epistemos/Views/Settings/SettingsView.swift`
- `EpistemosTests/AppStoreHardeningTests.swift`
- `EpistemosTests/ProductionHardeningTests.swift`

Change summary:
Add or refresh tests that verify MAS-visible feature lists exclude ScreenCaptureKit, Accessibility/CGEvent automation, shell/PTY/Docker, and arbitrary external MCP execution. Verify PrivacyInfo and Settings copy agree.

Why:
MAS V1 can fail review if direct-build computer-use capabilities leak into the App Store profile.

Risk:
Low if limited to tests/copy. Medium if changing compile flags.

Rollback:
Revert tests/copy changes and restore previous stubs.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-mas-tcc-build build CODE_SIGNING_ALLOWED=NO`
- command: source gate for MAS-only `OmegaPermissions.swift` and `TCCPermissionState.swift` branches
- command: `otool`/`find`/`nm` binary gate captured in `/tmp/epistemos_mas_tcc_binary_audit.log`
- manual test: deferred

Acceptance criteria:
- MAS build succeeds.
- Source/binary gates prove unsafe surfaces are absent or stubbed.
- No Settings privacy overclaim.

## Patch 2: Document Source-Of-Truth And Projection Recovery Gate

Priority:
P1

Status:
Code/test verified on 2026-04-28 for the non-manual gate. `ReadableBlocksIndexTests` passed 14/14 in `/tmp/epistemos_readable_blocks_tests.log`; focused `.epdoc` controller/search tests passed as part of 49/49 in `/tmp/epistemos_focused_audit_tests.log`; fresh `.epdoc` projection/source-of-truth tests passed 33/33 in `/tmp/epistemos_epdoc_projection_tests.log`. Remaining gate is live `.epdoc` window open/edit/save smoke, deferred per user instruction because it is manual/runtime-only.

Goal:
Prove `.epdoc` uses canonical `content.pm.json`, regenerates projections, and never silently imports `shadow.md` as canonical.

Files:
- `Epistemos/Engine/EpdocDocument.swift`
- `Epistemos/Models/EpdocPackage.swift`
- `Epistemos/Models/ProseMirrorMarkdownProjector.swift`
- `Epistemos/Sync/ReadableBlocksProjector.swift`
- `Epistemos/Sync/ReadableBlocksIndex.swift`
- `EpistemosTests/EpdocEndToEndSmokeTests.swift`
- `EpistemosTests/EpistemosDocumentControllerTests.swift`

Change summary:
Regenerate `shadow.md`, `plain.txt`, and `search_blocks.jsonl` from canonical `content.pm.json` during `EpdocDocument.fileWrapper(ofType:)`; add tests for projection regeneration, external/stale projection safety, FTS bridge behavior, and projector whitespace normalization.

Why:
Documents are now built enough to be tempting, but V1 must not ship a second source of truth or stale search projection.

Risk:
Medium. Tests may expose real gaps in package save/index wiring.

Rollback:
Keep Documents hidden while retaining package code.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:EpistemosTests/EpdocEndToEndSmokeTests -only-testing:EpistemosTests/EpistemosDocumentControllerTests -only-testing:EpistemosTests/ReadableBlocksProjectorTests` -> `/tmp/epistemos_epdoc_projection_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 33 tests executed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_epdoc_projection.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- manual test: deferred open/save `.epdoc`

Acceptance criteria:
- Canonical content survives projection corruption.
- Shadow edits do not silently overwrite canonical JSON.
- Search projection can be regenerated.

## Patch 3: Contextual Shadows V0 End-To-End Proof

Priority:
P1

Status:
Code/test verified for the non-manual V0 gate on 2026-04-28. `ContextualShadowsStateTests` passed 11/11 in `/tmp/epistemos_contextual_shadows_tests.log` (`** TEST SUCCEEDED **`, `EXIT:0`). Source wiring audit passed in `/tmp/epistemos_contextual_shadows_wiring_audit.log`: `ChatInputBar` mounts `ContextualShadowsButton` and `ContextualShadowsPanel`, `NoteDetailWorkspaceView` mounts the same overlay, and both surfaces route hits through production note/chat open helpers. Fresh MAS build passed in `/tmp/epistemos_mas_build_after_contextual_shadows.log` (`** BUILD SUCCEEDED **`, `EXIT:0`). Caveat: current `InstantRecallService` is note-index-only, so V0 classifies returned hits as notes and hides the Chat tab unless real chat hits exist later.

Goal:
Prove typing in note/chat can surface related artifacts without blocking UI and can open the selected result.

Files:
- `Epistemos/State/ContextualShadowsState.swift`
- `Epistemos/Views/Recall/ContextualShadowsButton.swift`
- `Epistemos/Views/Recall/ContextualShadowsPanel.swift`
- `Epistemos/Views/Chat/ChatInputBar.swift`
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` (protected; avoid unless required)
- `EpistemosTests/ContextualShadows*`

Change summary:
Cleared stale hits on disabled/short queries, preserved honest note-only result classification for V0, hid the Chat tab when there are no chat hits, and mounted the Related button/panel in both chat and note workspaces with production open routing.

Why:
This is the V1 differentiator, but it must be user-wired and performance-safe.

Risk:
Medium because editor/chat hooks are hot paths.

Rollback:
Keep `EPISTEMOS_AMBIENT_RECALL_V0` off.

Verification:
- command: `EPISTEMOS_AMBIENT_RECALL_V0=1 xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-contextual-shadows test -only-testing:EpistemosTests/ContextualShadowsStateTests` -> `/tmp/epistemos_contextual_shadows_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 11 Swift Testing tests passed
- command: source wiring audit -> `/tmp/epistemos_contextual_shadows_wiring_audit.log`, `EXIT:0`
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-mas-contextual-shadows build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_contextual_shadows.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- manual test: deferred typing/panel smoke

Acceptance criteria:
- Results are not stale after cancellation.
- V0 note hits are not mislabeled as chats.
- Click/open route is source-proven; runtime click smoke is deferred.
- Chat tab stays hidden until chat-indexed hits exist.

## Patch 4: Instant Recall Async-Only Rebuild Guard

Priority:
P1

Status:
Verified on 2026-04-28. `InstantRecallService.indexBatch(notes:)` and `rebuildIndex(notes:)` are compile-time unavailable stubs, `VaultSyncService` uses `await service.rebuildIndexAsync(notes: notes)`, async search now triggers lazy snapshot hydration, and no production sync rebuild/indexBatch callers were found. Evidence: `/tmp/epistemos_instant_recall_async_guard_tests.log`, `/tmp/epistemos_instant_recall_source_gate.log`, `/tmp/epistemos_mas_build_after_instant_recall_async_guard.log`.

Goal:
Prevent accidental main-actor recall index rebuilds.

Files:
- `Epistemos/KnowledgeFusion/InstantRecallService.swift`
- any callers discovered by `rg "rebuildIndex\\("`
- targeted tests

Change summary:
Keep production callers on `rebuildIndexAsync`; mark sync vault-wide rebuild/indexBatch APIs unavailable; ensure `searchAsync` triggers lazy initial snapshot hydration.

Why:
Large vault rebuilds must never block typing or launch.

Risk:
Low if call-site migration is small.

Rollback:
Restore sync behavior and keep recall V0 hidden.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-instant-recall test -only-testing:EpistemosTests/InstantRecallServiceTests`
- command: `/tmp/epistemos_instant_recall_source_gate.log`
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-mas-instant-recall build CODE_SIGNING_ALLOWED=NO`
- manual test: deferred large-vault import

Acceptance criteria:
- No production UI path calls sync rebuild.
- Async rebuild remains functional.
- Async search hydrates the initial snapshot instead of returning stale empty results forever.

## Patch 5: Raw Thoughts Recovery And Provider-Surface Tests

Priority:
P1

Status:
Code/test verified for the non-manual gate on 2026-04-28. Rust Raw Thoughts storage tests passed 12/12 in `/tmp/epistemos_raw_thoughts_patch5_cargo.log`; Claude provider redacted-thinking tests passed 12/12 in `/tmp/epistemos_claude_provider_redacted_thinking_tests.log`; full `agent_core` tests passed in `/tmp/epistemos_agent_core_patch5_full.log` (`774 passed` plus bin/e2e/doc-test pass, `EXIT:0`); Swift RawThoughtsState tests passed 14/14 in `/tmp/epistemos_raw_thoughts_state_patch5_tests.log`; fresh MAS build passed in `/tmp/epistemos_mas_build_after_raw_thoughts_patch5.log` (`** BUILD SUCCEEDED **`, `EXIT:0`). Remaining gate is live UI/run-link smoke and streaming-load proof before default-on exposure.

Goal:
Prove Raw Thoughts stores only observable provider/app-owned surfaces, recovers partial logs, and preserves opaque Anthropic data when used for replay.

Files:
- `agent_core/src/storage/raw_thoughts.rs`
- `agent_core/src/agent_loop.rs`
- `agent_core/src/provider.rs`
- `agent_core/src/types.rs`
- `agent_core/src/providers/claude.rs`
- `Epistemos/Views/RawThoughts/RawThoughtsInspectorView.swift`
- `EpistemosTests/RawThoughtsStateTests.swift`
- Rust and Swift tests

Change summary:
Add explicit Anthropic `redacted_thinking` event support, keep redacted payloads out of thinking text delegates/summaries, preserve opaque provider payload bytes through Raw Thoughts storage, and add Swift inspector JSONL partial-final-line recovery coverage.

Why:
Raw Thoughts is core to the product identity and high-risk if it fabricates or corrupts reasoning surfaces.

Risk:
Medium. Provider-specific payload assumptions can be subtle.

Rollback:
Keep `EPISTEMOS_RAW_THOUGHTS_V0` hidden.

Verification:
- command: `cargo test --manifest-path agent_core/Cargo.toml raw_thoughts -- --nocapture` -> `/tmp/epistemos_raw_thoughts_patch5_cargo.log`, `EXIT:0`, 12 tests passed
- command: `cargo test --manifest-path agent_core/Cargo.toml providers::claude -- --nocapture` -> `/tmp/epistemos_claude_provider_redacted_thinking_tests.log`, `EXIT:0`, 12 tests passed
- command: `cargo test --manifest-path agent_core/Cargo.toml -- --nocapture` -> `/tmp/epistemos_agent_core_patch5_full.log`, `EXIT:0`, full agent_core suite passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-raw-thoughts-patch5 test -only-testing:EpistemosTests/RawThoughtsStateTests` -> `/tmp/epistemos_raw_thoughts_state_patch5_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 14 Swift Testing tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-mas-raw-thoughts-patch5 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_raw_thoughts_patch5.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- manual test: deferred chat/run browse

Acceptance criteria:
- Partial final line does not hide valid previous events. Verified in `RawThoughtsStateTests.inspectorKeepsValidLinesWithPartialFinalJSONL`.
- Anthropic opaque payload/signature bytes round-trip. Verified for `redacted_thinking` in Rust storage/provider tests; existing signature coverage remains in Raw Thoughts tests.
- Tool calls/results/durations/status are persisted.

## Patch 6: Code Editor 4k-Line Performance And Gutter Gate

Priority:
P1

Status:
Code/test verified for the non-manual component gate on 2026-04-28. The patch did not touch protected Prose editor, graph engine, Metal graph, or hologram paths. Focused Swift code-editor policy/polish/highlighter tests passed in `/tmp/epistemos_code_editor_patch6_tests.log` (`** TEST SUCCEEDED **`, `EXIT:0`, 35 tests passed). The 4k-line line-metric component gate ran 50 scans of a 4k-line buffer and passed in 0.208s. A fresh MAS build passed in `/tmp/epistemos_mas_build_after_code_editor_patch6.log` (`** BUILD SUCCEEDED **`, `EXIT:0`). Remaining gate is full runtime/Instruments proof for 4k-line typing and scrolling with syntax colors enabled; do not market this as Xcode-level fluidity yet.

Goal:
Make the code editor target measurable before changing or advertising the line-count/gutter UX.

Files:
- `Epistemos/Views/Notes/CodeEditorView.swift`
- `Epistemos/Engine/SwiftTreeSitterLiveHighlighter.swift`
- `syntax-core/src/highlight.rs` (only if benchmark proves needed)
- `EpistemosTests/CodeEditor*`

Change summary:
Correct stale editor architecture comments, extract line counting into `CodeEditorLineMetrics`, add 4k-line line-metric component coverage, keep the existing right-side gutter under theme/width tests, and keep SwiftTreeSitter Unicode range tests green.

Why:
User explicitly wants Xcode-like fluidity and a right-side/clean line-count surface without theme conflict.

Risk:
Medium. Editor hot path is sensitive.

Rollback:
Disable gutter toggle and keep current editor behavior.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-code-editor-patch6 test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests -only-testing:EpistemosTests/CodeEditorPolishTests -only-testing:EpistemosTests/SwiftTreeSitterLiveHighlighterTests` -> `/tmp/epistemos_code_editor_patch6_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 35 Swift Testing tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-mas-code-editor-patch6 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_code_editor_patch6.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- manual test: deferred visual scroll check

Acceptance criteria:
- 4k-line component line-count gate recorded. Verified by `RuntimeCapabilityAndPerformancePolicyTests.codeEditorLineMetricsHas4kLineComponentBudget`.
- Syntax ranges survive emoji/CJK fixtures. Existing SwiftTreeSitter live highlighter tests stayed green in the focused suite.
- Gutter width/theme policy does not fight the editor canvas. Verified by `codeLineGutterWidthPolicyIsStableForLargeFiles` and `codeLineGutterThemeTokensStaySubtle`.
- Full scroll/typing/Instruments p95 proof remains open and is required before claiming Xcode-like fluidity.

## Patch 7: Search, Graph, And Derived-Store Consistency

Priority:
P1

Status:
Code/test verified for the non-manual component gate on 2026-04-28. Added readable-block projection tests proving stable artifact ID survives title/path replacement and every `ArtifactKind` resolves to typed artifact/block search hits. Focused readable-block + graph tests passed in `/tmp/epistemos_derived_store_patch7_tests.log` (`** TEST SUCCEEDED **`, `EXIT:0`, 21 Swift Testing tests passed). The command also requested `GraphStoreComprehensiveTests`, but that selector did not match Swift Testing's named suites; counted graph evidence is the `GraphStore` suite, including remove-node edge/adjacency cleanup. Remaining gate is live save/delete/rename/restart smoke across Prose, `.epdoc`, Raw Thoughts, recall, and graph.

Goal:
Prove visible artifact kinds update search/readable blocks and graph relationships on save/delete/rename.

Files:
- `Epistemos/Sync/ReadableBlocksIndex.swift`
- `Epistemos/Sync/SearchIndexService.swift`
- graph builder/store files
- artifact model files
- `EpistemosTests/ReadableBlocksIndexTests.swift`

Change summary:
Add focused component tests for readable-block typed artifact search hits and stable-ID title/path replacement. Reuse existing readable-block delete/replace tests and GraphStore cleanup tests instead of rewriting graph/search production code.

Why:
User-visible recall/search/graph must not drift from canonical data.

Risk:
Medium.

Rollback:
Keep unproven artifact kinds hidden from search/graph filters.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-derived-store-patch7 test -only-testing:EpistemosTests/ReadableBlocksIndexTests -only-testing:EpistemosTests/GraphStoreTests -only-testing:EpistemosTests/GraphStoreComprehensiveTests` -> `/tmp/epistemos_derived_store_patch7_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 21 Swift Testing tests passed
- manual test: deferred search/open/restart smoke

Acceptance criteria:
- Search hit resolves to artifact ID and block ID. Verified for every current `ArtifactKind` in `visibleArtifactKindsResolveToTypedSearchHits`.
- Deleted artifact disappears from derived stores. Existing `deleteAllForArtifact removes rows + cascades into FTS` stayed green.
- Renamed artifact preserves stable ID and updates path/title. Verified in `replaceAllForArtifactPreservesStableIDAcrossRename`.
- Full live save/delete/rename/restart and recall/graph propagation smoke remains deferred.

## Patch 8: Build/Test Evidence Refresh

Priority:
P1

Status:
Code/test evidence refresh completed for the non-manual gate on 2026-04-28. Fresh Pro build passed in `/tmp/epistemos_pro_build_patch8_refresh.log` (`** BUILD SUCCEEDED **`, `EXIT:0`). Fresh MAS build passed in `/tmp/epistemos_mas_build_patch8_refresh.log` (`** BUILD SUCCEEDED **`, `EXIT:0`). Both logs include the known CodeEdit SwiftLint plugin tail noise, but the raw xcodebuild success marker and exit status are green. Manual Phase S release gates remain intentionally deferred per user instruction.

Goal:
Refresh automated evidence after safe patches land.

Files:
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- raw logs under `/tmp` or repo-approved artifact path

Change summary:
Run targeted tests first, then Pro and MAS builds. Update audit with exact commands and results.

Why:
Prior logs are useful but not final proof after new patches.

Risk:
Low.

Rollback:
N/A.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-derived-store-patch7 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_pro_build_patch8_refresh.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-mas-patch8-refresh build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_patch8_refresh.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: targeted test list from patches 1-7
- manual test: deferred

Acceptance criteria:
- Raw logs contain success markers and exit status. Verified for Pro and MAS refresh builds.
- Failures are classified as pre-existing or introduced. No build failure remains; SwiftLint plugin tail noise did not affect xcodebuild success or exit status.

## Patch 9: User-Facing Empty States And Error Copy

Priority:
P2

Goal:
Improve recoverable user experience without adding new feature scope.

Files:
- recall panel
- Raw Thoughts section
- `.epdoc` editor
- search empty state
- Settings advanced/developer surfaces

Change summary:
Add small empty/error states for missing index, no runs, missing document projection, and disabled experimental features.

Why:
The app should fail calmly.

Risk:
Low.

Rollback:
Remove copy changes.

Verification:
- command: targeted UI snapshot/state tests if available
- manual test: deferred

Acceptance criteria:
- No blank panels for recoverable missing data.

## Patch 10: Manual Phase S And Release Evidence

Priority:
P2 until user re-enables manual ship gates

Goal:
Complete launched-app dogfood, Instruments p99, sanitizer/soak, App Store Connect, TestFlight, and submission evidence.

Files:
- release docs
- logs/artifacts

Change summary:
Run manual/runtime release-gate workflow from the Epistemos Release Audit skill.

Why:
Required before any real "release-ready" claim.

Risk:
Low to code, high to schedule.

Rollback:
N/A.

Verification:
- command: reliability gate scripts
- manual test: full Phase S

Acceptance criteria:
- Three zero-fail passes if making a final ship call.

## Patch 11: Deterministic Runtime Phase 0 Preflight

Priority:
P1

Status:
Phase 0 completed on 2026-04-28 in `docs/DETERMINISTIC_RUNTIME_V1_PREFLIGHT.md`. Rust knowledge-core/ring tests, ignored bridge accessor benchmarks, focused Swift bridge/query tests, and Pro/MAS build evidence are green. Production adapter work remains blocked until Swift view-model adapter tests exist.

Goal:
Ground the Deterministic Knowledge Runtime v1 plan in repo reality before coding.

Files:
- `docs/DETERMINISTIC_RUNTIME_V1_PREFLIGHT.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`

Change summary:
Document current production invalidation, staged knowledge-core transport, known blockers, exact files to patch, benchmark commands, and baseline results.

Why:
The staged ring is real, but production UI still uses `ReactiveQuery` plus `NotificationCenter`. Coding an adapter before MutationEnvelope/WatchPlan proof would create architecture drift.

Risk:
Low. Documentation and baseline evidence only.

Rollback:
Remove the preflight doc and audit references.

Verification:
- command: `cargo test --manifest-path graph-engine/Cargo.toml knowledge_core -- --nocapture` -> `/tmp/epistemos_deterministic_phase0_knowledge_core.log`, `EXIT:0`
- command: `cargo test --manifest-path graph-engine/Cargo.toml knowledge_core::ring -- --nocapture` -> `/tmp/epistemos_deterministic_phase0_ring.log`, `EXIT:0`
- command: `cargo test --manifest-path graph-engine/Cargo.toml benchmark_knowledge_core_payload_summary_accessor -- --ignored --nocapture` -> `/tmp/epistemos_deterministic_phase0_summary_bench.log`, `EXIT:0`
- command: `cargo test --manifest-path graph-engine/Cargo.toml benchmark_knowledge_core_payload_rows_batch_accessor -- --ignored --nocapture` -> `/tmp/epistemos_deterministic_phase0_rows_bench.log`, `EXIT:0`
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-deterministic-phase0 test -only-testing:EpistemosTests/KnowledgeCoreBridgeTests -only-testing:EpistemosTests/QueryRuntimeTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_deterministic_phase0_swift_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`
- manual test: deferred

Acceptance criteria:
- Preflight says the staged runtime is not production-wired. Verified.
- Preflight identifies missing `MutationEnvelope`, `QueryFingerprint`, `WatchPlan`, and feature flags. Verified.
- Preflight blocks production adapter work until envelope/watch-plan tests exist. Verified.

## Patch 12: Deterministic Runtime Typed Mutation Envelope Tests

Priority:
P1

Status:
Completed on 2026-04-28. `DatalogStore` now records typed mutation envelopes from real staged mutation paths; focused store tests and the broader Rust `knowledge_core` suite are green.

Goal:
Add the first implementation slice for Deterministic Knowledge Runtime v1 without touching production UI: typed mutation envelopes emitted by real staged knowledge-core mutation paths.

Files:
- `graph-engine/src/knowledge_core/store.rs`

Change summary:
Introduce or expose a typed mutation envelope containing tx id, touched artifact/page IDs, touched block IDs, relation kinds, affected classes, and source operation kind. Add tests for document ingest, block insert, move, delete, link/relation change, body edit, and ordering-only change where supported.

Why:
This is the narrowest safe next step. The production adapter depends on precise mutation semantics.

Risk:
Medium. The store already has `ChangedPatterns`; avoid broad rewrites and keep existing subscription behavior intact.

Rollback:
Remove the envelope type/tests and keep existing `ChangedPatterns` behavior.

Verification:
- command: `cargo test --manifest-path graph-engine/Cargo.toml knowledge_core::store -- --nocapture` -> `/tmp/epistemos_deterministic_phase1_store_tests.log`, `EXIT:0`, 9 passed, 1 ignored
- command: `cargo test --manifest-path graph-engine/Cargo.toml knowledge_core -- --nocapture` -> `/tmp/epistemos_deterministic_phase1_knowledge_core.log`, `EXIT:0`, 29 passed, 5 ignored
- manual test: none

Acceptance criteria:
- Real mutation paths, not helper constructors, emit precise envelope data. Verified for document ingest, block insert, block edit, block move, link relation change, and block delete.
- Existing knowledge-core tests remain green. Verified.
- No Swift production adapter is added in this patch. Verified.

## Patch 13: Deterministic Runtime Query Fingerprints and Watch Plans

Priority:
P1

Status:
Completed on 2026-04-28. Rust store/watch-plan tests and the broader `knowledge_core` suite are green.

Goal:
Add the second implementation slice for Deterministic Knowledge Runtime v1: stable query fingerprints, watch plans, and mutation/watch intersection tests in Rust before any production Swift adapter work.

Files:
- `graph-engine/src/knowledge_core/store.rs`

Change summary:
Represent normalized query identity and dependency watches for staged knowledge-core subscriptions. Add `mutation_intersects_watch_plan` tests for irrelevant/relevant artifact, block, relation, body-only, graph-only, ordering-only, and unsupported fallback behavior.

Why:
Typed mutation envelopes are not useful until the runtime can prove which watchers care. The Swift adapter must not be built on broad invalidation semantics.

Risk:
Medium. This must not replace existing subscription scheduling yet; it should add tested substrate while preserving current behavior.

Rollback:
Remove the watch-plan/fingerprint types and tests; Patch 12 mutation envelopes remain intact.

Verification:
- command: `cargo test --manifest-path graph-engine/Cargo.toml knowledge_core::store -- --nocapture` -> `/tmp/epistemos_deterministic_phase2_store_tests.log`, `EXIT:0`, 17 passed, 1 ignored
- command: `cargo test --manifest-path graph-engine/Cargo.toml knowledge_core -- --nocapture` -> `/tmp/epistemos_deterministic_phase2_knowledge_core.log`, `EXIT:0`, 37 passed, 5 ignored
- manual test: none

Acceptance criteria:
- Equivalent normalized queries produce identical fingerprints. Verified.
- Different query shapes produce different fingerprints. Verified.
- Relevant mutations invalidate matching watch plans. Verified.
- Irrelevant mutations do not invalidate matching watch plans. Verified.
- Unsupported query types fall back safely. Verified.
- Existing subscription behavior remains unchanged. Verified by broader `knowledge_core` suite.

## Patch 14: Deterministic Runtime Feature Flags

Priority:
P1

Status:
Completed on 2026-04-28. Swift runtime capability policy tests are green.

Goal:
Add the Swift feature-flag boundary required before any production deterministic-runtime adapter can be wired.

Files:
- `Epistemos/Engine/Log.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`

Change summary:
Introduce `EpistemosRuntimeFeatureFlags` with default-off flags for `deterministicKnowledgeCoreRuntime`, `borrowedKnowledgeRows`, `rawThoughtsBulkLane`, `staticArtifactRouting`, and `graphEdgePrefetch`. Add tests proving default-off behavior and explicit UserDefaults/environment opt-in behavior.

Why:
The production adapter needs a hard rollback/fallback switch before it can touch live view-model paths. This keeps deterministic-runtime work reversible and prevents staged code from becoming silently always-on.

Risk:
Low. The patch adds a passive flag reader and policy tests only; it does not wire the new runtime into production UI.

Rollback:
Remove `EpistemosRuntimeFeatureFlags` and the two policy tests; Patch 12/13 Rust substrate remains intact.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-runtime-flags-patch14 test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_runtime_flags_patch14_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 16 tests passed
- manual test: none

Acceptance criteria:
- All deterministic-runtime flags default off. Verified.
- UserDefaults can opt flags in. Verified.
- Environment variables can explicitly override flags on or off. Verified.
- No production adapter is enabled by this patch. Verified.

## Patch 15: Deterministic Runtime Adapter Contract

Priority:
P1

Status:
Completed on 2026-04-28. Focused `KnowledgeCoreBridgeTests` are green.

Goal:
Add the first Swift-side adapter contract for deterministic runtime payload application without mutating production UI broadly or bypassing the fallback flag.

Files:
- `Epistemos/Engine/KnowledgeCoreBridge.swift`
- `EpistemosTests/KnowledgeCoreBridgeTests.swift`

Change summary:
Introduce `KnowledgeCoreRuntimeAdapter`, `KnowledgeCoreRuntimeAdapterApplyResult`, and explicit fallback reasons. The adapter applies only outline payloads and only when `deterministicKnowledgeCoreRuntime` is enabled. Add tests proving flag-off fallback, real mutation-to-ring-to-outline-payload sink application when enabled, and unsupported payload fallback.

Why:
This creates a narrow, reviewable seam between the staged knowledge-core ring and future production view-model wiring. It avoids unsafe direct `QueryEngine` mutation until subscription-to-view-model ownership is explicit.

Risk:
Medium. The adapter contract is tested, but it is not yet production UI wiring. Claiming end-to-end deterministic runtime would still be false.

Rollback:
Remove `KnowledgeCoreRuntimeAdapter`, `KnowledgeCoreRuntimeAdapterApplyResult`, fallback reasons, and the three adapter tests. Existing `KnowledgeCoreBridge` shadow runtime behavior remains unchanged.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-runtime-adapter-patch15 test -only-testing:EpistemosTests/KnowledgeCoreBridgeTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_runtime_adapter_patch15_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 10 tests passed
- manual test: none

Acceptance criteria:
- Flag off produces `.disabled` fallback and does not call the sink. Verified.
- A real document ingest drains an outline payload from the shared-memory bridge and applies it to the sink when `deterministicKnowledgeCoreRuntime` is enabled. Verified.
- Unsupported payload kinds produce `.unsupportedKind` fallback and do not call the sink. Verified.
- Production `QueryEngine`/SwiftUI state is not mutated by this patch. Verified by scope; next patch must wire a subscription-owned production sink before any end-to-end claim.

## Patch 16: Deterministic Runtime Subscription Binding

Priority:
P1

Status:
Completed on 2026-04-28. Focused `KnowledgeCoreBridgeTests` are green.

Goal:
Add a subscription-owned binding registry so deterministic runtime payloads cannot be applied to arbitrary sinks without matching the payload subscription ID.

Files:
- `Epistemos/Engine/KnowledgeCoreBridge.swift`
- `EpistemosTests/KnowledgeCoreBridgeTests.swift`

Change summary:
Extend adapter fallback reasons with `.unregisteredSubscription`, add a subscription filter to `KnowledgeCoreRuntimeAdapter`, and introduce `KnowledgeCoreRuntimeBinding` with register/unregister/apply APIs. Add tests proving real bridge payloads from two outline subscriptions apply only to the registered sink, and unregistered sinks fall back after removal.

Why:
The next production step needs explicit subscription ownership before touching `QueryEngine` or SwiftUI. Without this registry, the staged runtime could accidentally reintroduce broad invalidation by applying every drained payload to every active view model.

Risk:
Medium. Subscription gating is tested, but this patch still does not mutate production query/UI state. It is a necessary safety seam, not the final user-facing path.

Rollback:
Remove `KnowledgeCoreRuntimeBinding`, the adapter subscription filter, the `.unregisteredSubscription` fallback reason, and the two binding tests. Patch 15's simple flag-gated adapter can remain if needed.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-runtime-binding-patch16 test -only-testing:EpistemosTests/KnowledgeCoreBridgeTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_runtime_binding_patch16_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 12 tests passed
- manual test: none

Acceptance criteria:
- Real bridge payloads from two outline subscriptions are drained and only the registered subscription reaches the sink. Verified.
- Unregistering a subscription sink prevents later payload application. Verified.
- Unregistered payloads produce `.unregisteredSubscription` fallback. Verified.
- Production `QueryEngine`/SwiftUI state is still untouched. Verified by scope; next patch must create or attach a real production sink before claiming end-to-end runtime wiring.

## Patch 17: Deterministic Outline Projection UI Sink

Priority:
P1

Status:
Completed on 2026-04-28. Focused `KnowledgeCoreBridgeTests` are green.

Goal:
Attach the deterministic runtime substrate to a narrow user-facing note outline state without touching the protected Prose editor or replacing the existing Markdown fallback.

Files:
- `Epistemos/Views/Notes/NoteTableOfContents.swift`
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
- `EpistemosTests/KnowledgeCoreBridgeTests.swift`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Add `KnowledgeCoreOutlineProjectionState`, which is default-off through `EpistemosRuntimeFeatureFlags`, subscribes to a page outline through `KnowledgeCoreBridge`, applies drained payloads through `KnowledgeCoreRuntimeBinding`, and updates the note outline item state only after a real matching payload applies. `NoteDetailWorkspaceView` calls this path during its existing debounced metrics refresh when `deterministicKnowledgeCoreRuntime` is enabled; otherwise the existing `TOCParser` fallback remains unchanged. `TOCItem` equality now ignores the generated UUID so identical outline content does not republish just because a new identity was minted.

Why:
Patch 15 and Patch 16 proved adapter and subscription ownership contracts, but still stopped before a production view model. This patch creates the first end-to-end, user-facing seam: note body -> staged knowledge-core ingest -> outline subscription payload -> binding-owned sink -> existing note TOC state. It stays reversible and does not claim broader `QueryEngine`/search/list wiring.

Risk:
Medium. The path is behind an explicit default-off feature flag and has focused tests. When enabled, it ingests the current note body through a per-view bridge during the existing debounced metrics refresh, so it should remain experimental until p95 typing/metrics-refresh timing is measured on large notes.

Rollback:
Remove `KnowledgeCoreOutlineProjectionState`, remove the `deterministicOutlineState` state and refresh branch from `NoteDetailWorkspaceView`, revert `TOCItem` equality if needed, and remove the three new `KnowledgeCoreBridgeTests`. The default Markdown TOC parser remains available.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/KnowledgeCoreBridgeTests test CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_outline_projection_patch17_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 15 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_outline_projection_patch17.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- manual test: none

Acceptance criteria:
- The deterministic outline projection stays dormant when `deterministicKnowledgeCoreRuntime` is disabled. Verified.
- A real bridge outline payload must apply before `KnowledgeCoreOutlineProjectionState` updates TOC state. Verified.
- The note outline surface remains backed by Markdown fallback headings when the deterministic path is disabled or cannot apply. Verified by implementation scope.
- Protected Prose editor and graph renderer paths remain untouched. Verified by protected-path diff check.

## Patch 18: Borrowed Row Scalar Projection Gate

Priority:
P1

Status:
Completed on 2026-04-29 for the focused non-materialization gate. Focused `KnowledgeCoreBridgeTests` and fresh MAS build are green.

Goal:
Add a lifetime-contained borrowed-row projection path that reads FFI row slices while the ring slot is still valid, records scalar metadata/hashes/byte counts, and proves the path does not materialize Swift `String`s.

Files:
- `Epistemos/Engine/KnowledgeCoreBridge.swift`
- `EpistemosTests/KnowledgeCoreBridgeTests.swift`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`
- `docs/DETERMINISTIC_RUNTIME_V1_PREFLIGHT.md`

Change summary:
Add `KnowledgeCoreBorrowedRowProjection`, `KnowledgeCoreBorrowedPayloadProjection`, and `KnowledgeCoreBorrowedProjectionSnapshot`. Add `KnowledgeCoreBridge.drainBorrowedProjections(limit:)`, which projects row kind, IDs as stable hashes, byte counts, depth/ref/task scalars, and aggregate projected bytes without decoding row text into Swift `String`. The borrowed slices are consumed inside the actor drain before advancing the ring tail and do not escape as raw pointers. Add a focused test that ingests a real outline payload, drains scalar projections, proves two rows are projected, proves materialized string count is zero, and proves the tail advanced by checking a subsequent owned drain is empty.

Why:
The staged ring was already faster than full payload decode, but Swift still paid the materialization tax when it decoded full `KnowledgeCoreRowSnapshot` values. This patch creates a tested, conservative intermediate tier before any visible-row owned model work. It deliberately avoids claiming end-to-end zero-copy: the output owns scalar hashes/counts, not borrowed text pointers.

Risk:
Medium. The projection path touches FFI string slices, so it must stay narrow: no raw pointer escapes, no async boundary crossing, no UI storage of borrowed memory. The current patch satisfies that by copying only scalar metadata/hashes before tail advance. It is not yet wired to visible-row materialization or production lists.

Rollback:
Remove the borrowed projection DTOs, `drainBorrowedProjections`, helper projection functions, and the focused borrowed projection test. Existing `drainPayloads` and `drainProjectedSummaries` remain unchanged.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/KnowledgeCoreBridgeTests test CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_borrowed_projection_patch18_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 16 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_borrowed_projection_patch18.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- manual test: none

Acceptance criteria:
- Real bridge row slices are inspected before ring tail advance. Verified by focused bridge test.
- The borrowed projection path reports `materializedStringCount == 0`. Verified.
- Raw pointers do not escape the actor drain. Verified by code scope: the public projection types contain only hashes/counts/scalars.
- Subsequent owned drain is empty after borrowed drain, proving the borrowed path advanced the tail. Verified.
- This patch does not claim or provide visible/focused owned-row model materialization. Verified by scope.

## Patch 19: Local Stream EOF Flush Correctness

Priority:
P1

Status:
Completed on 2026-04-29. Focused local-agent tests and fresh MAS build are green.

Goal:
Verify and correct Claude's local-stream truncation fix so trailing tag-prefix plaintext is emitted to the UI at stream EOF without duplicating the final returned answer, while unterminated hidden reasoning/tool buffers stay hidden.

Files:
- `Epistemos/LocalAgent/IncrementalToolCallDetector.swift`
- `Epistemos/LocalAgent/LocalAgentLoop.swift`
- `EpistemosTests/IncrementalToolCallDetectorTests.swift`
- `EpistemosTests/LocalAgentLoopTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Keep `IncrementalToolCallDetector.flushOnStreamEnd()` as the EOF drain for held-back tag-prefix candidates, but remove the extra `accumulatedOutput.append(flushed)` in `LocalAgentLoop` because the raw stream chunk was already appended before detector processing. Add detector tests proving trailing `<` plaintext flushes, hidden `<think>` and malformed `<tool_call>` buffers drop, and a local-agent reflex test proving visible tokens and returned answer both contain the trailing `<` exactly once.

Why:
The handoff correctly identified the UI truncation path, but the first implementation over-appended the flushed suffix to `accumulatedOutput`. Without this correction the streaming UI would be fixed while the returned answer could contain duplicated trailing tag-prefix text.

Risk:
Low. The change is local to EOF handling when no tool-call detection occurred. Existing reflex/tool-call behavior remains covered by the same focused suite.

Rollback:
Remove the new tests and restore the previous EOF branch. This would reintroduce duplicated returned output if `flushOnStreamEnd()` remains active.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/IncrementalToolCallDetectorTests -only-testing:EpistemosTests/LocalAgentLoopTests test CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_local_stream_flush_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 53 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_local_stream_flush_patch19.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- manual test: deferred note-ask/local-model UI scenario

Acceptance criteria:
- Trailing tag-prefix plaintext is emitted at EOF. Verified.
- Unterminated hidden reasoning/tool buffers remain hidden. Verified.
- `LocalAgentLoop` returns the final answer without duplicated flushed suffix. Verified.
- Existing reflex tool-call cancellation behavior remains green in the focused suite. Verified.

## Patch 20: Static Artifact Routing Verification Gate

Priority:
P1

Status:
Completed on 2026-04-29 as a no-code verification slice. Existing typed route tests and source gates are green.

Goal:
Prove the existing artifact routing surface already uses compile-time `ArtifactKind`/`ArtifactRoute` coverage and does not reintroduce `AnyView` in production hot paths.

Files:
- `Epistemos/Models/ArtifactRoute.swift`
- `Epistemos/Views/Workspace/ArtifactHostView.swift`
- `EpistemosTests/ArtifactRouteTests.swift`
- `EpistemosTests/ArtifactKindParityTests.swift`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
No production code change. Verified that every current `ArtifactKind` lifts to a route, the `RawThought`/`Run` route collapse is intentional, route identity is stable for navigation, Swift/Rust artifact-kind parity is intact, `ArtifactHostView` uses an exhaustive `@ViewBuilder` switch, and production Swift contains no `AnyView(...)` constructions.

Why:
The deterministic-runtime static routing phase should not churn a system that is already closed, tested, and no-`AnyView`. The correct move is to prove the invariant and move on to higher-risk production wiring.

Risk:
Low. This is verification-only.

Rollback:
No rollback required; no production code changed.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ArtifactRouteTests -only-testing:EpistemosTests/ArtifactKindParityTests test CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_static_routing_patch20_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 10 tests passed
- command: `rg -n 'AnyView\\s*\\(' Epistemos --glob '*.swift'` -> `/tmp/epistemos_static_routing_anyview_gate.log`, `EXIT:0`, no production `AnyView(...)` constructions found
- command: source routing audit -> `/tmp/epistemos_static_routing_source_audit.log`, `EXIT:0`
- manual test: none

Acceptance criteria:
- Every `ArtifactKind` has a route. Verified.
- Route count and raw-thought/run sharing are explicit. Verified.
- Artifact host dispatch uses `@ViewBuilder` switch. Verified by source gate.
- Production code has no `AnyView(...)` constructions. Verified.

## Patch 21: Bound Sidecar Bulk Prefetch

Priority:
P1

Status:
Completed on 2026-04-29. Focused sidecar tests and fresh MAS build are green.

Goal:
Prevent Claude's AP7 sidecar startup warmup from turning a large vault into unbounded background disk work.

Files:
- `Epistemos/Engine/EpistemosSidecar.swift`
- `EpistemosTests/EpistemosSidecarTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
`EpistemosSidecarStore.prefetchAll(under:)` now accepts `maxSidecars`, defaulting to `SidecarCache.bound`, returns immediately for zero or negative limits, and stops enumeration once the bound is reached. Focused tests prove bounded warmup and zero-limit no-op behavior.

Why:
`SidecarCache` already capped memory at 4096 entries, but the startup prefetch still enumerated and attempted to read every sidecar file under the vault. That protected heap growth but not disk I/O, file enumeration time, or launch-adjacent background pressure on huge vaults.

Risk:
Low. Existing call sites keep the same API shape through the default argument, cache behavior remains LRU-bounded, and the change only short-circuits bulk prefetch work.

Rollback:
Remove the `maxSidecars` parameter, restore full enumeration, and remove the two focused tests. This would reintroduce unbounded sidecar disk warmup on large vaults.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-patch21 test -only-testing:EpistemosTests/EpistemosSidecarTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_sidecar_prefetch_patch21_tests.log`, `** TEST SUCCEEDED **`, 12 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-patch21-mas build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_sidecar_prefetch_patch21.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: protected-path diff check for ProseEditor and graph/Metal/Hologram paths -> empty
- manual test: deferred; launch-time large-vault Instruments proof remains a later gate

Acceptance criteria:
- Sidecar prefetch warms no more than the requested bound. Verified.
- Zero prefetch limit performs no disk reads through the prefetch loop. Verified.
- Existing App Store target still compiles with the defaulted API. Verified.

## Patch 22: Right-Side Code Gutter Visible-Range Proof

Priority:
P1

Status:
Completed on 2026-04-29. Focused code-editor policy tests and fresh MAS build are green.

Goal:
Prove the right-side code gutter draws only the viewport-sized line range for 4k-line files, without changing ProseEditor or claiming full runtime scroll/typing p95.

Files:
- `Epistemos/Views/Notes/CodeLineGutter.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Extracted the gutter dirty-rect-to-line-range calculation into `CodeLineGutterView.visibleLineRange(...)` and added a 4k-line policy test proving top and mid-file draws stay bounded to the visible viewport. Existing width/theme tests remain the guard for the subtle right-side UX.

Why:
The user explicitly wants line counts/right-side gutter behavior that does not fight the theme or hurt large-file fluidity. This patch turns the existing draw math into a testable invariant so the next performance work can focus on runtime typing/scroll p95 instead of rediscovering the gutter range contract.

Risk:
Low. Production draw behavior is unchanged except for moving the same calculation into a static helper, and the helper is covered by focused Swift Testing.

Rollback:
Inline the range calculation back into `draw(_:)` and remove the new visible-range test. This would remove the non-manual proof that gutter drawing is viewport-bounded.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-code-gutter-visible test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_code_gutter_visible_range_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 17 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-code-gutter-visible-mas build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_code_gutter_visible_range_patch22_rerun.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: protected-path diff check for ProseEditor and graph/Metal/Hologram paths -> empty
- manual test: deferred; full 4k-line scroll/typing p95 proof remains a later Instruments/runtime gate

Acceptance criteria:
- Gutter draw range is derived from dirty rect, scroll offset, top inset, and line height. Verified.
- A 4k-line file draws a viewport-sized range near the top and mid-file, not all lines. Verified.
- Existing App Store target still compiles. Verified.
- No ProseEditor or graph protected path changed. Verified.

## Patch 23: Code Editor Init Line Count Allocation Fix

Priority:
P1

Status:
Completed on 2026-04-29. Focused code-editor policy tests and fresh MAS build are green.

Goal:
Avoid allocating a full line array when opening or initializing large code files.

Files:
- `Epistemos/Views/Notes/CodeEditorView.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
`CodeEditorView.init` now seeds `totalLines` through `CodeEditorLineMetrics.lineCount(content)` instead of `content.components(separatedBy: "\n").count`. This reuses the same allocation-free LF scan used by edit-time line updates.

Why:
The code editor target includes smooth 4k-line file open and scroll behavior. Splitting the full file into an array just to initialize the line gutter is avoidable startup/open overhead.

Risk:
Low. The helper counts LF bytes, starts at one visual line for empty documents, and preserves the previous trailing-newline behavior.

Rollback:
Restore the previous initializer expression. This would reintroduce full-buffer line-array allocation on open.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-code-init-linecount-rerun test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_code_init_linecount_patch23_tests_rerun.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 17 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-code-init-linecount-mas build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_code_init_linecount_patch23.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: protected-path diff check for ProseEditor and graph/Metal/Hologram paths -> empty
- manual test: deferred; full 4k-line scroll/typing p95 proof remains a later Instruments/runtime gate

Acceptance criteria:
- Opening a code editor no longer allocates an array of all lines just to seed the gutter count. Verified by source.
- Existing line-count policy and gutter component tests remain green. Verified.
- Existing App Store target still compiles. Verified.
- No ProseEditor or graph protected path changed. Verified.

## Patch 24: Semantic Cluster Parallel Slot Safety

Priority:
P1

Status:
Completed on 2026-04-29. Focused semantic-cluster/runtime-policy tests and fresh MAS build are green.

Goal:
Remove the Swift 6 unsafe mutable-buffer capture warning from Claude's semantic-cluster parallel embedding path while preserving bounded parallel work.

Files:
- `Epistemos/Graph/SemanticClusterService.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Replaced `nonisolated(unsafe)` slot storage plus `withUnsafeMutableBufferPointer` capture inside `DispatchQueue.concurrentPerform` with a small explicitly `nonisolated` locked `SemanticEmbeddingSlots` accumulator. Added a source-policy test proving the semantic-cluster path no longer uses the unsafe mutable-buffer pattern.

Why:
Swift 6 correctly warned that the prior implementation captured a mutable `UnsafeMutableBufferPointer` in a concurrently executing `@Sendable` closure. That was a race/lifetime smell in production graph intelligence code, even if the build currently allowed it as a warning.

Risk:
Low. Parallel embedding computation remains parallel; only writes into the shared result slots are serialized through a lock. The result dictionary construction stays deterministic by using the original node order.

Rollback:
Restore the previous buffer-pointer implementation and remove the source-policy test. This would reintroduce the Swift 6 concurrency warning and the unsafe shared mutable buffer pattern.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-semantic-cluster-slots-rerun test -only-testing:EpistemosTests/SemanticClusterServiceTests -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_semantic_cluster_slots_patch24_rerun_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 20 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-semantic-cluster-slots-mas-rerun build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_semantic_cluster_slots_patch24_rerun.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: protected-path diff check for ProseEditor and graph/Metal/Hologram paths -> empty
- command: source grep for `withUnsafeMutableBufferPointer`, `nonisolated(unsafe) var slots`, and `UnsafeMutableBufferPointer` in `SemanticClusterService.swift` -> empty
- manual test: deferred; full graph/semantic clustering runtime p95 proof remains a later Instruments/runtime gate

Acceptance criteria:
- Semantic clustering no longer captures an unsafe mutable buffer in the concurrent path. Verified by source and test.
- Existing semantic-cluster behavior tests remain green. Verified.
- Existing App Store target still compiles. Verified.
- No ProseEditor or graph protected path changed. Verified.

## Patch 25: Vault FFI Sendable Shim Cleanup

Priority:
P2

Status:
Completed on 2026-04-29. Focused runtime-policy tests and fresh MAS build are green.

Goal:
Remove local redundant `@unchecked Sendable` conformances for generated FFI types from `VaultLifecycleService`.

Files:
- `Epistemos/Vault/VaultLifecycleService.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Removed four local `@unchecked Sendable` extensions for generated FFI types that already conform to `Sendable` in generated `agent_core.swift`, while keeping the compatibility typealiases used by the vault lifecycle code. Added a source-policy test preventing the local unchecked shims from returning.

Why:
The App Store build emitted redundant-conformance warnings from `VaultLifecycleService.swift`. Local unchecked conformances over generated FFI types increase concurrency-audit noise and can hide real Sendable issues.

Risk:
Low. The generated bindings already provide `Sendable` conformance for these types, and the patch does not change runtime behavior or vault lifecycle control flow.

Rollback:
Restore the four local extensions and remove the source-policy test. This would reintroduce the local redundant-conformance warnings.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-vault-ffi-sendable-patch25 test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_vault_ffi_sendable_patch25_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 19 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-vault-ffi-sendable-mas-patch25 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_vault_ffi_sendable_patch25.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: grep MAS log for `VaultFactFfi`, `ContradictionFfi`, `SessionFolderInfoFfi`, `SkillRegistryEntryFfi` local redundant warnings -> none
- command: protected-path diff check for ProseEditor and graph/Metal/Hologram paths -> empty

Acceptance criteria:
- `VaultLifecycleService` no longer adds unchecked Sendable conformances for generated FFI types. Verified.
- Focused runtime policy tests remain green. Verified.
- Existing App Store target still compiles. Verified.
- No ProseEditor or graph protected path changed. Verified.

## Patch 26: Local LSP and Speech Warning Cleanup

Priority:
P2

Status:
Completed on 2026-04-29. Focused runtime-policy tests and fresh MAS build are green.

Goal:
Remove two local Swift warning sources from the App Store build without changing LSP routing behavior or speech capture behavior.

Files:
- `Epistemos/Engine/LSPClient.swift`
- `Epistemos/Engine/EpistemosSpeechAnalyzer.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Removed redundant `await` markers around synchronous actor helper calls inside `LSPClient.startRouting()`. Captured `EpistemosSpeechAnalyzer`'s logger before installing the route-change observer so the `@Sendable` notification closure no longer references a MainActor-isolated static property.

Why:
The MAS build still emitted local warnings for redundant `await` expressions in `LSPClient.swift` and a Sendable/MainActor logger capture in `EpistemosSpeechAnalyzer.swift`. These were warning-noise issues, but cleaning local warnings keeps the release audit focused on real remaining risks.

Risk:
Low. `routeIncoming(_:)` and `failAllPending(_:)` remain actor-isolated calls executed from the same actor task, and route-change logging still uses the same `Logger` value.

Rollback:
Restore the previous `await` markers and direct `Self.log.info` call inside the observer closure. This would reintroduce the local warnings.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-lsp-speech-warnings-patch26 test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_lsp_speech_warnings_patch26_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 21 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-lsp-speech-warnings-mas-patch26 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_lsp_speech_warnings_patch26.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: grep MAS/test logs for the old LSP redundant-await warning and speech logger Sendable warning -> none
- command: protected-path diff check for ProseEditor and graph/Metal/Hologram paths -> empty

Acceptance criteria:
- `LSPClient.startRouting()` no longer awaits synchronous actor helper calls. Verified by source, source-policy test, and MAS log grep.
- `EpistemosSpeechAnalyzer.observeRouteChanges(_:)` no longer references `Self.log` from inside the `@Sendable` observer closure. Verified by source, source-policy test, and MAS log grep.
- Existing App Store target still compiles. Verified.
- No ProseEditor or graph protected path changed. Verified.

## Patch 27: Epdoc WebKit Process-Pool Deprecation Cleanup

Priority:
P2

Status:
Completed on 2026-04-29. Source gate and fresh MAS build are green.

Goal:
Remove deprecated `WKProcessPool` usage from `.epdoc` WebView surfaces while preserving the local/non-persistent editor loading model.

Files:
- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`
- `Epistemos/Views/Epdoc/EpdocKaTeXPreview.swift`
- `Epistemos/App/EpistemosApp.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Removed the shared `WKProcessPool` singleton and all `configuration.processPool` assignments from `.epdoc` editor/preview WebViews. Replaced the memory-pressure diagnostic that previously claimed to reset an idle process pool with an honest `webViewIdle` signal based on live `.epdoc` WebView count. Kept `WKWebsiteDataStore.nonPersistent()`, custom-scheme loading, and WebView teardown behavior intact.

Why:
Current WebKit marks `WKProcessPool` and `WKWebViewConfiguration.processPool` deprecated because multiple process pools no longer provide the old isolation/reset semantics. Keeping it produced local MAS deprecation warnings and made the memory-pressure path overclaim what it could actually release.

Risk:
Low. WebView configuration still uses the same non-persistent data store and resource-loading policy; only the deprecated no-longer-effective process-pool hook was removed.

Rollback:
Restore `EpdocWebViewShared.processPool`, the `config.processPool` assignments, and `resetPoolIfIdle()`. This would reintroduce the deprecation warnings and stale memory-pressure semantics.

Verification:
- command: source gate for `WKProcessPool(`, `.processPool`, and `resetPoolIfIdle` in patched surfaces -> `/tmp/epistemos_webkit_processpool_patch27_source_gate.log`, `EXIT:0`
- command: narrow Swift Testing selector for the source-policy test -> `/tmp/epistemos_webkit_processpool_patch27_narrow_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, but selected 0 tests; not counted as behavioral proof
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-webkit-processpool-mas-patch27 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_webkit_processpool_patch27.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: grep MAS log for the old `EpdocEditorChromeView`/`EpdocKaTeXPreview` `WKProcessPool`/`processPool` deprecation warnings -> none
- command: protected-path diff check for ProseEditor and graph/Metal/Hologram paths -> empty

Acceptance criteria:
- `.epdoc` WebView surfaces no longer use deprecated WebKit process-pool APIs. Verified by source gate and MAS warning grep.
- `.epdoc` WebViews still use non-persistent website data stores. Verified by source review.
- Memory-pressure metadata no longer claims a process-pool reset; it reports whether `.epdoc` WebViews are idle. Verified by source gate.
- Existing App Store target still compiles. Verified.
- No ProseEditor or graph protected path changed. Verified.

## Patch 28: CoreSpotlight Async Indexing Cleanup

Priority:
P2

Status:
Completed on 2026-04-29. Source gate and fresh MAS build are green.

Goal:
Remove local CoreSpotlight "consider using asynchronous alternative function" warnings from note/vault indexing paths without changing the public indexing call sites.

Files:
- `Epistemos/Engine/SpotlightIndexer.swift`
- `Epistemos/Sync/VaultIndexActor.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Replaced callback-based `CSSearchableIndex.default().indexSearchableItems(...)` calls in the local Spotlight indexer and vault reindex path with the async throwing CoreSpotlight API. Existing error logging is preserved, and the public synchronous `SpotlightIndexer.index(_:)` entry still schedules the work through its existing task boundary. Added a source-policy test preventing the callback API from returning in these hot indexing surfaces.

Why:
The MAS build still emitted local CoreSpotlight warnings for `SpotlightIndexer.swift` and `VaultIndexActor.swift`. Using the async API keeps indexing work out of callback-style legacy APIs, reduces release warning noise, and preserves the existing off-call-site scheduling model.

Risk:
Low. The indexing batch contents and logging behavior are unchanged; only the CoreSpotlight call style changed from callback to async/await.

Rollback:
Restore the callback-based `indexSearchableItems` calls and remove the source-policy test. This would reintroduce the local CoreSpotlight warnings.

Verification:
- command: source gate for async CoreSpotlight calls and absence of callback patterns -> `/tmp/epistemos_spotlight_async_indexing_patch28_source_gate.log`, `EXIT:0`
- command: narrow Swift Testing selector for the source-policy test -> `/tmp/epistemos_spotlight_async_indexing_patch28_narrow_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, but selected 0 tests; counted only as build/sanity proof
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-spotlight-async-mas-patch28 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_spotlight_async_patch28.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: targeted grep for the old `SpotlightIndexer.swift`/`VaultIndexActor.swift` CoreSpotlight async-alternative warnings -> no matches
- command: protected-path diff check for ProseEditor and graph/Metal/Hologram paths -> empty

Acceptance criteria:
- Local Spotlight indexing paths use the async CoreSpotlight indexing API. Verified by source gate.
- The old local CoreSpotlight async-alternative warnings are gone from a fresh MAS build. Verified by targeted warning grep.
- Existing App Store target still compiles. Verified.
- No ProseEditor or graph protected path changed. Verified.

## Patch 29: Hologram Overlay Animation Completion Sendable Cleanup

Priority:
P2

Status:
Completed on 2026-04-29. Focused runtime-policy tests and fresh MAS build are green.

Goal:
Remove local Swift 6 Sendable warnings from Hologram overlay animation completion helper calls without changing graph renderer, physics, Metal, or Hologram controller behavior.

Files:
- `Epistemos/Views/Graph/HologramOverlay.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Changed the two private `HologramOverlay` animation helper completion parameters from plain escaping closures to `@Sendable` closures so they can be passed through `NSAnimationContext.runAnimationGroup` without local Sendable diagnostics. Hardened the runtime-policy source tests to read from the bundled `SourceMirror` instead of `#filePath`/`~/Downloads` repo paths after the focused test host wedged while reading a source file under the Downloads TCC surface.

Why:
The MAS build still emitted local warnings at `HologramOverlay.swift` for passing a non-Sendable `completion` parameter into a `@Sendable` animation-completion closure. The first verification run also exposed a real test-harness fragility: source-policy tests that read directly from the checkout under `~/Downloads` can hang under xcodebuild, so those checks now use the existing mirrored source bundle.

Risk:
Low. The change only tightens private helper closure types and keeps all call-site behavior on the same animation paths. The test-harness change follows the repo's existing `SourceMirrorTestSupport` pattern and does not affect production code.

Rollback:
Restore the helper completion parameters to plain closures and restore the source-policy tests' direct `#filePath` repo reads. This would reintroduce the Hologram Sendable warnings and the source-read hang risk.

Verification:
- command: source gate for Hologram helper signatures -> `/tmp/epistemos_hologram_completion_patch29_source_gate.log`, `EXIT:0`
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-hologram-completion-patch29-test3 test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_hologram_completion_patch29_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 24 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-hologram-completion-mas-patch29 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_hologram_completion_patch29.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: targeted grep for the old `HologramOverlay.swift` Sendable completion warnings -> no matches
- command: protected-path diff check for ProseEditor, MetalGraphView, and HologramController paths -> empty

Acceptance criteria:
- Hologram overlay animation helper completions are `@Sendable`. Verified by source and runtime-policy test.
- The old local Hologram Sendable completion warnings are gone from a fresh MAS build. Verified by targeted warning grep.
- Runtime-policy source tests no longer read repo sources through `#filePath` from `~/Downloads`. Verified by source grep and focused test.
- Existing App Store target still compiles. Verified.
- No ProseEditor, MetalGraphView, or HologramController protected path changed. Verified.

## Patch 30: Unicode-Safe Code Inspector Highlighting Chunks

Priority:
P1

Status:
Completed on 2026-04-29. Focused runtime-policy tests and fresh MAS build are green.

Goal:
Remove the remaining Unicode crash/performance risk in graph-inspector code preview/editor syntax highlighting by chunking on Swift `String.Index` boundaries while preserving UTF-8 byte offsets for token spans.

Files:
- `Epistemos/Views/Notes/CodeEditorView.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Added `CodeSyntaxChunker.utf8AlignedChunks(in:maxBytes:)`, which emits UTF-8-budgeted chunks that start and end on Swift character boundaries and records the matching UTF-8 lower/upper offsets. `CodeSyntaxHighlighter.applyChunked(...)` now slices chunks by `Range<String.Index>`, prepares tokens/spans on a utility-priority detached task, and applies only color attributes on the main actor. The old `offsetBy: chunk.start/end` byte-as-character indexing path is gone. Added policy tests for Unicode-heavy chunk continuity and source proof that chunk prep is Unicode-safe/off-main.

Why:
The user asked for Xcode-like 4k-line code fluidity. The earlier gutter/line-count patches handled visible-range drawing and open-time line counting, but this inspector highlighter still treated UTF-8 byte offsets as Swift character offsets. Unicode-heavy code previews could trap or mis-highlight, and token/span prep was more main-actor-heavy than needed.

Risk:
Medium-low. The main `CodeEditSourceEditor` live editor stack is unchanged; this patch affects the legacy/inspector highlighter path inside `CodeEditorView.swift`. The patch intentionally applies foreground color only in the chunked path, matching the existing token color behavior but not adding font styling. Full runtime typing/scroll p95 proof remains open.

Rollback:
Restore the old stride-based UTF-8 chunk tuple slicing and remove `CodeSyntaxChunker` plus the new tests. This would reintroduce the Unicode byte-offset indexing risk and heavier main-actor chunk prep.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-code-syntax-chunker-patch30 test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_code_syntax_chunker_patch30_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 26 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-mas-code-syntax-chunker-patch30 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_code_syntax_chunker_patch30.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: `git diff --check` for patched files -> clean
- command: protected-path diff check for ProseEditor, MetalGraphView, and HologramController paths -> empty
- command: source grep for `offsetBy: chunk.start`, `offsetBy: chunk.end`, `TokenAttributes`, and `computeTokenAttributes` -> no matches

Acceptance criteria:
- Unicode-heavy syntax chunks preserve contiguous Swift character ranges while tracking correct UTF-8 byte offsets. Verified by runtime-policy test.
- Chunk tokenization/span preparation runs off the main actor before main-actor attribute application. Verified by source-policy test and build.
- Old byte-offset `String.index(offsetBy:)` chunk slicing is absent. Verified by source grep.
- Existing App Store target still compiles. Verified.
- No ProseEditor, MetalGraphView, or HologramController protected path changed. Verified.

## Patch 31: Epdoc Legacy Options Warning Cleanup

Priority:
P2

Status:
Completed on 2026-04-29. Focused `.epdoc` property tests and fresh MAS build are green.

Goal:
Remove local MAS build warnings from the `.epdoc` legacy options migration path without changing canonical `options_v2` writes or legacy JSON import behavior.

Files:
- `Epistemos/Engine/EpdocProperty.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Moved the legacy `[String]` options storage to a private `legacyOptions` field and kept the deprecated public `options` compatibility accessor as a computed property. Internal init/decode/effective-option reads now use the private backing field, so the file no longer triggers its own deprecation warnings. Encoding still emits only canonical `options_v2`, and legacy input still auto-migrates through `effectiveOptions`.

Why:
After Patch 30, the only local non-generated MAS warnings were the intentional `.epdoc` decode-only `options` deprecation warnings. The migration behavior was correct, but warning on the implementation's own decode path made the release log noisier than necessary.

Risk:
Low. The public deprecated accessor still exists for compatibility, while Codable behavior is custom and remains covered by existing `.epdoc` property tests.

Rollback:
Restore `public let options: [String]?` as the stored property and update internal reads to use it. This would reintroduce the local deprecation warnings.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-epdoc-options-warning-patch31 test -only-testing:EpistemosTests/EpdocPropertyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_epdoc_options_warning_patch31_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 15 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-mas-epdoc-options-warning-patch31 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_epdoc_options_warning_patch31.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: targeted grep for `EpdocProperty.swift`/`Use optionsV2` warnings in the fresh MAS log -> no matches
- command: protected-path diff check for ProseEditor, MetalGraphView, and HologramController paths -> empty

Acceptance criteria:
- Legacy `options` JSON still decodes and migrates to deterministic `PropertyOption` values. Verified by existing `.epdoc` property tests.
- Re-encoding legacy data emits `options_v2` and drops legacy `options`. Verified by existing `.epdoc` property tests.
- Fresh MAS build no longer emits local `EpdocProperty.swift` deprecation warnings. Verified by log grep.
- Existing App Store target still compiles. Verified.
- No ProseEditor, MetalGraphView, or HologramController protected path changed. Verified.

## Patch 32: UniFFI Sendable Warning Patcher Cleanup

Priority:
P2

Status:
Completed on 2026-04-29. Patcher gate and fresh MAS build are green.

Goal:
Remove generated `agent_core.swift` redundant `Sendable` warnings at the generation-patcher layer without hand-editing generated Swift bindings.

Files:
- `patch-uniffi-bindings.py`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Changed the UniFFI Swift patcher so it no longer injects inline `: Sendable` conformances into `AgentConfigFfi`, `ToolConfig`, `ReasoningTrajectoryMetricsFfi`, or `AgentResultFfi` when UniFFI already emits `extension Type: Sendable {}`. The patcher also cleans previously patched generated files idempotently by removing those inline conformances only when the generated extension exists.

Why:
After Patch 31, the remaining local/generated warning noise was the generated `agent_core.swift` redundant-conformance class. Hand-editing `build-rust/swift-bindings/agent_core.swift` would be brittle because Xcode regenerates it; the durable fix belongs in `patch-uniffi-bindings.py`.

Risk:
Low. The generated `Sendable` extension remains the single conformance source, so the affected value types keep their sendability while avoiding duplicate declarations.

Rollback:
Restore the previous patcher loop that injects inline `: Sendable` on those four generated structs. This would reintroduce the redundant-conformance warnings.

Verification:
- command: `python3 patch-uniffi-bindings.py build-rust/swift-bindings/agent_core.swift` -> current generated binding retains only `extension Type: Sendable {}` for the four affected types
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-uniffi-sendable-patch32 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_uniffi_sendable_patch32.log`, `** BUILD SUCCEEDED **`, Codex tool process exited 0; note the command footer used a zsh-incompatible `PIPESTATUS` expression and printed a blank `EXIT:`
- command: `/tmp/epistemos_uniffi_sendable_patch32_gate.log` -> `EXIT:0`, redundant generated `Sendable` warning search found none; remaining warnings are upstream MLX C++17 diagnostics
- command: `git diff --check -- patch-uniffi-bindings.py` -> clean
- command: protected-path diff check for ProseEditor, MetalGraphView, and HologramController paths -> empty

Acceptance criteria:
- The patcher no longer adds duplicate inline `Sendable` conformances when UniFFI already generated a `Sendable` extension. Verified by generated binding grep.
- Fresh MAS build no longer emits generated `agent_core.swift` redundant `Sendable` warnings. Verified by `/tmp/epistemos_uniffi_sendable_patch32_gate.log`.
- Existing App Store target still compiles. Verified.
- No generated binding was hand-edited as the durable fix; only the source patcher changed. Verified by git status.
- No ProseEditor, MetalGraphView, or HologramController protected path changed. Verified.

## Patch 33: Lazy AppBootstrap Startup Call-Site Enforcement

Priority:
P1

Status:
Completed on 2026-04-29. Focused runtime-policy tests and fresh MAS build are green.

Goal:
Keep Claude's startup-memory lazy-init refactor honest by removing call sites that still eagerly construct cloud knowledge distillation or computer-use services during `AppBootstrap` initialization.

Files:
- `Epistemos/App/AppBootstrap.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Changed the NightBrain cloud-knowledge job closure from an eager capture of `cloudKnowledgeDistillationService` to a weak `self` capture that resolves the lazy service on the main actor only when the job executes. Removed eager `screenCapture` and `screen2AXFusion` arguments from `orchestratorState.registerAgents(...)`; the current `registerAgents` implementation does not use those optional services, so passing them only defeated the lazy computer-use chain. Added runtime-policy source tests that lock both invariants.

Why:
The handoff claimed `noteInsightService`, `cloudKnowledgeDistillationService`, and the computer-use chain were lazy, but source audit found two startup call sites that still forced construction. That erased part of the App Store idle-memory win and made the launch path carry computer-use/cloud-vault work before the user asked for it.

Risk:
Low. The NightBrain job still builds and runs the same cloud knowledge service when invoked, and the computer-use services remain accessible through their lazy getters for actual computer-use/ambient-capture paths. `OrchestratorState.registerAgents(...)` currently ignores the removed optional arguments.

Rollback:
Restore the eager NightBrain capture and pass `screenCapture`/`screen2AXFusion` into `registerAgents(...)`. This would reintroduce startup allocation and should only be done if a real call site proves it needs eager construction.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-lazy-bootstrap-patch33 test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_lazy_bootstrap_patch33_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 28 runtime-policy tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-mas-lazy-bootstrap-patch33 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_lazy_bootstrap_patch33.log`, `** BUILD SUCCEEDED **`, Codex tool process exited 0; note the command footer used a zsh-incompatible `PIPESTATUS` expression and printed a blank `EXIT:`
- command: `/tmp/epistemos_lazy_bootstrap_patch33_gate.log` -> focused tests, MAS build marker, eager NightBrain capture absence, and old `registerAgents` eager argument pair absence all `PASS`
- command: protected-path diff check for ProseEditor, MetalGraphView, and HologramController paths -> empty
- command: `git diff --check` for patched source/docs -> clean after final verification

Acceptance criteria:
- NightBrain no longer captures `cloudKnowledgeDistillationService` eagerly during `AppBootstrap` initialization. Verified by runtime-policy source test.
- `AppBootstrap` no longer passes `screenCapture: screenCapture` and `perception: screen2AXFusion` into the currently no-op `registerAgents(...)` path. Verified by runtime-policy source test.
- Existing App Store target still compiles. Verified.
- No ProseEditor, MetalGraphView, or HologramController protected path changed. Verified.

## Patch 34: MLX Idle Unload Depth Split

Priority:
P1

Status:
Completed on 2026-04-29. Focused runtime/Metal tests and fresh MAS build are green.

Goal:
Preserve the startup/runtime memory win from MLX unload handling without forcing a full Metal pipeline/archive teardown on routine idle unloads.

Files:
- `Epistemos/Engine/MLXInferenceService.swift`
- `EpistemosTests/RuntimeValidationTests.swift`
- `EpistemosTests/Mamba2MetalRuntimeTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Split MLX Metal runtime unloads into two explicit depths. Routine idle unload now releases only the working set, while explicit user unload, critical memory pressure, and critical thermal pressure still perform a deep unload that drops cached Metal pipeline/archive state. Added source-policy coverage for the mode split and a Metal runtime test proving `deepUnload()` is idempotent and clears runtime allocations.

Why:
Claude's perf sprint made every MLX unload call `MetalRuntimeManager.deepUnload()`. That is correct for critical pressure but too aggressive for normal idle gaps because it can trade a short idle memory win for a 200-500 ms warm-path recompile/rebuild tax on the next inference. Idle should free model working memory without discarding reusable Metal pipeline/archive state.

Risk:
Low to medium. The behavior intentionally keeps Metal pipeline/archive caches alive after ordinary idle unload, so idle memory relief is smaller than a deep unload. Critical pressure and explicit unload still preserve the full deep-release behavior.

Rollback:
Change idle unload back to `performUnload(metalRuntimeUnloadMode: .deep)` and remove the unload-depth enum/tests. This restores maximum idle release but reintroduces the warm-path recompile risk.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-mlx-unload-depth-patch34-focused test -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/Mamba2MetalRuntimeTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mlx_unload_depth_patch34_tests_final.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 256 tests passed across 2 suites
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-mas-mlx-unload-depth-patch34 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_mlx_unload_depth_patch34.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: `/tmp/epistemos_mlx_unload_depth_patch34_gate.log` -> focused tests, MAS build, idle working-set-only source gate, and critical/explicit deep-unload source gate all `PASS`
- command: protected-path diff check for ProseEditor, MetalGraphView, and HologramController paths -> empty

Acceptance criteria:
- Routine MLX idle unload releases only Metal working-set state, not all pipelines/archive state. Verified by source-policy test and source gate.
- Explicit unload and critical pressure/thermal paths still deep-unload the Metal runtime. Verified by source-policy test and source gate.
- `MetalRuntimeManager.deepUnload()` is safe to call repeatedly and clears runtime allocations. Verified by `Mamba2MetalRuntimeTests`.
- Existing App Store target still compiles. Verified.
- No ProseEditor, MetalGraphView, or HologramController protected path changed. Verified.

## Patch 35: Epdoc JS Brotli Transfer Assets

Priority:
P1

Status:
Completed on 2026-04-29. Focused bridge tests, AppStore and normal Debug bundle-script gates, and fresh MAS build are green.

Goal:
Reduce `.epdoc` editor transfer/load overhead in the App Store target without adding a new JS dependency or changing the WKWebView editor architecture.

Files:
- `build-tiptap-bundle.sh`
- `js-editor/webpack.config.js`
- `Epistemos/Engine/EpdocEditorBridge.swift`
- `EpistemosTests/EpdocEditorBridgeTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
Added a dependency-free webpack Brotli transfer asset plugin for production JS/CSS assets and changed the Xcode bundle script so it stages production editor assets by default for a stable app resource graph. Development bundles now require explicit `EPISTEMOS_TIPTAP_DEVELOPMENT=1`. The `.epdoc` URL scheme handler now resolves `.js`/`.mjs`/`.css` requests to matching `.br` transfer assets when present, preserves the original MIME type, and sets `Content-Encoding: br`. The resolver rejects path traversal and keeps fallback behavior for uncompressed assets.

Why:
The `.epdoc` editor bundle was being staged as a large development bundle in App Store build checks because `build-tiptap-bundle.sh` keyed only off `CONFIGURATION=Debug`. That also made normal Xcode Debug resources diverge from the MAS resource shape. Serving precompressed production editor assets by default is a conservative first slice that reduces delivered editor bytes and keeps Xcode app resources stable without code splitting, dynamic import risk, or a new compression dependency.

Risk:
Low to medium. The bridge relies on WebKit honoring `Content-Encoding: br` on `WKURLSchemeHandler` responses. If `.br` assets are missing, the resolver falls back to the original uncompressed asset. This patch intentionally does not attempt lazy KaTeX/Mermaid chunks or tree-shaking beyond the existing production webpack build.

Rollback:
Remove `BrotliTransferAssetsPlugin`, restore `build-tiptap-bundle.sh` to Debug-equals-development, and remove `.br` preference/header logic from `EpdocEditorAssetResolver`. This restores the prior uncompressed asset path.

Verification:
- command: `TARGET_NAME=Epistemos-AppStore CONFIGURATION=Debug bash build-tiptap-bundle.sh` -> `/tmp/epistemos_tiptap_appstore_brotli_patch35_script.log`, `webpack --mode production --mode production`, `.br` assets emitted, `EXIT:0`
- command: `TARGET_NAME=Epistemos CONFIGURATION=Debug bash build-tiptap-bundle.sh` -> `/tmp/epistemos_tiptap_debug_brotli_patch35_script.log`, `webpack --mode production --mode production`, `.br` assets emitted, `EXIT:0`
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-epdoc-brotli-patch35 test -only-testing:EpistemosTests/EpdocEditorBridgeTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_epdoc_brotli_patch35_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 17 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-mas-epdoc-brotli-patch35 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_epdoc_brotli_patch35.log`, `** BUILD SUCCEEDED **`, `EXIT:0`, AppStore target ran webpack in production mode and emitted `.br` assets
- command: `/tmp/epistemos_epdoc_brotli_patch35_gate.log` -> AppStore script, staged assets, bridge tests, MAS production bundle, and built-app `.br` checks all `PASS`
- command: built app resource check -> `/tmp/epistemos-dd-mas-epdoc-brotli-patch35/Build/Products/Debug/Epistemos.app/Contents/Resources/editor.js.br` and `editor.css.br` exist

Acceptance criteria:
- Xcode builds stage production `.epdoc` editor assets by default even when the scheme build action reports `CONFIGURATION=Debug`; development bundles require explicit `EPISTEMOS_TIPTAP_DEVELOPMENT=1`. Verified.
- Production editor JS/CSS emit matching `.br` transfer assets. Verified.
- The built App Store app contains `editor.js.br` and `editor.css.br`. Verified.
- The URL scheme resolver prefers `.br` for JS/CSS, preserves MIME type, sets Brotli encoding, rejects traversal, and falls back to uncompressed assets. Verified by focused bridge tests.
- No code-splitting/lazy-chunk claims are made by this patch. Verified by implementation scope.

## Patch 36: SSM Sidecar Compressed Context Persistence

Priority:
P1

Status:
Completed on 2026-04-29. Focused sidecar tests, source gate, stable bundle-script gate, and fresh MAS build are green.

Goal:
Replace the documented `SSMMemorySidecar.persistState()` stub with a narrow compressed-context persistence path so warm-resume state can survive app restarts without making SSM cache state canonical user data.

Files:
- `Epistemos/Engine/SSMMemorySidecar.swift`
- `Epistemos/Vault/SSMStateService.swift`
- `EpistemosTests/SSMMemorySidecarTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
`SSMMemorySidecar.persistState(modelID:sessionID:)` now writes the latest compressed context through `SSMStateService` when the service is active and a compressed context exists. `SSMStateService` now saves, loads, and discovers latest compressed-context JSON snapshots under `ssm_cache/<model>/compressed_context/` using sanitized path components and atomic writes.

Why:
The sidecar already maintained compressed-context state in memory, but persistence was a stub. That made warm-resume impossible across restarts and left a high-value performance feature documented but not real. This patch wires the smallest safe path: context snapshots are cache artifacts, not canonical user documents, and inactive/no-context cases remain no-ops.

Risk:
Low to medium. The cache files are derived runtime state and can be discarded. The main risks are path hygiene and accidental writes while inactive; both are covered by focused tests. This does not claim full SSM warm-start orchestration or model-quality validation.

Rollback:
Restore `persistState` to a no-op, remove the compressed-context APIs from `SSMStateService`, and remove the focused tests. That loses restart warm-resume persistence but does not affect canonical vault data.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-ssm-sidecar-persist-patch36 test -only-testing:EpistemosTests/SSMMemorySidecarTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_ssm_sidecar_persist_patch36_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 12 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-mas-ssm-sidecar-persist-patch36 build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_ssm_sidecar_persist_patch36.log`, `** BUILD SUCCEEDED **`, `EXIT:0`, CodeEdit SwiftLint plugin tail noise did not change exit status
- command: `/tmp/epistemos_ssm_sidecar_persist_patch36_gate.log` -> focused tests, MAS build, stub removal, compressed-context API presence, and stable Debug bundle checks all `PASS`

Acceptance criteria:
- `persistState` writes a compressed-context snapshot only when SSM state service is active and a compressed context exists. Verified by focused tests.
- Snapshot load/discovery round-trips model ID, session ID, context, format version, and state tracking. Verified by focused tests.
- Neighboring session names do not satisfy latest-context discovery by prefix accident. Verified by focused regression test.
- Inactive service and missing-context cases do not write cache files. Verified by focused tests.
- Writes are atomic and path components are sanitized. Verified by source and focused tests.
- No canonical vault data or ProseEditor/graph protected paths are touched. Verified by scope and protected-path checks.

## Patch 37: SpeechAnalyzer Live Dictation Crash Guard

Priority:
P0

Status:
Completed on 2026-04-29. Focused runtime-policy tests, crash-pattern source gate, and fresh MAS build are green.

Goal:
Remove the live dictation crash path seen in local crash reports by using SpeechAnalyzer's live-stream start API without double-binding the same input stream.

Files:
- `Epistemos/Engine/EpistemosSpeechAnalyzer.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
`EpistemosSpeechAnalyzer.startLive(onModelDownload:)` now constructs `SpeechAnalyzer(modules: [transcriber])` and starts the live `AnalyzerInputSequence` with `try await analyzer.start(inputSequence: inputStream)`. The previous code passed the same stream into the initializer and then into `analyzeSequence(inputStream)`, matching the crash stack in the latest local `Epistemos-2026-04-29-075435.ips` and `Epistemos-2026-04-29-075001.ips` reports.

Why:
Live dictation is user-facing through `VoiceInputButton`. A normal voice workflow was able to crash on a cooperative background thread inside `EpistemosSpeechAnalyzer.startLive`. The fix follows the SDK live-stream shape and keeps the app from double-consuming the same async input sequence.

Risk:
Low to medium. The patch changes the SpeechAnalyzer invocation path for live capture only. It does not change microphone permissions, audio capture buffering, transcript handling, ProseEditor, or graph code. Runtime microphone smoke is still a manual/deferred gate, so this is a crash-signature/source/build proof rather than a full dictation-quality proof.

Rollback:
Restore the previous `SpeechAnalyzer(inputSequence:modules:)` plus `analyzeSequence(inputStream)` call shape and remove the policy test. That is not recommended unless Apple changes the SDK contract or this path is proven incompatible in runtime mic smoke.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_speech_analyzer_crash_patch37_tests_ctki_cache.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 29 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_speech_analyzer_crash_patch37.log`, `** BUILD SUCCEEDED **`, `EXIT:0`, CodeEdit SwiftLint plugin tail noise did not change exit status
- command: `/tmp/epistemos_speech_analyzer_crash_patch37_gate.log` -> focused policy tests, MAS build, and source crash-pattern removal all `PASS`

Acceptance criteria:
- Live analyzer construction does not pass `inputSequence: inputStream` to the initializer. Verified by focused source-policy test and gate.
- Live analyzer execution uses `start(inputSequence: inputStream)`, not `analyzeSequence(inputStream)`. Verified by focused source-policy test and gate.
- App Store target compiles after the speech patch. Verified by fresh MAS build.
- ProseEditor and graph protected paths remain untouched. Verified by protected-path diff checks.

## Patch 38: Raw Thoughts Inspector Bounded Event Tail

Priority:
P1

Status:
Completed on 2026-04-29. Focused RawThoughtsState tests, source/test gate, and fresh MAS build are green.

Goal:
Prevent verbose Raw Thoughts runs from loading and publishing an entire high-rate `events.jsonl` file into SwiftUI state when the inspector opens.

Files:
- `Epistemos/Views/RawThoughts/RawThoughtsInspectorView.swift`
- `EpistemosTests/RawThoughtsStateTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
`RawThoughtsInspectorView.loadRunArtifacts(folderURL:)` now reads event logs through a bounded tail helper instead of `String(contentsOf:)` over the whole file. The helper reads at most 256 KiB from the end of `events.jsonl`, drops the first partial line when tailing from the middle of a file, and returns at most 500 visible event lines. Tests prove partial final JSONL recovery still works and synthetic 750-event logs publish only the final bounded tail.

Why:
Raw Thoughts storage/provider recovery was already proven, but opening a verbose run could still allocate and publish every event line into `@State`, creating a quiet App Store performance and memory cliff. The inspector should remain read-only and cheap even when a model/tool run emitted a lot of observable events.

Risk:
Low. This changes inspector presentation only; canonical Raw Thoughts logs remain append-only on disk. Very old event lines are no longer shown in the first inspector view for very large logs, but the full `events.jsonl` remains available through "Reveal in Finder" and can support a fuller paged viewer later.

Rollback:
Restore the prior `String(contentsOf:)` + full `.split(...).map(String.init)` path and remove the tail helper/tests. This would reintroduce the full-log SwiftUI materialization risk and is not recommended.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl test -only-testing:EpistemosTests/RawThoughtsStateTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_raw_thoughts_tail_patch38_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 16 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_raw_thoughts_tail_patch38.log`, `** BUILD SUCCEEDED **`, `EXIT:0`, CodeEdit SwiftLint plugin tail noise did not change exit status
- command: `/tmp/epistemos_raw_thoughts_tail_patch38_gate.log` -> focused tests, MAS build, bounded tail source, and regression-test presence all `PASS`

Acceptance criteria:
- Inspector loading no longer reads the entire `events.jsonl` into a Swift `String` before publishing UI rows. Verified by source gate.
- Inspector publishes no more than `RawThoughtsInspectorView.maxVisibleEventLines` rows for high-rate logs. Verified by focused test.
- Partial final JSONL lines remain visible so active/running logs do not appear empty or truncated at the end. Verified by focused test.
- Tailing from the middle of a file does not render a partial first line. Verified by focused test.
- App Store target compiles after the Raw Thoughts inspector patch. Verified by fresh MAS build.

## Patch 39: Voice Input Pulse Timeline Gate

Priority:
P1

Status:
Completed on 2026-04-29. Focused runtime-policy tests, source gate, and fresh MAS build are green.

Goal:
Remove the remaining `.repeatForever` animation from the user-facing dictation button and replace it with the repo-standard bounded `TimelineView` pulse gated by Reduce Motion and window occlusion.

Files:
- `Epistemos/Views/Shared/VoiceInputButton.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
`VoiceInputButton` no longer drives the recording ring with `.repeatForever`. The `.iconWithPulse` recording affordance now uses `TimelineView(.animation(minimumInterval: 1.0 / 30.0))` only while visible, pauses to a static ring when `accessibilityReduceMotion` is enabled or `UIState.windowOccluded` is true, and the preview explicitly injects `UIState`.

Why:
The Engineering Bible calls out `.repeatForever` as a known idle CPU anti-pattern. Dictation is user-facing and adjacent to the live SpeechAnalyzer crash fixed in Patch 37, so its visual state should follow the same bounded-animation contract as the rest of the native UI.

Risk:
Low. The patch changes the recording pulse driver only. It does not change dictation permissions, audio capture, transcript handling, chat input routing, ProseEditor, graph code, or speech analyzer lifecycle.

Rollback:
Restore the prior `.animation(.easeOut(...).repeatForever(...), value: phase)` ring and remove the source-policy test. This is not recommended because it reintroduces the known continuous-animation anti-pattern.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_voice_input_pulse_patch39_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 30 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_voice_input_pulse_patch39.log`, `** BUILD SUCCEEDED **`, `EXIT:0`, CodeEdit SwiftLint plugin tail noise did not change exit status
- command: `/tmp/epistemos_voice_input_pulse_patch39_gate.log` -> focused tests, MAS build, `repeatForever` removal, and TimelineView/reduce-motion/window-occlusion source gates all `PASS`

Acceptance criteria:
- `VoiceInputButton.swift` contains no `.repeatForever` pulse loop. Verified by source gate.
- The recording pulse uses a bounded `TimelineView` cadence. Verified by source-policy test and source gate.
- The pulse pauses for Reduce Motion and window occlusion. Verified by source-policy test and source gate.
- App Store target compiles after the dictation pulse patch. Verified by fresh MAS build.

## Patch 40: Code Editor Initial Gutter Line Count

Priority:
P1

Status:
Completed on 2026-04-29. Focused runtime-policy tests, source gate, protected-path invariant check, and fresh MAS build are green.

Goal:
Make the right-side code line gutter show the correct line count as soon as the AppKit editor surface is installed, not only after the first edit or scroll update.

Files:
- `Epistemos/Views/Notes/CodeEditorView.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
`applyGutterPreferences()` now immediately forwards the SwiftUI-owned `totalLines` and `cursorLine` state into the coordinator after installing/configuring the right-side gutter. The coordinator exposes `applyLineGutterState(totalLines:cursorLine:)`, which updates the gutter's line count and active line without waiting for a later text-change path.

Why:
The right-side line count was already performance-bounded for 4k-line files, but the AppKit coordinator's `lastTotalLines` started at `0`. A freshly opened code file could therefore install a blank/right-side gutter until a later text-change or layout event called `updateGutterLineCount`. That is user-facing polish debt in the code editor path the user specifically wants to feel Xcode-fluid and stable.

Risk:
Low. This patch only applies existing line-count state to the already-created gutter. It does not touch ProseEditor, TextKit prose surfaces, graph rendering, syntax parsing, LSP routing, or code editor scroll physics.

Rollback:
Remove `applyLineGutterState(totalLines:cursorLine:)` and the call from `applyGutterPreferences()`, then remove the source-policy regression test. This would reintroduce the initial blank-gutter risk and is not recommended.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_code_gutter_initial_count_patch40_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 31 tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_code_gutter_initial_count_patch40.log`, `** BUILD SUCCEEDED **`, `EXIT:0`, CodeEdit SwiftLint plugin tail noise did not change exit status
- command: `/tmp/epistemos_code_gutter_initial_count_patch40_gate.log` -> focused tests, MAS build, initial-gutter source shape, regression-test presence, and protected path diff all `PASS`

Acceptance criteria:
- The coordinator applies the initial `totalLines` immediately after gutter setup. Verified by source-policy test and source gate.
- The active cursor line is also forwarded during initial gutter setup. Verified by source-policy test and source gate.
- ProseEditor and graph protected paths remain untouched. Verified by gate.
- App Store target compiles after the code gutter patch. Verified by fresh MAS build.

## Patch 41: App Store NightBrain Scheduler And LaunchAgent Gate

Priority:
P1

Status:
Completed on 2026-04-29. Focused release-packaging tests, source/bundle gate, protected-path invariant check, and fresh MAS build are green.

Goal:
Keep NightBrain's direct-build LaunchAgent scheduler out of the App Store launch path and out of the App Store app bundle.

Files:
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos.xcodeproj/project.pbxproj`
- `EpistemosTests/ProductionHardeningTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`
- `docs/audits/PRIVACY_APP_STORE_AUDIT.md`

Change summary:
`AppBootstrap` now wraps both `NightBrainScheduler.register()` and `NightBrainScheduler.shouldRunFallbackInline()` behind `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`. The App Store target's project exception list now excludes `Resources/LaunchAgents/com.epistemos.nightbrain.plist` from the MAS bundle while leaving direct-build resources unchanged. Release packaging tests lock both source gates and the App Store resource exception.

Why:
`NightBrainService.start()` was already App Store-gated, but the launch scheduler and LaunchAgent resource still leaked into the App Store surface. Runtime gating alone is not enough for MAS review hygiene: App Store builds should not attempt LaunchAgent registration at startup, and the direct-build LaunchAgent plist should not be present in the MAS app bundle.

Risk:
Low for App Store. The patch only removes direct-build NightBrain scheduler surfaces from the MAS profile. Direct/debug builds still compile the scheduler path. The direct/debug missing-helper registration noise found during this audit is handled separately by Patch 42.

Rollback:
Remove the `AppBootstrap` compile-time gates and remove the App Store target exception for `Resources/LaunchAgents/com.epistemos.nightbrain.plist`. This is not recommended because it reintroduces MAS launch and bundle review risk.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl test -only-testing:EpistemosTests/ReleasePackagingHardeningTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_nightbrain_mas_scheduler_patch41_tests_rerun.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 18 Swift Testing tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_nightbrain_scheduler_patch41_rerun.log`, `** BUILD SUCCEEDED **`, `EXIT:0`, CodeEdit SwiftLint plugin tail noise did not change exit status
- command: `/tmp/epistemos_nightbrain_mas_scheduler_patch41_gate.log` -> focused tests, MAS build, MAS LaunchAgent stale-file removal, no MAS LaunchAgent plist copy, source gates, and protected path diff all `PASS`

Acceptance criteria:
- `AppBootstrap` does not register NightBrain LaunchAgents in App Store or sandbox builds. Verified by source-policy test and source gate.
- `AppBootstrap` does not run the NightBrain fallback inline path in App Store or sandbox builds. Verified by source-policy test and source gate.
- The App Store bundle does not copy `Resources/LaunchAgents/com.epistemos.nightbrain.plist`. Verified by fresh MAS build log and no-copy gate.
- ProseEditor and graph protected paths remain untouched. Verified by gate.
- App Store target compiles after the NightBrain scheduler/bundle gate. Verified by fresh MAS build.

## Patch 42: Direct NightBrain Missing Helper Guard

Priority:
P2

Status:
Completed on 2026-04-29. Focused release-packaging tests, direct launch-log gate, source gate, protected-path invariant check, and fresh MAS build are green.

Goal:
Prevent direct/debug launches from logging a scary NightBrain `SMAppService` registration failure when the direct-build helper target/plist bundle path has not been packaged yet.

Files:
- `Epistemos/State/NightBrainScheduler.swift`
- `EpistemosTests/ProductionHardeningTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
`NightBrainScheduler.register()` now checks whether `com.epistemos.nightbrain.plist` is actually bundled at `Contents/Library/LaunchAgents` before reading `SMAppService.agent.status` or attempting registration. If the helper/plist is not packaged, the scheduler logs a quiet informational skip and returns. Release-packaging tests lock the bundle-path helper and the guard ordering.

Why:
The direct LaunchAgent contract is still partially staged: the plist expects `Contents/MacOS/NightBrainHelper`, and `SMAppService.agent(plistName:)` expects the plist under `Contents/Library/LaunchAgents`. Test-host launches showed `NightBrain LaunchAgent register failed` even though the app could continue. That noise looked like a launch regression and obscured real failures. The scheduler should only ask ServiceManagement to register once the required bundle contract exists.

Risk:
Low. This does not register, unregister, or run NightBrain differently when the helper plist is correctly bundled. It only converts the missing-helper-packaging state into an explicit skip. The real helper target/copy phase remains future direct-distribution work.

Rollback:
Remove `bundledLaunchAgentURL`, `bundledLaunchAgentExists`, and the pre-registration guard. This would reintroduce direct/debug startup registration-failure noise when the helper is absent.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl test -only-testing:EpistemosTests/ReleasePackagingHardeningTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_nightbrain_direct_missing_helper_patch42_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 18 Swift Testing tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_nightbrain_direct_missing_helper_patch42.log`, `** BUILD SUCCEEDED **`, `EXIT:0`, CodeEdit SwiftLint plugin tail noise did not change exit status
- command: `/tmp/epistemos_nightbrain_direct_missing_helper_patch42_gate.log` -> focused tests, direct missing-helper log, old failure absence, MAS build, no MAS LaunchAgent plist copy, source gates, and protected path diff all `PASS`

Acceptance criteria:
- Missing direct NightBrain helper/plist packaging does not produce `NightBrain LaunchAgent register failed` during test-host launch. Verified by log gate.
- `NightBrainScheduler.register()` checks the bundle-path contract before reading `agent.status`. Verified by source-policy test and source gate.
- App Store target still compiles after the direct scheduler guard. Verified by fresh MAS build.
- MAS still does not copy the direct-build NightBrain LaunchAgent plist. Verified by gate.
- ProseEditor and graph protected paths remain untouched. Verified by gate.

## Patch 43: Performance Instrumentation Test Warning Cleanup

Priority:
P2

Status:
Completed on 2026-04-29. Focused App Store hardening and Performance.instrpkg tests are green, and the targeted test warning is gone.

Goal:
Remove a Swift test-target warning from the Performance.instrpkg verifier without changing the instrumentation package contract.

Files:
- `EpistemosTests/PerformanceInstrPkgTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`

Change summary:
`PerformanceInstrPkgTests` now decodes the non-optional `errData` value directly instead of applying `?? Data()` to a non-optional `Data`.

Why:
The S.6 privacy/settings gate pulled in `PerformanceInstrPkgTests` and exposed a local warning at line 74. Warnings in test infrastructure make real regression logs noisier and are worth removing when the fix is mechanical and low risk.

Risk:
Very low. This is test-only cleanup. It does not change production code, Settings UI, privacy wording, entitlements, graph, ProseEditor, instrumentation schema, or build scripts.

Rollback:
Restore `String(data: errData ?? Data(), encoding: .utf8) ?? ""`. This is not recommended because it reintroduces a known warning.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/PerformanceInstrPkgTests -only-testing:EpistemosTests/AppStoreHardeningTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_privacy_manifest_and_instrpkg_warning_patch43_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 25 Swift Testing tests passed
- command: `rg -n "PerformanceInstrPkgTests\\.swift:74|errData \\?\\? Data\\(\\)" /tmp/epistemos_privacy_manifest_and_instrpkg_warning_patch43_tests.log` -> no matches
- command: `git diff --check -- EpistemosTests/PerformanceInstrPkgTests.swift ...` -> `DIFF_CHECK_EXIT:0`

Acceptance criteria:
- `PerformanceInstrPkgTests.swift` no longer emits the non-optional nil-coalescing warning at line 74. Verified by log grep.
- App Store privacy manifest tests still pass. Verified by `AppStoreHardeningTests` entries in the focused log.
- Performance.instrpkg XML/category tests still pass. Verified by focused test log.
- The patch is test-only and leaves protected ProseEditor/graph paths untouched.

## Patch 44: Tiptap Editor Bundle Prune And Canonical Resource Tree

Priority:
P1

Status:
Completed on 2026-04-29. Focused bridge/script tests, shell syntax checks, fresh MAS build, and built-app bundle resource gates are green.

Goal:
Keep the `.epdoc` Tiptap editor payload small and make the App Store bundle preserve the canonical `Contents/Resources/Editor` tree expected by `EpdocEditorAssetResolver`.

Files:
- `build-tiptap-bundle.sh`
- `bundle-app-runtime-assets.sh`
- `EpistemosTests/EpdocEditorBridgeTests.swift`
- `EpistemosTests/ReleaseScriptAuditTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`
- `docs/audits/PRIVACY_APP_STORE_AUDIT.md`

Change summary:
Production editor bundles now prune plain JS/CSS counterparts when matching `.br` transfer assets exist and remove KaTeX `.ttf`/`.woff` files, keeping WOFF2. The runtime asset bundler now copies `Epistemos/Resources/Editor` into `Contents/Resources/Editor` and removes root-level flattened editor duplicates that Xcode resource copying can leave behind. Tests cover Brotli-only asset resolution and the runtime asset bundler's canonical editor tree behavior.

Why:
Patch 35 added Brotli assets but still left duplicate uncompressed JS/CSS and older font formats in the source resource tree. A fresh MAS build also exposed a real runtime packaging bug: Xcode flattened `Epistemos/Resources/Editor` files into `Contents/Resources`, while `EpdocEditorAssetResolver` expects `Bundle.main.resourceURL/Editor`. This patch fixes both the storage overhead and the built-app resource path.

Risk:
Medium-low. The `.epdoc` editor must be served through the app URL scheme handler so `Content-Encoding: br` is honored for compressed JS/CSS. The patch keeps `editor.html` and WOFF2 fonts uncompressed for normal WebKit loading and leaves development bundles available through `EPISTEMOS_TIPTAP_DEVELOPMENT=1`. It does not lazy-load KaTeX/Mermaid, tree-shake Tiptap extensions, or change WebView/editor logic.

Rollback:
Remove `prune_production_editor_bundle`, stop calling `bundle_editor_resources`, and restore the previous flat resource-copy behavior. This is not recommended because it reintroduces duplicate payload bytes and the built-app `Editor` directory absence.

Verification:
- command: `bash -n build-tiptap-bundle.sh && bash -n bundle-app-runtime-assets.sh` -> `/tmp/epistemos_tiptap_bundle_prune_patch44_bash_n.log`, `BASH_N_EXIT:0`
- command: `TARGET_NAME=Epistemos-AppStore CONFIGURATION=Debug bash build-tiptap-bundle.sh` -> `/tmp/epistemos_tiptap_bundle_prune_patch44_script_bash.log`, `EXIT:0`
- command: focused `EpdocEditorBridgeTests` and `ReleaseScriptAuditTests` -> `/tmp/epistemos_tiptap_bundle_prune_patch44_tests_rerun.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 43 Swift Testing tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_tiptap_bundle_prune_patch44_rerun.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: `/tmp/epistemos_tiptap_bundle_prune_patch44_gate.log` -> `GATE_EXIT:0`, built app has `Contents/Resources/Editor`, no root-level editor duplicates, no `.ttf`/`.woff`, no plain JS/CSS counterparts for `.br` assets

Acceptance criteria:
- Source `Epistemos/Resources/Editor` is pruned to 1.1M and contains only Brotli JS/CSS transfer assets, `editor.html`, Mermaid license text, and KaTeX WOFF2 fonts. Verified by gate.
- Built `Epistemos.app/Contents/Resources/Editor` exists and is also 1.1M. Verified by fresh MAS build gate.
- Built app root resources no longer contain flattened `editor*`, `katex*`, `mermaid*`, or `KaTeX_*` editor duplicates. Verified by gate.
- The `.epdoc` bridge can serve a Brotli-only production asset with `Content-Encoding: br`. Verified by focused bridge test.
- Lazy chunking/tree-shaking remains unimplemented and must not be claimed.

## Patch 46: Code Editor Indentation Guide Single-Pass Refresh

Priority:
P1

Status:
Completed on 2026-04-29. Runtime-policy suite, source gate, protected-path check, and fresh MAS build are green.

Goal:
Remove avoidable full-buffer line splitting and per-line trimming from the code editor indentation-guide refresh path for 4k-line files.

Files:
- `Epistemos/Views/Notes/SegmentedIndentationGuideView.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`
- `docs/audits/PERFORMANCE_CONCURRENCY_AUDIT.md`

Change summary:
`SegmentedIndentationGuideView.updateFromText` now uses a single-pass UTF-8 parser to compute line indentation, content presence, block starts/ends, y positions, and max indent. The parser avoids `components(separatedBy: .newlines)`, avoids `trimmingCharacters(in: .whitespaces)`, handles CR/LF/CRLF, and reserves bounded capacity. A runtime-policy test locks the source shape and a 4k-line refresh component budget.

Why:
The code editor target is smooth 4k-line open/scroll/typing with the right-side gutter and syntax colors enabled. Splitting the entire file into an array and trimming every line for an auxiliary indentation overlay is avoidable hot-path overhead.

Risk:
Low to medium. This changes indentation-guide parsing only. It does not touch ProseEditor internals, code editor text storage, syntax highlighting, LSP routing, graph rendering, or graph physics. The parser intentionally preserves the old ASCII block-marker behavior for common code delimiters; non-ASCII source text remains safe because indentation/block markers are derived from bytes only after whitespace scanning.

Rollback:
Restore the prior `components(separatedBy: .newlines)` implementation. This is not recommended because it reintroduces full-line array allocation on large buffers.

Verification:
- command: `rg -n "components\\(separatedBy: \\.newlines\\)|trimmingCharacters\\(in: \\.whitespaces\\)" Epistemos/Views/Notes/SegmentedIndentationGuideView.swift` -> no matches
- command: focused selector attempt -> `/tmp/epistemos_code_indent_guide_patch46_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, selected 0 tests; compile/host evidence only, not behavior proof
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-code-indent-guide-patch46-dd2 test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_code_indent_guide_patch46_suite_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 32 Swift Testing tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_code_indent_guide_patch46.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: protected-path diff check for `Epistemos/Views/Notes/ProseEditor*.swift`, `MetalGraphView.swift`, and `HologramController.swift` -> empty

Acceptance criteria:
- Indentation-guide refresh no longer splits the full source text into an array of lines. Verified by source gate and runtime-policy test.
- A 4k-line source buffer can refresh indentation guides 20 times under the component budget. Verified by `RuntimeCapabilityAndPerformancePolicyTests`.
- App Store target still builds after the parser change. Verified by fresh MAS build.
- ProseEditor and graph UI protected paths remain untouched. Verified by protected-path diff.
- Full Xcode-like 4k-line typing/scroll p95 remains unclaimed until a runtime/Instruments gate exists.

## Patch 47: SpeechAnalyzer Best-Compatible Format Guard

Priority:
P0

Status:
Completed on 2026-04-29. Runtime-policy suite, source gate, protected-path check, and fresh MAS build are green. Runtime microphone smoke remains deferred.

Goal:
Remove the remaining live dictation crash risk where Speech.framework traps after `start(inputSequence:)` by ensuring mic buffers are converted into SpeechAnalyzer's preferred analysis format before they are yielded.

Files:
- `Epistemos/Engine/EpistemosSpeechAnalyzer.swift`
- `Epistemos/Views/Shared/VoiceInputButton.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/audits/CRASH_REGRESSION_TRIAGE_2026_04_29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/STABILITY_ERROR_HANDLING_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`

Change summary:
`EpistemosSpeechAnalyzer.startLive` now asks `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:considering:)` for the analyzer format, prepares the analyzer with `prepareToAnalyze(in:)`, and runs live input through a small `SpeechAnalyzerAudioBufferConverter` before yielding `AnalyzerInput`. The raw input-node mic buffer is no longer yielded directly. If no compatible format or converter exists, the voice input UI shows a specific unavailable-format error instead of falling into a generic failure.

Why:
Patch 37 removed the double-bound input-stream shape, but the fresh Apr 29 crash reports still faulted inside the Speech framework live start path. The SDK exposes explicit APIs for choosing and preparing the analysis format, and the app was previously feeding the analyzer raw mic-tap buffers without conversion. Live dictation is user-facing, so this stays in the P0 crash-hardening lane.

Risk:
Medium. The patch changes only live speech capture format preparation/conversion and error reporting. It does not touch transcript merging, microphone permissions, ProseEditor, graph rendering, graph physics, or model routing. It allocates converted audio buffers per tap only when the mic format differs from the analyzer format. Runtime mic smoke is still required before claiming dictation is fully shipped.

Rollback:
Restore direct `AnalyzerInput(buffer: buffer)` yielding and remove the converter/test gates. This is not recommended because it reintroduces the crash-risk shape identified from local crash reports.

Verification:
- command: first focused test attempt -> `/tmp/epistemos_speech_format_patch47_tests.log`, failed before useful compile evidence because of disk pressure and a shell wrapper bug using zsh's read-only `status` variable
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_speech_format_patch47_tests_rerun.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 32 Swift Testing tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_speech_format_patch47.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: `/tmp/epistemos_speech_format_patch47_gate.log` -> `GATE_EXIT:0`, best-compatible-format source shape present, raw production buffer yield absent, user-visible unavailable-format error present, diff check clean, protected ProseEditor/graph paths untouched

Acceptance criteria:
- Live SpeechAnalyzer setup uses `bestAvailableAudioFormat(compatibleWith:considering:)` and `prepareToAnalyze(in:)`. Verified by source gate and runtime-policy test.
- Mic buffers are converted before yielding when the input format differs from the analyzer format. Verified by source gate and runtime-policy test.
- Production source no longer yields raw `AnalyzerInput(buffer: buffer)` from the mic tap. Verified by source gate.
- App Store target compiles after the speech patch. Verified by fresh MAS build.
- ProseEditor and graph UI protected paths remain untouched. Verified by protected-path diff.
- Full live microphone quality/permissions smoke remains unclaimed until a runtime gate exists.

## Patch 48: SpeechAnalyzer Audio-Tap Actor-Isolation Guard

Priority:
P0

Status:
Completed on 2026-04-29. Runtime-policy suite, source gate, protected-path check, and fresh MAS build are green. Runtime microphone smoke remains deferred.

Goal:
Remove the newer live dictation crash where the AVAudio tap callback tripped Swift concurrency isolation by reaching into the `@MainActor` analyzer instance from a realtime audio queue.

Files:
- `Epistemos/Engine/EpistemosSpeechAnalyzer.swift`
- `EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift`
- `docs/audits/CRASH_REGRESSION_TRIAGE_2026_04_29.md`
- `docs/audits/BUILD_TEST_VERIFICATION_AUDIT.md`
- `docs/audits/STABILITY_ERROR_HANDLING_AUDIT.md`
- `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md`
- `docs/audits/PATCH_QUEUE.md`
- `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`

Change summary:
The `installTap` callback now yields through the local `inputCont` captured when the `AsyncStream` is created. It no longer captures `self` or reads `self?.inputContinuation?.yield(input)` from the audio callback.

Why:
`Epistemos-2026-04-29-183409.ips` faulted in `_swift_task_checkIsolatedSwift` with the app frame `closure #3 in EpistemosSpeechAnalyzer.startLive(onModelDownload:)`. That points at actor-isolated state access from the audio tap queue. The `AsyncStream` continuation is already available as a local sendable-ish callback value and does not require crossing back through the `@MainActor` instance.

Risk:
Low. The patch changes only the audio-tap yield target. `stopInternal()` still finishes `inputContinuation`, which finishes the same stream continuation; the callback no longer has to read the instance property. It does not change audio format conversion, transcript handling, permissions, ProseEditor, graph rendering, or graph physics.

Rollback:
Restore `self?.inputContinuation?.yield(input)` in the tap closure. This is not recommended because it reintroduces the concurrency-isolation crash signature.

Verification:
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_speech_tap_isolation_patch48_tests.log`, `** TEST SUCCEEDED **`, `EXIT:0`, 32 Swift Testing tests passed
- command: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` -> `/tmp/epistemos_mas_build_after_speech_tap_isolation_patch48.log`, `** BUILD SUCCEEDED **`, `EXIT:0`
- command: `/tmp/epistemos_speech_tap_isolation_patch48_gate.log` -> `GATE_EXIT:0`, production source uses `inputCont.yield(input)`, production source no longer uses `self?.inputContinuation?.yield`, diff check is clean, and protected ProseEditor/graph paths are untouched

Acceptance criteria:
- AVAudio tap callback does not access `self?.inputContinuation` from the realtime audio queue. Verified by source gate and runtime-policy test.
- App Store target compiles after the patch. Verified by fresh MAS build.
- ProseEditor and graph UI protected paths remain untouched. Verified by protected-path diff.
- Full live microphone quality/permissions smoke remains unclaimed until a runtime gate exists.
