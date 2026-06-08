//! `falsify_gemma_qat_e2b_owner_approved_first_token_runtime_probe`
//!
//! Metadata-only contract for the future owner-approved Gemma E2B
//! GGUF/llama.cpp one-token probe. It does not open files, arm commands, run
//! inference, observe a token, or promote Gemma into System G.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbe, GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
    GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_ID,
    GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_NEXT_CURSOR,
    GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_UPSTREAM_REF,
    GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH,
};

const FALSIFIER_ID: &str = GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_ID;
const FIXTURE_ID: &str = "gemma_qat_e2b_owner_approved_first_token_runtime_probe_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_gemma_qat_e2b_owner_approved_first_token_runtime_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_owner_approved_first_token_runtime_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_model_file_and_llama_cpp_digest_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_401_000_000;

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
        "{FALSIFIER_ID}: overall_pass={} probe_fields={} owner_approval_granted={} command_executed={} first_token_observed={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_probe_field_count"].value,
        artifact.measurements["owner_approval_granted_count"].value,
        artifact.measurements["command_executed_count"].value,
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
    let probe = GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbe::canonical(
        GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_UPSTREAM_REF,
    );
    probe.validate()?;
    let reversed = GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbe {
        required_probe_fields: probe.required_probe_fields.iter().cloned().rev().collect(),
        required_abort_conditions: probe
            .required_abort_conditions
            .iter()
            .cloned()
            .rev()
            .collect(),
        required_command_args: probe.required_command_args.iter().cloned().rev().collect(),
        forbidden_command_args: probe.forbidden_command_args.iter().cloned().rev().collect(),
        ..probe.clone()
    };
    reversed.validate()?;

    let metrics = probe.metrics();
    let red_results = red_fixture_results(&probe);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        (
            "upstream_model_file_llama_cpp_digest_gate_pass",
            upstream_pass,
        ),
        (
            "upstream_model_file_llama_cpp_digest_ref_bound",
            probe.upstream_model_file_digest_gate_ref
                == GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_UPSTREAM_REF,
        ),
        (
            "single_e2b_gguf_llama_cpp_probe_lane_bound",
            probe.selected_model_id == "google/gemma-4-E2B-it-qat-q4_0-gguf"
                && probe.required_filename == "gemma-4-E2B_q4_0-it.gguf"
                && probe.expected_file_size_bytes == GEMMA_QAT_E2B_EXPECTED_FILE_BYTES
                && probe.command_path == GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH
                && red_pass(&red_results, "wrong_model")
                && red_pass(&red_results, "wrong_filename")
                && red_pass(&red_results, "wrong_expected_file_bytes")
                && red_pass(&red_results, "wrong_source_revision")
                && red_pass(&red_results, "wrong_runtime_lane"),
        ),
        (
            "owner_approval_required_but_pending",
            probe.owner_approval_required
                && !probe.owner_approval_granted
                && red_pass(&red_results, "owner_approval_not_required")
                && red_pass(&red_results, "owner_approval_granted"),
        ),
        (
            "model_llama_command_digest_requirements_bound",
            probe.owner_manifest_digest_bound
                && probe.canonical_path_digest_bound
                && probe.model_file_digest_bound
                && probe.model_file_size_bound
                && probe.llama_cpp_binary_digest_bound
                && probe.llama_cpp_version_digest_bound
                && probe.command_template_digest_bound
                && probe.command_template_visible
                && probe.offline_mode_required
                && red_pass(&red_results, "owner_manifest_digest_missing")
                && red_pass(&red_results, "canonical_path_digest_missing")
                && red_pass(&red_results, "model_digest_missing")
                && red_pass(&red_results, "model_size_unbound")
                && red_pass(&red_results, "llama_cpp_digest_missing")
                && red_pass(&red_results, "version_digest_missing")
                && red_pass(&red_results, "command_template_digest_missing")
                && red_pass(&red_results, "command_template_hidden")
                && red_pass(&red_results, "offline_not_required"),
        ),
        (
            "required_probe_fields_abort_conditions_and_args_bound",
            metrics.required_probe_field_count == 29
                && metrics.required_abort_condition_count == 27
                && metrics.required_command_arg_count == 14
                && metrics.forbidden_command_arg_count == 11
                && red_pass(&red_results, "missing_probe_field")
                && red_pass(&red_results, "missing_abort_condition")
                && red_pass(&red_results, "missing_required_arg")
                && red_pass(&red_results, "missing_forbidden_arg"),
        ),
        (
            "privacy_raw_path_prompt_output_stdio_denied",
            !probe.raw_path_retention_allowed
                && !probe.raw_prompt_retention_allowed
                && !probe.raw_output_retention_allowed
                && !probe.stdout_stderr_retention_allowed
                && metrics.captured_raw_path_bytes == 0
                && metrics.captured_raw_prompt_bytes == 0
                && metrics.captured_raw_output_bytes == 0
                && metrics.captured_stdout_bytes == 0
                && metrics.captured_stderr_bytes == 0
                && red_pass(&red_results, "raw_path_allowed")
                && red_pass(&red_results, "raw_prompt_allowed")
                && red_pass(&red_results, "raw_output_allowed")
                && red_pass(&red_results, "stdio_allowed")
                && red_pass(&red_results, "captured_raw_path")
                && red_pass(&red_results, "captured_raw_prompt")
                && red_pass(&red_results, "captured_raw_output")
                && red_pass(&red_results, "captured_stdout")
                && red_pass(&red_results, "captured_stderr"),
        ),
        (
            "memory_timeout_cancel_teardown_log_packet_bound",
            probe.memory_before_required
                && probe.memory_load_start_required
                && probe.memory_first_token_required
                && probe.memory_teardown_required
                && probe.timeout_bound
                && probe.cancellation_bound
                && probe.teardown_bound
                && probe.rollback_bound
                && probe.run_event_log_bound
                && probe.answer_packet_bound
                && probe.abstention_bound
                && red_pass(&red_results, "memory_before_missing")
                && red_pass(&red_results, "memory_load_missing")
                && red_pass(&red_results, "memory_token_missing")
                && red_pass(&red_results, "memory_teardown_missing")
                && red_pass(&red_results, "timeout_missing")
                && red_pass(&red_results, "cancel_missing")
                && red_pass(&red_results, "teardown_missing")
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing"),
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
            "forbidden_network_server_download_mmap_provider_surfaces_zero",
            metrics.forbidden_runtime_surface_count == 0
                && red_pass(&red_results, "network_access_allowed")
                && red_pass(&red_results, "server_mode_allowed")
                && red_pass(&red_results, "download_allowed")
                && red_pass(&red_results, "mmap_stress_allowed")
                && red_pass(&red_results, "provider_route_enabled"),
        ),
        (
            "no_route_or_system_g_mutation",
            !probe.runtime_router_mutation_allowed
                && !probe.system_g_mutation_allowed
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
            "no_mas_l2_l3_product_gemma_default_quality_or_70b_claim",
            metrics.promotion_claim_count == 0
                && red_pass(&red_results, "mas_l2_l3_product_claim")
                && red_pass(&red_results, "product_route_green")
                && red_pass(&red_results, "gemma_default_claim")
                && red_pass(&red_results, "e4b_or_12b_bypass_allowed")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim")
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "benchmark_fit_claim"),
        ),
        (
            "gemma_e2b_owner_approved_first_token_probe_address_deterministic",
            probe.probe_gate_address(CREATED_AT_MS) == reversed.probe_gate_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_NEXT_CURSOR
                == "gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate",
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
            "required_probe_field_count",
            metrics.required_probe_field_count,
            "==",
            29,
            "fields",
        ),
        (
            "required_abort_condition_count",
            metrics.required_abort_condition_count,
            "==",
            27,
            "conditions",
        ),
        (
            "required_command_arg_count",
            metrics.required_command_arg_count,
            "==",
            14,
            "args",
        ),
        (
            "forbidden_command_arg_count",
            metrics.forbidden_command_arg_count,
            "==",
            11,
            "args",
        ),
        (
            "owner_approval_granted_count",
            metrics.owner_approval_granted_count,
            "==",
            0,
            "claims",
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
            "forbidden_runtime_surface_count",
            metrics.forbidden_runtime_surface_count,
            "==",
            0,
            "surfaces",
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
            probe.expected_file_size_bytes,
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
        "gemma_e2b_owner_approved_first_token_probe_address",
        &probe.probe_gate_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_NEXT_CURSOR,
        "gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate",
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
        notes: "metadata-only F-GemmaQATE2BOwnerApprovedFirstTokenRuntimeProbe: consumes the E2B model-file and llama.cpp digest gate and defines the fail-closed contract for a future owner-approved one-token Gemma E2B GGUF/llama.cpp probe. It requires owner approval, owner manifest digest, canonical path digest, model-file sha256, llama.cpp binary sha256, llama.cpp version digest, visible offline command template, synthetic prompt digest, memory before/load/first-token/teardown samples, timeout/cancel, teardown, rollback, RunEventLog, AnswerPacket, and abstention before a run can proceed. It opens zero files, hashes zero local files, opens zero llama.cpp binaries, executes zero version checks, arms zero commands, executes zero commands, observes zero tokens, captures zero raw path/prompt/output/stdout/stderr bytes, loads zero model/runtime/provider bytes, rejects network/server/download/mmap/provider shortcuts, and makes no MAS/L2/L3/T4/user-facing, Gemma-default, quality, benchmark-fit, E4B/12B bypass, live-70B, or SSD-as-RAM claim.".to_string(),
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
    probe: &GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbe,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaQatE2bOwnerApprovedFirstTokenRuntimeProbe)>,
    )> = vec![
        (
            "wrong_model",
            Box::new(|p| p.selected_model_id = "google/gemma-4-E4B-it-qat-q4_0-gguf".to_string()),
        ),
        (
            "wrong_filename",
            Box::new(|p| p.required_filename = "gemma-4-E4B_q4_0-it.gguf".to_string()),
        ),
        (
            "wrong_expected_file_bytes",
            Box::new(|p| p.expected_file_size_bytes += 1),
        ),
        (
            "wrong_source_revision",
            Box::new(|p| p.source_revision = "main".to_string()),
        ),
        (
            "wrong_runtime_lane",
            Box::new(|p| p.runtime_lane = agent_core::uas::GemmaFamilyRuntimeLane::LiteRtLm),
        ),
        (
            "owner_approval_not_required",
            Box::new(|p| p.owner_approval_required = false),
        ),
        (
            "owner_approval_granted",
            Box::new(|p| p.owner_approval_granted = true),
        ),
        (
            "owner_manifest_digest_missing",
            Box::new(|p| p.owner_manifest_digest_bound = false),
        ),
        (
            "canonical_path_digest_missing",
            Box::new(|p| p.canonical_path_digest_bound = false),
        ),
        (
            "model_digest_missing",
            Box::new(|p| p.model_file_digest_bound = false),
        ),
        (
            "model_size_unbound",
            Box::new(|p| p.model_file_size_bound = false),
        ),
        (
            "llama_cpp_digest_missing",
            Box::new(|p| p.llama_cpp_binary_digest_bound = false),
        ),
        (
            "version_digest_missing",
            Box::new(|p| p.llama_cpp_version_digest_bound = false),
        ),
        (
            "command_template_digest_missing",
            Box::new(|p| p.command_template_digest_bound = false),
        ),
        (
            "command_template_hidden",
            Box::new(|p| p.command_template_visible = false),
        ),
        (
            "offline_not_required",
            Box::new(|p| p.offline_mode_required = false),
        ),
        (
            "synthetic_prompt_missing",
            Box::new(|p| p.synthetic_prompt_required = false),
        ),
        (
            "missing_probe_field",
            Box::new(|p| {
                p.required_probe_fields.pop();
            }),
        ),
        (
            "missing_abort_condition",
            Box::new(|p| {
                p.required_abort_conditions.pop();
            }),
        ),
        (
            "missing_required_arg",
            Box::new(|p| {
                p.required_command_args.pop();
            }),
        ),
        (
            "missing_forbidden_arg",
            Box::new(|p| {
                p.forbidden_command_args.pop();
            }),
        ),
        (
            "raw_path_allowed",
            Box::new(|p| p.raw_path_retention_allowed = true),
        ),
        (
            "raw_prompt_allowed",
            Box::new(|p| p.raw_prompt_retention_allowed = true),
        ),
        (
            "raw_output_allowed",
            Box::new(|p| p.raw_output_retention_allowed = true),
        ),
        (
            "stdio_allowed",
            Box::new(|p| p.stdout_stderr_retention_allowed = true),
        ),
        (
            "captured_raw_path",
            Box::new(|p| p.captured_raw_path_bytes = 1),
        ),
        (
            "captured_raw_prompt",
            Box::new(|p| p.captured_raw_prompt_bytes = 1),
        ),
        (
            "captured_raw_output",
            Box::new(|p| p.captured_raw_output_bytes = 1),
        ),
        ("captured_stdout", Box::new(|p| p.captured_stdout_bytes = 1)),
        ("captured_stderr", Box::new(|p| p.captured_stderr_bytes = 1)),
        (
            "memory_before_missing",
            Box::new(|p| p.memory_before_required = false),
        ),
        (
            "memory_load_missing",
            Box::new(|p| p.memory_load_start_required = false),
        ),
        (
            "memory_token_missing",
            Box::new(|p| p.memory_first_token_required = false),
        ),
        (
            "memory_teardown_missing",
            Box::new(|p| p.memory_teardown_required = false),
        ),
        ("timeout_missing", Box::new(|p| p.timeout_bound = false)),
        ("cancel_missing", Box::new(|p| p.cancellation_bound = false)),
        ("teardown_missing", Box::new(|p| p.teardown_bound = false)),
        ("rollback_missing", Box::new(|p| p.rollback_bound = false)),
        (
            "run_event_log_missing",
            Box::new(|p| p.run_event_log_bound = false),
        ),
        (
            "answer_packet_missing",
            Box::new(|p| p.answer_packet_bound = false),
        ),
        (
            "abstention_missing",
            Box::new(|p| p.abstention_bound = false),
        ),
        (
            "path_canonicalization_attempt",
            Box::new(|p| p.path_canonicalization_attempts = 1),
        ),
        ("file_stat_attempt", Box::new(|p| p.file_stat_attempts = 1)),
        ("file_hash_attempt", Box::new(|p| p.file_hash_attempts = 1)),
        (
            "model_file_opened",
            Box::new(|p| p.model_file_opened = true),
        ),
        (
            "llama_cpp_binary_opened",
            Box::new(|p| p.llama_cpp_binary_opened = true),
        ),
        (
            "llama_cpp_version_executed",
            Box::new(|p| p.llama_cpp_version_executions = 1),
        ),
        ("command_armed", Box::new(|p| p.command_armed = true)),
        ("command_executed", Box::new(|p| p.command_executed = true)),
        (
            "runtime_replay_performed",
            Box::new(|p| p.runtime_replay_performed = true),
        ),
        (
            "first_token_observed",
            Box::new(|p| p.first_token_observed = true),
        ),
        (
            "network_access_allowed",
            Box::new(|p| p.network_access_allowed = true),
        ),
        (
            "server_mode_allowed",
            Box::new(|p| p.server_mode_allowed = true),
        ),
        ("download_allowed", Box::new(|p| p.download_allowed = true)),
        (
            "mmap_stress_allowed",
            Box::new(|p| p.mmap_or_prefill_stress_allowed = true),
        ),
        (
            "provider_route_enabled",
            Box::new(|p| p.provider_route_enabled = true),
        ),
        ("model_bytes_loaded", Box::new(|p| p.model_bytes_loaded = 1)),
        (
            "runtime_bytes_loaded",
            Box::new(|p| p.runtime_bytes_loaded = 1),
        ),
        (
            "provider_calls_made",
            Box::new(|p| p.provider_calls_made = 1),
        ),
        (
            "runtime_router_mutation",
            Box::new(|p| p.runtime_router_mutation_allowed = true),
        ),
        (
            "system_g_mutation",
            Box::new(|p| p.system_g_mutation_allowed = true),
        ),
        (
            "hidden_route_authority",
            Box::new(|p| p.hidden_route_authority = true),
        ),
        (
            "hidden_eidos_authority",
            Box::new(|p| p.hidden_eidos_authority = true),
        ),
        (
            "hidden_lattice_authority",
            Box::new(|p| p.hidden_lattice_authority = true),
        ),
        (
            "hidden_patternboost_authority",
            Box::new(|p| p.hidden_patternboost_authority = true),
        ),
        (
            "hidden_cloud_fallback",
            Box::new(|p| p.hidden_cloud_fallback = true),
        ),
        (
            "mas_l2_l3_product_claim",
            Box::new(|p| {
                p.mas_promoted = true;
                p.l2_capability_effect = true;
                p.l3_wrv_effect = true;
            }),
        ),
        (
            "product_route_green",
            Box::new(|p| p.product_route_green = true),
        ),
        (
            "gemma_default_claim",
            Box::new(|p| p.live_gemma_default_claim = true),
        ),
        (
            "e4b_or_12b_bypass_allowed",
            Box::new(|p| p.e4b_or_12b_bypass_allowed = true),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|p| p.live_dense_70b_claim = true),
        ),
        ("ssd_as_ram_claim", Box::new(|p| p.ssd_as_ram_claim = true)),
        ("quality_claim", Box::new(|p| p.quality_claimed = true)),
        (
            "benchmark_fit_claim",
            Box::new(|p| p.benchmark_claimed_as_fit = true),
        ),
    ];
    cases
        .into_iter()
        .map(|(name, mutate)| {
            let mut mutated = probe.clone();
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
    for axis in GEMMA_QAT_E2B_OWNER_APPROVED_FIRST_TOKEN_RUNTIME_PROBE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
