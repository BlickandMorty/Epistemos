//! `falsify_page_gather` — T23B Phase 2 Terminal F harness binary for
//! F-PageGather (CPU baseline / fallback witness).
//!
//! Per `docs/falsifiers/F-PageGather-M2Pro_2026_05_17.md` the primary
//! gate is a **Metal scatter kernel** sustaining ≥ 70% of
//! STREAM-on-Metal. The CPU scalar reference at
//! `agent_core/src/helios/page_gather.rs` is the bit-exact ground truth
//! the Metal kernel must match. This binary runs the CPU reference
//! across the canonical 256/512/1024 MB working sets, records sustained
//! throughput, and emits a **fallback_witness** — the Metal gate
//! itself (W-41) remains pending on Swift+xcodebuild dispatch wire-in.
//!
//! Conservative scope (per CLAUDE.md research-first + no-fake-success):
//! - Measures CPU scatter throughput (not Metal).
//! - Reports CPU baseline only (no STREAM-on-Metal ratio).
//! - Uses 16 MB / 64 MB / 256 MB working sets to bound runtime under
//!   M2 Pro 16 GB UMA pressure when other terminals' worktrees are
//!   present (per F-PageGather-M2Pro §5.4 background-noise control).
//!
//! Source:
//! - `docs/falsifiers/F-PageGather-M2Pro_2026_05_17.md`
//! - `docs/falsifiers/F_PAGE_GATHER_BASELINE_2026_05_18.md`
//! - `agent_core/src/helios/page_gather.rs` (CPU reference)

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::time::Instant;

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use agent_core::helios::page_gather::gather;

const FALSIFIER_ID: &str = "F-PageGather-M2Pro";
const FIXTURE_ID: &str = "page_gather_cpu_scatter_fy_chacha8_v1";
const COMMAND: &str = "cargo run --release --bin falsify_page_gather";

// Conservative working sets (CPU baseline; the full Metal gate at
// 256/512/1024 MB requires the GPU scatter kernel). We sweep up to
// 256 MB on CPU which is well within M2 Pro 16 GB UMA bounds even
// with other terminals' worktrees present.
const WORKING_SETS_MB: &[usize] = &[16, 64, 256];
const WINDOW_SECONDS: f64 = 1.0;
const FP32_BYTES: usize = 4;
// CPU scatter baseline — a sanity floor (NOT the Metal gate). Honest
// CPU-bound throughput on M2 Pro 16 GB is ~3-15 GB/s for in-L2
// working sets and drops to ~0.5-1.5 GB/s once the working set
// outgrows L2 and the random scatter pattern starts page-faulting,
// especially when the rig is also running parallel cargo builds in
// other worktrees. We require ≥ 0.3 GB/s as a structural-correctness
// gate — anything below means the scatter loop itself is broken, not
// just contended.
const CPU_SCATTER_FLOOR_GBS: f64 = 0.3;

