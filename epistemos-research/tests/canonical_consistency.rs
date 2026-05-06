//! HELIOS V5 — Cross-module canonical consistency tests.
//!
//! HELIOS-CANONICAL-CONSISTENCY guard
//!
//! These integration tests catch canonical drift across the
//! Lane 3 epistemos-research substrate modules. Each test pins
//! a doctrinal invariant that should remain stable as long as
//! the canonical V5 lock holds.
//!
//! When any of these tests fail, the failure indicates EITHER:
//! - canonical drift (a substrate module changed away from doctrine), or
//! - explicit canon update (in which case the test must be updated
//!   in the same commit, with a docs/ change summarizing what
//!   moved).
//!
//! Lane 3 RESEARCH-ONLY. Built only under `--features research`.
#![cfg(feature = "research")]

use epistemos_research::{
    cross_domain_lens::{TSafetyBound, FIVE_LENSES},
    falsifier_actions::{FALSIFIER_TABLE, SIX_TERMS},
    mas_capability_lattice::{Capability, DeploymentTier, CAPABILITY_LATTICE},
    mathematical_pillars::{MathematicalPillar, FIVE_PILLARS},
    self_evolving_l_se::ALL_MECHANISMS,
    shadow_memory::{tier_codec, MemoryTier, ALL_TIERS},
    theorem_status::{TheoremStatus, FOUNDATIONAL_SEVEN},
    v6_1::{AttentionMode, V6_1Axis, ALL_AXES, ALL_LOCKS, VERIFIED_FLOOR_ANCHOR},
    validation_thresholds::{
        KL_DIVERGENCE_MAX, PEAK_RAM_GB_MAX, SEVEN_THRESHOLDS,
    },
    wbo_generations::{WboGeneration, ALL_GENERATIONS},
};

// ---------------------------------------------------------------------------
// V5/V6/V6.1 canon lock checks
// ---------------------------------------------------------------------------

#[test]
fn verified_floor_anchor_is_pinned_to_ac8c6d28() {
    // The Verified Floor commit anchor is the immutable carry-
    // forward per V6.1. Any change is HALT-class canon violation.
    assert_eq!(VERIFIED_FLOOR_ANCHOR, "ac8c6d28");
}

#[test]
fn v6_1_canonical_attention_mode_is_interrupt() {
    // V6.1 §1: "Attention is reframed as an interrupt, not a substrate."
    assert_eq!(AttentionMode::V6_1_CANONICAL, AttentionMode::Interrupt);
}

#[test]
fn current_wbo_generation_is_wbo7() {
    // V5 canon lock 2026-05-05: WBO-7 is current. Earlier
    // generations preserved verbatim per CANON_HARDENING_PROTOCOL.
    assert_eq!(WboGeneration::CURRENT, WboGeneration::Wbo7);
}

// ---------------------------------------------------------------------------
// Canonical-cardinality invariants — "five pillars", "seven thresholds", etc.
// ---------------------------------------------------------------------------

#[test]
fn five_pillars_cardinality_holds() {
    assert_eq!(FIVE_PILLARS.len(), 5);
}

#[test]
fn five_lenses_cardinality_holds() {
    // "Five names, one substance" koan.
    assert_eq!(FIVE_LENSES.len(), 5);
}

#[test]
fn seven_thresholds_cardinality_holds() {
    assert_eq!(SEVEN_THRESHOLDS.len(), 7);
}

#[test]
fn six_master_inequality_terms_cardinality_holds() {
    // WBO-6 has 6 terms; the falsifier table maps 1:1.
    assert_eq!(SIX_TERMS.len(), 6);
    assert_eq!(FALSIFIER_TABLE.len(), 6);
}

#[test]
fn five_tier_memory_hierarchy_cardinality_holds() {
    // Compass artifact §B.1: "canonical: 5-tier".
    assert_eq!(ALL_TIERS.len(), 5);
}

#[test]
fn six_v6_1_axes_cardinality_holds() {
    // V6.1 title-page slogan: 6 doctrinal axes.
    assert_eq!(ALL_AXES.len(), 6);
}

#[test]
fn four_canon_locks_cardinality_holds() {
    // V5 / V6 / V6.1 / VerifiedFloor.
    assert_eq!(ALL_LOCKS.len(), 4);
}

#[test]
fn four_lse_mechanisms_cardinality_holds() {
    // SEAL / TTT-Linear-MLP / Titans-MAC / Soft-Prompts-Mem0.
    assert_eq!(ALL_MECHANISMS.len(), 4);
}

#[test]
fn three_wbo_generations_cardinality_holds() {
    assert_eq!(ALL_GENERATIONS.len(), 3);
}

#[test]
fn twelve_capability_lattice_rows_cardinality_holds() {
    // mac_store_edition.md capability table: 12 capabilities.
    assert_eq!(CAPABILITY_LATTICE.len(), 12);
}

#[test]
fn seven_foundational_theorems_cardinality_holds() {
    // The Foundational Seven (E1..E7).
    assert_eq!(FOUNDATIONAL_SEVEN.len(), 7);
}

