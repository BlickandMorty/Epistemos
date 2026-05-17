//! Source:
//! - Huang et al., "Sherry: Hardware-Efficient 1.25-Bit Ternary Quantization",
//!   arXiv:2601.07892, 2026 — 3:4 sparse ternary pattern (exactly one
//!   zero per 4-weight group → 3 ternary values + 1 forced zero, log₂(3³) =
//!   ≈4.75 bits per 4-weight group ≈ 1.19 bits/weight ≈ "1.25-bit"
//!   on the doctrine-doc shelf).
//! - `docs/fusion/jordan's research/helios v3.md` Part II T_Q row +
//!   Part III L1 Compressed Residual row (Sherry on residual stream;
//!   12× compression target).
//! - NestQuant (arXiv:2502.09720) + Leech-Lattice VQ (arXiv:2603.11021)
//!   — the lattice-VQ family J7 extends with E8 + Leech (future iters).
//!
//! # Wave J7 — Sherry 1.25-bit + lattice-VQ substrate
//!
//! Four sub-features (all ✓ landed as of iter 77):
//!
//! 1. **Sherry 3:4 sparse ternary codec** ([`sparse_ternary`]) —
//!    encode an arbitrary `[f32; 4]` group into a [`Sherry34Block`]:
//!    smallest-magnitude slot is forced to zero, the other 3 are
//!    sign-quantized to `{-scale, 0, +scale}`. Scale = mean abs of the
//!    three non-zero originals.
//! 2. **E8 nearest-point quantizer** ([`e8`]) — Conway-Sloane Ch. 20
//!    Algorithm 5. Shaping gain G(E_8) = 0.0717 (iter 25).
//! 3. **Leech-24 lattice substrate** ([`leech`]) — typed envelope +
//!    canonical constants (dimension, shaping gain, kissing number,
//!    min norm²) + a documented Z^24-rounding placeholder for the
//!    nearest-point oracle. The real Algorithm-6 decoder needs Golay
//!    (24, 12) decoding and lands in a future iter behind the same
//!    signature (iter 71 ships the substrate; production decoder
//!    NOT-STARTED).
//! 4. **Codebook-family envelope** ([`codebook`], ✓ landed iter 77) —
//!    types the 3 families with canonical dimension / bits-per-weight
//!    / shaping-gain metadata, plus `select_by_budget(bits)` that
//!    picks the most-compressed admissible family for a given
//!    bit-budget per weight.

pub mod codebook;
pub mod e8;
pub mod leech;
pub mod sparse_ternary;

pub use codebook::{select_by_budget, CodebookFamily, CodebookSelectError};
pub use e8::{e8_quantize, in_e8, E8Error, E8Point};
pub use leech::{
    nearest_leech_point_placeholder, Leech24Point, LeechError, LEECH_DIMENSION,
    LEECH_KISSING_NUMBER, LEECH_MIN_NORM_SQUARED, LEECH_SHAPING_GAIN,
};
pub use sparse_ternary::{
    decode_sherry_3_4, encode_sherry_3_4, Sherry34Block, SherryError, SHERRY_GROUP_SIZE,
};
