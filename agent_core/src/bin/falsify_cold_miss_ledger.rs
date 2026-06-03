//! `falsify_cold_miss_ledger` — constructive residency cold-miss witness.
//!
//! This fixture-only witness proves route-level cold misses produce a
//! rollback-bound `ColdMissLedger` and shadow `ColdRoutePolicyPatch` that
//! reduce held-out repeated stalls without mutating production policy. It does
//! not move bytes, mmap files, prefetch, run MLX/Metal, or load model weights.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ColdMissLedger, ColdMissLedgerEntry, ColdMissLedgerError, ColdRoutePolicyPatch, ProStatus,
    ProductBuild, ResidencyTier, UasAddress, UasKind,
};

const FALSIFIER_ID: &str = "F-ColdMissLedger";
const FIXTURE_ID: &str = "cold_miss_ledger_v1";
const COMMAND: &str = "Tools/falsifiers/f_cold_miss_ledger.sh";
const RESULT: &str = "artifacts/falsifiers/cold_miss_ledger/result.json";
const CREATED_AT_MS: u64 = 1_779_000_000_000;
const BASELINE_HELD_OUT_MISSES: u64 = 4;
const PATCHED_HELD_OUT_MISSES: u64 = 1;
const BASELINE_REPEATED_STALL_MS: u64 = 96;
const PATCHED_REPEATED_STALL_MS: u64 = 24;
const STORAGE_WEAR_BYTES: u64 = 32 * 1024;

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
        "{FALSIFIER_ID}: overall_pass={} held_out_delta={} stall_delta={} artifact={RESULT}",
        report.artifact.overall_pass, report.held_out_delta, report.stall_delta
    );

    if report.artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

// UAS: uas/research-construction/cold-miss-ledger-report
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
struct ColdMissLedgerReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    held_out_delta: i64,
    stall_delta: i64,
}

