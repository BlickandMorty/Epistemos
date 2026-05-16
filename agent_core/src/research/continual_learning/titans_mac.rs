//! Source:
//! - Behrouz et al., "Titans: Learning to Memorize at Test Time",
//!   arXiv:2501.00663, 2025 — the Titans MAC (Memory As Context) lane:
//!   a small learned-memory module M (~1B params in the paper) updated
//!   at test time by minimizing the inner-loop residual ‖M·k − v‖².
//! - `docs/fusion/jordan's research/helios v3.md` Part III L_SE row +
//!   Part VII.2 Implication 4 ("L_SE surprise gradient is a Koopman-mode
//!   update; Titans is literally a streaming DMD of associative memory").
//! - Wang-Liang, ICLR 2025 spotlight MamKO, OpenReview hNjCVVm0EQ —
//!   the Koopman reading of SSM A-matrices that frames Titans' inner-
//!   loop step as a rank-1 Koopman-operator update.
//!
//! # J3 #4 — Titans-MAC surprise-gradient substrate (CPU reference)
//!
//! For each (k, v) pair the LMM minimizes:
//!
//! ```text
//! S_t = ‖M_{t-1} · k_t − v_t‖²            (the "surprise")
//! ∂S/∂M = 2 · (M · k − v) · k^T           (rank-1 outer product)
//! M_t = M_{t-1} − η · ∂S/∂M
//! ```
//!
//! Per Helios v3 Part VII.2 the rank-1 update is structurally equivalent
//! to a streaming Dynamic Mode Decomposition (DMD) of the associative
//! memory's Koopman operator. The substrate here is the bare math — no
//! Adam, no learning-rate schedule, no SEAL outer loop (those layer up
//! in J3 #5 / Phase 2+).
//!
//! ## Storage layout
//!
//! `LearnedMemoryModule.weights` is `out_dim × in_dim` row-major flat.
//! `weights[r * in_dim + c]` is the (r, c) entry. Matches the Rust
//! convention used by [`super::oftv2::OrthogonalMatrix`].

use serde::{Deserialize, Serialize};

/// Small learned-memory module. In the canonical Titans setup this is
/// a 1-layer linear map from key space to value space, updated at test
/// time. Real impls add more layers + non-linearities; the substrate
/// floor stops at one linear layer to keep the surprise math closed-form.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LearnedMemoryModule {
    pub out_dim: usize,
    pub in_dim: usize,
    pub weights: Vec<f32>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TitansError {
    ShapeMismatch { out_dim: usize, in_dim: usize, weights_len: usize },
    KeyDimMismatch { in_dim: usize, key_len: usize },
    ValueDimMismatch { out_dim: usize, value_len: usize },
    NonPositiveLearningRate { lr: f32 },
}

impl LearnedMemoryModule {
    pub fn zeros(out_dim: usize, in_dim: usize) -> Self {
        Self {
            out_dim,
            in_dim,
            weights: vec![0.0; out_dim * in_dim],
        }
    }

    pub fn new(out_dim: usize, in_dim: usize, weights: Vec<f32>) -> Result<Self, TitansError> {
        if weights.len() != out_dim * in_dim {
            return Err(TitansError::ShapeMismatch {
                out_dim,
                in_dim,
                weights_len: weights.len(),
            });
        }
        Ok(Self { out_dim, in_dim, weights })
    }

    /// `M · k` → `out`.
    pub fn predict(&self, k: &[f32], out: &mut [f32]) -> Result<(), TitansError> {
        if k.len() != self.in_dim {
            return Err(TitansError::KeyDimMismatch {
                in_dim: self.in_dim,
                key_len: k.len(),
            });
        }
        if out.len() != self.out_dim {
            return Err(TitansError::ValueDimMismatch {
                out_dim: self.out_dim,
                value_len: out.len(),
            });
        }
        for r in 0..self.out_dim {
            let mut acc: f32 = 0.0;
            for c in 0..self.in_dim {
                acc += self.weights[r * self.in_dim + c] * k[c];
            }
            out[r] = acc;
        }
        Ok(())
    }
}

/// `S_t = ‖M · k − v‖²`. The "surprise" in Titans-speak — large when
/// the LMM's prediction is far from the target.
pub fn surprise(m: &LearnedMemoryModule, k: &[f32], v: &[f32]) -> Result<f32, TitansError> {
    if v.len() != m.out_dim {
        return Err(TitansError::ValueDimMismatch {
            out_dim: m.out_dim,
            value_len: v.len(),
        });
    }
    let mut pred = vec![0.0_f32; m.out_dim];
    m.predict(k, &mut pred)?;
    let mut sum: f32 = 0.0;
    for r in 0..m.out_dim {
        let d = pred[r] - v[r];
        sum += d * d;
    }
    Ok(sum)
}

