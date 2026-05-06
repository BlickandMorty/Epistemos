//! HELIOS V5 SCOPE-Rex Pro — `ρ` resonance.
//!
//! HELIOS-RHO guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §G:
//!
//! > "ρ resonance (claim-graph propagation) — NEW
//! >  agent_core/src/resonance/rho.rs (Pro tier)"
//!
//! Pro tier substrate. Computes resonance scores between claim
//! pairs by walking the claim-graph and accumulating shared
//! evidence weight.

use serde::{Deserialize, Serialize};

/// Resonance score between two claims, in `[0, 1]`. 1.0 = strong
/// shared support; 0.0 = no shared evidence.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct ResonanceScore(pub f32);

impl ResonanceScore {
    pub fn new(score: f32) -> Self {
        Self(score.clamp(0.0, 1.0))
    }

    pub fn value(self) -> f32 {
        self.0
    }
}

/// Compute resonance from two evidence-weight signals (per-source
/// shared evidence count). Pure function: `ρ = shared / (shared +
/// disjoint + ε)` clamped to [0, 1].
pub fn rho_from_evidence_overlap(shared: f32, disjoint: f32) -> ResonanceScore {
    let total = shared + disjoint;
    if total <= 0.0 {
        return ResonanceScore(0.0);
    }
    ResonanceScore::new(shared / total)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn score_clamps_to_unit_interval() {
        assert_eq!(ResonanceScore::new(-0.5).value(), 0.0);
        assert_eq!(ResonanceScore::new(1.5).value(), 1.0);
        assert!((ResonanceScore::new(0.7).value() - 0.7).abs() < 1e-6);
    }

    #[test]
    fn full_overlap_yields_one() {
        let r = rho_from_evidence_overlap(10.0, 0.0);
        assert!((r.value() - 1.0).abs() < 1e-6);
    }

    #[test]
    fn no_overlap_yields_zero() {
        let r = rho_from_evidence_overlap(0.0, 10.0);
        assert!(r.value() < 1e-6);
    }

    #[test]
    fn empty_evidence_yields_zero_safely() {
        let r = rho_from_evidence_overlap(0.0, 0.0);
        assert!(r.value() < 1e-6);
    }
}
