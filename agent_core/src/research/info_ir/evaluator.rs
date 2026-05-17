//! Source:
//! - Amari (Springer 2016) Ch. 2 — log-partition A(θ) and dual map
//!   η = ∇A(θ) for exponential families.
//! - Amari Ch. 6 — Bregman divergence B_A(P, Q) = A(θ_P) - A(θ_Q) -
//!   ⟨∇A(θ_Q), θ_P - θ_Q⟩.
//! - Doctrine §4.5 — Info-IR first lowering target.
//! - Companion: [`super::grammar`] (the InfoExpr we evaluate).
//!
//! # Info-IR evaluator
//!
//! Three operations:
//!
//! ```text
//! LogPartition(F, θ)      → A_F(θ)
//! DualMap(F, θ)           → η = ∇A_F(θ)
//! KlProjection(F, p, q)   → KL(P || Q) (Bregman divergence
//!                            induced by A_F)
//! ```
//!
//! Closed forms per family:
//!
//! - **Bernoulli** with scalar natural parameter θ:
//!   - A(θ) = ln(1 + exp(θ))   (softplus)
//!   - η = sigmoid(θ) = exp(θ) / (1 + exp(θ))
//!   - KL(p, q) on natural params:
//!     A(p) - A(q) - sigmoid(q) * (p - q)
//!
//! - **Categorical{k}** with θ ∈ ℝ^{k-1}:
//!   - A(θ) = ln(1 + Σ_i exp(θ_i))
//!   - η_i = exp(θ_i) / (1 + Σ_j exp(θ_j))
//!   - KL(p, q) = A(p) - A(q) - Σ_i dual_map(q)_i * (p_i - q_i)
//!
//! - **Gaussian{σ²}** with scalar θ = μ/σ²:
//!   - A(θ) = σ²θ²/2
//!   - η = σ²θ
//!   - KL(p, q) = A(p) - A(q) - σ²q * (p - q)
//!
//! Numerical stability: we use log-sum-exp where appropriate to
//! avoid overflow in `exp(θ)`.

use super::grammar::{ExpFamily, InfoExpr};

/// Evaluation error.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum InfoEvalError {
    NonFiniteResult { value: f64 },
}

/// Evaluate an [`InfoExpr`]. LogPartition / KlProjection return a
/// scalar f64; DualMap returns a single-element vector for
/// Bernoulli + Gaussian and a `k-1`-element vector for Categorical
/// (matched against the family's natural-param arity).
pub fn evaluate_scalar(expr: &InfoExpr) -> Result<f64, InfoEvalError> {
    let v = match expr {
        InfoExpr::LogPartition {
            family,
            natural_params,
        } => log_partition(family, natural_params),
        InfoExpr::DualMap { .. } => {
            // DualMap is vector-valued; return the L1 norm as a
            // scalar summary. Callers wanting the full vector
            // should call [`evaluate_dual_map`] directly.
            let v = evaluate_dual_map(expr)?;
            v.iter().map(|x| x.abs()).sum()
        }
        InfoExpr::KlProjection {
            family,
            p_params,
            q_params,
        } => kl_divergence(family, p_params, q_params),
    };
    finite_or_err(v)
}

/// Vector-valued evaluator for the dual map η = ∇A(θ).
pub fn evaluate_dual_map(expr: &InfoExpr) -> Result<Vec<f64>, InfoEvalError> {
    match expr {
        InfoExpr::DualMap { family, natural_params }
        | InfoExpr::LogPartition { family, natural_params } => {
            // Dual-map is well-defined for both LogPartition and
            // DualMap nodes (they share the natural-params shape).
            let v = dual_map(family, natural_params);
            for &x in &v {
                if !x.is_finite() {
                    return Err(InfoEvalError::NonFiniteResult { value: x });
                }
            }
            Ok(v)
        }
        InfoExpr::KlProjection { .. } => {
            // KL-projection is scalar; not a vector-valued operation.
            // Return an empty vec rather than error — callers should
            // route to evaluate_scalar instead.
            Ok(Vec::new())
        }
    }
}

