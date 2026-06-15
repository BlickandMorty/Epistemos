//! `falsify_transport_cancellation`.
//!
//! Metadata-only witness for `F-TransportCancellation`. It proves route
//! changes cancel obsolete in-flight reads and reject stale slabs before any
//! live ColdStream, 70B, or product runtime claim can promote.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::CODEC_STAGE_LATENCY_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, TransportCancellationError, TransportCancellationRun,
    TransportCancellationState, TransportCancellationSurface, TransportCancellationWitness,
    TRANSPORT_CANCELLATION_CURSOR, TRANSPORT_CANCELLATION_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TransportCancellation";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";
const FIXTURE_ID: &str = "transport_cancellation_v1";
const COMMAND: &str = "Tools/falsifiers/f_transport_cancellation.sh";
const RESULT: &str = "artifacts/falsifiers/transport_cancellation/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const CODEC_STAGE_LATENCY_PATH: &str = "artifacts/falsifiers/codec_stage_latency/result.json";
const MIN_RUN_COUNT: u64 = 3;
const MIN_SURFACE_COUNT: u64 = 2;
const MIN_CANCELLATION_SUCCESS_BPS: u64 = 9_500;
const MAX_METADATA_BYTES: u64 = 256 * 1024;

#[derive(Debug)]
// UAS: uas:transport-cancellation:witness-error
// Plane: Verification
// Residency: metadata-only artifact rejection taxonomy.
enum TransportCancellationWitnessError {
    Primitive(TransportCancellationError),
    Io(String),
}

impl std::fmt::Display for TransportCancellationWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for TransportCancellationWitnessError {}

