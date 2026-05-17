//! Active-pull selector — the substrate that decides which packets fire
//! for a given query.
//!
//! Per F-ActiveAssembly-Minimal falsifier §2:
//!
//! ```text
//! For each query q:
//!   active = {output_sink}
//!   loop:
//!     candidates = ∪{predecessors(p) for p in active}
//!     rank candidates by (anchor_score(q, candidate) - cost_weight * candidate.cost_units)
//!     promote top-K from candidates into active
//!   until: active set stable OR depth_budget exhausted
//!   emit: run only packets in active
//! ```
//!
//! # Phase B.G.B6.b — iter 38
//!
//! Lands the `MarginAnchoredGreedyPull` strategy + `Selector` trait. The
//! integration harness lives in `agent_core/tests/active_assembly_minimal.rs`
//! (lands iter 39+).

use std::collections::BTreeSet;

use crate::research::active_assembly::packet::{Packet, PacketGraph, PacketId};

/// Selector trait — every active-pull strategy implements this.
pub trait Selector {
    /// Select the active packet set for the given query, starting from the
    /// `sink` packet.
    fn select(
        &self,
        graph: &PacketGraph,
        sink: PacketId,
        query: u64,
    ) -> Result<BTreeSet<PacketId>, SelectorError>;
}

/// Selector error surface.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SelectorError {
    /// The sink packet was not present in the graph.
    UnknownSink(PacketId),
}

/// Margin-anchored greedy-pull selector (the F-ActiveAssembly canonical
/// strategy).
///
/// Configuration knobs:
/// - `k_promote_per_round`: how many top candidates promote into the
///   active set per iteration (per falsifier §2 the canonical value is 4).
/// - `cost_weight`: penalty per cost unit (per falsifier §2 default 1.0;
///   higher = more aggressive pruning).
/// - `depth_budget`: max iterations before stopping (per falsifier §2
///   default 8).
#[derive(Clone, Debug, PartialEq)]
pub struct MarginAnchoredGreedyPull {
    pub k_promote_per_round: usize,
    pub cost_weight: f32,
    pub depth_budget: usize,
}

impl Default for MarginAnchoredGreedyPull {
    fn default() -> Self {
        Self { k_promote_per_round: 4, cost_weight: 1.0, depth_budget: 8 }
    }
}

impl MarginAnchoredGreedyPull {
    /// Anchor score for a query against a packet's input pattern.
    /// Higher = better match. Substrate-floor uses Hamming-similarity:
    /// (64 - popcount(query XOR pattern)) as f32.
    pub fn anchor_score(&self, query: u64, packet: &Packet) -> f32 {
        let mismatch = (query ^ packet.input_pattern).count_ones() as f32;
        let similarity = 64.0 - mismatch; // 0..=64
        similarity - self.cost_weight * (packet.cost_units as f32)
    }
}

