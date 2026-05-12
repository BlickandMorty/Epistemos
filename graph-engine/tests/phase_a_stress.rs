//! Phase A pure-data module stress tests at vault-size scale.
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Test harness
//! (4-layer, applies to all phases)" → "Stress tests | Nightly".
//!
//! Companion to `phase_b_stress.rs` — proves the Phase A modules
//! (`warmstart`, `reveal`, `atmosphere`) don't panic / produce NaN at
//! vault-scale inputs. Phase A is the *first-contact* surface for the
//! integrator (warm-start runs once on open; reveal drives the per-frame
//! batch cadence; atmosphere computes per-node wake state every frame),
//! so robustness here matters as much as in Phase B.

use graph_engine::warmstart::{warm_start, reveal_position_from_neighbors, WarmstartInput};
use graph_engine::reveal::{RevealController, RevealConfig, RevealStyle, RevealPhase};
use graph_engine::atmosphere::{
    AtmosphereConfig, AtmosphereNodeInput, WakeState,
    atmosphere_radius, lookahead_frames, compute_step, awake_fraction,
};

/// Deterministic xorshift64 — matches synth_vault.rs.
fn xorshift_step(state: &mut u64) -> u64 {
    let mut x = *state;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    *state = x;
    x
}

fn synthetic_node_ids(n: u32) -> Vec<u32> { (0..n).collect() }

fn synthetic_pkm_edges(n: u32, seed: u64) -> Vec<(u32, u32)> {
    // Power-law-ish preferential-attachment edges. Matches the synth_vault
    // generator's flavour: each new node attaches to ~3 existing nodes
    // biased toward high-degree ones.
    if n < 2 { return Vec::new(); }
    let mut state = seed.wrapping_mul(0xC0FF_EEDE_AD_BE_EFFu64).wrapping_add(1);
    let mut edges: Vec<(u32, u32)> = Vec::new();
    let mut degree: Vec<u32> = vec![1; n as usize];
    for new_node in 1..n {
        // Pick up to 3 distinct earlier nodes weighted by degree.
        let attempt_count = 3.min(new_node);
        for _ in 0..attempt_count {
            let weight_sum: u64 = degree[..new_node as usize].iter().map(|&d| d as u64).sum();
            if weight_sum == 0 { break; }
            let pick_target = (xorshift_step(&mut state) % weight_sum) as i64;
            let mut acc = 0i64;
            for j in 0..new_node {
                acc += degree[j as usize] as i64;
                if acc > pick_target {
                    if j != new_node {
                        edges.push((j, new_node));
                        degree[j as usize] += 1;
                        degree[new_node as usize] += 1;
                    }
                    break;
                }
            }
        }
    }
    edges
}

#[test]
fn warmstart_stress_10k_nodes() {
    let n = 10_000;
    let nodes = synthetic_node_ids(n);
    let edges = synthetic_pkm_edges(n, 42);
    let result = warm_start(WarmstartInput {
        node_ids: &nodes,
        edges: &edges,
        world_half: 200.0,
        seed: 42,
    });
    assert_eq!(result.positions.len(), n as usize);
    // Every position must be finite + inside the world box.
    for (id, p) in &result.positions {
        assert!(p[0].is_finite() && p[1].is_finite(),
            "warmstart pos[{id}] = ({}, {}) not finite", p[0], p[1]);
        assert!(p[0].abs() <= 201.0 && p[1].abs() <= 201.0,
            "warmstart pos[{id}] = ({}, {}) escaped world box", p[0], p[1]);
    }
    // At least one component (likely 1 because of preferential attachment).
    assert!(result.component_count >= 1);
}

#[test]
fn warmstart_is_deterministic_at_5k() {
    let n = 5_000;
    let nodes = synthetic_node_ids(n);
    let edges = synthetic_pkm_edges(n, 7);
    let a = warm_start(WarmstartInput {
        node_ids: &nodes, edges: &edges, world_half: 200.0, seed: 1234
    });
    let b = warm_start(WarmstartInput {
        node_ids: &nodes, edges: &edges, world_half: 200.0, seed: 1234
    });
    assert_eq!(a, b, "same input + seed → bit-identical at 5k");
}

#[test]
fn reveal_controller_full_walk_at_10k_finishes_in_bounded_frames() {
    let mut c = RevealController::new(10_000, RevealConfig {
        fps: 60.0, user_duration_scale: 1.0, style: RevealStyle::Chronological,
    });
    c.start();
    let mut iterations = 0u32;
    // A 10k chronological reveal at 60fps with default scale:
    //   T_reveal = clamp(1.2 + 1.1*sqrt(10000/5000), 1.2, 9.0) ≈ 2.76s → 166 frames
    //   plus settle_frames ≤ 5*60 = 300
    // So at most ~600 ticks should fully drive Idle → Seeding → Ramping → Settling → Steady.
    while c.phase() != RevealPhase::Steady && iterations < 10_000 {
        c.tick();
        iterations += 1;
    }
    assert_eq!(c.phase(), RevealPhase::Steady,
        "reveal controller must reach Steady within iteration budget; got {} ticks",
        iterations);
    assert!(iterations < 5_000, "reveal at 10k should not need more than 5k frames, got {}", iterations);
    assert_eq!(c.next_unrevealed(), 10_000);
}

