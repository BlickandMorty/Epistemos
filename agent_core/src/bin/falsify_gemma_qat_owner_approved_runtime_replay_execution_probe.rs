//! `falsify_gemma_qat_owner_approved_runtime_replay_execution_probe`
//!
//! Metadata-only execution-probe envelope for the first future owner-approved
//! Gemma E2B GGUF one-token replay. This does not run llama.cpp, open model
//! paths, observe tokens, retain raw prompt/output, or promote Gemma.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_gemma_qat_owner_approved_runtime_replay_abort_conditions,
    required_gemma_qat_owner_approved_runtime_replay_execution_proof_fields,
    GemmaQatOwnerApprovedRuntimeReplayExecutionProbe,
    GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_ID,
    GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_NEXT_CURSOR,
    GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_ID;
const FIXTURE_ID: &str = "gemma_qat_owner_approved_runtime_replay_execution_probe_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_gemma_qat_owner_approved_runtime_replay_execution_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_qat_owner_approved_runtime_replay_execution_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_runtime_replay_execution_artifact_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_388_500_000;

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
        "{FALSIFIER_ID}: overall_pass={} proof_fields={} command_armed={} command_executed={} first_token_observed={} model_bytes_loaded={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_execution_proof_field_count"].value,
        artifact.measurements["command_armed_count"].value,
        artifact.measurements["command_executed_count"].value,
        artifact.measurements["first_token_observed_count"].value,
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
    let probe = GemmaQatOwnerApprovedRuntimeReplayExecutionProbe::canonical(
        GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
    );
    probe.validate()?;
    let reversed = GemmaQatOwnerApprovedRuntimeReplayExecutionProbe {
        required_execution_proof_fields: probe
            .required_execution_proof_fields
            .iter()
            .cloned()
            .rev()
            .collect(),
        required_abort_conditions: probe
            .required_abort_conditions
            .iter()
            .cloned()
            .rev()
            .collect(),
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
        ("upstream_gemma_execution_artifact_gate_pass", upstream_pass),
        (
            "upstream_execution_artifact_gate_ref_bound",
            probe.upstream_execution_artifact_gate_ref
                == GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_UPSTREAM_REF,
        ),
        (
            "single_e2b_gguf_execution_probe_bound",
            probe.selected_model_id == "google/gemma-4-E2B-it-qat-q4_0-gguf"
                && probe.runtime_lane == agent_core::uas::GemmaFamilyRuntimeLane::GgufLlamaCpp
                && red_pass(&red_results, "wrong_model")
                && red_pass(&red_results, "wrong_runtime_lane"),
        ),
        (
            "proof_fields_and_abort_conditions_bound",
            metrics.required_execution_proof_field_count
                == required_gemma_qat_owner_approved_runtime_replay_execution_proof_fields().len()
                    as u64
                && metrics.required_abort_condition_count
                    == required_gemma_qat_owner_approved_runtime_replay_abort_conditions().len()
                        as u64
                && red_pass(&red_results, "missing_proof_field")
                && red_pass(&red_results, "missing_abort_condition"),
        ),
        (
            "owner_approval_pending_and_path_manifest_required",
            probe.owner_approval_required
                && !probe.owner_approval_granted
                && probe.owner_model_path_manifest_required
                && probe.canonical_path_digest_required
                && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "owner_manifest_missing")
                && red_pass(&red_results, "canonical_path_digest_missing"),
        ),
        (
            "privacy_raw_path_prompt_output_stdio_denied",
            !probe.raw_path_retention_allowed
                && !probe.raw_prompt_retention_allowed
                && !probe.raw_output_retention_allowed
                && !probe.stdout_stderr_retention_allowed
                && red_pass(&red_results, "raw_path_retained")
                && red_pass(&red_results, "raw_prompt_retained")
                && red_pass(&red_results, "raw_output_retained")
                && red_pass(&red_results, "stdio_retained"),
        ),
        (
            "command_visible_but_unarmed",
            probe.command_template_visible
                && !probe.command_armed
                && !probe.command_executed
                && red_pass(&red_results, "command_template_hidden")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed"),
        ),
        (
            "runtime_replay_and_first_token_deferred",
            !probe.runtime_replay_performed
                && !probe.first_token_observed
                && !probe.model_file_opened
                && red_pass(&red_results, "runtime_replay_performed")
                && red_pass(&red_results, "first_token_observed")
                && red_pass(&red_results, "model_file_opened"),
        ),
        (
            "digest_version_and_memory_samples_required",
            probe.first_token_digest_required_after_success
                && probe.model_digest_required
                && probe.llama_cpp_binary_digest_required
                && probe.llama_cpp_version_digest_required
                && probe.memory_before_required
                && probe.memory_start_required
                && probe.memory_first_token_required
                && probe.memory_after_required
                && red_pass(&red_results, "first_token_digest_not_required")
                && red_pass(&red_results, "model_digest_not_required")
                && red_pass(&red_results, "llama_binary_digest_not_required")
                && red_pass(&red_results, "llama_version_digest_not_required")
                && red_pass(&red_results, "memory_sample_missing"),
        ),
        (
            "offline_no_server_download_or_mmap_stress",
            !probe.network_access_allowed
                && !probe.server_mode_allowed
                && !probe.download_allowed
                && !probe.mmap_or_prefill_stress_allowed
                && !probe.provider_calls_allowed
                && red_pass(&red_results, "network_allowed")
                && red_pass(&red_results, "server_mode_allowed")
                && red_pass(&red_results, "download_allowed")
                && red_pass(&red_results, "mmap_stress_allowed")
                && red_pass(&red_results, "provider_calls_allowed"),
        ),
        (
            "cancellation_rollback_log_packet_abstention_bound",
            probe.timeout_bound
                && probe.cancellation_bound
                && probe.rollback_bound
                && probe.run_event_log_bound
                && probe.answer_packet_bound
                && probe.abstention_bound
                && red_pass(&red_results, "timeout_missing")
                && red_pass(&red_results, "cancellation_missing")
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "zero_model_runtime_provider_command_token_bytes",
            metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.runtime_replay_performed_count == 0
                && metrics.first_token_observed_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.captured_raw_prompt_bytes == 0
                && metrics.captured_raw_output_bytes == 0
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_call")
                && red_pass(&red_results, "raw_output_bytes"),
        ),
        (
            "no_runtime_router_or_system_g_mutation",
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
            "no_mas_l2_l3_product_gemma_default_or_70b_claim",
            metrics.promotion_claim_count == 0
                && red_pass(&red_results, "mas_l2_l3_product_claim")
                && red_pass(&red_results, "live_gemma_default_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim")
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "benchmark_fit_claim"),
        ),
        (
            "larger_models_blocked_until_repreflight",
            !probe.larger_model_probe_allowed
                && red_pass(&red_results, "larger_model_probe_allowed"),
        ),
        (
            "runtime_replay_execution_probe_address_deterministic",
            probe.probe_address(CREATED_AT_MS) == reversed.probe_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_NEXT_CURSOR
                == "gemma_qat_e2b_first_token_runtime_artifact_review_gate",
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
            "required_execution_proof_field_count",
            metrics.required_execution_proof_field_count,
            "==",
            27,
            "fields",
        ),
        (
            "required_abort_condition_count",
            metrics.required_abort_condition_count,
            "==",
            24,
            "conditions",
        ),
        (
            "owner_approval_granted_count",
            metrics.owner_approval_granted_count,
            "==",
            0,
            "claims",
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
            "runs",
        ),
        (
            "first_token_observed_count",
            metrics.first_token_observed_count,
            "==",
            0,
            "tokens",
        ),
        (
            "opened_model_file_bytes",
            metrics.opened_model_file_bytes,
            "==",
            0,
            "bytes",
        ),
        (
            "opened_runtime_file_bytes",
            metrics.opened_runtime_file_bytes,
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
            "forbidden_route_count",
            metrics.forbidden_route_count,
            "==",
            0,
            "routes",
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
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            ">=",
            35,
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
        "gemma_runtime_replay_execution_probe_address",
        &probe.probe_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_NEXT_CURSOR,
        "gemma_qat_e2b_first_token_runtime_artifact_review_gate",
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
        notes: "metadata-only F-GemmaQATOwnerApprovedRuntimeReplayExecutionProbe: consumes the execution artifact gate and binds the future owner-approved E2B GGUF one-token execution proof envelope. It requires owner approval, owner path manifest, canonical path/model/llama.cpp/command digests, redacted prompt/output/first-token digests, memory samples, timeout/cancellation, rollback, RunEventLog, AnswerPacket, abstention, and non-promotion. It arms zero commands, opens zero files, observes zero tokens, captures zero raw prompt/output/stdout/stderr bytes, loads zero model/runtime/provider bytes, and makes no MAS/L2/L3/user-facing, live Gemma default, quality, benchmark-fit, or live-70B claim.".to_string(),
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
        .and_then(|v| v.as_bool())
        .unwrap_or(false))
}

