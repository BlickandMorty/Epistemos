import Foundation

// MARK: - Inference Provider Protocol

/// Lightweight protocol for on-device text generation. Decouples synthetic
/// data generation from the specific inference service (MLXInferenceService).
/// Enables mock injection for testing.
protocol KFInferenceProvider: Sendable {
    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String
}

// MARK: - Types

struct GeneratedPair: Sendable {
    let question: String
    let answer: String
    let qualityScore: Int
    let sourceChunkId: UUID
    let sourceChunkText: String
}

// MARK: - InstructionBacktranslator

/// Implements the three-step Self-Instruct / Instruction Backtranslation loop:
/// 1. Query Generation: model reads chunk → generates hypothetical questions
/// 2. Response Rewriting: model rewrites raw facts into clean instruction-response pairs
/// 3. Quality Scoring: self-curation 1-5 scale, discard < 3
///
/// Research paper: "Synthetic Data Generation Pipeline" section.
/// 3B-4B models match 70B teacher quality with constrained prompt templates.
actor InstructionBacktranslator {

    private let inferenceProvider: KFInferenceProvider
    private let maxQuestionsPerChunk: Int

    init(inferenceProvider: KFInferenceProvider, maxQuestionsPerChunk: Int = 3) {
        self.inferenceProvider = inferenceProvider
        self.maxQuestionsPerChunk = maxQuestionsPerChunk
    }

    /// Run the full 3-step backtranslation on a single chunk.
    /// Returns 0 to `maxQuestionsPerChunk` quality-filtered pairs.
    func backtranslate(chunk: TextChunk) async throws -> [GeneratedPair] {
        // Step A: Generate questions
        let questions = try await generateQuestions(from: chunk.text)
        guard !questions.isEmpty else { return [] }

        var pairs: [GeneratedPair] = []
        pairs.reserveCapacity(questions.count)

        for question in questions.prefix(maxQuestionsPerChunk) {
            // Step B: Rewrite response
            let answer: String
            do {
                answer = try await rewriteResponse(question: question, passage: chunk.text)
            } catch {
                continue  // Skip this question on inference failure
            }
            guard !answer.isEmpty else { continue }

            // Step C: Quality scoring
            let score: Int
            do {
                score = try await scoreQuality(question: question, answer: answer)
            } catch {
                score = 1  // Default to discard on scoring failure
            }

            pairs.append(GeneratedPair(
                question: question,
                answer: answer,
                qualityScore: score,
                sourceChunkId: chunk.id,
                sourceChunkText: chunk.text
            ))
        }

        return pairs
    }

    // MARK: - Step A: Query Generation

    private func generateQuestions(from passage: String) async throws -> [String] {
        let prompt = """
        Generate \(maxQuestionsPerChunk) questions that the following passage answers. \
        Output ONLY a numbered list. No preamble or explanation.

        Passage:
        \(passage.prefix(1500))

        Questions:
        """

        let response = try await inferenceProvider.generate(
            prompt: prompt,
            systemPrompt: "You generate training data questions. Output only numbered lists.",
            maxTokens: 512
        )

        return parseNumberedList(response)
    }

    // MARK: - Step B: Response Rewriting

    private func rewriteResponse(question: String, passage: String) async throws -> String {
        let prompt = """
        Below is a passage and a question it answers. Rewrite the passage as a \
        clean, comprehensive answer to the question. Write in the first person if \
        the passage is personal writing, otherwise use neutral expository prose. \
        Use clear markdown formatting. No preamble.

        QUESTION: \(question)
        PASSAGE: \(passage)

        ANSWER:
        """

        let response = try await inferenceProvider.generate(
            prompt: prompt,
            systemPrompt: nil,
            maxTokens: 1024
        )

        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Step C: Quality Scoring

    private func scoreQuality(question: String, answer: String) async throws -> Int {
        let prompt = """
        Rate this QA pair 1-5. Reply with ONLY a number.
        Q: \(question.prefix(200))
        A: \(answer.prefix(300))
        Rating:
        """

        let response = try await inferenceProvider.generate(
            prompt: prompt,
            systemPrompt: "You are a rating tool. Output only a single digit 1-5.",
            maxTokens: 16
        )

        return parseScore(from: response)
    }

    /// Resilient score parser: extracts first digit 1-5 from model output,
    /// which may contain thinking tokens, XML tags, or verbose preamble.
    /// Defaults to 3 (pass) if no digit found — avoids discarding all pairs
    /// when the model returns non-numeric responses.
    private func parseScore(from response: String) -> Int {
        // Strip common wrapper patterns (thinking tags, XML, quotes)
        let cleaned = response
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Try exact integer first
        if let score = Int(cleaned), score >= 1, score <= 5 {
            return score
        }

        // Scan for any digit 1-5
        for char in cleaned {
            if let digit = char.wholeNumberValue, digit >= 1, digit <= 5 {
                return digit
            }
        }

        // Default to 3 (pass) rather than 1 (discard) — real models often
        // produce verbose output even when asked for a number.
        return 3
    }

    // MARK: - Helpers

    /// Parses a numbered list from model output. Handles thinking tags, XML wrappers,
    /// and various list formats (numbered, bulleted, plain lines with question marks).
    private func parseNumberedList(_ text: String) -> [String] {
        // Strip thinking tags and XML wrappers
        let cleaned = text
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        let lines = cleaned.components(separatedBy: .newlines)
        var results: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Match patterns: "1. ", "1) ", "- ", "* ", or plain lines with "?"
            var question = trimmed
            if let range = question.range(of: #"^\d+[\.\)]\s*"#, options: .regularExpression) {
                question = String(question[range.upperBound...])
            } else if question.hasPrefix("- ") || question.hasPrefix("* ") {
                question = String(question.dropFirst(2))
            } else if question.contains("?") {
                // Accept plain lines that look like questions
            } else {
                continue
            }

            question = question.trimmingCharacters(in: .whitespaces)
            if !question.isEmpty && question.count > 10 {
                results.append(question)
            }
        }

        // If parsing found nothing, try splitting on "?" as last resort
        if results.isEmpty {
            let parts = cleaned.components(separatedBy: "?")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count > 10 }
                .map { $0 + "?" }
            results = Array(parts.prefix(maxQuestionsPerChunk))
        }

        return results
    }
}
