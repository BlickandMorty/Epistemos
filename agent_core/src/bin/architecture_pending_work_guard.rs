//! Architecture Pending Work Guard.
//!
//! This is the pre-loop duplicate-work check for the Capability Ceiling queue.
//! It reads the executable route queue plus the KV-Direct full-suite plan and
//! emits one artifact that answers:
//! "what is already mapped, what is partially done, and what exact work should
//! continue next without rebuilding something twice?"

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-Architecture-Pending-Work-Guard";
const FIXTURE_ID: &str = "capability_ceiling_pending_work_dedup_v1";
const COMMAND: &str = "Tools/falsifiers/f_architecture_pending_work_guard.sh";
const OUTPUT: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";

const CAPABILITY_KERNEL_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const KV_PROMPT_SUITE_PATH: &str = "artifacts/falsifiers/kv_direct_gate/prompt_suite.json";
const KV_FULL_SUITE_PLAN_PATH: &str =
    "artifacts/falsifiers/kv_direct_gate/live_mlx_full_suite_plan/full_suite_run_plan.json";
const KV_SMOKE_DIR: &str = "artifacts/falsifiers/kv_direct_gate/live_mlx";
const KV_MERGED_DIR: &str = "artifacts/falsifiers/kv_direct_gate/live_mlx_merged";
const KV_DIRECT_RESULT_PATH: &str = "artifacts/falsifiers/kv_direct_gate/result.json";
const WEIGHT_BLOCK_RANGE_HASH_DRY_RUN_PATH: &str =
    "artifacts/falsifiers/weight_block_range_hash_dry_run/result.json";
const RESIDENCY_PLAN_DRY_RUN_PATH: &str = "artifacts/falsifiers/residency_plan_dry_run/result.json";
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
const TWO_STAGE_ROUTE_SCOUT_ABSTAIN_PATH: &str =
    "artifacts/falsifiers/two_stage_route_scout_abstain/result.json";
const PROVIDER_REFERENCE_MANIFEST_DRY_RUN_PATH: &str =
    "artifacts/falsifiers/provider_reference_manifest_dry_run/result.json";
const PROVIDER_REFERENCE_PROMPT_LEVEL_READINESS_PATH: &str =
    "artifacts/falsifiers/provider_reference_prompt_level_readiness/result.json";
const LOCAL_70B_COCKTAIL_PATH: &str = "artifacts/falsifiers/70b_local_cocktail_lite/result.json";
const LOCAL_WORKTREE_INVENTORY_PATH: &str =
    "docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json";
const KV_MODEL_CONTEXT_INVENTORY_PATH: &str =
    "docs/audits/KV_DIRECT_MODEL_CONTEXT_INVENTORY_2026_05_28.json";
const HEAVY_LONG_CONTEXT_ENV: &str = "EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT";
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
const TWO_STAGE_ROUTE_SCOUT_ABSTAIN_AXES: &[&str] = &[
    "upstream_route_scout_ssm_baseline_pass",
    "two_stage_fixture_present",
    "training_split_bound",
    "held_out_split_bound",
    "task_signatures_bound",
    "mission_ids_bound",
    "source_features_bound",
    "verifier_features_bound",
    "stage_a_family_choice_bound",
    "stage_a_no_selector_leak",
    "stage_b_selector_choice_bound",
    "stage_b_family_specific",
    "family_selector_separation_bound",
    "abstain_condition_bound",
    "uncertainty_abstention_bound",
    "verifier_conflict_abstention_bound",
    "irrelevant_selector_rejected_by_fixture",
    "two_stage_cheaper_than_heavy_route",
    "route_success_beats_all_in_one",
    "route_success_beats_static",
    "route_success_beats_no_abstain",
    "abstention_accuracy_beats_no_abstain",
    "abstention_case_present",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "no_hidden_route_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "live_policy_not_mutated",
    "two_stage_address_deterministic",
    "duplicate_task_rejected",
    "missing_stage_a_rejected",
    "missing_stage_b_rejected",
    "stage_a_selector_leak_rejected",
    "family_selector_mismatch_rejected",
    "irrelevant_selector_chosen_rejected",
    "missing_abstain_threshold_rejected",
    "high_uncertainty_non_abstain_rejected",
    "conflict_non_abstain_rejected",
    "all_in_one_selector_unbeaten_rejected",
    "static_selector_unbeaten_rejected",
    "no_abstain_unbeaten_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_live_authority_rejected",
    "live_policy_mutation_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_route_rejected",
    "two_stage_over_budget_rejected",
    "two_stage_not_cheaper_rejected",
    "no_runtime_bytes_loaded",
];

const CONTRACT_FILES: [&str; 5] = [
    "manifest.json",
    "reference_logits.json",
    "test_logits.json",
    "metrics.json",
    "spill_trace.json",
];

fn main() {
    let report = build_report();
    let path = PathBuf::from(OUTPUT);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("create architecture pending guard directory");
    }
    let mut file = std::fs::File::create(&path).expect("open architecture pending guard artifact");
    write_artifact(&mut file, &report.artifact).expect("write architecture pending guard artifact");

    println!(
        "Architecture Pending Work Guard: overall_pass={} next_existing_work={} duplicate_risk_count={} artifact={}",
        report.artifact.overall_pass,
        report.next_existing_work,
        report.duplicate_risk_count,
        path.display()
    );

    if !report.artifact.overall_pass {
        std::process::exit(1);
    }
}

struct GuardReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    next_existing_work: String,
    duplicate_risk_count: u64,
}