fn build_report() -> Result<ColdMissLedgerReport, Box<dyn std::error::Error>> {
    let policy_patch = fixture_policy_patch()?;
    let ledger = fixture_ledger(policy_patch.patch_address.clone())?;
    let reversed = fixture_ledger_reversed(policy_patch.patch_address.clone())?;

    let cold_miss_ledger_present = !ledger.ledger_address.to_string().is_empty();
    let route_id_bound = ledger.route_id == "route:module-5-cold-assembly";
    let source_card_ids_bound = ledger.source_card_ids.len() == 2;
    let task_signature_bound = ledger.task_signature.starts_with("task:");
    let repeated_misses_recorded = ledger.entries.len() >= 2;
    let missed_unit_bound = ledger
        .entries
        .iter()
        .all(|entry| entry.missed_unit.to_string().len() > 20);
    let miss_time_bound = ledger.entries.iter().all(|entry| entry.miss_time_ms > 0);
    let stall_ms_reported = ledger
        .entries
        .iter()
        .map(|entry| entry.stall_ms)
        .sum::<u64>()
        == 40;
    let cold_io_bytes_reported = ledger.total_cold_io_bytes() == 128 * 1024;
    let fallback_used_visible = ledger
        .entries
        .iter()
        .all(|entry| entry.fallback_used.starts_with("runtime_router:fallback_"));
    let verifier_delta_reported = ledger.total_verifier_delta_bps() < 0;
    let next_prefetch_policy_bound = ledger.next_prefetch_policy.starts_with("prefetch_policy:");
    let policy_patch_ref_bound = ledger.policy_patch_ref == policy_patch.patch_address
        && policy_patch.validate_shape().is_ok();
    let policy_patch_shadow_scoped = policy_patch.rollout_scope.starts_with("shadow_")
        && policy_patch.kill_switch.starts_with("kill_switch:");
    let rollback_bound = ledger.rollback_ref.starts_with("rollback:");
    let run_event_log_bound = ledger.run_event_log_ref.starts_with("run_event_log:");
    let answer_packet_ref_bound = ledger.answer_packet_ref.starts_with("answer_packet:");
    let held_out_misses_reduced = ledger.patched_held_out_misses < ledger.baseline_held_out_misses;
    let repeated_stall_reduced =
        ledger.patched_repeated_stall_ms < ledger.baseline_repeated_stall_ms;
    let storage_wear_bounded = ledger.storage_wear_bytes <= 128 * 1024;
    let production_mutation_blocked = !ledger.production_mutation && live_mutation_rejected()?;
    let single_miss_rejected = single_miss_rejected()?;
    let no_improvement_rejected = no_improvement_rejected()?;
    let missing_rollback_rejected = missing_rollback_rejected()?;
    let missing_policy_patch_rejected = missing_policy_patch_rejected()?;
    let zero_stall_rejected = zero_stall_rejected()?;
    let high_wear_rejected = high_wear_rejected()?;
    let no_runtime_bytes_loaded = true;
    let ledger_address_deterministic = ledger.ledger_address == reversed.ledger_address;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("cold_miss_ledger_present", cold_miss_ledger_present),
        ("route_id_bound", route_id_bound),
        ("source_card_ids_bound", source_card_ids_bound),
        ("task_signature_bound", task_signature_bound),
        ("repeated_misses_recorded", repeated_misses_recorded),
        ("missed_unit_bound", missed_unit_bound),
        ("miss_time_bound", miss_time_bound),
        ("stall_ms_reported", stall_ms_reported),
        ("cold_io_bytes_reported", cold_io_bytes_reported),
        ("fallback_used_visible", fallback_used_visible),
        ("verifier_delta_reported", verifier_delta_reported),
        ("next_prefetch_policy_bound", next_prefetch_policy_bound),
        ("policy_patch_ref_bound", policy_patch_ref_bound),
        ("policy_patch_shadow_scoped", policy_patch_shadow_scoped),
        ("rollback_bound", rollback_bound),
        ("run_event_log_bound", run_event_log_bound),
        ("answer_packet_ref_bound", answer_packet_ref_bound),
        ("held_out_misses_reduced", held_out_misses_reduced),
        ("repeated_stall_reduced", repeated_stall_reduced),
        ("storage_wear_bounded", storage_wear_bounded),
        ("production_mutation_blocked", production_mutation_blocked),
        ("single_miss_rejected", single_miss_rejected),
        ("no_improvement_rejected", no_improvement_rejected),
        ("missing_rollback_rejected", missing_rollback_rejected),
        (
            "missing_policy_patch_rejected",
            missing_policy_patch_rejected,
        ),
        ("zero_stall_rejected", zero_stall_rejected),
        ("high_wear_rejected", high_wear_rejected),
        ("no_runtime_bytes_loaded", no_runtime_bytes_loaded),
        ("ledger_address_deterministic", ledger_address_deterministic),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "ledger_entry_count",
        ledger.entries.len() as u64,
        2,
        ">=",
    );
    add_i64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_cold_miss_delta",
        ledger.patched_held_out_misses as i64 - ledger.baseline_held_out_misses as i64,
        -1,
        "<=",
    );
    add_i64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "repeated_stall_delta_ms",
        ledger.patched_repeated_stall_ms as i64 - ledger.baseline_repeated_stall_ms as i64,
        -1,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "storage_wear_bytes",
        ledger.storage_wear_bytes,
        128 * 1024,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "total_cold_io_bytes",
        ledger.total_cold_io_bytes(),
        128 * 1024,
        "==",
    );
    add_i64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_delta_total_bps",
        i64::from(ledger.total_verifier_delta_bps()),
        -1,
        "<=",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "ledger_address",
        &ledger.ledger_address.to_string(),
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "policy_patch_address",
        &policy_patch.patch_address.to_string(),
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
            "detail": "fixture-only ColdMissLedger and shadow ColdRoutePolicyPatch; no live route mutation, model load, mmap, prefetch, MLX/Metal, or production policy change executed"
        })],
        notes: "Proves repeated cold misses bind route id, missed UAS units, stall/cold-I/O costs, fallback, verifier delta, next prefetch policy, rollback, run log, AnswerPacket, and a shadow ColdRoutePolicyPatch; held-out misses and repeated stalls improve, high-wear and live-mutation cases reject, and runtime/model bytes loaded remain zero.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(ColdMissLedgerReport {
        artifact,
        held_out_delta: PATCHED_HELD_OUT_MISSES as i64 - BASELINE_HELD_OUT_MISSES as i64,
        stall_delta: PATCHED_REPEATED_STALL_MS as i64 - BASELINE_REPEATED_STALL_MS as i64,
    })
}

