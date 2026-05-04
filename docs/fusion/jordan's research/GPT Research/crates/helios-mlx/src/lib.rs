//! MLX bridge scaffold. CPU fallbacks are real; MLX dispatch is a platform integration target.

pub mod attention;
pub mod kernels;
pub mod tensors;

pub use attention::{AttentionOutput, PageOracle, ShadowFirstAttention};
pub use tensors::{TensorView, TensorViewError};
