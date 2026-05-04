//! Attention with KV-Direct reconstruction and shadow-first routing.
//!
//! [`HeliosAttention`] is the top-level attention module.  It orchestrates:
//!
//! 1. **Shadow-first page selection** — `ShadowAttention` sketches select the
//!    top-k pages likely to be relevant.
//! 2. **KV-Direct reconstruction** — for each selected page, K/V tensors are
//!    reconstructed on-demand from the nearest residual checkpoint.
//! 3. **Attention computation** — a software fallback dot-product attention.
//!    (Production dispatches to MLX `fast_attention`.)
//! 4. **Tier confidence routing** — if shadow confidence is below a threshold,
//!    the query is routed to the exact L0 tier.

use thiserror::Error;
use tracing::{debug, info, trace, warn};

use crate::kv_direct::{KVDirect, KVDirectError};
use crate::pages::{MemoryTier, TieredAllocator};
use crate::shadow::ShadowAttention;
use crate::types::{LayerId, MLXDtype, PageId, TensorView, TokenId};

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

/// Errors from the attention engine.
#[derive(Error, Debug, Clone, PartialEq)]
pub enum AttentionError {
    #[error("KV-Direct error: {0}")]
    KVDirect(#[from] KVDirectError),
    #[error("page not found: {0:?}")]
    PageNotFound(PageId),
    #[error("token not in any page: {0:?}")]
    TokenNotFound(TokenId),
    #[error("shape mismatch in attention: {expected:?} vs {got:?}")]
    ShapeMismatch { expected: Vec<usize>, got: Vec<usize> },
    #[error("tier routing failed: confidence {confidence} below threshold {threshold}")]
    TierRoutingFailed { confidence: f32, threshold: f32 },
    #[error("unimplemented: {0}")]
    Unimplemented(String),
}

pub type AttentionResult<T> = Result<T, AttentionError>;

// ---------------------------------------------------------------------------
// HeliosAttention
// ---------------------------------------------------------------------------

/// Top-level attention module.
///
/// Owns the KV-Direct engine, the shadow sketch pool, and the tiered allocator.
/// All mutable state lives here; the module is *not* `Clone` because it holds
/// the allocator and sketch pools.
#[derive(Debug)]
pub struct HeliosAttention {
    /// KV-Direct residual reconstruction engine.
    pub kv_direct: KVDirect,
    /// Shadow-sketch page selector.
    pub shadow: ShadowAttention,
    /// 6-tier memory allocator.
    pub tiered_alloc: TieredAllocator,
    /// Confidence threshold for exact L0 routing (0.0 … 1.0).
    pub confidence_threshold: f32,
    /// Query dimension (used for attention scaling).
    pub head_dim: usize,
    /// Number of attention heads.
    pub num_heads: usize,
    /// Attention softmax temperature.
    pub temperature: f32,
    /// Scratch buffer for intermediate attention scores (re-used per call).
    score_scratch: Vec<f32>,
}

impl HeliosAttention {
    /// Create a new attention module.
    pub fn new(
        kv_direct: KVDirect,
        shadow: ShadowAttention,
        tiered_alloc: TieredAllocator,
        confidence_threshold: f32,
        head_dim: usize,
        num_heads: usize,
    ) -> Self {
        Self {
            kv_direct,
            shadow,
            tiered_alloc,
            confidence_threshold,
            head_dim,
            num_heads,
            temperature: (head_dim as f32).sqrt(),
            score_scratch: Vec::new(),
        }
    }

