//! Source:
//! - Li/FNO arXiv:2010.08895 §3 — Fourier Neural Operator. The
//!   spectral block: DFT → spectral multiply on first M modes →
//!   IDFT. This module implements the spectral truncation form
//!   (no learnable spectral weights yet — Phase C work).
//! - Doctrine §4.4 — Operator-IR Fourier kernel lowering.
//!
//! # FNO Fourier-kernel lowering
//!
//! Pipeline:
//!
//! 1. `dft(x: &[f64]) -> Vec<(f64, f64)>` — naive O(N²) DFT,
//!    no extra dependency. Sufficient for small N (≤ 32 in tests).
//! 2. Truncate to first `modes` frequency bins; zero the rest.
//! 3. `idft_real(spec: &[(f64, f64)]) -> Vec<f64>` — IDFT,
//!    returning the real part (input was real, so the spectrum is
//!    conjugate-symmetric and the IDFT is real-valued).
//!
//! Numerical note: a naive DFT round-trip (no truncation) is not
//! bit-exact identity due to floating-point rounding of the
//! `sin`/`cos` evaluations. Property tests assert round-trip
//! agreement within `1e-9` rel-tol.

/// Naive O(N²) DFT on a real input vector. Returns a vector of
/// (real, imaginary) frequency-bin pairs of the same length.
pub fn dft(x: &[f64]) -> Vec<(f64, f64)> {
    let n = x.len();
    let mut out = Vec::with_capacity(n);
    for k in 0..n {
        let mut re = 0.0_f64;
        let mut im = 0.0_f64;
        for (j, xj) in x.iter().enumerate() {
            let arg = -2.0 * std::f64::consts::PI * (k as f64) * (j as f64)
                / (n as f64);
            re += xj * arg.cos();
            im += xj * arg.sin();
        }
        out.push((re, im));
    }
    out
}

/// Naive O(N²) IDFT, returning the real part. Used here for
/// inputs known to be real-valued (so the spectrum is conjugate-
/// symmetric and the IDFT is purely real modulo floating-point
/// rounding).
pub fn idft_real(spec: &[(f64, f64)]) -> Vec<f64> {
    let n = spec.len();
    let mut out = Vec::with_capacity(n);
    for j in 0..n {
        let mut re = 0.0_f64;
        for (k, &(sr, si)) in spec.iter().enumerate() {
            let arg = 2.0 * std::f64::consts::PI * (k as f64) * (j as f64)
                / (n as f64);
            // (sr + i si) * (cos + i sin) → real part = sr*cos - si*sin
            re += sr * arg.cos() - si * arg.sin();
        }
        out.push(re / (n as f64));
    }
    out
}

/// FNO spectral block: DFT → truncate to first `modes` bins → IDFT.
/// Returns a real-valued vector of the same length as `trunk_output`.
///
/// If `modes >= n`, this is a full round-trip and the output
/// matches the input within float rounding.
pub fn fno_spectral_block(trunk_output: &[f64], modes: usize) -> Vec<f64> {
    let n = trunk_output.len();
    if n == 0 {
        return Vec::new();
    }
    let mut spec = dft(trunk_output);
    let keep = modes.min(n);
    for s in spec.iter_mut().skip(keep) {
        *s = (0.0, 0.0);
    }
    idft_real(&spec)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx_vec(a: &[f64], b: &[f64], tol: f64) -> bool {
        a.len() == b.len()
            && a.iter().zip(b.iter()).all(|(x, y)| (x - y).abs() < tol)
    }

    #[test]
    fn dft_zero_input_returns_zero_spectrum() {
        let s = dft(&[0.0, 0.0, 0.0, 0.0]);
        for (re, im) in s {
            assert!(re.abs() < 1e-12);
            assert!(im.abs() < 1e-12);
        }
    }

    #[test]
    fn dft_constant_input_dc_only() {
        // Constant input → only the DC (k=0) bin has non-zero magnitude.
        let n = 8;
        let x: Vec<f64> = vec![1.0; n];
        let s = dft(&x);
        assert!((s[0].0 - n as f64).abs() < 1e-10);
        assert!(s[0].1.abs() < 1e-10);
        for sk in s.iter().skip(1) {
            assert!(sk.0.abs() < 1e-10, "non-zero re at non-DC: {}", sk.0);
            assert!(sk.1.abs() < 1e-10, "non-zero im at non-DC: {}", sk.1);
        }
    }

    #[test]
    fn dft_idft_round_trip_within_tolerance() {
        let x = vec![1.0, 2.0, 3.0, 4.0, 5.0, 4.0, 3.0, 2.0];
        let recovered = idft_real(&dft(&x));
        assert!(
            approx_vec(&x, &recovered, 1e-9),
            "round trip: input {:?} recovered {:?}",
            x, recovered
        );
    }

    #[test]
    fn fno_spectral_block_all_modes_is_identity_within_tolerance() {
        let x = vec![1.0_f64, 0.5, -0.5, -1.0, -0.5, 0.5, 1.0, 0.5];
        let y = fno_spectral_block(&x, x.len());
        assert!(approx_vec(&x, &y, 1e-9));
    }

    #[test]
    fn fno_spectral_block_zero_modes_yields_zero() {
        let x = vec![1.0_f64, 2.0, 3.0, 4.0];
        let y = fno_spectral_block(&x, 0);
        // Truncating all modes → zero spectrum → zero output.
        for v in &y {
            assert!(v.abs() < 1e-10, "expected 0, got {}", v);
        }
    }

    #[test]
    fn fno_spectral_block_one_mode_returns_dc_smoothing() {
        // Keeping only the DC bin reduces the signal to its mean.
        let x = vec![1.0_f64, 2.0, 3.0, 4.0];
        let mean = x.iter().sum::<f64>() / (x.len() as f64);
        let y = fno_spectral_block(&x, 1);
        for v in &y {
            assert!((v - mean).abs() < 1e-9, "expected {}, got {}", mean, v);
        }
    }

    #[test]
    fn fno_empty_input_returns_empty() {
        let y = fno_spectral_block(&[], 4);
        assert!(y.is_empty());
    }

    #[test]
    fn fno_modes_larger_than_input_treats_as_n() {
        let x = vec![1.0_f64, 2.0, 3.0];
        let y_full = fno_spectral_block(&x, x.len());
        let y_over = fno_spectral_block(&x, 100);
        assert!(approx_vec(&y_full, &y_over, 1e-12));
    }

    #[test]
    fn fno_linearity_in_input() {
        // FNO spectral block is linear; scaling input by α scales
        // output by α.
        let x = vec![1.0_f64, 0.5, -0.5, -1.0];
        let y1 = fno_spectral_block(&x, 2);
        let x_scaled: Vec<f64> = x.iter().map(|v| 3.0 * v).collect();
        let y_scaled = fno_spectral_block(&x_scaled, 2);
        let y_expected: Vec<f64> = y1.iter().map(|v| 3.0 * v).collect();
        assert!(approx_vec(&y_scaled, &y_expected, 1e-9));
    }
}
