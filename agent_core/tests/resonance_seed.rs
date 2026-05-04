//! Resonance Gate τ + π + λ daemon seed — integration tests.
//!
//! Validates the public API surface of `agent_core::resonance` against
//! doctrine §4.1 invariants and the seed mapping rules. CPU-only,
//! synchronous, no external dependencies — the same test surface a
//! future Pro / Research extension can rely on.

use agent_core::resonance::{
    classify, compute_signature_core, evaluate_truth, target_residency, Claim, ClaimClass,
    ClaimRef, ClaimType, ResidencyLevel, ResonanceSignatureCore, Truth,
};

// ---------- Test fixtures ----------

fn definition() -> Claim {
    Claim {
        kind: ClaimType::Definition,
        statement: "A graph is a set of nodes and edges.".into(),
        dependencies: vec![],
        evidence_count: 0,
    }
}

fn empirical(evidence: u32) -> Claim {
    Claim {
        kind: ClaimType::Empirical,
        statement: "ANE outperforms GPU on int8 inference.".into(),
        dependencies: vec![],
        evidence_count: evidence,
    }
}

fn composite(dep_count: usize) -> Claim {
    Claim {
        kind: ClaimType::Composite,
        statement: "Aggregate from prime claims.".into(),
        dependencies: (0..dep_count as u64).map(ClaimRef).collect(),
        evidence_count: 1,
    }
}

// ---------- τ — Kleene K3 ----------

#[test]
fn truth_int_encoding_matches_doctrine() {
    assert_eq!(Truth::True.as_int(), 1);
    assert_eq!(Truth::Unknown.as_int(), 0);
    assert_eq!(Truth::False.as_int(), -1);
}

#[test]
fn truth_kleene_k3_double_negation() {
    for v in [Truth::True, Truth::Unknown, Truth::False] {
        assert_eq!(v.not().not(), v, "double-negation failed for {:?}", v);
    }
}

#[test]
fn truth_kleene_k3_and_truth_table() {
    use Truth::*;
    // False is absorbing
    assert_eq!(False.and(True), False);
    assert_eq!(False.and(Unknown), False);
    assert_eq!(False.and(False), False);
    // True ∧ True = True
    assert_eq!(True.and(True), True);
    // Unknown ∧ True = Unknown
    assert_eq!(Unknown.and(True), Unknown);
    // Unknown ∧ Unknown = Unknown
    assert_eq!(Unknown.and(Unknown), Unknown);
}

#[test]
fn truth_kleene_k3_or_truth_table() {
    use Truth::*;
    // True is absorbing
    assert_eq!(True.or(False), True);
    assert_eq!(True.or(Unknown), True);
    assert_eq!(True.or(True), True);
    // False ∨ False = False
    assert_eq!(False.or(False), False);
    // Unknown ∨ False = Unknown
    assert_eq!(Unknown.or(False), Unknown);
    // Unknown ∨ Unknown = Unknown
    assert_eq!(Unknown.or(Unknown), Unknown);
}

#[test]
fn truth_kleene_k3_operators_commutative() {
    for a in [Truth::True, Truth::Unknown, Truth::False] {
        for b in [Truth::True, Truth::Unknown, Truth::False] {
            assert_eq!(
                a.and(b),
                b.and(a),
                "AND not commutative for {:?} {:?}",
                a,
                b
            );
            assert_eq!(a.or(b), b.or(a), "OR not commutative for {:?} {:?}", a, b);
        }
    }
}

#[test]
fn truth_definitions_are_tautologically_true() {
    assert_eq!(evaluate_truth(&definition()), Truth::True);
}

#[test]
fn truth_empirical_promotes_with_evidence_threshold() {
    assert_eq!(evaluate_truth(&empirical(0)), Truth::Unknown);
    assert_eq!(evaluate_truth(&empirical(1)), Truth::Unknown);
    assert_eq!(evaluate_truth(&empirical(2)), Truth::Unknown);
    assert_eq!(evaluate_truth(&empirical(3)), Truth::True);
    assert_eq!(evaluate_truth(&empirical(100)), Truth::True);
}

#[test]
fn truth_structurally_invalid_composite_is_false() {
    let bad = composite(0); // composite with no dependencies
    assert_eq!(evaluate_truth(&bad), Truth::False);
}

#[test]
fn truth_unverifiable_seed_types_default_to_unknown() {
    for kind in [
        ClaimType::Equation,
        ClaimType::Inequality,
        ClaimType::Causal,
        ClaimType::CodeInvariant,
        ClaimType::Prime,
        ClaimType::Gap,
    ] {
        let claim = Claim {
            kind,
            statement: "seed".into(),
            dependencies: vec![],
            evidence_count: 0,
        };
        assert_eq!(
            evaluate_truth(&claim),
            Truth::Unknown,
            "{:?} should defer to Unknown in the seed",
            kind
        );
    }
}

// ---------- π — prime / composite / gap classification ----------

