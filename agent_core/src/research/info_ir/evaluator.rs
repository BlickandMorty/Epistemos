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

/// Jensen-Shannon divergence from explicit probability vectors:
///
/// `JS(P, Q) = 0.5 · KL(P || M) + 0.5 · KL(Q || M)`
/// where `M = (P + Q) / 2`.
///
/// Bounded in [0, ln 2] for discrete probability vectors;
/// symmetric and proper distance after taking sqrt (Jensen-Shannon
/// distance).
///
/// Returns NaN on length mismatch or empty input.
///
/// Iter-182 — companion to kl_from_probs (iter-170).
pub fn js_from_probs(p: &[f64], q: &[f64]) -> f64 {
    if p.len() != q.len() || p.is_empty() {
        return f64::NAN;
    }
    let m: Vec<f64> = p.iter().zip(q.iter()).map(|(pi, qi)| 0.5 * (pi + qi)).collect();
    0.5 * kl_from_probs(p, &m) + 0.5 * kl_from_probs(q, &m)
}

/// Categorical cross-entropy from explicit probability vectors:
///
///   H(P, Q) = −Σᵢ pᵢ · ln(qᵢ).
///
/// Bounded below by `H(p)` (Gibbs' inequality, equality iff
/// `p == q`). Uses the `0·log 0 = 0` convention on the `p` side
/// but returns `INFINITY` when `qᵢ = 0` and `pᵢ > 0`.
///
/// Returns NaN on length mismatch or empty input.
///
/// Iter-248 — explicit-prob CE; mirror of EML's
/// `closure_categorical_cross_entropy` (iter-217) and the
/// `cross_entropy(family, …)` exp-family form.
pub fn cross_entropy_from_probs(p: &[f64], q: &[f64]) -> f64 {
    if p.len() != q.len() || p.is_empty() {
        return f64::NAN;
    }
    let mut acc = 0.0_f64;
    for (pi, qi) in p.iter().zip(q.iter()) {
        if *pi > 0.0 {
            if *qi <= 0.0 {
                return f64::INFINITY;
            }
            acc += pi * qi.ln();
        }
    }
    -acc
}

/// Normalized Shannon entropy `H̃(p) = H(p) / ln(n)`.
///
/// Maps onto `[0, 1]` for any probability vector of length `n ≥ 2`:
/// 0 for deterministic, 1 for uniform. Useful as a unit-free
/// "concentration" measure that doesn't depend on the alphabet
/// size.
///
/// Returns NaN on empty input or `n == 1` (max-entropy is 0, so
/// the ratio is undefined for the trivial single-class case).
///
/// Iter-254 — pairs with `categorical_entropy_from_probs`
/// (Shannon) and `uniform_entropy` (ln n baseline) to produce
/// the unit-free ratio.
pub fn normalized_entropy(probs: &[f64]) -> f64 {
    let n = probs.len();
    if n < 2 {
        return f64::NAN;
    }
    let h = categorical_entropy_from_probs(probs);
    let h_max = uniform_entropy(n);
    if h_max <= 0.0 {
        return f64::NAN;
    }
    h / h_max
}

/// Entropy ratio `H(P) / H(Q)`.
///
/// Useful for comparing uncertainty scales across two
/// distributions (e.g., posterior-to-prior collapse ratio in
/// VAEs). Returns NaN if either input is empty or if `H(Q) = 0`
/// (deterministic Q — undefined ratio).
///
/// Iter-296 — composition primitive over
/// `categorical_entropy_from_probs`. Useful for normalized
/// drift monitoring.
pub fn entropy_ratio(p: &[f64], q: &[f64]) -> f64 {
    if p.is_empty() || q.is_empty() {
        return f64::NAN;
    }
    let hq = categorical_entropy_from_probs(q);
    if hq <= 0.0 {
        return f64::NAN;
    }
    categorical_entropy_from_probs(p) / hq
}

/// Signed entropy difference `H(P) − H(Q)`.
///
/// Positive when `P` is "more uncertain than `Q`"; negative
/// when `Q` is more uncertain. Bounded in `[−ln(n_q), ln(n_p)]`
/// where `n_p, n_q` are alphabet sizes.
///
/// Returns NaN if either input is empty.
///
/// Iter-290 — composition primitive over
/// `categorical_entropy_from_probs`. Useful for monitoring
/// uncertainty drift between two distributions
/// (e.g., posterior at step t vs prior).
pub fn entropy_diff(p: &[f64], q: &[f64]) -> f64 {
    if p.is_empty() || q.is_empty() {
        return f64::NAN;
    }
    categorical_entropy_from_probs(p) - categorical_entropy_from_probs(q)
}

/// KL divergence from a probability vector to the n-class
/// uniform distribution:
///
///   KL(p || uniform_n) = ln(n) − H(p).
///
/// Reads as the "sparsity" / "concentration" of `p`: zero when
/// `p` is uniform, ln(n) when `p` is deterministic. Bounded in
/// `[0, ln n]`.
///
/// Returns NaN on empty input.
///
/// Iter-284 — composes `uniform_entropy` and
/// `categorical_entropy_from_probs`; equivalent to
/// `−ln(n) · (1 − normalized_entropy(p))` in flipped sign.
pub fn kl_to_uniform(probs: &[f64]) -> f64 {
    if probs.is_empty() {
        return f64::NAN;
    }
    let h_max = uniform_entropy(probs.len());
    let h = categorical_entropy_from_probs(probs);
    h_max - h
}

/// Uniform-distribution Shannon entropy `H(uniform_n) = ln n`.
///
/// The maximum-entropy reference baseline for an `n`-outcome
/// categorical. Any probability distribution `p` on `n` outcomes
/// satisfies `H(p) ≤ ln n` with equality iff `p` is uniform —
/// Gibbs' inequality.
///
/// Returns `f64::NEG_INFINITY` for `n == 0` (no outcomes ⇒ no
/// entropy defined).
///
/// Iter-242 — reference baseline for entropy ratios:
/// `H(p) / ln n` is the normalized entropy in `[0, 1]`. Pairs
/// with `categorical_entropy_from_probs` (Shannon), `min_entropy`
/// (Rényi ∞), and `collision_entropy` (Rényi 2).
pub fn uniform_entropy(n: usize) -> f64 {
    if n == 0 {
        return f64::NEG_INFINITY;
    }
    (n as f64).ln()
}

/// Collision entropy `H_2(p) = −ln(Σᵢ pᵢ²)` — the α=2 Rényi
/// entropy.
///
/// Reads as the negative log probability that two independent
/// draws collide on the same outcome. Bounded:
/// `0 ≤ H_2 ≤ ln n`. Equals `−ln(1 − G(p))` where `G` is the
/// Gini impurity (iter-200).
///
/// Returns NaN on empty input.
///
/// Iter-236 — completes the (Shannon H, Min H_∞, Collision H_2)
/// Rényi triad alongside `categorical_entropy_from_probs` and
/// `min_entropy`; also the second α-slice of the
/// `renyi_divergence_from_probs` family.
pub fn collision_entropy(probs: &[f64]) -> f64 {
    if probs.is_empty() {
        return f64::NAN;
    }
    let sum_sq: f64 = probs.iter().map(|p| p * p).sum();
    if sum_sq <= 0.0 {
        return f64::INFINITY;
    }
    -sum_sq.ln()
}

/// Min-entropy `H_∞(p) = −ln(max_i pᵢ)` — the worst-case Rényi
/// entropy (limit `α → ∞`).
///
/// Bounded below by 0 (deterministic) and above by `ln(n)` for an
/// `n`-class uniform. Always `H_∞(p) ≤ H(p)` (Shannon entropy);
/// the gap measures how "peaky" the distribution is.
///
/// Returns NaN on empty input. Returns `INFINITY` when the mode
/// has probability 0 (every entry zero — degenerate input).
///
/// Iter-230 — companion to `mode_probability` (iter-224) and
/// `categorical_entropy_from_probs` (iter-157); the α=∞ extreme
/// of the Rényi family that bridges between
/// `renyi_divergence_from_probs` (iter-194) and the bounded-
/// adversary entropy bounds in cryptography.
pub fn min_entropy(probs: &[f64]) -> f64 {
    if probs.is_empty() {
        return f64::NAN;
    }
    let m = mode_probability(probs);
    if m <= 0.0 {
        return f64::INFINITY;
    }
    -m.ln()
}

/// Rényi α-entropy at arbitrary α > 0, α ≠ 1:
///
/// `H_α(p) = 1/(1−α) · ln(Σᵢ pᵢ^α)`.
///
/// Generalizes the Shannon entropy (`α → 1` limit), collision
/// entropy (`α = 2`), and min-entropy (`α → ∞` limit). The
/// family is monotone non-increasing in α: `α₁ ≤ α₂ ⇒
/// H_{α₁} ≥ H_{α₂}`.
///
/// Behavior:
/// - Empty input → NaN.
/// - Σ pᵢ^α ≤ 0 (all-zero input) → INFINITY.
/// - At `α = 1` (within `1e-12`) the caller almost certainly wants
///   Shannon entropy; this function returns NaN there (the formula
///   has a removable singularity). Use `categorical_entropy_from_probs`
///   instead.
/// - `α ≤ 0` → NaN (the Rényi formula is only positive-α).
///
/// Iter-320 — completes the (Shannon H, collision H_2, min H_∞)
/// triad with the general α-slice. Matches the existing
/// `renyi_divergence_from_probs(_, _, α)` signature.
///
/// Source. Rényi, "On measures of entropy and information",
/// Proc. 4th Berkeley Symposium on Mathematical Statistics and
/// Probability, Vol. 1, pp. 547-561 (1961). The α-entropy is
/// defined in §4 eq. (3.4).
pub fn renyi_entropy_from_probs(probs: &[f64], alpha: f64) -> f64 {
    if probs.is_empty() {
        return f64::NAN;
    }
    if alpha <= 0.0 || !alpha.is_finite() {
        return f64::NAN;
    }
    if (alpha - 1.0).abs() < 1e-12 {
        return f64::NAN;
    }
    let sum: f64 = probs.iter().map(|p| p.powf(alpha)).sum();
    if sum <= 0.0 {
        return f64::INFINITY;
    }
    sum.ln() / (1.0 - alpha)
}

/// Tsallis q-entropy at arbitrary q > 0, q ≠ 1:
///
/// `S_q(p) = 1/(q−1) · (1 − Σᵢ pᵢ^q)`.
///
/// Non-additive generalization of the Shannon entropy used in
/// non-extensive statistical mechanics. The (q → 1) limit
/// recovers Shannon, and at q = 2 the formula reduces to
/// `1 − Σᵢ pᵢ²` — the Gini-Simpson diversity index.
///
/// Unlike Rényi entropy, S_q is not the logarithm of an L^q-norm
/// fold but a polynomial — the two families are related by
/// `H_α^Rényi = (1/(1−α)) · ln(1 − (α−1)·S_α^Tsallis)`.
///
/// Behavior:
/// - Empty input → NaN.
/// - `q ≤ 0` or `q == 1` (within `1e-12`) → NaN.
///
/// Iter-326 — companion to [`renyi_entropy_from_probs`]
/// (iter-320). Together they cover both the additive (Rényi) and
/// non-additive (Tsallis) one-parameter generalizations of
/// Shannon entropy.
///
/// Source. Tsallis, "Possible generalization of Boltzmann-Gibbs
/// statistics", Journal of Statistical Physics 52:479-487
/// (1988). The q-entropy is defined in eq. (1).
pub fn tsallis_entropy_from_probs(probs: &[f64], q: f64) -> f64 {
    if probs.is_empty() {
        return f64::NAN;
    }
    if q <= 0.0 || !q.is_finite() {
        return f64::NAN;
    }
    if (q - 1.0).abs() < 1e-12 {
        return f64::NAN;
    }
    let sum: f64 = probs.iter().map(|p| p.powf(q)).sum();
    (1.0 - sum) / (q - 1.0)
}

/// Hill number of order q (effective number of components):
///
/// `N_q(p) = (Σᵢ pᵢ^q)^(1/(1−q))` for q > 0, q ≠ 1.
/// `N_1(p) = exp(H_Shannon(p))`.
///
/// The exponentiated Rényi α-entropy, interpreted as the
/// "effective number of equally-likely categories" that the
/// distribution behaves like. The standard diversity-numbers
/// family in ecology and NLP:
/// - `N_1 = exp(H)` — Shannon effective N.
/// - `N_2 = 1 / Σ pᵢ²` — Simpson effective N.
/// - `N_∞ → 1 / max pᵢ` — Berger-Parker (limit).
///
/// Behavior:
/// - Empty → NaN.
/// - `q ≤ 0` or non-finite → NaN.
/// - `q == 1` (within 1e-12) → exp(Shannon).
/// - Degenerate (Σ pᵢ^q ≤ 0) → 0.
///
/// Iter-332 — completes the (Rényi entropy, Tsallis entropy,
/// Hill number) trio of α-family generalizations on Info-IR.
/// Among the three, the Hill number is the only one with units
/// matching the original "number of categories" — the canonical
/// diversity index for direct interpretation.
///
/// Source. Hill, M. O., "Diversity and Evenness: A Unifying
/// Notation and Its Consequences", Ecology 54(2):427-432 (1973);
/// the connection N_q = exp(H_q^Rényi) is given in eq. (3).
pub fn hill_number_from_probs(probs: &[f64], q: f64) -> f64 {
    if probs.is_empty() {
        return f64::NAN;
    }
    if q <= 0.0 || !q.is_finite() {
        return f64::NAN;
    }
    if (q - 1.0).abs() < 1e-12 {
        return categorical_entropy_from_probs(probs).exp();
    }
    let sum: f64 = probs.iter().map(|p| p.powf(q)).sum();
    if sum <= 0.0 {
        return 0.0;
    }
    sum.powf(1.0 / (1.0 - q))
}

/// Binary entropy `H₂(p) = −p·ln(p) − (1−p)·ln(1−p)` (in nats).
///
/// The Shannon entropy of a Bernoulli(p) distribution, viewed as
/// a scalar function on the unit interval. Conventionally
/// `0·ln(0) = 0`, so `H₂(0) = H₂(1) = 0` and `H₂(0.5) = ln(2)`
/// is the maximum (uniform over two outcomes).
///
/// Behavior:
/// - `p < 0` or `p > 1` → NaN (outside the Bernoulli parameter
///   domain).
/// - NaN input → NaN.
/// - Boundary values 0 and 1 return 0 exactly by the convention.
///
/// Iter-338 — fills the previously-missing dedicated scalar
/// primitive for `H(Bernoulli(p))`. The 2-class case
/// `categorical_entropy_from_probs(&[p, 1-p])` already produces
/// the same value, but at the cost of allocating a temporary
/// 2-vector at every call site; binary_entropy is the zero-
/// allocation scalar fast path used in cryptography, channel-
/// capacity bounds, and binary-hypothesis-testing identities.
///
/// Source. Cover & Thomas, "Elements of Information Theory"
/// (2nd ed., 2006) §2.1 eq. (2.6); Shannon (1948) §6 eq. (4).
pub fn binary_entropy(p: f64) -> f64 {
    if p.is_nan() || !(0.0..=1.0).contains(&p) {
        return f64::NAN;
    }
    if p == 0.0 || p == 1.0 {
        return 0.0;
    }
    let q = 1.0 - p;
    -p * p.ln() - q * q.ln()
}

