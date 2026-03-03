import Foundation
import Testing
@testable import Epistemos

@Suite("BlockEmbeddings")
struct BlockEmbeddingTests {

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
}
