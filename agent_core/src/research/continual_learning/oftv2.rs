//! Source:
//! - Qiu et al., "Orthogonal Finetuning Made Scalable", arXiv:2506.19847, 2025
//!   — OFTv2 / QOFT. Input-centric matrix-vector formulation: instead of
//!   updating W → R·W and then forwarding (R·W)·x, OFTv2 forwards R·(W·x)
//!   so the orthogonal R never materializes as an n×n weight delta.
//!   Claims 10× faster training and 3× lower GPU memory vs original OFT,
//!   plus QOFT (quantized OFTv2) outperforms QLoRA stability via
//!   orthogonality-regularized backprop gradients.
//! - Qiu et al. 2023, "Controlling Text-to-Image Diffusion by Orthogonal
//!   Finetuning", arXiv:2306.07280 — original OFT (the v1).
//! - `docs/fusion/jordan's research/kimis deep research/research/continual_learning_online.md`
//!   §8.1 — OFTv2 listed as the "Adaptation" layer alternative to LoRA.
//!
//! # J3 #2 — OFTv2 / QOFT substrate (CPU reference)
//!
//! The substrate floor owns:
//! - `OrthogonalMatrix` newtype with an explicit `verify_orthogonal()`
//!   check (`‖U^T U − I‖_F < tol`), since the entire OFT correctness
//!   story rests on `U^T U = I`.
//! - `apply_oftv2(u, w_times_x, out)` — the input-centric R·(W·x) step.
//!   Caller already computed `w_times_x = W · x`; this routine applies
//!   the orthogonal R on top. That separation is what gives OFTv2 its
//!   memory win: we never materialize `R · W`.
//! - QOFT's quantization regularizer is NOT-STARTED here — it requires
//!   gradient-flow plumbing (PyTorch / Burn / Candle hookup) which is
//!   beyond substrate-floor scope. Documented in the module rustdoc.

use serde::{Deserialize, Serialize};

/// Square orthogonal matrix in row-major flat layout (row 0 first).
/// `data.len() == size * size`. The orthogonality property is NOT
/// enforced at construction — caller must run [`Self::verify_orthogonal`]
/// before any apply that assumes `U^T U = I`.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct OrthogonalMatrix {
    pub size: usize,
    pub data: Vec<f32>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum OftError {
    /// `data.len()` did not match `size * size`.
    ShapeMismatch { size: usize, data_len: usize },
    /// Vector length did not match the orthogonal matrix size.
    VectorSizeMismatch { matrix_size: usize, vector_len: usize },
    /// `out.len()` did not match `matrix.size`.
    OutLengthMismatch { matrix_size: usize, out_len: usize },
    /// `U^T U` deviated from `I` by more than `tol` in Frobenius norm.
    NotOrthogonal { frobenius_distance: f32, tol: f32 },
    /// Tolerance for [`OrthogonalMatrix::verify_orthogonal`] was
    /// non-positive. The check needs a strictly positive floor.
    NonPositiveTolerance { tol: f32 },
}

impl OrthogonalMatrix {
    pub fn new(size: usize, data: Vec<f32>) -> Result<Self, OftError> {
        if data.len() != size * size {
            return Err(OftError::ShapeMismatch { size, data_len: data.len() });
        }
        Ok(Self { size, data })
    }

    /// `n × n` identity matrix. Always orthogonal; useful as the OFTv2
    /// no-op baseline (R = I means "behave like base weights").
    pub fn identity(size: usize) -> Self {
        let mut data = vec![0.0_f32; size * size];
        for i in 0..size {
            data[i * size + i] = 1.0;
        }
        Self { size, data }
    }

    /// Verify `‖U^T U − I‖_F < tol`. Frobenius norm of the deviation
    /// matrix. The OFTv2 paper recommends `tol ≈ 1e-6` for fp32 paths
    /// and `1e-3` for fp16 paths.
    pub fn verify_orthogonal(&self, tol: f32) -> Result<(), OftError> {
        if tol <= 0.0 {
            return Err(OftError::NonPositiveTolerance { tol });
        }
        let n = self.size;
        let mut frob_sq: f32 = 0.0;
        for i in 0..n {
            for j in 0..n {
                let mut sum: f32 = 0.0;
                for k in 0..n {
                    sum += self.data[k * n + i] * self.data[k * n + j];
                }
                let target = if i == j { 1.0 } else { 0.0 };
                let diff = sum - target;
                frob_sq += diff * diff;
            }
        }
        let frob = frob_sq.sqrt();
        if frob >= tol {
            return Err(OftError::NotOrthogonal {
                frobenius_distance: frob,
                tol,
            });
        }
        Ok(())
    }

    /// Transpose. For orthogonal matrices `U^T = U^{-1}` exactly —
    /// transpose is the cheapest way to get the inverse needed by
    /// many OFTv2 backward-pass paths.
    pub fn transpose(&self) -> Self {
        let n = self.size;
        let mut data = vec![0.0_f32; n * n];
        for i in 0..n {
            for j in 0..n {
                data[j * n + i] = self.data[i * n + j];
            }
        }
        Self { size: n, data }
    }

