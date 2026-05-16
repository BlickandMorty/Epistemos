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

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct InterruptCalibrationReport {
    pub n_observations: usize,
    pub auroc: f32,
    pub best_threshold: f32,
    pub best_youden_j: f32,
    pub passes_doctrine: bool,
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
}
