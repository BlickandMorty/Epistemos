use glam::Vec2;
use rustc_hash::FxHashMap;

// ── Barnes-Hut Quad Tree ────────────────────────────────────────────────────

/// Threshold ratio for Barnes-Hut approximation.
/// Higher = faster but less accurate. 0.9 is a good balance for graph layout.
const THETA: f32 = 0.9;

/// Maximum quad tree depth to prevent infinite recursion on coincident nodes.
const MAX_DEPTH: u32 = 20;

/// A node in the quad tree. Stores either a single body or subdivided children.
struct QTNode {
    center_of_mass: Vec2,
    total_mass: f32,
    bounds: Rect,
    body_index: Option<usize>,
    children: Option<Box<[Option<QTNode>; 4]>>,
}

#[derive(Clone, Copy)]
struct Rect {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
}

impl Rect {
    fn quadrant(&self, idx: usize) -> Rect {
        let hw = self.w * 0.5;
        let hh = self.h * 0.5;
        match idx {
            0 => Rect { x: self.x, y: self.y, w: hw, h: hh },           // NW
            1 => Rect { x: self.x + hw, y: self.y, w: hw, h: hh },      // NE
            2 => Rect { x: self.x, y: self.y + hh, w: hw, h: hh },      // SW
            _ => Rect { x: self.x + hw, y: self.y + hh, w: hw, h: hh }, // SE
        }
    }

    fn contains(&self, p: Vec2) -> bool {
        p.x >= self.x && p.x < self.x + self.w && p.y >= self.y && p.y < self.y + self.h
    }

    fn quadrant_for(&self, p: Vec2) -> usize {
        let mx = self.x + self.w * 0.5;
        let my = self.y + self.h * 0.5;
        if p.y < my {
            if p.x < mx { 0 } else { 1 }
        } else {
            if p.x < mx { 2 } else { 3 }
        }
    }
}

impl QTNode {
    fn new(bounds: Rect) -> Self {
        Self {
            center_of_mass: Vec2::ZERO,
            total_mass: 0.0,
            bounds,
            body_index: None,
            children: None,
        }
    }

    fn insert(&mut self, idx: usize, pos: Vec2, mass: f32, depth: u32) {
        if depth > MAX_DEPTH { return; }

        // Update center of mass
        let new_mass = self.total_mass + mass;
        if new_mass > 0.0 {
            self.center_of_mass =
                (self.center_of_mass * self.total_mass + pos * mass) / new_mass;
        }
        self.total_mass = new_mass;

        if self.children.is_some() {
            // Already subdivided — insert into correct child
            let qi = self.bounds.quadrant_for(pos);
            let children = self.children.as_mut().unwrap();
            if children[qi].is_none() {
                children[qi] = Some(QTNode::new(self.bounds.quadrant(qi)));
            }
            children[qi].as_mut().unwrap().insert(idx, pos, mass, depth + 1);
            return;
        }

        if self.body_index.is_none() {
            // Empty leaf — store this body
            self.body_index = Some(idx);
            return;
        }

        // Leaf with existing body — subdivide
        let old_idx = self.body_index.take().unwrap();
        self.children = Some(Box::new([None, None, None, None]));

        // Re-insert the existing body (use center_of_mass as approximation of old position)
        // We need the old position, but we only have center_of_mass which was just updated.
        // Fix: we need to pass positions array. Instead, store old pos in center_of_mass before update.
        // Actually, the simpler approach: pass positions slice to insert.
        // Let me restructure this.
        // For now, the old body was at the old center_of_mass (before we updated it).
        let old_pos = (self.center_of_mass * new_mass - pos * mass) / (new_mass - mass);
        let old_mass = new_mass - mass;

        let qi = self.bounds.quadrant_for(old_pos);
        let children = self.children.as_mut().unwrap();
        if children[qi].is_none() {
            children[qi] = Some(QTNode::new(self.bounds.quadrant(qi)));
        }
        children[qi].as_mut().unwrap().insert(old_idx, old_pos, old_mass, depth + 1);

        // Insert new body
        let qi2 = self.bounds.quadrant_for(pos);
        if children[qi2].is_none() {
            children[qi2] = Some(QTNode::new(self.bounds.quadrant(qi2)));
        }
        children[qi2].as_mut().unwrap().insert(idx, pos, mass, depth + 1);
    }

    fn compute_force(&self, pos: Vec2, repulsion: f32) -> Vec2 {
        if self.total_mass == 0.0 { return Vec2::ZERO; }

        let diff = pos - self.center_of_mass;
        let dist_sq = diff.length_squared().max(1.0);
        let dist = dist_sq.sqrt();

        // If this is a leaf or sufficiently far away, use approximation
        if self.children.is_none() || (self.bounds.w / dist) < THETA {
            // Coulomb-like repulsion: F = repulsion * mass / dist²
            let force_mag = repulsion * self.total_mass / dist_sq;
            return diff.normalize_or_zero() * force_mag;
        }

        // Recurse into children
        let mut force = Vec2::ZERO;
        if let Some(children) = &self.children {
            for child in children.iter() {
                if let Some(c) = child {
                    force += c.compute_force(pos, repulsion);
                }
            }
        }
        force
    }
}