    /// Compose two orthogonal matrices: `self · other`. Closed under
    /// the orthogonal-group product (assuming both inputs are
    /// orthogonal — verify upstream if uncertain). Returns
    /// `Err(VectorSizeMismatch)` if the matrices' sizes differ.
    pub fn compose(&self, other: &OrthogonalMatrix) -> Result<Self, OftError> {
        if self.size != other.size {
            return Err(OftError::VectorSizeMismatch {
                matrix_size: self.size,
                vector_len: other.size,
            });
        }
        let n = self.size;
        let mut data = vec![0.0_f32; n * n];
        for i in 0..n {
            for j in 0..n {
                let mut acc: f32 = 0.0;
                for k in 0..n {
                    acc += self.data[i * n + k] * other.data[k * n + j];
                }
                data[i * n + j] = acc;
            }
        }
        Ok(Self { size: n, data })
    }
}

/// Input-centric OFTv2 apply: `out = U · w_times_x`.
///
/// The caller is responsible for having computed `w_times_x = W · x`
/// already; OFTv2's win is that we never materialize `R · W`. For the
/// substrate floor this is just a standard mat-vec multiply with
/// orthogonality assumed (call [`OrthogonalMatrix::verify_orthogonal`]
/// upstream if you want the check).
pub fn apply_oftv2(
    u: &OrthogonalMatrix,
    w_times_x: &[f32],
    out: &mut [f32],
) -> Result<(), OftError> {
    if w_times_x.len() != u.size {
        return Err(OftError::VectorSizeMismatch {
            matrix_size: u.size,
            vector_len: w_times_x.len(),
        });
    }
    if out.len() != u.size {
        return Err(OftError::OutLengthMismatch {
            matrix_size: u.size,
            out_len: out.len(),
        });
    }
    for i in 0..u.size {
        let mut acc: f32 = 0.0;
        for k in 0..u.size {
            acc += u.data[i * u.size + k] * w_times_x[k];
        }
        out[i] = acc;
    }
    Ok(())
}

