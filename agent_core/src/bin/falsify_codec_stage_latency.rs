//! `falsify_codec_stage_latency`.
//!
//! Metadata-only witness for `F-CodecStage-Latency`. It proves decode and
//! conversion latency, checksums, and copy counts are separate from file-read
//! time before live ColdStream, 70B, or product runtime claims can promote.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[cfg(test)]
use agent_core::falsifier_artifacts::axes::CODEC_STAGE_LATENCY_AXES;
use agent_core::falsifier_artifacts::axes::METAL_IO_FEATURE_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    CodecStageLane, CodecStageLatencyError, CodecStageLatencyWitness, CodecStageRecord,
    CodecStageSurface, ProStatus, ProductBuild, CODEC_STAGE_LATENCY_CURSOR,
    CODEC_STAGE_LATENCY_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-CodecStage-Latency";
const FIXTURE_ID: &str = "codec_stage_latency_v1";
const COMMAND: &str = "Tools/falsifiers/f_codec_stage_latency.sh";
const RESULT: &str = "artifacts/falsifiers/codec_stage_latency/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const METAL_IO_FEATURE_GATE_PATH: &str = "artifacts/falsifiers/metal_io_feature_gate/result.json";
const MIN_STAGE_COUNT: u64 = 3;
const MIN_SURFACE_COUNT: u64 = 2;
const MIN_LATENCY_SUCCESS_BPS: u64 = 9_500;
const MAX_METADATA_BYTES: u64 = 256 * 1024;

#[derive(Debug)]
// UAS: uas:codec-stage-latency:witness-error
// Plane: Verification
// Residency: metadata-only artifact rejection taxonomy.
enum CodecStageWitnessError {
    Primitive(CodecStageLatencyError),
    Io(String),
}

impl std::fmt::Display for CodecStageWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for CodecStageWitnessError {}

