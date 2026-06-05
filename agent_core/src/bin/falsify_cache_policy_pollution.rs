//! `falsify_cache_policy_pollution`.
//!
//! Metadata-only witness for `F-CachePolicy-Pollution`. It proves explicit
//! cache policy choices are bounded against repeated hot-route performance
//! before any live ColdStream, 70B, or product runtime claim can promote.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::{
    CACHE_POLICY_POLLUTION_AXES, TRANSPORT_CANCELLATION_AXES,
};
use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    CachePolicyLane, CachePolicyPollutionError, CachePolicyPollutionWitness, CachePolicySurface,
    CachePolicyTrial, ProStatus, ProductBuild, CACHE_POLICY_POLLUTION_CURSOR,
    CACHE_POLICY_POLLUTION_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-CachePolicy-Pollution";
const FIXTURE_ID: &str = "cache_policy_pollution_v1";
const COMMAND: &str = "Tools/falsifiers/f_cache_policy_pollution.sh";
const RESULT: &str = "artifacts/falsifiers/cache_policy_pollution/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const TRANSPORT_CANCELLATION_PATH: &str = "artifacts/falsifiers/transport_cancellation/result.json";
const MIN_TRIAL_COUNT: u64 = 3;
const MIN_SURFACE_COUNT: u64 = 2;
const MIN_SUCCESS_BPS: u64 = 9_300;
const MAX_METADATA_BYTES: u64 = 256 * 1024;
const MAX_HOT_ROUTE_REGRESSION_BPS: u64 = 250;
const MAX_CACHE_POLLUTION_BPS: u64 = 800;

#[derive(Debug)]
// UAS: uas:cache-policy-pollution:witness-error
// Plane: Verification
// Residency: metadata-only artifact rejection taxonomy.
enum CachePolicyWitnessError {
    Primitive(CachePolicyPollutionError),
    Io(String),
}

impl std::fmt::Display for CachePolicyWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for CachePolicyWitnessError {}

