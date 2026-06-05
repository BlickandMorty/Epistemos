//! `falsify_small_model_runtime_harness_logged_runtime_smoke`.
//!
//! Metadata-only failure-path witness for
//! `F-SmallModelRuntimeHarnessLoggedRuntimeSmoke`. It proves the abortable
//! small-model probe path reaches the runtime harness logging boundary, records
//! missing local snapshots visibly, emits rollback/RunEventLog/AnswerPacket
//! evidence, and still refuses runtime/model byte loading or L2/L3 promotion.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, SmallModelLoggedRuntimeSmokePhase, SmallModelLoggedRuntimeSmokeRun,
    SmallModelLoggedRuntimeSmokeSurface, SmallModelRuntimeHarnessLoggedSmokeError,
    SmallModelRuntimeHarnessLoggedSmokeWitness,
    SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallModelRuntimeHarnessLoggedRuntimeSmoke";
const FIXTURE_ID: &str = "small_model_runtime_harness_logged_runtime_smoke_v1";
const COMMAND: &str = "Tools/falsifiers/f_small_model_runtime_harness_logged_runtime_smoke.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_logged_runtime_smoke/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const ABORTABLE_PROBE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_abortable_runtime_probe/result.json";
const LIVING_INDEX_PATH: &str = "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md";
const LATTICE_HTML_PATH: &str = "artifacts/lattice-coordinate-explainer/index.html";
const MLX_RUNTIME_PATH: &str = "Epistemos/Engine/MLXInferenceService.swift";
const SERIAL_CONTROLLER_PATH: &str = "Epistemos/Engine/LocalInferenceSerialController.swift";
const MIN_RUN_COUNT: u64 = 3;
const MIN_SURFACE_COUNT: u64 = 4;
const MIN_REQUIRED_LANE_COUNT: u64 = 3;
const MIN_PHASE_COUNT: u64 = 11;
const MAX_CONTEXT_TOKENS: u64 = 40_960;
const MAX_PROMPT_TOKENS: u64 = 8_192;
const MAX_DECODE_TOKENS: u64 = 512;
const MAX_MEMORY_BUDGET_BYTES: u64 = 8 * 1024 * 1024 * 1024;
const MAX_RUNTIME_SECONDS: u64 = 300;
const MAX_OBSERVED_ELAPSED_MS: u64 = 1_000;
const MAX_METADATA_BYTES: u64 = 448 * 1024;

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-logged-runtime-smoke:witness-error
// Plane: Verification
// Residency: metadata-only logged missing-snapshot rejection taxonomy.
enum LoggedRuntimeSmokeWitnessError {
    Primitive(SmallModelRuntimeHarnessLoggedSmokeError),
    Io(String),
}

impl std::fmt::Display for LoggedRuntimeSmokeWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for LoggedRuntimeSmokeWitnessError {}

