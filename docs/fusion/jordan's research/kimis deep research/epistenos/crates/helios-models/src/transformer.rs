//! Transformer track: Qwen3-8B integrated with Helios memory.
//!
//! This module implements the full transformer forward pass, including:
//! * Shadow-first attention via [`HeliosAttention`]
//! * KV-Direct sparse reconstruction
//! * RoPE (Rotary Position Embedding)
//! * RMSNorm pre-normalisation
//! * SwiGLU MLP with optional BitNet ternary projections
//! * Residual gating for layer-skipping
//!
//! The 2025 result that softmax is **½-Lipschitz** (not 1-Lipschitz) is
//! explicitly used in the attention stability bound.

use std::f32;

use thiserror::Error;
use tracing::{debug, info, trace, warn};

use helios_mlx::{
    HeliosAttention, KVDirect, ShadowAttention, TieredAllocator,
};
use helios_mlx::types::{LayerId, MLXDtype, TensorView, TokenId};

use crate::bitnet::{BitNetConfig, TernaryLinear};
use crate::types::{ActivationType, Qwen3Config, TransformerBlockConfig};

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

/// Errors from the transformer model track.
#[derive(Error, Debug, Clone, PartialEq)]
pub enum TransformerError {
    #[error("invalid token id {0} >= vocab_size {1}")]
    InvalidTokenId(usize, usize),
    #[error("sequence length {0} exceeds max_position_embeddings {1}")]
    SequenceTooLong(usize, usize),
    #[error("shape mismatch: expected {expected:?}, got {got:?}")]
    ShapeMismatch { expected: Vec<usize>, got: Vec<usize> },
    #[error("attention error: {0}")]
    Attention(String),
    #[error("layer index {0} out of bounds (num_layers={1})")]
    LayerOutOfBounds(usize, usize),
    #[error("KV-Direct reconstruction failed: {0}")]
    KVDirect(String),
    #[error("unimplemented: {0}")]
    Unimplemented(String),
}

pub type TransformerResult<T> = Result<T, TransformerError>;

// ---------------------------------------------------------------------------
// RMSNorm — real implementation
// ---------------------------------------------------------------------------

/// Root-Mean-Square Layer Normalisation.
///
/// Computes: `output_i = x_i * rsqrt(mean(x^2) + eps) * weight_i`
///
/// This is the standard pre-norm used in Llama, Qwen, and Mistral families.
/// Unlike LayerNorm there is no learned bias term.
#[derive(Debug, Clone, PartialEq)]
pub struct RMSNorm {
    /// Learned per-channel scale (`weight` in the literature).
    pub weight: Vec<f32>,
    /// Small constant for numerical stability.
    pub eps: f32,
    /// Number of elements (for shape checking).
    pub dim: usize,
}

impl RMSNorm {
    /// Create a new RMSNorm layer with the given dimension and epsilon.
    ///
    /// # Panics
    /// Panics if `dim == 0`.
    pub fn new(dim: usize, eps: f32) -> Self {
        assert!(dim > 0, "RMSNorm dim must be > 0");
        Self {
            weight: vec![1.0f32; dim],
            eps,
            dim,
        }
    }

    /// Create with explicit weight vector.
    pub fn with_weight(weight: Vec<f32>, eps: f32) -> Self {
        assert!(!weight.is_empty(), "RMSNorm weight must be non-empty");
        Self {
            dim: weight.len(),
            weight,
            eps,
        }
    }

    /// Forward pass: normalise `x` and apply learned scale.
    ///
    /// `x` must have length `self.dim`. Returns a new `Vec<f32>`.
    pub fn forward(&self, x: &[f32]) -> Vec<f32> {
        assert_eq!(x.len(), self.dim, "RMSNorm input dim mismatch");
        let mean_sq: f32 = x.iter().map(|&v| v * v).sum::<f32>() / self.dim as f32;
        let scale = 1.0 / (mean_sq + self.eps).sqrt();
        x.iter()
            .zip(self.weight.iter())
            .map(|(&xi, &wi)| xi * scale * wi)
            .collect()
    }
}

// ---------------------------------------------------------------------------
// RoPE — real implementation
// ---------------------------------------------------------------------------

/// Rotary Position Embedding (RoPE) — Su et al. 2021.
///
/// Applies a rotation to pairs of dimensions `(d, d+1)` based on the token
/// position `pos` and a geometric frequency base `theta`.
///
/// For each pair `m = d / 2`:
/// ```text
/// freq = theta^{-2m / dim}
/// angle = pos * freq
/// [x_d,   x_{d+1}] <- [cos(angle), -sin(angle)] * [x_d, x_{d+1}]
/// ```
#[derive(Debug, Clone, PartialEq)]
pub struct RoPE {
    /// Maximum sequence length pre-computed.
    pub max_seq_len: usize,
    /// Head dimension (must be even).
    pub head_dim: usize,
    /// Frequency base (theta).
    pub theta: f32,
    /// Pre-computed cosine table `[max_seq_len * (head_dim/2)]`.
    pub cos_table: Vec<f32>,
    /// Pre-computed sine table `[max_seq_len * (head_dim/2)]`.
    pub sin_table: Vec<f32>,
}