    /// Forward pass for a single `(query, layer, token)` triplet.
    ///
    /// # Pipeline
    /// 1. Shadow sketch → select top-k pages.
    /// 2. For each selected page: reconstruct KV via KVDirect.
    /// 3. Compute dot-product attention over reconstructed KV.
    /// 4. If max confidence < threshold, fall back to exact L0 scan.
    ///
    /// # Returns
    /// Output tensor of shape `[num_heads, head_dim]`.
    pub fn forward(
        &mut self,
        query: &TensorView,
        layer: LayerId,
        token: TokenId,
    ) -> AttentionResult<TensorView> {
        trace!(
            "forward: layer={} token={} query_shape={:?}",
            layer.0, token.0, query.shape
        );

        // 1. Shadow-first page selection.
        // The query needs to be a f32 feature vector.  In the real MLX path
        // this would be a Metal buffer read; here we use a synthetic feature
        // derived from the query shape for routing.
        let query_feature = self.extract_query_feature(query);
        let selected_pages = self.shadow.select_pages(&query_feature);

        // 2. Reconstruct KV for selected pages and compute attention.
        let mut max_confidence = 0.0f32;
        let mut output: Option<Vec<f32>> = None;

        for page_id in &selected_pages {
            // Track page access.
            if let Some(page) = self.tiered_alloc.find_page_mut(*page_id) {
                self.tiered_alloc.touch_page(page);
            }

            // Reconstruct K/V for the token within this page.
            let (k_view, v_view) = self.kv_direct.reconstruct_kv(layer, token)?;

            // Compute confidence from sketch alignment.
            let page_sketch = self
                .shadow
                .sketch_pool
                .get(page_id.0)
                .ok_or_else(|| AttentionError::PageNotFound(*page_id))?;
            let conf = crate::shadow::shadow_score(&query_feature, page_sketch);
            max_confidence = max_confidence.max(conf);

            // Soft attention over this page's K/V.
            let page_out = self.compute_attention_scores(query, &k_view, &v_view)?;
            match &mut output {
                None => output = Some(page_out),
                Some(acc) => {
                    for (a, b) in acc.iter_mut().zip(page_out.iter()) {
                        *a += b;
                    }
                }
            }
        }

        // 3. Exact L0 fallback if confidence is too low.
        if max_confidence < self.confidence_threshold || output.is_none() {
            debug!(
                "forward: exact L0 fallback for layer={} token={} (conf={:.4} < thresh={:.4})",
                layer.0, token.0, max_confidence, self.confidence_threshold
            );
            let exact_out = self.exact_l0_attention(query, layer, token)?;
            output = Some(exact_out);
        }

        let out_vec = output.unwrap_or_else(|| vec![0.0f32; self.num_heads * self.head_dim]);
        let out_view = TensorView::row_major(
            vec![self.num_heads, self.head_dim],
            MLXDtype::F32,
            out_vec.len() * 4,
        );

        debug!(
            "forward OK: layer={} token={} -> shape={:?}",
            layer.0, token.0, out_view.shape
        );
        Ok(out_view)
    }

    /// Prefill a sequence of tokens with exact KV, then build checkpoints.
    ///
    /// During prefill every token is materialised at L0 exact precision.
    /// After the sequence is complete, sparse checkpoints are extracted and
    /// the shadow sketches are initialised.
    ///
    /// # Returns
    /// The final hidden-state tensor after the last token.
    pub fn prefill(&mut self, tokens: &[TokenId]) -> AttentionResult<TensorView> {
        info!("prefill: {} tokens", tokens.len());
        if tokens.is_empty() {
            return Ok(TensorView::row_major(
                vec![self.num_heads, self.head_dim],
                MLXDtype::F32,
                0,
            ));
        }

        // Exact KV materialisation for every token.
        for (pos, &token) in tokens.iter().enumerate() {
            // In a real implementation this would run the full transformer
            // forward pass and accumulate K/V into the page buffers.
            let page_id = self.token_to_page(token);
            if let Some(page) = self.tiered_alloc.find_page_mut(page_id) {
                page.tokens.push(token);
                self.tiered_alloc.touch_page(page);
            }
        }

        // Build sparse residual checkpoints.
        let interval = self.kv_direct.checkpoint_interval;
        for (pos, &token) in tokens.iter().enumerate() {
            if pos % interval == 0 {
                // Create a checkpoint at this position.
                let residual = TensorView::row_major(
                    vec![self.kv_direct.hidden_dim],
                    MLXDtype::F32,
                    self.kv_direct.hidden_dim * 4,
                );
                self.kv_direct.residual_checkpoints.push(
                    crate::kv_direct::Checkpoint {
                        token_index: token,
                        residual_state: residual,
                    },
                );
            }
        }

        // Initialise shadow sketches from the exact KV.
        let num_pages = self.tiered_alloc.l0_pages.len().max(1);
        self.shadow.resize_pool(num_pages);
        for (pid, page) in self.tiered_alloc.l0_pages.iter().enumerate() {
            if page.tokens.is_empty() {
                continue;
            }
            let features: Vec<Vec<f32>> = page
                .tokens
                .iter()
                .map(|_| vec![1.0f32; 64]) // placeholder feature vector
                .collect();
            self.shadow.update_sketch(
                PageId(pid),
                &page.tokens,
                &features,
            );
        }

        // Return a dummy output for the last token.
        let out = TensorView::row_major(
            vec![self.num_heads, self.head_dim],
            MLXDtype::F32,
            self.num_heads * self.head_dim * 4,
        );
        info!("prefill complete: {} checkpoints", self.kv_direct.residual_checkpoints.len());
        Ok(out)
    }

