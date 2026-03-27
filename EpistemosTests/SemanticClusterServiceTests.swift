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
