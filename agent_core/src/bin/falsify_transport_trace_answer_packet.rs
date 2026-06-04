//! `falsify_transport_trace_answer_packet`.
//!
//! Metadata-only witness for `F-TransportTrace-AnswerPacket`. It proves
//! transport-shaped answers bind ColdStream trace bytes, stalls, copies,
//! fallback, rollback, RunEventLog, and AnswerPacket caveats before any cold
//! material can affect visible output. No runtime, model, mmap, Metal, or MLX
//! bytes move here.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[cfg(test)]
use agent_core::falsifier_artifacts::axes::TRANSPORT_TRACE_ANSWER_PACKET_AXES;
use agent_core::falsifier_artifacts::axes::{
    COLDSTREAM_NO_HIDDEN_AUTHORITY_AXES, PROVIDER_ROUTE_COPY_SOURCE_GUARD_AXES,
};
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ColdStreamAuthority, ColdStreamCachePolicy, ColdStreamDestination, ColdStreamPageRun,
    ColdStreamPriority, ColdStreamTransportManifest, ColdStreamTransportTrace, ProStatus,
    ProductBuild, TransportTraceAnswerPacketError, TransportTraceAnswerPacketFrame,
    TransportTraceAnswerPacketSurface, TransportTraceAnswerPacketWitness,
    TransportTraceVisibilityLane, UasAddress, UasKind, TRANSPORT_TRACE_ANSWER_PACKET_CURSOR,
    TRANSPORT_TRACE_ANSWER_PACKET_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TransportTrace-AnswerPacket";
const FIXTURE_ID: &str = "transport_trace_answer_packet_v1";
const COMMAND: &str = "Tools/falsifiers/f_transport_trace_answer_packet.sh";
const RESULT: &str = "artifacts/falsifiers/transport_trace_answer_packet/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const COLDSTREAM_PATH: &str = "artifacts/falsifiers/coldstream_no_hidden_authority/result.json";
const PROVIDER_GUARD_PATH: &str =
    "artifacts/falsifiers/provider_route_copy_source_guard/result.json";
const CREATED_AT_MS: u64 = 1_779_552_000_000;
const MIN_FRAME_COUNT: u64 = 3;
const MIN_VISIBILITY_LANE_COUNT: u64 = 3;
const MIN_TRACE_BYTES: u64 = 384 * 1024;
const MAX_COPY_COUNT: u64 = 2;
const MAX_READ_AMPLIFICATION_BPS: u64 = 16_000;
const MAX_METADATA_BYTES: u64 = 256 * 1024;

#[derive(Debug)]
// UAS: uas:transport-trace-answer-packet:witness-error
// Plane: Verification
// Residency: metadata-only witness rejection taxonomy.
enum TransportTraceWitnessError {
    Primitive(TransportTraceAnswerPacketError),
    ColdStream(agent_core::uas::ColdStreamError),
    Io(String),
}

