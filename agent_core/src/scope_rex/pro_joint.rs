//! HELIOS V5 W16 — Pro-tier T-MAC + Active-Support Atlas joint path.
//!
//! HELIOS-W16 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W16:
//!
//! > "W16 — Pro-tier T-MAC + Atlas joint path — Lane 2 (Pro) only;
//! >  not in MAS bundle. CI: B3 Pro matrix. WRV: Pro build only."
//!
//! Composes the W6 Active-Support Atlas index with the W12 T-MAC
//! ternary GEMM to produce a single joint Pro-tier inference path:
//! sparse mask × ternary weights, with the same BIT-IDENTICAL
//! correctness contract as each path independently.
//!
//! Gated under `pro-build` feature. Never in MAS.
//!
//! ## Cross-references
//!
//! - [`crate::scope_rex::metal::asa_index`] — W6 sparse-mask matmul
//! - [`crate::scope_rex::kernels::t_mac`] — W12 ternary GEMM

#![cfg(feature = "pro-build")]

use crate::scope_rex::kernels::t_mac::TernaryWeight;
use crate::scope_rex::metal::asa_index::AsaIndex;

// `t_mac_reference` only referenced in tests; brought in there.

/// Pro-tier joint path — sparse-masked ternary GEMM. Combines the
/// Active-Support Atlas (W6) row mask with the T-MAC ternary GEMM
/// (W12) per row.
///
/// **BIT-IDENTICAL** with the dense T-MAC reference when the mask
/// is conservative (i.e. includes every row that would produce
/// non-zero output). The conservativeness invariant is the same as
/// W6 §asa_matmul.
pub fn pro_joint_matmul(
    input: &[f32],
    weights: &[TernaryWeight],
    rows: usize,
    cols: usize,
    asa: &AsaIndex,
) -> Vec<f32> {
    debug_assert_eq!(input.len(), cols);
    debug_assert_eq!(weights.len(), rows * cols);
    let mut out = vec![0.0f32; rows];
    for r in asa.iter() {
        if r >= rows {
            continue;
        }
        // Per-row T-MAC reference inlined to keep dispatch order
        // identical between the joint path and the dense ternary
        // reference (preserves BIT-IDENTICAL contract).
        let mut acc = 0.0f32;
        for c in 0..cols {
            let w = weights[r * cols + c].0;
            match w {
                1 => acc += input[c],
                -1 => acc -= input[c],
                _ => {}
            }
        }
        out[r] = acc;
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::scope_rex::kernels::t_mac::t_mac_reference;

    fn ternary_grid(values: &[i8]) -> Vec<TernaryWeight> {
        values
            .iter()
            .map(|&v| TernaryWeight::from_i8(v).unwrap())
            .collect()
    }

    #[test]
    fn full_atlas_index_matches_dense_ternary_reference() {
        let rows = 4;
        let cols = 3;
        let weights = ternary_grid(&[
            1, 0, -1, // row 0
            -1, 1, 0, // row 1
            0, 1, -1, // row 2
            1, 1, 1, // row 3
        ]);
        let input = vec![1.0_f32, 2.0, 3.0];
        let dense_out = t_mac_reference(&input, &weights, rows, cols);
        let asa = AsaIndex::full(rows);
        let joint_out = pro_joint_matmul(&input, &weights, rows, cols, &asa);
        assert_eq!(dense_out, joint_out);
    }

    #[test]
    fn conservative_mask_preserves_bit_identical_output() {
        let rows = 4;
        let cols = 3;
        // Rows 0 and 2 are zeroed out — non-contributing.
        let weights = ternary_grid(&[0, 0, 0, -1, 1, 0, 0, 0, 0, 1, 1, 1]);
        let input = vec![1.0_f32, 2.0, 3.0];
        let dense_out = t_mac_reference(&input, &weights, rows, cols);
        // Conservative mask = {1, 3} (every contributing row).
        let asa = AsaIndex::from_active_rows([1usize, 3]);
        let joint_out = pro_joint_matmul(&input, &weights, rows, cols, &asa);
        assert_eq!(dense_out, joint_out);
    }
}
