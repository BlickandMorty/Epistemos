//! `falsify_small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe`.
//!
//! This L1/L3 preflight witness consumes the fresh product-runtime closeout,
//! verifies the release-audit skill is queued as log-first/zero-fail work, and
//! prevents release readiness from being claimed by metadata evidence.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[cfg(test)]
use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    fresh_product_runtime_l3_release_audit_preflight_metadata_budget_bytes,
    fresh_product_runtime_l3_release_audit_preflight_skill_path,
    required_fresh_product_runtime_l3_release_audit_preflight_blockers,
    required_fresh_product_runtime_l3_release_audit_preflight_phases, ProStatus, ProductBuild,
    SmallModelFreshProductRuntimeL3ReleaseAuditPreflightError,
    SmallModelFreshProductRuntimeL3ReleaseAuditPreflightWitness,
    SmallModelProductRouteCapabilityBlocker,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str =
    "F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditPreflightProbe";
const FIXTURE_ID: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const CLOSEOUT_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_capability_closeout_probe/result.json";
const EXPECTED_BLOCKER_COUNT: u64 = 9;
const ZERO_BYTES: u64 = 0;

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-preflight-probe:witness-error
// Plane: Verification
// Residency: falsifier IO/JSON/primitive error wrapper.
enum FreshProductRuntimeL3ReleaseAuditPreflightWitnessError {
    Primitive(SmallModelFreshProductRuntimeL3ReleaseAuditPreflightError),
    Io(String),
    Json(String),
}

