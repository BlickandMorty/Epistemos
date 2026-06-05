//! `falsify_small_model_runtime_harness_fresh_product_runtime_capability_recheck`.
//!
//! This L1 witness consumes fresh product-runtime WRV proof and rechecks the
//! capability ceiling before any product route can be called green. It opens no
//! model/runtime bytes and queues the next L3 log-correlation proof.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[cfg(test)]
use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    fresh_product_runtime_capability_recheck_metadata_budget_bytes,
    required_fresh_product_runtime_capability_blockers,
    required_fresh_product_runtime_capability_recheck_phases, ProStatus, ProductBuild,
    SmallModelFreshProductRuntimeCapabilityRecheckError,
    SmallModelFreshProductRuntimeCapabilityRecheckWitness, SmallModelProductRouteCapabilityBlocker,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallModelRuntimeHarnessFreshProductRuntimeCapabilityRecheck";
const FIXTURE_ID: &str = "small_model_runtime_harness_fresh_product_runtime_capability_recheck_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_small_model_runtime_harness_fresh_product_runtime_capability_recheck.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_capability_recheck/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const FRESH_WRV_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_wrv_probe/result.json";
const EXPECTED_BLOCKER_COUNT: u64 = 7;
const ZERO_BYTES: u64 = 0;

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-capability-recheck:witness-error
// Plane: Verification
// Residency: falsifier IO/JSON/primitive error wrapper.
enum FreshProductRuntimeCapabilityRecheckWitnessError {
    Primitive(SmallModelFreshProductRuntimeCapabilityRecheckError),
    Io(String),
    Json(String),
}

