#![recursion_limit = "256"]

//! Architecture Pending Work Guard.
//!
//! This is the pre-loop duplicate-work check for the Capability Ceiling queue.
//! It reads the executable route queue plus the KV-Direct full-suite plan and
//! emits one artifact that answers:
//! "what is already mapped, what is partially done, and what exact work should
//! continue next without rebuilding something twice?"

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::{
    CACHE_POLICY_POLLUTION_AXES, CODEC_STAGE_LATENCY_AXES, COLDSTREAM_NO_HIDDEN_AUTHORITY_AXES,
    COLDSTREAM_VS_MMAP_AXES, COLD_PANIC_FALLBACK_AXES,
    LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_BY_MLX_ROUTE_AXES, METAL_IO_FEATURE_GATE_AXES,
    PRODUCT_ROUTE_REVIEW_AXES, PROVIDER_ROUTE_COPY_SOURCE_GUARD_AXES, SLAB_ARENA_COPY_COUNT_AXES,
    SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_AXES,
    SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_AXES,
    SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_AXES,
    SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_AXES, SPARSE_ROUTE_NO_HIDDEN_AUTHORITY_AXES,
    SSD_WEAR_BUDGET_AXES, TRANSPORT_CANCELLATION_AXES, TRANSPORT_TRACE_ANSWER_PACKET_AXES,
};
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
const BUDGETED_UNCERTAINTY_ESCALATOR_PATH: &str =
    "artifacts/falsifiers/budgeted_uncertainty_escalator/result.json";
const SPARSE_WAKE_PROPOSAL_BUDGET_PATH: &str =
    "artifacts/falsifiers/sparse_wake_proposal_budget/result.json";
const VERIFIER_BUDGET_AUCTION_PATH: &str =
    "artifacts/falsifiers/verifier_budget_auction/result.json";
const KV_PAGE_SKETCH_INDEX_PATH: &str = "artifacts/falsifiers/kv_page_sketch_index/result.json";
const KV_PAGE_BLOOM_SKETCH_COVERAGE_PATH: &str =
    "artifacts/falsifiers/kv_page_bloom_sketch_coverage/result.json";
const QUERY_AWARE_KV_SELECTOR_PATH: &str =
    "artifacts/falsifiers/query_aware_kv_selector/result.json";
const SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET_PATH: &str =
    "artifacts/falsifiers/sparse_wake_certificate_answer_packet/result.json";
const LAYER_KV_JOINT_LEASE_PATH: &str = "artifacts/falsifiers/layer_kv_joint_lease/result.json";
const CONSTRUCTION_SEARCH_TOURNAMENT_PATH: &str =
    "artifacts/falsifiers/construction_search_tournament/result.json";
const ROUTE_DISTILLATION_TOURNAMENT_PATH: &str =
    "artifacts/falsifiers/route_distillation_tournament/result.json";
const PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK_PATH: &str =
    "artifacts/falsifiers/proof_search_signal_route_feedback/result.json";
const PROOF_PRESSURE_SIGNAL_PATH: &str = "artifacts/falsifiers/proof_pressure_signal/result.json";
const VERIFIER_REGRET_FAST_WEIGHTS_PATH: &str =
    "artifacts/falsifiers/verifier_regret_fast_weights/result.json";
const FAST_WEIGHT_QUARANTINE_PATH: &str = "artifacts/falsifiers/fast_weight_quarantine/result.json";
const DEPTH_LEASE_CHECKPOINT_PATH: &str = "artifacts/falsifiers/depth_lease_checkpoint/result.json";
const SHADOW_WAKE_ORACLE_PATH: &str = "artifacts/falsifiers/shadow_wake_oracle/result.json";
const ABLATION_SHADOW_RUN_PATH: &str = "artifacts/falsifiers/ablation_shadow_run/result.json";
const AXIOM_AXIOMATIC_SOURCE_DISTINCTION_PATH: &str =
    "artifacts/falsifiers/axiom_axiomatic_source_distinction/result.json";
const SPARSE_ROUTE_NO_HIDDEN_AUTHORITY_PATH: &str =
    "artifacts/falsifiers/sparse_route_no_hidden_authority/result.json";
const COLDSTREAM_NO_HIDDEN_AUTHORITY_PATH: &str =
    "artifacts/falsifiers/coldstream_no_hidden_authority/result.json";
const LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_BY_MLX_ROUTE_PATH: &str =
    "artifacts/falsifiers/large_model_provider_reference_deferred_by_mlx_route/result.json";
const PROVIDER_ROUTE_COPY_SOURCE_GUARD_PATH: &str =
    "artifacts/falsifiers/provider_route_copy_source_guard/result.json";
const TRANSPORT_TRACE_ANSWER_PACKET_PATH: &str =
    "artifacts/falsifiers/transport_trace_answer_packet/result.json";
