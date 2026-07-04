import Testing
@testable import EpistemosLlama

// Engine-adjacent invariants that need no model file.

@Suite("UTF8PieceAccumulator")
struct UTF8PieceAccumulatorTests {
    @Test("plain ASCII passes through per piece")
    func asciiPassthrough() {
        var accumulator = UTF8PieceAccumulator()
        #expect(accumulator.push(Array("Hello".utf8)) == "Hello")
        #expect(accumulator.push(Array(" world".utf8)) == " world")
        #expect(accumulator.flush() == nil)
    }

    @Test("multi-byte scalar split across pieces is held then emitted whole")
    func splitScalarHeldAcrossPieces() {
        var accumulator = UTF8PieceAccumulator()
        let emoji = Array("🦙".utf8) // 4 bytes
        let first = accumulator.push(Array(emoji[0..<2]))
        #expect(first == nil)
        let second = accumulator.push(Array(emoji[2..<4]))
        #expect(second == "🦙")
    }

    @Test("CJK split mid-sequence emits valid prefix and carries the tail")
    func cjkSplitCarriesTail() {
        var accumulator = UTF8PieceAccumulator()
        let bytes = Array("知識".utf8) // 6 bytes, two 3-byte scalars
        let first = accumulator.push(Array(bytes[0..<4])) // scalar 1 + 1 stray byte
        #expect(first == "知")
        let second = accumulator.push(Array(bytes[4..<6]))
        #expect(second == "識")
    }

    @Test("flush drains any pending bytes exactly once")
    func flushDrains() {
        var accumulator = UTF8PieceAccumulator()
        _ = accumulator.push(Array(Array("é".utf8)[0..<1]))
        #expect(accumulator.flush() != nil)
        #expect(accumulator.flush() == nil)
    }
}

@Suite("LocalChatWindowAccounting")
struct WindowAccountingTests {
    @Test("remaining tokens never go negative")
    func remainingClampsAtZero() {
        let accounting = LocalChatWindowAccounting(
            contextTokens: 100,
            promptTokens: 80,
            generatedTokens: 40
        )
        #expect(accounting.remainingTokens == 0)
    }

    @Test("remaining reflects prompt plus generated")
    func remainingMath() {
        let accounting = LocalChatWindowAccounting(
            contextTokens: 4_096,
            promptTokens: 1_000,
            generatedTokens: 96
        )
        #expect(accounting.remainingTokens == 3_000)
    }
}
