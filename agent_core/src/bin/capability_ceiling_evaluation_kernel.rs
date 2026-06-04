//! Capability Ceiling Evaluation Kernel.
//!
//! This is the route-level governor for the 16 GB / 70B-class ACS/UAS path.
//! It reads the local falsifier artifacts that already exist, preserves their
//! individual truth values, and emits one schema-valid artifact that answers:
//! "can this MacBook route run yet, and if not, which measured gate is next?"

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-Capability-Ceiling-Evaluation-Kernel";
const FIXTURE_ID: &str = "capability_ceiling_gate_rollup_v1";
const COMMAND: &str = "Tools/falsifiers/f_capability_ceiling_evaluation_kernel.sh";

const UAS_COPY_COUNT_PATH: &str = "artifacts/falsifiers/uas_copy_count/result.json";
const ACS_ANCHOR_LOOKUP_PATH: &str = "artifacts/falsifiers/acs_anchor_lookup/result.json";
const UAS_ZERO_COPY_SPINE_PATH: &str = "artifacts/falsifiers/uas_zero_copy_spine/result.json";
const UAS_ACS_MMAP_RESIDENCY_PATH: &str = "artifacts/falsifiers/uas_acs_mmap_residency/result.json";
const PAGE_GATHER_PATH: &str = "artifacts/falsifiers/page_gather/locality_probe_result.json";
const PAGE_GATHER_CALLER_PATH: &str =
    "artifacts/falsifiers/page_gather_packetized_caller/result.json";
const PAGE_GATHER_PACKETIZED_POLICY_PATH: &str =
    "artifacts/falsifiers/page_gather_packetized_policy_acceptance/result.json";
const KV_DIRECT_PATH: &str = "artifacts/falsifiers/kv_direct_gate/result.json";
const KV_DIRECT_FULL_SUITE_RUN_PLAN_PATH: &str =
    "artifacts/falsifiers/kv_direct_gate/live_mlx_full_suite_plan/full_suite_run_plan.json";
const AGENT_LOCAL_MODEL_RUNTIME_BRIDGE_PATH: &str =
    "artifacts/falsifiers/agent_local_model_runtime_bridge/result.json";
const ACTIVE_ASSEMBLY_TEST_PATH: &str = "agent_core/tests/active_assembly_minimal.rs";
const ACTIVE_ASSEMBLY_ARTIFACT_PATH: &str =
    "artifacts/falsifiers/active_assembly_minimal/result.json";
const SPARSE_RUNTIME_SPLIT_PATH: &str = "artifacts/falsifiers/sparse_runtime_split/result.json";
const RESIDENCY_CONSTRUCTION_GRAPH_PATH: &str =
    "artifacts/falsifiers/residency_construction_graph/result.json";
const COACTIVATION_TILE_PREFETCH_PATH: &str =
    "artifacts/falsifiers/coactivation_tile_prefetch/result.json";
const PROOF_CARRYING_RESIDENCY_LEASE_PATH: &str =
    "artifacts/falsifiers/proof_carrying_residency_lease/result.json";
const COLD_ASSEMBLY_PLAN_70B_LITE_PATH: &str =
    "artifacts/falsifiers/cold_assembly_plan_70b_lite/result.json";
const LATTICE_STATE_CONTROLLER_PATH: &str =
    "artifacts/falsifiers/lattice_state_controller/result.json";
const REASONING_STATE_CONTINUITY_PATH: &str =
    "artifacts/falsifiers/reasoning_state_continuity/result.json";
const COLD_MISS_LEDGER_PATH: &str = "artifacts/falsifiers/cold_miss_ledger/result.json";
const SWIFTLM_SOURCE_INTAKE_PATH: &str = "artifacts/falsifiers/swiftlm_source_intake/result.json";
const META_BREAKTHROUGH_CARD_REGISTRY_PATH: &str =
    "artifacts/falsifiers/meta_breakthrough_card_registry/result.json";
const PROOF_CARRYING_ROUTE_CARD_PATH: &str =
    "artifacts/falsifiers/proof_carrying_route_card/result.json";
const RUST_ROUTE_KERNEL_MODEL_CHECK_PATH: &str =
    "artifacts/falsifiers/rust_route_kernel_model_check/result.json";
const BRAIN_ROUTE_CARD_MULTI_MODEL_PATH: &str =
    "artifacts/falsifiers/brain_route_card_multi_model/result.json";
const KV_PAGE_CONTROL_QUERY_AWARE_PATH: &str =
    "artifacts/falsifiers/kv_page_control_query_aware/result.json";
const NEURAL_CONTROL_CARD_ABLATION_PATH: &str =
    "artifacts/falsifiers/neural_control_card_ablation/result.json";
const VERIFIER_REGRET_LEDGER_PATH: &str = "artifacts/falsifiers/verifier_regret_ledger/result.json";
const ROUTE_SCOUT_SSM_BASELINE_PATH: &str =
    "artifacts/falsifiers/route_scout_ssm_baseline/result.json";
const FULP_ORACLE_PATH: &str = "artifacts/falsifiers/ulp_oracle/result.json";
const CONTROLLER_KERNEL_PATH: &str = "artifacts/falsifiers/controller_kernel_pack/result.json";
const COCKTAIL_LITE_PATH: &str = "artifacts/falsifiers/70b_local_cocktail_lite/result.json";
const HEAVY_LONG_CONTEXT_ENV: &str = "EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT";
const LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED: &str =
    "large_model_provider_reference_deferred_by_mlx_route";
const RUST_ROUTE_KERNEL_MODEL_CHECK_AXES: &[&str] = &[
    "upstream_route_card_artifact_pass",
    "bounded_state_space_enumerated",
    "transition_relation_total",
    "invalid_transition_rejected",
    "admit_requires_preconditions",
    "execute_requires_rollback",
    "execute_requires_answer_packet",
    "execute_requires_pinned_toolchain",
    "abstain_on_uncertainty_or_conflict",
    "rollback_always_reachable",
    "budget_monotonic",
    "hidden_live_mutation_rejected",
    "unsafe_ffi_surface_audited",
    "unsafe_ffi_surface_empty",
    "deterministic_model_check_address",
    "missing_route_card_rejected",
    "stale_toolchain_rejected",
    "no_runtime_bytes_loaded",
];
const BRAIN_ROUTE_CARD_MULTI_MODEL_AXES: &[&str] = &[
    "upstream_route_kernel_model_check_pass",
    "brain_route_cards_present",
    "task_signatures_bound",
    "mission_ids_bound",
    "candidate_brains_bound",
    "selected_stack_bound",
    "fallback_brain_bound",
    "model_roles_bound",
    "privacy_classes_bound",
    "baseline_static_route_bound",
    "route_kernel_compatibility_bound",
    "quality_delta_positive",
    "evidence_validity_delta_positive",
    "verifier_delta_positive",
    "latency_delta_positive",
    "active_byte_delta_positive",
    "route_success_delta_positive",
    "static_baseline_beaten",
    "rollback_bound",
    "answer_packet_ref_bound",
    "regret_update_key_bound",
    "route_authority_shadow_only",
    "no_hidden_multi_model_authority",
    "hidden_chain_not_exposed",
    "no_hidden_cloud",
    "uncertainty_abstention_bound",
    "route_card_address_deterministic",
    "duplicate_route_card_rejected",
    "missing_candidate_rejected",
    "missing_rollback_rejected",
    "missing_answer_packet_rejected",
    "hidden_multi_model_authority_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_route_rejected",
    "unbeaten_static_baseline_rejected",
    "over_budget_route_rejected",
    "no_runtime_bytes_loaded",
];
const KV_PAGE_CONTROL_QUERY_AWARE_AXES: &[&str] = &[
    "upstream_brain_route_card_pass",
    "kv_page_control_cards_present",
    "query_signatures_bound",
    "mission_ids_bound",
    "model_ids_bound",
    "upstream_route_refs_bound",
    "uas_page_addresses_bound",
    "page_digests_bound",
    "layer_ranges_bound",
    "token_page_ranges_bound",
    "compatibility_fences_bound",
    "query_dependence_bound",
    "criticality_signal_bound",
    "sink_or_heavy_hitter_bound",
    "ranking_signals_bound",
    "privacy_classes_bound",
    "retention_decisions_bound",
    "eviction_decisions_bound",
    "restore_decisions_bound",
    "selected_pages_fit_active_byte_budget",
    "query_aware_beats_recency",
    "query_aware_beats_random",
    "query_aware_beats_file_order",
    "quality_delta_positive",
    "verifier_delta_positive",
    "latency_delta_positive",
    "active_byte_delta_positive",
    "rollback_bound",
    "answer_packet_ref_bound",
    "route_card_ref_bound",
    "page_control_shadow_only",
    "no_hidden_cloud",
    "page_control_address_deterministic",
    "duplicate_policy_rejected",
    "duplicate_page_rejected",
    "stale_page_rejected",
    "incompatible_fence_rejected",
    "missing_digest_rejected",
    "missing_rollback_rejected",
    "missing_answer_packet_rejected",
    "over_budget_selection_rejected",
    "hidden_live_mutation_rejected",
    "verifier_bypass_rejected",
    "cloud_page_rejected",
    "unbeaten_baseline_rejected",
    "no_runtime_bytes_loaded",
];
const NEURAL_CONTROL_CARD_ABLATION_AXES: &[&str] = &[
    "upstream_kv_page_control_pass",
    "neural_control_cards_present",
    "intervention_ids_bound",
    "feature_or_direction_ids_bound",
    "model_ids_bound",
    "layer_or_hook_bound",
    "token_ranges_bound",
    "strength_bounded",
    "start_stop_conditions_bound",
    "expected_effect_bound",
    "baseline_run_bound",
    "intervention_run_bound",
    "ablation_run_bound",
    "run_event_log_bound",
    "rollback_bound",
    "answer_packet_ref_bound",
    "failure_signature_bound",
    "side_effect_budget_bound",
    "active_byte_budget_bound",
    "no_base_weight_mutation",
    "neural_control_shadow_only",
    "route_around_guard_bound",
    "feature_ambiguity_bound",
    "baseline_beaten",
    "ablation_beaten",
    "side_effects_within_budget",
    "quality_delta_positive",
    "verifier_delta_positive",
    "latency_non_regression",
    "active_byte_budget_respected",
    "hidden_chain_not_exposed",
    "no_hidden_cloud",
    "neural_control_address_deterministic",
    "duplicate_intervention_rejected",
    "missing_baseline_rejected",
    "missing_intervention_rejected",
    "missing_ablation_rejected",
    "missing_run_event_log_rejected",
    "missing_rollback_rejected",
    "missing_answer_packet_rejected",
    "base_weight_mutation_rejected",
    "hidden_live_authority_rejected",
    "over_strength_rejected",
    "over_budget_side_effect_rejected",
    "active_byte_budget_rejected",
    "route_around_rejected",
    "ambiguous_feature_rejected",
    "unbeaten_baseline_rejected",
    "unbeaten_ablation_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_intervention_rejected",
    "no_runtime_bytes_loaded",
];
const VERIFIER_REGRET_LEDGER_AXES: &[&str] = &[
    "upstream_neural_control_pass",
    "regret_entries_present",
    "unit_ids_bound",
    "route_ids_bound",
    "task_signatures_bound",
    "baseline_scores_bound",
    "intervention_scores_bound",
    "quality_delta_positive",
    "verifier_delta_bound",
    "evidence_validity_delta_bound",
    "latency_delta_bound",
    "active_byte_delta_bound",
    "failure_modes_bound",
    "regret_updates_bound",
    "next_policy_bound",
    "held_out_task_set_bound",
    "later_route_selection_changed",
    "held_out_regret_reduced",
    "route_utility_update_shadow_only",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "policy_patch_bound",
    "no_hidden_route_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "live_policy_not_mutated",
    "policy_version_advances",
    "upstream_neural_refs_bound",
    "active_byte_budget_respected",
    "regret_address_deterministic",
    "duplicate_entry_rejected",
    "missing_held_out_rejected",
    "missing_regret_update_rejected",
    "missing_next_policy_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "no_route_change_rejected",
    "no_regret_reduction_rejected",
    "hidden_live_authority_rejected",
    "live_policy_mutation_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_route_rejected",
    "over_budget_update_rejected",
    "stale_policy_rejected",
    "no_runtime_bytes_loaded",
];
const ROUTE_SCOUT_SSM_BASELINE_AXES: &[&str] = &[
    "upstream_verifier_regret_ledger_pass",
    "route_scout_fixture_present",
    "training_split_bound",
    "held_out_split_bound",
    "task_signatures_bound",
    "mission_ids_bound",
    "source_features_bound",
    "cache_features_bound",
    "trace_features_bound",
    "verifier_features_bound",
    "hidden_state_bound",
    "route_logits_bound",
    "route_family_labels_bound",
    "verifier_need_labels_bound",
    "scout_predictions_present",
    "scout_cheaper_than_heavy_route",
    "route_family_accuracy_beats_static",
    "route_family_accuracy_beats_random",
    "route_family_accuracy_beats_recency",
    "route_family_accuracy_beats_embedding",
    "verifier_need_accuracy_beats_static",
    "verifier_need_accuracy_beats_random",
    "verifier_need_accuracy_beats_recency",
    "verifier_need_accuracy_beats_embedding",
    "route_calibration_beats_baselines",
    "verifier_calibration_beats_baselines",
    "abstention_case_present",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "no_hidden_route_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "live_policy_not_mutated",
    "scout_address_deterministic",
    "duplicate_task_rejected",
    "missing_label_rejected",
    "missing_feature_rejected",
    "missing_logits_rejected",
    "unknown_route_family_rejected",
    "missing_prediction_rejected",
    "no_held_out_rejected",
    "static_baseline_unbeaten_rejected",
    "random_baseline_unbeaten_rejected",
    "recency_baseline_unbeaten_rejected",
    "embedding_baseline_unbeaten_rejected",
    "verifier_static_baseline_unbeaten_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_live_authority_rejected",
    "live_policy_mutation_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_route_rejected",
    "scout_over_budget_rejected",
    "scout_not_cheaper_rejected",
    "uncalibrated_scout_rejected",
    "no_runtime_bytes_loaded",
];

fn main() {
    let report = build_report();
    let path =
        PathBuf::from("artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json");
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("create capability ceiling artifact directory");
    }
    let mut file = std::fs::File::create(&path).expect("open capability ceiling artifact");
    write_artifact(&mut file, &report.artifact).expect("write capability ceiling artifact");

    println!(
        "Capability Ceiling Evaluation Kernel: overall_pass={} route_status={} next_bottleneck={} artifact={}",
        report.artifact.overall_pass,
        report.route_status,
        report.next_bottleneck,
        path.display()
    );

    if !report.artifact.overall_pass {
        std::process::exit(1);
    }
}

struct KernelReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    route_status: String,
    next_bottleneck: String,
}

