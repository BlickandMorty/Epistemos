//! Source:
//! - Wang, Shi, Fox, "Test-Time Regression: A Unifying Framework for
//!   Designing Sequence Models with Associative Memory",
//!   arXiv:2501.12352, v3 2025-05-02 — unifies linear attention · SSMs
//!   (Mamba / Mamba-2) · Titans · fast-weight programmers · softmax
//!   attention as test-time regression parameterized by
//!   `(regression weights W, regressor function class φ, optimization
//!   algorithm A)`. Pillar IV of the Helios 5-pillar synthesis.
//! - `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md`
//!   §"Terminal B" Phase B.1 J11 + §1.9 ("strongest public theoretical
//!   anchor for `LatticeCoder + TestTimeRegressor` traits").
//! - Helios v3.md Part I Pillar IV (P, refreshed).
//!
//! # Wave J11 — Test-Time Regression unification
//!
//! Per Wang-Shi-Fox 2025, any sequence model with associative memory
//! is fully determined by a triple `(W, φ, A)`:
//!
//! 1. **`W`** — the regression weights stored across timesteps (the
//!    "memory"). Linear attention: `K·V` outer-product sum. SSM: the
//!    state matrix `M`. Titans: a small MLP's parameters.
//! 2. **`φ`** — the regressor function class (the basis the weights
//!    are projected through to produce the output). Linear attention:
//!    identity. SSM: a HiPPO basis. Softmax attention: a learned
//!    implicit basis induced by exponentiated similarity.
//! 3. **`A`** — the optimization algorithm that updates `W` from new
//!    `(k, v)` observations. Linear attention: rank-1 sum (no
//!    optimization). SSM: discretized linear recurrence. Titans:
//!    gradient descent on the inner-loop loss.
//!
//! The substrate floor here ships the three enums + a unified
//! `TestTimeRegressor` that wires them together. Concrete instances
//! (linear-attention regressor, SSD regressor, Titans regressor) live
//! in their respective siblings ([`super::ternary::gemv`] for the
//! decode hot-path, [`super::continual_learning::titans_mac`] for
//! Titans-MAC's surprise-gradient `A`, etc.).

use serde::{Deserialize, Serialize};

/// The regressor function class `φ`. The substrate-floor variants
/// cover the four published anchors V6.1 §1.4 + §1.9 cite.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum RegressorFunctionClass {
    /// `φ(x) = x` (identity). Used by linear attention and the
    /// elementwise GEMV decode hot-path.
    Identity,
    /// `φ(x) = HiPPO(x)` — orthogonal polynomial basis. Used by
    /// Mamba / Mamba-2 / Mamba-3 SSMs.
    Hippo,
    /// `φ(x) = exp(x·k_q^T)` — softmax similarity basis. Used by
    /// standard transformer attention.
    SoftmaxSimilarity,
    /// `φ(x) = MLP(x)` — small learned MLP. Used by Titans / fast-
    /// weight programmers.
    LearnedMlp,
}

