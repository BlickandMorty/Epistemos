import Foundation

// MARK: - Evaluation Dataset

struct EvaluationDataset: Sendable {
    /// Questions explicitly answerable from vault (factual QA).
    let directProbes: [DirectProbe]
    /// Questions requiring multi-hop synthesis (vault + world knowledge).
    let indirectProbes: [IndirectProbe]
    /// Partial user writing samples for style completion evaluation.
    let styleHeldOut: [String]

    struct DirectProbe: Sendable {
        let question: String
        let expectedAnswer: String
    }

    struct IndirectProbe: Sendable {
        let question: String
        /// Keywords that should appear in a correct multi-hop response.
        let expectedKeywords: [String]
    }
}

// MARK: - Evaluation Score

nonisolated struct EvaluationScore: Sendable, Codable {
    let directProbingScore: Double    // 0-1: fraction of correct direct answers
    let indirectProbingScore: Double  // 0-1: fraction of correct indirect answers
    let styleScore: Double            // 0-1: BERTScore approximation
    let compositeScore: Double        // weighted combination

    /// Composite: Direct * 0.5 + Indirect * 0.3 + Style * 0.2
    static func compute(direct: Double, indirect: Double, style: Double) -> EvaluationScore {
        EvaluationScore(
            directProbingScore: direct,
            indirectProbingScore: indirect,
            styleScore: style,
            compositeScore: direct * 0.5 + indirect * 0.3 + style * 0.2
        )
    }
}

// MARK: - MetricEvaluator

