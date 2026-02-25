import Foundation
import os

// MARK: - SOAR Student
// Progressive reasoner matching lib/engine/soar/student.ts

nonisolated enum SOARStudent {

    // MARK: - Attempt Stepping Stone

    static func attemptStone(
        stone: SteppingStone,
        previousAttempts: [StoneAttempt],
        targetQuery: String,
        llmService: LLMService? = nil
    ) async -> StoneAttempt {
        let startTime = Date()

        if let llm = llmService {
            do {
                return try await attemptStoneWithLLM(
                    llm: llm, stone: stone,
                    previousAttempts: previousAttempts,
                    targetQuery: targetQuery, startTime: startTime
                )
            } catch {
                Log.engine.warning("⚠️ SOAR stone attempt failed, using template: \(error.localizedDescription, privacy: .public)")
            }
        }

        return templateStoneAttempt(stone: stone, startTime: startTime)
    }

    private static func attemptStoneWithLLM(
        llm: LLMService, stone: SteppingStone,
        previousAttempts: [StoneAttempt],
        targetQuery: String, startTime: Date
    ) async throws -> StoneAttempt {
        let contextFromPrevious: String
        if !previousAttempts.isEmpty {
            let insights = previousAttempts.enumerated().map { i, attempt in
                "\(i + 1). \(attempt.stoneId) → \(attempt.response.prefix(200))..."
            }.joined(separator: "\n")
            contextFromPrevious = "\n\nPrevious insights:\n\(insights)\n\nBuild on these."
        } else {
            contextFromPrevious = ""
        }

        let systemPrompt = """
        You are a meta-analytical reasoning engine working through a curriculum.
        Target skill: \(stone.targetSkill)
        Difficulty: \(Int(stone.relativeDifficulty * 100))% of target\(contextFromPrevious)
        Target problem (context only): "\(targetQuery)"
        """

        let response = try await llm.generate(
            prompt: "STEPPING STONE: \"\(stone.question)\"\n\nWork through this systematically.",
            systemPrompt: systemPrompt, maxTokens: 1024
        )

        let hasQualifiers = response.range(of: "however|although|but|caveat|uncertain", options: .regularExpression) != nil
        let hasStructure = response.range(of: "first|second|third|therefore|thus", options: .regularExpression) != nil
        let lengthFactor = min(1, Double(response.count) / 2000)

        let confidenceAfter = min(0.9,
            0.3 + (hasStructure ? 0.15 : 0) + (response.count > 500 ? 0.1 : 0) - (hasQualifiers ? 0.05 : 0)
            + lengthFactor * 0.15 + stone.relativeDifficulty * 0.05
        )
        let entropyAfter = max(0.1,
            0.5 - (hasStructure ? 0.1 : 0) + (hasQualifiers ? 0.1 : 0) + (1 - lengthFactor) * 0.1
        )

        return StoneAttempt(
            stoneId: stone.id, response: response,
            confidenceAfter: confidenceAfter, entropyAfter: entropyAfter,
            durationMs: Date().timeIntervalSince(startTime) * 1000,
            contributedToContext: response.count > 100
        )
    }

    private static func templateStoneAttempt(stone: SteppingStone, startTime: Date) -> StoneAttempt {
        let quality = 0.4 + stone.relativeDifficulty * 0.3 + Double(stone.order) * 0.05
        return StoneAttempt(
            stoneId: stone.id,
            response: "[Template] Reasoning for: \"\(stone.question)\"\n\nTargeting skill: \(stone.targetSkill)\n\nThe key insight is that this problem requires \(stone.targetSkill.lowercased()), which involves systematically decomposing the question into verifiable sub-claims.",
            confidenceAfter: min(0.85, 0.3 + quality * 0.4),
            entropyAfter: max(0.15, 0.6 - quality * 0.3),
            durationMs: Date().timeIntervalSince(startTime) * 1000 + 200,
            contributedToContext: true
        )
    }

    // MARK: - Attempt Target Problem

    static func attemptTarget(
        query: String,
        queryAnalysis: QueryAnalysis,
        curriculum: Curriculum,
        attempts: [StoneAttempt],
        llmService: LLMService? = nil
    ) async -> FinalAttempt {
        let startTime = Date()

        if let llm = llmService {
            do {
                return try await attemptTargetWithLLM(
                    llm: llm, query: query, queryAnalysis: queryAnalysis,
                    curriculum: curriculum, attempts: attempts, startTime: startTime
                )
            } catch {
                Log.engine.warning("⚠️ SOAR final attempt failed, using template: \(error.localizedDescription, privacy: .public)")
            }
        }

        return templateFinalAttempt(attempts: attempts, startTime: startTime)
    }

    private static func attemptTargetWithLLM(
        llm: LLMService, query: String, queryAnalysis: QueryAnalysis,
        curriculum: Curriculum, attempts: [StoneAttempt], startTime: Date
    ) async throws -> FinalAttempt {
        let curriculumContext = attempts.enumerated().map { i, attempt in
            let stone = curriculum.stones.first { $0.id == attempt.stoneId }
            return "Step \(i + 1) — \(stone?.targetSkill ?? "reasoning"):\n\(attempt.response.prefix(300))"
        }.joined(separator: "\n\n")

        let systemPrompt = """
        You have completed a curriculum of preparatory problems. Apply developed reasoning patterns.

        ACCUMULATED CONTEXT:
        \(curriculumContext)

        Domain: \(queryAnalysis.domain.rawValue) | Complexity: \(String(format: "%.2f", queryAnalysis.complexity))
        """

        let result = try await llm.generate(
            prompt: "TARGET PROBLEM: \"\(query)\"\n\nProvide a thorough meta-analytical assessment.",
            systemPrompt: systemPrompt, maxTokens: 2048
        )

        let hasEvidence = result.range(of: "evidence|study|research|data|finding", options: .regularExpression) != nil
        let hasStructure = result.range(of: "first|second|third|therefore|thus", options: .regularExpression) != nil
        let hasUncertainty = result.range(of: "uncertain|unclear|limited|caveat", options: .regularExpression) != nil
        let hasDepth = result.count > 1000
        let lengthFactor = min(1, Double(result.count) / 3000)

        let confidence = min(0.9, 0.35 + (hasEvidence ? 0.12 : 0) + (hasStructure ? 0.1 : 0) + (hasDepth ? 0.08 : 0) + (Double(attempts.count) * 0.04) + lengthFactor * 0.08)
        let entropy = max(0.1, 0.5 - (hasStructure ? 0.12 : 0) - (hasDepth ? 0.05 : 0) + (hasUncertainty ? 0.08 : 0) + (1 - lengthFactor) * 0.08)
        let dissonance = max(0.05, 0.4 - (hasEvidence ? 0.1 : 0) - (Double(attempts.count) * 0.03) + (hasUncertainty ? 0.05 : 0))
        let healthScore = max(0.25, 1 - entropy * 0.45 - dissonance * 0.35)

        return FinalAttempt(
            analysis: result, confidence: confidence, entropy: entropy,
            dissonance: dissonance, healthScore: healthScore,
            durationMs: Date().timeIntervalSince(startTime) * 1000
        )
    }

    private static func templateFinalAttempt(attempts: [StoneAttempt], startTime: Date) -> FinalAttempt {
        let curriculumBonus = Double(attempts.count) * 0.06
        let avgStoneConfidence = attempts.isEmpty ? 0.3 : attempts.reduce(0) { $0 + $1.confidenceAfter } / Double(attempts.count)

        let confidence = min(0.85, 0.25 + curriculumBonus + avgStoneConfidence * 0.3 + Double(attempts.count) * 0.02)
        let entropy = max(0.1, 0.6 - curriculumBonus - avgStoneConfidence * 0.08)
        let dissonance = max(0.05, 0.5 - curriculumBonus * 0.8 - avgStoneConfidence * 0.05)
        let healthScore = max(0.25, 1 - entropy * 0.45 - dissonance * 0.35)

        return FinalAttempt(
            analysis: "[Template] Enhanced analysis after \(attempts.count)-step curriculum.",
            confidence: confidence, entropy: entropy,
            dissonance: dissonance, healthScore: healthScore,
            durationMs: Date().timeIntervalSince(startTime) * 1000 + 300
        )
    }
}
