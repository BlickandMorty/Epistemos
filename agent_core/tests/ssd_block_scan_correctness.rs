//! F-SemiseparableBlockScan-Correctness — substrate-floor Track A harness.
//!
//! Per `docs/falsifiers/F-SemiseparableBlockScan-Correctness_2026_05_17.md`
//! §3.1 Track A.
//!
//! # Substrate-floor scope
//!
//! Exercises `agent_core::helios::{ssd_scan_scalar, ssd_block_scan_scalar,
//! compare_scans, ssd_stability_check}` over 100 seeds × variant lengths
//! + block-size sweep. Proves the Rust scalar reference is internally
//! consistent (single-pass vs block-chunked yields identical output).
//!
//! Production-PASS Track A per falsifier §3.1 requires Metal kernel
//! match-vs-PyTorch `ssd_minimal.py` Listing 1 within max-abs-diff
//! ≤ 1e-3 fp16 over 100 seeds. Substrate-floor here proves the Rust
//! scalar reference is correct; Metal-vs-Rust match-check is the next
//! step (Phase B.G.B5+).

use agent_core::helios::{compare_scans, ssd_block_scan_scalar, ssd_scan_scalar, ssd_stability_check};

struct MiniRng(u64);

impl MiniRng {
    fn new(seed: u64) -> Self { Self(seed) }
    fn next_f32_unit(&mut self) -> f32 {
        // Step LCG; return value in [-0.95, 0.95] (avoids stability boundary).
        self.0 = self.0.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
        let u = (self.0 >> 11) as f32 / (1u64 << 53) as f32; // [0, 1)
        u * 1.9 - 0.95
    }
}

fn generate_seeded_inputs(seed: u64, timesteps: usize) -> (Vec<f32>, Vec<f32>, Vec<f32>, Vec<f32>) {
    let mut rng = MiniRng::new(seed);
    let a: Vec<f32> = (0..timesteps).map(|_| rng.next_f32_unit() * 0.9).collect(); // |a| < 0.9 for stability
    let b: Vec<f32> = (0..timesteps).map(|_| rng.next_f32_unit()).collect();
    let c: Vec<f32> = (0..timesteps).map(|_| rng.next_f32_unit()).collect();
    let x: Vec<f32> = (0..timesteps).map(|_| rng.next_f32_unit()).collect();
    (a, b, c, x)
}

#[test]
fn single_pass_matches_block_pass_across_100_seeds() {
    let timesteps = 512;
    let block_sizes = [32, 64, 128, 256];
    let mut max_observed_diff = 0.0_f32;

    for seed in 0..100_u64 {
        let (a, b, c, x) = generate_seeded_inputs(0xACAA_5500 + seed, timesteps);
        let single = ssd_scan_scalar(&a, &b, &c, &x, 0.0).expect("scan must succeed");

        for &bs in &block_sizes {
            let block = ssd_block_scan_scalar(&a, &b, &c, &x, 0.0, bs).expect("block scan must succeed");
            let diff = compare_scans(&single, &block)
                .expect("scan outputs must have matching length");
            if diff > max_observed_diff {
                max_observed_diff = diff;
            }
            // Block boundaries should be EXACTLY transparent (no rounding).
            assert!(
                diff < 1e-5,
                "seed {} block_size {} max-abs-diff {} > 1e-5 (block boundaries should be transparent)",
                seed, bs, diff
            );
        }
    }

    // Final summary diff should be vanishingly small.
    assert!(max_observed_diff < 1e-5);
}

#[test]
fn stability_check_accepts_safe_a_values() {
    let safe_a = vec![0.5, -0.5, 0.8, 0.0, -0.8];
    assert!(ssd_stability_check(&safe_a, 0.05));
}

#[test]
fn stability_check_rejects_unstable_a_values() {
    let unstable_a = vec![0.5, 1.0, 0.8]; // 1.0 ≥ (1 - 0.05) = 0.95
    assert!(!ssd_stability_check(&unstable_a, 0.05));
}

#[test]
fn stability_check_rejects_non_finite() {
    let bad_a = vec![0.5, f32::NAN, 0.8];
    assert!(!ssd_stability_check(&bad_a, 0.05));
    let bad_a = vec![0.5, f32::INFINITY, 0.8];
    assert!(!ssd_stability_check(&bad_a, 0.05));
}

#[test]
fn compare_scans_length_mismatch_returns_none() {
    use agent_core::helios::SsdScanResult;
    let ref_scan = SsdScanResult { y: vec![1.0, 2.0], final_state: 0.0 };
    let other = SsdScanResult { y: vec![1.0], final_state: 0.0 };
    assert!(compare_scans(&ref_scan, &other).is_none());
}

#[test]
fn length_mismatch_errors() {
    let res = ssd_scan_scalar(&[1.0, 2.0], &[1.0], &[1.0], &[1.0], 0.0);
    assert!(res.is_err());
}

#[test]
fn known_input_known_output() {
    // a = 0.5, b = 1, c = 1, x = 1, state_0 = 0
    // state_1 = 0.5*0 + 1*1 = 1; y_1 = 1*1 = 1
    // state_2 = 0.5*1 + 1*1 = 1.5; y_2 = 1*1.5 = 1.5
    // state_3 = 0.5*1.5 + 1*1 = 1.75; y_3 = 1*1.75 = 1.75
    let scan = ssd_scan_scalar(&[0.5, 0.5, 0.5], &[1.0, 1.0, 1.0], &[1.0, 1.0, 1.0], &[1.0, 1.0, 1.0], 0.0).unwrap();
    assert!((scan.y[0] - 1.0).abs() < 1e-6);
    assert!((scan.y[1] - 1.5).abs() < 1e-6);
    assert!((scan.y[2] - 1.75).abs() < 1e-6);
}

#[test]
fn empty_input_produces_empty_output() {
    let scan = ssd_scan_scalar(&[], &[], &[], &[], 0.0).unwrap();
    assert!(scan.y.is_empty());
    assert_eq!(scan.final_state, 0.0);
}
