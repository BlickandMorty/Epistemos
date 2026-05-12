//! Query freshness contract (canonical plan §"Query freshness contract").
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Query freshness
//! contract (applies to all materialized views)":
//!
//! > Every materialized view (CSR shards, cluster pyramid, layout cache,
//! > search index) carries a `through_seq` watermark. Every query
//! > response merges base + delta:
//! >
//! > ```rust
//! > struct QueryReply<T> {
//! >     hits: Vec<T>,
//! >     materialized_through_seq: u64,  // base view watermark
//! >     local_head_seq: u64,             // current local op-log head
//! >     stale_ops: u64,                  // = local_head_seq - materialized_through_seq
//! > }
//! > ```
//! >
//! > If `stale_ops > 0`, the UI may surface "indexing N changes" rather
//! > than pretending freshness. This is the operational analogue of
//! > "sleep ≠ invisible": never silently lie about state.
//!
//! ## Doctrine
//!
//! Every query response merges a base view (materialized lazily, lags
//! the op-log head by some amount) with a delta. The watermark surfaces
//! the lag honestly so the UI can label progressive results instead of
//! pretending freshness.
//!
//! Three latency classes from the canonical plan:
//!
//! | Class             | Subsystems                              | Target freshness |
//! |-------------------|-----------------------------------------|------------------|
//! | Immediate         | Local editor, canonical graph rows      | Same frame      |
//! | Near-real-time    | Neighbourhood expand, recent-text overlay | 0-250 ms       |
//! | Heavy             | FTS base index, HNSW, CSR shards        | 50 ms - 60 s    |
//!
//! ## Pure-data contract
//!
//! This module owns the typed wrapper. Each materialized-view module
//! decides how to populate the watermarks. No engine dependencies.
//!
//! ## Why a separate module
//!
//! The contract is **cross-cutting** — CSR shards, cluster pyramid,
//! layout cache, search index all need to surface `stale_ops` the same
//! way. Centralising the type means callers don't reinvent it.

use serde::{Deserialize, Serialize};

/// Three canonical latency classes from the canonical plan.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FreshnessClass {
    /// Local editor, canonical graph rows, sync ack — same-frame freshness.
    Immediate,
    /// Neighbourhood expand, reverse links, recent-text overlay — 0-250 ms.
    NearRealTime,
    /// FTS base index, HNSW, CSR shards, cluster pyramid, overview layout
    /// — 50 ms to 60 s depending on subsystem.
    Heavy,
}

impl FreshnessClass {
    /// Upper bound of the target freshness window in milliseconds.
    pub fn max_freshness_ms(self) -> u64 {
        match self {
            Self::Immediate => 17,        // ~one 60Hz frame
            Self::NearRealTime => 250,
            Self::Heavy => 60_000,
        }
    }
}

/// Typed wrapper around a query result with freshness annotations.
///
/// Generic `T` is the hit type — `GraphNodeId`, `EdgeId`, document
/// reference, whatever the underlying view returns. The watermarks let
/// the UI surface "indexing N changes" honestly when `stale_ops > 0`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct QueryReply<T> {
    /// Materialised hits (the actual answer rows).
    pub hits: Vec<T>,
    /// Op-log sequence number the base view has been materialised through.
    pub materialized_through_seq: u64,
    /// Current local op-log head sequence number.
    pub local_head_seq: u64,
    /// `local_head_seq - materialized_through_seq` — derived but stored
    /// for serialisation convenience. Always non-negative.
    pub stale_ops: u64,
    /// Which latency class this view belongs to. Drives the UI's
    /// stale-state policy (e.g. show a spinner only for Heavy class).
    pub freshness_class: FreshnessClass,
}

impl<T> QueryReply<T> {
    /// Construct a QueryReply, computing `stale_ops` from the two seqs.
    /// If `materialized_through_seq > local_head_seq` (impossible under
    /// the canonical contract — base view can't be ahead of the log),
    /// `stale_ops` is clamped to 0 and a defensive eprintln fires.
    pub fn new(
        hits: Vec<T>,
        materialized_through_seq: u64,
        local_head_seq: u64,
        freshness_class: FreshnessClass,
    ) -> Self {
        let stale_ops = if local_head_seq >= materialized_through_seq {
            local_head_seq - materialized_through_seq
        } else {
            eprintln!(
                "QueryReply: materialized_through_seq ({materialized_through_seq}) > local_head_seq ({local_head_seq}) — \
                 watermark inversion bug, clamping stale_ops to 0"
            );
            0
        };
        Self {
            hits,
            materialized_through_seq,
            local_head_seq,
            stale_ops,
            freshness_class,
        }
    }

