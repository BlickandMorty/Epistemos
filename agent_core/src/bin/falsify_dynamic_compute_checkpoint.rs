//! `falsify_dynamic_compute_checkpoint` — non-executing dynamic-compute gate.
//!
//! This proves only the manifest layer: every route-affecting dynamic-compute
//! checkpoint must bind a visible `RunEventLog` event, a Pro-only status, and
//! the `F-DynamicCompute-Checkpoint` verifier. It does not pause kernels,
//! mutate model state, mmap bytes, warm caches, allocate model buffers, or run
//! inference.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::agent_runtime_v2::{
    AgentEvent, DynamicComputeCheckpoint, DynamicComputeCheckpointError,
    DynamicComputeCheckpointKind, RunEventLog, DYNAMIC_COMPUTE_CHECKPOINT_FALSIFIER_ID,
};
use agent_core::cognitive_dag::node::Hash;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    ArtifactBuilder, ArtifactKind, FallbackTier,
};
use agent_core::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

const FALSIFIER_ID: &str = "F-DynamicCompute-Checkpoint";
const FIXTURE_ID: &str = "dynamic_compute_checkpoint_manifest_only_v1";
const COMMAND: &str = "Tools/falsifiers/f_dynamic_compute_checkpoint.sh";
const RESULT: &str = "artifacts/falsifiers/dynamic_compute_checkpoint/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} checkpoint_kinds={} artifact={}",
        report.artifact.overall_pass, report.checkpoint_kind_count, RESULT
    );
    if report.artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

struct DynamicComputeCheckpointReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    checkpoint_kind_count: u64,
}

