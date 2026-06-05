//! Capability Ceiling Evaluation Kernel.
//!
//! This is the route-level governor for the 16 GB / 70B-class ACS/UAS path.
//! It reads the local falsifier artifacts that already exist, preserves their
//! individual truth values, and emits one schema-valid artifact that answers:
//! "can this MacBook route run yet, and if not, which measured gate is next?"

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::{
    CACHE_POLICY_POLLUTION_AXES, CODEC_STAGE_LATENCY_AXES, COLDSTREAM_NO_HIDDEN_AUTHORITY_AXES,
    COLDSTREAM_VS_MMAP_AXES, COLD_PANIC_FALLBACK_AXES,
    LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_BY_MLX_ROUTE_AXES, METAL_IO_FEATURE_GATE_AXES,
    PRODUCT_ROUTE_REVIEW_AXES, PROVIDER_ROUTE_COPY_SOURCE_GUARD_AXES, SLAB_ARENA_COPY_COUNT_AXES,
    SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_AXES,
    SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_AXES,
    SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_AXES,
    SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_AXES,
    SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_AXES,
    SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_AXES,
    SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_AXES,
    SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_AXES,
    SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_AXES, SPARSE_ROUTE_NO_HIDDEN_AUTHORITY_AXES,
    SSD_WEAR_BUDGET_AXES, TRANSPORT_CANCELLATION_AXES, TRANSPORT_TRACE_ANSWER_PACKET_AXES,
};
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
const SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_logged_runtime_smoke/result.json";
const SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_first_token_runtime_probe/result.json";
const SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_answer_packet_runtime_probe/result.json";
const SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_product_wrv_probe/result.json";
const SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_product_answer_packet_live_probe/result.json";
const FULP_ORACLE_PATH: &str = "artifacts/falsifiers/ulp_oracle/result.json";
const CONTROLLER_KERNEL_PATH: &str = "artifacts/falsifiers/controller_kernel_pack/result.json";
const COCKTAIL_LITE_PATH: &str = "artifacts/falsifiers/70b_local_cocktail_lite/result.json";
const HEAVY_LONG_CONTEXT_ENV: &str = "EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT";
const LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED: &str =
    "large_model_provider_reference_deferred_by_mlx_route";
const PROVIDER_ROUTE_COPY_SOURCE_GUARD: &str = "provider_route_copy_source_guard";
const TRANSPORT_TRACE_ANSWER_PACKET: &str = "transport_trace_answer_packet";
const SSD_WEAR_BUDGET: &str = "ssd_wear_budget";
const COLDSTREAM_VS_MMAP: &str = "coldstream_vs_mmap";
const SLAB_ARENA_COPY_COUNT: &str = "slab_arena_copy_count";
const METAL_IO_FEATURE_GATE: &str = "metal_io_feature_gate";
const CODEC_STAGE_LATENCY: &str = "codec_stage_latency";
const TRANSPORT_CANCELLATION: &str = "transport_cancellation";
const CACHE_POLICY_POLLUTION: &str = "cache_policy_pollution";
const COLD_PANIC_FALLBACK: &str = "cold_panic_fallback";
const PRODUCT_ROUTE_REVIEW: &str = "ready_for_product_route_review";
const SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN: &str = "small_model_runtime_harness_safety_plan";
const SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_NEXT: &str =
    "small_model_runtime_harness_dry_run_witness";
const SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_NEXT: &str =
    "small_model_runtime_harness_owner_approved_probe";
const SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_NEXT: &str =
    "small_model_runtime_harness_abortable_runtime_probe";
const SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_NEXT: &str =
    "small_model_runtime_harness_logged_runtime_smoke";
const SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_NEXT: &str =
    "small_model_runtime_harness_first_token_runtime_probe";
const SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_NEXT: &str =
    "small_model_runtime_harness_answer_packet_runtime_probe";
const SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_NEXT: &str =
    "small_model_runtime_harness_product_wrv_probe";
const SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_NEXT: &str =
    "small_model_runtime_harness_product_answer_packet_live_probe";
const SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_NEXT: &str =
    "small_model_runtime_harness_product_route_capability_recheck";
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
    let two_stage_route_scout_abstain = GateArtifact::read(TWO_STAGE_ROUTE_SCOUT_ABSTAIN_PATH);
    let budgeted_uncertainty_escalator = GateArtifact::read(BUDGETED_UNCERTAINTY_ESCALATOR_PATH);
    let sparse_wake_proposal_budget = GateArtifact::read(SPARSE_WAKE_PROPOSAL_BUDGET_PATH);
    let verifier_budget_auction = GateArtifact::read(VERIFIER_BUDGET_AUCTION_PATH);
    let kv_page_sketch_index = GateArtifact::read(KV_PAGE_SKETCH_INDEX_PATH);
    let kv_page_bloom_sketch_coverage = GateArtifact::read(KV_PAGE_BLOOM_SKETCH_COVERAGE_PATH);
    let query_aware_kv_selector = GateArtifact::read(QUERY_AWARE_KV_SELECTOR_PATH);
    let sparse_wake_certificate_answer_packet =
        GateArtifact::read(SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET_PATH);
    let layer_kv_joint_lease = GateArtifact::read(LAYER_KV_JOINT_LEASE_PATH);
    let construction_search_tournament = GateArtifact::read(CONSTRUCTION_SEARCH_TOURNAMENT_PATH);
    let route_distillation_tournament = GateArtifact::read(ROUTE_DISTILLATION_TOURNAMENT_PATH);
    let proof_search_signal_route_feedback =
        GateArtifact::read(PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK_PATH);
    let proof_pressure_signal = GateArtifact::read(PROOF_PRESSURE_SIGNAL_PATH);
    let verifier_regret_fast_weights = GateArtifact::read(VERIFIER_REGRET_FAST_WEIGHTS_PATH);
    let fast_weight_quarantine = GateArtifact::read(FAST_WEIGHT_QUARANTINE_PATH);
    let depth_lease_checkpoint = GateArtifact::read(DEPTH_LEASE_CHECKPOINT_PATH);
    let shadow_wake_oracle = GateArtifact::read(SHADOW_WAKE_ORACLE_PATH);
    let ablation_shadow_run = GateArtifact::read(ABLATION_SHADOW_RUN_PATH);
    let axiom_axiomatic_source_distinction =
        GateArtifact::read(AXIOM_AXIOMATIC_SOURCE_DISTINCTION_PATH);
    let sparse_route_no_hidden_authority =
        GateArtifact::read(SPARSE_ROUTE_NO_HIDDEN_AUTHORITY_PATH);
    let coldstream_no_hidden_authority = GateArtifact::read(COLDSTREAM_NO_HIDDEN_AUTHORITY_PATH);
    let large_model_provider_reference_deferral =
        GateArtifact::read(LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_BY_MLX_ROUTE_PATH);
    let provider_route_copy_source_guard =
        GateArtifact::read(PROVIDER_ROUTE_COPY_SOURCE_GUARD_PATH);
    let transport_trace_answer_packet = GateArtifact::read(TRANSPORT_TRACE_ANSWER_PACKET_PATH);
    let ssd_wear_budget = GateArtifact::read(SSD_WEAR_BUDGET_PATH);
    let coldstream_vs_mmap = GateArtifact::read(COLDSTREAM_VS_MMAP_PATH);
    let slab_arena_copy_count = GateArtifact::read(SLAB_ARENA_COPY_COUNT_PATH);
    let metal_io_feature_gate = GateArtifact::read(METAL_IO_FEATURE_GATE_PATH);
    let codec_stage_latency = GateArtifact::read(CODEC_STAGE_LATENCY_PATH);
    let transport_cancellation = GateArtifact::read(TRANSPORT_CANCELLATION_PATH);
    let cache_policy_pollution = GateArtifact::read(CACHE_POLICY_POLLUTION_PATH);
    let cold_panic_fallback = GateArtifact::read(COLD_PANIC_FALLBACK_PATH);
    let product_route_review = GateArtifact::read(PRODUCT_ROUTE_REVIEW_PATH);
    let small_model_runtime_harness_safety_plan =
        GateArtifact::read(SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_PATH);
    let small_model_runtime_harness_dry_run_witness =
        GateArtifact::read(SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_PATH);
    let small_model_runtime_harness_owner_approved_probe =
        GateArtifact::read(SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_PATH);
    let small_model_runtime_harness_abortable_runtime_probe =
        GateArtifact::read(SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_PATH);
    let small_model_runtime_harness_logged_runtime_smoke =
        GateArtifact::read(SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_PATH);
    let small_model_runtime_harness_first_token_runtime_probe =
        GateArtifact::read(SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_PATH);
    let small_model_runtime_harness_answer_packet_runtime_probe =
        GateArtifact::read(SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_PATH);
    let small_model_runtime_harness_product_wrv_probe =
        GateArtifact::read(SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_PATH);
    let small_model_runtime_harness_product_answer_packet_live_probe =
        GateArtifact::read(SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_PATH);

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
        &two_stage_route_scout_abstain,
        &budgeted_uncertainty_escalator,
        &sparse_wake_proposal_budget,
        &verifier_budget_auction,
        &kv_page_sketch_index,
        &kv_page_bloom_sketch_coverage,
        &query_aware_kv_selector,
        &sparse_wake_certificate_answer_packet,
        &layer_kv_joint_lease,
        &construction_search_tournament,
        &route_distillation_tournament,
        &proof_search_signal_route_feedback,
        &proof_pressure_signal,
        &verifier_regret_fast_weights,
        &fast_weight_quarantine,
        &depth_lease_checkpoint,
        &shadow_wake_oracle,
        &ablation_shadow_run,
        &axiom_axiomatic_source_distinction,
        &sparse_route_no_hidden_authority,
        &coldstream_no_hidden_authority,
        &large_model_provider_reference_deferral,
        &provider_route_copy_source_guard,
        &transport_trace_answer_packet,
        &ssd_wear_budget,
        &coldstream_vs_mmap,
        &slab_arena_copy_count,
        &metal_io_feature_gate,
        &codec_stage_latency,
        &transport_cancellation,
        &cache_policy_pollution,
        &cold_panic_fallback,
        &product_route_review,
        &small_model_runtime_harness_safety_plan,
        &small_model_runtime_harness_dry_run_witness,
        &small_model_runtime_harness_owner_approved_probe,
        &small_model_runtime_harness_abortable_runtime_probe,
        &small_model_runtime_harness_logged_runtime_smoke,
        &small_model_runtime_harness_first_token_runtime_probe,
        &small_model_runtime_harness_answer_packet_runtime_probe,
        &small_model_runtime_harness_product_wrv_probe,
        &small_model_runtime_harness_product_answer_packet_live_probe,
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
    let two_stage_route_scout_abstain_pass = two_stage_route_scout_abstain.overall_pass
        && two_stage_route_scout_abstain.all_axes_true(TWO_STAGE_ROUTE_SCOUT_ABSTAIN_AXES);
    let budgeted_uncertainty_escalator_pass = budgeted_uncertainty_escalator.overall_pass
        && budgeted_uncertainty_escalator.all_axes_true(BUDGETED_UNCERTAINTY_ESCALATOR_AXES);
    let sparse_wake_proposal_budget_pass = sparse_wake_proposal_budget.overall_pass
        && sparse_wake_proposal_budget.all_axes_true(SPARSE_WAKE_PROPOSAL_BUDGET_AXES);
    let verifier_budget_auction_pass = verifier_budget_auction.overall_pass
        && verifier_budget_auction.all_axes_true(VERIFIER_BUDGET_AUCTION_AXES);
    let kv_page_sketch_index_pass = kv_page_sketch_index.overall_pass
        && kv_page_sketch_index.all_axes_true(KV_PAGE_SKETCH_INDEX_AXES);
    let kv_page_bloom_sketch_coverage_pass = kv_page_bloom_sketch_coverage.overall_pass
        && kv_page_bloom_sketch_coverage.all_axes_true(KV_PAGE_BLOOM_SKETCH_COVERAGE_AXES);
    let query_aware_kv_selector_pass = query_aware_kv_selector.overall_pass
        && query_aware_kv_selector.all_axes_true(QUERY_AWARE_KV_SELECTOR_AXES);
    let sparse_wake_certificate_answer_packet_pass = sparse_wake_certificate_answer_packet
        .overall_pass
        && sparse_wake_certificate_answer_packet
            .all_axes_true(SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET_AXES);
    let layer_kv_joint_lease_pass = layer_kv_joint_lease.overall_pass
        && layer_kv_joint_lease.all_axes_true(LAYER_KV_JOINT_LEASE_AXES);
    let construction_search_tournament_pass = construction_search_tournament.overall_pass
        && construction_search_tournament.all_axes_true(CONSTRUCTION_SEARCH_TOURNAMENT_AXES);
    let route_distillation_tournament_pass = route_distillation_tournament.overall_pass
        && route_distillation_tournament.all_axes_true(ROUTE_DISTILLATION_TOURNAMENT_AXES);
    let proof_search_signal_route_feedback_pass = proof_search_signal_route_feedback.overall_pass
        && proof_search_signal_route_feedback
            .all_axes_true(PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK_AXES);
    let proof_pressure_signal_pass = proof_pressure_signal.overall_pass
        && proof_pressure_signal.all_axes_true(PROOF_PRESSURE_SIGNAL_AXES);
    let verifier_regret_fast_weights_pass = verifier_regret_fast_weights.overall_pass
        && verifier_regret_fast_weights.all_axes_true(VERIFIER_REGRET_FAST_WEIGHTS_AXES);
    let fast_weight_quarantine_pass = fast_weight_quarantine.overall_pass
        && fast_weight_quarantine.all_axes_true(FAST_WEIGHT_QUARANTINE_AXES);
    let depth_lease_checkpoint_pass = depth_lease_checkpoint.overall_pass
        && depth_lease_checkpoint.all_axes_true(DEPTH_LEASE_CHECKPOINT_AXES);
    let shadow_wake_oracle_pass = shadow_wake_oracle.overall_pass
        && shadow_wake_oracle.all_axes_true(SHADOW_WAKE_ORACLE_AXES);
    let ablation_shadow_run_pass = ablation_shadow_run.overall_pass
        && ablation_shadow_run.all_axes_true(ABLATION_SHADOW_RUN_AXES);
    let axiom_axiomatic_source_distinction_pass = axiom_axiomatic_source_distinction.overall_pass
        && axiom_axiomatic_source_distinction
            .all_axes_true(AXIOM_AXIOMATIC_SOURCE_DISTINCTION_AXES);
    let sparse_route_no_hidden_authority_pass = sparse_route_no_hidden_authority.overall_pass
        && sparse_route_no_hidden_authority.all_axes_true(SPARSE_ROUTE_NO_HIDDEN_AUTHORITY_AXES);
    let coldstream_no_hidden_authority_pass = coldstream_no_hidden_authority.overall_pass
        && coldstream_no_hidden_authority.all_axes_true(COLDSTREAM_NO_HIDDEN_AUTHORITY_AXES);
    let large_model_provider_reference_deferral_pass = large_model_provider_reference_deferral
        .overall_pass
        && large_model_provider_reference_deferral
            .all_axes_true(LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_BY_MLX_ROUTE_AXES);
    let provider_route_copy_source_guard_pass = provider_route_copy_source_guard.overall_pass
        && provider_route_copy_source_guard.all_axes_true(PROVIDER_ROUTE_COPY_SOURCE_GUARD_AXES);
    let transport_trace_answer_packet_pass = transport_trace_answer_packet.overall_pass
        && transport_trace_answer_packet.all_axes_true(TRANSPORT_TRACE_ANSWER_PACKET_AXES);
    let ssd_wear_budget_pass =
        ssd_wear_budget.overall_pass && ssd_wear_budget.all_axes_true(SSD_WEAR_BUDGET_AXES);
    let coldstream_vs_mmap_pass = coldstream_vs_mmap.overall_pass
        && coldstream_vs_mmap.all_axes_true(COLDSTREAM_VS_MMAP_AXES);
    let slab_arena_copy_count_pass = slab_arena_copy_count.overall_pass
        && slab_arena_copy_count.all_axes_true(SLAB_ARENA_COPY_COUNT_AXES);
    let metal_io_feature_gate_pass = metal_io_feature_gate.overall_pass
        && metal_io_feature_gate.all_axes_true(METAL_IO_FEATURE_GATE_AXES);
    let codec_stage_latency_pass = codec_stage_latency.overall_pass
        && codec_stage_latency.all_axes_true(CODEC_STAGE_LATENCY_AXES);
    let transport_cancellation_pass = transport_cancellation.overall_pass
        && transport_cancellation.all_axes_true(TRANSPORT_CANCELLATION_AXES);
    let cache_policy_pollution_pass = cache_policy_pollution.overall_pass
        && cache_policy_pollution.all_axes_true(CACHE_POLICY_POLLUTION_AXES);
    let cold_panic_fallback_pass = cold_panic_fallback.overall_pass
        && cold_panic_fallback.all_axes_true(COLD_PANIC_FALLBACK_AXES);
    let product_route_review_pass = product_route_review.overall_pass
        && product_route_review.all_axes_true(PRODUCT_ROUTE_REVIEW_AXES);
    let small_model_runtime_harness_safety_plan_pass = small_model_runtime_harness_safety_plan
        .overall_pass
        && small_model_runtime_harness_safety_plan
            .all_axes_true(SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_AXES);
    let small_model_runtime_harness_dry_run_witness_pass =
        small_model_runtime_harness_dry_run_witness.overall_pass
            && small_model_runtime_harness_dry_run_witness
                .all_axes_true(SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_AXES);
    let small_model_runtime_harness_owner_approved_probe_pass =
        small_model_runtime_harness_owner_approved_probe.overall_pass
            && small_model_runtime_harness_owner_approved_probe
                .all_axes_true(SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_AXES);
    let small_model_runtime_harness_abortable_runtime_probe_pass =
        small_model_runtime_harness_abortable_runtime_probe.overall_pass
            && small_model_runtime_harness_abortable_runtime_probe
                .all_axes_true(SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_AXES);
    let small_model_runtime_harness_logged_runtime_smoke_pass =
        small_model_runtime_harness_logged_runtime_smoke.overall_pass
            && small_model_runtime_harness_logged_runtime_smoke
                .all_axes_true(SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_AXES);
    let small_model_runtime_harness_first_token_runtime_probe_pass =
        small_model_runtime_harness_first_token_runtime_probe.overall_pass
            && small_model_runtime_harness_first_token_runtime_probe
                .all_axes_true(SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_AXES);
    let small_model_runtime_harness_answer_packet_runtime_probe_pass =
        small_model_runtime_harness_answer_packet_runtime_probe.overall_pass
            && small_model_runtime_harness_answer_packet_runtime_probe
                .all_axes_true(SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_AXES);
    let small_model_runtime_harness_product_wrv_probe_pass =
        small_model_runtime_harness_product_wrv_probe.overall_pass
            && small_model_runtime_harness_product_wrv_probe
                .all_axes_true(SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_AXES);
    let small_model_runtime_harness_product_answer_packet_live_probe_pass =
        small_model_runtime_harness_product_answer_packet_live_probe.overall_pass
            && small_model_runtime_harness_product_answer_packet_live_probe
                .all_axes_true(SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_AXES);
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
        &two_stage_route_scout_abstain,
        &budgeted_uncertainty_escalator,
        &sparse_wake_proposal_budget,
        &verifier_budget_auction,
        &kv_page_sketch_index,
        &kv_page_bloom_sketch_coverage,
        &query_aware_kv_selector,
        &sparse_wake_certificate_answer_packet,
        &layer_kv_joint_lease,
        &construction_search_tournament,
        &route_distillation_tournament,
        &proof_search_signal_route_feedback,
        &proof_pressure_signal,
        &verifier_regret_fast_weights,
        &fast_weight_quarantine,
        &depth_lease_checkpoint,
        &shadow_wake_oracle,
        &ablation_shadow_run,
        &axiom_axiomatic_source_distinction,
        &sparse_route_no_hidden_authority,
        &coldstream_no_hidden_authority,
        &large_model_provider_reference_deferral,
        &provider_route_copy_source_guard,
        &transport_trace_answer_packet,
        &ssd_wear_budget,
        &coldstream_vs_mmap,
        &slab_arena_copy_count,
        &metal_io_feature_gate,
        &codec_stage_latency,
        &transport_cancellation,
        &cache_policy_pollution,
        &cold_panic_fallback,
        &product_route_review,
        &small_model_runtime_harness_safety_plan,
        &small_model_runtime_harness_dry_run_witness,
        &small_model_runtime_harness_owner_approved_probe,
        &small_model_runtime_harness_abortable_runtime_probe,
        &small_model_runtime_harness_logged_runtime_smoke,
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
        two_stage_route_scout_abstain_pass,
        budgeted_uncertainty_escalator_pass,
        sparse_wake_proposal_budget_pass,
        verifier_budget_auction_pass,
        kv_page_sketch_index_pass,
        kv_page_bloom_sketch_coverage_pass,
        query_aware_kv_selector_pass,
        sparse_wake_certificate_answer_packet_pass,
        layer_kv_joint_lease_pass,
        construction_search_tournament_pass,
        route_distillation_tournament_pass,
        proof_search_signal_route_feedback_pass,
        proof_pressure_signal_pass,
        verifier_regret_fast_weights_pass,
        fast_weight_quarantine_pass,
        depth_lease_checkpoint_pass,
        shadow_wake_oracle_pass,
        ablation_shadow_run_pass,
        axiom_axiomatic_source_distinction_pass,
        sparse_route_no_hidden_authority_pass,
        coldstream_no_hidden_authority_pass,
        seventy_b_route_pass,
        all_gate_artifacts_schema_normalized,
    );
    let base_next_bottleneck = next_bottleneck(
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
        two_stage_route_scout_abstain_pass,
        budgeted_uncertainty_escalator_pass,
        sparse_wake_proposal_budget_pass,
        verifier_budget_auction_pass,
        kv_page_sketch_index_pass,
        kv_page_bloom_sketch_coverage_pass,
        query_aware_kv_selector_pass,
        sparse_wake_certificate_answer_packet_pass,
        layer_kv_joint_lease_pass,
        construction_search_tournament_pass,
        route_distillation_tournament_pass,
        proof_search_signal_route_feedback_pass,
        proof_pressure_signal_pass,
        verifier_regret_fast_weights_pass,
        fast_weight_quarantine_pass,
        depth_lease_checkpoint_pass,
        shadow_wake_oracle_pass,
        ablation_shadow_run_pass,
        axiom_axiomatic_source_distinction_pass,
        sparse_route_no_hidden_authority_pass,
        coldstream_no_hidden_authority_pass,
        large_model_provider_reference_deferral_pass,
        provider_route_copy_source_guard_pass,
        transport_trace_answer_packet_pass,
        ssd_wear_budget_pass,
        coldstream_vs_mmap_pass,
        slab_arena_copy_count_pass,
        metal_io_feature_gate_pass,
        codec_stage_latency_pass,
        transport_cancellation_pass,
        cache_policy_pollution_pass,
        cold_panic_fallback_pass,
        product_route_review_pass,
        small_model_runtime_harness_safety_plan_pass,
        small_model_runtime_harness_dry_run_witness_pass,
        small_model_runtime_harness_owner_approved_probe_pass,
        small_model_runtime_harness_abortable_runtime_probe_pass,
        small_model_runtime_harness_logged_runtime_smoke_pass,
        small_model_runtime_harness_first_token_runtime_probe_pass,
        small_model_runtime_harness_answer_packet_runtime_probe_pass,
        seventy_b_route_pass,
        &cocktail,
    );
    let next_bottleneck = if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && small_model_runtime_harness_answer_packet_runtime_probe_pass
        && small_model_runtime_harness_product_wrv_probe_pass
        && small_model_runtime_harness_product_answer_packet_live_probe_pass
        && base_next_bottleneck == SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_NEXT
    {
        SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_NEXT.to_string()
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && small_model_runtime_harness_answer_packet_runtime_probe_pass
        && small_model_runtime_harness_product_wrv_probe_pass
        && base_next_bottleneck == SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_NEXT
    {
        SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_NEXT.to_string()
    } else {
        base_next_bottleneck
    };
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
        two_stage_route_scout_abstain_pass,
        budgeted_uncertainty_escalator_pass,
        sparse_wake_proposal_budget_pass,
        verifier_budget_auction_pass,
        kv_page_sketch_index_pass,
        kv_page_bloom_sketch_coverage_pass,
        query_aware_kv_selector_pass,
        sparse_wake_certificate_answer_packet_pass,
        layer_kv_joint_lease_pass,
        construction_search_tournament_pass,
        route_distillation_tournament_pass,
        proof_search_signal_route_feedback_pass,
        proof_pressure_signal_pass,
        verifier_regret_fast_weights_pass,
        fast_weight_quarantine_pass,
        depth_lease_checkpoint_pass,
        shadow_wake_oracle_pass,
        ablation_shadow_run_pass,
        axiom_axiomatic_source_distinction_pass,
        sparse_route_no_hidden_authority_pass,
        coldstream_no_hidden_authority_pass,
        large_model_provider_reference_deferral_pass,
        provider_route_copy_source_guard_pass,
        transport_trace_answer_packet_pass,
        ssd_wear_budget_pass,
        coldstream_vs_mmap_pass,
        slab_arena_copy_count_pass,
        metal_io_feature_gate_pass,
        codec_stage_latency_pass,
        transport_cancellation_pass,
        cache_policy_pollution_pass,
        cold_panic_fallback_pass,
        product_route_review_pass,
        small_model_runtime_harness_safety_plan_pass,
        small_model_runtime_harness_dry_run_witness_pass,
        small_model_runtime_harness_owner_approved_probe_pass,
        small_model_runtime_harness_abortable_runtime_probe_pass,
        small_model_runtime_harness_logged_runtime_smoke_pass,
        small_model_runtime_harness_first_token_runtime_probe_pass,
        small_model_runtime_harness_answer_packet_runtime_probe_pass,
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
        "two_stage_route_scout_abstain_pass",
        two_stage_route_scout_abstain_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "budgeted_uncertainty_escalator_pass",
        budgeted_uncertainty_escalator_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sparse_wake_proposal_budget_pass",
        sparse_wake_proposal_budget_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_budget_auction_pass",
        verifier_budget_auction_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_page_sketch_index_pass",
        kv_page_sketch_index_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_page_bloom_sketch_coverage_pass",
        kv_page_bloom_sketch_coverage_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "query_aware_kv_selector_pass",
        query_aware_kv_selector_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sparse_wake_certificate_answer_packet_pass",
        sparse_wake_certificate_answer_packet_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "layer_kv_joint_lease_pass",
        layer_kv_joint_lease_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "construction_search_tournament_pass",
        construction_search_tournament_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_distillation_tournament_pass",
        route_distillation_tournament_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_search_signal_route_feedback_pass",
        proof_search_signal_route_feedback_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_pressure_signal_pass",
        proof_pressure_signal_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_regret_fast_weights_pass",
        verifier_regret_fast_weights_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fast_weight_quarantine_pass",
        fast_weight_quarantine_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "depth_lease_checkpoint_pass",
        depth_lease_checkpoint_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "shadow_wake_oracle_pass",
        shadow_wake_oracle_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "ablation_shadow_run_pass",
        ablation_shadow_run_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "axiom_axiomatic_source_distinction_pass",
        axiom_axiomatic_source_distinction_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sparse_route_no_hidden_authority_pass",
        sparse_route_no_hidden_authority_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "coldstream_no_hidden_authority_pass",
        coldstream_no_hidden_authority_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "large_model_provider_reference_deferral_pass",
        large_model_provider_reference_deferral_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_route_copy_source_guard_pass",
        provider_route_copy_source_guard_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "transport_trace_answer_packet_pass",
        transport_trace_answer_packet_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "ssd_wear_budget_pass",
        ssd_wear_budget_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "coldstream_vs_mmap_pass",
        coldstream_vs_mmap_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "slab_arena_copy_count_pass",
        slab_arena_copy_count_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metal_io_feature_gate_pass",
        metal_io_feature_gate_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "codec_stage_latency_pass",
        codec_stage_latency_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "transport_cancellation_pass",
        transport_cancellation_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cache_policy_pollution_pass",
        cache_policy_pollution_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_panic_fallback_pass",
        cold_panic_fallback_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "product_route_review_pass",
        product_route_review_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_safety_plan_pass",
        small_model_runtime_harness_safety_plan_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_dry_run_witness_pass",
        small_model_runtime_harness_dry_run_witness_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_owner_approved_probe_pass",
        small_model_runtime_harness_owner_approved_probe_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_abortable_runtime_probe_pass",
        small_model_runtime_harness_abortable_runtime_probe_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_logged_runtime_smoke_pass",
        small_model_runtime_harness_logged_runtime_smoke_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_first_token_runtime_probe_pass",
        small_model_runtime_harness_first_token_runtime_probe_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_answer_packet_runtime_probe_pass",
        small_model_runtime_harness_answer_packet_runtime_probe_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_product_wrv_probe_pass",
        small_model_runtime_harness_product_wrv_probe_pass,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_product_answer_packet_live_probe_pass",
        small_model_runtime_harness_product_answer_packet_live_probe_pass,
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
    add_gate_summary(
        &mut measurements,
        "two_stage_route_scout_abstain",
        &two_stage_route_scout_abstain,
    );
    add_gate_summary(
        &mut measurements,
        "budgeted_uncertainty_escalator",
        &budgeted_uncertainty_escalator,
    );
    add_gate_summary(
        &mut measurements,
        "sparse_wake_proposal_budget",
        &sparse_wake_proposal_budget,
    );
    add_gate_summary(
        &mut measurements,
        "verifier_budget_auction",
        &verifier_budget_auction,
    );
    add_gate_summary(
        &mut measurements,
        "kv_page_sketch_index",
        &kv_page_sketch_index,
    );
    add_gate_summary(
        &mut measurements,
        "kv_page_bloom_sketch_coverage",
        &kv_page_bloom_sketch_coverage,
    );
    add_gate_summary(
        &mut measurements,
        "query_aware_kv_selector",
        &query_aware_kv_selector,
    );
    add_gate_summary(
        &mut measurements,
        "sparse_wake_certificate_answer_packet",
        &sparse_wake_certificate_answer_packet,
    );
    add_gate_summary(
        &mut measurements,
        "layer_kv_joint_lease",
        &layer_kv_joint_lease,
    );
    add_gate_summary(
        &mut measurements,
        "construction_search_tournament",
        &construction_search_tournament,
    );
    add_gate_summary(
        &mut measurements,
        "route_distillation_tournament",
        &route_distillation_tournament,
    );
    add_gate_summary(
        &mut measurements,
        "proof_search_signal_route_feedback",
        &proof_search_signal_route_feedback,
    );
    add_gate_summary(
        &mut measurements,
        "proof_pressure_signal",
        &proof_pressure_signal,
    );
    add_gate_summary(
        &mut measurements,
        "verifier_regret_fast_weights",
        &verifier_regret_fast_weights,
    );
    add_gate_summary(
        &mut measurements,
        "fast_weight_quarantine",
        &fast_weight_quarantine,
    );
    add_gate_summary(
        &mut measurements,
        "depth_lease_checkpoint",
        &depth_lease_checkpoint,
    );
    add_gate_summary(&mut measurements, "shadow_wake_oracle", &shadow_wake_oracle);
    add_gate_summary(
        &mut measurements,
        "ablation_shadow_run",
        &ablation_shadow_run,
    );
    add_gate_summary(
        &mut measurements,
        "axiom_axiomatic_source_distinction",
        &axiom_axiomatic_source_distinction,
    );
    add_gate_summary(
        &mut measurements,
        "sparse_route_no_hidden_authority",
        &sparse_route_no_hidden_authority,
    );
    add_gate_summary(
        &mut measurements,
        "coldstream_no_hidden_authority",
        &coldstream_no_hidden_authority,
    );
    add_gate_summary(
        &mut measurements,
        "large_model_provider_reference_deferral",
        &large_model_provider_reference_deferral,
    );
    add_gate_summary(
        &mut measurements,
        "provider_route_copy_source_guard",
        &provider_route_copy_source_guard,
    );
    add_gate_summary(
        &mut measurements,
        "transport_trace_answer_packet",
        &transport_trace_answer_packet,
    );
    add_gate_summary(&mut measurements, "ssd_wear_budget", &ssd_wear_budget);
    add_gate_summary(&mut measurements, "coldstream_vs_mmap", &coldstream_vs_mmap);
    add_gate_summary(
        &mut measurements,
        "slab_arena_copy_count",
        &slab_arena_copy_count,
    );
    add_gate_summary(
        &mut measurements,
        "metal_io_feature_gate",
        &metal_io_feature_gate,
    );
    add_gate_summary(
        &mut measurements,
        "codec_stage_latency",
        &codec_stage_latency,
    );
    add_gate_summary(
        &mut measurements,
        "transport_cancellation",
        &transport_cancellation,
    );
    add_gate_summary(
        &mut measurements,
        "cache_policy_pollution",
        &cache_policy_pollution,
    );
    add_gate_summary(
        &mut measurements,
        "cold_panic_fallback",
        &cold_panic_fallback,
    );
    add_gate_summary(
        &mut measurements,
        "product_route_review",
        &product_route_review,
    );
    add_gate_summary(
        &mut measurements,
        "small_model_runtime_harness_safety_plan",
        &small_model_runtime_harness_safety_plan,
    );
    add_gate_summary(
        &mut measurements,
        "small_model_runtime_harness_dry_run_witness",
        &small_model_runtime_harness_dry_run_witness,
    );
    add_gate_summary(
        &mut measurements,
        "small_model_runtime_harness_owner_approved_probe",
        &small_model_runtime_harness_owner_approved_probe,
    );
    add_gate_summary(
        &mut measurements,
        "small_model_runtime_harness_abortable_runtime_probe",
        &small_model_runtime_harness_abortable_runtime_probe,
    );
    add_gate_summary(
        &mut measurements,
        "small_model_runtime_harness_logged_runtime_smoke",
        &small_model_runtime_harness_logged_runtime_smoke,
    );
    add_gate_summary(
        &mut measurements,
        "small_model_runtime_harness_first_token_runtime_probe",
        &small_model_runtime_harness_first_token_runtime_probe,
    );
    add_gate_summary(
        &mut measurements,
        "small_model_runtime_harness_answer_packet_runtime_probe",
        &small_model_runtime_harness_answer_packet_runtime_probe,
    );
    add_gate_summary(
        &mut measurements,
        "small_model_runtime_harness_product_wrv_probe",
        &small_model_runtime_harness_product_wrv_probe,
    );
    add_gate_summary(
        &mut measurements,
        "small_model_runtime_harness_product_answer_packet_live_probe",
        &small_model_runtime_harness_product_answer_packet_live_probe,
    );
    add_gate_summary(&mut measurements, "seventy_b_lite", &cocktail);

    let mut anomalies = build_anomalies(
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
        two_stage_route_scout_abstain_pass,
        budgeted_uncertainty_escalator_pass,
        sparse_wake_proposal_budget_pass,
        verifier_budget_auction_pass,
        kv_page_sketch_index_pass,
        kv_page_bloom_sketch_coverage_pass,
        query_aware_kv_selector_pass,
        sparse_wake_certificate_answer_packet_pass,
        layer_kv_joint_lease_pass,
        construction_search_tournament_pass,
        route_distillation_tournament_pass,
        proof_search_signal_route_feedback_pass,
        proof_pressure_signal_pass,
        verifier_regret_fast_weights_pass,
        fast_weight_quarantine_pass,
        depth_lease_checkpoint_pass,
        shadow_wake_oracle_pass,
        ablation_shadow_run_pass,
        axiom_axiomatic_source_distinction_pass,
        sparse_route_no_hidden_authority_pass,
        coldstream_no_hidden_authority_pass,
        large_model_provider_reference_deferral_pass,
        provider_route_copy_source_guard_pass,
        transport_trace_answer_packet_pass,
        ssd_wear_budget_pass,
        coldstream_vs_mmap_pass,
        slab_arena_copy_count_pass,
        metal_io_feature_gate_pass,
        codec_stage_latency_pass,
        transport_cancellation_pass,
        cache_policy_pollution_pass,
        cold_panic_fallback_pass,
        product_route_review_pass,
        small_model_runtime_harness_safety_plan_pass,
        small_model_runtime_harness_dry_run_witness_pass,
        small_model_runtime_harness_owner_approved_probe_pass,
        small_model_runtime_harness_abortable_runtime_probe_pass,
        small_model_runtime_harness_logged_runtime_smoke_pass,
        small_model_runtime_harness_first_token_runtime_probe_pass,
        small_model_runtime_harness_answer_packet_runtime_probe_pass,
        seventy_b_route_pass,
        &next_bottleneck,
    );
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && small_model_runtime_harness_answer_packet_runtime_probe_pass
        && small_model_runtime_harness_product_wrv_probe_pass
        && !small_model_runtime_harness_product_answer_packet_live_probe_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_product_wrv_probe_source_only",
            "detail": "Small-model runtime harness product WRV is source/test-visible through the app route, Settings diagnostics, MessageBubble AnswerPacket chips, and focused tests. L2 remains red until a live product AnswerPacket route probe proves the app path with runtime evidence; no 70B/128K/MAS live-agent promotion is implied."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && small_model_runtime_harness_product_answer_packet_live_probe_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_product_answer_packet_live_probe_retained_handoff",
            "detail": "Small-model runtime harness product AnswerPacket handoff is present as retained-live L1 evidence: bounded Qwen3-4B runtime bytes are tied to product AnswerPacket/RunEventLog surfaces without fresh model bytes. L2 remains red for broader product-route requirements; no 70B/128K/MAS live-agent promotion is implied."
        }));
    }

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
    two_stage_route_scout_abstain_pass: bool,
    budgeted_uncertainty_escalator_pass: bool,
    sparse_wake_proposal_budget_pass: bool,
    verifier_budget_auction_pass: bool,
    kv_page_sketch_index_pass: bool,
    kv_page_bloom_sketch_coverage_pass: bool,
    query_aware_kv_selector_pass: bool,
    sparse_wake_certificate_answer_packet_pass: bool,
    layer_kv_joint_lease_pass: bool,
    construction_search_tournament_pass: bool,
    route_distillation_tournament_pass: bool,
    proof_search_signal_route_feedback_pass: bool,
    proof_pressure_signal_pass: bool,
    verifier_regret_fast_weights_pass: bool,
    fast_weight_quarantine_pass: bool,
    depth_lease_checkpoint_pass: bool,
    shadow_wake_oracle_pass: bool,
    ablation_shadow_run_pass: bool,
    axiom_axiomatic_source_distinction_pass: bool,
    sparse_route_no_hidden_authority_pass: bool,
    coldstream_no_hidden_authority_pass: bool,
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
        && two_stage_route_scout_abstain_pass
        && budgeted_uncertainty_escalator_pass
        && sparse_wake_proposal_budget_pass
        && verifier_budget_auction_pass
        && kv_page_sketch_index_pass
        && kv_page_bloom_sketch_coverage_pass
        && query_aware_kv_selector_pass
        && sparse_wake_certificate_answer_packet_pass
        && layer_kv_joint_lease_pass
        && construction_search_tournament_pass
        && route_distillation_tournament_pass
        && proof_search_signal_route_feedback_pass
        && proof_pressure_signal_pass
        && verifier_regret_fast_weights_pass
        && fast_weight_quarantine_pass
        && depth_lease_checkpoint_pass
        && shadow_wake_oracle_pass
        && ablation_shadow_run_pass
        && axiom_axiomatic_source_distinction_pass
        && sparse_route_no_hidden_authority_pass
        && coldstream_no_hidden_authority_pass
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
    two_stage_route_scout_abstain_pass: bool,
    budgeted_uncertainty_escalator_pass: bool,
    sparse_wake_proposal_budget_pass: bool,
    verifier_budget_auction_pass: bool,
    kv_page_sketch_index_pass: bool,
    kv_page_bloom_sketch_coverage_pass: bool,
    query_aware_kv_selector_pass: bool,
    sparse_wake_certificate_answer_packet_pass: bool,
    layer_kv_joint_lease_pass: bool,
    construction_search_tournament_pass: bool,
    route_distillation_tournament_pass: bool,
    proof_search_signal_route_feedback_pass: bool,
    proof_pressure_signal_pass: bool,
    verifier_regret_fast_weights_pass: bool,
    fast_weight_quarantine_pass: bool,
    depth_lease_checkpoint_pass: bool,
    shadow_wake_oracle_pass: bool,
    ablation_shadow_run_pass: bool,
    axiom_axiomatic_source_distinction_pass: bool,
    sparse_route_no_hidden_authority_pass: bool,
    coldstream_no_hidden_authority_pass: bool,
    large_model_provider_reference_deferral_pass: bool,
    provider_route_copy_source_guard_pass: bool,
    transport_trace_answer_packet_pass: bool,
    ssd_wear_budget_pass: bool,
    coldstream_vs_mmap_pass: bool,
    slab_arena_copy_count_pass: bool,
    metal_io_feature_gate_pass: bool,
    codec_stage_latency_pass: bool,
    transport_cancellation_pass: bool,
    cache_policy_pollution_pass: bool,
    cold_panic_fallback_pass: bool,
    product_route_review_pass: bool,
    small_model_runtime_harness_safety_plan_pass: bool,
    small_model_runtime_harness_dry_run_witness_pass: bool,
    small_model_runtime_harness_owner_approved_probe_pass: bool,
    small_model_runtime_harness_abortable_runtime_probe_pass: bool,
    small_model_runtime_harness_logged_runtime_smoke_pass: bool,
    small_model_runtime_harness_first_token_runtime_probe_pass: bool,
    small_model_runtime_harness_answer_packet_runtime_probe_pass: bool,
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
        } else if !two_stage_route_scout_abstain_pass {
            "two_stage_route_scout_abstain".to_string()
        } else if !budgeted_uncertainty_escalator_pass {
            "budgeted_uncertainty_escalator".to_string()
        } else if !sparse_wake_proposal_budget_pass {
            "sparse_wake_proposal_budget".to_string()
        } else if !verifier_budget_auction_pass {
            "verifier_budget_auction".to_string()
        } else if !kv_page_sketch_index_pass {
            "kv_page_sketch_index".to_string()
        } else if !kv_page_bloom_sketch_coverage_pass {
            "kv_page_bloom_sketch_coverage".to_string()
        } else if !query_aware_kv_selector_pass {
            "query_aware_kv_selector".to_string()
        } else if !sparse_wake_certificate_answer_packet_pass {
            "sparse_wake_certificate_answer_packet".to_string()
        } else if !layer_kv_joint_lease_pass {
            "layer_kv_joint_lease".to_string()
        } else if !construction_search_tournament_pass {
            "construction_search_tournament".to_string()
        } else if !route_distillation_tournament_pass {
            "route_distillation_tournament".to_string()
        } else if !proof_search_signal_route_feedback_pass {
            "proof_search_signal_route_feedback".to_string()
        } else if !proof_pressure_signal_pass {
            "proof_pressure_signal".to_string()
        } else if !verifier_regret_fast_weights_pass {
            "verifier_regret_fast_weights".to_string()
        } else if !fast_weight_quarantine_pass {
            "fast_weight_quarantine".to_string()
        } else if !depth_lease_checkpoint_pass {
            "depth_lease_checkpoint".to_string()
        } else if !shadow_wake_oracle_pass {
            "shadow_wake_oracle".to_string()
        } else if !ablation_shadow_run_pass {
            "ablation_shadow_run".to_string()
        } else if !axiom_axiomatic_source_distinction_pass {
            "axiom_axiomatic_source_distinction".to_string()
        } else if !sparse_route_no_hidden_authority_pass {
            "sparse_route_no_hidden_authority".to_string()
        } else if !coldstream_no_hidden_authority_pass {
            "coldstream_no_hidden_authority".to_string()
        } else if !seventy_b_route_pass && !large_model_provider_reference_deferral_pass {
            LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED.to_string()
        } else if !seventy_b_route_pass && !provider_route_copy_source_guard_pass {
            PROVIDER_ROUTE_COPY_SOURCE_GUARD.to_string()
        } else if !seventy_b_route_pass && !transport_trace_answer_packet_pass {
            TRANSPORT_TRACE_ANSWER_PACKET.to_string()
        } else if !seventy_b_route_pass && !ssd_wear_budget_pass {
            SSD_WEAR_BUDGET.to_string()
        } else if !seventy_b_route_pass && !coldstream_vs_mmap_pass {
            COLDSTREAM_VS_MMAP.to_string()
        } else if !seventy_b_route_pass && !slab_arena_copy_count_pass {
            SLAB_ARENA_COPY_COUNT.to_string()
        } else if !seventy_b_route_pass && !metal_io_feature_gate_pass {
            METAL_IO_FEATURE_GATE.to_string()
        } else if !seventy_b_route_pass && !codec_stage_latency_pass {
            CODEC_STAGE_LATENCY.to_string()
        } else if !seventy_b_route_pass && !transport_cancellation_pass {
            TRANSPORT_CANCELLATION.to_string()
        } else if !seventy_b_route_pass && !cache_policy_pollution_pass {
            CACHE_POLICY_POLLUTION.to_string()
        } else if !seventy_b_route_pass && !cold_panic_fallback_pass {
            COLD_PANIC_FALLBACK.to_string()
        } else if !seventy_b_route_pass && !product_route_review_pass {
            PRODUCT_ROUTE_REVIEW.to_string()
        } else if !seventy_b_route_pass && !small_model_runtime_harness_safety_plan_pass {
            SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN.to_string()
        } else if !seventy_b_route_pass && !small_model_runtime_harness_dry_run_witness_pass {
            SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_NEXT.to_string()
        } else if !seventy_b_route_pass && !small_model_runtime_harness_owner_approved_probe_pass {
            SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_NEXT.to_string()
        } else if !seventy_b_route_pass && !small_model_runtime_harness_abortable_runtime_probe_pass
        {
            SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_NEXT.to_string()
        } else if !seventy_b_route_pass && !small_model_runtime_harness_logged_runtime_smoke_pass {
            SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_NEXT.to_string()
        } else if !seventy_b_route_pass
            && !small_model_runtime_harness_first_token_runtime_probe_pass
        {
            SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_NEXT.to_string()
        } else if !seventy_b_route_pass
            && !small_model_runtime_harness_answer_packet_runtime_probe_pass
        {
            SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_NEXT.to_string()
        } else if !seventy_b_route_pass {
            SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_NEXT.to_string()
        } else {
            SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_NEXT.to_string()
        }
    } else if !seventy_b_route_pass {
        cocktail
            .measurement_string("primary_bottleneck")
            .unwrap_or_else(|| "run_70b_local_cocktail_with_real_inputs".to_string())
    } else {
        SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_NEXT.to_string()
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
    two_stage_route_scout_abstain_pass: bool,
    budgeted_uncertainty_escalator_pass: bool,
    sparse_wake_proposal_budget_pass: bool,
    verifier_budget_auction_pass: bool,
    kv_page_sketch_index_pass: bool,
    kv_page_bloom_sketch_coverage_pass: bool,
    query_aware_kv_selector_pass: bool,
    sparse_wake_certificate_answer_packet_pass: bool,
    layer_kv_joint_lease_pass: bool,
    construction_search_tournament_pass: bool,
    route_distillation_tournament_pass: bool,
    proof_search_signal_route_feedback_pass: bool,
    proof_pressure_signal_pass: bool,
    verifier_regret_fast_weights_pass: bool,
    fast_weight_quarantine_pass: bool,
    depth_lease_checkpoint_pass: bool,
    shadow_wake_oracle_pass: bool,
    ablation_shadow_run_pass: bool,
    axiom_axiomatic_source_distinction_pass: bool,
    sparse_route_no_hidden_authority_pass: bool,
    coldstream_no_hidden_authority_pass: bool,
    large_model_provider_reference_deferral_pass: bool,
    provider_route_copy_source_guard_pass: bool,
    transport_trace_answer_packet_pass: bool,
    ssd_wear_budget_pass: bool,
    coldstream_vs_mmap_pass: bool,
    slab_arena_copy_count_pass: bool,
    metal_io_feature_gate_pass: bool,
    codec_stage_latency_pass: bool,
    transport_cancellation_pass: bool,
    cache_policy_pollution_pass: bool,
    cold_panic_fallback_pass: bool,
    product_route_review_pass: bool,
    small_model_runtime_harness_safety_plan_pass: bool,
    small_model_runtime_harness_dry_run_witness_pass: bool,
    small_model_runtime_harness_owner_approved_probe_pass: bool,
    small_model_runtime_harness_abortable_runtime_probe_pass: bool,
    small_model_runtime_harness_logged_runtime_smoke_pass: bool,
    small_model_runtime_harness_first_token_runtime_probe_pass: bool,
    small_model_runtime_harness_answer_packet_runtime_probe_pass: bool,
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
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
                && cold_panic_fallback_pass
                && product_route_review_pass
                && small_model_runtime_harness_safety_plan_pass
                && small_model_runtime_harness_dry_run_witness_pass
                && small_model_runtime_harness_owner_approved_probe_pass
                && small_model_runtime_harness_abortable_runtime_probe_pass
                && small_model_runtime_harness_logged_runtime_smoke_pass
                && small_model_runtime_harness_first_token_runtime_probe_pass
                && small_model_runtime_harness_answer_packet_runtime_probe_pass
            {
                "deferred_l1_small_model_harness_answer_packet_runtime_probe_witnessed"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
                && cold_panic_fallback_pass
                && product_route_review_pass
                && small_model_runtime_harness_safety_plan_pass
                && small_model_runtime_harness_dry_run_witness_pass
                && small_model_runtime_harness_owner_approved_probe_pass
                && small_model_runtime_harness_abortable_runtime_probe_pass
                && small_model_runtime_harness_logged_runtime_smoke_pass
                && small_model_runtime_harness_first_token_runtime_probe_pass
            {
                "deferred_l1_small_model_harness_first_token_runtime_probe_witnessed"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
                && cold_panic_fallback_pass
                && product_route_review_pass
                && small_model_runtime_harness_safety_plan_pass
                && small_model_runtime_harness_dry_run_witness_pass
                && small_model_runtime_harness_owner_approved_probe_pass
                && small_model_runtime_harness_abortable_runtime_probe_pass
                && small_model_runtime_harness_logged_runtime_smoke_pass
            {
                "deferred_l1_small_model_harness_logged_runtime_smoke_witnessed"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
                && cold_panic_fallback_pass
                && product_route_review_pass
                && small_model_runtime_harness_safety_plan_pass
                && small_model_runtime_harness_dry_run_witness_pass
                && small_model_runtime_harness_owner_approved_probe_pass
                && small_model_runtime_harness_abortable_runtime_probe_pass
            {
                "deferred_l1_small_model_harness_abortable_probe_witnessed"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
                && cold_panic_fallback_pass
                && product_route_review_pass
                && small_model_runtime_harness_safety_plan_pass
                && small_model_runtime_harness_dry_run_witness_pass
            {
                "deferred_l1_small_model_harness_dry_run_witnessed"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
                && cold_panic_fallback_pass
                && product_route_review_pass
                && small_model_runtime_harness_safety_plan_pass
            {
                "deferred_l1_small_model_harness_safety_planned"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
                && cold_panic_fallback_pass
                && product_route_review_pass
            {
                "deferred_l1_product_route_reviewed"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
                && cold_panic_fallback_pass
            {
                "deferred_l1_cold_panic_fallback_witnessed"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
            {
                "deferred_l1_cold_panic_fallback_planned"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
            {
                "deferred_l1_cache_policy_pollution_planned"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
            {
                "deferred_l1_transport_cancellation_planned"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
            {
                "deferred_l1_codec_stage_latency_planned"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
            {
                "deferred_l1_slab_arena_copy_count_planned"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
            {
                "deferred_l1_coldstream_vs_mmap_planned"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
            {
                "deferred_l1_ssd_wear_budgeted"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
            {
                "deferred_l1_transport_trace_visible"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
            {
                "deferred_l1_copy_source_guarded"
            } else if !heavy_long_context_enabled && large_model_provider_reference_deferral_pass {
                "deferred_l1_metadata_witnessed"
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
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
                && cold_panic_fallback_pass
                && product_route_review_pass
                && small_model_runtime_harness_safety_plan_pass
                && small_model_runtime_harness_dry_run_witness_pass
                && small_model_runtime_harness_owner_approved_probe_pass
                && small_model_runtime_harness_abortable_runtime_probe_pass
            {
                "deferred_l1_small_model_harness_abortable_probe_witnessed"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
                && cold_panic_fallback_pass
                && product_route_review_pass
                && small_model_runtime_harness_safety_plan_pass
                && small_model_runtime_harness_dry_run_witness_pass
            {
                "deferred_l1_small_model_harness_dry_run_witnessed"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
                && cold_panic_fallback_pass
                && product_route_review_pass
                && small_model_runtime_harness_safety_plan_pass
            {
                "deferred_l1_small_model_harness_safety_planned"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
                && cold_panic_fallback_pass
                && product_route_review_pass
            {
                "deferred_l1_product_route_reviewed"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
                && cold_panic_fallback_pass
            {
                "deferred_l1_cold_panic_fallback_witnessed"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
                && cache_policy_pollution_pass
            {
                "deferred_l1_cold_panic_fallback_planned"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
                && transport_cancellation_pass
            {
                "deferred_l1_cache_policy_pollution_planned"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
                && codec_stage_latency_pass
            {
                "deferred_l1_transport_cancellation_planned"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
                && metal_io_feature_gate_pass
            {
                "deferred_l1_codec_stage_latency_planned"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
                && slab_arena_copy_count_pass
            {
                "deferred_l1_slab_arena_copy_count_planned"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
                && coldstream_vs_mmap_pass
            {
                "deferred_l1_coldstream_vs_mmap_planned"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
                && ssd_wear_budget_pass
            {
                "deferred_l1_ssd_wear_budgeted"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
                && transport_trace_answer_packet_pass
            {
                "deferred_l1_transport_trace_visible"
            } else if !heavy_long_context_enabled
                && large_model_provider_reference_deferral_pass
                && provider_route_copy_source_guard_pass
            {
                "deferred_l1_copy_source_guarded"
            } else if !heavy_long_context_enabled && large_model_provider_reference_deferral_pass {
                "deferred_l1_metadata_witnessed"
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
            if two_stage_route_scout_abstain_pass {
                "completed"
            } else if route_scout_ssm_baseline_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
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
        queue_item(
            29,
            "budgeted_uncertainty_escalator",
            "Meta Control",
            if budgeted_uncertainty_escalator_pass {
                "completed"
            } else if two_stage_route_scout_abstain_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_two_stage_route_scout_abstain"
            },
            "F-BudgetedUncertaintyEscalator",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "High uncertainty, budget exhaustion, or missing calibration must escalate rather than choose a cheap wrong route before sparse wake proposals can advance.",
            "Keep escalation shadow-only until uncertainty, budget, rollback, and AnswerPacket proof pass.",
        ),
        queue_item(
            30,
            "sparse_wake_proposal_budget",
            "Meta Control",
            if sparse_wake_proposal_budget_pass {
                "completed"
            } else if budgeted_uncertainty_escalator_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_budgeted_uncertainty_escalator"
            },
            "F-SparseWakeProposal-Budget",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Sparse wake proposals must fit byte, latency, evidence, and verifier budgets before any cheap selector can request residency work.",
            "Keep sparse wake proposals shadow-only until budget fit, rollback, RunEventLog, and AnswerPacket proof pass.",
        ),
        queue_item(
            31,
            "verifier_budget_auction",
            "Meta Control",
            if verifier_budget_auction_pass {
                "completed"
            } else if sparse_wake_proposal_budget_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_sparse_wake_proposal_budget"
            },
            "F-VerifierBudgetAuction",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Candidate wake units must compete under explicit verifier, byte, and latency budgets before a sparse wake can request residency work.",
            "Reject over-budget bundles and keep the auction shadow-only until rollback, RunEventLog, AnswerPacket, and held-out baseline proof pass.",
        ),
        queue_item(
            32,
            "kv_page_sketch_index",
            "Meta Control",
            if kv_page_sketch_index_pass {
                "completed"
            } else if verifier_budget_auction_pass && !heavy_long_context_enabled && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_verifier_budget_auction"
            },
            "F-KVPageSketchIndex",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "KV/page sketches must preserve required evidence coverage and compatibility fences before query-aware page selection can advance.",
            "Keep sketch indexes shadow-only until false-negative policy, coverage, rollback, RunEventLog, and AnswerPacket evidence pass.",
        ),
        queue_item(
            33,
            "kv_page_bloom_sketch_coverage",
            "Meta Control",
            if kv_page_bloom_sketch_coverage_pass {
                "completed"
            } else if kv_page_sketch_index_pass && !heavy_long_context_enabled && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_kv_page_sketch_index"
            },
            "F-KVPageBloomSketch-Coverage",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Bloom-like KV/page filters may over-include, but they must not silently drop proof-critical or privacy-critical required evidence.",
            "Keep bloom sketches shadow-only until false-negative coverage, rollback, RunEventLog, and AnswerPacket evidence pass.",
        ),
        queue_item(
            34,
            "query_aware_kv_selector",
            "Meta Control",
            if query_aware_kv_selector_pass {
                "completed"
            } else if kv_page_bloom_sketch_coverage_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_kv_page_bloom_sketch_coverage"
            },
            "F-QueryAwareKVSelector",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Query-aware KV/page selection must beat random, recency-only, and file-order baselines on held-out long-context-style fixtures before live page selection can promote.",
            "Keep selector output shadow-only until held-out recall/latency, rollback, RunEventLog, AnswerPacket, and no-hidden-authority evidence pass.",
        ),
        queue_item(
            35,
            "sparse_wake_certificate_answer_packet",
            "Meta Control",
            if sparse_wake_certificate_answer_packet_pass {
                "completed"
            } else if query_aware_kv_selector_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_query_aware_kv_selector"
            },
            "F-SparseWakeCertificate-AnswerPacket",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Sparse wake and KV/page decisions must become visible proof before any live sparse route can promote.",
            "Expose selected units, budgets, verifier/citation/test results, traces, fallback, rollback, and uncertainty in an AnswerPacket-bound certificate.",
        ),
        queue_item(
            36,
            "layer_kv_joint_lease",
            "Meta Control",
            if layer_kv_joint_lease_pass {
                "completed"
            } else if sparse_wake_certificate_answer_packet_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_sparse_wake_certificate_answer_packet"
            },
            "F-LayerKVJointLease",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Dynamic depth and KV/page choice must be leased together with error, byte, latency, fallback, rollback, and AnswerPacket accounting.",
            "Keep depth and KV decisions shadow-only until joint lease evidence rejects stale state, missing rollback, verifier bypass, and hidden route authority.",
        ),
        queue_item(
            37,
            "construction_search_tournament",
            "Meta Control",
            if construction_search_tournament_pass {
                "completed"
            } else if layer_kv_joint_lease_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_layer_kv_joint_lease"
            },
            "F-ConstructionSearchTournament",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "PatternBoost/Axplorer-style generate-repair-score-select must improve sparse wake plans over random generation under a fixed budget.",
            "Keep construction search offline/shadow-only until tournament winners beat random generation, preserve rollback, and expose AnswerPacket proof.",
        ),
        queue_item(
            38,
            "route_distillation_tournament",
            "Meta Control",
            if route_distillation_tournament_pass {
                "completed"
            } else if construction_search_tournament_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_construction_search_tournament"
            },
            "F-RouteDistillationTournament",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Expensive full/proof/oracle traces must produce held-out route labels that improve the small scout over direct heuristics.",
            "Keep distillation labels offline/shadow-only until train/held-out split, baseline wins, rollback, RunEventLog, and AnswerPacket proof pass.",
        ),
        queue_item(
            39,
            "proof_search_signal_route_feedback",
            "Meta Control",
            if proof_search_signal_route_feedback_pass {
                "completed"
            } else if route_distillation_tournament_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_route_distillation_tournament"
            },
            "F-ProofSearchSignal-RouteFeedback",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Lean/proof outcomes must become route features without becoming hidden truth or bypassing tests, citations, SCOPE-Rex, or AnswerPacket.",
            "Keep proof feedback shadow-only until pass/fail/repair traces, verifier outcomes, rollback, RunEventLog, and AnswerPacket evidence pass.",
        ),
        queue_item(
            40,
            "proof_pressure_signal",
            "Meta Control",
            if proof_pressure_signal_pass {
                "completed"
            } else if proof_search_signal_route_feedback_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_proof_search_signal_route_feedback"
            },
            "F-ProofPressureSignal",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Compiler errors, tactic-state entropy, missing premises, and failed attempt memory must become explicit route-pressure labels.",
            "Keep pressure labels shadow-only until statement preservation, missing-premise, rollback, RunEventLog, and AnswerPacket evidence pass.",
        ),
        queue_item(
            41,
            "verifier_regret_fast_weights",
            "Meta Control",
            if verifier_regret_fast_weights_pass {
                "completed"
            } else if proof_pressure_signal_pass && !heavy_long_context_enabled && !seventy_b_route_pass {
                "next_active_architecture_cursor"
            } else {
                "planned_after_proof_pressure_signal"
            },
            "F-VerifierRegretFastWeights",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Fast-weight updates must be bounded, session/local scoped, resettable, TTL-limited, and useful on held-out route choices before consolidation.",
            "Keep fast weights shadow-only until drift bounds, reset, rollback, TTL, held-out wins, RunEventLog, and AnswerPacket evidence pass.",
        ),
        queue_item(
            42,
            "fast_weight_quarantine",
            "Meta Control",
            if fast_weight_quarantine_pass {
                "completed"
            } else if verifier_regret_fast_weights_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_verifier_regret_fast_weights"
            },
            "F-FastWeightQuarantine",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Fast-weight deltas must remain quarantined and shadow-only until drift, held-out, rollback, TTL, and AnswerPacket gates pass.",
            "Reject live-control or consolidation attempts unless quarantine state, reset, rollback, held-out wins, and visible route evidence all pass.",
        ),
        queue_item(
            43,
            "depth_lease_checkpoint",
            "Meta Control",
            if depth_lease_checkpoint_pass {
                "completed"
            } else if fast_weight_quarantine_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_fast_weight_quarantine"
            },
            "F-DepthLease-Checkpoint",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Dynamic-depth choices must declare shallow exit, deeper wake, verifier margin, maximum extra layers, and full-depth fallback before route policy can cite depth savings.",
            "Keep depth decisions leased, rollback-bound, AnswerPacket-visible, and unable to hide full-depth fallback.",
        ),
        queue_item(
            44,
            "shadow_wake_oracle",
            "Meta Control",
            if shadow_wake_oracle_pass {
                "completed"
            } else if depth_lease_checkpoint_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_depth_lease_checkpoint"
            },
            "F-ShadowWakeOracle",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Full-wake, proof, test, and oracle traces must become route labels without becoming a hidden live runtime dependency.",
            "Keep oracle traces offline/shadow-only, rollback-bound, AnswerPacket-visible, and unable to bypass SCOPE-Rex or SovereignGate.",
        ),
        queue_item(
            45,
            "ablation_shadow_run",
            "Meta Control",
            if ablation_shadow_run_pass {
                "completed"
            } else if shadow_wake_oracle_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_shadow_wake_oracle"
            },
            "F-AblationShadowRun",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Counterfactual shadow runs must prove which oracle-labeled units actually mattered before distillation can cite route importance.",
            "Keep ablation evidence shadow-only, rollback-bound, AnswerPacket-visible, and unable to mutate live policy or hide full-wake failures.",
        ),
        queue_item(
            46,
            "axiom_axiomatic_source_distinction",
            "Meta Control",
            if axiom_axiomatic_source_distinction_pass {
                "completed"
            } else if ablation_shadow_run_pass && !heavy_long_context_enabled && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_ablation_shadow_run"
            },
            "F-AxiomAxiomatic-SourceDistinction",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Axioms, retrieved sources, oracle labels, verifier traces, and route priors must stay source-distinct before sparse route control can cite them.",
            "Reject source conflation, hidden oracle authority, missing provenance, missing rollback, or AnswerPacket-invisible route evidence.",
        ),
        queue_item(
            47,
            "sparse_route_no_hidden_authority",
            "Meta Control",
            if sparse_route_no_hidden_authority_pass {
                "completed"
            } else if axiom_axiomatic_source_distinction_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_axiom_axiomatic_source_distinction"
            },
            "F-SparseRoute-NoHiddenAuthority",
            "docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md",
            "Sparse route control must prove source-prior labels cannot become hidden live authority before any formal-math or oracle-derived route citation promotes.",
            "Keep sparse route policy shadow-only until SCOPE-Rex/SovereignGate, rollback, RunEventLog, AnswerPacket, and no-hidden-authority evidence pass.",
        ),
        queue_item(
            48,
            "coldstream_no_hidden_authority",
            "ColdStream Transport",
            if coldstream_no_hidden_authority_pass {
                "completed"
            } else if sparse_route_no_hidden_authority_pass
                && !heavy_long_context_enabled
                && !seventy_b_route_pass
            {
                "next_active_architecture_cursor"
            } else {
                "planned_after_sparse_route_no_hidden_authority"
            },
            "F-ColdStream-NoHiddenAuthority",
            "docs/falsifiers/F-COLDSTREAM-RESIDENCY-TRANSPORT-BUNDLE_2026_06_01.md",
            "ColdStream transport must prove route/control evidence cannot wake bytes or mutate route policy without SemanticWorkingSetPlan, SCOPE-Rex/SovereignGate admission, rollback, RunEventLog, and AnswerPacket proof.",
            "Keep transport proposal evidence metadata-only until byte leases, admission gates, rollback, and visible proof reject hidden live route authority.",
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
    two_stage_route_scout_abstain_pass: bool,
    budgeted_uncertainty_escalator_pass: bool,
    sparse_wake_proposal_budget_pass: bool,
    verifier_budget_auction_pass: bool,
    kv_page_sketch_index_pass: bool,
    kv_page_bloom_sketch_coverage_pass: bool,
    query_aware_kv_selector_pass: bool,
    sparse_wake_certificate_answer_packet_pass: bool,
    layer_kv_joint_lease_pass: bool,
    construction_search_tournament_pass: bool,
    route_distillation_tournament_pass: bool,
    proof_search_signal_route_feedback_pass: bool,
    proof_pressure_signal_pass: bool,
    verifier_regret_fast_weights_pass: bool,
    fast_weight_quarantine_pass: bool,
    depth_lease_checkpoint_pass: bool,
    shadow_wake_oracle_pass: bool,
    ablation_shadow_run_pass: bool,
    axiom_axiomatic_source_distinction_pass: bool,
    sparse_route_no_hidden_authority_pass: bool,
    coldstream_no_hidden_authority_pass: bool,
    large_model_provider_reference_deferral_pass: bool,
    provider_route_copy_source_guard_pass: bool,
    transport_trace_answer_packet_pass: bool,
    ssd_wear_budget_pass: bool,
    coldstream_vs_mmap_pass: bool,
    slab_arena_copy_count_pass: bool,
    metal_io_feature_gate_pass: bool,
    codec_stage_latency_pass: bool,
    transport_cancellation_pass: bool,
    cache_policy_pollution_pass: bool,
    cold_panic_fallback_pass: bool,
    product_route_review_pass: bool,
    small_model_runtime_harness_safety_plan_pass: bool,
    small_model_runtime_harness_dry_run_witness_pass: bool,
    small_model_runtime_harness_owner_approved_probe_pass: bool,
    small_model_runtime_harness_abortable_runtime_probe_pass: bool,
    small_model_runtime_harness_logged_runtime_smoke_pass: bool,
    small_model_runtime_harness_first_token_runtime_probe_pass: bool,
    small_model_runtime_harness_answer_packet_runtime_probe_pass: bool,
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
    if route_scout_ssm_baseline_pass
        && !two_stage_route_scout_abstain_pass
        && !heavy_long_context_enabled
    {
        anomalies.push(serde_json::json!({
            "kind": "two_stage_route_scout_abstain_missing",
            "detail": "RouteScoutSSM baseline evidence is present; the next non-heavy architecture cursor must split route-family and selector decisions with explicit abstention before any sparse wake proposal can promote."
        }));
    }
    if two_stage_route_scout_abstain_pass
        && !budgeted_uncertainty_escalator_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "budgeted_uncertainty_escalator_missing",
            "detail": "Two-stage route scout evidence is present; the next non-heavy architecture cursor must prove high uncertainty, budget exhaustion, and missing calibration escalate instead of selecting a cheap wrong route."
        }));
    }
    if budgeted_uncertainty_escalator_pass
        && !sparse_wake_proposal_budget_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "sparse_wake_proposal_budget_missing",
            "detail": "Budgeted uncertainty escalation evidence is present; the next non-heavy architecture cursor must prove sparse wake proposals fit byte, latency, evidence, and verifier budgets before route selection can request residency work."
        }));
    }
    if sparse_wake_proposal_budget_pass
        && !verifier_budget_auction_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "verifier_budget_auction_missing",
            "detail": "Sparse wake proposal budget evidence is present; the next non-heavy architecture cursor must prove candidate wake units compete under verifier, byte, and latency budgets before any residency work can promote."
        }));
    }
    if verifier_budget_auction_pass
        && !kv_page_sketch_index_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "kv_page_sketch_index_missing",
            "detail": "VerifierBudgetAuction evidence is present; the next non-heavy architecture cursor must prove KV/page sketch indexes preserve required evidence coverage before query-aware selection can advance."
        }));
    }
    if kv_page_sketch_index_pass
        && !kv_page_bloom_sketch_coverage_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "kv_page_bloom_sketch_coverage_missing",
            "detail": "KVPageSketchIndex evidence is present; the next non-heavy architecture cursor must prove bloom-like page filters do not drop required proof or privacy evidence before query-aware selection can advance."
        }));
    }
    if kv_page_bloom_sketch_coverage_pass
        && !query_aware_kv_selector_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "query_aware_kv_selector_missing",
            "detail": "KVPageBloomSketch coverage evidence is present; the next non-heavy architecture cursor must prove query-aware KV/page selection beats simple baselines before live selector promotion can advance."
        }));
    }
    if query_aware_kv_selector_pass
        && !sparse_wake_certificate_answer_packet_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "sparse_wake_certificate_answer_packet_missing",
            "detail": "QueryAwareKVSelector evidence is present; the next non-heavy architecture cursor must prove selected sparse/KV units, budgets, verifier results, traces, fallback, and rollback are exposed in an AnswerPacket certificate."
        }));
    }
    if sparse_wake_certificate_answer_packet_pass
        && !layer_kv_joint_lease_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "layer_kv_joint_lease_missing",
            "detail": "SparseWakeCertificate AnswerPacket evidence is present; the next non-heavy architecture cursor must prove depth, KV/page choice, error budgets, fallback, and rollback are leased together before any sparse route can promote."
        }));
    }
    if layer_kv_joint_lease_pass
        && !construction_search_tournament_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "construction_search_tournament_missing",
            "detail": "LayerKVJointLease evidence is present; the next non-heavy architecture cursor must prove generate-repair-score-select improves sparse wake plans under fixed budget without live route authority."
        }));
    }
    if construction_search_tournament_pass
        && !route_distillation_tournament_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "route_distillation_tournament_missing",
            "detail": "ConstructionSearchTournament evidence is present; the next non-heavy architecture cursor must prove full/proof/oracle trace labels improve the small scout on held-out route choices before distillation policy can promote."
        }));
    }
    if route_distillation_tournament_pass
        && !proof_search_signal_route_feedback_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "proof_search_signal_route_feedback_missing",
            "detail": "RouteDistillationTournament evidence is present; the next non-heavy architecture cursor must prove Lean/proof outcomes become route features without hidden truth, verifier bypass, or AnswerPacket omission."
        }));
    }
    if proof_search_signal_route_feedback_pass
        && !proof_pressure_signal_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "proof_pressure_signal_missing",
            "detail": "ProofSearchSignal evidence is present; the next non-heavy architecture cursor must prove compiler errors, tactic-state entropy, missing premises, and failed attempt memory become explicit route-pressure labels with rollback, RunEventLog, and AnswerPacket evidence."
        }));
    }
    if proof_pressure_signal_pass
        && !verifier_regret_fast_weights_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "verifier_regret_fast_weights_missing",
            "detail": "ProofPressureSignal evidence is present; the next non-heavy architecture cursor must prove verifier-regret fast weights are bounded, resettable, TTL-limited, shadow-scoped, rollback-bound, and held-out useful before consolidation."
        }));
    }
    if verifier_regret_fast_weights_pass
        && !fast_weight_quarantine_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "fast_weight_quarantine_missing",
            "detail": "VerifierRegretFastWeights evidence is present; the next non-heavy architecture cursor must prove fast-weight deltas remain quarantined and shadow-only until drift, held-out, rollback, TTL, and AnswerPacket gates pass."
        }));
    }
    if fast_weight_quarantine_pass
        && !depth_lease_checkpoint_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "depth_lease_checkpoint_missing",
            "detail": "FastWeightQuarantine evidence is present; the next non-heavy architecture cursor must prove dynamic-depth choices declare shallow exit, deeper wake, verifier margin, maximum extra layers, and full-depth fallback."
        }));
    }
    if depth_lease_checkpoint_pass
        && !shadow_wake_oracle_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "shadow_wake_oracle_missing",
            "detail": "DepthLeaseCheckpoint evidence is present; the next non-heavy architecture cursor must prove full-wake/proof/test oracle traces create route labels without becoming a live runtime dependency."
        }));
    }
    if shadow_wake_oracle_pass
        && !ablation_shadow_run_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "ablation_shadow_run_missing",
            "detail": "ShadowWakeOracle evidence is present; the next non-heavy architecture cursor must prove counterfactual ablation shadow runs identify which oracle-labeled units mattered without hidden live route authority."
        }));
    }
    if ablation_shadow_run_pass
        && !axiom_axiomatic_source_distinction_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "axiom_axiomatic_source_distinction_missing",
            "detail": "AblationShadowRun evidence is present; the next non-heavy architecture cursor must keep axioms, retrieved sources, oracle labels, verifier traces, and route priors source-distinct before sparse route control can cite them."
        }));
    }
    if axiom_axiomatic_source_distinction_pass
        && !sparse_route_no_hidden_authority_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "sparse_route_no_hidden_authority_missing",
            "detail": "Source-distinction evidence is present; the next non-heavy architecture cursor must prove sparse route control cannot treat source priors, proof traces, oracle labels, or formal-math motifs as hidden live authority."
        }));
    }
    if sparse_route_no_hidden_authority_pass
        && !coldstream_no_hidden_authority_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "coldstream_no_hidden_authority_missing",
            "detail": "Sparse route no-hidden-authority evidence is present; the next non-heavy architecture cursor must prove ColdStream transport cannot wake bytes or mutate route policy without SemanticWorkingSetPlan, SCOPE-Rex/SovereignGate admission, rollback, RunEventLog, and AnswerPacket proof."
        }));
    }
    if coldstream_no_hidden_authority_pass
        && !large_model_provider_reference_deferral_pass
        && !heavy_long_context_enabled
        && !seventy_b_route_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "large_model_provider_reference_deferral_missing",
            "detail": "ColdStream no-hidden-authority evidence is present; the next default-route cursor must prove provider/fp16/70B and 128K heavy probes stay deferred while practical MLX and cold-assembly architecture remain preserved."
        }));
    }
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && !metal_io_feature_gate_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "metal_io_feature_gate_missing",
            "detail": "SlabArena copy-count evidence is present; the next non-heavy cursor must prove Metal I/O is feature-gated and falls back to visible CPU slabs before live transport promotion."
        }));
    }
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && !codec_stage_latency_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "codec_stage_latency_missing",
            "detail": "Metal I/O feature-gate evidence is present; the next non-heavy cursor must prove decode/conversion latency, checksums, and copy counts are measured separately from file-read time before live transport promotion."
        }));
    }
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && !transport_cancellation_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "transport_cancellation_missing",
            "detail": "CodecStage latency evidence is present; the next non-heavy cursor must prove route changes cancel obsolete in-flight reads and reject stale slabs before live transport promotion."
        }));
    }
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && !cache_policy_pollution_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "cache_policy_pollution_missing",
            "detail": "Transport cancellation evidence is present; the next non-heavy cursor must prove explicit cache policy choices preserve repeated hot-route performance and expose cache-pollution caveats before live transport promotion."
        }));
    }
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && !cold_panic_fallback_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "cold_panic_fallback_missing",
            "detail": "Cache-policy pollution evidence is present; the next non-heavy cursor must prove missed ColdStream deadlines degrade visibly with fallback, stale-slab rejection, repair queue, rollback, RunEventLog, SCOPE-Rex/SovereignGate admission, and AnswerPacket caveats before live transport promotion."
        }));
    }
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
        && !product_route_review_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "product_route_review_missing",
            "detail": "Cold panic fallback evidence is present; the next L1 cursor must prove the product-route review packet sees red routes, preserves MAS/Pro and L1/L2/L3 separation, and refuses live 70B/ColdStream/KV promotion before planning a small-model runtime harness."
        }));
    }
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
        && product_route_review_pass
        && !small_model_runtime_harness_safety_plan_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_safety_plan_missing",
            "detail": "Product route review evidence is present; the next L1 cursor must prove the small-model runtime harness plan is serialized, owner-gated, dry-run-first, cancellable, rollback-bound, RunEventLog-bound, AnswerPacket-visible, privacy-fenced, MAS-honest, and metadata-only before any MLX runtime probe."
        }));
    }
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
        && product_route_review_pass
        && small_model_runtime_harness_safety_plan_pass
        && !small_model_runtime_harness_dry_run_witness_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_dry_run_witness_missing",
            "detail": "Small-model runtime harness safety planning is present; the next L1 cursor must prove a dry-run-only harness transcript with admission, serialized executor, cancellation, rollback, RunEventLog, AnswerPacket, privacy, budget, and zero runtime/model bytes before any owner-approved MLX runtime probe."
        }));
    }
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
        && product_route_review_pass
        && small_model_runtime_harness_safety_plan_pass
        && small_model_runtime_harness_dry_run_witness_pass
        && !small_model_runtime_harness_owner_approved_probe_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_owner_approved_probe_missing",
            "detail": "Small-model runtime harness dry-run evidence is present; the next L1 cursor must prove an owner-approval lease, selected local catalog model refs, admission, serialized executor, cancellation, rollback, RunEventLog, AnswerPacket, privacy, and budget fences before any abortable MLX runtime probe."
        }));
    }
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
        && product_route_review_pass
        && small_model_runtime_harness_safety_plan_pass
        && small_model_runtime_harness_dry_run_witness_pass
        && small_model_runtime_harness_owner_approved_probe_pass
        && !small_model_runtime_harness_abortable_runtime_probe_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_abortable_runtime_probe_missing",
            "detail": "Small-model runtime harness owner approval is witnessed; the next L1 cursor must prove pre-runtime cancellation, deadline, rollback, RunEventLog, AnswerPacket, privacy, and budget discipline before any logged small-model runtime smoke."
        }));
    }
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
        && product_route_review_pass
        && small_model_runtime_harness_safety_plan_pass
        && small_model_runtime_harness_dry_run_witness_pass
        && small_model_runtime_harness_owner_approved_probe_pass
        && small_model_runtime_harness_abortable_runtime_probe_pass
        && !small_model_runtime_harness_logged_runtime_smoke_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_logged_runtime_smoke_missing",
            "detail": "Small-model runtime harness abortability is witnessed; the next L1 cursor must prove the runtime harness logs an owner-approved attempt and visible missing-local-snapshot failure with rollback, RunEventLog, AnswerPacket, privacy, budget, and zero runtime/model bytes before any first-token runtime probe."
        }));
    }
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
        && product_route_review_pass
        && small_model_runtime_harness_safety_plan_pass
        && small_model_runtime_harness_dry_run_witness_pass
        && small_model_runtime_harness_owner_approved_probe_pass
        && small_model_runtime_harness_abortable_runtime_probe_pass
        && small_model_runtime_harness_logged_runtime_smoke_pass
        && !small_model_runtime_harness_first_token_runtime_probe_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_first_token_runtime_probe_missing",
            "detail": "Small-model runtime harness logged smoke is witnessed; the next L1 cursor must prove one owner-approved small local-model first token with redacted token text, rollback, RunEventLog, AnswerPacket, privacy, budget, no long-context shard, no 70B probe, and explicit L2/L3 non-promotion."
        }));
    }
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
        && product_route_review_pass
        && small_model_runtime_harness_safety_plan_pass
        && small_model_runtime_harness_dry_run_witness_pass
        && small_model_runtime_harness_owner_approved_probe_pass
        && small_model_runtime_harness_abortable_runtime_probe_pass
        && small_model_runtime_harness_logged_runtime_smoke_pass
        && small_model_runtime_harness_first_token_runtime_probe_pass
        && !small_model_runtime_harness_answer_packet_runtime_probe_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_answer_packet_runtime_probe_missing",
            "detail": "Small-model runtime harness first-token proof is retained at L1; the next L1 cursor must packetize the redacted Qwen3-4B sidecar into a real AnswerPacket and dense RunEventLog with rollback, admission, privacy, budget, zero new runtime/model bytes, and explicit L2/L3 non-promotion."
        }));
    }
    if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
        && product_route_review_pass
        && small_model_runtime_harness_safety_plan_pass
        && small_model_runtime_harness_dry_run_witness_pass
        && small_model_runtime_harness_owner_approved_probe_pass
        && small_model_runtime_harness_abortable_runtime_probe_pass
        && small_model_runtime_harness_logged_runtime_smoke_pass
        && small_model_runtime_harness_first_token_runtime_probe_pass
        && small_model_runtime_harness_answer_packet_runtime_probe_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_answer_packet_runtime_probe_l1_packetized_only",
            "detail": "Small-model runtime harness AnswerPacket packetization is retained at L1: the Qwen3-4B first-token sidecar is bound to real AnswerPacket and RunEventLog proof with token text redacted and zero new runtime/model bytes. L2 capability remains vault_research_route_with_packetized_mitigation and L3 user-facing/product runtime is unchanged; next bottleneck is product WRV."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
        && product_route_review_pass
        && small_model_runtime_harness_safety_plan_pass
        && small_model_runtime_harness_dry_run_witness_pass
        && small_model_runtime_harness_owner_approved_probe_pass
        && small_model_runtime_harness_abortable_runtime_probe_pass
        && small_model_runtime_harness_logged_runtime_smoke_pass
        && small_model_runtime_harness_first_token_runtime_probe_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_first_token_runtime_probe_l1_runtime_only",
            "detail": "Small-model runtime harness first-token proof is retained at L1 for Qwen3-4B with token text redacted. It loads small-model runtime/model bytes, so it is not metadata-only, but L2 capability remains vault_research_route_with_packetized_mitigation and L3 user-facing/product runtime is unchanged."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
        && product_route_review_pass
        && small_model_runtime_harness_safety_plan_pass
        && small_model_runtime_harness_dry_run_witness_pass
        && small_model_runtime_harness_owner_approved_probe_pass
        && !small_model_runtime_harness_abortable_runtime_probe_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_owner_approved_probe_metadata_only",
            "detail": "Small-model runtime harness owner-approval leases are witnessed at L1 and point to an abortable runtime probe next. No MLX/runtime/model bytes were loaded by this witness; L2 capability remains vault_research_route_with_packetized_mitigation and L3 user-facing/product runtime is unchanged."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
        && product_route_review_pass
        && small_model_runtime_harness_safety_plan_pass
        && small_model_runtime_harness_dry_run_witness_pass
        && !small_model_runtime_harness_owner_approved_probe_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_dry_run_witness_metadata_only",
            "detail": "Small-model runtime harness dry-run evidence is witnessed at L1 and points to owner-approved runtime probe gating next. L2 capability remains vault_research_route_with_packetized_mitigation and L3 user-facing/product runtime is unchanged."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
        && product_route_review_pass
        && small_model_runtime_harness_safety_plan_pass
        && !small_model_runtime_harness_dry_run_witness_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "small_model_runtime_harness_safety_plan_metadata_only",
            "detail": "Small-model runtime harness safety planning is witnessed at L1 and points to a dry-run-only harness witness next. L2 capability remains vault_research_route_with_packetized_mitigation and L3 user-facing/product runtime is unchanged."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
        && product_route_review_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "product_route_review_metadata_only",
            "detail": "Product route review is witnessed at L1 and points to a separate small-model runtime harness safety plan. L2 capability remains vault_research_route_with_packetized_mitigation and L3 user-facing/product runtime is unchanged."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
        && cold_panic_fallback_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "cold_panic_fallback_metadata_only",
            "detail": "Cold panic fallback is witnessed at L1 with missed-deadline fallback, token-block budgets, stale-slab rejection, repair queue, rollback, RunEventLog, SCOPE-Rex/SovereignGate admission, compatibility fences, and visible AnswerPacket caveats, but no live transport benchmark, KV-Direct 128K route, live sparse 70B route, provider route, or product runtime capability is promoted."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
        && cache_policy_pollution_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "cache_policy_pollution_metadata_only",
            "detail": "Cache-policy pollution is witnessed at L1 with explicit NoCache/HotReuse/metadata policy choices, repeated hot-route probes, p95/p99 regression budgets, cache-pollution bounds, rollback, RunEventLog, SCOPE-Rex/SovereignGate admission, compatibility fences, and visible AnswerPacket caveats, but no cold panic fallback, live transport benchmark, KV-Direct 128K route, live sparse 70B route, provider route, or product runtime capability is promoted."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
        && transport_cancellation_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "transport_cancellation_metadata_only",
            "detail": "Transport cancellation is witnessed at L1 with route epoch, cancellation groups/tokens, obsolete-read rejection, stale-slab rejection, rollback, RunEventLog, SCOPE-Rex/SovereignGate admission, compatibility fences, and visible AnswerPacket caveats, but no live transport benchmark, KV-Direct 128K route, live sparse 70B route, provider route, or product runtime capability is promoted."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
        && codec_stage_latency_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "codec_stage_latency_metadata_only",
            "detail": "CodecStage latency is witnessed at L1 with separate read/decode timing, checksum, copy-count, rollback, RunEventLog, SCOPE-Rex/SovereignGate admission, and visible AnswerPacket caveats, but no live codec benchmark, KV-Direct 128K route, live sparse 70B route, provider route, or product runtime capability is promoted."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
        && metal_io_feature_gate_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "metal_io_feature_gate_metadata_only",
            "detail": "Metal I/O feature-gate decisions are witnessed at L1 with supported-feature MetalBufferLease refs, unsupported/unknown CPU slab fallback, rollback, RunEventLog, SCOPE-Rex/SovereignGate admission, and visible AnswerPacket caveats, but no live Metal I/O benchmark, KV-Direct 128K route, live sparse 70B route, provider route, or product runtime capability is promoted."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
        && slab_arena_copy_count_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "slab_arena_copy_count_metadata_only",
            "detail": "SlabArena copy-count traces are witnessed at L1 with preallocated CPU slabs, bounded leases, zero per-token allocation spikes, rollback, RunEventLog, SCOPE-Rex/SovereignGate admission, and AnswerPacket refs, but no live ColdStream benchmark, Metal I/O route, KV-Direct 128K route, live sparse 70B route, provider route, or product runtime capability is promoted."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
        && coldstream_vs_mmap_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "coldstream_vs_mmap_metadata_only",
            "detail": "ColdStream-vs-mmap benchmark-plan rows are witnessed at L1 with same-fixture mmap, pread, and ColdStream comparisons, visible caveats, rollback, RunEventLog, and AnswerPacket refs, but no live mmap/pread/ColdStream benchmark, KV-Direct 128K route, live sparse 70B route, provider route, or product runtime capability is promoted."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
        && ssd_wear_budget_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "coldstream_vs_mmap_missing",
            "detail": "ColdStream trace visibility and repeated SSD wear/energy/cache budgeting are witnessed at L1; the next non-heavy architecture cursor must prove the mmap-fault, naive pread, and ColdStream benchmark-plan table is same-fixture, source-grounded, visible, rollback-bound, and non-runtime before live transport promotion."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && transport_trace_answer_packet_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "ssd_wear_budget_missing",
            "detail": "Provider/GGUF/KV/70B copy is source-guarded and ColdStream trace-to-AnswerPacket visibility is witnessed at L1; the next non-heavy architecture cursor must budget repeated read/write volume, burst volume, energy, cache pollution, write amplification, rollback, and AnswerPacket caveats before live transport promotion."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
        && provider_route_copy_source_guard_pass
        && !transport_trace_answer_packet_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "transport_trace_answer_packet_missing",
            "detail": "Provider/GGUF/KV/70B route copy is guarded at L1; the next non-heavy architecture cursor must bind ColdStream TransportTrace material to RunEventLog and visible AnswerPacket caveats before it can affect answers."
        }));
    } else if !seventy_b_route_pass
        && !heavy_long_context_enabled
        && large_model_provider_reference_deferral_pass
    {
        anomalies.push(serde_json::json!({
            "kind": "large_model_provider_reference_deferred_metadata_only",
            "detail": "Default MLX route deferral is witnessed at L1, but 70B/GGUF/provider-reference work is still not an active product/runtime pass."
        }));
    } else if !seventy_b_route_pass && !heavy_long_context_enabled {
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
        const TWO_STAGE_ROUTE: usize = 25;
        const BUDGETED_UNCERTAINTY: usize = 26;
        const SPARSE_WAKE: usize = 27;
        const VERIFIER_AUCTION: usize = 28;
        const KV_PAGE_SKETCH: usize = 29;
        const KV_PAGE_BLOOM: usize = 30;
        const QUERY_AWARE_KV: usize = 31;
        const SPARSE_CERT: usize = 32;
        const LAYER_KV_LEASE: usize = 33;
        const CONSTRUCTION_SEARCH: usize = 34;
        const ROUTE_DISTILLATION: usize = 35;
        const PROOF_SEARCH_SIGNAL: usize = 36;
        const PROOF_PRESSURE_SIGNAL: usize = 37;
        const VERIFIER_REGRET_FAST_WEIGHTS: usize = 38;
        const FAST_WEIGHT_QUARANTINE: usize = 39;
        const DEPTH_LEASE_CHECKPOINT: usize = 40;
        const SHADOW_WAKE_ORACLE: usize = 41;
        const ABLATION_SHADOW_RUN: usize = 42;
        const AXIOM_AXIOMATIC_SOURCE_DISTINCTION: usize = 43;
        const SPARSE_ROUTE_NO_HIDDEN_AUTHORITY: usize = 44;
        const COLDSTREAM_NO_HIDDEN_AUTHORITY: usize = 45;
        const SEVENTY_B: usize = 46;
        const SCHEMA: usize = 47;
        let classify = |true_indexes: &[usize]| -> String {
            let mut values = [false; 48];
            for index in true_indexes {
                values[*index] = true;
            }
            classify_route(
                values[0], values[1], values[2], values[3], values[4], values[5], values[6],
                values[7], values[8], values[9], values[10], values[11], values[12], values[13],
                values[14], values[15], values[16], values[17], values[18], values[19], values[20],
                values[21], values[22], values[23], values[24], values[25], values[26], values[27],
                values[28], values[29], values[30], values[31], values[32], values[33], values[34],
                values[35], values[36], values[37], values[38], values[39], values[40], values[41],
                values[42], values[43], values[44], values[45], values[46], values[47],
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
                TWO_STAGE_ROUTE,
                BUDGETED_UNCERTAINTY,
                SPARSE_WAKE,
                VERIFIER_AUCTION,
                KV_PAGE_SKETCH,
                KV_PAGE_BLOOM,
                QUERY_AWARE_KV,
                SPARSE_CERT,
                LAYER_KV_LEASE,
                CONSTRUCTION_SEARCH,
                ROUTE_DISTILLATION,
                PROOF_SEARCH_SIGNAL,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
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
                TWO_STAGE_ROUTE,
                BUDGETED_UNCERTAINTY,
                SPARSE_WAKE,
                VERIFIER_AUCTION,
                KV_PAGE_SKETCH,
                KV_PAGE_BLOOM,
                QUERY_AWARE_KV,
                SPARSE_CERT,
                LAYER_KV_LEASE,
                CONSTRUCTION_SEARCH,
                ROUTE_DISTILLATION,
                PROOF_SEARCH_SIGNAL,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
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
        const TWO_STAGE_ROUTE_SCOUT_ABSTAIN: usize = 40;
        const BUDGETED_UNCERTAINTY_ESCALATOR: usize = 41;
        const SPARSE_WAKE_PROPOSAL_BUDGET: usize = 42;
        const VERIFIER_BUDGET_AUCTION: usize = 43;
        const KV_PAGE_SKETCH_INDEX: usize = 44;
        const KV_PAGE_BLOOM_SKETCH_COVERAGE: usize = 45;
        const QUERY_AWARE_KV_SELECTOR: usize = 46;
        const SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET: usize = 47;
        const LAYER_KV_JOINT_LEASE: usize = 48;
        const CONSTRUCTION_SEARCH_TOURNAMENT: usize = 49;
        const ROUTE_DISTILLATION_TOURNAMENT: usize = 50;
        const PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK: usize = 51;
        const PROOF_PRESSURE_SIGNAL: usize = 52;
        const VERIFIER_REGRET_FAST_WEIGHTS: usize = 53;
        const FAST_WEIGHT_QUARANTINE: usize = 54;
        const DEPTH_LEASE_CHECKPOINT: usize = 55;
        const SHADOW_WAKE_ORACLE: usize = 56;
        const ABLATION_SHADOW_RUN: usize = 57;
        const AXIOM_AXIOMATIC_SOURCE_DISTINCTION: usize = 58;
        const SPARSE_ROUTE_NO_HIDDEN_AUTHORITY: usize = 59;
        const COLDSTREAM_NO_HIDDEN_AUTHORITY: usize = 60;
        const LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL: usize = 61;
        const PROVIDER_ROUTE_COPY_SOURCE_GUARD: usize = 62;
        const TRANSPORT_TRACE_ANSWER_PACKET: usize = 63;
        const SSD_WEAR_BUDGET: usize = 64;
        const COLDSTREAM_VS_MMAP: usize = 65;
        const SLAB_ARENA_COPY_COUNT: usize = 66;
        const METAL_IO_FEATURE_GATE: usize = 67;
        const CODEC_STAGE_LATENCY: usize = 68;
        const TRANSPORT_CANCELLATION: usize = 69;
        const CACHE_POLICY_POLLUTION: usize = 70;
        const COLD_PANIC_FALLBACK: usize = 71;
        const PRODUCT_ROUTE_REVIEW: usize = 72;
        const SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN: usize = 73;
        const SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS: usize = 74;
        const SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE: usize = 75;
        const SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE: usize = 76;
        const SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE: usize = 77;
        const SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE: usize = 78;
        const SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE: usize = 79;
        const SEVENTY_B: usize = 80;

        let with_floor = |true_indexes: &[usize]| -> Vec<usize> {
            let mut indexes = vec![SCHEMA, UAS_COPY, ACS_LOOKUP, UAS_ACS_MMAP];
            indexes.extend_from_slice(true_indexes);
            indexes
        };
        let flags = |true_indexes: &[usize]| -> [bool; 81] {
            let mut values = [false; 81];
            for index in true_indexes {
                values[*index] = true;
            }
            values
        };
        let nb_with_heavy = |values: [bool; 81], heavy_long_context_enabled: bool| -> String {
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
                values[41],
                values[42],
                values[43],
                values[44],
                values[45],
                values[46],
                values[47],
                values[48],
                values[49],
                values[50],
                values[51],
                values[52],
                values[53],
                values[54],
                values[55],
                values[56],
                values[57],
                values[58],
                values[59],
                values[60],
                values[61],
                values[62],
                values[63],
                values[64],
                values[65],
                values[66],
                values[67],
                values[68],
                values[69],
                values[70],
                values[71],
                values[72],
                values[73],
                values[74],
                values[75],
                values[76],
                values[77],
                values[78],
                values[79],
                values[80],
                &missing,
            )
        };
        let nb = |values: [bool; 81]| -> String { nb_with_heavy(values, false) };
        let nb_heavy = |values: [bool; 81]| -> String { nb_with_heavy(values, true) };
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
            ]))),
            "budgeted_uncertainty_escalator"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
            ]))),
            "sparse_wake_proposal_budget"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
            ]))),
            "verifier_budget_auction"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
            ]))),
            "kv_page_sketch_index"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
            ]))),
            "kv_page_bloom_sketch_coverage"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
            ]))),
            "query_aware_kv_selector"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
            ]))),
            "sparse_wake_certificate_answer_packet"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
            ]))),
            "layer_kv_joint_lease"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
            ]))),
            "construction_search_tournament"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
            ]))),
            "route_distillation_tournament"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
            ]))),
            "proof_search_signal_route_feedback"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
            ]))),
            "proof_pressure_signal"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
            ]))),
            "verifier_regret_fast_weights"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
            ]))),
            "fast_weight_quarantine"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
            ]))),
            "depth_lease_checkpoint"
        );
        assert_eq!(
            nb(flags(&with_floor(&[
                PAGE_PACKETIZED,
                PAGE_CALLER,
                PAGE_POLICY,
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
            ]))),
            "shadow_wake_oracle"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
            ]))),
            "ablation_shadow_run"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
            ]))),
            "axiom_axiomatic_source_distinction"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
            ]))),
            "sparse_route_no_hidden_authority"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
            ]))),
            "coldstream_no_hidden_authority"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                SEVENTY_B,
            ]))),
            "coldstream_no_hidden_authority"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
            ]))),
            LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
            ]))),
            "provider_route_copy_source_guard"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
            ]))),
            "transport_trace_answer_packet"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
            ]))),
            "ssd_wear_budget"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
            ]))),
            "coldstream_vs_mmap"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
            ]))),
            "slab_arena_copy_count"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
                SLAB_ARENA_COPY_COUNT,
            ]))),
            "metal_io_feature_gate"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
                SLAB_ARENA_COPY_COUNT,
                METAL_IO_FEATURE_GATE,
            ]))),
            "codec_stage_latency"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
                SLAB_ARENA_COPY_COUNT,
                METAL_IO_FEATURE_GATE,
                CODEC_STAGE_LATENCY,
            ]))),
            "transport_cancellation"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
                SLAB_ARENA_COPY_COUNT,
                METAL_IO_FEATURE_GATE,
                CODEC_STAGE_LATENCY,
                TRANSPORT_CANCELLATION,
            ]))),
            "cache_policy_pollution"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
                SLAB_ARENA_COPY_COUNT,
                METAL_IO_FEATURE_GATE,
                CODEC_STAGE_LATENCY,
                TRANSPORT_CANCELLATION,
                CACHE_POLICY_POLLUTION,
            ]))),
            "cold_panic_fallback"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
                SLAB_ARENA_COPY_COUNT,
                METAL_IO_FEATURE_GATE,
                CODEC_STAGE_LATENCY,
                TRANSPORT_CANCELLATION,
                CACHE_POLICY_POLLUTION,
                COLD_PANIC_FALLBACK,
            ]))),
            "ready_for_product_route_review"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
                SLAB_ARENA_COPY_COUNT,
                METAL_IO_FEATURE_GATE,
                CODEC_STAGE_LATENCY,
                TRANSPORT_CANCELLATION,
                CACHE_POLICY_POLLUTION,
                COLD_PANIC_FALLBACK,
                PRODUCT_ROUTE_REVIEW,
            ]))),
            "small_model_runtime_harness_safety_plan"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
                SLAB_ARENA_COPY_COUNT,
                METAL_IO_FEATURE_GATE,
                CODEC_STAGE_LATENCY,
                TRANSPORT_CANCELLATION,
                CACHE_POLICY_POLLUTION,
                COLD_PANIC_FALLBACK,
                PRODUCT_ROUTE_REVIEW,
                SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN,
            ]))),
            "small_model_runtime_harness_dry_run_witness"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
                SLAB_ARENA_COPY_COUNT,
                METAL_IO_FEATURE_GATE,
                CODEC_STAGE_LATENCY,
                TRANSPORT_CANCELLATION,
                CACHE_POLICY_POLLUTION,
                COLD_PANIC_FALLBACK,
                PRODUCT_ROUTE_REVIEW,
                SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN,
                SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS,
            ]))),
            "small_model_runtime_harness_owner_approved_probe"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
                SLAB_ARENA_COPY_COUNT,
                METAL_IO_FEATURE_GATE,
                CODEC_STAGE_LATENCY,
                TRANSPORT_CANCELLATION,
                CACHE_POLICY_POLLUTION,
                COLD_PANIC_FALLBACK,
                PRODUCT_ROUTE_REVIEW,
                SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN,
                SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS,
                SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE,
            ]))),
            "small_model_runtime_harness_abortable_runtime_probe"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
                SLAB_ARENA_COPY_COUNT,
                METAL_IO_FEATURE_GATE,
                CODEC_STAGE_LATENCY,
                TRANSPORT_CANCELLATION,
                CACHE_POLICY_POLLUTION,
                COLD_PANIC_FALLBACK,
                PRODUCT_ROUTE_REVIEW,
                SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN,
                SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS,
                SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE,
                SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE,
            ]))),
            "small_model_runtime_harness_logged_runtime_smoke"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
                SLAB_ARENA_COPY_COUNT,
                METAL_IO_FEATURE_GATE,
                CODEC_STAGE_LATENCY,
                TRANSPORT_CANCELLATION,
                CACHE_POLICY_POLLUTION,
                COLD_PANIC_FALLBACK,
                PRODUCT_ROUTE_REVIEW,
                SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN,
                SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS,
                SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE,
                SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE,
                SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE,
            ]))),
            "small_model_runtime_harness_first_token_runtime_probe"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
                SLAB_ARENA_COPY_COUNT,
                METAL_IO_FEATURE_GATE,
                CODEC_STAGE_LATENCY,
                TRANSPORT_CANCELLATION,
                CACHE_POLICY_POLLUTION,
                COLD_PANIC_FALLBACK,
                PRODUCT_ROUTE_REVIEW,
                SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN,
                SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS,
                SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE,
                SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE,
                SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE,
                SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE,
            ]))),
            "small_model_runtime_harness_answer_packet_runtime_probe"
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
                TWO_STAGE_ROUTE_SCOUT_ABSTAIN,
                BUDGETED_UNCERTAINTY_ESCALATOR,
                SPARSE_WAKE_PROPOSAL_BUDGET,
                VERIFIER_BUDGET_AUCTION,
                KV_PAGE_SKETCH_INDEX,
                KV_PAGE_BLOOM_SKETCH_COVERAGE,
                QUERY_AWARE_KV_SELECTOR,
                SPARSE_WAKE_CERTIFICATE_ANSWER_PACKET,
                LAYER_KV_JOINT_LEASE,
                CONSTRUCTION_SEARCH_TOURNAMENT,
                ROUTE_DISTILLATION_TOURNAMENT,
                PROOF_SEARCH_SIGNAL_ROUTE_FEEDBACK,
                PROOF_PRESSURE_SIGNAL,
                VERIFIER_REGRET_FAST_WEIGHTS,
                FAST_WEIGHT_QUARANTINE,
                DEPTH_LEASE_CHECKPOINT,
                SHADOW_WAKE_ORACLE,
                ABLATION_SHADOW_RUN,
                AXIOM_AXIOMATIC_SOURCE_DISTINCTION,
                SPARSE_ROUTE_NO_HIDDEN_AUTHORITY,
                COLDSTREAM_NO_HIDDEN_AUTHORITY,
                LARGE_MODEL_PROVIDER_REFERENCE_DEFERRAL,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD,
                TRANSPORT_TRACE_ANSWER_PACKET,
                SSD_WEAR_BUDGET,
                COLDSTREAM_VS_MMAP,
                SLAB_ARENA_COPY_COUNT,
                METAL_IO_FEATURE_GATE,
                CODEC_STAGE_LATENCY,
                TRANSPORT_CANCELLATION,
                CACHE_POLICY_POLLUTION,
                COLD_PANIC_FALLBACK,
                PRODUCT_ROUTE_REVIEW,
                SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN,
                SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS,
                SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE,
                SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE,
                SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE,
                SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE,
                SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE,
            ]))),
            "small_model_runtime_harness_product_wrv_probe"
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
