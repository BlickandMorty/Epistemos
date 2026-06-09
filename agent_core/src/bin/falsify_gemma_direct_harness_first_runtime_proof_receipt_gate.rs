//! `falsify_gemma_direct_harness_first_runtime_proof_receipt_gate`
//!
//! Metadata-only receipt gate for the first future owner-approved Gemma local
//! GGUF runtime proof. It reads only the upstream command-card artifact, writes
//! no receipt, opens no paths, arms no command, spawns no process, and promotes
//! no route.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaDirectHarnessFirstRuntimeProofReceiptGate, ProStatus, ProductBuild,
    GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_ID,
    GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_NEXT_CURSOR,
    GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_ID;
const FIXTURE_ID: &str = "gemma_direct_harness_first_runtime_proof_receipt_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_direct_harness_first_runtime_proof_receipt_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_proof_receipt_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_proof_command_card/result.json";
const CREATED_AT_MS: u64 = 1_779_840_000_000;

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
        "{FALSIFIER_ID}: overall_pass={} receipt_fields={} termination_classes={} command_executed={} process_spawned={} raw_private_bytes={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_receipt_field_count"].value,
        artifact.measurements["required_termination_class_count"].value,
        artifact.measurements["command_executed_count"].value,
        artifact.measurements["process_spawned_count"].value,
        artifact.measurements["raw_private_bytes"].value,
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
    let upstream_pass = upstream_gate_pass(UPSTREAM_RESULT)?;
    let gate = GemmaDirectHarnessFirstRuntimeProofReceiptGate::canonical();
    gate.validate()?;
    let reversed = GemmaDirectHarnessFirstRuntimeProofReceiptGate {
        required_receipt_fields: gate.required_receipt_fields.iter().cloned().rev().collect(),
        required_termination_classes: gate
            .required_termination_classes
            .iter()
            .cloned()
            .rev()
            .collect(),
        required_abort_conditions: gate
            .required_abort_conditions
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
        ("upstream_command_card_gate_pass", upstream_pass),
        (
            "upstream_command_card_ref_bound",
            gate.upstream_command_card_ref
                == GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_UPSTREAM_REF,
        ),
        (
            "local_gguf_runtime_lane_bound",
            gate.runtime_lane == "gemma-direct-harness-llama-cpp-gguf-pro-gated"
                && red_pass(&red_results, "bad_runtime_lane"),
        ),
        (
            "receipt_fields_termination_classes_and_abort_conditions_bound",
            metrics.required_receipt_field_count == 35
                && metrics.required_termination_class_count == 6
                && metrics.required_abort_condition_count == 66
                && red_pass(&red_results, "missing_receipt_field")
                && red_pass(&red_results, "duplicate_receipt_field")
                && red_pass(&red_results, "missing_termination_class")
                && red_pass(&red_results, "duplicate_termination_class")
                && red_pass(&red_results, "missing_abort_condition")
                && red_pass(&red_results, "duplicate_abort_condition"),
        ),
        (
            "owner_model_llama_command_identity_bound",
            gate.owner_and_model_identity_required
                && gate.command_card_digest_required
                && gate.llama_cli_identity_required
                && red_pass(&red_results, "owner_model_identity_missing")
                && red_pass(&red_results, "command_card_digest_missing")
                && red_pass(&red_results, "llama_identity_missing"),
        ),
        (
            "argv_environment_workdir_bound",
            gate.argv_environment_workdir_digest_required
                && red_pass(&red_results, "argv_environment_workdir_missing"),
        ),
        (
            "exit_termination_timeout_teardown_bound",
            gate.exit_termination_timeout_teardown_required
                && red_pass(&red_results, "exit_termination_missing"),
        ),
        (
            "timing_memory_stdio_token_prompt_output_bound",
            gate.timing_and_memory_digests_required
                && gate.stdout_stderr_digest_only
                && gate.first_token_digest_only
                && gate.prompt_and_output_digest_only
                && gate.redaction_and_raw_zero_proof_required
                && metrics.stdio_capture_cap_bytes == 65_536
                && red_pass(&red_results, "timing_memory_missing")
                && red_pass(&red_results, "stdio_digest_missing")
                && red_pass(&red_results, "first_token_digest_missing")
                && red_pass(&red_results, "prompt_output_digest_missing")
                && red_pass(&red_results, "redaction_raw_zero_missing")
                && red_pass(&red_results, "stdio_cap_unbounded"),
        ),
        (
            "rollback_log_packet_abstention_reviewer_summary_bound",
            gate.rollback_ref.starts_with("rollback:")
                && gate.run_event_log_ref.starts_with("run_event_log:")
                && gate.answer_packet_ref.starts_with("answer_packet:")
                && gate.abstention_required
                && gate
                    .reviewer_visible_summary_ref
                    .starts_with("reviewer_summary:")
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing")
                && red_pass(&red_results, "reviewer_summary_missing"),
        ),
        (
            "no_quality_route_or_promotion_bound",
            gate.no_quality_claim_bound
                && gate.no_route_admission_bound
                && gate.non_promotion_bound
                && red_pass(&red_results, "no_quality_missing")
                && red_pass(&red_results, "no_route_missing")
                && red_pass(&red_results, "non_promotion_missing"),
        ),
        (
            "receipt_write_read_and_command_card_read_deferred",
            metrics.future_receipt_written_count == 0
                && metrics.future_receipt_bytes_written == 0
                && metrics.future_receipt_bytes_read == 0
                && metrics.command_card_bytes_read == 0
                && red_pass(&red_results, "receipt_written")
                && red_pass(&red_results, "receipt_bytes_written")
                && red_pass(&red_results, "receipt_bytes_read")
                && red_pass(&red_results, "command_card_bytes_read"),
        ),
        (
            "zero_owner_path_command_process_server_network_model_runtime_provider_actions",
            metrics.owner_path_open_count == 0
                && metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.process_spawned_count == 0
                && metrics.server_started_count == 0
                && metrics.network_or_hub_or_endpoint_count == 0
                && metrics.file_open_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "owner_path_opened")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "process_spawned")
                && red_pass(&red_results, "server_started")
                && red_pass(&red_results, "network_allowed")
                && red_pass(&red_results, "hub_download_allowed")
                && red_pass(&red_results, "remote_endpoint_allowed")
                && red_pass(&red_results, "model_file_opened")
                && red_pass(&red_results, "llama_cli_opened")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "privacy_raw_path_prompt_output_stdio_token_denied",
            metrics.raw_private_bytes == 0
                && red_pass(&red_results, "raw_model_path")
                && red_pass(&red_results, "raw_prompt")
                && red_pass(&red_results, "raw_output")
                && red_pass(&red_results, "raw_stdout")
                && red_pass(&red_results, "raw_stderr")
                && red_pass(&red_results, "raw_token"),
        ),
        (
            "no_route_system_g_settings_mutation",
            metrics.mutation_count == 0
                && red_pass(&red_results, "runtime_router_mutation")
                && red_pass(&red_results, "system_g_mutation")
                && red_pass(&red_results, "settings_default_mutation"),
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
            "no_quality_mas_l2_l3_t4_default_70b_or_ssd_claim",
            metrics.promotion_claim_count == 0
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "mas_l2_l3_t4_claim")
                && red_pass(&red_results, "gemma_default_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "gemma_first_runtime_proof_receipt_gate_address_deterministic",
            gate.receipt_gate_address(CREATED_AT_MS)
                == reversed.receipt_gate_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_NEXT_CURSOR
                == "gemma_direct_harness_owner_approved_first_runtime_execution_probe",
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
            "required_receipt_field_count",
            metrics.required_receipt_field_count,
            "==",
            35,
            "fields",
        ),
        (
            "required_termination_class_count",
            metrics.required_termination_class_count,
            "==",
            6,
            "classes",
        ),
        (
            "required_abort_condition_count",
            metrics.required_abort_condition_count,
            "==",
            66,
            "conditions",
        ),
        (
            "stdio_capture_cap_bytes",
            metrics.stdio_capture_cap_bytes,
            "==",
            65_536,
            "bytes",
        ),
        (
            "future_receipt_written_count",
            metrics.future_receipt_written_count,
            "==",
            0,
            "count",
        ),
        (
            "future_receipt_bytes_written",
            metrics.future_receipt_bytes_written,
            "==",
            0,
            "bytes",
        ),
        (
            "future_receipt_bytes_read",
            metrics.future_receipt_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "command_card_bytes_read",
            metrics.command_card_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "owner_path_open_count",
            metrics.owner_path_open_count,
            "==",
            0,
            "count",
        ),
        (
            "command_armed_count",
            metrics.command_armed_count,
            "==",
            0,
            "count",
        ),
        (
            "command_executed_count",
            metrics.command_executed_count,
            "==",
            0,
            "count",
        ),
        (
            "process_spawned_count",
            metrics.process_spawned_count,
            "==",
            0,
            "count",
        ),
        (
            "server_started_count",
            metrics.server_started_count,
            "==",
            0,
            "count",
        ),
        (
            "network_or_hub_or_endpoint_count",
            metrics.network_or_hub_or_endpoint_count,
            "==",
            0,
            "count",
        ),
        ("file_open_count", metrics.file_open_count, "==", 0, "count"),
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
            "count",
        ),
        (
            "raw_private_bytes",
            metrics.raw_private_bytes,
            "==",
            0,
            "bytes",
        ),
        ("mutation_count", metrics.mutation_count, "==", 0, "count"),
        (
            "hidden_authority_count",
            metrics.hidden_authority_count,
            "==",
            0,
            "count",
        ),
        (
            "promotion_claim_count",
            metrics.promotion_claim_count,
            "==",
            0,
            "count",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            ">=",
            70,
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
        "gemma_first_runtime_proof_receipt_gate_address",
        &gate.receipt_gate_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_NEXT_CURSOR,
        "gemma_direct_harness_owner_approved_first_runtime_execution_probe",
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
        notes: "metadata-only F-GemmaDirectHarnessFirstRuntimeProofReceiptGate: consumes the Gemma first-runtime proof command-card gate and freezes the digest-only receipt contract required before a future owner-approved local GGUF execution probe can count as evidence. It binds model/llama.cpp/command identity, argv/environment/workdir digests, exit and termination classification, timeout/cancel/teardown, timing and memory digests, stdout/stderr/first-token/prompt/output digests, redaction proof, raw-byte-zero proof, rollback, RunEventLog, AnswerPacket, abstention, reviewer-visible summary, no-quality, no-route-admission, and non-promotion. It writes zero receipt bytes, reads zero command-card or receipt bytes, opens zero owner/model/llama.cpp paths, arms or executes zero commands, spawns zero processes, starts zero servers, allows zero network/hub/endpoint route, loads zero model/runtime/provider bytes, captures zero raw private bytes, mutates no RuntimeRouter/System G/settings/default state, and makes no MAS/L2/L3/T4/user-facing, Gemma-default, quality, live dense 70B, or SSD-as-RAM claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_gate_pass(path: &str) -> Result<bool, Box<dyn std::error::Error>> {
    if !Path::new(path).exists() {
        return Ok(false);
    }
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(path)?)?;
    Ok(value
        .get("overall_pass")
        .and_then(|value| value.as_bool())
        .unwrap_or(false))
}

