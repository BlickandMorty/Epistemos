// HARDENING ENFORCEMENT: retrieval kernels must remain panic-free
// in production. Tests are allowed to unwrap because a failed
// invariant SHOULD panic loudly.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! HELIOS V5 W15 — Modern Hopfield retrieval at chat boundary.
//!
//! HELIOS-W15 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W15 +
//! `docs/fusion/helios v5 updated.md` PART 1 (Modern Hopfield):
//!
//! > "Modern Hopfield 'Hopfield Networks is All You Need' (Ramsauer
//! >  et al., 16 authors) — arXiv:2008.02217v3 (2021-04-28), ICLR
//! >  2021. Exponential capacity, equivalence to attention."
//!
//! **Tier 2 contract:** retrieval recall ≥ 0.95 on noised-pattern
//! recall task. Gated behind "Verified Research Mode → Hopfield
//! retrieval" Settings toggle (default OFF).
//!
//! ## Modern Hopfield update rule
//!
//! Given stored patterns matrix `Y ∈ ℝ^{N × d}` (N patterns, dim
//! d) and a query vector `q ∈ ℝ^d`, the Modern Hopfield update
//! produces a softmax-weighted sum over patterns:
//!
//! ```text
//! q' = Y^T · softmax(β · Y · q)
//! ```
//!
//! where β > 0 is the inverse temperature. Per Ramsauer et al.,
//! single update is sufficient for storage capacity ≈ 2^(d/2)
//! patterns.
//!
//! ## Cross-references
//!
//! - DOC 0 §0.2 (H17 = Modern Hopfield associative recall)
//! - DOC 0 §0.4 (lane summary: Tier 2 flagged OFF, advisory in L1)
//! - [`crate::scope_rex::metal::softmax`] — softmax used by the
//!   update rule

use crate::scope_rex::metal::softmax::reference_softmax;

/// HELIOS V5 W15 — Modern Hopfield single-step update.
///
/// Returns a vector in `ℝ^d` that is a softmax-weighted convex
/// combination of stored patterns. Determined entirely by `(stored,
/// query, beta)` — pure function.
///
/// Panics in DEBUG only on shape mismatch. Production paths
/// validate at boundaries.
pub fn modern_hopfield_update(
    stored: &[Vec<f32>],
    query: &[f32],
    beta: f32,
) -> Vec<f32> {
    if stored.is_empty() {
        return Vec::new();
    }
    let d = query.len();
    debug_assert!(stored.iter().all(|p| p.len() == d), "patterns must match query dim");

    // Step 1: dot products `s_i = β · (Y · q)_i`.
    let scores: Vec<f32> = stored
        .iter()
        .map(|p| {
            let mut acc = 0.0f32;
            for i in 0..d {
                acc += p[i] * query[i];
            }
            acc * beta
        })
        .collect();

    // Step 2: softmax over scores.
    let weights = reference_softmax(&scores);

    // Step 3: weighted sum `q' = Σ_i weights_i · pattern_i`.
    let mut out = vec![0.0f32; d];
    for (i, p) in stored.iter().enumerate() {
        let w = weights[i];
        for j in 0..d {
            out[j] += w * p[j];
        }
    }
    out
}

