//! Shadow attention with sketch-guided page selection.
//!
//! Instead of materialising every KV page for every attention head, we keep a
//! compact *shadow* representation — a [`CountSketch`] per memory page.  At
//! attention time the query vector is hashed into the same sketch space; pages
//! whose sketch correlates highly with the query are promoted to the exact tier
//! and reconstructed via KV-Direct.

use std::collections::HashMap;

use tracing::{debug, trace, warn};

use crate::types::{PageId, TokenId};
use helios_core::CountSketch;

// ---------------------------------------------------------------------------
// PageIndex
// ---------------------------------------------------------------------------

/// Sparse mapping from token positions to page identifiers.
#[derive(Debug, Clone, Default)]
pub struct PageIndex {
    /// Token offset inside the page (0 … page_capacity-1).
    pub token_offset: usize,
    /// Back-reference to the page holding this token.
    pub page_id: PageId,
}

// ---------------------------------------------------------------------------
// ShadowAttention
// ---------------------------------------------------------------------------

/// Shadow attention engine.
///
/// Maintains one [`CountSketch`] per memory page.  Queries are scored against
/// every sketch; the top-k pages are returned for exact reconstruction.
#[derive(Debug, Clone)]
pub struct ShadowAttention {
    /// One sketch per page.
    pub sketch_pool: Vec<CountSketch<1024, 4>>,
    /// Token → page index.
    pub page_index: HashMap<TokenId, PageIndex>,
    /// How many pages to return on each `select_pages` call.
    pub top_k: usize,
}

impl Default for ShadowAttention {
    fn default() -> Self {
        Self {
            sketch_pool: Vec::new(),
            page_index: HashMap::new(),
            top_k: 4,
        }
    }
}

impl ShadowAttention {
    /// Create a new shadow engine with room for `num_pages` sketches.
    pub fn with_capacity(num_pages: usize, top_k: usize) -> Self {
        Self {
            sketch_pool: (0..num_pages)
                .map(|_| CountSketch::<1024, 4>::default())
                .collect(),
            page_index: HashMap::with_capacity(num_pages * 64),
            top_k,
        }
    }

    /// Select the most relevant pages for a query vector.
    ///
    /// `query` must be a `f32` feature vector.  It is hashed into each page's
    /// sketch; pages are ranked by estimated dot-product similarity.
    ///
    /// # Returns
    /// Up to `self.top_k` [`PageId`]s in descending relevance order.
    pub fn select_pages(&self, query: &[f32]) -> Vec<PageId> {
        if self.sketch_pool.is_empty() {
            return Vec::new();
        }
        let mut scored: Vec<(PageId, f32)> = self
            .sketch_pool
            .iter()
            .enumerate()
            .map(|(pid, sketch)| {
                let score = shadow_score(query, sketch);
                (PageId(pid), score)
            })
            .collect();
        scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
        scored.truncate(self.top_k);
        trace!("ShadowAttention selected {} pages", scored.len());
        scored.into_iter().map(|(pid, _)| pid).collect()
    }

    /// Incrementally update the sketch for `page` with new tokens.
    ///
    /// Each token is represented by a feature vector (e.g. the residual
    /// embedding at that position).  The sketch is updated in-place.
    pub fn update_sketch(&mut self, page: PageId, new_tokens: &[TokenId], features: &[Vec<f32>]) {
        let pid = page.0;
        if pid >= self.sketch_pool.len() {
            warn!(
                "page {} out of sketch_pool range (len={})",
                pid,
                self.sketch_pool.len()
            );
            return;
        }
        assert_eq!(
            new_tokens.len(),
            features.len(),
            "token/feature count mismatch"
        );
        for (tid, feat) in new_tokens.iter().zip(features.iter()) {
            self.sketch_pool[pid].update_vector(feat);
            self.page_index.insert(
                *tid,
                PageIndex {
                    token_offset: self.page_index.len(), // simplified
                    page_id: page,
                },
            );
        }
        debug!("Updated sketch for page {} with {} tokens", pid, new_tokens.len());
    }

    /// Reset a single page's sketch (e.g. after eviction).
    pub fn reset_page(&mut self, page: PageId) {
        let pid = page.0;
        if pid < self.sketch_pool.len() {
            self.sketch_pool[pid].clear();
            // Remove tokens that map to this page from page_index.
            self.page_index
                .retain(|_, idx| idx.page_id.0 != pid);
        }
    }

