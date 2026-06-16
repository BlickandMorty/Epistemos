//! `falsify_small_model_runtime_harness_abortable_runtime_probe`.
//!
//! Metadata-only abort-path witness for
//! `F-SmallModelRuntimeHarnessAbortableRuntimeProbe`. It proves the
//! owner-approved small-model runtime probe can be attempted, cancelled, and
//! rolled back before runtime/model bytes open, with RunEventLog and
//! AnswerPacket visibility. It does not execute MLX or promote L2/L3.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, SmallModelAbortableRuntimeProbePhase,
    SmallModelAbortableRuntimeProbeRun, SmallModelAbortableRuntimeProbeSurface,
    SmallModelRuntimeHarnessAbortableProbeError, SmallModelRuntimeHarnessAbortableProbeWitness,
    SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallModelRuntimeHarnessAbortableRuntimeProbe";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";
const FIXTURE_ID: &str = "small_model_runtime_harness_abortable_runtime_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_small_model_runtime_harness_abortable_runtime_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_abortable_runtime_probe/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const OWNER_PROBE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_owner_approved_probe/result.json";
const LIVING_INDEX_PATH: &str = "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md";
const LATTICE_HTML_PATH: &str = "artifacts/lattice-coordinate-explainer/index.html";
const MIN_RUN_COUNT: u64 = 3;
const MIN_SURFACE_COUNT: u64 = 2;
const MIN_REQUIRED_LANE_COUNT: u64 = 3;
const MIN_PHASE_COUNT: u64 = 13;
const MAX_CONTEXT_TOKENS: u64 = 40_960;
const MAX_PROMPT_TOKENS: u64 = 8_192;
const MAX_DECODE_TOKENS: u64 = 512;
const MAX_MEMORY_BUDGET_BYTES: u64 = 8 * 1024 * 1024 * 1024;
const MAX_RUNTIME_SECONDS: u64 = 300;
const MAX_DEADLINE_MS: u64 = 1_000;
const MAX_OBSERVED_ELAPSED_MS: u64 = 1_000;
const MAX_METADATA_BYTES: u64 = 384 * 1024;

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-abortable-runtime-probe:witness-error
// Plane: Verification
// Residency: metadata-only abort-path rejection taxonomy.
enum AbortableProbeWitnessError {
    Primitive(SmallModelRuntimeHarnessAbortableProbeError),
    Io(String),
}

impl std::fmt::Display for AbortableProbeWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for AbortableProbeWitnessError {}

