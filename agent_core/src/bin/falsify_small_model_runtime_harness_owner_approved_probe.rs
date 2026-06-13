//! `falsify_small_model_runtime_harness_owner_approved_probe`.
//!
//! Metadata-only witness for `F-SmallModelRuntimeHarnessOwnerApprovedProbe`.
//! It proves the first small local-model runtime smoke probe is owner-approved,
//! dry-run-bound, serialized, cancellable, rollback-backed, RunEventLog and
//! AnswerPacket visible, and budgeted while still executing no MLX runtime and
//! loading zero model/runtime/transport bytes.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, SmallModelOwnerProbeLease, SmallModelOwnerProbePhase,
    SmallModelOwnerProbeSurface, SmallModelRuntimeHarnessOwnerProbeError,
    SmallModelRuntimeHarnessOwnerProbeWitness,
    SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallModelRuntimeHarnessOwnerApprovedProbe";
const FIXTURE_ID: &str = "small_model_runtime_harness_owner_approved_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_small_model_runtime_harness_owner_approved_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_owner_approved_probe/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const DRY_RUN_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_dry_run_witness/result.json";
const LIVING_INDEX_PATH: &str = "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md";
const LATTICE_HTML_PATH: &str = "artifacts/lattice-coordinate-explainer/index.html";
const MIN_LEASE_COUNT: u64 = 3;
const MIN_SURFACE_COUNT: u64 = 2;
const MIN_REQUIRED_LANE_COUNT: u64 = 3;
const MIN_PHASE_COUNT: u64 = 13;
const MAX_CONTEXT_TOKENS: u64 = 40_960;
const MAX_PROMPT_TOKENS: u64 = 8_192;
const MAX_DECODE_TOKENS: u64 = 512;
const MAX_MEMORY_BUDGET_BYTES: u64 = 8 * 1024 * 1024 * 1024;
const MAX_RUNTIME_SECONDS: u64 = 300;
const MAX_METADATA_BYTES: u64 = 384 * 1024;

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-owner-probe:witness-error
// Plane: Verification
// Residency: metadata-only owner-probe rejection taxonomy.
enum OwnerProbeWitnessError {
    Primitive(SmallModelRuntimeHarnessOwnerProbeError),
    Io(String),
}

impl std::fmt::Display for OwnerProbeWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for OwnerProbeWitnessError {}