const SSD_WEAR_BUDGET_PATH: &str = "artifacts/falsifiers/ssd_wear_budget/result.json";
const COLDSTREAM_VS_MMAP_PATH: &str = "artifacts/falsifiers/coldstream_vs_mmap/result.json";
const SLAB_ARENA_COPY_COUNT_PATH: &str = "artifacts/falsifiers/slab_arena_copy_count/result.json";
const METAL_IO_FEATURE_GATE_PATH: &str = "artifacts/falsifiers/metal_io_feature_gate/result.json";
const CODEC_STAGE_LATENCY_PATH: &str = "artifacts/falsifiers/codec_stage_latency/result.json";
const TRANSPORT_CANCELLATION_PATH: &str = "artifacts/falsifiers/transport_cancellation/result.json";
const CACHE_POLICY_POLLUTION_PATH: &str = "artifacts/falsifiers/cache_policy_pollution/result.json";
const COLD_PANIC_FALLBACK_PATH: &str = "artifacts/falsifiers/cold_panic_fallback/result.json";
const PRODUCT_ROUTE_REVIEW_PATH: &str = "artifacts/falsifiers/product_route_review/result.json";
const SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_safety_plan/result.json";
const SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_dry_run_witness/result.json";
const SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_owner_approved_probe/result.json";
const SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_abortable_runtime_probe/result.json";
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
const BUDGETED_UNCERTAINTY_ESCALATOR_AXES: &[&str] = &[
    "upstream_two_stage_route_scout_abstain_pass",
    "budgeted_escalator_fixture_present",
    "training_split_bound",
    "held_out_split_bound",
    "task_signatures_bound",
    "mission_ids_bound",
    "scout_refs_bound",
    "calibration_set_bound",
    "coverage_target_bound",
    "uncertainty_bound",
    "ood_signal_bound",
    "byte_budget_bound",
    "latency_budget_bound",
    "verifier_coverage_bound",
    "decision_labels_bound",
    "escalation_target_bound",
    "abstain_reason_bound",
    "high_uncertainty_escalates",
    "budget_exhaustion_escalates",
    "latency_exhaustion_escalates",
    "missing_calibration_escalates",
    "ood_escalates",
    "coverage_shortfall_escalates",
    "verifier_coverage_shortfall_escalates",
    "cheap_route_allowed_when_calibrated_in_budget",
    "decision_success_beats_cheap_baseline",
    "decision_success_beats_always_escalate",
    "wrong_cheap_route_rejected",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "route_authority_shadow_only",
    "no_hidden_route_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "live_policy_not_mutated",
    "escalator_address_deterministic",
    "duplicate_task_rejected",
    "missing_calibration_rejected",
    "missing_scout_ref_rejected",
    "missing_coverage_target_rejected",
    "missing_budget_rejected",
    "missing_latency_budget_rejected",
    "missing_escalation_target_rejected",
    "missing_abstain_reason_rejected",
    "high_uncertainty_allowed_rejected",
    "missing_calibration_allowed_rejected",
    "ood_allowed_rejected",
    "byte_budget_allowed_rejected",
    "latency_budget_allowed_rejected",
    "coverage_shortfall_allowed_rejected",
    "verifier_coverage_shortfall_allowed_rejected",
    "cheap_baseline_unbeaten_rejected",
    "always_escalate_baseline_unbeaten_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_live_authority_rejected",
    "live_policy_mutation_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_route_rejected",
    "escalator_over_budget_rejected",
    "no_runtime_bytes_loaded",
    "training_task_count",
    "held_out_task_count",
    "escalation_case_count",
    "allowed_case_count",
    "high_uncertainty_case_count",
    "budget_exhaustion_case_count",
    "latency_exhaustion_case_count",
    "missing_calibration_case_count",
    "ood_case_count",
    "coverage_shortfall_case_count",
    "verifier_coverage_shortfall_case_count",
    "escalator_decision_success_bps",
    "cheap_baseline_success_bps",
    "always_escalate_success_bps",
    "false_cheap_route_count",
    "false_cheap_route_rejected_count",
    "max_escalator_active_bytes",
    "escalator_address",
];
const SPARSE_WAKE_PROPOSAL_BUDGET_AXES: &[&str] = &[
    "upstream_budgeted_uncertainty_escalator_pass",
    "sparse_wake_fixture_present",
    "training_split_bound",
    "held_out_split_bound",
    "proposal_ids_bound",
    "mission_ids_bound",
    "scout_refs_bound",
    "escalator_refs_bound",
    "selected_units_bound",
    "rejected_units_bound",
    "unit_addresses_bound",
    "unit_kinds_bound",
    "unit_budget_fields_bound",
    "fallback_route_bound",
    "uncertainty_bound",
    "verifier_need_bound",
    "quality_delta_positive",
    "verifier_delta_positive",
    "hot_bytes_within_budget",
    "kv_bytes_within_budget",
    "cold_io_within_budget",
    "latency_within_budget",
    "byte_budget_accounting_bound",
    "reject_reasons_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "route_authority_shadow_only",
    "no_hidden_route_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "live_policy_not_mutated",
    "sparse_wake_address_deterministic",
    "proposal_success_beats_wake_all_baseline",
    "proposal_success_beats_static_baseline",
    "proposal_success_beats_qwen_everything_baseline",
    "wrong_wake_rejected",
    "duplicate_proposal_rejected",
    "missing_selected_unit_rejected",
    "missing_rejected_unit_rejected",
    "missing_uas_address_rejected",
    "missing_budget_rejected",
    "over_hot_budget_rejected",
    "over_kv_budget_rejected",
    "over_cold_io_budget_rejected",
    "over_latency_budget_rejected",
    "missing_fallback_rejected",
    "missing_uncertainty_rejected",
    "missing_verifier_need_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_live_authority_rejected",
    "live_policy_mutation_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_route_rejected",
    "proposal_over_metadata_budget_rejected",
    "no_runtime_bytes_loaded",
    "training_proposal_count",
    "held_out_proposal_count",
    "selected_unit_count",
    "rejected_unit_count",
    "max_hot_bytes",
    "max_kv_bytes",
    "max_cold_io_bytes",
    "max_latency_ms",
    "sparse_wake_success_bps",
    "wake_all_baseline_success_bps",
    "static_baseline_success_bps",
    "qwen_everything_baseline_success_bps",
    "wrong_wake_count",
    "wrong_wake_rejected_count",
    "max_proposal_metadata_bytes",
    "sparse_wake_address",
];
const VERIFIER_BUDGET_AUCTION_AXES: &[&str] = &[
    "upstream_sparse_wake_proposal_budget_pass",
    "verifier_budget_auction_fixture_present",
    "training_split_bound",
    "held_out_split_bound",
    "auction_ids_bound",
    "mission_ids_bound",
    "sparse_wake_refs_bound",
    "candidates_bound",
    "selected_bundle_bound",
    "rejected_bundle_bound",
    "uas_addresses_bound",
    "unit_kinds_bound",
    "evidence_refs_bound",
    "compatibility_fences_bound",
    "budget_vector_bound",
    "verifier_need_bound",
    "fallback_bound",
    "abstain_reason_bound",
    "selected_hot_bytes_within_budget",
    "selected_kv_bytes_within_budget",
    "selected_cold_io_within_budget",
    "selected_latency_within_budget",
    "privacy_risk_within_budget",
    "interference_risk_within_budget",
    "rollback_cost_within_budget",
    "verifier_coverage_bound",
    "selected_bid_scores_positive",
    "expected_selection_bound",
    "rejected_bundle_reasons_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "route_authority_shadow_only",
    "no_hidden_route_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "live_policy_not_mutated",
    "auction_address_deterministic",
    "auction_success_beats_greedy_bytes_baseline",
    "auction_success_beats_max_quality_baseline",
    "auction_success_beats_wake_all_baseline",
    "over_budget_bundle_rejected",
    "low_verifier_bundle_rejected",
    "privacy_risk_bundle_rejected",
    "latency_bundle_rejected",
    "interference_bundle_rejected",
    "rollback_cost_bundle_rejected",
    "duplicate_round_rejected",
    "missing_candidate_rejected",
    "missing_selected_bundle_rejected",
    "missing_rejected_bundle_rejected",
    "missing_uas_address_rejected",
    "missing_budget_rejected",
    "over_hot_budget_rejected",
    "over_kv_budget_rejected",
    "over_cold_io_budget_rejected",
    "over_latency_budget_rejected",
    "over_privacy_budget_rejected",
    "over_interference_budget_rejected",
    "over_rollback_budget_rejected",
    "weak_verifier_coverage_rejected",
    "weak_bid_score_rejected",
    "missing_verifier_need_rejected",
    "missing_fallback_rejected",
    "missing_abstain_reason_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_live_authority_rejected",
    "live_policy_mutation_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_route_rejected",
    "auction_over_metadata_budget_rejected",
    "no_runtime_bytes_loaded",
    "training_round_count",
    "held_out_round_count",
    "candidate_count",
    "selected_bundle_unit_count",
    "rejected_bundle_unit_count",
    "max_selected_hot_bytes",
    "max_selected_kv_bytes",
    "max_selected_cold_io_bytes",
    "max_selected_latency_ms",
    "min_selected_verifier_coverage_bps",
    "auction_success_bps",
    "greedy_bytes_baseline_success_bps",
    "max_quality_baseline_success_bps",
    "wake_all_baseline_success_bps",
    "over_budget_reject_count",
    "low_verifier_reject_count",
    "max_auction_metadata_bytes",
    "auction_address",
];
const KV_PAGE_SKETCH_INDEX_AXES: &[&str] = &[
    "upstream_verifier_budget_auction_pass",
    "kv_page_sketch_index_fixture_present",
    "training_split_bound",
    "held_out_split_bound",
    "index_ids_bound",
    "model_ids_bound",
    "tokenizer_ids_bound",
    "upstream_auction_ref_bound",
    "page_ids_bound",
    "uas_page_addresses_bound",
    "page_digests_bound",
    "byte_counts_bound",
    "min_key_sketch_bound",
    "max_key_sketch_bound",
    "sketch_dimension_bound",
    "sketch_order_bound",
    "semantic_tags_bound",
    "recency_bound",
    "hit_counts_bound",
    "miss_counts_bound",
    "compatibility_fences_bound",
    "privacy_classes_bound",
    "required_evidence_bound",
    "false_negative_policy_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "route_authority_shadow_only",
    "no_hidden_chain",
    "no_hidden_cloud",
    "live_policy_not_mutated",
    "sketch_index_address_deterministic",
    "required_evidence_coverage_beats_recency_baseline",
    "required_evidence_coverage_beats_tagless_baseline",
    "required_evidence_coverage_beats_file_order_baseline",
    "duplicate_index_rejected",
    "duplicate_page_rejected",
    "missing_uas_address_rejected",
    "missing_digest_rejected",
    "zero_byte_count_rejected",
    "oversized_page_rejected",
    "missing_min_sketch_rejected",
    "missing_max_sketch_rejected",
    "sketch_dimension_mismatch_rejected",
    "sketch_order_rejected",
    "missing_semantic_tag_rejected",
    "missing_hit_count_rejected",
    "missing_miss_count_rejected",
    "missing_compatibility_fence_rejected",
    "incompatible_fence_rejected",
    "stale_page_rejected",
    "invalid_privacy_class_rejected",
    "missing_required_evidence_rejected",
    "required_evidence_false_negative_rejected",
    "missing_false_negative_policy_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_live_authority_rejected",
    "live_policy_mutation_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "index_metadata_budget_rejected",
    "unbeaten_baseline_rejected",
    "no_runtime_bytes_loaded",
    "sketch_index_count",
    "page_count",
    "training_page_count",
    "held_out_page_count",
    "required_evidence_page_count",
    "semantic_tag_count",
    "total_hit_count",
    "total_miss_count",
    "max_page_byte_count",
    "max_index_metadata_bytes",
    "sketch_dimension",
    "required_evidence_coverage_bps",
    "sketch_index_address",
];
const KV_PAGE_BLOOM_SKETCH_COVERAGE_AXES: &[&str] = &[
    "upstream_kv_page_sketch_index_pass",
    "kv_page_bloom_sketch_fixture_present",
    "training_split_bound",
    "held_out_split_bound",
    "sketch_ids_bound",
    "source_index_ref_bound",
    "source_page_refs_bound",
    "page_candidates_bound",
    "page_ids_bound",
    "uas_page_addresses_bound",
    "page_digests_bound",
    "compatibility_fences_bound",
    "feature_hashes_bound",
    "feature_hash_range_bound",
    "false_positive_budget_bound",
    "false_negative_policy_bound",
    "privacy_classes_bound",
    "required_evidence_bound",
    "proof_critical_filter_disabled",
    "privacy_critical_filter_disabled",
    "over_include_allowed_bound",
    "required_evidence_coverage_bound",
    "required_evidence_coverage_beats_hash_only_baseline",
    "required_evidence_coverage_beats_recency_baseline",
    "required_evidence_coverage_beats_tagless_baseline",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "route_authority_shadow_only",
    "no_hidden_chain",
    "no_hidden_cloud",
    "live_policy_not_mutated",
    "bloom_sketch_address_deterministic",
    "duplicate_sketch_rejected",
    "duplicate_page_candidate_rejected",
    "missing_source_index_rejected",
    "missing_source_page_ref_rejected",
    "missing_page_candidate_rejected",
    "missing_uas_address_rejected",
    "missing_digest_rejected",
    "missing_feature_hash_rejected",
    "feature_hash_out_of_range_rejected",
    "missing_compatibility_fence_rejected",
    "incompatible_fence_rejected",
    "missing_false_positive_budget_rejected",
    "false_positive_budget_exceeded_rejected",
    "missing_false_negative_policy_rejected",
    "required_evidence_false_negative_rejected",
    "proof_critical_negative_filter_rejected",
    "privacy_critical_negative_filter_rejected",
    "missing_required_evidence_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_live_authority_rejected",
    "live_policy_mutation_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "invalid_privacy_class_rejected",
    "metadata_budget_rejected",
    "unbeaten_baseline_rejected",
    "no_runtime_bytes_loaded",
    "bloom_sketch_count",
    "page_candidate_count",
    "training_candidate_count",
    "held_out_candidate_count",
    "required_evidence_candidate_count",
    "proof_critical_candidate_count",
    "privacy_critical_candidate_count",
    "overincluded_candidate_count",
    "bloom_bit_count",
    "hash_function_count",
    "required_evidence_coverage_bps",
    "hash_only_baseline_coverage_bps",
    "recency_baseline_coverage_bps",
    "tagless_baseline_coverage_bps",
    "max_false_positive_budget_bps",
    "max_bloom_metadata_bytes",
    "bloom_sketch_address",
];
const QUERY_AWARE_KV_SELECTOR_AXES: &[&str] = &[
    "upstream_kv_page_sketch_index_pass",
    "upstream_kv_page_bloom_sketch_coverage_pass",
    "query_aware_selector_fixture_present",
    "training_split_bound",
    "held_out_split_bound",
    "selector_ids_bound",
    "mission_ids_bound",
    "query_signatures_bound",
    "model_ids_bound",
    "tokenizer_ids_bound",
    "upstream_refs_bound",
    "page_candidates_bound",
    "page_ids_bound",
    "uas_page_addresses_bound",
    "page_digests_bound",
    "source_index_refs_bound",
    "bloom_refs_bound",
    "compatibility_fences_bound",
    "semantic_tags_bound",
    "query_match_signal_bound",
    "evidence_utility_signal_bound",
    "verifier_utility_signal_bound",
    "recency_bound",
    "file_order_bound",
    "active_bytes_bound",
    "restore_latency_bound",
    "privacy_classes_bound",
    "required_evidence_bound",
    "selected_pages_bound",
    "selected_pages_in_bloom_prefilter",
    "selected_pages_fit_active_byte_budget",
    "selected_pages_fit_latency_budget",
    "false_negative_policy_bound",
    "quality_floor_bound",
    "verifier_floor_bound",
    "query_aware_beats_recency_baseline",
    "query_aware_beats_random_baseline",
    "query_aware_beats_file_order_baseline",
    "query_aware_beats_bloom_only_baseline",
    "quality_delta_positive",
    "verifier_delta_positive",
    "latency_delta_positive",
    "active_byte_delta_positive",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "route_authority_shadow_only",
    "no_hidden_chain",
    "no_hidden_cloud",
    "live_policy_not_mutated",
    "query_selector_address_deterministic",
    "duplicate_selector_rejected",
    "duplicate_page_rejected",
    "missing_query_rejected",
    "missing_selected_page_rejected",
    "unknown_selected_page_rejected",
    "unfiltered_page_selected_rejected",
    "stale_page_rejected",
    "incompatible_fence_rejected",
    "missing_digest_rejected",
    "missing_uas_address_rejected",
    "missing_bloom_ref_rejected",
    "missing_required_evidence_rejected",
    "required_evidence_false_negative_rejected",
    "missing_false_negative_policy_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_live_authority_rejected",
    "live_policy_mutation_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "invalid_privacy_class_rejected",
    "over_budget_selection_rejected",
    "over_latency_selection_rejected",
    "verifier_bypass_rejected",
    "low_quality_selection_rejected",
    "metadata_budget_rejected",
    "unbeaten_baseline_rejected",
    "no_runtime_bytes_loaded",
    "selector_count",
    "page_candidate_count",
    "training_candidate_count",
    "held_out_candidate_count",
    "selected_page_count",
    "required_evidence_page_count",
    "bloom_selected_candidate_count",
    "max_selected_active_bytes",
    "max_selected_latency_ms",
    "min_selected_quality_bps",
    "min_selected_verifier_bps",
    "query_selector_success_bps",
    "recency_baseline_success_bps",
    "random_baseline_success_bps",
    "file_order_baseline_success_bps",
    "bloom_only_baseline_success_bps",
    "max_selector_metadata_bytes",
    "query_selector_address",
];
const SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET_AXES: &[&str] = &[
    "upstream_sparse_wake_proposal_budget_pass",
    "upstream_verifier_budget_auction_pass",
    "upstream_query_aware_kv_selector_pass",
    "sparse_wake_certificate_fixture_present",
    "certificate_ids_bound",
    "mission_ids_bound",
    "answer_packet_refs_bound",
    "upstream_refs_bound",
    "route_card_refs_bound",
    "selected_units_bound",
    "uas_addresses_bound",
    "selected_reasons_bound",
    "verifier_results_bound",
    "citation_results_bound",
    "test_results_bound",
    "trace_refs_bound",
    "compatibility_fences_bound",
    "privacy_classes_bound",
    "answer_packet_required_fields_bound",
    "fallback_bound",
    "rollback_bound",
    "run_event_log_bound",
    "route_authority_shadow_only",
    "live_route_not_promoted",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "sparse_wake_certificate_address_deterministic",
    "selected_units_fit_hot_budget",
    "selected_units_fit_kv_budget",
    "selected_units_fit_cold_budget",
    "certificate_latency_bound",
    "uncertainty_bound",
    "verifier_floor_bound",
    "citation_floor_bound",
    "test_floor_bound",
    "certificate_beats_proposal_only_baseline",
    "certificate_beats_route_only_baseline",
    "certificate_beats_hidden_answer_baseline",
    "certificate_metadata_bound",
    "duplicate_certificate_rejected",
    "duplicate_unit_rejected",
    "missing_selected_unit_rejected",
    "unknown_selected_unit_rejected",
    "missing_verifier_result_rejected",
    "missing_citation_result_rejected",
    "missing_test_result_rejected",
    "missing_trace_ref_rejected",
    "missing_answer_packet_field_rejected",
    "stale_unit_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_class_rejected",
    "over_hot_budget_rejected",
    "over_kv_budget_rejected",
    "over_cold_budget_rejected",
    "over_latency_rejected",
    "uncertainty_too_high_rejected",
    "verifier_bypass_rejected",
    "citation_bypass_rejected",
    "test_bypass_rejected",
    "missing_fallback_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "hidden_live_authority_rejected",
    "live_route_promotion_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "metadata_budget_rejected",
    "unbeaten_baseline_rejected",
    "certificate_count",
    "selected_unit_count",
    "kv_unit_count",
    "verifier_unit_count",
    "citation_unit_count",
    "test_unit_count",
    "max_hot_bytes",
    "max_kv_bytes",
    "max_cold_bytes",
    "max_latency_ms",
    "max_uncertainty_bps",
    "min_verifier_bps",
    "min_citation_bps",
    "min_test_bps",
    "certificate_success_bps",
    "proposal_only_baseline_bps",
    "route_only_baseline_bps",
    "hidden_answer_baseline_bps",
    "max_certificate_metadata_bytes",
    "sparse_wake_certificate_address",
];
const LAYER_KV_JOINT_LEASE_AXES: &[&str] = &[
    "upstream_sparse_wake_certificate_answer_packet_pass",
    "layer_kv_joint_lease_fixture_present",
    "lease_ids_bound",
    "mission_ids_bound",
    "answer_packet_refs_bound",
    "upstream_certificate_refs_bound",
    "route_card_refs_bound",
    "joint_decision_refs_bound",
    "depth_plans_bound",
    "kv_page_choices_bound",
    "depth_kv_coupling_bound",
    "checkpoint_refs_bound",
    "compatibility_fences_bound",
    "privacy_classes_bound",
    "attention_error_bound",
    "verifier_margin_bound",
    "full_depth_fallback_bound",
    "answer_packet_required_fields_bound",
    "fallback_bound",
    "rollback_bound",
    "run_event_log_bound",
    "route_authority_shadow_only",
    "live_route_not_promoted",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "layer_kv_joint_lease_address_deterministic",
    "selected_pages_fit_hot_budget",
    "selected_pages_fit_kv_budget",
    "selected_pages_fit_cold_budget",
    "joint_latency_bound",
    "extra_layer_bound",
    "lease_beats_depth_only_baseline",
    "lease_beats_kv_only_baseline",
    "lease_beats_independent_greedy_baseline",
    "shallow_wrong_page_negative_beaten",
    "lease_metadata_bound",
    "duplicate_lease_rejected",
    "duplicate_kv_page_rejected",
    "missing_depth_plan_rejected",
    "missing_selected_kv_page_rejected",
    "missing_joint_decision_rejected",
    "uncoupled_depth_kv_rejected",
    "stale_kv_page_rejected",
    "incompatible_depth_fence_rejected",
    "incompatible_page_fence_rejected",
    "invalid_privacy_class_rejected",
    "over_hot_budget_rejected",
    "over_kv_budget_rejected",
    "over_cold_budget_rejected",
    "over_latency_rejected",
    "over_extra_layers_rejected",
    "attention_error_too_high_rejected",
    "verifier_margin_too_low_rejected",
    "missing_full_depth_fallback_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_field_rejected",
    "hidden_live_authority_rejected",
    "live_route_promotion_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "metadata_budget_rejected",
    "shallow_wrong_page_negative_rejected",
    "unbeaten_baseline_rejected",
    "lease_count",
    "selected_kv_page_count",
    "required_evidence_page_count",
    "depth_checkpoint_count",
    "max_extra_layers",
    "max_hot_bytes",
    "max_kv_bytes",
    "max_cold_bytes",
    "max_latency_ms",
    "max_attention_error_bps",
    "min_verifier_margin_bps",
    "min_page_utility_bps",
    "lease_success_bps",
    "depth_only_baseline_bps",
    "kv_only_baseline_bps",
    "independent_greedy_baseline_bps",
    "shallow_wrong_page_baseline_bps",
    "max_lease_metadata_bytes",
    "layer_kv_joint_lease_address",
];
const CONSTRUCTION_SEARCH_TOURNAMENT_AXES: &[&str] = &[
    "upstream_layer_kv_joint_lease_pass",
    "construction_search_tournament_fixture_present",
    "tournament_ids_bound",
    "mission_families_bound",
    "generation_policy_bound",
    "repair_policy_bound",
    "scoring_policy_bound",
    "selection_policy_bound",
    "random_seed_bound",
    "candidate_genomes_bound",
    "generation_trace_refs_bound",
    "repair_trace_refs_bound",
    "score_trace_refs_bound",
    "selected_winners_bound",
    "held_out_split_bound",
    "diversity_buckets_bound",
    "exploration_budget_bound",
    "fixed_budget_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "route_authority_shadow_only",
    "live_route_not_promoted",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "construction_search_tournament_address_deterministic",
    "winners_fit_hot_budget",
    "winners_fit_kv_budget",
    "winners_fit_cold_budget",
    "winner_latency_bound",
    "repair_failure_rate_bound",
    "tournament_beats_random_generation_baseline",
    "tournament_beats_greedy_baseline",
    "tournament_beats_unrepaired_baseline",
    "held_out_win_rate_bound",
    "metadata_bound",
    "duplicate_tournament_rejected",
    "duplicate_candidate_rejected",
    "missing_generation_policy_rejected",
    "missing_repair_policy_rejected",
    "missing_scoring_policy_rejected",
    "missing_selection_policy_rejected",
    "missing_candidate_rejected",
    "unrepaired_candidate_selected_rejected",
    "invalid_candidate_selected_rejected",
    "over_budget_candidate_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_live_authority_rejected",
    "live_route_promotion_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "metadata_budget_rejected",
    "random_baseline_unbeaten_rejected",
    "greedy_baseline_unbeaten_rejected",
    "unrepaired_baseline_unbeaten_rejected",
    "insufficient_diversity_rejected",
    "exploration_budget_exceeded_rejected",
    "tournament_count",
    "candidate_count",
    "repaired_candidate_count",
    "selected_winner_count",
    "held_out_case_count",
    "diversity_bucket_count",
    "repair_failure_count",
    "max_generation_budget",
    "max_compute_steps",
    "max_exploration_budget",
    "max_hot_bytes",
    "max_kv_bytes",
    "max_cold_bytes",
    "max_latency_ms",
    "max_repair_failure_bps",
    "tournament_success_bps",
    "held_out_success_bps",
    "random_generation_baseline_bps",
    "greedy_baseline_bps",
    "unrepaired_baseline_bps",
    "max_tournament_metadata_bytes",
    "construction_search_tournament_address",
];
const ROUTE_DISTILLATION_TOURNAMENT_AXES: &[&str] = &[
    "upstream_construction_search_tournament_pass",
    "route_distillation_tournament_fixture_present",
    "tournament_ids_bound",
    "policy_refs_bound",
    "small_scout_refs_bound",
    "trace_labels_bound",
    "mission_ids_bound",
    "expensive_trace_refs_bound",
    "oracle_label_refs_bound",
    "route_labels_bound",
    "scout_feature_refs_bound",
    "train_split_bound",
    "held_out_split_bound",
    "full_wake_traces_bound",
    "proof_oracle_traces_bound",
    "compiler_failure_traces_bound",
    "failed_attempt_traces_bound",
    "source_kind_diversity_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "route_authority_shadow_only",
    "live_policy_not_promoted",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "route_distillation_tournament_address_deterministic",
    "held_out_success_bound",
    "label_agreement_bound",
    "calibration_error_bound",
    "trace_token_budget_bound",
    "metadata_bound",
    "beats_direct_heuristic_baseline",
    "beats_pre_distill_scout_baseline",
    "beats_construction_winner_baseline",
    "duplicate_tournament_rejected",
    "duplicate_trace_label_rejected",
    "missing_expensive_trace_rejected",
    "missing_oracle_label_rejected",
    "missing_route_label_rejected",
    "missing_scout_feature_rejected",
    "invalid_split_rejected",
    "missing_held_out_split_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_live_authority_rejected",
    "live_policy_promotion_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "direct_heuristic_unbeaten_rejected",
    "pre_distill_scout_unbeaten_rejected",
    "construction_winner_unbeaten_rejected",
    "label_agreement_too_low_rejected",
    "calibration_error_too_high_rejected",
    "source_kind_diversity_missing_rejected",
    "metadata_budget_rejected",
    "trace_token_budget_rejected",
    "tournament_count",
    "trace_label_count",
    "train_case_count",
    "held_out_case_count",
    "source_kind_count",
    "max_trace_tokens",
    "max_tournament_metadata_bytes",
    "held_out_success_bps",
    "label_agreement_bps",
    "calibration_error_bps",
    "direct_heuristic_baseline_bps",
    "pre_distill_scout_baseline_bps",
    "construction_winner_baseline_bps",
    "route_distillation_tournament_address",
];
const PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK_AXES: &[&str] = &[
    "upstream_route_distillation_tournament_pass",
    "proof_search_signal_fixture_present",
    "fixture_ids_bound",
    "feature_schema_refs_bound",
    "shadow_policy_refs_bound",
    "signal_ids_bound",
    "claim_ids_bound",
    "mission_ids_bound",
    "premise_refs_bound",
    "proof_state_hashes_bound",
    "tactic_trace_refs_bound",
    "verifier_status_bound",
    "pass_status_bound",
    "fail_status_bound",
    "repair_status_bound",
    "abstain_status_bound",
    "failure_signatures_bound",
    "repair_hints_bound",
    "route_feature_labels_bound",
    "test_refs_bound",
    "citation_refs_bound",
    "scope_rex_refs_bound",
    "sovereign_gate_refs_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "route_authority_shadow_only",
    "live_policy_not_promoted",
    "proof_feedback_not_hidden_truth",
    "verifier_not_bypassed",
    "tests_not_bypassed",
    "citations_not_bypassed",
    "scope_rex_not_bypassed",
    "sovereign_gate_not_bypassed",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "proof_search_signal_address_deterministic",
    "held_out_route_success_bound",
    "verifier_alignment_bound",
    "answer_packet_coverage_bound",
    "calibration_error_bound",
    "proof_token_budget_bound",
    "metadata_bound",
    "beats_proof_feature_baseline",
    "beats_route_distillation_only_baseline",
    "beats_no_proof_feedback_baseline",
    "duplicate_fixture_rejected",
    "duplicate_signal_rejected",
    "missing_premise_rejected",
    "missing_proof_state_rejected",
    "missing_tactic_trace_rejected",
    "missing_verifier_status_rejected",
    "invalid_verifier_status_rejected",
    "missing_failure_signature_rejected",
    "missing_repair_hint_rejected",
    "missing_route_feature_rejected",
    "missing_test_ref_rejected",
    "missing_citation_ref_rejected",
    "missing_scope_rex_rejected",
    "missing_sovereign_gate_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_truth_authority_rejected",
    "verifier_bypass_rejected",
    "test_bypass_rejected",
    "citation_bypass_rejected",
    "scope_rex_bypass_rejected",
    "sovereign_gate_bypass_rejected",
    "hidden_live_authority_rejected",
    "live_policy_promotion_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "proof_feature_baseline_unbeaten_rejected",
    "route_distillation_baseline_unbeaten_rejected",
    "no_proof_feedback_baseline_unbeaten_rejected",
    "calibration_error_too_high_rejected",
    "status_diversity_missing_rejected",
    "route_feature_diversity_missing_rejected",
    "metadata_budget_rejected",
    "proof_token_budget_rejected",
    "fixture_count",
    "signal_count",
    "train_case_count",
    "held_out_case_count",
    "status_kind_count",
    "route_feature_kind_count",
    "max_proof_tokens",
    "max_signal_metadata_bytes",
    "held_out_route_success_bps",
    "verifier_alignment_bps",
    "answer_packet_coverage_bps",
    "calibration_error_bps",
    "proof_feature_baseline_bps",
    "route_distillation_only_baseline_bps",
    "no_proof_feedback_baseline_bps",
    "proof_search_signal_address",
];
const PROOF_PRESSURE_SIGNAL_AXES: &[&str] = &[
    "upstream_proof_search_signal_route_feedback_pass",
    "proof_pressure_signal_fixture_present",
    "fixture_ids_bound",
    "pressure_schema_refs_bound",
    "shadow_policy_refs_bound",
    "pressure_signal_ids_bound",
    "claim_refs_bound",
    "mission_ids_bound",
    "proof_search_signal_refs_bound",
    "statement_preservation_scores_bound",
    "compiler_error_kinds_bound",
    "tactic_state_entropy_bound",
    "missing_premise_refs_bound",
    "verified_proof_neighbors_bound",
    "failed_attempt_memory_refs_bound",
    "route_pressure_labels_bound",
    "retrieve_pressure_bound",
    "repair_pressure_bound",
    "deeper_model_pressure_bound",
    "verifier_pressure_bound",
    "abstain_pressure_bound",
    "test_refs_bound",
    "citation_refs_bound",
    "scope_rex_refs_bound",
    "sovereign_gate_refs_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "route_authority_shadow_only",
    "live_policy_not_promoted",
    "pressure_not_hidden_truth",
    "statement_not_mutated",
    "verifier_not_bypassed",
    "tests_not_bypassed",
    "citations_not_bypassed",
    "scope_rex_not_bypassed",
    "sovereign_gate_not_bypassed",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "proof_pressure_signal_address_deterministic",
    "held_out_route_success_bound",
    "statement_preservation_floor_bound",
    "missing_premise_recall_bound",
    "answer_packet_coverage_bound",
    "calibration_error_bound",
    "pressure_token_budget_bound",
    "metadata_bound",
    "beats_static_proof_route_baseline",
    "beats_proof_search_only_baseline",
    "beats_no_pressure_memory_baseline",
    "duplicate_fixture_rejected",
    "duplicate_pressure_signal_rejected",
    "missing_claim_ref_rejected",
    "missing_mission_id_rejected",
    "missing_proof_search_signal_ref_rejected",
    "statement_preservation_too_low_rejected",
    "statement_mutation_rejected",
    "missing_compiler_error_kind_rejected",
    "invalid_compiler_error_kind_rejected",
    "tactic_entropy_out_of_range_rejected",
    "missing_premise_ref_rejected",
    "missing_verified_neighbor_rejected",
    "missing_failed_attempt_memory_rejected",
    "missing_route_pressure_rejected",
    "invalid_route_pressure_rejected",
    "missing_test_ref_rejected",
    "missing_citation_ref_rejected",
    "missing_scope_rex_rejected",
    "missing_sovereign_gate_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "hidden_truth_authority_rejected",
    "verifier_bypass_rejected",
    "test_bypass_rejected",
    "citation_bypass_rejected",
    "scope_rex_bypass_rejected",
    "sovereign_gate_bypass_rejected",
    "hidden_live_authority_rejected",
    "live_policy_promotion_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "static_proof_route_baseline_unbeaten_rejected",
    "proof_search_only_baseline_unbeaten_rejected",
    "no_pressure_memory_baseline_unbeaten_rejected",
    "calibration_error_too_high_rejected",
    "compiler_error_diversity_missing_rejected",
    "route_pressure_diversity_missing_rejected",
    "metadata_budget_rejected",
    "pressure_token_budget_rejected",
    "fixture_count",
    "pressure_signal_count",
    "train_case_count",
    "held_out_case_count",
    "compiler_error_kind_count",
    "route_pressure_kind_count",
    "missing_premise_case_count",
    "verified_neighbor_count",
    "max_pressure_tokens",
    "max_pressure_metadata_bytes",
    "max_tactic_state_entropy_bps",
    "held_out_route_success_bps",
    "statement_preservation_floor_bps",
    "missing_premise_recall_bps",
    "answer_packet_coverage_bps",
    "calibration_error_bps",
    "static_proof_route_baseline_bps",
    "proof_search_only_baseline_bps",
    "no_pressure_memory_baseline_bps",
    "proof_pressure_signal_address",
];
const VERIFIER_REGRET_FAST_WEIGHTS_AXES: &[&str] = &[
    "upstream_proof_pressure_signal_pass",
    "fast_weight_fixture_present",
    "fixture_ids_bound",
    "update_ids_bound",
    "scopes_bound",
    "base_policy_digests_bound",
    "fast_weight_delta_refs_bound",
    "update_rules_bound",
    "verifier_regret_refs_bound",
    "trace_surprise_refs_bound",
    "affected_policy_fields_bound",
    "splits_bound",
    "route_logit_delta_bound",
    "page_threshold_delta_bound",
    "depth_threshold_delta_bound",
    "verifier_prior_delta_bound",
    "tournament_temperature_delta_bound",
    "drift_bounds_bound",
    "ttl_bound",
    "reset_handles_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "held_out_result_refs_bound",
    "consolidation_candidates_bound",
    "consolidation_not_promoted",
    "route_authority_shadow_only",
    "fast_weights_session_local",
    "fast_weights_resettable",
    "ttl_not_expired",
    "drift_within_bound",
    "held_out_route_choice_improved",
    "route_choice_regret_reduced",
    "answer_packet_coverage_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "no_base_weight_mutation",
    "no_live_policy_promotion",
    "no_hidden_route_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "verifier_regret_fast_weights_address_deterministic",
    "metadata_bound",
    "beats_static_policy_baseline",
    "beats_no_fast_weight_baseline",
    "beats_stale_fast_weight_baseline",
    "beats_unbounded_delta_baseline",
    "duplicate_fixture_rejected",
    "missing_fixture_id_rejected",
    "missing_upstream_proof_pressure_rejected",
    "missing_shadow_policy_rejected",
    "missing_update_rejected",
    "duplicate_update_rejected",
    "missing_update_id_rejected",
    "missing_scope_rejected",
    "invalid_scope_rejected",
    "missing_base_policy_digest_rejected",
    "missing_delta_ref_rejected",
    "missing_update_rule_rejected",
    "missing_verifier_regret_rejected",
    "missing_trace_surprise_rejected",
    "missing_affected_policy_field_rejected",
    "invalid_policy_field_rejected",
    "route_logit_delta_overflow_rejected",
    "page_threshold_delta_overflow_rejected",
    "depth_threshold_delta_overflow_rejected",
    "verifier_prior_delta_overflow_rejected",
    "tournament_temperature_delta_overflow_rejected",
    "missing_drift_bound_rejected",
    "drift_overflow_rejected",
    "missing_ttl_rejected",
    "ttl_expired_rejected",
    "missing_reset_handle_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "missing_held_out_result_rejected",
    "missing_consolidation_candidate_rejected",
    "missing_held_out_split_rejected",
    "invalid_split_rejected",
    "consolidation_promotion_rejected",
    "base_weight_mutation_rejected",
    "live_policy_promotion_rejected",
    "hidden_route_authority_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "static_policy_unbeaten_rejected",
    "no_fast_weight_unbeaten_rejected",
    "stale_fast_weight_unbeaten_rejected",
    "unbounded_delta_unbeaten_rejected",
    "metadata_budget_rejected",
    "fixture_count",
    "update_count",
    "scope_count",
    "affected_policy_field_count",
    "held_out_case_count",
    "min_ttl_ms",
    "max_ttl_ms",
    "max_drift_bps",
    "drift_bound_bps",
    "held_out_route_success_bps",
    "route_regret_reduction_bps",
    "answer_packet_coverage_bps",
    "static_policy_baseline_bps",
    "no_fast_weight_baseline_bps",
    "stale_fast_weight_baseline_bps",
    "unbounded_delta_baseline_bps",
    "max_delta_metadata_bytes",
    "verifier_regret_fast_weights_address",
];
const FAST_WEIGHT_QUARANTINE_AXES: &[&str] = &[
    "upstream_verifier_regret_fast_weights_pass",
    "quarantine_fixture_present",
    "fixture_ids_bound",
    "quarantine_ids_bound",
    "source_update_refs_bound",
    "fast_weight_delta_refs_bound",
    "scopes_bound",
    "base_policy_digests_bound",
    "quarantine_policy_refs_bound",
    "quarantine_states_bound",
    "admission_gate_refs_bound",
    "drift_gate_refs_bound",
    "held_out_replay_refs_bound",
    "rollback_bound",
    "ttl_bound",
    "reset_handles_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "replay_trace_refs_bound",
    "release_decisions_bound",
    "write_barriers_bound",
    "mutation_safety_fences_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "quarantine_shadow_only",
    "route_authority_shadow_only",
    "live_control_attempts_rejected",
    "consolidation_not_promoted",
    "fast_weights_session_local",
    "fast_weights_resettable",
    "ttl_not_expired",
    "drift_within_bound",
    "held_out_replay_passed",
    "rollback_verified",
    "answer_packet_coverage_bound",
    "mutation_safety_bound",
    "no_base_weight_mutation",
    "no_route_policy_mutation",
    "no_live_control_authority",
    "no_hidden_route_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "fast_weight_quarantine_address_deterministic",
    "metadata_bound",
    "beats_unquarantined_fast_weight_baseline",
    "beats_live_promotion_baseline",
    "beats_stale_quarantine_baseline",
    "beats_no_answer_packet_baseline",
    "duplicate_fixture_rejected",
    "missing_fixture_id_rejected",
    "missing_upstream_fast_weight_rejected",
    "missing_quarantine_policy_rejected",
    "missing_quarantine_record_rejected",
    "duplicate_quarantine_rejected",
    "missing_quarantine_id_rejected",
    "missing_source_update_ref_rejected",
    "missing_delta_ref_rejected",
    "missing_scope_rejected",
    "invalid_scope_rejected",
    "missing_base_policy_digest_rejected",
    "missing_quarantine_state_rejected",
    "invalid_quarantine_state_rejected",
    "missing_admission_gate_rejected",
    "missing_drift_gate_rejected",
    "missing_held_out_replay_rejected",
    "held_out_replay_failure_rejected",
    "missing_rollback_rejected",
    "missing_ttl_rejected",
    "ttl_expired_rejected",
    "missing_reset_handle_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "missing_replay_trace_rejected",
    "missing_release_decision_rejected",
    "invalid_release_decision_rejected",
    "missing_write_barrier_rejected",
    "missing_mutation_safety_fence_rejected",
    "drift_overflow_rejected",
    "live_control_authority_rejected",
    "live_control_attempt_unblocked_rejected",
    "consolidation_promotion_rejected",
    "base_weight_mutation_rejected",
    "route_policy_mutation_rejected",
    "hidden_route_authority_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "unquarantined_baseline_unbeaten_rejected",
    "live_promotion_baseline_unbeaten_rejected",
    "stale_quarantine_baseline_unbeaten_rejected",
    "no_answer_packet_baseline_unbeaten_rejected",
    "metadata_budget_rejected",
    "missing_held_out_split_rejected",
    "invalid_split_rejected",
    "fixture_count",
    "quarantine_record_count",
    "scope_count",
    "state_count",
    "release_decision_count",
    "blocked_live_control_attempt_count",
    "held_out_replay_count",
    "reset_handle_count",
    "rollback_handle_count",
    "min_ttl_ms",
    "max_ttl_ms",
    "max_drift_bps",
    "drift_bound_bps",
    "held_out_replay_success_bps",
    "shadow_replay_success_bps",
    "answer_packet_coverage_bps",
    "live_control_rejection_bps",
    "unquarantined_fast_weight_baseline_bps",
    "live_promotion_baseline_bps",
    "stale_quarantine_baseline_bps",
    "no_answer_packet_baseline_bps",
    "max_quarantine_metadata_bytes",
    "fast_weight_quarantine_address",
];