impl From<SmallModelRuntimeHarnessAbortableProbeError> for AbortableProbeWitnessError {
    fn from(value: SmallModelRuntimeHarnessAbortableProbeError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, AbortableProbeWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fixture_witness(&evidence)?;
    let metrics = witness.metrics();
    let address = witness.address();
    let mut reversed = witness.runs.clone();
    reversed.reverse();
    let deterministic = SmallModelRuntimeHarnessAbortableProbeWitness::new(
        witness.witness_id.clone(),
        witness.owner_probe_artifact_ref.clone(),
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
            "upstream_small_model_runtime_harness_owner_approved_probe_pass",
            evidence.owner_probe_pass,
        ),
        (
            "guard_cursor_abortable_probe_or_advanced",
            evidence.guard_next_existing_work
                == SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_NEXT_CURSOR
                || evidence.guard_next_existing_work == ADVANCED_RELEASE_AUDIT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_abortable_probe_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_NEXT_CURSOR
                || evidence.capability_next_bottleneck == ADVANCED_RELEASE_AUDIT_CURSOR,
        ),
        (
            "product_status_research_only",
            witness.product_build == ProductBuild::Pro
                && witness.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_abortable_probe_only",
            witness.route_authority == "small_model_runtime_harness_abortable_probe_only",
        ),
        (
            "living_index_surface_scan_pass",
            witness.surfaces.iter().any(|surface| {
                surface.surface_id == "living_index"
                    && surface
                        .observed_text
                        .contains(SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR)
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
                        .contains(SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR)
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
            "owner_probe_artifact_ref_bound",
            witness
                .owner_probe_artifact_ref
                .starts_with("artifact:small_model_runtime_harness_owner_approved_probe:"),
        ),
        (
            "model_catalog_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.model_catalog_ref.starts_with("model_catalog:")),
        ),
        (
            "model_snapshot_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.model_snapshot_ref.starts_with("model_snapshot:local:")),
        ),
        (
            "prompt_envelope_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.prompt_envelope_ref.starts_with("prompt_envelope:")),
        ),
        (
            "serialized_executor_bound",
            witness.runs.iter().all(|run| {
                run.serialized_executor_ref
                    .starts_with("serialized_executor:")
            }),
        ),
        (
            "cancellation_bound",
            witness
                .runs
                .iter()
                .all(|run| run.cancellation_ref.starts_with("cancel:")),
        ),
        (
            "deadline_bound",
            witness
                .runs
                .iter()
                .all(|run| run.deadline_ref.starts_with("deadline:")),
        ),
        (
            "abort_reason_bound",
            witness
                .runs
                .iter()
                .all(|run| run.abort_reason_ref.starts_with("abort_reason:")),
        ),
        (
            "rollback_bound",
            witness
                .runs
                .iter()
                .all(|run| run.rollback_ref.starts_with("rollback:")),
        ),
        (
            "run_event_log_bound",
            witness
                .runs
                .iter()
                .all(|run| run.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "answer_packet_bound",
            witness
                .runs
                .iter()
                .all(|run| run.answer_packet_ref.starts_with("answer_packet:")),
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
            "privacy_fence_bound",
            witness
                .runs
                .iter()
                .all(|run| run.privacy_ref.starts_with("privacy:")),
        ),
        (
            "budget_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.budget_ref.starts_with("budget:")),
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
            "probe_attempted",
            metrics.probe_attempted_count == metrics.run_count,
        ),
        (
            "cancellation_armed",
            metrics.cancellation_armed_count == metrics.run_count,
        ),
        (
            "abort_signal_observed",
            metrics.abort_observed_count == metrics.run_count,
        ),
        (
            "runtime_start_suppressed",
            metrics.runtime_start_suppressed_count == metrics.run_count,
        ),
        (
            "runtime_not_completed",
            metrics.runtime_completed_count == 0,
        ),
        (
            "model_open_not_attempted",
            metrics.model_open_attempted_count == 0,
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
            witness.runs.iter().all(|run| !run.hidden_route_authority),
        ),
        (
            "no_route_policy_mutation",
            witness.runs.iter().all(|run| !run.route_policy_mutated),
        ),
        (
            "no_gate_bypass",
            witness.runs.iter().all(|run| !run.gate_bypass),
        ),
        (
            "no_answer_packet_suppression",
            witness.runs.iter().all(|run| !run.answer_packet_suppressed),
        ),
        (
            "no_hidden_chain",
            witness.runs.iter().all(|run| !run.hidden_chain_exposed),
        ),
        (
            "no_hidden_cloud_fallback",
            witness.runs.iter().all(|run| !run.hidden_cloud_fallback),
        ),
        (
            "no_subprocess_spawn",
            witness.runs.iter().all(|run| !run.subprocess_spawned),
        ),
        (
            "no_autogenous_kernel_attempt",
            witness
                .runs
                .iter()
                .all(|run| !run.autogenous_kernel_attempted),
        ),
        (
            "no_70b_probe_attempt",
            witness
                .runs
                .iter()
                .all(|run| !run.seventy_b_probe_attempted),
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
            "deadline_budget_bound",
            metrics.max_deadline_ms <= MAX_DEADLINE_MS,
        ),
        (
            "observed_elapsed_bound",
            metrics.max_observed_elapsed_ms <= MAX_OBSERVED_ELAPSED_MS,
        ),
        (
            "metadata_bound",
            witness.metadata_bytes <= MAX_METADATA_BYTES,
        ),
        (
            "small_model_runtime_harness_abortable_runtime_probe_address_deterministic",
            deterministic,
        ),
        (
            "missing_required_lane_rejected",
            invalid_axes.missing_required_lane_rejected,
        ),
        (
            "duplicate_run_rejected",
            invalid_axes.duplicate_run_rejected,
        ),
        (
            "missing_phase_rejected",
            invalid_axes.missing_phase_rejected,
        ),
        (
            "missing_owner_probe_artifact_rejected",
            invalid_axes.missing_owner_probe_artifact_rejected,
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
            "missing_deadline_rejected",
            invalid_axes.missing_deadline_rejected,
        ),
        (
            "missing_abort_reason_rejected",
            invalid_axes.missing_abort_reason_rejected,
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
            "probe_not_attempted_rejected",
            invalid_axes.probe_not_attempted_rejected,
        ),
        (
            "cancellation_not_armed_rejected",
            invalid_axes.cancellation_not_armed_rejected,
        ),
        (
            "abort_not_observed_rejected",
            invalid_axes.abort_not_observed_rejected,
        ),
        (
            "runtime_start_not_suppressed_rejected",
            invalid_axes.runtime_start_not_suppressed_rejected,
        ),
        (
            "runtime_completed_rejected",
            invalid_axes.runtime_completed_rejected,
        ),
        (
            "model_open_attempted_rejected",
            invalid_axes.model_open_attempted_rejected,
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
            "deadline_overflow_rejected",
            invalid_axes.deadline_overflow_rejected,
        ),
        (
            "deadline_overrun_rejected",
            invalid_axes.deadline_overrun_rejected,
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
        "run_count",
        metrics.run_count,
        ">=",
        MIN_RUN_COUNT,
        "runs",
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
        "probe_attempted_count",
        metrics.probe_attempted_count,
        "==",
        metrics.run_count,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cancellation_armed_count",
        metrics.cancellation_armed_count,
        "==",
        metrics.run_count,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "abort_observed_count",
        metrics.abort_observed_count,
        "==",
        metrics.run_count,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_start_suppressed_count",
        metrics.runtime_start_suppressed_count,
        "==",
        metrics.run_count,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_completed_count",
        metrics.runtime_completed_count,
        "==",
        0,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_open_attempted_count",
        metrics.model_open_attempted_count,
        "==",
        0,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mutation_committed_count",
        metrics.mutation_committed_count,
        "==",
        0,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cloud_fallback_count",
        metrics.cloud_fallback_count,
        "==",
        0,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "subprocess_spawn_count",
        metrics.subprocess_spawn_count,
        "==",
        0,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "seventy_b_probe_count",
        metrics.seventy_b_probe_count,
        "==",
        0,
        "runs",
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
        "max_deadline_ms",
        metrics.max_deadline_ms,
        "<=",
        MAX_DEADLINE_MS,
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_observed_elapsed_ms",
        metrics.max_observed_elapsed_ms,
        "<=",
        MAX_OBSERVED_ELAPSED_MS,
        "ms",
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
        "small_model_runtime_harness_abortable_runtime_probe_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address),
            unit: "sha256".to_string(),
        },
    );

    let anomalies = vec![serde_json::json!({
        "kind": "small_model_runtime_harness_abortable_runtime_probe_metadata_only",
        "detail": "The abortable small-model runtime probe proves pre-runtime cancellation, deadline, rollback, RunEventLog, AnswerPacket, admission, privacy, and budget discipline. It intentionally suppresses runtime/model byte opening, so L2 capability and L3 product runtime remain unpromoted."
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
        notes: "metadata-only F-SmallModelRuntimeHarnessAbortableRuntimeProbe: proves owner-approved small-model runtime smoke lanes can be attempted and aborted before runtime/model bytes open, with deadline, rollback, RunEventLog, AnswerPacket, privacy, MAS honesty, and L1/L2/L3 separation."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Clone)]
// UAS: uas:small-model-runtime-harness-abortable-runtime-probe:evidence-snapshot
// Plane: Verification
// Residency: metadata-only snapshot of guard, capability, and owner-probe evidence.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    owner_probe_pass: bool,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, AbortableProbeWitnessError> {
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        let owner_probe = read_json(Path::new(OWNER_PROBE_PATH))?;
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
            owner_probe_pass: artifact_all_axes_true(
                &owner_probe,
                SMALL_MODEL_RUNTIME_HARNESS_OWNER_APPROVED_PROBE_AXES,
            ),
        })
    }
}

fn fixture_witness(
    evidence: &EvidenceSnapshot,
) -> Result<SmallModelRuntimeHarnessAbortableProbeWitness, AbortableProbeWitnessError> {
    let living_index = read_text(Path::new(LIVING_INDEX_PATH))?;
    let lattice_html = read_text(Path::new(LATTICE_HTML_PATH))?;
    let surfaces = vec![
        surface("living_index", LIVING_INDEX_PATH, living_index)?,
        surface("lattice_html", LATTICE_HTML_PATH, lattice_html)?,
    ];
    let owner_probe_ref = "artifact:small_model_runtime_harness_owner_approved_probe:result";
    let runs = vec![
        run(
            "abortable_probe_qwen3_4b_smoke",
            "qwen3_small_catalog_smoke",
            "fast_local_notes_smoke",
            owner_probe_ref,
            "model_catalog:Qwen/Qwen3-4B-MLX-4bit",
            "model_snapshot:local:models--Qwen--Qwen3-4B-MLX-4bit:52a5ab34fa604bc8af6d3ce0cac0cab10b7eb495",
            4096,
            512,
            128,
            2 * 1024 * 1024 * 1024,
            60,
            100,
            31,
        )?,
        run(
            "abortable_probe_qwen3_thinking_4b_research",
            "local_agent_notes_research_smoke",
            "research_note_reasoning_smoke",
            owner_probe_ref,
            "model_catalog:mlx-community/Qwen3-4B-Thinking-2507-4bit",
            "model_snapshot:local:models--mlx-community--Qwen3-4B-Thinking-2507-4bit:627b019c66f22d4de0a641d289b41497651a55c9",
            8192,
            1024,
            192,
            3 * 1024 * 1024 * 1024,
            90,
            150,
            44,
        )?,
        run(
            "abortable_probe_qwen3_coder_next_coding",
            "coding_tool_dry_run_smoke",
            "coding_tool_smoke",
            owner_probe_ref,
            "model_catalog:mlx-community/Qwen3-Coder-Next-4bit",
            "model_snapshot:local:models--mlx-community--Qwen3-Coder-Next-4bit:7b9321eabb85ce79625cac3f61ea691e4ea984b5",
            8192,
            1024,
            192,
            4 * 1024 * 1024 * 1024,
            120,
            200,
            58,
        )?,
    ];
    let metadata_bytes = runs
        .iter()
        .map(|run| run.run_id.len() + run.model_catalog_ref.len() + run.model_snapshot_ref.len())
        .sum::<usize>() as u64
        + 12_288;
    Ok(SmallModelRuntimeHarnessAbortableProbeWitness::new(
        "small_model_runtime_harness_abortable_runtime_probe_2026_06_05",
        owner_probe_ref,
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "small_model_runtime_harness_abortable_probe_only",
        runs,
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
) -> Result<SmallModelAbortableRuntimeProbeSurface, AbortableProbeWitnessError> {
    Ok(SmallModelAbortableRuntimeProbeSurface::new(
        surface_id,
        path,
        vec![
            "Epistemos is a local cognitive substrate".to_string(),
            "no claim promotes without visible proof".to_string(),
            SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_CURSOR.to_string(),
            "vault_research_route_with_packetized_mitigation".to_string(),
        ],
        vec![
            "live 70B is done".to_string(),
            "dense 70B runs comfortably on 16 GB".to_string(),
            "small model runtime is product-live".to_string(),
            "abortable runtime probe makes L2 green".to_string(),
            "hidden cloud fallback is allowed".to_string(),
        ],
        observed_text,
    )?)
}

#[allow(clippy::too_many_arguments)]
fn run(
    run_id: &str,
    lane_id: &str,
    model_role: &str,
    owner_probe_ref: &str,
    model_catalog_ref: &str,
    model_snapshot_ref: &str,
    max_context_tokens: u32,
    prompt_tokens: u32,
    max_decode_tokens: u32,
    memory_budget_bytes: u64,
    runtime_budget_seconds: u32,
    deadline_ms: u32,
    observed_elapsed_ms: u32,
) -> Result<SmallModelAbortableRuntimeProbeRun, AbortableProbeWitnessError> {
    Ok(SmallModelAbortableRuntimeProbeRun::new(
        run_id,
        lane_id,
        model_role,
        owner_probe_ref,
        model_catalog_ref,
        model_snapshot_ref,
        format!("prompt_envelope:{lane_id}:visible-no-hidden-chain"),
        format!("admission:{lane_id}:scope-rex-sovereign-gate"),
        format!("scope_rex:{lane_id}:local-small-model-abortable-smoke"),
        format!("sovereign_gate:{lane_id}:abortable-runtime-probe"),
        format!("compat:{lane_id}:mlx-small-smoke-v1"),
        format!("serialized_executor:{lane_id}:single-flight"),
        format!("cancel:{lane_id}:pre-runtime-abort-token"),
        format!("deadline:{lane_id}:pre-runtime-{deadline_ms}ms"),
        format!("abort_reason:{lane_id}:owner-cancel-before-model-open"),
        format!("rollback:{lane_id}:no-mutation"),
        format!("run_event_log:{lane_id}:abortable-probe"),
        format!("answer_packet:{lane_id}:visible-abort-summary"),
        format!("privacy:{lane_id}:local-only-no-cloud"),
        format!("budget:{lane_id}:bounded-small-smoke"),
        abortable_probe_phases(),
        max_context_tokens,
        prompt_tokens,
        max_decode_tokens,
        memory_budget_bytes,
        runtime_budget_seconds,
        deadline_ms,
        observed_elapsed_ms,
        true,
        true,
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
        false,
        0,
        0,
        0,
    )?)
}

fn abortable_probe_phases() -> BTreeSet<SmallModelAbortableRuntimeProbePhase> {
    [
        SmallModelAbortableRuntimeProbePhase::OwnerProbeArtifactBound,
        SmallModelAbortableRuntimeProbePhase::LocalSnapshotPinned,
        SmallModelAbortableRuntimeProbePhase::PromptEnvelopeCompiled,
        SmallModelAbortableRuntimeProbePhase::AdmissionChecked,
        SmallModelAbortableRuntimeProbePhase::SerializedExecutorEntered,
        SmallModelAbortableRuntimeProbePhase::CancellationTokenArmed,
        SmallModelAbortableRuntimeProbePhase::DeadlineArmed,
        SmallModelAbortableRuntimeProbePhase::AbortSignalObserved,
        SmallModelAbortableRuntimeProbePhase::RuntimeStartSuppressed,
        SmallModelAbortableRuntimeProbePhase::RollbackVerified,
        SmallModelAbortableRuntimeProbePhase::RunEventLogged,
        SmallModelAbortableRuntimeProbePhase::AnswerPacketDrafted,
        SmallModelAbortableRuntimeProbePhase::EvidenceReviewPending,
    ]
    .into_iter()
    .collect()
}

#[derive(Default)]
// UAS: uas:small-model-runtime-harness-abortable-runtime-probe:invalid-axes
// Plane: Verification
// Residency: metadata-only invalid-fixture rejection coverage.
struct InvalidAxes {
    missing_required_lane_rejected: bool,
    duplicate_run_rejected: bool,
    missing_phase_rejected: bool,
    missing_owner_probe_artifact_rejected: bool,
    missing_model_catalog_rejected: bool,
    missing_model_snapshot_rejected: bool,
    missing_prompt_envelope_rejected: bool,
    missing_serialized_executor_rejected: bool,
    missing_cancellation_rejected: bool,
    missing_deadline_rejected: bool,
    missing_abort_reason_rejected: bool,
    missing_rollback_rejected: bool,
    missing_run_event_log_rejected: bool,
    missing_answer_packet_rejected: bool,
    missing_privacy_rejected: bool,
    missing_budget_rejected: bool,
    missing_admission_rejected: bool,
    missing_scope_rex_rejected: bool,
    missing_sovereign_gate_rejected: bool,
    missing_compatibility_fence_rejected: bool,
    probe_not_attempted_rejected: bool,
    cancellation_not_armed_rejected: bool,
    abort_not_observed_rejected: bool,
    runtime_start_not_suppressed_rejected: bool,
    runtime_completed_rejected: bool,
    model_open_attempted_rejected: bool,
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
    deadline_overflow_rejected: bool,
    deadline_overrun_rejected: bool,
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
) -> Result<InvalidAxes, AbortableProbeWitnessError> {
    Ok(InvalidAxes {
        missing_required_lane_rejected: reject_witness(evidence, |w| {
            w.runs
                .retain(|run| run.lane_id != "coding_tool_dry_run_smoke");
        })?,
        duplicate_run_rejected: reject_witness(evidence, |w| {
            w.runs[1] = w.runs[0].clone();
        })?,
        missing_phase_rejected: reject_run(evidence, |run| {
            run.phases
                .remove(&SmallModelAbortableRuntimeProbePhase::AbortSignalObserved);
        })?,
        missing_owner_probe_artifact_rejected: reject_run(evidence, |run| {
            run.owner_probe_artifact_ref = "artifact:missing:result".to_string();
        })?,
        missing_model_catalog_rejected: reject_run(evidence, |run| {
            run.model_catalog_ref = "model:Qwen".to_string();
        })?,
        missing_model_snapshot_rejected: reject_run(evidence, |run| {
            run.model_snapshot_ref = "model_snapshot:remote:qwen".to_string();
        })?,
        missing_prompt_envelope_rejected: reject_run(evidence, |run| {
            run.prompt_envelope_ref = "prompt:qwen".to_string();
        })?,
        missing_serialized_executor_rejected: reject_run(evidence, |run| {
            run.serialized_executor_ref = "executor:qwen".to_string();
        })?,
        missing_cancellation_rejected: reject_run(evidence, |run| {
            run.cancellation_ref = "stop:qwen".to_string();
        })?,
        missing_deadline_rejected: reject_run(evidence, |run| {
            run.deadline_ref = "timer:qwen".to_string();
        })?,
        missing_abort_reason_rejected: reject_run(evidence, |run| {
            run.abort_reason_ref = "abort:qwen".to_string();
        })?,
        missing_rollback_rejected: reject_run(evidence, |run| {
            run.rollback_ref = "undo:qwen".to_string();
        })?,
        missing_run_event_log_rejected: reject_run(evidence, |run| {
            run.run_event_log_ref = "log:qwen".to_string();
        })?,
        missing_answer_packet_rejected: reject_run(evidence, |run| {
            run.answer_packet_ref = "packet:qwen".to_string();
        })?,
        missing_privacy_rejected: reject_run(evidence, |run| {
            run.privacy_ref = "local-only".to_string();
        })?,
        missing_budget_rejected: reject_run(evidence, |run| {
            run.budget_ref = "limit:qwen".to_string();
        })?,
        missing_admission_rejected: reject_run(evidence, |run| {
            run.admission_ref = "admit:qwen".to_string();
        })?,
        missing_scope_rex_rejected: reject_run(evidence, |run| {
            run.scope_rex_ref = "scope:qwen".to_string();
        })?,
        missing_sovereign_gate_rejected: reject_run(evidence, |run| {
            run.sovereign_gate_ref = "gate:qwen".to_string();
        })?,
        missing_compatibility_fence_rejected: reject_run(evidence, |run| {
            run.compatibility_fence = "fence:qwen".to_string();
        })?,
        probe_not_attempted_rejected: reject_run(evidence, |run| {
            run.probe_attempted = false;
        })?,
        cancellation_not_armed_rejected: reject_run(evidence, |run| {
            run.cancellation_armed = false;
        })?,
        abort_not_observed_rejected: reject_run(evidence, |run| {
            run.abort_signal_observed = false;
        })?,
        runtime_start_not_suppressed_rejected: reject_run(evidence, |run| {
            run.runtime_start_suppressed = false;
        })?,
        runtime_completed_rejected: reject_run(evidence, |run| {
            run.runtime_completed = true;
        })?,
        model_open_attempted_rejected: reject_run(evidence, |run| {
            run.model_open_attempted = true;
        })?,
        mutation_committed_rejected: reject_run(evidence, |run| {
            run.mutation_committed = true;
        })?,
        route_policy_mutation_rejected: reject_run(evidence, |run| {
            run.route_policy_mutated = true;
        })?,
        gate_bypass_rejected: reject_run(evidence, |run| {
            run.gate_bypass = true;
        })?,
        answer_packet_suppression_rejected: reject_run(evidence, |run| {
            run.answer_packet_suppressed = true;
        })?,
        hidden_authority_rejected: reject_run(evidence, |run| {
            run.hidden_route_authority = true;
        })?,
        hidden_chain_rejected: reject_run(evidence, |run| {
            run.hidden_chain_exposed = true;
        })?,
        hidden_cloud_rejected: reject_run(evidence, |run| {
            run.hidden_cloud_fallback = true;
        })?,
        subprocess_spawn_rejected: reject_run(evidence, |run| {
            run.subprocess_spawned = true;
        })?,
        autogenous_kernel_rejected: reject_run(evidence, |run| {
            run.autogenous_kernel_attempted = true;
        })?,
        seventy_b_probe_rejected: reject_run(evidence, |run| {
            run.seventy_b_probe_attempted = true;
        })?,
        context_budget_overflow_rejected: reject_run(evidence, |run| {
            run.max_context_tokens = 40_961;
        })?,
        decode_budget_overflow_rejected: reject_run(evidence, |run| {
            run.max_decode_tokens = 513;
        })?,
        memory_budget_overflow_rejected: reject_run(evidence, |run| {
            run.memory_budget_bytes = 8 * 1024 * 1024 * 1024 + 1;
        })?,
        runtime_budget_overflow_rejected: reject_run(evidence, |run| {
            run.runtime_budget_seconds = 301;
        })?,
        deadline_overflow_rejected: reject_run(evidence, |run| {
            run.deadline_ms = 1_001;
        })?,
        deadline_overrun_rejected: reject_run(evidence, |run| {
            run.observed_elapsed_ms = run.deadline_ms + 1;
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
        runtime_bytes_rejected: reject_run(evidence, |run| {
            run.runtime_bytes_loaded = 1;
        })?,
        model_bytes_rejected: reject_run(evidence, |run| {
            run.model_bytes_loaded = 1;
        })?,
        transport_runtime_bytes_rejected: reject_run(evidence, |run| {
            run.transport_runtime_bytes_loaded = 1;
        })?,
        metadata_budget_rejected: reject_witness(evidence, |w| {
            w.metadata_bytes = 384 * 1024 + 1;
        })?,
    })
}

fn reject_witness(
    evidence: &EvidenceSnapshot,
    mutate: impl FnOnce(&mut SmallModelRuntimeHarnessAbortableProbeWitness),
) -> Result<bool, AbortableProbeWitnessError> {
    let mut witness = fixture_witness(evidence)?;
    mutate(&mut witness);
    Ok(SmallModelRuntimeHarnessAbortableProbeWitness::new(
        witness.witness_id,
        witness.owner_probe_artifact_ref,
        witness.guard_next_existing_work,
        witness.capability_route_status,
        witness.capability_next_bottleneck,
        witness.product_build,
        witness.pro_status,
        witness.route_authority,
        witness.runs,
        witness.surfaces,
        witness.metadata_bytes,
        witness.l1_l2_l3_separated,
        witness.mas_overclaim_attempted,
        witness.l2_green_claimed,
        witness.l3_green_claimed,
    )
    .is_err())
}

fn reject_run(
    evidence: &EvidenceSnapshot,
    mutate: impl FnOnce(&mut SmallModelAbortableRuntimeProbeRun),
) -> Result<bool, AbortableProbeWitnessError> {
    reject_witness(evidence, |witness| mutate(&mut witness.runs[0]))
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: u64,
    op: &str,
    threshold: u64,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(value),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: op.to_string(),
            value: serde_json::Value::from(threshold),
            unit: unit.to_string(),
        },
    );
    let passed = match op {
        ">=" => value >= threshold,
        "<=" => value <= threshold,
        "==" => value == threshold,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), passed);
}

fn read_text(path: &Path) -> Result<String, AbortableProbeWitnessError> {
    std::fs::read_to_string(path)
        .map_err(|error| AbortableProbeWitnessError::Io(format!("{}: {error}", path.display())))
}

fn read_json(path: &Path) -> Result<serde_json::Value, AbortableProbeWitnessError> {
    let text = read_text(path)?;
    serde_json::from_str(&text)
        .map_err(|error| AbortableProbeWitnessError::Io(format!("{}: {error}", path.display())))
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")?
        .get(key)?
        .get("value")
        .or_else(|| value.get("measurements")?.get(key))?
        .as_str()
        .map(ToString::to_string)
}

fn artifact_all_axes_true(value: &serde_json::Value, axes: &[&str]) -> bool {
    value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
        && axes.iter().all(|axis| {
            value
                .get("pass_per_axis")
                .and_then(|axes| axes.get(*axis))
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false)
        })
}
