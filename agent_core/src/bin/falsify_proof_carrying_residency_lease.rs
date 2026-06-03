//! `falsify_proof_carrying_residency_lease` — constructive residency lease gate.
//!
//! This fixture-only witness proves cold-byte wake proposals require a
//! proof-carrying lease envelope with UAS address, reason, byte cost,
//! proof/falsifier reference, expiry, fallback, and rollback. It does not move
//! bytes, mmap files, run MLX, touch Metal, call providers, or mutate route
//! policy.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    authorize_cold_byte_wake, ProofCarryingResidencyLease, ProofCarryingResidencyLeaseError,
    ResidencyTier, UasAddress, UasKind,
};

const FALSIFIER_ID: &str = "F-ProofCarryingResidencyLease";
const FIXTURE_ID: &str = "proof_carrying_residency_lease_v1";
const COMMAND: &str = "Tools/falsifiers/f_proof_carrying_residency_lease.sh";
const RESULT: &str = "artifacts/falsifiers/proof_carrying_residency_lease/result.json";
const CREATED_AT_MS: u64 = 1_779_200_000_000;
const AUTHORIZE_AT_MS: u64 = CREATED_AT_MS + 2_000;
const MAX_ACTIVE_BYTE_COST: u64 = 64 * 1024;

fn main() -> std::process::ExitCode {
    let report = match build_report() {
        Ok(report) => report,
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
    if let Err(error) = write_artifact(&mut file, &report.artifact) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }

    println!(
        "{FALSIFIER_ID}: overall_pass={} accepted_wakes={} rejected_wakes={} artifact={RESULT}",
        report.artifact.overall_pass, report.accepted_wake_count, report.rejected_wake_count
    );

    if report.artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

// UAS: uas/research-construction/proof-carrying-residency-lease-falsifier-report
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
struct ProofLeaseReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    accepted_wake_count: u64,
    rejected_wake_count: u64,
}

