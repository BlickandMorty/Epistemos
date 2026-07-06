import Foundation

// MARK: - RuntimeExecutor (Phase 2 Terminal T1 — 2026-05-24)
//
// Substrate Motion: *Mutate / Promote* (substrate routing decision →
// substrate dispatch). MLX stops being "the architecture." This file
// declares the executor protocol the substrate uses to treat MLX,
// GGUF/llama.cpp, Apple Intelligence, and cloud providers as
// interchangeable lanes behind one routing policy.
//
// 7-Law alignment:
//   * Motion        — every execute() call is a Mutate/Promote step
//                     witnessed by RunEventLog (downstream wiring).
//   * UAS           — MissionPacket carries `uasAddress` so callers
//                     do not lose identity across lane swaps.
//   * Plane         — `RuntimePlane` field on MissionPacket pins which
//                     of the five planes the request belongs to.
//   * Residency     — `ResidencyTier` carried on MissionPacket and
//                     surfaced as a per-lane capability (T1..T3).
//   * WBO           — escalations are tallied in
//                     `RuntimeRouterMetrics.escalationsByLane` per-lane.
//                     A follow-up terminal will fold these counts into
//                     the WBO ledger as availability/accuracy trade-offs
//                     (counts are observed in the diagnostics surface,
//                     not yet a WBO entry).
//   * Witness       — `RouteVerdict` is itself the witness primitive.
//                     Every dispatch produces a logged verdict.
//   * Falsifier     — F-LocalToolUse is the per-lane falsifier that
//                     proves the chosen lane actually honors the
//                     tool-call grammar the model claims.
//   * Tier          — lanes self-report capability tier; the router
//                     never promotes above the request's ceiling.
//   * Rollback      — `teardown()` is mandatory; the router must be
//                     able to disable a lane (Settings → Inference →
//                     Runtime Lanes) without leaking compute resources.

// MARK: - RuntimeLane

/// Identifies one executor lane in the multi-lane router.
///
/// MLX is **one lane among several** — the architecture is the
/// router + the protocol, not the local inference framework. The
/// `.cloud(provider:)` case is unique-per-provider so the router can
/// reason about Claude vs. OpenAI vs. Gemini vs. Perplexity as
/// distinct lanes with their own capability surfaces.
nonisolated public enum RuntimeLane: Hashable, Sendable, Codable {
    case appleIntelligence
    case gguf
    case cloud(provider: String)
    case stub

    /// Stable string identity for logs, metrics, defaults storage.
    public var stableID: String {
        switch self {
        case .appleIntelligence: return "apple_intelligence"
        case .gguf: return "gguf"
        case .cloud(let provider): return "cloud:\(provider)"
        case .stub: return "stub"
        }
    }

    public var displayName: String {
        switch self {
        case .appleIntelligence: return "Apple Intelligence"
        case .gguf: return "Local GGUF"
        case .cloud(let provider): return "Cloud · \(provider)"
        case .stub: return "Stub"
        }
    }

    /// The well-known lanes plus stub. The router always offers
    /// these in Settings even if a given lane's executor is not yet
    /// registered — that is the honest signal "lane present, no
    /// executor wired" rather than a silent omission.
    public static let knownLanes: [RuntimeLane] = [
        .appleIntelligence,
        .gguf,
        .cloud(provider: "claude"),
        .cloud(provider: "openai"),
        .cloud(provider: "gemini"),
        .cloud(provider: "zai"),
        .cloud(provider: "kimi"),
        .cloud(provider: "perplexity"),
        .stub,
    ]
}

// MARK: - ResidencyTier