fn build_report() -> KernelReport {
    let uas_copy = GateArtifact::read(UAS_COPY_COUNT_PATH);
    let acs_lookup = GateArtifact::read(ACS_ANCHOR_LOOKUP_PATH);
    let uas_spine = GateArtifact::read(UAS_ZERO_COPY_SPINE_PATH);
    let uas_acs_mmap_residency = GateArtifact::read(UAS_ACS_MMAP_RESIDENCY_PATH);
    let page_gather = GateArtifact::read(PAGE_GATHER_PATH);
    let page_gather_caller = GateArtifact::read(PAGE_GATHER_CALLER_PATH);
    let page_gather_policy = GateArtifact::read(PAGE_GATHER_PACKETIZED_POLICY_PATH);
    let kv_direct = GateArtifact::read(KV_DIRECT_PATH);
    let agent_local_model_bridge = GateArtifact::read(AGENT_LOCAL_MODEL_RUNTIME_BRIDGE_PATH);
    let fulp_oracle = GateArtifact::read(FULP_ORACLE_PATH);
    let controller = GateArtifact::read(CONTROLLER_KERNEL_PATH);
    let cocktail = GateArtifact::read(COCKTAIL_LITE_PATH);
    let active_assembly = GateArtifact::read(ACTIVE_ASSEMBLY_ARTIFACT_PATH);
    let sparse_runtime = GateArtifact::read(SPARSE_RUNTIME_SPLIT_PATH);
    let residency_construction_graph = GateArtifact::read(RESIDENCY_CONSTRUCTION_GRAPH_PATH);
    let coactivation_tile_prefetch = GateArtifact::read(COACTIVATION_TILE_PREFETCH_PATH);
    let proof_carrying_residency_lease = GateArtifact::read(PROOF_CARRYING_RESIDENCY_LEASE_PATH);
    let cold_assembly_plan_70b_lite = GateArtifact::read(COLD_ASSEMBLY_PLAN_70B_LITE_PATH);
    let lattice_state_controller = GateArtifact::read(LATTICE_STATE_CONTROLLER_PATH);
    let reasoning_state_continuity = GateArtifact::read(REASONING_STATE_CONTINUITY_PATH);
    let cold_miss_ledger = GateArtifact::read(COLD_MISS_LEDGER_PATH);
    let swiftlm_source_intake = GateArtifact::read(SWIFTLM_SOURCE_INTAKE_PATH);
    let meta_breakthrough_card_registry = GateArtifact::read(META_BREAKTHROUGH_CARD_REGISTRY_PATH);
    let proof_carrying_route_card = GateArtifact::read(PROOF_CARRYING_ROUTE_CARD_PATH);
    let rust_route_kernel_model_check = GateArtifact::read(RUST_ROUTE_KERNEL_MODEL_CHECK_PATH);
    let brain_route_card_multi_model = GateArtifact::read(BRAIN_ROUTE_CARD_MULTI_MODEL_PATH);
    let kv_page_control_query_aware = GateArtifact::read(KV_PAGE_CONTROL_QUERY_AWARE_PATH);
    let neural_control_card_ablation = GateArtifact::read(NEURAL_CONTROL_CARD_ABLATION_PATH);
    let verifier_regret_ledger = GateArtifact::read(VERIFIER_REGRET_LEDGER_PATH);
    let route_scout_ssm_baseline = GateArtifact::read(ROUTE_SCOUT_SSM_BASELINE_PATH);

    let active_assembly_shape_available = Path::new(ACTIVE_ASSEMBLY_TEST_PATH).exists();
    let source_artifacts_present = [
        &uas_copy,
        &acs_lookup,
        &uas_spine,
        &uas_acs_mmap_residency,
        &page_gather,
        &page_gather_caller,
        &page_gather_policy,
        &kv_direct,
        &agent_local_model_bridge,
        &fulp_oracle,
        &controller,
        &cocktail,
        &sparse_runtime,
        &residency_construction_graph,
        &coactivation_tile_prefetch,
        &proof_carrying_residency_lease,
        &cold_assembly_plan_70b_lite,
        &lattice_state_controller,
        &reasoning_state_continuity,
        &cold_miss_ledger,
        &swiftlm_source_intake,
        &meta_breakthrough_card_registry,
        &proof_carrying_route_card,
        &rust_route_kernel_model_check,
        &brain_route_card_multi_model,
        &kv_page_control_query_aware,
        &neural_control_card_ablation,
        &verifier_regret_ledger,
        &route_scout_ssm_baseline,
    ]
    .iter()
    .all(|gate| gate.exists);

    let verified_floor_green = fulp_oracle.overall_pass && controller.overall_pass;
    let uas_copy_count_hot_path_pass = uas_copy.legacy_or_schema_pass();
    let acs_anchor_lookup_pass = acs_lookup.legacy_or_schema_pass();
    let uas_zero_copy_spine_pass = uas_spine.overall_pass;
    let uas_acs_mmap_residency_pass = uas_acs_mmap_residency.overall_pass
        && uas_acs_mmap_residency.all_axes_true(&[
            "mmap_backed_bytes",
            "file_len_matches_mmap",
            "uas_address_round_trip",
            "acs_projection_lookup",
            "residency_lease_round_trip",
            "sampled_page_checksum_match",
            "hot_path_tracked_copies",
        ]);
    let page_gather_packetized_floor_pass = page_gather.all_axes_true(&[
        "packetized_scheduled_correctness_violations_256mb",
        "packetized_scheduled_correctness_violations_512mb",
        "packetized_scheduled_stream_ratio_256mb",
        "packetized_scheduled_stream_ratio_512mb",
    ]);
    let page_gather_dense_primary_pass = page_gather.overall_pass;
    let page_gather_packetized_caller_pass = page_gather_caller.overall_pass;
    let page_gather_packetized_policy_acceptance_pass = page_gather_policy.overall_pass
        && page_gather_policy.all_axes_true(&[
            "packetized_floor_available",
            "packetized_floor_zero_violations",
            "packetized_floor_stream_ratio",
            "packetized_caller_available",
            "packetized_caller_consumed",
            "dense_restore_deferred",
            "retained_limit_honored",
            "policy_scope_retrieval_and_witness_only",
            "dense_primary_not_promoted",
            "rollback_keeps_dense_gate_red",
        ]);
    let kv_direct_tier1_preflight_pass =
        kv_direct.all_axes_true(&["tier1_qk_equality_violations", "tier1_dispatch_contract"]);
    let kv_direct_live_contract_present = kv_direct.axis_true("live_harness_contract_present");
    let kv_direct_model_assets_available = kv_direct.axis_true("model_assets_available");
    let kv_direct_model_identity_matches_canonical =
        kv_direct.axis_true("model_identity_matches_canonical");
    let kv_direct_model_context_supports_required_context =
        kv_direct.axis_true("model_context_supports_required_context");
    let kv_direct_prompt_suite_manifest_available =
        kv_direct.axis_true("prompt_suite_manifest_available");
    let kv_direct_prompt_suite_shape_pass = kv_direct.all_axes_true(&[
        "prompt_suite_prompt_count",
        "prompt_suite_min_context_tokens",
        "prompt_suite_min_decode_tokens_per_prompt",
        "prompt_suite_balanced_family_coverage",
    ]);
    let kv_direct_full_suite_run_plan_available =
        valid_kv_direct_full_suite_run_plan(KV_DIRECT_FULL_SUITE_RUN_PLAN_PATH);
    let kv_direct_logits_available = kv_direct.axis_true("reference_logits_available")
        && kv_direct.axis_true("test_logits_available");
    let kv_direct_live_metrics_available = kv_direct.axis_true("live_metrics_available");
    let kv_direct_spill_trace_available = kv_direct.axis_true("spill_trace_available");
    let kv_direct_spill_trace_contract_pass = kv_direct.all_axes_true(&[
        "spill_trace_ssd_spill_labeled",
        "spill_trace_route_is_canonical",
        "spill_trace_residual_patch_applied",
        "spill_trace_mmap_backed",
        "spill_trace_quantized_storage",
        "spill_trace_cold_kv_bytes",
    ]);
    let kv_direct_live_shape_floor_pass = kv_direct.axis_true("live_prompt_count")
        && kv_direct.axis_true("context_window_tokens")
        && kv_direct.axis_true("decode_tokens_per_prompt");
    let kv_direct_live_128k_pass = kv_direct.overall_pass;
    let heavy_long_context_enabled = heavy_long_context_enabled();
    let agent_local_model_runtime_bridge_pass = agent_local_model_bridge.overall_pass;
    let agent_local_model_runtime_bridge_next_bottleneck = agent_local_model_bridge
        .measurement_string("next_bottleneck")
        .unwrap_or_else(|| "missing_agent_local_model_runtime_bridge_artifact".to_string());
    let active_assembly_runtime_artifact_pass = active_assembly.overall_pass;
    let sparse_runtime_split_artifact_pass = sparse_runtime.overall_pass;
    let residency_construction_graph_pass = residency_construction_graph.overall_pass
        && residency_construction_graph.all_axes_true(&[
            "candidate_units_present",
            "source_card_ids_bound",
            "task_signature_bound",
            "graph_address_deterministic",
            "coactivation_edges_bound",
            "incompatibility_edges_bound",
            "verifier_edges_bound",
            "cold_miss_history_bound",
            "budget_enforced",
            "invalid_assemblies_rejected",
            "rollback_required",
            "no_runtime_bytes_loaded",
        ]);
    let coactivation_tile_prefetch_pass = coactivation_tile_prefetch.overall_pass
        && coactivation_tile_prefetch.all_axes_true(&[
            "coactivation_tiles_present",
            "tile_address_deterministic",
            "tile_units_bound",
            "byte_ranges_nonempty",
            "codec_coverage",
            "verifier_history_bound",
            "rollback_required",
            "prefetch_cost_bounded",
            "compiled_order_priority_sorted",
            "compiled_beats_file_order_misses",
            "compiled_beats_random_misses",
            "compiled_stall_ms_below_baselines",
            "compiled_byte_waste_below_baselines",
            "no_runtime_bytes_loaded",
        ]);
    let proof_carrying_residency_lease_pass = proof_carrying_residency_lease.overall_pass
        && proof_carrying_residency_lease.all_axes_true(&[
            "proof_carrying_leases_present",
            "uas_addresses_bound",
            "lease_reasons_bound",
            "active_byte_costs_bound",
            "expected_utility_bound",
            "proof_or_falsifier_refs_bound",
            "expiry_bound",
            "fallback_bound",
            "rollback_bound",
            "lease_tier_capability_ceiling",
            "lease_address_deterministic",
            "cold_wakes_authorized",
            "wake_without_lease_rejected",
            "missing_reason_rejected",
            "missing_proof_rejected",
            "missing_fallback_rejected",
            "missing_rollback_rejected",
            "expired_lease_rejected",
            "over_budget_wake_rejected",
            "wrong_lease_rejected",
            "no_runtime_bytes_loaded",
        ]);
    let cold_assembly_plan_70b_lite_pass = cold_assembly_plan_70b_lite.overall_pass
        && cold_assembly_plan_70b_lite.all_axes_true(&[
            "cold_assembly_plan_present",
            "mission_id_bound",
            "construction_graph_ref_bound",
            "active_tiles_bound",
            "warm_tiles_bound",
            "cold_tiles_bound",
            "hot_bytes_bound",
            "warm_bytes_bound",
            "cold_bytes_bound",
            "active_executed_bytes_bound",
            "kv_bytes_bound",
            "adapter_bytes_bound",
            "peak_rss_bound",
            "prefetch_order_bound",
            "proof_leases_bound",
            "all_cold_wakes_scheduled_or_skipped",
            "verifier_stack_bound",
            "fallback_bound",
            "rollback_verified",
            "answer_packet_ref_bound",
            "beats_dense_local_baseline",
            "beats_rag_only_baseline",
            "beats_static_route_baseline",
            "no_hidden_cloud",
            "no_dense_resident_overclaim",
            "no_runtime_bytes_loaded",
            "plan_address_deterministic",
            "quality_delta_positive",
            "evidence_validity_delta_positive",
            "verifier_delta_positive",
            "unscheduled_cold_wake_rejected",
            "missing_lease_rejected",
        ]);
    let lattice_state_controller_pass = lattice_state_controller.overall_pass
        && lattice_state_controller.all_axes_true(&[
            "lattice_controller_present",
            "source_card_ids_bound",
            "task_signature_bound",
            "abstract_route_state_bound",
            "candidate_actions_bound",
            "selected_action_bound",
            "static_policy_action_bound",
            "monotone_progress_metric_bound",
            "uncertainty_bound",
            "conflict_signal_bound",
            "abstain_condition_bound",
            "verifier_feedback_bound",
            "abstains_when_uncertain",
            "beats_static_policy_baseline",
            "beats_random_policy_baseline",
            "beats_always_retrieve_baseline",
            "quality_delta_positive",
            "evidence_validity_delta_positive",
            "verifier_delta_positive",
            "route_success_delta_positive",
            "abstention_delta_positive",
            "fallback_bound",
            "rollback_verified",
            "answer_packet_ref_bound",
            "no_hidden_live_route_authority",
            "hidden_chain_not_exposed",
            "high_uncertainty_non_abstain_rejected",
            "unbeaten_static_policy_rejected",
            "no_runtime_bytes_loaded",
            "controller_address_deterministic",
        ]);
    let reasoning_state_continuity_pass = reasoning_state_continuity.overall_pass
        && reasoning_state_continuity.all_axes_true(&[
            "reasoning_state_card_present",
            "source_card_ids_bound",
            "task_signature_bound",
            "session_id_bound",
            "model_id_bound",
            "preserved_state_kind_bound",
            "privacy_class_bound",
            "visible_summary_present",
            "cache_key_bound",
            "restore_policy_bound",
            "compatibility_fence_bound",
            "verifier_caveat_bound",
            "purge_policy_bound",
            "compute_resume_lease_bound",
            "fallback_bound",
            "rollback_verified",
            "answer_packet_ref_bound",
            "beats_no_state_baseline",
            "beats_naive_cache_baseline",
            "beats_static_summary_baseline",
            "continuity_delta_positive",
            "cache_utility_delta_positive",
            "verifier_delta_positive",
            "latency_delta_positive",
            "active_bytes_delta_positive",
            "hidden_chain_not_exposed",
            "verifier_bypass_rejected",
            "stale_state_reuse_rejected",
            "missing_purge_policy_rejected",
            "incompatible_fence_rejected",
            "missing_answer_packet_rejected",
            "unbeaten_naive_cache_rejected",
            "no_runtime_bytes_loaded",
            "continuity_card_address_deterministic",
        ]);
    let cold_miss_ledger_pass = cold_miss_ledger.overall_pass
        && cold_miss_ledger.all_axes_true(&[
            "cold_miss_ledger_present",
            "route_id_bound",
            "source_card_ids_bound",
            "task_signature_bound",
            "repeated_misses_recorded",
            "missed_unit_bound",
            "miss_time_bound",
            "stall_ms_reported",
            "cold_io_bytes_reported",
            "fallback_used_visible",
            "verifier_delta_reported",
            "next_prefetch_policy_bound",
            "policy_patch_ref_bound",
            "policy_patch_shadow_scoped",
            "rollback_bound",
            "run_event_log_bound",
            "answer_packet_ref_bound",
            "held_out_misses_reduced",
            "repeated_stall_reduced",
            "storage_wear_bounded",
            "production_mutation_blocked",
            "single_miss_rejected",
            "no_improvement_rejected",
            "missing_rollback_rejected",
            "missing_policy_patch_rejected",
            "zero_stall_rejected",
            "high_wear_rejected",
            "no_runtime_bytes_loaded",
            "ledger_address_deterministic",
        ]);
    let swiftlm_source_intake_pass = swiftlm_source_intake.overall_pass
        && swiftlm_source_intake.all_axes_true(&[
            "swiftlm_source_cards_present",
            "swiftlm_repo_card_present",
            "source_cards_sorted",
            "source_graph_edges_bound",
            "source_graph_route_affinity_bound",
            "source_graph_address_deterministic",
            "ssd_streaming_motif_captured",
            "kv_compression_motif_captured",
            "persistent_buffer_motif_captured",
            "prefetch_motif_captured",
            "license_note_present",
            "setup_note_present",
            "benchmark_caveat_present",
            "local_test_plan_present",
            "no_code_import_declared",
            "no_product_dependency_declared",
            "no_runtime_bytes_loaded",
            "duplicate_source_rejected",
            "missing_license_rejected",
            "missing_benchmark_caveat_rejected",
            "missing_local_test_plan_rejected",
            "implementation_import_rejected",
        ]);
    let meta_breakthrough_card_registry_pass = meta_breakthrough_card_registry.overall_pass
        && meta_breakthrough_card_registry.all_axes_true(&[
            "meta_card_registry_present",
            "card_kinds_coverage",
            "uas_addresses_bound",
            "source_refs_bound",
            "budget_vectors_bound",
            "rollback_handles_bound",
            "proof_or_falsifier_state_bound",
            "answer_packet_visibility_bound",
            "route_authority_shadow_only",
            "registry_address_deterministic",
            "duplicate_card_rejected",
            "missing_uas_address_rejected",
            "missing_source_rejected",
            "missing_budget_rejected",
            "missing_rollback_rejected",
            "missing_proof_state_rejected",
            "missing_answer_packet_rejected",
            "hidden_live_authority_rejected",
            "no_runtime_bytes_loaded",
        ]);
    let proof_carrying_route_card_pass = proof_carrying_route_card.overall_pass
        && proof_carrying_route_card.all_axes_true(&[
            "proof_route_cards_present",
            "route_ids_bound",
            "mission_ids_bound",
            "preconditions_bound",
            "postconditions_bound",
            "budget_invariants_bound",
            "state_transition_bound",
            "allowed_mutations_bound",
            "rollback_handle_bound",
            "proof_or_model_check_artifact_bound",
            "pinned_toolchain_version_bound",
            "answer_packet_ref_bound",
            "answer_packet_required_fields_bound",
            "route_schema_complete",
            "route_card_address_deterministic",
            "duplicate_route_card_rejected",
            "missing_preconditions_rejected",
            "missing_postconditions_rejected",
            "missing_rollback_rejected",
            "missing_artifact_ref_rejected",
            "unpinned_toolchain_rejected",
            "missing_answer_packet_rejected",
            "budget_increase_rejected",
            "hidden_live_mutation_rejected",
            "no_runtime_bytes_loaded",
        ]);
    let rust_route_kernel_model_check_pass = rust_route_kernel_model_check.overall_pass
        && rust_route_kernel_model_check.all_axes_true(RUST_ROUTE_KERNEL_MODEL_CHECK_AXES);
    let brain_route_card_multi_model_pass = brain_route_card_multi_model.overall_pass
        && brain_route_card_multi_model.all_axes_true(BRAIN_ROUTE_CARD_MULTI_MODEL_AXES);
    let kv_page_control_query_aware_pass = kv_page_control_query_aware.overall_pass
        && kv_page_control_query_aware.all_axes_true(KV_PAGE_CONTROL_QUERY_AWARE_AXES);
    let neural_control_card_ablation_pass = neural_control_card_ablation.overall_pass
        && neural_control_card_ablation.all_axes_true(NEURAL_CONTROL_CARD_ABLATION_AXES);
    let verifier_regret_ledger_pass = verifier_regret_ledger.overall_pass
        && verifier_regret_ledger.all_axes_true(VERIFIER_REGRET_LEDGER_AXES);
    let route_scout_ssm_baseline_pass = route_scout_ssm_baseline.overall_pass
        && route_scout_ssm_baseline.all_axes_true(ROUTE_SCOUT_SSM_BASELINE_AXES);
    let seventy_b_route_pass = cocktail.overall_pass;
    let seventy_b_bottleneck_identified = cocktail.axis_true("bottleneck_identified");
    let all_gate_artifacts_schema_normalized = [
        &uas_copy,
        &acs_lookup,
        &uas_spine,
        &uas_acs_mmap_residency,
        &page_gather,
        &page_gather_caller,
        &page_gather_policy,
        &kv_direct,
        &agent_local_model_bridge,
        &fulp_oracle,
        &controller,
        &cocktail,
        &sparse_runtime,
        &residency_construction_graph,
        &coactivation_tile_prefetch,
        &proof_carrying_residency_lease,
        &cold_assembly_plan_70b_lite,
        &lattice_state_controller,
        &reasoning_state_continuity,
        &cold_miss_ledger,
        &swiftlm_source_intake,
        &meta_breakthrough_card_registry,
        &proof_carrying_route_card,
        &rust_route_kernel_model_check,
        &brain_route_card_multi_model,
        &kv_page_control_query_aware,
        &neural_control_card_ablation,
        &verifier_regret_ledger,
        &route_scout_ssm_baseline,
    ]
    .iter()
    .all(|gate| gate.schema_normalized);

    let route_status = classify_route(
        verified_floor_green,
        uas_acs_mmap_residency_pass,
        page_gather_packetized_floor_pass,
        page_gather_dense_primary_pass,
        page_gather_packetized_caller_pass,
        page_gather_packetized_policy_acceptance_pass,
        kv_direct_live_128k_pass,
        agent_local_model_runtime_bridge_pass,
        active_assembly_runtime_artifact_pass,
        sparse_runtime_split_artifact_pass,
        coactivation_tile_prefetch_pass,
        proof_carrying_residency_lease_pass,
        cold_assembly_plan_70b_lite_pass,
        lattice_state_controller_pass,
        reasoning_state_continuity_pass,
        cold_miss_ledger_pass,
        swiftlm_source_intake_pass,
        meta_breakthrough_card_registry_pass,
        proof_carrying_route_card_pass,
        rust_route_kernel_model_check_pass,
        brain_route_card_multi_model_pass,
        kv_page_control_query_aware_pass,
        neural_control_card_ablation_pass,
        verifier_regret_ledger_pass,
        route_scout_ssm_baseline_pass,
        seventy_b_route_pass,
        all_gate_artifacts_schema_normalized,
    );
    let next_bottleneck = next_bottleneck(
        all_gate_artifacts_schema_normalized,
        uas_copy_count_hot_path_pass,
        acs_anchor_lookup_pass,
        uas_acs_mmap_residency_pass,
        page_gather_packetized_floor_pass,
        page_gather_dense_primary_pass,
        page_gather_packetized_caller_pass,
        page_gather_packetized_policy_acceptance_pass,
        kv_direct_live_contract_present,
        kv_direct_model_assets_available,
        kv_direct_model_identity_matches_canonical,
        kv_direct_model_context_supports_required_context,
        kv_direct_prompt_suite_manifest_available,
        kv_direct_prompt_suite_shape_pass,
        kv_direct_full_suite_run_plan_available,
        kv_direct_logits_available,
        kv_direct_live_metrics_available,
        kv_direct_spill_trace_available,
        kv_direct_spill_trace_contract_pass,
        kv_direct_live_shape_floor_pass,
        kv_direct_live_128k_pass,
        heavy_long_context_enabled,
        agent_local_model_runtime_bridge_pass,
        &agent_local_model_runtime_bridge_next_bottleneck,
        active_assembly_runtime_artifact_pass,
        sparse_runtime_split_artifact_pass,
        residency_construction_graph_pass,
        coactivation_tile_prefetch_pass,
        proof_carrying_residency_lease_pass,
        cold_assembly_plan_70b_lite_pass,
        lattice_state_controller_pass,
        reasoning_state_continuity_pass,
        cold_miss_ledger_pass,
        swiftlm_source_intake_pass,
        meta_breakthrough_card_registry_pass,
        proof_carrying_route_card_pass,
        rust_route_kernel_model_check_pass,
        brain_route_card_multi_model_pass,
        kv_page_control_query_aware_pass,
        neural_control_card_ablation_pass,
        verifier_regret_ledger_pass,
        route_scout_ssm_baseline_pass,
        seventy_b_route_pass,
        &cocktail,
    );
    let cocktail_primary_bottleneck = cocktail
        .measurement_string("primary_bottleneck")
        .unwrap_or_else(|| "missing_70b_artifact_bottleneck".to_string());
    let ordered_build_queue = build_ordered_gap_queue(
        all_gate_artifacts_schema_normalized,
        verified_floor_green,
        uas_copy_count_hot_path_pass,
        acs_anchor_lookup_pass,
        uas_acs_mmap_residency_pass,
        page_gather_packetized_floor_pass,
        page_gather_dense_primary_pass,
        page_gather_packetized_caller_pass,
        page_gather_packetized_policy_acceptance_pass,
        kv_direct_live_contract_present,
        kv_direct_model_assets_available,
        kv_direct_model_identity_matches_canonical,
        kv_direct_model_context_supports_required_context,
        kv_direct_prompt_suite_manifest_available,
        kv_direct_prompt_suite_shape_pass,
        kv_direct_full_suite_run_plan_available,
        kv_direct_logits_available,
        kv_direct_live_metrics_available,
        kv_direct_spill_trace_available,
        kv_direct_spill_trace_contract_pass,
        kv_direct_live_shape_floor_pass,
        kv_direct_live_128k_pass,
        heavy_long_context_enabled,
        agent_local_model_runtime_bridge_pass,
        &agent_local_model_runtime_bridge_next_bottleneck,
        active_assembly_runtime_artifact_pass,
        sparse_runtime_split_artifact_pass,
        residency_construction_graph_pass,
        coactivation_tile_prefetch_pass,
        proof_carrying_residency_lease_pass,
        cold_assembly_plan_70b_lite_pass,
        lattice_state_controller_pass,
        reasoning_state_continuity_pass,
        cold_miss_ledger_pass,
        swiftlm_source_intake_pass,
        meta_breakthrough_card_registry_pass,
        proof_carrying_route_card_pass,
        rust_route_kernel_model_check_pass,
        brain_route_card_multi_model_pass,
        kv_page_control_query_aware_pass,
        neural_control_card_ablation_pass,
        verifier_regret_ledger_pass,
        route_scout_ssm_baseline_pass,
        seventy_b_route_pass,
        &cocktail_primary_bottleneck,
    );
    let unmapped_architecture_gap_count = count_unmapped_gaps(&ordered_build_queue);

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_artifacts_present",
        source_artifacts_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "all_gate_artifacts_schema_normalized",
        all_gate_artifacts_schema_normalized,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verified_floor_green",
        verified_floor_green,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "uas_copy_count_hot_path_pass",
        uas_copy_count_hot_path_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "acs_anchor_lookup_pass",
        acs_anchor_lookup_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "uas_zero_copy_spine_pass",
        uas_zero_copy_spine_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "uas_acs_mmap_residency_pass",
        uas_acs_mmap_residency_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_gather_packetized_floor_pass",
        page_gather_packetized_floor_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_gather_dense_primary_pass",
        page_gather_dense_primary_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_gather_packetized_caller_pass",
        page_gather_packetized_caller_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_gather_packetized_policy_acceptance_pass",
        page_gather_packetized_policy_acceptance_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_tier1_preflight_pass",
        kv_direct_tier1_preflight_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_live_contract_present",
        kv_direct_live_contract_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_model_assets_available",
        kv_direct_model_assets_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_model_identity_matches_canonical",
        kv_direct_model_identity_matches_canonical,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_model_context_supports_required_context",
        kv_direct_model_context_supports_required_context,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_prompt_suite_manifest_available",
        kv_direct_prompt_suite_manifest_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_prompt_suite_shape_pass",
        kv_direct_prompt_suite_shape_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_full_suite_run_plan_available",
        kv_direct_full_suite_run_plan_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_logits_available",
        kv_direct_logits_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_live_metrics_available",
        kv_direct_live_metrics_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_spill_trace_available",
        kv_direct_spill_trace_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_spill_trace_contract_pass",
        kv_direct_spill_trace_contract_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_live_shape_floor_pass",
        kv_direct_live_shape_floor_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_direct_live_128k_pass",
        kv_direct_live_128k_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "agent_local_model_runtime_bridge_pass",
        agent_local_model_runtime_bridge_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_assembly_shape_proof_available",
        active_assembly_shape_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_assembly_runtime_artifact_pass",
        active_assembly_runtime_artifact_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sparse_runtime_split_artifact_pass",
        sparse_runtime_split_artifact_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "residency_construction_graph_pass",
        residency_construction_graph_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "coactivation_tile_prefetch_pass",
        coactivation_tile_prefetch_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_carrying_residency_lease_pass",
        proof_carrying_residency_lease_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_assembly_plan_70b_lite_pass",
        cold_assembly_plan_70b_lite_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lattice_state_controller_pass",
        lattice_state_controller_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "reasoning_state_continuity_pass",
        reasoning_state_continuity_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_miss_ledger_pass",
        cold_miss_ledger_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "swiftlm_source_intake_pass",
        swiftlm_source_intake_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "meta_breakthrough_card_registry_pass",
        meta_breakthrough_card_registry_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_carrying_route_card_pass",
        proof_carrying_route_card_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rust_route_kernel_model_check_pass",
        rust_route_kernel_model_check_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "brain_route_card_multi_model_pass",
        brain_route_card_multi_model_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_page_control_query_aware_pass",
        kv_page_control_query_aware_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "neural_control_card_ablation_pass",
        neural_control_card_ablation_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_regret_ledger_pass",
        verifier_regret_ledger_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_scout_ssm_baseline_pass",
        route_scout_ssm_baseline_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "seventy_b_bottleneck_identified",
        seventy_b_bottleneck_identified,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "seventy_b_route_pass",
        seventy_b_route_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "canonical_build_queue_present",
        !ordered_build_queue.is_empty(),
    );
    add_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unmapped_architecture_gap_count",
        unmapped_architecture_gap_count,
        0,
    );

    add_label(&mut measurements, "route_status", &route_status);
    add_label(&mut measurements, "next_bottleneck", &next_bottleneck);
    add_label(
        &mut measurements,
        "cocktail_primary_bottleneck",
        &cocktail_primary_bottleneck,
    );
    add_label(
        &mut measurements,
        "agent_local_model_runtime_bridge_next_bottleneck",
        &agent_local_model_runtime_bridge_next_bottleneck,
    );
    add_bool_measurement(&mut measurements, "heavy_long_context_guard_present", true);
    add_bool_measurement(
        &mut measurements,
        "heavy_long_context_enabled",
        heavy_long_context_enabled,
    );
    add_bool_measurement(
        &mut measurements,
        "kv_direct_128k_route_active",
        heavy_long_context_enabled,
    );
    measurements.insert(
        "ordered_build_queue".to_string(),
        Measurement {
            value: serde_json::Value::Array(ordered_build_queue),
            unit: "queue".to_string(),
        },
    );
    add_gate_summary(&mut measurements, "uas_copy_count", &uas_copy);
    add_gate_summary(&mut measurements, "acs_anchor_lookup", &acs_lookup);
    add_gate_summary(
        &mut measurements,
        "uas_acs_mmap_residency",
        &uas_acs_mmap_residency,
    );
    add_gate_summary(&mut measurements, "page_gather", &page_gather);
    add_gate_summary(
        &mut measurements,
        "page_gather_packetized_caller",
        &page_gather_caller,
    );
    add_gate_summary(
        &mut measurements,
        "page_gather_packetized_policy_acceptance",
        &page_gather_policy,
    );
    add_gate_summary(&mut measurements, "kv_direct", &kv_direct);
    add_gate_summary(
        &mut measurements,
        "agent_local_model_runtime_bridge",
        &agent_local_model_bridge,
    );
    add_gate_summary(&mut measurements, "sparse_runtime_split", &sparse_runtime);
    add_gate_summary(
        &mut measurements,
        "residency_construction_graph",
        &residency_construction_graph,
    );
    add_gate_summary(
        &mut measurements,
        "coactivation_tile_prefetch",
        &coactivation_tile_prefetch,
    );
    add_gate_summary(
        &mut measurements,
        "proof_carrying_residency_lease",
        &proof_carrying_residency_lease,
    );
    add_gate_summary(
        &mut measurements,
        "cold_assembly_plan_70b_lite",
        &cold_assembly_plan_70b_lite,
    );
    add_gate_summary(
        &mut measurements,
        "lattice_state_controller",
        &lattice_state_controller,
    );
    add_gate_summary(
        &mut measurements,
        "reasoning_state_continuity",
        &reasoning_state_continuity,
    );
    add_gate_summary(&mut measurements, "cold_miss_ledger", &cold_miss_ledger);
    add_gate_summary(
        &mut measurements,
        "swiftlm_source_intake",
        &swiftlm_source_intake,
    );
    add_gate_summary(
        &mut measurements,
        "meta_breakthrough_card_registry",
        &meta_breakthrough_card_registry,
    );
    add_gate_summary(
        &mut measurements,
        "proof_carrying_route_card",
        &proof_carrying_route_card,
    );
    add_gate_summary(
        &mut measurements,
        "rust_route_kernel_model_check",
        &rust_route_kernel_model_check,
    );
    add_gate_summary(
        &mut measurements,
        "brain_route_card_multi_model",
        &brain_route_card_multi_model,
    );
    add_gate_summary(
        &mut measurements,
        "kv_page_control_query_aware",
        &kv_page_control_query_aware,
    );
    add_gate_summary(
        &mut measurements,
        "neural_control_card_ablation",
        &neural_control_card_ablation,
    );
    add_gate_summary(
        &mut measurements,
        "verifier_regret_ledger",
        &verifier_regret_ledger,
    );
    add_gate_summary(
        &mut measurements,
        "route_scout_ssm_baseline",
        &route_scout_ssm_baseline,
    );
    add_gate_summary(&mut measurements, "seventy_b_lite", &cocktail);

    let anomalies = build_anomalies(
        all_gate_artifacts_schema_normalized,
        uas_acs_mmap_residency_pass,
        page_gather_dense_primary_pass,
        page_gather_packetized_caller_pass,
        page_gather_packetized_policy_acceptance_pass,
        kv_direct_model_identity_matches_canonical,
        kv_direct_model_context_supports_required_context,
        kv_direct_live_128k_pass,
        heavy_long_context_enabled,
        agent_local_model_runtime_bridge_pass,
        active_assembly_runtime_artifact_pass,
        sparse_runtime_split_artifact_pass,
        residency_construction_graph_pass,
        coactivation_tile_prefetch_pass,
        proof_carrying_residency_lease_pass,
        cold_assembly_plan_70b_lite_pass,
        lattice_state_controller_pass,
        reasoning_state_continuity_pass,
        cold_miss_ledger_pass,
        swiftlm_source_intake_pass,
        meta_breakthrough_card_registry_pass,
        proof_carrying_route_card_pass,
        rust_route_kernel_model_check_pass,
        brain_route_card_multi_model_pass,
        kv_page_control_query_aware_pass,
        neural_control_card_ablation_pass,
        verifier_regret_ledger_pass,
        route_scout_ssm_baseline_pass,
        seventy_b_route_pass,
        &next_bottleneck,
    );

    let notes = format!(
        "route_rollup_failure_report; status={route_status}; next_bottleneck={next_bottleneck}; \
         dense 36B MLX gate remains 32 GB; 16 GB Capability Ceiling route remains Vault/Research \
         until PageGather dense primary or accepted packetized policy, live KV-Direct 128K, \
         live AgentRuntimeV2 local-model dispatch, live sparse 70B, and schema-normalized artifacts pass; \
         128K local probes require EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1"
    );

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: if route_status == "ready_for_product_route" {
            ArtifactKind::PrimaryWitness
        } else {
            ArtifactKind::FailureReport
        },
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: if route_status == "ready_for_product_route" {
            FallbackTier::Primary
        } else {
            FallbackTier::Fail
        },
        anomalies,
        notes,
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    KernelReport {
        artifact,
        route_status,
        next_bottleneck,
    }
}

