//! `falsify_model_vault_catalog_release_blocker_card`.
//!
//! Metadata-only witness binding the model-vault/catalog release-audit family
//! to exact catalog-trust source refs and no-promotion invariants.

use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_model_vault_catalog_invariants, required_model_vault_catalog_source_refs,
    ModelVaultCatalogReleaseBlockerWitness, MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    MODEL_VAULT_CATALOG_UPSTREAM_REF,
};
use std::collections::BTreeMap;

const FALSIFIER_ID: &str = "F-ModelVaultCatalog-ReleaseBlockerCard";
const FIXTURE_ID: &str = "model_vault_catalog_release_blocker_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_model_vault_catalog_release_blocker_card.sh";
const RESULT: &str = "artifacts/falsifiers/model_vault_catalog_release_blocker_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/release_audit_failure_family_source_card/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} issue_count={} source_refs={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["model_vault_catalog_issue_count"].value,
        artifact.measurements["source_ref_count"].value,
    );
    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let upstream = read_upstream()?;
    let witness = ModelVaultCatalogReleaseBlockerWitness::new(
        MODEL_VAULT_CATALOG_UPSTREAM_REF,
        upstream.overall_pass,
        &upstream.next_cursor,
        &upstream.model_vault_family_id,
        upstream.model_vault_issue_count,
    )?;
    witness.validate()?;
    let red_results = red_fixture_results(&witness);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let red_fixture_count = red_results.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_family_source_card_pass", upstream.overall_pass),
        (
            "upstream_next_cursor_model_vault",
            upstream.next_cursor == "model_vault_catalog_release_blocker_card",
        ),
        (
            "model_vault_family_bound",
            witness.card.family_id == "model_vault_catalog",
        ),
        (
            "model_vault_issue_count_retained",
            witness.card.issue_count == upstream.model_vault_issue_count
                && witness.card.issue_count == 9,
        ),
        (
            "source_refs_cover_catalog_surfaces",
            witness.metrics.source_ref_count == required_model_vault_catalog_source_refs().len(),
        ),
        (
            "focused_commands_cover_release_tests",
            witness.metrics.focused_command_count >= 3,
        ),
        (
            "release_invariants_bound",
            witness.metrics.invariant_count == required_model_vault_catalog_invariants().len(),
        ),
        (
            "gemma4_loader_blocked_invariant_bound",
            witness
                .card
                .required_invariants
                .iter()
                .any(|value| value == "gemma4_loader_blocked_from_picker"),
        ),
        (
            "shared_model_vault_targets_builder_bound",
            witness
                .card
                .required_invariants
                .iter()
                .any(|value| value == "shared_model_vault_targets_builder"),
        ),
        (
            "runtime_directory_resolution_bound",
            witness
                .card
                .required_invariants
                .iter()
                .any(|value| value == "runtime_directory_must_resolve_before_request"),
        ),
        (
            "checksum_validation_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Engine/ModelDownloadManager.swift"),
        ),
        (
            "no_catalog_entry_runtime_proof",
            !witness.card.catalog_entry_runtime_proof,
        ),
        (
            "no_model_runtime_bytes",
            witness.metrics.model_runtime_bytes_loaded == 0,
        ),
        (
            "no_hidden_route_authority",
            !witness.card.hidden_route_authority,
        ),
        (
            "no_hidden_cloud_fallback",
            !witness.card.hidden_cloud_fallback,
        ),
        (
            "no_live_dense_70b_claim",
            !witness.card.live_dense_70b_claimed,
        ),
        (
            "no_l2_l3_product_green",
            !witness.card.l2_green_claimed
                && !witness.card.l3_green_claimed
                && !witness.card.product_green_claimed,
        ),
        (
            "rollback_run_event_answer_packet_refs_present",
            !witness.card.rollback_ref.is_empty()
                && !witness.card.run_event_log_ref.is_empty()
                && !witness.card.answer_packet_ref.is_empty(),
        ),
        (
            "next_cursor_bound",
            witness.next_cursor == MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
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

    for (id, passed) in &red_results {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            id,
            *passed,
        );
    }

    for (name, actual, expected, unit) in [
        (
            "model_vault_catalog_issue_count",
            witness.card.issue_count,
            9,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_model_vault_catalog_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            3,
            "commands",
        ),
        (
            "release_invariant_count",
            witness.metrics.invariant_count as u64,
            required_model_vault_catalog_invariants().len() as u64,
            "invariants",
        ),
        (
            "model_runtime_bytes_loaded_total",
            witness.metrics.model_runtime_bytes_loaded,
            0,
            "bytes",
        ),
        (
            "red_fixture_count",
            red_fixture_count,
            red_fixture_count,
            "fixtures",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            red_fixture_count,
            "fixtures",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            actual,
            "==",
            expected,
            unit,
        );
    }

    measurements.insert(
        "model_vault_catalog_release_blocker_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "model_vault_catalog_release_blocker_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "model_vault_catalog_release_blocker_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "model_vault_catalog_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "model_vault_catalog_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("model_vault_catalog_card".to_string(), true);

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(witness.next_cursor),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "eq".to_string(),
            value: serde_json::json!(MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    );

    for axis in MODEL_VAULT_CATALOG_RELEASE_BLOCKER_CARD_AXES {
        measurements
            .entry((*axis).to_string())
            .or_insert(Measurement {
                value: serde_json::json!(false),
                unit: "axis_missing".to_string(),
            });
        thresholds
            .entry((*axis).to_string())
            .or_insert(AcceptanceThreshold {
                operator: "present".to_string(),
                value: serde_json::json!(true),
                unit: "axis_missing".to_string(),
            });
        pass_per_axis.entry((*axis).to_string()).or_insert(false);
    }

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
        notes: "metadata-only F-ModelVaultCatalog-ReleaseBlockerCard: consumes the release-audit failure-family source-card witness, binds model-vault/catalog release blockers to exact source refs, focused tests, catalog honesty invariants, MAS/Pro caveats, rollback, RunEventLog, AnswerPacket, and no-promotion boundaries; opens zero model/runtime/product bytes and makes no L2/L3/product/live-70B claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: model-vault catalog blocker upstream parser.
// Plane: Verification.
// Residency: metadata-only; reads artifact JSON only.
#[derive(Debug)]
struct UpstreamFamilySourceCard {
    overall_pass: bool,
    next_cursor: String,
    model_vault_family_id: String,
    model_vault_issue_count: u64,
}

fn read_upstream() -> Result<UpstreamFamilySourceCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    let cards = json
        .pointer("/measurements/failure_family_cards/value")
        .and_then(serde_json::Value::as_array)
        .ok_or("missing failure_family_cards")?;
    let model_vault = cards
        .iter()
        .find(|card| {
            card.get("family_id").and_then(serde_json::Value::as_str) == Some("model_vault_catalog")
        })
        .ok_or("missing model_vault_catalog family")?;
    Ok(UpstreamFamilySourceCard {
        overall_pass: json
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false),
        next_cursor: json
            .pointer("/measurements/next_cursor/value")
            .and_then(serde_json::Value::as_str)
            .unwrap_or_default()
            .to_string(),
        model_vault_family_id: model_vault
            .get("family_id")
            .and_then(serde_json::Value::as_str)
            .unwrap_or_default()
            .to_string(),
        model_vault_issue_count: model_vault
            .get("issue_count")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0),
    })
}

