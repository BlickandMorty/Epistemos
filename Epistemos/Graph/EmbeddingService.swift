import Accelerate
import Foundation
import NaturalLanguage

// MARK: - Sendable Helpers

nonisolated protocol TextEmbeddingLookup: Sendable {
    var dimension: Int { get }
    func vector(for token: String) -> [Float]?
}

nonisolated struct AppleWordEmbeddingLookup: TextEmbeddingLookup {
    var dimension: Int {
        NLEmbedding.wordEmbedding(for: .english)?.dimension ?? 0
    }

    func vector(for token: String) -> [Float]? {
        guard let embedding = NLEmbedding.wordEmbedding(for: .english),
              let vector = embedding.vector(for: token) else {
            return nil
        }

        var result = [Float](repeating: 0, count: vector.count)
        vDSP.convertElements(of: vector, to: &result)
        return result
    }
}

/// Value-type snapshot of node data for cross-isolation transfer.
private nonisolated struct EmbeddingNodeSnapshot: Sendable {
    let id: String
    let text: String
}

private nonisolated struct EmbeddingBatchPayload: Sendable {
    let ids: [String]
    let values: [Float]
    let dimension: Int

    var isEmpty: Bool {
        ids.isEmpty || values.isEmpty || dimension <= 0
    }
}

private nonisolated struct SendableEngineHandle: @unchecked Sendable {
    let raw: OpaquePointer
}

// MARK: - EmbeddingService
// Generates fallback word embeddings using Apple NLEmbedding and pushes them to the Rust
// engine while prepared retrieval remains on the Apple fallback path.
//
// Heavy computation (NLEmbedding + vector math) and the batched embedding push run
// on a background detached task. MainActor work is limited to cache/state updates
// and reading the current engine handle.

@MainActor
final class EmbeddingService {
    private enum EmbeddingCacheConfig {
        static let capacity = 4096
    }

    struct EmbeddingCacheDebugSnapshot {
        let entryCount: Int
        let currentSize: Int
        let capacity: Int
        let hits: Int
        let misses: Int
        let evictions: Int
    }

    /// Cached embeddings (node UUID → float vector).
    private(set) var embeddings: [String: [Float]] = [:]

    /// Embedding dimension (from NLEmbedding — typically 512).
    private(set) var dimension: Int = 0

    private let defaultEmbeddingCacheCapacity: Int
    private var embeddingCacheOrder: [String] = []
    private var embeddingCacheHitCount = 0
    private var embeddingCacheMissCount = 0
    private var embeddingCacheEvictionCount = 0
    private var embeddingCacheCapacityOverride: Int?
    private let fallbackEmbeddingLookup: any TextEmbeddingLookup
    private let preparedRetrievalRuntimeResolver: any PreparedRetrievalRuntimeResolving
    nonisolated(unsafe) private var activeEmbeddingLookup: any TextEmbeddingLookup
    nonisolated(unsafe) private var swiftEmbeddingFallbackActive = true
    nonisolated(unsafe) private var preparedQueryEmbeddingActive = false
    private(set) var preparedRetrievalRuntimeConfiguration: PreparedRetrievalRuntimeConfiguration?
    private(set) var preparedRetrievalExecutionMode: PreparedRetrievalExecutionMode = .appleEmbeddingFallback
    var preparedRetrievalIndexManifestPath: String? {
        preparedRetrievalRuntimeConfiguration?.assetLayout?.indexManifestPath
    }

    /// The compute task handle. Marked nonisolated(unsafe) so deinit can cancel it
    /// synchronously without requiring @MainActor isolation.
    nonisolated(unsafe) private var computeTask: Task<Void, Never>?

    /// Weak reference to owning GraphState — used to read the live engine handle
    /// inside MainActor.run instead of capturing a stale pointer by value.
    weak var graphState: GraphState?

    init(
        maxCacheEntries: Int = EmbeddingCacheConfig.capacity,
        embeddingLookup: any TextEmbeddingLookup = AppleWordEmbeddingLookup(),
        preparedRetrievalRuntimeResolver: any PreparedRetrievalRuntimeResolving = DefaultPreparedRetrievalRuntimeResolver()
    ) {
        self.defaultEmbeddingCacheCapacity = max(0, maxCacheEntries)
        fallbackEmbeddingLookup = embeddingLookup
        self.preparedRetrievalRuntimeResolver = preparedRetrievalRuntimeResolver
        activeEmbeddingLookup = embeddingLookup
    }

