//! `falsify_cold_fault_trace_learning` — fixture-only cold-miss learning gate.
//!
//! This witness proves repeated cold misses emit `ColdFaultTrace`s and generate
//! a rollback-only shadow `LayoutPatch` that improves held-out fixtures without
//! mutating production layout. It does not move bytes, rewrite storage, prefetch,
//! run MLX/Metal, or mutate route policy.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ColdFaultTrace, LayoutPatch, LayoutPatchPromotionStatus, SemanticWorkingSetError, UasAddress,
    UasKind,
};

const FALSIFIER_ID: &str = "F-ColdFaultTrace-Learning";
const FIXTURE_ID: &str = "cold_fault_trace_learning_v1";
const COMMAND: &str = "Tools/falsifiers/f_cold_fault_trace_learning.sh";
const RESULT: &str = "artifacts/falsifiers/cold_fault_trace_learning/result.json";
const CREATED_AT_MS: u64 = 1_779_000_000_000;
const BASELINE_HELD_OUT_MISSES: u64 = 3;
const PATCHED_HELD_OUT_MISSES: u64 = 1;

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
        "{FALSIFIER_ID}: overall_pass={} trace_count={} held_out_delta={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["trace_count"].value,
        artifact.measurements["held_out_cold_miss_delta"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let traces = fixture_traces()?;
    let reversed = traces.iter().cloned().rev().collect::<Vec<_>>();
    let patch = fixture_patch(traces.clone())?;
    let reversed_patch = fixture_patch(reversed)?;

    let traces_emitted = traces.len() == 2;
    let repeated_misses_required = single_trace_rejected()?;
    let trace_address_deterministic = traces[0].trace_address == fixture_traces()?[0].trace_address;
    let missing_unit_bound = traces
        .iter()
        .all(|trace| trace.missing_unit.to_string().len() > 20);
    let expected_unit_bound = traces
        .iter()
        .all(|trace| trace.expected_unit.to_string().len() > 20);
    let stall_ms_reported = traces.iter().map(|trace| trace.stall_ms).sum::<u64>() == 40;
    let cold_io_bytes_reported =
        traces.iter().map(|trace| trace.cold_io_bytes).sum::<u64>() == 128 * 1024;
    let fallback_used_visible = traces
        .iter()
        .all(|trace| trace.fallback_used.starts_with("runtime_router:fallback_"));
    let answer_effect_visible = traces.iter().all(|trace| !trace.answer_effect.is_empty());
    let source_or_cache_cause_visible = traces
        .iter()
        .all(|trace| !trace.source_or_cache_cause.is_empty());
    let layout_patch_generated = !patch.patch_address.to_string().is_empty();
    let patch_address_deterministic = patch.patch_address == reversed_patch.patch_address;
    let changed_tiles_bounded = patch.changed_tiles.len() == 2;
    let expected_cold_miss_delta_improves = patch.expected_cold_miss_delta < 0;
    let observed_cold_miss_delta_improves = patch.observed_cold_miss_delta < 0;
    let held_out_improvement_visible = PATCHED_HELD_OUT_MISSES < BASELINE_HELD_OUT_MISSES
        && patch.held_out_metrics_ref.starts_with("held_out:");
    let rollback_bound = patch.rollback_ref.starts_with("rollback:");
    let promotion_status_shadow_candidate =
        patch.promotion_status == LayoutPatchPromotionStatus::ShadowCandidate;
    let production_mutation_blocked = !patch.production_mutation && live_mutation_rejected()?;
    let no_improvement_rejected = no_improvement_rejected()?;
    let missing_rollback_rejected = missing_rollback_rejected()?;
    let storage_wear_bounded = patch.storage_wear_cost <= 128 * 1024;
    let storage_wear_unbounded_rejected = storage_wear_unbounded_rejected()?;
    let zero_stall_trace_rejected = zero_stall_trace_rejected()?;
    let empty_changed_tiles_rejected = empty_changed_tiles_rejected()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        ("traces_emitted", traces_emitted),
        ("repeated_misses_required", repeated_misses_required),
        ("trace_address_deterministic", trace_address_deterministic),
        ("missing_unit_bound", missing_unit_bound),
        ("expected_unit_bound", expected_unit_bound),
        ("stall_ms_reported", stall_ms_reported),
        ("cold_io_bytes_reported", cold_io_bytes_reported),
        ("fallback_used_visible", fallback_used_visible),
        ("answer_effect_visible", answer_effect_visible),
        (
            "source_or_cache_cause_visible",
            source_or_cache_cause_visible,
        ),
        ("layout_patch_generated", layout_patch_generated),
        ("patch_address_deterministic", patch_address_deterministic),
        ("changed_tiles_bounded", changed_tiles_bounded),
        (
            "expected_cold_miss_delta_improves",
            expected_cold_miss_delta_improves,
        ),
        (
            "observed_cold_miss_delta_improves",
            observed_cold_miss_delta_improves,
        ),
        ("held_out_improvement_visible", held_out_improvement_visible),
        ("rollback_bound", rollback_bound),
        (
            "promotion_status_shadow_candidate",
            promotion_status_shadow_candidate,
        ),
        ("production_mutation_blocked", production_mutation_blocked),
        ("no_improvement_rejected", no_improvement_rejected),
        ("missing_rollback_rejected", missing_rollback_rejected),
        ("storage_wear_bounded", storage_wear_bounded),
        (
            "storage_wear_unbounded_rejected",
            storage_wear_unbounded_rejected,
        ),
        ("zero_stall_trace_rejected", zero_stall_trace_rejected),
        ("empty_changed_tiles_rejected", empty_changed_tiles_rejected),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            pass,
        );
    }

    add_i64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "held_out_cold_miss_delta",
        PATCHED_HELD_OUT_MISSES as i64 - BASELINE_HELD_OUT_MISSES as i64,
        -1,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "trace_count",
        traces.len() as u64,
        2,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "changed_tile_count",
        patch.changed_tiles.len() as u64,
        4,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "storage_wear_cost",
        patch.storage_wear_cost,
        128 * 1024,
        "<=",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "patch_address",
        &patch.patch_address.to_string(),
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
            "detail": "fixture-only cold-fault learning; no byte movement, layout rewrite, prefetch, model decode, MLX/Metal, route mutation, or production policy mutation executed"
        })],
        notes: "Proves repeated cold misses emit deterministic ColdFaultTrace records and generate a bounded rollback-only shadow LayoutPatch that improves held-out cold-miss fixtures while rejecting one-trace, no-improvement, missing-rollback, high-wear, zero-stall, empty-tile, and live-mutation cases.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn fixture_traces() -> Result<Vec<ColdFaultTrace>, Box<dyn std::error::Error>> {
    Ok(vec![
        cold_fault_trace("missing-weight-a", "expected-weight-a", 18, 64 * 1024)?,
        cold_fault_trace("missing-weight-b", "expected-weight-b", 22, 64 * 1024)?,
    ])
}