/// Binary KL divergence
/// `D_KL(Bernoulli(p) ‖ Bernoulli(q)) =
///      p·ln(p/q) + (1−p)·ln((1−p)/(1−q))`
/// (in nats), the Bernoulli-vs-Bernoulli KL specialization.
///
/// Convention `0·ln(0/·) = 0` (so the boundary cases p = 0, p = 1
/// collapse correctly). When p > 0 and q = 0, or 1 − p > 0 and
/// q = 1, the divergence is `+∞`.
///
/// Behavior:
/// - p or q outside `[0, 1]` → NaN.
/// - NaN input → NaN.
/// - p, q ∈ {0, 1} are handled by the 0·ln(0) = 0 convention.
///
/// Iter-344 — companion to [`binary_entropy`] (iter-338); the
/// scalar zero-allocation fast path for the Bernoulli-vs-
/// Bernoulli KL used in:
/// - The Hoeffding/Bernstein binary-channel concentration
///   inequalities (where the divergence is the natural rate
///   function).
/// - Logistic regression's mirror-descent step (KL between
///   Bernoulli(σ(η)) and the target label as a Bernoulli).
///
/// `kl_from_probs(&[p, 1−p], &[q, 1−q])` produces the same
/// value but allocates two temporary 2-vectors per call; this
/// function is the allocation-free scalar specialization.
///
/// Source. Cover & Thomas, "Elements of Information Theory"
/// (2nd ed., 2006) §2.3 eq. (2.26) — KL divergence definition;
/// Bernoulli specialization is the n = 1 case of eq. (2.27).
/// Binary Jensen-Shannon divergence
/// `JS(Bernoulli(p), Bernoulli(q)) = ½·(D_KL(p ‖ m) + D_KL(q ‖ m))`
/// where `m = (p + q) / 2` (in nats).
///
/// Symmetric, bounded: `0 ≤ JS ≤ ln(2)`. Self-JS is 0; JS = ln(2)
/// when one of `{p, q}` is 0 and the other is 1.
///
/// Behavior:
/// - p or q outside `[0, 1]` → NaN.
/// - NaN input → NaN.
/// - `m = 0` (both p = 0 and q = 0) → 0 (degenerate distribution
///   pair; both KL terms are 0·ln(0/0) = 0 by convention).
///
/// Iter-350 — scalar zero-allocation fast path for Bernoulli-vs-
/// Bernoulli JS. Companion to [`binary_kl_divergence`] (iter-344);
/// the JS form is the symmetric, bounded alternative used when:
/// - Symmetry is required (clustering with distance-like metric).
/// - The unbounded ±∞ of KL is undesirable (the q = 0 / q = 1
///   edges return finite JS values).
///
/// Source. Lin, J., "Divergence measures based on the Shannon
/// entropy", IEEE Transactions on Information Theory 37(1):145-151
/// (1991) — eq. (1.1) defines the general JS divergence.
/// Binary total-variation distance
/// `TV(Bernoulli(p), Bernoulli(q)) = ½·Σ_i |p_i − q_i| = |p − q|`.
///
/// The TV for 2-class distributions collapses to `|p − q|`
/// algebraically: `½·(|p − q| + |(1−p) − (1−q)|) = |p − q|`.
/// Bounded `0 ≤ TV ≤ 1`. Symmetric, metric.
///
/// Behavior:
/// - p or q outside `[0, 1]` → NaN.
/// - NaN input → NaN.
///
/// Iter-356 — scalar zero-allocation fast path for Bernoulli-vs-
/// Bernoulli TV. Companion to [`binary_kl_divergence`] (iter-344)
/// and [`binary_jensen_shannon_divergence`] (iter-350). Pinsker's
/// inequality `TV² ≤ (1/2)·KL` is sharp in the binary case:
/// useful for binary-channel concentration bounds where the TV
/// quantity is the natural rate function (e.g., LeCam's method
/// in lower-bound proofs).
///
/// `total_variation_from_probs(&[p, 1−p], &[q, 1−q])` produces
/// the same value but allocates two temporary 2-vectors; this
/// is the allocation-free scalar specialization.
///
/// Source.
/// - TV distance definition + scalar 2-class collapse: Lehmann &
///   Romano, "Testing Statistical Hypotheses" (3rd ed., 2005)
///   §13.1.1 eq. (13.1).
/// - Pinsker's inequality: Cover & Thomas, "Elements of
///   Information Theory" (2nd ed., 2006) §11.6 Lemma 11.6.1.
pub fn binary_total_variation_distance(p: f64, q: f64) -> f64 {
    if p.is_nan() || q.is_nan() {
        return f64::NAN;
    }
    if !(0.0..=1.0).contains(&p) || !(0.0..=1.0).contains(&q) {
        return f64::NAN;
    }
    (p - q).abs()
}

/// Binary Hellinger distance
/// `H(Bernoulli(p), Bernoulli(q)) =
///    (1/√2) · √((√p − √q)² + (√(1−p) − √(1−q))²)`.
///
/// Bounded `0 ≤ H ≤ 1`. Symmetric, metric. Self-Hellinger is 0;
/// reaches 1 at `(p, q) ∈ {(0, 1), (1, 0)}`.
///
/// Behavior:
/// - p or q outside `[0, 1]` → NaN.
/// - NaN input → NaN.
///
/// Iter-362 — scalar zero-allocation fast path for Bernoulli-vs-
/// Bernoulli Hellinger. Companion to binary_kl_divergence
/// (iter-344, KL), binary_jensen_shannon_divergence (iter-350,
/// JS), and binary_total_variation_distance (iter-356, TV). The
/// Hellinger is a metric (triangle inequality holds, unlike KL
/// and JS), used in:
/// - Quantum-state-distinguishability bounds.
/// - Le Cam-style two-point lower bounds in nonparametric
///   estimation.
///
/// `hellinger_squared_from_probs(&[p, 1−p], &[q, 1−q])` gives
/// the same Hellinger² value but allocates two temporary
/// 2-vectors per call.
///
/// Source.
/// - Hellinger distance definition: Le Cam, "Asymptotic Methods
///   in Statistical Decision Theory" (1986), §16.
/// - Metric property + bounds: Lehmann & Romano, "Testing
///   Statistical Hypotheses" (3rd ed., 2005) §13.1.2.
/// Binary Jeffreys divergence (symmetrized KL):
/// `J(Bernoulli(p), Bernoulli(q)) = D_KL(p ‖ q) + D_KL(q ‖ p)`
/// (in nats).
///
/// Symmetric, non-negative. Unlike JS divergence (which is
/// bounded by ln(2)), Jeffreys is unbounded: tends to +∞ as
/// either parameter approaches a boundary {0, 1} away from
/// the other.
///
/// Behavior:
/// - p or q outside `[0, 1]` → NaN.
/// - NaN input → NaN.
/// - q ∈ {0, 1} with p ≠ q → +∞ (one of the two KL terms is
///   +∞ via the support-mismatch convention).
///
/// Iter-386 — symmetric scalar divergence companion to
/// binary_kl_divergence (iter-344, asymmetric) and
/// binary_jensen_shannon_divergence (iter-350, bounded
/// symmetric). The three together — KL, JS, Jeffreys — span
/// the asymmetric, bounded-symmetric, and unbounded-symmetric
/// scalar divergence regimes on Bernoulli pairs.
///
/// Source. Jeffreys, H., "An invariant form for the prior
/// probability in estimation problems", Proceedings of the
/// Royal Society A 186:453-461 (1946), eq. (4) — the
/// symmetrized KL as an "invariant" comparison statistic.
pub fn binary_jeffreys_divergence(p: f64, q: f64) -> f64 {
    if p.is_nan() || q.is_nan() {
        return f64::NAN;
    }
    if !(0.0..=1.0).contains(&p) || !(0.0..=1.0).contains(&q) {
        return f64::NAN;
    }
    let a = binary_kl_divergence(p, q);
    let b = binary_kl_divergence(q, p);
    if a.is_infinite() || b.is_infinite() {
        return f64::INFINITY;
    }
    a + b
}

/// Binary Pearson chi-squared divergence
/// `χ²(Bernoulli(p) ‖ Bernoulli(q)) = (p − q)² / (q · (1 − q))`.
///
/// Derived from the general `χ²(P, Q) = Σ_i (p_i − q_i)² / q_i`
/// at n = 2: `(p−q)²/q + (q−p)²/(1−q) = (p−q)² · [1/q + 1/(1−q)]
/// = (p−q)² / [q · (1 − q)]`.
///
/// Behavior:
/// - p or q outside `[0, 1]` → NaN.
/// - NaN input → NaN.
/// - `q ∈ {0, 1}` (degenerate reference distribution): returns
///   `+∞` if `p ≠ q`, `0` if `p == q` (the support-mismatch
///   case for the divergence-as-rate-function interpretation).
///
/// Iter-368 — scalar zero-allocation fast path for Bernoulli-vs-
/// Bernoulli χ². Joins the (KL, JS, TV, Hellinger, χ²) Bernoulli
/// scalar divergence quintet. χ² is the *second-order* moment
/// version of KL — `χ² ≥ 2·KL` near small differences (the
/// Cauchy-Schwarz tightening). Useful in:
/// - Pearson goodness-of-fit at n=2 categories.
/// - Power analysis for binary-classifier shift detection.
///
/// Source. Pearson's chi-squared statistic: Pearson, K., "On
/// the criterion that a given system of deviations…",
/// Philosophical Magazine 50:157–175 (1900); modern
/// divergence-form: Cover & Thomas, "Elements of Information
/// Theory" (2nd ed., 2006) §11.6 eq. (11.49).
/// Exponential-distribution KL divergence (scalar form):
/// `D_KL(Exp(λ_p) ‖ Exp(λ_q)) = ln(λ_p) − ln(λ_q) + λ_q/λ_p − 1`.
///
/// Closed form: see closure_kl_exponential (EML form). This is
/// the eager numeric companion.
///
/// Behavior:
/// - `λ_p ≤ 0` or `λ_q ≤ 0` → NaN.
/// - NaN input → NaN.
/// - Non-negative on all valid inputs (Gibbs inequality).
///
/// Iter-374 — scalar zero-allocation fast path for the exp-
/// distribution KL. Companion to `kl_divergence(ExpFamily,..)`
/// for the Bernoulli/Gaussian/categorical families and to the
/// `binary_*_divergence` scalar quintet (KL/JS/TV/H/χ²); this
/// covers the continuous positive-support case.
///
/// Source. Exponential KL closed form: Cover & Thomas, "Elements
/// of Information Theory" (2nd ed., 2006) §2.3 Example 2.3.
pub fn kl_exponential(lambda_p: f64, lambda_q: f64) -> f64 {
    if lambda_p.is_nan() || lambda_q.is_nan() {
        return f64::NAN;
    }
    if lambda_p <= 0.0 || lambda_q <= 0.0 {
        return f64::NAN;
    }
    lambda_p.ln() - lambda_q.ln() + lambda_q / lambda_p - 1.0
}

/// Poisson-distribution KL divergence (scalar form):
/// `D_KL(Poisson(λ_p) ‖ Poisson(λ_q)) = λ_p · ln(λ_p / λ_q) − λ_p + λ_q`.
///
/// Eager-numeric companion to closure_kl_poisson (iter-379, EML
/// form). Non-negative on valid inputs (Gibbs).
///
/// Behavior:
/// - `λ_p ≤ 0` or `λ_q ≤ 0` → NaN.
/// - NaN input → NaN.
///
/// Iter-380 — discrete-unbounded KL companion to
/// kl_exponential (iter-374, continuous positive-support) on
/// the scalar Info-IR side.
///
/// Source. Poisson KL closed form: Cover & Thomas, "Elements of
/// Information Theory" (2nd ed., 2006) §2.3 Example 2.4.
pub fn kl_poisson(lambda_p: f64, lambda_q: f64) -> f64 {
    if lambda_p.is_nan() || lambda_q.is_nan() {
        return f64::NAN;
    }
    if lambda_p <= 0.0 || lambda_q <= 0.0 {
        return f64::NAN;
    }
    lambda_p * (lambda_p / lambda_q).ln() - lambda_p + lambda_q
}

/// Geometric-distribution KL divergence (scalar form):
/// `D_KL(Geom(p_p) ‖ Geom(p_q)) = ln(p_p / p_q) +
///                                ((1 − p_p) / p_p) · ln((1 − p_p) / (1 − p_q))`.
///
/// Eager-numeric companion to closure_kl_geometric (iter-391).
///
/// Behavior:
/// - `p_p ∉ (0, 1)` or `p_q ∉ (0, 1)` → NaN.
/// - NaN input → NaN.
///
/// Iter-392 — scalar zero-allocation fast path for the
/// Geometric KL. Joins kl_exponential (iter-374, continuous
/// positive-support) and kl_poisson (iter-380, discrete
/// unbounded) on the parametric-distribution scalar KL side.
///
/// Source. Geometric KL via direct E_Geom[k] = (1−p)/p
/// integration; cf. Cover & Thomas, "Elements of Information
/// Theory" (2nd ed., 2006) §2.3.
pub fn kl_geometric(p_p: f64, p_q: f64) -> f64 {
    if p_p.is_nan() || p_q.is_nan() {
        return f64::NAN;
    }
    if !(0.0..1.0).contains(&p_p)
        || !(0.0..1.0).contains(&p_q)
        || p_p == 0.0
        || p_q == 0.0
    {
        return f64::NAN;
    }
    let log_ratio_p = (p_p / p_q).ln();
    let one_minus_p_p = 1.0 - p_p;
    let one_minus_p_q = 1.0 - p_q;
    log_ratio_p + (one_minus_p_p / p_p) * (one_minus_p_p / one_minus_p_q).ln()
}

/// Mutual information from a 2×2 joint probability table:
/// `I(X; Y) = Σ_{x, y} p(x, y) · ln(p(x, y) / (p(x) · p(y)))`.
///
/// Arguments are the four cell probabilities of the joint
/// distribution: `p_00`, `p_01`, `p_10`, `p_11`. They must
/// satisfy `p_xy ≥ 0` and `Σ p = 1` (up to a tolerance).
///
/// Behavior:
/// - Any p_xy < 0 or NaN → NaN.
/// - Σ p_xy not within 1e-9 of 1 → NaN.
/// - Cell with p_xy = 0 contributes 0 (0 · ln(0/·) ≡ 0).
/// - p_xy > 0 with p(x) = 0 or p(y) = 0 is impossible (the
///   marginal contains the joint cell), so no special case
///   needed.
///
/// Always ≥ 0; zero iff X ⊥ Y (independent marginals).
///
/// Iter-410 — scalar zero-allocation fast path for the
/// confusion-matrix mutual-information statistic. Useful in:
/// - Binary-classifier evaluation (MI between predicted /
///   actual class).
/// - Channel-capacity computations for binary symmetric /
///   asymmetric channels.
/// - Feature-selection MI scoring for binary features +
///   binary labels.
///
/// Source. Mutual-information definition: Cover & Thomas,
/// "Elements of Information Theory" (2nd ed., 2006) §2.4
/// eq. (2.28). 2×2 binary-binary specialization is the standard
/// confusion-matrix MI.
pub fn mutual_information_binary_2x2(
    p_00: f64,
    p_01: f64,
    p_10: f64,
    p_11: f64,
) -> f64 {
    let cells = [p_00, p_01, p_10, p_11];
    for &p in &cells {
        if p.is_nan() || p < 0.0 {
            return f64::NAN;
        }
    }
    let total: f64 = cells.iter().sum();
    if (total - 1.0).abs() > 1e-9 {
        return f64::NAN;
    }
    let p_x0 = p_00 + p_01;
    let p_x1 = p_10 + p_11;
    let p_y0 = p_00 + p_10;
    let p_y1 = p_01 + p_11;
    let mut mi = 0.0_f64;
    let pairs = [
        (p_00, p_x0, p_y0),
        (p_01, p_x0, p_y1),
        (p_10, p_x1, p_y0),
        (p_11, p_x1, p_y1),
    ];
    for (pxy, px, py) in pairs {
        if pxy > 0.0 {
            mi += pxy * (pxy / (px * py)).ln();
        }
    }
    mi
}

pub fn binary_chi_squared_divergence(p: f64, q: f64) -> f64 {
    if p.is_nan() || q.is_nan() {
        return f64::NAN;
    }
    if !(0.0..=1.0).contains(&p) || !(0.0..=1.0).contains(&q) {
        return f64::NAN;
    }
    if q == 0.0 || q == 1.0 {
        return if (p - q).abs() < 1e-12 { 0.0 } else { f64::INFINITY };
    }
    let diff = p - q;
    diff * diff / (q * (1.0 - q))
}

pub fn binary_hellinger_distance(p: f64, q: f64) -> f64 {
    if p.is_nan() || q.is_nan() {
        return f64::NAN;
    }
    if !(0.0..=1.0).contains(&p) || !(0.0..=1.0).contains(&q) {
        return f64::NAN;
    }
    let d_pos = p.sqrt() - q.sqrt();
    let d_neg = (1.0 - p).sqrt() - (1.0 - q).sqrt();
    let sq = d_pos * d_pos + d_neg * d_neg;
    (sq / 2.0).sqrt()
}

