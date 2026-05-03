import Foundation
import GRDB
import Metal
import QuartzCore
import Testing
@testable import Epistemos

@Suite("QueryRuntime", .serialized)
@MainActor
struct QueryRuntimeTests {
    private struct StubTextEmbeddingLookup: TextEmbeddingLookup {
        let vectors: [String: [Float]]
        let dimension: Int

        func vector(for token: String) -> [Float]? {
            vectors[token]
        }
    }

    @MainActor
    private struct StubPreparedRetrievalRuntimeResolver: PreparedRetrievalRuntimeResolving {
        let lookup: any TextEmbeddingLookup

        func resolveScorer(
            configuration: PreparedRetrievalRuntimeConfiguration?,
            executionMode: PreparedRetrievalExecutionMode,
            graphState: GraphState
        ) -> any RetrievalScoring {
            PassthroughRetrievalScorer()
        }

        func resolveEmbeddingLookup(
            configuration: PreparedRetrievalRuntimeConfiguration?,
            executionMode: PreparedRetrievalExecutionMode,
            fallback: any TextEmbeddingLookup
        ) -> any TextEmbeddingLookup {
            lookup
        }
    }

    @MainActor
    private final class ReversingScorer: RetrievalScoring {
        private(set) var receivedCandidateIDs: [String] = []

        func score(query: String, candidates: [RetrievalCandidate]) -> [RetrievalCandidate] {
            receivedCandidateIDs = candidates.map(\.node.id)
            return candidates.reversed()
        }
    }

    private func makeSearchIndex() throws -> SearchIndexService {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("query-runtime-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("search.sqlite")
        return try SearchIndexService(databaseURL: dbURL)
    }

    private func makeNoteNode(id: String, sourceId: String, label: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id,
            type: .note,
            label: label,
            sourceId: sourceId,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now
        )
    }

    private func makeProjectionNode(id: String) -> DurableGraphProjectionNode {
        DurableGraphProjectionNode(
            id: id,
            kind: "note",
            lastEventID: "event-\(id)",
            lastMutationID: "mutation-\(id)",
            lastEventKind: .nodeUpdated,
            lastOccurredAtMs: 1
        )
    }

