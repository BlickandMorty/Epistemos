// HARDENING ENFORCEMENT: STG kernel reference must remain panic-
// free in production. Tests are allowed to unwrap because a failed
// invariant SHOULD panic loudly.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! HELIOS V5 W14 — Sparse Ternary GEMM (NEON SIMD).
//!
//! HELIOS-W14 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W14 +
//! `docs/fusion/helios v5 updated.md` PART 1 (Sparse Ternary GEMM):
//!
//! > "Sparse Ternary GEMM Apple Silicon (Lipshitz, Melone, Maraziaris,
//! >  Bilal, ETH Zurich) — arXiv:2510.06957v2 (2025-10-13). 5.98×
//! >  scalar speedup vs TCSC at 50% sparsity; 50.2% theoretical
//! >  peak; 5.59× vectorized at 25%."
//!
//! **Tier 2 contract:** ≥ 4× speedup vs TCSC baseline on M2 Max at
//! 50% sparsity (verifying ETH paper's 5.98× on local hardware).
//! Gated behind "Experimental Metal Kernels → Sparse Ternary GEMM"
//! Settings toggle (default OFF).
//!
//! This pure-Rust reference is the CORRECTNESS oracle, not the
//! performance target. The NEON-SIMD acceleration lands per a
//! follow-up Metal/CPU-intrinsics slice; this reference produces
//! BIT-IDENTICAL output to the dense ternary GEMM (when the sparse
//! mask is conservative).
//!
//! ## Sparse-vs-dense tradeoff
//!
//! Sparse Ternary GEMM exploits the structural property that ~50%
//! of ternary weights are 0. The compressed format stores only
//! non-zero indices + signs (1 bit) instead of the full {-1, 0, +1}
//! triplet (2 bits). On Apple Silicon NEON, this enables
//! 16-element vector loads to cover 16 weights instead of 8.
//!
//! Per §2.5.2 compliance: source code ships in MAS bundle; the
//! bundled ternary-quantized model file is a release-prep concern.
//! The kernel runs against synthetic ternary weights for testing.
//!
//! ## Cross-references
//!
//! - DOC 0 §0.2 (H4 area; W14 in §0.6 glossary)
//! - DOC 0 §0.4 (lane summary: Tier 2 flagged OFF)
//! - [`crate::scope_rex::kernels::t_mac`] — dense ternary GEMM
//!   reference

use super::t_mac::TernaryWeight;

/// One non-zero entry in the sparse ternary representation:
/// (column index, sign in {-1, +1}). Zero weights are absent.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SparseTernaryEntry {
    pub col: u32,
    pub sign: i8, // -1 or +1; 0 is never stored
}

/// One row of a sparse ternary weight matrix. Stored in CSR-style
/// per-row entry list.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SparseTernaryRow {
    pub entries: Vec<SparseTernaryEntry>,
}

/// Sparse ternary weight matrix. Outer Vec is rows; per-row entries
/// are sorted ascending by `col` for deterministic dispatch.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SparseTernaryMatrix {
    pub rows: Vec<SparseTernaryRow>,
    pub cols: usize,
}

impl SparseTernaryMatrix {
    /// Build from a row-major dense ternary buffer. Drops zeros.
    pub fn from_dense(dense: &[TernaryWeight], rows: usize, cols: usize) -> Self {
        debug_assert_eq!(dense.len(), rows * cols);
        let mut sparse_rows = Vec::with_capacity(rows);
        for r in 0..rows {
            let mut entries = Vec::new();
            for c in 0..cols {
                let w = dense[r * cols + c].0;
                if w != 0 {
                    entries.push(SparseTernaryEntry {
                        col: c as u32,
                        sign: w,
                    });
                }
            }
            sparse_rows.push(SparseTernaryRow { entries });
        }
        Self {
            rows: sparse_rows,
            cols,
        }
    }

    /// Total number of non-zero entries across all rows.
    pub fn nnz(&self) -> usize {
        self.rows.iter().map(|r| r.entries.len()).sum()
    }

    /// Sparsity ratio: 1.0 = all zeros; 0.0 = fully dense.
    pub fn sparsity(&self) -> f32 {
        let total = (self.rows.len() * self.cols) as f32;
        if total <= 0.0 {
            return 1.0;
        }
        let nz = self.nnz() as f32;
        1.0 - (nz / total)
    }
}