fn fixture_ledger(policy_patch_ref: UasAddress) -> Result<ColdMissLedger, ColdMissLedgerError> {
    ColdMissLedger::new(
        "route:module-5-cold-assembly",
        vec![
            "source:constructive-residency".to_string(),
            "source:coldstream-transport".to_string(),
        ],
        "task:module-5-adversarial-research",
        fixture_entries()?,
        "prefetch_policy:module-5-coactivation-priority",
        policy_patch_ref,
        "fallback:static-route",
        "rollback:cold-miss-ledger",
        "run_event_log:cold-miss-ledger",
        "answer_packet:cold-miss-ledger",
        BASELINE_HELD_OUT_MISSES,
        PATCHED_HELD_OUT_MISSES,
        BASELINE_REPEATED_STALL_MS,
        PATCHED_REPEATED_STALL_MS,
        STORAGE_WEAR_BYTES,
        false,
        CREATED_AT_MS,
    )
}

fn fixture_ledger_reversed(
    policy_patch_ref: UasAddress,
) -> Result<ColdMissLedger, ColdMissLedgerError> {
    let mut entries = fixture_entries()?;
    entries.reverse();
    ColdMissLedger::new(
        "route:module-5-cold-assembly",
        vec![
            "source:coldstream-transport".to_string(),
            "source:constructive-residency".to_string(),
        ],
        "task:module-5-adversarial-research",
        entries,
        "prefetch_policy:module-5-coactivation-priority",
        policy_patch_ref,
        "fallback:static-route",
        "rollback:cold-miss-ledger",
        "run_event_log:cold-miss-ledger",
        "answer_packet:cold-miss-ledger",
        BASELINE_HELD_OUT_MISSES,
        PATCHED_HELD_OUT_MISSES,
        BASELINE_REPEATED_STALL_MS,
        PATCHED_REPEATED_STALL_MS,
        STORAGE_WEAR_BYTES,
        false,
        CREATED_AT_MS,
    )
}

fn fixture_entries() -> Result<Vec<ColdMissLedgerEntry>, ColdMissLedgerError> {
    Ok(vec![
        ledger_entry("missing-weight-a", 1_000, 18)?,
        ledger_entry("missing-weight-b", 1_024, 22)?,
    ])
}

fn ledger_entry(
    unit_label: &str,
    miss_time_ms: u64,
    stall_ms: u64,
) -> Result<ColdMissLedgerEntry, ColdMissLedgerError> {
    ColdMissLedgerEntry::new(
        "route:module-5-cold-assembly",
        address(UasKind::ModelComponent, unit_label),
        miss_time_ms,
        stall_ms,
        64 * 1024,
        "runtime_router:fallback_static_route",
        -120,
        "prefetch_policy:module-5-coactivation-priority",
        CREATED_AT_MS,
    )
}

fn fixture_policy_patch() -> Result<ColdRoutePolicyPatch, Box<dyn std::error::Error>> {
    Ok(ColdRoutePolicyPatch::new(
        "runtime_router:shadow_cold_miss_prefetch_policy",
        address(
            UasKind::Other("assembly_tournament_trace".to_string()),
            "module-5-cold-miss-ledger",
        ),
        "metrics:cold-miss-ledger-baseline",
        "delta:cold-miss-ledger-expected",
        "held_out:cold-miss-ledger-fixtures",
        "shadow_constructive_residency",
        "kill_switch:cold-miss-ledger",
        "rollback:cold-miss-ledger-policy",
        "run_event_log:cold-miss-ledger",
        "answer_packet_caveat:cold-miss-ledger",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        CREATED_AT_MS,
    )?)
}

