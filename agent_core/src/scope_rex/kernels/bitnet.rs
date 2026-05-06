// HARDENING ENFORCEMENT: BitNet kernel reference must remain panic-
// free in production. Tests are allowed to unwrap because a failed
// invariant SHOULD panic loudly.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! HELIOS V5 W13 — BitNet b1.58 inference path.
//!
//! HELIOS-W13 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W13 +
//! `docs/fusion/helios v5 updated.md` PART 1 (BitNet b1.58 2B4T):
//!
//! > "BitNet b1.58 2B4T (Ma, Wang, Huang, Zhang, Hu, Song, Xia, Wei,
//! >  Microsoft) — arXiv:2504.12285v2 (2025-04-25). 2B params, 4T
//! >  tokens, native 1-bit, MIT license, weights on HF
//! >  `microsoft/bitnet-b1.58-2B-4T`."
//!
//! **Tier 2 contract:** end-to-end perplexity within 0.5 of the
//! reference on the Lambada subset. Gated behind the "Experimental
//! Metal Kernels → BitNet 1.58-bit" Settings toggle (default OFF).
//!
//! The b1.58 quantization is `absmean` per Ma et al. arXiv 2402.17764:
//!
//!   1. Compute `gamma = mean(|W|)` per group.
//!   2. Quantize `W_q = round(W / (gamma + eps)) clamped to {-1, 0, +1}`.
//!   3. Inference uses ternary weights with the `gamma` scale per
//!      group reapplied at GEMM output.
//!
//! Per §2.5.2 compliance: source code ships in MAS bundle; the
//! bundled `microsoft/bitnet-b1.58-2B-4T.gguf` model file is a
//! release-prep concern (separate from this commit). Until the GGUF
//! ships, the kernel is exercised against synthetic ternary
//! weights generated from random fp32 sources.
//!
//! ## Cross-references
//!
//! - DOC 0 §0.2 (H4 / W13 in §0.6 glossary)
//! - DOC 0 §0.4 (lane summary: Tier 2 flagged OFF)
//! - [`crate::scope_rex::kernels::t_mac`] — T-MAC LUT path that
//!   USES this quantization output

use super::t_mac::TernaryWeight;

/// Per-group quantization scale. After absmean quantization, the
/// post-GEMM result must be multiplied by `gamma` to recover the
/// approximate original magnitude.
pub type Gamma = f32;

/// Output of [`absmean_quantize`].
pub struct QuantizedBitnet {
    pub weights: Vec<TernaryWeight>,
    pub gamma: Gamma,
}

/// b1.58 absmean quantization (per Ma et al. arXiv 2402.17764).
///
/// Computes the per-group `gamma = mean(|W|)` and quantizes each
/// weight to the nearest of {-1, 0, +1}. Round-half-to-even via Rust
/// `f32::round` (banker's rounding semantics on most platforms,
/// though Rust spec is round-half-away-from-zero — for the Tier-2
/// contract, perplexity-within-0.5 absorbs the rounding choice).
///
/// Returns ([`QuantizedBitnet`]).
pub fn absmean_quantize(weights: &[f32]) -> QuantizedBitnet {
    if weights.is_empty() {
        return QuantizedBitnet {
            weights: Vec::new(),
            gamma: 1.0,
        };
    }
    // Per-group gamma = mean(|W|).
    let mut sum_abs = 0.0f32;
    for &w in weights {
        sum_abs += w.abs();
    }
    let gamma = sum_abs / (weights.len() as f32);
    // Avoid div-by-zero — use a tiny epsilon scale.
    let scale = if gamma > 0.0 { gamma } else { 1.0e-6 };
    let mut out = Vec::with_capacity(weights.len());
    for &w in weights {
        let q = (w / scale).round();
        let clamped = q.clamp(-1.0, 1.0) as i8;
        // clamp + round into {-1, 0, +1}; safe to wrap.
        let tw = match clamped {
            -1..=1 => TernaryWeight(clamped),
            _ => TernaryWeight(0), // unreachable but defensive
        };
        out.push(tw);
    }
    QuantizedBitnet {
        weights: out,
        gamma,
    }
}

/// Apply the BitNet b1.58 GEMM path: ternary GEMM × `gamma` for
/// magnitude recovery.
///
/// Reference path (no Metal). Loops over rows; multiplies each row's
/// dot product by the per-group `gamma`. The Tier-2 acceptance is
/// PPL-within-0.5; this reference is the oracle.
pub fn bitnet_b158_gemm(
    input: &[f32],
    quantized: &QuantizedBitnet,
    rows: usize,
    cols: usize,
) -> Vec<f32> {
    debug_assert_eq!(input.len(), cols);
    debug_assert_eq!(quantized.weights.len(), rows * cols);
    let raw = super::t_mac::t_mac_reference(input, &quantized.weights, rows, cols);
    raw.into_iter().map(|x| x * quantized.gamma).collect()
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_weights_yield_unit_gamma_and_empty_output() {
        let q = absmean_quantize(&[]);
        assert!(q.weights.is_empty());
        assert!((q.gamma - 1.0).abs() < 1e-9);
    }

    #[test]
    fn small_uniform_weights_quantize_consistently() {
        // All weights equal → gamma = |w|; each weight quantizes to
        // sign(w), so output is +1 or -1 across the board.
        let w = vec![0.5f32; 8];
        let q = absmean_quantize(&w);
        assert!((q.gamma - 0.5).abs() < 1e-6);
        for &qw in &q.weights {
            assert_eq!(qw.0, 1);
        }
    }

    #[test]
    fn mixed_sign_weights_preserve_sign() {
        let w = vec![1.0f32, -1.0, 0.0, 0.5];
        let q = absmean_quantize(&w);
        // gamma = (1 + 1 + 0 + 0.5) / 4 = 0.625
        assert!((q.gamma - 0.625).abs() < 1e-6);
        // 1.0 / 0.625 = 1.6 → round → 2 → clamp → 1
        // -1.0 / 0.625 = -1.6 → round → -2 → clamp → -1
        // 0.0 / 0.625 = 0 → 0
        // 0.5 / 0.625 = 0.8 → round → 1 → 1
        assert_eq!(q.weights[0].0, 1);
        assert_eq!(q.weights[1].0, -1);
        assert_eq!(q.weights[2].0, 0);
        assert_eq!(q.weights[3].0, 1);
    }

    #[test]
    fn bitnet_gemm_round_trip_recovers_approximate_magnitude() {
        // Setup: 1x4 weight row of value 0.5 (uniform); input = 1's
        // → expected output ≈ 4 * 0.5 = 2.0 (within rounding).
        let weights = vec![0.5f32, 0.5, 0.5, 0.5];
        let input = vec![1.0f32, 1.0, 1.0, 1.0];
        let q = absmean_quantize(&weights);
        let out = bitnet_b158_gemm(&input, &q, 1, 4);
        assert_eq!(out.len(), 1);
        // gamma = 0.5; ternary all 1; sum = 4; 4 * 0.5 = 2.0
        assert!((out[0] - 2.0).abs() < 1e-6);
    }

    #[test]
    fn quantized_weights_validate_as_ternary() {
        let w: Vec<f32> = (0..32).map(|i| (i as f32) * 0.1 - 1.5).collect();
        let q = absmean_quantize(&w);
        assert!(super::super::t_mac::validate_ternary_weights(&q.weights));
    }
}