impl From<SmallModelRuntimeHarnessOwnerProbeError> for OwnerProbeWitnessError {
    fn from(value: SmallModelRuntimeHarnessOwnerProbeError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, OwnerProbeWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fixture_witness(&evidence)?;
    let metrics = witness.metrics();
    let address = witness.address();
    let mut reversed = witness.leases.clone();
    reversed.reverse();
    let deterministic = SmallModelRuntimeHarnessOwnerProbeWitness::new(
        witness.witness_id.clone(),
        witness.dry_run_artifact_ref.clone(),
        witness.guard_next_existing_work.clone(),
        witness.capability_route_status.clone(),
        witness.capability_next_bottleneck.clone(),
        witness.product_build.clone(),
        witness.pro_status.clone(),
        witness.route_authority.clone(),
        reversed,
        witness.surfaces.clone(),
        witness.metadata_bytes,
        witness.l1_l2_l3_separated,
        witness.mas_overclaim_attempted,
        witness.l2_green_claimed,
        witness.l3_green_claimed,
    )?
    .address()
        == address;
    let invalid_axes = invalid_fixture_axes(&evidence)?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_small_model_runtime_harness_dry_run_witness_pass",
            evidence.dry_run_pass,
        ),
        (
            "guard_cursor_owner_probe_or_advanced",
            evidence.guard_next_existing_work
                == SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_owner_probe_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_NEXT_CURSOR,
        ),
        (
            "product_status_research_only",
            witness.product_build == ProductBuild::Pro
                && witness.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_owner_approval_only",
            witness.route_authority == "small_model_runtime_harness_owner_approval_only",
        ),
        (
            "living_index_surface_scan_pass",
            witness.surfaces.iter().any(|surface| {
                surface.surface_id == "living_index"
                    && surface
                        .observed_text
                        .contains(SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR)
                    && surface
                        .observed_text
                        .contains("vault_research_route_with_packetized_mitigation")
            }),
        ),
        (
            "lattice_html_surface_scan_pass",
            witness.surfaces.iter().any(|surface| {
                surface.surface_id == "lattice_html"
                    && surface
                        .observed_text
                        .contains(SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR)
                    && surface
                        .observed_text
                        .contains("vault_research_route_with_packetized_mitigation")
            }),
        ),
        (
            "north_star_present",
            witness.surfaces.iter().all(|surface| {
                surface
                    .observed_text
                    .contains("Epistemos is a local cognitive substrate")
                    && surface
                        .observed_text
                        .contains("no claim promotes without visible proof")
            }),
        ),
        (
            "forbidden_runtime_claims_absent",
            witness.surfaces.iter().all(|surface| {
                surface
                    .forbidden_markers
                    .iter()
                    .all(|marker| !surface.observed_text.contains(marker))
            }),
        ),
        (
            "dry_run_artifact_ref_bound",
            witness
                .dry_run_artifact_ref
                .starts_with("artifact:small_model_runtime_harness_dry_run_witness:"),
        ),
        (
            "owner_approval_refs_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.owner_approval_ref.starts_with("owner_approval:")),
        ),
        (
            "model_catalog_refs_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.model_catalog_ref.starts_with("model_catalog:")),
        ),
        (
            "model_snapshot_refs_bound",
            witness.leases.iter().all(|lease| {
                lease
                    .model_snapshot_ref
                    .starts_with("model_snapshot:local:")
            }),
        ),
        (
            "prompt_envelope_refs_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.prompt_envelope_ref.starts_with("prompt_envelope:")),
        ),
        (
            "serialized_executor_bound",
            witness.leases.iter().all(|lease| {
                lease
                    .serialized_executor_ref
                    .starts_with("serialized_executor:")
            }),
        ),
        (
            "cancellation_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.cancellation_ref.starts_with("cancel:")),
        ),
        (
            "rollback_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.rollback_ref.starts_with("rollback:")),
        ),
        (
            "run_event_log_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "answer_packet_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.answer_packet_ref.starts_with("answer_packet:")),
        ),
        (
            "admission_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.admission_ref.starts_with("admission:")),
        ),
        (
            "scope_rex_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.scope_rex_ref.starts_with("scope_rex:")),
        ),
        (
            "sovereign_gate_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.sovereign_gate_ref.starts_with("sovereign_gate:")),
        ),
        (
            "compatibility_fence_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.compatibility_fence.starts_with("compat:")),
        ),
        (
            "privacy_fence_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.privacy_ref.starts_with("privacy:")),
        ),
        (
            "budget_refs_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.budget_ref.starts_with("budget:")),
        ),
        (
            "required_lanes_bound",
            metrics.required_lane_count >= MIN_REQUIRED_LANE_COUNT,
        ),
        (
            "required_phases_bound",
            metrics.phase_count >= MIN_PHASE_COUNT,
        ),
        (
            "approval_bound_to_dry_run",
            witness
                .leases
                .iter()
                .all(|lease| lease.approval_bound_to_dry_run),
        ),
        (
            "runtime_probe_armed",
            metrics.runtime_probe_armed_count == metrics.lease_count,
        ),
        (
            "runtime_execution_deferred",
            metrics.runtime_probe_executed_count == 0,
        ),
        ("l1_l2_l3_separation_bound", witness.l1_l2_l3_separated),
        (
            "mas_floor_preserved",
            witness.product_build == ProductBuild::Pro && !witness.mas_overclaim_attempted,
        ),
        ("no_l2_green_claim", !witness.l2_green_claimed),
        ("no_l3_green_claim", !witness.l3_green_claimed),
        (
            "no_hidden_route_authority",
            witness
                .leases
                .iter()
                .all(|lease| !lease.hidden_route_authority),
        ),
        (
            "no_route_policy_mutation",
            witness
                .leases
                .iter()
                .all(|lease| !lease.route_policy_mutated),
        ),
        (
            "no_gate_bypass",
            witness.leases.iter().all(|lease| !lease.gate_bypass),
        ),
        (
            "no_answer_packet_suppression",
            witness
                .leases
                .iter()
                .all(|lease| !lease.answer_packet_suppressed),
        ),
        (
            "no_hidden_chain",
            witness
                .leases
                .iter()
                .all(|lease| !lease.hidden_chain_exposed),
        ),
        (
            "no_hidden_cloud_fallback",
            witness
                .leases
                .iter()
                .all(|lease| !lease.hidden_cloud_fallback),
        ),
        (
            "no_subprocess_spawn",
            witness.leases.iter().all(|lease| !lease.subprocess_spawned),
        ),
        (
            "no_autogenous_kernel_attempt",
            witness
                .leases
                .iter()
                .all(|lease| !lease.autogenous_kernel_attempted),
        ),
        (
            "no_70b_probe_attempt",
            witness
                .leases
                .iter()
                .all(|lease| !lease.seventy_b_probe_attempted),
        ),
        (
            "no_mutation_committed",
            metrics.mutation_committed_count == 0,
        ),
        ("no_runtime_bytes_loaded", metrics.runtime_bytes_loaded == 0),
        ("no_model_bytes_loaded", metrics.model_bytes_loaded == 0),
        (
            "no_transport_runtime_bytes_loaded",
            metrics.transport_runtime_bytes_loaded == 0,
        ),
        (
            "context_budget_bound",
            metrics.max_context_tokens <= MAX_CONTEXT_TOKENS,
        ),
        (
            "prompt_budget_bound",
            metrics.max_prompt_tokens <= MAX_PROMPT_TOKENS,
        ),
        (
            "decode_budget_bound",
            metrics.max_decode_tokens <= MAX_DECODE_TOKENS,
        ),
        (
            "memory_budget_bound",
            metrics.max_memory_budget_bytes <= MAX_MEMORY_BUDGET_BYTES,
        ),
        (
            "runtime_budget_bound",
            metrics.max_runtime_seconds <= MAX_RUNTIME_SECONDS,
        ),
        (
            "metadata_bound",
            witness.metadata_bytes <= MAX_METADATA_BYTES,
        ),
        (
            "small_model_runtime_harness_owner_approved_probe_address_deterministic",
            deterministic,
        ),
        (
            "missing_required_lane_rejected",
            invalid_axes.missing_required_lane_rejected,
        ),
        (
            "duplicate_lease_rejected",
            invalid_axes.duplicate_lease_rejected,
        ),
        (
            "missing_phase_rejected",
            invalid_axes.missing_phase_rejected,
        ),
        (
            "missing_dry_run_artifact_rejected",
            invalid_axes.missing_dry_run_artifact_rejected,
        ),
        (
            "missing_owner_approval_rejected",
            invalid_axes.missing_owner_approval_rejected,
        ),
        (
            "owner_approval_not_bound_rejected",
            invalid_axes.owner_approval_not_bound_rejected,
        ),
        (
            "missing_model_catalog_rejected",
            invalid_axes.missing_model_catalog_rejected,
        ),
        (
            "missing_model_snapshot_rejected",
            invalid_axes.missing_model_snapshot_rejected,
        ),
        (
            "missing_prompt_envelope_rejected",
            invalid_axes.missing_prompt_envelope_rejected,
        ),
        (
            "missing_serialized_executor_rejected",
            invalid_axes.missing_serialized_executor_rejected,
        ),
        (
            "missing_cancellation_rejected",
            invalid_axes.missing_cancellation_rejected,
        ),
        (
            "missing_rollback_rejected",
            invalid_axes.missing_rollback_rejected,
        ),
        (
            "missing_run_event_log_rejected",
            invalid_axes.missing_run_event_log_rejected,
        ),
        (
            "missing_answer_packet_rejected",
            invalid_axes.missing_answer_packet_rejected,
        ),
        (
            "missing_privacy_rejected",
            invalid_axes.missing_privacy_rejected,
        ),
        (
            "missing_budget_rejected",
            invalid_axes.missing_budget_rejected,
        ),
        (
            "missing_admission_rejected",
            invalid_axes.missing_admission_rejected,
        ),
        (
            "missing_scope_rex_rejected",
            invalid_axes.missing_scope_rex_rejected,
        ),
        (
            "missing_sovereign_gate_rejected",
            invalid_axes.missing_sovereign_gate_rejected,
        ),
        (
            "missing_compatibility_fence_rejected",
            invalid_axes.missing_compatibility_fence_rejected,
        ),
        (
            "runtime_probe_not_armed_rejected",
            invalid_axes.runtime_probe_not_armed_rejected,
        ),
        (
            "runtime_probe_executed_rejected",
            invalid_axes.runtime_probe_executed_rejected,
        ),
        (
            "mutation_committed_rejected",
            invalid_axes.mutation_committed_rejected,
        ),
        (
            "route_policy_mutation_rejected",
            invalid_axes.route_policy_mutation_rejected,
        ),
        ("gate_bypass_rejected", invalid_axes.gate_bypass_rejected),
        (
            "answer_packet_suppression_rejected",
            invalid_axes.answer_packet_suppression_rejected,
        ),
        (
            "hidden_authority_rejected",
            invalid_axes.hidden_authority_rejected,
        ),
        ("hidden_chain_rejected", invalid_axes.hidden_chain_rejected),
        ("hidden_cloud_rejected", invalid_axes.hidden_cloud_rejected),
        (
            "subprocess_spawn_rejected",
            invalid_axes.subprocess_spawn_rejected,
        ),
        (
            "autogenous_kernel_rejected",
            invalid_axes.autogenous_kernel_rejected,
        ),
        (
            "seventy_b_probe_rejected",
            invalid_axes.seventy_b_probe_rejected,
        ),
        (
            "context_budget_overflow_rejected",
            invalid_axes.context_budget_overflow_rejected,
        ),
        (
            "decode_budget_overflow_rejected",
            invalid_axes.decode_budget_overflow_rejected,
        ),
        (
            "memory_budget_overflow_rejected",
            invalid_axes.memory_budget_overflow_rejected,
        ),
        (
            "runtime_budget_overflow_rejected",
            invalid_axes.runtime_budget_overflow_rejected,
        ),
        (
            "mas_overclaim_rejected",
            invalid_axes.mas_overclaim_rejected,
        ),
        (
            "l2_green_claim_rejected",
            invalid_axes.l2_green_claim_rejected,
        ),
        (
            "l3_green_claim_rejected",
            invalid_axes.l3_green_claim_rejected,
        ),
        (
            "runtime_bytes_rejected",
            invalid_axes.runtime_bytes_rejected,
        ),
        ("model_bytes_rejected", invalid_axes.model_bytes_rejected),
        (
            "transport_runtime_bytes_rejected",
            invalid_axes.transport_runtime_bytes_rejected,
        ),
        (
            "metadata_budget_rejected",
            invalid_axes.metadata_budget_rejected,
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

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lease_count",
        metrics.lease_count,
        ">=",
        MIN_LEASE_COUNT,
        "leases",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "surface_count",
        metrics.surface_count,
        ">=",
        MIN_SURFACE_COUNT,
        "surfaces",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_lane_count",
        metrics.required_lane_count,
        ">=",
        MIN_REQUIRED_LANE_COUNT,
        "lanes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "phase_count",
        metrics.phase_count,
        ">=",
        MIN_PHASE_COUNT,
        "phases",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_context_tokens",
        metrics.max_context_tokens,
        "<=",
        MAX_CONTEXT_TOKENS,
        "tokens",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_prompt_tokens",
        metrics.max_prompt_tokens,
        "<=",
        MAX_PROMPT_TOKENS,
        "tokens",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_decode_tokens",
        metrics.max_decode_tokens,
        "<=",
        MAX_DECODE_TOKENS,
        "tokens",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_memory_budget_bytes",
        metrics.max_memory_budget_bytes,
        "<=",
        MAX_MEMORY_BUDGET_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_runtime_seconds",
        metrics.max_runtime_seconds,
        "<=",
        MAX_RUNTIME_SECONDS,
        "seconds",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_probe_armed_count",
        metrics.runtime_probe_armed_count,
        "==",
        metrics.lease_count,
        "leases",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_probe_executed_count",
        metrics.runtime_probe_executed_count,
        "==",
        0,
        "leases",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mutation_committed_count",
        metrics.mutation_committed_count,
        "==",
        0,
        "leases",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cloud_fallback_count",
        metrics.cloud_fallback_count,
        "==",
        0,
        "leases",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "subprocess_spawn_count",
        metrics.subprocess_spawn_count,
        "==",
        0,
        "leases",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "seventy_b_probe_count",
        metrics.seventy_b_probe_count,
        "==",
        0,
        "leases",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_bytes_loaded",
        metrics.runtime_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_bytes_loaded",
        metrics.model_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "transport_runtime_bytes_loaded",
        metrics.transport_runtime_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes",
        witness.metadata_bytes,
        "<=",
        MAX_METADATA_BYTES,
        "bytes",
    );
    measurements.insert(
        "small_model_runtime_harness_owner_approved_probe_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address),
            unit: "sha256".to_string(),
        },
    );

    let anomalies = vec![serde_json::json!({
        "kind": "small_model_runtime_harness_owner_approved_probe_metadata_only",
        "detail": "Owner approval, local catalog selection, admission, serialized executor, cancellation, rollback, RunEventLog, AnswerPacket, privacy, and budget leases are witnessed at L1. No MLX/runtime/model bytes execute here; the next gate is an abortable runtime probe, not L2/L3 product promotion."
    })];

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
        notes: "metadata-only F-SmallModelRuntimeHarnessOwnerApprovedProbe: proves owner-approved small-model runtime probe leases are dry-run-bound, local-catalog-bound, serialized, abortable, rollback-backed, RunEventLog/AnswerPacket-visible, privacy-fenced, MAS-honest, and zero-runtime-byte before any live MLX smoke probe."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Clone)]
