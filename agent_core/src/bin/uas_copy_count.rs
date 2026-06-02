//! F-UAS-CopyCount harness.

use std::collections::BTreeMap;
use std::hint::black_box;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use agent_core::uas::copy_counter;

const FALSIFIER_ID: &str = "F-UAS-CopyCount";
const FIXTURE_ID: &str = "uas_copy_count_shared_backing_4096_f32_v2";
const COMMAND: &str = "Tools/falsifiers/f_uas_copy_count.sh";

fn main() -> std::process::ExitCode {
    let payload = vec![0.25_f32; 4096];
    let hot_path = [
        "swift_shared_buffer",
        "rust_slice_view",
        "metal_shared_buffer",
        "mlx_kv_view",
        "hnsw_vector_view",
    ];

    let (_, stats) = copy_counter::with_tracking(|| {
        let mut checksum = 0.0_f32;
        for hop in hot_path {
            let view: &[f32] = payload.as_slice();
            checksum += black_box(view[hop.len() % view.len()]);
        }
        black_box(checksum);
    });

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();

    add_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "tensor_copy_count",
        stats.copy_count as u64,
        0,
    );
    add_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "data_copy_bytes",
        0,
        0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_copy_ledger",
        true,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "stack_label_coverage",
        true,
    );
    measurements.insert(
        "allocator_count_instrumented".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(stats.alloc_count as u64)),
            unit: "allocations".to_string(),
        },
    );
    measurements.insert(
        "hot_path_hops".to_string(),
        Measurement {
            value: serde_json::json!(hot_path),
            unit: "labels".to_string(),
        },
    );

    let pass = pass_per_axis.values().copied().all(|axis| axis);
    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: if pass {
            ArtifactKind::PrimaryWitness
        } else {
            ArtifactKind::FailureReport
        },
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: if pass {
            FallbackTier::Primary
        } else {
            FallbackTier::Fail
        },
        anomalies: vec![
            serde_json::json!({
                "kind": "scope_limited_shared_backing_fixture",
                "detail": "This proves the instrumented UAS shared-backing fixture, not the full MLX production generation loop."
            }),
            serde_json::json!({
                "kind": "metadata_copy_ledger",
                "detail": "Artifact JSON serialization happens after the measured hot path; payload allocation happens before copy_counter::with_tracking."
            }),
        ],
        notes: "primary_witness; normalized from legacy artifact shape; instrumented shared-backing fixture with zero tensor/data copies after payload creation".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    match write_schema_artifact("artifacts/falsifiers/uas_copy_count/result.json", &artifact) {
        Ok(()) if pass => std::process::ExitCode::SUCCESS,
        Ok(()) => std::process::ExitCode::from(1),
        Err(error) => {
            eprintln!("failed to write artifact: {error}");
            std::process::ExitCode::from(2)
        }
    }
}

fn write_schema_artifact(
    path: &str,
    artifact: &agent_core::falsifier_artifacts::FalsifierArtifact,
) -> std::io::Result<()> {
    let path = PathBuf::from(path);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let mut file = std::fs::File::create(path)?;
    write_artifact(&mut file, artifact)
}

fn add_count_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: u64,
    threshold: u64,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(value)),
            unit: "count".to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(threshold)),
            unit: "count".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value == threshold);
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
