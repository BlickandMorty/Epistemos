//! Source:
//! - `docs/fusion/helios v6.2.md` 8-stage falsifier §6 —
//!   SemiseparableBlockScan.metal correctness vs PyTorch
//!   `ssd_minimal.py` Listing 1 (acceptance: max-abs-diff ≤ 1e-3 fp16
//!   over 100 seeds).
//! - Dao & Gu, "Transformers are SSMs: Generalized Models and Efficient
//!   Algorithms Through Structured State Space Duality", arXiv:2405.21060,
//!   2024 — Mamba-2 SSD formulation. Listing 1 in the supplement
//!   `ssd_minimal.py` is the reference this kernel must match.
//! - Gu et al., "Mamba: Linear-Time Sequence Modeling with Selective
//!   State Spaces", arXiv:2312.00752, 2023 — predecessor S6.
//!
//! # Helios stage 6 — SemiseparableBlockScan (CPU reference)
//!
//! The per-timestep selective state-space recurrence (Mamba-2 SSD,
//! scalar variant):
//!
//! ```text
//! state[t] = a[t] * state[t-1] + b[t] * x[t]
//! y[t]     = c[t] * state[t]
//! ```
//!
//! Substrate floor implements the scalar (single-channel) reference;
//! the production kernel runs per-channel in parallel on Metal threads.
//! "Semiseparable" naming comes from the matrix-form rewrite where the
//! lower-triangular cumulative matrix is semiseparable rank-1; the
//! `_block` part refers to processing multiple tokens per launch.
//!
//! The Mamba-2 paper's correctness bar (acceptance §6) is:
//! `max |y_ref - y_kernel| ≤ 1e-3` in fp16 across 100 random seeds.
//! Substrate floor here lands the reference; the Metal kernel +
//! acceptance harness land in subsequent iters.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SsdScanError {
    LengthMismatch { a: usize, b: usize, c: usize, x: usize },
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SsdScanResult {
    pub y: Vec<f32>,
    pub final_state: f32,
}

/// Scalar SSD scan reference. Returns the per-step output sequence
/// `y` and the terminal state (for chained-block continuation).
pub fn ssd_scan_scalar(
    a: &[f32],
    b: &[f32],
    c: &[f32],
    x: &[f32],
    initial_state: f32,
) -> Result<SsdScanResult, SsdScanError> {
    if a.len() != b.len() || b.len() != c.len() || c.len() != x.len() {
        return Err(SsdScanError::LengthMismatch {
            a: a.len(),
            b: b.len(),
            c: c.len(),
            x: x.len(),
        });
    }
    let t = a.len();
    let mut state = initial_state;
    let mut y = Vec::with_capacity(t);
    for i in 0..t {
        state = a[i] * state + b[i] * x[i];
        y.push(c[i] * state);
    }
    Ok(SsdScanResult { y, final_state: state })
}

