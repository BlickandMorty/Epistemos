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
            // Tuned for observatory layout: more spread, less clumping.
            link_distance: 250.0,
            charge_strength: -1200.0,
            charge_range: 2000.0,
            link_strength: 0.0, // auto

            // Higher = more viscous/damped, less bouncy.
            // 0.60 = 40% damping per tick — settles faster with less oscillation.
            velocity_decay: 0.60,
            center_strength: 0.005,
            collision_radius: 35.0,
            collision_iterations: 1,
            cluster_strength: 0.3,
            center_mode: CenterMode::Attract,
            semantic_strength: 0.0,

            // Simulation state
            alpha: 1.0,
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

    // Pre-allocated scratch buffers for physics (avoids per-tick heap allocation).
    collision_grid: FxHashMap<(i32, i32), Vec<usize>>,
    bodies_scratch: Vec<quadtree::Body>,
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
            collision_grid: FxHashMap::default(),
            bodies_scratch: Vec::new(),
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

        // Re-index edges to simulation indices, compute degrees.
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
                self.edges.push((src, tgt));
                self.edge_weights.push(edge.weight);
                self.degrees[src] += 1;
                self.degrees[tgt] += 1;
            }
        }

        // Ensure minimum degree of 1 for link strength calculation.
        for d in &mut self.degrees {
            if *d == 0 {
                *d = 1;
            }
        }

        // Scale force parameters for large graphs to prevent chaos and improve settling.
        // Larger graphs need tighter layout, more damping, and faster alpha decay
        // so the physics settle quickly instead of bouncing for 5+ seconds.
        let node_count = self.x.len();
        if node_count > 10_000 {
            // Massive graph (10K-30K+): very tight, very viscous, fast settle.
            self.params.link_distance = self.params.link_distance.min(60.0);
            self.params.charge_strength = self.params.charge_strength.max(-300.0);
            self.params.charge_range = self.params.charge_range.min(500.0);
            self.params.velocity_decay = self.params.velocity_decay.max(0.88);
            self.params.collision_iterations = self.params.collision_iterations.max(3);
            self.params.collision_radius = self.params.collision_radius.min(12.0);
            self.params.center_strength = self.params.center_strength.max(0.02);
            // Fast alpha decay: settle in ~80 ticks instead of 300.
            self.params.alpha_decay = self.params.alpha_decay.max(0.06);
        } else if node_count > 5000 {
            // Large graph (5K-10K): tight, damped, faster settle.
            self.params.link_distance = self.params.link_distance.min(80.0);
            self.params.charge_strength = self.params.charge_strength.max(-500.0);
            self.params.charge_range = self.params.charge_range.min(800.0);
            self.params.velocity_decay = self.params.velocity_decay.max(0.82);
            self.params.collision_iterations = self.params.collision_iterations.max(2);
            self.params.collision_radius = self.params.collision_radius.min(20.0);
            self.params.alpha_decay = self.params.alpha_decay.max(0.045);
        } else if node_count > 2000 {
            self.params.link_distance = self.params.link_distance.min(120.0);
            self.params.charge_strength = self.params.charge_strength.max(-800.0);
            self.params.velocity_decay = self.params.velocity_decay.max(0.70);
            self.params.collision_iterations = self.params.collision_iterations.max(2);
            self.params.alpha_decay = self.params.alpha_decay.max(0.035);
        } else if node_count > 500 {
            self.params.link_distance = self.params.link_distance.min(180.0);
            self.params.velocity_decay = self.params.velocity_decay.max(0.65);
        }

        // Reset alpha for fresh simulation.
        // At very large scales, start with lower alpha to avoid explosive first ticks.
        self.params.alpha = if node_count > 10_000 { 0.5 } else { 1.0 };
        self.is_settled = false;
    }

    /// One tick of the force simulation.
    /// d3-style velocity Verlet: alpha decay → forces → integration.
    pub fn tick(&mut self) {
        if self.x.is_empty() {
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
        for v in self.collision_grid.values_mut() {
            v.clear();
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
        if !self.lite_mode && self.params.cluster_strength > 0.001 && !self.cluster_ids.is_empty() {
            forces::force_cluster(
                &self.x,
                &self.y,
                &mut self.vx,
                &mut self.vy,
                &self.cluster_ids,
                self.params.cluster_strength,
                alpha,
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

        // 3. Velocity Verlet integration with decay
        for i in 0..n {
            if let Some(fx_val) = self.fx[i] {
                self.x[i] = fx_val;
                self.vx[i] = 0.0;
            } else {
                self.vx[i] *= self.params.velocity_decay;
                self.x[i] += self.vx[i];
            }
            if let Some(fy_val) = self.fy[i] {
                self.y[i] = fy_val;
                self.vy[i] = 0.0;
            } else {
                self.vy[i] *= self.params.velocity_decay;
                self.y[i] += self.vy[i];
            }
        }
    }

    /// Reheat the simulation (for user parameter changes or data reload).
    pub fn reheat(&mut self) {
        self.params.alpha = 0.3;
        self.is_settled = false;
    }

    /// Configure simulation for entrance animation (Obsidian-style calm build-out).
    /// Lower alpha = gentler forces; higher velocity_decay = more damping (nodes move slowly);
    /// slower alpha_decay = animation lasts longer before settling.
    pub fn set_entrance_mode(&mut self) {
        let n = self.x.len();
        if n > 10_000 {
            // Massive graph: start very low energy, settle fast.
            self.params.alpha = 0.15;
            self.params.velocity_decay = self.params.velocity_decay.max(0.88);
            self.params.alpha_decay = 0.04;
        } else if n > 5000 {
            self.params.alpha = 0.20;
            self.params.velocity_decay = self.params.velocity_decay.max(0.80);
            self.params.alpha_decay = 0.025;
        } else {
            self.params.alpha = 0.25;
            self.params.velocity_decay = 0.72;
            self.params.alpha_decay = 0.012;
        }
        self.is_settled = false;
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
        assert_eq!(p.link_distance, 250.0);
        assert_eq!(p.charge_strength, -1200.0);
        assert_eq!(p.charge_range, 2000.0);
        assert_eq!(p.velocity_decay, 0.60);
        assert_eq!(p.center_strength, 0.005);
        assert_eq!(p.collision_radius, 35.0);
        assert_eq!(p.collision_iterations, 1);
        assert_eq!(p.cluster_strength, 0.3);
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
