//! HELIOS V5 W21 + PCF-5 — Active Rank-One Runtime.
//!
//! HELIOS-W21 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W21 +
//! `docs/fusion/helios v5 updated.md` PART 5 T33 (PCF-5):
//!
//! > "Per-step, only the rank-one subcomponents whose pre-activation
//! >  exceeds threshold τ contribute meaningfully (≥ 1−δ of output
//! >  norm)."
//!
//! Lane 5 Vault — NEVER in MAS. Runtime acceleration gated until
//! kernels beat dense fallback on M2 Max per W25 falsifier rig.

use serde::{Deserialize, Serialize};

/// One active rank-one subcomponent firing at a single forward-pass
/// step. Captures the (component_id, magnitude) pair so the runtime
/// can route through a sparse subset.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct ActiveSubcomponent {
    pub component_id: u32,
    pub magnitude: f32,
}

/// Selection of active subcomponents for a single forward-pass step.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct ActiveStep {
    pub step_index: u32,
    pub active: Vec<ActiveSubcomponent>,
    /// Threshold τ used for selection.
    pub tau: f32,
}

impl ActiveStep {
    /// Filter a candidate set of subcomponents by magnitude > τ.
    /// Returns a fresh ActiveStep containing only the ones above
    /// threshold.
    pub fn select_above_threshold(
        step_index: u32,
        candidates: &[ActiveSubcomponent],
        tau: f32,
    ) -> Self {
        Self {
            step_index,
            active: candidates
                .iter()
                .copied()
                .filter(|c| c.magnitude > tau)
                .collect(),
            tau,
        }
    }

    /// Total magnitude across the active set.
    pub fn total_magnitude(&self) -> f32 {
        self.active.iter().map(|c| c.magnitude.abs()).sum()
    }

    /// Number of active subcomponents at this step.
    pub fn count(&self) -> usize {
        self.active.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_candidate_set_yields_empty_active() {
        let s = ActiveStep::select_above_threshold(0, &[], 0.5);
        assert_eq!(s.count(), 0);
        assert!((s.total_magnitude() - 0.0).abs() < 1e-6);
    }

    #[test]
    fn high_threshold_drops_all_below() {
        let candidates = [
            ActiveSubcomponent { component_id: 0, magnitude: 0.1 },
            ActiveSubcomponent { component_id: 1, magnitude: 0.4 },
            ActiveSubcomponent { component_id: 2, magnitude: 0.2 },
        ];
        let s = ActiveStep::select_above_threshold(0, &candidates, 0.5);
        assert_eq!(s.count(), 0);
    }

    #[test]
    fn moderate_threshold_keeps_some() {
        let candidates = [
            ActiveSubcomponent { component_id: 0, magnitude: 0.1 },
            ActiveSubcomponent { component_id: 1, magnitude: 0.6 },
            ActiveSubcomponent { component_id: 2, magnitude: 0.3 },
        ];
        let s = ActiveStep::select_above_threshold(0, &candidates, 0.2);
        assert_eq!(s.count(), 2);
        assert_eq!(s.active[0].component_id, 1);
        assert_eq!(s.active[1].component_id, 2);
    }
}
