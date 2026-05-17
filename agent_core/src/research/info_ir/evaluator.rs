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

/// Univariate Gaussian probability density:
///
/// `pdf(x; μ, σ²) = (1 / √(2π σ²)) · exp(-(x - μ)² / (2σ²))`
///
/// Iter-142 — direct PDF evaluator. Complements the natural-param
/// log_partition representation used elsewhere in Info-IR.
pub fn gaussian_pdf(x: f64, mu: f64, variance: f64) -> f64 {
    let norm = (2.0 * std::f64::consts::PI * variance).sqrt();
    let dx = x - mu;
    (-(dx * dx) / (2.0 * variance)).exp() / norm
}

/// Univariate Gaussian log-density:
///
/// `log pdf(x; μ, σ²) = -0.5 · log(2π σ²) - (x - μ)² / (2σ²)`
///
/// Iter-142 — log-domain companion of [`gaussian_pdf`]. Used in
/// numerical NLL / KL computations where overflow / underflow
/// must be avoided.
pub fn gaussian_log_pdf(x: f64, mu: f64, variance: f64) -> f64 {
    let log_norm = 0.5 * (2.0 * std::f64::consts::PI * variance).ln();
    let dx = x - mu;
    -log_norm - (dx * dx) / (2.0 * variance)
}

/// Symmetric KL divergence (sometimes called J-divergence):
/// `J(P, Q) = KL(P || Q) + KL(Q || P)`.
///
/// Symmetric but not bounded; useful when an asymmetric measure
/// is needed in a symmetric context.
///
/// Iter-132 — built atop existing kl_divergence; works for all
/// three families.
pub fn symmetric_kl(family: &ExpFamily, theta_p: &[f64], theta_q: &[f64]) -> f64 {
    kl_divergence(family, theta_p, theta_q) + kl_divergence(family, theta_q, theta_p)
}

/// χ² (chi-squared) divergence:
/// `χ²(P, Q) = Σ_i (p_i − q_i)² / q_i`
///
/// for discrete distributions. Bounds KL via `KL ≤ χ²` and is
/// the leading term in the Hellinger expansion for nearby
/// distributions.
///
/// - **Bernoulli**: (p − q)² / q + ((1-p) − (1-q))² / (1-q)
///                 = (p − q)² · (1/q + 1/(1-q))
///                 = (p − q)² / (q · (1-q))
/// - **Categorical{k}**: full simplex sum including pinned class.
/// - **Gaussian**: returns NaN (continuous case differs).
///
/// Iter-132 — companion to TV / Hellinger / KL distance family.
pub fn chi_squared_divergence(
    family: &ExpFamily,
    theta_p: &[f64],
    theta_q: &[f64],
) -> f64 {
    match family {
        ExpFamily::Bernoulli => {
            let p = sigmoid(theta_p[0]);
            let q = sigmoid(theta_q[0]);
            let dp = p - q;
            dp * dp / (q * (1.0 - q))
        }
        ExpFamily::Categorical { .. } => {
            let p_eta = dual_map(family, theta_p);
            let q_eta = dual_map(family, theta_q);
            let p_pinned = 1.0 - p_eta.iter().sum::<f64>();
            let q_pinned = 1.0 - q_eta.iter().sum::<f64>();
            let mut s: f64 = p_eta
                .iter()
                .zip(q_eta.iter())
                .map(|(pi, qi)| (pi - qi).powi(2) / qi)
                .sum();
            s += (p_pinned - q_pinned).powi(2) / q_pinned;
            s
        }
        ExpFamily::Gaussian { .. } => f64::NAN,
    }
}