impl std::fmt::Display for TransportTraceWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::ColdStream(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for TransportTraceWitnessError {}

impl From<TransportTraceAnswerPacketError> for TransportTraceWitnessError {
    fn from(value: TransportTraceAnswerPacketError) -> Self {
        Self::Primitive(value)
    }
}

impl From<agent_core::uas::ColdStreamError> for TransportTraceWitnessError {
    fn from(value: agent_core::uas::ColdStreamError) -> Self {
        Self::ColdStream(value)
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, TransportTraceWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fixture_witness()?;
    let metrics = witness.metrics();
    let address = witness.address();
    let mut reversed_frames = witness.frames.clone();
    reversed_frames.reverse();
    let deterministic = TransportTraceAnswerPacketWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "visible_trace_only",
        reversed_frames,
        witness.surfaces.clone(),
        metrics.hidden_summary_baseline_bps,
        metrics.no_answer_packet_baseline_bps,
        metrics.invisible_fallback_baseline_bps,
        metrics.live_authority_baseline_bps,
    )?
    .address()
        == address;
    let invalid_axes = invalid_fixture_axes()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_coldstream_no_hidden_authority_pass",
            evidence.coldstream_pass,
        ),
        (
            "upstream_provider_route_copy_source_guard_pass",
            evidence.provider_guard_pass,
        ),
        (
            "guard_cursor_transport_trace_or_advanced",
            evidence.guard_next_existing_work == TRANSPORT_TRACE_ANSWER_PACKET_CURSOR
                || evidence.guard_next_existing_work == TRANSPORT_TRACE_ANSWER_PACKET_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_transport_trace_or_advanced",
            evidence.capability_next_bottleneck == TRANSPORT_TRACE_ANSWER_PACKET_CURSOR
                || evidence.capability_next_bottleneck == TRANSPORT_TRACE_ANSWER_PACKET_NEXT_CURSOR,
        ),
        (
            "product_status_research_only",
            witness.product_build == ProductBuild::Pro
                && witness.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_visible_trace_only",
            witness.route_authority == "visible_trace_only",
        ),
        (
            "answer_packet_refs_bound",
            metrics.answer_packet_count == metrics.frame_count
                && witness
                    .frames
                    .iter()
                    .all(|frame| frame.answer_packet_ref.starts_with("answer_packet:")),
        ),
        (
            "run_event_log_refs_bound",
            metrics.run_event_log_count == metrics.frame_count
                && witness
                    .frames
                    .iter()
                    .all(|frame| frame.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "fallback_refs_bound",
            metrics.fallback_count == metrics.frame_count
                && witness
                    .frames
                    .iter()
                    .all(|frame| frame.fallback_ref.starts_with("fallback:")),
        ),
        (
            "rollback_bound",
            witness
                .frames
                .iter()
                .all(|frame| frame.rollback_ref.starts_with("rollback:")),
        ),
        (
            "admission_bound",
            witness
                .frames
                .iter()
                .all(|frame| frame.admission_ref.starts_with("admission:")),
        ),
        (
            "scope_rex_bound",
            witness
                .frames
                .iter()
                .all(|frame| frame.scope_rex_ref.starts_with("scope_rex:")),
        ),
        (
            "sovereign_gate_bound",
            witness
                .frames
                .iter()
                .all(|frame| frame.sovereign_gate_ref.starts_with("sovereign_gate:")),
        ),
        (
            "compatibility_fence_bound",
            witness
                .frames
                .iter()
                .all(|frame| frame.compatibility_fence.starts_with("compat:")),
        ),
        (
            "codec_stage_bound",
            witness
                .frames
                .iter()
                .all(|frame| frame.codec_stage_ref.starts_with("codec_stage:")),
        ),
        (
            "cache_policy_bound",
            witness
                .frames
                .iter()
                .all(|frame| frame.cache_policy_ref.starts_with("cache_policy:")),
        ),
        (
            "cancellation_group_bound",
            witness
                .frames
                .iter()
                .all(|frame| frame.cancellation_group.starts_with("cancel_group:")),
        ),
        (
            "material_frames_bound",
            witness.frames.iter().all(|frame| frame.material_to_answer),
        ),
        (
            "visible_summary_bound",
            metrics.visible_summary_count == metrics.frame_count,
        ),
        (
            "fallback_caveat_bound",
            metrics.fallback_caveat_count == metrics.frame_count,
        ),
        (
            "l1_l2_l3_separation_bound",
            witness.frames.iter().all(|frame| frame.l1_l2_l3_separated),
        ),
        (
            "read_amplification_bound",
            metrics.min_read_amplification_bps >= 10_000
                && metrics.min_read_amplification_bps <= MAX_READ_AMPLIFICATION_BPS,
        ),
        ("copy_count_bound", metrics.max_copy_count <= MAX_COPY_COUNT),
        (
            "no_hidden_route_authority",
            witness
                .frames
                .iter()
                .all(|frame| !frame.hidden_route_authority),
        ),
        (
            "no_route_policy_mutation",
            witness
                .frames
                .iter()
                .all(|frame| !frame.route_policy_mutated),
        ),
        (
            "no_scope_rex_bypass",
            witness.frames.iter().all(|frame| !frame.scope_rex_bypassed),
        ),
        (
            "no_sovereign_gate_bypass",
            witness
                .frames
                .iter()
                .all(|frame| !frame.sovereign_gate_bypassed),
        ),
        (
            "no_answer_packet_suppression",
            witness
                .frames
                .iter()
                .all(|frame| !frame.answer_packet_suppressed),
        ),
        (
            "no_fallback_caveat_suppression",
            witness
                .frames
                .iter()
                .all(|frame| !frame.fallback_caveat_suppressed),
        ),
        (
            "no_hidden_chain",
            witness
                .frames
                .iter()
                .all(|frame| !frame.hidden_chain_exposed),
        ),
        (
            "no_hidden_cloud",
            witness.frames.iter().all(|frame| !frame.hidden_cloud_route),
        ),
        ("no_runtime_bytes_loaded", metrics.runtime_bytes_loaded == 0),
        ("no_model_bytes_loaded", metrics.model_bytes_loaded == 0),
        (
            "metadata_bound",
            metrics.max_metadata_bytes <= MAX_METADATA_BYTES,
        ),
        (
            "transport_trace_answer_packet_address_deterministic",
            deterministic,
        ),
    ];
    for (axis, passed) in bool_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            passed,
        );
    }
    for (axis, passed) in invalid_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            passed,
        );
    }
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "frame_count",
        metrics.frame_count,
        MIN_FRAME_COUNT,
        "frames",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "surface_count",
        metrics.surface_count,
        MIN_FRAME_COUNT,
        "surfaces",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "answer_packet_count",
        metrics.answer_packet_count,
        MIN_FRAME_COUNT,
        "packets",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "run_event_log_count",
        metrics.run_event_log_count,
        MIN_FRAME_COUNT,
        "logs",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fallback_count",
        metrics.fallback_count,
        MIN_FRAME_COUNT,
        "fallbacks",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "visibility_lane_count",
        metrics.visibility_lane_count,
        MIN_VISIBILITY_LANE_COUNT,
        "lanes",
    );
    for (axis, actual, operator, expected, unit) in [
        (
            "bytes_requested",
            metrics.bytes_requested,
            ">=",
            MIN_TRACE_BYTES,
            "bytes",
        ),
        (
            "bytes_read",
            metrics.bytes_read,
            ">=",
            MIN_TRACE_BYTES,
            "bytes",
        ),
        (
            "bytes_decoded",
            metrics.bytes_decoded,
            ">=",
            MIN_TRACE_BYTES,
            "bytes",
        ),
        (
            "copied_bytes",
            metrics.copied_bytes,
            ">=",
            MIN_TRACE_BYTES,
            "bytes",
        ),
        (
            "max_copy_count",
            metrics.max_copy_count,
            "<=",
            MAX_COPY_COUNT,
            "copies",
        ),
        (
            "cancellation_count",
            metrics.cancellation_count,
            ">=",
            MIN_FRAME_COUNT,
            "cancellations",
        ),
        ("max_p95_stall_ms", metrics.max_p95_stall_ms, ">", 0, "ms"),
        ("max_p99_stall_ms", metrics.max_p99_stall_ms, ">", 0, "ms"),
        (
            "min_read_amplification_bps",
            metrics.min_read_amplification_bps,
            "<=",
            MAX_READ_AMPLIFICATION_BPS,
            "bps",
        ),
        (
            "visible_summary_count",
            metrics.visible_summary_count,
            ">=",
            MIN_FRAME_COUNT,
            "summaries",
        ),
        (
            "fallback_caveat_count",
            metrics.fallback_caveat_count,
            ">=",
            MIN_FRAME_COUNT,
            "caveats",
        ),
        (
            "runtime_bytes_loaded",
            metrics.runtime_bytes_loaded,
            "<=",
            0,
            "bytes",
        ),
        (
            "model_bytes_loaded",
            metrics.model_bytes_loaded,
            "<=",
            0,
            "bytes",
        ),
        (
            "max_metadata_bytes",
            metrics.max_metadata_bytes,
            "<=",
            MAX_METADATA_BYTES,
            "bytes",
        ),
        (
            "hidden_summary_baseline_bps",
            metrics.hidden_summary_baseline_bps,
            "<",
            9_000,
            "bps",
        ),
        (
            "no_answer_packet_baseline_bps",
            metrics.no_answer_packet_baseline_bps,
            "<",
            9_000,
            "bps",
        ),
        (
            "invisible_fallback_baseline_bps",
            metrics.invisible_fallback_baseline_bps,
            "<",
            9_000,
            "bps",
        ),
        (
            "live_authority_baseline_bps",
            metrics.live_authority_baseline_bps,
            "<",
            9_000,
            "bps",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            actual,
            operator,
            expected,
            unit,
        );
    }
    measurements.insert(
        "transport_trace_answer_packet_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address.clone()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "transport_trace_answer_packet_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String(
                "uas:transport-trace-answer-packet:sha256:".to_string(),
            ),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "transport_trace_answer_packet_address".to_string(),
        address.starts_with("uas:transport-trace-answer-packet:sha256:"),
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
            "kind": "metadata_only_transport_trace_answer_packet",
            "detail": "Binds ColdStream TransportTrace material to RunEventLog and visible AnswerPacket caveats; no live transport, mmap replacement, 70B runtime, provider route, or product promotion is proven."
        })],
        notes: "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. F-TransportTrace-AnswerPacket is metadata-only: transported/cold material cannot silently affect an answer without byte accounting, stall/copy metrics, fallback caveat, rollback, RunEventLog, and AnswerPacket proof.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();
    Ok(artifact)
}