/// Mirror of the substrate's three-tier residency axis. Surfaced here
/// so the router can refuse to dispatch a request to a lane that
/// cannot honor the request's ceiling (e.g. CapabilityCeiling request
/// to an Apple Intelligence lane with no flagship-tier surface yet).
nonisolated public enum ResidencyTier: String, Hashable, Sendable, Codable, CaseIterable {
    case currentApp = "current_app"
    case verifiedFloor = "verified_floor"
    case capabilityCeiling = "capability_ceiling"

    public var displayName: String {
        switch self {
        case .currentApp: return "Current App"
        case .verifiedFloor: return "Verified Floor"
        case .capabilityCeiling: return "Capability Ceiling"
        }
    }
}

// MARK: - RuntimePlane

/// Five-plane label carried by MissionPacket so the router pins the
/// dispatch to the correct plane (State · Episodic · Assembly ·
/// Controller · Verification).
nonisolated public enum RuntimePlane: String, Hashable, Sendable, Codable, CaseIterable {
    case state
    case episodic
    case assembly
    case controller
    case verification

    public var displayName: String { rawValue.capitalized }
}

// MARK: - RuntimeRole

/// The six per-role profiles the router publishes. Acceptance: at
/// least 6 non-empty profiles surfaced through `routeProfiles()`.
nonisolated public enum RuntimeRole: String, Hashable, Sendable, Codable, CaseIterable {
    case code
    case reasoning
    case quick
    case toolCaller = "tool_caller"
    case trivial
    case vision

    public var displayName: String {
        switch self {
        case .code: return "Code"
        case .reasoning: return "Reasoning"
        case .quick: return "Quick"
        case .toolCaller: return "Tool Caller"
        case .trivial: return "Trivial"
        case .vision: return "Vision"
        }
    }
}

// MARK: - RuntimeCapability

nonisolated public enum RuntimeCostClass: String, Hashable, Sendable, Codable, CaseIterable {
    case free
    case cheap
    case standard
    case premium

    public var displayName: String { rawValue.capitalized }
}

nonisolated public enum RuntimeLatencyClass: String, Hashable, Sendable, Codable, CaseIterable {
    /// In-process inference, no network hop.
    case local
    /// Local network or trusted edge.
    case edge
    /// Public internet round-trip.
    case networked

    public var displayName: String {
        switch self {
        case .local: return "Local"
        case .edge: return "Edge"
        case .networked: return "Networked"
        }
    }
}

nonisolated public enum RuntimeToolCallMode: String, Hashable, Sendable, Codable, CaseIterable {
    /// Grammar-constrained / native function-calling on the wire.
    case native
    /// Soft-guidance via prompt; parser extracts.
    case softGuidance = "soft_guidance"
    /// No tool calling supported by this lane.
    case none

    public var displayName: String {
        switch self {
        case .native: return "Native"
        case .softGuidance: return "Soft-guidance"
        case .none: return "None"
        }
    }
}

/// Per-lane capability surface. The router compares this against the
/// MissionPacket's demands to pick (or refuse) the lane.
nonisolated public struct RuntimeCapability: Hashable, Sendable, Codable {
    public let tier: ResidencyTier
    public let contextWindow: Int
    /// Tool-call grammars the lane can honor on the wire. Empty set
    /// means the lane cannot handle tool calls — soft-guidance only.
    public let grammarSupport: Set<String>
    public let vision: Bool
    public let costClass: RuntimeCostClass
    public let latencyClass: RuntimeLatencyClass
    public let toolCallMode: RuntimeToolCallMode

    public init(
        tier: ResidencyTier,
        contextWindow: Int,
        grammarSupport: Set<String> = [],
        vision: Bool = false,
        costClass: RuntimeCostClass = .free,
        latencyClass: RuntimeLatencyClass = .local,
        toolCallMode: RuntimeToolCallMode = .softGuidance
    ) {
        self.tier = tier
        self.contextWindow = contextWindow
        self.grammarSupport = grammarSupport
        self.vision = vision
        self.costClass = costClass
        self.latencyClass = latencyClass
        self.toolCallMode = toolCallMode
    }
}

// MARK: - MissionPacket (router input)