const DEPTH_LEASE_CHECKPOINT_AXES: &[&str] = &[
    "upstream_layer_kv_joint_lease_pass",
    "upstream_fast_weight_quarantine_pass",
    "checkpoint_fixture_present",
    "fixture_ids_bound",
    "checkpoint_ids_bound",
    "mission_ids_bound",
    "route_card_refs_bound",
    "depth_policy_refs_bound",
    "shallow_exit_declared",
    "deeper_wake_declared",
    "verifier_margin_bound",
    "max_extra_layers_bound",
    "full_depth_fallback_bound",
    "checkpoint_refs_bound",
    "resume_tokens_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "answer_packet_fields_bound",
    "mutation_safety_fence_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "held_out_split_bound",
    "depth_lease_shadow_only",
    "silent_depth_promotion_rejected",
    "full_depth_fallback_visible",
    "no_live_route_authority",
    "no_base_weight_mutation",
    "no_route_policy_mutation",
    "no_cache_mutation",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "depth_lease_checkpoint_address_deterministic",
    "metadata_bound",
    "beats_shallow_only_baseline",
    "beats_hidden_depth_baseline",
    "beats_no_checkpoint_baseline",
    "beats_no_fallback_baseline",
    "duplicate_fixture_rejected",
    "missing_fixture_id_rejected",
    "missing_fixture_policy_rejected",
    "missing_checkpoint_record_rejected",
    "duplicate_checkpoint_rejected",
    "missing_checkpoint_id_rejected",
    "missing_mission_rejected",
    "missing_upstream_layer_kv_rejected",
    "missing_upstream_fast_weight_quarantine_rejected",
    "missing_route_card_rejected",
    "missing_depth_policy_rejected",
    "missing_shallow_exit_rejected",
    "missing_deeper_wake_rejected",
    "invalid_depth_order_rejected",
    "missing_full_depth_rejected",
    "extra_layer_budget_rejected",
    "missing_checkpoint_ref_rejected",
    "missing_resume_token_rejected",
    "missing_verifier_margin_rejected",
    "verifier_margin_too_low_rejected",
    "latency_budget_rejected",
    "missing_full_depth_fallback_rejected",
    "fallback_disabled_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "missing_answer_packet_field_rejected",
    "missing_mutation_safety_fence_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "missing_split_rejected",
    "invalid_split_rejected",
    "missing_held_out_split_rejected",
    "silent_depth_promotion_case_rejected",
    "live_route_authority_rejected",
    "base_weight_mutation_rejected",
    "route_policy_mutation_rejected",
    "cache_mutation_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "metadata_budget_rejected",
    "shallow_only_baseline_unbeaten_rejected",
    "hidden_depth_baseline_unbeaten_rejected",
    "no_checkpoint_baseline_unbeaten_rejected",
    "no_fallback_baseline_unbeaten_rejected",
    "fixture_count",
    "checkpoint_count",
    "held_out_checkpoint_count",
    "shallow_exit_count",
    "deeper_wake_count",
    "full_depth_fallback_count",
    "resume_token_count",
    "rollback_handle_count",
    "run_event_log_count",
    "answer_packet_count",
    "min_verifier_margin_bps",
    "max_extra_layers",
    "max_depth_delta",
    "max_latency_ms",
    "lease_success_bps",
    "answer_packet_coverage_bps",
    "silent_promotion_rejection_bps",
    "shallow_only_baseline_bps",
    "hidden_depth_baseline_bps",
    "no_checkpoint_baseline_bps",
    "no_fallback_baseline_bps",
    "max_checkpoint_metadata_bytes",
    "depth_lease_checkpoint_address",
];

