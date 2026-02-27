import Foundation
import Testing
@testable import Epistemos

@Suite("SearchIndex")
struct SearchIndexTests {

    // MARK: - FTS5 Query Sanitization

    // SearchIndexService.sanitizeFTS5Query is private static.
    // Test it indirectly through search behavior, or test the logic pattern directly.
    // Since the method is private, we test the contract: search with various inputs.

    // For now, test the sanitization logic by replicating it here and verifying the pattern.
    // The actual method: splits on non-alphanumeric, filters words < 2 chars, wraps in quotes+*.

    private func sanitize(_ raw: String) -> String {
        let words = raw.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
        guard !words.isEmpty else { return "" }
        return words.map { "\"\($0)\"*" }.joined(separator: " ")
    }

    @Test("normal query produces quoted prefix tokens")
    func normalQuery() {
        let result = sanitize("hello world")
        #expect(result == "\"hello\"* \"world\"*")
    }

    @Test("single short word is filtered out")
    func shortWordFiltered() {
        let result = sanitize("a")
        #expect(result.isEmpty)
    }

    @Test("empty string produces empty result")
    func emptyQuery() {
        let result = sanitize("")
        #expect(result.isEmpty)
    }

    @Test("punctuation is stripped")
    func punctuationStripped() {
        let result = sanitize("hello, world! test.")
        #expect(result == "\"hello\"* \"world\"* \"test\"*")
    }

    @Test("mixed short and long words filters correctly")
    func mixedLengths() {
        let result = sanitize("I am a big dog")
        // "I", "am", "a" are too short (< 2 chars... wait "am" is 2 chars)
        // Actually "am" has 2 chars which is >= 2, so it stays
        #expect(result == "\"am\"* \"big\"* \"dog\"*")
    }

    @Test("uppercase is lowercased")
    func lowercased() {
        let result = sanitize("QUANTUM Physics")
        #expect(result == "\"quantum\"* \"physics\"*")
    }

    @Test("single valid word produces single token")
    func singleWord() {
        let result = sanitize("quantum")
        #expect(result == "\"quantum\"*")
    }
}