#[derive(Debug)]
struct GateArtifact {
    path: &'static str,
    exists: bool,
    schema_normalized: bool,
    status_pass: bool,
    overall_pass: bool,
    fallback_tier: Option<String>,
    value: Option<serde_json::Value>,
}

impl GateArtifact {
    fn read(path: &'static str) -> Self {
        let value = std::fs::read_to_string(path)
            .ok()
            .and_then(|s| serde_json::from_str::<serde_json::Value>(&s).ok());
        let exists = value.is_some();
        let schema_normalized = value
            .as_ref()
            .map(has_schema_normalized_shape)
            .unwrap_or(false);
        let status_pass = value
            .as_ref()
            .and_then(|v| v.get("status"))
            .and_then(|v| v.as_str())
            .map(|s| s.eq_ignore_ascii_case("PASS"))
            .unwrap_or(false);
        let overall_pass = value
            .as_ref()
            .and_then(|v| v.get("overall_pass"))
            .and_then(|v| v.as_bool())
            .unwrap_or(false);
        let fallback_tier = value
            .as_ref()
            .and_then(|v| v.get("fallback_tier"))
            .and_then(|v| v.as_str())
            .map(ToString::to_string);
        Self {
            path,
            exists,
            schema_normalized,
            status_pass,
            overall_pass,
            fallback_tier,
            value,
        }
    }

