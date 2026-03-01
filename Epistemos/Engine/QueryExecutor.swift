import Foundation
import QuartzCore

// MARK: - QueryExecutor
// Executes GraphQueryDSL against the appropriate backend.
//
// Backend dispatch:
//   findNodes/findEdges → GraphStore in-memory filter
//   pathBetween/neighbors → GraphStore BFS (shortestPath, nodesLinkedBy)
//   contentSearch → SearchIndexService (GRDB FTS5)
//   semanticSearch → GraphState.hybridSearch (Rust FST + embeddings)
//   aggregation → in-memory computation over GraphStore
//   compound → recursive execution with set operations

@MainActor
final class QueryExecutor {

    private let graphStore: GraphStore
    private let graphState: GraphState
    private let searchIndex: SearchIndexService

    init(graphStore: GraphStore, graphState: GraphState, searchIndex: SearchIndexService) {
        self.graphStore = graphStore
        self.graphState = graphState
        self.searchIndex = searchIndex
    }

    /// Execute a query and return results.
    func execute(_ query: GraphQueryDSL) -> QueryResult {
        let start = CACurrentMediaTime()
        let result = executeInner(query)
        let elapsed = (CACurrentMediaTime() - start) * 1000
        return QueryResult(
            nodes: result.nodes,
            edges: result.edges,
            aggregation: result.aggregation,
            executionTimeMs: elapsed
        )
    }

    // MARK: - Internal Dispatch

    private func executeInner(_ query: GraphQueryDSL) -> QueryResult {
        switch query {
        case .findNodes(let filter):
            return executeFindNodes(filter)

        case .findEdges(let filter):
            return executeFindEdges(filter)

        case .pathBetween(let from, let to, let maxHops):
            return executePathBetween(from: from, to: to, maxHops: maxHops)

        case .neighbors(let nodeRef, let edgeTypes, let depth):
            return executeNeighbors(of: nodeRef, edgeTypes: edgeTypes, depth: depth)

        case .aggregation(let aggType):
            return executeAggregation(aggType)

        case .contentSearch(let searchQuery, let nodeTypes):
            return executeContentSearch(query: searchQuery, nodeTypes: nodeTypes)

        case .semanticSearch(let searchQuery, let limit):
            return executeSemanticSearch(query: searchQuery, limit: limit)

        case .compound(let subQueries, let combiner):
            return executeCompound(subQueries, combiner: combiner)
        }
    }

    // MARK: - Find Nodes

