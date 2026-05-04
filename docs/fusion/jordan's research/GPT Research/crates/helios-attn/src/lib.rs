//! Attention orchestrator crate tying page routing to core tier policy.

pub use helios_mlx::{AttentionOutput, PageOracle, ShadowFirstAttention};

/// Acceptance threshold for the first KV-Direct gate.
pub const KV_DIRECT_KL_THRESHOLD: f32 = 0.05;
