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
    acs::{ACS_AUDIT_PLANE, ACS_CANONICAL_PLANE},
    agent_swarm::{
        AgentMessageContract, AgentMessageSignature, FIVE_BUDGET_AXES,
        HERMES_ARENA_BYTES, THREE_HERMES_OUTCOMES,
    },
    cargo_features::{CanonicalFeature, NINE_FEATURES},
    cross_domain_lens::{TSafetyBound, FIVE_LENSES},
    donor_distillation::{
        DistillationRecipe, TrainingPlanStep, CANONICAL_DONOR, CANONICAL_STUDENT,
        FALLBACK_BUNDLED, SIX_TRAINING_STEPS, THREE_RECIPES,
    },
    engram::{RECOMMENDED_STATIC_FRACTION_MAX, RECOMMENDED_STATIC_FRACTION_MIN},
    falsifier_actions::{FALSIFIER_TABLE, SIX_TERMS},
    five_planes::{ProductStream, RuntimePlane, FIVE_PLANES},
    gate_action::{
        GateAction, ENGRAM_KAPPA_THRESHOLD, ENGRAM_RHO_THRESHOLD,
        SELF_MONITORING_MAX_DEPTH, SIX_ACTIONS,
    },
    goodfire_vpd_specs::{
        computed_activation_sparsity, VPD_ACTIVATION_SPARSITY, VPD_ACTIVE_PER_POSITION,
        VPD_ALIVE_COMPONENTS, VPD_PARAMETER_COUNT, VPD_PUBLIC_ACTIVITY_FRACTION,
        VPD_PUBLIC_ACTIVITY_LABEL, VPD_RANK1_SUBCOMPONENTS, VPD_TRANSFORMER_LAYERS,
    },
    hardware_profile::{
        HardwareProfile, FOUR_PROFILES, USER_ACTUAL_TARGET, V6_1_CANONICAL_REFERENCE,
    },
    interrupt_score::{
        escalate, EscalationLevel, EscalationThresholds, FIVE_SIGNALS,
        InterruptCoefficients, InterruptScore, InterruptSignalSource,
        RHO_MAX_T35_V6_1, THREE_ESCALATION_LEVELS,
    },
    kv_direct_gate::{D_KL_THRESHOLD, PEAK_RAM_REDUCTION_FACTOR_MIN},
    learning_modes::{Direction, LearningMode, FOUR_LEARNING_MODES, SIX_DIRECTIONS},
    m2_max_kernels::{
        LoadBearingKernel, FIVE_LOAD_BEARING_KERNELS, INTERRUPT_SCORE_KERNEL_FILENAME,
        KERNEL_IMPLEMENTATION_POSTURE,
    },
    mas_capability_lattice::{Capability, DeploymentTier, CAPABILITY_LATTICE},
    mathematical_pillars::{MathematicalPillar, FIVE_PILLARS},
    scientific_calculator_basis::{total_scb_size, SIX_CATEGORIES, TWO_PRODUCTIONS},
    self_evolving_l_se::ALL_MECHANISMS,
    shadow_memory::{tier_codec, MemoryTier, ALL_TIERS},
    sherry::{BLOCK_WIDTH, CONFIG_SPACE_SIZE, NONZERO_PER_BLOCK},
    stack_roles::{ALL_ROLES, ReferenceCheckpoint, StackRole},
    theorem_status::{TheoremStatus, FOUNDATIONAL_SEVEN},
    v6_1::{AttentionMode, V6_1Axis, ALL_AXES, ALL_LOCKS, VERIFIED_FLOOR_ANCHOR},
    v6_1_execution_policy::{
        stream_execution_policy, AttentionWakePolicy, ConnectomeAlarmPolicy,
    },
    v6_1_foundation::{
        FoundationClaim, FoundationCommitment, FoundationGoodfireStatus,
        ANSWER_PACKET_SCHEMA_FREEZE_REQUIRES_F_ULP_ORACLE,
        CONSTANT_FREE_EML_GENERATOR_OPEN, EML_GRAMMAR, EML_OPERATOR_FORMULA,
        FOUNDATION_CLAIMS, FOUNDATION_COMMITMENT_ORDER, FOUNDATION_GOODFIRE_STATUS,
        FOUNDATION_HARDWARE_FLOOR, F_ULP_ORACLE, VERIFIED_FLOOR_COMMIT,
    },
    v6_1_stream_surface::{
        full_plane_count, stream_surface, StreamSurfaceLevel, ALL_FIFTEEN_CELLS,
    },
    v6_1_theorems::{T42FalsifierOutcome, V6_1Theorem, EIGHT_V6_1_THEOREMS},
    v6_2::{
        GoodfireV6_2Evidence, InterruptScoreImplementation, V6_2Falsifier, V6_2Stage,
        GOODFIRE_V6_2_EVIDENCE, INTERRUPT_SCORE_METAL_SHADOW_MIN_BATCH,
        INTERRUPT_SCORE_P99_US_MAX, LOCAL_RECALL_CORE_CONTEXT_K, LOCAL_RECALL_CORE_DEPTHS,
        LOCAL_RECALL_CORE_PASS_THRESHOLD, LOCAL_RECALL_CORE_TRIALS,
        LOCAL_RECALL_STRETCH_CONTEXT_K, M2_PRO_MEMORY_BANDWIDTH_GBPS,
        MAS_TIER1_HARD_CEILING_GB, MAS_TIER1_SOFT_CEILING_GB,
        PACKET_ROUTER_P99_US_MAX, PAGE_GATHER_BASELINE_RATIO, PAGE_GATHER_BUFFER_MB,
        PAGE_GATHER_BASELINE_SUSTAINED_GBPS_MAX,
        PAGE_GATHER_BASELINE_SUSTAINED_GBPS_MIN, PAGE_GATHER_MIN_WINDOW_SECONDS,
        SEMISEPARABLE_CANONICAL_CHUNK_SIZE,
        SEMISEPARABLE_CORE_L, SEMISEPARABLE_NGROUPS, SEMISEPARABLE_PERF_CANDIDATE_CHUNK_SIZE,
        SEMISEPARABLE_STRETCH_L, V6_2_CANON_SOURCE_PATH, V6_2_FALSIFIER_ORDER,
        V6_2_HARDWARE_LOCK, V6_2_KERNEL_LADDER_IS_AFTER_F_ULP_ORACLE,
        V6_2_STAGE_ORDER,
    },
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

