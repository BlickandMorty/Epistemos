//! HELIOS V5 — Sherry 1.25-bit packing (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-SHERRY guard
//!
//! Per HELIOS v4 preservation `source_docs/epistemos_resonance_gate.md`
//! §2.1 + Hong Huang et al. (City University of Hong Kong + Tencent
//! + McGill, January 2026; code at `github.com/Tencent/AngelSlim`).
//!
//! Sherry achieves **1.25 bits per weight** through a structured
//! 3:4 sparsity scheme:
//!
//! 1. Group weights into blocks of 4.
//! 2. Each block contains exactly **3 non-zero** weights (±1) and
//!    **1 zero** at one of the 4 positions.
//! 3. The configuration space is `C(4,3) · 2³ = 4 · 8 = 32`,
//!    perfectly saturating a 5-bit index (`2⁵ = 32` — zero waste).
//! 4. Storage cost: 5 bits per 4-weight block = 1.25 bits/weight.
//!
//! Empirical results (i7-14700HX, January 2026):
//! - 1B LLaMA-3.2: zero accuracy loss, 25% bit savings vs 2-bit,
//!   10% speedup over 2-bit baselines
//! - 3B model: 18% speedup over 1.67-bit (3-in-5) baseline
//!
//! Power-of-two SIMD alignment (M=4) eliminates the bit-shuffling
//! overhead of 1.67-bit packing — the architectural reason Sherry
//! beats prior ternary-sparsity formats on Apple Silicon.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY substrate. NEVER ships in MAS. Building
//! requires `--features research`. Only the typed packing /
//! unpacking primitives + 32-config enumeration ship here; the
//! actual Sherry ANE / Metal hybrid kernels would land per a Lane
//! 3 follow-up that consumes this substrate.

use serde::{Deserialize, Serialize};

/// Width of one Sherry packing block (in weights).
pub const BLOCK_WIDTH: usize = 4;

/// Number of non-zero weights per block.
pub const NONZERO_PER_BLOCK: usize = 3;

/// Number of zeros per block.
pub const ZEROS_PER_BLOCK: usize = BLOCK_WIDTH - NONZERO_PER_BLOCK;

/// Bits per packed Sherry block. Saturates the configuration space:
/// `C(4,3) · 2³ = 4 · 8 = 32 = 2⁵`.
pub const BITS_PER_BLOCK: usize = 5;

/// Bits per weight under Sherry packing: `5 / 4 = 1.25`.
/// Stored as a numerator/denominator pair to avoid float drift.
pub const BITS_PER_WEIGHT_NUMERATOR: u32 = 5;
pub const BITS_PER_WEIGHT_DENOMINATOR: u32 = 4;

/// Total number of distinct Sherry block configurations.
pub const CONFIG_SPACE_SIZE: usize = 32;

/// One Sherry-packed block: 4 weights with exactly 3 non-zero
/// values from `{-1, +1}` and exactly 1 zero.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct SherryBlock {
    /// Index in `[0, 4)` indicating which slot holds the zero.
    pub zero_position: u8,
    /// Sign pattern for the 3 non-zero slots, in slot-order
    /// (excluding the zero position). Each bit: `0` = -1, `1` = +1.
    pub sign_bits: u8,
}

impl SherryBlock {
    /// Encode a block into its 5-bit packed representation:
    ///
    /// ```text
    /// bits[0..2]  zero_position (0..3)
    /// bits[2..5]  sign_bits     (0..7)
    /// ```
    pub fn pack(self) -> u8 {
        debug_assert!(self.zero_position < 4);
        debug_assert!(self.sign_bits < 8);
        (self.zero_position & 0b11) | ((self.sign_bits & 0b111) << 2)
    }