fn build_report() -> Result<ProofLeaseReport, Box<dyn std::error::Error>> {
    let leases = valid_leases()?;
    let deterministic_lease = cold_evidence_lease()?;
    let accepted_wakes = leases
        .iter()
        .filter_map(|lease| {
            authorize_cold_byte_wake(
                &lease.unit_id,
                Some(lease),
                AUTHORIZE_AT_MS,
                MAX_ACTIVE_BYTE_COST,
            )
            .ok()
        })
        .collect::<Vec<_>>();

    let wake_without_lease_rejected = authorize_cold_byte_wake(
        "unit:cold-evidence",
        None,
        AUTHORIZE_AT_MS,
        MAX_ACTIVE_BYTE_COST,
    )
    .is_err_and(|error| matches!(error, ProofCarryingResidencyLeaseError::MissingLease { .. }));
    let missing_reason_rejected = invalid_lease(
        "",
        "F-CoactivationTile-Prefetch",
        "fallback:skip",
        "rollback:hot",
    )
    .is_err_and(|error| error == ProofCarryingResidencyLeaseError::MissingLeaseReason);
    let missing_proof_rejected =
        invalid_lease("needs cold evidence", "", "fallback:skip", "rollback:hot").is_err_and(
            |error| error == ProofCarryingResidencyLeaseError::MissingProofOrFalsifierRef,
        );
    let missing_fallback_rejected = invalid_lease(
        "needs cold evidence",
        "F-CoactivationTile-Prefetch",
        "",
        "rollback:hot",
    )
    .is_err_and(|error| error == ProofCarryingResidencyLeaseError::MissingFallback);
    let missing_rollback_rejected = invalid_lease(
        "needs cold evidence",
        "F-CoactivationTile-Prefetch",
        "fallback:skip",
        "",
    )
    .is_err_and(|error| error == ProofCarryingResidencyLeaseError::MissingRollback);
    let expired_lease_rejected = leases[0]
        .authorize_wake(leases[0].expires_at_ms(), MAX_ACTIVE_BYTE_COST)
        .is_err_and(|error| matches!(error, ProofCarryingResidencyLeaseError::ExpiredLease { .. }));
    let over_budget_wake_rejected = leases[0]
        .authorize_wake(AUTHORIZE_AT_MS, 16 * 1024)
        .is_err_and(|error| {
            matches!(
                error,
                ProofCarryingResidencyLeaseError::ActiveByteCostOverBudget { .. }
            )
        });
    let wrong_lease_rejected = authorize_cold_byte_wake(
        "unit:wrong",
        Some(&leases[0]),
        AUTHORIZE_AT_MS,
        MAX_ACTIVE_BYTE_COST,
    )
    .is_err_and(|error| {
        matches!(
            error,
            ProofCarryingResidencyLeaseError::UnitIdMismatch { .. }
        )
    });

    let active_byte_total = accepted_wakes
        .iter()
        .map(|wake| wake.active_byte_cost)
        .sum::<u64>();
    let min_ttl_ms = leases
        .iter()
        .map(|lease| lease.residency_lease.ttl_ms)
        .min()
        .unwrap_or_default();
    let max_active_byte_cost = leases
        .iter()
        .map(|lease| lease.active_byte_cost)
        .max()
        .unwrap_or_default();
    let rejected_wake_count = [
        wake_without_lease_rejected,
        missing_reason_rejected,
        missing_proof_rejected,
        missing_fallback_rejected,
        missing_rollback_rejected,
        expired_lease_rejected,
        over_budget_wake_rejected,
        wrong_lease_rejected,
    ]
    .into_iter()
    .filter(|passed| *passed)
    .count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_carrying_leases_present",
        leases.len() == 2,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "uas_addresses_bound",
        leases
            .iter()
            .all(|lease| lease.uas_address == lease.residency_lease.address),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lease_reasons_bound",
        leases.iter().all(|lease| !lease.lease_reason.is_empty()),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_byte_costs_bound",
        leases.iter().all(|lease| {
            lease.active_byte_cost > 0 && lease.active_byte_cost <= MAX_ACTIVE_BYTE_COST
        }),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "expected_utility_bound",
        leases
            .iter()
            .all(|lease| (1..=10_000).contains(&lease.expected_utility_bps)),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_or_falsifier_refs_bound",
        leases.iter().all(|lease| {
            lease.proof_or_falsifier_ref.starts_with("F-")
                || lease.proof_or_falsifier_ref.starts_with("proof:")
        }),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "expiry_bound",
        leases
            .iter()
            .all(|lease| lease.expires_at_ms() > AUTHORIZE_AT_MS),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fallback_bound",
        leases
            .iter()
            .all(|lease| lease.fallback_ref.starts_with("fallback:")),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rollback_bound",
        leases
            .iter()
            .all(|lease| lease.rollback_ref.starts_with("rollback:")),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lease_tier_capability_ceiling",
        leases
            .iter()
            .all(|lease| lease.residency_lease.tier == ResidencyTier::CapabilityCeiling),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lease_address_deterministic",
        leases[0].lease_address == deterministic_lease.lease_address,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_wakes_authorized",
        accepted_wakes.len() == leases.len(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "wake_without_lease_rejected",
        wake_without_lease_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_reason_rejected",
        missing_reason_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_proof_rejected",
        missing_proof_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_fallback_rejected",
        missing_fallback_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_rollback_rejected",
        missing_rollback_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "expired_lease_rejected",
        expired_lease_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "over_budget_wake_rejected",
        over_budget_wake_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "wrong_lease_rejected",
        wrong_lease_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_runtime_bytes_loaded",
        true,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "accepted_wake_count",
        accepted_wakes.len() as u64,
        2,
        "==",
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rejected_wake_count",
        rejected_wake_count,
        8,
        "==",
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_byte_total",
        active_byte_total,
        MAX_ACTIVE_BYTE_COST,
        "<=",
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_active_byte_cost",
        max_active_byte_cost,
        MAX_ACTIVE_BYTE_COST,
        "<=",
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "min_ttl_ms",
        min_ttl_ms,
        1,
        ">=",
        "ms",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lease_address",
        &leases[0].lease_address.to_string(),
    );

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: vec![serde_json::json!({
            "kind": "scope_guard",
            "detail": "metadata-only proof-carrying residency lease fixture; no cold bytes, mmap, model decode, MLX, Metal, KV, provider call, or live route policy mutation executed"
        })],
        notes: "Proves cold-byte wake proposals require proof-carrying residency leases with UAS address, reason, byte cost, proof/falsifier ref, expiry, fallback, and rollback; cold assembly runtime remains a separate gate.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(ProofLeaseReport {
        artifact,
        accepted_wake_count: accepted_wakes.len() as u64,
        rejected_wake_count,
    })
}

