# Architecture Map

## 1. Current Rust -> FFI -> Swift -> SwiftUI data flow

### Live graph/render path

```text
SwiftData models
  -> GraphBuilder / GraphStore
  -> MetalGraphView batch builders
  -> GraphEngine.swift typed FFI wrapper
  -> graph_engine.h
  -> Rust graph-engine (Engine, Simulation, Renderer)
  -> Metal rendering
```

Key files:

- `Epistemos/Graph/GraphStore.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Graph/GraphEngine.swift`
- `graph-engine/src/engine.rs`

### Live BTK subscription path

```text
Swift note edit
  -> BlockEditTranslator.translateEdit(...)
  -> graph_engine_btk_translate_edit(...)
  -> Rust BlockTree + OpLog mutation
  -> sync_btk_query_kernel(...)
  -> BtkQueryKernel diff payload (rkyv bytes in Vec<u8>)
  -> graph_engine_btk_take_subscription_update(...)
  -> Swift GraphEngine.decodeBTKPayload(...)
  -> Swift arrays / Strings
  -> optional BTKSubscriptionState polling
```

Important note:

- `BTKSubscriptionState` exists, but the main app query UI does not depend on it today.
- The live query UI is therefore not currently driven by BTK row diffs.

### Staged knowledge-core shadow path

```text
AppBootstrap feature flag
  -> KnowledgeCoreShadowRuntime (@Observable, @MainActor)
  -> KnowledgeCoreBridge actor
  -> graph_engine_kc_ring_region/layout/head/tail
  -> mapped shared memory slot payload
  -> graph_engine_kc_payload_* accessors
  -> KnowledgeCorePayloadSummary / KnowledgeCorePayloadSnapshot
  -> MainActor applyBatch(...)
  -> shadow counters only (not production view models yet)
```

Key files:

- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/Engine/KnowledgeCoreBridge.swift`
- `graph-engine/src/knowledge_core/mod.rs`
- `graph-engine/src/knowledge_core/ring.rs`
- `graph-engine/src/lib.rs`

Important note:

- This path is real and testable, but it is off by default.
- Swift maps the ring directly, but still uses Rust FFI helpers to validate and project archived rows.

### Live query UI path

```text
SwiftData / GraphStore / SearchIndex mutations
  -> NotificationCenter posts
  -> ReactiveQuery debounce
  -> QueryRuntime full step execution in Swift
  -> QueryEngine.currentResult
  -> SwiftUI views
```

Key files:

- `Epistemos/Engine/ReactiveQuery.swift`
- `Epistemos/Engine/QueryRuntime.swift`
- `Epistemos/Engine/QueryEngine.swift`
- `Epistemos/Graph/GraphStore.swift`
- `Epistemos/Sync/SearchIndexService.swift`

## 2. Current Swift action -> Rust transaction -> subscription -> UI update flow

### Live editor mutation path

```text
NSTextStorage edit
  -> Prose editor coordinator
  -> BlockEditTranslator
  -> graph_engine_btk_translate_edit
  -> translator.rs creates BTK ops
  -> BlockTree.apply(op)
  -> OpLog.append(op)
  -> BtkQueryKernel.sync_page(page_id, tree, log)
  -> subscriptions updated in Rust
  -> no automatic live Swift consumer in the main UI today
```

### Live query invalidation path

```text
GraphStore/SearchIndex mutation
  -> NotificationCenter post
  -> ReactiveQuery reevaluate()
  -> QueryRuntime.execute(plan)
  -> Swift observable state update
```

### Staged knowledge-core mutation path

```text
Swift shadow call
  -> KnowledgeCoreBridge.ingestDocument/insertBlock/moveBlock/deleteBlock
  -> graph_engine_kc_* FFI
  -> KnowledgeCore
  -> DatalogStore transaction + watcher refresh
  -> QueryDiffEnvelope archived directly into ring slot
  -> KnowledgeCoreShadowRuntime polling task
  -> MainActor batch counters update
