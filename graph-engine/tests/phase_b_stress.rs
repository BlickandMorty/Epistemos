//! Phase B kernel-reference stress tests at vault-size scale.
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Test harness
//! (4-layer, applies to all phases)" → "Stress tests | Nightly | 10k-100k
//! synthetic graphs, random topology diffs, forced reveal bursts, no
//! write-after-read hazards under load, no NaN propagation, no buffer
//! overrun".
//!
//! The kernel unit tests already prove correctness on small fixtures
//! (1-100 nodes). This file proves the kernels don't panic / blow up /
//! produce NaN on vault-scale inputs.
//!
//! The "nightly" cadence in the plan means these aren't gated on every
//! `cargo test --lib`; running this file is part of the integration
//! suite (`cargo test --test phase_b_stress`).
//!
//! ## Why pure data
//!
//! These run the same modules as the unit tests, just at a 100× input
//! scale. No engine dependencies; no Metal device required.

use graph_engine::force_kernels::{
    build_undirected_csr, integrate_kernel, spring_forces_kernel, UndirectedCsr,
};
use graph_engine::grid_kernels::{
    cell_reduce_kernel, grid_build_kernel, grid_scan_kernel, grid_scatter_kernel,
    repulsion_kernel, UniformGridConfig,
};
use graph_engine::adaptive_kernels::{
    fa2_swing_traction, fa2_global_speed, sleep_update_kernel, k_frame_threshold,
};
use graph_engine::visibility_kernels::{
    frustum_cull_nodes, frustum_cull_edges, Frustum2D,
};

/// Deterministic xorshift64 for the stress fixtures — matches the
/// pattern in `agent_core/src/bin/synth_vault.rs` so the corpora are
/// directly comparable.
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

fn synthetic_chain_with_skip_links(n: u32, skip: u32) -> Vec<(u32, u32)> {
    // Chain edges + occasional long-range "skip" links so the topology has
    // both local and long-tail structure.
    let mut edges: Vec<(u32, u32)> = Vec::new();
    for i in 0..n.saturating_sub(1) {
        edges.push((i, i + 1));
    }
    let mut i = 0u32;
    while i + skip < n {
        edges.push((i, i + skip));
        i += skip / 2;
    }
    edges
}

#[test]
fn spring_forces_kernel_stress_10k_nodes() {
    let n = 10_000;
    let world_half = 200.0;
    let (px, py) = synthetic_positions(n, 42, world_half);
    let edges = synthetic_chain_with_skip_links(n as u32, 64);
    let (head, neighbours) = build_undirected_csr(n as u32, &edges);
    let csr = UndirectedCsr { head: &head, neighbours: &neighbours };

    let edge_count = edges.len();
    let rest = vec![30.0_f32; edge_count];
    let weight = vec![1.0_f32; edge_count];
    let mut fx = vec![0.0_f32; n];
    let mut fy = vec![0.0_f32; n];

    spring_forces_kernel(&px, &py, &csr, &rest, &weight, &mut fx, &mut fy, 0.5, 30.0);

    // All outputs must be finite — the NaN/Inf quarantine catches any
    // upstream corruption.
    for (i, f) in fx.iter().enumerate() {
        assert!(f.is_finite(), "spring fx[{i}] = {f} is not finite at 10k stress");
    }
    for (i, f) in fy.iter().enumerate() {
        assert!(f.is_finite(), "spring fy[{i}] = {f} is not finite at 10k stress");
    }
}

#[test]
fn grid_pipeline_stress_10k_nodes() {
    let n = 10_000;
    let world_half = 200.0;
    let (px, py) = synthetic_positions(n, 7, world_half);
    let cfg = UniformGridConfig { world_half, cells_per_axis: 32 };

    let (cell_of_node, counts) = grid_build_kernel(&px, &py, &cfg);
    let scan = grid_scan_kernel(&counts);
    let scatter = grid_scatter_kernel(&cell_of_node, &scan);
    let aggregates = cell_reduce_kernel(&px, &py, &scatter, &scan);

    // Sanity: scatter length == total counts; mass sums match.
    assert_eq!(scatter.len() as u32, counts.iter().sum::<u32>());
    let mass_total: u32 = aggregates.iter().map(|a| a.mass).sum();
    assert!(mass_total <= n as u32, "mass total {} ≤ node count {}", mass_total, n);

    let mut fx = vec![0.0_f32; n];
    let mut fy = vec![0.0_f32; n];
    repulsion_kernel(
        &px, &py, &cell_of_node, &scatter, &scan, &aggregates,
        &cfg, &mut fx, &mut fy, 50.0, 1,
    );

    for (i, f) in fx.iter().chain(fy.iter()).enumerate() {
        assert!(f.is_finite(), "repulsion[{i}] = {f} is not finite at 10k stress");
    }
}

#[test]
fn integrate_kernel_stress_10k_nodes_one_frame() {
    let n = 10_000;
    let world_half = 200.0;
    let (mut px, mut py) = synthetic_positions(n, 99, world_half);
    let mut vx = vec![0.0_f32; n];
    let mut vy = vec![0.0_f32; n];
    let fx = vec![1.0_f32; n];
    let fy = vec![0.5_f32; n];
    let flags = vec![1u32 << 1; n]; // all AWAKE
    let dt_factors = vec![1.0_f32; n];
    let force_factors = vec![1.0_f32; n];

    integrate_kernel(
        &mut px, &mut py, &mut vx, &mut vy,
        &fx, &fy, &flags,
        1.0 / 60.0, &dt_factors, &force_factors, 0.95,
    );

    for (i, p) in px.iter().chain(py.iter()).enumerate() {
        assert!(p.is_finite(), "integrator output[{i}] = {p} is not finite");
    }
}

