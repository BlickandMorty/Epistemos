import Foundation
import QuartzCore

@MainActor
private func makeQueryResultNode(
    from record: GraphNodeRecord,
    in graphStore: GraphStore,
    score: Float? = nil,
    snippet: String? = nil
) -> QueryResultNode {
    QueryResultNode(
        from: record,
        score: score,
        snippet: snippet,
        connectionCount: graphStore.linkCount(for: record.id)
    )
}

nonisolated enum BTKQueryPageIDBufferDecoder {
    static func decode(_ buffer: GraphEngineByteBuffer) -> [String] {
        guard let ptr = buffer.ptr, buffer.len > 0 else {
            if buffer.capacity > 0 {
                graph_engine_free_bytes(buffer)
            }
            return []
        }

        defer { graph_engine_free_bytes(buffer) }
        let bytes = UnsafeRawBufferPointer(start: ptr, count: Int(buffer.len))
        return decode(bytes)
    }

    static func decode(_ bytes: UnsafeRawBufferPointer) -> [String] {
        guard let count = readUInt32(bytes, offset: 0) else { return [] }

        var offset = 4
        var pageIDs: [String] = []
        pageIDs.reserveCapacity(Int(count))

        for _ in 0..<count {
            guard let length = readUInt32(bytes, offset: offset) else { return [] }
            offset += 4
            let byteCount = Int(length)
            guard byteCount >= 0, offset + byteCount <= bytes.count else { return [] }
            let slice = bytes[offset..<(offset + byteCount)]
            pageIDs.append(String(decoding: slice, as: UTF8.self))
            offset += byteCount
        }

        return offset == bytes.count ? pageIDs : []
    }

    private static func readUInt32(
        _ bytes: UnsafeRawBufferPointer,
        offset: Int
    ) -> UInt32? {
        guard offset >= 0, offset + 4 <= bytes.count else { return nil }
        let start = bytes[offset]
        let byte1 = bytes[offset + 1]
        let byte2 = bytes[offset + 2]
        let byte3 = bytes[offset + 3]
        return UInt32(start)
            | (UInt32(byte1) << 8)
            | (UInt32(byte2) << 16)
            | (UInt32(byte3) << 24)
    }
}

nonisolated enum RetrievalCandidateSource: Sendable {
    case pageSearch
    case blockSearch
    case semanticGraph
}

nonisolated struct RetrievalCandidate: Sendable {
    let node: QueryResultNode
    let source: RetrievalCandidateSource
}

@MainActor
protocol RetrievalReranking {
    func rerank(query: String, candidates: [RetrievalCandidate]) -> [RetrievalCandidate]
}

struct PassthroughRetrievalReranker: RetrievalReranking {
    func rerank(query: String, candidates: [RetrievalCandidate]) -> [RetrievalCandidate] {
        candidates
    }
}

@MainActor
protocol PreparedRetrievalRuntimeResolving {
    func resolveReranker(
        configuration: PreparedRetrievalRuntimeConfiguration?,
        executionMode: PreparedRetrievalExecutionMode,
        graphState: GraphState
    ) -> any RetrievalReranking

    func resolveEmbeddingLookup(
        configuration: PreparedRetrievalRuntimeConfiguration?,
        executionMode: PreparedRetrievalExecutionMode,
        fallback: any TextEmbeddingLookup
    ) -> any TextEmbeddingLookup
}

struct DefaultPreparedRetrievalRuntimeResolver: PreparedRetrievalRuntimeResolving {
    func resolveReranker(
        configuration: PreparedRetrievalRuntimeConfiguration?,
        executionMode: PreparedRetrievalExecutionMode,
        graphState: GraphState
    ) -> any RetrievalReranking {
        guard executionMode.hasPreparedIndexRuntime else {
            return PassthroughRetrievalReranker()
        }
        return PreparedIndexSimilarityReranker(
            graphState: graphState,
            embeddingService: graphState.embeddingService
        )
    }

    func resolveEmbeddingLookup(
        configuration: PreparedRetrievalRuntimeConfiguration?,
        executionMode: PreparedRetrievalExecutionMode,
        fallback: any TextEmbeddingLookup
    ) -> any TextEmbeddingLookup {
        fallback
    }
}

