//! # D3-Force Simulation
//!
//! Faithful translation of d3-force's velocity Verlet simulation loop.
//! Each tick: decay alpha → apply forces → integrate (vx *= decay; x += vx).
//!
//! Key difference from the old engine: d3 stores velocity explicitly (vx/vy)
//! and applies velocityDecay as a multiplier. There is no position-Verlet,
//! no mass division, and no ambient Brownian motion.

use rustc_hash::FxHashMap;

use crate::forces;
use crate::quadtree;

/// Center force behavior: attract toward origin, off, or repel away.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum CenterMode {
    Attract = 0,
    Off = 1,
    Repel = 2,
}

impl CenterMode {
    pub fn from_u8(v: u8) -> Self {
        match v {
            1 => Self::Off,
            2 => Self::Repel,
            _ => Self::Attract,
        }
    }
}

/// Force parameters for the graph simulation.
/// Core 4 from LogSeq + extended tuning for smoother, more interactive physics.
#[derive(Clone)]
pub struct ForceParams {
    // ── Core (user-adjustable via basic sliders) ──
    pub link_distance: f32,
    pub charge_strength: f32,
    pub charge_range: f32,
    /// 0 = auto (1/min(deg)), >0 = override.
    pub link_strength: f32,

    // ── Extended (user-adjustable via advanced panel) ──
    /// Velocity damping per tick (0.0 = no friction, 1.0 = frozen).
    /// Lower values → bouncier/fluid; higher → viscous/damped.
    pub velocity_decay: f32,
    /// How strongly nodes are pulled toward center (0 = no pull, 0.1 = strong).
    pub center_strength: f32,
    /// Collision buffer zone in pixels. 0 = overlap allowed.
    pub collision_radius: f32,
    /// Number of collision resolution passes per tick (1-4).
    pub collision_iterations: u32,
    /// Cluster cohesion strength: pulls nodes toward their cluster centroid.
    /// 0 = off (default), 1.0 = strong clustering.
    pub cluster_strength: f32,
    /// Center force mode: Attract (default), Off, or Repel.
    pub center_mode: CenterMode,
    /// Semantic attraction strength: pulls nodes with similar embeddings together.
    /// 0 = off, 1.0 = strong. Default 0.0 (off until embeddings are loaded).
    pub semantic_strength: f32,

    // ── Internal simulation state ──
    pub alpha: f32,
    pub alpha_min: f32,
    pub alpha_decay: f32,
    pub alpha_target: f32,
}

impl Default for ForceParams {
    fn default() -> Self {
        Self {
            // Calm defaults — Logseq-style. Moderate spread, gentle repulsion.
            link_distance: 200.0,
            charge_strength: -400.0,
            charge_range: 1500.0,
            link_strength: 0.0, // auto

            // High damping = viscous, calm movement. Nodes glide, don't bounce.
            velocity_decay: 0.85,
            center_strength: 0.005,
            collision_radius: 20.0,
            collision_iterations: 1,
            cluster_strength: 0.15,
            center_mode: CenterMode::Attract,
            semantic_strength: 0.0,

            // Simulation state — start at lower alpha for gentler onset.
            alpha: 0.3,
            alpha_min: 0.001,
            // d3 default: 1 - pow(0.001, 1/300) ≈ 0.0228
            alpha_decay: 0.0228,
            alpha_target: 0.0,
        }
    }
}

/// The d3-force simulation state.
/// SoA layout for cache efficiency during force computation.
pub struct Simulation {
    // Per-node state (Structure of Arrays)
    pub x: Vec<f32>,
    pub y: Vec<f32>,
    pub vx: Vec<f32>,
    pub vy: Vec<f32>,
    pub fx: Vec<Option<f32>>,
    pub fy: Vec<Option<f32>>,
    pub radii: Vec<f32>,
    pub degrees: Vec<u32>,
    pub collision_radii: Vec<f32>,

    // Per-node cluster assignment (from Louvain community detection).
    pub cluster_ids: Vec<u32>,

    // Edge topology (source_idx, target_idx) with per-edge weights.
    pub edges: Vec<(usize, usize)>,
    /// Per-edge weight (parallel to `edges`). Higher weight = shorter link distance.
    pub edge_weights: Vec<f32>,

    // Maps simulation index → graph node index (for filtered physics).
    pub graph_indices: Vec<usize>,

    // Simulation parameters
    pub params: ForceParams,
    pub is_settled: bool,