fn fixture_witness() -> Result<TransportTraceAnswerPacketWitness, TransportTraceWitnessError> {
    let specs = [
        (
            "cpu",
            ColdStreamDestination::CpuSlab,
            ColdStreamPriority::Urgent,
            ColdStreamCachePolicy::NoCache,
            TransportTraceVisibilityLane::CpuSlab,
            11,
            19,
        ),
        (
            "metal",
            ColdStreamDestination::MetalBuffer,
            ColdStreamPriority::Prefetch,
            ColdStreamCachePolicy::Default,
            TransportTraceVisibilityLane::MetalFallback,
            13,
            23,
        ),
        (
            "mlx",
            ColdStreamDestination::MlxReadySlab,
            ColdStreamPriority::Background,
            ColdStreamCachePolicy::HotReuse,
            TransportTraceVisibilityLane::MlxReadySlab,
            17,
            29,
        ),
    ];
    let mut frames = Vec::with_capacity(specs.len());
    for (id, destination, priority, cache_policy, lane, p95, p99) in specs {
        let manifest = manifest(id, destination, priority, cache_policy)?;
        let trace = trace(&manifest, &format!("trace-{id}"), p95, p99)?;
        frames.push(frame(&manifest, &trace, &format!("frame-{id}"), lane)?);
    }
    let surfaces = frames
        .iter()
        .map(|frame| {
            TransportTraceAnswerPacketSurface::new(
                format!("surface-{}", frame.frame_id),
                frame.answer_packet_ref.clone(),
                frame.user_visible_summary.clone(),
                vec![
                    "AnswerPacket".to_string(),
                    "bytes".to_string(),
                    "stall".to_string(),
                    "fallback".to_string(),
                    "caveat".to_string(),
                    "not a live 70B route".to_string(),
                ],
                forbidden_markers(),
            )
        })
        .collect::<Result<Vec<_>, _>>()?;
    Ok(TransportTraceAnswerPacketWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "visible_trace_only",
        frames,
        surfaces,
        4_200,
        3_600,
        4_100,
        4_500,
    )?)
}

