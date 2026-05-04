# Build/Test/CI Verification Audit

Date: 2026-04-28

Verdict: Latest known Pro/MAS builds and targeted tests are green for the currently audited P0/P1 slices, including a fresh MAS unsafe-surface binary audit. This report does not claim final release readiness because manual-only Phase S gates are intentionally deferred per user instruction.

## Commands Run

| Command/log | Result | Notes |
|---|---|---|
| `/tmp/epistemos_round2_build.log` | `** BUILD SUCCEEDED **` | Pro build evidence from the current audit chain |
| `/tmp/epistemos_round2_mas_build.log` | `** BUILD SUCCEEDED **` | MAS build evidence from the current audit chain |
| `/tmp/epistemos_round2b_ascii_cleanup_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 19 tests passed | Targeted Settings/privacy cleanup tests |
| `/tmp/epistemos_raw_thoughts_cargo.log` | `EXIT:0`, 11 tests passed | Rust Raw Thoughts storage and provider-surface tests |
| `/tmp/epistemos_raw_thoughts_patch5_cargo.log` | `EXIT:0`, 12 tests passed | Rust Raw Thoughts storage tests, including `redacted_thinking` byte-preservation count |
| `/tmp/epistemos_claude_provider_redacted_thinking_tests.log` | `EXIT:0`, 12 tests passed | Claude provider parsing/serialization for `redacted_thinking` content blocks |
| `/tmp/epistemos_agent_core_patch5_full.log` | `EXIT:0`, full suite passed | Full `agent_core` verification: 774 lib tests plus bin/e2e/doc-test pass |
| `/tmp/epistemos_raw_thoughts_state_patch5_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 14 tests passed | Swift RawThoughtsState and inspector partial-final-line JSONL recovery |
| `/tmp/epistemos_code_editor_patch6_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 35 tests passed | Code editor policy/polish/highlighter focused suite; includes 4k-line line-metric component gate, right-side gutter width/theme tests, and SwiftTreeSitter Unicode mapping coverage |
| `/tmp/epistemos_derived_store_patch7_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 21 tests passed | ReadableBlocksIndex + GraphStore focused proof: typed artifact/block search hits, stable-ID title/path replacement, delete-to-FTS cleanup, graph remove-node adjacency cleanup |
| `/tmp/epistemos_readable_blocks_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 14 tests passed | ReadableBlocksIndex row store, FTS, fallback search, and artifact-kind round trip |
| `/tmp/epistemos_focused_audit_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 49 tests passed | Settings, Raw Thoughts state, `.epdoc` Info.plist/controller/FTS bridge, Instant Recall |
| `/tmp/epistemos_epdoc_projection_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 33 tests passed | `.epdoc` canonical source-of-truth, regenerated `shadow.md`, `plain.txt`, `search_blocks.jsonl`, FTS bridge, projector whitespace normalization |
| `/tmp/epistemos_contextual_shadows_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 11 tests passed | Contextual Shadows V0 flag behavior, cancellation, stale-result clearing, note-only V0 result classification |
| `/tmp/epistemos_contextual_shadows_wiring_audit.log` | `EXIT:0` | Source proof that chat and note workspaces mount `ContextualShadowsButton`/`ContextualShadowsPanel` and wire open routing |
| `/tmp/epistemos_instant_recall_async_guard_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 18 tests passed | Instant Recall async rebuild behavior, lazy hydration, stale-result clearing, metrics |
| `/tmp/epistemos_instant_recall_source_gate.log` | `EXIT:0` | Sync vault-wide rebuild/indexBatch APIs are unavailable and no production sync callers were found |
| `/tmp/epistemos_tcc_hardening_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 0 selected tests executed | Xcode `-only-testing` selector did not match Swift Testing suite; not counted as behavioral proof |
| `/tmp/epistemos_mas_tcc_source_gate.log` | `EXIT:0` | Verified MAS branches in `OmegaPermissions.swift` and `TCCPermissionState.swift` omit ScreenCaptureKit/Apple Events symbols |
| `/tmp/epistemos_mas_tcc_build.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after MAS TCC/Omega permission gating |
| `/tmp/epistemos_mas_build_after_epdoc_projection.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after `.epdoc` projection/source-of-truth patch |
| `/tmp/epistemos_mas_build_after_contextual_shadows.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after Contextual Shadows V0 user-surface wiring |
| `/tmp/epistemos_mas_build_after_instant_recall_async_guard.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after Instant Recall async-only rebuild guard |
| `/tmp/epistemos_mas_build_after_raw_thoughts_patch5.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after Raw Thoughts provider-surface/recovery patch |
| `/tmp/epistemos_mas_build_after_code_editor_patch6.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after code-editor line metrics/gutter component gate |
| `/tmp/epistemos_pro_build_patch8_refresh.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh Pro build after Patches 5-7; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_mas_build_patch8_refresh.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after Patches 5-7; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_deterministic_phase0_knowledge_core.log` | `EXIT:0`, 23 passed, 5 ignored | Deterministic runtime Phase 0 Rust `knowledge_core` baseline |
| `/tmp/epistemos_deterministic_phase0_ring.log` | `EXIT:0`, 6 passed, 1 ignored | Deterministic runtime Phase 0 ring baseline |
| `/tmp/epistemos_deterministic_phase0_summary_bench.log` | `EXIT:0`, `speedup_x=6.00` | Knowledge-core payload summary accessor ignored benchmark |
| `/tmp/epistemos_deterministic_phase0_rows_bench.log` | `EXIT:0`, `speedup_x=3.20` | Knowledge-core payload rows batch accessor ignored benchmark |
| `/tmp/epistemos_deterministic_phase0_swift_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 32 tests passed | Focused `KnowledgeCoreBridgeTests` and `QueryRuntimeTests` baseline |
| `/tmp/epistemos_deterministic_phase1_store_tests.log` | `EXIT:0`, 9 passed, 1 ignored | Deterministic runtime Phase 1 store tests for real mutation-envelope emission paths |
| `/tmp/epistemos_deterministic_phase1_knowledge_core.log` | `EXIT:0`, 29 passed, 5 ignored | Broader Rust `knowledge_core` suite after typed mutation envelopes |
| `/tmp/epistemos_deterministic_phase2_store_tests.log` | `EXIT:0`, 17 passed, 1 ignored | Deterministic runtime Phase 2 store tests for query fingerprints, watch plans, and mutation/watch intersection |
| `/tmp/epistemos_deterministic_phase2_knowledge_core.log` | `EXIT:0`, 37 passed, 5 ignored | Broader Rust `knowledge_core` suite after watch-plan substrate |
| `/tmp/epistemos_runtime_flags_patch14_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 16 tests passed | Runtime capability policy tests proving deterministic-runtime feature flags are default-off and explicit opt-ins |
| `/tmp/epistemos_runtime_adapter_patch15_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 10 tests passed | KnowledgeCoreBridge tests proving the deterministic runtime adapter remains flag-gated, applies real outline payloads to a sink when enabled, and falls back for unsupported payload kinds |
| `/tmp/epistemos_runtime_binding_patch16_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 12 tests passed | KnowledgeCoreBridge tests proving subscription-owned runtime binding applies only registered subscription payloads and falls back after unregister |
| `/tmp/epistemos_outline_projection_patch17_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 15 tests passed | KnowledgeCoreBridge tests proving the feature-flagged deterministic outline projection consumes real bridge payloads through subscription binding before updating note TOC state |
| `/tmp/epistemos_mas_build_after_outline_projection_patch17.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after feature-flagged deterministic outline projection wiring; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_borrowed_projection_patch18_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 16 tests passed | KnowledgeCoreBridge tests proving scalar borrowed-row projection inspects row slices before tail advance without materializing Swift strings |
| `/tmp/epistemos_mas_build_after_borrowed_projection_patch18.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after borrowed-row scalar projection; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_local_stream_flush_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 53 tests passed | Focused detector/local-agent tests proving stream-EOF tag-prefix flush, hidden/tool buffer privacy, and no duplicated returned answer |
| `/tmp/epistemos_mas_build_after_local_stream_flush_patch19.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after local-stream EOF correction; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_agent_core_perf_handoff_lib_tests.log` | `EXIT:0`, 774 tests passed | Rust `agent_core --lib` verification after Claude's perf sprint changes, including bounded shared memory/session pruning and memory-pressure bridge code |
| `/tmp/epistemos_shadow_perf_handoff_lib_tests.log` | `EXIT:0`, 45 passed, 5 ignored | Rust `epistemos-shadow --lib` verification after Tantivy heap tuning and doc-test cleanup |
| `/tmp/epistemos_static_routing_patch20_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 10 tests passed | ArtifactKind parity and ArtifactRoute compile-time routing coverage |
| `/tmp/epistemos_static_routing_anyview_gate.log` | `EXIT:0` | Source gate found no production `AnyView(...)` constructions |
| `/tmp/epistemos_static_routing_source_audit.log` | `EXIT:0` | Source audit captured `ArtifactRoute` mapping and `ArtifactHostView` exhaustive `@ViewBuilder` switch |
| `/tmp/epistemos_mas_tcc_binary_audit.log` | passed | No ScreenCaptureKit/AXorcist/omega_ax links or bundle paths; no dangerous `libomega_mcp` process/PTY symbols; only `tree-sitter-python` grammar resource matched `python` |
| `/tmp/epistemos_code_gutter_visible_range_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 17 tests passed | Runtime capability/code-editor policy tests proving right-side gutter visible-range calculation stays viewport-bounded for 4k-line files |
| `/tmp/epistemos_mas_build_after_code_gutter_visible_range_patch22_rerun.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after gutter visible-range helper/test; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_code_init_linecount_patch23_tests_rerun.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 17 tests passed | Runtime capability/code-editor policy tests remain green after replacing init-time `components(separatedBy:)` line counting with the allocation-free line counter |
| `/tmp/epistemos_mas_build_after_code_init_linecount_patch23.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after code-editor init line-count allocation fix |
| `/tmp/epistemos_semantic_cluster_slots_patch24_rerun_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 20 tests passed | SemanticClusterService and runtime-policy tests remain green after replacing unsafe mutable-buffer capture with an explicitly `nonisolated` locked semantic embedding slot accumulator |
| `/tmp/epistemos_mas_build_after_semantic_cluster_slots_patch24_rerun.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after the explicit-`nonisolated` semantic-cluster slot-safety fix; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_vault_ffi_sendable_patch25_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 19 tests passed | Runtime-policy tests remain green after removing local redundant `@unchecked Sendable` shims for generated vault FFI types |
| `/tmp/epistemos_mas_build_after_vault_ffi_sendable_patch25.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after the vault FFI Sendable cleanup; targeted local redundant-conformance warnings are gone, while generated UniFFI warnings remain generated-output noise |
| `/tmp/epistemos_lsp_speech_warnings_patch26_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 21 tests passed | Runtime-policy tests remain green after removing local redundant LSP awaits and the speech analyzer Sendable logger capture |
| `/tmp/epistemos_mas_build_after_lsp_speech_warnings_patch26.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after the local LSP/speech warning cleanup; targeted local warnings are gone |
| `/tmp/epistemos_webkit_processpool_patch27_source_gate.log` | `EXIT:0` | Source gate proves patched `.epdoc` WebView/App memory-pressure surfaces no longer reference `WKProcessPool(`, `.processPool`, or `resetPoolIfIdle`, and now expose `isIdleForMemoryPressure`/`webViewIdle` |
| `/tmp/epistemos_webkit_processpool_patch27_narrow_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 0 selected tests | Narrow Swift Testing selector did not execute the new source-policy test; counted only as build/sanity proof, not behavioral proof |
| `/tmp/epistemos_webkit_processpool_patch27_tests.log` | wedged and killed | Broad runtime-policy test command built and entered the suite, then wedged after an unrelated existing semantic-cluster test start; not counted as green or red |
| `/tmp/epistemos_mas_build_after_webkit_processpool_patch27.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after `.epdoc` WebKit process-pool deprecation cleanup; targeted `WKProcessPool`/`processPool` deprecation warnings are gone |
| `/tmp/epistemos_spotlight_async_indexing_patch28_source_gate.log` | `EXIT:0` | Source gate proves local Spotlight indexing uses async `CSSearchableIndex.default().indexSearchableItems(...)` calls and no longer contains the callback patterns in `SpotlightIndexer.swift` or `VaultIndexActor.swift` |
| `/tmp/epistemos_spotlight_async_indexing_patch28_narrow_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 0 selected tests | Narrow Swift Testing selector did not execute the new source-policy test; counted only as build/sanity proof, not behavioral proof |
| `/tmp/epistemos_mas_build_after_spotlight_async_patch28.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after CoreSpotlight async indexing cleanup; targeted local async-alternative warnings are gone |
| `/tmp/epistemos_hologram_completion_patch29_source_gate.log` | `EXIT:0` | Source gate proves `HologramOverlay` animation helper completions are `@Sendable` |
| `/tmp/epistemos_hologram_completion_patch29_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 24 tests passed | Runtime-policy tests remain green after Hologram completion Sendable cleanup and source-policy tests now use the bundled `SourceMirror` instead of `#filePath` repo reads |
| `/tmp/epistemos_mas_build_after_hologram_completion_patch29.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after Hologram completion Sendable cleanup; targeted local Hologram completion warnings are gone |
| `/tmp/epistemos_code_syntax_chunker_patch30_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 26 tests passed | Runtime-policy tests remain green after adding Unicode-safe code syntax chunking and off-main token/span preparation for the inspector highlighter path |
| `/tmp/epistemos_mas_build_after_code_syntax_chunker_patch30.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after the code syntax chunker fix; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_epdoc_options_warning_patch31_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 15 tests passed | `.epdoc` property tests prove legacy `options` decode/migration and canonical `options_v2` write behavior remain intact after moving local implementation reads to a private backing field |
| `/tmp/epistemos_mas_build_after_epdoc_options_warning_patch31.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after `.epdoc` legacy options warning cleanup; targeted local `EpdocProperty.swift` deprecation warnings are gone |
| `/tmp/epistemos_mas_build_after_uniffi_sendable_patch32.log` | `** BUILD SUCCEEDED **`, Codex tool process exited 0 | Fresh `Epistemos-AppStore` build after UniFFI Sendable patcher cleanup; the log footer has blank `EXIT:` because the command used Bash-style `PIPESTATUS` under zsh |
| `/tmp/epistemos_uniffi_sendable_patch32_gate.log` | `EXIT:0` | Gate proves the fresh MAS log has no generated `agent_core.swift` redundant `Sendable` warnings; remaining warnings are upstream MLX C++17 diagnostics |
| `/tmp/epistemos_lazy_bootstrap_patch33_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 28 tests passed | Runtime-policy tests prove `AppBootstrap` keeps the computer-use chain lazy at startup and no longer captures cloud knowledge distillation eagerly in the NightBrain job closure |
| `/tmp/epistemos_mas_build_after_lazy_bootstrap_patch33.log` | `** BUILD SUCCEEDED **`, Codex tool process exited 0 | Fresh `Epistemos-AppStore` build after lazy bootstrap call-site enforcement; the log footer has blank `EXIT:` because the command used Bash-style `PIPESTATUS` under zsh |
| `/tmp/epistemos_lazy_bootstrap_patch33_gate.log` | all four checks `PASS` | Gate proves focused tests, MAS build success marker, absence of eager NightBrain capture, and absence of the old `registerAgents` eager argument pair |
| `/tmp/epistemos_mlx_unload_depth_patch34_tests_final.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 256 tests passed across 2 suites | RuntimeValidation and Mamba2MetalRuntime tests prove idle MLX unload uses the working-set-only release path, critical/explicit unload stays deep, and `deepUnload()` is idempotent |
| `/tmp/epistemos_mas_build_after_mlx_unload_depth_patch34.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after the MLX unload-depth split; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_mlx_unload_depth_patch34_gate.log` | all four checks `PASS` | Gate proves focused tests, MAS build, idle working-set-only source shape, and critical/explicit deep-unload source shape |
| `/tmp/epistemos_tiptap_appstore_brotli_patch35_script.log` | `EXIT:0`, `webpack --mode production --mode production`, `.br` assets emitted | AppStore target bundle-script gate proves Debug AppStore builds now stage production `.epdoc` editor assets with Brotli transfer files |
| `/tmp/epistemos_tiptap_debug_brotli_patch35_script.log` | `EXIT:0`, `webpack --mode production --mode production`, `.br` assets emitted | Normal Xcode Debug bundle-script gate proves production editor assets are now the default resource shape unless `EPISTEMOS_TIPTAP_DEVELOPMENT=1` is set |
| `/tmp/epistemos_epdoc_brotli_patch35_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 17 tests passed | Epdoc editor bridge tests prove `.br` asset preference, original MIME preservation, `Content-Encoding: br`, traversal rejection, and font MIME mapping |
| `/tmp/epistemos_mas_build_after_epdoc_brotli_patch35.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after the AppStore bundle mode fix; log proves webpack ran production mode and emitted `.br` assets |
| `/tmp/epistemos_epdoc_brotli_patch35_gate.log` | all five checks `PASS` | Gate proves AppStore script production mode, staged `.br` assets, bridge tests, MAS production-bundle path, and built-app `.br` resource presence |
| `/tmp/epistemos_ssm_sidecar_persist_patch36_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 12 tests passed | SSM Memory Sidecar tests prove compressed-context persistence writes only with active service and context, round-trips snapshot data, no-ops for inactive/missing-context cases, and avoids accidental prefix matches between neighboring session IDs |
| `/tmp/epistemos_mas_build_after_ssm_sidecar_persist_patch36.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after SSM sidecar persistence patch; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_ssm_sidecar_persist_patch36_gate.log` | all five checks `PASS` | Gate proves focused tests, MAS build, stub removal, compressed-context API presence, and stable Debug bundle default |
| `/tmp/epistemos_speech_analyzer_crash_patch37_tests_ctki_cache.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 29 tests passed | Runtime capability policy tests prove live SpeechAnalyzer uses the single live-stream `start(inputSequence:)` path and does not keep the double-bound `analyzeSequence(inputStream)` crash shape |
| `/tmp/epistemos_mas_build_after_speech_analyzer_crash_patch37.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after the SpeechAnalyzer live dictation crash guard; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_speech_analyzer_crash_patch37_gate.log` | all three checks `PASS` | Gate proves focused policy tests, MAS build, and source crash-pattern removal |
| `/tmp/epistemos_speech_format_patch47_tests.log` | failed before useful compile evidence | First Patch 47 attempt ran into disk pressure and a shell wrapper bug using zsh's read-only `status` variable; not counted as product evidence |
| `/tmp/epistemos_speech_format_patch47_tests_rerun.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 32 tests passed | Runtime capability policy suite proves the live SpeechAnalyzer path now requests a best-compatible analysis format, prepares the analyzer in that format, converts mic buffers, and does not yield raw input-node buffers directly |
| `/tmp/epistemos_mas_build_after_speech_format_patch47.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after the SpeechAnalyzer format-conversion hardening; CodeEdit SwiftLint script-phase tail noise did not change exit status |
| `/tmp/epistemos_speech_format_patch47_gate.log` | `GATE_EXIT:0` | Source gate proves production source uses `bestAvailableAudioFormat`, `prepareToAnalyze(in:)`, and `AVAudioConverter`, has a user-visible unavailable-format error path, no longer yields raw mic buffers, and leaves ProseEditor/graph protected paths untouched |
| `/tmp/epistemos_speech_tap_isolation_patch48_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 32 tests passed | Runtime capability policy suite proves the AVAudio tap callback yields through the local `inputCont` and no longer reaches into `self?.inputContinuation` from the realtime audio queue |
| `/tmp/epistemos_mas_build_after_speech_tap_isolation_patch48.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after the SpeechAnalyzer tap-isolation hardening; CodeEdit SwiftLint script-phase tail noise did not change exit status |
| `/tmp/epistemos_speech_tap_isolation_patch48_gate.log` | `GATE_EXIT:0` | Source gate proves production source no longer uses `self?.inputContinuation?.yield` from the audio tap, diff check is clean, and protected ProseEditor/graph paths remain untouched |
| `/tmp/epistemos_raw_thoughts_tail_patch38_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 16 tests passed | RawThoughtsState tests prove inspector partial-final-line recovery and bounded high-rate event-log tail loading |
| `/tmp/epistemos_mas_build_after_raw_thoughts_tail_patch38.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after Raw Thoughts inspector tail bounding; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_raw_thoughts_tail_patch38_gate.log` | all four checks `PASS` | Gate proves focused tests, MAS build, bounded tail source shape, and regression-test presence |
| `/tmp/epistemos_voice_input_pulse_patch39_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 30 tests passed | Runtime-policy tests prove `VoiceInputButton` avoids `repeatForever`, uses bounded TimelineView animation, and gates the pulse on Reduce Motion plus window occlusion |
| `/tmp/epistemos_mas_build_after_voice_input_pulse_patch39.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after the dictation pulse cleanup; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_voice_input_pulse_patch39_gate.log` | all four checks `PASS` | Gate proves focused tests, MAS build, `repeatForever` removal, and TimelineView/reduce-motion/window-occlusion source shape |
| `/tmp/epistemos_code_gutter_initial_count_patch40_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 31 tests passed | Runtime-policy tests prove the right-side code gutter receives the initial document line count immediately after installation |
| `/tmp/epistemos_mas_build_after_code_gutter_initial_count_patch40.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after the code gutter initial-count patch; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_code_gutter_initial_count_patch40_gate.log` | all five checks `PASS` | Gate proves focused tests, MAS build, initial gutter source shape, regression-test presence, and protected editor/graph path invariants |
| `/tmp/epistemos_nightbrain_mas_scheduler_patch41_tests_rerun.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 18 tests passed | Release Packaging Hardening tests prove App Store/sandbox builds skip NightBrain scheduler registration and fallback inline launch paths, and that the App Store target excludes the direct-build LaunchAgent plist |
| `/tmp/epistemos_mas_build_after_nightbrain_scheduler_patch41_rerun.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after the NightBrain scheduler/bundle gate; log removes the stale `com.epistemos.nightbrain.plist` resource and does not copy it back into the MAS bundle |
| `/tmp/epistemos_nightbrain_mas_scheduler_patch41_gate.log` | all source/build/bundle/protected-path checks `PASS` | Gate proves focused tests, MAS build, no MAS LaunchAgent plist copy, source gates, and protected editor/graph path invariants |
| `/tmp/epistemos_nightbrain_direct_missing_helper_patch42_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 18 tests passed | Release Packaging Hardening tests prove the direct NightBrain scheduler checks the bundled LaunchAgent path before reading `SMAppService.agent.status`; test-host launch logs the quiet missing-helper skip instead of a registration failure |
| `/tmp/epistemos_mas_build_after_nightbrain_direct_missing_helper_patch42.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after the direct missing-helper scheduler guard; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `/tmp/epistemos_nightbrain_direct_missing_helper_patch42_gate.log` | all direct-log/source/MAS/protected-path checks `PASS` | Gate proves focused tests, old registration-failure log absence, direct missing-helper skip log, MAS build, no MAS LaunchAgent plist copy, source gates, and protected editor/graph path invariants |
| `/tmp/epistemos_privacy_manifest_and_instrpkg_warning_patch43_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 25 tests passed | App Store hardening privacy manifest tests and Performance.instrpkg tests remain green after the test-only warning cleanup; grep confirms the old `PerformanceInstrPkgTests.swift:74` warning is gone |
| `/tmp/epistemos_tiptap_bundle_prune_patch44_bash_n.log` | `BASH_N_EXIT:0` | Shell syntax check for `build-tiptap-bundle.sh` and `bundle-app-runtime-assets.sh` after the editor bundle prune/runtime-copy patch |
| `/tmp/epistemos_tiptap_bundle_prune_patch44_tests_rerun.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 43 tests passed | Epdoc editor bridge and release-script audit tests prove Brotli-only asset resolution and canonical `Contents/Resources/Editor` runtime asset copying |
| `/tmp/epistemos_mas_build_after_tiptap_bundle_prune_patch44_rerun.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after pruning the Tiptap source payload and preserving the editor resource tree; CodeEdit SwiftLint plugin tail noise did not change the exit status |
| `/tmp/epistemos_tiptap_bundle_prune_patch44_gate.log` | `GATE_EXIT:0` | Gate proves source and built editor payloads are 1.1M, built app has `Contents/Resources/Editor`, no root-level editor duplicates, no stale plain JS/CSS counterparts, and no KaTeX `.ttf`/`.woff` files |
| `/tmp/epistemos_mas_bundle_size_audit_patch45_clean_probe.log` | `PROBE_EXIT:0` | Clean Debug MAS size probe using fresh DerivedData: no test plug-in contamination, app 650M, resources 8.6M, editor resources 1.1M, largest payloads are Debug binary/Rust dylibs |
| `/tmp/epistemos_mas_release_size_audit_build_patch45.log` | failed with disk pressure | Release MAS size proof is blocked by `No space left on device` while extracting package artifacts; not counted as release-size evidence |
| `/tmp/epistemos_patch45_disk_pressure_after_cleanup.log` | 6.2Gi free after cleanup | Removed only temporary DerivedData directories created by the size audit |
| `/tmp/epistemos_graph_engine_physics_audit_pass1_bash.log` | `EXIT:0`, 9 physics audit tests passed | First protected graph-engine physics regression pass after the dirty graph-engine diff; zsh `PIPESTATUS` wrapper noise from the earlier attempt is not used as evidence |
| `/tmp/epistemos_graph_engine_physics_audit_pass2_bash.log` | `EXIT:0`, 9 physics audit tests passed | Second clean physics regression pass |
| `/tmp/epistemos_graph_engine_physics_audit_pass3_bash.log` | `EXIT:0`, 9 physics audit tests passed | Third clean physics regression pass; this satisfies the recursive physics-audit green-pass bar for the Rust physics tests |
| `/tmp/epistemos_graph_engine_knowledge_core_after_dirty_diff.log` | `EXIT:0`, 37 passed, 5 ignored | Focused knowledge-core suite remains green after the large `graph-engine/src/knowledge_core/store.rs` deterministic-runtime diff |
| `/tmp/epistemos_graph_engine_full_after_dirty_diff.log` | `EXIT:0`, 2522 passed, 8 ignored | Full `graph-engine` Rust suite remains green after the protected graph-engine diff; this is Rust-only proof, not Swift graph UI p99 proof |
| `/tmp/epistemos_agent_core_trajectory_crash_regression.log` | `EXIT:0`, 3 tests passed | Targeted Rust trajectory tool tests prove the older `trajectory_export` crash class now has a disable path and authorization coverage |
| `/tmp/epistemos_code_indent_guide_patch46_failing_test.log` | failed with disk pressure | Initial focused selector attempt hit `No space left on device` before useful test evidence; not counted as behavior proof |
| `/tmp/epistemos_code_indent_guide_patch46_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, selected 0 tests | Selector shape compiled and launched the test host but did not execute Swift Testing tests; not counted as targeted behavior proof |
| `/tmp/epistemos_code_indent_guide_patch46_suite_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`, 32 tests passed | Runtime-policy suite proves the code indentation guide no longer uses full-line array/trimming allocation patterns and refreshes a 4k-line buffer 20 times under the component budget |
| `/tmp/epistemos_mas_build_after_code_indent_guide_patch46.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Fresh `Epistemos-AppStore` build after the indentation guide parser change; CodeEdit SwiftLint plugin tail noise did not change exit status |
| `git log ac8c6d28..HEAD --oneline` | empty at initial recheck | no committed post-cutoff drift then |
| Protected-path diff checks | no docs-refresh edits to protected paths | re-run after docs patch |

