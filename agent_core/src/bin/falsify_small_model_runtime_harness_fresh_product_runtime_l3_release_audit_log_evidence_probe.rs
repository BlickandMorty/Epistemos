//! `falsify_small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe`.
//!
//! Metadata-only retained log-evidence probe for the fresh product-runtime L3
//! release-audit path. This consumes the red automated-checks artifact and
//! binds checks.tsv plus log digests without rerunning Xcode, reading model
//! bytes, embedding raw log payloads, or promoting product capability.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_PROBE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    sha256_hex, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier,
    Measurement,
};
use agent_core::uas::{
    required_fresh_product_runtime_l3_release_audit_log_evidence_checks,
    required_fresh_product_runtime_l3_release_audit_log_evidence_phases,
    required_fresh_product_runtime_l3_release_audit_log_evidence_rejection_policies,
    SmallModelReleaseAuditLogDigest, SmallModelReleaseAuditLogEvidenceProbe,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_CHECKS_TSV,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_PROBE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str =
    "F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditLogEvidenceProbe";
const FIXTURE_ID: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/result.json";
const ZERO: u64 = 0;

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
        "{FALSIFIER_ID}: overall_pass={} failed_checks={} top_family={} next_cursor={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["failed_check_count"].value,
        artifact.measurements["top_xcodebuild_test_failure_family"].value,
        artifact.measurements["next_cursor"].value,
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
    let log_digests = read_check_logs()?;
    let witness = SmallModelReleaseAuditLogEvidenceProbe::canonical(
        upstream.address.clone(),
        log_digests,
        upstream.failed_check_count,
        upstream.xcodebuild_test_issue_count,
        upstream.xcodebuild_test_unique_failure_count,
        upstream.top_xcodebuild_test_failure_family,
    );
    witness.validate()?;
    let red_results = red_fixture_results(&witness);
    let red_fixture_count = red_results.len() as u64;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (axis, pass) in [
        ("upstream_automated_checks_artifact_present", true),
        ("upstream_automated_checks_red_bound", !upstream.overall_pass),
        (
            "upstream_automated_checks_address_bound",
            witness.upstream_artifact_address == upstream.address
                && witness.upstream_artifact_address.starts_with("sha256:"),
        ),
        (
            "checks_tsv_bound",
            witness.checks_tsv_ref
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_CHECKS_TSV,
        ),
        (
            "required_check_ids_bound",
            witness.required_check_ids.len()
                == required_fresh_product_runtime_l3_release_audit_log_evidence_checks().len(),
        ),
        (
            "five_command_logs_digest_bound",
            witness.log_digests.len()
                == required_fresh_product_runtime_l3_release_audit_log_evidence_checks().len()
                && witness
                    .log_digests
                    .iter()
                    .all(|digest| digest.bytes > 0 && digest.sha256.starts_with("sha256:")),
        ),
        (
            "xcodebuild_test_failure_family_bound",
            witness.top_xcodebuild_test_failure_family == "graph_filter_visibility",
        ),
        (
            "red_failure_counts_bound",
            witness.failed_check_count == 1
                && witness.xcodebuild_test_issue_count > 0
                && witness.xcodebuild_test_unique_failure_count > 0,
        ),
        (
            "runtime_oslog_evidence_pending",
            witness.runtime_oslog_entries_bound == 0 && !witness.runtime_log_evidence_present,
        ),
        (
            "answer_packet_runtime_correlation_pending",
            !witness.answer_packet_runtime_correlation_present,
        ),
        (
            "manual_distribution_three_pass_blockers_preserved",
            !witness.manual_runtime_evidence_present
                && !witness.distribution_compliance_evidence_present
                && witness.zero_fail_pass_count == 0,
        ),
        (
            "no_l2_l3_product_release_green",
            !witness.l2_green_claimed
                && !witness.l3_green_claimed
                && !witness.product_green_claimed
                && !witness.release_ready_claimed,
        ),
        (
            "no_large_model_product_claim",
            !witness.live_dense_70b_claimed && !witness.long_context_shard_claimed,
        ),
        (
            "no_model_runtime_provider_bytes",
            witness.model_runtime_bytes_loaded == 0 && witness.provider_calls_made == 0,
        ),
        (
            "no_raw_prompt_or_answer_bytes",
            witness.raw_prompt_or_answer_bytes_embedded == 0,
        ),
        (
            "rollback_run_event_answer_packet_refs_present",
            !witness.rollback_ref.is_empty()
                && !witness.run_event_log_ref.is_empty()
                && !witness.answer_packet_ref.is_empty(),
        ),
        (
            "next_manual_runtime_verification_queued",
            witness.next_cursor
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_PROBE_NEXT_CURSOR,
        ),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            pass,
        );
    }

    for (axis, pass) in red_results {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            pass,
        );
    }

    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_check_count",
        witness.required_check_ids.len() as u64,
        required_fresh_product_runtime_l3_release_audit_log_evidence_checks().len() as u64,
        "checks",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_phase_count",
        witness.phases.len() as u64,
        required_fresh_product_runtime_l3_release_audit_log_evidence_phases().len() as u64,
        "phases",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_rejection_policy_count",
        witness.rejection_policies.len() as u64,
        required_fresh_product_runtime_l3_release_audit_log_evidence_rejection_policies().len()
            as u64,
        "policies",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "log_digest_count",
        witness.log_digests.len() as u64,
        required_fresh_product_runtime_l3_release_audit_log_evidence_checks().len() as u64,
        "logs",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_fixture_count,
        red_fixture_count,
        "fixtures",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        red_fixture_count,
        "fixtures",
    );

    for (axis, value, expected) in [
        ("failed_check_count", witness.failed_check_count, 1),
        (
            "runtime_oslog_entries_bound",
            witness.runtime_oslog_entries_bound,
            ZERO,
        ),
        (
            "model_runtime_bytes_loaded_total",
            witness.model_runtime_bytes_loaded,
            ZERO,
        ),
        (
            "provider_calls_made_total",
            witness.provider_calls_made,
            ZERO,
        ),
        (
            "raw_prompt_or_answer_bytes_embedded_total",
            witness.raw_prompt_or_answer_bytes_embedded,
            ZERO,
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            value,
            "==",
            expected,
            "count",
        );
    }
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "xcodebuild_test_issue_count",
        witness.xcodebuild_test_issue_count,
        ">=",
        1,
        "issues",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "xcodebuild_test_unique_failure_count",
        witness.xcodebuild_test_unique_failure_count,
        ">=",
        1,
        "tests",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "log_bytes_total",
        witness.log_digests.iter().map(|digest| digest.bytes).sum(),
        ">=",
        1,
        "bytes",
    );

    insert_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_automated_checks_address",
        &witness.upstream_artifact_address,
        &witness.upstream_artifact_address,
        "sha256",
    );
    insert_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "top_xcodebuild_test_failure_family",
        &witness.top_xcodebuild_test_failure_family,
        "graph_filter_visibility",
        "family",
    );
    insert_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe_address",
        &witness.address(),
        &witness.address(),
        "sha256",
    );
    insert_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        &witness.next_cursor,
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_PROBE_NEXT_CURSOR,
        "cursor",
    );
    measurements.insert(
        "log_digest_refs".to_string(),
        Measurement {
            value: serde_json::json!(witness.log_digests),
            unit: "redacted_log_digests".to_string(),
        },
    );
    pass_per_axis.insert("log_digest_refs".to_string(), true);
    measurements.insert(
        "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe"
            .to_string(),
        Measurement {
            value: serde_json::json!(true),
            unit: "log_evidence_probe".to_string(),
        },
    );
    pass_per_axis.insert(
        "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe"
            .to_string(),
        true,
    );

    for axis in
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_PROBE_AXES
    {
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
        notes: "metadata-only F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditLogEvidenceProbe: consumes retained automated-checks logs, binds red xcodebuild_test family evidence, keeps runtime OSLog and AnswerPacket runtime correlation pending, opens zero model/runtime/provider bytes, embeds no raw prompt/answer/log payloads, and does not promote L2/L3/product/release/large-model capability.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-log-evidence-probe:upstream
// Plane: Verification.
// Residency: metadata-only read of retained automated-checks artifact.
struct UpstreamAutomatedChecks {
    overall_pass: bool,
    address: String,
    failed_check_count: u64,
    xcodebuild_test_issue_count: u64,
    xcodebuild_test_unique_failure_count: u64,
    top_xcodebuild_test_failure_family: String,
}

fn read_upstream() -> Result<UpstreamAutomatedChecks, Box<dyn std::error::Error>> {
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(UPSTREAM_RESULT)?)?;
    Ok(UpstreamAutomatedChecks {
        overall_pass: value["overall_pass"].as_bool().unwrap_or(false),
        address: measurement_string(
            &value,
            "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe_address",
        ),
        failed_check_count: measurement_u64(&value, "failed_check_count"),
        xcodebuild_test_issue_count: measurement_u64(&value, "xcodebuild_test_issue_count"),
        xcodebuild_test_unique_failure_count: measurement_u64(
            &value,
            "xcodebuild_test_unique_failure_count",
        ),
        top_xcodebuild_test_failure_family: measurement_string(
            &value,
            "top_xcodebuild_test_failure_family",
        ),
    })
}