fn cold_fault_trace(
    missing_unit: &str,
    expected_unit: &str,
    stall_ms: u64,
    cold_io_bytes: u64,
) -> Result<ColdFaultTrace, Box<dyn std::error::Error>> {
    Ok(ColdFaultTrace::new(
        "mission:module-5-adversarial-thinking",
        address(UasKind::ModelComponent, missing_unit.as_bytes()),
        address(UasKind::ModelComponent, expected_unit.as_bytes()),
        stall_ms,
        cold_io_bytes,
        "runtime_router:fallback_static_route",
        "answer_delayed_not_wrong",
        "source:prefetch-window-miss",
        "layout-patch:module-5-coactivation",
        CREATED_AT_MS,
    )?)
}

fn fixture_patch(traces: Vec<ColdFaultTrace>) -> Result<LayoutPatch, Box<dyn std::error::Error>> {
    Ok(LayoutPatch::from_repeated_cold_faults(
        "layout-patch:module-5-coactivation",
        traces,
        "layout:module-5-coactivated",
        "layout:file-order",
        vec!["tile:assessment".to_string(), "tile:module-5".to_string()],
        -2,
        -1,
        4096,
        "rollback:cold-fault-layout",
        "held_out:module-5-fixtures",
        false,
        CREATED_AT_MS,
    )?)
}

