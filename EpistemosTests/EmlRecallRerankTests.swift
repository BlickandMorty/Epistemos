import Testing
import Foundation

@testable import Epistemos

// P5 EML rerank — make the tested EmlRerank primitive reachable for recall. These pin the pure
// rerank: with equal excerpt coverage it preserves the raw BM25 order (no surprise reordering),
// higher coverage breaks/boosts ties, the sort is stable, the flag defaults OFF, and recall wires
// it flag-gated.
@Suite("P5 — EML rerank reachable for recall")
struct EmlRecallRerankTests {

    private func result(_ id: String, snippet: String, rank: Double) -> SearchResult {
        SearchResult(pageId: id, title: id, snippet: snippet, rank: rank)
    }

    @Test("with equal coverage, the EML rerank preserves the BM25 order (lower rank = better, first)")
    func preservesBM25WhenCoverageEqual() {
        // FTS5 rank is lower-is-better (negative); equal snippet length → BM25 order preserved.
        let results = [
            result("a", snippet: "xxxx", rank: -1.0),
            result("b", snippet: "yyyy", rank: -3.0),
            result("c", snippet: "zzzz", rank: -2.0),
        ]
        #expect(EmlRecallRerank.reranked(results).map(\.pageId) == ["b", "c", "a"])
    }

    @Test("much higher excerpt coverage boosts a result above a BM25-equal one")
    func coverageBoosts() {
        let lowCoverage = result("short", snippet: "x", rank: -2.0)
        let highCoverage = result("long", snippet: String(repeating: "x", count: 500), rank: -2.0)
        #expect(EmlRecallRerank.reranked([lowCoverage, highCoverage]).first?.pageId == "long")
    }

    @Test("the rerank is stable on a true tie (same key → original order kept)")
    func stableOnTie() {
        let a = result("a", snippet: "xx", rank: -1.0)
        let b = result("b", snippet: "xx", rank: -1.0)
        #expect(EmlRecallRerank.reranked([a, b]).map(\.pageId) == ["a", "b"])
        #expect(EmlRecallRerank.reranked([b, a]).map(\.pageId) == ["b", "a"])
    }

    @Test("the recall rerank flag defaults OFF (raw BM25 order until opt-in)")
    func flagDefaultsOff() {
        if ProcessInfo.processInfo.environment["EPISTEMOS_EML_RERANK_RECALL_V0"] == nil {
            #expect(EmlRecallRerank.isEnabled == false)
        }
    }

    @Test("recall wires the rerank flag-gated (responder consults EmlRecallRerank)")
    func responderWiring() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/VaultBestEssayResponder.swift")
        #expect(src.contains("EmlRecallRerank.isEnabled"))
        #expect(src.contains("EmlRecallRerank.reranked(results)"))
    }
}
