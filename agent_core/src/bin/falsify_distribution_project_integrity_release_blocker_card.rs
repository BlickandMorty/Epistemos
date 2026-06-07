//! `falsify_distribution_project_integrity_release_blocker_card`.
//!
//! Metadata-only witness that binds retained project/distribution release
//! blockers to exact project, scheme, entitlement, privacy, and release-test
//! surfaces without granting archive, signing, MAS, L2, L3, or product proof.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_distribution_project_integrity_invariants,
    required_distribution_project_integrity_source_refs,
    DistributionProjectIntegrityReleaseBlockerWitness,
    DISTRIBUTION_PROJECT_INTEGRITY_FAMILY_SOURCE_REF,
    DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    DISTRIBUTION_PROJECT_INTEGRITY_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-DistributionProjectIntegrity-ReleaseBlockerCard";
const FIXTURE_ID: &str = "distribution_project_integrity_release_blocker_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_distribution_project_integrity_release_blocker_card.sh";
const RESULT: &str =
    "artifacts/falsifiers/distribution_project_integrity_release_blocker_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/theme_presentation_release_blocker_card/result.json";
const FAMILY_SOURCE_RESULT: &str =
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
        artifact.measurements["distribution_project_integrity_issue_count"].value,
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
    let family = read_family_source()?;
    let witness = DistributionProjectIntegrityReleaseBlockerWitness::new(
        DISTRIBUTION_PROJECT_INTEGRITY_UPSTREAM_REF,
        DISTRIBUTION_PROJECT_INTEGRITY_FAMILY_SOURCE_REF,
        upstream.overall_pass,
        &upstream.next_cursor,
        &family.family_id,
        family.issue_count,
    )?;
    witness.validate()?;
    let red_results = red_fixture_results(&witness);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let red_fixture_count = red_results.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        (
            "upstream_theme_presentation_card_pass",
            upstream.overall_pass,
        ),
        (
            "upstream_next_cursor_distribution_project_integrity",
            upstream.next_cursor == "distribution_project_integrity_release_blocker_card",
        ),
        (
            "distribution_project_integrity_family_bound",
            witness.card.family_id == "distribution_project_integrity",
        ),
        (
            "distribution_project_integrity_issue_count_retained",
            witness.card.issue_count == family.issue_count && witness.card.issue_count == 18,
        ),
        (
            "source_refs_cover_distribution_surfaces",
            witness.metrics.source_ref_count
                == required_distribution_project_integrity_source_refs().len(),
        ),
        (
            "focused_commands_cover_build_and_distribution_tests",
            witness.metrics.focused_command_count >= 5,
        ),
        (
            "distribution_invariants_bound",
            witness.metrics.invariant_count
                == required_distribution_project_integrity_invariants().len(),
        ),
        (
            "project_yml_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "project.yml"),
        ),
        (
            "appstore_entitlements_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Epistemos-AppStore.entitlements"),
        ),
        (
            "appstore_hardening_tests_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "EpistemosTests/AppStoreHardeningTests.swift"),
        ),
        (
            "no_project_build_as_release_proof",
            !witness.card.project_build_as_release_proof,
        ),
        (
            "no_archive_codesign_notary_review_claim",
            !witness.card.app_store_archive_claimed
                && !witness.card.distribution_codesign_claimed
                && !witness.card.notarization_or_review_claimed,
        ),
        (
            "xcodegen_drift_not_ignored",
            !witness.card.xcodegen_drift_ignored,
        ),
        (
            "mas_pro_entitlements_separated",
            !witness.card.mas_entitlements_include_pro_tools
                && !witness.card.pro_entitlements_marketed_as_mas,
        ),
        (
            "privacy_manifest_bound",
            !witness.card.privacy_manifest_missing,
        ),
        (
            "scheme_mismatch_not_ignored",
            !witness.card.scheme_mismatch_ignored,
        ),
        (
            "local_model_catalog_not_distribution_proof",
            !witness.card.local_model_catalog_as_distribution_proof,
        ),
        (
            "release_script_logs_required",
            !witness.card.release_script_log_hidden,
        ),
        (
            "no_hidden_route_or_cloud_authority",
            !witness.card.hidden_route_authority && !witness.card.hidden_cloud_fallback,
        ),
        (
            "no_l2_l3_product_green",
            !witness.card.l2_green_claimed
                && !witness.card.l3_green_claimed
                && !witness.card.product_green_claimed,
        ),
        (
            "no_live_dense_70b_claim",
            !witness.card.live_dense_70b_claimed,
        ),
        (
            "no_archive_model_bytes_or_provider_calls",
            witness.metrics.archive_bytes_loaded == 0
                && witness.metrics.model_runtime_bytes_loaded == 0
                && witness.metrics.provider_calls_made == 0,
        ),
        (
            "rollback_run_event_answer_packet_refs_present",
            !witness.card.rollback_ref.is_empty()
                && !witness.card.run_event_log_ref.is_empty()
                && !witness.card.answer_packet_ref.is_empty(),
        ),
        (
            "next_cursor_bound",
            witness.next_cursor == DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
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
            "distribution_project_integrity_issue_count",
            witness.card.issue_count,
            18,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_distribution_project_integrity_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            5,
            "commands",
        ),
        (
            "distribution_invariant_count",
            witness.metrics.invariant_count as u64,
            required_distribution_project_integrity_invariants().len() as u64,
            "invariants",
        ),
        (
            "archive_bytes_loaded_total",
            witness.metrics.archive_bytes_loaded,
            0,
            "bytes",
        ),
        (
            "model_runtime_bytes_loaded_total",
            witness.metrics.model_runtime_bytes_loaded,
            0,
            "bytes",
        ),
        (
            "provider_calls_made_total",
            witness.metrics.provider_calls_made,
            0,
            "calls",
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
        "distribution_project_integrity_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "distribution_project_integrity_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "distribution_project_integrity_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "distribution_project_integrity_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "distribution_project_integrity_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("distribution_project_integrity_card".to_string(), true);

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
            value: serde_json::json!(
                DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    );

    for axis in DISTRIBUTION_PROJECT_INTEGRITY_RELEASE_BLOCKER_CARD_AXES {
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
        notes: "metadata-only F-DistributionProjectIntegrity-ReleaseBlockerCard: consumes the theme/presentation blocker and release-audit family source card, binds distribution_project_integrity issue count 18 to project.yml, xcodeproj, schemes, plist, entitlements, privacy manifest, MAS/Pro source guard, and release tests, and rejects build-as-release-proof, archive/codesign/notary/review claims, xcodegen drift laundering, MAS/Pro entitlement collapse, local model catalog as distribution proof, hidden logs, hidden authority, L2/L3/product green, provider calls, and live dense-70B claims.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:distribution-project-integrity-release-blocker-card:upstream-parser
// Plane: Verification.
// Residency: metadata-only; reads artifact JSON only.
#[derive(Debug)]
struct UpstreamThemePresentationCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamThemePresentationCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamThemePresentationCard {
        overall_pass: json
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false),
        next_cursor: json
            .pointer("/measurements/next_cursor/value")
            .and_then(serde_json::Value::as_str)
            .unwrap_or_default()
            .to_string(),
    })
}

