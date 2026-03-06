# Living Graph Behavior — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add autonomous aquarium-like behavior to graph nodes — Perlin wander, sinusoidal breathing, damped parent-child tethering, and cursor curiosity/avoidance — as force #9 in the existing physics pipeline.

**Architecture:** A single `force_behavior()` function in `forces.rs` applies four sub-forces (wander, breathe, tether, cursor) per tick. It reads per-node `BehaviorNode` state stored in `Simulation` (SoA pattern, same as existing `x/y/vx/vy`). A `behavior_alpha` field stays warm at 0.15 so behavior continues even when the main physics alpha decays to floor. FSM transitions happen inline. No new threads, no new FFI, no Swift changes.

**Tech Stack:** Rust (graph-engine crate), inline Perlin noise, f32 math

**Design Doc:** `docs/plans/2026-03-06-living-graph-behavior-design.md`

---

## Context for Implementer

### How the physics pipeline works

The main physics runs on a dedicated thread in `Simulation::tick()` (`simulation.rs:560`). Each tick:
1. Alpha decay → settled check (early return if settled)
2. Forces: link → torsion → many-body → collide → center → cluster → semantic → wind → orbital → fluid
3. Velocity Verlet integration (`vx *= decay; x += vx`)

Forces operate on flat `&[f32]` slices (`self.x`, `self.y`, `self.vx`, `self.vy`). Fixed nodes use `self.fx`/`self.fy` (`Option<f32>`). All force functions live in `forces.rs`.

### Key insight: behavior must bypass the settled early return

When `is_settled == true` (alpha at floor, no dragged nodes), `tick()` zeros velocities and returns at line 589-594. Behavior needs to keep running. The solution: a separate `behavior_alpha` that never drops below 0.15. Before the settled early return, we call `force_behavior()` using `behavior_alpha` as the effective alpha.

### Parent-child relationships

Edge type 1 = "contains" = parent-child. During `load_from_graph()`, we scan edges to build `parent_sim_idx: Option<usize>` per behavior node. Depth comes from traversing the parent chain.

### Cursor position

`Engine::mouse_moved()` converts screen→world coordinates. Currently doesn't store them persistently. We add `cursor_world_x/y` and `cursor_speed` fields to `Simulation`, written from `Engine::mouse_moved()`.

### What NOT to touch

- All 8 existing force functions — untouched
- Renderer / Metal — untouched (breathe modulates `transform.scale` via existing per-instance data)
- Swift code — untouched (cursor already flows via `graph_engine_mouse_moved` FFI)
- FFI boundary — no new functions
- ECS `World` / `ecs/components.rs` — AIComponent exists but behavior data lives in Simulation for v1
- `ForceParams` — no new user-facing sliders

---

### Task 1: Perlin Noise + BehaviorProfile Constants

**Files:**
- Modify: `graph-engine/src/forces.rs` (append at end, before `#[cfg(test)]`)

This task adds the pure utility functions and constants that all other tasks depend on.

**Step 1: Write failing tests for perlin_1d**

Add to `forces.rs` inside the existing `#[cfg(test)] mod tests { ... }` block:

```rust
#[test]
fn test_perlin_1d_range() {
    // Perlin noise output should be in [-1.0, 1.0]
    for i in 0..10000 {
        let t = i as f32 * 0.01;
        let v = super::perlin_1d(t);
        assert!(v >= -1.0 && v <= 1.0, "perlin_1d({t}) = {v} out of range");
    }
}

#[test]
fn test_perlin_1d_smooth() {
    // Adjacent samples should be close (Lipschitz continuity)
    let dt = 0.001;
    for i in 0..10000 {
        let t = i as f32 * dt;
        let a = super::perlin_1d(t);
        let b = super::perlin_1d(t + dt);
        let diff = (b - a).abs();
        assert!(diff < 0.1, "perlin_1d not smooth at {t}: diff={diff}");
    }
}

#[test]
fn test_behavior_profiles_differ() {
    // Sentinel and Dreamer should have very different wander amplitudes
    let sentinel = &super::BEHAVIOR_PROFILES[6]; // Sentinel
    let dreamer = &super::BEHAVIOR_PROFILES[3];  // Dreamer
    assert!(sentinel.wander_amplitude_mult < dreamer.wander_amplitude_mult,
        "Sentinel should wander less than Dreamer");
    assert!(sentinel.cursor_curiosity_mult < dreamer.cursor_curiosity_mult,
        "Sentinel should be less curious than Dreamer");
}
```

**Step 2: Run tests to verify they fail**

Run: `cd graph-engine && cargo test test_perlin_1d_range test_perlin_1d_smooth test_behavior_profiles_differ -- --nocapture 2>&1 | head -30`
Expected: compilation error — `perlin_1d` and `BEHAVIOR_PROFILES` not found.

**Step 3: Implement perlin_1d and BehaviorProfile**

Add to `forces.rs`, before the `#[cfg(test)]` block:

```rust
// ── Behavior: Perlin noise + archetype profiles ─────────────────────────────

/// 1D gradient noise for smooth wander heading. ~20 lines, no external crate.
/// Returns value in [-1.0, 1.0]. Input `t` is continuous time * speed + seed.
pub fn perlin_1d(t: f32) -> f32 {
    let i = t.floor() as i32;
    let f = t - t.floor(); // fractional part [0, 1)
    // Smoothstep fade: 6t^5 - 15t^4 + 10t^3
    let u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    // Pseudo-random gradient at integer points (hash → ±1).
    let grad = |hash: i32| -> f32 {
        // Mix bits to get a pseudo-random sign + magnitude.
        let h = hash.wrapping_mul(1_364_076_727) ^ hash.wrapping_mul(252_744_541);
        let bits = (h >> 16) & 0x7FFF;
        (bits as f32 / 16383.5) - 1.0 // normalize to [-1, 1]
    };
    let g0 = grad(i);
    let g1 = grad(i + 1);
    let d0 = g0 * f;          // gradient * distance from left
    let d1 = g1 * (f - 1.0);  // gradient * distance from right
    d0 + u * (d1 - d0)        // interpolate
}

/// Per-archetype behavior tuning multipliers.
/// No unique logic per archetype — just parameter scales.
#[derive(Clone, Copy, Debug)]
pub struct BehaviorProfile {
    pub wander_speed_mult: f32,
    pub wander_amplitude_mult: f32,
    pub breathe_amplitude_mult: f32,
    pub breathe_freq_mult: f32,
    pub tether_stiffness_mult: f32,
    pub cursor_curiosity_mult: f32,
    pub cursor_avoidance_mult: f32,
}

/// Profiles indexed by archetype: [0]=default(Gardener), [1]=Archivist,
/// [2]=Examiner, [3]=Dreamer, [4]=Gardener, [5]=Guide, [6]=Sentinel.
pub const BEHAVIOR_PROFILES: [BehaviorProfile; 7] = [
    // 0: Default (Gardener fallback)
    BehaviorProfile {
        wander_speed_mult: 1.0, wander_amplitude_mult: 1.0,
        breathe_amplitude_mult: 1.0, breathe_freq_mult: 1.0,
        tether_stiffness_mult: 0.8, cursor_curiosity_mult: 1.0, cursor_avoidance_mult: 1.0,
    },
    // 1: Archivist — anchored scholar, slow and tight
    BehaviorProfile {
        wander_speed_mult: 0.3, wander_amplitude_mult: 0.3,
        breathe_amplitude_mult: 0.8, breathe_freq_mult: 0.8,
        tether_stiffness_mult: 1.2, cursor_curiosity_mult: 0.3, cursor_avoidance_mult: 0.5,
    },
    // 2: Examiner — watchful guard, alert breathing
    BehaviorProfile {
        wander_speed_mult: 0.6, wander_amplitude_mult: 0.6,
        breathe_amplitude_mult: 1.3, breathe_freq_mult: 1.3,
        tether_stiffness_mult: 1.0, cursor_curiosity_mult: 1.5, cursor_avoidance_mult: 1.3,
    },
    // 3: Dreamer — drifting jellyfish, wide and floaty
    BehaviorProfile {
        wander_speed_mult: 1.5, wander_amplitude_mult: 1.5,
        breathe_amplitude_mult: 0.7, breathe_freq_mult: 0.7,
        tether_stiffness_mult: 0.6, cursor_curiosity_mult: 1.5, cursor_avoidance_mult: 0.5,
    },
    // 4: Gardener — reliable worker, balanced
    BehaviorProfile {
        wander_speed_mult: 1.0, wander_amplitude_mult: 1.0,
        breathe_amplitude_mult: 1.0, breathe_freq_mult: 1.0,
        tether_stiffness_mult: 0.8, cursor_curiosity_mult: 1.0, cursor_avoidance_mult: 1.0,
    },
    // 5: Guide — cartographer, purposeful investigator
    BehaviorProfile {
        wander_speed_mult: 1.2, wander_amplitude_mult: 1.2,
        breathe_amplitude_mult: 0.9, breathe_freq_mult: 0.9,
        tether_stiffness_mult: 1.0, cursor_curiosity_mult: 2.0, cursor_avoidance_mult: 0.8,
    },
    // 6: Sentinel — stone guardian, nearly still
    BehaviorProfile {
        wander_speed_mult: 0.1, wander_amplitude_mult: 0.1,
        breathe_amplitude_mult: 0.5, breathe_freq_mult: 0.5,
        tether_stiffness_mult: 1.5, cursor_curiosity_mult: 0.0, cursor_avoidance_mult: 1.5,
    },
];
```

**Step 4: Run tests to verify they pass**

Run: `cd graph-engine && cargo test test_perlin_1d_range test_perlin_1d_smooth test_behavior_profiles_differ -- --nocapture`
Expected: 3 tests PASS.

**Step 5: Commit**

```bash
cd graph-engine
git add src/forces.rs
git commit -m "feat(behavior): add perlin_1d noise and BehaviorProfile constants"
```

---

### Task 2: BehaviorNode Struct + Simulation Integration Scaffold

**Files:**
- Modify: `graph-engine/src/simulation.rs` (add struct, fields, populate in load_from_graph)

This task adds the per-node behavior data structure and wires it into Simulation. No force logic yet — just data population and equilibrium snapshot.

**Step 1: Write failing test for behavior node population**

Add to `simulation.rs` inside the existing `#[cfg(test)] mod tests { ... }` block:

```rust
#[test]
fn behavior_nodes_populated_on_load() {
    let mut graph = Graph::new();
    graph.add_node("a".into(), 0.0, 0.0, 0, 1, "A".into());
    graph.add_node("b".into(), 100.0, 0.0, 0, 1, "B".into());
    graph.add_edge("a".into(), "b".into(), 1.0, 0);

    let mut sim = Simulation::new();
    sim.load_from_graph(&graph);

    assert_eq!(sim.behavior_nodes.len(), sim.x.len(),
        "behavior_nodes should match node count");
    // Each node should have a unique personality seed
    assert_ne!(sim.behavior_nodes[0].personality_seed, sim.behavior_nodes[1].personality_seed);
}

#[test]
fn equilibrium_snapshot_on_settle() {
    let mut graph = Graph::new();
    graph.add_node("a".into(), 50.0, 30.0, 0, 1, "A".into());
    let mut sim = Simulation::new();
    sim.load_from_graph(&graph);

    // Run until settled
    for _ in 0..500 { sim.tick(); }
    assert!(sim.is_settled);

    // Equilibrium should be snapshotted
    assert!(sim.behavior_nodes[0].equilibrium_x.is_finite());
    assert!(sim.behavior_nodes[0].equilibrium_y.is_finite());
    // Should be near the final position
    let dx = (sim.behavior_nodes[0].equilibrium_x - sim.x[0]).abs();
    let dy = (sim.behavior_nodes[0].equilibrium_y - sim.y[0]).abs();
    assert!(dx < 1.0 && dy < 1.0,
        "equilibrium should match settled position: dx={dx}, dy={dy}");
}
```

**Step 2: Run tests to verify they fail**

Run: `cd graph-engine && cargo test behavior_nodes_populated equilibrium_snapshot_on_settle -- --nocapture 2>&1 | head -30`
Expected: compilation error — `behavior_nodes` field not found.

**Step 3: Add BehaviorNode struct and Simulation fields**

Add `BehaviorNode` struct to `simulation.rs`, right before `pub struct Simulation`:

