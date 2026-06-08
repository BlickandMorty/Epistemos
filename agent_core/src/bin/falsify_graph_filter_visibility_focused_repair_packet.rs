//! `falsify_graph_filter_visibility_focused_repair_packet`.
//!
//! Metadata-only repair packet for the retained `graph_filter_visibility`
//! release-audit family. It binds current source truth and focused repair
//! anchors without mutating product source, executing Swift tests, loading
//! model/runtime bytes, or claiming release readiness.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_graph_filter_focused_repair_commands, required_graph_filter_focused_repair_invariants,
    required_graph_filter_focused_repair_source_refs,
    required_graph_filter_focused_repair_test_refs, GraphFilterFocusedRepairSourceTruth,
    GraphFilterVisibilityFocusedRepairPacketWitness,
    GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_NEXT_CURSOR,
    GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-GraphFilterVisibilityFocusedRepairPacket";
const FIXTURE_ID: &str = "graph_filter_visibility_focused_repair_packet_v1";
const COMMAND: &str = "Tools/falsifiers/f_graph_filter_visibility_focused_repair_packet.sh";
const RESULT: &str =
    "artifacts/falsifiers/graph_filter_visibility_focused_repair_packet/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/release_audit_automated_checks_closure_matrix/result.json";
const GRAPH_TYPES: &str = "Epistemos/Models/GraphTypes.swift";
const FILTER_ENGINE: &str = "Epistemos/Graph/FilterEngine.swift";

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
        "{FALSIFIER_ID}: overall_pass={} retained_issue_count={} repair_anchor_count={} next_cursor={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["retained_issue_count"].value,
        artifact.measurements["repair_anchor_count"].value,
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
    let source_truth = read_source_truth()?;
    let witness = GraphFilterVisibilityFocusedRepairPacketWitness::new(
        GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_UPSTREAM_REF,
        upstream.overall_pass,
        &upstream.next_cursor,
        &upstream.family_id,
        upstream.issue_count,
        upstream.repair_rank,
        source_truth,
    )?;
    witness.validate()?;

    let red_results = red_fixture_results(&witness);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let red_fixture_count = red_results.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_closure_matrix_pass", upstream.overall_pass),
        (
            "upstream_next_cursor_focused_repair_packet",
            upstream.next_cursor == "graph_filter_visibility_focused_repair_packet",
        ),
        (
            "graph_filter_family_rank_one_bound",
            upstream.family_id == "graph_filter_visibility" && upstream.repair_rank == 1,
        ),
        (
            "retained_issue_count_34_bound",
            witness.retained_issue_count == 34,
        ),
        (
            "source_truth_visible_cases_not_default_active",
            witness.source_truth.visible_cases_excludes_block
                && witness.source_truth.default_active_cases_excludes_folder,
        ),
        (
            "filter_engine_default_active_bound",
            witness
                .source_truth
                .filter_engine_initializes_default_active
                && witness.source_truth.is_filtered_compares_default_active
                && witness.source_truth.show_all_types_restores_default_active
                && witness
                    .source_truth
                    .reset_for_vault_lifecycle_restores_default_active,
        ),
        (
            "folder_explicit_opt_in_bound",
            witness.source_truth.folder_opt_in_methods_present,
        ),
        (
            "source_refs_bound",
            witness.metrics.source_ref_count
                == required_graph_filter_focused_repair_source_refs().len(),
        ),
        (
            "test_refs_bound",
            witness.metrics.test_ref_count
                == required_graph_filter_focused_repair_test_refs().len(),
        ),
        (
            "focused_commands_bound",
            witness.metrics.focused_command_count
                == required_graph_filter_focused_repair_commands().len(),
        ),
        (
            "repair_anchors_bound",
            witness.metrics.repair_anchor_count == 7,
        ),
        (
            "repair_invariants_bound",
            witness.metrics.invariant_count
                == required_graph_filter_focused_repair_invariants().len(),
        ),
        (
            "source_patch_not_required",
            witness
                .repair_anchors
                .iter()
                .all(|anchor| !anchor.product_source_patch_required),
        ),
        (
            "swift_tests_not_executed",
            witness.metrics.swift_tests_executed_count == 0
                && !witness.proof_boundary.swift_tests_executed,
        ),
        (
            "identifier_proof_not_claimed",
            !witness.proof_boundary.focused_identifier_proof_claimed,
        ),
        (
            "focused_repair_proof_not_claimed",
            !witness.proof_boundary.focused_repair_proof_claimed,
        ),
        (
            "focused_tests_do_not_replace_full_rerun",
            !witness.proof_boundary.focused_tests_replace_full_rerun
                && !witness.proof_boundary.full_xcodebuild_test_pass_claimed,
        ),
        (
            "no_l2_l3_t4_product_green",
            !witness.proof_boundary.l2_green_claimed
                && !witness.proof_boundary.l3_green_claimed
                && !witness.proof_boundary.t4_green_claimed
                && !witness.proof_boundary.product_green_claimed,
        ),
        (
            "no_live_dense_70b_claim",
            !witness.proof_boundary.live_dense_70b_claimed,
        ),
        (
            "no_hidden_authority_or_route_mutation",
            !witness.proof_boundary.graph_filter_as_eidos_route_authority
                && !witness.proof_boundary.hidden_route_authority
                && !witness.proof_boundary.route_mutation_claimed,
        ),
        (
            "source_card_not_repair_proof",
            !witness.proof_boundary.source_card_as_repair_proof,
        ),
        (
            "zero_model_graph_command_bytes",
            witness.metrics.model_runtime_bytes_loaded == 0
                && witness.metrics.graph_runtime_bytes_loaded == 0
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
            witness.next_cursor == GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_NEXT_CURSOR,
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
            "retained_issue_count",
            witness.metrics.retained_issue_count,
            34,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_graph_filter_focused_repair_source_refs().len() as u64,
            "refs",
        ),
        (
            "test_ref_count",
            witness.metrics.test_ref_count as u64,
            required_graph_filter_focused_repair_test_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            required_graph_filter_focused_repair_commands().len() as u64,
            "commands",
        ),
        (
            "repair_anchor_count",
            witness.metrics.repair_anchor_count as u64,
            7,
            "anchors",
        ),
        (
            "repair_invariant_count",
            witness.metrics.invariant_count as u64,
            required_graph_filter_focused_repair_invariants().len() as u64,
            "invariants",
        ),
        (
            "source_truth_marker_count",
            witness.metrics.source_truth_marker_count as u64,
            7,
            "markers",
        ),
        (
            "swift_tests_executed_count",
            witness.metrics.swift_tests_executed_count,
            0,
            "tests",
        ),
        (
            "model_runtime_bytes_loaded_total",
            witness.metrics.model_runtime_bytes_loaded,
            0,
            "bytes",
        ),
        (
            "graph_runtime_bytes_loaded_total",
            witness.metrics.graph_runtime_bytes_loaded,
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
            "source_text_bytes_read",
            witness.source_truth.source_text_bytes_read,
            witness.source_truth.source_text_bytes_read,
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
        "graph_filter_focused_repair_packet_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "graph_filter_focused_repair_packet_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "graph_filter_focused_repair_packet_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "repair_anchors".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.repair_anchors)?,
            unit: "anchors".to_string(),
        },
    );
    thresholds.insert(
        "repair_anchors".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "anchors".to_string(),
        },
    );
    pass_per_axis.insert("repair_anchors".to_string(), true);

    measurements.insert(
        "source_truth".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.source_truth)?,
            unit: "source_truth".to_string(),
        },
    );
    thresholds.insert(
        "source_truth".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "source_truth".to_string(),
        },
    );
    pass_per_axis.insert("source_truth".to_string(), true);

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
            value: serde_json::json!(GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_NEXT_CURSOR,
    );

    for axis in GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_AXES {
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
        notes: "metadata-only F-GraphFilterVisibilityFocusedRepairPacket: consumes the release-audit closure matrix, binds graph_filter_visibility issue count 34, records current GraphNodeType/FilterEngine source truth, maps seven focused repair anchors, requires valid focused test identifiers before proof, executes zero Swift tests, mutates zero product source, loads zero model/runtime bytes, and makes no L2/L3/T4/release/large-model claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Debug)]
// UAS: uas:graph-filter-visibility-focused-repair-packet:upstream-closure
// Plane: Verification.
// Residency: metadata-only closure matrix summary.
struct UpstreamClosureMatrix {
    overall_pass: bool,
    next_cursor: String,
    family_id: String,
    issue_count: u64,
    repair_rank: u64,
}

fn read_upstream() -> Result<UpstreamClosureMatrix, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    let rows = json
        .pointer("/measurements/family_rows/value")
        .and_then(serde_json::Value::as_array)
        .ok_or("missing family_rows")?;
    let row = rows
        .iter()
        .find(|row| {
            row.get("family_id").and_then(serde_json::Value::as_str)
                == Some("graph_filter_visibility")
        })
        .ok_or("missing graph_filter_visibility row")?;
    Ok(UpstreamClosureMatrix {
        overall_pass: json
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false),
        next_cursor: json
            .pointer("/measurements/next_cursor/value")
            .and_then(serde_json::Value::as_str)
            .unwrap_or_default()
            .to_string(),
        family_id: row
            .get("family_id")
            .and_then(serde_json::Value::as_str)
            .unwrap_or_default()
            .to_string(),
        issue_count: row
            .get("issue_count")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0),
        repair_rank: row
            .get("repair_rank")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0),
    })
}