impl From<CodecStageLatencyError> for CodecStageWitnessError {
    fn from(value: CodecStageLatencyError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, CodecStageWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fixture_witness()?;
    let metrics = witness.metrics();
    let address = witness.address();
    let mut reversed = witness.stages.clone();
    reversed.reverse();
    let deterministic = CodecStageLatencyWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "codec_stage_only",
        witness.latency_success_bps,
        witness.mixed_read_decode_baseline_bps,
        witness.unchecked_decode_baseline_bps,
        witness.hidden_copy_baseline_bps,
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
            "upstream_metal_io_feature_gate_pass",
            evidence.metal_io_feature_gate_pass,
        ),
        (
            "guard_cursor_codec_stage_latency_or_advanced",
            evidence.guard_next_existing_work == CODEC_STAGE_LATENCY_CURSOR
                || evidence.guard_next_existing_work == CODEC_STAGE_LATENCY_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_codec_stage_latency_or_advanced",
            evidence.capability_next_bottleneck == CODEC_STAGE_LATENCY_CURSOR
                || evidence.capability_next_bottleneck == CODEC_STAGE_LATENCY_NEXT_CURSOR,
        ),
        (
            "product_status_research_only",
            witness.product_build == ProductBuild::Pro
                && witness.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_codec_stage_only",
            witness.route_authority == "codec_stage_only",
        ),
        (
            "codec_stage_records_bound",
            metrics.stage_count as u64 >= MIN_STAGE_COUNT,
        ),
        (
            "codec_names_bound",
            witness.stages.iter().all(|stage| !stage.codec.is_empty()),
        ),
        (
            "input_runs_bound",
            witness
                .stages
                .iter()
                .all(|stage| stage.input_run_ref.starts_with("page_run:")),
        ),
        (
            "read_trace_refs_bound",
            witness
                .stages
                .iter()
                .all(|stage| stage.file_read_trace_ref.starts_with("read_trace:")),
        ),
        (
            "codec_latency_trace_refs_bound",
            witness
                .stages
                .iter()
                .all(|stage| stage.codec_latency_trace_ref.starts_with("codec_latency:")),
        ),
        (
            "kernel_refs_bound",
            witness.stages.iter().all(|stage| {
                stage.kernel_ref.starts_with("codec_kernel:")
                    || stage.kernel_ref.starts_with("metal_kernel:")
            }),
        ),
        (
            "output_slab_refs_bound",
            witness.stages.iter().all(|stage| {
                stage.output_slab_ref.starts_with("cpu_slab:")
                    || stage.output_slab_ref.starts_with("metal_buffer_lease:")
            }),
        ),
        (
            "checksum_after_decode_bound",
            witness
                .stages
                .iter()
                .all(|stage| stage.checksum_after_decode.starts_with("sha256:")),
        ),
        (
            "read_latency_separated",
            witness.stages.iter().all(|stage| {
                stage.file_read_latency_ms > 0
                    && stage.file_read_trace_ref != stage.codec_latency_trace_ref
                    && !stage.visible_caveat.contains("read+decode")
            }),
        ),
        (
            "decode_or_conversion_latency_bound",
            witness.stages.iter().all(|stage| {
                stage
                    .decode_latency_ms
                    .saturating_add(stage.conversion_latency_ms)
                    > 0
            }),
        ),
        (
            "copy_counts_bound",
            witness.stages.iter().all(|stage| {
                stage.observed_copy_count <= stage.expected_copy_count
                    && stage.expected_copy_count <= 2
            }),
        ),
        (
            "answer_packet_refs_bound",
            metrics.answer_packet_count >= metrics.surface_count,
        ),
        (
            "run_event_log_refs_bound",
            witness
                .stages
                .iter()
                .all(|stage| stage.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "rollback_bound",
            witness
                .stages
                .iter()
                .all(|stage| stage.rollback_ref.starts_with("rollback:")),
        ),
        (
            "admission_bound",
            witness
                .stages
                .iter()
                .all(|stage| stage.admission_ref.starts_with("admission:")),
        ),
        (
            "scope_rex_bound",
            witness
                .stages
                .iter()
                .all(|stage| stage.scope_rex_ref.starts_with("scope_rex:")),
        ),
        (
            "sovereign_gate_bound",
            witness
                .stages
                .iter()
                .all(|stage| stage.sovereign_gate_ref.starts_with("sovereign_gate:")),
        ),
        (
            "compatibility_fence_bound",
            witness
                .stages
                .iter()
                .all(|stage| stage.compatibility_fence.starts_with("compat:")),
        ),
        (
            "cancel_group_bound",
            witness
                .stages
                .iter()
                .all(|stage| stage.cancel_group_ref.starts_with("cancel_group:")),
        ),
        (
            "visible_caveat_bound",
            witness.stages.iter().all(|stage| {
                stage.visible_caveat.contains("metadata-only")
                    && stage.visible_caveat.contains("read separate")
                    && stage.visible_caveat.contains("copy count")
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
        ("codec_stage_latency_address_deterministic", deterministic),
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
        "stage_count",
        metrics.stage_count as u64,
        MIN_STAGE_COUNT,
        "stages",
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
        "codec_count",
        metrics.codec_count as u64,
        2,
        "codecs",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "total_input_bytes",
        metrics.total_input_bytes,
        1,
        "bytes",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "total_decoded_bytes",
        metrics.total_decoded_bytes,
        1,
        "bytes",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_file_read_latency_ms",
        metrics.max_file_read_latency_ms,
        1,
        "ms",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_codec_stage_latency_ms",
        metrics.max_codec_stage_latency_ms,
        1,
        "ms",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_decode_latency_ms",
        metrics.max_decode_latency_ms,
        1,
        "ms",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_conversion_latency_ms",
        metrics.max_conversion_latency_ms,
        1,
        "ms",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_observed_copy_count",
        metrics.max_observed_copy_count as u64,
        2,
        "copies",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_expected_copy_count",
        metrics.max_expected_copy_count as u64,
        2,
        "copies",
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
        "latency_success_bps",
        witness.latency_success_bps as u64,
        MIN_LATENCY_SUCCESS_BPS,
        "bps",
    );
    for (name, value) in [
        (
            "mixed_read_decode_baseline_bps",
            witness.mixed_read_decode_baseline_bps,
        ),
        (
            "unchecked_decode_baseline_bps",
            witness.unchecked_decode_baseline_bps,
        ),
        ("hidden_copy_baseline_bps", witness.hidden_copy_baseline_bps),
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
            witness.latency_success_bps.saturating_sub(1) as u64,
            "bps",
        );
    }
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "codec_stage_latency_address",
        address,
        "uas:codec-stage-latency:sha256:",
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
            "kind": "codec_stage_latency_metadata_only",
            "detail": "CodecStage latency is L1 metadata proof only: no live codec benchmark, no live transport bytes, no model bytes, no dense 70B, no KV-Direct 128K, and no product runtime promotion."
        })],
        notes: "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. F-CodecStage-Latency proves read timing, decode/conversion timing, checksums, copy counts, rollback, RunEventLog, SCOPE-Rex/SovereignGate admission, compatibility fences, cancellation, and AnswerPacket caveats are explicit and separate. L1 architecture cursor advances only; L2 remains vault_research_route_with_packetized_mitigation and L3 product runtime is unchanged."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn invalid_fixture_axes() -> Result<Vec<(&'static str, bool)>, CodecStageWitnessError> {
    Ok(vec![
        (
            "empty_stage_rejected",
            matches!(
                reject_witness(|witness| witness.stages.clear()),
                Err(CodecStageLatencyError::EmptyStage)
            ),
        ),
        (
            "empty_surface_rejected",
            matches!(
                reject_witness(|witness| witness.surfaces.clear()),
                Err(CodecStageLatencyError::EmptySurface)
            ),
        ),
        (
            "duplicate_stage_rejected",
            matches!(
                reject_witness(|witness| witness.stages.push(witness.stages[0].clone())),
                Err(CodecStageLatencyError::DuplicateStage(_))
            ),
        ),
        (
            "duplicate_surface_rejected",
            matches!(
                reject_witness(|witness| witness.surfaces.push(witness.surfaces[0].clone())),
                Err(CodecStageLatencyError::DuplicateSurface(_))
            ),
        ),
        (
            "duplicate_answer_packet_rejected",
            matches!(
                reject_one_stage(
                    |stage| stage.answer_packet_ref = "answer_packet:codec-zstd".to_string(),
                    1
                ),
                Err(CodecStageLatencyError::DuplicateAnswerPacket(_))
            ),
        ),
        (
            "missing_codec_rejected",
            matches!(
                reject_one_stage(|stage| stage.codec.clear(), 0),
                Err(CodecStageLatencyError::MissingField("codec"))
                    | Err(CodecStageLatencyError::MissingCodec(_))
            ),
        ),
        (
            "missing_input_run_rejected",
            matches!(
                reject_one_stage(|stage| stage.input_run_ref.clear(), 0),
                Err(CodecStageLatencyError::MissingField("input_run_ref"))
                    | Err(CodecStageLatencyError::MissingInputRun(_))
            ),
        ),
        (
            "missing_read_trace_rejected",
            matches!(
                reject_one_stage(|stage| stage.file_read_trace_ref.clear(), 0),
                Err(CodecStageLatencyError::MissingField("file_read_trace_ref"))
                    | Err(CodecStageLatencyError::MissingReadTrace(_))
            ),
        ),
        (
            "missing_codec_latency_trace_rejected",
            matches!(
                reject_one_stage(|stage| stage.codec_latency_trace_ref.clear(), 0),
                Err(CodecStageLatencyError::MissingField(
                    "codec_latency_trace_ref"
                )) | Err(CodecStageLatencyError::MissingCodecLatencyTrace(_))
            ),
        ),
        (
            "missing_kernel_ref_rejected",
            matches!(
                reject_one_stage(|stage| stage.kernel_ref.clear(), 0),
                Err(CodecStageLatencyError::MissingField("kernel_ref"))
                    | Err(CodecStageLatencyError::MissingKernelRef(_))
            ),
        ),
        (
            "missing_output_slab_rejected",
            matches!(
                reject_one_stage(|stage| stage.output_slab_ref.clear(), 0),
                Err(CodecStageLatencyError::MissingField("output_slab_ref"))
                    | Err(CodecStageLatencyError::MissingOutputSlab(_))
            ),
        ),
        (
            "missing_checksum_rejected",
            matches!(
                reject_one_stage(|stage| stage.checksum_after_decode.clear(), 0),
                Err(CodecStageLatencyError::MissingField(
                    "checksum_after_decode"
                )) | Err(CodecStageLatencyError::MissingChecksum(_))
            ),
        ),
        (
            "zero_input_bytes_rejected",
            matches!(
                reject_one_stage(|stage| stage.input_bytes = 0, 0),
                Err(CodecStageLatencyError::ZeroInputBytes(_))
            ),
        ),
        (
            "zero_decoded_bytes_rejected",
            matches!(
                reject_one_stage(|stage| stage.decoded_bytes = 0, 0),
                Err(CodecStageLatencyError::ZeroDecodedBytes(_))
            ),
        ),
        (
            "missing_decode_or_conversion_latency_rejected",
            matches!(
                reject_one_stage(
                    |stage| {
                        stage.decode_latency_ms = 0;
                        stage.conversion_latency_ms = 0;
                    },
                    0
                ),
                Err(CodecStageLatencyError::MissingDecodeOrConversionLatency(_))
            ),
        ),
        (
            "read_latency_not_separated_rejected",
            matches!(
                reject_one_stage(|stage| stage.file_read_latency_ms = 0, 0),
                Err(CodecStageLatencyError::ReadLatencyNotSeparated(_))
            ),
        ),
        (
            "copy_count_exceeded_rejected",
            matches!(
                reject_one_stage(
                    |stage| stage.observed_copy_count = stage.expected_copy_count + 1,
                    0
                ),
                Err(CodecStageLatencyError::CopyCountExceeded(_))
            ),
        ),
        (
            "expected_copy_budget_exceeded_rejected",
            matches!(
                reject_one_stage(|stage| stage.expected_copy_count = 3, 0),
                Err(CodecStageLatencyError::ExpectedCopyBudgetExceeded(_))
            ),
        ),
        (
            "missing_answer_packet_rejected",
            matches!(
                reject_one_stage(|stage| stage.answer_packet_ref.clear(), 0),
                Err(CodecStageLatencyError::MissingField("answer_packet_ref"))
                    | Err(CodecStageLatencyError::MissingAnswerPacket(_))
            ),
        ),
        (
            "missing_run_event_log_rejected",
            matches!(
                reject_one_stage(|stage| stage.run_event_log_ref.clear(), 0),
                Err(CodecStageLatencyError::MissingField("run_event_log_ref"))
                    | Err(CodecStageLatencyError::MissingRunEventLog(_))
            ),
        ),
        (
            "missing_rollback_rejected",
            matches!(
                reject_one_stage(|stage| stage.rollback_ref.clear(), 0),
                Err(CodecStageLatencyError::MissingField("rollback_ref"))
                    | Err(CodecStageLatencyError::MissingRollback(_))
            ),
        ),
        (
            "missing_admission_rejected",
            matches!(
                reject_one_stage(|stage| stage.admission_ref.clear(), 0),
                Err(CodecStageLatencyError::MissingField("admission_ref"))
                    | Err(CodecStageLatencyError::MissingAdmission)
            ),
        ),
        (
            "missing_scope_rex_rejected",
            matches!(
                reject_one_stage(|stage| stage.scope_rex_ref.clear(), 0),
                Err(CodecStageLatencyError::MissingField("scope_rex_ref"))
                    | Err(CodecStageLatencyError::MissingScopeRex)
            ),
        ),
        (
            "missing_sovereign_gate_rejected",
            matches!(
                reject_one_stage(|stage| stage.sovereign_gate_ref.clear(), 0),
                Err(CodecStageLatencyError::MissingField("sovereign_gate_ref"))
                    | Err(CodecStageLatencyError::MissingSovereignGate)
            ),
        ),
        (
            "missing_compatibility_fence_rejected",
            matches!(
                reject_one_stage(|stage| stage.compatibility_fence.clear(), 0),
                Err(CodecStageLatencyError::MissingField("compatibility_fence"))
                    | Err(CodecStageLatencyError::MissingCompatibilityFence(_))
            ),
        ),
        (
            "missing_cancel_group_rejected",
            matches!(
                reject_one_stage(|stage| stage.cancel_group_ref.clear(), 0),
                Err(CodecStageLatencyError::MissingField("cancel_group_ref"))
                    | Err(CodecStageLatencyError::MissingCancelGroup(_))
            ),
        ),
        (
            "missing_visible_caveat_rejected",
            matches!(
                reject_one_stage(|stage| stage.visible_caveat.clear(), 0),
                Err(CodecStageLatencyError::MissingField("visible_caveat"))
                    | Err(CodecStageLatencyError::MissingVisibleCaveat(_))
                    | Err(CodecStageLatencyError::MissingRequiredMarker(_))
            ),
        ),
        (
            "missing_required_marker_rejected",
            matches!(
                reject_surface(|surface| surface.visible_summary =
                    surface.visible_summary.replace("AnswerPacket", "packet")),
                Err(CodecStageLatencyError::MissingRequiredMarker(_))
            ),
        ),
        (
            "forbidden_marker_rejected",
            matches!(
                reject_surface(|surface| surface
                    .visible_summary
                    .push_str(" live transport is ready.")),
                Err(CodecStageLatencyError::ForbiddenMarker(_))
            ),
        ),
        (
            "missing_layer_separation_rejected",
            matches!(
                reject_surface(|surface| surface.visible_summary =
                    surface.visible_summary.replace("L3", "product")),
                Err(CodecStageLatencyError::MissingLayerSeparation)
                    | Err(CodecStageLatencyError::MissingRequiredMarker(_))
            ),
        ),
        (
            "hidden_route_authority_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_route_authority = true),
                Err(CodecStageLatencyError::HiddenRouteAuthority)
            ),
        ),
        (
            "route_policy_mutation_rejected",
            matches!(
                reject_witness(|witness| witness.route_policy_mutation = true),
                Err(CodecStageLatencyError::RoutePolicyMutation)
            ),
        ),
        (
            "gate_bypass_rejected",
            matches!(
                reject_witness(|witness| witness.gate_bypass = true),
                Err(CodecStageLatencyError::GateBypass)
            ),
        ),
        (
            "answer_packet_suppression_rejected",
            matches!(
                reject_witness(|witness| witness.answer_packet_suppression = true),
                Err(CodecStageLatencyError::AnswerPacketSuppression)
            ),
        ),
        (
            "hidden_chain_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_chain_exposed = true),
                Err(CodecStageLatencyError::HiddenChainExposure)
            ),
        ),
        (
            "hidden_cloud_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_cloud_route = true),
                Err(CodecStageLatencyError::HiddenCloudRoute)
            ),
        ),
        (
            "ssd_as_ram_rejected",
            matches!(
                reject_witness(|witness| witness.ssd_as_ram_claim = true),
                Err(CodecStageLatencyError::SsdAsRamClaim)
            ),
        ),
        (
            "mas_product_build_rejected",
            matches!(
                reject_witness(|witness| witness.product_build = ProductBuild::Mas),
                Err(CodecStageLatencyError::ProductStatusMismatch)
            ),
        ),
        (
            "live_pro_status_rejected",
            matches!(
                reject_witness(|witness| witness.pro_status = ProStatus::Live),
                Err(CodecStageLatencyError::ProductStatusMismatch)
            ),
        ),
        (
            "live_benchmark_rejected",
            matches!(
                reject_witness(|witness| witness.live_benchmark_attempted = true),
                Err(CodecStageLatencyError::LiveBenchmarkAttempted)
            ),
        ),
        (
            "runtime_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.runtime_bytes_loaded = 1),
                Err(CodecStageLatencyError::RuntimeBytesLoaded)
            ),
        ),
        (
            "model_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.model_bytes_loaded = 1),
                Err(CodecStageLatencyError::ModelBytesLoaded)
            ),
        ),
        (
            "transport_runtime_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.transport_runtime_bytes_loaded = 1),
                Err(CodecStageLatencyError::TransportRuntimeBytesLoaded)
            ),
        ),
        (
            "mixed_read_decode_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.mixed_read_decode_baseline_bps = 9_750),
                Err(CodecStageLatencyError::BaselineUnbeaten(
                    "mixed_read_decode"
                ))
            ),
        ),
        (
            "unchecked_decode_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.unchecked_decode_baseline_bps = 9_750),
                Err(CodecStageLatencyError::BaselineUnbeaten("unchecked_decode"))
            ),
        ),
        (
            "hidden_copy_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_copy_baseline_bps = 9_750),
                Err(CodecStageLatencyError::BaselineUnbeaten("hidden_copy"))
            ),
        ),
        (
            "live_authority_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.live_authority_baseline_bps = 9_750),
                Err(CodecStageLatencyError::BaselineUnbeaten("live_authority"))
            ),
        ),
        (
            "metadata_budget_rejected",
            matches!(
                reject_witness(|witness| witness.max_metadata_bytes = MAX_METADATA_BYTES + 1),
                Err(CodecStageLatencyError::MetadataBudgetExceeded)
            ),
        ),
    ])
}

