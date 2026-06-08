//! `falsify_gemma_qat_runtime_replay_execution_artifact_gate`
//!
//! Metadata-only parser gate for a future owner-approved Gemma E2B GGUF
//! one-token execution artifact. This does not run llama.cpp, open model paths,
//! capture tokens, retain raw prompt/output, or promote Gemma as the default.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_gemma_qat_runtime_replay_execution_manifest_fields,
    required_gemma_qat_runtime_replay_execution_rejection_policies,
    GemmaQatRuntimeReplayExecutionArtifactGate,
    GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_ID,
    GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR,
    GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_ID;
const FIXTURE_ID: &str = "gemma_qat_runtime_replay_execution_artifact_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_runtime_replay_execution_artifact_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_qat_runtime_replay_execution_artifact_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_owner_approved_runtime_replay_probe/result.json";
const CREATED_AT_MS: u64 = 1_779_388_000_000;

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
        "{FALSIFIER_ID}: overall_pass={} manifest_fields={} command_executed={} first_token_observed={} model_bytes_loaded={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_manifest_field_count"].value,
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
    let upstream_pass = upstream_probe_pass()?;
    let gate = GemmaQatRuntimeReplayExecutionArtifactGate::canonical(
        GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF,
    );
    gate.validate()?;
    let reversed = GemmaQatRuntimeReplayExecutionArtifactGate {
        required_execution_manifest_fields: gate
            .required_execution_manifest_fields
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
        ("upstream_gemma_runtime_replay_probe_pass", upstream_pass),
        (
            "upstream_probe_ref_bound",
            gate.upstream_probe_ref
                == GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF,
        ),
        (
            "single_e2b_gguf_execution_artifact_contract",
            gate.selected_model_id == "google/gemma-4-E2B-it-qat-q4_0-gguf"
                && gate.runtime_lane == agent_core::uas::GemmaFamilyRuntimeLane::GgufLlamaCpp
                && red_pass(&red_results, "wrong_model")
                && red_pass(&red_results, "wrong_runtime_lane"),
        ),
        (
            "artifact_root_and_manifest_name_bound",
            gate.artifact_root_prefix.starts_with(
                "artifacts/falsifiers/gemma_qat_runtime_replay_execution_artifact_gate/",
            ) && gate
                .future_manifest_name
                .contains("owner-approved-e2b-gguf-one-token-runtime-artifact")
                && red_pass(&red_results, "bad_artifact_root")
                && red_pass(&red_results, "bad_manifest_name"),
        ),
        (
            "required_execution_manifest_fields_bound",
            metrics.required_manifest_field_count
                == required_gemma_qat_runtime_replay_execution_manifest_fields().len() as u64
                && red_pass(&red_results, "missing_manifest_field"),
        ),
        (
            "required_rejection_policies_bound",
            metrics.required_rejection_policy_count
                == required_gemma_qat_runtime_replay_execution_rejection_policies().len() as u64
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "owner_approval_and_model_path_manifest_required",
            gate.owner_approval_required
                && !gate.owner_approval_granted
                && gate.owner_model_path_manifest_required
                && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "owner_manifest_missing"),
        ),
        (
            "raw_path_prompt_output_stdio_retention_denied",
            !gate.raw_model_path_retention_allowed
                && !gate.raw_prompt_retention_allowed
                && !gate.raw_output_retention_allowed
                && !gate.stdout_stderr_retention_allowed
                && red_pass(&red_results, "raw_model_path_retained")
                && red_pass(&red_results, "raw_prompt_retained")
                && red_pass(&red_results, "raw_output_retained")
                && red_pass(&red_results, "stdio_retained"),
        ),
        (
            "parser_dry_run_metadata_only",
            gate.parser_dry_run_only
                && gate.metadata_only
                && red_pass(&red_results, "parser_dry_run_disabled")
                && red_pass(&red_results, "metadata_only_disabled"),
        ),
        (
            "command_execution_runtime_replay_deferred",
            !gate.command_execution_allowed
                && !gate.command_executed
                && !gate.runtime_replay_performed
                && !gate.first_token_observed
                && red_pass(&red_results, "command_execution_allowed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "runtime_replay_performed")
                && red_pass(&red_results, "first_token_observed"),
        ),
        (
            "future_token_and_digest_proof_required",
            gate.future_first_token_digest_required
                && gate.model_file_digest_required
                && gate.command_digest_required
                && gate.llama_cpp_version_digest_required
                && red_pass(&red_results, "first_token_digest_not_required")
                && red_pass(&red_results, "model_digest_not_required")
                && red_pass(&red_results, "command_digest_not_required")
                && red_pass(&red_results, "llama_version_digest_not_required"),
        ),
        (
            "memory_samples_required",
            gate.memory_before_sample_required
                && gate.memory_runtime_start_sample_required
                && gate.memory_after_sample_required
                && red_pass(&red_results, "memory_before_missing")
                && red_pass(&red_results, "memory_start_missing")
                && red_pass(&red_results, "memory_after_missing"),
        ),
        (
            "cancellation_rollback_log_packet_abstention_bound",
            gate.cancellation_bound
                && gate.rollback_bound
                && gate.run_event_log_bound
                && gate.answer_packet_bound
                && gate.abstention_bound
                && red_pass(&red_results, "cancellation_missing")
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "zero_model_runtime_provider_command_token_bytes",
            metrics.command_executed_count == 0
                && metrics.runtime_replay_performed_count == 0
                && metrics.first_token_observed_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.captured_raw_prompt_bytes == 0
                && metrics.captured_raw_output_bytes == 0
                && red_pass(&red_results, "model_file_opened")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_call")
                && red_pass(&red_results, "raw_output_bytes"),
        ),
        (
            "no_runtime_router_or_system_g_mutation",
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
            !gate.larger_model_probe_allowed
                && red_pass(&red_results, "larger_model_probe_allowed"),
        ),
        (
            "execution_artifact_gate_address_deterministic",
            gate.gate_address(CREATED_AT_MS) == reversed.gate_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR
                == "gemma_qat_owner_approved_runtime_replay_execution_probe",
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
            "required_manifest_field_count",
            metrics.required_manifest_field_count,
            "==",
            23,
            "fields",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            20,
            "policies",
        ),
        (
            "owner_approval_granted_count",
            metrics.owner_approval_granted_count,
            "==",
            0,
            "claims",
        ),
        (
            "command_execution_allowed_count",
            metrics.command_execution_allowed_count,
            "==",
            0,
            "claims",
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
        "gemma_execution_artifact_gate_address",
        &gate.gate_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR,
        "gemma_qat_owner_approved_runtime_replay_execution_probe",
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
        notes: "metadata-only F-GemmaQATRuntimeReplayExecutionArtifactGate: consumes the Gemma E2B GGUF runtime replay probe envelope and binds the future execution artifact schema. It requires owner approval, owner path manifest digests, model/command/version digests, redacted prompt/output/first-token digests, memory before/start/after samples, cancellation, rollback, RunEventLog, AnswerPacket, abstention, and non-promotion. It opens zero files, executes zero commands, observes zero tokens, captures zero raw prompt/output/stdout/stderr bytes, loads zero model/runtime/provider bytes, and makes no MAS/L2/L3/user-facing, live Gemma default, quality, benchmark-fit, or live-70B claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_probe_pass() -> Result<bool, Box<dyn std::error::Error>> {
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
    gate: &GemmaQatRuntimeReplayExecutionArtifactGate,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaQatRuntimeReplayExecutionArtifactGate)>,
    )> = vec![
        (
            "wrong_model",
            Box::new(|g| g.selected_model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string()),
        ),
        (
            "wrong_runtime_lane",
            Box::new(|g| g.runtime_lane = agent_core::uas::GemmaFamilyRuntimeLane::LiteRtLm),
        ),
        (
            "bad_artifact_root",
            Box::new(|g| g.artifact_root_prefix = "/tmp/gemma/".to_string()),
        ),
        (
            "bad_manifest_name",
            Box::new(|g| g.future_manifest_name = "runtime.json".to_string()),
        ),
        (
            "missing_manifest_field",
            Box::new(|g| {
                g.required_execution_manifest_fields.pop();
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|g| {
                g.required_rejection_policies.pop();
            }),
        ),
        (
            "owner_approval_granted",
            Box::new(|g| g.owner_approval_granted = true),
        ),
        (
            "owner_manifest_missing",
            Box::new(|g| g.owner_model_path_manifest_required = false),
        ),
        (
            "raw_model_path_retained",
            Box::new(|g| g.raw_model_path_retention_allowed = true),
        ),
        (
            "raw_prompt_retained",
            Box::new(|g| g.raw_prompt_retention_allowed = true),
        ),
        (
            "raw_output_retained",
            Box::new(|g| g.raw_output_retention_allowed = true),
        ),
        (
            "stdio_retained",
            Box::new(|g| g.stdout_stderr_retention_allowed = true),
        ),
        (
            "parser_dry_run_disabled",
            Box::new(|g| g.parser_dry_run_only = false),
        ),
        (
            "metadata_only_disabled",
            Box::new(|g| g.metadata_only = false),
        ),
        (
            "command_execution_allowed",
            Box::new(|g| g.command_execution_allowed = true),
        ),
        ("command_executed", Box::new(|g| g.command_executed = true)),
        (
            "runtime_replay_performed",
            Box::new(|g| g.runtime_replay_performed = true),
        ),
        (
            "first_token_observed",
            Box::new(|g| g.first_token_observed = true),
        ),
        (
            "first_token_digest_not_required",
            Box::new(|g| g.future_first_token_digest_required = false),
        ),
        (
            "model_digest_not_required",
            Box::new(|g| g.model_file_digest_required = false),
        ),
        (
            "command_digest_not_required",
            Box::new(|g| g.command_digest_required = false),
        ),
        (
            "llama_version_digest_not_required",
            Box::new(|g| g.llama_cpp_version_digest_required = false),
        ),
        (
            "memory_before_missing",
            Box::new(|g| g.memory_before_sample_required = false),
        ),
        (
            "memory_start_missing",
            Box::new(|g| g.memory_runtime_start_sample_required = false),
        ),
        (
            "memory_after_missing",
            Box::new(|g| g.memory_after_sample_required = false),
        ),
        (
            "cancellation_missing",
            Box::new(|g| g.cancellation_bound = false),
        ),
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
            "model_file_opened",
            Box::new(|g| {
                g.model_file_opened = true;
                g.opened_model_file_bytes = 1;
            }),
        ),
        ("model_bytes_loaded", Box::new(|g| g.model_bytes_loaded = 1)),
        (
            "runtime_bytes_loaded",
            Box::new(|g| g.runtime_bytes_loaded = 1),
        ),
        ("provider_call", Box::new(|g| g.provider_calls_made = 1)),
        (
            "raw_output_bytes",
            Box::new(|g| g.captured_raw_output_bytes = 1),
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
            "mas_l2_l3_product_claim",
            Box::new(|g| {
                g.mas_promoted = true;
                g.l2_capability_effect = true;
                g.l3_wrv_effect = true;
            }),
        ),
        (
            "live_gemma_default_claim",
            Box::new(|g| g.live_gemma_default_claim = true),
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
            "larger_model_probe_allowed",
            Box::new(|g| g.larger_model_probe_allowed = true),
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
    for axis in GEMMA_QAT_RUNTIME_REPLAY_EXECUTION_ARTIFACT_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
