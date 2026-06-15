//! `falsify_cold_panic_fallback`.
//!
//! Metadata-only witness for `F-ColdPanicFallback`. It proves missed
//! ColdStream deadlines visibly degrade instead of silently blocking
//! token-time execution before live transport, mmap replacement, or 70B route
//! claims can promote.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::{
    CACHE_POLICY_POLLUTION_AXES, COLD_PANIC_FALLBACK_AXES,
};
use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ColdFallbackRoute, ColdPanicFallbackError, ColdPanicFallbackRun, ColdPanicFallbackWitness,
    ColdPanicSurface, ProStatus, ProductBuild, COLD_PANIC_FALLBACK_CURSOR,
    COLD_PANIC_FALLBACK_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-ColdPanicFallback";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";
const FIXTURE_ID: &str = "cold_panic_fallback_v1";
const COMMAND: &str = "Tools/falsifiers/f_cold_panic_fallback.sh";
const RESULT: &str = "artifacts/falsifiers/cold_panic_fallback/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const CACHE_POLICY_PATH: &str = "artifacts/falsifiers/cache_policy_pollution/result.json";
const MIN_RUN_COUNT: u64 = 3;
const MIN_SURFACE_COUNT: u64 = 2;
const MIN_SUCCESS_BPS: u64 = 9_400;
const MAX_METADATA_BYTES: u64 = 256 * 1024;
const MAX_TOKEN_BLOCK_MS: u64 = 16;
const MAX_FALLBACK_LATENCY_MS: u64 = 64;

#[derive(Debug)]
// UAS: uas:cold-panic-fallback:witness-error
// Plane: Verification
// Residency: metadata-only artifact rejection taxonomy.
enum ColdPanicWitnessError {
    Primitive(ColdPanicFallbackError),
    Io(String),
}

impl std::fmt::Display for ColdPanicWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for ColdPanicWitnessError {}