fn fixture_witness() -> Result<CodecStageLatencyWitness, CodecStageLatencyError> {
    CodecStageLatencyWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "codec_stage_only",
        9_700,
        8_100,
        8_250,
        8_400,
        8_000,
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
        fixture_stages()?,
        fixture_surfaces()?,
    )
}

fn fixture_stages() -> Result<Vec<CodecStageRecord>, CodecStageLatencyError> {
    Ok(vec![
        stage(
            "codec-zstd",
            "zstd",
            CodecStageLane::CpuDecode,
            "codec_kernel:zstd:decode",
            "cpu_slab:codec-zstd:out",
            12,
            0,
            1,
            "answer_packet:codec-zstd",
        )?,
        stage(
            "codec-q4-dequant",
            "q4_dequant",
            CodecStageLane::ConversionOnly,
            "codec_kernel:q4:dequant",
            "cpu_slab:codec-q4:out",
            2,
            5,
            1,
            "answer_packet:codec-q4-dequant",
        )?,
        stage(
            "codec-metal-unpack",
            "metal_unpacked_tile",
            CodecStageLane::MetalDecode,
            "metal_kernel:tile-unpack:decode",
            "metal_buffer_lease:codec-metal:out",
            8,
            2,
            1,
            "answer_packet:codec-metal-unpack",
        )?,
    ])
}