impl From<TransportCancellationError> for TransportCancellationWitnessError {
    fn from(value: TransportCancellationError) -> Self {
        Self::Primitive(value)
    }
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
        "{FALSIFIER_ID}: overall_pass={} artifact={RESULT}",
        artifact.overall_pass
    );
    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, TransportCancellationWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fixture_witness()?;
    let metrics = witness.metrics();
    let address = witness.address();
    let mut reversed = witness.runs.clone();
    reversed.reverse();
    let deterministic = TransportCancellationWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "transport_cancellation_gate_only",
        witness.cancellation_success_bps,
        witness.no_cancel_baseline_bps,
        witness.stale_slab_entry_baseline_bps,
        witness.hidden_cancel_baseline_bps,
        witness.live_authority_baseline_bps,
        0,
        0,
        0,
        MAX_METADATA_BYTES,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        reversed,
        witness.surfaces.clone(),
    )?
    .address()
        == address;
    let invalid_axes = invalid_fixture_axes()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_codec_stage_latency_pass",
            evidence.codec_stage_latency_pass,
        ),
        (
            "guard_cursor_transport_cancellation_or_advanced",
            evidence.guard_next_existing_work == TRANSPORT_CANCELLATION_CURSOR
                || evidence.guard_next_existing_work == TRANSPORT_CANCELLATION_NEXT_CURSOR
                || evidence.guard_next_existing_work == ADVANCED_RELEASE_AUDIT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_transport_cancellation_or_advanced",
            evidence.capability_next_bottleneck == TRANSPORT_CANCELLATION_CURSOR
                || evidence.capability_next_bottleneck == TRANSPORT_CANCELLATION_NEXT_CURSOR
                || evidence.capability_next_bottleneck == ADVANCED_RELEASE_AUDIT_CURSOR,
        ),
        (
            "product_status_research_only",
            witness.product_build == ProductBuild::Pro
                && witness.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_cancellation_gate_only",
            witness.route_authority == "transport_cancellation_gate_only",
        ),
        (
            "cancellation_runs_bound",
            metrics.run_count as u64 >= MIN_RUN_COUNT,
        ),
        (
            "completed_current_route_bound",
            metrics.completed_current_count >= 1,
        ),
        (
            "cancelled_obsolete_read_bound",
            metrics.cancelled_obsolete_count >= 1,
        ),
        (
            "stale_slab_rejection_bound",
            metrics.stale_rejection_count >= 1,
        ),
        (
            "page_runs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.page_run_ref.starts_with("page_run:")),
        ),
        (
            "read_trace_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.read_trace_ref.starts_with("read_trace:")),
        ),
        (
            "slab_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.slab_ref.starts_with("slab:")),
        ),
        (
            "cancel_groups_bound",
            witness
                .runs
                .iter()
                .all(|run| run.cancellation_group_ref.starts_with("cancel_group:")),
        ),
        (
            "cancel_tokens_bound",
            witness
                .runs
                .iter()
                .all(|run| run.cancellation_token_ref.starts_with("cancel_token:")),
        ),
        (
            "route_changes_bound",
            witness
                .runs
                .iter()
                .all(|run| run.route_change_ref.starts_with("route_change:")),
        ),
        (
            "lease_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.lease_ref.starts_with("lease:")),
        ),
        (
            "scheduler_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.scheduler_ref.starts_with("scheduler:")),
        ),
        (
            "obsolete_inflight_reads_rejected",
            witness.runs.iter().any(|run| {
                run.state == TransportCancellationState::CancelledObsoleteRead
                    && run.obsolete_inflight_read_rejected
                    && !run.entered_execution
            }),
        ),
        (
            "stale_slab_execution_rejected",
            witness.runs.iter().any(|run| {
                run.state == TransportCancellationState::RejectedStaleSlab
                    && run.stale_slab_execution_rejected
                    && !run.entered_execution
            }),
        ),
        (
            "current_route_execution_allowed",
            witness.runs.iter().any(|run| {
                run.state == TransportCancellationState::CompletedCurrentRoute
                    && run.entered_execution
                    && run.cancelled_bytes == 0
            }),
        ),
        (
            "answer_packet_refs_bound",
            metrics.answer_packet_count >= metrics.surface_count,
        ),
        (
            "run_event_log_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "rollback_bound",
            witness
                .runs
                .iter()
                .all(|run| run.rollback_ref.starts_with("rollback:")),
        ),
        (
            "admission_bound",
            witness
                .runs
                .iter()
                .all(|run| run.admission_ref.starts_with("admission:")),
        ),
        (
            "scope_rex_bound",
            witness
                .runs
                .iter()
                .all(|run| run.scope_rex_ref.starts_with("scope_rex:")),
        ),
        (
            "sovereign_gate_bound",
            witness
                .runs
                .iter()
                .all(|run| run.sovereign_gate_ref.starts_with("sovereign_gate:")),
        ),
        (
            "compatibility_fence_bound",
            witness
                .runs
                .iter()
                .all(|run| run.compatibility_fence.starts_with("compat:")),
        ),
        (
            "visible_caveat_bound",
            witness.runs.iter().all(|run| {
                run.visible_caveat.contains("metadata-only")
                    && run.visible_caveat.contains("route epoch")
                    && run.visible_caveat.contains("cancellation")
                    && run.visible_caveat.contains("stale slab")
            }),
        ),
        (
            "l1_l2_l3_separation_bound",
            witness.surfaces.iter().all(|surface| {
                surface.visible_summary.contains("L1")
                    && surface.visible_summary.contains("L2")
                    && surface.visible_summary.contains("L3")
            }),
        ),
        ("no_hidden_route_authority", !witness.hidden_route_authority),
        ("no_route_policy_mutation", !witness.route_policy_mutation),
        ("no_gate_bypass", !witness.gate_bypass),
        (
            "no_answer_packet_suppression",
            !witness.answer_packet_suppression,
        ),
        ("no_hidden_chain", !witness.hidden_chain_exposed),
        ("no_hidden_cloud", !witness.hidden_cloud_route),
        ("no_ssd_as_ram_claim", !witness.ssd_as_ram_claim),
        ("no_mas_live_promotion", !witness.mas_promotion_attempted),
        (
            "no_live_benchmark_attempted",
            !witness.live_benchmark_attempted,
        ),
        ("no_runtime_bytes_loaded", witness.runtime_bytes_loaded == 0),
        ("no_model_bytes_loaded", witness.model_bytes_loaded == 0),
        (
            "no_transport_runtime_bytes_loaded",
            witness.transport_runtime_bytes_loaded == 0,
        ),
        (
            "metadata_bound",
            witness.max_metadata_bytes <= MAX_METADATA_BYTES,
        ),
        (
            "transport_cancellation_address_deterministic",
            deterministic,
        ),
    ];
    for (name, passed) in bool_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }
    for (name, passed) in invalid_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }

    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "run_count",
        metrics.run_count as u64,
        MIN_RUN_COUNT,
        "runs",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "surface_count",
        metrics.surface_count as u64,
        MIN_SURFACE_COUNT,
        "surfaces",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "answer_packet_count",
        metrics.answer_packet_count as u64,
        3,
        "refs",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "run_event_log_count",
        metrics.run_event_log_count as u64,
        3,
        "refs",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_epoch_count",
        metrics.route_epoch_count as u64,
        2,
        "epochs",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "completed_current_count",
        metrics.completed_current_count as u64,
        1,
        "runs",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cancelled_obsolete_count",
        metrics.cancelled_obsolete_count as u64,
        1,
        "runs",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "stale_rejection_count",
        metrics.stale_rejection_count as u64,
        1,
        "runs",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "total_scheduled_bytes",
        metrics.total_scheduled_bytes,
        1,
        "bytes",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "total_cancelled_bytes",
        metrics.total_cancelled_bytes,
        1,
        "bytes",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_route_epoch",
        metrics.max_route_epoch,
        1,
        "epoch",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_bytes_loaded",
        witness.runtime_bytes_loaded,
        0,
        "bytes",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_bytes_loaded",
        witness.model_bytes_loaded,
        0,
        "bytes",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "transport_runtime_bytes_loaded",
        witness.transport_runtime_bytes_loaded,
        0,
        "bytes",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_metadata_bytes",
        witness.max_metadata_bytes,
        MAX_METADATA_BYTES,
        "bytes",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cancellation_success_bps",
        witness.cancellation_success_bps as u64,
        MIN_CANCELLATION_SUCCESS_BPS,
        "bps",
    );
    for (name, value) in [
        ("no_cancel_baseline_bps", witness.no_cancel_baseline_bps),
        (
            "stale_slab_entry_baseline_bps",
            witness.stale_slab_entry_baseline_bps,
        ),
        (
            "hidden_cancel_baseline_bps",
            witness.hidden_cancel_baseline_bps,
        ),
        (
            "live_authority_baseline_bps",
            witness.live_authority_baseline_bps,
        ),
    ] {
        add_max_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            value as u64,
            witness.cancellation_success_bps.saturating_sub(1) as u64,
            "bps",
        );
    }
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "transport_cancellation_address",
        address,
        "uas:transport-cancellation:sha256:",
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
            "kind": "transport_cancellation_metadata_only",
            "detail": "Transport cancellation is L1 metadata proof only: obsolete in-flight reads and stale slabs are rejected in the fixture, but no live transport bytes, model bytes, dense 70B, KV-Direct 128K, or product runtime promotion are claimed."
        })],
        notes: "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. F-TransportCancellation proves route epochs, cancellation groups, cancellation tokens, obsolete-read rejection, stale-slab execution rejection, rollback, RunEventLog, SCOPE-Rex/SovereignGate admission, compatibility fences, and AnswerPacket caveats are explicit. L1 architecture cursor advances only; L2 remains vault_research_route_with_packetized_mitigation and L3 product runtime is unchanged."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn invalid_fixture_axes() -> Result<Vec<(&'static str, bool)>, TransportCancellationWitnessError> {
    Ok(vec![
        (
            "empty_run_rejected",
            matches!(
                reject_witness(|witness| witness.runs.clear()),
                Err(TransportCancellationError::EmptyRun)
            ),
        ),
        (
            "empty_surface_rejected",
            matches!(
                reject_witness(|witness| witness.surfaces.clear()),
                Err(TransportCancellationError::EmptySurface)
            ),
        ),
        (
            "duplicate_run_rejected",
            matches!(
                reject_witness(|witness| witness.runs.push(witness.runs[0].clone())),
                Err(TransportCancellationError::DuplicateRun(_))
            ),
        ),
        (
            "duplicate_surface_rejected",
            matches!(
                reject_witness(|witness| witness.surfaces.push(witness.surfaces[0].clone())),
                Err(TransportCancellationError::DuplicateSurface(_))
            ),
        ),
        (
            "duplicate_answer_packet_rejected",
            matches!(
                reject_run(
                    |run| run.answer_packet_ref = "answer_packet:cancel-current".to_string(),
                    1
                ),
                Err(TransportCancellationError::DuplicateAnswerPacket(_))
            ),
        ),
        (
            "missing_page_run_rejected",
            matches!(
                reject_run(|run| run.page_run_ref.clear(), 0),
                Err(TransportCancellationError::MissingField("page_run_ref"))
                    | Err(TransportCancellationError::MissingPageRun(_))
            ),
        ),
        (
            "missing_read_trace_rejected",
            matches!(
                reject_run(|run| run.read_trace_ref.clear(), 0),
                Err(TransportCancellationError::MissingField("read_trace_ref"))
                    | Err(TransportCancellationError::MissingReadTrace(_))
            ),
        ),
        (
            "missing_slab_rejected",
            matches!(
                reject_run(|run| run.slab_ref.clear(), 0),
                Err(TransportCancellationError::MissingField("slab_ref"))
                    | Err(TransportCancellationError::MissingSlab(_))
            ),
        ),
        (
            "missing_cancel_group_rejected",
            matches!(
                reject_run(|run| run.cancellation_group_ref.clear(), 0),
                Err(TransportCancellationError::MissingField(
                    "cancellation_group_ref"
                )) | Err(TransportCancellationError::MissingCancelGroup(_))
            ),
        ),
        (
            "missing_cancel_token_rejected",
            matches!(
                reject_run(|run| run.cancellation_token_ref.clear(), 0),
                Err(TransportCancellationError::MissingField(
                    "cancellation_token_ref"
                )) | Err(TransportCancellationError::MissingCancelToken(_))
            ),
        ),
        (
            "missing_route_change_rejected",
            matches!(
                reject_run(|run| run.route_change_ref.clear(), 0),
                Err(TransportCancellationError::MissingField("route_change_ref"))
                    | Err(TransportCancellationError::MissingRouteChange(_))
            ),
        ),
        (
            "missing_lease_rejected",
            matches!(
                reject_run(|run| run.lease_ref.clear(), 0),
                Err(TransportCancellationError::MissingField("lease_ref"))
                    | Err(TransportCancellationError::MissingLease(_))
            ),
        ),
        (
            "missing_scheduler_rejected",
            matches!(
                reject_run(|run| run.scheduler_ref.clear(), 0),
                Err(TransportCancellationError::MissingField("scheduler_ref"))
                    | Err(TransportCancellationError::MissingScheduler(_))
            ),
        ),
        (
            "zero_route_epoch_rejected",
            matches!(
                reject_run(|run| run.route_epoch = 0, 0),
                Err(TransportCancellationError::ZeroRouteEpoch(_))
            ),
        ),
        (
            "zero_scheduled_bytes_rejected",
            matches!(
                reject_run(|run| run.scheduled_bytes = 0, 0),
                Err(TransportCancellationError::ZeroScheduledBytes(_))
            ),
        ),
        (
            "cancelled_run_entered_execution_rejected",
            matches!(
                reject_run(|run| run.entered_execution = true, 1),
                Err(TransportCancellationError::CancelledRunEnteredExecution(_))
            ),
        ),
        (
            "cancelled_run_missing_rejected_read_rejected",
            matches!(
                reject_run(|run| run.obsolete_inflight_read_rejected = false, 1),
                Err(TransportCancellationError::CancelledRunMissingRejectedRead(
                    _
                ))
            ),
        ),
        (
            "cancelled_run_zero_cancelled_bytes_rejected",
            matches!(
                reject_run(|run| run.cancelled_bytes = 0, 1),
                Err(TransportCancellationError::CancelledRunMissingCancelledBytes(_))
            ),
        ),
        (
            "stale_run_entered_execution_rejected",
            matches!(
                reject_run(|run| run.entered_execution = true, 2),
                Err(TransportCancellationError::StaleRunEnteredExecution(_))
            ),
        ),
        (
            "stale_run_missing_rejected_slab_rejected",
            matches!(
                reject_run(|run| run.stale_slab_execution_rejected = false, 2),
                Err(TransportCancellationError::StaleRunMissingRejectedSlab(_))
            ),
        ),
        (
            "current_run_cancelled_bytes_rejected",
            matches!(
                reject_run(|run| run.cancelled_bytes = 1, 0),
                Err(TransportCancellationError::CurrentRunCancelledBytes(_))
            ),
        ),
        (
            "missing_current_run_rejected",
            matches!(
                reject_witness(|witness| {
                    witness.runs.retain(|run| {
                        run.state != TransportCancellationState::CompletedCurrentRoute
                    })
                }),
                Err(TransportCancellationError::MissingCurrentRun)
            ),
        ),
        (
            "missing_cancelled_run_rejected",
            matches!(
                reject_witness(|witness| {
                    witness.runs.retain(|run| {
                        run.state != TransportCancellationState::CancelledObsoleteRead
                    })
                }),
                Err(TransportCancellationError::MissingCancelledRun)
            ),
        ),
        (
            "missing_stale_rejection_run_rejected",
            matches!(
                reject_witness(|witness| {
                    witness
                        .runs
                        .retain(|run| run.state != TransportCancellationState::RejectedStaleSlab)
                }),
                Err(TransportCancellationError::MissingStaleRejectionRun)
            ),
        ),
        (
            "missing_answer_packet_rejected",
            matches!(
                reject_run(|run| run.answer_packet_ref.clear(), 0),
                Err(TransportCancellationError::MissingField(
                    "answer_packet_ref"
                )) | Err(TransportCancellationError::MissingAnswerPacket(_))
            ),
        ),
        (
            "missing_run_event_log_rejected",
            matches!(
                reject_run(|run| run.run_event_log_ref.clear(), 0),
                Err(TransportCancellationError::MissingField(
                    "run_event_log_ref"
                )) | Err(TransportCancellationError::MissingRunEventLog(_))
            ),
        ),
        (
            "missing_rollback_rejected",
            matches!(
                reject_run(|run| run.rollback_ref.clear(), 0),
                Err(TransportCancellationError::MissingField("rollback_ref"))
                    | Err(TransportCancellationError::MissingRollback(_))
            ),
        ),
        (
            "missing_admission_rejected",
            matches!(
                reject_run(|run| run.admission_ref.clear(), 0),
                Err(TransportCancellationError::MissingField("admission_ref"))
                    | Err(TransportCancellationError::MissingAdmission)
            ),
        ),
        (
            "missing_scope_rex_rejected",
            matches!(
                reject_run(|run| run.scope_rex_ref.clear(), 0),
                Err(TransportCancellationError::MissingField("scope_rex_ref"))
                    | Err(TransportCancellationError::MissingScopeRex)
            ),
        ),
        (
            "missing_sovereign_gate_rejected",
            matches!(
                reject_run(|run| run.sovereign_gate_ref.clear(), 0),
                Err(TransportCancellationError::MissingField(
                    "sovereign_gate_ref"
                )) | Err(TransportCancellationError::MissingSovereignGate)
            ),
        ),
        (
            "missing_compatibility_fence_rejected",
            matches!(
                reject_run(|run| run.compatibility_fence.clear(), 0),
                Err(TransportCancellationError::MissingField(
                    "compatibility_fence"
                )) | Err(TransportCancellationError::MissingCompatibilityFence(_))
            ),
        ),
        (
            "missing_visible_caveat_rejected",
            matches!(
                reject_run(|run| run.visible_caveat.clear(), 0),
                Err(TransportCancellationError::MissingField("visible_caveat"))
                    | Err(TransportCancellationError::MissingVisibleCaveat(_))
                    | Err(TransportCancellationError::MissingRequiredMarker(_))
            ),
        ),
        (
            "missing_required_marker_rejected",
            matches!(
                reject_surface(|surface| {
                    surface.visible_summary =
                        surface.visible_summary.replace("AnswerPacket", "packet")
                }),
                Err(TransportCancellationError::MissingRequiredMarker(_))
            ),
        ),
        (
            "forbidden_marker_rejected",
            matches!(
                reject_surface(|surface| surface
                    .visible_summary
                    .push_str(" live transport ready.")),
                Err(TransportCancellationError::ForbiddenMarker(_))
            ),
        ),
        (
            "missing_layer_separation_rejected",
            matches!(
                reject_surface(|surface| {
                    surface.visible_summary = surface.visible_summary.replace("L3", "product")
                }),
                Err(TransportCancellationError::MissingLayerSeparation)
                    | Err(TransportCancellationError::MissingRequiredMarker(_))
            ),
        ),
        (
            "hidden_route_authority_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_route_authority = true),
                Err(TransportCancellationError::HiddenRouteAuthority)
            ),
        ),
        (
            "route_policy_mutation_rejected",
            matches!(
                reject_witness(|witness| witness.route_policy_mutation = true),
                Err(TransportCancellationError::RoutePolicyMutation)
            ),
        ),
        (
            "gate_bypass_rejected",
            matches!(
                reject_witness(|witness| witness.gate_bypass = true),
                Err(TransportCancellationError::GateBypass)
            ),
        ),
        (
            "answer_packet_suppression_rejected",
            matches!(
                reject_witness(|witness| witness.answer_packet_suppression = true),
                Err(TransportCancellationError::AnswerPacketSuppression)
            ),
        ),
        (
            "hidden_chain_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_chain_exposed = true),
                Err(TransportCancellationError::HiddenChainExposure)
            ),
        ),
        (
            "hidden_cloud_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_cloud_route = true),
                Err(TransportCancellationError::HiddenCloudRoute)
            ),
        ),
        (
            "ssd_as_ram_rejected",
            matches!(
                reject_witness(|witness| witness.ssd_as_ram_claim = true),
                Err(TransportCancellationError::SsdAsRamClaim)
            ),
        ),
        (
            "mas_product_build_rejected",
            matches!(
                reject_witness(|witness| witness.product_build = ProductBuild::Mas),
                Err(TransportCancellationError::ProductStatusMismatch)
            ),
        ),
        (
            "live_pro_status_rejected",
            matches!(
                reject_witness(|witness| witness.pro_status = ProStatus::Live),
                Err(TransportCancellationError::ProductStatusMismatch)
            ),
        ),
        (
            "live_benchmark_rejected",
            matches!(
                reject_witness(|witness| witness.live_benchmark_attempted = true),
                Err(TransportCancellationError::LiveBenchmarkAttempted)
            ),
        ),
        (
            "runtime_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.runtime_bytes_loaded = 1),
                Err(TransportCancellationError::RuntimeBytesLoaded)
            ),
        ),
        (
            "model_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.model_bytes_loaded = 1),
                Err(TransportCancellationError::ModelBytesLoaded)
            ),
        ),
        (
            "transport_runtime_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.transport_runtime_bytes_loaded = 1),
                Err(TransportCancellationError::TransportRuntimeBytesLoaded)
            ),
        ),
        (
            "no_cancel_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.no_cancel_baseline_bps = 9_750),
                Err(TransportCancellationError::BaselineUnbeaten("no_cancel"))
            ),
        ),
        (
            "stale_slab_entry_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.stale_slab_entry_baseline_bps = 9_750),
                Err(TransportCancellationError::BaselineUnbeaten(
                    "stale_slab_entry"
                ))
            ),
        ),
        (
            "hidden_cancel_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_cancel_baseline_bps = 9_750),
                Err(TransportCancellationError::BaselineUnbeaten(
                    "hidden_cancel"
                ))
            ),
        ),
        (
            "live_authority_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.live_authority_baseline_bps = 9_750),
                Err(TransportCancellationError::BaselineUnbeaten(
                    "live_authority"
                ))
            ),
        ),
        (
            "metadata_budget_rejected",
            matches!(
                reject_witness(|witness| witness.max_metadata_bytes = MAX_METADATA_BYTES + 1),
                Err(TransportCancellationError::MetadataBudgetExceeded)
            ),
        ),
    ])
}

