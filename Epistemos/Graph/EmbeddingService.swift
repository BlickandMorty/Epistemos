import Accelerate
import Foundation
import NaturalLanguage

// MARK: - Sendable Helpers

nonisolated protocol TextEmbeddingLookup: Sendable {
    var dimension: Int { get }
    func vector(for token: String) -> [Float]?

    /// Whole-text embedding. Return nil to fall back to per-token averaging.
    /// Lookups that support ANE-accelerated contextual embeddings (e.g.
    /// `AppleContextualEmbeddingLookup`) should implement this to skip the
    /// word-averaging code path entirely.
    func textVector(for text: String) -> [Float]?
}

extension TextEmbeddingLookup {
    nonisolated func textVector(for text: String) -> [Float]? { nil }
}

private nonisolated final class DeferredTextEmbeddingLookupStorage: @unchecked Sendable {
    private let lock = NSLock()
    private let factory: @Sendable () -> any TextEmbeddingLookup
    private var resolvedLookup: (any TextEmbeddingLookup)?

    init(factory: @escaping @Sendable () -> any TextEmbeddingLookup) {
        self.factory = factory
    }

    func lookup() -> any TextEmbeddingLookup {
        lock.lock()
        defer { lock.unlock() }

        if let resolvedLookup {
            return resolvedLookup
        }

        let lookup = factory()
        resolvedLookup = lookup
        return lookup
    }
}

nonisolated struct DeferredTextEmbeddingLookup: TextEmbeddingLookup, @unchecked Sendable {
    private let storage: DeferredTextEmbeddingLookupStorage

    init(factory: @escaping @Sendable () -> any TextEmbeddingLookup) {
        storage = DeferredTextEmbeddingLookupStorage(factory: factory)
    }

    var dimension: Int {
        storage.lookup().dimension
    }

    func vector(for token: String) -> [Float]? {
        storage.lookup().vector(for: token)
    }

    func textVector(for text: String) -> [Float]? {
        storage.lookup().textVector(for: text)
    }
}

nonisolated struct AppleWordEmbeddingLookup: TextEmbeddingLookup {
    nonisolated var dimension: Int {
        NLEmbedding.wordEmbedding(for: .english)?.dimension ?? 0
    }

    nonisolated func vector(for token: String) -> [Float]? {
        guard let embedding = NLEmbedding.wordEmbedding(for: .english),
              let vector = embedding.vector(for: token) else {
            return nil
        }

        var result = [Float](repeating: 0, count: vector.count)
        vDSP.convertElements(of: vector, to: &result)
        return result
    }
}

/// NLContextualEmbedding-backed lookup. Runs on ANE on Apple Silicon when
/// model assets are available (macOS 14+). Returns nil from `vector(for:)`
/// because per-token contextual lookups defeat the purpose of a contextual
/// model — the whole-text path is exposed via `textVector(for:)`.
///
/// Compose this with `AppleWordEmbeddingLookup` (see `AppleHybridEmbeddingLookup`)
/// to stay working while the model is downloading or when the query language
/// is not supported.
nonisolated struct AppleContextualEmbeddingLookup: TextEmbeddingLookup, @unchecked Sendable {
    // SAFETY: NLContextualEmbedding is a Foundation-bridged ObjC class. It is
    // effectively immutable after init (we only call `embeddingResult(...)` and
    // read `dimension`/`hasAvailableAssets`), and Apple documents those paths as
    // safe to invoke without external synchronization.
    private let embedding: NLContextualEmbedding?
    private let language: NLLanguage

    init(language: NLLanguage = .english) {
        self.language = language
        // Contextual activates only when assets are already present on device.
        // Asset download is not kicked off from here to keep the lookup
        // Sendable-clean; the hybrid lookup falls back to word embeddings until
        // assets land via other Apple-framework paths.
        self.embedding = NLContextualEmbedding(language: language)
    }

    var dimension: Int {
        guard let embedding, embedding.hasAvailableAssets else { return 0 }
        return Int(embedding.dimension)
    }

    func vector(for token: String) -> [Float]? { nil }

    func textVector(for text: String) -> [Float]? {
        guard let embedding, embedding.hasAvailableAssets else { return nil }
        guard let result = try? embedding.embeddingResult(for: text, language: language) else { return nil }
        return Self.meanPool(result, dimension: Int(embedding.dimension))
    }

    private static func meanPool(_ result: NLContextualEmbeddingResult, dimension: Int) -> [Float]? {
        guard dimension > 0 else { return nil }
        var sum = [Float](repeating: 0, count: dimension)
        var count = 0
        let range = result.string.startIndex..<result.string.endIndex
        result.enumerateTokenVectors(in: range) { vector, _ in
            guard vector.count == dimension else { return true }
            var converted = [Float](repeating: 0, count: dimension)
            vDSP.convertElements(of: vector, to: &converted)
            vDSP.add(sum, converted, result: &sum)
            count += 1
            return true
        }
        guard count > 0 else { return nil }
        var scaled = [Float](repeating: 0, count: dimension)
        vDSP.multiply(1.0 / Float(count), sum, result: &scaled)
        return scaled
    }
}