fn frame(
    manifest: &ColdStreamTransportManifest,
    trace: &ColdStreamTransportTrace,
    frame_id: &str,
    lane: TransportTraceVisibilityLane,
) -> Result<TransportTraceAnswerPacketFrame, TransportTraceAnswerPacketError> {
    TransportTraceAnswerPacketFrame::from_manifest_trace(
        manifest,
        trace,
        frame_id,
        lane,
        trace.bytes_decoded * u64::from(trace.copy_count),
        format!("codec_stage:{frame_id}:decode"),
        format!("cache_policy:{frame_id}:declared"),
        "cold transport fallback remained visible with rollback: degraded to a bounded local route when deadline risk rose",
        format!(
            "AnswerPacket transport caveat: cold transport read {} bytes, p99 stall {} ms, copies {}, fallback visible, caveat retained, RunEventLog bound, not a live 70B route.",
            trace.bytes_requested, trace.p99_stall_ms, trace.copy_count
        ),
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        0,
        0,
        24 * 1024,
    )
}

fn invalid_fixture_axes() -> Result<Vec<(&'static str, bool)>, TransportTraceWitnessError> {
    let witness = fixture_witness()?;
    let mut axes = Vec::new();
    axes.push((
        "empty_frame_rejected",
        TransportTraceAnswerPacketWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "visible_trace_only",
            vec![],
            witness.surfaces.clone(),
            4_200,
            3_600,
            4_100,
            4_500,
        )
        .is_err(),
    ));
    axes.push((
        "empty_surface_rejected",
        TransportTraceAnswerPacketWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "visible_trace_only",
            witness.frames.clone(),
            vec![],
            4_200,
            3_600,
            4_100,
            4_500,
        )
        .is_err(),
    ));
    axes.push(("duplicate_frame_rejected", {
        let mut frames = witness.frames.clone();
        frames.push(frames[0].clone());
        make_witness(frames, witness.surfaces.clone()).is_err()
    }));
    axes.push(("duplicate_surface_rejected", {
        let mut surfaces = witness.surfaces.clone();
        surfaces.push(surfaces[0].clone());
        make_witness(witness.frames.clone(), surfaces).is_err()
    }));
    axes.push((
        "duplicate_answer_packet_rejected",
        reject_frame(|frames| frames[1].answer_packet_ref = frames[0].answer_packet_ref.clone()),
    ));
    axes.push((
        "missing_answer_packet_rejected",
        reject_one_frame(|frame| frame.answer_packet_ref = "bad-packet".to_string()),
    ));
    axes.push((
        "missing_run_event_log_rejected",
        reject_one_frame(|frame| frame.run_event_log_ref = "bad-log".to_string()),
    ));
    axes.push((
        "missing_fallback_rejected",
        reject_one_frame(|frame| frame.fallback_ref = "bad-fallback".to_string()),
    ));
    axes.push((
        "missing_rollback_rejected",
        reject_one_frame(|frame| frame.rollback_ref = "bad-rollback".to_string()),
    ));
    axes.push((
        "missing_admission_rejected",
        reject_one_frame(|frame| frame.admission_ref = "bad-admission".to_string()),
    ));
    axes.push((
        "missing_scope_rex_rejected",
        reject_one_frame(|frame| frame.scope_rex_ref = "bad-scope".to_string()),
    ));
    axes.push((
        "missing_sovereign_gate_rejected",
        reject_one_frame(|frame| frame.sovereign_gate_ref = "bad-sovereign".to_string()),
    ));
    axes.push((
        "missing_compatibility_fence_rejected",
        reject_one_frame(|frame| frame.compatibility_fence = "bad-compat".to_string()),
    ));
    axes.push((
        "missing_codec_stage_rejected",
        reject_one_frame(|frame| frame.codec_stage_ref = "bad-codec".to_string()),
    ));
    axes.push((
        "missing_cache_policy_rejected",
        reject_one_frame(|frame| frame.cache_policy_ref = "bad-cache".to_string()),
    ));
    axes.push((
        "missing_cancellation_group_rejected",
        reject_one_frame(|frame| frame.cancellation_group = "bad-cancel".to_string()),
    ));
    axes.push((
        "missing_surface_ref_rejected",
        reject_one_frame(|frame| frame.answer_packet_ref = "answer_packet:missing".to_string()),
    ));
    axes.push(("missing_required_marker_rejected", {
        TransportTraceAnswerPacketSurface::new(
            "surface-bad",
            "answer_packet:bad",
            "AnswerPacket bytes stall fallback caveat",
            vec!["missing marker".to_string()],
            forbidden_markers(),
        )
        .is_err()
    }));
    axes.push(("forbidden_marker_rejected", {
        TransportTraceAnswerPacketSurface::new(
            "surface-bad",
            "answer_packet:bad",
            "AnswerPacket bytes stall fallback caveat 70B route is live",
            vec!["AnswerPacket".to_string()],
            forbidden_markers(),
        )
        .is_err()
    }));
    axes.push((
        "non_material_trace_rejected",
        reject_one_frame(|frame| frame.material_to_answer = false),
    ));
    axes.push((
        "zero_bytes_rejected",
        reject_one_frame(|frame| frame.bytes_requested = 0),
    ));
    axes.push((
        "read_under_requested_rejected",
        reject_one_frame(|frame| frame.bytes_read = frame.bytes_requested - 1),
    ));
    axes.push((
        "underdecode_rejected",
        reject_one_frame(|frame| frame.bytes_decoded = frame.bytes_requested - 1),
    ));
    axes.push((
        "copied_bytes_missing_rejected",
        reject_one_frame(|frame| frame.copied_bytes = 0),
    ));
    axes.push((
        "p99_order_rejected",
        reject_one_frame(|frame| frame.p99_stall_ms = frame.p95_stall_ms - 1),
    ));
    axes.push((
        "zero_stall_rejected",
        reject_one_frame(|frame| frame.p95_stall_ms = 0),
    ));
    axes.push((
        "copy_budget_rejected",
        reject_one_frame(|frame| frame.copy_count = 3),
    ));
    axes.push((
        "read_amplification_rejected",
        reject_one_frame(|frame| frame.read_amplification_bps = 9_999),
    ));
    axes.push((
        "missing_fallback_caveat_rejected",
        reject_one_frame(|frame| frame.fallback_caveat = "silent".to_string()),
    ));
    axes.push((
        "missing_visible_summary_rejected",
        reject_one_frame(|frame| frame.user_visible_summary = "too short".to_string()),
    ));
    axes.push((
        "missing_layer_separation_rejected",
        reject_one_frame(|frame| frame.l1_l2_l3_separated = false),
    ));
    axes.push((
        "hidden_route_authority_rejected",
        reject_one_frame(|frame| frame.hidden_route_authority = true),
    ));
    axes.push((
        "route_policy_mutation_rejected",
        reject_one_frame(|frame| frame.route_policy_mutated = true),
    ));
    axes.push((
        "scope_rex_bypass_rejected",
        reject_one_frame(|frame| frame.scope_rex_bypassed = true),
    ));
    axes.push((
        "sovereign_gate_bypass_rejected",
        reject_one_frame(|frame| frame.sovereign_gate_bypassed = true),
    ));
    axes.push((
        "answer_packet_suppression_rejected",
        reject_one_frame(|frame| frame.answer_packet_suppressed = true),
    ));
    axes.push((
        "fallback_caveat_suppression_rejected",
        reject_one_frame(|frame| frame.fallback_caveat_suppressed = true),
    ));
    axes.push((
        "hidden_chain_rejected",
        reject_one_frame(|frame| frame.hidden_chain_exposed = true),
    ));
    axes.push((
        "hidden_cloud_rejected",
        reject_one_frame(|frame| frame.hidden_cloud_route = true),
    ));
    axes.push((
        "mas_product_build_rejected",
        TransportTraceAnswerPacketWitness::new(
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            "visible_trace_only",
            witness.frames.clone(),
            witness.surfaces.clone(),
            4_200,
            3_600,
            4_100,
            4_500,
        )
        .is_err(),
    ));
    axes.push((
        "live_pro_status_rejected",
        TransportTraceAnswerPacketWitness::new(
            ProductBuild::Pro,
            ProStatus::Live,
            "visible_trace_only",
            witness.frames.clone(),
            witness.surfaces.clone(),
            4_200,
            3_600,
            4_100,
            4_500,
        )
        .is_err(),
    ));
    axes.push((
        "runtime_bytes_rejected",
        reject_one_frame(|frame| frame.runtime_bytes_loaded = 1),
    ));
    axes.push((
        "model_bytes_rejected",
        reject_one_frame(|frame| frame.model_bytes_loaded = 1),
    ));
    axes.push((
        "hidden_summary_baseline_unbeaten_rejected",
        make_witness_with_baselines(9_000, 3_600, 4_100, 4_500).is_err(),
    ));
    axes.push((
        "no_answer_packet_baseline_unbeaten_rejected",
        make_witness_with_baselines(4_200, 9_000, 4_100, 4_500).is_err(),
    ));
    axes.push((
        "invisible_fallback_baseline_unbeaten_rejected",
        make_witness_with_baselines(4_200, 3_600, 9_000, 4_500).is_err(),
    ));
    axes.push((
        "live_authority_baseline_unbeaten_rejected",
        make_witness_with_baselines(4_200, 3_600, 4_100, 9_000).is_err(),
    ));
    axes.push((
        "metadata_budget_rejected",
        reject_one_frame(|frame| frame.metadata_bytes = MAX_METADATA_BYTES + 1),
    ));
    Ok(axes)
}

