// CognitiveWeight.swift
//
// Master Fusion Plan §B.6 W1 — Swift mirror of the Rust
// `agent_core::cognitive_weight::CognitiveWeight` types.
//
// Source: `docs/fusion/COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md`
// + `docs/fusion/research/FINAL_SYNTHESIS.md` §3.
//
// **Semantic Gravity pulls attention; Policy Authority controls action;
// do not confuse the two.** The 4-tier classifier (Soft / Preferred /
// StrongAnchor / PolicyGrade) is purely about Semantic Gravity — how
// retrieval surfaces (Halo, composer attachment plan) should boost a
// document's salience. Policy Authority (the right to constrain tools)
// is a separate, more guarded affair.
//
// **W1 acceptance behavior**: per doctrine §6 W1, `policy_authority`
// is SILENTLY DOWNGRADED to false on the Swift side regardless of
// what the Rust side reports. W2 (Wave 7) is when policy authority
// goes live with the 5-gate enforcement loop. Until then, the badge
// + retrieval surfaces ONLY honor Semantic Gravity. The downgrade is
// silent — no UI element claims policy authority — so a misconfigured
// upstream that sets `policy_authority: true` doesn't accidentally
// gate tools.

import Foundation

/// The four canonical classes from FINAL_SYNTHESIS §3 / doctrine §2.
/// Numeric ranges tile [0, 1] without gaps or overlap.
///
/// Wire format matches the Rust serde `rename_all = "snake_case"`
/// shape so `CognitiveWeight` round-trips through FFI without remap.
public enum CognitiveWeightClass: String, Codable, Sendable, Hashable, CaseIterable {
    /// 0.00–0.30 · trailing context · no policy authority
    case soft
    /// 0.31–0.60 · inline context · no policy authority
    case preferred
    /// 0.61–0.85 · above-fold context · advisory (UI hint only)
    case strongAnchor = "strong_anchor"
    /// 0.86–1.00 · immutable system context · would-be ENFORCED policy
    /// authority — but silently downgraded under W1 acceptance §6.
    case policyGrade = "policy_grade"
}

/// Where in the rendered context window a class lands.
public enum ContextPlacement: String, Codable, Sendable, Hashable {
    case trailing
    case inline
    case aboveFold = "above_fold"
    case immutableSystem = "immutable_system"
}

/// Per-document cognitive weight. Carries enough metadata for the
/// retrieval surface (Halo, composer attachment plan) to apply boost
/// + render the 4-tier badge.
///
/// **Construction discipline**: callers should prefer
/// `CognitiveWeight(rawScore:)` over manual field assignment. The
/// initializer enforces:
///   - `rawScore` clamped to [0, 1]
///   - `class` derived from the score
///   - `policyAuthority` ALWAYS false (W1 silent downgrade)
///   - `retrievalPriorityBoost` + `contextPlacement` bound per class
public struct CognitiveWeight: Codable, Sendable, Hashable {
    /// The provider's raw weight, in [0, 1]. Source of truth.
    public let rawScore: Float
    /// Derived from `rawScore` per doctrine §2 table.
    public let `class`: CognitiveWeightClass
    /// **W1 acceptance §6**: ALWAYS false on the Swift side. W2 (Wave 7)
    /// will flip this to a real signal once the 5-gate enforcement loop
    /// lands.
    public let policyAuthority: Bool
    /// Bounded by `class` per doctrine §2 retrieval-priority column.
    public let retrievalPriorityBoost: Float
    /// Bounded by `class` per doctrine §2 context-placement column.
    public let contextPlacement: ContextPlacement

    /// Match the Rust serde field names (snake_case) so this struct
    /// can deserialize from the FFI wire format without remap.
    enum CodingKeys: String, CodingKey {
        case rawScore = "raw_score"
        case `class`
        case policyAuthority = "policy_authority"
        case retrievalPriorityBoost = "retrieval_priority_boost"
        case contextPlacement = "context_placement"
    }

    /// Deterministic constructor — matches `Rust::CognitiveWeight::
    /// from_raw_score`. `policyAuthority` is ALWAYS false here per W1
    /// silent-downgrade acceptance.
    public init(rawScore: Float) {
        let raw = max(0.0, min(1.0, rawScore))
        let cls = Self.classify(raw)
        let (boost, placement) = Self.biasForClass(cls)
        self.rawScore = raw
        self.class = cls
        self.policyAuthority = false
        self.retrievalPriorityBoost = boost
        self.contextPlacement = placement
    }

    /// Decoder honors W1 silent-downgrade: even if the Rust side
    /// reports `policy_authority: true`, the Swift mirror REWRITES it
    /// to false. This is the §6 acceptance anchor — a misconfigured
    /// upstream cannot accidentally signal policy authority into the
    /// Swift UI under W1.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decode(Float.self, forKey: .rawScore)
        // Read but discard the wire-format policy_authority; rebuild
        // the rest from the canonical bias-for-class mapping.
        _ = try container.decodeIfPresent(Bool.self, forKey: .policyAuthority)
        let cls = try container.decodeIfPresent(CognitiveWeightClass.self, forKey: .class)
            ?? Self.classify(raw)
        let (boost, placement) = Self.biasForClass(cls)
        self.rawScore = max(0.0, min(1.0, raw))
        self.class = cls
        self.policyAuthority = false // W1 silent downgrade
        self.retrievalPriorityBoost = boost
        self.contextPlacement = placement
    }

    /// Per-table classification. Maps score to class per doctrine §2.
    /// Boundary scores fall to the LOWER class (the table reads
    /// "0.00–0.30" inclusive).
    public static func classify(_ raw: Float) -> CognitiveWeightClass {
        let r = max(0.0, min(1.0, raw))
        switch r {
        case ...0.30: return .soft
        case ...0.60: return .preferred
        case ...0.85: return .strongAnchor
        default:      return .policyGrade
        }
    }

    /// Canonical retrieval-priority boost + context placement for a
    /// class. Boost values are the midpoint of the doctrine §2
    /// retrieval-priority range; different scores within the same
    /// class produce identical biases (class is the unit of
    /// retrieval-priority distinction, not raw score).
    public static func biasForClass(
        _ cls: CognitiveWeightClass
    ) -> (Float, ContextPlacement) {
        switch cls {
        case .soft:         return (0.05, .trailing)
        case .preferred:    return (0.20, .inline)
        case .strongAnchor: return (0.45, .aboveFold)
        case .policyGrade:  return (0.80, .immutableSystem)
        }
    }
}

// MARK: - Display strings (for the badge + accessibility labels)

public extension CognitiveWeightClass {
    /// Short user-facing label rendered inside the badge.
    var shortLabel: String {
        switch self {
        case .soft:         return "Soft"
        case .preferred:    return "Preferred"
        case .strongAnchor: return "Strong"
        case .policyGrade:  return "Policy"
        }
    }

    /// Longer accessibility / tooltip description per doctrine §2.
    /// The PolicyGrade variant explicitly says "advisory in W1" to
    /// reinforce the §6 silent-downgrade acceptance.
    var accessibilityDescription: String {
        switch self {
        case .soft:
            return "Soft memory — trailing context, no policy authority"
        case .preferred:
            return "Preferred context — inline at relevance order"
        case .strongAnchor:
            return "Strong anchor — above the fold, advisory only"
        case .policyGrade:
            return "Policy-grade — immutable system context, advisory in W1 (policy authority lands in W2)"
        }
    }
}