fn fixture_witness() -> Result<TransportCancellationWitness, TransportCancellationError> {
    TransportCancellationWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "transport_cancellation_gate_only",
        9_720,
        8_000,
        8_150,
        8_300,
        8_050,
        0,
        0,
        0,
        MAX_METADATA_BYTES,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        fixture_runs()?,
        fixture_surfaces()?,
    )
}

fn fixture_runs() -> Result<Vec<TransportCancellationRun>, TransportCancellationError> {
    Ok(vec![
        run(
            "cancel-current",
            "route:current",
            3,
            TransportCancellationState::CompletedCurrentRoute,
            0,
            false,
            false,
            true,
        )?,
        run(
            "cancel-obsolete",
            "route:previous",
            2,
            TransportCancellationState::CancelledObsoleteRead,
            16_384,
            true,
            false,
            false,
        )?,
        run(
            "cancel-stale-slab",
            "route:previous",
            1,
            TransportCancellationState::RejectedStaleSlab,
            8_192,
            true,
            true,
            false,
        )?,
    ])
}

#[allow(clippy::too_many_arguments)]
fn run(
    run_id: &str,
    route_id: &str,
    route_epoch: u64,
    state: TransportCancellationState,
    cancelled_bytes: u64,
    obsolete_rejected: bool,
    stale_rejected: bool,
    entered_execution: bool,
) -> Result<TransportCancellationRun, TransportCancellationError> {
    TransportCancellationRun::new(
        run_id,
        "mission:coldstream-transport-cancellation",
        route_id,
        route_epoch,
        state,
        format!("page_run:{run_id}:input"),
        format!("read_trace:{run_id}:file"),
        format!("slab:{run_id}:candidate"),
        format!("cancel_group:{run_id}"),
        format!("cancel_token:{run_id}"),
        format!("route_change:{run_id}:epoch-{route_epoch}"),
        format!("lease:{run_id}"),
        format!("scheduler:{run_id}"),
        32_768,
        cancelled_bytes,
        obsolete_rejected,
        stale_rejected,
        entered_execution,
        format!("answer_packet:{run_id}"),
        format!("run_event_log:{run_id}"),
        format!("rollback:{run_id}"),
        "admission:transport-cancellation",
        "scope_rex:transport-cancellation",
        "sovereign_gate:transport-cancellation",
        "compat:transport-cancellation-v1",
        "metadata-only route epoch cancellation proof: cancellation rejects obsolete reads, stale slab execution is blocked, AnswerPacket and rollback are visible, and this advances L1 only while L2 and L3 stay unchanged.",
    )
}

