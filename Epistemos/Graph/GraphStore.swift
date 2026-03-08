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
    let updatedAt: Date
    var position: SIMD2<Float> = .zero
    var velocity: SIMD2<Float> = .zero
    var isVisible: Bool = true
    var isPinned: Bool = false

    init(
        id: String,
        type: GraphNodeType,
        label: String,
        sourceId: String?,
        metadata: GraphNodeMetadata,
        weight: Double,
        createdAt: Date,
        updatedAt: Date? = nil,
        position: SIMD2<Float> = .zero,
        velocity: SIMD2<Float> = .zero,
        isVisible: Bool = true,
        isPinned: Bool = false
    ) {
        self.id = id
        self.type = type
        self.label = label
        self.sourceId = sourceId
        self.metadata = metadata
        self.weight = weight
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.position = position
        self.velocity = velocity
        self.isVisible = isVisible
        self.isPinned = isPinned
    }
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
//
// W7.4 Compact Storage: adjacency and edgesByNode use Int indices internally
// instead of String IDs. At 50K nodes with avg degree 5, this saves ~46MB
// by replacing Set<String> (100 bytes/ref) with [Int] (8 bytes/ref).
//
// W13.2 Trigram Index: fuzzySearch uses a pre-computed trigram index for
// O(1) candidate lookup instead of O(n) full scan. Sub-ms at 50K+ nodes.

@MainActor
final class GraphStore {

    // MARK: - Primary Storage

    /// All nodes keyed by ID. Unchanged public API — 20+ consumer sites use store.nodes[id].
    private(set) var nodes: [String: GraphNodeRecord] = [:]

    /// All edges keyed by ID. Unchanged public API.
    private(set) var edges: [String: GraphEdgeRecord] = [:]

    /// Position hints for newly created nodes. Key: SDGraphNode.id, Value: desired world position.
    /// Consumed during load() — if a hint exists, use it instead of random placement.
    var positionHints: [String: SIMD2<Float>] = [:]

    // MARK: - Compact Adjacency Storage (W7.4)
    // Replaces two [String: Set<String>] dicts with Int-indexed arrays.
    // Memory: 50K nodes × 5 neighbors × 8 bytes = 2MB vs. ~25MB with Set<String>.

    /// Node ID → stable compact index. Never reused after removal (stable references).
    private var _nodeIdx: [String: Int] = [:]

    /// Compact index → node ID. Gaps at removed indices contain empty string.
    private var _nodeIds: [String] = []

    /// Edge ID → stable compact index.
    private var _edgeIdx: [String: Int] = [:]

    /// Compact index → edge ID.
    private var _edgeIds: [String] = []

    /// Compact adjacency: _neighbors[nodeCompactIdx] = [neighborCompactIdx, ...].
    /// Undirected — each edge adds both directions.
    private var _neighbors: [[Int]] = []

    /// Compact edge reverse index: _edgesOf[nodeCompactIdx] = [edgeCompactIdx, ...].
    private var _edgesOf: [[Int]] = []

    // MARK: - Trigram Index (W13.2)
    // Pre-computed trigram → [nodeCompactIdx] for O(1) fuzzy search candidate lookup.
    // "Graph Store" → trigrams: "gra", "rap", "aph", "ph ", "h s", " st", "sto", "tor", "ore"

    /// Trigram (3-char lowercase string) → [compact node indices] that contain this trigram.
    private var _trigramIdx: [String: [Int]] = [:]

    // MARK: - Backward-Compatible Proxy Properties

    /// Adjacency: nodeId → set of neighbor nodeIds (undirected).
    /// Returns a lightweight proxy that generates Set<String> from compact Int storage.
    /// Consumer syntax unchanged: store.adjacency[nodeId] ?? [], store.adjacency[nodeId]?.count
    var adjacency: AdjacencyProxy { AdjacencyProxy(store: self) }

    /// Reverse index: nodeId → set of edgeIds touching that node.
    /// Consumer syntax unchanged: store.edgesByNode[nodeId] ?? []
    var edgesByNode: EdgesByNodeProxy { EdgesByNodeProxy(store: self) }

    // MARK: - Proxy Types

    struct AdjacencyProxy {
        let store: GraphStore