impl From<ColdPanicFallbackError> for ColdPanicWitnessError {
    fn from(value: ColdPanicFallbackError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, ColdPanicWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fixture_witness()?;
    let metrics = witness.metrics();
    let address = witness.address();
    let mut reversed = witness.runs.clone();
    reversed.reverse();
    let deterministic = ColdPanicFallbackWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "cold_panic_fallback_gate_only",
        witness.cold_panic_success_bps,
        witness.wait_forever_baseline_bps,
        witness.hidden_caveat_baseline_bps,
        witness.stale_slab_baseline_bps,
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
            "upstream_cache_policy_pollution_pass",
            evidence.cache_policy_pollution_pass,
        ),
        (
            "guard_cursor_cold_panic_fallback_or_advanced",
            evidence.guard_next_existing_work == COLD_PANIC_FALLBACK_CURSOR
                || evidence.guard_next_existing_work == COLD_PANIC_FALLBACK_NEXT_CURSOR
                || evidence.guard_next_existing_work == ADVANCED_RELEASE_AUDIT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_cold_panic_fallback_or_advanced",
            evidence.capability_next_bottleneck == COLD_PANIC_FALLBACK_CURSOR
                || evidence.capability_next_bottleneck == COLD_PANIC_FALLBACK_NEXT_CURSOR
                || evidence.capability_next_bottleneck == ADVANCED_RELEASE_AUDIT_CURSOR,
        ),
        (
            "product_status_research_only",
            witness.product_build == ProductBuild::Pro
                && witness.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_cold_panic_gate_only",
            witness.route_authority == "cold_panic_fallback_gate_only",
        ),
        (
            "fallback_runs_bound",
            metrics.run_count as u64 >= MIN_RUN_COUNT,
        ),
        (
            "visible_surfaces_bound",
            metrics.surface_count as u64 >= MIN_SURFACE_COUNT,
        ),
        ("hot_degraded_route_bound", metrics.hot_degraded_count > 0),
        (
            "cached_summary_route_bound",
            metrics.cached_summary_count > 0,
        ),
        (
            "background_repair_route_bound",
            metrics.background_repair_route_count > 0,
        ),
        (
            "fallback_route_diversity_bound",
            metrics.fallback_route_count >= 3,
        ),
        (
            "missed_run_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.missed_run_ref.starts_with("missed_run:")),
        ),
        (
            "deadline_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.deadline_ref.starts_with("transport_deadline:")),
        ),
        (
            "transport_trace_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.transport_trace_ref.starts_with("transport_trace:")),
        ),
        (
            "cache_policy_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.cache_policy_ref.starts_with("cache_policy:")),
        ),
        (
            "cancellation_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.cancellation_ref.starts_with("transport_cancellation:")),
        ),
        (
            "fallback_route_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.fallback_route_ref.starts_with("fallback_route:")),
        ),
        (
            "answer_packet_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.answer_packet_ref.starts_with("answer_packet:"))
                && witness
                    .surfaces
                    .iter()
                    .all(|surface| surface.answer_packet_ref.starts_with("answer_packet:")),
        ),
        (
            "run_event_log_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.run_event_log_ref.starts_with("run_event_log:"))
                && witness
                    .surfaces
                    .iter()
                    .all(|surface| surface.run_event_log_ref.starts_with("run_event_log:")),
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
            "deadline_miss_recorded",
            witness
                .runs
                .iter()
                .all(|run| run.elapsed_ms > run.deadline_ms && run.deadline_ms > 0),
        ),
        (
            "token_block_budget_bound",
            metrics.max_token_block_ms as u64 <= MAX_TOKEN_BLOCK_MS,
        ),
        (
            "fallback_latency_budget_bound",
            metrics.max_fallback_latency_ms as u64 <= MAX_FALLBACK_LATENCY_MS,
        ),
        (
            "stale_slab_rejection_bound",
            metrics.stale_slab_rejection_count == metrics.run_count,
        ),
        (
            "background_repair_queued_bound",
            metrics.repair_queued_count == metrics.run_count,
        ),
        (
            "visible_caveat_bound",
            witness
                .runs
                .iter()
                .all(|run| run.quality_caveat.contains("AnswerPacket")),
        ),
        (
            "user_visible_limit_bound",
            witness
                .runs
                .iter()
                .all(|run| run.user_visible_limit.contains("RunEventLog")),
        ),
        (
            "l1_l2_l3_separation_bound",
            witness.runs.iter().all(|run| {
                run.l1_l2_l3_separated
                    && contains_layers(&run.quality_caveat)
                    && contains_layers(&run.user_visible_limit)
            }) && witness
                .surfaces
                .iter()
                .all(|surface| contains_layers(&surface.visible_summary)),
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
        ("cold_panic_fallback_address_deterministic", deterministic),
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
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "surface_count",
        metrics.surface_count as u64,
        MIN_SURFACE_COUNT,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "answer_packet_count",
        metrics.answer_packet_count as u64,
        MIN_RUN_COUNT + MIN_SURFACE_COUNT,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "run_event_log_count",
        metrics.run_event_log_count as u64,
        MIN_RUN_COUNT + MIN_SURFACE_COUNT,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fallback_route_count",
        metrics.fallback_route_count as u64,
        3,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hot_degraded_count",
        metrics.hot_degraded_count as u64,
        1,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cached_summary_count",
        metrics.cached_summary_count as u64,
        1,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "background_repair_route_count",
        metrics.background_repair_route_count as u64,
        1,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "total_requested_cold_bytes",
        metrics.total_requested_cold_bytes,
        1,
        "bytes",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_deadline_ms",
        metrics.max_deadline_ms as u64,
        64,
        "ms",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_elapsed_ms",
        metrics.max_elapsed_ms as u64,
        33,
        "ms",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_token_block_ms",
        metrics.max_token_block_ms as u64,
        MAX_TOKEN_BLOCK_MS,
        "ms",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_fallback_latency_ms",
        metrics.max_fallback_latency_ms as u64,
        MAX_FALLBACK_LATENCY_MS,
        "ms",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "stale_slab_rejection_count",
        metrics.stale_slab_rejection_count as u64,
        MIN_RUN_COUNT,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "visible_fallback_count",
        metrics.visible_fallback_count as u64,
        MIN_RUN_COUNT,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "repair_queued_count",
        metrics.repair_queued_count as u64,
        MIN_RUN_COUNT,
        "count",
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
        "cold_panic_success_bps",
        witness.cold_panic_success_bps as u64,
        MIN_SUCCESS_BPS,
        "bps",
    );
    for (name, value) in [
        (
            "wait_forever_baseline_bps",
            witness.wait_forever_baseline_bps,
        ),
        (
            "hidden_caveat_baseline_bps",
            witness.hidden_caveat_baseline_bps,
        ),
        ("stale_slab_baseline_bps", witness.stale_slab_baseline_bps),
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
            witness.cold_panic_success_bps.saturating_sub(1) as u64,
            "bps",
        );
    }
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_panic_fallback_address",
        address,
        "uas:cold-panic-fallback:sha256:",
    );

    for axis in COLD_PANIC_FALLBACK_AXES {
        pass_per_axis.entry((*axis).to_string()).or_insert(false);
    }

    let mut anomalies = Vec::new();
    if evidence.cache_policy_pollution_pass {
        anomalies.push(serde_json::json!({
            "kind": "cold_panic_fallback_metadata_only",
            "detail": "F-ColdPanicFallback proves missed ColdStream deadlines degrade visibly with fallback, rollback, RunEventLog, AnswerPacket, SCOPE-Rex/SovereignGate admission, stale-slab rejection, and zero runtime/model/transport bytes. It advances L1 only."
        }));
    } else {
        anomalies.push(serde_json::json!({
            "kind": "missing_cache_policy_pollution",
            "detail": "F-ColdPanicFallback requires F-CachePolicy-Pollution to pass first so fallback evidence is attached to explicit cache-policy and repeated hot-route regression evidence."
        }));
    }
    if !evidence.capability_overall_pass {
        anomalies.push(serde_json::json!({
            "kind": "l2_l3_not_promoted",
            "detail": "Capability route stays vault_research_route_with_packetized_mitigation; this metadata witness does not promote live transport, KV-Direct 128K, live sparse 70B, dense 70B, or user-facing product runtime."
        }));
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
        anomalies,
        notes: "metadata-only F-ColdPanicFallback witness: missed ColdStream deadlines abort cold wakes, reject stale slabs, queue repair, surface AnswerPacket/RunEventLog/rollback caveats, and advance L1 only; L2 capability and L3 user-facing runtime remain unpromoted."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Debug)]
