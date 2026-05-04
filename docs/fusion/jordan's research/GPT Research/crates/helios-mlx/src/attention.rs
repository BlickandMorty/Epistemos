//! Shadow-first attention routing with deterministic CPU fallback.

use helios_core::TierState;

/// Page metadata exposed by L2/L3 routing.
#[derive(Clone, Debug, PartialEq)]
pub struct PageOracle {
    pub page_vectors: Vec<Vec<f32>>,
    pub page_tiers: Vec<TierState>,
}

/// Output of the shadow-first selector.
#[derive(Clone, Debug, PartialEq)]
pub struct AttentionOutput {
    pub selected_pages: Vec<usize>,
    pub scores: Vec<f32>,
    pub escalations: Vec<TierState>,
}

/// Shadow-first attention policy.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ShadowFirstAttention {
    pub top_k: usize,
    pub residual_threshold: f32,
    pub exact_threshold: f32,
}

impl Default for ShadowFirstAttention {
    fn default() -> Self {
        Self { top_k: 64, residual_threshold: 0.05, exact_threshold: 0.20 }
    }
}

impl ShadowFirstAttention {
    /// Score pages with dot products and select top-k. Uncertainty maps to tier escalation.
    #[must_use]
    pub fn shadow_attention(self, query: &[f32], pages: &PageOracle) -> AttentionOutput {
        let mut pairs: Vec<(usize, f32)> = pages
            .page_vectors
            .iter()
            .enumerate()
            .map(|(idx, page)| (idx, dot(query, page)))
            .collect();
        pairs.sort_by(|a, b| b.1.total_cmp(&a.1));
        pairs.truncate(self.top_k.min(pairs.len()));
        let max = pairs.first().map_or(1.0, |(_, score)| score.abs().max(1.0));
        let mut selected_pages = Vec::new();
        let mut scores = Vec::new();
        let mut escalations = Vec::new();
        for (idx, score) in pairs {
            let uncertainty = 1.0 - (score.abs() / max).clamp(0.0, 1.0);
            let tier = if uncertainty < self.residual_threshold {
                TierState::Shadow
            } else if uncertainty < self.exact_threshold {
                TierState::Residual
            } else {
                TierState::Hot
            };
            selected_pages.push(idx);
            scores.push(score);
            escalations.push(tier);
        }
        AttentionOutput { selected_pages, scores, escalations }
    }
}

fn dot(a: &[f32], b: &[f32]) -> f32 {
    assert_eq!(a.len(), b.len(), "attention vector dimension mismatch");
    a.iter().zip(b.iter()).map(|(x, y)| x * y).sum()
}

#[cfg(test)]
mod tests {
    use super::{PageOracle, ShadowFirstAttention};
    use helios_core::TierState;

    #[test]
    fn selects_best_page() {
        let pages = PageOracle { page_vectors: vec![vec![1.0, 0.0], vec![0.0, 3.0]], page_tiers: vec![TierState::Shadow; 2] };
        let out = ShadowFirstAttention { top_k: 1, ..ShadowFirstAttention::default() }.shadow_attention(&[0.0, 1.0], &pages);
        assert_eq!(out.selected_pages, vec![1]);
    }
}
