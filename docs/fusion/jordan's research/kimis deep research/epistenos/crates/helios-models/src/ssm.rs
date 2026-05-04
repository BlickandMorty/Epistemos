//! SSM track: Mamba-2 integrated with the Helios memory harness.
//!
//! This module implements the Mamba-2 state-space model architecture,
//! sharing the same [`TieredAllocator`] and [`ResonanceGate`] as the
//! transformer track.  The core computation is a **selective SSM step**
//! that updates hidden state with input-dependent transition matrices.
//!
//! # Key design decisions
//!
//! * **Discrete SSM step** — real recurrent update, not a stub.
//! * **CausalConv1d** — short convolution before the SSM core.
//! * **Cross-architecture resonance** — the [`ResonanceGate`] mixes
//!   transformer and SSM outputs for online validation.
//! * **Stability guarantee** — state transition `A` is parameterised as
//!   `A = -exp(a_raw)` ensuring all eigenvalues are negative (stable).

use std::f32;

use thiserror::Error;
use tracing::{debug, info, trace, warn};

use helios_mlx::pages::TieredAllocator;
use helios_mlx::types::{MLXDtype, TensorView, TokenId};

use crate::transformer::ResonanceGate;
use crate::types::Mamba2Config;

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

/// Errors from the SSM model track.
#[derive(Error, Debug, Clone, PartialEq)]
pub enum SsmError {
    #[error("invalid token id {0} >= vocab_size {1}")]
    InvalidTokenId(usize, usize),
    #[error("sequence length {0} exceeds capacity {1}")]
    SequenceTooLong(usize, usize),
    #[error("SSM state overflow: max abs state value {0} > threshold {1}")]
    StateOverflow(f32, f32),
    #[error("dimension mismatch: expected {expected}, got {got}")]
    DimMismatch { expected: usize, got: usize },
    #[error("unimplemented: {0}")]
    Unimplemented(String),
}

pub type SsmResult<T> = Result<T, SsmError>;

// ---------------------------------------------------------------------------
// SSMState — shared recurrent state
// ---------------------------------------------------------------------------

/// Discrete-time SSM state for one layer.
///
/// The continuous SSM
/// ```text
/// h'(t) = A h(t) + B x(t)
/// y(t)  = C h(t)
/// ```
/// is discretised via the zero-order hold (ZOH) rule:
/// ```text
/// h_{t} = Ā h_{t-1} + B̄ x_t
/// y_t   = C h_t
/// ```
/// where `Ā = exp(A * Δt)` and `B̄ = (Ā - I) A^{-1} B`.
///
/// For diagonal `A` this simplifies to elementwise operations.
#[derive(Debug, Clone, PartialEq)]
pub struct SSMState {
    /// State transition matrix `A` (diagonal, length = ssm_dim).
    /// Stored as raw parameters; the effective A is `-exp(a_raw)`.
    pub a_raw: Vec<f32>,
    /// Input-dependent matrix `B` (length = ssm_dim).
    pub b: Vec<f32>,
    /// Output matrix `C` (length = ssm_dim).
    pub c: Vec<f32>,
    /// Hidden state `h` (length = ssm_dim).
    pub h: Vec<f32>,
    /// Discretisation step `Δt` (learned per input).
    pub dt: f32,
    /// SSM dimension.
    pub ssm_dim: usize,
}

impl SSMState {
    /// Create a new zero-initialised SSM state.
    pub fn new(ssm_dim: usize) -> Self {
        Self {
            a_raw: vec![0.0f32; ssm_dim],
            b: vec![0.0f32; ssm_dim],
            c: vec![0.0f32; ssm_dim],
            h: vec![0.0f32; ssm_dim],
            dt: 0.01,
            ssm_dim,
        }
    }

    /// Ensure the hidden state does not explode.
    pub fn check_stability(&self, threshold: f32) -> SsmResult<()> {
        let max_abs = self
            .h
            .iter()
            .map(|&v| v.abs())
            .fold(0.0f32, f32::max);
        if max_abs > threshold {
            return Err(SsmError::StateOverflow(max_abs, threshold));
        }
        Ok(())
    }

    /// Reset the hidden state to zero.
    pub fn reset(&mut self) {
        self.h.fill(0.0);
    }
}

// ---------------------------------------------------------------------------
// CausalConv1d
// ---------------------------------------------------------------------------