    /// Page mode: optional anchor center in world coordinates.
    /// When set, the center force pulls toward this point instead of (0, 0).
    pub anchor_center: Option<[f32; 2]>,

    /// Pre-computed semantic neighbor pairs: (sim_idx_a, sim_idx_b, similarity).
    /// Updated from Engine when embeddings change — NOT per-tick.
    pub semantic_neighbors: Vec<(usize, usize, f32)>,

    /// Lite mode: skip cluster and semantic forces for faster physics at scale.
    pub lite_mode: bool,

    /// Static layout: physics completely disabled for large graphs (> 1500 nodes).
    /// Nodes keep their initial positions. Re-evaluated on every `load_from_graph()`,
    /// so focusing on a small subset automatically re-enables physics.
    pub static_layout: bool,

    // Pre-allocated scratch buffers for physics (avoids per-tick heap allocation).
    collision_grid: FxHashMap<(i32, i32), Vec<usize>>,
    bodies_scratch: Vec<quadtree::Body>,
    // Pre-allocated cluster centroid buffers (avoids per-tick allocation in force_cluster).
    cluster_cx: Vec<f32>,
    cluster_cy: Vec<f32>,
    cluster_counts: Vec<u32>,
    tick_count: u32,
}

impl Default for Simulation {
    fn default() -> Self {
        Self::new()
    }
}

impl Simulation {
    pub fn new() -> Self {
        Self {
            x: Vec::new(),
            y: Vec::new(),
            vx: Vec::new(),
            vy: Vec::new(),
            fx: Vec::new(),
            fy: Vec::new(),
            radii: Vec::new(),
            degrees: Vec::new(),
            collision_radii: Vec::new(),
            cluster_ids: Vec::new(),
            edges: Vec::new(),
            edge_weights: Vec::new(),
            graph_indices: Vec::new(),
            params: ForceParams::default(),
            is_settled: false,
            anchor_center: None,
            semantic_neighbors: Vec::new(),
            lite_mode: false,
            static_layout: false,
            collision_grid: FxHashMap::default(),
            bodies_scratch: Vec::new(),
            cluster_cx: Vec::new(),
            cluster_cy: Vec::new(),
            cluster_counts: Vec::new(),
            tick_count: 0,
        }
    }

