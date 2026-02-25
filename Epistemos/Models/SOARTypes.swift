import Foundation

// MARK: - SOAR Configuration

struct SOARConfig: Codable, Sendable {
    var enabled: Bool
    var autoDetect: Bool
    var thresholds: LearnabilityThresholds
    var maxIterations: Int
    var stonesPerCurriculum: Int
    var rewardWeights: RewardWeights
    var minRewardThreshold: Double
    var contradictionDetection: Bool
    var maxContradictionClaims: Int
    var apiCostCapTokens: Int
    var verbose: Bool

    static let `default` = SOARConfig(
        enabled: false,
        autoDetect: true,
        thresholds: LearnabilityThresholds.default,
        maxIterations: 3,
        stonesPerCurriculum: 3,
        rewardWeights: RewardWeights.default,
        minRewardThreshold: 0.05,
        contradictionDetection: true,
        maxContradictionClaims: 20,
        apiCostCapTokens: 50000,
        verbose: false
    )

    static let defaults = SOARConfig.default
}

struct LearnabilityThresholds: Codable, Sendable {
    var confidenceFloor: Double
    var entropyCeiling: Double
    var dissonanceCeiling: Double
    var difficultyFloor: Double

    static let `default` = LearnabilityThresholds(
        confidenceFloor: 0.35,
        entropyCeiling: 0.7,
        dissonanceCeiling: 0.6,
        difficultyFloor: 0.5
    )

    static let defaults = LearnabilityThresholds.default
}

struct RewardWeights: Codable, Sendable {
    var confidence: Double
    var entropy: Double
    var dissonance: Double
    var health: Double
    var tda: Double

    static let `default` = RewardWeights(
        confidence: 0.35,
        entropy: 0.25,
        dissonance: 0.20,
        health: 0.15,
        tda: 0.05
    )

    static let defaults = RewardWeights.default
}

// MARK: - Learnability Probe

struct LearnabilityProbe: Codable, Sendable {
    var estimatedDifficulty: Double
    var probeConfidence: Double
    var probeEntropy: Double
    var atEdge: Bool
    var reason: String
    var recommendedDepth: Int
    var timestamp: Date
}

// MARK: - Curriculum

struct Curriculum: Codable, Sendable {
    var id: String
    var targetQuery: String
    var stones: [SteppingStone]
    var generationTimeMs: Double
    var iteration: Int
    var teacherRationale: String
}

struct SteppingStone: Codable, Sendable, Identifiable {
    var id: String
    var question: String
    var targetSkill: String
    var relativeDifficulty: Double
    var structuralQuality: Double
    var wasUseful: Bool?
    var order: Int
}

// MARK: - Attempts

struct StoneAttempt: Codable, Sendable {
    var stoneId: String
    var response: String
    var confidenceAfter: Double
    var entropyAfter: Double
    var durationMs: Double
    var contributedToContext: Bool
}

struct FinalAttempt: Codable, Sendable {
    var analysis: String
    var confidence: Double
    var entropy: Double
    var dissonance: Double
    var healthScore: Double
    var durationMs: Double
}

// MARK: - Reward

struct SOARReward: Codable, Sendable {
    var deltaConfidence: Double
    var deltaEntropy: Double
    var deltaDissonance: Double
    var deltaHealth: Double
    var deltaPersistenceEntropy: Double
    var composite: Double
    var improved: Bool
}

struct BaselineSignals: Codable, Sendable {
    var confidence: Double
    var entropy: Double
    var dissonance: Double
    var healthScore: Double
    var persistenceEntropy: Double
}

// MARK: - Contradiction Detection

struct Contradiction: Codable, Sendable, Identifiable {
    var id: String
    var claimA: String
    var sourceA: String
    var claimB: String
    var sourceB: String
    var contradictionConfidence: Double
    var type: ContradictionType
    var explanation: String
}

enum ContradictionType: String, Codable, Sendable {
    case factual
    case logical
    case temporal
    case scope
    case methodological
}

struct ContradictionScan: Codable, Sendable {
    var totalClaims: Int
    var totalComparisons: Int
    var contradictions: [Contradiction]
    var computedDissonance: Double
    var durationMs: Double
}

// MARK: - SOAR Session

struct SOARSession: Identifiable, Codable, Sendable {
    var id: String
    var targetQuery: String
    var probe: LearnabilityProbe?
    var curricula: [Curriculum]
    var attempts: [StoneAttempt]
    var finalAttempts: [FinalAttempt]
    var rewards: [SOARReward]
    var contradictionScan: ContradictionScan?
    var baselineSignals: BaselineSignals
    var finalSignals: BaselineSignals?
    var iterationsCompleted: Int
    var maxIterations: Int
    var overallImproved: Bool
    var totalDurationMs: Double
    var inferenceMode: InferenceMode
    var startedAt: Date
    var completedAt: Date?
    var status: SOARSessionStatus
}