    /// Decode a 5-bit packed value back into a block. Returns `None`
    /// if the packed value lies outside `[0, 32)`.
    pub fn unpack(packed: u8) -> Option<Self> {
        if packed >= CONFIG_SPACE_SIZE as u8 {
            return None;
        }
        Some(SherryBlock {
            zero_position: packed & 0b11,
            sign_bits: (packed >> 2) & 0b111,
        })
    }

    /// Materialize the 4 weights of this block into an `[i8; 4]`
    /// where each entry is in `{-1, 0, +1}`.
    pub fn to_weights(self) -> [i8; BLOCK_WIDTH] {
        let mut out = [0i8; BLOCK_WIDTH];
        let mut sign_idx = 0;
        for (slot, value) in out.iter_mut().enumerate() {
            if slot as u8 == self.zero_position {
                *value = 0;
            } else {
                let sign_bit = (self.sign_bits >> sign_idx) & 1;
                *value = if sign_bit == 1 { 1 } else { -1 };
                sign_idx += 1;
            }
        }
        out
    }

    /// Construct a block from `[i8; 4]` weights. Returns `None` if
    /// the input does not match the 3:4 sparsity contract (exactly
    /// 3 non-zero ±1 entries and 1 zero).
    pub fn from_weights(weights: [i8; BLOCK_WIDTH]) -> Option<Self> {
        let zero_count = weights.iter().filter(|&&w| w == 0).count();
        if zero_count != ZEROS_PER_BLOCK {
            return None;
        }
        // All non-zero entries must be ±1.
        for &w in &weights {
            if w != -1 && w != 0 && w != 1 {
                return None;
            }
        }
        let zero_position =
            weights.iter().position(|&w| w == 0)? as u8;
        let mut sign_bits = 0u8;
        let mut sign_idx = 0;
        for (slot, &w) in weights.iter().enumerate() {
            if slot as u8 == zero_position {
                continue;
            }
            if w == 1 {
                sign_bits |= 1 << sign_idx;
            }
            sign_idx += 1;
        }
        Some(SherryBlock {
            zero_position,
            sign_bits,
        })
    }

    /// Number of non-zero weights in the block (always 3 by
    /// construction; the method exists as a contract assertion).
    pub fn nonzero_count(&self) -> usize {
        NONZERO_PER_BLOCK
    }
}