/// Router-layer mission packet. `MissionPacket` carries only the fields the
/// router needs to pick a lane: identity, plane, residency ceiling, role,
/// demands.
nonisolated public struct MissionPacket: Sendable, Equatable, Hashable, Codable, Identifiable {
    public let id: String
    public let uasAddress: String
    public let plane: RuntimePlane
    public let residencyCeiling: ResidencyTier
    public let role: RuntimeRole
    public let objective: String
    public let requiresTools: Bool
    public let requiresVision: Bool
    public let requiresGrammar: Bool
    public let privacySensitive: Bool
    public let classificationConfidence: Double?
    public let estimatedComplexity: Double?
    public let toolCountEstimate: Int?
    public let estimatedInputTokens: Int?
    /// Optional caller-supplied lane preference. The router treats
    /// this as a hint; honors it only if the lane is enabled and
    /// its capability surface satisfies the rest of the demands.
    public let preferredLane: RuntimeLane?

    public init(
        id: String = UUID().uuidString,
        uasAddress: String,
        plane: RuntimePlane = .controller,
        residencyCeiling: ResidencyTier = .currentApp,
        role: RuntimeRole,
        objective: String,
        requiresTools: Bool = false,
        requiresVision: Bool = false,
        requiresGrammar: Bool = false,
        privacySensitive: Bool = false,
        classificationConfidence: Double? = nil,
        estimatedComplexity: Double? = nil,
        toolCountEstimate: Int? = nil,
        estimatedInputTokens: Int? = nil,
        preferredLane: RuntimeLane? = nil
    ) {
        self.id = id
        self.uasAddress = uasAddress
        self.plane = plane
        self.residencyCeiling = residencyCeiling
        self.role = role
        self.objective = objective
        self.requiresTools = requiresTools
        self.requiresVision = requiresVision
        self.requiresGrammar = requiresGrammar
        self.privacySensitive = privacySensitive
        self.classificationConfidence = classificationConfidence
        self.estimatedComplexity = estimatedComplexity
        self.toolCountEstimate = toolCountEstimate
        self.estimatedInputTokens = estimatedInputTokens
        self.preferredLane = preferredLane
    }
}

// MARK: - RouteVerdict

/// The router's per-request verdict. **This is the witness** —
/// every dispatch produces one. Routing decisions are observable
/// for the duration of the session via `RuntimeRouterMetrics`.
nonisolated public enum RouteVerdict: Sendable, Equatable, Hashable, Codable {
    /// Lane will handle the request directly.
    case accept(lane: RuntimeLane, capability: RuntimeCapability)
    /// Lane cannot handle the request; the router will try another
    /// lane. `reason` is logged as an escalation entry.
    case escalate(from: RuntimeLane, to: RuntimeLane, reason: EscalationReason)
    /// No lane can serve. Caller sees an honest failure rather than
    /// a silent fallback. `reason` documents why.
    case reject(reason: RejectReason)

    public enum EscalationReason: String, Sendable, Equatable, Hashable, Codable {
        case laneDisabled = "lane_disabled"
        case contextWindowExceeded = "context_window_exceeded"
        case toolCallGrammarUnsupported = "tool_call_grammar_unsupported"
        case visionUnsupported = "vision_unsupported"
        case residencyTierExceeded = "residency_tier_exceeded"
        case privacyPolicyMismatch = "privacy_policy_mismatch"
        case capabilityMissing = "capability_missing"
        case classificationUncertain = "classification_uncertain"
        case taskTooComplex = "task_too_complex"
        case tooManyToolCalls = "too_many_tool_calls"
        case invalidPolicyInput = "invalid_policy_input"

        public var displayName: String {
            switch self {
            case .laneDisabled: return "Lane disabled"
            case .contextWindowExceeded: return "Context window exceeded"
            case .toolCallGrammarUnsupported: return "Tool grammar unsupported"
            case .visionUnsupported: return "Vision unsupported"
            case .residencyTierExceeded: return "Residency tier exceeded"
            case .privacyPolicyMismatch: return "Privacy policy mismatch"
            case .capabilityMissing: return "Capability missing"
            case .classificationUncertain: return "Classification uncertain"
            case .taskTooComplex: return "Task too complex"
            case .tooManyToolCalls: return "Too many tool calls"
            case .invalidPolicyInput: return "Invalid policy input"
            }
        }
    }

    public enum RejectReason: String, Sendable, Equatable, Hashable, Codable {
        case noLaneAvailable = "no_lane_available"
        case allLanesDisabled = "all_lanes_disabled"
        case privacySensitiveNoLocal = "privacy_sensitive_no_local"
        case invalidPolicyInput = "invalid_policy_input"

        public var displayName: String {
            switch self {
            case .noLaneAvailable: return "No lane available"
            case .allLanesDisabled: return "All lanes disabled"
            case .privacySensitiveNoLocal: return "Privacy-sensitive · no local lane"
            case .invalidPolicyInput: return "Invalid policy input"
            }
        }
    }
}