    fn legacy_or_schema_pass(&self) -> bool {
        self.overall_pass || (self.status_pass && self.pass_axes_all_true())
    }

    fn pass_axes_all_true(&self) -> bool {
        self.value
            .as_ref()
            .and_then(|v| v.get("pass_per_axis"))
            .and_then(|v| v.as_object())
            .map(|axes| axes.values().all(|v| v.as_bool().unwrap_or(false)))
            .unwrap_or(false)
    }

    fn axis_true(&self, axis: &str) -> bool {
        self.value
            .as_ref()
            .and_then(|v| v.get("pass_per_axis"))
            .and_then(|v| v.get(axis))
            .and_then(|v| v.as_bool())
            .unwrap_or(false)
    }

    fn all_axes_true(&self, axes: &[&str]) -> bool {
        self.exists && axes.iter().all(|axis| self.axis_true(axis))
    }

    fn measurement_string(&self, name: &str) -> Option<String> {
        self.value
            .as_ref()
            .and_then(|v| v.get("measurements"))
            .and_then(|v| v.get(name))
            .and_then(|m| m.get("value").or(Some(m)))
            .and_then(|v| v.as_str())
            .map(ToString::to_string)
    }
}

fn has_schema_normalized_shape(v: &serde_json::Value) -> bool {
    [
        "falsifier_id",
        "artifact_kind",
        "hardware_pin",
        "command_digest",
        "runner_environment",
        "commit_sha",
        "result_digest",
        "overall_pass",
        "fallback_tier",
    ]
    .iter()
    .all(|field| v.get(*field).is_some())
}

fn valid_kv_direct_full_suite_run_plan(path: &str) -> bool {
    let value = match std::fs::read_to_string(path)
        .ok()
        .and_then(|s| serde_json::from_str::<serde_json::Value>(&s).ok())
    {
        Some(value) => value,
        None => return false,
    };
    let prompt_count = value
        .get("prompt_count")
        .and_then(|v| v.as_u64())
        .unwrap_or_default();
    let target_context_tokens = value
        .get("target_context_tokens")
        .and_then(|v| v.as_u64())
        .unwrap_or_default();
    let decode_tokens_per_prompt = value
        .get("decode_tokens_per_prompt")
        .and_then(|v| v.as_u64())
        .unwrap_or_default();
    let shard_count = value
        .get("shard_count")
        .and_then(|v| v.as_u64())
        .unwrap_or_default();
    let shards = value
        .get("shards")
        .and_then(|v| v.as_array())
        .map(Vec::as_slice)
        .unwrap_or(&[]);
    let has_merge = value
        .get("merge_command")
        .and_then(|v| v.as_array())
        .map(|command| !command.is_empty())
        .unwrap_or(false);
    let has_falsifier_env = value
        .get("falsifier_env")
        .and_then(|v| v.as_object())
        .map(|env| {
            [
                "EPISTEMOS_KV_DIRECT_PROMPT_SUITE",
                "EPISTEMOS_KV_DIRECT_REFERENCE_LOGITS",
                "EPISTEMOS_KV_DIRECT_TEST_LOGITS",
                "EPISTEMOS_KV_DIRECT_METRICS_PATH",
                "EPISTEMOS_KV_DIRECT_SPILL_TRACE",
            ]
            .iter()
            .all(|key| env.get(*key).and_then(|v| v.as_str()).is_some())
        })
        .unwrap_or(false);
    let required_route_labeled = value
        .get("canonical_spill_route_required")
        .and_then(|v| v.as_str())
        .map(|route| route == "residual_patched_mmap_nf4_ssd_spill")
        .unwrap_or(false);
    let shards_are_executable = !shards.is_empty()
        && shards.len() == shard_count as usize
        && shards.iter().all(|shard| {
            let max_prompts = shard
                .get("max_prompts")
                .and_then(|v| v.as_u64())
                .unwrap_or_default();
            let prompt_ids = shard
                .get("prompt_ids")
                .and_then(|v| v.as_array())
                .map(Vec::as_slice)
                .unwrap_or(&[]);
            let command = shard
                .get("run_command")
                .and_then(|v| v.as_array())
                .map(Vec::as_slice)
                .unwrap_or(&[]);
            max_prompts > 0
                && max_prompts as usize == prompt_ids.len()
                && command
                    .iter()
                    .any(|arg| arg.as_str() == Some("--allow-full-suite"))
                && command
                    .iter()
                    .any(|arg| arg.as_str() == Some("--prompt-offset"))
                && command
                    .iter()
                    .any(|arg| arg.as_str() == Some("--max-prompts"))
        });

    prompt_count >= 100
        && target_context_tokens >= 128_000
        && decode_tokens_per_prompt >= 256
        && shard_count > 0
        && has_merge
        && has_falsifier_env
        && required_route_labeled
        && shards_are_executable
}

fn classify_route(
    verified_floor_green: bool,
    uas_acs_mmap_residency_pass: bool,
    page_gather_packetized_floor_pass: bool,
    page_gather_dense_primary_pass: bool,
    _page_gather_packetized_caller_pass: bool,
    page_gather_packetized_policy_acceptance_pass: bool,
    kv_direct_live_128k_pass: bool,
    agent_local_model_runtime_bridge_pass: bool,
    active_assembly_runtime_artifact_pass: bool,
    sparse_runtime_split_artifact_pass: bool,
    coactivation_tile_prefetch_pass: bool,
    proof_carrying_residency_lease_pass: bool,
    cold_assembly_plan_70b_lite_pass: bool,
    lattice_state_controller_pass: bool,
    reasoning_state_continuity_pass: bool,
    cold_miss_ledger_pass: bool,
    swiftlm_source_intake_pass: bool,
    meta_breakthrough_card_registry_pass: bool,
    proof_carrying_route_card_pass: bool,
    rust_route_kernel_model_check_pass: bool,
    brain_route_card_multi_model_pass: bool,
    kv_page_control_query_aware_pass: bool,
    neural_control_card_ablation_pass: bool,
    verifier_regret_ledger_pass: bool,
    route_scout_ssm_baseline_pass: bool,
    seventy_b_route_pass: bool,
    all_gate_artifacts_schema_normalized: bool,
) -> String {
    if verified_floor_green
        && uas_acs_mmap_residency_pass
        && (page_gather_dense_primary_pass || page_gather_packetized_policy_acceptance_pass)
        && kv_direct_live_128k_pass
        && agent_local_model_runtime_bridge_pass
        && active_assembly_runtime_artifact_pass
        && sparse_runtime_split_artifact_pass
        && coactivation_tile_prefetch_pass
        && proof_carrying_residency_lease_pass
        && cold_assembly_plan_70b_lite_pass
        && lattice_state_controller_pass
        && reasoning_state_continuity_pass
        && cold_miss_ledger_pass
        && swiftlm_source_intake_pass
        && meta_breakthrough_card_registry_pass
        && proof_carrying_route_card_pass
        && rust_route_kernel_model_check_pass
        && brain_route_card_multi_model_pass
        && kv_page_control_query_aware_pass
        && neural_control_card_ablation_pass
        && verifier_regret_ledger_pass
        && route_scout_ssm_baseline_pass
        && seventy_b_route_pass
        && all_gate_artifacts_schema_normalized
    {
        "ready_for_product_route".to_string()
    } else if verified_floor_green
        && uas_acs_mmap_residency_pass
        && page_gather_packetized_floor_pass
    {
        "vault_research_route_with_packetized_mitigation".to_string()
    } else if verified_floor_green && uas_acs_mmap_residency_pass {
        "verified_floor_only".to_string()
    } else {
        "foundation_incomplete".to_string()
    }
}

