//! Source:
//! - `docs/fusion/EML_INTEGRATION_DOCTRINE_2026_05_17.md` §3.3 — the
//!   T7 §4.B MVP integration site (SAE Cognition Observatory anomaly
//!   augmentation).
//! - `docs/audits/EML_AUDIT_2026_05_17.md` — substrate state.
//! - Companions:
//!     - `agent_core/src/research/eml_integration/potential.rs`
//!     - `agent_core/src/research/eml_integration/observatory.rs`
//!     - `agent_core/src/research/cognition_observatory/sae.rs`
//!
//! Integration-test sibling to the in-module unit tests of
//! `eml_integration::observatory`. These tests exercise the public
//! `augment` / `auc_on_augmented` API across realistic SAE-shaped
//! workloads and pin the AUC-preserving cornerstone identity across
//! a wider distribution of inputs than the unit-test fixture.

#![cfg(feature = "research")]

use agent_core::research::cognition_observatory::sae::{
    auc_roc, evaluate_against_gate, LabeledScore, SaeAucError, SaeVerdict,
    SAE_DOCTRINE_AUC_BAR,
};
use agent_core::research::eml_integration::{
    auc_on_augmented, augment, AugmentError, AugmentedObservation, EmlPotential,
};

fn obs(score: f32, is_hallucination: bool) -> LabeledScore {
    LabeledScore { score, is_hallucination }
}

fn approx(a: f32, b: f32, tol: f32) -> bool {
    (a - b).abs() < tol
}

#[test]
fn augment_returns_same_count_as_input() {
    let v: Vec<LabeledScore> = (0..50)
        .map(|i| obs((i as f32) * 0.02, i % 3 == 0))
        .collect();
    let out: Vec<AugmentedObservation> = augment(&v).unwrap();
    assert_eq!(out.len(), v.len());
}

#[test]
fn augment_preserves_per_index_labels() {
    let v: Vec<LabeledScore> = (0..50)
        .map(|i| obs((i as f32) * 0.02, i % 3 == 0))
        .collect();
    let out: Vec<AugmentedObservation> = augment(&v).unwrap();
    for (i, (a, b)) in out.iter().zip(v.iter()).enumerate() {
        assert_eq!(a.is_hallucination, b.is_hallucination, "label drift at index {}", i);
    }
}

#[test]
fn auc_preservation_under_perfect_separation() {
    // s ∈ [0, 0.4] for negatives, [0.6, 1.0] for positives — perfect.
    let mut v: Vec<LabeledScore> =
        (0..20).map(|i| obs((i as f32) * 0.02, false)).collect();
    v.extend((0..20).map(|i| obs(0.6 + (i as f32) * 0.02, true)));

    let raw = auc_roc(&v).unwrap();
    let aug = auc_on_augmented(&v).unwrap();
    assert!(approx(raw, aug, 1e-5),
        "raw_auc={} aug_auc={}", raw, aug);
    assert!((raw - 1.0).abs() < 1e-5);
}

#[test]
fn auc_preservation_under_partial_overlap() {
    // Mixed band. AUC should be substantially > 0.5 but < 1.0.
    let v: Vec<LabeledScore> = vec![
        obs(0.05, false), obs(0.10, false), obs(0.20, false), obs(0.30, false),
        obs(0.25, true),  obs(0.35, true),  obs(0.55, true),  obs(0.65, true),
        obs(0.45, false), obs(0.75, true),  obs(0.85, true),  obs(0.95, true),
    ];
    let raw = auc_roc(&v).unwrap();
    let aug = auc_on_augmented(&v).unwrap();
    assert!(approx(raw, aug, 1e-5));
    assert!(raw > 0.6 && raw < 1.0, "AUC = {} out of expected band", raw);
}

#[test]
fn auc_preservation_under_perfect_inversion() {
    // Inverted: positives have low scores, negatives high.
    let mut v: Vec<LabeledScore> =
        (0..15).map(|i| obs((i as f32) * 0.03, true)).collect();
    v.extend((0..15).map(|i| obs(0.5 + (i as f32) * 0.03, false)));
    let raw = auc_roc(&v).unwrap();
    let aug = auc_on_augmented(&v).unwrap();
    assert!(approx(raw, aug, 1e-5));
    assert!(raw.abs() < 1e-5);
}

#[test]
fn cornerstone_holds_across_random_distributions() {
    // Multiple distinct distributions; AUC-preservation must hold for
    // each. Deterministic seeds via linear-congruential generation for
    // reproducibility (no rand crate dependency).
    for seed_offset in 0..5_usize {
        let mut state: u64 = 0x9E3779B97F4A7C15_u64.wrapping_add(seed_offset as u64);
        let mut v = Vec::with_capacity(64);
        for i in 0..64 {
            state = state.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            let r = (state >> 33) as u32;
            let score = (r as f32) / (u32::MAX as f32);
            v.push(obs(score, (i + seed_offset) % 2 == 0));
        }
        let raw = auc_roc(&v).unwrap();
        let aug = auc_on_augmented(&v).unwrap();
        assert!(approx(raw, aug, 1e-4),
            "seed_offset={}: raw={} aug={}", seed_offset, raw, aug);
    }
}