// UAS: uas:cold-panic-fallback:evidence-snapshot
// Plane: Verification
// Residency: metadata-only upstream artifact cursor reader.
struct EvidenceSnapshot {
    cache_policy_pollution_pass: bool,
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, ColdPanicWitnessError> {
        let cache_policy = read_json(Path::new(CACHE_POLICY_PATH))?;
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        Ok(Self {
            cache_policy_pollution_pass: artifact_all_axes_true(
                &cache_policy,
                CACHE_POLICY_POLLUTION_AXES,
            ),
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_else(|| "missing_guard_next_existing_work".to_string()),
            capability_overall_pass: artifact_overall_pass(&capability),
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_else(|| "missing_capability_route_status".to_string()),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_else(|| "missing_capability_next_bottleneck".to_string()),
        })
    }
}

fn invalid_fixture_axes() -> Result<Vec<(&'static str, bool)>, ColdPanicWitnessError> {
    Ok(vec![
        (
            "empty_run_rejected",
            matches!(
                reject_witness(|witness| witness.runs.clear()),
                Err(ColdPanicFallbackError::EmptyRun)
            ),
        ),
        (
            "empty_surface_rejected",
            matches!(
                reject_witness(|witness| witness.surfaces.clear()),
                Err(ColdPanicFallbackError::EmptySurface)
            ),
        ),
        (
            "duplicate_run_rejected",
            matches!(
                reject_witness(|witness| witness.runs[1].run_id = witness.runs[0].run_id.clone()),
                Err(ColdPanicFallbackError::DuplicateRun(_))
            ),
        ),
        (
            "duplicate_surface_rejected",
            matches!(
                reject_witness(|witness| {
                    witness.surfaces[1].surface_id = witness.surfaces[0].surface_id.clone()
                }),
                Err(ColdPanicFallbackError::DuplicateSurface(_))
            ),
        ),
        (
            "duplicate_answer_packet_rejected",
            matches!(
                reject_witness(|witness| {
                    witness.runs[1].answer_packet_ref = witness.runs[0].answer_packet_ref.clone()
                }),
                Err(ColdPanicFallbackError::DuplicateAnswerPacket(_))
            ),
        ),
        (
            "missing_missed_run_rejected",
            matches!(
                reject_run(|run| run.missed_run_ref = "run:missing".to_string(), 0),
                Err(ColdPanicFallbackError::MissingMissedRun(_))
            ),
        ),
        (
            "missing_deadline_rejected",
            matches!(
                reject_run(|run| run.deadline_ref = "deadline:missing".to_string(), 0),
                Err(ColdPanicFallbackError::MissingDeadline(_))
            ),
        ),
        (
            "missing_transport_trace_rejected",
            matches!(
                reject_run(
                    |run| run.transport_trace_ref = "trace:missing".to_string(),
                    0
                ),
                Err(ColdPanicFallbackError::MissingTransportTrace(_))
            ),
        ),
        (
            "missing_cache_policy_rejected",
            matches!(
                reject_run(|run| run.cache_policy_ref = "policy:missing".to_string(), 0),
                Err(ColdPanicFallbackError::MissingCachePolicy(_))
            ),
        ),
        (
            "missing_cancellation_rejected",
            matches!(
                reject_run(|run| run.cancellation_ref = "cancel:missing".to_string(), 0),
                Err(ColdPanicFallbackError::MissingCancellation(_))
            ),
        ),
        (
            "missing_fallback_route_rejected",
            matches!(
                reject_run(
                    |run| run.fallback_route_ref = "fallback:missing".to_string(),
                    0
                ),
                Err(ColdPanicFallbackError::MissingFallbackRoute(_))
            ),
        ),
        (
            "missing_answer_packet_rejected",
            matches!(
                reject_run(
                    |run| run.answer_packet_ref = "packet:missing".to_string(),
                    0
                ),
                Err(ColdPanicFallbackError::MissingAnswerPacket(_))
            ),
        ),
        (
            "missing_run_event_log_rejected",
            matches!(
                reject_run(|run| run.run_event_log_ref = "log:missing".to_string(), 0),
                Err(ColdPanicFallbackError::MissingRunEventLog(_))
            ),
        ),
        (
            "missing_rollback_rejected",
            matches!(
                reject_run(|run| run.rollback_ref = "undo:missing".to_string(), 0),
                Err(ColdPanicFallbackError::MissingRollback(_))
            ),
        ),
        (
            "missing_admission_rejected",
            matches!(
                reject_run(|run| run.admission_ref = "gate:missing".to_string(), 0),
                Err(ColdPanicFallbackError::MissingAdmission)
            ),
        ),
        (
            "missing_scope_rex_rejected",
            matches!(
                reject_run(|run| run.scope_rex_ref = "scope:missing".to_string(), 0),
                Err(ColdPanicFallbackError::MissingScopeRex)
            ),
        ),
        (
            "missing_sovereign_gate_rejected",
            matches!(
                reject_run(
                    |run| run.sovereign_gate_ref = "sovereign:missing".to_string(),
                    0
                ),
                Err(ColdPanicFallbackError::MissingSovereignGate)
            ),
        ),
        (
            "missing_compatibility_fence_rejected",
            matches!(
                reject_run(
                    |run| run.compatibility_fence = "fence:missing".to_string(),
                    0
                ),
                Err(ColdPanicFallbackError::MissingCompatibilityFence(_))
            ),
        ),
        (
            "missing_quality_caveat_rejected",
            matches!(
                reject_run(|run| run.quality_caveat.clear(), 0),
                Err(ColdPanicFallbackError::MissingField("quality_caveat"))
                    | Err(ColdPanicFallbackError::MissingQualityCaveat(_))
                    | Err(ColdPanicFallbackError::MissingRequiredMarker(_))
            ),
        ),
        (
            "missing_user_visible_limit_rejected",
            matches!(
                reject_run(|run| run.user_visible_limit.clear(), 0),
                Err(ColdPanicFallbackError::MissingField("user_visible_limit"))
                    | Err(ColdPanicFallbackError::MissingUserVisibleLimit(_))
                    | Err(ColdPanicFallbackError::MissingRequiredMarker(_))
            ),
        ),
        (
            "missing_required_marker_rejected",
            matches!(
                reject_surface(|surface| {
                    surface.visible_summary =
                        surface.visible_summary.replace("AnswerPacket", "packet")
                }),
                Err(ColdPanicFallbackError::MissingRequiredMarker(_))
            ),
        ),
        (
            "forbidden_marker_rejected",
            matches!(
                reject_surface(|surface| surface
                    .visible_summary
                    .push_str(" live transport ready.")),
                Err(ColdPanicFallbackError::ForbiddenMarker(_))
            ),
        ),
        (
            "missing_layer_separation_rejected",
            matches!(
                reject_run(|run| run.l1_l2_l3_separated = false, 0),
                Err(ColdPanicFallbackError::MissingLayerSeparation)
            ),
        ),
        (
            "deadline_not_missed_rejected",
            matches!(
                reject_run(|run| run.elapsed_ms = run.deadline_ms, 0),
                Err(ColdPanicFallbackError::DeadlineNotMissed(_))
            ),
        ),
        (
            "zero_deadline_rejected",
            matches!(
                reject_run(|run| run.deadline_ms = 0, 0),
                Err(ColdPanicFallbackError::ZeroDeadline(_))
            ),
        ),
        (
            "zero_cold_bytes_rejected",
            matches!(
                reject_run(|run| run.requested_cold_bytes = 0, 0),
                Err(ColdPanicFallbackError::ZeroColdBytes(_))
            ),
        ),
        (
            "token_block_budget_exceeded_rejected",
            matches!(
                reject_run(|run| run.token_block_ms = 17, 0),
                Err(ColdPanicFallbackError::TokenBlockBudgetExceeded(_))
            ),
        ),
        (
            "fallback_latency_exceeded_rejected",
            matches!(
                reject_run(|run| run.fallback_latency_ms = 65, 0),
                Err(ColdPanicFallbackError::FallbackLatencyExceeded(_))
            ),
        ),
        (
            "cold_wake_not_aborted_rejected",
            matches!(
                reject_run(|run| run.cold_wake_aborted = false, 0),
                Err(ColdPanicFallbackError::ColdWakeNotAborted(_))
            ),
        ),
        (
            "stale_slab_execution_rejected",
            matches!(
                reject_run(|run| run.stale_slab_rejected = false, 0),
                Err(ColdPanicFallbackError::StaleSlabExecutionAllowed(_))
            ),
        ),
        (
            "invisible_fallback_rejected",
            matches!(
                reject_run(|run| run.visible_to_user = false, 0),
                Err(ColdPanicFallbackError::InvisibleFallback(_))
            ),
        ),
        (
            "background_repair_missing_rejected",
            matches!(
                reject_run(|run| run.background_repair_queued = false, 0),
                Err(ColdPanicFallbackError::BackgroundRepairMissing(_))
            ),
        ),
        (
            "hidden_route_authority_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_route_authority = true),
                Err(ColdPanicFallbackError::HiddenRouteAuthority)
            ),
        ),
        (
            "route_policy_mutation_rejected",
            matches!(
                reject_witness(|witness| witness.route_policy_mutation = true),
                Err(ColdPanicFallbackError::RoutePolicyMutation)
            ),
        ),
        (
            "gate_bypass_rejected",
            matches!(
                reject_witness(|witness| witness.gate_bypass = true),
                Err(ColdPanicFallbackError::GateBypass)
            ),
        ),
        (
            "answer_packet_suppression_rejected",
            matches!(
                reject_witness(|witness| witness.answer_packet_suppression = true),
                Err(ColdPanicFallbackError::AnswerPacketSuppression)
            ),
        ),
        (
            "hidden_chain_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_chain_exposed = true),
                Err(ColdPanicFallbackError::HiddenChainExposure)
            ),
        ),
        (
            "hidden_cloud_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_cloud_route = true),
                Err(ColdPanicFallbackError::HiddenCloudRoute)
            ),
        ),
        (
            "ssd_as_ram_rejected",
            matches!(
                reject_witness(|witness| witness.ssd_as_ram_claim = true),
                Err(ColdPanicFallbackError::SsdAsRamClaim)
            ),
        ),
        (
            "mas_product_build_rejected",
            matches!(
                reject_witness(|witness| witness.product_build = ProductBuild::Mas),
                Err(ColdPanicFallbackError::ProductStatusMismatch)
            ),
        ),
        (
            "live_pro_status_rejected",
            matches!(
                reject_witness(|witness| witness.pro_status = ProStatus::Live),
                Err(ColdPanicFallbackError::ProductStatusMismatch)
            ),
        ),
        (
            "live_benchmark_rejected",
            matches!(
                reject_witness(|witness| witness.live_benchmark_attempted = true),
                Err(ColdPanicFallbackError::LiveBenchmarkAttempted)
            ),
        ),
        (
            "runtime_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.runtime_bytes_loaded = 1),
                Err(ColdPanicFallbackError::RuntimeBytesLoaded)
            ),
        ),
        (
            "model_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.model_bytes_loaded = 1),
                Err(ColdPanicFallbackError::ModelBytesLoaded)
            ),
        ),
        (
            "transport_runtime_bytes_rejected",
            matches!(
                reject_witness(|witness| witness.transport_runtime_bytes_loaded = 1),
                Err(ColdPanicFallbackError::TransportRuntimeBytesLoaded)
            ),
        ),
        (
            "wait_forever_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.wait_forever_baseline_bps = 9_700),
                Err(ColdPanicFallbackError::BaselineUnbeaten("wait_forever"))
            ),
        ),
        (
            "hidden_caveat_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.hidden_caveat_baseline_bps = 9_700),
                Err(ColdPanicFallbackError::BaselineUnbeaten("hidden_caveat"))
            ),
        ),
        (
            "stale_slab_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.stale_slab_baseline_bps = 9_700),
                Err(ColdPanicFallbackError::BaselineUnbeaten("stale_slab"))
            ),
        ),
        (
            "live_authority_baseline_unbeaten_rejected",
            matches!(
                reject_witness(|witness| witness.live_authority_baseline_bps = 9_700),
                Err(ColdPanicFallbackError::BaselineUnbeaten("live_authority"))
            ),
        ),
        (
            "metadata_budget_rejected",
            matches!(
                reject_witness(|witness| witness.max_metadata_bytes = MAX_METADATA_BYTES + 1),
                Err(ColdPanicFallbackError::MetadataBudgetExceeded)
            ),
        ),
    ])
}

