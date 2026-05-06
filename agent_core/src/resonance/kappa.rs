//! HELIOS V5 SCOPE-Rex Research — `κ` KAM stability.
//!
//! HELIOS-KAPPA guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §G:
//!
//! > "κ KAM (KAM-stability of routing trajectories under perturbation)
//! >  — NEW agent_core/src/resonance/kappa.rs (Research)"
//!
//! Research tier substrate. Computes a KAM-stability score for a
//! routing trajectory under bounded perturbation. The full Σ
//! signature `[τ, δ, π, ρ, κ, η, λ]` gains `κ` here when `research`
//! feature is on.

use serde::{Deserialize, Serialize};

/// KAM-stability score for a routing trajectory under perturbation.
/// 1.0 = stable; 0.0 = trajectory collapses under perturbation.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct KamStabilityScore(pub f32);

impl KamStabilityScore {
    pub fn new(score: f32) -> Self {
        Self(score.clamp(0.0, 1.0))
    }

    pub fn value(self) -> f32 {
        self.0
    }
}

/// Compute κ stability from observed trajectory deviation under a
/// fixed perturbation magnitude. `deviation_l2` is the L² distance
/// between unperturbed and perturbed trajectories; `perturbation`
/// is the perturbation magnitude. Lower deviation per unit
/// perturbation = higher stability.
pub fn kappa_from_deviation(deviation_l2: f32, perturbation: f32) -> KamStabilityScore {
    if perturbation <= 0.0 {
        // Zero perturbation: undefined; default to maximally stable.
        return KamStabilityScore(1.0);
    }
    let ratio = deviation_l2 / perturbation;
    // Map ratio ∈ [0, ∞) to stability ∈ [0, 1] via 1 / (1 + ratio).
    KamStabilityScore::new(1.0 / (1.0 + ratio))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zero_deviation_yields_full_stability() {
        let k = kappa_from_deviation(0.0, 1.0);
        assert!((k.value() - 1.0).abs() < 1e-6);
    }

    #[test]
    fn matched_deviation_yields_half_stability() {
        let k = kappa_from_deviation(1.0, 1.0);
        assert!((k.value() - 0.5).abs() < 1e-6);
    }

    #[test]
    fn very_high_deviation_approaches_zero_stability() {
        let k = kappa_from_deviation(1000.0, 1.0);
        assert!(k.value() < 0.01);
    }

    #[test]
    fn zero_perturbation_yields_full_stability_safely() {
        let k = kappa_from_deviation(0.5, 0.0);
        assert!((k.value() - 1.0).abs() < 1e-6);
    }
}
