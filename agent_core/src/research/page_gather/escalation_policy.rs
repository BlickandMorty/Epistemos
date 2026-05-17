//! `escalation_policy` — F-ShadowFirst three-stage decision logic.
//!
//! Per F-ShadowFirst-PageEscalation falsifier §2:
//!
//! ```text
//! For each query q:
//!   scores = sketch_topk(q, K_SKETCH = 128)
//!   residual_scores = residual_rescore(scores, K_RESIDUAL = 32)
//!   if max(residual_scores) - second_max(residual_scores) ≥ EXACT_THRESHOLD:
//!       return top1_residual          # cheap path
//!   else:
//!       exact_scores = exact_decode(top_k_residual)
//!       return argmax(exact_scores)   # exact path
//! ```
//!
//! This module owns the scratch buffers; production hot-path callers
//! construct one `EscalationPolicy` per thread and reuse it across
//! queries — zero allocations per query.

use crate::research::page_gather::helios_page::{HeliosPage, ResidualBlock};
use crate::research::page_gather::residual_rescore::{residual_rescore, ResidualRescoreError};
use crate::research::page_gather::sketch_topk::{sketch_top_k, SketchTopKError};

/// Tunable thresholds per F-ShadowFirst falsifier §2.
#[derive(Clone, Debug, PartialEq)]
pub struct EscalationThresholds {
    /// K_SKETCH — top-K candidates from Stage 1 sketch scoring.
    pub k_sketch: usize,
    /// K_RESIDUAL — top-K candidates promoted to Stage 2 residual rescore.
    /// MUST be ≤ k_sketch (substrate-floor enforces).
    pub k_residual: usize,
    /// EXACT_THRESHOLD — margin in normalized score space below which the
    /// policy escalates to exact decode.
    pub exact_threshold: f32,
    /// RESIDUAL_THRESHOLD — informational; the sketch-score quantile that
    /// promotes to residual. Stage 1 produces K_SKETCH candidates
    /// regardless; this threshold may be used by a production refinement.
    pub residual_threshold: f32,
}

impl Default for EscalationThresholds {
    fn default() -> Self {
        // Default values per F-ShadowFirst §2.
        Self {
            k_sketch: 128,
            k_residual: 32,
            exact_threshold: 0.08,
            residual_threshold: 0.20,
        }
    }
}

/// Error surface for escalation.
#[derive(Clone, Debug, PartialEq)]
pub enum EscalationError {
    SketchStage(SketchTopKError),
    ResidualStage(ResidualRescoreError),
    /// K_RESIDUAL was larger than K_SKETCH; substrate-floor invariant
    /// violation.
    ResidualLargerThanSketch { k_sketch: usize, k_residual: usize },
    /// All candidates were sentinel-empty (corpus had no scoreable
    /// pages).
    EmptyResidualResult,
}

impl From<SketchTopKError> for EscalationError {
    fn from(e: SketchTopKError) -> Self {
        EscalationError::SketchStage(e)
    }
}

impl From<ResidualRescoreError> for EscalationError {
    fn from(e: ResidualRescoreError) -> Self {
        EscalationError::ResidualStage(e)
    }
}

/// Verdict returned by `EscalationPolicy::escalate` — which path
/// satisfied the query AND the winner page + score + margin.
#[derive(Clone, Debug, PartialEq)]
pub enum EscalationVerdict {
    /// Stage 2 produced a confident winner (margin ≥ exact_threshold).
    /// No exact decode needed.
    CheapResidual {
        winner_page_index: usize,
        score: f32,
        margin: f32,
    },
    /// Stage 2 was inconclusive; policy escalated to exact decode.
    /// Substrate-floor returns the candidate set without actually
    /// performing the exact decode (production reads SSD pages).
    ExactDecode {
        candidates: Vec<(usize, f32)>,
        provisional_winner: usize,
        margin: f32,
    },
}

/// Pre-allocated three-stage escalation policy. Reuse a single instance
/// across queries for zero per-query allocation.
#[derive(Debug)]
pub struct EscalationPolicy {
    pub thresholds: EscalationThresholds,
    sketch_scratch: Vec<(usize, i32)>,
    residual_scratch: Vec<(usize, f32)>,
}

