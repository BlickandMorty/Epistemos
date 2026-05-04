# Master Hardening + Wiring Audit

Date: 2026-04-28

## Executive Summary

Epistemos is no longer just a pile of staged systems. The repo now contains real substrate for the V1 identity: native Prose, chat/model routing, Metal graph, FTS/readable blocks, Instant Recall, Contextual Shadows V0, Raw Thoughts V0, `.epdoc` package/editor work, MAS stubs for computer use, and App Store privacy assets.

The main risk has shifted from "missing code" to "unproven user wiring." Several older audit claims were stale: Documents are not absent, Contextual Shadows UI is not absent, and Raw Thoughts is not only a paper plan. The correct hardening posture is stricter: treat these features as built/partial until their user path, persistence, recovery, privacy, and performance are proven.

The Mac App Store V1 should stay small: write, chat, search, graph, recall, privacy settings, and only proven slices of Raw Thoughts/Documents/Code. Direct-build-only automation must stay hidden in MAS.

## Highest-Risk Findings

| Finding | Severity | Confidence | Evidence |
|---|---:|---:|---|
| MAS privacy/computer-use boundary must remain exact | BLOCKER | High | Fresh MAS gate passed on 2026-04-28: `/tmp/epistemos_mas_tcc_build.log`, `/tmp/epistemos_mas_tcc_binary_audit.log`, `Epistemos/AppStore/AppStoreComputerUseStubs.swift`, `Epistemos/Omega/OmegaPermissions.swift`, `Epistemos/Omega/Vision/TCCPermissionState.swift` |
| Contextual Shadows V0 now has code-level user-surface proof, but runtime click/SLA proof and true chat-indexed hits remain open | HIGH | High | `/tmp/epistemos_contextual_shadows_tests.log`, `/tmp/epistemos_contextual_shadows_wiring_audit.log`, `/tmp/epistemos_mas_build_after_contextual_shadows.log`, `Epistemos/State/ContextualShadowsState.swift`, `Epistemos/Views/Recall/*`, `Epistemos/Views/Chat/ChatInputBar.swift`, `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` |
| Instant Recall sync rebuild entrypoints are now guarded, but large-vault p95 proof is still missing | MEDIUM | High | `/tmp/epistemos_instant_recall_async_guard_tests.log`, `/tmp/epistemos_instant_recall_source_gate.log`, `/tmp/epistemos_mas_build_after_instant_recall_async_guard.log`, `Epistemos/KnowledgeFusion/InstantRecallService.swift`, `Epistemos/Sync/VaultSyncService.swift` |
| Raw Thoughts storage/provider recovery and bounded inspector tail proof are green, but default-on UI/run-linking and live stream cadence still need runtime smoke | HIGH | High | `agent_core/src/storage/raw_thoughts.rs`, `agent_core/src/providers/claude.rs`, `Epistemos/Views/RawThoughts/RawThoughtsInspectorView.swift`, `/tmp/epistemos_raw_thoughts_patch5_cargo.log`, `/tmp/epistemos_claude_provider_redacted_thinking_tests.log`, `/tmp/epistemos_agent_core_patch5_full.log`, `/tmp/epistemos_raw_thoughts_state_patch5_tests.log`, `/tmp/epistemos_raw_thoughts_tail_patch38_tests.log`, `/tmp/epistemos_mas_build_after_raw_thoughts_tail_patch38.log` |
| Local-model streaming EOF handling is fixed and tested, but live note-ask/manual local-model UI smoke remains deferred | MEDIUM | High | `Epistemos/LocalAgent/IncrementalToolCallDetector.swift`, `Epistemos/LocalAgent/LocalAgentLoop.swift`, `EpistemosTests/IncrementalToolCallDetectorTests.swift`, `EpistemosTests/LocalAgentLoopTests.swift`, `/tmp/epistemos_local_stream_flush_tests.log` |
| `.epdoc` controller/projection/search proof is green, but live WebView open/edit/save smoke is still required before visible V1 | HIGH | High | `Epistemos/Engine/EpdocDocument.swift`, `Epistemos/Sync/ReadableBlocksProjector.swift`, `Epistemos/Sync/ReadableBlocksIndex.swift`, `/tmp/epistemos_epdoc_projection_tests.log`, `/tmp/epistemos_readable_blocks_tests.log`, `/tmp/epistemos_focused_audit_tests.log` |
| Code editor component gate is green, including init-time allocation-free line counting, but full 4k-line runtime fluidity remains unproven | HIGH | High | `Epistemos/Views/Notes/CodeEditorView.swift`, `Epistemos/Views/Notes/CodeLineGutter.swift`, `Epistemos/Engine/SwiftTreeSitterLiveHighlighter.swift`, `/tmp/epistemos_code_editor_patch6_tests.log`, `/tmp/epistemos_code_init_linecount_patch23_tests_rerun.log`, `/tmp/epistemos_mas_build_after_code_init_linecount_patch23.log` |
| Derived indexes can go stale unless live save/delete/rename paths are proven across graph/search/recall | HIGH | Medium | `ReadableBlocksIndex.swift`, `SearchIndexService.swift`, graph builders, recall index, `/tmp/epistemos_derived_store_patch7_tests.log` |
| Fresh Pro/MAS automated build refresh is green, but manual Phase S remains deferred | MEDIUM | High | `/tmp/epistemos_pro_build_patch8_refresh.log`, `/tmp/epistemos_mas_build_patch8_refresh.log`; user explicitly deferred manual-only Phase S checks |
| Deterministic runtime mutation envelopes, watch plans, Swift feature flags, guarded adapter, subscription binding, a narrow note-outline UI sink, and a scalar borrowed-row projection gate are now proven; broader QueryEngine/search/list wiring and visible-row owned materialization are still missing | HIGH | High | `graph-engine/src/knowledge_core/store.rs`, `Epistemos/Engine/Log.swift`, `Epistemos/Engine/KnowledgeCoreBridge.swift`, `Epistemos/Views/Notes/NoteTableOfContents.swift`, `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`, `/tmp/epistemos_deterministic_phase2_store_tests.log`, `/tmp/epistemos_deterministic_phase2_knowledge_core.log`, `/tmp/epistemos_runtime_flags_patch14_tests.log`, `/tmp/epistemos_runtime_adapter_patch15_tests.log`, `/tmp/epistemos_runtime_binding_patch16_tests.log`, `/tmp/epistemos_outline_projection_patch17_tests.log`, `/tmp/epistemos_mas_build_after_outline_projection_patch17.log`, `/tmp/epistemos_borrowed_projection_patch18_tests.log`, `/tmp/epistemos_mas_build_after_borrowed_projection_patch18.log` |