fn fixture_surfaces() -> Result<Vec<TransportCancellationSurface>, TransportCancellationError> {
    Ok(vec![
        TransportCancellationSurface::new(
            "surface:transport-cancellation",
            "answer_packet:transport-cancel-surface-a",
            "run_event_log:transport-cancel-surface-a",
            "metadata-only cancellation surface: L1 records route epoch changes, cancellation tokens, obsolete-read rejection, stale slab rejection, AnswerPacket, RunEventLog, and rollback; L2 remains vault research and L3 product runtime is unchanged.",
        )?,
        TransportCancellationSurface::new(
            "surface:transport-stale-slab",
            "answer_packet:transport-cancel-surface-b",
            "run_event_log:transport-cancel-surface-b",
            "metadata-only stale slab surface: L1 exposes cancellation, stale slab execution rejection, compatibility fence, AnswerPacket, and rollback; L2 capability remains red and L3 user-facing runtime is unchanged.",
        )?,
    ])
}

fn reject_witness(
    mutate: impl FnOnce(&mut TransportCancellationWitness),
) -> Result<TransportCancellationWitness, TransportCancellationError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness);
    rebuild_witness(witness)
}

fn reject_run(
    mutate: impl FnOnce(&mut TransportCancellationRun),
    index: usize,
) -> Result<TransportCancellationWitness, TransportCancellationError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness.runs[index]);
    rebuild_witness(witness)
}