    /// Exact L0 attention: scan every hot page and compute full attention.
    fn exact_l0_attention(
        &mut self,
        query: &TensorView,
        layer: LayerId,
        _token: TokenId,
    ) -> AttentionResult<Vec<f32>> {
        let mut acc = vec![0.0f32; self.num_heads * self.head_dim];
        let hot_pages: Vec<PageId> = self
            .tiered_alloc
            .l0_pages
            .iter()
            .filter(|p| p.tier == MemoryTier::L0ExactHot)
            .map(|p| p.id)
            .collect();

        for page_id in hot_pages {
            let (k_view, v_view) = self.kv_direct.reconstruct_kv(layer, _token)?;
            let out = self.compute_attention_scores(query, &k_view, &v_view)?;
            for (a, b) in acc.iter_mut().zip(out.iter()) {
                *a += b;
            }
        }
        Ok(acc)
    }

    /// Software attention over a single K/V pair.
    ///
    /// TODO: dispatch to MLX `fast_attention` when `mlx-rs` bindings are ready.
    fn compute_attention_scores(
        &mut self,
        query: &TensorView,
        key: &TensorView,
        value: &TensorView,
    ) -> AttentionResult<Vec<f32>> {
        // Validate shapes.
        if query.shape.len() < 2 || key.shape.len() < 2 || value.shape.len() < 2 {
            return Err(AttentionError::ShapeMismatch {
                expected: vec![self.num_heads, self.head_dim],
                got: query.shape.clone(),
            });
        }
        let heads = query.shape[query.shape.len() - 2];
        let q_dim = query.shape[query.shape.len() - 1];
        let k_dim = key.shape[key.shape.len() - 1];
        let v_dim = value.shape[value.shape.len() - 1];
        if q_dim != k_dim || k_dim != v_dim {
            return Err(AttentionError::ShapeMismatch {
                expected: vec![heads, q_dim],
                got: vec![heads, k_dim],
            });
        }

        // Simplified: for each head compute Q·K^T, softmax, then ·V.
        // In the stub we return a zero vector of the correct shape.
        let out_len = heads * v_dim;
        self.score_scratch.resize(out_len, 0.0f32);
        self.score_scratch.fill(0.0);

        // TODO: replace with real MLX attention kernel.
        trace!(
            "compute_attention_scores stub: heads={}, dim={}",
            heads, q_dim
        );
        Ok(self.score_scratch.clone())
    }

    /// Map a token to its resident page (naive round-robin for the stub).
    fn token_to_page(&self, token: TokenId) -> PageId {
        let n = self.tiered_alloc.l0_pages.len().max(1);
        PageId(token.0 % n)
    }

