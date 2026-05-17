//! Source:
//! - `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.36 — "SAE Cognition
//!   Observatory — hallucination detection AUC 0.90." The doctrine pin:
//!   "the row only counts as shipped when an SAE actually achieves AUC ≥ 0.90
//!   on a vault-domain validation set. Below 0.90 = research, not gate."
//! - Cunningham et al., "Sparse Autoencoders Find Highly Interpretable
//!   Features in Language Models", arXiv:2309.08600 — SAE methodology.
//! - Bricken et al., "Towards Monosemanticity: Decomposing Language Models
//!   With Dictionary Learning", Anthropic 2023 transformer-circuits.pub —
//!   the canonical SAE-on-residual-stream construction.
//! - Hanley & McNeil 1982, "The Meaning and Use of the Area under a
//!   Receiver Operating Characteristic (ROC) Curve" — AUC definition this
//!   module implements (trapezoidal integration of the ROC).
//!
//! # Wave J2 sub-feature #4 — SAE Cognition Observatory (substrate floor)
//!
//! Trains nothing here — that's the next layer up (Wave 9 integration per
//! §3.36 V1-scope row). This module owns the **doctrine-pin substrate**:
//! given a feature-firing trace + per-turn hallucination labels, compute
//! the AUC; given a held-out factual set, decide whether the SAE clears
//! the 0.90 bar.
//!
//! The math (Hanley & McNeil): for binary labels and continuous scores,
//! sort by score descending, sweep thresholds, plot (FPR, TPR), trapezoid-
//! integrate. We use the rank-based formulation for numerical safety:
//! `AUC = (S_pos - n_pos * (n_pos + 1) / 2) / (n_pos * n_neg)`
//! where `S_pos` = sum of ranks of positive-label items (1-indexed).
//!
//! Ties are broken by averaged ranks (the standard Mann-Whitney form), so
//! every tied score band gets the mean of its rank slots. That matches
//! `scipy.stats.mannwhitneyu` exactly and lets vault-team replays compare
//! against Python reference implementations.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct FeatureId(pub u32);

/// A per-turn observation: the score the SAE assigned to a hallucination-
/// indicating feature pattern (higher = more likely hallucination) + the
/// ground-truth label (true = was a hallucination on this turn).
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct LabeledScore {
    pub score: f32,
    pub is_hallucination: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SaeAucError {
    /// `observations` was empty — AUC is undefined.
    EmptyObservations,
    /// All observations had the same label (all positive or all negative).
    /// AUC is undefined in this degenerate case; the doctrine pin requires
    /// a mixed-label validation set.
    SingleClass { is_hallucination: bool, count: usize },
    /// An observation had a non-finite score (`NaN` or `±∞`). Reject so
    /// the AUC math doesn't silently produce garbage.
    NonFiniteScore { index: usize, score: f32 },
}

/// The §3.36 doctrine pin: 0.90.
pub const SAE_DOCTRINE_AUC_BAR: f32 = 0.90;

/// Verdict for one held-out validation run.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub enum SaeVerdict {
    /// `auc >= SAE_DOCTRINE_AUC_BAR`. Row counts as shipped.
    GatePassed { auc: f32 },
    /// `auc < SAE_DOCTRINE_AUC_BAR`. Below the pin — research, not gate.
    BelowGate { auc: f32, gap: f32 },
}

impl SaeVerdict {
    pub fn auc(&self) -> f32 {
        match *self {
            SaeVerdict::GatePassed { auc } => auc,
            SaeVerdict::BelowGate { auc, .. } => auc,
        }
    }

    pub fn passed(&self) -> bool {
        matches!(self, SaeVerdict::GatePassed { .. })
    }

    /// Complement to [`Self::passed`]. Cross-surface invariant:
    /// `passed XOR is_below` partitions every verdict.
    pub fn is_below(&self) -> bool {
        matches!(self, SaeVerdict::BelowGate { .. })
    }

    /// Distance below the doctrine bar: `bar - auc` for BelowGate,
    /// `0.0` for GatePassed. Always non-negative. Cross-surface
    /// invariant: matches the `gap` field stored in BelowGate.
    pub fn gap_below_gate(&self) -> f32 {
        match *self {
            SaeVerdict::GatePassed { .. } => 0.0,
            SaeVerdict::BelowGate { gap, .. } => gap,
        }
    }
}