fn read_source_truth() -> Result<GraphFilterFocusedRepairSourceTruth, Box<dyn std::error::Error>> {
    let graph_types = std::fs::read_to_string(GRAPH_TYPES)?;
    let filter_engine = std::fs::read_to_string(FILTER_ENGINE)?;
    Ok(GraphFilterFocusedRepairSourceTruth {
        visible_cases_excludes_block: graph_types
            .contains("static let visibleCases: [GraphNodeType] = allCases.filter { $0 != .block } + appLevelCases"),
        default_active_cases_excludes_folder: graph_types
            .contains("static let defaultActiveCases: [GraphNodeType] = visibleCases.filter { $0 != .folder }"),
        filter_engine_initializes_default_active: filter_engine
            .contains("private(set) var activeNodeTypes: Set<GraphNodeType> = Set(GraphNodeType.defaultActiveCases)"),
        is_filtered_compares_default_active: filter_engine
            .contains("activeNodeTypes != Set(GraphNodeType.defaultActiveCases)"),
        show_all_types_restores_default_active: filter_engine
            .contains("func showAllTypes()")
            && filter_engine.contains("activeNodeTypes = Set(GraphNodeType.defaultActiveCases)"),
        reset_for_vault_lifecycle_restores_default_active: filter_engine
            .contains("func resetForVaultLifecycle()")
            && filter_engine.contains("activeNodeTypes = Set(GraphNodeType.defaultActiveCases)"),
        folder_opt_in_methods_present: filter_engine.contains("func setType(_ type: GraphNodeType, isVisible: Bool)")
            && filter_engine.contains("func toggleType(_ type: GraphNodeType)"),
        source_text_bytes_read: graph_types.len() as u64 + filter_engine.len() as u64,
    })
}

