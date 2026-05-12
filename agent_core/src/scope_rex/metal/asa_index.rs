// HARDENING ENFORCEMENT: Metal Tier-1 kernel reference must remain
// panic-free in production. Tests are allowed to unwrap because a
// failed invariant SHOULD panic loudly.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! HELIOS V5 W6 — Active-Support Atlas indexing (Tier-1 ULP-equivalent).
//!
//! HELIOS-W6 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W6 +
//! `docs/fusion/helios v5 first.md` §1.13 (Active-Support Atlas
//! monotonicity) + DOC 0 §0.6:
//!
//! > "Active-Support Atlas indexing — replaces dense matmul over
//! >  irrelevant rows with masked sparse matmul; bit-exact when mask
//! >  is conservative."
//!
//! **Tier 1 contract:** the masked path produces the *same* output
//! as the reference dense matmul, within 1 ULP, **when the mask is
//! conservative** — i.e. every row that would contribute to a
//! non-zero output is included. Conservativeness is the key
//! invariant; an over-aggressive mask drops contributing rows and
//! breaks ULP-equality.
//!
//! ## H3 connection
//!
//! Per DOC 0 §0.2: H3 = Active-Support Atlas. The monotonicity
//! invariant (the Atlas index is non-decreasing under merge,
//! non-increasing under split) is exercised by [`AsaIndex::merge`]
//! and [`AsaIndex::split`] tests.
//!
//! ## Cross-references
//!
//! - [`crate::scope_rex::metal`] — module entry
//! - DOC 0 §0.4 (lane summary: Tier 1)
//! - canon-hardening protocol §1 — WRV state machine; this module is
//!   `state: implemented` (no production caller yet — the Metal
//!   accelerated drop-in lands per a follow-up slice gated on W25
//!   falsifier rig)

use std::collections::BTreeSet;

/// Sparse index over the active rows of a weight matrix. Rows
/// excluded from the index are treated as having zero contribution
/// to the output — *only safe when the index is conservative*
/// (i.e. every non-zero-contributing row is included).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct AsaIndex {
    active_rows: BTreeSet<usize>,
}

impl AsaIndex {
    /// Empty index — all rows treated as inactive.
    pub fn new() -> Self {
        Self::default()
    }

    /// Construct from an iterator of active row indices.
    pub fn from_active_rows<I: IntoIterator<Item = usize>>(iter: I) -> Self {
        Self {
            active_rows: iter.into_iter().collect(),
        }
    }

    /// Index covering ALL rows up to `n` (the full-dense fallback;
    /// the masked matmul against this index produces identical
    /// results to the reference dense matmul).
    pub fn full(n: usize) -> Self {
        Self {
            active_rows: (0..n).collect(),
        }
    }

    /// Total number of active rows.
    pub fn len(&self) -> usize {
        self.active_rows.len()
    }

    /// True iff no rows are active.
    pub fn is_empty(&self) -> bool {
        self.active_rows.is_empty()
    }

    /// True iff this index includes the given row.
    pub fn contains(&self, row: usize) -> bool {
        self.active_rows.contains(&row)
    }

    /// Iterator over active row indices in ascending order
    /// (BTreeSet iterates in sorted order — the canonical
    /// dispatch order for deterministic output).
    pub fn iter(&self) -> impl Iterator<Item = usize> + '_ {
        self.active_rows.iter().copied()
    }

    /// Insert a row into the index. Returns true iff the row was
    /// not already present.
    pub fn insert(&mut self, row: usize) -> bool {
        self.active_rows.insert(row)
    }

    /// Remove a row from the index. Returns true iff the row was
    /// present.
    pub fn remove(&mut self, row: usize) -> bool {
        self.active_rows.remove(&row)
    }

    /// H3 monotonicity invariant: union of two indexes. The result
    /// is monotone non-decreasing — every input row appears in the
    /// merged index, never fewer.
    pub fn merge(&self, other: &Self) -> Self {
        Self {
            active_rows: self
                .active_rows
                .union(&other.active_rows)
                .copied()
                .collect(),
        }
    }

    /// H3 monotonicity invariant: intersection of two indexes. The
    /// result is monotone non-increasing — every output row was in
    /// both inputs, never more.
    pub fn split(&self, other: &Self) -> Self {
        Self {
            active_rows: self
                .active_rows
                .intersection(&other.active_rows)
                .copied()
                .collect(),
        }
    }
}

