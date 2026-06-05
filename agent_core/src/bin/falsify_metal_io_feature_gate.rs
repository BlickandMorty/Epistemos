//! `falsify_metal_io_feature_gate`.
//!
//! Metadata-only witness for `F-MetalIO-FeatureGate`. It proves that Metal I/O
//! resource-loading lanes require explicit platform feature support and that
//! unsupported or unknown support falls back to visible CPU slabs before live
//! ColdStream, 70B, or product runtime claims can promote.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::SLAB_ARENA_COPY_COUNT_AXES;
#[cfg(test)]
use agent_core::falsifier_artifacts::axes::METAL_IO_FEATURE_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    MetalFeatureStatus, MetalIoFeatureDecision, MetalIoFeatureGateError, MetalIoFeatureGateWitness,
    MetalIoFeatureSurface, MetalIoLane, ProStatus, ProductBuild, METAL_IO_FEATURE_GATE_CURSOR,
    METAL_IO_FEATURE_GATE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-MetalIO-FeatureGate";
const FIXTURE_ID: &str = "metal_io_feature_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_metal_io_feature_gate.sh";
const RESULT: &str = "artifacts/falsifiers/metal_io_feature_gate/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const SLAB_ARENA_COPY_COUNT_PATH: &str = "artifacts/falsifiers/slab_arena_copy_count/result.json";
const MIN_DECISION_COUNT: u64 = 3;
const MIN_SURFACE_COUNT: u64 = 2;
const MIN_FEATURE_GATE_SUCCESS_BPS: u64 = 9_500;
const MAX_METADATA_BYTES: u64 = 256 * 1024;

#[derive(Debug)]
// UAS: uas:metal-io-feature-gate:witness-error
// Plane: Verification
// Residency: metadata-only artifact rejection taxonomy.
enum MetalIoWitnessError {
    Primitive(MetalIoFeatureGateError),
    Io(String),
}

impl std::fmt::Display for MetalIoWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for MetalIoWitnessError {}

