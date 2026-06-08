//! `falsify_gemma_direct_harness_owner_approved_receipt_emitter_gate`
//!
//! Metadata-only emitter gate for a future owner-approved Gemma direct-harness
//! receipt. It reads only the upstream receipt-map artifact, writes no receipt,
//! opens no model/runtime files, arms no command, and promotes no route.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaDirectHarnessOwnerApprovedReceiptEmitterGate,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_ID,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_NEXT_CURSOR,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_ID;
const FIXTURE_ID: &str = "gemma_direct_harness_owner_approved_receipt_emitter_gate_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_gemma_direct_harness_owner_approved_receipt_emitter_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_direct_harness_owner_approved_receipt_emitter_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_direct_harness_artifact_receipt_map/result.json";
const CREATED_AT_MS: u64 = 1_779_495_200_000;

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
        "{FALSIFIER_ID}: overall_pass={} emitter_fields={} future_receipt_bytes_written={} command_executed={} raw_token_bytes={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_emitter_field_count"].value,
        artifact.measurements["future_receipt_bytes_written"].value,
        artifact.measurements["command_executed_count"].value,
        artifact.measurements["raw_token_bytes"].value,
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
    let gate = GemmaDirectHarnessOwnerApprovedReceiptEmitterGate::canonical();
    gate.validate()?;
    let reversed = GemmaDirectHarnessOwnerApprovedReceiptEmitterGate {
        required_emitter_fields: gate.required_emitter_fields.iter().cloned().rev().collect(),
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
        ("upstream_receipt_map_pass", upstream_pass),
        (
            "upstream_receipt_map_ref_bound",
            gate.upstream_receipt_map_ref
                == GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_UPSTREAM_REF,
        ),
        (
            "emitter_fields_and_abort_conditions_bound",
            metrics.required_emitter_field_count == 33
                && metrics.required_abort_condition_count == 42
                && red_pass(&red_results, "missing_emitter_field")
                && red_pass(&red_results, "missing_abort_condition"),
        ),
        (
            "owner_source_model_runtime_command_digests_bound",
            gate.upstream_receipt_map_digest_required
                && gate.owner_approval_required
                && gate.owner_path_manifest_digest_required
                && gate.model_file_digest_required
                && gate.llama_cli_binary_digest_required
                && gate.llama_cli_version_digest_required
                && gate.command_template_digest_required
                && red_pass(&red_results, "upstream_digest_missing")
                && red_pass(&red_results, "owner_approval_missing")
                && red_pass(&red_results, "owner_path_manifest_missing")
                && red_pass(&red_results, "model_digest_missing")
                && red_pass(&red_results, "llama_cli_digest_missing")
                && red_pass(&red_results, "llama_cli_version_missing")
                && red_pass(&red_results, "command_template_missing"),
        ),
        (
            "argv_environment_prompt_grammar_digests_bound",
            gate.argv_environment_workdir_digests_required
                && gate.prompt_and_grammar_digests_required
                && red_pass(&red_results, "argv_environment_workdir_missing")
                && red_pass(&red_results, "prompt_grammar_missing"),
        ),
        (
            "process_timeout_cancel_teardown_stdio_policies_bound",
            gate.process_exit_policy_bound
                && gate.timeout_cancel_teardown_policy_bound
                && gate.stdout_stderr_digest_policy_bound
                && red_pass(&red_results, "process_exit_policy_missing")
                && red_pass(&red_results, "timeout_cancel_teardown_missing")
                && red_pass(&red_results, "stdio_digest_policy_missing"),
        ),
        (
            "token_redaction_timing_memory_atomic_cleanup_bound",
            gate.first_token_redaction_bound
                && gate.timing_sampler_bound
                && gate.memory_sampler_bound
                && gate.atomic_write_policy_bound
                && gate.cleanup_policy_bound
                && red_pass(&red_results, "first_token_redaction_missing")
                && red_pass(&red_results, "timing_sampler_missing")
                && red_pass(&red_results, "memory_sampler_missing")
                && red_pass(&red_results, "atomic_write_policy_missing")
                && red_pass(&red_results, "cleanup_policy_missing"),
        ),
        (
            "log_packet_rollback_abstention_bound",
            gate.run_event_log_bound
                && gate.answer_packet_bound
                && gate.rollback_bound
                && gate.abstention_bound
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "receipt_write_and_read_deferred",
            metrics.future_receipt_written_count == 0
                && metrics.future_receipt_bytes_written == 0
                && metrics.future_receipt_bytes_read == 0
                && red_pass(&red_results, "receipt_written")
                && red_pass(&red_results, "receipt_bytes_written")
                && red_pass(&red_results, "receipt_bytes_read"),
        ),
        (
            "zero_command_file_model_runtime_provider_actions",
            metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.file_open_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "model_file_opened")
                && red_pass(&red_results, "llama_cli_opened")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "privacy_raw_path_prompt_output_stdio_token_and_non_digest_denied",
            metrics.raw_owner_path_bytes == 0
                && metrics.raw_prompt_bytes == 0
                && metrics.raw_output_bytes == 0
                && metrics.raw_stdout_bytes == 0
                && metrics.raw_stderr_bytes == 0
                && metrics.raw_token_bytes == 0
                && metrics.non_digest_receipt_field_count == 0
                && red_pass(&red_results, "raw_owner_path")
                && red_pass(&red_results, "raw_prompt")
                && red_pass(&red_results, "raw_output")
                && red_pass(&red_results, "raw_stdout")
                && red_pass(&red_results, "raw_stderr")
                && red_pass(&red_results, "raw_token")
                && red_pass(&red_results, "non_digest_receipt_field"),
        ),
        (
            "no_route_system_g_settings_or_parallel_authority",
            metrics.mutation_count == 0
                && red_pass(&red_results, "runtime_router_mutation")
                && red_pass(&red_results, "system_g_mutation")
                && red_pass(&red_results, "settings_default_mutation")
                && red_pass(&red_results, "parallel_ladder_authority"),
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
            "gemma_direct_harness_receipt_emitter_address_deterministic",
            gate.emitter_gate_address(CREATED_AT_MS)
                == reversed.emitter_gate_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_NEXT_CURSOR
                == "gemma_direct_harness_receipt_emitter_dry_run_artifact_gate",
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
            "required_emitter_field_count",
            metrics.required_emitter_field_count,
            "==",
            33,
            "fields",
        ),
        (
            "required_abort_condition_count",
            metrics.required_abort_condition_count,
            "==",
            42,
            "conditions",
        ),
        (
            "future_receipt_written_count",
            metrics.future_receipt_written_count,
            "==",
            0,
            "receipts",
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
        ("file_open_count", metrics.file_open_count, "==", 0, "files"),
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
            "raw_owner_path_bytes",
            metrics.raw_owner_path_bytes,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_prompt_bytes",
            metrics.raw_prompt_bytes,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_output_bytes",
            metrics.raw_output_bytes,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_stdout_bytes",
            metrics.raw_stdout_bytes,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_stderr_bytes",
            metrics.raw_stderr_bytes,
            "==",
            0,
            "bytes",
        ),
        ("raw_token_bytes", metrics.raw_token_bytes, "==", 0, "bytes"),
        (
            "non_digest_receipt_field_count",
            metrics.non_digest_receipt_field_count,
            "==",
            0,
            "fields",
        ),
        ("mutation_count", metrics.mutation_count, "==", 0, "claims"),
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
            50,
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
        "gemma_direct_harness_receipt_emitter_gate_address",
        &gate.emitter_gate_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_NEXT_CURSOR,
        "gemma_direct_harness_receipt_emitter_dry_run_artifact_gate",
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
        notes: "metadata-only F-GemmaDirectHarnessOwnerApprovedReceiptEmitterGate: consumes the landed Gemma direct harness receipt-map witness and defines the fail-closed emitter contract for a future owner-approved bounded llama-cli receipt. It binds owner approval, owner path manifest, model/llama-cli/version/command/argv/environment/workdir/prompt/grammar digests, process exit/timeout/cancel/teardown policies, stdout/stderr digest policy, token redaction, timing/memory samplers, atomic write and cleanup policy, RunEventLog, AnswerPacket, rollback, abstention, and non-promotion. It writes zero receipts, reads zero receipt/model/runtime/provider bytes, opens zero model or llama-cli files, arms or executes zero commands, captures zero raw path/prompt/output/stdout/stderr/token bytes, allows zero non-digest receipt fields, mutates no RuntimeRouter/System G/settings/default state, and makes no Gemma live/default/L2/L3/T4/user-facing, quality, live dense 70B, or SSD-as-RAM claim.".to_string(),
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
    gate: &GemmaDirectHarnessOwnerApprovedReceiptEmitterGate,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaDirectHarnessOwnerApprovedReceiptEmitterGate)>,
    )> = vec![
        (
            "missing_emitter_field",
            Box::new(|g| {
                g.required_emitter_fields.pop();
            }),
        ),
        (
            "missing_abort_condition",
            Box::new(|g| {
                g.required_abort_conditions.pop();
            }),
        ),
        (
            "upstream_digest_missing",
            Box::new(|g| g.upstream_receipt_map_digest_required = false),
        ),
        (
            "owner_approval_missing",
            Box::new(|g| g.owner_approval_required = false),
        ),
        (
            "owner_path_manifest_missing",
            Box::new(|g| g.owner_path_manifest_digest_required = false),
        ),
        (
            "model_digest_missing",
            Box::new(|g| g.model_file_digest_required = false),
        ),
        (
            "llama_cli_digest_missing",
            Box::new(|g| g.llama_cli_binary_digest_required = false),
        ),
        (
            "llama_cli_version_missing",
            Box::new(|g| g.llama_cli_version_digest_required = false),
        ),
        (
            "command_template_missing",
            Box::new(|g| g.command_template_digest_required = false),
        ),
        (
            "argv_environment_workdir_missing",
            Box::new(|g| g.argv_environment_workdir_digests_required = false),
        ),
        (
            "prompt_grammar_missing",
            Box::new(|g| g.prompt_and_grammar_digests_required = false),
        ),
        (
            "process_exit_policy_missing",
            Box::new(|g| g.process_exit_policy_bound = false),
        ),
        (
            "timeout_cancel_teardown_missing",
            Box::new(|g| g.timeout_cancel_teardown_policy_bound = false),
        ),
        (
            "stdio_digest_policy_missing",
            Box::new(|g| g.stdout_stderr_digest_policy_bound = false),
        ),
        (
            "first_token_redaction_missing",
            Box::new(|g| g.first_token_redaction_bound = false),
        ),
        (
            "timing_sampler_missing",
            Box::new(|g| g.timing_sampler_bound = false),
        ),
        (
            "memory_sampler_missing",
            Box::new(|g| g.memory_sampler_bound = false),
        ),
        (
            "atomic_write_policy_missing",
            Box::new(|g| g.atomic_write_policy_bound = false),
        ),
        (
            "cleanup_policy_missing",
            Box::new(|g| g.cleanup_policy_bound = false),
        ),
        (
            "run_event_log_missing",
            Box::new(|g| g.run_event_log_bound = false),
        ),
        (
            "answer_packet_missing",
            Box::new(|g| g.answer_packet_bound = false),
        ),
        ("rollback_missing", Box::new(|g| g.rollback_bound = false)),
        (
            "abstention_missing",
            Box::new(|g| g.abstention_bound = false),
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
        ("command_armed", Box::new(|g| g.command_armed = true)),
        ("command_executed", Box::new(|g| g.command_executed = true)),
        (
            "model_file_opened",
            Box::new(|g| g.model_file_opened = true),
        ),
        ("llama_cli_opened", Box::new(|g| g.llama_cli_opened = true)),
        ("model_bytes_loaded", Box::new(|g| g.model_bytes_loaded = 1)),
        (
            "runtime_bytes_loaded",
            Box::new(|g| g.runtime_bytes_loaded = 1),
        ),
        (
            "provider_calls_made",
            Box::new(|g| g.provider_calls_made = 1),
        ),
        ("raw_owner_path", Box::new(|g| g.raw_owner_path_bytes = 1)),
        ("raw_prompt", Box::new(|g| g.raw_prompt_bytes = 1)),
        ("raw_output", Box::new(|g| g.raw_output_bytes = 1)),
        ("raw_stdout", Box::new(|g| g.raw_stdout_bytes = 1)),
        ("raw_stderr", Box::new(|g| g.raw_stderr_bytes = 1)),
        ("raw_token", Box::new(|g| g.raw_token_bytes = 1)),
        (
            "non_digest_receipt_field",
            Box::new(|g| g.non_digest_receipt_field_count = 1),
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
            "settings_default_mutation",
            Box::new(|g| g.settings_or_default_mutation_allowed = true),
        ),
        (
            "parallel_ladder_authority",
            Box::new(|g| g.parallel_ladder_authority_allowed = true),
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
    for axis in GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RECEIPT_EMITTER_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