@MainActor
final class PreparedIndexSimilarityReranker: RetrievalReranking {
    private weak var graphState: GraphState?
    private let embeddingService: EmbeddingService

    init(graphState: GraphState, embeddingService: EmbeddingService) {
        self.graphState = graphState
        self.embeddingService = embeddingService
    }

    func rerank(query: String, candidates: [RetrievalCandidate]) -> [RetrievalCandidate] {
        guard candidates.count > 1,
              embeddingService.preparedRetrievalExecutionMode.hasPreparedIndexRuntime,
              let graphState,
              graphState.ensurePreparedRetrievalIndexLoaded(),
              let engine = graphState.engineHandle else {
            return candidates
        }

        let dimension = Int(graph_engine_prepared_retrieval_dimension(engine))
        guard dimension > 0,
              let queryVector = embeddingService.queryEmbedding(for: query, expectedDimension: dimension) else {
            return candidates
        }

        let candidatePageIDs = candidates.compactMap(\.node.sourceId)
        guard candidatePageIDs.count > 1 else { return candidates }

        let scores = queryVector.withUnsafeBufferPointer { queryBuffer -> [String: Float] in
            guard let queryBaseAddress = queryBuffer.baseAddress else { return [:] }
            return withStableCStringArray(candidatePageIDs) { pointerBuffer in
                let list = graph_engine_prepared_retrieval_score_page_ids(
                    engine,
                    queryBaseAddress,
                    UInt32(dimension),
                    pointerBuffer.baseAddress,
                    UInt32(candidatePageIDs.count)
                )
                defer { graph_engine_free_prepared_retrieval_candidates(list) }
                guard let candidates = list.candidates, list.count > 0 else { return [:] }

                var scoreMap: [String: Float] = [:]
                scoreMap.reserveCapacity(Int(list.count))
                for index in 0..<Int(list.count) {
                    let result = candidates[index]
                    let pageID = result.page_id.map { String(cString: $0) } ?? ""
                    guard !pageID.isEmpty else { continue }
                    scoreMap[pageID] = result.score
                }
                return scoreMap
            } ?? [:]
        }

        guard !scores.isEmpty else { return candidates }

        let indexedCandidates = Array(candidates.enumerated())
        return indexedCandidates
            .sorted { lhs, rhs in
                let lhsScore = lhs.element.node.sourceId.flatMap { scores[$0] } ?? -.greatestFiniteMagnitude
                let rhsScore = rhs.element.node.sourceId.flatMap { scores[$0] } ?? -.greatestFiniteMagnitude
                if lhsScore == rhsScore {
                    return lhs.offset < rhs.offset
                }
                return lhsScore > rhsScore
            }
            .map(\.element)
    }
}

@MainActor
final class RetrievalRuntime {
    private enum RetrievalPolicy {
        static let rerankLimit = 12
    }

    private let graphStore: GraphStore
    private let graphState: GraphState
    private let searchIndex: SearchIndexService
    private let reranker: any RetrievalReranking
    private let rerankLimit: Int

    init(
        graphStore: GraphStore,
        graphState: GraphState,
        searchIndex: SearchIndexService,
        reranker: any RetrievalReranking = PassthroughRetrievalReranker(),
        rerankLimit: Int = RetrievalPolicy.rerankLimit
    ) {
        self.graphStore = graphStore
        self.graphState = graphState
        self.searchIndex = searchIndex
        self.reranker = reranker
        self.rerankLimit = max(0, rerankLimit)
    }

    func fullText(query: String, scope: SearchScope, limit: Int = 50) -> [QueryResultNode] {
        var seen = Set<String>()
        var candidates: [RetrievalCandidate] = []

        if scope != .blocks {
            let results = (try? searchIndex.search(query: query, limit: limit)) ?? []
            for result in results {
                appendNoteResult(
                    pageId: result.pageId,
                    score: Float(result.rank),
                    snippet: result.snippet,
                    source: .pageSearch,
                    seen: &seen,
                    candidates: &candidates
                )
            }
        }

        if scope == .blocks || scope == .all {
            let blockResults = (try? searchIndex.searchBlocks(query: query, limit: limit)) ?? []
            for result in blockResults {
                appendNoteResult(
                    pageId: result.pageId,
                    score: Float(result.rank),
                    snippet: result.snippet,
                    source: .blockSearch,
                    seen: &seen,
                    candidates: &candidates
                )
            }
        }

        return rerankedCandidates(query: query, candidates: candidates).map(\.node)
    }