// UAS: uas:small-model-runtime-harness-owner-probe:evidence-snapshot
// Plane: Verification
// Residency: metadata-only snapshot of guard, capability, and dry-run evidence.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    dry_run_pass: bool,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, OwnerProbeWitnessError> {
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        let dry_run = read_json(Path::new(DRY_RUN_PATH))?;
        Ok(Self {
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_else(|| "unset".to_string()),
            capability_overall_pass: capability
                .get("overall_pass")
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false),
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_else(|| "unset".to_string()),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_else(|| "unset".to_string()),
            dry_run_pass: artifact_all_axes_true(
                &dry_run,
                SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_AXES,
            ),
        })
    }
}

fn fixture_witness(
    evidence: &EvidenceSnapshot,
) -> Result<SmallModelRuntimeHarnessOwnerProbeWitness, OwnerProbeWitnessError> {
    let living_index = read_text(Path::new(LIVING_INDEX_PATH))?;
    let lattice_html = read_text(Path::new(LATTICE_HTML_PATH))?;
    let surfaces = vec![
        surface("living_index", LIVING_INDEX_PATH, living_index)?,
        surface("lattice_html", LATTICE_HTML_PATH, lattice_html)?,
    ];
    let dry_run_ref = "artifact:small_model_runtime_harness_dry_run_witness:result";
    let leases = vec![
        lease(
            "owner_probe_qwen3_4b_smoke",
            "qwen3_small_catalog_smoke",
            "fast_local_notes_smoke",
            dry_run_ref,
            "model_catalog:Qwen/Qwen3-4B-MLX-4bit",
            "model_snapshot:local:models--Qwen--Qwen3-4B-MLX-4bit:52a5ab34fa604bc8af6d3ce0cac0cab10b7eb495",
            4096,
            512,
            128,
            2 * 1024 * 1024 * 1024,
            60,
        )?,
        lease(
            "owner_probe_qwen3_thinking_4b_research",
            "local_agent_notes_research_smoke",
            "research_note_reasoning_smoke",
            dry_run_ref,
            "model_catalog:mlx-community/Qwen3-4B-Thinking-2507-4bit",
            "model_snapshot:local:models--mlx-community--Qwen3-4B-Thinking-2507-4bit:627b019c66f22d4de0a641d289b41497651a55c9",
            8192,
            1024,
            192,
            3 * 1024 * 1024 * 1024,
            90,
        )?,
        lease(
            "owner_probe_qwen3_coder_next_coding",
            "coding_tool_dry_run_smoke",
            "coding_tool_smoke",
            dry_run_ref,
            "model_catalog:mlx-community/Qwen3-Coder-Next-4bit",
            "model_snapshot:local:models--mlx-community--Qwen3-Coder-Next-4bit:7b9321eabb85ce79625cac3f61ea691e4ea984b5",
            8192,
            1024,
            192,
            4 * 1024 * 1024 * 1024,
            120,
        )?,
    ];
    let metadata_bytes = leases
        .iter()
        .map(|lease| {
            lease.lease_id.len() + lease.model_catalog_ref.len() + lease.model_snapshot_ref.len()
        })
        .sum::<usize>() as u64
        + 8192;
    Ok(SmallModelRuntimeHarnessOwnerProbeWitness::new(
        "small_model_runtime_harness_owner_approved_probe_2026_06_05",
        dry_run_ref,
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "small_model_runtime_harness_owner_approval_only",
        leases,
        surfaces,
        metadata_bytes,
        true,
        false,
        false,
        false,
    )?)
}