fn finite_or_err(v: f64) -> Result<f64, InfoEvalError> {
    if v.is_finite() {
        Ok(v)
    } else {
        Err(InfoEvalError::NonFiniteResult { value: v })
    }
}

/// A_F(θ) — log-partition function per family.
pub fn log_partition(family: &ExpFamily, theta: &[f64]) -> f64 {
    match family {
        ExpFamily::Bernoulli => softplus(theta[0]),
        ExpFamily::Categorical { .. } => {
            // ln(1 + Σ exp(θ_i)) — implemented as log-sum-exp over
            // [0.0, θ_1, …, θ_{k-1}].
            let mut all = Vec::with_capacity(theta.len() + 1);
            all.push(0.0);
            all.extend_from_slice(theta);
            log_sum_exp(&all)
        }
        ExpFamily::Gaussian { variance } => 0.5 * variance * theta[0] * theta[0],
    }
}

/// η = ∇A_F(θ) — dual / mean parameters.
pub fn dual_map(family: &ExpFamily, theta: &[f64]) -> Vec<f64> {
    match family {
        ExpFamily::Bernoulli => vec![sigmoid(theta[0])],
        ExpFamily::Categorical { .. } => {
            // η_i = exp(θ_i) / (1 + Σ_j exp(θ_j)) for i = 1..k-1.
            let mut all = Vec::with_capacity(theta.len() + 1);
            all.push(0.0);
            all.extend_from_slice(theta);
            let lse = log_sum_exp(&all);
            theta.iter().map(|t| (t - lse).exp()).collect()
        }
        ExpFamily::Gaussian { variance } => vec![variance * theta[0]],
    }
}

/// KL(P || Q) = A(p) - A(q) - ⟨η_Q, p - q⟩.
pub fn kl_divergence(family: &ExpFamily, p: &[f64], q: &[f64]) -> f64 {
    let a_p = log_partition(family, p);
    let a_q = log_partition(family, q);
    let eta_q = dual_map(family, q);
    let inner: f64 = eta_q
        .iter()
        .zip(p.iter().zip(q.iter()))
        .map(|(eq, (pi, qi))| eq * (pi - qi))
        .sum();
    a_p - a_q - inner
}

// ── numerical helpers ─────────────────────────────────────────────

fn sigmoid(x: f64) -> f64 {
    1.0 / (1.0 + (-x).exp())
}

fn softplus(x: f64) -> f64 {
    // log(1 + exp(x)) with shift for stability when x is large.
    if x > 30.0 {
        x
    } else if x < -30.0 {
        x.exp()
    } else {
        (1.0 + x.exp()).ln()
    }
}

