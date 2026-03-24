import Foundation

// MARK: - CurriculumSorter

/// Sorts training examples by cognitive complexity before training begins.
///
/// Per ANCHOR 4, Mitigation 2 (Curriculum Learning):
/// - Epoch 1: Simple, highly structured (glossaries, definitions, bullet lists)
/// - Epoch 2: Medium-complexity (explanatory text, how-to guides)
/// - Epoch 3: Complex (multi-hop reasoning, arguments, analysis)
///
/// Rationale: Mimics biological learning; stabilizes gradient descent.
nonisolated struct CurriculumSorter: Sendable {

    // MARK: - Public

    /// Sorts a JSONL file by ascending complexity and writes the result.
    /// Training script reads the sorted JSONL sequentially → natural curriculum.
    func sortByComplexity(inputPath: URL, outputPath: URL) throws {
        let content = try String(contentsOf: inputPath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Score each line
        let scored = lines.map { line -> (line: String, score: Double) in
            let text = extractAnswerText(from: line)
            let score = computeComplexity(text)
            return (line, score)
        }

        // Sort ascending: simple first, complex last
        let sorted = scored.sorted { $0.score < $1.score }

        let output = sorted.map(\.line).joined(separator: "\n")
        try output.write(to: outputPath, atomically: true, encoding: .utf8)
    }

    /// Computes a complexity score for a text example.
    /// Higher score = more complex content.
    func computeComplexity(_ text: String) -> Double {
        guard !text.isEmpty else { return 0 }

        var score: Double = 0

        // Factor 1: Average sentence length (longer sentences = more complex)
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let avgSentenceLength: Double
        if !sentences.isEmpty {
            let totalWords = sentences.reduce(0) { $0 + wordCount($1) }
            avgSentenceLength = Double(totalWords) / Double(sentences.count)
        } else {
            avgSentenceLength = 0
        }
        score += avgSentenceLength / 10.0

        // Factor 2: Clause depth estimate (subordinate conjunctions)
        let clauseMarkers = [
            "because", "although", "whereas", "while", "since",
            "unless", "provided that", "in order to", "so that",
            "even though", "despite", "notwithstanding",
        ]
        let lowerText = text.lowercased()
        let clauseCount = clauseMarkers.reduce(0) { count, marker in
            count + lowerText.components(separatedBy: marker).count - 1
        }
        score += Double(clauseCount)

        // Factor 3: Entity count (proper nouns / capitalized words as proxy)
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        let entityCount = words.filter { word in
            guard let first = word.first else { return false }
            return first.isUppercase && word.count > 1
        }.count
        score += Double(entityCount) / 5.0

        // Factor 4: Multi-hop reasoning cues
        let multiHopCues = [
            "because", "therefore", "which means", "given that",
            "it follows", "consequently", "as a result", "implies",
            "in contrast", "on the other hand", "however", "nevertheless",
            "furthermore", "moreover", "in addition", "similarly",
        ]
        let hasMultiHop = multiHopCues.contains { lowerText.contains($0) }
        if hasMultiHop { score += 1.0 }

        // Factor 5: Answer length
        score += 0.5 * Double(wordCount(text)) / 100.0

        return score
    }

    // MARK: - Helpers

    /// Extracts the assistant's answer text from a JSONL line.
    private func extractAnswerText(from jsonLine: String) -> String {
        guard let data = jsonLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = json["messages"] as? [[String: Any]] else {
            return jsonLine
        }

        // Find the assistant message
        for msg in messages {
            if msg["role"] as? String == "assistant",
               let content = msg["content"] as? String {
                return content
            }
        }

        return jsonLine
    }

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