fn red_fixture_results(
    gate: &GemmaDirectHarnessFirstRuntimeProofReceiptGate,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaDirectHarnessFirstRuntimeProofReceiptGate)>,
    )> = vec![
        (
            "bad_upstream_ref",
            Box::new(|g| {
                g.upstream_command_card_ref =
                    "artifact:falsifiers/wrong/result.json#wrong".to_string()
            }),
        ),
        (
            "bad_upstream_id",
            Box::new(|g| g.upstream_command_card_id = "F-Wrong".to_string()),
        ),
        (
            "bad_artifact_root",
            Box::new(|g| g.artifact_root_prefix = "artifacts/falsifiers/wrong/".to_string()),
        ),
        (
            "bad_receipt_gate_id",
            Box::new(|g| g.receipt_gate_id = "wrong".to_string()),
        ),
        (
            "bad_future_receipt_name",
            Box::new(|g| g.future_receipt_name = "wrong".to_string()),
        ),
        (
            "bad_runtime_lane",
            Box::new(|g| g.runtime_lane = "hidden-server-lane".to_string()),
        ),
        (
            "mas_product_build",
            Box::new(|g| g.product_build = ProductBuild::Mas),
        ),
        (
            "live_pro_status",
            Box::new(|g| g.pro_status = ProStatus::Live),
        ),
        (
            "metadata_too_large",
            Box::new(|g| g.metadata_bytes = 385 * 1024),
        ),
        (
            "missing_receipt_field",
            Box::new(|g| {
                g.required_receipt_fields.pop();
            }),
        ),
        (
            "duplicate_receipt_field",
            Box::new(|g| g.required_receipt_fields[0] = g.required_receipt_fields[1].clone()),
        ),
        (
            "missing_termination_class",
            Box::new(|g| {
                g.required_termination_classes.pop();
            }),
        ),
        (
            "duplicate_termination_class",
            Box::new(|g| {
                g.required_termination_classes[0] = g.required_termination_classes[1].clone()
            }),
        ),
        (
            "missing_abort_condition",
            Box::new(|g| {
                g.required_abort_conditions.pop();
            }),
        ),
        (
            "duplicate_abort_condition",
            Box::new(|g| g.required_abort_conditions[0] = g.required_abort_conditions[1].clone()),
        ),
        (
            "owner_model_identity_missing",
            Box::new(|g| g.owner_and_model_identity_required = false),
        ),
        (
            "command_card_digest_missing",
            Box::new(|g| g.command_card_digest_required = false),
        ),
        (
            "llama_identity_missing",
            Box::new(|g| g.llama_cli_identity_required = false),
        ),
        (
            "argv_environment_workdir_missing",
            Box::new(|g| g.argv_environment_workdir_digest_required = false),
        ),
        (
            "exit_termination_missing",
            Box::new(|g| g.exit_termination_timeout_teardown_required = false),
        ),
        (
            "timing_memory_missing",
            Box::new(|g| g.timing_and_memory_digests_required = false),
        ),
        (
            "stdio_digest_missing",
            Box::new(|g| g.stdout_stderr_digest_only = false),
        ),
        (
            "first_token_digest_missing",
            Box::new(|g| g.first_token_digest_only = false),
        ),
        (
            "prompt_output_digest_missing",
            Box::new(|g| g.prompt_and_output_digest_only = false),
        ),
        (
            "redaction_raw_zero_missing",
            Box::new(|g| g.redaction_and_raw_zero_proof_required = false),
        ),
        (
            "stdio_cap_unbounded",
            Box::new(|g| g.stdio_capture_cap_bytes = 1_000_000),
        ),
        (
            "rollback_missing",
            Box::new(|g| g.rollback_ref = "wrong".to_string()),
        ),
        (
            "run_event_log_missing",
            Box::new(|g| g.run_event_log_ref = "wrong".to_string()),
        ),
        (
            "answer_packet_missing",
            Box::new(|g| g.answer_packet_ref = "wrong".to_string()),
        ),
        (
            "abstention_missing",
            Box::new(|g| g.abstention_required = false),
        ),
        (
            "reviewer_summary_missing",
            Box::new(|g| g.reviewer_visible_summary_ref = "wrong".to_string()),
        ),
        (
            "no_quality_missing",
            Box::new(|g| g.no_quality_claim_bound = false),
        ),
        (
            "no_route_missing",
            Box::new(|g| g.no_route_admission_bound = false),
        ),
        (
            "non_promotion_missing",
            Box::new(|g| g.non_promotion_bound = false),
        ),
        (
            "receipt_written",
            Box::new(|g| g.future_receipt_written_count = 1),
        ),
        (
            "receipt_bytes_written",
            Box::new(|g| g.future_receipt_bytes_written = 1),
        ),
        (
            "receipt_bytes_read",
            Box::new(|g| g.future_receipt_bytes_read = 1),
        ),
        (
            "command_card_bytes_read",
            Box::new(|g| g.command_card_bytes_read = 1),
        ),
        (
            "owner_path_opened",
            Box::new(|g| g.owner_path_open_count = 1),
        ),
        (
            "model_file_opened",
            Box::new(|g| g.model_file_opened = true),
        ),
        ("llama_cli_opened", Box::new(|g| g.llama_cli_opened = true)),
        ("command_armed", Box::new(|g| g.command_armed = true)),
        ("command_executed", Box::new(|g| g.command_executed = true)),
        ("process_spawned", Box::new(|g| g.process_spawned = true)),
        ("server_started", Box::new(|g| g.server_started = true)),
        ("network_allowed", Box::new(|g| g.network_allowed = true)),
        (
            "hub_download_allowed",
            Box::new(|g| g.hub_download_allowed = true),
        ),
        (
            "remote_endpoint_allowed",
            Box::new(|g| g.remote_endpoint_allowed = true),
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
        ("raw_model_path", Box::new(|g| g.raw_model_path_bytes = 1)),
        ("raw_prompt", Box::new(|g| g.raw_prompt_bytes = 1)),
        ("raw_output", Box::new(|g| g.raw_output_bytes = 1)),
        ("raw_stdout", Box::new(|g| g.raw_stdout_bytes = 1)),
        ("raw_stderr", Box::new(|g| g.raw_stderr_bytes = 1)),
        ("raw_token", Box::new(|g| g.raw_token_bytes = 1)),
        (
            "runtime_router_mutation",
            Box::new(|g| g.runtime_router_mutation_allowed = true),
        ),
        (
            "system_g_mutation",
            Box::new(|g| g.system_g_mutation_allowed = true),
        ),
        (
            "settings_default_mutation",
            Box::new(|g| g.settings_or_default_mutation_allowed = true),
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
        ("quality_claim", Box::new(|g| g.quality_claimed = true)),
        (
            "mas_l2_l3_t4_claim",
            Box::new(|g| {
                g.mas_promoted = true;
                g.l2_capability_effect = true;
                g.l3_wrv_effect = true;
                g.t4_build_green_effect = true;
            }),
        ),
        (
            "gemma_default_claim",
            Box::new(|g| g.live_gemma_default_claim = true),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|g| g.live_dense_70b_claim = true),
        ),
        ("ssd_as_ram_claim", Box::new(|g| g.ssd_as_ram_claim = true)),
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
    for axis in GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_RECEIPT_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