/// Binary Jensen-Shannon distance: `sqrt(JS(p, q))`.
///
/// True metric (triangle inequality holds, unlike the JS
/// divergence itself which is only a "semi-metric"). Bounded
/// in `[0, sqrt(ln(2))]`.
///
/// Behavior:
/// - p or q outside `[0, 1]` → NaN.
/// - NaN input → NaN.
///
/// Iter-404 — metric-form companion to
/// `binary_jensen_shannon_divergence` (iter-350). Useful when
/// the triangle inequality is required (e.g., k-medoids
/// clustering on Bernoulli parameters, embedding-space
/// distance proofs).
///
/// Source. JS-distance metric property: Endres & Schindelin,
/// "A new metric for probability distributions", IEEE
/// Transactions on Information Theory 49(7):1858-1860 (2003);
/// Bernoulli specialization is the scalar 2-class case.
pub fn binary_jensen_shannon_distance(p: f64, q: f64) -> f64 {
    let js = binary_jensen_shannon_divergence(p, q);
    if js.is_nan() {
        return f64::NAN;
    }
    js.sqrt()
}

pub fn binary_jensen_shannon_divergence(p: f64, q: f64) -> f64 {
    if p.is_nan() || q.is_nan() {
        return f64::NAN;
    }
    if !(0.0..=1.0).contains(&p) || !(0.0..=1.0).contains(&q) {
        return f64::NAN;
    }
    let m = 0.5 * (p + q);
    if m == 0.0 {
        // Both p and q are 0; the divergence on degenerate
        // distributions is 0 by the 0·ln(0/0) ≡ 0 convention.
        return 0.0;
    }
    let kl_pm = binary_kl_divergence(p, m);
    let kl_qm = binary_kl_divergence(q, m);
    0.5 * (kl_pm + kl_qm)
}

pub fn binary_kl_divergence(p: f64, q: f64) -> f64 {
    if p.is_nan() || q.is_nan() {
        return f64::NAN;
    }
    if !(0.0..=1.0).contains(&p) || !(0.0..=1.0).contains(&q) {
        return f64::NAN;
    }
    let lhs = if p == 0.0 {
        0.0
    } else if q == 0.0 {
        return f64::INFINITY;
    } else {
        p * (p / q).ln()
    };
    let one_minus_p = 1.0 - p;
    let one_minus_q = 1.0 - q;
    let rhs = if one_minus_p == 0.0 {
        0.0
    } else if one_minus_q == 0.0 {
        return f64::INFINITY;
    } else {
        one_minus_p * (one_minus_p / one_minus_q).ln()
    };
    lhs + rhs
}

/// Index of the modal (max-probability) outcome:
/// `mode_index(p) = arg max_i pᵢ`.
///
/// Returns `None` on empty input or NaN entries. Ties are broken
/// by lowest index (first occurrence of the max).
///
/// Iter-260 — argmax companion to `mode_probability` (iter-224).
/// The "predicted class" of a posterior under the Bayes-optimal
/// classifier (maximum a posteriori).
pub fn mode_index(probs: &[f64]) -> Option<usize> {
    if probs.is_empty() {
        return None;
    }
    let mut best_idx = 0_usize;
    let mut best_val = f64::NEG_INFINITY;
    for (i, &p) in probs.iter().enumerate() {
        if p.is_nan() {
            return None;
        }
        if p > best_val {
            best_val = p;
            best_idx = i;
        }
    }
    Some(best_idx)
}

/// Bayes error rate `1 − max_i pᵢ` — error of the optimal
/// arg-max classifier given the posterior `p`.
///
/// Equals `1 − mode_probability(p)`. Bounded in `[0, 1 − 1/n]`
/// where `n = probs.len()`. NaN on empty input.
///
/// Iter-302 — companion to `mode_probability` (iter-224); the
/// complementary "miss rate" measure. Used as the Bayes-optimal
/// floor in PAC-style classification analysis.
pub fn bayes_error_rate(probs: &[f64]) -> f64 {
    if probs.is_empty() {
        return f64::NAN;
    }
    1.0 - mode_probability(probs)
}

/// Mode probability `M(p) = max_i pᵢ` — the Bayes-optimal
/// accuracy of a classifier that predicts the highest-mass class.
///
/// The complement `1 − M(p)` is the Bayes error rate. For a
/// uniform distribution on `n` classes, `M = 1/n` and the Bayes
/// error is `1 − 1/n`. For a deterministic distribution `M = 1`
/// and the error is 0.
///
/// Returns NaN on empty input.
///
/// Iter-224 — companion to `gini_impurity` (iter-200) and
/// `perplexity` (iter-206); the three together completely
/// determine the impurity / accuracy trade-off in tree-based
/// classification.
pub fn mode_probability(probs: &[f64]) -> f64 {
    if probs.is_empty() {
        return f64::NAN;
    }
    let mut best = f64::NEG_INFINITY;
    for &p in probs {
        if p > best {
            best = p;
        }
    }
    best
}

/// Jensen-Shannon distance `√JS(p, q)` — the proper metric
/// induced by JS divergence.
///
/// Endres, Schindelin (2003) proved that `√JS` satisfies the
/// triangle inequality and is bounded by `√(ln 2)`. Symmetric and
/// non-negative.
///
/// Returns NaN on length mismatch or empty input.
///
/// Iter-266 — metric companion to `js_from_probs` (iter-182).
/// Pairs with `total_variation_from_probs` (iter-218) and
/// `hellinger_distance` to give three proper metrics on the
/// probability simplex.
pub fn js_distance(p: &[f64], q: &[f64]) -> f64 {
    let js = js_from_probs(p, q);
    if js.is_nan() {
        return f64::NAN;
    }
    js.sqrt()
}

/// Pearson χ² divergence from explicit probability vectors:
///
///   χ²(P || Q) = Σᵢ (pᵢ − qᵢ)² / qᵢ.
///
/// `0 / 0 = 0` convention (skip term when `qᵢ = 0` and `pᵢ = 0`);
/// `INFINITY` when `qᵢ = 0` and `pᵢ > 0`.
///
/// Returns NaN on length mismatch or empty input.
///
/// Iter-272 — explicit-prob χ² mirror of `chi_squared_divergence`
/// (which uses the exp-family θ-coordinate). Useful when callers
/// hold probability vectors directly.
pub fn chi_squared_from_probs(p: &[f64], q: &[f64]) -> f64 {
    if p.len() != q.len() || p.is_empty() {
        return f64::NAN;
    }
    let mut acc = 0.0_f64;
    for (pi, qi) in p.iter().zip(q.iter()) {
        if *qi <= 0.0 {
            if *pi > 0.0 {
                return f64::INFINITY;
            }
            continue;
        }
        let diff = pi - qi;
        acc += (diff * diff) / qi;
    }
    acc
}

/// Right-hand side of Fano's inequality:
///
///   H(X | Y) ≤ H_b(p_e) + p_e · ln(n − 1),
///
/// where `H_b(p_e) = −p_e·ln(p_e) − (1−p_e)·ln(1−p_e)` is the
/// binary entropy of the error rate, and `n ≥ 2` is the
/// alphabet size.
///
/// Returns the RHS bound (an upper bound on the conditional
/// entropy). For `n = 2` the second term vanishes and the bound
/// reduces to the binary entropy of `p_e`.
///
/// Returns NaN for `n < 2` or `p_e ∉ [0, 1]`.
///
/// Iter-308 — Fano-bound primitive; pairs with
/// `pinsker_kl_lower_bound` (iter-278) as the two complementary
/// sample-complexity bounds in hypothesis testing.
pub fn fano_inequality_rhs(error_rate: f64, n_classes: usize) -> f64 {
    if n_classes < 2 || !(0.0..=1.0).contains(&error_rate) {
        return f64::NAN;
    }
    let h_binary = if error_rate == 0.0 || error_rate == 1.0 {
        0.0
    } else {
        -error_rate * error_rate.ln() - (1.0 - error_rate) * (1.0 - error_rate).ln()
    };
    let log_term = if n_classes == 2 {
        0.0
    } else {
        ((n_classes - 1) as f64).ln()
    };
    h_binary + error_rate * log_term
}

/// Pinsker's lower bound on KL divergence given total-variation
/// distance: `KL(p || q) ≥ 2 · TV(p, q)²`.
///
/// Returns `2 · tv²` directly. Used as a cheap lower bound on
/// KL when only TV is at hand (or as a stopping criterion: if
/// `2·TV² > target_KL`, KL is already at least that large).
///
/// Tight when `p, q` are Bernoulli at the same mass; loose in
/// general. The reverse Pinsker (KL ≤ 2(ln 2 / TV_max)·TV) needs
/// additional constants and is not provided here.
///
/// Iter-278 — diagnostic primitive bridging the two distance
/// scales (TV bounded in [0, 1]; KL unbounded). Pairs with
/// `total_variation_from_probs` and `kl_from_probs`.
pub fn pinsker_kl_lower_bound(tv: f64) -> f64 {
    2.0 * tv * tv
}

/// Total-variation distance from explicit probability vectors:
///
///   TV(P, Q) = ½ · Σᵢ |pᵢ − qᵢ|.
///
/// Bounded in `[0, 1]`. Equivalent dual form:
/// `TV = max_{S ⊆ X} |P(S) − Q(S)|`. Symmetric proper metric on
/// the probability simplex.
///
/// Returns NaN on length mismatch or empty input.
///
/// Iter-218 — explicit-prob TV companion to
/// `total_variation_distance` (which uses the exp-family
/// θ-coordinate signature). Useful when callers already hold
/// probability vectors and don't want to round-trip through the
/// natural-parameter space.
pub fn total_variation_from_probs(p: &[f64], q: &[f64]) -> f64 {
    if p.len() != q.len() || p.is_empty() {
        return f64::NAN;
    }
    let mut acc = 0.0_f64;
    for (pi, qi) in p.iter().zip(q.iter()) {
        acc += (pi - qi).abs();
    }
    0.5 * acc
}

/// Effective sample size `ESS(w) = 1 / Σᵢ wᵢ²` for normalized
/// importance-sampling weights.
///
/// Interpretation: if `w` is approximately uniform on `n`
/// samples, ESS ≈ n; if `w` is deterministic (one wᵢ = 1, others
/// zero), ESS = 1. Common particle-filter resampling trigger.
///
/// Note the formal identity `ESS = 1 / (1 − G(w))` where `G` is
/// the Gini-impurity of the weight distribution — so ESS = `n`
/// iff all weights uniform, ESS = `1` iff one weight carries
/// everything.
///
/// Empty input → NaN.
///
/// Iter-212 — companion to `gini_impurity` (iter-200) and
/// `perplexity` (iter-206); a third "effective-support-size"
/// measure tuned to importance-sampling weight diagnostics.
pub fn effective_sample_size_from_weights(weights: &[f64]) -> f64 {
    if weights.is_empty() {
        return f64::NAN;
    }
    let sum_sq: f64 = weights.iter().map(|w| w * w).sum();
    1.0 / sum_sq
}

/// Perplexity `PP(p) = exp(H(p))` of a discrete distribution.
///
/// Reads as the "effective vocabulary size" of `p`: a uniform
/// distribution over `n` classes has perplexity exactly `n`; a
/// deterministic distribution has perplexity `1`. The standard
/// language-model evaluation metric.
///
/// Uses `categorical_entropy_from_probs` internally; same NaN /
/// empty-input contract.
///
/// Iter-206 — companion to `categorical_entropy_from_probs`
/// (iter-157); equivalent to `2^{H_2(p)}` when the base-2 entropy
/// is used in the language-modeling literature, but here we stay
/// in the natural-log convention to match every other Info-IR
/// primitive.
pub fn perplexity(probs: &[f64]) -> f64 {
    let h = categorical_entropy_from_probs(probs);
    h.exp()
}

/// Gini impurity `G(p) = 1 − Σᵢ pᵢ²` of a discrete distribution.
///
/// Standard CART decision-tree splitting criterion. Equivalent
/// expressions:
///
///   G(p) = 1 − Σᵢ pᵢ² = Σᵢ pᵢ · (1 − pᵢ)
///        = 2 · Σᵢ<j pᵢ · pⱼ.
///
/// Bounds: `0 ≤ G(p) ≤ 1 − 1/n`. Zero for a deterministic
/// distribution; maximal for uniform on `n` classes (= 1 − 1/n).
///
/// Returns NaN on empty input.
///
/// Iter-200 — companion to `categorical_entropy_from_probs`
/// (iter-157); both measure "disorder" but with different
/// concavity profiles (Gini is the binomial concavity, entropy
/// is the Shannon concavity).
pub fn gini_impurity(probs: &[f64]) -> f64 {
    if probs.is_empty() {
        return f64::NAN;
    }
    let sum_sq: f64 = probs.iter().map(|p| p * p).sum();
    1.0 - sum_sq
}

/// α-Rényi divergence from explicit probability vectors:
///
///   D_α(P || Q) = (1 / (α − 1)) · ln(Σ_i p_i^α · q_i^{1-α})
///
/// for `α > 0, α ≠ 1`. KL is recovered as α → 1 (the limit is
/// excluded here — callers should use `kl_from_probs` directly).
///
/// The α → 1/2 case (×2) is the Bhattacharyya-like divergence;
/// α = 2 is the collision divergence; α → ∞ is the worst-case
/// log-likelihood-ratio.
///
/// Returns NaN on length mismatch, empty input, or `α == 1`.
/// Returns `INFINITY` when `q_i = 0` and `p_i > 0` for any `i`
/// with `α < 1` (using the convention that the corresponding
/// term blows up).
///
/// Iter-194 — generalized-divergence primitive; bridges
/// `kl_from_probs` (α → 1), `bhattacharyya_*` (α = 1/2), and
/// `chi_squared_divergence` (α = 2).
pub fn renyi_divergence_from_probs(p: &[f64], q: &[f64], alpha: f64) -> f64 {
    if p.len() != q.len() || p.is_empty() {
        return f64::NAN;
    }
    if alpha == 1.0 {
        return f64::NAN;
    }
    let mut acc = 0.0_f64;
    for (pi, qi) in p.iter().zip(q.iter()) {
        if *pi <= 0.0 {
            continue;
        }
        if *qi <= 0.0 {
            return f64::INFINITY;
        }
        acc += pi.powf(alpha) * qi.powf(1.0 - alpha);
    }
    if acc <= 0.0 {
        return f64::INFINITY;
    }
    acc.ln() / (alpha - 1.0)
}

/// Squared Hellinger distance from explicit probability vectors:
///
///   H²(p, q) = 1 − BC(p, q) = ½ · Σᵢ (√pᵢ − √qᵢ)².
///
/// Bounded in `[0, 1]`. The unsquared `H = √(H²)` is the proper
/// metric (Hellinger distance).
///
/// Returns NaN on length mismatch or empty input.
///
/// Iter-314 — explicit-prob squared Hellinger, the identity
/// 1 − BC. Pairs with `bhattacharyya_coefficient` (iter-188) and
/// the existing exp-family `hellinger_distance`.
pub fn hellinger_squared_from_probs(p: &[f64], q: &[f64]) -> f64 {
    let bc = bhattacharyya_coefficient(p, q);
    if bc.is_nan() {
        return f64::NAN;
    }
    1.0 - bc
}

/// Bhattacharyya coefficient `BC(p, q) = Σ_i √(p_i · q_i)`.
///
/// Bounded in [0, 1] for discrete probability vectors; 1 when
/// `p == q`, 0 when supports are disjoint. Symmetric.
///
/// Returns NaN on length mismatch or empty input.
///
/// Iter-188 — affinity/similarity primitive, companion to
/// `hellinger_distance` (BD-related) and `js_from_probs`.
pub fn bhattacharyya_coefficient(p: &[f64], q: &[f64]) -> f64 {
    if p.len() != q.len() || p.is_empty() {
        return f64::NAN;
    }
    let mut acc = 0.0_f64;
    for (pi, qi) in p.iter().zip(q.iter()) {
        if *pi > 0.0 && *qi > 0.0 {
            acc += (pi * qi).sqrt();
        }
    }
    acc
}

