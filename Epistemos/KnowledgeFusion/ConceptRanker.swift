import Foundation

nonisolated struct RankedConcept: Sendable, Equatable {
    let term: String
    let score: Double
    let noteCount: Int
    let definition: String
    let lastUpdatedAt: Date
}

nonisolated struct ConceptRanker: Sendable {
    private let nowProvider: @Sendable () -> Date
    private let sentenceExtractor: @Sendable (KnowledgeSourceNote) -> [String]

    init(
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        sentenceExtractor: @escaping @Sendable (KnowledgeSourceNote) -> [String] = ConceptRanker.defaultSentenceCandidates
    ) {
        self.nowProvider = nowProvider
        self.sentenceExtractor = sentenceExtractor
    }

    func rankConcepts(notes: [KnowledgeSourceNote], limit: Int) -> [RankedConcept] {
        guard limit > 0, !notes.isEmpty else { return [] }

        let now = nowProvider()
        var weightedScores: [String: Double] = [:]
        var noteIDsByTerm: [String: Set<String>] = [:]
        var definitionCandidates: [String: (score: Double, definition: String)] = [:]
        var lastUpdatedAtByTerm: [String: Date] = [:]

        for note in notes {
            let recencyMultiplier = recencyMultiplier(for: note.updatedAt, now: now)
            let sentenceCandidates = sentenceExtractor(note)
            let fallbackSnippet = note.body.isEmpty ? note.title : note.body
            var localScores: [String: Double] = [:]

            for tag in note.tags {
                let term = normalizeTag(tag)
                guard isMeaningful(term) else { continue }
                localScores[term, default: 0] += 8
                registerDefinitionCandidate(
                    term: term,
                    candidateScore: 8 * recencyMultiplier,
                    sentenceCandidates: sentenceCandidates,
                    fallbackSnippet: fallbackSnippet,
                    definitionCandidates: &definitionCandidates
                )
            }

            for token in tokenize(note.title) {
                guard isMeaningful(token) else { continue }
                localScores[token, default: 0] += 3
                registerDefinitionCandidate(
                    term: token,
                    candidateScore: 3 * recencyMultiplier,
                    sentenceCandidates: sentenceCandidates,
                    fallbackSnippet: fallbackSnippet,
                    definitionCandidates: &definitionCandidates
                )
            }

            var bodyFrequency: [String: Int] = [:]
            for token in tokenize(note.body) where isMeaningful(token) {
                bodyFrequency[token, default: 0] += 1
            }

            for (token, count) in bodyFrequency {
                localScores[token, default: 0] += Double(min(count, 3))
                registerDefinitionCandidate(
                    term: token,
                    candidateScore: Double(min(count, 3)) * recencyMultiplier,
                    sentenceCandidates: sentenceCandidates,
                    fallbackSnippet: fallbackSnippet,
                    definitionCandidates: &definitionCandidates
                )
            }

            for (term, baseScore) in localScores {
                weightedScores[term, default: 0] += baseScore * recencyMultiplier
                noteIDsByTerm[term, default: []].insert(note.id)
                if let existing = lastUpdatedAtByTerm[term] {
                    lastUpdatedAtByTerm[term] = max(existing, note.updatedAt)
                } else {
                    lastUpdatedAtByTerm[term] = note.updatedAt
                }
            }
        }

        return weightedScores
            .map { term, score in
                RankedConcept(
                    term: term,
                    score: score,
                    noteCount: noteIDsByTerm[term]?.count ?? 0,
                    definition: definitionCandidates[term]?.definition ?? "",
                    lastUpdatedAt: lastUpdatedAtByTerm[term] ?? now
                )
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.term < $1.term
                }
                return $0.score > $1.score
            }
            .prefix(limit)
            .map { $0 }
    }

    private func registerDefinitionCandidate(
        term: String,
        candidateScore: Double,
        sentenceCandidates: [String],
        fallbackSnippet: String,
        definitionCandidates: inout [String: (score: Double, definition: String)]
    ) {
        let definition = bestDefinitionSentence(
            for: term,
            sentenceCandidates: sentenceCandidates,
            fallbackSnippet: fallbackSnippet
        )
        guard !definition.isEmpty else { return }
        if let existing = definitionCandidates[term], existing.score >= candidateScore {
            return
        }
        definitionCandidates[term] = (candidateScore, definition)
    }

    private func bestDefinitionSentence(
        for term: String,
        sentenceCandidates: [String],
        fallbackSnippet: String
    ) -> String {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else { return "" }
        if let match = sentenceCandidates.first(where: {
            $0.localizedCaseInsensitiveContains(trimmedTerm)
        }) {
            return String(match.prefix(180))
        }

        return String(fallbackSnippet.prefix(180)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func recencyMultiplier(for updatedAt: Date, now: Date) -> Double {
        let ageDays = max(0, now.timeIntervalSince(updatedAt) / 86_400)
        let boost = max(0, 30 - ageDays) / 30
        return 1.0 + (boost * 0.5)
    }

    private func normalizeTag(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func defaultSentenceCandidates(for note: KnowledgeSourceNote) -> [String] {
        let haystack = note.body.isEmpty ? note.title : note.body
        return haystack
            .split(whereSeparator: { $0 == "." || $0 == "!" || $0 == "?" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func tokenize(_ value: String) -> [String] {
        value
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" })
            .map(String.init)
    }

    private func isMeaningful(_ term: String) -> Bool {
        guard term.count >= 3 else { return false }
        if Self.stopWords.contains(term) { return false }
        return term.rangeOfCharacter(from: .letters) != nil
    }

    private static let stopWords: Set<String> = [
        "about", "after", "again", "also", "and", "are", "because", "been", "before",
        "being", "between", "both", "but", "can", "context", "could", "does", "each",
        "even", "every", "from", "have", "into", "just", "long", "more", "most",
        "much", "need", "note", "notes", "other", "over", "same", "should", "some",
        "such", "than", "that", "their", "them", "there", "these", "they", "this",
        "those", "through", "want", "what", "when", "which", "with", "would", "your",
    ]
}