    func applyPreparedRetrievalRuntimeConfiguration(_ configuration: PreparedRetrievalRuntimeConfiguration?) {
        let previousConfiguration = preparedRetrievalRuntimeConfiguration
        let previousExecutionMode = preparedRetrievalExecutionMode
        preparedRetrievalRuntimeConfiguration = configuration
        preparedRetrievalExecutionMode = configuration?.preparedRetrievalExecutionMode ?? .appleEmbeddingFallback
        swiftEmbeddingFallbackActive = preparedRetrievalExecutionMode.usesSwiftEmbeddingFallback
        preparedQueryEmbeddingActive = preparedRetrievalExecutionMode.hasPreparedIndexRuntime
        activeEmbeddingLookup = preparedRetrievalRuntimeResolver.resolveEmbeddingLookup(
            configuration: configuration,
            executionMode: preparedRetrievalExecutionMode,
            fallback: fallbackEmbeddingLookup
        )
        if previousConfiguration != preparedRetrievalRuntimeConfiguration || previousExecutionMode != preparedRetrievalExecutionMode {
            cancelPendingTask()
            clearEmbeddingCache()
            dimension = 0
            clearEngineEmbeddings()
            clearPreparedRetrievalIndexRuntime()
        }
    }

    private var embeddingCacheCapacity: Int {
        max(0, embeddingCacheCapacityOverride ?? defaultEmbeddingCacheCapacity)
    }

    /// Compute embeddings for all graph nodes and push to the Rust engine.
    /// Call after commitGraphData() when the graph has been loaded.
    func computeAndPush(store: GraphStore) {
        guard swiftEmbeddingFallbackActive else {
            cancelPendingTask()
            clearEmbeddingCache()
            dimension = 0
            clearEngineEmbeddings()
            return
        }

        computeTask?.cancel()

        // Snapshot node data for background processing (pure-value copy, no shared refs).
        let nodeSnapshots: [EmbeddingNodeSnapshot] = store.nodes.values.map { node in
            var text = node.label
            if let abstract = node.metadata.abstract, !abstract.isEmpty {
                text += " " + abstract
            }
            if let theme = node.metadata.clusterTheme, !theme.isEmpty {
                text += " " + theme
            }
            return EmbeddingNodeSnapshot(id: node.id, text: text)
        }
        guard nodeSnapshots.count >= 2 else {
            clearEmbeddingCache()
            dimension = 0
            clearEngineEmbeddings()
            return
        }

        let embeddingLookup = activeEmbeddingLookup

        // Heavy compute on background thread — NLEmbedding word lookups + vector math.
        // Task.detached escapes @MainActor isolation so this doesn't block rendering.
        computeTask = Task.detached(priority: .utility) { [weak self] in
            let dim = embeddingLookup.dimension
            guard dim > 0 else {
                await MainActor.run { Log.app.error("EmbeddingService: NLEmbedding unavailable") }
                return
            }

            var newEmbeddings: [String: [Float]] = [:]

            for snapshot in nodeSnapshots {
                guard !Task.isCancelled else { return }

                if let vector = Self.averageEmbedding(
                    for: snapshot.text,
                    dimension: dim,
                    embeddingLookup: embeddingLookup
                ) {
                    newEmbeddings[snapshot.id] = vector
                }
            }

            guard !Task.isCancelled else { return }
            let completedEmbeddings = newEmbeddings
            let payload = Self.makeEmbeddingBatchPayload(from: completedEmbeddings, dimension: dim)

            let engineHandle: SendableEngineHandle? = await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return nil }
                self.dimension = dim
                self.replaceEmbeddingCache(with: completedEmbeddings)
                guard let engine = self.graphState?.engineHandle else { return nil }
                return SendableEngineHandle(raw: engine)
            }

            guard !Task.isCancelled,
                  let engineHandle,
                  !payload.isEmpty,
                  Self.prepareEngineEmbeddingStore(engineHandle.raw, dimension: dim) else {
                return
            }