fn build_report() -> GuardReport {
    let capability = read_json(Path::new(CAPABILITY_KERNEL_PATH));
    let queue_items = capability
        .as_ref()
        .and_then(extract_queue_items)
        .unwrap_or_default();
    let queue_summary = summarize_queue(&queue_items);
    let plan = read_json(Path::new(KV_FULL_SUITE_PLAN_PATH));
    let plan_summary = plan
        .as_ref()
        .map(summarize_kv_plan)
        .unwrap_or_else(KvPlanSummary::missing);
    let shard_summary = plan.as_ref().map(summarize_shards).unwrap_or_default();
    let merged_summary = contract_dir_status(Path::new(KV_MERGED_DIR));
    let smoke_summary = contract_dir_status(Path::new(KV_SMOKE_DIR));
    let worktree_inventory = read_json(Path::new(LOCAL_WORKTREE_INVENTORY_PATH));
    let worktree_summary = worktree_inventory
        .as_ref()
        .map(summarize_worktree_inventory)
        .unwrap_or_default();
    let model_context_inventory = read_json(Path::new(KV_MODEL_CONTEXT_INVENTORY_PATH));
    let model_context_summary = model_context_inventory
        .as_ref()
        .map(summarize_model_context_inventory)
        .unwrap_or_default();
    let next_bottleneck = capability
        .as_ref()
        .and_then(|v| measurement_string(v, "next_bottleneck"))
        .unwrap_or_else(|| "missing_capability_kernel_next_bottleneck".to_string());
    let heavy_long_context_enabled = capability
        .as_ref()
        .and_then(|v| measurement_bool_value(v, "heavy_long_context_enabled"))
        .unwrap_or_else(heavy_long_context_enabled);
    let kv_result = read_json(Path::new(KV_DIRECT_RESULT_PATH));
    let weight_block_range_hash_dry_run =
        read_json(Path::new(WEIGHT_BLOCK_RANGE_HASH_DRY_RUN_PATH));
    let weight_block_range_hash_dry_run_available = artifact_all_axes_true(
        &weight_block_range_hash_dry_run,
        &[
            "bounded_range_hashed",
            "range_len_bytes",
            "over_limit_rejected_before_read",
            "short_reader_rejected",
            "known_hash_manifest_valid",
            "no_model_file_touched",
        ],
    );
    let residency_plan_dry_run = read_json(Path::new(RESIDENCY_PLAN_DRY_RUN_PATH));
    let residency_plan_dry_run_available = artifact_all_axes_true(
        &residency_plan_dry_run,
        &[
            "fit_for_dry_run",
            "deterministic_plan_address",
            "runtime_model_bytes_loaded",
            "missing_rollback_rejected",
            "overlapping_ranges_rejected",
            "sherry_and_leech_codec_names_present",
        ],
    );
    let residency_construction_graph = read_json(Path::new(RESIDENCY_CONSTRUCTION_GRAPH_PATH));
    let residency_construction_graph_available = artifact_all_axes_true(
        &residency_construction_graph,
        &[
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
        ],
    );
    let coactivation_tile_prefetch = read_json(Path::new(COACTIVATION_TILE_PREFETCH_PATH));
    let coactivation_tile_prefetch_available = artifact_all_axes_true(
        &coactivation_tile_prefetch,
        &[
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
        ],
    );
    let proof_carrying_residency_lease = read_json(Path::new(PROOF_CARRYING_RESIDENCY_LEASE_PATH));
    let proof_carrying_residency_lease_available = artifact_all_axes_true(
        &proof_carrying_residency_lease,
        &[
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
        ],
    );
    let cold_assembly_plan_70b_lite = read_json(Path::new(COLD_ASSEMBLY_PLAN_70B_LITE_PATH));
    let cold_assembly_plan_70b_lite_available = artifact_all_axes_true(
        &cold_assembly_plan_70b_lite,
        &[
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
        ],
    );
    let lattice_state_controller = read_json(Path::new(LATTICE_STATE_CONTROLLER_PATH));
    let lattice_state_controller_available = artifact_all_axes_true(
        &lattice_state_controller,
        &[
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
        ],
    );
    let reasoning_state_continuity = read_json(Path::new(REASONING_STATE_CONTINUITY_PATH));
    let reasoning_state_continuity_available = artifact_all_axes_true(
        &reasoning_state_continuity,
        &[
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
        ],
    );
    let cold_miss_ledger = read_json(Path::new(COLD_MISS_LEDGER_PATH));
    let cold_miss_ledger_available = artifact_all_axes_true(
        &cold_miss_ledger,
        &[
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
        ],
    );
    let swiftlm_source_intake = read_json(Path::new(SWIFTLM_SOURCE_INTAKE_PATH));
    let swiftlm_source_intake_available = artifact_all_axes_true(
        &swiftlm_source_intake,
        &[
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
        ],
    );
    let meta_breakthrough_card_registry =
        read_json(Path::new(META_BREAKTHROUGH_CARD_REGISTRY_PATH));
    let meta_breakthrough_card_registry_available = artifact_all_axes_true(
        &meta_breakthrough_card_registry,
        &[
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
        ],
    );
    let proof_carrying_route_card = read_json(Path::new(PROOF_CARRYING_ROUTE_CARD_PATH));
    let proof_carrying_route_card_available = artifact_all_axes_true(
        &proof_carrying_route_card,
        &[
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
        ],
    );
    let rust_route_kernel_model_check = read_json(Path::new(RUST_ROUTE_KERNEL_MODEL_CHECK_PATH));
    let rust_route_kernel_model_check_available = artifact_all_axes_true(
        &rust_route_kernel_model_check,
        RUST_ROUTE_KERNEL_MODEL_CHECK_AXES,
    );
    let brain_route_card_multi_model = read_json(Path::new(BRAIN_ROUTE_CARD_MULTI_MODEL_PATH));
    let brain_route_card_multi_model_available = artifact_all_axes_true(
        &brain_route_card_multi_model,
        BRAIN_ROUTE_CARD_MULTI_MODEL_AXES,
    );
    let kv_page_control_query_aware = read_json(Path::new(KV_PAGE_CONTROL_QUERY_AWARE_PATH));
    let kv_page_control_query_aware_available = artifact_all_axes_true(
        &kv_page_control_query_aware,
        KV_PAGE_CONTROL_QUERY_AWARE_AXES,
    );
    let neural_control_card_ablation = read_json(Path::new(NEURAL_CONTROL_CARD_ABLATION_PATH));
    let neural_control_card_ablation_available = artifact_all_axes_true(
        &neural_control_card_ablation,
        NEURAL_CONTROL_CARD_ABLATION_AXES,
    );
    let verifier_regret_ledger = read_json(Path::new(VERIFIER_REGRET_LEDGER_PATH));
    let verifier_regret_ledger_available =
        artifact_all_axes_true(&verifier_regret_ledger, VERIFIER_REGRET_LEDGER_AXES);
    let route_scout_ssm_baseline = read_json(Path::new(ROUTE_SCOUT_SSM_BASELINE_PATH));
    let route_scout_ssm_baseline_available =
        artifact_all_axes_true(&route_scout_ssm_baseline, ROUTE_SCOUT_SSM_BASELINE_AXES);
    let two_stage_route_scout_abstain = read_json(Path::new(TWO_STAGE_ROUTE_SCOUT_ABSTAIN_PATH));
    let two_stage_route_scout_abstain_available = artifact_all_axes_true(
        &two_stage_route_scout_abstain,
        TWO_STAGE_ROUTE_SCOUT_ABSTAIN_AXES,
    );
    let provider_reference_manifest_dry_run =
        read_json(Path::new(PROVIDER_REFERENCE_MANIFEST_DRY_RUN_PATH));
    let provider_reference_manifest_dry_run_available = artifact_all_axes_true(
        &provider_reference_manifest_dry_run,
        &[
            "shape_fixture_written",
            "manifest_valid",
            "prompt_level_reference",
            "does_not_advance_70b_reference_gate",
            "row_root_path",
            "digest_matches_sidecar",
            "replay_files_valid",
            "prompt_suite_bound",
            "no_provider_call",
        ],
    );
    let provider_reference_prompt_level_readiness =
        read_json(Path::new(PROVIDER_REFERENCE_PROMPT_LEVEL_READINESS_PATH));
    let provider_reference_prompt_level_readiness_witness_available = artifact_has_axes(
        &provider_reference_prompt_level_readiness,
        &[
            "provider_reference_env_set",
            "manifest_file_exists",
            "manifest_valid",
            "prompt_level_scope",
            "prompt_count_floor",
            "replay_files_valid",
            "prompt_level_reference_available",
        ],
    )
        && provider_reference_prompt_level_readiness
            .as_ref()
            .and_then(|value| measurement_string_value(value, "primary_blocker"))
            .is_some();
    let provider_reference_prompt_level_readiness_primary_blocker =
        provider_reference_prompt_level_readiness
            .as_ref()
            .and_then(|value| measurement_string_value(value, "primary_blocker"));
    let local_70b_cocktail = read_json(Path::new(LOCAL_70B_COCKTAIL_PATH));
    let local_70b_cocktail_honest_red = local_70b_cocktail.as_ref().is_some_and(|value| {
        !artifact_overall_pass_value(value)
            && measurement_string_value(value, "primary_bottleneck").as_deref()
                == Some("missing_fp16_or_provider_reference")
            && artifact_axis_true_value(value, "weight_block_range_hash_dry_run_available")
            && artifact_axis_true_value(value, "residency_plan_dry_run_available")
            && !artifact_axis_true_value(value, "provider_reference_available")
    });
    let kv_fixture_logits_available = kv_result
        .as_ref()
        .and_then(|v| v.get("pass_per_axis"))
        .and_then(|axes| axes.get("reference_logits_available"))
        .and_then(|v| v.as_bool())
        .unwrap_or(false)
        && kv_result
            .as_ref()
            .and_then(|v| v.get("pass_per_axis"))
            .and_then(|axes| axes.get("test_logits_available"))
            .and_then(|v| v.as_bool())
            .unwrap_or(false);

    let next_existing_work = derive_next_existing_work(
        Path::new(KV_PROMPT_SUITE_PATH).exists(),
        plan_summary.available,
        &shard_summary,
        &merged_summary,
        kv_fixture_logits_available,
        &next_bottleneck,
        provider_reference_prompt_level_readiness_primary_blocker.as_deref(),
        heavy_long_context_enabled,
    );
    let duplicate_risk_count = queue_summary.duplicate_gap_ids
        + queue_summary.duplicate_orders
        + plan_summary.duplicate_prompt_ids
        + plan_summary.duplicate_output_dirs;
    let required_state_present = capability.is_some()
        && !queue_items.is_empty()
        && Path::new(KV_PROMPT_SUITE_PATH).exists()
        && plan_summary.available
        && weight_block_range_hash_dry_run_available
        && residency_plan_dry_run_available
        && residency_construction_graph_available
        && coactivation_tile_prefetch_available
        && proof_carrying_residency_lease_available
        && cold_assembly_plan_70b_lite_available
        && lattice_state_controller_available
        && reasoning_state_continuity_available
        && cold_miss_ledger_available
        && swiftlm_source_intake_available
        && meta_breakthrough_card_registry_available
        && proof_carrying_route_card_available
        && rust_route_kernel_model_check_available
        && brain_route_card_multi_model_available
        && kv_page_control_query_aware_available
        && neural_control_card_ablation_available
        && verifier_regret_ledger_available
        && route_scout_ssm_baseline_available
        && two_stage_route_scout_abstain_available
        && provider_reference_manifest_dry_run_available
        && (!heavy_long_context_enabled
            || provider_reference_prompt_level_readiness_witness_available)
        && (!heavy_long_context_enabled || local_70b_cocktail_honest_red)
        && worktree_inventory.is_some()
        && model_context_inventory.is_some()
        && next_existing_work != "unset";
    let no_duplicate_risk = duplicate_risk_count == 0;
    let plan_shape_ok = plan_summary.shape_ok;
    let shard_cursor_ok = shard_summary.total > 0 || !plan_summary.available;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "capability_kernel_artifact_available",
        capability.is_some(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "ordered_queue_available",
        !queue_items.is_empty(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "queue_gap_ids_unique",
        queue_summary.duplicate_gap_ids == 0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "queue_orders_unique",
        queue_summary.duplicate_orders == 0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "queue_required_fields_present",
        queue_summary.missing_required_fields == 0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_prompt_suite_available",
        Path::new(KV_PROMPT_SUITE_PATH).exists(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_full_suite_run_plan_available",
        plan_summary.available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_full_suite_run_plan_shape_ok",
        plan_shape_ok,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_plan_prompt_ids_unique",
        plan_summary.duplicate_prompt_ids == 0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_plan_output_dirs_unique",
        plan_summary.duplicate_output_dirs == 0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "weight_block_range_hash_dry_run_available",
        weight_block_range_hash_dry_run_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "residency_plan_dry_run_available",
        residency_plan_dry_run_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "residency_construction_graph_available",
        residency_construction_graph_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "coactivation_tile_prefetch_available",
        coactivation_tile_prefetch_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_carrying_residency_lease_available",
        proof_carrying_residency_lease_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_assembly_plan_70b_lite_available",
        cold_assembly_plan_70b_lite_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lattice_state_controller_available",
        lattice_state_controller_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "reasoning_state_continuity_available",
        reasoning_state_continuity_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_miss_ledger_available",
        cold_miss_ledger_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "swiftlm_source_intake_available",
        swiftlm_source_intake_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "meta_breakthrough_card_registry_available",
        meta_breakthrough_card_registry_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_carrying_route_card_available",
        proof_carrying_route_card_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rust_route_kernel_model_check_available",
        rust_route_kernel_model_check_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "brain_route_card_multi_model_available",
        brain_route_card_multi_model_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_page_control_query_aware_available",
        kv_page_control_query_aware_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "neural_control_card_ablation_available",
        neural_control_card_ablation_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_regret_ledger_available",
        verifier_regret_ledger_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_scout_ssm_baseline_available",
        route_scout_ssm_baseline_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "two_stage_route_scout_abstain_available",
        two_stage_route_scout_abstain_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_reference_manifest_dry_run_available",
        provider_reference_manifest_dry_run_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_reference_prompt_level_readiness_witness_available",
        provider_reference_prompt_level_readiness_witness_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_70b_cocktail_honest_red",
        local_70b_cocktail_honest_red,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_worktree_inventory_available",
        worktree_inventory.is_some(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_worktree_inventory_non_destructive",
        worktree_inventory
            .as_ref()
            .and_then(|v| v.get("non_destructive"))
            .and_then(|v| v.as_bool())
            .unwrap_or(false),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_worktree_current_repo_present",
        worktree_summary.current_repo_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_model_context_inventory_available",
        model_context_inventory.is_some(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_model_context_inventory_non_destructive",
        model_context_inventory
            .as_ref()
            .and_then(|v| v.get("non_destructive"))
            .and_then(|v| v.as_bool())
            .unwrap_or(false),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "pending_work_cursor_available",
        required_state_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_duplicate_rebuild_risk",
        no_duplicate_risk,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "shard_cursor_mapped",
        shard_cursor_ok,
    );

    add_count_measurement(&mut measurements, "queue_item_count", queue_summary.total);
    add_count_measurement(
        &mut measurements,
        "queue_pending_item_count",
        queue_summary.pending,
    );
    add_count_measurement(
        &mut measurements,
        "queue_duplicate_gap_id_count",
        queue_summary.duplicate_gap_ids,
    );
    add_count_measurement(
        &mut measurements,
        "queue_duplicate_order_count",
        queue_summary.duplicate_orders,
    );
    add_count_measurement(
        &mut measurements,
        "queue_missing_required_field_count",
        queue_summary.missing_required_fields,
    );
    add_count_measurement(
        &mut measurements,
        "kv_plan_duplicate_prompt_id_count",
        plan_summary.duplicate_prompt_ids,
    );
    add_count_measurement(
        &mut measurements,
        "kv_plan_duplicate_output_dir_count",
        plan_summary.duplicate_output_dirs,
    );
    add_count_measurement(
        &mut measurements,
        "kv_plan_shard_count",
        shard_summary.total,
    );
    add_count_measurement(
        &mut measurements,
        "kv_complete_shard_count",
        shard_summary.complete,
    );
    add_count_measurement(
        &mut measurements,
        "kv_partial_shard_count",
        shard_summary.partial,
    );
    add_count_measurement(
        &mut measurements,
        "kv_failed_shard_count",
        shard_summary.failed,
    );
    add_count_measurement(
        &mut measurements,
        "kv_missing_shard_count",
        shard_summary.missing,
    );
    add_count_measurement(
        &mut measurements,
        "local_epistemos_candidate_count",
        worktree_summary.candidate_count,
    );
    add_count_measurement(
        &mut measurements,
        "local_sibling_worktree_count",
        worktree_summary.sibling_worktree_count,
    );
    add_count_measurement(
        &mut measurements,
        "local_dirty_candidate_count",
        worktree_summary.dirty_candidate_count,
    );
    add_count_measurement(
        &mut measurements,
        "local_high_duplicate_risk_count",
        worktree_summary.high_duplicate_risk_count,
    );
    add_count_measurement(
        &mut measurements,
        "kv_model_context_required_candidate_count",
        model_context_summary.required_context_candidate_count,
    );
    add_count_measurement(
        &mut measurements,
        "kv_model_context_required_text_candidate_count",
        model_context_summary.required_context_text_model_candidate_count,
    );
    add_label(
        &mut measurements,
        "kv_model_context_best_candidate_repo_id",
        &model_context_summary.best_required_context_candidate_repo_id,
    );
    add_bool_measurement(
        &mut measurements,
        "kv_model_context_canonical_context_ok",
        model_context_summary.canonical_context_ok,
    );
    add_bool_measurement(&mut measurements, "heavy_long_context_guard_present", true);
    add_bool_measurement(
        &mut measurements,
        "heavy_long_context_enabled",
        heavy_long_context_enabled,
    );
    add_bool_measurement(
        &mut measurements,
        "large_model_provider_reference_required",
        heavy_long_context_enabled,
    );
    add_label(&mut measurements, "next_bottleneck", &next_bottleneck);
    add_label(
        &mut measurements,
        "provider_reference_prompt_level_primary_blocker",
        provider_reference_prompt_level_readiness_primary_blocker
            .as_deref()
            .unwrap_or("missing_provider_reference_prompt_level_readiness_artifact"),
    );
    add_label(&mut measurements, "next_existing_work", &next_existing_work);
    add_label(
        &mut measurements,
        "first_incomplete_shard",
        shard_summary.first_incomplete.as_deref().unwrap_or("none"),
    );
    add_label(
        &mut measurements,
        "first_incomplete_shard_status",
        shard_summary
            .first_incomplete_status
            .as_deref()
            .unwrap_or("none"),
    );
    add_json_measurement(
        &mut measurements,
        "already_mapped_work",
        serde_json::json!({
            "kv_prompt_suite": {
                "path": KV_PROMPT_SUITE_PATH,
                "exists": Path::new(KV_PROMPT_SUITE_PATH).exists()
            },
            "kv_full_suite_plan": {
                "path": KV_FULL_SUITE_PLAN_PATH,
                "exists": plan_summary.available,
                "falsifier_green_capable": plan_summary.falsifier_green_capable
            },
            "kv_smoke_contract_dir": {
                "path": KV_SMOKE_DIR,
                "status": smoke_summary.status_label()
            },
            "kv_merged_contract_dir": {
                "path": KV_MERGED_DIR,
                "status": merged_summary.status_label()
            },
            "local_worktree_inventory": {
                "path": LOCAL_WORKTREE_INVENTORY_PATH,
                "exists": worktree_inventory.is_some(),
                "candidate_count": worktree_summary.candidate_count,
                "high_duplicate_risk_count": worktree_summary.high_duplicate_risk_count
            },
            "kv_model_context_inventory": {
                "path": KV_MODEL_CONTEXT_INVENTORY_PATH,
                "exists": model_context_inventory.is_some(),
                "canonical_context_ok": model_context_summary.canonical_context_ok,
                "required_text_candidate_count": model_context_summary.required_context_text_model_candidate_count,
                "best_required_context_candidate_repo_id": model_context_summary.best_required_context_candidate_repo_id
            },
            "large_model_non_runtime_rungs": {
                "weight_block_range_hash_dry_run": {
                    "path": WEIGHT_BLOCK_RANGE_HASH_DRY_RUN_PATH,
                    "available": weight_block_range_hash_dry_run_available
                },
                "residency_plan_dry_run": {
                    "path": RESIDENCY_PLAN_DRY_RUN_PATH,
                    "available": residency_plan_dry_run_available
                },
                "residency_construction_graph": {
                    "path": RESIDENCY_CONSTRUCTION_GRAPH_PATH,
                    "available": residency_construction_graph_available
                },
                "coactivation_tile_prefetch": {
                    "path": COACTIVATION_TILE_PREFETCH_PATH,
                    "available": coactivation_tile_prefetch_available
                },
                "proof_carrying_residency_lease": {
                    "path": PROOF_CARRYING_RESIDENCY_LEASE_PATH,
                    "available": proof_carrying_residency_lease_available
                },
                "cold_assembly_plan_70b_lite": {
                    "path": COLD_ASSEMBLY_PLAN_70B_LITE_PATH,
                    "available": cold_assembly_plan_70b_lite_available
                },
                "lattice_state_controller": {
                    "path": LATTICE_STATE_CONTROLLER_PATH,
                    "available": lattice_state_controller_available
                },
                "reasoning_state_continuity": {
                    "path": REASONING_STATE_CONTINUITY_PATH,
                    "available": reasoning_state_continuity_available
                },
                "cold_miss_ledger": {
                    "path": COLD_MISS_LEDGER_PATH,
                    "available": cold_miss_ledger_available
                },
                "swiftlm_source_intake": {
                    "path": SWIFTLM_SOURCE_INTAKE_PATH,
                    "available": swiftlm_source_intake_available
                },
                "meta_breakthrough_card_registry": {
                    "path": META_BREAKTHROUGH_CARD_REGISTRY_PATH,
                    "available": meta_breakthrough_card_registry_available
                },
                "proof_carrying_route_card": {
                    "path": PROOF_CARRYING_ROUTE_CARD_PATH,
                    "available": proof_carrying_route_card_available
                },
                "rust_route_kernel_model_check": {
                    "path": RUST_ROUTE_KERNEL_MODEL_CHECK_PATH,
                    "available": rust_route_kernel_model_check_available
                },
                "brain_route_card_multi_model": {
                    "path": BRAIN_ROUTE_CARD_MULTI_MODEL_PATH,
                    "available": brain_route_card_multi_model_available
                },
                "kv_page_control_query_aware": {
                    "path": KV_PAGE_CONTROL_QUERY_AWARE_PATH,
                    "available": kv_page_control_query_aware_available
                },
                "neural_control_card_ablation": {
                    "path": NEURAL_CONTROL_CARD_ABLATION_PATH,
                    "available": neural_control_card_ablation_available
                },
                "verifier_regret_ledger": {
                    "path": VERIFIER_REGRET_LEDGER_PATH,
                    "available": verifier_regret_ledger_available
                },
                "route_scout_ssm_baseline": {
                    "path": ROUTE_SCOUT_SSM_BASELINE_PATH,
                    "available": route_scout_ssm_baseline_available
                },
                "two_stage_route_scout_abstain": {
                    "path": TWO_STAGE_ROUTE_SCOUT_ABSTAIN_PATH,
                    "available": two_stage_route_scout_abstain_available
                },
                "provider_reference_manifest_dry_run": {
                    "path": PROVIDER_REFERENCE_MANIFEST_DRY_RUN_PATH,
                    "available": provider_reference_manifest_dry_run_available
                },
                "provider_reference_prompt_level_readiness": {
                    "path": PROVIDER_REFERENCE_PROMPT_LEVEL_READINESS_PATH,
                    "witness_available": provider_reference_prompt_level_readiness_witness_available,
                    "overall_pass": provider_reference_prompt_level_readiness
                        .as_ref()
                        .is_some_and(artifact_overall_pass_value),
                    "primary_blocker": provider_reference_prompt_level_readiness
                        .as_ref()
                        .and_then(|value| measurement_string_value(value, "primary_blocker"))
                        .unwrap_or_else(|| "missing_provider_reference_prompt_level_readiness_artifact".to_string())
                },
                "local_70b_cocktail_preflight": {
                    "path": LOCAL_70B_COCKTAIL_PATH,
                    "honest_red": local_70b_cocktail_honest_red,
                    "primary_bottleneck": local_70b_cocktail
                        .as_ref()
                        .and_then(|value| measurement_string_value(value, "primary_bottleneck"))
                        .unwrap_or_else(|| "missing_70b_preflight_artifact".to_string())
                },
                "provider_reference_route_required": heavy_long_context_enabled
            }
        }),
    );
    add_json_measurement(
        &mut measurements,
        "incomplete_shards",
        serde_json::Value::Array(
            shard_summary
                .incomplete_shards
                .iter()
                .map(|shard| serde_json::Value::String(shard.clone()))
                .collect(),
        ),
    );
    add_json_measurement(
        &mut measurements,
        "failed_shards",
        serde_json::Value::Array(
            shard_summary
                .failed_shards
                .iter()
                .map(|shard| serde_json::Value::String(shard.clone()))
                .collect(),
        ),
    );

    let mut anomalies = Vec::new();
    if !required_state_present {
        anomalies.push(serde_json::json!({
            "kind": "missing_pending_work_cursor",
            "detail": "The loop cannot safely continue without the capability kernel artifact, ordered queue, prompt suite, full-suite plan, and next-existing-work cursor."
        }));
    }
    if !no_duplicate_risk {
        anomalies.push(serde_json::json!({
            "kind": "duplicate_work_risk",
            "detail": format!("duplicate_risk_count={duplicate_risk_count}; inspect queue gap/order ids and KV plan prompt/output-dir ids before implementing.")
        }));
    }
    if plan_summary.available && !plan_summary.falsifier_green_capable {
        anomalies.push(serde_json::json!({
            "kind": "mapped_nonpromoting_kv_route",
            "detail": "The current full-suite plan is useful continuation work, but it is still prompt_cache_reload development evidence and cannot promote F-KV-Direct-Gate."
        }));
    }
    if !weight_block_range_hash_dry_run_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_weight_block_range_hash_dry_run",
            "detail": "Large-model construction must prove bounded byte-range fingerprinting before trusting SSD-backed model byte ranges."
        }));
    }
    if !residency_plan_dry_run_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_residency_plan_dry_run",
            "detail": "Large-model construction must prove the active set fits the 16 GB floor before any runtime probe."
        }));
    }
    if !residency_construction_graph_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_residency_construction_graph",
            "detail": "Research Construction must prove candidate-unit scoring, evidence edges, budget rejection, and rollback discipline before coactivation tile prefetch continues."
        }));
    }
    if residency_construction_graph_available && !coactivation_tile_prefetch_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_coactivation_tile_prefetch",
            "detail": "Research Construction has a graph witness, but needs F-CoactivationTile-Prefetch before proof-carrying residency lease work continues."
        }));
    }
    if coactivation_tile_prefetch_available && !proof_carrying_residency_lease_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_proof_carrying_residency_lease",
            "detail": "Research Construction has a coactivation witness, but needs F-ProofCarryingResidencyLease before cold assembly plan work continues."
        }));
    }
    if proof_carrying_residency_lease_available && !cold_assembly_plan_70b_lite_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_cold_assembly_plan_70b_lite",
            "detail": "Research Construction has proof-carrying leases, but needs F-ColdAssemblyPlan-70B-Lite before LatticeStateController work continues."
        }));
    }
    if cold_assembly_plan_70b_lite_available && !lattice_state_controller_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_lattice_state_controller",
            "detail": "Research Construction has a cold 70B assembly plan, but needs F-LatticeStateController before reasoning-state continuity work continues."
        }));
    }
    if lattice_state_controller_available && !reasoning_state_continuity_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_reasoning_state_continuity",
            "detail": "Research Construction has a lattice controller, but needs F-ReasoningStateContinuity before cold-miss ledger work continues."
        }));
    }
    if reasoning_state_continuity_available && !cold_miss_ledger_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_cold_miss_ledger",
            "detail": "Research Construction has reasoning-state continuity, but needs F-ColdMissLedger before SwiftLM source-intake work continues."
        }));
    }
    if cold_miss_ledger_available && !swiftlm_source_intake_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_swiftlm_source_intake",
            "detail": "Research Construction has cold-miss learning, but needs F-SwiftLM-SourceIntake before meta-breakthrough card registry work continues."
        }));
    }
    if swiftlm_source_intake_available && !meta_breakthrough_card_registry_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_meta_breakthrough_card_registry",
            "detail": "Research Construction has SwiftLM source intake, but needs F-MetaBreakthrough-CardRegistry before proof-carrying route-card work continues."
        }));
    }
    if meta_breakthrough_card_registry_available && !proof_carrying_route_card_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_proof_carrying_route_card",
            "detail": "Meta Control has a card registry, but needs F-ProofCarryingRouteCard before Rust route-kernel model-check work continues."
        }));
    }
    if proof_carrying_route_card_available && !rust_route_kernel_model_check_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_rust_route_kernel_model_check",
            "detail": "Meta Control has proof-carrying route cards, but needs F-RustRouteKernel-ModelCheck before BrainRouteCard routing work continues."
        }));
    }
    if rust_route_kernel_model_check_available && !brain_route_card_multi_model_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_brain_route_card_multi_model",
            "detail": "Meta Control has a bounded route-kernel model check, but needs F-BrainRouteCard-MultiModel before query-aware KV/page control work continues."
        }));
    }
    if brain_route_card_multi_model_available && !kv_page_control_query_aware_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_kv_page_control_query_aware",
            "detail": "Meta Control has BrainRouteCard routing proof, but needs F-KVPageControl-QueryAware before the next non-heavy architecture cursor advances."
        }));
    }
    if kv_page_control_query_aware_available && !neural_control_card_ablation_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_neural_control_card_ablation",
            "detail": "Meta Control has query-aware KV/page proof, but needs F-NeuralControlCard-Ablation before verifier-regret work can advance."
        }));
    }
    if neural_control_card_ablation_available && !verifier_regret_ledger_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_verifier_regret_ledger",
            "detail": "Meta Control has NeuralControlCard ablation proof, but needs F-VerifierRegretLedger before route utility updates can cite regret learning."
        }));
    }
    if verifier_regret_ledger_available && !route_scout_ssm_baseline_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_route_scout_ssm_baseline",
            "detail": "Meta Control has verifier-regret evidence, but needs F-RouteScoutSSM-Baseline before the two-stage abstaining scout cursor can advance."
        }));
    }
    if route_scout_ssm_baseline_available && !two_stage_route_scout_abstain_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_two_stage_route_scout_abstain",
            "detail": "Meta Control has RouteScoutSSM baseline evidence, but needs F-TwoStageRouteScout-Abstain before budgeted uncertainty escalation can advance."
        }));
    }
    if !provider_reference_manifest_dry_run_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_provider_reference_manifest_dry_run",
            "detail": "70B reference evidence must have a digest-bound manifest ABI before prompt-level comparisons can be trusted."
        }));
    }
    if heavy_long_context_enabled && !provider_reference_prompt_level_readiness_witness_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_provider_reference_prompt_level_readiness",
            "detail": "The active provider/fp16 reference bottleneck needs an explicit readiness artifact that audits env, manifest scope, prompt count, and replay-file validity."
        }));
    }
    if heavy_long_context_enabled && !local_70b_cocktail_honest_red {
        anomalies.push(serde_json::json!({
            "kind": "missing_honest_70b_preflight_red_artifact",
            "detail": "The 70B preflight should remain red on missing prompt-level reference/runtime evidence while the safe metadata gates are green."
        }));
    }
    if worktree_summary.high_duplicate_risk_count > 0 {
        anomalies.push(serde_json::json!({
            "kind": "local_worktree_sprawl",
            "detail": format!("{} high duplicate-risk Epistemos sibling/copy surfaces are present under Downloads; inspect docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json before opening more worktrees.", worktree_summary.high_duplicate_risk_count)
        }));
    }
    if shard_summary.partial > 0 {
        anomalies.push(serde_json::json!({
            "kind": "partial_kv_shard_outputs",
            "detail": "At least one KV shard output directory is partial; repair or rerun that shard before starting a later shard."
        }));
    }
    if shard_summary.failed > 0 {
        anomalies.push(serde_json::json!({
            "kind": "failed_kv_shard_outputs",
            "detail": "At least one KV shard recorded failed progress; repair the runtime bottleneck before rerunning the same shard."
        }));
    }
    if model_context_inventory.is_some()
        && !model_context_summary.canonical_context_ok
        && model_context_summary.required_context_text_model_candidate_count > 0
    {
        anomalies.push(serde_json::json!({
            "kind": "alternate_128k_model_candidates_available",
            "detail": format!(
                "Canonical Qwen3-8B 128K context is not satisfied, but {} local text-generation candidates meet the context floor. Best candidate: {}. Treat alternates as development evidence unless canon explicitly changes the F-KV-Direct-Gate model.",
                model_context_summary.required_context_text_model_candidate_count,
                model_context_summary.best_required_context_candidate_repo_id
            )
        }));
    }

    let notes = if heavy_long_context_enabled {
        format!(
            "pending_work_guard; next_existing_work={next_existing_work}; \
             heavy_long_context_enabled=true; do not recreate prompt suite or shard plan while their artifacts exist; \
             continue the first incomplete shard or merge/feed existing shards before building new surfaces"
        )
    } else {
        format!(
            "pending_work_guard; next_existing_work={next_existing_work}; \
             heavy_long_context_enabled=false; 128K Qwen/GGUF shard and 70B provider-reference work are deferred unless EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1 is set; \
             continue non-heavy architecture work before creating new long-context surfaces"
        )
    };
    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: if required_state_present && no_duplicate_risk {
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
        fallback_tier: if required_state_present && no_duplicate_risk {
            FallbackTier::Primary
        } else {
            FallbackTier::Fail
        },
        anomalies,
        notes,
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    GuardReport {
        artifact,
        next_existing_work,
        duplicate_risk_count,
    }
}