fn reject_one_frame(mut mutate: impl FnMut(&mut TransportTraceAnswerPacketFrame)) -> bool {
    let Ok(witness) = fixture_witness() else {
        return false;
    };
    let mut frames = witness.frames;
    mutate(&mut frames[0]);
    make_witness(frames, witness.surfaces).is_err()
}

fn reject_frame(mut mutate: impl FnMut(&mut Vec<TransportTraceAnswerPacketFrame>)) -> bool {
    let Ok(witness) = fixture_witness() else {
        return false;
    };
    let mut frames = witness.frames;
    mutate(&mut frames);
    make_witness(frames, witness.surfaces).is_err()
}

fn make_witness(
    frames: Vec<TransportTraceAnswerPacketFrame>,
    surfaces: Vec<TransportTraceAnswerPacketSurface>,
) -> Result<TransportTraceAnswerPacketWitness, TransportTraceAnswerPacketError> {
    TransportTraceAnswerPacketWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "visible_trace_only",
        frames,
        surfaces,
        4_200,
        3_600,
        4_100,
        4_500,
    )
}

fn make_witness_with_baselines(
    hidden_summary: u64,
    no_answer_packet: u64,
    invisible_fallback: u64,
    live_authority: u64,
) -> Result<TransportTraceAnswerPacketWitness, TransportTraceWitnessError> {
    let witness = fixture_witness()?;
    Ok(TransportTraceAnswerPacketWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "visible_trace_only",
        witness.frames,
        witness.surfaces,
        hidden_summary,
        no_answer_packet,
        invisible_fallback,
        live_authority,
    )?)
}

