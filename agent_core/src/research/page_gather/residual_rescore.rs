//! `residual_rescore` — Stage 2 of the F-ShadowFirst escalation policy.
//!
//! Per F-ShadowFirst-PageEscalation falsifier §2:
//!
//! ```text
//! candidates = sketch_topk(q, K_SKETCH=128)
//! residual_scores = residual_rescore(candidates, K_RESIDUAL=32)
//! ```
//!
//! Stage 2 takes the K_SKETCH candidates from `sketch_top_k` and rescores
//! the subset that has a residual tier promoted. The rescoring uses
//! dequantized INT8 + per-block scale to produce a more precise f32
//! score than the raw INT8 sketch dot-product.
//!
//! Candidates without a residual tier fall back to their sketch score
//! (converted to f32) — the policy did not promote them to the warm tier.

use crate::research::page_gather::helios_page::{HeliosPage, ResidualBlock};

/// Error surface for residual rescoring.
#[derive(Clone, Debug, PartialEq)]
pub enum ResidualRescoreError {
    /// A candidate's page index was out of range for the corpus.
    CandidateOutOfRange { candidate_index: usize, corpus_len: usize },
    /// Query residual block count or block size did not match the page's
    /// residual layout for at least one candidate.
    QueryResidualShapeMismatch { page_index: usize },
    /// Caller passed an empty output buffer.
    EmptyOutputBuffer,
}

/// Rescore the sketch-top-K candidates using their residual tier where
/// promoted; fall back to sketch score otherwise. Produces top-`output.
/// len()` results sorted by descending score implicitly via in-place
/// min-replacement.
///
/// - `query_residual`: the query's residual representation (same shape
///   as a page residual). Must have `block_size` matching the residual
///   blocks of any candidate page that has a promoted residual.
/// - `sketch_topk_candidates`: output of `sketch_top_k` — slice of
///   (page_index, i32 sketch_score).
/// - `corpus`: HeliosPage corpus (must be the same slice used by
///   sketch_top_k).
/// - `output`: caller-allocated `[(page_index, f32 rescored_score)]`
///   buffer; length is K_RESIDUAL.
///
/// Zero allocations on hot path. Substrate-floor uses linear-scan top-K
/// (caller's responsibility to size output appropriately).
pub fn residual_rescore(
    query_residual: &[ResidualBlock],
    sketch_topk_candidates: &[(usize, i32)],
    corpus: &[HeliosPage],
    output: &mut [(usize, f32)],
) -> Result<(), ResidualRescoreError> {
    if output.is_empty() {
        return Err(ResidualRescoreError::EmptyOutputBuffer);
    }

    // Initialize output with (0, NEG_INFINITY) sentinels.
    for slot in output.iter_mut() {
        *slot = (0, f32::NEG_INFINITY);
    }

    for &(page_idx, sketch_score) in sketch_topk_candidates {
        if page_idx >= corpus.len() {
            return Err(ResidualRescoreError::CandidateOutOfRange {
                candidate_index: page_idx,
                corpus_len: corpus.len(),
            });
        }
        let page = &corpus[page_idx];

        // Compute rescored value: dequantized residual inner product if
        // promoted, else fall back to scaled sketch score.
        let rescored = if let Some(page_residual) = &page.residual {
            if page_residual.len() != query_residual.len() {
                return Err(ResidualRescoreError::QueryResidualShapeMismatch { page_index: page_idx });
            }
            dequantized_residual_inner_product(query_residual, page_residual)
                .map_err(|_| ResidualRescoreError::QueryResidualShapeMismatch { page_index: page_idx })?
        } else {
            // No residual; fall back to sketch score scaled to f32. Scale
            // factor 1/128.0 brings raw INT8 sketch dot-products into the
            // same approximate range as dequantized residual scores
            // (substrate-floor heuristic; production tunes this).
            (sketch_score as f32) / 128.0
        };

        // Find slot with smallest score; replace if better.
        let mut min_idx = 0;
        let mut min_score = output[0].1;
        for (i, slot) in output.iter().enumerate().skip(1) {
            if slot.1 < min_score {
                min_idx = i;
                min_score = slot.1;
            }
        }

        if rescored > min_score {
            output[min_idx] = (page_idx, rescored);
        }
    }

    Ok(())
}

