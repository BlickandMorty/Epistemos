//! Source:
//! - `~/Documents/Epistemos-QuickCapture/FINAL_SYNTHESIS.md` §5.4
//!   lines 446-461 — canonical formula:
//!     `sensitivity = 1.0`
//!     `scale = sensitivity / epsilon`
//!     `noisy_mean = mean(values) + Laplace(0, scale)`
//! - `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.42 — the
//!   ε ≤ 0.5 budget pin and "what gets noised vs plaintext" table.
//! - Dwork et al., TCC 2006 — Laplace mechanism: privacy loss bounded
//!   by ε iff noise scale is at least Δ/ε where Δ is the L1
//!   sensitivity of the query.
//! - Dwork-Roth, "The Algorithmic Foundations of Differential
//!   Privacy", 2014 — §3.4 parallel composition.
//!
//! # B2-M14 — Laplace differential-privacy gate
//!
//! `dp_aggregate(values, epsilon, &mut sampler)` returns the mean of
//! `values` plus a Laplace noise sample with scale `sensitivity /
//! epsilon`. Substrate-floor `sensitivity = 1.0` per §3.42 doctrine
//! (counting per record).
//!
//! ## Noise source
//!
//! The substrate ships two `LaplaceSampler` implementations:
//!
//! - [`ZeroNoiseSampler`] — always returns 0. Useful as a sentinel
//!   "noise disabled" mode for golden-master testing of the
//!   non-noise math, and as the safe default the report dispatcher
//!   falls back to if no sampler is configured (callers MUST opt
//!   into a real sampler before shipping to the user).
//! - [`DeterministicLcgSampler`] — seeded linear-congruential-generator
//!   PRNG fed through Laplace inverse-CDF. Deterministic per seed
//!   (reproducible for tests + audit replay), Laplace-distributed in
//!   the limit. Production calls a cryptographically-secure RNG (the
//!   `rand` crate's `OsRng`) instead — that lands behind the same
//!   trait once the crate dep is added.
//!
//! ## Budget enforcement
//!
//! `dp_aggregate` REJECTS `epsilon > DP_EPSILON_MAX = 0.5`. The
//! doctrine bound is strict: aggregate report output without
//! `dp_aggregate(_, ε ≤ 0.5)` fails the PR-discipline gate per §3.42.

pub const DP_EPSILON_MAX: f64 = 0.5;
pub const DEFAULT_SENSITIVITY: f64 = 1.0;

/// Sample from a Laplace distribution with location 0 and the given
/// scale parameter `b`. Implementations may be deterministic
/// (test/replay) or stochastic (production); both must produce
/// Laplace-distributed output in the limit.
pub trait LaplaceSampler {
    fn sample(&mut self, scale: f64) -> f64;
}

/// Deterministic sampler that always returns 0. Useful for golden-
/// master tests of the mean-arithmetic path and as a safe "no-op"
/// sentinel. Callers MUST swap to a real sampler before producing
/// a user-facing report.
#[derive(Clone, Copy, Debug, Default)]
pub struct ZeroNoiseSampler;

impl LaplaceSampler for ZeroNoiseSampler {
    fn sample(&mut self, _scale: f64) -> f64 {
        0.0
    }
}

/// Seeded LCG-driven Laplace sampler. Deterministic per `seed` —
/// reproducible for tests + audit replay. NOT cryptographically
/// secure: production replaces with `OsRng`-fed Laplace inverse-CDF
/// once `rand` is added as a dependency, behind the same trait.
#[derive(Clone, Copy, Debug)]
pub struct DeterministicLcgSampler {
    state: u64,
}

impl DeterministicLcgSampler {
    pub fn new(seed: u64) -> Self {
        Self { state: seed.wrapping_add(0x9E37_79B9_7F4A_7C15) }
    }

    fn next_u01(&mut self) -> f64 {
        // Numerical Recipes LCG: a=1664525, c=1013904223.
        self.state = self
            .state
            .wrapping_mul(1_664_525)
            .wrapping_add(1_013_904_223);
        // Use upper 53 bits for fp64 precision; force into (0, 1)
        // open interval so ln(1 - 2|u-0.5|) never sees ±1.
        let raw = (self.state >> 11) as f64;
        let u = (raw + 0.5) / ((1u64 << 53) as f64);
        u.clamp(f64::EPSILON, 1.0 - f64::EPSILON)
    }
}

