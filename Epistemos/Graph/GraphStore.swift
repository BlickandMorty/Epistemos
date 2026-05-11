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

    // Ghost Link decay fields (CMS-X v3 §3.2 — binding stiffness k_ij is learned and decayable)
    var strength: Double = 1.0       // Ebbinghaus decay: 1.0 = fresh, 0.0 = invisible
    var lastAccessed: Date = .now
    var accessCount: Int = 0
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
    nonisolated static let hiddenNodeTypes: Set<GraphNodeType> = [.tag, .source, .quote]

    private struct SourceLookupKey: Hashable {
        let sourceId: String
        let type: GraphNodeType
    }

    private struct SearchCacheKey: Hashable {
        let query: String
        let limit: Int
    }

    private struct SearchCacheEntry {
        let hits: [SearchHit]
        let expiresAt: Date
    }

    struct SearchCacheDebugSnapshot {
        let hits: Int
        let misses: Int
        let expired: Int
        let entryCount: Int
    }

    struct CompactStorageDebugSnapshot {
        let activeNodeCount: Int
        let nodeSlots: Int
        let nodeTombstones: Int
        let nodeCompactionEligible: Bool
        let activeEdgeCount: Int
        let edgeSlots: Int
        let edgeTombstones: Int
        let edgeCompactionEligible: Bool
    }

    private enum SearchCacheConfig {
        static let ttl: TimeInterval = 15
        static let capacity = 64
    }

    private enum CompactionConfig {
        static let minimumTombstones = 32
        static let minimumWasteFraction = 0.25
    }

    // MARK: - Primary Storage

    /// All nodes keyed by ID. Unchanged public API — 20+ consumer sites use store.nodes[id].
    private(set) var nodes: [String: GraphNodeRecord] = [:]

    /// (sourceId, type) → node ID for direct note/source lookup without a full-node scan.
    private var _sourceLookup: [SourceLookupKey: String] = [:]

    /// type → node IDs for direct type lookups without a full-node scan.
    private var _typeLookup: [GraphNodeType: Set<String>] = [:]

    /// Node IDs ordered by createdAt descending for newest-first query scans.
    private var _nodeIdsByCreatedAtDesc: [String] = []

    /// All edges keyed by ID. Unchanged public API.
    private(set) var edges: [String: GraphEdgeRecord] = [:]

    /// Position hints for newly created nodes. Key: SDGraphNode.id, Value: desired world position.
    /// Consumed during load() — if a hint exists, use it instead of random placement.
    var positionHints: [String: SIMD2<Float>] = [:]

    private nonisolated static func initialSpiralSpacing(nodeCount: Int) -> Float {
        guard nodeCount > 0 else { return 250 }
        let maxRadius: Float = nodeCount > 9_000 ? 6_800 : 8_500
        let adaptive = maxRadius / sqrt(Float(nodeCount))
        return min(250, max(44, adaptive))
    }

    nonisolated static func initialSpiralPosition(index: Int, nodeCount: Int) -> SIMD2<Float> {
        let golden = Float.pi * (3.0 - sqrt(5.0))
        let spacing = initialSpiralSpacing(nodeCount: nodeCount)
        let r = spacing * sqrt(Float(index))
        let theta = Float(index) * golden
        return SIMD2<Float>(r * cos(theta), r * sin(theta))
    }

    // MARK: - Compact Adjacency Storage (W7.4)
    // Replaces two [String: Set<String>] dicts with Int-indexed arrays.
    // Memory: 50K nodes × 5 neighbors × 8 bytes = 2MB vs. ~25MB with Set<String>.

    /// Node ID → opaque compact index. Internal maintenance may repack these slots.
    private var _nodeIdx: [String: Int] = [:]

    /// Compact index → node ID. Gaps at removed indices contain empty string.
    private var _nodeIds: [String] = []

    /// Edge ID → opaque compact index. Internal maintenance may repack these slots.
    private var _edgeIdx: [String: Int] = [:]

    /// Compact index → edge ID.
    private var _edgeIds: [String] = []

    /// Number of tombstoned node slots waiting for a compaction pass.
    private var nodeTombstoneCount = 0

    /// Number of tombstoned edge slots waiting for a compaction pass.
    private var edgeTombstoneCount = 0

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

    // MARK: - Topology Version

    /// Monotonically increasing version counter for structural changes.
    /// Incremented on load, addNode, removeNode, addEdge, removeEdge.
    /// Used by MetalGraphNSView to skip recomputing depth-color overrides when topology is unchanged.
    private(set) var topologyVersion: Int = 0

    private var searchCache: [SearchCacheKey: SearchCacheEntry] = [:]
    private var searchCacheOrder: [SearchCacheKey] = []
    private var searchCacheHitCount = 0
    private var searchCacheMissCount = 0
    private var searchCacheExpiredCount = 0
    private var searchCacheNowProvider: () -> Date = Date.init
    private var neighborLabelsCache: [String: [String]] = [:]

    // MARK: - Computed Properties

    var nodeCount: Int { nodes.count }
    var edgeCount: Int { edges.count }

    private func resetStorage(keepingCapacity: Bool) {
        nodes.removeAll(keepingCapacity: keepingCapacity)
        _sourceLookup.removeAll(keepingCapacity: keepingCapacity)
        _typeLookup.removeAll(keepingCapacity: keepingCapacity)
        _nodeIdsByCreatedAtDesc.removeAll(keepingCapacity: keepingCapacity)
        edges.removeAll(keepingCapacity: keepingCapacity)
        positionHints.removeAll(keepingCapacity: keepingCapacity)
        _nodeIdx.removeAll(keepingCapacity: keepingCapacity)
        _nodeIds.removeAll(keepingCapacity: keepingCapacity)
        _edgeIdx.removeAll(keepingCapacity: keepingCapacity)
        _edgeIds.removeAll(keepingCapacity: keepingCapacity)
        nodeTombstoneCount = 0
        edgeTombstoneCount = 0
        _neighbors.removeAll(keepingCapacity: keepingCapacity)
        _edgesOf.removeAll(keepingCapacity: keepingCapacity)
        _trigramIdx.removeAll(keepingCapacity: keepingCapacity)
        clearSearchCache()
        neighborLabelsCache.removeAll(keepingCapacity: true)
        topologyVersion += 1
    }

    private func prepareForBulkLoad(estimatedNodeCount: Int, estimatedEdgeCount: Int) {
        resetStorage(keepingCapacity: true)

        nodes.reserveCapacity(estimatedNodeCount)
        _sourceLookup.reserveCapacity(estimatedNodeCount)
        _nodeIdsByCreatedAtDesc.reserveCapacity(estimatedNodeCount)
        edges.reserveCapacity(estimatedEdgeCount)
        _nodeIdx.reserveCapacity(estimatedNodeCount)
        _nodeIds.reserveCapacity(estimatedNodeCount)
        _edgeIdx.reserveCapacity(estimatedEdgeCount)
        _edgeIds.reserveCapacity(estimatedEdgeCount)
        _neighbors.reserveCapacity(estimatedNodeCount)
        _edgesOf.reserveCapacity(estimatedNodeCount)
        _trigramIdx.reserveCapacity(estimatedNodeCount)
    }

    /// Remove all nodes, edges, adjacency, and index data.
    func clear() {
        resetStorage(keepingCapacity: false)
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

    private func shouldCompact(slotCount: Int, tombstoneCount: Int) -> Bool {
        guard slotCount > 0, tombstoneCount >= CompactionConfig.minimumTombstones else { return false }
        return Double(tombstoneCount) / Double(slotCount) >= CompactionConfig.minimumWasteFraction
    }

    private func orderedActiveIds(from slots: [String], activeKeys: Set<String>) -> [String] {
        var ordered: [String] = []
        ordered.reserveCapacity(activeKeys.count)
        var seen: Set<String> = []
        seen.reserveCapacity(activeKeys.count)

        for id in slots where !id.isEmpty && activeKeys.contains(id) {
            ordered.append(id)
            seen.insert(id)
        }

        if seen.count < activeKeys.count {
            for id in activeKeys.sorted() where !seen.contains(id) {
                ordered.append(id)
            }
        }

        return ordered
    }

    private func compactStorageIfNeeded() {
        guard shouldCompact(slotCount: _nodeIds.count, tombstoneCount: nodeTombstoneCount)
            || shouldCompact(slotCount: _edgeIds.count, tombstoneCount: edgeTombstoneCount)
        else { return }
        compactStorage()
    }

    private func compactStorage() {
        let activeNodeIds = orderedActiveIds(from: _nodeIds, activeKeys: Set(nodes.keys))
        let activeEdgeIds = orderedActiveIds(from: _edgeIds, activeKeys: Set(edges.keys))

        var compactNodeIdx: [String: Int] = [:]
        compactNodeIdx.reserveCapacity(activeNodeIds.count)
        var compactNodeIds: [String] = []
        compactNodeIds.reserveCapacity(activeNodeIds.count)
        var compactNeighbors: [[Int]] = []
        compactNeighbors.reserveCapacity(activeNodeIds.count)
        var compactEdgesOf: [[Int]] = []
        compactEdgesOf.reserveCapacity(activeNodeIds.count)
        var compactTrigramIdx: [String: [Int]] = [:]

        for nodeId in activeNodeIds {
            let nodeIdx = compactNodeIds.count
            compactNodeIdx[nodeId] = nodeIdx
            compactNodeIds.append(nodeId)
            compactNeighbors.append([])
            compactEdgesOf.append([])

            if let node = nodes[nodeId] {
                for tri in Self.trigrams(from: node.label) {
                    compactTrigramIdx[tri, default: []].append(nodeIdx)
                }
            }
        }

        var compactEdgeIdx: [String: Int] = [:]
        compactEdgeIdx.reserveCapacity(activeEdgeIds.count)
        var compactEdgeIds: [String] = []
        compactEdgeIds.reserveCapacity(activeEdgeIds.count)

        for edgeId in activeEdgeIds {
            guard let edge = edges[edgeId],
                  let srcIdx = compactNodeIdx[edge.sourceNodeId],
                  let tgtIdx = compactNodeIdx[edge.targetNodeId]
            else { continue }

            let edgeIdx = compactEdgeIds.count
            compactEdgeIdx[edgeId] = edgeIdx
            compactEdgeIds.append(edgeId)

            if !compactNeighbors[srcIdx].contains(tgtIdx) {
                compactNeighbors[srcIdx].append(tgtIdx)
            }
            if !compactNeighbors[tgtIdx].contains(srcIdx) {
                compactNeighbors[tgtIdx].append(srcIdx)
            }

            compactEdgesOf[srcIdx].append(edgeIdx)
            compactEdgesOf[tgtIdx].append(edgeIdx)
        }

        _nodeIdx = compactNodeIdx
        _nodeIds = compactNodeIds
        _neighbors = compactNeighbors
        _edgesOf = compactEdgesOf
        _edgeIdx = compactEdgeIdx
        _edgeIds = compactEdgeIds
        _trigramIdx = compactTrigramIdx
        nodeTombstoneCount = 0
        edgeTombstoneCount = 0
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
        let nodeDescriptor = FetchDescriptor<SDGraphNode>()
        let allNodes = try context.fetch(nodeDescriptor)
        let visibleNodes = allNodes.filter { !Self.hiddenNodeTypes.contains($0.nodeType) }
        let edgeDescriptor = FetchDescriptor<SDGraphEdge>()
        let sdEdges = try context.fetch(edgeDescriptor)

        prepareForBulkLoad(
            estimatedNodeCount: visibleNodes.count,
            estimatedEdgeCount: sdEdges.count
        )

        for (index, sdNode) in visibleNodes.enumerated() {
            let position: SIMD2<Float> = positionHints.removeValue(forKey: sdNode.id)
                ?? Self.initialSpiralPosition(index: index, nodeCount: visibleNodes.count)

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
            registerSourceLookup(for: record)
            registerTypeLookup(for: record)
            let nodeIdx = assignNodeIndex(record.id)
            addToTrigramIndex(nodeIdx: nodeIdx, label: record.label)
        }
        rebuildCreatedOrderIndex()
        ingestEdges(sdEdges)
    }

    /// Populate store directly from in-memory arrays (skips SwiftData fetch).
    /// Used by buildStructuralGraph() to avoid a redundant re-fetch after persist().
    func loadDirect(nodes sdNodes: [SDGraphNode], edges sdEdges: [SDGraphEdge]) {
        let visibleNodes = sdNodes.filter { !Self.hiddenNodeTypes.contains($0.nodeType) }
        prepareForBulkLoad(
            estimatedNodeCount: visibleNodes.count,
            estimatedEdgeCount: sdEdges.count
        )

        for (index, sdNode) in visibleNodes.enumerated() {
            let position: SIMD2<Float> = positionHints.removeValue(forKey: sdNode.id)
                ?? Self.initialSpiralPosition(index: index, nodeCount: visibleNodes.count)

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
            registerSourceLookup(for: record)
            registerTypeLookup(for: record)
            let nodeIdx = assignNodeIndex(record.id)
            addToTrigramIndex(nodeIdx: nodeIdx, label: record.label)
        }
        rebuildCreatedOrderIndex()

        ingestEdges(sdEdges)
    }

    /// Populate store from pre-built Sendable records (no SwiftData fetch).
    /// Used by background graph loading to avoid main-thread SwiftData access.
    func loadFromRecords(nodeRecords: [GraphNodeRecord], edgeRecords: [GraphEdgeRecord]) {
        prepareForBulkLoad(
            estimatedNodeCount: nodeRecords.count,
            estimatedEdgeCount: edgeRecords.count
        )

        for record in nodeRecords where !Self.hiddenNodeTypes.contains(record.type) {
            nodes[record.id] = record
            registerSourceLookup(for: record)
            registerTypeLookup(for: record)
            let nodeIdx = assignNodeIndex(record.id)
            addToTrigramIndex(nodeIdx: nodeIdx, label: record.label)
        }
        rebuildCreatedOrderIndex()

        ingestEdgeRecords(edgeRecords)
    }

    private func ingestEdgeRecords(_ edgeRecords: [GraphEdgeRecord]) {
        for record in edgeRecords {
            guard record.type != .quotes else { continue }
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

            guard record.type != .quotes else { continue }
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

    /// Neighbor labels without constructing intermediary node arrays.
    func neighborLabels(of nodeId: String) -> [String] {
        guard let idx = _nodeIdx[nodeId], idx < _neighbors.count else { return [] }
        if let cached = neighborLabelsCache[nodeId] {
            return cached
        }

        let neighborIndices = _neighbors[idx]
        var labels: [String] = []
        labels.reserveCapacity(neighborIndices.count)

        for neighborIdx in neighborIndices where neighborIdx < _nodeIds.count {
            let neighborId = _nodeIds[neighborIdx]
            guard !neighborId.isEmpty, let label = nodes[neighborId]?.label else { continue }
            labels.append(label)
        }

        neighborLabelsCache[nodeId] = labels
        return labels
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
        (_typeLookup[type] ?? []).compactMap { nodes[$0] }
    }

    func nodes(ofTypes types: [GraphNodeType]) -> [GraphNodeRecord] {
        guard !types.isEmpty else { return [] }
        if types.count == 1, let type = types.first {
            return nodes(ofType: type)
        }

        return types.flatMap { type in
            (_typeLookup[type] ?? []).compactMap { nodes[$0] }
        }
    }

    func firstNode(ofType type: GraphNodeType) -> GraphNodeRecord? {
        guard let nodeID = _typeLookup[type]?.first else { return nil }
        return nodes[nodeID]
    }

    func forEachNodeNewestFirst(
        ofTypes types: [GraphNodeType]? = nil,
        _ body: (GraphNodeRecord) -> Bool
    ) {
        for nodeID in _nodeIdsByCreatedAtDesc {
            guard let node = nodes[nodeID] else { continue }
            if let types, !types.contains(node.type) {
                continue
            }
            guard body(node) else { break }
        }
    }

    /// Exact case-insensitive substring matches backed by the trigram candidate index.
    func nodes(
        matchingLabelContains query: String,
        types: [GraphNodeType]? = nil
    ) -> [GraphNodeRecord] {
        guard !query.isEmpty else {
            guard let types else { return Array(nodes.values) }
            if types.count == 1, let type = types.first {
                return nodes(ofType: type)
            }
            return nodes.values.filter { types.contains($0.type) }
        }

        return candidateNodes(forLowercasedQuery: query.lowercased()).filter { node in
            if let types, !types.contains(node.type) {
                return false
            }
            return node.label.range(of: query, options: .caseInsensitive) != nil
        }
    }

    /// Find a node by its sourceId and type (e.g., the graph node for a specific SDPage).
    func node(bySourceId sourceId: String, type: GraphNodeType) -> GraphNodeRecord? {
        let key = SourceLookupKey(sourceId: sourceId, type: type)
        guard let nodeID = _sourceLookup[key] else { return nil }
        return nodes[nodeID]
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
        if let existing = nodes[node.id] {
            unregisterSourceLookup(for: existing)
            unregisterTypeLookup(for: existing)
        }
        nodes[node.id] = node
        registerSourceLookup(for: node)
        registerTypeLookup(for: node)
        let nodeIdx = assignNodeIndex(node.id)
        addToTrigramIndex(nodeIdx: nodeIdx, label: node.label)
        insertIntoCreatedOrderIndex(node)
        clearSearchCache()
        neighborLabelsCache.removeAll(keepingCapacity: true)
        topologyVersion += 1
        notifyChange([.graphNodes])
    }

    /// Replace a node's non-topology fields while preserving its adjacency slot.
    /// Layout and UI flags stay anchored to the current live graph state.
    func updateNode(_ node: GraphNodeRecord) {
        guard let existing = nodes[node.id] else {
            addNode(node)
            return
        }
        guard let nodeIdx = _nodeIdx[node.id] else { return }

        if existing.label != node.label {
            removeFromTrigramIndex(nodeIdx: nodeIdx, label: existing.label)
            addToTrigramIndex(nodeIdx: nodeIdx, label: node.label)
        }

        var updated = node
        updated.position = existing.position
        updated.velocity = existing.velocity
        updated.isVisible = existing.isVisible
        updated.isPinned = existing.isPinned
        unregisterSourceLookup(for: existing)
        unregisterTypeLookup(for: existing)
        removeFromCreatedOrderIndex(nodeID: existing.id)
        nodes[node.id] = updated
        registerSourceLookup(for: updated)
        registerTypeLookup(for: updated)
        insertIntoCreatedOrderIndex(updated)
        if existing.label != node.label {
            clearSearchCache()
            neighborLabelsCache.removeAll(keepingCapacity: true)
        }
        notifyChange([.graphNodes])
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
        neighborLabelsCache.removeAll(keepingCapacity: true)
        topologyVersion += 1
        notifyChange([.graphEdges])
    }

    /// Remove a node and all its edges, cleaning up compact adjacency.
    func removeNode(_ nodeId: String) {
        guard let nodeIdx = _nodeIdx[nodeId] else { return }
        guard let existing = nodes[nodeId] else { return }

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
            edgeTombstoneCount += 1
        }

        // Remove from trigram index
        removeFromTrigramIndex(nodeIdx: nodeIdx, label: existing.label)
        unregisterSourceLookup(for: existing)
        unregisterTypeLookup(for: existing)
        removeFromCreatedOrderIndex(nodeID: existing.id)

        // Tombstone the node's compact slot
        nodes.removeValue(forKey: nodeId)
        _nodeIdx.removeValue(forKey: nodeId)
        _nodeIds[nodeIdx] = ""  // Tombstone
        nodeTombstoneCount += 1
        _neighbors[nodeIdx] = []
        _edgesOf[nodeIdx] = []

        if nodes.isEmpty && edges.isEmpty {
            resetStorage(keepingCapacity: false)
            notifyChange([.graphNodes, .graphEdges])
            return
        }

        compactStorageIfNeeded()
        clearSearchCache()
        neighborLabelsCache.removeAll(keepingCapacity: true)
        topologyVersion += 1
        notifyChange([.graphNodes, .graphEdges])
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
        edgeTombstoneCount += 1
        compactStorageIfNeeded()
        neighborLabelsCache.removeAll(keepingCapacity: true)
        topologyVersion += 1
        notifyChange([.graphEdges])
    }

    // MARK: - Change Notification (debounced for ReactiveQuery)

    /// Post an immediate invalidation signal.
    /// ReactiveQuery owns the only debounce window for this path.
    private func notifyChange(_ dependencies: Set<QueryDependencyKey>) {
        NotificationCenter.default.post(
            name: .graphStoreDidChange,
            object: nil,
            userInfo: QueryDependencyKey.userInfo(for: dependencies)
        )
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
        let key = SearchCacheKey(query: q, limit: limit)
        let now = searchCacheNowProvider()

        if let cached = searchCache[key] {
            if cached.expiresAt > now {
                searchCacheHitCount += 1
                touchSearchCacheKey(key)
                return cached.hits
            }
            searchCacheExpiredCount += 1
            removeCachedSearch(for: key)
        }

        searchCacheMissCount += 1

        var hits: [SearchHit] = []
        for node in candidateNodes(forLowercasedQuery: q) {
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

        let result = Array(hits.prefix(limit))
        storeCachedSearch(result, for: key, now: now)
        return result
    }

    private func candidateNodes(forLowercasedQuery query: String) -> [GraphNodeRecord] {
        let candidateIndices = trigramCandidates(for: query)
        var candidates: [GraphNodeRecord] = []
        candidates.reserveCapacity(candidateIndices.count)

        for nodeIdx in candidateIndices {
            guard nodeIdx < _nodeIds.count else { continue }
            let nodeId = _nodeIds[nodeIdx]
            guard !nodeId.isEmpty, let node = nodes[nodeId] else { continue }
            candidates.append(node)
        }

        return candidates
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

    private func clearSearchCache() {
        searchCache.removeAll(keepingCapacity: true)
        searchCacheOrder.removeAll(keepingCapacity: true)
    }

    private func touchSearchCacheKey(_ key: SearchCacheKey) {
        searchCacheOrder.removeAll { $0 == key }
        searchCacheOrder.append(key)
    }

    private func removeCachedSearch(for key: SearchCacheKey) {
        searchCache.removeValue(forKey: key)
        searchCacheOrder.removeAll { $0 == key }
    }

    private func storeCachedSearch(_ hits: [SearchHit], for key: SearchCacheKey, now: Date) {
        searchCache[key] = SearchCacheEntry(
            hits: hits,
            expiresAt: now.addingTimeInterval(SearchCacheConfig.ttl)
        )
        touchSearchCacheKey(key)

        while searchCacheOrder.count > SearchCacheConfig.capacity {
            let evicted = searchCacheOrder.removeFirst()
            searchCache.removeValue(forKey: evicted)
        }
    }

    func searchCacheDebugSnapshot() -> SearchCacheDebugSnapshot {
        SearchCacheDebugSnapshot(
            hits: searchCacheHitCount,
            misses: searchCacheMissCount,
            expired: searchCacheExpiredCount,
            entryCount: searchCache.count
        )
    }

    func compactStorageDebugSnapshot() -> CompactStorageDebugSnapshot {
        CompactStorageDebugSnapshot(
            activeNodeCount: nodes.count,
            nodeSlots: _nodeIds.count,
            nodeTombstones: nodeTombstoneCount,
            nodeCompactionEligible: shouldCompact(
                slotCount: _nodeIds.count,
                tombstoneCount: nodeTombstoneCount
            ),
            activeEdgeCount: edges.count,
            edgeSlots: _edgeIds.count,
            edgeTombstones: edgeTombstoneCount,
            edgeCompactionEligible: shouldCompact(
                slotCount: _edgeIds.count,
                tombstoneCount: edgeTombstoneCount
            )
        )
    }

    func compactStorageForTesting() {
        compactStorage()
    }

    func setSearchCacheNowProviderForTesting(_ provider: @escaping () -> Date) {
        searchCacheNowProvider = provider
    }

    private func registerSourceLookup(for node: GraphNodeRecord) {
        guard let sourceId = node.sourceId else { return }
        _sourceLookup[SourceLookupKey(sourceId: sourceId, type: node.type)] = node.id
    }

    private func unregisterSourceLookup(for node: GraphNodeRecord) {
        guard let sourceId = node.sourceId else { return }
        _sourceLookup.removeValue(forKey: SourceLookupKey(sourceId: sourceId, type: node.type))
    }

    private func registerTypeLookup(for node: GraphNodeRecord) {
        _typeLookup[node.type, default: []].insert(node.id)
    }

    private func unregisterTypeLookup(for node: GraphNodeRecord) {
        _typeLookup[node.type]?.remove(node.id)
        if _typeLookup[node.type]?.isEmpty == true {
            _typeLookup.removeValue(forKey: node.type)
        }
    }

    private func rebuildCreatedOrderIndex() {
        _nodeIdsByCreatedAtDesc = nodes.values
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.id < rhs.id
            }
            .map(\.id)
    }

    private func insertIntoCreatedOrderIndex(_ node: GraphNodeRecord) {
        var insertionIndex = 0
        while insertionIndex < _nodeIdsByCreatedAtDesc.count {
            let existingNodeID = _nodeIdsByCreatedAtDesc[insertionIndex]
            guard let existing = nodes[existingNodeID] else {
                insertionIndex += 1
                continue
            }
            if existing.createdAt < node.createdAt {
                break
            }
            if existing.createdAt == node.createdAt, existing.id >= node.id {
                break
            }
            insertionIndex += 1
        }
        _nodeIdsByCreatedAtDesc.insert(node.id, at: insertionIndex)
    }

    private func removeFromCreatedOrderIndex(nodeID: String) {
        _nodeIdsByCreatedAtDesc.removeAll { $0 == nodeID }
    }

    // MARK: - Link Count (for Rust FFI)

    /// Number of edges touching this node (degree).
    /// Uses compact storage directly — no temporary Set creation.
    func linkCount(for nodeId: String) -> UInt32 {
        guard let idx = _nodeIdx[nodeId], idx < _neighbors.count else { return 0 }
        return UInt32(_neighbors[idx].count)
    }

    /// Snapshot the current store state for background FFI payload building.
    /// Captures a thread-safe copy of nodes, edges, and pre-computed link counts.
    func snapshot() -> GraphStoreSnapshot {
        let nIdx = _nodeIdx
        let neighbors = _neighbors
        var counts: [String: UInt32] = [:]
        counts.reserveCapacity(nIdx.count)

        for (id, idx) in nIdx {
            if idx < neighbors.count {
                counts[id] = UInt32(neighbors[idx].count)
            }
        }

        return GraphStoreSnapshot(
            nodes: nodes,
            edges: edges,
            linkCounts: counts
        )
    }
}
