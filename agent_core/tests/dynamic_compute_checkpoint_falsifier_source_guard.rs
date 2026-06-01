//! Source guard for the non-executing DynamicCompute checkpoint falsifier.
//!
//! Dynamic compute may only affect output through explicit, visible
//! checkpoints. The retained falsifier must stay manifest-only: no model load,
//! no mmap stress, no hidden kernel pause.

use std::path::Path;

#[test]
fn dynamic_compute_checkpoint_falsifier_files_exist() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"));

    assert!(
        root.join("src/bin/falsify_dynamic_compute_checkpoint.rs")
            .is_file(),
        "F-DynamicCompute-Checkpoint must have a retained Rust artifact emitter"
    );
    assert!(
        root.join("../Tools/falsifiers/f_dynamic_compute_checkpoint.sh")
            .is_file(),
        "F-DynamicCompute-Checkpoint must have a retained lightweight runner"
    );
}

#[test]
fn dynamic_compute_checkpoint_falsifier_stays_manifest_only() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"));
    let source = std::fs::read_to_string(root.join("src/bin/falsify_dynamic_compute_checkpoint.rs"))
        .expect("falsifier source should be readable");

    for snippet in [
        "F-DynamicCompute-Checkpoint",
        "DynamicComputeCheckpoint::from_visible_run_event",
        "runtime_model_bytes_loaded",
        "dry_run_ssd_read_bytes",
        "visible_run_event_ordinal_bound",
        "no mmap, no cache warm, no model byte load, no inference",
    ] {
        assert!(
            source.contains(snippet),
            "dynamic checkpoint falsifier must retain snippet `{snippet}`"
        );
    }
}