impl From<SmallModelRuntimeHarnessLoggedSmokeError> for LoggedRuntimeSmokeWitnessError {
    fn from(value: SmallModelRuntimeHarnessLoggedSmokeError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, LoggedRuntimeSmokeWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fixture_witness(&evidence)?;
    let metrics = witness.metrics();
    let address = witness.address();
    let mut reversed = witness.runs.clone();
    reversed.reverse();
    let deterministic = SmallModelRuntimeHarnessLoggedSmokeWitness::new(
        witness.witness_id.clone(),
        witness.abortable_probe_artifact_ref.clone(),
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
            "upstream_small_model_runtime_harness_abortable_runtime_probe_pass",
            evidence.abortable_probe_pass,
        ),
        (
            "guard_cursor_logged_runtime_smoke_or_advanced",
            evidence.guard_next_existing_work
                == SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_logged_runtime_smoke_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_NEXT_CURSOR,
        ),
        (
            "product_status_research_only",
            witness.product_build == ProductBuild::Pro
                && witness.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_logged_failure_only",
            witness.route_authority == "small_model_runtime_harness_logged_failure_only",
        ),
        (
            "living_index_surface_scan_pass",
            surface_contains(
                &witness,
                "living_index",
                SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_CURSOR,
            ),
        ),
        (
            "lattice_html_surface_scan_pass",
            surface_contains(
                &witness,
                "lattice_html",
                SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_CURSOR,
            ),
        ),
        (
            "north_star_present",
            witness
                .surfaces
                .iter()
                .filter(|surface| {
                    surface.surface_id == "living_index" || surface.surface_id == "lattice_html"
                })
                .all(|surface| {
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
            "abortable_probe_artifact_ref_bound",
            witness
                .abortable_probe_artifact_ref
                .starts_with("artifact:small_model_runtime_harness_abortable_runtime_probe:"),
        ),
        (
            "swift_runtime_surface_bound",
            witness.runs.iter().all(|run| {
                run.swift_runtime_surface_ref
                    .starts_with("source:Epistemos/Engine/MLXInferenceService.swift:")
            }),
        ),
        (
            "serial_controller_bound",
            witness.runs.iter().all(|run| {
                run.serial_controller_ref
                    .starts_with("source:Epistemos/Engine/LocalInferenceSerialController.swift:")
            }),
        ),
        (
            "model_catalog_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.model_catalog_ref.starts_with("model_catalog:")),
        ),
        (
            "model_snapshot_missing_refs_bound",
            witness.runs.iter().all(|run| {
                run.model_snapshot_ref.starts_with("model_snapshot:local:")
                    && run.model_snapshot_ref.ends_with(":missing")
            }),
        ),
        (
            "prompt_envelope_refs_bound",
            witness
                .runs
                .iter()
                .all(|run| run.prompt_envelope_ref.starts_with("prompt_envelope:")),
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
                .all(|run| run.compatibility_fence_ref.starts_with("compat:")),
        ),
        (
            "cancellation_bound",
            witness
                .runs
                .iter()
                .all(|run| run.cancellation_ref.starts_with("cancel:")),
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
            "failure_reason_bound",
            witness.runs.iter().all(|run| {
                run.failure_reason_ref
                    .starts_with("failure_reason:missing_local_snapshot:")
            }),
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
            "runtime_attempt_logged",
            metrics.runtime_attempt_logged_count == metrics.run_count,
        ),
        (
            "missing_snapshot_logged",
            metrics.missing_snapshot_logged_count == metrics.run_count,
        ),
        (
            "snapshot_unavailable_recorded",
            metrics.unavailable_snapshot_count == metrics.run_count,
        ),
        (
            "model_open_not_attempted",
            witness.runs.iter().all(|run| !run.model_open_attempted),
        ),
        (
            "runtime_not_started",
            witness.runs.iter().all(|run| !run.runtime_started),
        ),
        (
            "runtime_not_completed",
            witness.runs.iter().all(|run| !run.runtime_completed),
        ),
        (
            "first_token_not_observed",
            witness.runs.iter().all(|run| !run.first_token_observed),
        ),
        (
            "output_tokens_not_observed",
            witness.runs.iter().all(|run| run.output_token_count == 0),
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
                .runs
                .iter()
                .all(|run| !run.hidden_route_authority_attempted),
        ),
        (
            "no_route_policy_mutation",
            witness
                .runs
                .iter()
                .all(|run| !run.route_policy_mutation_attempted),
        ),
        (
            "no_gate_bypass",
            witness.runs.iter().all(|run| !run.gate_bypass_attempted),
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
            witness
                .runs
                .iter()
                .all(|run| !run.hidden_cloud_fallback_allowed),
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
            witness.runs.iter().all(|run| !run.committed_mutation),
        ),
        ("no_runtime_bytes_loaded", metrics.runtime_bytes_loaded == 0),
        ("no_model_bytes_loaded", metrics.model_bytes_loaded == 0),
        (
            "no_transport_runtime_bytes_loaded",
            metrics.transport_runtime_bytes_loaded == 0,
        ),
        (
            "context_budget_bound",
            witness
                .runs
                .iter()
                .all(|run| u64::from(run.context_tokens) <= MAX_CONTEXT_TOKENS),
        ),
        (
            "prompt_budget_bound",
            witness
                .runs
                .iter()
                .all(|run| u64::from(run.prompt_tokens) <= MAX_PROMPT_TOKENS),
        ),
        (
            "decode_budget_bound",
            witness
                .runs
                .iter()
                .all(|run| u64::from(run.decode_tokens) <= MAX_DECODE_TOKENS),
        ),
        (
            "memory_budget_bound",
            witness
                .runs
                .iter()
                .all(|run| run.memory_budget_bytes <= MAX_MEMORY_BUDGET_BYTES),
        ),
        (
            "runtime_budget_bound",
            witness
                .runs
                .iter()
                .all(|run| u64::from(run.runtime_budget_seconds) <= MAX_RUNTIME_SECONDS),
        ),
        (
            "observed_elapsed_bound",
            u64::from(metrics.max_observed_elapsed_ms) <= MAX_OBSERVED_ELAPSED_MS,
        ),
        (
            "metadata_bound",
            witness.metadata_bytes <= MAX_METADATA_BYTES,
        ),
        (
            "small_model_runtime_harness_logged_runtime_smoke_address_deterministic",
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
            "missing_abortable_probe_artifact_rejected",
            invalid_axes.missing_abortable_probe_artifact_rejected,
        ),
        (
            "missing_swift_runtime_surface_rejected",
            invalid_axes.missing_swift_runtime_surface_rejected,
        ),
        (
            "missing_serial_controller_rejected",
            invalid_axes.missing_serial_controller_rejected,
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
            "missing_failure_reason_rejected",
            invalid_axes.missing_failure_reason_rejected,
        ),
        (
            "runtime_attempt_not_logged_rejected",
            invalid_axes.runtime_attempt_not_logged_rejected,
        ),
        (
            "missing_snapshot_not_logged_rejected",
            invalid_axes.missing_snapshot_not_logged_rejected,
        ),
        (
            "snapshot_availability_overclaim_rejected",
            invalid_axes.snapshot_availability_overclaim_rejected,
        ),
        (
            "model_open_attempted_rejected",
            invalid_axes.model_open_attempted_rejected,
        ),
        (
            "runtime_started_rejected",
            invalid_axes.runtime_started_rejected,
        ),
        (
            "runtime_completed_rejected",
            invalid_axes.runtime_completed_rejected,
        ),
        (
            "first_token_observed_rejected",
            invalid_axes.first_token_observed_rejected,
        ),
        (
            "output_tokens_observed_rejected",
            invalid_axes.output_tokens_observed_rejected,
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
            "prompt_budget_overflow_rejected",
            invalid_axes.prompt_budget_overflow_rejected,
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
            "elapsed_overflow_rejected",
            invalid_axes.elapsed_overflow_rejected,
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
        "runtime_attempt_logged_count",
        metrics.runtime_attempt_logged_count,
        "==",
        metrics.run_count,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_snapshot_logged_count",
        metrics.missing_snapshot_logged_count,
        "==",
        metrics.run_count,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unavailable_snapshot_count",
        metrics.unavailable_snapshot_count,
        "==",
        metrics.run_count,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_open_attempted_count",
        witness
            .runs
            .iter()
            .filter(|run| run.model_open_attempted)
            .count() as u64,
        "==",
        0,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_started_count",
        witness
            .runs
            .iter()
            .filter(|run| run.runtime_started)
            .count() as u64,
        "==",
        0,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_completed_count",
        witness
            .runs
            .iter()
            .filter(|run| run.runtime_completed)
            .count() as u64,
        "==",
        0,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "first_token_observed_count",
        witness
            .runs
            .iter()
            .filter(|run| run.first_token_observed)
            .count() as u64,
        "==",
        0,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "output_token_count",
        witness
            .runs
            .iter()
            .map(|run| u64::from(run.output_token_count))
            .sum(),
        "==",
        0,
        "tokens",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mutation_committed_count",
        witness
            .runs
            .iter()
            .filter(|run| run.committed_mutation)
            .count() as u64,
        "==",
        0,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cloud_fallback_count",
        witness
            .runs
            .iter()
            .filter(|run| run.hidden_cloud_fallback_allowed)
            .count() as u64,
        "==",
        0,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "subprocess_spawn_count",
        witness
            .runs
            .iter()
            .filter(|run| run.subprocess_spawned)
            .count() as u64,
        "==",
        0,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "seventy_b_probe_count",
        witness
            .runs
            .iter()
            .filter(|run| run.seventy_b_probe_attempted)
            .count() as u64,
        "==",
        0,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_context_tokens",
        witness
            .runs
            .iter()
            .map(|run| u64::from(run.context_tokens))
            .max()
            .unwrap_or(0),
        "<=",
        MAX_CONTEXT_TOKENS,
        "tokens",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_prompt_tokens",
        witness
            .runs
            .iter()
            .map(|run| u64::from(run.prompt_tokens))
            .max()
            .unwrap_or(0),
        "<=",
        MAX_PROMPT_TOKENS,
        "tokens",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_decode_tokens",
        witness
            .runs
            .iter()
            .map(|run| u64::from(run.decode_tokens))
            .max()
            .unwrap_or(0),
        "<=",
        MAX_DECODE_TOKENS,
        "tokens",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_memory_budget_bytes",
        witness
            .runs
            .iter()
            .map(|run| run.memory_budget_bytes)
            .max()
            .unwrap_or(0),
        "<=",
        MAX_MEMORY_BUDGET_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_runtime_seconds",
        witness
            .runs
            .iter()
            .map(|run| u64::from(run.runtime_budget_seconds))
            .max()
            .unwrap_or(0),
        "<=",
        MAX_RUNTIME_SECONDS,
        "seconds",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_observed_elapsed_ms",
        u64::from(metrics.max_observed_elapsed_ms),
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
        "small_model_runtime_harness_logged_runtime_smoke_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "small_model_runtime_harness_logged_runtime_smoke_address".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "small_model_runtime_harness_logged_runtime_smoke_address".to_string(),
        true,
    );

    let anomalies = vec![serde_json::json!({
        "kind": "small_model_runtime_harness_logged_runtime_smoke_metadata_only",
        "detail": "The logged runtime smoke proves the runtime harness logs an owner-approved small-model attempt and visible missing-local-snapshot failure with rollback, RunEventLog, AnswerPacket, admission, privacy, and budget evidence. It intentionally opens no runtime/model bytes, emits no first token, and does not promote L2 capability or L3 product runtime."
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
        notes: "metadata-only F-SmallModelRuntimeHarnessLoggedRuntimeSmoke: proves owner-approved abortable small-model smoke reaches the runtime logging boundary and records missing local snapshots visibly; no MLX inference success, first token, runtime/model bytes, route mutation, hidden cloud, MAS overclaim, or L2/L3 promotion."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Clone)]
// UAS: uas:small-model-runtime-harness-logged-runtime-smoke:evidence-snapshot
// Plane: Verification
// Residency: metadata-only snapshot of guard, capability, abortable, and source surfaces.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    abortable_probe_pass: bool,
    living_index: String,
    lattice_html: String,
    mlx_runtime_source: String,
    serial_controller_source: String,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, LoggedRuntimeSmokeWitnessError> {
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        let abortable_probe = read_json(Path::new(ABORTABLE_PROBE_PATH))?;
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
            abortable_probe_pass: artifact_all_axes_true(
                &abortable_probe,
                SMALL_MODEL_RUNTIME_HARNESS_ABORTABLE_RUNTIME_PROBE_AXES,
            ),
            living_index: read_text(Path::new(LIVING_INDEX_PATH))?,
            lattice_html: read_text(Path::new(LATTICE_HTML_PATH))?,
            mlx_runtime_source: read_text(Path::new(MLX_RUNTIME_PATH))?,
            serial_controller_source: read_text(Path::new(SERIAL_CONTROLLER_PATH))?,
        })
    }
}

fn fixture_witness(
    evidence: &EvidenceSnapshot,
) -> Result<SmallModelRuntimeHarnessLoggedSmokeWitness, LoggedRuntimeSmokeWitnessError> {
    let surfaces = vec![
        surface(
            "living_index",
            LIVING_INDEX_PATH,
            evidence.living_index.clone(),
            vec![
                "Epistemos is a local cognitive substrate".to_string(),
                "no claim promotes without visible proof".to_string(),
                SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_CURSOR.to_string(),
                "vault_research_route_with_packetized_mitigation".to_string(),
            ],
        )?,
        surface(
            "lattice_html",
            LATTICE_HTML_PATH,
            evidence.lattice_html.clone(),
            vec![
                "Epistemos is a local cognitive substrate".to_string(),
                "JUNE1-CANON-FUSION-LOCK".to_string(),
                SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_CURSOR.to_string(),
                "vault_research_route_with_packetized_mitigation".to_string(),
            ],
        )?,
        surface(
            "mlx_runtime_source",
            MLX_RUNTIME_PATH,
            evidence.mlx_runtime_source.clone(),
            vec![
                "LocalMLXRuntime".to_string(),
                "generate(".to_string(),
                "MLXInferenceService".to_string(),
            ],
        )?,
        surface(
            "serial_controller_source",
            SERIAL_CONTROLLER_PATH,
            evidence.serial_controller_source.clone(),
            vec![
                "LocalInferenceSerialController".to_string(),
                "beginTurn".to_string(),
                "endTurn".to_string(),
            ],
        )?,
    ];
    let abortable_probe_ref = "artifact:small_model_runtime_harness_abortable_runtime_probe:result";
    let runs = vec![
        run(
            "logged_smoke_qwen3_4b_missing_snapshot",
            "qwen3_small_catalog_smoke",
            abortable_probe_ref,
            "model_catalog:Qwen/Qwen3-4B-MLX-4bit",
            "model_snapshot:local:models--Qwen--Qwen3-4B-MLX-4bit:missing",
            4096,
            512,
            128,
            2 * 1024 * 1024 * 1024,
            60,
            24,
        )?,
        run(
            "logged_smoke_qwen3_thinking_missing_snapshot",
            "local_agent_notes_research_smoke",
            abortable_probe_ref,
            "model_catalog:mlx-community/Qwen3-4B-Thinking-2507-4bit",
            "model_snapshot:local:models--mlx-community--Qwen3-4B-Thinking-2507-4bit:missing",
            8192,
            1024,
            192,
            3 * 1024 * 1024 * 1024,
            90,
            31,
        )?,
        run(
            "logged_smoke_qwen3_coder_missing_snapshot",
            "coding_tool_dry_run_smoke",
            abortable_probe_ref,
            "model_catalog:mlx-community/Qwen3-Coder-Next-4bit",
            "model_snapshot:local:models--mlx-community--Qwen3-Coder-Next-4bit:missing",
            8192,
            1024,
            192,
            4 * 1024 * 1024 * 1024,
            120,
            34,
        )?,
    ];
    let metadata_bytes = runs
        .iter()
        .map(|run| {
            run.run_id.len()
                + run.model_catalog_ref.len()
                + run.model_snapshot_ref.len()
                + run.failure_reason_ref.len()
        })
        .sum::<usize>() as u64
        + 16_384;
    Ok(SmallModelRuntimeHarnessLoggedSmokeWitness::new(
        "small_model_runtime_harness_logged_runtime_smoke_2026_06_05",
        abortable_probe_ref,
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "small_model_runtime_harness_logged_failure_only",
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
    required_markers: Vec<String>,
) -> Result<SmallModelLoggedRuntimeSmokeSurface, LoggedRuntimeSmokeWitnessError> {
    Ok(SmallModelLoggedRuntimeSmokeSurface::new(
        surface_id,
        path,
        observed_text,
        required_markers,
        vec![
            "live 70B is done".to_string(),
            "dense 70B runs comfortably on 16 GB".to_string(),
            "small model runtime is product-live".to_string(),
            "logged runtime smoke makes L2 green".to_string(),
            "hidden cloud fallback is allowed".to_string(),
            "MAS ships live local agent runtime".to_string(),
        ],
    )?)
}

#[allow(clippy::too_many_arguments)]
fn run(
    run_id: &str,
    lane_id: &str,
    abortable_probe_ref: &str,
    model_catalog_ref: &str,
    model_snapshot_ref: &str,
    context_tokens: u32,
    prompt_tokens: u32,
    decode_tokens: u32,
    memory_budget_bytes: u64,
    runtime_budget_seconds: u32,
    observed_elapsed_ms: u32,
) -> Result<SmallModelLoggedRuntimeSmokeRun, LoggedRuntimeSmokeWitnessError> {
    let mut run = SmallModelLoggedRuntimeSmokeRun::new(
        run_id,
        lane_id,
        abortable_probe_ref,
        "source:Epistemos/Engine/MLXInferenceService.swift:LocalMLXRuntime.generate",
        "source:Epistemos/Engine/LocalInferenceSerialController.swift:beginTurn",
        model_catalog_ref,
        model_snapshot_ref,
        format!("prompt_envelope:{lane_id}:visible-no-hidden-chain"),
        format!("admission:{lane_id}:scope-rex-sovereign-gate"),
        format!("scope_rex:{lane_id}:local-small-model-logged-smoke"),
        format!("sovereign_gate:{lane_id}:logged-runtime-smoke"),
        format!("compat:{lane_id}:mlx-small-smoke-v1"),
        format!("cancel:{lane_id}:abortable-probe-lease"),
        format!("rollback:{lane_id}:no-mutation"),
        format!("run_event_log:{lane_id}:missing-local-snapshot"),
        format!("answer_packet:{lane_id}:visible-missing-snapshot"),
        format!("privacy:{lane_id}:local-only-no-cloud-no-chain"),
        format!("budget:{lane_id}:bounded-small-smoke"),
        format!("failure_reason:missing_local_snapshot:{lane_id}"),
        logged_runtime_smoke_phases(),
    )?;
    run.context_tokens = context_tokens;
    run.prompt_tokens = prompt_tokens;
    run.decode_tokens = decode_tokens;
    run.memory_budget_bytes = memory_budget_bytes;
    run.runtime_budget_seconds = runtime_budget_seconds;
    run.observed_elapsed_ms = observed_elapsed_ms;
    run.validate()?;
    Ok(run)
}

fn logged_runtime_smoke_phases() -> Vec<SmallModelLoggedRuntimeSmokePhase> {
    [
        SmallModelLoggedRuntimeSmokePhase::AbortableArtifactBound,
        SmallModelLoggedRuntimeSmokePhase::SwiftRuntimeSurfaceBound,
        SmallModelLoggedRuntimeSmokePhase::SerialControllerBound,
        SmallModelLoggedRuntimeSmokePhase::LocalSnapshotAvailabilityChecked,
        SmallModelLoggedRuntimeSmokePhase::RuntimeAttemptLogged,
        SmallModelLoggedRuntimeSmokePhase::MissingSnapshotFailureLogged,
        SmallModelLoggedRuntimeSmokePhase::RollbackVerified,
        SmallModelLoggedRuntimeSmokePhase::RunEventLogged,
        SmallModelLoggedRuntimeSmokePhase::AnswerPacketDrafted,
        SmallModelLoggedRuntimeSmokePhase::MutationReviewPassed,
        SmallModelLoggedRuntimeSmokePhase::EvidenceReviewPending,
    ]
    .to_vec()
}

#[derive(Default)]
// UAS: uas:small-model-runtime-harness-logged-runtime-smoke:invalid-axes
// Plane: Verification
// Residency: metadata-only invalid-fixture rejection coverage.
struct InvalidAxes {
    missing_required_lane_rejected: bool,
    duplicate_run_rejected: bool,
    missing_phase_rejected: bool,
    missing_abortable_probe_artifact_rejected: bool,
    missing_swift_runtime_surface_rejected: bool,
    missing_serial_controller_rejected: bool,
    missing_model_catalog_rejected: bool,
    missing_model_snapshot_rejected: bool,
    missing_prompt_envelope_rejected: bool,
    missing_admission_rejected: bool,
    missing_scope_rex_rejected: bool,
    missing_sovereign_gate_rejected: bool,
    missing_compatibility_fence_rejected: bool,
    missing_cancellation_rejected: bool,
    missing_rollback_rejected: bool,
    missing_run_event_log_rejected: bool,
    missing_answer_packet_rejected: bool,
    missing_privacy_rejected: bool,
    missing_budget_rejected: bool,
    missing_failure_reason_rejected: bool,
    runtime_attempt_not_logged_rejected: bool,
    missing_snapshot_not_logged_rejected: bool,
    snapshot_availability_overclaim_rejected: bool,
    model_open_attempted_rejected: bool,
    runtime_started_rejected: bool,
    runtime_completed_rejected: bool,
    first_token_observed_rejected: bool,
    output_tokens_observed_rejected: bool,
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
    prompt_budget_overflow_rejected: bool,
    decode_budget_overflow_rejected: bool,
    memory_budget_overflow_rejected: bool,
    runtime_budget_overflow_rejected: bool,
    elapsed_overflow_rejected: bool,
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
) -> Result<InvalidAxes, LoggedRuntimeSmokeWitnessError> {
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
                .retain(|phase| phase != &SmallModelLoggedRuntimeSmokePhase::RunEventLogged);
        })?,
        missing_abortable_probe_artifact_rejected: reject_run(evidence, |run| {
            run.abortable_probe_artifact_ref = "artifact:missing:result".to_string();
        })?,
        missing_swift_runtime_surface_rejected: reject_run(evidence, |run| {
            run.swift_runtime_surface_ref = "source:swift:runtime".to_string();
        })?,
        missing_serial_controller_rejected: reject_run(evidence, |run| {
            run.serial_controller_ref = "source:swift:controller".to_string();
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
            run.compatibility_fence_ref = "fence:qwen".to_string();
        })?,
        missing_cancellation_rejected: reject_run(evidence, |run| {
            run.cancellation_ref = "stop:qwen".to_string();
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
        missing_failure_reason_rejected: reject_run(evidence, |run| {
            run.failure_reason_ref = "missing_snapshot:qwen".to_string();
        })?,
        runtime_attempt_not_logged_rejected: reject_run(evidence, |run| {
            run.runtime_attempt_logged = false;
        })?,
        missing_snapshot_not_logged_rejected: reject_run(evidence, |run| {
            run.missing_snapshot_logged = false;
        })?,
        snapshot_availability_overclaim_rejected: reject_run(evidence, |run| {
            run.model_snapshot_available = true;
        })?,
        model_open_attempted_rejected: reject_run(evidence, |run| {
            run.model_open_attempted = true;
        })?,
        runtime_started_rejected: reject_run(evidence, |run| {
            run.runtime_started = true;
        })?,
        runtime_completed_rejected: reject_run(evidence, |run| {
            run.runtime_completed = true;
        })?,
        first_token_observed_rejected: reject_run(evidence, |run| {
            run.first_token_observed = true;
        })?,
        output_tokens_observed_rejected: reject_run(evidence, |run| {
            run.output_token_count = 1;
        })?,
        mutation_committed_rejected: reject_run(evidence, |run| {
            run.committed_mutation = true;
        })?,
        route_policy_mutation_rejected: reject_run(evidence, |run| {
            run.route_policy_mutation_attempted = true;
        })?,
        gate_bypass_rejected: reject_run(evidence, |run| {
            run.gate_bypass_attempted = true;
        })?,
        answer_packet_suppression_rejected: reject_run(evidence, |run| {
            run.answer_packet_suppressed = true;
        })?,
        hidden_authority_rejected: reject_run(evidence, |run| {
            run.hidden_route_authority_attempted = true;
        })?,
        hidden_chain_rejected: reject_run(evidence, |run| {
            run.hidden_chain_exposed = true;
        })?,
        hidden_cloud_rejected: reject_run(evidence, |run| {
            run.hidden_cloud_fallback_allowed = true;
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
            run.context_tokens = 40_961;
        })?,
        prompt_budget_overflow_rejected: reject_run(evidence, |run| {
            run.prompt_tokens = 8_193;
        })?,
        decode_budget_overflow_rejected: reject_run(evidence, |run| {
            run.decode_tokens = 513;
        })?,
        memory_budget_overflow_rejected: reject_run(evidence, |run| {
            run.memory_budget_bytes = 8 * 1024 * 1024 * 1024 + 1;
        })?,
        runtime_budget_overflow_rejected: reject_run(evidence, |run| {
            run.runtime_budget_seconds = 301;
        })?,
        elapsed_overflow_rejected: reject_run(evidence, |run| {
            run.observed_elapsed_ms = 1_001;
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
            w.metadata_bytes = 448 * 1024 + 1;
        })?,
    })
}

fn reject_witness(
    evidence: &EvidenceSnapshot,
    mutate: impl FnOnce(&mut SmallModelRuntimeHarnessLoggedSmokeWitness),
) -> Result<bool, LoggedRuntimeSmokeWitnessError> {
    let mut witness = fixture_witness(evidence)?;
    mutate(&mut witness);
    Ok(SmallModelRuntimeHarnessLoggedSmokeWitness::new(
        witness.witness_id,
        witness.abortable_probe_artifact_ref,
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
    mutate: impl FnOnce(&mut SmallModelLoggedRuntimeSmokeRun),
) -> Result<bool, LoggedRuntimeSmokeWitnessError> {
    reject_witness(evidence, |witness| mutate(&mut witness.runs[0]))
}

fn surface_contains(
    witness: &SmallModelRuntimeHarnessLoggedSmokeWitness,
    surface_id: &str,
    marker: &str,
) -> bool {
    witness.surfaces.iter().any(|surface| {
        surface.surface_id == surface_id
            && surface.observed_text.contains(marker)
            && surface
                .observed_text
                .contains("vault_research_route_with_packetized_mitigation")
    })
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

fn read_text(path: &Path) -> Result<String, LoggedRuntimeSmokeWitnessError> {
    std::fs::read_to_string(path)
        .map_err(|error| LoggedRuntimeSmokeWitnessError::Io(format!("{}: {error}", path.display())))
}

fn read_json(path: &Path) -> Result<serde_json::Value, LoggedRuntimeSmokeWitnessError> {
    let text = read_text(path)?;
    serde_json::from_str(&text)
        .map_err(|error| LoggedRuntimeSmokeWitnessError::Io(format!("{}: {error}", path.display())))
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

#[allow(dead_code)]
fn _all_phase_tags_are_unique() -> bool {
    logged_runtime_smoke_phases()
        .into_iter()
        .map(|phase| phase.tag())
        .collect::<BTreeSet<_>>()
        .len()
        == MIN_PHASE_COUNT as usize
}
