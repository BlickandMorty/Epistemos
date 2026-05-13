import Foundation

// MARK: - HELIOS V5 W1 + W2 + W3 — Swift mirror types
//
// HELIOS-W1 guard
// HELIOS-W2 guard
// HELIOS-W3 guard
//
// These types mirror `agent_core/src/scope_rex/answer_packet.rs` and
// `agent_core/src/provenance/ledger.rs::ClaimKind`. Wire-format parity
// is enforced by the Rust side's `#[serde(rename_all = "snake_case")]`
// + the snake_case CodingKeys here.
//
// Tier 1 (MAS-safe): strictly additive structs. The chat path is not yet
// wired to populate AnswerPacket per reply — that lands in the W1 follow-up
// slice. Until then, these types compile + serialize round-trip cleanly,
// the canon-hardening WRV state is `state: implemented` (not `wired`).
//
// Cross-references:
// - docs/HELIOS_V5_DOC_0_INDEX.md §0.1 (concept-to-doc map),
//   §0.2 (theorem status table), §0.6 (glossary)
// - docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md §3 (W1 + W2 + W3)
// - docs/fusion/helios v5 first.md DOC 1 §1.2 (AnswerPacket schema)

/// HELIOS V5 W2 — classification mirroring the Rust
/// `ClaimKind` enum. Wire format is `snake_case` to match the Rust
/// `#[serde(rename_all = "snake_case")]` directive.
/// V5 locks five epistemic arms; V6.1 adds a runtime-admission arm
/// for static 9:1 fallback acknowledgement.
public enum ClaimKind: String, Codable, Hashable, Sendable, CaseIterable {
    case empirical
    case mathematical
    case codeInvariant = "code_invariant"
    case causal
    case speculative
    case staticFallbackAcknowledged = "static_fallback_acknowledged"

    /// Default to `.empirical` to match Rust's `Default for ClaimKind`
    /// (V1 archive backward-compat).
    public static let `default`: ClaimKind = .empirical
}

/// EPISTEMOS V6.1 — attention/retrieval wake mode for an emitted
/// AnswerPacket.
///
/// The default is `.unavailable` so older packets never imply dynamic
/// interrupt execution merely because the field was absent.
public enum AttentionMode: String, Codable, Hashable, Sendable, CaseIterable {
    case dynamic
    case staticFallback = "static_fallback"
    case unavailable

    public static let `default`: AttentionMode = .unavailable
}

/// EPISTEMOS V6.2 — turn-level InterruptScore (u_t) bucket sampled at
/// AnswerPacket emit time. Mirrors `InterruptScoreCpu.Bucket` (LOW/MED/
/// HIGH per V6.2 §1.5 thresholds 0.25 / 0.65) plus an `.unavailable`
/// sentinel for packets emitted before any signal source is wired.
///
/// The bucket is a per-TURN summary; V6.2 §1.4 Falsifier 6 specifies
/// u_t as per-TOKEN. The packet-level snapshot captures the bucket the
/// turn ended in — the Controller-plane veto cadence depends on the
/// bucket at the moment the streaming terminates, not on the entire
/// per-token trajectory.
///
/// Default is `.unavailable` so older packets never imply that the
/// runtime had genuine interrupt-score signals merely because the
/// field exists.
public enum InterruptBucket: String, Codable, Hashable, Sendable, CaseIterable {
    case low
    case medium
    case high
    case unavailable

    public static let `default`: InterruptBucket = .unavailable

    /// V6.2 §1.5 calibration-corpus mapping: LOW = boilerplate /
    /// continuation / format completion; MED = multi-step reasoning,
    /// cross-file refactor, retrieval QA; HIGH = novel theorem, OOD
    /// prompt, tool-call, agentic multi-hop.
    public var shortLabel: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        case .unavailable: return "—"
        }
    }
}

/// HELIOS V5 W3 — Verified Research Mode UI label.
///
/// 4-arm collapse of the 9-claim π Kleene K3 classification per
/// `docs/fusion/helios v5 first.md` §1.9. The chat row's
/// `VRMLabelView` renders one of these four states for every emitted
/// AnswerPacket.
public enum VRMLabel: String, Codable, Hashable, Sendable, CaseIterable {
    case verified
    case plausibleButUnverified = "plausible_but_unverified"
    case speculative
    case blocked