/// Block-scan variant: split the time axis into chunks of `block_size`,
/// scan each chunk, chain the terminal state into the next chunk's
/// initial state. Output is identical to `ssd_scan_scalar` (block
/// boundaries are transparent — the test
/// `block_scan_matches_single_pass` proves it) but the call shape
/// matches the Metal kernel's launch geometry.
pub fn ssd_block_scan_scalar(
    a: &[f32],
    b: &[f32],
    c: &[f32],
    x: &[f32],
    initial_state: f32,
    block_size: usize,
) -> Result<SsdScanResult, SsdScanError> {
    if a.len() != b.len() || b.len() != c.len() || c.len() != x.len() {
        return Err(SsdScanError::LengthMismatch {
            a: a.len(),
            b: b.len(),
            c: c.len(),
            x: x.len(),
        });
    }
    if block_size == 0 {
        return ssd_scan_scalar(a, b, c, x, initial_state);
    }
    let mut state = initial_state;
    let mut y = Vec::with_capacity(a.len());
    let mut i = 0;
    while i < a.len() {
        let end = (i + block_size).min(a.len());
        let block = ssd_scan_scalar(&a[i..end], &b[i..end], &c[i..end], &x[i..end], state)?;
        state = block.final_state;
        y.extend_from_slice(&block.y);
        i = end;
    }
    Ok(SsdScanResult { y, final_state: state })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_input_returns_empty_output_and_carries_state() {
        let r = ssd_scan_scalar(&[], &[], &[], &[], 7.0).unwrap();
        assert!(r.y.is_empty());
        assert_eq!(r.final_state, 7.0);
    }

    #[test]
    fn single_step_matches_hand_computation() {
        // state = 0.5 * 1.0 + 2.0 * 3.0 = 6.5
        // y = 4.0 * 6.5 = 26.0
        let r = ssd_scan_scalar(&[0.5], &[2.0], &[4.0], &[3.0], 1.0).unwrap();
        assert!((r.y[0] - 26.0).abs() < 1e-6);
        assert!((r.final_state - 6.5).abs() < 1e-6);
    }

    #[test]
    fn a_equals_one_b_equals_one_c_equals_one_is_running_sum() {
        let a = vec![1.0_f32; 4];
        let b = vec![1.0_f32; 4];
        let c = vec![1.0_f32; 4];
        let x = vec![1.0_f32, 2.0, 3.0, 4.0];
        let r = ssd_scan_scalar(&a, &b, &c, &x, 0.0).unwrap();
        assert_eq!(r.y, vec![1.0, 3.0, 6.0, 10.0]);
        assert_eq!(r.final_state, 10.0);
    }

    #[test]
    fn a_equals_zero_drops_state_each_step() {
        let a = vec![0.0_f32; 3];
        let b = vec![1.0_f32; 3];
        let c = vec![1.0_f32; 3];
        let x = vec![5.0_f32, 7.0, 11.0];
        let r = ssd_scan_scalar(&a, &b, &c, &x, 100.0).unwrap();
        assert_eq!(r.y, vec![5.0, 7.0, 11.0]);
        assert_eq!(r.final_state, 11.0);
    }

    #[test]
    fn length_mismatch_errors() {
        let err = ssd_scan_scalar(&[1.0, 2.0], &[1.0], &[1.0], &[1.0], 0.0).unwrap_err();
        assert!(matches!(err, SsdScanError::LengthMismatch { .. }));
    }

    #[test]
    fn block_scan_matches_single_pass_at_various_block_sizes() {
        let a: Vec<f32> = (0..16).map(|i| 0.5 + (i as f32) * 0.01).collect();
        let b: Vec<f32> = (0..16).map(|i| 1.0 + (i as f32) * 0.1).collect();
        let c: Vec<f32> = (0..16).map(|i| 0.9 + (i as f32) * 0.05).collect();
        let x: Vec<f32> = (0..16).map(|i| (i as f32) + 1.0).collect();
        let baseline = ssd_scan_scalar(&a, &b, &c, &x, 0.0).unwrap();
        for &block_size in &[1, 2, 4, 8, 16, 32] {
            let blocked =
                ssd_block_scan_scalar(&a, &b, &c, &x, 0.0, block_size).unwrap();
            assert_eq!(blocked.y.len(), baseline.y.len(), "len mismatch block={}", block_size);
            for i in 0..baseline.y.len() {
                assert!(
                    (blocked.y[i] - baseline.y[i]).abs() < 1e-5,
                    "diff at i={} block={}: {} vs {}",
                    i,
                    block_size,
                    blocked.y[i],
                    baseline.y[i]
                );
            }
            assert!((blocked.final_state - baseline.final_state).abs() < 1e-5);
        }
    }

    #[test]
    fn block_size_zero_falls_back_to_single_pass() {
        let a = vec![0.5_f32; 4];
        let b = vec![1.0_f32; 4];
        let c = vec![1.0_f32; 4];
        let x = vec![2.0_f32; 4];
        let baseline = ssd_scan_scalar(&a, &b, &c, &x, 0.0).unwrap();
        let blocked = ssd_block_scan_scalar(&a, &b, &c, &x, 0.0, 0).unwrap();
        assert_eq!(blocked, baseline);
    }

    #[test]
    fn initial_state_carries_into_first_step() {
        let a = vec![0.5_f32];
        let b = vec![0.0_f32];
        let c = vec![1.0_f32];
        let x = vec![0.0_f32];
        let r = ssd_scan_scalar(&a, &b, &c, &x, 4.0).unwrap();
        assert!((r.y[0] - 2.0).abs() < 1e-6);
        assert!((r.final_state - 2.0).abs() < 1e-6);
    }

    #[test]
    fn long_sequence_stays_finite_with_stable_a() {
        let n = 100;
        let a = vec![0.99_f32; n];
        let b = vec![0.01_f32; n];
        let c = vec![1.0_f32; n];
        let x = vec![1.0_f32; n];
        let r = ssd_scan_scalar(&a, &b, &c, &x, 0.0).unwrap();
        assert_eq!(r.y.len(), n);
        assert!(r.y.iter().all(|v| v.is_finite()));
    }

    #[test]
    fn result_serializes_through_serde_json() {
        let r = SsdScanResult { y: vec![1.0, 2.0, 3.0], final_state: 4.0 };
        let json = serde_json::to_string(&r).unwrap();
        let back: SsdScanResult = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn block_scan_carries_state_across_chunks() {
        let n = 8;
        let a = vec![0.5_f32; n];
        let b = vec![1.0_f32; n];
        let c = vec![1.0_f32; n];
        let x = vec![1.0_f32; n];
        let r_one_block = ssd_block_scan_scalar(&a, &b, &c, &x, 0.0, n).unwrap();
        let r_two_blocks = ssd_block_scan_scalar(&a, &b, &c, &x, 0.0, n / 2).unwrap();
        for i in 0..n {
            assert!((r_one_block.y[i] - r_two_blocks.y[i]).abs() < 1e-6);
        }
        assert!((r_one_block.final_state - r_two_blocks.final_state).abs() < 1e-6);
    }
}
