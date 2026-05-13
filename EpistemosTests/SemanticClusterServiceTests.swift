import Foundation
import Testing
@testable import Epistemos

private struct StubTextEmbeddingLookup: TextEmbeddingLookup {
    let dimension: Int
    let vectors: [String: [Float]]

    init(dimension: Int = 2, vectors: [String: [Float]]) {
        self.dimension = dimension
        self.vectors = vectors
    }

    func vector(for token: String) -> [Float]? {
        vectors[token]
    }
}

@Suite("SemanticClusterService")
@MainActor
struct SemanticClusterServiceTests {
    @Test("similar embeddings cluster together across randomized seeding")
    func similarEmbeddingsClusterTogether() throws {
        let store = GraphStore()
        store.addNode(makeNode(id: "science-a", label: "science reason"))
        store.addNode(makeNode(id: "science-b", label: "science logic"))
        store.addNode(makeNode(id: "poetry-a", label: "poetry lyric"))
        store.addNode(makeNode(id: "poetry-b", label: "poetry verse"))

        let lookup = StubTextEmbeddingLookup(vectors: [
            "science": [1.0, 0.0],
            "reason": [1.0, 0.0],
            "logic": [0.9, 0.1],
            "poetry": [0.0, 1.0],
            "lyric": [0.1, 0.9],
            "verse": [0.0, 1.0],
        ])

        for _ in 0..<10 {
            let clusters = SemanticClusterService.computeClusters(store: store, embeddingLookup: lookup)

            let scienceA = try #require(clusters["science-a"])
            let scienceB = try #require(clusters["science-b"])
            let poetryA = try #require(clusters["poetry-a"])
            let poetryB = try #require(clusters["poetry-b"])

            #expect(scienceA == scienceB)
            #expect(poetryA == poetryB)
            #expect(scienceA != poetryA)
        }
    }

    @Test("nodes without embeddings stay pinned to cluster zero")
    func nodesWithoutEmbeddingsStayPinnedToZero() throws {
        let store = GraphStore()
        store.addNode(makeNode(id: "science-a", label: "science reason"))
        store.addNode(makeNode(id: "science-b", label: "science logic"))
        store.addNode(makeNode(id: "poetry-a", label: "poetry lyric"))
        store.addNode(makeNode(id: "poetry-b", label: "poetry verse"))
        store.addNode(makeNode(id: "unknown", label: "mystery token"))

        let lookup = StubTextEmbeddingLookup(vectors: [
            "science": [1.0, 0.0],
            "reason": [1.0, 0.0],
            "logic": [0.9, 0.1],
            "poetry": [0.0, 1.0],
            "lyric": [0.1, 0.9],
            "verse": [0.0, 1.0],
        ])

        let clusters = SemanticClusterService.computeClusters(store: store, embeddingLookup: lookup)

        #expect(clusters.count == 5)
        #expect(try #require(clusters["unknown"]) == 0)
    }

    // MARK: - RCA-P1-012 off-main entry point (2026-05-13)