impl From<MetalIoFeatureGateError> for MetalIoWitnessError {
    fn from(value: MetalIoFeatureGateError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, MetalIoWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fixture_witness()?;
    let metrics = witness.metrics();
    let address = witness.address();
    let mut reversed = witness.decisions.clone();
    reversed.reverse();
    let deterministic = MetalIoFeatureGateWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "feature_gate_only",
        witness.feature_gate_success_bps,
        witness.ungated_metal_baseline_bps,
        witness.no_fallback_baseline_bps,
        witness.hidden_metal_baseline_bps,
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
            "upstream_slab_arena_copy_count_pass",
            evidence.slab_arena_copy_count_pass,
        ),
        (
            "guard_cursor_metal_io_feature_gate_or_advanced",
            evidence.guard_next_existing_work == METAL_IO_FEATURE_GATE_CURSOR
                || evidence.guard_next_existing_work == METAL_IO_FEATURE_GATE_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_metal_io_feature_gate_or_advanced",
            evidence.capability_next_bottleneck == METAL_IO_FEATURE_GATE_CURSOR
                || evidence.capability_next_bottleneck == METAL_IO_FEATURE_GATE_NEXT_CURSOR,
        ),
        (
            "product_status_research_only",
            witness.product_build == ProductBuild::Pro
                && witness.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_feature_gate_only",
            witness.route_authority == "feature_gate_only",
        ),
        (
            "feature_decisions_bound",
            metrics.decision_count >= MIN_DECISION_COUNT,
        ),
        (
            "device_refs_bound",
            witness
                .decisions
                .iter()
                .all(|decision| decision.device_ref.starts_with("metal_device:")),
        ),
        (
            "gpu_family_refs_bound",
            witness
                .decisions
                .iter()
                .all(|decision| decision.gpu_family_ref.starts_with("gpu_family:")),
        ),
        (
            "feature_query_refs_bound",
            witness
                .decisions
                .iter()
                .all(|decision| decision.feature_query_ref.starts_with("feature_query:")),
        ),
        (
            "requested_features_bound",
            witness
                .decisions
                .iter()
                .all(|decision| !decision.requested_feature.is_empty()),
        ),
        (
            "supported_feature_routes_metal",
            witness.decisions.iter().any(|decision| {
                decision.feature_status == MetalFeatureStatus::Supported
                    && decision.selected_lane == MetalIoLane::MetalResourceLoading
                    && decision
                        .metal_buffer_lease_ref
                        .as_deref()
                        .is_some_and(|lease| lease.starts_with("metal_buffer_lease:"))
            }),
        ),
        (
            "unsupported_feature_routes_cpu_fallback",
            witness.decisions.iter().any(|decision| {
                decision.feature_status == MetalFeatureStatus::Unsupported
                    && decision.selected_lane == MetalIoLane::CpuSlabFallback
                    && decision.metal_buffer_lease_ref.is_none()
            }),
        ),
        (
            "unknown_feature_routes_cpu_fallback",
            witness.decisions.iter().any(|decision| {
                decision.feature_status == MetalFeatureStatus::Unknown
                    && decision.selected_lane == MetalIoLane::CpuSlabFallback
                    && decision.metal_buffer_lease_ref.is_none()
            }),
        ),
        (
            "cpu_fallback_bound",
            witness
                .decisions
                .iter()
                .all(|decision| decision.fallback_cpu_slab_ref.starts_with("cpu_slab:")),
        ),
        (
            "metal_buffer_lease_bound",
            witness.decisions.iter().all(|decision| {
                if decision.selected_lane == MetalIoLane::MetalResourceLoading {
                    decision
                        .metal_buffer_lease_ref
                        .as_deref()
                        .is_some_and(|lease| lease.starts_with("metal_buffer_lease:"))
                } else {
                    decision.metal_buffer_lease_ref.is_none()
                }
            }),
        ),
        (
            "visible_caveat_bound",
            witness
                .decisions
                .iter()
                .all(|decision| decision.visible_caveat.contains("metadata-only"))
                && witness
                    .surfaces
                    .iter()
                    .all(|surface| surface.body.contains("metadata-only")),
        ),
        (
            "answer_packet_refs_bound",
            metrics.answer_packet_count >= metrics.surface_count,
        ),
        (
            "run_event_log_refs_bound",
            witness
                .decisions
                .iter()
                .all(|decision| decision.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "rollback_bound",
            witness
                .decisions
                .iter()
                .all(|decision| decision.rollback_ref.starts_with("rollback:")),
        ),
        (
            "admission_bound",
            witness
                .decisions
                .iter()
                .all(|decision| decision.admission_ref.starts_with("admission:")),
        ),
        (
            "scope_rex_bound",
            witness
                .decisions
                .iter()
                .all(|decision| decision.scope_rex_ref.starts_with("scope_rex:")),
        ),
        (
            "sovereign_gate_bound",
            witness
                .decisions
                .iter()
                .all(|decision| decision.sovereign_gate_ref.starts_with("sovereign_gate:")),
        ),
        (
            "compatibility_fence_bound",
            witness
                .decisions
                .iter()
                .all(|decision| decision.compatibility_fence.starts_with("compat:")),
        ),
        (
            "cancel_group_bound",
            witness
                .decisions
                .iter()
                .all(|decision| decision.cancel_group_ref.starts_with("cancel_group:")),
        ),
        (
            "l1_l2_l3_separation_bound",
            witness.surfaces.iter().all(|surface| {
                surface.body.contains("L1")
                    && surface.body.contains("L2 remains")
                    && surface.body.contains("L3")
            }),
        ),
        (
            "no_hidden_route_authority",
            !witness.hidden_route_authority_attempted,
        ),
        (
            "no_route_policy_mutation",
            !witness.route_policy_mutation_attempted,
        ),
        ("no_gate_bypass", !witness.gate_bypass_attempted),
        (
            "no_answer_packet_suppression",
            !witness.answer_packet_suppression_attempted,
        ),
        ("no_hidden_chain", !witness.hidden_chain_exposure_attempted),
        ("no_hidden_cloud", !witness.hidden_cloud_route_attempted),
        ("no_ssd_as_ram_claim", !witness.ssd_as_ram_claim_attempted),
        ("no_mas_live_promotion", !witness.mas_promotion_attempted),
        (
            "no_live_benchmark_attempted",
            !witness.live_benchmark_attempted,
        ),
        ("no_runtime_bytes_loaded", metrics.runtime_bytes_loaded == 0),
        ("no_model_bytes_loaded", metrics.model_bytes_loaded == 0),
        (
            "no_metal_runtime_bytes_loaded",
            metrics.metal_runtime_bytes_loaded == 0,
        ),
        (
            "metadata_bound",
            metrics.max_metadata_bytes <= MAX_METADATA_BYTES,
        ),
        ("metal_io_feature_gate_address_deterministic", deterministic),
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
        "decision_count",
        metrics.decision_count,
        MIN_DECISION_COUNT,
        "decisions",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "supported_feature_count",
        metrics.supported_feature_count,
        1,
        "features",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unsupported_feature_count",
        metrics.unsupported_feature_count,
        1,
        "features",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unknown_feature_count",
        metrics.unknown_feature_count,
        1,
        "features",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metal_lane_count",
        metrics.metal_lane_count,
        1,
        "lanes",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cpu_fallback_count",
        metrics.cpu_fallback_count,
        2,
        "lanes",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "surface_count",
        metrics.surface_count,
        MIN_SURFACE_COUNT,
        "surfaces",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "answer_packet_count",
        metrics.answer_packet_count,
        3,
        "refs",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_bytes_loaded",
        metrics.runtime_bytes_loaded,
        0,
        "bytes",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_bytes_loaded",
        metrics.model_bytes_loaded,
        0,
        "bytes",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metal_runtime_bytes_loaded",
        metrics.metal_runtime_bytes_loaded,
        0,
        "bytes",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_metadata_bytes",
        metrics.max_metadata_bytes,
        MAX_METADATA_BYTES,
        "bytes",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "feature_gate_success_bps",
        metrics.feature_gate_success_bps as u64,
        MIN_FEATURE_GATE_SUCCESS_BPS,
        "bps",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "ungated_metal_baseline_bps",
        metrics.ungated_metal_baseline_bps as u64,
        metrics.feature_gate_success_bps.saturating_sub(1) as u64,
        "bps",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_fallback_baseline_bps",
        metrics.no_fallback_baseline_bps as u64,
        metrics.feature_gate_success_bps.saturating_sub(1) as u64,
        "bps",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hidden_metal_baseline_bps",
        metrics.hidden_metal_baseline_bps as u64,
        metrics.feature_gate_success_bps.saturating_sub(1) as u64,
        "bps",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metal_io_feature_gate_address",
        address,
        "uas:metal-io-feature-gate:sha256:",
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
            "kind": "metal_io_feature_gate_metadata_only",
            "detail": "Metal feature-gate decisions are L1 metadata proof only: no live Metal I/O benchmark, no model bytes, no dense 70B, no KV-Direct 128K, and no product runtime promotion."
        })],
        notes: "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. F-MetalIO-FeatureGate proves supported Metal features can name a MetalBufferLease while unsupported or unknown features visibly fall back to CPU slabs with rollback, RunEventLog, SCOPE-Rex/SovereignGate admission, compatibility fences, cancellation, and AnswerPacket caveats. L1 architecture cursor advances only; L2 remains vault_research_route_with_packetized_mitigation and L3 product runtime is unchanged."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn invalid_fixture_axes() -> Result<Vec<(&'static str, bool)>, MetalIoWitnessError> {
    Ok(vec![
        (
            "empty_decision_rejected",
            matches!(
                reject_witness(|witness| witness.decisions.clear()),
                Err(MetalIoFeatureGateError::EmptyDecision)
            ),
        ),
        (
            "empty_surface_rejected",
            matches!(
                reject_witness(|witness| witness.surfaces.clear()),
                Err(MetalIoFeatureGateError::EmptySurface)
            ),
        ),
        (
            "duplicate_decision_rejected",
            matches!(
                reject_witness(|witness| {
                    let duplicate = witness.decisions[0].clone();
                    witness.decisions.push(duplicate);
                }),
                Err(MetalIoFeatureGateError::DuplicateDecision(_))
            ),
        ),
        (
            "duplicate_surface_rejected",
            matches!(
                reject_witness(|witness| {
                    let duplicate = witness.surfaces[0].clone();
                    witness.surfaces.push(duplicate);
                }),
                Err(MetalIoFeatureGateError::DuplicateSurface(_))
            ),
        ),
        (
            "duplicate_answer_packet_rejected",
            matches!(
                reject_one_decision(|decision| {
                    decision.answer_packet_ref = "answer_packet:metal-io-supported".to_string();
                }, 1),
                Err(MetalIoFeatureGateError::DuplicateAnswerPacket(_))
            ),
        ),
        (
            "missing_device_ref_rejected",
            matches!(
                reject_one_decision(|decision| decision.device_ref.clear(), 0),
                Err(MetalIoFeatureGateError::MissingDeviceRef(_))
            ),
        ),
        (
            "missing_gpu_family_ref_rejected",
            matches!(
                reject_one_decision(|decision| decision.gpu_family_ref.clear(), 0),
                Err(MetalIoFeatureGateError::MissingGpuFamilyRef(_))
            ),
        ),
        (
            "missing_feature_query_ref_rejected",
            matches!(
                reject_one_decision(|decision| decision.feature_query_ref.clear(), 0),
                Err(MetalIoFeatureGateError::MissingFeatureQueryRef(_))
            ),
        ),
        (
            "missing_requested_feature_rejected",
            matches!(
                reject_one_decision(|decision| decision.requested_feature.clear(), 0),
                Err(MetalIoFeatureGateError::MissingRequestedFeature(_))
            ),
        ),
        (
            "missing_metal_buffer_lease_rejected",
            matches!(
                reject_one_decision(|decision| decision.metal_buffer_lease_ref = None, 0),
                Err(MetalIoFeatureGateError::MissingMetalBufferLease(_))
            ),
        ),
        (
            "unexpected_metal_buffer_lease_rejected",
            matches!(
                reject_one_decision(|decision| {
                    decision.metal_buffer_lease_ref =
                        Some("metal_buffer_lease:unexpected-fallback".to_string());
                }, 1),
                Err(MetalIoFeatureGateError::UnexpectedMetalBufferLease(_))
            ),
        ),
        (
            "missing_cpu_slab_fallback_rejected",
            matches!(
                reject_one_decision(|decision| decision.fallback_cpu_slab_ref.clear(), 0),
                Err(MetalIoFeatureGateError::MissingCpuSlabFallback(_))
            ),
        ),
        (
            "missing_answer_packet_rejected",
            matches!(
                reject_one_decision(|decision| decision.answer_packet_ref.clear(), 0),
                Err(MetalIoFeatureGateError::MissingAnswerPacket(_))
            ),
        ),
        (
            "missing_run_event_log_rejected",
            matches!(
                reject_one_decision(|decision| decision.run_event_log_ref.clear(), 0),
                Err(MetalIoFeatureGateError::MissingRunEventLog(_))
            ),
        ),
        (
            "missing_rollback_rejected",
            matches!(
                reject_one_decision(|decision| decision.rollback_ref.clear(), 0),
                Err(MetalIoFeatureGateError::MissingRollback(_))
            ),
        ),
        (
            "missing_admission_rejected",
            matches!(
                reject_one_decision(|decision| decision.admission_ref.clear(), 0),
                Err(MetalIoFeatureGateError::MissingAdmission)
            ),
        ),
        (
            "missing_scope_rex_rejected",
            matches!(
                reject_one_decision(|decision| decision.scope_rex_ref.clear(), 0),
                Err(MetalIoFeatureGateError::MissingScopeRex)
            ),
        ),
        (
            "missing_sovereign_gate_rejected",
            matches!(
                reject_one_decision(|decision| decision.sovereign_gate_ref.clear(), 0),
                Err(MetalIoFeatureGateError::MissingSovereignGate)
            ),
        ),
        (
            "missing_compatibility_fence_rejected",
            matches!(
                reject_one_decision(|decision| decision.compatibility_fence.clear(), 0),
                Err(MetalIoFeatureGateError::MissingCompatibilityFence(_))
            ),
        ),
        (
            "missing_cancel_group_rejected",
            matches!(
                reject_one_decision(|decision| decision.cancel_group_ref.clear(), 0),
                Err(MetalIoFeatureGateError::MissingCancelGroup(_))
            ),
        ),
        (
            "missing_visible_caveat_rejected",
            matches!(
                reject_one_decision(|decision| decision.visible_caveat.clear(), 0),
                Err(MetalIoFeatureGateError::MissingVisibleCaveat(_))
            ),
        ),
        (
            "missing_required_marker_rejected",
            matches!(
                reject_surface(|surface| surface.body = surface.body.replace("Metal", "GPU")),
                Err(MetalIoFeatureGateError::MissingRequiredMarker(_))
            ),
        ),
        (
            "forbidden_marker_rejected",
            matches!(
                reject_surface(|surface| {
                    surface.body.push_str(" Metal is always available.");
                }),
                Err(MetalIoFeatureGateError::ForbiddenMarker(_))
            ),
        ),
        (
            "missing_layer_separation_rejected",
            matches!(
                reject_witness(|witness| {
                    witness.decisions.remove(0);
                }),
                Err(MetalIoFeatureGateError::MissingLayerSeparation)
            ),
        ),
        (
            "unsupported_feature_selected_metal_rejected",
            matches!(
                reject_one_decision(|decision| {
                    decision.feature_status = MetalFeatureStatus::Unsupported;
                    decision.selected_lane = MetalIoLane::MetalResourceLoading;
                }, 1),
                Err(MetalIoFeatureGateError::UnsupportedFeatureSelectedMetal(_))
            ),
        ),
        (
            "supported_feature_selected_fallback_rejected",
            matches!(
                reject_one_decision(|decision| {
                    decision.selected_lane = MetalIoLane::CpuSlabFallback;
                    decision.metal_buffer_lease_ref = None;
                }, 0),
                Err(MetalIoFeatureGateError::SupportedFeatureSelectedFallback(_))
            ),
        ),
        (
            "hidden_route_authority_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_route_authority_attempted = true),
                Err(MetalIoFeatureGateError::HiddenRouteAuthority)
            ),
        ),
        (
            "route_policy_mutation_rejected",
            matches!(
                reject_witness(|witness| witness.route_policy_mutation_attempted = true),
                Err(MetalIoFeatureGateError::RoutePolicyMutation)
            ),
        ),
        (
            "gate_bypass_rejected",
            matches!(
                reject_witness(|witness| witness.gate_bypass_attempted = true),
                Err(MetalIoFeatureGateError::GateBypass)
            ),
        ),
        (
            "answer_packet_suppression_rejected",
            matches!(
                reject_witness(|witness| witness.answer_packet_suppression_attempted = true),
                Err(MetalIoFeatureGateError::AnswerPacketSuppression)
            ),
        ),
        (
            "hidden_chain_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_chain_exposure_attempted = true),
                Err(MetalIoFeatureGateError::HiddenChainExposure)
            ),
        ),
        (
            "hidden_cloud_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_cloud_route_attempted = true),
                Err(MetalIoFeatureGateError::HiddenCloudRoute)
            ),
        ),
        (
            "ssd_as_ram_rejected",
            matches!(
                reject_witness(|witness| witness.ssd_as_ram_claim_attempted = true),
                Err(MetalIoFeatureGateError::SsdAsRamClaim)
            ),
        ),
        (
            "mas_product_build_rejected",
            matches!(
                reject_witness(|witness| witness.product_build = ProductBuild::Mas),
                Err(MetalIoFeatureGateError::ProductStatusMismatch)
            ),
        ),
        (
            "live_pro_status_rejected",
            matches!(
                reject_witness(|witness| witness.pro_status = ProStatus::Live),
                Err(MetalIoFeatureGateError::ProductStatusMismatch)
            ),
        ),
        (
            "mas_live_promotion_rejected",
            matches!(
                reject_witness(|witness| witness.mas_promotion_attempted = true),
                Err(MetalIoFeatureGateError::MasPromotionAttempted)
            ),
        ),
        (
            "live_benchmark_rejected",
            matches!(
                reject_witness(|witness| witness.live_benchmark_attempted = true),
                Err(MetalIoFeatureGateError::LiveBenchmarkAttempted)
            ),
        ),
        (
            "runtime_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.runtime_bytes_loaded = 1),
                Err(MetalIoFeatureGateError::RuntimeBytesLoaded)
            ),
        ),
        (
            "model_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.model_bytes_loaded = 1),
                Err(MetalIoFeatureGateError::ModelBytesLoaded)
            ),
        ),
        (
            "metal_runtime_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.metal_runtime_bytes_loaded = 1),
                Err(MetalIoFeatureGateError::MetalRuntimeBytesLoaded)
            ),
        ),
        (
            "ungated_metal_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.ungated_metal_baseline_bps = 9_850),
                Err(MetalIoFeatureGateError::BaselineUnbeaten("ungated_metal"))
            ),
        ),
        (
            "no_fallback_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.no_fallback_baseline_bps = 9_850),
                Err(MetalIoFeatureGateError::BaselineUnbeaten("no_fallback"))
            ),
        ),
        (
            "hidden_metal_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_metal_baseline_bps = 9_850),
                Err(MetalIoFeatureGateError::BaselineUnbeaten("hidden_metal"))
            ),
        ),
        (
            "metadata_budget_rejected",
            matches!(
                reject_witness(|witness| witness.max_metadata_bytes = MAX_METADATA_BYTES + 1),
                Err(MetalIoFeatureGateError::MetadataBudgetExceeded)
            ),
        ),
    ])
}