## Results

- The `.epdoc` controller + readable-blocks bridge now has targeted green proof: controller writer injection, projection, resave replacement, canonical source-of-truth protection, regenerated package projections, FTS/fallback search, and Info.plist registration.
- Raw Thoughts has targeted green proof on both sides: Rust storage/provider behavior, full `agent_core`, Swift state/taxonomy behavior, Swift inspector partial-line recovery, bounded high-rate inspector tail loading, and MAS build.
- Code editor component proof is now green for the 4k-line line counter, init-time allocation-free line counting, right-side gutter width/theme tokens, viewport-bounded gutter draw range, initial gutter population, outline/polish policy, and SwiftTreeSitter Unicode mapping suite. This is not full runtime scroll/typing p95 proof.
- Derived-store component proof is green for readable-block typed artifact/block hits, replace-on-rename semantics, delete-to-FTS cleanup, and basic GraphStore remove-node cleanup. This is not full live save/delete/rename/restart smoke.
- Fresh Pro and MAS builds are green after Patches 5-7 in `/tmp/epistemos_pro_build_patch8_refresh.log` and `/tmp/epistemos_mas_build_patch8_refresh.log`.
- Deterministic runtime Phase 0 preflight is now grounded by fresh Rust knowledge-core/ring tests, bridge accessor benchmarks, and focused Swift bridge/query tests. The preflight is documented in `docs/DETERMINISTIC_RUNTIME_V1_PREFLIGHT.md`.
- Deterministic runtime Phase 1 typed mutation envelopes are green in Rust: real `DatalogStore` document ingest, block insert/edit/move/delete, and link relation mutations now emit tested envelope data. This is not yet a production Swift adapter.
- Deterministic runtime Phase 2 query fingerprints/watch plans are green in Rust: equivalent query identity, distinct query shape, relevant/irrelevant artifact and block intersection, relation/backlink intersection, body/search versus graph separation, ordering-only separation, and unsupported fallback are tested. This is not yet a production Swift adapter.
- Deterministic-runtime feature flags are green in Swift policy tests: all experimental runtime lanes default off and require explicit UserDefaults or environment opt-in. The `xcodebuild` log includes known CodeEdit SwiftLint tail noise, but exits `0` after `** TEST SUCCEEDED **`.
- Deterministic runtime adapter contract is green in Swift: real outline payloads drained from `KnowledgeCoreBridge` apply to a sink only when `deterministicKnowledgeCoreRuntime` is enabled, while disabled and unsupported payload paths fall back. This is not yet wired into production QueryEngine/UI.
- Deterministic runtime binding contract is green in Swift: real payloads from two bridge subscriptions apply only to the registered subscription sink, and unregistered subscriptions fall back. This prevents broad payload application, but still stops short of production QueryEngine/UI mutation.
- Deterministic outline projection now has a narrow production note-surface seam: when `deterministicKnowledgeCoreRuntime` is enabled, note metrics refresh ingests the note body into the staged knowledge-core bridge, applies only the matching outline subscription through `KnowledgeCoreRuntimeBinding`, and updates the existing note TOC state. Broader `QueryEngine`/search/list UI wiring is still not complete.
- Fresh MAS build is green after deterministic outline projection wiring in `/tmp/epistemos_mas_build_after_outline_projection_patch17.log`.
- Borrowed-row work now has a safe scalar projection gate: `drainBorrowedProjections` reads `KnowledgeQueryRowFFI` slices while the ring slot is valid, records hashes/byte counts/scalars, advances tail, and reports `materializedStringCount == 0`. This is not yet a visible-row owned model layer.
- Fresh MAS build is green after borrowed-row scalar projection in `/tmp/epistemos_mas_build_after_borrowed_projection_patch18.log`.
- Claude's local-stream truncation fix is now corrected and covered: EOF-held tag-prefix plaintext flushes to the streaming UI, unterminated hidden/tool buffers remain hidden, and `LocalAgentLoop` no longer duplicates the flushed suffix in the returned answer. Verified in `/tmp/epistemos_local_stream_flush_tests.log`.
- Fresh MAS build is green after the local-stream EOF correction in `/tmp/epistemos_mas_build_after_local_stream_flush_patch19.log`.
- Claude's Rust perf-sprint claims now have local verification: `agent_core --lib` passed 774 tests in `/tmp/epistemos_agent_core_perf_handoff_lib_tests.log`, and `epistemos-shadow --lib` passed 45 tests with 5 ignored download-backed tests in `/tmp/epistemos_shadow_perf_handoff_lib_tests.log`.
- Static artifact routing is already in the desired shape: `ArtifactRoute` and Swift/Rust `ArtifactKind` parity tests passed in `/tmp/epistemos_static_routing_patch20_tests.log`, production `AnyView(...)` source gate is empty in `/tmp/epistemos_static_routing_anyview_gate.log`, and `ArtifactHostView` uses an exhaustive `@ViewBuilder` switch per `/tmp/epistemos_static_routing_source_audit.log`.
- Sidecar startup prefetch is now bounded: `EpistemosSidecarTests` passed 12 tests in `/tmp/epistemos_sidecar_prefetch_patch21_tests.log`, including max-bound and zero-limit coverage. Fresh MAS build is green after the sidecar prefetch bound in `/tmp/epistemos_mas_build_after_sidecar_prefetch_patch21.log` with `** BUILD SUCCEEDED **` and `EXIT:0`.
- Semantic clustering no longer uses the unsafe mutable-buffer capture pattern from Claude's perf sprint: focused semantic-cluster/runtime-policy tests passed in `/tmp/epistemos_semantic_cluster_slots_patch24_rerun_tests.log`, and fresh MAS build is green in `/tmp/epistemos_mas_build_after_semantic_cluster_slots_patch24_rerun.log`. The first slot-accumulator correction exposed the repo's default MainActor isolation warning, then the helper was corrected to `private nonisolated final class SemanticEmbeddingSlots`.
- `VaultLifecycleService` no longer adds redundant local `@unchecked Sendable` conformances for generated FFI types. Focused runtime-policy tests passed in `/tmp/epistemos_vault_ffi_sendable_patch25_tests.log`, and fresh MAS build is green in `/tmp/epistemos_mas_build_after_vault_ffi_sendable_patch25.log`. The remaining redundant `Sendable` warnings are in generated UniFFI output, not this local vault lifecycle file.
- `LSPClient` no longer awaits synchronous actor helpers, and `EpistemosSpeechAnalyzer` no longer captures a MainActor-isolated static logger from a `@Sendable` observer closure. Focused runtime-policy tests passed in `/tmp/epistemos_lsp_speech_warnings_patch26_tests.log`, and fresh MAS build is green in `/tmp/epistemos_mas_build_after_lsp_speech_warnings_patch26.log`.
- `.epdoc` WebView surfaces no longer use deprecated `WKProcessPool`/`configuration.processPool` APIs. The source gate passed in `/tmp/epistemos_webkit_processpool_patch27_source_gate.log`, and a fresh MAS build is green in `/tmp/epistemos_mas_build_after_webkit_processpool_patch27.log` with the targeted WebKit deprecation warnings gone.
- Local Spotlight indexing paths now use the async CoreSpotlight indexing API instead of callback-based calls. The source gate passed in `/tmp/epistemos_spotlight_async_indexing_patch28_source_gate.log`, and a fresh MAS build is green in `/tmp/epistemos_mas_build_after_spotlight_async_patch28.log` with the targeted local async-alternative warnings gone.
- `HologramOverlay` animation helpers now require `@Sendable` completion closures, removing the local Swift 6 completion warnings. Focused runtime-policy tests passed in `/tmp/epistemos_hologram_completion_patch29_tests.log`, and a fresh MAS build is green in `/tmp/epistemos_mas_build_after_hologram_completion_patch29.log`. The same patch hardened runtime-policy source tests to use the bundled `SourceMirror` after a direct `~/Downloads` source read wedged the first test host.
- Code inspector syntax chunking is now Unicode-safe and less main-actor-heavy: `CodeSyntaxChunker` chunks on Swift character boundaries while retaining UTF-8 byte offsets, per-chunk token/span prep runs in a utility-priority detached task, and the old `offsetBy: chunk.start/end` path is absent. Focused runtime-policy tests passed in `/tmp/epistemos_code_syntax_chunker_patch30_tests.log`, and fresh MAS build is green in `/tmp/epistemos_mas_build_after_code_syntax_chunker_patch30.log`.
- `.epdoc` legacy options migration no longer emits local deprecation warnings during MAS builds. The deprecated public compatibility accessor remains, but internal decode/effective-option reads use a private `legacyOptions` backing field. Existing `.epdoc` property tests passed in `/tmp/epistemos_epdoc_options_warning_patch31_tests.log`, and fresh MAS build is green in `/tmp/epistemos_mas_build_after_epdoc_options_warning_patch31.log`.
- Generated `agent_core.swift` redundant `Sendable` warnings are now fixed at the source patcher layer. `patch-uniffi-bindings.py` keeps UniFFI's generated `extension Type: Sendable {}` as the single conformance source for the four previously duplicated types. A fresh MAS build is green in `/tmp/epistemos_mas_build_after_uniffi_sendable_patch32.log`, and `/tmp/epistemos_uniffi_sendable_patch32_gate.log` proves the redundant-warning search is empty.
- `AppBootstrap` lazy startup call sites are now enforced: NightBrain no longer captures `cloudKnowledgeDistillationService` eagerly, and `registerAgents(...)` no longer receives unused `screenCapture`/`screen2AXFusion` arguments that forced the computer-use chain during launch. Focused runtime-policy tests passed in `/tmp/epistemos_lazy_bootstrap_patch33_tests.log`, and fresh MAS build is green in `/tmp/epistemos_mas_build_after_lazy_bootstrap_patch33.log`.
- MLX unload depth is now split by intent: normal idle unload releases only the Metal working set, while explicit unload and critical pressure/thermal paths still deep-unload Metal runtime state. Runtime/Metal tests passed in `/tmp/epistemos_mlx_unload_depth_patch34_tests_final.log`, and fresh MAS build is green in `/tmp/epistemos_mas_build_after_mlx_unload_depth_patch34.log`.
- `.epdoc` editor Xcode build assets are now staged as production bundles by default, including AppStore and normal Debug bundle-script gates. Production webpack emits `editor.js.br` and `editor.css.br`; the URL scheme handler prefers those files with `Content-Encoding: br`; focused bridge tests and fresh MAS build are green. Development bundles now require explicit `EPISTEMOS_TIPTAP_DEVELOPMENT=1`.
- SSM sidecar compressed-context persistence is now wired through `SSMStateService`: `persistState()` is no longer a stub, snapshots are saved atomically under the SSM cache, latest-context discovery requires the exact sanitized session prefix, and focused sidecar tests are green. Full user-visible warm-resume behavior remains a separate runtime validation gate.
- The live dictation crash signatures in `EpistemosSpeechAnalyzer.startLive` now have three automated hardening layers. Patch 37 removed the double-bound stream shape, Patch 47 requests SpeechAnalyzer's best-compatible analysis format and converts mic buffers before yielding them, and Patch 48 removes MainActor instance access from the AVAudio tap callback. Focused runtime-policy tests, source gates, and fresh MAS builds are green. Runtime microphone smoke remains deferred.
- The dictation recording pulse no longer uses `.repeatForever`. `VoiceInputButton` now uses a bounded `TimelineView` pulse only when recording and visible, with Reduce Motion/window-occlusion pause gates. Focused runtime-policy tests and a fresh MAS build are green.
- Raw Thoughts inspector loading is now bounded for verbose/high-rate runs: `RawThoughtsInspectorView` tails at most 256 KiB of `events.jsonl`, publishes at most 500 visible event rows, preserves partial final-line recovery, and drops a partial first line when tailing from the middle of a file. Focused RawThoughtsState tests and a fresh MAS build are green.
- NightBrain's direct-build scheduler is now out of the App Store launch and bundle profile: `AppBootstrap` skips LaunchAgent registration and fallback inline runs under `EPISTEMOS_APP_STORE || MAS_SANDBOX`, the App Store target excludes `Resources/LaunchAgents/com.epistemos.nightbrain.plist`, focused release-packaging tests are green, and a fresh MAS build proves the stale plist was removed and not copied back.
- Direct/debug NightBrain launch noise is now bounded: if the helper plist is not actually packaged at `Contents/Library/LaunchAgents`, `NightBrainScheduler.register()` logs an informational skip before touching `SMAppService.agent.status` instead of emitting a registration failure. Focused release-packaging tests, direct launch-log gate, and fresh MAS build are green.
- The S.6 settings/privacy automated slice is rechecked: `SettingsCategoryTests` already accounts for the privacy section, `PrivacyDetailView.swift` is ASCII-clean, and `AppStoreHardeningTests` prove `PrivacyInfo.xcprivacy` still declares no tracking, no tracking domains, no collected-data types, and the expected accessed API reason codes. The Performance.instrpkg test-warning cleanup is green in `/tmp/epistemos_privacy_manifest_and_instrpkg_warning_patch43_tests.log`.
- `.epdoc` editor packaging is now smaller and runtime-correct: the production resource tree is pruned from 5.8M to 1.1M by shipping only Brotli JS/CSS transfer assets plus WOFF2 fonts, and the App Store bundle now preserves `Contents/Resources/Editor` instead of leaving editor files flattened at the resource root. Focused tests, shell syntax checks, fresh MAS build, and built-app gates are green.
- Bundle-size audit is partially grounded. A clean Debug MAS app is 650M with no test plug-in contamination; resources are only 8.6M and `.epdoc` Editor is 1.1M, so the remaining Debug bloat is mostly `Epistemos.debug.dylib` and Rust dylibs. Release App Store size remains unproven because the Release build ran out of disk while extracting package artifacts.
- Local crash inventory for 2026-04-29 is recorded in `docs/audits/CRASH_REGRESSION_TRIAGE_2026_04_29.md`. The only three-day app crash signatures were both SpeechAnalyzer live-dictation paths; they now have the Patch 37 stream-shape fix, Patch 47 audio-format conversion guard, and Patch 48 audio-tap actor-isolation guard. The older trajectory registration crash class has targeted Rust regression proof.
- Contextual Shadows V0 has targeted state proof and source-level user-surface proof. The implementation is intentionally notes-first because `InstantRecallService` indexes notes only; chat-origin typing can trigger recall, but returned hits remain notes and the Chat tab is hidden unless real chat hits are present later.
- Instant Recall async-only rebuild guard is green: sync vault-wide rebuild/indexBatch APIs are unavailable, production rebuild uses the async path, async search triggers lazy snapshot hydration, and MAS still builds.
- MAS build and binary profile are now fresh after the TCC/Omega permissions gate. Re-run after any Settings, entitlement, Info.plist, AppStore scheme, Omega, or computer-use source change.
- ProseEditor and graph protected paths remain off-limits.
- The dirty worktree contains many unrelated files; this audit does not validate them all as ship-ready.

