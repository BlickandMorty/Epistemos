import Foundation
import QuartzCore

// MARK: - QueryRuntime
// Executes QueryPlan against the appropriate backends.

@MainActor
final class QueryRuntime {

    private let graphStore: GraphStore
    private let graphState: GraphState
    private let searchIndex: SearchIndexService

    init(graphStore: GraphStore, graphState: GraphState, searchIndex: SearchIndexService) {
        self.graphStore = graphStore
        self.graphState = graphState
        self.searchIndex = searchIndex
    }

    func execute(_ plan: QueryPlan) -> QueryResult {
        let start = CACurrentMediaTime()

        let raw: QueryResult
        if plan.steps.count == 1 && plan.combiner == .single {
            raw = executeStep(plan.steps[0])
        } else {
            raw = executeCombined(plan)
        }

        // Apply projection (limit/offset/orderBy)
        var nodes = raw.nodes
        if let orderBy = plan.orderBy {
            nodes = applyOrdering(nodes, orderBy: orderBy)
        }
        if let offset = plan.offset, offset > 0 {
            nodes = Array(nodes.dropFirst(offset))
        }
        if let limit = plan.limit {
            nodes = Array(nodes.prefix(limit))
        }

        let elapsed = (CACurrentMediaTime() - start) * 1000
        return QueryResult(
            nodes: nodes,
            edges: raw.edges,
            aggregation: raw.aggregation,
            executionTimeMs: elapsed
        )
    }

    private func applyOrdering(_ nodes: [QueryResultNode], orderBy: OrderBy) -> [QueryResultNode] {
        switch orderBy {
        case .relevance:
            return nodes.sorted { ($0.score ?? 0) > ($1.score ?? 0) }
        case .connections:
            return nodes.sorted {
                (graphStore.adjacency[$0.id]?.count ?? 0) > (graphStore.adjacency[$1.id]?.count ?? 0)
            }
        case .created(let ascending):
            return nodes.sorted {
                let a = graphStore.nodes[$0.id]?.createdAt ?? .distantPast
                let b = graphStore.nodes[$1.id]?.createdAt ?? .distantPast
                return ascending ? a < b : a > b
            }
        case .updated(let ascending):
            return nodes.sorted {
                let a = graphStore.nodes[$0.id]?.updatedAt ?? .distantPast
                let b = graphStore.nodes[$1.id]?.updatedAt ?? .distantPast
                return ascending ? a < b : a > b
            }
        }
    }

    /// Convenience: parse + compile + execute in one call.
    func query(_ input: String) -> QueryResult {
        let ast: QueryAST?
        if input.hasPrefix("?") {
            ast = StructuredQueryParser.parse(input)
        } else {
            // Use upgraded NL parser (Task 5)
            ast = QueryParser.parseToAST(input)
        }
        guard let ast else { return .empty }
        let plan = QueryCompiler.compile(ast)
        return execute(plan)
    }

    // MARK: - Step Execution

    private func executeStep(_ step: QueryPlan.QueryStep) -> QueryResult {
        switch step {
        case .graphStoreFilter(let filter):
            return executeNodeFilter(filter)

        case .graphStoreEdgeFilter(let filter):
            return executeEdgeFilter(filter)

        case .graphStorePath(let from, let to, let maxHops):
            return executePath(from: from, to: to, maxHops: maxHops)

        case .graphStoreNeighbors(let nodeRef, let edgeTypes, let depth):
            return executeNeighbors(of: nodeRef, edgeTypes: edgeTypes, depth: depth)

        case .fts5Search(let query, let scope):
            return executeFTS(query: query, scope: scope)

        case .semanticSearch(let query, _, let limit):
            return executeSemantic(query: query, limit: limit)

        case .btkPropertyFilter(let key, let op, let value):
            return executeBTKPropertyFilter(key: key, op: op, value: value)

        case .btkDepthFilter(let op, let value):
            return executeBTKDepthFilter(op: op, value: value)

        case .inMemoryLabelFilter(let text):
            return executeLabelFilter(text)
        }
    }

