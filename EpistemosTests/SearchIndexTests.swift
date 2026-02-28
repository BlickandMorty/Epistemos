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
}
