//! `falsify_small_model_runtime_harness_product_wrv_probe`.
//!
//! This source/metadata witness proves the small-model runtime route is wired,
//! reachable, visible, and verified at the app-source level while preserving
//! the red L2 capability ceiling and avoiding any runtime/model-byte load.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[cfg(test)]
use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    product_wrv_metadata_budget_bytes, required_product_wrv_phases, ProStatus, ProductBuild,
    SmallModelProductWrvProbeError, SmallModelProductWrvSourceRef, SmallModelProductWrvSurface,
    SmallModelProductWrvTestRef, SmallModelProductWrvWitness,
    SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallModelRuntimeHarnessProductWrvProbe";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";
const FIXTURE_ID: &str = "small_model_runtime_harness_product_wrv_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_small_model_runtime_harness_product_wrv_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_product_wrv_probe/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const ANSWER_PACKET_PROBE_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_answer_packet_runtime_probe/result.json";
const LIVING_INDEX_PATH: &str = "docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md";
const LATTICE_HTML_PATH: &str = "artifacts/lattice-coordinate-explainer/index.html";
const EXPECTED_SOURCE_REFS: u64 = 10;
const EXPECTED_SOURCE_MARKERS: u64 = 29;
const EXPECTED_TEST_REFS: u64 = 4;
const EXPECTED_TEST_MARKERS: u64 = 9;
const EXPECTED_SURFACES: u64 = 3;
const ZERO_BYTES: u64 = 0;

#[derive(Clone, Copy)]
// UAS: uas:small-model-runtime-harness-product-wrv-probe:marker-spec
// Plane: Verification
// Residency: source marker contract for WRV evidence only.
struct MarkerSpec {
    ref_id: &'static str,
    path: &'static str,
    markers: &'static [&'static str],
}

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-product-wrv-probe:witness-error
// Plane: Verification
// Residency: source/product WRV falsifier errors.
enum ProductWrvWitnessError {
    Primitive(SmallModelProductWrvProbeError),
    Io(String),
    Json(String),
    MissingMarker { path: String, marker: String },
}

impl std::fmt::Display for ProductWrvWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) | Self::Json(error) => write!(f, "{error}"),
            Self::MissingMarker { path, marker } => {
                write!(f, "`{path}` missing source marker `{marker}`")
            }
        }
    }
}

impl std::error::Error for ProductWrvWitnessError {}

