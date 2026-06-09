//! `falsify_gemma_local_artifact_acquisition_receipt_gate`
//!
//! Metadata-only receipt gate for future Gemma artifact acquisition. It proves
//! the acquisition receipt contract exists while writing no receipt, touching no
//! model file, and promoting no runtime route.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaLocalArtifactAcquisitionReceiptGate, GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_ID,
    GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_NEXT_CURSOR,
    GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_ID;
const FIXTURE_ID: &str = "gemma_local_artifact_acquisition_receipt_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_local_artifact_acquisition_receipt_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_local_artifact_acquisition_receipt_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_local_artifact_acquisition_command_card/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} receipt_fields={} future_receipt_present={} file_hash_count={} model_bytes_loaded={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_receipt_field_count"].value,
        artifact.measurements["future_receipt_present_count"].value,
        artifact.measurements["local_file_hash_count"].value,
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
    let upstream_pass = upstream_gate_pass(UPSTREAM_RESULT)?;
    let gate = GemmaLocalArtifactAcquisitionReceiptGate::canonical();
    gate.validate()?;
    let metrics = gate.metrics();
    let red_results = red_fixture_results(&gate);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_acquisition_command_card_pass", upstream_pass),
        (
            "upstream_acquisition_command_card_ref_bound",
            gate.upstream_command_card_ref
                == GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_UPSTREAM_REF,
        ),
        (
            "receipt_contract_bound",
            metrics.required_receipt_field_count == 24
                && metrics.required_rejection_policy_count == 32
                && red_pass(&red_results, "missing_receipt_field")
                && red_pass(&red_results, "duplicate_receipt_field")
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "selected_card_and_shortcut_policy_bound",
            metrics.allowed_selected_card_count == 4
                && metrics.denied_shortcut_count == 12
                && red_pass(&red_results, "missing_selected_card")
                && red_pass(&red_results, "unknown_selected_card")
                && red_pass(&red_results, "missing_denied_shortcut"),
        ),
        (
            "receipt_deferred_and_owner_approval_absent",
            metrics.owner_approval_granted_count == 0
                && metrics.future_receipt_present_count == 0
                && metrics.future_receipt_bytes_written == 0
                && metrics.future_receipt_bytes_read == 0
                && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "receipt_present")
                && red_pass(&red_results, "receipt_bytes_written"),
        ),
        (
            "zero_local_file_hash_path_actions",
            metrics.local_file_present_count == 0
                && metrics.local_file_open_count == 0
                && metrics.local_file_hash_count == 0
                && metrics.path_canonicalization_count == 0
                && metrics.local_file_sha256_present_count == 0
                && metrics.local_file_byte_count_verified_count == 0
                && red_pass(&red_results, "local_file_present")
                && red_pass(&red_results, "local_file_opened")
                && red_pass(&red_results, "local_file_hashed")
                && red_pass(&red_results, "path_canonicalized"),
        ),
        (
            "zero_command_download_server_runtime_actions",
            metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.download_started_count == 0
                && metrics.server_started_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "download_started")
                && red_pass(&red_results, "server_started")
                && red_pass(&red_results, "model_bytes_loaded"),
        ),
        (
            "privacy_raw_path_denied",
            metrics.raw_path_storage_count == 0 && red_pass(&red_results, "raw_path_storage"),
        ),
        (
            "rollback_log_packet_abstention_bound",
            gate.rollback_ref.starts_with("rollback:")
                && gate.run_event_log_ref.starts_with("run_event_log:")
                && gate.answer_packet_ref.starts_with("answer_packet:")
                && gate.abstention_required
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing"),
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
                && red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "no_quality_l2_l3_t4_gemma_default_70b_or_ssd_claim",
            metrics.promotion_claim_count == 0
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "l2_l3_t4_claim")
                && red_pass(&red_results, "live_gemma_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "gemma_local_artifact_acquisition_receipt_gate_address_deterministic",
            gate.address() == GemmaLocalArtifactAcquisitionReceiptGate::canonical().address(),
        ),
        (
            "next_cursor_bound",
            gate.next_cursor == GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_NEXT_CURSOR,
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
            24,
            "fields",
        ),
        (
            "allowed_selected_card_count",
            metrics.allowed_selected_card_count,
            "==",
            4,
            "cards",
        ),
        (
            "denied_shortcut_count",
            metrics.denied_shortcut_count,
            "==",
            12,
            "shortcuts",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            32,
            "policies",
        ),
        (
            "owner_approval_granted_count",
            metrics.owner_approval_granted_count,
            "==",
            0,
            "approvals",
        ),
        (
            "future_receipt_present_count",
            metrics.future_receipt_present_count,
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
            "raw_path_storage_count",
            metrics.raw_path_storage_count,
            "==",
            0,
            "paths",
        ),
        (
            "local_file_present_count",
            metrics.local_file_present_count,
            "==",
            0,
            "files",
        ),
        (
            "local_file_open_count",
            metrics.local_file_open_count,
            "==",
            0,
            "opens",
        ),
        (
            "local_file_hash_count",
            metrics.local_file_hash_count,
            "==",
            0,
            "hashes",
        ),
        (
            "path_canonicalization_count",
            metrics.path_canonicalization_count,
            "==",
            0,
            "paths",
        ),
        (
            "local_file_sha256_present_count",
            metrics.local_file_sha256_present_count,
            "==",
            0,
            "hashes",
        ),
        (
            "local_file_byte_count_verified_count",
            metrics.local_file_byte_count_verified_count,
            "==",
            0,
            "verifications",
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
            "download_started_count",
            metrics.download_started_count,
            "==",
            0,
            "downloads",
        ),
        (
            "server_started_count",
            metrics.server_started_count,
            "==",
            0,
            "servers",
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
        "gemma_local_artifact_acquisition_receipt_gate_address",
        &gate.address().to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_NEXT_CURSOR,
        GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_NEXT_CURSOR,
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
        notes: "metadata-only F-GemmaLocalArtifactAcquisitionReceiptGate: consumes the Gemma acquisition command cards and freezes the future acquisition receipt contract. It writes zero receipts, reads zero receipts, opens zero local files, computes zero hashes, arms zero commands, starts zero downloads or servers, loads zero model/runtime/provider bytes, stores zero raw owner paths, and makes no Gemma L2/L3/T4/user-facing claim.".to_string(),
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
    gate: &GemmaLocalArtifactAcquisitionReceiptGate,
) -> Vec<(&'static str, bool)> {
    let mut fixtures: Vec<(
        &'static str,
        Box<
            dyn Fn(
                GemmaLocalArtifactAcquisitionReceiptGate,
            ) -> GemmaLocalArtifactAcquisitionReceiptGate,
        >,
    )> = vec![
        (
            "missing_receipt_field",
            Box::new(|mut g| {
                g.required_receipt_fields.pop();
                g
            }),
        ),
        (
            "duplicate_receipt_field",
            Box::new(|mut g| {
                g.required_receipt_fields
                    .push(g.required_receipt_fields[0].clone());
                g
            }),
        ),
        (
            "missing_selected_card",
            Box::new(|mut g| {
                g.allowed_selected_card_ids.pop();
                g
            }),
        ),
        (
            "unknown_selected_card",
            Box::new(|mut g| {
                g.allowed_selected_card_ids[0] = "gemma-latest".to_string();
                g
            }),
        ),
        (
            "missing_denied_shortcut",
            Box::new(|mut g| {
                g.denied_shortcuts.pop();
                g
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|mut g| {
                g.required_rejection_policies.pop();
                g
            }),
        ),
        (
            "owner_approval_granted",
            Box::new(|mut g| {
                g.owner_approval_granted = true;
                g
            }),
        ),
        (
            "receipt_present",
            Box::new(|mut g| {
                g.future_receipt_present = true;
                g
            }),
        ),
        (
            "receipt_bytes_written",
            Box::new(|mut g| {
                g.future_receipt_bytes_written = 1;
                g
            }),
        ),
        (
            "receipt_bytes_read",
            Box::new(|mut g| {
                g.future_receipt_bytes_read = 1;
                g
            }),
        ),
        (
            "raw_path_storage",
            Box::new(|mut g| {
                g.stores_raw_owner_path = true;
                g
            }),
        ),
        (
            "local_file_present",
            Box::new(|mut g| {
                g.local_file_present = true;
                g
            }),
        ),
        (
            "local_file_opened",
            Box::new(|mut g| {
                g.local_file_open_count = 1;
                g
            }),
        ),
        (
            "local_file_hashed",
            Box::new(|mut g| {
                g.local_file_hash_count = 1;
                g
            }),
        ),
        (
            "path_canonicalized",
            Box::new(|mut g| {
                g.path_canonicalization_count = 1;
                g
            }),
        ),
        (
            "sha256_present",
            Box::new(|mut g| {
                g.local_file_sha256_present = true;
                g
            }),
        ),
        (
            "byte_count_verified",
            Box::new(|mut g| {
                g.local_file_byte_count_verified = true;
                g
            }),
        ),
        (
            "command_armed",
            Box::new(|mut g| {
                g.command_armed = true;
                g
            }),
        ),
        (
            "command_executed",
            Box::new(|mut g| {
                g.command_executed = true;
                g
            }),
        ),
        (
            "download_started",
            Box::new(|mut g| {
                g.download_started_count = 1;
                g
            }),
        ),
        (
            "server_started",
            Box::new(|mut g| {
                g.server_started = true;
                g
            }),
        ),
        (
            "model_bytes_loaded",
            Box::new(|mut g| {
                g.model_bytes_loaded = 1;
                g
            }),
        ),
        (
            "rollback_missing",
            Box::new(|mut g| {
                g.rollback_ref = "missing".to_string();
                g
            }),
        ),
        (
            "run_event_log_missing",
            Box::new(|mut g| {
                g.run_event_log_ref = "missing".to_string();
                g
            }),
        ),
        (
            "answer_packet_missing",
            Box::new(|mut g| {
                g.answer_packet_ref = "missing".to_string();
                g
            }),
        ),
        (
            "abstention_missing",
            Box::new(|mut g| {
                g.abstention_required = false;
                g
            }),
        ),
        (
            "runtime_router_mutation",
            Box::new(|mut g| {
                g.runtime_router_mutation_allowed = true;
                g
            }),
        ),
        (
            "system_g_mutation",
            Box::new(|mut g| {
                g.system_g_mutation_allowed = true;
                g
            }),
        ),
        (
            "settings_default_mutation",
            Box::new(|mut g| {
                g.settings_default_mutation_allowed = true;
                g
            }),
        ),
        (
            "hidden_route_authority",
            Box::new(|mut g| {
                g.hidden_route_authority = true;
                g
            }),
        ),
        (
            "hidden_cloud_fallback",
            Box::new(|mut g| {
                g.hidden_cloud_fallback = true;
                g
            }),
        ),
        (
            "quality_claim",
            Box::new(|mut g| {
                g.quality_claim = true;
                g
            }),
        ),
        (
            "l2_l3_t4_claim",
            Box::new(|mut g| {
                g.l2_l3_t4_claim = true;
                g
            }),
        ),
        (
            "live_gemma_claim",
            Box::new(|mut g| {
                g.live_gemma_claim = true;
                g
            }),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|mut g| {
                g.live_dense_70b_claim = true;
                g
            }),
        ),
        (
            "ssd_as_ram_claim",
            Box::new(|mut g| {
                g.ssd_as_ram_claim = true;
                g
            }),
        ),
    ];

    fixtures
        .drain(..)
        .map(|(name, mutate)| {
            let candidate = mutate(gate.clone());
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
    let missing: Vec<_> = GEMMA_LOCAL_ARTIFACT_ACQUISITION_RECEIPT_GATE_AXES
        .iter()
        .filter(|axis| !measurements.contains_key(**axis))
        .copied()
        .collect();
    assert!(missing.is_empty(), "missing axes: {missing:?}");
}
