import Foundation

/// P5 EML rerank — make the tested, parity-locked `EmlRerank` primitive REACHABLE for recall.
/// Until now `EmlRerank.rerankKey` was consumed only by `ConfidenceRouter` (the not-yet-live route
/// energy); vault recall never used it. This reranks vault search results by the EML key — fusing
/// BM25 relevance with excerpt coverage — so the substrate's energy-rerank becomes reachable from a
/// real recall path (the vault ranked-answer responder).
///
/// FTS5 `bm25()` is LOWER-is-better (negative), and `EmlRerank.rerankKey` wants a "more is better"
/// primary, so the primary is `-rank`; the secondary boost is the matched-excerpt coverage. The key
/// is "smaller is better", matching how the results are already sorted, so with equal coverage this
/// preserves the BM25 order — coverage only breaks/boosts ties. Pure → headless-testable.
///
/// Behind EPISTEMOS_EML_RERANK_RECALL_V0 (default OFF): OFF → recall keeps the raw BM25 order
/// (byte-identical); ON → results are EML-reranked before the answer is formatted.
enum EmlRecallRerank {

    /// Default OFF. Set `EPISTEMOS_EML_RERANK_RECALL_V0=1` to make recall use the EML rerank.
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_EML_RERANK_RECALL_V0"] == "1"
    }

    /// Rerank vault search results by the EML energy key (smaller = better), stably.
    static func reranked(_ results: [SearchResult]) -> [SearchResult] {
        results
            .enumerated()
            .sorted { lhs, rhs in
                let lk = key(lhs.element), rk = key(rhs.element)
                if lk == rk { return lhs.offset < rhs.offset }   // stable on ties
                return lk < rk
            }
            .map(\.element)
    }

    /// The EML rerank key for one result: primary = BM25 "more is better" (`-rank`), secondary =
    /// matched-excerpt coverage (character length). Smaller key sorts first.
    static func key(_ result: SearchResult) -> Double {
        EmlRerank.rerankKey(primary: -result.rank, secondary: Double(result.snippet.count))
    }
}