fn read_check_logs() -> Result<Vec<SmallModelReleaseAuditLogDigest>, Box<dyn std::error::Error>> {
    let checks_tsv = std::fs::read_to_string(
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_CHECKS_TSV,
    )?;
    let mut digests = Vec::new();
    for (index, line) in checks_tsv.lines().enumerate() {
        if index == 0 {
            continue;
        }
        let fields: Vec<&str> = line.split('\t').collect();
        if fields.len() != 5 {
            continue;
        }
        let check_id = fields[0].to_string();
        let log_ref = fields[4].to_string();
        let bytes = std::fs::read(&log_ref)?;
        digests.push(SmallModelReleaseAuditLogDigest {
            check_id,
            log_ref,
            bytes: bytes.len() as u64,
            sha256: sha256_hex(&bytes),
        });
    }
    digests.sort_by(|left, right| left.check_id.cmp(&right.check_id));
    Ok(digests)
}

fn measurement_u64(value: &serde_json::Value, key: &str) -> u64 {
    value["measurements"][key]["value"].as_u64().unwrap_or(0)
}

fn measurement_string(value: &serde_json::Value, key: &str) -> String {
    value["measurements"][key]["value"]
        .as_str()
        .unwrap_or_default()
        .to_string()
}

fn red_fixture_results(
    witness: &SmallModelReleaseAuditLogEvidenceProbe,
) -> Vec<(&'static str, bool)> {
    let mut results = Vec::new();
    let mut cases = Vec::new();
    cases.push((
        "upstream_green_laundered_rejected",
        mutate(witness, |probe| {
            probe.upstream_overall_pass = true;
        }),
    ));
    cases.push((
        "missing_checks_tsv_rejected",
        mutate(witness, |probe| {
            probe.checks_tsv_ref = "missing.tsv".to_string();
        }),
    ));
    cases.push((
        "missing_required_log_rejected",
        mutate(witness, |probe| {
            probe.log_digests.pop();
        }),
    ));
    cases.push((
        "bad_log_digest_rejected",
        mutate(witness, |probe| {
            probe.log_digests[0].sha256 = "sha256:bad".to_string();
        }),
    ));
    cases.push((
        "zero_xcodebuild_issue_count_rejected",
        mutate(witness, |probe| {
            probe.xcodebuild_test_issue_count = 0;
        }),
    ));
    cases.push((
        "missing_top_failure_family_rejected",
        mutate(witness, |probe| {
            probe.top_xcodebuild_test_failure_family = "none".to_string();
        }),
    ));
    cases.push((
        "runtime_oslog_claim_rejected",
        mutate(witness, |probe| {
            probe.runtime_log_evidence_present = true;
        }),
    ));
    cases.push((
        "answer_packet_runtime_claim_rejected",
        mutate(witness, |probe| {
            probe.answer_packet_runtime_correlation_present = true;
        }),
    ));
    cases.push((
        "manual_runtime_claim_rejected",
        mutate(witness, |probe| {
            probe.manual_runtime_evidence_present = true;
        }),
    ));
    cases.push((
        "distribution_compliance_claim_rejected",
        mutate(witness, |probe| {
            probe.distribution_compliance_evidence_present = true;
        }),
    ));
    cases.push((
        "zero_fail_pass_count_claim_rejected",
        mutate(witness, |probe| {
            probe.zero_fail_pass_count = 1;
        }),
    ));
    cases.push((
        "l2_green_claim_rejected",
        mutate(witness, |probe| {
            probe.l2_green_claimed = true;
        }),
    ));
    cases.push((
        "l3_green_claim_rejected",
        mutate(witness, |probe| {
            probe.l3_green_claimed = true;
        }),
    ));
    cases.push((
        "product_green_claim_rejected",
        mutate(witness, |probe| {
            probe.product_green_claimed = true;
        }),
    ));
    cases.push((
        "release_ready_claim_rejected",
        mutate(witness, |probe| {
            probe.release_ready_claimed = true;
        }),
    ));
    cases.push((
        "live_dense_70b_claim_rejected",
        mutate(witness, |probe| {
            probe.live_dense_70b_claimed = true;
        }),
    ));
    cases.push((
        "long_context_shard_claim_rejected",
        mutate(witness, |probe| {
            probe.long_context_shard_claimed = true;
        }),
    ));
    cases.push((
        "model_runtime_bytes_rejected",
        mutate(witness, |probe| {
            probe.model_runtime_bytes_loaded = 1;
        }),
    ));
    cases.push((
        "provider_call_rejected",
        mutate(witness, |probe| {
            probe.provider_calls_made = 1;
        }),
    ));
    cases.push((
        "raw_prompt_or_answer_bytes_rejected",
        mutate(witness, |probe| {
            probe.raw_prompt_or_answer_bytes_embedded = 1;
        }),
    ));
    cases.push((
        "next_cursor_mismatch_rejected",
        mutate(witness, |probe| {
            probe.next_cursor = "wrong".to_string();
        }),
    ));
    results.extend(cases);
    results
}