impl std::fmt::Display for FreshProductRuntimeL3ReleaseAuditPreflightWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) | Self::Json(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for FreshProductRuntimeL3ReleaseAuditPreflightWitnessError {}

impl From<SmallModelFreshProductRuntimeL3ReleaseAuditPreflightError>
    for FreshProductRuntimeL3ReleaseAuditPreflightWitnessError
{
    fn from(value: SmallModelFreshProductRuntimeL3ReleaseAuditPreflightError) -> Self {
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
    FreshProductRuntimeL3ReleaseAuditPreflightWitnessError,
> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fresh_product_runtime_l3_release_audit_preflight_witness(&evidence)?;
    let deterministic = witness.address()
        == fresh_product_runtime_l3_release_audit_preflight_witness(&evidence)?.address();
    let invalid_axes = invalid_rejections(&witness);
    let metrics = witness.metrics();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let required_blockers_present =
        required_fresh_product_runtime_l3_release_audit_preflight_blockers()
            .into_iter()
            .all(|required| {
                witness
                    .blockers
                    .iter()
                    .any(|blocker| blocker.blocker_id == required)
            });

    let bool_axes = [
        (
            "upstream_l3_capability_closeout_probe_pass",
            evidence.closeout_pass,
        ),
        (
            "guard_cursor_l3_release_audit_preflight_or_advanced",
            evidence.guard_next_existing_work
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_l3_release_audit_preflight_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_NEXT_CURSOR,
        ),
        (
            "product_status_gated",
            witness.product_build == ProductBuild::Pro && witness.pro_status == ProStatus::Gated,
        ),
        (
            "route_authority_preflight_only",
            witness.route_authority
                == "fresh_product_runtime_l3_release_audit_preflight_no_ship_authority",
        ),
        ("release_audit_skill_present", witness.release_audit_skill_exists),
        (
            "release_audit_skill_log_first_required",
            witness.release_audit_log_first_required,
        ),
        (
            "release_audit_skill_zero_fail_required",
            witness.release_audit_zero_fail_required,
        ),
        (
            "release_audit_zero_fail_not_run",
            !witness.release_audit_zero_fail_completed,
        ),
        ("ship_call_not_authorized", !witness.ship_call_authorized),
        (
            "product_capability_not_promoted",
            !witness.product_capability_promoted,
        ),
        (
            "answer_packet_run_event_log_bound",
            witness.answer_packet_run_event_log_bound,
        ),
        (
            "residual_blockers_visible",
            witness.blockers.iter().all(|blocker| blocker.visible),
        ),
        ("required_blockers_present", required_blockers_present),
        (
            "upstream_runtime_bytes_nonzero",
            metrics.upstream_runtime_bytes_loaded > 0,
        ),
        (
            "upstream_model_bytes_nonzero",
            metrics.upstream_model_bytes_loaded > 0,
        ),
        (
            "preflight_runtime_bytes_zero",
            metrics.preflight_runtime_bytes_loaded == 0,
        ),
        (
            "preflight_model_bytes_zero",
            metrics.preflight_model_bytes_loaded == 0,
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
            "no_hidden_route_authority",
            !witness.hidden_authority_attempted
                && witness
                    .blockers
                    .iter()
                    .all(|blocker| !blocker.hidden_route_authority),
        ),
        (
            "no_route_policy_mutation",
            !witness.route_mutation_attempted
                && witness
                    .blockers
                    .iter()
                    .all(|blocker| !blocker.route_policy_mutated),
        ),
        ("heavy_routes_deferred", !evidence.heavy_long_context_enabled),
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
            "next_l3_release_audit_zero_fail_bound",
            witness.next_cursor
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_NEXT_CURSOR,
        ),
        (
            "required_phases_bound",
            metrics.phase_count
                == required_fresh_product_runtime_l3_release_audit_preflight_phases().len()
                    as u64,
        ),
        (
            "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe_address_deterministic",
            deterministic,
        ),
        (
            "missing_upstream_closeout_rejected",
            invalid_axes.missing_upstream_closeout_rejected,
        ),
        (
            "missing_release_audit_skill_rejected",
            invalid_axes.missing_release_audit_skill_rejected,
        ),
        (
            "missing_release_audit_log_first_rejected",
            invalid_axes.missing_release_audit_log_first_rejected,
        ),
        (
            "missing_release_audit_zero_fail_rejected",
            invalid_axes.missing_release_audit_zero_fail_rejected,
        ),
        (
            "missing_required_blocker_rejected",
            invalid_axes.missing_required_blocker_rejected,
        ),
        (
            "duplicate_blocker_rejected",
            invalid_axes.duplicate_blocker_rejected,
        ),
        (
            "blocker_green_rejected",
            invalid_axes.blocker_green_rejected,
        ),
        (
            "hidden_authority_rejected",
            invalid_axes.hidden_authority_rejected,
        ),
        (
            "route_policy_mutation_rejected",
            invalid_axes.route_policy_mutation_rejected,
        ),
        (
            "zero_fail_completion_claim_rejected",
            invalid_axes.zero_fail_completion_claim_rejected,
        ),
        (
            "ship_call_authorized_rejected",
            invalid_axes.ship_call_authorized_rejected,
        ),
        (
            "product_capability_promotion_rejected",
            invalid_axes.product_capability_promotion_rejected,
        ),
        (
            "upstream_runtime_missing_rejected",
            invalid_axes.upstream_runtime_missing_rejected,
        ),
        (
            "upstream_model_missing_rejected",
            invalid_axes.upstream_model_missing_rejected,
        ),
        (
            "preflight_runtime_bytes_rejected",
            invalid_axes.preflight_runtime_bytes_rejected,
        ),
        (
            "preflight_model_bytes_rejected",
            invalid_axes.preflight_model_bytes_rejected,
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
        "blocker_count",
        metrics.blocker_count,
        EXPECTED_BLOCKER_COUNT,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "phase_count",
        metrics.phase_count,
        required_fresh_product_runtime_l3_release_audit_preflight_phases().len() as u64,
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
        "preflight_runtime_bytes_loaded",
        metrics.preflight_runtime_bytes_loaded,
        "==",
        ZERO_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "preflight_model_bytes_loaded",
        metrics.preflight_model_bytes_loaded,
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
        fresh_product_runtime_l3_release_audit_preflight_metadata_budget_bytes(),
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
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_NEXT_CURSOR
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
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    let address = witness.address();
    measurements.insert(
        "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe_address"
            .to_string(),
        Measurement {
            value: serde_json::json!(address),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe_address"
            .to_string(),
        deterministic,
    );
    thresholds.insert(
        "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe_address"
            .to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: measurements
                .get("small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe_address")
                .map(|measurement| measurement.value.clone())
                .unwrap_or_else(|| serde_json::json!("")),
            unit: "sha256".to_string(),
        },
    );
    measurements.insert(
        "release_audit_skill_ref".to_string(),
        Measurement {
            value: serde_json::json!(fresh_product_runtime_l3_release_audit_preflight_skill_path()),
            unit: "path".to_string(),
        },
    );
    pass_per_axis.insert("release_audit_skill_ref".to_string(), true);
    thresholds.insert(
        "release_audit_skill_ref".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(fresh_product_runtime_l3_release_audit_preflight_skill_path()),
            unit: "path".to_string(),
        },
    );
    measurements.insert(
        "blocker_ids".to_string(),
        Measurement {
            value: serde_json::json!(witness
                .blockers
                .iter()
                .map(|blocker| blocker.blocker_id.clone())
                .collect::<Vec<_>>()),
            unit: "ids".to_string(),
        },
    );
    pass_per_axis.insert("blocker_ids".to_string(), true);
    thresholds.insert(
        "blocker_ids".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(
                required_fresh_product_runtime_l3_release_audit_preflight_blockers()
            ),
            unit: "ids".to_string(),
        },
    );

    let anomalies = vec![serde_json::json!({
        "kind": "small_model_fresh_product_runtime_l3_release_audit_preflight_red",
        "detail": "Release-audit preflight is queued with log-first and zero-fail requirements. It is not a ship call, not L2 green, and not a product capability promotion."
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
        notes: "L1/L3 F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditPreflightProbe: queues the release-audit skill as log-first/zero-fail work, preserves red L2/L3 blockers, opens zero fresh bytes, and advances only to the zero-fail release-audit probe."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn fresh_product_runtime_l3_release_audit_preflight_witness(
    evidence: &EvidenceSnapshot,
) -> Result<
    SmallModelFreshProductRuntimeL3ReleaseAuditPreflightWitness,
    FreshProductRuntimeL3ReleaseAuditPreflightWitnessError,
> {
    SmallModelFreshProductRuntimeL3ReleaseAuditPreflightWitness::new(
        "small-model-fresh-product-runtime-l3-release-audit-preflight:red-state",
        "artifact:small_model_runtime_harness_fresh_product_runtime_l3_capability_closeout_probe:result",
        fresh_product_runtime_l3_release_audit_preflight_skill_path(),
        evidence.guard_next_existing_work.clone(),
        evidence.capability_overall_pass,
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::Gated,
        "fresh_product_runtime_l3_release_audit_preflight_no_ship_authority",
        release_audit_preflight_blockers(evidence),
        required_fresh_product_runtime_l3_release_audit_preflight_phases().to_vec(),
        evidence.upstream_runtime_bytes_loaded,
        evidence.upstream_model_bytes_loaded,
        0,
        0,
        evidence.release_audit_skill_exists,
        evidence.release_audit_log_first_required,
        evidence.release_audit_zero_fail_required,
        false,
        false,
        false,
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
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_NEXT_CURSOR,
        evidence.metadata_bytes,
    )
    .map_err(FreshProductRuntimeL3ReleaseAuditPreflightWitnessError::from)
}

// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-preflight-probe:evidence-snapshot
// Plane: Verification
// Residency: guard/kernel/closeout/skill state consumed by the preflight.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    closeout_pass: bool,
    upstream_runtime_bytes_loaded: u64,
    upstream_model_bytes_loaded: u64,
    heavy_long_context_enabled: bool,
    kv_direct_live_128k_pass: bool,
    seventy_b_route_pass: bool,
    release_audit_skill_exists: bool,
    release_audit_log_first_required: bool,
    release_audit_zero_fail_required: bool,
    metadata_bytes: u64,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, FreshProductRuntimeL3ReleaseAuditPreflightWitnessError> {
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        let closeout = read_json(Path::new(CLOSEOUT_PATH))?;
        let skill_path = Path::new(fresh_product_runtime_l3_release_audit_preflight_skill_path());
        let release_audit_skill_text = std::fs::read_to_string(skill_path).unwrap_or_default();
        let closeout_metadata_bytes = std::fs::metadata(CLOSEOUT_PATH)
            .map(|metadata| metadata.len())
            .unwrap_or(0);
        let skill_metadata_bytes = std::fs::metadata(skill_path)
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
            closeout_pass: artifact_all_axes_true(&closeout),
            upstream_runtime_bytes_loaded: measurement_u64(
                &closeout,
                "upstream_runtime_bytes_loaded",
            )
            .unwrap_or(0),
            upstream_model_bytes_loaded: measurement_u64(&closeout, "upstream_model_bytes_loaded")
                .unwrap_or(0),
            heavy_long_context_enabled: measurement_bool(&capability, "heavy_long_context_enabled")
                .unwrap_or(false),
            kv_direct_live_128k_pass: measurement_bool(&capability, "kv_direct_live_128k_pass")
                .unwrap_or(false),
            seventy_b_route_pass: measurement_bool(&capability, "seventy_b_route_pass")
                .unwrap_or(false),
            release_audit_skill_exists: skill_path.exists(),
            release_audit_log_first_required: release_audit_skill_text
                .contains("logs are first-class evidence"),
            release_audit_zero_fail_required: release_audit_skill_text
                .contains("Recursive zero-fail requirement")
                && release_audit_skill_text.contains("3 uninterrupted passes"),
            metadata_bytes: closeout_metadata_bytes.saturating_add(skill_metadata_bytes),
        })
    }
}

fn release_audit_preflight_blockers(
    evidence: &EvidenceSnapshot,
) -> Vec<SmallModelProductRouteCapabilityBlocker> {
    [
        (
            "blocker:l2_capability_kernel_red",
            "verification",
            "evidence:capability_kernel:overall_pass_false",
            "safety:capability_kernel_must_remain_red_until_zero_fail_release_audit",
        ),
        (
            "blocker:l3_fresh_runtime_manual_review_l1_only",
            "verification",
            "evidence:l3:manual_runtime_review_l1_only",
            "safety:manual_review_not_ship_authority",
        ),
        (
            "blocker:release_audit_skill_log_first_required",
            "verification",
            if evidence.release_audit_log_first_required {
                "evidence:release_audit:log_first_skill_bound"
            } else {
                "evidence:release_audit:log_first_missing"
            },
            "safety:logs_must_correlate_with_runtime_and_ui",
        ),
        (
            "blocker:release_audit_zero_fail_not_run",
            "verification",
            if evidence.release_audit_zero_fail_required {
                "evidence:release_audit:zero_fail_required_not_run"
            } else {
                "evidence:release_audit:zero_fail_requirement_missing"
            },
            "safety:recursive_zero_fail_required_before_ship_call",
        ),
        (
            "blocker:mas_live_agent_not_promoted",
            "state",
            "evidence:mas:live_agent_not_promoted",
            "safety:mas_floor_honesty_required",
        ),
        (
            "blocker:live_70b_route_not_promoted",
            "assembly",
            if evidence.seventy_b_route_pass {
                "evidence:70b:unexpected_green"
            } else {
                "evidence:70b:still_red"
            },
            "safety:70b_cold_assembly_only",
        ),
        (
            "blocker:kv_direct_128k_not_promoted",
            "episodic",
            if evidence.kv_direct_live_128k_pass {
                "evidence:kv_direct:unexpected_green"
            } else {
                "evidence:kv_direct:still_red"
            },
            "safety:kv_direct_128k_deferred",
        ),
        (
            "blocker:autogenous_kernel_not_promoted",
            "controller",
            "evidence:autogenous_kernel:pro_research_only",
            "safety:dry_run_rollback_required",
        ),
        (
            "blocker:ship_call_not_authorized",
            "verification",
            "evidence:ship_call:not_authorized_by_release_preflight",
            "safety:zero_fail_release_audit_and_manual_runtime_required",
        ),
    ]
    .into_iter()
    .map(
        |(blocker_id, plane, evidence_ref, safety_ref)| SmallModelProductRouteCapabilityBlocker {
            blocker_id: blocker_id.to_string(),
            plane: plane.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            evidence_ref: evidence_ref.to_string(),
            answer_packet_ref: "answer_packet:fresh_runtime_l3_release_audit_preflight:red"
                .to_string(),
            rollback_ref: "rollback:no_release_readiness_from_preflight".to_string(),
            budget_ref: "budget:zero_preflight_runtime_bytes".to_string(),
            safety_ref: safety_ref.to_string(),
            visible: true,
            currently_green: false,
            hidden_route_authority: false,
            route_policy_mutated: false,
        },
    )
    .collect()
}

#[derive(Default)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-preflight-probe:invalid-axes
// Plane: Verification
// Residency: invalid fixture coverage for release-audit preflight rejection paths.
struct InvalidAxes {
    missing_upstream_closeout_rejected: bool,
    missing_release_audit_skill_rejected: bool,
    missing_release_audit_log_first_rejected: bool,
    missing_release_audit_zero_fail_rejected: bool,
    missing_required_blocker_rejected: bool,
    duplicate_blocker_rejected: bool,
    blocker_green_rejected: bool,
    hidden_authority_rejected: bool,
    route_policy_mutation_rejected: bool,
    zero_fail_completion_claim_rejected: bool,
    ship_call_authorized_rejected: bool,
    product_capability_promotion_rejected: bool,
    upstream_runtime_missing_rejected: bool,
    upstream_model_missing_rejected: bool,
    preflight_runtime_bytes_rejected: bool,
    preflight_model_bytes_rejected: bool,
    mas_live_agent_overclaim_rejected: bool,
    l2_green_claim_rejected: bool,
    l3_green_claim_rejected: bool,
    autogenous_kernel_rejected: bool,
    seventy_b_product_claim_rejected: bool,
    long_context_shard_claim_rejected: bool,
    next_cursor_mismatch_rejected: bool,
    metadata_budget_rejected: bool,
}

fn invalid_rejections(
    witness: &SmallModelFreshProductRuntimeL3ReleaseAuditPreflightWitness,
) -> InvalidAxes {
    let mutate = |mutator: fn(&mut SmallModelFreshProductRuntimeL3ReleaseAuditPreflightWitness)| {
        let mut candidate = witness.clone();
        mutator(&mut candidate);
        candidate.validate().is_err()
    };
    InvalidAxes {
        missing_upstream_closeout_rejected: mutate(|candidate| {
            candidate.upstream_closeout_artifact_ref.clear();
        }),
        missing_release_audit_skill_rejected: mutate(|candidate| {
            candidate.release_audit_skill_exists = false;
        }),
        missing_release_audit_log_first_rejected: mutate(|candidate| {
            candidate.release_audit_log_first_required = false;
        }),
        missing_release_audit_zero_fail_rejected: mutate(|candidate| {
            candidate.release_audit_zero_fail_required = false;
        }),
        missing_required_blocker_rejected: mutate(|candidate| {
            candidate
                .blockers
                .retain(|blocker| blocker.blocker_id != "blocker:release_audit_zero_fail_not_run");
        }),
        duplicate_blocker_rejected: mutate(|candidate| {
            candidate.blockers[1] = candidate.blockers[0].clone();
        }),
        blocker_green_rejected: mutate_blocker(witness, |blocker| blocker.currently_green = true),
        hidden_authority_rejected: mutate_blocker(witness, |blocker| {
            blocker.hidden_route_authority = true;
        }),
        route_policy_mutation_rejected: mutate_blocker(witness, |blocker| {
            blocker.route_policy_mutated = true;
        }),
        zero_fail_completion_claim_rejected: mutate(|candidate| {
            candidate.release_audit_zero_fail_completed = true;
        }),
        ship_call_authorized_rejected: mutate(|candidate| {
            candidate.ship_call_authorized = true;
        }),
        product_capability_promotion_rejected: mutate(|candidate| {
            candidate.product_capability_promoted = true;
        }),
        upstream_runtime_missing_rejected: mutate(|candidate| {
            candidate.upstream_runtime_bytes_loaded = 0;
        }),
        upstream_model_missing_rejected: mutate(|candidate| {
            candidate.upstream_model_bytes_loaded = 0;
        }),
        preflight_runtime_bytes_rejected: mutate(|candidate| {
            candidate.preflight_runtime_bytes_loaded = 1;
        }),
        preflight_model_bytes_rejected: mutate(|candidate| {
            candidate.preflight_model_bytes_loaded = 1;
        }),
        mas_live_agent_overclaim_rejected: mutate(|candidate| {
            candidate.mas_live_agent_overclaim_attempted = true;
        }),
        l2_green_claim_rejected: mutate(|candidate| candidate.l2_green_claimed = true),
        l3_green_claim_rejected: mutate(|candidate| candidate.l3_green_claimed = true),
        autogenous_kernel_rejected: mutate(|candidate| {
            candidate.autogenous_kernel_attempted = true;
        }),
        seventy_b_product_claim_rejected: mutate(|candidate| {
            candidate.seventy_b_product_claimed = true;
        }),
        long_context_shard_claim_rejected: mutate(|candidate| {
            candidate.long_context_shard_product_claimed = true;
        }),
        next_cursor_mismatch_rejected: mutate(|candidate| candidate.next_cursor = "done".into()),
        metadata_budget_rejected: mutate(|candidate| {
            candidate.metadata_bytes =
                fresh_product_runtime_l3_release_audit_preflight_metadata_budget_bytes() + 1;
        }),
    }
}

fn mutate_blocker(
    witness: &SmallModelFreshProductRuntimeL3ReleaseAuditPreflightWitness,
    mutator: fn(&mut SmallModelProductRouteCapabilityBlocker),
) -> bool {
    let mut candidate = witness.clone();
    if let Some(blocker) = candidate.blockers.first_mut() {
        mutator(blocker);
    }
    candidate.validate().is_err()
}

fn read_json(
    path: &Path,
) -> Result<serde_json::Value, FreshProductRuntimeL3ReleaseAuditPreflightWitnessError> {
    let text = std::fs::read_to_string(path).map_err(|error| {
        FreshProductRuntimeL3ReleaseAuditPreflightWitnessError::Io(format!(
            "failed to read {}: {error}",
            path.display()
        ))
    })?;
    serde_json::from_str(&text).map_err(|error| {
        FreshProductRuntimeL3ReleaseAuditPreflightWitnessError::Json(format!(
            "failed to parse {}: {error}",
            path.display()
        ))
    })
}

fn json_bool(
    value: &serde_json::Value,
    key: &str,
) -> Result<bool, FreshProductRuntimeL3ReleaseAuditPreflightWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_bool)
        .ok_or_else(|| {
            FreshProductRuntimeL3ReleaseAuditPreflightWitnessError::Json(format!(
                "missing bool `{key}`"
            ))
        })
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_str)
        .map(str::to_string)
}