#[test]
fn reveal_all_at_once_stress() {
    let mut c = RevealController::new(50_000, RevealConfig {
        fps: 60.0, user_duration_scale: 1.0, style: RevealStyle::AllAtOnce,
    });
    c.start();
    let seed_step = c.tick();
    // Single drop frame.
    assert_eq!(seed_step.batch_start, 0);
    assert_eq!(seed_step.batch_end, 50_000);
    assert!(seed_step.alpha > 0.0 && seed_step.alpha.is_finite());
    // Settle takes some frames.
    let mut count = 1u32;
    while c.phase() != RevealPhase::Steady && count < 5_000 {
        c.tick();
        count += 1;
    }
    assert_eq!(c.phase(), RevealPhase::Steady);
}

#[test]
fn atmosphere_compute_step_stress_10k_nodes() {
    let cfg = AtmosphereConfig::default();
    let mut state = 0xDEAD_BEEFu64;
    let n = 10_000;
    let mut nodes: Vec<AtmosphereNodeInput> = Vec::with_capacity(n);
    for i in 0..n {
        let _r0 = xorshift_step(&mut state); // burn for diversity
        let x = ((xorshift_step(&mut state) >> 32) as i32 as f32) / (i32::MAX as f32) * 100.0;
        let y = ((xorshift_step(&mut state) >> 32) as i32 as f32) / (i32::MAX as f32) * 100.0;
        nodes.push(AtmosphereNodeInput {
            id: i as u32,
            x, y,
            vx: 0.1, vy: 0.0,
            radius: 1.0,
            median_incident_rest_length: 10.0,
            heat: 0.0,
            state: WakeState::Sleeping,
        });
    }
    // Every step must produce a finite radius and a valid wake_to enum.
    for node in &nodes {
        let step = compute_step(node, &cfg, 5.0, 50.0, false);
        assert!(step.radius.is_finite(), "atmosphere radius for node {} not finite: {}",
            node.id, step.radius);
        assert!(step.dt_factor.is_finite() && (0.0..=1.0).contains(&step.dt_factor));
        assert!(step.force_factor.is_finite() && (0.0..=1.0).contains(&step.force_factor));
    }
}

#[test]
fn atmosphere_awake_fraction_stress_50k() {
    // 50k mixed wake states. Awake-fraction summary must be O(N) + finite.
    let mut states: Vec<WakeState> = Vec::with_capacity(50_000);
    for i in 0..50_000 {
        states.push(match i % 5 {
            0 | 1 => WakeState::Sleeping,
            2 => WakeState::Warming,
            _ => WakeState::Awake,
        });
    }
    let snap = awake_fraction(&states);
    assert_eq!(snap.awake + snap.warming + snap.sleeping, 50_000);
    assert!(snap.fraction_awake_or_warming.is_finite());
    // 3/5 = 0.6 awake-or-warming.
    assert!((snap.fraction_awake_or_warming - 0.6).abs() < 0.01,
        "expected ~0.6 awake fraction in 3/5-mixed fixture, got {}",
        snap.fraction_awake_or_warming);
}

#[test]
fn warmstart_handles_disconnected_components_at_scale() {
    // Two disjoint cliques + 100 isolated nodes.
    let mut nodes: Vec<u32> = (0..200).collect();
    nodes.extend(300..400); // gap from 200-299 left empty
    nodes.extend(500..600); // another gap
    let mut edges: Vec<(u32, u32)> = Vec::new();
    // Clique 0: nodes 0-50, fully connected
    for i in 0..50 {
        for j in (i + 1)..50 {
            edges.push((i, j));
        }
    }
    // Clique 1: nodes 300-350, fully connected
    for i in 300..350 {
        for j in (i + 1)..350 {
            edges.push((i, j));
        }
    }
    // Isolated nodes: 500-600 (no edges)
    let result = warm_start(WarmstartInput {
        node_ids: &nodes, edges: &edges, world_half: 200.0, seed: 99,
    });
    assert!(result.component_count >= 2, "must detect at least 2 components, got {}",
        result.component_count);
    // All positions finite.
    for (_, p) in &result.positions {
        assert!(p[0].is_finite() && p[1].is_finite());
    }
}

#[test]
fn reveal_position_centroid_stress_many_neighbors() {
    // 1000 neighbours weighted uniformly — centroid should be close to mean.
    let positions: Vec<[f32; 2]> = (0..1000).map(|i| [i as f32, 0.0]).collect();
    let weights = vec![1.0_f32; 1000];
    let centroid = reveal_position_from_neighbors(&positions, &weights, 42)
        .expect("centroid for non-empty input");
    // Mean is 499.5 in x. Allow jitter window.
    assert!((centroid[0] - 499.5).abs() < 1.0,
        "1000-neighbour centroid should be near mean, got {}", centroid[0]);
    assert!(centroid[0].is_finite() && centroid[1].is_finite());
}

#[test]
fn atmosphere_lookahead_safe_under_extreme_velocity() {
    let cfg = AtmosphereConfig::default();
    // Extreme velocity — should still clamp lookahead to 12.
    let n = AtmosphereNodeInput {
        id: 1, x: 0.0, y: 0.0, vx: 1e10, vy: 1e10,
        radius: 1.0,
        median_incident_rest_length: 10.0,
        heat: 0.0,
        state: WakeState::Awake,
    };
    let look = lookahead_frames(&n, &cfg);
    assert!((3..=12).contains(&look),
        "lookahead must clamp to [3,12] under extreme velocity, got {}", look);
    let r = atmosphere_radius(&n, &cfg, look);
    assert!(r.is_finite(), "atmosphere radius must be finite even under extreme v, got {}", r);
}
