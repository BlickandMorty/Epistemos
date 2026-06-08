//! `falsify_gemma_qat_e2b_release_audit_surface_gate`
//!
//! Metadata-only release-audit contract for the future Gemma E2B product route.
//! It reads only the upstream settings/diagnostics WRV witness, opens no
//! model/runtime bytes, runs no Xcode command, and performs no route mutation.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaQatE2bReleaseAuditSurfaceGate, GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
    GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_ID,
    GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_NEXT_CURSOR,
    GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_UPSTREAM_REF, GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH,
};

const FALSIFIER_ID: &str = GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_ID;
const FIXTURE_ID: &str = "gemma_qat_e2b_release_audit_surface_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_e2b_release_audit_surface_gate.sh";
const RESULT: &str = "artifacts/falsifiers/gemma_qat_e2b_release_audit_surface_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_settings_diagnostics_wrv_gate/result.json";
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
        "{FALSIFIER_ID}: overall_pass={} release_fields={} settings_row_wired={} xcode_executed={} model_bytes_loaded={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_release_surface_field_count"].value,
        artifact.measurements["settings_row_wired_count"].value,
        artifact.measurements["xcode_command_executed_count"].value,
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
    let gate = GemmaQatE2bReleaseAuditSurfaceGate::canonical(
        GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_UPSTREAM_REF,
    );
    gate.validate()?;
    let reversed = GemmaQatE2bReleaseAuditSurfaceGate {
        required_release_surface_fields: gate
            .required_release_surface_fields
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
        ("upstream_settings_diagnostics_wrv_gate_pass", upstream_pass),
        (
            "upstream_settings_diagnostics_wrv_ref_bound",
            gate.upstream_settings_diagnostics_wrv_ref
                == GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_UPSTREAM_REF,
        ),
        (
            "single_e2b_gguf_llama_cpp_release_lane_bound",
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
            "release_audit_skill_and_blocker_bound",
            gate.release_audit_skill_ref == ".agents/skills/epistemos_release_audit/SKILL.md"
                && gate.automated_checks_blocker_ref
                    == "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe"
                && red_pass(&red_results, "bad_release_audit_skill")
                && red_pass(&red_results, "bad_product_blocker"),
        ),
        (
            "graph_filter_proof_root_boundary_bound",
            gate.focused_proof_root_command_card_ref
                == "F-GraphFilterVisibilityFocusedProofRootCommandCard"
                && gate.focused_proof_root_execution_artifact_gate_ref
                    == "F-GraphFilterVisibilityFocusedProofRootExecutionArtifactGate"
                && gate.owner_approval_runbook_ref
                    == "docs/audits/FOCUSED_PROOF_ROOT_OWNER_APPROVAL_RUNBOOK_2026_06_08.md"
                && red_pass(&red_results, "bad_command_card")
                && red_pass(&red_results, "bad_execution_artifact_gate")
                && red_pass(&red_results, "bad_owner_approval_runbook"),
        ),
        (
            "release_surface_fields_and_rejection_policies_bound",
            metrics.required_release_surface_field_count == 40
                && metrics.required_rejection_policy_count == 72
                && red_pass(&red_results, "missing_release_surface_field")
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "automated_log_manual_distribution_zero_fail_required",
            gate.upstream_settings_diagnostics_wrv_digest_required
                && gate.log_correlation_evidence_required
                && gate.manual_runtime_verification_required
                && gate.distribution_compliance_evidence_required
                && gate.repeated_zero_fail_evidence_required
                && red_pass(&red_results, "upstream_digest_missing")
                && red_pass(&red_results, "log_correlation_missing")
                && red_pass(&red_results, "manual_runtime_missing")
                && red_pass(&red_results, "distribution_compliance_missing")
                && red_pass(&red_results, "repeated_zero_fail_missing"),
        ),
        (
            "visible_copy_answerpacket_run_event_rollback_bound",
            gate.settings_visible_copy_digest_required
                && gate.diagnostics_visible_copy_digest_required
                && gate.answer_packet_template_digest_required
                && gate.run_event_log_digest_required
                && gate.rollback_digest_required
                && gate.abstention_digest_required
                && gate.scope_rex_digest_required
                && gate.sovereign_gate_digest_required
                && gate.cancellation_digest_required
                && red_pass(&red_results, "settings_copy_missing")
                && red_pass(&red_results, "diagnostics_copy_missing")
                && red_pass(&red_results, "answer_packet_template_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "abstention_missing")
                && red_pass(&red_results, "scope_rex_missing")
                && red_pass(&red_results, "sovereign_gate_missing")
                && red_pass(&red_results, "cancellation_missing"),
        ),
        (
            "non_claims_and_fast_row_gated_visibility_bound",
            gate.non_promotion_digest_required
                && gate.no_toggle_unlock_digest_required
                && gate.no_default_model_mutation_digest_required
                && gate.no_runtime_route_admission_digest_required
                && gate.no_xcode_execution_digest_required
                && gate.no_model_bytes_digest_required
                && gate.no_command_armed_digest_required
                && gate.no_raw_prompt_output_digest_required
                && gate.no_hidden_authority_digest_required
                && gate.no_cloud_fallback_digest_required
                && gate.no_mas_promotion_digest_required
                && gate.no_l2_l3_t4_digest_required
                && gate.no_quality_claim_digest_required
                && gate.no_benchmark_fit_digest_required
                && gate.no_e4b_12b_bypass_digest_required
                && gate.no_live_70b_digest_required
                && gate.no_ssd_as_ram_digest_required
                && gate.owner_action_required_digest_required
                && gate.product_capability_recheck_deferred_digest_required
                && gate.fast_row_gated_visibility_digest_required
                && gate.release_surface_packet_digest_required
                && red_pass(&red_results, "non_promotion_missing")
                && red_pass(&red_results, "no_default_model_mutation_missing")
                && red_pass(&red_results, "no_runtime_route_admission_missing")
                && red_pass(&red_results, "no_xcode_execution_missing")
                && red_pass(&red_results, "no_model_bytes_missing")
                && red_pass(&red_results, "no_command_armed_missing")
                && red_pass(&red_results, "owner_action_required_missing")
                && red_pass(&red_results, "product_capability_recheck_deferred_missing")
                && red_pass(&red_results, "fast_row_gated_visibility_missing")
                && red_pass(&red_results, "release_surface_packet_digest_missing"),
        ),
        (
            "future_release_packet_deferred",
            metrics.future_release_packet_present_count == 0
                && metrics.future_release_packet_bytes_read == 0
                && red_pass(&red_results, "future_release_packet_present")
                && red_pass(&red_results, "future_release_packet_bytes_read"),
        ),
        (
            "zero_settings_diagnostics_answerpacket_route_xcode_actions",
            metrics.settings_row_wired_count == 0
                && metrics.diagnostics_ui_wired_count == 0
                && metrics.user_visible_answer_packet_emitted_count == 0
                && metrics.release_surface_action_count == 0
                && red_pass(&red_results, "settings_row_wired")
                && red_pass(&red_results, "diagnostics_ui_wired")
                && red_pass(&red_results, "user_visible_answer_packet_emitted")
                && red_pass(&red_results, "runtime_router_mutation")
                && red_pass(&red_results, "system_g_mutation")
                && red_pass(&red_results, "default_model_mutation")
                && red_pass(&red_results, "route_admitted")
                && red_pass(&red_results, "xcode_command_executed"),
        ),
        (
            "zero_model_command_runtime_provider_actions",
            metrics.model_command_armed_count == 0
                && metrics.model_command_executed_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "model_command_armed")
                && red_pass(&red_results, "model_command_executed")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "privacy_preserved",
            metrics.raw_prompt_bytes_captured == 0
                && metrics.raw_output_bytes_captured == 0
                && red_pass(&red_results, "raw_prompt_captured")
                && red_pass(&red_results, "raw_output_captured"),
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
            "gemma_e2b_release_audit_surface_gate_address_deterministic",
            gate.release_surface_address(CREATED_AT_MS)
                == reversed.release_surface_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_NEXT_CURSOR
                == "gemma_qat_e2b_product_capability_recheck_gate",
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
            "required_release_surface_field_count",
            metrics.required_release_surface_field_count,
            "==",
            40,
            "fields",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            72,
            "policies",
        ),
        (
            "future_release_packet_present_count",
            metrics.future_release_packet_present_count,
            "==",
            0,
            "packets",
        ),
        (
            "future_release_packet_bytes_read",
            metrics.future_release_packet_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "settings_row_wired_count",
            metrics.settings_row_wired_count,
            "==",
            0,
            "surfaces",
        ),
        (
            "diagnostics_ui_wired_count",
            metrics.diagnostics_ui_wired_count,
            "==",
            0,
            "surfaces",
        ),
        (
            "user_visible_answer_packet_emitted_count",
            metrics.user_visible_answer_packet_emitted_count,
            "==",
            0,
            "packets",
        ),
        (
            "release_surface_action_count",
            metrics.release_surface_action_count,
            "==",
            0,
            "actions",
        ),
        (
            "xcode_command_executed_count",
            gate.xcode_command_executed as u64,
            "==",
            0,
            "commands",
        ),
        (
            "model_command_armed_count",
            metrics.model_command_armed_count,
            "==",
            0,
            "commands",
        ),
        (
            "model_command_executed_count",
            metrics.model_command_executed_count,
            "==",
            0,
            "commands",
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
            80,
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
        "gemma_e2b_release_audit_surface_gate_address",
        &gate.release_surface_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_NEXT_CURSOR,
        "gemma_qat_e2b_product_capability_recheck_gate",
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
        notes: "metadata-only F-GemmaQATE2BReleaseAuditSurfaceGate: consumes the E2B settings/diagnostics WRV gate and defines the release-audit surface required before a fast Gemma row can become any product route or default-model claim. It binds the release-audit skill, red automated-check blocker, graph-filter proof-root command card, execution-artifact parser gate, owner-approval runbook, log/manual/distribution/repeated-zero-fail requirements, settings and diagnostics copy, AnswerPacket, RunEventLog, rollback, abstention, SCOPE-Rex, SovereignGate, cancellation, non-promotion, fast-row gated visibility, owner action, and product-capability recheck deferral. It reads zero release packet bytes, wires zero settings or diagnostics surfaces, emits zero user-visible AnswerPackets, runs zero Xcode commands, mutates zero routes/defaults, arms or executes zero model commands, loads zero model/runtime/provider bytes, captures zero raw prompt/output bytes, and makes no MAS/L2/L3/T4/user-facing, Gemma-default, quality, benchmark-fit, E4B/12B/70B bypass, live-70B, or SSD-as-RAM claim.".to_string(),
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

fn red_fixture_results(gate: &GemmaQatE2bReleaseAuditSurfaceGate) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaQatE2bReleaseAuditSurfaceGate)>,
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
            "bad_upstream_ref",
            Box::new(|g| g.upstream_settings_diagnostics_wrv_ref = "artifact:wrong".to_string()),
        ),
        (
            "bad_upstream_id",
            Box::new(|g| g.upstream_settings_diagnostics_wrv_id = "F-Wrong".to_string()),
        ),
        (
            "bad_artifact_root",
            Box::new(|g| g.artifact_root_prefix = "artifacts/falsifiers/wrong/".to_string()),
        ),
        (
            "bad_release_surface_card_id",
            Box::new(|g| g.release_surface_card_id = "wrong-card".to_string()),
        ),
        (
            "bad_future_packet_name",
            Box::new(|g| g.future_release_packet_name = "wrong-packet".to_string()),
        ),
        (
            "bad_release_audit_skill",
            Box::new(|g| g.release_audit_skill_ref = "wrong".to_string()),
        ),
        (
            "bad_product_blocker",
            Box::new(|g| g.automated_checks_blocker_ref = "wrong".to_string()),
        ),
        (
            "bad_command_card",
            Box::new(|g| g.focused_proof_root_command_card_ref = "F-Wrong".to_string()),
        ),
        (
            "bad_execution_artifact_gate",
            Box::new(|g| g.focused_proof_root_execution_artifact_gate_ref = "F-Wrong".to_string()),
        ),
        (
            "bad_owner_approval_runbook",
            Box::new(|g| g.owner_approval_runbook_ref = "wrong.md".to_string()),
        ),
        (
            "missing_release_surface_field",
            Box::new(|g| {
                g.required_release_surface_fields.pop();
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
            Box::new(|g| g.upstream_settings_diagnostics_wrv_digest_required = false),
        ),
        (
            "log_correlation_missing",
            Box::new(|g| g.log_correlation_evidence_required = false),
        ),
        (
            "manual_runtime_missing",
            Box::new(|g| g.manual_runtime_verification_required = false),
        ),
        (
            "distribution_compliance_missing",
            Box::new(|g| g.distribution_compliance_evidence_required = false),
        ),
        (
            "repeated_zero_fail_missing",
            Box::new(|g| g.repeated_zero_fail_evidence_required = false),
        ),
        (
            "settings_copy_missing",
            Box::new(|g| g.settings_visible_copy_digest_required = false),
        ),
        (
            "diagnostics_copy_missing",
            Box::new(|g| g.diagnostics_visible_copy_digest_required = false),
        ),
        (
            "answer_packet_template_missing",
            Box::new(|g| g.answer_packet_template_digest_required = false),
        ),
        (
            "run_event_log_missing",
            Box::new(|g| g.run_event_log_digest_required = false),
        ),
        (
            "rollback_missing",
            Box::new(|g| g.rollback_digest_required = false),
        ),
        (
            "abstention_missing",
            Box::new(|g| g.abstention_digest_required = false),
        ),
        (
            "scope_rex_missing",
            Box::new(|g| g.scope_rex_digest_required = false),
        ),
        (
            "sovereign_gate_missing",
            Box::new(|g| g.sovereign_gate_digest_required = false),
        ),
        (
            "cancellation_missing",
            Box::new(|g| g.cancellation_digest_required = false),
        ),
        (
            "non_promotion_missing",
            Box::new(|g| g.non_promotion_digest_required = false),
        ),
        (
            "no_toggle_unlock_missing",
            Box::new(|g| g.no_toggle_unlock_digest_required = false),
        ),
        (
            "no_default_model_mutation_missing",
            Box::new(|g| g.no_default_model_mutation_digest_required = false),
        ),
        (
            "no_runtime_route_admission_missing",
            Box::new(|g| g.no_runtime_route_admission_digest_required = false),
        ),
        (
            "no_xcode_execution_missing",
            Box::new(|g| g.no_xcode_execution_digest_required = false),
        ),
        (
            "no_model_bytes_missing",
            Box::new(|g| g.no_model_bytes_digest_required = false),
        ),
        (
            "no_command_armed_missing",
            Box::new(|g| g.no_command_armed_digest_required = false),
        ),
        (
            "no_raw_prompt_output_missing",
            Box::new(|g| g.no_raw_prompt_output_digest_required = false),
        ),
        (
            "no_hidden_authority_missing",
            Box::new(|g| g.no_hidden_authority_digest_required = false),
        ),
        (
            "no_cloud_fallback_missing",
            Box::new(|g| g.no_cloud_fallback_digest_required = false),
        ),
        (
            "no_mas_promotion_missing",
            Box::new(|g| g.no_mas_promotion_digest_required = false),
        ),
        (
            "no_l2_l3_t4_missing",
            Box::new(|g| g.no_l2_l3_t4_digest_required = false),
        ),
        (
            "no_quality_claim_missing",
            Box::new(|g| g.no_quality_claim_digest_required = false),
        ),
        (
            "no_benchmark_fit_missing",
            Box::new(|g| g.no_benchmark_fit_digest_required = false),
        ),
        (
            "no_e4b_12b_bypass_missing",
            Box::new(|g| g.no_e4b_12b_bypass_digest_required = false),
        ),
        (
            "no_live_70b_missing",
            Box::new(|g| g.no_live_70b_digest_required = false),
        ),
        (
            "no_ssd_as_ram_missing",
            Box::new(|g| g.no_ssd_as_ram_digest_required = false),
        ),
        (
            "owner_action_required_missing",
            Box::new(|g| g.owner_action_required_digest_required = false),
        ),
        (
            "product_capability_recheck_deferred_missing",
            Box::new(|g| g.product_capability_recheck_deferred_digest_required = false),
        ),
        (
            "fast_row_gated_visibility_missing",
            Box::new(|g| g.fast_row_gated_visibility_digest_required = false),
        ),
        (
            "release_surface_packet_digest_missing",
            Box::new(|g| g.release_surface_packet_digest_required = false),
        ),
        (
            "future_release_packet_present",
            Box::new(|g| g.future_release_packet_present = true),
        ),
        (
            "future_release_packet_bytes_read",
            Box::new(|g| g.future_release_packet_bytes_read = 1),
        ),
        (
            "settings_row_wired",
            Box::new(|g| g.settings_row_wired = true),
        ),
        (
            "diagnostics_ui_wired",
            Box::new(|g| g.diagnostics_ui_wired = true),
        ),
        (
            "user_visible_answer_packet_emitted",
            Box::new(|g| g.user_visible_answer_packet_emitted_count = 1),
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
        ("route_admitted", Box::new(|g| g.route_admitted = true)),
        (
            "xcode_command_executed",
            Box::new(|g| g.xcode_command_executed = true),
        ),
        (
            "model_command_armed",
            Box::new(|g| g.model_command_armed = true),
        ),
        (
            "model_command_executed",
            Box::new(|g| g.model_command_executed = true),
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
            Box::new(|g| g.metadata_bytes = 500 * 1024),
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
    for axis in GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