#[derive(Debug, Clone, Default)]
struct QueueItem {
    order: Option<u64>,
    gap_id: Option<String>,
    status: Option<String>,
    witness: Option<String>,
    falsifier_or_gate: Option<String>,
}

#[derive(Debug, Clone, Default)]
struct QueueSummary {
    total: u64,
    pending: u64,
    duplicate_gap_ids: u64,
    duplicate_orders: u64,
    missing_required_fields: u64,
}

#[derive(Debug, Clone)]
struct KvPlanSummary {
    available: bool,
    shape_ok: bool,
    falsifier_green_capable: bool,
    duplicate_prompt_ids: u64,
    duplicate_output_dirs: u64,
}

impl KvPlanSummary {
    fn missing() -> Self {
        Self {
            available: false,
            shape_ok: false,
            falsifier_green_capable: false,
            duplicate_prompt_ids: 0,
            duplicate_output_dirs: 0,
        }
    }
}

#[derive(Debug, Clone, Default)]
struct ShardSummary {
    total: u64,
    complete: u64,
    partial: u64,
    failed: u64,
    missing: u64,
    first_incomplete: Option<String>,
    first_incomplete_status: Option<String>,
    incomplete_shards: Vec<String>,
    failed_shards: Vec<String>,
}

#[derive(Debug, Clone, Default)]
struct WorktreeSummary {
    candidate_count: u64,
    sibling_worktree_count: u64,
    dirty_candidate_count: u64,
    high_duplicate_risk_count: u64,
    current_repo_present: bool,
}