#[test]
fn pi_nine_claim_types_enumerated_per_doctrine() {
    assert_eq!(ClaimType::ALL.len(), 9);
    // Spot-check the doctrine-listed types are present.
    assert!(ClaimType::ALL.contains(&ClaimType::Equation));
    assert!(ClaimType::ALL.contains(&ClaimType::Inequality));
    assert!(ClaimType::ALL.contains(&ClaimType::Causal));
    assert!(ClaimType::ALL.contains(&ClaimType::Definition));
    assert!(ClaimType::ALL.contains(&ClaimType::Empirical));
    assert!(ClaimType::ALL.contains(&ClaimType::CodeInvariant));
    assert!(ClaimType::ALL.contains(&ClaimType::Prime));
    assert!(ClaimType::ALL.contains(&ClaimType::Composite));
    assert!(ClaimType::ALL.contains(&ClaimType::Gap));
}

#[test]
fn pi_definition_classifies_as_prime() {
    assert_eq!(classify(&definition()), ClaimClass::Prime);
}

#[test]
fn pi_lone_evidenced_claim_classifies_as_prime() {
    assert_eq!(classify(&empirical(5)), ClaimClass::Prime);
}

#[test]
fn pi_no_evidence_no_dependencies_classifies_as_gap() {
    assert_eq!(classify(&empirical(0)), ClaimClass::Gap);
}

#[test]
fn pi_two_or_more_dependencies_classifies_as_composite() {
    assert_eq!(classify(&composite(2)), ClaimClass::Composite);
    assert_eq!(classify(&composite(5)), ClaimClass::Composite);
}

#[test]
fn pi_ontological_inputs_short_circuit_to_their_class() {
    let prime_input = Claim {
        kind: ClaimType::Prime,
        statement: "x".into(),
        dependencies: vec![ClaimRef(1), ClaimRef(2), ClaimRef(3)], // ignored
        evidence_count: 0,
    };
    assert_eq!(classify(&prime_input), ClaimClass::Prime);

    let gap_input = Claim {
        kind: ClaimType::Gap,
        statement: "x".into(),
        dependencies: vec![ClaimRef(1), ClaimRef(2)], // also ignored
        evidence_count: 100,
    };
    assert_eq!(classify(&gap_input), ClaimClass::Gap);
}

// ---------- λ — residency target (Core caps L0–L3 + L7) ----------

#[test]
fn lambda_core_allowed_set_excludes_pro_research() {
    assert_eq!(ResidencyLevel::CORE_ALLOWED.len(), 5);
    for lvl in ResidencyLevel::CORE_ALLOWED {
        assert!(lvl.is_core_allowed(), "{:?} should be Core-allowed", lvl);
        assert!(
            !lvl.requires_pro_or_research(),
            "{:?} should not require Pro/Research",
            lvl
        );
    }
}

#[test]
fn lambda_pro_research_levels_are_gated() {
    for lvl in [
        ResidencyLevel::L4Engram,
        ResidencyLevel::L5Adapter,
        ResidencyLevel::L6Forbidden,
    ] {
        assert!(!lvl.is_core_allowed(), "{:?} must NOT be Core-allowed", lvl);
        assert!(
            lvl.requires_pro_or_research(),
            "{:?} must require Pro/Research",
            lvl
        );
    }
}

#[test]
fn lambda_residency_level_ordering_is_hot_to_cold_to_quarantine() {
    assert!(ResidencyLevel::L0Working < ResidencyLevel::L1Recent);
    assert!(ResidencyLevel::L3Cold < ResidencyLevel::L4Engram);
    assert!(ResidencyLevel::L6Forbidden < ResidencyLevel::L7Quarantine);
}

#[test]
fn lambda_structurally_invalid_composite_quarantines() {
    let bad = composite(0);
    assert_eq!(target_residency(&bad), ResidencyLevel::L7Quarantine);
}

#[test]
fn lambda_definition_targets_warm_cache() {
    assert_eq!(target_residency(&definition()), ResidencyLevel::L2Warm);
}

#[test]
fn lambda_empirical_residency_tracks_evidence() {
    assert_eq!(target_residency(&empirical(0)), ResidencyLevel::L3Cold);
    assert_eq!(target_residency(&empirical(2)), ResidencyLevel::L3Cold);
    assert_eq!(target_residency(&empirical(3)), ResidencyLevel::L1Recent);
    assert_eq!(target_residency(&empirical(99)), ResidencyLevel::L1Recent);
}

#[test]
fn lambda_seed_never_emits_a_pro_research_residency() {
    // Doctrine §3 + §6 hard forbidden list: a Core path must never
    // emit L4–L6 without explicit Pro/Research entitlement. The seed
    // never has access to those entitlements, so every input must map
    // to a Core-allowed level.
    for kind in ClaimType::ALL {
        for evidence in [0, 1, 2, 3, 5, 100] {
            for dep_count in [0, 1, 2, 3] {
                let claim = Claim {
                    kind,
                    statement: "sweep".into(),
                    dependencies: (0..dep_count as u64).map(ClaimRef).collect(),
                    evidence_count: evidence,
                };
                let lvl = target_residency(&claim);
                assert!(
                    lvl.is_core_allowed(),
                    "Core seed emitted Pro/Research level {:?} for kind={:?} evidence={} deps={}",
                    lvl,
                    kind,
                    evidence,
                    dep_count
                );
            }
        }
    }
}

