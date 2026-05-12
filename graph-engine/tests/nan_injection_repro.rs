//! Deterministic NaN/Inf injection repro per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md`
//! §"Failure cases to make deterministically reproducible":
//!
//!   - Inject NaN/Inf into integration scratch and verify the kernel
//!     quarantines bad state instead of propagating
//!
//! Earlier iterations added quarantine guards across spring_forces +
//! repulsion + cell_reduce + integrate + atmosphere + visibility kernels
//! and stress-tested each at 10k nodes. This file closes the canonical
//! plan's *named* failure-case repro by chaining all four force kernels
//! with explicit NaN injection into different stages and asserting that
//! the final position vector survives.
//!
//! ## Why a separate file
//!
//! The stress harnesses prove the kernels handle their own outputs
//! cleanly. This repro proves the kernels handle an **upstream** kernel
//! producing bad output — the propagation guard, not just the
//! recovery guard.

use graph_engine::force_kernels::{
    build_undirected_csr, integrate_kernel, spring_forces_kernel, UndirectedCsr,
};
use graph_engine::grid_kernels::{
    cell_reduce_kernel, grid_build_kernel, grid_scan_kernel, grid_scatter_kernel,
    repulsion_kernel, UniformGridConfig,
};

#[test]
fn nan_injected_into_position_buffer_is_quarantined_through_full_pipeline() {
    let n = 100;
    let world_half = 50.0;

    // Build a small chain graph.
    let mut pos_x: Vec<f32> = (0..n).map(|i| (i as f32) * 0.3 - 15.0).collect();
    let mut pos_y: Vec<f32> = vec![0.0; n];

    // Explicitly inject NaN into node 42's position — the canonical
    // failure mode this test reproduces.
    pos_x[42] = f32::NAN;
    pos_y[42] = f32::INFINITY;

    let edges: Vec<(u32, u32)> = (0..n as u32 - 1).map(|i| (i, i + 1)).collect();
    let (head, neighbours) = build_undirected_csr(n as u32, &edges);
    let csr = UndirectedCsr { head: &head, neighbours: &neighbours };

    let rest = vec![30.0_f32; edges.len()];
    let weight = vec![1.0_f32; edges.len()];
    let mut spring_fx = vec![0.0_f32; n];
    let mut spring_fy = vec![0.0_f32; n];

    // Stage 1: spring forces consume the NaN position. Output must be finite.
    spring_forces_kernel(
        &pos_x, &pos_y, &csr,
        &rest, &weight,
        &mut spring_fx, &mut spring_fy,
        1.0, 30.0,
    );
    for (i, f) in spring_fx.iter().chain(spring_fy.iter()).enumerate() {
        assert!(f.is_finite(),
            "STAGE 1 (spring) leaked NaN at offset {i}: {f}");
    }

    // Stage 2: grid pipeline. NaN position in node 42 should not poison
    // the grid build / centroid pipeline.
    let cfg = UniformGridConfig { world_half, cells_per_axis: 8 };
    let (cell_of_node, counts) = grid_build_kernel(&pos_x, &pos_y, &cfg);
    let scan = grid_scan_kernel(&counts);
    let scatter = grid_scatter_kernel(&cell_of_node, &scan);
    let aggregates = cell_reduce_kernel(&pos_x, &pos_y, &scatter, &scan);
    // All centroids finite even though one member is NaN.
    for (i, a) in aggregates.iter().enumerate() {
        assert!(a.centre_x.is_finite() && a.centre_y.is_finite(),
            "STAGE 2 (cell_reduce) leaked NaN at cell {i}: ({}, {})",
            a.centre_x, a.centre_y);
    }

    // Stage 3: repulsion kernel reads positions + aggregates. Must produce
    // finite forces.
    let mut repulse_fx = vec![0.0_f32; n];
    let mut repulse_fy = vec![0.0_f32; n];
    repulsion_kernel(
        &pos_x, &pos_y, &cell_of_node, &scatter, &scan, &aggregates,
        &cfg, &mut repulse_fx, &mut repulse_fy, 50.0, 1,
    );
    for (i, f) in repulse_fx.iter().chain(repulse_fy.iter()).enumerate() {
        assert!(f.is_finite(),
            "STAGE 3 (repulsion) leaked NaN at offset {i}: {f}");
    }

    // Stage 4: integrate consumes both spring + repulsion. The integrator's
    // pre-update stash + post-update snap-back must keep node 42's position
    // finite — by snapping it back to the prior frame (which was NaN/Inf,
    // so the integrator's defensive fallback to (0, 0) kicks in).
    let mut total_fx: Vec<f32> = (0..n).map(|i| spring_fx[i] + repulse_fx[i]).collect();
    let mut total_fy: Vec<f32> = (0..n).map(|i| spring_fy[i] + repulse_fy[i]).collect();
    // Also inject NaN/Inf directly into the force buffers for stage 4.
    total_fx[7] = f32::NAN;
    total_fy[55] = f32::INFINITY;

    let mut vx = vec![0.0_f32; n];
    let mut vy = vec![0.0_f32; n];
    let flags = vec![1u32 << 1; n]; // all AWAKE
    let dt_factors = vec![1.0_f32; n];
    let force_factors = vec![1.0_f32; n];
    integrate_kernel(
        &mut pos_x, &mut pos_y, &mut vx, &mut vy,
        &total_fx, &total_fy, &flags,
        1.0 / 60.0, &dt_factors, &force_factors, 0.95,
    );

    // Every position MUST be finite after the integrator quarantines bad state.
    for i in 0..n {
        assert!(pos_x[i].is_finite(),
            "STAGE 4 (integrate) leaked NaN at node {i} pos_x = {}", pos_x[i]);
        assert!(pos_y[i].is_finite(),
            "STAGE 4 (integrate) leaked NaN at node {i} pos_y = {}", pos_y[i]);
        assert!(vx[i].is_finite() && vy[i].is_finite(),
            "STAGE 4 (integrate) leaked NaN velocity at node {i}: ({}, {})",
            vx[i], vy[i]);
    }

    // The originally-NaN node 42 should now be at (0, 0) — the integrator's
    // defensive fallback when both prior position and current proposal are
    // non-finite. Other nodes should have advanced normally.
    assert_eq!(pos_x[42], 0.0, "node 42 should snap to defensive default (0,0)");
    assert_eq!(pos_y[42], 0.0);
}