fn log_sum_exp(xs: &[f64]) -> f64 {
    // LSE(x) = m + ln Σ exp(x_i - m) where m = max(xs).
    if xs.is_empty() {
        return f64::NEG_INFINITY;
    }
    let m = xs.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    if !m.is_finite() {
        return m;
    }
    let s: f64 = xs.iter().map(|x| (x - m).exp()).sum();
    m + s.ln()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx(a: f64, b: f64, tol: f64) -> bool {
        (a - b).abs() < tol
    }

    // ── Bernoulli ─────────────────────────────────────────────────

    #[test]
    fn bernoulli_log_partition_at_zero_is_ln_two() {
        assert!(approx(log_partition(&ExpFamily::Bernoulli, &[0.0]), 2.0_f64.ln(), 1e-12));
    }

    #[test]
    fn bernoulli_dual_map_at_zero_is_half() {
        let eta = dual_map(&ExpFamily::Bernoulli, &[0.0]);
        assert!(approx(eta[0], 0.5, 1e-12));
    }

    #[test]
    fn bernoulli_kl_zero_when_p_equals_q() {
        let kl = kl_divergence(&ExpFamily::Bernoulli, &[0.5], &[0.5]);
        assert!(approx(kl, 0.0, 1e-12));
    }

    #[test]
    fn bernoulli_kl_nonnegative() {
        // Sample several (p, q) pairs and verify KL ≥ 0.
        let f = ExpFamily::Bernoulli;
        for p in [-2.0_f64, -1.0, 0.0, 0.5, 1.0, 2.0] {
            for q in [-2.0_f64, -1.0, 0.0, 0.5, 1.0, 2.0] {
                let kl = kl_divergence(&f, &[p], &[q]);
                assert!(kl >= -1e-10, "KL({}, {}) = {} < 0", p, q, kl);
            }
        }
    }

    #[test]
    fn bernoulli_softplus_stable_for_large_x() {
        assert!(approx(softplus(100.0), 100.0, 1e-10));
        assert!(softplus(-100.0) < 1e-40);
    }

    // ── Categorical ───────────────────────────────────────────────

    #[test]
    fn categorical_3_log_partition_at_zeros() {
        // θ = [0, 0]; A = ln(1 + e^0 + e^0) = ln(3).
        let v = log_partition(&ExpFamily::Categorical { k: 3 }, &[0.0, 0.0]);
        assert!(approx(v, 3.0_f64.ln(), 1e-12));
    }

    #[test]
    fn categorical_3_dual_map_at_zeros_is_1_over_3() {
        let eta = dual_map(&ExpFamily::Categorical { k: 3 }, &[0.0, 0.0]);
        assert!(approx(eta[0], 1.0 / 3.0, 1e-12));
        assert!(approx(eta[1], 1.0 / 3.0, 1e-12));
    }

    #[test]
    fn categorical_kl_zero_when_p_equals_q() {
        let kl = kl_divergence(
            &ExpFamily::Categorical { k: 4 },
            &[0.1, 0.2, -0.3],
            &[0.1, 0.2, -0.3],
        );
        assert!(approx(kl, 0.0, 1e-12));
    }

    // ── Gaussian ──────────────────────────────────────────────────

    #[test]
    fn gaussian_log_partition_quadratic() {
        // σ²=1, θ=2 → A = 0.5 * 1 * 4 = 2.
        let v = log_partition(&ExpFamily::Gaussian { variance: 1.0 }, &[2.0]);
        assert!(approx(v, 2.0, 1e-12));
    }

    #[test]
    fn gaussian_dual_map_is_variance_times_theta() {
        let eta = dual_map(&ExpFamily::Gaussian { variance: 2.0 }, &[3.0]);
        assert!(approx(eta[0], 6.0, 1e-12));
    }

    #[test]
    fn gaussian_kl_zero_when_p_equals_q() {
        let kl = kl_divergence(&ExpFamily::Gaussian { variance: 1.5 }, &[2.0], &[2.0]);
        assert!(approx(kl, 0.0, 1e-12));
    }

    // ── InfoExpr top-level evaluator ──────────────────────────────

    #[test]
    fn evaluate_scalar_log_partition() {
        let e =
            InfoExpr::log_partition(ExpFamily::Bernoulli, vec![0.0]).unwrap();
        assert!(approx(evaluate_scalar(&e).unwrap(), 2.0_f64.ln(), 1e-12));
    }

    #[test]
    fn evaluate_dual_map_returns_correct_vec() {
        let e = InfoExpr::dual_map(ExpFamily::Bernoulli, vec![0.0]).unwrap();
        let v = evaluate_dual_map(&e).unwrap();
        assert_eq!(v.len(), 1);
        assert!(approx(v[0], 0.5, 1e-12));
    }

    #[test]
    fn evaluate_scalar_kl() {
        let e =
            InfoExpr::kl_projection(ExpFamily::Bernoulli, vec![1.0], vec![0.0])
                .unwrap();
        // KL(1.0, 0.0) on Bernoulli:
        // A(1) = ln(1 + e), A(0) = ln(2), η(0) = 0.5,
        // KL = ln(1+e) - ln(2) - 0.5 * 1.0
        let expected =
            (1.0_f64.exp() + 1.0).ln() - 2.0_f64.ln() - 0.5 * 1.0;
        assert!(approx(evaluate_scalar(&e).unwrap(), expected, 1e-12));
    }
}
