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
    agent_swarm::{
        AgentMessageContract, AgentMessageSignature, FIVE_BUDGET_AXES,
        HERMES_ARENA_BYTES, THREE_HERMES_OUTCOMES,
    },
    cargo_features::{CanonicalFeature, NINE_FEATURES},
    cross_domain_lens::{TSafetyBound, FIVE_LENSES},
    engram::{RECOMMENDED_STATIC_FRACTION_MAX, RECOMMENDED_STATIC_FRACTION_MIN},
    falsifier_actions::{FALSIFIER_TABLE, SIX_TERMS},
    gate_action::{
        GateAction, ENGRAM_KAPPA_THRESHOLD, ENGRAM_RHO_THRESHOLD,
        SELF_MONITORING_MAX_DEPTH, SIX_ACTIONS,
    },
    kv_direct_gate::{D_KL_THRESHOLD, PEAK_RAM_REDUCTION_FACTOR_MIN},
    learning_modes::{Direction, LearningMode, FOUR_LEARNING_MODES, SIX_DIRECTIONS},
    mas_capability_lattice::{Capability, DeploymentTier, CAPABILITY_LATTICE},
    mathematical_pillars::{MathematicalPillar, FIVE_PILLARS},
    scientific_calculator_basis::{total_scb_size, SIX_CATEGORIES, TWO_PRODUCTIONS},
    self_evolving_l_se::ALL_MECHANISMS,
    shadow_memory::{tier_codec, MemoryTier, ALL_TIERS},
    sherry::{BLOCK_WIDTH, CONFIG_SPACE_SIZE, NONZERO_PER_BLOCK},
    stack_roles::{ALL_ROLES, ReferenceCheckpoint, StackRole},
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

// ---------------------------------------------------------------------------
// Cardinality invariants for newer modules (Stages 49-57)
// ---------------------------------------------------------------------------

#[test]
fn six_scb_categories_total_23_members() {
    // From eml_formal_synthesis.md §1.1: 6+4+2+5+3+3 = 23.
    assert_eq!(SIX_CATEGORIES.len(), 6);
    assert_eq!(total_scb_size(), 23);
}

#[test]
fn two_eml_grammar_productions_canonical() {
    // Grammar S → 1 | eml(S, S) — exactly 2 productions.
    assert_eq!(TWO_PRODUCTIONS.len(), 2);
}

#[test]
fn six_gate_actions_canonical() {
    // ResonanceGate: Pass / Hold / Quarantine /
    // TriggerEvidenceSupremacy / EngramAnchor / MigrateResidency.
    assert_eq!(SIX_ACTIONS.len(), 6);
}

#[test]
fn three_stack_roles_canonical() {
    // RustSpine / MlxHand / MetalNerves anatomical metaphor.
    assert_eq!(ALL_ROLES.len(), 3);
}

#[test]
fn four_learning_modes_canonical() {
    // Freeze / FastWeight / LoRa / Sketch.
    assert_eq!(FOUR_LEARNING_MODES.len(), 4);
}

#[test]
fn six_directions_canonical() {
    // Upward / Downward / Sideways / Inward / OnItself / None.
    assert_eq!(SIX_DIRECTIONS.len(), 6);
}

#[test]
fn five_task_budget_axes_canonical() {
    // MaxTokens / MaxCost / MaxTime / MinResonance / Deadline.
    assert_eq!(FIVE_BUDGET_AXES.len(), 5);
}

#[test]
fn three_hermes_verification_outcomes_canonical() {
    // VerifiedPromote / EdgeTriggerEsp / ContradictedQuarantine.
    assert_eq!(THREE_HERMES_OUTCOMES.len(), 3);
}

#[test]
fn nine_cargo_features_canonical() {
    // Metal / Mlx (default) / Ane / Ssm / Ttt / SelfTuning /
    // Vault / Hermes (Pro) / Bench.
    assert_eq!(NINE_FEATURES.len(), 9);
}

// ---------------------------------------------------------------------------
// Pinned-bound invariants for newer modules
// ---------------------------------------------------------------------------

#[test]
fn kv_direct_d_kl_threshold_is_zero() {
    // Per Qasim Theorem 1: greedy token-identical match means
    // D_KL == 0.0 exactly.
    assert_eq!(D_KL_THRESHOLD, 0.0);
}

#[test]
fn kv_direct_ram_reduction_factor_min_is_8() {
    // Per helios_v3 §V: peak-RAM reduction ≥ 8× for PASS.
    assert_eq!(PEAK_RAM_REDUCTION_FACTOR_MIN, 8.0);
}

