//! Source:
//! - `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` §1.5 +
//!   §"Terminal B" Phase B.6.20 — Hybrid-SSM + attention-as-interrupt
//!   thesis calibration. F-Interrupt-Calibration: 30-task corpus,
//!   AUROC ≥ 0.85 on hand-labeled "interrupt-needed" set.
//! - Companion to [`super::cognition_observatory::sae`] — reuses
//!   `sae::auc_roc` (Hanley-McNeil 1982 rank-based AUC) for the
//!   binary classifier evaluation.
//!
//! # Wave J B.6.20 — Hybrid-SSM interrupt calibration substrate
//!
//! The V6.1 thesis:
//!
//! ```text
//! SSM-default decoder runs linearly along the time axis.
//! A per-token classifier emits an interrupt-score.
//! If the score exceeds the calibrated threshold τ, the runtime
//!   switches to full-attention for the next K tokens.
//! ```
//!
//! Acceptance: AUROC ≥ [`INTERRUPT_DOCTRINE_AUROC_BAR`] = 0.85 on a
//! 30-task hand-labeled corpus per V6.1 §1.5.
//!
//! Substrate floor owns the calibration math + the gate verdict.
//! Threshold selection uses Youden's J statistic (J = TPR − FPR
//! maximized over candidate thresholds) — the canonical choice when
//! the cost matrix is symmetric.

use super::cognition_observatory::sae::{auc_roc, LabeledScore, SaeAucError};
use serde::{Deserialize, Serialize};