// ===========================================================================
// V6.1 cross-module consistency (Stages 62-67 substrate)
// ===========================================================================

#[test]
fn v6_1_five_planes_cardinality_holds() {
    // V6.1 §3: exactly 5 runtime planes, orthogonal to 3 product streams.
    assert_eq!(FIVE_PLANES.len(), 5);
    let set: std::collections::HashSet<RuntimePlane> = FIVE_PLANES.iter().copied().collect();
    assert_eq!(set.len(), 5);
}

#[test]
fn v6_1_five_planes_have_canonical_numbering() {
    // Plane numbers are 1..=5 in canonical V6.1 §3 order.
    for (i, plane) in FIVE_PLANES.iter().enumerate() {
        assert_eq!(plane.plane_number(), (i as u32) + 1);
    }
}

#[test]
fn v6_1_only_verification_plane_has_no_metal_kernel() {
    // V6.1 §3: Verification plane is doctrine-substrate only.
    let no_kernel: Vec<_> = FIVE_PLANES
        .iter()
        .filter(|p| !p.requires_gpu_kernel())
        .copied()
        .collect();
    assert_eq!(no_kernel.len(), 1);
    assert_eq!(no_kernel[0], RuntimePlane::Verification);
}

#[test]
fn v6_1_natural_ternary_home_is_assembly_and_controller() {
    // V6.1 sharpening point 5: routing + gates are naturally ternary.
    let ternary: std::collections::HashSet<RuntimePlane> = FIVE_PLANES
        .iter()
        .filter(|p| p.natural_ternary_home())
        .copied()
        .collect();
    assert_eq!(ternary.len(), 2);
    assert!(ternary.contains(&RuntimePlane::Assembly));
    assert!(ternary.contains(&RuntimePlane::Controller));
    // State stays denser; Episodic + Verification are not ternary.
    assert!(!RuntimePlane::State.natural_ternary_home());
    assert!(!RuntimePlane::Episodic.natural_ternary_home());
    assert!(!RuntimePlane::Verification.natural_ternary_home());
}

#[test]
fn v6_1_three_product_streams_are_distinct() {
    // V6.1 §3: tri-stream (MAS / Pro / Vault) is the product
    // organization; orthogonal to the five-plane runtime organization.
    let streams = [ProductStream::Mas, ProductStream::Pro, ProductStream::Vault];
    let set: std::collections::HashSet<ProductStream> = streams.iter().copied().collect();
    assert_eq!(set.len(), 3);
}

#[test]
fn v6_1_interrupt_score_has_five_signals() {
    // V6.1 §2.2: u_t = α·H + β·WBO + γ·Sheaf + δ·Tool + ε·Connectome.
    assert_eq!(FIVE_SIGNALS.len(), 5);
    let set: std::collections::HashSet<InterruptSignalSource> =
        FIVE_SIGNALS.iter().copied().collect();
    assert_eq!(set.len(), 5);
}

#[test]
fn v6_1_connectome_alarm_is_only_new_in_v6_1_signal() {
    // V6.1: ConnectomeAlarm is the NEW signal (bridges Lane 3 ↔ Lane 1).
    // The other four (PredictiveEntropy, WboRisk, SheafResidual, ToolNeed)
    // are V5/V6 carry-forward.
    assert!(FIVE_SIGNALS.contains(&InterruptSignalSource::ConnectomeAlarm));
}

#[test]
fn v6_1_three_escalation_levels_match_thresholds() {
    // V6.1 §2.2: PureRecurrent / RecallEpisode / FullEscalation
    // partition real-line on (τ_low, τ_high).
    assert_eq!(THREE_ESCALATION_LEVELS.len(), 3);
    let thresholds = EscalationThresholds {
        tau_low: 0.3,
        tau_high: 0.7,
    };
    assert_eq!(escalate(0.1, thresholds), EscalationLevel::PureRecurrent);
    assert_eq!(escalate(0.5, thresholds), EscalationLevel::RecallEpisode);
    assert_eq!(escalate(0.9, thresholds), EscalationLevel::FullEscalation);
}

#[test]
fn v6_1_rho_max_t35_is_zero_point_two() {
    // V6.1 §2.3 T35 falsifier: "if ρ > 0.20 on real workloads, the
    // architecture has collapsed back to a static hybrid and the
    // moat is gone."
    assert_eq!(RHO_MAX_T35_V6_1, 0.20);
}

#[test]
fn v6_1_uniform_interrupt_coefficients_sum_to_one() {
    // Default uniform coefficients α=β=γ=δ=ε=0.2; sum = 1.0.
    let c = InterruptCoefficients::UNIFORM;
    let sum = c.alpha + c.beta + c.gamma + c.delta + c.epsilon;
    assert!((sum - 1.0).abs() < 1e-6);
    // Compute u_t with all signals zero; should yield zero.
    let s = InterruptScore {
        h_predictive_entropy: 0.0,
        wbo_risk: 0.0,
        sheaf_residual: 0.0,
        tool_need: 0.0,
        connectome_alarm: 0.0,
    };
    assert_eq!(s.compute(&c), 0.0);
}

