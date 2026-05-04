//! Model types and configuration interfaces.
//!
//! This module defines the shared configuration traits and concrete structs
//! for all model architectures in the Helios system: Qwen3 transformer,
//! Mamba-2 SSM, and the unified BitNet / TTT layers.

use serde::{Deserialize, Serialize};

// ---------------------------------------------------------------------------
// ModelConfig trait
// ---------------------------------------------------------------------------

/// Shared configuration interface for all Helios model tracks.
///
/// Both transformer and SSM models implement this trait so that the runtime
/// can query hyperparameters generically.
pub trait ModelConfig {
    /// Total number of layers.
    fn num_layers(&self) -> usize;
    /// Hidden dimension (a.k.a. model dimension, `d_model`).
    fn hidden_dim(&self) -> usize;
    /// Vocabulary size (including any special / padding tokens).
    fn vocab_size(&self) -> usize;
    /// Number of attention heads (or SSM heads).
    fn num_heads(&self) -> usize;
    /// Human-readable model label.
    fn label(&self) -> &'static str;
}

// ---------------------------------------------------------------------------
// ActivationType
// ---------------------------------------------------------------------------

/// Supported non-linear activation functions.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ActivationType {
    /// SwiGLU: `swish(xW) * xV` — used in Llama-2/3, Qwen3, Mistral.
    SwiGLU,
    /// GELU: `x * Φ(x)` where Φ is the standard-normal CDF.
    GELU,
    /// SiLU (a.k.a. Swish-1): `x * sigmoid(x)`.
    SiLU,
}

impl ActivationType {
    /// Evaluate the activation on a single `f32` scalar.
    pub fn apply(self, x: f32) -> f32 {
        match self {
            ActivationType::SwiGLU => {
                // SwiGLU is a gated activation; the raw SiLU part is `x * sigmoid(x)`.
                x * (1.0 / (1.0 + (-x).exp()))
            }
            ActivationType::GELU => {
                // Fast approximate GELU: 0.5 * x * (1 + tanh(sqrt(2/π) * (x + 0.044715 * x^3)))
                gelu_approx(x)
            }
            ActivationType::SiLU => x * (1.0 / (1.0 + (-x).exp())),
        }
    }

    /// Apply the activation elementwise to a `&[f32]` slice.
    pub fn apply_slice(self, xs: &[f32]) -> Vec<f32> {
        xs.iter().map(|&x| self.apply(x)).collect()
    }
}

/// Fast approximate GELU (Hendrycks & Gimpel, 2016).
fn gelu_approx(x: f32) -> f32 {
    let c = (2.0f32 / std::f32::consts::PI).sqrt();
    let tmp = c * (x + 0.044715 * x.powi(3));
    0.5 * x * (1.0 + tmp.tanh())
}

// ---------------------------------------------------------------------------
// TransformerBlockConfig
// ---------------------------------------------------------------------------

/// Per-layer configuration for transformer blocks.
///
/// Some models (e.g. Qwen3-MoE) vary head count or MLP width per layer;
/// this struct captures those per-layer overrides.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TransformerBlockConfig {
    /// Hidden dimension for this layer (usually constant across layers).
    pub hidden_dim: usize,
    /// Number of attention heads for this layer.
    pub num_heads: usize,
    /// Attention head dimension (`hidden_dim / num_heads`).
    pub head_dim: usize,
    /// Intermediate MLP dimension (up-projection width).
    pub intermediate_dim: usize,
    /// Activation type for the MLP gate.
    pub activation: ActivationType,
    /// RMSNorm epsilon.
    pub rms_norm_eps: f32,
    /// Max sequence length supported by RoPE.
    pub max_seq_len: usize,
    /// RoPE theta (frequency base).
    pub rope_theta: f32,
}

impl Default for TransformerBlockConfig {
    fn default() -> Self {
        Self {
            hidden_dim: 4096,
            num_heads: 32,
            head_dim: 128,
            intermediate_dim: 11_008,
            activation: ActivationType::SwiGLU,
            rms_norm_eps: 1e-6,
            max_seq_len: 32_768,
            rope_theta: 1_000_000.0,
        }
    }
}