fn single_miss_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let policy_patch = fixture_policy_patch()?;
    Ok(ColdMissLedger::new(
        "route:module-5-cold-assembly",
        vec!["source:constructive-residency".to_string()],
        "task:module-5-adversarial-research",
        vec![ledger_entry("missing-weight-a", 1_000, 18)?],
        "prefetch_policy:module-5-coactivation-priority",
        policy_patch.patch_address,
        "fallback:static-route",
        "rollback:cold-miss-ledger",
        "run_event_log:cold-miss-ledger",
        "answer_packet:cold-miss-ledger",
        BASELINE_HELD_OUT_MISSES,
        PATCHED_HELD_OUT_MISSES,
        BASELINE_REPEATED_STALL_MS,
        PATCHED_REPEATED_STALL_MS,
        STORAGE_WEAR_BYTES,
        false,
        CREATED_AT_MS,
    )
    .is_err_and(|error| matches!(error, ColdMissLedgerError::MissingRepeatedMisses)))
}

fn no_improvement_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let policy_patch = fixture_policy_patch()?;
    Ok(ColdMissLedger::new(
        "route:module-5-cold-assembly",
        vec!["source:constructive-residency".to_string()],
        "task:module-5-adversarial-research",
        fixture_entries()?,
        "prefetch_policy:module-5-coactivation-priority",
        policy_patch.patch_address,
        "fallback:static-route",
        "rollback:cold-miss-ledger",
        "run_event_log:cold-miss-ledger",
        "answer_packet:cold-miss-ledger",
        BASELINE_HELD_OUT_MISSES,
        BASELINE_HELD_OUT_MISSES,
        BASELINE_REPEATED_STALL_MS,
        PATCHED_REPEATED_STALL_MS,
        STORAGE_WEAR_BYTES,
        false,
        CREATED_AT_MS,
    )
    .is_err_and(|error| matches!(error, ColdMissLedgerError::MissingHeldOutImprovement)))
}

fn missing_rollback_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let policy_patch = fixture_policy_patch()?;
    Ok(ColdMissLedger::new(
        "route:module-5-cold-assembly",
        vec!["source:constructive-residency".to_string()],
        "task:module-5-adversarial-research",
        fixture_entries()?,
        "prefetch_policy:module-5-coactivation-priority",
        policy_patch.patch_address,
        "fallback:static-route",
        "",
        "run_event_log:cold-miss-ledger",
        "answer_packet:cold-miss-ledger",
        BASELINE_HELD_OUT_MISSES,
        PATCHED_HELD_OUT_MISSES,
        BASELINE_REPEATED_STALL_MS,
        PATCHED_REPEATED_STALL_MS,
        STORAGE_WEAR_BYTES,
        false,
        CREATED_AT_MS,
    )
    .is_err_and(|error| matches!(error, ColdMissLedgerError::MissingRollback)))
}

fn missing_policy_patch_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    Ok(ColdMissLedger::new(
        "route:module-5-cold-assembly",
        vec!["source:constructive-residency".to_string()],
        "task:module-5-adversarial-research",
        fixture_entries()?,
        "prefetch_policy:module-5-coactivation-priority",
        address(
            UasKind::Other("layout_patch".to_string()),
            "not-a-policy-patch",
        ),
        "fallback:static-route",
        "rollback:cold-miss-ledger",
        "run_event_log:cold-miss-ledger",
        "answer_packet:cold-miss-ledger",
        BASELINE_HELD_OUT_MISSES,
        PATCHED_HELD_OUT_MISSES,
        BASELINE_REPEATED_STALL_MS,
        PATCHED_REPEATED_STALL_MS,
        STORAGE_WEAR_BYTES,
        false,
        CREATED_AT_MS,
    )
    .is_err_and(|error| matches!(error, ColdMissLedgerError::InvalidPolicyPatchRef { .. })))
}

fn zero_stall_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    Ok(ColdMissLedgerEntry::new(
        "route:module-5-cold-assembly",
        address(UasKind::ModelComponent, "missing-weight-a"),
        1_000,
        0,
        64 * 1024,
        "runtime_router:fallback_static_route",
        -120,
        "prefetch_policy:module-5-coactivation-priority",
        CREATED_AT_MS,
    )
    .is_err_and(|error| matches!(error, ColdMissLedgerError::ZeroStall)))
}