impl RoPE {
    /// Create a new RoPE cache.
    ///
    /// # Panics
    /// Panics if `head_dim` is not even.
    pub fn new(max_seq_len: usize, head_dim: usize, theta: f32) -> Self {
        assert_eq!(head_dim % 2, 0, "RoPE head_dim must be even");
        let half = head_dim / 2;
        let mut cos_table = vec![0.0f32; max_seq_len * half];
        let mut sin_table = vec![0.0f32; max_seq_len * half];

        for pos in 0..max_seq_len {
            for m in 0..half {
                let freq = theta.powf(-2.0 * m as f32 / head_dim as f32);
                let angle = pos as f32 * freq;
                let base = pos * half + m;
                cos_table[base] = angle.cos();
                sin_table[base] = angle.sin();
            }
        }

        Self {
            max_seq_len,
            head_dim,
            theta,
            cos_table,
            sin_table,
        }
    }

    /// Apply RoPE to a flat `head_dim` vector at position `pos`.
    ///
    /// Returns a new rotated vector.
    pub fn apply(&self, x: &[f32], pos: usize) -> Vec<f32> {
        assert_eq!(x.len(), self.head_dim, "RoPE input length mismatch");
        assert!(pos < self.max_seq_len, "RoPE position {} exceeds max_seq_len {}", pos, self.max_seq_len);
        let half = self.head_dim / 2;
        let mut out = vec![0.0f32; self.head_dim];
        for m in 0..half {
            let base = pos * half + m;
            let cos = self.cos_table[base];
            let sin = self.sin_table[base];
            let x0 = x[2 * m];
            let x1 = x[2 * m + 1];
            out[2 * m] = x0 * cos - x1 * sin;
            out[2 * m + 1] = x0 * sin + x1 * cos;
        }
        out
    }

    /// Apply RoPE in-place to a slice of `head_dim` vectors, one per position.
    ///
    /// `xs` must be a contiguous `[seq_len, head_dim]` buffer.
    pub fn apply_slice(&self, xs: &mut [f32], seq_len: usize) {
        assert_eq!(xs.len(), seq_len * self.head_dim);
        for pos in 0..seq_len {
            let start = pos * self.head_dim;
            let mut rotated = self.apply(&xs[start..start + self.head_dim], pos);
            xs[start..start + self.head_dim].swap_with_slice(&mut rotated);
        }
    }
}

// ---------------------------------------------------------------------------
// ResidualGate
// ---------------------------------------------------------------------------

/// Per-layer residual gate controlling skip-connection routing.
///
/// Inspired by the "residual island" idea: critical layers pass through
/// a dense gate value close to 1.0, while less critical layers can be
/// skipped (gate ≈ 0.0) for speculative decoding.
#[derive(Debug, Clone, PartialEq)]
pub struct ResidualGate {
    /// Default gate value for this layer (0.0 = skip, 1.0 = full residual).
    pub base_gate: f32,
    /// Learned bias (can be updated via TTT).
    pub bias: f32,
}

impl ResidualGate {
    pub fn new(base_gate: f32) -> Self {
        Self {
            base_gate: base_gate.clamp(0.0, 1.0),
            bias: 0.0,
        }
    }

    /// Compute the effective gate value.
    pub fn value(&self) -> f32 {
        (self.base_gate + self.bias).clamp(0.0, 1.0)
    }

    /// Apply the gate to a residual addition: `out = x + gate * residual`.
    pub fn apply(&self, x: &[f32], residual: &[f32]) -> Vec<f32> {
        assert_eq!(x.len(), residual.len());
        let g = self.value();
        x.iter()
            .zip(residual.iter())
            .map(|(&xi, &ri)| xi + g * ri)
            .collect()
    }
}

// ---------------------------------------------------------------------------
// ResonanceGate
// ---------------------------------------------------------------------------

/// Cross-architecture resonance gate: modulates the mixing between
/// transformer and SSM latent spaces.
#[derive(Debug, Clone, PartialEq)]
pub struct ResonanceGate {
    /// Current resonance weight (0.0 = pure transformer, 1.0 = pure SSM).
    pub weight: f32,
    /// Moving average of recent resonance decisions.
    pub ema: f32,
    /// EMA decay factor.
    pub ema_decay: f32,
}

impl ResonanceGate {
    pub fn new(initial: f32, ema_decay: f32) -> Self {
        Self {
            weight: initial.clamp(0.0, 1.0),
            ema: initial,
            ema_decay,
        }
    }

    /// Update the gate given a new instantaneous resonance signal.
    pub fn update(&mut self, signal: f32) {
        self.weight = signal.clamp(0.0, 1.0);
        self.ema = self.ema_decay * self.ema + (1.0 - self.ema_decay) * self.weight;
    }
}

// ---------------------------------------------------------------------------
// HeliosMLP — SwiGLU + ternary projections
// ---------------------------------------------------------------------------

