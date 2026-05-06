//! Resonance Gate τ + π + λ daemon — Core seed.
//!
//! This module is the **first piece of the visible Resonance Gate philosophy**
//! per `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.1. It is the
//! Core entry: τ (truth, Kleene K3 ternary), π (prime/composite/gap
//! classification over 9 typed claims), and λ (residency target L0–L3).
//!
//! ## Tier scope
//!
//! - **Core** (this module): τ + π + λ only. CPU-only, synchronous,
//!   no Z3 / Kani / Lean inline (they live off the hot path per Annex A.2).
//! - **Pro** (future, separate module): δ (direction, Koopman) +
//!   ρ (resonance, Laplace–Beltrami).
//! - **Research** (future, separate module): κ (KAM stability,
//!   Diophantine) + η (evidence, Engram + search).
//!
//! ## Hot-path target
//!
//! Doctrine §4.1 sets the per-token signature target at < 100 µs.
//! `compute_signature_core` is a pure function over a `Claim` value with
//! no allocations beyond what `Claim` itself owns.
//!
//! ## What is NOT here
//!
//! - No FFI surface (Swift consumer + UniFFI bridge are a separate slice).
//! - No `agent_loop.rs` integration (signature emission is also separate).
//! - No δ / ρ / κ / η scaffolding (Pro / Research only).
//! - No Z3 / Lean / Kani / Kissat calls (T2 ceiling per Annex A.2).
//! - No Metal / MLX / ANE imports (CPU-only seed).

pub mod lambda;
pub mod pi;
pub mod tau;

// HELIOS V5 SCOPE-Rex Pro extension — δ + ρ. Built when `pro-build`
// feature is on. Per docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md §G.
#[cfg(feature = "pro-build")]
pub mod delta;
#[cfg(feature = "pro-build")]
pub mod rho;

// HELIOS V5 SCOPE-Rex Research extension — κ + η. Built when
// `research` feature is on. Per same doc §G.
#[cfg(feature = "research")]
pub mod eta;
#[cfg(feature = "research")]
pub mod kappa;

pub use lambda::{target_residency, ResidencyLevel};
pub use pi::{classify, ClaimClass, ClaimType};
pub use tau::{evaluate_truth, Truth};

use serde::{Deserialize, Serialize};

/// Opaque reference to a previously-known claim. The Core seed treats this
/// as a u64 nonce; future tiers may attach a real claim graph identifier.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Ord, PartialOrd, Serialize, Deserialize)]
pub struct ClaimRef(pub u64);

/// Input to the Resonance Gate τ + π + λ daemon.
///
/// The seed deliberately keeps the input tiny: a typed kind, a statement
/// (carried for downstream display + audit, not used by τ/π/λ math), a
/// dependency list (used by π for compositeness), and an evidence count
/// (used by τ + π for confidence).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Claim {
    pub kind: ClaimType,
    pub statement: String,
    pub dependencies: Vec<ClaimRef>,
    pub evidence_count: u32,
}

/// Core-tier Resonance signature — the τ + π + λ subset of the full
/// 7-field Σ defined in doctrine §4.1.
///
/// Pro tier extends with `direction: Direction` + `resonance: f32`.
/// Research tier extends with `kam_stability: f32` + `evidence: EvidenceStatus`.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct ResonanceSignatureCore {
    pub truth: Truth,
    pub class: ClaimClass,
    pub residency: ResidencyLevel,
}

impl ResonanceSignatureCore {
    /// Whether this signature passes the doctrine §4.1 invariant 1: "no
    /// token with τ = -1 ever reaches the user." Used by downstream
    /// emission paths to short-circuit before display.
    pub const fn passes_truth_invariant(&self) -> bool {
        !matches!(self.truth, Truth::False)
    }

    /// Whether this signature is Core-allowed. Returns `false` for any
    /// Pro/Research-only residency level (L4–L6); a Core build that
    /// produces such a signature is a tier-leakage bug.
    pub const fn is_core_compatible(&self) -> bool {
        self.residency.is_core_allowed()
    }
}

