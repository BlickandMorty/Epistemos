import Foundation

nonisolated struct StyleAnalysis: Sendable, Equatable {
    let averageSentenceLength: Double
    let vocabularyRichness: Double
    let dominantStructures: [String]
    let commonPhrases: [String]
    let toneDescriptor: String
}

nonisolated struct StyleAnalyzer: Sendable {
    func analyze(notes: [KnowledgeSourceNote]) -> StyleAnalysis {
        let joinedBodies = notes.map(\.body).joined(separator: "\n")
        let sentenceLengths = sentenceWordCounts(in: joinedBodies)
        let tokens = tokenize(joinedBodies)
        let uniqueTokenCount = Set(tokens).count
        let vocabularyRichness = tokens.isEmpty ? 0 : Double(uniqueTokenCount) / Double(tokens.count)
        let averageSentenceLength = sentenceLengths.isEmpty
            ? 0
            : sentenceLengths.reduce(0, +) / Double(sentenceLengths.count)

        let structureCounts: [(String, Int)] = [
            ("Headings", joinedBodies.split(separator: "\n").filter { $0.hasPrefix("#") }.count),
            ("Lists", joinedBodies.split(separator: "\n").filter {
                let trimmed = $0.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("- ")
                    || trimmed.hasPrefix("* ")
                    || trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil
            }.count),
            ("Block Quotes", joinedBodies.split(separator: "\n").filter {
                $0.trimmingCharacters(in: .whitespaces).hasPrefix(">")
            }.count),
            ("Code Fences", joinedBodies.components(separatedBy: "```").count / 2),
        ]

        let dominantStructures = structureCounts
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map(\.0)

        let commonPhrases = mostCommonPhrases(tokens: tokens, limit: 3)

        let toneDescriptor: String
        if averageSentenceLength >= 18 || vocabularyRichness >= 0.45 {
            toneDescriptor = "Dense and technical"
        } else if dominantStructures.contains("Lists") || dominantStructures.contains("Headings") {
            toneDescriptor = "Direct and structured"
        } else {
            toneDescriptor = "Conversational and compact"
        }

        return StyleAnalysis(
            averageSentenceLength: averageSentenceLength,
            vocabularyRichness: vocabularyRichness,
            dominantStructures: dominantStructures,
            commonPhrases: commonPhrases,
            toneDescriptor: toneDescriptor
        )
    }

    private func sentenceWordCounts(in text: String) -> [Double] {
        text
            .split(whereSeparator: { $0 == "." || $0 == "!" || $0 == "?" || $0 == "\n" })
            .map { sentence in
                Double(tokenize(String(sentence)).count)
            }
            .filter { $0 > 0 }
    }

    private func mostCommonPhrases(tokens: [String], limit: Int) -> [String] {
        guard tokens.count >= 2, limit > 0 else { return [] }

        var counts: [String: Int] = [:]
        for index in 0..<(tokens.count - 1) {
            let first = tokens[index]
            let second = tokens[index + 1]
            if Self.stopWords.contains(first) || Self.stopWords.contains(second) {
                continue
            }
            let phrase = "\(first) \(second)"
            counts[phrase, default: 0] += 1
        }

        return counts
            .filter { $0.value > 1 }
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }
                return $0.value > $1.value
            }
            .prefix(limit)
            .map(\.key)
    }

    private func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" })
            .map(String.init)
            .filter { $0.count >= 2 }
    }

    private static let stopWords: Set<String> = [
        "about", "after", "again", "also", "and", "are", "because", "been", "being",
        "between", "both", "but", "can", "could", "does", "each", "from", "have",
        "into", "just", "more", "most", "note", "notes", "other", "same", "should",
        "some", "such", "than", "that", "their", "them", "there", "these", "they",
        "this", "those", "through", "want", "what", "when", "which", "with", "would",
        "your",
    ]
}