fn valid_leases() -> Result<Vec<ProofCarryingResidencyLease>, ProofCarryingResidencyLeaseError> {
    Ok(vec![cold_evidence_lease()?, verifier_lane_lease()?])
}

fn cold_evidence_lease() -> Result<ProofCarryingResidencyLease, ProofCarryingResidencyLeaseError> {
    lease(
        "unit:cold-evidence",
        UasKind::KvPage,
        b"cold-evidence-page",
        "answer needs cold evidence bundle",
        32 * 1024,
        9_200,
        "F-CoactivationTile-Prefetch",
        "fallback:skip-cold-evidence",
        "rollback:restore-hot-only-route",
        120_000,
    )
}

fn verifier_lane_lease() -> Result<ProofCarryingResidencyLease, ProofCarryingResidencyLeaseError> {
    lease(
        "unit:verifier-lane",
        UasKind::ToolResult,
        b"verifier-lane-output",
        "answer needs verifier proof packet",
        8 * 1024,
        8_700,
        "proof:lean-schema-check",
        "fallback:abstain-on-verifier-gap",
        "rollback:drop-verifier-lane",
        90_000,
    )
}

fn lease(
    unit_id: &str,
    kind: UasKind,
    address_bytes: &[u8],
    lease_reason: &str,
    active_byte_cost: u64,
    expected_utility_bps: u16,
    proof_or_falsifier_ref: &str,
    fallback_ref: &str,
    rollback_ref: &str,
    ttl_ms: u64,
) -> Result<ProofCarryingResidencyLease, ProofCarryingResidencyLeaseError> {
    ProofCarryingResidencyLease::new(
        unit_id,
        UasAddress::new(kind, address_bytes, CREATED_AT_MS),
        lease_reason,
        active_byte_cost,
        expected_utility_bps,
        proof_or_falsifier_ref,
        fallback_ref,
        rollback_ref,
        CREATED_AT_MS,
        ttl_ms,
    )
}

fn invalid_lease(
    lease_reason: &str,
    proof_or_falsifier_ref: &str,
    fallback_ref: &str,
    rollback_ref: &str,
) -> Result<ProofCarryingResidencyLease, ProofCarryingResidencyLeaseError> {
    lease(
        "unit:invalid",
        UasKind::KvPage,
        b"invalid-unit",
        lease_reason,
        1,
        1,
        proof_or_falsifier_ref,
        fallback_ref,
        rollback_ref,
        1,
    )
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    threshold: u64,
    operator: &str,
    unit: &str,
) {
    let pass = match operator {
        "==" => actual == threshold,
        "<=" => actual <= threshold,
        ">=" => actual >= threshold,
        _ => false,
    };
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::from(threshold),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual.to_string()),
            unit: "string".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::String(actual.to_string()),
            unit: "string".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), true);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn report_contains_required_proof_lease_axes() {
        let report = build_report().expect("proof lease report should build");
        for axis in [
            "proof_carrying_leases_present",
            "uas_addresses_bound",
            "lease_reasons_bound",
            "active_byte_costs_bound",
            "expected_utility_bound",
            "proof_or_falsifier_refs_bound",
            "expiry_bound",
            "fallback_bound",
            "rollback_bound",
            "lease_tier_capability_ceiling",
            "lease_address_deterministic",
            "cold_wakes_authorized",
            "wake_without_lease_rejected",
            "missing_reason_rejected",
            "missing_proof_rejected",
            "missing_fallback_rejected",
            "missing_rollback_rejected",
            "expired_lease_rejected",
            "over_budget_wake_rejected",
            "wrong_lease_rejected",
            "no_runtime_bytes_loaded",
        ] {
            assert_eq!(report.artifact.pass_per_axis.get(axis), Some(&true));
            assert!(report.artifact.measurements.contains_key(axis));
            assert!(report.artifact.acceptance_thresholds.contains_key(axis));
        }
    }
}