impl SaeAucError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            SaeAucError::EmptyObservations => "empty_observations",
            SaeAucError::SingleClass { .. } => "single_class",
            SaeAucError::NonFiniteScore { .. } => "non_finite_score",
        }
    }

    /// Predicate: error pertains to the label set (Empty / SingleClass).
    pub const fn is_label_error(&self) -> bool {
        matches!(
            self,
            SaeAucError::EmptyObservations | SaeAucError::SingleClass { .. }
        )
    }

    /// Predicate: error pertains to a non-finite score value.
    /// Cross-surface invariant: `is_label_error XOR is_score_error`
    /// partitions all variants.
    pub const fn is_score_error(&self) -> bool {
        matches!(self, SaeAucError::NonFiniteScore { .. })
    }
}

impl LabeledScore {
    /// Predicate alias for `is_hallucination` — reads better at sites
    /// that think in classifier terms ("positive class" = hallucination).
    pub const fn is_positive(&self) -> bool {
        self.is_hallucination
    }
}

impl FeatureId {
    /// Underlying u32 value. Avoids `.0` field-access at telemetry
    /// call sites.
    pub const fn value(self) -> u32 {
        self.0
    }
}

/// Compute the area under the ROC curve via the rank-based formula. See
/// the module docstring for the mathematical justification.
pub fn auc_roc(observations: &[LabeledScore]) -> Result<f32, SaeAucError> {
    if observations.is_empty() {
        return Err(SaeAucError::EmptyObservations);
    }
    for (i, obs) in observations.iter().enumerate() {
        if !obs.score.is_finite() {
            return Err(SaeAucError::NonFiniteScore { index: i, score: obs.score });
        }
    }
    let n_pos = observations.iter().filter(|o| o.is_hallucination).count();
    let n_neg = observations.len() - n_pos;
    if n_pos == 0 {
        return Err(SaeAucError::SingleClass {
            is_hallucination: false,
            count: n_neg,
        });
    }
    if n_neg == 0 {
        return Err(SaeAucError::SingleClass {
            is_hallucination: true,
            count: n_pos,
        });
    }
    let mut indexed: Vec<(usize, f32, bool)> = observations
        .iter()
        .enumerate()
        .map(|(i, o)| (i, o.score, o.is_hallucination))
        .collect();
    indexed.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap_or(std::cmp::Ordering::Equal));

    let mut ranks: Vec<f32> = vec![0.0; observations.len()];
    let mut i = 0;
    while i < indexed.len() {
        let mut j = i + 1;
        while j < indexed.len() && indexed[j].1 == indexed[i].1 {
            j += 1;
        }
        let avg_rank = ((i + 1) as f32 + j as f32) / 2.0;
        for k in i..j {
            ranks[indexed[k].0] = avg_rank;
        }
        i = j;
    }

    let s_pos: f32 = observations
        .iter()
        .enumerate()
        .filter(|(_, o)| o.is_hallucination)
        .map(|(idx, _)| ranks[idx])
        .sum();

    let n_pos_f = n_pos as f32;
    let n_neg_f = n_neg as f32;
    let auc = (s_pos - n_pos_f * (n_pos_f + 1.0) / 2.0) / (n_pos_f * n_neg_f);
    Ok(auc)
}

/// Apply the §3.36 doctrine pin. Returns [`SaeVerdict::GatePassed`] iff
/// `auc >= SAE_DOCTRINE_AUC_BAR`.
pub fn evaluate_against_gate(observations: &[LabeledScore]) -> Result<SaeVerdict, SaeAucError> {
    let auc = auc_roc(observations)?;
    if auc >= SAE_DOCTRINE_AUC_BAR {
        Ok(SaeVerdict::GatePassed { auc })
    } else {
        Ok(SaeVerdict::BelowGate {
            auc,
            gap: SAE_DOCTRINE_AUC_BAR - auc,
        })
    }
}

/// Bundle of feature-firing observations for one held-out validation set.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ValidationSet {
    pub vault_domain: String,
    pub observations: Vec<LabeledScore>,
}

/// Per-validation-set class distribution.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct ClassBalance {
    pub total: usize,
    pub positives: usize,
    pub negatives: usize,
}

impl ClassBalance {
    /// Fraction of observations that are positive (= hallucination).
    /// Returns `None` if `total == 0` (rate is undefined on empty set).
    pub fn positive_rate(&self) -> Option<f32> {
        if self.total == 0 {
            return None;
        }
        Some(self.positives as f32 / self.total as f32)
    }

