//! Source:
//! - `docs/fusion/jordan's research/ternary kernel.md` §"Fused ternary projection
//!   with residual island add" — "Do not stop at 'ternary dot product.' Fuse the
//!   residual island correction into the same pass. That cuts memory traffic and
//!   makes the dense-perimeter idea real."
//! - Same file, §"The extraordinary method" / "Ternary Core with Residual
//!   Islands" — the canonical equation
//!   `y = BitLinear_ternary(x; W_t, s) + ResidualIsland(x; W_r)`.
//! - Ma et al. arXiv:2402.17764 (BitNet b1.58) — ternary alphabet for `W_t`.
//!
//! # Wave J1 kernel #3 — Fused ternary projection with residual island add
//!
//! The decode-path equation per `ternary kernel.md`:
//!
//! ```text
//! y = BitLinear_ternary(x; W_t, s) + ResidualIsland(x; W_r)
//! ```
//!
//! where
//! - `W_t` is the packed ternary weight tensor (one [`GemvBlock`] per block),
//! - `s` is the per-block scale,
//! - `W_r` is a very small dense correction path for "outlier channels in
//!   attention and MLP projections, small steering/residual patches,
//!   selected layers near the output" — i.e. the things that destabilize
//!   accuracy if you push them to ternary too aggressively.
//!
//! Doing this as two passes ([`super::gemv::gemv_block_scaled`] + a separate
//! dense add) doubles the memory traffic on the output vector. The fused
//! kernel writes `y` exactly once per row.
//!
//! ## Why per-row sparse dense format
//!
//! The doctrine calls out three populations that stay dense:
//! "outlier channels in attention and MLP projections", "small
//! steering/residual patches", "selected layers near the output". All three
//! collapse to "a small number of full-precision (row, col, weight) triples
//! per row" — 1-4 corrections per row is typical for outlier-channel
//! preservation. A per-row sparse list ([`ResidualIslandRow::entries`])
//! captures that shape exactly without paying the cost of a dense
//! correction matrix.

use super::gemv::{gemv_block_scaled, GemvBlock, GemvError, GEMV_BLOCK_TRITS};
use serde::{Deserialize, Serialize};

/// A single row of dense corrections. `entries` is a list of
/// `(column_index, fp32_weight)` pairs. Columns must be in range
/// `0..input.len()`; the kernel verifies this and surfaces
/// [`ResidualIslandError::ColumnOutOfRange`] on miss.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct ResidualIslandRow {
    pub entries: Vec<(usize, f32)>,
}

/// The full per-row sparse dense correction (`W_r` in the doctrine).
/// `rows.len()` MUST equal `weights.len()` from the paired
/// [`super::gemv::gemv_block_scaled`] call.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct ResidualIsland {
    pub rows: Vec<ResidualIslandRow>,
}

