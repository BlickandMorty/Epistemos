//! `falsify_release_audit_automated_checks_closure_matrix`.
//!
//! Metadata-only closure matrix for the retained red release-audit automated
//! checks. It maps the failed `xcodebuild_test` row and all source-carded
//! failure families into repair order without rerunning commands, loading
//! model/runtime bytes, or claiming release/product readiness.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_release_audit_closure_check_ids, required_release_audit_closure_steps,
    required_release_audit_closure_top_family_source_refs,
    required_release_audit_closure_top_family_test_refs,
    ReleaseAuditAutomatedChecksClosureMatrixWitness, ReleaseAuditClosureCommandRow,
    ReleaseAuditClosureCommandStatus, ReleaseAuditClosureFamilyStatus,
    ReleaseAuditFailureFamilySourceCard,
    RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_FAMILY_SOURCE_REF,
    RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_NEXT_CURSOR,
    RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-ReleaseAuditAutomatedChecksClosureMatrix";
const FIXTURE_ID: &str = "release_audit_automated_checks_closure_matrix_v1";
const COMMAND: &str = "Tools/falsifiers/f_release_audit_automated_checks_closure_matrix.sh";
const RESULT: &str =
    "artifacts/falsifiers/release_audit_automated_checks_closure_matrix/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/result.json";
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
        "{FALSIFIER_ID}: overall_pass={} failed_command_count={} total_issue_count={} next_cursor={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["failed_command_count"].value,
        artifact.measurements["total_issue_count"].value,
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
    let family_source = read_family_source()?;
    let command_rows = command_rows_from_upstream(&upstream)?;
    let witness = ReleaseAuditAutomatedChecksClosureMatrixWitness::new(
        RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_UPSTREAM_REF,
        RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_FAMILY_SOURCE_REF,
        upstream.overall_pass,
        upstream.failed_check_count,
        upstream.unique_failure_count,
        &upstream.top_family_id,
        command_rows,
        family_source.cards,
    )?;
    witness.validate()?;

    let red_results = red_fixture_results(&witness);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let red_fixture_count = red_results.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_automated_checks_red", !upstream.overall_pass),
        (
            "upstream_failed_xcodebuild_test_bound",
            upstream.failed_check_count == 1
                && upstream.xcodebuild_test_passed == Some(false)
                && upstream.top_family_id == "graph_filter_visibility",
        ),
        (
            "required_check_rows_bound",
            witness.metrics.command_count == required_release_audit_closure_check_ids().len(),
        ),
        (
            "only_xcodebuild_test_failed",
            witness.metrics.failed_command_count == 1
                && witness.command_rows.iter().any(|row| {
                    row.check_id == "xcodebuild_test"
                        && row.status == ReleaseAuditClosureCommandStatus::FailedRetained
                }),
        ),
        (
            "four_retained_commands_passed",
            witness.metrics.passed_command_count == 4,
        ),
        (
            "family_source_card_pass_bound",
            family_source.overall_pass
                && family_source.falsifier_id == "F-ReleaseAuditFailureFamily-SourceCard",
        ),
        (
            "all_failure_families_in_closure_matrix",
            witness.metrics.family_count == 15,
        ),
        (
            "total_issue_count_retained",
            witness.metrics.total_issue_count == upstream.issue_count,
        ),
        (
            "unique_failure_count_retained",
            witness.metrics.unique_failure_count == 84,
        ),
        (
            "top_family_graph_filter_visibility_bound",
            witness.metrics.top_family_id == "graph_filter_visibility"
                && witness.metrics.top_family_issue_count == 34,
        ),
        (
            "graph_filter_visibility_focused_repair_needed",
            witness.family_rows.iter().any(|row| {
                row.family_id == "graph_filter_visibility"
                    && row.status == ReleaseAuditClosureFamilyStatus::FocusedRepairNeeded
                    && row.repair_rank == 1
            }),
        ),
        (
            "top_family_source_refs_bound",
            required_release_audit_closure_top_family_source_refs()
                .iter()
                .all(|required| {
                    upstream
                        .focused_repair_source_refs
                        .iter()
                        .any(|value| value == required)
                }),
        ),
        (
            "top_family_test_refs_bound",
            required_release_audit_closure_top_family_test_refs()
                .iter()
                .all(|required| {
                    upstream
                        .focused_repair_test_refs
                        .iter()
                        .any(|value| value == required)
                }),
        ),
        (
            "closure_steps_bound",
            witness.metrics.closure_step_count == required_release_audit_closure_steps().len(),
        ),
        (
            "source_cards_not_repair_proof",
            witness.metrics.source_card_repair_proof_count == 0,
        ),
        (
            "focused_tests_do_not_replace_full_rerun",
            witness.metrics.focused_test_full_rerun_replacement_count == 0,
        ),
        (
            "log_manual_distribution_evidence_not_attempted",
            !witness.proof_boundary.log_evidence_attempted
                && !witness.proof_boundary.manual_runtime_evidence_attempted
                && !witness.proof_boundary.distribution_evidence_attempted,
        ),
        (
            "zero_fail_passes_unclaimed",
            witness.proof_boundary.zero_fail_passes_claimed == 0,
        ),
        (
            "no_l2_l3_t4_product_ship_green",
            !witness.proof_boundary.l2_green_claimed
                && !witness.proof_boundary.l3_green_claimed
                && !witness.proof_boundary.t4_green_claimed
                && !witness.proof_boundary.product_green_claimed
                && !witness.proof_boundary.ship_call_claimed,
        ),
        (
            "no_live_dense_70b_or_ssd_as_ram",
            !witness.proof_boundary.live_dense_70b_claimed
                && !witness.proof_boundary.ssd_as_ram_claimed,
        ),
        (
            "no_hidden_authority_or_route_mutation",
            !witness.proof_boundary.hidden_route_authority_claimed
                && !witness.proof_boundary.route_mutation_claimed,
        ),
        (
            "zero_model_product_provider_command_bytes",
            witness.metrics.model_runtime_bytes_loaded == 0
                && witness.metrics.product_runtime_bytes_loaded == 0
                && witness.metrics.provider_bytes_loaded == 0
                && witness.metrics.command_bytes_executed == 0,
        ),
        (
            "rollback_run_event_answer_packet_refs_present",
            !witness.rollback_ref.is_empty()
                && !witness.run_event_log_ref.is_empty()
                && !witness.answer_packet_ref.is_empty(),
        ),
        (
            "next_cursor_bound",
            witness.next_cursor == RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_NEXT_CURSOR,
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
            "command_count",
            witness.metrics.command_count as u64,
            5,
            "commands",
        ),
        (
            "passed_command_count",
            witness.metrics.passed_command_count as u64,
            4,
            "commands",
        ),
        (
            "failed_command_count",
            witness.metrics.failed_command_count as u64,
            1,
            "commands",
        ),
        (
            "total_issue_count",
            witness.metrics.total_issue_count,
            161,
            "issues",
        ),
        (
            "unique_failure_count",
            witness.metrics.unique_failure_count,
            84,
            "tests",
        ),
        (
            "failure_family_count",
            witness.metrics.family_count as u64,
            15,
            "families",
        ),
        (
            "top_family_issue_count",
            witness.metrics.top_family_issue_count,
            34,
            "issues",
        ),
        (
            "closure_step_count",
            witness.metrics.closure_step_count as u64,
            required_release_audit_closure_steps().len() as u64,
            "steps",
        ),
        (
            "focused_repair_family_count",
            witness.metrics.focused_repair_family_count as u64,
            1,
            "families",
        ),
        (
            "source_card_repair_proof_count",
            witness.metrics.source_card_repair_proof_count as u64,
            0,
            "claims",
        ),
        (
            "focused_test_full_rerun_replacement_count",
            witness.metrics.focused_test_full_rerun_replacement_count as u64,
            0,
            "claims",
        ),
        (
            "model_runtime_bytes_loaded_total",
            witness.metrics.model_runtime_bytes_loaded,
            0,
            "bytes",
        ),
        (
            "product_runtime_bytes_loaded_total",
            witness.metrics.product_runtime_bytes_loaded,
            0,
            "bytes",
        ),
        (
            "provider_bytes_loaded_total",
            witness.metrics.provider_bytes_loaded,
            0,
            "bytes",
        ),
        (
            "command_bytes_executed_total",
            witness.metrics.command_bytes_executed,
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
        "release_audit_closure_matrix_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "release_audit_closure_matrix_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "release_audit_closure_matrix_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "command_rows".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.command_rows)?,
            unit: "rows".to_string(),
        },
    );
    thresholds.insert(
        "command_rows".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "rows".to_string(),
        },
    );
    pass_per_axis.insert("command_rows".to_string(), true);

    measurements.insert(
        "family_rows".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.family_rows)?,
            unit: "rows".to_string(),
        },
    );
    thresholds.insert(
        "family_rows".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "rows".to_string(),
        },
    );
    pass_per_axis.insert("family_rows".to_string(), true);

    measurements.insert(
        "closure_steps".to_string(),
        Measurement {
            value: serde_json::json!(witness.closure_steps),
            unit: "steps".to_string(),
        },
    );
    thresholds.insert(
        "closure_steps".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "steps".to_string(),
        },
    );
    pass_per_axis.insert("closure_steps".to_string(), true);

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
            value: serde_json::json!(RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_NEXT_CURSOR,
    );

    for axis in RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_AXES {
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
        notes: "metadata-only F-ReleaseAuditAutomatedChecksClosureMatrix: consumes the retained red automated-check ledger and release-audit family source card, maps xcodebuild_test plus 15 families into repair order, binds graph_filter_visibility as the first focused repair, rejects source-card-as-repair/full-rerun/product-green/live-70B/SSD-as-RAM/hidden-authority/byte fixtures, runs no commands, loads zero model/runtime/provider bytes, and makes no L2/L3/T4/release-ready claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Debug)]
// UAS: uas:release-audit-automated-checks-closure-matrix:upstream-automated-checks
// Plane: Verification.
// Residency: metadata-only retained command ledger summary; no command rerun.
struct UpstreamAutomatedChecks {
    overall_pass: bool,
    failed_check_count: u64,
    issue_count: u64,
    unique_failure_count: u64,
    top_family_id: String,
    check_ids: Vec<String>,
    xcodebuild_test_passed: Option<bool>,
    focused_repair_source_refs: Vec<String>,
    focused_repair_test_refs: Vec<String>,
}

fn read_upstream() -> Result<UpstreamAutomatedChecks, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamAutomatedChecks {
        overall_pass: json
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false),
        failed_check_count: measurement_u64(&json, "failed_check_count"),
        issue_count: measurement_u64(&json, "xcodebuild_test_issue_count"),
        unique_failure_count: measurement_u64(&json, "xcodebuild_test_unique_failure_count"),
        top_family_id: measurement_string(&json, "top_xcodebuild_test_failure_family"),
        check_ids: measurement_string_array(&json, "automated_check_ids"),
        xcodebuild_test_passed: json
            .pointer("/measurements/xcodebuild_test_passed/value")
            .and_then(serde_json::Value::as_bool),
        focused_repair_source_refs: measurement_string_array(&json, "focused_repair_source_refs"),
        focused_repair_test_refs: measurement_string_array(&json, "focused_repair_test_refs"),
    })
}