// ---------- Σ-core signature assembly ----------

#[test]
fn signature_assembly_is_a_pure_function() {
    let claim = definition();
    let s1 = compute_signature_core(&claim);
    let s2 = compute_signature_core(&claim);
    assert_eq!(s1, s2, "same input must yield identical signature");
    assert_eq!(s1.truth, Truth::True);
    assert_eq!(s1.class, ClaimClass::Prime);
    assert_eq!(s1.residency, ResidencyLevel::L2Warm);
}

#[test]
fn signature_passes_truth_invariant_unless_false() {
    let true_sig = ResonanceSignatureCore {
        truth: Truth::True,
        class: ClaimClass::Prime,
        residency: ResidencyLevel::L1Recent,
    };
    let unknown_sig = ResonanceSignatureCore {
        truth: Truth::Unknown,
        class: ClaimClass::Gap,
        residency: ResidencyLevel::L3Cold,
    };
    let false_sig = ResonanceSignatureCore {
        truth: Truth::False,
        class: ClaimClass::Composite,
        residency: ResidencyLevel::L7Quarantine,
    };
    assert!(true_sig.passes_truth_invariant());
    assert!(unknown_sig.passes_truth_invariant());
    assert!(
        !false_sig.passes_truth_invariant(),
        "doctrine §4.1 invariant 1: τ = -1 must NOT pass"
    );
}

#[test]
fn signature_core_compatibility_rejects_pro_research_residency() {
    let pro_leak = ResonanceSignatureCore {
        truth: Truth::True,
        class: ClaimClass::Prime,
        residency: ResidencyLevel::L4Engram,
    };
    assert!(
        !pro_leak.is_core_compatible(),
        "Core build must reject signatures that demand Pro/Research residency"
    );

    let core_ok = ResonanceSignatureCore {
        truth: Truth::True,
        class: ClaimClass::Prime,
        residency: ResidencyLevel::L1Recent,
    };
    assert!(core_ok.is_core_compatible());
}

#[test]
fn signature_full_sweep_never_emits_pro_research_for_default_seed_inputs() {
    // The doctrine §3 invariant — a Core seed must never produce a
    // signature that demands Pro / Research residency. Sweep every
    // input shape the seed accepts and assert.
    for kind in ClaimType::ALL {
        for evidence in [0, 3, 10] {
            for deps in [0, 1, 3] {
                let claim = Claim {
                    kind,
                    statement: "sweep".into(),
                    dependencies: (0..deps as u64).map(ClaimRef).collect(),
                    evidence_count: evidence,
                };
                let sig = compute_signature_core(&claim);
                assert!(
                    sig.is_core_compatible(),
                    "Core seed emitted non-Core signature {:?} for kind={:?} evidence={} deps={}",
                    sig,
                    kind,
                    evidence,
                    deps
                );
            }
        }
    }
}

// ---------- Serde round-trip (FFI bridge contract) ----------

#[test]
fn claim_serde_round_trips() {
    let claim = Claim {
        kind: ClaimType::Empirical,
        statement: "ANE outperforms GPU on int8".into(),
        dependencies: vec![ClaimRef(7), ClaimRef(13)],
        evidence_count: 5,
    };
    let json = serde_json::to_string(&claim).expect("encode claim");
    let decoded: Claim = serde_json::from_str(&json).expect("decode claim");
    assert_eq!(claim, decoded, "Claim round-trip must be identity");
}

#[test]
fn signature_serde_round_trips() {
    let sig = ResonanceSignatureCore {
        truth: Truth::True,
        class: ClaimClass::Prime,
        residency: ResidencyLevel::L1Recent,
    };
    let json = serde_json::to_string(&sig).expect("encode signature");
    let decoded: ResonanceSignatureCore = serde_json::from_str(&json).expect("decode signature");
    assert_eq!(
        sig, decoded,
        "ResonanceSignatureCore round-trip must be identity"
    );
}

#[test]
fn ffi_compute_resonance_signature_core_round_trips() {
    let claim = Claim {
        kind: ClaimType::Definition,
        statement: "A graph is a set of nodes and edges.".into(),
        dependencies: vec![],
        evidence_count: 0,
    };
    let claim_json = serde_json::to_string(&claim).expect("encode claim");
    let result = agent_core::bridge::compute_resonance_signature_core(claim_json);
    let signature_json = result.expect("FFI must succeed for a well-formed claim");
    let signature: ResonanceSignatureCore =
        serde_json::from_str(&signature_json).expect("decode signature");
    assert_eq!(signature.truth, Truth::True);
    assert_eq!(signature.class, ClaimClass::Prime);
    assert_eq!(signature.residency, ResidencyLevel::L2Warm);
}

#[test]
fn ffi_compute_resonance_signature_core_rejects_garbage() {
    let result = agent_core::bridge::compute_resonance_signature_core("{this is not json}".into());
    assert!(result.is_err(), "FFI must error on invalid JSON");
}
