//! `falsify_gemma_qat_e2b_route_answer_packet_visibility_gate`
//!
//! Metadata-only visibility contract for future Gemma E2B route AnswerPackets.
//! It reads only the upstream dry-run route witness, opens no model/runtime
//! bytes, emits no user-visible packet, and performs no route mutation.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaQatE2bRouteAnswerPacketVisibilityGate, GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
    GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_ID,
    GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_NEXT_CURSOR,
    GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_UPSTREAM_REF,
    GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH,
};

const FALSIFIER_ID: &str = GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_ID;
const FIXTURE_ID: &str = "gemma_qat_e2b_route_answer_packet_visibility_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_e2b_route_answer_packet_visibility_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_route_answer_packet_visibility_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_system_g_dry_run_route_packet_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_582_000_000;

fn main() -> std::process::ExitCode {
    let artifact = match build_artifact() {
        Ok(artifact) => artifact,
        Err(error) => {
            eprintln!("failed to build {FALSIFIER_ID}: {error}");
            return std::process::ExitCode::from(2);
        }
    };

    let path = PathBuf::from(RESULT);
    if let Some(parent) = path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create artifact directory: {error}");
            return std::process::ExitCode::from(2);
        }
    }
    let mut file = match std::fs::File::create(&path) {
        Ok(file) => file,
        Err(error) => {
            eprintln!("failed to open artifact: {error}");
            return std::process::ExitCode::from(2);
        }
    };
    if let Err(error) = write_artifact(&mut file, &artifact) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }

    println!(
        "{FALSIFIER_ID}: overall_pass={} visibility_fields={} emitted_to_user={} mutation_count={} model_bytes_loaded={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_visibility_field_count"].value,
        artifact.measurements["answer_packet_emitted_to_user_count"].value,
        artifact.measurements["mutation_count"].value,
        artifact.measurements["model_bytes_loaded"].value,
        artifact.measurements["red_fixture_rejection_count"].value,
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let upstream_pass = upstream_gate_pass()?;
    let gate = GemmaQatE2bRouteAnswerPacketVisibilityGate::canonical(
        GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_UPSTREAM_REF,
    );
    gate.validate()?;
    let reversed = GemmaQatE2bRouteAnswerPacketVisibilityGate {
        required_visibility_fields: gate
            .required_visibility_fields
            .iter()
            .cloned()
            .rev()
            .collect(),
        required_rejection_policies: gate
            .required_rejection_policies
            .iter()
            .cloned()
            .rev()
            .collect(),
        ..gate.clone()
    };
    reversed.validate()?;

    let metrics = gate.metrics();
    let red_results = red_fixture_results(&gate);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_dry_run_route_packet_gate_pass", upstream_pass),
        (
            "upstream_dry_run_route_packet_ref_bound",
            gate.upstream_dry_run_route_packet_ref
                == GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_UPSTREAM_REF,
        ),
        (
            "single_e2b_gguf_llama_cpp_visibility_lane_bound",
            gate.selected_model_id == "google/gemma-4-E2B-it-qat-q4_0-gguf"
                && gate.required_filename == "gemma-4-E2B_q4_0-it.gguf"
                && gate.expected_file_size_bytes == GEMMA_QAT_E2B_EXPECTED_FILE_BYTES
                && gate.command_path == GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH
                && red_pass(&red_results, "wrong_model")
                && red_pass(&red_results, "wrong_filename")
                && red_pass(&red_results, "wrong_expected_file_bytes")
                && red_pass(&red_results, "wrong_runtime_lane"),
        ),
        (
            "visibility_fields_and_rejection_policies_bound",
            metrics.required_visibility_field_count == 30
                && metrics.required_rejection_policy_count == 63
                && red_pass(&red_results, "missing_visibility_field")
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "answer_packet_template_and_visible_identity_bound",
            gate.upstream_dry_run_route_packet_digest_required
                && gate.answer_packet_template_digest_required
                && gate.visible_model_identity_required
                && gate.visible_runtime_lane_required
                && gate.visible_route_status_required
                && gate.visible_route_caveat_required
                && red_pass(&red_results, "upstream_digest_missing")
                && red_pass(&red_results, "answer_packet_template_missing")
                && red_pass(&red_results, "visible_model_identity_missing")
                && red_pass(&red_results, "visible_runtime_lane_missing")
                && red_pass(&red_results, "visible_route_status_missing")
                && red_pass(&red_results, "visible_route_caveat_missing"),
        ),
        (
            "visible_budget_privacy_and_build_boundary_bound",
            gate.visible_budget_summary_required
                && gate.visible_memory_headroom_required
                && gate.visible_kv_budget_required
                && gate.visible_latency_budget_required
                && gate.visible_privacy_class_required
                && gate.visible_mas_pro_boundary_required
                && red_pass(&red_results, "visible_budget_summary_missing")
                && red_pass(&red_results, "visible_memory_headroom_missing")
                && red_pass(&red_results, "visible_kv_budget_missing")
                && red_pass(&red_results, "visible_latency_budget_missing")
                && red_pass(&red_results, "visible_privacy_class_missing")
                && red_pass(&red_results, "visible_mas_pro_boundary_missing"),
        ),
        (
            "visible_scope_rex_sovereign_gate_fallback_and_abstention_bound",
            gate.visible_scope_rex_ref.starts_with("scope_rex:")
                && gate
                    .visible_sovereign_gate_ref
                    .starts_with("sovereign_gate:")
                && gate.visible_fallback_ref.starts_with("fallback:")
                && gate.visible_abstention_ref.starts_with("abstention:")
                && gate.visible_cancellation_ref.starts_with("cancel:")
                && red_pass(&red_results, "visible_scope_rex_missing")
                && red_pass(&red_results, "visible_sovereign_gate_missing")
                && red_pass(&red_results, "visible_fallback_missing")
                && red_pass(&red_results, "visible_abstention_missing")
                && red_pass(&red_results, "visible_cancellation_missing"),
        ),
        (
            "visible_rollback_run_event_surfaces_and_non_promotion_bound",
            gate.visible_rollback_ref.starts_with("rollback:")
                && gate.visible_run_event_log_ref.starts_with("run_event_log:")
                && gate.visible_no_default_model_mutation_required
                && gate.visible_no_hidden_authority_required
                && gate.visible_non_promotion_required
                && gate.settings_surface_copy_digest_required
                && gate.diagnostics_surface_copy_digest_required
                && gate.route_explanation_digest_required
                && gate.rejected_candidate_summary_digest_required
                && gate.user_action_required_digest_required
                && gate.no_quality_claim_digest_required
                && gate.no_live_default_claim_digest_required
                && gate.no_large_model_bypass_digest_required
                && red_pass(&red_results, "visible_rollback_missing")
                && red_pass(&red_results, "visible_run_event_log_missing")
                && red_pass(&red_results, "visible_no_default_model_mutation_missing")
                && red_pass(&red_results, "visible_no_hidden_authority_missing")
                && red_pass(&red_results, "visible_non_promotion_missing")
                && red_pass(&red_results, "settings_surface_copy_missing")
                && red_pass(&red_results, "diagnostics_surface_copy_missing")
                && red_pass(&red_results, "route_explanation_missing")
                && red_pass(&red_results, "rejected_candidate_summary_missing")
                && red_pass(&red_results, "user_action_required_missing")
                && red_pass(&red_results, "no_quality_claim_missing")
                && red_pass(&red_results, "no_live_default_claim_missing")
                && red_pass(&red_results, "no_large_model_bypass_missing"),
        ),
        (
            "visibility_packet_deferred",
            metrics.future_visibility_packet_present_count == 0
                && metrics.future_visibility_packet_bytes_read == 0
                && metrics.answer_packet_emitted_to_user_count == 0
                && red_pass(&red_results, "future_visibility_packet_present")
                && red_pass(&red_results, "future_visibility_packet_bytes_read")
                && red_pass(&red_results, "answer_packet_emitted_to_user"),
        ),
        (
            "zero_route_mutation_command_model_runtime_provider_actions",
            metrics.system_g_dry_run_performed_count == 0
                && metrics.admission_performed_count == 0
                && metrics.route_priority_mutation_count == 0
                && metrics.mutation_count == 0
                && metrics.command_executed_count == 0
                && metrics.runtime_replay_performed_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "system_g_dry_run_performed")
                && red_pass(&red_results, "admission_performed")
                && red_pass(&red_results, "route_priority_mutation")
                && red_pass(&red_results, "runtime_router_mutation")
                && red_pass(&red_results, "system_g_mutation")
                && red_pass(&red_results, "default_model_mutation")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "runtime_replay_performed")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "privacy_and_answer_packet_visibility_preserved",
            metrics.raw_prompt_bytes_captured == 0
                && metrics.raw_output_bytes_captured == 0
                && metrics.answer_packet_suppressed_count == 0
                && red_pass(&red_results, "raw_prompt_captured")
                && red_pass(&red_results, "raw_output_captured")
                && red_pass(&red_results, "answer_packet_suppressed"),
        ),
        (
            "no_hidden_authority_or_cloud_fallback",
            metrics.hidden_authority_count == 0
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_eidos_authority")
                && red_pass(&red_results, "hidden_lattice_authority")
                && red_pass(&red_results, "hidden_patternboost_authority")
                && red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "no_mas_l2_l3_t4_product_gemma_default_quality_or_large_model_claim",
            metrics.promotion_claim_count == 0
                && red_pass(&red_results, "mas_l2_l3_t4_product_claim")
                && red_pass(&red_results, "product_route_green")
                && red_pass(&red_results, "gemma_default_claim")
                && red_pass(&red_results, "larger_model_bypass")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim")
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "benchmark_fit_claim"),
        ),
        (
            "gemma_e2b_route_answer_packet_visibility_gate_address_deterministic",
            gate.visibility_gate_address(CREATED_AT_MS)
                == reversed.visibility_gate_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_NEXT_CURSOR
                == "gemma_qat_e2b_settings_diagnostics_wrv_gate",
        ),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }

    for (name, value, operator, expected, unit) in [
        (
            "required_visibility_field_count",
            metrics.required_visibility_field_count,
            "==",
            30,
            "fields",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            63,
            "policies",
        ),
        (
            "future_visibility_packet_present_count",
            metrics.future_visibility_packet_present_count,
            "==",
            0,
            "packets",
        ),
        (
            "future_visibility_packet_bytes_read",
            metrics.future_visibility_packet_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "answer_packet_emitted_to_user_count",
            metrics.answer_packet_emitted_to_user_count,
            "==",
            0,
            "packets",
        ),
        (
            "system_g_dry_run_performed_count",
            metrics.system_g_dry_run_performed_count,
            "==",
            0,
            "actions",
        ),
        (
            "admission_performed_count",
            metrics.admission_performed_count,
            "==",
            0,
            "actions",
        ),
        (
            "route_priority_mutation_count",
            metrics.route_priority_mutation_count,
            "==",
            0,
            "mutations",
        ),
        (
            "mutation_count",
            metrics.mutation_count,
            "==",
            0,
            "mutations",
        ),
        (
            "command_executed_count",
            metrics.command_executed_count,
            "==",
            0,
            "commands",
        ),
        (
            "runtime_replay_performed_count",
            metrics.runtime_replay_performed_count,
            "==",
            0,
            "replays",
        ),
        (
            "model_bytes_loaded",
            metrics.model_bytes_loaded,
            "==",
            0,
            "bytes",
        ),
        (
            "runtime_bytes_loaded",
            metrics.runtime_bytes_loaded,
            "==",
            0,
            "bytes",
        ),
        (
            "provider_calls_made",
            metrics.provider_calls_made,
            "==",
            0,
            "calls",
        ),
        (
            "raw_prompt_bytes_captured",
            metrics.raw_prompt_bytes_captured,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_output_bytes_captured",
            metrics.raw_output_bytes_captured,
            "==",
            0,
            "bytes",
        ),
        (
            "answer_packet_suppressed_count",
            metrics.answer_packet_suppressed_count,
            "==",
            0,
            "suppressed",
        ),
        (
            "hidden_authority_count",
            metrics.hidden_authority_count,
            "==",
            0,
            "claims",
        ),
        (
            "promotion_claim_count",
            metrics.promotion_claim_count,
            "==",
            0,
            "claims",
        ),
        (
            "expected_file_size_bytes",
            gate.expected_file_size_bytes,
            "==",
            GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
            "bytes",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            ">=",
            76,
            "fixtures",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            value,
            operator,
            expected,
            unit,
        );
    }

    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "gemma_e2b_route_answer_packet_visibility_gate_address",
        &gate.visibility_gate_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_NEXT_CURSOR,
        "gemma_qat_e2b_settings_diagnostics_wrv_gate",
    );

    assert_axis_coverage(&measurements);

    Ok(ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: Vec::new(),
        notes: "metadata-only F-GemmaQATE2BRouteAnswerPacketVisibilityGate: consumes the E2B System G dry-run route packet gate and defines the fail-closed AnswerPacket visibility contract before Gemma E2B route evidence can reach settings, diagnostics, or WRV surfaces. It binds visible model identity, runtime lane, route status, caveats, budgets, privacy, MAS/Pro boundary, SCOPE-Rex, SovereignGate, fallback, abstention, cancellation, rollback, RunEventLog, route explanation, rejected candidate summary, user-action requirements, and explicit non-claims. It reads zero visibility packet bytes, emits zero user-visible AnswerPackets, performs zero dry-run/admission actions, mutates zero routes, arms or executes zero commands, loads zero model/runtime/provider bytes, captures zero raw prompt/output bytes, suppresses zero AnswerPackets, and makes no MAS/L2/L3/T4/user-facing, Gemma-default, quality, benchmark-fit, E4B/12B/70B bypass, live-70B, or SSD-as-RAM claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_gate_pass() -> Result<bool, Box<dyn std::error::Error>> {
    if !Path::new(UPSTREAM_RESULT).exists() {
        return Ok(false);
    }
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(UPSTREAM_RESULT)?)?;
    Ok(value
        .get("overall_pass")
        .and_then(|value| value.as_bool())
        .unwrap_or(false))
}

