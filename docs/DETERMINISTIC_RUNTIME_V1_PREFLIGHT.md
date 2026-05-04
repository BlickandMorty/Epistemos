# Deterministic Knowledge Runtime V1 Preflight

Date: 2026-04-28

## Executive Verdict

Phase 0 is complete enough to proceed to design, but not to implementation beyond scoped tests.

The repo already has two separate realities:

1. Live production query UI still runs through `GraphStore` / `SearchIndexService` notifications, `ReactiveQuery`, and `QueryRuntime`.
2. Staged knowledge-core already has a Rust-side dependency-aware store, a shared-memory ring, Swift draining, and shadow counters/projection stats.

The staged path is not production-wired. `KnowledgeCoreShadowRuntime` updates counters and projection-cache stats in `Epistemos/Engine/KnowledgeCoreBridge.swift:627-770`; it does not update production note/search/graph view models. Do not claim end-to-end deterministic UI performance yet.

## Current Live Path

### Graph mutation to query update

Runtime path:

`GraphStore mutation -> GraphStore.notifyChange -> NotificationCenter.graphStoreDidChange -> ReactiveQuery.shouldInvalidate -> ReactiveQuery.reevaluate -> QueryRuntime.execute -> AsyncStream<QueryResult> -> query UI`

Evidence:

- `Epistemos/Graph/GraphStore.swift:820-828` adds a node and posts `.graphNodes`.
- `Epistemos/Graph/GraphStore.swift:866-887` adds an edge and posts `.graphEdges`.
- `Epistemos/Graph/GraphStore.swift:890-937` removes a node and posts `.graphNodes` + `.graphEdges`.
- `Epistemos/Graph/GraphStore.swift:982-987` posts `.graphStoreDidChange` with `QueryDependencyKey` userInfo.
- `Epistemos/Models/QueryTypes.swift:199-250` defines dependency classes and maps query steps to coarse dependencies.
- `Epistemos/Engine/ReactiveQuery.swift:54-64` subscribes to graph/search notifications.
- `Epistemos/Engine/ReactiveQuery.swift:95-104` intersects notification keys with plan dependencies.
- `Epistemos/Engine/ReactiveQuery.swift:79-92` debounces 35 ms and reruns the whole `QueryRuntime` plan.

Strength:

- Dependency scoping exists at a coarse class level (`graphNodes`, `graphEdges`, `searchPages`, `searchBlocks`).
- Focused tests prove irrelevant graph/search dependency notifications can be ignored.

Gap:

- No stable query fingerprint type exists.
- No watch plan exists beyond coarse `QueryDependencyKey` classes.
- A relevant mutation still triggers a full `QueryRuntime.execute` for that plan.
- Fallback for unscoped notifications is intentionally broad (`ReactiveQuery.swift:95-99`).

### Search mutation to query update

Runtime path:

`SearchIndexService upsert/delete -> notifyIndexChanged -> NotificationCenter.searchIndexDidUpdate -> ReactiveQuery.shouldInvalidate -> QueryRuntime.execute -> query UI`

Evidence:

- `Epistemos/Sync/SearchIndexService.swift:590-604` upserts a block and posts `.searchBlocks`.
- `Epistemos/Sync/SearchIndexService.swift:618-634` upserts a page and posts `.searchPages`.
- `Epistemos/Sync/SearchIndexService.swift:666-674` deletes a page and posts `.searchPages`.
- `Epistemos/Sync/SearchIndexService.swift:709-716` marshals notification posting onto `MainActor`.
- `Epistemos/Engine/ReactiveQuery.swift:60-64` listens for `.searchIndexDidUpdate`.

Strength:

- Page and block search invalidation domains are separated.

Gap:

- Notifications do not carry artifact IDs, block IDs, relation kinds, or operation kinds.
- Search updates are still coarse by index domain, not by affected query/watch plan.

## Current Staged Knowledge-Core Path

### Rust mutation to ring publication

Runtime path:

`KnowledgeCore API mutation -> parser/store mutation -> ChangedPatterns -> subscription match -> incremental diff or query rerun -> QueryDiffEnvelope -> SharedRingBuffer.write_archived_frame`

Evidence:

- `graph-engine/src/knowledge_core/mod.rs:240-246` ingests a document, parses it, replaces page facts, and publishes diffs.
- `graph-engine/src/knowledge_core/mod.rs:249-292` inserts a block and publishes diffs.
- `graph-engine/src/knowledge_core/mod.rs:295-310` moves a block and publishes diffs.
- `graph-engine/src/knowledge_core/mod.rs:313-321` deletes a block and publishes diffs.
- `graph-engine/src/knowledge_core/mod.rs:337-345` publishes archived diffs into the ring and updates transport stats.
- `graph-engine/src/knowledge_core/store.rs:54-84` matches subscriptions against changed pages/relations/keys/block IDs.
- `graph-engine/src/knowledge_core/store.rs:452-505` increments tx, schedules only matching subscriptions, and attempts incremental refresh before full query.
- `graph-engine/src/knowledge_core/store.rs:796-1020` contains per-subscription incremental refresh paths for outline, tasks, properties, and links.
- `graph-engine/src/knowledge_core/store.rs:1366-1412` tests non-matching page suppression and no-full-query outline movement refresh.

