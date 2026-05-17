#![cfg(feature = "research")]
//! Wave J2 cognition observatory SAE harness — integration tests.
//!
//! Source:
//! - `agent_core/src/research/cognition_observatory/sae.rs` (substrate).
//! - MASTER_FUSION §3.36 "SAE Cognition Observatory — hallucination
//!   detection AUC 0.90" — doctrine pin.
//! - Phase B iter 61 substrate-floor.
//!
//! # Substrate-floor scope
//!
//! Exercises auc_roc + evaluate_against_gate + SaeVerdict + LabeledScore
//! + SaeAucError. Verifies doctrine 0.90 gate, single-class edge,
//! non-finite-score detection, and predicate partition invariants.

use agent_core::research::cognition_observatory::sae::{
    auc_roc, evaluate_against_gate, LabeledScore, SaeAucError, SaeVerdict, SAE_DOCTRINE_AUC_BAR,
};

#[test]
fn doctrine_auc_bar_is_0_90() {
    assert!((SAE_DOCTRINE_AUC_BAR - 0.90).abs() < 1e-6);
}

#[test]
fn perfect_classifier_auc_is_one() {
    let obs = vec![
        LabeledScore { score: 0.1, is_hallucination: false },
        LabeledScore { score: 0.2, is_hallucination: false },
        LabeledScore { score: 0.8, is_hallucination: true },
        LabeledScore { score: 0.9, is_hallucination: true },
    ];
    let auc = auc_roc(&obs).unwrap();
    assert!((auc - 1.0).abs() < 1e-6, "perfect separation → AUC = 1.0; got {}", auc);
}

#[test]
fn anti_correlated_classifier_auc_is_quarter() {
    // Positives at LOWER scores than mid; mixed → AUC = 0.25 (worse-than-
    // random). The 4 pos×neg pairs: (0.1, 0.2) = miss, (0.1, 0.4) = miss,
    // (0.3, 0.2) = hit, (0.3, 0.4) = miss → 1/4 = 0.25.
    let obs = vec![
        LabeledScore { score: 0.1, is_hallucination: true },
        LabeledScore { score: 0.2, is_hallucination: false },
        LabeledScore { score: 0.3, is_hallucination: true },
        LabeledScore { score: 0.4, is_hallucination: false },
    ];
    let auc = auc_roc(&obs).unwrap();
    assert!((auc - 0.25).abs() < 1e-6, "anti-correlated interleave → AUC = 0.25; got {}", auc);
}

#[test]
fn balanced_classifier_auc_is_half() {
    // 1 pos at 0.3 + 1 neg at 0.3 (tie) — symmetric ties give AUC ≈ 0.5.
    let obs = vec![
        LabeledScore { score: 0.3, is_hallucination: true },
        LabeledScore { score: 0.3, is_hallucination: false },
    ];
    let auc = auc_roc(&obs).unwrap();
    // With a single tie pair, AUC counts the tie as 0.5.
    assert!((auc - 0.5).abs() < 1e-6, "single tied pair → AUC = 0.5; got {}", auc);
}

#[test]
fn inverted_classifier_auc_is_zero() {
    let obs = vec![
        LabeledScore { score: 0.9, is_hallucination: false },
        LabeledScore { score: 0.8, is_hallucination: false },
        LabeledScore { score: 0.2, is_hallucination: true },
        LabeledScore { score: 0.1, is_hallucination: true },
    ];
    let auc = auc_roc(&obs).unwrap();
    assert!(auc < 1e-6, "inverted → AUC = 0.0; got {}", auc);
}

#[test]
fn empty_observations_errors() {
    let obs: Vec<LabeledScore> = vec![];
    assert_eq!(auc_roc(&obs).unwrap_err(), SaeAucError::EmptyObservations);
}

#[test]
fn single_class_all_positive_errors() {
    let obs = vec![
        LabeledScore { score: 0.1, is_hallucination: true },
        LabeledScore { score: 0.5, is_hallucination: true },
    ];
    let err = auc_roc(&obs).unwrap_err();
    assert!(matches!(err, SaeAucError::SingleClass { is_hallucination: true, count: 2 }));
}

#[test]
fn single_class_all_negative_errors() {
    let obs = vec![
        LabeledScore { score: 0.1, is_hallucination: false },
        LabeledScore { score: 0.5, is_hallucination: false },
        LabeledScore { score: 0.9, is_hallucination: false },
    ];
    let err = auc_roc(&obs).unwrap_err();
    assert!(matches!(err, SaeAucError::SingleClass { is_hallucination: false, count: 3 }));
}

#[test]
fn nan_score_errors() {
    let obs = vec![
        LabeledScore { score: f32::NAN, is_hallucination: true },
        LabeledScore { score: 0.5, is_hallucination: false },
    ];
    let err = auc_roc(&obs).unwrap_err();
    assert!(matches!(err, SaeAucError::NonFiniteScore { index: 0, .. }));
}

#[test]
fn infinity_score_errors() {
    let obs = vec![
        LabeledScore { score: f32::INFINITY, is_hallucination: true },
        LabeledScore { score: 0.5, is_hallucination: false },
    ];
    let err = auc_roc(&obs).unwrap_err();
    assert!(matches!(err, SaeAucError::NonFiniteScore { .. }));
}

#[test]
fn gate_passes_at_0_90() {
    let obs = vec![
        LabeledScore { score: 0.1, is_hallucination: false },
        LabeledScore { score: 0.9, is_hallucination: true },
    ];
    let verdict = evaluate_against_gate(&obs).unwrap();
    assert!(verdict.passed(), "AUC = 1.0 must pass the 0.90 gate; got {:?}", verdict);
    assert!((verdict.auc() - 1.0).abs() < 1e-6);
    assert_eq!(verdict.gap_below_gate(), 0.0);
}

#[test]
fn gate_fails_when_auc_below() {
    let obs = vec![
        LabeledScore { score: 0.5, is_hallucination: false },
        LabeledScore { score: 0.4, is_hallucination: true }, // inverted
    ];
    let verdict = evaluate_against_gate(&obs).unwrap();
    assert!(verdict.is_below(), "AUC = 0.0 must fail the 0.90 gate; got {:?}", verdict);
    assert!(verdict.gap_below_gate() > 0.0);
}

#[test]
fn verdict_predicate_partition_is_strict_xor() {
    // For any verdict, exactly one of passed() or is_below() is true.
    let passed = SaeVerdict::GatePassed { auc: 0.95 };
    let below = SaeVerdict::BelowGate { auc: 0.5, gap: 0.4 };
    assert!(passed.passed() && !passed.is_below());
    assert!(!below.passed() && below.is_below());
}

#[test]
fn error_cause_strings_locked_for_observability() {
    assert_eq!(SaeAucError::EmptyObservations.cause(), "empty_observations");
    assert_eq!(
        SaeAucError::SingleClass { is_hallucination: true, count: 5 }.cause(),
        "single_class"
    );
    assert_eq!(
        SaeAucError::NonFiniteScore { index: 0, score: f32::NAN }.cause(),
        "non_finite_score"
    );
}

#[test]
fn gap_below_gate_invariant_matches_stored_gap() {
    let v = SaeVerdict::BelowGate { auc: 0.5, gap: 0.4 };
    assert!((v.gap_below_gate() - 0.4).abs() < 1e-6);
}