#[test]
fn augmented_potential_values_are_monotone_in_raw() {
    // Across a sorted slice, augmented values must be sorted too.
    let mut v: Vec<LabeledScore> =
        (0..30).map(|i| obs(0.01 + (i as f32) * 0.03, i % 2 == 0)).collect();
    // Already sorted by score (construction).
    let out = augment(&v).unwrap();
    for w in out.windows(2) {
        assert!(w[0].potential.value() <= w[1].potential.value(),
            "non-monotone: {} > {}", w[0].potential.value(), w[1].potential.value());
    }
    // Reverse-sorted should reverse-sort the potentials too.
    v.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap());
    let out_rev = augment(&v).unwrap();
    for w in out_rev.windows(2) {
        assert!(w[0].potential.value() >= w[1].potential.value());
    }
}

#[test]
fn augment_rejects_negative_at_first_negative_index() {
    let v = vec![obs(0.1, false), obs(0.5, true), obs(-0.001, false), obs(0.9, true)];
    let err = augment(&v).unwrap_err();
    match err {
        AugmentError::Potential { index, .. } => assert_eq!(index, 2),
        other => panic!("expected Potential at index 2, got {:?}", other),
    }
}

#[test]
fn evaluate_gate_with_augmented_scores_gives_same_verdict() {
    // Same passing fixture as sae::tests::gate_passes_when_auc_meets_pin
    // but routed through the augmented AUC. Verdict must match.
    let v = vec![
        obs(0.05, false), obs(0.10, false), obs(0.15, false), obs(0.20, false),
        obs(0.21, true),  obs(0.85, true),  obs(0.90, true),  obs(0.95, true),
    ];
    let raw_verdict = evaluate_against_gate(&v).unwrap();
    let aug_auc = auc_on_augmented(&v).unwrap();
    assert!(raw_verdict.passed());
    assert!(aug_auc >= SAE_DOCTRINE_AUC_BAR,
        "aug_auc = {} below pin = {}", aug_auc, SAE_DOCTRINE_AUC_BAR);
}

#[test]
fn cornerstone_holds_with_tied_scores() {
    // Ties produce averaged ranks in auc_roc; the augmented values
    // for tied raw scores are themselves tied (deterministic encoding),
    // so the averaged-rank path is exercised identically.
    let v = vec![
        obs(0.5, true), obs(0.5, false), obs(0.5, true), obs(0.5, false),
    ];
    let raw = auc_roc(&v).unwrap();
    let aug = auc_on_augmented(&v).unwrap();
    assert!(approx(raw, aug, 1e-5));
    assert!(approx(raw, 0.5, 1e-5));
}

#[test]
fn augment_handles_two_class_minimum() {
    // Smallest possible non-degenerate set: 1 positive + 1 negative.
    let v = vec![obs(0.1, false), obs(0.9, true)];
    let out = augment(&v).unwrap();
    assert_eq!(out.len(), 2);
    let aug = auc_on_augmented(&v).unwrap();
    assert!(approx(aug, 1.0, 1e-5));
}

#[test]
fn augment_propagates_single_class_when_routed_through_auc() {
    let v = vec![obs(0.1, false), obs(0.5, false), obs(0.9, false)];
    let err = auc_on_augmented(&v).unwrap_err();
    matches!(err, AugmentError::Auc(SaeAucError::SingleClass { .. }));
}

#[test]
fn potential_value_for_score_at_one_matches_two_minus_ln_two() {
    // Cross-verify the canonical sentinel value referenced in the
    // diagnostic surface (see eml_integration::diagnostic).
    let p = EmlPotential::from_score(1.0).unwrap();
    let expected = 2.0_f64 - 2.0_f64.ln();
    assert!((p.value() - expected).abs() < 1e-12);
}

#[test]
fn verdict_comparison_under_below_gate_still_below() {
    // Weak separation → BelowGate on raw → still BelowGate after augment.
    let v = vec![
        obs(0.1, true), obs(0.2, false), obs(0.3, true), obs(0.4, false),
    ];
    let raw_v = evaluate_against_gate(&v).unwrap();
    let aug_auc = auc_on_augmented(&v).unwrap();
    assert!(matches!(raw_v, SaeVerdict::BelowGate { .. }));
    assert!(aug_auc < SAE_DOCTRINE_AUC_BAR,
        "aug_auc = {} should be below pin", aug_auc);
}