fn next_bottleneck(
    all_gate_artifacts_schema_normalized: bool,
    uas_copy_count_hot_path_pass: bool,
    acs_anchor_lookup_pass: bool,
    uas_acs_mmap_residency_pass: bool,
    page_gather_packetized_floor_pass: bool,
    page_gather_dense_primary_pass: bool,
    page_gather_packetized_caller_pass: bool,
    page_gather_packetized_policy_acceptance_pass: bool,
    kv_direct_live_contract_present: bool,
    kv_direct_model_assets_available: bool,
    kv_direct_model_identity_matches_canonical: bool,
    kv_direct_model_context_supports_required_context: bool,
    kv_direct_prompt_suite_manifest_available: bool,
    kv_direct_prompt_suite_shape_pass: bool,
    kv_direct_full_suite_run_plan_available: bool,
    kv_direct_logits_available: bool,
    kv_direct_live_metrics_available: bool,
    kv_direct_spill_trace_available: bool,
    kv_direct_spill_trace_contract_pass: bool,
    kv_direct_live_shape_floor_pass: bool,
    kv_direct_live_128k_pass: bool,
    heavy_long_context_enabled: bool,
    agent_local_model_runtime_bridge_pass: bool,
    agent_local_model_runtime_bridge_next_bottleneck: &str,
    active_assembly_runtime_artifact_pass: bool,
    sparse_runtime_split_artifact_pass: bool,
    residency_construction_graph_pass: bool,
    coactivation_tile_prefetch_pass: bool,
    proof_carrying_residency_lease_pass: bool,
    cold_assembly_plan_70b_lite_pass: bool,
    lattice_state_controller_pass: bool,
    reasoning_state_continuity_pass: bool,
    cold_miss_ledger_pass: bool,
    swiftlm_source_intake_pass: bool,
    meta_breakthrough_card_registry_pass: bool,
    proof_carrying_route_card_pass: bool,
    rust_route_kernel_model_check_pass: bool,
    brain_route_card_multi_model_pass: bool,
    kv_page_control_query_aware_pass: bool,
    neural_control_card_ablation_pass: bool,
    verifier_regret_ledger_pass: bool,
    route_scout_ssm_baseline_pass: bool,
    seventy_b_route_pass: bool,
    cocktail: &GateArtifact,
) -> String {
    if !all_gate_artifacts_schema_normalized {
        "normalize_legacy_uas_and_acs_artifacts".to_string()
    } else if !uas_copy_count_hot_path_pass {
        "restore_uas_copy_count_hot_path_witness".to_string()
    } else if !acs_anchor_lookup_pass {
        "restore_acs_anchor_lookup_witness".to_string()
    } else if !uas_acs_mmap_residency_pass {
        "land_uas_acs_mmap_residency_witness".to_string()
    } else if !page_gather_packetized_floor_pass {
        "restore_page_gather_packetized_floor".to_string()
    } else if !page_gather_dense_primary_pass && !page_gather_packetized_caller_pass {
        "wire_page_gather_packetized_caller_or_fix_dense_restore".to_string()
    } else if !page_gather_dense_primary_pass && !page_gather_packetized_policy_acceptance_pass {
        "accept_page_gather_packetized_policy_or_fix_dense_restore".to_string()
    } else if !kv_direct_live_128k_pass && heavy_long_context_enabled {
        if kv_direct_live_contract_present {
            if !kv_direct_model_assets_available {
                "resolve_qwen3_8b_mlx_model_assets_for_kv_direct".to_string()
            } else if !kv_direct_model_identity_matches_canonical {
                "resolve_canonical_qwen3_8b_model_identity_for_kv_direct".to_string()
            } else if !kv_direct_model_context_supports_required_context {
                "resolve_qwen3_8b_128k_context_model_assets_for_kv_direct".to_string()
            } else if !kv_direct_prompt_suite_manifest_available
                || !kv_direct_prompt_suite_shape_pass
            {
                "generate_qwen3_8b_100_prompt_128k_kv_direct_suite".to_string()
            } else if !kv_direct_full_suite_run_plan_available {
                "create_qwen3_8b_100_prompt_128k_shard_run_plan".to_string()
            } else if !kv_direct_logits_available {
                "run_qwen3_8b_100_prompt_128k_reference_and_kv_direct_logits".to_string()
            } else if !kv_direct_live_metrics_available {
                "record_qwen3_8b_128k_kv_direct_rss_toks_wallclock_metrics".to_string()
            } else if !kv_direct_spill_trace_available {
                "record_qwen3_8b_128k_kv_direct_ssd_spill_trace".to_string()
            } else if !kv_direct_spill_trace_contract_pass {
                "record_qwen3_8b_128k_residual_mmap_nf4_spill_trace".to_string()
            } else if !kv_direct_live_shape_floor_pass {
                "expand_kv_direct_fixture_to_100_prompts_128k_context_256_decode_tokens".to_string()
            } else {
                "debug_kv_direct_live_128k_threshold_failures".to_string()
            }
        } else {
            "build_live_qwen3_8b_128k_kv_direct_harness".to_string()
        }
    } else if !agent_local_model_runtime_bridge_pass {
        agent_local_model_runtime_bridge_next_bottleneck.to_string()
    } else if !active_assembly_runtime_artifact_pass {
        "promote_active_assembly_from_shape_proof_to_runtime_artifact".to_string()
    } else if !sparse_runtime_split_artifact_pass {
        "add_sparse_runtime_split_artifact".to_string()
    } else if !heavy_long_context_enabled {
        if !residency_construction_graph_pass {
            "build_residency_construction_graph_dry_run".to_string()
        } else if !coactivation_tile_prefetch_pass {
            "coactivation_tile_prefetch".to_string()
        } else if !proof_carrying_residency_lease_pass {
            "proof_carrying_residency_lease".to_string()
        } else if !cold_assembly_plan_70b_lite_pass {
            "cold_assembly_plan_70b_lite".to_string()
        } else if !lattice_state_controller_pass {
            "lattice_state_controller".to_string()
        } else if !reasoning_state_continuity_pass {
            "reasoning_state_continuity".to_string()
        } else if !cold_miss_ledger_pass {
            "cold_miss_ledger".to_string()
        } else if !swiftlm_source_intake_pass {
            "swiftlm_source_intake".to_string()
        } else if !meta_breakthrough_card_registry_pass {
            "meta_breakthrough_card_registry".to_string()
        } else if !proof_carrying_route_card_pass {
            "proof_carrying_route_card".to_string()
        } else if !rust_route_kernel_model_check_pass {
            "rust_route_kernel_model_check".to_string()
        } else if !brain_route_card_multi_model_pass {
            "brain_route_card_multi_model".to_string()
        } else if !kv_page_control_query_aware_pass {
            "kv_page_control_query_aware".to_string()
        } else if !neural_control_card_ablation_pass {
            "neural_control_card_ablation".to_string()
        } else if !verifier_regret_ledger_pass {
            "verifier_regret_ledger".to_string()
        } else if !route_scout_ssm_baseline_pass {
            "route_scout_ssm_baseline".to_string()
        } else if !seventy_b_route_pass {
            "two_stage_route_scout_abstain".to_string()
        } else {
            "ready_for_product_route_review".to_string()
        }
    } else if !seventy_b_route_pass {
        cocktail
            .measurement_string("primary_bottleneck")
            .unwrap_or_else(|| "run_70b_local_cocktail_with_real_inputs".to_string())
    } else {
        "ready_for_product_route_review".to_string()
    }
}

#[allow(clippy::too_many_arguments)]
fn build_ordered_gap_queue(
    all_gate_artifacts_schema_normalized: bool,
    verified_floor_green: bool,
    uas_copy_count_hot_path_pass: bool,
    acs_anchor_lookup_pass: bool,
    uas_acs_mmap_residency_pass: bool,
    page_gather_packetized_floor_pass: bool,
    page_gather_dense_primary_pass: bool,
    page_gather_packetized_caller_pass: bool,
    page_gather_packetized_policy_acceptance_pass: bool,
    kv_direct_live_contract_present: bool,
    kv_direct_model_assets_available: bool,
    kv_direct_model_identity_matches_canonical: bool,
    kv_direct_model_context_supports_required_context: bool,
    kv_direct_prompt_suite_manifest_available: bool,
    kv_direct_prompt_suite_shape_pass: bool,
    kv_direct_full_suite_run_plan_available: bool,
    kv_direct_logits_available: bool,
    kv_direct_live_metrics_available: bool,
    kv_direct_spill_trace_available: bool,
    kv_direct_spill_trace_contract_pass: bool,
    kv_direct_live_shape_floor_pass: bool,
    kv_direct_live_128k_pass: bool,
    heavy_long_context_enabled: bool,
    agent_local_model_runtime_bridge_pass: bool,
    agent_local_model_runtime_bridge_next_bottleneck: &str,
    active_assembly_runtime_artifact_pass: bool,
    sparse_runtime_split_artifact_pass: bool,
    residency_construction_graph_pass: bool,
    coactivation_tile_prefetch_pass: bool,
    proof_carrying_residency_lease_pass: bool,
    cold_assembly_plan_70b_lite_pass: bool,
    lattice_state_controller_pass: bool,
    reasoning_state_continuity_pass: bool,
    cold_miss_ledger_pass: bool,
    swiftlm_source_intake_pass: bool,
    meta_breakthrough_card_registry_pass: bool,
    proof_carrying_route_card_pass: bool,
    rust_route_kernel_model_check_pass: bool,
    brain_route_card_multi_model_pass: bool,
    kv_page_control_query_aware_pass: bool,
    neural_control_card_ablation_pass: bool,
    verifier_regret_ledger_pass: bool,
    route_scout_ssm_baseline_pass: bool,
    seventy_b_route_pass: bool,
    cocktail_primary_bottleneck: &str,
) -> Vec<serde_json::Value> {
    vec![
        queue_item(
            0,
            "mas_current_app_guard",
            "MAS / CurrentApp",
            "completed",
            "MODEL_GATING_MATRIX + Capability Ceiling Model Gate",
            "docs/audits/CAPABILITY_CEILING_MODEL_GATE_2026_05_27.md",
            "Dense 36B remains 32 GB + explicit opt-in; 70B remains Vault/Research-only until artifact gates pass.",
            "Keep product route on practical local MLX and cloud/provider lanes; never lower dense RAM gate from research artifacts.",
        ),
        queue_item(
            1,
            "schema_normalized_artifact_floor",
            "Verified Floor",
            status(all_gate_artifacts_schema_normalized),
            "F-UAS-CopyCount + F-ACS-AnchorLookup + F-UAS-ACS-MmapResidency + route source artifacts",
            "artifacts/falsifiers/*/result.json",
            "All gate artifacts consumed by the route kernel use the shared schema shape.",
            "Do not promote routes from legacy PASS keys; normalize artifact shape first.",
        ),
        queue_item(
            2,
            "verified_floor_primary_metal",
            "Verified Floor",
            status(verified_floor_green),
            "F-ULP-Oracle + F-ControllerKernelPack",
            "artifacts/falsifiers/ulp_oracle/result.json; artifacts/falsifiers/controller_kernel_pack/result.json",
            "Metal ULP and controller-kernel primary witnesses remain green on M2 Pro floor.",
            "Keep CPU/fallback witnesses separate from Metal primary claims.",
        ),
        queue_item(
            3,
            "uas_acs_hot_path_floor",
            "Verified Floor",
            status(
                uas_copy_count_hot_path_pass
                    && acs_anchor_lookup_pass
                    && uas_acs_mmap_residency_pass,
            ),
            "F-UAS-CopyCount + F-ACS-AnchorLookup + F-UAS-ACS-MmapResidency",
            "artifacts/falsifiers/uas_copy_count/result.json; artifacts/falsifiers/acs_anchor_lookup/result.json; artifacts/falsifiers/uas_acs_mmap_residency/result.json",
            "UAS copy-count, ACS anchor lookup, and file-backed mmap residency pass as schema-normalized witnesses.",
            "Keep full production generation/KV residual-spill copy-count as a separate future measurement if not yet covered.",
        ),
        queue_item(
            4,
            "pagegather_packetized_floor_and_caller",
            "Capability Ceiling",
            status(page_gather_packetized_floor_pass && page_gather_packetized_caller_pass),
            "F-PageGather-M2Pro + F-PageGather-Packetized-Caller",
            "artifacts/falsifiers/page_gather/locality_probe_result.json; artifacts/falsifiers/page_gather_packetized_caller/result.json",
            "Packetized PageGather clears mitigation floor and one caller path consumes packets before dense restore.",
            "Dense restore remains non-primary; do not claim dense PageGather green from packet mitigation alone.",
        ),
        queue_item(
            5,
            "pagegather_dense_primary_or_policy_acceptance",
            "Capability Ceiling",
            status(page_gather_dense_primary_pass || page_gather_packetized_policy_acceptance_pass),
            "F-PageGather-M2Pro + F-PageGather-Packetized-Policy-Acceptance",
            "artifacts/falsifiers/page_gather/locality_probe_result.json; artifacts/falsifiers/page_gather_packetized_policy_acceptance/result.json",
            "Either dense primary PageGather clears the STREAM bar or canon explicitly accepts a packetized policy for the relevant product route.",
            "Use packetized caller path as fallback; keep dense scatter off hot product claims until measured.",
        ),
        queue_item(
            6,
            "kv_direct_live_128k_inputs",
            "Capability Ceiling",
            kv_direct_queue_status(
                kv_direct_live_128k_pass,
                kv_direct_live_contract_present,
                kv_direct_model_assets_available,
                kv_direct_model_identity_matches_canonical,
                kv_direct_model_context_supports_required_context,
                kv_direct_prompt_suite_manifest_available,
                kv_direct_prompt_suite_shape_pass,
                kv_direct_full_suite_run_plan_available,
                kv_direct_logits_available,
                kv_direct_live_metrics_available,
            kv_direct_spill_trace_available,
            kv_direct_spill_trace_contract_pass,
            kv_direct_live_shape_floor_pass,
            heavy_long_context_enabled,
        ),
        "F-KV-Direct-Gate",
        "artifacts/falsifiers/kv_direct_gate/result.json",
        if heavy_long_context_enabled {
            "Set or auto-detect the canonical Qwen/Qwen3-8B-MLX-4bit asset, require its config to honestly support >=128K context, generate the canonical 100-prompt 128K suite manifest, write the restartable full-suite shard plan, then provide paired reference/test logits, >=128K context metrics, >=256 decode tokens per prompt, RSS/tok/s/wall-clock metrics, and SSD-spill trace; all axes pass."
        } else {
            "Deferred by default; only revisit the 128K KV-Direct route with EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1 and an explicit research/probe task."
        },
        "Keep QK equality as preflight only; no 128K local context product claim without live prompt metrics or explicit heavy opt-in.",
    ),
        queue_item(
            7,
            "agent_local_model_runtime_bridge",
            "Pro / Agent Runtime",
            if agent_local_model_runtime_bridge_pass {
                "completed"
            } else {
                agent_local_model_runtime_bridge_next_bottleneck
            },
            "F-Agent-Local-Model-Runtime-Bridge",
            "artifacts/falsifiers/agent_local_model_runtime_bridge/result.json",
            "System G routes ProviderPolicy::LocalMlx through live MLX/GGUF generation, streams local-model events, and emits AnswerPackets with model provenance; provider-aware fail-closed routing alone is not enough.",
            "Keep AgentRuntimeV2 provider dispatch fail-closed/scaffold-labeled until live local generation and provenance pass; do not claim frontier-replacement local agents from catalog metadata alone.",
        ),
        queue_item(
            8,
            "active_assembly_runtime_floor",
            "Capability Ceiling",
            status(active_assembly_runtime_artifact_pass),
            "F-ActiveAssembly-Minimal",
            "artifacts/falsifiers/active_assembly_minimal/result.json",
            "Synthetic runtime witness proves small active support with bounded output drift.",
            "Treat live model packet routing as a later promotion, not implied by the synthetic fixture.",
        ),
        queue_item(
            9,
            "sparse_runtime_split_floor",
            "Capability Ceiling",
            status(sparse_runtime_split_artifact_pass),
            "F-Sparse-Runtime-Split",
            "artifacts/falsifiers/sparse_runtime_split/result.json",
            "Synthetic sparse/reference split passes bounded KL, active ratio, cost ratio, and chart labels.",
            "Keep live sparse 70B runtime and live chart coverage red until model-backed rows exist.",
        ),
        queue_item(
            10,
            "live_sparse_70b_runtime_and_chart_coverage",
            "Vault / Capability Ceiling",
            if seventy_b_route_pass {
                "completed"
            } else if !heavy_long_context_enabled {
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED
            } else {
                "pending_live_model_runtime"
            },
            "F-70B-Local-Cocktail-Lite",
            "artifacts/falsifiers/70b_local_cocktail_lite/result.json",
            if heavy_long_context_enabled {
                "Provide local 70B weights, provider/fp16 reference, live sparse runtime trace, and live chart rows for weights/layers/KV/kernels."
            } else {
                "Deferred under the active MLX route; do not require GGUF/provider-reference setup unless explicitly re-enabled for research."
            },
            "Keep 70B route Vault/Research-only; practical MLX routes must not impersonate ACS/UAS.",
        ),
        queue_item(
            11,
            "seventy_b_prompt_level_cocktail",
            "Vault / Beyond",
            if seventy_b_route_pass {
                "completed"
            } else if !heavy_long_context_enabled {
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED
            } else {
                cocktail_primary_bottleneck
            },
            "F-70B-Local-Cocktail-Lite",
            "artifacts/falsifiers/70b_local_cocktail_lite/result.json",
            if heavy_long_context_enabled {
                "Prompt-level D_KL, TTFT, tok/s, RSS, cache state, bottleneck attribution, and rollback all pass."
            } else {
                "No active provider-reference prompt-level work is required for the MLX route."
            },
            "Route active local inference through MLX; do not expose 70B as product.",
        ),
        queue_item(
            12,
            "research_construction_engine",
            "Research Construction",
            if residency_construction_graph_pass {
                "completed"
            } else if !heavy_long_context_enabled && !seventy_b_route_pass {
                "next_active_architecture_cursor"
            } else {
                "planned_after_measured_runtime_gates"
            },
            "F-ResidencyConstructionGraph",
            "artifacts/falsifiers/residency_construction_graph/result.json",
            "Problem/task signatures become source-card-backed ResidencyConstructionGraphs with deterministic assembly scores, verifier/cold-miss evidence, rollback, and zero runtime/model-byte loads.",
            "Keep candidate laws and public-research motifs candidate-only until local falsifiers pass.",
        ),
        queue_item(
            13,
            "coactivation_tile_prefetch",
            "Research Construction",
            if coactivation_tile_prefetch_pass {
                "completed"
            } else if residency_construction_graph_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_research_construction_graph"
            },
            "F-CoactivationTile-Prefetch",
            "docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md",
            "Tile packing and prefetch beat original file order or random fetch on cold misses, stall time, and byte waste.",
            "Keep cold layout/prefetch as shadow planner evidence until held-out cold-miss and stall reductions pass.",
        ),
        queue_item(
            14,
            "proof_carrying_residency_lease",
            "Research Construction",
            if proof_carrying_residency_lease_pass {
                "completed"
            } else if coactivation_tile_prefetch_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_coactivation_tile_prefetch"
            },
            "F-ProofCarryingResidencyLease",
            "docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md",
            "Residency leases carry verifier, rollback, abstention, and budget evidence before any live cold assembly can claim promotion.",
            "Treat any lease without proof packet evidence as research-only and fail closed.",
        ),
        queue_item(
            15,
            "cold_assembly_plan_70b_lite",
            "Research Construction",
            if cold_assembly_plan_70b_lite_pass {
                "completed"
            } else if proof_carrying_residency_lease_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_proof_carrying_residency_lease"
            },
            "F-ColdAssemblyPlan-70B-Lite",
            "docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md",
            "A small-hot plus cold-selected plan beats dense-local, RAG-only, and static-route baselines without hidden cloud or dense-resident overclaim.",
            "Keep cold assembly research-only until baseline comparisons, route witness, rollback, and no-hidden-cloud evidence pass.",
        ),
        queue_item(
            16,
            "lattice_state_controller",
            "Research Construction",
            if lattice_state_controller_pass {
                "completed"
            } else if cold_assembly_plan_70b_lite_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_cold_assembly_plan_70b_lite"
            },
            "F-LatticeStateController",
            "docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md",
            "Bound the lattice controller that admits, abstains, or rolls back proof-carrying cold assemblies before live route authority.",
            "No PatternBoost or cold assembly may become hidden live route authority without controller-state witness evidence.",
        ),
        queue_item(
            17,
            "reasoning_state_continuity",
            "Research Construction",
            if reasoning_state_continuity_pass {
                "completed"
            } else if lattice_state_controller_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_lattice_state_controller"
            },
            "F-ReasoningStateContinuity",
            "docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md",
            "Preserved cache, summary, route, and verifier state must improve continuity without exposing hidden reasoning or bypassing AnswerPacket verification.",
            "Resumable reasoning state stays witness-only until hidden-chain leakage, stale-state reuse, verifier bypass, and rollback failures are rejected.",
        ),
        queue_item(
            18,
            "cold_miss_ledger",
            "Research Construction",
            if cold_miss_ledger_pass {
                "completed"
            } else if reasoning_state_continuity_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_reasoning_state_continuity"
            },
            "F-ColdMissLedger",
            "docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md",
            "Cold-miss traces must update later prefetch and route policy while proving held-out repeated-stall reduction.",
            "Cold-miss learning stays shadow-policy only until storage-wear, rollback, held-out improvement, and AnswerPacket visibility pass.",
        ),
        queue_item(
            19,
            "swiftlm_source_intake",
            "Research Construction",
            if swiftlm_source_intake_pass {
                "completed"
            } else if cold_miss_ledger_pass && !heavy_long_context_enabled && !seventy_b_route_pass {
                "next_active_architecture_cursor"
            } else {
                "planned_after_cold_miss_ledger"
            },
            "F-SwiftLM-SourceIntake",
            "docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md",
            "SwiftLM SSD-streaming and KV-compression motifs must be captured as source cards, license/setup notes, benchmark caveats, and local test plans before any implementation import.",
            "SwiftLM is source-mining discipline, not a product dependency or code import path.",
        ),
        queue_item(
            20,
            "meta_breakthrough_card_registry",
            "Meta Control",
            if meta_breakthrough_card_registry_pass {
                "completed"
            } else if swiftlm_source_intake_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_swiftlm_source_intake"
            },
            "F-MetaBreakthrough-CardRegistry",
            "docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md",
            "Every meta-control card must bind UAS address, source, budget, rollback, proof/falsifier state, and AnswerPacket visibility before controlling route policy.",
            "Meta-control cards remain research-only until source, budget, rollback, proof, and AnswerPacket visibility are witnessed.",
        ),
        queue_item(
            21,
            "proof_carrying_route_card",
            "Meta Control",
            if proof_carrying_route_card_pass {
                "completed"
            } else if meta_breakthrough_card_registry_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_meta_breakthrough_card_registry"
            },
            "F-ProofCarryingRouteCard",
            "docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md",
            "Proof-carrying route cards must reject missing preconditions, rollback, artifact refs, or unpinned proof/toolchain versions before route execution can cite them.",
            "Route cards remain schema/proof witnesses until rollback, artifact refs, pinned proof/toolchain identity, and AnswerPacket visibility are verified.",
        ),
        queue_item(
            22,
            "rust_route_kernel_model_check",
            "Meta Control",
            if rust_route_kernel_model_check_pass {
                "completed"
            } else if proof_carrying_route_card_pass && !heavy_long_context_enabled && !seventy_b_route_pass {
                "next_active_architecture_cursor"
            } else {
                "planned_after_proof_carrying_route_card"
            },
            "F-RustRouteKernel-ModelCheck",
            "artifacts/falsifiers/rust_route_kernel_model_check/result.json",
            "Bounded route-state and unsafe/FFI invariants must model-check before proof-carrying routes can approach live execution.",
            "Keep route execution shadow-only until model-check evidence, rollback, pinned toolchain identity, and AnswerPacket visibility are verified.",
        ),
        queue_item(
            23,
            "brain_route_card_multi_model",
            "Meta Control",
            if brain_route_card_multi_model_pass {
                "completed"
            } else if rust_route_kernel_model_check_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_rust_route_kernel_model_check"
            },
            "F-BrainRouteCard-MultiModel",
            "docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md",
            "Learned or task-shaped BrainRouteCard routing must beat static route policy on quality, evidence, latency, active bytes, and verifier outcomes without hidden multi-model route authority.",
            "Keep BrainRouteCard route priors shadow-only until AnswerPacket-visible evidence, rollback, held-out wins, and route-kernel compatibility pass.",
        ),
        queue_item(
            24,
            "kv_page_control_query_aware",
            "Meta Control",
            if kv_page_control_query_aware_pass {
                "completed"
            } else if brain_route_card_multi_model_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_brain_route_card_multi_model"
            },
            "F-KVPageControl-QueryAware",
            "docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md",
            "Query-aware KV/page control must beat recency-only and random selection under active-byte, quality, verifier, and AnswerPacket visibility budgets.",
            "Keep KV/page control shadow-only until stale/incompatible units, budget overflow, missing rollback, and verifier bypass cases reject.",
        ),
        queue_item(
            25,
            "neural_control_card_ablation",
            "Meta Control",
            if neural_control_card_ablation_pass {
                "completed"
            } else if kv_page_control_query_aware_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_kv_page_control_query_aware"
            },
            "F-NeuralControlCard-Ablation",
            "docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md",
            "Bounded neural/feature control cards must improve target behavior versus baseline and ablation without unacceptable side effects, hidden route authority, or live mutation.",
            "Keep neural control cards shadow-only until baseline, intervention, ablation, rollback, RunEventLog, and AnswerPacket evidence pass.",
        ),
        queue_item(
            26,
            "verifier_regret_ledger",
            "Meta Control",
            if verifier_regret_ledger_pass {
                "completed"
            } else if neural_control_card_ablation_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_neural_control_card_ablation"
            },
            "F-VerifierRegretLedger",
            "docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md",
            "Verifier regret updates must change later route selection and reduce regret over held-out prompt/task sets without hidden route authority.",
            "Keep regret updates shadow-only until held-out regret reduction, rollback, RunEventLog, and AnswerPacket evidence pass.",
        ),
        queue_item(
            27,
            "route_scout_ssm_baseline",
            "Meta Control",
            if route_scout_ssm_baseline_pass {
                "completed"
            } else if verifier_regret_ledger_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_verifier_regret_ledger"
            },
            "F-RouteScoutSSM-Baseline",
            "docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md",
            "A tiny route scout must predict route family and verifier need better than static, random, recency, and embedding-only baselines before sparse wake routing can advance.",
            "Keep scout predictions shadow-only until held-out baselines, abstention, rollback, and AnswerPacket-visible proof pass.",
        ),
        queue_item(
            28,
            "two_stage_route_scout_abstain",
            "Meta Control",
            if route_scout_ssm_baseline_pass && !heavy_long_context_enabled && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_route_scout_ssm_baseline"
            },
            "F-TwoStageRouteScout-Abstain",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Stage A route-family choice and Stage B selector choice must be separate, cheap, and abstention-capable before sparse wake proposals can advance.",
            "Keep the two-stage scout shadow-only until family/selector separation, abstention, rollback, and AnswerPacket proof pass.",
        ),
    ]
}

