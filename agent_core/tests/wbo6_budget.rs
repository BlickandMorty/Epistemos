use agent_core::{
    resonance::{
        compute_signature_core, Claim, ClaimRef, ClaimType, ResidencyLevel, ResonanceSignatureCore,
        Truth,
    },
    wbo6::{
        kl_divergence, kl_divergence_from_logits, resonance_core_budget_terms, softmax, Wbo6Budget,
        Wbo6Error, Wbo6Term, Wbo6Terms, CORE_RESONANCE_TERM_R,
    },
};

fn empirical(evidence_count: u32) -> Claim {
    Claim {
        kind: ClaimType::Empirical,
        statement: "A measured local-runtime claim.".into(),
        dependencies: vec![],
        evidence_count,
    }
}

#[test]
fn term_codes_match_canonical_wbo6_order() {
    assert_eq!(Wbo6Term::ALL.len(), 6);
    let codes: Vec<_> = Wbo6Term::ALL.iter().map(|term| term.code()).collect();
    assert_eq!(codes, ["T_W", "T_K", "T_R", "T_Q", "T_S", "T_SE"]);
}

#[test]
fn terms_reject_nonfinite_and_negative_values() {
    assert_eq!(
        Wbo6Terms::new(0.0, 0.0, f64::NAN, 0.0, 0.0, 0.0),
        Err(Wbo6Error::InvalidTerm)
    );
    assert_eq!(
        Wbo6Terms::from_pairs([(Wbo6Term::KvCache, -0.1)]),
        Err(Wbo6Error::InvalidTerm)
    );
}

#[test]
fn total_bound_uses_half_softmax_constant() {
    let terms = Wbo6Terms::new(1.0, 1.0, 1.0, 1.0, 1.0, 1.0).unwrap();
    let budget = Wbo6Budget::new(terms);

    assert_eq!(budget.bound().unwrap(), 3.0);
}

#[test]
fn evaluation_records_margin_and_pass_flag() {
    let terms = Wbo6Terms::new(0.1, 0.1, 0.1, 0.1, 0.1, 0.1).unwrap();
    let evaluation = Wbo6Budget::new(terms).evaluate(0.2).unwrap();

    assert!(evaluation.passed);
    assert!((evaluation.bound - 0.3).abs() < 1.0e-12);
    assert!(evaluation.margin > 0.0);
}

#[test]
fn evaluation_fails_when_measured_drift_exceeds_bound() {
    let terms = Wbo6Terms::new(0.02, 0.02, 0.02, 0.02, 0.02, 0.02).unwrap();
    let evaluation = Wbo6Budget::new(terms).evaluate(0.2).unwrap();

    assert!(!evaluation.passed);
    assert!(evaluation.margin < 0.0);
}

#[test]
fn softmax_is_stable_for_large_logits() {
    let probs = softmax(&[1_000.0, 1_001.0, 1_002.0]).unwrap();
    let sum: f64 = probs.iter().sum();

    assert!((sum - 1.0).abs() < 1.0e-12);
    assert!(probs[2] > probs[1]);
    assert!(probs[1] > probs[0]);
}

#[test]
fn kl_zero_for_identical_probability_vectors() {
    let kl = kl_divergence(&[0.25, 0.75], &[0.25, 0.75]).unwrap();

    assert!(kl.abs() < 1.0e-12);
}

#[test]
fn kl_from_logits_detects_candidate_drift() {
    let identical = kl_divergence_from_logits(&[1.0, 2.0, 3.0], &[1.0, 2.0, 3.0]).unwrap();
    let drifted = kl_divergence_from_logits(&[1.0, 2.0, 3.0], &[3.0, 2.0, 1.0]).unwrap();

    assert!(identical < 1.0e-12);
    assert!(drifted > identical);
}

#[test]
fn kl_rejects_dimension_mismatch_after_validation() {
    assert_eq!(
        kl_divergence(&[0.5, 0.5], &[1.0]),
        Err(Wbo6Error::DimensionMismatch {
            reference: 2,
            candidate: 1
        })
    );
}

#[test]
fn core_resonance_signature_consumes_only_t_r() {
    let signature = compute_signature_core(&empirical(3));
    let terms = resonance_core_budget_terms(&signature);

    assert_eq!(terms.get(Wbo6Term::Resonance), CORE_RESONANCE_TERM_R);
    assert_eq!(terms.get(Wbo6Term::WeightRuntime), 0.0);
    assert_eq!(terms.get(Wbo6Term::KvCache), 0.0);
    assert_eq!(terms.get(Wbo6Term::Quantization), 0.0);
    assert_eq!(terms.get(Wbo6Term::SubstrateBoundary), 0.0);
    assert_eq!(terms.get(Wbo6Term::SovereignSecurity), 0.0);
}

#[test]
fn blocked_resonance_signature_gets_zero_display_budget() {
    let blocked = ResonanceSignatureCore {
        truth: Truth::False,
        class: agent_core::resonance::ClaimClass::Composite,
        residency: ResidencyLevel::L7Quarantine,
    };

    assert_eq!(resonance_core_budget_terms(&blocked), Wbo6Terms::zero());
}

#[test]
fn pro_research_resonance_signature_gets_zero_core_budget() {
    let pro_only = ResonanceSignatureCore {
        truth: Truth::True,
        class: agent_core::resonance::ClaimClass::Prime,
        residency: ResidencyLevel::L4Engram,
    };

    assert_eq!(resonance_core_budget_terms(&pro_only), Wbo6Terms::zero());
}

#[test]
fn composite_claim_budget_evaluates_inside_seed_bound() {
    let claim = Claim {
        kind: ClaimType::Composite,
        statement: "Composite reasoning with dependencies.".into(),
        dependencies: vec![ClaimRef(1), ClaimRef(2)],
        evidence_count: 1,
    };
    let signature = compute_signature_core(&claim);
    let budget = Wbo6Budget::new(resonance_core_budget_terms(&signature));

    assert!(budget.evaluate(0.0).unwrap().passed);
}