    /// Resize the sketch pool (add empty sketches or truncate).
    pub fn resize_pool(&mut self, new_len: usize) {
        let old_len = self.sketch_pool.len();
        if new_len > old_len {
            self.sketch_pool
                .extend((old_len..new_len).map(|_| CountSketch::<1024, 4>::default()));
        } else {
            self.sketch_pool.truncate(new_len);
            self.page_index
                .retain(|_, idx| idx.page_id.0 < new_len);
        }
    }

    /// Number of pages currently tracked.
    pub fn num_pages(&self) -> usize {
        self.sketch_pool.len()
    }
}

// ---------------------------------------------------------------------------
// shadow_score
// ---------------------------------------------------------------------------

/// Compute the dot-product similarity between a query and a sketch.
///
/// The query is hashed with the same seeds as the sketch; the result is an
/// unbiased estimator of `query · page_vector`.
///
/// # Panics
/// Panics if `query.len() > 1024` (the sketch width is fixed at compile time).
pub fn shadow_score(query: &[f32], sketch: &CountSketch<1024, 4>) -> f32 {
    assert!(
        query.len() <= 1024,
        "query length {} exceeds sketch width 1024",
        query.len()
    );
    sketch.estimate_dot(query)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn select_pages_basic() {
        let mut shadow = ShadowAttention::with_capacity(8, 3);
        // Page 0 gets feature [1,0,0,...]
        shadow.update_sketch(PageId(0), &[TokenId(0)], &[vec![1.0f32, 0.0, 0.0, 0.0]]);
        // Page 1 gets feature [0,1,0,...]
        shadow.update_sketch(PageId(1), &[TokenId(1)], &[vec![0.0f32, 1.0, 0.0, 0.0]]);
        // Query aligned with page 0.
        let query = vec![1.0f32, 0.0, 0.0, 0.0];
        let selected = shadow.select_pages(&query);
        assert_eq!(selected.len(), 3);
        assert_eq!(selected[0], PageId(0));
    }

    #[test]
    fn select_pages_orthogonal() {
        let mut shadow = ShadowAttention::with_capacity(4, 2);
        let f0 = vec![1.0f32, 0.0, 0.0, 0.0];
        let f1 = vec![0.0f32, 1.0, 0.0, 0.0];
        shadow.update_sketch(PageId(0), &[TokenId(0)], &[f0.clone()]);
        shadow.update_sketch(PageId(1), &[TokenId(1)], &[f1.clone()]);
        let selected = shadow.select_pages(&f0);
        assert_eq!(selected[0], PageId(0));
        let selected = shadow.select_pages(&f1);
        assert_eq!(selected[0], PageId(1));
    }

    #[test]
    fn sketch_update_accumulates() {
        let mut shadow = ShadowAttention::with_capacity(1, 1);
        let mut feat = vec![0.0f32; 1024];
        feat[0] = 1.0;
        shadow.update_sketch(PageId(0), &[TokenId(0)], &[feat.clone()]);
        let score_before = shadow_score(&feat, &shadow.sketch_pool[0]);
        // Update again with the same feature.
        shadow.update_sketch(PageId(0), &[TokenId(1)], &[feat.clone()]);
        let score_after = shadow_score(&feat, &shadow.sketch_pool[0]);
        assert!(
            score_after > score_before,
            "sketch should accumulate: before={}, after={}",
            score_before,
            score_after
        );
    }

    #[test]
    fn reset_page_clears_sketch() {
        let mut shadow = ShadowAttention::with_capacity(2, 2);
        let feat = vec![1.0f32; 4];
        shadow.update_sketch(PageId(0), &[TokenId(0)], &[feat.clone()]);
        assert!(shadow_score(&feat, &shadow.sketch_pool[0]) > 0.0);
        shadow.reset_page(PageId(0));
        assert_eq!(shadow_score(&feat, &shadow.sketch_pool[0]), 0.0);
    }

    #[test]
    fn resize_pool_grows_and_shrinks() {
        let mut shadow = ShadowAttention::with_capacity(4, 2);
        assert_eq!(shadow.num_pages(), 4);
        shadow.resize_pool(8);
        assert_eq!(shadow.num_pages(), 8);
        shadow.resize_pool(2);
        assert_eq!(shadow.num_pages(), 2);
        // page_index should be cleaned up after shrink.
        assert!(shadow.page_index.values().all(|idx| idx.page_id.0 < 2));
    }

    #[test]
    fn page_index_maps_tokens() {
        let mut shadow = ShadowAttention::with_capacity(2, 2);
        let feat = vec![1.0f32; 4];
        shadow.update_sketch(PageId(1), &[TokenId(42)], &[feat]);
        let idx = shadow.page_index.get(&TokenId(42)).unwrap();
        assert_eq!(idx.page_id, PageId(1));
    }
}