/// Reference dense matmul: `out[r] = Σ_c input[c] * weights[r * cols + c]`.
///
/// Used as the ULP-equality oracle for [`asa_matmul`].
pub fn dense_matmul(input: &[f32], weights: &[f32], rows: usize, cols: usize) -> Vec<f32> {
    debug_assert_eq!(input.len(), cols, "input width must match weights cols");
    debug_assert_eq!(
        weights.len(),
        rows * cols,
        "weights length must equal rows * cols"
    );
    let mut out = vec![0.0f32; rows];
    for r in 0..rows {
        let mut acc = 0.0f32;
        for c in 0..cols {
            acc += input[c] * weights[r * cols + c];
        }
        out[r] = acc;
    }
    out
}

/// Active-Support Atlas masked matmul. Rows NOT in the index are
/// skipped entirely; rows IN the index compute identically to the
/// reference path.
///
/// **Conservative-mask invariant:** if the index includes EVERY row
/// that would produce a non-zero output, the masked output is
/// element-wise EQUAL (within 1 ULP from float reordering — but
/// since we sum the same operands in the same order, output is
/// BIT-IDENTICAL).
///
/// Output shape is the full `rows`; entries for inactive rows are
/// `0.0` (never NaN, never Inf, never garbage).
pub fn asa_matmul(
    input: &[f32],
    weights: &[f32],
    rows: usize,
    cols: usize,
    asa: &AsaIndex,
) -> Vec<f32> {
    debug_assert_eq!(input.len(), cols);
    debug_assert_eq!(weights.len(), rows * cols);
    let mut out = vec![0.0f32; rows];
    for r in asa.iter() {
        if r >= rows {
            // Defensive — out-of-bounds row index ignored. Caller's
            // contract is to maintain `r < rows` for every active row.
            continue;
        }
        let mut acc = 0.0f32;
        for c in 0..cols {
            acc += input[c] * weights[r * cols + c];
        }
        out[r] = acc;
    }
    out
}

