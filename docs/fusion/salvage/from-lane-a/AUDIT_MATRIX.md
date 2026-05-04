# Audit Matrix

## Legend

- `PASS`: implemented, wired, and supported by code inspection plus tests
- `PARTIAL`: implemented in some form, but not yet authoritative, not fully wired, or materially perf-risky
- `FAIL`: architecture goal is not met by the current default runtime
- `UNKNOWN`: not enough evidence yet; requires deeper audit or measurement

## Current matrix

| Goal | Status | Why |
|---|---|---|
| 1. Low-latency zero-copy FFI via shared-memory SPSC ring | PARTIAL | The staged knowledge-core path now has a real shared-memory ring and Swift shadow consumer, with direct archive-into-slot writes, layout assertions, explicit fail-fast backpressure stats, a measured `6.36x` faster summary accessor path, and a measured `3.47x` faster batched row accessor path. The default live runtime still uses BTK `Vec<u8>` -> `Data(bytesNoCopy)` -> Swift row/string materialization, and the staged Swift path still copies when creating Swift snapshots. |
| 2. CozoDB-backed Datalog core | PARTIAL | Cozo is embedded and now stays resident in staged knowledge-core, with staged mutations mirrored incrementally into one in-memory `DbInstance`. It is still not the authoritative persistent transactional core, and the live BTK path still uses Cozo only as a helper. |
| 3. Reactive subscriptions / watcher diff pipeline | PARTIAL | The staged store now performs dependency-pattern matching plus incremental touched-row refresh, and the live BTK outline/property helpers now skip full reruns on matching updates. The live Swift query UI still relies on coarse `NotificationCenter` invalidation and Swift re-execution. |
| 4. Loro-based movable-tree CRDT with fractional indexing | FAIL | Loro exists in staged knowledge-core only. The shipping outline path remains BTK `BlockTree` plus a custom index/order system. |
| 5. Unified Org/Markdown parser using `orgize` + `pulldown-cmark` | FAIL | The staged parser instantiates both parser crates, now handles basic Org property drawers correctly, and has a benchmarked line-parser scaffold. It still is not a true event-normalized AST pipeline and is not the live ingest path. |
| 6. SwiftUI integration using `@Observable` and correct `MainActor` boundaries | PARTIAL | The shadow runtime is `@Observable`, main-thread batched, and feature-flagged. The production query/view model flow still does not consume knowledge-core diffs. |
| 7. Mechanical-sympathy performance tuning, RAII, alignment, SIMD, and test coverage | PARTIAL | There is real alignment work in the ring, direct archive writes, and RAII cleanup. There is not yet enough benchmark, fuzz, ABI, or production-path coverage to call the architecture hardened. |

## Area-by-area matrix

### Shared-memory FFI

| Area | Status | Evidence |
|---|---|---|
| Ring exists | PASS | `graph-engine/src/knowledge_core/ring.rs` |
| 128-byte head/tail separation | PASS | compile-time `assert!` + runtime debug assertions in `ring.rs` |
| Swift shared-memory consumer exists | PASS | `Epistemos/Engine/KnowledgeCoreBridge.swift` |
| Default app uses the ring | FAIL | only constructed when `epistemos.knowledgeCore.shadow` is enabled |
| Producer-side zero-copy archive write | PASS | `KnowledgeCore::publish_diff()` -> `SharedRingBuffer::write_archived_frame()` |
| Summary metadata path is reduced | PASS | `KnowledgeCoreBridge.decodeSummary()` now uses `graph_engine_kc_payload_summary(...)` with measured `6.36x` speedup over the old scalar accessor sequence |
| Row decode path is reduced | PASS | `KnowledgeCoreBridge.decodeRows()` now uses `graph_engine_kc_payload_rows(...)` with measured `3.47x` speedup over the old scalar row loop |
| End-to-end zero-copy into UI | FAIL | Swift materializes rows and `String`s in `KnowledgeCoreBridge.decodeRows()` |
| Backpressure policy is explicit | PASS | ring returns `RingError::Full` without overwrite, and staged FFI now exposes `graph_engine_kc_backpressure_policy(...)` plus `graph_engine_kc_transport_stats(...)` |

### Cozo / query core