pub const INTERRUPT_DOCTRINE_AUROC_BAR: f32 = 0.85;

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct InterruptObservation {
    pub interrupt_score: f32,
    pub ground_truth_needed: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum InterruptCalibrationError {
    PassthroughAuc(SaeAucError),
    EmptyObservations,
}

impl From<SaeAucError> for InterruptCalibrationError {
    fn from(e: SaeAucError) -> Self {
        InterruptCalibrationError::PassthroughAuc(e)
    }
}

impl InterruptCalibrationError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            InterruptCalibrationError::PassthroughAuc(_) => "passthrough_auc",
            InterruptCalibrationError::EmptyObservations => "empty_observations",
        }
    }

    /// Predicate: this error came from the AUC computation upstream.
    pub const fn is_passthrough_auc(&self) -> bool {
        matches!(self, InterruptCalibrationError::PassthroughAuc(_))
    }

    /// Predicate: this error is the local empty-observation check.
    /// Cross-surface invariant: `is_passthrough_auc XOR
    /// is_empty_observations` partitions all variants.
    pub const fn is_empty_observations(&self) -> bool {
        matches!(self, InterruptCalibrationError::EmptyObservations)
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct InterruptCalibrationReport {
    pub n_observations: usize,
    pub auroc: f32,
    pub best_threshold: f32,
    pub best_youden_j: f32,
    pub passes_doctrine: bool,
}

impl InterruptCalibrationReport {
    /// AUROC minus the doctrine bar. Positive when the classifier
    /// clears the bar; negative when it's below. Cross-surface
    /// invariant: `doctrine_gap() >= 0.0 iff passes_doctrine`.
    pub fn doctrine_gap(&self) -> f32 {
        self.auroc - INTERRUPT_DOCTRINE_AUROC_BAR
    }
}

/// Calibrate + evaluate per V6.1 §1.5. Computes AUROC + the Youden-J
/// optimal threshold. `passes_doctrine = auroc >= 0.85`.
pub fn calibrate_interrupt_classifier(
    observations: &[InterruptObservation],
) -> Result<InterruptCalibrationReport, InterruptCalibrationError> {
    if observations.is_empty() {
        return Err(InterruptCalibrationError::EmptyObservations);
    }
    let labeled: Vec<LabeledScore> = observations
        .iter()
        .map(|o| LabeledScore {
            score: o.interrupt_score,
            is_hallucination: o.ground_truth_needed,
        })
        .collect();
    let auroc = auc_roc(&labeled)?;

    let mut sorted: Vec<&InterruptObservation> = observations.iter().collect();
    sorted.sort_by(|a, b| {
        a.interrupt_score
            .partial_cmp(&b.interrupt_score)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    let n_pos = observations.iter().filter(|o| o.ground_truth_needed).count();
    let n_neg = observations.len() - n_pos;

    let mut best_j: f32 = f32::NEG_INFINITY;
    let mut best_thr: f32 = observations[0].interrupt_score;
    if n_pos > 0 && n_neg > 0 {
        for thr_obs in &sorted {
            let thr = thr_obs.interrupt_score;
            let tp = observations
                .iter()
                .filter(|o| o.ground_truth_needed && o.interrupt_score >= thr)
                .count() as f32;
            let fp = observations
                .iter()
                .filter(|o| !o.ground_truth_needed && o.interrupt_score >= thr)
                .count() as f32;
            let tpr = tp / (n_pos as f32);
            let fpr = fp / (n_neg as f32);
            let j = tpr - fpr;
            if j > best_j {
                best_j = j;
                best_thr = thr;
            }
        }
    } else {
        best_j = 0.0;
    }

    Ok(InterruptCalibrationReport {
        n_observations: observations.len(),
        auroc,
        best_threshold: best_thr,
        best_youden_j: best_j,
        passes_doctrine: auroc >= INTERRUPT_DOCTRINE_AUROC_BAR,
    })
}

/// Confusion matrix at a fixed decision threshold + derived metrics.
/// Distinct from [`InterruptCalibrationReport`] (which learns the
/// threshold via Youden-J on a calibration set); this surface is for
/// the production-side question "given the threshold I shipped, what
/// are my TPR/FPR/precision/recall on this batch?".
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct ConfusionMatrix {
    pub threshold: f32,
    pub true_positive: u32,
    pub false_positive: u32,
    pub true_negative: u32,
    pub false_negative: u32,
}

impl ConfusionMatrix {
    pub fn total(&self) -> u32 {
        self.true_positive + self.false_positive + self.true_negative + self.false_negative
    }

    /// Accuracy: `(TP + TN) / total`. Returns `None` on empty batch.
    pub fn accuracy(&self) -> Option<f32> {
        let t = self.total();
        if t == 0 {
            return None;
        }
        Some((self.true_positive + self.true_negative) as f32 / t as f32)
    }

    /// Precision: `TP / (TP + FP)`. Returns `None` if `TP + FP = 0`
    /// (no positive predictions made — precision is undefined).
    pub fn precision(&self) -> Option<f32> {
        let denom = self.true_positive + self.false_positive;
        if denom == 0 {
            return None;
        }
        Some(self.true_positive as f32 / denom as f32)
    }

    /// Recall (= TPR / sensitivity): `TP / (TP + FN)`. Returns `None`
    /// if no actual positives in the batch (no positives to recall).
    pub fn recall(&self) -> Option<f32> {
        let denom = self.true_positive + self.false_negative;
        if denom == 0 {
            return None;
        }
        Some(self.true_positive as f32 / denom as f32)
    }

    /// FPR (= 1 − specificity): `FP / (FP + TN)`. Returns `None` if
    /// no actual negatives in the batch.
    pub fn false_positive_rate(&self) -> Option<f32> {
        let denom = self.false_positive + self.true_negative;
        if denom == 0 {
            return None;
        }
        Some(self.false_positive as f32 / denom as f32)
    }

    /// F1 score: harmonic mean of precision + recall. Returns `None`
    /// if either is undefined or both are zero.
    pub fn f1(&self) -> Option<f32> {
        let p = self.precision()?;
        let r = self.recall()?;
        if p + r == 0.0 {
            return None;
        }
        Some(2.0 * p * r / (p + r))
    }

    /// Specificity (= TN rate, complement of FPR):
    /// `TN / (FP + TN)`. Returns `None` if no actual negatives.
    /// Cross-surface invariant: `specificity + false_positive_rate
    /// = 1.0` when both are defined.
    pub fn specificity(&self) -> Option<f32> {
        let denom = self.false_positive + self.true_negative;
        if denom == 0 {
            return None;
        }
        Some(self.true_negative as f32 / denom as f32)
    }

    /// Number of actually-positive samples in the batch (TP + FN).
    pub const fn actual_positives(&self) -> u32 {
        self.true_positive + self.false_negative
    }

    /// Number of actually-negative samples in the batch (FP + TN).
    pub const fn actual_negatives(&self) -> u32 {
        self.false_positive + self.true_negative
    }

    /// Number of samples the classifier predicted as positive
    /// (TP + FP).
    pub const fn predicted_positives(&self) -> u32 {
        self.true_positive + self.false_positive
    }

    /// Number of samples the classifier predicted as negative
    /// (TN + FN).
    pub const fn predicted_negatives(&self) -> u32 {
        self.true_negative + self.false_negative
    }

    /// Predicate: every prediction was correct (FP=0 AND FN=0).
    /// Cross-surface invariant: `is_perfect() iff accuracy() ==
    /// Some(1.0)` (over non-empty batches).
    pub const fn is_perfect(&self) -> bool {
        self.false_positive == 0 && self.false_negative == 0
    }
}

/// Evaluate the classifier at a fixed `threshold`. A score ≥ threshold
/// is "predicted interrupt"; below is "predicted no-interrupt". The
/// observation's `ground_truth_needed` is the actual label.
pub fn evaluate_at_threshold(
    observations: &[InterruptObservation],
    threshold: f32,
) -> Result<ConfusionMatrix, InterruptCalibrationError> {
    if observations.is_empty() {
        return Err(InterruptCalibrationError::EmptyObservations);
    }
    let mut tp = 0u32;
    let mut fp = 0u32;
    let mut tn = 0u32;
    let mut fn_ = 0u32;
    for o in observations {
        let predicted = o.interrupt_score >= threshold;
        match (predicted, o.ground_truth_needed) {
            (true, true) => tp += 1,
            (true, false) => fp += 1,
            (false, false) => tn += 1,
            (false, true) => fn_ += 1,
        }
    }
    Ok(ConfusionMatrix {
        threshold,
        true_positive: tp,
        false_positive: fp,
        true_negative: tn,
        false_negative: fn_,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn obs(score: f32, needed: bool) -> InterruptObservation {
        InterruptObservation { interrupt_score: score, ground_truth_needed: needed }
    }

    #[test]
    fn doctrine_bar_is_zero_point_eight_five() {
        assert_eq!(INTERRUPT_DOCTRINE_AUROC_BAR, 0.85);
    }

    #[test]
    fn perfect_separation_passes_doctrine() {
        let v = vec![
            obs(0.1, false),
            obs(0.2, false),
            obs(0.3, false),
            obs(0.9, true),
            obs(0.95, true),
        ];
        let r = calibrate_interrupt_classifier(&v).unwrap();
        assert!((r.auroc - 1.0).abs() < 1e-6);
        assert!(r.passes_doctrine);
        assert!((r.best_youden_j - 1.0).abs() < 1e-6);
    }

    #[test]
    fn empty_observations_errors() {
        let err = calibrate_interrupt_classifier(&[]).unwrap_err();
        assert_eq!(err, InterruptCalibrationError::EmptyObservations);
    }

    #[test]
    fn random_split_below_doctrine() {
        // Worse-than-random: low scores positive, high scores negative.
        let v = vec![
            obs(0.1, true),
            obs(0.2, false),
            obs(0.3, true),
            obs(0.4, false),
        ];
        let r = calibrate_interrupt_classifier(&v).unwrap();
        assert!(r.auroc < INTERRUPT_DOCTRINE_AUROC_BAR);
        assert!(!r.passes_doctrine);
    }

    #[test]
    fn youden_j_picks_optimal_threshold() {
        let v = vec![
            obs(0.1, false),
            obs(0.2, false),
            obs(0.8, true),
            obs(0.9, true),
        ];
        let r = calibrate_interrupt_classifier(&v).unwrap();
        // Best threshold sits between 0.2 and 0.8; the smallest score
        // that achieves perfect separation is 0.8.
        assert!((r.best_threshold - 0.8).abs() < 1e-6);
        assert!((r.best_youden_j - 1.0).abs() < 1e-6);
    }

    #[test]
    fn moderate_separation_around_zero_point_nine_two() {
        // From the SAE iter-12 reference fixture.
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
        let r = calibrate_interrupt_classifier(&v).unwrap();
        assert!((r.auroc - 0.92).abs() < 1e-3);
        assert!(r.passes_doctrine);
    }

    #[test]
    fn report_roundtrips_through_serde_json() {
        let v = vec![obs(0.0, false), obs(1.0, true)];
        let r = calibrate_interrupt_classifier(&v).unwrap();
        let json = serde_json::to_string(&r).unwrap();
        let back: InterruptCalibrationReport = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn observation_roundtrips_through_serde_json() {
        let o = obs(0.5, true);
        let json = serde_json::to_string(&o).unwrap();
        let back: InterruptObservation = serde_json::from_str(&json).unwrap();
        assert_eq!(o, back);
    }

    #[test]
    fn single_class_propagates_auc_error() {
        let v = vec![obs(0.1, true), obs(0.5, true)];
        let err = calibrate_interrupt_classifier(&v).unwrap_err();
        assert!(matches!(err, InterruptCalibrationError::PassthroughAuc(_)));
    }

    #[test]
    fn n_observations_matches_input_length() {
        let v = vec![obs(0.0, false), obs(0.5, true), obs(1.0, true)];
        let r = calibrate_interrupt_classifier(&v).unwrap();
        assert_eq!(r.n_observations, 3);
    }

    #[test]
    fn just_passes_doctrine_at_auroc_zero_point_eight_five() {
        // Hand-tuned 10-observation set with AUROC ≈ 0.88 (above bar).
        // 5 positives, 5 negatives; one weak pair to drop below 1.0.
        let v = vec![
            obs(0.05, false),
            obs(0.10, false),
            obs(0.20, false),
            obs(0.30, false),
            obs(0.35, false),
            obs(0.32, true),
            obs(0.60, true),
            obs(0.70, true),
            obs(0.80, true),
            obs(0.90, true),
        ];
        let r = calibrate_interrupt_classifier(&v).unwrap();
        assert!(r.passes_doctrine, "auroc={}", r.auroc);
    }

    // ── evaluate_at_threshold + ConfusionMatrix tests (iter 97) ─────────────

    #[test]
    fn evaluate_empty_rejected() {
        let err = evaluate_at_threshold(&[], 0.5).unwrap_err();
        assert_eq!(err, InterruptCalibrationError::EmptyObservations);
    }

    #[test]
    fn evaluate_perfect_classifier_at_optimal_threshold() {
        let v = vec![
            obs(0.1, false),
            obs(0.2, false),
            obs(0.8, true),
            obs(0.9, true),
        ];
        let cm = evaluate_at_threshold(&v, 0.5).unwrap();
        assert_eq!(cm.true_positive, 2);
        assert_eq!(cm.false_positive, 0);
        assert_eq!(cm.true_negative, 2);
        assert_eq!(cm.false_negative, 0);
        assert_eq!(cm.total(), 4);
        assert!((cm.accuracy().unwrap() - 1.0).abs() < 1e-6);
        assert!((cm.precision().unwrap() - 1.0).abs() < 1e-6);
        assert!((cm.recall().unwrap() - 1.0).abs() < 1e-6);
        assert!((cm.false_positive_rate().unwrap() - 0.0).abs() < 1e-6);
        assert!((cm.f1().unwrap() - 1.0).abs() < 1e-6);
    }

    #[test]
    fn evaluate_too_low_threshold_yields_all_positives() {
        let v = vec![
            obs(0.1, false),
            obs(0.2, false),
            obs(0.8, true),
            obs(0.9, true),
        ];
        let cm = evaluate_at_threshold(&v, 0.0).unwrap();
        assert_eq!(cm.true_positive, 2);
        assert_eq!(cm.false_positive, 2); // both negatives marked positive
        assert_eq!(cm.true_negative, 0);
        assert_eq!(cm.false_negative, 0);
    }

    #[test]
    fn evaluate_too_high_threshold_yields_all_negatives() {
        let v = vec![
            obs(0.1, false),
            obs(0.2, false),
            obs(0.8, true),
            obs(0.9, true),
        ];
        let cm = evaluate_at_threshold(&v, 10.0).unwrap();
        assert_eq!(cm.true_positive, 0);
        assert_eq!(cm.false_positive, 0);
        assert_eq!(cm.true_negative, 2);
        assert_eq!(cm.false_negative, 2);
    }

    #[test]
    fn precision_none_when_no_positive_predictions() {
        let v = vec![obs(0.1, false), obs(0.2, false)];
        let cm = evaluate_at_threshold(&v, 0.5).unwrap();
        // No TP + no FP → precision undefined.
        assert!(cm.precision().is_none());
    }

    #[test]
    fn recall_none_when_no_actual_positives() {
        let v = vec![obs(0.1, false), obs(0.2, false)];
        let cm = evaluate_at_threshold(&v, 0.5).unwrap();
        // No actual positives → recall undefined.
        assert!(cm.recall().is_none());
    }

    #[test]
    fn fpr_none_when_no_actual_negatives() {
        let v = vec![obs(0.9, true), obs(0.95, true)];
        let cm = evaluate_at_threshold(&v, 0.5).unwrap();
        assert!(cm.false_positive_rate().is_none());
    }

    #[test]
    fn f1_none_when_precision_or_recall_undefined() {
        // No actual positives → recall undefined → F1 undefined.
        let v = vec![obs(0.1, false), obs(0.2, false)];
        let cm = evaluate_at_threshold(&v, 0.5).unwrap();
        assert!(cm.f1().is_none());
    }

    #[test]
    fn confusion_matrix_threshold_at_boundary_is_inclusive() {
        // Score == threshold should be "predicted interrupt".
        let v = vec![obs(0.5, true), obs(0.4999, false)];
        let cm = evaluate_at_threshold(&v, 0.5).unwrap();
        assert_eq!(cm.true_positive, 1);
        assert_eq!(cm.true_negative, 1);
    }

    #[test]
    fn confusion_matrix_serde_roundtrip() {
        let cm = ConfusionMatrix {
            threshold: 0.5,
            true_positive: 10,
            false_positive: 2,
            true_negative: 8,
            false_negative: 1,
        };
        let json = serde_json::to_string(&cm).unwrap();
        let back: ConfusionMatrix = serde_json::from_str(&json).unwrap();
        assert_eq!(cm, back);
    }

    // ── diagnostic surface (iter 166) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct() {
        let variants = [
            InterruptCalibrationError::EmptyObservations,
            InterruptCalibrationError::PassthroughAuc(SaeAucError::EmptyObservations),
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 2);
    }

    #[test]
    fn error_classifiers_partition() {
        // Cross-surface invariant: is_passthrough_auc XOR is_empty_observations.
        for e in [
            InterruptCalibrationError::EmptyObservations,
            InterruptCalibrationError::PassthroughAuc(SaeAucError::EmptyObservations),
        ] {
            assert_ne!(e.is_passthrough_auc(), e.is_empty_observations());
        }
    }

    #[test]
    fn confusion_specificity_complements_fpr() {
        // Cross-surface invariant: specificity + fpr = 1.0 when both defined.
        let cm = ConfusionMatrix {
            threshold: 0.5,
            true_positive: 5,
            false_positive: 2,
            true_negative: 8,
            false_negative: 1,
        };
        let spec = cm.specificity().unwrap();
        let fpr = cm.false_positive_rate().unwrap();
        assert!((spec + fpr - 1.0).abs() < 1e-6);
        // 8 / (2 + 8) = 0.8.
        assert!((spec - 0.8).abs() < 1e-6);
    }

    #[test]
    fn confusion_specificity_none_when_no_negatives() {
        let cm = ConfusionMatrix {
            threshold: 0.5,
            true_positive: 5,
            false_positive: 0,
            true_negative: 0,
            false_negative: 1,
        };
        assert!(cm.specificity().is_none());
    }

    #[test]
    fn confusion_actual_predicted_counts_partition_total() {
        // Cross-surface: actual_positives + actual_negatives = total.
        // Same for predicted_positives + predicted_negatives.
        let cm = ConfusionMatrix {
            threshold: 0.5,
            true_positive: 5,
            false_positive: 2,
            true_negative: 8,
            false_negative: 1,
        };
        assert_eq!(cm.actual_positives() + cm.actual_negatives(), cm.total());
        assert_eq!(cm.predicted_positives() + cm.predicted_negatives(), cm.total());
        assert_eq!(cm.actual_positives(), 6); // TP + FN
        assert_eq!(cm.actual_negatives(), 10); // FP + TN
        assert_eq!(cm.predicted_positives(), 7); // TP + FP
        assert_eq!(cm.predicted_negatives(), 9); // TN + FN
    }

    #[test]
    fn is_perfect_aligns_with_accuracy_one() {
        // Cross-surface invariant: is_perfect iff accuracy == 1.0
        // (over non-empty batches).
        let perfect = ConfusionMatrix {
            threshold: 0.5,
            true_positive: 5,
            false_positive: 0,
            true_negative: 3,
            false_negative: 0,
        };
        assert!(perfect.is_perfect());
        assert!((perfect.accuracy().unwrap() - 1.0).abs() < 1e-6);

        let with_fp = ConfusionMatrix {
            threshold: 0.5,
            true_positive: 5,
            false_positive: 1,
            true_negative: 3,
            false_negative: 0,
        };
        assert!(!with_fp.is_perfect());
        assert!(with_fp.accuracy().unwrap() < 1.0);

        let with_fn = ConfusionMatrix {
            threshold: 0.5,
            true_positive: 5,
            false_positive: 0,
            true_negative: 3,
            false_negative: 1,
        };
        assert!(!with_fn.is_perfect());
        assert!(with_fn.accuracy().unwrap() < 1.0);
    }

    #[test]
    fn doctrine_gap_aligns_with_passes() {
        // Cross-surface invariant: doctrine_gap >= 0 iff passes_doctrine.
        let v_pass = vec![obs(0.1, false), obs(0.9, true), obs(0.05, false), obs(0.95, true)];
        let r_pass = calibrate_interrupt_classifier(&v_pass).unwrap();
        assert!(r_pass.doctrine_gap() >= 0.0);
        assert!(r_pass.passes_doctrine);

        let v_fail = vec![obs(0.1, true), obs(0.2, false), obs(0.3, true), obs(0.4, false)];
        let r_fail = calibrate_interrupt_classifier(&v_fail).unwrap();
        assert!(r_fail.doctrine_gap() < 0.0);
        assert!(!r_fail.passes_doctrine);
    }

    #[test]
    fn doctrine_gap_arithmetic_correct() {
        let r = InterruptCalibrationReport {
            n_observations: 10,
            auroc: 0.92,
            best_threshold: 0.5,
            best_youden_j: 0.8,
            passes_doctrine: true,
        };
        assert!((r.doctrine_gap() - (0.92 - 0.85)).abs() < 1e-6);
    }
}