## Failures

No current focused test failure remains in the verified logs above. Full-suite status remains unknown after the final docs/code updates until commands are re-run.

## Warnings

- Do not treat prior green logs as final ship evidence after additional code changes.
- Wrapper scripts can hide real exit codes; final gates must read raw logs.
- SwiftLint plugin tail noise is not a failure by itself, but raw xcodebuild exit status is authoritative.
- Generated `syntax-core/.../libsyntax_core.rlib` must never be staged.
- Generated `agent_core.swift` redundant `Sendable` warnings were fixed in the UniFFI generation patcher on 2026-04-29. Do not hand-edit generated bindings if this class returns.
- `.epdoc` WebKit process-pool deprecation warnings, local CoreSpotlight async-alternative warnings, and generated UniFFI redundant `Sendable` warnings are fixed in the patched surfaces. The current fresh MAS warning inventory is upstream MLX C++17 diagnostics.
- Focused runtime-policy test logs still include pre-existing test-target warnings (`AgentHarnessTests`, `EpdocEndToEndSmokeTests`, and one `PipelineServiceTests` macro warning). Patches 33 and 34 do not address those test-warning classes. The local `PerformanceInstrPkgTests.swift:74` warning was fixed by Patch 43.

## Broken Tests

This report does not newly identify broken tests. Prior audit material referenced disabled or deferred tests; each disabled suite must either have a re-enable plan or be removed from ship claims.