#[derive(Debug)]
// UAS: uas:release-audit-automated-checks-closure-matrix:family-source-artifact
// Plane: Verification.
// Residency: metadata-only family source-card artifact summary.
struct FamilySourceArtifact {
    overall_pass: bool,
    falsifier_id: String,
    cards: Vec<ReleaseAuditFailureFamilySourceCard>,
}

fn read_family_source() -> Result<FamilySourceArtifact, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(FAMILY_SOURCE_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    let cards = json
        .pointer("/measurements/failure_family_cards/value")
        .and_then(serde_json::Value::as_array)
        .ok_or("missing failure_family_cards")?
        .iter()
        .cloned()
        .map(serde_json::from_value)
        .collect::<Result<Vec<ReleaseAuditFailureFamilySourceCard>, _>>()?;
    Ok(FamilySourceArtifact {
        overall_pass: json
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false),
        falsifier_id: json
            .get("falsifier_id")
            .and_then(serde_json::Value::as_str)
            .unwrap_or_default()
            .to_string(),
        cards,
    })
}

fn command_rows_from_upstream(
    upstream: &UpstreamAutomatedChecks,
) -> Result<Vec<ReleaseAuditClosureCommandRow>, Box<dyn std::error::Error>> {
    if upstream.check_ids.len() != required_release_audit_closure_check_ids().len() {
        return Err("bad upstream check id count".into());
    }
    let mut rows = Vec::with_capacity(upstream.check_ids.len());
    for check_id in &upstream.check_ids {
        let failed = check_id == "xcodebuild_test";
        rows.push(ReleaseAuditClosureCommandRow::new(
            check_id,
            if failed {
                ReleaseAuditClosureCommandStatus::FailedRetained
            } else {
                ReleaseAuditClosureCommandStatus::PassedRetained
            },
            if failed { upstream.issue_count } else { 0 },
            &format!("artifact_log:{check_id}"),
        )?);
    }
    Ok(rows)
}