        subscript(_ nodeId: String) -> Set<String>? {
            guard let idx = store._nodeIdx[nodeId], idx < store._neighbors.count else { return nil }
            let neighborIndices = store._neighbors[idx]
            return Set(neighborIndices.compactMap {
                $0 < store._nodeIds.count ? store._nodeIds[$0] : nil
            }.filter { !$0.isEmpty })
        }

        /// Number of nodes with adjacency entries (matches old dictionary .count).
        var count: Int { store._nodeIdx.count }

        /// True if no nodes have adjacency entries.
        var isEmpty: Bool { store._nodeIdx.isEmpty }
    }

    struct EdgesByNodeProxy {
        let store: GraphStore

        subscript(_ nodeId: String) -> Set<String>? {
            guard let idx = store._nodeIdx[nodeId], idx < store._edgesOf.count else { return nil }
            let edgeIndices = store._edgesOf[idx]
            return Set(edgeIndices.compactMap {
                $0 < store._edgeIds.count ? store._edgeIds[$0] : nil
            }.filter { !$0.isEmpty })
        }

        /// Number of nodes with edge entries (matches old dictionary .count).
        var count: Int { store._nodeIdx.count }

        /// True if no nodes have edge entries.
        var isEmpty: Bool { store._nodeIdx.isEmpty }
    }

    // MARK: - Computed Properties

    var nodeCount: Int { nodes.count }
    var edgeCount: Int { edges.count }

    /// Remove all nodes, edges, adjacency, and index data.
    func clear() {
        nodes.removeAll()
        edges.removeAll()
        positionHints.removeAll()
        _nodeIdx.removeAll()
        _nodeIds.removeAll()
        _edgeIdx.removeAll()
        _edgeIds.removeAll()
        _neighbors.removeAll()
        _edgesOf.removeAll()
        _trigramIdx.removeAll()
    }

    // MARK: - Compact Index Helpers

    /// Assign a compact index to a node ID. Returns the index.
    @discardableResult
    private func assignNodeIndex(_ nodeId: String) -> Int {
        if let existing = _nodeIdx[nodeId] { return existing }
        let idx = _nodeIds.count
        _nodeIds.append(nodeId)
        _neighbors.append([])
        _edgesOf.append([])
        _nodeIdx[nodeId] = idx
        return idx
    }

    /// Assign a compact index to an edge ID. Returns the index.
    @discardableResult
    private func assignEdgeIndex(_ edgeId: String) -> Int {
        if let existing = _edgeIdx[edgeId] { return existing }
        let idx = _edgeIds.count
        _edgeIds.append(edgeId)
        _edgeIdx[edgeId] = idx
        return idx
    }

    // MARK: - Trigram Helpers

    /// Extract all trigrams from a label (lowercased, 3-char sliding window).
    private static func trigrams(from label: String) -> Set<String> {
        let lower = label.lowercased()
        guard lower.count >= 3 else {
            // For short labels (1-2 chars), use the label itself as a "trigram"
            return lower.isEmpty ? [] : [lower]
        }
        var result = Set<String>()
        var i = lower.startIndex
        while i < lower.endIndex {
            let end = lower.index(i, offsetBy: 3, limitedBy: lower.endIndex)
            guard let end else { break }
            result.insert(String(lower[i..<end]))
            i = lower.index(after: i)
        }
        return result
    }

    /// Add a node's label trigrams to the index.
    private func addToTrigramIndex(nodeIdx: Int, label: String) {
        for tri in Self.trigrams(from: label) {
            _trigramIdx[tri, default: []].append(nodeIdx)
        }
    }

    /// Remove a node's label trigrams from the index.
    private func removeFromTrigramIndex(nodeIdx: Int, label: String) {
        for tri in Self.trigrams(from: label) {
            _trigramIdx[tri]?.removeAll { $0 == nodeIdx }
            if _trigramIdx[tri]?.isEmpty == true {
                _trigramIdx.removeValue(forKey: tri)
            }
        }
    }

    // MARK: - Loading from SwiftData