// ---------------------------------------------------------------------------
// Canonical-bound invariants — pinned numerics
// ---------------------------------------------------------------------------

#[test]
fn kl_divergence_threshold_is_zero_point_05() {
    assert_eq!(KL_DIVERGENCE_MAX, 0.05);
}

#[test]
fn peak_ram_gb_max_is_twelve_gb_for_m3_max_64gb() {
    assert_eq!(PEAK_RAM_GB_MAX, 12.0);
}

#[test]
fn t_safety_hard_constraint_ceiling_is_one_thousandth() {
    // helios_v3 §VI.2: hard-constitution constraints (bioweapons,
    // CSAM, direct physical harm) anchor at 1e-3.
    assert_eq!(TSafetyBound::HARD_CONSTRAINT_CEILING, 1e-3);
}

// ---------------------------------------------------------------------------
// Canonical-mapping invariants — cross-module relationships
// ---------------------------------------------------------------------------

#[test]
fn pillar_iii_anchors_leading_half_of_master_inequality() {
    // Cross-check: MathematicalPillar::SoftmaxHalfLipschitz IS the
    // leading ½ on the WBO-7 master inequality. The doctrine says
    // "Pillar III is the leading 1/2".
    assert_eq!(
        MathematicalPillar::SoftmaxHalfLipschitz.master_inequality_role(),
        "leading 1/2"
    );
}

#[test]
fn l1_compressed_residual_codec_is_sherry_per_pillar_l1() {
    // Cross-check: shadow_memory::tier_codec(L1CompressedResidual)
    // matches the canonical Sherry codec. Per the definitive
    // master + compass artifact: L1 uses Sherry 1.25-bit on the
    // residual stream.
    assert_eq!(
        tier_codec(MemoryTier::L1CompressedResidual),
        "sherry_1_25bit_on_residual"
    );
}

#[test]
fn l4_hermes_cascade_is_the_only_network_boundary() {
    // Cross-check: only L4 crosses the network boundary; L0/L1/L2
    // resident in unified RAM; L3 is SSD.
    let mut count = 0;
    for tier in ALL_TIERS {
        if tier.crosses_network_boundary() {
            count += 1;
            assert_eq!(tier, MemoryTier::L4HermesCascade);
        }
    }
    assert_eq!(count, 1);
}

#[test]
fn mas_baseline_capabilities_strictly_ship_in_mas_core() {
    // Cross-check: the 5 MAS-baseline capabilities (vault retrieval,
    // Touch ID, App Group, XPC helper, curated tool manifests) all
    // ship in MAS Core per the doctrine.
    let baseline = [
        Capability::SelectedVaultRetrieval,
        Capability::TouchIdGating,
        Capability::AppGroupSharedSubstrate,
        Capability::SandboxedXpcHelper,
        Capability::CuratedLocalToolManifests,
    ];
    for cap in baseline {
        let avail = cap.row().availability(DeploymentTier::MasCore);
        assert!(
            avail.ships(),
            "{:?} must ship in MAS Core (canonical baseline)",
            cap
        );
    }
}

#[test]
fn raw_ane_only_in_research_tier() {
    // Cross-check: Raw ANE / private frameworks is Research-only.
    let row = Capability::RawAneOrPrivateFrameworks.row();
    assert!(!row.mas_core.ships());
    assert!(!row.pro.ships());
    assert!(row.research.ships());
}

#[test]
fn proven_pillars_dont_require_falsifier() {
    // Cross-check: TheoremStatus::P (proven) does NOT require a
    // falsifier per house rule 2 (only EB / C do).
    assert!(!TheoremStatus::P.requires_falsifier());
    assert!(!TheoremStatus::EV.requires_falsifier());
    assert!(TheoremStatus::EB.requires_falsifier());
    assert!(TheoremStatus::C.requires_falsifier());
    assert!(!TheoremStatus::DROP.requires_falsifier());
}

// ---------------------------------------------------------------------------
// Canonical V6.1 axis invariants
// ---------------------------------------------------------------------------

#[test]
fn v6_1_axes_include_ssm_connectome_thinking_retrieval_brain_appstore() {
    // The 6 doctrinal axes from the V6.1 title page slogan.
    let expected_axes = [
        V6_1Axis::HybridSsm,
        V6_1Axis::ParameterConnectome,
        V6_1Axis::HeavyThinking,
        V6_1Axis::VectorlessRetrieval,
        V6_1Axis::BrainInspired,
        V6_1Axis::AppStoreNative,
    ];
    for axis in expected_axes {
        assert!(ALL_AXES.contains(&axis));
    }
}

#[test]
fn current_canon_lock_is_v6_1_strict_sharpening() {
    // V5 + V6 are preserved verbatim. V6.1 is strict sharpening.
    // The current canonical mode is V6.1 (Interrupt).
    let mode = AttentionMode::default();
    assert!(mode.is_v6_1_canonical());
}