    /// Load graph data into the simulation.
    /// Only includes visible nodes. Edges are re-indexed to simulation indices.
    pub fn load_from_graph(&mut self, graph: &crate::types::Graph) {
        self.x.clear();
        self.y.clear();
        self.vx.clear();
        self.vy.clear();
        self.fx.clear();
        self.fy.clear();
        self.radii.clear();
        self.degrees.clear();
        self.collision_radii.clear();
        self.cluster_ids.clear();
        self.edges.clear();
        self.edge_weights.clear();
        self.graph_indices.clear();

        // Map graph node index → simulation index (only visible nodes).
        let mut graph_to_sim: Vec<Option<usize>> = vec![None; graph.nodes.len()];
        for (gi, node) in graph.nodes.iter().enumerate() {
            if !node.visible {
                continue;
            }
            let si = self.x.len();
            graph_to_sim[gi] = Some(si);
            self.graph_indices.push(gi);

            self.x.push(node.x);
            self.y.push(node.y);
            self.vx.push(node.vx);
            self.vy.push(node.vy);
            self.fx.push(node.fx);
            self.fy.push(node.fy);
            self.radii.push(node.radius);
            self.degrees.push(0); // computed below
            self.collision_radii.push(self.params.collision_radius);
        }

        // Static layout for large graphs: no physics at all.
        // Skip expensive edge processing — nodes keep spiral/loaded positions.
        // When user focuses on a subset, visible count drops below threshold
        // and physics re-enables automatically via the next load_from_graph().
        let node_count = self.x.len();
        const STATIC_LAYOUT_THRESHOLD: usize = 1500;
        if node_count > STATIC_LAYOUT_THRESHOLD {
            self.static_layout = true;
            self.is_settled = true;
            self.params.alpha = 0.0;
            // Zero out all velocities — no residual drift.
            for v in &mut self.vx { *v = 0.0; }
            for v in &mut self.vy { *v = 0.0; }
            // Still compute degrees from raw edge data (needed for node radius sizing)
            // but skip sorting/capping since physics won't run.
            for edge in &graph.edges {
                let si_src = graph
                    .id_to_index
                    .get(&edge.source)
                    .and_then(|&gi| graph_to_sim[gi]);
                let si_tgt = graph
                    .id_to_index
                    .get(&edge.target)
                    .and_then(|&gi| graph_to_sim[gi]);
                if let (Some(src), Some(tgt)) = (si_src, si_tgt) {
                    self.degrees[src] += 1;
                    self.degrees[tgt] += 1;
                }
            }
            for d in &mut self.degrees {
                if *d == 0 { *d = 1; }
            }
            return;
        }

        self.static_layout = false;

        // Re-index edges to simulation indices, compute degrees.
        // Cap physics edges per node to prevent jitter from hyper-connected nodes.
        // Data stays in SwiftData — only the physics simulation is simplified.
        // Edge cap values tuned empirically: enough structure to see clusters,
        // few enough to prevent competing-force jitter.
        let max_physics_edges_per_node: u32 = if node_count > 500 { 12 } else { 20 };

        // First pass: collect and sort edges by weight (highest first = structural edges kept).
        let mut candidate_edges: Vec<(usize, usize, f32)> = Vec::with_capacity(graph.edges.len());
        for edge in &graph.edges {
            let si_src = graph
                .id_to_index
                .get(&edge.source)
                .and_then(|&gi| graph_to_sim[gi]);
            let si_tgt = graph
                .id_to_index
                .get(&edge.target)
                .and_then(|&gi| graph_to_sim[gi]);

            if let (Some(src), Some(tgt)) = (si_src, si_tgt) {
                candidate_edges.push((src, tgt, edge.weight));
            }
        }
        // Sort descending by weight — structural/containment edges (weight > 1) come first.
        candidate_edges.sort_unstable_by(|a, b| b.2.partial_cmp(&a.2).unwrap_or(std::cmp::Ordering::Equal));

        // Second pass: add edges, skipping if either endpoint is over the cap.
        let mut edge_counts: Vec<u32> = vec![0; self.x.len()];
        for (src, tgt, weight) in candidate_edges {
            if edge_counts[src] >= max_physics_edges_per_node
                && edge_counts[tgt] >= max_physics_edges_per_node
            {
                continue; // Both endpoints saturated — skip entirely.
            }
            self.edges.push((src, tgt));
            self.edge_weights.push(weight);
            self.degrees[src] += 1;
            self.degrees[tgt] += 1;
            edge_counts[src] += 1;
            edge_counts[tgt] += 1;
        }

        // Ensure minimum degree of 1 for link strength calculation.
        for d in &mut self.degrees {
            if *d == 0 {
                *d = 1;
            }
        }

        // Scale force parameters for medium graphs (500-1500 nodes).
        if node_count > 500 {
            self.params.link_distance = self.params.link_distance.min(180.0);
            self.params.velocity_decay = self.params.velocity_decay.max(0.85);
        }

        // Reset alpha for fresh simulation — calm start.
        self.params.alpha = if node_count > 500 {
            0.2
        } else {
            0.3
        };
        self.is_settled = false;
    }

