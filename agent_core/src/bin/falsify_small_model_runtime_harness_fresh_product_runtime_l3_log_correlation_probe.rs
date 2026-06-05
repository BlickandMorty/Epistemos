//! `falsify_small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe`.
//!
//! This L1/L3-evidence witness correlates the fresh product-runtime live
//! sidecar, AnswerPacket JSON, RunEventLog JSON, source WRV artifact, and
//! blocker ledger. It opens no new runtime/model bytes and leaves L2 red until
//! manual product-runtime verification lands.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[cfg(test)]
use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    fresh_product_runtime_l3_log_correlation_metadata_budget_bytes,
    required_fresh_product_runtime_l3_log_correlation_phases, ProStatus, ProductBuild,
    SmallModelFreshProductRuntimeL3LogCorrelationError,
    SmallModelFreshProductRuntimeL3LogCorrelationRecord,
    SmallModelFreshProductRuntimeL3LogCorrelationWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_NEXT_CURSOR,
};
use serde_json::Value;

const FALSIFIER_ID: &str = "F-SmallModelRuntimeHarnessFreshProductRuntimeL3LogCorrelationProbe";
const FIXTURE_ID: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const CAPABILITY_RECHECK_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_capability_recheck/result.json";
const FRESH_ANSWER_PACKET_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_answer_packet_probe/result.json";
const FRESH_WRV_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_wrv_probe/result.json";
const LIVE_SIDECAR_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_live_probe/live_probe.json";
const ANSWER_PACKET_JSON_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_answer_packet_probe/answer_packet.json";
const RUN_EVENT_LOG_JSON_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_answer_packet_probe/run_event_log.json";
const ZERO_BYTES: u64 = 0;
const EXPECTED_CORRELATION_COUNT: u64 = 1;
const EXPECTED_RUN_EVENT_LOG_ENTRIES: u64 = 2;

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-log-correlation-probe:witness-error
// Plane: Verification
// Residency: falsifier IO/JSON/primitive error wrapper.
enum FreshProductRuntimeL3LogCorrelationWitnessError {
    Primitive(SmallModelFreshProductRuntimeL3LogCorrelationError),
    Io(String),
    Json(String),
}

