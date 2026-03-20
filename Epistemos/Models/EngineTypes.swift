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

enum EmotionalValence: String, Codable, Sendable {
    case positive
    case negative
    case mixed
    case neutral
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
    var focusDepth: Double?
    var temperatureScale: Double?
    var concepts: [String]?

    init(
        confidence: Double? = nil,
        entropy: Double? = nil,
        dissonance: Double? = nil,
        healthScore: Double? = nil,
        safetyState: SafetyState? = nil,
        riskScore: Double? = nil,
        focusDepth: Double? = nil,
        temperatureScale: Double? = nil,
        concepts: [String]? = nil
    ) {
        self.confidence = confidence
        self.entropy = entropy
        self.dissonance = dissonance
        self.healthScore = healthScore
        self.safetyState = safetyState
        self.riskScore = riskScore
        self.focusDepth = focusDepth
        self.temperatureScale = temperatureScale
        self.concepts = concepts
    }
}

enum SafetyState: String, Codable, Sendable {
    case green
    case yellow
    case orange
    case red
}


struct SignalHistoryEntry: Codable, Sendable {
    var timestamp: Date
    var confidence: Double
    var entropy: Double
    var dissonance: Double
    var healthScore: Double
}

// MARK: - Pipeline Events

enum PipelineEvent: Sendable {
    case textDelta(String)
    case completed(DualMessage, TruthAssessment?)
    case error(String)
}

// MARK: - Evidence

enum EvidenceGrade: String, Codable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case f = "F"
}

// MARK: - Inference Mode

enum InferenceMode: String, Codable, Sendable, CaseIterable {
    case local
    case api
    case appleIntelligence

    static var analytical: InferenceMode { .api }
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

// MARK: - Conversation Context

struct ConversationContext: Codable, Sendable {
    var previousQueries: [String]
    var previousEntities: [String]
    var rootQuestion: String?
}