    /// One tick of the force simulation.
    /// d3-style velocity Verlet: alpha decay → forces → integration.
    pub fn tick(&mut self) {
        if self.x.is_empty() || self.static_layout {
            return;
        }

        let n = self.x.len();

        // 1. Alpha decay
        self.params.alpha +=
            (self.params.alpha_target - self.params.alpha) * self.params.alpha_decay;

        // Don't settle while any node is fixed (being dragged) — neighbors
        // still need forces applied to smoothly adjust around the dragged node.
        let any_fixed = self.fx.iter().any(|f| f.is_some());
        if self.params.alpha < self.params.alpha_min && !any_fixed {
            self.is_settled = true;
            return;
        }
        self.is_settled = false;

        let alpha = self.params.alpha;

        // 2. Apply forces in d3/LogSeq order: link → many-body → collide → center

        // Link force (springs along edges, per-edge weight modulates distance)
        forces::force_link(
            &self.x,
            &self.y,
            &mut self.vx,
            &mut self.vy,
            &self.edges,
            &self.edge_weights,
            &self.degrees,
            self.params.link_distance,
            self.params.link_strength,
            alpha,
        );

        // Many-body force (Barnes-Hut repulsion) — reuses scratch buffer.
        self.bodies_scratch.clear();
        forces::force_many_body_with_scratch(
            &self.x,
            &self.y,
            &mut self.vx,
            &mut self.vy,
            self.params.charge_strength,
            self.params.charge_range,
            1.0, // distance_min (d3 default)
            alpha,
            &mut self.bodies_scratch,
        );

        // Collision force (position-based overlap prevention) — reuses scratch grid.
        // Passes fx/fy so fixed (dragged) nodes don't get pushed by collision.
        // Full clear every 120 ticks to prevent stale key accumulation.
        self.tick_count = self.tick_count.wrapping_add(1);
        if self.tick_count % 120 == 0 {
            self.collision_grid.clear();
        } else {
            for v in self.collision_grid.values_mut() {
                v.clear();
            }
        }
        forces::force_collide_with_scratch(
            &mut self.x,
            &mut self.y,
            &self.collision_radii,
            &self.fx,
            &self.fy,
            self.params.collision_iterations,
            &mut self.collision_grid,
        );

        // Center force: pull toward anchor (page mode) or origin (global mode).
        let (cx, cy) = match self.anchor_center {
            Some([ax, ay]) => (ax, ay),
            None => (0.0, 0.0),
        };
        let center_str = match self.params.center_mode {
            CenterMode::Attract => self.params.center_strength,
            CenterMode::Off => 0.0,
            CenterMode::Repel => -self.params.center_strength,
        };
        if center_str.abs() > 0.0001 {
            forces::force_center(
                &self.x,
                &self.y,
                &mut self.vx,
                &mut self.vy,
                cx,
                cy,
                center_str,
                alpha,
            );
        }

        // Cluster cohesion force (skipped in lite mode).
        // Uses pre-allocated centroid buffers to avoid per-tick allocation.
        if !self.lite_mode && self.params.cluster_strength > 0.001 && !self.cluster_ids.is_empty() {
            forces::force_cluster_with_scratch(
                &self.x,
                &self.y,
                &mut self.vx,
                &mut self.vy,
                &self.cluster_ids,
                self.params.cluster_strength,
                alpha,
                &mut self.cluster_cx,
                &mut self.cluster_cy,
                &mut self.cluster_counts,
            );
        }

        // Semantic attraction force (skipped in lite mode).
        if !self.lite_mode && self.params.semantic_strength > 0.001 && !self.semantic_neighbors.is_empty() {
            forces::force_semantic(
                &self.x,
                &self.y,
                &mut self.vx,
                &mut self.vy,
                &self.semantic_neighbors,
                self.params.semantic_strength,
                self.params.link_distance,
                alpha,
            );
        }

        // 3. Velocity Verlet integration with decay.
        // High-degree nodes get extra damping via smoothstep to prevent jitter.
        for i in 0..n {
            let decay = if self.degrees[i] >= 10 {
                // Smoothstep: gradual onset from degree 10, saturates at degree 40.
                let t = ((self.degrees[i] - 10) as f32 / 30.0).min(1.0);
                let smooth = t * t * (3.0 - 2.0 * t); // Hermite smoothstep
                self.params.velocity_decay + smooth * (0.95 - self.params.velocity_decay)
            } else {
                self.params.velocity_decay
            };

            if let Some(fx_val) = self.fx[i] {
                self.x[i] = fx_val;
                self.vx[i] = 0.0;
            } else {
                self.vx[i] *= decay;
                self.x[i] += self.vx[i];
            }
            if let Some(fy_val) = self.fy[i] {
                self.y[i] = fy_val;
                self.vy[i] = 0.0;
            } else {
                self.vy[i] *= decay;
                self.y[i] += self.vy[i];
            }
        }
    }

    /// Reheat the simulation (for user parameter changes or data reload).
    /// No-op when in static layout mode (large graphs with physics disabled).
    pub fn reheat(&mut self) {
        if self.static_layout {
            return;
        }
        self.params.alpha = 0.3;
        self.is_settled = false;
    }

