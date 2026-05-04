# Whole-App Performance Map

## Executive Shape

Epistemos currently has two performance stories:

1. The live app path:
   - SwiftUI + `@Observable` state
   - SwiftData models and file-backed note bodies
   - `GraphStore` in-memory graph
   - GRDB/FTS5 `SearchIndexService`
   - Rust graph engine for rendering, physics, BTK queries, markdown parsing, and embeddings

2. The staged parallel path:
   - `knowledge-core` shadow runtime
   - shared-memory SPSC ring
   - staged Cozo + Loro + parser path
   - `KnowledgeCoreBridge.swift`

The live app is still dominated by the first path. The staged path is real enough to benchmark, but it is not the authoritative runtime.

## Subsystem Inventory

### App Bootstrap and Dependency Graph

- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/AppEnvironment.swift`
- `Epistemos/App/EpistemosApp.swift`
- `Epistemos/App/RootView.swift`

Role:
- bootstraps SwiftData, graph state, search index access, AI stack, vault sync, and optional `knowledge-core` shadow runtime

Hot-path risk:
- startup work is split reasonably, but several subsystems still initialize eagerly
- duplicate runtime shape exists: live BTK + shadow `knowledge-core`

### AI Pipeline and Routing

- `Epistemos/Engine/TriageService.swift`
- `Epistemos/Engine/PipelineService.swift`
- `Epistemos/Engine/LLMService.swift`
- `Epistemos/Engine/MLXInferenceService.swift`

Role:
- routes Apple Intelligence vs local MLX
- manages streaming, continuation, and reasoning mode

Hot-path risk:
- local inference path is latency-sensitive but not FFI-dominated
- biggest wins here come from prompt/context shaping, continuation policy, and memory budgets, not shared-memory transport

### Notes, Editor, and Note Windows

- `Epistemos/Views/Notes/ProseEditorView.swift`
- `Epistemos/Views/Notes/ProseEditorRepresentable.swift`
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`
- `Epistemos/Views/Notes/NotesSidebar.swift`
- `Epistemos/Models/SDPage.swift`
- `Epistemos/Sync/NoteFileStorage.swift`
- `Epistemos/Sync/MappedNoteBody.swift`

Role:
- file-backed note editing with NSTextView bridge
- debounced persistence, block mirror sync, sidebar/search views

Hot-path risk:
- repeated `loadBody()` string creation across editor, sidebar, graph builder, intents, and summarizers
- lots of NotificationCenter fan-out around note body changes

### Vault Sync, Search, and Indexing

- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Sync/VaultIndexActor.swift`
- `Epistemos/Sync/SearchIndexService.swift`
- `Epistemos/Engine/SpotlightIndexer.swift`

Role:
- vault import/export
- file diff sync
- GRDB/FTS5 page/block search
- Spotlight indexing

Hot-path risk:
- repeated full-body reads in sync/index pipelines
- main-thread notification fan-out after index writes
- some full rebuild paths still exist and are acceptable only as cold paths

### Graph Runtime and Query Stack

- `Epistemos/Graph/GraphState.swift`
- `Epistemos/Graph/GraphStore.swift`
- `Epistemos/Graph/GraphBuilder.swift`
- `Epistemos/Graph/BackgroundGraphActor.swift`
- `Epistemos/Engine/QueryEngine.swift`
- `Epistemos/Engine/QueryRuntime.swift`
- `Epistemos/Engine/ReactiveQuery.swift`

Role:
- in-memory graph projection for UI and graph search
- background structural builds from SwiftData
- query execution across graph store, FTS, semantic search, and BTK helpers

Hot-path risk:
- `ReactiveQuery` uses broad invalidation and full plan re-execution
- `GraphStore` and `ReactiveQuery` stack debounces on top of each other
- `QueryRuntime` runs on `@MainActor`, including some full-array sorting/filtering

### Rust Graph Engine and FFI

- `Epistemos/Graph/GraphEngine.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Engine/BlockEditTranslator.swift`
- `Epistemos/Graph/EmbeddingService.swift`
- `graph-engine-bridge/graph_engine.h`
- `graph-engine/src/lib.rs`
- `graph-engine/src/renderer.rs`
- `graph-engine/src/types.rs`
- `graph-engine/src/markdown.rs`

Role:
- renderer/physics engine
- label search
- BTK subscriptions and property/depth queries
- markdown parsing helpers

Hot-path risk:
- bridge is mixed: some command calls are cheap and fine, some query/subscription paths still materialize rows and strings in Swift

### Staged Knowledge-Core Runtime

- `Epistemos/Engine/KnowledgeCoreBridge.swift`
- `graph-engine/src/knowledge_core/mod.rs`
- `graph-engine/src/knowledge_core/ring.rs`
- `graph-engine/src/knowledge_core/store.rs`
- `graph-engine/src/knowledge_core/parser.rs`
- `graph-engine/src/knowledge_core/crdt.rs`

Role:
- shadow runtime for shared-memory transport, typed diffs, staged parser/Cozo/CRDT work

Hot-path risk:
- currently shadow-only
- not yet authoritative for production note/query UI

## Live Data Flows

### Startup

`AppBootstrap` ->
SwiftData container ->
`VaultSyncService` and search provider ->
`GraphState.loadGraph()` via `BackgroundGraphActor` ->
`QueryEngine.configure(...)`

Latency sources:
- graph load
- search index lazy open on first use
- duplicate runtime initialization possibility when shadow mode is enabled

### Notes

Disk file ->
`SDPage.loadBody()` ->
`ProseEditorView` `@State bodyText` ->
`ProseEditorRepresentable2` / NSTextView ->
debounced save ->
`NoteFileStorage.writeBody` ->
`BlockMirror.sync` ->
`needsVaultSync`

Latency sources:
- repeated disk-to-String loads outside the editor fast path
- NotificationCenter-based external change propagation

### Search

User query ->
`QueryEngine` ->
`QueryRuntime`

Possible backends:
- `GraphStore.fuzzySearch`
- `SearchIndexService.search/searchBlocks`
- `GraphState.hybridSearch`
- BTK property/depth queries via FFI

Latency sources:
- full query rerun on broad invalidation
- main-thread sorting/filtering
- bridge row materialization

### Graph

SwiftData graph rows ->
`BackgroundGraphActor.loadRecords()` ->
`GraphStore.loadFromRecords()` ->
Metal/Rust engine commit ->
UI interactions via `GraphState` / `MetalGraphView`

Latency sources:
- full rebuilds scanning note bodies
- page-mode subgraph parsing reading full note bodies

### Staged Knowledge-Core

Rust `knowledge-core` ->
shared-memory ring ->
`KnowledgeCoreBridge.poll` ->
Swift snapshot structs ->
shadow counters/state only

Latency sources:
- still shadow-only
- still materializes Swift strings/arrays after transport

## Hot-Path Candidate List

1. `GraphStore.notifyChange()` + `ReactiveQuery.reevaluate()` had stacked debounce delay.
2. `GraphEngine.decodeBTKPayload()` converts borrowed Rust bytes into Swift arrays of structs and strings every update.
3. `SDPage.loadBody()` is called repeatedly across sidebar, graph build, daily brief, backlinks, intents, and vault tools.
4. `GraphBuilder.build(context:)` scans every page body for block refs during structural rebuilds.
5. `QueryRuntime` executes and sorts on `@MainActor`, including broad graph/node scans.
6. `ReactiveQuery` invalidates by notification name, not by dependency key.
7. `SearchIndexService.notifyIndexChanged()` posts a main-actor notification for every incremental write.
8. `KnowledgeCoreBridge` polls and rehydrates Swift snapshots even though the live UI does not consume typed diffs yet.
9. Several note-context and command-palette surfaces layer `Task.sleep` delays for UI timing.
10. JSON/Data storage inside `SDMessage`, `SDPage`, `SDNoteInsight`, and `SDGraphNode` adds decode/encode tax in some user-visible paths.

## Probable Perf Bottleneck List

### User-Visible

1. Query/search updates lag after graph or index mutations.
2. Note-adjacent surfaces repeatedly read and stringify note bodies.
3. Graph rebuild and page-mode extraction do body scans instead of incremental projections.
4. Note-context chat assembly still does broad body hydration for vault-wide context.

### Bridge / Dataflow

1. BTK subscription updates are zero-copy only at the raw byte buffer layer, not at the Swift model layer.
2. `knowledge-core` shared memory is real but not on the hot production path.
3. Some FFI query helpers still cross as C strings or newline-separated payloads instead of typed diffs.

### UI / Actor Churn

1. NotificationCenter is used for broad invalidation in query/search and note body events.
2. `Task.sleep` is used heavily for debounce/coalescing across app surfaces.
3. `QueryRuntime` and `QueryEngine` are main-actor bound even when backend work is pure data filtering.

## Probable Architecture Debt List

1. Duplicate runtimes:
   - live BTK/SwiftData/GraphStore path
   - shadow `knowledge-core` path
2. Duplicate reactive models:
   - broad notification invalidation in live query UI
   - typed diff/watcher path in staged runtime
3. Duplicate note search/context pipelines:
   - GRDB/FTS5 search index
   - ambient vault manifest/in-memory note context browse
4. Unused scaffolding:
   - `BTKSubscriptionState.startPolling()` exists but is not wired anywhere in the app

## Initial Conclusions

The strongest upgrade opportunities are not “replace everything with shared memory.” They are:

1. remove stacked invalidation/debounce latency from the live query path
2. reduce repeated note body hydration and disk/string churn
3. keep GRDB/FTS5 for search and stop forcing graph/runtime machinery into text-search problems
4. only use shared-memory/rkyv transport where the UI actually consumes high-frequency structured diffs

## Audit Pass Status

Implemented in this pass:

1. the live query invalidation stack was collapsed:
   - `GraphStore` posts immediately
   - `ReactiveQuery` now owns the only debounce window at `35ms`
2. `GraphBuilder.build(context:)` now uses `loadBody(mapped: true)` for bulk block-ref scans
3. daily brief note collection and backlinks scanning now use mapped body reads, and daily brief note bodies are loaded once per note instead of twice

Still outstanding:

1. dependency-key invalidation for live `ReactiveQuery`
2. repeated note body hydration across many non-editor surfaces
3. Swift-side BTK payload materialization
4. main-actor query filtering/projection work
