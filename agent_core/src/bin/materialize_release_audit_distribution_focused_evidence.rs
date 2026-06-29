//! `materialize_release_audit_distribution_focused_evidence`.
//!
//! Digest-only witness for the focused distribution checks named by
//! `F-DistributionProjectIntegrity-ReleaseBlockerCard`. This consumes local
//! xcodebuild logs after the checks have run, but it does not claim
//! notarization, App Store review, distribution compliance, or ship readiness.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::RELEASE_AUDIT_DISTRIBUTION_FOCUSED_EVIDENCE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, sha256_hex, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-ReleaseAuditDistributionFocusedEvidence";
const FIXTURE_ID: &str = "release_audit_distribution_focused_evidence_v1";
const COMMAND: &str = "Tools/falsifiers/materialize_release_audit_distribution_focused_evidence.sh";
const RESULT: &str = "artifacts/falsifiers/release_audit_distribution_focused_evidence/result.json";
const DEFAULT_APPSTORE_BUILD_LOG: &str = "/tmp/epistemos_appstore_distribution_build.log";
const DEFAULT_DISTRIBUTION_TEST_LOG: &str = "/tmp/epistemos_distribution_focused_tests.log";

struct LogEvidence {
    path: String,
    bytes: u64,
    sha256: String,
    text: String,
}

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
        "{FALSIFIER_ID}: overall_pass={} appstore_build={} distribution_tests={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["appstore_build_succeeded"].value,
        artifact.measurements["distribution_focused_tests_succeeded"].value,
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact() -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, String> {
    let appstore_build = read_log(
        "EPI_RELEASE_AUDIT_APPSTORE_BUILD_LOG",
        DEFAULT_APPSTORE_BUILD_LOG,
    )?;
    let distribution_tests = read_log(
        "EPI_RELEASE_AUDIT_DISTRIBUTION_TEST_LOG",
        DEFAULT_DISTRIBUTION_TEST_LOG,
    )?;

    let appstore_build_succeeded = appstore_build.text.contains("** BUILD SUCCEEDED **");
    let distribution_focused_tests_succeeded =
        distribution_tests.text.contains("** TEST SUCCEEDED **");
    let appstore_hardening_suite_passed = distribution_tests
        .text
        .contains("Suite \"Phase S -- App Store hardening\" passed");
    let release_script_audit_suite_passed = distribution_tests
        .text
        .contains("Suite \"Release Script Audit\" passed");
    let core_mas_boundary_suite_passed = distribution_tests
        .text
        .contains("Suite \"Core/MAS Boundary Source Guard\" passed");
    let expected_test_count_passed = distribution_tests
        .text
        .contains("Test run with 70 tests in 3 suites passed");

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (axis, passed) in [
        ("appstore_build_succeeded", appstore_build_succeeded),
        (
            "distribution_focused_tests_succeeded",
            distribution_focused_tests_succeeded,
        ),
        (
            "appstore_hardening_suite_passed",
            appstore_hardening_suite_passed,
        ),
        (
            "release_script_audit_suite_passed",
            release_script_audit_suite_passed,
        ),
        (
            "core_mas_boundary_suite_passed",
            core_mas_boundary_suite_passed,
        ),
        (
            "expected_distribution_test_count_passed",
            expected_test_count_passed,
        ),
        ("raw_log_content_not_embedded", true),
        ("notarization_or_review_not_claimed", true),
        ("distribution_compliance_not_claimed", true),
        ("ship_call_not_authorized", true),
        ("gemma_route_not_promoted", true),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            passed,
        );
    }

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "appstore_build_log_bytes",
        appstore_build.bytes,
        ">",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "distribution_focused_tests_log_bytes",
        distribution_tests.bytes,
        ">",
        0,
        "bytes",
    );

    for (axis, value, unit) in [
        (
            "appstore_build_log_path",
            appstore_build.path.as_str(),
            "path",
        ),
        (
            "appstore_build_log_sha256",
            appstore_build.sha256.as_str(),
            "sha256",
        ),
        (
            "distribution_focused_tests_log_path",
            distribution_tests.path.as_str(),
            "path",
        ),
        (
            "distribution_focused_tests_log_sha256",
            distribution_tests.sha256.as_str(),
            "sha256",
        ),
        (
            "next_cursor",
            "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes",
            "cursor",
        ),
    ] {
        measurements.insert(
            axis.to_string(),
            Measurement {
                value: serde_json::json!(value),
                unit: unit.to_string(),
            },
        );
        pass_per_axis.insert(axis.to_string(), true);
        thresholds.insert(
            axis.to_string(),
            AcceptanceThreshold {
                operator: "==".to_string(),
                value: serde_json::json!(value),
                unit: unit.to_string(),
            },
        );
    }

    for axis in RELEASE_AUDIT_DISTRIBUTION_FOCUSED_EVIDENCE_AXES {
        if !pass_per_axis.contains_key(*axis) {
            return Err(format!("missing canonical axis {axis}"));
        }
    }
    for axis in pass_per_axis.keys() {
        if !RELEASE_AUDIT_DISTRIBUTION_FOCUSED_EVIDENCE_AXES.contains(&axis.as_str()) {
            return Err(format!("unexpected axis {axis}"));
        }
    }

    let anomalies = vec![serde_json::json!({
        "kind": "release_audit_distribution_focused_evidence_not_ship_authority",
        "detail": "Focused App Store build and distribution source-guard tests passed, but distribution/compliance review, notarization/review, and three uninterrupted zero-fail passes remain unclaimed."
    })];

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
        anomalies,
        notes: "Digest-only focused distribution evidence: proves current App Store scheme build and focused distribution tests passed from local logs; does not claim notarization, App Store review, compliance, Gemma route promotion, or ship readiness."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn read_log(env_key: &str, default_path: &str) -> Result<LogEvidence, String> {
    let path = std::env::var(env_key).unwrap_or_else(|_| default_path.to_string());
    let bytes = std::fs::read(Path::new(&path))
        .map_err(|error| format!("failed to read {path}: {error}"))?;
    let text = String::from_utf8(bytes.clone())
        .map_err(|error| format!("log {path} is not UTF-8: {error}"))?;
    Ok(LogEvidence {
        path,
        bytes: bytes.len() as u64,
        sha256: sha256_hex(&bytes),
        text,
    })
}