// UAS: uas:distribution-project-integrity-release-blocker-card:family-parser
// Plane: Verification.
// Residency: metadata-only; reads retained failure-family JSON only.
#[derive(Debug)]
struct FamilySourceCard {
    family_id: String,
    issue_count: u64,
}

fn read_family_source() -> Result<FamilySourceCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(FAMILY_SOURCE_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    let cards = json
        .pointer("/measurements/failure_family_cards/value")
        .and_then(serde_json::Value::as_array)
        .ok_or("missing failure_family_cards")?;
    let family = cards
        .iter()
        .find(|card| {
            card.get("family_id").and_then(serde_json::Value::as_str)
                == Some("distribution_project_integrity")
        })
        .ok_or("missing distribution_project_integrity family")?;
    Ok(FamilySourceCard {
        family_id: family
            .get("family_id")
            .and_then(serde_json::Value::as_str)
            .unwrap_or_default()
            .to_string(),
        issue_count: family
            .get("issue_count")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0),
    })
}

fn red_fixture_results(
    witness: &DistributionProjectIntegrityReleaseBlockerWitness,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "distribution_project_integrity_release_blocker_card",
            "distribution_project_integrity",
            18,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "theme_presentation_release_blocker_card",
            "distribution_project_integrity",
            18,
        ),
        (
            "wrong_family_rejected",
            true,
            "distribution_project_integrity_release_blocker_card",
            "theme_presentation",
            19,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "distribution_project_integrity_release_blocker_card",
            "distribution_project_integrity",
            0,
        ),
    ] {
        let rejected = DistributionProjectIntegrityReleaseBlockerWitness::new(
            DISTRIBUTION_PROJECT_INTEGRITY_UPSTREAM_REF,
            DISTRIBUTION_PROJECT_INTEGRITY_FAMILY_SOURCE_REF,
            upstream_pass,
            cursor,
            family,
            issues,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add_card =
        |id: &str,
         mutate: fn(&mut agent_core::uas::DistributionProjectIntegrityReleaseBlockerCard),
         results: &mut Vec<(String, bool)>| {
            let mut card = witness.card.clone();
            mutate(&mut card);
            results.push((id.to_string(), card.validate().is_err()));
        };
    add_card(
        "missing_project_yml_source_rejected",
        |card| card.source_refs.retain(|value| value != "project.yml"),
        &mut results,
    );
    add_card(
        "missing_appstore_entitlements_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Epistemos-AppStore.entitlements")
        },
        &mut results,
    );
    add_card(
        "missing_xcodegen_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "project_yml_is_xcodegen_source_of_truth")
        },
        &mut results,
    );
    add_card(
        "missing_archive_review_invariant_rejected",
        |card| {
            card.required_invariants.retain(|value| {
                value != "archive_codesign_notary_and_review_are_required_for_green"
            })
        },
        &mut results,
    );
    add_card(
        "build_as_release_proof_rejected",
        |card| card.project_build_as_release_proof = true,
        &mut results,
    );
    add_card(
        "appstore_archive_claim_rejected",
        |card| card.app_store_archive_claimed = true,
        &mut results,
    );
    add_card(
        "distribution_codesign_claim_rejected",
        |card| card.distribution_codesign_claimed = true,
        &mut results,
    );
    add_card(
        "notary_review_claim_rejected",
        |card| card.notarization_or_review_claimed = true,
        &mut results,
    );
    add_card(
        "xcodegen_drift_ignored_rejected",
        |card| card.xcodegen_drift_ignored = true,
        &mut results,
    );
    add_card(
        "mas_entitlements_pro_tool_rejected",
        |card| card.mas_entitlements_include_pro_tools = true,
        &mut results,
    );
    add_card(
        "pro_entitlements_as_mas_rejected",
        |card| card.pro_entitlements_marketed_as_mas = true,
        &mut results,
    );
    add_card(
        "privacy_manifest_missing_rejected",
        |card| card.privacy_manifest_missing = true,
        &mut results,
    );
    add_card(
        "scheme_mismatch_ignored_rejected",
        |card| card.scheme_mismatch_ignored = true,
        &mut results,
    );
    add_card(
        "local_model_catalog_distribution_proof_rejected",
        |card| card.local_model_catalog_as_distribution_proof = true,
        &mut results,
    );
    add_card(
        "release_script_log_hidden_rejected",
        |card| card.release_script_log_hidden = true,
        &mut results,
    );
    add_card(
        "hidden_route_cloud_authority_rejected",
        |card| {
            card.hidden_route_authority = true;
            card.hidden_cloud_fallback = true;
        },
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
        "live_dense_70b_claim_rejected",
        |card| card.live_dense_70b_claimed = true,
        &mut results,
    );
    add_card(
        "archive_byte_leak_rejected",
        |card| card.archive_bytes_loaded = 1,
        &mut results,
    );
    add_card(
        "model_runtime_byte_leak_rejected",
        |card| card.model_runtime_bytes_loaded = 1,
        &mut results,
    );
    add_card(
        "provider_call_leak_rejected",
        |card| card.provider_calls_made = 1,
        &mut results,
    );

    results
}