## Product Identity Recommendation

V1 identity:

Epistemos is a native macOS cognitive workspace where you can write, chat, recall, and see the graph of your work without sacrificing privacy or speed.

Do not market V1 as a Notion clone, an autonomous computer-use agent, or a full rich-document suite. The near-term magic should be:

1. Prose is fast and native.
2. Chat is useful and honest about local/cloud routing.
3. Related context appears while you write.
4. Raw Thoughts make observable model/run work inspectable.
5. Search and graph resolve to typed artifacts, not anonymous blobs.

## P0 Must Fix Before V1

| Item | Required fix | Verification |
|---|---|---|
| MAS unsafe surfaces | Hide/stub ScreenCaptureKit, AX, CGEvent, shell, PTY, Docker, arbitrary external MCP in MAS | Fresh MAS build and binary profile passed in `/tmp/epistemos_mas_tcc_build.log` and `/tmp/epistemos_mas_tcc_binary_audit.log` |
| Privacy copy and manifest drift | Settings copy, PrivacyInfo, entitlements, and provider routes agree | Automated settings/privacy slice is green in `/tmp/epistemos_privacy_manifest_and_instrpkg_warning_patch43_tests.log`; manual App Store wording/metadata review remains deferred |
| Reachable hard crashes/stubs | No reachable core UI path throws fatal/stub/bindingsUnavailable | targeted grep plus smoke tests |
| Canonical data safety | Derived projections never overwrite canonical `.epdoc` or Prose content silently | `.epdoc` external/stale projection tests passed in `/tmp/epistemos_epdoc_projection_tests.log` |
| Provider reasoning safety | Store only observable provider/app-owned reasoning surfaces; Anthropic opaque data preserved if replayed | Raw Thoughts redacted-thinking/signature round-trip tests are green; keep live replay smoke gated |

## P1 Should Fix Before Public Beta

