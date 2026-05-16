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
/// Reserved for the future training-pipeline layer; this substrate floor
/// holds only the AUC math.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ValidationSet {
    pub vault_domain: String,
    pub observations: Vec<LabeledScore>,
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
}
