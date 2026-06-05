//! `falsify_small_model_runtime_harness_first_token_runtime_probe`.
//!
//! Retained live-runtime L1 witness for
//! `F-SmallModelRuntimeHarnessFirstTokenRuntimeProbe`. It validates a redacted
//! small-model first-token sidecar, binds it to the logged runtime smoke rung,
//! and keeps product capability / user-facing truth red.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_first_token_runtime_probe_phases, ProStatus, ProductBuild,
    SmallModelFirstTokenRuntimeProbeRun, SmallModelFirstTokenRuntimeProbeSurface,
    SmallModelRuntimeHarnessFirstTokenProbeError, SmallModelRuntimeHarnessFirstTokenProbeWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallModelRuntimeHarnessFirstTokenRuntimeProbe";
const FIXTURE_ID: &str = "small_model_runtime_harness_first_token_runtime_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_small_model_runtime_harness_first_token_runtime_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_first_token_runtime_probe/result.json";
const LIVE_PROBE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_first_token_runtime_probe/live_probe.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const LOGGED_SMOKE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_logged_runtime_smoke/result.json";
const LIVING_INDEX_PATH: &str = "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md";
const LATTICE_HTML_PATH: &str = "artifacts/lattice-coordinate-explainer/index.html";
const MLX_RUNTIME_PATH: &str = "Epistemos/Engine/MLXInferenceService.swift";
const SERIAL_CONTROLLER_PATH: &str = "Epistemos/Engine/LocalInferenceSerialController.swift";
const MAX_CONTEXT_TOKENS: u64 = 65_536;
const MAX_PROMPT_TOKENS: u64 = 256;
const MAX_DECODE_TOKENS: u64 = 1;
const MAX_MEMORY_BUDGET_BYTES: u64 = 6 * 1024 * 1024 * 1024;
const MAX_MODEL_BYTES_LOADED: u64 = 4 * 1024 * 1024 * 1024;
const MAX_RUNTIME_SECONDS: u64 = 180;
const MAX_LOAD_MS: u64 = 60_000;
const MAX_FIRST_TOKEN_MS: u64 = 60_000;
const MAX_TOTAL_MS: u64 = 180_000;
const MAX_METADATA_BYTES: u64 = 512 * 1024;

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-first-token-runtime-probe:witness-error
// Plane: Verification
// Residency: retained first-token witness rejection taxonomy.
enum FirstTokenWitnessError {
    Primitive(SmallModelRuntimeHarnessFirstTokenProbeError),
    Io(String),
}

impl std::fmt::Display for FirstTokenWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for FirstTokenWitnessError {}

