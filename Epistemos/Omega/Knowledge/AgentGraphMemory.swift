import Foundation
import os

// MARK: - Agent Graph Memory

/// Persists agent execution results into the knowledge graph.
/// Every successful agent action creates graph nodes and edges that form
/// the agent's long-term memory — searchable, visualizable, and reusable.
///
/// Node types used:
/// - `.idea` — agent insights, discoveries, generated content
/// - `.source` — external data retrieved (web pages, files)
/// - `.tag` — auto-generated topic tags from agent actions
///
/// Edge types used:
/// - `.related` — connects agent outputs to source notes
/// - `.supports` — when agent findings confirm existing knowledge
/// - `.expands` — when agent findings add new detail to existing knowledge
/// - `.cites` — when agent references external sources
@MainActor
final class AgentGraphMemory {
    private let log = Logger(subsystem: "com.epistemos.omega", category: "AgentGraphMemory")

    private let graphStore: GraphStore

    /// Number of nodes created this session.
    private(set) var nodesCreatedThisSession: Int = 0

    /// Number of edges created this session.
    private(set) var edgesCreatedThisSession: Int = 0

    init(graphStore: GraphStore) {
        self.graphStore = graphStore
    }

    // MARK: - Record Agent Execution

    /// Record a completed agent execution as graph nodes + edges.
    /// Creates an idea node for the result and links it to any related existing nodes.
    func recordExecution(
        taskDescription: String,
        steps: [AgentStepResult],
        relatedNoteIds: [String] = []
    ) {
        let successfulSteps = steps.filter { $0.success }
        guard !successfulSteps.isEmpty else { return }

        // Create an idea node for the overall execution
        let executionNode = GraphNodeRecord(
            id: UUID().uuidString,
            type: .idea,
            label: truncateLabel(taskDescription),
            sourceId: nil,
            metadata: GraphNodeMetadata(
                originChatId: nil,
                originNoteId: nil
            ),
            weight: Double(successfulSteps.count) / Double(steps.count),
            createdAt: Date(),
            updatedAt: Date(),
            position: .zero,
            velocity: .zero,
            isVisible: true,
            isPinned: false
        )
        graphStore.addNode(executionNode)
        nodesCreatedThisSession += 1

        // Link to related notes
        for noteId in relatedNoteIds {
            guard graphStore.nodes[noteId] != nil else { continue }
            let edge = GraphEdgeRecord(
                id: UUID().uuidString,
                sourceNodeId: executionNode.id,
                targetNodeId: noteId,
                type: .expands,
                weight: 0.8,
                createdAt: Date()
            )
            graphStore.addEdge(edge)
            edgesCreatedThisSession += 1
        }

        // Create source nodes for external data (web URLs, files read)
        for step in successfulSteps {
            if let sourceNode = extractSourceNode(from: step) {
                graphStore.addNode(sourceNode)
                nodesCreatedThisSession += 1

                let edge = GraphEdgeRecord(
                    id: UUID().uuidString,
                    sourceNodeId: executionNode.id,
                    targetNodeId: sourceNode.id,
                    type: .cites,
                    weight: 0.7,
                    createdAt: Date()
                )
                graphStore.addEdge(edge)
                edgesCreatedThisSession += 1
            }
        }

        // Auto-tag based on task keywords
        let tags = extractTags(from: taskDescription)
        for tag in tags {
            linkOrCreateTag(tag, toNodeId: executionNode.id)
        }

        let nodeCount = self.nodesCreatedThisSession
        let edgeCount = self.edgesCreatedThisSession
        log.info("Recorded execution: \(nodeCount) nodes, \(edgeCount) edges")
    }

    // MARK: - Query Agent Memory

    /// Find past agent executions related to a query.
    /// Uses the graph's fuzzy search to find relevant idea nodes.
    func recall(query: String, limit: Int = 10) -> [GraphNodeRecord] {
        let hits = graphStore.fuzzySearch(query: query, limit: limit)
        return hits
            .map { $0.node }
            .filter { $0.type == .idea }
    }

    /// Find all sources cited by a specific execution node.
    func sourcesFor(executionNodeId: String) -> [GraphNodeRecord] {
        graphStore.edges(for: executionNodeId)
            .filter { $0.type == .cites }
            .compactMap { edge in
                let targetId = edge.sourceNodeId == executionNodeId ? edge.targetNodeId : edge.sourceNodeId
                return graphStore.nodes[targetId]
            }
            .filter { $0.type == .source }
    }

    /// Get the agent's knowledge context for a topic — combines recall + neighbor expansion.
    func contextFor(topic: String, maxDepth: Int = 2) -> [GraphNodeRecord] {
        let recalled = recall(query: topic, limit: 5)
        var contextSet = Set(recalled.map { $0.id })
        var contextNodes = recalled

        // Expand neighbors
        for node in recalled {
            let connected = graphStore.connected(to: node.id, maxDepth: maxDepth)
            for connectedId in connected {
                guard !contextSet.contains(connectedId),
                      let connectedNode = graphStore.nodes[connectedId] else { continue }
                contextSet.insert(connectedId)
                contextNodes.append(connectedNode)
            }
        }

        return contextNodes
    }

    // MARK: - Helpers

    private func extractSourceNode(from step: AgentStepResult) -> GraphNodeRecord? {
        guard let data = step.outputJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Extract URL from web search / page open results
        if let url = json["url"] as? String {
            let label = (json["title"] as? String) ?? url
            // Deduplicate: check if source already exists
            if graphStore.node(bySourceId: url, type: .source) != nil {
                return nil // Already tracked
            }
            return GraphNodeRecord(
                id: UUID().uuidString,
                type: .source,
                label: truncateLabel(label),
                sourceId: url,
                metadata: GraphNodeMetadata(url: url),
                weight: 0.5,
                createdAt: Date(),
                updatedAt: Date(),
                position: .zero,
                velocity: .zero,
                isVisible: true,
                isPinned: false
            )
        }

        return nil
    }

    private func extractTags(from text: String) -> [String] {
        // Simple keyword extraction: words >4 chars that appear meaningful
        let stopWords: Set<String> = [
            "about", "after", "again", "being", "could", "every",
            "first", "found", "great", "their", "there", "these",
            "thing", "think", "those", "under", "which", "while",
            "would", "write", "please", "create", "search", "files",
        ]

        let words = text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 4 && !stopWords.contains($0) }

        // Deduplicate and limit
        return Array(Set(words).prefix(3))
    }

    private func linkOrCreateTag(_ tag: String, toNodeId: String) {
        let tagNodeId: String

        // Check if tag node already exists
        let existing = graphStore.nodes.values.first { $0.type == .tag && $0.label.lowercased() == tag }
        if let existing {
            tagNodeId = existing.id
        } else {
            let tagNode = GraphNodeRecord(
                id: UUID().uuidString,
                type: .tag,
                label: tag,
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 0.3,
                createdAt: Date(),
                updatedAt: Date(),
                position: .zero,
                velocity: .zero,
                isVisible: true,
                isPinned: false
            )
            graphStore.addNode(tagNode)
            nodesCreatedThisSession += 1
            tagNodeId = tagNode.id
        }

        let edge = GraphEdgeRecord(
            id: UUID().uuidString,
            sourceNodeId: toNodeId,
            targetNodeId: tagNodeId,
            type: .tagged,
            weight: 0.4,
            createdAt: Date()
        )
        graphStore.addEdge(edge)
        edgesCreatedThisSession += 1
    }

    private func truncateLabel(_ text: String) -> String {
        if text.count <= 80 { return text }
        return String(text.prefix(77)) + "..."
    }
}
