import Foundation
import SwiftData

// MARK: - GraphNodeRecord
// In-memory representation of a graph node for adjacency-list traversal
// and force-directed layout. Loaded from SDGraphNode at startup.
//
// nonisolated so this value type is freely usable across isolation boundaries
// (e.g., passed to/from the ForceSimulation actor).

nonisolated struct GraphNodeRecord: Identifiable, Sendable {
    let id: String
    let type: GraphNodeType
    let label: String
    let sourceId: String?
    let metadata: GraphNodeMetadata
    var weight: Double
    let createdAt: Date
    var position: SIMD2<Float> = .zero
    var velocity: SIMD2<Float> = .zero
    var isVisible: Bool = true
    var isPinned: Bool = false
}

// MARK: - GraphEdgeRecord
// In-memory representation of a graph edge for adjacency-list traversal.

nonisolated struct GraphEdgeRecord: Identifiable, Sendable {
    let id: String
    let sourceNodeId: String
    let targetNodeId: String
    let type: GraphEdgeType
    let weight: Double
    let createdAt: Date
}

// MARK: - GraphStore
// Holds the in-memory adjacency list built from SwiftData graph models.
// @MainActor for thread safety — NOT @Observable to avoid SwiftUI observation overhead.
// The SpriteKit scene reads positions directly each frame; observation would add latency.

@MainActor
final class GraphStore {

    // MARK: - Storage

    /// All nodes keyed by ID.
    private(set) var nodes: [String: GraphNodeRecord] = [:]

    /// All edges keyed by ID.
    private(set) var edges: [String: GraphEdgeRecord] = [:]

    /// Position hints for newly created nodes. Key: SDGraphNode.id, Value: desired world position.
    /// Consumed during load() — if a hint exists, use it instead of random placement.
    var positionHints: [String: SIMD2<Float>] = [:]

    /// Adjacency list: nodeId -> set of neighbor nodeIds (undirected).
    private(set) var adjacency: [String: Set<String>] = [:]

    /// Reverse index: nodeId -> set of edgeIds touching that node.
    private(set) var edgesByNode: [String: Set<String>] = [:]

    // MARK: - Computed Properties

    var nodeCount: Int { nodes.count }
    var edgeCount: Int { edges.count }

    // MARK: - Loading from SwiftData

    /// Fetch all SDGraphNode and SDGraphEdge from the given context,
    /// build the in-memory adjacency list, and assign random initial positions.
    func load(context: ModelContext) throws {
        // Clear existing state
        nodes = [:]
        edges = [:]
        adjacency = [:]
        edgesByNode = [:]

        // Fetch nodes
        let nodeDescriptor = FetchDescriptor<SDGraphNode>()
        let sdNodes = try context.fetch(nodeDescriptor)

        for sdNode in sdNodes {
            let position: SIMD2<Float> = positionHints.removeValue(forKey: sdNode.id)
                ?? SIMD2<Float>(Float.random(in: -500...500), Float.random(in: -500...500))

            let record = GraphNodeRecord(
                id: sdNode.id,
                type: sdNode.nodeType,
                label: sdNode.label,
                sourceId: sdNode.sourceId,
                metadata: sdNode.meta,
                weight: sdNode.weight,
                createdAt: sdNode.createdAt,
                position: position,
                velocity: .zero
            )
            nodes[record.id] = record
            adjacency[record.id] = []
            edgesByNode[record.id] = []
        }

        // Fetch edges
        let edgeDescriptor = FetchDescriptor<SDGraphEdge>()
        let sdEdges = try context.fetch(edgeDescriptor)

        ingestEdges(sdEdges)
    }