| Item | Required fix | Verification |
|---|---|---|
| Contextual Shadows V0 | keep notes-first V0 honest; add runtime click/SLA proof before default-on | state tests and source wiring are green; runtime smoke/signposts still needed |
| Instant Recall async rebuild | keep production on async-only path; measure large-vault p95 before default-on recall claims | async guard tests/source gate/MAS build are green; p95 signpost proof remains |
| Raw Thoughts V0 | run folder, manifest, events, summaries, tools, links, recovery, UI smoke | Rust + Swift tests are green for storage/recovery/provider surfaces and bounded inspector tail loading; runtime smoke remains |
| `.epdoc` visibility gate | expose only if package open/save/projections/search and live editor smoke are green | integration test plus runtime smoke |
| Code editor performance | full 4k-line scroll/typing/gutter/runtime highlighting proof | component line-count/gutter/visible-range/Unicode chunking tests are green; Instruments/p95 runtime proof remains |
| Search/readable blocks | every visible artifact kind emits normalized readable blocks | integration tests |
| Graph/data consistency | live save/delete/rename update derived graph/search/recall | readable-block/GraphStore component tests are green; app-level propagation smoke remains |

## P2 Safe to Defer

- Full Agent Command Center.
- Publication-grade DOCX/PDF export.
- CRDT/collaboration.
- Djot adoption.
- Full deterministic knowledge runtime.
- Deterministic runtime Phase 3+ until feature flags and production Swift adapter tests exist.
- Metal text editor rewrite.
- Semantic auto-linking everywhere.
- Diagnostics dashboard beyond hidden developer mode.

## Hidden Capabilities That Should Be Surfaced

| Capability | Surface |
|---|---|
| Contextual Shadows | subtle Related button during note/chat typing |
| Raw Thoughts | model vault tree plus "Open run" from chat/agent result |
| `.epdoc` Documents | file-type-driven New Document only after smoke proof |
| Code editor line gutter | theme-safe editor toggle after benchmark |
| Privacy/saved grants | Settings Privacy link |
| Quick Capture | menu/shortcut only if end-to-end save/index works |

## Capabilities That Should Stay Hidden

- Computer use in MAS.
- Shell/PTY/Docker/local process tools in MAS.
- External arbitrary MCP servers in MAS.
- iMessage automation until separately reviewed.
- Agent Command Center until stable and scoped.
- Documents if `.epdoc` smoke fails.
- Raw Thoughts if live run-link/runtime smoke or streaming-load proof fails.

## Features That Are Built But Not Wired

| Feature | Gap |
|---|---|
| `.epdoc` package/editor | built pieces need full open/save/search user-path proof |
| Readable blocks | schema exists; all artifact producers must feed it |
| Raw Thoughts | storage/provider recovery and inspector partial-line proof are green; run-link/search/graph proof incomplete |
| Contextual Shadows | state/source wiring is green; V0 is notes-first and hides Chats unless real chat hits exist |
| Code editor high-performance path | editor exists; 4k-line line-count/gutter/visible-range and Unicode-safe inspector chunking component gates are green; full scroll/typing p95 proof incomplete |
| Quick Capture | code exists; discoverable save/index path unclear |

## Features That Are Wired But Not Visible

- Raw Thoughts behind environment flag.
- Contextual Shadows behind environment flag.
- App Store computer-use stubs are intentionally invisible.
- Diagnostics and performance evidence are mostly internal.

## Features That Are Visible But Not Stable

- Code editor large-file/gutter target until runtime scroll/typing p95 proof exists.
- `.epdoc` if surfaced before integration proof.
- Recall panel default-on if runtime click/SLA proof is not fixed.
- Model/cloud privacy copy if provider routes shift without tests.

## Performance/Concurrency Risks