// MARK: - RuntimeAnswerPacket

/// Result wrapper returned by `RuntimeExecutor.execute`. Distinct
/// from the substrate's `AnswerPacket` (Epistemos/Models/AnswerPacket.swift)
/// which is the consumer-facing claim/witness packet emitted by the
/// chat surface. `RuntimeAnswerPacket` is the executor's raw return
/// — the chat surface assembles the substrate AnswerPacket from
/// this plus residency + claim graph state.
nonisolated public struct RuntimeAnswerPacket: Sendable, Equatable, Hashable, Codable {
    public let lane: RuntimeLane
    public let modelID: String?
    public let text: String
    /// Optional structured tool-call payload (raw JSON). Empty when
    /// the lane returned a text-only response.
    public let toolCallJSON: String?
    public let promptTokens: Int
    public let completionTokens: Int
    /// Substrate witness reference — points into the RunEventLog
    /// entry created at dispatch time.
    public let witnessRef: String

    public init(
        lane: RuntimeLane,
        modelID: String?,
        text: String,
        toolCallJSON: String? = nil,
        promptTokens: Int = 0,
        completionTokens: Int = 0,
        witnessRef: String
    ) {
        self.lane = lane
        self.modelID = modelID
        self.text = text
        self.toolCallJSON = toolCallJSON
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.witnessRef = witnessRef
    }
}

// MARK: - RuntimeExecutorError

nonisolated public struct RuntimeExecutorError: Error, Equatable, LocalizedError, Sendable {
    public let lane: RuntimeLane
    public let message: String

    public init(lane: RuntimeLane, message: String) {
        self.lane = lane
        self.message = message
    }

    public var errorDescription: String? {
        "[\(lane.stableID)] \(message)"
    }
}

// MARK: - RuntimeExecutor

/// The protocol every lane (MLX, GGUF, Apple Intelligence, each
/// cloud provider, stub) implements. Conformance is `Sendable` so
/// the router can hold lanes in an `@Observable` table without
/// MainActor isolation.
nonisolated public protocol RuntimeExecutor: Sendable {
    var id: RuntimeLane { get }
    var capability: RuntimeCapability { get }

    /// Pure routing decision — no I/O. The router calls this for
    /// every candidate lane and picks the first `.accept` verdict.
    func canHandle(_ request: MissionPacket) -> RouteVerdict

    /// Actual dispatch. The router only calls this for the lane it
    /// already accepted; lanes may still throw on transient failures
    /// (network blip, model not loaded) and the router will record
    /// the escalation.
    func execute(_ request: MissionPacket) async throws -> RuntimeAnswerPacket

    /// Tear down resources held by the lane. Must be idempotent —
    /// the Settings panel may flip a lane OFF and back ON multiple
    /// times per session.
    func teardown() async
}
