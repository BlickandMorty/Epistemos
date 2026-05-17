//! Source:
//! - `docs/fusion/EML_INTEGRATION_DOCTRINE_2026_05_17.md` §3.3 — the
//!   SAE Cognition Observatory MVP integration site (the no-coord
//!   default per the T7 prompt's PHASES section).
//! - Companion (read-only consumer):
//!   `agent_core/src/research/cognition_observatory/sae.rs` — supplies
//!   `LabeledScore` + `auc_roc` (Hanley & McNeil 1982 rank-based form).
//! - Companion (encoding primitive): [`super::potential::EmlPotential`].
//!
//! # SAE-score augmentation via EML potential
//!
//! The §4.B prompt asks: "energy as anomaly signal." This module is
//! the runtime adapter that turns that phrase into a concrete,
//! property-test-backed operation: take a slice of `LabeledScore`
//! observations from the SAE Cognition Observatory and produce an
//! augmented view where each raw score `s` carries a paired EML
//! potential value (the monotone-encoded `(1+s) − ln(1+s)`).
//!
//! ## The AUC-preserving cornerstone (doctrine §3.3 + §5)
//!
//! Because the EML potential is a strictly monotone-increasing
//! function of `s` (proof: derivative `1 − 1/(1+s) > 0` for `s > 0`;
//! pinned by `potential::tests::monotone_in_score_across_grid`), the
//! rank-based AUC formula in `sae::auc_roc` (Hanley & McNeil 1982;
//! `sae.rs:144-201`) returns the **same value** when applied to the
//! augmented scores as when applied to the raw scores — modulo the
//! f32 cast at the LabeledScore boundary, which is bounded by an
//! `< 1e-6` tolerance for SAE scores in `[0, 1]` (the typical range).
//!
//! This is the cornerstone integration claim. Pinned by
//! [`tests::auc_on_augmented_matches_auc_on_raw_within_eps`].
//!
//! ## Read-only consumer discipline
//!
//! Per §0 rule 1 (NEVER delete a feature) + §B.4 (additive only) +
//! the T7 SCOPE LOCK (`cognition_observatory/sae.rs` is NOT in T7's
//! write scope), this module **only reads** from `sae`. It does not
//! modify `LabeledScore`, `SaeVerdict`, or any other sae surface.
//! The augmentation is composed externally and re-fed into the
//! existing `auc_roc` entry point.

use super::super::cognition_observatory::sae::{auc_roc, LabeledScore, SaeAucError};
use super::potential::{EmlPotential, EmlPotentialError};

/// A single SAE observation augmented with its EML potential.
/// Carries the raw score, the deterministic potential, and the
/// label, so callers can A/B raw-vs-augmented behavior without
/// losing provenance.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct AugmentedObservation {
    pub raw_score: f32,
    pub potential: EmlPotential,
    pub is_hallucination: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum AugmentError {
    /// Score-to-potential encoding rejected (negative, non-finite,
    /// or eml-operator-rejected). Carries the index and inner error
    /// for actionable diagnosis.
    Potential { index: usize, source: EmlPotentialError },
    /// The augmented observations failed the AUC precondition
    /// (empty / single-class / non-finite). Forwarded from sae.
    Auc(SaeAucError),
}

impl From<SaeAucError> for AugmentError {
    fn from(e: SaeAucError) -> Self {
        AugmentError::Auc(e)
    }
}

/// Augment every observation with its EML potential. Preserves order,
/// label, and count. Errors on first invalid score with index for
/// diagnostic.
pub fn augment(
    observations: &[LabeledScore],
) -> Result<Vec<AugmentedObservation>, AugmentError> {
    let mut out = Vec::with_capacity(observations.len());
    for (i, obs) in observations.iter().enumerate() {
        let potential = EmlPotential::from_score(obs.score as f64)
            .map_err(|source| AugmentError::Potential { index: i, source })?;
        out.push(AugmentedObservation {
            raw_score: obs.score,
            potential,
            is_hallucination: obs.is_hallucination,
        });
    }
    Ok(out)
}

/// Run the rank-based AUC over the augmented potential values. By the
/// strict-monotonicity of [`EmlPotential::from_score`], this equals
/// the AUC over the raw scores (up to the f32 cast at the LabeledScore
/// boundary). The cornerstone of the §4.B MVP integration.
pub fn auc_on_augmented(observations: &[LabeledScore]) -> Result<f32, AugmentError> {
    let augmented = augment(observations)?;
    let relabeled: Vec<LabeledScore> = augmented
        .iter()
        .map(|a| LabeledScore {
            score: a.potential.value() as f32,
            is_hallucination: a.is_hallucination,
        })
        .collect();
    auc_roc(&relabeled).map_err(AugmentError::Auc)
}