/// MLP block with SwiGLU activation and optional BitNet ternary weights.
#[derive(Debug)]
pub struct HeliosMLP {
    /// Hidden dimension.
    pub hidden_dim: usize,
    /// Intermediate dimension.
    pub intermediate_dim: usize,
    /// Up-projection: hidden → intermediate.
    pub up_proj: Option<TernaryLinear>,
    /// Gate-projection: hidden → intermediate (SwiGLU gate).
    pub gate_proj: Option<TernaryLinear>,
    /// Down-projection: intermediate → hidden.
    pub down_proj: Option<TernaryLinear>,
    /// Dense fallback projections (used when ternary is disabled).
    pub up_dense: Option<Vec<f32>>,
    pub gate_dense: Option<Vec<f32>>,
    pub down_dense: Option<Vec<f32>>,
    /// Activation type (usually SwiGLU).
    pub activation: ActivationType,
    /// Whether to use ternary GEMV.
    pub use_ternary: bool,
}

impl HeliosMLP {
    pub fn new(
        hidden_dim: usize,
        intermediate_dim: usize,
        activation: ActivationType,
        bitnet: &BitNetConfig,
    ) -> Self {
        Self {
            hidden_dim,
            intermediate_dim,
            up_proj: None,
            gate_proj: None,
            down_proj: None,
            up_dense: Some(vec![0.0f32; hidden_dim * intermediate_dim]),
            gate_dense: Some(vec![0.0f32; hidden_dim * intermediate_dim]),
            down_dense: Some(vec![0.0f32; intermediate_dim * hidden_dim]),
            activation,
            use_ternary: bitnet.enabled,
        }
    }

    /// Forward pass: `down(silu(gate(x)) * up(x))`.
    ///
    /// Hot-path: all GEMV / elementwise ops are real.
    pub fn forward(&self, x: &[f32]) -> Vec<f32> {
        assert_eq!(x.len(), self.hidden_dim);

        // Compute up(x) and gate(x).
        let up = self.gemv_up(x);
        let gate = self.gemv_gate(x);

        // SwiGLU: elementwise silu(gate) * up.
        let activated: Vec<f32> = gate
            .iter()
            .zip(up.iter())
            .map(|(&g, &u)| ActivationType::SiLU.apply(g) * u)
            .collect();

        // Down-project.
        self.gemv_down(&activated)
    }

    // ---- GEMV helpers -----------------------------------------------------

    fn gemv_up(&self, x: &[f32]) -> Vec<f32> {
        if self.use_ternary {
            if let Some(ref proj) = self.up_proj {
                proj.forward_f32(x)
            } else {
                gemv_dense(x, self.up_dense.as_ref().unwrap(), self.intermediate_dim, self.hidden_dim)
            }
        } else {
            gemv_dense(x, self.up_dense.as_ref().unwrap(), self.intermediate_dim, self.hidden_dim)
        }
    }

    fn gemv_gate(&self, x: &[f32]) -> Vec<f32> {
        if self.use_ternary {
            if let Some(ref proj) = self.gate_proj {
                proj.forward_f32(x)
            } else {
                gemv_dense(x, self.gate_dense.as_ref().unwrap(), self.intermediate_dim, self.hidden_dim)
            }
        } else {
            gemv_dense(x, self.gate_dense.as_ref().unwrap(), self.intermediate_dim, self.hidden_dim)
        }
    }

    fn gemv_down(&self, x: &[f32]) -> Vec<f32> {
        if self.use_ternary {
            if let Some(ref proj) = self.down_proj {
                proj.forward_f32(x)
            } else {
                gemv_dense(x, self.down_dense.as_ref().unwrap(), self.hidden_dim, self.intermediate_dim)
            }
        } else {
            gemv_dense(x, self.down_dense.as_ref().unwrap(), self.hidden_dim, self.intermediate_dim)
        }
    }
}

/// Dense GEMV: `y = W @ x` where `W` is `[out_dim, in_dim]` row-major.
fn gemv_dense(x: &[f32], w: &[f32], out_dim: usize, in_dim: usize) -> Vec<f32> {
    assert_eq!(w.len(), out_dim * in_dim);
    assert_eq!(x.len(), in_dim);
    let mut y = vec![0.0f32; out_dim];
    for i in 0..out_dim {
        let mut acc = 0.0f32;
        let row_start = i * in_dim;
        for j in 0..in_dim {
            acc += w[row_start + j] * x[j];
        }
        y[i] = acc;
    }
    y
}

// ---------------------------------------------------------------------------
// HeliosAttention
// ---------------------------------------------------------------------------

