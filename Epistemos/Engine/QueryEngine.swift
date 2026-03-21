import Foundation
import SwiftUI

// MARK: - QueryEngine
// @Observable coordinator for the query system.
// Wires QueryParser/StructuredQueryParser → QueryCompiler → QueryRuntime.
// Injected as environment object; consumed by HologramSearchSidebar and CommandPalette.

@MainActor
@Observable
final class QueryEngine {
    typealias SearchIndexProvider = @MainActor () -> SearchIndexService?

    // MARK: - State

    var isProcessing = false
    var currentResult: QueryResult?
    var currentQuery: String = ""
    var queryHistory: [QueryHistoryEntry] = []
    var errorMessage: String?
    var isReactive = false
    var resultVersion = 0

    // MARK: - Dependencies

    private var graphStore: GraphStore?
    private var graphState: GraphState?
    private var searchIndexProvider: SearchIndexProvider?
    private var runtime: QueryRuntime?
    private var activeReactiveQuery: ReactiveQuery?
    private var reactiveTask: Task<Void, Never>?
    private(set) var preparedRetrievalRuntimeConfiguration: PreparedRetrievalRuntimeConfiguration?
    private(set) var preparedRetrievalExecutionMode: PreparedRetrievalExecutionMode = .appleEmbeddingFallback
    private var preparedRetrievalRuntimeResolver: any PreparedRetrievalRuntimeResolving =
        DefaultPreparedRetrievalRuntimeResolver()

    /// Configure with live dependencies. Called once during app bootstrap.
    func configure(
        graphStore: GraphStore,
        graphState: GraphState,
        searchIndexProvider: @escaping SearchIndexProvider,
        preparedRetrievalRuntimeConfiguration: PreparedRetrievalRuntimeConfiguration? = nil,
        preparedRetrievalRuntimeResolver: any PreparedRetrievalRuntimeResolving = DefaultPreparedRetrievalRuntimeResolver()
    ) {
        self.graphStore = graphStore
        self.graphState = graphState
        self.searchIndexProvider = searchIndexProvider
        self.preparedRetrievalRuntimeConfiguration = preparedRetrievalRuntimeConfiguration
        self.preparedRetrievalExecutionMode = preparedRetrievalRuntimeConfiguration?.preparedRetrievalExecutionMode
            ?? .appleEmbeddingFallback
        self.preparedRetrievalRuntimeResolver = preparedRetrievalRuntimeResolver
        invalidateRuntime()
    }

    func applyPreparedRetrievalRuntimeConfiguration(_ configuration: PreparedRetrievalRuntimeConfiguration?) {
        preparedRetrievalRuntimeConfiguration = configuration
        preparedRetrievalExecutionMode = configuration?.preparedRetrievalExecutionMode ?? .appleEmbeddingFallback
        invalidateRuntime()
    }

    func invalidateRuntime() {
        stopReactive()
        runtime = nil
    }

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
            searchIndex: searchIndex,
            scorer: preparedRetrievalRuntimeResolver.resolveScorer(
                configuration: preparedRetrievalRuntimeConfiguration,
                executionMode: preparedRetrievalExecutionMode,
                graphState: graphState
            )
        )
        self.runtime = runtime
        return runtime
    }

    // MARK: - Execute

    /// Execute a query (NL or structured with ? prefix).
    /// Routes ?-prefix to StructuredQueryParser, natural language to QueryParser.
    func execute(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let runtime = resolvedRuntime() else {
            errorMessage = "Query engine not configured"
            return
        }

        isProcessing = true
        errorMessage = nil
        currentQuery = trimmed

        // Use the runtime's unified query interface
        // It automatically handles ? prefix routing
        let result = runtime.query(trimmed)
        
        currentResult = result
        resultVersion += 1
        isProcessing = false
        addToHistory(query: trimmed, result: result)
    }

    // MARK: - Reactive Execute

    /// Start a reactive query that auto-updates when graph/index data changes.
    /// Replaces one-shot execute() for pinned/live queries.
    func executeReactive(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let runtime = resolvedRuntime() else {
            errorMessage = "Query engine not configured"
            return
        }

        // Tear down previous reactive stream
        stopReactive()

        guard let rq = ReactiveQuery(runtime: runtime, query: trimmed) else {
            // Fall back to one-shot if query can't parse
            execute(query: trimmed)
            return
        }

        activeReactiveQuery = rq
        isReactive = true
        isProcessing = true
        errorMessage = nil
        currentQuery = trimmed

        let stream = rq.stream()
        reactiveTask = Task { @MainActor [weak self] in
            var first = true
            for await result in stream {
                guard let self, !Task.isCancelled else { break }
                self.currentResult = result
                self.resultVersion += 1
                if first {
                    self.isProcessing = false
                    self.addToHistory(query: trimmed, result: result)
                    first = false
                }
            }
            // Stream ended
            self?.isReactive = false
        }
    }

    /// Stop the active reactive query stream.
    func stopReactive() {
        reactiveTask?.cancel()
        reactiveTask = nil
        activeReactiveQuery = nil
        isReactive = false
    }

    /// Clear current results.
    func clear() {
        stopReactive()
        currentResult = nil
        currentQuery = ""
        errorMessage = nil
    }

    private func addToHistory(query: String, result: QueryResult) {
        queryHistory.insert(QueryHistoryEntry(
            query: query,
            resultCount: result.nodes.count + (result.aggregation?.rows.count ?? 0),
            timestamp: .now
        ), at: 0)
        if queryHistory.count > 50 {
            queryHistory = Array(queryHistory.prefix(50))
        }
    }
}

// MARK: - QueryHistoryEntry

struct QueryHistoryEntry: Identifiable, Sendable {
    let id = UUID()
    let query: String
    let resultCount: Int
    let timestamp: Date
}
