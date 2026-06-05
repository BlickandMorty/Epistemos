//! `falsify_small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
//!
//! This L1/L3 witness consumes zero-fail release-audit proof plus a fixed
//! automated-check evidence ledger. It proves the command set passed without
//! authorizing release readiness, product capability promotion, or any L2 green
//! claim.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[cfg(test)]
use agent_core::falsifier_artifacts::axes::SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    sha256_hex, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier,
    Measurement,
};
use agent_core::uas::{
    fresh_product_runtime_l3_release_audit_automated_checks_metadata_budget_bytes,
    fresh_product_runtime_l3_release_audit_automated_checks_skill_path,
    required_fresh_product_runtime_l3_release_audit_automated_check_blockers,
    required_fresh_product_runtime_l3_release_audit_automated_check_phases,
    required_fresh_product_runtime_l3_release_audit_automated_checks, ProStatus, ProductBuild,
    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckRecord,
    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus,
    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError,
    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksWitness,
    SmallModelProductRouteCapabilityBlocker,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_CURSOR,
    SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str =
    "F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditAutomatedChecksProbe";
const FIXTURE_ID: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/result.json";
const CHECK_LEDGER: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/checks.tsv";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const ZERO_FAIL_PATH: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_zero_fail_probe/result.json";
const EXPECTED_CHECK_COUNT: u64 = 5;
const EXPECTED_BLOCKER_COUNT: u64 = 12;
const ZERO: u64 = 0;

#[derive(Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-automated-checks-probe:witness-error
// Plane: Verification
// Residency: falsifier IO/JSON/primitive error wrapper.
enum FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError {
    Primitive(SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError),
    Io(String),
    Json(String),
    Evidence(String),
}

impl std::fmt::Display for FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) | Self::Json(error) | Self::Evidence(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError {}

impl From<SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError>
    for FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError
{
    fn from(value: SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError) -> Self {
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
    FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError,
> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = automated_checks_witness(&evidence)?;
    let deterministic = witness.address() == automated_checks_witness(&evidence)?.address();
    let invalid_axes = invalid_rejections(&witness);
    let metrics = witness.metrics();

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let required_checks_present =
        required_fresh_product_runtime_l3_release_audit_automated_checks()
            .into_iter()
            .all(|required| {
                witness
                    .checks
                    .iter()
                    .any(|check| check.check_id == required)
            });
    let required_blockers_present =
        required_fresh_product_runtime_l3_release_audit_automated_check_blockers()
            .into_iter()
            .all(|required| {
                witness
                    .blockers
                    .iter()
                    .any(|blocker| blocker.blocker_id == required)
            });

    let bool_axes = [
        ("upstream_l3_release_audit_zero_fail_probe_pass", evidence.zero_fail_pass),
        (
            "guard_cursor_l3_release_audit_automated_checks_or_advanced",
            evidence.guard_next_existing_work
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_CURSOR
                || evidence.guard_next_existing_work
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_l3_release_audit_automated_checks_or_advanced",
            evidence.capability_next_bottleneck
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_CURSOR
                || evidence.capability_next_bottleneck
                    == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_NEXT_CURSOR,
        ),
        (
            "product_status_gated",
            witness.product_build == ProductBuild::Pro && witness.pro_status == ProStatus::Gated,
        ),
        (
            "route_authority_automated_checks_only",
            witness.route_authority
                == "fresh_product_runtime_l3_release_audit_automated_checks_no_ship_authority",
        ),
        ("release_audit_skill_present", evidence.release_audit_skill_exists),
        ("release_audit_skill_mentions_automated_checks", evidence.release_skill_mentions_checks),
        ("all_required_automated_checks_present", required_checks_present),
        ("all_required_automated_checks_passed", metrics.failed_check_count == 0),
        ("xcodebuild_build_passed", passed_check(&witness, "xcodebuild_build")),
        ("xcodebuild_test_passed", passed_check(&witness, "xcodebuild_test")),
        (
            "graph_engine_cargo_test_passed",
            passed_check(&witness, "graph_engine_cargo_test"),
        ),
        (
            "omega_mcp_cargo_test_passed",
            passed_check(&witness, "omega_mcp_cargo_test"),
        ),
        (
            "omega_ax_cargo_test_passed",
            passed_check(&witness, "omega_ax_cargo_test"),
        ),
        ("all_check_logs_bound", witness.checks.iter().all(|check| check.log_bytes > 0)),
        (
            "command_log_digests_present",
            witness
                .checks
                .iter()
                .all(|check| is_sha256_digest(&check.log_sha256)),
        ),
        ("required_blockers_present", required_blockers_present),
        (
            "residual_blockers_visible",
            witness.blockers.iter().all(|blocker| blocker.visible),
        ),
        ("automated_checks_completed", witness.automated_checks_completed),
        ("zero_fail_pass_count_zero", witness.zero_fail_pass_count == 0),
        ("ship_call_not_authorized", !witness.ship_call_authorized),
        (
            "product_capability_not_promoted",
            !witness.product_capability_promoted,
        ),
        (
            "log_runtime_evidence_not_claimed",
            !witness.log_runtime_evidence_present,
        ),
        (
            "manual_runtime_evidence_not_claimed",
            !witness.manual_runtime_evidence_present,
        ),
        (
            "distribution_compliance_not_claimed",
            !witness.distribution_compliance_evidence_present,
        ),
        ("l1_l2_l3_separation_bound", witness.l1_l2_l3_separated),
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
            "model_runtime_bytes_zero",
            witness.model_runtime_bytes_loaded == 0,
        ),
        (
            "next_l3_release_audit_log_evidence_bound",
            witness.next_cursor
                == SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_NEXT_CURSOR,
        ),
        (
            "required_phases_bound",
            metrics.phase_count
                == required_fresh_product_runtime_l3_release_audit_automated_check_phases()
                    .len() as u64,
        ),
        (
            "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe_address_deterministic",
            deterministic,
        ),
        (
            "missing_upstream_zero_fail_rejected",
            invalid_axes.missing_upstream_zero_fail_rejected,
        ),
        (
            "missing_required_check_rejected",
            invalid_axes.missing_required_check_rejected,
        ),
        ("duplicate_check_rejected", invalid_axes.duplicate_check_rejected),
        (
            "failed_check_rejected",
            invalid_axes.failed_status_zero_exit_rejected,
        ),
        ("missing_log_rejected", invalid_axes.missing_log_rejected),
        (
            "bad_log_digest_rejected",
            invalid_axes.bad_log_digest_rejected,
        ),
        (
            "missing_required_blocker_rejected",
            invalid_axes.missing_required_blocker_rejected,
        ),
        (
            "duplicate_blocker_rejected",
            invalid_axes.duplicate_blocker_rejected,
        ),
        ("blocker_green_rejected", invalid_axes.blocker_green_rejected),
        ("hidden_authority_rejected", invalid_axes.hidden_authority_rejected),
        (
            "route_policy_mutation_rejected",
            invalid_axes.route_policy_mutation_rejected,
        ),
        (
            "automated_checks_incomplete_rejected",
            invalid_axes.automated_checks_incomplete_rejected,
        ),
        (
            "zero_fail_pass_count_overclaim_rejected",
            invalid_axes.zero_fail_pass_count_overclaim_rejected,
        ),
        (
            "log_evidence_claim_rejected",
            invalid_axes.log_evidence_claim_rejected,
        ),
        (
            "manual_runtime_evidence_claim_rejected",
            invalid_axes.manual_runtime_evidence_claim_rejected,
        ),
        (
            "distribution_compliance_claim_rejected",
            invalid_axes.distribution_compliance_claim_rejected,
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
            "model_runtime_bytes_rejected",
            invalid_axes.model_runtime_bytes_rejected,
        ),
        (
            "mas_live_agent_overclaim_rejected",
            invalid_axes.mas_live_agent_overclaim_rejected,
        ),
        ("l2_green_claim_rejected", invalid_axes.l2_green_claim_rejected),
        ("l3_green_claim_rejected", invalid_axes.l3_green_claim_rejected),
        ("autogenous_kernel_rejected", invalid_axes.autogenous_kernel_rejected),
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
        ("metadata_budget_rejected", invalid_axes.metadata_budget_rejected),
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
        "check_count",
        metrics.check_count,
        EXPECTED_CHECK_COUNT,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "failed_check_count",
        metrics.failed_check_count,
        0,
        "count",
    );
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
        required_fresh_product_runtime_l3_release_audit_automated_check_phases().len() as u64,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "zero_fail_pass_count",
        metrics.zero_fail_pass_count,
        0,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "check_log_bytes",
        metrics.log_bytes,
        ">",
        ZERO,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_runtime_bytes_loaded",
        metrics.model_runtime_bytes_loaded,
        "==",
        ZERO,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes",
        witness.metadata_bytes,
        "<=",
        fresh_product_runtime_l3_release_audit_automated_checks_metadata_budget_bytes(),
        "bytes",
    );
    insert_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "capability_route_status",
        &evidence.capability_route_status,
        "vault_research_route_with_packetized_mitigation",
        "status",
    );
    insert_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_NEXT_CURSOR,
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_NEXT_CURSOR,
        "cursor",
    );
    let address = witness.address();
    insert_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe_address",
        &address,
        &address,
        "sha256",
    );
    insert_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "release_audit_skill_ref",
        fresh_product_runtime_l3_release_audit_automated_checks_skill_path(),
        fresh_product_runtime_l3_release_audit_automated_checks_skill_path(),
        "path",
    );
    measurements.insert(
        "automated_check_ids".to_string(),
        Measurement {
            value: serde_json::json!(witness
                .checks
                .iter()
                .map(|check| check.check_id.clone())
                .collect::<Vec<_>>()),
            unit: "ids".to_string(),
        },
    );
    pass_per_axis.insert("automated_check_ids".to_string(), true);
    thresholds.insert(
        "automated_check_ids".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(
                required_fresh_product_runtime_l3_release_audit_automated_checks()
            ),
            unit: "ids".to_string(),
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
                required_fresh_product_runtime_l3_release_audit_automated_check_blockers()
            ),
            unit: "ids".to_string(),
        },
    );

    let (anomaly_kind, anomaly_detail, notes) = if metrics.failed_check_count == 0 {
        (
            "small_model_fresh_product_runtime_l3_release_audit_automated_checks_passed_not_ready",
            "Required automated build/test commands passed and logs are bound, but this advances L1/L3 check evidence only. Runtime log evidence, manual runtime review, distribution/compliance review, and three uninterrupted zero-fail passes remain blockers; no ship call or L2 product capability promotion is authorized.",
            "L1/L3 F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditAutomatedChecksProbe: binds required xcodebuild/cargo automated-check logs, preserves red L2/L3 release blockers, opens zero model/runtime bytes, and advances only to log-evidence release-audit work.",
        )
    } else {
        (
            "small_model_fresh_product_runtime_l3_release_audit_automated_checks_failed",
            "Required automated build/test command logs are bound, but at least one automated check failed. The artifact is retained as red evidence; the architecture cursor must not advance and no ship call or product capability promotion is authorized.",
            "L1/L3 F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditAutomatedChecksProbe: records a red automated-check ledger with bound logs, preserves red L2/L3 release blockers, opens zero model/runtime bytes, and keeps the guard cursor on automated-check repair.",
        )
    };
    let anomalies = vec![serde_json::json!({
        "kind": anomaly_kind,
        "detail": anomaly_detail
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
        notes: notes.to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn automated_checks_witness(
    evidence: &EvidenceSnapshot,
) -> Result<
    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksWitness,
    FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError,
> {
    let witness_id = if all_checks_passed(&evidence.checks) {
        "small-model-fresh-product-runtime-l3-release-audit-automated-checks:passed-not-ready"
    } else {
        "small-model-fresh-product-runtime-l3-release-audit-automated-checks:completed-red-ledger"
    };
    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksWitness::new(
        witness_id,
        "artifact:small_model_runtime_harness_fresh_product_runtime_l3_release_audit_zero_fail_probe:result",
        fresh_product_runtime_l3_release_audit_automated_checks_skill_path(),
        evidence.guard_next_existing_work.clone(),
        evidence.capability_overall_pass,
        evidence.capability_route_status.clone(),
        evidence.capability_next_bottleneck.clone(),
        ProductBuild::Pro,
        ProStatus::Gated,
        "fresh_product_runtime_l3_release_audit_automated_checks_no_ship_authority",
        evidence.checks.clone(),
        release_audit_automated_check_blockers(evidence),
        required_fresh_product_runtime_l3_release_audit_automated_check_phases().to_vec(),
        true,
        0,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        0,
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_NEXT_CURSOR,
        evidence.metadata_bytes,
    )
    .map_err(FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError::from)
}

// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-automated-checks-probe:evidence-snapshot
// Plane: Verification
// Residency: guard/kernel/zero_fail/check-log state consumed by automated checks.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    zero_fail_pass: bool,
    heavy_long_context_enabled: bool,
    kv_direct_live_128k_pass: bool,
    seventy_b_route_pass: bool,
    release_audit_skill_exists: bool,
    release_skill_mentions_checks: bool,
    checks: Vec<SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckRecord>,
    metadata_bytes: u64,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError> {
        let guard = read_json(Path::new(GUARD_PATH))?;
        let capability = read_json(Path::new(CAPABILITY_PATH))?;
        let zero_fail = read_json(Path::new(ZERO_FAIL_PATH))?;
        let skill_path =
            Path::new(fresh_product_runtime_l3_release_audit_automated_checks_skill_path());
        let release_audit_skill_text = std::fs::read_to_string(skill_path).unwrap_or_default();
        let checks = read_check_ledger(Path::new(CHECK_LEDGER))?;
        let zero_fail_metadata_bytes = std::fs::metadata(ZERO_FAIL_PATH)
            .map(|metadata| metadata.len())
            .unwrap_or(0);
        let ledger_metadata_bytes = std::fs::metadata(CHECK_LEDGER)
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
            zero_fail_pass: artifact_all_axes_true(&zero_fail),
            heavy_long_context_enabled: measurement_bool(&capability, "heavy_long_context_enabled")
                .unwrap_or(false),
            kv_direct_live_128k_pass: measurement_bool(&capability, "kv_direct_live_128k_pass")
                .unwrap_or(false),
            seventy_b_route_pass: measurement_bool(&capability, "seventy_b_route_pass")
                .unwrap_or(false),
            release_audit_skill_exists: skill_path.exists(),
            release_skill_mentions_checks: release_audit_skill_text
                .contains("xcodebuild -project Epistemos.xcodeproj")
                && release_audit_skill_text.contains("graph-engine && cargo test")
                && release_audit_skill_text.contains("omega-mcp && cargo test")
                && release_audit_skill_text.contains("omega-ax && cargo test"),
            checks,
            metadata_bytes: zero_fail_metadata_bytes
                .saturating_add(ledger_metadata_bytes),
        })
    }
}

