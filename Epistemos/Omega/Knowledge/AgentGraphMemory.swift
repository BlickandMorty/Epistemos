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
    /// Uses the graph's fuzzy search + MMR reranking for diverse, relevant results.
    func recall(query: String, limit: Int = 10) -> [GraphNodeRecord] {
        // Fetch 3x candidates so MMR has room to diversify
        let candidateLimit = min(limit * 3, 50)
        let hits = graphStore.fuzzySearch(query: query, limit: candidateLimit)
            .filter { $0.node.type == .idea }

        guard hits.count > limit else {
            return hits.map(\.node)
        }

        // MMR rerank: balance relevance (λ=0.7) with diversity
        let scored = hits.map { hit in
            MMRReranker.ScoredItem(
                item: hit.node,
                relevanceScore: Double(hit.score),
                textForDiversity: hit.node.label
            )
        }
        let reranked = MMRReranker.rerank(
            items: scored,
            query: query,
            limit: limit,
            lambda: 0.7
        )
        return reranked.map { $0.item }
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

    // MARK: - Memory Distillation (NightBrain)

    /// Result of a distillation pass — returned for logging.
    struct DistillationResult: Sendable {
        let nodesDecayed: Int
        let nodesGarbageCollected: Int
        let totalNodesProcessed: Int
    }

    /// Run Ebbinghaus decay on all agent memory nodes and garbage-collect
    /// nodes whose strength drops below the threshold.
    ///
    /// Matches the Rust Living Vault implementation:
    /// - `decay_memory_nodes()` — `strength(t) = strength(t₀) × e^(-λ × Δt)`
    /// - `gc_memory_nodes()` — remove unpinned nodes below threshold
    ///
    /// When agent_core UniFFI bindings are available, this should delegate
    /// to the Rust FFI. For now, the same math runs in Swift.
    func distillMemory(
        decayLambda: Double = 0.01,
        gcThreshold: Double = 0.15
    ) -> DistillationResult {
        let now = Date()
        let allNodes = graphStore.nodes.values.filter { $0.type == .idea || $0.type == .source }
        var decayedCount = 0
        var gcIds: [String] = []

        for node in allNodes {
            let daysSinceUpdate = now.timeIntervalSince(node.updatedAt) / 86400.0
            guard daysSinceUpdate > 0 else { continue }

            let decayedStrength = node.weight * exp(-decayLambda * daysSinceUpdate)
            let clampedStrength = max(0, min(1, decayedStrength))

            if !node.isPinned && clampedStrength < gcThreshold {
                gcIds.append(node.id)
            } else if clampedStrength != node.weight {
                var updated = node
                updated.weight = clampedStrength
                graphStore.updateNode(updated)
                decayedCount += 1
            }
        }

        // Garbage-collect weak unpinned nodes
        for id in gcIds {
            graphStore.removeNode(id)
        }

        log.info("Distillation: decayed \(decayedCount), GC'd \(gcIds.count) of \(allNodes.count) nodes")
        return DistillationResult(
            nodesDecayed: decayedCount,
            nodesGarbageCollected: gcIds.count,
            totalNodesProcessed: allNodes.count
        )
    }

    // MARK: - Helpers

    private func truncateLabel(_ text: String) -> String {
        if text.count <= 80 { return text }
        return String(text.prefix(77)) + "..."
    }
}