const SHADOW_WAKE_ORACLE_AXES: &[&str] = &[
    "upstream_depth_lease_checkpoint_pass",
    "upstream_route_distillation_tournament_pass",
    "shadow_wake_fixture_present",
    "fixture_ids_bound",
    "oracle_ids_bound",
    "mission_ids_bound",
    "cheap_route_traces_bound",
    "full_wake_traces_bound",
    "proof_or_test_results_bound",
    "unit_credit_assignments_bound",
    "byte_latency_deltas_bound",
    "oracle_labels_bound",
    "route_labels_bound",
    "scout_feature_refs_bound",
    "proof_refs_bound",
    "test_refs_bound",
    "citation_refs_bound",
    "scope_rex_refs_bound",
    "sovereign_gate_refs_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "held_out_split_bound",
    "source_kind_diversity_bound",
    "route_label_diversity_bound",
    "shadow_only_authority",
    "offline_distillation_only",
    "oracle_not_live_dependency",
    "oracle_not_hidden_truth",
    "verifier_not_bypassed",
    "tests_not_bypassed",
    "citations_not_bypassed",
    "scope_rex_not_bypassed",
    "sovereign_gate_not_bypassed",
    "no_base_weight_mutation",
    "no_route_policy_mutation",
    "no_cache_mutation",
    "no_hidden_route_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "shadow_wake_oracle_address_deterministic",
    "held_out_success_bound",
    "label_agreement_bound",
    "calibration_error_bound",
    "trace_token_budget_bound",
    "metadata_bound",
    "beats_cheap_route_baseline",
    "beats_full_wake_everything_baseline",
    "beats_no_oracle_label_baseline",
    "duplicate_fixture_rejected",
    "duplicate_oracle_rejected",
    "missing_fixture_id_rejected",
    "missing_oracle_record_rejected",
    "missing_oracle_id_rejected",
    "missing_mission_rejected",
    "missing_upstream_depth_lease_rejected",
    "missing_upstream_route_distillation_rejected",
    "missing_cheap_route_trace_rejected",
    "missing_full_wake_trace_rejected",
    "missing_proof_or_test_rejected",
    "missing_credit_assignment_rejected",
    "missing_byte_latency_delta_rejected",
    "missing_oracle_label_rejected",
    "missing_route_label_rejected",
    "missing_scout_feature_rejected",
    "missing_proof_ref_rejected",
    "missing_test_ref_rejected",
    "missing_citation_ref_rejected",
    "missing_scope_rex_rejected",
    "missing_sovereign_gate_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "missing_split_rejected",
    "invalid_split_rejected",
    "missing_held_out_split_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "hidden_live_dependency_rejected",
    "hidden_truth_authority_rejected",
    "verifier_bypass_rejected",
    "test_bypass_rejected",
    "citation_bypass_rejected",
    "scope_rex_bypass_rejected",
    "sovereign_gate_bypass_rejected",
    "base_weight_mutation_rejected",
    "route_policy_mutation_rejected",
    "cache_mutation_rejected",
    "hidden_route_authority_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "cheap_route_baseline_unbeaten_rejected",
    "full_wake_everything_baseline_unbeaten_rejected",
    "no_oracle_label_baseline_unbeaten_rejected",
    "label_agreement_too_low_rejected",
    "calibration_error_too_high_rejected",
    "source_kind_diversity_missing_rejected",
    "route_label_diversity_missing_rejected",
    "trace_token_budget_rejected",
    "metadata_budget_rejected",
    "fixture_count",
    "oracle_record_count",
    "train_case_count",
    "held_out_case_count",
    "source_kind_count",
    "route_label_count",
    "credit_assignment_count",
    "proof_or_test_result_count",
    "max_trace_tokens",
    "max_oracle_metadata_bytes",
    "held_out_success_bps",
    "label_agreement_bps",
    "calibration_error_bps",
    "cheap_route_baseline_bps",
    "full_wake_everything_baseline_bps",
    "no_oracle_label_baseline_bps",
    "shadow_wake_oracle_address",
];

