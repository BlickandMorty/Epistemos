# Performance + Concurrency Audit

Date: 2026-04-28

Verdict: The largest remaining risks are unproven hot paths, not missing ambition. The app has good patterns in many places, but V1 cannot claim native-fast until recall, code editing, streaming, graph, and document save paths have targeted proof.

## Findings

| Finding | File | MainActor risk? | User symptom | Fix | Priority | Test |
|---|---|---:|---|---|---:|---|
| Instant Recall sync rebuild entrypoints are guarded, but p95 proof is missing | `Epistemos/KnowledgeFusion/InstantRecallService.swift`; `Epistemos/Sync/VaultSyncService.swift` | REDUCED | Large-vault import/search could still exceed latency budget | Keep async-only source gate; add 1000-note signpost/p95 proof before default-on claims | P1 | 1000-note async rebuild/search p95 signpost |
| Contextual Shadows V0 lacks end-to-end latency proof | `Epistemos/State/ContextualShadowsState.swift`; `Epistemos/Views/Recall/*` | PARTIAL | Button/panel may hitch or return stale hits | Add state test plus signpost around request/apply | P1 | typing snapshot -> result apply p95 budget |
| Code editor still reads whole text on edit, but line-count and indentation-guide components are now cheap/tested | `Epistemos/Views/Notes/CodeEditorView.swift`; `Epistemos/Views/Notes/SegmentedIndentationGuideView.swift` | YES at scale | 4k+ line typing hitch if other edit work grows | Keep Swift live editor, preserve `CodeEditorLineMetrics` and the single-pass indentation parser, measure actual typing/scroll p95 before deeper edits | P1 | full 4k-line typing and scroll runtime benchmark |
| Code editor right-side gutter width/theme policy is tested; live scroll proof is still missing | `Epistemos/Views/Notes/CodeEditorView.swift`; `Epistemos/Views/Notes/CodeLineGutter.swift` | POSSIBLE | Scroll jank or theme conflict | Component tests are green; add Instruments/runtime scroll proof before claiming Xcode-level fluidity | P1 | scroll 4k-line file with gutter enabled |
| Syntax highlighting path has UTF-8 to UTF-16 runtime cost risk | `Epistemos/Views/Notes/CodeEditorView.swift`; `Epistemos/Engine/SwiftTreeSitterLiveHighlighter.swift` | POSSIBLE | Wrong highlights/crashes with Unicode or costly whole-text highlight | Unicode mapping tests are green; measure whole-text versus visible-range highlighting before optimizing | P1 | emoji/CJK source fixture plus large-file p95 |
| `.epdoc` WebView save pipeline needs runtime latency proof | `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`; `Epistemos/Engine/EpdocDocument.swift` | PARTIAL | typing/save stalls or stale projection | Keep WebView reused/prewarmed; debounce save; measure save projection time | P1 | edit -> autosave -> projection under budget |
| Readable block replacement component behavior is green, but live producer scheduling still needs proof | `Epistemos/Sync/ReadableBlocksIndex.swift` | NO if called off-main | stale or partial search projection | Keep `replaceAllForArtifact` transactional; verify callers run projection/indexing off hot UI paths | P1 | live save/delete/rename indexing smoke |
| Raw Thoughts inspector loading now has a detached, testable recovery seam, but streaming UI batching still needs proof | `Epistemos/Views/RawThoughts/RawThoughtsInspectorView.swift`; `agent_core/src/storage/raw_thoughts.rs` | REDUCED | token-stream UI churn or unbounded logs | Keep inspector file I/O off MainActor; prove append batching and UI scan behavior | P1 | 100+ events/sec synthetic run |
| MLX/model loading remains a risk area | `Epistemos/Engine/MLXInferenceService.swift`; `ModelDownloadManager.swift` | POSSIBLE | model swap freezes UI | Keep heavy load/download off main and signposted | P1 | cold load while scrolling chat/vault |
| Graph renderer protected, but 10K-node p99 proof is not fresh | `Epistemos/Views/Graph/MetalGraphView.swift`; `graph-engine/src/*` | POSSIBLE | pan/zoom stutter | Rust graph-engine regression proof is green (`/tmp/epistemos_graph_engine_full_after_dirty_diff.log`, 2522 passed / 8 ignored, plus three physics audit passes), but do not claim UI smoothness until graph frame p99/signpost evidence exists | P1 | graph frame p99 evidence |
| Settings privacy pane builds into MAS | `Epistemos/Views/Settings/SettingsView.swift` | LOW | build failure or overclaim | Keep exact copy and tests | P0 | MAS scheme build |

## Acceptance Targets

| Surface | Target |
|---|---|
| Prose typing | No regression from protected editor; no new sync disk/FFI work |
| Code editor 4k lines | Smooth scroll and typing with syntax colors; p95/p99 recorded |
| Recall search | No MainActor FFI/search work except final state apply |
| Raw Thoughts streaming | No per-token SwiftUI state mutation; bounded logs |
| `.epdoc` editing | WebView reused; debounced save; projection work measured |
| Graph | No full rebuild on every save; frame p99 captured before ship claim |
| App launch | No vault crawl, embedding, model load, or graph recompute blocking launch |

## Instrumentation Recommendations

- `recall.request`, `recall.search`, `recall.apply`
- `codeEditor.textDidChange`, `codeEditor.highlight`, `codeEditor.scroll`
- `epdoc.save`, `epdoc.project.shadow`, `epdoc.project.searchBlocks`
- `rawThoughts.append`, `rawThoughts.scan`, `rawThoughts.uiApply`
- `graph.frame`, `graph.dataApply`
- `vault.index.update`, `search.readableBlocks.replace`

## Protected Paths

- Do not touch `Epistemos/Views/Notes/ProseEditor*.swift` unless a failing test proves a recall hook is broken.
- Do not touch `graph-engine/**`, `Epistemos/Views/Graph/MetalGraphView.swift`, or Hologram controller physics/rendering unless a dedicated graph perf audit clears it.

## P0/P1 Actions

1. Run MAS and Pro builds after any Settings, entitlement, or Info.plist change.
2. Add code-editor runtime benchmark for 4k-line typing/scroll/gutter/indent guides. Component line-count/gutter tests passed in `/tmp/epistemos_code_editor_patch6_tests.log`; indentation-guide single-pass refresh passed in `/tmp/epistemos_code_indent_guide_patch46_suite_tests.log`; full p95 proof remains open.
3. Add recall end-to-end state test and signposts.
4. Add Raw Thoughts synthetic event stream test.
5. Add `.epdoc` save/projection latency test before default user exposure.
