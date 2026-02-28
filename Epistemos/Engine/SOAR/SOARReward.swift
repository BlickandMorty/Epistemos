import Foundation
import os

// MARK: - SOAR Reward
// Grounded reward signal matching lib/engine/soar/reward.ts

nonisolated enum SOARRewardCalculator {

    // MARK: - Compute Reward

    static func computeReward(
        baseline: BaselineSignals,
        current: BaselineSignals,
        weights: RewardWeights
    ) -> SOARReward {
        let deltaConfidence = current.confidence - baseline.confidence
        let deltaEntropy = baseline.entropy - current.entropy
        let deltaDissonance = baseline.dissonance - current.dissonance
        let deltaHealth = current.healthScore - baseline.healthScore

        let composite =
            weights.confidence * deltaConfidence +
            weights.entropy * deltaEntropy +
            weights.dissonance * deltaDissonance +
            weights.health * deltaHealth

        return SOARReward(
            deltaConfidence: deltaConfidence,
            deltaEntropy: -deltaEntropy,
            deltaDissonance: -deltaDissonance,
            deltaHealth: deltaHealth,
            composite: composite,
            improved: composite > 0.01
        )
    }

    // MARK: - Assess Structural Quality

    static func assessStructuralQuality(
        stoneQuestion: String,
        targetQuery: String
    ) -> Double {
        var quality = 0.5

        let wordCount = stoneQuestion.split(separator: " ").count
        if wordCount >= 15 && wordCount <= 80 {
            quality += 0.15
        } else if wordCount < 8 || wordCount > 120 {
            quality -= 0.15
        }

        let trimmed = stoneQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("?") {
            quality += 0.1
        }
        if trimmed.lowercased().range(of: "^(what|how|why|when|where|which|can|does|is|are|should|would|could)", options: .regularExpression) != nil {
            quality += 0.05
        }

        let hasSpecificTerms = stoneQuestion.range(of: "[A-Z][a-z]{2,}|[a-z]+(?:tion|ment|ness|ity|ism|ics|ogy|phy)", options: .regularExpression) != nil
        if hasSpecificTerms {
            quality += 0.1
        }

        let overlap = computeTokenOverlap(stoneQuestion, targetQuery)
        if overlap < 0.3 {
            quality += 0.1
        } else if overlap > 0.7 {
            quality -= 0.2
        }

        return max(0, min(1, quality))
    }

    // MARK: - Token Overlap (Jaccard-like)

    private static func computeTokenOverlap(_ a: String, _ b: String) -> Double {
        let tokensA = Set(a.lowercased().split(separator: " ").filter { $0.count > 3 }.map { String($0) })
        let tokensB = Set(b.lowercased().split(separator: " ").filter { $0.count > 3 }.map { String($0) })

        if tokensA.isEmpty || tokensB.isEmpty { return 0 }

        let intersection = tokensA.intersection(tokensB).count
        let union = tokensA.union(tokensB).count
        return union > 0 ? Double(intersection) / Double(union) : 0
    }
}

// MARK: - Contradiction Detection

enum ContradictionDetector {

    static func scanForContradictions(
        analysis: String,
        maxClaims: Int = 20,
        llmService: LLMService? = nil
    ) async -> ContradictionScan {
        let startTime = Date()
        let claims = extractClaims(from: analysis, maxClaims: maxClaims)

        if let llm = llmService {
            do {
                return try await scanWithLLM(llm: llm, claims: claims, startTime: startTime)
            } catch {
                Log.engine.warning("⚠️ SOAR LLM reward scan failed, using heuristic: \(error.localizedDescription, privacy: .public)")
            }
        }

        return heuristicScan(claims: claims, startTime: startTime)
    }

    private static func extractClaims(from analysis: String, maxClaims: Int) -> [String] {
        let sentences = analysis
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 20 }

        var claims: [String] = []
        for sentence in sentences {
            if sentence.contains("[DATA]") || sentence.contains("[MODEL]") || sentence.contains("[UNCERTAIN]") || sentence.contains("[CONFLICT]") {
                let clean = sentence
                    .replacingOccurrences(of: "\\[DATA\\]", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\[MODEL\\]", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\[UNCERTAIN\\]", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\[CONFLICT\\]", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if !clean.isEmpty { claims.append(clean) }
            }
        }

        for sentence in sentences where !claims.contains(sentence) && sentence.count > 30 {
            claims.append(sentence)
        }

        return Array(claims.prefix(maxClaims))
    }