## Missing Tests

| Missing test | Priority | Why |
|---|---:|---|
| Contextual Shadows live runtime click/SLA smoke | P1 | State and source wiring are green, but manual/runtime click and typing-latency proof are deferred |
| Raw Thoughts live run-link/runtime browse smoke | P1 | storage and inspector recovery are green, but default-on needs real run-to-UI proof |
| Raw Thoughts live stream cadence/backpressure proof | P1 | storage and inspector high-rate tail bounding are green, but live producer-to-UI cadence/backpressure still needs runtime proof before default-on claims |
| `.epdoc` full UI open/edit/save smoke | P1 | controller/projection/search proof is green, but the live document window path still needs runtime smoke before surfacing broadly |
| Derived-store live save/delete/rename/restart smoke | P1 | component readable-block/graph tests are green, but app-level propagation into recall/search/graph still needs runtime proof |
| Code editor full 4k-line typing/scroll/Instruments p95 proof | P1 | component line-count/gutter/visible-range tests are green, but user requested Xcode-like runtime fluidity |
| Code editor viewport/incremental syntax highlight proof | P1 | SwiftTreeSitter Unicode mapping tests are green; whole-text highlight/runtime cost still needs measurement before stronger claims |
| Swift Testing selector for `ProductionHardeningTests` | P2 | `xcodebuild -only-testing:EpistemosTests/ProductionHardeningTests` built but executed 0 tests; keep the source/binary gate until the selector is fixed |

