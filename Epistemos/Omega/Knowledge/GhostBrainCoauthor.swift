import Foundation
import os

// MARK: - Ghost Brain Co-Author

/// Provides graph-aware context injection for the note editor's AI features.
/// When the user writes or queries in a note, the ghost brain searches the
/// knowledge graph for relevant agent memories, recipes, and linked notes,
/// then injects this context into the AI prompt for richer, grounded responses.
///
/// This bridges the Omega agent system with the existing NoteChatState:
/// - Agent executions create graph nodes (via AgentGraphMemory)
/// - Ghost brain reads those nodes when the user writes about related topics
/// - The AI response is grounded in the user's accumulated knowledge
@MainActor @Observable
final class GhostBrainCoauthor {
    private let log = Logger(subsystem: "com.epistemos.omega", category: "GhostBrain")

    private let graphStore: GraphStore
    private let agentMemory: AgentGraphMemory

    /// Whether ghost brain context injection is enabled.
    var isEnabled: Bool = true

    /// Last context query and results (for UI inspection).
    private(set) var lastQuery: String = ""
    private(set) var lastContextNodeCount: Int = 0

    init(graphStore: GraphStore, agentMemory: AgentGraphMemory) {
        self.graphStore = graphStore
        self.agentMemory = agentMemory
    }

    // MARK: - Context Building

    /// Build a context prompt fragment from the knowledge graph.
    /// Searches for nodes related to the note content and formats them
    /// as a concise context block for the AI system prompt.
    ///
    /// Returns nil if no relevant context found or ghost brain is disabled.
    func buildContext(
        noteTitle: String,
        noteBodyPrefix: String,
        userQuery: String? = nil,
        maxTokenBudget: Int = 800
    ) -> String? {
        guard isEnabled else { return nil }

        // Build search query from note content + user query
        let searchQuery = buildSearchQuery(
            title: noteTitle,
            bodyPrefix: noteBodyPrefix,
            query: userQuery
        )
        lastQuery = searchQuery

        // Search the graph for related knowledge
        let contextNodes = agentMemory.contextFor(topic: searchQuery, maxDepth: 2)
        guard !contextNodes.isEmpty else {
            lastContextNodeCount = 0
            return nil
        }

        lastContextNodeCount = contextNodes.count

        // Format context within token budget
        let formatted = formatContext(nodes: contextNodes, budget: maxTokenBudget)
        guard !formatted.isEmpty else { return nil }

        log.debug("Ghost brain: \(contextNodes.count) nodes for '\(searchQuery.prefix(40))'")

        return """
        [Knowledge Graph Context — \(contextNodes.count) related nodes]
        \(formatted)
        [End Context]
        """
    }

    /// Build context specifically for continue-writing operations.
    /// Focuses on expanding/related edges to suggest continuation directions.
    func buildContinuationContext(
        noteTitle: String,
        lastParagraph: String
    ) -> String? {
        guard isEnabled else { return nil }

        let query = "\(noteTitle) \(lastParagraph)"
        let hits = graphStore.fuzzySearch(query: query, limit: 8)

        let relevantNodes = hits.map { $0.node }
        guard !relevantNodes.isEmpty else { return nil }

        // Find expansion edges — these suggest natural continuation points
        var expansions: [(node: GraphNodeRecord, edge: GraphEdgeRecord)] = []
        for node in relevantNodes {
            let edges = graphStore.edges(for: node.id)
            for edge in edges where edge.type == .expands || edge.type == .supports {
                let targetId = edge.sourceNodeId == node.id ? edge.targetNodeId : edge.sourceNodeId
                if let targetNode = graphStore.nodes[targetId] {
                    expansions.append((targetNode, edge))
                }
            }
        }

        if expansions.isEmpty { return nil }

        var lines: [String] = ["[Continuation suggestions from knowledge graph]"]
        for (node, edge) in expansions.prefix(5) {
            let relation = edge.type == .expands ? "expands on" : "supports"
            lines.append("- \(node.label) (\(relation) related content)")
        }
        lines.append("[End suggestions]")

        return lines.joined(separator: "\n")
    }

    /// Find notes in the graph that are connected to a given topic.
    /// Returns note IDs for cross-referencing or wikilink suggestions.
    func relatedNoteIds(forTopic topic: String, limit: Int = 5) -> [String] {
        let hits = graphStore.fuzzySearch(query: topic, limit: limit * 2)
        return hits
            .map { $0.node }
            .filter { $0.type == .note }
            .prefix(limit)
            .compactMap { $0.sourceId }
    }

    /// Suggest wikilinks based on graph connections to the current note.
    func suggestWikilinks(
        currentNoteId: String,
        cursorContext: String
    ) -> [WikilinkSuggestion] {
        // Find neighbors of the current note in the graph
        guard let noteNode = graphStore.node(bySourceId: currentNoteId, type: .note) else {
            // Fallback: search by cursor context
            let hits = graphStore.fuzzySearch(query: cursorContext, limit: 5)
            return hits.filter { $0.node.type == .note }.map { hit in
                WikilinkSuggestion(
                    noteId: hit.node.sourceId ?? hit.node.id,
                    title: hit.node.label,
                    relevance: Double(hit.score)
                )
            }
        }

        let neighbors = graphStore.neighbors(of: noteNode.id)
        let noteNeighbors = neighbors.filter { $0.type == .note }

        return noteNeighbors.prefix(8).map { node in
            WikilinkSuggestion(
                noteId: node.sourceId ?? node.id,
                title: node.label,
                relevance: node.weight
            )
        }
    }

    // MARK: - Helpers

    private func buildSearchQuery(title: String, bodyPrefix: String, query: String?) -> String {
        var parts: [String] = []
        if !title.isEmpty { parts.append(title) }
        if let q = query, !q.isEmpty { parts.append(q) }
        // Use last ~100 chars of body prefix for recency
        let bodyTail = String(bodyPrefix.suffix(100))
        if !bodyTail.isEmpty { parts.append(bodyTail) }
        return parts.joined(separator: " ")
    }

    private func formatContext(nodes: [GraphNodeRecord], budget: Int) -> String {
        var lines: [String] = []
        var charCount = 0
        let charBudget = budget * 4 // Rough chars-per-token estimate

        for node in nodes {
            let line: String
            switch node.type {
            case .idea:
                line = "- Insight: \(node.label)"
            case .source:
                let url = node.metadata.url ?? ""
                line = "- Source: \(node.label)" + (url.isEmpty ? "" : " (\(url))")
            case .note:
                line = "- Note: \(node.label)"
            case .tag:
                line = "- Topic: #\(node.label)"
            default:
                line = "- \(node.type.displayName): \(node.label)"
            }

            if charCount + line.count > charBudget { break }
            lines.append(line)
            charCount += line.count
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Types

struct WikilinkSuggestion: Sendable, Identifiable {
    var id: String { noteId }
    let noteId: String
    let title: String
    let relevance: Double
}
