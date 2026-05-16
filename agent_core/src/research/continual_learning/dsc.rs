//! Source:
//! - Wang et al., "Dynamic Orthogonal Continual Fine-tuning for Mitigating
//!   Catastrophic Forgettings", arXiv:2509.23893, 2025 — DSC / DOC.
//!   Online PCA tracking of functional direction drift; ~40% less
//!   forgetting vs fixed-direction methods over >100-conversation
//!   sequences (`continual_learning_online.md` §8.2 point 1).
//! - Farajtabar et al., "Orthogonal Gradient Descent for Continual
//!   Learning", arXiv:1907.08684 — the canonical OGD baseline DSC
//!   improves on (fixed direction tracking).
//! - Wang et al., "Orthogonal Subspace Learning for Language Model
//!   Continual Learning" (O-LoRA), EMNLP 2023, arXiv:2310.14152 — the
//!   subspace-orthogonal-LoRA sibling lane.
//! - `continual_learning_online.md` §8.1 (Adaptation layer) + §8.2
//!   (DOC > O-LoRA for long sequences).
//!
//! # J3 #3 — DSC / DOC substrate (CPU reference)
//!
//! Maintain an orthonormal basis spanning the directions of past-task
//! gradients. For each new gradient `g`:
//!
//! 1. Project out the component already covered by the basis:
//!    `g_perp = g − Σ_b (b · g) · b`.
//! 2. If `‖g_perp‖ > threshold`, normalize and append to the basis
//!    (subject to `rank_limit` — oldest basis vector evicted if full).
//!
//! Then for any future weight update gradient, [`project_orthogonal`]
//! returns the component perpendicular to the basis — that's the safe
//! direction to step in without forgetting past tasks.
//!
//! Substrate floor restrictions: pure CPU reference, no Burn / Candle
//! integration, no fp16 hot path. Real adapters need the iterative
//! incremental-SVD version from Wang 2025 §3.2; this floor uses the
//! simpler Gram-Schmidt orthogonalization which is `O(rank · dim)` per
//! ingest and adequate for the substrate-floor unit tests.

use serde::{Deserialize, Serialize};

/// Orthonormal basis tracked by DSC. Vectors are stored as flat `Vec<f32>`
/// of length `dim` each. `basis.len() ≤ rank_limit`.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct OrthogonalSubspace {
    pub dim: usize,
    pub rank_limit: usize,
    pub basis: Vec<Vec<f32>>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum DscError {
    ZeroDim,
    ZeroRankLimit,
    /// Gradient length did not match `subspace.dim`.
    GradientLengthMismatch { dim: usize, actual: usize },
    /// `out.len()` did not match `subspace.dim`.
    OutLengthMismatch { dim: usize, out_len: usize },
    /// Non-positive threshold for `update_with_gradient`.
    NonPositiveThreshold { threshold: f32 },
}

impl OrthogonalSubspace {
    pub fn new(dim: usize, rank_limit: usize) -> Result<Self, DscError> {
        if dim == 0 {
            return Err(DscError::ZeroDim);
        }
        if rank_limit == 0 {
            return Err(DscError::ZeroRankLimit);
        }
        Ok(Self {
            dim,
            rank_limit,
            basis: Vec::new(),
        })
    }

    pub fn rank(&self) -> usize {
        self.basis.len()
    }

    pub fn is_empty(&self) -> bool {
        self.basis.is_empty()
    }

    pub fn is_full(&self) -> bool {
        self.basis.len() >= self.rank_limit
    }

    /// Clear all basis vectors. Preserves `dim` + `rank_limit`. Useful
    /// for restart-from-clean-state between distinct task sequences.
    pub fn clear(&mut self) {
        self.basis.clear();
    }

    /// Verify the basis is orthonormal: every pair (b_i, b_j) for
    /// i ≠ j has |b_i · b_j| < tol AND every b_i has |‖b_i‖ - 1| < tol.
    /// Substrate floor of the DSC §3.2 correctness invariant.
    pub fn verify_orthonormal(&self, tol: f32) -> Result<(), DscError> {
        if tol <= 0.0 {
            return Err(DscError::NonPositiveThreshold { threshold: tol });
        }
        for (i, bi) in self.basis.iter().enumerate() {
            let n = norm(bi);
            if (n - 1.0).abs() >= tol {
                return Err(DscError::GradientLengthMismatch {
                    dim: i,
                    actual: bi.len(),
                });
            }
            for (j, bj) in self.basis.iter().enumerate().skip(i + 1) {
                if dot(bi, bj).abs() >= tol {
                    return Err(DscError::GradientLengthMismatch {
                        dim: i,
                        actual: j,
                    });
                }
            }
        }
        Ok(())
    }