impl EscalationPolicy {
    /// Build a policy with the given thresholds. Pre-allocates scratch
    /// buffers sized to `k_sketch` + `k_residual`.
    pub fn new(thresholds: EscalationThresholds) -> Result<Self, EscalationError> {
        if thresholds.k_residual > thresholds.k_sketch {
            return Err(EscalationError::ResidualLargerThanSketch {
                k_sketch: thresholds.k_sketch,
                k_residual: thresholds.k_residual,
            });
        }
        Ok(Self {
            sketch_scratch: vec![(0_usize, i32::MIN); thresholds.k_sketch],
            residual_scratch: vec![(0_usize, f32::NEG_INFINITY); thresholds.k_residual],
            thresholds,
        })
    }

    /// Run the full three-stage escalation. Zero allocations on hot path
    /// (scratch buffers reused across calls).
    pub fn escalate(
        &mut self,
        query_sketch: &[i8],
        query_residual: &[ResidualBlock],
        corpus: &[HeliosPage],
    ) -> Result<EscalationVerdict, EscalationError> {
        // Stage 1 — sketch top-K.
        sketch_top_k(query_sketch, corpus, &mut self.sketch_scratch)?;

        // Stage 2 — residual rescore.
        residual_rescore(
            query_residual,
            &self.sketch_scratch,
            corpus,
            &mut self.residual_scratch,
        )?;

        // Stage 3 — margin check. Find top-1 + second-best in the
        // residual scratch.
        let (top1_slot, top1_idx, top1_score) = max_score_slot(&self.residual_scratch);
        if top1_score == f32::NEG_INFINITY {
            return Err(EscalationError::EmptyResidualResult);
        }
        let top2_score = second_max_score(&self.residual_scratch, top1_slot);
        let margin = if top2_score == f32::NEG_INFINITY {
            f32::INFINITY // single non-sentinel result: infinite margin
        } else {
            top1_score - top2_score
        };

        if margin >= self.thresholds.exact_threshold {
            Ok(EscalationVerdict::CheapResidual {
                winner_page_index: top1_idx,
                score: top1_score,
                margin,
            })
        } else {
            // Escalate. Production would now call exact_decode(candidates,
            // corpus) → exact_scores. Substrate-floor returns the
            // candidate set + provisional winner (which exact_decode
            // would refine).
            let candidates = self.residual_scratch.clone(); // intentional alloc — only fires on exact-path escalation
            Ok(EscalationVerdict::ExactDecode {
                candidates,
                provisional_winner: top1_idx,
                margin,
            })
        }
    }
}

fn max_score_slot(scratch: &[(usize, f32)]) -> (usize, usize, f32) {
    let mut slot = 0;
    let mut idx = scratch[0].0;
    let mut score = scratch[0].1;
    for (i, &(p_idx, s)) in scratch.iter().enumerate().skip(1) {
        if s > score {
            slot = i;
            idx = p_idx;
            score = s;
        }
    }
    (slot, idx, score)
}