fn manifest(
    id: &str,
    destination: ColdStreamDestination,
    priority: ColdStreamPriority,
    cache_policy: ColdStreamCachePolicy,
) -> Result<ColdStreamTransportManifest, agent_core::uas::ColdStreamError> {
    ColdStreamTransportManifest::new(
        format!("manifest-{id}"),
        format!("route:coldstream:{id}"),
        format!("uas:semantic_working_set_plan:{id}"),
        format!("residency_page_table:{id}"),
        format!("admission:{id}"),
        format!("scope_rex:{id}"),
        format!("sovereign_gate:{id}"),
        format!("rollback:{id}"),
        format!("run_event_log:{id}"),
        format!("answer_packet:{id}"),
        format!("fallback:{id}"),
        format!("cancel_group:{id}"),
        ColdStreamAuthority::ProposalOnly,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        vec![ColdStreamPageRun::new(
            format!("run-{id}"),
            format!("file-{id}"),
            4096,
            128 * 1024,
            vec![format!("semantic-unit-{id}")],
            vec![UasAddress::new(
                UasKind::Other(format!("transport_trace_answer_packet_unit_{id}")),
                id.as_bytes(),
                CREATED_AT_MS,
            )],
            "zstd",
            format!("sha256:{id}"),
            destination,
            priority,
            cache_policy,
            format!("lease:{id}"),
            format!("compat:{id}"),
        )?],
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        0,
        0,
        CREATED_AT_MS,
    )
}

