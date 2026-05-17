//! Source:
//! - Kirkpatrick et al., "Overcoming catastrophic forgetting in neural
//!   networks", PNAS 2017, arXiv:1612.00796 — canonical Elastic Weight
//!   Consolidation. Equation 3 of the paper:
//!   `L(θ) = L_B(θ) + Σ_i (λ/2) · F_i · (θ_i − θ*_{A,i})²`
//!   where `F_i` is the diagonal of the Fisher information matrix at the
//!   optimum of task A, `θ*_{A,i}` is the post-task-A parameter, and λ
//!   is the protection strength.
//! - `docs/fusion/jordan's research/kimis deep research/research/continual_learning_online.md`
//!   §8.1 — EWC is the "Protection" layer of the Never Retrain stack,
//!   paired with SI (Synaptic Intelligence) for batch+online hybrid.
//!
//! # J3 #1 — EWC (Elastic Weight Consolidation) substrate
//!
//! Substrate floor: the math (penalty + gradient) + an anchor type
//! that holds the post-task parameters and the Fisher diagonal. A
//! caller (the training loop) uses [`ewc_penalty`] for evaluation and
//! [`ewc_gradient_contribution`] inside the optimizer step to add the
//! EWC contribution to whatever new-task loss gradient it already has.
//!
//! Multi-task EWC (anchoring against N prior tasks) composes by summing
//! the penalty / gradient across N [`EwcAnchor`]s — no additional
//! machinery required.

use serde::{Deserialize, Serialize};

/// Per-parameter Fisher information diagonal. Length must match the
/// parameter vector the anchor was captured from.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct FisherInfo {
    pub diagonal: Vec<f32>,
}

/// A captured anchor from a prior task: the post-task parameter values
/// + the Fisher information diagonal at those values. Together with a
/// protection strength λ they form one EWC term.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct EwcAnchor {
    pub task_id: String,
    pub anchor_params: Vec<f32>,
    pub fisher: FisherInfo,
    pub lambda: f32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum EwcError {
    /// `anchor.anchor_params.len()` did not match `current_params.len()`.
    ParamLengthMismatch {
        anchor_len: usize,
        current_len: usize,
    },
    /// `fisher.diagonal.len()` did not match `anchor_params.len()`.
    FisherLengthMismatch {
        fisher_len: usize,
        anchor_len: usize,
    },
    /// `lambda` was negative. EWC's λ must be ≥ 0 (0 disables the term).
    NegativeLambda { lambda: f32 },
    /// `gradient_out.len()` did not match `current_params.len()`.
    GradientOutLengthMismatch {
        current_len: usize,
        out_len: usize,
    },
}

impl EwcError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            EwcError::ParamLengthMismatch { .. } => "param_length_mismatch",
            EwcError::FisherLengthMismatch { .. } => "fisher_length_mismatch",
            EwcError::NegativeLambda { .. } => "negative_lambda",
            EwcError::GradientOutLengthMismatch { .. } => "gradient_out_length_mismatch",
        }
    }

    /// Predicate: error pertains to vector-length validation
    /// (ParamLengthMismatch / FisherLengthMismatch /
    /// GradientOutLengthMismatch).
    pub const fn is_length_error(&self) -> bool {
        matches!(
            self,
            EwcError::ParamLengthMismatch { .. }
                | EwcError::FisherLengthMismatch { .. }
                | EwcError::GradientOutLengthMismatch { .. }
        )
    }

    /// Predicate: error pertains to hyperparameter validation
    /// (NegativeLambda). Cross-surface invariant:
    /// `is_length_error XOR is_hyperparam_error` partitions all
    /// variants.
    pub const fn is_hyperparam_error(&self) -> bool {
        matches!(self, EwcError::NegativeLambda { .. })
    }
}

impl EwcAnchor {
    /// Predicate: `lambda == 0.0` — the EWC term is disabled (penalty
    /// + gradient contribution are zero regardless of distance).
    pub fn is_disabled(&self) -> bool {
        self.lambda == 0.0
    }

    /// Number of parameters in this anchor. Cross-surface invariant:
    /// `param_count() == anchor_params.len() == fisher.diagonal.len()`
    /// (by construction; the validator enforces this).
    pub fn param_count(&self) -> usize {
        self.anchor_params.len()
    }
}

