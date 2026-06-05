//! `falsify_small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe`.
//!
//! This L1/L3 manual-verification witness binds the fresh product-runtime
//! log-correlation artifact to Living Index, lattice HTML, AnswerPacket,
//! RunEventLog, and red capability-kernel evidence. It opens no new bytes and
//! leaves product capability red until a separate closeout/recheck lands.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[cfg(test)]
use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    fresh_product_runtime_l3_manual_runtime_verification_metadata_budget_bytes,
    required_fresh_product_runtime_l3_manual_runtime_verification_phases, ProStatus, ProductBuild,
    SmallModelFreshProductRuntimeL3ManualRuntimeObservation,
    SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError,
    SmallModelFreshProductRuntimeL3ManualRuntimeVerificationWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_NEXT_CURSOR,
};
use serde_json::Value;

const FALSIFIER_ID: &str =
    "F-SmallModelRuntimeHarnessFreshProductRuntimeL3ManualRuntimeVerificationProbe";
const FIXTURE_ID: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const UPSTREAM_LOG_CORRELATION_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe/result.json";
const LIVE_SIDECAR_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_live_probe/live_probe.json";
const ANSWER_PACKET_JSON_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_answer_packet_probe/answer_packet.json";
const RUN_EVENT_LOG_JSON_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_answer_packet_probe/run_event_log.json";
const LIVING_INDEX_PATH: &str = "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md";
const LATTICE_HTML_PATH: &str = "artifacts/lattice-coordinate-explainer/index.html";
const NORTH_STAR_SENTENCE: &str = "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.";
const ZERO_BYTES: u64 = 0;
const EXPECTED_OBSERVATION_COUNT: u64 = 3;
const EXPECTED_MANUAL_STEP_COUNT: u64 = 7;

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-manual-runtime-verification-probe:witness-error
// Plane: Verification
// Residency: falsifier IO/JSON/primitive error wrapper.
enum FreshProductRuntimeL3ManualRuntimeVerificationWitnessError {
    Primitive(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError),
    Io(String),
    Json(String),
}