impl From<CachePolicyPollutionError> for CachePolicyWitnessError {
    fn from(value: CachePolicyPollutionError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, CachePolicyWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fixture_witness()?;
    let metrics = witness.metrics();
    let address = witness.address();
    let mut reversed = witness.trials.clone();
    reversed.reverse();
    let deterministic = CachePolicyPollutionWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "cache_policy_pollution_gate_only",
        witness.cache_policy_success_bps,
        witness.no_explicit_policy_baseline_bps,
        witness.always_cache_baseline_bps,
        witness.hidden_policy_baseline_bps,
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
            "upstream_transport_cancellation_pass",
            evidence.transport_cancellation_pass,
        ),
        (
            "guard_cursor_cache_policy_pollution_or_advanced",
            evidence.guard_next_existing_work == CACHE_POLICY_POLLUTION_CURSOR
                || evidence.guard_next_existing_work == CACHE_POLICY_POLLUTION_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_cache_policy_pollution_or_advanced",
            evidence.capability_next_bottleneck == CACHE_POLICY_POLLUTION_CURSOR
                || evidence.capability_next_bottleneck == CACHE_POLICY_POLLUTION_NEXT_CURSOR,
        ),
        (
            "product_status_research_only",
            witness.product_build == ProductBuild::Pro
                && witness.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_cache_policy_gate_only",
            witness.route_authority == "cache_policy_pollution_gate_only",
        ),
        (
            "cache_policy_trials_bound",
            metrics.trial_count as u64 >= MIN_TRIAL_COUNT,
        ),
        (
            "visible_surfaces_bound",
            metrics.surface_count as u64 >= MIN_SURFACE_COUNT,
        ),
        (
            "streaming_no_cache_trial_bound",
            metrics.no_cache_count >= 1,
        ),
        ("hot_reuse_trial_bound", metrics.hot_reuse_count >= 1),
        (
            "metadata_only_trial_bound",
            metrics.metadata_only_count >= 1,
        ),
        (
            "policy_lane_diversity_bound",
            metrics.policy_lane_count >= 3,
        ),
        (
            "cache_policy_refs_bound",
            witness
                .trials
                .iter()
                .all(|trial| trial.cache_policy_ref.starts_with("cache_policy:")),
        ),
        (
            "hot_route_refs_bound",
            witness
                .trials
                .iter()
                .all(|trial| trial.hot_route_ref.starts_with("hot_route:")),
        ),
        (
            "repeated_probe_refs_bound",
            witness
                .trials
                .iter()
                .all(|trial| trial.repeated_probe_ref.starts_with("repeated_probe:")),
        ),
        (
            "transport_trace_refs_bound",
            witness
                .trials
                .iter()
                .all(|trial| trial.transport_trace_ref.starts_with("transport_trace:")),
        ),
        (
            "cancellation_refs_bound",
            witness.trials.iter().all(|trial| {
                trial
                    .cancellation_ref
                    .starts_with("transport_cancellation:")
            }),
        ),
        (
            "answer_packet_refs_bound",
            metrics.answer_packet_count >= metrics.surface_count,
        ),
        (
            "run_event_log_refs_bound",
            witness
                .trials
                .iter()
                .all(|trial| trial.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "rollback_bound",
            witness
                .trials
                .iter()
                .all(|trial| trial.rollback_ref.starts_with("rollback:")),
        ),
        (
            "admission_bound",
            witness
                .trials
                .iter()
                .all(|trial| trial.admission_ref.starts_with("admission:")),
        ),
        (
            "scope_rex_bound",
            witness
                .trials
                .iter()
                .all(|trial| trial.scope_rex_ref.starts_with("scope_rex:")),
        ),
        (
            "sovereign_gate_bound",
            witness
                .trials
                .iter()
                .all(|trial| trial.sovereign_gate_ref.starts_with("sovereign_gate:")),
        ),
        (
            "compatibility_fence_bound",
            witness
                .trials
                .iter()
                .all(|trial| trial.compatibility_fence.starts_with("compat:")),
        ),
        (
            "explicit_policy_decisions_bound",
            witness
                .trials
                .iter()
                .all(|trial| trial.explicit_policy_decision),
        ),
        (
            "hot_route_p95_p99_bound",
            witness.trials.iter().all(|trial| {
                trial.hot_route_p99_before_ms >= trial.hot_route_p95_before_ms
                    && trial.hot_route_p99_after_ms >= trial.hot_route_p95_after_ms
            }),
        ),
        (
            "hot_route_regression_budget_bound",
            metrics.max_hot_route_regression_bps as u64 <= MAX_HOT_ROUTE_REGRESSION_BPS,
        ),
        (
            "cache_pollution_budget_bound",
            metrics.max_cache_pollution_bps as u64 <= MAX_CACHE_POLLUTION_BPS,
        ),
        (
            "read_amplification_bound",
            witness.trials.iter().all(|trial| {
                trial.read_amplification_bps > 0 && trial.read_amplification_bps <= 20_000
            }),
        ),
        (
            "repeated_probe_count_bound",
            metrics.min_repeated_probe_count >= 3,
        ),
        ("reuse_horizon_bound", metrics.min_reuse_horizon_ms > 0),
        (
            "visible_caveat_bound",
            witness.trials.iter().all(|trial| {
                trial.visible_caveat.contains("metadata-only")
                    && trial.visible_caveat.contains("cache policy")
                    && trial.visible_caveat.contains("hot route")
                    && trial.visible_caveat.contains("repeated probe")
                    && trial.visible_caveat.contains("AnswerPacket")
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
            "cache_policy_pollution_address_deterministic",
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
        "trial_count",
        metrics.trial_count as u64,
        MIN_TRIAL_COUNT,
        "trials",
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
        "policy_lane_count",
        metrics.policy_lane_count as u64,
        3,
        "lanes",
    );
    for (name, value) in [
        ("no_cache_count", metrics.no_cache_count as u64),
        ("hot_reuse_count", metrics.hot_reuse_count as u64),
        ("metadata_only_count", metrics.metadata_only_count as u64),
    ] {
        add_min_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            value,
            1,
            "trials",
        );
    }
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "total_cold_bytes",
        metrics.total_cold_bytes,
        1,
        "bytes",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_hot_route_regression_bps",
        metrics.max_hot_route_regression_bps as u64,
        MAX_HOT_ROUTE_REGRESSION_BPS,
        "bps",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_cache_pollution_bps",
        metrics.max_cache_pollution_bps as u64,
        MAX_CACHE_POLLUTION_BPS,
        "bps",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_hot_route_p99_after_ms",
        metrics.max_hot_route_p99_after_ms as u64,
        1,
        "ms",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_reuse_horizon_ms",
        metrics.min_reuse_horizon_ms,
        1,
        "ms",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_repeated_probe_count",
        metrics.min_repeated_probe_count as u64,
        3,
        "probes",
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
        "cache_policy_success_bps",
        witness.cache_policy_success_bps as u64,
        MIN_SUCCESS_BPS,
        "bps",
    );
    for (name, value) in [
        (
            "no_explicit_policy_baseline_bps",
            witness.no_explicit_policy_baseline_bps,
        ),
        (
            "always_cache_baseline_bps",
            witness.always_cache_baseline_bps,
        ),
        (
            "hidden_policy_baseline_bps",
            witness.hidden_policy_baseline_bps,
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
            witness.cache_policy_success_bps.saturating_sub(1) as u64,
            "bps",
        );
    }
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cache_policy_pollution_address",
        address,
        "uas:cache-policy-pollution:sha256:",
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
            "kind": "cache_policy_pollution_metadata_only",
            "detail": "Cache-policy pollution is L1 metadata proof only: repeated hot-route probes, explicit NoCache/HotReuse/metadata policies, regression budgets, rollback, RunEventLog, SCOPE-Rex/SovereignGate admission, and visible AnswerPacket caveats are bound, but no live transport benchmark, model bytes, dense 70B, KV-Direct 128K, or product runtime promotion is claimed."
        })],
        notes: "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. F-CachePolicy-Pollution proves cache policy choices are explicit, repeated hot-route p95/p99 regression is budgeted, cache pollution is bounded, rollback/RunEventLog/SCOPE-Rex/SovereignGate/AnswerPacket caveats are visible, and L1 advances only. L2 remains vault_research_route_with_packetized_mitigation and L3 product runtime is unchanged."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    debug_assert!(
        CACHE_POLICY_POLLUTION_AXES
            .iter()
            .all(|axis| artifact.pass_per_axis.contains_key(*axis)),
        "axis list and artifact builder diverged"
    );

    Ok(artifact)
}

