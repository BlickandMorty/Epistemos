import Foundation
import Testing
@testable import Epistemos

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
        let service = await EmbeddingService()
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
        let service = await EmbeddingService()
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
        let service = await EmbeddingService()
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
        let service = await EmbeddingService()
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

    @Test("embedding cache enforces a hard cap")
    func embeddingCacheEnforcesHardCap() async {
        let service = await EmbeddingService()
        await service.setEmbeddingCacheCapacityForTesting(3)
        await service.replaceEmbeddingCacheForTesting([
            "a": [1.0],
            "b": [2.0],
            "c": [3.0],
            "d": [4.0],
            "e": [5.0],
        ])

        let snapshot = await service.embeddingCacheDebugSnapshot()

        #expect(snapshot.capacity == 3)
        #expect(snapshot.entryCount == 3)
        #expect(snapshot.currentSize == 3)
        #expect(snapshot.evictions == 2)
        #expect(await service.embedding(for: "a") == nil)
    }

    @Test("embedding cache retains recently accessed items across eviction")
    func embeddingCacheRetainsRecentlyAccessedItems() async {
        let service = await EmbeddingService()
        await service.setEmbeddingCacheCapacityForTesting(3)
        await service.replaceEmbeddingCacheForTesting([
            "a": [1.0],
            "b": [2.0],
            "c": [3.0],
        ])

        #expect(await service.embedding(for: "a") == [1.0])

        await service.replaceEmbeddingCacheForTesting([
            "a": [1.0],
            "b": [2.0],
            "c": [3.0],
            "d": [4.0],
        ])

        #expect(await service.embedding(for: "a") == [1.0])
        #expect(await service.embedding(for: "b") == nil)
        #expect(await service.embedding(for: "d") == [4.0])
    }

    @Test("embedding cache reports hit and miss metrics")
    func embeddingCacheReportsMetrics() async {
        let service = await EmbeddingService(maxCacheEntries: 2)
        await service.replaceEmbeddingCacheForTesting([
            "a": [1.0],
            "b": [2.0],
        ])

        #expect(await service.embedding(for: "a") == [1.0])
        #expect(await service.embedding(for: "missing") == nil)

        let snapshot = await service.embeddingCacheDebugSnapshot()
        #expect(snapshot.capacity == 2)
        #expect(snapshot.currentSize == 2)
        #expect(snapshot.hits == 1)
        #expect(snapshot.misses == 1)
    }

    @Test("computeAndPush clears stale cache when the graph is too small")
    func computeAndPushClearsCacheForSmallGraph() async {
        let service = await EmbeddingService()
        await service.setEmbeddingCacheCapacityForTesting(4)
        await service.replaceEmbeddingCacheForTesting([
            "stale-a": [1.0],
            "stale-b": [2.0],
        ])

        let store = GraphStore()
        store.addNode(makeNode(id: "solo", label: "Solo"))

        await service.computeAndPush(store: store)

        let snapshot = await service.embeddingCacheDebugSnapshot()
        #expect(snapshot.entryCount == 0)
        #expect(snapshot.currentSize == 0)
        #expect(await service.embedding(for: "stale-a") == nil)
    }
}