    /// Default mirrors Rust `VrmLabel::default()` — never silently
    /// promote unverified claims to verified status.
    public static let `default`: VRMLabel = .plausibleButUnverified

    /// Short display label suitable for a chat-row chip.
    public var shortLabel: String {
        switch self {
        case .verified: return "Verified"
        case .plausibleButUnverified: return "Plausible"
        case .speculative: return "Speculative"
        case .blocked: return "Blocked"
        }
    }

    /// Verbose label for accessibility / hover tooltip.
    public var accessibilityLabel: String {
        switch self {
        case .verified: return "Verified — empirical, mathematical, or code-invariant chain validated"
        case .plausibleButUnverified: return "Plausible but unverified — internally consistent, no verification chain"
        case .speculative: return "Speculative — hypothesis or conjecture"
        case .blocked: return "Blocked — failed safety or privacy gate"
        }
    }
}

/// HELIOS V5 W4 — pure-data input to the Residency Governor.
/// Mirrors Rust `ResidencySignal`. The Governor itself is the W4 slice;
/// this struct is W1's input type carried by AnswerPacket.
public struct ResidencySignal: Codable, Hashable, Sendable {
    public var safetyRisk: Float
    public var privacy: Float
    public var verificationScore: Float
    public var repeatCount: UInt32
    public var gain: Float
    public var forgetting: Float

    public init(
        safetyRisk: Float,
        privacy: Float,
        verificationScore: Float,
        repeatCount: UInt32,
        gain: Float,
        forgetting: Float
    ) {
        self.safetyRisk = safetyRisk
        self.privacy = privacy
        self.verificationScore = verificationScore
        self.repeatCount = repeatCount
        self.gain = gain
        self.forgetting = forgetting
    }

    /// Neutral signal matching Rust `ResidencySignal::neutral()`.
    public static let neutral = ResidencySignal(
        safetyRisk: 0.0,
        privacy: 0.0,
        verificationScore: 0.5,
        repeatCount: 0,
        gain: 0.0,
        forgetting: 0.0
    )

    enum CodingKeys: String, CodingKey {
        case safetyRisk = "safety_risk"
        case privacy
        case verificationScore = "verification_score"
        case repeatCount = "repeat_count"
        case gain
        case forgetting
    }
}

// MARK: - HELIOS V5 W4 — Residency Governor 9-variant taxonomy
//
// HELIOS-W4 guard
//
// Mirror of Rust `agent_core::scope_rex::residency::Residency`.
// 7 of 9 arms are reachable from the §1.13-threshold route() function;
// HarnessRule + CloudDistilled are reserved for higher-level routing
// layers (Pro-tier harness-versioning + cloud-fusion dispatch).

/// HELIOS V5 W4 — 9-variant residency taxonomy mirror.
public enum Residency: String, Codable, Hashable, Sendable, CaseIterable {
    case transientContext = "transient_context"
    case retrievalMemory = "retrieval_memory"
    case featureRule = "feature_rule"
    case harnessRule = "harness_rule"
    case grpoPrior = "grpo_prior"
    case psoftAdapter = "psoft_adapter"
    case osftCore = "osft_core"
    case cloudDistilled = "cloud_distilled"
    case quarantine
}

/// Status mirror for a Claim — tracks the Rust `ClaimStatus` 4-arm.
public enum ClaimStatus: String, Codable, Hashable, Sendable {
    case active
    case atRisk = "at_risk"
    case needsRevalidation = "needs_revalidation"
    case retracted
}

/// Swift mirror of Rust `Claim`. Field order matches the Rust struct;
/// `kind` is decoded with a default of `.empirical` for v1 archive
/// backward-compat (matches Rust `#[serde(default)]`).
public struct Claim: Codable, Hashable, Sendable {
    public var id: String
    public var text: String
    public var status: ClaimStatus
    public var createdAtMs: Int64
    public var kind: ClaimKind