fn mutate(
    witness: &SmallModelReleaseAuditLogEvidenceProbe,
    mutation: fn(&mut SmallModelReleaseAuditLogEvidenceProbe),
) -> bool {
    let mut candidate = witness.clone();
    mutation(&mut candidate);
    candidate.validate().is_err()
}

fn insert_string_measurement(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    key: &str,
    value: &str,
    expected: &str,
    unit: &str,
) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        key.to_string(),
        AcceptanceThreshold {
            operator: "eq".to_string(),
            value: serde_json::json!(expected),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(key.to_string(), value == expected);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn red_fixture_suite_is_exhaustive() {
        let witness = SmallModelReleaseAuditLogEvidenceProbe::canonical(
            "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            required_fresh_product_runtime_l3_release_audit_log_evidence_checks()
                .iter()
                .map(|check_id| SmallModelReleaseAuditLogDigest {
                    check_id: (*check_id).to_string(),
                    log_ref: format!("artifacts/falsifiers/example/logs/{check_id}.log"),
                    bytes: 1,
                    sha256:
                        "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                            .to_string(),
                })
                .collect(),
            1,
            161,
            84,
            "graph_filter_visibility",
        );
        let results = red_fixture_results(&witness);
        assert_eq!(results.len(), 21);
        assert!(results.iter().all(|(_, pass)| *pass));
    }
}