            Self.sendEmbeddingBatch(payload, to: engineHandle.raw)
            // Recompute KNN: O(n^2*dim) — expensive but runs on this background
            // thread. The Rust function writes to engine.semantic_neighbors and
            // calls reheat(). This is NOT safe to call concurrently with render,
            // but the render loop only reads semantic_neighbors inside
            // sync_semantic_neighbors() which holds the sim Mutex. The KNN write
            // itself is to engine.semantic_neighbors (not sim), and render only
            // reads it inside a Mutex-locked section → safe as long as we don't
            // call this while sync_semantic_neighbors is running (which it can't
            // be, since sync holds the Mutex and tick() calls it serially).
            graph_engine_recompute_semantic_neighbors(engineHandle.raw, 8, 0.3)

            await MainActor.run {
                Log.app.info("EmbeddingService: pushed \(completedEmbeddings.count) embeddings (dim=\(dim)) to Rust")
            }
        }
    }

    /// Cancel any in-flight background embedding computation.
    /// Safe to call from any isolation domain (nonisolated).
    nonisolated func cancelPendingTask() {
        computeTask?.cancel()
        computeTask = nil
    }

    /// Get embedding for a specific node (for hybrid search).
    func embedding(for nodeId: String) -> [Float]? {
        guard let vector = embeddings[nodeId] else {
            embeddingCacheMissCount += 1
            return nil
        }
        embeddingCacheHitCount += 1
        touchEmbeddingCacheEntry(nodeId)
        return vector
    }

    // MARK: - Block Embeddings

    nonisolated func queryEmbedding(for query: String, expectedDimension: Int? = nil) -> [Float]? {
        guard swiftEmbeddingFallbackActive || preparedQueryEmbeddingActive else { return nil }
        let embeddingLookup = activeEmbeddingLookup
        let dimension = expectedDimension ?? embeddingLookup.dimension
        guard dimension > 0 else { return nil }
        guard expectedDimension == nil || expectedDimension == dimension else { return nil }
        return Self.averageEmbedding(
            for: query,
            dimension: dimension,
            embeddingLookup: embeddingLookup
        )
    }

    /// Compute embedding vectors for a set of blocks using NLEmbedding word-averaging.
    /// Pure computation — does NOT push to Rust. Returns blockId -> vector dict.
    /// Blocks with empty content or no recognized words are skipped.
    nonisolated func computeBlockVectors(blocks: [(id: String, content: String)]) -> [String: [Float]] {
        guard swiftEmbeddingFallbackActive else { return [:] }
        let embeddingLookup = activeEmbeddingLookup
        let dim = embeddingLookup.dimension
        guard dim > 0 else { return [:] }
        var result: [String: [Float]] = [:]
        result.reserveCapacity(blocks.count)

        for block in blocks {
            if let vector = Self.averageEmbedding(
                for: block.content,
                dimension: dim,
                embeddingLookup: embeddingLookup
            ) {
                result[block.id] = vector
            }
        }

        return result
    }

    func computeFallbackSemanticClusters(store: GraphStore) -> [String: UInt32] {
        SemanticClusterService.computeClusters(
            store: store,
            embeddingLookup: fallbackEmbeddingLookup
        )
    }

    /// Push pre-computed block embeddings to the Rust engine via FFI.
    /// Same pattern as node embedding push — requires MainActor for engineHandle access.
    func pushBlockEmbeddings(_ embeddings: [String: [Float]]) {
        guard let engine = graphState?.engineHandle else { return }
        guard let firstVector = embeddings.values.first else { return }
        let dim = firstVector.count
        let payload = Self.makeEmbeddingBatchPayload(from: embeddings, dimension: dim)
        guard !payload.isEmpty else { return }
        let engineHandle = SendableEngineHandle(raw: engine)

        Task.detached(priority: .utility) {
            guard Self.prepareEngineEmbeddingStore(engineHandle.raw, dimension: dim) else { return }
            Self.sendEmbeddingBatch(payload, to: engineHandle.raw)
        }
    }

    private nonisolated static func makeEmbeddingBatchPayload(
        from embeddings: [String: [Float]],
        dimension: Int
    ) -> EmbeddingBatchPayload {
        guard dimension > 0 else {
            return EmbeddingBatchPayload(ids: [], values: [], dimension: 0)
        }

        let ids = embeddings.keys.sorted()
        var flattened: [Float] = []
        flattened.reserveCapacity(ids.count * dimension)

        var filteredIDs: [String] = []
        filteredIDs.reserveCapacity(ids.count)

        for id in ids {
            guard let vector = embeddings[id], vector.count == dimension else { continue }
            filteredIDs.append(id)
            flattened.append(contentsOf: vector)
        }

        return EmbeddingBatchPayload(ids: filteredIDs, values: flattened, dimension: dimension)
    }

    private nonisolated static func sendEmbeddingBatch(
        _ payload: EmbeddingBatchPayload,
        to engine: OpaquePointer
    ) {
        guard !payload.isEmpty else { return }
        withStableCStringArray(payload.ids) { uuidPtrs in
            payload.values.withUnsafeBufferPointer { values in
                guard let valuesBase = values.baseAddress else { return }
                graph_engine_set_node_embeddings_batch(
                    engine,
                    uuidPtrs.baseAddress,
                    valuesBase,
                    UInt32(payload.dimension),
                    UInt32(payload.ids.count)
                )
            }
        }
    }

    func embeddingCacheDebugSnapshot() -> EmbeddingCacheDebugSnapshot {
        EmbeddingCacheDebugSnapshot(
            entryCount: embeddings.count,
            currentSize: embeddings.count,
            capacity: embeddingCacheCapacity,
            hits: embeddingCacheHitCount,
            misses: embeddingCacheMissCount,
            evictions: embeddingCacheEvictionCount
        )
    }

    func setEmbeddingCacheCapacityForTesting(_ capacity: Int?) {
        embeddingCacheCapacityOverride = capacity.map { max(0, $0) }
        trimEmbeddingCacheIfNeeded()
    }

    func replaceEmbeddingCacheForTesting(_ embeddings: [String: [Float]]) {
        replaceEmbeddingCache(with: embeddings)
    }

    func setDimensionForTesting(_ dimension: Int) {
        self.dimension = max(0, dimension)
    }

    func waitForPendingComputationForTesting() async {
        let task = computeTask
        await task?.value
    }

    private func clearEmbeddingCache() {
        embeddings.removeAll(keepingCapacity: true)
        embeddingCacheOrder.removeAll(keepingCapacity: true)
    }

    private func clearEngineEmbeddings() {
        guard let engine = graphState?.engineHandle else { return }
        graph_engine_clear_embeddings(engine)
    }

    private func clearPreparedRetrievalIndexRuntime() {
        guard let engine = graphState?.engineHandle else { return }
        graph_engine_clear_prepared_retrieval_index(engine)
    }

    private nonisolated static func prepareEngineEmbeddingStore(_ engine: OpaquePointer, dimension: Int) -> Bool {
        guard dimension > 0 else { return false }
        if Int(graph_engine_embedding_dimension(engine)) != dimension {
            return graph_engine_reset_embedding_dimension(engine, UInt32(dimension)) != 0
        }
        graph_engine_clear_embeddings(engine)
        return true
    }

    private func touchEmbeddingCacheEntry(_ nodeId: String) {
        embeddingCacheOrder.removeAll { $0 == nodeId }
        embeddingCacheOrder.append(nodeId)
    }

    private func replaceEmbeddingCache(with newEmbeddings: [String: [Float]]) {
        var cache = newEmbeddings
        var ordered = embeddingCacheOrder.filter { cache[$0] != nil }
        let existing = Set(ordered)
        ordered.append(
            contentsOf: cache.keys
                .filter { !existing.contains($0) }
                .sorted()
        )

        while cache.count > embeddingCacheCapacity && !ordered.isEmpty {
            let evicted = ordered.removeFirst()
            if cache.removeValue(forKey: evicted) != nil {
                embeddingCacheEvictionCount += 1
            }
        }

        embeddings = cache
        embeddingCacheOrder = ordered
    }

    private func trimEmbeddingCacheIfNeeded() {
        replaceEmbeddingCache(with: embeddings)
    }

    private nonisolated static func averageEmbedding(
        for text: String,
        dimension: Int,
        embeddingLookup: any TextEmbeddingLookup
    ) -> [Float]? {
        let words = text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 1 }

        var sumVector = [Float](repeating: 0, count: dimension)
        var count = 0

        for word in words {
            guard let vector = embeddingLookup.vector(for: word),
                  vector.count == dimension else {
                continue
            }
            vDSP.add(sumVector, vector, result: &sumVector)
            count += 1
        }

        guard count > 0 else { return nil }
        var scaled = [Float](repeating: 0, count: dimension)
        vDSP.multiply(1.0 / Float(count), sumVector, result: &scaled)
        return scaled
    }
}