fn trace(
    manifest: &ColdStreamTransportManifest,
    trace_id: &str,
    p95: u32,
    p99: u32,
) -> Result<ColdStreamTransportTrace, agent_core::uas::ColdStreamError> {
    ColdStreamTransportTrace::new(
        manifest,
        trace_id,
        manifest.planned_bytes(),
        manifest.planned_bytes() + 4096,
        manifest.planned_bytes(),
        2,
        1,
        p95,
        p99,
        10_312,
        false,
        true,
        &manifest.run_event_log_ref,
        &manifest.answer_packet_ref,
    )
}

fn forbidden_markers() -> Vec<String> {
    [
        "70B route is live",
        "dense 70B runs locally today",
        "ColdStream works live",
        "mmap is RAM",
        "chain-of-thought",
        "hidden reasoning",
        "hidden cloud",
        "product route is live",
    ]
    .iter()
    .map(|value| value.to_string())
    .collect()
}

// UAS: uas:transport-trace-answer-packet:evidence-snapshot
// Plane: Verification
// Residency: metadata-only guard/capability/upstream evidence reader.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    coldstream_pass: bool,
    provider_guard_pass: bool,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, TransportTraceWitnessError> {
        let guard = read_json(GUARD_PATH)?;
        let capability = read_json(CAPABILITY_PATH)?;
        let coldstream = read_json(COLDSTREAM_PATH)?;
        let provider_guard = read_json(PROVIDER_GUARD_PATH)?;
        Ok(Self {
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_default(),
            capability_overall_pass: bool_field(&capability, "overall_pass"),
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_default(),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_default(),
            coldstream_pass: artifact_all_axes_true(
                &coldstream,
                COLDSTREAM_NO_HIDDEN_AUTHORITY_AXES,
            ),
            provider_guard_pass: artifact_all_axes_true(
                &provider_guard,
                PROVIDER_ROUTE_COPY_SOURCE_GUARD_AXES,
            ),
        })
    }
}

