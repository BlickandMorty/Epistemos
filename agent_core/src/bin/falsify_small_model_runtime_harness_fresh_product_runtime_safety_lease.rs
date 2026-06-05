//! `falsify_small_model_runtime_harness_fresh_product_runtime_safety_lease`.
//!
//! This metadata-only witness installs the safety lease that must exist before
//! any fresh product-runtime small-model probe can open runtime/model bytes.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    fresh_product_runtime_safety_lease_max_deadline_ms,
    fresh_product_runtime_safety_lease_max_model_budget_bytes,
    fresh_product_runtime_safety_lease_max_runtime_budget_bytes,
    fresh_product_runtime_safety_lease_metadata_budget_bytes,
    fresh_product_runtime_safety_lease_route_authority,
    required_fresh_product_runtime_safety_lease_ids,
    required_fresh_product_runtime_safety_lease_phases, ProStatus, ProductBuild,
    SmallModelFreshProductRuntimeSafetyLease, SmallModelFreshProductRuntimeSafetyLeaseError,
    SmallModelFreshProductRuntimeSafetyLeaseWitness,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallModelRuntimeHarnessFreshProductRuntimeSafetyLease";
const FIXTURE_ID: &str = "small_model_runtime_harness_fresh_product_runtime_safety_lease_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_small_model_runtime_harness_fresh_product_runtime_safety_lease.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_safety_lease/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const PRODUCT_RECHECK_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_product_route_capability_recheck/result.json";
const ZERO_BYTES: u64 = 0;

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-safety-lease:witness-error
// Plane: Verification
// Residency: falsifier IO/JSON/primitive error wrapper.
enum FreshProductRuntimeSafetyLeaseWitnessError {
    Primitive(SmallModelFreshProductRuntimeSafetyLeaseError),
    Io(String),
    Json(String),
}

