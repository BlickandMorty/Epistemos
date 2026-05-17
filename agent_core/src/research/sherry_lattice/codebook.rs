//! Source:
//! - Huang et al., arXiv:2601.07892 — Sherry 3:4 sparse ternary
//!   (≈1.19 bits/weight).
//! - Conway, J. H., Sloane, N. J. A., "Sphere Packings, Lattices and
//!   Groups", Springer 1988 — E8 (8-dim) + Leech (24-dim) shaping
//!   gains.
//! - `docs/fusion/jordan's research/helios v3.md` Part II T_K row +
//!   T_Q row — codebook rate-distortion table.
//! - Companions: [`super::sparse_ternary`] (Sherry 3:4),
//!   [`super::e8`] (E8 nearest-point), [`super::leech`] (Leech-24
//!   substrate).
//!
//! # Wave J7 — Codebook family envelope
//!
//! Each of the 3 J7 codebook families ships its own substrate kernel.
//! This file is the typed envelope that catalogs them with their
//! canonical metadata (dimension, shaping gain, rate) so the residency
//! layer / KV-cache quantizer can select a codebook by bit budget
//! without re-deriving the rate-distortion numbers from each kernel.
//!
//! ## Codebook table (canonical, per Helios v3 Part II)
//!
//! | Codebook    | Dim | Bits/weight | Shaping gain G | Source                |
//! |-------------|-----|-------------|----------------|-----------------------|
//! | Sherry34    | 4   | 1.19        | n/a (sparse)   | arXiv:2601.07892      |
//! | E8          | 8   | ~3.0        | 0.0717         | Conway-Sloane Ch. 4   |
//! | Leech24     | 24  | ~4.0        | 0.0658         | Conway-Sloane Ch. 24  |
//!
//! Sherry is sparsity-based and has no shaping-gain in the Conway-Sloane
//! sense (it doesn't operate on a lattice). E8 and Leech do, with Leech
//! the gold standard but requiring Golay decoding (still substrate-only
//! per iter 71). The selector returns the lowest-rate codebook that
//! fits the caller's bit budget, with Sherry winning all sub-2-bit
//! budgets, E8 winning the 2-3.5 bit window, and Leech winning above.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum CodebookFamily {
    Sherry34,
    E8,
    Leech24,
}

impl CodebookFamily {
    pub const ALL: [CodebookFamily; 3] = [
        CodebookFamily::Sherry34,
        CodebookFamily::E8,
        CodebookFamily::Leech24,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            CodebookFamily::Sherry34 => "sherry_3_4",
            CodebookFamily::E8 => "e8",
            CodebookFamily::Leech24 => "leech_24",
        }
    }

    /// Lattice dimension. Sherry is `4` because its codec operates on
    /// 4-weight groups, even though Sherry is sparsity-based rather
    /// than lattice-based.
    pub const fn dimension(self) -> usize {
        match self {
            CodebookFamily::Sherry34 => 4,
            CodebookFamily::E8 => 8,
            CodebookFamily::Leech24 => super::leech::LEECH_DIMENSION,
        }
    }

    /// Canonical per-weight rate in bits, per Helios v3 Part II table.
    /// Sherry is `log₂(3³) / 4 ≈ 1.19` (3 ternary slots + 1 forced
    /// zero per 4-weight group). E8 and Leech rates are typical
    /// operating-point values from the Conway-Sloane Ch. 20 nested-
    /// lattice VQ analysis.
    pub fn bits_per_weight(self) -> f64 {
        match self {
            CodebookFamily::Sherry34 => (27.0_f64).log2() / 4.0,
            CodebookFamily::E8 => 3.0,
            CodebookFamily::Leech24 => 4.0,
        }
    }

    /// Second-moment shaping gain `G` per Conway-Sloane. Sherry returns
    /// `None` because it's not a lattice-VQ family and the Conway-Sloane
    /// shaping-gain quantity isn't defined for it.
    pub fn shaping_gain(self) -> Option<f64> {
        match self {
            CodebookFamily::Sherry34 => None,
            CodebookFamily::E8 => Some(0.0717),
            CodebookFamily::Leech24 => Some(super::leech::LEECH_SHAPING_GAIN),
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|f| f.code() == code)
    }

    /// Predicate: this family is lattice-VQ-based (E8 or Leech24).
    /// Cross-surface invariant: `is_lattice_based() iff
    /// shaping_gain().is_some()` (Conway-Sloane shaping gain is only
    /// defined for lattice families).
    pub const fn is_lattice_based(self) -> bool {
        matches!(self, CodebookFamily::E8 | CodebookFamily::Leech24)
    }

    /// Predicate: this family is sparsity-based (Sherry34).
    /// Cross-surface invariant: `is_lattice_based XOR is_sparsity_based`
    /// partitions all variants.
    pub const fn is_sparsity_based(self) -> bool {
        matches!(self, CodebookFamily::Sherry34)
    }
}