    func semantic(query: String, limit: Int) -> [QueryResultNode] {
        let candidates = graphState.semanticSearch(query: query, limit: limit).map {
            RetrievalCandidate(
                node: makeQueryResultNode(from: $0.node, in: graphStore, score: $0.score),
                source: .semanticGraph
            )
        }
        return rerankedCandidates(query: query, candidates: candidates).map(\.node)
    }

    private func appendNoteResult(
        pageId: String,
        score: Float,
        snippet: String,
        source: RetrievalCandidateSource,
        seen: inout Set<String>,
        candidates: inout [RetrievalCandidate]
    ) {
        guard let graphNode = graphStore.node(bySourceId: pageId, type: .note),
              seen.insert(graphNode.id).inserted else { return }
        candidates.append(
            RetrievalCandidate(
                node: makeQueryResultNode(
                    from: graphNode,
                    in: graphStore,
                    score: score,
                    snippet: snippet
                ),
                source: source
            )
        )
    }

    private func rerankedCandidates(
        query: String,
        candidates: [RetrievalCandidate]
    ) -> [RetrievalCandidate] {
        guard candidates.count > 1, rerankLimit > 0 else { return candidates }
        let prefixCount = min(rerankLimit, candidates.count)
        let prefix = Array(candidates.prefix(prefixCount))
        let rerankedPrefix = reranker.rerank(query: query, candidates: prefix)
        guard rerankedPrefix.count == prefix.count,
              Set(rerankedPrefix.map(\.node.id)) == Set(prefix.map(\.node.id)) else {
            return candidates
        }
        return rerankedPrefix + candidates.dropFirst(prefixCount)
    }
}

// MARK: - QueryRuntime
// Executes QueryPlan against the appropriate backends.

@MainActor
final class QueryRuntime {

    private let graphStore: GraphStore
    private let graphState: GraphState
    private let retrieval: RetrievalRuntime