#[derive(Debug, Clone, Default)]
struct ModelContextInventorySummary {
    required_context_candidate_count: u64,
    required_context_text_model_candidate_count: u64,
    canonical_context_ok: bool,
    best_required_context_candidate_repo_id: String,
}

#[derive(Debug, Clone, Copy, Eq, PartialEq)]
enum ContractStatus {
    Missing,
    Partial,
    Complete,
}

impl ContractStatus {
    fn status_label(self) -> &'static str {
        match self {
            Self::Missing => "missing",
            Self::Partial => "partial",
            Self::Complete => "complete",
        }
    }
}

fn extract_queue_items(value: &serde_json::Value) -> Option<Vec<QueueItem>> {
    let queue = value
        .get("measurements")?
        .get("ordered_build_queue")?
        .get("value")?
        .as_array()?;
    Some(
        queue
            .iter()
            .map(|item| QueueItem {
                order: item.get("order").and_then(|v| v.as_u64()),
                gap_id: item
                    .get("gap_id")
                    .and_then(|v| v.as_str())
                    .map(ToString::to_string),
                status: item
                    .get("status")
                    .and_then(|v| v.as_str())
                    .map(ToString::to_string),
                witness: item
                    .get("witness")
                    .and_then(|v| v.as_str())
                    .map(ToString::to_string),
                falsifier_or_gate: item
                    .get("falsifier_or_gate")
                    .and_then(|v| v.as_str())
                    .map(ToString::to_string),
            })
            .collect(),
    )
}

