import Foundation

// MARK: - Pipeline Stage

enum PipelineStage: String, Codable, Sendable, CaseIterable {
    case triage = "TRIAGE"
    case memory = "MEMORY"
    case routing = "ROUTING"
    case statistical = "STATISTICAL"
    case causal = "CAUSAL"
    case metaAnalysis = "META_ANALYSIS"
    case bayesian = "BAYESIAN"
    case synthesis = "SYNTHESIS"
    case adversarial = "ADVERSARIAL"
    case calibration = "CALIBRATION"

    /// Human-readable display name for UI and intents.
    nonisolated var displayName: String {
        switch self {
        case .triage: "Triage"
        case .memory: "Memory"
        case .routing: "Routing"
        case .statistical: "Statistical"
        case .causal: "Causal"
        case .metaAnalysis: "Meta-Analysis"
        case .bayesian: "Bayesian"
        case .synthesis: "Synthesis"
        case .adversarial: "Adversarial"
        case .calibration: "Calibration"
        }
    }

    /// Short description for intent entities.
    nonisolated var stageDescription: String {
        switch self {
        case .triage: "Initial assessment"
        case .memory: "Context retrieval"
        case .routing: "Engine selection"
        case .statistical: "Statistical analysis"
        case .causal: "Causal reasoning"
        case .metaAnalysis: "Cross-study synthesis"
        case .bayesian: "Bayesian inference"
        case .synthesis: "Final synthesis"
        case .adversarial: "Counter-argument generation"
        case .calibration: "Confidence calibration"
        }
    }
}

enum StageStatus: String, Codable, Sendable {
    case idle
    case pending
    case running
    case completed
    case failed
    case skipped
}

// MARK: - Stage Result

struct StageResult: Codable, Sendable {
    var stage: PipelineStage
    var status: StageStatus
    var data: String?
    var durationMs: Int?
    var error: String?
    var detail: String?
    var value: Double?
}

// MARK: - Query Analysis

struct QueryAnalysis: Codable, Sendable {
    var domain: AnalysisDomain
    var questionType: QuestionType
    var entities: [String]
    var coreQuestion: String
    var complexity: Double
    var isEmpirical: Bool
    var isPhilosophical: Bool
    var isMetaAnalytical: Bool
    var hasSafetyKeywords: Bool
    var hasNormativeClaims: Bool
    var keyTerms: [String]
    var emotionalValence: EmotionalValence
    var isFollowUp: Bool
    var followUpFocus: String?
}

enum AnalysisDomain: String, Codable, Sendable {
    case medical
    case philosophy
    case science
    case technology
    case socialScience = "social_science"
    case economics
    case psychology
    case ethics
    case general
}

enum QuestionType: String, Codable, Sendable {
    case causal
    case comparative
    case definitional
    case evaluative
    case speculative
    case metaAnalytical = "meta_analytical"
    case empirical
    case conceptual
}

enum EmotionalValence: String, Codable, Sendable {
    case neutral
    case positive
    case negative
    case mixed
}

// MARK: - Dual Message System

struct DualMessage: Codable, Sendable {
    var rawAnalysis: String
    var uncertaintyTags: [UncertaintyTag]
    var modelVsDataFlags: [DataFlag]
    var laymanSummary: LaymanSummary?
    var reflection: ReflectionResult?
    var arbitration: ArbitrationResult?
}

struct UncertaintyTag: Codable, Sendable {
    var claim: String
    var tag: UncertaintyTagType
}

enum UncertaintyTagType: String, Codable, Sendable {
    case data
    case model
    case uncertain
    case conflict
}

struct DataFlag: Codable, Sendable {
    var claim: String
    var source: DataFlagSource
}

enum DataFlagSource: String, Codable, Sendable {
    case dataDriven = "data-driven"
    case modelAssumption = "model-assumption"
    case heuristic
}

struct LaymanSummary: Codable, Sendable {
    var whatWasTried: String
    var whatIsLikelyTrue: String
    var confidenceExplanation: String
    var whatCouldChange: String
    var whoShouldTrust: String
    var sectionLabels: SectionLabels?
}

