//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.6.14 — Koopman lift consequences (B2-M8). SSM
//!   A-matrix as discrete-time Koopman operator (Wang-Liang MamKO
//!   ICLR 2025 spotlight, OpenReview hNjCVVm0EQ) + 4 mechanical
//!   consequences.
//! - Koopman, B. O., "Hamiltonian Systems and Transformations in
//!   Hilbert Space", PNAS 17(5), 1931 — the original lift.
//! - Bauer & Fike, "Norms and exclusion theorems", Numer. Math. 2,
//!   1960 — eigenvalue perturbation bound: for diagonalizable A,
//!   `min_λ |λ̂ − λ| ≤ κ_p(V) · ‖ΔA‖_p`.
//! - Helios v3.md Part VII.2 — Koopman reading of Pillar IV +
//!   Bauer-Fike-on-Babai composition of Pillars II + IV.
//!
//! # Wave J B.6.14 — Koopman lift substrate
//!
//! Four mechanical consequences (substrate floor enumerates + tests
//! the load-bearing math primitive — Bauer-Fike — that makes
//! consequence #2 sharp):
//!
//! 1. **Pillar IV unification** — Test-Time Regression's
//!    regressor-function-class = Koopman observable basis choice
//!    (already realized in [`super::test_time_regression`]).
//! 2. **WBO-6 quantization bound** — quantizing the SSM A-matrix
//!    shifts Koopman eigenvalues by at most `κ(V) · ‖ΔA‖` per
//!    Bauer-Fike. This module owns the bound + verifier.
//! 3. **Attention sinks Koopman-spectral** — sink modes are
//!    eigenvector tails of the attention-Koopman operator (Cancedda
//!    arXiv:2402.09221).
//! 4. **Titans = streaming DMD** — Titans' inner-loop rank-1 update
//!    IS a single-mode streaming DMD step on the LMM's Koopman
//!    operator (already realized in
//!    [`super::continual_learning::titans_mac`]).

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum KoopmanConsequence {
    PillarIvUnification,
    Wbo6QuantizationBound,
    AttentionSinksSpectral,
    TitansStreamingDmd,
}

impl KoopmanConsequence {
    pub const ALL: [KoopmanConsequence; 4] = [
        KoopmanConsequence::PillarIvUnification,
        KoopmanConsequence::Wbo6QuantizationBound,
        KoopmanConsequence::AttentionSinksSpectral,
        KoopmanConsequence::TitansStreamingDmd,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            KoopmanConsequence::PillarIvUnification => "pillar_iv_unification",
            KoopmanConsequence::Wbo6QuantizationBound => "wbo6_quant_bauer_fike",
            KoopmanConsequence::AttentionSinksSpectral => "attention_sinks_spectral",
            KoopmanConsequence::TitansStreamingDmd => "titans_streaming_dmd",
        }
    }

    /// Which sibling module realizes this consequence (per the
    /// substrate floor's current state).
    pub const fn realized_at(self) -> &'static str {
        match self {
            KoopmanConsequence::PillarIvUnification => {
                "agent_core/src/research/test_time_regression.rs"
            }
            KoopmanConsequence::Wbo6QuantizationBound => {
                "agent_core/src/research/koopman.rs"
            }
            KoopmanConsequence::AttentionSinksSpectral => {
                "agent_core/src/research/attention_sinks.rs"
            }
            KoopmanConsequence::TitansStreamingDmd => {
                "agent_core/src/research/continual_learning/titans_mac.rs"
            }
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|c| c.code() == code)
    }

    /// Predicate: this consequence is realized inside the koopman
    /// module itself (Wbo6QuantizationBound = the Bauer-Fike bound).
    /// The other three are realized in sibling modules. Cross-surface
    /// invariant: `is_internal()` iff `realized_at()` ends in
    /// `"koopman.rs"`.
    pub const fn is_internal(self) -> bool {
        matches!(self, KoopmanConsequence::Wbo6QuantizationBound)
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum KoopmanError {
    NonPositiveConditionNumber { kappa: f32 },
    NonPositivePerturbationNorm { norm: f32 },
    EmptySpectrum,
    NonFiniteMagnitude { index: usize, value: f32 },
    NegativeMagnitude { index: usize, value: f32 },
    SingularMatrix { min_magnitude: f32 },
}

impl KoopmanError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            KoopmanError::NonPositiveConditionNumber { .. } => "non_positive_condition_number",
            KoopmanError::NonPositivePerturbationNorm { .. } => "non_positive_perturbation_norm",
            KoopmanError::EmptySpectrum => "empty_spectrum",
            KoopmanError::NonFiniteMagnitude { .. } => "non_finite_magnitude",
            KoopmanError::NegativeMagnitude { .. } => "negative_magnitude",
            KoopmanError::SingularMatrix { .. } => "singular_matrix",
        }
    }

    /// Predicate: error pertains to Bauer-Fike parameter validation
    /// (NonPositiveConditionNumber / NonPositivePerturbationNorm).
    pub const fn is_bound_param_error(&self) -> bool {
        matches!(
            self,
            KoopmanError::NonPositiveConditionNumber { .. }
                | KoopmanError::NonPositivePerturbationNorm { .. }
        )
    }

    /// Predicate: error pertains to spectrum input validation
    /// (Empty / NonFinite / Negative / Singular).
    /// Cross-surface invariant: `is_bound_param_error XOR
    /// is_spectrum_error` partitions all 6 variants.
    pub const fn is_spectrum_error(&self) -> bool {
        matches!(
            self,
            KoopmanError::EmptySpectrum
                | KoopmanError::NonFiniteMagnitude { .. }
                | KoopmanError::NegativeMagnitude { .. }
                | KoopmanError::SingularMatrix { .. }
        )
    }
}

