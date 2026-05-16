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
}