```

Important note:

- The staged path currently proves transport and diff generation.
- It does not yet drive real app state such as `QueryEngine`, `GraphStore`, note outlines, or visible SwiftUI models.

## 3. Current parser flow

### Live parser flow

```text
Markdown body / note text
  -> Swift BlockParser / BlockPropertyParser / NoteChatParser
  -> SwiftData blocks / properties / note views / graph builder helpers
```

Key files:

- `Epistemos/Sync/BlockParser.swift`
- `Epistemos/Sync/BlockPropertyParser.swift`
- `Epistemos/Sync/NoteChatParser.swift`

### Staged parser flow

```text
text + format
  -> knowledge_core::parser::parse_document()
  -> instantiate orgize / pulldown-cmark parsers
  -> line-oriented normalization into blocks/tasks/properties/links
  -> knowledge_core::store fact materialization
```

Important note:

- The staged parser is not a full canonical event-normalized AST pipeline yet.
- It instantiates parser iterators, but important normalization still falls back to line parsing.

## 4. Current CRDT / block ordering flow

### Live

```text
BTK BlockTree
  + OpLog
  + MovableTreeIndex (custom CRDT-like index for tests/query use)
  + custom FractionalIndex
```

Files:

- `graph-engine/src/block_kernel/block_tree.rs`
- `graph-engine/src/block_kernel/op_log.rs`
- `graph-engine/src/block_kernel/crdt.rs`
- `graph-engine/src/block_kernel/fractional_index.rs`

Important note:

- Live BTK is not Loro-backed.
- `MovableTreeIndex` is a custom helper and not the same as the staged Loro implementation.

### Staged

```text
knowledge_core::OutlineCrdt
  -> LoroDoc / LoroTree
  -> custom FractionalIndex projection for sort keys
  -> snapshot/restore helpers
```

File:

- `graph-engine/src/knowledge_core/crdt.rs`

## 5. Current persistence backends

### Live

- SwiftData: primary model store
- GRDB/SQLite: search index
- vault markdown files: import/export and recovery source
- Rust BTK: in-memory only per session

### Staged

- knowledge-core Cozo store is rebuilt in memory per query
- no persisted Cozo backend is wired
- no persisted knowledge-core transaction log or ring log is wired

## 6. Current query paths: legacy vs new

### Live / active paths

1. `QueryRuntime` over `GraphStore`
2. GRDB-backed `SearchIndexService`
3. direct BTK property/depth helper FFI calls
4. `ReactiveQuery` using `NotificationCenter`

### Staged / new path

1. `knowledge_core::store::DatalogStore`
2. `knowledge_core::ring::SharedRingBuffer`
3. `graph_engine_kc_*` FFI
4. `KnowledgeCoreBridge`
5. `KnowledgeCoreShadowRuntime`

Important note:

- The staged path no longer stops at the Rust FFI boundary.
- It now stops at a feature-flagged shadow runtime instead of a production query/view model integration.

## 7. App environment / observable model flow

```text
AppBootstrap
  -> builds services/state
  -> GraphState, QueryEngine, NoteChatState, etc.
  -> optional KnowledgeCoreShadowRuntime
  -> AppEnvironment.withAppEnvironment(...)
  -> SwiftUI environment injection
```

Files:

- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/AppEnvironment.swift`

Important note:

- `KnowledgeCoreShadowRuntime` is constructed in bootstrap, but it is not yet threaded through the real app environment as a first-class query engine dependency.

## 8. Build and test wiring

Build files:

- `build-rust.sh`
- `graph-engine/Cargo.toml`
- `graph-engine-build-inputs.xcfilelist`
- `project.yml`
- `graph-engine-bridge/graph_engine.h`

Test files:

- `graph-engine/src/knowledge_core/ring.rs`
- `graph-engine/src/lib.rs`
- `EpistemosTests/KnowledgeCoreBridgeTests.swift`

Important notes:

- Rust staticlib build remains wired into Xcode.
- Header generation is still manual; there is no `cbindgen` pipeline in this repo.
- The new Swift knowledge-core tests are present, but the full `EpistemosTests` target still has unrelated compile failures that block running them through `xcodebuild test`.
