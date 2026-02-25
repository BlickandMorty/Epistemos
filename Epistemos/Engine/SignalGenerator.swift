import Foundation

// MARK: - Signal Generator
// Generates pipeline signals from query analysis.

enum SignalGenerator {

    // MARK: - Generate Signals

    static func generate(
        queryAnalysis: QueryAnalysis,
        controls: PipelineControls = .default,
        steeringBias: SteeringBias? = nil,
        llmConcepts: [String]? = nil
    ) -> GeneratedSignals {
        let c = max(0, min(1, queryAnalysis.complexity + controls.complexityBias))
        let advInt = controls.adversarialIntensity
        let bayStr = controls.bayesianPriorStrength
        let ef = min(1, Double(queryAnalysis.entities.count) / 8)

        // TDA structural complexity heuristics
        let betti0 = queryAnalysis.isPhilosophical
            ? Int(2 + Double(queryAnalysis.entities.count) * 0.5)
            : max(1, Int(1 + c * 4))

        let betti1 = queryAnalysis.isPhilosophical
            ? (queryAnalysis.hasNormativeClaims ? Int(1 + ef) : Int(ef * 1.5))
            : Int(c * 2 * advInt + ef)

        let persistenceEntropy = queryAnalysis.isPhilosophical
            ? 0.5 + c * 1.5 + ef * 0.4
            : 0.1 + c * 1.8 + ef * 0.25

        let maxPersistence = 0.1 + c * 0.5 + ef * 0.15

        // Base confidence
        let baseConf: Double
        if queryAnalysis.isPhilosophical {
            baseConf = 0.2 + c * 0.15 + ef * 0.1
        } else if queryAnalysis.isEmpirical {
            baseConf = (0.45 + c * 0.2 + ef * 0.15) * bayStr
        } else {
            baseConf = 0.35 + c * 0.2 + ef * 0.15
        }

        // Entropy
        let entropy: Double
        if queryAnalysis.isPhilosophical {
            entropy = 0.5 + c * 0.3 + ef * 0.1
        } else if queryAnalysis.isEmpirical {
            entropy = 0.05 + c * 0.4 + ef * 0.1
        } else {
            entropy = 0.15 + c * 0.45 + ef * 0.1
        }

        // Dissonance
        let dissonance: Double
        if queryAnalysis.hasNormativeClaims {
            dissonance = (0.3 + c * 0.25 + ef * 0.15) * advInt
        } else if queryAnalysis.isPhilosophical {
            dissonance = 0.2 + c * 0.25 + ef * 0.15
        } else {
            dissonance = (0.05 + c * 0.35 + ef * 0.1) * advInt
        }

        // Health score
        let safetyPenalty = queryAnalysis.hasSafetyKeywords ? 0.15 : 0
        let healthScoreBase = max(0.25, 1 - entropy * 0.45 - dissonance * 0.35 - safetyPenalty)

        // Risk score
        let riskScoreBase: Double
        if queryAnalysis.hasSafetyKeywords {
            riskScoreBase = 0.4 + c * 0.2 + ef * 0.15
        } else if queryAnalysis.hasNormativeClaims {
            riskScoreBase = 0.15 + c * 0.15 + ef * 0.1
        } else {
            riskScoreBase = 0.02 + c * 0.2 + ef * 0.08
        }

        // Apply steering bias
        let sb = steeringBias
        let steeredConf = sb.map { baseConf + $0.confidence * $0.steeringStrength } ?? baseConf
        let steeredEntropy = sb.map { entropy + $0.entropy * $0.steeringStrength } ?? entropy
        let steeredDissonance = sb.map { dissonance + $0.dissonance * $0.steeringStrength } ?? dissonance
        let healthScore = sb.map { healthScoreBase + $0.healthScore * $0.steeringStrength } ?? healthScoreBase
        let riskScore = sb.map { riskScoreBase + $0.riskScore * $0.steeringStrength } ?? riskScoreBase

        // Safety state
        let safetyState: SafetyState
        if riskScore >= 0.55 {
            safetyState = .red
        } else if riskScore >= 0.35 {
            safetyState = .yellow
        } else {
            safetyState = .green
        }

        // Focus depth and temperature
        let baseDepth = controls.focusDepthOverride ?? (2 + c * 7 + (queryAnalysis.isPhilosophical ? 1.5 : 0))
        let baseTemp = controls.temperatureOverride ?? (queryAnalysis.isPhilosophical ? 0.7 + c * 0.15 + ef * 0.1 : 1.0 - c * 0.5)

        let depth = sb.map { baseDepth + $0.focusDepth * $0.steeringStrength } ?? baseDepth
        let temp = sb.map { baseTemp + $0.temperatureScale * $0.steeringStrength } ?? baseTemp

        // Concepts — seeded from query entities only; real concepts are
        // extracted from the LLM response after streaming completes
        // (see PipelineService.extractResponseConcepts).
        let concepts: [String]
        if let llmConcepts = llmConcepts, !llmConcepts.isEmpty {
            concepts = llmConcepts
        } else {
            // Use only actual query entities — no hardcoded pools.
            // Title-case each entity for display consistency.
            let entityConcepts = queryAnalysis.entities.map { entity in
                entity.prefix(1).uppercased() + entity.dropFirst()
            }
            let uniqueConcepts = Array(Set(entityConcepts))
            let cw = controls.conceptWeights ?? [:]
            let sortedConcepts = uniqueConcepts.sorted { a, b in
                let wa = cw[a] ?? 1.0
                let wb = cw[b] ?? 1.0
                return (wb + Double(b.count) * 0.02) < (wa + Double(a.count) * 0.02)
            }
            concepts = Array(sortedConcepts.prefix(Int(3 + c * 4)))
        }

        let clampedConf = max(0.1, min(steeredConf, 0.95))
        let grade: EvidenceGrade
        if clampedConf > 0.7 {
            grade = .a
        } else if clampedConf > 0.5 {
            grade = .b
        } else if clampedConf > 0.35 {
            grade = .c
        } else {
            grade = .d
        }

        let mode: AnalysisMode
        if queryAnalysis.isMetaAnalytical {
            mode = .metaAnalytical
        } else if queryAnalysis.isPhilosophical {
            mode = .philosophicalAnalytical
        } else if queryAnalysis.isEmpirical {
            mode = .executive
        } else {
            mode = .moderate
        }

        return GeneratedSignals(
            confidence: clampedConf,
            entropy: max(0.01, min(steeredEntropy, 0.95)),
            dissonance: max(0.01, min(steeredDissonance, 0.95)),
            healthScore: max(healthScore, 0.2),
            safetyState: safetyState,
            riskScore: max(0.01, min(riskScore, 0.9)),
            tda: TDASnapshot(
                betti0: betti0,
                betti1: betti1,
                persistenceEntropy: persistenceEntropy,
                maxPersistence: maxPersistence
            ),
            focusDepth: depth,
            temperatureScale: temp,
            concepts: concepts,
            harmonyKeyDistance: min(steeredDissonance, 0.95),
            grade: grade,
            mode: mode
        )
    }
}

// MARK: - Generated Signals

struct GeneratedSignals: Sendable {
    var confidence: Double
    var entropy: Double
    var dissonance: Double
    var healthScore: Double
    var safetyState: SafetyState
    var riskScore: Double
    var tda: TDASnapshot
    var focusDepth: Double
    var temperatureScale: Double
    var concepts: [String]
    var harmonyKeyDistance: Double
    var grade: EvidenceGrade
    var mode: AnalysisMode
}
