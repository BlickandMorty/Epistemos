import Foundation
import CryptoKit

// MARK: - Types

enum TrainingPairCategory: String, Codable, Sendable {
    case knowledge
    case style
    case tool
}

struct TrainingPair: Sendable, Codable {
    let messages: [ChatMessage]
    let category: TrainingPairCategory
    let qualityScore: Int
    let sourceChunkId: String

    struct ChatMessage: Sendable, Codable {
        let role: String
        let content: String
    }
}

struct CurationResult: Sendable {
    let accepted: [TrainingPair]
    let evalHeldOut: [TrainingPair]
    let discardedCount: Int
    let duplicateCount: Int
    let categoryBreakdown: [TrainingPairCategory: Int]
}

// MARK: - QualityCurator

/// Applies quality filtering, classification, deduplication, and eval holdout
/// to generated pairs from InstructionBacktranslator.
///
/// Research paper: Self-curation quality threshold discard < 3.
/// Classification: knowledge / style / tool by content heuristics.
/// 10% held out for evaluation (Phase 6 MetricEvaluator).
nonisolated struct QualityCurator: Sendable {

    let qualityThreshold: Int
    let evalHoldoutRatio: Double

    init(qualityThreshold: Int = 3, evalHoldoutRatio: Double = 0.10) {
        self.qualityThreshold = qualityThreshold
        self.evalHoldoutRatio = evalHoldoutRatio
    }

    // MARK: - Public

    @MainActor func curate(pairs: [GeneratedPair]) -> CurationResult {
        // 1. Quality filter: discard < threshold (LLM self-score)
        let qualityFiltered = pairs.filter { $0.qualityScore >= qualityThreshold }
        var discardedCount = pairs.count - qualityFiltered.count

        // 1b. Rust-side quality scoring (text characteristics check)
        let rustFiltered = qualityFiltered.filter { pair in
            let result = scoreTrainingPair(instruction: pair.question, response: pair.answer, minScore: 0.5)
            return result.passes
        }
        discardedCount += qualityFiltered.count - rustFiltered.count

        // 2. Exact dedup by SHA-256 hash of (question, answer)
        var seenHashes: Set<String> = []
        var exactDeduped: [GeneratedPair] = []
        exactDeduped.reserveCapacity(rustFiltered.count)
        var duplicateCount = 0

        for pair in rustFiltered {
            let hash = hashPair(question: pair.question, answer: pair.answer)
            if seenHashes.insert(hash).inserted {
                exactDeduped.append(pair)
            } else {
                duplicateCount += 1
            }
        }

        // 2b. MinHash near-duplicate detection via Rust FFI
        let deduplicated: [GeneratedPair]
        if exactDeduped.count > 1 {
            let texts = exactDeduped.map { $0.question + " ||| " + $0.answer }
            if let textsJson = try? JSONEncoder().encode(texts),
               let textsStr = String(data: textsJson, encoding: .utf8) {
                let dedupResult = dedupTexts(textsJson: textsStr, threshold: 0.8)
                if let indicesData = dedupResult.keepIndicesJson.data(using: .utf8),
                   let keepIndices = try? JSONDecoder().decode([Int].self, from: indicesData) {
                    deduplicated = keepIndices.compactMap { idx in
                        idx < exactDeduped.count ? exactDeduped[idx] : nil
                    }
                    duplicateCount += Int(dedupResult.duplicateCount)
                } else {
                    deduplicated = exactDeduped
                }
            } else {
                deduplicated = exactDeduped
            }
        } else {
            deduplicated = exactDeduped
        }

        // 3. Classify each pair
        let classified = deduplicated.map { pair -> TrainingPair in
            let category = classifyPair(question: pair.question, answer: pair.answer)
            return TrainingPair(
                messages: [
                    .init(role: "system", content: systemPrompt(for: category)),
                    .init(role: "user", content: pair.question),
                    .init(role: "assistant", content: pair.answer)
                ],
                category: category,
                qualityScore: pair.qualityScore,
                sourceChunkId: pair.sourceChunkId.uuidString
            )
        }

        // 4. Split into training and eval holdout (10%)
        let shuffled = classified.shuffled()
        let evalCount = max(1, Int(Double(shuffled.count) * evalHoldoutRatio))
        let evalSet: [TrainingPair]
        let trainingSet: [TrainingPair]

        if shuffled.count > 1 {
            evalSet = Array(shuffled.prefix(evalCount))
            trainingSet = Array(shuffled.dropFirst(evalCount))
        } else {
            evalSet = []
            trainingSet = shuffled
        }

        // 5. Category breakdown
        var breakdown: [TrainingPairCategory: Int] = [.knowledge: 0, .style: 0, .tool: 0]
        for pair in trainingSet {
            breakdown[pair.category, default: 0] += 1
        }

        return CurationResult(
            accepted: trainingSet,
            evalHeldOut: evalSet,
            discardedCount: discardedCount,
            duplicateCount: duplicateCount,
            categoryBreakdown: breakdown
        )
    }

    // MARK: - Classification

    /// Classifies a QA pair into knowledge/style/tool by content heuristics.
    /// - Personal pronouns ("I ", "my ", "we ") → style
    /// - API/function keywords → tool
    /// - Otherwise → knowledge
    func classifyPair(question: String, answer: String) -> TrainingPairCategory {
        let combined = (question + " " + answer).lowercased()

        // Tool detection: API/function/code patterns
        let toolKeywords = [
            "function", "method", "api", "endpoint", "parameter",
            "argument", "return type", "class ", "struct ", "enum ",
            "import ", "library", "framework", "package", "module",
            "command", "cli ", "flag", "option", "config",
            "http", "rest", "graphql", "sdk", "interface"
        ]
        let toolHits = toolKeywords.filter { combined.contains($0) }.count
        if toolHits >= 2 { return .tool }

        // Style detection: personal writing cues
        let stylePatterns = [
            "i ", "i'm", "i've", "i'd", "my ", "we ", "we're",
            "our ", "me ", "myself", "personally", "in my experience",
            "i think", "i feel", "i believe", "journal", "diary",
            "today i", "yesterday", "this morning", "tonight"
        ]
        let styleHits = stylePatterns.filter { combined.contains($0) }.count
        if styleHits >= 2 { return .style }

        return .knowledge
    }

    // MARK: - JSONL Writing

    /// Writes classified training pairs to separate JSONL files by category.
    /// Returns paths to created files.
    func writeJSONL(
        pairs: [TrainingPair],
        outputDirectory: URL,
        timestamp: String
    ) throws -> [TrainingPairCategory: URL] {
        let fm = FileManager.default
        try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        var paths: [TrainingPairCategory: URL] = [:]

        for category in TrainingPairCategory.allCases {
            let categoryPairs = pairs.filter { $0.category == category }
            guard !categoryPairs.isEmpty else { continue }

            let filename = "\(category.rawValue)_pairs_\(timestamp).jsonl"
            let fileURL = outputDirectory.appendingPathComponent(filename)

            // Write mlx-lm compatible JSONL: {"messages": [...]}
            let lines = try categoryPairs.map { pair -> String in
                let mlxFormat = MLXTrainingLine(messages: pair.messages.map {
                    .init(role: $0.role, content: $0.content)
                })
                let data = try encoder.encode(mlxFormat)
                return String(data: data, encoding: .utf8)!
            }

            try lines.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
            paths[category] = fileURL
        }

        return paths
    }

    /// Writes eval holdout set to a separate JSONL.
    func writeEvalJSONL(pairs: [TrainingPair], outputDirectory: URL, timestamp: String) throws -> URL? {
        guard !pairs.isEmpty else { return nil }
        let fm = FileManager.default
        try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let filename = "eval_\(timestamp).jsonl"
        let fileURL = outputDirectory.appendingPathComponent(filename)

        let lines = try pairs.map { pair -> String in
            let mlxFormat = MLXTrainingLine(messages: pair.messages.map {
                .init(role: $0.role, content: $0.content)
            })
            let data = try encoder.encode(mlxFormat)
            return String(data: data, encoding: .utf8)!
        }

        try lines.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    // MARK: - Helpers

    private func hashPair(question: String, answer: String) -> String {
        let input = question + "|||" + answer
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func systemPrompt(for category: TrainingPairCategory) -> String {
        switch category {
        case .knowledge:
            return "You are a knowledgeable assistant that provides accurate, detailed answers based on the user's personal knowledge base."
        case .style:
            return "You are a writing assistant that matches the user's personal writing style, tone, and voice."
        case .tool:
            return "You are a technical assistant that provides accurate guidance on tools, APIs, and software development workflows."
        }
    }
}

// MARK: - MLX-Compatible JSONL Format

private nonisolated struct MLXTrainingLine: Codable, Sendable {
    let messages: [MLXMessage]

    nonisolated struct MLXMessage: Codable, Sendable {
        let role: String
        let content: String
    }
}

// MARK: - CaseIterable Conformance

extension TrainingPairCategory: CaseIterable {}
