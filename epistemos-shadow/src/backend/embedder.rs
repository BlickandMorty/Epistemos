//! W8.4.b stub — Model2Vec encoder wrapper.
//!
//! Filled in by the W8.4.b commit. The shape:
//!
//!   pub struct Embedder { model: model2vec_rs::model::StaticModel }
//!
//!   impl Embedder {
//!       pub fn global() -> &'static Embedder;
//!       pub fn encode_paragraphs(&self, texts: &[String]) -> Vec<Vec<f32>>;
//!       pub fn encode_one(&self, text: &str) -> Vec<f32>;
//!   }
//!
//!   pub const EMBED_DIM: usize = 256;  // verified by encode-shape test
//!
//! Day-1 spike (commit 7c867f55) confirmed minishlab/potion-base-8M
//! encodes at p99 = 286-607µs on M-series, 8× under the 5ms budget.
//! HuggingFace auto-download triggers the first time `Embedder::global()`
//! is called — Swift bootstrap should fire `shadow_warm()` at app
//! start to pay that cost off the hot path.

#![allow(dead_code)]

/// Placeholder constant — overwritten in W8.4.b once a real
/// `model2vec_rs::model::StaticModel::encode` call confirms the
/// dimension. potion-base-8M ships at 256-d but the constant should
/// be derived, not assumed.
pub const EMBED_DIM_PLACEHOLDER: usize = 256;