## Required New Tests

- Contextual Shadows runtime smoke or UI automation for click-open and typing-latency proof
- Instant Recall large-vault p95/signpost proof
- Raw Thoughts live run-link runtime smoke
- Raw Thoughts live stream cadence/backpressure test
- `.epdoc` live WebView open/edit/save smoke test or manual evidence log
- `CodeEditorLargeFileRuntimePerformanceTests` for actual scroll/typing p95, not just component scans
- `CodeEditorViewportHighlightingTests` if syntax highlighting moves from whole-text to visible/incremental ranges
- `AppStoreComputerUseProfileTests`

## Manual Smoke Test Plan

Manual-only checks are deferred per user instruction, but the final ship gate still needs them:

1. Launch app.
2. Open/create vault.
3. Create note.
4. Edit note.
5. Search note.
6. Open graph.
7. Pan/zoom graph.
8. Start chat.
9. Stream AI response.
10. Trigger Ambient Recall.
11. Open related note.
12. Open related chat if chat recall ships.
13. Create/open/save `.epdoc` if Documents ship.
14. Browse Raw Thoughts run if Raw Thoughts ships.
15. Restart app.
16. Verify data persists.

## Next Verification Commands

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
cargo test --manifest-path graph-engine/Cargo.toml
cargo test --manifest-path agent_core/Cargo.toml
```

Run targeted tests first after implementing each patch. Run full suites only after P0/P1 patches settle.
