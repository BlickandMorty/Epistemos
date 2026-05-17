//! Source:
//! - `docs/fusion/jordan's research/ternary kernel.md` §"Block-scaled ternary GEMV"
//!   — "the first performance-critical kernel. For decode, matrix-vector multiply
//!   matters more than beautiful abstractions." Block carries packed trits +
//!   one fp16/fp32 block scale + optional nonzero-count metadata.
//! - Ma et al., "The Era of 1-bit LLMs: All Large Language Models are in 1.58 Bits"
//!   (BitNet b1.58), arXiv:2402.17764 — ternary `{-1, 0, +1}` weights with a
//!   group-mean (`gamma`) scale at the GEMM output.
//! - Wei et al., "T-MAC: CPU Renaissance via Table Lookup for Low-Bit LLM Deployment",
//!   arXiv:2407.00088 — LUT-centric ternary GEMM (prefill / batch path); the
//!   J1 GEMV is its decode-path sibling.
//!
//! # Wave J1 kernel #2 — Block-scaled ternary GEMV (CPU reference)
//!
//! Per the kernel-portfolio order in `ternary kernel.md`, this is the second
//! kernel after [`super::pack`] / [`super::trit`] (kernel #1). It is the
//! decode-path performance hot-spot: on-device chat is decode-bound and
//! memory-bandwidth-bound, and per-token Q/K/V/O + MLP projections all
//! collapse to matrix-vector multiplies over ternary weight matrices.
//!
//! ## Block layout
//!
//! A weight matrix `W ∈ {-1, 0, +1}^(rows × cols)` is partitioned into rows
//! of contiguous blocks, each block carrying [`GEMV_BLOCK_TRITS`] = 16 trits
//! packed via [`super::pack::pack_trits_u32`]. The block also carries a
//! per-block fp32 scale (`s`) — the absmean group scale of BitNet b1.58 (Ma
//! et al.) — and a nonzero-count sparsity hint for downstream skip-zero
//! optimizations.
//!
//! Per row, `cols / GEMV_BLOCK_TRITS` blocks. Callers MUST pre-pad input
//! columns to a multiple of [`GEMV_BLOCK_TRITS`]; the kernel rejects shape
//! mismatches with [`GemvError`] instead of silently truncating.
//!
//! ## Math
//!
//! For row `r`:
//!
//! ```text
//! y[r] = Σ_b ( s[r, b] · Σ_{t=0..16} ( trit_value(W[r, b, t]) · x[b*16 + t] ) )
//! ```
//!
//! Float accumulation is fp32 throughout for this reference. The Metal port
//! (`Epistemos/Shaders/ternary_gemv.metal`) lowers the inner reduction to
//! the GPU but keeps the same per-block scale semantics.
//!
//! ## Why GEMV and not GEMM
//!
//! Sibling crates already cover the GEMM lane:
//! `agent_core/src/scope_rex/kernels/t_mac.rs` (Helios V5 W12 — T-MAC LUT
//! GEMM, prefill path), `bitnet.rs` (W13 — BitNet b1.58 absmean quantize),
//! `sparse_ternary_gemm.rs` (W14 — sparse format CSR GEMM). The J1 GEMV
//! lives on the decode side where `batch=1` collapses GEMM to GEMV and
//! the kernel-design trade-offs shift from compute-bound to bandwidth-bound.
//!
//! ## HARDWARE-BUDGET
//!
//! Per §6 of the driver doc, target hardware is M2 Pro 16 GB. This CPU
//! reference has no hardware ceiling (runs on any host). The Metal shader
//! sibling (`ternary_gemv.metal`) will need the M2 Pro 16 GB validation
//! pass once dispatch wiring lands; until then it is a doctrinal stub.

use super::pack::{unpack_trits_u32, PackError, TRITS_PER_U32};
use serde::{Deserialize, Serialize};