fn summarize_queue(items: &[QueueItem]) -> QueueSummary {
    let mut gap_ids = BTreeSet::new();
    let mut orders = BTreeSet::new();
    let mut duplicate_gap_ids = 0;
    let mut duplicate_orders = 0;
    let mut missing_required_fields = 0;
    let mut pending = 0;

    for item in items {
        match item.gap_id.as_deref() {
            Some(gap_id) if !gap_id.is_empty() => {
                if !gap_ids.insert(gap_id.to_string()) {
                    duplicate_gap_ids += 1;
                }
            }
            _ => missing_required_fields += 1,
        }
        match item.order {
            Some(order) => {
                if !orders.insert(order) {
                    duplicate_orders += 1;
                }
            }
            None => missing_required_fields += 1,
        }
        if item.status.as_deref().unwrap_or("").is_empty()
            || item.witness.as_deref().unwrap_or("").is_empty()
            || item.falsifier_or_gate.as_deref().unwrap_or("").is_empty()
        {
            missing_required_fields += 1;
        }
        if item.status.as_deref() != Some("completed") {
            pending += 1;
        }
    }

    QueueSummary {
        total: items.len() as u64,
        pending,
        duplicate_gap_ids,
        duplicate_orders,
        missing_required_fields,
    }
}

fn summarize_kv_plan(value: &serde_json::Value) -> KvPlanSummary {
    let prompt_count = value
        .get("prompt_count")
        .and_then(|v| v.as_u64())
        .unwrap_or_default();
    let target_context = value
        .get("target_context_tokens")
        .and_then(|v| v.as_u64())
        .unwrap_or_default();
    let decode_tokens = value
        .get("decode_tokens_per_prompt")
        .and_then(|v| v.as_u64())
        .unwrap_or_default();
    let shards = value
        .get("shards")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let shard_count = value
        .get("shard_count")
        .and_then(|v| v.as_u64())
        .unwrap_or_default();
    let mut prompt_ids = BTreeSet::new();
    let mut output_dirs = BTreeSet::new();
    let mut duplicate_prompt_ids = 0;
    let mut duplicate_output_dirs = 0;
    let mut command_shape_ok = true;

    for shard in &shards {
        let prompt_id_values = shard
            .get("prompt_ids")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        for prompt_id in prompt_id_values {
            let prompt_id = prompt_id.as_str().unwrap_or("").to_string();
            if prompt_id.is_empty() || !prompt_ids.insert(prompt_id) {
                duplicate_prompt_ids += 1;
            }
        }
        let output_dir = shard
            .get("output_dir")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        if output_dir.is_empty() || !output_dirs.insert(output_dir) {
            duplicate_output_dirs += 1;
        }
        let command = shard
            .get("run_command")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        command_shape_ok = command_shape_ok
            && command
                .iter()
                .any(|arg| arg.as_str() == Some("--allow-full-suite"))
            && command
                .iter()
                .any(|arg| arg.as_str() == Some("--prompt-offset"))
            && command
                .iter()
                .any(|arg| arg.as_str() == Some("--max-prompts"));
    }

    let shape_ok = prompt_count >= 100
        && target_context >= 128_000
        && decode_tokens >= 256
        && shard_count > 0
        && shard_count as usize == shards.len()
        && prompt_ids.len() as u64 == prompt_count
        && command_shape_ok;

    KvPlanSummary {
        available: true,
        shape_ok,
        falsifier_green_capable: value
            .get("falsifier_green_capable")
            .and_then(|v| v.as_bool())
            .unwrap_or(false),
        duplicate_prompt_ids,
        duplicate_output_dirs,
    }
}