    /// True when the base view is fully caught up to the log head.
    pub fn is_fresh(&self) -> bool {
        self.stale_ops == 0
    }

    /// UI helper — formatted label for the stale-state badge.
    /// Returns `None` when fresh (no badge needed).
    pub fn stale_label(&self) -> Option<String> {
        if self.stale_ops == 0 {
            None
        } else if self.stale_ops == 1 {
            Some("indexing 1 change".to_string())
        } else {
            Some(format!("indexing {} changes", self.stale_ops))
        }
    }

    /// Map the hits to a different type, preserving watermarks.
    pub fn map_hits<U, F: FnMut(T) -> U>(self, f: F) -> QueryReply<U> {
        QueryReply {
            hits: self.hits.into_iter().map(f).collect(),
            materialized_through_seq: self.materialized_through_seq,
            local_head_seq: self.local_head_seq,
            stale_ops: self.stale_ops,
            freshness_class: self.freshness_class,
        }
    }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn freshness_class_thresholds_match_canonical_table() {
        assert_eq!(FreshnessClass::Immediate.max_freshness_ms(), 17);
        assert_eq!(FreshnessClass::NearRealTime.max_freshness_ms(), 250);
        assert_eq!(FreshnessClass::Heavy.max_freshness_ms(), 60_000);
    }

    #[test]
    fn fresh_reply_has_zero_stale_ops() {
        let reply: QueryReply<u32> = QueryReply::new(
            vec![1, 2, 3],
            100,
            100,
            FreshnessClass::Heavy,
        );
        assert!(reply.is_fresh());
        assert_eq!(reply.stale_ops, 0);
        assert!(reply.stale_label().is_none());
    }

    #[test]
    fn stale_reply_computes_op_lag_correctly() {
        let reply: QueryReply<u32> = QueryReply::new(
            vec![1, 2],
            85,
            100,
            FreshnessClass::Heavy,
        );
        assert!(!reply.is_fresh());
        assert_eq!(reply.stale_ops, 15);
    }

    #[test]
    fn stale_label_singular_vs_plural() {
        let r1: QueryReply<u32> = QueryReply::new(vec![], 99, 100, FreshnessClass::Heavy);
        assert_eq!(r1.stale_label(), Some("indexing 1 change".to_string()));
        let r5: QueryReply<u32> = QueryReply::new(vec![], 95, 100, FreshnessClass::Heavy);
        assert_eq!(r5.stale_label(), Some("indexing 5 changes".to_string()));
    }

    #[test]
    fn inverted_watermark_clamps_to_zero_with_warning() {
        // Per the canonical contract, materialized_through_seq > local_head_seq
        // is impossible. If it happens, that's a watermark inversion bug —
        // the reply still constructs cleanly with stale_ops = 0.
        let reply: QueryReply<u32> = QueryReply::new(vec![], 150, 100, FreshnessClass::Heavy);
        assert_eq!(reply.stale_ops, 0);
        assert!(reply.is_fresh());
    }

    #[test]
    fn map_hits_preserves_watermarks() {
        let reply: QueryReply<u32> = QueryReply::new(
            vec![1, 2, 3],
            42,
            50,
            FreshnessClass::NearRealTime,
        );
        let mapped: QueryReply<String> = reply.map_hits(|n| format!("hit-{}", n));
        assert_eq!(mapped.materialized_through_seq, 42);
        assert_eq!(mapped.local_head_seq, 50);
        assert_eq!(mapped.stale_ops, 8);
        assert_eq!(mapped.freshness_class, FreshnessClass::NearRealTime);
        assert_eq!(mapped.hits, vec!["hit-1", "hit-2", "hit-3"]);
    }

    #[test]
    fn freshness_class_serializes_snake_case() {
        let json = serde_json::to_string(&FreshnessClass::NearRealTime).unwrap();
        assert_eq!(json, "\"near_real_time\"");
        let back: FreshnessClass = serde_json::from_str("\"immediate\"").unwrap();
        assert_eq!(back, FreshnessClass::Immediate);
    }

    #[test]
    fn query_reply_round_trips_via_serde() {
        let r: QueryReply<u32> = QueryReply::new(
            vec![10, 20, 30],
            100,
            105,
            FreshnessClass::Heavy,
        );
        let json = serde_json::to_string(&r).unwrap();
        let back: QueryReply<u32> = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn empty_hits_with_stale_ops_still_useful() {
        // A common case: query has no hits yet, but base view is lagging.
        // UI surfaces "indexing N changes" while waiting for results.
        let r: QueryReply<u32> = QueryReply::new(vec![], 0, 50, FreshnessClass::Heavy);
        assert!(r.hits.is_empty());
        assert_eq!(r.stale_ops, 50);
        assert!(!r.is_fresh());
    }
}