fn invalid_fixture_axes() -> Result<Vec<(&'static str, bool)>, CachePolicyWitnessError> {
    Ok(vec![
        (
            "empty_trial_rejected",
            matches!(
                reject_witness(|witness| witness.trials.clear()),
                Err(CachePolicyPollutionError::EmptyTrial)
            ),
        ),
        (
            "empty_surface_rejected",
            matches!(
                reject_witness(|witness| witness.surfaces.clear()),
                Err(CachePolicyPollutionError::EmptySurface)
            ),
        ),
        (
            "duplicate_trial_rejected",
            matches!(
                reject_witness(|witness| witness.trials.push(witness.trials[0].clone())),
                Err(CachePolicyPollutionError::DuplicateTrial(_))
            ),
        ),
        (
            "duplicate_surface_rejected",
            matches!(
                reject_witness(|witness| witness.surfaces.push(witness.surfaces[0].clone())),
                Err(CachePolicyPollutionError::DuplicateSurface(_))
            ),
        ),
        (
            "duplicate_answer_packet_rejected",
            matches!(
                reject_trial(
                    |trial| trial.answer_packet_ref = "answer_packet:no-cache".to_string(),
                    1
                ),
                Err(CachePolicyPollutionError::DuplicateAnswerPacket(_))
            ),
        ),
        (
            "missing_cache_policy_rejected",
            matches!(
                reject_trial(|trial| trial.cache_policy_ref.clear(), 0),
                Err(CachePolicyPollutionError::MissingField("cache_policy_ref"))
                    | Err(CachePolicyPollutionError::MissingCachePolicy(_))
            ),
        ),
        (
            "missing_hot_route_rejected",
            matches!(
                reject_trial(|trial| trial.hot_route_ref.clear(), 0),
                Err(CachePolicyPollutionError::MissingField("hot_route_ref"))
                    | Err(CachePolicyPollutionError::MissingHotRoute(_))
            ),
        ),
        (
            "missing_repeated_probe_rejected",
            matches!(
                reject_trial(|trial| trial.repeated_probe_ref.clear(), 0),
                Err(CachePolicyPollutionError::MissingField(
                    "repeated_probe_ref"
                )) | Err(CachePolicyPollutionError::MissingRepeatedProbe(_))
            ),
        ),
        (
            "missing_transport_trace_rejected",
            matches!(
                reject_trial(|trial| trial.transport_trace_ref.clear(), 0),
                Err(CachePolicyPollutionError::MissingField(
                    "transport_trace_ref"
                )) | Err(CachePolicyPollutionError::MissingTransportTrace(_))
            ),
        ),
        (
            "missing_cancellation_rejected",
            matches!(
                reject_trial(|trial| trial.cancellation_ref.clear(), 0),
                Err(CachePolicyPollutionError::MissingField("cancellation_ref"))
                    | Err(CachePolicyPollutionError::MissingCancellation(_))
            ),
        ),
        (
            "missing_answer_packet_rejected",
            matches!(
                reject_trial(|trial| trial.answer_packet_ref.clear(), 0),
                Err(CachePolicyPollutionError::MissingField("answer_packet_ref"))
                    | Err(CachePolicyPollutionError::MissingAnswerPacket(_))
            ),
        ),
        (
            "missing_run_event_log_rejected",
            matches!(
                reject_trial(|trial| trial.run_event_log_ref.clear(), 0),
                Err(CachePolicyPollutionError::MissingField("run_event_log_ref"))
                    | Err(CachePolicyPollutionError::MissingRunEventLog(_))
            ),
        ),
        (
            "missing_rollback_rejected",
            matches!(
                reject_trial(|trial| trial.rollback_ref.clear(), 0),
                Err(CachePolicyPollutionError::MissingField("rollback_ref"))
                    | Err(CachePolicyPollutionError::MissingRollback(_))
            ),
        ),
        (
            "missing_admission_rejected",
            matches!(
                reject_trial(|trial| trial.admission_ref.clear(), 0),
                Err(CachePolicyPollutionError::MissingField("admission_ref"))
                    | Err(CachePolicyPollutionError::MissingAdmission)
            ),
        ),
        (
            "missing_scope_rex_rejected",
            matches!(
                reject_trial(|trial| trial.scope_rex_ref.clear(), 0),
                Err(CachePolicyPollutionError::MissingField("scope_rex_ref"))
                    | Err(CachePolicyPollutionError::MissingScopeRex)
            ),
        ),
        (
            "missing_sovereign_gate_rejected",
            matches!(
                reject_trial(|trial| trial.sovereign_gate_ref.clear(), 0),
                Err(CachePolicyPollutionError::MissingField(
                    "sovereign_gate_ref"
                )) | Err(CachePolicyPollutionError::MissingSovereignGate)
            ),
        ),
        (
            "missing_compatibility_fence_rejected",
            matches!(
                reject_trial(|trial| trial.compatibility_fence.clear(), 0),
                Err(CachePolicyPollutionError::MissingField(
                    "compatibility_fence"
                )) | Err(CachePolicyPollutionError::MissingCompatibilityFence(_))
            ),
        ),
        (
            "missing_visible_caveat_rejected",
            matches!(
                reject_trial(|trial| trial.visible_caveat.clear(), 0),
                Err(CachePolicyPollutionError::MissingField("visible_caveat"))
                    | Err(CachePolicyPollutionError::MissingVisibleCaveat(_))
                    | Err(CachePolicyPollutionError::MissingRequiredMarker(_))
            ),
        ),
        (
            "missing_required_marker_rejected",
            matches!(
                reject_surface(|surface| {
                    surface.visible_summary =
                        surface.visible_summary.replace("AnswerPacket", "packet")
                }),
                Err(CachePolicyPollutionError::MissingRequiredMarker(_))
            ),
        ),
        (
            "forbidden_marker_rejected",
            matches!(
                reject_surface(|surface| surface
                    .visible_summary
                    .push_str(" live transport ready.")),
                Err(CachePolicyPollutionError::ForbiddenMarker(_))
            ),
        ),
        (
            "missing_layer_separation_rejected",
            matches!(
                reject_trial(|trial| trial.l1_l2_l3_separated = false, 0),
                Err(CachePolicyPollutionError::MissingLayerSeparation)
            ),
        ),
        (
            "missing_no_cache_trial_rejected",
            matches!(
                reject_witness(|witness| {
                    witness
                        .trials
                        .retain(|trial| trial.lane != CachePolicyLane::StreamingNoCache)
                }),
                Err(CachePolicyPollutionError::MissingStreamingNoCacheTrial)
            ),
        ),
        (
            "missing_hot_reuse_trial_rejected",
            matches!(
                reject_witness(|witness| {
                    witness
                        .trials
                        .retain(|trial| trial.lane != CachePolicyLane::HotReuse)
                }),
                Err(CachePolicyPollutionError::MissingHotReuseTrial)
            ),
        ),
        (
            "missing_metadata_only_trial_rejected",
            matches!(
                reject_witness(|witness| {
                    witness
                        .trials
                        .retain(|trial| trial.lane != CachePolicyLane::MetadataOnly)
                }),
                Err(CachePolicyPollutionError::MissingMetadataOnlyTrial)
            ),
        ),
        (
            "policy_decision_not_explicit_rejected",
            matches!(
                reject_trial(|trial| trial.explicit_policy_decision = false, 0),
                Err(CachePolicyPollutionError::PolicyDecisionNotExplicit(_))
            ),
        ),
        (
            "policy_lane_mismatch_rejected",
            matches!(
                reject_trial(
                    |trial| trial.cache_policy_ref = "cache_policy:hot-reuse:mismatch".to_string(),
                    0
                ),
                Err(CachePolicyPollutionError::PolicyLaneMismatch(_))
            ),
        ),
        (
            "zero_cold_bytes_rejected",
            matches!(
                reject_trial(|trial| trial.cold_bytes = 0, 0),
                Err(CachePolicyPollutionError::ZeroColdBytes(_))
            ),
        ),
        (
            "zero_probe_count_rejected",
            matches!(
                reject_trial(|trial| trial.repeated_probe_count = 0, 0),
                Err(CachePolicyPollutionError::ZeroProbeCount(_))
            ),
        ),
        (
            "p99_below_p95_rejected",
            matches!(
                reject_trial(|trial| trial.hot_route_p99_after_ms = 8, 0),
                Err(CachePolicyPollutionError::P99BelowP95(_))
            ),
        ),
        (
            "hot_route_regression_exceeded_rejected",
            matches!(
                reject_trial(|trial| trial.observed_regression_bps = 300, 0),
                Err(CachePolicyPollutionError::HotRouteRegressionExceeded(_))
            ),
        ),
        (
            "cache_pollution_exceeded_rejected",
            matches!(
                reject_trial(|trial| trial.cache_pollution_bps = 900, 0),
                Err(CachePolicyPollutionError::CachePollutionExceeded(_))
            ),
        ),
        (
            "read_amplification_rejected",
            matches!(
                reject_trial(|trial| trial.read_amplification_bps = 0, 0),
                Err(CachePolicyPollutionError::ReadAmplificationInvalid(_))
            ),
        ),
        (
            "reuse_horizon_missing_rejected",
            matches!(
                reject_trial(|trial| trial.reuse_horizon_ms = 0, 0),
                Err(CachePolicyPollutionError::ReuseHorizonMissing(_))
            ),
        ),
        (
            "hidden_route_authority_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_route_authority = true),
                Err(CachePolicyPollutionError::HiddenRouteAuthority)
            ),
        ),
        (
            "route_policy_mutation_rejected",
            matches!(
                reject_witness(|witness| witness.route_policy_mutation = true),
                Err(CachePolicyPollutionError::RoutePolicyMutation)
            ),
        ),
        (
            "gate_bypass_rejected",
            matches!(
                reject_witness(|witness| witness.gate_bypass = true),
                Err(CachePolicyPollutionError::GateBypass)
            ),
        ),
        (
            "answer_packet_suppression_rejected",
            matches!(
                reject_witness(|witness| witness.answer_packet_suppression = true),
                Err(CachePolicyPollutionError::AnswerPacketSuppression)
            ),
        ),
        (
            "hidden_chain_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_chain_exposed = true),
                Err(CachePolicyPollutionError::HiddenChainExposure)
            ),
        ),
        (
            "hidden_cloud_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_cloud_route = true),
                Err(CachePolicyPollutionError::HiddenCloudRoute)
            ),
        ),
        (
            "ssd_as_ram_rejected",
            matches!(
                reject_witness(|witness| witness.ssd_as_ram_claim = true),
                Err(CachePolicyPollutionError::SsdAsRamClaim)
            ),
        ),
        (
            "mas_product_build_rejected",
            matches!(
                reject_witness(|witness| witness.product_build = ProductBuild::Mas),
                Err(CachePolicyPollutionError::ProductStatusMismatch)
            ),
        ),
        (
            "live_pro_status_rejected",
            matches!(
                reject_witness(|witness| witness.pro_status = ProStatus::Live),
                Err(CachePolicyPollutionError::ProductStatusMismatch)
            ),
        ),
        (
            "live_benchmark_rejected",
            matches!(
                reject_witness(|witness| witness.live_benchmark_attempted = true),
                Err(CachePolicyPollutionError::LiveBenchmarkAttempted)
            ),
        ),
        (
            "runtime_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.runtime_bytes_loaded = 1),
                Err(CachePolicyPollutionError::RuntimeBytesLoaded)
            ),
        ),
        (
            "model_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.model_bytes_loaded = 1),
                Err(CachePolicyPollutionError::ModelBytesLoaded)
            ),
        ),
        (
            "transport_runtime_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.transport_runtime_bytes_loaded = 1),
                Err(CachePolicyPollutionError::TransportRuntimeBytesLoaded)
            ),
        ),
        (
            "no_explicit_policy_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.no_explicit_policy_baseline_bps = 9_700),
                Err(CachePolicyPollutionError::BaselineUnbeaten(
                    "no_explicit_policy"
                ))
            ),
        ),
        (
            "always_cache_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.always_cache_baseline_bps = 9_700),
                Err(CachePolicyPollutionError::BaselineUnbeaten("always_cache"))
            ),
        ),
        (
            "hidden_policy_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_policy_baseline_bps = 9_700),
                Err(CachePolicyPollutionError::BaselineUnbeaten("hidden_policy"))
            ),
        ),
        (
            "live_authority_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.live_authority_baseline_bps = 9_700),
                Err(CachePolicyPollutionError::BaselineUnbeaten(
                    "live_authority"
                ))
            ),
        ),
        (
            "metadata_budget_rejected",
            matches!(
                reject_witness(|witness| witness.max_metadata_bytes = MAX_METADATA_BYTES + 1),
                Err(CachePolicyPollutionError::MetadataBudgetExceeded)
            ),
        ),
    ])
}

