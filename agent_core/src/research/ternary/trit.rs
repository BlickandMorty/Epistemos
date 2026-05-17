//! Source: `docs/fusion/jordan's research/ternary kernel.md` §"Ternary packing
//! and unpacking" — three-valued logic over `{-1, 0, +1}`.

use serde::{Deserialize, Serialize};

/// A ternary digit in the BitNet b1.58 alphabet.
///
/// Storage is one byte for in-memory convenience; the wire / packed
/// representation is two bits per trit via [`super::pack`].
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[repr(i8)]
pub enum Trit {
    Neg = -1,
    Zero = 0,
    Pos = 1,
}

impl Trit {
    /// Canonical byte encoding used by [`super::pack`]: `00=-1`, `01=0`,
    /// `10=+1`, `11=reserved`. The reserved slot is the explicit
    /// debuggability hook called out in `ternary kernel.md`.
    pub const fn to_bits(self) -> u8 {
        match self {
            Trit::Neg => 0b00,
            Trit::Zero => 0b01,
            Trit::Pos => 0b10,
        }
    }

    /// Inverse of [`Trit::to_bits`]. Returns `None` for the reserved
    /// `0b11` pattern so callers can route into their drift / control-room
    /// inspection path instead of silently coercing.
    pub const fn from_bits(bits: u8) -> Option<Trit> {
        match bits & 0b11 {
            0b00 => Some(Trit::Neg),
            0b01 => Some(Trit::Zero),
            0b10 => Some(Trit::Pos),
            _ => None,
        }
    }

    pub const fn as_i8(self) -> i8 {
        self as i8
    }

    pub const ALL: [Trit; 3] = [Trit::Neg, Trit::Zero, Trit::Pos];

    /// Predicate: this trit is the zero element.
    pub const fn is_zero(self) -> bool {
        matches!(self, Trit::Zero)
    }

    /// Predicate: this trit is the negative element.
    pub const fn is_negative(self) -> bool {
        matches!(self, Trit::Neg)
    }

    /// Predicate: this trit is the positive element. Cross-surface
    /// invariant: exactly one of `is_negative / is_zero / is_positive`
    /// is true per variant (3-way partition).
    pub const fn is_positive(self) -> bool {
        matches!(self, Trit::Pos)
    }

    /// Absolute value: `|Trit| ∈ {Zero, Pos}`. Cross-surface
    /// invariant: `abs().as_i8() == self.as_i8().abs()`.
    pub const fn abs(self) -> Trit {
        match self {
            Trit::Neg | Trit::Pos => Trit::Pos,
            Trit::Zero => Trit::Zero,
        }
    }

    /// Negation: `Pos → Neg`, `Neg → Pos`, `Zero → Zero`. Cross-surface
    /// invariant: `neg().as_i8() == -self.as_i8()`; `neg(neg(t)) == t`.
    pub const fn neg(self) -> Trit {
        match self {
            Trit::Neg => Trit::Pos,
            Trit::Pos => Trit::Neg,
            Trit::Zero => Trit::Zero,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bits_roundtrip_all_three_values() {
        for t in [Trit::Neg, Trit::Zero, Trit::Pos] {
            assert_eq!(Trit::from_bits(t.to_bits()), Some(t));
        }
    }

    #[test]
    fn reserved_bit_pattern_is_none() {
        assert!(Trit::from_bits(0b11).is_none());
    }

    #[test]
    fn as_i8_matches_canonical_values() {
        assert_eq!(Trit::Neg.as_i8(), -1);
        assert_eq!(Trit::Zero.as_i8(), 0);
        assert_eq!(Trit::Pos.as_i8(), 1);
    }

    // ── diagnostic surface (iter 173) ────────────────────────────────────────

    #[test]
    fn all_contains_three_distinct() {
        let s: std::collections::HashSet<_> = Trit::ALL.iter().copied().collect();
        assert_eq!(s.len(), 3);
    }

    #[test]
    fn classifiers_partition_variants() {
        // Cross-surface invariant: is_negative XOR is_zero XOR is_positive.
        for t in Trit::ALL.iter().copied() {
            let trio = [t.is_negative(), t.is_zero(), t.is_positive()];
            assert_eq!(trio.iter().filter(|x| **x).count(), 1, "{:?}", t);
        }
    }

    #[test]
    fn abs_matches_i8_abs() {
        // Cross-surface invariant: abs().as_i8() == self.as_i8().abs().
        for t in Trit::ALL.iter().copied() {
            assert_eq!(t.abs().as_i8(), (t.as_i8() as i32).abs() as i8);
        }
        assert_eq!(Trit::Neg.abs(), Trit::Pos);
        assert_eq!(Trit::Pos.abs(), Trit::Pos);
        assert_eq!(Trit::Zero.abs(), Trit::Zero);
    }

    #[test]
    fn neg_matches_i8_negate() {
        // Cross-surface invariant: neg().as_i8() == -self.as_i8().
        for t in Trit::ALL.iter().copied() {
            assert_eq!(t.neg().as_i8(), -t.as_i8());
        }
    }

    #[test]
    fn neg_is_involutive() {
        // Cross-surface invariant: neg(neg(t)) == t.
        for t in Trit::ALL.iter().copied() {
            assert_eq!(t.neg().neg(), t);
        }
    }
}