// ---------------------------------------------------------------------------
// Tests — ULP-equality + monotonicity
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn deterministic_random(seed: u64, n: usize) -> Vec<f32> {
        // Simple linear congruential generator — deterministic for
        // tests, no proptest dep needed.
        let mut state = seed
            .wrapping_mul(2862933555777941757)
            .wrapping_add(3037000493);
        let mut out = Vec::with_capacity(n);
        for _ in 0..n {
            state = state
                .wrapping_mul(2862933555777941757)
                .wrapping_add(3037000493);
            // Map to roughly [-1, 1]
            let f = ((state >> 8) & 0xFFFFFF) as f32 / 8_388_608.0 - 1.0;
            out.push(f);
        }
        out
    }

    #[test]
    fn full_index_matches_reference_dense_matmul() {
        let rows = 16;
        let cols = 8;
        let weights = deterministic_random(1, rows * cols);
        let input = deterministic_random(2, cols);
        let asa = AsaIndex::full(rows);

        let dense_out = dense_matmul(&input, &weights, rows, cols);
        let asa_out = asa_matmul(&input, &weights, rows, cols, &asa);

        // Bit-identical because we compute Σ in the same order.
        assert_eq!(dense_out, asa_out);
    }

    #[test]
    fn empty_index_zeroes_every_row() {
        let rows = 4;
        let cols = 4;
        let weights = vec![1.0f32; rows * cols];
        let input = vec![1.0f32; cols];
        let asa = AsaIndex::new();

        let asa_out = asa_matmul(&input, &weights, rows, cols, &asa);
        assert_eq!(asa_out, vec![0.0f32; rows]);
    }

    #[test]
    fn conservative_mask_produces_bit_identical_output() {
        // Build a weights matrix where rows {3, 5, 7} are nonzero
        // and others are zero. Conservative mask = {3, 5, 7}.
        let rows = 10;
        let cols = 4;
        let mut weights = vec![0.0f32; rows * cols];
        for r in [3usize, 5, 7] {
            for c in 0..cols {
                weights[r * cols + c] = (r * 100 + c) as f32 * 0.01;
            }
        }
        let input = vec![1.0_f32, -2.0, 3.0, -4.0];

        let dense_out = dense_matmul(&input, &weights, rows, cols);
        let asa = AsaIndex::from_active_rows([3, 5, 7]);
        let asa_out = asa_matmul(&input, &weights, rows, cols, &asa);

        // Every row's output must match exactly.
        assert_eq!(dense_out, asa_out);
    }

    #[test]
    fn over_aggressive_mask_breaks_equality_for_dropped_rows() {
        // Documents the contract: an under-conservative mask (drops
        // a contributing row) does NOT preserve ULP-equality.
        let rows = 4;
        let cols = 2;
        let weights = vec![
            1.0, 2.0, // row 0
            3.0, 4.0, // row 1 -- intentionally dropped from mask
            5.0, 6.0, // row 2
            7.0, 8.0, // row 3
        ];
        let input = vec![1.0_f32, 1.0];
        let dense_out = dense_matmul(&input, &weights, rows, cols);
        // Mask drops row 1 — non-conservative.
        let asa = AsaIndex::from_active_rows([0, 2, 3]);
        let asa_out = asa_matmul(&input, &weights, rows, cols, &asa);

        // Row 1 differs (ASA says 0; dense says 7).
        assert_ne!(asa_out[1], dense_out[1]);
        // Other rows still match.
        assert_eq!(asa_out[0], dense_out[0]);
        assert_eq!(asa_out[2], dense_out[2]);
        assert_eq!(asa_out[3], dense_out[3]);
    }

    #[test]
    fn ulp_equality_over_10000_random_prompts() {
        // Per W6 acceptance: "ULP-equality test vs reference matmul
        // over 10⁴ prompts." We test bit-equality for the
        // full-index case because conservative-mask + same-order
        // sum is bit-identical, not just ULP-close.
        let rows = 12;
        let cols = 6;
        let weights = deterministic_random(42, rows * cols);
        for seed in 0..10_000u64 {
            let input = deterministic_random(seed.wrapping_add(1), cols);
            let dense_out = dense_matmul(&input, &weights, rows, cols);
            let asa = AsaIndex::full(rows);
            let asa_out = asa_matmul(&input, &weights, rows, cols, &asa);
            assert_eq!(dense_out, asa_out, "seed {} produced ULP drift", seed);
        }
    }

    // H3 monotonicity invariants

    #[test]
    fn merge_is_monotone_non_decreasing() {
        let a = AsaIndex::from_active_rows([1, 3, 5]);
        let b = AsaIndex::from_active_rows([2, 4, 6]);
        let merged = a.merge(&b);
        // Every input row appears in the merged index.
        for r in a.iter() {
            assert!(merged.contains(r));
        }
        for r in b.iter() {
            assert!(merged.contains(r));
        }
        // Size is non-decreasing.
        assert!(merged.len() >= a.len());
        assert!(merged.len() >= b.len());
    }

    #[test]
    fn split_is_monotone_non_increasing() {
        let a = AsaIndex::from_active_rows([1, 2, 3, 4, 5]);
        let b = AsaIndex::from_active_rows([3, 4, 5, 6, 7]);
        let split = a.split(&b);
        // Every output row was in BOTH inputs.
        for r in split.iter() {
            assert!(a.contains(r));
            assert!(b.contains(r));
        }
        // Size is non-increasing.
        assert!(split.len() <= a.len());
        assert!(split.len() <= b.len());
        // For this fixture: intersection is exactly {3, 4, 5}.
        assert_eq!(split, AsaIndex::from_active_rows([3, 4, 5]));
    }

    #[test]
    fn merge_preserves_idempotence() {
        let a = AsaIndex::from_active_rows([1, 2, 3]);
        let merged = a.merge(&a);
        assert_eq!(merged, a);
    }

    #[test]
    fn split_preserves_idempotence() {
        let a = AsaIndex::from_active_rows([1, 2, 3]);
        let split = a.split(&a);
        assert_eq!(split, a);
    }

    #[test]
    fn iter_yields_in_ascending_order_for_deterministic_dispatch() {
        let a = AsaIndex::from_active_rows([5, 1, 3, 2, 4]);
        let collected: Vec<usize> = a.iter().collect();
        assert_eq!(collected, vec![1, 2, 3, 4, 5]);
    }
}