/// Sparse Ternary GEMM kernel. Iterates each row's non-zero entries
/// and accumulates `sign * input[col]` into the row's output slot.
///
/// **Tier 2 contract:** produces output BIT-IDENTICAL to the dense
/// reference [`super::t_mac::t_mac_reference`] when the sparse mask
/// drops only true-zero weights (the canonical case after
/// [`SparseTernaryMatrix::from_dense`]).
pub fn sparse_ternary_gemm(input: &[f32], sparse: &SparseTernaryMatrix) -> Vec<f32> {
    debug_assert_eq!(input.len(), sparse.cols);
    let mut out = vec![0.0f32; sparse.rows.len()];
    for (r, row) in sparse.rows.iter().enumerate() {
        let mut acc = 0.0f32;
        for entry in &row.entries {
            let col = entry.col as usize;
            if col >= sparse.cols {
                continue; // defensive bounds-check
            }
            match entry.sign {
                1 => acc += input[col],
                -1 => acc -= input[col],
                _ => {} // never stored, but defensive
            }
        }
        out[r] = acc;
    }
    out
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::super::t_mac::{t_mac_reference, TernaryWeight};
    use super::*;

    fn deterministic_ternary_weights(seed: u64, n: usize, sparsity: f32) -> Vec<TernaryWeight> {
        let mut state = seed
            .wrapping_mul(2862933555777941757)
            .wrapping_add(3037000493);
        let mut out = Vec::with_capacity(n);
        for _ in 0..n {
            state = state
                .wrapping_mul(2862933555777941757)
                .wrapping_add(3037000493);
            let r = ((state >> 8) & 0xFFFFFF) as f32 / 16_777_216.0;
            if r < sparsity {
                out.push(TernaryWeight(0));
            } else {
                state = state
                    .wrapping_mul(2862933555777941757)
                    .wrapping_add(3037000493);
                let s = if (state & 1) == 0 { 1 } else { -1 };
                out.push(TernaryWeight(s));
            }
        }
        out
    }

    #[test]
    fn from_dense_matches_dense_when_no_zeros() {
        let dense = vec![
            TernaryWeight(1),
            TernaryWeight(-1),
            TernaryWeight(1),
            TernaryWeight(-1),
        ];
        let sparse = SparseTernaryMatrix::from_dense(&dense, 2, 2);
        assert_eq!(sparse.nnz(), 4);
        assert!((sparse.sparsity() - 0.0).abs() < 1e-6);
    }

    #[test]
    fn from_dense_drops_zero_entries() {
        let dense = vec![
            TernaryWeight(1),
            TernaryWeight(0),
            TernaryWeight(0),
            TernaryWeight(-1),
        ];
        let sparse = SparseTernaryMatrix::from_dense(&dense, 2, 2);
        assert_eq!(sparse.nnz(), 2);
        assert!((sparse.sparsity() - 0.5).abs() < 1e-6);
    }

    #[test]
    fn sparse_gemm_matches_dense_reference_on_mixed_input() {
        let dense = vec![
            TernaryWeight(1),
            TernaryWeight(0),
            TernaryWeight(-1),
            TernaryWeight(0),
            TernaryWeight(1),
            TernaryWeight(1),
        ];
        let input = vec![1.0_f32, 2.0, 3.0];
        let sparse = SparseTernaryMatrix::from_dense(&dense, 2, 3);

        let dense_out = t_mac_reference(&input, &dense, 2, 3);
        let sparse_out = sparse_ternary_gemm(&input, &sparse);

        assert_eq!(dense_out, sparse_out);
    }

    #[test]
    fn sparse_gemm_bit_identical_against_dense_for_50_percent_sparse() {
        // ETH paper headline case: 50% sparsity. Verify
        // bit-identical output between sparse and dense paths.
        let rows = 12;
        let cols = 8;
        let dense = deterministic_ternary_weights(7, rows * cols, 0.5);
        let input: Vec<f32> = (0..cols).map(|i| (i as f32 * 0.5) - 1.0).collect();

        let dense_out = t_mac_reference(&input, &dense, rows, cols);
        let sparse = SparseTernaryMatrix::from_dense(&dense, rows, cols);
        let sparse_out = sparse_ternary_gemm(&input, &sparse);

        assert_eq!(dense_out, sparse_out);
    }

    #[test]
    fn sparse_gemm_preserves_determinism_under_repeated_calls() {
        let dense = deterministic_ternary_weights(42, 8 * 4, 0.3);
        let input = vec![1.0_f32, 2.0, 3.0, 4.0];
        let sparse = SparseTernaryMatrix::from_dense(&dense, 8, 4);
        let first = sparse_ternary_gemm(&input, &sparse);
        for _ in 0..1000 {
            assert_eq!(sparse_ternary_gemm(&input, &sparse), first);
        }
    }

    #[test]
    fn empty_matrix_returns_empty_output() {
        let sparse = SparseTernaryMatrix::default();
        let input: Vec<f32> = Vec::new();
        let out = sparse_ternary_gemm(&input, &sparse);
        assert!(out.is_empty());
    }
}
