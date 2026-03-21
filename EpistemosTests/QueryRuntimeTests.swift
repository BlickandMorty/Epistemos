import Foundation
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

        func resolveReranker(
            configuration: PreparedRetrievalRuntimeConfiguration?,
            executionMode: PreparedRetrievalExecutionMode,
            graphState: GraphState
        ) -> any RetrievalReranking {
            PassthroughRetrievalReranker()
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
    private final class ReversingReranker: RetrievalReranking {
        private(set) var receivedCandidateIDs: [String] = []

        func rerank(query: String, candidates: [RetrievalCandidate]) -> [RetrievalCandidate] {
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

        #expect(
            pageReactive.shouldInvalidate(for: notification(name: .searchIndexDidUpdate, keys: [.searchPages]))
        )
        #expect(
            !pageReactive.shouldInvalidate(for: notification(name: .searchIndexDidUpdate, keys: [.searchBlocks]))
        )
        #expect(
            blockReactive.shouldInvalidate(for: notification(name: .searchIndexDidUpdate, keys: [.searchBlocks]))
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

    @Test("retrieval runtime reranks only the configured top-k candidates")
    func retrievalRuntimeReranksOnlyConfiguredTopKCandidates() throws {
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
            rerankLimit: 2
        )
        let reranker = ReversingReranker()
        let rerankedRuntime = RetrievalRuntime(
            graphStore: store,
            graphState: graphState,
            searchIndex: searchIndex,
            reranker: reranker,
            rerankLimit: 2
        )

        let baselineIDs = baseline.fullText(query: "physics", scope: .pages).map(\.id)
        let rerankedIDs = rerankedRuntime.fullText(query: "physics", scope: .pages).map(\.id)

        #expect(reranker.receivedCandidateIDs.count == 2)
        #expect(Array(rerankedIDs.prefix(2)) == Array(baselineIDs.prefix(2).reversed()))
        #expect(Array(rerankedIDs.dropFirst(2)) == Array(baselineIDs.dropFirst(2)))
    }

    @Test("query runtime forwards configured reranker into retrieval execution")
    func queryRuntimeForwardsConfiguredRerankerIntoRetrievalExecution() throws {
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

        let baselineRuntime = try QueryRuntime(
            graphStore: store,
            graphState: graphState,
            searchIndex: searchIndex
        )
        let reranker = ReversingReranker()
        let rerankedRuntime = try QueryRuntime(
            graphStore: store,
            graphState: graphState,
            searchIndex: searchIndex,
            reranker: reranker
        )

        let baseline = baselineRuntime.execute(
            QueryPlan(
                steps: [.fts5Search(query: "physics", scope: .pages)],
                combiner: .single
            )
        )
        let result = rerankedRuntime.execute(
            QueryPlan(
                steps: [.fts5Search(query: "physics", scope: .pages)],
                combiner: .single
            )
        )

        let baselineIDs = baseline.nodes.map(\.id)
        #expect(reranker.receivedCandidateIDs == baselineIDs)
        #expect(result.nodes.map(\.id) == baselineIDs.reversed())
    }

    @Test("prepared index reranker reorders candidates using Rust retrieval scores")
    func preparedIndexRerankerUsesRustRetrievalScores() throws {
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
            ),
            reranker: nil
        )

        let layout = try #require(configuration.assetLayout)
        try FileManager.default.createDirectory(atPath: layout.indexRoot, withIntermediateDirectories: true)

        let sourceDatabaseURL = tempRoot.appendingPathComponent("search.sqlite")
        try Data().write(to: sourceDatabaseURL, options: .atomic)
        let sourceDatabaseModifiedAt = try #require(
            sourceDatabaseURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        ).timeIntervalSince1970

        let manifest = PreparedRetrievalIndexManifest(
            retrieverModelID: "BAAI/bge-m3",
            rerankerModelID: nil,
            embeddingFormat: "row-major-f32-v1",
            embeddingDimension: 2,
            documentCount: 2,
            embeddingsFile: "block-embeddings.f32",
            documentsFile: "documents.jsonl",
            builtAt: 10,
            sourceDatabasePath: sourceDatabaseURL.path,
            sourceDatabaseModifiedAt: sourceDatabaseModifiedAt,
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

        let reranker = PreparedIndexSimilarityReranker(
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

        let reranked = reranker.rerank(query: "alpha", candidates: candidates)

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

        let runtime = try QueryRuntime(
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