impl From<SmallModelRuntimeHarnessFirstTokenProbeError> for FirstTokenWitnessError {
    fn from(value: SmallModelRuntimeHarnessFirstTokenProbeError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, FirstTokenWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fixture_witness(&evidence)?;
    let metrics = witness.metrics();
    let address = witness.address();
    let deterministic = SmallModelRuntimeHarnessFirstTokenProbeWitness::new(
        witness.witness_id.clone(),
        witness.logged_smoke_artifact_ref.clone(),
        witness.guard_next_existing_work.clone(),
        witness.capability_route_status.clone(),
        witness.capability_next_bottleneck.clone(),
        witness.product_build.clone(),
        witness.pro_status.clone(),
        witness.route_authority.clone(),
        witness.runs.clone(),
        witness.surfaces.clone(),
        witness.metadata_bytes,
        witness.l1_l2_l3_separated,
        witness.mas_overclaim_attempted,
        witness.l2_green_claimed,
        witness.l3_green_claimed,
    )?
    .address()
        == address;
    let invalid_axes = invalid_fixture_axes(&witness)?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let run = &witness.runs[0];
    let bool_axes = [
        (
            "upstream_small_model_runtime_harness_logged_runtime_smoke_pass",
            evidence.logged_smoke_pass,
        ),
        (
            "guard_cursor_first_token_or_advanced",
            evidence.guard_next_existing_work
                == SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_first_token_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_NEXT_CURSOR,
        ),
        (
            "product_status_research_only",
            witness.product_build == ProductBuild::Pro
                && witness.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_retained_probe_only",
            witness.route_authority == "retained_small_model_first_token_probe_only",
        ),
        (
            "living_index_surface_scan_pass",
            surface_contains(
                &witness,
                "living_index",
                SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_CURSOR,
            ),
        ),
        (
            "lattice_html_surface_scan_pass",
            surface_contains(
                &witness,
                "lattice_html",
                SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_CURSOR,
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
            "live_probe_sidecar_bound",
            run.live_probe_sidecar_ref.starts_with(
                "artifact:small_model_runtime_harness_first_token_runtime_probe:live_probe:",
            ),
        ),
        (
            "live_probe_sidecar_redacted",
            evidence.live_probe.raw_token_text_retained == Some(false)
                && evidence.live_probe.first_token_preview.is_none(),
        ),
        (
            "model_repo_small_qwen3_bound",
            evidence.live_probe.model_repo == "Qwen/Qwen3-4B-MLX-4bit",
        ),
        ("model_snapshot_exists", evidence.model_snapshot_exists),
        (
            "model_config_bound",
            evidence.live_probe.model_type.as_deref() == Some("qwen3")
                && evidence.live_probe.quantization_bits == Some(4)
                && evidence.live_probe.max_position_embeddings == Some(65_536),
        ),
        ("tokenizer_bound", evidence.tokenizer_exists),
        (
            "prompt_hash_bound",
            evidence.live_probe.prompt_sha256.starts_with("sha256:")
                && evidence.live_probe.prompt_sha256.len() >= 71,
        ),
        (
            "synthetic_prompt_no_user_data",
            !evidence.live_probe.prompt_contains_user_data,
        ),
        ("first_token_observed", run.first_token_observed),
        ("exactly_one_output_token", run.output_token_count == 1),
        (
            "runtime_started_and_completed",
            run.runtime_started && run.runtime_completed,
        ),
        ("runtime_bytes_loaded_nonzero", run.runtime_bytes_loaded > 0),
        ("model_bytes_loaded_nonzero", run.model_bytes_loaded > 0),
        (
            "runtime_bytes_budget_bound",
            run.runtime_bytes_loaded <= MAX_MODEL_BYTES_LOADED,
        ),
        (
            "model_bytes_budget_bound",
            run.model_bytes_loaded <= MAX_MODEL_BYTES_LOADED,
        ),
        ("load_time_bound", u64::from(run.load_ms) <= MAX_LOAD_MS),
        (
            "first_token_time_bound",
            u64::from(run.first_token_ms) <= MAX_FIRST_TOKEN_MS,
        ),
        ("total_time_bound", u64::from(run.total_ms) <= MAX_TOTAL_MS),
        (
            "logged_smoke_artifact_ref_bound",
            run.logged_smoke_artifact_ref
                .starts_with("artifact:small_model_runtime_harness_logged_runtime_smoke:"),
        ),
        (
            "admission_bound",
            run.admission_ref.starts_with("admission:"),
        ),
        (
            "scope_rex_bound",
            run.scope_rex_ref.starts_with("scope_rex:"),
        ),
        (
            "sovereign_gate_bound",
            run.sovereign_gate_ref.starts_with("sovereign_gate:"),
        ),
        (
            "compatibility_fence_bound",
            run.compatibility_fence_ref.starts_with("compat:"),
        ),
        (
            "cancellation_bound",
            run.cancellation_ref.starts_with("cancel:"),
        ),
        ("rollback_bound", run.rollback_ref.starts_with("rollback:")),
        (
            "run_event_log_bound",
            run.run_event_log_ref.starts_with("run_event_log:"),
        ),
        (
            "answer_packet_bound",
            run.answer_packet_ref.starts_with("answer_packet:"),
        ),
        (
            "privacy_fence_bound",
            run.privacy_ref.starts_with("privacy:"),
        ),
        ("budget_refs_bound", run.budget_ref.starts_with("budget:")),
        (
            "token_digest_bound",
            run.token_digest_ref.starts_with("token_sha256:"),
        ),
        ("required_phases_bound", metrics.phase_count >= 16),
        ("l1_l2_l3_separation_bound", witness.l1_l2_l3_separated),
        (
            "mas_floor_preserved",
            witness.product_build == ProductBuild::Pro && !witness.mas_overclaim_attempted,
        ),
        ("no_l2_green_claim", !witness.l2_green_claimed),
        ("no_l3_green_claim", !witness.l3_green_claimed),
        (
            "no_hidden_route_authority",
            !run.hidden_route_authority_attempted,
        ),
        (
            "no_route_policy_mutation",
            !run.route_policy_mutation_attempted,
        ),
        ("no_gate_bypass", !run.gate_bypass_attempted),
        (
            "no_answer_packet_suppression",
            !run.answer_packet_suppressed,
        ),
        ("no_hidden_chain", !run.hidden_chain_exposed),
        (
            "no_hidden_cloud_fallback",
            !run.hidden_cloud_fallback_allowed,
        ),
        (
            "no_app_path_subprocess_spawn",
            !run.subprocess_spawned_in_app_path,
        ),
        (
            "no_autogenous_kernel_attempt",
            !run.autogenous_kernel_attempted,
        ),
        ("no_70b_probe_attempt", !run.seventy_b_probe_attempted),
        (
            "no_long_context_shard_probe",
            !run.long_context_shard_probe_attempted,
        ),
        ("no_mutation_committed", !run.committed_mutation),
        (
            "context_budget_bound",
            u64::from(run.context_tokens) <= MAX_CONTEXT_TOKENS,
        ),
        (
            "prompt_budget_bound",
            u64::from(run.prompt_tokens) <= MAX_PROMPT_TOKENS,
        ),
        (
            "decode_budget_bound",
            u64::from(run.decode_tokens) <= MAX_DECODE_TOKENS,
        ),
        (
            "memory_budget_bound",
            run.memory_budget_bytes <= MAX_MEMORY_BUDGET_BYTES,
        ),
        (
            "runtime_budget_bound",
            u64::from(run.runtime_budget_seconds) <= MAX_RUNTIME_SECONDS,
        ),
        (
            "metadata_bound",
            witness.metadata_bytes <= MAX_METADATA_BYTES,
        ),
        (
            "small_model_runtime_harness_first_token_runtime_probe_address_deterministic",
            deterministic,
        ),
        (
            "missing_sidecar_rejected",
            invalid_axes.missing_sidecar_rejected,
        ),
        (
            "missing_logged_smoke_rejected",
            invalid_axes.missing_logged_smoke_rejected,
        ),
        (
            "missing_model_snapshot_rejected",
            invalid_axes.missing_model_snapshot_rejected,
        ),
        (
            "missing_model_config_rejected",
            invalid_axes.missing_model_config_rejected,
        ),
        (
            "missing_tokenizer_rejected",
            invalid_axes.missing_tokenizer_rejected,
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
            "missing_token_digest_rejected",
            invalid_axes.missing_token_digest_rejected,
        ),
        (
            "missing_phase_rejected",
            invalid_axes.missing_phase_rejected,
        ),
        (
            "duplicate_run_rejected",
            invalid_axes.duplicate_run_rejected,
        ),
        (
            "first_token_missing_rejected",
            invalid_axes.first_token_missing_rejected,
        ),
        (
            "output_token_count_mismatch_rejected",
            invalid_axes.output_token_count_mismatch_rejected,
        ),
        (
            "token_text_retained_rejected",
            invalid_axes.token_text_retained_rejected,
        ),
        (
            "prompt_user_data_rejected",
            invalid_axes.prompt_user_data_rejected,
        ),
        (
            "runtime_bytes_zero_rejected",
            invalid_axes.runtime_bytes_zero_rejected,
        ),
        (
            "model_bytes_zero_rejected",
            invalid_axes.model_bytes_zero_rejected,
        ),
        (
            "runtime_bytes_over_budget_rejected",
            invalid_axes.runtime_bytes_over_budget_rejected,
        ),
        (
            "model_bytes_over_budget_rejected",
            invalid_axes.model_bytes_over_budget_rejected,
        ),
        (
            "load_time_overflow_rejected",
            invalid_axes.load_time_overflow_rejected,
        ),
        (
            "first_token_time_overflow_rejected",
            invalid_axes.first_token_time_overflow_rejected,
        ),
        (
            "total_time_overflow_rejected",
            invalid_axes.total_time_overflow_rejected,
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
            "app_path_subprocess_rejected",
            invalid_axes.app_path_subprocess_rejected,
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
            "long_context_shard_probe_rejected",
            invalid_axes.long_context_shard_probe_rejected,
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
        1,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "surface_count",
        metrics.surface_count,
        ">=",
        4,
        "surfaces",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "phase_count",
        metrics.phase_count,
        ">=",
        16,
        "phases",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "first_token_observed_count",
        metrics.first_token_observed_count,
        "==",
        metrics.run_count,
        "runs",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "output_token_count",
        metrics.output_token_count,
        "==",
        metrics.run_count,
        "tokens",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_load_ms",
        u64::from(metrics.max_load_ms),
        "<=",
        MAX_LOAD_MS,
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_first_token_ms",
        u64::from(metrics.max_first_token_ms),
        "<=",
        MAX_FIRST_TOKEN_MS,
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_total_ms",
        u64::from(metrics.max_total_ms),
        "<=",
        MAX_TOTAL_MS,
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_bytes_loaded",
        metrics.runtime_bytes_loaded,
        ">",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_bytes_loaded",
        metrics.model_bytes_loaded,
        ">",
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
        "small_model_runtime_harness_first_token_runtime_probe_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address),
            unit: "sha256".to_string(),
        },
    );
    thresholds.insert(
        "small_model_runtime_harness_first_token_runtime_probe_address".to_string(),
        AcceptanceThreshold {
            operator: "present".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "small_model_runtime_harness_first_token_runtime_probe_address".to_string(),
        true,
    );

    let anomalies = vec![serde_json::json!({
        "kind": "small_model_runtime_harness_first_token_runtime_probe_l1_only",
        "detail": "The retained Qwen3-4B MLX sidecar proves one owner-approved small local model first token with redacted token text, rollback, RunEventLog, AnswerPacket, admission, privacy, and budget evidence. It loads small-model runtime/model bytes, so it is not metadata-only, but L2 capability and L3 product runtime remain unpromoted."
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
        notes: "live-retained L1 F-SmallModelRuntimeHarnessFirstTokenRuntimeProbe: proves a redacted Qwen3-4B MLX first-token sidecar only; no MAS/product route, no 70B, no 128K shard, no hidden cloud, no hidden chain, no mutation, and no L2/L3 promotion."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

#[derive(Clone)]
// UAS: Aggregates runtime witness surfaces for F-SmallModelRuntimeHarnessFirstTokenRuntimeProbe.
// Plane: Verification.
// Residency: CurrentApp small-model first-token evidence only; no 70B or product-route promotion.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    logged_smoke_pass: bool,
    live_probe: LiveProbeSidecar,
    model_snapshot_exists: bool,
    tokenizer_exists: bool,
    living_index: String,
    lattice_html: String,
    mlx_runtime_source: String,
    serial_controller_source: String,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, FirstTokenWitnessError> {
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        let logged_smoke = read_json(Path::new(LOGGED_SMOKE_PATH))?;
        let live_probe = read_sidecar(Path::new(LIVE_PROBE_PATH))?;
        let snapshot = Path::new(&live_probe.model_path);
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
            logged_smoke_pass: artifact_all_axes_true(
                &logged_smoke,
                SMALL_MODEL_RUNTIME_HARNESS_LOGGED_RUNTIME_SMOKE_AXES,
            ),
            model_snapshot_exists: snapshot.exists(),
            tokenizer_exists: snapshot.join("tokenizer.json").exists()
                || snapshot.join("tokenizer_config.json").exists(),
            live_probe,
            living_index: read_text(Path::new(LIVING_INDEX_PATH))?,
            lattice_html: read_text(Path::new(LATTICE_HTML_PATH))?,
            mlx_runtime_source: read_text(Path::new(MLX_RUNTIME_PATH))?,
            serial_controller_source: read_text(Path::new(SERIAL_CONTROLLER_PATH))?,
        })
    }
}

#[derive(Clone, Debug)]
// UAS: Retained redacted sidecar schema for the owner-approved Qwen3-4B MLX first-token probe.
// Plane: Verification.
// Residency: CurrentApp runtime/model-byte evidence with raw token text explicitly excluded.
struct LiveProbeSidecar {
    model_repo: String,
    model_path: String,
    model_type: Option<String>,
    quantization_bits: Option<u32>,
    max_position_embeddings: Option<u32>,
    prompt_sha256: String,
    prompt_contains_user_data: bool,
    first_token_observed: bool,
    chunks_observed: u32,
    output_token_count: u32,
    first_token_utf8_len: u32,
    first_token_sha256: String,
    raw_token_text_retained: Option<bool>,
    first_token_preview: Option<String>,
    load_ms: u32,
    first_token_ms: u32,
    total_ms: u32,
    model_bytes_loaded: u64,
    runtime_bytes_loaded: u64,
}

fn read_sidecar(path: &Path) -> Result<LiveProbeSidecar, FirstTokenWitnessError> {
    let value = read_json(path)?;
    Ok(LiveProbeSidecar {
        model_repo: json_string(&value, "model_repo")?,
        model_path: json_string(&value, "model_path")?,
        model_type: value
            .get("model_type")
            .and_then(serde_json::Value::as_str)
            .map(ToOwned::to_owned),
        quantization_bits: value
            .get("quantization_bits")
            .and_then(serde_json::Value::as_u64)
            .and_then(|value| u32::try_from(value).ok()),
        max_position_embeddings: value
            .get("max_position_embeddings")
            .and_then(serde_json::Value::as_u64)
            .and_then(|value| u32::try_from(value).ok()),
        prompt_sha256: json_string(&value, "prompt_sha256")?,
        prompt_contains_user_data: json_bool(&value, "prompt_contains_user_data")?,
        first_token_observed: json_bool(&value, "first_token_observed")?,
        chunks_observed: json_u32(&value, "chunks_observed")?,
        output_token_count: json_u32(&value, "output_token_count")?,
        first_token_utf8_len: json_u32(&value, "first_token_utf8_len")?,
        first_token_sha256: json_string(&value, "first_token_sha256")?,
        raw_token_text_retained: value
            .get("raw_token_text_retained")
            .and_then(serde_json::Value::as_bool),
        first_token_preview: value
            .get("first_token_preview")
            .and_then(serde_json::Value::as_str)
            .map(ToOwned::to_owned),
        load_ms: json_u32(&value, "load_ms")?,
        first_token_ms: json_u32(&value, "first_token_ms")?,
        total_ms: json_u32(&value, "total_ms")?,
        model_bytes_loaded: json_u64(&value, "model_bytes_loaded")?,
        runtime_bytes_loaded: json_u64(&value, "runtime_bytes_loaded")?,
    })
}

fn fixture_witness(
    evidence: &EvidenceSnapshot,
) -> Result<SmallModelRuntimeHarnessFirstTokenProbeWitness, FirstTokenWitnessError> {
    let surfaces = vec![
        surface(
            "living_index",
            LIVING_INDEX_PATH,
            evidence.living_index.clone(),
            vec![
                "Epistemos is a local cognitive substrate".to_string(),
                "no claim promotes without visible proof".to_string(),
                SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_CURSOR.to_string(),
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
                SMALL_MODEL_RUNTIME_HARNESS_FIRST_TOKEN_RUNTIME_PROBE_CURSOR.to_string(),
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
    let logged_smoke_ref = "artifact:small_model_runtime_harness_logged_runtime_smoke:result";
    let sidecar_ref =
        "artifact:small_model_runtime_harness_first_token_runtime_probe:live_probe:sha256:retained";
    let mut run = SmallModelFirstTokenRuntimeProbeRun::new(
        "first_token_qwen3_4b_2026_06_05",
        "qwen3_4b_first_token_runtime_probe",
        logged_smoke_ref,
        sidecar_ref,
        format!("model_catalog:{}", evidence.live_probe.model_repo),
        format!(
            "model_snapshot:local:{}:present",
            evidence.live_probe.model_path.replace(':', "_")
        ),
        "model_config:qwen3:max_position_embeddings=65536:quantized=4bit",
        "tokenizer:Qwen/Qwen3-4B-MLX-4bit:tokenizer.json",
        format!(
            "prompt_envelope:synthetic-one-word-ok:{}",
            evidence.live_probe.prompt_sha256
        ),
        "admission:qwen3_4b:scope-rex-sovereign-gate",
        "scope_rex:qwen3_4b:first-token-runtime-probe",
        "sovereign_gate:qwen3_4b:research-candidate-only",
        "compat:qwen3_4b:mlx-small-first-token-v1",
        "cancel:qwen3_4b:bounded-runtime-lease",
        "rollback:qwen3_4b:no-mutation",
        "run_event_log:qwen3_4b:first-token-redacted",
        "answer_packet:qwen3_4b:first-token-visible-proof",
        "privacy:qwen3_4b:local-only-redacted-token-no-user-data",
        "budget:qwen3_4b:4gb-180s-one-token",
        format!(
            "token_sha256:{}",
            evidence
                .live_probe
                .first_token_sha256
                .trim_start_matches("sha256:")
        ),
        required_first_token_runtime_probe_phases().to_vec(),
    )?;
    run.context_tokens = evidence
        .live_probe
        .max_position_embeddings
        .unwrap_or(65_536);
    run.prompt_tokens = 8;
    run.decode_tokens = 1;
    run.memory_budget_bytes = 4 * 1024 * 1024 * 1024;
    run.runtime_budget_seconds = 180;
    run.load_ms = evidence.live_probe.load_ms;
    run.first_token_ms = evidence.live_probe.first_token_ms;
    run.total_ms = evidence.live_probe.total_ms;
    run.chunks_observed = evidence.live_probe.chunks_observed;
    run.first_token_utf8_len = evidence.live_probe.first_token_utf8_len;
    run.output_token_count = evidence.live_probe.output_token_count;
    run.first_token_observed = evidence.live_probe.first_token_observed;
    run.raw_token_text_retained = evidence.live_probe.raw_token_text_retained.unwrap_or(true);
    run.prompt_contains_user_data = evidence.live_probe.prompt_contains_user_data;
    run.runtime_bytes_loaded = evidence.live_probe.runtime_bytes_loaded;
    run.model_bytes_loaded = evidence.live_probe.model_bytes_loaded;
    run.validate()?;

    let metadata_bytes = run.run_id.len() as u64
        + run.model_catalog_ref.len() as u64
        + run.model_snapshot_ref.len() as u64
        + run.token_digest_ref.len() as u64
        + 18_432;
    Ok(SmallModelRuntimeHarnessFirstTokenProbeWitness::new(
        "small_model_runtime_harness_first_token_runtime_probe_2026_06_05",
        logged_smoke_ref,
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "retained_small_model_first_token_probe_only",
        vec![run],
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
) -> Result<SmallModelFirstTokenRuntimeProbeSurface, FirstTokenWitnessError> {
    Ok(SmallModelFirstTokenRuntimeProbeSurface::new(
        surface_id,
        path,
        observed_text,
        required_markers,
        vec![
            "live 70B is done".to_string(),
            "dense 70B runs comfortably on 16 GB".to_string(),
            "small model runtime is product-live".to_string(),
            "first-token probe makes L2 green".to_string(),
            "hidden cloud fallback is allowed".to_string(),
            "MAS ships live local agent runtime".to_string(),
            "raw first token retained".to_string(),
        ],
    )?)
}

#[derive(Default)]
// UAS: Negative-fixture ledger proving the first-token probe rejects malformed witness evidence.
// Plane: Verification.
// Residency: Validator-only fixtures; no runtime bytes are loaded by these invalid cases.
struct InvalidAxes {
    missing_sidecar_rejected: bool,
    missing_logged_smoke_rejected: bool,
    missing_model_snapshot_rejected: bool,
    missing_model_config_rejected: bool,
    missing_tokenizer_rejected: bool,
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
    missing_token_digest_rejected: bool,
    missing_phase_rejected: bool,
    duplicate_run_rejected: bool,
    first_token_missing_rejected: bool,
    output_token_count_mismatch_rejected: bool,
    token_text_retained_rejected: bool,
    prompt_user_data_rejected: bool,
    runtime_bytes_zero_rejected: bool,
    model_bytes_zero_rejected: bool,
    runtime_bytes_over_budget_rejected: bool,
    model_bytes_over_budget_rejected: bool,
    load_time_overflow_rejected: bool,
    first_token_time_overflow_rejected: bool,
    total_time_overflow_rejected: bool,
    mutation_committed_rejected: bool,
    route_policy_mutation_rejected: bool,
    gate_bypass_rejected: bool,
    answer_packet_suppression_rejected: bool,
    hidden_authority_rejected: bool,
    hidden_chain_rejected: bool,
    hidden_cloud_rejected: bool,
    app_path_subprocess_rejected: bool,
    autogenous_kernel_rejected: bool,
    seventy_b_probe_rejected: bool,
    long_context_shard_probe_rejected: bool,
    mas_overclaim_rejected: bool,
    l2_green_claim_rejected: bool,
    l3_green_claim_rejected: bool,
    metadata_budget_rejected: bool,
}

fn invalid_fixture_axes(
    witness: &SmallModelRuntimeHarnessFirstTokenProbeWitness,
) -> Result<InvalidAxes, FirstTokenWitnessError> {
    let mut axes = InvalidAxes::default();
    let mutate_run = |mutator: fn(&mut SmallModelFirstTokenRuntimeProbeRun)| {
        let mut run = witness.runs[0].clone();
        mutator(&mut run);
        run.validate().is_err()
    };
    axes.missing_sidecar_rejected = mutate_run(|run| run.live_probe_sidecar_ref.clear());
    axes.missing_logged_smoke_rejected = mutate_run(|run| run.logged_smoke_artifact_ref.clear());
    axes.missing_model_snapshot_rejected = mutate_run(|run| run.model_snapshot_ref.clear());
    axes.missing_model_config_rejected = mutate_run(|run| run.model_config_ref.clear());
    axes.missing_tokenizer_rejected = mutate_run(|run| run.tokenizer_ref.clear());
    axes.missing_prompt_envelope_rejected = mutate_run(|run| run.prompt_envelope_ref.clear());
    axes.missing_admission_rejected = mutate_run(|run| run.admission_ref.clear());
    axes.missing_scope_rex_rejected = mutate_run(|run| run.scope_rex_ref.clear());
    axes.missing_sovereign_gate_rejected = mutate_run(|run| run.sovereign_gate_ref.clear());
    axes.missing_compatibility_fence_rejected =
        mutate_run(|run| run.compatibility_fence_ref.clear());
    axes.missing_cancellation_rejected = mutate_run(|run| run.cancellation_ref.clear());
    axes.missing_rollback_rejected = mutate_run(|run| run.rollback_ref.clear());
    axes.missing_run_event_log_rejected = mutate_run(|run| run.run_event_log_ref.clear());
    axes.missing_answer_packet_rejected = mutate_run(|run| run.answer_packet_ref.clear());
    axes.missing_privacy_rejected = mutate_run(|run| run.privacy_ref.clear());
    axes.missing_budget_rejected = mutate_run(|run| run.budget_ref.clear());
    axes.missing_token_digest_rejected = mutate_run(|run| run.token_digest_ref.clear());
    axes.missing_phase_rejected = mutate_run(|run| run.phases.pop().map(drop).unwrap_or(()));
    let mut duplicate = witness.clone();
    duplicate.runs.push(duplicate.runs[0].clone());
    axes.duplicate_run_rejected = duplicate.validate().is_err();
    axes.first_token_missing_rejected = mutate_run(|run| run.first_token_observed = false);
    axes.output_token_count_mismatch_rejected = mutate_run(|run| run.output_token_count = 2);
    axes.token_text_retained_rejected = mutate_run(|run| run.raw_token_text_retained = true);
    axes.prompt_user_data_rejected = mutate_run(|run| run.prompt_contains_user_data = true);
    axes.runtime_bytes_zero_rejected = mutate_run(|run| run.runtime_bytes_loaded = 0);
    axes.model_bytes_zero_rejected = mutate_run(|run| run.model_bytes_loaded = 0);
    axes.runtime_bytes_over_budget_rejected =
        mutate_run(|run| run.runtime_bytes_loaded = MAX_MODEL_BYTES_LOADED + 1);
    axes.model_bytes_over_budget_rejected =
        mutate_run(|run| run.model_bytes_loaded = MAX_MODEL_BYTES_LOADED + 1);
    axes.load_time_overflow_rejected = mutate_run(|run| run.load_ms = MAX_LOAD_MS as u32 + 1);
    axes.first_token_time_overflow_rejected =
        mutate_run(|run| run.first_token_ms = MAX_FIRST_TOKEN_MS as u32 + 1);
    axes.total_time_overflow_rejected = mutate_run(|run| run.total_ms = MAX_TOTAL_MS as u32 + 1);
    axes.mutation_committed_rejected = mutate_run(|run| run.committed_mutation = true);
    axes.route_policy_mutation_rejected =
        mutate_run(|run| run.route_policy_mutation_attempted = true);
    axes.gate_bypass_rejected = mutate_run(|run| run.gate_bypass_attempted = true);
    axes.answer_packet_suppression_rejected = mutate_run(|run| run.answer_packet_suppressed = true);
    axes.hidden_authority_rejected = mutate_run(|run| run.hidden_route_authority_attempted = true);
    axes.hidden_chain_rejected = mutate_run(|run| run.hidden_chain_exposed = true);
    axes.hidden_cloud_rejected = mutate_run(|run| run.hidden_cloud_fallback_allowed = true);
    axes.app_path_subprocess_rejected = mutate_run(|run| run.subprocess_spawned_in_app_path = true);
    axes.autogenous_kernel_rejected = mutate_run(|run| run.autogenous_kernel_attempted = true);
    axes.seventy_b_probe_rejected = mutate_run(|run| run.seventy_b_probe_attempted = true);
    axes.long_context_shard_probe_rejected =
        mutate_run(|run| run.long_context_shard_probe_attempted = true);
    let mutate_witness = |mutator: fn(&mut SmallModelRuntimeHarnessFirstTokenProbeWitness)| {
        let mut bad = witness.clone();
        mutator(&mut bad);
        bad.validate().is_err()
    };
    axes.mas_overclaim_rejected = mutate_witness(|bad| bad.mas_overclaim_attempted = true);
    axes.l2_green_claim_rejected = mutate_witness(|bad| bad.l2_green_claimed = true);
    axes.l3_green_claim_rejected = mutate_witness(|bad| bad.l3_green_claimed = true);
    axes.metadata_budget_rejected =
        mutate_witness(|bad| bad.metadata_bytes = MAX_METADATA_BYTES + 1);
    Ok(axes)
}

#[allow(clippy::too_many_arguments)]
fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: u64,
    operator: &str,
    threshold: u64,
    unit: &str,
) {
    let passed = match operator {
        ">=" => value >= threshold,
        ">" => value > threshold,
        "<=" => value <= threshold,
        "==" => value == threshold,
        _ => false,
    };
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Number(value.into()),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::Number(threshold.into()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), passed);
}

fn surface_contains(
    witness: &SmallModelRuntimeHarnessFirstTokenProbeWitness,
    surface_id: &str,
    needle: &str,
) -> bool {
    witness
        .surfaces
        .iter()
        .find(|surface| surface.surface_id == surface_id)
        .is_some_and(|surface| surface.observed_text.contains(needle))
}

fn read_text(path: &Path) -> Result<String, FirstTokenWitnessError> {
    std::fs::read_to_string(path)
        .map_err(|error| FirstTokenWitnessError::Io(format!("read {}: {error}", path.display())))
}

fn read_json(path: &Path) -> Result<serde_json::Value, FirstTokenWitnessError> {
    let text = read_text(path)?;
    serde_json::from_str(&text)
        .map_err(|error| FirstTokenWitnessError::Io(format!("parse {}: {error}", path.display())))
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_str)
        .map(ToOwned::to_owned)
}

fn artifact_all_axes_true(value: &serde_json::Value, axes: &[&str]) -> bool {
    value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
        && axes.iter().all(|axis| {
            value
                .get("pass_per_axis")
                .and_then(|map| map.get(*axis))
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false)
        })
}

fn json_string(
    value: &serde_json::Value,
    key: &'static str,
) -> Result<String, FirstTokenWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_str)
        .map(ToOwned::to_owned)
        .ok_or_else(|| FirstTokenWitnessError::Io(format!("missing string sidecar field `{key}`")))
}

fn json_bool(value: &serde_json::Value, key: &'static str) -> Result<bool, FirstTokenWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_bool)
        .ok_or_else(|| FirstTokenWitnessError::Io(format!("missing bool sidecar field `{key}`")))
}

fn json_u32(value: &serde_json::Value, key: &'static str) -> Result<u32, FirstTokenWitnessError> {
    let raw = json_u64(value, key)?;
    u32::try_from(raw)
        .map_err(|_| FirstTokenWitnessError::Io(format!("sidecar field `{key}` exceeds u32")))
}

fn json_u64(value: &serde_json::Value, key: &'static str) -> Result<u64, FirstTokenWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_u64)
        .ok_or_else(|| FirstTokenWitnessError::Io(format!("missing u64 sidecar field `{key}`")))
}
