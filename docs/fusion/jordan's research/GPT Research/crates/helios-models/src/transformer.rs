//! Qwen3-style Transformer harness scaffold.

use helios_mlx::PageOracle;

pub type Token = u32;
pub type Logits = Vec<f32>;

#[derive(Clone, Debug, PartialEq)]
pub struct Qwen3Helios {
    pub hidden_size: usize,
    pub ttt_layers_enabled: bool,
}

impl Default for Qwen3Helios {
    fn default() -> Self { Self { hidden_size: 4096, ttt_layers_enabled: true } }
}

impl Qwen3Helios {
    pub fn forward(&self, input: &[Token], _pages: &PageOracle) -> Result<Logits, ModelError> {
        if input.is_empty() { return Err(ModelError::EmptyInput); }
        Ok(vec![0.0; 32])
    }

    pub fn ttt_update(&mut self, hidden_state: &[f32], _token: Token) -> Result<(), ModelError> {
        if hidden_state.len() != self.hidden_size { return Err(ModelError::HiddenSizeMismatch); }
        Ok(())
    }

    #[must_use]
    pub fn apply_fast_weights(&self, hidden: &[f32], _session_id: u64) -> Vec<f32> { hidden.to_vec() }

    #[must_use]
    pub fn apply_lora(&self, hidden: &[f32], _domain_id: u64) -> Vec<f32> { hidden.to_vec() }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ModelError {
    EmptyInput,
    HiddenSizeMismatch,
}