// ---------------------------------------------------------------------------
// Qwen3Config
// ---------------------------------------------------------------------------

/// Hyperparameters for Qwen3-8B and compatible sizes.
///
/// Qwen3 uses:
/// * GQA (grouped-query attention) with `num_key_value_heads` < `num_heads`
/// * SwiGLU MLP
/// * RMSNorm pre-norm
/// * RoPE with extended base (`rope_theta = 1_000_000` for 128k context)
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Qwen3Config {
    /// Number of transformer layers.
    pub num_layers: usize,
    /// Model hidden dimension (`d_model`).
    pub hidden_dim: usize,
    /// Vocabulary size.
    pub vocab_size: usize,
    /// Number of attention heads.
    pub num_attention_heads: usize,
    /// Number of key/value heads (GQA).
    pub num_key_value_heads: usize,
    /// Intermediate MLP width.
    pub intermediate_dim: usize,
    /// RMSNorm epsilon.
    pub rms_norm_eps: f32,
    /// RoPE theta base.
    pub rope_theta: f32,
    /// Max supported sequence length.
    pub max_position_embeddings: usize,
    /// Attention dropout (0.0 for inference).
    pub attention_dropout: f32,
    /// Per-layer config overrides (if empty, use defaults derived from this struct).
    pub layer_configs: Vec<TransformerBlockConfig>,
    /// Use KV-Direct sparse reconstruction.
    pub use_kv_direct: bool,
    /// KV-Direct checkpoint interval.
    pub kv_direct_interval: usize,
    /// BitNet ternary enabled on these layers (empty = all eligible layers).
    pub ternary_layers: Vec<usize>,
    /// Residual island density (fraction of weights kept dense, 0.0 … 1.0).
    pub residual_island_density: f32,
}

impl Default for Qwen3Config {
    fn default() -> Self {
        let num_layers = 32;
        let hidden_dim = 4096;
        let num_heads = 32;
        let head_dim = hidden_dim / num_heads;
        let mut layer_configs = Vec::with_capacity(num_layers);
        for _ in 0..num_layers {
            layer_configs.push(TransformerBlockConfig {
                hidden_dim,
                num_heads,
                head_dim,
                intermediate_dim: 11_008,
                activation: ActivationType::SwiGLU,
                rms_norm_eps: 1e-6,
                max_seq_len: 32_768,
                rope_theta: 1_000_000.0,
            });
        }
        Self {
            num_layers,
            hidden_dim,
            vocab_size: 151_936,
            num_attention_heads: num_heads,
            num_key_value_heads: 4,
            intermediate_dim: 11_008,
            rms_norm_eps: 1e-6,
            rope_theta: 1_000_000.0,
            max_position_embeddings: 32_768,
            attention_dropout: 0.0,
            layer_configs,
            use_kv_direct: true,
            kv_direct_interval: 64,
            ternary_layers: Vec::new(),
            residual_island_density: 0.005,
        }
    }
}

impl ModelConfig for Qwen3Config {
    fn num_layers(&self) -> usize {
        self.num_layers
    }

    fn hidden_dim(&self) -> usize {
        self.hidden_dim
    }

    fn vocab_size(&self) -> usize {
        self.vocab_size
    }

    fn num_heads(&self) -> usize {
        self.num_attention_heads
    }

    fn label(&self) -> &'static str {
        "Qwen3-8B-Helios"
    }
}

// ---------------------------------------------------------------------------
// Mamba2Config
// ---------------------------------------------------------------------------

/// Hyperparameters for Mamba-2 state-space models.
///
/// Mamba-2 uses:
/// * SSD (selective state space) with structured matrices
/// * Causal 1-D convolution before the SSM core
/// * Linear projections without bias
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Mamba2Config {
    /// Number of SSM layers.
    pub num_layers: usize,
    /// Model hidden dimension.
    pub hidden_dim: usize,
    /// Vocabulary size.
    pub vocab_size: usize,
    /// State expansion factor (usually 2 or 4).
    pub state_expansion: usize,
    /// Convolution kernel size (causal conv1d width).
    pub conv_kernel: usize,
    /// SSM dimension (`hidden_dim * state_expansion`).
    pub ssm_dim: usize,
    /// Number of heads for tensor-parallel SSM.
    pub num_heads: usize,
    /// RMSNorm epsilon.
    pub rms_norm_eps: f32,
    /// Use short convolution before SSM.
    pub use_conv: bool,
    /// dt (delta-t) rank for discretisation.
    pub dt_rank: usize,
    /// Use BitNet ternary on selected layers.
    pub ternary_layers: Vec<usize>,
    /// Residual island density.
    pub residual_island_density: f32,
}