fn red_fixture_results(witness: &ModelVaultCatalogReleaseBlockerWitness) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "model_vault_catalog_release_blocker_card",
            "model_vault_catalog",
            9,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "agent_route_policy_large_model_no_hidden_authority",
            "model_vault_catalog",
            9,
        ),
        (
            "wrong_family_rejected",
            true,
            "model_vault_catalog_release_blocker_card",
            "agent_route_policy",
            21,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "model_vault_catalog_release_blocker_card",
            "model_vault_catalog",
            0,
        ),
    ] {
        let rejected = ModelVaultCatalogReleaseBlockerWitness::new(
            MODEL_VAULT_CATALOG_UPSTREAM_REF,
            upstream_pass,
            cursor,
            family,
            issues,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add_card = |id: &str,
                    mutate: fn(&mut agent_core::uas::ModelVaultCatalogReleaseBlockerCard),
                    results: &mut Vec<(String, bool)>| {
        let mut card = witness.card.clone();
        mutate(&mut card);
        results.push((id.to_string(), card.validate().is_err()));
    };
    add_card(
        "missing_inference_state_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/State/InferenceState.swift")
        },
        &mut results,
    );
    add_card(
        "missing_gemma4_loader_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "gemma4_loader_blocked_from_picker")
        },
        &mut results,
    );
    add_card(
        "catalog_runtime_proof_claim_rejected",
        |card| card.catalog_entry_runtime_proof = true,
        &mut results,
    );
    add_card(
        "hidden_cloud_fallback_rejected",
        |card| card.hidden_cloud_fallback = true,
        &mut results,
    );
    add_card(
        "hidden_route_authority_rejected",
        |card| card.hidden_route_authority = true,
        &mut results,
    );
    add_card(
        "live_dense_70b_claim_rejected",
        |card| card.live_dense_70b_claimed = true,
        &mut results,
    );
    add_card(
        "l2_l3_product_green_claim_rejected",
        |card| {
            card.l2_green_claimed = true;
            card.l3_green_claimed = true;
            card.product_green_claimed = true;
        },
        &mut results,
    );
    add_card(
        "model_runtime_byte_leak_rejected",
        |card| card.model_runtime_bytes_loaded = 1,
        &mut results,
    );

    results
}
