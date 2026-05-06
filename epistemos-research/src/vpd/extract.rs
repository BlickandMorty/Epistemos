//! HELIOS V5 W17 + PCF-1 — VPD extraction pipeline.
//!
//! HELIOS-W17 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W17 +
//! `docs/fusion/helios v5 updated.md` PART 5 T25 (PCF-1):
//!
//! > "Parameter Assembly Extraction Theorem (CANDIDATE) — given a
//! >  transformer with bounded weight matrices, the SPD/APD parameter
//! >  decomposition recovers ground-truth mechanisms in toy models
//! >  with reconstruction error → 0 as #components → ground-truth count."
//!
//! Citations:
//! - Bushnaq-Braun-Sharkey arXiv:2506.20790 (SPD)
//! - Braun et al. arXiv:2501.14926 (APD)

use serde::{Deserialize, Serialize};

/// One VPD-extracted parameter component. Rank-1 outer-product form:
/// `W_c ≈ U_c · V_c^T` where `U_c ∈ ℝ^{d_out}` and `V_c ∈ ℝ^{d_in}`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ParamComponent {
    pub component_id: u32,
    pub u: Vec<f32>,
    pub v: Vec<f32>,
    /// Whether this component is "alive" (firing on > threshold prompts).
    pub alive: bool,
}

/// VPD extraction output. Holds the extracted component library +
/// reconstruction error against the input weight matrix.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct VpdExtraction {
    pub components: Vec<ParamComponent>,
    pub reconstruction_error: f32,
}

/// Reconstruct a single weight matrix from a component library.
/// Sums `U_c · V_c^T` over alive components. Used as the Tier-1
/// reconstruction-error oracle for the M2 Max falsifier rig (W25).
pub fn reconstruct(components: &[ParamComponent], rows: usize, cols: usize) -> Vec<f32> {
    let mut out = vec![0.0f32; rows * cols];
    for c in components.iter().filter(|c| c.alive) {
        for r in 0..rows {
            for col in 0..cols {
                out[r * cols + col] += c.u[r] * c.v[col];
            }
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_components_reconstruct_to_zero_matrix() {
        let out = reconstruct(&[], 3, 4);
        assert_eq!(out, vec![0.0f32; 12]);
    }

    #[test]
    fn dead_components_skipped() {
        let dead = ParamComponent {
            component_id: 0,
            u: vec![1.0, 1.0],
            v: vec![1.0, 1.0],
            alive: false,
        };
        let out = reconstruct(&[dead], 2, 2);
        assert_eq!(out, vec![0.0f32; 4]);
    }

    #[test]
    fn single_alive_component_round_trip() {
        let alive = ParamComponent {
            component_id: 0,
            u: vec![1.0, 2.0],
            v: vec![3.0, 4.0],
            alive: true,
        };
        let out = reconstruct(&[alive], 2, 2);
        // u v^T = [[1*3, 1*4], [2*3, 2*4]] = [[3, 4], [6, 8]]
        assert_eq!(out, vec![3.0, 4.0, 6.0, 8.0]);
    }
}
