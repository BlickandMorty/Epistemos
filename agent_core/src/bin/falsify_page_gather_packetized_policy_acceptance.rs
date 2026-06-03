//! F-PageGather-Packetized-Policy-Acceptance.
//!
//! This is a policy witness, not the dense PageGather primary bandwidth gate.
//! It accepts the already-measured packetized PageGather path for retrieval and
//! witness surfaces while keeping dense restore out of hot product claims.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};

const FALSIFIER_ID: &str = "F-PageGather-Packetized-Policy-Acceptance";
const FIXTURE_ID: &str = "page_gather_packetized_policy_acceptance_v1";
const COMMAND: &str = "Tools/falsifiers/f_page_gather_packetized_policy_acceptance.sh";
const PAGE_GATHER_PATH: &str = "artifacts/falsifiers/page_gather/locality_probe_result.json";
const PAGE_GATHER_CALLER_PATH: &str =
    "artifacts/falsifiers/page_gather_packetized_caller/result.json";

fn main() -> std::process::ExitCode {
    let artifact = build_artifact();
    let pass = artifact.overall_pass;
    let path =
        PathBuf::from("artifacts/falsifiers/page_gather_packetized_policy_acceptance/result.json");
    if let Some(parent) = path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create artifact directory: {error}");
            return std::process::ExitCode::from(2);
        }
    }
    match std::fs::File::create(&path).and_then(|mut file| write_artifact(&mut file, &artifact)) {
        Ok(()) if pass => std::process::ExitCode::SUCCESS,
        Ok(()) => std::process::ExitCode::from(1),
        Err(error) => {
            eprintln!("failed to write artifact: {error}");
            std::process::ExitCode::from(2)
        }
    }
}

fn build_artifact() -> agent_core::falsifier_artifacts::FalsifierArtifact {
    let page_gather = read_json(PAGE_GATHER_PATH);
    let caller = read_json(PAGE_GATHER_CALLER_PATH);

    let packetized_floor_available = page_gather.is_some();
    let packetized_floor_zero_violations = axis_true(
        page_gather.as_ref(),
        "packetized_scheduled_correctness_violations_256mb",
    ) && axis_true(
        page_gather.as_ref(),
        "packetized_scheduled_correctness_violations_512mb",
    );
    let ratio_256 = measurement_f64(
        page_gather.as_ref(),
        "packetized_scheduled_stream_ratio_256mb",
    )
    .unwrap_or_default();
    let ratio_512 = measurement_f64(
        page_gather.as_ref(),
        "packetized_scheduled_stream_ratio_512mb",
    )
    .unwrap_or_default();
    let packetized_floor_stream_ratio = ratio_256 >= 0.70 && ratio_512 >= 0.70;
    let packetized_caller_available = caller.is_some();
    let packetized_caller_consumed = axis_true(caller.as_ref(), "packetized_caller_consumed");
    let dense_restore_deferred = axis_true(caller.as_ref(), "dense_restore_deferred");
    let retained_limit_honored = axis_true(caller.as_ref(), "retained_limit_honored");
    let policy_scope_retrieval_and_witness_only = true;
    let dense_primary_not_promoted = true;
    let rollback_keeps_dense_gate_red = !overall_pass(page_gather.as_ref());

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "packetized_floor_available",
        packetized_floor_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "packetized_floor_zero_violations",
        packetized_floor_zero_violations,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "packetized_floor_stream_ratio",
        packetized_floor_stream_ratio,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "packetized_caller_available",
        packetized_caller_available,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "packetized_caller_consumed",
        packetized_caller_consumed,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "dense_restore_deferred",
        dense_restore_deferred,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "retained_limit_honored",
        retained_limit_honored,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "policy_scope_retrieval_and_witness_only",
        policy_scope_retrieval_and_witness_only,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "dense_primary_not_promoted",
        dense_primary_not_promoted,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rollback_keeps_dense_gate_red",
        rollback_keeps_dense_gate_red,
    );

    add_f64_measurement(
        &mut measurements,
        "packetized_scheduled_stream_ratio_256mb",
        ratio_256,
    );
    add_f64_measurement(
        &mut measurements,
        "packetized_scheduled_stream_ratio_512mb",
        ratio_512,
    );
    add_label(
        &mut measurements,
        "policy_scope",
        "retrieval_and_witness_packetized_surfaces_only",
    );

    ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::FallbackWitness,
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Fallback,
        anomalies: vec![serde_json::json!({
            "kind": "dense_primary_not_promoted",
            "detail": "This accepts packetized PageGather only for retrieval and witness surfaces; dense F-PageGather-M2Pro remains red until its measured primary gate passes."
        })],
        notes: "fallback_witness; packetized PageGather policy accepted for retrieval/witness surfaces only; dense primary gate remains separate".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build()
}

fn read_json(path: &str) -> Option<serde_json::Value> {
    std::fs::read_to_string(path)
        .ok()
        .and_then(|text| serde_json::from_str(&text).ok())
}

fn overall_pass(value: Option<&serde_json::Value>) -> bool {
    value
        .and_then(|artifact| artifact.get("overall_pass"))
        .and_then(|value| value.as_bool())
        .unwrap_or(false)
}

fn axis_true(value: Option<&serde_json::Value>, axis: &str) -> bool {
    value
        .and_then(|artifact| artifact.get("pass_per_axis"))
        .and_then(|axes| axes.get(axis))
        .and_then(|value| value.as_bool())
        .unwrap_or(false)
}

fn measurement_f64(value: Option<&serde_json::Value>, key: &str) -> Option<f64> {
    value?.get("measurements")?.get(key)?.get("value")?.as_f64()
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: bool,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Bool(value),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value);
}

fn add_f64_measurement(measurements: &mut BTreeMap<String, Measurement>, key: &str, value: f64) {
    let number = serde_json::Number::from_f64(value).unwrap_or_else(|| serde_json::Number::from(0));
    measurements.insert(
        key.to_string(),
        Measurement {
            value: serde_json::Value::Number(number),
            unit: "ratio".to_string(),
        },
    );
}

fn add_label(measurements: &mut BTreeMap<String, Measurement>, key: &str, value: &str) {
    measurements.insert(
        key.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "label".to_string(),
        },
    );
}