/// Aggregate summary of EML-potential values across a slice of
/// augmented observations. Useful for the diagnostic surface (next
/// to the per-call live readout) and for downstream telemetry that
/// wants a one-shot signal rather than the full vector.
///
/// `None`-typed fields signal "no observations to aggregate" rather
/// than zeroing out — keeps the empty case typed and avoids silently
/// pinning min/max/mean to 0.0 on empty input.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct AugmentedSummary {
    pub count: usize,
    pub positives: usize,
    pub negatives: usize,
    pub min_potential: Option<f64>,
    pub max_potential: Option<f64>,
    pub mean_potential: Option<f64>,
}

impl AugmentedSummary {
    /// Range of the potential values: `max − min`. `None` when there
    /// were no observations.
    pub fn potential_range(&self) -> Option<f64> {
        match (self.min_potential, self.max_potential) {
            (Some(min), Some(max)) => Some(max - min),
            _ => None,
        }
    }

    /// Positive-class fraction. `None` on empty input (rate
    /// undefined). Matches the shape of
    /// `cognition_observatory::sae::ClassBalance::positive_rate`.
    pub fn positive_rate(&self) -> Option<f32> {
        if self.count == 0 {
            return None;
        }
        Some(self.positives as f32 / self.count as f32)
    }
}