fn fixture_witness() -> Result<MetalIoFeatureGateWitness, MetalIoFeatureGateError> {
    MetalIoFeatureGateWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "feature_gate_only",
        9_850,
        8_100,
        7_900,
        7_600,
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
        fixture_decisions()?,
        fixture_surfaces()?,
    )
}

fn fixture_decisions() -> Result<Vec<MetalIoFeatureDecision>, MetalIoFeatureGateError> {
    Ok(vec![
        decision(
            "decision:metal-supported",
            MetalFeatureStatus::Supported,
            MetalIoLane::MetalResourceLoading,
            Some("metal_buffer_lease:residency-set-a:range-0".to_string()),
            "answer_packet:metal-io-supported",
        )?,
        decision(
            "decision:metal-unsupported",
            MetalFeatureStatus::Unsupported,
            MetalIoLane::CpuSlabFallback,
            None,
            "answer_packet:metal-io-unsupported",
        )?,
        decision(
            "decision:metal-unknown",
            MetalFeatureStatus::Unknown,
            MetalIoLane::CpuSlabFallback,
            None,
            "answer_packet:metal-io-unknown",
        )?,
    ])
}

fn fixture_surfaces() -> Result<Vec<MetalIoFeatureSurface>, MetalIoFeatureGateError> {
    Ok(vec![
        MetalIoFeatureSurface::new(
            "surface:metal-io-gate",
            "answer_packet:metal-io-surface-a",
            "Metal I/O remains metadata-only L1 proof: supported feature decisions may name a MetalBufferLease, unsupported or unknown decisions use CPU fallback, rollback and AnswerPacket caveats; L2 remains vault research and L3 product runtime is unchanged.",
        )?,
        MetalIoFeatureSurface::new(
            "surface:metal-io-fallback",
            "answer_packet:metal-io-surface-b",
            "Fallback is visible metadata-only evidence: no covert route control, every Metal decision carries rollback and AnswerPacket refs, CPU fallback is mandatory, L1 advances only while L2 remains red and L3 stays unchanged.",
        )?,
    ])
}