struct SectionLabels: Codable, Sendable {
    var whatWasTried: String?
    var whatIsLikelyTrue: String?
    var confidenceExplanation: String?
    var whatCouldChange: String?
    var whoShouldTrust: String?
}

struct ReflectionResult: Codable, Sendable {
    var selfCriticalQuestions: [String]
    var adjustments: [String]
    var leastDefensibleClaim: String
    var precisionVsEvidenceCheck: String
}

struct ArbitrationResult: Codable, Sendable {
    var consensus: Bool
    var votes: [EngineVote]
    var disagreements: [String]
    var resolution: String
}

struct EngineVote: Codable, Sendable {
    var engine: PipelineStage
    var position: VotePosition
    var reasoning: String
    var confidence: Double
}

enum VotePosition: String, Codable, Sendable {
    case supports
    case opposes
    case neutral
}

// MARK: - Truth Assessment

struct TruthAssessment: Codable, Sendable {
    var overallTruthLikelihood: Double
    var signalInterpretation: String
    var weaknesses: [String]
    var improvements: [String]
    var blindSpots: [String]
    var confidenceCalibration: String
    var dataVsModelBalance: String
    var recommendedActions: [String]
}

// MARK: - Signals

struct SignalUpdate: Codable, Sendable {
    var confidence: Double?
    var entropy: Double?
    var dissonance: Double?
    var healthScore: Double?
    var safetyState: SafetyState?
    var riskScore: Double?
    var tda: TDASnapshot?
    var focusDepth: Double?
    var temperatureScale: Double?
    var concepts: [String]?
    var activeChordProduct: Double?
    var harmonyKeyDistance: Double?

    init(
        confidence: Double? = nil,
        entropy: Double? = nil,
        dissonance: Double? = nil,
        healthScore: Double? = nil,
        safetyState: SafetyState? = nil,
        riskScore: Double? = nil,
        tda: TDASnapshot? = nil,
        focusDepth: Double? = nil,
        temperatureScale: Double? = nil,
        concepts: [String]? = nil,
        activeChordProduct: Double? = nil,
        harmonyKeyDistance: Double? = nil
    ) {
        self.confidence = confidence
        self.entropy = entropy
        self.dissonance = dissonance
        self.healthScore = healthScore
        self.safetyState = safetyState
        self.riskScore = riskScore
        self.tda = tda
        self.focusDepth = focusDepth
        self.temperatureScale = temperatureScale
        self.concepts = concepts
        self.activeChordProduct = activeChordProduct
        self.harmonyKeyDistance = harmonyKeyDistance
    }
}

enum SafetyState: String, Codable, Sendable {
    case green
    case yellow
    case orange
    case red
}

struct TDASnapshot: Codable, Sendable {
    var betti0: Int
    var betti1: Int
    var persistenceEntropy: Double
    var maxPersistence: Double
}

struct SignalHistoryEntry: Codable, Sendable {
    var timestamp: Date
    var confidence: Double
    var entropy: Double
    var dissonance: Double
    var healthScore: Double
}

// MARK: - Pipeline Controls

struct PipelineControls: Codable, Sendable {
    var focusDepthOverride: Double?
    var temperatureOverride: Double?
    var complexityBias: Double
    var adversarialIntensity: Double
    var bayesianPriorStrength: Double
    var conceptWeights: [String: Double]?

    static let `default` = PipelineControls(
        focusDepthOverride: nil,
        temperatureOverride: nil,
        complexityBias: 0.0,
        adversarialIntensity: 1.0,
        bayesianPriorStrength: 1.0,
        conceptWeights: nil
    )

    static let defaults = PipelineControls.default
}

// MARK: - Pipeline Events

enum PipelineEvent: Sendable {
    case stageAdvanced(PipelineStage, StageResult)
    case textDelta(String)
    case reasoningDelta(String)
    case deliberationDelta(String)
    case signalUpdate(SignalUpdate)
    case completed(DualMessage, TruthAssessment?)
    case enriched(DualMessage, TruthAssessment)
    case error(String)
    case soarEvent(SOAREventType, [String: AnySendable])
}

// MARK: - Evidence & Analysis

enum EvidenceGrade: String, Codable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case f = "F"
}

