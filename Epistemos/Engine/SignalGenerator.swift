import Foundation

// MARK: - Signal Generator
// Produces initial signal estimates from query analysis.
// These are starting defaults — real confidence, concepts, and truth assessment
// come from the LLM enrichment passes, not from heuristics.

enum SignalGenerator {

    static func generate(
        queryAnalysis: QueryAnalysis,
        controls: PipelineControls = .default,
        steeringBias: SteeringBias? = nil,
        llmConcepts: [String]? = nil
    ) -> GeneratedSignals {
        let c = max(0, min(1, queryAnalysis.complexity + controls.complexityBias))
        let ef = min(1, Double(queryAnalysis.entities.count) / 8)

        // Neutral defaults — the LLM enrichment passes produce the real assessment.
        // These provide reasonable starting points that vary with query characteristics.
        let confidence: Double
        if queryAnalysis.isPhilosophical { confidence = 0.35 + ef * 0.05 }
        else if queryAnalysis.isEmpirical { confidence = 0.55 + ef * 0.05 }
        else { confidence = 0.45 + ef * 0.05 }

        let entropy = queryAnalysis.isPhilosophical ? (0.45 + c * 0.2) : (0.3 + c * 0.2)
        let dissonance = queryAnalysis.hasNormativeClaims ? 0.35 : 0.15

        let riskScore = queryAnalysis.hasSafetyKeywords ? (0.4 + c * 0.2 + ef * 0.1) : 0.1
        let safetyState: SafetyState
        if riskScore >= 0.55 { safetyState = .red }
        else if riskScore >= 0.3 { safetyState = .yellow }
        else { safetyState = .green }

        // Concepts — seeded from query entities; real concepts come from
        // LLM response (see EnrichmentController.extractResponseConcepts).
        let concepts: [String]
        if let llmConcepts, !llmConcepts.isEmpty {
            concepts = llmConcepts
        } else {
            concepts = Array(Set(queryAnalysis.entities.map {
                $0.prefix(1).uppercased() + $0.dropFirst()
            })).prefix(6).map { String($0) }
        }

        let mode: AnalysisMode
        if queryAnalysis.isMetaAnalytical { mode = .metaAnalytical }
        else if queryAnalysis.isPhilosophical { mode = .philosophicalAnalytical }
        else if queryAnalysis.isEmpirical { mode = .executive }
        else { mode = .moderate }

        return GeneratedSignals(
            confidence: confidence,
            entropy: entropy,
            dissonance: dissonance,
            healthScore: max(0.5, 1 - entropy * 0.3 - dissonance * 0.2),
            safetyState: safetyState,
            riskScore: riskScore,
            focusDepth: controls.focusDepthOverride ?? (3 + c * 5),
            temperatureScale: controls.temperatureOverride ?? (queryAnalysis.isPhilosophical ? 0.8 : 0.7),
            concepts: concepts,
            grade: confidence > 0.5 ? .b : .c,
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
    var focusDepth: Double
    var temperatureScale: Double
    var concepts: [String]
    var grade: EvidenceGrade
    var mode: AnalysisMode
}