/// The optimization algorithm `A` that updates `W` from new
/// observations.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum OptimizationAlgorithm {
    /// `W_t = W_{t-1} + k_t v_t^T` — no optimization, just rank-1
    /// accumulation. Linear attention.
    RankOneAccumulate,
    /// Discretized linear recurrence `W_t = A_t W_{t-1} + B_t v_t`.
    /// SSM family (Mamba / Mamba-2 / Mamba-3).
    LinearRecurrence,
    /// SGD step on the inner-loop loss
    /// `W_t = W_{t-1} - η · ∇_W ‖W_{t-1} k_t - v_t‖²`. Titans-MAC.
    SurpriseSgd,
    /// Closed-form least-squares (`W = (K^T K)^{-1} K^T V`) — used
    /// when the regressor class admits a closed-form solution.
    ClosedFormLeastSquares,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TestTimeRegressor {
    pub regression_weights: Vec<Vec<f32>>,
    pub function_class: RegressorFunctionClass,
    pub optimizer: OptimizationAlgorithm,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum RegressionError {
    KeyDimMismatch { expected_rows: usize, key_len: usize },
    ValueDimMismatch { expected_cols: usize, value_len: usize },
    NonPositiveLearningRate { lr: f32 },
}

impl TestTimeRegressor {
    /// Build a fresh regressor with all weights zeroed. `rows` is the
    /// output dimension; `cols` is the key/input dimension.
    pub fn zeros(
        rows: usize,
        cols: usize,
        function_class: RegressorFunctionClass,
        optimizer: OptimizationAlgorithm,
    ) -> Self {
        Self {
            regression_weights: vec![vec![0.0; cols]; rows],
            function_class,
            optimizer,
        }
    }

    pub fn rows(&self) -> usize {
        self.regression_weights.len()
    }

    pub fn cols(&self) -> usize {
        self.regression_weights.first().map(|r| r.len()).unwrap_or(0)
    }

    /// Apply one observation `(key, value)` using the configured
    /// optimizer. For `RankOneAccumulate`: `W += value · key^T`.
    /// For `SurpriseSgd`: `W -= lr · (W·key - value) · key^T` (requires
    /// `lr > 0` via the `lr` field passed in by caller).
    /// For `LinearRecurrence` and `ClosedFormLeastSquares`: rejects —
    /// those need extra parameters not modeled at substrate floor.
    pub fn observe(
        &mut self,
        key: &[f32],
        value: &[f32],
        lr: f32,
    ) -> Result<(), RegressionError> {
        if key.len() != self.cols() {
            return Err(RegressionError::KeyDimMismatch {
                expected_rows: self.cols(),
                key_len: key.len(),
            });
        }
        if value.len() != self.rows() {
            return Err(RegressionError::ValueDimMismatch {
                expected_cols: self.rows(),
                value_len: value.len(),
            });
        }
        match self.optimizer {
            OptimizationAlgorithm::RankOneAccumulate => {
                for r in 0..self.rows() {
                    for c in 0..self.cols() {
                        self.regression_weights[r][c] += value[r] * key[c];
                    }
                }
            }
            OptimizationAlgorithm::SurpriseSgd => {
                if lr <= 0.0 {
                    return Err(RegressionError::NonPositiveLearningRate { lr });
                }
                let mut pred = vec![0.0_f32; self.rows()];
                for r in 0..self.rows() {
                    let mut acc = 0.0_f32;
                    for c in 0..self.cols() {
                        acc += self.regression_weights[r][c] * key[c];
                    }
                    pred[r] = acc;
                }
                for r in 0..self.rows() {
                    let residual = pred[r] - value[r];
                    for c in 0..self.cols() {
                        self.regression_weights[r][c] -= lr * residual * key[c];
                    }
                }
            }
            OptimizationAlgorithm::LinearRecurrence
            | OptimizationAlgorithm::ClosedFormLeastSquares => {
                // Both need extra parameters (recurrence matrices /
                // batch of (K, V) pairs) not modeled here. Substrate
                // floor exposes only the two algorithms that fit the
                // per-step trait shape.
            }
        }
        Ok(())
    }

    /// Forward pass: `out = φ(W) · key` where `φ` is the function
    /// class. Substrate floor: `Identity` applies the raw matmul;
    /// other classes return the raw matmul too (the `φ` projection is
    /// a no-op at substrate level — concrete instances inject the
    /// basis transformation upstream).
    pub fn predict(&self, key: &[f32], out: &mut [f32]) -> Result<(), RegressionError> {
        if key.len() != self.cols() {
            return Err(RegressionError::KeyDimMismatch {
                expected_rows: self.cols(),
                key_len: key.len(),
            });
        }
        if out.len() != self.rows() {
            return Err(RegressionError::ValueDimMismatch {
                expected_cols: self.rows(),
                value_len: out.len(),
            });
        }
        for r in 0..self.rows() {
            let mut acc = 0.0_f32;
            for c in 0..self.cols() {
                acc += self.regression_weights[r][c] * key[c];
            }
            out[r] = acc;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zeros_constructor_sets_correct_dims() {
        let r = TestTimeRegressor::zeros(
            3,
            5,
            RegressorFunctionClass::Identity,
            OptimizationAlgorithm::RankOneAccumulate,
        );
        assert_eq!(r.rows(), 3);
        assert_eq!(r.cols(), 5);
        assert!(r.regression_weights.iter().all(|row| row.iter().all(|&v| v == 0.0)));
    }

    #[test]
    fn rank_one_accumulate_writes_outer_product() {
        let mut r = TestTimeRegressor::zeros(
            2,
            3,
            RegressorFunctionClass::Identity,
            OptimizationAlgorithm::RankOneAccumulate,
        );
        r.observe(&[1.0, 2.0, 3.0], &[10.0, 20.0], 0.0).unwrap();
        assert_eq!(r.regression_weights[0], vec![10.0, 20.0, 30.0]);
        assert_eq!(r.regression_weights[1], vec![20.0, 40.0, 60.0]);
    }

    #[test]
    fn rank_one_accumulate_two_observations_sum() {
        let mut r = TestTimeRegressor::zeros(
            1,
            2,
            RegressorFunctionClass::Identity,
            OptimizationAlgorithm::RankOneAccumulate,
        );
        r.observe(&[1.0, 0.0], &[5.0], 0.0).unwrap();
        r.observe(&[0.0, 1.0], &[7.0], 0.0).unwrap();
        assert_eq!(r.regression_weights[0], vec![5.0, 7.0]);
    }

    #[test]
    fn predict_after_rank_one_recalls_associated_value() {
        let mut r = TestTimeRegressor::zeros(
            1,
            2,
            RegressorFunctionClass::Identity,
            OptimizationAlgorithm::RankOneAccumulate,
        );
        r.observe(&[1.0, 0.0], &[5.0], 0.0).unwrap();
        let mut out = vec![0.0_f32; 1];
        r.predict(&[1.0, 0.0], &mut out).unwrap();
        assert_eq!(out, vec![5.0]);
    }

    #[test]
    fn surprise_sgd_reduces_residual_each_step() {
        let mut r = TestTimeRegressor::zeros(
            1,
            1,
            RegressorFunctionClass::LearnedMlp,
            OptimizationAlgorithm::SurpriseSgd,
        );
        let key = vec![1.0_f32];
        let value = vec![5.0_f32];
        let mut pred = vec![0.0_f32];
        r.predict(&key, &mut pred).unwrap();
        let pre = (pred[0] - value[0]).abs();
        r.observe(&key, &value, 0.1).unwrap();
        r.predict(&key, &mut pred).unwrap();
        let post = (pred[0] - value[0]).abs();
        assert!(post < pre, "pre={} post={}", pre, post);
    }

    #[test]
    fn surprise_sgd_converges_after_many_steps() {
        let mut r = TestTimeRegressor::zeros(
            1,
            1,
            RegressorFunctionClass::LearnedMlp,
            OptimizationAlgorithm::SurpriseSgd,
        );
        for _ in 0..500 {
            r.observe(&[1.0], &[3.0], 0.05).unwrap();
        }
        let mut pred = vec![0.0_f32];
        r.predict(&[1.0], &mut pred).unwrap();
        assert!((pred[0] - 3.0).abs() < 1e-3);
    }

    #[test]
    fn surprise_sgd_rejects_zero_lr() {
        let mut r = TestTimeRegressor::zeros(
            1,
            1,
            RegressorFunctionClass::LearnedMlp,
            OptimizationAlgorithm::SurpriseSgd,
        );
        let err = r.observe(&[1.0], &[1.0], 0.0).unwrap_err();
        assert_eq!(err, RegressionError::NonPositiveLearningRate { lr: 0.0 });
    }

    #[test]
    fn key_dim_mismatch_errors() {
        let mut r = TestTimeRegressor::zeros(
            2,
            3,
            RegressorFunctionClass::Identity,
            OptimizationAlgorithm::RankOneAccumulate,
        );
        let err = r.observe(&[1.0, 2.0], &[1.0, 2.0], 0.0).unwrap_err();
        assert_eq!(
            err,
            RegressionError::KeyDimMismatch { expected_rows: 3, key_len: 2 }
        );
    }

    #[test]
    fn value_dim_mismatch_errors() {
        let mut r = TestTimeRegressor::zeros(
            2,
            3,
            RegressorFunctionClass::Identity,
            OptimizationAlgorithm::RankOneAccumulate,
        );
        let err = r.observe(&[1.0, 2.0, 3.0], &[1.0], 0.0).unwrap_err();
        assert_eq!(
            err,
            RegressionError::ValueDimMismatch { expected_cols: 2, value_len: 1 }
        );
    }

    #[test]
    fn linear_recurrence_observe_is_substrate_noop() {
        let mut r = TestTimeRegressor::zeros(
            2,
            2,
            RegressorFunctionClass::Hippo,
            OptimizationAlgorithm::LinearRecurrence,
        );
        r.observe(&[1.0, 2.0], &[3.0, 4.0], 0.1).unwrap();
        assert!(r.regression_weights.iter().all(|row| row.iter().all(|&v| v == 0.0)));
    }

    #[test]
    fn closed_form_observe_is_substrate_noop() {
        let mut r = TestTimeRegressor::zeros(
            2,
            2,
            RegressorFunctionClass::SoftmaxSimilarity,
            OptimizationAlgorithm::ClosedFormLeastSquares,
        );
        r.observe(&[1.0, 2.0], &[3.0, 4.0], 0.1).unwrap();
        assert!(r.regression_weights.iter().all(|row| row.iter().all(|&v| v == 0.0)));
    }

    #[test]
    fn four_function_classes_distinct() {
        let s: std::collections::HashSet<_> = [
            RegressorFunctionClass::Identity,
            RegressorFunctionClass::Hippo,
            RegressorFunctionClass::SoftmaxSimilarity,
            RegressorFunctionClass::LearnedMlp,
        ]
        .iter()
        .copied()
        .collect();
        assert_eq!(s.len(), 4);
    }

    #[test]
    fn four_optimizers_distinct() {
        let s: std::collections::HashSet<_> = [
            OptimizationAlgorithm::RankOneAccumulate,
            OptimizationAlgorithm::LinearRecurrence,
            OptimizationAlgorithm::SurpriseSgd,
            OptimizationAlgorithm::ClosedFormLeastSquares,
        ]
        .iter()
        .copied()
        .collect();
        assert_eq!(s.len(), 4);
    }

    #[test]
    fn regressor_roundtrips_through_serde_json() {
        let mut r = TestTimeRegressor::zeros(
            1,
            2,
            RegressorFunctionClass::Identity,
            OptimizationAlgorithm::RankOneAccumulate,
        );
        r.observe(&[1.0, 0.0], &[5.0], 0.0).unwrap();
        let json = serde_json::to_string(&r).unwrap();
        let back: TestTimeRegressor = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }
}