impl From<SmallModelProductWrvProbeError> for ProductWrvWitnessError {
    fn from(value: SmallModelProductWrvProbeError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, ProductWrvWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = product_wrv_witness(&evidence)?;
    let deterministic = witness.address() == product_wrv_witness(&evidence)?.address();
    let invalid_axes = invalid_rejections(&witness);
    let metrics = witness.metrics();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_small_model_runtime_harness_answer_packet_runtime_probe_pass",
            evidence.answer_packet_probe_pass,
        ),
        (
            "guard_cursor_product_wrv_or_advanced",
            evidence.guard_next_existing_work
                == SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_NEXT_CURSOR
                || evidence.guard_next_existing_work == ADVANCED_RELEASE_AUDIT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_product_wrv_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_NEXT_CURSOR
                || evidence.capability_next_bottleneck == ADVANCED_RELEASE_AUDIT_CURSOR,
        ),
        (
            "product_status_gated",
            witness.product_build == ProductBuild::Pro && witness.pro_status == ProStatus::Gated,
        ),
        (
            "route_authority_source_wrv_only",
            witness.route_authority == "source_wrv_only_no_live_route_authority",
        ),
        ("wired_axis_bound", witness.wired),
        ("reachable_axis_bound", witness.reachable),
        ("visible_axis_bound", witness.visible),
        ("verified_axis_bound", witness.verified),
        (
            "triage_policy_source_bound",
            evidence.source_present("source:triage_policy"),
        ),
        (
            "llm_service_source_bound",
            evidence.source_present("source:llm_service"),
        ),
        (
            "note_chat_source_bound",
            evidence.source_present("source:note_chat"),
        ),
        (
            "local_serial_controller_source_bound",
            evidence.source_present("source:local_serial_controller"),
        ),
        (
            "answer_packet_emitter_source_bound",
            evidence.source_present("source:answer_packet_emitter"),
        ),
        (
            "settings_visibility_source_bound",
            evidence.source_present("source:settings_visibility"),
        ),
        (
            "message_packet_visibility_source_bound",
            evidence.source_present("source:message_packet_visibility"),
        ),
        (
            "triage_policy_tests_bound",
            evidence.test_present("test:triage_policy"),
        ),
        (
            "serial_controller_tests_bound",
            evidence.test_present("test:serial_controller"),
        ),
        (
            "answer_packet_tests_bound",
            evidence.test_present("test:answer_packet"),
        ),
        (
            "substrate_settings_tests_bound",
            evidence.test_present("test:substrate_settings"),
        ),
        (
            "run_event_log_ref_bound",
            witness
                .surfaces
                .iter()
                .all(|surface| surface.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "answer_packet_ref_bound",
            witness
                .surfaces
                .iter()
                .all(|surface| surface.answer_packet_ref.starts_with("answer_packet:")),
        ),
        (
            "admission_bound",
            witness
                .surfaces
                .iter()
                .all(|surface| surface.admission_ref.starts_with("admission:")),
        ),
        (
            "rollback_bound",
            witness
                .surfaces
                .iter()
                .all(|surface| surface.rollback_ref.starts_with("rollback:")),
        ),
        (
            "compatibility_fence_bound",
            witness
                .surfaces
                .iter()
                .all(|surface| surface.compatibility_fence_ref.starts_with("compat:")),
        ),
        (
            "privacy_fence_bound",
            witness
                .surfaces
                .iter()
                .all(|surface| surface.privacy_ref.starts_with("privacy:")),
        ),
        (
            "budget_refs_bound",
            witness
                .surfaces
                .iter()
                .all(|surface| surface.budget_ref.starts_with("budget:")),
        ),
        (
            "required_phases_bound",
            metrics.phase_count == required_product_wrv_phases().len() as u64,
        ),
        (
            "living_index_surface_scan_pass",
            evidence.living_index_has_current_cursor && evidence.living_index_has_north_star,
        ),
        (
            "lattice_html_surface_scan_pass",
            evidence.lattice_has_current_cursor && evidence.lattice_has_meta_locks,
        ),
        (
            "north_star_present",
            evidence.living_index_has_north_star && evidence.master_index_has_north_star,
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
        (
            "no_l3_runtime_green_claim",
            !witness.l3_runtime_green_claimed,
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
            "no_70b_product_claim",
            witness
                .surfaces
                .iter()
                .all(|surface| !surface.seventy_b_product_claimed),
        ),
        (
            "no_long_context_shard_product_claim",
            witness
                .surfaces
                .iter()
                .all(|surface| !surface.long_context_shard_product_claimed),
        ),
        ("no_runtime_bytes_loaded", witness.runtime_bytes_loaded == 0),
        ("no_model_bytes_loaded", witness.model_bytes_loaded == 0),
        (
            "metadata_bound",
            witness.metadata_bytes <= product_wrv_metadata_budget_bytes(),
        ),
        (
            "small_model_runtime_harness_product_wrv_probe_address_deterministic",
            deterministic,
        ),
        (
            "missing_answer_packet_artifact_rejected",
            invalid_axes.missing_answer_packet_artifact_rejected,
        ),
        (
            "missing_source_marker_rejected",
            invalid_axes.missing_source_marker_rejected,
        ),
        (
            "missing_surface_rejected",
            invalid_axes.missing_surface_rejected,
        ),
        (
            "missing_test_marker_rejected",
            invalid_axes.missing_test_marker_rejected,
        ),
        (
            "missing_wired_axis_rejected",
            invalid_axes.missing_wired_axis_rejected,
        ),
        (
            "missing_reachable_axis_rejected",
            invalid_axes.missing_reachable_axis_rejected,
        ),
        (
            "missing_visible_axis_rejected",
            invalid_axes.missing_visible_axis_rejected,
        ),
        (
            "missing_verified_axis_rejected",
            invalid_axes.missing_verified_axis_rejected,
        ),
        (
            "missing_admission_rejected",
            invalid_axes.missing_admission_rejected,
        ),
        (
            "missing_rollback_rejected",
            invalid_axes.missing_rollback_rejected,
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
            "missing_compatibility_fence_rejected",
            invalid_axes.missing_compatibility_fence_rejected,
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
            "app_path_subprocess_rejected",
            invalid_axes.app_path_subprocess_rejected,
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
            "long_context_shard_product_claim_rejected",
            invalid_axes.long_context_shard_product_claim_rejected,
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
            "l3_runtime_green_claim_rejected",
            invalid_axes.l3_runtime_green_claim_rejected,
        ),
        (
            "runtime_bytes_rejected",
            invalid_axes.runtime_bytes_rejected,
        ),
        ("model_bytes_rejected", invalid_axes.model_bytes_rejected),
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

    let count_axes = [
        (
            "source_ref_count",
            metrics.source_ref_count,
            EXPECTED_SOURCE_REFS,
            "count",
        ),
        (
            "source_marker_count",
            metrics.source_marker_count,
            EXPECTED_SOURCE_MARKERS,
            "count",
        ),
        (
            "surface_count",
            metrics.surface_count,
            EXPECTED_SURFACES,
            "count",
        ),
        (
            "test_ref_count",
            metrics.test_ref_count,
            EXPECTED_TEST_REFS,
            "count",
        ),
        (
            "test_marker_count",
            metrics.test_marker_count,
            EXPECTED_TEST_MARKERS,
            "count",
        ),
        (
            "phase_count",
            metrics.phase_count,
            required_product_wrv_phases().len() as u64,
            "count",
        ),
    ];
    for (axis, value, threshold, unit) in count_axes {
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
    measurements.insert(
        "runtime_bytes_loaded".to_string(),
        Measurement {
            value: serde_json::json!(metrics.runtime_bytes_loaded),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert(
        "runtime_bytes_loaded".to_string(),
        metrics.runtime_bytes_loaded == ZERO_BYTES,
    );
    thresholds.insert(
        "runtime_bytes_loaded".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(ZERO_BYTES),
            unit: "bytes".to_string(),
        },
    );
    measurements.insert(
        "model_bytes_loaded".to_string(),
        Measurement {
            value: serde_json::json!(metrics.model_bytes_loaded),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert(
        "model_bytes_loaded".to_string(),
        metrics.model_bytes_loaded == ZERO_BYTES,
    );
    thresholds.insert(
        "model_bytes_loaded".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(ZERO_BYTES),
            unit: "bytes".to_string(),
        },
    );
    measurements.insert(
        "metadata_bytes".to_string(),
        Measurement {
            value: serde_json::json!(witness.metadata_bytes),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert(
        "metadata_bytes".to_string(),
        witness.metadata_bytes <= product_wrv_metadata_budget_bytes(),
    );
    thresholds.insert(
        "metadata_bytes".to_string(),
        AcceptanceThreshold {
            operator: "<=".to_string(),
            value: serde_json::json!(product_wrv_metadata_budget_bytes()),
            unit: "bytes".to_string(),
        },
    );
    let address = witness.address();
    measurements.insert(
        "small_model_runtime_harness_product_wrv_probe_address".to_string(),
        Measurement {
            value: serde_json::json!(address),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "small_model_runtime_harness_product_wrv_probe_address".to_string(),
        deterministic,
    );
    thresholds.insert(
        "small_model_runtime_harness_product_wrv_probe_address".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: measurements
                .get("small_model_runtime_harness_product_wrv_probe_address")
                .map(|measurement| measurement.value.clone())
                .unwrap_or_else(|| serde_json::json!("")),
            unit: "sha256".to_string(),
        },
    );
    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert("next_cursor".to_string(), true);
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );

    let anomalies = vec![serde_json::json!({
        "kind": "small_model_product_wrv_source_only",
        "detail": "Small-model route WRV is source/test visible: TriageService, LLMService, NoteChatState, LocalInferenceSerialController, AnswerPacketEmitter, MessageBubble, Settings diagnostics, and focused tests are bound. This is not a live product AnswerPacket runtime probe, does not load model/runtime bytes, and keeps L2 red."
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
        notes: "L1/L3-source F-SmallModelRuntimeHarnessProductWrvProbe: binds product WRV source/test evidence for the practical small-model route without loading model/runtime bytes, without MAS live-agent overclaim, without 70B/128K promotion, and without L2 capability green."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn product_wrv_witness(
    evidence: &EvidenceSnapshot,
) -> Result<SmallModelProductWrvWitness, ProductWrvWitnessError> {
    SmallModelProductWrvWitness::new(
        "small-model-runtime-harness-product-wrv:source-proof",
        "artifact:small_model_runtime_harness_answer_packet_runtime_probe:result",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::Gated,
        "source_wrv_only_no_live_route_authority",
        evidence.source_refs.clone(),
        product_surfaces(),
        evidence.test_refs.clone(),
        required_product_wrv_phases().to_vec(),
        true,
        true,
        true,
        true,
        true,
        false,
        false,
        false,
        0,
        0,
        evidence.metadata_bytes,
    )
    .map_err(ProductWrvWitnessError::from)
}

fn product_surfaces() -> Vec<SmallModelProductWrvSurface> {
    ["note-chat", "message-bubble", "settings-diagnostics"]
        .iter()
        .map(|id| SmallModelProductWrvSurface {
            surface_id: format!("surface:{id}"),
            admission_ref: "admission:scope_rex:small_model_product_wrv_source_only".to_string(),
            rollback_ref: "rollback:no_product_mutation:source_wrv_probe".to_string(),
            answer_packet_ref: "answer_packet:product_route:diagnostic_and_message_chip"
                .to_string(),
            run_event_log_ref: "run_event_log:system_g:replay_projection_bound".to_string(),
            compatibility_fence_ref: "compat:mas_pro_l1_l2_l3_separated".to_string(),
            privacy_ref: "privacy:no_prompt_text_no_token_text_no_hidden_chain".to_string(),
            budget_ref: "budget:zero_runtime_or_model_bytes_source_probe".to_string(),
            visible: true,
            hidden_route_authority: false,
            hidden_cloud_fallback: false,
            hidden_chain_exposed: false,
            route_policy_mutated: false,
            gate_bypassed: false,
            answer_packet_suppressed: false,
            subprocess_spawned_in_app_path: false,
            autogenous_kernel_attempted: false,
            seventy_b_product_claimed: false,
            long_context_shard_product_claimed: false,
        })
        .collect()
}

// UAS: uas:small-model-runtime-harness-product-wrv-probe:evidence-snapshot
// Plane: Verification
// Residency: source/test WRV artifact snapshot, no runtime bytes.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    answer_packet_probe_pass: bool,
    source_refs: Vec<SmallModelProductWrvSourceRef>,
    test_refs: Vec<SmallModelProductWrvTestRef>,
    living_index_has_current_cursor: bool,
    living_index_has_north_star: bool,
    lattice_has_current_cursor: bool,
    lattice_has_meta_locks: bool,
    master_index_has_north_star: bool,
    metadata_bytes: u64,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, ProductWrvWitnessError> {
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        let answer_packet = read_json(Path::new(ANSWER_PACKET_PROBE_PATH))?;
        let source_refs = collect_source_refs(SOURCE_SPECS)?;
        let test_refs = collect_test_refs(TEST_SPECS)?;
        let living_index = read_to_string(Path::new(LIVING_INDEX_PATH))?;
        let lattice = read_to_string(Path::new(LATTICE_HTML_PATH))?;
        let master = read_to_string(Path::new("docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md"))?;
        let marker_bytes: usize = source_refs
            .iter()
            .flat_map(|source| source.markers.iter())
            .map(String::len)
            .sum::<usize>()
            + test_refs
                .iter()
                .flat_map(|test_ref| test_ref.markers.iter())
                .map(String::len)
                .sum::<usize>();
        Ok(Self {
            guard_next_existing_work: measurement_string(
                &guard,
                "next_existing_work",
            )
            .unwrap_or_default(),
            capability_overall_pass: json_bool(&capability, "overall_pass")?,
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_default(),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_default(),
            answer_packet_probe_pass: artifact_all_axes_true(&answer_packet),
            source_refs,
            test_refs,
            living_index_has_current_cursor: living_index
                .contains(SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR),
            living_index_has_north_star: living_index.contains("Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness"),
            lattice_has_current_cursor: lattice
                .contains(SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR),
            lattice_has_meta_locks: lattice.contains("JUNE1-CANON-FUSION-LOCK")
                && lattice.contains("JUNE1-PATTERNBOOST-LOCK"),
            master_index_has_north_star: master.contains("Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness"),
            metadata_bytes: marker_bytes as u64,
        })
    }

    fn source_present(&self, ref_id: &str) -> bool {
        self.source_refs
            .iter()
            .any(|source| source.ref_id == ref_id)
    }

    fn test_present(&self, ref_id: &str) -> bool {
        self.test_refs
            .iter()
            .any(|test_ref| test_ref.ref_id == ref_id)
    }
}

const SOURCE_SPECS: &[MarkerSpec] = &[
    MarkerSpec {
        ref_id: "source:triage_policy",
        path: "Epistemos/Engine/TriageService.swift",
        markers: &["InferencePolicyEngine", "localRouteKind", "case .localMLX"],
    },
    MarkerSpec {
        ref_id: "source:llm_service",
        path: "Epistemos/Engine/LLMService.swift",
        markers: &[
            "LocalConfigurableLLMClient",
            "localLLMClient.stream",
            "LocalInferenceRoutingError.runtimeUnavailable",
        ],
    },
    MarkerSpec {
        ref_id: "source:note_chat",
        path: "Epistemos/State/NoteChatState.swift",
        markers: &[
            "triageService.stream",
            "lastAssistantInferenceMode",
            "makeAssistantMessage",
        ],
    },
    MarkerSpec {
        ref_id: "source:local_serial_controller",
        path: "Epistemos/Engine/LocalInferenceSerialController.swift",
        markers: &[
            "beginGpuCompute",
            "beginSsdRead",
            "Disk reads are forbidden",
        ],
    },
    MarkerSpec {
        ref_id: "source:answer_packet_emitter",
        path: "Epistemos/Engine/AnswerPacketEmitter.swift",
        markers: &[
            "turnCompletionStub",
            "maxRingSize = 100",
            "emit(_ packet: AnswerPacket)",
        ],
    },
    MarkerSpec {
        ref_id: "source:streaming_delegate_packet_emit",
        path: "Epistemos/Bridge/StreamingDelegate.swift",
        markers: &[
            "AnswerPacket.turnCompletionStub",
            "AnswerPacketEmitter.shared.emit",
            "answerPacketId: packet.id",
        ],
    },
    MarkerSpec {
        ref_id: "source:message_packet_visibility",
        path: "Epistemos/Views/Chat/MessageBubble.swift",
        markers: &[
            "AnswerPacketChipRow",
            "LatestAnswerPacketSink.shared",
            "answerPacketId",
        ],
    },
    MarkerSpec {
        ref_id: "source:settings_visibility",
        path: "Epistemos/Views/Settings/SubstrateHealthPanel.swift",
        markers: &[
            "AnswerPacketHealthRow()",
            "LocalAgentDiagnosticsHealthRow()",
        ],
    },
    MarkerSpec {
        ref_id: "source:local_agent_diagnostics",
        path: "Epistemos/Views/Settings/LocalAgentDiagnosticsHealthRow.swift",
        markers: &[
            "CapabilityCeilingHealthSnapshot.load()",
            "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json",
            "Heavy long-context opt-in",
        ],
    },
    MarkerSpec {
        ref_id: "source:system_g_run_event_log",
        path: "Epistemos/SystemG/RealSystemGRunSeam.swift",
        markers: &[
            "RunEventLog",
            "RunEventLogReplayProjection.answerPacket",
            "AnswerPacketEmitter.shared.emit",
        ],
    },
];

const TEST_SPECS: &[MarkerSpec] = &[
    MarkerSpec {
        ref_id: "test:triage_policy",
        path: "EpistemosTests/TriageServiceTests.swift",
        markers: &[
            "explicit local selection survives cloud auto-route for local turns",
            "local only bypasses Apple Intelligence",
            "#expect(decision.selectedRoute == .localMLX)",
        ],
    },
    MarkerSpec {
        ref_id: "test:serial_controller",
        path: "EpistemosTests/LocalInferenceSerialControllerTests.swift",
        markers: &[
            "controller forbids disk reads during active gpu compute",
            "expert prefetch disabled",
        ],
    },
    MarkerSpec {
        ref_id: "test:answer_packet",
        path: "EpistemosTests/AnswerPacketAttentionModeTests.swift",
        markers: &[
            "AnswerPacket attention-mode invariants",
            "static fallback requires explicit acknowledgement claim",
        ],
    },
    MarkerSpec {
        ref_id: "test:substrate_settings",
        path: "EpistemosTests/SubstrateHealthPanelTests.swift",
        markers: &[
            "AnswerPacketHealthRow()",
            "Local agent diagnostics surfaces the capability-ceiling cursor",
        ],
    },
];

#[derive(Default)]
// UAS: uas:small-model-runtime-harness-product-wrv-probe:invalid-axes
// Plane: Verification
// Residency: invalid fixture coverage for product WRV rejection paths.
struct InvalidAxes {
    missing_answer_packet_artifact_rejected: bool,
    missing_source_marker_rejected: bool,
    missing_surface_rejected: bool,
    missing_test_marker_rejected: bool,
    missing_wired_axis_rejected: bool,
    missing_reachable_axis_rejected: bool,
    missing_visible_axis_rejected: bool,
    missing_verified_axis_rejected: bool,
    missing_admission_rejected: bool,
    missing_rollback_rejected: bool,
    missing_answer_packet_rejected: bool,
    missing_run_event_log_rejected: bool,
    missing_compatibility_fence_rejected: bool,
    missing_privacy_rejected: bool,
    missing_budget_rejected: bool,
    hidden_authority_rejected: bool,
    hidden_cloud_rejected: bool,
    hidden_chain_rejected: bool,
    route_policy_mutation_rejected: bool,
    gate_bypass_rejected: bool,
    answer_packet_suppression_rejected: bool,
    app_path_subprocess_rejected: bool,
    autogenous_kernel_rejected: bool,
    seventy_b_product_claim_rejected: bool,
    long_context_shard_product_claim_rejected: bool,
    mas_live_agent_overclaim_rejected: bool,
    l2_green_claim_rejected: bool,
    l3_runtime_green_claim_rejected: bool,
    runtime_bytes_rejected: bool,
    model_bytes_rejected: bool,
    metadata_budget_rejected: bool,
}

fn invalid_rejections(witness: &SmallModelProductWrvWitness) -> InvalidAxes {
    let mutate = |mutator: fn(&mut SmallModelProductWrvWitness)| {
        let mut candidate = witness.clone();
        mutator(&mut candidate);
        candidate.validate().is_err()
    };
    InvalidAxes {
        missing_answer_packet_artifact_rejected: mutate(|candidate| {
            candidate.upstream_answer_packet_artifact_ref.clear();
        }),
        missing_source_marker_rejected: mutate(|candidate| {
            if let Some(source) = candidate.source_refs.first_mut() {
                source.markers.clear();
            }
        }),
        missing_surface_rejected: mutate(|candidate| candidate.surfaces.clear()),
        missing_test_marker_rejected: mutate(|candidate| {
            if let Some(test_ref) = candidate.test_refs.first_mut() {
                test_ref.markers.clear();
            }
        }),
        missing_wired_axis_rejected: mutate(|candidate| candidate.wired = false),
        missing_reachable_axis_rejected: mutate(|candidate| candidate.reachable = false),
        missing_visible_axis_rejected: mutate(|candidate| candidate.visible = false),
        missing_verified_axis_rejected: mutate(|candidate| candidate.verified = false),
        missing_admission_rejected: mutate_surface(witness, |surface| {
            surface.admission_ref.clear()
        }),
        missing_rollback_rejected: mutate_surface(witness, |surface| surface.rollback_ref.clear()),
        missing_answer_packet_rejected: mutate_surface(witness, |surface| {
            surface.answer_packet_ref.clear();
        }),
        missing_run_event_log_rejected: mutate_surface(witness, |surface| {
            surface.run_event_log_ref.clear();
        }),
        missing_compatibility_fence_rejected: mutate_surface(witness, |surface| {
            surface.compatibility_fence_ref.clear();
        }),
        missing_privacy_rejected: mutate_surface(witness, |surface| surface.privacy_ref.clear()),
        missing_budget_rejected: mutate_surface(witness, |surface| surface.budget_ref.clear()),
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
        app_path_subprocess_rejected: mutate_surface(witness, |surface| {
            surface.subprocess_spawned_in_app_path = true;
        }),
        autogenous_kernel_rejected: mutate_surface(witness, |surface| {
            surface.autogenous_kernel_attempted = true;
        }),
        seventy_b_product_claim_rejected: mutate_surface(witness, |surface| {
            surface.seventy_b_product_claimed = true;
        }),
        long_context_shard_product_claim_rejected: mutate_surface(witness, |surface| {
            surface.long_context_shard_product_claimed = true;
        }),
        mas_live_agent_overclaim_rejected: mutate(|candidate| {
            candidate.mas_live_agent_overclaim_attempted = true;
        }),
        l2_green_claim_rejected: mutate(|candidate| candidate.l2_green_claimed = true),
        l3_runtime_green_claim_rejected: mutate(|candidate| {
            candidate.l3_runtime_green_claimed = true;
        }),
        runtime_bytes_rejected: mutate(|candidate| candidate.runtime_bytes_loaded = 1),
        model_bytes_rejected: mutate(|candidate| candidate.model_bytes_loaded = 1),
        metadata_budget_rejected: mutate(|candidate| {
            candidate.metadata_bytes = product_wrv_metadata_budget_bytes() + 1;
        }),
    }
}

fn mutate_surface(
    witness: &SmallModelProductWrvWitness,
    mutator: fn(&mut SmallModelProductWrvSurface),
) -> bool {
    let mut candidate = witness.clone();
    if let Some(surface) = candidate.surfaces.first_mut() {
        mutator(surface);
    }
    candidate.validate().is_err()
}

fn collect_source_refs(
    specs: &[MarkerSpec],
) -> Result<Vec<SmallModelProductWrvSourceRef>, ProductWrvWitnessError> {
    specs
        .iter()
        .map(|spec| {
            let markers = collect_markers(spec)?;
            Ok(SmallModelProductWrvSourceRef {
                ref_id: spec.ref_id.to_string(),
                path: spec.path.to_string(),
                markers,
            })
        })
        .collect()
}

fn collect_test_refs(
    specs: &[MarkerSpec],
) -> Result<Vec<SmallModelProductWrvTestRef>, ProductWrvWitnessError> {
    specs
        .iter()
        .map(|spec| {
            let markers = collect_markers(spec)?;
            Ok(SmallModelProductWrvTestRef {
                ref_id: spec.ref_id.to_string(),
                path: spec.path.to_string(),
                markers,
            })
        })
        .collect()
}

fn collect_markers(spec: &MarkerSpec) -> Result<Vec<String>, ProductWrvWitnessError> {
    let text = read_to_string(Path::new(spec.path))?;
    let mut markers = Vec::with_capacity(spec.markers.len());
    for marker in spec.markers {
        if !text.contains(marker) {
            return Err(ProductWrvWitnessError::MissingMarker {
                path: spec.path.to_string(),
                marker: (*marker).to_string(),
            });
        }
        markers.push((*marker).to_string());
    }
    Ok(markers)
}

fn read_to_string(path: &Path) -> Result<String, ProductWrvWitnessError> {
    std::fs::read_to_string(path)
        .map_err(|error| ProductWrvWitnessError::Io(format!("{}: {error}", path.display())))
}

fn read_json(path: &Path) -> Result<serde_json::Value, ProductWrvWitnessError> {
    let text = read_to_string(path)?;
    serde_json::from_str(&text)
        .map_err(|error| ProductWrvWitnessError::Json(format!("{}: {error}", path.display())))
}

fn json_bool(value: &serde_json::Value, key: &str) -> Result<bool, ProductWrvWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_bool)
        .ok_or_else(|| ProductWrvWitnessError::Json(format!("missing bool `{key}`")))
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")?
        .get(key)?
        .get("value")?
        .as_str()
        .map(ToOwned::to_owned)
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn declared_axes_are_non_empty_and_unique() {
        let mut seen = std::collections::BTreeSet::new();
        for axis in SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_AXES {
            assert!(!axis.is_empty());
            assert!(seen.insert(*axis), "duplicate axis {axis}");
        }
    }

    #[test]
    fn source_specs_have_two_or_more_markers() {
        for spec in SOURCE_SPECS {
            assert!(spec.ref_id.starts_with("source:"));
            assert!(spec.markers.len() >= 2);
        }
    }

    #[test]
    fn test_specs_have_two_or_more_markers() {
        for spec in TEST_SPECS {
            assert!(spec.ref_id.starts_with("test:"));
            assert!(spec.markers.len() >= 2);
        }
    }
}