fn queue_item(
    order: u64,
    gap_id: &str,
    tier: &str,
    status: &str,
    falsifier_or_gate: &str,
    witness: &str,
    promotion_condition: &str,
    rollback: &str,
) -> serde_json::Value {
    serde_json::json!({
        "order": order,
        "gap_id": gap_id,
        "tier": tier,
        "status": status,
        "falsifier_or_gate": falsifier_or_gate,
        "witness": witness,
        "promotion_condition": promotion_condition,
        "rollback": rollback,
    })
}

fn status(done: bool) -> &'static str {
    if done {
        "completed"
    } else {
        "pending"
    }
}

fn kv_direct_queue_status(
    pass: bool,
    contract_present: bool,
    model_assets_available: bool,
    model_identity_matches_canonical: bool,
    model_context_supports_required_context: bool,
    prompt_suite_manifest_available: bool,
    prompt_suite_shape_pass: bool,
    full_suite_run_plan_available: bool,
    logits_available: bool,
    live_metrics_available: bool,
    spill_trace_available: bool,
    spill_trace_contract_pass: bool,
    shape_floor_pass: bool,
    heavy_long_context_enabled: bool,
) -> &'static str {
    if pass {
        "completed"
    } else if !heavy_long_context_enabled {
        "deferred_heavy_long_context_opt_in"
    } else if !contract_present {
        "pending_contract"
    } else if !model_assets_available {
        "pending_model_assets"
    } else if !model_identity_matches_canonical {
        "pending_canonical_model_identity"
    } else if !model_context_supports_required_context {
        "pending_128k_context_model"
    } else if !prompt_suite_manifest_available {
        "pending_prompt_suite_manifest"
    } else if !prompt_suite_shape_pass {
        "pending_prompt_suite_shape"
    } else if !full_suite_run_plan_available {
        "pending_full_suite_run_plan"
    } else if !logits_available {
        "pending_100_prompt_128k_logits"
    } else if !live_metrics_available {
        "pending_live_metrics"
    } else if !spill_trace_available {
        "pending_spill_trace"
    } else if !spill_trace_contract_pass {
        "pending_residual_mmap_nf4_spill_trace"
    } else if !shape_floor_pass {
        "pending_fixture_shape_floor"
    } else {
        "pending_threshold_debug"
    }
}

fn count_unmapped_gaps(queue: &[serde_json::Value]) -> u64 {
    queue
        .iter()
        .filter(|item| {
            item.get("gap_id").and_then(|v| v.as_str()).is_none()
                || item
                    .get("promotion_condition")
                    .and_then(|v| v.as_str())
                    .map(str::is_empty)
                    .unwrap_or(true)
                || item
                    .get("rollback")
                    .and_then(|v| v.as_str())
                    .map(str::is_empty)
                    .unwrap_or(true)
        })
        .count() as u64
}