fn red_fixture_results(
    witness: &GraphFilterVisibilityFocusedRepairPacketWitness,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    let truth = witness.source_truth.clone();

    let bad_new_cases = [
        (
            "upstream_fail_rejected",
            false,
            "graph_filter_visibility_focused_repair_packet",
            "graph_filter_visibility",
            34,
            1,
            truth.clone(),
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe",
            "graph_filter_visibility",
            34,
            1,
            truth.clone(),
        ),
        (
            "wrong_family_rejected",
            true,
            "graph_filter_visibility_focused_repair_packet",
            "agent_route_policy",
            21,
            2,
            truth.clone(),
        ),
        (
            "zero_issue_count_rejected",
            true,
            "graph_filter_visibility_focused_repair_packet",
            "graph_filter_visibility",
            0,
            1,
            truth.clone(),
        ),
        (
            "wrong_repair_rank_rejected",
            true,
            "graph_filter_visibility_focused_repair_packet",
            "graph_filter_visibility",
            34,
            2,
            truth.clone(),
        ),
    ];
    for (id, pass, cursor, family, issues, rank, truth) in bad_new_cases {
        results.push((
            id.to_string(),
            GraphFilterVisibilityFocusedRepairPacketWitness::new(
                GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_UPSTREAM_REF,
                pass,
                cursor,
                family,
                issues,
                rank,
                truth,
            )
            .is_err(),
        ));
    }

    for (id, mutate) in [
        (
            "visible_cases_default_active_conflation_rejected",
            "visible_cases_excludes_block",
        ),
        (
            "folder_default_on_source_truth_rejected",
            "default_active_cases_excludes_folder",
        ),
        (
            "filter_engine_init_default_active_missing_rejected",
            "filter_engine_initializes_default_active",
        ),
        (
            "show_all_default_active_missing_rejected",
            "show_all_types_restores_default_active",
        ),
        (
            "reset_default_active_missing_rejected",
            "reset_for_vault_lifecycle_restores_default_active",
        ),
        (
            "folder_opt_in_missing_rejected",
            "folder_opt_in_methods_present",
        ),
    ] {
        let mut broken = truth.clone();
        match mutate {
            "visible_cases_excludes_block" => broken.visible_cases_excludes_block = false,
            "default_active_cases_excludes_folder" => {
                broken.default_active_cases_excludes_folder = false
            }
            "filter_engine_initializes_default_active" => {
                broken.filter_engine_initializes_default_active = false
            }
            "show_all_types_restores_default_active" => {
                broken.show_all_types_restores_default_active = false
            }
            "reset_for_vault_lifecycle_restores_default_active" => {
                broken.reset_for_vault_lifecycle_restores_default_active = false
            }
            "folder_opt_in_methods_present" => broken.folder_opt_in_methods_present = false,
            _ => {}
        }
        results.push((
            id.to_string(),
            GraphFilterVisibilityFocusedRepairPacketWitness::new(
                GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_UPSTREAM_REF,
                true,
                "graph_filter_visibility_focused_repair_packet",
                "graph_filter_visibility",
                34,
                1,
                broken,
            )
            .is_err(),
        ));
    }

    let mut packet = witness.clone();
    packet.repair_anchors[0].product_source_patch_required = true;
    results.push((
        "product_source_patch_required_rejected".to_string(),
        packet.validate().is_err(),
    ));

    let mut packet = witness.clone();
    packet.repair_anchors.pop();
    results.push((
        "missing_repair_anchor_rejected".to_string(),
        packet.validate().is_err(),
    ));

    let mut packet = witness.clone();
    packet.source_refs.pop();
    results.push((
        "missing_source_ref_rejected".to_string(),
        packet.validate().is_err(),
    ));

    let mut packet = witness.clone();
    packet.test_refs.pop();
    results.push((
        "missing_test_ref_rejected".to_string(),
        packet.validate().is_err(),
    ));

    for (id, mutate) in [
        (
            "swift_test_execution_claim_rejected",
            "swift_tests_executed",
        ),
        (
            "identifier_proof_claim_rejected",
            "focused_identifier_proof_claimed",
        ),
        (
            "focused_repair_proof_claim_rejected",
            "focused_repair_proof_claimed",
        ),
        (
            "full_xcodebuild_pass_claim_rejected",
            "full_xcodebuild_test_pass_claimed",
        ),
        (
            "l2_l3_product_green_claim_rejected",
            "product_green_claimed",
        ),
        ("live_dense_70b_claim_rejected", "live_dense_70b_claimed"),
        (
            "graph_filter_route_authority_rejected",
            "graph_filter_as_eidos_route_authority",
        ),
        ("hidden_authority_rejected", "hidden_route_authority"),
        ("route_mutation_rejected", "route_mutation_claimed"),
        (
            "source_card_as_repair_proof_rejected",
            "source_card_as_repair_proof",
        ),
        (
            "focused_tests_replace_full_rerun_rejected",
            "focused_tests_replace_full_rerun",
        ),
    ] {
        let mut packet = witness.clone();
        match mutate {
            "swift_tests_executed" => packet.proof_boundary.swift_tests_executed = true,
            "focused_identifier_proof_claimed" => {
                packet.proof_boundary.focused_identifier_proof_claimed = true
            }
            "focused_repair_proof_claimed" => {
                packet.proof_boundary.focused_repair_proof_claimed = true
            }
            "full_xcodebuild_test_pass_claimed" => {
                packet.proof_boundary.full_xcodebuild_test_pass_claimed = true
            }
            "product_green_claimed" => packet.proof_boundary.product_green_claimed = true,
            "live_dense_70b_claimed" => packet.proof_boundary.live_dense_70b_claimed = true,
            "graph_filter_as_eidos_route_authority" => {
                packet.proof_boundary.graph_filter_as_eidos_route_authority = true
            }
            "hidden_route_authority" => packet.proof_boundary.hidden_route_authority = true,
            "route_mutation_claimed" => packet.proof_boundary.route_mutation_claimed = true,
            "source_card_as_repair_proof" => {
                packet.proof_boundary.source_card_as_repair_proof = true
            }
            "focused_tests_replace_full_rerun" => {
                packet.proof_boundary.focused_tests_replace_full_rerun = true
            }
            _ => {}
        }
        results.push((id.to_string(), packet.validate().is_err()));
    }

    let mut packet = witness.clone();
    packet.metrics.model_runtime_bytes_loaded = 1;
    results.push((
        "model_runtime_byte_leak_rejected".to_string(),
        packet.validate().is_err(),
    ));

    let mut packet = witness.clone();
    packet.metrics.graph_runtime_bytes_loaded = 1;
    results.push((
        "graph_runtime_byte_leak_rejected".to_string(),
        packet.validate().is_err(),
    ));

    let mut packet = witness.clone();
    packet.metrics.command_bytes_executed = 1;
    results.push((
        "command_execution_byte_leak_rejected".to_string(),
        packet.validate().is_err(),
    ));

    results
}