fn read_text(path: &'static str) -> Result<String, TransportTraceWitnessError> {
    let resolved = resolve_artifact_path(path);
    std::fs::read_to_string(&resolved).map_err(|error| {
        TransportTraceWitnessError::Io(format!("failed to read {}: {error}", resolved.display()))
    })
}

fn read_json(path: &'static str) -> Result<serde_json::Value, TransportTraceWitnessError> {
    let text = read_text(path)?;
    serde_json::from_str(&text)
        .map_err(|error| TransportTraceWitnessError::Io(format!("failed to parse {path}: {error}")))
}

fn resolve_artifact_path(path: &'static str) -> PathBuf {
    let direct = PathBuf::from(path);
    if direct.exists() {
        return direct;
    }
    Path::new("..").join(path)
}

fn bool_field(value: &serde_json::Value, key: &str) -> bool {
    value
        .get(key)
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_str)
        .map(str::to_string)
}

fn artifact_all_axes_true(value: &serde_json::Value, axes: &[&str]) -> bool {
    bool_field(value, "overall_pass")
        && axes.iter().all(|axis| {
            value
                .get("pass_per_axis")
                .and_then(|axes| axes.get(*axis))
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false)
        })
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    actual: u64,
    operator: &str,
    expected: u64,
    unit: &str,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    let passed = match operator {
        ">=" => actual >= expected,
        "<=" => actual <= expected,
        "<" => actual < expected,
        ">" => actual > expected,
        "==" => actual == expected,
        _ => false,
    };
    pass_per_axis.insert(axis.to_string(), passed);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_artifact_passes() {
        let artifact = build_artifact().expect("artifact");
        assert!(artifact.overall_pass);
        assert_eq!(artifact.falsifier_id, FALSIFIER_ID);
    }

    #[test]
    fn artifact_contains_shared_axes() {
        let artifact = build_artifact().expect("artifact");
        for axis in TRANSPORT_TRACE_ANSWER_PACKET_AXES {
            assert!(
                artifact.pass_per_axis.contains_key(*axis),
                "missing axis {axis}"
            );
        }
    }

    #[test]
    fn invalid_axes_are_true() {
        let artifact = build_artifact().expect("artifact");
        for axis in [
            "missing_answer_packet_rejected",
            "missing_run_event_log_rejected",
            "missing_fallback_caveat_rejected",
            "hidden_route_authority_rejected",
            "route_policy_mutation_rejected",
            "answer_packet_suppression_rejected",
            "runtime_bytes_rejected",
            "model_bytes_rejected",
        ] {
            assert_eq!(
                artifact.pass_per_axis.get(axis).copied(),
                Some(true),
                "{axis}"
            );
        }
    }

    #[test]
    fn witness_address_is_deterministic() {
        let witness = fixture_witness().expect("witness");
        let address = witness.address();
        let mut frames = witness.frames.clone();
        frames.reverse();
        let reversed = make_witness(frames, witness.surfaces).expect("reversed");
        assert_eq!(address, reversed.address());
        assert!(address.starts_with("uas:transport-trace-answer-packet:sha256:"));
    }

    #[test]
    fn witness_binds_visible_surfaces() {
        let witness = fixture_witness().expect("witness");
        for frame in &witness.frames {
            assert!(witness
                .surfaces
                .iter()
                .any(|surface| surface.answer_packet_ref == frame.answer_packet_ref));
            assert!(frame.user_visible_summary.contains("AnswerPacket"));
            assert!(frame.user_visible_summary.contains("not a live 70B route"));
        }
    }
}
