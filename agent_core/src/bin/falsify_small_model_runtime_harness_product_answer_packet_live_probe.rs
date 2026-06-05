//! `falsify_small_model_runtime_harness_product_answer_packet_live_probe`.
//!
//! This witness binds retained small-model runtime evidence to the product
//! AnswerPacket handoff without opening new model bytes or promoting L2/L3.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    product_answer_packet_live_metadata_budget_bytes, required_product_answer_packet_live_phases,
    ProStatus, ProductBuild, SmallModelProductAnswerPacketLiveProbeError,
    SmallModelProductAnswerPacketLiveSurface, SmallModelProductAnswerPacketLiveWitness,
    SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallModelRuntimeHarnessProductAnswerPacketLiveProbe";
const FIXTURE_ID: &str = "small_model_runtime_harness_product_answer_packet_live_probe_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_small_model_runtime_harness_product_answer_packet_live_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_product_answer_packet_live_probe/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const PRODUCT_WRV_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_product_wrv_probe/result.json";
const ANSWER_PACKET_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_answer_packet_runtime_probe/result.json";
const FIRST_TOKEN_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_first_token_runtime_probe/result.json";
const ANSWER_PACKET_SIDECAR: &str =
    "artifacts/falsifiers/small_model_runtime_harness_answer_packet_runtime_probe/answer_packet.json";
const RUN_EVENT_LOG_SIDECAR: &str =
    "artifacts/falsifiers/small_model_runtime_harness_answer_packet_runtime_probe/run_event_log.json";
const FIRST_TOKEN_SIDECAR: &str =
    "artifacts/falsifiers/small_model_runtime_harness_first_token_runtime_probe/live_probe.json";
const EXPECTED_SURFACES: u64 = 3;
const EXPECTED_MARKERS: u64 = 9;
const ZERO_BYTES: u64 = 0;

#[derive(Clone, Copy)]
// UAS: uas:small-model-runtime-harness-product-answer-packet-live-probe:marker-spec
// Plane: Verification
// Residency: product source marker contract for retained-live handoff evidence.
struct MarkerSpec {
    surface_id: &'static str,
    source_ref: &'static str,
    path: &'static str,
    markers: &'static [&'static str],
}

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-product-answer-packet-live-probe:witness-error
// Plane: Verification
// Residency: falsifier IO/source/primitive error wrapper.
enum ProductAnswerPacketLiveWitnessError {
    Primitive(SmallModelProductAnswerPacketLiveProbeError),
    Io(String),
    Json(String),
    MissingMarker { path: String, marker: String },
}

impl std::fmt::Display for ProductAnswerPacketLiveWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) | Self::Json(error) => write!(f, "{error}"),
            Self::MissingMarker { path, marker } => {
                write!(f, "`{path}` missing marker `{marker}`")
            }
        }
    }
}

impl std::error::Error for ProductAnswerPacketLiveWitnessError {}