enum AnalysisMode: String, Codable, Sendable {
    case metaAnalytical = "meta-analytical"
    case philosophicalAnalytical = "philosophical-analytical"
    case executive
    case moderate
}

// MARK: - Inference Mode

enum InferenceMode: String, Codable, Sendable, CaseIterable {
    case local
    case api
    case appleIntelligence

    static var analytical: InferenceMode { .api }
}

// MARK: - Synthesis Report

struct SynthesisReport: Codable, Sendable {
    var plainSummary: String
    var researchSummary: String
    var suggestions: [String]
    var timestamp: Date
}

// MARK: - File Attachments

struct FileAttachment: Codable, Sendable, Identifiable {
    var id: String
    var name: String
    var type: AttachmentType
    var uri: String
    var size: Int
    var mimeType: String
    var preview: String?
}

enum AttachmentType: String, Codable, Sendable {
    case image
    case csv
    case pdf
    case text
    case other
}

// MARK: - Reroute (Mid-Stream Cognitive Redirection)

enum RerouteType: String, Codable, Sendable, CaseIterable {
    case focus
    case explore
    case challenge
    case synthesize
    case simplify

    nonisolated var label: String {
        switch self {
        case .focus: "Focus"
        case .explore: "Explore"
        case .challenge: "Challenge"
        case .synthesize: "Synthesize"
        case .simplify: "Simplify"
        }
    }

    nonisolated var icon: String {
        switch self {
        case .focus: "scope"
        case .explore: "arrow.trianglehead.branch"
        case .challenge: "shield.lefthalf.filled.trianglebadge.exclamationmark"
        case .synthesize: "arrow.triangle.merge"
        case .simplify: "rectangle.compress.vertical"
        }
    }

    nonisolated var prompt: String {
        switch self {
        case .focus: "Narrow down on key evidence and the strongest arguments. Cut tangential threads."
        case .explore: "Branch out to related areas, adjacent domains, and alternative framings."
        case .challenge: "Apply adversarial scrutiny. What are the strongest counter-arguments?"
        case .synthesize: "Combine findings into a unified conclusion. Reconcile tensions."
        case .simplify: "Reduce complexity. Express the core insight as plainly as possible."
        }
    }
}

struct RerouteInstruction: Codable, Sendable {
    var type: RerouteType
    var detail: String?
}

// MARK: - Steer Suggestions (Cognitive Hints)

enum SteerHint: String, CaseIterable, Sendable {
    case signal
    case maths
    case patterns
    case cognition
    case metrics
    case creative

    nonisolated var label: String {
        switch self {
        case .signal: "Signal"
        case .maths: "Maths"
        case .patterns: "Patterns"
        case .cognition: "Cognition"
        case .metrics: "Metrics"
        case .creative: "Creative"
        }
    }

    nonisolated var icon: String {
        switch self {
        case .signal: "waveform.path"
        case .maths: "sum"
        case .patterns: "waveform"
        case .cognition: "brain.head.profile"
        case .metrics: "chart.bar"
        case .creative: "lightbulb"
        }
    }

    nonisolated var detail: String {
        switch self {
        case .signal: "Adjust confidence signals and evidence weighting"
        case .maths: "Apply more rigorous statistical reasoning"
        case .patterns: "Look for recurring patterns in the data"
        case .cognition: "Shift cognitive strategy or reasoning depth"
        case .metrics: "Focus on quantitative metrics and effect sizes"
        case .creative: "Try unconventional angles and lateral thinking"
        }
    }
}

// MARK: - Cortex

struct CortexSnapshot: Identifiable, Codable, Sendable {
    var id: String
    var label: String
    var timestamp: Date
    var confidence: Double
    var entropy: Double
    var dissonance: Double
    var healthScore: Double
    var concepts: [String]
    var queriesProcessed: Int
}

// MARK: - Conversation Context

struct ConversationContext: Codable, Sendable {
    var previousQueries: [String]
    var previousEntities: [String]
    var rootQuestion: String?
}

// MARK: - Analytical Mode (for prompt composer)

enum AnalyticalMode: String, Sendable {
    case research
    case plain
}
