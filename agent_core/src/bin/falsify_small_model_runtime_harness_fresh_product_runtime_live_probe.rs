//! `falsify_small_model_runtime_harness_fresh_product_runtime_live_probe`.
//!
//! This witness validates a retained one-token MLX sidecar generated under
//! the fresh product-runtime safety lease. It does not rerun the model; it
//! verifies the sidecar's privacy, byte, timing, MAS/Pro, and no-promotion
//! contract before queuing a product AnswerPacket packaging probe.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    fresh_product_runtime_live_probe_max_first_token_ms,
    fresh_product_runtime_live_probe_max_load_ms, fresh_product_runtime_live_probe_max_total_ms,
    fresh_product_runtime_live_probe_metadata_budget_bytes,
    fresh_product_runtime_live_probe_route_authority,
    fresh_product_runtime_safety_lease_max_model_budget_bytes,
    fresh_product_runtime_safety_lease_max_runtime_budget_bytes,
    required_fresh_product_runtime_live_probe_phases, ProStatus, ProductBuild,
    SmallModelFreshProductRuntimeLiveProbeError, SmallModelFreshProductRuntimeLiveProbeRecord,
    SmallModelFreshProductRuntimeLiveProbeWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallModelRuntimeHarnessFreshProductRuntimeLiveProbe";
const FIXTURE_ID: &str = "small_model_runtime_harness_fresh_product_runtime_live_probe_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_small_model_runtime_harness_fresh_product_runtime_live_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_live_probe/result.json";
const SIDECAR: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_live_probe/live_probe.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const SAFETY_LEASE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_safety_lease/result.json";
const EXPECTED_OUTPUT_TOKENS: u64 = 1;
const EXPECTED_CHUNKS: u64 = 1;

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-live-probe:witness-error
// Plane: Verification
// Residency: falsifier IO/JSON/primitive error wrapper.
enum FreshProductRuntimeLiveProbeWitnessError {
    Primitive(SmallModelFreshProductRuntimeLiveProbeError),
    Io(String),
    Json(String),
}