fn decision(
    decision_id: &str,
    status: MetalFeatureStatus,
    lane: MetalIoLane,
    lease: Option<String>,
    answer_packet: &str,
) -> Result<MetalIoFeatureDecision, MetalIoFeatureGateError> {
    MetalIoFeatureDecision::new(
        decision_id,
        "mission:coldstream-metal-gate",
        "metal_device:m2-pro-primary",
        "gpu_family:apple7-or-newer",
        "feature_query:supports-family-resource-loading",
        "resource_loading",
        status,
        lane,
        lease,
        format!("cpu_slab:{decision_id}:fallback"),
        answer_packet,
        format!("run_event_log:{decision_id}"),
        format!("rollback:{decision_id}"),
        "admission:scope-rex-metal-io-feature-gate",
        "scope_rex:metal-io-feature-gate",
        "sovereign_gate:metal-io-feature-gate",
        "compat:metal-family-resource-loading-v1",
        format!("cancel_group:{decision_id}"),
        "Metal I/O feature decision is metadata-only L1 evidence with CPU fallback, rollback, and AnswerPacket visibility; L2 remains vault research and L3 product runtime is unchanged until live transport witnesses pass.",
    )
}

fn reject_witness(
    mutate: impl FnOnce(&mut MetalIoFeatureGateWitness),
) -> Result<MetalIoFeatureGateWitness, MetalIoFeatureGateError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness);
    rebuild_witness(witness)
}

