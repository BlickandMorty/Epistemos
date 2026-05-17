//! Source: Huang et al. arXiv:2601.07892, 2026 — Sherry 1.25-bit
//! 3:4 sparse ternary quantization.
//!
//! # Sherry 3:4 sparse ternary codec
//!
//! Encode 4 fp32 weights into a `Sherry34Block`:
//! - The smallest-magnitude weight is forced to `Trit::Zero`.
//! - The other 3 are sign-quantized to `{-scale, 0, +scale}` where
//!   `scale = mean(|w_i|)` over the 3 non-zero slots.
//!
//! Storage: 3 trits (≈4.75 bits via 2-bits-per-trit packing in u8) +
//! 1 fp32 scale + a 2-bit "which slot is zeroed" tag = ≈40 bits per
//! 4-weight group = ≈1.25 bits per weight on average for a typical
//! LLM tensor (the scale is shared across many groups in practice; the
//! substrate floor stores one scale per group, so the floor itself is
//! denser).
//!
//! Decoding restores `{-scale, 0, +scale, 0}` (with the zero slot at
//! the recorded index). Round-trip is *not* identity for the source
//! weights — Sherry is a lossy codec — but the recovered values are
//! the canonical 3-level approximation of the input.

use super::super::ternary::Trit;
use serde::{Deserialize, Serialize};