    private func makeEdge(
        id: String,
        source: String,
        target: String,
        type: GraphEdgeType = .reference,
        createdAt: Date
    ) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: id,
            sourceNodeId: source,
            targetNodeId: target,
            type: type,
            weight: 1.0,
            createdAt: createdAt
        )
    }

    private func notification(
        name: Notification.Name,
        keys: Set<QueryDependencyKey>? = nil
    ) -> Notification {
        Notification(
            name: name,
            object: nil,
            userInfo: QueryDependencyKey.userInfo(for: keys)
        )
    }

    private func makeBTKQueryPageIDPayload(_ pageIDs: [String]) -> Data {
        var data = Data()
        data.reserveCapacity(4 + pageIDs.reduce(0) { $0 + 4 + $1.utf8.count })
        var count = UInt32(pageIDs.count).littleEndian
        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
        for pageID in pageIDs {
            var length = UInt32(pageID.utf8.count).littleEndian
            withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
            data.append(contentsOf: pageID.utf8)
        }
        return data
    }

    @Test("updated ordering uses updatedAt instead of createdAt")
    func updatedOrderingUsesUpdatedAt() throws {
        let store = GraphStore()
        let olderCreatedNewerUpdated = GraphNodeRecord(
            id: "alpha",
            type: .note,
            label: "Alpha",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 400)
        )
        let newerCreatedOlderUpdated = GraphNodeRecord(
            id: "beta",
            type: .note,
            label: "Beta",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: Date(timeIntervalSince1970: 300),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        store.addNode(olderCreatedNewerUpdated)
        store.addNode(newerCreatedOlderUpdated)

        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        #expect(store.nodeCount == 2)

        let basePlan = QueryPlan(
            steps: [.graphStoreFilter(NodeFilter(limit: 10))],
            combiner: .single
        )
        let descending = runtime.execute(QueryPlan(inner: basePlan, limit: nil, offset: nil, orderBy: .updated(ascending: false)))
        let ascending = runtime.execute(QueryPlan(inner: basePlan, limit: nil, offset: nil, orderBy: .updated(ascending: true)))

        #expect(descending.nodes.map(\.id) == ["alpha", "beta"])
        #expect(ascending.nodes.map(\.id) == ["beta", "alpha"])
    }

    @Test("connection ordering uses stored link counts")
    func connectionOrderingUsesStoredLinkCounts() throws {
        let store = GraphStore()
        store.addNode(
            GraphNodeRecord(
                id: "alpha",
                type: .note,
                label: "Alpha",
                sourceId: "page-alpha",
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: Date(timeIntervalSince1970: 400)
            )
        )
        store.addNode(
            GraphNodeRecord(
                id: "beta",
                type: .note,
                label: "Beta",
                sourceId: "page-beta",
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: Date(timeIntervalSince1970: 300)
            )
        )
        store.addNode(
            GraphNodeRecord(
                id: "gamma",
                type: .note,
                label: "Gamma",
                sourceId: "page-gamma",
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )
        store.addNode(
            GraphNodeRecord(
                id: "delta",
                type: .note,
                label: "Delta",
                sourceId: "page-delta",
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )

        store.addEdge(
            makeEdge(
                id: "alpha-beta",
                source: "alpha",
                target: "beta",
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )
        store.addEdge(
            makeEdge(
                id: "alpha-gamma",
                source: "alpha",
                target: "gamma",
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )
        store.addEdge(
            makeEdge(
                id: "beta-gamma",
                source: "beta",
                target: "gamma",
                createdAt: Date(timeIntervalSince1970: 300)
            )
        )

        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let basePlan = QueryPlan(
            steps: [.graphStoreFilter(NodeFilter(limit: 10))],
            combiner: .single
        )
        let ordered = runtime.execute(
            QueryPlan(inner: basePlan, limit: nil, offset: nil, orderBy: .connections)
        )

        #expect(ordered.nodes.map(\.id) == ["alpha", "beta", "gamma", "delta"])
        #expect(ordered.nodes.map(\.connectionCount) == [2, 2, 2, 0])
    }

    @Test("edge filter keeps only the newest limited edges without materializing the full edge set")
    func edgeFilterKeepsNewestLimitedEdges() throws {
        let store = GraphStore()
        store.addNode(makeNoteNode(id: "alpha", sourceId: "page-alpha", label: "Alpha"))
        store.addNode(makeNoteNode(id: "beta", sourceId: "page-beta", label: "Beta"))
        store.addNode(makeNoteNode(id: "gamma", sourceId: "page-gamma", label: "Gamma"))

        store.addEdge(
            makeEdge(
                id: "older-edge",
                source: "alpha",
                target: "beta",
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )
        store.addEdge(
            makeEdge(
                id: "newer-edge",
                source: "beta",
                target: "gamma",
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )

        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let result = runtime.execute(
            QueryPlan(
                steps: [.graphStoreEdgeFilter(EdgeFilter(limit: 1))],
                combiner: .single
            )
        )

        #expect(result.edges.map(\.id) == ["newer-edge"])
    }

    @Test("edge filter honors involving-node scoping through the graph edge index")
    func edgeFilterHonorsInvolvingNodeScope() throws {
        let store = GraphStore()
        store.addNode(makeNoteNode(id: "alpha", sourceId: "page-alpha", label: "Alpha"))
        store.addNode(makeNoteNode(id: "beta", sourceId: "page-beta", label: "Beta"))
        store.addNode(makeNoteNode(id: "gamma", sourceId: "page-gamma", label: "Gamma"))

        store.addEdge(
            makeEdge(
                id: "alpha-beta",
                source: "alpha",
                target: "beta",
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )
        store.addEdge(
            makeEdge(
                id: "beta-gamma",
                source: "beta",
                target: "gamma",
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )

        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let result = runtime.execute(
            QueryPlan(
                steps: [
                    .graphStoreEdgeFilter(
                        EdgeFilter(
                            types: nil,
                            involvingNodeRef: .id("alpha"),
                            limit: 10
                        )
                    )
                ],
                combiner: .single
            )
        )

        #expect(result.edges.map(\.id) == ["alpha-beta"])
    }

    @Test("BTK query page-id decoder reads length-prefixed payloads")
    func btkQueryPageIDDecoderReadsLengthPrefixedPayloads() {
        let payload = makeBTKQueryPageIDPayload(["page-1", "page-2", "vault/page-3"])
        let pageIDs = payload.withUnsafeBytes { bytes in
            BTKQueryPageIDBufferDecoder.decode(bytes)
        }

        #expect(pageIDs == ["page-1", "page-2", "vault/page-3"])
    }

    @Test("BTK query page-id decoder rejects truncated payloads")
    func btkQueryPageIDDecoderRejectsTruncatedPayloads() {
        var payload = makeBTKQueryPageIDPayload(["page-1", "page-2"])
        payload.removeLast()

        let pageIDs = payload.withUnsafeBytes { bytes in
            BTKQueryPageIDBufferDecoder.decode(bytes)
        }

        #expect(pageIDs.isEmpty)
    }

    @Test("label filter preserves case-insensitive substring semantics")
    func labelFilterPreservesCaseInsensitiveSubstringSemantics() throws {
        let store = GraphStore()
        store.addNode(makeNoteNode(id: "alpha", sourceId: "page-alpha", label: "Alpha Graph"))
        store.addNode(makeNoteNode(id: "beta", sourceId: "page-beta", label: "Beta"))

        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let result = runtime.execute(
            QueryPlan(
                steps: [.inMemoryLabelFilter("gRaPh")],
                combiner: .single
            )
        )

        #expect(result.nodes.map(\.id) == ["alpha"])
    }

    @Test("neighbors can resolve a type node ref without scanning all graph nodes")
    func neighborsResolveTypeNodeRef() throws {
        let store = GraphStore()
        store.addNode(makeNoteNode(id: "alpha", sourceId: "page-alpha", label: "Alpha"))
        store.addNode(
            GraphNodeRecord(
                id: "tag-1",
                type: .tag,
                label: "Tag",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now
            )
        )
        store.addEdge(
            makeEdge(
                id: "alpha-tag",
                source: "alpha",
                target: "tag-1",
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )

        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let result = runtime.execute(
            QueryPlan(
                steps: [.graphStoreNeighbors(of: .type(.note), edgeTypes: nil, depth: 1)],
                combiner: .single
            )
        )

        #expect(result.nodes.map(\.id) == ["tag-1"])
    }

    @Test("node filter preserves multi-type semantics through the direct type index")
    func nodeFilterPreservesMultiTypeSemantics() throws {
        let store = GraphStore()
        store.addNode(makeNoteNode(id: "alpha", sourceId: "page-alpha", label: "Alpha"))
        store.addNode(
            GraphNodeRecord(
                id: "tag-1",
                type: .tag,
                label: "Tag",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now
            )
        )
        store.addNode(
            GraphNodeRecord(
                id: "folder-1",
                type: .folder,
                label: "Folder",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now
            )
        )

        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let result = runtime.execute(
            QueryPlan(
                steps: [
                    .graphStoreFilter(
                        NodeFilter(types: [.note, .tag], limit: 10)
                    )
                ],
                combiner: .single
            )
        )

        #expect(Set(result.nodes.map(\.id)) == ["alpha", "tag-1"])
    }

    @Test("reactive query invalidation stays within a single debounce window")
    func reactiveQueryInvalidationLatency() async throws {
        let store = GraphStore()
        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let plan = QueryPlan(
            steps: [.graphStoreFilter(NodeFilter(limit: 10))],
            combiner: .single
        )
        let reactive = ReactiveQuery(runtime: runtime, plan: plan)
        var iterator = reactive.stream().makeAsyncIterator()

        let initial = await iterator.next()
        #expect(initial?.nodes.isEmpty == true)

        let clock = ContinuousClock()
        let start = clock.now
        store.addNode(
            GraphNodeRecord(
                id: "gamma",
                type: .note,
                label: "Gamma",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now
            )
        )

        let updated = await iterator.next()
        let elapsed = clock.now - start

        #expect(updated?.nodes.map(\.id) == ["gamma"])
        #expect(
            elapsed < .milliseconds(120),
            "Reactive query update took \(elapsed), expected to stay within a bounded debounce window"
        )
    }

    @Test("reactive query ignores irrelevant graph dependency notifications")
    func reactiveQueryIgnoresIrrelevantGraphNotifications() throws {
        let runtime = try QueryRuntime(
            graphStore: GraphStore(),
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let plan = QueryPlan(
            steps: [.graphStoreFilter(NodeFilter(limit: 10))],
            combiner: .single
        )
        let reactive = ReactiveQuery(runtime: runtime, plan: plan)

        #expect(
            reactive.shouldInvalidate(for: notification(name: .graphStoreDidChange, keys: [.graphNodes]))
        )
        #expect(
            !reactive.shouldInvalidate(for: notification(name: .graphStoreDidChange, keys: [.graphEdges]))
        )
    }

    @Test("reactive query scopes search invalidation by index domain")
    func reactiveQueryScopesSearchInvalidationByIndexDomain() throws {
        let runtime = try QueryRuntime(
            graphStore: GraphStore(),
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let pageReactive = ReactiveQuery(
            runtime: runtime,
            plan: QueryPlan(
                steps: [.fts5Search(query: "graph", scope: .pages)],
                combiner: .single
            )
        )
        let blockReactive = ReactiveQuery(
            runtime: runtime,
            plan: QueryPlan(
                steps: [.fts5Search(query: "graph", scope: .blocks)],
                combiner: .single
            )
        )
        let allReactive = ReactiveQuery(
            runtime: runtime,
            plan: QueryPlan(
                steps: [.fts5Search(query: "graph", scope: .all)],
                combiner: .single
            )
        )

        #expect(
            pageReactive.shouldInvalidate(for: notification(name: .searchIndexDidUpdate, keys: [.searchPages]))
        )
        #expect(
            !pageReactive.shouldInvalidate(for: notification(name: .searchIndexDidUpdate, keys: [.searchBlocks]))
        )
        #expect(
            !pageReactive.shouldInvalidate(for: notification(name: .searchIndexDidUpdate, keys: [.searchReadable]))
        )
        #expect(
            blockReactive.shouldInvalidate(for: notification(name: .searchIndexDidUpdate, keys: [.searchBlocks]))
        )
        #expect(
            !blockReactive.shouldInvalidate(for: notification(name: .searchIndexDidUpdate, keys: [.searchReadable]))
        )
        #expect(
            allReactive.shouldInvalidate(for: notification(name: .searchIndexDidUpdate, keys: [.searchReadable]))
        )
    }

    @Test("reactive query conservatively invalidates unscoped notifications")
    func reactiveQueryConservativeFallback() throws {
        let runtime = try QueryRuntime(
            graphStore: GraphStore(),
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )
        let reactive = ReactiveQuery(
            runtime: runtime,
            plan: QueryPlan(
                steps: [.fts5Search(query: "graph", scope: .pages)],
                combiner: .single
            )
        )

        #expect(reactive.shouldInvalidate(for: Notification(name: .searchIndexDidUpdate)))
    }

    @Test("reactive query keeps the newest stream alive when replacing subscribers")
    func reactiveQueryStreamReplacementPreservesNewestSubscriber() async throws {
        let store = GraphStore()
        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let reactive = ReactiveQuery(
            runtime: runtime,
            plan: QueryPlan(
                steps: [.graphStoreFilter(NodeFilter(limit: 10))],
                combiner: .single
            )
        )

        var firstIterator: AsyncStream<QueryResult>.Iterator? = reactive.stream().makeAsyncIterator()
        let firstInitial = await firstIterator?.next()
        #expect(firstInitial?.nodes.isEmpty == true)

        var secondIterator = reactive.stream().makeAsyncIterator()
        let secondInitial = await secondIterator.next()
        #expect(secondInitial?.nodes.isEmpty == true)

        // Allow the first stream's termination cleanup to run before the next invalidation.
        try? await Task.sleep(for: .milliseconds(20))
        firstIterator = nil

        store.addNode(
            GraphNodeRecord(
                id: "delta",
                type: .note,
                label: "Delta",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now
            )
        )

        let updated = await secondIterator.next()
        #expect(updated?.nodes.map(\.id) == ["delta"])
    }

    @Test("reactive query buffers only the newest pending result")
    func reactiveQueryBuffersNewestPendingResult() async throws {
        let store = GraphStore()
        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let reactive = ReactiveQuery(
            runtime: runtime,
            plan: QueryPlan(
                steps: [.graphStoreFilter(NodeFilter(limit: 10))],
                combiner: .single
            )
        )

        var iterator = reactive.stream().makeAsyncIterator()
        let initial = await iterator.next()
        #expect(initial?.nodes.isEmpty == true)

        store.addNode(
            GraphNodeRecord(
                id: "alpha",
                type: .note,
                label: "Alpha",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now
            )
        )
        try? await Task.sleep(for: .milliseconds(80))

        store.addNode(
            GraphNodeRecord(
                id: "beta",
                type: .note,
                label: "Beta",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now
            )
        )
        try? await Task.sleep(for: .milliseconds(80))

        let latest = await iterator.next()
        #expect(Set(latest?.nodes.map(\.id) ?? []) == ["alpha", "beta"])
    }

    @Test("retrieval runtime de-duplicates page and block hits for the same note")
    func retrievalRuntimeDeduplicatesPageAndBlockHitsForSameNote() throws {
        let store = GraphStore()
        let graphState = GraphState()
        let searchIndex = try makeSearchIndex()

        store.addNode(makeNoteNode(id: "note-1", sourceId: "page-1", label: "Alpha"))
        try searchIndex.upsert(
            id: "page-1",
            title: "Alpha",
            body: "physics overview",
            tags: "",
            updatedAt: .now
        )
        try searchIndex.upsertBlock(
            blockId: "block-1",
            pageId: "page-1",
            content: "physics detail"
        )

        let runtime = RetrievalRuntime(
            graphStore: store,
            graphState: graphState,
            searchIndex: searchIndex
        )

        let results = runtime.fullText(query: "physics", scope: .all)

        #expect(results.count == 1)
        #expect(results.map(\.id) == ["note-1"])
    }

    @Test("retrieval runtime preserves distinct notes across page and block search")
    func retrievalRuntimePreservesDistinctNotesAcrossPageAndBlockSearch() throws {
        let store = GraphStore()
        let graphState = GraphState()
        let searchIndex = try makeSearchIndex()

        store.addNode(makeNoteNode(id: "note-1", sourceId: "page-1", label: "Alpha"))
        store.addNode(makeNoteNode(id: "note-2", sourceId: "page-2", label: "Beta"))
        try searchIndex.upsert(
            id: "page-1",
            title: "Alpha",
            body: "physics overview",
            tags: "",
            updatedAt: .now
        )
        try searchIndex.upsertBlock(
            blockId: "block-2",
            pageId: "page-2",
            content: "physics detail"
        )

        let runtime = RetrievalRuntime(
            graphStore: store,
            graphState: graphState,
            searchIndex: searchIndex
        )

        let ids = Set(runtime.fullText(query: "physics", scope: .all).map(\.id))

        #expect(ids == ["note-1", "note-2"])
    }

    @Test("GraphEvent projection hint only reorders existing equal-score candidates")
    func graphEventProjectionHintOnlyReordersExistingEqualScoreCandidates() throws {
        let candidates = [
            RetrievalCandidate(
                node: QueryResultNode(
                    from: makeNoteNode(id: "note-a", sourceId: "page-a", label: "Alpha"),
                    score: 1.0
                ),
                source: .pageSearch
            ),
            RetrievalCandidate(
                node: QueryResultNode(
                    from: makeNoteNode(id: "note-b", sourceId: "page-b", label: "Beta"),
                    score: 1.0
                ),
                source: .pageSearch
            ),
            RetrievalCandidate(
                node: QueryResultNode(
                    from: makeNoteNode(id: "note-c", sourceId: "page-c", label: "Gamma"),
                    score: 0.5
                ),
                source: .pageSearch
            ),
        ]
        let snapshot = DurableGraphProjectionSnapshot(
            nodes: [
                makeProjectionNode(id: "note-b"),
                makeProjectionNode(id: "note-ghost"),
            ],
            edges: [],
            eventCount: 2,
            latestEventID: "event-note-b"
        )

        let hinted = GraphEventProjectionHint.apply(to: candidates, snapshot: snapshot)

        #expect(hinted.map(\.node.id) == ["note-b", "note-a", "note-c"])
        #expect(Set(hinted.map(\.node.id)) == Set(candidates.map(\.node.id)))
        #expect(hinted.count == candidates.count)
    }

    @Test("retrieval runtime applies GraphEvent projection hint only to existing full-text candidates")
    func retrievalRuntimeAppliesGraphEventProjectionHintOnlyToExistingFullTextCandidates() throws {
        let store = GraphStore()
        let graphState = GraphState()
        let searchIndex = try makeSearchIndex()

        store.addNode(makeNoteNode(id: "note-1", sourceId: "page-1", label: "Alpha"))
        store.addNode(makeNoteNode(id: "note-2", sourceId: "page-2", label: "Beta"))
        try searchIndex.upsert(
            id: "page-1",
            title: "Physics",
            body: "shared retrieval body",
            tags: "",
            updatedAt: .now
        )
        try searchIndex.upsert(
            id: "page-2",
            title: "Physics",
            body: "shared retrieval body",
            tags: "",
            updatedAt: .now
        )
        let snapshot = DurableGraphProjectionSnapshot(
            nodes: [
                makeProjectionNode(id: "note-2"),
                makeProjectionNode(id: "note-ghost"),
            ],
            edges: [],
            eventCount: 2,
            latestEventID: "event-note-2"
        )
        let runtime = RetrievalRuntime(
            graphStore: store,
            graphState: graphState,
            searchIndex: searchIndex,
            scoreLimit: 0,
            graphEventProjectionSnapshotProvider: { snapshot }
        )

        let results = runtime.fullText(query: "physics", scope: .pages)

        #expect(results.map(\.id) == ["note-2", "note-1"])
        #expect(Set(results.map(\.id)) == ["note-1", "note-2"])
    }

    @Test(
        "retrieval runtime routes all-scope through RRF fused search only behind the flag",
        .enabled(if: sqliteSupportsFTS5ForFusionTests())
    )
    func retrievalRuntimeRoutesAllScopeThroughRRFFusedSearchOnlyBehindFlag() throws {
        let flag = "EPISTEMOS_RRF_FUSION_V1"
        let previous = ProcessInfo.processInfo.environment[flag]
        unsetenv(flag)
        defer {
            if let previous {
                _ = setenv(flag, previous, 1)
            } else {
                unsetenv(flag)
            }
        }

        let store = GraphStore()
        let graphState = GraphState()
        let searchIndex = try makeSearchIndex()
        let runtime = RetrievalRuntime(
            graphStore: store,
            graphState: graphState,
            searchIndex: searchIndex
        )

        store.addNode(makeNoteNode(id: "note-readable", sourceId: "doc-readable", label: "Readable Doc"))
        let block = ReadableBlock(
            artifactID: "doc-readable",
            artifactKind: .document,
            blockID: "doc-readable#root",
            blockKind: .paragraph,
            titlePath: "Readable Doc",
            body: "metaphysics appears only in the universal readable blocks projection",
            updatedAt: ReadableBlock.iso8601(Date(timeIntervalSince1970: 200)),
            vaultID: "query-runtime-test"
        )
        try searchIndex.databaseWriter().write { db in
            try ReadableBlocksIndex.insert(block, in: db)
        }

        #expect(runtime.fullText(query: "metaphysics", scope: .all).isEmpty)

        _ = setenv(flag, "1", 1)

        #expect(runtime.fullText(query: "metaphysics", scope: .pages).isEmpty)
        #expect(runtime.fullText(query: "metaphysics", scope: .all).map(\.id) == ["note-readable"])
    }

    @Test("retrieval runtime preserves legacy full-text results when RRF fused path falls back")
    func retrievalRuntimePreservesLegacyResultsWhenRRFFusedPathFallsBack() throws {
        let flag = "EPISTEMOS_RRF_FUSION_V1"
        let previous = ProcessInfo.processInfo.environment[flag]
        _ = setenv(flag, "1", 1)
        SearchFusionMetrics.shared.reset()
        defer {
            SearchFusionMetrics.shared.reset()
            if let previous {
                _ = setenv(flag, previous, 1)
            } else {
                unsetenv(flag)
            }
        }

        let store = GraphStore()
        let graphState = GraphState()
        let searchIndex = try makeSearchIndex()
        store.addNode(makeNoteNode(id: "note-legacy", sourceId: "page-legacy", label: "Legacy Search"))
        try searchIndex.upsert(
            id: "page-legacy",
            title: "Legacy Search",
            body: "physics appears in the legacy page index",
            tags: "",
            updatedAt: .now
        )
        try searchIndex.databaseWriter().write { db in
            try db.execute(sql: "DROP TABLE IF EXISTS readable_blocks_fts")
        }

        let runtime = RetrievalRuntime(
            graphStore: store,
            graphState: graphState,
            searchIndex: searchIndex
        )

        let results = runtime.fullText(query: "physics", scope: .all)

        #expect(results.map(\.id) == ["note-legacy"])
        #expect(SearchFusionMetrics.shared.snapshot().lastErrorDescription != nil)
    }

    @Test("retrieval runtime keeps page and block scopes on legacy search when RRF flag is enabled")
    func retrievalRuntimeKeepsNonAllScopesOffRRFFusedPath() throws {
        let flag = "EPISTEMOS_RRF_FUSION_V1"
        let previous = ProcessInfo.processInfo.environment[flag]
        _ = setenv(flag, "1", 1)
        SearchFusionMetrics.shared.reset()
        defer {
            SearchFusionMetrics.shared.reset()
            if let previous {
                _ = setenv(flag, previous, 1)
            } else {
                unsetenv(flag)
            }
        }

        let store = GraphStore()
        let graphState = GraphState()
        let searchIndex = try makeSearchIndex()
        store.addNode(makeNoteNode(id: "note-page", sourceId: "page-page", label: "Page Search"))
        store.addNode(makeNoteNode(id: "note-block", sourceId: "page-block", label: "Block Search"))
        try searchIndex.upsert(
            id: "page-page",
            title: "Page Search",
            body: "pagetoken appears in the legacy page index",
            tags: "",
            updatedAt: .now
        )
        try searchIndex.upsert(
            id: "page-block",
            title: "Block Search",
            body: "block page shell",
            tags: "",
            updatedAt: .now
        )
        try searchIndex.upsertBlock(
            blockId: "block-1",
            pageId: "page-block",
            content: "blocktoken appears in the legacy block index"
        )

        let runtime = RetrievalRuntime(
            graphStore: store,
            graphState: graphState,
            searchIndex: searchIndex
        )

        #expect(runtime.fullText(query: "pagetoken", scope: .pages).map(\.id) == ["note-page"])
        #expect(runtime.fullText(query: "blocktoken", scope: .blocks).map(\.id) == ["note-block"])
        let snapshot = SearchFusionMetrics.shared.snapshot()
        #expect(snapshot.totalQueries == 0)
        #expect(snapshot.lastErrorDescription == nil)
    }

    @Test("GraphEvent projection hint stays out of indexes and renderer")
    func graphEventProjectionHintStaysOutOfIndexesAndRenderer() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/QueryRuntime.swift")

        #expect(source.contains("GraphEventProjectionHint"))
        #expect(source.contains("graphEventProjectionSnapshotProvider"))
        #expect(source.contains("EPISTEMOS_GRAPH_EVENT_QUERY_PROJECTION_V1"))
        #expect(!source.contains("saveGraphEvent"))
        #expect(!source.contains("saveMutationEnvelope"))
        #expect(!source.contains("GraphEventAuditProjectionService"))
        #expect(!source.contains("InstantRecallService"))
        #expect(!source.contains("MeaningAnchorService"))
        #expect(!source.contains("DispatchSourceTimer"))
        #expect(!source.contains("repeatForever"))
        #expect(!source.contains("Epistemos/Views/Graph"))
    }

    @Test("QueryRuntime RRF fused path stays flag-gated and falls back")
    func queryRuntimeRRFFusedPathStaysFlagGatedAndFallsBack() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/QueryRuntime.swift")

        #expect(source.contains("RRFFusionFlags.isEnabled && scope == .all"))
        #expect(source.contains("searchIndex.fusedSearch("))
        #expect(source.contains("FusionWeights(maxResults: limit)"))
        #expect(source.contains("Falling back to legacy per-index dispatch"))
        #expect(!source.contains("fusedSearchAsync("))
        #expect(!source.contains("saveGraphEvent"))
        #expect(!source.contains("saveMutationEnvelope"))
        #expect(!source.contains("GraphEventAuditProjectionService"))
        #expect(!source.contains("InstantRecallService"))
        #expect(!source.contains("MeaningAnchorService"))
        #expect(!source.contains("Process("))
        #expect(!source.contains("DispatchSourceTimer"))
        #expect(!source.contains("repeatForever"))
        #expect(!source.contains("Epistemos/Views/Graph"))
    }

    @Test("retrieval runtime scores only the configured top-k candidates")
    func retrievalRuntimeScoresOnlyConfiguredTopKCandidates() throws {
        let store = GraphStore()
        let graphState = GraphState()
        let searchIndex = try makeSearchIndex()

        store.addNode(makeNoteNode(id: "note-1", sourceId: "page-1", label: "Alpha"))
        store.addNode(makeNoteNode(id: "note-2", sourceId: "page-2", label: "Beta"))
        store.addNode(makeNoteNode(id: "note-3", sourceId: "page-3", label: "Gamma"))
        try searchIndex.upsert(
            id: "page-1",
            title: "Alpha",
            body: "physics physics physics overview",
            tags: "",
            updatedAt: .now
        )
        try searchIndex.upsert(
            id: "page-2",
            title: "Beta",
            body: "physics detail and analysis",
            tags: "",
            updatedAt: .now
        )
        try searchIndex.upsert(
            id: "page-3",
            title: "Gamma",
            body: "physics appendix",
            tags: "",
            updatedAt: .now
        )

        let baseline = RetrievalRuntime(
            graphStore: store,
            graphState: graphState,
            searchIndex: searchIndex,
            scoreLimit: 2
        )
        let scorer = ReversingScorer()
        let scoredRuntime = RetrievalRuntime(
            graphStore: store,
            graphState: graphState,
            searchIndex: searchIndex,
            scorer: scorer,
            scoreLimit: 2
        )

        let baselineIDs = baseline.fullText(query: "physics", scope: .pages).map(\.id)
        let scoredIDs = scoredRuntime.fullText(query: "physics", scope: .pages).map(\.id)

        #expect(scorer.receivedCandidateIDs.count == 2)
        #expect(Array(scoredIDs.prefix(2)) == Array(baselineIDs.prefix(2).reversed()))
        #expect(Array(scoredIDs.dropFirst(2)) == Array(baselineIDs.dropFirst(2)))
    }

    @Test("query runtime forwards configured scorer into retrieval execution")
    func queryRuntimeForwardsConfiguredScorerIntoRetrievalExecution() throws {
        let store = GraphStore()
        let graphState = GraphState()
        let searchIndex = try makeSearchIndex()

        store.addNode(makeNoteNode(id: "note-1", sourceId: "page-1", label: "Alpha"))
        store.addNode(makeNoteNode(id: "note-2", sourceId: "page-2", label: "Beta"))
        try searchIndex.upsert(
            id: "page-1",
            title: "Alpha",
            body: "physics overview",
            tags: "",
            updatedAt: .now
        )
        try searchIndex.upsert(
            id: "page-2",
            title: "Beta",
            body: "physics detail",
            tags: "",
            updatedAt: .now
        )

        let baselineRuntime = QueryRuntime(
            graphStore: store,
            graphState: graphState,
            searchIndex: searchIndex
        )
        let scorer = ReversingScorer()
        let scoredRuntime = QueryRuntime(
            graphStore: store,
            graphState: graphState,
            searchIndex: searchIndex,
            scorer: scorer
        )

        let baseline = baselineRuntime.execute(
            QueryPlan(
                steps: [.fts5Search(query: "physics", scope: .pages)],
                combiner: .single
            )
        )
        let result = scoredRuntime.execute(
            QueryPlan(
                steps: [.fts5Search(query: "physics", scope: .pages)],
                combiner: .single
            )
        )

        let baselineIDs = baseline.nodes.map(\.id)
        #expect(scorer.receivedCandidateIDs == baselineIDs)
        #expect(result.nodes.map(\.id) == baselineIDs.reversed())
    }

    @Test("prepared index scorer reorders candidates using Rust retrieval scores")
    func preparedIndexScorerUsesRustRetrievalScores() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .bgra8Unorm
        layer.frame = CGRect(x: 0, y: 0, width: 64, height: 64)

        let engine = try #require(GraphEngine(device: device, layer: layer))
        let graphState = GraphState()
        graphState.engineHandle = engine.rawHandle

        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)

        let configuration = PreparedRetrievalRuntimeConfiguration(
            retriever: PreparedModelDescriptor(
                key: "retriever_primary",
                role: .retriever,
                displayName: "BGE-M3",
                artifactID: nil,
                modelID: "BAAI/bge-m3",
                servedModelID: "BAAI/bge-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: retrieverPath.path,
                status: "downloaded",
                trustRemoteCode: false
            )
        )

        let layout = try #require(configuration.assetLayout)
        try FileManager.default.createDirectory(atPath: layout.indexRoot, withIntermediateDirectories: true)

        let sourceDatabaseURL = tempRoot.appendingPathComponent("search.sqlite")
        try Data().write(to: sourceDatabaseURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 10)],
            ofItemAtPath: sourceDatabaseURL.path
        )

        let manifest = PreparedRetrievalIndexManifest(
            retrieverModelID: "BAAI/bge-m3",
            embeddingFormat: "row-major-f32-v1",
            embeddingDimension: 2,
            documentCount: 2,
            embeddingsFile: "block-embeddings.f32",
            documentsFile: "documents.jsonl",
            builtAt: 10,
            sourceDatabasePath: sourceDatabaseURL.path,
            sourceDatabaseModifiedAt: 10,
            sourceDatabaseWALModifiedAt: nil
        )
        try JSONEncoder().encode(manifest).write(to: URL(fileURLWithPath: layout.indexManifestPath), options: .atomic)

        let values: [Float] = [
            0, 1,
            1, 0,
        ]
        let embeddingsData = values.withUnsafeBufferPointer { Data(buffer: $0) }
        try embeddingsData.write(to: URL(fileURLWithPath: layout.embeddingsPath), options: .atomic)
        try Data(
            """
            {"document_id":"doc-1","block_id":null,"page_id":"page-b","content":"beta","source_type":"page"}
            {"document_id":"doc-2","block_id":null,"page_id":"page-a","content":"alpha","source_type":"page"}
            """.utf8
        ).write(to: URL(fileURLWithPath: layout.documentsPath), options: .atomic)

        let embeddingService = EmbeddingService(
            embeddingLookup: StubTextEmbeddingLookup(vectors: [:], dimension: 0),
            preparedRetrievalRuntimeResolver: StubPreparedRetrievalRuntimeResolver(
                lookup: StubTextEmbeddingLookup(
                    vectors: ["alpha": [1, 0]],
                    dimension: 2
                )
            )
        )
        embeddingService.graphState = graphState
        embeddingService.applyPreparedRetrievalRuntimeConfiguration(configuration)
        graphState.applyPreparedRetrievalRuntimeConfiguration(configuration)

        let scorer = PreparedIndexSimilarityScorer(
            graphState: graphState,
            embeddingService: embeddingService
        )

        let candidates = [
            RetrievalCandidate(
                node: QueryResultNode(from: makeNoteNode(id: "node-b", sourceId: "page-b", label: "Beta")),
                source: .pageSearch
            ),
            RetrievalCandidate(
                node: QueryResultNode(from: makeNoteNode(id: "node-a", sourceId: "page-a", label: "Alpha")),
                source: .pageSearch
            ),
        ]

        let reranked = scorer.score(query: "alpha", candidates: candidates)

        #expect(reranked.map { $0.node.id } == ["node-a", "node-b"])
    }

    @Test("semantic retrieval does not silently degrade into text hits when semantic runtime is unavailable")
    func semanticRetrievalDoesNotSilentlyDegradeIntoTextHitsWhenSemanticRuntimeIsUnavailable() throws {
        let store = GraphStore()
        let graphState = GraphState()
        let searchIndex = try makeSearchIndex()

        store.addNode(makeNoteNode(id: "note-1", sourceId: "page-1", label: "Alpha"))
        try searchIndex.upsert(
            id: "page-1",
            title: "Alpha",
            body: "physics overview",
            tags: "",
            updatedAt: .now
        )

        let runtime = QueryRuntime(
            graphStore: store,
            graphState: graphState,
            searchIndex: searchIndex
        )

        let result = runtime.execute(
            QueryPlan(
                steps: [.semanticSearch(query: "physics", threshold: 0, limit: 10)],
                combiner: .single
            )
        )

        #expect(result.nodes.isEmpty)
    }

    @Test("combined complement returns graph nodes outside the excluded set")
    func combinedComplementReturnsNodesOutsideExcludedSet() throws {
        let store = GraphStore()
        store.addNode(makeNoteNode(id: "alpha", sourceId: "page-1", label: "Alpha"))
        store.addNode(makeNoteNode(id: "beta", sourceId: "page-2", label: "Beta"))
        store.addNode(makeNoteNode(id: "gamma", sourceId: "page-3", label: "Gamma"))

        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let plan = QueryPlan(
            subPlans: [
                QueryPlan(
                    steps: [.graphStoreFilter(NodeFilter(labelContains: "Beta", limit: 10))],
                    combiner: .single
                ),
            ],
            combiner: .complement
        )

        let result = runtime.execute(plan)

        #expect(Set(result.nodes.map(\.id)) == ["alpha", "gamma"])
    }

    @Test("combined complement preserves newest-first order while excluding matches")
    func combinedComplementPreservesNewestFirstOrder() throws {
        let store = GraphStore()
        store.addNode(
            GraphNodeRecord(
                id: "older",
                type: .note,
                label: "Older",
                sourceId: "page-1",
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )
        store.addNode(
            GraphNodeRecord(
                id: "excluded",
                type: .note,
                label: "Excluded",
                sourceId: "page-2",
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )
        store.addNode(
            GraphNodeRecord(
                id: "newest",
                type: .note,
                label: "Newest",
                sourceId: "page-3",
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: Date(timeIntervalSince1970: 300)
            )
        )

        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let plan = QueryPlan(
            subPlans: [
                QueryPlan(
                    steps: [.graphStoreFilter(NodeFilter(labelContains: "Excluded", limit: 10))],
                    combiner: .single
                ),
            ],
            combiner: .complement
        )

        let result = runtime.execute(plan)

        #expect(result.nodes.map(\.id) == ["newest", "older"])
    }

    @Test("node filter preserves matching metadata constraints")
    func nodeFilterPreservesMatchingMetadataConstraints() throws {
        let store = GraphStore()
        store.addNode(
            GraphNodeRecord(
                id: "old",
                type: .note,
                label: "Alpha",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: Date(timeIntervalSince1970: 100),
                updatedAt: Date(timeIntervalSince1970: 100)
            )
        )
        store.addNode(
            GraphNodeRecord(
                id: "fresh",
                type: .note,
                label: "Project Alpha",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: Date(timeIntervalSince1970: 200),
                updatedAt: Date(timeIntervalSince1970: 300)
            )
        )
        store.addNode(
            GraphNodeRecord(
                id: "other",
                type: .note,
                label: "Beta",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: Date(timeIntervalSince1970: 400),
                updatedAt: Date(timeIntervalSince1970: 400)
            )
        )

        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let result = runtime.execute(
            QueryPlan(
                steps: [
                    .graphStoreFilter(
                        NodeFilter(
                            types: [.note],
                            labelContains: "Alpha",
                            createdAfter: Date(timeIntervalSince1970: 150),
                            createdBefore: nil,
                            updatedAfter: nil,
                            updatedBefore: nil,
                            limit: 10
                        )
                    ),
                ],
                combiner: .single
            )
        )

        #expect(result.nodes.map(\.id) == ["fresh"])
    }

    @Test("node filter keeps only the newest matching nodes within the requested limit")
    func nodeFilterKeepsNewestMatchesWithinLimit() throws {
        let store = GraphStore()
        store.addNode(
            GraphNodeRecord(
                id: "oldest",
                type: .note,
                label: "Alpha",
                sourceId: "page-1",
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )
        store.addNode(
            GraphNodeRecord(
                id: "middle",
                type: .note,
                label: "Alpha middle",
                sourceId: "page-2",
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )
        store.addNode(
            GraphNodeRecord(
                id: "newest",
                type: .note,
                label: "Alpha newest",
                sourceId: "page-3",
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: Date(timeIntervalSince1970: 300)
            )
        )

        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let result = runtime.execute(
            QueryPlan(
                steps: [
                    .graphStoreFilter(
                        NodeFilter(
                            types: [.note],
                            labelContains: "alpha",
                            createdAfter: nil,
                            createdBefore: nil,
                            updatedAfter: nil,
                            updatedBefore: nil,
                            limit: 2
                        )
                    ),
                ],
                combiner: .single
            )
        )

        #expect(result.nodes.map(\.id) == ["newest", "middle"])
    }
}

@Suite("Query Analyzer and Compiler")
struct QueryAnalyzerAndCompilerTests {
    @Test("follow-up analysis extracts captured focus text")
    func followUpAnalysisExtractsFocus() {
        let analysis = QueryAnalyzer.analyze(
            query: "What about executive control?",
            context: ConversationContext(
                previousQueries: ["How does bilingualism affect cognition?"],
                previousEntities: ["bilingualism"],
                rootQuestion: "How does bilingualism affect cognition?"
            )
        )

        #expect(analysis.isFollowUp)
        #expect(analysis.followUpFocus == "executive control")
    }

    @Test("date equality compiles to an inclusive same-day range")
    func dateEqualityCompilesToDayRange() throws {
        let calendar = Calendar.current
        let value = Date(timeIntervalSince1970: 1_767_548_800) // January 1, 2026 12:00:00 UTC
        let plan = QueryCompiler.compile(.dateFilter(field: .created, op: .eq, value: value))

        let step = try #require(plan.steps.first)
        guard case .graphStoreFilter(let filter) = step else {
            Issue.record("Expected graphStoreFilter step")
            return
        }

        let startOfDay = calendar.startOfDay(for: value)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)

        #expect(filter.createdAfter == startOfDay)
        #expect(filter.createdBefore != nil)
        #expect((filter.createdBefore ?? startOfDay) > value)
        #expect((filter.createdBefore ?? startOfDay) < (nextDay ?? value))
    }

    @Test("date inequality compiles to the complement of the same-day range")
    func dateInequalityCompilesToComplementRange() throws {
        let calendar = Calendar.current
        let value = Date(timeIntervalSince1970: 1_767_548_800) // January 1, 2026 12:00:00 UTC
        let plan = QueryCompiler.compile(.dateFilter(field: .updated, op: .neq, value: value))

        #expect(plan.combiner == .complement)
        let subPlan = try #require(plan.subPlans.first)
        let step = try #require(subPlan.steps.first)
        guard case .graphStoreFilter(let filter) = step else {
            Issue.record("Expected graphStoreFilter step")
            return
        }

        let startOfDay = calendar.startOfDay(for: value)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)

        #expect(filter.updatedAfter == startOfDay)
        #expect(filter.updatedBefore != nil)
        #expect((filter.updatedBefore ?? startOfDay) > value)
        #expect((filter.updatedBefore ?? startOfDay) < (nextDay ?? value))
    }
}
