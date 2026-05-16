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

/// Count nonzero trits (`Neg = 00` or `Pos = 10`) in a packed word
/// without unpacking. Treats the reserved `0b11` pattern as nonzero
/// (it's a debugger sentinel, not a real zero). Returns count in
/// `0..=16`. Useful as a hot-path companion to GemvBlock's
/// `nonzero_count` metadata when the source word is the truth.
pub fn count_nonzero_in_word(word: u32) -> u8 {
    let mut count = 0u8;
    for slot in 0..TRITS_PER_U32 {
        let bits = ((word >> (slot * 2)) & 0b11) as u8;
        // Zero pattern is 0b01; anything else (00, 10, 11) counts as
        // nonzero. The 0b11 reserved pattern is intentionally counted
        // — surfacing reserved-slot debugger sentinels to sparsity
        // accounting would otherwise hide them.
        if bits != 0b01 {
            count += 1;
        }
    }
    count
}

/// Validate that a packed word has no slot holding the reserved
/// `0b11` pattern. Returns `Ok(())` on clean input or
/// `Err(ReservedPattern { index })` for the first reserved slot.
/// Allocation-free companion to `unpack_trits_u32` for hot paths
/// that only need the validation, not the unpacked array.
pub fn validate_word(word: u32) -> Result<(), PackError> {
    for slot in 0..TRITS_PER_U32 {
        let bits = ((word >> (slot * 2)) & 0b11) as u8;
        if bits == 0b11 {
            return Err(PackError::ReservedPattern { index: slot });
        }
    }
    Ok(())
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

    // ── count_nonzero_in_word + validate_word tests (iter 114) ──────────────

    #[test]
    fn count_nonzero_all_zero_word() {
        // pack([]) yields all-zero trits → all slots are 0b01 → count 0.
        let word = pack_trits_u32(&[]).unwrap();
        assert_eq!(count_nonzero_in_word(word), 0);
    }

    #[test]
    fn count_nonzero_three_nonzero_trits() {
        let trits = [Trit::Pos, Trit::Neg, Trit::Pos];
        let word = pack_trits_u32(&trits).unwrap();
        assert_eq!(count_nonzero_in_word(word), 3);
    }

    #[test]
    fn count_nonzero_all_slots_nonzero() {
        let trits: [Trit; TRITS_PER_U32] = [Trit::Pos; TRITS_PER_U32];
        let word = pack_trits_u32(&trits).unwrap();
        assert_eq!(count_nonzero_in_word(word), 16);
    }

    #[test]
    fn count_nonzero_matches_unpack_filter_count() {
        // Cross-check vs the obvious unpack-then-filter implementation
        // across a non-trivial sample.
        let trits = [
            Trit::Neg, Trit::Zero, Trit::Pos, Trit::Neg,
            Trit::Zero, Trit::Pos, Trit::Zero, Trit::Neg,
            Trit::Zero, Trit::Zero, Trit::Pos, Trit::Pos,
            Trit::Zero, Trit::Neg, Trit::Zero, Trit::Pos,
        ];
        let word = pack_trits_u32(&trits).unwrap();
        let unpack_count =
            unpack_trits_u32(word).unwrap().iter().filter(|&&t| t != Trit::Zero).count() as u8;
        assert_eq!(count_nonzero_in_word(word), unpack_count);
    }

    #[test]
    fn count_nonzero_reserved_pattern_counts_as_nonzero() {
        // Reserved pattern at slot 3 (bit positions 6-7). Slots 0-2
        // are 0b00 (Neg, nonzero). So count = 3 (Negs) + 1 (reserved) = 4.
        let word: u32 = 0b11 << 6;
        // Slots 0,1,2: bits 0b00 = Neg (nonzero)
        // Slot 3: bits 0b11 = reserved (counted as nonzero)
        // Slots 4-15: bits 0b00 = Neg (nonzero) since default is 0
        // Wait — bits all zero means slot=0b00=Neg. Let me reconsider.
        // word = 0b11 << 6 means only slot 3 has 0b11. All other slots
        // have 0b00 = Neg.
        // So nonzero count = 16 (all slots are nonzero: 15 Negs + 1 reserved).
        assert_eq!(count_nonzero_in_word(word), 16);
    }

    #[test]
    fn validate_word_clean_passes() {
        let word = pack_trits_u32(&[Trit::Pos, Trit::Neg, Trit::Zero]).unwrap();
        assert!(validate_word(word).is_ok());
    }

    #[test]
    fn validate_word_reserved_pattern_at_index() {
        // Reserved at slot 5.
        let word: u32 = 0b11 << 10;
        let err = validate_word(word).unwrap_err();
        assert_eq!(err, PackError::ReservedPattern { index: 5 });
    }

    #[test]
    fn validate_word_first_reserved_slot_wins() {
        // Reserved at both slot 2 AND slot 7. validate_word returns
        // the LOWEST index.
        let word: u32 = (0b11 << 4) | (0b11 << 14);
        let err = validate_word(word).unwrap_err();
        assert_eq!(err, PackError::ReservedPattern { index: 2 });
    }

    #[test]
    fn validate_word_agrees_with_unpack_on_clean_words() {
        // For every clean word, validate_word should pass iff unpack
        // succeeds. Sample a few non-trivial inputs.
        let inputs: &[&[Trit]] = &[
            &[Trit::Pos],
            &[Trit::Neg, Trit::Pos, Trit::Zero],
            &[Trit::Pos; TRITS_PER_U32],
            &[Trit::Zero; TRITS_PER_U32],
        ];
        for input in inputs {
            let word = pack_trits_u32(input).unwrap();
            assert!(validate_word(word).is_ok());
            assert!(unpack_trits_u32(word).is_ok());
        }
    }
}