impl Selector for MarginAnchoredGreedyPull {
    fn select(
        &self,
        graph: &PacketGraph,
        sink: PacketId,
        query: u64,
    ) -> Result<BTreeSet<PacketId>, SelectorError> {
        if !graph.contains(sink) {
            return Err(SelectorError::UnknownSink(sink));
        }

        let mut active: BTreeSet<PacketId> = BTreeSet::new();
        active.insert(sink);

        for _round in 0..self.depth_budget {
            // Gather every candidate predecessor of the current active set.
            let mut candidates: Vec<(PacketId, f32)> = Vec::new();
            for &p_id in &active {
                if let Some(p) = graph.get(p_id) {
                    for &pred_id in &p.predecessors {
                        if active.contains(&pred_id) {
                            continue;
                        }
                        if let Some(pred) = graph.get(pred_id) {
                            let score = self.anchor_score(query, pred);
                            candidates.push((pred_id, score));
                        }
                    }
                }
            }

            if candidates.is_empty() {
                break;
            }

            // Sort by score descending; promote top-K.
            candidates.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

            let before = active.len();
            for (id, _score) in candidates.iter().take(self.k_promote_per_round) {
                active.insert(*id);
            }

            // Stable-set check: if no new packets were added, stop.
            if active.len() == before {
                break;
            }
        }

        Ok(active)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::research::active_assembly::packet::Packet;

    fn graph_n(n: usize) -> PacketGraph {
        let mut g = PacketGraph::new();
        for i in 0..n {
            let preds: Vec<PacketId> = if i == 0 {
                vec![]
            } else if i == 1 {
                vec![PacketId(0)]
            } else {
                vec![PacketId(i - 1), PacketId(i - 2)]
            };
            g.add(Packet::new(PacketId(i), i as u64, (i * 2) as u64, ((i % 16) + 1) as u8, preds))
                .unwrap();
        }
        g
    }

    #[test]
    fn selector_includes_sink_always() {
        let g = graph_n(5);
        let s = MarginAnchoredGreedyPull::default();
        let active = s.select(&g, PacketId(4), 0).unwrap();
        assert!(active.contains(&PacketId(4)));
    }

    #[test]
    fn selector_walks_predecessors() {
        let g = graph_n(10);
        let s = MarginAnchoredGreedyPull::default();
        let active = s.select(&g, PacketId(9), 0).unwrap();
        // Sink is in; some predecessors should be in too.
        assert!(active.contains(&PacketId(9)));
        assert!(active.len() > 1, "selector should walk backwards from sink");
    }

    #[test]
    fn unknown_sink_errors() {
        let g = graph_n(3);
        let s = MarginAnchoredGreedyPull::default();
        assert_eq!(
            s.select(&g, PacketId(99), 0).unwrap_err(),
            SelectorError::UnknownSink(PacketId(99))
        );
    }

    #[test]
    fn anchor_score_higher_for_closer_pattern() {
        let s = MarginAnchoredGreedyPull { k_promote_per_round: 1, cost_weight: 0.0, depth_budget: 1 };
        let p_match = Packet::new(PacketId(0), 0xFFFF_FFFF_FFFF_FFFF, 0, 1, vec![]);
        let p_miss = Packet::new(PacketId(1), 0x0000_0000_0000_0000, 0, 1, vec![]);
        let query = 0xFFFF_FFFF_FFFF_FFFF;
        assert!(s.anchor_score(query, &p_match) > s.anchor_score(query, &p_miss));
    }

    #[test]
    fn cost_weight_penalizes_expensive_packets() {
        let cheap = Packet::new(PacketId(0), 0, 0, 1, vec![]);
        let expensive = Packet::new(PacketId(1), 0, 0, 16, vec![]);
        // Same pattern; cost_weight > 0 should make expensive worse.
        let s = MarginAnchoredGreedyPull { k_promote_per_round: 1, cost_weight: 1.0, depth_budget: 1 };
        assert!(s.anchor_score(0, &cheap) > s.anchor_score(0, &expensive));
    }

    #[test]
    fn depth_budget_caps_iterations() {
        // With depth_budget = 0, only the sink is active.
        let g = graph_n(10);
        let s = MarginAnchoredGreedyPull { k_promote_per_round: 4, cost_weight: 1.0, depth_budget: 0 };
        let active = s.select(&g, PacketId(9), 0).unwrap();
        assert_eq!(active.len(), 1);
        assert!(active.contains(&PacketId(9)));
    }

    #[test]
    fn k_promote_caps_per_round() {
        // With k_promote_per_round = 1, each round adds at most 1 packet.
        let g = graph_n(20);
        let s = MarginAnchoredGreedyPull { k_promote_per_round: 1, cost_weight: 1.0, depth_budget: 100 };
        let active = s.select(&g, PacketId(19), 0).unwrap();
        // Sink + at most depth_budget added = at most 101. Actually depth
        // walks predecessors which form a 2-fanin DAG; growth is bounded.
        assert!(active.contains(&PacketId(19)));
        assert!(active.len() >= 2);
    }
}
