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
//! 7. Steering delta apply kernel ([`steering`] — push/pop composable
//!    SteeringStack; Metal port + RepE-style direction-discovery wiring
//!    pending).
//!
//! Substrate floor for J1 kernels #1-#7 complete. Remaining J1 work:
//! - Concrete CPU backend impl on top of these kernels (`DenseMlxBackend`
//!   currently a placeholder; needs MLX-Swift shim).
//! - Metal dispatch wire-in for the 7 kernels via
//!   `Epistemos/Engine/MetalRuntimeManager.swift` (mirroring the W12/W13/W14
//!   toggle pattern in Settings → Experimental Metal Kernels).
//! - ANE backend (Pro-tier; `cs.disable-library-validation` entitlement
//!   path) — gated on `pro-build` + `research` features.
//! - End-to-end falsifier harness: compare TernaryMetalBackend output
//!   against DenseMlxBackend on a 200-prompt RULER subset, target D_KL
//!   under 0.05 per Helios v3 Part IV threshold #1.
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
pub mod kernel_kind;
pub mod kv_fingerprint;
pub mod pack;
pub mod residual_island;
pub mod steering;
pub mod trit;

pub use activation_tap::{ActivationTap, ActivationTapError};
pub use backend::{BackendKind, TernaryBackend};
pub use kernel_kind::{
    validate_optimization, DecodePriority, OptimizationError, TernaryKernelKind,
};
pub use fused_rmsnorm::{fused_rmsnorm_gemv, rmsnorm_into, FusedRmsnormError};
pub use gemv::{gemv_block_scaled, GemvBlock, GemvError, GEMV_BLOCK_TRITS};
pub use kv_fingerprint::{
    fingerprint_distance, fingerprint_k_vector, FingerprintError, KvFingerprint,
};
pub use pack::{pack_trits_u32, unpack_trits_u32, PackError, TRITS_PER_U32};
pub use residual_island::{
    fused_gemv_residual, ResidualIsland, ResidualIslandError, ResidualIslandRow,
};
pub use steering::{apply_delta, SteeringDelta, SteeringError, SteeringStack};
pub use trit::Trit;
