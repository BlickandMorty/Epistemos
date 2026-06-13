//! `materialize_release_audit_zero_fail_pass_ledger`.
//!
//! Digest-only ledger for the release-audit zero-fail counter. It consumes the
//! current green automated/log/manual/closeout/distribution-focused/compliance
//! artifacts, records counted passes, and keeps release/Gemma promotion blocked
//! until distribution compliance and three uninterrupted passes are present.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::process::Command;

use agent_core::falsifier_artifacts::axes::RELEASE_AUDIT_ZERO_FAIL_PASS_LEDGER_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, sha256_hex, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-ReleaseAuditZeroFailPassLedger";
const FIXTURE_ID: &str = "release_audit_zero_fail_pass_ledger_v1";
const COMMAND: &str = "Tools/falsifiers/materialize_release_audit_zero_fail_pass_ledger.sh";
const RESULT: &str = "artifacts/falsifiers/release_audit_zero_fail_pass_ledger/result.json";
const REQUIRED_PASS_COUNT: u64 = 3;

const AUTOMATED_CHECKS: &str = "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/result.json";
const LOG_EVIDENCE: &str = "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe/result.json";
const MANUAL_RUNTIME: &str = "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe/result.json";
const CAPABILITY_CLOSEOUT: &str = "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_capability_closeout_probe/result.json";
const DISTRIBUTION_FOCUSED: &str =
    "artifacts/falsifiers/release_audit_distribution_focused_evidence/result.json";
const DISTRIBUTION_COMPLIANCE_REVIEW: &str =
    "artifacts/falsifiers/release_audit_distribution_compliance_review/result.json";

struct ArtifactEvidence {
    path: &'static str,
    id: String,
    overall_pass: bool,
    bytes: u64,
    sha256: String,
}