    public init(
        id: String,
        text: String,
        status: ClaimStatus,
        createdAtMs: Int64,
        kind: ClaimKind = .empirical
    ) {
        self.id = id
        self.text = text
        self.status = status
        self.createdAtMs = createdAtMs
        self.kind = kind
    }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case status
        case createdAtMs = "created_at_ms"
        case kind
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.text = try c.decode(String.self, forKey: .text)
        self.status = try c.decode(ClaimStatus.self, forKey: .status)
        self.createdAtMs = try c.decode(Int64.self, forKey: .createdAtMs)
        // V1 backward-compat: missing `kind` decodes as `.empirical`.
        self.kind = try c.decodeIfPresent(ClaimKind.self, forKey: .kind) ?? .empirical
    }
}

/// Swift mirror of Rust `AnswerPacket`. Tier 1 schema; not yet emitted
/// by the chat path (`state: implemented`, not `state: wired`).
public struct AnswerPacket: Codable, Hashable, Sendable {
    public var id: String
    public var claims: [Claim]
    public var residencySignals: [ResidencySignal]
    public var uiLabel: VRMLabel
    public var attentionMode: AttentionMode
    /// V6.2 §1.4 Falsifier 6: turn-level u_t bucket sampled at emit time.
    /// Default `.unavailable` until the runtime threads real signal
    /// sources (entropy / WBO / sheaf / tool-need / connectome-alarm).
    public var interruptBucket: InterruptBucket
    public var witnessedStateRef: String
    public var semanticDeltaRef: String?
    public var mutationEnvelopeRef: String

    public init(
        id: String,
        claims: [Claim] = [],
        residencySignals: [ResidencySignal] = [],
        uiLabel: VRMLabel = .plausibleButUnverified,
        attentionMode: AttentionMode = .unavailable,
        interruptBucket: InterruptBucket = .unavailable,
        witnessedStateRef: String,
        semanticDeltaRef: String? = nil,
        mutationEnvelopeRef: String
    ) {
        self.id = id
        self.claims = claims
        self.residencySignals = residencySignals
        self.uiLabel = uiLabel
        self.attentionMode = attentionMode
        self.interruptBucket = interruptBucket
        self.witnessedStateRef = witnessedStateRef
        self.semanticDeltaRef = semanticDeltaRef
        self.mutationEnvelopeRef = mutationEnvelopeRef
    }

    public var requiresStaticFallbackAcknowledgement: Bool {
        attentionMode == .staticFallback
    }

    public var acknowledgesStaticFallback: Bool {
        guard requiresStaticFallbackAcknowledgement else { return true }
        return claims.contains { $0.kind == .staticFallbackAcknowledged }
    }

    public var attentionModeClaimsAreConsistent: Bool {
        let hasStaticFallbackAcknowledgement = claims.contains {
            $0.kind == .staticFallbackAcknowledged
        }
        switch attentionMode {
        case .staticFallback:
            return hasStaticFallbackAcknowledgement
        case .dynamic, .unavailable:
            return !hasStaticFallbackAcknowledgement
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case claims
        case residencySignals = "residency_signals"
        case uiLabel = "ui_label"
        case attentionMode = "attention_mode"
        case interruptBucket = "interrupt_bucket"
        case witnessedStateRef = "witnessed_state_ref"
        case semanticDeltaRef = "semantic_delta_ref"
        case mutationEnvelopeRef = "mutation_envelope_ref"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.claims = try c.decode([Claim].self, forKey: .claims)
        self.residencySignals = try c.decode([ResidencySignal].self, forKey: .residencySignals)
        self.uiLabel = try c.decode(VRMLabel.self, forKey: .uiLabel)
        self.attentionMode = try c.decodeIfPresent(AttentionMode.self, forKey: .attentionMode) ?? .unavailable
        // V6.2 backward-compat: pre-V6.2 packets don't carry
        // `interrupt_bucket`; decode missing as `.unavailable`.
        self.interruptBucket = try c.decodeIfPresent(InterruptBucket.self, forKey: .interruptBucket) ?? .unavailable
        self.witnessedStateRef = try c.decode(String.self, forKey: .witnessedStateRef)
        self.semanticDeltaRef = try c.decodeIfPresent(String.self, forKey: .semanticDeltaRef)
        self.mutationEnvelopeRef = try c.decode(String.self, forKey: .mutationEnvelopeRef)
    }
}
