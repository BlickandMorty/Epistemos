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
        connectionCount: currentProductProjectionLinkCount(for: record, in: graphStore)
    )
}

@MainActor
private func currentProductProjectionLinkCount(
    for record: GraphNodeRecord,
    in graphStore: GraphStore
) -> UInt32 {
    guard ProductCapabilityPolicy.allowsGraphProjection(of: record) else { return 0 }
    return UInt32(graphStore.edges(for: record.id).reduce(into: 0) { count, edge in
        guard let source = graphStore.nodes[edge.sourceNodeId],
              let target = graphStore.nodes[edge.targetNodeId],
              ProductCapabilityPolicy.allowsGraphProjection(of: source),
              ProductCapabilityPolicy.allowsGraphProjection(of: target)
        else {
            return
        }
        count += 1
    })
}

nonisolated enum BTKQueryPageIDBufferDecoder {
    static func decode(_ buffer: GraphEngineByteBuffer) -> [String] {
        guard let ptr = buffer.ptr, buffer.len > 0 else {
            if buffer.capacity > 0 {
                graph_engine_free_bytes(buffer)
                return recordDecodeFailure(
                    "BTK query returned an allocated buffer without payload bytes",
                    metadata: [
                        "length": "\(buffer.len)",
                        "capacity": "\(buffer.capacity)",
                    ]
                )
            }
            return []
        }

        defer { graph_engine_free_bytes(buffer) }
        let bytes = UnsafeRawBufferPointer(start: ptr, count: Int(buffer.len))
        return decode(bytes)
    }

    static func decode(_ bytes: UnsafeRawBufferPointer) -> [String] {
        guard let count = readUInt32(bytes, offset: 0) else {
            return recordDecodeFailure(
                "BTK query payload was missing the page count header",
                metadata: ["byteCount": "\(bytes.count)"]
            )
        }

        var offset = 4
        var pageIDs: [String] = []
        pageIDs.reserveCapacity(Int(count))

        for _ in 0..<count {
            guard let length = readUInt32(bytes, offset: offset) else {
                return recordDecodeFailure(
                    "BTK query payload was truncated while reading page ID length",
                    metadata: [
                        "byteCount": "\(bytes.count)",
                        "offset": "\(offset)",
                    ]
                )
            }
            offset += 4
            let byteCount = Int(length)
            guard byteCount >= 0, offset + byteCount <= bytes.count else {
                return recordDecodeFailure(
                    "BTK query payload declared an out-of-bounds page ID",
                    metadata: [
                        "byteCount": "\(bytes.count)",
                        "offset": "\(offset)",
                        "declaredLength": "\(byteCount)",
                    ]
                )
            }
            let slice = bytes[offset..<(offset + byteCount)]
            pageIDs.append(String(decoding: slice, as: UTF8.self))
            offset += byteCount
        }

        guard offset == bytes.count else {
            return recordDecodeFailure(
                "BTK query payload had trailing bytes after decoding page IDs",
                metadata: [
                    "byteCount": "\(bytes.count)",
                    "offset": "\(offset)",
                ]
            )
        }
        return pageIDs
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

    private static func recordDecodeFailure(
        _ message: String,
        metadata: [String: String]
    ) -> [String] {
        Log.ffiBoundary.error("\(message, privacy: .public)")
        RuntimeDiagnostics.record(
            .error,
            category: "FFIBoundary",
            message: message,
            metadata: metadata
        )
        return []
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

typealias GraphEventProjectionSnapshotProvider = @MainActor () -> DurableGraphProjectionSnapshot

nonisolated enum GraphEventProjectionHint {
    static let emptySnapshot = DurableGraphProjectionSnapshot(
        nodes: [],
        edges: [],
        eventCount: 0,
        latestEventID: nil
    )

    static func apply(
        to candidates: [RetrievalCandidate],
        snapshot: DurableGraphProjectionSnapshot
    ) -> [RetrievalCandidate] {
        guard candidates.count > 1, snapshot.eventCount > 0 else { return candidates }

        var projectedIDs = Set<String>()
        projectedIDs.reserveCapacity(snapshot.nodes.count + (snapshot.edges.count * 2))
        for node in snapshot.nodes {
            projectedIDs.insert(node.id)
        }
        for edge in snapshot.edges {
            projectedIDs.insert(edge.fromID)
            projectedIDs.insert(edge.toID)
        }
        guard !projectedIDs.isEmpty else { return candidates }

        var reordered: [RetrievalCandidate] = []
        reordered.reserveCapacity(candidates.count)
        var index = 0
        while index < candidates.count {
            let score = candidates[index].node.score
            var end = index + 1
            while end < candidates.count, candidates[end].node.score == score {
                end += 1
            }

            let group = candidates[index..<end]
            reordered.append(
                contentsOf: group.enumerated().sorted { lhs, rhs in
                    let lhsHinted = isHinted(lhs.element, projectedIDs: projectedIDs)
                    let rhsHinted = isHinted(rhs.element, projectedIDs: projectedIDs)
                    if lhsHinted == rhsHinted {
                        return lhs.offset < rhs.offset
                    }
                    return lhsHinted && !rhsHinted
                }.map(\.element)
            )
            index = end
        }
        return reordered
    }

    private static func isHinted(
        _ candidate: RetrievalCandidate,
        projectedIDs: Set<String>
    ) -> Bool {
        projectedIDs.contains(candidate.node.id)
            || candidate.node.sourceId.map(projectedIDs.contains) == true
    }
}

@MainActor
protocol RetrievalScoring {
    func score(query: String, candidates: [RetrievalCandidate]) -> [RetrievalCandidate]
}

struct PassthroughRetrievalScorer: RetrievalScoring {
    func score(query: String, candidates: [RetrievalCandidate]) -> [RetrievalCandidate] {
        candidates
    }
}

@MainActor
protocol PreparedRetrievalRuntimeResolving {
    func resolveScorer(
        configuration: PreparedRetrievalRuntimeConfiguration?,
        executionMode: PreparedRetrievalExecutionMode,
        graphState: GraphState
    ) -> any RetrievalScoring

    func resolveEmbeddingLookup(
        configuration: PreparedRetrievalRuntimeConfiguration?,
        executionMode: PreparedRetrievalExecutionMode,
        fallback: any TextEmbeddingLookup
    ) -> any TextEmbeddingLookup
}

struct DefaultPreparedRetrievalRuntimeResolver: PreparedRetrievalRuntimeResolving {
    func resolveScorer(
        configuration: PreparedRetrievalRuntimeConfiguration?,
        executionMode: PreparedRetrievalExecutionMode,
        graphState: GraphState
    ) -> any RetrievalScoring {
        guard executionMode.hasPreparedIndexRuntime else {
            return PassthroughRetrievalScorer()
        }
        return PreparedIndexSimilarityScorer(
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
final class PreparedIndexSimilarityScorer: RetrievalScoring {
    private weak var graphState: GraphState?
    private let embeddingService: EmbeddingService

    init(graphState: GraphState, embeddingService: EmbeddingService) {
        self.graphState = graphState
        self.embeddingService = embeddingService
    }

    func score(query: String, candidates: [RetrievalCandidate]) -> [RetrievalCandidate] {
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
        static let scoreLimit = 12
    }

    private static let graphEventProjectionEnvironmentKey = "EPISTEMOS_GRAPH_EVENT_QUERY_PROJECTION_V1"

    private let graphStore: GraphStore
    private let graphState: GraphState
    private let searchIndex: SearchIndexService
    private let scorer: any RetrievalScoring
    private let scoreLimit: Int
    private let graphEventProjectionSnapshotProvider: GraphEventProjectionSnapshotProvider

    init(
        graphStore: GraphStore,
        graphState: GraphState,
        searchIndex: SearchIndexService,
        scorer: any RetrievalScoring = PassthroughRetrievalScorer(),
        scoreLimit: Int = RetrievalPolicy.scoreLimit,
        graphEventProjectionSnapshotProvider: GraphEventProjectionSnapshotProvider? = nil
    ) {
        self.graphStore = graphStore
        self.graphState = graphState
        self.searchIndex = searchIndex
        self.scorer = scorer
        self.scoreLimit = max(0, scoreLimit)
        self.graphEventProjectionSnapshotProvider = graphEventProjectionSnapshotProvider
            ?? Self.defaultGraphEventProjectionSnapshot
    }

    func fullText(query: String, scope: SearchScope, limit: Int = 50) -> [QueryResultNode] {
        guard let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit) else { return [] }
        guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query) else { return [] }
        var seen = Set<String>()
        var candidates: [RetrievalCandidate] = []

        // RRF Fusion Phase 4 wiring site §3 — Epdoc Slash menu / @-mention
        // block-link autocomplete. When the env flag is set AND the caller
        // wants `.all` (mixed page+block scope), one fused SQL query
        // replaces the two per-index dispatches below. Per-index calls
        // remain the legacy fallback path on flag-off and on fused-path
        // failure.
        if RRFFusionFlags.isEnabled && scope == .all {
            do {
                let fused = try searchIndex.fusedSearch(
                    query: checkedQuery,
                    weights: FusionWeights(maxResults: checkedLimit)
                )
                for result in fused {
                    let resolvedSource: RetrievalCandidateSource =
                        (result.entityKind == "block") ? .blockSearch : .pageSearch
                    appendNoteResult(
                        pageId: result.parentDocID,
                        score: Float(result.fusedScore),
                        snippet: result.snippet ?? "",
                        source: resolvedSource,
                        seen: &seen,
                        candidates: &candidates
                    )
                }
                return graphEventHintedCandidates(
                    scoredCandidates(query: checkedQuery, candidates: candidates)
                ).map(\.node)
            } catch {
                Log.ffiBoundary.error(
                    "QueryRuntime: fused note search failed; falling back to bounded per-index search."
                )
                // Fall through to legacy path below.
            }
        }

        if scope != .blocks {
            do {
                let results = try searchIndex.search(query: checkedQuery, limit: checkedLimit)
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
            } catch {
                Log.ffiBoundary.error(
                    "QueryRuntime: note index search failed."
                )
            }
        }

        if scope == .blocks || scope == .all {
            do {
                let blockResults = try searchIndex.searchBlocks(query: checkedQuery, limit: checkedLimit)
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
            } catch {
                Log.ffiBoundary.error(
                    "QueryRuntime: block index search failed."
                )
            }
        }

        return graphEventHintedCandidates(
            scoredCandidates(query: checkedQuery, candidates: candidates)
        ).map(\.node)
    }

    func semantic(query: String, limit: Int) -> [QueryResultNode] {
        guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query) else { return [] }
        guard let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit) else { return [] }
        let candidates = graphState.semanticSearch(query: checkedQuery, limit: checkedLimit).map {
            RetrievalCandidate(
                node: makeQueryResultNode(from: $0.node, in: graphStore, score: $0.score),
                source: .semanticGraph
            )
        }
        return scoredCandidates(query: checkedQuery, candidates: candidates).map(\.node)
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

    private func scoredCandidates(
        query: String,
        candidates: [RetrievalCandidate]
    ) -> [RetrievalCandidate] {
        guard candidates.count > 1, scoreLimit > 0 else { return candidates }
        let prefixCount = min(scoreLimit, candidates.count)
        let prefix = Array(candidates.prefix(prefixCount))
        let scoredPrefix = scorer.score(query: query, candidates: prefix)
        guard scoredPrefix.count == prefix.count,
              Set(scoredPrefix.map(\.node.id)) == Set(prefix.map(\.node.id)) else {
            return candidates
        }
        return scoredPrefix + candidates.dropFirst(prefixCount)
    }

    private func graphEventHintedCandidates(_ candidates: [RetrievalCandidate]) -> [RetrievalCandidate] {
        guard candidates.count > 1 else { return candidates }
        return GraphEventProjectionHint.apply(
            to: candidates,
            snapshot: graphEventProjectionSnapshotProvider()
        )
    }

    private static func defaultGraphEventProjectionSnapshot() -> DurableGraphProjectionSnapshot {
        guard ProcessInfo.processInfo.environment[graphEventProjectionEnvironmentKey] == "1" else {
            return GraphEventProjectionHint.emptySnapshot
        }
        return EventStore.shared?.graphEventProjectionSnapshot(limit: 100)
            ?? GraphEventProjectionHint.emptySnapshot
    }
}

// MARK: - QueryExecutor

/// Swappable query-execution seam — Slice 0 of the knowledge-core cutover
/// (docs/plans/KNOWLEDGE_CORE_SHADOW_TO_PRODUCTION_CUTOVER_PLAN_2026_06_13.md).
///
/// `QueryRuntime` is the only conformer today; a knowledge-core-backed
/// executor is introduced in a later slice behind a default-OFF flag. This is
/// behavior-preserving for execution: every existing caller passes a
/// `QueryRuntime`. Executors also identify their concrete Search source so
/// reactive consumers can reject delayed events from a retired vault.
@MainActor
protocol QueryExecutor: AnyObject {
    func execute(_ plan: QueryPlan) -> QueryResult
    func matchesSearchNotificationSource(_ source: SearchIndexService) -> Bool
}

extension QueryRuntime: QueryExecutor {}

// MARK: - QueryRuntime
// Executes QueryPlan against the appropriate backends.

@MainActor
final class QueryRuntime {

    private let graphStore: GraphStore
    private let graphState: GraphState
    private let searchIndex: SearchIndexService
    private let retrieval: RetrievalRuntime

    init(
        graphStore: GraphStore,
        graphState: GraphState,
        searchIndex: SearchIndexService,
        scorer: any RetrievalScoring = PassthroughRetrievalScorer(),
        graphEventProjectionSnapshotProvider: GraphEventProjectionSnapshotProvider? = nil
    ) {
        self.graphStore = graphStore
        self.graphState = graphState
        self.searchIndex = searchIndex
        retrieval = RetrievalRuntime(
            graphStore: graphStore,
            graphState: graphState,
            searchIndex: searchIndex,
            scorer: scorer,
            graphEventProjectionSnapshotProvider: graphEventProjectionSnapshotProvider
        )
    }

    func matchesSearchNotificationSource(_ source: SearchIndexService) -> Bool {
        searchIndex === source
    }

    func execute(_ plan: QueryPlan) -> QueryResult {
        let start = CACurrentMediaTime()

        let raw: QueryResult
        if plan.steps.count == 1 && plan.combiner == .single {
            raw = executeStep(plan.steps[0])
        } else {
            raw = executeCombined(plan)
        }

        // Sanitize before projection so a hidden record cannot affect paging,
        // ordering, graph traversal, or a caller's direct compiled plan.
        let sanitizedRaw = sanitizeForCurrentProduct(raw)

        // Apply projection (limit/offset/orderBy)
        var nodes = sanitizedRaw.nodes
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
            edges: sanitizedRaw.edges,
            aggregation: sanitizedRaw.aggregation,
            executionTimeMs: elapsed
        )
    }

    private func sanitizeForCurrentProduct(_ result: QueryResult) -> QueryResult {
        QueryResult(
            nodes: result.nodes.compactMap { resultNode in
                guard let record = graphStore.nodes[resultNode.id],
                      ProductCapabilityPolicy.allowsGraphProjection(of: record)
                else {
                    return nil
                }
                return makeQueryResultNode(
                    from: record,
                    in: graphStore,
                    score: resultNode.score,
                    snippet: resultNode.snippet
                )
            },
            // QueryResultEdge omits endpoint IDs. Every edge result is therefore
            // validated before its labels are constructed in executeEdgeFilter.
            edges: result.edges,
            // An aggregation without record identities cannot be proven to have
            // been derived from the allowed induced subgraph.
            aggregation: currentProductAggregation(from: result.aggregation),
            executionTimeMs: result.executionTimeMs
        )
    }

    private func currentProductAggregation(from aggregation: QueryAggregation?) -> QueryAggregation? {
        ProductCapabilityPolicy.currentEdition == .freeV1 ? nil : aggregation
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
        guard ProductCapabilityPolicy.allowsGraphProjection(of: node) else {
            return false
        }
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

        let edgeResults = results.compactMap { edge -> QueryResultEdge? in
            guard let source = graphStore.nodes[edge.sourceNodeId],
                  let target = graphStore.nodes[edge.targetNodeId],
                  ProductCapabilityPolicy.allowsGraphProjection(of: source),
                  ProductCapabilityPolicy.allowsGraphProjection(of: target)
            else {
                return nil
            }
            return QueryResultEdge(
                id: edge.id,
                sourceLabel: source.label,
                targetLabel: target.label,
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
        guard let source = graphStore.nodes[edge.sourceNodeId],
              let target = graphStore.nodes[edge.targetNodeId],
              ProductCapabilityPolicy.allowsGraphProjection(of: source),
              ProductCapabilityPolicy.allowsGraphProjection(of: target)
        else {
            return false
        }
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

    private func allowedNeighborIDs(
        from nodeID: String,
        edgeTypes: Set<GraphEdgeType>?
    ) -> [String] {
        guard let source = graphStore.nodes[nodeID],
              ProductCapabilityPolicy.allowsGraphProjection(of: source)
        else {
            return []
        }

        var seen = Set<String>()
        return graphStore.edges(for: nodeID)
            .compactMap { edge -> String? in
                guard edgeTypes?.contains(edge.type) ?? true else { return nil }
                let otherID = edge.sourceNodeId == nodeID ? edge.targetNodeId : edge.sourceNodeId
                guard let other = graphStore.nodes[otherID],
                      ProductCapabilityPolicy.allowsGraphProjection(of: other),
                      seen.insert(otherID).inserted
                else {
                    return nil
                }
                return otherID
            }
    }

    private func allowedReachableNodeIDs(from nodeID: String, maxDepth: Int) -> [String] {
        guard maxDepth > 0,
              let source = graphStore.nodes[nodeID],
              ProductCapabilityPolicy.allowsGraphProjection(of: source)
        else {
            return []
        }

        var visited: Set<String> = [nodeID]
        var queue: [(id: String, depth: Int)] = [(nodeID, 0)]
        var queueIndex = 0
        var result: [String] = []

        while queueIndex < queue.count {
            let current = queue[queueIndex]
            queueIndex += 1
            guard current.depth < maxDepth else { continue }

            for neighborID in allowedNeighborIDs(from: current.id, edgeTypes: nil)
            where visited.insert(neighborID).inserted {
                result.append(neighborID)
                queue.append((neighborID, current.depth + 1))
            }
        }
        return result
    }

    private func allowedPath(from startID: String, to endID: String, maxHops: Int) -> [GraphNodeRecord] {
        guard maxHops >= 0,
              let start = graphStore.nodes[startID],
              let end = graphStore.nodes[endID],
              ProductCapabilityPolicy.allowsGraphProjection(of: start),
              ProductCapabilityPolicy.allowsGraphProjection(of: end)
        else {
            return []
        }
        if startID == endID { return [start] }

        var visited: Set<String> = [startID]
        var parent: [String: String] = [:]
        var queue: [(id: String, depth: Int)] = [(startID, 0)]
        var queueIndex = 0

        while queueIndex < queue.count {
            let current = queue[queueIndex]
            queueIndex += 1
            guard current.depth < maxHops else { continue }

            for neighborID in allowedNeighborIDs(from: current.id, edgeTypes: nil)
            where visited.insert(neighborID).inserted {
                parent[neighborID] = current.id
                if neighborID == endID {
                    var pathIDs = [endID]
                    while let previous = parent[pathIDs.last!] {
                        pathIDs.append(previous)
                    }
                    return pathIDs.reversed().compactMap { graphStore.nodes[$0] }
                }
                queue.append((neighborID, current.depth + 1))
            }
        }
        return []
    }

    private func executePath(from: NodeRef, to: NodeRef, maxHops: Int) -> QueryResult {
        guard let fromId = resolveNodeRef(from),
              let toId = resolveNodeRef(to) else { return .empty }
        let path = allowedPath(from: fromId, to: toId, maxHops: maxHops)
        let nodes = path.map { makeQueryResultNode(from: $0, in: graphStore) }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func executeNeighbors(of nodeRef: NodeRef, edgeTypes: [GraphEdgeType]?, depth: Int) -> QueryResult {
        guard let nodeId = resolveNodeRef(nodeRef) else { return .empty }
        if let edgeTypes {
            let permittedTypes = Set(edgeTypes)
            let nodes = allowedNeighborIDs(from: nodeId, edgeTypes: permittedTypes)
                .compactMap { graphStore.nodes[$0] }
                .map { makeQueryResultNode(from: $0, in: graphStore) }
            return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
        } else {
            let nodes = allowedReachableNodeIDs(from: nodeId, maxDepth: depth)
                .compactMap { graphStore.nodes[$0] }
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
        guard let engine = graphState.engineHandle else {
            Log.ffiBoundary.debug("BTK property query skipped because the graph engine handle is unavailable")
            return .empty
        }

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
        guard let engine = graphState.engineHandle else {
            Log.ffiBoundary.debug("BTK depth query skipped because the graph engine handle is unavailable")
            return .empty
        }

        let buffer = graph_engine_btk_query_depth(engine, op.ffiCode, UInt32(max(0, value)))
        return pageIdsToQueryResult(buffer)
    }

    private func pageIdsToQueryResult(_ buffer: GraphEngineByteBuffer) -> QueryResult {
        let pageIds = BTKQueryPageIDBufferDecoder.decode(buffer)
        let nodes = pageIds.compactMap { pageId -> QueryResultNode? in
            guard let node = graphStore.node(bySourceId: pageId, type: .note),
                  ProductCapabilityPolicy.allowsGraphProjection(of: node)
            else {
                return nil
            }
            return makeQueryResultNode(from: node, in: graphStore)
        }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func executeLabelFilter(_ text: String) -> QueryResult {
        let matches = graphStore.nodes(matchingLabelContains: text)
            .filter(ProductCapabilityPolicy.allowsGraphProjection(of:))
        let nodes = matches.map { makeQueryResultNode(from: $0, in: graphStore) }
        return QueryResult(nodes: nodes, edges: [], aggregation: nil, executionTimeMs: 0)
    }

    private func resolveNodeRef(_ ref: NodeRef) -> String? {
        switch ref {
        case .id(let id):
            guard let node = graphStore.nodes[id],
                  ProductCapabilityPolicy.allowsGraphProjection(of: node)
            else {
                return nil
            }
            return id
        case .label(let label):
            return graphStore.fuzzySearchForCurrentProductProjection(
                query: label,
                limit: 1
            ).first?.id
        case .type(let type):
            guard ProductCapabilityPolicy.allowsGraphProjection(of: type) else {
                return nil
            }
            var match: String?
            graphStore.forEachNodeNewestFirst(ofTypes: [type]) { node in
                guard ProductCapabilityPolicy.allowsGraphProjection(of: node) else {
                    return true
                }
                match = node.id
                return false
            }
            return match
        }
    }
}