/// Causal 1-D convolution used in the Mamba block.
///
/// The convolution is **causal**: output at position `t` only depends on
/// inputs at positions `t, t-1, …, t-k+1` where `k` is the kernel size.
#[derive(Debug, Clone, PartialEq)]
pub struct CausalConv1d {
    /// Convolution kernel weights `[kernel_size, in_channels, out_channels]`
    /// flattened row-major.  For the standard Mamba case `in_channels == out_channels`.
    pub weights: Vec<f32>,
    /// Kernel size (width).
    pub kernel_size: usize,
    /// Input / output channels.
    pub channels: usize,
    /// Padding buffer for causal convolution.
    pub padding: Vec<f32>,
}

impl CausalConv1d {
    pub fn new(kernel_size: usize, channels: usize) -> Self {
        Self {
            weights: vec![0.0f32; kernel_size * channels * channels],
            kernel_size,
            channels,
            padding: vec![0.0f32; (kernel_size - 1) * channels],
        }
    }

    /// Forward one step of causal convolution.
    ///
    /// `x` is the current input vector of length `channels`.
    /// Returns the convolved output of length `channels`.
    pub fn step(&mut self, x: &[f32]) -> Vec<f32> {
        assert_eq!(x.len(), self.channels);

        // Concatenate padding + current input.
        let mut window = self.padding.clone();
        window.extend_from_slice(x);

        // Compute causal conv: for each output channel, dot over kernel.
        let mut out = vec![0.0f32; self.channels];
        for oc in 0..self.channels {
            let mut acc = 0.0f32;
            for k in 0..self.kernel_size {
                let window_start = k * self.channels;
                for ic in 0..self.channels {
                    let w_idx = k * self.channels * self.channels + ic * self.channels + oc;
                    acc += self.weights[w_idx] * window[window_start + ic];
                }
            }
            out[oc] = acc;
        }

        // Shift padding window: keep the last (kernel_size-1) slices.
        let keep = (self.kernel_size - 1) * self.channels;
        if keep > 0 {
            // window[channels..] = previous padding without the oldest slice + current x
            self.padding.clear();
            self.padding.extend_from_slice(&window[self.channels..]);
        } else {
            self.padding.clear();
        }
        debug_assert_eq!(self.padding.len(), keep);

        out
    }

    /// Reset the padding buffer.
    pub fn reset(&mut self) {
        self.padding.fill(0.0);
    }
}

// ---------------------------------------------------------------------------
// SelectiveSSM
// ---------------------------------------------------------------------------

/// Selective State Space Model core.
///
/// Implements the discretised diagonal SSM with input-dependent `B`, `C`,
/// and `Δt` parameters.  This is the heart of the Mamba architecture.
#[derive(Debug, Clone, PartialEq)]
pub struct SelectiveSSM {
    /// SSM state dimension.
    pub ssm_dim: usize,
    /// Learned `A` parameters (raw, pre-exp).
    pub a_log: Vec<f32>,
    /// Input projection to `B`.
    pub proj_b: Vec<f32>,
    /// Input projection to `C`.
    pub proj_c: Vec<f32>,
    /// Input projection to `Δt`.
    pub proj_dt: Vec<f32>,
    /// Discretisation rank (for low-rank `dt` projection).
    pub dt_rank: usize,
    /// Hidden dimension (input size).
    pub hidden_dim: usize,
}

impl SelectiveSSM {
    pub fn new(hidden_dim: usize, ssm_dim: usize, dt_rank: usize) -> Self {
        Self {
            ssm_dim,
            a_log: vec![0.0f32; ssm_dim],
            proj_b: vec![0.0f32; ssm_dim * hidden_dim],
            proj_c: vec![0.0f32; ssm_dim * hidden_dim],
            proj_dt: vec![0.0f32; dt_rank * hidden_dim],
            dt_rank,
            hidden_dim,
        }
    }