/// Composite lookup that prefers ANE-accelerated contextual embeddings when
/// available and falls back to the stable word-embedding path otherwise.
/// Dimension is pinned at construction time to keep cached vectors consistent
/// within a single session; restart the embedding cache to pick up a transition
/// from word → contextual after assets finish downloading.
nonisolated struct AppleHybridEmbeddingLookup: TextEmbeddingLookup, @unchecked Sendable {
    private let contextual: AppleContextualEmbeddingLookup
    private let word: AppleWordEmbeddingLookup
    private let pinnedDimension: Int
    private let usesContextual: Bool

    init() {
        let ctx = AppleContextualEmbeddingLookup()
        let wrd = AppleWordEmbeddingLookup()
        let cdim = ctx.dimension
        if cdim > 0 {
            self.usesContextual = true
            self.pinnedDimension = cdim
        } else {
            self.usesContextual = false
            self.pinnedDimension = wrd.dimension
        }
        self.contextual = ctx
        self.word = wrd
    }

    var dimension: Int { pinnedDimension }

    func vector(for token: String) -> [Float]? {
        usesContextual ? nil : word.vector(for: token)
    }

    func textVector(for text: String) -> [Float]? {
        guard usesContextual else { return nil }
        return contextual.textVector(for: text)
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

private nonisolated final class DetachedEngineUseTracker: @unchecked Sendable {
    private let lock = NSLock()
    private let group = DispatchGroup()
    private var acceptsUse = true

    func open() {
        lock.lock()
        acceptsUse = true
        lock.unlock()
    }

    func begin() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard acceptsUse else { return false }
        group.enter()
        return true
    }

    func end() {
        group.leave()
    }

    func closeAndWait() {
        lock.lock()
        acceptsUse = false
        lock.unlock()
        group.wait()
    }

    func closeAndWaitAsync() async {
        await Task.detached(priority: .utility) {
            self.closeAndWait()
        }.value
    }
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
    // SAFETY: written only on MainActor (applyPreparedRetrievalRuntimeConfiguration),
    // read from nonisolated embedding functions — the values are effectively immutable
    // between configuration changes.
    nonisolated(unsafe) private var activeEmbeddingLookup: any TextEmbeddingLookup
    nonisolated(unsafe) private var swiftEmbeddingFallbackActive = true
    nonisolated(unsafe) private var preparedQueryEmbeddingActive = false
    private(set) var preparedRetrievalRuntimeConfiguration: PreparedRetrievalRuntimeConfiguration?
    private(set) var preparedRetrievalExecutionMode: PreparedRetrievalExecutionMode = .appleEmbeddingFallback
    var preparedRetrievalIndexManifestPath: String? {
        preparedRetrievalRuntimeConfiguration?.assetLayout?.indexManifestPath
    }

    // SAFETY: accessed from nonisolated cancelPendingTask/prepareForEngineDestroy only after
    // the MainActor task that writes it has completed or been cancelled.
    nonisolated(unsafe) private var computeTask: Task<Void, Never>?
    private let detachedEngineUseTracker = DetachedEngineUseTracker()

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

    func prepareForEngineUse() {
        detachedEngineUseTracker.open()
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
                  !payload.isEmpty else {
                return
            }

            // FFI push (mutates embedding_store) must stay on MainActor.
            // Signpost interval — feeds Phase 0 perf budget (graph.embed.push.ms).
            // Master plan target: <2 ms p99; ceiling 4 ms. If this exceeds budget,
            // move the push off MainActor with a Rust-side mutex audit first.
            let pushInterval = Log.graphPerf.beginInterval("graph.embed.push.ms")
            await MainActor.run {
                guard Self.prepareEngineEmbeddingStore(engineHandle.raw, dimension: dim) else {
                    return
                }
                Self.sendEmbeddingBatch(payload, to: engineHandle.raw)
            }
            Log.graphPerf.endInterval("graph.embed.push.ms", pushInterval)

            // KNN recompute is O(n²) — run off main thread to avoid beach ball.
            // The Rust side uses a Mutex to install the result, so the render
            // loop is never blocked by the computation.
            let handle = engineHandle
            let count = completedEmbeddings.count
            guard let detachedEngineUseTracker = self?.detachedEngineUseTracker,
                  !Task.isCancelled,
                  detachedEngineUseTracker.begin() else {
                return
            }
            let task = Task.detached(priority: .utility) {
                defer { detachedEngineUseTracker.end() }
                graph_engine_recompute_semantic_neighbors(handle.raw, 8, 0.3)
                Log.app.info("EmbeddingService: pushed \(count) embeddings (dim=\(dim)) to Rust")
            }
            _ = task
        }
    }

    /// Cancel any in-flight background embedding computation.
    /// Safe to call from any isolation domain (nonisolated).
    nonisolated func cancelPendingTask() {
        computeTask?.cancel()
        computeTask = nil
    }

    nonisolated func prepareForEngineDestroy() {
        cancelPendingTask()
        detachedEngineUseTracker.closeAndWait()
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

        // SAFETY: FFI calls MUST run on MainActor to prevent use-after-free.
        // The payload construction above is the expensive part (already done).
        // The FFI push below is fast — safe to run on main.
        Task { @MainActor in
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
        await detachedEngineUseTracker.closeAndWaitAsync()
        detachedEngineUseTracker.open()
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
        if let contextual = embeddingLookup.textVector(for: text),
           contextual.count == dimension {
            return contextual
        }

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