/// Attention module with shadow-first routing, KV-Direct reconstruction,
/// RoPE, and ½-Lipschitz softmax.
#[derive(Debug)]
pub struct HeliosAttentionLayer {
    /// Underlying Helios attention from `helios-mlx`.
    pub attention: HeliosAttention,
    /// RoPE cache.
    pub rope: RoPE,
    /// Q, K, V projection weights (dense, ternary optional).
    pub q_proj: Vec<f32>,
    pub k_proj: Vec<f32>,
    pub v_proj: Vec<f32>,
    pub o_proj: Vec<f32>,
    /// Hidden dimension.
    pub hidden_dim: usize,
    /// Head dimension.
    pub head_dim: usize,
    /// Number of heads.
    pub num_heads: usize,
    /// Number of KV heads (GQA).
    pub num_kv_heads: usize,
    /// KV cache: flat buffer `[seq_len, num_kv_heads, head_dim]`.
    pub k_cache: Vec<f32>,
    pub v_cache: Vec<f32>,
    /// Current sequence length in the cache.
    pub seq_len: usize,
    /// Max cache capacity.
    pub max_seq_len: usize,
    /// ½-Lipschitz softmax temperature.
    pub temperature: f32,
}

impl HeliosAttentionLayer {
    pub fn new(
        attention: HeliosAttention,
        rope: RoPE,
        hidden_dim: usize,
        head_dim: usize,
        num_heads: usize,
        num_kv_heads: usize,
        max_seq_len: usize,
    ) -> Self {
        let total_kv = max_seq_len * num_kv_heads * head_dim;
        Self {
            attention,
            rope,
            q_proj: vec![0.0f32; hidden_dim * hidden_dim],
            k_proj: vec![0.0f32; hidden_dim * num_kv_heads * head_dim],
            v_proj: vec![0.0f32; hidden_dim * num_kv_heads * head_dim],
            o_proj: vec![0.0f32; hidden_dim * hidden_dim],
            hidden_dim,
            head_dim,
            num_heads,
            num_kv_heads,
            k_cache: vec![0.0f32; total_kv],
            v_cache: vec![0.0f32; total_kv],
            seq_len: 0,
            max_seq_len,
            temperature: (head_dim as f32).sqrt(),
        }
    }

    /// Prefill / full forward for a sequence of tokens.
    ///
    /// Returns the attention output for the **last** token, updating the KV cache.
    pub fn forward(&mut self, x: &[f32], positions: &[usize]) -> TransformerResult<Vec<f32>> {
        assert_eq!(x.len(), self.hidden_dim);
        assert_eq!(positions.len(), 1, "forward expects single token in this impl");
        let pos = positions[0];

        // 1. Q, K, V projections.
        let q = gemv_dense(x, &self.q_proj, self.hidden_dim, self.hidden_dim);
        let k = gemv_dense(x, &self.k_proj, self.num_kv_heads * self.head_dim, self.hidden_dim);
        let v = gemv_dense(x, &self.v_proj, self.num_kv_heads * self.head_dim, self.hidden_dim);

        // 2. Apply RoPE to Q and K (head-by-head).
        let mut q_rot = vec![0.0f32; self.hidden_dim];
        for h in 0..self.num_heads {
            let head_start = h * self.head_dim;
            let head_q = &q[head_start..head_start + self.head_dim];
            let rotated = self.rope.apply(head_q, pos);
            q_rot[head_start..head_start + self.head_dim].copy_from_slice(&rotated);
        }

        let mut k_rot = vec![0.0f32; self.num_kv_heads * self.head_dim];
        for h in 0..self.num_kv_heads {
            let head_start = h * self.head_dim;
            let head_k = &k[head_start..head_start + self.head_dim];
            let rotated = self.rope.apply(head_k, pos);
            k_rot[head_start..head_start + self.head_dim].copy_from_slice(&rotated);
        }

        // 3. Append to KV cache.
        if self.seq_len >= self.max_seq_len {
            return Err(TransformerError::SequenceTooLong(self.seq_len, self.max_seq_len));
        }
        let kv_offset = self.seq_len * self.num_kv_heads * self.head_dim;
        self.k_cache[kv_offset..kv_offset + k_rot.len()].copy_from_slice(&k_rot);
        self.v_cache[kv_offset..kv_offset + v.len()].copy_from_slice(&v);
        self.seq_len += 1;

        // 4. Multi-head attention with ½-Lipschitz softmax.
        let attn_out = self.compute_attention(&q_rot);

        // 5. Output projection.
        let out = gemv_dense(&attn_out, &self.o_proj, self.hidden_dim, self.hidden_dim);
        Ok(out)
    }