fn build_anomalies(
    all_gate_artifacts_schema_normalized: bool,
    uas_acs_mmap_residency_pass: bool,
    page_gather_dense_primary_pass: bool,
    page_gather_packetized_caller_pass: bool,
    page_gather_packetized_policy_acceptance_pass: bool,
    kv_direct_model_identity_matches_canonical: bool,
    kv_direct_model_context_supports_required_context: bool,
    kv_direct_live_128k_pass: bool,
    heavy_long_context_enabled: bool,
    agent_local_model_runtime_bridge_pass: bool,
    active_assembly_runtime_artifact_pass: bool,
    sparse_runtime_split_artifact_pass: bool,
    residency_construction_graph_pass: bool,
    coactivation_tile_prefetch_pass: bool,
    proof_carrying_residency_lease_pass: bool,
    cold_assembly_plan_70b_lite_pass: bool,
    lattice_state_controller_pass: bool,
    reasoning_state_continuity_pass: bool,
    cold_miss_ledger_pass: bool,
    swiftlm_source_intake_pass: bool,
    meta_breakthrough_card_registry_pass: bool,
    proof_carrying_route_card_pass: bool,
    rust_route_kernel_model_check_pass: bool,
    brain_route_card_multi_model_pass: bool,
    kv_page_control_query_aware_pass: bool,
    neural_control_card_ablation_pass: bool,
    verifier_regret_ledger_pass: bool,
    route_scout_ssm_baseline_pass: bool,
    seventy_b_route_pass: bool,
    next_bottleneck: &str,
) -> Vec<serde_json::Value> {
    let mut anomalies = Vec::new();
    if !all_gate_artifacts_schema_normalized {
        anomalies.push(serde_json::json!({
            "kind": "legacy_artifact_shape",
            "detail": "F-UAS-CopyCount and F-ACS-AnchorLookup still use legacy artifact keys; preserve pass meaning but normalize before route promotion."
        }));
    }
    if !uas_acs_mmap_residency_pass {
        anomalies.push(serde_json::json!({
            "kind": "uas_acs_mmap_residency_red",
            "detail": "No primary witness proves file-backed mmap bytes can be addressed by UAS, leased by ResidencyLease, and resolved through ACS projection lookup without tracked hot-path copies."
        }));
    }
    if !page_gather_dense_primary_pass && !page_gather_packetized_policy_acceptance_pass {
        anomalies.push(serde_json::json!({
            "kind": "page_gather_dense_route_red",
            "detail": "PageGather packetized scheduled output clears the 0.70x mitigation floor, but dense restore remains below the primary stream-ratio gate and no policy artifact has accepted the packetized route."
        }));
    } else if !page_gather_dense_primary_pass {
        anomalies.push(serde_json::json!({
            "kind": "page_gather_dense_primary_deferred_by_policy",
            "detail": "Dense PageGather remains below the primary stream-ratio gate; the packetized policy artifact accepts only retrieval/witness packet surfaces and does not promote dense restore."
        }));
    }
    if !page_gather_packetized_caller_pass {
        anomalies.push(serde_json::json!({
            "kind": "page_gather_packetized_caller_missing",
            "detail": "No schema-valid caller-path artifact proves a retrieval or witness surface consumes PageGather packets before dense restore."
        }));
    }
    if !kv_direct_live_128k_pass && heavy_long_context_enabled {
        anomalies.push(serde_json::json!({
            "kind": "kv_direct_live_gate_red",
            "detail": "KV-Direct Rust equality passes, but the Qwen3-8B 128K SSD-spill D_KL/RSS/tok/s gate is still sentinel red."
        }));
    } else if !kv_direct_live_128k_pass {
        anomalies.push(serde_json::json!({
            "kind": "kv_direct_128k_route_deferred_by_default",
            "detail": "The Qwen/GGUF 128K KV-Direct lane remains red research evidence, but it is not the active architecture cursor unless EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1 is set."
        }));
    }
    if !kv_direct_model_identity_matches_canonical && heavy_long_context_enabled {
        anomalies.push(serde_json::json!({
            "kind": "kv_direct_model_identity_red",
            "detail": "The resolved KV-Direct model asset is not the canonical Qwen/Qwen3-8B-MLX-4bit target. Alternate long-context models stay candidate-tier unless canon changes."
        }));
    }
    if !kv_direct_model_context_supports_required_context && heavy_long_context_enabled {
        anomalies.push(serde_json::json!({
            "kind": "kv_direct_model_context_red",
            "detail": "The resolved KV-Direct model asset does not currently prove a >=128K context window, so the 128K live run is blocked before logits."
        }));
    }
    if !agent_local_model_runtime_bridge_pass {
        anomalies.push(serde_json::json!({
            "kind": "agent_local_model_runtime_bridge_red",
            "detail": "The model catalog, local runtime clients, LocalAgent dispatch plan, and System G fail-closed LocalMlx route exist, but AgentRuntimeV2/System G does not yet dispatch ProviderPolicy::LocalMlx to live local generation with AnswerPacket provenance."
        }));
    }
    if !active_assembly_runtime_artifact_pass {
        anomalies.push(serde_json::json!({
            "kind": "active_assembly_runtime_artifact_missing",
            "detail": "The selector has a shape proof/test file, but no schema-valid runtime falsifier artifact proving small support with bounded behavior drift."
        }));
    }
    if !sparse_runtime_split_artifact_pass {
        anomalies.push(serde_json::json!({
            "kind": "sparse_runtime_split_artifact_missing",
            "detail": "No schema-valid F-Sparse-Runtime-Split artifact proves selected sparse execution reproduces dense/reference logits within bounded drift."
        }));
    }
    if !residency_construction_graph_pass && !heavy_long_context_enabled {
        anomalies.push(serde_json::json!({
            "kind": "residency_construction_graph_missing",
            "detail": "The active Research Construction cursor needs F-ResidencyConstructionGraph before coactivation tile prefetch or proof-carrying lease work can advance."
        }));
    }
    if residency_construction_graph_pass
        && !coactivation_tile_prefetch_pass
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "coactivation_tile_prefetch_missing",
            "detail": "Research Construction has a scored graph, but F-CoactivationTile-Prefetch must pass before proof-carrying residency leases can advance."
        }));
    }
    if coactivation_tile_prefetch_pass
        && !proof_carrying_residency_lease_pass
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "proof_carrying_residency_lease_missing",
            "detail": "Research Construction has coactivation tiles, but F-ProofCarryingResidencyLease must pass before any cold assembly plan can advance."
        }));
    }
    if proof_carrying_residency_lease_pass
        && !cold_assembly_plan_70b_lite_pass
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "cold_assembly_plan_70b_lite_missing",
            "detail": "Research Construction has proof-carrying leases, but F-ColdAssemblyPlan-70B-Lite must pass before LatticeStateController work can advance."
        }));
    }
    if cold_assembly_plan_70b_lite_pass
        && !lattice_state_controller_pass
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "lattice_state_controller_missing",
            "detail": "Research Construction has a cold 70B assembly plan, but F-LatticeStateController must pass before resumable reasoning-state work can advance."
        }));
    }
    if lattice_state_controller_pass
        && !reasoning_state_continuity_pass
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "reasoning_state_continuity_missing",
            "detail": "Research Construction has a lattice route controller, but F-ReasoningStateContinuity must pass before cold-miss learning can advance."
        }));
    }
    if reasoning_state_continuity_pass && !cold_miss_ledger_pass && !heavy_long_context_enabled {
        anomalies.push(serde_json::json!({
            "kind": "cold_miss_ledger_missing",
            "detail": "Research Construction has continuity state, but F-ColdMissLedger must pass before SwiftLM source-intake work can advance."
        }));
    }
    if cold_miss_ledger_pass && !swiftlm_source_intake_pass && !heavy_long_context_enabled {
        anomalies.push(serde_json::json!({
            "kind": "swiftlm_source_intake_missing",
            "detail": "Research Construction has cold-miss learning, but F-SwiftLM-SourceIntake must pass before meta-breakthrough card registry work can advance."
        }));
    }
    if swiftlm_source_intake_pass
        && !meta_breakthrough_card_registry_pass
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "meta_breakthrough_card_registry_missing",
            "detail": "Research Construction has SwiftLM source intake, but F-MetaBreakthrough-CardRegistry must pass before proof-carrying route-card work can advance."
        }));
    }
    if meta_breakthrough_card_registry_pass
        && !proof_carrying_route_card_pass
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "proof_carrying_route_card_missing",
            "detail": "Meta Control has a card registry, but F-ProofCarryingRouteCard must pass before Rust route-kernel model-check work can advance."
        }));
    }
    if proof_carrying_route_card_pass
        && !rust_route_kernel_model_check_pass
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "rust_route_kernel_model_check_missing",
            "detail": "Meta Control has proof-carrying route cards, but F-RustRouteKernel-ModelCheck must pass before BrainRouteCard or route-policy work can advance."
        }));
    }
    if rust_route_kernel_model_check_pass
        && !brain_route_card_multi_model_pass
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "brain_route_card_multi_model_missing",
            "detail": "Meta Control has a bounded route-kernel model check, but F-BrainRouteCard-MultiModel must pass before query-aware KV/page control work can advance."
        }));
    }
    if brain_route_card_multi_model_pass
        && !kv_page_control_query_aware_pass
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "kv_page_control_query_aware_missing",
            "detail": "Meta Control has BrainRouteCard routing proof, but F-KVPageControl-QueryAware must pass before neural control-card work can advance."
        }));
    }
    if kv_page_control_query_aware_pass
        && !neural_control_card_ablation_pass
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "neural_control_card_ablation_missing",
            "detail": "Meta Control has query-aware KV/page proof, but F-NeuralControlCard-Ablation must pass before verifier-regret work can advance."
        }));
    }
    if neural_control_card_ablation_pass
        && !verifier_regret_ledger_pass
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "verifier_regret_ledger_missing",
            "detail": "Meta Control has NeuralControlCard ablation proof, but F-VerifierRegretLedger must pass before route utility updates can cite regret learning."
        }));
    }
    if verifier_regret_ledger_pass && !route_scout_ssm_baseline_pass && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "route_scout_ssm_baseline_missing",
            "detail": "Meta Control has verifier-regret evidence, but F-RouteScoutSSM-Baseline must prove cheap held-out route/verifier predictions before two-stage abstaining scout work can advance."
        }));
    }
    if route_scout_ssm_baseline_pass && !heavy_long_context_enabled && !seventy_b_route_pass {
        anomalies.push(serde_json::json!({
            "kind": "two_stage_route_scout_abstain_missing",
            "detail": "RouteScoutSSM baseline evidence is present; the next non-heavy architecture cursor must split route-family and selector decisions with explicit abstention before any sparse wake proposal can promote."
        }));
    }
    if !seventy_b_route_pass && !heavy_long_context_enabled {
        anomalies.push(serde_json::json!({
            "kind": "seventy_b_route_deferred_by_mlx_route",
            "detail": "70B/GGUF/provider-reference work is not an active requirement while the app is routed through practical MLX local inference."
        }));
    } else if !seventy_b_route_pass {
        anomalies.push(serde_json::json!({
            "kind": "seventy_b_route_red",
            "detail": "70B Local Cocktail Lite remains a failure report; dense MLX must not impersonate the ACS/UAS capability ceiling route."
        }));
    }
    anomalies.push(serde_json::json!({
        "kind": "next_bottleneck",
        "detail": next_bottleneck
    }));
    anomalies
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: bool,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Bool(value),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value);
}

fn add_count_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: u64,
    threshold: u64,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(value)),
            unit: "count".to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(threshold)),
            unit: "count".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value == threshold);
}

fn add_label(measurements: &mut BTreeMap<String, Measurement>, key: &str, value: &str) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "label".to_string(),
        },
    );
}

fn add_bool_measurement(measurements: &mut BTreeMap<String, Measurement>, key: &str, value: bool) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value: serde_json::Value::Bool(value),
            unit: "bool".to_string(),
        },
    );
}

fn add_gate_summary(
    measurements: &mut BTreeMap<String, Measurement>,
    key: &str,
    gate: &GateArtifact,
) {
    measurements.insert(
        format!("{key}_summary"),
        Measurement {
            value: serde_json::json!({
                "path": gate.path,
                "exists": gate.exists,
                "schema_normalized": gate.schema_normalized,
                "overall_pass": gate.overall_pass,
                "status_pass": gate.status_pass,
                "pass_axes_all_true": gate.pass_axes_all_true(),
                "fallback_tier": gate.fallback_tier,
            }),
            unit: "object".to_string(),
        },
    );
}