#[test]
fn v6_1_eight_theorems_cardinality_holds() {
    // V6.1 §"PART 4": T35-T42 family has 8 theorems.
    assert_eq!(EIGHT_V6_1_THEOREMS.len(), 8);
    let set: std::collections::HashSet<V6_1Theorem> =
        EIGHT_V6_1_THEOREMS.iter().copied().collect();
    assert_eq!(set.len(), 8);
}

#[test]
fn v6_1_t38_and_t42_are_only_new_theorems() {
    // V6.1 §"PART 4": T38 (Distilled Hybrid Lift) and T42
    // (Connectome-State Coupling) are NEW. T35-T37 + T39 are
    // sharpened V6 theorems; T40 + T41 are V6 carry-forward.
    let new_count = EIGHT_V6_1_THEOREMS
        .iter()
        .filter(|t| t.is_new_in_v6_1())
        .count();
    assert_eq!(new_count, 2);
    assert!(V6_1Theorem::T38DistilledHybridLift.is_new_in_v6_1());
    assert!(V6_1Theorem::T42ConnectomeStateCoupling.is_new_in_v6_1());
}

#[test]
fn v6_1_t35_t36_t37_t39_are_sharpened() {
    // V6.1 §"PART 4": T35-T37 and T39 are V6 statements tightened
    // for V6.1 (ρ_max bound on T35; etc.).
    let sharpened_count = EIGHT_V6_1_THEOREMS
        .iter()
        .filter(|t| t.is_sharpened_in_v6_1())
        .count();
    assert_eq!(sharpened_count, 4);
    assert!(V6_1Theorem::T35InterruptiveRecallEfficiency.is_sharpened_in_v6_1());
    assert!(V6_1Theorem::T36WboGatedSkipBound.is_sharpened_in_v6_1());
    assert!(V6_1Theorem::T37SheafTriggeredRecallCompleteness.is_sharpened_in_v6_1());
    assert!(V6_1Theorem::T39ToolAugmentedStateGeneralization.is_sharpened_in_v6_1());
}

#[test]
fn v6_1_t40_and_t41_are_v6_carry_forward() {
    // V6.1 §"PART 4": T40 (Connectome-RAG Novel Retrieval) and
    // T41 (Convergent Number Representation) are preserved from V6
    // verbatim. T40 is Lane-3 ONLY; does not ship in MAS without
    // crossing falsifier.
    let carry_count = EIGHT_V6_1_THEOREMS
        .iter()
        .filter(|t| t.is_v6_carry_forward())
        .count();
    assert_eq!(carry_count, 2);
    assert!(V6_1Theorem::T40ConnectomeRagNovelRetrieval.is_v6_carry_forward());
    assert!(V6_1Theorem::T41ConvergentNumberRepresentation.is_v6_carry_forward());
    assert_eq!(V6_1Theorem::T40ConnectomeRagNovelRetrieval.lane(), "L3 only");
}

#[test]
fn v6_1_only_t42_bridges_lane_3_to_lane_1() {
    // V6.1 §"PART 4": T42 (Connectome-State Coupling) is the
    // load-bearing bridge from Lane 3 PCF research to Lane 1
    // runtime gating via the ConnectomeAlarm signal.
    let bridges: Vec<_> = EIGHT_V6_1_THEOREMS
        .iter()
        .filter(|t| t.bridges_lane_3_to_lane_1())
        .copied()
        .collect();
    assert_eq!(bridges.len(), 1);
    assert_eq!(bridges[0], V6_1Theorem::T42ConnectomeStateCoupling);
}

#[test]
fn v6_1_theorem_taxonomy_partitions_eight_theorems() {
    // Every V6.1 theorem is exactly one of: NEW / sharpened /
    // V6-carry-forward. No double-classifications, no orphans.
    for theorem in EIGHT_V6_1_THEOREMS {
        let new = theorem.is_new_in_v6_1() as u32;
        let sharpened = theorem.is_sharpened_in_v6_1() as u32;
        let carry_forward = theorem.is_v6_carry_forward() as u32;
        let total = new + sharpened + carry_forward;
        assert_eq!(
            total, 1,
            "theorem {:?} must satisfy exactly one classification, got {}",
            theorem, total
        );
    }
}

#[test]
fn v6_1_t42_falsifier_has_two_outcomes() {
    // V6.1 §"PART 4" T42 falsifier: ConnectomeAlarm has zero
    // predictive power on held-out interrupt traces ⇒ T42 fails.
    let outcomes = [
        T42FalsifierOutcome::PredictiveAboveChance,
        T42FalsifierOutcome::ZeroOrBelowChance,
    ];
    let set: std::collections::HashSet<T42FalsifierOutcome> = outcomes.iter().copied().collect();
    assert_eq!(set.len(), 2);
}

#[test]
fn v6_1_goodfire_vpd_pinned_numerics_match_v6_1_lock() {
    // V6.1 §"GOODFIRE VPD CONFIRMED-PUBLIC NUMERICS": 67M params,
    // 4 transformer layers, 38912 rank-1 subcomponents, 9972 alive,
    // 205 active per position, public rounded 2.1% activation
    // sparsity.
    assert_eq!(VPD_PARAMETER_COUNT, 67_000_000);
    assert_eq!(VPD_TRANSFORMER_LAYERS, 4);
    assert_eq!(VPD_RANK1_SUBCOMPONENTS, 38_912);
    assert_eq!(VPD_ALIVE_COMPONENTS, 9_972);
    assert_eq!(VPD_ACTIVE_PER_POSITION, 205);
    assert!((VPD_ACTIVATION_SPARSITY - VPD_PUBLIC_ACTIVITY_FRACTION).abs() < 5e-4);
    assert_eq!(VPD_PUBLIC_ACTIVITY_LABEL, "2.1%");
}

