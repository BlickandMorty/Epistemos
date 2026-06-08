//! `falsify_gemma_direct_harness_artifact_receipt_map`
//!
//! Metadata-only receipt-map witness for a future bounded Gemma `llama-cli`
//! run. It reads only existing upstream witness artifacts, opens no model or
//! runtime bytes, arms no command, and does not promote Gemma into System G.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaDirectHarnessArtifactReceiptMap, GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_ID,
    GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_ID;
const FIXTURE_ID: &str = "gemma_direct_harness_artifact_receipt_map_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_direct_harness_artifact_receipt_map.sh";
const RESULT: &str = "artifacts/falsifiers/gemma_direct_harness_artifact_receipt_map/result.json";
const EXECUTION_ARTIFACT_GATE_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_runtime_replay_execution_artifact_gate/result.json";
const EXECUTION_PROBE_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_owner_approved_runtime_replay_execution_probe/result.json";
const FIRST_TOKEN_REVIEW_GATE_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_first_token_runtime_artifact_review_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_491_600_000;

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
        "{FALSIFIER_ID}: overall_pass={} receipt_fields={} future_receipt_bytes_read={} command_executed={} raw_path_bytes={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_receipt_field_count"].value,
        artifact.measurements["future_receipt_bytes_read"].value,
        artifact.measurements["command_executed_count"].value,
        artifact.measurements["raw_path_bytes"].value,
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
    let execution_artifact_gate_pass = upstream_gate_pass(EXECUTION_ARTIFACT_GATE_RESULT)?;
    let execution_probe_pass = upstream_gate_pass(EXECUTION_PROBE_RESULT)?;
    let first_token_review_gate_pass = upstream_gate_pass(FIRST_TOKEN_REVIEW_GATE_RESULT)?;
    let map = GemmaDirectHarnessArtifactReceiptMap::canonical();
    map.validate()?;
    let reversed = GemmaDirectHarnessArtifactReceiptMap {
        required_receipt_sections: map
            .required_receipt_sections
            .iter()
            .cloned()
            .rev()
            .collect(),
        required_receipt_fields: map.required_receipt_fields.iter().cloned().rev().collect(),
        required_rejection_policies: map
            .required_rejection_policies
            .iter()
            .cloned()
            .rev()
            .collect(),
        ..map.clone()
    };
    reversed.validate()?;

    let metrics = map.metrics();
    let red_results = red_fixture_results(&map);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        (
            "upstream_execution_artifact_gate_pass",
            execution_artifact_gate_pass,
        ),
        ("upstream_execution_probe_pass", execution_probe_pass),
        (
            "upstream_first_token_review_gate_pass",
            first_token_review_gate_pass,
        ),
        (
            "receipt_sections_fields_and_rejection_policies_bound",
            metrics.required_receipt_section_count == 7
                && metrics.required_receipt_field_count == 26
                && metrics.required_rejection_policy_count == 37
                && red_pass(&red_results, "missing_receipt_section")
                && red_pass(&red_results, "missing_receipt_field")
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "subject_material_invocation_digests_bound",
            map.subject_digest_required
                && map.material_digests_required
                && map.invocation_digests_required
                && red_pass(&red_results, "subject_digest_missing")
                && red_pass(&red_results, "materials_digest_missing")
                && red_pass(&red_results, "invocation_digest_missing"),
        ),
        (
            "process_exit_timeout_cancel_teardown_bound",
            map.process_exit_bound
                && map.termination_reason_bound
                && map.timeout_cancel_teardown_bound
                && red_pass(&red_results, "process_exit_missing")
                && red_pass(&red_results, "termination_reason_missing")
                && red_pass(&red_results, "timeout_cancel_teardown_missing"),
        ),
        (
            "observation_redaction_timing_memory_bound",
            map.observation_digests_required
                && map.redaction_policy_bound
                && map.timing_memory_bound
                && red_pass(&red_results, "observation_digest_missing")
                && red_pass(&red_results, "redaction_policy_missing")
                && red_pass(&red_results, "timing_memory_missing"),
        ),
        (
            "run_event_log_answer_packet_rollback_abstention_bound",
            map.run_event_log_bound
                && map.answer_packet_bound
                && map.rollback_bound
                && map.abstention_bound
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "receipt_read_and_reconciliation_deferred",
            metrics.future_receipt_present_count == 0
                && metrics.future_receipt_bytes_read == 0
                && metrics.accepted_receipt_count == 0
                && metrics.receipt_reconciliation_performed_count == 0
                && red_pass(&red_results, "future_receipt_present")
                && red_pass(&red_results, "future_receipt_bytes_read")
                && red_pass(&red_results, "accepted_receipt")
                && red_pass(&red_results, "receipt_reconciliation_performed"),
        ),
        (
            "zero_command_model_runtime_provider_actions",
            metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "privacy_raw_prompt_output_stdio_token_path_denied",
            metrics.raw_prompt_bytes == 0
                && metrics.raw_output_bytes == 0
                && metrics.raw_stdout_bytes == 0
                && metrics.raw_stderr_bytes == 0
                && metrics.raw_token_bytes == 0
                && metrics.raw_path_bytes == 0
                && red_pass(&red_results, "raw_prompt")
                && red_pass(&red_results, "raw_output")
                && red_pass(&red_results, "raw_stdout")
                && red_pass(&red_results, "raw_stderr")
                && red_pass(&red_results, "raw_token")
                && red_pass(&red_results, "raw_path"),
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
            "gemma_direct_harness_receipt_map_address_deterministic",
            map.receipt_map_address(CREATED_AT_MS) == reversed.receipt_map_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_NEXT_CURSOR
                == "gemma_direct_harness_owner_approved_receipt_emitter_gate",
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
            "required_receipt_section_count",
            metrics.required_receipt_section_count,
            "==",
            7,
            "sections",
        ),
        (
            "required_receipt_field_count",
            metrics.required_receipt_field_count,
            "==",
            26,
            "fields",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            37,
            "policies",
        ),
        (
            "future_receipt_present_count",
            metrics.future_receipt_present_count,
            "==",
            0,
            "receipts",
        ),
        (
            "future_receipt_bytes_read",
            metrics.future_receipt_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "accepted_receipt_count",
            metrics.accepted_receipt_count,
            "==",
            0,
            "receipts",
        ),
        (
            "receipt_reconciliation_performed_count",
            metrics.receipt_reconciliation_performed_count,
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
        ("raw_path_bytes", metrics.raw_path_bytes, "==", 0, "bytes"),
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
            40,
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
        "gemma_direct_harness_receipt_map_address",
        &map.receipt_map_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_NEXT_CURSOR,
        "gemma_direct_harness_owner_approved_receipt_emitter_gate",
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
        notes: "metadata-only F-GemmaDirectHarnessArtifactReceiptMap: maps the Pass 211 bounded llama-cli Gemma harness rail into the existing Gemma execution artifact, owner-approved execution probe, first-token review, reconciliation, same-fixture quality, RuntimeRouter admission, dry-run route, AnswerPacket visibility, and settings WRV ladder. It binds digest-only subject/material/invocation/process/observation/join/promotion receipt sections, rejects raw prompt/output/stdout/stderr/token/path bytes, hidden command args, missing exit/termination/timeout/cancel/teardown/redaction/memory/timing/log/packet proof, parallel ladder authority, route/default/settings mutation, and product promotion. It reads zero receipt/model/runtime/provider bytes, arms or executes zero commands, and makes no Gemma live/default/L2/L3/T4/user-facing, quality, live dense 70B, or SSD-as-RAM claim.".to_string(),
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

fn red_fixture_results(map: &GemmaDirectHarnessArtifactReceiptMap) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaDirectHarnessArtifactReceiptMap)>,
    )> = vec![
        (
            "missing_receipt_section",
            Box::new(|m| {
                m.required_receipt_sections.pop();
            }),
        ),
        (
            "missing_receipt_field",
            Box::new(|m| {
                m.required_receipt_fields.pop();
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|m| {
                m.required_rejection_policies.pop();
            }),
        ),
        (
            "subject_digest_missing",
            Box::new(|m| m.subject_digest_required = false),
        ),
        (
            "materials_digest_missing",
            Box::new(|m| m.material_digests_required = false),
        ),
        (
            "invocation_digest_missing",
            Box::new(|m| m.invocation_digests_required = false),
        ),
        (
            "process_exit_missing",
            Box::new(|m| m.process_exit_bound = false),
        ),
        (
            "termination_reason_missing",
            Box::new(|m| m.termination_reason_bound = false),
        ),
        (
            "timeout_cancel_teardown_missing",
            Box::new(|m| m.timeout_cancel_teardown_bound = false),
        ),
        (
            "observation_digest_missing",
            Box::new(|m| m.observation_digests_required = false),
        ),
        (
            "redaction_policy_missing",
            Box::new(|m| m.redaction_policy_bound = false),
        ),
        (
            "timing_memory_missing",
            Box::new(|m| m.timing_memory_bound = false),
        ),
        (
            "run_event_log_missing",
            Box::new(|m| m.run_event_log_bound = false),
        ),
        (
            "answer_packet_missing",
            Box::new(|m| m.answer_packet_bound = false),
        ),
        ("rollback_missing", Box::new(|m| m.rollback_bound = false)),
        (
            "abstention_missing",
            Box::new(|m| m.abstention_bound = false),
        ),
        (
            "future_receipt_present",
            Box::new(|m| m.future_receipt_present = true),
        ),
        (
            "future_receipt_bytes_read",
            Box::new(|m| m.future_receipt_bytes_read = 1),
        ),
        (
            "accepted_receipt",
            Box::new(|m| m.accepted_receipt_count = 1),
        ),
        (
            "receipt_reconciliation_performed",
            Box::new(|m| m.receipt_reconciliation_performed_count = 1),
        ),
        ("command_armed", Box::new(|m| m.command_armed = true)),
        ("command_executed", Box::new(|m| m.command_executed = true)),
        ("model_bytes_loaded", Box::new(|m| m.model_bytes_loaded = 1)),
        (
            "runtime_bytes_loaded",
            Box::new(|m| m.runtime_bytes_loaded = 1),
        ),
        (
            "provider_calls_made",
            Box::new(|m| m.provider_calls_made = 1),
        ),
        ("raw_prompt", Box::new(|m| m.raw_prompt_bytes = 1)),
        ("raw_output", Box::new(|m| m.raw_output_bytes = 1)),
        ("raw_stdout", Box::new(|m| m.raw_stdout_bytes = 1)),
        ("raw_stderr", Box::new(|m| m.raw_stderr_bytes = 1)),
        ("raw_token", Box::new(|m| m.raw_token_bytes = 1)),
        ("raw_path", Box::new(|m| m.raw_path_bytes = 1)),
        (
            "runtime_router_mutation",
            Box::new(|m| m.runtime_router_mutation_allowed = true),
        ),
        (
            "system_g_mutation",
            Box::new(|m| m.system_g_mutation_allowed = true),
        ),
        (
            "settings_default_mutation",
            Box::new(|m| m.settings_or_default_mutation_allowed = true),
        ),
        (
            "parallel_ladder_authority",
            Box::new(|m| m.parallel_ladder_authority_allowed = true),
        ),
        (
            "hidden_route_authority",
            Box::new(|m| m.hidden_route_authority = true),
        ),
        (
            "hidden_eidos_authority",
            Box::new(|m| m.hidden_eidos_authority = true),
        ),
        (
            "hidden_lattice_authority",
            Box::new(|m| m.hidden_lattice_authority = true),
        ),
        (
            "hidden_patternboost_authority",
            Box::new(|m| m.hidden_patternboost_authority = true),
        ),
        (
            "hidden_cloud_fallback",
            Box::new(|m| m.hidden_cloud_fallback = true),
        ),
        ("quality_claim", Box::new(|m| m.quality_claimed = true)),
        (
            "mas_l2_l3_t4_claim",
            Box::new(|m| {
                m.mas_promoted = true;
                m.l2_capability_effect = true;
                m.l3_wrv_effect = true;
                m.t4_build_green_effect = true;
            }),
        ),
        (
            "gemma_default_claim",
            Box::new(|m| m.live_gemma_default_claim = true),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|m| m.live_dense_70b_claim = true),
        ),
        ("ssd_as_ram_claim", Box::new(|m| m.ssd_as_ram_claim = true)),
    ];
    cases
        .into_iter()
        .map(|(name, mutate)| {
            let mut mutated = map.clone();
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
    for axis in GEMMA_DIRECT_HARNESS_ARTIFACT_RECEIPT_MAP_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