/// Bhattacharyya distance `BD(p, q) = -ln(BC(p, q))`.
///
/// Non-negative; zero when `p == q`; ∞ when supports are
/// disjoint (BC = 0). Symmetric but not a true metric
/// (Hellinger is the proper metric companion).
///
/// Returns NaN on length mismatch or empty input.
///
/// Iter-188 — companion to `bhattacharyya_coefficient`.
pub fn bhattacharyya_distance(p: &[f64], q: &[f64]) -> f64 {
    let bc = bhattacharyya_coefficient(p, q);
    if bc.is_nan() {
        return f64::NAN;
    }
    if bc <= 0.0 {
        return f64::INFINITY;
    }
    -bc.ln()
}

/// KL divergence from two explicit probability vectors:
///
/// `KL(P || Q) = Σ_i p_i · log(p_i / q_i)`
///
/// with `0 · log 0 = 0` convention. Returns `f64::INFINITY` if
/// any `q_i = 0` where `p_i > 0` (unbounded mismatch).
///
/// Caller must supply equal-length probability vectors;
/// returns `f64::NAN` on length mismatch.
///
/// Iter-170 — companion to `kl_divergence` (exp-family form) and
/// `categorical_entropy_from_probs` (iter-157).
pub fn kl_from_probs(p: &[f64], q: &[f64]) -> f64 {
    if p.len() != q.len() || p.is_empty() {
        return f64::NAN;
    }
    let mut kl = 0.0_f64;
    for (pi, qi) in p.iter().zip(q.iter()) {
        if *pi > 0.0 {
            if *qi <= 0.0 {
                return f64::INFINITY;
            }
            kl += pi * (pi / qi).ln();
        }
    }
    kl
}

/// True iff `probs` is a valid probability vector: all entries
/// non-negative and sum to within `tolerance` of 1.0.
///
/// Iter-163 — input-validation helper for entropy / KL / MI functions.
pub fn is_valid_probability_vector(probs: &[f64], tolerance: f64) -> bool {
    if probs.is_empty() {
        return false;
    }
    let mut sum = 0.0_f64;
    for &p in probs {
        if p < 0.0 || !p.is_finite() {
            return false;
        }
        sum += p;
    }
    (sum - 1.0).abs() <= tolerance
}

/// True iff `joint` is a valid joint distribution: non-negative
/// entries, sum to within `tolerance` of 1.0, all rows same length.
///
/// Iter-163 — input-validation helper for mutual_information.
pub fn is_valid_joint_distribution(joint: &[Vec<f64>], tolerance: f64) -> bool {
    if joint.is_empty() {
        return false;
    }
    let n_y = joint[0].len();
    if n_y == 0 {
        return false;
    }
    let mut sum = 0.0_f64;
    for row in joint {
        if row.len() != n_y {
            return false;
        }
        for &p in row {
            if p < 0.0 || !p.is_finite() {
                return false;
            }
            sum += p;
        }
    }
    (sum - 1.0).abs() <= tolerance
}

/// Direct discrete entropy from an explicit probability vector:
///
/// `H(P) = -Σ_i p_i · log p_i` (with `0 · log 0 = 0` convention).
///
/// Caller supplies the probability vector (must sum to ≈ 1; the
/// function doesn't enforce normalization).
///
/// Iter-157 — direct entropy companion to mutual_information (iter-152),
/// useful when probabilities are already known explicitly (not via
/// natural-param coords).
pub fn categorical_entropy_from_probs(probs: &[f64]) -> f64 {
    probs
        .iter()
        .map(|&p| if p > 0.0 { -p * p.ln() } else { 0.0 })
        .sum()
}

/// Joint entropy from explicit joint table:
///
/// `H(X, Y) = -Σ_{i,j} P(x, y) · log P(x, y)`
///
/// with `0 · log 0 = 0` convention. Returns NaN on empty / invalid.
///
/// Iter-177 — companion to mutual_information (iter-152) and
/// categorical_entropy_from_probs (iter-157).
pub fn joint_entropy(joint: &[Vec<f64>]) -> f64 {
    if joint.is_empty() {
        return f64::NAN;
    }
    let n_y = joint[0].len();
    if n_y == 0 {
        return f64::NAN;
    }
    let mut h = 0.0_f64;
    for row in joint {
        if row.len() != n_y {
            return f64::NAN;
        }
        for &p in row {
            if p > 0.0 {
                h -= p * p.ln();
            } else if p < 0.0 {
                return f64::NAN;
            }
        }
    }
    h
}

/// Conditional entropy `H(X | Y) = H(X, Y) − H(Y)`.
///
/// The Y-marginal is computed from the joint table.
///
/// Iter-177 — companion to joint_entropy.
pub fn conditional_entropy(joint: &[Vec<f64>]) -> f64 {
    if joint.is_empty() {
        return f64::NAN;
    }
    let n_y = joint[0].len();
    if n_y == 0 {
        return f64::NAN;
    }
    // Marginal of Y.
    let mut py = vec![0.0_f64; n_y];
    for row in joint {
        if row.len() != n_y {
            return f64::NAN;
        }
        for (j, &p) in row.iter().enumerate() {
            if p < 0.0 {
                return f64::NAN;
            }
            py[j] += p;
        }
    }
    joint_entropy(joint) - categorical_entropy_from_probs(&py)
}

/// Mutual information between two discrete random variables from
/// an explicit joint probability table:
///
/// `I(X; Y) = Σ_{x,y} P(x, y) · log(P(x, y) / (p(x) · p(y)))`
///
/// where `joint[i][j] = P(X = i, Y = j)`. The function computes
/// the marginals `p(x_i) = Σ_j joint[i][j]` and
/// `p(y_j) = Σ_i joint[i][j]` from the table.
///
/// Returns `f64::NAN` if any joint probability is negative or
/// the table is empty.
///
/// Iter-152 — exact discrete mutual information; doesn't depend
/// on any ExpFamily, lives in info_ir alongside KL/entropy.
pub fn mutual_information(joint: &[Vec<f64>]) -> f64 {
    if joint.is_empty() {
        return f64::NAN;
    }
    let n_y = joint[0].len();
    if n_y == 0 {
        return f64::NAN;
    }

    // Compute marginals.
    let mut px = vec![0.0_f64; joint.len()];
    let mut py = vec![0.0_f64; n_y];
    for (i, row) in joint.iter().enumerate() {
        if row.len() != n_y {
            return f64::NAN;
        }
        for (j, &p) in row.iter().enumerate() {
            if p < 0.0 {
                return f64::NAN;
            }
            px[i] += p;
            py[j] += p;
        }
    }

    let mut mi = 0.0_f64;
    for (i, row) in joint.iter().enumerate() {
        for (j, &p) in row.iter().enumerate() {
            if p > 0.0 && px[i] > 0.0 && py[j] > 0.0 {
                mi += p * (p / (px[i] * py[j])).ln();
            }
        }
    }
    mi
}

/// Full KL divergence between two univariate Gaussians with
/// possibly different means AND variances:
///
/// `KL(N(μ_1, σ_1²) || N(μ_2, σ_2²)) =
///   0.5 · (log(σ_2²/σ_1²) + (σ_1² + (μ_1 − μ_2)²) / σ_2² − 1)`
///
/// Useful when the same-variance reduction in
/// [`kl_divergence`] doesn't apply (different distributions
/// with different scales).
///
/// Iter-148 — companion to kl_divergence for the general Gaussian
/// case.
pub fn gaussian_kl_full(mu_p: f64, sig2_p: f64, mu_q: f64, sig2_q: f64) -> f64 {
    0.5 * ((sig2_q / sig2_p).ln() + (sig2_p + (mu_p - mu_q).powi(2)) / sig2_q - 1.0)
}

