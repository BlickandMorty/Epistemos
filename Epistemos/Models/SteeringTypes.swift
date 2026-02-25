import Foundation

// MARK: - Steering Bias
// The only steering type actively used in v3.
// Referenced by PipelineService, SignalGenerator, and PromptComposer.

struct SteeringBias: Codable, Sendable {
    var confidence: Double
    var entropy: Double
    var dissonance: Double
    var healthScore: Double
    var riskScore: Double
    var focusDepth: Double
    var temperatureScale: Double
    var betti0Adjust: Double
    var betti1Adjust: Double
    var conceptBoosts: [String: Double]
    var steeringStrength: Double
    var steeringSource: String

    static let neutral = SteeringBias(
        confidence: 0, entropy: 0, dissonance: 0, healthScore: 0,
        riskScore: 0, focusDepth: 0, temperatureScale: 0,
        betti0Adjust: 0, betti1Adjust: 0, conceptBoosts: [:],
        steeringStrength: 0, steeringSource: "none"
    )
}