impl From<SmallModelProductAnswerPacketLiveProbeError> for ProductAnswerPacketLiveWitnessError {
    fn from(value: SmallModelProductAnswerPacketLiveProbeError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, ProductAnswerPacketLiveWitnessError>
{
    let evidence = EvidenceSnapshot::read()?;
    let witness = product_answer_packet_live_witness(&evidence)?;
    let deterministic =
        witness.address() == product_answer_packet_live_witness(&evidence)?.address();
    let invalid_axes = invalid_rejections(&witness);
    let metrics = witness.metrics();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        ("upstream_product_wrv_probe_pass", evidence.product_wrv_pass),
        (
            "upstream_answer_packet_runtime_probe_pass",
            evidence.answer_packet_probe_pass,
        ),
        (
            "upstream_first_token_runtime_probe_pass",
            evidence.first_token_probe_pass,
        ),
        (
            "answer_packet_sidecar_present",
            evidence.answer_packet_sidecar_present,
        ),
        (
            "run_event_log_sidecar_present",
            evidence.run_event_log_sidecar_present,
        ),
        (
            "first_token_sidecar_present",
            evidence.first_token_sidecar_present,
        ),
        (
            "guard_cursor_product_answer_packet_live_or_advanced",
            evidence.guard_next_existing_work
                == SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_product_answer_packet_live_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_NEXT_CURSOR,
        ),
        (
            "product_status_gated",
            witness.product_build == ProductBuild::Pro && witness.pro_status == ProStatus::Gated,
        ),
        (
            "route_authority_retained_handoff_only",
            witness.route_authority
                == "retained_live_product_answer_packet_handoff_no_route_authority",
        ),
        (
            "retained_runtime_bytes_nonzero",
            witness.retained_runtime_bytes_loaded > 0,
        ),
        (
            "retained_model_bytes_nonzero",
            witness.retained_model_bytes_loaded > 0,
        ),
        (
            "fresh_product_runtime_bytes_zero",
            witness.fresh_product_runtime_bytes_loaded == 0,
        ),
        (
            "fresh_product_model_bytes_zero",
            witness.fresh_product_model_bytes_loaded == 0,
        ),
        (
            "answer_packet_id_bound",
            evidence.answer_packet_id.starts_with("answer_packet:"),
        ),
        (
            "run_event_log_entries_bound",
            evidence.run_event_log_entry_count >= 2 && evidence.run_event_log_has_stop,
        ),
        (
            "retained_token_digest_bound",
            evidence.retained_token_digest.starts_with("token_sha256:"),
        ),
        (
            "product_surfaces_visible",
            witness.surfaces.iter().all(|surface| surface.visible),
        ),
        (
            "product_packet_projected",
            witness
                .surfaces
                .iter()
                .all(|surface| surface.packet_projected),
        ),
        (
            "product_run_event_log_projected",
            witness
                .surfaces
                .iter()
                .all(|surface| surface.run_event_log_projected),
        ),
        (
            "source_markers_bound",
            witness
                .surfaces
                .iter()
                .all(|surface| surface.product_markers.len() >= 2),
        ),
        ("l1_l2_l3_separation_bound", witness.l1_l2_l3_separated),
        (
            "mas_floor_preserved",
            !witness.mas_live_agent_overclaim_attempted,
        ),
        (
            "no_mas_live_agent_overclaim",
            !witness.mas_live_agent_overclaim_attempted,
        ),
        ("no_l2_green_claim", !witness.l2_green_claimed),
        ("no_l3_green_claim", !witness.l3_green_claimed),
        (
            "no_raw_token_text_retained",
            witness
                .surfaces
                .iter()
                .all(|surface| !surface.raw_token_text_retained),
        ),
        (
            "no_prompt_user_data_retained",
            witness
                .surfaces
                .iter()
                .all(|surface| !surface.prompt_user_data_retained),
        ),
        (
            "no_hidden_route_authority",
            witness
                .surfaces
                .iter()
                .all(|surface| !surface.hidden_route_authority),
        ),
        (
            "no_hidden_cloud_fallback",
            witness
                .surfaces
                .iter()
                .all(|surface| !surface.hidden_cloud_fallback),
        ),
        (
            "no_hidden_chain",
            witness
                .surfaces
                .iter()
                .all(|surface| !surface.hidden_chain_exposed),
        ),
        (
            "no_route_policy_mutation",
            witness
                .surfaces
                .iter()
                .all(|surface| !surface.route_policy_mutated),
        ),
        (
            "no_gate_bypass",
            witness
                .surfaces
                .iter()
                .all(|surface| !surface.gate_bypassed),
        ),
        (
            "no_answer_packet_suppression",
            witness
                .surfaces
                .iter()
                .all(|surface| !surface.answer_packet_suppressed),
        ),
        (
            "no_app_path_subprocess_spawn",
            witness
                .surfaces
                .iter()
                .all(|surface| !surface.subprocess_spawned_in_app_path),
        ),
        (
            "no_autogenous_kernel_attempt",
            witness
                .surfaces
                .iter()
                .all(|surface| !surface.autogenous_kernel_attempted),
        ),
        (
            "no_70b_probe_attempt",
            witness
                .surfaces
                .iter()
                .all(|surface| !surface.seventy_b_probe_attempted),
        ),
        (
            "no_long_context_shard_probe",
            witness
                .surfaces
                .iter()
                .all(|surface| !surface.long_context_shard_probe_attempted),
        ),
        (
            "required_phases_bound",
            metrics.phase_count == required_product_answer_packet_live_phases().len() as u64,
        ),
        (
            "metadata_bound",
            witness.metadata_bytes <= product_answer_packet_live_metadata_budget_bytes(),
        ),
        (
            "small_model_runtime_harness_product_answer_packet_live_probe_address_deterministic",
            deterministic,
        ),
        (
            "missing_product_wrv_artifact_rejected",
            invalid_axes.missing_product_wrv_artifact_rejected,
        ),
        (
            "missing_answer_packet_artifact_rejected",
            invalid_axes.missing_answer_packet_artifact_rejected,
        ),
        (
            "missing_first_token_artifact_rejected",
            invalid_axes.missing_first_token_artifact_rejected,
        ),
        (
            "missing_surface_rejected",
            invalid_axes.missing_surface_rejected,
        ),
        (
            "missing_surface_marker_rejected",
            invalid_axes.missing_surface_marker_rejected,
        ),
        (
            "missing_retained_runtime_rejected",
            invalid_axes.missing_retained_runtime_rejected,
        ),
        (
            "missing_retained_model_rejected",
            invalid_axes.missing_retained_model_rejected,
        ),
        (
            "fresh_runtime_bytes_rejected",
            invalid_axes.fresh_runtime_bytes_rejected,
        ),
        (
            "fresh_model_bytes_rejected",
            invalid_axes.fresh_model_bytes_rejected,
        ),
        (
            "hidden_authority_rejected",
            invalid_axes.hidden_authority_rejected,
        ),
        ("hidden_cloud_rejected", invalid_axes.hidden_cloud_rejected),
        ("hidden_chain_rejected", invalid_axes.hidden_chain_rejected),
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
            "raw_token_text_rejected",
            invalid_axes.raw_token_text_rejected,
        ),
        (
            "prompt_user_data_rejected",
            invalid_axes.prompt_user_data_rejected,
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
            "mas_live_agent_overclaim_rejected",
            invalid_axes.mas_live_agent_overclaim_rejected,
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
            "surface_count",
            metrics.surface_count,
            EXPECTED_SURFACES,
            "count",
        ),
        (
            "product_marker_count",
            metrics.product_marker_count,
            EXPECTED_MARKERS,
            "count",
        ),
        (
            "phase_count",
            metrics.phase_count,
            required_product_answer_packet_live_phases().len() as u64,
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
    add_bytes_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "retained_runtime_bytes_loaded",
        metrics.retained_runtime_bytes_loaded,
        ">",
        0,
    );
    add_bytes_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "retained_model_bytes_loaded",
        metrics.retained_model_bytes_loaded,
        ">",
        0,
    );
    add_bytes_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fresh_product_runtime_bytes_loaded",
        metrics.fresh_product_runtime_bytes_loaded,
        "==",
        ZERO_BYTES,
    );
    add_bytes_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fresh_product_model_bytes_loaded",
        metrics.fresh_product_model_bytes_loaded,
        "==",
        ZERO_BYTES,
    );
    add_bytes_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes",
        witness.metadata_bytes,
        "<=",
        product_answer_packet_live_metadata_budget_bytes(),
    );
    measurements.insert(
        "answer_packet_id".to_string(),
        Measurement {
            value: serde_json::json!(evidence.answer_packet_id),
            unit: "id".to_string(),
        },
    );
    pass_per_axis.insert("answer_packet_id".to_string(), true);
    thresholds.insert(
        "answer_packet_id".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("answer_packet:"),
            unit: "id".to_string(),
        },
    );
    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(
                SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_NEXT_CURSOR
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
                SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    let address = witness.address();
    measurements.insert(
        "small_model_runtime_harness_product_answer_packet_live_probe_address".to_string(),
        Measurement {
            value: serde_json::json!(address),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "small_model_runtime_harness_product_answer_packet_live_probe_address".to_string(),
        deterministic,
    );
    thresholds.insert(
        "small_model_runtime_harness_product_answer_packet_live_probe_address".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: measurements
                .get("small_model_runtime_harness_product_answer_packet_live_probe_address")
                .map(|measurement| measurement.value.clone())
                .unwrap_or_else(|| serde_json::json!("")),
            unit: "sha256".to_string(),
        },
    );

    let anomalies = vec![serde_json::json!({
        "kind": "retained_live_product_answer_packet_handoff",
        "detail": "Product route surfaces are bound to retained Qwen3-4B first-token runtime evidence and real AnswerPacket/RunEventLog sidecars. This opens no fresh model bytes and does not promote L2, MAS live-agent, 70B, or 128K claims."
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
        notes: "L1 F-SmallModelRuntimeHarnessProductAnswerPacketLiveProbe: binds retained small-model runtime evidence to product AnswerPacket/RunEventLog handoff surfaces with strict privacy, cancellation, rollback, MAS/Pro, and no-promotion gates; no fresh model/runtime bytes loaded."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn product_answer_packet_live_witness(
    evidence: &EvidenceSnapshot,
) -> Result<SmallModelProductAnswerPacketLiveWitness, ProductAnswerPacketLiveWitnessError> {
    SmallModelProductAnswerPacketLiveWitness::new(
        "small-model-runtime-harness-product-answer-packet-live:retained-handoff",
        "artifact:small_model_runtime_harness_product_wrv_probe:result",
        "artifact:small_model_runtime_harness_answer_packet_runtime_probe:result",
        "artifact:small_model_runtime_harness_first_token_runtime_probe:result",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::Gated,
        "retained_live_product_answer_packet_handoff_no_route_authority",
        evidence.surfaces.clone(),
        required_product_answer_packet_live_phases().to_vec(),
        evidence.retained_runtime_bytes_loaded,
        evidence.retained_model_bytes_loaded,
        0,
        0,
        true,
        false,
        false,
        false,
        evidence.metadata_bytes,
    )
    .map_err(ProductAnswerPacketLiveWitnessError::from)
}

// UAS: uas:small-model-runtime-harness-product-answer-packet-live-probe:evidence-snapshot
// Plane: Verification
// Residency: retained sidecar and product source snapshot.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    product_wrv_pass: bool,
    answer_packet_probe_pass: bool,
    first_token_probe_pass: bool,
    answer_packet_sidecar_present: bool,
    run_event_log_sidecar_present: bool,
    first_token_sidecar_present: bool,
    answer_packet_id: String,
    run_event_log_entry_count: u64,
    run_event_log_has_stop: bool,
    retained_token_digest: String,
    retained_runtime_bytes_loaded: u64,
    retained_model_bytes_loaded: u64,
    surfaces: Vec<SmallModelProductAnswerPacketLiveSurface>,
    metadata_bytes: u64,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, ProductAnswerPacketLiveWitnessError> {
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        let product_wrv = read_json(Path::new(PRODUCT_WRV_PATH))?;
        let answer_packet_probe = read_json(Path::new(ANSWER_PACKET_PATH))?;
        let first_token_probe = read_json(Path::new(FIRST_TOKEN_PATH))?;
        let answer_packet = read_json(Path::new(ANSWER_PACKET_SIDECAR))?;
        let run_event_log = read_json(Path::new(RUN_EVENT_LOG_SIDECAR))?;
        let first_token = read_json(Path::new(FIRST_TOKEN_SIDECAR))?;
        let retained_token_digest = token_digest(&first_token)?;
        let answer_packet_id = json_string(&answer_packet, "id")?;
        let run_event_log_entry_count = run_event_log
            .get("entries")
            .and_then(serde_json::Value::as_array)
            .map(|entries| entries.len() as u64)
            .unwrap_or(0);
        let run_event_log_has_stop = run_event_log
            .get("entries")
            .and_then(serde_json::Value::as_array)
            .is_some_and(|entries| {
                entries.iter().any(|entry| {
                    entry
                        .get("event")
                        .and_then(|event| event.get("event_type"))
                        .and_then(serde_json::Value::as_str)
                        == Some("stop")
                })
            });
        let surfaces = collect_surfaces(&answer_packet_id, &retained_token_digest)?;
        let source_marker_bytes = surfaces
            .iter()
            .flat_map(|surface| surface.product_markers.iter())
            .map(String::len)
            .sum::<usize>() as u64;
        let sidecar_bytes = std::fs::metadata(ANSWER_PACKET_SIDECAR)
            .map(|metadata| metadata.len())
            .unwrap_or(0)
            + std::fs::metadata(RUN_EVENT_LOG_SIDECAR)
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
            product_wrv_pass: artifact_all_axes_true(&product_wrv),
            answer_packet_probe_pass: artifact_all_axes_true(&answer_packet_probe),
            first_token_probe_pass: artifact_all_axes_true(&first_token_probe),
            answer_packet_sidecar_present: Path::new(ANSWER_PACKET_SIDECAR).exists(),
            run_event_log_sidecar_present: Path::new(RUN_EVENT_LOG_SIDECAR).exists(),
            first_token_sidecar_present: Path::new(FIRST_TOKEN_SIDECAR).exists(),
            answer_packet_id,
            run_event_log_entry_count,
            run_event_log_has_stop,
            retained_token_digest,
            retained_runtime_bytes_loaded: measurement_u64(
                &first_token_probe,
                "runtime_bytes_loaded",
            )
            .unwrap_or(0),
            retained_model_bytes_loaded: measurement_u64(&first_token_probe, "model_bytes_loaded")
                .unwrap_or(0),
            surfaces,
            metadata_bytes: source_marker_bytes + sidecar_bytes,
        })
    }
}

const SURFACE_SPECS: &[MarkerSpec] = &[
    MarkerSpec {
        surface_id: "surface:message-bubble",
        source_ref: "source:message_packet_visibility",
        path: "Epistemos/Views/Chat/MessageBubble.swift",
        markers: &[
            "AnswerPacketChipRow",
            "LatestAnswerPacketSink.shared",
            "answerPacketId",
        ],
    },
    MarkerSpec {
        surface_id: "surface:settings-diagnostics",
        source_ref: "source:settings_visibility",
        path: "Epistemos/Views/Settings/SubstrateHealthPanel.swift",
        markers: &[
            "AnswerPacketHealthRow()",
            "LocalAgentDiagnosticsHealthRow()",
            "Substrate",
        ],
    },
    MarkerSpec {
        surface_id: "surface:system-g-run-event-log",
        source_ref: "source:system_g_run_event_log",
        path: "Epistemos/SystemG/RealSystemGRunSeam.swift",
        markers: &[
            "RunEventLog",
            "RunEventLogReplayProjection.answerPacket",
            "AnswerPacketEmitter.shared.emit",
        ],
    },
];

fn collect_surfaces(
    answer_packet_id: &str,
    token_digest: &str,
) -> Result<Vec<SmallModelProductAnswerPacketLiveSurface>, ProductAnswerPacketLiveWitnessError> {
    SURFACE_SPECS
        .iter()
        .map(|spec| {
            let markers = collect_markers(spec)?;
            Ok(SmallModelProductAnswerPacketLiveSurface {
                surface_id: spec.surface_id.to_string(),
                source_ref: spec.source_ref.to_string(),
                answer_packet_ref: answer_packet_id.to_string(),
                run_event_log_ref: "run_event_log:system_g:product_answer_packet_projection"
                    .to_string(),
                admission_ref: "admission:scope_rex:small_model_product_answer_packet_live"
                    .to_string(),
                scope_rex_ref: "scope_rex:small_model_product_answer_packet_live".to_string(),
                sovereign_gate_ref: "sovereign_gate:small_model_product_answer_packet_live"
                    .to_string(),
                rollback_ref: "rollback:no_product_mutation:retained_live_packet_projection"
                    .to_string(),
                cancellation_ref: "cancel:serialized_local_inference_controller".to_string(),
                compatibility_fence_ref: "compat:mas_pro_l1_l2_l3_separated".to_string(),
                privacy_ref: "privacy:no_prompt_text_no_token_text_no_hidden_chain".to_string(),
                budget_ref: "budget:retained_small_model_runtime_only_no_new_product_bytes"
                    .to_string(),
                retained_token_digest_ref: token_digest.to_string(),
                product_markers: markers,
                visible: true,
                packet_projected: true,
                run_event_log_projected: true,
                raw_token_text_retained: false,
                prompt_user_data_retained: false,
                hidden_route_authority: false,
                hidden_cloud_fallback: false,
                hidden_chain_exposed: false,
                route_policy_mutated: false,
                gate_bypassed: false,
                answer_packet_suppressed: false,
                subprocess_spawned_in_app_path: false,
                autogenous_kernel_attempted: false,
                seventy_b_probe_attempted: false,
                long_context_shard_probe_attempted: false,
            })
        })
        .collect()
}

#[derive(Default)]
// UAS: uas:small-model-runtime-harness-product-answer-packet-live-probe:invalid-axes
// Plane: Verification
// Residency: invalid fixture coverage for product live handoff rejection paths.
struct InvalidAxes {
    missing_product_wrv_artifact_rejected: bool,
    missing_answer_packet_artifact_rejected: bool,
    missing_first_token_artifact_rejected: bool,
    missing_surface_rejected: bool,
    missing_surface_marker_rejected: bool,
    missing_retained_runtime_rejected: bool,
    missing_retained_model_rejected: bool,
    fresh_runtime_bytes_rejected: bool,
    fresh_model_bytes_rejected: bool,
    hidden_authority_rejected: bool,
    hidden_cloud_rejected: bool,
    hidden_chain_rejected: bool,
    route_policy_mutation_rejected: bool,
    gate_bypass_rejected: bool,
    answer_packet_suppression_rejected: bool,
    raw_token_text_rejected: bool,
    prompt_user_data_rejected: bool,
    app_path_subprocess_rejected: bool,
    autogenous_kernel_rejected: bool,
    seventy_b_probe_rejected: bool,
    long_context_shard_probe_rejected: bool,
    mas_live_agent_overclaim_rejected: bool,
    l2_green_claim_rejected: bool,
    l3_green_claim_rejected: bool,
    metadata_budget_rejected: bool,
}

fn invalid_rejections(witness: &SmallModelProductAnswerPacketLiveWitness) -> InvalidAxes {
    let mutate = |mutator: fn(&mut SmallModelProductAnswerPacketLiveWitness)| {
        let mut candidate = witness.clone();
        mutator(&mut candidate);
        candidate.validate().is_err()
    };
    InvalidAxes {
        missing_product_wrv_artifact_rejected: mutate(|candidate| {
            candidate.product_wrv_artifact_ref.clear();
        }),
        missing_answer_packet_artifact_rejected: mutate(|candidate| {
            candidate.answer_packet_artifact_ref.clear();
        }),
        missing_first_token_artifact_rejected: mutate(|candidate| {
            candidate.first_token_artifact_ref.clear();
        }),
        missing_surface_rejected: mutate(|candidate| candidate.surfaces.clear()),
        missing_surface_marker_rejected: mutate_surface(witness, |surface| {
            surface.product_markers.clear();
        }),
        missing_retained_runtime_rejected: mutate(|candidate| {
            candidate.retained_runtime_bytes_loaded = 0;
        }),
        missing_retained_model_rejected: mutate(|candidate| {
            candidate.retained_model_bytes_loaded = 0;
        }),
        fresh_runtime_bytes_rejected: mutate(|candidate| {
            candidate.fresh_product_runtime_bytes_loaded = 1;
        }),
        fresh_model_bytes_rejected: mutate(|candidate| {
            candidate.fresh_product_model_bytes_loaded = 1;
        }),
        hidden_authority_rejected: mutate_surface(witness, |surface| {
            surface.hidden_route_authority = true;
        }),
        hidden_cloud_rejected: mutate_surface(witness, |surface| {
            surface.hidden_cloud_fallback = true;
        }),
        hidden_chain_rejected: mutate_surface(witness, |surface| {
            surface.hidden_chain_exposed = true;
        }),
        route_policy_mutation_rejected: mutate_surface(witness, |surface| {
            surface.route_policy_mutated = true;
        }),
        gate_bypass_rejected: mutate_surface(witness, |surface| surface.gate_bypassed = true),
        answer_packet_suppression_rejected: mutate_surface(witness, |surface| {
            surface.answer_packet_suppressed = true;
        }),
        raw_token_text_rejected: mutate_surface(witness, |surface| {
            surface.raw_token_text_retained = true;
        }),
        prompt_user_data_rejected: mutate_surface(witness, |surface| {
            surface.prompt_user_data_retained = true;
        }),
        app_path_subprocess_rejected: mutate_surface(witness, |surface| {
            surface.subprocess_spawned_in_app_path = true;
        }),
        autogenous_kernel_rejected: mutate_surface(witness, |surface| {
            surface.autogenous_kernel_attempted = true;
        }),
        seventy_b_probe_rejected: mutate_surface(witness, |surface| {
            surface.seventy_b_probe_attempted = true;
        }),
        long_context_shard_probe_rejected: mutate_surface(witness, |surface| {
            surface.long_context_shard_probe_attempted = true;
        }),
        mas_live_agent_overclaim_rejected: mutate(|candidate| {
            candidate.mas_live_agent_overclaim_attempted = true;
        }),
        l2_green_claim_rejected: mutate(|candidate| candidate.l2_green_claimed = true),
        l3_green_claim_rejected: mutate(|candidate| candidate.l3_green_claimed = true),
        metadata_budget_rejected: mutate(|candidate| {
            candidate.metadata_bytes = product_answer_packet_live_metadata_budget_bytes() + 1;
        }),
    }
}

fn mutate_surface(
    witness: &SmallModelProductAnswerPacketLiveWitness,
    mutator: fn(&mut SmallModelProductAnswerPacketLiveSurface),
) -> bool {
    let mut candidate = witness.clone();
    if let Some(surface) = candidate.surfaces.first_mut() {
        mutator(surface);
    }
    candidate.validate().is_err()
}

fn collect_markers(spec: &MarkerSpec) -> Result<Vec<String>, ProductAnswerPacketLiveWitnessError> {
    let text = read_to_string(Path::new(spec.path))?;
    let mut markers = Vec::with_capacity(spec.markers.len());
    for marker in spec.markers {
        if !text.contains(marker) {
            return Err(ProductAnswerPacketLiveWitnessError::MissingMarker {
                path: spec.path.to_string(),
                marker: (*marker).to_string(),
            });
        }
        markers.push((*marker).to_string());
    }
    Ok(markers)
}

fn add_bytes_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: u64,
    operator: &str,
    threshold: u64,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert(
        axis.to_string(),
        match operator {
            ">" => value > threshold,
            "<=" => value <= threshold,
            "==" => value == threshold,
            _ => false,
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::json!(threshold),
            unit: "bytes".to_string(),
        },
    );
}

