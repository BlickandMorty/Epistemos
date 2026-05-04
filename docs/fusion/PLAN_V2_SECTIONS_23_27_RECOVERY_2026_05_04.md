# PLAN_V2 Sections 23-27 Recovery — 2026-05-04

Track: T9 editor, T10 graph, T13 agent runtime, T0 Rust-FFI.

This document promotes the durable substrate rules from
`.claude/worktrees/inspiring-heisenberg-ea9dc3/docs/architecture/PLAN_V2.md`
sections 23-27. It is a recovery bridge, not a bulk doc copy.

## Donor Authority

Source:

- `.claude/worktrees/inspiring-heisenberg-ea9dc3/docs/architecture/PLAN_V2.md`
  sections 23-27.

Current fusion companions:

- `docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md`
- `docs/fusion/WORKTREE_PROTOTYPE_CANON_FUSION_QUEUE_2026_05_04.md`
- `docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md`

## 23. Code Editor Truth And Syntax Data Plane

Before editor optimization, docs must be reconciled against live code. Claimed
features are not real until wired, reachable, visible, and verified.

Verified donor claims to preserve:

- code-like content routes to `CodeEditorView`; prose routes to the prose editor
  path;
- the current code editor path depends on `CodeEditSourceEditor` and has an
  O(n) `Binding<String>` integration acceptable only for smaller files;
- the prose editor path is better scoped because it limits expensive work to
  edited paragraphs and nearby lines;
- docs such as `CODE_EDITOR_FEATURE_AUDIT.md` may claim active features that
  require live verification before optimization.

Hybrid architecture:

- Swift / native editor shell owns text input, IME, selection, undo/redo,
  accessibility, scrolling, and native editing behavior.
- Rust owns incremental parsing, syntax token generation, folds, diagnostics,
  outline extraction, generation counters, stale-parse cancellation, and UTF-8
  document math.
- FFI carries edit deltas, viewport requests, and compact viewport-scoped
  token/fold/diagnostic outputs.
- Metal may render minimaps, gutter decorations, diagnostics heatmaps, diff
  overlays, and background decoration layers. It must not own text input.

Viewport-scoped token materialization:

- send edit deltas, not full document text;
- reparse incrementally;
- request tokens only for visible range plus margin;
- use numeric token IDs, not token-kind strings;
- discard stale generations;
- never retain Rust token-buffer pointers in Swift state.

Benchmark gate:

- no editor migration until open time, first paint, keystroke-to-highlight,
  fold/outline update latency, scroll FPS/hitches, memory growth, binding-sync
  main-thread time, token parse time, allocation count, and copy count are
  captured.

Targets:

- under 16ms keystroke-to-highlight;
- under 500ms open time for 50K-line files;
- stable 60fps / 120fps scroll;
- no unbounded memory growth during continuous typing.

## 24. Agent Streaming Data Plane

Only high-frequency streaming events justify optimized transport. Session
creation, permission gates, approval loops, provider selection, audit, lineage,
and setup calls stay on the current bridge unless benchmarks prove otherwise.

The first optimization is token coalescing, not a transport rewrite:

- collect text/thinking tokens for 16ms;
- deliver one frame-aligned batch to Swift;
- reduce crossings from roughly 100-300/sec to roughly 60/sec;
- never coalesce or drop errors, approval requests, completion events, or
  cancellation acknowledgements.

Backpressure must be measured and visible. Acceptable options include an SPSC
ring, pull-based frame polling, or a shared pause flag, but activation must emit
telemetry.

Cancellation is Rust-owned: Swift sends typed cancel intent; Rust tears down the
session/task; Swift ignores stale generations. Approval, error, and completion
events are still delivered.

## 25. Graph Zero-Copy Rendering

Graph zero-copy is gated by benchmarks. The sequence is:

1. typed buffers with synchronous copy;
2. benchmark and prove copy is the bottleneck;
3. only then introduce triple-buffered `MTLBuffer` with `.storageModeShared`.

The desired data layout is struct-of-arrays:

- positions as contiguous `f32`;
- sizes as contiguous `f32`;
- colors as contiguous `u32`;
- edge source/target pairs uploaded on mutation;
- label strings kept in a separate id-to-string table.

Do not prematurely optimize for zero-copy when typed buffers are already fast
enough.

## 26. Recovery Session Order

The donor order remains useful:

1. Editor doc-truth audit before optimization.
2. Benchmark harness and signpost/divan baselines before signature changes.
3. Swift 6 concurrency hardening for verified violations.
4. Graph typed-buffer prototype behind a compatibility flag.
5. Graph Chat receiver wiring through the existing ACC/Rust compile path.
6. `syntax-core` scaffolding and benchmarks before editor wiring.
7. Agent streaming instrumentation before coalescing or transport migration.

Future editor syntax bridge, agent streaming transport, Rust canonical rope,
Metal editor overlays, and graph zero-copy shared buffers are conditional on
benchmarks.

## 27. Anti-Patterns

The recovered prohibitions:

- do not mass-migrate every bridge to BoltFFI;
- do not rebuild the code editor before benchmarks;
- do not put routing or permissions in Swift;
- do not create a second graph chat architecture;
- do not move text input, IME, or accessibility out of native macOS;
- do not pass full document text across FFI every keystroke;
- do not apply syntax attributes to the full file every keystroke;
- do not migrate embeddings/vector payloads in the first bridge wave;
- do not migrate approval or routing semantics out of Rust sovereignty;
- do not replace the editor shell before benchmarking;
- do not choose `crop` over `ropey` without benchmark evidence;
- do not bundle editor tree-sitter into `graph-engine`;
- do not optimize features that only exist in documentation;
- do not treat a faster bridge as a substitute for event coalescing;
- do not require a new bridge toolchain for the first typed-buffer prototype.

## Supersession Note

PLAN_V2 §23.5 says `SyntaxDocumentHandle` uses `Box::into_raw` and
`syntax_document_free`. That detail is superseded by the honest-handle doctrine
and current `syntax-core/src/honest_handle.rs`, which uses an Arc-backed opaque
handle and balanced retain/release. Keep the §23.5 flat data shapes, but use
honest-handle ownership for live handles.

## Recovery Placement

Recovery stage:

- A-F recovery: preserve the laws, audit requirements, and benchmark gates.
- T9 editor: reconcile doc claims before any editor migration.
- T10 graph: typed-buffer first; zero-copy only after proof.
- T13 agent runtime: coalesce and instrument before transport migration.
- T0 FFI: pair these sections with honest-handle doctrine for ownership.