fn red_fixture_results(
    probe: &GemmaQatOwnerApprovedRuntimeReplayExecutionProbe,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaQatOwnerApprovedRuntimeReplayExecutionProbe)>,
    )> = vec![
        (
            "wrong_model",
            Box::new(|p| p.selected_model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string()),
        ),
        (
            "wrong_runtime_lane",
            Box::new(|p| p.runtime_lane = agent_core::uas::GemmaFamilyRuntimeLane::LiteRtLm),
        ),
        (
            "missing_proof_field",
            Box::new(|p| {
                p.required_execution_proof_fields.pop();
            }),
        ),
        (
            "missing_abort_condition",
            Box::new(|p| {
                p.required_abort_conditions.pop();
            }),
        ),
        (
            "owner_approval_granted",
            Box::new(|p| p.owner_approval_granted = true),
        ),
        (
            "owner_manifest_missing",
            Box::new(|p| p.owner_model_path_manifest_required = false),
        ),
        (
            "canonical_path_digest_missing",
            Box::new(|p| p.canonical_path_digest_required = false),
        ),
        (
            "raw_path_retained",
            Box::new(|p| p.raw_path_retention_allowed = true),
        ),
        (
            "raw_prompt_retained",
            Box::new(|p| p.raw_prompt_retention_allowed = true),
        ),
        (
            "raw_output_retained",
            Box::new(|p| p.raw_output_retention_allowed = true),
        ),
        (
            "stdio_retained",
            Box::new(|p| p.stdout_stderr_retention_allowed = true),
        ),
        (
            "command_template_hidden",
            Box::new(|p| p.command_template_visible = false),
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
            "model_file_opened",
            Box::new(|p| {
                p.model_file_opened = true;
                p.opened_model_file_bytes = 1;
            }),
        ),
        (
            "first_token_digest_not_required",
            Box::new(|p| p.first_token_digest_required_after_success = false),
        ),
        (
            "model_digest_not_required",
            Box::new(|p| p.model_digest_required = false),
        ),
        (
            "llama_binary_digest_not_required",
            Box::new(|p| p.llama_cpp_binary_digest_required = false),
        ),
        (
            "llama_version_digest_not_required",
            Box::new(|p| p.llama_cpp_version_digest_required = false),
        ),
        (
            "memory_sample_missing",
            Box::new(|p| p.memory_first_token_required = false),
        ),
        (
            "network_allowed",
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
            "provider_calls_allowed",
            Box::new(|p| p.provider_calls_allowed = true),
        ),
        ("timeout_missing", Box::new(|p| p.timeout_bound = false)),
        (
            "cancellation_missing",
            Box::new(|p| p.cancellation_bound = false),
        ),
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
        ("model_bytes_loaded", Box::new(|p| p.model_bytes_loaded = 1)),
        (
            "runtime_bytes_loaded",
            Box::new(|p| p.runtime_bytes_loaded = 1),
        ),
        ("provider_call", Box::new(|p| p.provider_calls_made = 1)),
        (
            "raw_output_bytes",
            Box::new(|p| p.captured_raw_output_bytes = 1),
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
            "live_gemma_default_claim",
            Box::new(|p| p.live_gemma_default_claim = true),
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
        (
            "larger_model_probe_allowed",
            Box::new(|p| p.larger_model_probe_allowed = true),
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
    for axis in GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_EXECUTION_PROBE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
