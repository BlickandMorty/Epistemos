//! Phase C pure-data module stress tests at vault-size scale.
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Test harness
//! (4-layer, applies to all phases)" → "Stress tests | Nightly".
//!
//! Companion to `phase_a_stress.rs` + `phase_b_stress.rs`. Closes the
//! stress-coverage arc for the cluster hierarchy + benchmark harness +
//! visibility kernel modules that were scaffolded across earlier
//! iterations of the canonical-plan algorithmic prep.

use graph_engine::cluster_hierarchy::{
    build_hierarchy, build_leaf_clusters, incremental_edge_update,
    CLUSTER_ROOT_PARENT,
};
use graph_engine::benchmark_harness::{
    summarise_results, BenchmarkResult, BenchmarkScenario, meets_phase_target,
};

/// Deterministic xorshift64 PRNG — matches synth_vault.rs.
fn xorshift_step(state: &mut u64) -> u64 {
    let mut x = *state;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    *state = x;
    x
}

fn synthetic_positions(n: usize, seed: u64, world_half: f32) -> (Vec<f32>, Vec<f32>) {
    let mut state = seed.wrapping_mul(0x9E37_79B9_7F4A_7C15).wrapping_add(1);
    let mut px = Vec::with_capacity(n);
    let mut py = Vec::with_capacity(n);
    for _ in 0..n {
        let rx = xorshift_step(&mut state) as f64 / u64::MAX as f64;
        let ry = xorshift_step(&mut state) as f64 / u64::MAX as f64;
        px.push((rx * 2.0 - 1.0) as f32 * world_half);
        py.push((ry * 2.0 - 1.0) as f32 * world_half);
    }
    (px, py)
}

#[test]
fn cluster_hierarchy_stress_5k_nodes() {
    let n = 5_000;
    let world_half = 200.0;
    let (px, py) = synthetic_positions(n, 42, world_half);
    // Assign each node to one of 20 clusters based on x-band, then add
    // some cross-cluster edges to drive Louvain consolidation.
    let assignment: Vec<u32> = px.iter()
        .map(|x| (((x + world_half) / (world_half * 2.0 / 20.0)) as u32).min(19))
        .collect();
    let mut edges: Vec<(u32, u32)> = Vec::new();
    let mut state = 0xC0FFEE_u64;
    for _ in 0..(n / 2) {
        let s = (xorshift_step(&mut state) % n as u64) as u32;
        let t = (xorshift_step(&mut state) % n as u64) as u32;
        if s != t {
            edges.push((s, t));
        }
    }
    let h = build_hierarchy(&px, &py, &assignment, &edges);
    // All centroids finite.
    for cluster in &h.clusters {
        assert!(cluster.centroid_x.is_finite(),
            "cluster {} (level {}) centroid_x not finite", cluster.id, cluster.level);
        assert!(cluster.centroid_y.is_finite(),
            "cluster {} (level {}) centroid_y not finite", cluster.id, cluster.level);
    }
    // node_to_leaf_cluster preserved.
    assert_eq!(h.node_to_leaf_cluster, assignment);
}

#[test]
fn cluster_hierarchy_is_deterministic_at_3k() {
    let n = 3_000;
    let world_half = 100.0;
    let (px, py) = synthetic_positions(n, 7, world_half);
    let assignment: Vec<u32> = (0..n as u32).map(|i| i % 10).collect();
    let edges: Vec<(u32, u32)> = (0..n as u32 - 1).map(|i| (i, i + 1)).collect();
    let a = build_hierarchy(&px, &py, &assignment, &edges);
    let b = build_hierarchy(&px, &py, &assignment, &edges);
    assert_eq!(a, b, "same input → identical hierarchy at 3k");
}

#[test]
fn cluster_hierarchy_handles_one_giant_cluster() {
    // Single cluster of 5000 nodes.
    let n = 5_000;
    let world_half = 100.0;
    let (px, py) = synthetic_positions(n, 11, world_half);
    let assignment: Vec<u32> = vec![0u32; n];
    let h = build_hierarchy(&px, &py, &assignment, &[]);
    // Should stop at level 1 (single cluster).
    assert_eq!(h.clusters.len(), 1);
    assert_eq!(h.clusters[0].member_count, n as u32);
    assert_eq!(h.clusters[0].parent, CLUSTER_ROOT_PARENT);
}

#[test]
fn cluster_hierarchy_handles_all_isolated() {
    // 1000 singleton clusters.
    let n = 1_000;
    let world_half = 100.0;
    let (px, py) = synthetic_positions(n, 13, world_half);
    let assignment: Vec<u32> = (0..n as u32).collect();
    let h = build_hierarchy(&px, &py, &assignment, &[]);
    // 1000 leaf clusters.
    let leaf_count = h.clusters.iter().filter(|c| c.level == 0).count();
    assert_eq!(leaf_count, n);
    for cluster in &h.clusters {
        assert!(cluster.centroid_x.is_finite() && cluster.centroid_y.is_finite());
    }
}

#[test]
fn cluster_hierarchy_incremental_intra_cluster_short_circuits_at_scale() {
    let n = 2_000;
    let world_half = 100.0;
    let (px, py) = synthetic_positions(n, 99, world_half);
    let assignment: Vec<u32> = (0..n as u32).map(|i| i % 10).collect();
    let edges: Vec<(u32, u32)> = (0..n as u32 - 1).map(|i| (i, i + 1)).collect();
    let initial = build_hierarchy(&px, &py, &assignment, &edges);
    // Intra-cluster edge: both endpoints in cluster 5.
    let after = incremental_edge_update(
        initial.clone(),
        (5, 5),
        &px, &py, &assignment, &edges,
    );
    assert_eq!(initial, after, "intra-cluster edge must be a no-op even at 2k");
}

#[test]
fn benchmark_summary_stress_100_results() {
    // 100 BenchmarkResults across mixed scenarios + sizes.
    let mut results: Vec<BenchmarkResult> = Vec::with_capacity(100);
    let scenarios = [
        BenchmarkScenario::ColdOpen,
        BenchmarkScenario::SteadyFpsZoomOut,
        BenchmarkScenario::SteadyFpsZoomIn,
        BenchmarkScenario::DragFps,
        BenchmarkScenario::MemoryResidencyMb,
    ];
    let vault_sizes = [1_000u32, 5_000, 10_000, 50_000, 100_000];
    for i in 0..100 {
        results.push(BenchmarkResult {
            scenario: scenarios[i % scenarios.len()],
            vault_node_count: vault_sizes[i % vault_sizes.len()],
            hardware_tag: "M2Pro16GB".into(),
            build_tag: format!("test-build-{i}"),
            value: 50.0 + (i as f64),
            timestamp_secs: 1_715_000_000 + i as u64,
        });
    }
    let summary = summarise_results(&results);
    assert_eq!(summary.result_count, 100);
    // Every mean is finite.
    for (_, mean) in &summary.mean_by_scenario_and_size {
        assert!(mean.is_finite());
    }
    // meets_phase_target is total over the 100 results without panicking.
    for r in &results {
        let _ = meets_phase_target(r);
    }
}

#[test]
fn build_leaf_clusters_stress_10k_nodes() {
    let n = 10_000;
    let world_half = 100.0;
    let (px, py) = synthetic_positions(n, 21, world_half);
    let assignment: Vec<u32> = (0..n as u32).map(|i| i % 100).collect();
    let records = build_leaf_clusters(&px, &py, &assignment);
    assert_eq!(records.len(), 100);
    for r in &records {
        assert!(r.centroid_x.is_finite());
        assert!(r.centroid_y.is_finite());
        assert!(r.member_count > 0);
    }
}