fn second_max_score(scratch: &[(usize, f32)], top_slot: usize) -> f32 {
    let mut best = f32::NEG_INFINITY;
    for (i, &(_p_idx, s)) in scratch.iter().enumerate() {
        if i == top_slot {
            continue;
        }
        if s > best {
            best = s;
        }
    }
    best
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{UasAddress, UasKind};

    fn page_with_sketch_and_residual(seed: u64, sketch: Vec<i8>, residual: Vec<ResidualBlock>, block_size: usize) -> HeliosPage {
        let address = UasAddress::new(UasKind::KvPage, &seed.to_le_bytes(), 0);
        HeliosPage::sketch_only(address, sketch)
            .unwrap()
            .with_residual(residual, block_size)
            .unwrap()
    }

    #[test]
    fn k_residual_larger_than_k_sketch_errors() {
        let bad = EscalationThresholds { k_sketch: 32, k_residual: 64, ..Default::default() };
        let err = EscalationPolicy::new(bad).unwrap_err();
        assert!(matches!(err, EscalationError::ResidualLargerThanSketch { .. }));
    }

    #[test]
    fn cheap_residual_path_with_clear_margin() {
        let thresholds = EscalationThresholds {
            k_sketch: 4,
            k_residual: 4,
            exact_threshold: 0.5,
            residual_threshold: 0.2,
        };
        let mut policy = EscalationPolicy::new(thresholds).unwrap();

        // Corpus: 4 pages, one with clearly-better residual.
        let bs = 2;
        let corpus = vec![
            page_with_sketch_and_residual(
                0,
                vec![100, 100],
                vec![ResidualBlock { data: vec![100, 100], scale: 0.1 }],
                bs,
            ),
            page_with_sketch_and_residual(
                1,
                vec![1, 1],
                vec![ResidualBlock { data: vec![1, 1], scale: 0.01 }],
                bs,
            ),
            page_with_sketch_and_residual(
                2,
                vec![1, 1],
                vec![ResidualBlock { data: vec![1, 1], scale: 0.01 }],
                bs,
            ),
            page_with_sketch_and_residual(
                3,
                vec![1, 1],
                vec![ResidualBlock { data: vec![1, 1], scale: 0.01 }],
                bs,
            ),
        ];
        let query_sketch = vec![100, 100];
        let query_residual = vec![ResidualBlock { data: vec![100, 100], scale: 0.1 }];

        let verdict = policy.escalate(&query_sketch, &query_residual, &corpus).unwrap();
        match verdict {
            EscalationVerdict::CheapResidual { winner_page_index, .. } => {
                assert_eq!(winner_page_index, 0, "page 0 has clearly-better residual");
            }
            EscalationVerdict::ExactDecode { .. } => panic!("expected cheap-residual path; got exact-decode"),
        }
    }

    #[test]
    fn exact_path_when_residual_is_tight() {
        let thresholds = EscalationThresholds {
            k_sketch: 4,
            k_residual: 4,
            exact_threshold: 100.0, // very high; force exact path
            residual_threshold: 0.2,
        };
        let mut policy = EscalationPolicy::new(thresholds).unwrap();

        let bs = 2;
        let corpus = vec![
            page_with_sketch_and_residual(0, vec![10, 10], vec![ResidualBlock { data: vec![10, 10], scale: 0.1 }], bs),
            page_with_sketch_and_residual(1, vec![10, 10], vec![ResidualBlock { data: vec![10, 10], scale: 0.1 }], bs),
        ];
        let query_sketch = vec![10, 10];
        let query_residual = vec![ResidualBlock { data: vec![10, 10], scale: 0.1 }];

        let verdict = policy.escalate(&query_sketch, &query_residual, &corpus).unwrap();
        assert!(matches!(verdict, EscalationVerdict::ExactDecode { .. }));
    }

    #[test]
    fn single_result_has_infinite_margin() {
        let thresholds = EscalationThresholds { k_sketch: 1, k_residual: 1, exact_threshold: 0.5, residual_threshold: 0.2 };
        let mut policy = EscalationPolicy::new(thresholds).unwrap();

        let bs = 2;
        let corpus = vec![page_with_sketch_and_residual(0, vec![10, 10], vec![ResidualBlock { data: vec![10, 10], scale: 0.1 }], bs)];
        let query_sketch = vec![10, 10];
        let query_residual = vec![ResidualBlock { data: vec![10, 10], scale: 0.1 }];

        let verdict = policy.escalate(&query_sketch, &query_residual, &corpus).unwrap();
        // With only 1 result, margin = INFINITY > any exact_threshold,
        // so cheap-residual.
        assert!(matches!(verdict, EscalationVerdict::CheapResidual { .. }));
    }

    #[test]
    fn default_thresholds_match_falsifier_spec() {
        let t = EscalationThresholds::default();
        assert_eq!(t.k_sketch, 128);
        assert_eq!(t.k_residual, 32);
        assert!((t.exact_threshold - 0.08).abs() < 1e-6);
        assert!((t.residual_threshold - 0.20).abs() < 1e-6);
    }
}