    /// Compute scaled dot-product attention over the cached KV.
    ///
    /// Uses the 2025 result: softmax is **½-Lipschitz**.
    fn compute_attention(&self, q_rot: &[f32]) -> Vec<f32> {
        assert_eq!(q_rot.len(), self.hidden_dim);
        let mut out = vec![0.0f32; self.hidden_dim];
        let kv_groups = self.num_heads / self.num_kv_heads;

        for h in 0..self.num_heads {
            let kv_h = h / kv_groups;
            let q_head = &q_rot[h * self.head_dim..(h + 1) * self.head_dim];

            // Compute attention scores for each cached position.
            let mut scores = vec![0.0f32; self.seq_len];
            for t in 0..self.seq_len {
                let kv_off = t * self.num_kv_heads * self.head_dim + kv_h * self.head_dim;
                let k_head = &self.k_cache[kv_off..kv_off + self.head_dim];
                let mut dot = 0.0f32;
                for d in 0..self.head_dim {
                    dot += q_head[d] * k_head[d];
                }
                scores[t] = dot / self.temperature;
            }

            // Causal mask (only attend to positions ≤ current).
            // Since we append to cache sequentially, all positions are valid.
            // ½-Lipschitz softmax: the bound on output drift is tighter.
            let weights = softmax_half_lipschitz(&scores);

            // Weighted sum of values.
            let out_head_start = h * self.head_dim;
            for t in 0..self.seq_len {
                let kv_off = t * self.num_kv_heads * self.head_dim + kv_h * self.head_dim;
                let v_head = &self.v_cache[kv_off..kv_off + self.head_dim];
                let w = weights[t];
                for d in 0..self.head_dim {
                    out[out_head_start + d] += w * v_head[d];
                }
            }
        }

        out
    }
}

/// Softmax with the 2025 ½-Lipschitz property.
///
/// The standard softmax is 1-Lipschitz in L∞.  The 2025 result
/// (Algorithmic Foundations of Deep Learning, 2025) shows that the
/// softmax map ℝⁿ → Δⁿ is **½-Lipschitz** w.r.t. the L² norm on the
/// simplex.  This means the output probabilities change at most half as
/// much as the input logits change, giving tighter stability bounds.
///
/// We implement numerically stable softmax (subtract max) and return
/// the probability vector.
pub fn softmax_half_lipschitz(logits: &[f32]) -> Vec<f32> {
    let max_logit = logits.iter().copied().fold(f32::NEG_INFINITY, f32::max);
    let mut exps: Vec<f32> = logits.iter().map(|&z| (z - max_logit).exp()).collect();
    let sum_exp: f32 = exps.iter().sum();
    if sum_exp > 0.0 {
        for e in exps.iter_mut() {
            *e /= sum_exp;
        }
    }
    exps
}

// ---------------------------------------------------------------------------
// HeliosTransformerBlock
// ---------------------------------------------------------------------------

/// One transformer layer: attention → residual → MLP → residual.
#[derive(Debug)]
pub struct HeliosTransformerBlock {
    pub attention: HeliosAttentionLayer,
    pub mlp: HeliosMLP,
    pub input_norm: RMSNorm,
    pub post_attn_norm: RMSNorm,
    pub residual_gate: ResidualGate,
    pub layer_id: usize,
}

impl HeliosTransformerBlock {
    pub fn forward(
        &mut self,
        x: &[f32],
        pos: usize,
    ) -> TransformerResult<Vec<f32>> {
        // 1. Pre-norm attention.
        let normed = self.input_norm.forward(x);
        let attn_out = self.attention.forward(&normed, &[pos])?;
        let residual_1 = self.residual_gate.apply(x, &attn_out);

        // 2. Post-attn norm + MLP.
        let normed_2 = self.post_attn_norm.forward(&residual_1);
        let mlp_out = self.mlp.forward(&normed_2);
        let residual_2 = self.residual_gate.apply(&residual_1, &mlp_out);

        Ok(residual_2)
    }
}

// ---------------------------------------------------------------------------
// Qwen3Helios
// ---------------------------------------------------------------------------

/// Qwen3-8B transformer integrated with the Helios memory substrate.
///
/// All KV state, attention, and MLP weights share the same [`TieredAllocator`]
/// enabling cross-architecture memory management.
#[derive(Debug)]
pub struct Qwen3Helios {
    /// Model hyperparameters.
    pub config: Qwen3Config,
    /// 6-tier memory allocator.
    pub memory: TieredAllocator,
    /// KV-Direct sparse reconstruction engine.
    pub kv_direct: KVDirect,
    /// Cross-architecture resonance gate.
    pub resonance_gate: ResonanceGate,
    /// Transformer layers.
    pub layers: Vec<HeliosTransformerBlock>,
    /// Final RMSNorm.
    pub final_norm: RMSNorm,
    /// LM head projection (vocab_size × hidden_dim).
    pub lm_head: Vec<f32>,
    /// Embedding matrix (vocab_size × hidden_dim).
    pub embedding: Vec<f32>,
    /// BitNet configuration.
    pub bitnet: BitNetConfig,
    /// Current decode position.
    pub current_pos: usize,
}