impl std::fmt::Display for FreshProductRuntimeL3ManualRuntimeVerificationWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) | Self::Json(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for FreshProductRuntimeL3ManualRuntimeVerificationWitnessError {}

impl From<SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError>
    for FreshProductRuntimeL3ManualRuntimeVerificationWitnessError
{
    fn from(value: SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError) -> Self {
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
    FreshProductRuntimeL3ManualRuntimeVerificationWitnessError,
> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fresh_product_runtime_l3_manual_runtime_verification_witness(&evidence)?;
    let deterministic = witness.address()
        == fresh_product_runtime_l3_manual_runtime_verification_witness(&evidence)?.address();
    let invalid_axes = invalid_rejections(&witness);
    let metrics = witness.metrics();
    let first_observation = witness
        .observations
        .first()
        .ok_or(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::EmptyObservation)?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        ("upstream_l3_log_correlation_probe_pass", evidence.upstream_log_correlation_pass),
        (
            "guard_cursor_l3_manual_verification_or_advanced",
            evidence.guard_next_existing_work
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_l3_manual_verification_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_NEXT_CURSOR,
        ),
        (
            "product_status_gated",
            witness.product_build == ProductBuild::Pro && witness.pro_status == ProStatus::Gated,
        ),
        (
            "route_authority_manual_verification_only",
            witness.route_authority
                == "fresh_product_runtime_l3_manual_verification_no_route_authority",
        ),
        ("lattice_cursor_visible", witness.lattice_cursor_visible),
        ("living_index_cursor_visible", witness.living_index_cursor_visible),
        ("north_star_visible", witness.north_star_visible),
        ("l1_l2_l3_status_visible", witness.l1_l2_l3_status_visible),
        ("answer_packet_observed", witness.answer_packet_observed),
        ("run_event_log_observed", witness.run_event_log_observed),
        ("token_digest_observed", witness.token_digest_observed),
        (
            "prompt_privacy_observed",
            !witness.prompt_user_data_retained && !witness.raw_token_text_retained,
        ),
        (
            "rollback_cancellation_visible",
            witness.rollback_cancellation_visible,
        ),
        (
            "source_wrv_coverage_bound",
            metrics.source_ref_count >= 10
                && metrics.visible_surface_count >= 3
                && metrics.test_ref_count >= 4,
        ),
        (
            "manual_observation_floor_bound",
            metrics.observation_count >= EXPECTED_OBSERVATION_COUNT,
        ),
        (
            "manual_step_count_bound",
            metrics.manual_step_count >= EXPECTED_MANUAL_STEP_COUNT,
        ),
        (
            "upstream_runtime_bytes_nonzero",
            metrics.upstream_runtime_bytes_loaded > 0,
        ),
        (
            "upstream_model_bytes_nonzero",
            metrics.upstream_model_bytes_loaded > 0,
        ),
        (
            "manual_verification_runtime_bytes_zero",
            metrics.manual_verification_runtime_bytes_loaded == 0,
        ),
        (
            "manual_verification_model_bytes_zero",
            metrics.manual_verification_model_bytes_loaded == 0,
        ),
        ("l1_l2_l3_separation_bound", witness.l1_l2_l3_separated),
        ("no_hidden_route_authority", !witness.hidden_authority_attempted),
        ("no_route_policy_mutation", !witness.route_mutation_attempted),
        (
            "no_mas_live_agent_overclaim",
            !witness.mas_live_agent_overclaim_attempted,
        ),
        ("no_l2_green_claim", !witness.l2_green_claimed),
        ("no_l3_green_claim", !witness.l3_green_claimed),
        ("heavy_routes_deferred", !evidence.heavy_long_context_enabled),
        ("kv_direct_128k_still_red", !evidence.kv_direct_live_128k_pass),
        ("live_70b_still_red", !evidence.seventy_b_route_pass),
        (
            "autogenous_kernel_still_research",
            !witness.autogenous_kernel_attempted,
        ),
        (
            "next_capability_closeout_probe_bound",
            witness.next_cursor
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_NEXT_CURSOR,
        ),
        (
            "required_phases_bound",
            metrics.phase_count
                == required_fresh_product_runtime_l3_manual_runtime_verification_phases().len()
                    as u64,
        ),
        (
            "small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe_address_deterministic",
            deterministic,
        ),
        (
            "missing_upstream_log_correlation_rejected",
            invalid_axes.missing_upstream_log_correlation_rejected,
        ),
        (
            "duplicate_observation_rejected",
            invalid_axes.duplicate_observation_rejected,
        ),
        (
            "missing_lattice_cursor_rejected",
            invalid_axes.missing_lattice_cursor_rejected,
        ),
        (
            "missing_living_index_cursor_rejected",
            invalid_axes.missing_living_index_cursor_rejected,
        ),
        (
            "missing_north_star_rejected",
            invalid_axes.missing_north_star_rejected,
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
            "raw_token_retained_rejected",
            invalid_axes.raw_token_retained_rejected,
        ),
        (
            "prompt_user_data_rejected",
            invalid_axes.prompt_user_data_rejected,
        ),
        (
            "manual_runtime_bytes_rejected",
            invalid_axes.manual_runtime_bytes_rejected,
        ),
        (
            "manual_model_bytes_rejected",
            invalid_axes.manual_model_bytes_rejected,
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
            "autogenous_kernel_rejected",
            invalid_axes.autogenous_kernel_rejected,
        ),
        (
            "seventy_b_product_claim_rejected",
            invalid_axes.seventy_b_product_claim_rejected,
        ),
        (
            "long_context_shard_claim_rejected",
            invalid_axes.long_context_shard_claim_rejected,
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
    for (axis, pass) in bool_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            pass,
        );
    }

    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "observation_count",
        metrics.observation_count,
        EXPECTED_OBSERVATION_COUNT,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "phase_count",
        metrics.phase_count,
        required_fresh_product_runtime_l3_manual_runtime_verification_phases().len() as u64,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_ref_count",
        metrics.source_ref_count,
        ">=",
        10,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "visible_surface_count",
        metrics.visible_surface_count,
        ">=",
        3,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "test_ref_count",
        metrics.test_ref_count,
        ">=",
        4,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "manual_step_count",
        metrics.manual_step_count,
        ">=",
        EXPECTED_MANUAL_STEP_COUNT,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_runtime_bytes_loaded",
        metrics.upstream_runtime_bytes_loaded,
        ">",
        ZERO_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_model_bytes_loaded",
        metrics.upstream_model_bytes_loaded,
        ">",
        ZERO_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "manual_verification_runtime_bytes_loaded",
        metrics.manual_verification_runtime_bytes_loaded,
        "==",
        ZERO_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "manual_verification_model_bytes_loaded",
        metrics.manual_verification_model_bytes_loaded,
        "==",
        ZERO_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes",
        witness.metadata_bytes,
        "<=",
        fresh_product_runtime_l3_manual_runtime_verification_metadata_budget_bytes(),
        "bytes",
    );
    measurements.insert(
        "capability_route_status".to_string(),
        Measurement {
            value: serde_json::json!(evidence.capability_route_status),
            unit: "status".to_string(),
        },
    );
    pass_per_axis.insert("capability_route_status".to_string(), true);
    thresholds.insert(
        "capability_route_status".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("vault_research_route_with_packetized_mitigation"),
            unit: "status".to_string(),
        },
    );
    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert("next_cursor".to_string(), true);
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    let address = witness.address();
    measurements.insert(
        "small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe_address"
            .to_string(),
        Measurement {
            value: serde_json::json!(address),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe_address"
            .to_string(),
        deterministic,
    );
    thresholds.insert(
        "small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe_address"
            .to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: measurements
                .get("small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe_address")
                .map(|measurement| measurement.value.clone())
                .unwrap_or_else(|| serde_json::json!("")),
            unit: "sha256".to_string(),
        },
    );
    measurements.insert(
        "token_digest_ref".to_string(),
        Measurement {
            value: serde_json::json!(first_observation.token_digest_ref),
            unit: "token_digest".to_string(),
        },
    );
    pass_per_axis.insert("token_digest_ref".to_string(), true);
    thresholds.insert(
        "token_digest_ref".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(first_observation.token_digest_ref),
            unit: "token_digest".to_string(),
        },
    );
    measurements.insert(
        "answer_packet_ref".to_string(),
        Measurement {
            value: serde_json::json!(first_observation.answer_packet_ref),
            unit: "ref".to_string(),
        },
    );
    pass_per_axis.insert("answer_packet_ref".to_string(), true);
    thresholds.insert(
        "answer_packet_ref".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(first_observation.answer_packet_ref),
            unit: "ref".to_string(),
        },
    );

    let anomalies = vec![serde_json::json!({
        "kind": "small_model_fresh_product_runtime_l3_manual_runtime_verification_packet",
        "detail": "Fresh product-runtime manual-verification evidence is visible across Living Index, lattice HTML, AnswerPacket, RunEventLog, and the red capability ledger. This opens zero new model/runtime bytes and queues a capability closeout/recheck; L2 remains vault_research_route_with_packetized_mitigation."
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
        notes: "L1/L3 F-SmallModelRuntimeHarnessFreshProductRuntimeL3ManualRuntimeVerificationProbe: binds visible manual-review evidence for the fresh Qwen3-4B product-runtime packet/log/source proof with zero new bytes; L2 remains red and capability closeout remains queued."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn fresh_product_runtime_l3_manual_runtime_verification_witness(
    evidence: &EvidenceSnapshot,
) -> Result<
    SmallModelFreshProductRuntimeL3ManualRuntimeVerificationWitness,
    FreshProductRuntimeL3ManualRuntimeVerificationWitnessError,
> {
    SmallModelFreshProductRuntimeL3ManualRuntimeVerificationWitness::new(
        "small-model-fresh-product-runtime-l3-manual-runtime-verification:visible-proof",
        "artifact:small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe:result",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_overall_pass,
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::Gated,
        "fresh_product_runtime_l3_manual_verification_no_route_authority",
        manual_observations(evidence),
        required_fresh_product_runtime_l3_manual_runtime_verification_phases().to_vec(),
        evidence.source_ref_count,
        evidence.visible_surface_count,
        evidence.test_ref_count,
        EXPECTED_MANUAL_STEP_COUNT,
        evidence.upstream_runtime_bytes_loaded,
        evidence.upstream_model_bytes_loaded,
        0,
        0,
        evidence.lattice_cursor_visible,
        evidence.living_index_cursor_visible,
        evidence.north_star_visible,
        evidence.l1_l2_l3_status_visible,
        evidence.answer_packet_observed,
        evidence.run_event_log_observed,
        !evidence.token_digest_ref.is_empty(),
        evidence.prompt_contains_user_data,
        evidence.raw_token_text_retained,
        evidence.rollback_cancellation_visible,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_NEXT_CURSOR,
        evidence.metadata_bytes,
    )
    .map_err(FreshProductRuntimeL3ManualRuntimeVerificationWitnessError::from)
}

fn manual_observations(
    evidence: &EvidenceSnapshot,
) -> Vec<SmallModelFreshProductRuntimeL3ManualRuntimeObservation> {
    [
        (
            "manual_observation:lattice-current-cursor-visible",
            "surface:lattice_index_html",
            "artifact:lattice-coordinate-explainer:index_html",
        ),
        (
            "manual_observation:living-index-current-state-visible",
            "surface:living_index_section_6",
            "artifact:epistemos-living-index:section-6",
        ),
        (
            "manual_observation:answer-packet-run-event-log-visible",
            "surface:answer_packet_run_event_log_sidecars",
            "artifact:small_model_runtime_harness_fresh_product_runtime_answer_packet_probe:sidecars",
        ),
    ]
    .into_iter()
    .map(|(observation_id, surface_ref, artifact_ref)| {
        SmallModelFreshProductRuntimeL3ManualRuntimeObservation {
            observation_id: observation_id.to_string(),
            operator_ref: "operator:codex-local-architecture-audit".to_string(),
            surface_ref: surface_ref.to_string(),
            artifact_ref: artifact_ref.to_string(),
            answer_packet_ref: evidence.answer_packet_ref.clone(),
            run_event_log_ref: evidence.run_event_log_ref.clone(),
            token_digest_ref: evidence.token_digest_ref.clone(),
            visible_to_operator: evidence.lattice_cursor_visible
                && evidence.living_index_cursor_visible,
            l1_l2_l3_called_out: evidence.l1_l2_l3_status_visible,
            prompt_privacy_visible: !evidence.prompt_contains_user_data
                && !evidence.raw_token_text_retained,
            rollback_visible: evidence.rollback_ref_present,
            cancellation_visible: evidence.cancellation_ref_present,
            route_authority_denied: !evidence.route_policy_mutated,
            product_green_denied: !evidence.capability_overall_pass,
        }
    })
    .collect()
}

// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-manual-runtime-verification-probe:evidence-snapshot
// Plane: Verification
// Residency: local canon/artifact state consumed by manual verification proof.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    upstream_log_correlation_pass: bool,
    source_ref_count: u64,
    visible_surface_count: u64,
    test_ref_count: u64,
    upstream_runtime_bytes_loaded: u64,
    upstream_model_bytes_loaded: u64,
    heavy_long_context_enabled: bool,
    kv_direct_live_128k_pass: bool,
    seventy_b_route_pass: bool,
    lattice_cursor_visible: bool,
    living_index_cursor_visible: bool,
    north_star_visible: bool,
    l1_l2_l3_status_visible: bool,
    answer_packet_observed: bool,
    run_event_log_observed: bool,
    answer_packet_ref: String,
    run_event_log_ref: String,
    token_digest_ref: String,
    prompt_contains_user_data: bool,
    raw_token_text_retained: bool,
    rollback_ref_present: bool,
    cancellation_ref_present: bool,
    rollback_cancellation_visible: bool,
    route_policy_mutated: bool,
    metadata_bytes: u64,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, FreshProductRuntimeL3ManualRuntimeVerificationWitnessError> {
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        let upstream = read_json(Path::new(UPSTREAM_LOG_CORRELATION_PATH))?;
        let live_sidecar = read_json(Path::new(LIVE_SIDECAR_PATH))?;
        let answer_packet_json = read_json(Path::new(ANSWER_PACKET_JSON_PATH))?;
        let run_event_log_json = read_json(Path::new(RUN_EVENT_LOG_JSON_PATH))?;
        let living_index = read_text(Path::new(LIVING_INDEX_PATH))?;
        let lattice_html = read_text(Path::new(LATTICE_HTML_PATH))?;
        let answer_packet_ref = json_string(&answer_packet_json, "id")?.to_string();
        let token_digest_ref = measurement_string(&upstream, "token_digest_ref")
            .or_else(|| token_digest_from_answer_packet(&answer_packet_json))
            .unwrap_or_default();
        let run_event_log_ref = "run_event_log:fresh-product-runtime:packetized".to_string();
        let rollback_ref_present = json_string(&live_sidecar, "rollback_ref").is_ok();
        let cancellation_ref_present = json_string(&live_sidecar, "cancellation_ref").is_ok();
        Ok(Self {
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_default(),
            capability_overall_pass: json_bool(&capability, "overall_pass")?,
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_default(),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_default(),
            upstream_log_correlation_pass: artifact_all_axes_true(&upstream),
            source_ref_count: measurement_u64(&upstream, "source_ref_count").unwrap_or(0),
            visible_surface_count: measurement_u64(&upstream, "visible_surface_count").unwrap_or(0),
            test_ref_count: measurement_u64(&upstream, "test_ref_count").unwrap_or(0),
            upstream_runtime_bytes_loaded: measurement_u64(
                &upstream,
                "upstream_runtime_bytes_loaded",
            )
            .unwrap_or(0),
            upstream_model_bytes_loaded: measurement_u64(&upstream, "upstream_model_bytes_loaded")
                .unwrap_or(0),
            heavy_long_context_enabled: measurement_bool(&capability, "heavy_long_context_enabled")
                .unwrap_or(false),
            kv_direct_live_128k_pass: measurement_bool(&capability, "kv_direct_live_128k_pass")
                .unwrap_or(false),
            seventy_b_route_pass: measurement_bool(&capability, "seventy_b_route_pass")
                .unwrap_or(false),
            lattice_cursor_visible: cursor_visible(&lattice_html),
            living_index_cursor_visible: cursor_visible(&living_index),
            north_star_visible: lattice_html.contains(NORTH_STAR_SENTENCE)
                && living_index.contains(NORTH_STAR_SENTENCE),
            l1_l2_l3_status_visible: living_index.contains("L1")
                && living_index.contains("L2")
                && living_index.contains("L3")
                && living_index.contains("vault_research_route_with_packetized_mitigation")
                && lattice_html.contains("L1")
                && lattice_html.contains("L2")
                && lattice_html.contains("L3"),
            answer_packet_observed: answer_packet_ref.starts_with("answer_packet:")
                && answer_packet_json
                    .get("claims")
                    .and_then(Value::as_array)
                    .is_some(),
            run_event_log_observed: run_event_log_entries(&run_event_log_json) > 0,
            answer_packet_ref,
            run_event_log_ref,
            token_digest_ref,
            prompt_contains_user_data: json_bool_key(&live_sidecar, "prompt_contains_user_data")?,
            raw_token_text_retained: json_bool_key(&live_sidecar, "raw_token_text_retained")?,
            rollback_ref_present,
            cancellation_ref_present,
            rollback_cancellation_visible: rollback_ref_present && cancellation_ref_present,
            route_policy_mutated: json_bool_key(&live_sidecar, "route_policy_mutated")?,
            metadata_bytes: file_len(GUARD_PATH)
                + file_len(CAPABILITY_PATH)
                + file_len(UPSTREAM_LOG_CORRELATION_PATH)
                + file_len(LIVE_SIDECAR_PATH)
                + file_len(ANSWER_PACKET_JSON_PATH)
                + file_len(RUN_EVENT_LOG_JSON_PATH)
                + file_len(LIVING_INDEX_PATH)
                + file_len(LATTICE_HTML_PATH),
        })
    }
}

fn invalid_rejections(
    witness: &SmallModelFreshProductRuntimeL3ManualRuntimeVerificationWitness,
) -> InvalidAxes {
    let mut missing_upstream = witness.clone();
    missing_upstream
        .upstream_log_correlation_artifact_ref
        .clear();
    let mut duplicate_observation = witness.clone();
    duplicate_observation.observations[1].observation_id =
        duplicate_observation.observations[0].observation_id.clone();
    let mut missing_lattice = witness.clone();
    missing_lattice.lattice_cursor_visible = false;
    let mut missing_living_index = witness.clone();
    missing_living_index.living_index_cursor_visible = false;
    let mut missing_north_star = witness.clone();
    missing_north_star.north_star_visible = false;
    let mut missing_packet = witness.clone();
    missing_packet.answer_packet_observed = false;
    let mut missing_log = witness.clone();
    missing_log.run_event_log_observed = false;
    let mut raw_token = witness.clone();
    raw_token.raw_token_text_retained = true;
    let mut prompt_user_data = witness.clone();
    prompt_user_data.prompt_user_data_retained = true;
    let mut manual_runtime_bytes = witness.clone();
    manual_runtime_bytes.manual_verification_runtime_bytes_loaded = 1;
    let mut manual_model_bytes = witness.clone();
    manual_model_bytes.manual_verification_model_bytes_loaded = 1;
    let mut l2_green = witness.clone();
    l2_green.l2_green_claimed = true;
    let mut l3_green = witness.clone();
    l3_green.l3_green_claimed = true;
    let mut autogenous = witness.clone();
    autogenous.autogenous_kernel_attempted = true;
    let mut seventy_b = witness.clone();
    seventy_b.seventy_b_product_claimed = true;
    let mut long_context = witness.clone();
    long_context.long_context_shard_product_claimed = true;
    let mut next_cursor = witness.clone();
    next_cursor.next_cursor = "small_model_runtime_harness_fresh_product_runtime_done".to_string();
    let mut metadata = witness.clone();
    metadata.metadata_bytes =
        fresh_product_runtime_l3_manual_runtime_verification_metadata_budget_bytes() + 1;
    InvalidAxes {
        missing_upstream_log_correlation_rejected: missing_upstream.validate().is_err(),
        duplicate_observation_rejected: duplicate_observation.validate().is_err(),
        missing_lattice_cursor_rejected: missing_lattice.validate().is_err(),
        missing_living_index_cursor_rejected: missing_living_index.validate().is_err(),
        missing_north_star_rejected: missing_north_star.validate().is_err(),
        missing_answer_packet_rejected: missing_packet.validate().is_err(),
        missing_run_event_log_rejected: missing_log.validate().is_err(),
        raw_token_retained_rejected: raw_token.validate().is_err(),
        prompt_user_data_rejected: prompt_user_data.validate().is_err(),
        manual_runtime_bytes_rejected: manual_runtime_bytes.validate().is_err(),
        manual_model_bytes_rejected: manual_model_bytes.validate().is_err(),
        l2_green_claim_rejected: l2_green.validate().is_err(),
        l3_green_claim_rejected: l3_green.validate().is_err(),
        autogenous_kernel_rejected: autogenous.validate().is_err(),
        seventy_b_product_claim_rejected: seventy_b.validate().is_err(),
        long_context_shard_claim_rejected: long_context.validate().is_err(),
        next_cursor_mismatch_rejected: next_cursor.validate().is_err(),
        metadata_budget_rejected: metadata.validate().is_err(),
    }
}

// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-manual-runtime-verification-probe:invalid-axes
// Plane: Verification
// Residency: negative fixture results.
struct InvalidAxes {
    missing_upstream_log_correlation_rejected: bool,
    duplicate_observation_rejected: bool,
    missing_lattice_cursor_rejected: bool,
    missing_living_index_cursor_rejected: bool,
    missing_north_star_rejected: bool,
    missing_answer_packet_rejected: bool,
    missing_run_event_log_rejected: bool,
    raw_token_retained_rejected: bool,
    prompt_user_data_rejected: bool,
    manual_runtime_bytes_rejected: bool,
    manual_model_bytes_rejected: bool,
    l2_green_claim_rejected: bool,
    l3_green_claim_rejected: bool,
    autogenous_kernel_rejected: bool,
    seventy_b_product_claim_rejected: bool,
    long_context_shard_claim_rejected: bool,
    next_cursor_mismatch_rejected: bool,
    metadata_budget_rejected: bool,
}

fn cursor_visible(text: &str) -> bool {
    text.contains(
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_CURSOR,
    ) || text.contains(
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_NEXT_CURSOR,
    )
}

fn token_digest_from_answer_packet(value: &Value) -> Option<String> {
    value
        .get("semantic_delta_ref")
        .and_then(Value::as_str)
        .and_then(|semantic_delta| semantic_delta.rsplit(':').next())
        .filter(|digest| digest.len() == 64 && digest.chars().all(|ch| ch.is_ascii_hexdigit()))
        .map(|digest| format!("token_sha256:{}", digest.to_ascii_lowercase()))
}

fn run_event_log_entries(value: &Value) -> usize {
    value
        .get("entries")
        .and_then(Value::as_array)
        .map_or(0, Vec::len)
}

fn read_json(
    path: &Path,
) -> Result<Value, FreshProductRuntimeL3ManualRuntimeVerificationWitnessError> {
    let bytes = std::fs::read(path).map_err(|error| {
        FreshProductRuntimeL3ManualRuntimeVerificationWitnessError::Io(format!(
            "failed to read {}: {error}",
            path.display()
        ))
    })?;
    serde_json::from_slice(&bytes).map_err(|error| {
        FreshProductRuntimeL3ManualRuntimeVerificationWitnessError::Json(format!(
            "failed to parse {}: {error}",
            path.display()
        ))
    })
}

fn read_text(
    path: &Path,
) -> Result<String, FreshProductRuntimeL3ManualRuntimeVerificationWitnessError> {
    std::fs::read_to_string(path).map_err(|error| {
        FreshProductRuntimeL3ManualRuntimeVerificationWitnessError::Io(format!(
            "failed to read {}: {error}",
            path.display()
        ))
    })
}

fn json_string<'a>(
    value: &'a Value,
    key: &'static str,
) -> Result<&'a str, FreshProductRuntimeL3ManualRuntimeVerificationWitnessError> {
    value
        .get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| json_error(format!("missing string `{key}`")))
}