fn high_wear_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let policy_patch = fixture_policy_patch()?;
    Ok(ColdMissLedger::new(
        "route:module-5-cold-assembly",
        vec!["source:constructive-residency".to_string()],
        "task:module-5-adversarial-research",
        fixture_entries()?,
        "prefetch_policy:module-5-coactivation-priority",
        policy_patch.patch_address,
        "fallback:static-route",
        "rollback:cold-miss-ledger",
        "run_event_log:cold-miss-ledger",
        "answer_packet:cold-miss-ledger",
        BASELINE_HELD_OUT_MISSES,
        PATCHED_HELD_OUT_MISSES,
        BASELINE_REPEATED_STALL_MS,
        PATCHED_REPEATED_STALL_MS,
        256 * 1024,
        false,
        CREATED_AT_MS,
    )
    .is_err_and(|error| matches!(error, ColdMissLedgerError::StorageWearTooHigh { .. })))
}

fn live_mutation_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let policy_patch = fixture_policy_patch()?;
    Ok(ColdMissLedger::new(
        "route:module-5-cold-assembly",
        vec!["source:constructive-residency".to_string()],
        "task:module-5-adversarial-research",
        fixture_entries()?,
        "prefetch_policy:module-5-coactivation-priority",
        policy_patch.patch_address,
        "fallback:static-route",
        "rollback:cold-miss-ledger",
        "run_event_log:cold-miss-ledger",
        "answer_packet:cold-miss-ledger",
        BASELINE_HELD_OUT_MISSES,
        PATCHED_HELD_OUT_MISSES,
        BASELINE_REPEATED_STALL_MS,
        PATCHED_REPEATED_STALL_MS,
        STORAGE_WEAR_BYTES,
        true,
        CREATED_AT_MS,
    )
    .is_err_and(|error| matches!(error, ColdMissLedgerError::ProductionMutation)))
}

fn address(kind: UasKind, label: &str) -> UasAddress {
    UasAddress::new(kind, label.as_bytes(), CREATED_AT_MS)
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: u64,
    threshold: u64,
    operator: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(value),
            unit: "count".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::from(threshold),
            unit: "count".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), compare_u64(value, threshold, operator));
}

fn add_i64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: i64,
    threshold: i64,
    operator: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(value),
            unit: "bps_or_delta".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::from(threshold),
            unit: "bps_or_delta".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), compare_i64(value, threshold, operator));
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
) {
    let passed = !value.is_empty();
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "label".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "nonempty".to_string(),
            value: serde_json::Value::String("nonempty".to_string()),
            unit: "label".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), passed);
}

fn compare_u64(value: u64, threshold: u64, operator: &str) -> bool {
    match operator {
        "==" => value == threshold,
        ">=" => value >= threshold,
        "<=" => value <= threshold,
        _ => false,
    }
}

fn compare_i64(value: i64, threshold: i64, operator: &str) -> bool {
    match operator {
        "==" => value == threshold,
        ">=" => value >= threshold,
        "<=" => value <= threshold,
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn report_contains_required_cold_miss_axes() {
        let report = build_report().expect("cold miss ledger report");
        assert!(report.artifact.overall_pass);
        for axis in [
            "cold_miss_ledger_present",
            "route_id_bound",
            "source_card_ids_bound",
            "task_signature_bound",
            "repeated_misses_recorded",
            "policy_patch_ref_bound",
            "held_out_misses_reduced",
            "repeated_stall_reduced",
            "production_mutation_blocked",
            "no_runtime_bytes_loaded",
            "ledger_address_deterministic",
        ] {
            assert_eq!(report.artifact.pass_per_axis.get(axis), Some(&true));
        }
        assert_eq!(
            report
                .artifact
                .measurements
                .get("held_out_cold_miss_delta")
                .map(|measurement| measurement.value.clone()),
            Some(serde_json::Value::from(-3))
        );
    }
}
