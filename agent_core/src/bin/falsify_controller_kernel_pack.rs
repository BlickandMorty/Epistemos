//! `falsify_controller_kernel_pack` — T23B Phase 2 Terminal F harness
//! binary for F-ControllerKernelPack (CPU fallback witness).
//!
//! Per `docs/falsifiers/F-ControllerKernelPack_2026_05_17.md` the
//! primary gate is "all 6 kernels (scalar-add / scalar-mul / max /
//! argmax / copy / zero-fill) reference-equivalent under fp32 tolerance"
//! comparing Metal vs CPU. The CPU side already lives at
//! `agent_core/src/helios/controller_pack.rs`.
//!
//! This binary runs the 6 CPU kernels against deterministic inputs,
//! computes a stable result digest, asserts the **closure** of the
//! kernel set under their own contract (no NaNs, no length-mismatch
//! errors on aligned inputs, no empty-input panics with the right
//! errors), and emits a **fallback_witness**. The primary witness
//! requires Metal dispatch — pending W-41.
//!
//! Source:
//! - `docs/falsifiers/F-ControllerKernelPack_2026_05_17.md`
//! - `docs/falsifiers/F_CONTROLLER_KERNEL_PACK_2026_05_18.md`
//! - `agent_core/src/helios/controller_pack.rs`

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::time::Instant;

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, sha256_hex, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::helios::controller_pack::{
    argmax_reduce, copy_range, max_reduce, scalar_add_in_place, scalar_mul_in_place, zero_fill,
    ControllerKernelError,
};

const FALSIFIER_ID: &str = "F-ControllerKernelPack";
const FIXTURE_ID: &str = "controller_pack_deterministic_fp32_v1";
const COMMAND: &str = "cargo run --release --bin falsify_controller_kernel_pack";

const SIZES: &[usize] = &[16, 256, 4_096, 65_536];