fn validate_anchor(anchor: &EwcAnchor, current_len: usize) -> Result<(), EwcError> {
    if anchor.lambda < 0.0 {
        return Err(EwcError::NegativeLambda { lambda: anchor.lambda });
    }
    if anchor.anchor_params.len() != current_len {
        return Err(EwcError::ParamLengthMismatch {
            anchor_len: anchor.anchor_params.len(),
            current_len,
        });
    }
    if anchor.fisher.diagonal.len() != anchor.anchor_params.len() {
        return Err(EwcError::FisherLengthMismatch {
            fisher_len: anchor.fisher.diagonal.len(),
            anchor_len: anchor.anchor_params.len(),
        });
    }
    Ok(())
}

/// Scalar EWC penalty: `(λ/2) · Σ_i F_i · (θ_i − θ*_i)²`. Returns
/// the contribution from a single anchor. Multi-anchor callers sum
/// across all returned values.
pub fn ewc_penalty(current_params: &[f32], anchor: &EwcAnchor) -> Result<f32, EwcError> {
    validate_anchor(anchor, current_params.len())?;
    let mut sum: f32 = 0.0;
    for i in 0..current_params.len() {
        let diff = current_params[i] - anchor.anchor_params[i];
        sum += anchor.fisher.diagonal[i] * diff * diff;
    }
    Ok(0.5 * anchor.lambda * sum)
}

/// Per-parameter EWC gradient contribution: `λ · F_i · (θ_i − θ*_i)`.
/// Adds into `gradient_out` (does NOT overwrite — callers feed in
/// the new-task gradient and let this routine add the EWC term).
pub fn ewc_gradient_contribution(
    current_params: &[f32],
    anchor: &EwcAnchor,
    gradient_out: &mut [f32],
) -> Result<(), EwcError> {
    validate_anchor(anchor, current_params.len())?;
    if gradient_out.len() != current_params.len() {
        return Err(EwcError::GradientOutLengthMismatch {
            current_len: current_params.len(),
            out_len: gradient_out.len(),
        });
    }
    for i in 0..current_params.len() {
        let diff = current_params[i] - anchor.anchor_params[i];
        gradient_out[i] += anchor.lambda * anchor.fisher.diagonal[i] * diff;
    }
    Ok(())
}

/// Multi-task EWC penalty: sum of [`ewc_penalty`] across N anchors.
/// The mod doc notes multi-task EWC composes by simple summation;
/// this is the convenience surface. Returns the total penalty.
pub fn multi_anchor_penalty(
    current_params: &[f32],
    anchors: &[EwcAnchor],
) -> Result<f32, EwcError> {
    let mut total = 0.0;
    for anchor in anchors {
        total += ewc_penalty(current_params, anchor)?;
    }
    Ok(total)
}

/// Multi-task EWC gradient: accumulates [`ewc_gradient_contribution`]
/// across N anchors into `gradient_out`. Caller feeds in the new-task
/// gradient; this adds every anchor's EWC term on top.
pub fn multi_anchor_gradient_contribution(
    current_params: &[f32],
    anchors: &[EwcAnchor],
    gradient_out: &mut [f32],
) -> Result<(), EwcError> {
    for anchor in anchors {
        ewc_gradient_contribution(current_params, anchor, gradient_out)?;
    }
    Ok(())
}

impl FisherInfo {
    /// Maximum diagonal value (most-protected parameter's Fisher).
    /// Returns `None` if the diagonal is empty.
    pub fn max(&self) -> Option<f32> {
        self.diagonal.iter().copied().fold(None, |acc, v| match acc {
            None => Some(v),
            Some(a) => Some(if v > a { v } else { a }),
        })
    }

    /// Arithmetic mean of the diagonal. Returns `None` on empty.
    pub fn mean(&self) -> Option<f32> {
        let n = self.diagonal.len();
        if n == 0 {
            return None;
        }
        Some(self.diagonal.iter().sum::<f32>() / n as f32)
    }

    /// Count of parameters whose Fisher information is at least
    /// `threshold`. The §8.3 open question "Optimal Fisher threshold
    /// τ_prime is currently heuristic" applies here — callers
    /// supply τ via this method.
    pub fn count_above(&self, threshold: f32) -> usize {
        self.diagonal.iter().filter(|&&v| v >= threshold).count()
    }

    /// Minimum diagonal value. Returns `None` on empty.
    pub fn min(&self) -> Option<f32> {
        self.diagonal.iter().copied().fold(None, |acc, v| match acc {
            None => Some(v),
            Some(a) => Some(if v < a { v } else { a }),
        })
    }

    /// Sum of the diagonal. Useful for normalization (e.g.
    /// `diagonal / sum() = parameter-importance distribution`).
    pub fn sum(&self) -> f32 {
        self.diagonal.iter().sum()
    }

    /// Predicate: the diagonal is empty.
    pub fn is_empty(&self) -> bool {
        self.diagonal.is_empty()
    }

