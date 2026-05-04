//! `helios-models` — Model tracks: transformer and SSM unified under Helios memory.
//!
//! This crate implements the model architecture layer of the Epistenos
//! deterministic superintelligence system.  It provides **two parallel tracks**
//! that share the same 6-tier memory substrate:
//!
//! | Track | Module | Architecture | Key feature |
//! |-------|--------|--------------|-------------|
//! | **Transformer** | [`transformer`] | Qwen3-8B | Shadow-first attention, KV-Direct, RoPE, ½-Lipschitz softmax |
//! | **SSM** | [`ssm`] | Mamba-2 | Selective state space, causal conv1d, cross-arch resonance |
//! | **Quantisation** | [`bitnet`] | BitNet 1.58-bit | Ternary weights + residual islands |
//! | **Adaptation** | [`ttt`] | Test-Time Training | Online inner-weight updates |
//!
//! # Quick start
//!
//! ```rust,ignore
//! use helios_models::{
//!     Qwen3Helios, Qwen3Config,
//!     Mamba2Helios, Mamba2Config,
//!     BitNetConfig, TernaryLinear,
//!     TTTLinear, TTTConfig,
//! };
//! ```
//!
//! # Design decisions
//!
//! * **Unified memory substrate** — both transformer and SSM use the same
//!   [`TieredAllocator`](helios_mlx::TieredAllocator), enabling cross-architecture
//!   memory accounting and online equivalence checks.
//! * **½-Lipschitz softmax** — the 2025 result (not the older 1-Lipschitz bound)
//!   is used in the attention stability analysis.
//! * **Real hot-path code** — attention, MLP, SSM step, RoPE, and RMSNorm are
//!   all real numerical implementations.  MLX tensor operations are stubbed with
//!   [`TensorView`](helios_mlx::types::TensorView) descriptors since the exact
//!   `mlx-rs` API is still stabilising.
//! * **BitNet ternary** — provides ~1.5× decode speedup with <1% accuracy loss
//!   when residual islands are enabled.
//! * **TTT online adaptation** — replaces attention for selected layers with
//!   an inner model that trains at test time.

#![warn(missing_docs)]
#![warn(rust_2018_idioms)]

pub mod bitnet;
pub mod ssm;
pub mod transformer;
pub mod ttt;
pub mod types;

// Re-exports for ergonomic top-level access.

// ---- types ----------------------------------------------------------------
pub use types::{
    ActivationType, Mamba2Config, ModelConfig, Qwen3Config, TransformerBlockConfig,
};

// ---- transformer ----------------------------------------------------------
pub use transformer::{
    HeliosAttentionLayer, HeliosMLP, HeliosTransformerBlock, Qwen3Helios,
    ResidualGate, ResonanceGate, RMSNorm, RoPE, TransformerError, TransformerResult,
    softmax_half_lipschitz,
};

// ---- ssm ------------------------------------------------------------------
pub use ssm::{
    CausalConv1d, Mamba2Block, Mamba2Helios, SelectiveSSM, SSMState,
    SsmError, SsmResult,
};

// ---- bitnet ---------------------------------------------------------------
pub use bitnet::{
    BitNetCheckpoint, BitNetConfig, BitNetError, BitNetResult,
    LayerType, PackedTritBlock, ResidualIsland, TernaryLinear,
    load_bitnet_weights,
    DENSE_LAYERS, TERNARY_LAYERS,
};

// ---- ttt ------------------------------------------------------------------
pub use ttt::{
    TTTConfig, TTTError, TTTLinear, TTTResult,
    ttt_attention_replacement,
};