    /// Populate store directly from in-memory arrays (skips SwiftData fetch).
    /// Used by buildStructuralGraph() to avoid a redundant re-fetch after persist().
    func loadDirect(nodes sdNodes: [SDGraphNode], edges sdEdges: [SDGraphEdge]) {
        // Clear existing state
        nodes = [:]
        edges = [:]
        adjacency = [:]
        edgesByNode = [:]

        for sdNode in sdNodes {
            let position: SIMD2<Float> = positionHints.removeValue(forKey: sdNode.id)
                ?? SIMD2<Float>(Float.random(in: -500...500), Float.random(in: -500...500))

            let record = GraphNodeRecord(
                id: sdNode.id,
                type: sdNode.nodeType,
                label: sdNode.label,
                sourceId: sdNode.sourceId,
                metadata: sdNode.meta,
                weight: sdNode.weight,
                createdAt: sdNode.createdAt,
                position: position,
                velocity: .zero
            )
            nodes[record.id] = record
            adjacency[record.id] = []
            edgesByNode[record.id] = []
        }

        ingestEdges(sdEdges)
    }

    private func ingestEdges(_ sdEdges: [SDGraphEdge]) {
        for sdEdge in sdEdges {
            let record = GraphEdgeRecord(
                id: sdEdge.id,
                sourceNodeId: sdEdge.sourceNodeId,
                targetNodeId: sdEdge.targetNodeId,
                type: sdEdge.edgeType,
                weight: sdEdge.weight,
                createdAt: sdEdge.createdAt
            )

            // Only add if both endpoints exist
            guard nodes[record.sourceNodeId] != nil,
                  nodes[record.targetNodeId] != nil else { continue }

            edges[record.id] = record

            // Undirected adjacency
            adjacency[record.sourceNodeId, default: []].insert(record.targetNodeId)
            adjacency[record.targetNodeId, default: []].insert(record.sourceNodeId)

            // Edge reverse index
            edgesByNode[record.sourceNodeId, default: []].insert(record.id)
            edgesByNode[record.targetNodeId, default: []].insert(record.id)
        }
    }

    // MARK: - Queries

    /// All neighbor records for a given node.
    func neighbors(of nodeId: String) -> [GraphNodeRecord] {
        guard let neighborIds = adjacency[nodeId] else { return [] }
        return neighborIds.compactMap { nodes[$0] }
    }

    /// All edges touching a given node.
    func edges(for nodeId: String) -> [GraphEdgeRecord] {
        guard let edgeIds = edgesByNode[nodeId] else { return [] }
        return edgeIds.compactMap { edges[$0] }
    }

    /// All nodes of a specific type.
    func nodes(ofType type: GraphNodeType) -> [GraphNodeRecord] {
        nodes.values.filter { $0.type == type }
    }

    /// Find a node by its sourceId and type (e.g., the graph node for a specific SDPage).
    func node(bySourceId sourceId: String, type: GraphNodeType) -> GraphNodeRecord? {
        nodes.values.first { $0.sourceId == sourceId && $0.type == type }
    }

    /// BFS from a starting node, returning all reachable node IDs within maxDepth.
    func connected(to nodeId: String, maxDepth: Int) -> Set<String> {
        guard adjacency[nodeId] != nil else { return [] }

        var visited = Set<String>()
        var queue: [(id: String, depth: Int)] = [(nodeId, 0)]
        visited.insert(nodeId)

        while !queue.isEmpty {
            let (currentId, depth) = queue.removeFirst()
            guard depth < maxDepth else { continue }

            for neighborId in adjacency[currentId] ?? [] {
                if !visited.contains(neighborId) {
                    visited.insert(neighborId)
                    queue.append((neighborId, depth + 1))
                }
            }
        }

        return visited
    }

    // MARK: - Mutators

    /// Add a node to the store, initializing its adjacency entries.
    func addNode(_ node: GraphNodeRecord) {
        nodes[node.id] = node
        if adjacency[node.id] == nil {
            adjacency[node.id] = []
        }
        if edgesByNode[node.id] == nil {
            edgesByNode[node.id] = []
        }
    }

