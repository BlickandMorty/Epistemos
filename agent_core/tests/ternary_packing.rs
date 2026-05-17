#![cfg(feature = "research")]
//! Wave J1 ternary substrate — integration harness for pack / unpack /
//! validate / count_nonzero.
//!
//! Source:
//! - `agent_core/src/research/ternary/{trit, pack}.rs` (substrate landed
//!   under research feature gate).
//! - `docs/fusion/jordan's research/ternary kernel.md` §"Ternary packing
//!   and unpacking" — 16 trits per u32, 2 bits per trit.
//! - Phase B iter 58 substrate-floor.
//!
//! # Substrate-floor scope
//!
//! Exercises the agent_core::research::ternary primitives at scale.
//! Round-trip determinism + reserved-pattern detection + overflow
//! detection + count_nonzero correctness across many random inputs.
//!
//! Production-PASS for ternary lane comes from F-PacketRouter1bit +
//! F-70B-Cocktail composition; this harness anchors the SUBSTRATE.

use agent_core::research::ternary::pack::{
    count_nonzero_in_word, pack_trits_u32, unpack_trits_u32, validate_word, PackError,
    TRITS_PER_U32,
};
use agent_core::research::ternary::trit::Trit;

struct MiniRng(u64);

impl MiniRng {
    fn new(seed: u64) -> Self { Self(seed) }
    fn next_u32(&mut self) -> u32 {
        self.0 = self.0.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
        (self.0 >> 32) as u32
    }
    fn next_trit(&mut self) -> Trit {
        match self.next_u32() % 3 {
            0 => Trit::Neg,
            1 => Trit::Zero,
            _ => Trit::Pos,
        }
    }
}

#[test]
fn trits_per_u32_is_16() {
    assert_eq!(TRITS_PER_U32, 16);
}

#[test]
fn empty_pack_returns_zero_word() {
    let word = pack_trits_u32(&[]).unwrap();
    // The unpacked all-zero (Trit::Zero) word round-trips back to [Zero; 16].
    let unpacked = unpack_trits_u32(word).unwrap();
    assert!(unpacked.iter().all(|t| matches!(t, Trit::Zero)));
}

#[test]
fn pack_unpack_round_trip_at_full_capacity_100_seeds() {
    let mut rng = MiniRng::new(0xACAA_3100_u64);
    for _ in 0..100 {
        let trits: [Trit; TRITS_PER_U32] = std::array::from_fn(|_| rng.next_trit());
        let word = pack_trits_u32(&trits).unwrap();
        let unpacked = unpack_trits_u32(word).unwrap();
        assert_eq!(unpacked, trits, "pack/unpack must round-trip at full capacity");
    }
}

#[test]
fn pack_unpack_round_trip_at_short_lengths() {
    let mut rng = MiniRng::new(0xACAA_3101_u64);
    for len in 0..TRITS_PER_U32 {
        let trits: Vec<Trit> = (0..len).map(|_| rng.next_trit()).collect();
        let word = pack_trits_u32(&trits).unwrap();
        let unpacked = unpack_trits_u32(word).unwrap();
        // The first `len` trits must match; remaining slots are Zero.
        assert_eq!(&unpacked[..len], trits.as_slice());
        assert!(unpacked[len..].iter().all(|t| matches!(t, Trit::Zero)));
    }
}

#[test]
fn pack_overflow_errors_when_more_than_16_trits() {
    let trits: Vec<Trit> = (0..17).map(|_| Trit::Pos).collect();
    let err = pack_trits_u32(&trits).unwrap_err();
    assert_eq!(err, PackError::Overflow { provided: 17, limit: TRITS_PER_U32 });
}

#[test]
fn reserved_pattern_unpack_errors() {
    // 0b11 at slot 0 — reserved per doctrine.
    let bad_word: u32 = 0b11;
    let err = unpack_trits_u32(bad_word).unwrap_err();
    assert!(matches!(err, PackError::ReservedPattern { index: 0 }));
}

#[test]
fn validate_word_passes_clean_words() {
    let trits = vec![Trit::Neg, Trit::Zero, Trit::Pos, Trit::Neg];
    let word = pack_trits_u32(&trits).unwrap();
    assert!(validate_word(word).is_ok());
}

#[test]
fn validate_word_rejects_reserved() {
    let bad = 0b11_u32 << 4; // reserved pattern at slot 2
    assert!(validate_word(bad).is_err());
}

#[test]
fn count_nonzero_matches_naive_count() {
    let trits = vec![Trit::Neg, Trit::Zero, Trit::Pos, Trit::Pos, Trit::Zero, Trit::Neg];
    let word = pack_trits_u32(&trits).unwrap();
    let count = count_nonzero_in_word(word);
    let naive: u8 = trits.iter().filter(|t| !matches!(t, Trit::Zero)).count() as u8;
    assert_eq!(count, naive);
}

#[test]
fn count_nonzero_all_zero_word_is_zero() {
    let word = pack_trits_u32(&[Trit::Zero; TRITS_PER_U32]).unwrap();
    assert_eq!(count_nonzero_in_word(word), 0);
}

#[test]
fn count_nonzero_all_neg_word_is_16() {
    let word = pack_trits_u32(&[Trit::Neg; TRITS_PER_U32]).unwrap();
    assert_eq!(count_nonzero_in_word(word), 16);
}

#[test]
fn count_nonzero_all_pos_word_is_16() {
    let word = pack_trits_u32(&[Trit::Pos; TRITS_PER_U32]).unwrap();
    assert_eq!(count_nonzero_in_word(word), 16);
}

#[test]
fn trit_as_i8_invariants_lockced() {
    assert_eq!(Trit::Neg.as_i8(), -1);
    assert_eq!(Trit::Zero.as_i8(), 0);
    assert_eq!(Trit::Pos.as_i8(), 1);
}

#[test]
fn trit_neg_is_self_inverse() {
    for t in Trit::ALL {
        assert_eq!(t.neg().neg(), t, "double-neg must be identity for {:?}", t);
    }
}

#[test]
fn trit_abs_is_idempotent() {
    for t in Trit::ALL {
        let a = t.abs();
        assert_eq!(a.abs(), a, "abs must be idempotent for {:?}", t);
    }
}