fn measurement_u64(json: &serde_json::Value, name: &str) -> u64 {
    json.pointer(&format!("/measurements/{name}/value"))
        .and_then(serde_json::Value::as_u64)
        .unwrap_or(0)
}

fn measurement_string(json: &serde_json::Value, name: &str) -> String {
    json.pointer(&format!("/measurements/{name}/value"))
        .and_then(serde_json::Value::as_str)
        .unwrap_or_default()
        .to_string()
}

fn measurement_string_array(json: &serde_json::Value, name: &str) -> Vec<String> {
    json.pointer(&format!("/measurements/{name}/value"))
        .and_then(serde_json::Value::as_array)
        .map(|values| {
            values
                .iter()
                .filter_map(serde_json::Value::as_str)
                .map(ToString::to_string)
                .collect()
        })
        .unwrap_or_default()
}

fn red_fixture_results(
    witness: &ReleaseAuditAutomatedChecksClosureMatrixWitness,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    let commands = witness.command_rows.clone();
    let cards = witness
        .family_rows
        .iter()
        .map(|row| {
            ReleaseAuditFailureFamilySourceCard::new(&row.family_id, row.issue_count)
                .expect("source-card mirror")
        })
        .collect::<Vec<_>>();

    let mut missing_top_cards = cards.clone();
    missing_top_cards.retain(|card| card.family_id != "graph_filter_visibility");
    let mut zero_issue_cards = cards.clone();
    if let Some(card) = zero_issue_cards
        .iter_mut()
        .find(|card| card.family_id == "graph_filter_visibility")
    {
        card.issue_count = 0;
    }
    let mut duplicate_cards = cards.clone();
    duplicate_cards.push(cards[0].clone());

    let bad_cases = [
        (
            "green_upstream_rejected",
            true,
            0,
            0,
            "graph_filter_visibility",
            commands.clone(),
            cards.clone(),
        ),
        (
            "zero_failed_check_rejected",
            false,
            0,
            84,
            "graph_filter_visibility",
            commands.clone(),
            cards.clone(),
        ),
        (
            "zero_unique_failures_rejected",
            false,
            1,
            0,
            "graph_filter_visibility",
            commands.clone(),
            cards.clone(),
        ),
        (
            "wrong_top_family_rejected",
            false,
            1,
            84,
            "agent_route_policy",
            commands.clone(),
            cards.clone(),
        ),
        (
            "missing_top_family_rejected",
            false,
            1,
            84,
            "graph_filter_visibility",
            commands.clone(),
            missing_top_cards,
        ),
        (
            "zero_issue_family_rejected",
            false,
            1,
            84,
            "graph_filter_visibility",
            commands.clone(),
            zero_issue_cards,
        ),
        (
            "duplicate_family_rejected",
            false,
            1,
            84,
            "graph_filter_visibility",
            commands.clone(),
            duplicate_cards,
        ),
    ];
    for (id, overall_pass, failed_count, unique_count, top_family, commands, cards) in bad_cases {
        results.push((
            id.to_string(),
            ReleaseAuditAutomatedChecksClosureMatrixWitness::new(
                RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_UPSTREAM_REF,
                RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_FAMILY_SOURCE_REF,
                overall_pass,
                failed_count,
                unique_count,
                top_family,
                commands,
                cards,
            )
            .is_err(),
        ));
    }

    let mut wrong_commands = commands.clone();
    if let Some(row) = wrong_commands
        .iter_mut()
        .find(|row| row.check_id == "xcodebuild_test")
    {
        row.status = ReleaseAuditClosureCommandStatus::PassedRetained;
        row.issue_count = 0;
    }
    results.push((
        "failed_command_missing_rejected".to_string(),
        ReleaseAuditAutomatedChecksClosureMatrixWitness::new(
            RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_UPSTREAM_REF,
            RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_FAMILY_SOURCE_REF,
            false,
            1,
            84,
            "graph_filter_visibility",
            wrong_commands,
            cards.clone(),
        )
        .is_err(),
    ));

    let mut witness = witness.clone();
    if let Some(row) = witness
        .family_rows
        .iter_mut()
        .find(|row| row.family_id == "graph_filter_visibility")
    {
        row.source_card_is_repair_proof = true;
    }
    results.push((
        "source_card_as_repair_proof_rejected".to_string(),
        witness.validate().is_err(),
    ));

    let mut witness = witness.clone();
    if let Some(row) = witness
        .family_rows
        .iter_mut()
        .find(|row| row.family_id == "graph_filter_visibility")
    {
        row.focused_test_replaces_full_rerun = true;
    }
    results.push((
        "focused_test_replaces_full_rerun_rejected".to_string(),
        witness.validate().is_err(),
    ));

    let mut witness = witness.clone();
    witness.proof_boundary.log_evidence_attempted = true;
    results.push((
        "log_evidence_attempted_rejected".to_string(),
        witness.validate().is_err(),
    ));

    let mut witness = witness.clone();
    witness.proof_boundary.manual_runtime_evidence_attempted = true;
    results.push((
        "manual_runtime_evidence_attempted_rejected".to_string(),
        witness.validate().is_err(),
    ));

    let mut witness = witness.clone();
    witness.proof_boundary.t4_green_claimed = true;
    results.push((
        "t4_green_claim_rejected".to_string(),
        witness.validate().is_err(),
    ));

    let mut witness = witness.clone();
    witness.proof_boundary.product_green_claimed = true;
    results.push((
        "product_green_claim_rejected".to_string(),
        witness.validate().is_err(),
    ));

    let mut witness = witness.clone();
    witness.proof_boundary.ship_call_claimed = true;
    results.push((
        "ship_call_claim_rejected".to_string(),
        witness.validate().is_err(),
    ));

    let mut witness = witness.clone();
    witness.proof_boundary.live_dense_70b_claimed = true;
    results.push((
        "live_dense_70b_claim_rejected".to_string(),
        witness.validate().is_err(),
    ));

    let mut witness = witness.clone();
    witness.proof_boundary.ssd_as_ram_claimed = true;
    results.push((
        "ssd_as_ram_claim_rejected".to_string(),
        witness.validate().is_err(),
    ));

    let mut witness = witness.clone();
    witness.proof_boundary.hidden_route_authority_claimed = true;
    results.push((
        "hidden_authority_claim_rejected".to_string(),
        witness.validate().is_err(),
    ));

    let mut witness = witness.clone();
    witness.proof_boundary.route_mutation_claimed = true;
    results.push((
        "route_mutation_claim_rejected".to_string(),
        witness.validate().is_err(),
    ));

    let mut witness = witness.clone();
    witness.byte_ledger.model_runtime_bytes_loaded = 1;
    results.push((
        "model_runtime_byte_leak_rejected".to_string(),
        witness.validate().is_err(),
    ));

    let mut witness = witness.clone();
    witness.byte_ledger.product_runtime_bytes_loaded = 1;
    results.push((
        "product_runtime_byte_leak_rejected".to_string(),
        witness.validate().is_err(),
    ));

    let mut witness = witness.clone();
    witness.byte_ledger.command_bytes_executed = 1;
    results.push((
        "command_execution_byte_leak_rejected".to_string(),
        witness.validate().is_err(),
    ));

    results
}