fn summarize_shards(plan: &serde_json::Value) -> ShardSummary {
    let shards = plan
        .get("shards")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let mut summary = ShardSummary {
        total: shards.len() as u64,
        ..ShardSummary::default()
    };

    for shard in shards {
        let shard_id = shard
            .get("shard_id")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown_shard")
            .to_string();
        let output_dir = shard
            .get("output_dir")
            .and_then(|v| v.as_str())
            .map(PathBuf::from);
        let status = output_dir
            .as_deref()
            .map(contract_dir_status)
            .unwrap_or(ContractStatus::Missing);
        let progress_status = output_dir
            .as_deref()
            .and_then(progress_status)
            .unwrap_or_else(|| "unset".to_string());
        let is_failed = progress_status == "failed";
        match status {
            ContractStatus::Complete if !is_failed => summary.complete += 1,
            ContractStatus::Partial => {
                summary.partial += 1;
                if is_failed {
                    summary.failed += 1;
                    summary.failed_shards.push(shard_id.clone());
                }
                summary.incomplete_shards.push(shard_id.clone());
                if summary.first_incomplete.is_none() {
                    summary.first_incomplete = Some(shard_id);
                    summary.first_incomplete_status = Some(if is_failed {
                        "failed".to_string()
                    } else {
                        "partial".to_string()
                    });
                }
            }
            ContractStatus::Complete => {
                summary.partial += 1;
                summary.failed += 1;
                summary.failed_shards.push(shard_id.clone());
                summary.incomplete_shards.push(shard_id.clone());
                if summary.first_incomplete.is_none() {
                    summary.first_incomplete = Some(shard_id);
                    summary.first_incomplete_status = Some("failed".to_string());
                }
            }
            ContractStatus::Missing => {
                summary.missing += 1;
                summary.incomplete_shards.push(shard_id.clone());
                if summary.first_incomplete.is_none() {
                    summary.first_incomplete = Some(shard_id);
                    summary.first_incomplete_status = Some("missing".to_string());
                }
            }
        }
    }
    summary
}