    private static func scanWithLLM(
        llm: LLMService,
        claims: [String],
        startTime: Date
    ) async throws -> ContradictionScan {
        let systemPrompt = """
        You are a logical analysis engine. Identify contradictions between pairs of claims.
        Be conservative — only flag genuine contradictions, not minor disagreements.
        """

        let numberedClaims = claims.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
        let userPrompt = """
        Analyze these claims for contradictions:

        \(numberedClaims)

        Return format:
        CONTRADICTION 1:
        CLAIM A: <text>
        CLAIM B: <text>
        CONFIDENCE: <0-1>
        TYPE: <factual|logical|temporal|scope|methodological>
        EXPLANATION: <why>

        If none: "NO CONTRADICTIONS"
        """

        let response = try await llm.generate(prompt: userPrompt, systemPrompt: systemPrompt, maxTokens: 1500)
        let contradictions = parseContradictions(from: response)
        let computedDissonance = min(0.95, Double(contradictions.count) / Double(max(claims.count / 4, 1)) * 0.5)

        return ContradictionScan(
            totalClaims: claims.count,
            totalComparisons: (claims.count * (claims.count - 1)) / 2,
            contradictions: contradictions,
            computedDissonance: computedDissonance,
            durationMs: Date().timeIntervalSince(startTime) * 1000
        )
    }

    private static func parseContradictions(from response: String) -> [Contradiction] {
        var contradictions: [Contradiction] = []
        let pattern = "CONTRADICTION\\s*\\d*:"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }

        let matches = regex.matches(in: response, range: NSRange(location: 0, length: response.utf16.count))

        for (index, match) in matches.enumerated() {
            let start = match.range.location
            let end = index + 1 < matches.count ? matches[index + 1].range.location : response.utf16.count

            guard let range = Range(NSRange(location: start, length: end - start), in: response) else { continue }
            let block = String(response[range])

            if let claimA = extractField(from: block, field: "CLAIM A"),
               let claimB = extractField(from: block, field: "CLAIM B"),
               let confidenceStr = extractField(from: block, field: "CONFIDENCE"),
               let confidence = Double(confidenceStr.trimmingCharacters(in: .whitespaces)),
               let typeStr = extractField(from: block, field: "TYPE"),
               let type = ContradictionType(rawValue: typeStr.lowercased().trimmingCharacters(in: .whitespaces)),
               let explanation = extractField(from: block, field: "EXPLANATION") {
                contradictions.append(Contradiction(
                    id: "contradiction_\(UUID().uuidString)",
                    claimA: claimA, sourceA: "analysis",
                    claimB: claimB, sourceB: "analysis",
                    contradictionConfidence: confidence,
                    type: type, explanation: explanation
                ))
            }
        }
        return contradictions
    }

    private static func extractField(from text: String, field: String) -> String? {
        let pattern = "\(field):\\s*(.+?)(?=\\n[A-Z]|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(location: 0, length: text.utf16.count)
        if let match = regex.firstMatch(in: text, range: range),
           let valueRange = Range(match.range(at: 1), in: text) {
            return String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func heuristicScan(claims: [String], startTime: Date) -> ContradictionScan {
        var contradictions: [Contradiction] = []

        let negationIndicators = ["not", "no", "never", "none", "cannot", "impossible", "false"]
        let affirmationIndicators = ["is", "are", "does", "can", "will", "always", "true"]

        for i in 0..<claims.count {
            for j in (i+1)..<claims.count {
                let claimA = claims[i].lowercased()
                let claimB = claims[j].lowercased()

                let aHasNeg = negationIndicators.contains { claimA.contains($0) }
                let bHasNeg = negationIndicators.contains { claimB.contains($0) }
                let aHasAff = affirmationIndicators.contains { claimA.contains($0) }
                let bHasAff = affirmationIndicators.contains { claimB.contains($0) }

                let tokensA = Set(claimA.split(separator: " ").filter { $0.count > 4 })
                let tokensB = Set(claimB.split(separator: " ").filter { $0.count > 4 })
                let overlap = Double(tokensA.intersection(tokensB).count) / Double(max(tokensA.union(tokensB).count, 1))

                if overlap > 0.5 && ((aHasNeg && bHasAff) || (aHasAff && bHasNeg)) {
                    contradictions.append(Contradiction(
                        id: "contradiction_\(UUID().uuidString)",
                        claimA: claims[i], sourceA: "analysis",
                        claimB: claims[j], sourceB: "analysis",
                        contradictionConfidence: 0.6,
                        type: .logical, explanation: "Claims have similar content but opposite polarity"
                    ))
                }
            }
        }

        let computedDissonance = min(0.95, Double(contradictions.count) / Double(max(claims.count / 4, 1)) * 0.5)
        return ContradictionScan(
            totalClaims: claims.count,
            totalComparisons: (claims.count * (claims.count - 1)) / 2,
            contradictions: contradictions,
            computedDissonance: computedDissonance,
            durationMs: Date().timeIntervalSince(startTime) * 1000
        )
    }
}