fn surface(
    surface_id: &str,
    path: &str,
    observed_text: String,
) -> Result<SmallModelOwnerProbeSurface, OwnerProbeWitnessError> {
    Ok(SmallModelOwnerProbeSurface::new(
        surface_id,
        path,
        vec![
            "Epistemos is a local cognitive substrate".to_string(),
            "no claim promotes without visible proof".to_string(),
            SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_CURSOR.to_string(),
            "vault_research_route_with_packetized_mitigation".to_string(),
        ],
        vec![
            "live 70B is done".to_string(),
            "dense 70B runs comfortably on 16 GB".to_string(),
            "small model runtime is product-live".to_string(),
            "hidden cloud fallback is allowed".to_string(),
        ],
        observed_text,
    )?)
}

#[allow(clippy::too_many_arguments)]
fn lease(
    lease_id: &str,
    lane_id: &str,
    model_role: &str,
    dry_run_ref: &str,
    model_catalog_ref: &str,
    model_snapshot_ref: &str,
    max_context_tokens: u32,
    prompt_tokens: u32,
    max_decode_tokens: u32,
    memory_budget_bytes: u64,
    runtime_budget_seconds: u32,
) -> Result<SmallModelOwnerProbeLease, OwnerProbeWitnessError> {
    Ok(SmallModelOwnerProbeLease::new(
        lease_id,
        lane_id,
        model_role,
        dry_run_ref,
        "owner_approval:2026-06-05:user-requested-small-model-runtime-before-70b:lease-only",
        model_catalog_ref,
        model_snapshot_ref,
        format!("prompt_envelope:{lane_id}:visible-no-hidden-chain"),
        format!("admission:{lane_id}:scope-rex-sovereign-gate"),
        format!("scope_rex:{lane_id}:local-small-model-smoke"),
        format!("sovereign_gate:{lane_id}:owner-approved-probe"),
        format!("compat:{lane_id}:mlx-small-smoke-v1"),
        format!("serialized_executor:{lane_id}:single-flight"),
        format!("cancel:{lane_id}:owner-probe-abort"),
        format!("rollback:{lane_id}:no-mutation"),
        format!("run_event_log:{lane_id}:owner-probe"),
        format!("answer_packet:{lane_id}:visible-summary"),
        format!("privacy:{lane_id}:local-only-no-cloud"),
        format!("budget:{lane_id}:bounded-small-smoke"),
        owner_probe_phases(),
        max_context_tokens,
        prompt_tokens,
        max_decode_tokens,
        memory_budget_bytes,
        runtime_budget_seconds,
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
        false,
        false,
        false,
        0,
        0,
        0,
    )?)
}