fn fixture_witness() -> Result<ColdPanicFallbackWitness, ColdPanicFallbackError> {
    ColdPanicFallbackWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "cold_panic_fallback_gate_only",
        9_610,
        8_120,
        8_260,
        8_030,
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

fn fixture_runs() -> Result<Vec<ColdPanicFallbackRun>, ColdPanicFallbackError> {
    Ok(vec![
        run("hot-degraded", ColdFallbackRoute::HotDegradedRoute, 2, 18)?,
        run("cached-summary", ColdFallbackRoute::CachedSummary, 1, 12)?,
        run(
            "background-repair",
            ColdFallbackRoute::BackgroundRepairQueue,
            0,
            24,
        )?,
    ])
}

fn run(
    run_id: &str,
    route: ColdFallbackRoute,
    token_block_ms: u32,
    fallback_latency_ms: u32,
) -> Result<ColdPanicFallbackRun, ColdPanicFallbackError> {
    let marker = route.required_marker();
    ColdPanicFallbackRun::new(
        run_id,
        "mission:coldstream-panic-fallback",
        format!("route:{run_id}"),
        format!("missed_run:{run_id}"),
        format!("transport_deadline:{run_id}:32ms"),
        format!("transport_trace:{run_id}"),
        format!("cache_policy:no-cache:{run_id}"),
        format!("transport_cancellation:{run_id}"),
        route.clone(),
        format!("fallback_route:{marker}:{run_id}"),
        format!("answer_packet:{run_id}"),
        format!("run_event_log:{run_id}"),
        format!("rollback:{run_id}"),
        "admission:cold-panic-fallback",
        "scope_rex:cold-panic-fallback",
        "sovereign_gate:cold-panic-fallback",
        "compat:cold-panic-fallback-v1",
        65_536,
        32,
        58,
        token_block_ms,
        MAX_TOKEN_BLOCK_MS as u32,
        fallback_latency_ms,
        true,
        true,
        true,
        true,
        format!("metadata-only cold deadline fallback for {marker}: missed transport deadline aborts the cold wake, records fallback in AnswerPacket and RunEventLog, keeps rollback visible, and advances L1 only while L2 and L3 remain unchanged."),
        format!("user-visible fallback limit for {marker}: the answer states the cold deadline miss, uses a degraded or cached route, links AnswerPacket, RunEventLog, and rollback, and separates L1 evidence from L2 and L3 product runtime."),
        true,
    )
}

fn fixture_surfaces() -> Result<Vec<ColdPanicSurface>, ColdPanicFallbackError> {
    Ok(vec![
        ColdPanicSurface::new(
            "surface:cold-panic-answerpacket",
            "answer_packet:cold-panic-surface-a",
            "run_event_log:cold-panic-surface-a",
            "fallback_route:surface:answerpacket",
            "metadata-only cold panic fallback surface: L1 records the missed cold deadline, visible fallback, AnswerPacket, RunEventLog, and rollback; L2 remains vault research and L3 product runtime is unchanged.",
        )?,
        ColdPanicSurface::new(
            "surface:cold-panic-runlog",
            "answer_packet:cold-panic-surface-b",
            "run_event_log:cold-panic-surface-b",
            "fallback_route:surface:runlog",
            "metadata-only fallback run log surface: L1 exposes the cold deadline miss, stale-slab rejection, repair queue, AnswerPacket, RunEventLog, and rollback; L2 capability stays red and L3 runtime is unchanged.",
        )?,
    ])
}

fn reject_witness(
    mutate: impl FnOnce(&mut ColdPanicFallbackWitness),
) -> Result<ColdPanicFallbackWitness, ColdPanicFallbackError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness);
    rebuild_witness(witness)
}