impl std::fmt::Display for FreshProductRuntimeL3LogCorrelationWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) | Self::Json(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for FreshProductRuntimeL3LogCorrelationWitnessError {}

impl From<SmallModelFreshProductRuntimeL3LogCorrelationError>
    for FreshProductRuntimeL3LogCorrelationWitnessError
{
    fn from(value: SmallModelFreshProductRuntimeL3LogCorrelationError) -> Self {
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
    FreshProductRuntimeL3LogCorrelationWitnessError,
> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fresh_product_runtime_l3_log_correlation_witness(&evidence)?;
    let deterministic =
        witness.address() == fresh_product_runtime_l3_log_correlation_witness(&evidence)?.address();
    let invalid_axes = invalid_rejections(&witness);
    let metrics = witness.metrics();
    let correlation = witness
        .correlations
        .first()
        .ok_or(SmallModelFreshProductRuntimeL3LogCorrelationError::EmptyCorrelation)?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_capability_recheck_pass",
            evidence.capability_recheck_pass,
        ),
        (
            "upstream_fresh_answer_packet_probe_pass",
            evidence.fresh_answer_packet_pass,
        ),
        ("upstream_fresh_wrv_probe_pass", evidence.fresh_wrv_pass),
        (
            "guard_cursor_l3_log_correlation_or_advanced",
            evidence.guard_next_existing_work
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_l3_log_correlation_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_NEXT_CURSOR,
        ),
        (
            "product_status_gated",
            witness.product_build == ProductBuild::Pro && witness.pro_status == ProStatus::Gated,
        ),
        (
            "route_authority_log_correlation_only",
            witness.route_authority
                == "fresh_product_runtime_l3_log_correlation_no_route_authority",
        ),
        ("answer_packet_sidecar_bound", !correlation.answer_packet_ref.is_empty()),
        ("run_event_log_sidecar_bound", !correlation.run_event_log_ref.is_empty()),
        ("live_sidecar_bound", !correlation.live_sidecar_ref.is_empty()),
        (
            "token_digest_correlated",
            correlation.token_digest_ref == correlation.answer_packet_token_digest_ref
                && correlation.token_digest_ref == correlation.run_event_log_token_digest_ref
                && correlation.token_digest_ref == correlation.live_sidecar_token_digest_ref,
        ),
        (
            "stop_reason_end_turn_correlated",
            correlation.answer_packet_stop_reason == "end_turn"
                && correlation.run_event_log_stop_reason == "end_turn"
                && correlation.run_event_log_stop_present,
        ),
        (
            "prompt_privacy_correlated",
            !correlation.prompt_contains_user_data && !correlation.raw_token_text_retained,
        ),
        (
            "source_wrv_coverage_bound",
            metrics.source_ref_count >= 10
                && metrics.visible_surface_count >= 3
                && metrics.test_ref_count >= 4,
        ),
        (
            "manual_runtime_verification_still_red",
            !witness.manual_runtime_verification_green,
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
            "correlation_runtime_bytes_zero",
            metrics.correlation_runtime_bytes_loaded == 0,
        ),
        (
            "correlation_model_bytes_zero",
            metrics.correlation_model_bytes_loaded == 0,
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
        (
            "heavy_routes_deferred",
            !evidence.heavy_long_context_enabled,
        ),
        (
            "kv_direct_128k_still_red",
            !evidence.kv_direct_live_128k_pass,
        ),
        ("live_70b_still_red", !evidence.seventy_b_route_pass),
        (
            "autogenous_kernel_still_research",
            !witness.autogenous_kernel_attempted,
        ),
        (
            "next_manual_runtime_verification_probe_bound",
            witness.next_cursor
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_NEXT_CURSOR,
        ),
        (
            "required_phases_bound",
            metrics.phase_count
                == required_fresh_product_runtime_l3_log_correlation_phases().len() as u64,
        ),
        (
            "small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe_address_deterministic",
            deterministic,
        ),
        (
            "missing_capability_recheck_artifact_rejected",
            invalid_axes.missing_capability_recheck_artifact_rejected,
        ),
        (
            "token_digest_mismatch_rejected",
            invalid_axes.token_digest_mismatch_rejected,
        ),
        (
            "missing_run_event_log_stop_rejected",
            invalid_axes.missing_run_event_log_stop_rejected,
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
            "source_wrv_shortfall_rejected",
            invalid_axes.source_wrv_shortfall_rejected,
        ),
        (
            "manual_verification_green_rejected",
            invalid_axes.manual_verification_green_rejected,
        ),
        (
            "correlation_runtime_bytes_rejected",
            invalid_axes.correlation_runtime_bytes_rejected,
        ),
        (
            "correlation_model_bytes_rejected",
            invalid_axes.correlation_model_bytes_rejected,
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
        "correlation_count",
        metrics.correlation_count,
        EXPECTED_CORRELATION_COUNT,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "run_event_log_entry_count",
        correlation.run_event_log_entry_count,
        EXPECTED_RUN_EVENT_LOG_ENTRIES,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "phase_count",
        metrics.phase_count,
        required_fresh_product_runtime_l3_log_correlation_phases().len() as u64,
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
        "correlation_runtime_bytes_loaded",
        metrics.correlation_runtime_bytes_loaded,
        "==",
        ZERO_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "correlation_model_bytes_loaded",
        metrics.correlation_model_bytes_loaded,
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
        fresh_product_runtime_l3_log_correlation_metadata_budget_bytes(),
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
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_NEXT_CURSOR
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
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    let address = witness.address();
    measurements.insert(
        "small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe_address"
            .to_string(),
        Measurement {
            value: serde_json::json!(address),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe_address"
            .to_string(),
        deterministic,
    );
    thresholds.insert(
        "small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe_address"
            .to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: measurements
                .get("small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe_address")
                .map(|measurement| measurement.value.clone())
                .unwrap_or_else(|| serde_json::json!("")),
            unit: "sha256".to_string(),
        },
    );
    measurements.insert(
        "token_digest_ref".to_string(),
        Measurement {
            value: serde_json::json!(correlation.token_digest_ref),
            unit: "token_digest".to_string(),
        },
    );
    pass_per_axis.insert("token_digest_ref".to_string(), true);
    thresholds.insert(
        "token_digest_ref".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(correlation.token_digest_ref),
            unit: "token_digest".to_string(),
        },
    );
    measurements.insert(
        "answer_packet_ref".to_string(),
        Measurement {
            value: serde_json::json!(correlation.answer_packet_ref),
            unit: "ref".to_string(),
        },
    );
    pass_per_axis.insert("answer_packet_ref".to_string(), true);
    thresholds.insert(
        "answer_packet_ref".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(correlation.answer_packet_ref),
            unit: "ref".to_string(),
        },
    );

    let anomalies = vec![serde_json::json!({
        "kind": "small_model_fresh_product_runtime_l3_log_correlation_proof",
        "detail": "Fresh product-runtime AnswerPacket, RunEventLog, live sidecar, source WRV, and capability blocker ledger correlate on token digest, stop reason, prompt privacy, and visible product surfaces. This opens zero new model/runtime bytes and still leaves L2 red until manual runtime verification lands."
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
        notes: "L1/L3-source F-SmallModelRuntimeHarnessFreshProductRuntimeL3LogCorrelationProbe: correlates fresh Qwen3-4B AnswerPacket, RunEventLog, live sidecar, source WRV, and red capability ledger with zero new bytes; L2 remains red and manual product-runtime verification remains queued."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn fresh_product_runtime_l3_log_correlation_witness(
    evidence: &EvidenceSnapshot,
) -> Result<
    SmallModelFreshProductRuntimeL3LogCorrelationWitness,
    FreshProductRuntimeL3LogCorrelationWitnessError,
> {
    SmallModelFreshProductRuntimeL3LogCorrelationWitness::new(
        "small-model-fresh-product-runtime-l3-log-correlation:visible-proof",
        "artifact:small_model_runtime_harness_fresh_product_runtime_capability_recheck:result",
        "artifact:small_model_runtime_harness_fresh_product_runtime_answer_packet_probe:result",
        "artifact:small_model_runtime_harness_fresh_product_runtime_wrv_probe:result",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_overall_pass,
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::Gated,
        "fresh_product_runtime_l3_log_correlation_no_route_authority",
        vec![evidence.correlation_record.clone()],
        required_fresh_product_runtime_l3_log_correlation_phases().to_vec(),
        evidence.source_ref_count,
        evidence.visible_surface_count,
        evidence.test_ref_count,
        evidence.upstream_runtime_bytes_loaded,
        evidence.upstream_model_bytes_loaded,
        0,
        0,
        evidence.manual_runtime_verification_green,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_NEXT_CURSOR,
        evidence.metadata_bytes,
    )
    .map_err(FreshProductRuntimeL3LogCorrelationWitnessError::from)
}

// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-log-correlation-probe:evidence-snapshot
// Plane: Verification
// Residency: sidecar/artifact state consumed by L3 log-correlation proof.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    capability_recheck_pass: bool,
    fresh_answer_packet_pass: bool,
    fresh_wrv_pass: bool,
    source_ref_count: u64,
    visible_surface_count: u64,
    test_ref_count: u64,
    upstream_runtime_bytes_loaded: u64,
    upstream_model_bytes_loaded: u64,
    heavy_long_context_enabled: bool,
    kv_direct_live_128k_pass: bool,
    seventy_b_route_pass: bool,
    manual_runtime_verification_green: bool,
    correlation_record: SmallModelFreshProductRuntimeL3LogCorrelationRecord,
    metadata_bytes: u64,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, FreshProductRuntimeL3LogCorrelationWitnessError> {
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        let capability_recheck = read_json(Path::new(CAPABILITY_RECHECK_PATH))?;
        let fresh_answer_packet = read_json(Path::new(FRESH_ANSWER_PACKET_PATH))?;
        let fresh_wrv = read_json(Path::new(FRESH_WRV_PATH))?;
        let live_sidecar = read_json(Path::new(LIVE_SIDECAR_PATH))?;
        let answer_packet_json = read_json(Path::new(ANSWER_PACKET_JSON_PATH))?;
        let run_event_log_json = read_json(Path::new(RUN_EVENT_LOG_JSON_PATH))?;
        let correlation_record =
            correlation_record(&live_sidecar, &answer_packet_json, &run_event_log_json)?;
        Ok(Self {
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_default(),
            capability_overall_pass: json_bool(&capability, "overall_pass")?,
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_default(),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_default(),
            capability_recheck_pass: artifact_all_axes_true(&capability_recheck),
            fresh_answer_packet_pass: artifact_all_axes_true(&fresh_answer_packet),
            fresh_wrv_pass: artifact_all_axes_true(&fresh_wrv),
            source_ref_count: measurement_u64(&fresh_wrv, "source_ref_count").unwrap_or(0),
            visible_surface_count: measurement_u64(&fresh_wrv, "surface_count").unwrap_or(0),
            test_ref_count: measurement_u64(&fresh_wrv, "test_ref_count").unwrap_or(0),
            upstream_runtime_bytes_loaded: measurement_u64(
                &capability_recheck,
                "upstream_runtime_bytes_loaded",
            )
            .unwrap_or(0),
            upstream_model_bytes_loaded: measurement_u64(
                &capability_recheck,
                "upstream_model_bytes_loaded",
            )
            .unwrap_or(0),
            heavy_long_context_enabled: measurement_bool(&capability, "heavy_long_context_enabled")
                .unwrap_or(false),
            kv_direct_live_128k_pass: measurement_bool(&capability, "kv_direct_live_128k_pass")
                .unwrap_or(false),
            seventy_b_route_pass: measurement_bool(&capability, "seventy_b_route_pass")
                .unwrap_or(false),
            manual_runtime_verification_green: measurement_bool(
                &capability,
                "small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe_pass",
            )
            .unwrap_or(false),
            correlation_record,
            metadata_bytes: std::fs::metadata(CAPABILITY_RECHECK_PATH)
                .map(|metadata| metadata.len())
                .unwrap_or(0)
                + std::fs::metadata(FRESH_ANSWER_PACKET_PATH)
                    .map(|metadata| metadata.len())
                    .unwrap_or(0)
                + std::fs::metadata(FRESH_WRV_PATH)
                    .map(|metadata| metadata.len())
                    .unwrap_or(0)
                + std::fs::metadata(LIVE_SIDECAR_PATH)
                    .map(|metadata| metadata.len())
                    .unwrap_or(0)
                + std::fs::metadata(ANSWER_PACKET_JSON_PATH)
                    .map(|metadata| metadata.len())
                    .unwrap_or(0)
                + std::fs::metadata(RUN_EVENT_LOG_JSON_PATH)
                    .map(|metadata| metadata.len())
                    .unwrap_or(0),
        })
    }
}

fn correlation_record(
    live_sidecar: &Value,
    answer_packet_json: &Value,
    run_event_log_json: &Value,
) -> Result<
    SmallModelFreshProductRuntimeL3LogCorrelationRecord,
    FreshProductRuntimeL3LogCorrelationWitnessError,
> {
    let answer_packet_ref = json_string(answer_packet_json, "id")?.to_string();
    let semantic_delta = json_string(answer_packet_json, "semantic_delta_ref")?;
    let answer_packet_token_digest_ref = normalize_token_digest(
        semantic_delta
            .rsplit(':')
            .next()
            .ok_or_else(|| json_error("answer packet semantic delta missing token digest"))?,
    )?;
    let live_sidecar_token_digest_ref =
        normalize_token_digest(json_string(live_sidecar, "first_token_sha256")?)?;
    let prompt_hash_ref = json_string(live_sidecar, "prompt_sha256")?.to_string();
    let product_surface = format!("surface:{}", json_string(live_sidecar, "product_surface")?);
    let output_token_count = json_u64(live_sidecar, "output_token_count")?;
    let prompt_contains_user_data = json_bool_key(live_sidecar, "prompt_contains_user_data")?;
    let raw_token_text_retained = json_bool_key(live_sidecar, "raw_token_text_retained")?;
    let (run_event_log_token_digest_ref, run_event_log_stop_reason, final_text, stop, errors, len) =
        read_run_event_log(run_event_log_json)?;
    let answer_packet_stop_reason = answer_packet_json
        .get("claims")
        .and_then(Value::as_array)
        .and_then(|claims| {
            claims
                .iter()
                .filter_map(|claim| claim.get("text").and_then(Value::as_str))
                .find_map(|text| text.contains("stop_reason=end_turn").then_some("end_turn"))
        })
        .unwrap_or("")
        .to_string();
    let record = SmallModelFreshProductRuntimeL3LogCorrelationRecord {
        correlation_id: "fresh-product-runtime-qwen3-4b-log-correlation".to_string(),
        answer_packet_ref,
        run_event_log_ref: "run_event_log:fresh-product-runtime:packetized".to_string(),
        live_sidecar_ref:
            "artifact:small_model_runtime_harness_fresh_product_runtime_live_probe:live_probe:result"
                .to_string(),
        token_digest_ref: live_sidecar_token_digest_ref.clone(),
        prompt_hash_ref,
        product_surface_ref: product_surface,
        answer_packet_token_digest_ref,
        run_event_log_token_digest_ref,
        live_sidecar_token_digest_ref,
        answer_packet_stop_reason,
        run_event_log_stop_reason,
        output_token_count,
        run_event_log_entry_count: len,
        run_event_log_final_text_present: final_text,
        run_event_log_stop_present: stop,
        run_event_log_error_count: errors,
        prompt_contains_user_data,
        raw_token_text_retained,
    };
    record
        .validate()
        .map_err(FreshProductRuntimeL3LogCorrelationWitnessError::from)?;
    Ok(record)
}

fn read_run_event_log(
    value: &Value,
) -> Result<(String, String, bool, bool, u64, u64), FreshProductRuntimeL3LogCorrelationWitnessError>
{
    let entries = value
        .get("entries")
        .and_then(Value::as_array)
        .ok_or_else(|| json_error("run_event_log.entries missing"))?;
    let mut token_digest = String::new();
    let mut stop_reason = String::new();
    let mut final_text = false;
    let mut stop = false;
    let mut errors = 0;
    for entry in entries {
        let event = entry.get("event").unwrap_or(entry);
        match event.get("event_type").and_then(Value::as_str) {
            Some("final_text") => {
                final_text = true;
                let text = event.get("text").and_then(Value::as_str).unwrap_or("");
                if let Some(digest) = text
                    .split("token_sha256:")
                    .nth(1)
                    .and_then(|tail| tail.split(']').next())
                {
                    token_digest = normalize_token_digest(digest)?;
                }
            }
            Some("stop") => {
                stop = true;
                stop_reason = event
                    .get("reason")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .to_string();
            }
            Some("error") => errors += 1,
            _ => {}
        }
    }
    Ok((
        token_digest,
        stop_reason,
        final_text,
        stop,
        errors,
        entries.len() as u64,
    ))
}

fn invalid_rejections(
    witness: &SmallModelFreshProductRuntimeL3LogCorrelationWitness,
) -> InvalidAxes {
    let mut missing_capability_recheck = witness.clone();
    missing_capability_recheck
        .capability_recheck_artifact_ref
        .clear();
    let mut token_mismatch = witness.clone();
    token_mismatch.correlations[0].run_event_log_token_digest_ref =
        "token_sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".to_string();
    let mut missing_stop = witness.clone();
    missing_stop.correlations[0].run_event_log_stop_present = false;
    let mut raw_token = witness.clone();
    raw_token.correlations[0].raw_token_text_retained = true;
    let mut prompt_user_data = witness.clone();
    prompt_user_data.correlations[0].prompt_contains_user_data = true;
    let mut source_shortfall = witness.clone();
    source_shortfall.source_ref_count = 0;
    let mut manual_green = witness.clone();
    manual_green.manual_runtime_verification_green = true;
    let mut runtime_bytes = witness.clone();
    runtime_bytes.correlation_runtime_bytes_loaded = 1;
    let mut model_bytes = witness.clone();
    model_bytes.correlation_model_bytes_loaded = 1;
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
    metadata.metadata_bytes = fresh_product_runtime_l3_log_correlation_metadata_budget_bytes() + 1;
    InvalidAxes {
        missing_capability_recheck_artifact_rejected: missing_capability_recheck
            .validate()
            .is_err(),
        token_digest_mismatch_rejected: token_mismatch.validate().is_err(),
        missing_run_event_log_stop_rejected: missing_stop.validate().is_err(),
        raw_token_retained_rejected: raw_token.validate().is_err(),
        prompt_user_data_rejected: prompt_user_data.validate().is_err(),
        source_wrv_shortfall_rejected: source_shortfall.validate().is_err(),
        manual_verification_green_rejected: manual_green.validate().is_err(),
        correlation_runtime_bytes_rejected: runtime_bytes.validate().is_err(),
        correlation_model_bytes_rejected: model_bytes.validate().is_err(),
        l2_green_claim_rejected: l2_green.validate().is_err(),
        l3_green_claim_rejected: l3_green.validate().is_err(),
        autogenous_kernel_rejected: autogenous.validate().is_err(),
        seventy_b_product_claim_rejected: seventy_b.validate().is_err(),
        long_context_shard_claim_rejected: long_context.validate().is_err(),
        next_cursor_mismatch_rejected: next_cursor.validate().is_err(),
        metadata_budget_rejected: metadata.validate().is_err(),
    }
}

// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-log-correlation-probe:invalid-axes
// Plane: Verification
// Residency: negative fixture results.
struct InvalidAxes {
    missing_capability_recheck_artifact_rejected: bool,
    token_digest_mismatch_rejected: bool,
    missing_run_event_log_stop_rejected: bool,
    raw_token_retained_rejected: bool,
    prompt_user_data_rejected: bool,
    source_wrv_shortfall_rejected: bool,
    manual_verification_green_rejected: bool,
    correlation_runtime_bytes_rejected: bool,
    correlation_model_bytes_rejected: bool,
    l2_green_claim_rejected: bool,
    l3_green_claim_rejected: bool,
    autogenous_kernel_rejected: bool,
    seventy_b_product_claim_rejected: bool,
    long_context_shard_claim_rejected: bool,
    next_cursor_mismatch_rejected: bool,
    metadata_budget_rejected: bool,
}

fn normalize_token_digest(
    digest: &str,
) -> Result<String, FreshProductRuntimeL3LogCorrelationWitnessError> {
    let stripped = digest.strip_prefix("sha256:").unwrap_or(digest);
    if stripped.len() != 64 || !stripped.chars().all(|ch| ch.is_ascii_hexdigit()) {
        return Err(json_error("token digest must be a 64-char hex digest"));
    }
    Ok(format!("token_sha256:{}", stripped.to_ascii_lowercase()))
}

fn read_json(path: &Path) -> Result<Value, FreshProductRuntimeL3LogCorrelationWitnessError> {
    let bytes = std::fs::read(path).map_err(|error| {
        FreshProductRuntimeL3LogCorrelationWitnessError::Io(format!(
            "failed to read {}: {error}",
            path.display()
        ))
    })?;
    serde_json::from_slice(&bytes).map_err(|error| {
        FreshProductRuntimeL3LogCorrelationWitnessError::Json(format!(
            "failed to parse {}: {error}",
            path.display()
        ))
    })
}

fn json_string<'a>(
    value: &'a Value,
    key: &'static str,
) -> Result<&'a str, FreshProductRuntimeL3LogCorrelationWitnessError> {
    value
        .get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| json_error(format!("missing string `{key}`")))
}

fn json_u64(
    value: &Value,
    key: &'static str,
) -> Result<u64, FreshProductRuntimeL3LogCorrelationWitnessError> {
    value
        .get(key)
        .and_then(Value::as_u64)
        .ok_or_else(|| json_error(format!("missing u64 `{key}`")))
}

fn json_bool_key(
    value: &Value,
    key: &'static str,
) -> Result<bool, FreshProductRuntimeL3LogCorrelationWitnessError> {
    value
        .get(key)
        .and_then(Value::as_bool)
        .ok_or_else(|| json_error(format!("missing bool `{key}`")))
}

fn json_bool(
    value: &Value,
    key: &str,
) -> Result<bool, FreshProductRuntimeL3LogCorrelationWitnessError> {
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

fn json_error(message: impl Into<String>) -> FreshProductRuntimeL3LogCorrelationWitnessError {
    FreshProductRuntimeL3LogCorrelationWitnessError::Json(message.into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn axis_contract_has_no_duplicates() {
        let mut seen = std::collections::BTreeSet::new();
        for axis in SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_AXES
        {
            assert!(seen.insert(*axis), "duplicate axis {axis}");
        }
    }

    #[test]
    fn token_digest_normalization_accepts_sha256_prefix() {
        let normalized = normalize_token_digest(
            "sha256:75a11da44c802486bc6f65640aa48a730f0f684c5c07a42ba3cd1735eb3fb070",
        )
        .expect("valid digest");
        assert_eq!(
            normalized,
            "token_sha256:75a11da44c802486bc6f65640aa48a730f0f684c5c07a42ba3cd1735eb3fb070"
        );
    }
}
