//! Mamba-2 / RWKV-style SSM harness scaffold.

use crate::transformer::{Logits, ModelError, Token};

#[derive(Clone, Debug, PartialEq)]
pub struct Mamba2Helios {
    pub state_size: usize,
    pub shadow_first: bool,
}

impl Default for Mamba2Helios {
    fn default() -> Self { Self { state_size: 4096, shadow_first: true } }
}

impl Mamba2Helios {
    pub fn forward(&self, input: &[Token]) -> Result<Logits, ModelError> {
        if input.is_empty() { return Err(ModelError::EmptyInput); }
        Ok(vec![0.0; 32])
    }
}
