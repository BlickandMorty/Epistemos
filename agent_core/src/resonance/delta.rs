//! HELIOS V5 SCOPE-Rex Pro — `δ` directional operators.
//!
//! HELIOS-DELTA guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §G:
//!
//! > "δ 5 directional operators (upward generalization, downward
//! >  specialization, lateral resonance, etc.) — NEW
//! >  agent_core/src/resonance/delta.rs (Pro tier)"
//!
//! Pro tier substrate. The full Σ signature `[τ, δ, π, ρ, κ, η, λ]`
//! gains `δ` here when `pro-build` is on.

use serde::{Deserialize, Serialize};

/// One of the 5 directional operators in the Pro-tier δ ring.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DeltaOp {
    /// Upward generalization — abstract from a specific to a category.
    UpwardGeneralization,
    /// Downward specialization — refine a category to a specific.
    DownwardSpecialization,
    /// Lateral resonance — spread along same-tier neighbors.
    LateralResonance,
    /// Convergent gather — multiple sources collapse to one anchor.
    ConvergentGather,
    /// Divergent fan-out — one source spreads to multiple targets.
    DivergentFanout,
}

impl DeltaOp {
    /// All 5 directional operators in canonical iteration order.
    pub const ALL: [DeltaOp; 5] = [
        DeltaOp::UpwardGeneralization,
        DeltaOp::DownwardSpecialization,
        DeltaOp::LateralResonance,
        DeltaOp::ConvergentGather,
        DeltaOp::DivergentFanout,
    ];
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_lists_5_directional_operators() {
        assert_eq!(DeltaOp::ALL.len(), 5);
    }

    #[test]
    fn delta_serializes_in_snake_case() {
        for (op, expected) in [
            (DeltaOp::UpwardGeneralization, "\"upward_generalization\""),
            (
                DeltaOp::DownwardSpecialization,
                "\"downward_specialization\"",
            ),
            (DeltaOp::LateralResonance, "\"lateral_resonance\""),
            (DeltaOp::ConvergentGather, "\"convergent_gather\""),
            (DeltaOp::DivergentFanout, "\"divergent_fanout\""),
        ] {
            assert_eq!(serde_json::to_string(&op).unwrap(), expected);
        }
    }
}