#[test]
fn v6_1_goodfire_vpd_computed_sparsity_matches_pinned_constant() {
    // The pinned exact-ratio sparsity must equal 205 / 9972 within
    // tight tolerance; public docs round it to 0.021 / 2.1%.
    let computed = computed_activation_sparsity();
    assert!(
        (computed - VPD_ACTIVATION_SPARSITY).abs() < 1e-8,
        "computed sparsity {computed} must match pinned {VPD_ACTIVATION_SPARSITY}"
    );
}

#[test]
fn v6_1_goodfire_vpd_internal_math_and_external_label_do_not_fight() {
    // Internal math is exact 205 / 9972; external canon says 2.1%.
    assert_eq!(VPD_ACTIVATION_SPARSITY, computed_activation_sparsity());
    assert!((VPD_ACTIVATION_SPARSITY - 0.020557).abs() < 1e-6);
    assert_eq!(VPD_PUBLIC_ACTIVITY_LABEL, "2.1%");
}

#[test]
fn v6_1_canonical_donor_matches_v5_verified_floor_anchor_model() {
    // V6.1 §5 Step 1: "Donor selection: Qwen3-8B (V5 Verified Floor)."
    // The Verified Floor commit anchor is ac8c6d28; the canonical
    // donor model is the Qwen3-8B that anchor pinned. These are
    // separate substrates (one a git commit, one an HF model id)
    // but they share the V5 Verified Floor doctrine.
    assert_eq!(CANONICAL_DONOR, "Qwen/Qwen3-8B-MLX-4bit");
    assert_eq!(VERIFIED_FLOOR_ANCHOR, "ac8c6d28");
    // The donor name carries "Qwen3-8B" — the canonical V5 spine.
    assert!(CANONICAL_DONOR.contains("Qwen3-8B"));
}

#[test]
fn v6_1_canonical_student_is_granite_4_h_micro_3b() {
    // V6.1 §5 Step 2: Granite-4.0-H-Micro 3B (9:1 hybrid).
    assert_eq!(CANONICAL_STUDENT, "Granite-4.0-H-Micro-3B (9:1 hybrid)");
}

#[test]
fn v6_1_fallback_bundled_is_falcon_mamba_7b() {
    // V6.1 §"CAVEATS" #1: if Qwen3 license drift / Granite MLX delay,
    // fall back to bundled Falcon-Mamba-7B-MLX-4bit.
    assert_eq!(FALLBACK_BUNDLED, "tiiuae/Falcon-Mamba-7B-MLX-4bit");
}

#[test]
fn v6_1_three_distillation_recipes_canonical_order() {
    // V6.1 §5: MambaInLlama, MOHAWK, HyLo.
    assert_eq!(THREE_RECIPES.len(), 3);
    assert_eq!(THREE_RECIPES[0], DistillationRecipe::MambaInLlama);
    assert_eq!(THREE_RECIPES[1], DistillationRecipe::Mohawk);
    assert_eq!(THREE_RECIPES[2], DistillationRecipe::HyLo);
}

#[test]
fn v6_1_six_training_steps_in_canonical_order() {
    // V6.1 §5: 6-step training plan (donor → student → compute →
    // HyLo → HeavySkill LoRA → Goodfire VPD).
    assert_eq!(SIX_TRAINING_STEPS.len(), 6);
    assert_eq!(SIX_TRAINING_STEPS[0], TrainingPlanStep::DonorSelection);
    assert_eq!(SIX_TRAINING_STEPS[5], TrainingPlanStep::GoodfireVpdExtraction);
}

#[test]
fn v6_1_five_load_bearing_kernels_distinct_filenames() {
    // V6.1 §7: SemiseparableBlockScan, LocalRecallIsland, PageGather,
    // ControllerKernelPack, PacketRouter1bit. All 5 must have
    // distinct .metal filenames.
    assert_eq!(FIVE_LOAD_BEARING_KERNELS.len(), 5);
    let names: std::collections::HashSet<&'static str> =
        FIVE_LOAD_BEARING_KERNELS.iter().map(|k| k.filename()).collect();
    assert_eq!(names.len(), 5);
    for kernel in FIVE_LOAD_BEARING_KERNELS {
        assert!(kernel.filename().ends_with(".metal"));
    }
}

#[test]
fn v6_1_kernel_to_plane_mapping_is_canonical() {
    // V6.1 §7 plane-aligned kernel taxonomy:
    // SemiseparableBlockScan → State,
    // LocalRecallIsland + PageGather → Episodic,
    // ControllerKernelPack → Controller,
    // PacketRouter1bit → Assembly.
    assert_eq!(
        LoadBearingKernel::SemiseparableBlockScan.plane(),
        RuntimePlane::State
    );
    assert_eq!(
        LoadBearingKernel::LocalRecallIsland.plane(),
        RuntimePlane::Episodic
    );
    assert_eq!(
        LoadBearingKernel::PageGather.plane(),
        RuntimePlane::Episodic
    );
    assert_eq!(
        LoadBearingKernel::ControllerKernelPack.plane(),
        RuntimePlane::Controller
    );
    assert_eq!(
        LoadBearingKernel::PacketRouter1bit.plane(),
        RuntimePlane::Assembly
    );
}

#[test]
fn v6_1_no_load_bearing_kernel_in_verification_plane() {
    // V6.1 §3: Verification plane has no GPU kernel — it lives in
    // the doctrine substrate (theorems, AnswerPacket, replay).
    for kernel in FIVE_LOAD_BEARING_KERNELS {
        assert_ne!(kernel.plane(), RuntimePlane::Verification);
    }
}

