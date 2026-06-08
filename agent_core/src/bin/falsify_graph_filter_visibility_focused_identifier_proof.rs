//! `falsify_graph_filter_visibility_focused_identifier_proof`.
//!
//! Metadata-only Swift Testing identifier proof for the graph-filter repair
//! ladder. It inspects source markers and records exact selector shapes without
//! running Xcode, opening result bundles, loading runtime/model bytes, or
//! claiming release readiness.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_graph_filter_focused_identifier_command_candidates,
    required_graph_filter_focused_identifier_function_identifiers,
    required_graph_filter_focused_identifier_source_refs,
    required_graph_filter_focused_identifier_suite_identifiers,
    GraphFilterFocusedIdentifierSourceMarkers, GraphFilterVisibilityFocusedIdentifierProofWitness,
    GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_NEXT_CURSOR,
    GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_NEXT_CURSOR,
    GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-GraphFilterVisibilityFocusedIdentifierProof";
const FIXTURE_ID: &str = "graph_filter_visibility_focused_identifier_proof_v1";
const COMMAND: &str = "Tools/falsifiers/f_graph_filter_visibility_focused_identifier_proof.sh";
const RESULT: &str =
    "artifacts/falsifiers/graph_filter_visibility_focused_identifier_proof/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/graph_filter_visibility_focused_repair_packet/result.json";