impl std::fmt::Display for FreshProductRuntimeCapabilityRecheckWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) | Self::Json(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for FreshProductRuntimeCapabilityRecheckWitnessError {}

impl From<SmallModelFreshProductRuntimeCapabilityRecheckError>
    for FreshProductRuntimeCapabilityRecheckWitnessError
{
    fn from(value: SmallModelFreshProductRuntimeCapabilityRecheckError) -> Self {
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
    FreshProductRuntimeCapabilityRecheckWitnessError,
> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fresh_product_runtime_capability_recheck_witness(&evidence)?;
    let deterministic =
        witness.address() == fresh_product_runtime_capability_recheck_witness(&evidence)?.address();
    let invalid_axes = invalid_rejections(&witness);
    let metrics = witness.metrics();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let required_blockers_present = required_fresh_product_runtime_capability_blockers()
        .into_iter()
        .all(|required| {
            witness
                .blockers
                .iter()
                .any(|blocker| blocker.blocker_id == required)
        });

    let bool_axes = [
        (
            "upstream_fresh_product_runtime_wrv_probe_pass",
            evidence.fresh_wrv_pass,
        ),
        (
            "guard_cursor_fresh_product_runtime_capability_recheck_or_advanced",
            evidence.guard_next_existing_work
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_fresh_product_runtime_capability_recheck_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR,
        ),
        (
            "product_status_gated",
            witness.product_build == ProductBuild::Pro && witness.pro_status == ProStatus::Gated,
        ),
        (
            "route_authority_recheck_only",
            witness.route_authority
                == "fresh_product_runtime_capability_recheck_no_route_authority",
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
            "recheck_runtime_bytes_zero",
            metrics.recheck_runtime_bytes_loaded == 0,
        ),
        (
            "recheck_model_bytes_zero",
            metrics.recheck_model_bytes_loaded == 0,
        ),
        (
            "l2_blockers_visible",
            witness.blockers.iter().all(|blocker| blocker.visible),
        ),
        ("required_blockers_present", required_blockers_present),
        (
            "l3_log_correlation_blocker_visible",
            witness.blockers.iter().any(|blocker| {
                blocker.blocker_id == "blocker:fresh_product_runtime_l3_log_correlation_missing"
                    && blocker.visible
            }),
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
            witness
                .blockers
                .iter()
                .all(|blocker| !blocker.hidden_route_authority),
        ),
        (
            "no_route_policy_mutation",
            witness
                .blockers
                .iter()
                .all(|blocker| !blocker.route_policy_mutated),
        ),
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
            "next_l3_log_correlation_probe_bound",
            witness.next_cursor
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR,
        ),
        (
            "required_phases_bound",
            metrics.phase_count
                == required_fresh_product_runtime_capability_recheck_phases().len() as u64,
        ),
        (
            "small_model_runtime_harness_fresh_product_runtime_capability_recheck_address_deterministic",
            deterministic,
        ),
        (
            "missing_fresh_wrv_artifact_rejected",
            invalid_axes.missing_fresh_wrv_artifact_rejected,
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
            "upstream_runtime_missing_rejected",
            invalid_axes.upstream_runtime_missing_rejected,
        ),
        (
            "upstream_model_missing_rejected",
            invalid_axes.upstream_model_missing_rejected,
        ),
        (
            "recheck_runtime_bytes_rejected",
            invalid_axes.recheck_runtime_bytes_rejected,
        ),
        (
            "recheck_model_bytes_rejected",
            invalid_axes.recheck_model_bytes_rejected,
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
        required_fresh_product_runtime_capability_recheck_phases().len() as u64,
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
        "recheck_runtime_bytes_loaded",
        metrics.recheck_runtime_bytes_loaded,
        "==",
        ZERO_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "recheck_model_bytes_loaded",
        metrics.recheck_model_bytes_loaded,
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
        fresh_product_runtime_capability_recheck_metadata_budget_bytes(),
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
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR
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
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    let address = witness.address();
    measurements.insert(
        "small_model_runtime_harness_fresh_product_runtime_capability_recheck_address".to_string(),
        Measurement {
            value: serde_json::json!(address),
            unit: "sha256".to_string(),
        },
    );
    pass_per_axis.insert(
        "small_model_runtime_harness_fresh_product_runtime_capability_recheck_address".to_string(),
        deterministic,
    );
    thresholds.insert(
        "small_model_runtime_harness_fresh_product_runtime_capability_recheck_address".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: measurements
                .get("small_model_runtime_harness_fresh_product_runtime_capability_recheck_address")
                .map(|measurement| measurement.value.clone())
                .unwrap_or_else(|| serde_json::json!("")),
            unit: "sha256".to_string(),
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
            value: serde_json::json!(required_fresh_product_runtime_capability_blockers()),
            unit: "ids".to_string(),
        },
    );

    let anomalies = vec![serde_json::json!({
        "kind": "small_model_fresh_product_runtime_capability_recheck_red",
        "detail": "Fresh Qwen3-4B runtime, AnswerPacket, RunEventLog, and source WRV proof are present, but product capability remains red until L3 log correlation and remaining capability blockers pass. No MAS live-agent, live 70B, KV-Direct 128K, or autogenous-kernel claim promotes."
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
        notes: "L1 F-SmallModelRuntimeHarnessFreshProductRuntimeCapabilityRecheck: records the red L2/L3 product-route blockers after fresh runtime WRV, preserves upstream runtime/model byte evidence, opens zero new bytes, and queues L3 log correlation proof."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn fresh_product_runtime_capability_recheck_witness(
    evidence: &EvidenceSnapshot,
) -> Result<
    SmallModelFreshProductRuntimeCapabilityRecheckWitness,
    FreshProductRuntimeCapabilityRecheckWitnessError,
> {
    SmallModelFreshProductRuntimeCapabilityRecheckWitness::new(
        "small-model-fresh-product-runtime-capability-recheck:red-state",
        "artifact:small_model_runtime_harness_fresh_product_runtime_wrv_probe:result",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_overall_pass,
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::Gated,
        "fresh_product_runtime_capability_recheck_no_route_authority",
        capability_blockers(evidence),
        required_fresh_product_runtime_capability_recheck_phases().to_vec(),
        evidence.upstream_runtime_bytes_loaded,
        evidence.upstream_model_bytes_loaded,
        0,
        0,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR,
        evidence.metadata_bytes,
    )
    .map_err(FreshProductRuntimeCapabilityRecheckWitnessError::from)
}

// UAS: uas:small-model-runtime-harness-fresh-product-runtime-capability-recheck:evidence-snapshot
// Plane: Verification
// Residency: kernel/guard/fresh-WRV state consumed by the red recheck.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    fresh_wrv_pass: bool,
    upstream_runtime_bytes_loaded: u64,
    upstream_model_bytes_loaded: u64,
    heavy_long_context_enabled: bool,
    kv_direct_live_128k_pass: bool,
    seventy_b_route_pass: bool,
    metadata_bytes: u64,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, FreshProductRuntimeCapabilityRecheckWitnessError> {
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        let fresh_wrv = read_json(Path::new(FRESH_WRV_PATH))?;
        Ok(Self {
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_default(),
            capability_overall_pass: json_bool(&capability, "overall_pass")?,
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_default(),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_default(),
            fresh_wrv_pass: artifact_all_axes_true(&fresh_wrv),
            upstream_runtime_bytes_loaded: measurement_u64(
                &fresh_wrv,
                "upstream_runtime_bytes_loaded",
            )
            .unwrap_or(0),
            upstream_model_bytes_loaded: measurement_u64(&fresh_wrv, "upstream_model_bytes_loaded")
                .unwrap_or(0),
            heavy_long_context_enabled: measurement_bool(&capability, "heavy_long_context_enabled")
                .unwrap_or(false),
            kv_direct_live_128k_pass: measurement_bool(&capability, "kv_direct_live_128k_pass")
                .unwrap_or(false),
            seventy_b_route_pass: measurement_bool(&capability, "seventy_b_route_pass")
                .unwrap_or(false),
            metadata_bytes: std::fs::metadata(FRESH_WRV_PATH)
                .map(|metadata| metadata.len())
                .unwrap_or(0),
        })
    }
}

fn capability_blockers(
    evidence: &EvidenceSnapshot,
) -> Vec<SmallModelProductRouteCapabilityBlocker> {
    [
        (
            "blocker:l2_capability_kernel_red",
            "verification",
            "evidence:capability_kernel:overall_pass_false",
            "safety:l3_log_correlation_required",
        ),
        (
            "blocker:fresh_product_runtime_l3_log_correlation_missing",
            "verification",
            "evidence:l3:fresh_product_runtime_log_correlation_missing",
            "safety:l3_log_correlation_required",
        ),
        (
            "blocker:l3_manual_runtime_verification_missing",
            "verification",
            "evidence:l3:manual_runtime_verification_missing",
            "safety:manual_runtime_log_required",
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
    ]
    .into_iter()
    .map(
        |(blocker_id, plane, evidence_ref, safety_ref)| SmallModelProductRouteCapabilityBlocker {
            blocker_id: blocker_id.to_string(),
            plane: plane.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            evidence_ref: evidence_ref.to_string(),
            answer_packet_ref: "answer_packet:fresh_runtime_capability_recheck:red".to_string(),
            rollback_ref: "rollback:no_fresh_product_capability_promotion".to_string(),
            budget_ref: "budget:zero_recheck_runtime_bytes".to_string(),
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
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-capability-recheck:invalid-axes
// Plane: Verification
// Residency: invalid fixture coverage for fresh capability recheck rejection paths.
struct InvalidAxes {
    missing_fresh_wrv_artifact_rejected: bool,
    missing_required_blocker_rejected: bool,
    duplicate_blocker_rejected: bool,
    blocker_green_rejected: bool,
    hidden_authority_rejected: bool,
    route_policy_mutation_rejected: bool,
    upstream_runtime_missing_rejected: bool,
    upstream_model_missing_rejected: bool,
    recheck_runtime_bytes_rejected: bool,
    recheck_model_bytes_rejected: bool,
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
    witness: &SmallModelFreshProductRuntimeCapabilityRecheckWitness,
) -> InvalidAxes {
    let mutate = |mutator: fn(&mut SmallModelFreshProductRuntimeCapabilityRecheckWitness)| {
        let mut candidate = witness.clone();
        mutator(&mut candidate);
        candidate.validate().is_err()
    };
    InvalidAxes {
        missing_fresh_wrv_artifact_rejected: mutate(|candidate| {
            candidate.fresh_wrv_artifact_ref.clear();
        }),
        missing_required_blocker_rejected: mutate(|candidate| {
            candidate.blockers.retain(|blocker| {
                blocker.blocker_id != "blocker:fresh_product_runtime_l3_log_correlation_missing"
            });
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
        upstream_runtime_missing_rejected: mutate(|candidate| {
            candidate.upstream_runtime_bytes_loaded = 0;
        }),
        upstream_model_missing_rejected: mutate(|candidate| {
            candidate.upstream_model_bytes_loaded = 0;
        }),
        recheck_runtime_bytes_rejected: mutate(|candidate| {
            candidate.recheck_runtime_bytes_loaded = 1;
        }),
        recheck_model_bytes_rejected: mutate(|candidate| {
            candidate.recheck_model_bytes_loaded = 1;
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
                fresh_product_runtime_capability_recheck_metadata_budget_bytes() + 1;
        }),
    }
}

fn mutate_blocker(
    witness: &SmallModelFreshProductRuntimeCapabilityRecheckWitness,
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
) -> Result<serde_json::Value, FreshProductRuntimeCapabilityRecheckWitnessError> {
    let text = std::fs::read_to_string(path).map_err(|error| {
        FreshProductRuntimeCapabilityRecheckWitnessError::Io(format!(
            "failed to read {}: {error}",
            path.display()
        ))
    })?;
    serde_json::from_str(&text).map_err(|error| {
        FreshProductRuntimeCapabilityRecheckWitnessError::Json(format!(
            "failed to parse {}: {error}",
            path.display()
        ))
    })
}

fn json_bool(
    value: &serde_json::Value,
    key: &str,
) -> Result<bool, FreshProductRuntimeCapabilityRecheckWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_bool)
        .ok_or_else(|| {
            FreshProductRuntimeCapabilityRecheckWitnessError::Json(format!("missing bool `{key}`"))
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
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR
                    .to_string(),
            capability_overall_pass: false,
            capability_route_status: "vault_research_route_with_packetized_mitigation".to_string(),
            capability_next_bottleneck:
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR
                    .to_string(),
            fresh_wrv_pass: true,
            upstream_runtime_bytes_loaded: 1,
            upstream_model_bytes_loaded: 1,
            heavy_long_context_enabled: false,
            kv_direct_live_128k_pass: false,
            seventy_b_route_pass: false,
            metadata_bytes: 1,
        };
        let blockers = capability_blockers(&evidence);
        for required in required_fresh_product_runtime_capability_blockers() {
            assert!(blockers
                .iter()
                .any(|blocker| blocker.blocker_id == required));
        }
    }

    #[test]
    fn axis_contract_has_no_duplicates() {
        let mut seen = std::collections::BTreeSet::new();
        for axis in SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_AXES {
            assert!(seen.insert(*axis), "duplicate axis {axis}");
        }
    }
}