/// Cosine similarity (for nearest-pattern recall checks).
pub fn cosine_similarity(a: &[f32], b: &[f32]) -> f32 {
    debug_assert_eq!(a.len(), b.len());
    let mut dot = 0.0f32;
    let mut na = 0.0f32;
    let mut nb = 0.0f32;
    for i in 0..a.len() {
        dot += a[i] * b[i];
        na += a[i] * a[i];
        nb += b[i] * b[i];
    }
    if na <= 0.0 || nb <= 0.0 {
        return 0.0;
    }
    dot / (na.sqrt() * nb.sqrt())
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn deterministic_random(seed: u64, n: usize) -> Vec<f32> {
        let mut state = seed.wrapping_mul(2862933555777941757).wrapping_add(3037000493);
        let mut out = Vec::with_capacity(n);
        for _ in 0..n {
            state = state.wrapping_mul(2862933555777941757).wrapping_add(3037000493);
            let f = ((state >> 8) & 0xFFFFFF) as f32 / 8_388_608.0 - 1.0;
            out.push(f);
        }
        out
    }

    #[test]
    fn empty_stored_patterns_yield_empty_output() {
        let q = vec![1.0_f32, 2.0, 3.0];
        let out = modern_hopfield_update(&[], &q, 1.0);
        assert!(out.is_empty());
    }

    #[test]
    fn single_pattern_returns_pattern_exactly() {
        // With one pattern, softmax([s]) = [1.0], so output = pattern.
        let pattern = vec![1.0_f32, 2.0, 3.0];
        let q = vec![0.5_f32, 0.5, 0.5];
        let out = modern_hopfield_update(&[pattern.clone()], &q, 1.0);
        assert_eq!(out, pattern);
    }

    #[test]
    fn high_beta_focuses_on_nearest_pattern() {
        // Two orthogonal patterns; query closest to first; large β
        // → output should be near pattern_0.
        let p0 = vec![1.0_f32, 0.0];
        let p1 = vec![0.0_f32, 1.0];
        let q = vec![0.95_f32, 0.05]; // very close to p0
        let out = modern_hopfield_update(&[p0.clone(), p1.clone()], &q, 100.0);
        // Output should be ≈ p0
        assert!((out[0] - 1.0).abs() < 0.05, "out[0]={}", out[0]);
        assert!(out[1].abs() < 0.05, "out[1]={}", out[1]);
    }

    #[test]
    fn low_beta_yields_uniform_average() {
        // β → 0: softmax becomes uniform; output → mean of patterns.
        let p0 = vec![1.0_f32, 0.0];
        let p1 = vec![0.0_f32, 1.0];
        let q = vec![0.5_f32, 0.5];
        let out = modern_hopfield_update(&[p0, p1], &q, 0.0);
        assert!((out[0] - 0.5).abs() < 1e-5);
        assert!((out[1] - 0.5).abs() < 1e-5);
    }

    fn deterministic_bipolar(seed: u64, n: usize) -> Vec<f32> {
        // Canonical Modern Hopfield input: bipolar {-1, +1}.
        // Capacity 2^(d/2) per Ramsauer et al. holds for bipolar.
        let mut state = seed.wrapping_mul(2862933555777941757).wrapping_add(3037000493);
        let mut out = Vec::with_capacity(n);
        for _ in 0..n {
            state = state.wrapping_mul(2862933555777941757).wrapping_add(3037000493);
            out.push(if (state & 1) == 0 { 1.0 } else { -1.0 });
        }
        out
    }

    #[test]
    fn associative_recall_under_partial_noise_recovers_target() {
        // Per W15 acceptance: "store N patterns of dim d in modern
        // Hopfield; retrieve with noise; require strong recall."
        // Canonical bipolar setup per Ramsauer et al. arXiv:2008.02217:
        // patterns ∈ {-1, +1}^d, N << 2^(d/2). Recall ≥ 0.95 cosine
        // sim under 25% bit-flip noise with β = 1.
        let d = 64;
        let n_patterns = 16; // well under 2^(d/2) = 2^32
        let mut patterns = Vec::with_capacity(n_patterns);
        for i in 0..n_patterns {
            patterns.push(deterministic_bipolar((i as u64) + 1, d));
        }
        let target = patterns[0].clone();
        let mut noised = target.clone();
        // Flip 25% of dims (every 4th).
        for j in (0..d).step_by(4) {
            noised[j] = -noised[j];
        }
        let recovered = modern_hopfield_update(&patterns, &noised, 1.0);
        let sim = cosine_similarity(&recovered, &target);
        assert!(
            sim > 0.95,
            "bipolar Hopfield recall under 25% noise = {} should exceed 0.95",
            sim
        );
    }

    #[test]
    fn associative_recall_with_30_percent_noise_recovers_better_than_baseline() {
        // Stress test: 30% bit-flip noise. Recall expected to
        // exceed cosine sim of the noised input itself.
        let d = 32;
        let n_patterns = 8;
        let mut patterns = Vec::with_capacity(n_patterns);
        for i in 0..n_patterns {
            patterns.push(deterministic_bipolar((i as u64) + 1, d));
        }
        let target = patterns[0].clone();
        let mut noised = target.clone();
        // Flip every 3rd dim ≈ 33% noise.
        for j in (0..d).step_by(3) {
            noised[j] = -noised[j];
        }
        let baseline = cosine_similarity(&noised, &target);
        let recovered = modern_hopfield_update(&patterns, &noised, 1.0);
        let sim = cosine_similarity(&recovered, &target);
        assert!(
            sim > baseline,
            "Hopfield recall {} should exceed baseline noised-similarity {}",
            sim,
            baseline
        );
    }

    #[test]
    fn cosine_similarity_handles_orthogonal_pair() {
        let a = vec![1.0_f32, 0.0];
        let b = vec![0.0_f32, 1.0];
        let sim = cosine_similarity(&a, &b);
        assert!(sim.abs() < 1e-6);
    }

    #[test]
    fn cosine_similarity_handles_parallel_pair() {
        let a = vec![1.0_f32, 1.0];
        let b = vec![2.0_f32, 2.0];
        let sim = cosine_similarity(&a, &b);
        assert!((sim - 1.0).abs() < 1e-6);
    }

    #[test]
    fn cosine_similarity_handles_zero_vector_safely() {
        let a = vec![0.0_f32, 0.0];
        let b = vec![1.0_f32, 1.0];
        let sim = cosine_similarity(&a, &b);
        assert_eq!(sim, 0.0);
    }
}
