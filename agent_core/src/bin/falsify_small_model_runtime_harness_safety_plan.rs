//! `falsify_small_model_runtime_harness_safety_plan`.
//!
//! Metadata-only witness for `F-SmallModelRuntimeHarnessSafetyPlan`. It proves
//! the next local small-model harness step is a safety plan only: serialized,
//! owner-gated, abortable, rollback-bound, RunEventLog-bound,
//! AnswerPacket-visible, MAS-safe, and mutation-free before any runtime bytes
//! can load.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::PRODUCT_ROUTE_REVIEW_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, SmallModelHarnessLane, SmallModelHarnessSafetySurface,
    SmallModelHarnessStage, SmallModelRuntimeHarnessSafetyError,
    SmallModelRuntimeHarnessSafetyPlan, SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallModelRuntimeHarnessSafetyPlan";
const FIXTURE_ID: &str = "small_model_runtime_harness_safety_plan_v1";
const COMMAND: &str = "Tools/falsifiers/f_small_model_runtime_harness_safety_plan.sh";
const RESULT: &str = "artifacts/falsifiers/small_model_runtime_harness_safety_plan/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const PRODUCT_ROUTE_REVIEW_PATH: &str = "artifacts/falsifiers/product_route_review/result.json";
const LIVING_INDEX_PATH: &str = "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md";
const LATTICE_HTML_PATH: &str = "artifacts/lattice-coordinate-explainer/index.html";
const MIN_STAGE_COUNT: u64 = 5;
const MIN_LANE_COUNT: u64 = 3;
const MIN_SURFACE_COUNT: u64 = 2;
const MIN_REQUIRED_LANE_COUNT: u64 = 3;
const MAX_CONTEXT_TOKENS: u64 = 40_960;
const MAX_PROMPT_TOKENS: u64 = 8_192;
const MAX_DECODE_TOKENS: u64 = 512;
const MAX_MEMORY_BUDGET_BYTES: u64 = 8 * 1024 * 1024 * 1024;
const MAX_RUNTIME_SECONDS: u64 = 300;
const MAX_METADATA_BYTES: u64 = 256 * 1024;

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-safety:witness-error
// Plane: Verification
// Residency: metadata-only safety-plan rejection taxonomy.
enum HarnessSafetyWitnessError {
    Primitive(SmallModelRuntimeHarnessSafetyError),
    Io(String),
}

impl std::fmt::Display for HarnessSafetyWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for HarnessSafetyWitnessError {}

