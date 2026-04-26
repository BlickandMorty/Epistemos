//! W8.4.e — Reciprocal Rank Fusion.
//!
//! Pure function — no I/O, no allocator surprises, ~30 LOC of real
//! work. Fuses dense (vector) + lexical (BM25) hit lists into a
//! single ranking per the canonical Cormack/Clarke/Büttcher paper:
//!
//!     score(d) = Σ 1/(k + rank_i(d))
//!
//! where `rank_i(d)` is the doc's rank (1-indexed) in result list `i`.
//! `k=60` is the original-pilot-study constant; anywhere in `[20, 100]`
//! MAP barely moves so we pick the canonical default. Higher `k`
//! flattens the curve (later positions still contribute meaningfully);
//! lower `k` makes the top positions dominate more.
//!
//! Tied scores break by sort stability of the input lists; the
//! function preserves first-occurrence order across the two channels
//! when scores are exactly equal.

use rustc_hash::FxHashMap;

/// Canonical RRF k. Logseq, Quickwit, Vespa all default here.
pub const RRF_K_DEFAULT: usize = 60;

/// Fuse two ranked hit lists. The lists are `(doc_id, score)` pairs in
/// rank order — score is informational only (RRF ignores it; the rank
/// position is what matters).
///
/// Returns the fused list capped at `limit` entries, sorted by RRF
/// score descending. Output `score` is the RRF aggregate; the original
/// per-channel scores are not preserved (callers needing them should
/// keep their own side maps).
///
/// `k` controls the smoothing constant; pass `RRF_K_DEFAULT` (60) for
/// the canonical behavior.
pub fn rrf_fuse(
    dense: &[(String, f32)],
    lexical: &[(String, f32)],
    k: usize,
    limit: usize,
) -> Vec<(String, f32)> {
    if limit == 0 {
        return Vec::new();
    }
    let kf = k as f32;

    // Doc id → cumulative RRF score
    let mut scores: FxHashMap<String, f32> =
        FxHashMap::with_capacity_and_hasher(dense.len() + lexical.len(), Default::default());
    // First-seen order so equal scores break deterministically.
    let mut order: FxHashMap<String, usize> =
        FxHashMap::with_capacity_and_hasher(dense.len() + lexical.len(), Default::default());
    let mut order_counter: usize = 0;

    for (rank_zero, (doc_id, _score)) in dense.iter().enumerate() {
        let rank = rank_zero + 1;
        *scores.entry(doc_id.clone()).or_insert(0.0) += 1.0 / (kf + rank as f32);
        order.entry(doc_id.clone()).or_insert_with(|| {
            let v = order_counter;
            order_counter += 1;
            v
        });
    }
    for (rank_zero, (doc_id, _score)) in lexical.iter().enumerate() {
        let rank = rank_zero + 1;
        *scores.entry(doc_id.clone()).or_insert(0.0) += 1.0 / (kf + rank as f32);
        order.entry(doc_id.clone()).or_insert_with(|| {
            let v = order_counter;
            order_counter += 1;
            v
        });
    }

    let mut fused: Vec<(String, f32)> = scores.into_iter().collect();
    // Score descending; ties broken by first-seen order.
    fused.sort_by(|a, b| {
        match b.1.partial_cmp(&a.1) {
            Some(std::cmp::Ordering::Equal) | None => {
                let oa = order.get(&a.0).copied().unwrap_or(usize::MAX);
                let ob = order.get(&b.0).copied().unwrap_or(usize::MAX);
                oa.cmp(&ob)
            }
            Some(o) => o,
        }
    });
    fused.truncate(limit);
    fused
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pair(id: &str, score: f32) -> (String, f32) {
        (id.to_string(), score)
    }

    #[test]
    fn fuses_two_disjoint_lists_summed_into_one() {
        let dense = vec![pair("a", 0.9), pair("b", 0.5)];
        let lexical = vec![pair("c", 1.5), pair("d", 0.3)];
        let fused = rrf_fuse(&dense, &lexical, RRF_K_DEFAULT, 10);
        let ids: Vec<&str> = fused.iter().map(|(id, _)| id.as_str()).collect();
        assert_eq!(ids.len(), 4, "every input doc MUST appear in the fused list");
        // Each doc has rank 1 in exactly one channel + rank 1 = 1/(60+1) = 0.01639.
        // Each doc has rank 2 in exactly one channel + rank 2 = 1/(60+2) = 0.01613.
        // So a + c (rank 1 in their channels) > b + d (rank 2).
        assert!(ids[0] == "a" || ids[0] == "c");
        assert!(ids[1] == "a" || ids[1] == "c");
        assert!(ids[2] == "b" || ids[2] == "d");
        assert!(ids[3] == "b" || ids[3] == "d");
    }

    #[test]
    fn doc_in_both_channels_outranks_doc_in_one() {
        let dense = vec![pair("shared", 0.9), pair("dense_only", 0.5)];
        let lexical = vec![pair("shared", 1.5), pair("lex_only", 0.3)];
        let fused = rrf_fuse(&dense, &lexical, RRF_K_DEFAULT, 10);
        assert_eq!(
            fused[0].0, "shared",
            "doc appearing in BOTH channels MUST outrank singletons"
        );
        // shared score = 1/61 + 1/61 = 0.03279
        // singletons     = 1/62      = 0.01613
        assert!(
            fused[0].1 > fused[1].1 + 0.01,
            "shared doc score {} must clearly exceed singleton {}",
            fused[0].1, fused[1].1
        );
    }

    #[test]
    fn empty_dense_returns_lexical_in_order() {
        let lexical = vec![pair("a", 1.0), pair("b", 0.5)];
        let fused = rrf_fuse(&[], &lexical, RRF_K_DEFAULT, 10);
        assert_eq!(fused.len(), 2);
        assert_eq!(fused[0].0, "a");
        assert_eq!(fused[1].0, "b");
    }

    #[test]
    fn empty_lexical_returns_dense_in_order() {
        let dense = vec![pair("a", 1.0), pair("b", 0.5)];
        let fused = rrf_fuse(&dense, &[], RRF_K_DEFAULT, 10);
        assert_eq!(fused.len(), 2);
        assert_eq!(fused[0].0, "a");
        assert_eq!(fused[1].0, "b");
    }

    #[test]
    fn both_empty_returns_empty() {
        let fused = rrf_fuse(&[], &[], RRF_K_DEFAULT, 10);
        assert!(fused.is_empty());
    }

    #[test]
    fn limit_zero_returns_empty() {
        let dense = vec![pair("a", 1.0)];
        assert!(rrf_fuse(&dense, &[], RRF_K_DEFAULT, 0).is_empty());
    }

    #[test]
    fn limit_truncates_to_top_n() {
        let dense: Vec<_> = (0..10).map(|i| pair(&format!("d{i}"), 1.0)).collect();
        let fused = rrf_fuse(&dense, &[], RRF_K_DEFAULT, 3);
        assert_eq!(fused.len(), 3);
        assert_eq!(fused[0].0, "d0");
        assert_eq!(fused[1].0, "d1");
        assert_eq!(fused[2].0, "d2");
    }

    #[test]
    fn k_smaller_makes_top_positions_dominate_more() {
        // With shared docs, smaller k → bigger gap between top + tail.
        let dense = vec![pair("shared", 0.9), pair("tail", 0.1)];
        let lexical = vec![pair("shared", 1.0)];

        let fused_small_k = rrf_fuse(&dense, &lexical, 1, 10);
        let fused_big_k = rrf_fuse(&dense, &lexical, 1000, 10);

        let small_gap = fused_small_k[0].1 - fused_small_k[1].1;
        let big_gap = fused_big_k[0].1 - fused_big_k[1].1;
        assert!(
            small_gap > big_gap,
            "smaller k MUST widen the gap; small={small_gap} big={big_gap}"
        );
    }

    #[test]
    fn rrf_k_default_is_canonical_60() {
        // Pin the constant — Cormack/Clarke/Büttcher SIGIR 2009.
        assert_eq!(RRF_K_DEFAULT, 60);
    }
}
