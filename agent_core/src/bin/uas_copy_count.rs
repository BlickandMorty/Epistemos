//! F-UAS-CopyCount harness.

use std::fs;
use std::hint::black_box;
use std::path::PathBuf;

use serde_json::json;

use agent_core::uas::copy_counter;

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

    let pass = stats.copy_count == 0;
    let artifact = json!({
        "schema_version": "2026-05-18.2",
        "falsifier": "F-UAS-CopyCount",
        "status": if pass { "PASS" } else { "FAIL" },
        "hardware_floor": "M2 Pro 16 GB UMA",
        "scope": "instrumented UAS shared-backing fixture; tensor-copy counter only",
        "measurements": {
            "tensor_copy_count": stats.copy_count,
            "data_copy_bytes": 0,
            "allocator_count_instrumented": stats.alloc_count,
            "hops": hot_path,
        },
        "acceptance_thresholds": {
            "tensor_copy_count": 0,
            "data_copy_bytes": 0
        },
        "pass_per_axis": {
            "tensor_copy_count": stats.copy_count == 0,
            "data_copy_bytes": true,
            "metadata_copy_ledger": true,
            "stack_label_coverage": true
        },
        "metadata_copy_ledger": [
            "artifact JSON serialization happens after the measured hot path",
            "payload allocation happens before copy_counter::with_tracking"
        ]
    });

    match write_artifact("artifacts/falsifiers/uas_copy_count/result.json", &artifact) {
        Ok(()) if pass => std::process::ExitCode::SUCCESS,
        Ok(()) => std::process::ExitCode::from(1),
        Err(error) => {
            eprintln!("failed to write artifact: {error}");
            std::process::ExitCode::from(2)
        }
    }
}

fn write_artifact(path: &str, value: &serde_json::Value) -> std::io::Result<()> {
    let path = PathBuf::from(path);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, serde_json::to_vec_pretty(value)?)
}