// ── Force Simulation ────────────────────────────────────────────────────────

/// Force-directed layout simulation parameters.
pub struct ForceConfig {
    pub repulsion: f32,
    pub attraction: f32,
    pub damping: f32,
    pub alpha: f32,
    pub alpha_min: f32,
    pub alpha_decay: f32,
    pub alpha_target: f32,
    pub velocity_decay: f32,
    pub center_x: f32,
    pub center_y: f32,
    pub center_strength: f32,
}

impl Default for ForceConfig {
    fn default() -> Self {
        Self {
            repulsion: 800.0,
            attraction: 0.005,
            damping: 0.3,
            alpha: 1.0,
            alpha_min: 0.001,
            alpha_decay: 0.0228, // ~300 iterations to cool (1 - (0.001)^(1/300))
            alpha_target: 0.0,
            velocity_decay: 0.6,
            center_x: 500.0,
            center_y: 350.0,
            center_strength: 0.02,
        }
    }
}

/// Per-node physics state, kept in flat arrays for cache-friendly iteration.
pub struct PhysicsState {
    pub positions: Vec<Vec2>,
    pub velocities: Vec<Vec2>,
    pub masses: Vec<f32>,
    pub edges: Vec<(u32, u32, f32)>, // (source_id, target_id, weight)
    pub graph_indices: Vec<usize>,   // maps physics index -> graph node index
    pub config: ForceConfig,
    pub is_settled: bool,
}

impl PhysicsState {
    pub fn new() -> Self {
        Self {
            positions: Vec::new(),
            velocities: Vec::new(),
            masses: Vec::new(),
            edges: Vec::new(),
            graph_indices: Vec::new(),
            config: ForceConfig::default(),
            is_settled: false,
        }
    }

    /// Load physics state from the graph. Call after graph_engine_commit.
    pub fn load_from_graph(&mut self, graph: &crate::types::Graph) {
        let n = graph.nodes.len();
        self.positions.clear();
        self.velocities.clear();
        self.masses.clear();
        self.edges.clear();

        self.positions.reserve(n);
        self.velocities.reserve(n);
        self.masses.reserve(n);

        for node in &graph.nodes {
            self.positions.push(node.pos);
            self.velocities.push(node.vel);
            self.masses.push(node.weight.max(1.0));
        }

        // Identity mapping: physics index i == graph index i
        self.graph_indices = (0..n).collect();

        self.edges.reserve(graph.edges.len());
        for edge in &graph.edges {
            self.edges.push((edge.source, edge.target, edge.weight));
        }

        self.config.alpha = 1.0;
        self.is_settled = false;
    }

    /// Load physics state from graph, including only visible nodes.
    /// Builds a compact physics array and maps indices back to graph positions.
    pub fn load_from_graph_filtered(&mut self, graph: &crate::types::Graph) {
        self.positions.clear();
        self.velocities.clear();
        self.masses.clear();
        self.edges.clear();
        self.graph_indices.clear();

        // Build ID -> physics_index map for visible nodes only
        let mut id_to_phys: FxHashMap<u32, usize> = FxHashMap::default();

        for (graph_idx, node) in graph.nodes.iter().enumerate() {
            if !node.visible { continue; }
            let phys_idx = self.positions.len();
            id_to_phys.insert(node.id, phys_idx);
            self.positions.push(node.pos);
            self.velocities.push(node.vel);
            self.masses.push(node.weight.max(1.0));
            self.graph_indices.push(graph_idx);
        }

        // Only include edges where both endpoints are visible
        for edge in &graph.edges {
            if let (Some(&si), Some(&ti)) = (id_to_phys.get(&edge.source), id_to_phys.get(&edge.target)) {
                self.edges.push((si as u32, ti as u32, edge.weight));
            }
        }

        self.config.alpha = 0.3; // Gentle reheat on filter change
        self.is_settled = false;
    }

