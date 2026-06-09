//! `falsify_gemma_local_artifact_acquisition_plan`
//!
//! Metadata-only acquisition plan for the missing local Gemma artifact step. It
//! reads only the upstream receipt-gate artifact, writes no download receipt,
//! opens no model files, arms no commands, starts no server, and promotes no
//! Gemma route.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaLocalArtifactAcquisitionPlan, GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_ID,
    GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_NEXT_CURSOR,
    GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_ID;
const FIXTURE_ID: &str = "gemma_local_artifact_acquisition_plan_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_local_artifact_acquisition_plan.sh";
const RESULT: &str = "artifacts/falsifiers/gemma_local_artifact_acquisition_plan/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_proof_receipt_gate/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} source_cards={} allowed_modes={} bytes_downloaded={} command_executed={} model_bytes_loaded={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["source_card_count"].value,
        artifact.measurements["allowed_acquisition_mode_count"].value,
        artifact.measurements["bytes_downloaded"].value,
        artifact.measurements["command_executed_count"].value,
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
    let plan = GemmaLocalArtifactAcquisitionPlan::canonical();
    plan.validate()?;
    let reversed = GemmaLocalArtifactAcquisitionPlan {
        required_source_fields: plan.required_source_fields.iter().cloned().rev().collect(),
        required_plan_fields: plan.required_plan_fields.iter().cloned().rev().collect(),
        allowed_acquisition_modes: plan
            .allowed_acquisition_modes
            .iter()
            .cloned()
            .rev()
            .collect(),
        denied_proof_shortcuts: plan.denied_proof_shortcuts.iter().cloned().rev().collect(),
        required_rejection_policies: plan
            .required_rejection_policies
            .iter()
            .cloned()
            .rev()
            .collect(),
        ..plan.clone()
    };
    reversed.validate()?;

    let metrics = plan.metrics();
    let red_results = red_fixture_results(&plan);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_receipt_gate_pass", upstream_pass),
        (
            "upstream_receipt_gate_ref_bound",
            plan.upstream_receipt_gate_ref == GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_UPSTREAM_REF,
        ),
        (
            "source_cards_e2b_e4b_litert12b_bound",
            metrics.source_card_count == 3
                && metrics.total_source_artifact_bytes == 15_052_042_560
                && metrics.max_source_artifact_bytes == 6_547_589_312
                && red_pass(&red_results, "missing_source_card")
                && red_pass(&red_results, "duplicate_source_card")
                && red_pass(&red_results, "wrong_revision")
                && red_pass(&red_results, "wrong_file_size"),
        ),
        (
            "source_plan_and_rejection_fields_bound",
            metrics.required_source_field_count == 11
                && metrics.required_plan_field_count == 15
                && metrics.required_rejection_policy_count == 33
                && red_pass(&red_results, "missing_source_field")
                && red_pass(&red_results, "missing_plan_field")
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "allowed_acquisition_modes_bound",
            metrics.allowed_acquisition_mode_count == 4
                && red_pass(&red_results, "missing_allowed_mode")
                && red_pass(&red_results, "unapproved_acquisition_mode"),
        ),
        (
            "denied_proof_shortcuts_bound",
            metrics.denied_proof_shortcut_count == 10
                && red_pass(&red_results, "missing_denied_shortcut")
                && red_pass(&red_results, "hf_as_proof")
                && red_pass(&red_results, "server_as_proof"),
        ),
        (
            "owner_approval_and_local_artifact_absent",
            plan.owner_approval_required
                && metrics.owner_approval_granted_count == 0
                && metrics.local_artifact_present_count == 0
                && plan.owner_path_manifest_required_after_acquisition
                && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "local_artifact_present")
                && red_pass(&red_results, "owner_manifest_not_required"),
        ),
        (
            "zero_download_file_path_actions",
            metrics.download_started_count == 0
                && metrics.bytes_downloaded == 0
                && metrics.file_open_count == 0
                && metrics.file_hash_count == 0
                && metrics.path_canonicalization_count == 0
                && red_pass(&red_results, "download_started")
                && red_pass(&red_results, "bytes_downloaded")
                && red_pass(&red_results, "file_opened")
                && red_pass(&red_results, "file_hashed")
                && red_pass(&red_results, "path_canonicalized"),
        ),
        (
            "zero_command_process_server_runtime_actions",
            metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.process_spawned_count == 0
                && metrics.server_started_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "server_started")
                && red_pass(&red_results, "model_bytes_loaded"),
        ),
        (
            "rollback_log_packet_abstention_bound",
            plan.rollback_ref.starts_with("rollback:")
                && plan.run_event_log_ref.starts_with("run_event_log:")
                && plan.answer_packet_ref.starts_with("answer_packet:")
                && plan.abstention_required
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
            "gemma_local_artifact_acquisition_plan_address_deterministic",
            plan.address() == GemmaLocalArtifactAcquisitionPlan::canonical().address(),
        ),
        (
            "next_cursor_bound",
            plan.next_cursor == GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_NEXT_CURSOR,
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
            "source_card_count",
            metrics.source_card_count,
            "==",
            3,
            "cards",
        ),
        (
            "required_source_field_count",
            metrics.required_source_field_count,
            "==",
            11,
            "fields",
        ),
        (
            "required_plan_field_count",
            metrics.required_plan_field_count,
            "==",
            15,
            "fields",
        ),
        (
            "allowed_acquisition_mode_count",
            metrics.allowed_acquisition_mode_count,
            "==",
            4,
            "modes",
        ),
        (
            "denied_proof_shortcut_count",
            metrics.denied_proof_shortcut_count,
            "==",
            10,
            "shortcuts",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            33,
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
            "local_artifact_present_count",
            metrics.local_artifact_present_count,
            "==",
            0,
            "artifacts",
        ),
        (
            "download_started_count",
            metrics.download_started_count,
            "==",
            0,
            "downloads",
        ),
        (
            "bytes_downloaded",
            metrics.bytes_downloaded,
            "==",
            0,
            "bytes",
        ),
        ("file_open_count", metrics.file_open_count, "==", 0, "opens"),
        (
            "file_hash_count",
            metrics.file_hash_count,
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
            "total_source_artifact_bytes",
            metrics.total_source_artifact_bytes,
            "==",
            15_052_042_560,
            "bytes",
        ),
        (
            "max_source_artifact_bytes",
            metrics.max_source_artifact_bytes,
            "==",
            6_547_589_312,
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
        "gemma_local_artifact_acquisition_plan_address",
        &plan.address().to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_NEXT_CURSOR,
        GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_NEXT_CURSOR,
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
        notes: "metadata-only F-GemmaLocalArtifactAcquisitionPlan: consumes the landed Gemma first-runtime receipt gate, pins E2B/E4B GGUF and 12B LiteRT source artifacts, requires owner approval and local-file sha256/byte/path manifest after acquisition, starts zero downloads, opens zero files, arms zero commands, starts zero servers, loads zero model/runtime/provider bytes, and makes no Gemma L2/L3/T4/user-facing claim.".to_string(),
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

fn red_fixture_results(plan: &GemmaLocalArtifactAcquisitionPlan) -> Vec<(&'static str, bool)> {
    let mut fixtures: Vec<(
        &'static str,
        Box<dyn Fn(GemmaLocalArtifactAcquisitionPlan) -> GemmaLocalArtifactAcquisitionPlan>,
    )> = vec![
        (
            "missing_source_card",
            Box::new(|mut p| {
                p.source_cards.pop();
                p
            }),
        ),
        (
            "duplicate_source_card",
            Box::new(|mut p| {
                p.source_cards.push(p.source_cards[0].clone());
                p
            }),
        ),
        (
            "wrong_revision",
            Box::new(|mut p| {
                p.source_cards[0].source_revision = "main".to_string();
                p
            }),
        ),
        (
            "wrong_file_size",
            Box::new(|mut p| {
                p.source_cards[1].expected_file_size_bytes = 1;
                p
            }),
        ),
        (
            "missing_source_field",
            Box::new(|mut p| {
                p.required_source_fields.pop();
                p
            }),
        ),
        (
            "missing_plan_field",
            Box::new(|mut p| {
                p.required_plan_fields.pop();
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
            "missing_allowed_mode",
            Box::new(|mut p| {
                p.allowed_acquisition_modes.pop();
                p
            }),
        ),
        (
            "unapproved_acquisition_mode",
            Box::new(|mut p| {
                p.allowed_acquisition_modes
                    .push("auto_download".to_string());
                p
            }),
        ),
        (
            "missing_denied_shortcut",
            Box::new(|mut p| {
                p.denied_proof_shortcuts.pop();
                p
            }),
        ),
        (
            "hf_as_proof",
            Box::new(|mut p| {
                p.denied_proof_shortcuts
                    .retain(|item| item != "llama_cli_hf_as_runtime_proof");
                p
            }),
        ),
        (
            "server_as_proof",
            Box::new(|mut p| {
                p.denied_proof_shortcuts
                    .retain(|item| item != "llama_server_as_product_proof");
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
            "local_artifact_present",
            Box::new(|mut p| {
                p.local_artifact_present = true;
                p
            }),
        ),
        (
            "owner_manifest_not_required",
            Box::new(|mut p| {
                p.owner_path_manifest_required_after_acquisition = false;
                p
            }),
        ),
        (
            "download_started",
            Box::new(|mut p| {
                p.download_started_count = 1;
                p
            }),
        ),
        (
            "bytes_downloaded",
            Box::new(|mut p| {
                p.bytes_downloaded = 1;
                p
            }),
        ),
        (
            "file_opened",
            Box::new(|mut p| {
                p.file_open_count = 1;
                p
            }),
        ),
        (
            "file_hashed",
            Box::new(|mut p| {
                p.file_hash_count = 1;
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
            "model_bytes_loaded",
            Box::new(|mut p| {
                p.model_bytes_loaded = 1;
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
            "hidden_cloud_fallback",
            Box::new(|mut p| {
                p.hidden_cloud_fallback = true;
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
            let candidate = mutate(plan.clone());
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
    for axis in GEMMA_LOCAL_ARTIFACT_ACQUISITION_PLAN_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_builds_with_red_fixtures_rejected() {
        let artifact = build_artifact().expect("artifact should build");
        assert!(artifact.overall_pass);
        assert_eq!(
            artifact.measurements["red_fixture_rejection_count"]
                .value
                .as_u64(),
            Some(38)
        );
    }
}
