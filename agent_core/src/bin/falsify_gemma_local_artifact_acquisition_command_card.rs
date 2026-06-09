//! `falsify_gemma_local_artifact_acquisition_command_card`
//!
//! Metadata-only acquisition command cards for Gemma local artifacts. The
//! witness defines owner-approved ways to provide/download/import a model into
//! quarantine, but executes nothing and promotes no runtime route.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaArtifactAcquisitionCommandCardSet, GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_ID,
    GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_NEXT_CURSOR,
    GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_ID;
const FIXTURE_ID: &str = "gemma_local_artifact_acquisition_command_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_local_artifact_acquisition_command_card.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_local_artifact_acquisition_command_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_local_artifact_acquisition_plan/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} command_cards={} command_executed={} download_started={} model_bytes_loaded={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["command_card_count"].value,
        artifact.measurements["command_executed_count"].value,
        artifact.measurements["download_started_count"].value,
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
    let set = GemmaArtifactAcquisitionCommandCardSet::canonical();
    set.validate()?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&set);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_acquisition_plan_pass", upstream_pass),
        (
            "upstream_acquisition_plan_ref_bound",
            set.upstream_plan_ref == GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_UPSTREAM_REF,
        ),
        (
            "command_cards_bound",
            metrics.command_card_count == 4
                && metrics.acquisition_mode_count == 3
                && red_pass(&red_results, "missing_card")
                && red_pass(&red_results, "duplicate_card")
                && red_pass(&red_results, "wrong_model")
                && red_pass(&red_results, "wrong_file_size"),
        ),
        (
            "receipt_fields_shortcuts_and_rejections_bound",
            metrics.required_receipt_field_count == 17
                && metrics.denied_shortcut_count == 10
                && metrics.required_rejection_policy_count == 30
                && red_pass(&red_results, "missing_receipt_field")
                && red_pass(&red_results, "missing_denied_shortcut")
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "owner_approval_pending_and_unarmed",
            metrics.owner_approval_granted_count == 0
                && metrics.command_armed_count == 0
                && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "command_armed"),
        ),
        (
            "zero_download_file_path_actions",
            metrics.download_started_count == 0
                && metrics.file_open_count == 0
                && metrics.file_hash_count == 0
                && metrics.path_canonicalization_count == 0
                && red_pass(&red_results, "download_started")
                && red_pass(&red_results, "file_opened")
                && red_pass(&red_results, "file_hashed")
                && red_pass(&red_results, "path_canonicalized"),
        ),
        (
            "zero_command_process_server_runtime_actions",
            metrics.command_executed_count == 0
                && metrics.server_started_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "server_started")
                && red_pass(&red_results, "model_bytes_loaded"),
        ),
        (
            "privacy_raw_path_denied",
            metrics.raw_path_storage_count == 0 && red_pass(&red_results, "raw_path_storage"),
        ),
        (
            "rollback_log_packet_abstention_bound",
            set.rollback_ref.starts_with("rollback:")
                && set.run_event_log_ref.starts_with("run_event_log:")
                && set.answer_packet_ref.starts_with("answer_packet:")
                && set.abstention_required
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
            "gemma_local_artifact_acquisition_command_card_address_deterministic",
            set.address() == GemmaArtifactAcquisitionCommandCardSet::canonical().address(),
        ),
        (
            "next_cursor_bound",
            set.next_cursor == GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_NEXT_CURSOR,
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
            "command_card_count",
            metrics.command_card_count,
            "==",
            4,
            "cards",
        ),
        (
            "acquisition_mode_count",
            metrics.acquisition_mode_count,
            ">=",
            3,
            "modes",
        ),
        (
            "required_receipt_field_count",
            metrics.required_receipt_field_count,
            "==",
            17,
            "fields",
        ),
        (
            "denied_shortcut_count",
            metrics.denied_shortcut_count,
            "==",
            10,
            "shortcuts",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            30,
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
            "raw_path_storage_count",
            metrics.raw_path_storage_count,
            "==",
            0,
            "paths",
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
            "server_started_count",
            metrics.server_started_count,
            "==",
            0,
            "servers",
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
            "total_planned_artifact_bytes",
            metrics.total_planned_artifact_bytes,
            "==",
            18_401_556_672,
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
        "gemma_local_artifact_acquisition_command_card_address",
        &set.address().to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_NEXT_CURSOR,
        GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_NEXT_CURSOR,
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
        notes: "metadata-only F-GemmaLocalArtifactAcquisitionCommandCard: consumes the landed acquisition plan and freezes four owner-approval-pending acquisition command cards for local file, HF quarantine download, E4B quarantine download, and LiteRT-LM quarantine import. It executes zero commands, starts zero downloads, opens zero files, stores zero raw paths, loads zero model/runtime/provider bytes, and makes no Gemma L2/L3/T4/user-facing claim.".to_string(),
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

fn red_fixture_results(set: &GemmaArtifactAcquisitionCommandCardSet) -> Vec<(&'static str, bool)> {
    let mut fixtures: Vec<(
        &'static str,
        Box<
            dyn Fn(
                GemmaArtifactAcquisitionCommandCardSet,
            ) -> GemmaArtifactAcquisitionCommandCardSet,
        >,
    )> = vec![
        (
            "missing_card",
            Box::new(|mut s| {
                s.cards.pop();
                s
            }),
        ),
        (
            "duplicate_card",
            Box::new(|mut s| {
                s.cards.push(s.cards[0].clone());
                s
            }),
        ),
        (
            "wrong_model",
            Box::new(|mut s| {
                s.cards[0].model_id = "google/gemma-latest".to_string();
                s
            }),
        ),
        (
            "wrong_file_size",
            Box::new(|mut s| {
                s.cards[0].expected_file_size_bytes = 1;
                s
            }),
        ),
        (
            "missing_receipt_field",
            Box::new(|mut s| {
                s.required_receipt_fields.pop();
                s
            }),
        ),
        (
            "missing_denied_shortcut",
            Box::new(|mut s| {
                s.denied_shortcuts.pop();
                s
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|mut s| {
                s.required_rejection_policies.pop();
                s
            }),
        ),
        (
            "owner_approval_granted",
            Box::new(|mut s| {
                s.cards[0].owner_approval_granted = true;
                s
            }),
        ),
        (
            "command_armed",
            Box::new(|mut s| {
                s.cards[0].command_armed = true;
                s
            }),
        ),
        (
            "command_executed",
            Box::new(|mut s| {
                s.cards[0].command_executed = true;
                s
            }),
        ),
        (
            "download_started",
            Box::new(|mut s| {
                s.cards[1].download_started = true;
                s
            }),
        ),
        (
            "file_opened",
            Box::new(|mut s| {
                s.cards[0].file_opened = true;
                s
            }),
        ),
        (
            "file_hashed",
            Box::new(|mut s| {
                s.cards[0].file_hashed = true;
                s
            }),
        ),
        (
            "path_canonicalized",
            Box::new(|mut s| {
                s.cards[0].path_canonicalized = true;
                s
            }),
        ),
        (
            "raw_path_storage",
            Box::new(|mut s| {
                s.cards[0].stores_raw_owner_path = true;
                s
            }),
        ),
        (
            "server_started",
            Box::new(|mut s| {
                s.cards[0].server_started = true;
                s
            }),
        ),
        (
            "model_bytes_loaded",
            Box::new(|mut s| {
                s.cards[0].model_bytes_loaded = 1;
                s
            }),
        ),
        (
            "rollback_missing",
            Box::new(|mut s| {
                s.rollback_ref = "missing".to_string();
                s
            }),
        ),
        (
            "run_event_log_missing",
            Box::new(|mut s| {
                s.run_event_log_ref = "missing".to_string();
                s
            }),
        ),
        (
            "answer_packet_missing",
            Box::new(|mut s| {
                s.answer_packet_ref = "missing".to_string();
                s
            }),
        ),
        (
            "abstention_missing",
            Box::new(|mut s| {
                s.abstention_required = false;
                s
            }),
        ),
        (
            "runtime_router_mutation",
            Box::new(|mut s| {
                s.runtime_router_mutation_allowed = true;
                s
            }),
        ),
        (
            "system_g_mutation",
            Box::new(|mut s| {
                s.system_g_mutation_allowed = true;
                s
            }),
        ),
        (
            "settings_default_mutation",
            Box::new(|mut s| {
                s.settings_default_mutation_allowed = true;
                s
            }),
        ),
        (
            "hidden_route_authority",
            Box::new(|mut s| {
                s.hidden_route_authority = true;
                s
            }),
        ),
        (
            "hidden_cloud_fallback",
            Box::new(|mut s| {
                s.hidden_cloud_fallback = true;
                s
            }),
        ),
        (
            "quality_claim",
            Box::new(|mut s| {
                s.quality_claim = true;
                s
            }),
        ),
        (
            "l2_l3_t4_claim",
            Box::new(|mut s| {
                s.l2_l3_t4_claim = true;
                s
            }),
        ),
        (
            "live_gemma_claim",
            Box::new(|mut s| {
                s.live_gemma_claim = true;
                s
            }),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|mut s| {
                s.live_dense_70b_claim = true;
                s
            }),
        ),
        (
            "ssd_as_ram_claim",
            Box::new(|mut s| {
                s.ssd_as_ram_claim = true;
                s
            }),
        ),
    ];

    fixtures
        .drain(..)
        .map(|(name, mutate)| {
            let candidate = mutate(set.clone());
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
    let missing: Vec<_> = GEMMA_LOCAL_ARTIFACT_ACQUISITION_COMMAND_CARD_AXES
        .iter()
        .filter(|axis| !measurements.contains_key(**axis))
        .copied()
        .collect();
    assert!(missing.is_empty(), "missing axes: {missing:?}");
}