- Instant Recall large-vault rebuild/search p95 is not yet measured, although sync rebuild entrypoints are now unavailable.
- Code editor whole-text edit/highlight work at 4k+ lines. The line-count helper, init-time allocation-free count, gutter policy, viewport-bounded gutter range, initial gutter population, single-pass indentation-guide refresh, and Unicode-safe inspector syntax chunking are tested, but runtime p95 proof is not done.
- UTF-8/UTF-16 syntax range conversion. Existing SwiftTreeSitter mapping tests are green; large-file cost still needs measurement.
- `.epdoc` WebView save/projection latency.
- Raw Thoughts live event stream cadence/backpressure. Inspector loading is now bounded to a 256 KiB / 500-line tail, but live producer-to-UI cadence is still a runtime gate.
- Sidecar AP7 cache memory is bounded and bulk prefetch now stops at `SidecarCache.bound`, but large-vault launch p95/Instruments proof remains outstanding.
- Semantic clustering parallel embedding collection no longer captures an unsafe mutable buffer in the concurrent path; it now uses an explicitly `nonisolated` locked slot accumulator, and focused tests plus MAS build are green. Full graph/semantic clustering runtime p95 remains a later measurement gate.
- `VaultLifecycleService` no longer declares local redundant `@unchecked Sendable` shims for generated FFI types; focused policy tests and MAS build are green. The later UniFFI patcher cleanup also removes the generated `agent_core.swift` redundant `Sendable` warnings by keeping UniFFI's generated extension as the single conformance source.
- Local LSP routing and speech route-change observer warnings are cleaned up: `LSPClient` no longer awaits synchronous actor helper calls, and `EpistemosSpeechAnalyzer` captures its logger before the `@Sendable` notification closure. Focused policy tests and MAS build are green.
- `.epdoc` WebView surfaces no longer use deprecated `WKProcessPool`/`configuration.processPool` APIs. The editor and KaTeX preview still use non-persistent data stores; the memory-pressure diagnostic now reports WebView idleness instead of claiming a stale process-pool reset. Source gate and fresh MAS build are green.
- Local Spotlight indexing now uses async CoreSpotlight indexing APIs in `SpotlightIndexer` and `VaultIndexActor`. Source gate and fresh MAS build are green, and the targeted local async-alternative warnings are gone.
- `HologramOverlay` animation helper completions are now `@Sendable`, removing the local Swift 6 animation-completion warnings. Runtime-policy tests were also hardened to use the bundled `SourceMirror` instead of direct `~/Downloads` source reads after the first focused test host wedged in a source-file read. Focused tests and fresh MAS build are green.
- The dirty protected graph-engine diff has Rust-side regression proof: three recursive physics-audit passes are green, the focused knowledge-core suite is green, and the full `graph-engine` suite is green with 2522 passed / 8 ignored in `/tmp/epistemos_graph_engine_full_after_dirty_diff.log`. This does not prove Swift graph UI frame p99 or runtime pan/zoom smoothness.
- Code inspector syntax highlighting no longer treats UTF-8 byte offsets as Swift character offsets. `CodeSyntaxChunker` emits character-boundary ranges with matching UTF-8 offsets, chunk token/span prep runs off-main, focused runtime-policy tests are green, and the fresh MAS build is green. This still does not replace Instruments/p95 proof for the main CodeEditSourceEditor typing/scroll path.
- `.epdoc` legacy options migration no longer produces local deprecation warnings in MAS builds. The deprecated public `options` accessor remains for compatibility, internal migration reads use private `legacyOptions`, `.epdoc` property tests are green, and a fresh MAS build is green.
- Generated `agent_core.swift` redundant `Sendable` warnings are fixed at the UniFFI patcher layer. A fresh MAS build is green, the redundant warning gate is green, and the remaining fresh MAS warning inventory is upstream MLX C++17 diagnostics.
- `AppBootstrap` lazy service boundaries are now enforced at the call-site level. NightBrain resolves `cloudKnowledgeDistillationService` only when its background job runs, and the currently no-op orchestrator registration no longer receives unused computer-use services that forced startup allocation. Focused runtime-policy tests and fresh MAS build are green.
- MLX unload depth now matches runtime intent. Ordinary idle unload keeps reusable Metal pipeline/archive state and releases only the working set; explicit unload, critical memory pressure, and critical thermal pressure still deep-unload the Metal runtime. Focused runtime/Metal tests and fresh MAS build are green.
- `.epdoc` editor Xcode builds now stage production JS/CSS assets with Brotli transfer files by default, including AppStore and normal Debug bundle-script gates. The URL scheme handler prefers `.br` assets for JS/CSS with `Content-Encoding: br` and falls back to uncompressed assets. Focused bridge tests and fresh MAS build are green. Development bundles now require explicit `EPISTEMOS_TIPTAP_DEVELOPMENT=1`; lazy chunking/tree-shaking for KaTeX/Mermaid remains unimplemented and must not be claimed.
- `.epdoc` editor resources are now pruned and packaged under the canonical built-app tree. Production source and built resources are 1.1M instead of the previously observed 5.8M duplicate payload, stale plain JS/CSS counterparts are removed when `.br` exists, KaTeX ships WOFF2 only, and `bundle-app-runtime-assets.sh` preserves `Contents/Resources/Editor` instead of leaving Xcode-flattened editor files at the resource root. Focused tests, shell syntax checks, fresh MAS build, and built-app gates are green.
- SSM sidecar compressed-context persistence is no longer a stub. `SSMMemorySidecar.persistState()` writes the latest compressed context through active `SSMStateService` cache APIs, and focused sidecar tests prove active write/load, inactive no-op, missing-context no-op, and exact session-prefix discovery behavior. Full warm-resume product behavior remains a runtime validation gate.
- Live dictation now has three automated crash hardening layers for the Apr 29 SpeechAnalyzer reports. Patch 37 removed the double-bound input-stream pattern; Patch 47 requests SpeechAnalyzer's best-compatible analysis format, prepares the analyzer in that format, converts mic buffers with `AVAudioConverter`, and exposes an unavailable-format UI error; Patch 48 removes MainActor instance access from the AVAudio tap callback. Focused runtime-policy tests, source gates, and fresh MAS builds are green. Runtime microphone smoke remains deferred.
- The dictation recording pulse no longer uses `.repeatForever`. `VoiceInputButton` now uses a bounded `TimelineView` cadence and pauses the ring when Reduce Motion is enabled or the window is occluded. Focused runtime-policy tests, a source gate, and a fresh MAS build are green.
- Raw Thoughts inspector loading no longer reads/publishes all of a verbose `events.jsonl` into SwiftUI. `RawThoughtsInspectorView` uses a bounded file tail, keeps only 500 visible rows, preserves partial final-line recovery, and has focused tests plus a fresh MAS build green. Live run-link/runtime browsing still remains deferred.
- NightBrain's direct-build LaunchAgent scheduler no longer leaks into the App Store launch or bundle profile. `AppBootstrap` skips scheduler registration and fallback inline runs for `EPISTEMOS_APP_STORE || MAS_SANDBOX`, the App Store target excludes `Resources/LaunchAgents/com.epistemos.nightbrain.plist`, focused release-packaging tests are green, and a fresh MAS build proves the stale plist was removed and not copied back.
- Direct/debug NightBrain startup now handles the still-staged helper packaging honestly: if `Contents/Library/LaunchAgents/com.epistemos.nightbrain.plist` is absent, `NightBrainScheduler.register()` logs an informational skip before reading `SMAppService.agent.status`, avoiding the previous launch-time registration-failure noise. The actual helper target remains future direct-distribution work.
- Settings privacy copy and `PrivacyInfo.xcprivacy` are now covered by a focused automated gate: `AppStoreHardeningTests` prove no tracking, no tracking domains, no collected-data types, and the expected accessed API reason codes; `PrivacyDetailView.swift` is ASCII-clean and does not overclaim cloud-provider or telemetry behavior. Manual App Store Connect metadata review is still deferred.
- Graph p99 proof freshness.
- Model load/download UI responsiveness.