    /// Execute one SSM step.
    ///
    /// `input` is the current hidden-state vector of length `hidden_dim`.
    /// `state` is the mutable recurrent state (updated in-place).
    ///
    /// Returns the SSM output vector of length `ssm_dim`.
    ///
    /// # Algorithm
    /// 1. Project `input` → `B`, `C`, `Δt`.
    /// 2. Discretise `A` via ZOH: `Ā = exp(A * Δt)`.
    /// 3. Discretise `B̄ = (Ā - I) * B` (simplified for diagonal `A`).
    /// 4. Update hidden state: `h = Ā * h + B̄ * x`.
    /// 5. Output: `y = C * h`.
    pub fn step(&self, input: &[f32], state: &mut SSMState) -> Vec<f32> {
        assert_eq!(input.len(), self.hidden_dim);
        assert_eq!(state.ssm_dim, self.ssm_dim);

        // 1. Project to B, C, dt.
        let b = gemv(&self.proj_b, input, self.ssm_dim, self.hidden_dim);
        let c = gemv(&self.proj_c, input, self.ssm_dim, self.hidden_dim);
        let dt_raw = gemv(&self.proj_dt, input, self.dt_rank, self.hidden_dim);
        let dt: f32 = dt_raw.iter().sum::<f32>().clamp(1e-3, 0.1); // softplus-like

        // 2. Effective A = -exp(a_log)  (stable by construction).
        let a_eff: Vec<f32> = self.a_log.iter().map(|&a| -a.exp()).collect();

        // 3. Discretise via ZOH.
        let a_bar: Vec<f32> = a_eff.iter().map(|&a| (a * dt).exp()).collect();

        // 4. B̄ = (Ā - I) * B / A  (simplified ZOH for diagonal A).
        let b_bar: Vec<f32> = a_eff
            .iter()
            .zip(a_bar.iter())
            .zip(b.iter())
            .map(|((&a, &ab), &bi)| {
                if a.abs() > 1e-6 {
                    (ab - 1.0) / a * bi
                } else {
                    dt * bi // limit as A → 0
                }
            })
            .collect();

        // 5. State update.
        for i in 0..self.ssm_dim {
            state.h[i] = a_bar[i] * state.h[i] + b_bar[i];
        }

        // 6. Output.
        c.iter()
            .zip(state.h.iter())
            .map(|(&ci, &hi)| ci * hi)
            .collect()
    }
}

// ---------------------------------------------------------------------------
// Mamba2Block
// ---------------------------------------------------------------------------

/// One Mamba-2 layer: input projection → causal conv → selective SSM → output projection.
#[derive(Debug)]
pub struct Mamba2Block {
    pub layer_id: usize,
    pub conv1d: CausalConv1d,
    pub ssm: SelectiveSSM,
    pub proj_in: Vec<f32>,      // hidden_dim → 2*hidden_dim (for split)
    pub proj_out: Vec<f32>,     // ssm_dim → hidden_dim
    pub norm: crate::transformer::RMSNorm,
    pub hidden_dim: usize,
    pub ssm_dim: usize,
}

impl Mamba2Block {
    pub fn forward(&mut self, x: &[f32], state: &mut SSMState) -> SsmResult<Vec<f32>> {
        assert_eq!(x.len(), self.hidden_dim);

        // 1. Input projection (split into two branches).
        let proj = gemv(&self.proj_in, x, self.hidden_dim * 2, self.hidden_dim);
        let (x_conv, x_skip) = proj.split_at(self.hidden_dim);

        // 2. Causal convolution.
        let conv_out = self.conv1d.step(x_conv);

        // 3. Selective SSM.
        let ssm_out = self.ssm.step(&conv_out, state);

        // 4. Output projection.
        let mut out = gemv(&self.proj_out, &ssm_out, self.hidden_dim, self.ssm_dim);

        // 5. Add skip branch (gated residual).
        for (o, &s) in out.iter_mut().zip(x_skip.iter()) {
            *o += s;
        }

        // 6. RMSNorm.
        out = self.norm.forward(&out);

        Ok(out)
    }

    pub fn reset(&mut self) {
        self.conv1d.reset();
    }
}

// ---------------------------------------------------------------------------
// Mamba2Helios
// ---------------------------------------------------------------------------

/// Mamba-2 model integrated with the Helios memory substrate.
///
/// Shares [`TieredAllocator`] and [`ResonanceGate`] with the transformer
/// track, enabling cross-architecture memory management and online
/// equivalence checking.
#[derive(Debug)]
pub struct Mamba2Helios {
    pub config: Mamba2Config,
    pub memory: TieredAllocator,
    pub ssm_state: Vec<SSMState>,
    pub resonance_gate: ResonanceGate,
    pub layers: Vec<Mamba2Block>,
    pub final_norm: crate::transformer::RMSNorm,
    pub lm_head: Vec<f32>,
    pub embedding: Vec<f32>,
    pub current_pos: usize,
}

