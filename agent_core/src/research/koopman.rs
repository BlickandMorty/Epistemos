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
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum KoopmanError {
    NonPositiveConditionNumber { kappa: f32 },
    NonPositivePerturbationNorm { norm: f32 },
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
}