fn read_check_ledger(
    path: &Path,
) -> Result<
    Vec<SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckRecord>,
    FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError,
> {
    let text = std::fs::read_to_string(path).map_err(|error| {
        FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError::Io(format!(
            "{}: {error}",
            path.display()
        ))
    })?;
    let mut records = Vec::new();
    for (idx, line) in text.lines().enumerate() {
        if idx == 0 && line == "id\tstatus\texit_code\tduration_seconds\tlog_path" {
            continue;
        }
        if line.trim().is_empty() {
            continue;
        }
        let parts = line.split('\t').collect::<Vec<_>>();
        if parts.len() != 5 {
            return Err(
                FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError::Evidence(format!(
                    "malformed check ledger line {}",
                    idx + 1
                )),
            );
        }
        let status = match parts[1] {
            "pass" => SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus::Pass,
            "fail" => SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus::Fail,
            other => {
                return Err(
                    FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError::Evidence(
                        format!("unknown check status `{other}` on line {}", idx + 1),
                    ),
                )
            }
        };
        let exit_code = parts[2].parse::<i32>().map_err(|error| {
            FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError::Evidence(format!(
                "invalid exit code on line {}: {error}",
                idx + 1
            ))
        })?;
        let duration_seconds = parts[3].parse::<u64>().map_err(|error| {
            FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError::Evidence(format!(
                "invalid duration on line {}: {error}",
                idx + 1
            ))
        })?;
        let log_path = Path::new(parts[4]);
        let log_bytes = std::fs::metadata(log_path)
            .map(|metadata| metadata.len())
            .unwrap_or(0);
        let log_sha256 = std::fs::read(log_path)
            .map(|bytes| sha256_hex(&bytes))
            .unwrap_or_default();
        records.push(
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckRecord {
                check_id: parts[0].to_string(),
                status,
                exit_code,
                duration_seconds,
                log_ref: format!("log:{}", parts[4]),
                log_sha256,
                log_bytes,
            },
        );
    }
    Ok(records)
}