impl LaplaceSampler for DeterministicLcgSampler {
    fn sample(&mut self, scale: f64) -> f64 {
        let u = self.next_u01();
        // Laplace inverse CDF: x = -b · sign(u - 0.5) · ln(1 - 2|u - 0.5|)
        let centered = u - 0.5;
        let sign = if centered >= 0.0 { 1.0 } else { -1.0 };
        let inner = 1.0 - 2.0 * centered.abs();
        -scale * sign * inner.ln()
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum DpError {
    EmptyInput,
    EpsilonOutOfRange { epsilon: f64, max: f64 },
    NonFinite,
}

impl DpError {
    /// Stable identifier for the failure cause. Used by telemetry that
    /// wants a wire-form string instead of the Debug formatter.
    pub const fn cause(&self) -> &'static str {
        match self {
            DpError::EmptyInput => "empty_input",
            DpError::EpsilonOutOfRange { .. } => "epsilon_out_of_range",
            DpError::NonFinite => "non_finite",
        }
    }

    pub const fn is_empty_input(&self) -> bool {
        matches!(self, DpError::EmptyInput)
    }

    pub const fn is_epsilon_out_of_range(&self) -> bool {
        matches!(self, DpError::EpsilonOutOfRange { .. })
    }

    pub const fn is_non_finite(&self) -> bool {
        matches!(self, DpError::NonFinite)
    }
}

/// Predicate: `epsilon` is in the doctrine-allowed range
/// `(0.0, DP_EPSILON_MAX]`. Companion to the validation branch in
/// [`dp_aggregate`]. Cross-surface invariant:
/// `is_valid_epsilon(eps) iff dp_aggregate(non_empty, eps, sampler)`
/// does NOT return [`DpError::EpsilonOutOfRange`].
pub fn is_valid_epsilon(epsilon: f64) -> bool {
    epsilon.is_finite() && epsilon > 0.0 && epsilon <= DP_EPSILON_MAX
}

/// Canonical Laplace noise scale `sensitivity / epsilon` for the
/// substrate-floor `sensitivity = 1.0`. Errors out-of-range epsilon
/// with the same variant `dp_aggregate` uses. Useful for callers
/// that want to size a noise budget without invoking the sampler.
pub fn noise_scale(epsilon: f64) -> Result<f64, DpError> {
    if !is_valid_epsilon(epsilon) {
        return Err(DpError::EpsilonOutOfRange {
            epsilon,
            max: DP_EPSILON_MAX,
        });
    }
    Ok(DEFAULT_SENSITIVITY / epsilon)
}

/// Aggregate `values` with mean + Laplace noise. Returns the noisy
/// mean, or a typed error.
///
/// - Rejects empty `values` (no mean to noise).
/// - Rejects `epsilon ≤ 0.0` or `epsilon > DP_EPSILON_MAX` per §3.42.
/// - Rejects any non-finite input value (NaN / inf).
///
/// Sensitivity is the §3.42 default `1.0` (counting per record).
/// Noise scale is `sensitivity / epsilon`.
pub fn dp_aggregate<S: LaplaceSampler>(
    values: &[f64],
    epsilon: f64,
    sampler: &mut S,
) -> Result<f64, DpError> {
    if values.is_empty() {
        return Err(DpError::EmptyInput);
    }
    if !epsilon.is_finite() || epsilon <= 0.0 || epsilon > DP_EPSILON_MAX {
        return Err(DpError::EpsilonOutOfRange {
            epsilon,
            max: DP_EPSILON_MAX,
        });
    }
    let mut sum = 0.0_f64;
    for &v in values {
        if !v.is_finite() {
            return Err(DpError::NonFinite);
        }
        sum += v;
    }
    let mean = sum / values.len() as f64;
    let scale = DEFAULT_SENSITIVITY / epsilon;
    let noisy = mean + sampler.sample(scale);
    if !noisy.is_finite() {
        return Err(DpError::NonFinite);
    }
    Ok(noisy)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dp_epsilon_max_pinned_at_half() {
        assert_eq!(DP_EPSILON_MAX, 0.5);
    }

    #[test]
    fn default_sensitivity_is_one() {
        assert_eq!(DEFAULT_SENSITIVITY, 1.0);
    }

    #[test]
    fn zero_noise_returns_exact_mean() {
        let mut s = ZeroNoiseSampler;
        let r = dp_aggregate(&[1.0, 2.0, 3.0], 0.5, &mut s).unwrap();
        assert!((r - 2.0).abs() < 1e-12);
    }

    #[test]
    fn empty_input_rejected() {
        let mut s = ZeroNoiseSampler;
        assert_eq!(dp_aggregate(&[], 0.5, &mut s).unwrap_err(), DpError::EmptyInput);
    }

    #[test]
    fn epsilon_above_doctrine_max_rejected() {
        let mut s = ZeroNoiseSampler;
        let err = dp_aggregate(&[1.0], 0.6, &mut s).unwrap_err();
        assert!(matches!(err, DpError::EpsilonOutOfRange { .. }));
    }

    #[test]
    fn epsilon_zero_rejected() {
        let mut s = ZeroNoiseSampler;
        let err = dp_aggregate(&[1.0], 0.0, &mut s).unwrap_err();
        assert!(matches!(err, DpError::EpsilonOutOfRange { .. }));
    }

    #[test]
    fn epsilon_negative_rejected() {
        let mut s = ZeroNoiseSampler;
        let err = dp_aggregate(&[1.0], -0.1, &mut s).unwrap_err();
        assert!(matches!(err, DpError::EpsilonOutOfRange { .. }));
    }

    #[test]
    fn epsilon_nan_rejected() {
        let mut s = ZeroNoiseSampler;
        let err = dp_aggregate(&[1.0], f64::NAN, &mut s).unwrap_err();
        assert!(matches!(err, DpError::EpsilonOutOfRange { .. }));
    }

    #[test]
    fn nan_value_rejected() {
        let mut s = ZeroNoiseSampler;
        let err = dp_aggregate(&[1.0, f64::NAN], 0.5, &mut s).unwrap_err();
        assert_eq!(err, DpError::NonFinite);
    }

    #[test]
    fn inf_value_rejected() {
        let mut s = ZeroNoiseSampler;
        let err = dp_aggregate(&[1.0, f64::INFINITY], 0.5, &mut s).unwrap_err();
        assert_eq!(err, DpError::NonFinite);
    }

    #[test]
    fn lcg_sampler_is_deterministic_per_seed() {
        let mut a = DeterministicLcgSampler::new(42);
        let mut b = DeterministicLcgSampler::new(42);
        for _ in 0..100 {
            let x = a.sample(1.0);
            let y = b.sample(1.0);
            assert!((x - y).abs() < 1e-12);
        }
    }

    #[test]
    fn lcg_sampler_different_seeds_diverge() {
        let mut a = DeterministicLcgSampler::new(1);
        let mut b = DeterministicLcgSampler::new(2);
        let mut diff_count = 0;
        for _ in 0..20 {
            let x = a.sample(1.0);
            let y = b.sample(1.0);
            if (x - y).abs() > 1e-6 {
                diff_count += 1;
            }
        }
        // With distinct seeds nearly every sample should differ.
        assert!(diff_count >= 15, "diff_count = {}", diff_count);
    }

    #[test]
    fn lcg_sampler_mean_converges_toward_zero() {
        // Laplace(0, b) has mean 0. Over a long sequence the empirical
        // mean should be close to 0. Tolerance is wide because LCG +
        // 1000 samples is not a tight estimator; we just want to
        // catch a sampler that's biased by orders of magnitude.
        let mut s = DeterministicLcgSampler::new(7);
        let n = 5_000usize;
        let total: f64 = (0..n).map(|_| s.sample(1.0)).sum();
        let mean = total / n as f64;
        assert!(mean.abs() < 0.2, "empirical mean was {}", mean);
    }

    #[test]
    fn dp_aggregate_with_lcg_perturbs_the_mean() {
        // True mean of [10, 10, 10, 10] is 10.0. With non-zero noise
        // at scale 1/0.5 = 2.0, the noisy result should differ from
        // 10.0 (with overwhelming probability) on the LCG-deterministic
        // sample sequence.
        let mut s = DeterministicLcgSampler::new(123);
        let noisy = dp_aggregate(&[10.0, 10.0, 10.0, 10.0], 0.5, &mut s).unwrap();
        assert!((noisy - 10.0).abs() > 1e-6, "noisy was {}", noisy);
        // But still within a sensible envelope (Laplace at scale 2 puts
        // ~99% mass within ±10 of the location).
        assert!((noisy - 10.0).abs() < 30.0);
    }

    #[test]
    fn dp_aggregate_reproducible_with_same_seed() {
        let mut s1 = DeterministicLcgSampler::new(99);
        let mut s2 = DeterministicLcgSampler::new(99);
        let r1 = dp_aggregate(&[1.0, 2.0, 3.0], 0.5, &mut s1).unwrap();
        let r2 = dp_aggregate(&[1.0, 2.0, 3.0], 0.5, &mut s2).unwrap();
        assert!((r1 - r2).abs() < 1e-12);
    }

    #[test]
    fn epsilon_at_doctrine_floor_accepted() {
        let mut s = ZeroNoiseSampler;
        // ε at the exact upper bound 0.5 must be accepted; the
        // doctrine says "ε ≤ 0.5" not "ε < 0.5".
        assert!(dp_aggregate(&[1.0], 0.5, &mut s).is_ok());
    }

    // ── diagnostic surface (iter 149) ────────────────────────────────────────

    #[test]
    fn is_valid_epsilon_accepts_in_range() {
        assert!(is_valid_epsilon(0.1));
        assert!(is_valid_epsilon(0.5));
        assert!(is_valid_epsilon(0.001));
    }

    #[test]
    fn is_valid_epsilon_rejects_out_of_range() {
        assert!(!is_valid_epsilon(0.0));
        assert!(!is_valid_epsilon(-0.1));
        assert!(!is_valid_epsilon(0.6));
        assert!(!is_valid_epsilon(1.0));
        assert!(!is_valid_epsilon(f64::NAN));
        assert!(!is_valid_epsilon(f64::INFINITY));
    }

    #[test]
    fn is_valid_epsilon_aligns_with_dp_aggregate_rejection() {
        // Cross-surface invariant: is_valid_epsilon(eps) iff
        // dp_aggregate(non-empty, eps, sampler) does NOT return
        // EpsilonOutOfRange. (It may still return other errors —
        // here we test with a valid non-empty input so only the
        // epsilon branch decides.)
        let mut s = ZeroNoiseSampler;
        for &eps in &[0.0, 0.1, 0.5, 0.6, -0.1, f64::NAN] {
            let valid = is_valid_epsilon(eps);
            let result = dp_aggregate(&[1.0], eps, &mut s);
            match result {
                Ok(_) => assert!(valid, "eps={} dp_aggregate ok but not valid", eps),
                Err(DpError::EpsilonOutOfRange { .. }) => assert!(!valid, "eps={}", eps),
                Err(other) => panic!("unexpected error: {:?}", other),
            }
        }
    }

    #[test]
    fn noise_scale_returns_one_over_epsilon_for_default_sensitivity() {
        let s = noise_scale(0.5).unwrap();
        assert!((s - 2.0).abs() < 1e-12); // 1.0 / 0.5 = 2.0
        let s = noise_scale(0.1).unwrap();
        assert!((s - 10.0).abs() < 1e-12); // 1.0 / 0.1 = 10.0
    }

    #[test]
    fn noise_scale_rejects_invalid_epsilon() {
        // Cross-surface invariant: noise_scale errors iff
        // !is_valid_epsilon(eps).
        for &eps in &[0.0, -1.0, 0.6, f64::NAN, f64::INFINITY] {
            assert!(noise_scale(eps).is_err(), "eps={}", eps);
            assert!(!is_valid_epsilon(eps), "eps={}", eps);
        }
    }

    #[test]
    fn error_cause_returns_distinct_per_variant() {
        let empties: std::collections::HashSet<_> = [
            DpError::EmptyInput,
            DpError::EpsilonOutOfRange { epsilon: 1.0, max: 0.5 },
            DpError::NonFinite,
        ]
        .iter()
        .map(|e| e.cause())
        .collect();
        assert_eq!(empties.len(), 3);
    }

    #[test]
    fn error_classifier_predicates_partition() {
        let variants = [
            DpError::EmptyInput,
            DpError::EpsilonOutOfRange { epsilon: 1.0, max: 0.5 },
            DpError::NonFinite,
        ];
        // Cross-surface invariant: exactly one of the three predicates
        // is true for every variant.
        for v in &variants {
            let trio = [v.is_empty_input(), v.is_epsilon_out_of_range(), v.is_non_finite()];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", v);
        }
    }

    #[test]
    fn error_from_real_aggregate_carries_correct_cause() {
        // Cross-surface: dp_aggregate-returned errors get matching cause().
        let mut s = ZeroNoiseSampler;
        let err = dp_aggregate(&[], 0.5, &mut s).unwrap_err();
        assert_eq!(err.cause(), "empty_input");
        assert!(err.is_empty_input());

        let err = dp_aggregate(&[1.0], 0.6, &mut s).unwrap_err();
        assert_eq!(err.cause(), "epsilon_out_of_range");
        assert!(err.is_epsilon_out_of_range());

        let err = dp_aggregate(&[1.0, f64::NAN], 0.5, &mut s).unwrap_err();
        assert_eq!(err.cause(), "non_finite");
        assert!(err.is_non_finite());
    }
}