fn progress_status(dir: &Path) -> Option<String> {
    read_json(&dir.join("progress.json")).and_then(|value| {
        value
            .get("status")
            .and_then(|v| v.as_str())
            .map(ToString::to_string)
    })
}

fn summarize_worktree_inventory(value: &serde_json::Value) -> WorktreeSummary {
    let summary = value.get("summary").and_then(|v| v.as_object());
    let entries = value
        .get("entries")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    WorktreeSummary {
        candidate_count: summary
            .and_then(|s| s.get("candidate_count"))
            .and_then(|v| v.as_u64())
            .unwrap_or_default(),
        sibling_worktree_count: summary
            .and_then(|s| s.get("sibling_worktree_count"))
            .and_then(|v| v.as_u64())
            .unwrap_or_default(),
        dirty_candidate_count: summary
            .and_then(|s| s.get("dirty_candidate_count"))
            .and_then(|v| v.as_u64())
            .unwrap_or_default(),
        high_duplicate_risk_count: summary
            .and_then(|s| s.get("high_duplicate_risk_count"))
            .and_then(|v| v.as_u64())
            .unwrap_or_default(),
        current_repo_present: entries.iter().any(|entry| {
            entry
                .get("classification")
                .and_then(|v| v.as_str())
                .map(|classification| classification == "current_repo")
                .unwrap_or(false)
        }),
    }
}

fn summarize_model_context_inventory(value: &serde_json::Value) -> ModelContextInventorySummary {
    let summary = value.get("summary").and_then(|v| v.as_object());
    ModelContextInventorySummary {
        required_context_candidate_count: summary
            .and_then(|s| s.get("required_context_candidate_count"))
            .and_then(|v| v.as_u64())
            .unwrap_or_default(),
        required_context_text_model_candidate_count: summary
            .and_then(|s| s.get("required_context_text_model_candidate_count"))
            .and_then(|v| v.as_u64())
            .unwrap_or_default(),
        canonical_context_ok: summary
            .and_then(|s| s.get("canonical_context_ok"))
            .and_then(|v| v.as_bool())
            .unwrap_or(false),
        best_required_context_candidate_repo_id: summary
            .and_then(|s| s.get("best_required_context_candidate_repo_id"))
            .and_then(|v| v.as_str())
            .unwrap_or("none")
            .to_string(),
    }
}

fn contract_dir_status(dir: &Path) -> ContractStatus {
    let present = CONTRACT_FILES
        .iter()
        .filter(|file| dir.join(file).is_file())
        .count();
    if present == CONTRACT_FILES.len() {
        ContractStatus::Complete
    } else if present > 0 {
        ContractStatus::Partial
    } else {
        ContractStatus::Missing
    }
}

fn derive_next_existing_work(
    prompt_suite_exists: bool,
    plan_exists: bool,
    shards: &ShardSummary,
    merged: &ContractStatus,
    kv_fixture_logits_available: bool,
    next_bottleneck: &str,
    provider_reference_prompt_level_blocker: Option<&str>,
    heavy_long_context_enabled: bool,
) -> String {
    if !heavy_long_context_enabled && next_bottleneck == "missing_fp16_or_provider_reference" {
        return "large_model_provider_reference_deferred_by_mlx_route".to_string();
    }
    if next_bottleneck == "missing_fp16_or_provider_reference" {
        if let Some(blocker) = provider_reference_prompt_level_blocker {
            if blocker != "ready_for_70b_prompt_level_comparison" {
                return blocker.to_string();
            }
        }
    }
    if !heavy_long_context_enabled && is_kv_direct_work(next_bottleneck) {
        return "heavy_long_context_deferred_by_default".to_string();
    }
    if !heavy_long_context_enabled {
        return next_bottleneck.to_string();
    }
    if matches!(
        next_bottleneck,
        "resolve_qwen3_8b_mlx_model_assets_for_kv_direct"
    ) {
        return next_bottleneck.to_string();
    }
    if next_bottleneck == "resolve_qwen3_8b_128k_context_model_assets_for_kv_direct" {
        return next_bottleneck.to_string();
    }
    if !prompt_suite_exists {
        return "create_kv_direct_prompt_suite".to_string();
    }
    if !plan_exists {
        return "create_kv_direct_full_suite_run_plan".to_string();
    }
    if let Some(shard) = &shards.first_incomplete {
        if shards.first_incomplete_status.as_deref() == Some("failed") {
            return format!("repair_failed_kv_direct_shard:{shard}");
        }
        if shards.first_incomplete_status.as_deref() == Some("partial") {
            return format!("repair_partial_kv_direct_shard:{shard}");
        }
        return format!("continue_kv_direct_shard:{shard}");
    }
    if shards.total > 0 && *merged != ContractStatus::Complete {
        return "merge_completed_kv_direct_shards".to_string();
    }
    if *merged == ContractStatus::Complete && !kv_fixture_logits_available {
        return "feed_merged_kv_direct_bundle_to_falsifier".to_string();
    }
    next_bottleneck.to_string()
}

fn is_kv_direct_work(next_bottleneck: &str) -> bool {
    next_bottleneck.contains("kv_direct") || next_bottleneck.contains("qwen3_8b")
}

fn read_json(path: &Path) -> Option<serde_json::Value> {
    std::fs::read_to_string(path)
        .ok()
        .and_then(|s| serde_json::from_str::<serde_json::Value>(&s).ok())
}

fn artifact_all_axes_true(value: &Option<serde_json::Value>, axes: &[&str]) -> bool {
    value.as_ref().is_some_and(|artifact| {
        artifact_overall_pass_value(artifact)
            && axes
                .iter()
                .all(|axis| artifact_axis_true_value(artifact, axis))
    })
}

fn artifact_has_axes(value: &Option<serde_json::Value>, axes: &[&str]) -> bool {
    value.as_ref().is_some_and(|artifact| {
        let Some(pass_per_axis) = artifact
            .get("pass_per_axis")
            .and_then(|axes| axes.as_object())
        else {
            return false;
        };
        axes.iter().all(|axis| pass_per_axis.contains_key(*axis))
    })
}

fn artifact_overall_pass_value(value: &serde_json::Value) -> bool {
    value
        .get("overall_pass")
        .and_then(|v| v.as_bool())
        .unwrap_or(false)
}

fn artifact_axis_true_value(value: &serde_json::Value, axis: &str) -> bool {
    value
        .get("pass_per_axis")
        .and_then(|axes| axes.get(axis))
        .and_then(|v| v.as_bool())
        .unwrap_or(false)
}