```rust
// ── Per-node behavior state ─────────────────────────────────────────────────

/// Per-node autonomous behavior state. Lives in Simulation (SoA) alongside x/y/vx/vy.
/// Compact: 48 bytes per node (~235 KB at 5,000 nodes).
#[derive(Clone, Copy, Debug)]
pub struct BehaviorNode {
    /// Current FSM state (maps to ecs::AIState discriminant).
    pub state: u8,
    /// Index into BEHAVIOR_PROFILES array (0=default, 1-6=archetypes).
    pub profile_index: u8,
    /// Hierarchy depth (0 = root). Deeper children trail more lazily.
    pub depth: u8,
    pub _pad: u8,
    /// Parent's sim index, or u32::MAX if no parent.
    pub parent_sim_idx: u32,
    /// Per-node RNG seed for Perlin phase offset.
    pub personality_seed: u32,
    /// Snapshot of where physics settled this node (wander home anchor).
    pub equilibrium_x: f32,
    pub equilibrium_y: f32,
    /// Current Perlin-sampled heading angle.
    pub wander_angle: f32,
    /// Sinusoidal breathe phase offset.
    pub breath_phase: f32,
    /// Breathe frequency (Hz). Base: 0.5, modulated by profile.
    pub breath_freq: f32,
    /// Max wander drift from equilibrium (px).
    pub wander_radius: f32,
    /// Base movement speed multiplier.
    pub speed: f32,
    /// 0.0–1.0 interpolation between curiosity (0) and avoidance (1).
    pub cursor_awareness: f32,
    /// Seconds remaining in Excited state (decays to 0).
    pub excitement_timer: f32,
    /// Current breathe scale multiplier (written by force_behavior, read by renderer).
    pub breathe_scale: f32,
}

impl Default for BehaviorNode {
    fn default() -> Self {
        Self {
            state: 0, // Idle
            profile_index: 0,
            depth: 0,
            _pad: 0,
            parent_sim_idx: u32::MAX,
            personality_seed: 0,
            equilibrium_x: f32::NAN,
            equilibrium_y: f32::NAN,
            wander_angle: 0.0,
            breath_phase: 0.0,
            breath_freq: 0.5,
            wander_radius: 5.0,
            speed: 1.0,
            cursor_awareness: 0.0,
            excitement_timer: 0.0,
            breathe_scale: 1.0,
        }
    }
}
```

Add these fields to `pub struct Simulation` (after `search_saved_alpha_target`):

```rust
    /// Per-node autonomous behavior state (parallel to x/y/vx/vy).
    pub behavior_nodes: Vec<BehaviorNode>,
    /// Separate alpha for behavior forces — never drops below warm floor.
    pub behavior_alpha: f32,
    /// Cursor world position (written by Engine::mouse_moved).
    pub cursor_world_x: f32,
    pub cursor_world_y: f32,
    /// Cursor speed in world units/sec (smoothed).
    pub cursor_speed: f32,
    /// Cumulative simulation time in seconds (for Perlin sampling).
    pub behavior_time: f32,
    /// Whether equilibrium has been snapshotted (set once on first settle).
    pub equilibrium_snapshotted: bool,
```

Initialize in `Simulation::new()`:

```rust
            behavior_nodes: Vec::new(),
            behavior_alpha: 0.3,
            cursor_world_x: f32::NAN,
            cursor_world_y: f32::NAN,
            cursor_speed: 0.0,
            behavior_time: 0.0,
            equilibrium_snapshotted: false,
```

**Step 4: Populate behavior_nodes in load_from_graph**

In `load_from_graph()`, add `self.behavior_nodes.clear();` alongside the other `.clear()` calls (around line 413-427).

After the edge processing loop (around line 540, after degrees are computed and caps applied), add:

```rust
        // ── Populate behavior nodes ─────────────────────────────────
        self.behavior_nodes.clear();
        self.behavior_nodes.resize(node_count, BehaviorNode::default());
        self.equilibrium_snapshotted = false;
        self.behavior_alpha = 0.3;
        self.behavior_time = 0.0;

        // Assign personality seeds (deterministic from sim index).
        for i in 0..node_count {
            let seed = (i as u32).wrapping_mul(2654435761); // Knuth multiplicative hash
            self.behavior_nodes[i].personality_seed = seed;
            self.behavior_nodes[i].breath_phase =
                (seed as f32 / u32::MAX as f32) * std::f32::consts::TAU;
            self.behavior_nodes[i].wander_radius = 5.0;
            self.behavior_nodes[i].speed = 1.0;
            self.behavior_nodes[i].breath_freq = 0.5;
        }

        // Build parent relationships from "contains" edges (type 1).
        for &(src, tgt) in &self.edges {
            let etype = self.edge_types[self.edges.iter().position(|&e| e == (src, tgt)).unwrap_or(0)];
            if etype == 1 {
                // "contains" = parent→child: src is parent, tgt is child
                self.behavior_nodes[tgt].parent_sim_idx = src as u32;
            }
        }

        // Compute depths from parent chains.
        for i in 0..node_count {
            let mut depth: u8 = 0;
            let mut current = i;
            while self.behavior_nodes[current].parent_sim_idx != u32::MAX {
                depth = depth.saturating_add(1);
                current = self.behavior_nodes[current].parent_sim_idx as usize;
                if depth > 10 || current >= node_count { break; }
            }
            self.behavior_nodes[i].depth = depth;
        }
```

**IMPORTANT:** The edge_type lookup above uses a position scan which is O(n²). Replace it with a proper indexed approach. Since `self.edge_types` is parallel to `self.edges`, use the edge index directly:

```rust
        // Build parent relationships from "contains" edges (type 1).
        for (ei, &(src, tgt)) in self.edges.iter().enumerate() {
            if self.edge_types[ei] == 1 {
                self.behavior_nodes[tgt].parent_sim_idx = src as u32;
            }
        }
```

**Step 5: Snapshot equilibrium when settled**

In `Simulation::tick()`, right after `self.is_settled = at_floor && !any_fixed;` (line 584) and before the settled early-return block, add:

```rust
        // Snapshot equilibrium positions on first settle.
        if self.is_settled && !self.equilibrium_snapshotted {
            self.equilibrium_snapshotted = true;
            for i in 0..n {
                self.behavior_nodes[i].equilibrium_x = self.x[i];
                self.behavior_nodes[i].equilibrium_y = self.y[i];
                self.behavior_nodes[i].state = 1; // Swimming
            }
        }
```

**Step 6: Run tests to verify they pass**

Run: `cd graph-engine && cargo test behavior_nodes_populated equilibrium_snapshot_on_settle -- --nocapture`
Expected: 2 tests PASS.

**Step 7: Run full test suite to check for regressions**

Run: `cd graph-engine && cargo test 2>&1 | tail -5`
Expected: All existing tests still pass.

**Step 8: Commit**

```bash
cd graph-engine
git add src/simulation.rs
git commit -m "feat(behavior): add BehaviorNode struct and populate in Simulation"
```

---

### Task 3: force_behavior() — Wander + Breathe Sub-Forces

