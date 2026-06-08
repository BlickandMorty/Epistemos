//! `falsify_gemma_qat_owner_approved_runtime_replay_probe`
//!
//! Metadata-only witness for `F-GemmaQATOwnerApprovedRuntimeReplayProbe`. It
//! consumes the Gemma runtime transcript gate and binds the smallest E2B
//! GGUF/llama.cpp replay probe envelope without opening model paths, arming a
//! command, capturing tokens, or promoting Gemma as the product default.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_gemma_qat_owner_approved_runtime_replay_probe_cards,
    GemmaQatOwnerApprovedRuntimeReplayProbeCard, GemmaQatOwnerApprovedRuntimeReplayProbeLedger,
    GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_ID,
    GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_NEXT_CURSOR,
    GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID,
};

const FALSIFIER_ID: &str = GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_ID;
const FIXTURE_ID: &str = "gemma_qat_owner_approved_runtime_replay_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_owner_approved_runtime_replay_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_qat_owner_approved_runtime_replay_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_owner_approved_runtime_replay_transcript_gate/result.json";
const UPSTREAM_REF: &str = "artifact:falsifiers/gemma_qat_owner_approved_runtime_replay_transcript_gate/result.json#F-GemmaQATOwnerApprovedRuntimeReplayTranscriptGate";
const CREATED_AT_MS: u64 = 1_779_301_600_000;
const LEDGER_METADATA_BYTES: u64 = 96_000;

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
        "{FALSIFIER_ID}: overall_pass={} probe_count={} owner_approval_granted={} command_executed={} first_token_observed={} model_bytes_loaded_total={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["runtime_replay_probe_count"].value,
        artifact.measurements["owner_approval_granted_count"].value,
        artifact.measurements["command_executed_count"].value,
        artifact.measurements["first_token_observed_count_total"].value,
        artifact.measurements["model_bytes_loaded_total"].value,
        artifact.measurements["red_fixture_rejection_count"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let upstream_pass = upstream_transcript_gate_pass()?;
    let probes = canonical_gemma_qat_owner_approved_runtime_replay_probe_cards(UPSTREAM_REF);
    let ledger = build_ledger(probes.clone())?;
    let reversed = GemmaQatOwnerApprovedRuntimeReplayProbeLedger::new(
        UPSTREAM_REF,
        probes.iter().cloned().rev().collect(),
        LEDGER_METADATA_BYTES,
        CREATED_AT_MS,
    )?;
    let metrics = ledger.metrics();
    let red_results = red_fixture_results(&probes);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        (
            "upstream_gemma_runtime_replay_transcript_gate_pass",
            upstream_pass,
        ),
        (
            "single_e2b_gguf_probe_envelope_present",
            metrics.probe_count == 1
                && metrics.e2b_probe_count == 1
                && metrics.gguf_lane_count == 1
                && probes[0].model_id == GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID
                && red_pass(&red_results, "e4b_selected")
                && red_pass(&red_results, "twelve_b_selected"),
        ),
        (
            "selected_transcript_card_bound",
            probes[0]
                .selected_transcript_card_id
                .contains("e2b_gguf_llama_cpp")
                && red_pass(&red_results, "bad_selected_transcript_card"),
        ),
        (
            "command_template_visible_offline_one_token",
            probes[0].command_template_visible
                && probes[0].byte_ledger.retained_token_budget == 1
                && probes[0].byte_ledger.max_context_tokens == 512
                && red_pass(&red_results, "command_template_hidden")
                && red_pass(&red_results, "token_budget_two")
                && red_pass(&red_results, "context_unbounded"),
        ),
        (
            "forbidden_command_args_absent",
            red_pass(&red_results, "hf_repo_arg_present")
                && red_pass(&red_results, "server_arg_present")
                && red_pass(&red_results, "mmap_arg_present"),
        ),
        (
            "owner_approval_pending_and_required",
            metrics.owner_approval_required_count == 1
                && metrics.owner_approval_granted_count == 0
                && red_pass(&red_results, "owner_approval_not_required")
                && red_pass(&red_results, "owner_approval_granted"),
        ),
        (
            "model_path_pending_not_opened",
            probes[0].model_path_pending
                && !probes[0].model_path_opened
                && metrics.opened_model_file_bytes_total == 0
                && red_pass(&red_results, "model_path_not_pending")
                && red_pass(&red_results, "model_path_opened"),
        ),
        (
            "required_probe_phases_bound",
            metrics.required_phase_count_total == 16 && red_pass(&red_results, "missing_phase"),
        ),
        (
            "prompt_output_digest_policy_bound",
            metrics.prompt_digest_bound_count == 1
                && metrics.output_digest_bound_count == 1
                && red_pass(&red_results, "prompt_digest_missing")
                && red_pass(&red_results, "output_digest_missing"),
        ),
        (
            "privacy_raw_output_and_stdio_bound",
            probes[0].raw_prompt_denied
                && probes[0].raw_output_denied
                && probes[0].stdout_stderr_denied
                && red_pass(&red_results, "raw_prompt_allowed")
                && red_pass(&red_results, "raw_output_allowed")
                && red_pass(&red_results, "stdio_allowed"),
        ),
        (
            "memory_cancellation_rollback_log_packet_abstention_bound",
            metrics.memory_sample_required_count == 1
                && probes[0].runtime_start_memory_sample_required
                && probes[0].cancellation_bound
                && probes[0].rollback_bound
                && probes[0].run_event_log_bound
                && probes[0].answer_packet_bound
                && probes[0].abstention_bound
                && red_pass(&red_results, "memory_sample_missing")
                && red_pass(&red_results, "cancellation_missing")
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "runtime_replay_deferred",
            metrics.runtime_replay_performed_count == 0
                && red_pass(&red_results, "runtime_replay_performed"),
        ),
        (
            "zero_model_runtime_provider_command_token_bytes",
            metrics.model_bytes_loaded_total == 0
                && metrics.runtime_bytes_loaded_total == 0
                && metrics.provider_calls_made_total == 0
                && metrics.command_executed_count == 0
                && metrics.first_token_observed_count_total == 0
                && metrics.captured_raw_prompt_bytes_total == 0
                && metrics.captured_raw_output_bytes_total == 0
                && metrics.captured_stdout_bytes_total == 0
                && metrics.captured_stderr_bytes_total == 0
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "first_token_observed")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_call"),
        ),
        (
            "no_runtime_router_or_system_g_mutation",
            !probes[0].runtime_router_mutation_allowed
                && !probes[0].system_g_mutation_allowed
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
            metrics.larger_model_probe_allowed_count == 0
                && red_pass(&red_results, "larger_model_probe_allowed"),
        ),
        (
            "runtime_replay_probe_ledger_address_deterministic",
            ledger.ledger_address == reversed.ledger_address,
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_NEXT_CURSOR
                == "gemma_qat_runtime_replay_execution_artifact_gate",
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
            "runtime_replay_probe_count",
            metrics.probe_count,
            "==",
            1,
            "probe",
        ),
        ("e2b_probe_count", metrics.e2b_probe_count, "==", 1, "probe"),
        ("gguf_lane_count", metrics.gguf_lane_count, "==", 1, "lane"),
        (
            "required_phase_count_total",
            metrics.required_phase_count_total,
            "==",
            16,
            "phases",
        ),
        (
            "owner_approval_required_count",
            metrics.owner_approval_required_count,
            "==",
            1,
            "probe",
        ),
        (
            "owner_approval_granted_count",
            metrics.owner_approval_granted_count,
            "==",
            0,
            "probe",
        ),
        (
            "command_template_visible_count",
            metrics.command_template_visible_count,
            "==",
            1,
            "probe",
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
            "prompt_digest_bound_count",
            metrics.prompt_digest_bound_count,
            "==",
            1,
            "probe",
        ),
        (
            "output_digest_bound_count",
            metrics.output_digest_bound_count,
            "==",
            1,
            "probe",
        ),
        (
            "memory_sample_required_count",
            metrics.memory_sample_required_count,
            "==",
            1,
            "probe",
        ),
        (
            "opened_model_file_bytes_total",
            metrics.opened_model_file_bytes_total,
            "==",
            0,
            "bytes",
        ),
        (
            "opened_runtime_file_bytes_total",
            metrics.opened_runtime_file_bytes_total,
            "==",
            0,
            "bytes",
        ),
        (
            "captured_raw_prompt_bytes_total",
            metrics.captured_raw_prompt_bytes_total,
            "==",
            0,
            "bytes",
        ),
        (
            "captured_raw_output_bytes_total",
            metrics.captured_raw_output_bytes_total,
            "==",
            0,
            "bytes",
        ),
        (
            "captured_stdout_bytes_total",
            metrics.captured_stdout_bytes_total,
            "==",
            0,
            "bytes",
        ),
        (
            "captured_stderr_bytes_total",
            metrics.captured_stderr_bytes_total,
            "==",
            0,
            "bytes",
        ),
        (
            "model_bytes_loaded_total",
            metrics.model_bytes_loaded_total,
            "==",
            0,
            "bytes",
        ),
        (
            "runtime_bytes_loaded_total",
            metrics.runtime_bytes_loaded_total,
            "==",
            0,
            "bytes",
        ),
        (
            "provider_calls_made_total",
            metrics.provider_calls_made_total,
            "==",
            0,
            "calls",
        ),
        (
            "first_token_observed_count_total",
            metrics.first_token_observed_count_total,
            "==",
            0,
            "tokens",
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
            "larger_model_probe_allowed_count",
            metrics.larger_model_probe_allowed_count,
            "==",
            0,
            "probes",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            ">=",
            30,
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
        "gemma_runtime_replay_probe_address",
        &ledger.ledger_address.to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_NEXT_CURSOR,
        "gemma_qat_runtime_replay_execution_artifact_gate",
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
        notes: "metadata-only F-GemmaQATOwnerApprovedRuntimeReplayProbe: consumes the Gemma runtime transcript gate and binds one E2B GGUF/llama.cpp probe envelope to owner-approval-pending state, offline one-token command template, forbidden download/server/mmap args, model-path-pending status, synthetic prompt digest, redacted output digest, fresh memory samples, cancellation, rollback, RunEventLog, AnswerPacket, abstention, and non-promotion. It opens zero files, executes zero commands, observes zero tokens, captures zero raw prompt/output/stdout/stderr bytes, loads zero model/runtime/provider bytes, and makes no MAS/L2/L3/user-facing, live Gemma default, quality, benchmark-fit, or live-70B claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_transcript_gate_pass() -> Result<bool, Box<dyn std::error::Error>> {
    if !Path::new(UPSTREAM_RESULT).exists() {
        return Ok(false);
    }
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(UPSTREAM_RESULT)?)?;
    Ok(value
        .get("overall_pass")
        .and_then(|v| v.as_bool())
        .unwrap_or(false))
}