/// Compute the Core-tier τ + π + λ signature for a claim.
///
/// **Pure function.** Same input → same output. No I/O. No async. No
/// allocation beyond what `Claim` already owns.
pub fn compute_signature_core(claim: &Claim) -> ResonanceSignatureCore {
    ResonanceSignatureCore {
        truth: evaluate_truth(claim),
        class: classify(claim),
        residency: target_residency(claim),
    }
}

// ---------------------------------------------------------------------------
// HELIOS V5 — Pro / Research tier Σ-signature composition.
//
// Per docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md §G:
//
//   Σ(x) = [τ truth, δ direction, π prime/composite/gap,
//           ρ resonance, κ KAM, η evidence, λ residency]
//
// Core tier ships [τ, π, λ] (3 of 7) above. Pro tier composes with
// δ + ρ to ship 5 of 7. Research tier adds κ + η for the full 7.
// ---------------------------------------------------------------------------

/// Pro-tier Σ-signature — Core fields plus δ direction + ρ resonance.
///
/// Built when `pro-build` feature is on. Wire format mirrors the
/// Core signature with two additional fields appended.
#[cfg(feature = "pro-build")]
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct ResonanceSignaturePro {
    pub truth: Truth,
    pub class: ClaimClass,
    pub residency: ResidencyLevel,
    pub direction: delta::DeltaOp,
    pub resonance: rho::ResonanceScore,
}

/// Pro-tier composition input — additional context beyond the Claim.
#[cfg(feature = "pro-build")]
#[derive(Clone, Copy, Debug, PartialEq, Default)]
pub struct ProComposeContext {
    pub direction: Option<delta::DeltaOp>,
    /// Shared evidence weight for ρ resonance.
    pub shared_evidence: f32,
    /// Disjoint evidence weight for ρ resonance.
    pub disjoint_evidence: f32,
}

/// Compose the 5-field Pro Σ-signature `[τ, π, λ, δ, ρ]`.
#[cfg(feature = "pro-build")]
pub fn compute_signature_pro(claim: &Claim, ctx: &ProComposeContext) -> ResonanceSignaturePro {
    let core = compute_signature_core(claim);
    ResonanceSignaturePro {
        truth: core.truth,
        class: core.class,
        residency: core.residency,
        direction: ctx.direction.unwrap_or(delta::DeltaOp::LateralResonance),
        resonance: rho::rho_from_evidence_overlap(ctx.shared_evidence, ctx.disjoint_evidence),
    }
}

/// Research-tier Σ-signature — full 7-field surface
/// `[τ, π, λ, δ, ρ, κ, η]`.
///
/// Built when `research` feature is on. The full Σ signature lands
/// here per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md`
/// §G "Research-tier wiring".
#[cfg(feature = "research")]
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct ResonanceSignatureResearch {
    pub truth: Truth,
    pub class: ClaimClass,
    pub residency: ResidencyLevel,
    pub kam_stability: kappa::KamStabilityScore,
    pub evidence: eta::EvidenceSupremacy,
}

/// Research-tier composition input.
#[cfg(feature = "research")]
#[derive(Clone, Copy, Debug, PartialEq, Default)]
pub struct ResearchComposeContext {
    /// L² deviation of the routing trajectory under perturbation.
    pub trajectory_deviation_l2: f32,
    /// Perturbation magnitude.
    pub perturbation_magnitude: f32,
    /// Normalized evidence weight for η classification.
    pub evidence_weight: f32,
}

/// Compose the Research Σ-signature `[τ, π, λ, κ, η]`. (Note: this
/// returns a 5-field struct rather than the full 7 because δ + ρ
/// require the Pro feature; the full 7-field compose lives below.)
#[cfg(feature = "research")]
pub fn compute_signature_research(
    claim: &Claim,
    ctx: &ResearchComposeContext,
) -> ResonanceSignatureResearch {
    let core = compute_signature_core(claim);
    ResonanceSignatureResearch {
        truth: core.truth,
        class: core.class,
        residency: core.residency,
        kam_stability: kappa::kappa_from_deviation(
            ctx.trajectory_deviation_l2,
            ctx.perturbation_magnitude,
        ),
        evidence: eta::eta_classify(ctx.evidence_weight),
    }
}