    /// Run one tick of the force simulation.
    pub fn tick(&mut self) {
        if self.is_settled || self.positions.is_empty() { return; }

        let n = self.positions.len();
        let alpha = self.config.alpha;

        // ── 1. Alpha decay (D3-style) ───────────────────────────────────
        self.config.alpha += (self.config.alpha_target - self.config.alpha) * self.config.alpha_decay;
        if self.config.alpha < self.config.alpha_min {
            self.is_settled = true;
            return;
        }

        // ── 2. Build Barnes-Hut quad tree ───────────────────────────────
        let (mut min_x, mut min_y) = (f32::MAX, f32::MAX);
        let (mut max_x, mut max_y) = (f32::MIN, f32::MIN);
        for p in &self.positions {
            min_x = min_x.min(p.x);
            min_y = min_y.min(p.y);
            max_x = max_x.max(p.x);
            max_y = max_y.max(p.y);
        }
        // Add padding to prevent zero-size bounds
        let pad = 10.0;
        min_x -= pad;
        min_y -= pad;
        let w = (max_x - min_x + 2.0 * pad).max(1.0);
        let h = (max_y - min_y + 2.0 * pad).max(1.0);
        let size = w.max(h); // Square bounds for consistent theta

        let bounds = Rect { x: min_x, y: min_y, w: size, h: size };
        let mut tree = QTNode::new(bounds);

        for i in 0..n {
            tree.insert(i, self.positions[i], self.masses[i], 0);
        }

        // ── 3. Repulsion via Barnes-Hut ─────────────────────────────────
        let mut forces = vec![Vec2::ZERO; n];
        for i in 0..n {
            forces[i] += tree.compute_force(self.positions[i], self.config.repulsion);
        }

        // ── 4. Attraction along edges (Hooke's spring) ─────────────────
        for &(src, tgt, weight) in &self.edges {
            let si = src as usize;
            let ti = tgt as usize;
            if si >= n || ti >= n { continue; }

            let diff = self.positions[ti] - self.positions[si];
            let dist = diff.length().max(1.0);
            let target_len = 100.0; // Natural spring length
            let displacement = dist - target_len;
            let strength = self.config.attraction * weight;
            let f = diff.normalize_or_zero() * displacement * strength;

            forces[si] += f;
            forces[ti] -= f;
        }

        // ── 5. Center gravity ───────────────────────────────────────────
        let center = Vec2::new(self.config.center_x, self.config.center_y);
        for i in 0..n {
            let to_center = center - self.positions[i];
            forces[i] += to_center * self.config.center_strength;
        }

        // ── 6. Apply forces with alpha and velocity decay ───────────────
        for i in 0..n {
            self.velocities[i] += forces[i] * alpha;
            self.velocities[i] *= self.config.velocity_decay;

            // Clamp velocity to prevent explosions
            let speed = self.velocities[i].length();
            if speed > 50.0 {
                self.velocities[i] *= 50.0 / speed;
            }

            self.positions[i] += self.velocities[i];
        }
    }

    /// Write updated positions back to graph nodes using graph_indices mapping.
    pub fn write_back(&self, graph: &mut crate::types::Graph) {
        for (phys_idx, &graph_idx) in self.graph_indices.iter().enumerate() {
            if phys_idx < self.positions.len() && graph_idx < graph.nodes.len() {
                graph.nodes[graph_idx].pos = self.positions[phys_idx];
                graph.nodes[graph_idx].vel = self.velocities[phys_idx];
            }
        }
    }

    /// Reheat the simulation (e.g. after dragging a node).
    pub fn reheat(&mut self) {
        self.config.alpha = 0.3;
        self.is_settled = false;
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn two_nodes_repel() {
        let mut state = PhysicsState::new();
        state.positions = vec![Vec2::new(0.0, 0.0), Vec2::new(10.0, 0.0)];
        state.velocities = vec![Vec2::ZERO, Vec2::ZERO];
        state.masses = vec![1.0, 1.0];
        state.config.center_strength = 0.0; // Disable centering for clean test
        state.config.alpha = 1.0;
        state.config.alpha_min = 0.0;

        state.tick();

        // Node 0 should move left (away from node 1)
        assert!(state.positions[0].x < 0.0, "Node 0 should move left, got {}", state.positions[0].x);
        // Node 1 should move right (away from node 0)
        assert!(state.positions[1].x > 10.0, "Node 1 should move right, got {}", state.positions[1].x);
    }

    #[test]
    fn connected_nodes_attract() {
        let mut state = PhysicsState::new();
        // Place nodes far apart so attraction > repulsion
        state.positions = vec![Vec2::new(0.0, 0.0), Vec2::new(500.0, 0.0)];
        state.velocities = vec![Vec2::ZERO, Vec2::ZERO];
        state.masses = vec![1.0, 1.0];
        state.edges = vec![(0, 1, 5.0)]; // Strong edge
        state.config.center_strength = 0.0;
        state.config.repulsion = 100.0; // Reduce repulsion
        state.config.attraction = 0.1;  // Strong attraction
        state.config.alpha = 1.0;
        state.config.alpha_min = 0.0;

        let initial_dist = 500.0;
        state.tick();

        let new_dist = (state.positions[1] - state.positions[0]).length();
        assert!(new_dist < initial_dist, "Nodes should get closer: {} vs {}", new_dist, initial_dist);
    }

    #[test]
    fn simulation_settles() {
        let mut state = PhysicsState::new();
        state.positions = vec![Vec2::new(100.0, 100.0), Vec2::new(200.0, 200.0)];
        state.velocities = vec![Vec2::ZERO, Vec2::ZERO];
        state.masses = vec![1.0, 1.0];
        state.config.alpha_decay = 0.1; // Fast decay for test

        for _ in 0..200 {
            state.tick();
        }

        assert!(state.is_settled, "Simulation should settle after many ticks");
    }

    #[test]
    fn reheat_restarts_simulation() {
        let mut state = PhysicsState::new();
        state.is_settled = true;
        state.config.alpha = 0.0;

        state.reheat();

        assert!(!state.is_settled);
        assert!(state.config.alpha > 0.0);
    }
}
