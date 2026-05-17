//! Source:
//! - `docs/fusion/jordan's research/ternary kernel.md` §"Fused RMSNorm + ternary
//!   projection" — "Once the base projection works, fuse one cheap normalization
//!   stage before or after projection if profiling says it helps."
//! - Zhang & Sennrich, "Root Mean Square Layer Normalization", arXiv:1910.07467
//!   — canonical RMSNorm: `y_i = (x_i / sqrt(mean(x^2) + eps)) * g_i`. Used in
//!   LLaMA, Qwen, BitNet b1.58, and every modern ternary-friendly transformer.
//!
//! # Wave J1 kernel #4 — Fused RMSNorm + ternary projection
//!
//! Combines RMSNorm with the block-scaled ternary GEMV from [`super::gemv`]
//! into a single call. For the substrate floor we pre-normalize the input
//! and forward to the existing GEMV — internally two passes but the caller
//! sees one fused API and one bounds-check surface. Real Metal fusion (one
//! kernel walking the input once and emitting normalized values on the fly
//! into the GEMV accumulator) is deferred to the dispatch wire-in pass.
//!
//! The doctrine deliberately hedges ("if profiling says it helps") on
//! whether fusion is the win — the substrate-floor job is to establish the
//! API so the dispatch wire-in pass can swap in a Metal kernel without
//! changing any caller code.

use super::gemv::{gemv_block_scaled, GemvBlock, GemvError};

#[derive(Clone, Debug, PartialEq)]
pub enum FusedRmsnormError {
    /// `gain.len()` did not match `input.len()`.
    GainLengthMismatch { input_len: usize, gain_len: usize },
    /// Input was empty. RMSNorm of a 0-element vector is undefined; the
    /// kernel rejects rather than coerce to identity.
    EmptyInput,
    /// `eps` was non-positive. RMSNorm needs a strictly positive
    /// floor under the sqrt for numerical safety on all-zero inputs.
    NonPositiveEps { eps: f32 },
    /// The underlying ternary GEMV rejected the call. Forwarded verbatim.
    Gemv(GemvError),
}

impl From<GemvError> for FusedRmsnormError {
    fn from(err: GemvError) -> Self {
        FusedRmsnormError::Gemv(err)
    }
}

/// Compute RMSNorm in-place into `out`. `out` must already have
/// `input.len()` slots allocated by the caller (the kernel pre-allocates
/// a `Vec` if a fused-API call needs the buffer).
pub fn rmsnorm_into(
    input: &[f32],
    gain: &[f32],
    eps: f32,
    out: &mut [f32],
) -> Result<(), FusedRmsnormError> {
    if input.is_empty() {
        return Err(FusedRmsnormError::EmptyInput);
    }
    if gain.len() != input.len() {
        return Err(FusedRmsnormError::GainLengthMismatch {
            input_len: input.len(),
            gain_len: gain.len(),
        });
    }
    if eps <= 0.0 {
        return Err(FusedRmsnormError::NonPositiveEps { eps });
    }
    let mean_sq: f32 =
        input.iter().map(|x| x * x).sum::<f32>() / (input.len() as f32);
    let inv_rms = (mean_sq + eps).sqrt().recip();
    for (i, ((&x, &g), o)) in input.iter().zip(gain.iter()).zip(out.iter_mut()).enumerate() {
        let _ = i;
        *o = x * inv_rms * g;
    }
    Ok(())
}

/// Root-mean-square of `input` with safety-floor `eps`:
/// `sqrt(mean(x²) + eps)`. The denominator the RMSNorm scaling
/// factor `inv_rms` is built from. Returns `None` on empty input or
/// non-positive eps.
pub fn compute_rms(input: &[f32], eps: f32) -> Option<f32> {
    if input.is_empty() {
        return None;
    }
    if !eps.is_finite() || eps <= 0.0 {
        return None;
    }
    let mean_sq: f32 = input.iter().map(|x| x * x).sum::<f32>() / (input.len() as f32);
    Some((mean_sq + eps).sqrt())
}

/// Verify that `out` has root-mean-square magnitude close to
/// `expected_rms` within `tol`. The canonical "is this output
/// correctly RMS-normalized?" correctness check. Returns
/// `Ok(actual_rms)` on success or the computed RMS in
/// `Err` otherwise. Substrate-floor caller-supplied tolerance —
/// fp32-pipeline tests typically use 1e-4.
pub fn verify_rms_normalized(
    out: &[f32],
    expected_rms: f32,
    tol: f32,
) -> Result<f32, f32> {
    if out.is_empty() {
        return Err(0.0);
    }
    let mean_sq: f32 = out.iter().map(|x| x * x).sum::<f32>() / (out.len() as f32);
    let actual = mean_sq.sqrt();
    if (actual - expected_rms).abs() < tol {
        Ok(actual)
    } else {
        Err(actual)
    }
}