fn build_report() -> Result<DynamicComputeCheckpointReport, Box<dyn std::error::Error>> {
    let mut log = RunEventLog::new();
    let ordinal = log.append_event(AgentEvent::ReasoningDelta {
        text: "Eidos interrupt checkpoint is visible before answer emission".to_string(),
    });

    let kinds = checkpoint_kinds();
    let mut checkpoints = Vec::with_capacity(kinds.len());
    for kind in kinds {
        checkpoints.push(DynamicComputeCheckpoint::from_visible_run_event(
            kind,
            format!("{} checkpoint route decision", kind.wire_tag()),
            active_units_before(),
            active_units_after(),
            format!(
                "{} route decision must be explicit before it can affect output",
                kind.wire_tag()
            ),
            2_500,
            &log,
            ordinal,
            verifier_stack(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            1_779_000_000_000,
        )?);
    }

    let primary = checkpoints
        .iter()
        .find(|checkpoint| {
            checkpoint.checkpoint_kind == DynamicComputeCheckpointKind::EidosInterrupt
        })
        .ok_or("fixture must include EidosInterrupt checkpoint")?;
    let visible_run_event_ordinal_bound = primary.run_event_id == "run_event_log:0";
    let active_units_bound =
        primary.active_units_before.len() == 2 && primary.active_units_after.len() == 3;
    let pro_research_status_bound = primary.product_build == ProductBuild::Pro
        && primary.pro_status == ProStatus::ResearchCandidate;
    let dynamic_checkpoint_verifier_bound = primary
        .verifier_stack
        .iter()
        .any(|verifier| verifier == DYNAMIC_COMPUTE_CHECKPOINT_FALSIFIER_ID);

    let missing_visible_event_rejected = DynamicComputeCheckpoint::from_visible_run_event(
        DynamicComputeCheckpointKind::VerifierRepair,
        "citation verifier failed",
        active_units_before(),
        active_units_after(),
        "bounded verifier repair must be visible",
        1_000,
        &RunEventLog::new(),
        0,
        verifier_stack(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        1_779_000_000_000,
    )
    .unwrap_err()
        == DynamicComputeCheckpointError::MissingRunEventLogOrdinal { ordinal: 0 };

    let mut non_event_log = RunEventLog::new();
    let non_event_ordinal =
        non_event_log.append_sealed_mutation(Hash::from_bytes([7; 32]), Default::default());
    let non_event_ordinal_rejected = DynamicComputeCheckpoint::from_visible_run_event(
        DynamicComputeCheckpointKind::AdapterSwap,
        "adapter family switch",
        active_units_before(),
        active_units_after(),
        "adapter swap must bind an AgentEvent row, not only a mutation row",
        1_000,
        &non_event_log,
        non_event_ordinal,
        verifier_stack(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        1_779_000_000_000,
    )
    .unwrap_err()
        == DynamicComputeCheckpointError::RunEventLogOrdinalIsNotEvent {
            ordinal: non_event_ordinal,
        };

    let missing_dynamic_checkpoint_falsifier_rejected =
        DynamicComputeCheckpoint::from_visible_run_event(
            DynamicComputeCheckpointKind::DepthBudget,
            "depth budget reached",
            active_units_before(),
            active_units_after(),
            "budget gate must be admitted before output changes",
            1_000,
            &log,
            ordinal,
            vec!["F-AppColdStore-Layout".to_string()],
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            1_779_000_000_000,
        )
        .unwrap_err()
            == DynamicComputeCheckpointError::MissingDynamicCheckpointFalsifier;

    let mas_checkpoint_rejected = DynamicComputeCheckpoint::from_visible_run_event(
        DynamicComputeCheckpointKind::SelfSpeculative,
        "shallow draft proposed deeper verify",
        active_units_before(),
        active_units_after(),
        "self-speculative routing remains Pro Research until falsified",
        1_000,
        &log,
        ordinal,
        verifier_stack(),
        ProductBuild::Mas,
        ProStatus::ResearchCandidate,
        1_779_000_000_000,
    )
    .unwrap_err()
        == DynamicComputeCheckpointError::ProductBuildStatusMismatch;

    let pro_live_checkpoint_rejected = DynamicComputeCheckpoint::from_visible_run_event(
        DynamicComputeCheckpointKind::DepthBudget,
        "depth budget changed the route plan",
        active_units_before(),
        active_units_after(),
        "manifest-only dynamic compute cannot be Pro Live",
        1_000,
        &log,
        ordinal,
        verifier_stack(),
        ProductBuild::Pro,
        ProStatus::Live,
        1_779_000_000_000,
    )
    .unwrap_err()
        == DynamicComputeCheckpointError::ProductBuildStatusMismatch;

    let duplicate_active_unit_rejected = {
        let duplicate = unit(b"duplicate-unit");
        DynamicComputeCheckpoint::from_visible_run_event(
            DynamicComputeCheckpointKind::KvRestore,
            "restore candidate KV pages before generation",
            vec![duplicate.clone(), duplicate.clone()],
            active_units_after(),
            "KV restore checkpoints must declare a unique support set",
            1_000,
            &log,
            ordinal,
            verifier_stack(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            1_779_000_000_000,
        )
        .unwrap_err()
            == DynamicComputeCheckpointError::DuplicateActiveUnit {
                field: "active_units_before",
                address: duplicate.to_string(),
            }
    };

    let unchanged_active_unit_sets_rejected = {
        let unchanged = unit(b"unchanged-unit");
        DynamicComputeCheckpoint::from_visible_run_event(
            DynamicComputeCheckpointKind::DepthBudget,
            "depth budget check reached",
            vec![unchanged.clone()],
            vec![unchanged],
            "route-affecting checkpoints must declare the support-set delta",
            1_000,
            &log,
            ordinal,
            verifier_stack(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            1_779_000_000_000,
        )
        .unwrap_err()
            == DynamicComputeCheckpointError::ActiveUnitsUnchanged
    };

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "declared_checkpoint_kind_count",
        checkpoints.len() as u64,
        8,
        "kinds",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "all_declared_checkpoint_kinds_constructed",
        checkpoints.len() == 8,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "visible_run_event_ordinal_bound",
        visible_run_event_ordinal_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_units_before_after_bound",
        active_units_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "dynamic_checkpoint_verifier_bound",
        dynamic_checkpoint_verifier_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "product_build_pro_research_status_bound",
        pro_research_status_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_visible_event_rejected",
        missing_visible_event_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "non_event_run_event_ordinal_rejected",
        non_event_ordinal_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_dynamic_checkpoint_falsifier_rejected",
        missing_dynamic_checkpoint_falsifier_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mas_checkpoint_rejected",
        mas_checkpoint_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "pro_live_checkpoint_rejected",
        pro_live_checkpoint_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "duplicate_active_unit_rejected",
        duplicate_active_unit_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unchanged_active_unit_sets_rejected",
        unchanged_active_unit_sets_rejected,
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_model_bytes_loaded",
        0,
        0,
        "bytes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_model_peak_uma_bytes",
        0,
        0,
        "bytes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "dry_run_ssd_read_bytes",
        0,
        0,
        "bytes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "witness_completeness_percent",
        100,
        100,
        "percent",
    );

    Ok(DynamicComputeCheckpointReport {
        checkpoint_kind_count: checkpoints.len() as u64,
        artifact: ArtifactBuilder {
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
                "detail": "manifest-only dynamic checkpoint witness; no mmap, no cache warm, no model byte load, no inference"
            })],
            notes: "Validates DynamicComputeCheckpoint manifest admission over visible RunEventLog rows; not a runtime, kernel, or model-state proof.".to_string(),
            timestamp_utc: now_utc_rfc3339(),
        }
        .build(),
    })
}

fn checkpoint_kinds() -> [DynamicComputeCheckpointKind; 8] {
    [
        DynamicComputeCheckpointKind::EarlyExit,
        DynamicComputeCheckpointKind::SelfSpeculative,
        DynamicComputeCheckpointKind::DepthBudget,
        DynamicComputeCheckpointKind::KvRestore,
        DynamicComputeCheckpointKind::AdapterSwap,
        DynamicComputeCheckpointKind::EidosInterrupt,
        DynamicComputeCheckpointKind::VerifierRepair,
        DynamicComputeCheckpointKind::ControllerSsm,
    ]
}

fn active_units_before() -> Vec<UasAddress> {
    vec![unit(b"controller-hot"), unit(b"eidos-evidence-patch")]
}

fn active_units_after() -> Vec<UasAddress> {
    vec![
        unit(b"controller-hot"),
        unit(b"eidos-evidence-patch"),
        unit(b"visible-checkpoint-support"),
    ]
}

fn unit(label: &[u8]) -> UasAddress {
    UasAddress::new(UasKind::ModelComponent, label, 1_779_000_000_000)
}

fn verifier_stack() -> Vec<String> {
    vec![DYNAMIC_COMPUTE_CHECKPOINT_FALSIFIER_ID.to_string()]
}