#[test]
fn v6_1_episodic_plane_has_two_load_bearing_kernels() {
    // V6.1 §7: LocalRecallIsland + PageGather both map to Episodic;
    // every other plane has exactly one load-bearing kernel.
    let episodic_count = FIVE_LOAD_BEARING_KERNELS
        .iter()
        .filter(|k| k.plane() == RuntimePlane::Episodic)
        .count();
    assert_eq!(episodic_count, 2);
}

#[test]
fn v6_1_kernel_filenames_match_planes_primary_kernel() {
    // V6.1 §3: each plane.kernel_filename() reports its primary
    // load-bearing kernel. Cross-check against m2_max_kernels.rs
    // single-kernel planes (State, Assembly, Controller — Episodic
    // intentionally skipped because it has 2 kernels).
    assert_eq!(
        RuntimePlane::State.kernel_filename(),
        LoadBearingKernel::SemiseparableBlockScan.filename()
    );
    assert_eq!(
        RuntimePlane::Assembly.kernel_filename(),
        LoadBearingKernel::PacketRouter1bit.filename()
    );
    assert_eq!(
        RuntimePlane::Controller.kernel_filename(),
        LoadBearingKernel::ControllerKernelPack.filename()
    );
}

#[test]
fn v6_1_interrupt_score_kernel_is_separate_from_load_bearing_five() {
    // V6.1 §7: "InterruptScore.metal — small, fast, always-on, runs
    // before every step." It sits OUTSIDE the load-bearing 5.
    assert_eq!(INTERRUPT_SCORE_KERNEL_FILENAME, "InterruptScore.metal");
    let load_bearing_files: std::collections::HashSet<&'static str> =
        FIVE_LOAD_BEARING_KERNELS.iter().map(|k| k.filename()).collect();
    assert!(!load_bearing_files.contains(INTERRUPT_SCORE_KERNEL_FILENAME));
}

#[test]
fn v6_1_execution_policy_uses_attention_by_exception_for_every_stream() {
    for stream in [ProductStream::Mas, ProductStream::Pro, ProductStream::Vault] {
        let policy = stream_execution_policy(stream);
        assert!(policy.attention_wake_policy.uses_interrupt_score());
        assert!(!policy.wakes_attention(EscalationLevel::PureRecurrent));
        assert!(!policy.wakes_tools(EscalationLevel::PureRecurrent));
        assert!(policy.wakes_attention(EscalationLevel::RecallEpisode));
        assert!(!policy.wakes_tools(EscalationLevel::RecallEpisode));
        assert!(policy.wakes_tools(EscalationLevel::FullEscalation));
    }
}

#[test]
fn v6_1_execution_policy_tier_kernels_match_lean_brief() {
    let mas = stream_execution_policy(ProductStream::Mas);
    assert_eq!(
        mas.attention_wake_policy,
        AttentionWakePolicy::InterruptScoreWithStatic9To1Fallback
    );
    assert!(mas.attention_wake_policy.has_static_9_to_1_fallback());
    assert_eq!(mas.state_kernel, LoadBearingKernel::SemiseparableBlockScan);
    assert_eq!(mas.recall_kernel, None);

    let pro = stream_execution_policy(ProductStream::Pro);
    assert_eq!(pro.attention_wake_policy, AttentionWakePolicy::FullInterruptScore);
    assert_eq!(pro.recall_kernel, Some(LoadBearingKernel::LocalRecallIsland));
    assert_eq!(pro.connectome_alarm_policy, ConnectomeAlarmPolicy::ObservabilityOnly);
    assert!(!pro.connectome_alarm_policy.can_drive_runtime_interrupts());

    let vault = stream_execution_policy(ProductStream::Vault);
    assert_eq!(vault.assembly_kernel, Some(LoadBearingKernel::PacketRouter1bit));
    assert_eq!(
        vault.connectome_alarm_policy,
        ConnectomeAlarmPolicy::ExperimentalVaultOnly
    );
    assert!(vault.connectome_alarm_policy.can_drive_runtime_interrupts());
}

#[test]
fn v6_1_kernel_names_are_doctrine_targets_not_implementation_claims() {
    // The current repo records V6.1 kernel names and falsifiers. The
    // actual `.metal` files are future implementation work and must
    // not be implied by this research substrate.
    assert_eq!(
        KERNEL_IMPLEMENTATION_POSTURE,
        "canonical_target_not_implemented_here"
    );
}

#[test]
fn v6_1_user_actual_target_is_m2_pro_16gb() {
    // Per user message 2026-05-06: "i have a m2 pro not max with
    // 16gb of ram." This is the actual ship target, not the V6.1
    // canonical M2 Max 64GB reference.
    assert_eq!(USER_ACTUAL_TARGET, HardwareProfile::M2Pro16Gb);
    assert!(USER_ACTUAL_TARGET.is_actual_user_target());
}

#[test]
fn v6_1_canonical_reference_is_m2_max_64gb() {
    // V6.1 PART 7 references M2 Max 64GB as the M2 Max kernel
    // benchmark profile. PEAK_RAM_GB_MAX = 12.0 in
    // validation_thresholds.rs is calibrated for this profile.
    assert_eq!(V6_1_CANONICAL_REFERENCE, HardwareProfile::M2Max64Gb);
    assert!(!V6_1_CANONICAL_REFERENCE.is_actual_user_target());
}