/// Predicate: the discrete-time Koopman operator (spectral magnitudes
/// given) is contractive — all eigenvalues strictly inside the unit
/// circle (|λ| < 1). The BIBO-stability check for SSM A-matrices:
/// `spectral_radius < 1.0` iff the recurrence damps perturbations
/// (no eigenmode grows under iteration).
///
/// Returns the same error variants as [`spectral_radius`] for
/// invalid input.
pub fn is_contractive(magnitudes: &[f32]) -> Result<bool, KoopmanError> {
    let r = spectral_radius(magnitudes)?;
    Ok(r < 1.0)
}

/// Predicate: the spectrum is well-conditioned at `threshold` — i.e.,
/// `condition_number_normal(mags) ≤ threshold`. Cross-surface
/// invariant: a true verdict means a Bauer-Fike bound at
/// `‖ΔA‖ = ε` produces a per-eigenvalue shift bound `≤ threshold · ε`.
///
/// Returns `Err` on invalid spectrum (same error set as
/// [`condition_number_normal`]). `threshold` ≤ 0 is treated as
/// "always fails" — returns `Ok(false)` without invoking the
/// condition-number computation.
pub fn is_well_conditioned(magnitudes: &[f32], threshold: f32) -> Result<bool, KoopmanError> {
    if !threshold.is_finite() || threshold <= 0.0 {
        return Ok(false);
    }
    let kappa = condition_number_normal(magnitudes)?;
    Ok(kappa <= threshold)
}

/// Bauer-Fike eigenvalue perturbation bound: for diagonalizable A,
/// every eigenvalue λ̂ of Â = A + E is within
/// `κ_p(V) · ‖E‖_p` of some eigenvalue λ of A.
///
/// Returns the bound; caller verifies actual `|λ̂ − λ| ≤ bound`.
pub fn bauer_fike_bound(condition_number: f32, perturbation_norm: f32) -> Result<f32, KoopmanError> {
    if condition_number <= 0.0 {
        return Err(KoopmanError::NonPositiveConditionNumber {
            kappa: condition_number,
        });
    }
    if perturbation_norm < 0.0 {
        return Err(KoopmanError::NonPositivePerturbationNorm {
            norm: perturbation_norm,
        });
    }
    Ok(condition_number * perturbation_norm)
}

/// Check whether the observed eigenvalue shift satisfies Bauer-Fike:
/// `|λ̂ − λ| ≤ κ · ‖ΔA‖`. Returns `Ok(true)` iff the bound holds.
pub fn verify_bauer_fike(
    observed_shift: f32,
    condition_number: f32,
    perturbation_norm: f32,
) -> Result<bool, KoopmanError> {
    let bound = bauer_fike_bound(condition_number, perturbation_norm)?;
    Ok(observed_shift.abs() <= bound + 1e-6)
}

/// Spectral radius: `max_i |λ_i|`. Caller supplies eigenvalue
/// magnitudes (the substrate-floor avoids a Complex type by working
/// with the modulus directly). Rejects empty input + non-finite +
/// negative magnitudes.
pub fn spectral_radius(magnitudes: &[f32]) -> Result<f32, KoopmanError> {
    if magnitudes.is_empty() {
        return Err(KoopmanError::EmptySpectrum);
    }
    let mut max: f32 = 0.0;
    for (i, &m) in magnitudes.iter().enumerate() {
        if !m.is_finite() {
            return Err(KoopmanError::NonFiniteMagnitude { index: i, value: m });
        }
        if m < 0.0 {
            return Err(KoopmanError::NegativeMagnitude { index: i, value: m });
        }
        if m > max {
            max = m;
        }
    }
    Ok(max)
}

