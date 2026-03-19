# State Of System

## Scope

This document reflects the repo as inspected on 2026-03-19. It distinguishes:

- `live path`: code that is currently wired into the default app runtime
- `staged path`: code that compiles and is partially wired, but is off by default or not yet authoritative

## High-level verdict

Epistemos currently runs two architectures in parallel:

- Live graph/render/runtime path: SwiftUI + SwiftData + Rust `graph-engine`
- Live note/query path: Swift `BlockEditTranslator` + Rust BTK (`BlockTree`, `OpLog`, `BtkQueryKernel`) + Swift `QueryRuntime`
- Staged next-gen path: Rust `knowledge_core` with shared-memory ring, Cozo wrapper, Loro wrapper, unified parser scaffold, and a Swift shadow bridge

The design brief is still not true for the shipping default runtime:

- Shared-memory zero-copy FFI is not the default UI/query path.
- Cozo is not the authoritative persistent transactional core.
- Loro is not the live outline CRDT.
- Unified Org/Markdown parsing is not the live ingest/editor path.

What changed during this audit:

- The staged knowledge-core path now has a real Swift consumer behind a feature flag in [AppBootstrap.swift](/Users/jojo/Epistemos/Epistemos/App/AppBootstrap.swift).
- The staged Rust publish path no longer serializes through an intermediate `Vec<u8>` before ring write.
- The staged FFI now exposes last-error code/message instead of hiding all failures behind bare `0/1`.
- The staged Swift summary drain path now uses one validated payload-summary accessor instead of six scalar metadata calls.
- The staged Swift row drain path now uses one validated batched row accessor per section instead of one row accessor call per row.
- The staged FFI now exposes explicit fail-fast backpressure policy and transport stats.
- The app icon/build regression caused by project resource drift was fixed; `AppIcon.icon` is back in the asset pipeline and the macOS build emits `AppIcon.icns` again.

## What is live today

### 1. Rust graph engine

Live files:

- `graph-engine/src/engine.rs`
- `graph-engine/src/lib.rs`
- `Epistemos/Graph/GraphEngine.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`

Status:

- Rust owns Metal render + physics core.
- Swift calls into Rust through the stable C header.
- Batch node/edge uploads are live.
- This path is unrelated to the staged knowledge-core ring.

### 2. BTK note mutation path

Live files:

- `Epistemos/Engine/BlockEditTranslator.swift`
- `graph-engine/src/block_kernel/translator.rs`
- `graph-engine/src/block_kernel/block_tree.rs`
- `graph-engine/src/block_kernel/op_log.rs`
- `graph-engine/src/lib.rs`

Status:

- NSTextStorage edits are translated into BTK ops.
- Rust stores page-local `BlockTree` plus append-only `OpLog`.
- After each mutation, `sync_btk_query_kernel()` rematerializes BTK facts and updates BTK subscriptions.

### 3. Live query path

Live files:

- `Epistemos/Engine/QueryRuntime.swift`
- `Epistemos/Engine/ReactiveQuery.swift`
- `Epistemos/Engine/QueryEngine.swift`
- `Epistemos/Graph/GraphStore.swift`
- `Epistemos/Sync/SearchIndexService.swift`

Status:

- Most query execution is still Swift-side against `GraphStore` and GRDB-backed search.
- BTK is used for property/depth helpers and a subscription API, but not as the main UI query driver.
- Reactive queries still rerun from `NotificationCenter` invalidations, not typed Rust watcher diffs.

### 4. Persistence

Live files:

- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Sync/VaultSyncService.swift`

Status:

- SwiftData is the primary app persistence layer.
- GRDB/SQLite search index exists as a separate search subsystem.
- Vault `.md` files are import/export targets.
- Rust BTK state is in-memory and rebuilt per page session.
- Rust knowledge-core has no live persistent backing store.

## What is staged only

### 1. Shared-memory knowledge core

Staged files:

- `graph-engine/src/knowledge_core/mod.rs`
- `graph-engine/src/knowledge_core/ring.rs`
- `graph-engine/src/knowledge_core/store.rs`
- `graph-engine/src/knowledge_core/crdt.rs`
- `graph-engine/src/knowledge_core/parser.rs`
- `graph-engine-bridge/graph_engine.h`
- `Epistemos/Engine/KnowledgeCoreBridge.swift`

Status:

- Rust shared-memory ring exists.
- Rust FFI entry points exist.
- Swift now maps the shared region directly and drains staged diffs.
- The staged bridge is off by default and only created when `UserDefaults.standard.bool(forKey: "epistemos.knowledgeCore.shadow")` is true.
- The shadow runtime currently records batches into observable counters; it does not yet replace `QueryRuntime`, `GraphStore`, or view models.

### 2. Loro outline runtime

Staged files:

- `graph-engine/src/knowledge_core/crdt.rs`

Status:

- Loro is compiled and tested in Rust.
- It is not used by the shipping note editor or BTK mutation flow.

### 3. Markdown/Org unified parser

Staged files:

- `graph-engine/src/knowledge_core/parser.rs`

Status:

- Uses `orgize` and `pulldown-cmark` to instantiate/advance parsers.
- Actual normalization is still line-based in important paths, not a canonical event-driven AST pipeline.
- Not used by the live import/editor/query flow.

## Immediate audit findings

1. The repo still contains two runtimes:
   - BTK: live and authoritative
   - knowledge-core: staged and measurable, but not authoritative

2. Several design claims are true only for the staged path:
   - shared-memory diff transport
   - 128-byte padded SPSC ring layout
   - direct archive-into-ring writes
   - typed watcher diff envelopes
   - Loro outline operations

3. The live Swift query UI is still coarse invalidation:
   - `GraphStore.notifyChange()` posts `graphStoreDidChange` after 50 ms
   - `ReactiveQuery` adds another 100 ms debounce
   - steady-state query freshness is roughly 150 ms before view work

4. The live BTK subscription path still copies aggressively:
   - Rust serializes archived payloads into `Vec<u8>`
   - Swift wraps bytes in `Data`
   - Swift decodes rows into arrays of Swift structs
   - Swift decodes each archived string into a new `String`

5. The staged knowledge-core producer path is materially better than before:
   - `KnowledgeCore::publish_diff()` now archives directly into the reserved ring slot
   - no intermediate `Vec<u8>` is created on the staged producer hot path

6. The staged Swift consumer is not end-to-end zero-copy:
   - transport is zero-copy up to the mapped slot payload
   - Swift now crosses FFI once for staged summary metadata and once per section for full payload decoding in the common path
   - Swift still materializes rows and strings into owned Swift values for UI-safe snapshots

7. Operability is still weak on the staged path:
   - `graph_engine_kc_*` mutation functions still collapse return values to `0/1`
   - but Swift can now inspect typed staged failures through last-error code/message
   - and the staged transport now reports explicit `FailFast` policy plus publish/failure counters

8. One measured staged hot path improved materially:
   - staged scalar summary decode path: `34045 ns/decode`
   - staged combined summary accessor path: `5481 ns/decode`
   - measured speedup: `6.21x`

9. A second staged hot path improved materially:
   - staged scalar row decode path: `12506 ns/payload`
   - staged batched row accessor path: `3807 ns/payload`
   - measured speedup: `3.28x`

10. Full app test execution is still blocked by unrelated test-target compile debt:
   - `LandingExperienceSettingsTests.swift` is fixed now
   - broader Swift 6 migration failures remain in unrelated test files such as `ConcurrencyEdgeCaseTests.swift` and `ConcurrencyStressTests.swift`
   - the app build succeeds, but isolated `KnowledgeCoreBridgeTests` still cannot run under `xcodebuild test` until the broader test target compiles again

## Baseline conclusion

The repository is in a parallel-runtime transition state. The correct posture is still:

- keep BTK and the existing graph engine as the stable path
- continue auditing and benchmarking the knowledge-core path in parallel
- use the shadow bridge for measurement and correctness verification
- do not replace the live runtime until parity and performance are proven