/// Compute the aggregate summary across the augmented observations.
/// Single-pass over the input; O(n) time, O(1) extra space.
pub fn summarize(
    observations: &[LabeledScore],
) -> Result<AugmentedSummary, AugmentError> {
    let augmented = augment(observations)?;
    let count = augmented.len();
    if count == 0 {
        return Ok(AugmentedSummary {
            count: 0,
            positives: 0,
            negatives: 0,
            min_potential: None,
            max_potential: None,
            mean_potential: None,
        });
    }
    let mut positives = 0_usize;
    let mut sum = 0.0_f64;
    let mut min = f64::INFINITY;
    let mut max = f64::NEG_INFINITY;
    for a in &augmented {
        let v = a.potential.value();
        if a.is_hallucination {
            positives += 1;
        }
        if v < min {
            min = v;
        }
        if v > max {
            max = v;
        }
        sum += v;
    }
    Ok(AugmentedSummary {
        count,
        positives,
        negatives: count - positives,
        min_potential: Some(min),
        max_potential: Some(max),
        mean_potential: Some(sum / count as f64),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn obs(score: f32, is_hallucination: bool) -> LabeledScore {
        LabeledScore { score, is_hallucination }
    }

    fn approx(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn augment_preserves_observation_count() {
        let v = vec![obs(0.1, false), obs(0.5, true), obs(0.9, true)];
        let out = augment(&v).unwrap();
        assert_eq!(out.len(), v.len());
    }

    #[test]
    fn augment_preserves_labels_in_order() {
        let v = vec![obs(0.1, false), obs(0.5, true), obs(0.9, false)];
        let out = augment(&v).unwrap();
        for (a, b) in out.iter().zip(v.iter()) {
            assert_eq!(a.is_hallucination, b.is_hallucination);
        }
    }

    #[test]
    fn augment_preserves_raw_score() {
        let v = vec![obs(0.1, false), obs(0.5, true), obs(0.9, false)];
        let out = augment(&v).unwrap();
        for (a, b) in out.iter().zip(v.iter()) {
            assert!(approx(a.raw_score, b.score, 1e-12));
        }
    }

    #[test]
    fn augment_potential_value_is_above_one_for_positive_score() {
        let v = vec![obs(0.01, true), obs(0.5, false), obs(1.0, true)];
        let out = augment(&v).unwrap();
        for a in &out {
            assert!(a.potential.value() > 1.0, "potential {} ≤ 1.0", a.potential.value());
        }
    }

    #[test]
    fn augment_potential_value_is_exactly_one_at_zero() {
        let v = vec![obs(0.0, false)];
        let out = augment(&v).unwrap();
        assert!((out[0].potential.value() - 1.0).abs() < 1e-12);
    }

    #[test]
    fn augment_monotone_in_raw_score() {
        let v = vec![obs(0.1, true), obs(0.3, false), obs(0.5, true), obs(0.9, false)];
        let out = augment(&v).unwrap();
        // Sort by raw score, check potentials are also sorted.
        let mut pairs: Vec<(f32, f64)> =
            out.iter().map(|a| (a.raw_score, a.potential.value())).collect();
        pairs.sort_by(|x, y| x.0.partial_cmp(&y.0).unwrap());
        for w in pairs.windows(2) {
            assert!(w[0].1 < w[1].1, "non-monotone: {:?}", pairs);
        }
    }

    #[test]
    fn augment_deterministic_repeat() {
        let v = vec![obs(0.1, true), obs(0.5, false)];
        let a1 = augment(&v).unwrap();
        let a2 = augment(&v).unwrap();
        assert_eq!(a1, a2);
    }

    #[test]
    fn augment_rejects_negative_score_with_index() {
        let v = vec![obs(0.1, true), obs(-0.5, false), obs(0.9, true)];
        let err = augment(&v).unwrap_err();
        match err {
            AugmentError::Potential { index, source } => {
                assert_eq!(index, 1);
                assert!(matches!(source, EmlPotentialError::NegativeScore { .. }));
            }
            other => panic!("expected Potential, got {:?}", other),
        }
    }

    #[test]
    fn augment_rejects_nan_score_with_index() {
        let v = vec![obs(f32::NAN, true), obs(0.5, false)];
        let err = augment(&v).unwrap_err();
        match err {
            AugmentError::Potential { index, source } => {
                assert_eq!(index, 0);
                assert!(matches!(source, EmlPotentialError::NonFiniteScore { .. }));
            }
            other => panic!("expected Potential, got {:?}", other),
        }
    }

    #[test]
    fn augment_on_empty_returns_empty() {
        let out = augment(&[]).unwrap();
        assert!(out.is_empty());
    }

    #[test]
    fn auc_on_augmented_matches_auc_on_raw_within_eps() {
        // Cornerstone: rank-based AUC is invariant under strictly
        // monotone score transforms. EML potential is strictly
        // monotone-increasing in s. So both AUCs must match within
        // float tolerance.
        let v = vec![
            obs(0.05, false),
            obs(0.10, false),
            obs(0.15, false),
            obs(0.20, false),
            obs(0.21, true),
            obs(0.85, true),
            obs(0.90, true),
            obs(0.95, true),
        ];
        let raw_auc = auc_roc(&v).unwrap();
        let aug_auc = auc_on_augmented(&v).unwrap();
        assert!(approx(raw_auc, aug_auc, 1e-5),
            "raw_auc={} aug_auc={}", raw_auc, aug_auc);
    }

    #[test]
    fn auc_on_augmented_perfect_separation_is_one() {
        let v = vec![
            obs(0.1, false),
            obs(0.2, false),
            obs(0.8, true),
            obs(0.9, true),
        ];
        let aug_auc = auc_on_augmented(&v).unwrap();
        assert!((aug_auc - 1.0).abs() < 1e-5);
    }

    #[test]
    fn auc_on_augmented_perfectly_inverted_is_zero() {
        let v = vec![
            obs(0.1, true),
            obs(0.2, true),
            obs(0.8, false),
            obs(0.9, false),
        ];
        let aug_auc = auc_on_augmented(&v).unwrap();
        assert!(aug_auc.abs() < 1e-5);
    }

    #[test]
    fn auc_on_augmented_propagates_single_class_error() {
        let v = vec![obs(0.1, true), obs(0.5, true)];
        let err = auc_on_augmented(&v).unwrap_err();
        assert!(matches!(err, AugmentError::Auc(SaeAucError::SingleClass { .. })));
    }

    #[test]
    fn auc_on_augmented_propagates_empty_error() {
        let err = auc_on_augmented(&[]).unwrap_err();
        assert!(matches!(err, AugmentError::Auc(SaeAucError::EmptyObservations)));
    }

    #[test]
    fn auc_on_augmented_propagates_potential_error_for_negative() {
        let v = vec![obs(-0.1, true), obs(0.5, false)];
        let err = auc_on_augmented(&v).unwrap_err();
        assert!(matches!(err, AugmentError::Potential { .. }));
    }

    #[test]
    fn augmented_floor_holds_for_zero_score_input() {
        // For raw 0.0 the potential is exactly 1.0. The augmented
        // LabeledScore.score (f32) is finite and ≥ 1.0.
        let v = vec![obs(0.0, false), obs(0.5, true)];
        let augmented = augment(&v).unwrap();
        assert!(augmented[0].potential.value() >= 1.0);
        assert!(augmented[1].potential.value() >= 1.0);
    }

    // ── summarize / AugmentedSummary tests (iter 10) ─────────────────────────

    #[test]
    fn summarize_on_empty_returns_zero_counts_and_none_fields() {
        let s = summarize(&[]).unwrap();
        assert_eq!(s.count, 0);
        assert_eq!(s.positives, 0);
        assert_eq!(s.negatives, 0);
        assert!(s.min_potential.is_none());
        assert!(s.max_potential.is_none());
        assert!(s.mean_potential.is_none());
        assert!(s.potential_range().is_none());
        assert!(s.positive_rate().is_none());
    }

    #[test]
    fn summarize_counts_match_class_balance() {
        let v = vec![
            obs(0.1, false), obs(0.2, true), obs(0.3, true), obs(0.4, false),
        ];
        let s = summarize(&v).unwrap();
        assert_eq!(s.count, 4);
        assert_eq!(s.positives, 2);
        assert_eq!(s.negatives, 2);
        assert!((s.positive_rate().unwrap() - 0.5).abs() < 1e-6);
    }

    #[test]
    fn summarize_min_max_mean_match_per_element_potentials() {
        let v = vec![obs(0.0, false), obs(1.0, true), obs(2.0, false)];
        let augmented = augment(&v).unwrap();
        let values: Vec<f64> = augmented.iter().map(|a| a.potential.value()).collect();
        let s = summarize(&v).unwrap();

        let expected_min = values.iter().cloned().fold(f64::INFINITY, f64::min);
        let expected_max = values.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let expected_mean = values.iter().sum::<f64>() / values.len() as f64;

        assert!((s.min_potential.unwrap() - expected_min).abs() < 1e-12);
        assert!((s.max_potential.unwrap() - expected_max).abs() < 1e-12);
        assert!((s.mean_potential.unwrap() - expected_mean).abs() < 1e-12);
    }

    #[test]
    fn summarize_min_at_zero_score_is_floor_one() {
        let v = vec![obs(0.0, false), obs(0.5, true), obs(1.0, false)];
        let s = summarize(&v).unwrap();
        // s=0 gives value 1.0 exactly; min must be 1.0.
        assert!((s.min_potential.unwrap() - 1.0).abs() < 1e-12);
    }

    #[test]
    fn summarize_propagates_negative_score_error_with_index() {
        let v = vec![obs(0.5, true), obs(-0.3, false), obs(0.9, true)];
        let err = summarize(&v).unwrap_err();
        match err {
            AugmentError::Potential { index, .. } => assert_eq!(index, 1),
            other => panic!("expected Potential at index 1, got {:?}", other),
        }
    }

    #[test]
    fn summarize_potential_range_matches_max_minus_min() {
        let v = vec![obs(0.0, false), obs(2.0, true), obs(10.0, false)];
        let s = summarize(&v).unwrap();
        let range = s.potential_range().unwrap();
        let expected = s.max_potential.unwrap() - s.min_potential.unwrap();
        assert!((range - expected).abs() < 1e-12);
        assert!(range > 0.0);
    }

    #[test]
    fn summarize_monotone_potentials_means_min_equals_first() {
        // Sorted-ascending scores produce sorted-ascending potentials
        // (proved by potential::tests::monotone_in_score_across_grid).
        // So summarize's min is the first observation's potential.
        let v = vec![obs(0.1, true), obs(0.5, false), obs(2.0, true), obs(5.0, false)];
        let s = summarize(&v).unwrap();
        let augmented = augment(&v).unwrap();
        let expected_min = augmented[0].potential.value();
        assert!((s.min_potential.unwrap() - expected_min).abs() < 1e-12);
    }

    #[test]
    fn summarize_single_observation_min_equals_max_equals_mean() {
        let v = vec![obs(0.7, true)];
        let s = summarize(&v).unwrap();
        assert_eq!(s.count, 1);
        let v_min = s.min_potential.unwrap();
        let v_max = s.max_potential.unwrap();
        let v_mean = s.mean_potential.unwrap();
        assert!((v_min - v_max).abs() < 1e-12);
        assert!((v_mean - v_min).abs() < 1e-12);
    }

    #[test]
    fn summarize_deterministic() {
        let v = vec![obs(0.1, false), obs(0.5, true), obs(0.9, false)];
        let a = summarize(&v).unwrap();
        let b = summarize(&v).unwrap();
        assert_eq!(a, b);
    }

    #[test]
    fn summarize_positive_rate_zero_when_no_positives() {
        let v = vec![obs(0.1, false), obs(0.5, false)];
        let s = summarize(&v).unwrap();
        assert_eq!(s.positives, 0);
        assert!((s.positive_rate().unwrap() - 0.0).abs() < 1e-6);
    }
}