struct PreviousLedger {
    pass_count: u64,
    pass_signature: String,
    source_state_signature: String,
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
        "{FALSIFIER_ID}: overall_pass={} zero_fail_pass_count={} artifact={RESULT}",
        artifact.overall_pass, artifact.measurements["zero_fail_pass_count"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact() -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, String> {
    let evidence = [
        read_artifact(AUTOMATED_CHECKS)?,
        read_artifact(LOG_EVIDENCE)?,
        read_artifact(MANUAL_RUNTIME)?,
        read_artifact(CAPABILITY_CLOSEOUT)?,
        read_artifact(DISTRIBUTION_FOCUSED)?,
        read_artifact(DISTRIBUTION_COMPLIANCE_REVIEW)?,
    ];
    let all_required_artifacts_passed = evidence.iter().all(|item| item.overall_pass);
    let distribution = evidence
        .iter()
        .find(|item| item.path == DISTRIBUTION_FOCUSED)
        .ok_or_else(|| "missing distribution focused evidence".to_string())?;
    let distribution_compliance = evidence
        .iter()
        .find(|item| item.path == DISTRIBUTION_COMPLIANCE_REVIEW)
        .ok_or_else(|| "missing distribution compliance review evidence".to_string())?;
    let distribution_compliance_not_claimed = measurement_bool(
        &read_json(DISTRIBUTION_FOCUSED)?,
        "distribution_compliance_not_claimed",
    );
    let distribution_compliance_review_passed = measurement_bool(
        &read_json(DISTRIBUTION_COMPLIANCE_REVIEW)?,
        "distribution_compliance_review_passed",
    );
    let ship_call_not_authorized = measurement_bool(
        &read_json(DISTRIBUTION_COMPLIANCE_REVIEW)?,
        "ship_call_not_authorized",
    );
    let gemma_route_not_promoted = measurement_bool(
        &read_json(DISTRIBUTION_COMPLIANCE_REVIEW)?,
        "gemma_route_not_promoted",
    );
    let clean_evidence = all_required_artifacts_passed
        && distribution_compliance_not_claimed
        && distribution_compliance_review_passed
        && ship_call_not_authorized
        && gemma_route_not_promoted;
    let release_ready_claimed = false;
    let pass_signature = sha256_hex(
        evidence
            .iter()
            .flat_map(|item| [item.path.to_string(), item.sha256.clone()])
            .collect::<Vec<_>>()
            .join("|")
            .as_bytes(),
    );
    let source_state_signature = source_state_signature()?;
    let previous_ledger = read_previous_ledger();
    let previous_pass_count = previous_ledger
        .as_ref()
        .map(|ledger| ledger.pass_count)
        .unwrap_or(0);
    let source_state_continuity = previous_ledger
        .as_ref()
        .map(|ledger| ledger.source_state_signature == source_state_signature)
        .unwrap_or(false);
    let continuity_pass_count = if source_state_continuity {
        previous_pass_count
    } else {
        0
    };
    let duplicate_pass_signature = previous_ledger
        .as_ref()
        .map(|ledger| ledger.pass_signature == pass_signature && source_state_continuity)
        .unwrap_or(false);
    let zero_fail_pass_count = if clean_evidence {
        if duplicate_pass_signature {
            continuity_pass_count
        } else {
            continuity_pass_count
                .saturating_add(1)
                .min(REQUIRED_PASS_COUNT)
        }
    } else {
        0
    };
    let remaining_zero_fail_pass_count = REQUIRED_PASS_COUNT.saturating_sub(zero_fail_pass_count);
    let release_completion_still_required =
        !distribution_compliance_review_passed || zero_fail_pass_count < REQUIRED_PASS_COUNT;
    let source_state_change_resets_counter =
        previous_pass_count == 0 || source_state_continuity || continuity_pass_count == 0;
    let duplicate_pass_signature_not_counted =
        !duplicate_pass_signature || zero_fail_pass_count == continuity_pass_count;
    let next_cursor = if !distribution_compliance_review_passed {
        "release_audit_distribution_compliance_review"
    } else if remaining_zero_fail_pass_count == 0 {
        "gemma_product_capability_recheck_after_release_audit"
    } else if remaining_zero_fail_pass_count == 1 {
        "release_audit_distribution_compliance_and_one_remaining_zero_fail_pass"
    } else {
        "release_audit_distribution_compliance_and_two_remaining_zero_fail_passes"
    };

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (axis, passed) in [
        ("all_required_artifacts_present", evidence.len() == 6),
        (
            "all_required_artifacts_passed",
            all_required_artifacts_passed,
        ),
        (
            "automated_checks_artifact_passed",
            evidence
                .iter()
                .any(|item| item.path == AUTOMATED_CHECKS && item.overall_pass),
        ),
        (
            "log_evidence_artifact_passed",
            evidence
                .iter()
                .any(|item| item.path == LOG_EVIDENCE && item.overall_pass),
        ),
        (
            "manual_runtime_artifact_passed",
            evidence
                .iter()
                .any(|item| item.path == MANUAL_RUNTIME && item.overall_pass),
        ),
        (
            "capability_closeout_artifact_passed",
            evidence
                .iter()
                .any(|item| item.path == CAPABILITY_CLOSEOUT && item.overall_pass),
        ),
        (
            "distribution_focused_artifact_passed",
            distribution.overall_pass,
        ),
        (
            "distribution_compliance_review_artifact_passed",
            distribution_compliance.overall_pass,
        ),
        (
            "distribution_compliance_not_claimed",
            distribution_compliance_not_claimed,
        ),
        (
            "distribution_compliance_review_passed",
            distribution_compliance_review_passed,
        ),
        ("ship_call_not_authorized", ship_call_not_authorized),
        ("gemma_route_not_promoted", gemma_route_not_promoted),
        ("release_ready_not_claimed", !release_ready_claimed),
        (
            "source_state_change_resets_counter",
            source_state_change_resets_counter,
        ),
        (
            "duplicate_pass_signature_not_counted",
            duplicate_pass_signature_not_counted,
        ),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            passed,
        );
    }
    insert_bool_fact_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "release_completion_still_required",
        release_completion_still_required,
    );

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "previous_zero_fail_pass_count",
        previous_pass_count,
        ">=",
        0,
        "passes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "zero_fail_pass_count",
        zero_fail_pass_count,
        ">=",
        1,
        "passes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_zero_fail_pass_count",
        REQUIRED_PASS_COUNT,
        "==",
        REQUIRED_PASS_COUNT,
        "passes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "remaining_zero_fail_pass_count",
        remaining_zero_fail_pass_count,
        "<=",
        2,
        "passes",
    );

    for item in &evidence {
        let prefix = artifact_prefix(item.path);
        insert_string_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            &format!("{prefix}_artifact_id"),
            &item.id,
            "id",
        );
        insert_string_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            &format!("{prefix}_artifact_sha256"),
            &item.sha256,
            "sha256",
        );
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            &format!("{prefix}_artifact_bytes"),
            item.bytes,
            ">",
            0,
            "bytes",
        );
    }
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_state_signature",
        &source_state_signature,
        "sha256",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "zero_fail_pass_signature",
        &pass_signature,
        "sha256",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        next_cursor,
        "cursor",
    );

    for axis in RELEASE_AUDIT_ZERO_FAIL_PASS_LEDGER_AXES {
        if !pass_per_axis.contains_key(*axis) {
            return Err(format!("missing canonical axis {axis}"));
        }
    }
    for axis in pass_per_axis.keys() {
        if !RELEASE_AUDIT_ZERO_FAIL_PASS_LEDGER_AXES.contains(&axis.as_str()) {
            return Err(format!("unexpected axis {axis}"));
        }
    }

    let anomalies = vec![serde_json::json!({
        "kind": "release_audit_zero_fail_pass_ledger_not_release_ready",
        "detail": format!(
            "{zero_fail_pass_count}/{REQUIRED_PASS_COUNT} uninterrupted zero-fail evidence sets are counted for this source-state signature. Distribution/compliance review passed={distribution_compliance_review_passed}. Gemma route/default promotion stays blocked until product capability recheck."
        )
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
        notes: "Digest-only release-audit zero-fail pass ledger: counts green automated/log/manual/closeout/distribution-focused/compliance evidence sets only when the source-state signature is stable and the pass signature is fresh; keeps release/Gemma promotion blocked until product capability recheck."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn read_previous_ledger() -> Option<PreviousLedger> {
    let json = read_json(RESULT).ok()?;
    let measurements = json.get("measurements")?;
    let pass_count = measurement_u64_from(measurements, "zero_fail_pass_count")?;
    let pass_signature = measurement_string_from(measurements, "zero_fail_pass_signature")?;
    let source_state_signature = measurement_string_from(measurements, "source_state_signature")?;
    Some(PreviousLedger {
        pass_count,
        pass_signature,
        source_state_signature,
    })
}

fn read_artifact(path: &'static str) -> Result<ArtifactEvidence, String> {
    let bytes = std::fs::read(Path::new(path))
        .map_err(|error| format!("failed to read {path}: {error}"))?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)
        .map_err(|error| format!("failed to parse {path}: {error}"))?;
    let id = json
        .get("falsifier_id")
        .and_then(|value| value.as_str())
        .ok_or_else(|| format!("missing falsifier_id in {path}"))?
        .to_string();
    let overall_pass = json
        .get("overall_pass")
        .and_then(|value| value.as_bool())
        .ok_or_else(|| format!("missing overall_pass in {path}"))?;
    Ok(ArtifactEvidence {
        path,
        id,
        overall_pass,
        bytes: bytes.len() as u64,
        sha256: sha256_hex(&bytes),
    })
}

fn read_json(path: &str) -> Result<serde_json::Value, String> {
    let bytes = std::fs::read(Path::new(path))
        .map_err(|error| format!("failed to read {path}: {error}"))?;
    serde_json::from_slice(&bytes).map_err(|error| format!("failed to parse {path}: {error}"))
}

fn measurement_bool(json: &serde_json::Value, key: &str) -> bool {
    json.get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(|value| value.as_bool())
        .unwrap_or(false)
}

fn measurement_u64_from(measurements: &serde_json::Value, key: &str) -> Option<u64> {
    measurements
        .get(key)
        .and_then(|measurement| measurement.get("value"))
        .and_then(|value| value.as_u64())
}

fn measurement_string_from(measurements: &serde_json::Value, key: &str) -> Option<String> {
    measurements
        .get(key)
        .and_then(|measurement| measurement.get("value"))
        .and_then(|value| value.as_str())
        .map(str::to_string)
}

fn source_state_signature() -> Result<String, String> {
    let output = Command::new("git")
        .args([
            "ls-files",
            "-m",
            "-o",
            "--exclude-standard",
            "--",
            "Epistemos",
            "EpistemosTests",
            "Tools/falsifiers",
            "agent_core/src",
            "docs",
            "project.yml",
            "Epistemos.xcodeproj",
        ])
        .output()
        .map_err(|error| format!("failed to inspect source state: {error}"))?;
    if !output.status.success() {
        return Err(format!(
            "git ls-files source state failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    let mut paths = String::from_utf8(output.stdout)
        .map_err(|error| format!("source state paths are not UTF-8: {error}"))?
        .lines()
        .map(str::to_string)
        .filter(|path| !path.is_empty())
        .collect::<Vec<_>>();
    paths.sort();

    let mut payload = current_commit_sha().into_bytes();
    for path in paths {
        payload.extend_from_slice(b"\0path\0");
        payload.extend_from_slice(path.as_bytes());
        payload.extend_from_slice(b"\0bytes\0");
        let bytes = std::fs::read(Path::new(&path))
            .map_err(|error| format!("failed to read source state path {path}: {error}"))?;
        payload.extend_from_slice(&bytes);
    }

    Ok(sha256_hex(&payload))
}

fn artifact_prefix(path: &str) -> &'static str {
    match path {
        AUTOMATED_CHECKS => "automated_checks",
        LOG_EVIDENCE => "log_evidence",
        MANUAL_RUNTIME => "manual_runtime",
        CAPABILITY_CLOSEOUT => "capability_closeout",
        DISTRIBUTION_FOCUSED => "distribution_focused",
        DISTRIBUTION_COMPLIANCE_REVIEW => "distribution_compliance_review",
        _ => "unknown",
    }
}

fn insert_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: &str,
    unit: &str,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(value),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), true);
}

fn insert_bool_fact_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: bool,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(value),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), true);
}