**Files:**
- Modify: `graph-engine/src/forces.rs` (add force_behavior function)

Implements the first two behavior sub-forces: Perlin-noise wander and sinusoidal breathe.

**Step 1: Write failing tests**

Add to `forces.rs` inside `#[cfg(test)] mod tests`:

```rust
#[test]
fn test_wander_stays_within_radius() {
    use crate::simulation::BehaviorNode;

    let n = 1;
    let mut x = vec![100.0];
    let mut y = vec![100.0];
    let mut vx = vec![0.0];
    let mut vy = vec![0.0];
    let fx: Vec<Option<f32>> = vec![None];
    let fy: Vec<Option<f32>> = vec![None];

    let mut nodes = vec![BehaviorNode::default()];
    nodes[0].state = 1; // Swimming
    nodes[0].equilibrium_x = 100.0;
    nodes[0].equilibrium_y = 100.0;
    nodes[0].wander_radius = 10.0;
    nodes[0].personality_seed = 42;

    let max_allowed = 10.0 * 1.5; // wander_radius * 1.5

    for tick in 0..10_000 {
        let time = tick as f32 * 0.016; // ~60fps
        super::force_behavior(
            &mut x, &mut y, &mut vx, &mut vy, &fx, &fy,
            &mut nodes, time, f32::NAN, f32::NAN, 0.0, 0.15,
        );
        // Integrate (simplified — no velocity decay for pure wander test)
        x[0] += vx[0];
        y[0] += vy[0];
        vx[0] *= 0.6; // velocity decay

        let dx = x[0] - 100.0;
        let dy = y[0] - 100.0;
        let dist = (dx * dx + dy * dy).sqrt();
        assert!(dist < max_allowed,
            "tick {tick}: wander drifted {dist:.1}px from equilibrium (max {max_allowed})");
    }
}

#[test]
fn test_breathe_scale_oscillates() {
    use crate::simulation::BehaviorNode;

    let mut nodes = vec![BehaviorNode::default()];
    nodes[0].state = 1; // Swimming
    nodes[0].equilibrium_x = 0.0;
    nodes[0].equilibrium_y = 0.0;
    nodes[0].breath_phase = 0.0;
    nodes[0].breath_freq = 0.5;

    let mut x = vec![0.0];
    let mut y = vec![0.0];
    let mut vx = vec![0.0];
    let mut vy = vec![0.0];
    let fx: Vec<Option<f32>> = vec![None];
    let fy: Vec<Option<f32>> = vec![None];

    let mut min_scale = f32::MAX;
    let mut max_scale = f32::MIN;

    for tick in 0..1000 {
        let time = tick as f32 * 0.016;
        super::force_behavior(
            &mut x, &mut y, &mut vx, &mut vy, &fx, &fy,
            &mut nodes, time, f32::NAN, f32::NAN, 0.0, 0.15,
        );
        let s = nodes[0].breathe_scale;
        if s < min_scale { min_scale = s; }
        if s > max_scale { max_scale = s; }
    }

    // Breathe should oscillate around 1.0 with 1-3% amplitude
    assert!(min_scale < 1.0, "breathe should go below 1.0: min={min_scale}");
    assert!(max_scale > 1.0, "breathe should go above 1.0: max={max_scale}");
    assert!(min_scale > 0.95, "breathe amplitude too large: min={min_scale}");
    assert!(max_scale < 1.05, "breathe amplitude too large: max={max_scale}");
}
```

**Step 2: Run tests to verify they fail**

Run: `cd graph-engine && cargo test test_wander_stays_within_radius test_breathe_scale_oscillates -- --nocapture 2>&1 | head -20`
Expected: compilation error — `force_behavior` not found.

**Step 3: Implement force_behavior with wander + breathe**

Add to `forces.rs`, after the `BEHAVIOR_PROFILES` const:

```rust
/// Autonomous behavior force (#9 in the physics pipeline).
/// Applies wander, breathe, damped tether, and cursor reaction per node.
/// Stays active at `behavior_alpha` even when main physics alpha is at floor.
///
/// `cursor_x/y`: world-space cursor position (NaN = cursor not tracked).
/// `cursor_speed`: cursor velocity in world units/sec.
/// `behavior_alpha`: separate alpha that stays warm (0.15 floor).
#[allow(clippy::too_many_arguments)]
pub fn force_behavior(
    x: &mut [f32],
    y: &mut [f32],
    vx: &mut [f32],
    vy: &mut [f32],
    fx: &[Option<f32>],
    fy: &[Option<f32>],
    nodes: &mut [crate::simulation::BehaviorNode],
    time: f32,
    cursor_x: f32,
    cursor_y: f32,
    cursor_speed: f32,
    behavior_alpha: f32,
) {
    let n = x.len().min(nodes.len());

    for i in 0..n {
        // Skip fixed (dragged) nodes.
        if fx[i].is_some() || fy[i].is_some() {
            continue;
        }

        let node = &mut nodes[i];
        let profile = &BEHAVIOR_PROFILES[node.profile_index.min(6) as usize];

        // Skip nodes without equilibrium snapshot (still in initial layout).
        if !node.equilibrium_x.is_finite() || !node.equilibrium_y.is_finite() {
            continue;
        }

        // ── State multipliers ──
        let (wander_mult, breathe_mult) = match node.state {
            0 => (0.0, 0.5),  // Idle — minimal movement
            1 => (1.0, 1.0),  // Swimming — full behavior
            2 => (0.3, 0.8),  // AvoidingCursor — reduced wander, cursor force dominates
            3 => (0.5, 0.9),  // TrailingParent — moderate wander, tether dominates
            4 => (2.0, 1.5),  // Excited — doubled wander, amplified breathe
            5 => (0.02, 0.3), // Sleeping — near-zero wander, faint breathe
            _ => (1.0, 1.0),
        };

        // ── 1. Wander (Perlin noise) ──
        let wander_speed = 0.2 * profile.wander_speed_mult * wander_mult;
        let wander_amp = 0.5 * profile.wander_amplitude_mult * wander_mult;
        let seed_offset = node.personality_seed as f32 * 0.001;

        node.wander_angle = perlin_1d(time * wander_speed + seed_offset) * std::f32::consts::TAU;
        let wander_fx = node.wander_angle.cos() * wander_amp * behavior_alpha;
        let wander_fy = node.wander_angle.sin() * wander_amp * behavior_alpha;

        vx[i] += wander_fx;
        vy[i] += wander_fy;

        // Soft spring back to equilibrium (prevents migration).
        let eq_dx = node.equilibrium_x - x[i];
        let eq_dy = node.equilibrium_y - y[i];
        let eq_dist = (eq_dx * eq_dx + eq_dy * eq_dy).sqrt();
        let radius = node.wander_radius * profile.wander_amplitude_mult;
        if eq_dist > radius * 0.5 {
            let spring_k = 0.01 * (eq_dist / radius).min(2.0);
            vx[i] += eq_dx * spring_k * behavior_alpha;
            vy[i] += eq_dy * spring_k * behavior_alpha;
        }

        // ── 2. Breathe (sinusoidal scale) ──
        let breathe_amp = 0.02 * profile.breathe_amplitude_mult * breathe_mult;
        let breathe_freq = node.breath_freq * profile.breathe_freq_mult;
        node.breathe_scale = 1.0
            + breathe_amp * (time * breathe_freq * std::f32::consts::TAU + node.breath_phase).sin();
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd graph-engine && cargo test test_wander_stays_within_radius test_breathe_scale_oscillates -- --nocapture`
Expected: 2 tests PASS.