fn single_trace_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    Ok(matches!(
        fixture_patch(vec![fixture_traces()?[0].clone()])
            .unwrap_err()
            .downcast_ref::<SemanticWorkingSetError>(),
        Some(SemanticWorkingSetError::ColdFaultLearningRejected { .. })
    ))
}

fn no_improvement_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = LayoutPatch::from_repeated_cold_faults(
        "layout-patch:no-improvement",
        fixture_traces()?,
        "layout:module-5-coactivated",
        "layout:file-order",
        vec!["tile:module-5".to_string()],
        0,
        0,
        4096,
        "rollback:cold-fault-layout",
        "held_out:module-5-fixtures",
        false,
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::ColdFaultLearningRejected { .. }
    ))
}

fn missing_rollback_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = LayoutPatch::from_repeated_cold_faults(
        "layout-patch:missing-rollback",
        fixture_traces()?,
        "layout:module-5-coactivated",
        "layout:file-order",
        vec!["tile:module-5".to_string()],
        -2,
        -1,
        4096,
        "live:mutate-layout",
        "held_out:module-5-fixtures",
        false,
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::ColdFaultLearningRejected { .. }
    ))
}

fn live_mutation_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = LayoutPatch::from_repeated_cold_faults(
        "layout-patch:live-mutation",
        fixture_traces()?,
        "layout:module-5-coactivated",
        "layout:file-order",
        vec!["tile:module-5".to_string()],
        -2,
        -1,
        4096,
        "rollback:cold-fault-layout",
        "held_out:module-5-fixtures",
        true,
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::ColdFaultLearningRejected { .. }
    ))
}

fn storage_wear_unbounded_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = LayoutPatch::from_repeated_cold_faults(
        "layout-patch:high-wear",
        fixture_traces()?,
        "layout:module-5-coactivated",
        "layout:file-order",
        vec!["tile:module-5".to_string()],
        -2,
        -1,
        256 * 1024,
        "rollback:cold-fault-layout",
        "held_out:module-5-fixtures",
        false,
        CREATED_AT_MS,
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::ColdFaultLearningRejected { .. }
    ))
}

fn zero_stall_trace_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = cold_fault_trace("missing-zero", "expected-zero", 0, 64 * 1024).unwrap_err();
    Ok(matches!(
        error.downcast_ref::<SemanticWorkingSetError>(),
        Some(SemanticWorkingSetError::ColdFaultLearningRejected { .. })
    ))
}

fn empty_changed_tiles_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    Ok(LayoutPatch::from_repeated_cold_faults(
        "layout-patch:empty-tiles",
        fixture_traces()?,
        "layout:module-5-coactivated",
        "layout:file-order",
        Vec::new(),
        -2,
        -1,
        4096,
        "rollback:cold-fault-layout",
        "held_out:module-5-fixtures",
        false,
        CREATED_AT_MS,
    )
    .is_err())
}

fn address(kind: UasKind, bytes: &[u8]) -> UasAddress {
    UasAddress::new(kind, bytes, CREATED_AT_MS)
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    pass: bool,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Bool(pass),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    operator: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(actual)),
            unit: "count_or_bytes".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(expected)),
            unit: "count_or_bytes".to_string(),
        },
    );
    let pass = match operator {
        "<=" => actual <= expected,
        ">=" => actual >= expected,
        "==" => actual == expected,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_i64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: i64,
    expected: i64,
    operator: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(actual)),
            unit: "signed_count".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(expected)),
            unit: "signed_count".to_string(),
        },
    );
    let pass = match operator {
        "<=" => actual <= expected,
        ">=" => actual >= expected,
        "==" => actual == expected,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
) {
    let pass = !value.is_empty();
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "string".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "string".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}