    /// Number of parameters covered by this Fisher diagonal.
    pub fn len(&self) -> usize {
        self.diagonal.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn anchor(params: Vec<f32>, fisher: Vec<f32>, lambda: f32) -> EwcAnchor {
        EwcAnchor {
            task_id: "task_a".into(),
            anchor_params: params,
            fisher: FisherInfo { diagonal: fisher },
            lambda,
        }
    }

    #[test]
    fn penalty_is_zero_when_current_equals_anchor() {
        let a = anchor(vec![1.0, 2.0, 3.0], vec![10.0, 20.0, 30.0], 1.0);
        let p = ewc_penalty(&[1.0, 2.0, 3.0], &a).unwrap();
        assert_eq!(p, 0.0);
    }

    #[test]
    fn penalty_scales_with_lambda() {
        let a1 = anchor(vec![0.0], vec![1.0], 1.0);
        let a2 = anchor(vec![0.0], vec![1.0], 4.0);
        let p1 = ewc_penalty(&[2.0], &a1).unwrap();
        let p2 = ewc_penalty(&[2.0], &a2).unwrap();
        assert!((p2 / p1 - 4.0).abs() < 1e-6);
    }

    #[test]
    fn penalty_scales_quadratically_with_distance() {
        let a = anchor(vec![0.0], vec![1.0], 1.0);
        let p_one = ewc_penalty(&[1.0], &a).unwrap();
        let p_two = ewc_penalty(&[2.0], &a).unwrap();
        assert!((p_two / p_one - 4.0).abs() < 1e-6);
    }

    #[test]
    fn penalty_weighted_by_fisher_diagonal() {
        let a = anchor(vec![0.0, 0.0], vec![1.0, 100.0], 1.0);
        let p = ewc_penalty(&[1.0, 1.0], &a).unwrap();
        assert!((p - 0.5 * (1.0 + 100.0)).abs() < 1e-6);
    }

    #[test]
    fn gradient_is_zero_at_anchor() {
        let a = anchor(vec![1.0, 2.0], vec![1.0, 1.0], 1.0);
        let mut grad = vec![0.0_f32; 2];
        ewc_gradient_contribution(&[1.0, 2.0], &a, &mut grad).unwrap();
        assert_eq!(grad, vec![0.0, 0.0]);
    }

    #[test]
    fn gradient_pulls_toward_anchor() {
        let a = anchor(vec![0.0], vec![1.0], 1.0);
        let mut grad = vec![0.0_f32];
        ewc_gradient_contribution(&[3.0], &a, &mut grad).unwrap();
        assert_eq!(grad[0], 3.0);

        let mut grad_neg = vec![0.0_f32];
        ewc_gradient_contribution(&[-2.0], &a, &mut grad_neg).unwrap();
        assert_eq!(grad_neg[0], -2.0);
    }

    #[test]
    fn gradient_accumulates_into_existing() {
        let a = anchor(vec![0.0], vec![1.0], 1.0);
        let mut grad = vec![5.0_f32];
        ewc_gradient_contribution(&[2.0], &a, &mut grad).unwrap();
        assert_eq!(grad[0], 7.0);
    }

    #[test]
    fn multi_anchor_sums_penalties() {
        let a1 = anchor(vec![0.0], vec![1.0], 1.0);
        let a2 = anchor(vec![10.0], vec![1.0], 1.0);
        let p1 = ewc_penalty(&[5.0], &a1).unwrap();
        let p2 = ewc_penalty(&[5.0], &a2).unwrap();
        assert!((p1 - 12.5).abs() < 1e-6);
        assert!((p2 - 12.5).abs() < 1e-6);
    }

    #[test]
    fn param_length_mismatch_errors() {
        let a = anchor(vec![0.0, 0.0], vec![1.0, 1.0], 1.0);
        let err = ewc_penalty(&[1.0], &a).unwrap_err();
        assert_eq!(
            err,
            EwcError::ParamLengthMismatch { anchor_len: 2, current_len: 1 }
        );
    }

    #[test]
    fn fisher_length_mismatch_errors() {
        let a = anchor(vec![0.0, 0.0], vec![1.0], 1.0);
        let err = ewc_penalty(&[1.0, 1.0], &a).unwrap_err();
        assert_eq!(
            err,
            EwcError::FisherLengthMismatch { fisher_len: 1, anchor_len: 2 }
        );
    }

    #[test]
    fn negative_lambda_errors() {
        let a = anchor(vec![0.0], vec![1.0], -1.0);
        let err = ewc_penalty(&[1.0], &a).unwrap_err();
        assert_eq!(err, EwcError::NegativeLambda { lambda: -1.0 });
    }

    #[test]
    fn gradient_out_length_mismatch_errors() {
        let a = anchor(vec![0.0, 0.0], vec![1.0, 1.0], 1.0);
        let mut grad = vec![0.0_f32];
        let err =
            ewc_gradient_contribution(&[1.0, 1.0], &a, &mut grad).unwrap_err();
        assert_eq!(
            err,
            EwcError::GradientOutLengthMismatch { current_len: 2, out_len: 1 }
        );
    }

    #[test]
    fn zero_lambda_yields_zero_penalty_and_gradient() {
        let a = anchor(vec![0.0; 5], vec![1.0; 5], 0.0);
        let p = ewc_penalty(&[10.0; 5], &a).unwrap();
        assert_eq!(p, 0.0);
        let mut grad = vec![0.0_f32; 5];
        ewc_gradient_contribution(&[10.0; 5], &a, &mut grad).unwrap();
        assert!(grad.iter().all(|&g| g == 0.0));
    }

    #[test]
    fn anchor_roundtrips_through_serde_json() {
        let a = anchor(vec![0.1, 0.2], vec![1.0, 2.0], 0.5);
        let json = serde_json::to_string(&a).unwrap();
        let back: EwcAnchor = serde_json::from_str(&json).unwrap();
        assert_eq!(a, back);
    }

    // ── multi-anchor + FisherInfo diagnostic tests (iter 104) ───────────────

    #[test]
    fn multi_anchor_penalty_sums_across_anchors() {
        // Two anchors at distance 1.0 from current, both lambda=2,
        // both fisher=1. Each contributes 0.5*2*1*1² = 1. Total = 2.
        let a1 = anchor(vec![0.0, 0.0], vec![1.0, 1.0], 2.0);
        let a2 = anchor(vec![0.0, 0.0], vec![1.0, 1.0], 2.0);
        let current = vec![1.0, 1.0]; // distance² per param = 1
        // Each anchor contributes 0.5 * 2 * (1*1 + 1*1) = 2. Total 4.
        let total = multi_anchor_penalty(&current, &[a1, a2]).unwrap();
        assert!((total - 4.0).abs() < 1e-6);
    }

    #[test]
    fn multi_anchor_penalty_empty_anchors_zero() {
        let total = multi_anchor_penalty(&[1.0, 2.0], &[]).unwrap();
        assert_eq!(total, 0.0);
    }

    #[test]
    fn multi_anchor_gradient_accumulates() {
        // Two anchors at [0,0] with fisher [1,1] and lambda 1.
        // current = [1, 1]; per-anchor gradient = [1, 1]; total = [2, 2].
        let a1 = anchor(vec![0.0, 0.0], vec![1.0, 1.0], 1.0);
        let a2 = anchor(vec![0.0, 0.0], vec![1.0, 1.0], 1.0);
        let current = vec![1.0, 1.0];
        let mut grad = vec![0.0_f32; 2];
        multi_anchor_gradient_contribution(&current, &[a1, a2], &mut grad).unwrap();
        assert!((grad[0] - 2.0).abs() < 1e-6);
        assert!((grad[1] - 2.0).abs() < 1e-6);
    }

    #[test]
    fn multi_anchor_gradient_with_prior_grad_adds_on_top() {
        // Caller-supplied prior gradient [0.5, 0.5]; one anchor adds [1, 1].
        let a = anchor(vec![0.0, 0.0], vec![1.0, 1.0], 1.0);
        let current = vec![1.0, 1.0];
        let mut grad = vec![0.5_f32; 2];
        multi_anchor_gradient_contribution(&current, &[a], &mut grad).unwrap();
        assert!((grad[0] - 1.5).abs() < 1e-6);
        assert!((grad[1] - 1.5).abs() < 1e-6);
    }

    #[test]
    fn fisher_max_returns_largest() {
        let f = FisherInfo { diagonal: vec![0.5, 2.0, 1.5] };
        assert!((f.max().unwrap() - 2.0).abs() < 1e-6);
    }

    #[test]
    fn fisher_max_empty_returns_none() {
        let f = FisherInfo { diagonal: vec![] };
        assert!(f.max().is_none());
    }

    #[test]
    fn fisher_mean_arithmetic_average() {
        let f = FisherInfo { diagonal: vec![1.0, 2.0, 3.0, 4.0] };
        assert!((f.mean().unwrap() - 2.5).abs() < 1e-6);
    }

    #[test]
    fn fisher_mean_empty_returns_none() {
        let f = FisherInfo { diagonal: vec![] };
        assert!(f.mean().is_none());
    }

    #[test]
    fn fisher_count_above_threshold() {
        let f = FisherInfo { diagonal: vec![0.1, 0.5, 1.0, 2.0, 3.0] };
        assert_eq!(f.count_above(1.0), 3); // 1.0, 2.0, 3.0
        assert_eq!(f.count_above(2.0), 2); // 2.0, 3.0
        assert_eq!(f.count_above(10.0), 0);
        assert_eq!(f.count_above(0.0), 5); // all values ≥ 0
    }

    #[test]
    fn fisher_count_above_empty_is_zero() {
        let f = FisherInfo { diagonal: vec![] };
        assert_eq!(f.count_above(0.0), 0);
    }

    // ── diagnostic surface (iter 188) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [
            EwcError::ParamLengthMismatch { anchor_len: 1, current_len: 2 },
            EwcError::FisherLengthMismatch { fisher_len: 1, anchor_len: 2 },
            EwcError::NegativeLambda { lambda: -1.0 },
            EwcError::GradientOutLengthMismatch { current_len: 1, out_len: 2 },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 4);
    }

    #[test]
    fn error_classifiers_partition() {
        let variants = [
            EwcError::ParamLengthMismatch { anchor_len: 1, current_len: 2 },
            EwcError::FisherLengthMismatch { fisher_len: 1, anchor_len: 2 },
            EwcError::NegativeLambda { lambda: -1.0 },
            EwcError::GradientOutLengthMismatch { current_len: 1, out_len: 2 },
        ];
        // Cross-surface invariant: is_length_error XOR is_hyperparam_error.
        for e in variants {
            assert_ne!(e.is_length_error(), e.is_hyperparam_error());
        }
        assert_eq!(variants.iter().filter(|e| e.is_length_error()).count(), 3);
        assert_eq!(variants.iter().filter(|e| e.is_hyperparam_error()).count(), 1);
    }

    #[test]
    fn anchor_is_disabled_at_zero_lambda() {
        let a = anchor(vec![0.0], vec![1.0], 0.0);
        assert!(a.is_disabled());
        let a = anchor(vec![0.0], vec![1.0], 0.5);
        assert!(!a.is_disabled());
    }

    #[test]
    fn anchor_param_count_matches_vec_len() {
        // Cross-surface invariant.
        let a = anchor(vec![0.0; 7], vec![1.0; 7], 1.0);
        assert_eq!(a.param_count(), 7);
        assert_eq!(a.param_count(), a.anchor_params.len());
        assert_eq!(a.param_count(), a.fisher.diagonal.len());
    }

    #[test]
    fn fisher_min_returns_smallest() {
        let f = FisherInfo { diagonal: vec![2.0, 0.5, 1.5] };
        assert!((f.min().unwrap() - 0.5).abs() < 1e-6);
    }

    #[test]
    fn fisher_min_empty_returns_none() {
        let f = FisherInfo { diagonal: vec![] };
        assert!(f.min().is_none());
    }

    #[test]
    fn fisher_ordering_invariant_max_geq_mean_geq_min() {
        // Cross-surface invariant: max ≥ mean ≥ min for non-empty Fisher
        // diagonals with non-negative entries (the only physically
        // meaningful case).
        for diag in [vec![1.0_f32, 2.0, 3.0, 4.0], vec![0.5], vec![10.0, 0.1, 5.0]] {
            let f = FisherInfo { diagonal: diag };
            assert!(f.max().unwrap() >= f.mean().unwrap());
            assert!(f.mean().unwrap() >= f.min().unwrap());
        }
    }

    #[test]
    fn fisher_sum_consistent_with_mean() {
        // Cross-surface invariant: sum = mean × len for non-empty.
        let f = FisherInfo { diagonal: vec![1.0, 2.0, 3.0, 4.0] };
        assert!((f.sum() - f.mean().unwrap() * f.len() as f32).abs() < 1e-6);
    }

    #[test]
    fn fisher_is_empty_aligned_with_len() {
        let empty = FisherInfo { diagonal: vec![] };
        assert!(empty.is_empty());
        assert_eq!(empty.len(), 0);
        let full = FisherInfo { diagonal: vec![1.0; 5] };
        assert!(!full.is_empty());
        assert_eq!(full.len(), 5);
    }

    #[test]
    fn disabled_anchor_zero_penalty_invariant() {
        // Cross-surface invariant: is_disabled implies ewc_penalty == 0
        // for any current_params (lambda=0 kills the whole term).
        let a = anchor(vec![0.0, 0.0], vec![1.0, 1.0], 0.0);
        assert!(a.is_disabled());
        let p = ewc_penalty(&[1000.0, -500.0], &a).unwrap();
        assert_eq!(p, 0.0);
    }
}