impl Default for Mamba2Config {
    fn default() -> Self {
        let hidden_dim = 4096;
        let state_expansion = 2;
        Self {
            num_layers: 24,
            hidden_dim,
            vocab_size: 50_000,
            state_expansion,
            conv_kernel: 4,
            ssm_dim: hidden_dim * state_expansion,
            num_heads: 8,
            rms_norm_eps: 1e-6,
            use_conv: true,
            dt_rank: 16,
            ternary_layers: Vec::new(),
            residual_island_density: 0.005,
        }
    }
}

impl ModelConfig for Mamba2Config {
    fn num_layers(&self) -> usize {
        self.num_layers
    }

    fn hidden_dim(&self) -> usize {
        self.hidden_dim
    }

    fn vocab_size(&self) -> usize {
        self.vocab_size
    }

    fn num_heads(&self) -> usize {
        self.num_heads
    }

    fn label(&self) -> &'static str {
        "Mamba2-Helios"
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn model_config_trait_for_qwen3() {
        let cfg = Qwen3Config::default();
        assert_eq!(cfg.num_layers(), 32);
        assert_eq!(cfg.hidden_dim(), 4096);
        assert_eq!(cfg.vocab_size(), 151_936);
        assert_eq!(cfg.num_heads(), 32);
        assert_eq!(cfg.label(), "Qwen3-8B-Helios");
    }

    #[test]
    fn model_config_trait_for_mamba2() {
        let cfg = Mamba2Config::default();
        assert_eq!(cfg.num_layers(), 24);
        assert_eq!(cfg.hidden_dim(), 4096);
        assert_eq!(cfg.vocab_size(), 50_000);
        assert_eq!(cfg.num_heads(), 8);
        assert_eq!(cfg.label(), "Mamba2-Helios");
    }

    #[test]
    fn activation_silu_matches_reference() {
        let xs: Vec<f32> = vec![-2.0, -1.0, 0.0, 1.0, 2.0];
        let out = ActivationType::SiLU.apply_slice(&xs);
        // SiLU(0) = 0
        assert!(out[2].abs() < 1e-6);
        // SiLU(2) ≈ 2 * sigmoid(2) ≈ 1.7616
        assert!((out[4] - 1.761_594).abs() < 1e-4);
    }

    #[test]
    fn activation_gelu_approximate() {
        // GELU(0) ≈ 0
        assert!(ActivationType::GELU.apply(0.0).abs() < 1e-3);
        // GELU(2) ≈ 1.954
        let y = ActivationType::GELU.apply(2.0);
        assert!((y - 1.954_5).abs() < 1e-3);
    }

    #[test]
    fn qwen3_layer_configs_populated() {
        let cfg = Qwen3Config::default();
        assert_eq!(cfg.layer_configs.len(), cfg.num_layers);
        for lc in &cfg.layer_configs {
            assert_eq!(lc.hidden_dim, cfg.hidden_dim);
            assert_eq!(lc.num_heads, cfg.num_attention_heads);
        }
    }

    #[test]
    fn mamba2_ssm_dim_derived() {
        let cfg = Mamba2Config::default();
        assert_eq!(cfg.ssm_dim, cfg.hidden_dim * cfg.state_expansion);
    }

    #[test]
    fn transformer_block_config_default() {
        let d = TransformerBlockConfig::default();
        assert_eq!(d.hidden_dim, 4096);
        assert_eq!(d.head_dim, 128);
        assert_eq!(d.intermediate_dim, 11_008);
        assert!(matches!(d.activation, ActivationType::SwiGLU));
    }
}