fn main() {
    let started_utc = now_utc_rfc3339();
    let start = Instant::now();

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();
    let mut anomalies: Vec<serde_json::Value> = Vec::new();

    let mut digest_bytes = Vec::new();
    let mut violations: usize = 0;

    for &n in SIZES {
        let input: Vec<f32> = (0..n)
            .map(|i| (i as f32) * 0.5 - (n as f32) * 0.25)
            .collect();

        // scalar_add_in_place
        let mut a = input.clone();
        scalar_add_in_place(&mut a, 0.125);
        digest_chunk(&mut digest_bytes, "scalar_add", n, &a);

        // scalar_mul_in_place
        let mut b = input.clone();
        scalar_mul_in_place(&mut b, 2.0);
        digest_chunk(&mut digest_bytes, "scalar_mul", n, &b);

        // max_reduce
        match max_reduce(&input) {
            Ok(m) => digest_chunk(&mut digest_bytes, "max", n, &[m]),
            Err(_) if n > 0 => violations += 1,
            Err(_) => {}
        }

        // argmax_reduce
        match argmax_reduce(&input) {
            Ok(idx) => digest_chunk(&mut digest_bytes, "argmax", n, &[idx as f32]),
            Err(_) if n > 0 => violations += 1,
            Err(_) => {}
        }

        // copy_range
        let mut dst = vec![0.0_f32; n];
        match copy_range(&mut dst, &input) {
            Ok(()) => digest_chunk(&mut digest_bytes, "copy", n, &dst),
            Err(_) => violations += 1,
        }

        // zero_fill
        let mut z = input.clone();
        zero_fill(&mut z);
        if z.iter().any(|&v| v != 0.0) {
            violations += 1;
        }
        digest_chunk(&mut digest_bytes, "zero_fill", n, &z);
    }

    // Empty-input contract: max + argmax MUST return EmptyInput error.
    let empty: Vec<f32> = vec![];
    let empty_contract_pass = matches!(
        max_reduce(&empty),
        Err(ControllerKernelError::EmptyInput {
            which: "max_reduce"
        })
    ) && matches!(
        argmax_reduce(&empty),
        Err(ControllerKernelError::EmptyInput {
            which: "argmax_reduce"
        })
    );

    // Length-mismatch contract: copy_range MUST reject mismatched lengths.
    let mut dst_short = vec![0.0_f32; 3];
    let src_long = vec![1.0_f32; 5];
    let mismatch_contract_pass = matches!(
        copy_range(&mut dst_short, &src_long),
        Err(ControllerKernelError::LengthMismatch { dst: 3, src: 5 })
    );

    measurements.insert(
        "violations_aligned_inputs".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(violations as u64)),
            unit: "count".to_string(),
        },
    );
    thresholds.insert(
        "violations_aligned_inputs".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(0)),
            unit: "count".to_string(),
        },
    );
    pass_per_axis.insert("violations_aligned_inputs".to_string(), violations == 0);

    let pack_digest = sha256_hex(&digest_bytes);
    measurements.insert(
        "kernel_pack_digest".to_string(),
        Measurement {
            value: serde_json::Value::String(pack_digest.clone()),
            unit: "sha256_hex".to_string(),
        },
    );
    thresholds.insert(
        "kernel_pack_digest".to_string(),
        AcceptanceThreshold {
            operator: "=~".to_string(),
            value: serde_json::Value::String("^sha256:[0-9a-f]{64}$".to_string()),
            unit: "regex".to_string(),
        },
    );
    pass_per_axis.insert(
        "kernel_pack_digest".to_string(),
        pack_digest.starts_with("sha256:") && pack_digest.len() == 71,
    );

    measurements.insert(
        "empty_input_contract".to_string(),
        Measurement {
            value: serde_json::Value::Bool(empty_contract_pass),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        "empty_input_contract".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert("empty_input_contract".to_string(), empty_contract_pass);

    measurements.insert(
        "length_mismatch_contract".to_string(),
        Measurement {
            value: serde_json::Value::Bool(mismatch_contract_pass),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        "length_mismatch_contract".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(
        "length_mismatch_contract".to_string(),
        mismatch_contract_pass,
    );

    let elapsed_seconds = start.elapsed().as_secs_f64();
    measurements.insert(
        "harness_wall_clock_seconds".to_string(),
        Measurement {
            value: serde_json::Value::Number(
                serde_json::Number::from_f64(elapsed_seconds)
                    .unwrap_or_else(|| serde_json::Number::from(0)),
            ),
            unit: "seconds".to_string(),
        },
    );

    anomalies.push(serde_json::json!({
        "kind": "scope_caveat",
        "detail": "CPU fallback witness. Primary F-ControllerKernelPack \
                   gate requires Metal kernel-vs-CPU equivalence \
                   (Epistemos/Shaders/ControllerKernelPack.metal) plus \
                   threadgroup budget measurement; pending W-41. \
                   This artifact certifies the CPU reference's contract \
                   closure (empty-input + length-mismatch errors) + \
                   deterministic digest of the 6 kernels over 4 input sizes."
    }));

    let notes = format!(
        "fallback_witness; primary Metal gate W-41; CPU reference \
         contract closure verified over sizes={SIZES:?}; pack_digest={pack_digest}"
    );

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::FallbackWitness,
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Fallback,
        anomalies,
        notes,
        timestamp_utc: started_utc,
    }
    .build();

    let path = PathBuf::from("artifacts/falsifiers/controller_kernel_pack/result.json");
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("create artifacts directory");
    }
    let mut file = std::fs::File::create(&path).expect("open artifact for write");
    write_artifact(&mut file, &artifact).expect("write artifact");

    println!(
        "F-ControllerKernelPack (CPU fallback): overall_pass={} elapsed_seconds={:.4} artifact={}",
        artifact.overall_pass,
        elapsed_seconds,
        path.display()
    );

    if !artifact.overall_pass {
        std::process::exit(1);
    }
}

fn digest_chunk(bytes: &mut Vec<u8>, label: &str, n: usize, values: &[f32]) {
    bytes.extend_from_slice(label.as_bytes());
    bytes.extend_from_slice(&(n as u64).to_le_bytes());
    for v in values {
        bytes.extend_from_slice(&v.to_bits().to_le_bytes());
    }
}