impl From<SmallModelRuntimeHarnessSafetyError> for HarnessSafetyWitnessError {
    fn from(value: SmallModelRuntimeHarnessSafetyError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, HarnessSafetyWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let plan = fixture_plan(&evidence)?;
    let metrics = plan.metrics();
    let address = plan.address();
    let mut reversed = plan.lanes.clone();
    reversed.reverse();
    let deterministic = SmallModelRuntimeHarnessSafetyPlan::new(
        plan.plan_id.clone(),
        plan.guard_next_existing_work.clone(),
        plan.capability_route_status.clone(),
        plan.capability_next_bottleneck.clone(),
        plan.product_build.clone(),
        plan.pro_status.clone(),
        plan.route_authority.clone(),
        plan.admission_ref.clone(),
        plan.scope_rex_ref.clone(),
        plan.sovereign_gate_ref.clone(),
        plan.compatibility_fence.clone(),
        plan.stages.clone(),
        plan.surfaces.clone(),
        reversed,
        plan.metadata_bytes,
        plan.l1_l2_l3_separated,
        plan.mas_overclaim_attempted,
        plan.l2_green_claimed,
        plan.l3_green_claimed,
        plan.hidden_route_authority,
        plan.route_policy_mutated,
        plan.gate_bypass,
        plan.answer_packet_suppressed,
        plan.hidden_chain_exposed,
        plan.hidden_cloud_fallback,
        plan.subprocess_spawn_attempted,
        plan.autogenous_kernel_attempted,
        plan.seventy_b_probe_attempted,
        plan.runtime_bytes_loaded,
        plan.model_bytes_loaded,
        plan.transport_runtime_bytes_loaded,
    )?
    .address()
        == address;
    let invalid_axes = invalid_fixture_axes(&evidence)?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_product_route_review_pass",
            evidence.product_route_review_pass,
        ),
        (
            "guard_cursor_harness_safety_or_advanced",
            evidence.guard_next_existing_work == SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_harness_safety_or_advanced",
            evidence.capability_next_bottleneck == SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_NEXT_CURSOR,
        ),
        (
            "product_status_research_only",
            plan.product_build == ProductBuild::Pro
                && plan.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_safety_plan_only",
            plan.route_authority == "small_model_runtime_harness_safety_plan_only",
        ),
        (
            "living_index_surface_scan_pass",
            plan.surfaces.iter().any(|surface| {
                surface.surface_id == "living_index"
                    && surface
                        .observed_text
                        .contains(SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_CURSOR)
                    && surface
                        .observed_text
                        .contains("vault_research_route_with_packetized_mitigation")
            }),
        ),
        (
            "lattice_html_surface_scan_pass",
            plan.surfaces.iter().any(|surface| {
                surface.surface_id == "lattice_html"
                    && surface
                        .observed_text
                        .contains(SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_CURSOR)
                    && surface
                        .observed_text
                        .contains("vault_research_route_with_packetized_mitigation")
            }),
        ),
        (
            "north_star_present",
            plan.surfaces.iter().all(|surface| {
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
            plan.surfaces.iter().all(|surface| {
                surface
                    .forbidden_markers
                    .iter()
                    .all(|marker| !surface.observed_text.contains(marker))
            }),
        ),
        (
            "required_stages_bound",
            metrics.stage_count >= MIN_STAGE_COUNT,
        ),
        (
            "required_lanes_bound",
            metrics.required_lane_count >= MIN_REQUIRED_LANE_COUNT,
        ),
        (
            "serialized_executor_bound",
            plan.lanes.iter().all(|lane| {
                lane.serialized_executor_ref
                    .starts_with("serialized_executor:")
            }),
        ),
        (
            "cancellation_bound",
            plan.lanes
                .iter()
                .all(|lane| lane.cancellation_ref.starts_with("cancel:")),
        ),
        (
            "rollback_bound",
            plan.lanes
                .iter()
                .all(|lane| lane.rollback_ref.starts_with("rollback:")),
        ),
        (
            "run_event_log_bound",
            plan.lanes
                .iter()
                .all(|lane| lane.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "answer_packet_bound",
            plan.lanes
                .iter()
                .all(|lane| lane.answer_packet_ref.starts_with("answer_packet:")),
        ),
        (
            "admission_bound",
            plan.admission_ref.starts_with("admission:"),
        ),
        (
            "scope_rex_bound",
            plan.scope_rex_ref.starts_with("scope_rex:"),
        ),
        (
            "sovereign_gate_bound",
            plan.sovereign_gate_ref.starts_with("sovereign_gate:"),
        ),
        (
            "compatibility_fence_bound",
            plan.compatibility_fence.starts_with("compat:"),
        ),
        (
            "privacy_fence_bound",
            plan.lanes
                .iter()
                .all(|lane| lane.privacy_ref.starts_with("privacy:")),
        ),
        (
            "owner_approval_required",
            plan.lanes.iter().all(|lane| lane.owner_approval_required),
        ),
        (
            "dry_run_first_bound",
            plan.lanes.iter().all(|lane| lane.dry_run_first),
        ),
        ("l1_l2_l3_separation_bound", plan.l1_l2_l3_separated),
        ("mas_floor_preserved", !plan.mas_overclaim_attempted),
        ("no_l2_green_claim", !plan.l2_green_claimed),
        ("no_l3_green_claim", !plan.l3_green_claimed),
        ("no_hidden_route_authority", !plan.hidden_route_authority),
        ("no_route_policy_mutation", !plan.route_policy_mutated),
        ("no_gate_bypass", !plan.gate_bypass),
        (
            "no_answer_packet_suppression",
            !plan.answer_packet_suppressed,
        ),
        ("no_hidden_chain", !plan.hidden_chain_exposed),
        ("no_hidden_cloud_fallback", !plan.hidden_cloud_fallback),
        ("no_subprocess_spawn", !plan.subprocess_spawn_attempted),
        (
            "no_autogenous_kernel_attempt",
            !plan.autogenous_kernel_attempted,
        ),
        ("no_70b_probe_attempt", !plan.seventy_b_probe_attempted),
        (
            "no_runtime_probe_enabled",
            metrics.runtime_probe_enabled_count == 0,
        ),
        ("no_mutations_allowed", metrics.mutation_allowed_count == 0),
        ("no_runtime_bytes_loaded", plan.runtime_bytes_loaded == 0),
        ("no_model_bytes_loaded", plan.model_bytes_loaded == 0),
        (
            "no_transport_runtime_bytes_loaded",
            plan.transport_runtime_bytes_loaded == 0,
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
        ("metadata_bound", plan.metadata_bytes <= MAX_METADATA_BYTES),
        (
            "small_model_runtime_harness_safety_plan_address_deterministic",
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
        "stage_count",
        metrics.stage_count,
        MIN_STAGE_COUNT,
        "count",
    );
    add_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lane_count",
        metrics.lane_count,
        MIN_LANE_COUNT,
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
        "required_lane_count",
        metrics.required_lane_count,
        MIN_REQUIRED_LANE_COUNT,
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
        "mutation_allowed_count",
        metrics.mutation_allowed_count,
        0,
        "count",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cloud_fallback_allowed_count",
        metrics.cloud_fallback_allowed_count,
        0,
        "count",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "subprocess_spawn_allowed_count",
        metrics.subprocess_spawn_allowed_count,
        0,
        "count",
    );
    add_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "seventy_b_probe_allowed_count",
        metrics.seventy_b_probe_allowed_count,
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
        "small_model_runtime_harness_safety_plan_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address),
            unit: "address".to_string(),
        },
    );
    measurements.insert(
        "next_safe_unit".to_string(),
        Measurement {
            value: serde_json::Value::String(
                SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_NEXT_CURSOR.to_string(),
            ),
            unit: "cursor".to_string(),
        },
    );

    let mut anomalies = Vec::new();
    anomalies.push(serde_json::json!({
        "kind": "runtime_deferred",
        "detail": "Small-model runtime harness safety plan is metadata-only. No MLX/model/runtime bytes loaded; next work is a dry-run witness before any live probe."
    }));
    if evidence.capability_overall_pass {
        anomalies.push(serde_json::json!({
            "kind": "unexpected_l2_green",
            "detail": "Safety plan expected the capability kernel to remain red until runtime and L3 witnesses pass."
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
        notes: "metadata-only F-SmallModelRuntimeHarnessSafetyPlan witness: proves future small local-model runtime work is owner-gated, dry-run-first, serialized, abortable, rollback-bound, RunEventLog/AnswerPacket-visible, MAS-safe, mutation-free, and separate from 70B/ColdStream/KV promotion."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-safety:evidence-snapshot
// Plane: Verification
// Residency: metadata-only upstream artifact and S0 surface reader.
struct EvidenceSnapshot {
    product_route_review_pass: bool,
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    living_index_text: String,
    lattice_html_text: String,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, HarnessSafetyWitnessError> {
        let product_review = read_json(Path::new(PRODUCT_ROUTE_REVIEW_PATH))?;
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        Ok(Self {
            product_route_review_pass: artifact_all_axes_true(
                &product_review,
                PRODUCT_ROUTE_REVIEW_AXES,
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

fn fixture_plan(
    evidence: &EvidenceSnapshot,
) -> Result<SmallModelRuntimeHarnessSafetyPlan, HarnessSafetyWitnessError> {
    Ok(SmallModelRuntimeHarnessSafetyPlan::new(
        "small_model_runtime_harness_safety_plan_2026_06_05",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "small_model_runtime_harness_safety_plan_only",
        "admission:scope-rex-sovereign-gate:small-model-harness",
        "scope_rex:small-model-harness",
        "sovereign_gate:small-model-harness",
        "compat:small-model-harness:v1",
        harness_stages(),
        harness_surfaces(evidence)?,
        harness_lanes()?,
        96 * 1024,
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

fn harness_stages() -> BTreeSet<SmallModelHarnessStage> {
    BTreeSet::from([
        SmallModelHarnessStage::CatalogInventory,
        SmallModelHarnessStage::DryRunWitness,
        SmallModelHarnessStage::OwnerApprovalGate,
        SmallModelHarnessStage::AbortableRuntimeProbe,
        SmallModelHarnessStage::EvidenceReview,
    ])
}

fn harness_surfaces(
    evidence: &EvidenceSnapshot,
) -> Result<Vec<SmallModelHarnessSafetySurface>, HarnessSafetyWitnessError> {
    let required = vec![
        "Epistemos is a local cognitive substrate".to_string(),
        "no claim promotes without visible proof".to_string(),
        SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_CURSOR.to_string(),
        "vault_research_route_with_packetized_mitigation".to_string(),
        "small-model runtime harness safety plan".to_string(),
    ];
    let forbidden = vec![
        "small model runtime is product-green".to_string(),
        "MLX runtime probe already ran".to_string(),
        "MAS ships agentic local model runtime".to_string(),
        "70B runtime probe allowed by small model plan".to_string(),
        "hidden cloud fallback allowed".to_string(),
    ];
    Ok(vec![
        SmallModelHarnessSafetySurface::new(
            "living_index",
            LIVING_INDEX_PATH,
            required.clone(),
            forbidden.clone(),
            evidence.living_index_text.clone(),
        )?,
        SmallModelHarnessSafetySurface::new(
            "lattice_html",
            LATTICE_HTML_PATH,
            required,
            forbidden,
            evidence.lattice_html_text.clone(),
        )?,
    ])
}

fn harness_lanes() -> Result<Vec<SmallModelHarnessLane>, HarnessSafetyWitnessError> {
    Ok(vec![
        lane("qwen3_small_catalog_smoke", "research_notes_coding")?,
        lane(
            "local_agent_notes_research_smoke",
            "note_context_agentic_loop",
        )?,
        lane("coding_tool_dry_run_smoke", "coding_tool_call_dry_run")?,
    ])
}

fn lane(id: &str, role: &str) -> Result<SmallModelHarnessLane, HarnessSafetyWitnessError> {
    Ok(SmallModelHarnessLane::new(
        id,
        role,
        format!("model_catalog:{id}:mlx-small"),
        40960,
        4096,
        384,
        4 * 1024 * 1024 * 1024,
        180,
        format!("serialized_executor:{id}:mlx"),
        format!("cancel:{id}:owner-abort"),
        format!("rollback:{id}:no-state-mutation"),
        format!("answer_packet:{id}:harness-plan"),
        format!("run_event_log:{id}:harness-plan"),
        format!("privacy:{id}:local-only"),
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
    )?)
}

fn invalid_fixture_axes(
    evidence: &EvidenceSnapshot,
) -> Result<Vec<(&'static str, bool)>, HarnessSafetyWitnessError> {
    let plan = fixture_plan(evidence)?;
    let mut missing_lane = plan.lanes.clone();
    missing_lane.retain(|lane| lane.lane_id != "coding_tool_dry_run_smoke");
    let duplicate_lane = vec![
        lane("qwen3_small_catalog_smoke", "research_notes_coding")?,
        lane("qwen3_small_catalog_smoke", "research_notes_coding")?,
        lane("coding_tool_dry_run_smoke", "coding_tool_call_dry_run")?,
    ];
    let mut missing_stage = harness_stages();
    missing_stage.remove(&SmallModelHarnessStage::DryRunWitness);
    Ok(vec![
        (
            "missing_required_lane_rejected",
            plan_with(
                evidence,
                Some(missing_lane),
                None,
                None,
                None,
                None,
                None,
                None,
                None,
            )?
            .is_err(),
        ),
        (
            "duplicate_lane_rejected",
            plan_with(
                evidence,
                Some(duplicate_lane),
                None,
                None,
                None,
                None,
                None,
                None,
                None,
            )?
            .is_err(),
        ),
        (
            "missing_stage_rejected",
            SmallModelRuntimeHarnessSafetyPlan::new(
                "small_model_runtime_harness_safety_plan_2026_06_05",
                evidence.guard_next_existing_work.clone(),
                evidence.capability_route_status.clone(),
                evidence.capability_next_bottleneck.clone(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                "small_model_runtime_harness_safety_plan_only",
                "admission:scope-rex-sovereign-gate:small-model-harness",
                "scope_rex:small-model-harness",
                "sovereign_gate:small-model-harness",
                "compat:small-model-harness:v1",
                missing_stage,
                harness_surfaces(evidence)?,
                harness_lanes()?,
                96 * 1024,
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
            )
            .is_err(),
        ),
        (
            "owner_approval_missing_rejected",
            invalid_lane_owner_approval().is_err(),
        ),
        (
            "dry_run_first_missing_rejected",
            invalid_lane_dry_run().is_err(),
        ),
        (
            "runtime_probe_enabled_rejected",
            invalid_lane_runtime_enabled().is_err(),
        ),
        (
            "missing_serialized_executor_rejected",
            invalid_lane_serialized_executor().is_err(),
        ),
        (
            "missing_cancellation_rejected",
            invalid_lane_cancel().is_err(),
        ),
        (
            "missing_rollback_rejected",
            invalid_lane_rollback().is_err(),
        ),
        (
            "missing_answer_packet_rejected",
            invalid_lane_answer_packet().is_err(),
        ),
        ("missing_privacy_rejected", invalid_lane_privacy().is_err()),
        (
            "context_budget_overflow_rejected",
            invalid_lane_context_budget().is_err(),
        ),
        (
            "decode_budget_overflow_rejected",
            invalid_lane_decode_budget().is_err(),
        ),
        (
            "memory_budget_overflow_rejected",
            invalid_lane_memory_budget().is_err(),
        ),
        (
            "runtime_budget_overflow_rejected",
            invalid_lane_runtime_budget().is_err(),
        ),
        (
            "mas_overclaim_rejected",
            plan_with(
                evidence,
                None,
                Some(true),
                None,
                None,
                None,
                None,
                None,
                None,
            )?
            .is_err(),
        ),
        (
            "l2_green_claim_rejected",
            plan_with(
                evidence,
                None,
                None,
                Some(true),
                None,
                None,
                None,
                None,
                None,
            )?
            .is_err(),
        ),
        (
            "l3_green_claim_rejected",
            plan_with(
                evidence,
                None,
                None,
                None,
                Some(true),
                None,
                None,
                None,
                None,
            )?
            .is_err(),
        ),
        (
            "hidden_authority_rejected",
            plan_with(
                evidence,
                None,
                None,
                None,
                None,
                Some(true),
                None,
                None,
                None,
            )?
            .is_err(),
        ),
        (
            "route_policy_mutation_rejected",
            plan_with(
                evidence,
                None,
                None,
                None,
                None,
                None,
                Some(true),
                None,
                None,
            )?
            .is_err(),
        ),
        (
            "gate_bypass_rejected",
            plan_with(
                evidence,
                None,
                None,
                None,
                None,
                None,
                None,
                Some(true),
                None,
            )?
            .is_err(),
        ),
        (
            "answer_packet_suppression_rejected",
            plan_with(
                evidence,
                None,
                None,
                None,
                None,
                None,
                None,
                None,
                Some(true),
            )?
            .is_err(),
        ),
        (
            "hidden_chain_rejected",
            invalid_plan_hidden_chain(evidence)?.is_err(),
        ),
        (
            "hidden_cloud_rejected",
            invalid_plan_hidden_cloud(evidence)?.is_err(),
        ),
        (
            "subprocess_spawn_rejected",
            invalid_plan_subprocess(evidence)?.is_err(),
        ),
        (
            "autogenous_kernel_rejected",
            invalid_plan_autogenous_kernel(evidence)?.is_err(),
        ),
        (
            "seventy_b_probe_rejected",
            invalid_plan_seventy_b_probe(evidence)?.is_err(),
        ),
        (
            "runtime_bytes_rejected",
            invalid_plan_bytes(evidence, 1, 0, 0)?.is_err(),
        ),
        (
            "model_bytes_rejected",
            invalid_plan_bytes(evidence, 0, 1, 0)?.is_err(),
        ),
        (
            "transport_runtime_bytes_rejected",
            invalid_plan_bytes(evidence, 0, 0, 1)?.is_err(),
        ),
        (
            "metadata_budget_rejected",
            invalid_plan_metadata_budget(evidence)?.is_err(),
        ),
    ])
}

#[allow(clippy::too_many_arguments)]
fn plan_with(
    evidence: &EvidenceSnapshot,
    lanes_override: Option<Vec<SmallModelHarnessLane>>,
    mas_overclaim: Option<bool>,
    l2_green: Option<bool>,
    l3_green: Option<bool>,
    hidden_authority: Option<bool>,
    route_mutation: Option<bool>,
    gate_bypass: Option<bool>,
    answer_suppressed: Option<bool>,
) -> Result<
    Result<SmallModelRuntimeHarnessSafetyPlan, SmallModelRuntimeHarnessSafetyError>,
    HarnessSafetyWitnessError,
> {
    Ok(SmallModelRuntimeHarnessSafetyPlan::new(
        "small_model_runtime_harness_safety_plan_2026_06_05",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "small_model_runtime_harness_safety_plan_only",
        "admission:scope-rex-sovereign-gate:small-model-harness",
        "scope_rex:small-model-harness",
        "sovereign_gate:small-model-harness",
        "compat:small-model-harness:v1",
        harness_stages(),
        harness_surfaces(evidence)?,
        lanes_override.unwrap_or(harness_lanes()?),
        96 * 1024,
        true,
        mas_overclaim.unwrap_or(false),
        l2_green.unwrap_or(false),
        l3_green.unwrap_or(false),
        hidden_authority.unwrap_or(false),
        route_mutation.unwrap_or(false),
        gate_bypass.unwrap_or(false),
        answer_suppressed.unwrap_or(false),
        false,
        false,
        false,
        false,
        false,
        0,
        0,
        0,
    ))
}

fn invalid_lane_owner_approval(
) -> Result<SmallModelHarnessLane, SmallModelRuntimeHarnessSafetyError> {
    SmallModelHarnessLane::new(
        "qwen3_small_catalog_smoke",
        "research_notes_coding",
        "model_catalog:qwen3:mlx-small",
        40960,
        4096,
        384,
        4 * 1024 * 1024 * 1024,
        180,
        "serialized_executor:qwen3:mlx",
        "cancel:qwen3",
        "rollback:qwen3",
        "answer_packet:qwen3",
        "run_event_log:qwen3",
        "privacy:qwen3",
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn invalid_lane_dry_run() -> Result<SmallModelHarnessLane, SmallModelRuntimeHarnessSafetyError> {
    SmallModelHarnessLane::new(
        "qwen3_small_catalog_smoke",
        "research_notes_coding",
        "model_catalog:qwen3:mlx-small",
        40960,
        4096,
        384,
        4 * 1024 * 1024 * 1024,
        180,
        "serialized_executor:qwen3:mlx",
        "cancel:qwen3",
        "rollback:qwen3",
        "answer_packet:qwen3",
        "run_event_log:qwen3",
        "privacy:qwen3",
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
    )
}

fn invalid_lane_runtime_enabled(
) -> Result<SmallModelHarnessLane, SmallModelRuntimeHarnessSafetyError> {
    SmallModelHarnessLane::new(
        "qwen3_small_catalog_smoke",
        "research_notes_coding",
        "model_catalog:qwen3:mlx-small",
        40960,
        4096,
        384,
        4 * 1024 * 1024 * 1024,
        180,
        "serialized_executor:qwen3:mlx",
        "cancel:qwen3",
        "rollback:qwen3",
        "answer_packet:qwen3",
        "run_event_log:qwen3",
        "privacy:qwen3",
        true,
        true,
        true,
        false,
        false,
        false,
        false,
        false,
    )
}

macro_rules! invalid_lane {
    ($name:ident, $executor:expr, $cancel:expr, $rollback:expr, $packet:expr, $privacy:expr, $ctx:expr, $decode:expr, $memory:expr, $runtime:expr) => {
        fn $name() -> Result<SmallModelHarnessLane, SmallModelRuntimeHarnessSafetyError> {
            SmallModelHarnessLane::new(
                "qwen3_small_catalog_smoke",
                "research_notes_coding",
                "model_catalog:qwen3:mlx-small",
                $ctx,
                4096,
                $decode,
                $memory,
                $runtime,
                $executor,
                $cancel,
                $rollback,
                $packet,
                "run_event_log:qwen3",
                $privacy,
                true,
                true,
                false,
                false,
                false,
                false,
                false,
                false,
            )
        }
    };
}

invalid_lane!(
    invalid_lane_serialized_executor,
    "executor:qwen3",
    "cancel:qwen3",
    "rollback:qwen3",
    "answer_packet:qwen3",
    "privacy:qwen3",
    40960,
    384,
    4 * 1024 * 1024 * 1024,
    180
);
invalid_lane!(
    invalid_lane_cancel,
    "serialized_executor:qwen3:mlx",
    "abort:qwen3",
    "rollback:qwen3",
    "answer_packet:qwen3",
    "privacy:qwen3",
    40960,
    384,
    4 * 1024 * 1024 * 1024,
    180
);
invalid_lane!(
    invalid_lane_rollback,
    "serialized_executor:qwen3:mlx",
    "cancel:qwen3",
    "revert:qwen3",
    "answer_packet:qwen3",
    "privacy:qwen3",
    40960,
    384,
    4 * 1024 * 1024 * 1024,
    180
);
invalid_lane!(
    invalid_lane_answer_packet,
    "serialized_executor:qwen3:mlx",
    "cancel:qwen3",
    "rollback:qwen3",
    "packet:qwen3",
    "privacy:qwen3",
    40960,
    384,
    4 * 1024 * 1024 * 1024,
    180
);
invalid_lane!(
    invalid_lane_privacy,
    "serialized_executor:qwen3:mlx",
    "cancel:qwen3",
    "rollback:qwen3",
    "answer_packet:qwen3",
    "fence:qwen3",
    40960,
    384,
    4 * 1024 * 1024 * 1024,
    180
);
invalid_lane!(
    invalid_lane_context_budget,
    "serialized_executor:qwen3:mlx",
    "cancel:qwen3",
    "rollback:qwen3",
    "answer_packet:qwen3",
    "privacy:qwen3",
    40961,
    384,
    4 * 1024 * 1024 * 1024,
    180
);
invalid_lane!(
    invalid_lane_decode_budget,
    "serialized_executor:qwen3:mlx",
    "cancel:qwen3",
    "rollback:qwen3",
    "answer_packet:qwen3",
    "privacy:qwen3",
    40960,
    513,
    4 * 1024 * 1024 * 1024,
    180
);
invalid_lane!(
    invalid_lane_memory_budget,
    "serialized_executor:qwen3:mlx",
    "cancel:qwen3",
    "rollback:qwen3",
    "answer_packet:qwen3",
    "privacy:qwen3",
    40960,
    384,
    9 * 1024 * 1024 * 1024,
    180
);
invalid_lane!(
    invalid_lane_runtime_budget,
    "serialized_executor:qwen3:mlx",
    "cancel:qwen3",
    "rollback:qwen3",
    "answer_packet:qwen3",
    "privacy:qwen3",
    40960,
    384,
    4 * 1024 * 1024 * 1024,
    301
);

fn invalid_plan_hidden_chain(
    evidence: &EvidenceSnapshot,
) -> Result<
    Result<SmallModelRuntimeHarnessSafetyPlan, SmallModelRuntimeHarnessSafetyError>,
    HarnessSafetyWitnessError,
> {
    plan_custom_flags(evidence, false, true, false, false, false)
}

fn invalid_plan_hidden_cloud(
    evidence: &EvidenceSnapshot,
) -> Result<
    Result<SmallModelRuntimeHarnessSafetyPlan, SmallModelRuntimeHarnessSafetyError>,
    HarnessSafetyWitnessError,
> {
    plan_custom_flags(evidence, false, false, true, false, false)
}

fn invalid_plan_subprocess(
    evidence: &EvidenceSnapshot,
) -> Result<
    Result<SmallModelRuntimeHarnessSafetyPlan, SmallModelRuntimeHarnessSafetyError>,
    HarnessSafetyWitnessError,
> {
    plan_custom_flags(evidence, false, false, false, true, false)
}

fn invalid_plan_autogenous_kernel(
    evidence: &EvidenceSnapshot,
) -> Result<
    Result<SmallModelRuntimeHarnessSafetyPlan, SmallModelRuntimeHarnessSafetyError>,
    HarnessSafetyWitnessError,
> {
    plan_custom_flags(evidence, true, false, false, false, false)
}

fn invalid_plan_seventy_b_probe(
    evidence: &EvidenceSnapshot,
) -> Result<
    Result<SmallModelRuntimeHarnessSafetyPlan, SmallModelRuntimeHarnessSafetyError>,
    HarnessSafetyWitnessError,
> {
    plan_custom_flags(evidence, false, false, false, false, true)
}

fn plan_custom_flags(
    evidence: &EvidenceSnapshot,
    autogenous_kernel: bool,
    hidden_chain: bool,
    hidden_cloud: bool,
    subprocess: bool,
    seventy_b_probe: bool,
) -> Result<
    Result<SmallModelRuntimeHarnessSafetyPlan, SmallModelRuntimeHarnessSafetyError>,
    HarnessSafetyWitnessError,
> {
    Ok(SmallModelRuntimeHarnessSafetyPlan::new(
        "small_model_runtime_harness_safety_plan_2026_06_05",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "small_model_runtime_harness_safety_plan_only",
        "admission:scope-rex-sovereign-gate:small-model-harness",
        "scope_rex:small-model-harness",
        "sovereign_gate:small-model-harness",
        "compat:small-model-harness:v1",
        harness_stages(),
        harness_surfaces(evidence)?,
        harness_lanes()?,
        96 * 1024,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        hidden_chain,
        hidden_cloud,
        subprocess,
        autogenous_kernel,
        seventy_b_probe,
        0,
        0,
        0,
    ))
}

fn invalid_plan_bytes(
    evidence: &EvidenceSnapshot,
    runtime: u64,
    model: u64,
    transport: u64,
) -> Result<
    Result<SmallModelRuntimeHarnessSafetyPlan, SmallModelRuntimeHarnessSafetyError>,
    HarnessSafetyWitnessError,
> {
    Ok(SmallModelRuntimeHarnessSafetyPlan::new(
        "small_model_runtime_harness_safety_plan_2026_06_05",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "small_model_runtime_harness_safety_plan_only",
        "admission:scope-rex-sovereign-gate:small-model-harness",
        "scope_rex:small-model-harness",
        "sovereign_gate:small-model-harness",
        "compat:small-model-harness:v1",
        harness_stages(),
        harness_surfaces(evidence)?,
        harness_lanes()?,
        96 * 1024,
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
        runtime,
        model,
        transport,
    ))
}

fn invalid_plan_metadata_budget(
    evidence: &EvidenceSnapshot,
) -> Result<
    Result<SmallModelRuntimeHarnessSafetyPlan, SmallModelRuntimeHarnessSafetyError>,
    HarnessSafetyWitnessError,
> {
    Ok(SmallModelRuntimeHarnessSafetyPlan::new(
        "small_model_runtime_harness_safety_plan_2026_06_05",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "small_model_runtime_harness_safety_plan_only",
        "admission:scope-rex-sovereign-gate:small-model-harness",
        "scope_rex:small-model-harness",
        "sovereign_gate:small-model-harness",
        "compat:small-model-harness:v1",
        harness_stages(),
        harness_surfaces(evidence)?,
        harness_lanes()?,
        MAX_METADATA_BYTES + 1,
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
    ))
}

fn add_min_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    min: u64,
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
            value: serde_json::Value::from(min),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual >= min);
}

fn add_max_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    max: u64,
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
            value: serde_json::Value::from(max),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual <= max);
}

fn artifact_all_axes_true(value: &serde_json::Value, required_axes: &[&str]) -> bool {
    if !artifact_overall_pass(value) {
        return false;
    }
    required_axes.iter().all(|axis| {
        value
            .get("pass_per_axis")
            .and_then(|axes| axes.get(*axis))
            .and_then(|axis_value| axis_value.as_bool())
            .unwrap_or(false)
    })
}

fn artifact_overall_pass(value: &serde_json::Value) -> bool {
    value
        .get("overall_pass")
        .and_then(|pass| pass.as_bool())
        .unwrap_or(false)
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")?
        .get(key)?
        .get("value")?
        .as_str()
        .map(str::to_string)
}

fn read_json(path: &Path) -> Result<serde_json::Value, HarnessSafetyWitnessError> {
    let content = read_text(path)?;
    serde_json::from_str(&content).map_err(|error| {
        HarnessSafetyWitnessError::Io(format!("failed to parse {}: {error}", path.display()))
    })
}

fn read_text(path: &Path) -> Result<String, HarnessSafetyWitnessError> {
    std::fs::read_to_string(path).map_err(|error| {
        HarnessSafetyWitnessError::Io(format!("failed to read {}: {error}", path.display()))
    })
}

#[cfg(test)]
mod tests {
    #[test]
    fn axis_contract_matches_schema() {
        let axis_set =
            agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_SAFETY_PLAN_AXES
                .iter()
                .copied()
                .collect::<std::collections::BTreeSet<_>>();
        assert!(axis_set.contains("owner_approval_required"));
        assert!(axis_set.contains("no_runtime_probe_enabled"));
        assert!(axis_set.contains("small_model_runtime_harness_safety_plan_address_deterministic"));
    }
}
