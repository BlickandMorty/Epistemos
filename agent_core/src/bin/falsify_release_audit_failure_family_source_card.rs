//! `falsify_release_audit_failure_family_source_card`.
//!
//! Metadata-only source-card witness for retained release-audit failure
//! families. It consumes the red automated-checks artifact and makes each
//! xcode failure family addressable without claiming product readiness.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_release_audit_failure_families, ReleaseAuditFailureFamilySourceCardWitness,
    RELEASE_AUDIT_AUTOMATED_CHECKS_UPSTREAM_REF,
    RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-ReleaseAuditFailureFamily-SourceCard";
const FIXTURE_ID: &str = "release_audit_failure_family_source_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_release_audit_failure_family_source_card.sh";
const RESULT: &str = "artifacts/falsifiers/release_audit_failure_family_source_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} family_count={} issue_count={} top_family={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["failure_family_count"].value,
        artifact.measurements["total_issue_count"].value,
        artifact.measurements["top_failure_family"].value
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
    let witness = ReleaseAuditFailureFamilySourceCardWitness::new(
        RELEASE_AUDIT_AUTOMATED_CHECKS_UPSTREAM_REF,
        upstream.overall_pass,
        upstream.failed_check_count,
        upstream.unique_failure_count,
        &upstream.family_counts,
    )?;
    witness.validate()?;
    let red_results = red_fixture_results(&witness, &upstream.family_counts);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let red_fixture_count = red_results.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        (
            "upstream_automated_checks_artifact_present",
            upstream.artifact_present,
        ),
        ("upstream_automated_checks_red", !upstream.overall_pass),
        (
            "upstream_failed_xcodebuild_test_bound",
            upstream.failed_check_count == 1 && upstream.xcodebuild_test_passed == Some(false),
        ),
        (
            "all_failure_families_carded",
            witness.metrics.family_count == required_release_audit_failure_families().len(),
        ),
        (
            "top_family_graph_filter_visibility",
            witness.metrics.top_family_id == "graph_filter_visibility",
        ),
        (
            "total_issue_count_matches_upstream",
            witness.metrics.total_issue_count == upstream.issue_count,
        ),
        (
            "family_cards_are_promotion_blockers",
            witness.metrics.promotion_blocker_count == witness.metrics.family_count,
        ),
        (
            "source_refs_bound",
            witness.metrics.source_ref_count >= witness.metrics.family_count,
        ),
        (
            "focused_commands_bound",
            witness.metrics.focused_command_count >= witness.metrics.family_count,
        ),
        (
            "model_vault_catalog_family_present",
            witness
                .cards
                .iter()
                .any(|card| card.family_id == "model_vault_catalog"),
        ),
        (
            "agent_route_policy_family_present",
            witness
                .cards
                .iter()
                .any(|card| card.family_id == "agent_route_policy"),
        ),
        (
            "graph_filter_visibility_family_present",
            witness
                .cards
                .iter()
                .any(|card| card.family_id == "graph_filter_visibility"),
        ),
        (
            "zero_model_runtime_bytes",
            witness.metrics.model_runtime_bytes_loaded == 0,
        ),
        ("no_product_promotion", witness.no_product_promotion),
        (
            "next_cursor_bound",
            witness.next_cursor == RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_NEXT_CURSOR,
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
            "failure_family_count",
            witness.metrics.family_count as u64,
            15,
            "families",
        ),
        (
            "total_issue_count",
            witness.metrics.total_issue_count,
            upstream.issue_count,
            "issues",
        ),
        (
            "unique_failure_count",
            upstream.unique_failure_count,
            upstream.unique_failure_count,
            "tests",
        ),
        (
            "failed_check_count",
            upstream.failed_check_count,
            1,
            "checks",
        ),
        (
            "promotion_blocker_count",
            witness.metrics.promotion_blocker_count as u64,
            15,
            "cards",
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
        "top_failure_family".to_string(),
        Measurement {
            value: serde_json::json!(witness.metrics.top_family_id),
            unit: "family".to_string(),
        },
    );
    thresholds.insert(
        "top_failure_family".to_string(),
        AcceptanceThreshold {
            operator: "eq".to_string(),
            value: serde_json::json!("graph_filter_visibility"),
            unit: "family".to_string(),
        },
    );
    pass_per_axis.insert(
        "top_failure_family".to_string(),
        witness.metrics.top_family_id == "graph_filter_visibility",
    );

    measurements.insert(
        "release_audit_failure_family_source_card_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "release_audit_failure_family_source_card_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "release_audit_failure_family_source_card_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "failure_family_cards".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.cards)?,
            unit: "cards".to_string(),
        },
    );
    thresholds.insert(
        "failure_family_cards".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "cards".to_string(),
        },
    );
    pass_per_axis.insert(
        "failure_family_cards".to_string(),
        !witness.cards.is_empty(),
    );

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
            value: serde_json::json!(RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_NEXT_CURSOR,
    );

    for axis in RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_AXES {
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
        notes: "metadata-only F-ReleaseAuditFailureFamily-SourceCard: consumes the retained red automated-checks artifact, turns 15 xcode failure families into typed source cards with organs/source refs/focused commands/falsifier backlog, keeps model/runtime bytes at zero, and makes no product, L2, L3, MAS, live-70B, or release-readiness claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: retained automated-checks RED ledger parser for failure-family source cards.
// Plane: Verification.
// Residency: metadata-only; reads artifact JSON only, no product/model/runtime bytes.
#[derive(Debug)]
struct UpstreamAutomatedChecks {
    artifact_present: bool,
    overall_pass: bool,
    failed_check_count: u64,
    issue_count: u64,
    unique_failure_count: u64,
    xcodebuild_test_passed: Option<bool>,
    family_counts: BTreeMap<String, u64>,
}

fn read_upstream() -> Result<UpstreamAutomatedChecks, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    let family_counts = json
        .pointer("/measurements/xcodebuild_test_failure_families/value")
        .and_then(serde_json::Value::as_object)
        .ok_or("missing family counts")?
        .iter()
        .map(|(key, value)| {
            value
                .as_u64()
                .map(|count| (key.clone(), count))
                .ok_or_else(|| format!("bad count for {key}"))
        })
        .collect::<Result<BTreeMap<_, _>, _>>()?;
    Ok(UpstreamAutomatedChecks {
        artifact_present: true,
        overall_pass: json
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false),
        failed_check_count: json
            .pointer("/measurements/failed_check_count/value")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0),
        issue_count: json
            .pointer("/measurements/xcodebuild_test_issue_count/value")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0),
        unique_failure_count: json
            .pointer("/measurements/xcodebuild_test_unique_failure_count/value")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0),
        xcodebuild_test_passed: json
            .pointer("/measurements/xcodebuild_test_passed/value")
            .and_then(serde_json::Value::as_bool),
        family_counts,
    })
}

