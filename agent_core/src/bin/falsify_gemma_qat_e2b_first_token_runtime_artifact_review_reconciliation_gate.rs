//! `falsify_gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate`
//!
//! Metadata-only reconciliation contract for a future owner-approved Gemma E2B
//! GGUF/llama.cpp one-token runtime artifact. It reads only the upstream
//! falsifier artifact, does not read runtime artifacts, does not open files,
//! does not arm commands, and does not promote Gemma into System G.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGate,
    GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
    GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_ID,
    GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_NEXT_CURSOR,
    GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_UPSTREAM_REF,
    GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH,
};

const FALSIFIER_ID: &str = GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_ID;
const FIXTURE_ID: &str = "gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate.sh";
const RESULT: &str = "artifacts/falsifiers/gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_owner_approved_first_token_runtime_probe/result.json";
const CREATED_AT_MS: u64 = 1_779_402_000_000;

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
        "{FALSIFIER_ID}: overall_pass={} reconciliation_fields={} artifact_bytes_read={} reconciliation_performed={} first_token_observed={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_reconciliation_field_count"].value,
        artifact.measurements["future_runtime_artifact_bytes_read"].value,
        artifact.measurements["reconciliation_performed_count"].value,
        artifact.measurements["first_token_observed_count"].value,
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
    let gate = GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGate::canonical(
        GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_UPSTREAM_REF,
    );
    gate.validate()?;
    let reversed = GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGate {
        required_reconciliation_fields: gate
            .required_reconciliation_fields
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
        ("upstream_owner_approved_first_token_probe_pass", upstream_pass),
        (
            "upstream_owner_approved_probe_ref_bound",
            gate.upstream_owner_approved_probe_ref
                == GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_UPSTREAM_REF,
        ),
        (
            "single_e2b_gguf_llama_cpp_reconciliation_lane_bound",
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
            "reconciliation_fields_and_rejection_policies_bound",
            metrics.required_reconciliation_field_count == 36
                && metrics.required_rejection_policy_count == 42
                && red_pass(&red_results, "missing_reconciliation_field")
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "digest_match_requirements_bound",
            gate.owner_approval_digest_required
                && gate.owner_manifest_digest_required
                && gate.canonical_path_digest_required
                && gate.model_file_digest_match_required
                && gate.model_file_size_match_required
                && gate.llama_cpp_binary_digest_match_required
                && gate.llama_cpp_version_digest_match_required
                && gate.command_template_digest_match_required
                && gate.resolved_argv_digest_match_required
                && gate.environment_allowlist_match_required
                && gate.synthetic_prompt_digest_match_required
                && red_pass(&red_results, "owner_approval_missing")
                && red_pass(&red_results, "owner_manifest_missing")
                && red_pass(&red_results, "canonical_path_missing")
                && red_pass(&red_results, "model_digest_mismatch")
                && red_pass(&red_results, "model_size_mismatch")
                && red_pass(&red_results, "llama_cpp_digest_mismatch")
                && red_pass(&red_results, "version_digest_mismatch")
                && red_pass(&red_results, "command_template_mismatch")
                && red_pass(&red_results, "argv_mismatch")
                && red_pass(&red_results, "env_mismatch")
                && red_pass(&red_results, "synthetic_prompt_mismatch"),
        ),
        (
            "token_memory_cancel_teardown_log_packet_bound",
            gate.first_token_digest_required
                && gate.first_token_redacted
                && !gate.first_token_quality_authority
                && gate.memory_samples_required
                && gate.timeout_bound
                && gate.cancellation_bound
                && gate.teardown_bound
                && gate.rollback_bound
                && gate.run_event_log_bound
                && gate.answer_packet_bound
                && gate.abstention_bound
                && red_pass(&red_results, "first_token_digest_missing")
                && red_pass(&red_results, "first_token_unredacted")
                && red_pass(&red_results, "first_token_quality_authority")
                && red_pass(&red_results, "memory_missing")
                && red_pass(&red_results, "timeout_missing")
                && red_pass(&red_results, "cancel_missing")
                && red_pass(&red_results, "teardown_missing")
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "runtime_artifact_review_deferred",
            metrics.future_runtime_artifact_present_count == 0
                && metrics.future_runtime_artifact_bytes_read == 0
                && metrics.accepted_runtime_artifact_count == 0
                && metrics.reconciliation_performed_count == 0
                && red_pass(&red_results, "future_artifact_present")
                && red_pass(&red_results, "artifact_bytes_read")
                && red_pass(&red_results, "accepted_artifact")
                && red_pass(&red_results, "reconciliation_performed"),
        ),
        (
            "zero_file_command_token_model_runtime_provider_actions",
            metrics.file_action_count == 0
                && metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.runtime_replay_performed_count == 0
                && metrics.first_token_observed_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "path_canonicalization_attempt")
                && red_pass(&red_results, "file_stat_attempt")
                && red_pass(&red_results, "file_hash_attempt")
                && red_pass(&red_results, "model_file_opened")
                && red_pass(&red_results, "llama_cpp_binary_opened")
                && red_pass(&red_results, "llama_cpp_version_executed")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "runtime_replay_performed")
                && red_pass(&red_results, "first_token_observed")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "privacy_raw_path_prompt_output_stdio_token_denied",
            metrics.captured_raw_path_bytes == 0
                && metrics.captured_raw_prompt_bytes == 0
                && metrics.captured_raw_output_bytes == 0
                && metrics.captured_stdout_bytes == 0
                && metrics.captured_stderr_bytes == 0
                && metrics.captured_raw_token_bytes == 0
                && red_pass(&red_results, "captured_raw_path")
                && red_pass(&red_results, "captured_raw_prompt")
                && red_pass(&red_results, "captured_raw_output")
                && red_pass(&red_results, "captured_stdout")
                && red_pass(&red_results, "captured_stderr")
                && red_pass(&red_results, "captured_raw_token"),
        ),
        (
            "no_route_or_system_g_mutation",
            !gate.runtime_router_mutation_allowed
                && !gate.system_g_mutation_allowed
                && red_pass(&red_results, "runtime_router_mutation")
                && red_pass(&red_results, "system_g_mutation"),
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
            "no_mas_l2_l3_t4_product_gemma_default_quality_or_70b_claim",
            metrics.promotion_claim_count == 0
                && red_pass(&red_results, "mas_l2_l3_t4_product_claim")
                && red_pass(&red_results, "product_route_green")
                && red_pass(&red_results, "gemma_default_claim")
                && red_pass(&red_results, "e4b_or_12b_bypass_allowed")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim")
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "benchmark_fit_claim"),
        ),
        (
            "gemma_e2b_first_token_reconciliation_address_deterministic",
            gate.reconciliation_gate_address(CREATED_AT_MS)
                == reversed.reconciliation_gate_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_NEXT_CURSOR
                == "gemma_qat_e2b_same_fixture_quality_replay_packet_gate",
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
            "required_reconciliation_field_count",
            metrics.required_reconciliation_field_count,
            "==",
            36,
            "fields",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            42,
            "policies",
        ),
        (
            "future_runtime_artifact_present_count",
            metrics.future_runtime_artifact_present_count,
            "==",
            0,
            "artifacts",
        ),
        (
            "future_runtime_artifact_bytes_read",
            metrics.future_runtime_artifact_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "accepted_runtime_artifact_count",
            metrics.accepted_runtime_artifact_count,
            "==",
            0,
            "artifacts",
        ),
        (
            "reconciliation_performed_count",
            metrics.reconciliation_performed_count,
            "==",
            0,
            "actions",
        ),
        (
            "file_action_count",
            metrics.file_action_count,
            "==",
            0,
            "actions",
        ),
        (
            "command_armed_count",
            metrics.command_armed_count,
            "==",
            0,
            "commands",
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
            "first_token_observed_count",
            metrics.first_token_observed_count,
            "==",
            0,
            "tokens",
        ),
        (
            "captured_raw_path_bytes",
            metrics.captured_raw_path_bytes,
            "==",
            0,
            "bytes",
        ),
        (
            "captured_raw_prompt_bytes",
            metrics.captured_raw_prompt_bytes,
            "==",
            0,
            "bytes",
        ),
        (
            "captured_raw_output_bytes",
            metrics.captured_raw_output_bytes,
            "==",
            0,
            "bytes",
        ),
        (
            "captured_stdout_bytes",
            metrics.captured_stdout_bytes,
            "==",
            0,
            "bytes",
        ),
        (
            "captured_stderr_bytes",
            metrics.captured_stderr_bytes,
            "==",
            0,
            "bytes",
        ),
        (
            "captured_raw_token_bytes",
            metrics.captured_raw_token_bytes,
            "==",
            0,
            "bytes",
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
            60,
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
        "gemma_e2b_first_token_reconciliation_gate_address",
        &gate.reconciliation_gate_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_NEXT_CURSOR,
        "gemma_qat_e2b_same_fixture_quality_replay_packet_gate",
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
        notes: "metadata-only F-GemmaQATE2BFirstTokenRuntimeArtifactReviewReconciliationGate: consumes the owner-approved E2B first-token probe and defines the fail-closed reconciliation contract for a future first-token artifact before quality replay or RuntimeRouter/System G admission. It requires exact owner approval, owner manifest, canonical path, model-file, llama.cpp binary/version, command, argv, environment, synthetic prompt, token, memory, timeout/cancel, teardown, rollback, RunEventLog, AnswerPacket, and abstention digests. It reads zero runtime artifact bytes, opens zero files, hashes zero local files, opens zero llama.cpp binaries, executes zero version checks, arms zero commands, executes zero commands, observes zero tokens, captures zero raw path/prompt/output/stdout/stderr/token bytes, loads zero model/runtime/provider bytes, and makes no MAS/L2/L3/T4/user-facing, Gemma-default, quality, benchmark-fit, E4B/12B bypass, live-70B, or SSD-as-RAM claim.".to_string(),
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
    gate: &GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGate,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaQatE2bFirstTokenRuntimeArtifactReviewReconciliationGate)>,
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
            "missing_reconciliation_field",
            Box::new(|g| {
                g.required_reconciliation_fields.pop();
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|g| {
                g.required_rejection_policies.pop();
            }),
        ),
        (
            "owner_approval_missing",
            Box::new(|g| g.owner_approval_digest_required = false),
        ),
        (
            "owner_manifest_missing",
            Box::new(|g| g.owner_manifest_digest_required = false),
        ),
        (
            "canonical_path_missing",
            Box::new(|g| g.canonical_path_digest_required = false),
        ),
        (
            "model_digest_mismatch",
            Box::new(|g| g.model_file_digest_match_required = false),
        ),
        (
            "model_size_mismatch",
            Box::new(|g| g.model_file_size_match_required = false),
        ),
        (
            "llama_cpp_digest_mismatch",
            Box::new(|g| g.llama_cpp_binary_digest_match_required = false),
        ),
        (
            "version_digest_mismatch",
            Box::new(|g| g.llama_cpp_version_digest_match_required = false),
        ),
        (
            "command_template_mismatch",
            Box::new(|g| g.command_template_digest_match_required = false),
        ),
        (
            "argv_mismatch",
            Box::new(|g| g.resolved_argv_digest_match_required = false),
        ),
        (
            "env_mismatch",
            Box::new(|g| g.environment_allowlist_match_required = false),
        ),
        (
            "synthetic_prompt_mismatch",
            Box::new(|g| g.synthetic_prompt_digest_match_required = false),
        ),
        (
            "first_token_digest_missing",
            Box::new(|g| g.first_token_digest_required = false),
        ),
        (
            "first_token_unredacted",
            Box::new(|g| g.first_token_redacted = false),
        ),
        (
            "first_token_quality_authority",
            Box::new(|g| g.first_token_quality_authority = true),
        ),
        (
            "memory_missing",
            Box::new(|g| g.memory_samples_required = false),
        ),
        ("timeout_missing", Box::new(|g| g.timeout_bound = false)),
        ("cancel_missing", Box::new(|g| g.cancellation_bound = false)),
        ("teardown_missing", Box::new(|g| g.teardown_bound = false)),
        ("rollback_missing", Box::new(|g| g.rollback_bound = false)),
        (
            "run_event_log_missing",
            Box::new(|g| g.run_event_log_bound = false),
        ),
        (
            "answer_packet_missing",
            Box::new(|g| g.answer_packet_bound = false),
        ),
        (
            "abstention_missing",
            Box::new(|g| g.abstention_bound = false),
        ),
        (
            "future_artifact_present",
            Box::new(|g| g.future_runtime_artifact_present = true),
        ),
        (
            "artifact_bytes_read",
            Box::new(|g| g.future_runtime_artifact_bytes_read = 1),
        ),
        (
            "accepted_artifact",
            Box::new(|g| g.accepted_runtime_artifact_count = 1),
        ),
        (
            "reconciliation_performed",
            Box::new(|g| g.reconciliation_performed_count = 1),
        ),
        (
            "path_canonicalization_attempt",
            Box::new(|g| g.path_canonicalization_attempts = 1),
        ),
        ("file_stat_attempt", Box::new(|g| g.file_stat_attempts = 1)),
        ("file_hash_attempt", Box::new(|g| g.file_hash_attempts = 1)),
        (
            "model_file_opened",
            Box::new(|g| g.model_file_opened = true),
        ),
        (
            "llama_cpp_binary_opened",
            Box::new(|g| g.llama_cpp_binary_opened = true),
        ),
        (
            "llama_cpp_version_executed",
            Box::new(|g| g.llama_cpp_version_executions = 1),
        ),
        ("command_armed", Box::new(|g| g.command_armed = true)),
        ("command_executed", Box::new(|g| g.command_executed = true)),
        (
            "runtime_replay_performed",
            Box::new(|g| g.runtime_replay_performed = true),
        ),
        (
            "first_token_observed",
            Box::new(|g| g.first_token_observed = true),
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
            "captured_raw_path",
            Box::new(|g| g.captured_raw_path_bytes = 1),
        ),
        (
            "captured_raw_prompt",
            Box::new(|g| g.captured_raw_prompt_bytes = 1),
        ),
        (
            "captured_raw_output",
            Box::new(|g| g.captured_raw_output_bytes = 1),
        ),
        ("captured_stdout", Box::new(|g| g.captured_stdout_bytes = 1)),
        ("captured_stderr", Box::new(|g| g.captured_stderr_bytes = 1)),
        (
            "captured_raw_token",
            Box::new(|g| g.captured_raw_token_bytes = 1),
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
            "e4b_or_12b_bypass_allowed",
            Box::new(|g| g.e4b_or_12b_bypass_allowed = true),
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
    for axis in GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_RECONCILIATION_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
