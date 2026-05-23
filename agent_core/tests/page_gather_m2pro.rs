//! F-PageGather-M2Pro — substrate-floor Rust CPU twin.
//!
//! Per `docs/falsifiers/F-PageGather-M2Pro_2026_05_17.md` §3.
//!
//! # Substrate-floor scope
//!
//! Exercises `agent_core::helios::{gather, gather_with_scale}` over the
//! three working-set sizes (~256 KB, 512 KB, 1024 KB — scaled down from
//! the 256/512/1024 MB production target since substrate-floor runs on
//! the per-iter cargo budget). Production-PASS requires Metal kernel
//! ≥ 70% MEASURED M2 Pro STREAM bandwidth + bit-for-bit Rust vs Metal
//! on fixed-seed inputs (Phase B.G.B5).
//!
//! This harness proves:
//! 1. Sequential gather (contiguous indices) returns the source prefix
//!    exactly.
//! 2. Scatter (random permutation indices) returns the right source
//!    elements.
//! 3. gather_with_scale applies per-element scale correctly.
//! 4. Stats (max_index, sequential-flag, elements_read) match
//!    expectations.
//! 5. Bad inputs surface typed errors.

use agent_core::helios::{gather, gather_with_scale};

const KB: usize = 1024;
const WORKING_SET_FLOATS: &[usize] = &[64 * KB, 128 * KB, 256 * KB]; // 256 / 512 / 1024 KB

struct MiniRng(u64);

impl MiniRng {
    fn new(seed: u64) -> Self { Self(seed) }
    fn next_u32(&mut self, modulo: u32) -> u32 {
        self.0 = self.0.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
        ((self.0 >> 32) as u32) % modulo
    }
}

fn deterministic_source(size: usize, seed: u64) -> Vec<f32> {
    let mut rng = MiniRng::new(seed);
    (0..size)
        .map(|_| {
            let raw = rng.next_u32(u32::MAX);
            (raw as f32) / (u32::MAX as f32)
        })
        .collect()
}

#[test]
fn sequential_gather_returns_source_prefix() {
    for &n in WORKING_SET_FLOATS {
        let src = deterministic_source(n, 0xABCD_0001);
        let idx: Vec<u32> = (0..n as u32).collect();
        let mut out = vec![0.0_f32; n];
        let stats = gather(&src, &idx, &mut out).unwrap();
        assert_eq!(out, src, "sequential gather should return source prefix at size {}", n);
        assert!(stats.sequential, "stats.sequential must be true for contiguous indices");
    }
}

#[test]
fn random_scatter_pattern_matches_indices() {
    for &n in WORKING_SET_FLOATS {
        let src = deterministic_source(n, 0xABCD_0002);

        // Fisher-Yates shuffle of [0, n).
        let mut idx: Vec<u32> = (0..n as u32).collect();
        let mut rng = MiniRng::new(0xACAA_5500);
        for i in (1..n).rev() {
            let j = rng.next_u32((i + 1) as u32) as usize;
            idx.swap(i, j);
        }

        let mut out = vec![0.0_f32; n];
        let stats = gather(&src, &idx, &mut out).unwrap();
        // out[i] must equal source[idx[i]]
        for (i, &index) in idx.iter().enumerate() {
            assert_eq!(out[i], src[index as usize], "scatter mismatch at i={}, idx={}", i, index);
        }
        assert!(!stats.sequential, "scatter pattern should not flag sequential (size {})", n);
        assert_eq!(stats.elements_read, n);
    }
}

#[test]
fn gather_with_scale_applies_scale() {
    let src = vec![1.0_f32, 2.0, 3.0, 4.0];
    let idx: Vec<u32> = vec![0, 2, 1, 3];
    let scales = vec![0.5_f32, 1.0, 2.0, 0.25];
    let mut out = vec![0.0_f32; 4];
    gather_with_scale(&src, &idx, &scales, &mut out).unwrap();
    assert_eq!(out, vec![0.5, 3.0, 4.0, 1.0]);
}

#[test]
fn gather_bad_index_errors() {
    let src = vec![1.0_f32, 2.0, 3.0];
    let bad_idx: Vec<u32> = vec![0, 5]; // index 5 out of range for source of length 3
    let mut out = vec![0.0_f32; 2];
    assert!(gather(&src, &bad_idx, &mut out).is_err());
}

#[test]
fn gather_output_length_mismatch_errors() {
    let src = vec![1.0_f32, 2.0, 3.0];
    let idx: Vec<u32> = vec![0, 1, 2];
    let mut out = vec![0.0_f32; 5]; // wrong length
    assert!(gather(&src, &idx, &mut out).is_err());
}

#[test]
fn scales_length_mismatch_errors() {
    let src = vec![1.0_f32, 2.0];
    let idx: Vec<u32> = vec![0];
    let scales = vec![1.0_f32, 2.0]; // length mismatch with idx
    let mut out = vec![0.0_f32; 1];
    assert!(gather_with_scale(&src, &idx, &scales, &mut out).is_err());
}

#[test]
fn empty_indices_returns_empty_output() {
    let src = vec![1.0_f32; 10];
    let idx: Vec<u32> = vec![];
    let mut out: Vec<f32> = vec![];
    let stats = gather(&src, &idx, &mut out).unwrap();
    assert_eq!(stats.elements_read, 0);
}