    /// Derive a f32 feature vector from a query TensorView for sketch hashing.
    ///
    /// In the real system this would read the actual query vector from the MLX
    /// buffer.  Here we hash the shape/dtype metadata into a small feature vec.
    fn extract_query_feature(&self, query: &TensorView) -> Vec<f32> {
        let mut feat = vec![0.0f32; 64];
        // Use shape[0] and shape[1] as seeds.
        let seed0 = query.shape.first().copied().unwrap_or(0) as f32;
        let seed1 = query.shape.get(1).copied().unwrap_or(0) as f32;
        for (i, v) in feat.iter_mut().enumerate() {
            *v = (seed0 * (i + 1) as f32 + seed1).sin() * 0.1;
        }
        feat
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::kv_direct::{KVDirectBuilder, KVProjection, ProjectionMatrix};
    use crate::types::{AttentionHead, LayerId};

    fn make_test_attention() -> HeliosAttention {
        let hidden = 64usize;
        let heads = 4usize;
        let head_dim = hidden / heads;
        let layers = 2usize;

        let kv = KVDirectBuilder::new()
            .hidden_dim(hidden)
            .head_dim(head_dim)
            .num_heads(heads)
            .checkpoint_interval(8)
            .add_layer(KVProjection {
                layer: LayerId(0),
                k_proj: ProjectionMatrix::new(hidden, hidden, vec![0.0f32; hidden * hidden]).unwrap(),
                v_proj: ProjectionMatrix::new(hidden, hidden, vec![0.0f32; hidden * hidden]).unwrap(),
                k_bias: None,
                v_bias: None,
            })
            .add_layer(KVProjection {
                layer: LayerId(1),
                k_proj: ProjectionMatrix::new(hidden, hidden, vec![0.0f32; hidden * hidden]).unwrap(),
                v_proj: ProjectionMatrix::new(hidden, hidden, vec![0.0f32; hidden * hidden]).unwrap(),
                k_bias: None,
                v_bias: None,
            })
            .build()
            .unwrap();

        let shadow = ShadowAttention::with_capacity(4, 2);
        let alloc = TieredAllocator::new(4096);

        HeliosAttention::new(kv, shadow, alloc, 0.5, head_dim, heads)
    }

    #[test]
    fn attention_output_shape() {
        let mut attn = make_test_attention();
        let query = TensorView::row_major(vec![4, 16], MLXDtype::F32, 256);
        let out = attn.forward(&query, LayerId(0), TokenId(0)).unwrap();
        assert_eq!(out.shape, vec![4, 16]);
    }

    #[test]
    fn prefill_creates_checkpoints() {
        let mut attn = make_test_attention();
        let tokens: Vec<TokenId> = (0..24).map(TokenId).collect();
        let out = attn.prefill(&tokens).unwrap();
        assert_eq!(out.shape, vec![4, 16]);
        // 24 tokens / interval 8 => checkpoints at 0, 8, 16 => 3 checkpoints
        // Plus maybe one at 24 if inclusive, but our loop uses %.
        assert_eq!(attn.kv_direct.residual_checkpoints.len(), 3);
    }

    #[test]
    fn tier_routing_fallback_when_low_confidence() {
        let mut attn = make_test_attention();
        attn.confidence_threshold = 0.9; // very high -> always fallback

        // Prefill some tokens so pages exist.
        let tokens: Vec<TokenId> = (0..8).map(TokenId).collect();
        attn.prefill(&tokens).unwrap();

        let query = TensorView::row_major(vec![4, 16], MLXDtype::F32, 256);
        let out = attn.forward(&query, LayerId(0), TokenId(3)).unwrap();
        assert_eq!(out.shape, vec![4, 16]);
    }

    #[test]
    fn empty_prefill_returns_zero_shape() {
        let mut attn = make_test_attention();
        let out = attn.prefill(&[]).unwrap();
        assert_eq!(out.shape, vec![4, 16]);
    }

    #[test]
    fn token_to_page_round_robin() {
        let mut attn = make_test_attention();
        // Grow allocator so we have pages.
        let _ = attn.tiered_alloc.allocate_pages(&crate::pages::PageAllocationRequest {
            token_count: 16,
            layer_count: 2,
            tier_preference: MemoryTier::L0ExactHot,
            head_dim: 16,
            num_heads: 4,
            dtype_bytes: 4,
        }).unwrap();
        assert_eq!(attn.token_to_page(TokenId(0)).0, 0);
        assert_eq!(attn.token_to_page(TokenId(3)).0, 3 % attn.tiered_alloc.l0_pages.len());
    }

    #[test]
    fn attention_shape_mismatch_error() {
        let mut attn = make_test_attention();
        let query = TensorView::row_major(vec![4, 16], MLXDtype::F32, 256);
        let key = TensorView::row_major(vec![4, 8], MLXDtype::F32, 128); // mismatch
        let value = TensorView::row_major(vec![4, 16], MLXDtype::F32, 256);
        let err = attn.compute_attention_scores(&query, &key, &value);
        assert!(err.is_err());
    }
}
