import Foundation
import os

// MARK: - Agent Graph Memory

/// Reads and distills agent memory from the knowledge graph.
@MainActor
final class AgentGraphMemory {
    private let log = Logger(subsystem: "com.epistemos.omega", category: "AgentGraphMemory")

    private let graphStore: GraphStore
    /// Weak reference to GraphState for pushing incremental FFI updates to the Rust Metal engine.
    /// Without this, nodes added to the store are invisible to the hologram overlay.
    weak var graphState: GraphState?

    init(graphStore: GraphStore, graphState: GraphState? = nil) {
        self.graphStore = graphStore
        self.graphState = graphState
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
            graphState?.requestIncrementalRemove(nodeId: id)
            graphStore.removeNode(id)
        }

        log.info("Distillation: decayed \(decayedCount), GC'd \(gcIds.count) of \(allNodes.count) nodes")
        return DistillationResult(
            nodesDecayed: decayedCount,
            nodesGarbageCollected: gcIds.count,
            totalNodesProcessed: allNodes.count
        )
    }

}