fn fixture_witness() -> Result<CachePolicyPollutionWitness, CachePolicyPollutionError> {
    CachePolicyPollutionWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "cache_policy_pollution_gate_only",
        9_520,
        8_250,
        8_120,
        8_340,
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
        fixture_trials()?,
        fixture_surfaces()?,
    )
}

fn fixture_trials() -> Result<Vec<CachePolicyTrial>, CachePolicyPollutionError> {
    Ok(vec![
        trial("no-cache", CachePolicyLane::StreamingNoCache, 120, 430)?,
        trial("hot-reuse", CachePolicyLane::HotReuse, 90, 260)?,
        trial("metadata-only", CachePolicyLane::MetadataOnly, 40, 110)?,
    ])
}

fn trial(
    trial_id: &str,
    lane: CachePolicyLane,
    observed_regression_bps: u32,
    cache_pollution_bps: u32,
) -> Result<CachePolicyTrial, CachePolicyPollutionError> {
    let marker = lane.required_marker();
    CachePolicyTrial::new(
        trial_id,
        "mission:coldstream-cache-policy",
        format!("route:{trial_id}"),
        lane,
        format!("cache_policy:{marker}:{trial_id}"),
        format!("hot_route:{trial_id}:editor-note-loop"),
        format!("repeated_probe:{trial_id}:5x"),
        format!("transport_trace:{trial_id}"),
        format!("transport_cancellation:{trial_id}"),
        format!("answer_packet:{trial_id}"),
        format!("run_event_log:{trial_id}"),
        format!("rollback:{trial_id}"),
        "admission:cache-policy-pollution",
        "scope_rex:cache-policy-pollution",
        "sovereign_gate:cache-policy-pollution",
        "compat:cache-policy-v1",
        65_536,
        9,
        9,
        15,
        16,
        200,
        observed_regression_bps,
        cache_pollution_bps,
        700,
        10_500,
        5,
        30_000,
        true,
        format!("metadata-only cache policy witness for {marker}: repeated probe evidence bounds hot route p95/p99 regression, AnswerPacket and rollback are visible, and this advances L1 only while L2 and L3 stay unchanged."),
        true,
    )
}