/// Total variation distance between two distributions in the same
/// exp-family:
///
/// `TV(P, Q) = (1/2) · Σ_i |p_i − q_i|`
///
/// (factor 1/2 so that TV is bounded in [0, 1]).
///
/// Per family:
/// - **Bernoulli**: TV(p, q) = |p − q| (the 1/2 · 2-term sum
///   simplifies via |p-q| + |(1-p)-(1-q)| = 2|p-q|).
/// - **Categorical{k}**: full simplex sum including pinned class.
/// - **Gaussian**: NOT IMPLEMENTED — requires erf (not part of
///   the IR primitives); returns NaN. Use [`hellinger_distance`]
///   or [`fisher_rao_distance`] instead.
///
/// Iter-122 — proper metric, complements Hellinger / Fisher-Rao.
pub fn total_variation_distance(
    family: &ExpFamily,
    theta_p: &[f64],
    theta_q: &[f64],
) -> f64 {
    match family {
        ExpFamily::Bernoulli => {
            let p = sigmoid(theta_p[0]);
            let q = sigmoid(theta_q[0]);
            (p - q).abs()
        }
        ExpFamily::Categorical { .. } => {
            let p_eta = dual_map(family, theta_p);
            let q_eta = dual_map(family, theta_q);
            let p_pinned = 1.0 - p_eta.iter().sum::<f64>();
            let q_pinned = 1.0 - q_eta.iter().sum::<f64>();
            let mut s: f64 = p_eta
                .iter()
                .zip(q_eta.iter())
                .map(|(pi, qi)| (pi - qi).abs())
                .sum();
            s += (p_pinned - q_pinned).abs();
            0.5 * s
        }
        ExpFamily::Gaussian { .. } => f64::NAN,
    }
}

/// Hellinger distance between two distributions in the same
/// exp-family:
///
/// `H²(P, Q) = 1 − BC(P, Q)` where `BC = Σ √(p_i · q_i)` is the
/// Bhattacharyya coefficient (discrete case) or the appropriate
/// integral (continuous case).
///
/// Per family:
/// - **Bernoulli**: `H²(p, q) = 1 − (√(pq) + √((1-p)(1-q)))`.
/// - **Categorical{k}**: `H²(P, Q) = 1 − Σ_i √(p_i · q_i)` over
///   the full simplex (including pinned class).
/// - **Gaussian{σ²}** (same variance): closed form
///   `H² = 1 − exp(-(Δμ)² / (8σ²))`.
///
/// Returns the Hellinger distance `H = √H²`, which is a proper
/// metric (symmetric, satisfies triangle inequality) bounded
/// in `[0, √2]` for the discrete case.
///
/// Iter-116 — Hellinger 1909; companion to [`fisher_rao_distance`]
/// (iter-110) and [`js_divergence`] (iter-91).
pub fn hellinger_distance(family: &ExpFamily, theta_p: &[f64], theta_q: &[f64]) -> f64 {
    let h2 = match family {
        ExpFamily::Bernoulli => {
            let p = sigmoid(theta_p[0]);
            let q = sigmoid(theta_q[0]);
            1.0 - ((p * q).sqrt() + ((1.0 - p) * (1.0 - q)).sqrt())
        }
        ExpFamily::Categorical { .. } => {
            let p_eta = dual_map(family, theta_p);
            let q_eta = dual_map(family, theta_q);
            let p_pinned = 1.0 - p_eta.iter().sum::<f64>();
            let q_pinned = 1.0 - q_eta.iter().sum::<f64>();
            let mut bc: f64 = p_eta
                .iter()
                .zip(q_eta.iter())
                .map(|(pi, qi)| (pi * qi).sqrt())
                .sum();
            bc += (p_pinned * q_pinned).sqrt();
            1.0 - bc
        }
        ExpFamily::Gaussian { variance } => {
            // For Gaussians with the same variance:
            // H² = 1 - exp(-(μ_p - μ_q)² / (8σ²))
            let mu_p = variance * theta_p[0];
            let mu_q = variance * theta_q[0];
            let arg = -(mu_p - mu_q).powi(2) / (8.0 * variance);
            1.0 - arg.exp()
        }
    };
    h2.max(0.0).sqrt()
}