## App Store/Privacy Risks

- JIT entitlement needs rationale or removal.
- ScreenCaptureKit/AX/CGEvent/shell tools must remain out of MAS. Current fresh binary audit proves no ScreenCaptureKit/AXorcist/`omega_ax` link or bundle path and no dangerous `libomega_mcp` process/PTY symbols.
- Direct-build LaunchAgent/background schedulers must remain out of MAS. NightBrain scheduler and LaunchAgent plist are now gated/excluded with focused release-packaging tests and fresh MAS bundle evidence.
- Cloud providers must disclose user content sent to providers.
- Local model downloads/cache need storage controls and disclosure.
- PrivacyInfo reason APIs must match implementation; current automated proof is green in `/tmp/epistemos_privacy_manifest_and_instrpkg_warning_patch43_tests.log`.
- App size must still be measured before submission. Current `.epdoc` editor resource payload is improved from 5.8M to 1.1M and the MAS bundle preserves the expected `Contents/Resources/Editor` tree, but the full app bundle remains large and needs a top-resource audit.
- Clean Debug MAS bundle-size audit now exists in `docs/audits/APP_BUNDLE_SIZE_AUDIT_2026_04_29.md`: no test plug-in contamination, app 650M, resources 8.6M, editor resources 1.1M, largest payloads are Debug binary/Rust dylibs. Release size proof is still blocked by disk pressure and must be re-run before any ship-size claim.