fn red_fixture_results(
    witness: &ReleaseAuditFailureFamilySourceCardWitness,
    family_counts: &BTreeMap<String, u64>,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    let add_counts =
        |id: &str, mutate: fn(&mut BTreeMap<String, u64>), results: &mut Vec<(String, bool)>| {
            let mut counts = family_counts.clone();
            mutate(&mut counts);
            let rejected = ReleaseAuditFailureFamilySourceCardWitness::new(
                RELEASE_AUDIT_AUTOMATED_CHECKS_UPSTREAM_REF,
                false,
                1,
                84,
                &counts,
            )
            .is_err();
            results.push((id.to_string(), rejected));
        };
    add_counts(
        "missing_graph_filter_visibility_family_rejected",
        |counts| {
            counts.remove("graph_filter_visibility");
        },
        &mut results,
    );
    add_counts(
        "unknown_failure_family_rejected",
        |counts| {
            counts.insert("unknown_local_model_magic".to_string(), 1);
        },
        &mut results,
    );
    add_counts(
        "zero_issue_family_rejected",
        |counts| {
            counts.insert("agent_route_policy".to_string(), 0);
        },
        &mut results,
    );

    for (id, upstream_pass, failed_count, unique_count) in [
        ("green_upstream_rejected", true, 0, 0),
        ("zero_failed_check_rejected", false, 0, 84),
        ("zero_unique_failures_rejected", false, 1, 0),
    ] {
        let rejected = ReleaseAuditFailureFamilySourceCardWitness::new(
            RELEASE_AUDIT_AUTOMATED_CHECKS_UPSTREAM_REF,
            upstream_pass,
            failed_count,
            unique_count,
            family_counts,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let mut promoted = witness.clone();
    promoted.cards[0].l3_green_claimed = true;
    results.push((
        "l3_green_claim_rejected".to_string(),
        promoted.cards[0].validate().is_err(),
    ));

    let mut byte_leak = witness.clone();
    byte_leak.cards[0].model_runtime_bytes_loaded = 1;
    results.push((
        "model_runtime_byte_leak_rejected".to_string(),
        byte_leak.cards[0].validate().is_err(),
    ));

    let mut hidden = witness.clone();
    hidden.cards[0].hidden_authority_claimed = true;
    results.push((
        "hidden_authority_claim_rejected".to_string(),
        hidden.cards[0].validate().is_err(),
    ));

    results
}
