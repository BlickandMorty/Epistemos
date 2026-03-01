import Foundation
import Testing
@testable import Epistemos

@Suite("SearchIndex")
struct SearchIndexTests {

    // MARK: - FTS5 Query Sanitization
    // Tests the real SearchIndexService.sanitizeFTS5Query (now internal).

    @Test("normal query produces quoted prefix tokens")
    func normalQuery() {
        let result = SearchIndexService.sanitizeFTS5Query("hello world")
        #expect(result == "\"hello\"* \"world\"*")
    }

    @Test("single short word is filtered out")
    func shortWordFiltered() {
        let result = SearchIndexService.sanitizeFTS5Query("a")
        #expect(result.isEmpty)
    }

    @Test("empty string produces empty result")
    func emptyQuery() {
        let result = SearchIndexService.sanitizeFTS5Query("")
        #expect(result.isEmpty)
    }

    @Test("punctuation is stripped")
    func punctuationStripped() {
        let result = SearchIndexService.sanitizeFTS5Query("hello, world! test.")
        #expect(result == "\"hello\"* \"world\"* \"test\"*")
    }

    @Test("mixed short and long words filters correctly")
    func mixedLengths() {
        let result = SearchIndexService.sanitizeFTS5Query("I am a big dog")
        // "I" and "a" are too short (< 2 chars), "am" has 2 chars (>= 2) so stays
        #expect(result == "\"am\"* \"big\"* \"dog\"*")
    }

    @Test("uppercase is lowercased")
    func lowercased() {
        let result = SearchIndexService.sanitizeFTS5Query("QUANTUM Physics")
        #expect(result == "\"quantum\"* \"physics\"*")
    }

    @Test("single valid word produces single token")
    func singleWord() {
        let result = SearchIndexService.sanitizeFTS5Query("quantum")
        #expect(result == "\"quantum\"*")
    }

    // MARK: - Audit W5.5 — FTS5 Hardening Edge Cases

    @Test("embedded quotes are stripped")
    func quotesStripped() {
        let result = SearchIndexService.sanitizeFTS5Query("\"unclosed quote")
        #expect(!result.contains("\"\""))  // No doubled quotes
        #expect(result == "\"unclosed\"* \"quote\"*")
    }

    @Test("FTS5 operators are treated as words")
    func operatorsNeutralized() {
        let result = SearchIndexService.sanitizeFTS5Query("database NOT sensitive OR private")
        // NOT, OR become lowercase words; split by alphanumerics strips no operators
        #expect(result == "\"database\"* \"not\"* \"sensitive\"* \"or\"* \"private\"*")
    }

    @Test("very long input is capped at 500 characters")
    func longInputCapped() {
        let longInput = String(repeating: "quantum ", count: 200)  // 1600 chars
        let result = SearchIndexService.sanitizeFTS5Query(longInput)
        // After 500 char cap + word splitting, result should be limited
        #expect(!result.isEmpty)
        // Count quoted tokens — should be well under the full 200 repetitions
        let tokenCount = result.components(separatedBy: "\"*").count - 1
        #expect(tokenCount <= 20)  // Word count cap
    }

    @Test("word count is capped at 20")
    func wordCountCapped() {
        let manyWords = (1...50).map { "word\($0)" }.joined(separator: " ")
        let result = SearchIndexService.sanitizeFTS5Query(manyWords)
        let tokenCount = result.components(separatedBy: "\"*").count - 1
        #expect(tokenCount == 20)
    }

    @Test("wildcard-only input produces empty result")
    func wildcardOnly() {
        let result = SearchIndexService.sanitizeFTS5Query("* ** ***")
        #expect(result.isEmpty)  // '*' is not alphanumeric, filtered out
    }

    @Test("column filter syntax is neutralized")
    func columnFilterNeutralized() {
        let result = SearchIndexService.sanitizeFTS5Query("title:search body:hack")
        // Colon splits "title" and "search" into separate words
        #expect(result == "\"title\"* \"search\"* \"body\"* \"hack\"*")
    }
}