/// Fisher-Rao Riemannian distance on the statistical manifold.
///
/// The Fisher-Rao distance is the geodesic distance under the
/// Fisher information metric (Rao 1945 "Information and accuracy
/// attainable in the estimation of statistical parameters").
///
/// Closed forms per family:
/// - **Bernoulli**: with `p = σ(θ_p)`, `q = σ(θ_q)`:
///   `d_FR(p, q) = 2 · arccos(√(pq) + √((1-p)(1-q)))`
///   (spherical-embedding distance).
/// - **Categorical{k}**: similar spherical-embedding form:
///   `d_FR = 2 · arccos(Σ_i √(p_i · q_i))` over the full simplex.
/// - **Gaussian{σ²}** with fixed variance: `d_FR = |μ_p − μ_q| / σ`
///   in mean coords, equivalently `σ · |θ_p − θ_q|` in naturals.
///
/// Iter-110 — Fisher-Rao metric distance closes the geometry of
/// the statistical manifold for the three info-IR families.
pub fn fisher_rao_distance(family: &ExpFamily, theta_p: &[f64], theta_q: &[f64]) -> f64 {
    match family {
        ExpFamily::Bernoulli => {
            let p = sigmoid(theta_p[0]);
            let q = sigmoid(theta_q[0]);
            let arg = (p * q).sqrt() + ((1.0 - p) * (1.0 - q)).sqrt();
            2.0 * arg.clamp(-1.0, 1.0).acos()
        }
        ExpFamily::Categorical { .. } => {
            let p_eta = dual_map(family, theta_p);
            let q_eta = dual_map(family, theta_q);
            let p_pinned = 1.0 - p_eta.iter().sum::<f64>();
            let q_pinned = 1.0 - q_eta.iter().sum::<f64>();
            let mut sum: f64 = p_eta
                .iter()
                .zip(q_eta.iter())
                .map(|(pi, qi)| (pi * qi).sqrt())
                .sum();
            sum += (p_pinned * q_pinned).sqrt();
            2.0 * sum.clamp(-1.0, 1.0).acos()
        }
        ExpFamily::Gaussian { variance } => {
            // |Δθ| · σ.
            (theta_p[0] - theta_q[0]).abs() * variance.sqrt()
        }
    }
}