const FILTER_ENGINE_TESTS: &str = "EpistemosTests/FilterEngineComprehensiveTests.swift";
const RESOURCE_TESTS: &str = "EpistemosTests/ResourceExhaustionTests.swift";
const CONCURRENCY_TESTS: &str = "EpistemosTests/ConcurrencyEdgeCaseTests.swift";
const VAULT_TESTS: &str = "EpistemosTests/VaultLifecycleResetTests.swift";

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
        "{FALSIFIER_ID}: overall_pass={} function_identifiers={} next_cursor={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["function_identifier_count"].value,
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
    let source_markers = read_source_markers()?;
    let witness = GraphFilterVisibilityFocusedIdentifierProofWitness::new(
        GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_REF,
        upstream.overall_pass,
        &upstream.next_cursor,
        source_markers,
    )?;
    witness.validate()?;

    let red_results = red_fixture_results(&witness);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let red_fixture_count = red_results.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_focused_repair_packet_pass", upstream.overall_pass),
        (
            "upstream_next_cursor_identifier_proof",
            upstream.next_cursor
                == GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_NEXT_CURSOR,
        ),
        (
            "test_target_epistemos_tests_bound",
            witness.test_target == "EpistemosTests",
        ),
        (
            "source_refs_bound",
            witness.metrics.source_ref_count
                == required_graph_filter_focused_identifier_source_refs().len(),
        ),
        (
            "suite_identifiers_bound",
            witness.metrics.suite_identifier_count
                == required_graph_filter_focused_identifier_suite_identifiers().len(),
        ),
        (
            "function_identifiers_bound",
            witness.metrics.function_identifier_count
                == required_graph_filter_focused_identifier_function_identifiers().len(),
        ),
        (
            "function_identifiers_are_not_filenames",
            witness
                .function_identifiers
                .iter()
                .all(|identifier| !identifier.ends_with(".swift")),
        ),
        (
            "command_candidates_bound",
            witness.metrics.command_candidate_count
                == required_graph_filter_focused_identifier_command_candidates().len(),
        ),
        (
            "source_markers_bound",
            witness.source_markers.required_functions_present
                == required_graph_filter_focused_identifier_function_identifiers().len(),
        ),
        (
            "enumeration_incomplete_not_used_as_proof",
            !witness.enumeration_caveat.enumeration_completed
                && !witness
                    .enumeration_caveat
                    .incomplete_enumeration_used_as_proof,
        ),
        (
            "build_cost_phases_observed_bound",
            witness.metrics.build_cost_phase_count == 4,
        ),
        (
            "result_bundle_policy_bound",
            witness.result_bundle_policy.result_bundle_path_required
                && witness.result_bundle_policy.fresh_result_bundle_required
                && witness.result_bundle_policy.stale_xcresult_rejected,
        ),
        (
            "zero_executed_tests_rejected",
            witness.result_bundle_policy.zero_executed_tests_rejected,
        ),
        (
            "result_policy_rejects_filename_selectors",
            witness.result_bundle_policy.filename_selector_rejected,
        ),
        (
            "focused_pass_does_not_replace_full_row",
            !witness.result_bundle_policy.focused_pass_replaces_full_row,
        ),
        (
            "xcode_and_swift_tests_not_executed",
            !witness.proof_boundary.xcode_command_executed
                && !witness.proof_boundary.swift_tests_executed,
        ),
        (
            "no_l2_l3_t4_product_release_green",
            !witness.proof_boundary.l2_green_claimed
                && !witness.proof_boundary.l3_green_claimed
                && !witness.proof_boundary.t4_green_claimed
                && !witness.proof_boundary.product_green_claimed
                && !witness.proof_boundary.release_ready_claimed,
        ),
        (
            "no_live_dense_70b_claim",
            !witness.proof_boundary.live_dense_70b_claimed,
        ),
        (
            "no_raw_user_note_prompt_model_bytes",
            !witness
                .proof_boundary
                .raw_user_note_prompt_or_model_bytes_logged,
        ),
        (
            "no_hidden_authority_or_route_mutation",
            !witness.proof_boundary.hidden_route_authority
                && !witness.proof_boundary.route_mutation_claimed,
        ),
        (
            "zero_model_app_xcode_bytes",
            witness.metrics.xcode_command_bytes_executed == 0
                && witness.metrics.model_runtime_bytes_loaded == 0
                && witness.metrics.app_runtime_bytes_loaded == 0,
        ),
        (
            "rollback_run_event_answer_packet_refs_present",
            !witness.rollback_ref.is_empty()
                && !witness.run_event_log_ref.is_empty()
                && !witness.answer_packet_ref.is_empty(),
        ),
        (
            "next_cursor_bound",
            witness.next_cursor == GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_NEXT_CURSOR,
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
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_graph_filter_focused_identifier_source_refs().len() as u64,
            "refs",
        ),
        (
            "suite_identifier_count",
            witness.metrics.suite_identifier_count as u64,
            required_graph_filter_focused_identifier_suite_identifiers().len() as u64,
            "suites",
        ),
        (
            "function_identifier_count",
            witness.metrics.function_identifier_count as u64,
            required_graph_filter_focused_identifier_function_identifiers().len() as u64,
            "functions",
        ),
        (
            "command_candidate_count",
            witness.metrics.command_candidate_count as u64,
            required_graph_filter_focused_identifier_command_candidates().len() as u64,
            "commands",
        ),
        (
            "build_cost_phase_count",
            witness.metrics.build_cost_phase_count as u64,
            4,
            "phases",
        ),
        (
            "source_text_bytes_read",
            witness.metrics.source_text_bytes_read,
            witness.metrics.source_text_bytes_read,
            "bytes",
        ),
        (
            "xcode_command_bytes_executed_total",
            witness.metrics.xcode_command_bytes_executed,
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
            "app_runtime_bytes_loaded_total",
            witness.metrics.app_runtime_bytes_loaded,
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

    for (name, value, unit) in [
        (
            "graph_filter_focused_identifier_proof_address",
            serde_json::json!(witness.address),
            "sha256",
        ),
        (
            "suite_identifiers",
            serde_json::to_value(&witness.suite_identifiers)?,
            "suites",
        ),
        (
            "function_identifiers",
            serde_json::to_value(&witness.function_identifiers)?,
            "functions",
        ),
        (
            "enumeration_caveat",
            serde_json::to_value(&witness.enumeration_caveat)?,
            "enumeration",
        ),
        (
            "result_bundle_policy",
            serde_json::to_value(&witness.result_bundle_policy)?,
            "result_bundle_policy",
        ),
        (
            "next_cursor",
            serde_json::json!(witness.next_cursor),
            "cursor",
        ),
    ] {
        measurements.insert(
            name.to_string(),
            Measurement {
                value,
                unit: unit.to_string(),
            },
        );
        thresholds.insert(
            name.to_string(),
            AcceptanceThreshold {
                operator: "present".to_string(),
                value: serde_json::json!(true),
                unit: unit.to_string(),
            },
        );
        pass_per_axis.insert(name.to_string(), true);
    }

    for axis in GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_AXES {
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
        notes: "metadata-only F-GraphFilterVisibilityFocusedIdentifierProof: consumes the focused repair packet, binds exact Swift Testing suite/function identifiers from source, records incomplete enumeration caveat and build-cost phases, requires fresh result-bundle/nonzero-test proof later, rejects filename and zero-test laundering, executes zero Xcode commands, loads zero model/runtime bytes, and makes no L2/L3/T4/release/large-model claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:graph-filter-visibility-focused-identifier-proof:upstream-summary
// Plane: Verification.
// Residency: metadata-only upstream packet summary.
#[derive(Debug)]
struct UpstreamFocusedRepairPacket {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamFocusedRepairPacket, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamFocusedRepairPacket {
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

fn read_source_markers(
) -> Result<GraphFilterFocusedIdentifierSourceMarkers, Box<dyn std::error::Error>> {
    let filter_engine = std::fs::read_to_string(FILTER_ENGINE_TESTS)?;
    let resource = std::fs::read_to_string(RESOURCE_TESTS)?;
    let concurrency = std::fs::read_to_string(CONCURRENCY_TESTS)?;
    let vault = std::fs::read_to_string(VAULT_TESTS)?;
    let all = format!("{filter_engine}\n{resource}\n{concurrency}\n{vault}");
    let required_functions_present =
        required_graph_filter_focused_identifier_function_identifiers()
            .iter()
            .filter(|identifier| {
                identifier
                    .rsplit_once('/')
                    .map(|(_, function_name)| all.contains(&format!("func {function_name}(")))
                    .unwrap_or(false)
            })
            .count();
    Ok(GraphFilterFocusedIdentifierSourceMarkers {
        filter_engine_node_visibility_suite: filter_engine
            .contains("struct FilterEngineNodeVisibilityTests"),
        filter_engine_type_filter_specific_suite: filter_engine
            .contains("struct FilterEngineTypeFilterSpecificTests"),
        filter_engine_complex_scenario_suite: filter_engine
            .contains("struct FilterEngineComplexScenarioTests"),
        resource_edge_case_suite: resource.contains("struct ResourceEdgeCaseTests"),
        concurrency_filter_engine_suite: concurrency
            .contains("struct ConcurrencyFilterEngineTests"),
        vault_lifecycle_reset_suite: vault.contains("struct VaultLifecycleResetTests"),
        required_functions_present,
        source_text_bytes_read: all.len() as u64,
    })
}

fn red_fixture_results(
    witness: &GraphFilterVisibilityFocusedIdentifierProofWitness,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor) in [
        (
            "upstream_fail_rejected",
            false,
            GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_NEXT_CURSOR,
        ),
        ("wrong_upstream_cursor_rejected", true, "wrong_next_cursor"),
    ] {
        let rejected = GraphFilterVisibilityFocusedIdentifierProofWitness::new(
            GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_REF,
            upstream_pass,
            cursor,
            witness.source_markers.clone(),
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add = |id: &str,
               mutate: fn(&mut GraphFilterVisibilityFocusedIdentifierProofWitness),
               results: &mut Vec<(String, bool)>| {
        let mut fixture = witness.clone();
        mutate(&mut fixture);
        results.push((id.to_string(), fixture.validate().is_err()));
    };

    add(
        "missing_suite_identifier_rejected",
        |fixture| {
            fixture
                .suite_identifiers
                .retain(|value| !value.contains("FilterEngineNodeVisibilityTests"))
        },
        &mut results,
    );
    add(
        "missing_function_identifier_rejected",
        |fixture| {
            fixture
                .function_identifiers
                .retain(|value| !value.contains("isNodeVisibleForAllTypes"))
        },
        &mut results,
    );
    add(
        "filename_selector_rejected",
        |fixture| {
            fixture.function_identifiers[0] =
                "EpistemosTests/FilterEngineComprehensiveTests.swift".to_string()
        },
        &mut results,
    );
    add(
        "whitespace_selector_rejected",
        |fixture| {
            fixture.function_identifiers[0] =
                "EpistemosTests/Filter Engine/isNodeVisibleForAllTypes".to_string()
        },
        &mut results,
    );
    add(
        "function_without_suite_rejected",
        |fixture| {
            fixture.function_identifiers[0] =
                "EpistemosTests/MissingSuite/isNodeVisibleForAllTypes".to_string()
        },
        &mut results,
    );
    add(
        "missing_source_marker_rejected",
        |fixture| fixture.source_markers.required_functions_present = 0,
        &mut results,
    );
    add(
        "enumeration_completion_claim_rejected",
        |fixture| fixture.enumeration_caveat.enumeration_completed = true,
        &mut results,
    );
    add(
        "incomplete_enumeration_as_proof_rejected",
        |fixture| {
            fixture
                .enumeration_caveat
                .incomplete_enumeration_used_as_proof = true
        },
        &mut results,
    );
    add(
        "missing_build_cost_phase_rejected",
        |fixture| {
            fixture
                .enumeration_caveat
                .build_cost_phases_observed
                .clear()
        },
        &mut results,
    );
    add(
        "stale_xcresult_policy_gap_rejected",
        |fixture| fixture.result_bundle_policy.stale_xcresult_rejected = false,
        &mut results,
    );
    add(
        "zero_test_policy_gap_rejected",
        |fixture| fixture.result_bundle_policy.zero_executed_tests_rejected = false,
        &mut results,
    );
    add(
        "focused_replaces_full_row_rejected",
        |fixture| fixture.result_bundle_policy.focused_pass_replaces_full_row = true,
        &mut results,
    );
    add(
        "xcode_execution_claim_rejected",
        |fixture| fixture.proof_boundary.xcode_command_executed = true,
        &mut results,
    );
    add(
        "swift_test_execution_claim_rejected",
        |fixture| fixture.proof_boundary.swift_tests_executed = true,
        &mut results,
    );
    add(
        "focused_repair_proof_claim_rejected",
        |fixture| fixture.proof_boundary.focused_repair_proof_claimed = true,
        &mut results,
    );
    add(
        "full_xcodebuild_pass_claim_rejected",
        |fixture| fixture.proof_boundary.full_xcodebuild_test_pass_claimed = true,
        &mut results,
    );
    add(
        "l2_l3_product_release_green_rejected",
        |fixture| fixture.proof_boundary.release_ready_claimed = true,
        &mut results,
    );
    add(
        "live_dense_70b_claim_rejected",
        |fixture| fixture.proof_boundary.live_dense_70b_claimed = true,
        &mut results,
    );
    add(
        "raw_user_note_prompt_model_bytes_rejected",
        |fixture| {
            fixture
                .proof_boundary
                .raw_user_note_prompt_or_model_bytes_logged = true
        },
        &mut results,
    );
    add(
        "hidden_authority_rejected",
        |fixture| fixture.proof_boundary.hidden_route_authority = true,
        &mut results,
    );
    add(
        "route_mutation_rejected",
        |fixture| fixture.proof_boundary.route_mutation_claimed = true,
        &mut results,
    );
    add(
        "xcode_byte_execution_rejected",
        |fixture| fixture.metrics.xcode_command_bytes_executed = 1,
        &mut results,
    );
    add(
        "model_runtime_byte_leak_rejected",
        |fixture| fixture.metrics.model_runtime_bytes_loaded = 1,
        &mut results,
    );
    add(
        "app_runtime_byte_leak_rejected",
        |fixture| fixture.metrics.app_runtime_bytes_loaded = 1,
        &mut results,
    );
    results
}