/// Number of trits per GEMV block. Pinned to [`TRITS_PER_U32`] so the
/// packed representation and the GEMV block stride agree byte-for-byte.
pub const GEMV_BLOCK_TRITS: usize = TRITS_PER_U32;

/// A single GEMV block: packed trits + per-block scale + sparsity hint.
///
/// Per `ternary kernel.md` §"Block-scaled ternary GEMV":
/// > Each block should have: packed trits, one fp16 or fp32 block scale,
/// > optional sparse mask or "nonzero count" metadata.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct GemvBlock {
    pub packed: u32,
    pub scale: f32,
    pub nonzero_count: u8,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum GemvError {
    /// `output.len()` did not match the row count of `weights`.
    OutputRowMismatch { expected: usize, actual: usize },
    /// `input.len()` did not match `blocks_per_row * GEMV_BLOCK_TRITS`.
    InputColMismatch { expected: usize, actual: usize },
    /// Rows had differing block counts. Callers must pad to a uniform
    /// `blocks_per_row` before invoking the kernel.
    RaggedRows { row_index: usize, this_row: usize, first_row: usize },
    /// A packed-trit slot held the reserved `0b11` pattern. Surfaces the
    /// control-room hook from [`super::pack::PackError`].
    Pack(PackError),
}

impl From<PackError> for GemvError {
    fn from(err: PackError) -> Self {
        GemvError::Pack(err)
    }
}

impl GemvBlock {
    /// Sparsity fraction `(GEMV_BLOCK_TRITS − nonzero_count) /
    /// GEMV_BLOCK_TRITS`. A block with all zeros has sparsity 1.0;
    /// a block with every slot nonzero has sparsity 0.0. Useful as
    /// the input to skip-zero memory-bandwidth optimizers.
    pub fn sparsity_fraction(&self) -> f32 {
        let nz = (self.nonzero_count as usize).min(GEMV_BLOCK_TRITS);
        (GEMV_BLOCK_TRITS - nz) as f32 / GEMV_BLOCK_TRITS as f32
    }

    /// Bytes-on-the-wire for one GemvBlock: 4 (packed u32) + 4 (fp32
    /// scale) + 1 (u8 nonzero_count) = 9 bytes. Padding to native
    /// alignment lives at the caller's container layout.
    pub const fn effective_bytes() -> usize {
        4 + 4 + 1
    }
}

/// Number of GemvBlocks needed for a `rows × cols` weight matrix.
/// `cols` MUST be a multiple of [`GEMV_BLOCK_TRITS`] — the kernel
/// rejects unpadded callers. Returns `None` if either dimension is 0
/// or cols is not a multiple of the block stride.
pub fn dense_block_count(rows: usize, cols: usize) -> Option<usize> {
    if rows == 0 || cols == 0 {
        return None;
    }
    if cols % GEMV_BLOCK_TRITS != 0 {
        return None;
    }
    Some(rows * (cols / GEMV_BLOCK_TRITS))
}