fn red_fixture_results(
    gate: &GemmaQatE2bRouteAnswerPacketVisibilityGate,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaQatE2bRouteAnswerPacketVisibilityGate)>,
    )> = vec![
        (
            "wrong_model",
            Box::new(|g| g.selected_model_id = "google/gemma-4-E4B-it-qat-q4_0-gguf".to_string()),
        ),
        (
            "wrong_filename",
            Box::new(|g| g.required_filename = "gemma-4-E4B_q4_0-it.gguf".to_string()),
        ),
        (
            "wrong_expected_file_bytes",
            Box::new(|g| g.expected_file_size_bytes += 1),
        ),
        (
            "wrong_runtime_lane",
            Box::new(|g| g.runtime_lane = agent_core::uas::GemmaFamilyRuntimeLane::LiteRtLm),
        ),
        (
            "bad_upstream_route_ref",
            Box::new(|g| {
                g.upstream_dry_run_route_packet_ref = "artifact:falsifiers/wrong/".to_string()
            }),
        ),
        (
            "bad_upstream_route_id",
            Box::new(|g| g.upstream_dry_run_route_packet_id = "F-Wrong".to_string()),
        ),
        (
            "bad_upstream_admission_ref",
            Box::new(|g| {
                g.upstream_admission_packet_ref =
                    "artifact:falsifiers/wrong/result.json#F-Wrong".to_string()
            }),
        ),
        (
            "bad_artifact_root",
            Box::new(|g| g.artifact_root_prefix = "artifacts/falsifiers/wrong/".to_string()),
        ),
        (
            "bad_visibility_card_id",
            Box::new(|g| g.visibility_card_id = "wrong-card".to_string()),
        ),
        (
            "bad_future_packet_name",
            Box::new(|g| g.future_visibility_packet_name = "wrong-packet".to_string()),
        ),
        (
            "missing_visibility_field",
            Box::new(|g| {
                g.required_visibility_fields.pop();
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|g| {
                g.required_rejection_policies.pop();
            }),
        ),
        (
            "upstream_digest_missing",
            Box::new(|g| g.upstream_dry_run_route_packet_digest_required = false),
        ),
        (
            "answer_packet_template_missing",
            Box::new(|g| g.answer_packet_template_digest_required = false),
        ),
        (
            "visible_model_identity_missing",
            Box::new(|g| g.visible_model_identity_required = false),
        ),
        (
            "visible_runtime_lane_missing",
            Box::new(|g| g.visible_runtime_lane_required = false),
        ),
        (
            "visible_route_status_missing",
            Box::new(|g| g.visible_route_status_required = false),
        ),
        (
            "visible_route_caveat_missing",
            Box::new(|g| g.visible_route_caveat_required = false),
        ),
        (
            "visible_budget_summary_missing",
            Box::new(|g| g.visible_budget_summary_required = false),
        ),
        (
            "visible_memory_headroom_missing",
            Box::new(|g| g.visible_memory_headroom_required = false),
        ),
        (
            "visible_kv_budget_missing",
            Box::new(|g| g.visible_kv_budget_required = false),
        ),
        (
            "visible_latency_budget_missing",
            Box::new(|g| g.visible_latency_budget_required = false),
        ),
        (
            "visible_privacy_class_missing",
            Box::new(|g| g.visible_privacy_class_required = false),
        ),
        (
            "visible_mas_pro_boundary_missing",
            Box::new(|g| g.visible_mas_pro_boundary_required = false),
        ),
        (
            "visible_scope_rex_missing",
            Box::new(|g| g.visible_scope_rex_ref = "missing".to_string()),
        ),
        (
            "visible_sovereign_gate_missing",
            Box::new(|g| g.visible_sovereign_gate_ref = "missing".to_string()),
        ),
        (
            "visible_fallback_missing",
            Box::new(|g| g.visible_fallback_ref = "hidden".to_string()),
        ),
        (
            "visible_abstention_missing",
            Box::new(|g| g.visible_abstention_ref = "none".to_string()),
        ),
        (
            "visible_cancellation_missing",
            Box::new(|g| g.visible_cancellation_ref = "missing".to_string()),
        ),
        (
            "visible_rollback_missing",
            Box::new(|g| g.visible_rollback_ref = "missing".to_string()),
        ),
        (
            "visible_run_event_log_missing",
            Box::new(|g| g.visible_run_event_log_ref = "missing".to_string()),
        ),
        (
            "visible_no_default_model_mutation_missing",
            Box::new(|g| g.visible_no_default_model_mutation_required = false),
        ),
        (
            "visible_no_hidden_authority_missing",
            Box::new(|g| g.visible_no_hidden_authority_required = false),
        ),
        (
            "visible_non_promotion_missing",
            Box::new(|g| g.visible_non_promotion_required = false),
        ),
        (
            "settings_surface_copy_missing",
            Box::new(|g| g.settings_surface_copy_digest_required = false),
        ),
        (
            "diagnostics_surface_copy_missing",
            Box::new(|g| g.diagnostics_surface_copy_digest_required = false),
        ),
        (
            "route_explanation_missing",
            Box::new(|g| g.route_explanation_digest_required = false),
        ),
        (
            "rejected_candidate_summary_missing",
            Box::new(|g| g.rejected_candidate_summary_digest_required = false),
        ),
        (
            "user_action_required_missing",
            Box::new(|g| g.user_action_required_digest_required = false),
        ),
        (
            "no_quality_claim_missing",
            Box::new(|g| g.no_quality_claim_digest_required = false),
        ),
        (
            "no_live_default_claim_missing",
            Box::new(|g| g.no_live_default_claim_digest_required = false),
        ),
        (
            "no_large_model_bypass_missing",
            Box::new(|g| g.no_large_model_bypass_digest_required = false),
        ),
        (
            "future_visibility_packet_present",
            Box::new(|g| g.future_visibility_packet_present = true),
        ),
        (
            "future_visibility_packet_bytes_read",
            Box::new(|g| g.future_visibility_packet_bytes_read = 1),
        ),
        (
            "answer_packet_emitted_to_user",
            Box::new(|g| g.answer_packet_emitted_to_user_count = 1),
        ),
        (
            "system_g_dry_run_performed",
            Box::new(|g| g.system_g_dry_run_performed_count = 1),
        ),
        (
            "admission_performed",
            Box::new(|g| g.admission_performed_count = 1),
        ),
        (
            "route_priority_mutation",
            Box::new(|g| g.route_priority_mutation_count = 1),
        ),
        (
            "runtime_router_mutation",
            Box::new(|g| g.runtime_router_mutation_allowed = true),
        ),
        (
            "system_g_mutation",
            Box::new(|g| g.system_g_mutation_allowed = true),
        ),
        (
            "default_model_mutation",
            Box::new(|g| g.default_model_mutation_allowed = true),
        ),
        ("command_armed", Box::new(|g| g.command_armed = true)),
        ("command_executed", Box::new(|g| g.command_executed = true)),
        (
            "runtime_replay_performed",
            Box::new(|g| g.runtime_replay_performed = true),
        ),
        ("model_bytes_loaded", Box::new(|g| g.model_bytes_loaded = 1)),
        (
            "runtime_bytes_loaded",
            Box::new(|g| g.runtime_bytes_loaded = 1),
        ),
        (
            "provider_calls_made",
            Box::new(|g| g.provider_calls_made = 1),
        ),
        (
            "raw_prompt_captured",
            Box::new(|g| g.raw_prompt_bytes_captured = 1),
        ),
        (
            "raw_output_captured",
            Box::new(|g| g.raw_output_bytes_captured = 1),
        ),
        (
            "answer_packet_suppressed",
            Box::new(|g| g.answer_packet_suppressed = true),
        ),
        (
            "hidden_route_authority",
            Box::new(|g| g.hidden_route_authority = true),
        ),
        (
            "hidden_eidos_authority",
            Box::new(|g| g.hidden_eidos_authority = true),
        ),
        (
            "hidden_lattice_authority",
            Box::new(|g| g.hidden_lattice_authority = true),
        ),
        (
            "hidden_patternboost_authority",
            Box::new(|g| g.hidden_patternboost_authority = true),
        ),
        (
            "hidden_cloud_fallback",
            Box::new(|g| g.hidden_cloud_fallback = true),
        ),
        (
            "mas_l2_l3_t4_product_claim",
            Box::new(|g| {
                g.mas_promoted = true;
                g.l2_capability_effect = true;
                g.l3_wrv_effect = true;
                g.t4_build_green_effect = true;
            }),
        ),
        (
            "product_route_green",
            Box::new(|g| g.product_route_green = true),
        ),
        (
            "gemma_default_claim",
            Box::new(|g| g.live_gemma_default_claim = true),
        ),
        (
            "larger_model_bypass",
            Box::new(|g| g.larger_model_bypass_allowed = true),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|g| g.live_dense_70b_claim = true),
        ),
        ("ssd_as_ram_claim", Box::new(|g| g.ssd_as_ram_claim = true)),
        ("quality_claim", Box::new(|g| g.quality_claimed = true)),
        (
            "benchmark_fit_claim",
            Box::new(|g| g.benchmark_claimed_as_fit = true),
        ),
        (
            "metadata_budget_overflow",
            Box::new(|g| g.metadata_bytes = 400 * 1024),
        ),
        (
            "wrong_product_build",
            Box::new(|g| g.product_build = agent_core::uas::ProductBuild::Mas),
        ),
        (
            "wrong_pro_status",
            Box::new(|g| g.pro_status = agent_core::uas::ProStatus::Live),
        ),
        (
            "wrong_next_cursor",
            Box::new(|g| g.next_cursor = "wrong_next".to_string()),
        ),
    ];
    cases
        .into_iter()
        .map(|(name, mutate)| {
            let mut mutated = gate.clone();
            mutate(&mut mutated);
            (name, mutated.validate().is_err())
        })
        .collect()
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(case, _)| *case == name)
        .map(|(_, passed)| *passed)
        .unwrap_or(false)
}

fn add_text_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
    expected: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "text".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::String(expected.to_string()),
            unit: "text".to_string(),
        },
    );
    pass_per_axis.insert(
        name.to_string(),
        if expected == "non_empty" {
            !value.trim().is_empty()
        } else {
            value == expected
        },
    );
}

fn assert_axis_coverage(measurements: &BTreeMap<String, Measurement>) {
    for axis in GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