fn stage(
    stage_id: &str,
    codec: &str,
    lane: CodecStageLane,
    kernel_ref: &str,
    output_ref: &str,
    decode_latency_ms: u64,
    conversion_latency_ms: u64,
    copy_count: u32,
    answer_packet_ref: &str,
) -> Result<CodecStageRecord, CodecStageLatencyError> {
    CodecStageRecord::new(
        stage_id,
        "mission:coldstream-codec-stage",
        codec,
        lane,
        format!("page_run:{stage_id}:input"),
        format!("read_trace:{stage_id}:file"),
        format!("codec_latency:{stage_id}:decode"),
        kernel_ref,
        output_ref,
        format!("sha256:{stage_id}-decoded-checksum"),
        32_768,
        65_536,
        4,
        decode_latency_ms,
        conversion_latency_ms,
        copy_count,
        copy_count,
        answer_packet_ref,
        format!("run_event_log:{stage_id}"),
        format!("rollback:{stage_id}"),
        "admission:codec-stage-latency",
        "scope_rex:codec-stage-latency",
        "sovereign_gate:codec-stage-latency",
        "compat:codec-stage-latency-v1",
        format!("cancel_group:{stage_id}"),
        "metadata-only CodecStage evidence keeps read separate from codec latency, exposes checksum and copy count in AnswerPacket, binds rollback, and advances L1 only while L2 and L3 stay unchanged.",
    )
}

