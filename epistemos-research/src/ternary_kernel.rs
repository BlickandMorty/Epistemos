//! HELIOS V5 — Ternary Kernel Architecture (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-TERNARY-KERNEL guard
//!
//! Per HELIOS v4 preservation `source_docs/ternary_kernel.md` —
//! Ternary Core with Residual Islands. The deepest doctrinal claim:
//!
//! > "Most transformer linear layers go ternary. A tiny set of
//! >  'fragile' parameters stays dense."
//!
//! This module exposes the **typed substrate** for that doctrine:
//! the trit alphabet, the packing convention (16 trits per u32),
//! the three-backend triad (Dense / BitnetReference / TernaryMetal),
//! the residual-island formula, and the canonical lists of
//! fragile-stays-dense layers and ternary-first hot-path layers.
//!
//! The actual MSL kernels (T-MAC LUT / BitNet b1.58 GEMM /
//! Sparse Ternary GEMM) live at `Epistemos/Shaders/` — those are
//! the W12/W13/W14 Tier-2 deliverables shipped in HELIOS V5 Stage
//! 20. This module documents the architectural envelope around
//! them.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY substrate. NEVER ships in MAS. Building
//! requires `--features research`. The MSL kernels themselves are
//! `pro-build` gated separately on the Swift side.
//!
//! ## Cross-references
//!
//! - HELIOS V5 W12 — T-MAC LUT GEMM (`Epistemos/Shaders/tmac_lut.metal`)
//! - HELIOS V5 W13 — BitNet b1.58 (`Epistemos/Shaders/bitnet_b158.metal`)
//! - HELIOS V5 W14 — Sparse Ternary GEMM
//!   (`Epistemos/Shaders/sparse_ternary_gemm.metal`)

use serde::{Deserialize, Serialize};

/// Trit alphabet — the three-symbol ternary value used by BitNet b1.58
/// and T-MAC weights. Bit-pattern convention from
/// `ternary_kernel.md` §"Ternary packing and unpacking":
///
/// ```text
/// 00 = -1
/// 01 =  0
/// 10 = +1
/// 11 = reserved
/// ```
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Trit {
    Neg1,
    Zero,
    Pos1,
}

impl Trit {
    /// 2-bit encoding per the canonical packing convention.
    pub fn to_bits(self) -> u8 {
        match self {
            Trit::Neg1 => 0b00,
            Trit::Zero => 0b01,
            Trit::Pos1 => 0b10,
        }
    }

    /// Decode 2-bit value back to a Trit. `0b11` is reserved and
    /// returns `None` per doctrine.
    pub fn from_bits(bits: u8) -> Option<Trit> {
        match bits & 0b11 {
            0b00 => Some(Trit::Neg1),
            0b01 => Some(Trit::Zero),
            0b10 => Some(Trit::Pos1),
            _ => None,
        }
    }

    /// Numeric value as i8 (matches the `{-1, 0, +1}` formal alphabet).
    pub fn to_i8(self) -> i8 {
        match self {
            Trit::Neg1 => -1,
            Trit::Zero => 0,
            Trit::Pos1 => 1,
        }
    }
}

/// Number of trits packed into one u32 per the canonical convention
/// (each trit takes 2 bits; 32 / 2 = 16).
pub const TRITS_PER_U32: usize = 16;

/// Pack 16 trits into a single u32 (LSB = position 0).
pub fn pack_16_trits(trits: [Trit; TRITS_PER_U32]) -> u32 {
    let mut out: u32 = 0;
    for (i, trit) in trits.iter().enumerate() {
        out |= (trit.to_bits() as u32) << (i * 2);
    }
    out
}

/// Unpack a u32 back into 16 trits. Returns `None` if any 2-bit
/// position contains the reserved `0b11` pattern.
pub fn unpack_16_trits(packed: u32) -> Option<[Trit; TRITS_PER_U32]> {
    let mut out = [Trit::Zero; TRITS_PER_U32];
    for (i, slot) in out.iter_mut().enumerate() {
        let bits = ((packed >> (i * 2)) & 0b11) as u8;
        *slot = Trit::from_bits(bits)?;
    }
    Some(out)
}

/// Three-backend triad per `ternary_kernel.md` §"What I would actually
/// build". Each backend exists for a distinct reason; none replaces
/// the others.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TernaryBackend {
    /// Gold-standard baseline. Lets you compare quality, latency,
    /// and memory against a known-good dense runtime.
    DenseMlx,
    /// External truth source. Lets you validate against the official
    /// BitNet/bitnet.cpp behavior.
    BitnetReference,
    /// Breakthrough lane. Where custom packed-trit kernels, residual
    /// islands, and live control room live (W12/W13/W14 MSL).
    TernaryMetal,
}