/// Block-scaled ternary matrix-vector multiply (CPU reference).
///
/// `weights`: row-major. `weights[r]` is the block-list for row `r`.
/// All rows MUST share the same block count (uniform `blocks_per_row`).
///
/// `input`: length must equal `blocks_per_row * GEMV_BLOCK_TRITS`.
/// `output`: length must equal `weights.len()`; overwritten by the result
/// (NOT accumulated into — callers wanting `y += W·x` add the prior `y`
/// outside this call).
pub fn gemv_block_scaled(
    weights: &[Vec<GemvBlock>],
    input: &[f32],
    output: &mut [f32],
) -> Result<(), GemvError> {
    if output.len() != weights.len() {
        return Err(GemvError::OutputRowMismatch {
            expected: weights.len(),
            actual: output.len(),
        });
    }
    if weights.is_empty() {
        return Ok(());
    }

    let blocks_per_row = weights[0].len();
    let expected_cols = blocks_per_row * GEMV_BLOCK_TRITS;
    if input.len() != expected_cols {
        return Err(GemvError::InputColMismatch {
            expected: expected_cols,
            actual: input.len(),
        });
    }

    for (row_idx, row_blocks) in weights.iter().enumerate() {
        if row_blocks.len() != blocks_per_row {
            return Err(GemvError::RaggedRows {
                row_index: row_idx,
                this_row: row_blocks.len(),
                first_row: blocks_per_row,
            });
        }
        let mut accum: f32 = 0.0;
        for (block_idx, block) in row_blocks.iter().enumerate() {
            let col_base = block_idx * GEMV_BLOCK_TRITS;
            let trits = unpack_trits_u32(block.packed)?;
            let mut block_dot: f32 = 0.0;
            for (t_idx, trit) in trits.iter().enumerate() {
                let weight = trit.as_i8() as f32;
                if weight != 0.0 {
                    block_dot += weight * input[col_base + t_idx];
                }
            }
            accum += block.scale * block_dot;
        }
        output[row_idx] = accum;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
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
    fn zero_rows_returns_ok_with_empty_output() {
        let weights: Vec<Vec<GemvBlock>> = vec![];
        let input = vec![1.0_f32; GEMV_BLOCK_TRITS];
        let mut output: Vec<f32> = vec![];
        assert!(gemv_block_scaled(&weights, &input, &mut output).is_ok());
        assert!(output.is_empty());
    }

    #[test]
    fn all_zero_weights_yield_zero_output() {
        let row: Vec<GemvBlock> = vec![block(&[Trit::Zero; GEMV_BLOCK_TRITS], 1.0)];
        let weights = vec![row];
        let input = vec![3.7_f32; GEMV_BLOCK_TRITS];
        let mut output = vec![99.0_f32];
        gemv_block_scaled(&weights, &input, &mut output).unwrap();
        assert_eq!(output[0], 0.0);
    }

    #[test]
    fn pos_one_trit_at_index_zero_picks_first_input() {
        let mut trits = [Trit::Zero; GEMV_BLOCK_TRITS];
        trits[0] = Trit::Pos;
        let row = vec![block(&trits, 1.0)];
        let weights = vec![row];
        let mut input = vec![0.0_f32; GEMV_BLOCK_TRITS];
        input[0] = 7.5;
        let mut output = vec![0.0_f32];
        gemv_block_scaled(&weights, &input, &mut output).unwrap();
        assert_eq!(output[0], 7.5);
    }

    #[test]
    fn neg_one_trit_negates_input() {
        let mut trits = [Trit::Zero; GEMV_BLOCK_TRITS];
        trits[5] = Trit::Neg;
        let row = vec![block(&trits, 1.0)];
        let weights = vec![row];
        let mut input = vec![0.0_f32; GEMV_BLOCK_TRITS];
        input[5] = 4.0;
        let mut output = vec![0.0_f32];
        gemv_block_scaled(&weights, &input, &mut output).unwrap();
        assert_eq!(output[0], -4.0);
    }

    #[test]
    fn scale_multiplies_block_contribution() {
        let mut trits = [Trit::Zero; GEMV_BLOCK_TRITS];
        trits[0] = Trit::Pos;
        let row = vec![block(&trits, 0.25)];
        let weights = vec![row];
        let mut input = vec![0.0_f32; GEMV_BLOCK_TRITS];
        input[0] = 8.0;
        let mut output = vec![0.0_f32];
        gemv_block_scaled(&weights, &input, &mut output).unwrap();
        assert_eq!(output[0], 2.0);
    }

    #[test]
    fn two_blocks_per_row_sum_correctly() {
        let mut trits_a = [Trit::Zero; GEMV_BLOCK_TRITS];
        trits_a[0] = Trit::Pos;
        let mut trits_b = [Trit::Zero; GEMV_BLOCK_TRITS];
        trits_b[0] = Trit::Pos;
        let row = vec![block(&trits_a, 1.0), block(&trits_b, 1.0)];
        let weights = vec![row];
        let mut input = vec![0.0_f32; 2 * GEMV_BLOCK_TRITS];
        input[0] = 3.0;
        input[GEMV_BLOCK_TRITS] = 5.0;
        let mut output = vec![0.0_f32];
        gemv_block_scaled(&weights, &input, &mut output).unwrap();
        assert_eq!(output[0], 8.0);
    }

    #[test]
    fn multiple_rows_independent() {
        let mut t_row0 = [Trit::Zero; GEMV_BLOCK_TRITS];
        t_row0[0] = Trit::Pos;
        let mut t_row1 = [Trit::Zero; GEMV_BLOCK_TRITS];
        t_row1[0] = Trit::Neg;
        let weights = vec![vec![block(&t_row0, 1.0)], vec![block(&t_row1, 1.0)]];
        let mut input = vec![0.0_f32; GEMV_BLOCK_TRITS];
        input[0] = 2.5;
        let mut output = vec![0.0_f32; 2];
        gemv_block_scaled(&weights, &input, &mut output).unwrap();
        assert_eq!(output[0], 2.5);
        assert_eq!(output[1], -2.5);
    }

    #[test]
    fn output_row_mismatch_errors() {
        let row = vec![block(&[Trit::Zero; GEMV_BLOCK_TRITS], 1.0)];
        let weights = vec![row];
        let input = vec![0.0_f32; GEMV_BLOCK_TRITS];
        let mut output = vec![0.0_f32; 2];
        let err = gemv_block_scaled(&weights, &input, &mut output).unwrap_err();
        assert_eq!(
            err,
            GemvError::OutputRowMismatch { expected: 1, actual: 2 }
        );
    }

    #[test]
    fn input_col_mismatch_errors() {
        let row = vec![block(&[Trit::Zero; GEMV_BLOCK_TRITS], 1.0)];
        let weights = vec![row];
        let input = vec![0.0_f32; GEMV_BLOCK_TRITS - 1];
        let mut output = vec![0.0_f32];
        let err = gemv_block_scaled(&weights, &input, &mut output).unwrap_err();
        assert_eq!(
            err,
            GemvError::InputColMismatch {
                expected: GEMV_BLOCK_TRITS,
                actual: GEMV_BLOCK_TRITS - 1,
            }
        );
    }

    #[test]
    fn ragged_rows_errors() {
        let row_a = vec![block(&[Trit::Zero; GEMV_BLOCK_TRITS], 1.0)];
        let row_b = vec![
            block(&[Trit::Zero; GEMV_BLOCK_TRITS], 1.0),
            block(&[Trit::Zero; GEMV_BLOCK_TRITS], 1.0),
        ];
        let weights = vec![row_a, row_b];
        let input = vec![0.0_f32; GEMV_BLOCK_TRITS];
        let mut output = vec![0.0_f32; 2];
        let err = gemv_block_scaled(&weights, &input, &mut output).unwrap_err();
        assert_eq!(
            err,
            GemvError::RaggedRows { row_index: 1, this_row: 2, first_row: 1 }
        );
    }

    #[test]
    fn reserved_pack_pattern_surfaces() {
        let mut bad_block = block(&[Trit::Zero; GEMV_BLOCK_TRITS], 1.0);
        bad_block.packed |= 0b11 << 4;
        let weights = vec![vec![bad_block]];
        let input = vec![1.0_f32; GEMV_BLOCK_TRITS];
        let mut output = vec![0.0_f32];
        let err = gemv_block_scaled(&weights, &input, &mut output).unwrap_err();
        match err {
            GemvError::Pack(PackError::ReservedPattern { index }) => {
                assert_eq!(index, 2);
            }
            other => panic!("expected ReservedPattern, got {:?}", other),
        }
    }

    #[test]
    fn mixed_trits_matches_dense_reference() {
        let mut trits = [Trit::Zero; GEMV_BLOCK_TRITS];
        trits[0] = Trit::Pos;
        trits[3] = Trit::Neg;
        trits[7] = Trit::Pos;
        trits[15] = Trit::Neg;
        let row = vec![block(&trits, 0.5)];
        let weights = vec![row];
        let input: Vec<f32> =
            (0..GEMV_BLOCK_TRITS).map(|i| (i as f32) + 1.0).collect();
        let mut output = vec![0.0_f32];
        gemv_block_scaled(&weights, &input, &mut output).unwrap();
        let expected = 0.5 * (input[0] - input[3] + input[7] - input[15]);
        assert!((output[0] - expected).abs() < 1e-6);
    }

    #[test]
    fn nonzero_count_metadata_carries_through() {
        let mut trits = [Trit::Zero; GEMV_BLOCK_TRITS];
        trits[0] = Trit::Pos;
        trits[1] = Trit::Neg;
        trits[2] = Trit::Pos;
        let b = block(&trits, 1.0);
        assert_eq!(b.nonzero_count, 3);
    }

    // ── sparsity_fraction + effective_bytes + dense_block_count (iter 113) ──

    fn approx(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn sparsity_fraction_all_zero_is_one() {
        let b = GemvBlock { packed: 0, scale: 1.0, nonzero_count: 0 };
        assert!(approx(b.sparsity_fraction(), 1.0, 1e-6));
    }

    #[test]
    fn sparsity_fraction_all_nonzero_is_zero() {
        let b = GemvBlock { packed: 0, scale: 1.0, nonzero_count: GEMV_BLOCK_TRITS as u8 };
        assert!(approx(b.sparsity_fraction(), 0.0, 1e-6));
    }

    #[test]
    fn sparsity_fraction_half_nonzero_is_half() {
        let b = GemvBlock { packed: 0, scale: 1.0, nonzero_count: (GEMV_BLOCK_TRITS / 2) as u8 };
        assert!(approx(b.sparsity_fraction(), 0.5, 1e-6));
    }

    #[test]
    fn sparsity_fraction_clamps_at_one_if_count_overflows() {
        // nonzero_count > GEMV_BLOCK_TRITS is a caller bug; the
        // sparsity fraction clamps to 0.0 (saturates at "fully dense")
        // rather than going negative.
        let b = GemvBlock { packed: 0, scale: 1.0, nonzero_count: 250 };
        assert!(approx(b.sparsity_fraction(), 0.0, 1e-6));
    }

    #[test]
    fn effective_bytes_is_nine() {
        // 4 (packed) + 4 (scale) + 1 (nonzero_count).
        assert_eq!(GemvBlock::effective_bytes(), 9);
    }

    #[test]
    fn dense_block_count_zero_dim_returns_none() {
        assert!(dense_block_count(0, 16).is_none());
        assert!(dense_block_count(4, 0).is_none());
    }

    #[test]
    fn dense_block_count_unpadded_cols_returns_none() {
        // 17 is not a multiple of GEMV_BLOCK_TRITS = 16.
        assert!(dense_block_count(4, 17).is_none());
    }

    #[test]
    fn dense_block_count_matches_formula() {
        // 4 rows × 32 cols = 4 × 2 = 8 blocks.
        assert_eq!(dense_block_count(4, 32), Some(8));
        // 1 × 16 = 1.
        assert_eq!(dense_block_count(1, 16), Some(1));
        // 1024 × 1024 = 1024 × 64 = 65_536.
        assert_eq!(dense_block_count(1024, 1024), Some(65_536));
    }

    #[test]
    fn dense_block_count_byte_estimate_matches_effective_bytes() {
        // For a 1024×1024 matrix, total wire bytes = block_count × 9.
        let blocks = dense_block_count(1024, 1024).unwrap();
        let bytes = blocks * GemvBlock::effective_bytes();
        assert_eq!(bytes, 589_824); // 65_536 × 9
    }
}