**Step 5: Commit**

```bash
cd graph-engine
git add src/forces.rs
git commit -m "feat(behavior): add force_behavior with wander and breathe sub-forces"
```

---

### Task 4: force_behavior() — Damped Tether + Cursor Reaction

**Files:**
- Modify: `graph-engine/src/forces.rs` (extend force_behavior)

Adds the remaining two sub-forces: viscous parent-child tether and two-phase cursor reaction.

**Step 1: Write failing tests**

Add to `forces.rs` inside `#[cfg(test)] mod tests`:

```rust
#[test]
fn test_damped_tether_no_overshoot() {
    use crate::simulation::BehaviorNode;

    // Parent at origin, child at (100, 0). Tether should pull child toward parent
    // monotonically — no oscillation past the parent.
    let mut x = vec![0.0, 100.0];
    let mut y = vec![0.0, 0.0];
    let mut vx = vec![0.0, 0.0];
    let mut vy = vec![0.0, 0.0];
    let fx: Vec<Option<f32>> = vec![None, None];
    let fy: Vec<Option<f32>> = vec![None, None];

    let mut nodes = vec![BehaviorNode::default(); 2];
    // Parent (index 0): Swimming
    nodes[0].state = 1;
    nodes[0].equilibrium_x = 0.0;
    nodes[0].equilibrium_y = 0.0;
    // Child (index 1): TrailingParent
    nodes[1].state = 3; // TrailingParent
    nodes[1].parent_sim_idx = 0;
    nodes[1].depth = 1;
    nodes[1].equilibrium_x = 100.0;
    nodes[1].equilibrium_y = 0.0;
    nodes[1].wander_radius = 0.0; // Disable wander for this test

    // Now move parent to (-50, 0) — child should follow smoothly
    x[0] = -50.0;

    let mut prev_dist = (x[1] - x[0]).abs();
    let mut approached_monotonically = true;

    for tick in 0..200 {
        let time = tick as f32 * 0.016;
        super::force_behavior(
            &mut x, &mut y, &mut vx, &mut vy, &fx, &fy,
            &mut nodes, time, f32::NAN, f32::NAN, 0.0, 0.15,
        );
        // Integrate with decay
        vx[1] *= 0.6;
        vy[1] *= 0.6;
        x[1] += vx[1];
        y[1] += vy[1];

        let dist = (x[1] - x[0]).abs();
        if dist > prev_dist + 0.5 { // Allow tiny numerical noise
            approached_monotonically = false;
        }
        prev_dist = dist;
    }

    assert!(approached_monotonically,
        "child should approach parent monotonically (no overshoot)");
    // Child should have moved closer to parent
    assert!(x[1] < 80.0, "child should have moved toward parent: x={}", x[1]);
}

#[test]
fn test_cursor_curiosity_then_avoidance() {
    use crate::simulation::BehaviorNode;

    let mut x = vec![0.0];
    let mut y = vec![0.0];
    let mut vx = vec![0.0];
    let mut vy = vec![0.0];
    let fx: Vec<Option<f32>> = vec![None];
    let fy: Vec<Option<f32>> = vec![None];

    let mut nodes = vec![BehaviorNode::default()];
    nodes[0].state = 1; // Swimming
    nodes[0].equilibrium_x = 0.0;
    nodes[0].equilibrium_y = 0.0;
    nodes[0].wander_radius = 0.0; // Disable wander

    // Phase 1: Slow cursor at (80, 0) — should attract (curiosity)
    super::force_behavior(
        &mut x, &mut y, &mut vx, &mut vy, &fx, &fy,
        &mut nodes, 0.0,
        80.0, 0.0, 10.0, // cursor at 80px, speed 10 (slow)
        0.15,
    );
    let curiosity_vx = vx[0];
    assert!(curiosity_vx > 0.0,
        "slow cursor should attract (curiosity): vx={curiosity_vx}");

    // Reset
    vx[0] = 0.0;
    nodes[0].cursor_awareness = 0.0;

    // Phase 2: Fast cursor at (80, 0) — should repel (avoidance)
    super::force_behavior(
        &mut x, &mut y, &mut vx, &mut vy, &fx, &fy,
        &mut nodes, 0.0,
        80.0, 0.0, 200.0, // cursor at 80px, speed 200 (fast)
        0.15,
    );
    let avoidance_vx = vx[0];
    assert!(avoidance_vx < 0.0,
        "fast cursor should repel (avoidance): vx={avoidance_vx}");
}
```

**Step 2: Run tests to verify they fail**

Run: `cd graph-engine && cargo test test_damped_tether_no_overshoot test_cursor_curiosity_then_avoidance -- --nocapture 2>&1 | head -20`
Expected: Tests fail — force_behavior doesn't yet implement tether or cursor.

**Step 3: Add tether and cursor sub-forces to force_behavior**

Inside the `for i in 0..n` loop in `force_behavior()`, after the breathe section, add:

