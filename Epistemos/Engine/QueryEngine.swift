import Foundation
import SwiftUI

// MARK: - QueryEngine
// @Observable coordinator for the query system.
// Wires QueryParser/StructuredQueryParser → QueryCompiler → QueryRuntime.
// Injected as environment object; consumed by HologramSearchSidebar and CommandPalette.

@MainActor
@Observable
final class QueryEngine {

    // MARK: - State

    var isProcessing = false
    var currentResult: QueryResult?
    var currentQuery: String = ""
    var queryHistory: [QueryHistoryEntry] = []
    var errorMessage: String?

    // MARK: - Dependencies

    private var runtime: QueryRuntime?

    /// Configure with live dependencies. Called once during app bootstrap.
    func configure(graphStore: GraphStore, graphState: GraphState, searchIndex: SearchIndexService) {
        self.runtime = QueryRuntime(
            graphStore: graphStore,
            graphState: graphState,
            searchIndex: searchIndex
        )
    }

    // MARK: - Execute

    /// Execute a query (NL or structured with ? prefix).
    /// Routes ?-prefix to StructuredQueryParser, natural language to QueryParser.
    func execute(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let runtime else {
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
        isProcessing = false

        // Add to history
        queryHistory.insert(QueryHistoryEntry(
            query: trimmed,
            resultCount: result.nodes.count + (result.aggregation?.rows.count ?? 0),
            timestamp: .now
        ), at: 0)

        // Keep history manageable
        if queryHistory.count > 50 {
            queryHistory = Array(queryHistory.prefix(50))
        }
    }

    /// Clear current results.
    func clear() {
        currentResult = nil
        currentQuery = ""
        errorMessage = nil
    }
}

// MARK: - QueryHistoryEntry

struct QueryHistoryEntry: Identifiable, Sendable {
    let id = UUID()
    let query: String
    let resultCount: Int
    let timestamp: Date
}
