import Foundation
import os

// MARK: - SOAR Teacher
// Curriculum generator matching lib/engine/soar/teacher.ts

actor SOARTeacher {

    private static let templateStones: [(question: String, skill: String)] = [
        ("What are the key assumptions underlying {TOPIC}?", "Assumption identification"),
        ("What evidence would change your view on {TOPIC}?", "Falsifiability reasoning"),
        ("How would a skeptic critique the strongest argument for {TOPIC}?", "Adversarial thinking"),
        ("What analogous problem in a different domain shares the same logical structure as {TOPIC}?", "Structural transfer"),
        ("Decompose {TOPIC} into its three most fundamental sub-questions.", "Problem decomposition"),
        ("What are the second-order effects of {TOPIC} that are commonly overlooked?", "Consequence tracing"),
        ("Identify the most likely confounding variable in claims about {TOPIC}.", "Causal reasoning"),
        ("If {TOPIC} is true, what else must necessarily be true?", "Deductive inference chain"),
        ("Construct a minimal counterexample to the primary claim about {TOPIC}.", "Counterexample construction"),
        ("What would a Bayesian update look like given new evidence about {TOPIC}?", "Bayesian reasoning")
    ]

    private var curriculumCounter = 0

    // MARK: - Generate Curriculum

    func generateCurriculum(
        query: String,
        queryAnalysis: QueryAnalysis,
        numStones: Int,
        iteration: Int,
        previousReward: SOARReward? = nil,
        llmService: LLMService? = nil
    ) async -> Curriculum {
        let startTime = Date()
        curriculumCounter += 1
        let curriculumId = "cur_\(curriculumCounter)_\(Int(startTime.timeIntervalSince1970 * 1000))"

        if let llm = llmService {
            do {
                return try await generateLLMCurriculum(
                    llm: llm, query: query, queryAnalysis: queryAnalysis,
                    numStones: numStones, iteration: iteration,
                    previousReward: previousReward, curriculumId: curriculumId, startTime: startTime
                )
            } catch {
                Log.engine.warning("⚠️ SOAR curriculum generation failed, using template: \(error.localizedDescription, privacy: .public)")
            }
        }

        return generateSimulatedCurriculum(
            query: query, queryAnalysis: queryAnalysis,
            numStones: numStones, iteration: iteration,
            curriculumId: curriculumId, startTime: startTime
        )
    }

    // MARK: - LLM Curriculum

    private func generateLLMCurriculum(
        llm: LLMService, query: String, queryAnalysis: QueryAnalysis,
        numStones: Int, iteration: Int, previousReward: SOARReward?,
        curriculumId: String, startTime: Date
    ) async throws -> Curriculum {
        let rewardContext: String
        if let reward = previousReward {
            let improved = reward.improved ? "improved" : "no improvement"
            rewardContext = "\nPrevious curriculum reward: \(String(format: "%.3f", reward.composite)) (\(improved)).\n\(reward.improved ? "Refine and deepen it." : "Generate a DIFFERENT curriculum approach.")"
        } else {
            rewardContext = ""
        }

        let systemPrompt = """
        You are a pedagogical curriculum designer operating within a meta-analytical reasoning engine.
        Generate STEPPING-STONE problems — intermediate questions that build reasoning scaffolding.

        Domain: \(queryAnalysis.domain.rawValue)
        Question type: \(queryAnalysis.questionType.rawValue)
        Complexity: \(String(format: "%.2f", queryAnalysis.complexity))
        Key entities: \(queryAnalysis.entities.joined(separator: ", "))\(rewardContext)
        """

        let userPrompt = """
        TARGET PROBLEM: "\(query)"
        Generate exactly \(numStones) stepping-stone problems.

        Return format:
        RATIONALE: <curriculum strategy>

        STONE 1:
        Q: <question>
        SKILL: <target skill>
        DIFFICULTY: <0.0-1.0>
        """

        let response = try await llm.generate(prompt: userPrompt, systemPrompt: systemPrompt, maxTokens: 1500)
        let (stones, rationale) = parseCurriculumResponse(response, curriculumId: curriculumId, numStones: numStones, queryAnalysis: queryAnalysis)

        return Curriculum(
            id: curriculumId, targetQuery: query, stones: stones,
            generationTimeMs: Date().timeIntervalSince(startTime) * 1000,
            iteration: iteration, teacherRationale: rationale
        )
    }

    private func parseCurriculumResponse(_ response: String, curriculumId: String, numStones: Int, queryAnalysis: QueryAnalysis) -> ([SteppingStone], String) {
        var stones: [SteppingStone] = []
        var rationale = "LLM-generated curriculum"

        if let rationaleRange = response.range(of: "RATIONALE:", options: .caseInsensitive) {
            let afterRationale = response[rationaleRange.upperBound...]
            if let nl = afterRationale.firstIndex(of: "\n") {
                let beforeStone = afterRationale[..<nl]
                if !beforeStone.contains("STONE") {
                    rationale = String(beforeStone).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        for i in 0..<numStones {
            let stonePrefix = "STONE \(i + 1):"
            if let stoneRange = response.range(of: stonePrefix, options: .caseInsensitive) {
                let afterStone = response[stoneRange.upperBound...]
                let nextPrefix = "STONE \(i + 2):"
                let endIndex = afterStone.range(of: nextPrefix, options: .caseInsensitive)?.lowerBound ?? afterStone.endIndex
                let stoneText = String(afterStone[..<endIndex])

                let question = extractField(from: stoneText, field: "Q:") ?? "Analyze the structure of this problem"
                let skill = extractField(from: stoneText, field: "SKILL:") ?? "Analytical reasoning"
                let difficultyStr = extractField(from: stoneText, field: "DIFFICULTY:") ?? "0.5"
                let difficulty = Double(difficultyStr) ?? 0.5

                stones.append(SteppingStone(
                    id: "stone_\(curriculumId)_\(i)", question: question,
                    targetSkill: skill, relativeDifficulty: max(0, min(1, difficulty)),
                    structuralQuality: 0, wasUseful: nil, order: i
                ))
            }
        }

        if stones.isEmpty {
            let topic = queryAnalysis.entities.first ?? "the subject"
            for i in 0..<min(numStones, SOARTeacher.templateStones.count) {
                let template = SOARTeacher.templateStones[i]
                stones.append(SteppingStone(
                    id: "stone_\(curriculumId)_\(i)",
                    question: template.question.replacingOccurrences(of: "{TOPIC}", with: topic),
                    targetSkill: template.skill,
                    relativeDifficulty: 0.3 + (Double(i) / Double(numStones)) * 0.5,
                    structuralQuality: 0.5, wasUseful: nil, order: i
                ))
            }
        }

        return (stones, rationale)
    }

    private func extractField(from text: String, field: String) -> String? {
        guard let range = text.range(of: field, options: .caseInsensitive) else { return nil }
        let afterField = text[range.upperBound...]
        let trimmed = afterField.drop(while: { $0.isWhitespace || $0 == ":" })
        let knownFields = ["Q:", "SKILL:", "DIFFICULTY:"]
        var endIndex = trimmed.endIndex
        for kf in knownFields where kf.uppercased() != field.uppercased() {
            if let fr = trimmed.range(of: kf, options: .caseInsensitive), fr.lowerBound < endIndex {
                endIndex = fr.lowerBound
            }
        }
        return String(trimmed[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Simulated Curriculum

    private func generateSimulatedCurriculum(
        query: String, queryAnalysis: QueryAnalysis,
        numStones: Int, iteration: Int,
        curriculumId: String, startTime: Date
    ) -> Curriculum {
        let topic = queryAnalysis.entities.first ?? "the subject"
        let templates = Array(SOARTeacher.templateStones.prefix(min(numStones, SOARTeacher.templateStones.count)))

        let stones: [SteppingStone] = templates.enumerated().map { i, template in
            SteppingStone(
                id: "stone_\(curriculumId)_\(i)",
                question: template.question.replacingOccurrences(of: "{TOPIC}", with: topic),
                targetSkill: template.skill,
                relativeDifficulty: 0.3 + (Double(i) / Double(numStones)) * 0.5,
                structuralQuality: 0.5 + Double.random(in: 0...0.3),
                wasUseful: nil, order: i
            )
        }

        return Curriculum(
            id: curriculumId, targetQuery: query, stones: stones,
            generationTimeMs: Date().timeIntervalSince(startTime) * 1000,
            iteration: iteration,
            teacherRationale: "[Template] Generated \(numStones) stepping stones for \(queryAnalysis.domain.rawValue)/\(queryAnalysis.questionType.rawValue) domain."
        )
    }
}
