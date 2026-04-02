import Foundation

nonisolated struct KnowledgeSourceNote: Sendable, Equatable {
    let id: String
    let title: String
    let body: String
    let tags: [String]
    let updatedAt: Date
    let createdAt: Date
}

nonisolated struct ModelVaultMetadata: Codable, Sendable, Equatable {
    let modelID: String
    let displayName: String
    let compiledAt: Date
    let noteCount: Int
    let conceptCount: Int
    let activeNoteCount: Int
    let tokenEstimate: Int
}

nonisolated struct CompiledModelVault: Sendable, Equatable {
    let modelID: String
    let displayName: String
    let knowledgeProfile: String
    let conceptIndex: String
    let activeContext: String
    let instructions: String?
    let metadata: ModelVaultMetadata
}

nonisolated struct CloudKnowledgeCompiler: Sendable {
    private let nowProvider: @Sendable () -> Date
    private let calendar: Calendar
    private let activeWindowDays: Int
    private let conceptLimit: Int
    private let conceptRanker: ConceptRanker
    private let styleAnalyzer: StyleAnalyzer

    init(
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        calendar: Calendar = .current,
        activeWindowDays: Int = 7,
        conceptLimit: Int = 60,
        conceptRanker: ConceptRanker? = nil,
        styleAnalyzer: StyleAnalyzer = StyleAnalyzer()
    ) {
        self.nowProvider = nowProvider
        self.calendar = calendar
        self.activeWindowDays = activeWindowDays
        self.conceptLimit = conceptLimit
        self.conceptRanker = conceptRanker ?? ConceptRanker(nowProvider: nowProvider)
        self.styleAnalyzer = styleAnalyzer
    }

    func compile(
        modelID: String,
        displayName: String,
        notes: [KnowledgeSourceNote],
        recentChats: [String],
        instructions: String?
    ) -> CompiledModelVault {
        let now = nowProvider()
        let rankedConcepts = conceptRanker.rankConcepts(notes: notes, limit: conceptLimit)
        let style = styleAnalyzer.analyze(notes: notes)
        let activeNotes = notes
            .filter { now.timeIntervalSince($0.updatedAt) <= Double(activeWindowDays) * 86_400 }
            .sorted { $0.updatedAt > $1.updatedAt }
        let knowledgeProfile = renderKnowledgeProfile(
            notes: notes,
            rankedConcepts: rankedConcepts,
            style: style
        )
        let conceptIndex = renderConceptIndex(rankedConcepts)
        let activeContext = renderActiveContext(
            activeNotes: activeNotes,
            recentChats: recentChats
        )
        let metadata = ModelVaultMetadata(
            modelID: modelID,
            displayName: displayName,
            compiledAt: now,
            noteCount: notes.count,
            conceptCount: rankedConcepts.count,
            activeNoteCount: activeNotes.count,
            tokenEstimate: estimateTokenCount(
                strings: [knowledgeProfile, conceptIndex, activeContext, instructions ?? ""]
            )
        )

        return CompiledModelVault(
            modelID: modelID,
            displayName: displayName,
            knowledgeProfile: knowledgeProfile,
            conceptIndex: conceptIndex,
            activeContext: activeContext,
            instructions: normalizedInstructions(instructions),
            metadata: metadata
        )
    }

    private func renderKnowledgeProfile(
        notes: [KnowledgeSourceNote],
        rankedConcepts: [RankedConcept],
        style: StyleAnalysis
    ) -> String {
        var parts: [String] = []
        parts.append("## Domain Map")
        parts.append(contentsOf: renderDomainMap(notes: notes, rankedConcepts: rankedConcepts))
        parts.append("")
        parts.append("## Entity Graph Summary")
        parts.append(contentsOf: renderEntityGraphSummary(notes: notes, rankedConcepts: rankedConcepts))
        parts.append("")
        parts.append("## Writing Style Fingerprint")
        parts.append("- Tone: \(style.toneDescriptor)")
        parts.append("- Average sentence length: \(Int(style.averageSentenceLength.rounded())) words")
        parts.append("- Vocabulary richness: \(String(format: "%.2f", style.vocabularyRichness))")
        parts.append(
            "- Dominant structures: \(style.dominantStructures.isEmpty ? "Mostly plain paragraphs" : style.dominantStructures.joined(separator: ", "))"
        )
        if !style.commonPhrases.isEmpty {
            parts.append("- Common phrases: \(style.commonPhrases.joined(separator: ", "))")
        }
        parts.append("")
        parts.append("## Terminology Glossary")
        if rankedConcepts.isEmpty {
            parts.append("- No repeated concepts detected yet.")
        } else {
            for concept in rankedConcepts.prefix(8) {
                let definition = concept.definition.isEmpty ? "Frequently referenced in the vault." : concept.definition
                parts.append("- \(concept.term): \(definition)")
            }
        }

        return parts.joined(separator: "\n")
    }

    private func renderConceptIndex(_ rankedConcepts: [RankedConcept]) -> String {
        var parts: [String] = []
        parts.append("## Concept Index")
        if rankedConcepts.isEmpty {
            parts.append("- No concepts compiled yet.")
            return parts.joined(separator: "\n")
        }

        for (index, concept) in rankedConcepts.enumerated() {
            let definition = concept.definition.isEmpty ? "Frequently referenced in the vault." : concept.definition
            parts.append(
                "\(index + 1). \(concept.term) — \(definition) (score: \(String(format: "%.1f", concept.score)), notes: \(concept.noteCount))"
            )
        }
        return parts.joined(separator: "\n")
    }

    private func renderActiveContext(
        activeNotes: [KnowledgeSourceNote],
        recentChats: [String]
    ) -> String {
        var parts: [String] = []
        parts.append("## Active Context")
        parts.append("### Recent Notes")
        if activeNotes.isEmpty {
            parts.append("- No notes were updated in the last \(activeWindowDays) days.")
        } else {
            for note in activeNotes.prefix(10) {
                parts.append(
                    "- \(note.title) (\(Self.isoDateString(note.updatedAt))): \(snippet(from: note.body))"
                )
            }
        }
        parts.append("")
        parts.append("### Recent Chats")
        if recentChats.isEmpty {
            parts.append("- No recent chat summaries captured.")
        } else {
            for chat in recentChats.prefix(8) {
                parts.append("- \(chat.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        return parts.joined(separator: "\n")
    }

    private func renderDomainMap(
        notes: [KnowledgeSourceNote],
        rankedConcepts: [RankedConcept]
    ) -> [String] {
        var topics: [(term: String, count: Int, lastUpdated: Date)] = []
        var buckets: [String: (count: Int, lastUpdated: Date)] = [:]

        for note in notes {
            for tag in note.tags {
                let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !normalized.isEmpty else { continue }
                if let existing = buckets[normalized] {
                    buckets[normalized] = (
                        existing.count + 1,
                        max(existing.lastUpdated, note.updatedAt)
                    )
                } else {
                    buckets[normalized] = (1, note.updatedAt)
                }
            }
        }

        if buckets.isEmpty {
            topics = rankedConcepts.prefix(8).map {
                ($0.term, $0.noteCount, $0.lastUpdatedAt)
            }
        } else {
            topics = buckets.map { ($0.key, $0.value.count, $0.value.lastUpdated) }
                .sorted {
                    if $0.count == $1.count {
                        return $0.term < $1.term
                    }
                    return $0.count > $1.count
                }
        }

        guard !topics.isEmpty else {
            return ["- No topic clusters compiled yet."]
        }

        return topics.prefix(8).map {
            "- \($0.term) (\($0.count) note\($0.count == 1 ? "" : "s"), last updated \(Self.isoDateString($0.lastUpdated)))"
        }
    }

    private func renderEntityGraphSummary(
        notes: [KnowledgeSourceNote],
        rankedConcepts: [RankedConcept]
    ) -> [String] {
        var pairCounts: [String: Int] = [:]

        for note in notes {
            let relatedTerms = Array(Set(note.tags.map { $0.lowercased() })).sorted()
            guard relatedTerms.count >= 2 else { continue }
            for index in 0..<(relatedTerms.count - 1) {
                for otherIndex in (index + 1)..<relatedTerms.count {
                    let key = "\(relatedTerms[index])|\(relatedTerms[otherIndex])"
                    pairCounts[key, default: 0] += 1
                }
            }
        }

        if pairCounts.isEmpty, rankedConcepts.count >= 2 {
            return rankedConcepts.prefix(3).enumerated().map { index, concept in
                let neighbors = rankedConcepts
                    .dropFirst(index + 1)
                    .prefix(2)
                    .map(\.term)
                    .joined(separator: ", ")
                return "- \(concept.term) is frequently discussed alongside \(neighbors)."
            }
        }

        let sortedPairs = pairCounts
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }
                return $0.value > $1.value
            }
            .prefix(5)

        return sortedPairs.map { pair, count in
            let terms = pair.components(separatedBy: "|")
            return "- \(terms.joined(separator: " ↔ ")) co-occurs in \(count) note\(count == 1 ? "" : "s")."
        }
    }

    private func estimateTokenCount(strings: [String]) -> Int {
        let wordCount = strings
            .flatMap { $0.split(whereSeparator: \.isWhitespace) }
            .count
        return Int((Double(wordCount) * 1.33).rounded(.up))
    }

    private func normalizedInstructions(_ instructions: String?) -> String? {
        guard let instructions else { return nil }
        let trimmed = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func snippet(from body: String) -> String {
        body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(180)
            .description
    }

    private static func isoDateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }
}