impl std::fmt::Display for FreshProductRuntimeLiveProbeWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) | Self::Json(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for FreshProductRuntimeLiveProbeWitnessError {}

impl From<SmallModelFreshProductRuntimeLiveProbeError>
    for FreshProductRuntimeLiveProbeWitnessError
{
    fn from(value: SmallModelFreshProductRuntimeLiveProbeError) -> Self {
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

fn build_artifact() -> Result<
    agent_core::falsifier_artifacts::FalsifierArtifact,
    FreshProductRuntimeLiveProbeWitnessError,
> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fresh_product_runtime_live_probe_witness(&evidence)?;
    let deterministic =
        witness.address() == fresh_product_runtime_live_probe_witness(&evidence)?.address();
    let invalid_axes = invalid_rejections(&witness);
    let metrics = witness.metrics();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_fresh_product_runtime_safety_lease_pass",
            evidence.safety_lease_pass,
        ),
        (
            "guard_cursor_fresh_product_runtime_live_probe_or_advanced",
            evidence.guard_next_existing_work
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_fresh_product_runtime_live_probe_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_NEXT_CURSOR,
        ),
        (
            "product_status_gated",
            witness.product_build == ProductBuild::Pro && witness.pro_status == ProStatus::Gated,
        ),
        (
            "route_authority_l1_live_probe_only",
            witness.route_authority == fresh_product_runtime_live_probe_route_authority(),
        ),
        ("live_probe_sidecar_present", evidence.sidecar_present),
        (
            "sidecar_scope_l1_only",
            witness.live_probe.scope == fresh_product_runtime_live_probe_route_authority(),
        ),
        (
            "sidecar_helper_bound",
            witness.live_probe.helper == "manual_mlx_lm_stream_generate_product_lease_helper",
        ),
        (
            "model_repo_bound",
            witness.live_probe.model_repo == "Qwen/Qwen3-4B-MLX-4bit",
        ),
        (
            "model_path_local_epistemos",
            witness.live_probe.model_path.starts_with(
                "/Users/jojo/Library/Application Support/Epistemos/Models/text/hub/models--Qwen--Qwen3-4B-MLX-4bit/snapshots/",
            ),
        ),
        ("model_path_exists", evidence.model_path_exists),
        ("model_type_qwen3_bound", witness.live_probe.model_type == "qwen3"),
        ("quantization_4bit_bound", witness.live_probe.quantization_bits == 4),
        (
            "context_limit_bound",
            witness.live_probe.max_position_embeddings == 65_536,
        ),
        (
            "product_surface_bound",
            witness.live_probe.product_surface == "note_chat_fresh_product_runtime",
        ),
        (
            "safety_lease_ref_bound",
            witness
                .live_probe
                .safety_lease_ref
                .starts_with("artifact:small_model_runtime_harness_fresh_product_runtime_safety_lease:"),
        ),
        (
            "synthetic_prompt_bound",
            witness.live_probe.prompt_label == "synthetic_one_safe_word_ok_product_path",
        ),
        (
            "prompt_hash_bound",
            witness.live_probe.prompt_sha256.starts_with("sha256:"),
        ),
        ("no_prompt_user_data", !witness.live_probe.prompt_contains_user_data),
        ("first_token_observed", witness.live_probe.first_token_observed),
        (
            "exactly_one_chunk",
            witness.live_probe.chunks_observed == EXPECTED_CHUNKS,
        ),
        (
            "exactly_one_output_token",
            witness.live_probe.output_token_count == EXPECTED_OUTPUT_TOKENS,
        ),
        (
            "redacted_token_digest_bound",
            witness.live_probe.first_token_sha256.starts_with("sha256:"),
        ),
        (
            "raw_token_text_not_retained",
            !witness.live_probe.raw_token_text_retained,
        ),
        (
            "load_latency_under_budget",
            witness.live_probe.load_ms <= fresh_product_runtime_live_probe_max_load_ms(),
        ),
        (
            "first_token_latency_under_budget",
            witness.live_probe.first_token_ms
                <= fresh_product_runtime_live_probe_max_first_token_ms(),
        ),
        (
            "total_latency_under_budget",
            witness.live_probe.total_ms <= fresh_product_runtime_live_probe_max_total_ms(),
        ),
        (
            "model_bytes_nonzero_within_lease",
            witness.live_probe.fresh_product_model_bytes_loaded > 0
                && witness.live_probe.fresh_product_model_bytes_loaded
                    <= fresh_product_runtime_safety_lease_max_model_budget_bytes(),
        ),
        (
            "runtime_bytes_nonzero_within_lease",
            witness.live_probe.fresh_product_runtime_bytes_loaded > 0
                && witness.live_probe.fresh_product_runtime_bytes_loaded
                    <= fresh_product_runtime_safety_lease_max_runtime_budget_bytes(),
        ),
        (
            "runtime_route_scope_l1_only",
            witness.live_probe.runtime_route_scope == "product_path_l1_falsifier_only",
        ),
        (
            "answer_packet_ref_bound",
            witness.live_probe.answer_packet_ref.starts_with("answer_packet:"),
        ),
        (
            "run_event_log_bound",
            witness.live_probe.run_event_log_ref.starts_with("run_event_log:"),
        ),
        ("rollback_bound", witness.live_probe.rollback_ref.starts_with("rollback:")),
        (
            "cancellation_bound",
            witness.live_probe.cancellation_ref.starts_with("cancel:"),
        ),
        (
            "admission_bound",
            witness.live_probe.admission_ref.starts_with("admission:"),
        ),
        (
            "scope_rex_bound",
            witness.live_probe.scope_rex_ref.starts_with("scope_rex:"),
        ),
        (
            "sovereign_gate_bound",
            witness.live_probe.sovereign_gate_ref.starts_with("sovereign_gate:"),
        ),
        (
            "privacy_fence_bound",
            witness.live_probe.privacy_ref.starts_with("privacy:"),
        ),
        ("budget_bound", witness.live_probe.budget_ref.starts_with("budget:")),
        ("l1_l2_l3_separation_bound", witness.l1_l2_l3_separated),
        ("mas_floor_preserved", witness.mas_floor_preserved),
        (
            "no_product_route_promotion",
            !witness.live_probe.product_route_promoted,
        ),
        ("no_mas_claim_promotion", !witness.live_probe.mas_claim_promoted),
        ("no_l2_green_claim", !witness.live_probe.l2_claim_promoted),
        ("no_l3_green_claim", !witness.live_probe.l3_claim_promoted),
        (
            "no_hidden_cloud",
            !witness.live_probe.hidden_cloud_fallback_allowed,
        ),
        ("no_hidden_chain", !witness.live_probe.hidden_chain_exposed),
        (
            "no_route_policy_mutation",
            !witness.live_probe.route_policy_mutated,
        ),
        (
            "no_app_path_subprocess_spawn",
            !witness.live_probe.app_path_subprocess_spawned,
        ),
        (
            "no_autogenous_kernel_attempt",
            !witness.live_probe.autogenous_kernel_attempted,
        ),
        (
            "no_70b_probe_attempt",
            !witness.live_probe.seventy_b_probe_attempted,
        ),
        (
            "no_long_context_shard_probe",
            !witness.live_probe.long_context_shard_probe_attempted,
        ),
        (
            "next_answer_packet_probe_cursor_bound",
            witness.next_cursor
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_NEXT_CURSOR,
        ),
        (
            "required_phases_bound",
            metrics.phase_count == required_fresh_product_runtime_live_probe_phases().len() as u64,
        ),
        (
            "metadata_bound",
            witness.metadata_bytes <= fresh_product_runtime_live_probe_metadata_budget_bytes(),
        ),
        (
            "small_model_runtime_harness_fresh_product_runtime_live_probe_address_deterministic",
            deterministic,
        ),
        (
            "missing_safety_lease_ref_rejected",
            invalid_axes.missing_safety_lease_ref_rejected,
        ),
        (
            "missing_sidecar_field_rejected",
            invalid_axes.missing_sidecar_field_rejected,
        ),
        (
            "prompt_user_data_rejected",
            invalid_axes.prompt_user_data_rejected,
        ),
        (
            "missing_first_token_rejected",
            invalid_axes.missing_first_token_rejected,
        ),
        (
            "multi_chunk_rejected",
            invalid_axes.multi_chunk_rejected,
        ),
        (
            "multi_output_token_rejected",
            invalid_axes.multi_output_token_rejected,
        ),
        (
            "raw_token_text_rejected",
            invalid_axes.raw_token_text_rejected,
        ),
        (
            "invalid_token_digest_rejected",
            invalid_axes.invalid_token_digest_rejected,
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
            "latency_over_budget_rejected",
            invalid_axes.latency_over_budget_rejected,
        ),
        (
            "missing_answer_packet_rejected",
            invalid_axes.missing_answer_packet_rejected,
        ),
        (
            "missing_run_event_log_rejected",
            invalid_axes.missing_run_event_log_rejected,
        ),
        (
            "missing_rollback_rejected",
            invalid_axes.missing_rollback_rejected,
        ),
        (
            "product_route_promotion_rejected",
            invalid_axes.product_route_promotion_rejected,
        ),
        (
            "mas_claim_promotion_rejected",
            invalid_axes.mas_claim_promotion_rejected,
        ),
        (
            "l2_green_claim_rejected",
            invalid_axes.l2_green_claim_rejected,
        ),
        (
            "l3_green_claim_rejected",
            invalid_axes.l3_green_claim_rejected,
        ),
        ("hidden_cloud_rejected", invalid_axes.hidden_cloud_rejected),
        ("hidden_chain_rejected", invalid_axes.hidden_chain_rejected),
        (
            "route_policy_mutation_rejected",
            invalid_axes.route_policy_mutation_rejected,
        ),
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
            "next_cursor_mismatch_rejected",
            invalid_axes.next_cursor_mismatch_rejected,
        ),
        (
            "metadata_budget_rejected",
            invalid_axes.metadata_budget_rejected,
        ),
    ];
    for (axis, passed) in bool_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            passed,
        );
    }

    for (axis, value, threshold, unit) in [
        (
            "phase_count",
            metrics.phase_count,
            required_fresh_product_runtime_live_probe_phases().len() as u64,
            "count",
        ),
        (
            "chunks_observed",
            metrics.chunks_observed,
            EXPECTED_CHUNKS,
            "count",
        ),
        (
            "output_token_count",
            metrics.output_token_count,
            EXPECTED_OUTPUT_TOKENS,
            "count",
        ),
    ] {
        add_count_eq_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            value,
            threshold,
            unit,
        );
    }
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "first_token_utf8_len",
        metrics.first_token_utf8_len,
        ">",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "load_ms",
        metrics.load_ms,
        "<=",
        fresh_product_runtime_live_probe_max_load_ms(),
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "first_token_ms",
        metrics.first_token_ms,
        "<=",
        fresh_product_runtime_live_probe_max_first_token_ms(),
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "total_ms",
        metrics.total_ms,
        "<=",
        fresh_product_runtime_live_probe_max_total_ms(),
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fresh_product_runtime_bytes_loaded",
        metrics.fresh_runtime_bytes_loaded,
        "<=",
        fresh_product_runtime_safety_lease_max_runtime_budget_bytes(),
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fresh_product_model_bytes_loaded",
        metrics.fresh_model_bytes_loaded,
        "<=",
        fresh_product_runtime_safety_lease_max_model_budget_bytes(),
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes",
        metrics.metadata_bytes,
        "<=",
        fresh_product_runtime_live_probe_metadata_budget_bytes(),
        "bytes",
    );
    add_label_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "capability_route_status",
        &evidence.capability_route_status,
        "vault_research_route_with_packetized_mitigation",
        "status",
    );
    add_label_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_NEXT_CURSOR,
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_NEXT_CURSOR,
        "cursor",
    );
    let address = witness.address();
    add_label_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_fresh_product_runtime_live_probe_address",
        &address,
        &address,
        "sha256",
    );
    measurements.insert(
        "probe_id".to_string(),
        Measurement {
            value: serde_json::json!(witness.live_probe.probe_id),
            unit: "id".to_string(),
        },
    );
    pass_per_axis.insert("probe_id".to_string(), true);
    thresholds.insert(
        "probe_id".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "id".to_string(),
        },
    );

    let anomalies = vec![serde_json::json!({
        "kind": "fresh_product_runtime_live_probe_l1_only",
        "detail": "A bounded local Qwen3-4B MLX sidecar observed exactly one redacted first token under the fresh product-runtime safety lease. This advances L1 only; L2 remains vault_research_route_with_packetized_mitigation and L3 still needs product AnswerPacket packaging/WRV before any product claim promotes."
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
        notes: "L1 F-SmallModelRuntimeHarnessFreshProductRuntimeLiveProbe: validates a bounded one-token fresh product-runtime Qwen3-4B sidecar with redacted token hash, byte/timing budgets, safety-lease refs, rollback, RunEventLog, AnswerPacket ref, privacy, MAS/Pro honesty, and no L2/L3/product promotion."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn fresh_product_runtime_live_probe_witness(
    evidence: &EvidenceSnapshot,
) -> Result<SmallModelFreshProductRuntimeLiveProbeWitness, FreshProductRuntimeLiveProbeWitnessError>
{
    SmallModelFreshProductRuntimeLiveProbeWitness::new(
        "small-model-fresh-product-runtime-live-probe:v1",
        "artifact:small_model_runtime_harness_fresh_product_runtime_safety_lease:result",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_overall_pass,
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::Gated,
        fresh_product_runtime_live_probe_route_authority(),
        evidence.live_probe.clone(),
        required_fresh_product_runtime_live_probe_phases(),
        true,
        true,
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_LIVE_PROBE_NEXT_CURSOR,
        evidence.metadata_bytes,
    )
    .map_err(FreshProductRuntimeLiveProbeWitnessError::from)
}

// UAS: uas:small-model-runtime-harness-fresh-product-runtime-live-probe:evidence-snapshot
// Plane: Verification
// Residency: generated sidecar plus current guard/kernel state.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    safety_lease_pass: bool,
    sidecar_present: bool,
    model_path_exists: bool,
    live_probe: SmallModelFreshProductRuntimeLiveProbeRecord,
    metadata_bytes: u64,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, FreshProductRuntimeLiveProbeWitnessError> {
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        let safety_lease = read_json(Path::new(SAFETY_LEASE_PATH))?;
        let sidecar = read_json(Path::new(SIDECAR))?;
        let live_probe = live_probe_from_sidecar(&sidecar)?;
        let model_path_exists = Path::new(&live_probe.model_path).exists();
        let metadata_bytes = std::fs::metadata(SIDECAR)
            .map(|metadata| metadata.len())
            .unwrap_or(0);
        Ok(Self {
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_default(),
            capability_overall_pass: json_bool(&capability, "overall_pass")?,
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_default(),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_default(),
            safety_lease_pass: artifact_all_axes_true(&safety_lease),
            sidecar_present: Path::new(SIDECAR).exists(),
            model_path_exists,
            live_probe,
            metadata_bytes,
        })
    }
}

fn live_probe_from_sidecar(
    sidecar: &serde_json::Value,
) -> Result<SmallModelFreshProductRuntimeLiveProbeRecord, FreshProductRuntimeLiveProbeWitnessError>
{
    SmallModelFreshProductRuntimeLiveProbeRecord::new(
        json_string(sidecar, "probe_id")?,
        json_string(sidecar, "generated_at_utc")?,
        json_string(sidecar, "scope")?,
        json_string(sidecar, "helper")?,
        json_string(sidecar, "model_repo")?,
        json_string(sidecar, "model_path")?,
        json_string(sidecar, "model_type")?,
        json_u64(sidecar, "quantization_bits")?,
        json_u64(sidecar, "max_position_embeddings")?,
        json_string(sidecar, "product_surface")?,
        json_string(sidecar, "safety_lease_ref")?,
        json_string(sidecar, "prompt_label")?,
        json_string(sidecar, "prompt_sha256")?,
        json_bool(sidecar, "prompt_contains_user_data")?,
        json_bool(sidecar, "first_token_observed")?,
        json_u64(sidecar, "chunks_observed")?,
        json_u64(sidecar, "output_token_count")?,
        json_u64(sidecar, "first_token_utf8_len")?,
        json_string(sidecar, "first_token_sha256")?,
        json_bool(sidecar, "raw_token_text_retained")?,
        json_u64(sidecar, "load_ms")?,
        json_u64(sidecar, "first_token_ms")?,
        json_u64(sidecar, "total_ms")?,
        json_u64(sidecar, "fresh_product_model_bytes_loaded")?,
        json_u64(sidecar, "fresh_product_runtime_bytes_loaded")?,
        json_string(sidecar, "runtime_route_scope")?,
        json_string(sidecar, "answer_packet_ref")?,
        json_string(sidecar, "run_event_log_ref")?,
        json_string(sidecar, "rollback_ref")?,
        json_string(sidecar, "cancellation_ref")?,
        json_string(sidecar, "admission_ref")?,
        json_string(sidecar, "scope_rex_ref")?,
        json_string(sidecar, "sovereign_gate_ref")?,
        json_string(sidecar, "privacy_ref")?,
        json_string(sidecar, "budget_ref")?,
        json_bool(sidecar, "product_route_promoted")?,
        json_bool(sidecar, "mas_claim_promoted")?,
        json_bool(sidecar, "l2_claim_promoted")?,
        json_bool(sidecar, "l3_claim_promoted")?,
        json_bool(sidecar, "seventy_b_probe_attempted")?,
        json_bool(sidecar, "long_context_shard_probe_attempted")?,
        json_bool(sidecar, "autogenous_kernel_attempted")?,
        json_bool(sidecar, "hidden_cloud_fallback_allowed")?,
        json_bool(sidecar, "hidden_chain_exposed")?,
        json_bool(sidecar, "route_policy_mutated")?,
        json_bool(sidecar, "app_path_subprocess_spawned")?,
    )
    .map_err(FreshProductRuntimeLiveProbeWitnessError::from)
}

#[derive(Default)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-live-probe:invalid-axes
// Plane: Verification
// Residency: invalid fixture coverage for live sidecar rejection paths.
struct InvalidAxes {
    missing_safety_lease_ref_rejected: bool,
    missing_sidecar_field_rejected: bool,
    prompt_user_data_rejected: bool,
    missing_first_token_rejected: bool,
    multi_chunk_rejected: bool,
    multi_output_token_rejected: bool,
    raw_token_text_rejected: bool,
    invalid_token_digest_rejected: bool,
    runtime_bytes_zero_rejected: bool,
    model_bytes_zero_rejected: bool,
    runtime_bytes_over_budget_rejected: bool,
    model_bytes_over_budget_rejected: bool,
    latency_over_budget_rejected: bool,
    missing_answer_packet_rejected: bool,
    missing_run_event_log_rejected: bool,
    missing_rollback_rejected: bool,
    product_route_promotion_rejected: bool,
    mas_claim_promotion_rejected: bool,
    l2_green_claim_rejected: bool,
    l3_green_claim_rejected: bool,
    hidden_cloud_rejected: bool,
    hidden_chain_rejected: bool,
    route_policy_mutation_rejected: bool,
    app_path_subprocess_rejected: bool,
    autogenous_kernel_rejected: bool,
    seventy_b_probe_rejected: bool,
    long_context_shard_probe_rejected: bool,
    next_cursor_mismatch_rejected: bool,
    metadata_budget_rejected: bool,
}

fn invalid_rejections(witness: &SmallModelFreshProductRuntimeLiveProbeWitness) -> InvalidAxes {
    let mutate = |mutator: fn(&mut SmallModelFreshProductRuntimeLiveProbeWitness)| {
        let mut candidate = witness.clone();
        mutator(&mut candidate);
        candidate.validate().is_err()
    };
    InvalidAxes {
        missing_safety_lease_ref_rejected: mutate(|candidate| {
            candidate.safety_lease_artifact_ref.clear();
        }),
        missing_sidecar_field_rejected: mutate_probe(witness, |probe| {
            probe.probe_id.clear();
        }),
        prompt_user_data_rejected: mutate_probe(witness, |probe| {
            probe.prompt_contains_user_data = true;
        }),
        missing_first_token_rejected: mutate_probe(witness, |probe| {
            probe.first_token_observed = false;
        }),
        multi_chunk_rejected: mutate_probe(witness, |probe| {
            probe.chunks_observed = 2;
        }),
        multi_output_token_rejected: mutate_probe(witness, |probe| {
            probe.output_token_count = 2;
        }),
        raw_token_text_rejected: mutate_probe(witness, |probe| {
            probe.raw_token_text_retained = true;
        }),
        invalid_token_digest_rejected: mutate_probe(witness, |probe| {
            probe.first_token_sha256 = "sha256:not-hex".to_string();
        }),
        runtime_bytes_zero_rejected: mutate_probe(witness, |probe| {
            probe.fresh_product_runtime_bytes_loaded = 0;
        }),
        model_bytes_zero_rejected: mutate_probe(witness, |probe| {
            probe.fresh_product_model_bytes_loaded = 0;
        }),
        runtime_bytes_over_budget_rejected: mutate_probe(witness, |probe| {
            probe.fresh_product_runtime_bytes_loaded =
                fresh_product_runtime_safety_lease_max_runtime_budget_bytes() + 1;
        }),
        model_bytes_over_budget_rejected: mutate_probe(witness, |probe| {
            probe.fresh_product_model_bytes_loaded =
                fresh_product_runtime_safety_lease_max_model_budget_bytes() + 1;
        }),
        latency_over_budget_rejected: mutate_probe(witness, |probe| {
            probe.total_ms = fresh_product_runtime_live_probe_max_total_ms() + 1;
        }),
        missing_answer_packet_rejected: mutate_probe(witness, |probe| {
            probe.answer_packet_ref.clear();
        }),
        missing_run_event_log_rejected: mutate_probe(witness, |probe| {
            probe.run_event_log_ref.clear();
        }),
        missing_rollback_rejected: mutate_probe(witness, |probe| {
            probe.rollback_ref.clear();
        }),
        product_route_promotion_rejected: mutate_probe(witness, |probe| {
            probe.product_route_promoted = true;
        }),
        mas_claim_promotion_rejected: mutate_probe(witness, |probe| {
            probe.mas_claim_promoted = true;
        }),
        l2_green_claim_rejected: mutate_probe(witness, |probe| {
            probe.l2_claim_promoted = true;
        }),
        l3_green_claim_rejected: mutate_probe(witness, |probe| {
            probe.l3_claim_promoted = true;
        }),
        hidden_cloud_rejected: mutate_probe(witness, |probe| {
            probe.hidden_cloud_fallback_allowed = true;
        }),
        hidden_chain_rejected: mutate_probe(witness, |probe| {
            probe.hidden_chain_exposed = true;
        }),
        route_policy_mutation_rejected: mutate_probe(witness, |probe| {
            probe.route_policy_mutated = true;
        }),
        app_path_subprocess_rejected: mutate_probe(witness, |probe| {
            probe.app_path_subprocess_spawned = true;
        }),
        autogenous_kernel_rejected: mutate_probe(witness, |probe| {
            probe.autogenous_kernel_attempted = true;
        }),
        seventy_b_probe_rejected: mutate_probe(witness, |probe| {
            probe.seventy_b_probe_attempted = true;
        }),
        long_context_shard_probe_rejected: mutate_probe(witness, |probe| {
            probe.long_context_shard_probe_attempted = true;
        }),
        next_cursor_mismatch_rejected: mutate(|candidate| {
            candidate.next_cursor = "done".to_string();
        }),
        metadata_budget_rejected: mutate(|candidate| {
            candidate.metadata_bytes = fresh_product_runtime_live_probe_metadata_budget_bytes() + 1;
        }),
    }
}

fn mutate_probe(
    witness: &SmallModelFreshProductRuntimeLiveProbeWitness,
    mutator: fn(&mut SmallModelFreshProductRuntimeLiveProbeRecord),
) -> bool {
    let mut candidate = witness.clone();
    mutator(&mut candidate.live_probe);
    candidate.validate().is_err()
}

fn read_json(path: &Path) -> Result<serde_json::Value, FreshProductRuntimeLiveProbeWitnessError> {
    let text = std::fs::read_to_string(path)
        .map_err(|error| FreshProductRuntimeLiveProbeWitnessError::Io(error.to_string()))?;
    serde_json::from_str(&text)
        .map_err(|error| FreshProductRuntimeLiveProbeWitnessError::Json(error.to_string()))
}

fn json_string(
    value: &serde_json::Value,
    key: &'static str,
) -> Result<String, FreshProductRuntimeLiveProbeWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_str)
        .map(ToString::to_string)
        .ok_or_else(|| {
            FreshProductRuntimeLiveProbeWitnessError::Primitive(
                SmallModelFreshProductRuntimeLiveProbeError::MissingField(key),
            )
        })
}