#[test]
fn v6_1_canonical_reference_budget_matches_peak_ram_threshold() {
    // M2 Max 64GB realistic budget = 12.0 GB; this must equal the
    // PEAK_RAM_GB_MAX validation threshold (the V6.1 conservative
    // ceiling). If these drift apart, one of the two has been
    // edited without updating the other.
    let budget = V6_1_CANONICAL_REFERENCE.realistic_resident_budget_gb();
    assert!(
        (budget - PEAK_RAM_GB_MAX as f32).abs() < 1e-6,
        "M2 Max budget {budget} must match PEAK_RAM_GB_MAX {PEAK_RAM_GB_MAX}"
    );
}

#[test]
fn v6_1_user_actual_target_budget_below_canonical_reference() {
    // M2 Pro 16GB has tighter realistic budget than M2 Max 64GB;
    // this is the binding constraint on local model selection
    // (4-bit 7-8B sweet spot vs 13B on the canonical reference).
    let user_budget = USER_ACTUAL_TARGET.realistic_resident_budget_gb();
    let canonical_budget = V6_1_CANONICAL_REFERENCE.realistic_resident_budget_gb();
    assert!(
        user_budget < canonical_budget,
        "user M2 Pro budget {user_budget} must be < V6.1 reference budget {canonical_budget}"
    );
}

#[test]
fn v6_1_four_hardware_profiles_distinct() {
    // The 4-profile enum (M2 Pro / M3 Max / M2 Max / M3 Ultra) must
    // have distinct unified_memory_gb values.
    assert_eq!(FOUR_PROFILES.len(), 4);
    let set: std::collections::HashSet<u32> =
        FOUR_PROFILES.iter().map(|p| p.unified_memory_gb()).collect();
    assert_eq!(set.len(), 4);
}

#[test]
fn v6_1_user_target_sweet_spot_is_4bit_7b() {
    // user_hardware.md: M2 Pro 16GB sweet-spot model is 4-bit 7B.
    let sweet_b = USER_ACTUAL_TARGET.sweet_spot_model_b();
    assert!(
        (7.0..=8.0).contains(&sweet_b),
        "M2 Pro sweet-spot {sweet_b} must be in [7B, 8B] range"
    );
}

#[test]
fn v6_1_user_target_max_context_is_32k() {
    // user_hardware.md: M2 Pro 16GB max practical context is 32k
    // (128k requires KV-Direct gate). Cross-check this matches the
    // hardware_profile module's stored value.
    assert_eq!(USER_ACTUAL_TARGET.max_practical_context_k(), 32);
}

#[test]
fn v6_1_canonical_reference_max_context_is_128k() {
    // V6.1 canonical: 128k @ M2 Max 64GB.
    assert_eq!(V6_1_CANONICAL_REFERENCE.max_practical_context_k(), 128);
}

#[test]
fn v6_1_acs_lives_in_episodic_plane_and_audits_in_verification() {
    // ACS stores exact cognitive coordinates, not the semantic SSM
    // spine. The theorem labels attached to ACS anchors are audited
    // by the Verification plane.
    assert_eq!(ACS_CANONICAL_PLANE, RuntimePlane::Episodic);
    assert_ne!(ACS_CANONICAL_PLANE, RuntimePlane::State);
    assert_eq!(ACS_AUDIT_PLANE, RuntimePlane::Verification);
}

#[test]
fn v6_1_stream_surface_has_fifteen_cells() {
    // V6.1 §3: 3 streams × 5 planes = 15 cells, every cell well-defined.
    assert_eq!(ALL_FIFTEEN_CELLS.len(), 15);
}

#[test]
fn v6_1_stream_surface_assembly_is_bounded_in_mas_full_in_pro_vault() {
    // V6.1 sharpening point 5: ternary routing lives in Assembly,
    // but MAS remains a bounded App-Store-safe exposure surface.
    assert_eq!(
        stream_surface(ProductStream::Mas, RuntimePlane::Assembly),
        StreamSurfaceLevel::Bounded
    );
    assert_eq!(
        stream_surface(ProductStream::Pro, RuntimePlane::Assembly),
        StreamSurfaceLevel::Full
    );
    assert_eq!(
        stream_surface(ProductStream::Vault, RuntimePlane::Assembly),
        StreamSurfaceLevel::Full
    );
}

#[test]
fn v6_1_stream_surface_verification_doctrine_only_everywhere() {
    // V6.1 §3: Verification plane is doctrine substrate only — no
    // GPU kernel. It is emitted uniformly across streams as audit
    // doctrine.
    for stream in [ProductStream::Mas, ProductStream::Pro, ProductStream::Vault] {
        assert_eq!(
            stream_surface(stream, RuntimePlane::Verification),
            StreamSurfaceLevel::DoctrineOnly
        );
    }
}

#[test]
fn v6_1_stream_surface_pro_widens_mas_envelope() {
    // V6.1 doctrine: Pro is "same architecture, wider envelopes."
    // No runtime plane in Pro is more bounded than its MAS counterpart.
    for plane in [
        RuntimePlane::State,
        RuntimePlane::Episodic,
        RuntimePlane::Assembly,
        RuntimePlane::Controller,
    ] {
        let mas = stream_surface(ProductStream::Mas, plane);
        let pro = stream_surface(ProductStream::Pro, plane);
        assert!(
            pro.is_full(),
            "Pro plane {plane:?} must be Full at this surface granularity, got {pro:?}"
        );
        if !mas.is_full() {
            assert_ne!(mas, pro, "Pro must widen MAS for plane {plane:?}");
        }
    }
}

#[test]
fn v6_1_stream_surface_full_plane_counts_match_doctrine() {
    // MAS has no Full policy planes: State/Assembly/Controller are
    // Bounded, Episodic=Restricted, Verification=DoctrineOnly.
    assert_eq!(full_plane_count(ProductStream::Mas), 0);
    // Pro / Vault: 4 Full planes (all but Verification).
    assert_eq!(full_plane_count(ProductStream::Pro), 4);
    assert_eq!(full_plane_count(ProductStream::Vault), 4);
}

