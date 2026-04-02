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

    init(nowProvider: @escaping @Sendable () -> Date = Date.init) {
        self.nowProvider = nowProvider
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
            var localScores: [String: Double] = [:]

            for tag in note.tags {
                let term = normalizeTag(tag)
                guard isMeaningful(term) else { continue }
                localScores[term, default: 0] += 8
                registerDefinitionCandidate(
                    term: term,
                    note: note,
                    candidateScore: 8 * recencyMultiplier,
                    definitionCandidates: &definitionCandidates
                )
            }

            for token in tokenize(note.title) {
                guard isMeaningful(token) else { continue }
                localScores[token, default: 0] += 3
                registerDefinitionCandidate(
                    term: token,
                    note: note,
                    candidateScore: 3 * recencyMultiplier,
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
                    note: note,
                    candidateScore: Double(min(count, 3)) * recencyMultiplier,
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
        note: KnowledgeSourceNote,
        candidateScore: Double,
        definitionCandidates: inout [String: (score: Double, definition: String)]
    ) {
        let definition = bestDefinitionSentence(for: term, in: note)
        guard !definition.isEmpty else { return }
        if let existing = definitionCandidates[term], existing.score >= candidateScore {
            return
        }
        definitionCandidates[term] = (candidateScore, definition)
    }

    private func bestDefinitionSentence(for term: String, in note: KnowledgeSourceNote) -> String {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else { return "" }
        let haystack = note.body.isEmpty ? note.title : note.body
        let sentences = haystack
            .split(whereSeparator: { $0 == "." || $0 == "!" || $0 == "?" || $0 == "\n" })
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        if let match = sentences.first(where: {
            $0.localizedCaseInsensitiveContains(trimmedTerm)
        }) {
            return String(match.prefix(180))
        }

        let snippet = note.body.isEmpty ? note.title : note.body
        return String(snippet.prefix(180)).trimmingCharacters(in: .whitespacesAndNewlines)
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