fn fixture_surfaces() -> Result<Vec<CodecStageSurface>, CodecStageLatencyError> {
    Ok(vec![
        CodecStageSurface::new(
            "surface:codec-stage-latency",
            "answer_packet:codec-surface-a",
            "run_event_log:codec-surface-a",
            "metadata-only CodecStage surface: L1 records separate file-read and codec latency, checksum, copy count, AnswerPacket, RunEventLog, and rollback; L2 remains vault research and L3 product runtime is unchanged.",
        )?,
        CodecStageSurface::new(
            "surface:codec-stage-copy-count",
            "answer_packet:codec-surface-b",
            "run_event_log:codec-surface-b",
            "metadata-only copy surface: L1 shows decode/conversion copies and checksum caveats in the AnswerPacket with rollback; L2 capability remains red and L3 user-facing runtime is unchanged.",
        )?,
    ])
}

fn reject_witness(
    mutate: impl FnOnce(&mut CodecStageLatencyWitness),
) -> Result<CodecStageLatencyWitness, CodecStageLatencyError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness);
    rebuild_witness(witness)
}

fn reject_one_stage(
    mutate: impl FnOnce(&mut CodecStageRecord),
    index: usize,
) -> Result<CodecStageLatencyWitness, CodecStageLatencyError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness.stages[index]);
    rebuild_witness(witness)
}