/// The 9 fragile layers that should stay dense in the residual-
/// island design. From `ternary_kernel.md` §"What should remain
/// dense at first".
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FragileDenseLayer {
    Embeddings,
    LmHead,
    RmsNormScales,
    LogitsProcessing,
    AttentionSoftmax,
    RopeTrigTables,
    SteeringDeltas,
    SafetyVerificationChannels,
    OutputAdjacentLayers,
}

/// The 4 hot-path layers where ternary should land first. From
/// `ternary_kernel.md` §"What should go ternary first".
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TernaryHotPathLayer {
    /// Q/K/V/O projections in attention.
    QkvOutputProjection,
    /// Up/down/gate MLP projections.
    MlpUpDownGate,
    /// Decode-path GEMV hot loop (token-by-token).
    DecodeGemv,
    /// Selected prefill GEMM paths (after decode is stable).
    PrefillGemm,
}

/// Residual-island layer formula:
///
/// ```text
/// y = BitLinear_ternary(x; W_t, s) + ResidualIsland(x; W_r)
/// ```
///
/// where `W_t` is packed-trit weight data, `s` is per-block scale
/// metadata, and `W_r` is a small dense correction path. Captures
/// the dimension footprint so consumers can budget memory.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct ResidualIslandLayer {
    /// Width of the input vector x.
    pub d_in: u32,
    /// Width of the output vector y.
    pub d_out: u32,
    /// Block size for ternary packing; one fp16/fp32 scale per block.
    pub block_size: u32,
    /// Width (in float channels) of the dense residual correction
    /// path. Typical: 0.5%–5% of `d_out`.
    pub residual_dense_channels: u32,
}

impl ResidualIslandLayer {
    /// Number of u32 words required to store the packed-trit weights
    /// of this layer. Each (d_in × d_out) block holds 16 trits per
    /// u32 word.
    pub fn ternary_weight_words(&self) -> u64 {
        let total_trits = self.d_in as u64 * self.d_out as u64;
        total_trits.div_ceil(TRITS_PER_U32 as u64)
    }

    /// Number of fp16 scale entries (one per d_out × block).
    pub fn scale_entries_fp16(&self) -> u64 {
        let blocks_per_row = (self.d_in as u64).div_ceil(self.block_size as u64);
        blocks_per_row * self.d_out as u64
    }

    /// Number of f32 channels in the dense residual island
    /// correction path: `d_out × residual_dense_channels`.
    pub fn residual_dense_f32_channels(&self) -> u64 {
        self.d_out as u64 * self.residual_dense_channels as u64
    }
}

/// All 3 backends in canonical order.
pub const ALL_BACKENDS: [TernaryBackend; 3] = [
    TernaryBackend::DenseMlx,
    TernaryBackend::BitnetReference,
    TernaryBackend::TernaryMetal,
];

/// All 9 fragile-dense layers in canonical doctrine order.
pub const ALL_FRAGILE_LAYERS: [FragileDenseLayer; 9] = [
    FragileDenseLayer::Embeddings,
    FragileDenseLayer::LmHead,
    FragileDenseLayer::RmsNormScales,
    FragileDenseLayer::LogitsProcessing,
    FragileDenseLayer::AttentionSoftmax,
    FragileDenseLayer::RopeTrigTables,
    FragileDenseLayer::SteeringDeltas,
    FragileDenseLayer::SafetyVerificationChannels,
    FragileDenseLayer::OutputAdjacentLayers,
];