    /// Fraction of `g`'s energy already covered by the subspace
    /// (`‖g_parallel‖² / ‖g‖²`). Returns `Ok(0.0)` for an empty
    /// subspace or zero-norm `g`. Values close to 1.0 mean any
    /// future weight step in `g`'s direction would risk forgetting
    /// past tasks — the projection bites hard.
    pub fn gradient_alignment(&self, g: &[f32]) -> Result<f32, DscError> {
        if g.len() != self.dim {
            return Err(DscError::GradientLengthMismatch {
                dim: self.dim,
                actual: g.len(),
            });
        }
        let g_norm_sq = dot(g, g);
        if g_norm_sq == 0.0 {
            return Ok(0.0);
        }
        let mut parallel_norm_sq = 0.0;
        for b in &self.basis {
            let proj = dot(b, g);
            parallel_norm_sq += proj * proj;
        }
        Ok(parallel_norm_sq / g_norm_sq)
    }
}

fn dot(a: &[f32], b: &[f32]) -> f32 {
    a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
}

fn norm(v: &[f32]) -> f32 {
    dot(v, v).sqrt()
}

/// Subtract the basis-aligned component from `g` into `out`.
/// `out[i] = g[i] − Σ_b (b · g) · b[i]`.
pub fn project_orthogonal(
    subspace: &OrthogonalSubspace,
    g: &[f32],
    out: &mut [f32],
) -> Result<(), DscError> {
    if g.len() != subspace.dim {
        return Err(DscError::GradientLengthMismatch {
            dim: subspace.dim,
            actual: g.len(),
        });
    }
    if out.len() != subspace.dim {
        return Err(DscError::OutLengthMismatch {
            dim: subspace.dim,
            out_len: out.len(),
        });
    }
    out.copy_from_slice(g);
    for b in &subspace.basis {
        let coeff = dot(b, g);
        for i in 0..subspace.dim {
            out[i] -= coeff * b[i];
        }
    }
    Ok(())
}