const ABLATION_SHADOW_RUN_AXES: &[&str] = &[
    "upstream_shadow_wake_oracle_pass",
    "ablation_fixture_present",
    "fixture_ids_bound",
    "run_ids_bound",
    "mission_ids_bound",
    "upstream_shadow_wake_refs_bound",
    "baseline_traces_bound",
    "candidate_traces_bound",
    "removed_units_bound",
    "removed_unit_uas_addresses_bound",
    "route_labels_bound",
    "oracle_label_refs_bound",
    "quality_deltas_bound",
    "verifier_deltas_bound",
    "latency_deltas_bound",
    "byte_deltas_bound",
    "decisions_bound",
    "decision_records_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "held_out_split_bound",
    "retained_cases_present",
    "demoted_cases_present",
    "abstain_cases_present",
    "decision_diversity_bound",
    "route_label_diversity_bound",
    "counterfactual_remove_one_unit_bound",
    "shadow_only_authority",
    "offline_evaluation_only",
    "oracle_not_live_dependency",
    "no_live_route_promotion",
    "no_base_weight_mutation",
    "no_route_policy_mutation",
    "no_cache_mutation",
    "no_hidden_route_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "ablation_shadow_run_address_deterministic",
    "retained_quality_delta_bound",
    "retained_verifier_delta_bound",
    "retained_latency_penalty_budget_bound",
    "retained_byte_budget_bound",
    "decision_accuracy_bound",
    "retained_success_bound",
    "metadata_bound",
    "beats_keep_all_baseline",
    "beats_remove_all_baseline",
    "beats_random_ablation_baseline",
    "beats_no_ablation_baseline",
    "duplicate_fixture_rejected",
    "duplicate_run_rejected",
    "missing_fixture_id_rejected",
    "missing_policy_rejected",
    "missing_run_rejected",
    "missing_run_id_rejected",
    "missing_mission_rejected",
    "missing_upstream_shadow_wake_rejected",
    "missing_baseline_trace_rejected",
    "missing_candidate_trace_rejected",
    "missing_removed_unit_rejected",
    "missing_removed_unit_uas_rejected",
    "invalid_removed_unit_uas_rejected",
    "missing_route_label_rejected",
    "missing_oracle_label_rejected",
    "missing_decision_rejected",
    "invalid_decision_rejected",
    "decision_mismatch_rejected",
    "missing_decision_record_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "missing_split_rejected",
    "invalid_split_rejected",
    "missing_held_out_split_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "oracle_live_dependency_rejected",
    "live_route_promotion_rejected",
    "base_weight_mutation_rejected",
    "route_policy_mutation_rejected",
    "cache_mutation_rejected",
    "hidden_route_authority_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_source_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "keep_all_baseline_unbeaten_rejected",
    "remove_all_baseline_unbeaten_rejected",
    "random_ablation_baseline_unbeaten_rejected",
    "no_ablation_baseline_unbeaten_rejected",
    "decision_accuracy_too_low_rejected",
    "retained_success_too_low_rejected",
    "retained_quality_delta_too_low_rejected",
    "retained_verifier_delta_too_low_rejected",
    "retained_latency_budget_rejected",
    "retained_byte_budget_rejected",
    "decision_diversity_missing_rejected",
    "route_label_diversity_missing_rejected",
    "metadata_budget_rejected",
    "fixture_count",
    "ablation_run_count",
    "train_case_count",
    "held_out_case_count",
    "retained_case_count",
    "demoted_case_count",
    "abstain_case_count",
    "removed_unit_count",
    "route_label_count",
    "decision_kind_count",
    "min_retained_quality_delta_bps",
    "min_retained_verifier_delta_bps",
    "max_retained_latency_delta_ms",
    "max_retained_byte_delta",
    "decision_accuracy_bps",
    "retained_success_bps",
    "keep_all_baseline_bps",
    "remove_all_baseline_bps",
    "random_ablation_baseline_bps",
    "no_ablation_baseline_bps",
    "max_ablation_metadata_bytes",
    "ablation_shadow_run_address",
];