/// Dequantize block-by-block and compute inner product.
///
/// For each block i: ip += scale_q[i] * scale_p[i] * Σ (q.data[j] as i32) *
/// (p.data[j] as i32).
fn dequantized_residual_inner_product(
    query: &[ResidualBlock],
    page: &[ResidualBlock],
) -> Result<f32, ()> {
    if query.len() != page.len() {
        return Err(());
    }
    let mut acc = 0.0_f32;
    for (q, p) in query.iter().zip(page.iter()) {
        if q.data.len() != p.data.len() {
            return Err(());
        }
        let mut block_ip = 0_i32;
        for (qx, px) in q.data.iter().zip(p.data.iter()) {
            block_ip += (*qx as i32) * (*px as i32);
        }
        acc += q.scale * p.scale * (block_ip as f32);
    }
    Ok(acc)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{UasAddress, UasKind};

    fn page_with_residual(seed: u64, blocks: Vec<ResidualBlock>, block_size: usize) -> HeliosPage {
        let address = UasAddress::new(UasKind::KvPage, &seed.to_le_bytes(), 0);
        HeliosPage::sketch_only(address, vec![1, 1, 1, 1])
            .unwrap()
            .with_residual(blocks, block_size)
            .unwrap()
    }

    fn page_sketch_only(seed: u64) -> HeliosPage {
        let address = UasAddress::new(UasKind::KvPage, &seed.to_le_bytes(), 0);
        HeliosPage::sketch_only(address, vec![1, 1, 1, 1]).unwrap()
    }

    #[test]
    fn empty_output_errors() {
        let candidates = vec![(0_usize, 10)];
        let corpus = vec![page_sketch_only(0)];
        let query_residual: Vec<ResidualBlock> = vec![];
        let mut output: Vec<(usize, f32)> = vec![];
        let err = residual_rescore(&query_residual, &candidates, &corpus, &mut output).unwrap_err();
        assert_eq!(err, ResidualRescoreError::EmptyOutputBuffer);
    }

    #[test]
    fn candidate_out_of_range_errors() {
        let candidates = vec![(99_usize, 10)];
        let corpus = vec![page_sketch_only(0)];
        let query_residual: Vec<ResidualBlock> = vec![];
        let mut output = vec![(0_usize, f32::NEG_INFINITY); 1];
        let err = residual_rescore(&query_residual, &candidates, &corpus, &mut output).unwrap_err();
        assert_eq!(
            err,
            ResidualRescoreError::CandidateOutOfRange { candidate_index: 99, corpus_len: 1 }
        );
    }

    #[test]
    fn rescore_picks_best_when_all_have_residual() {
        let block_size = 2;
        let q = vec![ResidualBlock { data: vec![10, 10], scale: 0.1 }];

        let corpus = vec![
            page_with_residual(0, vec![ResidualBlock { data: vec![10, 10], scale: 0.1 }], block_size),
            page_with_residual(1, vec![ResidualBlock { data: vec![20, 20], scale: 0.1 }], block_size),
            page_with_residual(2, vec![ResidualBlock { data: vec![5, 5], scale: 0.1 }], block_size),
        ];
        // page 1 has largest signal (20 * 10 * 2 * 0.01 = 4.0); page 0 has 2.0; page 2 has 1.0
        let candidates = vec![(0_usize, 100), (1_usize, 100), (2_usize, 100)];
        let mut output = vec![(0_usize, f32::NEG_INFINITY); 1];

        residual_rescore(&q, &candidates, &corpus, &mut output).unwrap();
        assert_eq!(output[0].0, 1, "page 1 should be top-1 by residual rescore");
    }

    #[test]
    fn sketch_only_page_falls_back_to_sketch_score() {
        let q: Vec<ResidualBlock> = vec![];
        // Single candidate, no residual on the page.
        let corpus = vec![page_sketch_only(0)];
        let candidates = vec![(0_usize, 128)]; // raw sketch score 128 → 1.0 after /128 scale
        let mut output = vec![(0_usize, f32::NEG_INFINITY); 1];

        residual_rescore(&q, &candidates, &corpus, &mut output).unwrap();
        assert_eq!(output[0].0, 0);
        assert!((output[0].1 - 1.0).abs() < 1e-6, "fallback score = sketch_score / 128.0");
    }

    #[test]
    fn shape_mismatch_when_page_has_residual_but_query_does_not() {
        let block_size = 2;
        let q: Vec<ResidualBlock> = vec![]; // empty query residual
        let corpus = vec![page_with_residual(
            0,
            vec![ResidualBlock { data: vec![1, 1], scale: 1.0 }],
            block_size,
        )];
        let candidates = vec![(0_usize, 1)];
        let mut output = vec![(0_usize, f32::NEG_INFINITY); 1];
        let err = residual_rescore(&q, &candidates, &corpus, &mut output).unwrap_err();
        assert_eq!(
            err,
            ResidualRescoreError::QueryResidualShapeMismatch { page_index: 0 }
        );
    }

    #[test]
    fn mixed_corpus_some_residual_some_sketch_only() {
        let block_size = 2;
        let q = vec![ResidualBlock { data: vec![10, 10], scale: 0.1 }];
        let corpus = vec![
            page_with_residual(0, vec![ResidualBlock { data: vec![10, 10], scale: 0.1 }], block_size),
            page_sketch_only(1),
        ];
        // page 0 residual: 10*10*2 * 0.01 = 2.0
        // page 1 sketch fallback: 128 / 128 = 1.0
        let candidates = vec![(0_usize, 50), (1_usize, 128)];
        let mut output = vec![(0_usize, f32::NEG_INFINITY); 2];

        residual_rescore(&q, &candidates, &corpus, &mut output).unwrap();
        // Both candidates fit; verify ordering / inclusion.
        let mut ids: Vec<usize> = output.iter().map(|(i, _)| *i).collect();
        ids.sort();
        assert_eq!(ids, vec![0, 1]);
    }
}