```rust
        // ── 3. Damped Tether (parent-child) ──
        if node.state == 3 && node.parent_sim_idx != u32::MAX {
            let pi = node.parent_sim_idx as usize;
            if pi < n {
                let dx = x[pi] - x[i];
                let dy = y[pi] - y[i];
                let rel_vx = vx[pi] - vx[i];
                let rel_vy = vy[pi] - vy[i];

                // Stiffness attenuates with depth: 0.02 * 0.7^depth
                let base_stiffness = 0.02 * profile.tether_stiffness_mult;
                let depth_factor = 0.7_f32.powi(node.depth as i32);
                let stiffness = base_stiffness * depth_factor;
                let damping = 0.85;

                let tether_fx = dx * stiffness - rel_vx * damping;
                let tether_fy = dy * stiffness - rel_vy * damping;

                vx[i] += tether_fx * behavior_alpha;
                vy[i] += tether_fy * behavior_alpha;
            }
        }

        // ── 4. Cursor Reaction (curiosity → avoidance) ──
        if cursor_x.is_finite() && cursor_y.is_finite() {
            let cdx = x[i] - cursor_x;
            let cdy = y[i] - cursor_y;
            let cursor_dist = (cdx * cdx + cdy * cdy).sqrt();
            let cursor_range = 120.0;

            if cursor_dist < cursor_range && cursor_dist > 1.0 {
                let curiosity_threshold = 50.0; // px/sec
                let dir_x = cdx / cursor_dist;
                let dir_y = cdy / cursor_dist;

                if cursor_speed < curiosity_threshold {
                    // Curiosity: tiny attraction toward cursor
                    let strength = 0.3 * profile.cursor_curiosity_mult
                        * (1.0 - cursor_dist / cursor_range);
                    vx[i] -= dir_x * strength * behavior_alpha;
                    vy[i] -= dir_y * strength * behavior_alpha;
                    // Interpolate awareness toward 0 (curiosity)
                    node.cursor_awareness = (node.cursor_awareness - 0.05).max(0.0);
                } else {
                    // Avoidance: soft repulsion (inverse-square falloff)
                    let inv_sq = 1.0 / (cursor_dist * cursor_dist).max(1.0);
                    let strength = 50.0 * profile.cursor_avoidance_mult * inv_sq;
                    vx[i] += dir_x * strength * behavior_alpha;
                    vy[i] += dir_y * strength * behavior_alpha;
                    // Interpolate awareness toward 1 (avoidance)
                    node.cursor_awareness = (node.cursor_awareness + 0.05).min(1.0);
                }
            }
        }
```

**Step 4: Run tests to verify they pass**

Run: `cd graph-engine && cargo test test_damped_tether_no_overshoot test_cursor_curiosity_then_avoidance -- --nocapture`
Expected: 2 tests PASS.

**Step 5: Run full test suite**

Run: `cd graph-engine && cargo test 2>&1 | tail -5`
Expected: All tests pass.

**Step 6: Commit**

```bash
cd graph-engine
git add src/forces.rs
git commit -m "feat(behavior): add damped tether and cursor reaction sub-forces"
```

---

### Task 5: FSM State Transitions + Sleeping/Active-at-Floor Tests

**Files:**
- Modify: `graph-engine/src/forces.rs` (add FSM logic at start of force_behavior)
- Modify: `graph-engine/src/simulation.rs` (behavior_alpha warm floor in tick)

**Step 1: Write failing tests**

Add to `forces.rs` `#[cfg(test)] mod tests`:

```rust
#[test]
fn test_sleeping_node_minimal_motion() {
    use crate::simulation::BehaviorNode;

    let mut x = vec![50.0];
    let mut y = vec![50.0];
    let mut vx = vec![0.0];
    let mut vy = vec![0.0];
    let fx: Vec<Option<f32>> = vec![None];
    let fy: Vec<Option<f32>> = vec![None];

    let mut nodes = vec![BehaviorNode::default()];
    nodes[0].state = 5; // Sleeping
    nodes[0].equilibrium_x = 50.0;
    nodes[0].equilibrium_y = 50.0;

    for tick in 0..1000 {
        let time = tick as f32 * 0.016;
        super::force_behavior(
            &mut x, &mut y, &mut vx, &mut vy, &fx, &fy,
            &mut nodes, time, f32::NAN, f32::NAN, 0.0, 0.15,
        );
        vx[0] *= 0.6;
        vy[0] *= 0.6;
        x[0] += vx[0];
        y[0] += vy[0];
    }

    let dx = (x[0] - 50.0).abs();
    let dy = (y[0] - 50.0).abs();
    let displacement = (dx * dx + dy * dy).sqrt();
    assert!(displacement < 0.5,
        "sleeping node should barely move: displacement={displacement:.3}px");
}

#[test]
fn test_behavior_active_at_alpha_floor() {
    use crate::simulation::BehaviorNode;

    let mut x = vec![0.0];
    let mut y = vec![0.0];
    let mut vx = vec![0.0];
    let mut vy = vec![0.0];
    let fx: Vec<Option<f32>> = vec![None];
    let fy: Vec<Option<f32>> = vec![None];

    let mut nodes = vec![BehaviorNode::default()];
    nodes[0].state = 1; // Swimming
    nodes[0].equilibrium_x = 0.0;
    nodes[0].equilibrium_y = 0.0;
    nodes[0].personality_seed = 12345;
    nodes[0].wander_radius = 10.0;

    let start_x = x[0];
    let start_y = y[0];

    // Run 100 ticks with behavior_alpha at warm floor
    for tick in 0..100 {
        let time = tick as f32 * 0.016;
        super::force_behavior(
            &mut x, &mut y, &mut vx, &mut vy, &fx, &fy,
            &mut nodes, time, f32::NAN, f32::NAN, 0.0, 0.15, // behavior_alpha = 0.15
        );
        vx[0] *= 0.6;
        vy[0] *= 0.6;
        x[0] += vx[0];
        y[0] += vy[0];
    }

    let dx = (x[0] - start_x).abs();
    let dy = (y[0] - start_y).abs();
    let displacement = (dx * dx + dy * dy).sqrt();
    assert!(displacement > 0.1,
        "swimming node should move at alpha floor: displacement={displacement:.4}px");
}
```

**Step 2: Run tests to verify they fail (or pass with current implementation)**

Run: `cd graph-engine && cargo test test_sleeping_node_minimal_motion test_behavior_active_at_alpha_floor -- --nocapture`
Expected: These may already pass since we set state multipliers in Task 3. If they pass, great — the implementation already handles these cases.

**Step 3: Add FSM transition logic to force_behavior**

At the very beginning of the `for i in 0..n` loop (before the state multipliers), add inline FSM transitions:

```rust
        // ── FSM transitions (inline, no separate system) ──
        let dt = 0.016_f32; // Approximate tick delta
        match node.state {
            0 => {
                // Idle → Swimming (once equilibrium is set)
                if node.equilibrium_x.is_finite() {
                    node.state = 1;
                }
            }
            4 => {
                // Excited → Swimming (timer decay)
                node.excitement_timer = (node.excitement_timer - dt).max(0.0);
                if node.excitement_timer <= 0.0 {
                    node.state = if node.parent_sim_idx != u32::MAX { 3 } else { 1 };
                }
            }
            1 | 2 => {
                // Swimming ↔ AvoidingCursor (cursor proximity)
                if cursor_x.is_finite() {
                    let cdx = x[i] - cursor_x;
                    let cdy = y[i] - cursor_y;
                    let cursor_dist = (cdx * cdx + cdy * cdy).sqrt();
                    if cursor_dist < 120.0 && node.state == 1 {
                        node.state = 2; // → AvoidingCursor
                    } else if cursor_dist >= 120.0 && node.state == 2 {
                        node.state = if node.parent_sim_idx != u32::MAX { 3 } else { 1 };
                    }
                } else if node.state == 2 {
                    node.state = if node.parent_sim_idx != u32::MAX { 3 } else { 1 };
                }
                // Swimming → TrailingParent (has parent)
                if node.state == 1 && node.parent_sim_idx != u32::MAX {
                    node.state = 3;
                }
            }
            3 => {
                // TrailingParent → AvoidingCursor (cursor near)
                if cursor_x.is_finite() {
                    let cdx = x[i] - cursor_x;
                    let cdy = y[i] - cursor_y;
                    let cursor_dist = (cdx * cdx + cdy * cdy).sqrt();
                    if cursor_dist < 120.0 {
                        node.state = 2;
                    }
                }
            }
            _ => {} // Sleeping (5) — stays until external trigger
        }
```

**Step 4: Run all behavior tests**

Run: `cd graph-engine && cargo test test_wander_stays test_breathe_scale test_damped_tether test_cursor_curiosity test_sleeping_node test_behavior_active -- --nocapture`
Expected: All 6 tests PASS.

**Step 5: Commit**

```bash
cd graph-engine
git add src/forces.rs
git commit -m "feat(behavior): add FSM state transitions and sleeping/active tests"
```

---

### Task 6: Wire force_behavior into Simulation::tick() + Cursor Plumbing

**Files:**
- Modify: `graph-engine/src/simulation.rs` (call force_behavior in tick, behavior_alpha management)
- Modify: `graph-engine/src/engine.rs` (store cursor world position)

This is the integration task that makes everything work end-to-end.

**Step 1: Write failing integration test**

Add to `simulation.rs` `#[cfg(test)] mod tests`:

```rust
#[test]
fn test_archetype_profiles_differ_after_ticks() {
    use crate::forces::BEHAVIOR_PROFILES;

    let mut graph = Graph::new();
    // Two nodes: one will be Sentinel (barely moves), one will be Dreamer (floaty)
    graph.add_node("sentinel".into(), 0.0, 0.0, 0, 1, "S".into());
    graph.add_node("dreamer".into(), 200.0, 0.0, 0, 1, "D".into());

    let mut sim = Simulation::new();
    sim.load_from_graph(&graph);

    // Assign profiles
    sim.behavior_nodes[0].profile_index = 6; // Sentinel
    sim.behavior_nodes[1].profile_index = 3; // Dreamer

    // Run until settled (sets equilibrium)
    for _ in 0..500 { sim.tick(); }
    assert!(sim.equilibrium_snapshotted);

    let eq_x0 = sim.behavior_nodes[0].equilibrium_x;
    let eq_y0 = sim.behavior_nodes[0].equilibrium_y;
    let eq_x1 = sim.behavior_nodes[1].equilibrium_x;
    let eq_y1 = sim.behavior_nodes[1].equilibrium_y;

    // Run 1000 more ticks with behavior active
    for _ in 0..1000 { sim.tick(); }

    let drift_sentinel = ((sim.x[0] - eq_x0).powi(2) + (sim.y[0] - eq_y0).powi(2)).sqrt();
    let drift_dreamer = ((sim.x[1] - eq_x1).powi(2) + (sim.y[1] - eq_y1).powi(2)).sqrt();

    assert!(drift_dreamer > drift_sentinel,
        "Dreamer should drift more than Sentinel: dreamer={drift_dreamer:.2}, sentinel={drift_sentinel:.2}");
}
```

**Step 2: Run test to verify it fails**

Run: `cd graph-engine && cargo test test_archetype_profiles_differ -- --nocapture 2>&1 | head -20`
Expected: Fails because `tick()` doesn't call `force_behavior()` yet.

**Step 3: Add behavior_alpha management and force_behavior call to Simulation::tick()**