Strength:

- Rust store already has dependency-aware changed patterns and incremental subscription refresh.
- Diffs are typed by subscription kind and carry tx/subscription IDs in `QueryDiffEnvelope`.

Gap:

- There is no exported `MutationEnvelope` type with the required fields from the implementation prompt.
- There is no exported `QueryFingerprint` or `WatchPlan`.
- The current Rust matching is internal to the staged store, not a general app-wide production invalidation contract.

### Ring transport

Runtime path:

`QueryDiffEnvelope -> rkyv archive directly into ring slot -> Rust publishes head -> Swift drains slot by head/tail -> Swift advances tail`

Evidence:

- `FFI_AUDIT.md` classifies the staged ring as passing shared-memory SPSC shape, cache-line separation, Acquire/Release ordering, and producer-side direct archive writes.
- `graph-engine/src/knowledge_core/ring.rs` owns the mmap-backed ring and layout assertions.
- `Epistemos/Engine/KnowledgeCoreBridge.swift:334-372` reads ring head/tail, decodes summaries/payloads, applies projection stats, and advances tail.

Strength:

- Transport and layout are measured and tested.
- Backpressure is fail-fast and observable through transport stats.

Gap:

- Swift still materializes `KnowledgeCorePayloadSummary`, `KnowledgeCoreRowSnapshot`, `String`, and arrays when decoding full payloads.
- The projection cache stores Swift `String`s, not true borrowed row views.
- Updated 2026-04-29: `KnowledgeCoreBridge.drainBorrowedProjections` now provides a lifetime-contained scalar projection gate that reads row slices before tail advance and reports `materializedStringCount == 0`; visible/focused owned row materialization is still missing.

### Swift staged consumer

Runtime path:

`KnowledgeCoreShadowRuntime.startIfNeeded -> utility polling task -> bridge.drainProjectedSummaries -> MainActor.applyBatch -> counters/projection stats`

Evidence:

- `Epistemos/Engine/KnowledgeCoreBridge.swift:627-645` exposes counters and last batch state.
- `Epistemos/Engine/KnowledgeCoreBridge.swift:714-750` drains on a utility task and batches MainActor application.
- `Epistemos/Engine/KnowledgeCoreBridge.swift:759-770` applies batch metrics to observable state.

Strength:

- Polling is off the main actor and only batched state apply hops back.
- Focused Swift tests prove draining, error surfacing, backpressure stats, batching, and projection-cache reuse.

Gap:

- Shadow runtime polling still updates counters/projection stats only.
- Updated 2026-04-28: `deterministicKnowledgeCoreRuntime`, `borrowedKnowledgeRows`, `rawThoughtsBulkLane`, `staticArtifactRouting`, and `graphEdgePrefetch` now exist in `Epistemos/Engine/Log.swift` and default off.
- Updated 2026-04-28: a narrow note-outline production sink now consumes real outline payloads behind `deterministicKnowledgeCoreRuntime`, but broader `QueryEngine`/search/list UI wiring is still incomplete.

## Known Blockers

| Blocker | Severity | Evidence | Required next step |
|---|---:|---|---|
| Broader production adapter incomplete | P1 | Updated 2026-04-28: Patch 17 wires a feature-flagged note-outline sink, but `QueryEngine`/search/list views still use the old runtime | Extend only after each view owns its subscription and fallback path |
| Borrowed row scalar projection gate implemented | P1 | Updated 2026-04-29: `KnowledgeCoreBridge.drainBorrowedProjections` projects row hashes/counts/scalars without materializing Swift strings; `/tmp/epistemos_borrowed_projection_patch18_tests.log` passed | Add visible/focused owned-row materialization before enabling the flag in production UI |
| Mutation envelope substrate implemented | Done | Updated 2026-04-28: `MutationEnvelope` and real mutation-path tests landed in `graph-engine/src/knowledge_core/store.rs`; see `/tmp/epistemos_deterministic_phase1_knowledge_core.log` | Keep as regression surface |
| QueryFingerprint/WatchPlan substrate implemented | Done | Updated 2026-04-28: stable fingerprints, watch plans, and intersection tests landed in `graph-engine/src/knowledge_core/store.rs`; see `/tmp/epistemos_deterministic_phase2_knowledge_core.log` | Keep as regression surface |
| Swift materialization still too eager for full payload/UI paths | P1 | `KnowledgeCoreBridge.decodeRows` still returns `[KnowledgeCoreRowSnapshot]` and decodes `String`s for owned drains; borrowed scalar projection is tested but not used by visible rows yet | Add visible-range materialization and prove offscreen rows avoid owned strings before any end-to-end zero-copy claim |
| Live query runtime still MainActor | P1 | `ReactiveQuery` and `QueryRuntime` are `@MainActor`; reevaluation calls `runtime.execute` after debounce in `Epistemos/Engine/ReactiveQuery.swift:79-92` | Measure and isolate before moving heavy work |
| Full Swift suite not refreshed here | P2 | Focused suites pass; full suite was not run in this Phase 0 pass | Run full suite only after deterministic Phase 1/2 test scaffolding settles |