    /// Configure simulation for calm entrance (Obsidian-style slow build-out).
    ///
    /// Nodes start in a phyllotaxis spiral at near-equilibrium spacing.
    /// Physics begins at very low alpha (gentle forces) with high damping
    /// (viscous movement). Alpha ramps up gradually via `entrance_tick()`.
    /// Result: nodes drift smoothly into clusters instead of exploding.
    pub fn set_entrance_mode(&mut self) {
        let n = self.x.len();
        if n > 10_000 {
            // Massive graph: barely visible forces, very viscous.
            self.params.alpha = 0.03;
            self.params.velocity_decay = self.params.velocity_decay.max(0.92);
            self.params.alpha_decay = 0.0;  // Manual ramp, not auto-decay.
        } else if n > 5000 {
            self.params.alpha = 0.04;
            self.params.velocity_decay = self.params.velocity_decay.max(0.90);
            self.params.alpha_decay = 0.0;
        } else if n > 1000 {
            self.params.alpha = 0.05;
            self.params.velocity_decay = self.params.velocity_decay.max(0.88);
            self.params.alpha_decay = 0.0;
        } else {
            // Small graph: slightly more energy, still very damped.
            self.params.alpha = 0.06;
            self.params.velocity_decay = 0.85;
            self.params.alpha_decay = 0.0;
        }
        self.tick_count = 0;
        self.is_settled = false;
    }

    /// One tick during entrance: gradually ramps alpha from whisper to cruise,
    /// then switches to normal alpha decay for settling. Call this instead of
    /// `tick()` during the entrance phase.
    pub fn entrance_tick(&mut self) {
        if self.x.is_empty() || self.static_layout {
            return;
        }

        // Use tick_count for phase detection. Note: tick() also increments tick_count,
        // so we read BEFORE calling tick() to get consistent phase timing.
        // tick_count is incremented inside tick() (line ~387), not here.
        let t = self.tick_count.wrapping_add(1);

        // Phase 1 (ticks 0–60, ~1s): ramp alpha gently from starting value to cruise.
        // Phase 2 (ticks 61–180, ~2s): hold at cruise alpha.
        // Phase 3 (ticks 181+): switch to normal alpha decay for settling.
        let n = self.x.len();
        let (cruise_alpha, ramp_ticks, hold_ticks) = if n > 10_000 {
            (0.15, 90u32, 120u32)
        } else if n > 5000 {
            (0.20, 75, 100)
        } else if n > 1000 {
            (0.25, 60, 90)
        } else {
            (0.30, 45, 70)
        };

        if t <= ramp_ticks {
            // Smooth ease-in: cubic ramp from start_alpha to cruise_alpha.
            let progress = t as f32 / ramp_ticks as f32;
            let eased = progress * progress * (3.0 - 2.0 * progress); // smoothstep
            let start_alpha = if n > 10_000 { 0.03 } else if n > 5000 { 0.04 } else if n > 1000 { 0.05 } else { 0.06 };
            self.params.alpha = start_alpha + (cruise_alpha - start_alpha) * eased;
            self.params.alpha_decay = 0.0;
        } else if t <= ramp_ticks + hold_ticks {
            // Hold at cruise alpha — forces are stable, nodes organize.
            self.params.alpha = cruise_alpha;
            self.params.alpha_decay = 0.0;
        } else {
            // Switch to normal decay for final settling.
            if self.params.alpha_decay < 0.001 {
                self.params.alpha = cruise_alpha;
                self.params.alpha_decay = if n > 5000 { 0.035 } else { 0.0228 };
            }
        }

        // Run the actual physics tick.
        self.tick();
    }

    /// Set fixed position for a node (drag constraint, d3 style).
    /// While fixed, the node snaps to (fx, fy) and velocity is zeroed.
    pub fn fix_node(&mut self, sim_index: usize, fx: f32, fy: f32) {
        if sim_index < self.x.len() {
            self.fx[sim_index] = Some(fx);
            self.fy[sim_index] = Some(fy);
        }
    }

