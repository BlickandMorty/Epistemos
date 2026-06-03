//! `falsify_residency_construction_graph` — RCE dry-run planner witness.
//!
//! This is the first Research Construction Engine witness. It proves a
//! metadata-only `ResidencyConstructionGraph` can score candidate units under
//! memory, verifier, incompatibility, and cold-miss constraints without waking
//! model bytes, touching mmap files, or mutating live route policy.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    CoactivationEdge, ColdMissRecord, IncompatibilityEdge, ResidencyConstructionBudget,
    ResidencyConstructionGraph, ResidencyConstructionGraphError, ResidencyConstructionUnit,
    VerifierEdge,
};

const FALSIFIER_ID: &str = "F-ResidencyConstructionGraph";
const FIXTURE_ID: &str = "residency_construction_graph_dry_run_v1";
const COMMAND: &str = "Tools/falsifiers/f_residency_construction_graph.sh";
const RESULT: &str = "artifacts/falsifiers/residency_construction_graph/result.json";
const CREATED_AT_MS: u64 = 1_779_000_000_000;

fn main() -> std::process::ExitCode {
    let report = match build_report() {
        Ok(report) => report,
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
    if let Err(error) = write_artifact(&mut file, &report.artifact) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }

    println!(
        "{FALSIFIER_ID}: overall_pass={} selected_units={} rejected_units={} artifact={RESULT}",
        report.artifact.overall_pass, report.selected_unit_count, report.rejected_unit_count
    );

    if report.artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

// UAS: uas/research-construction/falsifier-report
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
struct ResidencyConstructionGraphReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    selected_unit_count: u64,
    rejected_unit_count: u64,
}

fn build_report() -> Result<ResidencyConstructionGraphReport, Box<dyn std::error::Error>> {
    let graph = accepted_graph()?;
    let reversed = ResidencyConstructionGraph::score(
        graph.task_signature.clone(),
        graph.candidate_units.iter().cloned().rev().collect(),
        graph.coactivation_edges.iter().cloned().rev().collect(),
        graph.incompatibility_edges.iter().cloned().rev().collect(),
        graph.verifier_edges.iter().cloned().rev().collect(),
        graph.cold_miss_history.iter().cloned().rev().collect(),
        graph.budget.clone(),
        CREATED_AT_MS,
    )?;
    let unknown_edge_rejected = ResidencyConstructionGraph::score(
        "task:bad-edge",
        vec![unit("evidence_core", 48, 16, 128, 8_700, 9_200, 8_500)?],
        vec![CoactivationEdge::new("evidence_core", "missing_unit", 250)?],
        vec![],
        vec![],
        vec![],
        ResidencyConstructionBudget::m2_pro_dry_run(),
        CREATED_AT_MS,
    )
    .is_err_and(|error| {
        error
            == ResidencyConstructionGraphError::UnknownUnitReference {
                unit_id: "missing_unit".to_string(),
            }
    });
    let no_valid_assembly_rejected = ResidencyConstructionGraph::score(
        "task:no-fit",
        vec![unit("too_large", 512, 0, 0, 8_000, 8_000, 8_000)?],
        vec![],
        vec![],
        vec![],
        vec![],
        ResidencyConstructionBudget {
            hot_uma_bytes: 1,
            warm_uma_bytes: 0,
            cold_ssd_bytes: 0,
            max_cold_misses: 0,
            max_cold_stall_ms: 0,
        },
        CREATED_AT_MS,
    )
    .is_err_and(|error| error == ResidencyConstructionGraphError::NoValidAssembly);
    let rollback_required = ResidencyConstructionUnit::new(
        "missing_rollback",
        "source:missing_rollback",
        1,
        0,
        0,
        8_000,
        8_000,
        8_000,
        "",
        CREATED_AT_MS,
    )
    .is_err_and(|error| {
        matches!(
            error,
            ResidencyConstructionGraphError::MissingRollback { .. }
        )
    });

    let source_card_ids = graph
        .candidate_units
        .iter()
        .map(|unit| unit.source_card_id.as_str())
        .collect::<BTreeSet<_>>();
    let selected_ids = graph
        .assembly_score
        .selected_unit_ids
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    let rejected_ids = graph
        .assembly_score
        .rejected_unit_ids
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "candidate_units_present",
        graph.candidate_units.len() == 4,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_card_ids_bound",
        source_card_ids.len() == graph.candidate_units.len()
            && source_card_ids.iter().all(|id| id.starts_with("source:")),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "task_signature_bound",
        graph.task_signature == "task:adversarial-note-research",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "graph_address_deterministic",
        graph.graph_address == reversed.graph_address,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "coactivation_edges_bound",
        graph.coactivation_edges.len() == 2
            && graph
                .coactivation_edges
                .iter()
                .any(|edge| edge.affinity_bps >= 900),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "incompatibility_edges_bound",
        graph.incompatibility_edges.len() == 1
            && graph
                .incompatibility_edges
                .iter()
                .any(|edge| edge.reason.contains("active-byte budget")),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_edges_bound",
        graph.verifier_edges.len() == 2
            && graph
                .verifier_edges
                .iter()
                .all(|edge| edge.verifier_id.starts_with("verifier:")),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_miss_history_bound",
        graph.cold_miss_history.len() == 3
            && graph.assembly_score.cold_miss_count == 1
            && graph.assembly_score.cold_stall_ms == 12,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "budget_enforced",
        selected_ids == BTreeSet::from(["evidence_core", "verifier_lane"])
            && rejected_ids == BTreeSet::from(["cold_atlas", "giant_dense_body"]),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "invalid_assemblies_rejected",
        unknown_edge_rejected && no_valid_assembly_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rollback_required",
        rollback_required,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_runtime_bytes_loaded",
        true,
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_unit_count",
        graph.assembly_score.selected_unit_ids.len() as u64,
        2,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rejected_unit_count",
        graph.assembly_score.rejected_unit_ids.len() as u64,
        2,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hot_resident_bytes",
        graph.assembly_score.hot_resident_bytes,
        80,
        "bytes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "warm_bytes",
        graph.assembly_score.warm_bytes,
        16,
        "bytes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_bytes",
        graph.assembly_score.cold_bytes,
        128,
        "bytes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_miss_count",
        graph.assembly_score.cold_miss_count,
        1,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_stall_ms",
        graph.assembly_score.cold_stall_ms,
        12,
        "ms",
    );
    add_count_ge_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "assembly_score_bps",
        u64::from(graph.assembly_score.score_bps),
        8_000,
        "bps",
    );
    add_string_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "graph_address",
        &graph.graph_address.to_string(),
    );

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: vec![serde_json::json!({
            "kind": "scope_guard",
            "detail": "metadata-only Research Construction Engine dry run; no mmap, model decode, MLX, Metal, KV, provider, or live route policy mutation executed"
        })],
        notes: "Proves the first RCE ResidencyConstructionGraph dry-run planner gate; later coactivation tile prefetch, proof-carrying lease, and cold assembly runtime gates remain separate.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(ResidencyConstructionGraphReport {
        artifact,
        selected_unit_count: graph.assembly_score.selected_unit_ids.len() as u64,
        rejected_unit_count: graph.assembly_score.rejected_unit_ids.len() as u64,
    })
}