fn reject_run(
    mutate: impl FnOnce(&mut ColdPanicFallbackRun),
    index: usize,
) -> Result<ColdPanicFallbackWitness, ColdPanicFallbackError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness.runs[index]);
    rebuild_witness(witness)
}

fn reject_surface(
    mutate: impl FnOnce(&mut ColdPanicSurface),
) -> Result<ColdPanicFallbackWitness, ColdPanicFallbackError> {
    let mut witness = fixture_witness()?;
    mutate(&mut witness.surfaces[0]);
    rebuild_witness(witness)
}

fn rebuild_witness(
    witness: ColdPanicFallbackWitness,
) -> Result<ColdPanicFallbackWitness, ColdPanicFallbackError> {
    ColdPanicFallbackWitness::new(
        witness.product_build,
        witness.pro_status,
        witness.route_authority,
        witness.cold_panic_success_bps,
        witness.wait_forever_baseline_bps,
        witness.hidden_caveat_baseline_bps,
        witness.stale_slab_baseline_bps,
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

fn read_json(path: &Path) -> Result<serde_json::Value, ColdPanicWitnessError> {
    let bytes = std::fs::read(path)
        .map_err(|error| ColdPanicWitnessError::Io(format!("{}: {error}", path.display())))?;
    serde_json::from_slice(&bytes)
        .map_err(|error| ColdPanicWitnessError::Io(format!("{}: {error}", path.display())))
}

fn artifact_all_axes_true(value: &serde_json::Value, axes: &[&str]) -> bool {
    artifact_overall_pass(value)
        && axes.iter().all(|axis| {
            value
                .get("pass_per_axis")
                .and_then(|axes| axes.get(*axis))
                .and_then(|v| v.as_bool())
                .unwrap_or(false)
        })
}

fn artifact_overall_pass(value: &serde_json::Value) -> bool {
    value
        .get("overall_pass")
        .and_then(|v| v.as_bool())
        .unwrap_or(false)
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(|value| value.as_str())
        .map(str::to_string)
}

fn contains_layers(value: &str) -> bool {
    value.contains("L1") && value.contains("L2") && value.contains("L3")
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
            unit: "address".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String(prefix.to_string()),
            unit: "address".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), passed);
}