| Area | Status | Evidence |
|---|---|---|
| Cozo dependency present and live in staged path | PASS | `graph-engine/src/knowledge_core/store.rs` |
| Persistent staged Cozo instance | PASS | one resident `DbInstance` inside `DatalogStore`, incrementally updated via `import_relations(...)` |
| Persistent transactional Cozo store | FAIL | Cozo is still not the authoritative persisted app database |
| Schema for blocks/tasks/properties/links | PARTIAL | staged path has these relations only; tags/refs/pages/order metadata remain incomplete |
| MVCC/time-travel actually used | FAIL | no persistent Cozo backend or snapshot usage is wired |
| Query wrappers exist | PASS | `run_outline_query`, `run_tasks_query`, `run_properties_query`, `run_links_query` |
| Staged hot path is materially safer | PASS | staged watcher refresh no longer pays fresh DB creation/import on matched updates |
| Live BTK hot path is fully safe | PARTIAL | outline/property matched updates are incremental; linked-reference traversal still rebuilds Cozo |

### Watchers / reactivity

| Area | Status | Evidence |
|---|---|---|
| Dependency-pattern filtering exists | PASS | `SubscriptionSpec::matches(&ChangedPatterns)` |
| Row-level diff generation exists | PASS | `diff_rows(...)` in `store.rs` |
| Live UI uses typed diffs | FAIL | live UI still uses `ReactiveQuery` + `NotificationCenter` |
| Irrelevant updates avoid staged watcher reruns | PASS | tested for non-matching page in `store.rs` tests |
| Matching staged updates avoid full query reruns | PASS | `matching_updates_refresh_outline_without_full_query_rerun` + `78.47x` staged watcher benchmark |
| Matching BTK property updates avoid full query reruns | PASS | `matching_property_updates_do_not_reexecute_full_query` + `1.86x` BTK property benchmark |
| Irrelevant updates avoid live query reruns | FAIL | top-level live Swift query path is still coarse invalidation |

### CRDT / ordering

| Area | Status | Evidence |
|---|---|---|
| Staged Loro wrapper exists | PASS | `graph-engine/src/knowledge_core/crdt.rs` |
| Live outline uses Loro | FAIL | live editor path still goes through BTK |
| Fractional ordering exists | PARTIAL | custom ordering exists in both BTK and staged path, but only BTK is live |
| Snapshot/time-travel in active runtime | FAIL | staged only |

### Parser

| Area | Status | Evidence |
|---|---|---|
| `orgize` integrated | PASS | staged parser module |
| `pulldown-cmark` integrated | PASS | staged parser module |
| Canonical shared AST/event normalization | FAIL | normalization still falls back to line-oriented logic |
| Live editor/import path uses unified parser | FAIL | live path remains Swift parsers |

### Swift integration

| Area | Status | Evidence |
|---|---|---|
| `@Observable` state classes are standard pattern | PASS | repo-wide, including `KnowledgeCoreShadowRuntime` |
| Shadow runtime uses batched main-thread apply | PASS | `startIfNeeded(frameInterval: .milliseconds(16))` |
| Shadow runtime feeds production models/views | FAIL | counters only; not integrated with `QueryEngine` or view state |
| Test target currently validates the bridge end-to-end | PARTIAL | Rust bridge tests pass and the app build passes. `KnowledgeCoreBridgeTests.swift` now covers staged backpressure/stats too, but unrelated Swift test-target compile failures still block `xcodebuild test` execution |

### Perf / safety hardening

| Area | Status | Evidence |
|---|---|---|
| Layout assertions added | PASS | `ring.rs` compile-time and runtime assertions |
| Direct archive write replaces temp buffer | PASS | `write_archived_frame()` |
| Unsafe blocks documented/minimized | PARTIAL | ring writer/accessors are documented and the staged knowledge-core FFI entrypoints now carry local `// SAFETY:` justifications; full repo safety audit still pending |
| Fuzz/property coverage for knowledge-core | FAIL | no dedicated fuzz harness yet |
| Benchmark evidence for knowledge-core path | PARTIAL | targeted benchmarks now exist for direct archive writes (`2.70x`), combined summary decode (`6.36x`), batched row decode (`3.47x`), staged incremental watcher refresh (`78.47x`), BTK property watcher refresh (`1.86x`), and a coarse staged parser throughput benchmark; full UI-apply benchmarks still need expansion |

## Current recommendation

Current decision remains:

- `knowledge-core`: keep parallel and feature-flagged
- `BTK + existing graph engine`: keep as the default stable runtime

The staged path is now substantial enough to benchmark and shadow-verify. It is not ready to replace the default runtime.