#[test]
fn engram_thresholds_match_resonance_gate_canon() {
    // Hard invariant 3: ρ > 0.7 + κ > 0.382 → Engram anchor.
    assert_eq!(ENGRAM_RHO_THRESHOLD, 0.7);
    assert_eq!(ENGRAM_KAPPA_THRESHOLD, 0.382);
    assert_eq!(SELF_MONITORING_MAX_DEPTH, 3);
}

#[test]
fn engram_static_fraction_range_is_canonical() {
    // Sparsity Allocation Law: 20-25% recommended (heuristic).
    assert_eq!(RECOMMENDED_STATIC_FRACTION_MIN, 0.20);
    assert_eq!(RECOMMENDED_STATIC_FRACTION_MAX, 0.25);
}

#[test]
fn sherry_block_width_and_config_space_match_doctrine() {
    // Sherry: 4 weights / 5 bits / 32-config space.
    assert_eq!(BLOCK_WIDTH, 4);
    assert_eq!(NONZERO_PER_BLOCK, 3);
    assert_eq!(CONFIG_SPACE_SIZE, 32);
}

#[test]
fn hermes_arena_size_canonical_200kb() {
    assert_eq!(HERMES_ARENA_BYTES, 200 * 1024);
}

// ---------------------------------------------------------------------------
// Cross-module mapping invariants for newer substrate
// ---------------------------------------------------------------------------

#[test]
fn pillar_v_eml_grammar_has_canonical_two_productions() {
    // Pillar V (eml-operator universal) anchors the 2-production
    // grammar S → 1 | eml(S, S). The substrate must be consistent.
    let _ = MathematicalPillar::EmlOperatorUniversal;
    assert_eq!(TWO_PRODUCTIONS.len(), 2);
}

#[test]
fn only_pass_among_gate_actions_emits_to_user() {
    // Hard invariant 1: no τ = -1 reaches user. Only Pass emits.
    let mut count = 0;
    for action in SIX_ACTIONS {
        if action.emits_to_user() {
            count += 1;
            assert_eq!(action, GateAction::Pass);
        }
    }
    assert_eq!(count, 1);
}

#[test]
fn metal_and_mlx_are_default_features() {
    // Per build-prompt §4.3: default = ["metal", "mlx"].
    assert!(CanonicalFeature::Metal.is_default());
    assert!(CanonicalFeature::Mlx.is_default());
    // Other 7 features are not default.
    let default_count = NINE_FEATURES.iter().filter(|f| f.is_default()).count();
    assert_eq!(default_count, 2);
}

#[test]
fn metal_nerves_is_only_bandwidth_critical_role() {
    // Stack-role spine/hand/nerves anatomy: only nerves is
    // bandwidth-critical.
    let bw_count = ALL_ROLES.iter().filter(|r| r.is_bandwidth_critical()).count();
    assert_eq!(bw_count, 1);
    assert!(StackRole::MetalNerves.is_bandwidth_critical());
}

#[test]
fn freeze_is_only_frozen_learning_mode() {
    let frozen_count = FOUR_LEARNING_MODES.iter().filter(|m| m.is_frozen()).count();
    assert_eq!(frozen_count, 1);
    assert!(LearningMode::Freeze.is_frozen());
}

#[test]
fn upward_and_downward_are_only_vertical_directions() {
    let vertical_count = SIX_DIRECTIONS.iter().filter(|d| d.is_vertical()).count();
    assert_eq!(vertical_count, 2);
    assert!(Direction::Upward.is_vertical());
    assert!(Direction::Downward.is_vertical());
}

#[test]
fn agent_message_canonical_contract_matches_three_properties() {
    // Per build-prompt §2.4: Ed25519 signed + capability granted +
    // resonance classified. All three required for canonical.
    let canonical = AgentMessageContract {
        signature: AgentMessageSignature::Ed25519,
        capability_granted: true,
        resonance_classified: true,
    };
    assert!(canonical.satisfies_canonical_contract());
}

#[test]
fn reference_checkpoints_target_distinct_tracks() {
    // helios_v2 §"Rust, MLX, Metal": cross-architecture validation
    // pair (Qwen3-8B-MLX-4bit vs Mamba-2.7b-4bit-mlx).
    let txfmr = ReferenceCheckpoint::TRANSFORMER_REFERENCE;
    let ssm = ReferenceCheckpoint::SSM_REFERENCE;
    assert_ne!(txfmr.track, ssm.track);
}
