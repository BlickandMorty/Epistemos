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
}