#[test]
fn fa2_stress_10k_nodes() {
    let n = 10_000;
    let mut fx = vec![0.0_f32; n];
    let mut fy = vec![0.0_f32; n];
    for i in 0..n {
        fx[i] = (i as f32 * 0.1).sin();
        fy[i] = (i as f32 * 0.13).cos();
    }
    let prev_fx = fx.iter().map(|x| x * 0.9).collect::<Vec<_>>();
    let prev_fy = fy.iter().map(|y| y * 0.9).collect::<Vec<_>>();

    let (swing, traction) = fa2_swing_traction(&fx, &fy, &prev_fx, &prev_fy);
    assert!(swing.is_finite() && swing >= 0.0);
    assert!(traction.is_finite() && traction >= 0.0);
    let speed = fa2_global_speed(swing, traction, n, 1.0);
    assert!(speed.is_finite() && speed >= 0.0,
        "FA2 global speed must be finite + non-negative, got {}", speed);
}

#[test]
fn sleep_update_stress_10k_nodes() {
    let n = 10_000;
    // Mix calm + moving nodes.
    let mut vx = vec![0.0_f32; n];
    let mut vy = vec![0.0_f32; n];
    for i in (0..n).step_by(3) {
        vx[i] = 1.0;
        vy[i] = 1.0;
    }
    let mut counts = vec![0u32; n];
    let mut propose = vec![false; n];
    sleep_update_kernel(&vx, &vy, &mut counts, &mut propose, k_frame_threshold(60.0));
    let calm_count = counts.iter().filter(|&&c| c == 1).count();
    let moving_count = counts.iter().filter(|&&c| c == 0).count();
    assert_eq!(calm_count + moving_count, n);
    // Roughly 2/3 calm in this fixture.
    assert!(calm_count > moving_count,
        "expected more calm than moving in 1/3-moving fixture: calm={} moving={}",
        calm_count, moving_count);
}

#[test]
fn frustum_cull_stress_10k_nodes() {
    let n = 10_000;
    let world_half = 200.0;
    let (px, py) = synthetic_positions(n, 13, world_half);
    let radii = vec![1.0_f32; n];
    let flags = vec![1u32; n]; // all RENDERABLE
    let frustum = Frustum2D::from_centre_and_half(0.0, 0.0, 50.0, 50.0);

    let visible_nodes = frustum_cull_nodes(&px, &py, &radii, &flags, &frustum);
    // Roughly (100/400)² = 6.25% of the world is in the frustum.
    let frac = visible_nodes.len() as f32 / n as f32;
    assert!(frac > 0.02 && frac < 0.20,
        "frustum 50×50 / 400×400 world should cull to ~6%, got {:.2}% ({} nodes)",
        frac * 100.0, visible_nodes.len());

    // Edge cull stress.
    let edges = synthetic_chain_with_skip_links(n as u32, 32);
    let visible_set: std::collections::BTreeSet<u32> = visible_nodes.iter().copied().collect();
    let visible_edges = frustum_cull_edges(&edges, &visible_set);
    assert!(visible_edges.len() <= edges.len());
}

#[test]
fn end_to_end_phase_b_kernel_pipeline_stress_5k() {
    // Run the full pipeline end-to-end: build CSR → spring → grid → repulsion → integrate.
    let n = 5_000;
    let world_half = 100.0;
    let (mut px, mut py) = synthetic_positions(n, 314, world_half);
    let edges = synthetic_chain_with_skip_links(n as u32, 16);
    let (head, neighbours) = build_undirected_csr(n as u32, &edges);
    let csr = UndirectedCsr { head: &head, neighbours: &neighbours };

    let mut vx = vec![0.0_f32; n];
    let mut vy = vec![0.0_f32; n];
    let flags = vec![1u32 << 1; n];

    // 30-frame loop, mirroring what the integrator will drive.
    for frame in 0..30 {
        let rest = vec![30.0_f32; edges.len()];
        let weight = vec![1.0_f32; edges.len()];
        let mut spring_fx = vec![0.0_f32; n];
        let mut spring_fy = vec![0.0_f32; n];
        spring_forces_kernel(&px, &py, &csr, &rest, &weight, &mut spring_fx, &mut spring_fy, 0.3, 30.0);

        let cfg = UniformGridConfig { world_half, cells_per_axis: 16 };
        let (cell_of_node, counts) = grid_build_kernel(&px, &py, &cfg);
        let scan = grid_scan_kernel(&counts);
        let scatter = grid_scatter_kernel(&cell_of_node, &scan);
        let aggregates = cell_reduce_kernel(&px, &py, &scatter, &scan);

        let mut repulse_fx = vec![0.0_f32; n];
        let mut repulse_fy = vec![0.0_f32; n];
        repulsion_kernel(
            &px, &py, &cell_of_node, &scatter, &scan, &aggregates,
            &cfg, &mut repulse_fx, &mut repulse_fy, 20.0, 1,
        );

        let mut total_fx = vec![0.0_f32; n];
        let mut total_fy = vec![0.0_f32; n];
        for i in 0..n {
            total_fx[i] = spring_fx[i] + repulse_fx[i];
            total_fy[i] = spring_fy[i] + repulse_fy[i];
        }
        let dt_factors = vec![1.0_f32; n];
        let force_factors = vec![1.0_f32; n];
        integrate_kernel(
            &mut px, &mut py, &mut vx, &mut vy,
            &total_fx, &total_fy, &flags,
            1.0 / 60.0, &dt_factors, &force_factors, 0.95,
        );

        // Per-frame finiteness assertion — proves no NaN propagates.
        for (i, p) in px.iter().chain(py.iter()).enumerate() {
            assert!(p.is_finite(),
                "frame {frame} position[{i}] = {p} is not finite — quarantine failed");
        }
    }
}
