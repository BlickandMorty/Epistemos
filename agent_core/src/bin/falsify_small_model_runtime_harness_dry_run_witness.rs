//! `falsify_small_model_runtime_harness_dry_run_witness`.
//!
//! Metadata-only witness for `F-SmallModelRuntimeHarnessDryRunWitness`. It
//! proves the small local-model harness can replay a runtime-shaped dry-run
//! transcript with admission, serialized executor, cancellation, rollback,
//! RunEventLog, AnswerPacket, privacy, and budget fences while loading zero
//! runtime/model/transport bytes and promoting neither L2 nor L3.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, SmallModelDryRunPhase, SmallModelDryRunRecord,
    SmallModelDryRunSurface, SmallModelRuntimeHarnessDryRunError,
    SmallModelRuntimeHarnessDryRunWitness, SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallModelRuntimeHarnessDryRunWitness";
const FIXTURE_ID: &str = "small_model_runtime_harness_dry_run_witness_v1";
const COMMAND: &str = "Tools/falsifiers/f_small_model_runtime_harness_dry_run_witness.sh";
const RESULT: &str = "artifacts/falsifiers/small_model_runtime_harness_dry_run_witness/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const SAFETY_PLAN_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_safety_plan/result.json";
const LIVING_INDEX_PATH: &str = "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md";
const LATTICE_HTML_PATH: &str = "artifacts/lattice-coordinate-explainer/index.html";
const MIN_RECORD_COUNT: u64 = 3;
const MIN_SURFACE_COUNT: u64 = 2;
const MIN_REQUIRED_RECORD_COUNT: u64 = 3;
const MIN_PHASE_COUNT: u64 = 10;
const MAX_CONTEXT_TOKENS: u64 = 40_960;
const MAX_PROMPT_TOKENS: u64 = 8_192;
const MAX_DECODE_TOKENS: u64 = 512;
const MAX_MEMORY_BUDGET_BYTES: u64 = 8 * 1024 * 1024 * 1024;
const MAX_RUNTIME_SECONDS: u64 = 300;
const MAX_METADATA_BYTES: u64 = 320 * 1024;

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-dry-run:witness-error
// Plane: Verification
// Residency: metadata-only dry-run rejection taxonomy.
enum HarnessDryRunWitnessError {
    Primitive(SmallModelRuntimeHarnessDryRunError),
    Io(String),
}

impl std::fmt::Display for HarnessDryRunWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for HarnessDryRunWitnessError {}