    /// Release a fixed node (end drag).
    /// Zeroes velocity so the node doesn't fly off from residual force accumulation.
    pub fn unfix_node(&mut self, sim_index: usize) {
        if sim_index < self.x.len() {
            self.fx[sim_index] = None;
            self.fy[sim_index] = None;
            self.vx[sim_index] = 0.0;
            self.vy[sim_index] = 0.0;
        }
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::Graph;

    fn make_test_graph(n: usize, connect: bool) -> Graph {
        let mut g = Graph::new();
        for i in 0..n {
            let angle = 2.0 * std::f32::consts::PI * (i as f32) / (n as f32);
            let r = 200.0;
            g.add_node(
                format!("node-{}", i),
                r * angle.cos(),
                r * angle.sin(),
                0,
                if connect { 2 } else { 1 },
                format!("Node {}", i),
            );
        }
        if connect {
            for i in 0..n {
                let j = (i + 1) % n;
                let uuid_i = format!("node-{}", i);
                let uuid_j = format!("node-{}", j);
                g.add_edge(&uuid_i, &uuid_j, 1.0, 0);
            }
        }
        g
    }

    #[test]
    fn simulation_settles() {
        let graph = make_test_graph(10, true);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        // Run 400 ticks (d3 default: ~300 ticks to settle).
        for _ in 0..400 {
            sim.tick();
        }

        assert!(sim.is_settled, "simulation should settle within 400 ticks");
    }

    #[test]
    fn simulation_reheat() {
        let graph = make_test_graph(5, true);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        // Settle.
        for _ in 0..500 {
            sim.tick();
        }
        assert!(sim.is_settled);

        // Reheat.
        sim.reheat();
        assert!(!sim.is_settled);
        assert!(sim.params.alpha > 0.1);

        // Should eventually settle again.
        for _ in 0..300 {
            sim.tick();
        }
        assert!(sim.is_settled);
    }

    #[test]
    fn fixed_node_stays_put() {
        let graph = make_test_graph(5, true);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        // Fix node 0 at (42, 99).
        sim.fix_node(0, 42.0, 99.0);

        for _ in 0..100 {
            sim.tick();
        }

        assert!((sim.x[0] - 42.0).abs() < f32::EPSILON);
        assert!((sim.y[0] - 99.0).abs() < f32::EPSILON);
        assert_eq!(sim.vx[0], 0.0);
        assert_eq!(sim.vy[0], 0.0);
    }

    #[test]
    fn unfix_allows_movement() {
        let graph = make_test_graph(5, true);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        sim.fix_node(0, 500.0, 500.0);
        sim.tick();
        sim.unfix_node(0);

        // After unfixing, forces should move the node.
        let x_before = sim.x[0];
        for _ in 0..10 {
            sim.tick();
        }
        assert!(
            (sim.x[0] - x_before).abs() > 0.01,
            "unfixed node should move"
        );
    }

    #[test]
    fn edges_re_indexed_correctly() {
        let graph = make_test_graph(3, true);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        assert_eq!(sim.edges.len(), 3); // 3 nodes in a ring = 3 edges
        for &(s, t) in &sim.edges {
            assert!(s < sim.x.len());
            assert!(t < sim.x.len());
        }
    }

    #[test]
    fn invisible_nodes_excluded() {
        let mut graph = make_test_graph(5, true);
        graph.nodes[0].visible = false;
        graph.nodes[1].visible = false;

        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        assert_eq!(sim.x.len(), 3, "only 3 visible nodes should be loaded");
        assert_eq!(sim.graph_indices.len(), 3);
    }

    #[test]
    fn alpha_decays_monotonically() {
        let graph = make_test_graph(5, true);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        let mut prev_alpha = sim.params.alpha;
        for _ in 0..100 {
            sim.tick();
            assert!(
                sim.params.alpha <= prev_alpha,
                "alpha should decay monotonically"
            );
            prev_alpha = sim.params.alpha;
        }
    }

    #[test]
    fn default_params_match_observatory() {
        let p = ForceParams::default();
        assert_eq!(p.link_distance, 200.0);
        assert_eq!(p.charge_strength, -400.0);
        assert_eq!(p.charge_range, 1500.0);
        assert_eq!(p.velocity_decay, 0.85);
        assert_eq!(p.center_strength, 0.005);
        assert_eq!(p.collision_radius, 20.0);
        assert_eq!(p.collision_iterations, 1);
        assert_eq!(p.cluster_strength, 0.15);
        assert_eq!(p.center_mode, CenterMode::Attract);
    }

    #[test]
    fn two_connected_nodes_reach_equilibrium() {
        let mut graph = Graph::new();
        graph.add_node("a".into(), -100.0, 0.0, 0, 1, "A".into());
        graph.add_node("b".into(), 100.0, 0.0, 0, 1, "B".into());
        graph.add_edge("a", "b", 1.0, 0);

        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        for _ in 0..500 {
            sim.tick();
        }

        let dist = ((sim.x[1] - sim.x[0]).powi(2) + (sim.y[1] - sim.y[0]).powi(2)).sqrt();
        // Should settle near link_distance (180) but repulsion pushes further.
        // The equilibrium is where link force = repulsion force.
        assert!(
            dist > 50.0 && dist < 500.0,
            "expected equilibrium distance between 50 and 500, got {}",
            dist
        );
    }

}