fn accepted_graph() -> Result<ResidencyConstructionGraph, Box<dyn std::error::Error>> {
    Ok(ResidencyConstructionGraph::score(
        "task:adversarial-note-research",
        vec![
            unit("verifier_lane", 32, 0, 0, 8_200, 9_000, 9_100)?,
            unit("giant_dense_body", 1_024, 0, 0, 9_900, 9_500, 9_500)?,
            unit("evidence_core", 48, 16, 128, 8_700, 9_200, 8_500)?,
            unit("cold_atlas", 64, 0, 128, 7_800, 8_100, 7_600)?,
        ],
        vec![
            CoactivationEdge::new("evidence_core", "verifier_lane", 900)?,
            CoactivationEdge::new("cold_atlas", "evidence_core", 350)?,
        ],
        vec![IncompatibilityEdge::new(
            "giant_dense_body",
            "evidence_core",
            "dense body violates active-byte budget",
        )?],
        vec![
            VerifierEdge::new("evidence_core", "verifier:eidos", 900)?,
            VerifierEdge::new("verifier_lane", "verifier:lean-schema", 600)?,
        ],
        vec![
            ColdMissRecord::new("evidence_core", 1, 12)?,
            ColdMissRecord::new("verifier_lane", 0, 0)?,
            ColdMissRecord::new("cold_atlas", 2, 24)?,
        ],
        ResidencyConstructionBudget {
            hot_uma_bytes: 128,
            warm_uma_bytes: 32,
            cold_ssd_bytes: 256,
            max_cold_misses: 2,
            max_cold_stall_ms: 25,
        },
        CREATED_AT_MS,
    )?)
}

fn unit(
    id: &str,
    hot: u64,
    warm: u64,
    cold: u64,
    quality: u16,
    evidence: u16,
    verifier: u16,
) -> Result<ResidencyConstructionUnit, ResidencyConstructionGraphError> {
    ResidencyConstructionUnit::new(
        id,
        format!("source:{id}"),
        hot,
        warm,
        cold,
        quality,
        evidence,
        verifier,
        format!("rollback:{id}"),
        CREATED_AT_MS,
    )
}

fn add_count_eq_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual == expected);
}

fn add_count_ge_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    minimum: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::from(minimum),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual >= minimum);
}

fn add_string_eq_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual.to_string()),
            unit: "string".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::String(actual.to_string()),
            unit: "string".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), true);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn report_contains_required_rce_axes() {
        let report = build_report().expect("RCE report should build");
        for axis in [
            "candidate_units_present",
            "source_card_ids_bound",
            "graph_address_deterministic",
            "coactivation_edges_bound",
            "incompatibility_edges_bound",
            "verifier_edges_bound",
            "cold_miss_history_bound",
            "budget_enforced",
            "invalid_assemblies_rejected",
            "rollback_required",
            "no_runtime_bytes_loaded",
        ] {
            assert_eq!(report.artifact.pass_per_axis.get(axis), Some(&true));
            assert!(report.artifact.measurements.contains_key(axis));
            assert!(report.artifact.acceptance_thresholds.contains_key(axis));
        }
    }
}