    init(
        graphStore: GraphStore,
        graphState: GraphState,
        searchIndex: SearchIndexService,
        reranker: any RetrievalReranking = PassthroughRetrievalReranker()
    ) {
        self.graphStore = graphStore
        self.graphState = graphState
        retrieval = RetrievalRuntime(
            graphStore: graphStore,
            graphState: graphState,
            searchIndex: searchIndex,
            reranker: reranker
        )
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
                if $0.connectionCount == $1.connectionCount {
                    if $0.createdAt == $1.createdAt {
                        return $0.id < $1.id
                    }
                    return $0.createdAt > $1.createdAt
                }
                return $0.connectionCount > $1.connectionCount
            }
        case .created(let ascending):
            return nodes.sorted {
                let a = $0.createdAt
                let b = $1.createdAt
                guard a != b else { return $0.id < $1.id }
                return ascending ? a < b : a > b
            }
        case .updated(let ascending):
            return nodes.sorted {
                let a = $0.updatedAt
                let b = $1.updatedAt
                guard a != b else { return $0.id < $1.id }
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
            let excluded = resultSets.reduce(into: Set<String>()) { $0.formUnion($1) }
            var nodes: [QueryResultNode] = []
            nodes.reserveCapacity(max(0, graphStore.nodeCount - excluded.count))
            graphStore.forEachNodeNewestFirst { node in
                guard !excluded.contains(node.id) else { return true }
                nodes.append(nodeMap[node.id] ?? makeQueryResultNode(from: node, in: graphStore))
                return true
            }
            return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
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
        guard filter.limit > 0 else { return .empty }

        let labelContains = filter.labelContains
        var results: [GraphNodeRecord] = []
        results.reserveCapacity(min(filter.limit, graphStore.nodeCount))

        if let labelContains {
            appendMatchingNodes(
                from: graphStore.nodes(matchingLabelContains: labelContains, types: filter.types),
                into: &results,
                types: nil,
                labelContains: nil,
                createdAfter: filter.createdAfter,
                createdBefore: filter.createdBefore,
                updatedAfter: filter.updatedAfter,
                updatedBefore: filter.updatedBefore,
                limit: filter.limit
            )
        } else {
            graphStore.forEachNodeNewestFirst(ofTypes: filter.types) { node in
                guard nodeMatchesFilter(
                    node,
                    types: nil,
                    labelContains: nil,
                    createdAfter: filter.createdAfter,
                    createdBefore: filter.createdBefore,
                    updatedAfter: filter.updatedAfter,
                    updatedBefore: filter.updatedBefore
                ) else {
                    return true
                }
                results.append(node)
                return results.count < filter.limit
            }
        }
        let nodes = results.map { makeQueryResultNode(from: $0, in: graphStore) }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func appendMatchingNodes<S: Sequence>(
        from candidates: S,
        into results: inout [GraphNodeRecord],
        types: [GraphNodeType]?,
        labelContains: String?,
        createdAfter: Date?,
        createdBefore: Date?,
        updatedAfter: Date?,
        updatedBefore: Date?,
        limit: Int
    ) where S.Element == GraphNodeRecord {
        for node in candidates {
            guard nodeMatchesFilter(
                node,
                types: types,
                labelContains: labelContains,
                createdAfter: createdAfter,
                createdBefore: createdBefore,
                updatedAfter: updatedAfter,
                updatedBefore: updatedBefore
            ) else { continue }
            insertNewestNode(node, into: &results, limit: limit)
        }
    }

    private func nodeMatchesFilter(
        _ node: GraphNodeRecord,
        types: [GraphNodeType]?,
        labelContains: String?,
        createdAfter: Date?,
        createdBefore: Date?,
        updatedAfter: Date?,
        updatedBefore: Date?
    ) -> Bool {
        if let types, !types.contains(node.type) {
            return false
        }
        if let labelContains,
           node.label.range(of: labelContains, options: .caseInsensitive) == nil {
            return false
        }
        if let createdAfter, node.createdAt < createdAfter {
            return false
        }
        if let createdBefore, node.createdAt > createdBefore {
            return false
        }
        if let updatedAfter, node.updatedAt < updatedAfter {
            return false
        }
        if let updatedBefore, node.updatedAt > updatedBefore {
            return false
        }
        return true
    }

    private func insertNewestNode(
        _ node: GraphNodeRecord,
        into results: inout [GraphNodeRecord],
        limit: Int
    ) {
        guard limit > 0 else { return }
        if results.count == limit, let last = results.last, node.createdAt <= last.createdAt {
            return
        }

        var insertionIndex = results.count
        while insertionIndex > 0, results[insertionIndex - 1].createdAt < node.createdAt {
            insertionIndex -= 1
        }

        results.insert(node, at: insertionIndex)
        if results.count > limit {
            results.removeLast()
        }
    }

    private func executeEdgeFilter(_ filter: EdgeFilter) -> QueryResult {
        guard filter.limit > 0 else { return .empty }

        let scopedNodeID = filter.involvingNodeRef.flatMap(resolveNodeRef)
        if filter.involvingNodeRef != nil, scopedNodeID == nil {
            return .empty
        }

        var results: [GraphEdgeRecord] = []
        results.reserveCapacity(min(filter.limit, graphStore.edgeCount))

        if let scopedNodeID {
            appendMatchingEdges(
                from: graphStore.edges(for: scopedNodeID),
                into: &results,
                types: filter.types,
                involvingNodeID: scopedNodeID,
                limit: filter.limit
            )
        } else {
            appendMatchingEdges(
                from: graphStore.edges.values,
                into: &results,
                types: filter.types,
                involvingNodeID: nil,
                limit: filter.limit
            )
        }

        let edgeResults = results.map { edge -> QueryResultEdge in
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

    private func appendMatchingEdges<S: Sequence>(
        from candidates: S,
        into results: inout [GraphEdgeRecord],
        types: [GraphEdgeType]?,
        involvingNodeID: String?,
        limit: Int
    ) where S.Element == GraphEdgeRecord {
        for edge in candidates {
            guard edgeMatchesFilter(edge, types: types, involvingNodeID: involvingNodeID) else { continue }
            insertNewestEdge(edge, into: &results, limit: limit)
        }
    }

    private func edgeMatchesFilter(
        _ edge: GraphEdgeRecord,
        types: [GraphEdgeType]?,
        involvingNodeID: String?
    ) -> Bool {
        if let types, !types.contains(edge.type) {
            return false
        }
        if let involvingNodeID,
           edge.sourceNodeId != involvingNodeID,
           edge.targetNodeId != involvingNodeID {
            return false
        }
        return true
    }

    private func insertNewestEdge(
        _ edge: GraphEdgeRecord,
        into results: inout [GraphEdgeRecord],
        limit: Int
    ) {
        guard limit > 0 else { return }
        if results.count == limit, let last = results.last, edge.createdAt <= last.createdAt {
            return
        }

        var insertionIndex = results.count
        while insertionIndex > 0, results[insertionIndex - 1].createdAt < edge.createdAt {
            insertionIndex -= 1
        }

        results.insert(edge, at: insertionIndex)
        if results.count > limit {
            results.removeLast()
        }
    }

    private func executePath(from: NodeRef, to: NodeRef, maxHops: Int) -> QueryResult {
        guard let fromId = resolveNodeRef(from),
              let toId = resolveNodeRef(to) else { return .empty }
        let path = graphStore.query(.pathBetween(from: fromId, to: toId, maxHops: maxHops))
        let nodes = path.map { makeQueryResultNode(from: $0, in: graphStore) }
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
            let nodes = unique.map { makeQueryResultNode(from: $0, in: graphStore) }
            return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
        } else {
            let connectedIds = graphStore.connected(to: nodeId, maxDepth: depth)
            let nodes = connectedIds
                .compactMap { graphStore.nodes[$0] }
                .filter { $0.id != nodeId }
                .map { makeQueryResultNode(from: $0, in: graphStore) }
            return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
        }
    }

    private func executeFTS(query: String, scope: SearchScope) -> QueryResult {
        QueryResult(
            nodes: retrieval.fullText(query: query, scope: scope),
            edges: [],
            aggregation: nil,
            executionTimeMs: 0
        )
    }

    private func executeSemantic(query: String, limit: Int) -> QueryResult {
        QueryResult(
            nodes: retrieval.semantic(query: query, limit: limit),
            edges: [],
            aggregation: nil,
            executionTimeMs: 0
        )
    }

    private func executeBTKPropertyFilter(key: String, op: CompOp, value: PropertyValue) -> QueryResult {
        guard let engine = graphState.engineHandle else { return .empty }

        let opCode = op.ffiCode
        let (valType, valStr) = value.ffiEncoded

        let buffer = key.withCString { keyPtr in
            valStr.withCString { valPtr in
                graph_engine_btk_query_property(engine, keyPtr, opCode, valType, valPtr)
            }
        }
        return pageIdsToQueryResult(buffer)
    }

    private func executeBTKDepthFilter(op: CompOp, value: Int) -> QueryResult {
        guard let engine = graphState.engineHandle else { return .empty }

        let buffer = graph_engine_btk_query_depth(engine, op.ffiCode, UInt32(max(0, value)))
        return pageIdsToQueryResult(buffer)
    }

    private func pageIdsToQueryResult(_ buffer: GraphEngineByteBuffer) -> QueryResult {
        let pageIds = BTKQueryPageIDBufferDecoder.decode(buffer)
        let nodes = pageIds.compactMap { pageId -> QueryResultNode? in
            guard let node = graphStore.node(bySourceId: pageId, type: .note) else { return nil }
            return makeQueryResultNode(from: node, in: graphStore)
        }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func executeLabelFilter(_ text: String) -> QueryResult {
        let matches = graphStore.nodes(matchingLabelContains: text)
        let nodes = matches.map { makeQueryResultNode(from: $0, in: graphStore) }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func resolveNodeRef(_ ref: NodeRef) -> String? {
        switch ref {
        case .id(let id): return graphStore.nodes[id] != nil ? id : nil
        case .label(let label): return graphStore.fuzzySearch(query: label, limit: 1).first?.id
        case .type(let type): return graphStore.firstNode(ofType: type)?.id
        }
    }
}
