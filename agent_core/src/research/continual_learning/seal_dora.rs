//! Source:
//! - Liu et al., "DoRA: Weight-Decomposed Low-Rank Adaptation",
//!   arXiv:2402.09353, ICML 2024 — DoRA decomposes pre-trained weights
//!   into magnitude (per-output-row scalar) + direction (unit-norm
//!   matrix), then applies a low-rank LoRA update ONLY to the direction.
//!   Claim: closes most of the LoRA-vs-full-fine-tune accuracy gap.
//! - Zweiger-Pari et al., "Self-Edited Active Learning (SEAL)",
//!   arXiv:2506.10943, 2026 — outer-RL nightly self-edits compiled into
//!   per-user adapter. Pairs naturally with DoRA: SEAL produces the
//!   nightly Δdirection update, DoRA composes it onto base direction.
//! - `docs/fusion/jordan's research/helios v3.md` Part III L_SE row —
//!   "Titans-MAC online + SEAL outer-RL nightly self-edits compiled into
//!   per-user DoRA. Base Qwen3-8B weights are immutable."
//!
//! # J3 #5 — SEAL-DoRA substrate (CPU reference, completes J3)
//!
//! DoRA decomposition for a base weight matrix `W ∈ R^{out × in}`:
//!
//! ```text
//! m_r = ‖W[r, :]‖             (per-row magnitude)
//! V[r, :] = W[r, :] / m_r     (per-row unit-norm direction)
//! ```
//!
//! The adapted weight at inference time is:
//!
//! ```text
//! V'[r, :] = (V[r, :] + ΔV[r, :]) / ‖V[r, :] + ΔV[r, :]‖
//! W'[r, :] = m_r · V'[r, :]
//! ```
//!
//! `ΔV = B · A` is the LoRA delta (rank `r`, `A ∈ R^{r × in}`,
//! `B ∈ R^{out × r}`). SEAL produces `ΔV` nightly via outer-RL self-edits
//! (the outer loop is beyond substrate-floor scope — documented as
//! NOT-STARTED below).
//!
//! ## "Never Retrain" invariant preserved
//!
//! Base `m` and `V` are immutable. All adaptation lives in `ΔV`. This
//! matches the Helios v3 L_SE doctrine: base Qwen3-8B weights never
//! change; the per-user DoRA adapter carries everything user-specific.
//!
//! ## NOT-STARTED in this substrate floor
//!
//! - SEAL outer-RL self-edit loop (needs reward model + replay buffer).
//! - DoRA gradient backprop through the normalization (needs autograd
//!   plumbing — Burn / Candle).
//! - Per-user adapter serialization envelope (will live in a future
//!   Wave 9+ integration layer).

use serde::{Deserialize, Serialize};

/// DoRA decomposition of a base weight matrix. Both `magnitude` and
/// `direction` are derived from the same source `W` at adapter-load
/// time; treat them as immutable in normal use.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DoraDecomposition {
    pub out_dim: usize,
    pub in_dim: usize,
    pub magnitude: Vec<f32>,
    pub direction: Vec<f32>,
}