## Data Integrity Risks

- Derived `.epdoc` `shadow.md` or `search_blocks.jsonl` must not become canonical.
- Raw Thoughts partial final JSONL line must not hide an entire run. Component proof is green; runtime browse smoke remains.
- Delete/rename/move must clear or rebuild graph/search/recall derived stores. Readable-block and GraphStore component proof is green; live app-level propagation still needs smoke.
- Search hit must resolve to artifact ID and block ID.
- Graph must avoid promoting every paragraph into nodes by default.

## Recommended Minimal V1 User Surface

- Native Prose editor.
- Chat with honest model/provider state.
- Search with artifact/block results.
- Graph with current stable controls.
- Contextual Related button behind `EPISTEMOS_AMBIENT_RECALL_V0`; default-on only after runtime click/SLA proof.
- Raw Thoughts under model vault tree only after recovery/provenance proof plus runtime run-link smoke passes.
- Settings with AI, Models, Vault, Recall, Privacy, Advanced.
- Code editor with conservative line gutter only if runtime performance proof passes. Component gates for bounded line metrics, viewport drawing, theme tokens, and initial line-count population are green; do not overclaim runtime p95.
- Documents only if `.epdoc` package/editor/search smoke is green.

## Implementation Patch Plan

Patch ordering:

1. P0 MAS privacy/stub/profile validation.
2. P0 canonical source-of-truth safety checks for `.epdoc`.
3. P1 Contextual Shadows V0 source/state proof and result routing.
4. P1 Instant Recall async-only rebuild guard. Verified on 2026-04-28 with focused tests, source gate, and MAS build.
5. P1 Raw Thoughts live run-link/runtime smoke and streaming-load proof.
6. P1 `.epdoc` open/save/projection/search smoke.
7. P1 Code editor 4k-line component gate, init-time allocation-free line count, and Unicode range tests. Component gate verified on 2026-04-29; full runtime p95 proof remains.
8. P1 search/graph derived-store consistency tests. Component tests verified on 2026-04-28; live app propagation remains.
9. P1 automated Pro/MAS build evidence refresh. Verified on 2026-04-28 after Patches 5-7.
10. P1 deterministic runtime substrate. Phase 0 preflight, typed mutation envelopes, query fingerprints/watch plans, Swift feature flags, a guarded Swift adapter contract, subscription-owned binding, a feature-flagged note outline UI sink, and a scalar borrowed-row projection gate are verified. Next implementation should avoid overclaiming: the note TOC path is user-facing and the borrowed projection path avoids Swift string materialization, but broader `QueryEngine`/search/list UI wiring and visible-row owned materialization remain incomplete.
11. P1 sidecar startup prefetch bounding. Verified on 2026-04-29 with focused `EpistemosSidecarTests` and fresh MAS build; runtime large-vault launch p95 remains a measurement gate.
12. P1 semantic-cluster parallel slot safety. Verified on 2026-04-29 with focused semantic-cluster/runtime-policy tests and fresh MAS build; runtime graph clustering p95 remains a measurement gate.
13. P2 vault FFI Sendable shim cleanup. Verified on 2026-04-29 with focused runtime-policy tests and fresh MAS build.
14. P2 local LSP/speech warning cleanup. Verified on 2026-04-29 with focused runtime-policy tests, targeted warning grep, and fresh MAS build.
15. P2 `.epdoc` WebKit process-pool deprecation cleanup. Verified on 2026-04-29 with source gate, targeted MAS warning grep, and fresh MAS build.
16. P2 CoreSpotlight async indexing cleanup. Verified on 2026-04-29 with source gate, targeted MAS warning grep, and fresh MAS build.
17. P2 Hologram overlay animation completion Sendable cleanup. Verified on 2026-04-29 with focused runtime-policy tests, targeted MAS warning grep, and fresh MAS build.
18. P2 UniFFI generated Sendable patcher cleanup. Verified on 2026-04-29 with generated binding grep, targeted MAS warning grep, and fresh MAS build.
19. P1 lazy AppBootstrap startup call-site enforcement. Verified on 2026-04-29 with focused runtime-policy tests and fresh MAS build.
20. P1 MLX idle unload depth split. Verified on 2026-04-29 with focused runtime/Metal tests, source gate, and fresh MAS build.
21. P1 `.epdoc` AppStore JS Brotli transfer assets. Verified on 2026-04-29 with AppStore and normal Debug bundle-script gates, focused bridge tests, staged/built resource checks, and fresh MAS build. This is not the deferred lazy-chunk/tree-shake work.
22. P1 SSM sidecar compressed-context persistence. Verified on 2026-04-29 with focused sidecar tests, source gates, and fresh MAS build. This is cache persistence only; end-user warm-resume experience still needs runtime validation.
23. P0 SpeechAnalyzer live dictation crash guard. Verified on 2026-04-29 with focused runtime-policy tests, source gates, and fresh MAS builds. Patch 37 removed the double-bound stream shape; Patch 47 added best-compatible-format preparation and mic-buffer conversion; Patch 48 removed MainActor instance access from the AVAudio tap callback. This addresses the observed source-level crash risks; live microphone QA remains a deferred runtime gate.
24. P1 Raw Thoughts bounded inspector tail loading. Verified on 2026-04-29 with focused RawThoughtsState tests, a source/test gate, and fresh MAS build. This closes the automated high-rate inspector memory/UI cliff; live stream cadence and run-link smoke remain runtime gates.
25. P1 Voice Input pulse TimelineView gate. Verified on 2026-04-29 with focused runtime-policy tests, a source gate, and fresh MAS build. This removes the remaining user-facing `.repeatForever` dictation pulse loop.
26. P1 code editor initial gutter line-count population. Verified on 2026-04-29 with focused runtime-policy tests, a source gate, protected-path invariant checks, and fresh MAS build. This closes the blank-initial-gutter UI regression for the right-side code line count; runtime 4k-line scroll p95 remains a later measurement gate.
27. P1 App Store NightBrain scheduler and LaunchAgent exclusion. Verified on 2026-04-29 with focused release-packaging tests, source/bundle gates, protected-path invariant checks, and fresh MAS build. Direct/debug missing-helper registration noise found during this audit is handled by Patch 28.
28. P2 direct NightBrain missing-helper registration guard. Verified on 2026-04-29 with focused release-packaging tests, direct launch-log gate, source gates, protected-path invariant checks, and fresh MAS build. This suppresses false registration-failure noise while the helper target/copy phase remains future direct-distribution work.
29. P2 Performance.instrpkg warning cleanup and S.6 privacy/settings automated gate. Verified on 2026-04-29 with focused `AppStoreHardeningTests` and `PerformanceInstrPkgTests`; the old `PerformanceInstrPkgTests.swift:74` warning is gone and PrivacyInfo checks are green.
30. P1 `.epdoc` Tiptap bundle prune and canonical resource tree. Verified on 2026-04-29 with shell syntax checks, focused bridge/release-script tests, fresh MAS build, and built-app resource gates. This reduces the editor payload to 1.1M and fixes the built-app `Contents/Resources/Editor` path. It is not lazy chunking/tree-shaking.
31. P1 code editor indentation-guide allocation cleanup. Verified on 2026-04-29 with the `RuntimeCapabilityAndPerformancePolicyTests` suite and a fresh MAS build. The indentation guide now avoids full-line splitting/trimming on 4k-line refreshes; runtime typing/scroll p95 remains a later measurement gate.
32. P2 diagnostics and polish.

Full details live in `docs/audits/PATCH_QUEUE.md`.

## Verification Plan

Automated first:

- Pro build.
- MAS build.
- Targeted tests for settings/privacy, recall, Raw Thoughts, `.epdoc`, readable blocks, code editor, graph/search.
- Rust tests for agent_core Raw Thoughts and graph-engine recall/search.
- ASCII/stale-claim grep on audit docs.

Manual later, per user deferral:

- Launch app.
- Create/open vault.
- Create/edit/search note.
- Trigger recall and open result.
- Chat and inspect Raw Thoughts run.
- Open graph and pan/zoom.
- Create/open/save `.epdoc` if surfaced.
- Restart and verify persistence.

## Final Ship Gate

Do not call Epistemos release-ready until:

1. P0 count is zero.
2. P1 user-path tests are green or features stay hidden.
3. MAS profile is verified from raw logs.
4. Prose and graph protected paths are unchanged unless explicitly audited.
5. Privacy manifest/copy/entitlements are aligned.
6. Bundle size is measured.
7. Manual-only Phase S checks are completed later or the milestone is explicitly non-ship.
