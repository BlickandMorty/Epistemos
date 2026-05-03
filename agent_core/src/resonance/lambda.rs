//! λ — residency target mapping.
//!
//! Per doctrine §A.3 (the 7-level residency hierarchy) + §3 tier matrix:
//! Core/App Store builds may only target L0–L3 + L7. L4 (Engram), L5
//! (adapter cache), and L6 (Forbidden / Sovereign-class) are gated to
//! Pro / Research. Promotion past L3 requires T2+ verification AND a
//! measurable runtime gain (per Annex A.3 + the doctrine §6 hard
//! forbidden list).
//!
//! The seed maps a claim to the L0–L3 cold-to-hot quartile based on its
//! kind + evidence count. Structurally invalid inputs (e.g. a Composite
//! with no dependencies) sink to L7 Quarantine — the safe, doctrine-§4.1
//! invariant-respecting destination for "should never reach the user."

use crate::resonance::{Claim, ClaimType};
use serde::{Deserialize, Serialize};

/// 8-level residency hierarchy per doctrine Annex A.3.
///
/// `Ord` ordering is the natural hot→cold→Pro→Research→Quarantine sweep:
/// L0Working < L1Recent < L2Warm < L3Cold < L4Engram < L5Adapter <
/// L6Forbidden < L7Quarantine. Useful for promotion / demotion checks.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Ord, PartialOrd, Serialize, Deserialize)]
pub enum ResidencyLevel {
    /// Hot working memory — current attention, most volatile.
    L0Working,
    /// Recent context — last few turns, easy recall.
    L1Recent,
    /// Warm cache — likely to be referenced soon.
    L2Warm,
    /// Cold cache — infrequently referenced; still in process.
    L3Cold,
    /// **Pro+** — Engram tier (O(1) hash recall for static knowledge).
    L4Engram,
    /// **Pro+** — adapter cache (continual-learning weights).
    L5Adapter,
    /// **Research only** — Forbidden tier (Sovereign-class promotion via Secure Enclave seal).
    L6Forbidden,
    /// Quarantine — safe sink for rejected claims (τ = -1 or
    /// structurally invalid inputs).
    L7Quarantine,
}

impl ResidencyLevel {
    /// The five Core-allowed levels: L0–L3 working set + L7 Quarantine.
    pub const CORE_ALLOWED: [ResidencyLevel; 5] = [
        ResidencyLevel::L0Working,
        ResidencyLevel::L1Recent,
        ResidencyLevel::L2Warm,
        ResidencyLevel::L3Cold,
        ResidencyLevel::L7Quarantine,
    ];

    /// Whether this level is allowed in a Core / App Store build.
    /// A Core path that emits an L4–L6 target is a P0 tier-leakage bug.
    pub const fn is_core_allowed(self) -> bool {
        matches!(
            self,
            ResidencyLevel::L0Working
                | ResidencyLevel::L1Recent
                | ResidencyLevel::L2Warm
                | ResidencyLevel::L3Cold
                | ResidencyLevel::L7Quarantine
        )
    }

    /// Whether this level requires Pro / Research entitlements.
    /// Mirror of `!is_core_allowed()` for readability at call sites.
    pub const fn requires_pro_or_research(self) -> bool {
        matches!(
            self,
            ResidencyLevel::L4Engram | ResidencyLevel::L5Adapter | ResidencyLevel::L6Forbidden
        )
    }
}

/// Map a claim to its Core-tier residency target.
///
/// **Hot-path cost.** O(1) — single match arm + length check.
///
/// ## Mapping rules (seed)
///
/// - Composite without dependencies → L7Quarantine (structurally invalid).
/// - Definition → L2Warm (axiomatic, infrequent direct lookup).
/// - Empirical with strong evidence (≥3) → L1Recent; weak → L3Cold.
/// - Equation / Inequality / CodeInvariant → L1Recent (verifiable, keep hot).
/// - Causal → L2Warm (longitudinal evidence accrues slowly).
/// - Prime → L1Recent (foundational, frequent reference).
/// - Composite (with deps) → L0Working (active reasoning).
/// - Gap → L3Cold (unresolved, low display priority).
pub fn target_residency(claim: &Claim) -> ResidencyLevel {
    // Structural invariant: composite must have ≥1 dependency. (Two-or-more
    // is the π classifier's stricter rule; one is enough to avoid
    // quarantine because a single-dep composite is "incomplete" not
    // "invalid".)
    if matches!(claim.kind, ClaimType::Composite) && claim.dependencies.is_empty() {
        return ResidencyLevel::L7Quarantine;
    }

    match claim.kind {
        ClaimType::Definition => ResidencyLevel::L2Warm,
        ClaimType::Empirical => {
            if claim.evidence_count >= 3 {
                ResidencyLevel::L1Recent
            } else {
                ResidencyLevel::L3Cold
            }
        }
        ClaimType::Equation | ClaimType::Inequality | ClaimType::CodeInvariant => {
            ResidencyLevel::L1Recent
        }
        ClaimType::Causal => ResidencyLevel::L2Warm,
        ClaimType::Prime => ResidencyLevel::L1Recent,
        ClaimType::Composite => ResidencyLevel::L0Working,
        ClaimType::Gap => ResidencyLevel::L3Cold,
    }
}