impl From<SmallModelRuntimeHarnessDryRunError> for HarnessDryRunWitnessError {
    fn from(value: SmallModelRuntimeHarnessDryRunError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, HarnessDryRunWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fixture_witness(&evidence)?;
    let metrics = witness.metrics();
    let address = witness.address();
    let mut reversed = witness.records.clone();
    reversed.reverse();
    let deterministic = SmallModelRuntimeHarnessDryRunWitness::new(
        witness.witness_id.clone(),
        witness.safety_plan_artifact_ref.clone(),
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
            "upstream_small_model_runtime_harness_safety_plan_pass",
            evidence.safety_plan_pass,
        ),
        (
            "guard_cursor_dry_run_or_advanced",
            evidence.guard_next_existing_work == SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_dry_run_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_NEXT_CURSOR,
        ),
        (
            "product_status_research_only",
            witness.product_build == ProductBuild::Pro
                && witness.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_dry_run_only",
            witness.route_authority == "small_model_runtime_harness_dry_run_witness_only",
        ),
        (
            "living_index_surface_scan_pass",
            witness.surfaces.iter().any(|surface| {
                surface.surface_id == "living_index"
                    && surface
                        .observed_text
                        .contains(SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR)
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
                        .contains(SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR)
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
            "safety_plan_artifact_ref_bound",
            witness
                .safety_plan_artifact_ref
                .starts_with("artifact:small_model_runtime_harness_safety_plan:"),
        ),
        (
            "required_records_bound",
            metrics.required_record_count >= MIN_REQUIRED_RECORD_COUNT,
        ),
        (
            "required_phases_bound",
            metrics.phase_count >= MIN_PHASE_COUNT,
        ),
        (
            "catalog_refs_bound",
            witness
                .records
                .iter()
                .all(|record| record.catalog_ref.starts_with("model_catalog:")),
        ),
        (
            "prompt_envelope_refs_bound",
            witness
                .records
                .iter()
                .all(|record| record.prompt_envelope_ref.starts_with("prompt_envelope:")),
        ),
        (
            "serialized_executor_bound",
            witness.records.iter().all(|record| {
                record
                    .serialized_executor_ref
                    .starts_with("serialized_executor:")
            }),
        ),
        (
            "cancellation_bound",
            witness
                .records
                .iter()
                .all(|record| record.cancellation_ref.starts_with("cancel:")),
        ),
        (
            "rollback_bound",
            witness
                .records
                .iter()
                .all(|record| record.rollback_ref.starts_with("rollback:")),
        ),
        (
            "run_event_log_bound",
            witness
                .records
                .iter()
                .all(|record| record.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "answer_packet_bound",
            witness
                .records
                .iter()
                .all(|record| record.answer_packet_ref.starts_with("answer_packet:")),
        ),
        (
            "admission_bound",
            witness
                .records
                .iter()
                .all(|record| record.admission_ref.starts_with("admission:")),
        ),
        (
            "scope_rex_bound",
            witness
                .records
                .iter()
                .all(|record| record.scope_rex_ref.starts_with("scope_rex:")),
        ),
        (
            "sovereign_gate_bound",
            witness
                .records
                .iter()
                .all(|record| record.sovereign_gate_ref.starts_with("sovereign_gate:")),
        ),
        (
            "compatibility_fence_bound",
            witness
                .records
                .iter()
                .all(|record| record.compatibility_fence.starts_with("compat:")),
        ),
        (
            "privacy_fence_bound",
            witness
                .records
                .iter()
                .all(|record| record.privacy_ref.starts_with("privacy:")),
        ),
        (
            "budget_refs_bound",
            witness
                .records
                .iter()
                .all(|record| record.budget_ref.starts_with("budget:")),
        ),
        (
            "dry_run_only_bound",
            witness.records.iter().all(|record| record.dry_run_only),
        ),
        ("l1_l2_l3_separation_bound", witness.l1_l2_l3_separated),
        ("mas_floor_preserved", !witness.mas_overclaim_attempted),
        ("no_l2_green_claim", !witness.l2_green_claimed),
        ("no_l3_green_claim", !witness.l3_green_claimed),
        (
            "no_hidden_route_authority",
            witness
                .records
                .iter()
                .all(|record| !record.hidden_route_authority),
        ),
        (
            "no_route_policy_mutation",
            metrics.route_policy_mutation_count == 0,
        ),
        (
            "no_gate_bypass",
            witness.records.iter().all(|record| !record.gate_bypass),
        ),
        (
            "no_answer_packet_suppression",
            witness
                .records
                .iter()
                .all(|record| !record.answer_packet_suppressed),
        ),
        (
            "no_hidden_chain",
            witness
                .records
                .iter()
                .all(|record| !record.hidden_chain_exposed),
        ),
        (
            "no_hidden_cloud_fallback",
            witness
                .records
                .iter()
                .all(|record| !record.hidden_cloud_fallback),
        ),
        (
            "no_subprocess_spawn",
            witness
                .records
                .iter()
                .all(|record| !record.subprocess_spawned),
        ),
        (
            "no_autogenous_kernel_attempt",
            witness
                .records
                .iter()
                .all(|record| !record.autogenous_kernel_attempted),
        ),
        (
            "no_70b_probe_attempt",
            witness
                .records
                .iter()
                .all(|record| !record.seventy_b_probe_attempted),
        ),
        (
            "no_runtime_probe_enabled",
            metrics.runtime_probe_enabled_count == 0,
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
            u64::from(metrics.max_context_tokens) <= MAX_CONTEXT_TOKENS,
        ),
        (
            "prompt_budget_bound",
            u64::from(metrics.max_prompt_tokens) <= MAX_PROMPT_TOKENS,
        ),
        (
            "decode_budget_bound",
            u64::from(metrics.max_decode_tokens) <= MAX_DECODE_TOKENS,
        ),
        (
            "memory_budget_bound",
            metrics.max_memory_budget_bytes <= MAX_MEMORY_BUDGET_BYTES,
        ),
        (
            "runtime_budget_bound",
            u64::from(metrics.max_runtime_seconds) <= MAX_RUNTIME_SECONDS,
        ),
        (
            "metadata_bound",
            metrics.metadata_bytes <= MAX_METADATA_BYTES,
        ),
        (
            "small_model_runtime_harness_dry_run_witness_address_deterministic",
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
        "record_count",
        metrics.record_count,
        MIN_RECORD_COUNT,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "surface_count",
        metrics.surface_count,
        MIN_SURFACE_COUNT,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_record_count",
        metrics.required_record_count,
        MIN_REQUIRED_RECORD_COUNT,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "phase_count",
        metrics.phase_count,
        MIN_PHASE_COUNT,
        "count",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_context_tokens",
        u64::from(metrics.max_context_tokens),
        MAX_CONTEXT_TOKENS,
        "tokens",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_prompt_tokens",
        u64::from(metrics.max_prompt_tokens),
        MAX_PROMPT_TOKENS,
        "tokens",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_decode_tokens",
        u64::from(metrics.max_decode_tokens),
        MAX_DECODE_TOKENS,
        "tokens",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_memory_budget_bytes",
        metrics.max_memory_budget_bytes,
        MAX_MEMORY_BUDGET_BYTES,
        "bytes",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_runtime_seconds",
        u64::from(metrics.max_runtime_seconds),
        MAX_RUNTIME_SECONDS,
        "seconds",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_probe_enabled_count",
        metrics.runtime_probe_enabled_count,
        0,
        "count",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mutation_committed_count",
        metrics.mutation_committed_count,
        0,
        "count",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "route_policy_mutation_count",
        metrics.route_policy_mutation_count,
        0,
        "count",
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
        "transport_runtime_bytes_loaded",
        metrics.transport_runtime_bytes_loaded,
        0,
        "bytes",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes",
        metrics.metadata_bytes,
        MAX_METADATA_BYTES,
        "bytes",
    );
    measurements.insert(
        "small_model_runtime_harness_dry_run_witness_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address),
            unit: "address".to_string(),
        },
    );
    measurements.insert(
        "next_safe_unit".to_string(),
        Measurement {
            value: serde_json::Value::String(
                SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_NEXT_CURSOR.to_string(),
            ),
            unit: "cursor".to_string(),
        },
    );

    let mut anomalies = vec![serde_json::json!({
        "kind": "runtime_deferred",
        "detail": "Small-model runtime harness dry-run witness is metadata-only. It replays runtime-shaped evidence but loads no MLX/model/runtime bytes; the next unit is owner-approved runtime probe gating, not product promotion."
    })];
    if evidence.capability_overall_pass {
        anomalies.push(serde_json::json!({
            "kind": "unexpected_l2_green",
            "detail": "Dry-run witness expected the capability kernel to remain red until runtime and L3 witnesses pass."
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
        notes: "metadata-only F-SmallModelRuntimeHarnessDryRunWitness: proves the local small-model harness dry-run transcript is safety-plan-bound, serialized, abortable, rollback-backed, RunEventLog/AnswerPacket-visible, privacy-fenced, mutation-free, MAS-honest, and zero-runtime-byte before any owner-approved MLX runtime probe."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-dry-run:evidence-snapshot
// Plane: Verification
// Residency: metadata-only upstream artifact and S0 surface reader.
struct EvidenceSnapshot {
    safety_plan_pass: bool,
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    living_index_text: String,
    lattice_html_text: String,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, HarnessDryRunWitnessError> {
        let safety_plan = read_json(Path::new(SAFETY_PLAN_PATH))?;
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        Ok(Self {
            safety_plan_pass: artifact_all_axes_true(
                &safety_plan,
                SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_AXES,
            ),
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_else(|| "missing_guard_next_existing_work".to_string()),
            capability_overall_pass: artifact_overall_pass(&capability),
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_else(|| "missing_capability_route_status".to_string()),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_else(|| "missing_capability_next_bottleneck".to_string()),
            living_index_text: read_text(Path::new(LIVING_INDEX_PATH))?,
            lattice_html_text: read_text(Path::new(LATTICE_HTML_PATH))?,
        })
    }
}

fn fixture_witness(
    evidence: &EvidenceSnapshot,
) -> Result<SmallModelRuntimeHarnessDryRunWitness, HarnessDryRunWitnessError> {
    Ok(SmallModelRuntimeHarnessDryRunWitness::new(
        "small_model_runtime_harness_dry_run_witness_2026_06_05",
        "artifact:small_model_runtime_harness_safety_plan:result",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "small_model_runtime_harness_dry_run_witness_only",
        dry_run_records()?,
        dry_run_surfaces(evidence)?,
        128 * 1024,
        true,
        false,
        false,
        false,
    )?)
}

fn dry_run_phases() -> BTreeSet<SmallModelDryRunPhase> {
    BTreeSet::from([
        SmallModelDryRunPhase::CatalogResolved,
        SmallModelDryRunPhase::PromptEnvelopeCompiled,
        SmallModelDryRunPhase::AdmissionChecked,
        SmallModelDryRunPhase::ExecutorReserved,
        SmallModelDryRunPhase::CancellationArmed,
        SmallModelDryRunPhase::RollbackCheckpointRecorded,
        SmallModelDryRunPhase::RunEventLogged,
        SmallModelDryRunPhase::AnswerPacketDrafted,
        SmallModelDryRunPhase::DryRunCompleted,
        SmallModelDryRunPhase::EvidenceReviewed,
    ])
}

fn dry_run_surfaces(
    evidence: &EvidenceSnapshot,
) -> Result<Vec<SmallModelDryRunSurface>, HarnessDryRunWitnessError> {
    let required = vec![
        "Epistemos is a local cognitive substrate".to_string(),
        "no claim promotes without visible proof".to_string(),
        SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_CURSOR.to_string(),
        "vault_research_route_with_packetized_mitigation".to_string(),
        "small-model runtime harness dry-run witness".to_string(),
    ];
    let forbidden = vec![
        "small model dry-run makes product green".to_string(),
        "MLX runtime probe executed".to_string(),
        "runtime bytes loaded in dry run".to_string(),
        "model bytes loaded in dry run".to_string(),
        "MAS ships small-model agent runtime".to_string(),
        "dry-run permits 70B probe".to_string(),
        "hidden cloud fallback allowed".to_string(),
    ];
    Ok(vec![
        SmallModelDryRunSurface::new(
            "living_index",
            LIVING_INDEX_PATH,
            required.clone(),
            forbidden.clone(),
            evidence.living_index_text.clone(),
        )?,
        SmallModelDryRunSurface::new(
            "lattice_html",
            LATTICE_HTML_PATH,
            required,
            forbidden,
            evidence.lattice_html_text.clone(),
        )?,
    ])
}

fn dry_run_records() -> Result<Vec<SmallModelDryRunRecord>, HarnessDryRunWitnessError> {
    Ok(vec![
        record("qwen3_small_catalog_smoke", "research_notes_coding")?,
        record(
            "local_agent_notes_research_smoke",
            "note_context_agentic_loop",
        )?,
        record("coding_tool_dry_run_smoke", "coding_tool_call_dry_run")?,
    ])
}

fn record(id: &str, role: &str) -> Result<SmallModelDryRunRecord, HarnessDryRunWitnessError> {
    Ok(SmallModelDryRunRecord::new(
        format!("dry_run:{id}"),
        id,
        role,
        format!("model_catalog:{id}:mlx-small"),
        format!("prompt_envelope:{id}:dry-run"),
        format!("admission:{id}:dry-run"),
        format!("scope_rex:{id}:dry-run"),
        format!("sovereign_gate:{id}:dry-run"),
        format!("compat:{id}:dry-run:v1"),
        format!("serialized_executor:{id}:mlx"),
        format!("cancel:{id}:owner-abort"),
        format!("rollback:{id}:no-state-mutation"),
        format!("run_event_log:{id}:dry-run"),
        format!("answer_packet:{id}:dry-run"),
        format!("privacy:{id}:local-only"),
        format!("budget:{id}:dry-run"),
        dry_run_phases(),
        40960,
        4096,
        384,
        4 * 1024 * 1024 * 1024,
        180,
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
        "dry_run_passed_no_runtime",
    )?)
}

fn invalid_fixture_axes(
    evidence: &EvidenceSnapshot,
) -> Result<Vec<(&'static str, bool)>, HarnessDryRunWitnessError> {
    let witness = fixture_witness(evidence)?;
    let mut missing_record = witness.records.clone();
    missing_record.retain(|record| record.lane_id != "coding_tool_dry_run_smoke");
    let duplicate_record = vec![
        record("qwen3_small_catalog_smoke", "research_notes_coding")?,
        record("qwen3_small_catalog_smoke", "research_notes_coding")?,
        record(
            "local_agent_notes_research_smoke",
            "note_context_agentic_loop",
        )?,
        record("coding_tool_dry_run_smoke", "coding_tool_call_dry_run")?,
    ];
    Ok(vec![
        (
            "missing_required_record_rejected",
            witness_with_records(evidence, missing_record)?.is_err(),
        ),
        (
            "duplicate_record_rejected",
            witness_with_records(evidence, duplicate_record)?.is_err(),
        ),
        (
            "missing_phase_rejected",
            invalid_record(evidence, |record| {
                record
                    .phases
                    .remove(&SmallModelDryRunPhase::DryRunCompleted);
            })?
            .is_err(),
        ),
        (
            "missing_prompt_envelope_rejected",
            invalid_record(evidence, |record| {
                record.prompt_envelope_ref = "missing".to_string()
            })?
            .is_err(),
        ),
        (
            "missing_serialized_executor_rejected",
            invalid_record(evidence, |record| {
                record.serialized_executor_ref = "missing".to_string();
            })?
            .is_err(),
        ),
        (
            "missing_cancellation_rejected",
            invalid_record(evidence, |record| {
                record.cancellation_ref = "missing".to_string()
            })?
            .is_err(),
        ),
        (
            "missing_rollback_rejected",
            invalid_record(evidence, |record| {
                record.rollback_ref = "missing".to_string()
            })?
            .is_err(),
        ),
        (
            "missing_run_event_log_rejected",
            invalid_record(evidence, |record| {
                record.run_event_log_ref = "missing".to_string()
            })?
            .is_err(),
        ),
        (
            "missing_answer_packet_rejected",
            invalid_record(evidence, |record| {
                record.answer_packet_ref = "missing".to_string()
            })?
            .is_err(),
        ),
        (
            "missing_privacy_rejected",
            invalid_record(evidence, |record| {
                record.privacy_ref = "missing".to_string()
            })?
            .is_err(),
        ),
        (
            "missing_budget_rejected",
            invalid_record(evidence, |record| record.budget_ref = "missing".to_string())?.is_err(),
        ),
        (
            "missing_admission_rejected",
            invalid_record(evidence, |record| {
                record.admission_ref = "missing".to_string()
            })?
            .is_err(),
        ),
        (
            "missing_scope_rex_rejected",
            invalid_record(evidence, |record| {
                record.scope_rex_ref = "missing".to_string()
            })?
            .is_err(),
        ),
        (
            "missing_sovereign_gate_rejected",
            invalid_record(evidence, |record| {
                record.sovereign_gate_ref = "missing".to_string()
            })?
            .is_err(),
        ),
        (
            "missing_compatibility_fence_rejected",
            invalid_record(evidence, |record| {
                record.compatibility_fence = "missing".to_string()
            })?
            .is_err(),
        ),
        (
            "dry_run_only_missing_rejected",
            invalid_record(evidence, |record| record.dry_run_only = false)?.is_err(),
        ),
        (
            "runtime_probe_enabled_rejected",
            invalid_record(evidence, |record| record.runtime_probe_enabled = true)?.is_err(),
        ),
        (
            "mutation_committed_rejected",
            invalid_record(evidence, |record| record.mutation_committed = true)?.is_err(),
        ),
        (
            "route_policy_mutation_rejected",
            invalid_record(evidence, |record| record.route_policy_mutated = true)?.is_err(),
        ),
        (
            "gate_bypass_rejected",
            invalid_record(evidence, |record| record.gate_bypass = true)?.is_err(),
        ),
        (
            "answer_packet_suppression_rejected",
            invalid_record(evidence, |record| record.answer_packet_suppressed = true)?.is_err(),
        ),
        (
            "hidden_authority_rejected",
            invalid_record(evidence, |record| record.hidden_route_authority = true)?.is_err(),
        ),
        (
            "hidden_chain_rejected",
            invalid_record(evidence, |record| record.hidden_chain_exposed = true)?.is_err(),
        ),
        (
            "hidden_cloud_rejected",
            invalid_record(evidence, |record| record.hidden_cloud_fallback = true)?.is_err(),
        ),
        (
            "subprocess_spawn_rejected",
            invalid_record(evidence, |record| record.subprocess_spawned = true)?.is_err(),
        ),
        (
            "autogenous_kernel_rejected",
            invalid_record(evidence, |record| record.autogenous_kernel_attempted = true)?.is_err(),
        ),
        (
            "seventy_b_probe_rejected",
            invalid_record(evidence, |record| record.seventy_b_probe_attempted = true)?.is_err(),
        ),
        (
            "context_budget_overflow_rejected",
            invalid_record(evidence, |record| record.max_context_tokens = 40_961)?.is_err(),
        ),
        (
            "decode_budget_overflow_rejected",
            invalid_record(evidence, |record| record.max_decode_tokens = 513)?.is_err(),
        ),
        (
            "memory_budget_overflow_rejected",
            invalid_record(evidence, |record| {
                record.memory_budget_bytes = 9 * 1024 * 1024 * 1024
            })?
            .is_err(),
        ),
        (
            "runtime_budget_overflow_rejected",
            invalid_record(evidence, |record| record.runtime_budget_seconds = 301)?.is_err(),
        ),
        (
            "mas_overclaim_rejected",
            witness_with_flags(evidence, true, false, false, 128 * 1024)?.is_err(),
        ),
        (
            "l2_green_claim_rejected",
            witness_with_flags(evidence, false, true, false, 128 * 1024)?.is_err(),
        ),
        (
            "l3_green_claim_rejected",
            witness_with_flags(evidence, false, false, true, 128 * 1024)?.is_err(),
        ),
        (
            "runtime_bytes_rejected",
            invalid_record(evidence, |record| record.runtime_bytes_loaded = 1)?.is_err(),
        ),
        (
            "model_bytes_rejected",
            invalid_record(evidence, |record| record.model_bytes_loaded = 1)?.is_err(),
        ),
        (
            "transport_runtime_bytes_rejected",
            invalid_record(evidence, |record| record.transport_runtime_bytes_loaded = 1)?.is_err(),
        ),
        (
            "metadata_budget_rejected",
            witness_with_flags(evidence, false, false, false, MAX_METADATA_BYTES + 1)?.is_err(),
        ),
    ])
}

fn invalid_record(
    evidence: &EvidenceSnapshot,
    mutate: impl FnOnce(&mut SmallModelDryRunRecord),
) -> Result<
    Result<SmallModelRuntimeHarnessDryRunWitness, SmallModelRuntimeHarnessDryRunError>,
    HarnessDryRunWitnessError,
> {
    let mut records = dry_run_records()?;
    if let Some(record) = records
        .iter_mut()
        .find(|record| record.lane_id == "coding_tool_dry_run_smoke")
    {
        mutate(record);
    }
    witness_with_records(evidence, records)
}

fn witness_with_records(
    evidence: &EvidenceSnapshot,
    records: Vec<SmallModelDryRunRecord>,
) -> Result<
    Result<SmallModelRuntimeHarnessDryRunWitness, SmallModelRuntimeHarnessDryRunError>,
    HarnessDryRunWitnessError,
> {
    Ok(SmallModelRuntimeHarnessDryRunWitness::new(
        "small_model_runtime_harness_dry_run_witness_2026_06_05",
        "artifact:small_model_runtime_harness_safety_plan:result",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "small_model_runtime_harness_dry_run_witness_only",
        records,
        dry_run_surfaces(evidence)?,
        128 * 1024,
        true,
        false,
        false,
        false,
    ))
}

fn witness_with_flags(
    evidence: &EvidenceSnapshot,
    mas_overclaim: bool,
    l2_green: bool,
    l3_green: bool,
    metadata_bytes: u64,
) -> Result<
    Result<SmallModelRuntimeHarnessDryRunWitness, SmallModelRuntimeHarnessDryRunError>,
    HarnessDryRunWitnessError,
> {
    Ok(SmallModelRuntimeHarnessDryRunWitness::new(
        "small_model_runtime_harness_dry_run_witness_2026_06_05",
        "artifact:small_model_runtime_harness_safety_plan:result",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "small_model_runtime_harness_dry_run_witness_only",
        dry_run_records()?,
        dry_run_surfaces(evidence)?,
        metadata_bytes,
        true,
        mas_overclaim,
        l2_green,
        l3_green,
    ))
}

fn read_json(path: &Path) -> Result<Option<serde_json::Value>, HarnessDryRunWitnessError> {
    match std::fs::read_to_string(path) {
        Ok(text) => serde_json::from_str(&text)
            .map(Some)
            .map_err(|error| HarnessDryRunWitnessError::Io(format!("{}: {error}", path.display()))),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(error) => Err(HarnessDryRunWitnessError::Io(format!(
            "{}: {error}",
            path.display()
        ))),
    }
}

fn read_text(path: &Path) -> Result<String, HarnessDryRunWitnessError> {
    std::fs::read_to_string(path)
        .map_err(|error| HarnessDryRunWitnessError::Io(format!("{}: {error}", path.display())))
}

fn artifact_all_axes_true(value: &Option<serde_json::Value>, axes: &[&str]) -> bool {
    value.as_ref().is_some_and(|value| {
        artifact_overall_pass_value(value)
            && axes
                .iter()
                .all(|axis| artifact_axis_true_value(value, axis))
    })
}

fn artifact_overall_pass(value: &Option<serde_json::Value>) -> bool {
    value.as_ref().is_some_and(artifact_overall_pass_value)
}

fn artifact_overall_pass_value(value: &serde_json::Value) -> bool {
    value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
}

fn artifact_axis_true_value(value: &serde_json::Value, axis: &str) -> bool {
    value
        .get("pass_per_axis")
        .and_then(|axes| axes.get(axis))
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
}

fn measurement_string(value: &Option<serde_json::Value>, key: &str) -> Option<String> {
    value
        .as_ref()?
        .get("measurements")?
        .get(key)?
        .get("value")?
        .as_str()
        .map(ToString::to_string)
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

#[cfg(test)]
mod tests {
    use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_AXES;

    #[test]
    fn axis_contract_matches_schema() {
        for axis in SMALL_MODEL_RUNTIME_HARNESS_DRY_RUN_WITNESS_AXES {
            assert!(
                !axis.trim().is_empty(),
                "axis names must be non-empty and trimmed"
            );
            assert_eq!(*axis, axis.trim(), "axis names must be trimmed");
        }
    }
}