/// Rank-`r` LoRA-style direction delta. `a` is `rank × in_dim` row-major;
/// `b` is `out_dim × rank` row-major. `ΔV[r, :] = (B · A)[r, :]`.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LoraDelta {
    pub out_dim: usize,
    pub in_dim: usize,
    pub rank: usize,
    pub a: Vec<f32>,
    pub b: Vec<f32>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SealDoraError {
    ShapeMismatch { kind: &'static str, expected: usize, actual: usize },
    DimensionMismatch { dora_dim: usize, lora_dim: usize, axis: &'static str },
    /// A direction row had zero norm — happens when the caller decomposed
    /// a base weight matrix with an all-zero row. Surfaces so the caller
    /// can drop / regularize that row before adapter composition.
    ZeroNormDirection { row: usize },
}

impl DoraDecomposition {
    /// Decompose `weights` (row-major `out_dim × in_dim`) into magnitude +
    /// unit-norm direction. Rejects all-zero rows.
    pub fn from_weights(out_dim: usize, in_dim: usize, weights: &[f32]) -> Result<Self, SealDoraError> {
        if weights.len() != out_dim * in_dim {
            return Err(SealDoraError::ShapeMismatch {
                kind: "weights",
                expected: out_dim * in_dim,
                actual: weights.len(),
            });
        }
        let mut magnitude = vec![0.0_f32; out_dim];
        let mut direction = vec![0.0_f32; out_dim * in_dim];
        for r in 0..out_dim {
            let row = &weights[r * in_dim..(r + 1) * in_dim];
            let norm_sq: f32 = row.iter().map(|v| v * v).sum();
            let norm = norm_sq.sqrt();
            if norm == 0.0 {
                return Err(SealDoraError::ZeroNormDirection { row: r });
            }
            magnitude[r] = norm;
            for c in 0..in_dim {
                direction[r * in_dim + c] = row[c] / norm;
            }
        }
        Ok(Self { out_dim, in_dim, magnitude, direction })
    }
}

impl LoraDelta {
    pub fn zeros(out_dim: usize, in_dim: usize, rank: usize) -> Self {
        Self {
            out_dim,
            in_dim,
            rank,
            a: vec![0.0; rank * in_dim],
            b: vec![0.0; out_dim * rank],
        }
    }

    /// Materialize `ΔV = B · A` as row-major `out_dim × in_dim`.
    pub fn materialize(&self) -> Vec<f32> {
        let mut delta = vec![0.0_f32; self.out_dim * self.in_dim];
        for r in 0..self.out_dim {
            for c in 0..self.in_dim {
                let mut acc: f32 = 0.0;
                for k in 0..self.rank {
                    acc += self.b[r * self.rank + k] * self.a[k * self.in_dim + c];
                }
                delta[r * self.in_dim + c] = acc;
            }
        }
        delta
    }
}

/// Compose DoRA + LoRA delta into the adapted weight matrix `W'`:
///
/// `V' = (V + ΔV) / ‖V + ΔV‖`  (per-row normalization)
/// `W'[r, :] = m_r · V'[r, :]`
pub fn compose_dora(
    dora: &DoraDecomposition,
    delta: &LoraDelta,
) -> Result<Vec<f32>, SealDoraError> {
    if dora.out_dim != delta.out_dim {
        return Err(SealDoraError::DimensionMismatch {
            dora_dim: dora.out_dim,
            lora_dim: delta.out_dim,
            axis: "out_dim",
        });
    }
    if dora.in_dim != delta.in_dim {
        return Err(SealDoraError::DimensionMismatch {
            dora_dim: dora.in_dim,
            lora_dim: delta.in_dim,
            axis: "in_dim",
        });
    }
    let delta_mat = delta.materialize();
    let mut adapted = vec![0.0_f32; dora.out_dim * dora.in_dim];
    for r in 0..dora.out_dim {
        let row_base = r * dora.in_dim;
        let mut new_dir = vec![0.0_f32; dora.in_dim];
        for c in 0..dora.in_dim {
            new_dir[c] = dora.direction[row_base + c] + delta_mat[row_base + c];
        }
        let norm_sq: f32 = new_dir.iter().map(|v| v * v).sum();
        let norm = norm_sq.sqrt();
        if norm == 0.0 {
            return Err(SealDoraError::ZeroNormDirection { row: r });
        }
        for c in 0..dora.in_dim {
            adapted[row_base + c] = dora.magnitude[r] * new_dir[c] / norm;
        }
    }
    Ok(adapted)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx_eq_slices(a: &[f32], b: &[f32], tol: f32) -> bool {
        a.len() == b.len() && a.iter().zip(b.iter()).all(|(x, y)| (x - y).abs() < tol)
    }

    #[test]
    fn decomposition_recovers_original_weights() {
        let w = vec![3.0, 4.0, 6.0, 8.0];
        let dora = DoraDecomposition::from_weights(2, 2, &w).unwrap();
        let zero_delta = LoraDelta::zeros(2, 2, 1);
        let recovered = compose_dora(&dora, &zero_delta).unwrap();
        assert!(approx_eq_slices(&recovered, &w, 1e-5));
    }

    #[test]
    fn magnitude_matches_row_norms() {
        let w = vec![3.0, 4.0, 6.0, 8.0];
        let dora = DoraDecomposition::from_weights(2, 2, &w).unwrap();
        assert!((dora.magnitude[0] - 5.0).abs() < 1e-6);
        assert!((dora.magnitude[1] - 10.0).abs() < 1e-6);
    }

    #[test]
    fn direction_has_unit_row_norm() {
        let w = vec![3.0, 4.0];
        let dora = DoraDecomposition::from_weights(1, 2, &w).unwrap();
        let norm: f32 = dora.direction.iter().map(|v| v * v).sum::<f32>().sqrt();
        assert!((norm - 1.0).abs() < 1e-6);
    }

    #[test]
    fn zero_row_rejected_at_decomposition() {
        let w = vec![0.0_f32; 4];
        let err = DoraDecomposition::from_weights(2, 2, &w).unwrap_err();
        assert_eq!(err, SealDoraError::ZeroNormDirection { row: 0 });
    }

    #[test]
    fn shape_mismatch_rejected_at_decomposition() {
        let err = DoraDecomposition::from_weights(2, 2, &[1.0, 2.0]).unwrap_err();
        assert_eq!(
            err,
            SealDoraError::ShapeMismatch { kind: "weights", expected: 4, actual: 2 }
        );
    }

    #[test]
    fn lora_delta_materialize_is_outer_product_for_rank_one() {
        let delta = LoraDelta {
            out_dim: 2,
            in_dim: 3,
            rank: 1,
            a: vec![1.0, 2.0, 3.0],
            b: vec![4.0, 5.0],
        };
        let mat = delta.materialize();
        assert_eq!(mat, vec![4.0, 8.0, 12.0, 5.0, 10.0, 15.0]);
    }

    #[test]
    fn out_dim_mismatch_rejected_in_compose() {
        let dora = DoraDecomposition::from_weights(2, 2, &[1.0, 0.0, 0.0, 1.0]).unwrap();
        let delta = LoraDelta::zeros(3, 2, 1);
        let err = compose_dora(&dora, &delta).unwrap_err();
        assert_eq!(
            err,
            SealDoraError::DimensionMismatch { dora_dim: 2, lora_dim: 3, axis: "out_dim" }
        );
    }

    #[test]
    fn in_dim_mismatch_rejected_in_compose() {
        let dora = DoraDecomposition::from_weights(2, 2, &[1.0, 0.0, 0.0, 1.0]).unwrap();
        let delta = LoraDelta::zeros(2, 3, 1);
        let err = compose_dora(&dora, &delta).unwrap_err();
        assert_eq!(
            err,
            SealDoraError::DimensionMismatch { dora_dim: 2, lora_dim: 3, axis: "in_dim" }
        );
    }

    #[test]
    fn nonzero_delta_changes_direction_but_preserves_magnitude() {
        let w = vec![1.0_f32, 0.0];
        let dora = DoraDecomposition::from_weights(1, 2, &w).unwrap();
        let delta = LoraDelta {
            out_dim: 1,
            in_dim: 2,
            rank: 1,
            a: vec![0.0, 1.0],
            b: vec![1.0],
        };
        let adapted = compose_dora(&dora, &delta).unwrap();
        let adapted_norm: f32 = adapted.iter().map(|v| v * v).sum::<f32>().sqrt();
        assert!((adapted_norm - dora.magnitude[0]).abs() < 1e-5);
        assert!(adapted[1] > 0.0);
    }

    #[test]
    fn rank_two_lora_compose() {
        let dora = DoraDecomposition::from_weights(2, 2, &[1.0, 0.0, 0.0, 1.0]).unwrap();
        let delta = LoraDelta {
            out_dim: 2,
            in_dim: 2,
            rank: 2,
            a: vec![1.0, 0.0, 0.0, 1.0],
            b: vec![0.1, 0.0, 0.0, 0.1],
        };
        let adapted = compose_dora(&dora, &delta).unwrap();
        assert!(adapted[0] > 0.99 && adapted[0] <= 1.0);
        assert!(adapted[3] > 0.99 && adapted[3] <= 1.0);
    }

    #[test]
    fn dora_decomposition_roundtrips_through_serde_json() {
        let dora = DoraDecomposition::from_weights(2, 2, &[3.0, 4.0, 6.0, 8.0]).unwrap();
        let json = serde_json::to_string(&dora).unwrap();
        let back: DoraDecomposition = serde_json::from_str(&json).unwrap();
        assert_eq!(dora, back);
    }

    #[test]
    fn lora_delta_zeros_constructor_produces_zero_materialization() {
        let delta = LoraDelta::zeros(3, 4, 2);
        let mat = delta.materialize();
        assert!(mat.iter().all(|&v| v == 0.0));
        assert_eq!(mat.len(), 12);
    }

    #[test]
    fn compose_dora_preserves_immutable_base_decomposition() {
        let dora = DoraDecomposition::from_weights(1, 2, &[3.0, 4.0]).unwrap();
        let pre_dir = dora.direction.clone();
        let pre_mag = dora.magnitude.clone();
        let delta = LoraDelta {
            out_dim: 1,
            in_dim: 2,
            rank: 1,
            a: vec![1.0, -1.0],
            b: vec![0.5],
        };
        let _ = compose_dora(&dora, &delta).unwrap();
        assert_eq!(dora.direction, pre_dir);
        assert_eq!(dora.magnitude, pre_mag);
    }
}