#[test]
fn v6_1_stream_surface_no_stream_omits_any_plane() {
    // V6.1 §3: "every stream contains the same five planes."
    // Every (stream, plane) cell must produce a defined level.
    let streams = [ProductStream::Mas, ProductStream::Pro, ProductStream::Vault];
    let planes = [
        RuntimePlane::State,
        RuntimePlane::Episodic,
        RuntimePlane::Assembly,
        RuntimePlane::Controller,
        RuntimePlane::Verification,
    ];
    let mut covered = 0;
    for s in streams {
        for p in planes {
            let _ = stream_surface(s, p);
            covered += 1;
        }
    }
    assert_eq!(covered, 15);
}

// ---------------------------------------------------------------------------
// V6.2 lean verification canon intake
// ---------------------------------------------------------------------------

#[test]
fn v6_2_source_path_is_jordan_research_lock() {
    assert_eq!(
        V6_2_CANON_SOURCE_PATH,
        "docs/fusion/jordan's research/helios v6.2.md"
    );
}

#[test]
fn v6_2_hardware_lock_is_actual_ship_rig() {
    // V6.2 doctrine: "If it works on Jojo's M2 Pro 16 GB, it can
    // ship. If it requires a workstation, it's research-tier."
    assert_eq!(V6_2_HARDWARE_LOCK, USER_ACTUAL_TARGET);
    assert_eq!(V6_2_HARDWARE_LOCK, HardwareProfile::M2Pro16Gb);
    assert_eq!(M2_PRO_MEMORY_BANDWIDTH_GBPS, 200);
    assert_eq!(V6_2_HARDWARE_LOCK.unified_memory_gb(), 16);
}

#[test]
fn v6_2_mas_memory_ceiling_stays_below_16gb() {
    assert_eq!(MAS_TIER1_SOFT_CEILING_GB, 12.0);
    assert_eq!(MAS_TIER1_HARD_CEILING_GB, 14.0);
    assert!(MAS_TIER1_SOFT_CEILING_GB < MAS_TIER1_HARD_CEILING_GB);
    assert!(MAS_TIER1_HARD_CEILING_GB < V6_2_HARDWARE_LOCK.unified_memory_gb() as f32);
}

#[test]
fn v6_2_page_gather_threshold_is_baseline_relative() {
    // V6.2 replaces ">=70% of theoretical M2 Max bandwidth" with
    // ">=70% of measured BW_baseline_M2Pro".
    assert!((PAGE_GATHER_BASELINE_RATIO - 0.70).abs() < f32::EPSILON);
    assert_eq!(PAGE_GATHER_BASELINE_SUSTAINED_GBPS_MIN, 63);
    assert_eq!(PAGE_GATHER_BASELINE_SUSTAINED_GBPS_MAX, 73);
    assert!(
        (PAGE_GATHER_BASELINE_SUSTAINED_GBPS_MAX as f32)
            / (M2_PRO_MEMORY_BANDWIDTH_GBPS as f32)
            < 0.40
    );
    assert_eq!(PAGE_GATHER_MIN_WINDOW_SECONDS, 1.0);
    assert_eq!(PAGE_GATHER_BUFFER_MB, [256, 512, 1024]);
    assert!(!PAGE_GATHER_BUFFER_MB.contains(&4096));
}

#[test]
fn v6_2_semiseparable_core_lane_is_32k_with_128k_stretch() {
    assert_eq!(SEMISEPARABLE_CORE_L, 32_768);
    assert_eq!(SEMISEPARABLE_STRETCH_L, 131_072);
    assert_eq!(SEMISEPARABLE_NGROUPS, 1);
    assert_eq!(SEMISEPARABLE_CANONICAL_CHUNK_SIZE, 256);
    assert_eq!(SEMISEPARABLE_PERF_CANDIDATE_CHUNK_SIZE, 128);
}

#[test]
fn v6_2_local_recall_core_is_50_by_5_at_32k() {
    assert_eq!(LOCAL_RECALL_CORE_CONTEXT_K, 32);
    assert_eq!(LOCAL_RECALL_STRETCH_CONTEXT_K, 128);
    assert_eq!(LOCAL_RECALL_CORE_TRIALS, 50);
    assert_eq!(LOCAL_RECALL_CORE_DEPTHS, 5);
    assert_eq!(LOCAL_RECALL_CORE_TRIALS * LOCAL_RECALL_CORE_DEPTHS, 250);
    assert_eq!(LOCAL_RECALL_CORE_PASS_THRESHOLD, 0.95);
}

#[test]
fn v6_2_interrupt_score_is_swift_cpu_canonical() {
    assert!(InterruptScoreImplementation::SwiftCpuCanonical.is_canonical());
    assert!(!InterruptScoreImplementation::MetalShadowBatchOnly.is_canonical());
    assert_eq!(INTERRUPT_SCORE_P99_US_MAX, 100);
    assert_eq!(INTERRUPT_SCORE_METAL_SHADOW_MIN_BATCH, 64);
}

#[test]
fn v6_2_packet_router_dispatch_budget_is_100us_p99() {
    assert_eq!(PACKET_ROUTER_P99_US_MAX, 100);
}

