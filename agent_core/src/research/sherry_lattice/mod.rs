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
//! Two sub-features (iter 24 ships #1 only):
//!
//! 1. **Sherry 3:4 sparse ternary codec** ([`sparse_ternary`]) —
//!    encode an arbitrary `[f32; 4]` group into a [`Sherry34Block`]:
//!    smallest-magnitude slot is forced to zero, the other 3 are
//!    sign-quantized to `{-scale, 0, +scale}`. Scale = mean abs of the
//!    three non-zero originals.
//! 2. **E8 / Leech lattice nearest-point quantizers** (NOT-STARTED) —
//!    NestQuant + Huang arXiv:2603.11021 nested-lattice VQ, second-
//!    moment shaping gain G(E_8) = 0.0717, G(Leech_24) = 0.0658 per
//!    Helios v3 Part II T_K row.

pub mod sparse_ternary;

pub use sparse_ternary::{
    decode_sherry_3_4, encode_sherry_3_4, Sherry34Block, SherryError, SHERRY_GROUP_SIZE,
};