fn heavy_long_context_enabled() -> bool {
    std::env::var(HEAVY_LONG_CONTEXT_ENV)
        .ok()
        .is_some_and(|value| value == "1")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn route_classifier_requires_all_primary_gates_for_product() {
        const VERIFIED_FLOOR: usize = 0;
        const UAS_MMAP: usize = 1;
        const PAGE_PACKETIZED: usize = 2;
        const PAGE_DENSE: usize = 3;
        const PAGE_CALLER: usize = 4;
        const PAGE_POLICY: usize = 5;
        const KV_DIRECT: usize = 6;
        const AGENT_LOCAL: usize = 7;
        const ACTIVE_ASSEMBLY: usize = 8;
        const SPARSE_RUNTIME: usize = 9;
        const COACTIVATION: usize = 10;
        const RESIDENCY_LEASE: usize = 11;
        const COLD_ASSEMBLY: usize = 12;
        const LATTICE: usize = 13;
        const REASONING: usize = 14;
        const COLD_MISS: usize = 15;
        const SWIFTLM: usize = 16;
        const META_CARD: usize = 17;
        const PROOF_ROUTE: usize = 18;
        const RUST_MODEL_CHECK: usize = 19;
        const BRAIN_ROUTE: usize = 20;
        const KV_PAGE: usize = 21;
        const NEURAL_CONTROL: usize = 22;
        const VERIFIER_REGRET: usize = 23;
        const ROUTE_SCOUT: usize = 24;
        const SEVENTY_B: usize = 25;
        const SCHEMA: usize = 26;
        let classify = |true_indexes: &[usize]| -> String {
            let mut values = [false; 27];
            for index in true_indexes {
                values[*index] = true;
            }
            classify_route(
                values[0], values[1], values[2], values[3], values[4], values[5], values[6],
                values[7], values[8], values[9], values[10], values[11], values[12], values[13],
                values[14], values[15], values[16], values[17], values[18], values[19], values[20],
                values[21], values[22], values[23], values[24], values[25], values[26],
            )
        };
        assert_eq!(
            classify(&[
                VERIFIED_FLOOR,
                UAS_MMAP,
                PAGE_PACKETIZED,
                PAGE_DENSE,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_DIRECT,
                AGENT_LOCAL,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                COACTIVATION,
                RESIDENCY_LEASE,
                COLD_ASSEMBLY,
                LATTICE,
                REASONING,
                COLD_MISS,
                SWIFTLM,
                META_CARD,
                PROOF_ROUTE,
                RUST_MODEL_CHECK,
                BRAIN_ROUTE,
                KV_PAGE,
                NEURAL_CONTROL,
                VERIFIER_REGRET,
                ROUTE_SCOUT,
                SEVENTY_B,
                SCHEMA,
            ]),
            "ready_for_product_route"
        );
        assert_eq!(
            classify(&[VERIFIED_FLOOR, UAS_MMAP, PAGE_PACKETIZED]),
            "vault_research_route_with_packetized_mitigation"
        );
        assert_eq!(classify(&[VERIFIED_FLOOR, UAS_MMAP]), "verified_floor_only");
        assert_eq!(
            classify(&[
                VERIFIED_FLOOR,
                UAS_MMAP,
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_DIRECT,
                AGENT_LOCAL,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                COACTIVATION,
                RESIDENCY_LEASE,
                COLD_ASSEMBLY,
                LATTICE,
                REASONING,
                COLD_MISS,
                SWIFTLM,
                META_CARD,
                PROOF_ROUTE,
                RUST_MODEL_CHECK,
                BRAIN_ROUTE,
                KV_PAGE,
                NEURAL_CONTROL,
                VERIFIER_REGRET,
                ROUTE_SCOUT,
                SEVENTY_B,
                SCHEMA,
            ]),
            "ready_for_product_route"
        );
    }

    #[test]
    fn bottleneck_order_starts_with_normalization() {
        let missing = GateArtifact {
            path: "missing",
            exists: false,
            schema_normalized: false,
            status_pass: false,
            overall_pass: false,
            fallback_tier: None,
            value: None,
        };
        const SCHEMA: usize = 0;
        const UAS_COPY: usize = 1;
        const ACS_LOOKUP: usize = 2;
        const UAS_ACS_MMAP: usize = 3;
        const PAGE_PACKETIZED: usize = 4;
        const PAGE_CALLER: usize = 6;
        const PAGE_POLICY: usize = 7;
        const KV_CONTRACT: usize = 8;
        const MODEL_ASSETS: usize = 9;
        const MODEL_IDENTITY: usize = 10;
        const MODEL_CONTEXT: usize = 11;
        const PROMPT_MANIFEST: usize = 12;
        const PROMPT_SHAPE: usize = 13;
        const FULL_PLAN: usize = 14;
        const LOGITS: usize = 15;
        const METRICS: usize = 16;
        const SPILL_TRACE: usize = 17;
        const SPILL_CONTRACT: usize = 18;
        const SHAPE_FLOOR: usize = 19;
        const LIVE_128K: usize = 20;
        const AGENT_LOCAL_BRIDGE: usize = 21;
        const ACTIVE_ASSEMBLY: usize = 22;
        const SPARSE_RUNTIME: usize = 23;
        const RESIDENCY_CONSTRUCTION_GRAPH: usize = 24;
        const COACTIVATION_TILE_PREFETCH: usize = 25;
        const PROOF_CARRYING_RESIDENCY_LEASE: usize = 26;
        const COLD_ASSEMBLY_PLAN_70B_LITE: usize = 27;
        const LATTICE_STATE_CONTROLLER: usize = 28;
        const REASONING_STATE_CONTINUITY: usize = 29;
        const COLD_MISS_LEDGER: usize = 30;
        const SWIFTLM_SOURCE_INTAKE: usize = 31;
        const META_BREAKTHROUGH_CARD_REGISTRY: usize = 32;
        const PROOF_CARRYING_ROUTE_CARD: usize = 33;
        const RUST_ROUTE_KERNEL_MODEL_CHECK: usize = 34;
        const BRAIN_ROUTE_CARD_MULTI_MODEL: usize = 35;
        const KV_PAGE_CONTROL_QUERY_AWARE: usize = 36;
        const NEURAL_CONTROL_CARD_ABLATION: usize = 37;
        const VERIFIER_REGRET_LEDGER: usize = 38;
        const ROUTE_SCOUT_SSM_BASELINE: usize = 39;
        const SEVENTY_B: usize = 40;

        let with_floor = |true_indexes: &[usize]| -> Vec<usize> {
            let mut indexes = vec![SCHEMA, UAS_COPY, ACS_LOOKUP, UAS_ACS_MMAP];
            indexes.extend_from_slice(true_indexes);
            indexes
        };
        let flags = |true_indexes: &[usize]| -> [bool; 41] {
            let mut values = [false; 41];
            for index in true_indexes {
                values[*index] = true;
            }
            values
        };
        let nb_with_heavy = |values: [bool; 41], heavy_long_context_enabled: bool| -> String {
            next_bottleneck(
                values[0],
                values[1],
                values[2],
                values[3],
                values[4],
                values[5],
                values[6],
                values[7],
                values[8],
                values[9],
                values[10],
                values[11],
                values[12],
                values[13],
                values[14],
                values[15],
                values[16],
                values[17],
                values[18],
                values[19],
                values[20],
                heavy_long_context_enabled,
                values[21],
                "wire_local_agent_adapter_dispatch",
                values[22],
                values[23],
                values[24],
                values[25],
                values[26],
                values[27],
                values[28],
                values[29],
                values[30],
                values[31],
                values[32],
                values[33],
                values[34],
                values[35],
                values[36],
                values[37],
                values[38],
                values[39],
                values[40],
                &missing,
            )
        };
        let nb = |values: [bool; 41]| -> String { nb_with_heavy(values, false) };
        let nb_heavy = |values: [bool; 41]| -> String { nb_with_heavy(values, true) };
        assert_eq!(
            nb(flags(&[PAGE_PACKETIZED])),
            "normalize_legacy_uas_and_acs_artifacts"
        );
        assert_eq!(
            nb(flags(&[SCHEMA])),
            "restore_uas_copy_count_hot_path_witness"
        );
        assert_eq!(
            nb(flags(&[SCHEMA, UAS_COPY])),
            "restore_acs_anchor_lookup_witness"
        );
        assert_eq!(
            nb(flags(&[SCHEMA, UAS_COPY, ACS_LOOKUP])),
            "land_uas_acs_mmap_residency_witness"
        );
        assert_eq!(
            nb(flags(&with_floor(&[PAGE_PACKETIZED]))),
            "wire_page_gather_packetized_caller_or_fix_dense_restore"
        );
        assert_eq!(
            nb(flags(&with_floor(&[PAGE_PACKETIZED, PAGE_CALLER]))),
            "accept_page_gather_packetized_policy_or_fix_dense_restore"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY
            ]))),
            "wire_local_agent_adapter_dispatch"
        );
        assert_eq!(
            nb_heavy(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY
            ]))),
            "build_live_qwen3_8b_128k_kv_direct_harness"
        );
        assert_eq!(
            nb_heavy(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT
            ]))),
            "resolve_qwen3_8b_mlx_model_assets_for_kv_direct"
        );
        assert_eq!(
            nb_heavy(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
            ]))),
            "resolve_canonical_qwen3_8b_model_identity_for_kv_direct"
        );
        assert_eq!(
            nb_heavy(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
            ]))),
            "resolve_qwen3_8b_128k_context_model_assets_for_kv_direct"
        );
        assert_eq!(
            nb_heavy(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
            ]))),
            "generate_qwen3_8b_100_prompt_128k_kv_direct_suite"
        );
        assert_eq!(
            nb_heavy(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
            ]))),
            "create_qwen3_8b_100_prompt_128k_shard_run_plan"
        );
        assert_eq!(
            nb_heavy(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
            ]))),
            "run_qwen3_8b_100_prompt_128k_reference_and_kv_direct_logits"
        );
        assert_eq!(
            nb_heavy(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
            ]))),
            "record_qwen3_8b_128k_kv_direct_rss_toks_wallclock_metrics"
        );
        assert_eq!(
            nb_heavy(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
            ]))),
            "record_qwen3_8b_128k_kv_direct_ssd_spill_trace"
        );
        assert_eq!(
            nb_heavy(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
            ]))),
            "record_qwen3_8b_128k_residual_mmap_nf4_spill_trace"
        );
        assert_eq!(
            nb_heavy(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
            ]))),
            "expand_kv_direct_fixture_to_100_prompts_128k_context_256_decode_tokens"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                ACTIVE_ASSEMBLY,
            ]))),
            "wire_local_agent_adapter_dispatch"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
            ]))),
            "add_sparse_runtime_split_artifact"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
            ]))),
            "build_residency_construction_graph_dry_run"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
            ]))),
            "coactivation_tile_prefetch"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
            ]))),
            "proof_carrying_residency_lease"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
            ]))),
            "cold_assembly_plan_70b_lite"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
                COLD_ASSEMBLY_PLAN_70B_LITE,
            ]))),
            "lattice_state_controller"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
                COLD_ASSEMBLY_PLAN_70B_LITE,
                LATTICE_STATE_CONTROLLER,
            ]))),
            "reasoning_state_continuity"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
                COLD_ASSEMBLY_PLAN_70B_LITE,
                LATTICE_STATE_CONTROLLER,
                REASONING_STATE_CONTINUITY,
            ]))),
            "cold_miss_ledger"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
                COLD_ASSEMBLY_PLAN_70B_LITE,
                LATTICE_STATE_CONTROLLER,
                REASONING_STATE_CONTINUITY,
                COLD_MISS_LEDGER,
            ]))),
            "swiftlm_source_intake"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
                COLD_ASSEMBLY_PLAN_70B_LITE,
                LATTICE_STATE_CONTROLLER,
                REASONING_STATE_CONTINUITY,
                COLD_MISS_LEDGER,
                SWIFTLM_SOURCE_INTAKE,
            ]))),
            "meta_breakthrough_card_registry"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
                COLD_ASSEMBLY_PLAN_70B_LITE,
                LATTICE_STATE_CONTROLLER,
                REASONING_STATE_CONTINUITY,
                COLD_MISS_LEDGER,
                SWIFTLM_SOURCE_INTAKE,
                META_BREAKTHROUGH_CARD_REGISTRY,
            ]))),
            "proof_carrying_route_card"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
                COLD_ASSEMBLY_PLAN_70B_LITE,
                LATTICE_STATE_CONTROLLER,
                REASONING_STATE_CONTINUITY,
                COLD_MISS_LEDGER,
                SWIFTLM_SOURCE_INTAKE,
                META_BREAKTHROUGH_CARD_REGISTRY,
                PROOF_CARRYING_ROUTE_CARD,
            ]))),
            "rust_route_kernel_model_check"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
                COLD_ASSEMBLY_PLAN_70B_LITE,
                LATTICE_STATE_CONTROLLER,
                REASONING_STATE_CONTINUITY,
                COLD_MISS_LEDGER,
                SWIFTLM_SOURCE_INTAKE,
                META_BREAKTHROUGH_CARD_REGISTRY,
                PROOF_CARRYING_ROUTE_CARD,
                RUST_ROUTE_KERNEL_MODEL_CHECK,
            ]))),
            "brain_route_card_multi_model"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
                COLD_ASSEMBLY_PLAN_70B_LITE,
                LATTICE_STATE_CONTROLLER,
                REASONING_STATE_CONTINUITY,
                COLD_MISS_LEDGER,
                SWIFTLM_SOURCE_INTAKE,
                META_BREAKTHROUGH_CARD_REGISTRY,
                PROOF_CARRYING_ROUTE_CARD,
                RUST_ROUTE_KERNEL_MODEL_CHECK,
                BRAIN_ROUTE_CARD_MULTI_MODEL,
            ]))),
            "kv_page_control_query_aware"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
                COLD_ASSEMBLY_PLAN_70B_LITE,
                LATTICE_STATE_CONTROLLER,
                REASONING_STATE_CONTINUITY,
                COLD_MISS_LEDGER,
                SWIFTLM_SOURCE_INTAKE,
                META_BREAKTHROUGH_CARD_REGISTRY,
                PROOF_CARRYING_ROUTE_CARD,
                RUST_ROUTE_KERNEL_MODEL_CHECK,
                BRAIN_ROUTE_CARD_MULTI_MODEL,
                KV_PAGE_CONTROL_QUERY_AWARE,
            ]))),
            "neural_control_card_ablation"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
                COLD_ASSEMBLY_PLAN_70B_LITE,
                LATTICE_STATE_CONTROLLER,
                REASONING_STATE_CONTINUITY,
                COLD_MISS_LEDGER,
                SWIFTLM_SOURCE_INTAKE,
                META_BREAKTHROUGH_CARD_REGISTRY,
                PROOF_CARRYING_ROUTE_CARD,
                RUST_ROUTE_KERNEL_MODEL_CHECK,
                BRAIN_ROUTE_CARD_MULTI_MODEL,
                KV_PAGE_CONTROL_QUERY_AWARE,
                NEURAL_CONTROL_CARD_ABLATION,
            ]))),
            "verifier_regret_ledger"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
                COLD_ASSEMBLY_PLAN_70B_LITE,
                LATTICE_STATE_CONTROLLER,
                REASONING_STATE_CONTINUITY,
                COLD_MISS_LEDGER,
                SWIFTLM_SOURCE_INTAKE,
                META_BREAKTHROUGH_CARD_REGISTRY,
                PROOF_CARRYING_ROUTE_CARD,
                RUST_ROUTE_KERNEL_MODEL_CHECK,
                BRAIN_ROUTE_CARD_MULTI_MODEL,
                KV_PAGE_CONTROL_QUERY_AWARE,
                NEURAL_CONTROL_CARD_ABLATION,
                VERIFIER_REGRET_LEDGER,
            ]))),
            "route_scout_ssm_baseline"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
                COLD_ASSEMBLY_PLAN_70B_LITE,
                LATTICE_STATE_CONTROLLER,
                REASONING_STATE_CONTINUITY,
                COLD_MISS_LEDGER,
                SWIFTLM_SOURCE_INTAKE,
                META_BREAKTHROUGH_CARD_REGISTRY,
                PROOF_CARRYING_ROUTE_CARD,
                RUST_ROUTE_KERNEL_MODEL_CHECK,
                BRAIN_ROUTE_CARD_MULTI_MODEL,
                KV_PAGE_CONTROL_QUERY_AWARE,
                NEURAL_CONTROL_CARD_ABLATION,
                VERIFIER_REGRET_LEDGER,
                ROUTE_SCOUT_SSM_BASELINE,
            ]))),
            "two_stage_route_scout_abstain"
        );
        assert_eq!(
            nb_heavy(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
            ]))),
            "run_70b_local_cocktail_with_real_inputs"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
                KV_CONTRACT,
                MODEL_ASSETS,
                MODEL_IDENTITY,
                MODEL_CONTEXT,
                PROMPT_MANIFEST,
                PROMPT_SHAPE,
                FULL_PLAN,
                LOGITS,
                METRICS,
                SPILL_TRACE,
                SPILL_CONTRACT,
                SHAPE_FLOOR,
                LIVE_128K,
                AGENT_LOCAL_BRIDGE,
                ACTIVE_ASSEMBLY,
                SPARSE_RUNTIME,
                RESIDENCY_CONSTRUCTION_GRAPH,
                COACTIVATION_TILE_PREFETCH,
                PROOF_CARRYING_RESIDENCY_LEASE,
                COLD_ASSEMBLY_PLAN_70B_LITE,
                LATTICE_STATE_CONTROLLER,
                REASONING_STATE_CONTINUITY,
                COLD_MISS_LEDGER,
                SWIFTLM_SOURCE_INTAKE,
                META_BREAKTHROUGH_CARD_REGISTRY,
                PROOF_CARRYING_ROUTE_CARD,
                RUST_ROUTE_KERNEL_MODEL_CHECK,
                BRAIN_ROUTE_CARD_MULTI_MODEL,
                KV_PAGE_CONTROL_QUERY_AWARE,
                NEURAL_CONTROL_CARD_ABLATION,
                VERIFIER_REGRET_LEDGER,
                ROUTE_SCOUT_SSM_BASELINE,
                SEVENTY_B,
            ]))),
            "ready_for_product_route_review"
        );
    }

    #[test]
    fn schema_shape_detector_distinguishes_legacy_artifacts() {
        let normalized = serde_json::json!({
            "falsifier_id": "F-Test",
            "artifact_kind": "failure_report",
            "hardware_pin": {},
            "command_digest": "sha256:test",
            "runner_environment": {},
            "commit_sha": "0",
            "result_digest": "sha256:test",
            "overall_pass": false,
            "fallback_tier": "Fail"
        });
        let legacy = serde_json::json!({
            "falsifier": "F-Test",
            "status": "PASS",
            "pass_per_axis": {"a": true}
        });
        assert!(has_schema_normalized_shape(&normalized));
        assert!(!has_schema_normalized_shape(&legacy));
    }

    #[test]
    fn kv_direct_run_plan_validator_requires_full_suite_shape() {
        let path = std::env::temp_dir().join(format!(
            "epistemos_kv_direct_run_plan_{}_{}.json",
            std::process::id(),
            128_000
        ));
        let plan = serde_json::json!({
            "prompt_count": 100,
            "target_context_tokens": 128000,
            "decode_tokens_per_prompt": 256,
            "shard_count": 1,
            "canonical_spill_route_required": "residual_patched_mmap_nf4_ssd_spill",
            "shards": [{
                "max_prompts": 100,
                "prompt_ids": (0..100).map(|i| format!("prompt_{i:03}")).collect::<Vec<_>>(),
                "run_command": [
                    "Tools/falsifiers/run_kv_direct_mlx_live.sh",
                    "--allow-full-suite",
                    "--prompt-offset",
                    "0",
                    "--max-prompts",
                    "100"
                ]
            }],
            "merge_command": ["Tools/falsifiers/merge_kv_direct_mlx_shards.sh"],
            "falsifier_env": {
                "EPISTEMOS_KV_DIRECT_PROMPT_SUITE": "suite.json",
                "EPISTEMOS_KV_DIRECT_REFERENCE_LOGITS": "reference_logits.json",
                "EPISTEMOS_KV_DIRECT_TEST_LOGITS": "test_logits.json",
                "EPISTEMOS_KV_DIRECT_METRICS_PATH": "metrics.json",
                "EPISTEMOS_KV_DIRECT_SPILL_TRACE": "spill_trace.json"
            }
        });
        std::fs::write(&path, serde_json::to_vec(&plan).unwrap()).unwrap();
        assert!(valid_kv_direct_full_suite_run_plan(path.to_str().unwrap()));

        let mut undersized = plan;
        undersized["target_context_tokens"] = serde_json::json!(2048);
        std::fs::write(&path, serde_json::to_vec(&undersized).unwrap()).unwrap();
        assert!(!valid_kv_direct_full_suite_run_plan(path.to_str().unwrap()));
        let _ = std::fs::remove_file(path);
    }
}
