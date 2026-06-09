//! `falsify_gemma_owner_approved_local_artifact_receipt_probe`
//!
//! Metadata-only probe for the owner-approved Gemma local artifact receipt
//! cutline. It binds the receipt contract while opening no files, hashing no
//! model bytes, executing no commands, and promoting no route.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaOwnerApprovedLocalArtifactReceiptProbe,
    GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_ID,
    GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_NEXT_CURSOR,
    GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_ID;
const FIXTURE_ID: &str = "gemma_owner_approved_local_artifact_receipt_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_owner_approved_local_artifact_receipt_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_local_artifact_discovery_runbook_gate/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} receipt_fields={} model_ids={} runtime_lanes={} file_actions={} runtime_actions={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_receipt_field_count"].value,
        artifact.measurements["allowed_model_id_count"].value,
        artifact.measurements["allowed_runtime_lane_count"].value,
        artifact.measurements["local_file_action_count"].value,
        artifact.measurements["runtime_action_count"].value,
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
    let probe = GemmaOwnerApprovedLocalArtifactReceiptProbe::canonical();
    probe.validate()?;
    let metrics = probe.metrics();
    let red_results = red_fixture_results(&probe);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_discovery_runbook_gate_pass", upstream_pass),
        (
            "upstream_discovery_runbook_gate_ref_bound",
            probe.upstream_discovery_runbook_ref
                == GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_UPSTREAM_REF,
        ),
        (
            "receipt_fields_bound",
            metrics.required_receipt_field_count == 28
                && red_pass(&red_results, "missing_receipt_field")
                && red_pass(&red_results, "duplicate_receipt_field"),
        ),
        (
            "model_and_runtime_lane_policy_bound",
            metrics.allowed_model_id_count == 4
                && metrics.allowed_runtime_lane_count == 3
                && red_pass(&red_results, "missing_model_id")
                && red_pass(&red_results, "unknown_model_id")
                && red_pass(&red_results, "missing_runtime_lane")
                && red_pass(&red_results, "unknown_runtime_lane"),
        ),
        (
            "shortcut_and_rejection_policy_bound",
            metrics.denied_shortcut_count == 14
                && metrics.rejection_policy_count == 36
                && red_pass(&red_results, "missing_denied_shortcut")
                && red_pass(&red_results, "duplicate_denied_shortcut")
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "owner_approval_required_but_absent",
            metrics.owner_approval_required_count == 1
                && metrics.owner_approval_granted_count == 0
                && red_pass(&red_results, "owner_approval_not_required")
                && red_pass(&red_results, "owner_approval_granted"),
        ),
        (
            "receipt_fixture_deferred",
            metrics.receipt_fixture_present_count == 0
                && metrics.receipt_bytes_written == 0
                && metrics.receipt_bytes_read == 0
                && red_pass(&red_results, "receipt_fixture_present")
                && red_pass(&red_results, "receipt_bytes_written")
                && red_pass(&red_results, "receipt_bytes_read"),
        ),
        (
            "zero_raw_path_file_hash_help_actions",
            metrics.raw_path_storage_count == 0
                && metrics.local_file_action_count == 0
                && red_pass(&red_results, "raw_path_storage")
                && red_pass(&red_results, "path_canonicalized")
                && red_pass(&red_results, "local_file_opened")
                && red_pass(&red_results, "local_file_hashed")
                && red_pass(&red_results, "sha256_materialized")
                && red_pass(&red_results, "byte_count_verified")
                && red_pass(&red_results, "llama_cli_version_executed")
                && red_pass(&red_results, "llama_cli_help_executed"),
        ),
        (
            "zero_command_runtime_server_network_actions",
            metrics.runtime_action_count == 0
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "server_started")
                && red_pass(&red_results, "network_probe_allowed"),
        ),
        (
            "zero_model_runtime_provider_bytes",
            metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_called"),
        ),
        (
            "no_route_system_g_settings_mutation",
            metrics.route_mutation_count == 0
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
            "rollback_log_packet_abstention_bound",
            probe.rollback_ref.starts_with("rollback:")
                && probe.run_event_log_ref.starts_with("run_event_log:")
                && probe.answer_packet_ref.starts_with("answer_packet:")
                && probe.abstention_required
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "no_quality_l2_l3_t4_gemma_70b_or_ssd_claim",
            metrics.promotion_claim_count == 0
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "l2_l3_t4_claim")
                && red_pass(&red_results, "live_gemma_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "gemma_owner_approved_local_artifact_receipt_probe_address_deterministic",
            probe.address() == GemmaOwnerApprovedLocalArtifactReceiptProbe::canonical().address(),
        ),
        (
            "next_cursor_bound",
            probe.next_cursor == GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_NEXT_CURSOR,
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
            "allowed_model_id_count",
            metrics.allowed_model_id_count,
            "==",
            4,
            "models",
        ),
        (
            "allowed_runtime_lane_count",
            metrics.allowed_runtime_lane_count,
            "==",
            3,
            "lanes",
        ),
        (
            "denied_shortcut_count",
            metrics.denied_shortcut_count,
            "==",
            14,
            "shortcuts",
        ),
        (
            "rejection_policy_count",
            metrics.rejection_policy_count,
            "==",
            36,
            "policies",
        ),
        (
            "owner_approval_required_count",
            metrics.owner_approval_required_count,
            "==",
            1,
            "requirements",
        ),
        (
            "owner_approval_granted_count",
            metrics.owner_approval_granted_count,
            "==",
            0,
            "approvals",
        ),
        (
            "receipt_fixture_present_count",
            metrics.receipt_fixture_present_count,
            "==",
            0,
            "receipts",
        ),
        (
            "receipt_bytes_written",
            metrics.receipt_bytes_written,
            "==",
            0,
            "bytes",
        ),
        (
            "receipt_bytes_read",
            metrics.receipt_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_path_storage_count",
            metrics.raw_path_storage_count,
            "==",
            0,
            "paths",
        ),
        (
            "local_file_action_count",
            metrics.local_file_action_count,
            "==",
            0,
            "actions",
        ),
        (
            "runtime_action_count",
            metrics.runtime_action_count,
            "==",
            0,
            "actions",
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
            "route_mutation_count",
            metrics.route_mutation_count,
            "==",
            0,
            "mutations",
        ),
        (
            "hidden_authority_count",
            metrics.hidden_authority_count,
            "==",
            0,
            "authorities",
        ),
        (
            "promotion_claim_count",
            metrics.promotion_claim_count,
            "==",
            0,
            "claims",
        ),
        (
            "metadata_bytes",
            metrics.metadata_bytes,
            "<=",
            196_608,
            "bytes",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            ">=",
            red_results.len() as u64,
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
        "gemma_owner_approved_local_artifact_receipt_probe_address",
        &probe.address().to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_NEXT_CURSOR,
        GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_NEXT_CURSOR,
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
        notes: "metadata-only F-GemmaOwnerApprovedLocalArtifactReceiptProbe: consumes the Gemma local artifact discovery runbook and freezes the owner-approved local artifact receipt cutline. It requires explicit future owner approval, model/source/revision/byte/sha/path-digest/runtime-lane fields, llama-cli help/version/offline evidence fields, rollback, RunEventLog, AnswerPacket, abstention, and non-promotion while storing zero raw paths, opening zero files, hashing zero model bytes, arming zero commands, loading zero model/runtime/provider bytes, and making no Gemma L2/L3/T4/user-facing claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_gate_pass(path: &str) -> Result<bool, Box<dyn std::error::Error>> {
    if !Path::new(path).exists() {
        return Ok(false);
    }
    let bytes = std::fs::read(path)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(json
        .get("overall_pass")
        .and_then(|value| value.as_bool())
        .unwrap_or(false))
}

