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

    /// Total dense-correction entries across all rows. Substrate-floor
    /// "how many outlier channels are we preserving in this layer?"
    /// query — the bigger this number, the less the layer behaves
    /// like a pure ternary lane.
    pub fn total_entry_count(&self) -> usize {
        self.rows.iter().map(|r| r.entries.len()).sum()
    }

    /// Maximum entries in any single row. Useful for spotting layers
    /// where one specific channel concentrates outlier preservation.
    /// Returns 0 for an empty island.
    pub fn max_entries_per_row(&self) -> usize {
        self.rows.iter().map(|r| r.entries.len()).max().unwrap_or(0)
    }

    /// Mean entries per row. Returns `None` for an empty island
    /// (no rows to average).
    pub fn mean_entries_per_row(&self) -> Option<f32> {
        let n = self.rows.len();
        if n == 0 {
            return None;
        }
        Some(self.total_entry_count() as f32 / n as f32)
    }

    /// Density: `total_entries / (rows × cols)`. Returns `None` if
    /// `cols == 0` or no rows. Substrate-floor expectation per the
    /// doctrine is < 0.05 (5%) — much higher means the residual
    /// correction is no longer a "small dense path" but a sibling
    /// dense layer.
    pub fn density(&self, cols: usize) -> Option<f32> {
        if self.rows.is_empty() || cols == 0 {
            return None;
        }
        Some(self.total_entry_count() as f32 / (self.rows.len() * cols) as f32)
    }

    /// True iff every row has zero entries.
    pub fn is_empty(&self) -> bool {
        self.rows.iter().all(|r| r.entries.is_empty())
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

    // ── Sparsity diagnostic tests (iter 116) ────────────────────────────────

    fn island_with_entries(entries_per_row: &[usize]) -> ResidualIsland {
        ResidualIsland {
            rows: entries_per_row
                .iter()
                .map(|&n| ResidualIslandRow {
                    entries: (0..n).map(|i| (i, i as f32)).collect(),
                })
                .collect(),
        }
    }

    #[test]
    fn total_entry_count_zero_on_empty_island() {
        let island = ResidualIsland::empty(5);
        assert_eq!(island.total_entry_count(), 0);
    }

    #[test]
    fn total_entry_count_sums_rows() {
        let island = island_with_entries(&[2, 0, 3, 1]);
        assert_eq!(island.total_entry_count(), 6);
    }

    #[test]
    fn max_entries_per_row_empty_island_zero() {
        let island = ResidualIsland::empty(3);
        assert_eq!(island.max_entries_per_row(), 0);
    }

    #[test]
    fn max_entries_per_row_picks_largest() {
        let island = island_with_entries(&[1, 4, 2, 0]);
        assert_eq!(island.max_entries_per_row(), 4);
    }

    #[test]
    fn max_entries_per_row_no_rows_returns_zero() {
        let island = ResidualIsland { rows: vec![] };
        assert_eq!(island.max_entries_per_row(), 0);
    }

    #[test]
    fn mean_entries_per_row_arithmetic() {
        // 4 rows with [1, 2, 3, 4] entries → total 10, mean 2.5.
        let island = island_with_entries(&[1, 2, 3, 4]);
        assert!((island.mean_entries_per_row().unwrap() - 2.5).abs() < 1e-6);
    }

    #[test]
    fn mean_entries_per_row_empty_island_returns_none() {
        let island = ResidualIsland { rows: vec![] };
        assert!(island.mean_entries_per_row().is_none());
    }

    #[test]
    fn density_matches_formula() {
        // 4 rows × 8 cols, 2 entries per row → 8 total / 32 = 0.25.
        let island = island_with_entries(&[2, 2, 2, 2]);
        let d = island.density(8).unwrap();
        assert!((d - 0.25).abs() < 1e-6);
    }

    #[test]
    fn density_zero_cols_returns_none() {
        let island = island_with_entries(&[1, 1]);
        assert!(island.density(0).is_none());
    }

    #[test]
    fn density_empty_rows_returns_none() {
        let island = ResidualIsland { rows: vec![] };
        assert!(island.density(10).is_none());
    }

    #[test]
    fn is_empty_true_when_all_rows_have_zero_entries() {
        let island = ResidualIsland::empty(5);
        assert!(island.is_empty());
    }

    #[test]
    fn is_empty_false_when_any_row_has_entries() {
        let island = island_with_entries(&[0, 0, 1, 0]);
        assert!(!island.is_empty());
    }

    #[test]
    fn doctrine_density_under_5_percent_in_typical_case() {
        // Doctrine pin: "small dense path" — typical density < 5%.
        // 1024 rows × 1024 cols, 2 entries per row = 2048 / 1_048_576
        // ≈ 0.002 (0.2%).
        let island = island_with_entries(&vec![2; 1024]);
        let d = island.density(1024).unwrap();
        assert!(d < 0.05, "doctrine violation: density {} >= 0.05", d);
    }
}