## Exact Files To Patch Next

Phase 1 candidate files:

- `graph-engine/src/knowledge_core/store.rs`
- `graph-engine/src/knowledge_core/mod.rs`
- `graph-engine/src/knowledge_core/archived.rs`
- `graph-engine/src/lib.rs`
- `graph-engine-bridge/graph_engine.h` only if envelope/diagnostic FFI is exposed
- `EpistemosTests/KnowledgeCoreBridgeTests.swift` only for bridge-visible behavior

Phase 2 candidate files:

- `graph-engine/src/knowledge_core/store.rs`
- new Rust test module if the existing file gets too dense
- `Epistemos/Models/QueryTypes.swift` only if Swift watch-plan parity is needed
- `EpistemosTests/QueryRuntimeTests.swift` for existing live-query fallback behavior

Do not touch yet:

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Notes/ProseEditorRepresentable*.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Graph/HologramController.swift`
- broad app shell or UI routing

## Current Benchmark Commands

Rust:

```bash
cargo test --manifest-path graph-engine/Cargo.toml knowledge_core -- --nocapture
cargo test --manifest-path graph-engine/Cargo.toml knowledge_core::ring -- --nocapture
cargo test --manifest-path graph-engine/Cargo.toml benchmark_knowledge_core_payload_summary_accessor -- --ignored --nocapture
cargo test --manifest-path graph-engine/Cargo.toml benchmark_knowledge_core_payload_rows_batch_accessor -- --ignored --nocapture
```

Swift:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-deterministic-phase0 test -only-testing:EpistemosTests/KnowledgeCoreBridgeTests -only-testing:EpistemosTests/QueryRuntimeTests CODE_SIGNING_ALLOWED=NO
```

Build refresh:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-derived-store-patch7 build CODE_SIGNING_ALLOWED=NO
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' -derivedDataPath /tmp/epistemos-dd-mas-patch8-refresh build CODE_SIGNING_ALLOWED=NO
```

## Baseline Results

| Command/log | Result | Notes |
|---|---|---|
| `/tmp/epistemos_deterministic_phase0_knowledge_core.log` | `EXIT:0`, 23 passed, 5 ignored | full `knowledge_core` filter |
| `/tmp/epistemos_deterministic_phase0_ring.log` | `EXIT:0`, 6 passed, 1 ignored | ring layout/backpressure/roundtrip filter |
| `/tmp/epistemos_deterministic_phase0_summary_bench.log` | `EXIT:0`; `scalar_ns_per_decode=16348`, `summary_ns_per_decode=2724`, `speedup_x=6.00` | ignored benchmark run explicitly |
| `/tmp/epistemos_deterministic_phase0_rows_bench.log` | `EXIT:0`; `scalar_ns_per_payload=12048`, `batch_ns_per_payload=3761`, `speedup_x=3.20` | ignored benchmark run explicitly |
| `/tmp/epistemos_deterministic_phase0_swift_tests.log` | `** TEST SUCCEEDED **`, `EXIT:0`; 32 Swift Testing tests passed | `KnowledgeCoreBridgeTests` + `QueryRuntimeTests`; XCTest wrapper reports 0 tests before Swift Testing summary |
| `/tmp/epistemos_pro_build_patch8_refresh.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | Pro build after Patches 5-7 |
| `/tmp/epistemos_mas_build_patch8_refresh.log` | `** BUILD SUCCEEDED **`, `EXIT:0` | MAS build after Patches 5-7 |

Warnings:

- Swift build/test logs still show generated UniFFI redundant `Sendable` warnings.
- Swift build/test logs still show the known CodeEdit SwiftLint plugin tail noise after success.
- NightBrain LaunchAgent test-runtime warnings appear in focused Swift logs; they did not fail the selected tests.

## Whether Swift Tests Are Blocked

Focused Swift tests for deterministic Phase 0 are not blocked:

- `KnowledgeCoreBridgeTests`: passed.
- `QueryRuntimeTests`: passed.

Full Swift suite status is not established by this Phase 0 pass. Do not use this preflight to claim full CI health.

## Phase 1 Entry Criteria

Before coding a production adapter, add tests proving:

1. Real document ingest emits a typed mutation envelope.
2. Real block insert/move/delete emit precise touched IDs and affected-class flags.
3. Link/relation changes are represented distinctly from body/order changes.
4. Irrelevant mutations do not invalidate unrelated watchers.
5. Unsupported query/watch types fall back conservatively without silently skipping invalidation.

Only after those are green should Swift adapter work begin.