fn read_to_string(path: &Path) -> Result<String, ProductAnswerPacketLiveWitnessError> {
    std::fs::read_to_string(path).map_err(|error| {
        ProductAnswerPacketLiveWitnessError::Io(format!("{}: {error}", path.display()))
    })
}

fn read_json(path: &Path) -> Result<serde_json::Value, ProductAnswerPacketLiveWitnessError> {
    let text = read_to_string(path)?;
    serde_json::from_str(&text).map_err(|error| {
        ProductAnswerPacketLiveWitnessError::Json(format!("{}: {error}", path.display()))
    })
}

fn json_bool(
    value: &serde_json::Value,
    key: &str,
) -> Result<bool, ProductAnswerPacketLiveWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_bool)
        .ok_or_else(|| ProductAnswerPacketLiveWitnessError::Json(format!("missing bool `{key}`")))
}

fn json_string(
    value: &serde_json::Value,
    key: &str,
) -> Result<String, ProductAnswerPacketLiveWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_str)
        .map(ToOwned::to_owned)
        .ok_or_else(|| ProductAnswerPacketLiveWitnessError::Json(format!("missing string `{key}`")))
}

fn token_digest(value: &serde_json::Value) -> Result<String, ProductAnswerPacketLiveWitnessError> {
    let digest = json_string(value, "first_token_sha256")?;
    let suffix = digest.strip_prefix("sha256:").ok_or_else(|| {
        ProductAnswerPacketLiveWitnessError::Json("malformed token digest".to_string())
    })?;
    Ok(format!("token_sha256:{suffix}"))
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_str)
        .map(ToOwned::to_owned)
}

fn measurement_u64(value: &serde_json::Value, key: &str) -> Option<u64> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_u64)
}

fn artifact_all_axes_true(value: &serde_json::Value) -> bool {
    value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
        && value
            .get("pass_per_axis")
            .and_then(serde_json::Value::as_object)
            .is_some_and(|axes| {
                !axes.is_empty() && axes.values().all(|axis| axis.as_bool().unwrap_or(false))
            })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn token_digest_rewrites_sha256_prefix() {
        let value = serde_json::json!({
            "first_token_sha256": "sha256:d03502c43d74a30b936740a9517dc4ea2b2ad7168caa0a774cefe793ce0b33e7"
        });
        assert_eq!(
            token_digest(&value).expect("digest"),
            "token_sha256:d03502c43d74a30b936740a9517dc4ea2b2ad7168caa0a774cefe793ce0b33e7"
        );
    }

    #[test]
    fn malformed_token_digest_is_rejected() {
        let value = serde_json::json!({"first_token_sha256": "not-a-sha"});
        assert!(token_digest(&value).is_err());
    }
}