fn fixture_surfaces() -> Result<Vec<CachePolicySurface>, CachePolicyPollutionError> {
    Ok(vec![
        CachePolicySurface::new(
            "surface:cache-policy-hot-route",
            "answer_packet:cache-policy-surface-a",
            "run_event_log:cache-policy-surface-a",
            "metadata-only cache policy surface: L1 records hot route repeated probe results, cache policy caveats, AnswerPacket, RunEventLog, and rollback; L2 remains vault research and L3 product runtime is unchanged.",
        )?,
        CachePolicySurface::new(
            "surface:cache-policy-caveat",
            "answer_packet:cache-policy-surface-b",
            "run_event_log:cache-policy-surface-b",
            "metadata-only cache policy caveat: L1 exposes no-cache and hot-reuse decisions, hot route repeated probe evidence, AnswerPacket, and rollback; L2 capability remains red and L3 user-facing runtime is unchanged.",
        )?,
    ])
}

fn reject_witness(
    mutate: impl FnOnce(&mut CachePolicyPollutionWitness),
) -> Result<CachePolicyPollutionWitness, CachePolicyPollutionError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness);
    rebuild_witness(witness)
}

fn reject_trial(
    mutate: impl FnOnce(&mut CachePolicyTrial),
    index: usize,
) -> Result<CachePolicyPollutionWitness, CachePolicyPollutionError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness.trials[index]);
    rebuild_witness(witness)
}