    /// True iff both classes have at least one member — the prerequisite
    /// for `auc_roc` to succeed.
    pub fn has_both_classes(&self) -> bool {
        self.positives > 0 && self.negatives > 0
    }
}

impl ValidationSet {
    /// Compute the class-balance breakdown of this set.
    pub fn class_balance(&self) -> ClassBalance {
        let total = self.observations.len();
        let positives = self.observations.iter().filter(|o| o.is_hallucination).count();
        let negatives = total - positives;
        ClassBalance { total, positives, negatives }
    }

    /// Convenience: run [`evaluate_against_gate`] on this set's
    /// observations. Production callers shouldn't reach into
    /// `.observations` for the common path.
    pub fn evaluate(&self) -> Result<SaeVerdict, SaeAucError> {
        evaluate_against_gate(&self.observations)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn obs(score: f32, h: bool) -> LabeledScore {
        LabeledScore { score, is_hallucination: h }
    }

    #[test]
    fn doctrine_pin_is_zero_point_nine() {
        assert_eq!(SAE_DOCTRINE_AUC_BAR, 0.90);
    }

    #[test]
    fn perfect_separation_yields_auc_one() {
        let v = vec![
            obs(0.1, false),
            obs(0.2, false),
            obs(0.9, true),
            obs(1.0, true),
        ];
        let auc = auc_roc(&v).unwrap();
        assert!((auc - 1.0).abs() < 1e-6);
    }

    #[test]
    fn perfectly_inverted_yields_auc_zero() {
        let v = vec![
            obs(1.0, false),
            obs(0.9, false),
            obs(0.2, true),
            obs(0.1, true),
        ];
        let auc = auc_roc(&v).unwrap();
        assert!(auc.abs() < 1e-6);
    }

    #[test]
    fn worse_than_random_yields_below_half_auc() {
        let v = vec![
            obs(0.1, true),
            obs(0.2, false),
            obs(0.3, true),
            obs(0.4, false),
        ];
        let auc = auc_roc(&v).unwrap();
        assert!((auc - 0.25).abs() < 1e-6, "auc={}", auc);
    }

    #[test]
    fn tied_scores_use_averaged_ranks() {
        let v = vec![obs(0.5, true), obs(0.5, false)];
        let auc = auc_roc(&v).unwrap();
        assert!((auc - 0.5).abs() < 1e-6);
    }

    #[test]
    fn empty_observations_errors() {
        let err = auc_roc(&[]).unwrap_err();
        assert_eq!(err, SaeAucError::EmptyObservations);
    }

    #[test]
    fn all_positive_class_errors() {
        let v = vec![obs(0.1, true), obs(0.9, true)];
        let err = auc_roc(&v).unwrap_err();
        assert_eq!(
            err,
            SaeAucError::SingleClass { is_hallucination: true, count: 2 }
        );
    }

    #[test]
    fn all_negative_class_errors() {
        let v = vec![obs(0.1, false), obs(0.9, false)];
        let err = auc_roc(&v).unwrap_err();
        assert_eq!(
            err,
            SaeAucError::SingleClass { is_hallucination: false, count: 2 }
        );
    }

    #[test]
    fn nan_score_errors() {
        let v = vec![obs(f32::NAN, true), obs(0.5, false)];
        let err = auc_roc(&v).unwrap_err();
        match err {
            SaeAucError::NonFiniteScore { index, .. } => assert_eq!(index, 0),
            other => panic!("expected NonFiniteScore, got {:?}", other),
        }
    }

    #[test]
    fn gate_passes_when_auc_meets_pin() {
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
        let verdict = evaluate_against_gate(&v).unwrap();
        assert!(verdict.passed());
        match verdict {
            SaeVerdict::GatePassed { auc } => assert!(auc >= SAE_DOCTRINE_AUC_BAR),
            other => panic!("expected GatePassed, got {:?}", other),
        }
    }

    #[test]
    fn gate_below_when_separation_is_weak() {
        let v = vec![
            obs(0.1, true),
            obs(0.2, false),
            obs(0.3, true),
            obs(0.4, false),
        ];
        let verdict = evaluate_against_gate(&v).unwrap();
        assert!(!verdict.passed());
        match verdict {
            SaeVerdict::BelowGate { auc, gap } => {
                assert!((auc - 0.25).abs() < 1e-6, "auc={}", auc);
                assert!((gap - 0.65).abs() < 1e-6, "gap={}", gap);
            }
            other => panic!("expected BelowGate, got {:?}", other),
        }
    }

    #[test]
    fn validation_set_roundtrips_through_serde_json() {
        let vs = ValidationSet {
            vault_domain: "math".into(),
            observations: vec![obs(0.1, false), obs(0.9, true)],
        };
        let json = serde_json::to_string(&vs).unwrap();
        let back: ValidationSet = serde_json::from_str(&json).unwrap();
        assert_eq!(vs, back);
    }

    #[test]
    fn moderate_auc_matches_hand_computed_zero_point_nine_two() {
        let v = vec![
            obs(0.1, false),
            obs(0.2, false),
            obs(0.3, false),
            obs(0.4, false),
            obs(0.5, false),
            obs(0.35, true),
            obs(0.55, true),
            obs(0.65, true),
            obs(0.75, true),
            obs(0.85, true),
        ];
        let auc = auc_roc(&v).unwrap();
        assert!((auc - 0.92).abs() < 1e-6, "auc={}", auc);
    }

    // ── ValidationSet + ClassBalance tests (iter 103) ───────────────────────

    fn vs(observations: Vec<LabeledScore>) -> ValidationSet {
        ValidationSet { vault_domain: "test".into(), observations }
    }

    #[test]
    fn class_balance_empty() {
        let s = vs(vec![]);
        let cb = s.class_balance();
        assert_eq!(cb.total, 0);
        assert_eq!(cb.positives, 0);
        assert_eq!(cb.negatives, 0);
        assert!(cb.positive_rate().is_none());
        assert!(!cb.has_both_classes());
    }

    #[test]
    fn class_balance_balanced() {
        let s = vs(vec![
            obs(0.1, false),
            obs(0.2, false),
            obs(0.8, true),
            obs(0.9, true),
        ]);
        let cb = s.class_balance();
        assert_eq!(cb.total, 4);
        assert_eq!(cb.positives, 2);
        assert_eq!(cb.negatives, 2);
        assert!((cb.positive_rate().unwrap() - 0.5).abs() < 1e-6);
        assert!(cb.has_both_classes());
    }

    #[test]
    fn class_balance_single_class_positives() {
        let s = vs(vec![obs(0.5, true), obs(0.9, true)]);
        let cb = s.class_balance();
        assert_eq!(cb.positives, 2);
        assert_eq!(cb.negatives, 0);
        assert!(!cb.has_both_classes());
        assert!((cb.positive_rate().unwrap() - 1.0).abs() < 1e-6);
    }

    #[test]
    fn class_balance_single_class_negatives() {
        let s = vs(vec![obs(0.1, false), obs(0.5, false)]);
        let cb = s.class_balance();
        assert_eq!(cb.positives, 0);
        assert_eq!(cb.negatives, 2);
        assert!(!cb.has_both_classes());
        assert!((cb.positive_rate().unwrap() - 0.0).abs() < 1e-6);
    }

    #[test]
    fn evaluate_passes_when_observations_separate_classes() {
        // Perfect separation → AUC 1.0 > 0.90 → GatePassed.
        let s = vs(vec![
            obs(0.1, false),
            obs(0.2, false),
            obs(0.8, true),
            obs(0.9, true),
        ]);
        let verdict = s.evaluate().unwrap();
        assert!(verdict.passed());
        assert!((verdict.auc() - 1.0).abs() < 1e-6);
    }

    #[test]
    fn evaluate_below_gate_when_classifier_random() {
        // Interleaved scores → AUC ~ 0.5 < 0.90 → BelowGate.
        let s = vs(vec![
            obs(0.1, true),
            obs(0.2, false),
            obs(0.3, true),
            obs(0.4, false),
        ]);
        let verdict = s.evaluate().unwrap();
        assert!(!verdict.passed());
        match verdict {
            SaeVerdict::BelowGate { gap, .. } => assert!(gap > 0.0),
            _ => panic!("expected BelowGate"),
        }
    }

    #[test]
    fn evaluate_propagates_single_class_error() {
        let s = vs(vec![obs(0.5, true), obs(0.9, true)]);
        let err = s.evaluate().unwrap_err();
        assert!(matches!(err, SaeAucError::SingleClass { .. }));
    }

    #[test]
    fn evaluate_propagates_empty_error() {
        let s = vs(vec![]);
        let err = s.evaluate().unwrap_err();
        assert_eq!(err, SaeAucError::EmptyObservations);
    }

    #[test]
    fn class_balance_serde_roundtrip() {
        let cb = ClassBalance { total: 10, positives: 3, negatives: 7 };
        let json = serde_json::to_string(&cb).unwrap();
        let back: ClassBalance = serde_json::from_str(&json).unwrap();
        assert_eq!(cb, back);
    }

    // ── diagnostic surface (iter 181) ────────────────────────────────────────

    #[test]
    fn verdict_passed_xor_below_partition() {
        // Cross-surface invariant: passed XOR is_below.
        let p = SaeVerdict::GatePassed { auc: 0.95 };
        let b = SaeVerdict::BelowGate { auc: 0.80, gap: 0.10 };
        for v in [p, b] {
            assert_ne!(v.passed(), v.is_below());
        }
    }

    #[test]
    fn verdict_gap_below_gate_matches_field() {
        // Cross-surface invariant: gap_below_gate matches BelowGate.gap.
        let b = SaeVerdict::BelowGate { auc: 0.80, gap: 0.10 };
        assert!((b.gap_below_gate() - 0.10).abs() < 1e-9);
    }

    #[test]
    fn verdict_gap_zero_when_passed() {
        let p = SaeVerdict::GatePassed { auc: 0.95 };
        assert_eq!(p.gap_below_gate(), 0.0);
    }

    #[test]
    fn verdict_gap_arithmetic_from_real_eval() {
        // Cross-surface: BelowGate's gap = SAE_DOCTRINE_AUC_BAR - auc.
        let v = vec![obs(0.1, true), obs(0.2, false), obs(0.3, true), obs(0.4, false)];
        let verdict = evaluate_against_gate(&v).unwrap();
        assert!(verdict.is_below());
        let computed_gap = SAE_DOCTRINE_AUC_BAR - verdict.auc();
        assert!((verdict.gap_below_gate() - computed_gap).abs() < 1e-6);
    }

    #[test]
    fn auc_error_cause_distinct_per_variant() {
        let variants = [
            SaeAucError::EmptyObservations,
            SaeAucError::SingleClass { is_hallucination: true, count: 5 },
            SaeAucError::NonFiniteScore { index: 0, score: f32::NAN },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 3);
    }

    #[test]
    fn auc_error_classifiers_partition() {
        let variants = [
            SaeAucError::EmptyObservations,
            SaeAucError::SingleClass { is_hallucination: true, count: 5 },
            SaeAucError::NonFiniteScore { index: 0, score: f32::NAN },
        ];
        // Cross-surface invariant: is_label_error XOR is_score_error.
        for e in variants {
            assert_ne!(e.is_label_error(), e.is_score_error());
        }
        assert_eq!(variants.iter().filter(|e| e.is_label_error()).count(), 2);
        assert_eq!(variants.iter().filter(|e| e.is_score_error()).count(), 1);
    }

    #[test]
    fn has_both_classes_aligns_with_auc_roc_success() {
        // Cross-surface invariant: ClassBalance::has_both_classes iff
        // auc_roc does NOT return SingleClass (for non-empty input).
        fn vs2(obs_list: Vec<LabeledScore>) -> ValidationSet {
            ValidationSet { vault_domain: "t".into(), observations: obs_list }
        }
        let s = vs2(vec![obs(0.1, true), obs(0.5, false)]);
        let bal = s.class_balance();
        assert!(bal.has_both_classes());
        assert!(auc_roc(&s.observations).is_ok());

        let s = vs2(vec![obs(0.1, true), obs(0.5, true)]);
        let bal = s.class_balance();
        assert!(!bal.has_both_classes());
        let err = auc_roc(&s.observations).unwrap_err();
        assert!(matches!(err, SaeAucError::SingleClass { .. }));
    }

    #[test]
    fn labeled_score_is_positive_alias() {
        let pos = obs(0.5, true);
        let neg = obs(0.5, false);
        assert!(pos.is_positive());
        assert!(!neg.is_positive());
    }

    #[test]
    fn feature_id_value_returns_inner() {
        let f = FeatureId(42);
        assert_eq!(f.value(), 42);
    }
}