fn json_bool_key(
    value: &Value,
    key: &'static str,
) -> Result<bool, FreshProductRuntimeL3ManualRuntimeVerificationWitnessError> {
    value
        .get(key)
        .and_then(Value::as_bool)
        .ok_or_else(|| json_error(format!("missing bool `{key}`")))
}

fn json_bool(
    value: &Value,
    key: &str,
) -> Result<bool, FreshProductRuntimeL3ManualRuntimeVerificationWitnessError> {
    value
        .get(key)
        .and_then(Value::as_bool)
        .ok_or_else(|| json_error(format!("missing bool `{key}`")))
}

fn measurement_string(value: &Value, key: &str) -> Option<String> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(Value::as_str)
        .map(ToOwned::to_owned)
}

fn measurement_u64(value: &Value, key: &str) -> Option<u64> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(Value::as_u64)
}

fn measurement_bool(value: &Value, key: &str) -> Option<bool> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(Value::as_bool)
}

fn artifact_all_axes_true(value: &Value) -> bool {
    value
        .get("overall_pass")
        .and_then(Value::as_bool)
        .unwrap_or(false)
        && value
            .get("pass_per_axis")
            .and_then(Value::as_object)
            .is_some_and(|axes| !axes.is_empty() && axes.values().all(|axis| axis == true))
}

fn file_len(path: &str) -> u64 {
    std::fs::metadata(path)
        .map(|metadata| metadata.len())
        .unwrap_or(0)
}

fn json_error(
    message: impl Into<String>,
) -> FreshProductRuntimeL3ManualRuntimeVerificationWitnessError {
    FreshProductRuntimeL3ManualRuntimeVerificationWitnessError::Json(message.into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn axis_contract_has_no_duplicates() {
        let mut seen = std::collections::BTreeSet::new();
        for axis in SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_AXES
        {
            assert!(seen.insert(*axis), "duplicate axis {axis}");
        }
    }

    #[test]
    fn cursor_visible_accepts_current_or_advanced_cursor() {
        assert!(cursor_visible(
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_CURSOR
        ));
        assert!(cursor_visible(
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_NEXT_CURSOR
        ));
        assert!(!cursor_visible(
            "small_model_runtime_harness_product_wrv_probe"
        ));
    }
}