/// Ingest `g`: project out the existing basis, then append the
/// normalized residual if `‖g_perp‖ ≥ threshold`. If the basis is at
/// `rank_limit`, evicts the oldest entry first.
///
/// Returns `Ok(true)` if a new basis vector was added, `Ok(false)` if
/// the residual was below threshold (already covered by the existing
/// subspace).
pub fn update_with_gradient(
    subspace: &mut OrthogonalSubspace,
    g: &[f32],
    threshold: f32,
) -> Result<bool, DscError> {
    if threshold <= 0.0 {
        return Err(DscError::NonPositiveThreshold { threshold });
    }
    let mut residual = vec![0.0_f32; subspace.dim];
    project_orthogonal(subspace, g, &mut residual)?;
    let r_norm = norm(&residual);
    if r_norm < threshold {
        return Ok(false);
    }
    for v in residual.iter_mut() {
        *v /= r_norm;
    }
    if subspace.basis.len() == subspace.rank_limit {
        subspace.basis.remove(0);
    }
    subspace.basis.push(residual);
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zero_dim_rejected() {
        let err = OrthogonalSubspace::new(0, 4).unwrap_err();
        assert_eq!(err, DscError::ZeroDim);
    }

    #[test]
    fn zero_rank_limit_rejected() {
        let err = OrthogonalSubspace::new(3, 0).unwrap_err();
        assert_eq!(err, DscError::ZeroRankLimit);
    }

    #[test]
    fn empty_subspace_passes_gradient_through() {
        let s = OrthogonalSubspace::new(3, 4).unwrap();
        let g = vec![1.0_f32, -2.0, 3.0];
        let mut out = vec![0.0_f32; 3];
        project_orthogonal(&s, &g, &mut out).unwrap();
        assert_eq!(out, g);
    }

    #[test]
    fn first_ingest_adds_single_basis_vector() {
        let mut s = OrthogonalSubspace::new(2, 4).unwrap();
        let added = update_with_gradient(&mut s, &[3.0, 4.0], 1e-6).unwrap();
        assert!(added);
        assert_eq!(s.rank(), 1);
        assert!((norm(&s.basis[0]) - 1.0).abs() < 1e-6);
    }

    #[test]
    fn second_ingest_in_same_direction_is_below_threshold() {
        let mut s = OrthogonalSubspace::new(2, 4).unwrap();
        update_with_gradient(&mut s, &[3.0, 4.0], 1e-6).unwrap();
        let added = update_with_gradient(&mut s, &[6.0, 8.0], 1e-3).unwrap();
        assert!(!added);
        assert_eq!(s.rank(), 1);
    }

    #[test]
    fn orthogonal_second_ingest_adds_second_basis_vector() {
        let mut s = OrthogonalSubspace::new(2, 4).unwrap();
        update_with_gradient(&mut s, &[1.0, 0.0], 1e-6).unwrap();
        let added = update_with_gradient(&mut s, &[0.0, 1.0], 1e-6).unwrap();
        assert!(added);
        assert_eq!(s.rank(), 2);
    }

    #[test]
    fn projection_removes_basis_aligned_component() {
        let mut s = OrthogonalSubspace::new(3, 4).unwrap();
        update_with_gradient(&mut s, &[1.0, 0.0, 0.0], 1e-6).unwrap();
        let g = vec![5.0_f32, 2.0, -1.0];
        let mut out = vec![0.0_f32; 3];
        project_orthogonal(&s, &g, &mut out).unwrap();
        assert!(out[0].abs() < 1e-5);
        assert!((out[1] - 2.0).abs() < 1e-5);
        assert!((out[2] - -1.0).abs() < 1e-5);
    }

    #[test]
    fn basis_evicts_oldest_at_rank_limit() {
        let mut s = OrthogonalSubspace::new(3, 2).unwrap();
        update_with_gradient(&mut s, &[1.0, 0.0, 0.0], 1e-6).unwrap();
        update_with_gradient(&mut s, &[0.0, 1.0, 0.0], 1e-6).unwrap();
        update_with_gradient(&mut s, &[0.0, 0.0, 1.0], 1e-6).unwrap();
        assert_eq!(s.rank(), 2);
        assert!((s.basis[0][1] - 1.0).abs() < 1e-6);
        assert!((s.basis[1][2] - 1.0).abs() < 1e-6);
    }

    #[test]
    fn projection_after_two_orthogonal_basis_zeroes_full_basis() {
        let mut s = OrthogonalSubspace::new(3, 4).unwrap();
        update_with_gradient(&mut s, &[1.0, 0.0, 0.0], 1e-6).unwrap();
        update_with_gradient(&mut s, &[0.0, 1.0, 0.0], 1e-6).unwrap();
        let g = vec![3.0_f32, 4.0, 5.0];
        let mut out = vec![0.0_f32; 3];
        project_orthogonal(&s, &g, &mut out).unwrap();
        assert!(out[0].abs() < 1e-5);
        assert!(out[1].abs() < 1e-5);
        assert!((out[2] - 5.0).abs() < 1e-5);
    }

    #[test]
    fn non_positive_threshold_rejected() {
        let mut s = OrthogonalSubspace::new(2, 4).unwrap();
        let err = update_with_gradient(&mut s, &[1.0, 0.0], 0.0).unwrap_err();
        assert_eq!(err, DscError::NonPositiveThreshold { threshold: 0.0 });
    }

    #[test]
    fn gradient_length_mismatch_errors() {
        let mut s = OrthogonalSubspace::new(2, 4).unwrap();
        let err = update_with_gradient(&mut s, &[1.0], 1e-6).unwrap_err();
        assert_eq!(err, DscError::GradientLengthMismatch { dim: 2, actual: 1 });
    }

    #[test]
    fn project_out_length_mismatch_errors() {
        let s = OrthogonalSubspace::new(3, 4).unwrap();
        let g = vec![1.0_f32; 3];
        let mut bad_out = vec![0.0_f32; 2];
        let err = project_orthogonal(&s, &g, &mut bad_out).unwrap_err();
        assert_eq!(err, DscError::OutLengthMismatch { dim: 3, out_len: 2 });
    }

    #[test]
    fn near_aligned_gradient_below_threshold_skips() {
        let mut s = OrthogonalSubspace::new(2, 4).unwrap();
        update_with_gradient(&mut s, &[1.0, 0.0], 1e-6).unwrap();
        let added = update_with_gradient(&mut s, &[1.0, 1e-9], 1e-3).unwrap();
        assert!(!added);
    }

    #[test]
    fn subspace_roundtrips_through_serde_json() {
        let mut s = OrthogonalSubspace::new(2, 4).unwrap();
        update_with_gradient(&mut s, &[1.0, 0.0], 1e-6).unwrap();
        let json = serde_json::to_string(&s).unwrap();
        let back: OrthogonalSubspace = serde_json::from_str(&json).unwrap();
        assert_eq!(s, back);
    }

    // ── Diagnostic surface tests (iter 107) ─────────────────────────────────

    #[test]
    fn fresh_subspace_is_empty_not_full() {
        let s = OrthogonalSubspace::new(4, 3).unwrap();
        assert!(s.is_empty());
        assert!(!s.is_full());
        assert_eq!(s.rank(), 0);
    }

    #[test]
    fn subspace_becomes_full_at_rank_limit() {
        let mut s = OrthogonalSubspace::new(3, 2).unwrap();
        update_with_gradient(&mut s, &[1.0, 0.0, 0.0], 1e-3).unwrap();
        assert!(!s.is_full());
        update_with_gradient(&mut s, &[0.0, 1.0, 0.0], 1e-3).unwrap();
        assert!(s.is_full());
    }

    #[test]
    fn clear_returns_to_empty_preserving_config() {
        let mut s = OrthogonalSubspace::new(3, 5).unwrap();
        update_with_gradient(&mut s, &[1.0, 0.0, 0.0], 1e-3).unwrap();
        assert!(!s.is_empty());
        s.clear();
        assert!(s.is_empty());
        assert_eq!(s.dim, 3);
        assert_eq!(s.rank_limit, 5);
    }

    #[test]
    fn verify_orthonormal_empty_basis_passes() {
        let s = OrthogonalSubspace::new(3, 2).unwrap();
        assert!(s.verify_orthonormal(1e-6).is_ok());
    }

    #[test]
    fn verify_orthonormal_after_ingest_passes() {
        let mut s = OrthogonalSubspace::new(3, 3).unwrap();
        update_with_gradient(&mut s, &[1.0, 0.0, 0.0], 1e-3).unwrap();
        update_with_gradient(&mut s, &[1.0, 1.0, 0.0], 1e-3).unwrap();
        update_with_gradient(&mut s, &[1.0, 1.0, 1.0], 1e-3).unwrap();
        assert!(s.verify_orthonormal(1e-5).is_ok());
    }

    #[test]
    fn verify_orthonormal_non_positive_tol_rejected() {
        let s = OrthogonalSubspace::new(3, 2).unwrap();
        assert!(s.verify_orthonormal(0.0).is_err());
        assert!(s.verify_orthonormal(-0.1).is_err());
    }

    #[test]
    fn gradient_alignment_empty_subspace_returns_zero() {
        let s = OrthogonalSubspace::new(3, 2).unwrap();
        let a = s.gradient_alignment(&[1.0, 2.0, 3.0]).unwrap();
        assert!(a.abs() < 1e-6);
    }

    #[test]
    fn gradient_alignment_zero_gradient_returns_zero() {
        let s = OrthogonalSubspace::new(3, 2).unwrap();
        let a = s.gradient_alignment(&[0.0, 0.0, 0.0]).unwrap();
        assert!(a.abs() < 1e-6);
    }

    #[test]
    fn gradient_alignment_one_for_basis_direction() {
        // Basis = {e_x}; alignment of g = e_x is 1.0 (fully covered).
        let mut s = OrthogonalSubspace::new(3, 2).unwrap();
        update_with_gradient(&mut s, &[1.0, 0.0, 0.0], 1e-3).unwrap();
        let a = s.gradient_alignment(&[5.0, 0.0, 0.0]).unwrap();
        assert!((a - 1.0).abs() < 1e-5);
    }

    #[test]
    fn gradient_alignment_zero_for_perpendicular_direction() {
        // Basis = {e_x}; alignment of g = e_y is 0 (perpendicular).
        let mut s = OrthogonalSubspace::new(3, 2).unwrap();
        update_with_gradient(&mut s, &[1.0, 0.0, 0.0], 1e-3).unwrap();
        let a = s.gradient_alignment(&[0.0, 3.0, 0.0]).unwrap();
        assert!(a.abs() < 1e-6);
    }

    #[test]
    fn gradient_alignment_partial_for_diagonal_direction() {
        // Basis = {e_x}; g = [1, 1, 0] / sqrt(2). Projection onto e_x
        // has squared norm 0.5; total squared norm 1.0; alignment 0.5.
        let mut s = OrthogonalSubspace::new(3, 2).unwrap();
        update_with_gradient(&mut s, &[1.0, 0.0, 0.0], 1e-3).unwrap();
        let inv_sqrt_2 = 1.0_f32 / 2.0_f32.sqrt();
        let a = s.gradient_alignment(&[inv_sqrt_2, inv_sqrt_2, 0.0]).unwrap();
        assert!((a - 0.5).abs() < 1e-5);
    }

    #[test]
    fn gradient_alignment_dim_mismatch_rejected() {
        let s = OrthogonalSubspace::new(3, 2).unwrap();
        let err = s.gradient_alignment(&[1.0, 2.0]).unwrap_err();
        assert!(matches!(err, DscError::GradientLengthMismatch { .. }));
    }
}