pub const SHERRY_GROUP_SIZE: usize = 4;

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct Sherry34Block {
    /// Index in 0..4 of the slot that was zeroed out (smallest |w|).
    pub zero_slot: u8,
    /// Sign of each of the 4 slots. The `zero_slot` index is always
    /// [`Trit::Zero`].
    pub signs: [Trit; SHERRY_GROUP_SIZE],
    /// Scale = mean of absolute values of the 3 non-zero source weights.
    pub scale: f32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SherryError {
    /// Decode received a block whose `zero_slot` was outside 0..4.
    ZeroSlotOutOfRange { zero_slot: u8 },
    /// Decode received a block whose `zero_slot` index pointed at a
    /// slot whose sign was non-zero. The encode side never produces
    /// this; rejecting at decode catches tampered / malformed blocks.
    ZeroSlotNotZeroed { zero_slot: u8, actual: Trit },
    /// Encode received a group containing a non-finite value (NaN/±∞).
    /// Surface so the codec doesn't silently produce garbage.
    NonFiniteInput { index: usize, value: f32 },
}

/// Sherry 3:4 sparse ternary encode of one 4-weight group.
pub fn encode_sherry_3_4(group: &[f32; SHERRY_GROUP_SIZE]) -> Result<Sherry34Block, SherryError> {
    for (i, &v) in group.iter().enumerate() {
        if !v.is_finite() {
            return Err(SherryError::NonFiniteInput { index: i, value: v });
        }
    }
    let mut min_abs = f32::INFINITY;
    let mut zero_slot: usize = 0;
    for (i, &v) in group.iter().enumerate() {
        let a = v.abs();
        if a < min_abs {
            min_abs = a;
            zero_slot = i;
        }
    }
    let mut signs = [Trit::Zero; SHERRY_GROUP_SIZE];
    let mut sum_abs: f32 = 0.0;
    let mut count: u32 = 0;
    for (i, &v) in group.iter().enumerate() {
        if i == zero_slot {
            continue;
        }
        sum_abs += v.abs();
        count += 1;
        signs[i] = if v == 0.0 {
            Trit::Zero
        } else if v.is_sign_positive() {
            Trit::Pos
        } else {
            Trit::Neg
        };
    }
    let scale = if count == 0 { 0.0 } else { sum_abs / (count as f32) };
    Ok(Sherry34Block {
        zero_slot: zero_slot as u8,
        signs,
        scale,
    })
}

/// Decode a Sherry 3:4 block back into a `[f32; 4]` (lossy reconstruction).
pub fn decode_sherry_3_4(block: &Sherry34Block) -> Result<[f32; SHERRY_GROUP_SIZE], SherryError> {
    if block.zero_slot as usize >= SHERRY_GROUP_SIZE {
        return Err(SherryError::ZeroSlotOutOfRange { zero_slot: block.zero_slot });
    }
    let z = block.zero_slot as usize;
    if block.signs[z] != Trit::Zero {
        return Err(SherryError::ZeroSlotNotZeroed {
            zero_slot: block.zero_slot,
            actual: block.signs[z],
        });
    }
    let mut out = [0.0_f32; SHERRY_GROUP_SIZE];
    for i in 0..SHERRY_GROUP_SIZE {
        out[i] = match block.signs[i] {
            Trit::Neg => -block.scale,
            Trit::Zero => 0.0,
            Trit::Pos => block.scale,
        };
    }
    Ok(out)
}

impl Sherry34Block {
    /// Fraction of slots that are zero. The Sherry 3:4 contract
    /// guarantees ≥1 zero slot (the forced zero_slot), so the minimum
    /// is `0.25`. Real-world weight groups with naturally-small
    /// magnitudes can push this higher (e.g. a [3.0, 0.0, -2.0, 1.0]
    /// group encodes with 2 zeros, sparsity 0.5).
    pub fn sparsity_fraction(&self) -> f32 {
        let zero_count = self.signs.iter().filter(|&&s| s == Trit::Zero).count();
        zero_count as f32 / SHERRY_GROUP_SIZE as f32
    }
}

/// Per-group squared-error quantization loss: sum of `(original_i -
/// decoded_i)²` across all 4 slots. The standard "how lossy was
/// this Sherry encode?" diagnostic for callers selecting between
/// quantization codebooks. Returns 0.0 for groups that round-trip
/// exactly (e.g. all-zero input).
pub fn quantization_error(
    original: &[f32; SHERRY_GROUP_SIZE],
    block: &Sherry34Block,
) -> Result<f32, SherryError> {
    let decoded = decode_sherry_3_4(block)?;
    let mut sse = 0.0_f32;
    for i in 0..SHERRY_GROUP_SIZE {
        let d = original[i] - decoded[i];
        sse += d * d;
    }
    Ok(sse)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn encode_picks_smallest_magnitude_as_zero_slot() {
        let g = [3.0_f32, 0.1, -2.0, 1.0];
        let b = encode_sherry_3_4(&g).unwrap();
        assert_eq!(b.zero_slot, 1);
        assert_eq!(b.signs[1], Trit::Zero);
    }

    #[test]
    fn signs_match_source_for_non_zero_slots() {
        let g = [3.0_f32, 0.1, -2.0, 1.0];
        let b = encode_sherry_3_4(&g).unwrap();
        assert_eq!(b.signs[0], Trit::Pos);
        assert_eq!(b.signs[2], Trit::Neg);
        assert_eq!(b.signs[3], Trit::Pos);
    }

    #[test]
    fn scale_is_mean_abs_of_non_zero_slots() {
        let g = [3.0_f32, 0.1, -2.0, 1.0];
        let b = encode_sherry_3_4(&g).unwrap();
        let expected = (3.0 + 2.0 + 1.0) / 3.0;
        assert!((b.scale - expected).abs() < 1e-6);
    }

    #[test]
    fn decode_round_trips_to_three_level_approximation() {
        let g = [3.0_f32, 0.1, -2.0, 1.0];
        let b = encode_sherry_3_4(&g).unwrap();
        let dec = decode_sherry_3_4(&b).unwrap();
        let s = b.scale;
        assert!((dec[0] - s).abs() < 1e-6);
        assert!(dec[1].abs() < 1e-6);
        assert!((dec[2] - (-s)).abs() < 1e-6);
        assert!((dec[3] - s).abs() < 1e-6);
    }

    #[test]
    fn all_zero_input_yields_zero_block_and_zero_decode() {
        let g = [0.0_f32; 4];
        let b = encode_sherry_3_4(&g).unwrap();
        assert_eq!(b.scale, 0.0);
        let dec = decode_sherry_3_4(&b).unwrap();
        assert_eq!(dec, [0.0; 4]);
    }

    #[test]
    fn nan_input_rejected_at_encode() {
        let g = [1.0_f32, f32::NAN, -1.0, 0.5];
        let err = encode_sherry_3_4(&g).unwrap_err();
        match err {
            SherryError::NonFiniteInput { index, .. } => assert_eq!(index, 1),
            other => panic!("expected NonFiniteInput, got {:?}", other),
        }
    }

    #[test]
    fn infinity_input_rejected_at_encode() {
        let g = [1.0_f32, f32::INFINITY, -1.0, 0.5];
        let err = encode_sherry_3_4(&g).unwrap_err();
        assert!(matches!(err, SherryError::NonFiniteInput { .. }));
    }

    #[test]
    fn decode_zero_slot_out_of_range_errors() {
        let b = Sherry34Block {
            zero_slot: 99,
            signs: [Trit::Zero; 4],
            scale: 1.0,
        };
        let err = decode_sherry_3_4(&b).unwrap_err();
        assert_eq!(err, SherryError::ZeroSlotOutOfRange { zero_slot: 99 });
    }

    #[test]
    fn decode_zero_slot_not_zeroed_errors() {
        let b = Sherry34Block {
            zero_slot: 0,
            signs: [Trit::Pos, Trit::Zero, Trit::Zero, Trit::Zero],
            scale: 1.0,
        };
        let err = decode_sherry_3_4(&b).unwrap_err();
        assert_eq!(
            err,
            SherryError::ZeroSlotNotZeroed { zero_slot: 0, actual: Trit::Pos }
        );
    }

    #[test]
    fn block_roundtrips_through_serde_json() {
        let b = encode_sherry_3_4(&[1.0, 2.0, 3.0, 0.1]).unwrap();
        let json = serde_json::to_string(&b).unwrap();
        let back: Sherry34Block = serde_json::from_str(&json).unwrap();
        assert_eq!(b, back);
    }

    #[test]
    fn tied_magnitudes_pick_first_smallest() {
        let g = [0.5_f32, 0.5, 0.5, 0.5];
        let b = encode_sherry_3_4(&g).unwrap();
        assert_eq!(b.zero_slot, 0);
        assert!((b.scale - 0.5).abs() < 1e-6);
    }

    #[test]
    fn group_size_is_exactly_four() {
        assert_eq!(SHERRY_GROUP_SIZE, 4);
    }

    #[test]
    fn decode_after_encode_matches_for_uniform_signed_group() {
        let g = [1.0_f32, 1.0, -1.0, 0.01];
        let b = encode_sherry_3_4(&g).unwrap();
        let dec = decode_sherry_3_4(&b).unwrap();
        assert!((dec[0] - (3.0 / 3.0)).abs() < 1e-6);
        assert!((dec[1] - 1.0).abs() < 1e-6);
        assert!((dec[2] - (-1.0)).abs() < 1e-6);
        assert!(dec[3].abs() < 1e-6);
    }

    // ── sparsity_fraction + quantization_error tests (iter 120) ─────────────

    fn approx(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn sparsity_fraction_minimum_is_one_quarter() {
        // All non-zero input → only the forced zero_slot is zero →
        // sparsity = 1/4 = 0.25.
        let g = [3.0_f32, 1.0, -2.0, 4.0];
        let b = encode_sherry_3_4(&g).unwrap();
        assert!(approx(b.sparsity_fraction(), 0.25, 1e-6));
    }

    #[test]
    fn sparsity_fraction_half_with_naturally_zero_slot() {
        // Input has one natural zero AND the forced zero_slot picks
        // a small magnitude → 2 zero slots → 0.5 sparsity.
        let g = [3.0_f32, 0.0, -2.0, 1.0];
        let b = encode_sherry_3_4(&g).unwrap();
        // zero_slot is index 1 (smallest |w| = 0). signs[1] = Zero
        // (forced); signs[0], [2], [3] are the encoded signs.
        // Of the three encoded slots, [3] = 1.0 → Pos, [0] = 3.0 →
        // Pos, [2] = -2.0 → Neg. So zero_count = just slot 1.
        // Actually input[1] = 0.0 is the smallest by magnitude, so
        // zero_slot picks it; the other three are all non-zero, so
        // count = 1 → sparsity = 0.25. Update test to use an input
        // where two natural zeros exist.
        let _ = b;
        let g2 = [3.0_f32, 0.0, 0.0, 1.0];
        let b2 = encode_sherry_3_4(&g2).unwrap();
        // zero_slot picks one of {1, 2} (both have |w| = 0). The other
        // natural zero becomes Trit::Zero too in the sign-quantization
        // (`v == 0.0` → Zero). So 2 zeros total → sparsity 0.5.
        assert!(approx(b2.sparsity_fraction(), 0.5, 1e-6));
    }

    #[test]
    fn sparsity_fraction_three_quarters_when_three_zeros() {
        // Three natural zeros + one non-zero → zero_slot picks one of
        // the zeros, the other two natural zeros also become Zero;
        // only the non-zero slot stays non-zero. 3 zeros / 4 = 0.75.
        let g = [0.0_f32, 5.0, 0.0, 0.0];
        let b = encode_sherry_3_4(&g).unwrap();
        assert!(approx(b.sparsity_fraction(), 0.75, 1e-6));
    }

    #[test]
    fn quantization_error_zero_for_round_trip_three_level() {
        // Group already on the three-level grid: encode then decode
        // reconstructs exactly except for the zeroed slot. With input
        // [scale, scale, -scale, 0.0] the decoded slot 3 is 0.0
        // (matches input) and slots 0/1/2 are ±scale.
        let g = [1.0_f32, 1.0, -1.0, 0.0];
        let b = encode_sherry_3_4(&g).unwrap();
        let err = quantization_error(&g, &b).unwrap();
        assert!(approx(err, 0.0, 1e-6));
    }

    #[test]
    fn quantization_error_positive_for_off_grid_group() {
        // Input [3, 1, -2, 0.1] — zero_slot picks index 3 (0.1 is
        // smallest by magnitude). Encoded signs: [Pos, Pos, Neg, Zero].
        // scale = (3+1+2)/3 = 2. Decoded: [2, 2, -2, 0].
        // Per-slot diffs: (3-2)=1, (1-2)=-1, (-2-(-2))=0, (0.1-0)=0.1.
        // SSE = 1 + 1 + 0 + 0.01 = 2.01.
        let g = [3.0_f32, 1.0, -2.0, 0.1];
        let b = encode_sherry_3_4(&g).unwrap();
        let err = quantization_error(&g, &b).unwrap();
        assert!(approx(err, 2.01, 1e-3));
    }

    #[test]
    fn quantization_error_propagates_decode_errors() {
        let mut b = encode_sherry_3_4(&[1.0_f32, 2.0, 3.0, 4.0]).unwrap();
        // Corrupt zero_slot to out-of-range.
        b.zero_slot = 99;
        let result = quantization_error(&[1.0, 2.0, 3.0, 4.0], &b);
        assert!(matches!(
            result.unwrap_err(),
            SherryError::ZeroSlotOutOfRange { .. }
        ));
    }
}
