//! Source:
//! - Ma et al., "The Era of 1-bit LLMs: All Large Language Models are in 1.58 Bits"
//!   (BitNet b1.58), arXiv:2402.17764 — ternary `{-1, 0, +1}` weights.
//! - Microsoft `bitnet.cpp` reference implementation (decode-first 1-bit kernels).
//! - Wei et al., "T-MAC: CPU Renaissance via Table Lookup for Low-Bit LLM Deployment",
//!   arXiv:2407.00088 — specialized low-bit kernel methodology.
//! - `docs/fusion/jordan's research/ternary kernel.md` — Epistemos ternary lane
//!   doctrine (3-backend split, residual islands, decode-first kernel portfolio).
//! - `docs/fusion/jordan's research/helios v3.md` Part I Pillar V (eml-operator) +
//!   Part III L1 Compressed Residual (Sherry 1.25-bit, Huang et al. arXiv:2601.07892).
//!
//! # Wave J1 — Ternary core
//!
//! "Most transformer linear layers go ternary. A tiny set of fragile
//! parameters stays dense." (`ternary kernel.md`). The lane is intentionally
//! split into three backends so a single research run can A/B/C any decode
//! path against a gold-standard dense baseline and an external reference.
//!
//! The kernel portfolio in the canonical order from `ternary kernel.md`:
//!
//! 1. Ternary packing / unpacking ([`pack`]).
//! 2. Block-scaled ternary GEMV ([`gemv`] — CPU reference + Metal stub at
//!    `Epistemos/Shaders/ternary_gemv.metal`; Metal dispatch wire-in pending).
//! 3. Fused ternary projection with residual island add ([`residual_island`]
//!    — CPU reference; Metal fusion pending).
//! 4. Fused RMSNorm + ternary projection ([`fused_rmsnorm`] — CPU reference
//!    with allocated scratch; Metal single-pass fusion pending).
//! 5. Ternary KV fingerprint kernel ([`kv_fingerprint`] — CPU reference +
//!    Hamming-like distance; routing-layer wire-in pending). Distinct from
//!    full KV ternarization, which is intentionally deferred per
//!    `ternary kernel.md`.
//! 6. Live activation capture kernel ([`activation_tap`] — CPU reference
//!    with FIFO ring buffer; on-GPU mirror pending).
//! 7. Steering delta apply kernel (NOT-STARTED).
//!
//! This iteration lands only the substrate floor: the [`Trit`] primitive,
//! the canonical packed-representation codec, and the [`TernaryBackend`]
//! trait that the three backend stubs implement. Subsequent Wave J1 iters
//! fill in each numbered kernel above.
//!
//! # Decode-first invariant
//!
//! Per `ternary kernel.md`: on-device chat is decode-bound and
//! memory-bandwidth-bound. The earliest wins come from the token-by-token
//! projection path, not from rewriting every kernel on day one. Every
//! kernel landed under this module MUST justify itself against decode
//! performance before any prefill-only optimization is considered.

pub mod activation_tap;
pub mod backend;
pub mod fused_rmsnorm;
pub mod gemv;
pub mod kv_fingerprint;
pub mod pack;
pub mod residual_island;
pub mod trit;

pub use activation_tap::{ActivationTap, ActivationTapError};
pub use backend::{BackendKind, TernaryBackend};
pub use fused_rmsnorm::{
    fused_rmsnorm_gemv, rmsnorm_into, FusedRmsnormError, RmsNormParams,
};
pub use gemv::{gemv_block_scaled, GemvBlock, GemvError, GEMV_BLOCK_TRITS};
pub use kv_fingerprint::{
    fingerprint_distance, fingerprint_k_vector, FingerprintError, KvFingerprint,
};
pub use pack::{pack_trits_u32, unpack_trits_u32, PackError, TRITS_PER_U32};
pub use residual_island::{
    fused_gemv_residual, ResidualIsland, ResidualIslandError, ResidualIslandRow,
};
pub use trit::Trit;
