//! `falsify_gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate`
//!
//! Metadata-only redacted dry-run receipt gate for a future owner-approved
//! Gemma direct harness. It reads only the upstream command-envelope artifact,
//! writes no receipt, opens no paths, arms no command, spawns no process, and
//! promotes no route.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_ID,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_NEXT_CURSOR,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_ID;
const FIXTURE_ID: &str = "gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_direct_harness_owner_approved_command_envelope_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_754_400_000;

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
        "{FALSIFIER_ID}: overall_pass={} receipt_fields={} receipt_bytes_written={} process_spawned={} raw_token_bytes={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_receipt_field_count"].value,
        artifact.measurements["future_receipt_bytes_written"].value,
        artifact.measurements["process_spawned_count"].value,
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
    let gate = GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate::canonical();
    gate.validate()?;
    let reversed = GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate {
        required_receipt_fields: gate.required_receipt_fields.iter().cloned().rev().collect(),
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
        ("upstream_command_envelope_gate_pass", upstream_pass),
        (
            "upstream_command_envelope_ref_bound",
            gate.upstream_command_envelope_ref
                == GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_UPSTREAM_REF,
        ),
        (
            "receipt_fields_and_abort_conditions_bound",
            metrics.required_receipt_field_count == 28
                && metrics.required_abort_condition_count == 51
                && red_pass(&red_results, "missing_receipt_field")
                && red_pass(&red_results, "duplicate_receipt_field")
                && red_pass(&red_results, "missing_abort_condition")
                && red_pass(&red_results, "duplicate_abort_condition"),
        ),
        (
            "owner_model_llama_identity_bound",
            gate.owner_and_identity_digests_required
                && red_pass(&red_results, "owner_identity_missing"),
        ),
        (
            "exit_timeout_teardown_bound",
            gate.exit_timeout_teardown_required
                && red_pass(&red_results, "exit_timeout_teardown_missing"),
        ),
        (
            "redacted_stdio_token_prompt_policy_bound",
            gate.stdout_stderr_digest_policy_required
                && gate.first_token_digest_policy_required
                && gate.prompt_digest_policy_required
                && gate.redaction_and_byte_caps_required
                && red_pass(&red_results, "stdio_digest_policy_missing")
                && red_pass(&red_results, "token_prompt_redaction_missing"),
        ),
        (
            "memory_timing_temp_atomic_cleanup_bound",
            gate.memory_and_timing_samples_required
                && gate.temp_atomic_cleanup_required
                && red_pass(&red_results, "memory_timing_missing")
                && red_pass(&red_results, "temp_atomic_cleanup_missing"),
        ),
        (
            "rollback_log_packet_abstention_confirmation_bound",
            gate.rollback_log_packet_abstention_required
                && gate.human_confirmation_required
                && red_pass(&red_results, "rollback_log_packet_abstention_missing")
                && red_pass(&red_results, "human_confirmation_missing"),
        ),
        (
            "no_route_quality_l2_l3_t4_default_claim_bound",
            gate.no_route_mutation_bound
                && gate.no_quality_claim_bound
                && gate.no_l2_l3_t4_default_claim_bound
                && red_pass(&red_results, "no_route_mutation_missing")
                && red_pass(&red_results, "no_quality_claim_missing")
                && red_pass(&red_results, "no_l2_l3_t4_default_claim_missing"),
        ),
        (
            "receipt_write_read_deferred",
            metrics.future_receipt_written_count == 0
                && metrics.future_receipt_bytes_written == 0
                && metrics.future_receipt_bytes_read == 0
                && red_pass(&red_results, "receipt_written")
                && red_pass(&red_results, "receipt_bytes_written")
                && red_pass(&red_results, "receipt_bytes_read"),
        ),
        (
            "zero_path_command_process_file_model_runtime_provider_actions",
            metrics.temp_path_open_count == 0
                && metrics.owner_path_open_count == 0
                && metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.process_spawned_count == 0
                && metrics.file_open_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "temp_path_opened")
                && red_pass(&red_results, "owner_path_opened")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "process_spawned")
                && red_pass(&red_results, "model_file_opened")
                && red_pass(&red_results, "llama_cli_opened")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "privacy_raw_prompt_output_stdio_token_denied",
            metrics.raw_prompt_bytes == 0
                && metrics.raw_output_bytes == 0
                && metrics.raw_stdout_bytes == 0
                && metrics.raw_stderr_bytes == 0
                && metrics.raw_token_bytes == 0
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
            "gemma_direct_harness_redacted_receipt_address_deterministic",
            gate.redacted_receipt_gate_address(CREATED_AT_MS)
                == reversed.redacted_receipt_gate_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_NEXT_CURSOR
                == "gemma_direct_harness_owner_approved_first_token_digest_review_gate",
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
            28,
            "fields",
        ),
        (
            "required_abort_condition_count",
            metrics.required_abort_condition_count,
            "==",
            51,
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
            "temp_path_open_count",
            metrics.temp_path_open_count,
            "==",
            0,
            "paths",
        ),
        (
            "owner_path_open_count",
            metrics.owner_path_open_count,
            "==",
            0,
            "paths",
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
            "process_spawned_count",
            metrics.process_spawned_count,
            "==",
            0,
            "processes",
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
            45,
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
        "gemma_direct_harness_redacted_receipt_gate_address",
        &gate
            .redacted_receipt_gate_address(CREATED_AT_MS)
            .to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_NEXT_CURSOR,
        "gemma_direct_harness_owner_approved_first_token_digest_review_gate",
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
        notes: "metadata-only F-GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate: consumes the landed Gemma direct-harness owner-approved command envelope gate and freezes the digest-only redacted dry-run receipt contract. It binds owner/model/llama.cpp identity, exit/timeout/teardown policy, stdout/stderr/first-token/prompt digest policy, redaction maps, output/token byte caps, memory/timing samples, temp/atomic/cleanup policy, rollback, RunEventLog, AnswerPacket, abstention, human confirmation, no-route-mutation proof, quality denial, and non-promotion. It writes zero receipts, opens zero temp/owner/model/llama-cli paths, arms or executes zero commands, spawns zero processes, captures zero raw prompt/output/stdout/stderr/token bytes, mutates no RuntimeRouter/System G/settings/default state, and makes no Gemma live/default/L2/L3/T4/user-facing, quality, live dense 70B, or SSD-as-RAM claim.".to_string(),
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
    gate: &GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate)>,
    )> = vec![
        (
            "missing_receipt_field",
            Box::new(|g| {
                g.required_receipt_fields.pop();
            }),
        ),
        (
            "duplicate_receipt_field",
            Box::new(|g| {
                g.required_receipt_fields[0] = g.required_receipt_fields[1].clone();
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
            Box::new(|g| {
                g.required_abort_conditions[0] = g.required_abort_conditions[1].clone();
            }),
        ),
        (
            "bad_artifact_root_prefix",
            Box::new(|g| {
                g.artifact_root_prefix =
                    "artifacts/falsifiers/gemma_direct_harness_wrong_receipt_gate/".to_string();
            }),
        ),
        (
            "bad_next_cursor",
            Box::new(|g| {
                g.next_cursor = "gemma_direct_harness_wrong_next_gate".to_string();
            }),
        ),
        (
            "owner_identity_missing",
            Box::new(|g| g.owner_and_identity_digests_required = false),
        ),
        (
            "exit_timeout_teardown_missing",
            Box::new(|g| g.exit_timeout_teardown_required = false),
        ),
        (
            "stdio_digest_policy_missing",
            Box::new(|g| g.stdout_stderr_digest_policy_required = false),
        ),
        (
            "token_prompt_redaction_missing",
            Box::new(|g| {
                g.first_token_digest_policy_required = false;
                g.prompt_digest_policy_required = false;
                g.redaction_and_byte_caps_required = false;
            }),
        ),
        (
            "memory_timing_missing",
            Box::new(|g| {
                g.memory_and_timing_samples_required = false;
            }),
        ),
        (
            "temp_atomic_cleanup_missing",
            Box::new(|g| {
                g.temp_atomic_cleanup_required = false;
            }),
        ),
        (
            "rollback_log_packet_abstention_missing",
            Box::new(|g| g.rollback_log_packet_abstention_required = false),
        ),
        (
            "human_confirmation_missing",
            Box::new(|g| g.human_confirmation_required = false),
        ),
        (
            "no_route_mutation_missing",
            Box::new(|g| g.no_route_mutation_bound = false),
        ),
        (
            "no_quality_claim_missing",
            Box::new(|g| g.no_quality_claim_bound = false),
        ),
        (
            "no_l2_l3_t4_default_claim_missing",
            Box::new(|g| g.no_l2_l3_t4_default_claim_bound = false),
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
        ("temp_path_opened", Box::new(|g| g.temp_path_open_count = 1)),
        (
            "owner_path_opened",
            Box::new(|g| g.owner_path_open_count = 1),
        ),
        ("command_armed", Box::new(|g| g.command_armed = true)),
        ("command_executed", Box::new(|g| g.command_executed = true)),
        ("process_spawned", Box::new(|g| g.process_spawned = true)),
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
    for axis in GEMMA_DIRECT_HARNESS_OWNER_APPROVED_REDACTED_DRY_RUN_RECEIPT_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