fn build_ledger(
    probes: Vec<GemmaQatOwnerApprovedRuntimeReplayProbeCard>,
) -> Result<
    GemmaQatOwnerApprovedRuntimeReplayProbeLedger,
    agent_core::uas::GemmaQatOwnerApprovedRuntimeReplayProbeError,
> {
    GemmaQatOwnerApprovedRuntimeReplayProbeLedger::new(
        UPSTREAM_REF,
        probes,
        LEDGER_METADATA_BYTES,
        CREATED_AT_MS,
    )
}

fn red_fixture_results(
    probes: &[GemmaQatOwnerApprovedRuntimeReplayProbeCard],
) -> Vec<(&'static str, bool)> {
    let mut results = Vec::new();
    let base = probes.to_vec();
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaQatOwnerApprovedRuntimeReplayProbeCard)>,
    )> = vec![
        (
            "e4b_selected",
            Box::new(|p| p.model_id = "google/gemma-4-E4B-it-qat-q4_0-gguf".to_string()),
        ),
        (
            "twelve_b_selected",
            Box::new(|p| p.model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string()),
        ),
        (
            "bad_selected_transcript_card",
            Box::new(|p| {
                p.selected_transcript_card_id =
                    "gemma4_e4b_gguf_llama_cpp_runtime_replay_transcript_gate".to_string()
            }),
        ),
        (
            "command_template_hidden",
            Box::new(|p| p.command_template_visible = false),
        ),
        (
            "token_budget_two",
            Box::new(|p| p.byte_ledger.retained_token_budget = 2),
        ),
        (
            "context_unbounded",
            Box::new(|p| p.byte_ledger.max_context_tokens = 131_072),
        ),
        (
            "hf_repo_arg_present",
            Box::new(|p| p.command_template_args.push("--hf-repo".to_string())),
        ),
        (
            "server_arg_present",
            Box::new(|p| p.command_template_args.push("--server".to_string())),
        ),
        (
            "mmap_arg_present",
            Box::new(|p| p.command_template_args.push("--mmap".to_string())),
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
            "model_path_not_pending",
            Box::new(|p| p.model_path_pending = false),
        ),
        (
            "model_path_opened",
            Box::new(|p| {
                p.model_path_opened = true;
                p.byte_ledger.opened_model_file_bytes = 1;
            }),
        ),
        (
            "missing_phase",
            Box::new(|p| {
                p.required_phases.pop();
            }),
        ),
        (
            "prompt_digest_missing",
            Box::new(|p| p.prompt_digest_bound = false),
        ),
        (
            "output_digest_missing",
            Box::new(|p| p.output_digest_bound = false),
        ),
        (
            "raw_prompt_allowed",
            Box::new(|p| p.raw_prompt_denied = false),
        ),
        (
            "raw_output_allowed",
            Box::new(|p| p.raw_output_denied = false),
        ),
        (
            "stdio_allowed",
            Box::new(|p| p.stdout_stderr_denied = false),
        ),
        (
            "memory_sample_missing",
            Box::new(|p| p.memory_sample_required_before_runtime = false),
        ),
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
        (
            "runtime_replay_performed",
            Box::new(|p| p.runtime_replay_performed = true),
        ),
        (
            "command_executed",
            Box::new(|p| {
                p.command_executed = true;
                p.byte_ledger.command_execution_count = 1;
            }),
        ),
        (
            "first_token_observed",
            Box::new(|p| p.byte_ledger.first_token_observed_count = 1),
        ),
        (
            "model_bytes_loaded",
            Box::new(|p| p.byte_ledger.model_bytes_loaded = 1),
        ),
        (
            "runtime_bytes_loaded",
            Box::new(|p| p.byte_ledger.runtime_bytes_loaded = 1),
        ),
        (
            "provider_call",
            Box::new(|p| p.byte_ledger.provider_calls_made = 1),
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
            Box::new(|p| p.twelve_b_or_larger_probe_allowed = true),
        ),
    ];

    for (name, mutate) in cases {
        let mut mutated = base.clone();
        mutate(&mut mutated[0]);
        results.push((name, build_ledger(mutated).is_err()));
    }
    results
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
    for axis in GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_PROBE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