impl CodebookSelectError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            CodebookSelectError::BudgetBelowFloor { .. } => "budget_below_floor",
            CodebookSelectError::NonFiniteBudget => "non_finite_budget",
        }
    }

    pub const fn is_budget_below_floor(&self) -> bool {
        matches!(self, CodebookSelectError::BudgetBelowFloor { .. })
    }

    /// Cross-surface invariant: `is_budget_below_floor XOR
    /// is_non_finite_budget` partitions all variants.
    pub const fn is_non_finite_budget(&self) -> bool {
        matches!(self, CodebookSelectError::NonFiniteBudget)
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum CodebookSelectError {
    BudgetBelowFloor { budget_bits: f64, floor: f64 },
    NonFiniteBudget,
}

/// Select the codebook family that fits within `budget_bits` per
/// weight, preferring the lowest-rate (= most-compressed) family
/// that still meets the budget. Sherry wins all budgets ≥ ~1.19;
/// E8 wins budgets ≥ 3.0; Leech wins budgets ≥ 4.0. The lowest
/// admissible budget is the Sherry floor (`~1.19`); below that we
/// reject — substrate doesn't ship a sub-Sherry option.
pub fn select_by_budget(budget_bits: f64) -> Result<CodebookFamily, CodebookSelectError> {
    if !budget_bits.is_finite() {
        return Err(CodebookSelectError::NonFiniteBudget);
    }
    let sherry_floor = CodebookFamily::Sherry34.bits_per_weight();
    if budget_bits < sherry_floor {
        return Err(CodebookSelectError::BudgetBelowFloor {
            budget_bits,
            floor: sherry_floor,
        });
    }
    // Prefer the most-compressed admissible family. Sherry is most-
    // compressed and always wins if its floor is met.
    if budget_bits < CodebookFamily::E8.bits_per_weight() {
        Ok(CodebookFamily::Sherry34)
    } else if budget_bits < CodebookFamily::Leech24.bits_per_weight() {
        Ok(CodebookFamily::E8)
    } else {
        Ok(CodebookFamily::Leech24)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn three_distinct_families() {
        let s: std::collections::HashSet<_> = CodebookFamily::ALL.iter().copied().collect();
        assert_eq!(s.len(), 3);
    }

    #[test]
    fn codes_unique_and_snake_case() {
        let mut s = std::collections::HashSet::new();
        for f in CodebookFamily::ALL.iter() {
            let c = f.code();
            assert!(s.insert(c));
            assert!(c.chars().all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || ch == '_'));
        }
    }

    #[test]
    fn dimensions_match_canonical() {
        assert_eq!(CodebookFamily::Sherry34.dimension(), 4);
        assert_eq!(CodebookFamily::E8.dimension(), 8);
        assert_eq!(CodebookFamily::Leech24.dimension(), 24);
    }

    #[test]
    fn sherry_rate_is_log2_27_over_4() {
        let r = CodebookFamily::Sherry34.bits_per_weight();
        let expected = (27.0_f64).log2() / 4.0;
        assert!((r - expected).abs() < 1e-12);
        // Doctrine-doc "~1.19 bits/weight" pin.
        assert!((r - 1.189).abs() < 0.01);
    }

    #[test]
    fn rates_strictly_increasing_across_families() {
        let s = CodebookFamily::Sherry34.bits_per_weight();
        let e = CodebookFamily::E8.bits_per_weight();
        let l = CodebookFamily::Leech24.bits_per_weight();
        assert!(s < e, "{} not < {}", s, e);
        assert!(e < l, "{} not < {}", e, l);
    }

    #[test]
    fn shaping_gain_sherry_is_none() {
        assert_eq!(CodebookFamily::Sherry34.shaping_gain(), None);
    }

    #[test]
    fn shaping_gain_e8_is_pinned() {
        let g = CodebookFamily::E8.shaping_gain().unwrap();
        assert!((g - 0.0717).abs() < 1e-9);
    }

    #[test]
    fn shaping_gain_leech_sources_from_leech_module() {
        assert_eq!(
            CodebookFamily::Leech24.shaping_gain(),
            Some(super::super::leech::LEECH_SHAPING_GAIN)
        );
    }

    #[test]
    fn select_below_floor_rejected() {
        assert!(matches!(
            select_by_budget(1.0).unwrap_err(),
            CodebookSelectError::BudgetBelowFloor { .. }
        ));
    }

    #[test]
    fn select_nan_rejected() {
        assert!(matches!(
            select_by_budget(f64::NAN).unwrap_err(),
            CodebookSelectError::NonFiniteBudget
        ));
    }

    #[test]
    fn select_at_sherry_floor_returns_sherry() {
        let f = select_by_budget(1.19).unwrap();
        assert_eq!(f, CodebookFamily::Sherry34);
    }

    #[test]
    fn select_2_bits_returns_sherry() {
        assert_eq!(select_by_budget(2.0).unwrap(), CodebookFamily::Sherry34);
    }

    #[test]
    fn select_3_bits_returns_e8() {
        assert_eq!(select_by_budget(3.0).unwrap(), CodebookFamily::E8);
    }

    #[test]
    fn select_3_5_bits_returns_e8() {
        assert_eq!(select_by_budget(3.5).unwrap(), CodebookFamily::E8);
    }

    #[test]
    fn select_4_bits_returns_leech() {
        assert_eq!(select_by_budget(4.0).unwrap(), CodebookFamily::Leech24);
    }

    #[test]
    fn select_high_bits_returns_leech() {
        assert_eq!(select_by_budget(16.0).unwrap(), CodebookFamily::Leech24);
    }

    #[test]
    fn family_serde_roundtrip() {
        let f = CodebookFamily::Leech24;
        let json = serde_json::to_string(&f).unwrap();
        let back: CodebookFamily = serde_json::from_str(&json).unwrap();
        assert_eq!(f, back);
    }

    // ── diagnostic surface (iter 175) ────────────────────────────────────────

    #[test]
    fn family_from_code_roundtrips_all() {
        for f in CodebookFamily::ALL.iter().copied() {
            assert_eq!(CodebookFamily::from_code(f.code()), Some(f));
        }
        assert_eq!(CodebookFamily::from_code("Sherry34"), None);
        assert_eq!(CodebookFamily::from_code(""), None);
    }

    #[test]
    fn lattice_and_sparsity_partition_families() {
        // Cross-surface invariant: is_lattice_based XOR is_sparsity_based.
        for f in CodebookFamily::ALL.iter().copied() {
            assert_ne!(f.is_lattice_based(), f.is_sparsity_based());
        }
        assert!(CodebookFamily::E8.is_lattice_based());
        assert!(CodebookFamily::Leech24.is_lattice_based());
        assert!(CodebookFamily::Sherry34.is_sparsity_based());
    }

    #[test]
    fn lattice_based_aligns_with_shaping_gain_some() {
        // Cross-surface invariant: is_lattice_based iff shaping_gain().is_some().
        for f in CodebookFamily::ALL.iter().copied() {
            assert_eq!(f.is_lattice_based(), f.shaping_gain().is_some());
        }
    }

    #[test]
    fn select_error_cause_distinct() {
        let variants = [
            CodebookSelectError::BudgetBelowFloor { budget_bits: 0.5, floor: 1.19 },
            CodebookSelectError::NonFiniteBudget,
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 2);
    }

    #[test]
    fn select_error_classifiers_partition() {
        // Cross-surface invariant: is_budget_below_floor XOR is_non_finite_budget.
        for e in [
            CodebookSelectError::BudgetBelowFloor { budget_bits: 0.5, floor: 1.19 },
            CodebookSelectError::NonFiniteBudget,
        ] {
            assert_ne!(e.is_budget_below_floor(), e.is_non_finite_budget());
        }
    }

    #[test]
    fn real_select_errors_carry_matching_classifier() {
        // Cross-surface: select_by_budget errors carry matching predicates.
        let err = select_by_budget(0.5).unwrap_err();
        assert!(err.is_budget_below_floor());
        assert_eq!(err.cause(), "budget_below_floor");

        let err = select_by_budget(f64::NAN).unwrap_err();
        assert!(err.is_non_finite_budget());
        assert_eq!(err.cause(), "non_finite_budget");

        // Infinity is also non-finite, should hit the same branch.
        let err = select_by_budget(f64::INFINITY).unwrap_err();
        assert!(err.is_non_finite_budget());
    }
}