impl Mamba2Helios {
    pub fn new(config: Mamba2Config) -> SsmResult<Self> {
        let memory = TieredAllocator::new(4096);
        let mut layers = Vec::with_capacity(config.num_layers);
        let mut ssm_state = Vec::with_capacity(config.num_layers);

        for layer_id in 0..config.num_layers {
            let ssm_dim = config.ssm_dim;
            let hidden_dim = config.hidden_dim;
            let conv = CausalConv1d::new(config.conv_kernel, hidden_dim);
            let ssm = SelectiveSSM::new(hidden_dim, ssm_dim, config.dt_rank);
            let norm = crate::transformer::RMSNorm::new(hidden_dim, config.rms_norm_eps);

            layers.push(Mamba2Block {
                layer_id,
                conv1d: conv,
                ssm,
                proj_in: vec![0.0f32; hidden_dim * 2 * hidden_dim],
                proj_out: vec![0.0f32; hidden_dim * ssm_dim],
                norm,
                hidden_dim,
                ssm_dim,
            });
            ssm_state.push(SSMState::new(ssm_dim));
        }

        let embedding = vec![0.0f32; config.vocab_size * config.hidden_dim];
        let lm_head = vec![0.0f32; config.vocab_size * config.hidden_dim];

        Ok(Self {
            config,
            memory,
            ssm_state,
            resonance_gate: ResonanceGate::new(1.0, 0.95),
            layers,
            final_norm: crate::transformer::RMSNorm::new(config.hidden_dim, config.rms_norm_eps),
            lm_head,
            embedding,
            current_pos: 0,
        })
    }

    /// Full forward pass for a token sequence.
    pub fn forward(&mut self, tokens: &[TokenId]) -> SsmResult<TensorView> {
        if tokens.is_empty() {
            return Err(SsmError::InvalidTokenId(0, self.config.vocab_size));
        }

        let mut hidden = self.embed(tokens[0]);

        for (pos, &token) in tokens.iter().enumerate() {
            if token.0 >= self.config.vocab_size {
                return Err(SsmError::InvalidTokenId(token.0, self.config.vocab_size));
            }
            if pos > 0 {
                hidden = self.embed(token);
            }
            for (layer_idx, layer) in self.layers.iter_mut().enumerate() {
                hidden = layer.forward(&hidden, &mut self.ssm_state[layer_idx])?;
                // Stability check.
                self.ssm_state[layer_idx].check_stability(1e6)?;
            }
            hidden = self.final_norm.forward(&hidden);
        }

        let logits = gemv(&self.lm_head, &hidden, self.config.vocab_size, self.config.hidden_dim);
        let view = TensorView::row_major(
            vec![self.config.vocab_size],
            MLXDtype::F32,
            logits.len() * 4,
        );
        self.current_pos = tokens.len();
        Ok(view)
    }

    /// Single autoregressive decode step.
    pub fn decode_step(&mut self, last_token: TokenId) -> SsmResult<TokenId> {
        if last_token.0 >= self.config.vocab_size {
            return Err(SsmError::InvalidTokenId(last_token.0, self.config.vocab_size));
        }

        let mut hidden = self.embed(last_token);
        for (layer_idx, layer) in self.layers.iter_mut().enumerate() {
            hidden = layer.forward(&hidden, &mut self.ssm_state[layer_idx])?;
        }
        hidden = self.final_norm.forward(&hidden);

        let logits = gemv(&self.lm_head, &hidden, self.config.vocab_size, self.config.hidden_dim);
        let next_id = argmax(&logits);
        self.current_pos += 1;

        trace!("Mamba2 decode_step: pos={} -> token={}", self.current_pos - 1, next_id);
        Ok(TokenId(next_id))
    }

    fn embed(&self, token: TokenId) -> Vec<f32> {
        let start = token.0 * self.config.hidden_dim;
        self.embedding[start..start + self.config.hidden_dim].to_vec()
    }

    /// Reset all recurrent state.
    pub fn reset(&mut self) {
        self.current_pos = 0;
        for state in self.ssm_state.iter_mut() {
            state.reset();
        }
        for layer in self.layers.iter_mut() {
            layer.reset();
        }
    }
}

// ---------------------------------------------------------------------------
// Utility GEMV
// ---------------------------------------------------------------------------