/// All 4 ternary hot-path layers in canonical doctrine order.
pub const ALL_HOT_PATH_LAYERS: [TernaryHotPathLayer; 4] = [
    TernaryHotPathLayer::QkvOutputProjection,
    TernaryHotPathLayer::MlpUpDownGate,
    TernaryHotPathLayer::DecodeGemv,
    TernaryHotPathLayer::PrefillGemm,
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn trit_bits_match_canonical_packing_convention() {
        assert_eq!(Trit::Neg1.to_bits(), 0b00);
        assert_eq!(Trit::Zero.to_bits(), 0b01);
        assert_eq!(Trit::Pos1.to_bits(), 0b10);
    }

    #[test]
    fn reserved_bit_pattern_decodes_to_none() {
        assert!(Trit::from_bits(0b11).is_none());
        // Higher bits ignored — pattern 0b1100 still maps to 0b00.
        assert_eq!(Trit::from_bits(0b1100), Some(Trit::Neg1));
    }

    #[test]
    fn trit_decode_round_trips_for_three_valid_patterns() {
        for &t in &[Trit::Neg1, Trit::Zero, Trit::Pos1] {
            assert_eq!(Trit::from_bits(t.to_bits()), Some(t));
        }
    }

    #[test]
    fn trit_i8_values_match_formal_alphabet() {
        assert_eq!(Trit::Neg1.to_i8(), -1);
        assert_eq!(Trit::Zero.to_i8(), 0);
        assert_eq!(Trit::Pos1.to_i8(), 1);
    }

    #[test]
    fn pack_unpack_round_trips_all_zero_trits() {
        let trits = [Trit::Zero; TRITS_PER_U32];
        let packed = pack_16_trits(trits);
        let unpacked = unpack_16_trits(packed).unwrap();
        assert_eq!(unpacked, trits);
    }

    #[test]
    fn pack_unpack_round_trips_alternating_trits() {
        let mut trits = [Trit::Zero; TRITS_PER_U32];
        for (i, t) in trits.iter_mut().enumerate() {
            *t = match i % 3 {
                0 => Trit::Neg1,
                1 => Trit::Zero,
                _ => Trit::Pos1,
            };
        }
        let packed = pack_16_trits(trits);
        let unpacked = unpack_16_trits(packed).unwrap();
        assert_eq!(unpacked, trits);
    }

    #[test]
    fn unpack_detects_reserved_pattern_in_any_slot() {
        // Construct a packed value with 0b11 in slot 5.
        let packed = 0b11u32 << (5 * 2);
        assert!(unpack_16_trits(packed).is_none());
    }

    #[test]
    fn trits_per_u32_matches_doctrine() {
        // 16 trits × 2 bits = 32 bits.
        assert_eq!(TRITS_PER_U32, 16);
        assert_eq!(TRITS_PER_U32 * 2, 32);
    }

    #[test]
    fn residual_island_layer_computes_weight_words() {
        // 1024 × 1024 trits / 16 trits-per-word = 65536 words.
        let l = ResidualIslandLayer {
            d_in: 1024,
            d_out: 1024,
            block_size: 64,
            residual_dense_channels: 8,
        };
        assert_eq!(l.ternary_weight_words(), 65_536);
    }

    #[test]
    fn residual_island_layer_handles_non_aligned_dimensions() {
        // 1023 × 1023 = 1_046_529 trits → 65_409 words (with rounding up).
        let l = ResidualIslandLayer {
            d_in: 1023,
            d_out: 1023,
            block_size: 64,
            residual_dense_channels: 8,
        };
        let total_trits: u64 = 1023u64 * 1023u64;
        let expected = total_trits.div_ceil(16);
        assert_eq!(l.ternary_weight_words(), expected);
    }

    #[test]
    fn residual_island_layer_computes_scale_entries() {
        // d_in=1024, block_size=64 → 16 blocks per row × 1024 rows.
        let l = ResidualIslandLayer {
            d_in: 1024,
            d_out: 1024,
            block_size: 64,
            residual_dense_channels: 8,
        };
        assert_eq!(l.scale_entries_fp16(), 16 * 1024);
    }

    #[test]
    fn residual_island_layer_computes_dense_channels() {
        let l = ResidualIslandLayer {
            d_in: 1024,
            d_out: 4096,
            block_size: 64,
            residual_dense_channels: 32,
        };
        assert_eq!(l.residual_dense_f32_channels(), 4096 * 32);
    }

    #[test]
    fn three_backends_are_all_present_and_distinct() {
        let set: std::collections::HashSet<TernaryBackend> =
            ALL_BACKENDS.iter().copied().collect();
        assert_eq!(set.len(), 3);
    }

    #[test]
    fn nine_fragile_layers_are_distinct() {
        let set: std::collections::HashSet<FragileDenseLayer> =
            ALL_FRAGILE_LAYERS.iter().copied().collect();
        assert_eq!(set.len(), 9);
    }

    #[test]
    fn four_hot_path_layers_are_distinct() {
        let set: std::collections::HashSet<TernaryHotPathLayer> =
            ALL_HOT_PATH_LAYERS.iter().copied().collect();
        assert_eq!(set.len(), 4);
    }

    #[test]
    fn trit_serializes_in_snake_case() {
        for (t, expected) in [
            (Trit::Neg1, "\"neg1\""),
            (Trit::Zero, "\"zero\""),
            (Trit::Pos1, "\"pos1\""),
        ] {
            assert_eq!(serde_json::to_string(&t).unwrap(), expected);
        }
    }

    #[test]
    fn ternary_backend_serializes_in_snake_case() {
        for (b, expected) in [
            (TernaryBackend::DenseMlx, "\"dense_mlx\""),
            (TernaryBackend::BitnetReference, "\"bitnet_reference\""),
            (TernaryBackend::TernaryMetal, "\"ternary_metal\""),
        ] {
            assert_eq!(serde_json::to_string(&b).unwrap(), expected);
        }
    }
}