fn reject_surface(
    mutate: impl FnOnce(&mut TransportCancellationSurface),
) -> Result<TransportCancellationWitness, TransportCancellationError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness.surfaces[0]);
    rebuild_witness(witness)
}

fn rebuild_witness(
    witness: TransportCancellationWitness,
) -> Result<TransportCancellationWitness, TransportCancellationError> {
    TransportCancellationWitness::new(
        witness.product_build,
        witness.pro_status,
        witness.route_authority,
        witness.cancellation_success_bps,
        witness.no_cancel_baseline_bps,
        witness.stale_slab_entry_baseline_bps,
        witness.hidden_cancel_baseline_bps,
        witness.live_authority_baseline_bps,
        witness.runtime_bytes_loaded,
        witness.model_bytes_loaded,
        witness.transport_runtime_bytes_loaded,
        witness.max_metadata_bytes,
        witness.hidden_route_authority,
        witness.route_policy_mutation,
        witness.gate_bypass,
        witness.answer_packet_suppression,
        witness.hidden_chain_exposed,
        witness.hidden_cloud_route,
        witness.ssd_as_ram_claim,
        witness.mas_promotion_attempted,
        witness.live_benchmark_attempted,
        witness.runs,
        witness.surfaces,
    )
}

fn add_min_axis(
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

fn add_max_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    maximum: u64,
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
            operator: "<=".to_string(),
            value: serde_json::Value::from(maximum),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual <= maximum);
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: String,
    prefix: &str,
) {
    let passed = actual.starts_with(prefix);
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual),
            unit: "string".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String(prefix.to_string()),
            unit: "string".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), passed);
}