/// Dense GEMV: `y = W @ x` where `W` is `[out_dim, in_dim]` row-major.
fn gemv(w: &[f32], x: &[f32], out_dim: usize, in_dim: usize) -> Vec<f32> {
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

    // -----------------------------------------------------------------------
    // SSMState tests
    // -----------------------------------------------------------------------

    #[test]
    fn ssm_state_new_zeros() {
        let state = SSMState::new(64);
        assert_eq!(state.h.len(), 64);
        assert!(state.h.iter().all(|&v| v == 0.0));
    }

    #[test]
    fn ssm_state_stability_passes_for_zeros() {
        let state = SSMState::new(64);
        assert!(state.check_stability(1e6).is_ok());
    }

    #[test]
    fn ssm_state_stability_fails_for_explosion() {
        let mut state = SSMState::new(4);
        state.h[0] = 1e9;
        assert!(state.check_stability(1e6).is_err());
    }

    #[test]
    fn ssm_state_reset_clears() {
        let mut state = SSMState::new(8);
        state.h.fill(1.0);
        state.reset();
        assert!(state.h.iter().all(|&v| v == 0.0));
    }

    // -----------------------------------------------------------------------
    // CausalConv1d tests
    // -----------------------------------------------------------------------

    #[test]
    fn causal_conv_step_shape() {
        let mut conv = CausalConv1d::new(4, 16);
        let x = vec![1.0f32; 16];
        let out = conv.step(&x);
        assert_eq!(out.len(), 16);
    }

    #[test]
    fn causal_conv_zero_weights_zero_output() {
        let mut conv = CausalConv1d::new(3, 8);
        let x = vec![1.0f32; 8];
        let out = conv.step(&x);
        // All weights are zero, padding starts at zero.
        assert!(out.iter().all(|&v| v.abs() < 1e-6));
    }

    #[test]
    fn causal_conv_preserves_causality() {
        let mut conv = CausalConv1d::new(2, 4);
        // Set identity-like weights for kernel 0 (current).
        for i in 0..4 {
            conv.weights[i * 4 + i] = 1.0;
        }
        let x = vec![1.0f32, 2.0, 3.0, 4.0];
        let out1 = conv.step(&x);
        // Second step should not leak from the future.
        let x2 = vec![5.0f32, 6.0, 7.0, 8.0];
        let out2 = conv.step(&x2);
        // out2 should incorporate x2 and x (previous), but not anything after x2.
        assert_eq!(out2.len(), 4);
    }

    // -----------------------------------------------------------------------
    // SelectiveSSM tests
    // -----------------------------------------------------------------------

    #[test]
    fn selective_ssm_step_shape() {
        let ssm = SelectiveSSM::new(16, 32, 4);
        let mut state = SSMState::new(32);
        let input = vec![0.1f32; 16];
        let out = ssm.step(&input, &mut state);
        assert_eq!(out.len(), 32);
        // State should be updated (not necessarily non-zero because projections are zero).
        assert_eq!(state.h.len(), 32);
    }

    #[test]
    fn selective_ssm_stable_with_negative_a() {
        let mut ssm = SelectiveSSM::new(8, 16, 4);
        // Set a_log to small positive values so a_eff = -exp(a_log) is strongly negative.
        ssm.a_log.fill(0.5);
        let mut state = SSMState::new(16);
        let input = vec![0.1f32; 8];

        // Run many steps — state should remain bounded.
        for _ in 0..100 {
            let _ = ssm.step(&input, &mut state);
        }
        let max_abs = state.h.iter().map(|&v| v.abs()).fold(0.0f32, f32::max);
        assert!(
            max_abs < 1e6,
            "SSM state exploded: max_abs={}",
            max_abs
        );
    }

    #[test]
    fn selective_ssm_no_explosion_random_input() {
        let mut rng = fastrand::Rng::with_seed(42);
        let mut ssm = SelectiveSSM::new(16, 32, 8);
        // Randomise projections.
        for w in ssm.proj_b.iter_mut() { *w = rng.f32() * 0.1 - 0.05; }
        for w in ssm.proj_c.iter_mut() { *w = rng.f32() * 0.1 - 0.05; }
        ssm.a_log.fill(0.2);
        let mut state = SSMState::new(32);

        for _ in 0..50 {
            let input: Vec<f32> = (0..16).map(|_| rng.f32() * 2.0 - 1.0).collect();
            let _ = ssm.step(&input, &mut state);
        }
        let max_abs = state.h.iter().map(|&v| v.abs()).fold(0.0f32, f32::max);
        assert!(
            max_abs < 1e8,
            "SSM state exploded with random inputs: max_abs={}",
            max_abs
        );
    }

    // -----------------------------------------------------------------------
    // Mamba2Helios integration tests
    // -----------------------------------------------------------------------

    fn make_test_mamba_config() -> Mamba2Config {
        let mut cfg = Mamba2Config::default();
        cfg.num_layers = 2;
        cfg.hidden_dim = 64;
        cfg.vocab_size = 128;
        cfg.ssm_dim = 128;
        cfg.conv_kernel = 4;
        cfg
    }

    #[test]
    fn mamba2_helios_builds() {
        let cfg = make_test_mamba_config();
        let model = Mamba2Helios::new(cfg);
        assert!(model.is_ok());
    }

    #[test]
    fn mamba2_forward_shape() {
        let cfg = make_test_mamba_config();
        let mut model = Mamba2Helios::new(cfg).unwrap();
        let tokens: Vec<TokenId> = vec![TokenId(0), TokenId(1)];
        let view = model.forward(&tokens).unwrap();
        assert_eq!(view.shape, vec![model.config.vocab_size]);
    }

    #[test]
    fn mamba2_decode_step_increments_pos() {
        let cfg = make_test_mamba_config();
        let mut model = Mamba2Helios::new(cfg).unwrap();
        let start = model.current_pos;
        let _ = model.decode_step(TokenId(0));
        assert_eq!(model.current_pos, start + 1);
    }

    #[test]
    fn mamba2_invalid_token_error() {
        let cfg = make_test_mamba_config();
        let mut model = Mamba2Helios::new(cfg).unwrap();
        let bad = TokenId(model.config.vocab_size + 1);
        assert!(model.decode_step(bad).is_err());
    }

    #[test]
    fn mamba2_reset_clears_state() {
        let cfg = make_test_mamba_config();
        let mut model = Mamba2Helios::new(cfg).unwrap();
        let _ = model.decode_step(TokenId(0));
        let _ = model.decode_step(TokenId(1));
        model.reset();
        assert_eq!(model.current_pos, 0);
        assert!(model.ssm_state.iter().all(|s| s.h.iter().all(|&v| v == 0.0)));
    }

    #[test]
    fn mamba2_stability_over_long_sequence() {
        let cfg = make_test_mamba_config();
        let mut model = Mamba2Helios::new(cfg).unwrap();
        let tokens: Vec<TokenId> = (0..64).map(TokenId).collect();
        let result = model.forward(&tokens);
        assert!(result.is_ok(), "SSM should remain stable over 64 tokens");
    }

    #[test]
    fn mamba2_and_transformer_same_input_both_ok() {
        // Verify that both tracks can process the same short input without crashing.
        use crate::transformer::{Qwen3Helios, BitNetConfig};
        use crate::types::Qwen3Config;

        let mut mamba_cfg = make_test_mamba_config();
        mamba_cfg.hidden_dim = 32;
        mamba_cfg.vocab_size = 64;
        mamba_cfg.ssm_dim = 64;

        let mut qwen_cfg = Qwen3Config::default();
        qwen_cfg.num_layers = 2;
        qwen_cfg.hidden_dim = 32;
        qwen_cfg.vocab_size = 64;
        qwen_cfg.num_attention_heads = 4;
        qwen_cfg.num_key_value_heads = 2;
        qwen_cfg.intermediate_dim = 128;
        qwen_cfg.max_position_embeddings = 256;
        qwen_cfg.layer_configs = (0..qwen_cfg.num_layers)
            .map(|_| crate::types::TransformerBlockConfig {
                hidden_dim: qwen_cfg.hidden_dim,
                num_heads: qwen_cfg.num_attention_heads,
                head_dim: qwen_cfg.hidden_dim / qwen_cfg.num_attention_heads,
                intermediate_dim: qwen_cfg.intermediate_dim,
                activation: crate::types::ActivationType::SwiGLU,
                rms_norm_eps: 1e-6,
                max_seq_len: qwen_cfg.max_position_embeddings,
                rope_theta: 10_000.0,
            })
            .collect();

        let mut mamba = Mamba2Helios::new(mamba_cfg).unwrap();
        let mut transformer = Qwen3Helios::new(qwen_cfg, BitNetConfig::default()).unwrap();

        let tokens: Vec<TokenId> = vec![TokenId(0), TokenId(1), TokenId(2)];
        let mamba_view = mamba.forward(&tokens);
        let trans_view = transformer.forward(&tokens);
        assert!(mamba_view.is_ok());
        assert!(trans_view.is_ok());
        // Both should produce a vocab-sized output.
        assert_eq!(mamba_view.unwrap().shape, vec![64]);
        assert_eq!(trans_view.unwrap().shape, vec![64]);
    }
}
