//! F-UAS-ZeroCopy-Spine — path 2 substrate-floor integration test.
//!
//! Per `docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md` §2.1 row 2:
//! "Logit stream → AnswerPacket" must run with `copy_count == 0`.
//!
//! # Substrate-floor scope
//!
//! The production hot path is one logit-array → one next-token decision
//! per generation step. The argmax + (optional) top-k sampling must run
//! zero-copy + zero-alloc per step. AnswerPacket emission is per-
//! generation (not per-token); its zero-copy property is tested
//! separately.
//!
//! This test exercises a mock argmax + top-K helper against the iter-32
//! `copy_counter` infrastructure with `#[global_allocator]
//! CountingAllocator`.

use agent_core::uas::copy_counter::{self, CountingAllocator};
use std::sync::Mutex;

#[global_allocator]
static GLOBAL: CountingAllocator = CountingAllocator::new();

/// File-local serialization mutex. The CountingAllocator counters are
/// process-wide atomics; parallel tests' setup-phase allocations would
/// cross-contaminate the alloc_count assertions if the entire test body
/// is not serialized. Every test in this file takes this mutex on entry.
static FILE_SERIAL: Mutex<()> = Mutex::new(());

/// Mock production hot path: argmax over a logit array. Zero allocations,
/// zero copies of the logits.
#[inline]
fn mock_argmax_logits(logits: &[f32]) -> usize {
    debug_assert!(!logits.is_empty());
    let mut best_idx = 0;
    let mut best_score = logits[0];
    for (i, &score) in logits.iter().enumerate().skip(1) {
        if score > best_score {
            best_idx = i;
            best_score = score;
        }
    }
    best_idx
}

/// Mock production hot path variant: top-K argmax, caller-allocated
/// output. Used when sampling instead of greedy decoding.
#[inline]
fn mock_top_k_logits(logits: &[f32], output: &mut [(usize, f32)]) {
    let k = output.len();
    // Fill with first K.
    for (i, slot) in output.iter_mut().enumerate().take(k.min(logits.len())) {
        *slot = (i, logits[i]);
    }
    // Walk the rest, displacing the slot with the smallest score whenever
    // a larger score is found.
    for (idx, &score) in logits.iter().enumerate().skip(k) {
        let mut min_slot = 0;
        let mut min_score = output[0].1;
        for (i, slot) in output.iter().enumerate().skip(1) {
            if slot.1 < min_score {
                min_slot = i;
                min_score = slot.1;
            }
        }
        if score > min_score {
            output[min_slot] = (idx, score);
        }
    }
}

/// 100 generation-step simulation with 152k-vocab logits (Qwen-3 8B
/// size). Hot path runs zero-copy + zero-alloc.
#[test]
fn logit_stream_argmax_is_zero_copy_zero_alloc() {
    let _guard = FILE_SERIAL.lock().unwrap_or_else(|p| p.into_inner());
    // 152k floats; pre-allocate once outside the loop.
    let mut logits: Vec<f32> = vec![0.0; 152_064];
    // Initialize with a deterministic pattern; argmax target at idx 42_000.
    for (i, slot) in logits.iter_mut().enumerate() {
        *slot = (i as f32).sin() * 0.5;
    }
    logits[42_000] = 100.0; // unambiguous max

    // Warmup.
    for _ in 0..10 {
        let _ = mock_argmax_logits(&logits);
    }

    let (last_token, stats) = copy_counter::with_tracking(|| {
        let mut last = 0;
        for _ in 0..100 {
            last = mock_argmax_logits(&logits);
        }
        last
    });

    assert_eq!(last_token, 42_000, "argmax must return the planted maximum index");
    assert_eq!(
        stats.copy_count, 0,
        "F-UAS-ZeroCopy-Spine path 2 FAILED: copy_count = {} on argmax hot path",
        stats.copy_count
    );
    assert_eq!(
        stats.alloc_count, 0,
        "F-UAS-ZeroCopy-Spine path 2 FAILED: alloc_count = {} (steady-state)",
        stats.alloc_count
    );
}

/// Same hot path under top-K sampling — caller-allocated output.
#[test]
fn logit_stream_top_k_is_zero_copy_zero_alloc() {
    let _guard = FILE_SERIAL.lock().unwrap_or_else(|p| p.into_inner());
    let logits: Vec<f32> = (0..152_064).map(|i| (i as f32).cos() * 10.0).collect();
    let mut top_k_output = vec![(0_usize, 0.0_f32); 8];

    // Warmup.
    for _ in 0..5 {
        mock_top_k_logits(&logits, &mut top_k_output);
    }

    let (_, stats) = copy_counter::with_tracking(|| {
        for _ in 0..50 {
            mock_top_k_logits(&logits, &mut top_k_output);
        }
    });

    assert_eq!(stats.copy_count, 0, "top-K must be zero-copy");
    assert_eq!(stats.alloc_count, 0, "top-K must be zero-alloc");
}

/// Correctness sanity — argmax actually finds the maximum.
#[test]
fn mock_argmax_correctness() {
    let _guard = FILE_SERIAL.lock().unwrap_or_else(|p| p.into_inner());
    let logits = vec![1.0, -2.0, 3.0, 0.5, -1.5];
    assert_eq!(mock_argmax_logits(&logits), 2);
}

/// Correctness sanity — top-K finds the largest 3 scores.
#[test]
fn mock_top_k_correctness() {
    let _guard = FILE_SERIAL.lock().unwrap_or_else(|p| p.into_inner());
    let logits = vec![1.0, 5.0, 2.0, 8.0, 3.0, 4.0, 0.0];
    let mut top3 = vec![(0_usize, 0.0_f32); 3];
    mock_top_k_logits(&logits, &mut top3);
    let mut indices: Vec<usize> = top3.iter().map(|(i, _)| *i).collect();
    indices.sort();
    assert_eq!(indices, vec![1, 3, 5], "top-3 indices must be {{1, 3, 5}} for scores {{5, 8, 4}}");
}