    private func executeFindNodes(_ filter: NodeFilter) -> QueryResult {
        var results = Array(graphStore.nodes.values)

        if let types = filter.types {
            results = results.filter { types.contains($0.type) }
        }
        if let labelContains = filter.labelContains {
            let lower = labelContains.lowercased()
            results = results.filter { $0.label.lowercased().contains(lower) }
        }
        if let after = filter.createdAfter {
            results = results.filter { $0.createdAt >= after }
        }
        if let before = filter.createdBefore {
            results = results.filter { $0.createdAt <= before }
        }
        if let meta = filter.metadata {
            if let stage = meta.researchStage {
                results = results.filter { $0.metadata.researchStage == stage }
            }
            if let hasURL = meta.hasURL {
                results = results.filter { hasURL ? $0.metadata.url != nil : $0.metadata.url == nil }
            }
        }

        // Sort by creation date descending
        results.sort { $0.createdAt > $1.createdAt }

        let nodes = Array(results.prefix(filter.limit)).map {
            QueryResultNode(from: $0)
        }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    // MARK: - Find Edges

    private func executeFindEdges(_ filter: EdgeFilter) -> QueryResult {
        var results = Array(graphStore.edges.values)

        if let types = filter.types {
            results = results.filter { types.contains($0.type) }
        }

        if let nodeRef = filter.involvingNodeRef {
            if let nodeId = resolveNodeRef(nodeRef) {
                results = results.filter {
                    $0.sourceNodeId == nodeId || $0.targetNodeId == nodeId
                }
            }
        }

        let edgeResults = Array(results.prefix(filter.limit)).map { edge -> QueryResultEdge in
            let srcLabel = graphStore.nodes[edge.sourceNodeId]?.label ?? "?"
            let tgtLabel = graphStore.nodes[edge.targetNodeId]?.label ?? "?"
            return QueryResultEdge(
                id: edge.id,
                sourceLabel: srcLabel,
                targetLabel: tgtLabel,
                type: edge.type,
                weight: edge.weight
            )
        }
        return QueryResult(nodes: [], edges: edgeResults, aggregation: nil, executionTimeMs: 0)
    }

    // MARK: - Path Between

    private func executePathBetween(from: NodeRef, to: NodeRef, maxHops: Int) -> QueryResult {
        guard let fromId = resolveNodeRef(from),
              let toId = resolveNodeRef(to) else {
            return .empty
        }

        let path = graphStore.query(.pathBetween(from: fromId, to: toId, maxHops: maxHops))
        let nodes = path.map { record in
            QueryResultNode(from: record, score: nil)
        }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    // MARK: - Neighbors

    private func executeNeighbors(of nodeRef: NodeRef, edgeTypes: [GraphEdgeType]?, depth: Int) -> QueryResult {
        guard let nodeId = resolveNodeRef(nodeRef) else { return .empty }

        if let edgeTypes {
            // Filter by specific edge types
            var allNeighbors: [GraphNodeRecord] = []
            for edgeType in edgeTypes {
                let neighbors = graphStore.query(.nodesWithEdgeType(edgeType, from: nodeId))
                allNeighbors.append(contentsOf: neighbors)
            }
            // Deduplicate
            var seen = Set<String>()
            let unique = allNeighbors.filter { seen.insert($0.id).inserted }
            let nodes = unique.map { QueryResultNode(from: $0) }
            return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
        } else {
            // All neighbors via BFS
            let connectedIds = graphStore.connected(to: nodeId, maxDepth: depth)
            let nodes = connectedIds
                .compactMap { graphStore.nodes[$0] }
                .filter { $0.id != nodeId }
                .map { QueryResultNode(from: $0) }
            return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
        }
    }

    // MARK: - Aggregation

    private func executeAggregation(_ aggType: AggregationType) -> QueryResult {
        switch aggType {
        case .countByType:
            var counts: [GraphNodeType: Int] = [:]
            for node in graphStore.nodes.values {
                counts[node.type, default: 0] += 1
            }
            let rows = counts.sorted { $0.value > $1.value }
                .map { (label: $0.key.displayName, value: $0.value) }
            return QueryResult(
                nodes: [], edges: [],
                aggregation: QueryAggregation(title: "Nodes by Type", rows: rows),
                executionTimeMs: 0
            )

        case .countByEdgeType:
            var counts: [GraphEdgeType: Int] = [:]
            for edge in graphStore.edges.values {
                counts[edge.type, default: 0] += 1
            }
            let rows = counts.sorted { $0.value > $1.value }
                .map { (label: $0.key.rawValue, value: $0.value) }
            return QueryResult(
                nodes: [], edges: [],
                aggregation: QueryAggregation(title: "Edges by Type", rows: rows),
                executionTimeMs: 0
            )

        case .mostConnected(let limit):
            let sorted = graphStore.nodes.values
                .sorted { (graphStore.adjacency[$0.id]?.count ?? 0) > (graphStore.adjacency[$1.id]?.count ?? 0) }
            let nodes = Array(sorted.prefix(limit)).map { node in
                QueryResultNode(from: node, score: Float(graphStore.adjacency[node.id]?.count ?? 0))
            }
            return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)

        case .recentlyCreated(let limit):
            let sorted = graphStore.nodes.values
                .sorted { $0.createdAt > $1.createdAt }
            let nodes = Array(sorted.prefix(limit)).map { QueryResultNode(from: $0) }
            return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)

        case .orphans:
            let orphans = graphStore.nodes.values.filter {
                (graphStore.adjacency[$0.id] ?? []).isEmpty
            }
            let nodes = orphans.map { QueryResultNode(from: $0) }
            return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
        }
    }

    // MARK: - Content Search

    private func executeContentSearch(query: String, nodeTypes: [GraphNodeType]?) -> QueryResult {
        let searchResults = (try? searchIndex.search(query: query)) ?? []

        var nodes: [QueryResultNode] = []
        for result in searchResults {
            // Map search result (page-based) to graph node
            if let graphNode = graphStore.node(bySourceId: result.pageId, type: .note) {
                if let types = nodeTypes, !types.contains(graphNode.type) { continue }
                nodes.append(QueryResultNode(
                    from: graphNode,
                    score: Float(result.rank),
                    snippet: result.snippet
                ))
            }
        }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    // MARK: - Semantic Search

    private func executeSemanticSearch(query: String, limit: Int) -> QueryResult {
        let hits = graphState.hybridSearch(query: query, limit: limit)
        let nodes = hits.map {
            QueryResultNode(from: $0.node, score: $0.score)
        }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    // MARK: - Compound

    private func executeCompound(_ subQueries: [GraphQueryDSL], combiner: SetCombiner) -> QueryResult {
        guard !subQueries.isEmpty else { return .empty }

        var resultSets: [Set<String>] = []
        var nodeMap: [String: QueryResultNode] = [:]

        for subQuery in subQueries {
            let result = executeInner(subQuery)
            var idSet = Set<String>()
            for node in result.nodes {
                idSet.insert(node.id)
                nodeMap[node.id] = node
            }
            resultSets.append(idSet)
        }

        var combined = resultSets[0]
        for i in 1..<resultSets.count {
            switch combiner {
            case .union:
                combined = combined.union(resultSets[i])
            case .intersection:
                combined = combined.intersection(resultSets[i])
            case .difference:
                combined = combined.subtracting(resultSets[i])
            }
        }

        let nodes = combined.compactMap { nodeMap[$0] }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    // MARK: - Node Resolution

    /// Resolve a NodeRef to a concrete node ID.
    private func resolveNodeRef(_ ref: NodeRef) -> String? {
        switch ref {
        case .id(let id):
            return graphStore.nodes[id] != nil ? id : nil

        case .label(let label):
            // Fuzzy search for the best matching node
            let hits = graphStore.fuzzySearch(query: label, limit: 1)
            return hits.first?.id

        case .type(let type):
            // Return the first node of this type (mainly for aggregation)
            return graphStore.nodes.values.first { $0.type == type }?.id
        }
    }
}