fn measurement_u64(value: &serde_json::Value, key: &str) -> Option<u64> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_u64)
}

fn measurement_bool(value: &serde_json::Value, key: &str) -> Option<bool> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_bool)
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
    fn blocker_ids_match_required_contract() {
        let evidence = EvidenceSnapshot {
            guard_next_existing_work:
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_CURSOR
                    .to_string(),
            capability_overall_pass: false,
            capability_route_status: "vault_research_route_with_packetized_mitigation".to_string(),
            capability_next_bottleneck:
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_CURSOR
                    .to_string(),
            closeout_pass: true,
            upstream_runtime_bytes_loaded: 1,
            upstream_model_bytes_loaded: 1,
            heavy_long_context_enabled: false,
            kv_direct_live_128k_pass: false,
            seventy_b_route_pass: false,
            release_audit_skill_exists: true,
            release_audit_log_first_required: true,
            release_audit_zero_fail_required: true,
            metadata_bytes: 1,
        };
        let blockers = release_audit_preflight_blockers(&evidence);
        for required in required_fresh_product_runtime_l3_release_audit_preflight_blockers() {
            assert!(blockers
                .iter()
                .any(|blocker| blocker.blocker_id == required));
        }
    }

    #[test]
    fn axis_contract_has_no_duplicates() {
        let mut seen = std::collections::BTreeSet::new();
        for axis in
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_PREFLIGHT_PROBE_AXES
        {
            assert!(seen.insert(*axis), "duplicate axis {axis}");
        }
    }
}
