# Graph Overlay and Query Stack

## Why this matters

The graph is a major surface in Epistemos, but it is architecturally separate from normal SwiftUI content. Any MLX or TTS integration that touches graph summaries, graph-side queries, or future spoken graph summaries must respect that separation.

## Current graph architecture

The graph is driven by `GraphState` and a separate overlay controller:

```swift
@MainActor @Observable
final class GraphState {
    let store = GraphStore()
    let filter = FilterEngine()
    nonisolated(unsafe) var engineHandle: OpaquePointer?
    let embeddingService: EmbeddingService
}
```

And the overlay is managed as a singleton window/controller:

```swift
@MainActor
final class HologramController {
    static let shared = HologramController()

    private var overlay: HologramOverlay?
    private var graphState: GraphState?
    private var queryEngine: QueryEngine?
}
```

This means graph-side AI should not assume it lives inside the home window lifecycle.

## Query stack

The app already has a query engine that is configured once at bootstrap and lazily resolves its runtime:

```swift
@MainActor
@Observable
final class QueryEngine {
    typealias SearchIndexProvider = @MainActor () -> SearchIndexService?

    private var graphStore: GraphStore?
    private var graphState: GraphState?
    private var searchIndexProvider: SearchIndexProvider?
    private var runtime: QueryRuntime?
}
```

Lazy runtime resolution:

```swift
private func resolvedRuntime() -> QueryRuntime? {
    if let runtime {
        return runtime
    }
    guard let graphStore, let graphState, let searchIndex = searchIndexProvider?() else {
        return nil
    }
    let runtime = QueryRuntime(
        graphStore: graphStore,
        graphState: graphState,
        searchIndex: searchIndex
    )
    self.runtime = runtime
    return runtime
}
```

This lazy pattern is highly relevant to local AI and voice:

- large models should not load at app launch
- TTS runtime should probably not fully spin up until needed
- graph-side AI should reuse shared services instead of creating its own heavy process per overlay

## Current overlay boot path

Bootstrap wires the graph lazily:

```swift
graphState.modelContext = container.mainContext
Task(priority: .utility) { await graphState.loadGraph(container: container) }
```

And overlay setup happens separately:

```swift
HologramController.shared.setup(
    graphState: bootstrap.graphState,
    queryEngine: bootstrap.queryEngine,
    modelContainer: bootstrap.modelContainer,
    physicsCoordinator: bootstrap.physicsCoordinator,
    dialogueChatState: bootstrap.dialogueChatState
)
```

## Relevance to future MLX / TTS

Possible graph-related AI / voice surfaces:

- graph inspector summaries
- graph-side semantic search follow-ups
- read-aloud of graph summaries
- future graph NPC / agent speech

But this should likely be phased:

- V1 probably focuses on chat + notes first
- graph voice should be opt-in and careful

## What research should answer

- should graph summaries call the same MLX/local stack as chat and notes
- should graph TTS share one voice engine with the whole app
- how should voice state behave when the overlay is shown/hidden
- how to avoid model/runtime duplication across home window and graph overlay
- whether graph surfaces should be V1 for voice or later