/// Fused RMSNorm + block-scaled ternary GEMV.
///
/// `output = ternary_gemv(weights, RMSNorm(input, gain, eps))`
///
/// Internally allocates a normalized-input scratch buffer of size
/// `input.len()`; future Metal fusion will eliminate this allocation.
pub fn fused_rmsnorm_gemv(
    weights: &[Vec<GemvBlock>],
    input: &[f32],
    gain: &[f32],
    eps: f32,
    output: &mut [f32],
) -> Result<(), FusedRmsnormError> {
    let mut normalized = vec![0.0_f32; input.len()];
    rmsnorm_into(input, gain, eps, &mut normalized)?;
    gemv_block_scaled(weights, &normalized, output)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::research::ternary::gemv::GEMV_BLOCK_TRITS;
    use crate::research::ternary::pack::pack_trits_u32;
    use crate::research::ternary::trit::Trit;

    fn block(trits: &[Trit], scale: f32) -> GemvBlock {
        let nonzero_count =
            trits.iter().filter(|&&t| t != Trit::Zero).count() as u8;
        GemvBlock {
            packed: pack_trits_u32(trits).unwrap(),
            scale,
            nonzero_count,
        }
    }

    #[test]
    fn rmsnorm_unit_gain_normalizes_to_unit_rms() {
        let input = vec![3.0_f32, 4.0_f32];
        let gain = vec![1.0_f32, 1.0_f32];
        let mut out = vec![0.0_f32; 2];
        rmsnorm_into(&input, &gain, 1e-6, &mut out).unwrap();
        let rms: f32 = (out.iter().map(|y| y * y).sum::<f32>() / 2.0).sqrt();
        assert!((rms - 1.0).abs() < 1e-3);
    }

    #[test]
    fn rmsnorm_scales_by_gain() {
        let input = vec![1.0_f32; 4];
        let gain = vec![2.0_f32, 2.0_f32, 2.0_f32, 2.0_f32];
        let mut out = vec![0.0_f32; 4];
        rmsnorm_into(&input, &gain, 1e-6, &mut out).unwrap();
        for &y in &out {
            assert!((y - 2.0).abs() < 1e-3);
        }
    }

    #[test]
    fn rmsnorm_all_zero_input_yields_zero_output() {
        let input = vec![0.0_f32; 4];
        let gain = vec![5.0_f32; 4];
        let mut out = vec![1.0_f32; 4];
        rmsnorm_into(&input, &gain, 1e-6, &mut out).unwrap();
        for &y in &out {
            assert_eq!(y, 0.0);
        }
    }

    #[test]
    fn rmsnorm_empty_input_errors() {
        let input: Vec<f32> = vec![];
        let gain: Vec<f32> = vec![];
        let mut out: Vec<f32> = vec![];
        let err = rmsnorm_into(&input, &gain, 1e-6, &mut out).unwrap_err();
        assert_eq!(err, FusedRmsnormError::EmptyInput);
    }

    #[test]
    fn rmsnorm_gain_mismatch_errors() {
        let input = vec![1.0_f32; 3];
        let gain = vec![1.0_f32; 2];
        let mut out = vec![0.0_f32; 3];
        let err = rmsnorm_into(&input, &gain, 1e-6, &mut out).unwrap_err();
        assert_eq!(
            err,
            FusedRmsnormError::GainLengthMismatch { input_len: 3, gain_len: 2 }
        );
    }

    #[test]
    fn rmsnorm_nonpositive_eps_errors() {
        let input = vec![1.0_f32; 2];
        let gain = vec![1.0_f32; 2];
        let mut out = vec![0.0_f32; 2];
        let err = rmsnorm_into(&input, &gain, 0.0, &mut out).unwrap_err();
        assert_eq!(err, FusedRmsnormError::NonPositiveEps { eps: 0.0 });
    }

    #[test]
    fn fused_path_matches_two_stage_reference() {
        let mut trits = [Trit::Zero; GEMV_BLOCK_TRITS];
        trits[0] = Trit::Pos;
        trits[1] = Trit::Neg;
        let weights = vec![vec![block(&trits, 1.0)]];
        let mut input = vec![0.0_f32; GEMV_BLOCK_TRITS];
        input[0] = 3.0;
        input[1] = 4.0;
        let gain: Vec<f32> = (0..GEMV_BLOCK_TRITS).map(|_| 1.0_f32).collect();

        let mut normalized = vec![0.0_f32; GEMV_BLOCK_TRITS];
        rmsnorm_into(&input, &gain, 1e-6, &mut normalized).unwrap();
        let mut two_stage = vec![0.0_f32; 1];
        crate::research::ternary::gemv::gemv_block_scaled(
            &weights,
            &normalized,
            &mut two_stage,
        )
        .unwrap();

        let mut fused = vec![0.0_f32; 1];
        fused_rmsnorm_gemv(&weights, &input, &gain, 1e-6, &mut fused).unwrap();

        assert!((fused[0] - two_stage[0]).abs() < 1e-6);
    }

    #[test]
    fn fused_forwards_gemv_error_on_shape_miss() {
        let mut trits = [Trit::Zero; GEMV_BLOCK_TRITS];
        trits[0] = Trit::Pos;
        let weights = vec![vec![block(&trits, 1.0)]];
        let short_input = vec![1.0_f32; GEMV_BLOCK_TRITS - 1];
        let gain: Vec<f32> = vec![1.0_f32; GEMV_BLOCK_TRITS - 1];
        let mut output = vec![0.0_f32; 1];
        let err = fused_rmsnorm_gemv(&weights, &short_input, &gain, 1e-6, &mut output)
            .unwrap_err();
        match err {
            FusedRmsnormError::Gemv(GemvError::InputColMismatch { .. }) => {}
            other => panic!("expected forwarded InputColMismatch, got {:?}", other),
        }
    }

    #[test]
    fn rmsnorm_eps_dominates_below_floor() {
        let input = vec![1e-10_f32; 4];
        let gain = vec![1.0_f32; 4];
        let mut out = vec![0.0_f32; 4];
        rmsnorm_into(&input, &gain, 1.0, &mut out).unwrap();
        for &y in &out {
            assert!(y.abs() < 1e-6);
        }
    }

    // ── compute_rms + verify_rms_normalized tests (iter 115) ────────────────

    fn approx(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn compute_rms_empty_returns_none() {
        assert!(compute_rms(&[], 1e-6).is_none());
    }

    #[test]
    fn compute_rms_non_positive_eps_returns_none() {
        assert!(compute_rms(&[1.0_f32], 0.0).is_none());
        assert!(compute_rms(&[1.0_f32], -0.1).is_none());
        assert!(compute_rms(&[1.0_f32], f32::NAN).is_none());
    }

    #[test]
    fn compute_rms_all_zeros_returns_sqrt_eps() {
        // mean(x²) = 0; result = sqrt(0 + eps) = sqrt(eps).
        let eps = 0.25_f32;
        let r = compute_rms(&[0.0_f32; 4], eps).unwrap();
        assert!(approx(r, 0.5, 1e-6));
    }

    #[test]
    fn compute_rms_uniform_value_matches_value() {
        // input = [v; n] → mean(x²) = v² → sqrt(v² + eps) ≈ v for
        // small eps.
        let r = compute_rms(&[2.0_f32; 8], 1e-12).unwrap();
        assert!(approx(r, 2.0, 1e-5));
    }

    #[test]
    fn compute_rms_matches_pythagorean_3_4() {
        // input = [3, 4]; mean(x²) = (9 + 16) / 2 = 12.5;
        // sqrt(12.5 + eps) ≈ sqrt(12.5) ≈ 3.5355.
        let r = compute_rms(&[3.0_f32, 4.0], 1e-12).unwrap();
        let expected = (12.5_f32).sqrt();
        assert!(approx(r, expected, 1e-5));
    }

    #[test]
    fn verify_rms_normalized_within_tolerance_passes() {
        // RMSNorm of unit-gain input should produce output with RMS ≈ 1.
        let input = vec![1.0_f32, 2.0, 3.0, 4.0];
        let gain = vec![1.0_f32; 4];
        let mut out = vec![0.0_f32; 4];
        rmsnorm_into(&input, &gain, 1e-12, &mut out).unwrap();
        let result = verify_rms_normalized(&out, 1.0, 1e-4);
        assert!(result.is_ok());
        let actual = result.unwrap();
        assert!(approx(actual, 1.0, 1e-4));
    }

    #[test]
    fn verify_rms_normalized_outside_tolerance_returns_err() {
        // [2, 2] has RMS exactly 2; expecting 1.0 → fails.
        let out = vec![2.0_f32, 2.0];
        let result = verify_rms_normalized(&out, 1.0, 1e-4);
        match result {
            Err(actual) => assert!(approx(actual, 2.0, 1e-6)),
            Ok(_) => panic!("expected Err"),
        }
    }

    #[test]
    fn verify_rms_normalized_empty_returns_err() {
        let result = verify_rms_normalized(&[], 1.0, 1e-4);
        assert!(result.is_err());
    }

    #[test]
    fn verify_rms_normalized_doubled_gain_doubles_rms() {
        // Gain = 2.0 across all rows → expect output RMS ≈ 2.0.
        let input = vec![1.0_f32, 2.0, 3.0, 4.0];
        let gain = vec![2.0_f32; 4];
        let mut out = vec![0.0_f32; 4];
        rmsnorm_into(&input, &gain, 1e-12, &mut out).unwrap();
        let result = verify_rms_normalized(&out, 2.0, 1e-4);
        assert!(result.is_ok());
    }
}