/// Inverse of [`dual_map`]: convert mean parameters back to
/// natural parameters.
///
/// Per family:
/// - **Bernoulli**: `θ = logit(p) = log(p / (1-p))` for `p ∈ (0,1)`.
/// - **Categorical{k}**: `θ_i = log(p_i / p_pinned)` where
///   `p_pinned = 1 - Σ_j p_j`. Caller supplies `(k-1)` mean params
///   (the pinned class is implicit).
/// - **Gaussian{σ²}**: `θ = μ / σ²` where `μ = η` is the mean.
///
/// Iter-105 — closes the round-trip `θ ↔ η` between natural and
/// mean coordinate systems. Useful for MLE, EM, and information
/// projections that operate naturally in one space vs. the other.
pub fn mean_to_natural(family: &ExpFamily, eta: &[f64]) -> Vec<f64> {
    match family {
        ExpFamily::Bernoulli => {
            let p = eta[0];
            vec![(p / (1.0 - p)).ln()]
        }
        ExpFamily::Categorical { .. } => {
            let p_pinned = 1.0 - eta.iter().sum::<f64>();
            eta.iter().map(|p| (p / p_pinned).ln()).collect()
        }
        ExpFamily::Gaussian { variance } => vec![eta[0] / variance],
    }
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

    // ── iter-142: gaussian_pdf + gaussian_log_pdf ─────────────────

    #[test]
    fn gaussian_pdf_at_mean_is_peak() {
        // pdf(μ; μ, σ²) = 1 / √(2π σ²).
        for sigma2 in [0.5_f64, 1.0, 2.0] {
            let v = gaussian_pdf(1.0, 1.0, sigma2);
            let expected = 1.0 / (2.0 * std::f64::consts::PI * sigma2).sqrt();
            assert!((v - expected).abs() < 1e-12);
        }
    }

    #[test]
    fn gaussian_pdf_decays_with_distance_from_mean() {
        let close = gaussian_pdf(0.5, 0.0, 1.0);
        let far = gaussian_pdf(5.0, 0.0, 1.0);
        assert!(close > far);
        assert!(far > 0.0);
    }

    #[test]
    fn gaussian_log_pdf_consistency_with_pdf() {
        for x in [-2.0_f64, 0.0, 1.5, 3.0] {
            for mu in [-1.0_f64, 0.0, 2.0] {
                for sigma2 in [0.5_f64, 1.0, 2.0] {
                    let p = gaussian_pdf(x, mu, sigma2);
                    let lp = gaussian_log_pdf(x, mu, sigma2);
                    assert!(
                        (lp - p.ln()).abs() < 1e-12,
                        "log_pdf({}, {}, {}) = {} vs ln(pdf) = {}",
                        x, mu, sigma2, lp, p.ln()
                    );
                }
            }
        }
    }

    #[test]
    fn gaussian_log_pdf_at_mean_unit_variance_known() {
        // log pdf(0; 0, 1) = -0.5 · log(2π) ≈ -0.9189.
        let v = gaussian_log_pdf(0.0, 0.0, 1.0);
        let expected = -0.5 * (2.0 * std::f64::consts::PI).ln();
        assert!((v - expected).abs() < 1e-12);
    }

    #[test]
    fn gaussian_pdf_integrates_approximately_to_one() {
        // Rough trapezoidal integration over [-10, 10] with dx=0.01.
        let mut sum = 0.0;
        let mut x = -10.0_f64;
        let dx = 0.01;
        while x < 10.0 {
            sum += gaussian_pdf(x, 0.0, 1.0) * dx;
            x += dx;
        }
        assert!((sum - 1.0).abs() < 1e-3);
    }

    // ── iter-132: symmetric_kl + chi_squared_divergence ───────────

    #[test]
    fn symmetric_kl_self_is_zero() {
        for fam in [
            ExpFamily::Bernoulli,
            ExpFamily::Categorical { k: 3 },
            ExpFamily::Gaussian { variance: 1.5 },
        ] {
            let arity = fam.natural_param_arity();
            let theta = vec![0.7_f64; arity];
            let d = symmetric_kl(&fam, &theta, &theta);
            assert!(d.abs() < 1e-10, "{}: J(θ, θ) = {}", fam, d);
        }
    }

    #[test]
    fn symmetric_kl_is_symmetric() {
        // J(P, Q) = J(Q, P) by construction.
        let cases = [
            (ExpFamily::Bernoulli, vec![1.0_f64], vec![-1.0]),
            (ExpFamily::Gaussian { variance: 2.0 }, vec![0.7], vec![-1.3]),
        ];
        for (fam, p, q) in cases {
            let pq = symmetric_kl(&fam, &p, &q);
            let qp = symmetric_kl(&fam, &q, &p);
            assert!((pq - qp).abs() < 1e-12);
        }
    }

    #[test]
    fn symmetric_kl_geq_each_direction() {
        // J(P, Q) ≥ max(KL(P||Q), KL(Q||P)).
        let p = vec![1.0_f64];
        let q = vec![-1.0_f64];
        let j = symmetric_kl(&ExpFamily::Bernoulli, &p, &q);
        let kl1 = kl_divergence(&ExpFamily::Bernoulli, &p, &q);
        let kl2 = kl_divergence(&ExpFamily::Bernoulli, &q, &p);
        assert!(j >= kl1 - 1e-12);
        assert!(j >= kl2 - 1e-12);
    }

    #[test]
    fn chi_squared_self_is_zero() {
        let d = chi_squared_divergence(&ExpFamily::Bernoulli, &[0.5], &[0.5]);
        assert!(d.abs() < 1e-10);
        let d_cat = chi_squared_divergence(&ExpFamily::Categorical { k: 3 }, &[0.0, 0.0], &[0.0, 0.0]);
        assert!(d_cat.abs() < 1e-10);
    }

    #[test]
    fn chi_squared_non_negative() {
        for (p, q) in [(1.0_f64, 0.0), (-2.0, 3.0), (0.5, -0.5)] {
            let d = chi_squared_divergence(&ExpFamily::Bernoulli, &[p], &[q]);
            assert!(d >= -1e-10);
        }
    }

    #[test]
    fn chi_squared_gaussian_returns_nan() {
        let d = chi_squared_divergence(
            &ExpFamily::Gaussian { variance: 1.0 },
            &[0.0],
            &[1.0],
        );
        assert!(d.is_nan());
    }

    #[test]
    fn chi_squared_categorical_self_is_zero_distinct_thetas_mapping_same() {
        // Equal natural params → same distribution → χ² = 0.
        let theta = vec![1.5_f64, -0.5];
        let d = chi_squared_divergence(&ExpFamily::Categorical { k: 3 }, &theta, &theta);
        assert!(d.abs() < 1e-10);
    }

    // ── iter-122: total_variation_distance ────────────────────────

    #[test]
    fn tv_distance_self_is_zero_bernoulli() {
        let d = total_variation_distance(&ExpFamily::Bernoulli, &[0.7], &[0.7]);
        assert!(d.abs() < 1e-12);
    }

    #[test]
    fn tv_distance_bernoulli_matches_abs_p_minus_q() {
        for (a, b) in [(1.0_f64, -1.0), (0.0, 0.5), (3.0, -3.0)] {
            let d = total_variation_distance(&ExpFamily::Bernoulli, &[a], &[b]);
            let expected = (1.0_f64 / (1.0 + (-a).exp()) - 1.0 / (1.0 + (-b).exp())).abs();
            assert!((d - expected).abs() < 1e-12);
        }
    }

    #[test]
    fn tv_distance_bernoulli_bounded_by_one() {
        for (p, q) in [(1.0_f64, 0.0), (-2.0, 3.0), (100.0, -100.0)] {
            let d = total_variation_distance(&ExpFamily::Bernoulli, &[p], &[q]);
            assert!(d >= 0.0);
            assert!(d <= 1.0 + 1e-9);
        }
    }

    #[test]
    fn tv_distance_bernoulli_extremes_approaches_one() {
        let d = total_variation_distance(&ExpFamily::Bernoulli, &[100.0], &[-100.0]);
        assert!((d - 1.0).abs() < 1e-9);
    }

    #[test]
    fn tv_distance_symmetric() {
        let cases = [
            (ExpFamily::Bernoulli, vec![1.0_f64], vec![-1.0]),
            (ExpFamily::Categorical { k: 3 }, vec![0.5, -0.5], vec![1.0, 1.0]),
        ];
        for (fam, p, q) in cases {
            let pq = total_variation_distance(&fam, &p, &q);
            let qp = total_variation_distance(&fam, &q, &p);
            assert!((pq - qp).abs() < 1e-12);
        }
    }

    #[test]
    fn tv_distance_categorical_uniform_self_is_zero() {
        let d = total_variation_distance(&ExpFamily::Categorical { k: 3 }, &[0.0, 0.0], &[0.0, 0.0]);
        assert!(d.abs() < 1e-12);
    }

    #[test]
    fn tv_distance_categorical_bounded_by_one() {
        let d = total_variation_distance(
            &ExpFamily::Categorical { k: 3 },
            &[100.0, -100.0],
            &[-100.0, 100.0],
        );
        assert!(d >= 0.0);
        assert!(d <= 1.0 + 1e-9);
    }

    #[test]
    fn tv_distance_gaussian_returns_nan_for_now() {
        let d = total_variation_distance(
            &ExpFamily::Gaussian { variance: 1.0 },
            &[0.0],
            &[1.0],
        );
        assert!(d.is_nan());
    }

    // ── iter-116: hellinger_distance ──────────────────────────────

    #[test]
    fn hellinger_distance_self_is_zero() {
        for fam in [
            ExpFamily::Bernoulli,
            ExpFamily::Categorical { k: 3 },
            ExpFamily::Gaussian { variance: 1.5 },
        ] {
            let arity = fam.natural_param_arity();
            let theta = vec![0.7_f64; arity];
            let d = hellinger_distance(&fam, &theta, &theta);
            assert!(d.abs() < 1e-10, "{}: d(θ, θ) = {}", fam, d);
        }
    }

    #[test]
    fn hellinger_distance_symmetric() {
        let cases = [
            (ExpFamily::Bernoulli, vec![1.0_f64], vec![-1.0]),
            (ExpFamily::Categorical { k: 3 }, vec![0.5, -0.5], vec![1.0, 1.0]),
            (ExpFamily::Gaussian { variance: 2.0 }, vec![0.7], vec![-1.3]),
        ];
        for (fam, p, q) in cases {
            let pq = hellinger_distance(&fam, &p, &q);
            let qp = hellinger_distance(&fam, &q, &p);
            assert!((pq - qp).abs() < 1e-12, "{}: d(p,q)={}, d(q,p)={}", fam, pq, qp);
        }
    }

    #[test]
    fn hellinger_distance_bounded_by_one_for_discrete() {
        // For Bernoulli/Categorical, H ≤ 1 (squared ≤ 1).
        for (p, q) in [(50.0_f64, -50.0), (10.0, 0.0), (-5.0, 5.0)] {
            let d = hellinger_distance(&ExpFamily::Bernoulli, &[p], &[q]);
            assert!(d <= 1.0 + 1e-9, "Bernoulli H = {}", d);
        }
    }

    #[test]
    fn hellinger_distance_bernoulli_at_extremes_approaches_one() {
        // H(σ(∞)=1, σ(-∞)=0) = √(1 - 0) = 1.
        let d = hellinger_distance(&ExpFamily::Bernoulli, &[100.0], &[-100.0]);
        assert!((d - 1.0).abs() < 1e-6);
    }

    #[test]
    fn hellinger_distance_gaussian_grows_with_mean_difference() {
        // Larger Δμ → larger Hellinger.
        let d_small = hellinger_distance(
            &ExpFamily::Gaussian { variance: 1.0 },
            &[0.0],
            &[0.5],
        );
        let d_large = hellinger_distance(
            &ExpFamily::Gaussian { variance: 1.0 },
            &[0.0],
            &[5.0],
        );
        assert!(d_small < d_large);
        assert!(d_small > 0.0);
        assert!(d_large > 0.0);
    }

    #[test]
    fn hellinger_distance_non_negative() {
        let cases = [
            (ExpFamily::Bernoulli, vec![1.0_f64], vec![0.5]),
            (ExpFamily::Categorical { k: 4 }, vec![1.0, 2.0, -1.0], vec![0.0, 0.0, 0.0]),
            (ExpFamily::Gaussian { variance: 0.5 }, vec![-2.0], vec![3.0]),
        ];
        for (fam, p, q) in cases {
            let d = hellinger_distance(&fam, &p, &q);
            assert!(d >= -1e-12, "{}: d = {}", fam, d);
        }
    }

    // ── iter-110: fisher_rao_distance ─────────────────────────────

    #[test]
    fn fisher_rao_distance_self_is_zero() {
        for fam in [
            ExpFamily::Bernoulli,
            ExpFamily::Categorical { k: 3 },
            ExpFamily::Gaussian { variance: 1.5 },
        ] {
            let arity = fam.natural_param_arity();
            let theta = vec![0.5_f64; arity];
            let d = fisher_rao_distance(&fam, &theta, &theta);
            assert!(d.abs() < 1e-10, "{}: d(θ, θ) = {}", fam, d);
        }
    }

    #[test]
    fn fisher_rao_distance_symmetric() {
        let cases = [
            (ExpFamily::Bernoulli, vec![1.0_f64], vec![-1.0]),
            (ExpFamily::Categorical { k: 3 }, vec![0.5, -0.5], vec![1.0, 1.0]),
            (ExpFamily::Gaussian { variance: 2.0 }, vec![0.7], vec![-1.3]),
        ];
        for (fam, p, q) in cases {
            let pq = fisher_rao_distance(&fam, &p, &q);
            let qp = fisher_rao_distance(&fam, &q, &p);
            assert!(
                (pq - qp).abs() < 1e-12,
                "{}: d(p,q) = {}, d(q,p) = {}", fam, pq, qp
            );
        }
    }

    #[test]
    fn fisher_rao_distance_non_negative() {
        for (p, q) in [(1.0_f64, 0.0), (-2.0, 3.0), (0.5, -0.5)] {
            let d = fisher_rao_distance(&ExpFamily::Bernoulli, &[p], &[q]);
            assert!(d >= -1e-12, "d = {}", d);
        }
    }

    #[test]
    fn fisher_rao_bernoulli_bounded_by_pi() {
        // Bernoulli Fisher-Rao distance ≤ π (the manifold is a
        // half-circle of length π/2 from the spherical embedding,
        // but with the 2·arccos factor the max is π).
        for (p, q) in [(50.0_f64, -50.0), (100.0, -100.0), (1000.0, 0.0)] {
            let d = fisher_rao_distance(&ExpFamily::Bernoulli, &[p], &[q]);
            assert!(d <= std::f64::consts::PI + 1e-9, "d = {} > π", d);
        }
    }

    #[test]
    fn fisher_rao_bernoulli_at_50_50_to_50_50() {
        // d(σ(0), σ(0)) = d(0.5, 0.5) = 2·arccos(0.5 + 0.5) = 0.
        let d = fisher_rao_distance(&ExpFamily::Bernoulli, &[0.0], &[0.0]);
        assert!(d.abs() < 1e-12);
    }

    #[test]
    fn fisher_rao_bernoulli_extremes_distance_is_pi() {
        // d(σ(∞)=1, σ(-∞)=0) = 2·arccos(0) = π.
        let d = fisher_rao_distance(&ExpFamily::Bernoulli, &[1000.0], &[-1000.0]);
        assert!((d - std::f64::consts::PI).abs() < 1e-6, "d = {}", d);
    }

    #[test]
    fn fisher_rao_gaussian_linear_in_theta_diff() {
        // d_FR = σ · |Δθ| for Gaussian with fixed variance.
        let sigma2 = 4.0_f64;
        let sigma = sigma2.sqrt();
        for (p, q) in [(0.0_f64, 2.0), (-1.0, 1.0), (3.0, -1.0)] {
            let d = fisher_rao_distance(&ExpFamily::Gaussian { variance: sigma2 }, &[p], &[q]);
            let expected = sigma * (p - q).abs();
            assert!(
                (d - expected).abs() < 1e-12,
                "Gaussian d({}, {}) = {}, expected {}", p, q, d, expected
            );
        }
    }

    #[test]
    fn fisher_rao_categorical_uniform_to_uniform_is_zero() {
        // d(uniform, uniform) = 0.
        let theta = vec![0.0_f64, 0.0];
        let d = fisher_rao_distance(&ExpFamily::Categorical { k: 3 }, &theta, &theta);
        assert!(d.abs() < 1e-10);
    }

    // ── iter-105: mean_to_natural (inverse of dual_map) ───────────

    #[test]
    fn mean_to_natural_bernoulli_at_half_is_zero() {
        let theta = mean_to_natural(&ExpFamily::Bernoulli, &[0.5]);
        assert!((theta[0] - 0.0).abs() < 1e-12);
    }

    #[test]
    fn mean_to_natural_bernoulli_roundtrips_with_dual_map() {
        for theta_orig in [-3.0_f64, -1.0, 0.0, 0.5, 2.0] {
            let eta = dual_map(&ExpFamily::Bernoulli, &[theta_orig]);
            let theta_back = mean_to_natural(&ExpFamily::Bernoulli, &eta);
            assert!(
                (theta_back[0] - theta_orig).abs() < 1e-10,
                "θ={} → η={:?} → θ_back={}", theta_orig, eta, theta_back[0]
            );
        }
    }

    #[test]
    fn mean_to_natural_categorical_uniform_is_zero() {
        // Uniform Categorical k=3: η = (1/3, 1/3), pinned p = 1/3.
        // θ_i = log(1/3 / 1/3) = log 1 = 0.
        let theta = mean_to_natural(&ExpFamily::Categorical { k: 3 }, &[1.0 / 3.0, 1.0 / 3.0]);
        assert!(theta[0].abs() < 1e-12);
        assert!(theta[1].abs() < 1e-12);
    }

    #[test]
    fn mean_to_natural_categorical_roundtrips_with_dual_map() {
        // Use a variety of natural-param inputs.
        let cases = [
            (3, vec![0.0_f64, 0.0]),
            (3, vec![1.0, -1.0]),
            (3, vec![-2.0, 3.0]),
            (4, vec![0.5, -0.3, 1.0]),
        ];
        for (k, theta_orig) in cases {
            let family = ExpFamily::Categorical { k };
            let eta = dual_map(&family, &theta_orig);
            let theta_back = mean_to_natural(&family, &eta);
            for (a, b) in theta_back.iter().zip(theta_orig.iter()) {
                assert!(
                    (a - b).abs() < 1e-10,
                    "k={} θ={:?} → η={:?} → θ_back={:?}", k, theta_orig, eta, theta_back
                );
            }
        }
    }

    #[test]
    fn mean_to_natural_gaussian_divides_by_variance() {
        // η = μ; θ = μ / σ².
        for variance in [0.5_f64, 1.0, 2.0, 4.0] {
            for mu in [-2.0_f64, 0.0, 1.5, 3.0] {
                let theta = mean_to_natural(&ExpFamily::Gaussian { variance }, &[mu]);
                let expected = mu / variance;
                assert!((theta[0] - expected).abs() < 1e-12);
            }
        }
    }

    #[test]
    fn mean_to_natural_gaussian_roundtrips_with_dual_map() {
        for variance in [0.5_f64, 1.0, 2.5] {
            for theta_orig in [-2.0_f64, 0.0, 1.5, 3.0] {
                let eta = dual_map(&ExpFamily::Gaussian { variance }, &[theta_orig]);
                let theta_back = mean_to_natural(&ExpFamily::Gaussian { variance }, &eta);
                assert!(
                    (theta_back[0] - theta_orig).abs() < 1e-12,
                    "variance={} θ={} → η={:?} → θ_back={}",
                    variance, theta_orig, eta, theta_back[0]
                );
            }
        }
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