In `Simulation::tick()`, add `use crate::forces;` at the top of the function (or ensure it's imported).

**3a.** After the behavior time increment (add right after `self.haptic_event = 0;`, around line 565):

```rust
        // Behavior time accumulates for Perlin sampling (~60Hz assumption).
        self.behavior_time += 0.016;

        // Behavior alpha: decays toward warm floor (0.15), never below.
        const BEHAVIOR_ALPHA_FLOOR: f32 = 0.15;
        self.behavior_alpha += (BEHAVIOR_ALPHA_FLOOR - self.behavior_alpha) * 0.02;
        if self.behavior_alpha < BEHAVIOR_ALPHA_FLOOR {
            self.behavior_alpha = BEHAVIOR_ALPHA_FLOOR;
        }
```

**3b.** BEFORE the settled early-return block (before `if self.is_settled {` at line 589), call force_behavior:

```rust
        // Force #9: Behavior — runs even when settled (uses behavior_alpha, not main alpha).
        if self.equilibrium_snapshotted && !self.behavior_nodes.is_empty() {
            forces::force_behavior(
                &mut self.x,
                &mut self.y,
                &mut self.vx,
                &mut self.vy,
                &self.fx,
                &self.fy,
                &mut self.behavior_nodes,
                self.behavior_time,
                self.cursor_world_x,
                self.cursor_world_y,
                self.cursor_speed,
                self.behavior_alpha,
            );
        }
```

**3c.** Modify the settled early-return block to NOT zero velocities when behavior is active:

Replace the existing settled block:
```rust
        if self.is_settled {
            for i in 0..n {
                self.vx[i] = 0.0;
                self.vy[i] = 0.0;
            }
            return;
        }
```

With:
```rust
        if self.is_settled {
            if self.equilibrium_snapshotted {
                // Behavior is active — apply velocity decay + integration for behavior forces only.
                const MAX_VELOCITY: f32 = 500.0;
                let decay = self.params.velocity_decay;
                for i in 0..n {
                    if self.fx[i].is_none() {
                        self.vx[i] *= decay;
                        self.vx[i] = self.vx[i].clamp(-MAX_VELOCITY, MAX_VELOCITY);
                        self.x[i] += self.vx[i];
                    }
                    if self.fy[i].is_none() {
                        self.vy[i] *= decay;
                        self.vy[i] = self.vy[i].clamp(-MAX_VELOCITY, MAX_VELOCITY);
                        self.y[i] += self.vy[i];
                    }
                    if !self.x[i].is_finite() { self.x[i] = 0.0; self.vx[i] = 0.0; }
                    if !self.y[i].is_finite() { self.y[i] = 0.0; self.vy[i] = 0.0; }
                }
            } else {
                for i in 0..n {
                    self.vx[i] = 0.0;
                    self.vy[i] = 0.0;
                }
            }
            return;
        }
```

**Step 4: Add cursor plumbing to Engine::mouse_moved**

In `engine.rs`, inside `pub fn mouse_moved(&mut self, screen_x: f32, screen_y: f32)`, after the world coordinate conversion (`let (wx, wy) = self.screen_to_world(screen_x, screen_y);`), add:

```rust
        // Update cursor position for behavior force.
        {
            let mut sim = self.sim.lock();
            let prev_x = sim.cursor_world_x;
            let prev_y = sim.cursor_world_y;
            sim.cursor_world_x = wx;
            sim.cursor_world_y = wy;
            // Compute cursor speed (smoothed).
            if prev_x.is_finite() && prev_y.is_finite() {
                let dx = wx - prev_x;
                let dy = wy - prev_y;
                let instant_speed = (dx * dx + dy * dy).sqrt() * 60.0; // Assume ~60fps
                sim.cursor_speed = sim.cursor_speed * 0.8 + instant_speed * 0.2; // EMA smoothing
            }
        }
```

**Step 5: Run the integration test**

Run: `cd graph-engine && cargo test test_archetype_profiles_differ -- --nocapture`
Expected: PASS — Dreamer drifts more than Sentinel.

**Step 6: Run full test suite**

Run: `cd graph-engine && cargo test 2>&1 | tail -5`
Expected: All tests pass (including all existing 549+ tests).

**Step 7: Commit**

```bash
cd graph-engine
git add src/simulation.rs src/engine.rs
git commit -m "feat(behavior): wire force_behavior into Simulation::tick with cursor plumbing"
```

---

### Task 7: Breathe Scale Sync + Static Layout Gate

**Files:**
- Modify: `graph-engine/src/engine.rs` (sync breathe_scale to graph nodes)

This task ensures the breathe effect is visible in the renderer and that behavior is disabled for large graphs.

**Step 1: Write test for static layout gate**

Add to `simulation.rs` `#[cfg(test)] mod tests`:

```rust
#[test]
fn test_behavior_disabled_when_static_layout() {
    let mut sim = Simulation::new();
    sim.static_layout = true;
    sim.behavior_nodes = vec![crate::simulation::BehaviorNode::default()];
    sim.behavior_nodes[0].state = 1;
    sim.behavior_nodes[0].equilibrium_x = 0.0;
    sim.behavior_nodes[0].equilibrium_y = 0.0;
    sim.x = vec![0.0];
    sim.y = vec![0.0];
    sim.vx = vec![0.0];
    sim.vy = vec![0.0];

    // tick() should return early for static layout
    sim.tick();
    assert_eq!(sim.x[0], 0.0, "static layout should prevent all movement");
}
```

**Step 2: Run test**

Run: `cd graph-engine && cargo test test_behavior_disabled_when_static_layout -- --nocapture`
Expected: PASS (static_layout check is at top of tick(), returns before any force runs).

**Step 3: Sync breathe_scale to renderer**

In `engine.rs`, find the `sync_positions` method (where sim positions are copied back to graph nodes). After the position sync, add breathe scale sync:

Find the position sync loop (where `self.graph.nodes[gi].x = sim.x[si]` is called) and add:

```rust
            // Sync breathe scale to graph node radius scaling.
            if si < sim.behavior_nodes.len() {
                self.graph.nodes[gi].radius_scale = sim.behavior_nodes[si].breathe_scale;
            }
```

**NOTE:** If `Node` doesn't have a `radius_scale` field, add it:

In `types.rs`, add to `pub struct Node`:
```rust
    /// Breathe animation scale multiplier (1.0 = normal). Written by behavior force.
    pub radius_scale: f32,
```

And initialize it to `1.0` in the Node constructor/default.

Then in the renderer, wherever `node.radius` is used for instance data, multiply by `node.radius_scale`:
```rust
radius * node.radius_scale
```

**Step 4: Run full test suite**

Run: `cd graph-engine && cargo test 2>&1 | tail -5`
Expected: All tests pass.

**Step 5: Commit**

```bash
cd graph-engine
git add src/engine.rs src/types.rs src/simulation.rs
git commit -m "feat(behavior): sync breathe scale to renderer and verify static layout gate"
```

---

## Summary of All Tests

| Test | File | What It Verifies |
|------|------|-----------------|
| `test_perlin_1d_range` | forces.rs | Perlin output stays in [-1, 1] |
| `test_perlin_1d_smooth` | forces.rs | Perlin output is continuous (no jitter) |
| `test_behavior_profiles_differ` | forces.rs | Sentinel ≠ Dreamer tuning |
| `test_wander_stays_within_radius` | forces.rs | 10K ticks, never exceeds radius × 1.5 |
| `test_breathe_scale_oscillates` | forces.rs | Scale oscillates 1% ± around 1.0 |
| `test_damped_tether_no_overshoot` | forces.rs | Child approaches parent monotonically |
| `test_cursor_curiosity_then_avoidance` | forces.rs | Slow cursor attracts, fast repels |
| `test_sleeping_node_minimal_motion` | forces.rs | < 0.5px displacement over 1K ticks |
| `test_behavior_active_at_alpha_floor` | forces.rs | Swimming node moves at alpha floor |
| `behavior_nodes_populated_on_load` | simulation.rs | Correct count + unique seeds |
| `equilibrium_snapshot_on_settle` | simulation.rs | Snapshot matches settled positions |
| `test_archetype_profiles_differ_after_ticks` | simulation.rs | Dreamer > Sentinel drift |
| `test_behavior_disabled_when_static_layout` | simulation.rs | Static layout = zero movement |

## Run All Tests

```bash
cd graph-engine && cargo test 2>&1 | tail -10
```

Expected: All 560+ tests pass (549 existing + 13 new).