/// Evaluates trained adapters using the KUP Framework (Direct + Indirect Probing)
/// and stylometric analysis per ANCHOR 5.
///
/// Research paper: "Evaluation and Consumer Quality Bar" section.
/// Standard loss curves DO NOT prove knowledge fusion — must use probing.
///
/// Diagnostic: If model passes DIRECT but fails INDIRECT → mere memorization,
/// NOT genuine knowledge fusion.
actor MetricEvaluator {

    private let inferenceProvider: KFInferenceProvider

    init(inferenceProvider: KFInferenceProvider) {
        self.inferenceProvider = inferenceProvider
    }

    // MARK: - Full Evaluation

    func evaluate(evalData: EvaluationDataset) async -> EvaluationScore {
        async let directScore = evaluateDirectProbing(probes: evalData.directProbes)
        async let indirectScore = evaluateIndirectProbing(probes: evalData.indirectProbes)
        async let styleScore = evaluateStyle(samples: evalData.styleHeldOut)

        let d = await directScore
        let i = await indirectScore
        let s = await styleScore

        return EvaluationScore.compute(direct: d, indirect: i, style: s)
    }

    // MARK: - Direct Probing (KUP Framework)

    /// Ask factual questions explicitly stated in the personal vault.
    /// Pass criterion: model answers correctly without RAG context.
    func evaluateDirectProbing(probes: [EvaluationDataset.DirectProbe]) async -> Double {
        guard !probes.isEmpty else { return 0 }

        var correct = 0
        for probe in probes {
            let prompt = "Answer the following question based on your knowledge. Be concise.\n\nQuestion: \(probe.question)\n\nAnswer:"
            do {
                let response = try await inferenceProvider.generate(
                    prompt: prompt, systemPrompt: nil, maxTokens: 256
                )
                if semanticMatch(response: response, expected: probe.expectedAnswer) {
                    correct += 1
                }
            } catch {
                continue
            }
        }
        return Double(correct) / Double(probes.count)
    }

    // MARK: - Indirect Probing (Multi-hop Reasoning)

    /// Require multi-hop reasoning combining vault facts + pre-trained knowledge.
    /// Pass criterion: model reaches novel conclusion from combined knowledge.
    func evaluateIndirectProbing(probes: [EvaluationDataset.IndirectProbe]) async -> Double {
        guard !probes.isEmpty else { return 0 }

        var correct = 0
        for probe in probes {
            let prompt = "Think through this question step by step.\n\nQuestion: \(probe.question)\n\nAnswer:"
            do {
                let response = try await inferenceProvider.generate(
                    prompt: prompt, systemPrompt: nil, maxTokens: 512
                )
                if keywordMatch(response: response, keywords: probe.expectedKeywords) {
                    correct += 1
                }
            } catch {
                continue
            }
        }
        return Double(correct) / Double(probes.count)
    }

    // MARK: - Style Evaluation

    /// Evaluate generated text vs. known user baseline.
    /// Uses token overlap as a lightweight BERTScore approximation.
    /// Full BERTScore requires an embedding model — scaffold for future.
    func evaluateStyle(samples: [String]) async -> Double {
        guard !samples.isEmpty else { return 0 }

        var totalSimilarity: Double = 0
        for sample in samples {
            // Split sample: first 60% as prompt, last 40% as expected continuation
            let words = sample.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            let splitPoint = Int(Double(words.count) * 0.6)
            guard splitPoint > 0 && splitPoint < words.count else { continue }

            let promptPart = words[..<splitPoint].joined(separator: " ")
            let expectedContinuation = words[splitPoint...].joined(separator: " ")

            let prompt = "Continue the following text in the same style:\n\n\(promptPart)"
            do {
                let response = try await inferenceProvider.generate(
                    prompt: prompt, systemPrompt: nil, maxTokens: 256
                )
                let similarity = tokenOverlapSimilarity(
                    generated: response,
                    reference: expectedContinuation
                )
                totalSimilarity += similarity
            } catch {
                continue
            }
        }
        return totalSimilarity / Double(samples.count)
    }

    // MARK: - Similarity Helpers

    /// Lightweight semantic match: checks if key terms from expected answer
    /// appear in the response. Not a full embedding-based similarity.
    private func semanticMatch(response: String, expected: String) -> Bool {
        let responseWords = Set(
            response.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 3 }
        )
        let expectedWords = expected.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 }

        guard !expectedWords.isEmpty else { return false }

        let matchCount = expectedWords.filter { responseWords.contains($0) }.count
        let matchRatio = Double(matchCount) / Double(expectedWords.count)
        return matchRatio >= 0.4  // 40% keyword overlap threshold
    }

    /// Checks if expected keywords appear in the response (for indirect probing).
    private func keywordMatch(response: String, keywords: [String]) -> Bool {
        guard !keywords.isEmpty else { return false }
        let lower = response.lowercased()
        let matchCount = keywords.filter { lower.contains($0.lowercased()) }.count
        return Double(matchCount) / Double(keywords.count) >= 0.5
    }

    /// Token-overlap similarity as lightweight BERTScore approximation.
    func tokenOverlapSimilarity(generated: String, reference: String) -> Double {
        let genTokens = Set(
            generated.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
        )
        let refTokens = Set(
            reference.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
        )

        guard !genTokens.isEmpty && !refTokens.isEmpty else { return 0 }

        let intersection = genTokens.intersection(refTokens).count
        let precision = Double(intersection) / Double(genTokens.count)
        let recall = Double(intersection) / Double(refTokens.count)

        guard precision + recall > 0 else { return 0 }
        return 2 * precision * recall / (precision + recall)  // F1 score
    }

    // MARK: - Auto-generate Eval Dataset from JSONL

    /// Creates an EvaluationDataset from a held-out JSONL file.
    static func loadEvalDataset(from jsonlPath: URL) throws -> EvaluationDataset {
        let content = try String(contentsOf: jsonlPath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        var directProbes: [EvaluationDataset.DirectProbe] = []
        var styleHeldOut: [String] = []

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let messages = json["messages"] as? [[String: Any]] else { continue }

            let user = messages.first { $0["role"] as? String == "user" }?["content"] as? String ?? ""
            let assistant = messages.first { $0["role"] as? String == "assistant" }?["content"] as? String ?? ""

            guard !user.isEmpty && !assistant.isEmpty else { continue }

            // Classify: if assistant response is personal writing style → style sample
            let lowerAssistant = assistant.lowercased()
            if lowerAssistant.contains("i ") || lowerAssistant.contains("my ") {
                styleHeldOut.append(assistant)
            } else {
                directProbes.append(.init(question: user, expectedAnswer: assistant))
            }
        }

        return EvaluationDataset(
            directProbes: directProbes,
            indirectProbes: [],  // Indirect probes need manual curation
            styleHeldOut: styleHeldOut
        )
    }
}