fn measurement_string_value(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")?
        .get(key)?
        .get("value")
        .or_else(|| value.get("measurements")?.get(key))?
        .as_str()
        .map(ToString::to_string)
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    measurement_string_value(value, key)
}

fn measurement_bool_value(value: &serde_json::Value, key: &str) -> Option<bool> {
    value
        .get("measurements")?
        .get(key)?
        .get("value")
        .or_else(|| value.get("measurements")?.get(key))?
        .as_bool()
}

fn heavy_long_context_enabled() -> bool {
    std::env::var(HEAVY_LONG_CONTEXT_ENV)
        .ok()
        .is_some_and(|value| value == "1")
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

fn add_count_measurement(measurements: &mut BTreeMap<String, Measurement>, key: &str, value: u64) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(value)),
            unit: "count".to_string(),
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

fn add_label(measurements: &mut BTreeMap<String, Measurement>, key: &str, value: &str) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "label".to_string(),
        },
    );
}

fn add_json_measurement(
    measurements: &mut BTreeMap<String, Measurement>,
    key: &str,
    value: serde_json::Value,
) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value,
            unit: "object".to_string(),
        },
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn queue_summary_catches_duplicate_gap_ids() {
        let items = vec![
            QueueItem {
                order: Some(1),
                gap_id: Some("kv".to_string()),
                status: Some("completed".to_string()),
                witness: Some("a".to_string()),
                falsifier_or_gate: Some("F-A".to_string()),
            },
            QueueItem {
                order: Some(2),
                gap_id: Some("kv".to_string()),
                status: Some("pending".to_string()),
                witness: Some("b".to_string()),
                falsifier_or_gate: Some("F-B".to_string()),
            },
        ];
        let summary = summarize_queue(&items);
        assert_eq!(summary.total, 2);
        assert_eq!(summary.pending, 1);
        assert_eq!(summary.duplicate_gap_ids, 1);
        assert_eq!(summary.duplicate_orders, 0);
    }

    #[test]
    fn next_work_continues_first_incomplete_shard_before_merge() {
        let shards = ShardSummary {
            total: 4,
            complete: 0,
            partial: 0,
            failed: 0,
            missing: 4,
            first_incomplete: Some("shard_000_024".to_string()),
            first_incomplete_status: Some("missing".to_string()),
            incomplete_shards: vec!["shard_000_024".to_string()],
            failed_shards: vec![],
        };
        assert_eq!(
            derive_next_existing_work(
                true,
                true,
                &shards,
                &ContractStatus::Missing,
                false,
                "run_qwen3_8b_100_prompt_128k_reference_and_kv_direct_logits",
                None,
                true,
            ),
            "continue_kv_direct_shard:shard_000_024"
        );
    }

    #[test]
    fn next_work_honors_model_context_bottleneck_before_failed_shard() {
        let shards = ShardSummary {
            total: 4,
            complete: 0,
            partial: 1,
            failed: 1,
            missing: 3,
            first_incomplete: Some("shard_000_000".to_string()),
            first_incomplete_status: Some("failed".to_string()),
            incomplete_shards: vec!["shard_000_000".to_string()],
            failed_shards: vec!["shard_000_000".to_string()],
        };
        assert_eq!(
            derive_next_existing_work(
                true,
                true,
                &shards,
                &ContractStatus::Missing,
                false,
                "resolve_qwen3_8b_128k_context_model_assets_for_kv_direct",
                None,
                true,
            ),
            "resolve_qwen3_8b_128k_context_model_assets_for_kv_direct"
        );
    }

    #[test]
    fn next_work_skips_kv_shards_when_heavy_long_context_disabled() {
        let shards = ShardSummary {
            total: 4,
            complete: 0,
            partial: 1,
            failed: 1,
            missing: 3,
            first_incomplete: Some("shard_000_000".to_string()),
            first_incomplete_status: Some("failed".to_string()),
            incomplete_shards: vec!["shard_000_000".to_string()],
            failed_shards: vec!["shard_000_000".to_string()],
        };
        assert_eq!(
            derive_next_existing_work(
                true,
                true,
                &shards,
                &ContractStatus::Missing,
                false,
                "missing_fp16_or_provider_reference",
                None,
                false,
            ),
            "large_model_provider_reference_deferred_by_mlx_route"
        );
        assert_eq!(
            derive_next_existing_work(
                true,
                true,
                &shards,
                &ContractStatus::Missing,
                false,
                "resolve_qwen3_8b_128k_context_model_assets_for_kv_direct",
                None,
                false,
            ),
            "heavy_long_context_deferred_by_default"
        );
    }

    #[test]
    fn next_work_defers_provider_reference_when_heavy_context_is_off() {
        let shards = ShardSummary::default();
        assert_eq!(
            derive_next_existing_work(
                true,
                true,
                &shards,
                &ContractStatus::Missing,
                false,
                "missing_fp16_or_provider_reference",
                Some("missing_provider_reference_env"),
                false,
            ),
            "large_model_provider_reference_deferred_by_mlx_route"
        );
        assert_eq!(
            derive_next_existing_work(
                true,
                true,
                &shards,
                &ContractStatus::Missing,
                false,
                "missing_fp16_or_provider_reference",
                Some("missing_provider_reference_env"),
                true,
            ),
            "missing_provider_reference_env"
        );
    }

    #[test]
    fn already_mapped_work_includes_constructive_and_provider_rungs() {
        let report = build_report();
        let already_mapped_work = report
            .artifact
            .measurements
            .get("already_mapped_work")
            .expect("already_mapped_work measurement")
            .value
            .get("large_model_non_runtime_rungs")
            .expect("large_model_non_runtime_rungs object")
            .clone();

        assert!(already_mapped_work
            .get("coactivation_tile_prefetch")
            .is_some());
        assert!(already_mapped_work
            .get("proof_carrying_residency_lease")
            .is_some());
        assert!(already_mapped_work
            .get("cold_assembly_plan_70b_lite")
            .is_some());
        assert!(already_mapped_work
            .get("lattice_state_controller")
            .is_some());
        assert!(already_mapped_work
            .get("reasoning_state_continuity")
            .is_some());
        assert!(already_mapped_work.get("cold_miss_ledger").is_some());
        assert!(already_mapped_work.get("swiftlm_source_intake").is_some());
        assert!(already_mapped_work
            .get("meta_breakthrough_card_registry")
            .is_some());
        assert!(already_mapped_work
            .get("proof_carrying_route_card")
            .is_some());
        assert!(already_mapped_work
            .get("rust_route_kernel_model_check")
            .is_some());
        assert!(already_mapped_work
            .get("brain_route_card_multi_model")
            .is_some());
        assert!(already_mapped_work
            .get("kv_page_control_query_aware")
            .is_some());
        assert!(already_mapped_work
            .get("neural_control_card_ablation")
            .is_some());
        assert!(already_mapped_work.get("verifier_regret_ledger").is_some());
        assert!(already_mapped_work
            .get("route_scout_ssm_baseline")
            .is_some());
        assert!(already_mapped_work
            .get("two_stage_route_scout_abstain")
            .is_some());
        assert!(already_mapped_work
            .get("provider_reference_prompt_level_readiness")
            .is_some());
    }

    #[test]
    fn contract_dir_status_distinguishes_partial_outputs() {
        let dir =
            std::env::temp_dir().join(format!("epistemos_contract_dir_{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        assert_eq!(contract_dir_status(&dir), ContractStatus::Missing);
        std::fs::write(dir.join("manifest.json"), "{}").unwrap();
        assert_eq!(contract_dir_status(&dir), ContractStatus::Partial);
        for file in CONTRACT_FILES {
            std::fs::write(dir.join(file), "{}").unwrap();
        }
        assert_eq!(contract_dir_status(&dir), ContractStatus::Complete);
        let _ = std::fs::remove_dir_all(dir);
    }
}