/// Apply one surprise-gradient step in place:
/// `M ← M − lr · 2 · (M · k − v) · k^T`.
/// Returns the pre-update surprise.
pub fn apply_surprise_update(
    m: &mut LearnedMemoryModule,
    k: &[f32],
    v: &[f32],
    lr: f32,
) -> Result<f32, TitansError> {
    if lr <= 0.0 {
        return Err(TitansError::NonPositiveLearningRate { lr });
    }
    if v.len() != m.out_dim {
        return Err(TitansError::ValueDimMismatch {
            out_dim: m.out_dim,
            value_len: v.len(),
        });
    }
    let mut pred = vec![0.0_f32; m.out_dim];
    m.predict(k, &mut pred)?;
    let mut residual_sq: f32 = 0.0;
    let mut delta = vec![0.0_f32; m.out_dim];
    for r in 0..m.out_dim {
        let d = pred[r] - v[r];
        delta[r] = d;
        residual_sq += d * d;
    }
    let scale = 2.0 * lr;
    for r in 0..m.out_dim {
        for c in 0..m.in_dim {
            m.weights[r * m.in_dim + c] -= scale * delta[r] * k[c];
        }
    }
    Ok(residual_sq)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zeros_module_predicts_zero() {
        let m = LearnedMemoryModule::zeros(3, 4);
        let mut out = vec![99.0_f32; 3];
        m.predict(&[1.0, 2.0, 3.0, 4.0], &mut out).unwrap();
        assert_eq!(out, vec![0.0; 3]);
    }

    #[test]
    fn shape_mismatch_on_construction_errors() {
        let err = LearnedMemoryModule::new(2, 3, vec![0.0; 5]).unwrap_err();
        assert_eq!(
            err,
            TitansError::ShapeMismatch { out_dim: 2, in_dim: 3, weights_len: 5 }
        );
    }

    #[test]
    fn surprise_zero_when_module_predicts_target() {
        let m = LearnedMemoryModule::new(2, 2, vec![1.0, 0.0, 0.0, 1.0]).unwrap();
        let k = vec![3.0, 4.0];
        let v = vec![3.0, 4.0];
        let s = surprise(&m, &k, &v).unwrap();
        assert!(s.abs() < 1e-6);
    }

    #[test]
    fn surprise_positive_when_prediction_off() {
        let m = LearnedMemoryModule::zeros(2, 2);
        let s = surprise(&m, &[1.0, 0.0], &[3.0, 4.0]).unwrap();
        assert!((s - 25.0).abs() < 1e-6);
    }

    #[test]
    fn single_update_strictly_reduces_surprise_on_overdetermined_target() {
        let mut m = LearnedMemoryModule::zeros(1, 2);
        let k = vec![1.0_f32, 1.0];
        let v = vec![2.0_f32];
        let pre = surprise(&m, &k, &v).unwrap();
        apply_surprise_update(&mut m, &k, &v, 0.1).unwrap();
        let post = surprise(&m, &k, &v).unwrap();
        assert!(post < pre, "post={} pre={}", post, post);
    }

    #[test]
    fn many_updates_converge_below_threshold() {
        let mut m = LearnedMemoryModule::zeros(1, 1);
        let k = vec![1.0_f32];
        let v = vec![5.0_f32];
        for _ in 0..200 {
            apply_surprise_update(&mut m, &k, &v, 0.05).unwrap();
        }
        let s = surprise(&m, &k, &v).unwrap();
        assert!(s < 1e-6, "did not converge, surprise={}", s);
    }

    #[test]
    fn apply_returns_pre_update_surprise() {
        let mut m = LearnedMemoryModule::zeros(2, 1);
        let s_pre_reported = apply_surprise_update(&mut m, &[1.0], &[2.0, 3.0], 0.1).unwrap();
        let s_pre_computed = 4.0 + 9.0;
        assert!((s_pre_reported - s_pre_computed).abs() < 1e-6);
    }

    #[test]
    fn non_positive_learning_rate_rejected() {
        let mut m = LearnedMemoryModule::zeros(1, 1);
        let err = apply_surprise_update(&mut m, &[1.0], &[1.0], 0.0).unwrap_err();
        assert_eq!(err, TitansError::NonPositiveLearningRate { lr: 0.0 });
    }

    #[test]
    fn key_dim_mismatch_errors() {
        let m = LearnedMemoryModule::zeros(2, 3);
        let mut out = vec![0.0_f32; 2];
        let err = m.predict(&[1.0, 2.0], &mut out).unwrap_err();
        assert_eq!(err, TitansError::KeyDimMismatch { in_dim: 3, key_len: 2 });
    }

    #[test]
    fn value_dim_mismatch_in_surprise_errors() {
        let m = LearnedMemoryModule::zeros(2, 2);
        let err = surprise(&m, &[1.0, 2.0], &[1.0]).unwrap_err();
        assert_eq!(err, TitansError::ValueDimMismatch { out_dim: 2, value_len: 1 });
    }

    #[test]
    fn rank_one_update_matches_outer_product_formula() {
        let mut m = LearnedMemoryModule::zeros(2, 2);
        let k = vec![1.0_f32, 0.0];
        let v = vec![3.0_f32, 5.0];
        apply_surprise_update(&mut m, &k, &v, 0.1).unwrap();
        assert!((m.weights[0] - (2.0 * 0.1 * 3.0)).abs() < 1e-6);
        assert!(m.weights[1].abs() < 1e-6);
        assert!((m.weights[2] - (2.0 * 0.1 * 5.0)).abs() < 1e-6);
        assert!(m.weights[3].abs() < 1e-6);
    }

    #[test]
    fn module_roundtrips_through_serde_json() {
        let m = LearnedMemoryModule::new(2, 2, vec![1.0, 2.0, 3.0, 4.0]).unwrap();
        let json = serde_json::to_string(&m).unwrap();
        let back: LearnedMemoryModule = serde_json::from_str(&json).unwrap();
        assert_eq!(m, back);
    }

    #[test]
    fn predict_after_update_moves_toward_target() {
        let mut m = LearnedMemoryModule::zeros(1, 1);
        let k = vec![1.0_f32];
        let v = vec![10.0_f32];
        let mut before = vec![0.0_f32];
        m.predict(&k, &mut before).unwrap();
        apply_surprise_update(&mut m, &k, &v, 0.1).unwrap();
        let mut after = vec![0.0_f32];
        m.predict(&k, &mut after).unwrap();
        assert!(after[0] > before[0]);
        assert!(after[0] < v[0]);
    }
}