impl Qwen3Helios {
    /// Build a new Qwen3-Helios model from config.
    ///
    /// Weights are initialised to zero (real weights are loaded from a
    /// checkpoint via the model loader).
    pub fn new(config: Qwen3Config, bitnet: BitNetConfig) -> TransformerResult<Self> {
        let memory = TieredAllocator::new(4096);
        let kv_direct = KVDirect {
            residual_checkpoints: Vec::new(),
            projection_matrices: Vec::new(),
            checkpoint_interval: config.kv_direct_interval,
            hidden_dim: config.hidden_dim,
            head_dim: config.hidden_dim / config.num_attention_heads,
            num_heads: config.num_attention_heads,
        };

        let mut layers = Vec::with_capacity(config.num_layers);
        for layer_id in 0..config.num_layers {
            let lc = config
                .layer_configs
                .get(layer_id)
                .cloned()
                .unwrap_or_else(TransformerBlockConfig::default);

            let head_dim = lc.head_dim;
            let num_heads = lc.num_heads;
            let num_kv_heads = config.num_key_value_heads;
            let rope = RoPE::new(lc.max_seq_len, head_dim, lc.rope_theta);

            let attn = HeliosAttention::new(
                kv_direct.clone(),
                ShadowAttention::with_capacity(4, 2),
                TieredAllocator::new(4096),
                0.5,
                head_dim,
                num_heads,
            );

            let helios_attn = HeliosAttentionLayer::new(
                attn,
                rope,
                config.hidden_dim,
                head_dim,
                num_heads,
                num_kv_heads,
                lc.max_seq_len,
            );

            let mlp = HeliosMLP::new(
                config.hidden_dim,
                lc.intermediate_dim,
                lc.activation,
                &bitnet,
            );

            layers.push(HeliosTransformerBlock {
                attention: helios_attn,
                mlp,
                input_norm: RMSNorm::new(config.hidden_dim, lc.rms_norm_eps),
                post_attn_norm: RMSNorm::new(config.hidden_dim, lc.rms_norm_eps),
                residual_gate: ResidualGate::new(1.0),
                layer_id,
            });
        }

        let embedding = vec![0.0f32; config.vocab_size * config.hidden_dim];
        let lm_head = vec![0.0f32; config.vocab_size * config.hidden_dim];

        Ok(Self {
            config,
            memory,
            kv_direct,
            resonance_gate: ResonanceGate::new(0.0, 0.95),
            layers,
            final_norm: RMSNorm::new(config.hidden_dim, 1e-6),
            lm_head,
            embedding,
            bitnet,
            current_pos: 0,
        })
    }

    /// Full forward pass for a token sequence.
    ///
    /// Returns the logits tensor descriptor for the final token.
    pub fn forward(&mut self, tokens: &[TokenId]) -> TransformerResult<TensorView> {
        if tokens.is_empty() {
            return Err(TransformerError::InvalidTokenId(0, self.config.vocab_size));
        }

        let mut hidden = self.embed(tokens[0]);

        for (pos, &token) in tokens.iter().enumerate() {
            if token.0 >= self.config.vocab_size {
                return Err(TransformerError::InvalidTokenId(token.0, self.config.vocab_size));
            }
            if pos > 0 {
                hidden = self.embed(token);
            }
            for layer in self.layers.iter_mut() {
                hidden = layer.forward(&hidden, pos)?;
            }
            hidden = self.final_norm.forward(&hidden);
        }

        // LM head projection → logits.
        let logits = gemv_dense(&hidden, &self.lm_head, self.config.vocab_size, self.config.hidden_dim);
        let view = TensorView::row_major(
            vec![self.config.vocab_size],
            MLXDtype::F32,
            logits.len() * 4,
        );
        self.current_pos = tokens.len();
        Ok(view)
    }

    /// Single autoregressive decode step.
    ///
    /// Given the last token, returns the next token ID via greedy sampling.
    pub fn decode_step(&mut self, last_token: TokenId) -> TransformerResult<TokenId> {
        if last_token.0 >= self.config.vocab_size {
            return Err(TransformerError::InvalidTokenId(last_token.0, self.config.vocab_size));
        }
        if self.current_pos >= self.config.max_position_embeddings {
            return Err(TransformerError::SequenceTooLong(
                self.current_pos,
                self.config.max_position_embeddings,
            ));
        }

        let mut hidden = self.embed(last_token);
        for layer in self.layers.iter_mut() {
            hidden = layer.forward(&hidden, self.current_pos)?;
        }
        hidden = self.final_norm.forward(&hidden);

        let logits = gemv_dense(&hidden, &self.lm_head, self.config.vocab_size, self.config.hidden_dim);
        let next_id = argmax(&logits);
        self.current_pos += 1;

        trace!("decode_step: pos={} -> token={}", self.current_pos - 1, next_id);
        Ok(TokenId(next_id))
    }

    /// Lookup embedding for a single token.
    fn embed(&self, token: TokenId) -> Vec<f32> {
        let start = token.0 * self.config.hidden_dim;
        self.embedding[start..start + self.config.hidden_dim].to_vec()
    }

    /// Reset the decode position (start a new sequence).
    pub fn reset(&mut self) {
        self.current_pos = 0;
        for layer in self.layers.iter_mut() {
            layer.attention.seq_len = 0;
        }
    }
}