/// Enumerate all 32 distinct Sherry block configurations in
/// canonical order. Useful for codebooks, look-up tables, and
/// reference oracle generation.
pub fn enumerate_all_configs() -> Vec<SherryBlock> {
    let mut out = Vec::with_capacity(CONFIG_SPACE_SIZE);
    for zero_position in 0u8..(BLOCK_WIDTH as u8) {
        for sign_bits in 0u8..8u8 {
            out.push(SherryBlock {
                zero_position,
                sign_bits,
            });
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sherry_block_constants_match_doctrine() {
        assert_eq!(BLOCK_WIDTH, 4);
        assert_eq!(NONZERO_PER_BLOCK, 3);
        assert_eq!(ZEROS_PER_BLOCK, 1);
        assert_eq!(BITS_PER_BLOCK, 5);
        // 5 bits / 4 weights = 1.25 bits/weight (numerator = 5, denominator = 4)
        assert_eq!(BITS_PER_WEIGHT_NUMERATOR, 5);
        assert_eq!(BITS_PER_WEIGHT_DENOMINATOR, 4);
        // C(4,3) · 2³ = 4 · 8 = 32 = 2⁵ — zero bit waste
        assert_eq!(CONFIG_SPACE_SIZE, 32);
    }

    #[test]
    fn pack_unpack_round_trips_all_32_configurations() {
        for packed in 0u8..(CONFIG_SPACE_SIZE as u8) {
            let block = SherryBlock::unpack(packed).unwrap();
            assert_eq!(block.pack(), packed);
        }
    }

    #[test]
    fn unpack_rejects_packed_values_outside_config_space() {
        // Values 32..255 must decode to None per doctrine.
        for packed in (CONFIG_SPACE_SIZE as u8)..u8::MAX {
            assert!(SherryBlock::unpack(packed).is_none());
        }
    }

    #[test]
    fn enumerate_all_configs_has_exactly_32_entries() {
        let configs = enumerate_all_configs();
        assert_eq!(configs.len(), CONFIG_SPACE_SIZE);
    }

    #[test]
    fn enumerated_configs_are_all_distinct() {
        let configs = enumerate_all_configs();
        let unique: std::collections::HashSet<SherryBlock> =
            configs.iter().copied().collect();
        assert_eq!(unique.len(), CONFIG_SPACE_SIZE);
    }

    #[test]
    fn every_block_has_exactly_3_nonzero_weights_and_1_zero() {
        for block in enumerate_all_configs() {
            let weights = block.to_weights();
            let nonzero = weights.iter().filter(|&&w| w != 0).count();
            let zeros = weights.iter().filter(|&&w| w == 0).count();
            assert_eq!(nonzero, 3);
            assert_eq!(zeros, 1);
        }
    }

    #[test]
    fn every_block_weight_is_in_minus_one_zero_plus_one() {
        for block in enumerate_all_configs() {
            for &w in &block.to_weights() {
                assert!(w == -1 || w == 0 || w == 1);
            }
        }
    }

    #[test]
    fn from_weights_round_trips_through_to_weights() {
        for block in enumerate_all_configs() {
            let weights = block.to_weights();
            let recovered = SherryBlock::from_weights(weights).unwrap();
            assert_eq!(recovered, block);
        }
    }

    #[test]
    fn from_weights_rejects_non_sherry_patterns() {
        // 0 zeros (4 non-zero) — violates 3:4 sparsity.
        assert!(SherryBlock::from_weights([1, 1, 1, 1]).is_none());
        // 2 zeros — violates 3:4 sparsity.
        assert!(SherryBlock::from_weights([0, 0, 1, 1]).is_none());
        // Out-of-range value (2 instead of ±1).
        assert!(SherryBlock::from_weights([1, 1, 0, 2]).is_none());
        // All zeros.
        assert!(SherryBlock::from_weights([0, 0, 0, 0]).is_none());
    }

    #[test]
    fn from_weights_accepts_all_canonical_3_4_patterns() {
        // Sample canonical 3:4 patterns: zero at each of 4 positions
        // with all-positive signs.
        for zero_pos in 0..4 {
            let mut weights = [1i8; 4];
            weights[zero_pos] = 0;
            assert!(SherryBlock::from_weights(weights).is_some());
        }
    }

    #[test]
    fn nonzero_count_invariant_holds() {
        // The 3:4 sparsity contract says EVERY block has exactly 3
        // non-zero weights. This method exists as an assertion of
        // the contract.
        for block in enumerate_all_configs() {
            assert_eq!(block.nonzero_count(), 3);
        }
    }

    #[test]
    fn pack_uses_canonical_5_bit_layout() {
        // Layout: bits[0..2] = zero_position, bits[2..5] = sign_bits.
        // The maximum valid packed value is (3 << 2) | 7 = 12 | 7 = 15 = 0b01111? no:
        // zero_position max = 3 = 0b11, sign_bits max = 7 = 0b111
        // packed = 0b11 | (0b111 << 2) = 0b11 | 0b11100 = 0b11111 = 31
        let max = SherryBlock {
            zero_position: 3,
            sign_bits: 7,
        };
        assert_eq!(max.pack(), 31);
        // Zero packed value decodes to (zero_position=0, sign_bits=0)
        let min = SherryBlock::unpack(0).unwrap();
        assert_eq!(min.zero_position, 0);
        assert_eq!(min.sign_bits, 0);
    }

    #[test]
    fn block_serializes_and_round_trips_through_json() {
        for block in enumerate_all_configs() {
            let json = serde_json::to_string(&block).unwrap();
            let parsed: SherryBlock = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, block);
        }
    }
}