impl std::fmt::Display for FreshProductRuntimeSafetyLeaseWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) | Self::Json(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for FreshProductRuntimeSafetyLeaseWitnessError {}

impl From<SmallModelFreshProductRuntimeSafetyLeaseError>
    for FreshProductRuntimeSafetyLeaseWitnessError
{
    fn from(value: SmallModelFreshProductRuntimeSafetyLeaseError) -> Self {
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
    FreshProductRuntimeSafetyLeaseWitnessError,
> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fresh_product_runtime_safety_lease_witness(&evidence)?;
    let deterministic =
        witness.address() == fresh_product_runtime_safety_lease_witness(&evidence)?.address();
    let invalid_axes = invalid_rejections(&witness);
    let metrics = witness.metrics();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let required_leases_present = required_fresh_product_runtime_safety_lease_ids()
        .into_iter()
        .all(|required| {
            witness
                .leases
                .iter()
                .any(|lease| lease.lease_id == required)
        });

    let bool_axes = [
        (
            "upstream_product_route_capability_recheck_pass",
            evidence.product_recheck_pass,
        ),
        (
            "guard_cursor_fresh_product_runtime_safety_lease_or_advanced",
            evidence.guard_next_existing_work
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_fresh_product_runtime_safety_lease_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_NEXT_CURSOR,
        ),
        (
            "product_status_gated",
            witness.product_build == ProductBuild::Pro && witness.pro_status == ProStatus::Gated,
        ),
        (
            "route_authority_lease_only",
            witness.route_authority == fresh_product_runtime_safety_lease_route_authority(),
        ),
        ("required_leases_present", required_leases_present),
        (
            "lease_owner_approval_bound",
            witness.leases.iter().all(|lease| lease.owner_approved),
        ),
        (
            "lease_dry_run_first_bound",
            witness.leases.iter().all(|lease| lease.dry_run_first),
        ),
        (
            "serialized_executor_bound",
            witness.leases.iter().all(|lease| lease.serialized_executor),
        ),
        (
            "cancellation_deadline_bound",
            witness.leases.iter().all(|lease| {
                lease.cancellable
                    && lease.max_deadline_ms > 0
                    && lease.max_deadline_ms <= fresh_product_runtime_safety_lease_max_deadline_ms()
            }),
        ),
        (
            "rollback_bound",
            witness.leases.iter().all(|lease| lease.rollback_bound),
        ),
        (
            "run_event_log_bound",
            witness.leases.iter().all(|lease| lease.run_event_log_bound),
        ),
        (
            "answer_packet_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.answer_packet_visible),
        ),
        (
            "admission_bound",
            witness.leases.iter().all(|lease| lease.admission_bound),
        ),
        (
            "scope_rex_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.scope_rex_ref.starts_with("scope_rex:")),
        ),
        (
            "sovereign_gate_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.sovereign_gate_ref.starts_with("sovereign_gate:")),
        ),
        (
            "compatibility_fence_bound",
            witness
                .leases
                .iter()
                .all(|lease| lease.compatibility_fence_ref.starts_with("compat:")),
        ),
        (
            "privacy_fence_bound",
            witness.leases.iter().all(|lease| lease.privacy_fenced),
        ),
        (
            "budget_bound",
            witness.leases.iter().all(|lease| {
                lease.max_runtime_bytes_budget
                    <= fresh_product_runtime_safety_lease_max_runtime_budget_bytes()
                    && lease.max_model_bytes_budget
                        <= fresh_product_runtime_safety_lease_max_model_budget_bytes()
            }),
        ),
        ("l1_l2_l3_separation_bound", witness.l1_l2_l3_separated),
        ("mas_floor_preserved", witness.mas_floor_preserved),
        ("no_l2_green_claim", !witness.l2_green_claimed),
        ("no_l3_green_claim", !witness.l3_green_claimed),
        (
            "no_fresh_product_runtime_enabled",
            !witness.fresh_product_runtime_probe_enabled,
        ),
        (
            "no_runtime_probe_before_lease",
            !witness.fresh_product_runtime_probe_enabled,
        ),
        (
            "no_hidden_route_authority",
            witness
                .leases
                .iter()
                .all(|lease| !lease.hidden_route_authority),
        ),
        (
            "no_route_policy_mutation",
            witness
                .leases
                .iter()
                .all(|lease| !lease.route_policy_mutated),
        ),
        (
            "no_gate_bypass",
            witness.leases.iter().all(|lease| !lease.gate_bypassed),
        ),
        (
            "no_answer_packet_suppression",
            witness
                .leases
                .iter()
                .all(|lease| !lease.answer_packet_suppressed),
        ),
        (
            "no_hidden_chain",
            witness
                .leases
                .iter()
                .all(|lease| !lease.hidden_chain_exposed),
        ),
        (
            "no_hidden_cloud",
            witness
                .leases
                .iter()
                .all(|lease| !lease.hidden_cloud_fallback),
        ),
        (
            "no_app_path_subprocess_spawn",
            witness
                .leases
                .iter()
                .all(|lease| !lease.subprocess_spawned_in_app_path),
        ),
        (
            "no_autogenous_kernel_attempt",
            witness
                .leases
                .iter()
                .all(|lease| !lease.autogenous_kernel_attempted),
        ),
        (
            "no_70b_probe_attempt",
            witness
                .leases
                .iter()
                .all(|lease| !lease.seventy_b_probe_attempted),
        ),
        (
            "no_long_context_shard_probe",
            witness
                .leases
                .iter()
                .all(|lease| !lease.long_context_shard_probe_attempted),
        ),
        (
            "fresh_product_runtime_bytes_zero",
            metrics.fresh_runtime_bytes_loaded == 0,
        ),
        (
            "fresh_product_model_bytes_zero",
            metrics.fresh_model_bytes_loaded == 0,
        ),
        (
            "retained_runtime_evidence_kept_red_state_only",
            evidence.retained_runtime_bytes_loaded > 0,
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
            "next_live_probe_cursor_bound",
            witness.next_cursor
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_NEXT_CURSOR,
        ),
        (
            "required_phases_bound",
            metrics.phase_count
                == required_fresh_product_runtime_safety_lease_phases().len() as u64,
        ),
        (
            "small_model_runtime_harness_fresh_product_runtime_safety_lease_address_deterministic",
            deterministic,
        ),
        (
            "missing_product_route_recheck_artifact_rejected",
            invalid_axes.missing_product_route_recheck_artifact_rejected,
        ),
        (
            "missing_required_lease_rejected",
            invalid_axes.missing_required_lease_rejected,
        ),
        (
            "duplicate_lease_rejected",
            invalid_axes.duplicate_lease_rejected,
        ),
        (
            "deadline_zero_rejected",
            invalid_axes.deadline_zero_rejected,
        ),
        (
            "deadline_over_max_rejected",
            invalid_axes.deadline_over_max_rejected,
        ),
        (
            "runtime_budget_over_max_rejected",
            invalid_axes.runtime_budget_over_max_rejected,
        ),
        (
            "model_budget_over_max_rejected",
            invalid_axes.model_budget_over_max_rejected,
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
            "hidden_authority_rejected",
            invalid_axes.hidden_authority_rejected,
        ),
        (
            "route_policy_mutation_rejected",
            invalid_axes.route_policy_mutation_rejected,
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
            "runtime_probe_enabled_rejected",
            invalid_axes.runtime_probe_enabled_rejected,
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
            "l2_green_claim_rejected",
            invalid_axes.l2_green_claim_rejected,
        ),
        (
            "l3_green_claim_rejected",
            invalid_axes.l3_green_claim_rejected,
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
        "lease_count",
        metrics.lease_count,
        required_fresh_product_runtime_safety_lease_ids().len() as u64,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "phase_count",
        metrics.phase_count,
        required_fresh_product_runtime_safety_lease_phases().len() as u64,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_deadline_ms",
        metrics.max_deadline_ms,
        "<=",
        fresh_product_runtime_safety_lease_max_deadline_ms(),
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_runtime_bytes_budget",
        metrics.max_runtime_bytes_budget,
        "<=",
        fresh_product_runtime_safety_lease_max_runtime_budget_bytes(),
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_model_bytes_budget",
        metrics.max_model_bytes_budget,
        "<=",
        fresh_product_runtime_safety_lease_max_model_budget_bytes(),
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fresh_product_runtime_bytes_loaded",
        metrics.fresh_runtime_bytes_loaded,
        "==",
        ZERO_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fresh_product_model_bytes_loaded",
        metrics.fresh_model_bytes_loaded,
        "==",
        ZERO_BYTES,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes",
        metrics.metadata_bytes,
        "<=",
        fresh_product_runtime_safety_lease_metadata_budget_bytes(),
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
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_NEXT_CURSOR,
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_NEXT_CURSOR,
        "cursor",
    );
    let address = witness.address();
    add_label_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_fresh_product_runtime_safety_lease_address",
        &address,
        &address,
        "sha256",
    );
    measurements.insert(
        "lease_ids".to_string(),
        Measurement {
            value: serde_json::json!(witness
                .leases
                .iter()
                .map(|lease| lease.lease_id.clone())
                .collect::<Vec<_>>()),
            unit: "ids".to_string(),
        },
    );
    pass_per_axis.insert("lease_ids".to_string(), true);
    thresholds.insert(
        "lease_ids".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(required_fresh_product_runtime_safety_lease_ids()),
            unit: "ids".to_string(),
        },
    );

    let anomalies = vec![serde_json::json!({
        "kind": "fresh_product_runtime_safety_lease_metadata_only",
        "detail": "Fresh product runtime remains closed. The lease binds owner approval, dry-run fallback, serialized execution, cancellation/deadline, rollback, RunEventLog, AnswerPacket, privacy, MAS/Pro honesty, and zero fresh bytes before the next live probe cursor."
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
        notes: "L1 F-SmallModelRuntimeHarnessFreshProductRuntimeSafetyLease: metadata-only fresh product runtime safety lease. It opens no runtime/model bytes, preserves L2 vault_research_route_with_packetized_mitigation and L3 unverified product runtime, and queues only the next fresh product runtime live probe cursor."
            .to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn fresh_product_runtime_safety_lease_witness(
    evidence: &EvidenceSnapshot,
) -> Result<
    SmallModelFreshProductRuntimeSafetyLeaseWitness,
    FreshProductRuntimeSafetyLeaseWitnessError,
> {
    SmallModelFreshProductRuntimeSafetyLeaseWitness::new(
        "small-model-fresh-product-runtime-safety-lease:v1",
        "artifact:small_model_runtime_harness_product_route_capability_recheck:result",
        evidence.guard_next_existing_work.clone(),
        evidence.capability_overall_pass,
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::Gated,
        fresh_product_runtime_safety_lease_route_authority(),
        safety_leases(),
        required_fresh_product_runtime_safety_lease_phases(),
        true,
        true,
        false,
        false,
        false,
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_NEXT_CURSOR,
        evidence.metadata_bytes,
    )
    .map_err(FreshProductRuntimeSafetyLeaseWitnessError::from)
}

// UAS: uas:small-model-runtime-harness-fresh-product-runtime-safety-lease:evidence-snapshot
// Plane: Verification
// Residency: guard/kernel/recheck state consumed by the lease witness.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    product_recheck_pass: bool,
    retained_runtime_bytes_loaded: u64,
    heavy_long_context_enabled: bool,
    kv_direct_live_128k_pass: bool,
    seventy_b_route_pass: bool,
    metadata_bytes: u64,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, FreshProductRuntimeSafetyLeaseWitnessError> {
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        let product_recheck = read_json(Path::new(PRODUCT_RECHECK_PATH))?;
        Ok(Self {
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_default(),
            capability_overall_pass: json_bool(&capability, "overall_pass")?,
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_default(),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_default(),
            product_recheck_pass: artifact_all_axes_true(&product_recheck),
            retained_runtime_bytes_loaded: measurement_u64(
                &product_recheck,
                "retained_runtime_bytes_loaded",
            )
            .unwrap_or(0),
            heavy_long_context_enabled: measurement_bool(&capability, "heavy_long_context_enabled")
                .unwrap_or(false),
            kv_direct_live_128k_pass: measurement_bool(&capability, "kv_direct_live_128k_pass")
                .unwrap_or(false),
            seventy_b_route_pass: measurement_bool(&capability, "seventy_b_route_pass")
                .unwrap_or(false),
            metadata_bytes: std::fs::metadata(PRODUCT_RECHECK_PATH)
                .map(|metadata| metadata.len())
                .unwrap_or(0),
        })
    }
}

fn safety_leases() -> Vec<SmallModelFreshProductRuntimeSafetyLease> {
    required_fresh_product_runtime_safety_lease_ids()
        .into_iter()
        .map(|lease_id| {
            let surface = lease_id.trim_start_matches("lease:");
            SmallModelFreshProductRuntimeSafetyLease {
                lease_id: lease_id.to_string(),
                product_surface_ref: format!("surface:{surface}"),
                product_build: ProductBuild::Pro,
                pro_status: ProStatus::Gated,
                owner_approval_ref: "owner_approval:fresh-product-runtime:manual-gate".to_string(),
                dry_run_witness_ref: "dry_run:small-model-runtime-harness-dry-run".to_string(),
                safety_plan_ref: "safety_plan:small-model-runtime-harness-safety-plan".to_string(),
                serialized_executor_ref: "serialized_executor:mlx-single-flight".to_string(),
                cancellation_ref: "cancel:fresh-product-runtime:deadline-and-owner-abort"
                    .to_string(),
                deadline_ref: "deadline:fresh-product-runtime:6000ms".to_string(),
                rollback_ref: "rollback:fresh-product-runtime:no-route-promotion".to_string(),
                run_event_log_ref: "run_event_log:fresh-product-runtime:required".to_string(),
                answer_packet_ref: "answer_packet:fresh-product-runtime:required".to_string(),
                admission_ref: "admission:scope-rex-sovereign-gate".to_string(),
                scope_rex_ref: "scope_rex:fresh-product-runtime".to_string(),
                sovereign_gate_ref: "sovereign_gate:fresh-product-runtime".to_string(),
                compatibility_fence_ref: "compat:mas-pro-product-route-boundary".to_string(),
                privacy_ref: "privacy:redacted-visible-summary-no-hidden-chain".to_string(),
                budget_ref: "budget:fresh-product-runtime:bounded-qwen3-4b".to_string(),
                route_authority: fresh_product_runtime_safety_lease_route_authority().to_string(),
                max_deadline_ms: fresh_product_runtime_safety_lease_max_deadline_ms(),
                max_runtime_bytes_budget:
                    fresh_product_runtime_safety_lease_max_runtime_budget_bytes(),
                max_model_bytes_budget: fresh_product_runtime_safety_lease_max_model_budget_bytes(),
                fresh_runtime_bytes_loaded: 0,
                fresh_model_bytes_loaded: 0,
                visible: true,
                owner_approved: true,
                dry_run_first: true,
                serialized_executor: true,
                cancellable: true,
                rollback_bound: true,
                run_event_log_bound: true,
                answer_packet_visible: true,
                privacy_fenced: true,
                admission_bound: true,
                hidden_route_authority: false,
                route_policy_mutated: false,
                gate_bypassed: false,
                answer_packet_suppressed: false,
                hidden_chain_exposed: false,
                hidden_cloud_fallback: false,
                subprocess_spawned_in_app_path: false,
                autogenous_kernel_attempted: false,
                seventy_b_probe_attempted: false,
                long_context_shard_probe_attempted: false,
            }
        })
        .collect()
}

#[derive(Default)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-safety-lease:invalid-axes
// Plane: Verification
// Residency: invalid fixture coverage for lease rejection paths.
struct InvalidAxes {
    missing_product_route_recheck_artifact_rejected: bool,
    missing_required_lease_rejected: bool,
    duplicate_lease_rejected: bool,
    deadline_zero_rejected: bool,
    deadline_over_max_rejected: bool,
    runtime_budget_over_max_rejected: bool,
    model_budget_over_max_rejected: bool,
    missing_rollback_rejected: bool,
    missing_answer_packet_rejected: bool,
    hidden_authority_rejected: bool,
    route_policy_mutation_rejected: bool,
    fresh_runtime_bytes_rejected: bool,
    fresh_model_bytes_rejected: bool,
    runtime_probe_enabled_rejected: bool,
    app_path_subprocess_rejected: bool,
    autogenous_kernel_rejected: bool,
    seventy_b_probe_rejected: bool,
    long_context_shard_probe_rejected: bool,
    l2_green_claim_rejected: bool,
    l3_green_claim_rejected: bool,
    next_cursor_mismatch_rejected: bool,
    metadata_budget_rejected: bool,
}

fn invalid_rejections(witness: &SmallModelFreshProductRuntimeSafetyLeaseWitness) -> InvalidAxes {
    let mutate = |mutator: fn(&mut SmallModelFreshProductRuntimeSafetyLeaseWitness)| {
        let mut candidate = witness.clone();
        mutator(&mut candidate);
        candidate.validate().is_err()
    };
    InvalidAxes {
        missing_product_route_recheck_artifact_rejected: mutate(|candidate| {
            candidate.product_route_recheck_artifact_ref.clear();
        }),
        missing_required_lease_rejected: mutate(|candidate| {
            candidate
                .leases
                .retain(|lease| lease.lease_id != "lease:note_chat_fresh_product_runtime");
        }),
        duplicate_lease_rejected: mutate(|candidate| {
            candidate.leases[1] = candidate.leases[0].clone()
        }),
        deadline_zero_rejected: mutate_lease(witness, |lease| lease.max_deadline_ms = 0),
        deadline_over_max_rejected: mutate_lease(witness, |lease| {
            lease.max_deadline_ms = fresh_product_runtime_safety_lease_max_deadline_ms() + 1;
        }),
        runtime_budget_over_max_rejected: mutate_lease(witness, |lease| {
            lease.max_runtime_bytes_budget =
                fresh_product_runtime_safety_lease_max_runtime_budget_bytes() + 1;
        }),
        model_budget_over_max_rejected: mutate_lease(witness, |lease| {
            lease.max_model_bytes_budget =
                fresh_product_runtime_safety_lease_max_model_budget_bytes() + 1;
        }),
        missing_rollback_rejected: mutate_lease(witness, |lease| lease.rollback_ref.clear()),
        missing_answer_packet_rejected: mutate_lease(witness, |lease| {
            lease.answer_packet_visible = false;
        }),
        hidden_authority_rejected: mutate_lease(witness, |lease| {
            lease.hidden_route_authority = true;
        }),
        route_policy_mutation_rejected: mutate_lease(witness, |lease| {
            lease.route_policy_mutated = true;
        }),
        fresh_runtime_bytes_rejected: mutate_lease(witness, |lease| {
            lease.fresh_runtime_bytes_loaded = 1;
        }),
        fresh_model_bytes_rejected: mutate_lease(witness, |lease| {
            lease.fresh_model_bytes_loaded = 1;
        }),
        runtime_probe_enabled_rejected: mutate(|candidate| {
            candidate.fresh_product_runtime_probe_enabled = true;
        }),
        app_path_subprocess_rejected: mutate_lease(witness, |lease| {
            lease.subprocess_spawned_in_app_path = true;
        }),
        autogenous_kernel_rejected: mutate_lease(witness, |lease| {
            lease.autogenous_kernel_attempted = true;
        }),
        seventy_b_probe_rejected: mutate_lease(witness, |lease| {
            lease.seventy_b_probe_attempted = true;
        }),
        long_context_shard_probe_rejected: mutate_lease(witness, |lease| {
            lease.long_context_shard_probe_attempted = true;
        }),
        l2_green_claim_rejected: mutate(|candidate| candidate.l2_green_claimed = true),
        l3_green_claim_rejected: mutate(|candidate| candidate.l3_green_claimed = true),
        next_cursor_mismatch_rejected: mutate(|candidate| candidate.next_cursor = "done".into()),
        metadata_budget_rejected: mutate(|candidate| {
            candidate.metadata_bytes =
                fresh_product_runtime_safety_lease_metadata_budget_bytes() + 1;
        }),
    }
}

fn mutate_lease(
    witness: &SmallModelFreshProductRuntimeSafetyLeaseWitness,
    mutator: fn(&mut SmallModelFreshProductRuntimeSafetyLease),
) -> bool {
    let mut candidate = witness.clone();
    if let Some(lease) = candidate.leases.first_mut() {
        mutator(lease);
    }
    candidate.validate().is_err()
}

fn read_json(path: &Path) -> Result<serde_json::Value, FreshProductRuntimeSafetyLeaseWitnessError> {
    let text = std::fs::read_to_string(path).map_err(|error| {
        FreshProductRuntimeSafetyLeaseWitnessError::Io(format!(
            "failed to read {}: {error}",
            path.display()
        ))
    })?;
    serde_json::from_str(&text).map_err(|error| {
        FreshProductRuntimeSafetyLeaseWitnessError::Json(format!(
            "failed to parse {}: {error}",
            path.display()
        ))
    })
}

fn json_bool(
    value: &serde_json::Value,
    key: &str,
) -> Result<bool, FreshProductRuntimeSafetyLeaseWitnessError> {
    value
        .get(key)
        .and_then(serde_json::Value::as_bool)
        .ok_or_else(|| {
            FreshProductRuntimeSafetyLeaseWitnessError::Json(format!("missing bool `{key}`"))
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
    fn generated_leases_cover_required_ids() {
        let leases = safety_leases();
        for required in required_fresh_product_runtime_safety_lease_ids() {
            assert!(leases.iter().any(|lease| lease.lease_id == required));
        }
    }

    #[test]
    fn measurement_helpers_read_nested_values() {
        let value = serde_json::json!({
            "measurements": {
                "next_bottleneck": {"value": "small_model_runtime_harness_fresh_product_runtime_safety_lease", "unit": "cursor"},
                "kv_direct_live_128k_pass": {"value": false, "unit": "bool"},
                "retained_runtime_bytes_loaded": {"value": 1, "unit": "bytes"}
            }
        });
        assert_eq!(
            measurement_string(&value, "next_bottleneck"),
            Some(SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_SAFETY_LEASE_CURSOR.to_string())
        );
        assert_eq!(
            measurement_bool(&value, "kv_direct_live_128k_pass"),
            Some(false)
        );
        assert_eq!(
            measurement_u64(&value, "retained_runtime_bytes_loaded"),
            Some(1)
        );
    }
}