    @Test("computeClustersFromNodes produces same result as computeClusters on the same input")
    func nonisolatedEntryPointMatchesMainActorEntryPoint() throws {
        // The nonisolated `computeClustersFromNodes` must be a drop-in
        // for the MainActor `computeClusters` so callers that hop
        // off-main don't see a different clustering than the legacy
        // path. Identity here is "same equivalence-classes" — k-means
        // cluster IDs are permutation-arbitrary, so we compare the
        // partition shape, not the exact ID values.
        let store = GraphStore()
        store.addNode(makeNode(id: "science-a", label: "science reason"))
        store.addNode(makeNode(id: "science-b", label: "science logic"))
        store.addNode(makeNode(id: "poetry-a", label: "poetry lyric"))
        store.addNode(makeNode(id: "poetry-b", label: "poetry verse"))

        let lookup = StubTextEmbeddingLookup(vectors: [
            "science": [1.0, 0.0],
            "reason": [1.0, 0.0],
            "logic": [0.9, 0.1],
            "poetry": [0.0, 1.0],
            "lyric": [0.1, 0.9],
            "verse": [0.0, 1.0],
        ])

        let viaMainActor = SemanticClusterService.computeClusters(
            store: store,
            embeddingLookup: lookup
        )
        let nodes = Array(store.nodes.values)
        let viaNonisolated = SemanticClusterService.computeClustersFromNodes(
            nodes: nodes,
            embeddingLookup: lookup
        )

        // Same partition: science nodes in one cluster, poetry in
        // another, on both paths.
        let mScienceA = try #require(viaMainActor["science-a"])
        let mScienceB = try #require(viaMainActor["science-b"])
        let mPoetryA = try #require(viaMainActor["poetry-a"])
        let mPoetryB = try #require(viaMainActor["poetry-b"])
        #expect(mScienceA == mScienceB)
        #expect(mPoetryA == mPoetryB)
        #expect(mScienceA != mPoetryA)

        let nScienceA = try #require(viaNonisolated["science-a"])
        let nScienceB = try #require(viaNonisolated["science-b"])
        let nPoetryA = try #require(viaNonisolated["poetry-a"])
        let nPoetryB = try #require(viaNonisolated["poetry-b"])
        #expect(nScienceA == nScienceB)
        #expect(nPoetryA == nPoetryB)
        #expect(nScienceA != nPoetryA)
    }

    @Test("computeClustersFromNodes handles < 4 nodes the same way computeClusters does")
    func nonisolatedEntryPointDegenerateInputMatchesMainActor() {
        // Below-threshold cluster (< 4 nodes) returns every node in
        // cluster 0 per the existing guard. Both entry points share
        // the implementation so they must match.
        let onlyThree = [
            makeNode(id: "a", label: "alpha"),
            makeNode(id: "b", label: "beta"),
            makeNode(id: "c", label: "gamma"),
        ]
        let lookup = StubTextEmbeddingLookup(vectors: [
            "alpha": [1.0, 0.0],
            "beta": [0.0, 1.0],
            "gamma": [0.5, 0.5],
        ])
        let result = SemanticClusterService.computeClustersFromNodes(
            nodes: onlyThree,
            embeddingLookup: lookup
        )
        #expect(result.count == 3)
        #expect(result.values.allSatisfy { $0 == 0 },
            "below-threshold input must put every node in cluster 0; got \(result)")
    }

    @Test("computeClustersFromNodes is callable from a detached Task without MainActor")
    func nonisolatedEntryPointRunsFromDetachedTask() async throws {
        // The whole point of the RCA-P1-012 chip: this static method
        // must compile + run from a `Task.detached` body. Without the
        // `nonisolated` keyword, calling it from off-main would
        // produce an actor-isolation compile error.
        let nodes = [
            makeNode(id: "science-a", label: "science reason"),
            makeNode(id: "science-b", label: "science logic"),
            makeNode(id: "poetry-a", label: "poetry lyric"),
            makeNode(id: "poetry-b", label: "poetry verse"),
        ]
        let lookup = StubTextEmbeddingLookup(vectors: [
            "science": [1.0, 0.0],
            "reason": [1.0, 0.0],
            "logic": [0.9, 0.1],
            "poetry": [0.0, 1.0],
            "lyric": [0.1, 0.9],
            "verse": [0.0, 1.0],
        ])
        let task = Task.detached(priority: .userInitiated) { () -> Int in
            let result = SemanticClusterService.computeClustersFromNodes(
                nodes: nodes,
                embeddingLookup: lookup
            )
            return result.count
        }
        let count = await task.value
        #expect(count == 4,
            "detached task must successfully invoke computeClustersFromNodes; got \(count) entries")
    }

    private func makeNode(id: String, label: String) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id,
            type: .note,
            label: label,
            sourceId: id,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now
        )
    }
}
