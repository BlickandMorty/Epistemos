//! Source: `docs/fusion/jordan's research/ternary kernel.md` §"Ternary packing
//! and unpacking" — 16 trits per `u32` with `00=-1, 01=0, 10=+1, 11=reserved`.
//!
//! Chosen because it is "debuggable, deterministic, and friendly to
//! control-room inspection" — not the fastest imaginable physical layout
//! but the correct starting point per the doctrine doc.

use super::trit::Trit;

/// Number of trits that fit in one `u32` at the canonical 2-bits-per-trit
/// packing. Quoted as the first invariant in `ternary kernel.md`.
pub const TRITS_PER_U32: usize = 16;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PackError {
    /// Too many trits handed to a single-word pack call. The packed
    /// representation deliberately exposes this as an error instead of
    /// silently truncating so the control room can flag the drift.
    Overflow { provided: usize, limit: usize },
    /// Unpack encountered the reserved `0b11` pattern in slot `index`.
    /// `ternary kernel.md` reserves this slot for debugger-only sentinels.
    ReservedPattern { index: usize },
}

/// Pack up to 16 trits into a single `u32`, least-significant trit first.
/// Slots beyond `trits.len()` are filled with `Trit::Zero` (`0b01`), so
/// short inputs round-trip back to themselves up to a tail of zeros.
pub fn pack_trits_u32(trits: &[Trit]) -> Result<u32, PackError> {
    if trits.len() > TRITS_PER_U32 {
        return Err(PackError::Overflow {
            provided: trits.len(),
            limit: TRITS_PER_U32,
        });
    }
    let mut word: u32 = 0;
    for slot in 0..TRITS_PER_U32 {
        let bits = trits.get(slot).copied().unwrap_or(Trit::Zero).to_bits() as u32;
        word |= bits << (slot * 2);
    }
    Ok(word)
}

/// Unpack exactly 16 trits from a single `u32`, least-significant trit first.
/// Returns [`PackError::ReservedPattern`] if any 2-bit slot holds the
/// reserved `0b11` pattern.
pub fn unpack_trits_u32(word: u32) -> Result<[Trit; TRITS_PER_U32], PackError> {
    let mut out = [Trit::Zero; TRITS_PER_U32];
    for slot in 0..TRITS_PER_U32 {
        let bits = ((word >> (slot * 2)) & 0b11) as u8;
        match Trit::from_bits(bits) {
            Some(t) => out[slot] = t,
            None => return Err(PackError::ReservedPattern { index: slot }),
        }
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_packs_to_all_zero_word() {
        let word = pack_trits_u32(&[]).unwrap();
        let trits = unpack_trits_u32(word).unwrap();
        assert!(trits.iter().all(|&t| t == Trit::Zero));
    }

    #[test]
    fn full_word_roundtrip() {
        let input: [Trit; TRITS_PER_U32] = [
            Trit::Neg, Trit::Zero, Trit::Pos, Trit::Neg,
            Trit::Pos, Trit::Pos, Trit::Zero, Trit::Neg,
            Trit::Zero, Trit::Pos, Trit::Neg, Trit::Zero,
            Trit::Pos, Trit::Neg, Trit::Zero, Trit::Pos,
        ];
        let word = pack_trits_u32(&input).unwrap();
        let output = unpack_trits_u32(word).unwrap();
        assert_eq!(input, output);
    }

    #[test]
    fn short_input_tail_zeros_on_unpack() {
        let input = [Trit::Pos, Trit::Neg, Trit::Pos];
        let word = pack_trits_u32(&input).unwrap();
        let output = unpack_trits_u32(word).unwrap();
        assert_eq!(&output[..3], &input[..]);
        assert!(output[3..].iter().all(|&t| t == Trit::Zero));
    }

    #[test]
    fn overflow_rejects_seventeen_trits() {
        let input = vec![Trit::Zero; TRITS_PER_U32 + 1];
        let err = pack_trits_u32(&input).unwrap_err();
        assert_eq!(
            err,
            PackError::Overflow {
                provided: TRITS_PER_U32 + 1,
                limit: TRITS_PER_U32,
            }
        );
    }

    #[test]
    fn reserved_pattern_surfaces_on_unpack() {
        let word: u32 = 0b11 << 6;
        let err = unpack_trits_u32(word).unwrap_err();
        assert_eq!(err, PackError::ReservedPattern { index: 3 });
    }

    #[test]
    fn least_significant_slot_first_bit_layout() {
        let input = [Trit::Pos];
        let word = pack_trits_u32(&input).unwrap();
        assert_eq!(word & 0b11, Trit::Pos.to_bits() as u32);
        assert_eq!(word >> 2, 0u32 | ((Trit::Zero.to_bits() as u32) * 0x55555555 >> 2));
    }
}
