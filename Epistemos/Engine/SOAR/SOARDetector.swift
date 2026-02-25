import Foundation

// MARK: - SOAR Detector
// Edge-of-learnability detection matching lib/engine/soar/detector.ts

nonisolated enum SOARDetector {

    // MARK: - Hard Indicators

    static let hardIndicators: [String] = [
        "paradox", "contradiction", "dilemma", "impossible", "unsolvable",
        "undecidable", "np-hard", "intractable", "unprovable", "incompleteness",
        "infinite regress", "self-referential", "emergent", "consciousness",
        "qualia", "free will", "hard problem", "meta-analysis of meta-analyses",
        "causal inference from observational", "confounding", "selection bias",
        "simpson's paradox", "ecological fallacy", "counterfactual",
        "multi-step reasoning", "abductive", "non-monotonic", "defeasible"
    ]

    static let hardQuestionTypes: Set<QuestionType> = [
        .metaAnalytical, .causal, .speculative
    ]

    static let hardDomains: Set<AnalysisDomain> = [
        .philosophy, .ethics, .psychology
    ]

    // MARK: - Learnability Probe

    static func probeLearnability(
        queryAnalysis: QueryAnalysis,
        priorSignals: BaselineSignals? = nil,
        thresholds: LearnabilityThresholds
    ) -> LearnabilityProbe {
        let queryLower = queryAnalysis.coreQuestion.lowercased()

        // 1. Base difficulty from triage complexity
        var difficulty = queryAnalysis.complexity

        // 2. Hard indicator keyword scan
        var hardKeywordCount = 0
        for kw in hardIndicators {
            if queryLower.contains(kw) {
                hardKeywordCount += 1
            }
        }
        difficulty += min(0.2, Double(hardKeywordCount) * 0.05)

        // 3. Question type difficulty
        if hardQuestionTypes.contains(queryAnalysis.questionType) {
            difficulty += 0.1
        }

        // 4. Domain difficulty
        if hardDomains.contains(queryAnalysis.domain) {
            difficulty += 0.08
        }

        // 5. Structural complexity (entity count)
        let entityCount = queryAnalysis.entities.count
        if entityCount > 5 { difficulty += 0.05 }
        if entityCount > 10 { difficulty += 0.05 }

        // 6. Multi-hop reasoning detection (question length as proxy)
        let wordCount = queryAnalysis.coreQuestion.split(separator: " ").count
        if wordCount > 50 { difficulty += 0.05 }
        if wordCount > 100 { difficulty += 0.05 }

        difficulty = max(0, min(1, difficulty))

        // Estimate initial confidence and entropy from difficulty
        let probeConfidence = max(0.05, 0.9 - difficulty * 0.8)
        let probeEntropy = min(0.95, 0.1 + difficulty * 0.7)

        // Use prior signals if available
        let effectiveConfidence = priorSignals?.confidence ?? probeConfidence
        let effectiveEntropy = priorSignals?.entropy ?? probeEntropy
        let effectiveDissonance = priorSignals?.dissonance ?? (difficulty * 0.5)

        // Edge detection
        let belowConfidence = effectiveConfidence < thresholds.confidenceFloor
        let aboveEntropy = effectiveEntropy > thresholds.entropyCeiling
        let aboveDissonance = effectiveDissonance > thresholds.dissonanceCeiling
        let aboveDifficulty = difficulty >= thresholds.difficultyFloor

        let signalTriggers = [belowConfidence, aboveEntropy, aboveDissonance].filter { $0 }.count
        let atEdge = aboveDifficulty && signalTriggers >= 2

        // Determine recommended iteration depth
        var recommendedDepth = 0
        if atEdge {
            if signalTriggers == 3 {
                recommendedDepth = 3
            } else if difficulty > 0.8 {
                recommendedDepth = 3
            } else {
                recommendedDepth = 2
            }
        }

        // Build reason string
        let reason: String
        if !aboveDifficulty {
            reason = "Query difficulty (\(String(format: "%.2f", difficulty))) below threshold (\(String(format: "%.2f", thresholds.difficultyFloor))). Standard pipeline sufficient."
        } else if signalTriggers < 2 {
            reason = "Difficulty is high (\(String(format: "%.2f", difficulty))) but only \(signalTriggers)/3 signal thresholds triggered. SOAR not needed."
        } else {
            var triggers: [String] = []
            if belowConfidence { triggers.append("confidence \(String(format: "%.2f", effectiveConfidence)) < \(String(format: "%.2f", thresholds.confidenceFloor))") }
            if aboveEntropy { triggers.append("entropy \(String(format: "%.2f", effectiveEntropy)) > \(String(format: "%.2f", thresholds.entropyCeiling))") }
            if aboveDissonance { triggers.append("dissonance \(String(format: "%.2f", effectiveDissonance)) > \(String(format: "%.2f", thresholds.dissonanceCeiling))") }
            reason = "At learnability edge: \(triggers.joined(separator: ", ")). Difficulty: \(String(format: "%.2f", difficulty)). SOAR recommended (depth \(recommendedDepth))."
        }

        return LearnabilityProbe(
            estimatedDifficulty: difficulty,
            probeConfidence: effectiveConfidence,
            probeEntropy: effectiveEntropy,
            atEdge: atEdge,
            reason: reason,
            recommendedDepth: recommendedDepth,
            timestamp: Date()
        )
    }
}