/// Same-variance Gaussian KL (scalar fast path):
/// `KL(N(μ_p, σ²) || N(μ_q, σ²)) = (μ_p − μ_q)² / (2σ²)`.
///
/// Algebraic specialization of [`gaussian_kl_full`] at
/// `sig2_p == sig2_q == sigma2`: the log-ratio cancels and the
/// `(σ² − σ²) / σ²` term collapses, leaving just the quadratic
/// mean-shift penalty.
///
/// Behavior:
/// - `sigma2 ≤ 0` or NaN → NaN.
///
/// Iter-398 — fast-path companion to `gaussian_kl_full`
/// (iter-148). Frequently used in mirror-descent / natural-
/// gradient pipelines where the variance is held fixed across
/// the variational update — common in Gaussian variational
/// inference under isotropic posteriors.
///
/// Source. Same-variance Gaussian KL: direct simplification of
/// gaussian_kl_full; cf. Cover & Thomas (2nd ed., 2006) §8.5
/// eq. (8.45).
pub fn gaussian_kl_same_variance(mu_p: f64, mu_q: f64, sigma2: f64) -> f64 {
    if sigma2.is_nan() || sigma2 <= 0.0 {
        return f64::NAN;
    }
    let d = mu_p - mu_q;
    d * d / (2.0 * sigma2)
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

    // ── iter-182: js_from_probs ───────────────────────────────────

    #[test]
    fn js_from_probs_self_is_zero() {
        let p = vec![0.5, 0.5];
        assert!(js_from_probs(&p, &p).abs() < 1e-12);
    }

    #[test]
    fn js_from_probs_symmetric() {
        let p = vec![0.7, 0.3];
        let q = vec![0.2, 0.8];
        let pq = js_from_probs(&p, &q);
        let qp = js_from_probs(&q, &p);
        assert!((pq - qp).abs() < 1e-12);
    }

    #[test]
    fn js_from_probs_bounded_by_ln_2() {
        // Maximum JS for two-state distributions ≤ ln 2.
        let extremes = vec![1.0, 0.0];
        let opposite = vec![0.0, 1.0];
        let js = js_from_probs(&extremes, &opposite);
        assert!(js <= 2.0_f64.ln() + 1e-9);
        assert!((js - 2.0_f64.ln()).abs() < 1e-9);
    }

    #[test]
    fn js_from_probs_dim_mismatch_returns_nan() {
        let js = js_from_probs(&[0.5, 0.5], &[1.0]);
        assert!(js.is_nan());
    }

    // ── iter-254: normalized_entropy ──────────────────────────────

    #[test]
    fn normalized_entropy_uniform_is_one() {
        for n in 2..=8_usize {
            let p = vec![1.0 / n as f64; n];
            assert!((normalized_entropy(&p) - 1.0).abs() < 1e-9);
        }
    }

    #[test]
    fn normalized_entropy_deterministic_is_zero() {
        let p = vec![1.0_f64, 0.0, 0.0];
        assert!(normalized_entropy(&p).abs() < 1e-12);
    }

    #[test]
    fn normalized_entropy_bounded_in_unit_interval() {
        let cases = vec![
            vec![0.7_f64, 0.2, 0.1],
            vec![0.4_f64, 0.3, 0.2, 0.1],
            vec![0.5_f64, 0.5, 0.0, 0.0, 0.0],
        ];
        for p in &cases {
            let h_norm = normalized_entropy(p);
            assert!(h_norm >= 0.0 && h_norm <= 1.0 + 1e-9, "out of range: {} for {:?}", h_norm, p);
        }
    }

    #[test]
    fn normalized_entropy_single_class_is_nan() {
        let p = vec![1.0_f64];
        assert!(normalized_entropy(&p).is_nan());
    }

    // ── iter-248: cross_entropy_from_probs ────────────────────────

    #[test]
    fn cross_entropy_from_probs_self_equals_entropy() {
        let p = vec![0.2_f64, 0.3, 0.5];
        let ce = cross_entropy_from_probs(&p, &p);
        let h = categorical_entropy_from_probs(&p);
        assert!((ce - h).abs() < 1e-12);
    }

    #[test]
    fn cross_entropy_from_probs_one_hot_target_matches_neg_log_q() {
        // p = (1, 0, 0); q = (0.7, 0.2, 0.1) → H(P, Q) = -ln 0.7.
        let p = vec![1.0_f64, 0.0, 0.0];
        let q = vec![0.7_f64, 0.2, 0.1];
        let ce = cross_entropy_from_probs(&p, &q);
        assert!((ce - (-0.7_f64.ln())).abs() < 1e-9);
    }

    #[test]
    fn cross_entropy_from_probs_zero_q_with_positive_p_is_infinite() {
        let p = vec![0.5_f64, 0.5];
        let q = vec![1.0_f64, 0.0];
        assert!(cross_entropy_from_probs(&p, &q).is_infinite());
    }

    #[test]
    fn cross_entropy_from_probs_kl_relationship() {
        // KL(p || q) = CE(p, q) - H(p).
        let p = vec![0.2_f64, 0.3, 0.5];
        let q = vec![0.4_f64, 0.4, 0.2];
        let ce = cross_entropy_from_probs(&p, &q);
        let h = categorical_entropy_from_probs(&p);
        let kl = kl_from_probs(&p, &q);
        assert!((kl - (ce - h)).abs() < 1e-9);
    }

    #[test]
    fn cross_entropy_from_probs_dim_mismatch_is_nan() {
        assert!(cross_entropy_from_probs(&[0.5, 0.5], &[1.0]).is_nan());
    }

    // ── iter-296: entropy_ratio ───────────────────────────────────

    #[test]
    fn entropy_ratio_self_is_one() {
        let p = vec![0.2_f64, 0.3, 0.5];
        assert!((entropy_ratio(&p, &p) - 1.0).abs() < 1e-9);
    }

    #[test]
    fn entropy_ratio_uniform_over_uniform_n_is_one() {
        let p = vec![0.5_f64, 0.5];
        let q = vec![0.5_f64, 0.5];
        assert!((entropy_ratio(&p, &q) - 1.0).abs() < 1e-9);
    }

    #[test]
    fn entropy_ratio_deterministic_q_is_nan() {
        let p = vec![0.5_f64, 0.5];
        let q = vec![1.0_f64, 0.0];
        assert!(entropy_ratio(&p, &q).is_nan());
    }

    #[test]
    fn entropy_ratio_empty_is_nan() {
        assert!(entropy_ratio(&[], &[0.5, 0.5]).is_nan());
        assert!(entropy_ratio(&[0.5, 0.5], &[]).is_nan());
    }

    // ── iter-290: entropy_diff ────────────────────────────────────

    #[test]
    fn entropy_diff_self_is_zero() {
        let p = vec![0.2_f64, 0.3, 0.5];
        assert!(entropy_diff(&p, &p).abs() < 1e-12);
    }

    #[test]
    fn entropy_diff_uniform_minus_deterministic_is_ln_n() {
        let unif = vec![0.5_f64, 0.5];
        let det = vec![1.0_f64, 0.0];
        let d = entropy_diff(&unif, &det);
        assert!((d - 2.0_f64.ln()).abs() < 1e-9);
    }

    #[test]
    fn entropy_diff_antisymmetric() {
        let p = vec![0.7_f64, 0.2, 0.1];
        let q = vec![0.4_f64, 0.4, 0.2];
        let pq = entropy_diff(&p, &q);
        let qp = entropy_diff(&q, &p);
        assert!((pq + qp).abs() < 1e-12);
    }

    #[test]
    fn entropy_diff_empty_is_nan() {
        assert!(entropy_diff(&[], &[0.5, 0.5]).is_nan());
        assert!(entropy_diff(&[0.5, 0.5], &[]).is_nan());
    }

    // ── iter-284: kl_to_uniform ───────────────────────────────────

    #[test]
    fn kl_to_uniform_uniform_is_zero() {
        for n in 2..=8_usize {
            let p = vec![1.0 / n as f64; n];
            assert!(kl_to_uniform(&p).abs() < 1e-9);
        }
    }

    #[test]
    fn kl_to_uniform_deterministic_is_ln_n() {
        for n in 2..=8_usize {
            let mut p = vec![0.0; n];
            p[0] = 1.0;
            let kl = kl_to_uniform(&p);
            assert!((kl - (n as f64).ln()).abs() < 1e-9);
        }
    }

    #[test]
    fn kl_to_uniform_bounded_in_log_n() {
        let p = vec![0.7_f64, 0.2, 0.1];
        let kl = kl_to_uniform(&p);
        assert!(kl >= 0.0 && kl <= 3.0_f64.ln() + 1e-9);
    }

    #[test]
    fn kl_to_uniform_empty_is_nan() {
        assert!(kl_to_uniform(&[]).is_nan());
    }

    // ── iter-242: uniform_entropy ─────────────────────────────────

    #[test]
    fn uniform_entropy_zero_is_neg_infinity() {
        let h = uniform_entropy(0);
        assert!(h.is_infinite() && h < 0.0);
    }

    #[test]
    fn uniform_entropy_one_is_zero() {
        assert_eq!(uniform_entropy(1), 0.0);
    }

    #[test]
    fn uniform_entropy_matches_explicit_uniform() {
        // H(uniform_n) = ln n; matches categorical_entropy_from_probs(uniform).
        for n in 2..=8_usize {
            let p = vec![1.0 / n as f64; n];
            let h_explicit = categorical_entropy_from_probs(&p);
            let h_baseline = uniform_entropy(n);
            assert!((h_explicit - h_baseline).abs() < 1e-9);
        }
    }

    #[test]
    fn uniform_entropy_is_max_for_n_classes() {
        // Gibbs' inequality: H(p) ≤ ln n for any p on n classes.
        let n = 4;
        let max_h = uniform_entropy(n);
        // Test a few non-uniform distributions.
        let cases = vec![
            vec![0.7_f64, 0.1, 0.1, 0.1],
            vec![0.4_f64, 0.3, 0.2, 0.1],
            vec![0.5_f64, 0.5, 0.0, 0.0],
        ];
        for p in &cases {
            let h = categorical_entropy_from_probs(p);
            assert!(h <= max_h + 1e-9, "H({:?}) = {} > {}", p, h, max_h);
        }
    }

    // ── iter-236: collision_entropy ───────────────────────────────

    #[test]
    fn collision_entropy_uniform_n_is_ln_n() {
        for n in 2..=8_usize {
            let p = vec![1.0 / n as f64; n];
            let h2 = collision_entropy(&p);
            assert!((h2 - (n as f64).ln()).abs() < 1e-9);
        }
    }

    #[test]
    fn collision_entropy_deterministic_is_zero() {
        let p = vec![1.0_f64, 0.0, 0.0];
        assert!(collision_entropy(&p).abs() < 1e-12);
    }

    #[test]
    fn collision_entropy_matches_neg_log_one_minus_gini() {
        // H_2 = -ln(Σ p²) = -ln(1 - G).
        let p = vec![0.7_f64, 0.2, 0.1];
        let h2 = collision_entropy(&p);
        let g = gini_impurity(&p);
        let from_gini = -(1.0 - g).ln();
        assert!((h2 - from_gini).abs() < 1e-12);
    }

    #[test]
    fn collision_entropy_between_min_and_shannon() {
        // H_∞ ≤ H_2 ≤ H (Rényi monotone in 1/α).
        let p = vec![0.7_f64, 0.2, 0.1];
        let h_inf = min_entropy(&p);
        let h2 = collision_entropy(&p);
        let h_shannon = categorical_entropy_from_probs(&p);
        assert!(h_inf <= h2 + 1e-12, "H_∞={} H_2={}", h_inf, h2);
        assert!(h2 <= h_shannon + 1e-12, "H_2={} H={}", h2, h_shannon);
    }

    #[test]
    fn collision_entropy_empty_is_nan() {
        assert!(collision_entropy(&[]).is_nan());
    }

    // ── iter-230: min_entropy ─────────────────────────────────────

    #[test]
    fn min_entropy_uniform_n_is_ln_n() {
        for n in 2..=8_usize {
            let p = vec![1.0 / n as f64; n];
            let h = min_entropy(&p);
            assert!((h - (n as f64).ln()).abs() < 1e-9, "n={}: h={}", n, h);
        }
    }

    #[test]
    fn min_entropy_deterministic_is_zero() {
        let p = vec![1.0_f64, 0.0, 0.0];
        assert!(min_entropy(&p).abs() < 1e-12);
    }

    #[test]
    fn min_entropy_at_most_shannon() {
        // H_∞ ≤ H (Shannon ≥ min-entropy).
        let p = vec![0.7_f64, 0.2, 0.1];
        let h_inf = min_entropy(&p);
        let h_shannon = categorical_entropy_from_probs(&p);
        assert!(h_inf <= h_shannon + 1e-12, "H_∞={} H={}", h_inf, h_shannon);
    }

    #[test]
    fn min_entropy_empty_is_nan() {
        assert!(min_entropy(&[]).is_nan());
    }

    // ── iter-320: renyi_entropy_from_probs ────────────────────────

    #[test]
    fn renyi_entropy_uniform_n_is_ln_n_for_any_alpha() {
        // For uniform p over n: H_α(uniform_n) = ln(n) for every
        // α > 0, α ≠ 1.
        let n = 5_usize;
        let p = vec![1.0 / n as f64; n];
        let ln_n = (n as f64).ln();
        for alpha in [0.5_f64, 2.0, 3.0, 10.0] {
            let h = renyi_entropy_from_probs(&p, alpha);
            assert!((h - ln_n).abs() < 1e-9, "alpha={}: H={}", alpha, h);
        }
    }

    #[test]
    fn renyi_entropy_alpha_2_matches_collision_entropy() {
        // H_2 ≡ collision entropy by definition.
        let p = vec![0.5_f64, 0.3, 0.2];
        let r = renyi_entropy_from_probs(&p, 2.0);
        let c = collision_entropy(&p);
        assert!((r - c).abs() < 1e-12);
    }

    #[test]
    fn renyi_entropy_monotone_non_increasing_in_alpha() {
        // α₁ ≤ α₂ ⇒ H_{α₁} ≥ H_{α₂} (Rényi 1961 §4).
        let p = vec![0.6_f64, 0.25, 0.1, 0.05];
        let h_05 = renyi_entropy_from_probs(&p, 0.5);
        let h_2 = renyi_entropy_from_probs(&p, 2.0);
        let h_10 = renyi_entropy_from_probs(&p, 10.0);
        assert!(h_05 >= h_2 - 1e-9, "0.5 vs 2: {} {}", h_05, h_2);
        assert!(h_2 >= h_10 - 1e-9, "2 vs 10: {} {}", h_2, h_10);
    }

    #[test]
    fn renyi_entropy_large_alpha_approaches_min_entropy() {
        // H_α → H_∞ = −ln(p_max) as α → ∞.
        let p = vec![0.7_f64, 0.2, 0.1];
        let h_50 = renyi_entropy_from_probs(&p, 50.0);
        let h_inf = min_entropy(&p);
        // Numerical convergence is slow but should be close at α=50.
        assert!((h_50 - h_inf).abs() < 5e-2);
    }

    #[test]
    fn renyi_entropy_empty_and_alpha_singularity_are_nan() {
        assert!(renyi_entropy_from_probs(&[], 2.0).is_nan());
        assert!(renyi_entropy_from_probs(&[0.5, 0.5], 1.0).is_nan());
        assert!(renyi_entropy_from_probs(&[0.5, 0.5], -0.5).is_nan());
        assert!(renyi_entropy_from_probs(&[0.5, 0.5], 0.0).is_nan());
    }

    // ── iter-326: tsallis_entropy_from_probs ──────────────────────

    #[test]
    fn tsallis_entropy_q_2_equals_gini_simpson() {
        // S_2(p) = 1 − Σ pᵢ² (Gini-Simpson diversity).
        let p = vec![0.5_f64, 0.3, 0.2];
        let s = tsallis_entropy_from_probs(&p, 2.0);
        let expected = 1.0 - p.iter().map(|x| x * x).sum::<f64>();
        assert!((s - expected).abs() < 1e-12);
    }

    #[test]
    fn tsallis_entropy_deterministic_is_zero() {
        // p = (1, 0, …): S_q(p) = (1 − 1)/(q−1) = 0 for all valid q.
        let p = vec![1.0_f64, 0.0, 0.0];
        for q in [0.5_f64, 1.5, 2.0, 5.0] {
            let s = tsallis_entropy_from_probs(&p, q);
            assert!(s.abs() < 1e-12, "q={}: S={}", q, s);
        }
    }

    #[test]
    fn tsallis_entropy_uniform_n_value_matches_closed_form() {
        // For uniform p over n: S_q = (1 − n^(1−q))/(q−1).
        let n = 4_usize;
        let p = vec![1.0 / n as f64; n];
        for q in [0.5_f64, 2.0, 3.0] {
            let s = tsallis_entropy_from_probs(&p, q);
            let expected = (1.0 - (n as f64).powf(1.0 - q)) / (q - 1.0);
            assert!((s - expected).abs() < 1e-9, "q={}: S={} expected={}", q, s, expected);
        }
    }

    #[test]
    fn tsallis_entropy_nonneg_on_valid_distribution() {
        // S_q ≥ 0 for q > 0 on any valid probability vector.
        let p = vec![0.4_f64, 0.3, 0.2, 0.1];
        for q in [0.5_f64, 2.0, 5.0, 10.0] {
            let s = tsallis_entropy_from_probs(&p, q);
            assert!(s >= -1e-12, "q={}: S={} < 0", q, s);
        }
    }

    #[test]
    fn tsallis_entropy_empty_and_q_singularity_are_nan() {
        assert!(tsallis_entropy_from_probs(&[], 2.0).is_nan());
        assert!(tsallis_entropy_from_probs(&[0.5, 0.5], 1.0).is_nan());
        assert!(tsallis_entropy_from_probs(&[0.5, 0.5], 0.0).is_nan());
        assert!(tsallis_entropy_from_probs(&[0.5, 0.5], -0.3).is_nan());
    }

    // ── iter-338: binary_entropy ──────────────────────────────────

    #[test]
    fn binary_entropy_boundary_zero_and_one() {
        assert_eq!(binary_entropy(0.0), 0.0);
        assert_eq!(binary_entropy(1.0), 0.0);
    }

    #[test]
    fn binary_entropy_half_is_ln_two() {
        let h = binary_entropy(0.5);
        assert!((h - 2.0_f64.ln()).abs() < 1e-12);
    }

    #[test]
    fn binary_entropy_symmetric_around_one_half() {
        // H₂(p) = H₂(1−p).
        for p in [0.1_f64, 0.2, 0.3, 0.4, 0.49, 0.55, 0.7, 0.9] {
            let h_p = binary_entropy(p);
            let h_q = binary_entropy(1.0 - p);
            assert!((h_p - h_q).abs() < 1e-12);
        }
    }

    #[test]
    fn binary_entropy_matches_categorical_entropy_two_class() {
        // Bit-equal to categorical_entropy_from_probs on [p, 1-p].
        for p in [0.1_f64, 0.25, 0.49, 0.7, 0.999] {
            let h2 = binary_entropy(p);
            let hcat = categorical_entropy_from_probs(&[p, 1.0 - p]);
            assert!(
                (h2 - hcat).abs() < 1e-12,
                "p={}: binary={} categorical={}",
                p,
                h2,
                hcat
            );
        }
    }

    #[test]
    fn binary_entropy_out_of_range_is_nan() {
        assert!(binary_entropy(-0.01).is_nan());
        assert!(binary_entropy(1.01).is_nan());
        assert!(binary_entropy(f64::NAN).is_nan());
    }

    // ── iter-374: kl_exponential ──────────────────────────────────

    #[test]
    fn kl_exponential_self_is_zero() {
        for lambda in [0.5_f64, 1.0, 2.0, 5.0] {
            let v = kl_exponential(lambda, lambda);
            assert!(v.abs() < 1e-12, "λ={}: KL={}", lambda, v);
        }
    }

    #[test]
    fn kl_exponential_closed_form() {
        // (λ_p, λ_q) = (1, 2): KL = ln(0.5) + 2 − 1 = ln(0.5) + 1.
        let v = kl_exponential(1.0, 2.0);
        let expected = (0.5_f64).ln() + 1.0;
        assert!((v - expected).abs() < 1e-12);
    }

    #[test]
    fn kl_exponential_nonneg_on_grid() {
        for (lp, lq) in [(0.5_f64, 1.0), (1.0, 2.0), (2.0, 0.5), (4.0, 1.0)] {
            let v = kl_exponential(lp, lq);
            assert!(v >= -1e-12, "(λ_p, λ_q) = ({}, {}): KL={}", lp, lq, v);
        }
    }

    #[test]
    fn kl_exponential_invalid_inputs_are_nan() {
        assert!(kl_exponential(0.0, 1.0).is_nan());
        assert!(kl_exponential(1.0, 0.0).is_nan());
        assert!(kl_exponential(-1.0, 1.0).is_nan());
        assert!(kl_exponential(f64::NAN, 1.0).is_nan());
    }

    // ── iter-380: kl_poisson ──────────────────────────────────────

    #[test]
    fn kl_poisson_self_is_zero() {
        for lambda in [0.5_f64, 1.0, 2.0, 5.0] {
            let v = kl_poisson(lambda, lambda);
            assert!(v.abs() < 1e-12, "λ={}: KL={}", lambda, v);
        }
    }

    #[test]
    fn kl_poisson_closed_form() {
        // (λ_p, λ_q) = (3, 1): KL = 3·ln(3) − 3 + 1 = 3·ln(3) − 2.
        let v = kl_poisson(3.0, 1.0);
        let expected = 3.0 * 3.0_f64.ln() - 2.0;
        assert!((v - expected).abs() < 1e-12);
    }

    #[test]
    fn kl_poisson_nonneg_on_grid() {
        for (lp, lq) in [(0.5_f64, 1.0), (1.0, 2.0), (2.0, 0.5), (4.0, 1.0)] {
            let v = kl_poisson(lp, lq);
            assert!(v >= -1e-12, "(λ_p, λ_q) = ({}, {}): KL={}", lp, lq, v);
        }
    }

    #[test]
    fn kl_poisson_invalid_inputs_are_nan() {
        assert!(kl_poisson(0.0, 1.0).is_nan());
        assert!(kl_poisson(1.0, 0.0).is_nan());
        assert!(kl_poisson(-1.0, 1.0).is_nan());
        assert!(kl_poisson(f64::NAN, 1.0).is_nan());
    }

    // ── iter-386: binary_jeffreys_divergence ──────────────────────

    #[test]
    fn binary_jeffreys_self_is_zero() {
        for p in [0.0_f64, 0.3, 0.5, 0.8, 1.0] {
            let v = binary_jeffreys_divergence(p, p);
            assert!(v.abs() < 1e-12, "p={}: J={}", p, v);
        }
    }

    #[test]
    fn binary_jeffreys_symmetric() {
        for (p, q) in [(0.1_f64, 0.4), (0.3, 0.7), (0.5, 0.5), (0.9, 0.1)] {
            let a = binary_jeffreys_divergence(p, q);
            let b = binary_jeffreys_divergence(q, p);
            assert!((a - b).abs() < 1e-12, "(p, q) = ({}, {})", p, q);
        }
    }

    #[test]
    fn binary_jeffreys_equals_kl_sum() {
        for (p, q) in [(0.1_f64, 0.4), (0.3, 0.7)] {
            let j = binary_jeffreys_divergence(p, q);
            let sum = binary_kl_divergence(p, q) + binary_kl_divergence(q, p);
            assert!((j - sum).abs() < 1e-12, "(p, q) = ({}, {})", p, q);
        }
    }

    #[test]
    fn binary_jeffreys_extremes_at_p_zero_q_one_is_infinity() {
        let v = binary_jeffreys_divergence(0.0, 1.0);
        assert!(v.is_infinite());
    }

    #[test]
    fn binary_jeffreys_nonneg_on_grid() {
        for p in [0.1_f64, 0.3, 0.5, 0.7, 0.9] {
            for q in [0.1_f64, 0.3, 0.5, 0.7, 0.9] {
                let v = binary_jeffreys_divergence(p, q);
                assert!(v >= -1e-12, "(p, q) = ({}, {})", p, q);
            }
        }
    }

    #[test]
    fn binary_jeffreys_invalid_inputs_are_nan() {
        assert!(binary_jeffreys_divergence(-0.1, 0.5).is_nan());
        assert!(binary_jeffreys_divergence(0.5, 1.1).is_nan());
        assert!(binary_jeffreys_divergence(f64::NAN, 0.5).is_nan());
    }

    // ── iter-392: kl_geometric ────────────────────────────────────

    #[test]
    fn kl_geometric_self_is_zero() {
        for p in [0.1_f64, 0.3, 0.5, 0.7, 0.9] {
            let v = kl_geometric(p, p);
            assert!(v.abs() < 1e-12, "p={}: KL={}", p, v);
        }
    }

    #[test]
    fn kl_geometric_closed_form() {
        // (p_p, p_q) = (0.5, 0.25): KL = ln(2) + 1 · ln(0.5/0.75)
        //                              = ln(2) + ln(2/3).
        let v = kl_geometric(0.5, 0.25);
        let expected = 2.0_f64.ln() + (2.0_f64 / 3.0).ln();
        assert!((v - expected).abs() < 1e-12, "got {} expected {}", v, expected);
    }

    #[test]
    fn kl_geometric_nonneg_on_grid() {
        for pp in [0.1_f64, 0.3, 0.5, 0.7, 0.9] {
            for pq in [0.1_f64, 0.3, 0.5, 0.7, 0.9] {
                let v = kl_geometric(pp, pq);
                assert!(v >= -1e-12, "(p_p, p_q) = ({}, {}): KL={}", pp, pq, v);
            }
        }
    }

    #[test]
    fn kl_geometric_invalid_inputs_are_nan() {
        assert!(kl_geometric(0.0, 0.5).is_nan());
        assert!(kl_geometric(0.5, 0.0).is_nan());
        assert!(kl_geometric(1.0, 0.5).is_nan());
        assert!(kl_geometric(0.5, 1.0).is_nan());
        assert!(kl_geometric(f64::NAN, 0.5).is_nan());
    }

    // ── iter-398: gaussian_kl_same_variance ───────────────────────

    #[test]
    fn gaussian_kl_same_variance_self_is_zero() {
        for mu in [-2.0_f64, 0.0, 1.5] {
            let v = gaussian_kl_same_variance(mu, mu, 1.0);
            assert!(v.abs() < 1e-12, "μ={}: KL={}", mu, v);
        }
    }

    #[test]
    fn gaussian_kl_same_variance_matches_full_form() {
        // Should be bit-equal to gaussian_kl_full when σ² is shared.
        for (mu_p, mu_q, s) in [
            (0.0_f64, 1.0, 1.0),
            (2.0, -1.0, 4.0),
            (-3.0, 3.0, 0.5),
        ] {
            let same = gaussian_kl_same_variance(mu_p, mu_q, s);
            let full = gaussian_kl_full(mu_p, s, mu_q, s);
            assert!((same - full).abs() < 1e-12, "(μ_p, μ_q, σ²) = ({}, {}, {})", mu_p, mu_q, s);
        }
    }

    #[test]
    fn gaussian_kl_same_variance_closed_form() {
        // (μ_p, μ_q, σ²) = (0, 2, 1): KL = (2)² / 2 = 2.
        let v = gaussian_kl_same_variance(0.0, 2.0, 1.0);
        assert_eq!(v, 2.0);
    }

    #[test]
    fn gaussian_kl_same_variance_invalid_sigma_is_nan() {
        assert!(gaussian_kl_same_variance(0.0, 1.0, 0.0).is_nan());
        assert!(gaussian_kl_same_variance(0.0, 1.0, -1.0).is_nan());
        assert!(gaussian_kl_same_variance(0.0, 1.0, f64::NAN).is_nan());
    }

    // ── iter-410: mutual_information_binary_2x2 ───────────────────

    #[test]
    fn binary_2x2_mi_independent_joint_is_zero() {
        // p(x, y) = p(x)·p(y) (product distribution): MI = 0.
        // (px=0.5, py=0.5) → p_00 = p_01 = p_10 = p_11 = 0.25.
        let v = mutual_information_binary_2x2(0.25, 0.25, 0.25, 0.25);
        assert!(v.abs() < 1e-12);
    }

    #[test]
    fn binary_2x2_mi_deterministic_is_ln_2() {
        // p_00 = p_11 = 0.5, p_01 = p_10 = 0: X = Y a.s. → MI = H(X) = ln(2).
        let v = mutual_information_binary_2x2(0.5, 0.0, 0.0, 0.5);
        assert!((v - 2.0_f64.ln()).abs() < 1e-12);
    }

    #[test]
    fn binary_2x2_mi_nonneg_on_grid() {
        // Five (close to) valid joint distributions; MI ≥ 0.
        let joints = [
            (0.3_f64, 0.2, 0.1, 0.4),
            (0.5, 0.1, 0.1, 0.3),
            (0.4, 0.1, 0.2, 0.3),
        ];
        for (a, b, c, d) in joints {
            let v = mutual_information_binary_2x2(a, b, c, d);
            assert!(v >= -1e-12, "({}, {}, {}, {}): MI={}", a, b, c, d, v);
        }
    }

    #[test]
    fn binary_2x2_mi_invalid_inputs_are_nan() {
        // Negative cell.
        assert!(mutual_information_binary_2x2(-0.1, 0.3, 0.3, 0.5).is_nan());
        // Doesn't sum to 1.
        assert!(mutual_information_binary_2x2(0.1, 0.1, 0.1, 0.1).is_nan());
        // NaN cell.
        assert!(mutual_information_binary_2x2(f64::NAN, 0.25, 0.25, 0.25).is_nan());
    }

    // ── iter-368: binary_chi_squared_divergence ───────────────────

    #[test]
    fn binary_chi_squared_self_is_zero() {
        for p in [0.0_f64, 0.3, 0.5, 0.8, 1.0] {
            let v = binary_chi_squared_divergence(p, p);
            assert!(v.abs() < 1e-12, "p={}: χ²={}", p, v);
        }
    }

    #[test]
    fn binary_chi_squared_nonnegative_on_grid() {
        for p in [0.1_f64, 0.3, 0.5, 0.7, 0.9] {
            for q in [0.1_f64, 0.3, 0.5, 0.7, 0.9] {
                let v = binary_chi_squared_divergence(p, q);
                assert!(v >= -1e-12, "(p, q) = ({}, {})", p, q);
            }
        }
    }

    #[test]
    fn binary_chi_squared_closed_form_check() {
        // p = 0.6, q = 0.4: (0.2)² / (0.4 · 0.6) = 0.04 / 0.24 = 1/6.
        let v = binary_chi_squared_divergence(0.6, 0.4);
        assert!((v - 1.0 / 6.0).abs() < 1e-12);
    }

    #[test]
    fn binary_chi_squared_q_at_boundary_with_p_different_is_inf() {
        let v = binary_chi_squared_divergence(0.3, 0.0);
        assert!(v.is_infinite() && v > 0.0);
        let v2 = binary_chi_squared_divergence(0.3, 1.0);
        assert!(v2.is_infinite() && v2 > 0.0);
    }

    #[test]
    fn binary_chi_squared_q_at_boundary_with_p_equal_is_zero() {
        // p = q = 0 or p = q = 1: divergence is 0 by the support-
        // match convention.
        assert_eq!(binary_chi_squared_divergence(0.0, 0.0), 0.0);
        assert_eq!(binary_chi_squared_divergence(1.0, 1.0), 0.0);
    }

    #[test]
    fn binary_chi_squared_invalid_inputs_are_nan() {
        assert!(binary_chi_squared_divergence(-0.1, 0.5).is_nan());
        assert!(binary_chi_squared_divergence(0.5, 1.1).is_nan());
        assert!(binary_chi_squared_divergence(f64::NAN, 0.5).is_nan());
    }

    // ── iter-362: binary_hellinger_distance ───────────────────────

    #[test]
    fn binary_hellinger_self_is_zero() {
        for p in [0.0_f64, 0.2, 0.5, 0.8, 1.0] {
            let v = binary_hellinger_distance(p, p);
            assert!(v.abs() < 1e-12, "p={}: H={}", p, v);
        }
    }

    #[test]
    fn binary_hellinger_extreme_is_one() {
        // H(Bernoulli(0), Bernoulli(1)) = 1.
        let v = binary_hellinger_distance(0.0, 1.0);
        assert!((v - 1.0).abs() < 1e-12);
    }

    #[test]
    fn binary_hellinger_symmetric() {
        for (p, q) in [(0.0_f64, 0.5), (0.1, 0.7), (0.3, 0.9), (0.5, 0.5)] {
            let a = binary_hellinger_distance(p, q);
            let b = binary_hellinger_distance(q, p);
            assert!((a - b).abs() < 1e-12, "(p, q) = ({}, {})", p, q);
        }
    }

    #[test]
    fn binary_hellinger_bounded_in_zero_one() {
        for (p, q) in [
            (0.0_f64, 1.0),
            (0.1, 0.9),
            (0.3, 0.6),
            (0.5, 0.5),
        ] {
            let v = binary_hellinger_distance(p, q);
            assert!(v >= -1e-12 && v <= 1.0 + 1e-12, "H={}", v);
        }
    }

    #[test]
    fn binary_hellinger_squared_matches_hellinger_squared_from_probs() {
        for (p, q) in [(0.1_f64, 0.4), (0.3, 0.7), (0.5, 0.5)] {
            let h = binary_hellinger_distance(p, q);
            let h_sq_from_probs = hellinger_squared_from_probs(&[p, 1.0 - p], &[q, 1.0 - q]);
            assert!(
                (h * h - h_sq_from_probs).abs() < 1e-12,
                "(p, q) = ({}, {})",
                p,
                q
            );
        }
    }

    #[test]
    fn binary_hellinger_invalid_inputs_are_nan() {
        assert!(binary_hellinger_distance(-0.1, 0.5).is_nan());
        assert!(binary_hellinger_distance(0.5, 1.1).is_nan());
        assert!(binary_hellinger_distance(f64::NAN, 0.5).is_nan());
    }

    // ── iter-356: binary_total_variation_distance ─────────────────

    #[test]
    fn binary_tv_self_is_zero() {
        for p in [0.0_f64, 0.3, 0.5, 0.8, 1.0] {
            assert_eq!(binary_total_variation_distance(p, p), 0.0);
        }
    }

    #[test]
    fn binary_tv_extreme_is_one() {
        assert_eq!(binary_total_variation_distance(0.0, 1.0), 1.0);
        assert_eq!(binary_total_variation_distance(1.0, 0.0), 1.0);
    }

    #[test]
    fn binary_tv_symmetric_and_metric() {
        for (p, q) in [(0.0_f64, 0.4), (0.1, 0.8), (0.3, 0.7), (0.5, 0.5)] {
            let a = binary_total_variation_distance(p, q);
            let b = binary_total_variation_distance(q, p);
            assert_eq!(a, b);
        }
    }

    #[test]
    fn binary_tv_matches_total_variation_from_probs_two_class() {
        for (p, q) in [(0.1_f64, 0.4), (0.3, 0.7), (0.5, 0.5), (0.9, 0.1)] {
            let bk = binary_total_variation_distance(p, q);
            let vec = total_variation_from_probs(&[p, 1.0 - p], &[q, 1.0 - q]);
            assert!((bk - vec).abs() < 1e-12, "(p, q) = ({}, {})", p, q);
        }
    }

    #[test]
    fn binary_tv_pinsker_inequality() {
        // Pinsker's inequality: 2·TV² ≤ KL on the binary support.
        for (p, q) in [(0.2_f64, 0.5), (0.3, 0.7), (0.1, 0.9)] {
            let tv = binary_total_variation_distance(p, q);
            let kl = binary_kl_divergence(p, q);
            assert!(2.0 * tv * tv <= kl + 1e-9, "TV²={}, KL={}", tv * tv, kl);
        }
    }

    #[test]
    fn binary_tv_invalid_inputs_are_nan() {
        assert!(binary_total_variation_distance(-0.1, 0.5).is_nan());
        assert!(binary_total_variation_distance(0.5, 1.1).is_nan());
        assert!(binary_total_variation_distance(f64::NAN, 0.5).is_nan());
    }

    // ── iter-404: binary_jensen_shannon_distance ──────────────────

    #[test]
    fn binary_js_distance_self_is_zero() {
        for p in [0.0_f64, 0.3, 0.5, 0.7, 1.0] {
            let v = binary_jensen_shannon_distance(p, p);
            assert!(v.abs() < 1e-12);
        }
    }

    #[test]
    fn binary_js_distance_extreme_is_sqrt_ln_2() {
        // JS(0, 1) = ln(2), so distance = sqrt(ln(2)).
        let v = binary_jensen_shannon_distance(0.0, 1.0);
        let expected = 2.0_f64.ln().sqrt();
        assert!((v - expected).abs() < 1e-12);
    }

    #[test]
    fn binary_js_distance_symmetric() {
        for (p, q) in [(0.1_f64, 0.7), (0.3, 0.9), (0.4, 0.6)] {
            let a = binary_jensen_shannon_distance(p, q);
            let b = binary_jensen_shannon_distance(q, p);
            assert!((a - b).abs() < 1e-12);
        }
    }

    #[test]
    fn binary_js_distance_squared_matches_js_divergence() {
        for (p, q) in [(0.1_f64, 0.4), (0.3, 0.7), (0.5, 0.5)] {
            let d = binary_jensen_shannon_distance(p, q);
            let div = binary_jensen_shannon_divergence(p, q);
            assert!((d * d - div).abs() < 1e-12);
        }
    }

    #[test]
    fn binary_js_distance_invalid_inputs_are_nan() {
        assert!(binary_jensen_shannon_distance(-0.1, 0.5).is_nan());
        assert!(binary_jensen_shannon_distance(0.5, 1.1).is_nan());
        assert!(binary_jensen_shannon_distance(f64::NAN, 0.5).is_nan());
    }

    // ── iter-350: binary_jensen_shannon_divergence ────────────────

    #[test]
    fn binary_js_self_is_zero() {
        for p in [0.0_f64, 0.1, 0.5, 0.9, 1.0] {
            let v = binary_jensen_shannon_divergence(p, p);
            assert!(v.abs() < 1e-12, "p={}: JS={}", p, v);
        }
    }

    #[test]
    fn binary_js_symmetric() {
        for (p, q) in [(0.0_f64, 0.5), (0.1, 0.7), (0.3, 0.8), (0.5, 0.5)] {
            let a = binary_jensen_shannon_divergence(p, q);
            let b = binary_jensen_shannon_divergence(q, p);
            assert!((a - b).abs() < 1e-12, "(p, q) = ({}, {})", p, q);
        }
    }

    #[test]
    fn binary_js_extremes_at_p_zero_q_one_is_ln_two() {
        let v = binary_jensen_shannon_divergence(0.0, 1.0);
        let expected = 2.0_f64.ln();
        assert!((v - expected).abs() < 1e-12);
    }

    #[test]
    fn binary_js_bounded_above_by_ln_two() {
        for (p, q) in [
            (0.0_f64, 1.0),
            (0.1, 0.9),
            (0.3, 0.6),
            (0.5, 0.5),
            (0.4, 0.4),
        ] {
            let v = binary_jensen_shannon_divergence(p, q);
            assert!(v <= 2.0_f64.ln() + 1e-12, "JS({}, {}) = {}", p, q, v);
        }
    }

    #[test]
    fn binary_js_degenerate_both_zero_is_zero() {
        let v = binary_jensen_shannon_divergence(0.0, 0.0);
        assert_eq!(v, 0.0);
    }

    #[test]
    fn binary_js_invalid_inputs_are_nan() {
        assert!(binary_jensen_shannon_divergence(-0.1, 0.5).is_nan());
        assert!(binary_jensen_shannon_divergence(0.5, 1.1).is_nan());
        assert!(binary_jensen_shannon_divergence(f64::NAN, 0.5).is_nan());
    }

    // ── iter-344: binary_kl_divergence ────────────────────────────

    #[test]
    fn binary_kl_self_is_zero() {
        for p in [0.1_f64, 0.3, 0.5, 0.8, 0.99] {
            let v = binary_kl_divergence(p, p);
            assert!(v.abs() < 1e-12, "p={}: KL={}", p, v);
        }
    }

    #[test]
    fn binary_kl_matches_kl_from_probs_two_class() {
        // Bit-equal to kl_from_probs on the 2-vector form.
        for (p, q) in [
            (0.1_f64, 0.4),
            (0.3, 0.7),
            (0.5, 0.5),
            (0.9, 0.1),
            (0.01, 0.99),
        ] {
            let bk = binary_kl_divergence(p, q);
            let vk = kl_from_probs(&[p, 1.0 - p], &[q, 1.0 - q]);
            assert!((bk - vk).abs() < 1e-12, "(p, q) = ({}, {})", p, q);
        }
    }

    #[test]
    fn binary_kl_boundary_p_zero_or_one_collapses() {
        // p = 0: only the (1-p) term contributes.
        let v0 = binary_kl_divergence(0.0, 0.5);
        let expected_0 = 1.0_f64 * (1.0 / 0.5_f64).ln();
        assert!((v0 - expected_0).abs() < 1e-12);
        // p = 1: only the p term contributes.
        let v1 = binary_kl_divergence(1.0, 0.5);
        let expected_1 = 1.0_f64 * (1.0 / 0.5_f64).ln();
        assert!((v1 - expected_1).abs() < 1e-12);
    }

    #[test]
    fn binary_kl_q_zero_with_p_positive_is_infinity() {
        let v = binary_kl_divergence(0.3, 0.0);
        assert!(v.is_infinite() && v > 0.0);
        // Mirror case: q = 1 with p < 1.
        let v2 = binary_kl_divergence(0.3, 1.0);
        assert!(v2.is_infinite() && v2 > 0.0);
    }

    #[test]
    fn binary_kl_nonnegative_on_grid() {
        // KL divergence is non-negative (Gibbs).
        for p in [0.1_f64, 0.3, 0.5, 0.7, 0.9] {
            for q in [0.1_f64, 0.3, 0.5, 0.7, 0.9] {
                let v = binary_kl_divergence(p, q);
                assert!(v >= -1e-12, "(p, q) = ({}, {}): KL={}", p, q, v);
            }
        }
    }

    #[test]
    fn binary_kl_invalid_inputs_are_nan() {
        assert!(binary_kl_divergence(-0.1, 0.5).is_nan());
        assert!(binary_kl_divergence(0.5, 1.1).is_nan());
        assert!(binary_kl_divergence(f64::NAN, 0.5).is_nan());
        assert!(binary_kl_divergence(0.5, f64::NAN).is_nan());
    }

    // ── iter-332: hill_number_from_probs ──────────────────────────

    #[test]
    fn hill_number_uniform_n_equals_n() {
        // For uniform p over n: N_q ≡ n for every q > 0.
        for n in 2..=8_usize {
            let p = vec![1.0 / n as f64; n];
            for q in [0.5_f64, 1.0, 2.0, 5.0] {
                let nq = hill_number_from_probs(&p, q);
                assert!((nq - n as f64).abs() < 1e-9, "n={} q={}: N={}", n, q, nq);
            }
        }
    }

    #[test]
    fn hill_number_q_2_equals_inverse_collision_sum() {
        // N_2 = 1 / Σ pᵢ² (Simpson effective N).
        let p = vec![0.5_f64, 0.3, 0.2];
        let n2 = hill_number_from_probs(&p, 2.0);
        let sum_sq: f64 = p.iter().map(|x| x * x).sum();
        assert!((n2 - 1.0 / sum_sq).abs() < 1e-12);
    }

    #[test]
    fn hill_number_q_1_equals_exp_shannon() {
        // N_1 = exp(H_shannon).
        let p = vec![0.4_f64, 0.3, 0.2, 0.1];
        let n1 = hill_number_from_probs(&p, 1.0);
        let h = categorical_entropy_from_probs(&p);
        assert!((n1 - h.exp()).abs() < 1e-12);
    }

    #[test]
    fn hill_number_deterministic_is_one() {
        let p = vec![1.0_f64, 0.0, 0.0];
        for q in [0.5_f64, 1.0, 2.0, 5.0] {
            let nq = hill_number_from_probs(&p, q);
            assert!((nq - 1.0).abs() < 1e-9, "q={}: N={}", q, nq);
        }
    }

    #[test]
    fn hill_number_monotone_non_increasing_in_q() {
        // Same monotonicity as Rényi entropy: q₁ ≤ q₂ ⇒ N_{q₁} ≥ N_{q₂}.
        let p = vec![0.6_f64, 0.25, 0.1, 0.05];
        let n_05 = hill_number_from_probs(&p, 0.5);
        let n_1 = hill_number_from_probs(&p, 1.0);
        let n_2 = hill_number_from_probs(&p, 2.0);
        let n_10 = hill_number_from_probs(&p, 10.0);
        assert!(n_05 >= n_1 - 1e-9);
        assert!(n_1 >= n_2 - 1e-9);
        assert!(n_2 >= n_10 - 1e-9);
    }

    #[test]
    fn hill_number_empty_and_q_invalid_are_nan() {
        assert!(hill_number_from_probs(&[], 2.0).is_nan());
        assert!(hill_number_from_probs(&[0.5, 0.5], 0.0).is_nan());
        assert!(hill_number_from_probs(&[0.5, 0.5], -0.5).is_nan());
    }

    // ── iter-302: bayes_error_rate ────────────────────────────────

    #[test]
    fn bayes_error_deterministic_is_zero() {
        let p = vec![1.0_f64, 0.0, 0.0];
        assert!(bayes_error_rate(&p).abs() < 1e-12);
    }

    #[test]
    fn bayes_error_uniform_n_is_one_minus_one_over_n() {
        for n in 2..=8_usize {
            let p = vec![1.0 / n as f64; n];
            let err = bayes_error_rate(&p);
            assert!((err - (1.0 - 1.0 / n as f64)).abs() < 1e-12);
        }
    }

    #[test]
    fn bayes_error_complements_mode_probability() {
        let p = vec![0.7_f64, 0.2, 0.1];
        let err = bayes_error_rate(&p);
        let mode = mode_probability(&p);
        assert!((err + mode - 1.0).abs() < 1e-12);
    }

    #[test]
    fn bayes_error_empty_is_nan() {
        assert!(bayes_error_rate(&[]).is_nan());
    }

    // ── iter-260: mode_index ──────────────────────────────────────

    #[test]
    fn mode_index_basic() {
        let p = vec![0.1_f64, 0.7, 0.2];
        assert_eq!(mode_index(&p), Some(1));
    }

    #[test]
    fn mode_index_empty_is_none() {
        assert!(mode_index(&[]).is_none());
    }

    #[test]
    fn mode_index_nan_is_none() {
        let p = vec![0.5_f64, f64::NAN, 0.2];
        assert!(mode_index(&p).is_none());
    }

    #[test]
    fn mode_index_tie_breaks_to_lowest_index() {
        let p = vec![0.5_f64, 0.5];
        assert_eq!(mode_index(&p), Some(0));
    }

    #[test]
    fn mode_index_value_matches_mode_probability() {
        let p = vec![0.1_f64, 0.7, 0.2];
        let idx = mode_index(&p).unwrap();
        assert_eq!(p[idx], mode_probability(&p));
    }

    // ── iter-224: mode_probability ────────────────────────────────

    #[test]
    fn mode_probability_uniform_n_is_one_over_n() {
        for n in 2..=8_usize {
            let p = vec![1.0 / n as f64; n];
            let m = mode_probability(&p);
            assert!((m - 1.0 / n as f64).abs() < 1e-12);
        }
    }

    #[test]
    fn mode_probability_deterministic_is_one() {
        let p = vec![0.0_f64, 0.0, 1.0, 0.0];
        assert!((mode_probability(&p) - 1.0).abs() < 1e-12);
    }

    #[test]
    fn mode_probability_complement_is_bayes_error() {
        // (0.7, 0.2, 0.1): M = 0.7, Bayes error = 0.3.
        let p = vec![0.7_f64, 0.2, 0.1];
        assert!((1.0 - mode_probability(&p) - 0.3).abs() < 1e-12);
    }

    #[test]
    fn mode_probability_empty_is_nan() {
        assert!(mode_probability(&[]).is_nan());
    }

    // ── iter-308: fano_inequality_rhs ─────────────────────────────

    #[test]
    fn fano_zero_error_is_zero() {
        for n in 2..=8_usize {
            assert!(fano_inequality_rhs(0.0, n).abs() < 1e-12);
        }
    }

    #[test]
    fn fano_binary_case_reduces_to_binary_entropy() {
        // n = 2: RHS = H_b(p_e).
        let p_e = 0.3_f64;
        let rhs = fano_inequality_rhs(p_e, 2);
        let h_b = -p_e * p_e.ln() - (1.0 - p_e) * (1.0 - p_e).ln();
        assert!((rhs - h_b).abs() < 1e-12);
    }

    #[test]
    fn fano_full_error_is_log_n_minus_1() {
        // p_e = 1, H_b(1) = 0 → RHS = ln(n-1).
        let rhs = fano_inequality_rhs(1.0, 5);
        assert!((rhs - 4.0_f64.ln()).abs() < 1e-9);
    }

    #[test]
    fn fano_invalid_inputs_return_nan() {
        assert!(fano_inequality_rhs(0.5, 1).is_nan());
        assert!(fano_inequality_rhs(-0.1, 5).is_nan());
        assert!(fano_inequality_rhs(1.1, 5).is_nan());
    }

    // ── iter-278: pinsker_kl_lower_bound ──────────────────────────

    #[test]
    fn pinsker_zero_tv_is_zero_bound() {
        assert_eq!(pinsker_kl_lower_bound(0.0), 0.0);
    }

    #[test]
    fn pinsker_quadratic_in_tv() {
        // 2·(0.5)² = 0.5; 2·(1)² = 2.
        assert!((pinsker_kl_lower_bound(0.5) - 0.5).abs() < 1e-12);
        assert!((pinsker_kl_lower_bound(1.0) - 2.0).abs() < 1e-12);
    }

    #[test]
    fn pinsker_lower_bound_actually_lower_bounds_kl() {
        // KL(p || q) ≥ 2·TV²(p, q) (Pinsker).
        let p = vec![0.5_f64, 0.5];
        let q = vec![0.1_f64, 0.9];
        let tv = total_variation_from_probs(&p, &q);
        let bound = pinsker_kl_lower_bound(tv);
        let kl = kl_from_probs(&p, &q);
        assert!(kl >= bound - 1e-9, "KL={} not ≥ Pinsker bound={}", kl, bound);
    }

    // ── iter-272: chi_squared_from_probs ──────────────────────────

    #[test]
    fn chi_squared_from_probs_self_is_zero() {
        let p = vec![0.2_f64, 0.3, 0.5];
        assert!(chi_squared_from_probs(&p, &p).abs() < 1e-12);
    }

    #[test]
    fn chi_squared_from_probs_known() {
        // p = (0.5, 0.5); q = (0.4, 0.6).
        // (0.1)²/0.4 + (-0.1)²/0.6 = 0.025 + 0.01667 = 0.04167.
        let p = vec![0.5_f64, 0.5];
        let q = vec![0.4_f64, 0.6];
        let chi2 = chi_squared_from_probs(&p, &q);
        let expected = 0.01 / 0.4 + 0.01 / 0.6;
        assert!((chi2 - expected).abs() < 1e-9);
    }

    #[test]
    fn chi_squared_from_probs_zero_q_with_positive_p_is_infinite() {
        let p = vec![0.5_f64, 0.5];
        let q = vec![1.0_f64, 0.0];
        assert!(chi_squared_from_probs(&p, &q).is_infinite());
    }

    #[test]
    fn chi_squared_from_probs_dim_mismatch_is_nan() {
        assert!(chi_squared_from_probs(&[0.5, 0.5], &[1.0]).is_nan());
    }

    // ── iter-266: js_distance ─────────────────────────────────────

    #[test]
    fn js_distance_self_is_zero() {
        let p = vec![0.2_f64, 0.3, 0.5];
        assert!(js_distance(&p, &p).abs() < 1e-12);
    }

    #[test]
    fn js_distance_disjoint_is_sqrt_ln_2() {
        let p = vec![1.0_f64, 0.0];
        let q = vec![0.0_f64, 1.0];
        let d = js_distance(&p, &q);
        let expected = 2.0_f64.ln().sqrt();
        assert!((d - expected).abs() < 1e-9);
    }

    #[test]
    fn js_distance_symmetric() {
        let p = vec![0.4_f64, 0.6];
        let q = vec![0.1_f64, 0.9];
        let pq = js_distance(&p, &q);
        let qp = js_distance(&q, &p);
        assert!((pq - qp).abs() < 1e-12);
    }

    #[test]
    fn js_distance_dim_mismatch_is_nan() {
        assert!(js_distance(&[0.5, 0.5], &[1.0]).is_nan());
    }

    // ── iter-218: total_variation_from_probs ──────────────────────

    #[test]
    fn tv_from_probs_self_is_zero() {
        let p = vec![0.2_f64, 0.3, 0.5];
        assert!(total_variation_from_probs(&p, &p).abs() < 1e-12);
    }

    #[test]
    fn tv_from_probs_disjoint_support_is_one() {
        let p = vec![1.0_f64, 0.0];
        let q = vec![0.0_f64, 1.0];
        assert!((total_variation_from_probs(&p, &q) - 1.0).abs() < 1e-12);
    }

    #[test]
    fn tv_from_probs_symmetric() {
        let p = vec![0.4_f64, 0.6];
        let q = vec![0.1_f64, 0.9];
        let pq = total_variation_from_probs(&p, &q);
        let qp = total_variation_from_probs(&q, &p);
        assert!((pq - qp).abs() < 1e-12);
    }

    #[test]
    fn tv_from_probs_known_value() {
        // p = (0.4, 0.6), q = (0.1, 0.9): |0.3| + |0.3| = 0.6 → TV = 0.3.
        let p = vec![0.4_f64, 0.6];
        let q = vec![0.1_f64, 0.9];
        assert!((total_variation_from_probs(&p, &q) - 0.3).abs() < 1e-12);
    }

    #[test]
    fn tv_from_probs_dim_mismatch_is_nan() {
        assert!(total_variation_from_probs(&[0.5, 0.5], &[1.0]).is_nan());
    }

    // ── iter-212: effective_sample_size_from_weights ──────────────

    #[test]
    fn ess_uniform_weights_equals_n() {
        for n in 2..=8_usize {
            let w = vec![1.0 / n as f64; n];
            let ess = effective_sample_size_from_weights(&w);
            assert!((ess - n as f64).abs() < 1e-9, "n={}: ess={}", n, ess);
        }
    }

    #[test]
    fn ess_one_hot_is_one() {
        let w = vec![1.0_f64, 0.0, 0.0, 0.0];
        assert!((effective_sample_size_from_weights(&w) - 1.0).abs() < 1e-12);
    }

    #[test]
    fn ess_skewed_between_one_and_uniform_ess() {
        // n=2, w=(0.9, 0.1): Σw² = 0.82; ESS = 1/0.82 ≈ 1.22.
        let w = vec![0.9_f64, 0.1];
        let ess = effective_sample_size_from_weights(&w);
        assert!(ess > 1.0 && ess < 2.0, "ess = {}", ess);
        assert!((ess - 1.0 / 0.82).abs() < 1e-9);
    }

    #[test]
    fn ess_empty_is_nan() {
        assert!(effective_sample_size_from_weights(&[]).is_nan());
    }

    // ── iter-206: perplexity ──────────────────────────────────────

    #[test]
    fn perplexity_deterministic_is_one() {
        let p = vec![1.0_f64, 0.0, 0.0, 0.0];
        assert!((perplexity(&p) - 1.0).abs() < 1e-12);
    }

    #[test]
    fn perplexity_uniform_n_equals_n() {
        // H(uniform on n) = ln(n) → PP = exp(ln(n)) = n.
        for n in 2..=8_usize {
            let p = vec![1.0 / n as f64; n];
            let pp = perplexity(&p);
            assert!((pp - n as f64).abs() < 1e-9, "n={}: pp={}", n, pp);
        }
    }

    #[test]
    fn perplexity_skewed_two_class_between_1_and_2() {
        // 0.9, 0.1 → H ≈ 0.325 → PP ≈ 1.38.
        let p = vec![0.9_f64, 0.1];
        let pp = perplexity(&p);
        assert!(pp > 1.0 && pp < 2.0, "pp = {}", pp);
    }

    #[test]
    fn perplexity_monotone_under_softening() {
        // Mixing the distribution toward uniform → perplexity ↑.
        let sharp = vec![0.9_f64, 0.1];
        let soft = vec![0.6_f64, 0.4];
        assert!(perplexity(&sharp) < perplexity(&soft));
    }

    // ── iter-200: gini_impurity ───────────────────────────────────

    #[test]
    fn gini_impurity_deterministic_is_zero() {
        let p = vec![1.0_f64, 0.0, 0.0];
        assert!(gini_impurity(&p).abs() < 1e-12);
    }

    #[test]
    fn gini_impurity_uniform_2_is_one_half() {
        let p = vec![0.5_f64, 0.5];
        assert!((gini_impurity(&p) - 0.5).abs() < 1e-12);
    }

    #[test]
    fn gini_impurity_uniform_n_is_one_minus_one_over_n() {
        // G(uniform on n) = 1 - n·(1/n)² = 1 - 1/n.
        for n in 2..=10_usize {
            let p = vec![1.0 / n as f64; n];
            let g = gini_impurity(&p);
            let expected = 1.0 - 1.0 / n as f64;
            assert!((g - expected).abs() < 1e-12, "n={}: g={} exp={}", n, g, expected);
        }
    }

    #[test]
    fn gini_impurity_two_class_skewed() {
        // G(0.9, 0.1) = 1 - (0.81 + 0.01) = 0.18.
        let p = vec![0.9_f64, 0.1];
        assert!((gini_impurity(&p) - 0.18).abs() < 1e-12);
    }

    #[test]
    fn gini_impurity_empty_is_nan() {
        assert!(gini_impurity(&[]).is_nan());
    }

    // ── iter-194: renyi_divergence_from_probs ─────────────────────

    #[test]
    fn renyi_divergence_self_is_zero() {
        let p = vec![0.2_f64, 0.3, 0.5];
        for alpha in [0.5_f64, 2.0, 3.0] {
            let d = renyi_divergence_from_probs(&p, &p, alpha);
            assert!(d.abs() < 1e-12, "D_{}(p||p) = {}", alpha, d);
        }
    }

    #[test]
    fn renyi_divergence_alpha_eq_one_is_nan() {
        let p = vec![0.5_f64, 0.5];
        let q = vec![0.6_f64, 0.4];
        assert!(renyi_divergence_from_probs(&p, &q, 1.0).is_nan());
    }

    #[test]
    fn renyi_divergence_disjoint_support_is_infinite() {
        let p = vec![1.0_f64, 0.0];
        let q = vec![0.0_f64, 1.0];
        assert!(renyi_divergence_from_probs(&p, &q, 0.5).is_infinite());
    }

    #[test]
    fn renyi_divergence_dim_mismatch_returns_nan() {
        let d = renyi_divergence_from_probs(&[0.5, 0.5], &[1.0], 2.0);
        assert!(d.is_nan());
    }

    #[test]
    fn renyi_half_matches_minus_two_ln_bc() {
        // D_{1/2}(p || q) = -2 ln BC(p, q).
        let p = vec![0.2_f64, 0.3, 0.5];
        let q = vec![0.4_f64, 0.4, 0.2];
        let renyi_half = renyi_divergence_from_probs(&p, &q, 0.5);
        let bc = bhattacharyya_coefficient(&p, &q);
        let expected = -2.0 * bc.ln();
        assert!((renyi_half - expected).abs() < 1e-9, "{} vs {}", renyi_half, expected);
    }

    // ── iter-314: hellinger_squared_from_probs ────────────────────

    #[test]
    fn hellinger_squared_self_is_zero() {
        let p = vec![0.2_f64, 0.3, 0.5];
        assert!(hellinger_squared_from_probs(&p, &p).abs() < 1e-12);
    }

    #[test]
    fn hellinger_squared_disjoint_is_one() {
        let p = vec![1.0_f64, 0.0];
        let q = vec![0.0_f64, 1.0];
        assert!((hellinger_squared_from_probs(&p, &q) - 1.0).abs() < 1e-12);
    }

    #[test]
    fn hellinger_squared_equals_one_minus_bc() {
        let p = vec![0.4_f64, 0.6];
        let q = vec![0.1_f64, 0.9];
        let h2 = hellinger_squared_from_probs(&p, &q);
        let bc = bhattacharyya_coefficient(&p, &q);
        assert!((h2 - (1.0 - bc)).abs() < 1e-12);
    }

    #[test]
    fn hellinger_squared_in_unit_interval() {
        let p = vec![0.7_f64, 0.2, 0.1];
        let q = vec![0.4_f64, 0.4, 0.2];
        let h2 = hellinger_squared_from_probs(&p, &q);
        assert!(h2 >= 0.0 && h2 <= 1.0 + 1e-9);
    }

    // ── iter-188: bhattacharyya_coefficient + _distance ───────────

    #[test]
    fn bhattacharyya_coefficient_self_is_one() {
        let p = vec![0.2_f64, 0.3, 0.5];
        assert!((bhattacharyya_coefficient(&p, &p) - 1.0).abs() < 1e-12);
    }

    #[test]
    fn bhattacharyya_coefficient_symmetric() {
        let p = vec![0.1_f64, 0.6, 0.3];
        let q = vec![0.4_f64, 0.4, 0.2];
        let pq = bhattacharyya_coefficient(&p, &q);
        let qp = bhattacharyya_coefficient(&q, &p);
        assert!((pq - qp).abs() < 1e-12);
    }

    #[test]
    fn bhattacharyya_disjoint_support_gives_zero_coefficient() {
        let p = vec![1.0_f64, 0.0];
        let q = vec![0.0_f64, 1.0];
        assert!(bhattacharyya_coefficient(&p, &q).abs() < 1e-12);
    }

    #[test]
    fn bhattacharyya_distance_self_is_zero() {
        let p = vec![0.2_f64, 0.8];
        assert!(bhattacharyya_distance(&p, &p).abs() < 1e-12);
    }

    #[test]
    fn bhattacharyya_distance_disjoint_is_infinite() {
        let p = vec![1.0_f64, 0.0];
        let q = vec![0.0_f64, 1.0];
        assert!(bhattacharyya_distance(&p, &q).is_infinite());
    }

    #[test]
    fn bhattacharyya_dim_mismatch_returns_nan() {
        assert!(bhattacharyya_coefficient(&[0.5, 0.5], &[1.0]).is_nan());
        assert!(bhattacharyya_distance(&[0.5, 0.5], &[1.0]).is_nan());
    }

    // ── iter-170: kl_from_probs ───────────────────────────────────

    #[test]
    fn kl_from_probs_self_is_zero() {
        let p = vec![0.4, 0.6];
        assert!(kl_from_probs(&p, &p).abs() < 1e-12);
    }

    #[test]
    fn kl_from_probs_uniform_vs_skewed() {
        // KL(uniform || skewed). p=(0.5, 0.5), q=(0.9, 0.1).
        // KL = 0.5·log(0.5/0.9) + 0.5·log(0.5/0.1)
        //    = 0.5·(-0.5878) + 0.5·(1.609)
        //    = -0.2939 + 0.8047 = 0.5108.
        let kl = kl_from_probs(&[0.5, 0.5], &[0.9, 0.1]);
        let expected = 0.5 * (0.5_f64 / 0.9).ln() + 0.5 * (0.5_f64 / 0.1).ln();
        assert!((kl - expected).abs() < 1e-12);
    }

    #[test]
    fn kl_from_probs_q_zero_where_p_nonzero_is_infinity() {
        let kl = kl_from_probs(&[0.5, 0.5], &[1.0, 0.0]);
        assert!(kl.is_infinite());
    }

    #[test]
    fn kl_from_probs_p_zero_handled() {
        // p_i = 0 contributes 0·log(0/q_i) = 0 (entropy convention).
        let kl = kl_from_probs(&[0.0, 1.0], &[0.5, 0.5]);
        let expected = 1.0 * (1.0_f64 / 0.5).ln();
        assert!((kl - expected).abs() < 1e-12);
    }

    #[test]
    fn kl_from_probs_dim_mismatch_returns_nan() {
        let kl = kl_from_probs(&[0.5, 0.5], &[1.0]);
        assert!(kl.is_nan());
    }

    // ── iter-163: is_valid_probability_vector + joint ─────────────

    #[test]
    fn is_valid_probability_vector_uniform() {
        assert!(is_valid_probability_vector(&[0.25, 0.25, 0.25, 0.25], 1e-12));
    }

    #[test]
    fn is_valid_probability_vector_rejects_negative() {
        assert!(!is_valid_probability_vector(&[0.5, -0.1, 0.6], 1e-12));
    }

    #[test]
    fn is_valid_probability_vector_rejects_non_sum_to_one() {
        assert!(!is_valid_probability_vector(&[0.3, 0.3, 0.3], 1e-9));
    }

    #[test]
    fn is_valid_probability_vector_tolerance_works() {
        // Slight rounding error allowed under tolerance.
        assert!(is_valid_probability_vector(&[0.333, 0.333, 0.334], 1e-2));
    }

    #[test]
    fn is_valid_joint_distribution_2x2_uniform() {
        let joint = vec![vec![0.25, 0.25], vec![0.25, 0.25]];
        assert!(is_valid_joint_distribution(&joint, 1e-12));
    }

    #[test]
    fn is_valid_joint_distribution_rejects_non_square_when_inconsistent() {
        let joint = vec![vec![0.25, 0.25], vec![0.5]];
        assert!(!is_valid_joint_distribution(&joint, 1e-9));
    }

    #[test]
    fn is_valid_joint_distribution_rejects_empty() {
        let empty: Vec<Vec<f64>> = vec![];
        assert!(!is_valid_joint_distribution(&empty, 1e-9));
    }

    // ── iter-157: categorical_entropy_from_probs ──────────────────

    #[test]
    fn categorical_entropy_uniform_k_is_ln_k() {
        for k in [2_usize, 3, 5, 10] {
            let probs = vec![1.0 / k as f64; k];
            let h = categorical_entropy_from_probs(&probs);
            assert!((h - (k as f64).ln()).abs() < 1e-12);
        }
    }

    #[test]
    fn categorical_entropy_delta_is_zero() {
        let probs = vec![1.0, 0.0, 0.0, 0.0];
        let h = categorical_entropy_from_probs(&probs);
        assert_eq!(h, 0.0);
    }

    #[test]
    fn categorical_entropy_bounded_by_ln_n() {
        // H(P) ≤ ln(n) for n-state distribution; equality at uniform.
        let probs = vec![0.4, 0.3, 0.2, 0.1];
        let h = categorical_entropy_from_probs(&probs);
        let bound = 4.0_f64.ln();
        assert!(h <= bound + 1e-12);
        assert!(h > 0.0);
    }

    #[test]
    fn categorical_entropy_handles_zero_probs() {
        // 0·log(0) treated as 0 (entropy convention).
        let probs = vec![0.0, 0.5, 0.5];
        let h = categorical_entropy_from_probs(&probs);
        assert!((h - 2.0_f64.ln()).abs() < 1e-12);
    }

    // ── iter-177: joint_entropy + conditional_entropy ─────────────

    #[test]
    fn joint_entropy_uniform_2x2_is_ln_4() {
        let joint = vec![vec![0.25, 0.25], vec![0.25, 0.25]];
        let h = joint_entropy(&joint);
        assert!((h - 4.0_f64.ln()).abs() < 1e-12);
    }

    #[test]
    fn joint_entropy_delta_is_zero() {
        let joint = vec![vec![1.0, 0.0], vec![0.0, 0.0]];
        let h = joint_entropy(&joint);
        assert_eq!(h, 0.0);
    }

    #[test]
    fn conditional_entropy_independent_equals_marginal() {
        // X ⊥ Y → H(X|Y) = H(X).
        // Uniform 2×2: H(X) = ln 2; joint H = ln 4; marginal H(Y) = ln 2.
        // → H(X|Y) = ln 4 - ln 2 = ln 2. ✓
        let joint = vec![vec![0.25, 0.25], vec![0.25, 0.25]];
        let h_cond = conditional_entropy(&joint);
        assert!((h_cond - 2.0_f64.ln()).abs() < 1e-12);
    }

    #[test]
    fn conditional_entropy_deterministic_is_zero() {
        // X = Y (diagonal joint, uniform marginal).
        // H(X|Y) should be 0 (Y determines X).
        let joint = vec![vec![0.5, 0.0], vec![0.0, 0.5]];
        let h_cond = conditional_entropy(&joint);
        assert!(h_cond.abs() < 1e-12, "H(X|Y) = {}", h_cond);
    }

    // ── iter-152: mutual_information ──────────────────────────────

    #[test]
    fn mutual_information_independent_variables_is_zero() {
        // X and Y independent: joint = outer(p_x, p_y).
        // P(X=0)=0.5, P(X=1)=0.5; P(Y=0)=0.4, P(Y=1)=0.6.
        let joint = vec![
            vec![0.5 * 0.4, 0.5 * 0.6],
            vec![0.5 * 0.4, 0.5 * 0.6],
        ];
        let mi = mutual_information(&joint);
        assert!(mi.abs() < 1e-12, "I = {} should be 0", mi);
    }

    #[test]
    fn mutual_information_perfectly_correlated_is_h_x() {
        // Y = X: joint is diagonal. I(X;Y) = H(X).
        // Uniform 2-state X: H = ln 2.
        let joint = vec![
            vec![0.5, 0.0],
            vec![0.0, 0.5],
        ];
        let mi = mutual_information(&joint);
        assert!((mi - 2.0_f64.ln()).abs() < 1e-12);
    }

    #[test]
    fn mutual_information_non_negative() {
        // Random joint distribution: MI ≥ 0 always.
        let joint = vec![
            vec![0.1, 0.2, 0.05],
            vec![0.15, 0.1, 0.1],
            vec![0.05, 0.1, 0.15],
        ];
        let mi = mutual_information(&joint);
        assert!(mi >= -1e-12);
    }

    #[test]
    fn mutual_information_empty_or_negative_returns_nan() {
        let empty: Vec<Vec<f64>> = vec![];
        assert!(mutual_information(&empty).is_nan());

        let negative = vec![vec![0.5, -0.1], vec![0.3, 0.3]];
        assert!(mutual_information(&negative).is_nan());
    }

    // ── iter-148: gaussian_kl_full ────────────────────────────────

    #[test]
    fn gaussian_kl_full_same_dist_is_zero() {
        let kl = gaussian_kl_full(1.5, 2.0, 1.5, 2.0);
        assert!(kl.abs() < 1e-12);
    }

    #[test]
    fn gaussian_kl_full_same_variance_only_mean_diff() {
        // KL = 0.5 · (μ_1 - μ_2)² / σ².
        let kl = gaussian_kl_full(0.0, 1.0, 2.0, 1.0);
        assert!((kl - 2.0).abs() < 1e-12);
    }

    #[test]
    fn gaussian_kl_full_known_value_different_variances() {
        // KL(N(0, 1) || N(0, 4)):
        // = 0.5 · (log 4 + (1 + 0) / 4 - 1)
        // = 0.5 · (1.3863 + 0.25 - 1)
        // = 0.5 · 0.6363 = 0.31815...
        let kl = gaussian_kl_full(0.0, 1.0, 0.0, 4.0);
        let expected = 0.5 * (4.0_f64.ln() + 0.25 - 1.0);
        assert!((kl - expected).abs() < 1e-12);
    }

    #[test]
    fn gaussian_kl_full_non_negative() {
        // Gibbs inequality: KL ≥ 0.
        let cases = [
            (0.0_f64, 1.0, 0.0, 1.0),
            (1.0, 1.0, 2.0, 1.0),
            (0.0, 1.0, 1.0, 4.0),
            (-2.0, 0.5, 3.0, 2.0),
        ];
        for (mp, sp, mq, sq) in cases {
            let kl = gaussian_kl_full(mp, sp, mq, sq);
            assert!(kl >= -1e-12, "KL = {}", kl);
        }
    }

    #[test]
    fn gaussian_kl_full_asymmetric() {
        // KL(p || q) ≠ KL(q || p) when distributions differ.
        let pq = gaussian_kl_full(0.0, 1.0, 2.0, 4.0);
        let qp = gaussian_kl_full(2.0, 4.0, 0.0, 1.0);
        assert!((pq - qp).abs() > 0.1);
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