fn reject_one_decision(
    mutate: impl FnOnce(&mut MetalIoFeatureDecision),
    index: usize,
) -> Result<MetalIoFeatureGateWitness, MetalIoFeatureGateError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness.decisions[index]);
    rebuild_witness(witness)
}

fn reject_surface(
    mutate: impl FnOnce(&mut MetalIoFeatureSurface),
) -> Result<MetalIoFeatureGateWitness, MetalIoFeatureGateError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness.surfaces[0]);
    rebuild_witness(witness)
}

fn rebuild_witness(
    witness: MetalIoFeatureGateWitness,
) -> Result<MetalIoFeatureGateWitness, MetalIoFeatureGateError> {
    MetalIoFeatureGateWitness::new(
        witness.product_build,
        witness.pro_status,
        witness.route_authority,
        witness.feature_gate_success_bps,
        witness.ungated_metal_baseline_bps,
        witness.no_fallback_baseline_bps,
        witness.hidden_metal_baseline_bps,
        witness.runtime_bytes_loaded,
        witness.model_bytes_loaded,
        witness.metal_runtime_bytes_loaded,
        witness.max_metadata_bytes,
        witness.hidden_route_authority_attempted,
        witness.route_policy_mutation_attempted,
        witness.gate_bypass_attempted,
        witness.answer_packet_suppression_attempted,
        witness.hidden_chain_exposure_attempted,
        witness.hidden_cloud_route_attempted,
        witness.ssd_as_ram_claim_attempted,
        witness.mas_promotion_attempted,
        witness.live_benchmark_attempted,
        witness.decisions,
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
// UAS: Binds upstream witness refs used to prove Metal I/O feature-gate lineage.
// Plane: Verification.
// Residency: Metadata-only evidence; no runtime/model/Metal bytes are loaded.
struct EvidenceSnapshot {
    slab_arena_copy_count_pass: bool,
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, MetalIoWitnessError> {
        let slab = read_json(SLAB_ARENA_COPY_COUNT_PATH)?;
        let guard = read_json(GUARD_PATH)?;
        let capability = read_json(CAPABILITY_PATH)?;
        Ok(Self {
            slab_arena_copy_count_pass: slab
                .get("overall_pass")
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false)
                && axes_all_present(&slab, SLAB_ARENA_COPY_COUNT_AXES),
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

fn read_json(path: &'static str) -> Result<serde_json::Value, MetalIoWitnessError> {
    let text = read_text(path)?;
    serde_json::from_str(&text)
        .map_err(|error| MetalIoWitnessError::Io(format!("failed to parse {path}: {error}")))
}

fn read_text(path: &'static str) -> Result<String, MetalIoWitnessError> {
    let workspace_root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap_or_else(|| Path::new("."));
    let resolved = workspace_root.join(path);
    std::fs::read_to_string(resolved)
        .map_err(|error| MetalIoWitnessError::Io(format!("failed to read {path}: {error}")))
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
        let mut expected = METAL_IO_FEATURE_GATE_AXES.to_vec();
        expected.sort_unstable();
        assert_eq!(actual, expected);
    }

    #[test]
    fn invalid_axes_are_exercised() {
        let axes = invalid_fixture_axes().expect("invalid axes");
        assert!(axes.iter().all(|(_, passed)| *passed));
        assert!(axes
            .iter()
            .any(|(name, _)| *name == "unsupported_feature_selected_metal_rejected"));
        assert!(axes
            .iter()
            .any(|(name, _)| *name == "metal_runtime_bytes_rejected"));
    }
}