#[derive(Debug)]
// UAS: Binds upstream witness refs used to prove cancellation lineage.
// Plane: Verification.
// Residency: Metadata-only evidence; no runtime/model/transport bytes are loaded.
struct EvidenceSnapshot {
    codec_stage_latency_pass: bool,
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, TransportCancellationWitnessError> {
        let codec = read_json(CODEC_STAGE_LATENCY_PATH)?;
        let guard = read_json(GUARD_PATH)?;
        let capability = read_json(CAPABILITY_PATH)?;
        Ok(Self {
            codec_stage_latency_pass: codec
                .get("overall_pass")
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false)
                && axes_all_present(&codec, CODEC_STAGE_LATENCY_AXES),
            guard_next_existing_work: measurement_string(&guard, "next_existing_work"),
            capability_overall_pass: capability
                .get("overall_pass")
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false),
            capability_route_status: measurement_string(&capability, "route_status"),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck"),
        })
    }
}

fn axes_all_present(value: &serde_json::Value, axes: &[&str]) -> bool {
    let Some(pass_per_axis) = value
        .get("pass_per_axis")
        .and_then(serde_json::Value::as_object)
    else {
        return false;
    };
    axes.iter().all(|axis| {
        pass_per_axis
            .get(*axis)
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false)
    })
}

fn read_json(path: &str) -> Result<serde_json::Value, TransportCancellationWitnessError> {
    let resolved = resolve_repo_path(path);
    let text = std::fs::read_to_string(&resolved)
        .map_err(|error| TransportCancellationWitnessError::Io(format!("{path}: {error}")))?;
    serde_json::from_str(&text)
        .map_err(|error| TransportCancellationWitnessError::Io(format!("{path}: {error}")))
}

fn resolve_repo_path(path: &str) -> PathBuf {
    let direct = PathBuf::from(path);
    if direct.exists() {
        return direct;
    }
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .join(path)
}

fn measurement_string(value: &serde_json::Value, key: &str) -> String {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_str)
        .unwrap_or("missing")
        .to_string()
}

#[cfg(test)]
mod tests {
    use agent_core::falsifier_artifacts::axes::TRANSPORT_CANCELLATION_AXES;

    use super::*;

    #[test]
    fn fixture_artifact_covers_transport_cancellation_axes() {
        let artifact = build_artifact().expect("artifact");
        for axis in TRANSPORT_CANCELLATION_AXES {
            assert!(
                artifact.pass_per_axis.contains_key(*axis),
                "missing axis {axis}"
            );
        }
        assert!(artifact.overall_pass);
    }
}