fn owner_probe_phases() -> BTreeSet<SmallModelOwnerProbePhase> {
    [
        SmallModelOwnerProbePhase::DryRunArtifactBound,
        SmallModelOwnerProbePhase::OwnerApprovalLeaseBound,
        SmallModelOwnerProbePhase::ModelCatalogBound,
        SmallModelOwnerProbePhase::PromptEnvelopeCompiled,
        SmallModelOwnerProbePhase::AdmissionChecked,
        SmallModelOwnerProbePhase::ExecutorReserved,
        SmallModelOwnerProbePhase::CancellationArmed,
        SmallModelOwnerProbePhase::RollbackCheckpointRecorded,
        SmallModelOwnerProbePhase::RuntimeProbeArmed,
        SmallModelOwnerProbePhase::RuntimeExecutionDeferred,
        SmallModelOwnerProbePhase::RunEventLogged,
        SmallModelOwnerProbePhase::AnswerPacketDrafted,
        SmallModelOwnerProbePhase::EvidenceReviewPending,
    ]
    .into_iter()
    .collect()
}

#[derive(Default)]
// UAS: uas:small-model-runtime-harness-owner-probe:invalid-axes
// Plane: Verification
// Residency: metadata-only invalid-fixture rejection coverage.
struct InvalidAxes {
    missing_required_lane_rejected: bool,
    duplicate_lease_rejected: bool,
    missing_phase_rejected: bool,
    missing_dry_run_artifact_rejected: bool,
    missing_owner_approval_rejected: bool,
    owner_approval_not_bound_rejected: bool,
    missing_model_catalog_rejected: bool,
    missing_model_snapshot_rejected: bool,
    missing_prompt_envelope_rejected: bool,
    missing_serialized_executor_rejected: bool,
    missing_cancellation_rejected: bool,
    missing_rollback_rejected: bool,
    missing_run_event_log_rejected: bool,
    missing_answer_packet_rejected: bool,
    missing_privacy_rejected: bool,
    missing_budget_rejected: bool,
    missing_admission_rejected: bool,
    missing_scope_rex_rejected: bool,
    missing_sovereign_gate_rejected: bool,
    missing_compatibility_fence_rejected: bool,
    runtime_probe_not_armed_rejected: bool,
    runtime_probe_executed_rejected: bool,
    mutation_committed_rejected: bool,
    route_policy_mutation_rejected: bool,
    gate_bypass_rejected: bool,
    answer_packet_suppression_rejected: bool,
    hidden_authority_rejected: bool,
    hidden_chain_rejected: bool,
    hidden_cloud_rejected: bool,
    subprocess_spawn_rejected: bool,
    autogenous_kernel_rejected: bool,
    seventy_b_probe_rejected: bool,
    context_budget_overflow_rejected: bool,
    decode_budget_overflow_rejected: bool,
    memory_budget_overflow_rejected: bool,
    runtime_budget_overflow_rejected: bool,
    mas_overclaim_rejected: bool,
    l2_green_claim_rejected: bool,
    l3_green_claim_rejected: bool,
    runtime_bytes_rejected: bool,
    model_bytes_rejected: bool,
    transport_runtime_bytes_rejected: bool,
    metadata_budget_rejected: bool,
}

