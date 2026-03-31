import Foundation

// MARK: - Maximum Marginal Relevance Reranker
// Reranks search results to balance relevance with diversity.
// Prevents the agent from receiving N near-identical notes about the
// same topic, which causes LLM tunnel vision.
//
// Algorithm: MMR(d) = λ · Sim(d, q) - (1-λ) · max_{d' ∈ S} Sim(d, d')
//   λ = 0.7 (favor relevance, penalize redundancy)
//   Sim = Jaccard similarity on whitespace-tokenized sets
//
// Reference: Carbonell & Goldstein, "The Use of MMR, Diversity-Based
// Reranking for Reordering Documents and Producing Summaries" (1998)

nonisolated enum MMRReranker {

    /// A scored item with an original relevance score and text content.
    nonisolated struct ScoredItem<T> {
        let item: T
        let relevanceScore: Double
        let textForDiversity: String
    }

    /// Rerank items using Maximum Marginal Relevance.
    /// - Parameters:
    ///   - items: Scored search results with relevance scores and text.
    ///   - query: The original search query (used for relevance similarity).
    ///   - limit: Max results to return.
    ///   - lambda: Balance between relevance (1.0) and diversity (0.0). Default 0.7.
    /// - Returns: Reranked subset of items.
    static func rerank<T>(
        items: [ScoredItem<T>],
        query: String,
        limit: Int,
        lambda: Double = 0.7
    ) -> [ScoredItem<T>] {
        guard !items.isEmpty else { return [] }
        let effectiveLimit = min(limit, items.count)

        let queryTokens = tokenize(query)

        // Precompute token sets for all items
        let itemTokenSets: [Set<String>] = items.map { tokenize($0.textForDiversity) }

        // Normalize relevance scores to [0, 1]
        let maxRelevance = items.map(\.relevanceScore).max() ?? 1.0
        let minRelevance = items.map(\.relevanceScore).min() ?? 0.0
        let relevanceRange = max(maxRelevance - minRelevance, 1e-9)

        var selected: [Int] = []
        var remaining = Set(items.indices)

        for _ in 0..<effectiveLimit {
            var bestIndex = -1
            var bestMMR = -Double.infinity

            for idx in remaining {
                // Relevance: Jaccard(item, query) weighted by original score
                let queryJaccard = jaccardSimilarity(itemTokenSets[idx], queryTokens)
                let normalizedRelevance = (items[idx].relevanceScore - minRelevance) / relevanceRange
                let relevanceTerm = (queryJaccard + normalizedRelevance) / 2.0

                // Diversity penalty: max similarity to any already-selected item
                var maxSimilarityToSelected: Double = 0.0
                for selectedIdx in selected {
                    let sim = jaccardSimilarity(itemTokenSets[idx], itemTokenSets[selectedIdx])
                    maxSimilarityToSelected = max(maxSimilarityToSelected, sim)
                }

                // MMR score
                let mmr = lambda * relevanceTerm - (1.0 - lambda) * maxSimilarityToSelected

                if mmr > bestMMR {
                    bestMMR = mmr
                    bestIndex = idx
                }
            }

            guard bestIndex >= 0 else { break }
            selected.append(bestIndex)
            remaining.remove(bestIndex)
        }

        return selected.map { items[$0] }
    }

    // MARK: - Jaccard Similarity

    /// Jaccard similarity: |A ∩ B| / |A ∪ B|
    static func jaccardSimilarity(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 0.0 }
        let intersection = a.intersection(b).count
        let union = a.union(b).count
        return Double(intersection) / Double(union)
    }

    // MARK: - Tokenization

    /// Simple whitespace + punctuation tokenizer. Lowercased, deduped.
    private static func tokenize(_ text: String) -> Set<String> {
        let lowered = text.lowercased()
        let tokens = lowered.split { char in
            char.isWhitespace || char.isPunctuation
        }
        return Set(tokens.map(String.init).filter { $0.count >= 2 })
    }
}