fn reject_surface(
    mutate: impl FnOnce(&mut CachePolicySurface),
) -> Result<CachePolicyPollutionWitness, CachePolicyPollutionError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness.surfaces[0]);
    rebuild_witness(witness)
}

fn rebuild_witness(
    witness: CachePolicyPollutionWitness,
) -> Result<CachePolicyPollutionWitness, CachePolicyPollutionError> {
    CachePolicyPollutionWitness::new(
        witness.product_build,
        witness.pro_status,
        witness.route_authority,
        witness.cache_policy_success_bps,
        witness.no_explicit_policy_baseline_bps,
        witness.always_cache_baseline_bps,
        witness.hidden_policy_baseline_bps,
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
        witness.trials,
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
// UAS: Binds upstream witness refs used to prove cache-policy lineage.
// Plane: Verification.
// Residency: Metadata-only evidence; no runtime/model/transport bytes are loaded.
struct EvidenceSnapshot {
    transport_cancellation_pass: bool,
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, CachePolicyWitnessError> {
        let transport = read_json(TRANSPORT_CANCELLATION_PATH)?;
        let guard = read_json(GUARD_PATH)?;
        let capability = read_json(CAPABILITY_PATH)?;
        Ok(Self {
            transport_cancellation_pass: transport
                .get("overall_pass")
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false)
                && axes_all_present(&transport, TRANSPORT_CANCELLATION_AXES),
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

fn read_json(path: &str) -> Result<serde_json::Value, CachePolicyWitnessError> {
    let resolved = resolve_repo_path(path);
    let text = std::fs::read_to_string(&resolved)
        .map_err(|error| CachePolicyWitnessError::Io(format!("{path}: {error}")))?;
    serde_json::from_str(&text)
        .map_err(|error| CachePolicyWitnessError::Io(format!("{path}: {error}")))
}

fn resolve_repo_path(path: &str) -> PathBuf {
    let direct = PathBuf::from(path);
    if direct.exists() {
        return direct;
    }
    let mut current = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
    loop {
        let candidate = current.join(path);
        if candidate.exists() {
            return candidate;
        }
        if !current.pop() {
            break;
        }
    }
    direct
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fixture_artifact_passes_all_cache_policy_axes() {
        let artifact = build_artifact().expect("artifact");
        assert!(artifact.overall_pass);
        for axis in CACHE_POLICY_POLLUTION_AXES {
            assert_eq!(
                artifact.pass_per_axis.get(*axis),
                Some(&true),
                "axis {axis} should pass"
            );
        }
    }
}
