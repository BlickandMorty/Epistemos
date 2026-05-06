//! HELIOS V5 Tier-1 Metal-kernel reference implementations.
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §1 + §3
//! W6/W7/W8: Tier-1 kernel drop-ins are mathematically equivalent to
//! their reference paths within a tight ULP bound. This module hosts
//! the **pure-Rust reference implementations** that lock the
//! correctness contract; Metal acceleration on top of these
//! references lands in a follow-up slice gated on the M2 Max
//! falsifier rig (W25).
//!
//! - [`asa_index`] — W6 Active-Support Atlas indexing (sparse-mask
//!   matmul; ULP-equality vs dense reference)
//! - [`softmax`] — W7 Half-softmax post-not-pre rewrite (≤ 2 ULP
//!   drift vs IEEE-754 reference)
//!
//! ## §2.5.2 compliance posture
//!
//! Tier 1 ON in MAS by default. All implementations are pure-Rust
//! `f32` arithmetic; no Metal kernel + no model file change at this
//! tier. The Metal-accelerated drop-ins (which DO change `.metallib`
//! contents) ship under the `Experimental Metal Kernels` Settings
//! toggle (W11) defaulting OFF — that's the Tier-2 follow-up.

pub mod asa_index;
pub mod softmax;