fn json_bool(
    value: &serde_json::Value,
    key: &'static str,
) -> Result<bool, FreshProductRuntimeLiveProbeWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_bool)
        .ok_or_else(|| {
            FreshProductRuntimeLiveProbeWitnessError::Primitive(
                SmallModelFreshProductRuntimeLiveProbeError::MissingField(key),
            )
        })
}

fn json_u64(
    value: &serde_json::Value,
    key: &'static str,
) -> Result<u64, FreshProductRuntimeLiveProbeWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_u64)
        .ok_or_else(|| {
            FreshProductRuntimeLiveProbeWitnessError::Primitive(
                SmallModelFreshProductRuntimeLiveProbeError::MissingField(key),
            )
        })
}

fn artifact_all_axes_true(value: &serde_json::Value) -> bool {
    value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        == Some(true)
        && value
            .get("pass_per_axis")
            .and_then(serde_json::Value::as_object)
            .map(|axes| !axes.is_empty() && axes.values().all(|axis| axis.as_bool() == Some(true)))
            .unwrap_or(false)
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_str)
        .map(ToString::to_string)
}

fn add_label_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
    expected: &str,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(expected),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual == expected);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sidecar_loader_rejects_missing_required_field() {
        let sidecar = serde_json::json!({
            "probe_id": "id"
        });
        assert!(live_probe_from_sidecar(&sidecar).is_err());
    }

    #[test]
    fn artifact_all_axes_requires_overall_pass_and_axes() {
        let value = serde_json::json!({
            "overall_pass": true,
            "pass_per_axis": {"a": true, "b": true}
        });
        assert!(artifact_all_axes_true(&value));
        let value = serde_json::json!({
            "overall_pass": true,
            "pass_per_axis": {"a": true, "b": false}
        });
        assert!(!artifact_all_axes_true(&value));
    }
}