    /// Fetch all SDGraphNode and SDGraphEdge from the given context,
    /// build the in-memory adjacency list, and assign phyllotaxis spiral positions.
    func load(context: ModelContext) throws {
        clear()

        let nodeDescriptor = FetchDescriptor<SDGraphNode>()
        let sdNodes = try context.fetch(nodeDescriptor)

        let golden = Float.pi * (3.0 - sqrt(5.0))
        for (index, sdNode) in sdNodes.enumerated() {
            let position: SIMD2<Float> = positionHints.removeValue(forKey: sdNode.id)
                ?? {
                    let r: Float = 250.0 * sqrt(Float(index))
                    let theta = Float(index) * golden
                    return SIMD2<Float>(r * cos(theta), r * sin(theta))
                }()

            let record = GraphNodeRecord(
                id: sdNode.id,
                type: sdNode.nodeType,
                label: sdNode.label,
                sourceId: sdNode.sourceId,
                metadata: sdNode.meta,
                weight: sdNode.weight,
                createdAt: sdNode.createdAt,
                updatedAt: sdNode.updatedAt,
                position: position,
                velocity: .zero
            )
            nodes[record.id] = record
            let nodeIdx = assignNodeIndex(record.id)
            addToTrigramIndex(nodeIdx: nodeIdx, label: record.label)
        }

        let edgeDescriptor = FetchDescriptor<SDGraphEdge>()
        let sdEdges = try context.fetch(edgeDescriptor)
        ingestEdges(sdEdges)
    }

    /// Populate store directly from in-memory arrays (skips SwiftData fetch).
    /// Used by buildStructuralGraph() to avoid a redundant re-fetch after persist().
    func loadDirect(nodes sdNodes: [SDGraphNode], edges sdEdges: [SDGraphEdge]) {
        clear()

        let golden = Float.pi * (3.0 - sqrt(5.0))
        for (index, sdNode) in sdNodes.enumerated() {
            let position: SIMD2<Float> = positionHints.removeValue(forKey: sdNode.id)
                ?? {
                    let r: Float = 250.0 * sqrt(Float(index))
                    let theta = Float(index) * golden
                    return SIMD2<Float>(r * cos(theta), r * sin(theta))
                }()

            let record = GraphNodeRecord(
                id: sdNode.id,
                type: sdNode.nodeType,
                label: sdNode.label,
                sourceId: sdNode.sourceId,
                metadata: sdNode.meta,
                weight: sdNode.weight,
                createdAt: sdNode.createdAt,
                updatedAt: sdNode.updatedAt,
                position: position,
                velocity: .zero
            )
            nodes[record.id] = record
            let nodeIdx = assignNodeIndex(record.id)
            addToTrigramIndex(nodeIdx: nodeIdx, label: record.label)
        }

        ingestEdges(sdEdges)
    }

    /// Populate store from pre-built Sendable records (no SwiftData fetch).
    /// Used by background graph loading to avoid main-thread SwiftData access.
    func loadFromRecords(nodeRecords: [GraphNodeRecord], edgeRecords: [GraphEdgeRecord]) {
        clear()

        for record in nodeRecords {
            nodes[record.id] = record
            let nodeIdx = assignNodeIndex(record.id)
            addToTrigramIndex(nodeIdx: nodeIdx, label: record.label)
        }

        ingestEdgeRecords(edgeRecords)
    }