fn invalid_fixture_axes(
    evidence: &EvidenceSnapshot,
) -> Result<InvalidAxes, OwnerProbeWitnessError> {
    Ok(InvalidAxes {
        missing_required_lane_rejected: reject_witness(evidence, |w| {
            w.leases
                .retain(|lease| lease.lane_id != "coding_tool_dry_run_smoke");
        })?,
        duplicate_lease_rejected: reject_witness(evidence, |w| {
            w.leases[1] = w.leases[0].clone();
        })?,
        missing_phase_rejected: reject_lease(evidence, |lease| {
            lease
                .phases
                .remove(&SmallModelOwnerProbePhase::RuntimeExecutionDeferred);
        })?,
        missing_dry_run_artifact_rejected: reject_lease(evidence, |lease| {
            lease.dry_run_artifact_ref = "artifact:missing:result".to_string();
        })?,
        missing_owner_approval_rejected: reject_lease(evidence, |lease| {
            lease.owner_approval_ref = "chat:loose-approval".to_string();
        })?,
        owner_approval_not_bound_rejected: reject_lease(evidence, |lease| {
            lease.approval_bound_to_dry_run = false;
        })?,
        missing_model_catalog_rejected: reject_lease(evidence, |lease| {
            lease.model_catalog_ref = "model:Qwen".to_string();
        })?,
        missing_model_snapshot_rejected: reject_lease(evidence, |lease| {
            lease.model_snapshot_ref = "model_snapshot:remote:qwen".to_string();
        })?,
        missing_prompt_envelope_rejected: reject_lease(evidence, |lease| {
            lease.prompt_envelope_ref = "prompt:qwen".to_string();
        })?,
        missing_serialized_executor_rejected: reject_lease(evidence, |lease| {
            lease.serialized_executor_ref = "executor:qwen".to_string();
        })?,
        missing_cancellation_rejected: reject_lease(evidence, |lease| {
            lease.cancellation_ref = "stop:qwen".to_string();
        })?,
        missing_rollback_rejected: reject_lease(evidence, |lease| {
            lease.rollback_ref = "undo:qwen".to_string();
        })?,
        missing_run_event_log_rejected: reject_lease(evidence, |lease| {
            lease.run_event_log_ref = "log:qwen".to_string();
        })?,
        missing_answer_packet_rejected: reject_lease(evidence, |lease| {
            lease.answer_packet_ref = "packet:qwen".to_string();
        })?,
        missing_privacy_rejected: reject_lease(evidence, |lease| {
            lease.privacy_ref = "local-only".to_string();
        })?,
        missing_budget_rejected: reject_lease(evidence, |lease| {
            lease.budget_ref = "limit:qwen".to_string();
        })?,
        missing_admission_rejected: reject_lease(evidence, |lease| {
            lease.admission_ref = "gate:qwen".to_string();
        })?,
        missing_scope_rex_rejected: reject_lease(evidence, |lease| {
            lease.scope_rex_ref = "scope:qwen".to_string();
        })?,
        missing_sovereign_gate_rejected: reject_lease(evidence, |lease| {
            lease.sovereign_gate_ref = "sovereign:qwen".to_string();
        })?,
        missing_compatibility_fence_rejected: reject_lease(evidence, |lease| {
            lease.compatibility_fence = "fence:qwen".to_string();
        })?,
        runtime_probe_not_armed_rejected: reject_lease(evidence, |lease| {
            lease.runtime_probe_armed = false;
        })?,
        runtime_probe_executed_rejected: reject_lease(evidence, |lease| {
            lease.runtime_probe_executed = true;
        })?,
        mutation_committed_rejected: reject_lease(evidence, |lease| {
            lease.mutation_committed = true;
        })?,
        route_policy_mutation_rejected: reject_lease(evidence, |lease| {
            lease.route_policy_mutated = true;
        })?,
        gate_bypass_rejected: reject_lease(evidence, |lease| {
            lease.gate_bypass = true;
        })?,
        answer_packet_suppression_rejected: reject_lease(evidence, |lease| {
            lease.answer_packet_suppressed = true;
        })?,
        hidden_authority_rejected: reject_lease(evidence, |lease| {
            lease.hidden_route_authority = true;
        })?,
        hidden_chain_rejected: reject_lease(evidence, |lease| {
            lease.hidden_chain_exposed = true;
        })?,
        hidden_cloud_rejected: reject_lease(evidence, |lease| {
            lease.hidden_cloud_fallback = true;
        })?,
        subprocess_spawn_rejected: reject_lease(evidence, |lease| {
            lease.subprocess_spawned = true;
        })?,
        autogenous_kernel_rejected: reject_lease(evidence, |lease| {
            lease.autogenous_kernel_attempted = true;
        })?,
        seventy_b_probe_rejected: reject_lease(evidence, |lease| {
            lease.seventy_b_probe_attempted = true;
        })?,
        context_budget_overflow_rejected: reject_lease(evidence, |lease| {
            lease.max_context_tokens = 40_961;
        })?,
        decode_budget_overflow_rejected: reject_lease(evidence, |lease| {
            lease.max_decode_tokens = 513;
        })?,
        memory_budget_overflow_rejected: reject_lease(evidence, |lease| {
            lease.memory_budget_bytes = 8 * 1024 * 1024 * 1024 + 1;
        })?,
        runtime_budget_overflow_rejected: reject_lease(evidence, |lease| {
            lease.runtime_budget_seconds = 301;
        })?,
        mas_overclaim_rejected: reject_witness(evidence, |w| {
            w.mas_overclaim_attempted = true;
        })?,
        l2_green_claim_rejected: reject_witness(evidence, |w| {
            w.l2_green_claimed = true;
        })?,
        l3_green_claim_rejected: reject_witness(evidence, |w| {
            w.l3_green_claimed = true;
        })?,
        runtime_bytes_rejected: reject_lease(evidence, |lease| {
            lease.runtime_bytes_loaded = 1;
        })?,
        model_bytes_rejected: reject_lease(evidence, |lease| {
            lease.model_bytes_loaded = 1;
        })?,
        transport_runtime_bytes_rejected: reject_lease(evidence, |lease| {
            lease.transport_runtime_bytes_loaded = 1;
        })?,
        metadata_budget_rejected: reject_witness(evidence, |w| {
            w.metadata_bytes = MAX_METADATA_BYTES + 1;
        })?,
    })
}