    // MARK: - Combined Execution

    private func executeCombined(_ plan: QueryPlan) -> QueryResult {
        var resultSets: [Set<String>] = []
        var nodeMap: [String: QueryResultNode] = [:]

        // Execute direct steps
        for step in plan.steps {
            let result = executeStep(step)
            collectResult(result, into: &resultSets, nodeMap: &nodeMap)
        }

        // Execute nested sub-plans recursively
        for subPlan in plan.subPlans {
            let result = execute(subPlan)
            collectResult(result, into: &resultSets, nodeMap: &nodeMap)
        }

        guard !resultSets.isEmpty else { return .empty }

        let combined: Set<String>
        switch plan.combiner {
        case .intersection:
            var acc = resultSets[0]
            for i in 1..<resultSets.count { acc = acc.intersection(resultSets[i]) }
            combined = acc
        case .union:
            var acc = resultSets[0]
            for i in 1..<resultSets.count { acc = acc.union(resultSets[i]) }
            combined = acc
        case .complement:
            // NOT: full universe minus the matched set
            let excluded = resultSets.reduce(into: Set<String>()) { $0.formUnion($1) }
            let allIds = Set(graphStore.nodes.keys)
            combined = allIds.subtracting(excluded)
            // Populate nodeMap for complement nodes
            for id in combined where nodeMap[id] == nil {
                if let node = graphStore.nodes[id] {
                    nodeMap[id] = QueryResultNode(from: node)
                }
            }
        case .single, .sequential:
            combined = resultSets[0]
        }

        let nodes = combined.compactMap { nodeMap[$0] }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func collectResult(_ result: QueryResult, into sets: inout [Set<String>], nodeMap: inout [String: QueryResultNode]) {
        var idSet = Set<String>()
        for node in result.nodes {
            idSet.insert(node.id)
            nodeMap[node.id] = node
        }
        sets.append(idSet)
    }

    // MARK: - Backend Implementations

    private func executeNodeFilter(_ filter: NodeFilter) -> QueryResult {
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
        if let after = filter.updatedAfter {
            results = results.filter { $0.updatedAt >= after }
        }
        if let before = filter.updatedBefore {
            results = results.filter { $0.updatedAt <= before }
        }
        results.sort { $0.createdAt > $1.createdAt }
        let nodes = Array(results.prefix(filter.limit)).map { QueryResultNode(from: $0) }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func executeEdgeFilter(_ filter: EdgeFilter) -> QueryResult {
        var results = Array(graphStore.edges.values)
        if let types = filter.types {
            results = results.filter { types.contains($0.type) }
        }
        let edgeResults = Array(results.prefix(filter.limit)).map { edge -> QueryResultEdge in
            QueryResultEdge(
                id: edge.id,
                sourceLabel: graphStore.nodes[edge.sourceNodeId]?.label ?? "?",
                targetLabel: graphStore.nodes[edge.targetNodeId]?.label ?? "?",
                type: edge.type,
                weight: edge.weight
            )
        }
        return QueryResult(nodes: [], edges: edgeResults, aggregation: nil, executionTimeMs: 0)
    }

    private func executePath(from: NodeRef, to: NodeRef, maxHops: Int) -> QueryResult {
        guard let fromId = resolveNodeRef(from),
              let toId = resolveNodeRef(to) else { return .empty }
        let path = graphStore.query(.pathBetween(from: fromId, to: toId, maxHops: maxHops))
        let nodes = path.map { QueryResultNode(from: $0, score: nil) }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func executeNeighbors(of nodeRef: NodeRef, edgeTypes: [GraphEdgeType]?, depth: Int) -> QueryResult {
        guard let nodeId = resolveNodeRef(nodeRef) else { return .empty }
        if let edgeTypes {
            var allNeighbors: [GraphNodeRecord] = []
            for edgeType in edgeTypes {
                allNeighbors.append(contentsOf: graphStore.query(.nodesWithEdgeType(edgeType, from: nodeId)))
            }
            var seen = Set<String>()
            let unique = allNeighbors.filter { seen.insert($0.id).inserted }
            let nodes = unique.map { QueryResultNode(from: $0) }
            return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
        } else {
            let connectedIds = graphStore.connected(to: nodeId, maxDepth: depth)
            let nodes = connectedIds
                .compactMap { graphStore.nodes[$0] }
                .filter { $0.id != nodeId }
                .map { QueryResultNode(from: $0) }
            return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
        }
    }

    private func executeFTS(query: String, scope: SearchScope) -> QueryResult {
        var seen = Set<String>()
        var nodes: [QueryResultNode] = []

        // Page-level FTS (unless scope is blocks-only)
        if scope != .blocks {
            let results = (try? searchIndex.search(query: query)) ?? []
            for result in results {
                if let graphNode = graphStore.node(bySourceId: result.pageId, type: .note),
                   seen.insert(graphNode.id).inserted {
                    nodes.append(QueryResultNode(from: graphNode, score: Float(result.rank), snippet: result.snippet))
                }
            }
        }

        // Block-level FTS (for .blocks and .all scopes)
        if scope == .blocks || scope == .all {
            let blockResults = (try? searchIndex.searchBlocks(query: query)) ?? []
            for result in blockResults {
                if let graphNode = graphStore.node(bySourceId: result.pageId, type: .note),
                   seen.insert(graphNode.id).inserted {
                    nodes.append(QueryResultNode(from: graphNode, score: Float(result.rank), snippet: result.snippet))
                }
            }
        }

        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func executeSemantic(query: String, limit: Int) -> QueryResult {
        let hits = graphState.hybridSearch(query: query, limit: limit)
        let nodes = hits.map { QueryResultNode(from: $0.node, score: $0.score) }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func executeBTKPropertyFilter(key: String, op: CompOp, value: PropertyValue) -> QueryResult {
        guard let engine = graphState.engineHandle else { return .empty }

        let opCode = op.ffiCode
        let (valType, valStr) = value.ffiEncoded

        let resultPtr = key.withCString { keyPtr in
            valStr.withCString { valPtr in
                graph_engine_btk_query_property(engine, keyPtr, opCode, valType, valPtr)
            }
        }
        return pageIdsToQueryResult(resultPtr)
    }

    private func executeBTKDepthFilter(op: CompOp, value: Int) -> QueryResult {
        guard let engine = graphState.engineHandle else { return .empty }

        let resultPtr = graph_engine_btk_query_depth(engine, op.ffiCode, UInt32(max(0, value)))
        return pageIdsToQueryResult(resultPtr)
    }

    /// Convert newline-separated page_ids from FFI into QueryResult by looking up graph nodes.
    private func pageIdsToQueryResult(_ ptr: UnsafePointer<CChar>?) -> QueryResult {
        guard let ptr else { return .empty }
        let str = String(cString: ptr)
        graph_engine_free_string(UnsafeMutablePointer(mutating: ptr))

        let pageIds = str.split(separator: "\n").map(String.init)
        let nodes = pageIds.compactMap { pageId -> QueryResultNode? in
            guard let node = graphStore.node(bySourceId: pageId, type: .note) else { return nil }
            return QueryResultNode(from: node)
        }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func executeLabelFilter(_ text: String) -> QueryResult {
        let lower = text.lowercased()
        let matches = graphStore.nodes.values.filter {
            $0.label.lowercased().contains(lower)
        }
        let nodes = matches.map { QueryResultNode(from: $0) }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func resolveNodeRef(_ ref: NodeRef) -> String? {
        switch ref {
        case .id(let id): return graphStore.nodes[id] != nil ? id : nil
        case .label(let label): return graphStore.fuzzySearch(query: label, limit: 1).first?.id
        case .type(let type): return graphStore.nodes.values.first { $0.type == type }?.id
        }
    }
}
