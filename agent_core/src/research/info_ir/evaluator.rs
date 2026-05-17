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

/// Fisher information matrix `I(θ) = ∇²A(θ)`, the Hessian of the
/// log-partition function. For exp-families this equals the
/// covariance of the sufficient statistic, `Cov_θ[T(X)]`.
///
/// Per family:
/// - Bernoulli: `I = σ(θ)·(1-σ(θ))` (1×1).
/// - Categorical{k}: `I_ij = p_i·δ_ij − p_i·p_j` (k-1 × k-1)
///   where `p_i = exp(θ_i) / Z`.
/// - Gaussian{σ²}: `I = σ²` (1×1).
///
/// Returns a square `(d × d)` matrix where `d = natural_param_arity`.
///
/// Iter-92 — second-order Info-IR primitive. Used for natural-
/// gradient descent (Amari 1998) and confidence-interval estimation.
pub fn fisher_information(family: &ExpFamily, theta: &[f64]) -> Vec<Vec<f64>> {
    match family {
        ExpFamily::Bernoulli => {
            let s = sigmoid(theta[0]);
            vec![vec![s * (1.0 - s)]]
        }
        ExpFamily::Categorical { .. } => {
            let eta = dual_map(family, theta);
            let d = eta.len();
            let mut m = vec![vec![0.0; d]; d];
            for i in 0..d {
                for j in 0..d {
                    let kron = if i == j { 1.0 } else { 0.0 };
                    m[i][j] = eta[i] * kron - eta[i] * eta[j];
                }
            }
            m
        }
        ExpFamily::Gaussian { variance } => vec![vec![*variance]],
    }
}

/// Shannon entropy `H(P_θ)` via the Fenchel-duality identity
/// `H(P_θ) = A(θ) - ⟨∇A(θ), θ⟩`. Companion to [`kl_divergence`].
///
/// For Gaussian, the discrete identity does NOT apply (Gaussian
/// is continuous); we return the continuous differential entropy
/// `H = 0.5·log(2π·e·σ²)` directly.
///
/// Iter-91 — direct entropy evaluator for the three Info-IR
/// exp-families.
pub fn entropy(family: &ExpFamily, theta: &[f64]) -> f64 {
    match family {
        ExpFamily::Bernoulli | ExpFamily::Categorical { .. } => {
            let a = log_partition(family, theta);
            let eta = dual_map(family, theta);
            let inner: f64 = eta.iter().zip(theta.iter()).map(|(e, t)| e * t).sum();
            a - inner
        }
        ExpFamily::Gaussian { variance } => {
            let two_pi_e_var = 2.0 * std::f64::consts::PI * std::f64::consts::E * variance;
            0.5 * two_pi_e_var.ln()
        }
    }
}

/// Cross-entropy `H(P, Q) = -E_P[log q(x)]` for two distributions
/// in the same exp-family, parameterized by natural params `p`
/// and `q`.
///
/// For exp-families, `H(P, Q) = H(P) + KL(P || Q)`. We compute via
/// that identity to reuse the existing primitives.
///
/// Iter-91 — closes the Info-IR information-theoretic surface
/// (kl + entropy + cross_entropy + js_divergence).
pub fn cross_entropy(family: &ExpFamily, p: &[f64], q: &[f64]) -> f64 {
    entropy(family, p) + kl_divergence(family, p, q)
}

