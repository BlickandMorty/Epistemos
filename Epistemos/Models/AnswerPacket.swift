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

/// HELIOS V5 W2 — 5-arm classification mirroring the Rust
/// `ClaimKind` enum. Wire format is `snake_case` to match the Rust
/// `#[serde(rename_all = "snake_case")]` directive.
public enum ClaimKind: String, Codable, Hashable, Sendable, CaseIterable {
    case empirical
    case mathematical
    case codeInvariant = "code_invariant"
    case causal
    case speculative

    /// Default to `.empirical` to match Rust's `Default for ClaimKind`
    /// (V1 archive backward-compat).
    public static let `default`: ClaimKind = .empirical
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
    public var witnessedStateRef: String
    public var semanticDeltaRef: String?
    public var mutationEnvelopeRef: String

    public init(
        id: String,
        claims: [Claim] = [],
        residencySignals: [ResidencySignal] = [],
        uiLabel: VRMLabel = .plausibleButUnverified,
        witnessedStateRef: String,
        semanticDeltaRef: String? = nil,
        mutationEnvelopeRef: String
    ) {
        self.id = id
        self.claims = claims
        self.residencySignals = residencySignals
        self.uiLabel = uiLabel
        self.witnessedStateRef = witnessedStateRef
        self.semanticDeltaRef = semanticDeltaRef
        self.mutationEnvelopeRef = mutationEnvelopeRef
    }

    enum CodingKeys: String, CodingKey {
        case id
        case claims
        case residencySignals = "residency_signals"
        case uiLabel = "ui_label"
        case witnessedStateRef = "witnessed_state_ref"
        case semanticDeltaRef = "semantic_delta_ref"
        case mutationEnvelopeRef = "mutation_envelope_ref"
    }
}
