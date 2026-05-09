import Foundation
import Metal
import QuartzCore
import Testing
@testable import Epistemos

private struct StubTextEmbeddingLookup: TextEmbeddingLookup {
    let vectors: [String: [Float]]
    let dimension: Int

    func vector(for token: String) -> [Float]? {
        vectors[token]
    }
}

private struct SlowTextEmbeddingLookup: TextEmbeddingLookup {
    let dimension: Int
    let delay: TimeInterval
    let vector: [Float]

    func vector(for token: String) -> [Float]? {
        Thread.sleep(forTimeInterval: delay)
        return vector
    }
}

private nonisolated final class DeferredLookupProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var creations = 0

    func makeLookup() -> any TextEmbeddingLookup {
        lock.lock()
        creations += 1
        lock.unlock()
        return StubTextEmbeddingLookup(
            vectors: ["alpha": [1, 2]],
            dimension: 2
        )
    }

    var creationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return creations
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
@Suite("BlockEmbeddings")
struct BlockEmbeddingTests {
    private func makeNode(id: String, label: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id,
            type: .note,
            label: label,
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now
        )
    }

    @Test("computeBlockVectors returns vectors for blocks with real content")
    func computeReturnsVectors() async {
        let service = EmbeddingService()
        let blocks: [(id: String, content: String)] = [
            (id: "block-1", content: "quantum physics research"),
            (id: "block-2", content: "machine learning algorithms"),
        ]

        let result = service.computeBlockVectors(blocks: blocks)

        #expect(result.count == 2)
        #expect(result["block-1"] != nil)
        #expect(result["block-2"] != nil)
    }

    @Test("empty and short content blocks produce no embedding")
    func emptyContentSkipped() async {
        let service = EmbeddingService()
        let blocks: [(id: String, content: String)] = [
            (id: "empty", content: ""),
            (id: "whitespace", content: "   "),
            (id: "single-char", content: "a b c"),
            (id: "valid", content: "quantum physics"),
        ]

        let result = service.computeBlockVectors(blocks: blocks)

        #expect(result["empty"] == nil)
        #expect(result["whitespace"] == nil)
        #expect(result["single-char"] == nil)
        #expect(result["valid"] != nil)
    }

    @Test("all vectors have same dimension")
    func uniformDimension() async {
        let service = EmbeddingService()
        let blocks: [(id: String, content: String)] = [
            (id: "a", content: "quantum entanglement theory"),
            (id: "b", content: "neural network training"),
            (id: "c", content: "differential equations calculus"),
        ]

        let result = service.computeBlockVectors(blocks: blocks)

        let dimensions = Set(result.values.map(\.count))
        #expect(dimensions.count == 1, "All vectors should have the same dimension")
    }

    @Test("vectors have nonzero dimension")
    func nonzeroDimension() async {
        let service = EmbeddingService()
        let blocks: [(id: String, content: String)] = [
            (id: "test", content: "quantum physics research"),
        ]

        let result = service.computeBlockVectors(blocks: blocks)

        if let vector = result["test"] {
            #expect(!vector.isEmpty, "Embedding vector should have nonzero dimension")
            #expect(vector.count > 0)
        } else {
            Issue.record("Expected embedding for 'test' block — NLEmbedding may be unavailable")
        }
    }

    @Test("queryEmbedding uses the configured embedding backend")
    func queryEmbeddingUsesConfiguredBackend() async {
        let service = EmbeddingService(
            embeddingLookup: StubTextEmbeddingLookup(
                vectors: [
                    "alpha": [2, 0],
                    "beta": [0, 2],
                ],
                dimension: 2
            )
        )

        let result = service.queryEmbedding(for: "alpha beta", expectedDimension: 2)

        #expect(result == [1, 1])
    }

    @Test("deferred embedding lookup waits until the first semantic access")
    func deferredEmbeddingLookupWaitsForFirstAccess() async {
        let probe = DeferredLookupProbe()
        let lookup = DeferredTextEmbeddingLookup {
            probe.makeLookup()
        }

        #expect(probe.creationCount == 0)
        #expect(lookup.dimension == 2)
        #expect(probe.creationCount == 1)
        #expect(lookup.vector(for: "alpha") == [1, 2])
        #expect(probe.creationCount == 1)
    }

    @Test("queryEmbedding refuses dimension mismatch")
    func queryEmbeddingRejectsDimensionMismatch() async {
        let service = EmbeddingService(
            embeddingLookup: StubTextEmbeddingLookup(
                vectors: ["alpha": [1, 1]],
                dimension: 2
            )
        )

        let result = service.queryEmbedding(for: "alpha", expectedDimension: 3)

        #expect(result == nil)
    }

    @Test("embedding service defaults to apple fallback until prepared retrieval assets exist")
    func embeddingServiceDefaultsToAppleFallback() async {
        let service = EmbeddingService(
            embeddingLookup: StubTextEmbeddingLookup(
                vectors: ["alpha": [1, 1]],
                dimension: 2
            )
        )

        #expect(service.preparedRetrievalRuntimeConfiguration == nil)
        #expect(service.preparedRetrievalExecutionMode == .appleEmbeddingFallback)
        #expect(service.preparedRetrievalExecutionMode.usesSwiftEmbeddingFallback)
    }

    @Test("embedding service disables Swift semantic query embedding once prepared retrieval leaves apple fallback")
    func embeddingServiceDisablesSwiftSemanticQueryEmbeddingOutsideFallback() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)

        let service = EmbeddingService(
            embeddingLookup: StubTextEmbeddingLookup(
                vectors: [:],
                dimension: 0
            ),
            preparedRetrievalRuntimeResolver: StubPreparedRetrievalRuntimeResolver(
                lookup: StubTextEmbeddingLookup(
                    vectors: [
                        "alpha": [2, 0],
                        "beta": [0, 2],
                    ],
                    dimension: 2
                )
            )
        )

        service.applyPreparedRetrievalRuntimeConfiguration(
            PreparedRetrievalRuntimeConfiguration(
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
        )

        let result = service.queryEmbedding(for: "alpha beta")

        #expect(service.preparedRetrievalExecutionMode == .preparedAssetsPendingIndex(retrieverModelID: "BAAI/bge-m3"))
        #expect(!service.preparedRetrievalExecutionMode.usesSwiftEmbeddingFallback)
        #expect(result == nil)
    }

    @Test("embedding service enables prepared query embeddings once a built index is ready")
    func embeddingServiceEnablesPreparedQueryEmbeddingsOnceIndexIsReady() async throws {
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
        let sourceDatabaseModifiedAt = try #require(
            sourceDatabaseURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        ).timeIntervalSince1970

        let manifest = PreparedRetrievalIndexManifest(
            retrieverModelID: "BAAI/bge-m3",
            embeddingFormat: "row-major-f32-v1",
            embeddingDimension: 2,
            documentCount: 1,
            embeddingsFile: "block-embeddings.f32",
            documentsFile: "documents.jsonl",
            builtAt: 10,
            sourceDatabasePath: sourceDatabaseURL.path,
            sourceDatabaseModifiedAt: sourceDatabaseModifiedAt,
            sourceDatabaseWALModifiedAt: nil
        )
        try JSONEncoder().encode(manifest).write(to: URL(fileURLWithPath: layout.indexManifestPath), options: .atomic)

        let values: [Float] = [1, 0]
        let embeddingsData = values.withUnsafeBufferPointer { Data(buffer: $0) }
        try embeddingsData.write(to: URL(fileURLWithPath: layout.embeddingsPath), options: .atomic)
        try Data("{\"document_id\":\"doc-1\",\"block_id\":null,\"page_id\":\"page-1\",\"content\":\"alpha beta\",\"source_type\":\"page\"}\n".utf8)
            .write(to: URL(fileURLWithPath: layout.documentsPath), options: .atomic)

        let service = EmbeddingService(
            embeddingLookup: StubTextEmbeddingLookup(vectors: [:], dimension: 0),
            preparedRetrievalRuntimeResolver: StubPreparedRetrievalRuntimeResolver(
                lookup: StubTextEmbeddingLookup(
                    vectors: [
                        "alpha": [2, 0],
                        "beta": [0, 2],
                    ],
                    dimension: 2
                )
            )
        )

        service.applyPreparedRetrievalRuntimeConfiguration(configuration)

        let result = service.queryEmbedding(for: "alpha beta", expectedDimension: 2)

        #expect(service.preparedRetrievalExecutionMode == .preparedIndexReady(retrieverModelID: "BAAI/bge-m3"))
        #expect(!service.preparedRetrievalExecutionMode.usesSwiftEmbeddingFallback)
        #expect(result == [1, 1])
    }

    @Test("computeBlockVectors stays empty once prepared retrieval leaves apple fallback")
    func computeBlockVectorsStayEmptyOutsideFallback() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)

        let service = EmbeddingService(
            embeddingLookup: StubTextEmbeddingLookup(
                vectors: [
                    "alpha": [2, 0],
                    "beta": [0, 2],
                ],
                dimension: 2
            )
        )

        service.applyPreparedRetrievalRuntimeConfiguration(
            PreparedRetrievalRuntimeConfiguration(
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
        )

        let result = service.computeBlockVectors(
            blocks: [(id: "mixed", content: "alpha beta")]
        )

        #expect(result.isEmpty)
    }

    @Test("changing prepared retrieval runtime clears stale semantic state")
    func runtimeChangeClearsStaleSemanticState() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)

        let service = EmbeddingService(
            embeddingLookup: StubTextEmbeddingLookup(
                vectors: ["alpha": [1, 1]],
                dimension: 2
            ),
            preparedRetrievalRuntimeResolver: StubPreparedRetrievalRuntimeResolver(
                lookup: StubTextEmbeddingLookup(
                    vectors: ["beta": [2, 0]],
                    dimension: 2
                )
            )
        )
        service.replaceEmbeddingCacheForTesting(["node-1": [1, 1]])
        service.setDimensionForTesting(2)

        service.applyPreparedRetrievalRuntimeConfiguration(
            PreparedRetrievalRuntimeConfiguration(
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
        )

        let snapshot = service.embeddingCacheDebugSnapshot()

        #expect(snapshot.entryCount == 0)
        #expect(service.dimension == 0)
        #expect(service.preparedRetrievalExecutionMode == .preparedAssetsPendingIndex(retrieverModelID: "BAAI/bge-m3"))
    }

    @Test("computeBlockVectors uses the configured embedding backend")
    func computeBlockVectorsUsesConfiguredBackend() async {
        let service = EmbeddingService(
            embeddingLookup: StubTextEmbeddingLookup(
                vectors: [
                    "alpha": [2, 0],
                    "beta": [0, 2],
                    "gamma": [1, 1],
                ],
                dimension: 2
            )
        )

        let result = service.computeBlockVectors(
            blocks: [
                (id: "mixed", content: "alpha beta"),
                (id: "single", content: "gamma"),
                (id: "unknown", content: "zzz")
            ]
        )

        #expect(result["mixed"] == [1, 1])
        #expect(result["single"] == [1, 1])
        #expect(result["unknown"] == nil)
    }

    @Test("fallback semantic clustering uses the configured fallback embedding backend")
    func fallbackSemanticClusteringUsesConfiguredBackend() async {
        let service = EmbeddingService(
            embeddingLookup: StubTextEmbeddingLookup(
                vectors: [
                    "alpha": [1, 0],
                    "beta": [0, 1],
                    "gamma": [1, 1],
                    "delta": [0.5, 0.5],
                ],
                dimension: 2
            )
        )
        let store = GraphStore()
        store.addNode(makeNode(id: "n1", label: "alpha"))
        store.addNode(makeNode(id: "n2", label: "beta"))
        store.addNode(makeNode(id: "n3", label: "gamma"))
        store.addNode(makeNode(id: "n4", label: "delta"))

        let clusters = service.computeFallbackSemanticClusters(store: store)

        #expect(clusters.count == 4)
        #expect(clusters["n1"] != nil)
        #expect(clusters["n2"] != nil)
        #expect(clusters["n3"] != nil)
        #expect(clusters["n4"] != nil)
    }

    @Test("embedding cache enforces a hard cap")
    func embeddingCacheEnforcesHardCap() async {
        let service = EmbeddingService()
        service.setEmbeddingCacheCapacityForTesting(3)
        service.replaceEmbeddingCacheForTesting([
            "a": [1.0],
            "b": [2.0],
            "c": [3.0],
            "d": [4.0],
            "e": [5.0],
        ])

        let snapshot = service.embeddingCacheDebugSnapshot()

        #expect(snapshot.capacity == 3)
        #expect(snapshot.entryCount == 3)
        #expect(snapshot.currentSize == 3)
        #expect(snapshot.evictions == 2)
        #expect(service.embedding(for: "a") == nil)
    }

    @Test("embedding cache retains recently accessed items across eviction")
    func embeddingCacheRetainsRecentlyAccessedItems() async {
        let service = EmbeddingService()
        service.setEmbeddingCacheCapacityForTesting(3)
        service.replaceEmbeddingCacheForTesting([
            "a": [1.0],
            "b": [2.0],
            "c": [3.0],
        ])

        #expect(service.embedding(for: "a") == [1.0])

        service.replaceEmbeddingCacheForTesting([
            "a": [1.0],
            "b": [2.0],
            "c": [3.0],
            "d": [4.0],
        ])

        #expect(service.embedding(for: "a") == [1.0])
        #expect(service.embedding(for: "b") == nil)
        #expect(service.embedding(for: "d") == [4.0])
    }

    @Test("embedding cache reports hit and miss metrics")
    func embeddingCacheReportsMetrics() async {
        let service = EmbeddingService(maxCacheEntries: 2)
        service.replaceEmbeddingCacheForTesting([
            "a": [1.0],
            "b": [2.0],
        ])

        #expect(service.embedding(for: "a") == [1.0])
        #expect(service.embedding(for: "missing") == nil)

        let snapshot = service.embeddingCacheDebugSnapshot()
        #expect(snapshot.capacity == 2)
        #expect(snapshot.currentSize == 2)
        #expect(snapshot.hits == 1)
        #expect(snapshot.misses == 1)
    }

    @Test("computeAndPush clears stale cache when the graph is too small")
    func computeAndPushClearsCacheForSmallGraph() async {
        let service = EmbeddingService()
        service.setEmbeddingCacheCapacityForTesting(4)
        service.replaceEmbeddingCacheForTesting([
            "stale-a": [1.0],
            "stale-b": [2.0],
        ])

        let store = GraphStore()
        store.addNode(makeNode(id: "solo", label: "Solo"))

        service.computeAndPush(store: store)

        let snapshot = service.embeddingCacheDebugSnapshot()
        #expect(snapshot.entryCount == 0)
        #expect(snapshot.currentSize == 0)
        #expect(service.embedding(for: "stale-a") == nil)
    }

    @Test("computeAndPush resets the Rust semantic store to the active fallback dimension before pushing")
    func computeAndPushResetsRustStoreDimensionBeforePushing() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .bgra8Unorm
        layer.frame = CGRect(x: 0, y: 0, width: 64, height: 64)

        let engine = try #require(GraphEngine(device: device, layer: layer))
        engine.addNode(uuid: "alpha-node", x: 0, y: 0, nodeType: .note, linkCount: 1, label: "Alpha")
        engine.addNode(uuid: "beta-node", x: 10, y: 10, nodeType: .note, linkCount: 1, label: "Beta")
        engine.commit(entrance: false)

        let graphState = GraphState()
        graphState.engineHandle = engine.rawHandle

        let service = EmbeddingService(
            embeddingLookup: StubTextEmbeddingLookup(
                vectors: [
                    "alpha": [1, 0],
                    "beta": [0, 1],
                ],
                dimension: 2
            )
        )
        service.graphState = graphState

        let store = GraphStore()
        store.addNode(makeNode(id: "alpha-node", label: "alpha"))
        store.addNode(makeNode(id: "beta-node", label: "beta"))

        #expect(engine.semanticEmbeddingDimension() == 512)

        service.computeAndPush(store: store)
        await service.waitForPendingComputationForTesting()

        #expect(engine.semanticEmbeddingDimension() == 2)
        #expect(engine.semanticEmbeddingCount() == 2)
    }

    @Test("computeAndPush does not block MainActor while fallback embeddings are computed")
    func computeAndPushDoesNotBlockMainActor() async {
        let service = EmbeddingService(
            embeddingLookup: SlowTextEmbeddingLookup(
                dimension: 2,
                delay: 0.2,
                vector: [1, 0]
            )
        )

        let store = GraphStore()
        store.addNode(makeNode(id: "alpha-node", label: "alpha"))
        store.addNode(makeNode(id: "beta-node", label: "beta"))
        store.addNode(makeNode(id: "gamma-node", label: "gamma"))

        let clock = ContinuousClock()
        let start = clock.now
        service.computeAndPush(store: store)
        let elapsed = clock.now - start

        #expect(elapsed < .milliseconds(150), "computeAndPush blocked MainActor for \(elapsed)")

        await service.waitForPendingComputationForTesting()

        let snapshot = service.embeddingCacheDebugSnapshot()
        #expect(snapshot.entryCount == 3)
        #expect(service.dimension == 2)
    }

    @Test("semantic recompute task participates in engine teardown")
    func semanticRecomputeTaskParticipatesInEngineTeardown() throws {
        let serviceSource = try loadMirroredSourceTextFile("Epistemos/Graph/EmbeddingService.swift")
        let metalGraphSource = try loadMirroredSourceTextFile("Epistemos/Views/Graph/MetalGraphView.swift")

        #expect(serviceSource.contains("final class DetachedEngineUseTracker"))
        #expect(serviceSource.contains("func prepareForEngineDestroy()"))
        #expect(serviceSource.contains("detachedEngineUseTracker.closeAndWait()"))
        #expect(serviceSource.contains("detachedEngineUseTracker.begin()"))
        #expect(metalGraphSource.contains("embeddingService.prepareForEngineDestroy()"))

        let engineSource = try loadMirroredSourceTextFile("graph-engine/src/engine.rs")
        let graphFFISource = try loadMirroredSourceTextFile("graph-engine/src/lib.rs")
        #expect(engineSource.contains("pub(crate) embedding_store: Mutex<EmbeddingStore>"))
        #expect(graphFFISource.contains("let embedding_snapshot = engine.embedding_store.lock().clone();"))
        #expect(graphFFISource.contains("let pairs = embedding_snapshot.all_knn_pairs(k as usize, threshold);"))
    }

    @Test("fallback semantic search requires a populated Rust store with a matching dimension")
    func fallbackSemanticSearchRequiresPopulatedMatchingRustStore() async throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .bgra8Unorm
        layer.frame = CGRect(x: 0, y: 0, width: 64, height: 64)

        let engine = try #require(GraphEngine(device: device, layer: layer))
        engine.addNode(uuid: "alpha-node", x: 0, y: 0, nodeType: .note, linkCount: 1, label: "Alpha")
        engine.commit(entrance: false)

        let graphState = GraphState()
        graphState.engineHandle = engine.rawHandle
        graphState.embeddingService.setDimensionForTesting(2)

        #expect(graphState.canRunFallbackSemanticSearch() == false)

        #expect(engine.resetSemanticEmbeddingDimension(to: 2))
        #expect(graphState.canRunFallbackSemanticSearch() == false)

        engine.setNodeEmbedding(uuid: "alpha-node", vector: [1, 0])
        #expect(graphState.canRunFallbackSemanticSearch())

        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)

        graphState.applyPreparedRetrievalRuntimeConfiguration(
            PreparedRetrievalRuntimeConfiguration(
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
        )

        #expect(graphState.canRunFallbackSemanticSearch() == false)
    }
}