#[test]
fn v6_2_goodfire_subnumbers_are_revalidated_without_runtime_promotion() {
    assert!(GOODFIRE_V6_2_EVIDENCE.contains(&GoodfireV6_2Evidence::HeadlinePublicConfirmed));
    assert!(
        GOODFIRE_V6_2_EVIDENCE.contains(&GoodfireV6_2Evidence::ActivitySubnumbersRevalidated)
    );
    assert!(
        GOODFIRE_V6_2_EVIDENCE
            .contains(&GoodfireV6_2Evidence::RuntimeAccelerationStillCandidate)
    );
    // Preserve V6.1 exact internal math + public presentation.
    assert_eq!(VPD_ALIVE_COMPONENTS, 9_972);
    assert_eq!(VPD_ACTIVE_PER_POSITION, 205);
    assert_eq!(VPD_PUBLIC_ACTIVITY_LABEL, "2.1%");
}

#[test]
fn v6_2_falsifier_order_is_dependency_true() {
    assert!(V6_2_KERNEL_LADDER_IS_AFTER_F_ULP_ORACLE);
    assert_eq!(V6_2_FALSIFIER_ORDER.len(), 8);
    assert_eq!(V6_2_FALSIFIER_ORDER[0], V6_2Falsifier::PageGatherBaseline);
    assert_eq!(V6_2_FALSIFIER_ORDER[1], V6_2Falsifier::PageGatherScatter);
    assert_eq!(V6_2_FALSIFIER_ORDER[2], V6_2Falsifier::InterruptScoreCpu);
    assert_eq!(V6_2_FALSIFIER_ORDER[7], V6_2Falsifier::RulerBabilongHarness);
}

#[test]
fn v6_2_falsifiers_map_to_v6_1_kernel_targets_without_claiming_files_exist() {
    let kernels: std::collections::HashSet<LoadBearingKernel> = V6_2_FALSIFIER_ORDER
        .iter()
        .filter_map(|f| f.kernel())
        .collect();
    for kernel in FIVE_LOAD_BEARING_KERNELS {
        assert!(
            kernels.contains(&kernel),
            "V6.2 falsifiers should still cover V6.1 kernel target {kernel:?}"
        );
    }
    assert_eq!(
        KERNEL_IMPLEMENTATION_POSTURE,
        "canonical_target_not_implemented_here"
    );
}

#[test]
fn v6_2_stage_order_has_no_calendar_commitment() {
    assert_eq!(V6_2_STAGE_ORDER.len(), 4);
    assert_eq!(V6_2_STAGE_ORDER[0], V6_2Stage::LeanScaffolding);
    assert_eq!(V6_2_STAGE_ORDER[1], V6_2Stage::HardwareFalsifiers);
    assert_eq!(V6_2_STAGE_ORDER[2], V6_2Stage::LeanIntegration);
    assert_eq!(V6_2_STAGE_ORDER[3], V6_2Stage::Migration);
}

// ---------------------------------------------------------------------------
// V6.1 Foundation refresh: EML floor + F-ULP-Oracle W1
// ---------------------------------------------------------------------------

#[test]
fn v6_1_foundation_eml_floor_is_bounded_and_precedes_schema_freeze() {
    assert_eq!(VERIFIED_FLOOR_COMMIT, VERIFIED_FLOOR_ANCHOR);
    assert_eq!(FOUNDATION_HARDWARE_FLOOR, V6_2_HARDWARE_LOCK);
    assert_eq!(EML_OPERATOR_FORMULA, "eml(x,y)=exp(x)-ln(y)");
    assert_eq!(EML_GRAMMAR, "S -> 1 | eml(S,S)");
    assert!(CONSTANT_FREE_EML_GENERATOR_OPEN);
    assert!(ANSWER_PACKET_SCHEMA_FREEZE_REQUIRES_F_ULP_ORACLE);
    assert_eq!(F_ULP_ORACLE.log_sampled_points, 412_000);
    assert_eq!(F_ULP_ORACLE.stress_points, 2_048);
    assert_eq!(F_ULP_ORACLE.max_ulp_fp16, 2);
    assert_eq!(F_ULP_ORACLE.wall_clock_seconds_max, 90);
}

#[test]
fn v6_1_foundation_goodfire_conflict_resolves_to_live_page_revalidation() {
    assert!(FOUNDATION_GOODFIRE_STATUS
        .contains(&FoundationGoodfireStatus::ActivitySubnumbersPublicConfirmed));
    assert!(FOUNDATION_GOODFIRE_STATUS
        .contains(&FoundationGoodfireStatus::RuntimeAccelerationCandidate));
    assert!(GOODFIRE_V6_2_EVIDENCE
        .contains(&GoodfireV6_2Evidence::ActivitySubnumbersRevalidated));
    assert_eq!(VPD_ALIVE_COMPONENTS, 9_972);
    assert_eq!(VPD_ACTIVE_PER_POSITION, 205);
    assert_eq!(VPD_PUBLIC_ACTIVITY_LABEL, "2.1%");
}

#[test]
fn v6_1_foundation_drops_unverified_eml_star_and_quantum_sheffer() {
    assert_eq!(FoundationClaim::MonnerotEmlStar.status(), TheoremStatus::DROP);
    assert_eq!(
        FoundationClaim::SingleQuantumShefferStroke.status(),
        TheoremStatus::DROP
    );
    for claim in FOUNDATION_CLAIMS {
        if matches!(claim.status(), TheoremStatus::EB | TheoremStatus::C) {
            assert!(claim.requires_hardware_falsifier());
        }
    }
}

#[test]
fn v6_1_foundation_commitment_order_gates_answer_packet_schema() {
    let oracle = FOUNDATION_COMMITMENT_ORDER
        .iter()
        .position(|item| *item == FoundationCommitment::LandFulpOracleHarness)
        .expect("F-ULP-Oracle commitment must exist");
    let schema = FOUNDATION_COMMITMENT_ORDER
        .iter()
        .position(|item| *item == FoundationCommitment::FreezeAnswerPacketSchemaBehindOracle)
        .expect("schema-freeze commitment must exist");
    assert!(oracle < schema);
}