fn reject_lease<F>(evidence: &EvidenceSnapshot, mutate: F) -> Result<bool, OwnerProbeWitnessError>
where
    F: FnOnce(&mut SmallModelOwnerProbeLease),
{
    reject_witness(evidence, |w| mutate(&mut w.leases[0]))
}

fn reject_witness<F>(evidence: &EvidenceSnapshot, mutate: F) -> Result<bool, OwnerProbeWitnessError>
where
    F: FnOnce(&mut SmallModelRuntimeHarnessOwnerProbeWitness),
{
    let mut witness = fixture_witness(evidence)?;
    mutate(&mut witness);
    Ok(rebuild_witness(witness).is_err())
}

fn rebuild_witness(
    witness: SmallModelRuntimeHarnessOwnerProbeWitness,
) -> Result<SmallModelRuntimeHarnessOwnerProbeWitness, SmallModelRuntimeHarnessOwnerProbeError> {
    SmallModelRuntimeHarnessOwnerProbeWitness::new(
        witness.witness_id,
        witness.dry_run_artifact_ref,
        witness.guard_next_existing_work,
        witness.capability_route_status,
        witness.capability_next_bottleneck,
        witness.product_build,
        witness.pro_status,
        witness.route_authority,
        witness.leases,
        witness.surfaces,
        witness.metadata_bytes,
        witness.l1_l2_l3_separated,
        witness.mas_overclaim_attempted,
        witness.l2_green_claimed,
        witness.l3_green_claimed,
    )
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    operator: &str,
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
            operator: operator.to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    let passed = match operator {
        "==" => actual == expected,
        ">=" => actual >= expected,
        "<=" => actual <= expected,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), passed);
}

fn read_json(path: &Path) -> Result<serde_json::Value, OwnerProbeWitnessError> {
    let text = read_text(path)?;
    serde_json::from_str(&text).map_err(|error| {
        OwnerProbeWitnessError::Io(format!("failed to parse {}: {error}", path.display()))
    })
}

fn read_text(path: &Path) -> Result<String, OwnerProbeWitnessError> {
    std::fs::read_to_string(path).map_err(|error| {
        OwnerProbeWitnessError::Io(format!("failed to read {}: {error}", path.display()))
    })
}

fn measurement_string(value: &serde_json::Value, name: &str) -> Option<String> {
    value
        .get("measurements")?
        .get(name)?
        .get("value")?
        .as_str()
        .map(str::to_string)
}

fn artifact_all_axes_true(value: &serde_json::Value, axes: &[&str]) -> bool {
    value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
        && axes.iter().all(|axis| {
            value
                .get("pass_per_axis")
                .and_then(|pass| pass.get(*axis))
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false)
        })
}