    private func ingestEdgeRecords(_ edgeRecords: [GraphEdgeRecord]) {
        for record in edgeRecords {
            guard let srcIdx = _nodeIdx[record.sourceNodeId],
                  let tgtIdx = _nodeIdx[record.targetNodeId] else { continue }

            edges[record.id] = record
            let edgeIdx = assignEdgeIndex(record.id)

            if !_neighbors[srcIdx].contains(tgtIdx) { _neighbors[srcIdx].append(tgtIdx) }
            if !_neighbors[tgtIdx].contains(srcIdx) { _neighbors[tgtIdx].append(srcIdx) }
            _edgesOf[srcIdx].append(edgeIdx)
            _edgesOf[tgtIdx].append(edgeIdx)
        }
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

            guard let srcIdx = _nodeIdx[record.sourceNodeId],
                  let tgtIdx = _nodeIdx[record.targetNodeId] else { continue }

            edges[record.id] = record
            let edgeIdx = assignEdgeIndex(record.id)

            if !_neighbors[srcIdx].contains(tgtIdx) { _neighbors[srcIdx].append(tgtIdx) }
            if !_neighbors[tgtIdx].contains(srcIdx) { _neighbors[tgtIdx].append(srcIdx) }
            _edgesOf[srcIdx].append(edgeIdx)
            _edgesOf[tgtIdx].append(edgeIdx)
        }
    }

    // MARK: - Queries

    /// All neighbor records for a given node.
    func neighbors(of nodeId: String) -> [GraphNodeRecord] {
        guard let idx = _nodeIdx[nodeId], idx < _neighbors.count else { return [] }
        return _neighbors[idx].compactMap {
            $0 < _nodeIds.count ? nodes[_nodeIds[$0]] : nil
        }
    }

    /// All edges touching a given node.
    func edges(for nodeId: String) -> [GraphEdgeRecord] {
        guard let idx = _nodeIdx[nodeId], idx < _edgesOf.count else { return [] }
        return _edgesOf[idx].compactMap {
            $0 < _edgeIds.count ? edges[_edgeIds[$0]] : nil
        }
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
    /// Uses compact Int indices internally for faster traversal.
    func connected(to nodeId: String, maxDepth: Int) -> Set<String> {
        guard let startIdx = _nodeIdx[nodeId] else { return [] }

        var visited = Set<Int>()
        var queue: [(idx: Int, depth: Int)] = [(startIdx, 0)]
        var head = 0
        visited.insert(startIdx)

        while head < queue.count {
            let (currentIdx, depth) = queue[head]
            head += 1
            guard depth < maxDepth else { continue }

            for neighborIdx in _neighbors[currentIdx] {
                if !visited.contains(neighborIdx) {
                    visited.insert(neighborIdx)
                    queue.append((neighborIdx, depth + 1))
                }
            }
        }

        return Set(visited.compactMap {
            $0 < _nodeIds.count ? _nodeIds[$0] : nil
        }.filter { !$0.isEmpty })
    }

    // MARK: - Graph Query DSL

    /// Structured queries for exploring the knowledge graph.
    enum GraphQuery {
        case supportsOf(nodeId: String)
        case contradictsOf(nodeId: String)
        case nodesWithEdgeType(GraphEdgeType, from: String)
        case pathBetween(from: String, to: String, maxHops: Int)
    }

    /// Execute a structured graph query.
    func query(_ predicate: GraphQuery) -> [GraphNodeRecord] {
        switch predicate {
        case .supportsOf(let nodeId):
            return nodesLinkedBy(.supports, to: nodeId)
        case .contradictsOf(let nodeId):
            return nodesLinkedBy(.contradicts, to: nodeId)
        case .nodesWithEdgeType(let edgeType, let nodeId):
            return nodesLinkedBy(edgeType, to: nodeId)
        case .pathBetween(let fromId, let toId, let maxHops):
            return shortestPath(from: fromId, to: toId, maxHops: maxHops)
        }
    }

    /// Nodes linked to `nodeId` via edges of the given type (either direction).
    private func nodesLinkedBy(_ edgeType: GraphEdgeType, to nodeId: String) -> [GraphNodeRecord] {
        edges(for: nodeId)
            .filter { $0.type == edgeType }
            .compactMap { edge in
                let otherId = edge.sourceNodeId == nodeId ? edge.targetNodeId : edge.sourceNodeId
                return nodes[otherId]
            }
    }

    /// BFS shortest path using compact Int indices internally.
    private func shortestPath(from startId: String, to endId: String, maxHops: Int) -> [GraphNodeRecord] {
        guard let startIdx = _nodeIdx[startId],
              let endIdx = _nodeIdx[endId] else { return [] }
        if startIdx == endIdx { return [nodes[startId]].compactMap { $0 } }

        var visited = Set<Int>([startIdx])
        var predecessor: [Int: Int] = [:]
        var queue: [(idx: Int, depth: Int)] = [(startIdx, 0)]
        var head = 0

        while head < queue.count {
            let (currentIdx, depth) = queue[head]
            head += 1
            guard depth < maxHops else { continue }

            for neighborIdx in _neighbors[currentIdx] {
                if neighborIdx == endIdx {
                    predecessor[endIdx] = currentIdx
                    var path: [Int] = [endIdx]
                    var cur = currentIdx
                    var seen = Set<Int>([endIdx])
                    while cur != startIdx {
                        guard seen.insert(cur).inserted else { return [] }
                        path.append(cur)
                        cur = predecessor[cur] ?? startIdx
                    }
                    path.append(startIdx)
                    path.reverse()
                    return path.compactMap {
                        $0 < _nodeIds.count ? nodes[_nodeIds[$0]] : nil
                    }
                }
                if !visited.contains(neighborIdx) {
                    visited.insert(neighborIdx)
                    predecessor[neighborIdx] = currentIdx
                    queue.append((neighborIdx, depth + 1))
                }
            }
        }

        return []
    }

    // MARK: - Mutators

    /// Add a node to the store, initializing its compact adjacency entries.
    func addNode(_ node: GraphNodeRecord) {
        nodes[node.id] = node
        let nodeIdx = assignNodeIndex(node.id)
        addToTrigramIndex(nodeIdx: nodeIdx, label: node.label)
    }

    /// Add an edge to the store, updating compact adjacency for both endpoints.
    /// Adjacency deduplicates neighbor references (matches old Set<String> behavior).
    func addEdge(_ edge: GraphEdgeRecord) {
        guard let srcIdx = _nodeIdx[edge.sourceNodeId],
              let tgtIdx = _nodeIdx[edge.targetNodeId] else { return }

        edges[edge.id] = edge
        let edgeIdx = assignEdgeIndex(edge.id)

        // Adjacency: deduplicate (Set behavior — idempotent insert)
        if !_neighbors[srcIdx].contains(tgtIdx) {
            _neighbors[srcIdx].append(tgtIdx)
        }
        if !_neighbors[tgtIdx].contains(srcIdx) {
            _neighbors[tgtIdx].append(srcIdx)
        }

        // Edge reverse index: always add (multiple edges between same pair are valid)
        _edgesOf[srcIdx].append(edgeIdx)
        _edgesOf[tgtIdx].append(edgeIdx)
    }

    /// Remove a node and all its edges, cleaning up compact adjacency.
    func removeNode(_ nodeId: String) {
        guard let nodeIdx = _nodeIdx[nodeId] else { return }

        // Remove all edges touching this node
        let touchingEdgeIndices = _edgesOf[nodeIdx]
        for edgeIdx in touchingEdgeIndices {
            guard edgeIdx < _edgeIds.count else { continue }
            let edgeId = _edgeIds[edgeIdx]
            guard !edgeId.isEmpty, let edge = edges[edgeId] else { continue }

            let otherId = edge.sourceNodeId == nodeId ? edge.targetNodeId : edge.sourceNodeId
            if let otherIdx = _nodeIdx[otherId] {
                _neighbors[otherIdx].removeAll { $0 == nodeIdx }
                _edgesOf[otherIdx].removeAll { $0 == edgeIdx }
            }

            edges.removeValue(forKey: edgeId)
            _edgeIdx.removeValue(forKey: edgeId)
            _edgeIds[edgeIdx] = ""  // Tombstone
        }

        // Remove from trigram index
        if let label = nodes[nodeId]?.label {
            removeFromTrigramIndex(nodeIdx: nodeIdx, label: label)
        }

        // Tombstone the node's compact slot
        nodes.removeValue(forKey: nodeId)
        _nodeIdx.removeValue(forKey: nodeId)
        _nodeIds[nodeIdx] = ""  // Tombstone
        _neighbors[nodeIdx] = []
        _edgesOf[nodeIdx] = []
    }

    /// Remove a single edge by ID, cleaning up compact adjacency.
    /// Only removes the neighbor link if no other edges connect the same pair.
    func removeEdge(_ edgeId: String) {
        guard let edgeIdx = _edgeIdx[edgeId],
              let edge = edges[edgeId] else { return }

        if let srcIdx = _nodeIdx[edge.sourceNodeId],
           let tgtIdx = _nodeIdx[edge.targetNodeId] {
            // Remove this edge from reverse index first
            _edgesOf[srcIdx].removeAll { $0 == edgeIdx }
            _edgesOf[tgtIdx].removeAll { $0 == edgeIdx }

            // Only remove neighbor link if no other edges connect this pair.
            // Check remaining edges of srcIdx for any that still reference tgtIdx.
            let stillConnected = _edgesOf[srcIdx].contains { ei in
                guard ei < _edgeIds.count, !_edgeIds[ei].isEmpty,
                      let e = edges[_edgeIds[ei]] else { return false }
                let otherSrc = _nodeIdx[e.sourceNodeId]
                let otherTgt = _nodeIdx[e.targetNodeId]
                return (otherSrc == srcIdx && otherTgt == tgtIdx)
                    || (otherSrc == tgtIdx && otherTgt == srcIdx)
            }
            if !stillConnected {
                _neighbors[srcIdx].removeAll { $0 == tgtIdx }
                _neighbors[tgtIdx].removeAll { $0 == srcIdx }
            }
        }

        edges.removeValue(forKey: edgeId)
        _edgeIdx.removeValue(forKey: edgeId)
        _edgeIds[edgeIdx] = ""  // Tombstone
    }

    // MARK: - Fuzzy Search (W13.2 — Trigram-Accelerated)

    /// A scored search result from the in-memory fuzzy matcher.
    struct SearchHit: Identifiable {
        let id: String       // GraphNodeRecord.id
        let node: GraphNodeRecord
        let score: Float     // 0.0–1.0 relevance score
    }

    /// 5-tier fuzzy search with trigram-accelerated candidate filtering.
    /// At 50K nodes, trigram lookup reduces candidates from O(n) to ~O(100).
    /// Scoring: exact (1.0) > prefix (0.9) > word-start (0.8) > contains (0.6) > subsequence (0.3).
    func fuzzySearch(query: String, limit: Int = 20) -> [SearchHit] {
        let q = query.lowercased()
        guard !q.isEmpty else { return [] }

        // Get candidate node indices from trigram index
        let candidates = trigramCandidates(for: q)

        var hits: [SearchHit] = []
        for nodeIdx in candidates {
            guard nodeIdx < _nodeIds.count else { continue }
            let nodeId = _nodeIds[nodeIdx]
            guard !nodeId.isEmpty, let node = nodes[nodeId] else { continue }

            let label = node.label.lowercased()
            let score: Float

            if label == q {
                score = 1.0
            } else if label.hasPrefix(q) {
                score = 0.9
            } else if wordStartMatch(query: q, in: label) {
                score = 0.8
            } else if label.contains(q) {
                score = 0.6
            } else if subsequenceMatch(query: q, in: label) {
                score = 0.3
            } else {
                continue
            }

            hits.append(SearchHit(id: node.id, node: node, score: score))
        }

        hits.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.node.label.localizedCaseInsensitiveCompare(rhs.node.label) == .orderedAscending
        }

        return Array(hits.prefix(limit))
    }

    /// Get candidate node indices from the trigram index.
    /// Returns the intersection of posting lists for all trigrams in the query,
    /// falling back to union for short queries or when intersection is empty.
    private func trigramCandidates(for query: String) -> Set<Int> {
        let queryTrigrams = Self.trigrams(from: query)
        guard !queryTrigrams.isEmpty else {
            // No trigrams (1-2 char query) — fall back to full scan
            return Set(0..<_nodeIds.count)
        }

        // Intersect posting lists: a node must contain ALL query trigrams to be a candidate
        var result: Set<Int>?
        for tri in queryTrigrams {
            let posting = Set(_trigramIdx[tri] ?? [])
            if let current = result {
                result = current.intersection(posting)
            } else {
                result = posting
            }
            // Early exit if intersection is empty
            if result?.isEmpty == true { break }
        }

        let intersected = result ?? []

        // If intersection is too restrictive (e.g., for subsequence matches),
        // fall back to union of any trigram match
        if intersected.isEmpty {
            var unionResult = Set<Int>()
            for tri in queryTrigrams {
                if let posting = _trigramIdx[tri] {
                    unionResult.formUnion(posting)
                }
            }
            return unionResult.isEmpty ? Set(0..<_nodeIds.count) : unionResult
        }

        return intersected
    }

    /// Check if query characters match the start of words in the label.
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
    /// Uses compact storage directly — no temporary Set creation.
    func linkCount(for nodeId: String) -> UInt32 {
        guard let idx = _nodeIdx[nodeId], idx < _neighbors.count else { return 0 }
        return UInt32(_neighbors[idx].count)
    }
}