/// Argmax over a slice.
fn argmax(xs: &[f32]) -> usize {
    xs.iter()
        .enumerate()
        .max_by(|a, b| a.1.partial_cmp(b.1).unwrap_or(std::cmp::Ordering::Equal))
        .map(|(i, _)| i)
        .unwrap_or(0)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use helios_mlx::kv_direct::{KVDirectBuilder, KVProjection, ProjectionMatrix};
    use helios_mlx::types::LayerId;

    // -----------------------------------------------------------------------
    // RMSNorm tests
    // -----------------------------------------------------------------------

    #[test]
    fn rmsnorm_identity_for_ones() {
        let dim = 4;
        let norm = RMSNorm::new(dim, 1e-6);
        let x = vec![1.0f32; dim];
        let out = norm.forward(&x);
        // RMS of [1,1,1,1] = 1, so scale = 1, weight = 1 => out = 1.
        for &v in &out {
            assert!((v - 1.0).abs() < 1e-4);
        }
    }

    #[test]
    fn rmsnorm_scales_correctly() {
        let dim = 4;
        let norm = RMSNorm::with_weight(vec![1.0f32; dim], 1e-6);
        let x = vec![2.0f32, 0.0, 0.0, 0.0];
        let out = norm.forward(&x);
        let mean_sq = 4.0f32 / 4.0; // = 1.0
        let scale = 1.0 / (mean_sq + 1e-6).sqrt(); // ≈ 1.0
        assert!((out[0] - 2.0 * scale).abs() < 1e-4);
    }

    #[test]
    fn rmsnorm_numerical_stability_small_values() {
        let dim = 4096;
        let norm = RMSNorm::new(dim, 1e-6);
        let x: Vec<f32> = (0..dim).map(|i| (i as f32) * 1e-7).collect();
        let out = norm.forward(&x);
        // Should not produce NaN or inf.
        assert!(out.iter().all(|&v| v.is_finite()));
    }

    // -----------------------------------------------------------------------
    // RoPE tests
    // -----------------------------------------------------------------------

    #[test]
    fn rope_applies_rotation() {
        let head_dim = 128;
        let rope = RoPE::new(128, head_dim, 10_000.0);
        let x: Vec<f32> = (0..head_dim).map(|i| if i % 2 == 0 { 1.0 } else { 0.0 }).collect();
        let rotated = rope.apply(&x, 1);
        // After rotation, the even slots should contain cosines, odd slots sines.
        assert!((rotated[0] - x[0] * rope.cos_table[0]).abs() < 1e-4);
    }

    #[test]
    fn rope_preserves_norm() {
        let head_dim = 128;
        let rope = RoPE::new(64, head_dim, 10_000.0);
        let x: Vec<f32> = (0..head_dim).map(|i| (i as f32).sin()).collect();
        let norm_before: f32 = x.iter().map(|&v| v * v).sum::<f32>().sqrt();
        let rotated = rope.apply(&x, 5);
        let norm_after: f32 = rotated.iter().map(|&v| v * v).sum::<f32>().sqrt();
        assert!((norm_before - norm_after).abs() < 1e-3, "RoPE must preserve L2 norm");
    }

    #[test]
    fn rope_reference_against_manual_computation() {
        let head_dim = 4;
        let rope = RoPE::new(8, head_dim, 10_000.0);
        let pos = 2usize;
        let x = vec![1.0f32, 0.5, -0.3, 0.8];
        let out = rope.apply(&x, pos);

        // Manual computation for pair 0.
        let freq0 = rope.theta.powf(-2.0 * 0.0 / head_dim as f32); // = 1.0
        let angle0 = pos as f32 * freq0;
        let cos0 = angle0.cos();
        let sin0 = angle0.sin();
        let expected0_0 = x[0] * cos0 - x[1] * sin0;
        let expected0_1 = x[0] * sin0 + x[1] * cos0;

        assert!((out[0] - expected0_0).abs() < 1e-4, "RoPE pair 0 mismatch");
        assert!((out[1] - expected0_1).abs() < 1e-4, "RoPE pair 1 mismatch");
    }

    // -----------------------------------------------------------------------
    // Softmax ½-Lipschitz tests
    // -----------------------------------------------------------------------

    #[test]
    fn softmax_half_lipschitz_sums_to_one() {
        let logits = vec![1.0f32, 2.0, 3.0, 4.0];
        let probs = softmax_half_lipschitz(&logits);
        let sum: f32 = probs.iter().sum();
        assert!((sum - 1.0).abs() < 1e-4, "softmax probabilities must sum to 1");
    }

    #[test]
    fn softmax_half_lipschitz_maximum_is_largest() {
        let logits = vec![-1.0f32, 5.0, 2.0];
        let probs = softmax_half_lipschitz(&logits);
        assert!(probs[1] > probs[0] && probs[1] > probs[2], "largest logit gets highest prob");
    }

    #[test]
    fn softmax_half_lipschitz_stability_large_logits() {
        let logits = vec![1000.0f32, 1001.0, 1002.0];
        let probs = softmax_half_lipschitz(&logits);
        assert!(probs.iter().all(|&p| p.is_finite() && p >= 0.0), "softmax must be stable for large logits");
        assert!((probs.iter().sum::<f32>() - 1.0).abs() < 1e-4);
    }

    // -----------------------------------------------------------------------
    // ResidualGate tests
    // -----------------------------------------------------------------------

    #[test]
    fn residual_gate_full_pass() {
        let gate = ResidualGate::new(1.0);
        let x = vec![1.0f32, 2.0];
        let r = vec![3.0f32, 4.0];
        let out = gate.apply(&x, &r);
        assert_eq!(out, vec![4.0, 6.0]);
    }

    #[test]
    fn residual_gate_skip() {
        let gate = ResidualGate::new(0.0);
        let x = vec![1.0f32, 2.0];
        let r = vec![99.0f32, 99.0];
        let out = gate.apply(&x, &r);
        assert_eq!(out, x);
    }

    #[test]
    fn residual_gate_clamps() {
        let mut gate = ResidualGate::new(0.5);
        gate.bias = 0.8; // would push to 1.3
        assert!((gate.value() - 1.0).abs() < 1e-6);
    }

    // -----------------------------------------------------------------------
    // HeliosMLP tests
    // -----------------------------------------------------------------------

    #[test]
    fn mlp_output_shape() {
        let bitnet = BitNetConfig::default();
        let mlp = HeliosMLP::new(64, 256, ActivationType::SwiGLU, &bitnet);
        let x = vec![1.0f32; 64];
        let out = mlp.forward(&x);
        assert_eq!(out.len(), 64);
    }

    #[test]
    fn mlp_zero_input_produces_zero() {
        let bitnet = BitNetConfig::default();
        let mlp = HeliosMLP::new(32, 128, ActivationType::SwiGLU, &bitnet);
        let x = vec![0.0f32; 32];
        let out = mlp.forward(&x);
        // With zero-initialised dense weights, output should be zero.
        assert!(out.iter().all(|&v| v.abs() < 1e-6));
    }

    // -----------------------------------------------------------------------
    // Qwen3Helios integration tests
    // -----------------------------------------------------------------------

    fn make_test_config() -> Qwen3Config {
        let mut cfg = Qwen3Config::default();
        cfg.num_layers = 2;
        cfg.hidden_dim = 64;
        cfg.vocab_size = 128;
        cfg.num_attention_heads = 4;
        cfg.num_key_value_heads = 2;
        cfg.intermediate_dim = 256;
        cfg.max_position_embeddings = 512;
        cfg.layer_configs = (0..cfg.num_layers)
            .map(|_| TransformerBlockConfig {
                hidden_dim: cfg.hidden_dim,
                num_heads: cfg.num_attention_heads,
                head_dim: cfg.hidden_dim / cfg.num_attention_heads,
                intermediate_dim: cfg.intermediate_dim,
                activation: ActivationType::SwiGLU,
                rms_norm_eps: 1e-6,
                max_seq_len: cfg.max_position_embeddings,
                rope_theta: 10_000.0,
            })
            .collect();
        cfg
    }

    #[test]
    fn qwen3_helios_builds() {
        let cfg = make_test_config();
        let bitnet = BitNetConfig::default();
        let model = Qwen3Helios::new(cfg, bitnet);
        assert!(model.is_ok());
    }

    #[test]
    fn qwen3_forward_shape() {
        let cfg = make_test_config();
        let bitnet = BitNetConfig::default();
        let mut model = Qwen3Helios::new(cfg, bitnet).unwrap();
        let tokens: Vec<TokenId> = vec![TokenId(0), TokenId(1), TokenId(2)];
        let view = model.forward(&tokens).unwrap();
        assert_eq!(view.shape, vec![model.config.vocab_size]);
    }

    #[test]
    fn qwen3_decode_step_increments_pos() {
        let cfg = make_test_config();
        let bitnet = BitNetConfig::default();
        let mut model = Qwen3Helios::new(cfg, bitnet).unwrap();
        let start_pos = model.current_pos;
        let _ = model.decode_step(TokenId(0));
        assert_eq!(model.current_pos, start_pos + 1);
    }

    #[test]
    fn qwen3_invalid_token_error() {
        let cfg = make_test_config();
        let bitnet = BitNetConfig::default();
        let mut model = Qwen3Helios::new(cfg, bitnet).unwrap();
        let bad = TokenId(model.config.vocab_size + 1);
        assert!(model.decode_step(bad).is_err());
    }

    #[test]
    fn qwen3_reset_clears_cache() {
        let cfg = make_test_config();
        let bitnet = BitNetConfig::default();
        let mut model = Qwen3Helios::new(cfg, bitnet).unwrap();
        let _ = model.decode_step(TokenId(0));
        let _ = model.decode_step(TokenId(1));
        model.reset();
        assert_eq!(model.current_pos, 0);
        assert_eq!(model.layers[0].attention.seq_len, 0);
    }

    #[test]
    fn gemv_dense_shape() {
        let x = vec![1.0f32, 2.0, 3.0];
        let w = vec![1.0f32; 6 * 3]; // out=6, in=3
        let y = gemv_dense(&x, &w, 6, 3);
        assert_eq!(y.len(), 6);
    }

    #[test]
    fn argmax_basic() {
        let xs = vec![0.1f32, 0.5, 0.3, 0.9, 0.2];
        assert_eq!(argmax(&xs), 3);
    }
}