fn release_audit_automated_check_blockers(
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
            "blocker:release_audit_zero_fail_three_passes_missing",
            "verification",
            "evidence:release_audit:automated_checks_one_stage_only_zero_fail_passes_zero",
            "safety:three_uninterrupted_zero_fail_passes_required_before_ready",
        ),
        (
            "blocker:release_audit_log_evidence_missing",
            "verification",
            "evidence:release_audit:runtime_logs_required_missing",
            "safety:logs_must_be_correlated_before_ui_verified_claim",
        ),
        (
            "blocker:release_audit_manual_runtime_missing",
            "verification",
            "evidence:release_audit:manual_runtime_required_missing",
            "safety:manual_runtime_required_before_l3_ship_call",
        ),
        (
            "blocker:release_audit_distribution_compliance_missing",
            "state",
            "evidence:release_audit:distribution_compliance_required_missing",
            "safety:mas_direct_distribution_boundaries_must_be_checked",
        ),
        (
            "blocker:release_audit_three_passes_missing",
            "verification",
            "evidence:release_audit:three_uninterrupted_passes_required_zero_observed",
            "safety:three_uninterrupted_zero_fail_passes_required_before_ready",
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
            "evidence:ship_call:not_authorized_by_release_automated_checks",
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
            answer_packet_ref: "answer_packet:fresh_runtime_l3_release_audit_automated_checks:red"
                .to_string(),
            rollback_ref: "rollback:no_release_readiness_from_automated_checks".to_string(),
            budget_ref: "budget:zero_model_runtime_bytes_for_automated_checks".to_string(),
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
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-automated-checks-probe:invalid-axes
// Plane: Verification
// Residency: invalid fixture coverage for automated-check rejection paths.
struct InvalidAxes {
    missing_upstream_zero_fail_rejected: bool,
    missing_required_check_rejected: bool,
    duplicate_check_rejected: bool,
    failed_status_zero_exit_rejected: bool,
    missing_log_rejected: bool,
    bad_log_digest_rejected: bool,
    missing_required_blocker_rejected: bool,
    duplicate_blocker_rejected: bool,
    blocker_green_rejected: bool,
    hidden_authority_rejected: bool,
    route_policy_mutation_rejected: bool,
    automated_checks_incomplete_rejected: bool,
    zero_fail_pass_count_overclaim_rejected: bool,
    log_evidence_claim_rejected: bool,
    manual_runtime_evidence_claim_rejected: bool,
    distribution_compliance_claim_rejected: bool,
    ship_call_authorized_rejected: bool,
    product_capability_promotion_rejected: bool,
    model_runtime_bytes_rejected: bool,
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
    witness: &SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksWitness,
) -> InvalidAxes {
    let mutate =
        |mutator: fn(&mut SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksWitness)| {
            let mut candidate = witness.clone();
            mutator(&mut candidate);
            candidate.validate().is_err()
        };
    InvalidAxes {
        missing_upstream_zero_fail_rejected: mutate(|candidate| {
            candidate.upstream_zero_fail_artifact_ref.clear();
        }),
        missing_required_check_rejected: mutate(|candidate| {
            candidate
                .checks
                .retain(|check| check.check_id != "xcodebuild_test");
        }),
        duplicate_check_rejected: mutate(|candidate| {
            candidate.checks[1] = candidate.checks[0].clone();
        }),
        failed_status_zero_exit_rejected: mutate(|candidate| {
            candidate.checks[0].status =
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus::Fail;
        }),
        missing_log_rejected: mutate(|candidate| {
            candidate.checks[0].log_bytes = 0;
        }),
        bad_log_digest_rejected: mutate(|candidate| {
            candidate.checks[0].log_sha256 = "not_sha256".to_string();
        }),
        missing_required_blocker_rejected: mutate(|candidate| {
            candidate.blockers.retain(|blocker| {
                blocker.blocker_id != "blocker:release_audit_log_evidence_missing"
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
        automated_checks_incomplete_rejected: mutate(|candidate| {
            candidate.automated_checks_completed = false;
        }),
        zero_fail_pass_count_overclaim_rejected: mutate(|candidate| {
            candidate.zero_fail_pass_count = 1;
        }),
        log_evidence_claim_rejected: mutate(|candidate| {
            candidate.log_runtime_evidence_present = true;
        }),
        manual_runtime_evidence_claim_rejected: mutate(|candidate| {
            candidate.manual_runtime_evidence_present = true;
        }),
        distribution_compliance_claim_rejected: mutate(|candidate| {
            candidate.distribution_compliance_evidence_present = true;
        }),
        ship_call_authorized_rejected: mutate(|candidate| {
            candidate.ship_call_authorized = true;
        }),
        product_capability_promotion_rejected: mutate(|candidate| {
            candidate.product_capability_promoted = true;
        }),
        model_runtime_bytes_rejected: mutate(|candidate| {
            candidate.model_runtime_bytes_loaded = 1;
        }),
        mas_live_agent_overclaim_rejected: mutate(|candidate| {
            candidate.mas_live_agent_overclaim_attempted = true;
        }),
        l2_green_claim_rejected: mutate(|candidate| {
            candidate.l2_green_claimed = true;
        }),
        l3_green_claim_rejected: mutate(|candidate| {
            candidate.l3_green_claimed = true;
        }),
        autogenous_kernel_rejected: mutate(|candidate| {
            candidate.autogenous_kernel_attempted = true;
        }),
        seventy_b_product_claim_rejected: mutate(|candidate| {
            candidate.seventy_b_product_claimed = true;
        }),
        long_context_shard_claim_rejected: mutate(|candidate| {
            candidate.long_context_shard_product_claimed = true;
        }),
        next_cursor_mismatch_rejected: mutate(|candidate| {
            candidate.next_cursor = "release_ready".to_string();
        }),
        metadata_budget_rejected: mutate(|candidate| {
            candidate.metadata_bytes =
                fresh_product_runtime_l3_release_audit_automated_checks_metadata_budget_bytes() + 1;
        }),
    }
}

fn mutate_blocker(
    witness: &SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksWitness,
    mutator: fn(&mut SmallModelProductRouteCapabilityBlocker),
) -> bool {
    let mut candidate = witness.clone();
    if let Some(blocker) = candidate.blockers.first_mut() {
        mutator(blocker);
    }
    candidate.validate().is_err()
}

fn passed_check(
    witness: &SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksWitness,
    check_id: &str,
) -> bool {
    witness.checks.iter().any(|check| {
        check.check_id == check_id
            && check.status == SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus::Pass
            && check.exit_code == 0
            && check.log_bytes > 0
    })
}

fn insert_string_measurement(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: &str,
    expected: &str,
    unit: &str,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value == expected);
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(expected),
            unit: unit.to_string(),
        },
    );
}

fn read_json(
    path: &Path,
) -> Result<serde_json::Value, FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError> {
    let text = std::fs::read_to_string(path).map_err(|error| {
        FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError::Io(format!(
            "{}: {error}",
            path.display()
        ))
    })?;
    serde_json::from_str(&text).map_err(|error| {
        FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError::Json(format!(
            "{}: {error}",
            path.display()
        ))
    })
}

fn artifact_all_axes_true(value: &serde_json::Value) -> bool {
    value
        .get("pass_per_axis")
        .and_then(|axes| axes.as_object())
        .is_some_and(|axes| !axes.is_empty() && axes.values().all(|axis| axis == true))
}

fn json_bool(
    value: &serde_json::Value,
    key: &str,
) -> Result<bool, FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError> {
    value
        .get(key)
        .and_then(|value| value.as_bool())
        .ok_or_else(|| {
            FreshProductRuntimeL3ReleaseAuditAutomatedChecksWitnessError::Json(format!(
                "missing bool `{key}`"
            ))
        })
}

fn all_checks_passed(
    checks: &[SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckRecord],
) -> bool {
    checks.iter().all(|check| {
        check.status == SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus::Pass
            && check.exit_code == 0
    })
}

fn is_sha256_digest(value: &str) -> bool {
    let Some(hex) = value.strip_prefix("sha256:") else {
        return false;
    };
    hex.len() == 64
        && hex
            .chars()
            .all(|ch| ch.is_ascii_hexdigit() && !ch.is_ascii_uppercase())
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(|value| value.as_str())
        .map(str::to_string)
}

fn measurement_bool(value: &serde_json::Value, key: &str) -> Option<bool> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(|value| value.as_bool())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn axes_contract_lists_every_emitted_axis() {
        let emitted = [
            "upstream_l3_release_audit_zero_fail_probe_pass",
            "guard_cursor_l3_release_audit_automated_checks_or_advanced",
            "capability_kernel_red",
            "capability_route_status_vault_research",
            "capability_next_bottleneck_l3_release_audit_automated_checks_or_advanced",
            "product_status_gated",
            "route_authority_automated_checks_only",
            "release_audit_skill_present",
            "release_audit_skill_mentions_automated_checks",
            "all_required_automated_checks_present",
            "all_required_automated_checks_passed",
            "xcodebuild_build_passed",
            "xcodebuild_test_passed",
            "graph_engine_cargo_test_passed",
            "omega_mcp_cargo_test_passed",
            "omega_ax_cargo_test_passed",
            "all_check_logs_bound",
            "command_log_digests_present",
            "required_blockers_present",
            "residual_blockers_visible",
            "automated_checks_completed",
            "zero_fail_pass_count_zero",
            "ship_call_not_authorized",
            "product_capability_not_promoted",
            "log_runtime_evidence_not_claimed",
            "manual_runtime_evidence_not_claimed",
            "distribution_compliance_not_claimed",
            "l1_l2_l3_separation_bound",
            "no_hidden_route_authority",
            "no_route_policy_mutation",
            "no_mas_live_agent_overclaim",
            "no_l2_green_claim",
            "no_l3_green_claim",
            "heavy_routes_deferred",
            "kv_direct_128k_still_red",
            "live_70b_still_red",
            "autogenous_kernel_still_research",
            "model_runtime_bytes_zero",
            "next_l3_release_audit_log_evidence_bound",
            "required_phases_bound",
            "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe_address_deterministic",
            "missing_upstream_zero_fail_rejected",
            "missing_required_check_rejected",
            "duplicate_check_rejected",
            "failed_check_rejected",
            "missing_log_rejected",
            "bad_log_digest_rejected",
            "missing_required_blocker_rejected",
            "duplicate_blocker_rejected",
            "blocker_green_rejected",
            "hidden_authority_rejected",
            "route_policy_mutation_rejected",
            "automated_checks_incomplete_rejected",
            "zero_fail_pass_count_overclaim_rejected",
            "log_evidence_claim_rejected",
            "manual_runtime_evidence_claim_rejected",
            "distribution_compliance_claim_rejected",
            "ship_call_authorized_rejected",
            "product_capability_promotion_rejected",
            "model_runtime_bytes_rejected",
            "mas_live_agent_overclaim_rejected",
            "l2_green_claim_rejected",
            "l3_green_claim_rejected",
            "autogenous_kernel_rejected",
            "seventy_b_product_claim_rejected",
            "long_context_shard_claim_rejected",
            "next_cursor_mismatch_rejected",
            "metadata_budget_rejected",
            "check_count",
            "failed_check_count",
            "blocker_count",
            "phase_count",
            "zero_fail_pass_count",
            "check_log_bytes",
            "model_runtime_bytes_loaded",
            "metadata_bytes",
            "capability_route_status",
            "next_cursor",
            "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe_address",
            "release_audit_skill_ref",
            "automated_check_ids",
            "blocker_ids",
        ];
        for axis in emitted {
            assert!(
                SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_AXES
                    .contains(&axis),
                "missing axis {axis}"
            );
        }
    }
}