fn reject_surface(
    mutate: impl FnOnce(&mut CodecStageSurface),
) -> Result<CodecStageLatencyWitness, CodecStageLatencyError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness.surfaces[0]);
    rebuild_witness(witness)
}

fn rebuild_witness(
    witness: CodecStageLatencyWitness,
) -> Result<CodecStageLatencyWitness, CodecStageLatencyError> {
    CodecStageLatencyWitness::new(
        witness.product_build,
        witness.pro_status,
        witness.route_authority,
        witness.latency_success_bps,
        witness.mixed_read_decode_baseline_bps,
        witness.unchecked_decode_baseline_bps,
        witness.hidden_copy_baseline_bps,
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
        witness.stages,
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
// UAS: Binds upstream witness refs used to prove CodecStage lineage.
// Plane: Verification.
// Residency: Metadata-only evidence; no runtime/model/transport bytes are loaded.
struct EvidenceSnapshot {
    metal_io_feature_gate_pass: bool,
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, CodecStageWitnessError> {
        let metal = read_json(METAL_IO_FEATURE_GATE_PATH)?;
        let guard = read_json(GUARD_PATH)?;
        let capability = read_json(CAPABILITY_PATH)?;
        Ok(Self {
            metal_io_feature_gate_pass: metal
                .get("overall_pass")
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false)
                && axes_all_present(&metal, METAL_IO_FEATURE_GATE_AXES),
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
            == Some(true)
    })
}

fn measurement_string(value: &serde_json::Value, key: &str) -> String {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_str)
        .unwrap_or_default()
        .to_string()
}

fn read_json(path: &'static str) -> Result<serde_json::Value, CodecStageWitnessError> {
    let text = read_text(path)?;
    serde_json::from_str(&text)
        .map_err(|error| CodecStageWitnessError::Io(format!("failed to parse {path}: {error}")))
}

fn read_text(path: &'static str) -> Result<String, CodecStageWitnessError> {
    let workspace_root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap_or_else(|| Path::new("."));
    let resolved = workspace_root.join(path);
    std::fs::read_to_string(resolved)
        .map_err(|error| CodecStageWitnessError::Io(format!("failed to read {path}: {error}")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_axis_set_matches_contract() {
        let artifact = build_artifact().expect("artifact");
        let mut actual = artifact
            .pass_per_axis
            .keys()
            .map(String::as_str)
            .collect::<Vec<_>>();
        actual.sort_unstable();
        let mut expected = CODEC_STAGE_LATENCY_AXES.to_vec();
        expected.sort_unstable();
        assert_eq!(actual, expected);
    }

    #[test]
    fn invalid_axes_are_exercised() {
        let axes = invalid_fixture_axes().expect("invalid axes");
        let failed = axes
            .iter()
            .filter_map(|(name, passed)| (!*passed).then_some(*name))
            .collect::<Vec<_>>();
        assert!(failed.is_empty(), "failed invalid axes: {failed:?}");
        assert!(axes
            .iter()
            .any(|(name, _)| *name == "read_latency_not_separated_rejected"));
        assert!(axes
            .iter()
            .any(|(name, _)| *name == "transport_runtime_bytes_rejected"));
    }
}