/// Full 7-field Σ-signature — Core + Pro + Research composed
/// together. Built when BOTH `pro-build` and `research` features
/// are on.
#[cfg(all(feature = "pro-build", feature = "research"))]
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct ResonanceSignatureFull {
    pub truth: Truth,
    pub class: ClaimClass,
    pub residency: ResidencyLevel,
    pub direction: delta::DeltaOp,
    pub resonance: rho::ResonanceScore,
    pub kam_stability: kappa::KamStabilityScore,
    pub evidence: eta::EvidenceSupremacy,
}

/// Compose the full 7-field Σ.
#[cfg(all(feature = "pro-build", feature = "research"))]
pub fn compute_signature_full(
    claim: &Claim,
    pro_ctx: &ProComposeContext,
    research_ctx: &ResearchComposeContext,
) -> ResonanceSignatureFull {
    let pro = compute_signature_pro(claim, pro_ctx);
    let research = compute_signature_research(claim, research_ctx);
    ResonanceSignatureFull {
        truth: pro.truth,
        class: pro.class,
        residency: pro.residency,
        direction: pro.direction,
        resonance: pro.resonance,
        kam_stability: research.kam_stability,
        evidence: research.evidence,
    }
}

#[cfg(test)]
mod compose_tests {
    use super::*;

    fn sample_claim() -> Claim {
        Claim {
            kind: ClaimType::Empirical,
            statement: "x".to_string(),
            dependencies: vec![],
            evidence_count: 5,
        }
    }

    #[cfg(feature = "pro-build")]
    #[test]
    fn pro_compose_produces_5_field_signature() {
        let claim = sample_claim();
        let ctx = ProComposeContext {
            direction: Some(delta::DeltaOp::UpwardGeneralization),
            shared_evidence: 8.0,
            disjoint_evidence: 2.0,
        };
        let sig = compute_signature_pro(&claim, &ctx);
        assert_eq!(sig.direction, delta::DeltaOp::UpwardGeneralization);
        // ρ from 8/(8+2) = 0.8.
        assert!((sig.resonance.value() - 0.8).abs() < 1e-6);
    }

    #[cfg(feature = "research")]
    #[test]
    fn research_compose_produces_kam_eta_fields() {
        let claim = sample_claim();
        let ctx = ResearchComposeContext {
            trajectory_deviation_l2: 0.0,
            perturbation_magnitude: 1.0,
            evidence_weight: 0.9,
        };
        let sig = compute_signature_research(&claim, &ctx);
        // κ from zero deviation = full stability.
        assert!((sig.kam_stability.value() - 1.0).abs() < 1e-6);
        // η at 0.9 = Strong.
        assert_eq!(sig.evidence, eta::EvidenceSupremacy::Strong);
    }

    #[cfg(all(feature = "pro-build", feature = "research"))]
    #[test]
    fn full_compose_returns_all_seven_fields() {
        let claim = sample_claim();
        let pro_ctx = ProComposeContext {
            direction: Some(delta::DeltaOp::ConvergentGather),
            shared_evidence: 10.0,
            disjoint_evidence: 0.0,
        };
        let research_ctx = ResearchComposeContext {
            trajectory_deviation_l2: 1.0,
            perturbation_magnitude: 1.0,
            evidence_weight: 0.5,
        };
        let sig = compute_signature_full(&claim, &pro_ctx, &research_ctx);
        // All 7 fields present.
        assert_eq!(sig.direction, delta::DeltaOp::ConvergentGather);
        assert!((sig.resonance.value() - 1.0).abs() < 1e-6);
        assert!((sig.kam_stability.value() - 0.5).abs() < 1e-6);
        assert_eq!(sig.evidence, eta::EvidenceSupremacy::Edge);
    }
}