    /// Add an edge to the store, updating adjacency for both endpoints.
    func addEdge(_ edge: GraphEdgeRecord) {
        guard nodes[edge.sourceNodeId] != nil,
              nodes[edge.targetNodeId] != nil else { return }

        edges[edge.id] = edge

        adjacency[edge.sourceNodeId, default: []].insert(edge.targetNodeId)
        adjacency[edge.targetNodeId, default: []].insert(edge.sourceNodeId)

        edgesByNode[edge.sourceNodeId, default: []].insert(edge.id)
        edgesByNode[edge.targetNodeId, default: []].insert(edge.id)
    }

    /// Remove a node and all its edges, cleaning up adjacency.
    func removeNode(_ nodeId: String) {
        // Remove all edges touching this node
        let touchingEdgeIds = edgesByNode[nodeId] ?? []
        for edgeId in touchingEdgeIds {
            guard let edge = edges[edgeId] else { continue }

            // Clean up the other endpoint's adjacency and edgesByNode
            let otherId = edge.sourceNodeId == nodeId ? edge.targetNodeId : edge.sourceNodeId
            adjacency[otherId]?.remove(nodeId)
            edgesByNode[otherId]?.remove(edgeId)

            edges.removeValue(forKey: edgeId)
        }

        // Remove the node itself
        nodes.removeValue(forKey: nodeId)
        adjacency.removeValue(forKey: nodeId)
        edgesByNode.removeValue(forKey: nodeId)
    }

    // MARK: - Fuzzy Search

    /// A scored search result from the in-memory fuzzy matcher.
    struct SearchHit: Identifiable {
        let id: String       // GraphNodeRecord.id
        let node: GraphNodeRecord
        let score: Float     // 0.0–1.0 relevance score
    }

    /// 5-tier fuzzy search matching the Rust FST scoring algorithm:
    /// exact (1.0) > prefix (0.9) > word-start (0.8) > contains (0.6) > subsequence (0.3).
    func fuzzySearch(query: String, limit: Int = 20) -> [SearchHit] {
        let q = query.lowercased()
        guard !q.isEmpty else { return [] }

        var hits: [SearchHit] = []
        for node in nodes.values {
            let label = node.label.lowercased()
            let score: Float

            if label == q {
                score = 1.0                              // exact
            } else if label.hasPrefix(q) {
                score = 0.9                              // prefix
            } else if wordStartMatch(query: q, in: label) {
                score = 0.8                              // word-start (e.g. "gst" matches "graph store tests")
            } else if label.contains(q) {
                score = 0.6                              // substring
            } else if subsequenceMatch(query: q, in: label) {
                score = 0.3                              // subsequence (e.g. "grph" matches "graph")
            } else {
                continue
            }

            hits.append(SearchHit(id: node.id, node: node, score: score))
        }

        // Sort by score descending, then alphabetically
        hits.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.node.label.localizedCaseInsensitiveCompare(rhs.node.label) == .orderedAscending
        }

        return Array(hits.prefix(limit))
    }

    /// Check if query characters match the start of words in the label.
    /// "gst" matches "Graph Store Tests" (G-raph S-tore T-ests).
    private func wordStartMatch(query: String, in label: String) -> Bool {
        let words = label.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        let wordStarts = words.compactMap { $0.first.map { String($0).lowercased() } }
        let initials = wordStarts.joined()
        return initials.contains(query)
    }

    /// Check if all query characters appear in order in the label.
    private func subsequenceMatch(query: String, in label: String) -> Bool {
        var labelIdx = label.startIndex
        for qChar in query {
            guard let found = label[labelIdx...].firstIndex(of: qChar) else { return false }
            labelIdx = label.index(after: found)
        }
        return true
    }

    // MARK: - Link Count (for Rust FFI)

    /// Number of edges touching this node (degree).
    /// Used by the Rust engine for radius sizing: cbrt(link_count) * 8.0.
    func linkCount(for nodeId: String) -> UInt32 {
        UInt32(adjacency[nodeId]?.count ?? 0)
    }
}