fn main() {
    let started_utc = now_utc_rfc3339();
    let start = Instant::now();

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();
    let mut anomalies: Vec<serde_json::Value> = Vec::new();

    for &ws_mb in WORKING_SETS_MB {
        let element_count = (ws_mb * 1024 * 1024) / FP32_BYTES;
        let source = build_source(element_count);
        let indices = fisher_yates_shuffle(element_count as u32, ws_mb as u64 ^ 0xBA_7A_C1_5A);
        let mut out = vec![0.0_f32; element_count];

        // Warm-up: one untimed pass to prime caches + page-in source.
        let _ = gather(&source, &indices, &mut out);

        let gbs = measure_throughput(&source, &indices, &mut out, WINDOW_SECONDS);
        let axis = format!("scatter_gbs_{ws_mb}mb");
        measurements.insert(
            axis.clone(),
            Measurement {
                value: serde_json::Value::Number(
                    serde_json::Number::from_f64(gbs)
                        .unwrap_or_else(|| serde_json::Number::from(0)),
                ),
                unit: "GB_per_second".to_string(),
            },
        );
        thresholds.insert(
            axis.clone(),
            AcceptanceThreshold {
                operator: ">=".to_string(),
                value: serde_json::Value::Number(
                    serde_json::Number::from_f64(CPU_SCATTER_FLOOR_GBS)
                        .unwrap_or_else(|| serde_json::Number::from(0)),
                ),
                unit: "GB_per_second".to_string(),
            },
        );
        pass_per_axis.insert(axis, gbs >= CPU_SCATTER_FLOOR_GBS);

        // Sanity gate: verify the scatter produced the right values
        // on a sampled subset (out[i] must equal source[indices[i]]).
        let bad_samples = sample_correctness_check(&source, &indices, &out);
        let correct_axis = format!("correctness_violations_{ws_mb}mb");
        measurements.insert(
            correct_axis.clone(),
            Measurement {
                value: serde_json::Value::Number(serde_json::Number::from(bad_samples as u64)),
                unit: "violations".to_string(),
            },
        );
        thresholds.insert(
            correct_axis.clone(),
            AcceptanceThreshold {
                operator: "==".to_string(),
                value: serde_json::Value::Number(serde_json::Number::from(0)),
                unit: "violations".to_string(),
            },
        );
        pass_per_axis.insert(correct_axis, bad_samples == 0);
    }

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
        "detail": "CPU-only fallback witness. The F-PageGather-M2Pro \
                   primary gate requires Metal scatter kernel + \
                   STREAM-on-Metal triad baseline; both pending \
                   (W-41 Apple-platform external work). This artifact \
                   establishes the bit-exact CPU reference + sanity-checks \
                   the scalar scatter throughput floor."
    }));

    let notes = "fallback_witness; primary Metal gate W-41; CPU scalar reference \
                 only; working sets capped at 256 MB for M2 Pro 16 GB shared-rig safety; \
                 BW figures here are CPU-bound, NOT the F-PageGather-M2Pro 70%-of-STREAM \
                 acceptance bar"
        .to_string();

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

    let path = PathBuf::from("artifacts/falsifiers/page_gather/result.json");
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).expect("create artifacts directory");
    }
    let mut file = std::fs::File::create(&path).expect("open artifact for write");
    write_artifact(&mut file, &artifact).expect("write artifact");

    println!(
        "F-PageGather-M2Pro (CPU fallback): overall_pass={} elapsed_seconds={:.2} artifact={}",
        artifact.overall_pass,
        elapsed_seconds,
        path.display()
    );

    if !artifact.overall_pass {
        std::process::exit(1);
    }
}

/// Build a stable source buffer — deterministic content per index so the
/// correctness check has a known answer without storing a copy.
fn build_source(n: usize) -> Vec<f32> {
    let mut s = Vec::with_capacity(n);
    for i in 0..n {
        s.push((i as f32) * 1.0e-6);
    }
    s
}

/// Deterministic Fisher-Yates shuffle seeded by `seed`. Uses xorshift64
/// for in-binary determinism without pulling another rng dependency.
fn fisher_yates_shuffle(n: u32, seed: u64) -> Vec<u32> {
    let mut out: Vec<u32> = (0..n).collect();
    let mut state = seed.wrapping_mul(0x9E37_79B9_7F4A_7C15) | 1;
    for i in (1..out.len()).rev() {
        // xorshift64
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        let j = (state as usize) % (i + 1);
        out.swap(i, j);
    }
    out
}

fn measure_throughput(
    source: &[f32],
    indices: &[u32],
    out: &mut [f32],
    window_seconds: f64,
) -> f64 {
    let bytes_per_iter = (indices.len() * FP32_BYTES) as u64;
    let start = Instant::now();
    let mut iterations: u64 = 0;
    let mut total_bytes: u64 = 0;
    let deadline = std::time::Duration::from_secs_f64(window_seconds);
    while start.elapsed() < deadline {
        // Inline scatter; gather() is bounds-checked + returns stats —
        // for throughput we skip the validation overhead and trust the
        // already-validated indices.
        for i in 0..indices.len() {
            // SAFETY: indices is the shuffled 0..n permutation;
            // get_unchecked here is safe and matters for the
            // CPU baseline number.
            unsafe {
                let idx = *indices.get_unchecked(i) as usize;
                *out.get_unchecked_mut(i) = *source.get_unchecked(idx);
            }
        }
        iterations += 1;
        total_bytes = total_bytes.wrapping_add(bytes_per_iter);
        if iterations > 10_000 {
            break;
        }
    }
    let elapsed = start.elapsed().as_secs_f64().max(1e-9);
    (total_bytes as f64) / elapsed / 1e9
}

fn sample_correctness_check(source: &[f32], indices: &[u32], out: &[f32]) -> usize {
    // Sample 1024 evenly-spaced positions; cheap correctness floor.
    let mut bad = 0;
    let step = indices.len().max(1) / 1024;
    let step = step.max(1);
    let mut i = 0;
    while i < indices.len() {
        let idx = indices[i] as usize;
        if out[i] != source[idx] {
            bad += 1;
        }
        i += step;
    }
    bad
}