/// 2-norm condition number for a normal matrix:
/// `κ₂(A) = max|λ| / min|λ|`. Pairs with [`bauer_fike_bound`] to
/// close the workflow "given eigenvalues, compute κ, apply
/// Bauer-Fike". Rejects empty input + non-finite + negative
/// magnitudes; rejects min == 0 as `SingularMatrix` (condition
/// number is +∞ for singular matrices and no useful bound follows).
pub fn condition_number_normal(magnitudes: &[f32]) -> Result<f32, KoopmanError> {
    if magnitudes.is_empty() {
        return Err(KoopmanError::EmptySpectrum);
    }
    let mut max: f32 = 0.0;
    let mut min: f32 = f32::INFINITY;
    for (i, &m) in magnitudes.iter().enumerate() {
        if !m.is_finite() {
            return Err(KoopmanError::NonFiniteMagnitude { index: i, value: m });
        }
        if m < 0.0 {
            return Err(KoopmanError::NegativeMagnitude { index: i, value: m });
        }
        if m > max {
            max = m;
        }
        if m < min {
            min = m;
        }
    }
    if min == 0.0 {
        return Err(KoopmanError::SingularMatrix { min_magnitude: min });
    }
    Ok(max / min)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn four_distinct_consequences() {
        let s: std::collections::HashSet<_> =
            KoopmanConsequence::ALL.iter().copied().collect();
        assert_eq!(s.len(), 4);
    }

    #[test]
    fn consequence_codes_stable() {
        assert_eq!(KoopmanConsequence::PillarIvUnification.code(), "pillar_iv_unification");
        assert_eq!(KoopmanConsequence::Wbo6QuantizationBound.code(), "wbo6_quant_bauer_fike");
        assert_eq!(KoopmanConsequence::AttentionSinksSpectral.code(), "attention_sinks_spectral");
        assert_eq!(KoopmanConsequence::TitansStreamingDmd.code(), "titans_streaming_dmd");
    }

    #[test]
    fn realized_at_points_to_sibling_modules() {
        assert!(KoopmanConsequence::PillarIvUnification
            .realized_at()
            .contains("test_time_regression.rs"));
        assert!(KoopmanConsequence::Wbo6QuantizationBound
            .realized_at()
            .contains("koopman.rs"));
        assert!(KoopmanConsequence::AttentionSinksSpectral
            .realized_at()
            .contains("attention_sinks.rs"));
        assert!(KoopmanConsequence::TitansStreamingDmd
            .realized_at()
            .contains("titans_mac.rs"));
    }

    #[test]
    fn bauer_fike_bound_basic_case() {
        let b = bauer_fike_bound(2.0, 0.1).unwrap();
        assert!((b - 0.2).abs() < 1e-6);
    }

    #[test]
    fn bauer_fike_unit_condition_number_gives_bound_equal_to_perturbation() {
        let b = bauer_fike_bound(1.0, 0.05).unwrap();
        assert!((b - 0.05).abs() < 1e-6);
    }

    #[test]
    fn bauer_fike_zero_perturbation_gives_zero_bound() {
        let b = bauer_fike_bound(5.0, 0.0).unwrap();
        assert!(b.abs() < 1e-6);
    }

    #[test]
    fn non_positive_condition_number_rejected() {
        let err = bauer_fike_bound(0.0, 0.1).unwrap_err();
        assert_eq!(err, KoopmanError::NonPositiveConditionNumber { kappa: 0.0 });
        let err = bauer_fike_bound(-1.0, 0.1).unwrap_err();
        assert_eq!(err, KoopmanError::NonPositiveConditionNumber { kappa: -1.0 });
    }

    #[test]
    fn negative_perturbation_norm_rejected() {
        let err = bauer_fike_bound(1.0, -0.1).unwrap_err();
        assert_eq!(err, KoopmanError::NonPositivePerturbationNorm { norm: -0.1 });
    }

    #[test]
    fn verify_within_bound_passes() {
        // shift = 0.05, kappa = 2, norm = 0.1 → bound = 0.2; 0.05 ≤ 0.2 ✓
        assert!(verify_bauer_fike(0.05, 2.0, 0.1).unwrap());
    }

    #[test]
    fn verify_exceeds_bound_fails() {
        // shift = 0.5, kappa = 2, norm = 0.1 → bound = 0.2; 0.5 > 0.2 ✗
        assert!(!verify_bauer_fike(0.5, 2.0, 0.1).unwrap());
    }

    #[test]
    fn verify_at_exactly_bound_passes() {
        // shift = 0.2, kappa = 2, norm = 0.1 → bound = 0.2; 0.2 ≤ 0.2 ✓
        assert!(verify_bauer_fike(0.2, 2.0, 0.1).unwrap());
    }

    #[test]
    fn verify_negative_shift_taken_as_abs() {
        assert!(verify_bauer_fike(-0.05, 2.0, 0.1).unwrap());
        assert!(!verify_bauer_fike(-0.5, 2.0, 0.1).unwrap());
    }

    #[test]
    fn high_condition_number_widens_bound() {
        let narrow = bauer_fike_bound(1.0, 0.1).unwrap();
        let wide = bauer_fike_bound(100.0, 0.1).unwrap();
        assert!(wide > narrow * 99.0);
    }

    #[test]
    fn consequence_serializes_through_serde_json() {
        let c = KoopmanConsequence::Wbo6QuantizationBound;
        let json = serde_json::to_string(&c).unwrap();
        let back: KoopmanConsequence = serde_json::from_str(&json).unwrap();
        assert_eq!(c, back);
    }

    // ── spectral_radius + condition_number_normal tests (iter 98) ───────────

    #[test]
    fn spectral_radius_empty_rejected() {
        assert_eq!(
            spectral_radius(&[]).unwrap_err(),
            KoopmanError::EmptySpectrum
        );
    }

    #[test]
    fn spectral_radius_picks_max_magnitude() {
        assert!((spectral_radius(&[0.5, 1.5, 0.8]).unwrap() - 1.5).abs() < 1e-6);
    }

    #[test]
    fn spectral_radius_single_element() {
        assert!((spectral_radius(&[3.14]).unwrap() - 3.14).abs() < 1e-6);
    }

    #[test]
    fn spectral_radius_all_zeros_returns_zero() {
        assert!((spectral_radius(&[0.0, 0.0, 0.0]).unwrap() - 0.0).abs() < 1e-12);
    }

    #[test]
    fn spectral_radius_nan_rejected() {
        assert!(matches!(
            spectral_radius(&[1.0, f32::NAN]).unwrap_err(),
            KoopmanError::NonFiniteMagnitude { .. }
        ));
    }

    #[test]
    fn spectral_radius_negative_rejected() {
        assert!(matches!(
            spectral_radius(&[1.0, -0.5]).unwrap_err(),
            KoopmanError::NegativeMagnitude { .. }
        ));
    }

    #[test]
    fn condition_number_normal_max_over_min() {
        assert!((condition_number_normal(&[1.0, 2.0, 5.0]).unwrap() - 5.0).abs() < 1e-6);
        assert!((condition_number_normal(&[0.5, 2.0]).unwrap() - 4.0).abs() < 1e-6);
    }

    #[test]
    fn condition_number_normal_singular_rejected() {
        assert!(matches!(
            condition_number_normal(&[0.0, 1.0]).unwrap_err(),
            KoopmanError::SingularMatrix { .. }
        ));
    }

    #[test]
    fn condition_number_normal_empty_rejected() {
        assert_eq!(
            condition_number_normal(&[]).unwrap_err(),
            KoopmanError::EmptySpectrum
        );
    }

    #[test]
    fn condition_number_normal_uniform_is_one() {
        assert!((condition_number_normal(&[2.0, 2.0, 2.0]).unwrap() - 1.0).abs() < 1e-6);
    }

    #[test]
    fn condition_number_feeds_bauer_fike_workflow() {
        // Eigenvalues → condition number → Bauer-Fike bound.
        let mags = vec![0.5_f32, 1.0, 1.5, 2.0];
        let kappa = condition_number_normal(&mags).unwrap();
        let bound = bauer_fike_bound(kappa, 0.01).unwrap();
        // κ = 4.0, ‖E‖ = 0.01, bound = 0.04.
        assert!((bound - 0.04).abs() < 1e-6);
    }

    // ── diagnostic surface (iter 165) ────────────────────────────────────────

    #[test]
    fn consequence_from_code_roundtrips_all() {
        for c in KoopmanConsequence::ALL.iter().copied() {
            assert_eq!(KoopmanConsequence::from_code(c.code()), Some(c));
        }
        assert_eq!(KoopmanConsequence::from_code("Wbo6QuantizationBound"), None);
        assert_eq!(KoopmanConsequence::from_code(""), None);
    }

    #[test]
    fn is_internal_only_for_wbo6() {
        // Cross-surface invariant: is_internal iff realized_at()
        // points to koopman.rs.
        for c in KoopmanConsequence::ALL.iter().copied() {
            let in_koopman = c.realized_at().ends_with("koopman.rs");
            assert_eq!(c.is_internal(), in_koopman);
        }
        assert!(KoopmanConsequence::Wbo6QuantizationBound.is_internal());
        assert!(!KoopmanConsequence::PillarIvUnification.is_internal());
        assert!(!KoopmanConsequence::AttentionSinksSpectral.is_internal());
        assert!(!KoopmanConsequence::TitansStreamingDmd.is_internal());
    }

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [
            KoopmanError::NonPositiveConditionNumber { kappa: 0.0 },
            KoopmanError::NonPositivePerturbationNorm { norm: 0.0 },
            KoopmanError::EmptySpectrum,
            KoopmanError::NonFiniteMagnitude { index: 0, value: f32::NAN },
            KoopmanError::NegativeMagnitude { index: 0, value: -1.0 },
            KoopmanError::SingularMatrix { min_magnitude: 0.0 },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 6);
    }

    #[test]
    fn error_classifiers_partition_variants() {
        let variants = [
            KoopmanError::NonPositiveConditionNumber { kappa: 0.0 },
            KoopmanError::NonPositivePerturbationNorm { norm: 0.0 },
            KoopmanError::EmptySpectrum,
            KoopmanError::NonFiniteMagnitude { index: 0, value: f32::NAN },
            KoopmanError::NegativeMagnitude { index: 0, value: -1.0 },
            KoopmanError::SingularMatrix { min_magnitude: 0.0 },
        ];
        // Cross-surface invariant: is_bound_param_error XOR is_spectrum_error.
        for e in variants {
            assert_ne!(e.is_bound_param_error(), e.is_spectrum_error());
        }
        // 2 bound-param errors + 4 spectrum errors.
        assert_eq!(variants.iter().filter(|e| e.is_bound_param_error()).count(), 2);
        assert_eq!(variants.iter().filter(|e| e.is_spectrum_error()).count(), 4);
    }

    #[test]
    fn is_contractive_true_when_radius_below_one() {
        // Cross-surface invariant: is_contractive iff spectral_radius < 1.
        let mags = vec![0.3_f32, 0.7, 0.5];
        assert!(is_contractive(&mags).unwrap());
        assert!(spectral_radius(&mags).unwrap() < 1.0);
    }

    #[test]
    fn is_contractive_false_when_radius_at_or_above_one() {
        // Eigenvalue at exactly 1.0 is NOT strictly contractive.
        assert!(!is_contractive(&[0.5, 1.0]).unwrap());
        assert!(!is_contractive(&[0.5, 1.5]).unwrap());
    }

    #[test]
    fn is_contractive_propagates_spectrum_errors() {
        assert!(matches!(
            is_contractive(&[]).unwrap_err(),
            KoopmanError::EmptySpectrum
        ));
        assert!(matches!(
            is_contractive(&[1.0, -0.5]).unwrap_err(),
            KoopmanError::NegativeMagnitude { .. }
        ));
    }

    #[test]
    fn is_well_conditioned_matches_condition_number_threshold() {
        // Cross-surface invariant: when valid, is_well_conditioned(m, t)
        // iff condition_number_normal(m) ≤ t.
        let mags = vec![0.5_f32, 1.0, 1.5, 2.0]; // κ = 4.0
        let kappa = condition_number_normal(&mags).unwrap();
        for &t in &[1.0_f32, 3.0, 4.0, 4.5, 10.0] {
            assert_eq!(is_well_conditioned(&mags, t).unwrap(), kappa <= t, "t={}", t);
        }
    }

    #[test]
    fn is_well_conditioned_non_positive_threshold_always_false() {
        let mags = vec![1.0_f32, 1.0];
        // threshold ≤ 0 → false without computing kappa.
        assert!(!is_well_conditioned(&mags, 0.0).unwrap());
        assert!(!is_well_conditioned(&mags, -1.0).unwrap());
        assert!(!is_well_conditioned(&mags, f32::NAN).unwrap());
    }

    #[test]
    fn is_well_conditioned_propagates_singular_error() {
        // Singular matrix → SingularMatrix error (kappa undefined).
        assert!(matches!(
            is_well_conditioned(&[0.0, 1.0], 100.0).unwrap_err(),
            KoopmanError::SingularMatrix { .. }
        ));
    }
}