/// Build a 2D rotation `[cos θ, -sin θ; sin θ, cos θ]` for testing.
/// Guaranteed orthogonal for any θ.
pub fn rotation_2d(theta_radians: f32) -> OrthogonalMatrix {
    let c = theta_radians.cos();
    let s = theta_radians.sin();
    OrthogonalMatrix {
        size: 2,
        data: vec![c, -s, s, c],
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn identity_is_orthogonal() {
        let u = OrthogonalMatrix::identity(4);
        assert!(u.verify_orthogonal(1e-6).is_ok());
    }

    #[test]
    fn identity_apply_is_passthrough() {
        let u = OrthogonalMatrix::identity(3);
        let x = vec![1.0_f32, 2.0, 3.0];
        let mut out = vec![0.0_f32; 3];
        apply_oftv2(&u, &x, &mut out).unwrap();
        assert_eq!(out, x);
    }

    #[test]
    fn rotation_2d_is_orthogonal() {
        let r = rotation_2d(0.7);
        assert!(r.verify_orthogonal(1e-6).is_ok());
    }

    #[test]
    fn rotation_2d_preserves_vector_norm() {
        let r = rotation_2d(1.234);
        let x = vec![3.0_f32, 4.0];
        let mut out = vec![0.0_f32; 2];
        apply_oftv2(&r, &x, &mut out).unwrap();
        let in_norm: f32 = (x[0] * x[0] + x[1] * x[1]).sqrt();
        let out_norm: f32 = (out[0] * out[0] + out[1] * out[1]).sqrt();
        assert!((in_norm - out_norm).abs() < 1e-5);
    }

    #[test]
    fn rotation_then_inverse_returns_input() {
        let r = rotation_2d(0.5);
        let r_inv = rotation_2d(-0.5);
        let x = vec![7.0_f32, -2.0];
        let mut mid = vec![0.0_f32; 2];
        let mut back = vec![0.0_f32; 2];
        apply_oftv2(&r, &x, &mut mid).unwrap();
        apply_oftv2(&r_inv, &mid, &mut back).unwrap();
        assert!((back[0] - x[0]).abs() < 1e-5);
        assert!((back[1] - x[1]).abs() < 1e-5);
    }

    #[test]
    fn shape_mismatch_rejects_construction() {
        let err = OrthogonalMatrix::new(2, vec![1.0, 0.0, 0.0]).unwrap_err();
        assert_eq!(err, OftError::ShapeMismatch { size: 2, data_len: 3 });
    }

    #[test]
    fn vector_size_mismatch_errors_on_apply() {
        let u = OrthogonalMatrix::identity(3);
        let x = vec![1.0, 2.0];
        let mut out = vec![0.0_f32; 3];
        let err = apply_oftv2(&u, &x, &mut out).unwrap_err();
        assert_eq!(
            err,
            OftError::VectorSizeMismatch { matrix_size: 3, vector_len: 2 }
        );
    }

    #[test]
    fn out_length_mismatch_errors_on_apply() {
        let u = OrthogonalMatrix::identity(3);
        let x = vec![1.0, 2.0, 3.0];
        let mut out = vec![0.0_f32; 5];
        let err = apply_oftv2(&u, &x, &mut out).unwrap_err();
        assert_eq!(
            err,
            OftError::OutLengthMismatch { matrix_size: 3, out_len: 5 }
        );
    }

    #[test]
    fn non_orthogonal_matrix_fails_verify() {
        let bad = OrthogonalMatrix {
            size: 2,
            data: vec![2.0, 0.0, 0.0, 1.0],
        };
        let err = bad.verify_orthogonal(1e-6).unwrap_err();
        match err {
            OftError::NotOrthogonal { frobenius_distance, tol } => {
                assert!(frobenius_distance > 1e-6);
                assert_eq!(tol, 1e-6);
            }
            other => panic!("expected NotOrthogonal, got {:?}", other),
        }
    }

    #[test]
    fn non_positive_tolerance_rejected() {
        let u = OrthogonalMatrix::identity(2);
        let err = u.verify_orthogonal(0.0).unwrap_err();
        assert_eq!(err, OftError::NonPositiveTolerance { tol: 0.0 });
    }

    #[test]
    fn rotation_pi_over_2_swaps_with_sign() {
        let r = rotation_2d(std::f32::consts::FRAC_PI_2);
        let x = vec![1.0_f32, 0.0];
        let mut out = vec![0.0_f32; 2];
        apply_oftv2(&r, &x, &mut out).unwrap();
        assert!(out[0].abs() < 1e-5);
        assert!((out[1] - 1.0).abs() < 1e-5);
    }

    #[test]
    fn matrix_roundtrips_through_serde_json() {
        let r = rotation_2d(1.0);
        let json = serde_json::to_string(&r).unwrap();
        let back: OrthogonalMatrix = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn off_diagonal_identity_one_value_breaks_orthogonality() {
        let mut u = OrthogonalMatrix::identity(3);
        u.data[1] = 0.5;
        assert!(u.verify_orthogonal(1e-6).is_err());
    }

    // ── transpose + compose tests (iter 106) ────────────────────────────────

    fn approx_eq(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn transpose_of_identity_is_identity() {
        let i = OrthogonalMatrix::identity(3);
        let t = i.transpose();
        assert_eq!(i, t);
    }

    #[test]
    fn transpose_of_rotation_is_inverse_rotation() {
        let r = rotation_2d(0.5);
        let t = r.transpose();
        // R(θ).T = R(-θ).
        let r_neg = rotation_2d(-0.5);
        for k in 0..4 {
            assert!(
                approx_eq(t.data[k], r_neg.data[k], 1e-6),
                "transpose[{}] = {} != {}",
                k,
                t.data[k],
                r_neg.data[k]
            );
        }
    }

    #[test]
    fn transpose_twice_returns_original() {
        let r = rotation_2d(1.25);
        let tt = r.transpose().transpose();
        for k in 0..4 {
            assert!(approx_eq(tt.data[k], r.data[k], 1e-6));
        }
    }

    #[test]
    fn compose_with_identity_is_identity() {
        let r = rotation_2d(0.7);
        let i = OrthogonalMatrix::identity(2);
        let ri = r.compose(&i).unwrap();
        let ir = i.compose(&r).unwrap();
        for k in 0..4 {
            assert!(approx_eq(ri.data[k], r.data[k], 1e-6));
            assert!(approx_eq(ir.data[k], r.data[k], 1e-6));
        }
    }

    #[test]
    fn compose_two_rotations_adds_angles() {
        let r1 = rotation_2d(0.3);
        let r2 = rotation_2d(0.4);
        let r12 = r1.compose(&r2).unwrap();
        let r_sum = rotation_2d(0.7);
        for k in 0..4 {
            assert!(
                approx_eq(r12.data[k], r_sum.data[k], 1e-6),
                "compose[{}] = {} != {}",
                k,
                r12.data[k],
                r_sum.data[k]
            );
        }
    }

    #[test]
    fn compose_with_transpose_yields_identity() {
        // R · R^T = I for orthogonal R.
        let r = rotation_2d(0.9);
        let rt = r.transpose();
        let p = r.compose(&rt).unwrap();
        let i = OrthogonalMatrix::identity(2);
        for k in 0..4 {
            assert!(approx_eq(p.data[k], i.data[k], 1e-6));
        }
    }

    #[test]
    fn compose_size_mismatch_rejected() {
        let a = OrthogonalMatrix::identity(2);
        let b = OrthogonalMatrix::identity(3);
        let err = a.compose(&b).unwrap_err();
        assert!(matches!(err, OftError::VectorSizeMismatch { .. }));
    }

    #[test]
    fn composed_orthogonal_is_still_orthogonal() {
        // Composition is closed under the orthogonal group: R1 · R2
        // is orthogonal if both inputs are.
        let r1 = rotation_2d(0.5);
        let r2 = rotation_2d(1.1);
        let r12 = r1.compose(&r2).unwrap();
        assert!(r12.verify_orthogonal(1e-5).is_ok());
    }
}