#[test]
fn inf_injected_into_force_buffer_is_quarantined() {
    // Smaller targeted repro: just the integrate step with a single Inf force.
    let n = 10;
    let mut pos_x: Vec<f32> = (0..n).map(|i| i as f32).collect();
    let mut pos_y: Vec<f32> = vec![5.0; n];
    let mut vx = vec![0.0_f32; n];
    let mut vy = vec![0.0_f32; n];
    let mut fx = vec![1.0_f32; n];
    let mut fy = vec![1.0_f32; n];
    fx[5] = f32::INFINITY;
    fy[5] = f32::NEG_INFINITY;
    let flags = vec![1u32 << 1; n];

    let pre_pos_x_5 = pos_x[5];
    let pre_pos_y_5 = pos_y[5];

    integrate_kernel(
        &mut pos_x, &mut pos_y, &mut vx, &mut vy,
        &fx, &fy, &flags,
        0.1, &[1.0; 10], &[1.0; 10], 1.0,
    );

    // Node 5 should be snapped back to its pre-update position.
    assert_eq!(pos_x[5], pre_pos_x_5,
        "node 5 should snap-back to prior position on Inf force");
    assert_eq!(pos_y[5], pre_pos_y_5);
    assert_eq!(vx[5], 0.0, "velocity zeroed");
    assert_eq!(vy[5], 0.0);

    // Other nodes advanced normally.
    for i in 0..n {
        if i == 5 { continue; }
        assert!(pos_x[i].is_finite());
        assert!(pos_y[i].is_finite());
    }
}

#[test]
fn nan_injection_across_30_frame_loop_does_not_propagate() {
    // The most thorough repro: 30 frames of integration where NaN is
    // injected ONCE at frame 0, and we verify every subsequent frame is
    // clean (no propagation).
    let n = 50;
    let mut pos_x: Vec<f32> = (0..n).map(|i| i as f32 * 2.0 - 50.0).collect();
    let mut pos_y: Vec<f32> = vec![0.0; n];
    let mut vx = vec![0.0_f32; n];
    let mut vy = vec![0.0_f32; n];

    // Inject NaN at frame 0.
    pos_x[10] = f32::NAN;
    pos_y[20] = f32::INFINITY;

    let edges: Vec<(u32, u32)> = (0..n as u32 - 1).map(|i| (i, i + 1)).collect();
    let (head, neighbours) = build_undirected_csr(n as u32, &edges);
    let csr = UndirectedCsr { head: &head, neighbours: &neighbours };

    for frame in 0..30 {
        let rest = vec![30.0_f32; edges.len()];
        let weight = vec![1.0_f32; edges.len()];
        let mut sfx = vec![0.0_f32; n];
        let mut sfy = vec![0.0_f32; n];
        spring_forces_kernel(&pos_x, &pos_y, &csr, &rest, &weight, &mut sfx, &mut sfy, 0.5, 30.0);

        let flags = vec![1u32 << 1; n];
        let dt_factors = vec![1.0_f32; n];
        let force_factors = vec![1.0_f32; n];
        integrate_kernel(
            &mut pos_x, &mut pos_y, &mut vx, &mut vy,
            &sfx, &sfy, &flags,
            1.0 / 60.0, &dt_factors, &force_factors, 0.95,
        );

        // After frame 0 the NaN should be cleared and never reappear.
        for i in 0..n {
            assert!(pos_x[i].is_finite() && pos_y[i].is_finite(),
                "frame {frame} node {i} position not finite: ({}, {})",
                pos_x[i], pos_y[i]);
        }
    }
}