enum SOARSessionStatus: String, Codable, Sendable {
    case probing
    case teaching
    case learning
    case evaluating
    case complete
    case aborted
}

// MARK: - SOAR Events

enum SOAREventType: String, Sendable {
    case probeComplete = "probe-complete"
    case teachingStart = "teaching-start"
    case teachingComplete = "teaching-complete"
    case stoneStart = "stone-start"
    case stoneComplete = "stone-complete"
    case finalAttemptStart = "final-attempt-start"
    case finalAttemptComplete = "final-attempt-complete"
    case rewardComputed = "reward-computed"
    case contradictionScanStart = "contradiction-scan-start"
    case contradictionScanComplete = "contradiction-scan-complete"
    case iterationComplete = "iteration-complete"
    case sessionComplete = "session-complete"
    case sessionAborted = "session-aborted"
}

struct SOAREvent: Sendable {
    var type: SOAREventType
    var sessionId: String
    var iteration: Int
    var data: [String: AnySendable]
    var timestamp: Date
}

// MARK: - SOAR Limitations by Mode

struct SOARLimitations: Sendable {
    var mode: InferenceMode
    var maxIterations: Int
    var maxStonesPerCurriculum: Int
    var supportsRapidIteration: Bool
    var supportsLogprobs: Bool
    var supportsWeightUpdates: Bool
    var estimatedCostPerIteration: String
    var estimatedLatencyPerIteration: String
    var learningPersistence: LearningPersistence
    var limitations: [String]
    var advantages: [String]
}

enum LearningPersistence: String, Sendable {
    case none
    case inContext = "in-context"
    case session
    case permanent
}

nonisolated func getSOARLimitations(for mode: InferenceMode) -> SOARLimitations {
    switch mode {
    case .local:
        SOARLimitations(
            mode: .local,
            maxIterations: 5,
            maxStonesPerCurriculum: 5,
            supportsRapidIteration: true,
            supportsLogprobs: true,
            supportsWeightUpdates: false,
            estimatedCostPerIteration: "Free (local compute only)",
            estimatedLatencyPerIteration: "5-30s depending on model size",
            learningPersistence: .session,
            limitations: [
                "Smaller model capacity limits curriculum quality",
                "VRAM/memory constraints cap maximum model size",
                "No true weight updates — learning is context-accumulation",
                "Local models may lack world knowledge for specialized domains",
                "Quantized models may produce less coherent curricula"
            ],
            advantages: [
                "Unlimited iterations — no cost per query",
                "Full control over generation parameters",
                "Can run rapid-fire teacher-student loops",
                "Access to token logprobs for richer signals",
                "No data leaves your machine — full privacy"
            ]
        )
    case .api:
        SOARLimitations(
            mode: .api,
            maxIterations: 2,
            maxStonesPerCurriculum: 3,
            supportsRapidIteration: false,
            supportsLogprobs: false,
            supportsWeightUpdates: false,
            estimatedCostPerIteration: "~$0.02-0.15 per iteration (GPT-4o/Claude)",
            estimatedLatencyPerIteration: "3-12s per round-trip",
            learningPersistence: .inContext,
            limitations: [
                "Each iteration costs tokens — 6-15x a single query",
                "Rate limits cap iteration speed",
                "No weight updates — model doesn't actually learn",
                "Learning is ephemeral — resets between sessions",
                "No access to model internals for debugging"
            ],
            advantages: [
                "Access to frontier models with superior reasoning",
                "Teacher generates higher-quality curricula",
                "Better structural coherence in stepping stones",
                "Faster per-call latency than most local setups",
                "No local hardware requirements"
            ]
        )
    case .appleIntelligence:
        SOARLimitations(
            mode: .appleIntelligence,
            maxIterations: 3,
            maxStonesPerCurriculum: 3,
            supportsRapidIteration: true,
            supportsLogprobs: false,
            supportsWeightUpdates: false,
            estimatedCostPerIteration: "Free (on-device)",
            estimatedLatencyPerIteration: "2-8s per iteration",
            learningPersistence: .session,
            limitations: [
                "Model capacity varies by device",
                "No access to internal weights",
                "Learning is context-based only"
            ],
            advantages: [
                "Free and private",
                "Fast local execution",
                "No network required"
            ]
        )
    }
}
