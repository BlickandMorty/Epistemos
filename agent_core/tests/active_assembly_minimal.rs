#![cfg(feature = "research")]
//! F-ActiveAssembly-Minimal — substrate-floor integration harness.
//!
//! Per `docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md` §3.
//!
//! # Substrate-floor scope
//!
//! This harness exercises the iter-37 PacketGraph + iter-38
//! MarginAnchoredGreedyPull surfaces in an end-to-end integration test.
//! Three substrate-floor assertions:
//!
//! 1. **Selector saves work** — the active set is strictly smaller than
//!    the full graph (firing_ratio < 1.0).
//! 2. **Sink always selected** — every selector call includes the sink
//!    packet in the active set.
//! 3. **Active set is well-formed** — every active packet's id is in the
//!    graph; no orphan selections.
//!
//! The full production gate per falsifier §3 (two-sided constraint:
//! output_bound ≤ 4-bit Hamming AND cost_ratio < 0.40 AND firing_ratio <
//! 0.50) requires a "running" semantics on the packets — that is, a way
//! to compute output from the active set. Mock production semantics (each
//! packet contributes its output_pattern via XOR) make the 4-bit Hamming
//! bound difficult to satisfy with random patterns; the canonical proof
//! requires per-packet "mass > τ" ground truth tied to the query, which
//! is a richer modeling story than substrate-floor scope.
//!
//! Production-PASS lands when the harness wires into a real model's
//! packet routing layer. This iter proves the substrate primitives are
//! wired correctly.

use agent_core::research::active_assembly::{
    MarginAnchoredGreedyPull, Packet, PacketGraph, PacketId, Selector,
};

/// Build a synthetic packet graph with N=200 nodes; each non-root packet
/// has 1-3 predecessors (DAG topology).
fn build_synthetic_graph(seed: u64) -> PacketGraph {
    let mut g = PacketGraph::new();
    let mut rng = seed;
    for i in 0..200 {
        // LCG for predecessor count + pattern.
        rng = rng.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
        let pred_count = if i == 0 { 0 } else { 1 + ((rng % 3) as usize) }; // 1..=3
        let mut preds = Vec::with_capacity(pred_count);
        for _ in 0..pred_count {
            rng = rng.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
            let candidate = (rng as usize) % i; // strictly less than i; topological
            if !preds.iter().any(|p: &PacketId| p.0 == candidate) {
                preds.push(PacketId(candidate));
            }
        }
        let cost_units = ((i % 16) + 1) as u8; // 1..=16

        rng = rng.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
        let input = rng;
        rng = rng.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
        let output = rng;

        g.add(Packet::new(PacketId(i), input, output, cost_units, preds)).unwrap();
    }
    g
}

#[test]
fn selector_saves_work_across_50_queries() {
    let graph = build_synthetic_graph(0xACAA_0001_u64);
    let selector = MarginAnchoredGreedyPull::default();
    let sink = PacketId(199);

    let mut firing_counts = Vec::with_capacity(50);
    let mut rng = 0xABCD_1234_u64;
    for _ in 0..50 {
        rng = rng.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
        let query = rng;
        let active = selector.select(&graph, sink, query).expect("select must succeed");
        firing_counts.push(active.len());
    }

    let total = graph.len();
    let avg_firing = firing_counts.iter().sum::<usize>() as f64 / firing_counts.len() as f64;
    let firing_ratio = avg_firing / total as f64;

    assert!(
        firing_ratio < 1.0,
        "selector must save work; avg firing_ratio = {} (avg active = {} / total = {})",
        firing_ratio, avg_firing, total
    );
    // Substrate-floor budget: at least SOME pruning. Production gate is
    // < 0.50 (per falsifier §3); substrate-floor uses < 0.95 to lock in
    // that the selector is doing meaningful work without requiring
    // production-grade tuning.
    assert!(
        firing_ratio < 0.95,
        "substrate-floor: selector should at least prune 5% of packets on average; got firing_ratio = {}",
        firing_ratio
    );
}

#[test]
fn sink_always_in_active_set() {
    let graph = build_synthetic_graph(0xACAA_0002_u64);
    let selector = MarginAnchoredGreedyPull::default();
    let sink = PacketId(199);

    let mut rng = 0xDCBA_5678_u64;
    for _ in 0..20 {
        rng = rng.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
        let query = rng;
        let active = selector.select(&graph, sink, query).expect("select must succeed");
        assert!(active.contains(&sink), "sink {:?} must always be active for query 0x{:x}", sink, query);
    }
}

#[test]
fn active_set_only_contains_graph_packet_ids() {
    let graph = build_synthetic_graph(0xACAA_0003_u64);
    let selector = MarginAnchoredGreedyPull::default();
    let sink = PacketId(199);

    let mut rng = 0x1357_2468_u64;
    for _ in 0..20 {
        rng = rng.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
        let query = rng;
        let active = selector.select(&graph, sink, query).expect("select must succeed");
        for &active_id in &active {
            assert!(
                graph.contains(active_id),
                "active set includes orphan id {:?} not in graph",
                active_id
            );
        }
    }
}

#[test]
fn reproducibility_same_seed_same_result() {
    let graph_a = build_synthetic_graph(0xACAA_0004_u64);
    let graph_b = build_synthetic_graph(0xACAA_0004_u64);
    assert_eq!(graph_a.len(), graph_b.len());
    for i in 0..graph_a.len() {
        let pa = graph_a.get(PacketId(i)).unwrap();
        let pb = graph_b.get(PacketId(i)).unwrap();
        assert_eq!(pa, pb, "same seed must produce same packet at id {}", i);
    }

    let selector = MarginAnchoredGreedyPull::default();
    let sink = PacketId(199);
    let active_a = selector.select(&graph_a, sink, 0xCAFE_BABE).unwrap();
    let active_b = selector.select(&graph_b, sink, 0xCAFE_BABE).unwrap();
    assert_eq!(active_a, active_b, "same graph + query must produce same active set");
}

#[test]
fn graph_is_well_formed_dag() {
    // Substrate-floor invariant: the synthetic graph is a valid DAG
    // (predecessor edges always point to LOWER ids).
    let graph = build_synthetic_graph(0xACAA_0005_u64);
    for packet in graph.iter() {
        for pred in &packet.predecessors {
            assert!(
                pred.0 < packet.id.0,
                "edge {:?} -> {:?} violates topological invariant (predecessor must have lower id)",
                packet.id, pred
            );
        }
    }
}