fn red_fixture_results(
    probe: &GemmaOwnerApprovedLocalArtifactReceiptProbe,
) -> Vec<(&'static str, bool)> {
    let mut fixtures: Vec<(
        &'static str,
        Box<
            dyn Fn(
                GemmaOwnerApprovedLocalArtifactReceiptProbe,
            ) -> GemmaOwnerApprovedLocalArtifactReceiptProbe,
        >,
    )> = vec![
        (
            "missing_receipt_field",
            Box::new(|mut p| {
                p.required_receipt_fields.pop();
                p
            }),
        ),
        (
            "duplicate_receipt_field",
            Box::new(|mut p| {
                p.required_receipt_fields
                    .push(p.required_receipt_fields[0].clone());
                p
            }),
        ),
        (
            "missing_model_id",
            Box::new(|mut p| {
                p.allowed_model_ids.pop();
                p
            }),
        ),
        (
            "unknown_model_id",
            Box::new(|mut p| {
                p.allowed_model_ids[0] = "google/gemma-latest".to_string();
                p
            }),
        ),
        (
            "missing_runtime_lane",
            Box::new(|mut p| {
                p.allowed_runtime_lanes.pop();
                p
            }),
        ),
        (
            "unknown_runtime_lane",
            Box::new(|mut p| {
                p.allowed_runtime_lanes[0] = "hidden_local_endpoint".to_string();
                p
            }),
        ),
        (
            "missing_denied_shortcut",
            Box::new(|mut p| {
                p.denied_shortcuts.pop();
                p
            }),
        ),
        (
            "duplicate_denied_shortcut",
            Box::new(|mut p| {
                p.denied_shortcuts.push(p.denied_shortcuts[0].clone());
                p
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|mut p| {
                p.required_rejection_policies.pop();
                p
            }),
        ),
        (
            "owner_approval_not_required",
            Box::new(|mut p| {
                p.owner_approval_required = false;
                p
            }),
        ),
        (
            "owner_approval_granted",
            Box::new(|mut p| {
                p.owner_approval_granted = true;
                p
            }),
        ),
        (
            "receipt_fixture_present",
            Box::new(|mut p| {
                p.receipt_fixture_present = true;
                p
            }),
        ),
        (
            "receipt_bytes_written",
            Box::new(|mut p| {
                p.receipt_bytes_written = 1;
                p
            }),
        ),
        (
            "receipt_bytes_read",
            Box::new(|mut p| {
                p.receipt_bytes_read = 1;
                p
            }),
        ),
        (
            "raw_path_storage",
            Box::new(|mut p| {
                p.stores_raw_owner_path = true;
                p
            }),
        ),
        (
            "path_canonicalized",
            Box::new(|mut p| {
                p.path_canonicalization_count = 1;
                p
            }),
        ),
        (
            "local_file_opened",
            Box::new(|mut p| {
                p.local_file_open_count = 1;
                p
            }),
        ),
        (
            "local_file_hashed",
            Box::new(|mut p| {
                p.local_file_hash_count = 1;
                p
            }),
        ),
        (
            "sha256_materialized",
            Box::new(|mut p| {
                p.local_file_sha256_materialized = true;
                p
            }),
        ),
        (
            "byte_count_verified",
            Box::new(|mut p| {
                p.byte_count_verified = true;
                p
            }),
        ),
        (
            "llama_cli_version_executed",
            Box::new(|mut p| {
                p.llama_cli_version_executed = true;
                p
            }),
        ),
        (
            "llama_cli_help_executed",
            Box::new(|mut p| {
                p.llama_cli_help_executed = true;
                p
            }),
        ),
        (
            "command_armed",
            Box::new(|mut p| {
                p.command_armed = true;
                p
            }),
        ),
        (
            "command_executed",
            Box::new(|mut p| {
                p.command_executed = true;
                p
            }),
        ),
        (
            "server_started",
            Box::new(|mut p| {
                p.server_started = true;
                p
            }),
        ),
        (
            "network_probe_allowed",
            Box::new(|mut p| {
                p.network_probe_allowed = true;
                p
            }),
        ),
        (
            "model_bytes_loaded",
            Box::new(|mut p| {
                p.model_bytes_loaded = 1;
                p
            }),
        ),
        (
            "runtime_bytes_loaded",
            Box::new(|mut p| {
                p.runtime_bytes_loaded = 1;
                p
            }),
        ),
        (
            "provider_called",
            Box::new(|mut p| {
                p.provider_calls_made = 1;
                p
            }),
        ),
        (
            "runtime_router_mutation",
            Box::new(|mut p| {
                p.runtime_router_mutation_allowed = true;
                p
            }),
        ),
        (
            "system_g_mutation",
            Box::new(|mut p| {
                p.system_g_mutation_allowed = true;
                p
            }),
        ),
        (
            "settings_default_mutation",
            Box::new(|mut p| {
                p.settings_default_mutation_allowed = true;
                p
            }),
        ),
        (
            "hidden_route_authority",
            Box::new(|mut p| {
                p.hidden_route_authority = true;
                p
            }),
        ),
        (
            "hidden_eidos_authority",
            Box::new(|mut p| {
                p.hidden_eidos_authority = true;
                p
            }),
        ),
        (
            "hidden_lattice_authority",
            Box::new(|mut p| {
                p.hidden_lattice_authority = true;
                p
            }),
        ),
        (
            "hidden_patternboost_authority",
            Box::new(|mut p| {
                p.hidden_patternboost_authority = true;
                p
            }),
        ),
        (
            "hidden_cloud_fallback",
            Box::new(|mut p| {
                p.hidden_cloud_fallback = true;
                p
            }),
        ),
        (
            "rollback_missing",
            Box::new(|mut p| {
                p.rollback_ref = "missing".to_string();
                p
            }),
        ),
        (
            "run_event_log_missing",
            Box::new(|mut p| {
                p.run_event_log_ref = "missing".to_string();
                p
            }),
        ),
        (
            "answer_packet_missing",
            Box::new(|mut p| {
                p.answer_packet_ref = "missing".to_string();
                p
            }),
        ),
        (
            "abstention_missing",
            Box::new(|mut p| {
                p.abstention_required = false;
                p
            }),
        ),
        (
            "quality_claim",
            Box::new(|mut p| {
                p.quality_claim = true;
                p
            }),
        ),
        (
            "l2_l3_t4_claim",
            Box::new(|mut p| {
                p.l2_l3_t4_claim = true;
                p
            }),
        ),
        (
            "live_gemma_claim",
            Box::new(|mut p| {
                p.live_gemma_claim = true;
                p
            }),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|mut p| {
                p.live_dense_70b_claim = true;
                p
            }),
        ),
        (
            "ssd_as_ram_claim",
            Box::new(|mut p| {
                p.ssd_as_ram_claim = true;
                p
            }),
        ),
    ];

    fixtures
        .drain(..)
        .map(|(name, mutate)| {
            let candidate = mutate(probe.clone());
            (name, candidate.validate().is_err())
        })
        .collect()
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| *candidate == name)
        .map(|(_, pass)| *pass)
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
    let passed = if expected == "non_empty" {
        !value.is_empty()
    } else {
        value == expected
    };
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
            operator: if expected == "non_empty" { "!=" } else { "==" }.to_string(),
            value: serde_json::Value::String(if expected == "non_empty" {
                "".to_string()
            } else {
                expected.to_string()
            }),
            unit: "text".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), passed);
}

fn assert_axis_coverage(measurements: &BTreeMap<String, Measurement>) {
    for axis in GEMMA_OWNER_APPROVED_LOCAL_ARTIFACT_RECEIPT_PROBE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} for {FALSIFIER_ID}"
        );
    }
}
