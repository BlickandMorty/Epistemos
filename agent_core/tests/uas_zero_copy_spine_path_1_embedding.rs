//! F-UAS-ZeroCopy-Spine — path 1 substrate-floor integration test.
//!
//! Per `docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md` §2.1 row 1:
//! "Embedding query → search index" must run with `copy_count == 0`.
//!
//! # Substrate-floor scope
//!
//! This test exercises the iter-32 `copy_counter` infrastructure against
//! a mock embedding-to-search function. The mock demonstrates the API
//! contract (caller-allocated output buffer + slice-view scoring) that
//! production `epistemos-shadow::vector_index` is expected to honor on
//! the hot path. Production wire-up to the real vector index lands when
//! `epistemos-shadow` is added as an `agent_core` dev-dep OR when the
//! test moves to the `epistemos-shadow` crate's own test suite.

use agent_core::uas::copy_counter::{
    self, CopyStats, CountingAllocator,
};

#[global_allocator]
static GLOBAL: CountingAllocator = CountingAllocator::new();

/// Mock production hot-path: rank `corpus` rows by inner-product with
/// `query`; write top-K indices into the caller-allocated `output`. Zero
/// allocations on the hot path; zero copies of `query` or `corpus`.
///
/// The signature is the contract: `&[f32]` for inputs (slice borrows),
/// `&mut [(usize, f32)]` for output (caller-owned). Production
/// `epistemos-shadow::vector_index::top_k` is expected to honor this
/// shape.
fn mock_embed_top_k(
    query: &[f32],
    corpus: &[Vec<f32>],
    output: &mut [(usize, f32)],
) {
    debug_assert!(corpus.iter().all(|row| row.len() == query.len()));

    let k = output.len();
    // Initial fill: first K rows.
    for (out_idx, slot) in output.iter_mut().enumerate().take(k.min(corpus.len())) {
        let score = inner_product(query, &corpus[out_idx]);
        *slot = (out_idx, score);
    }
    // Maintain max-heap-by-min-score: insert any remaining row if score
    // beats current minimum. Substrate-floor uses linear scan; production
    // would use a heap.
    for (row_idx, row) in corpus.iter().enumerate().skip(k) {
        let score = inner_product(query, row);
        // Find the slot with the smallest score.
        let mut min_idx = 0;
        let mut min_score = output[0].1;
        for (i, slot) in output.iter().enumerate().skip(1) {
            if slot.1 < min_score {
                min_idx = i;
                min_score = slot.1;
            }
        }
        if score > min_score {
            output[min_idx] = (row_idx, score);
        }
    }
}

#[inline]
fn inner_product(a: &[f32], b: &[f32]) -> f32 {
    debug_assert_eq!(a.len(), b.len());
    let mut acc = 0.0_f32;
    for (x, y) in a.iter().zip(b.iter()) {
        acc += x * y;
    }
    acc
}

/// Substrate-floor proof: with caller-allocated buffers, the hot-path
/// search is zero-copy AND zero-alloc.
///
/// Warmup phase runs the function once (which triggers Metal-shader-like
/// kernel-cache priming if any). Then counters are reset and the hot-path
/// runs `N = 50` times under `with_tracking`. The final assertion: 0
/// copies + 0 allocations across all 50 iterations.
#[test]
fn embedding_query_to_search_index_is_zero_copy_zero_alloc() {
    // Allocate everything OUTSIDE the timing loop.
    let query: Vec<f32> = (0..128).map(|i| (i as f32) / 128.0).collect();
    let corpus: Vec<Vec<f32>> = (0..200)
        .map(|j| (0..128).map(|i| ((i * j) as f32) / 8192.0).collect())
        .collect();
    let mut output: Vec<(usize, f32)> = vec![(0, 0.0); 5];

    // Warmup — exercises caches; allocations here don't count.
    for _ in 0..10 {
        mock_embed_top_k(&query, &corpus, &mut output);
    }

    // Hot path.
    let (_, stats) = copy_counter::with_tracking(|| {
        for _ in 0..50 {
            mock_embed_top_k(&query, &corpus, &mut output);
        }
    });

    assert_eq!(
        stats.copy_count, 0,
        "F-UAS-ZeroCopy-Spine path 1 FAILED: copy_count = {} on embedding query → search index hot path",
        stats.copy_count
    );
    assert_eq!(
        stats.alloc_count, 0,
        "F-UAS-ZeroCopy-Spine path 1 FAILED: alloc_count = {} (steady-state) — bytes = {}",
        stats.alloc_count, stats.bytes_allocated
    );

    assert!(stats.is_zero_copy_and_zero_alloc(), "stats predicate must agree with assertions");
}

/// Confirms top-K result is correct — proves the mock actually computes
/// something useful and the assertions above aren't passing on dead code.
#[test]
fn mock_top_k_returns_correct_max_for_uniform_query() {
    let query: Vec<f32> = vec![1.0; 8];
    let corpus: Vec<Vec<f32>> = vec![
        vec![1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], // ip = 1
        vec![1.0; 8],                                  // ip = 8 (max)
        vec![0.5; 8],                                  // ip = 4
        vec![1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0], // ip = 4
    ];
    let mut top1 = vec![(0_usize, 0.0_f32); 1];
    mock_embed_top_k(&query, &corpus, &mut top1);
    assert_eq!(top1[0].0, 1, "row index 1 (all-ones) is the top-1");
    assert!((top1[0].1 - 8.0).abs() < 1e-6);
}

/// CopyStats sanity: a deliberate copy on the hot path is detected.
/// This proves the harness CAN fail — if `track_copy()` is unreachable
/// in the substrate, the gate is meaningless.
#[test]
fn deliberate_track_copy_is_detected() {
    let stats = copy_counter::with_tracking(|| {
        copy_counter::track_copy();
        copy_counter::track_copy();
    })
    .1;
    assert_eq!(stats.copy_count, 2);
    assert!(!stats.is_zero_copy_and_zero_alloc());
}

/// CopyStats sanity: a deliberate allocation is detected when
/// CountingAllocator is the global allocator.
#[test]
fn deliberate_allocation_is_detected_under_counting_allocator() {
    let stats = copy_counter::with_tracking(|| {
        let _v: Vec<u8> = Vec::with_capacity(64);
        // The capacity allocation increments ALLOC_COUNT via
        // CountingAllocator declared at the top of this file.
    })
    .1;
    assert!(
        stats.alloc_count >= 1,
        "Expected at least 1 allocation, got {} — CountingAllocator may not be wired",
        stats.alloc_count
    );
    assert!(stats.bytes_allocated >= 64);
}