impl ResidualIsland {
    pub fn empty(row_count: usize) -> Self {
        Self {
            rows: vec![ResidualIslandRow::default(); row_count],
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub enum ResidualIslandError {
    /// `island.rows.len()` did not match `weights.len()`.
    RowCountMismatch { expected: usize, actual: usize },
    /// An `entries[(col, _)]` pair referenced a column outside
    /// `0..input.len()`.
    ColumnOutOfRange { row_index: usize, col: usize, input_len: usize },
    /// The underlying ternary GEMV rejected the call. Forwarded
    /// verbatim so the control room sees the original cause.
    Gemv(GemvError),
}

impl From<GemvError> for ResidualIslandError {
    fn from(err: GemvError) -> Self {
        ResidualIslandError::Gemv(err)
    }
}

/// Fused ternary projection with residual island add.
///
/// `output[r] = gemv_block_scaled(weights, input)[r]
///            + Σ_{(c, w) ∈ island.rows[r].entries} ( w · input[c] )`
///
/// Single pass per row; `output[r]` is written exactly once.
pub fn fused_gemv_residual(
    weights: &[Vec<GemvBlock>],
    input: &[f32],
    island: &ResidualIsland,
    output: &mut [f32],
) -> Result<(), ResidualIslandError> {
    if island.rows.len() != weights.len() {
        return Err(ResidualIslandError::RowCountMismatch {
            expected: weights.len(),
            actual: island.rows.len(),
        });
    }
    for (row_idx, row) in island.rows.iter().enumerate() {
        for &(col, _) in &row.entries {
            if col >= input.len() {
                return Err(ResidualIslandError::ColumnOutOfRange {
                    row_index: row_idx,
                    col,
                    input_len: input.len(),
                });
            }
        }
    }

    gemv_block_scaled(weights, input, output)?;

    for (row_idx, row) in island.rows.iter().enumerate() {
        let mut correction: f32 = 0.0;
        for &(col, weight) in &row.entries {
            correction += weight * input[col];
        }
        output[row_idx] += correction;
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

    fn single_row_pos_at_zero() -> Vec<Vec<GemvBlock>> {
        let mut trits = [Trit::Zero; GEMV_BLOCK_TRITS];
        trits[0] = Trit::Pos;
        vec![vec![block(&trits, 1.0)]]
    }

    #[test]
    fn empty_island_matches_pure_gemv() {
        let weights = single_row_pos_at_zero();
        let island = ResidualIsland::empty(1);
        let mut input = vec![0.0_f32; GEMV_BLOCK_TRITS];
        input[0] = 4.0;
        let mut fused = vec![0.0_f32];
        fused_gemv_residual(&weights, &input, &island, &mut fused).unwrap();

        let mut pure = vec![0.0_f32];
        gemv_block_scaled(&weights, &input, &mut pure).unwrap();

        assert_eq!(fused, pure);
    }

    #[test]
    fn empty_ternary_yields_pure_island_contribution() {
        let zero_row = vec![block(&[Trit::Zero; GEMV_BLOCK_TRITS], 1.0)];
        let weights = vec![zero_row];
        let island = ResidualIsland {
            rows: vec![ResidualIslandRow {
                entries: vec![(0, 0.5), (3, -0.25)],
            }],
        };
        let mut input = vec![0.0_f32; GEMV_BLOCK_TRITS];
        input[0] = 10.0;
        input[3] = 8.0;
        let mut output = vec![0.0_f32];
        fused_gemv_residual(&weights, &input, &island, &mut output).unwrap();
        assert!((output[0] - (0.5 * 10.0 + -0.25 * 8.0)).abs() < 1e-6);
    }

    #[test]
    fn combined_sums_ternary_and_dense() {
        let weights = single_row_pos_at_zero();
        let island = ResidualIsland {
            rows: vec![ResidualIslandRow { entries: vec![(2, 1.5)] }],
        };
        let mut input = vec![0.0_f32; GEMV_BLOCK_TRITS];
        input[0] = 4.0;
        input[2] = 6.0;
        let mut output = vec![0.0_f32];
        fused_gemv_residual(&weights, &input, &island, &mut output).unwrap();
        assert!((output[0] - (4.0 + 1.5 * 6.0)).abs() < 1e-6);
    }

    #[test]
    fn row_count_mismatch_errors() {
        let weights = single_row_pos_at_zero();
        let island = ResidualIsland::empty(2);
        let input = vec![0.0_f32; GEMV_BLOCK_TRITS];
        let mut output = vec![0.0_f32];
        let err =
            fused_gemv_residual(&weights, &input, &island, &mut output).unwrap_err();
        assert_eq!(
            err,
            ResidualIslandError::RowCountMismatch { expected: 1, actual: 2 }
        );
    }

    #[test]
    fn column_out_of_range_errors() {
        let weights = single_row_pos_at_zero();
        let island = ResidualIsland {
            rows: vec![ResidualIslandRow { entries: vec![(99, 1.0)] }],
        };
        let input = vec![0.0_f32; GEMV_BLOCK_TRITS];
        let mut output = vec![0.0_f32];
        let err =
            fused_gemv_residual(&weights, &input, &island, &mut output).unwrap_err();
        assert_eq!(
            err,
            ResidualIslandError::ColumnOutOfRange {
                row_index: 0,
                col: 99,
                input_len: GEMV_BLOCK_TRITS,
            }
        );
    }

    #[test]
    fn gemv_error_is_forwarded() {
        let weights = single_row_pos_at_zero();
        let island = ResidualIsland::empty(1);
        let short_input = vec![0.0_f32; GEMV_BLOCK_TRITS - 1];
        let mut output = vec![0.0_f32];
        let err =
            fused_gemv_residual(&weights, &short_input, &island, &mut output)
                .unwrap_err();
        match err {
            ResidualIslandError::Gemv(GemvError::InputColMismatch {
                expected,
                actual,
            }) => {
                assert_eq!(expected, GEMV_BLOCK_TRITS);
                assert_eq!(actual, GEMV_BLOCK_TRITS - 1);
            }
            other => panic!("expected forwarded InputColMismatch, got {:?}", other),
        }
    }

    #[test]
    fn multi_row_independent_corrections() {
        let mut trits_a = [Trit::Zero; GEMV_BLOCK_TRITS];
        trits_a[0] = Trit::Pos;
        let mut trits_b = [Trit::Zero; GEMV_BLOCK_TRITS];
        trits_b[0] = Trit::Neg;
        let weights = vec![vec![block(&trits_a, 1.0)], vec![block(&trits_b, 1.0)]];
        let island = ResidualIsland {
            rows: vec![
                ResidualIslandRow { entries: vec![(1, 0.5)] },
                ResidualIslandRow { entries: vec![(2, -1.0)] },
            ],
        };
        let mut input = vec![0.0_f32; GEMV_BLOCK_TRITS];
        input[0] = 4.0;
        input[1] = 6.0;
        input[2] = 3.0;
        let mut output = vec![0.0_f32; 2];
        fused_gemv_residual(&weights, &input, &island, &mut output).unwrap();
        assert!((output[0] - (4.0 + 0.5 * 6.0)).abs() < 1e-6);
        assert!((output[1] - (-4.0 + -1.0 * 3.0)).abs() < 1e-6);
    }
}
