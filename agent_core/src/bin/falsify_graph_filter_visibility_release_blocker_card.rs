//! `falsify_graph_filter_visibility_release_blocker_card`.
//!
//! Metadata-only witness that binds the retained graph/filter visibility
//! release-audit failures to exact repair surfaces before Eidos graph evidence
//! navigation can promote to product proof.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_graph_filter_visibility_invariants, required_graph_filter_visibility_source_refs,
    GraphFilterVisibilityReleaseBlockerWitness, GRAPH_FILTER_VISIBILITY_FAMILY_SOURCE_REF,
    GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR, GRAPH_FILTER_VISIBILITY_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-GraphFilterVisibility-ReleaseBlockerCard";
const FIXTURE_ID: &str = "graph_filter_visibility_release_blocker_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_graph_filter_visibility_release_blocker_card.sh";
const RESULT: &str =
    "artifacts/falsifiers/graph_filter_visibility_release_blocker_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/visible_output_sanitization_release_blocker_card/result.json";
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
        artifact.measurements["graph_filter_issue_count"].value,
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
    let witness = GraphFilterVisibilityReleaseBlockerWitness::new(
        GRAPH_FILTER_VISIBILITY_UPSTREAM_REF,
        GRAPH_FILTER_VISIBILITY_FAMILY_SOURCE_REF,
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
        ("upstream_visible_output_card_pass", upstream.overall_pass),
        (
            "upstream_next_cursor_graph_filter_visibility",
            upstream.next_cursor == "graph_filter_visibility_release_blocker_card",
        ),
        (
            "graph_filter_family_bound",
            witness.card.family_id == "graph_filter_visibility",
        ),
        (
            "graph_filter_issue_count_retained",
            witness.card.issue_count == family.issue_count && witness.card.issue_count == 34,
        ),
        (
            "source_refs_cover_graph_filter_surfaces",
            witness.metrics.source_ref_count
                == required_graph_filter_visibility_source_refs().len(),
        ),
        (
            "focused_commands_cover_graph_filter_tests",
            witness.metrics.focused_command_count >= 3,
        ),
        (
            "graph_filter_invariants_bound",
            witness.metrics.invariant_count == required_graph_filter_visibility_invariants().len(),
        ),
        (
            "filter_engine_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Graph/FilterEngine.swift"),
        ),
        (
            "graph_types_source_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "Epistemos/Models/GraphTypes.swift"),
        ),
        (
            "filter_engine_tests_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "EpistemosTests/FilterEngineComprehensiveTests.swift"),
        ),
        (
            "resource_exhaustion_tests_bound",
            witness
                .card
                .source_refs
                .iter()
                .any(|value| value == "EpistemosTests/ResourceExhaustionTests.swift"),
        ),
        (
            "no_graph_filter_as_eidos_route_authority",
            !witness.card.graph_filter_as_eidos_route_authority,
        ),
        (
            "no_hidden_graph_filter_authority",
            !witness.card.hidden_graph_filter_authority,
        ),
        (
            "no_app_level_ffi_type_promotion",
            !witness.card.ffi_app_level_type_promoted,
        ),
        (
            "no_folder_default_on_overclaim",
            !witness.card.folder_default_on_claimed,
        ),
        (
            "no_search_or_focus_visibility_bypass",
            !witness.card.search_filter_bypass_claimed && !witness.card.focus_filter_bypass_claimed,
        ),
        (
            "edge_visibility_requires_visible_endpoints",
            !witness.card.edge_visibility_endpoint_bypass_claimed,
        ),
        (
            "no_graph_release_family_green_claim",
            !witness.card.graph_release_family_green_claimed,
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
            "no_runtime_bytes",
            witness.metrics.model_runtime_bytes_loaded == 0
                && witness.metrics.graph_runtime_bytes_loaded == 0,
        ),
        (
            "rollback_run_event_answer_packet_refs_present",
            !witness.card.rollback_ref.is_empty()
                && !witness.card.run_event_log_ref.is_empty()
                && !witness.card.answer_packet_ref.is_empty(),
        ),
        (
            "next_cursor_bound",
            witness.next_cursor == GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
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
            "graph_filter_issue_count",
            witness.card.issue_count,
            34,
            "issues",
        ),
        (
            "source_ref_count",
            witness.metrics.source_ref_count as u64,
            required_graph_filter_visibility_source_refs().len() as u64,
            "refs",
        ),
        (
            "focused_command_count",
            witness.metrics.focused_command_count as u64,
            3,
            "commands",
        ),
        (
            "graph_filter_invariant_count",
            witness.metrics.invariant_count as u64,
            required_graph_filter_visibility_invariants().len() as u64,
            "invariants",
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
        "graph_filter_visibility_address".to_string(),
        Measurement {
            value: serde_json::json!(witness.address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "graph_filter_visibility_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "graph_filter_visibility_address".to_string(),
        !witness.address.is_empty(),
    );

    measurements.insert(
        "graph_filter_visibility_card".to_string(),
        Measurement {
            value: serde_json::to_value(&witness.card)?,
            unit: "card".to_string(),
        },
    );
    thresholds.insert(
        "graph_filter_visibility_card".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::json!(true),
            unit: "card".to_string(),
        },
    );
    pass_per_axis.insert("graph_filter_visibility_card".to_string(), true);

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
            value: serde_json::json!(GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor == GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_NEXT_CURSOR,
    );

    for axis in GRAPH_FILTER_VISIBILITY_RELEASE_BLOCKER_CARD_AXES {
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
        notes: "metadata-only F-GraphFilterVisibility-ReleaseBlockerCard: consumes the visible-output blocker and release-audit family source card, binds graph_filter_visibility issue count 34 to exact FilterEngine/GraphTypes/GraphState/GraphStore/graph-view source refs, focused tests, visibility invariants, rollback, RunEventLog, AnswerPacket, and rejects graph filters as hidden Eidos route authority, app-level GraphNodeType FFI promotion, default-folder overclaims, search/focus/edge visibility bypasses, runtime byte loads, L2/L3/product green, and live dense-70B claims.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

// UAS: uas:graph-filter-visibility-release-blocker-card:upstream-parser
// Plane: Verification.
// Residency: metadata-only; reads artifact JSON only.
#[derive(Debug)]
struct UpstreamVisibleOutputCard {
    overall_pass: bool,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamVisibleOutputCard, Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    Ok(UpstreamVisibleOutputCard {
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

// UAS: uas:graph-filter-visibility-release-blocker-card:family-parser
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
    let graph_filter = cards
        .iter()
        .find(|card| {
            card.get("family_id").and_then(serde_json::Value::as_str)
                == Some("graph_filter_visibility")
        })
        .ok_or("missing graph_filter_visibility family")?;
    Ok(FamilySourceCard {
        family_id: graph_filter
            .get("family_id")
            .and_then(serde_json::Value::as_str)
            .unwrap_or_default()
            .to_string(),
        issue_count: graph_filter
            .get("issue_count")
            .and_then(serde_json::Value::as_u64)
            .unwrap_or(0),
    })
}

fn red_fixture_results(
    witness: &GraphFilterVisibilityReleaseBlockerWitness,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    for (id, upstream_pass, cursor, family, issues) in [
        (
            "upstream_fail_rejected",
            false,
            "graph_filter_visibility_release_blocker_card",
            "graph_filter_visibility",
            34,
        ),
        (
            "wrong_upstream_cursor_rejected",
            true,
            "visible_output_sanitization_release_blocker_card",
            "graph_filter_visibility",
            34,
        ),
        (
            "wrong_family_rejected",
            true,
            "graph_filter_visibility_release_blocker_card",
            "visible_output_sanitization",
            5,
        ),
        (
            "zero_issue_count_rejected",
            true,
            "graph_filter_visibility_release_blocker_card",
            "graph_filter_visibility",
            0,
        ),
    ] {
        let rejected = GraphFilterVisibilityReleaseBlockerWitness::new(
            GRAPH_FILTER_VISIBILITY_UPSTREAM_REF,
            GRAPH_FILTER_VISIBILITY_FAMILY_SOURCE_REF,
            upstream_pass,
            cursor,
            family,
            issues,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    }

    let add_card = |id: &str,
                    mutate: fn(&mut agent_core::uas::GraphFilterVisibilityReleaseBlockerCard),
                    results: &mut Vec<(String, bool)>| {
        let mut card = witness.card.clone();
        mutate(&mut card);
        results.push((id.to_string(), card.validate().is_err()));
    };
    add_card(
        "missing_filter_engine_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Graph/FilterEngine.swift")
        },
        &mut results,
    );
    add_card(
        "missing_graph_types_source_rejected",
        |card| {
            card.source_refs
                .retain(|value| value != "Epistemos/Models/GraphTypes.swift")
        },
        &mut results,
    );
    add_card(
        "missing_default_active_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "default_active_cases_are_single_source_of_truth")
        },
        &mut results,
    );
    add_card(
        "missing_ffi_contract_invariant_rejected",
        |card| {
            card.required_invariants
                .retain(|value| value != "ffi_graph_node_type_contract_stays_fourteen_cases")
        },
        &mut results,
    );
    add_card(
        "graph_filter_route_authority_rejected",
        |card| card.graph_filter_as_eidos_route_authority = true,
        &mut results,
    );
    add_card(
        "hidden_graph_filter_authority_rejected",
        |card| card.hidden_graph_filter_authority = true,
        &mut results,
    );
    add_card(
        "app_level_ffi_type_promotion_rejected",
        |card| card.ffi_app_level_type_promoted = true,
        &mut results,
    );
    add_card(
        "folder_default_on_claim_rejected",
        |card| card.folder_default_on_claimed = true,
        &mut results,
    );
    add_card(
        "search_filter_bypass_rejected",
        |card| card.search_filter_bypass_claimed = true,
        &mut results,
    );
    add_card(
        "focus_filter_bypass_rejected",
        |card| card.focus_filter_bypass_claimed = true,
        &mut results,
    );
    add_card(
        "edge_visibility_endpoint_bypass_rejected",
        |card| card.edge_visibility_endpoint_bypass_claimed = true,
        &mut results,
    );
    add_card(
        "graph_release_family_green_claim_rejected",
        |card| card.graph_release_family_green_claimed = true,
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
        "model_runtime_byte_leak_rejected",
        |card| card.model_runtime_bytes_loaded = 1,
        &mut results,
    );
    add_card(
        "graph_runtime_byte_leak_rejected",
        |card| card.graph_runtime_bytes_loaded = 1,
        &mut results,
    );

    results
}