/// Jensen-Shannon divergence
/// `JS(P || Q) = 0.5·KL(P || M) + 0.5·KL(Q || M)`
/// where M = (P + Q) / 2 is the mixture distribution.
///
/// For Bernoulli / Categorical (discrete), we compute M by averaging
/// the dual / mean parameters and converting back to natural-param
/// coords. For Gaussian we average on the natural-parameter side
/// (variance fixed); this is a CONVENTION since the mixture of
/// two Gaussians isn't a Gaussian — we approximate.
///
/// Iter-91 — symmetrized, bounded divergence (0 ≤ JS ≤ log 2).
pub fn js_divergence(family: &ExpFamily, p: &[f64], q: &[f64]) -> f64 {
    match family {
        ExpFamily::Bernoulli => {
            // Mixture mean p_m = (σ(p) + σ(q)) / 2; convert back via logit.
            let p_mean = sigmoid(p[0]);
            let q_mean = sigmoid(q[0]);
            let m_mean = 0.5 * (p_mean + q_mean);
            // Avoid log(0) at the boundary.
            let m_theta = (m_mean / (1.0 - m_mean)).ln();
            0.5 * kl_divergence(family, p, &[m_theta])
                + 0.5 * kl_divergence(family, q, &[m_theta])
        }
        ExpFamily::Categorical { k } => {
            // Mean params: p_i = exp(θ_i)/(1+Σexp(θ_j)) for non-pinned,
            // and 1/(1+Σexp(θ_j)) for the pinned class.
            let p_eta = dual_map(family, p);
            let q_eta = dual_map(family, q);
            let mut m_eta: Vec<f64> = p_eta
                .iter()
                .zip(q_eta.iter())
                .map(|(pe, qe)| 0.5 * (pe + qe))
                .collect();
            // Pinned-class probability for the mixture.
            let p_pinned = 1.0 - p_eta.iter().sum::<f64>();
            let q_pinned = 1.0 - q_eta.iter().sum::<f64>();
            let m_pinned = 0.5 * (p_pinned + q_pinned);
            // Convert back: θ_i = log(η_i / m_pinned).
            let m_theta: Vec<f64> = m_eta
                .iter_mut()
                .map(|e| (*e / m_pinned).ln())
                .collect();
            let _ = k;
            0.5 * kl_divergence(family, p, &m_theta)
                + 0.5 * kl_divergence(family, q, &m_theta)
        }
        ExpFamily::Gaussian { .. } => {
            // For fixed-variance Gaussians, the mixture of two
            // Gaussians is NOT a Gaussian. Approximate by averaging
            // natural parameters (mean estimates).
            let m_theta: Vec<f64> = p
                .iter()
                .zip(q.iter())
                .map(|(pi, qi)| 0.5 * (pi + qi))
                .collect();
            0.5 * kl_divergence(family, p, &m_theta)
                + 0.5 * kl_divergence(family, q, &m_theta)
        }
    }
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

    // ── iter-92: Fisher information matrix ────────────────────────

    #[test]
    fn fisher_bernoulli_peaks_at_zero() {
        let i = fisher_information(&ExpFamily::Bernoulli, &[0.0]);
        assert_eq!(i.len(), 1);
        assert_eq!(i[0].len(), 1);
        assert!((i[0][0] - 0.25).abs() < 1e-12, "I(0) = {}", i[0][0]);
    }

    #[test]
    fn fisher_bernoulli_saturates_to_zero() {
        let i_pos = fisher_information(&ExpFamily::Bernoulli, &[10.0]);
        let i_neg = fisher_information(&ExpFamily::Bernoulli, &[-10.0]);
        assert!(i_pos[0][0] < 1e-4);
        assert!(i_neg[0][0] < 1e-4);
    }

    #[test]
    fn fisher_categorical_uniform_diag_minus_outer() {
        // Uniform Categorical{k=3}, θ=0: η = (1/3, 1/3) → I = ((2/9, -1/9), (-1/9, 2/9)).
        let i = fisher_information(&ExpFamily::Categorical { k: 3 }, &[0.0, 0.0]);
        assert_eq!(i.len(), 2);
        assert!((i[0][0] - 2.0 / 9.0).abs() < 1e-12);
        assert!((i[1][1] - 2.0 / 9.0).abs() < 1e-12);
        assert!((i[0][1] + 1.0 / 9.0).abs() < 1e-12);
        assert!((i[1][0] + 1.0 / 9.0).abs() < 1e-12);
    }

    #[test]
    fn fisher_categorical_is_symmetric() {
        let i = fisher_information(&ExpFamily::Categorical { k: 4 }, &[0.5, -0.3, 1.0]);
        for r in 0..3 {
            for c in 0..3 {
                assert!(
                    (i[r][c] - i[c][r]).abs() < 1e-12,
                    "I[{}][{}] = {} != I[{}][{}] = {}", r, c, i[r][c], c, r, i[c][r]
                );
            }
        }
    }

    #[test]
    fn fisher_gaussian_is_variance() {
        for variance in [0.5_f64, 1.0, 2.5, 4.0] {
            let i = fisher_information(&ExpFamily::Gaussian { variance }, &[1.0]);
            assert_eq!(i.len(), 1);
            assert!((i[0][0] - variance).abs() < 1e-12);
        }
    }

    #[test]
    fn fisher_dimensionality_matches_arity() {
        for (fam, theta) in [
            (ExpFamily::Bernoulli, vec![0.5]),
            (ExpFamily::Categorical { k: 3 }, vec![0.5, -0.5]),
            (ExpFamily::Categorical { k: 5 }, vec![1.0, 2.0, 3.0, 4.0]),
            (ExpFamily::Gaussian { variance: 1.0 }, vec![1.5]),
        ] {
            let i = fisher_information(&fam, &theta);
            let d = fam.natural_param_arity();
            assert_eq!(i.len(), d, "{}: Fisher rows = {}, arity = {}", fam, i.len(), d);
            for row in &i {
                assert_eq!(row.len(), d);
            }
        }
    }

    #[test]
    fn fisher_categorical_positive_semidefinite() {
        // I is the covariance of T(X), so I is PSD: x^T I x ≥ 0 for any x.
        let i = fisher_information(&ExpFamily::Categorical { k: 3 }, &[1.0, -1.0]);
        for x in [vec![1.0_f64, 0.0], vec![0.0, 1.0], vec![1.0, 1.0], vec![1.0, -1.0]] {
            let mut q = 0.0;
            for r in 0..2 {
                for c in 0..2 {
                    q += x[r] * i[r][c] * x[c];
                }
            }
            assert!(q >= -1e-12, "x={:?}: x^T I x = {}", x, q);
        }
    }

    // ── iter-91: entropy, cross-entropy, JS divergence ────────────

    #[test]
    fn entropy_bernoulli_at_zero_is_ln_2() {
        let h = entropy(&ExpFamily::Bernoulli, &[0.0]);
        assert!((h - 2.0_f64.ln()).abs() < 1e-12);
    }

    #[test]
    fn entropy_bernoulli_saturates_at_extremes() {
        let h_pos = entropy(&ExpFamily::Bernoulli, &[10.0]);
        let h_neg = entropy(&ExpFamily::Bernoulli, &[-10.0]);
        assert!(h_pos < 1e-3);
        assert!(h_neg < 1e-3);
    }

    #[test]
    fn entropy_categorical_uniform_is_ln_k() {
        for k in [2_usize, 3, 5, 10] {
            let theta = vec![0.0_f64; k - 1];
            let h = entropy(&ExpFamily::Categorical { k }, &theta);
            assert!(
                (h - (k as f64).ln()).abs() < 1e-12,
                "k={}: H = {}", k, h
            );
        }
    }

    #[test]
    fn entropy_gaussian_differential_form() {
        // H = 0.5 · log(2π·e·σ²); σ²=1 → H = 0.5·log(2πe) ≈ 1.4189.
        let h = entropy(&ExpFamily::Gaussian { variance: 1.0 }, &[0.0]);
        let expected = 0.5 * (2.0 * std::f64::consts::PI * std::f64::consts::E).ln();
        assert!((h - expected).abs() < 1e-12);
    }

    #[test]
    fn cross_entropy_equals_self_at_p_eq_q() {
        // H(P, P) = H(P) when p == q.
        let theta = [0.7_f64];
        let ce = cross_entropy(&ExpFamily::Bernoulli, &theta, &theta);
        let h = entropy(&ExpFamily::Bernoulli, &theta);
        assert!((ce - h).abs() < 1e-12, "H(P,P) = {}, H(P) = {}", ce, h);
    }

    #[test]
    fn cross_entropy_decomposition() {
        // H(P, Q) = H(P) + KL(P || Q).
        for (p, q) in [
            (vec![1.0_f64], vec![-1.0]),
            (vec![0.5], vec![-0.5]),
            (vec![2.0], vec![0.0]),
        ] {
            let ce = cross_entropy(&ExpFamily::Bernoulli, &p, &q);
            let h = entropy(&ExpFamily::Bernoulli, &p);
            let kl = kl_divergence(&ExpFamily::Bernoulli, &p, &q);
            assert!(
                (ce - (h + kl)).abs() < 1e-12,
                "CE = {}; H + KL = {}", ce, h + kl
            );
        }
    }

    #[test]
    fn js_divergence_zero_at_p_equals_q() {
        for fam in [
            ExpFamily::Bernoulli,
            ExpFamily::Categorical { k: 3 },
            ExpFamily::Gaussian { variance: 1.5 },
        ] {
            let theta_dim = fam.natural_param_arity();
            let theta = vec![0.5_f64; theta_dim];
            let js = js_divergence(&fam, &theta, &theta);
            assert!(js.abs() < 1e-10, "JS({}) = {}", fam, js);
        }
    }

    #[test]
    fn js_divergence_bernoulli_symmetric() {
        let p = [1.0_f64];
        let q = [-1.0];
        let js_pq = js_divergence(&ExpFamily::Bernoulli, &p, &q);
        let js_qp = js_divergence(&ExpFamily::Bernoulli, &q, &p);
        assert!((js_pq - js_qp).abs() < 1e-12, "symmetry: {} != {}", js_pq, js_qp);
    }

    #[test]
    fn js_divergence_non_negative_bernoulli() {
        // JS ≥ 0 across a moderate grid.
        for (p, q) in [
            (1.0_f64, 0.0),
            (-1.0, 2.0),
            (0.5, -0.5),
            (3.0, -3.0),
        ] {
            let js = js_divergence(&ExpFamily::Bernoulli, &[p], &[q]);
            assert!(js >= -1e-10, "JS({}, {}) = {}", p, q, js);
        }
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