const AXIOM_AXIOMATIC_SOURCE_DISTINCTION_AXES: &[&str] = &[
    "upstream_ablation_shadow_run_pass",
    "source_fixture_present",
    "fixture_ids_bound",
    "source_cards_bound",
    "source_ids_bound",
    "source_urls_bound",
    "source_titles_bound",
    "source_classes_bound",
    "motif_classes_bound",
    "license_notes_bound",
    "usage_notes_bound",
    "source_digests_bound",
    "claim_status_bound",
    "product_build_bound",
    "pro_status_bound",
    "allowed_use_bound",
    "forbidden_claims_bound",
    "route_impact_bound",
    "admission_bound",
    "rollback_bound",
    "run_event_log_bound",
    "answer_packet_ref_bound",
    "compatibility_fence_bound",
    "privacy_classes_bound",
    "false_merge_negatives_bound",
    "source_class_diversity_bound",
    "motif_class_diversity_bound",
    "source_urls_unique",
    "source_ids_unique",
    "external_sources_not_local_capability",
    "source_prior_only_route_impact",
    "stale_overclaim_strings_guarded",
    "no_hidden_source_authority",
    "no_hidden_route_authority",
    "no_hidden_proof_authority",
    "no_hidden_chain",
    "no_hidden_cloud",
    "no_raw_code_import",
    "no_product_claim_promotion",
    "no_runtime_bytes_loaded",
    "no_model_bytes_loaded",
    "metadata_bound",
    "axiom_axle_distinct_from_axiomatic_axprover",
    "axiom_axplorer_distinct_from_axiomatic_oprover",
    "harmonic_distinct_from_math_inc",
    "ulamai_distinct_from_axiom",
    "lean_tooling_distinct_from_provers",
    "math_inc_workflow_distinct_from_harmonic_artifact",
    "axiom_axiomatic_source_distinction_address_deterministic",
    "empty_fixture_rejected",
    "duplicate_source_id_rejected",
    "duplicate_source_url_rejected",
    "missing_fixture_id_rejected",
    "missing_source_card_rejected",
    "missing_source_id_rejected",
    "missing_source_url_rejected",
    "invalid_source_url_rejected",
    "missing_source_title_rejected",
    "missing_source_class_rejected",
    "unknown_source_class_rejected",
    "forbidden_merged_source_class_rejected",
    "missing_motif_class_rejected",
    "missing_license_rejected",
    "missing_usage_note_rejected",
    "missing_source_digest_rejected",
    "invalid_source_digest_rejected",
    "missing_claim_status_rejected",
    "product_claim_status_rejected",
    "missing_product_build_rejected",
    "mas_product_build_rejected",
    "missing_pro_status_rejected",
    "live_pro_status_rejected",
    "missing_allowed_use_rejected",
    "missing_forbidden_claims_rejected",
    "hidden_source_authority_rejected",
    "hidden_route_authority_rejected",
    "hidden_proof_authority_rejected",
    "hidden_chain_exposure_rejected",
    "cloud_runtime_dependency_rejected",
    "raw_code_import_rejected",
    "product_claim_promotion_rejected",
    "missing_route_impact_rejected",
    "live_route_impact_rejected",
    "missing_admission_rejected",
    "missing_rollback_rejected",
    "missing_run_event_log_rejected",
    "missing_answer_packet_rejected",
    "incompatible_fence_rejected",
    "invalid_privacy_rejected",
    "runtime_bytes_rejected",
    "model_bytes_rejected",
    "metadata_budget_rejected",
    "source_class_diversity_missing_rejected",
    "motif_class_diversity_missing_rejected",
    "false_merge_negatives_missing_rejected",
    "false_merge_not_rejected_rejected",
    "false_merge_same_source_rejected",
    "required_false_merge_pair_missing_rejected",
    "missing_stale_overclaim_guard_rejected",
    "stale_overclaim_string_rejected",
    "fixture_count",
    "source_card_count",
    "source_class_count",
    "motif_class_count",
    "false_merge_case_count",
    "stale_overclaim_string_count",
    "max_source_card_metadata_bytes",
    "axiom_axiomatic_source_distinction_address",
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
    let budgeted_uncertainty_escalator = read_json(Path::new(BUDGETED_UNCERTAINTY_ESCALATOR_PATH));
    let budgeted_uncertainty_escalator_available = artifact_all_axes_true(
        &budgeted_uncertainty_escalator,
        BUDGETED_UNCERTAINTY_ESCALATOR_AXES,
    );
    let sparse_wake_proposal_budget = read_json(Path::new(SPARSE_WAKE_PROPOSAL_BUDGET_PATH));
    let sparse_wake_proposal_budget_available = artifact_all_axes_true(
        &sparse_wake_proposal_budget,
        SPARSE_WAKE_PROPOSAL_BUDGET_AXES,
    );
    let verifier_budget_auction = read_json(Path::new(VERIFIER_BUDGET_AUCTION_PATH));
    let verifier_budget_auction_available =
        artifact_all_axes_true(&verifier_budget_auction, VERIFIER_BUDGET_AUCTION_AXES);
    let kv_page_sketch_index = read_json(Path::new(KV_PAGE_SKETCH_INDEX_PATH));
    let kv_page_sketch_index_available =
        artifact_all_axes_true(&kv_page_sketch_index, KV_PAGE_SKETCH_INDEX_AXES);
    let kv_page_bloom_sketch_coverage = read_json(Path::new(KV_PAGE_BLOOM_SKETCH_COVERAGE_PATH));
    let kv_page_bloom_sketch_coverage_available = artifact_all_axes_true(
        &kv_page_bloom_sketch_coverage,
        KV_PAGE_BLOOM_SKETCH_COVERAGE_AXES,
    );
    let query_aware_kv_selector = read_json(Path::new(QUERY_AWARE_KV_SELECTOR_PATH));
    let query_aware_kv_selector_available =
        artifact_all_axes_true(&query_aware_kv_selector, QUERY_AWARE_KV_SELECTOR_AXES);
    let sparse_wake_certificate_answer_packet =
        read_json(Path::new(SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET_PATH));
    let sparse_wake_certificate_answer_packet_available = artifact_all_axes_true(
        &sparse_wake_certificate_answer_packet,
        SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET_AXES,
    );
    let layer_kv_joint_lease = read_json(Path::new(LAYER_KV_JOINT_LEASE_PATH));
    let layer_kv_joint_lease_available =
        artifact_all_axes_true(&layer_kv_joint_lease, LAYER_KV_JOINT_LEASE_AXES);
    let construction_search_tournament = read_json(Path::new(CONSTRUCTION_SEARCH_TOURNAMENT_PATH));
    let construction_search_tournament_available = artifact_all_axes_true(
        &construction_search_tournament,
        CONSTRUCTION_SEARCH_TOURNAMENT_AXES,
    );
    let route_distillation_tournament = read_json(Path::new(ROUTE_DISTILLATION_TOURNAMENT_PATH));
    let route_distillation_tournament_available = artifact_all_axes_true(
        &route_distillation_tournament,
        ROUTE_DISTILLATION_TOURNAMENT_AXES,
    );
    let proof_search_signal_route_feedback =
        read_json(Path::new(PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK_PATH));
    let proof_search_signal_route_feedback_available = artifact_all_axes_true(
        &proof_search_signal_route_feedback,
        PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK_AXES,
    );
    let proof_pressure_signal = read_json(Path::new(PROOF_PRESSURE_SIGNAL_PATH));
    let proof_pressure_signal_available =
        artifact_all_axes_true(&proof_pressure_signal, PROOF_PRESSURE_SIGNAL_AXES);
    let verifier_regret_fast_weights = read_json(Path::new(VERIFIER_REGRET_FAST_WEIGHTS_PATH));
    let verifier_regret_fast_weights_available = artifact_all_axes_true(
        &verifier_regret_fast_weights,
        VERIFIER_REGRET_FAST_WEIGHTS_AXES,
    );
    let fast_weight_quarantine = read_json(Path::new(FAST_WEIGHT_QUARANTINE_PATH));
    let fast_weight_quarantine_available =
        artifact_all_axes_true(&fast_weight_quarantine, FAST_WEIGHT_QUARANTINE_AXES);
    let depth_lease_checkpoint = read_json(Path::new(DEPTH_LEASE_CHECKPOINT_PATH));
    let depth_lease_checkpoint_available =
        artifact_all_axes_true(&depth_lease_checkpoint, DEPTH_LEASE_CHECKPOINT_AXES);
    let shadow_wake_oracle = read_json(Path::new(SHADOW_WAKE_ORACLE_PATH));
    let shadow_wake_oracle_available =
        artifact_all_axes_true(&shadow_wake_oracle, SHADOW_WAKE_ORACLE_AXES);
    let ablation_shadow_run = read_json(Path::new(ABLATION_SHADOW_RUN_PATH));
    let ablation_shadow_run_available =
        artifact_all_axes_true(&ablation_shadow_run, ABLATION_SHADOW_RUN_AXES);
    let axiom_axiomatic_source_distinction =
        read_json(Path::new(AXIOM_AXIOMATIC_SOURCE_DISTINCTION_PATH));
    let axiom_axiomatic_source_distinction_available = artifact_all_axes_true(
        &axiom_axiomatic_source_distinction,
        AXIOM_AXIOMATIC_SOURCE_DISTINCTION_AXES,
    );
    let sparse_route_no_hidden_authority =
        read_json(Path::new(SPARSE_ROUTE_NO_HIDDEN_AUTHORITY_PATH));
    let sparse_route_no_hidden_authority_available = artifact_all_axes_true(
        &sparse_route_no_hidden_authority,
        SPARSE_ROUTE_NO_HIDDEN_AUTHORITY_AXES,
    );
    let coldstream_no_hidden_authority = read_json(Path::new(COLDSTREAM_NO_HIDDEN_AUTHORITY_PATH));
    let coldstream_no_hidden_authority_available = artifact_all_axes_true(
        &coldstream_no_hidden_authority,
        COLDSTREAM_NO_HIDDEN_AUTHORITY_AXES,
    );
    let large_model_provider_reference_deferral = read_json(Path::new(
        LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_BY_MLX_ROUTE_PATH,
    ));
    let large_model_provider_reference_deferral_available = artifact_all_axes_true(
        &large_model_provider_reference_deferral,
        LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_BY_MLX_ROUTE_AXES,
    );
    let provider_route_copy_source_guard =
        read_json(Path::new(PROVIDER_ROUTE_COPY_SOURCE_GUARD_PATH));
    let provider_route_copy_source_guard_available = artifact_all_axes_true(
        &provider_route_copy_source_guard,
        PROVIDER_ROUTE_COPY_SOURCE_GUARD_AXES,
    );
    let transport_trace_answer_packet = read_json(Path::new(TRANSPORT_TRACE_ANSWER_PACKET_PATH));
    let transport_trace_answer_packet_available = artifact_all_axes_true(
        &transport_trace_answer_packet,
        TRANSPORT_TRACE_ANSWER_PACKET_AXES,
    );
    let ssd_wear_budget = read_json(Path::new(SSD_WEAR_BUDGET_PATH));
    let ssd_wear_budget_available = artifact_all_axes_true(&ssd_wear_budget, SSD_WEAR_BUDGET_AXES);
    let coldstream_vs_mmap = read_json(Path::new(COLDSTREAM_VS_MMAP_PATH));
    let coldstream_vs_mmap_available =
        artifact_all_axes_true(&coldstream_vs_mmap, COLDSTREAM_VS_MMAP_AXES);
    let slab_arena_copy_count = read_json(Path::new(SLAB_ARENA_COPY_COUNT_PATH));
    let slab_arena_copy_count_available =
        artifact_all_axes_true(&slab_arena_copy_count, SLAB_ARENA_COPY_COUNT_AXES);
    let metal_io_feature_gate = read_json(Path::new(METAL_IO_FEATURE_GATE_PATH));
    let metal_io_feature_gate_available =
        artifact_all_axes_true(&metal_io_feature_gate, METAL_IO_FEATURE_GATE_AXES);
    let codec_stage_latency = read_json(Path::new(CODEC_STAGE_LATENCY_PATH));
    let codec_stage_latency_available =
        artifact_all_axes_true(&codec_stage_latency, CODEC_STAGE_LATENCY_AXES);
    let transport_cancellation = read_json(Path::new(TRANSPORT_CANCELLATION_PATH));
    let transport_cancellation_available =
        artifact_all_axes_true(&transport_cancellation, TRANSPORT_CANCELLATION_AXES);
    let cache_policy_pollution = read_json(Path::new(CACHE_POLICY_POLLUTION_PATH));
    let cache_policy_pollution_available =
        artifact_all_axes_true(&cache_policy_pollution, CACHE_POLICY_POLLUTION_AXES);
    let cold_panic_fallback = read_json(Path::new(COLD_PANIC_FALLBACK_PATH));
    let cold_panic_fallback_available =
        artifact_all_axes_true(&cold_panic_fallback, COLD_PANIC_FALLBACK_AXES);
    let product_route_review = read_json(Path::new(PRODUCT_ROUTE_REVIEW_PATH));
    let product_route_review_available =
        artifact_all_axes_true(&product_route_review, PRODUCT_ROUTE_REVIEW_AXES);
    let small_model_runtime_harness_safety_plan =
        read_json(Path::new(SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_PATH));
    let small_model_runtime_harness_safety_plan_available = artifact_all_axes_true(
        &small_model_runtime_harness_safety_plan,
        SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_AXES,
    );
    let small_model_runtime_harness_dry_run_witness =
        read_json(Path::new(SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_PATH));
    let small_model_runtime_harness_dry_run_witness_available = artifact_all_axes_true(
        &small_model_runtime_harness_dry_run_witness,
        SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_AXES,
    );
    let small_model_runtime_harness_owner_approved_probe =
        read_json(Path::new(SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_PATH));
    let small_model_runtime_harness_owner_approved_probe_available = artifact_all_axes_true(
        &small_model_runtime_harness_owner_approved_probe,
        SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_AXES,
    );
    let small_model_runtime_harness_abortable_runtime_probe =
        read_json(Path::new(SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_PATH));
    let small_model_runtime_harness_abortable_runtime_probe_available = artifact_all_axes_true(
        &small_model_runtime_harness_abortable_runtime_probe,
        SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_AXES,
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
        large_model_provider_reference_deferral_available,
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
        && budgeted_uncertainty_escalator_available
        && sparse_wake_proposal_budget_available
        && verifier_budget_auction_available
        && kv_page_sketch_index_available
        && kv_page_bloom_sketch_coverage_available
        && query_aware_kv_selector_available
        && sparse_wake_certificate_answer_packet_available
        && layer_kv_joint_lease_available
        && construction_search_tournament_available
        && route_distillation_tournament_available
        && proof_search_signal_route_feedback_available
        && proof_pressure_signal_available
        && verifier_regret_fast_weights_available
        && fast_weight_quarantine_available
        && depth_lease_checkpoint_available
        && shadow_wake_oracle_available
        && ablation_shadow_run_available
        && axiom_axiomatic_source_distinction_available
        && sparse_route_no_hidden_authority_available
        && coldstream_no_hidden_authority_available
        && (heavy_long_context_enabled || large_model_provider_reference_deferral_available)
        && (heavy_long_context_enabled
            || !large_model_provider_reference_deferral_available
            || provider_route_copy_source_guard_available)
        && (heavy_long_context_enabled
            || !provider_route_copy_source_guard_available
            || transport_trace_answer_packet_available)
        && (heavy_long_context_enabled
            || !transport_trace_answer_packet_available
            || ssd_wear_budget_available)
        && (heavy_long_context_enabled
            || !ssd_wear_budget_available
            || coldstream_vs_mmap_available)
        && (heavy_long_context_enabled
            || !coldstream_vs_mmap_available
            || slab_arena_copy_count_available)
        && (heavy_long_context_enabled
            || !slab_arena_copy_count_available
            || metal_io_feature_gate_available)
        && (heavy_long_context_enabled
            || !metal_io_feature_gate_available
            || codec_stage_latency_available)
        && (heavy_long_context_enabled
            || !codec_stage_latency_available
            || transport_cancellation_available)
        && (heavy_long_context_enabled
            || !transport_cancellation_available
            || cache_policy_pollution_available)
        && (heavy_long_context_enabled
            || !cache_policy_pollution_available
            || cold_panic_fallback_available)
        && (heavy_long_context_enabled
            || !product_route_review_available
            || small_model_runtime_harness_safety_plan_available)
        && (heavy_long_context_enabled
            || !small_model_runtime_harness_safety_plan_available
            || small_model_runtime_harness_dry_run_witness_available)
        && (heavy_long_context_enabled
            || !small_model_runtime_harness_dry_run_witness_available
            || small_model_runtime_harness_owner_approved_probe_available)
        && (heavy_long_context_enabled
            || !small_model_runtime_harness_owner_approved_probe_available
            || small_model_runtime_harness_abortable_runtime_probe_available)
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
        "budgeted_uncertainty_escalator_available",
        budgeted_uncertainty_escalator_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sparse_wake_proposal_budget_available",
        sparse_wake_proposal_budget_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_budget_auction_available",
        verifier_budget_auction_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_page_sketch_index_available",
        kv_page_sketch_index_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_page_bloom_sketch_coverage_available",
        kv_page_bloom_sketch_coverage_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "query_aware_kv_selector_available",
        query_aware_kv_selector_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sparse_wake_certificate_answer_packet_available",
        sparse_wake_certificate_answer_packet_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "layer_kv_joint_lease_available",
        layer_kv_joint_lease_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "construction_search_tournament_available",
        construction_search_tournament_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_distillation_tournament_available",
        route_distillation_tournament_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_search_signal_route_feedback_available",
        proof_search_signal_route_feedback_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_pressure_signal_available",
        proof_pressure_signal_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_regret_fast_weights_available",
        verifier_regret_fast_weights_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fast_weight_quarantine_available",
        fast_weight_quarantine_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "depth_lease_checkpoint_available",
        depth_lease_checkpoint_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "shadow_wake_oracle_available",
        shadow_wake_oracle_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "ablation_shadow_run_available",
        ablation_shadow_run_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "axiom_axiomatic_source_distinction_available",
        axiom_axiomatic_source_distinction_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sparse_route_no_hidden_authority_available",
        sparse_route_no_hidden_authority_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "coldstream_no_hidden_authority_available",
        coldstream_no_hidden_authority_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "large_model_provider_reference_deferral_available",
        large_model_provider_reference_deferral_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_route_copy_source_guard_available",
        provider_route_copy_source_guard_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "transport_trace_answer_packet_available",
        transport_trace_answer_packet_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "ssd_wear_budget_available",
        ssd_wear_budget_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "coldstream_vs_mmap_available",
        coldstream_vs_mmap_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "slab_arena_copy_count_available",
        slab_arena_copy_count_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metal_io_feature_gate_available",
        metal_io_feature_gate_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "codec_stage_latency_available",
        codec_stage_latency_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "transport_cancellation_available",
        transport_cancellation_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cache_policy_pollution_available",
        cache_policy_pollution_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_panic_fallback_available",
        cold_panic_fallback_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "product_route_review_available",
        product_route_review_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_safety_plan_available",
        small_model_runtime_harness_safety_plan_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_dry_run_witness_available",
        small_model_runtime_harness_dry_run_witness_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_owner_approved_probe_available",
        small_model_runtime_harness_owner_approved_probe_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_abortable_runtime_probe_available",
        small_model_runtime_harness_abortable_runtime_probe_available,
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
                "budgeted_uncertainty_escalator": {
                    "path": BUDGETED_UNCERTAINTY_ESCALATOR_PATH,
                    "available": budgeted_uncertainty_escalator_available
                },
                "sparse_wake_proposal_budget": {
                    "path": SPARSE_WAKE_PROPOSAL_BUDGET_PATH,
                    "available": sparse_wake_proposal_budget_available
                },
                "verifier_budget_auction": {
                    "path": VERIFIER_BUDGET_AUCTION_PATH,
                    "available": verifier_budget_auction_available
                },
                "kv_page_sketch_index": {
                    "path": KV_PAGE_SKETCH_INDEX_PATH,
                    "available": kv_page_sketch_index_available
                },
                "kv_page_bloom_sketch_coverage": {
                    "path": KV_PAGE_BLOOM_SKETCH_COVERAGE_PATH,
                    "available": kv_page_bloom_sketch_coverage_available
                },
                "query_aware_kv_selector": {
                    "path": QUERY_AWARE_KV_SELECTOR_PATH,
                    "available": query_aware_kv_selector_available
                },
                "sparse_wake_certificate_answer_packet": {
                    "path": SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET_PATH,
                    "available": sparse_wake_certificate_answer_packet_available
                },
                "layer_kv_joint_lease": {
                    "path": LAYER_KV_JOINT_LEASE_PATH,
                    "available": layer_kv_joint_lease_available
                },
                "construction_search_tournament": {
                    "path": CONSTRUCTION_SEARCH_TOURNAMENT_PATH,
                    "available": construction_search_tournament_available
                },
                "route_distillation_tournament": {
                    "path": ROUTE_DISTILLATION_TOURNAMENT_PATH,
                    "available": route_distillation_tournament_available
                },
                "proof_search_signal_route_feedback": {
                    "path": PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK_PATH,
                    "available": proof_search_signal_route_feedback_available
                },
                "proof_pressure_signal": {
                    "path": PROOF_PRESSURE_SIGNAL_PATH,
                    "available": proof_pressure_signal_available
                },
                "verifier_regret_fast_weights": {
                    "path": VERIFIER_REGRET_FAST_WEIGHTS_PATH,
                    "available": verifier_regret_fast_weights_available
                },
                "fast_weight_quarantine": {
                    "path": FAST_WEIGHT_QUARANTINE_PATH,
                    "available": fast_weight_quarantine_available
                },
                "depth_lease_checkpoint": {
                    "path": DEPTH_LEASE_CHECKPOINT_PATH,
                    "available": depth_lease_checkpoint_available
                },
                "shadow_wake_oracle": {
                    "path": SHADOW_WAKE_ORACLE_PATH,
                    "available": shadow_wake_oracle_available
                },
                "ablation_shadow_run": {
                    "path": ABLATION_SHADOW_RUN_PATH,
                    "available": ablation_shadow_run_available
                },
                "axiom_axiomatic_source_distinction": {
                    "path": AXIOM_AXIOMATIC_SOURCE_DISTINCTION_PATH,
                    "available": axiom_axiomatic_source_distinction_available
                },
                "sparse_route_no_hidden_authority": {
                    "path": SPARSE_ROUTE_NO_HIDDEN_AUTHORITY_PATH,
                    "available": sparse_route_no_hidden_authority_available
                },
                "coldstream_no_hidden_authority": {
                    "path": COLDSTREAM_NO_HIDDEN_AUTHORITY_PATH,
                    "available": coldstream_no_hidden_authority_available
                },
                "large_model_provider_reference_deferral": {
                    "path": LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_BY_MLX_ROUTE_PATH,
                    "available": large_model_provider_reference_deferral_available
                },
                "provider_route_copy_source_guard": {
                    "path": PROVIDER_ROUTE_COPY_SOURCE_GUARD_PATH,
                    "available": provider_route_copy_source_guard_available
                },
                "transport_trace_answer_packet": {
                    "path": TRANSPORT_TRACE_ANSWER_PACKET_PATH,
                    "available": transport_trace_answer_packet_available
                },
                "ssd_wear_budget": {
                    "path": SSD_WEAR_BUDGET_PATH,
                    "available": ssd_wear_budget_available
                },
                "coldstream_vs_mmap": {
                    "path": COLDSTREAM_VS_MMAP_PATH,
                    "available": coldstream_vs_mmap_available
                },
                "slab_arena_copy_count": {
                    "path": SLAB_ARENA_COPY_COUNT_PATH,
                    "available": slab_arena_copy_count_available
                },
                "metal_io_feature_gate": {
                    "path": METAL_IO_FEATURE_GATE_PATH,
                    "available": metal_io_feature_gate_available
                },
                "codec_stage_latency": {
                    "path": CODEC_STAGE_LATENCY_PATH,
                    "available": codec_stage_latency_available
                },
                "transport_cancellation": {
                    "path": TRANSPORT_CANCELLATION_PATH,
                    "available": transport_cancellation_available
                },
                "cache_policy_pollution": {
                    "path": CACHE_POLICY_POLLUTION_PATH,
                    "available": cache_policy_pollution_available
                },
                "cold_panic_fallback": {
                    "path": COLD_PANIC_FALLBACK_PATH,
                    "available": cold_panic_fallback_available
                },
                "product_route_review": {
                    "path": PRODUCT_ROUTE_REVIEW_PATH,
                    "available": product_route_review_available
                },
                "small_model_runtime_harness_safety_plan": {
                    "path": SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_PATH,
                    "available": small_model_runtime_harness_safety_plan_available
                },
                "small_model_runtime_harness_dry_run_witness": {
                    "path": SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_PATH,
                    "available": small_model_runtime_harness_dry_run_witness_available
                },
                "small_model_runtime_harness_owner_approved_probe": {
                    "path": SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_PATH,
                    "available": small_model_runtime_harness_owner_approved_probe_available
                },
                "small_model_runtime_harness_abortable_runtime_probe": {
                    "path": SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_PATH,
                    "available": small_model_runtime_harness_abortable_runtime_probe_available
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
    if two_stage_route_scout_abstain_available && !budgeted_uncertainty_escalator_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_budgeted_uncertainty_escalator",
            "detail": "Meta Control has two-stage route scout evidence, but needs F-BudgetedUncertaintyEscalator before sparse wake proposal budgeting can advance."
        }));
    }
    if budgeted_uncertainty_escalator_available && !sparse_wake_proposal_budget_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_sparse_wake_proposal_budget",
            "detail": "Meta Control has budgeted uncertainty escalation evidence, but needs F-SparseWakeProposal-Budget before verifier budget auction work can advance."
        }));
    }
    if sparse_wake_proposal_budget_available && !verifier_budget_auction_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_verifier_budget_auction",
            "detail": "Meta Control has sparse wake proposal budget evidence, but needs F-VerifierBudgetAuction before KV/page sketch index work can advance."
        }));
    }
    if verifier_budget_auction_available && !kv_page_sketch_index_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_kv_page_sketch_index",
            "detail": "Meta Control has verifier budget auction evidence, but needs F-KVPageSketchIndex before bloom-sketch coverage or query-aware page selection work can advance."
        }));
    }
    if kv_page_sketch_index_available && !kv_page_bloom_sketch_coverage_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_kv_page_bloom_sketch_coverage",
            "detail": "Meta Control has KV page sketch-index evidence, but needs F-KVPageBloomSketch-Coverage before query-aware page selection work can advance."
        }));
    }
    if kv_page_bloom_sketch_coverage_available && !query_aware_kv_selector_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_query_aware_kv_selector",
            "detail": "Meta Control has KV page Bloom coverage evidence, but needs F-QueryAwareKVSelector before sparse wake certificates or live page-selector authority can advance."
        }));
    }
    if query_aware_kv_selector_available && !sparse_wake_certificate_answer_packet_available {
        anomalies.push(serde_json::json!({
            "kind": "missing_sparse_wake_certificate_answer_packet",
            "detail": "Meta Control has QueryAwareKVSelector evidence, but needs F-SparseWakeCertificate-AnswerPacket before depth/KV joint leases or live sparse route authority can advance."
        }));
    }
    if sparse_wake_certificate_answer_packet_available
        && !layer_kv_joint_lease_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_layer_kv_joint_lease",
            "detail": "Meta Control has SparseWakeCertificate AnswerPacket evidence; the next non-heavy cursor must prove depth and KV/page choices are leased together with fallback, rollback, and AnswerPacket proof."
        }));
    }
    if layer_kv_joint_lease_available
        && !construction_search_tournament_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_construction_search_tournament",
            "detail": "Meta Control has LayerKVJointLease evidence; the next non-heavy cursor must prove generate-repair-score-select improves sparse wake plans under fixed budget without live route authority."
        }));
    }
    if construction_search_tournament_available
        && !route_distillation_tournament_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_route_distillation_tournament",
            "detail": "Meta Control has ConstructionSearchTournament evidence; the next non-heavy cursor must prove full/proof/oracle route labels improve the small scout on held-out choices before route distillation can promote."
        }));
    }
    if route_distillation_tournament_available
        && !proof_search_signal_route_feedback_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_proof_search_signal_route_feedback",
            "detail": "Meta Control has RouteDistillationTournament evidence; the next non-heavy cursor must prove Lean/proof outcomes become route features without hidden truth, verifier bypass, or AnswerPacket omission."
        }));
    }
    if proof_search_signal_route_feedback_available
        && !proof_pressure_signal_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_proof_pressure_signal",
            "detail": "Meta Control has ProofSearchSignal route feedback evidence; the next non-heavy cursor must prove compiler errors, tactic-state entropy, missing premises, and failed attempt memory become explicit route-pressure labels with rollback, RunEventLog, and AnswerPacket evidence."
        }));
    }
    if proof_pressure_signal_available
        && !verifier_regret_fast_weights_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_verifier_regret_fast_weights",
            "detail": "Meta Control has ProofPressureSignal evidence; the next non-heavy cursor must prove verifier-regret fast weights are bounded, resettable, TTL-limited, shadow-scoped, rollback-bound, and held-out useful before consolidation."
        }));
    }
    if verifier_regret_fast_weights_available
        && !fast_weight_quarantine_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_fast_weight_quarantine",
            "detail": "Meta Control has VerifierRegretFastWeights evidence; the next non-heavy cursor must prove fast-weight deltas remain quarantined and shadow-only until drift, held-out, rollback, TTL, and AnswerPacket gates pass."
        }));
    }
    if fast_weight_quarantine_available
        && !depth_lease_checkpoint_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_depth_lease_checkpoint",
            "detail": "Meta Control has FastWeightQuarantine evidence; the next non-heavy cursor must prove DepthLease checkpoints before any adaptive depth/runtime promotion can claim live authority."
        }));
    }
    if depth_lease_checkpoint_available
        && !shadow_wake_oracle_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_shadow_wake_oracle",
            "detail": "Meta Control has DepthLeaseCheckpoint evidence; the next non-heavy cursor must prove oracle traces become route labels without hidden live runtime dependency."
        }));
    }
    if shadow_wake_oracle_available && !ablation_shadow_run_available && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_ablation_shadow_run",
            "detail": "Meta Control has ShadowWakeOracle evidence; the next non-heavy cursor must prove ablation shadow runs identify unit importance without hidden live route authority."
        }));
    }
    if ablation_shadow_run_available
        && !axiom_axiomatic_source_distinction_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_axiom_axiomatic_source_distinction",
            "detail": "Meta Control has AblationShadowRun evidence; the next non-heavy cursor must keep axioms, retrieved sources, oracle labels, verifier traces, and route priors source-distinct before sparse route control can cite them."
        }));
    }
    if axiom_axiomatic_source_distinction_available
        && !sparse_route_no_hidden_authority_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_sparse_route_no_hidden_authority",
            "detail": "Meta Control has source-distinction evidence; the next non-heavy cursor must prove sparse route control cannot treat source priors, proof traces, oracle labels, or formal-math motifs as hidden live authority."
        }));
    }
    if sparse_route_no_hidden_authority_available
        && !coldstream_no_hidden_authority_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_coldstream_no_hidden_authority",
            "detail": "Meta Control has SparseRoute no-hidden-authority evidence; the next non-heavy cursor must prove ColdStream transport cannot wake bytes or mutate route policy without SemanticWorkingSetPlan, SCOPE-Rex/SovereignGate admission, rollback, RunEventLog, and AnswerPacket proof."
        }));
    }
    if coldstream_no_hidden_authority_available
        && !large_model_provider_reference_deferral_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_large_model_provider_reference_deferral",
            "detail": "Meta Control has ColdStream no-hidden-authority evidence; the next non-heavy cursor must prove provider/fp16/70B and 128K heavy probes stay deferred while practical MLX and cold-assembly architecture remain preserved."
        }));
    }
    if large_model_provider_reference_deferral_available
        && !provider_route_copy_source_guard_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_provider_route_copy_source_guard",
            "detail": "Large-model provider deferral is present; the next non-heavy cursor must prove provider/GGUF/KV/70B route copy stays source-only and cannot promote L2/L3 capability claims, hidden cloud fallback, provider calls, or route-policy mutation."
        }));
    }
    if provider_route_copy_source_guard_available
        && !transport_trace_answer_packet_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_transport_trace_answer_packet",
            "detail": "Provider-route copy/source guard is present; the next non-heavy cursor must prove ColdStream TransportTrace material cannot shape visible answers without byte, stall, copy, fallback, rollback, RunEventLog, and AnswerPacket caveat proof."
        }));
    }
    if transport_trace_answer_packet_available
        && !ssd_wear_budget_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_ssd_wear_budget",
            "detail": "TransportTrace AnswerPacket visibility is present; the next non-heavy cursor must prove repeated ColdStream transport plans budget read/write volume, burst volume, energy, cache pollution, write amplification, rollback, and visible AnswerPacket caveats before live transport promotion."
        }));
    }
    if ssd_wear_budget_available && !coldstream_vs_mmap_available && !heavy_long_context_enabled {
        anomalies.push(serde_json::json!({
            "kind": "missing_coldstream_vs_mmap",
            "detail": "SSD wear budgeting is present; the next non-heavy cursor must prove the ColdStream-vs-mmap benchmark-plan table is same-fixture, source-grounded, visible, rollback-bound, and metadata-only before live mmap/pread/ColdStream benchmarks can promote."
        }));
    }
    if coldstream_vs_mmap_available
        && !slab_arena_copy_count_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_slab_arena_copy_count",
            "detail": "ColdStream-vs-mmap benchmark-plan evidence is present; the next non-heavy cursor must prove CPU SlabArena preallocation, lease ranges, copy counts, allocation samples, rollback, RunEventLog, SCOPE-Rex/SovereignGate admission, and AnswerPacket visibility before live transport promotion."
        }));
    }
    if slab_arena_copy_count_available
        && !metal_io_feature_gate_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_metal_io_feature_gate",
            "detail": "SlabArena copy-count evidence is present; the next non-heavy cursor must prove Metal I/O is platform feature-gated and visibly falls back to CPU slabs before live transport promotion."
        }));
    }
    if metal_io_feature_gate_available
        && !codec_stage_latency_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_codec_stage_latency",
            "detail": "Metal I/O feature-gate evidence is present; the next non-heavy cursor must prove decode/conversion latency, checksums, and copy counts are measured separately from file-read time before live transport promotion."
        }));
    }
    if codec_stage_latency_available
        && !transport_cancellation_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_transport_cancellation",
            "detail": "CodecStage latency evidence is present; the next non-heavy cursor must prove route changes cancel obsolete in-flight reads and reject stale slabs before live transport promotion."
        }));
    }
    if transport_cancellation_available
        && !cache_policy_pollution_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_cache_policy_pollution",
            "detail": "Transport cancellation evidence is present; the next non-heavy cursor must prove explicit cache policy choices preserve repeated hot-route performance and expose cache-pollution caveats before live transport promotion."
        }));
    }
    if cache_policy_pollution_available
        && !cold_panic_fallback_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_cold_panic_fallback",
            "detail": "Cache-policy pollution evidence is present; the next non-heavy cursor must prove missed ColdStream deadlines degrade visibly through ColdPanicFallback instead of silently blocking token-time execution."
        }));
    }
    if cold_panic_fallback_available
        && !product_route_review_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_product_route_review",
            "detail": "ColdPanicFallback is present; the next non-heavy cursor must prove ProductRouteReview keeps red routes red, preserves MAS/Pro and L1/L2/L3 separation, and refuses live 70B/ColdStream/KV promotion before planning the small-model runtime harness."
        }));
    }
    if product_route_review_available
        && !small_model_runtime_harness_safety_plan_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_small_model_runtime_harness_safety_plan",
            "detail": "ProductRouteReview is present; the next non-heavy cursor must prove the small-model runtime harness is serialized, owner-gated, dry-run-first, cancellable, rollback-bound, RunEventLog-bound, AnswerPacket-visible, privacy-fenced, MAS-honest, and metadata-only before any MLX runtime probe."
        }));
    }
    if small_model_runtime_harness_safety_plan_available
        && !small_model_runtime_harness_dry_run_witness_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_small_model_runtime_harness_dry_run_witness",
            "detail": "SmallModelRuntimeHarnessSafetyPlan is present; the next non-heavy cursor must prove a dry-run-only harness transcript with admission, serialized executor, cancellation, rollback, RunEventLog, AnswerPacket, privacy, budget, and zero runtime/model bytes before any owner-approved MLX runtime probe."
        }));
    }
    if small_model_runtime_harness_dry_run_witness_available
        && !small_model_runtime_harness_owner_approved_probe_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_small_model_runtime_harness_owner_approved_probe",
            "detail": "SmallModelRuntimeHarnessDryRunWitness is present; the next non-heavy cursor must prove owner-approval leases, selected local model catalog refs, admission, serialized execution, cancellation, rollback, RunEventLog, AnswerPacket, privacy, and bounded budgets before any abortable runtime probe."
        }));
    }
    if small_model_runtime_harness_owner_approved_probe_available
        && !small_model_runtime_harness_abortable_runtime_probe_available
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "missing_small_model_runtime_harness_abortable_runtime_probe",
            "detail": "SmallModelRuntimeHarnessOwnerApprovedProbe is present; the next non-heavy cursor must prove the owner-approved small-model smoke lanes are cancelable before runtime/model bytes open, rollback-bound, RunEventLog-bound, AnswerPacket-visible, privacy-fenced, budgeted, and mutation-free."
        }));
    }
    if small_model_runtime_harness_abortable_runtime_probe_available && !heavy_long_context_enabled {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_abortable_runtime_probe_metadata_only",
            "detail": "SmallModelRuntimeHarnessAbortableRuntimeProbe is present as L1 metadata only. It proves pre-runtime abort/cancellation discipline but loads no MLX/runtime/model bytes; L2 capability and L3 user-facing/product runtime remain unpromoted while the next cursor moves to small_model_runtime_harness_logged_runtime_smoke."
        }));
    } else if small_model_runtime_harness_owner_approved_probe_available && !heavy_long_context_enabled {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_owner_approved_probe_metadata_only",
            "detail": "SmallModelRuntimeHarnessOwnerApprovedProbe is present as L1 metadata only. It arms owner-approved small-model probe leases but loads no runtime/model bytes; L2 capability and L3 user-facing/product runtime remain unpromoted while the next cursor moves to small_model_runtime_harness_abortable_runtime_probe."
        }));
    } else if small_model_runtime_harness_dry_run_witness_available && !heavy_long_context_enabled {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_dry_run_witness_metadata_only",
            "detail": "SmallModelRuntimeHarnessDryRunWitness is present as L1 metadata only. L2 capability and L3 user-facing/product runtime remain unpromoted while the next cursor moves to small_model_runtime_harness_owner_approved_probe."
        }));
    } else if small_model_runtime_harness_safety_plan_available && !heavy_long_context_enabled {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_safety_plan_metadata_only",
            "detail": "SmallModelRuntimeHarnessSafetyPlan is present as L1 metadata only. L2 capability and L3 user-facing/product runtime remain unpromoted while the next cursor moves to small_model_runtime_harness_dry_run_witness."
        }));
    } else if product_route_review_available && !heavy_long_context_enabled {
        anomalies.push(serde_json::json!({
            "kind": "product_route_review_metadata_only",
            "detail": "ProductRouteReview is present as L1 metadata only. L2 capability and L3 user-facing/product runtime remain unpromoted while the next cursor moves to small_model_runtime_harness_safety_plan."
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
    large_model_provider_reference_deferral_available: bool,
    heavy_long_context_enabled: bool,
) -> String {
    if !heavy_long_context_enabled && next_bottleneck == "missing_fp16_or_provider_reference" {
        if large_model_provider_reference_deferral_available {
            return "provider_route_copy_source_guard".to_string();
        }
        return LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED.to_string();
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
                false,
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
                false,
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
                false,
            ),
            "provider_route_copy_source_guard"
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
                false,
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
            .get("budgeted_uncertainty_escalator")
            .is_some());
        assert!(already_mapped_work
            .get("sparse_wake_proposal_budget")
            .is_some());
        assert!(already_mapped_work.get("verifier_budget_auction").is_some());
        assert!(already_mapped_work.get("kv_page_sketch_index").is_some());
        assert!(already_mapped_work
            .get("kv_page_bloom_sketch_coverage")
            .is_some());
        assert!(already_mapped_work.get("query_aware_kv_selector").is_some());
        assert!(already_mapped_work
            .get("sparse_wake_certificate_answer_packet")
            .is_some());
        assert!(already_mapped_work.get("layer_kv_joint_lease").is_some());
        assert!(already_mapped_work
            .get("construction_search_tournament")
            .is_some());
        assert!(already_mapped_work
            .get("proof_search_signal_route_feedback")
            .is_some());
        assert!(already_mapped_work.get("proof_pressure_signal").is_some());
        assert!(already_mapped_work
            .get("verifier_regret_fast_weights")
            .is_some());
        assert!(already_mapped_work.get("fast_weight_quarantine").is_some());
        assert!(already_mapped_work.get("depth_lease_checkpoint").is_some());
        assert!(already_mapped_work.get("shadow_wake_oracle").is_some());
        assert!(already_mapped_work.get("ablation_shadow_run").is_some());
        assert!(already_mapped_work
            .get("axiom_axiomatic_source_distinction")
            .is_some());
        assert!(already_mapped_work
            .get("sparse_route_no_hidden_authority")
            .is_some());
        assert!(already_mapped_work
            .get("coldstream_no_hidden_authority")
            .is_some());
        assert!(already_mapped_work.get("slab_arena_copy_count").is_some());
        assert!(already_mapped_work.get("metal_io_feature_gate").is_some());
        assert!(already_mapped_work
            .get("provider_reference_prompt_level_readiness")
            .is_some());
        assert!(already_mapped_work.get("transport_cancellation").is_some());
        assert!(already_mapped_work.get("cache_policy_pollution").is_some());
        assert!(already_mapped_work.get("cold_panic_fallback").is_some());
        assert!(already_mapped_work.get("product_route_review").is_some());
        assert!(already_mapped_work
            .get("small_model_runtime_harness_safety_plan")
            .is_some());
        assert!(already_mapped_work
            .get("small_model_runtime_harness_dry_run_witness")
            .is_some());
        assert!(already_mapped_work
            .get("small_model_runtime_harness_owner_approved_probe")
            .is_some());
        assert!(already_mapped_work
            .get("small_model_runtime_harness_abortable_runtime_probe")
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
