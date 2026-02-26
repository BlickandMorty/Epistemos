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

        // Recover old body position from center_of_mass before update
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

    fn compute_force(&self, pos: Vec2, radius: f32, repulsion: f32) -> Vec2 {
        if self.total_mass == 0.0 { return Vec2::ZERO; }

        let diff = pos - self.center_of_mass;
        let dist_sq = diff.length_squared().max(1.0);
        let dist = dist_sq.sqrt();

        // If this is a leaf or sufficiently far away, use approximation
        if self.children.is_none() || (self.bounds.w / dist) < THETA {
            // Coulomb-like repulsion with radius offset:
            // A larger node (bigger radius) shrinks effective_dist, producing
            // stronger repulsion so big nodes claim more visual space.
            let effective_dist = (dist - radius).max(1.0);
            let force_mag = repulsion * self.total_mass / (effective_dist * effective_dist);
            return diff.normalize_or_zero() * force_mag;
        }

        // Recurse into children
        let mut force = Vec2::ZERO;
        if let Some(children) = &self.children {
            for child in children.iter() {
                if let Some(c) = child {
                    force += c.compute_force(pos, radius, repulsion);
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
    pub link_distance: f32,
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
            repulsion: 2500.0,    // Strong personal-space bubble per node (Obsidian-style)
            attraction: 0.012,    // Slightly stronger springs to hold clusters together
            link_distance: 220.0, // More breathing room between connected nodes
            damping: 0.85,        // Verlet damping (applied to inertia term)
            alpha: 1.0,
            alpha_min: 0.001,
            alpha_decay: 0.015,   // Slower cooling → longer, more fluid animation
            alpha_target: 0.0,
            velocity_decay: 0.55, // Used for ambient drift magnitude
            center_x: 500.0,
            center_y: 350.0,
            center_strength: 0.002, // Weak center pull — clusters spread out, don't collapse
        }
    }
}

/// Per-node physics state using Verlet integration.
/// Stores current and previous positions instead of explicit velocities.
/// Velocity is implicitly (positions[i] - prev_positions[i]), giving superior
/// stability and natural momentum preservation over Euler integration.
pub struct PhysicsState {
    pub positions: Vec<Vec2>,
    pub prev_positions: Vec<Vec2>,
    pub masses: Vec<f32>,
    pub radii: Vec<f32>,
    pub edges: Vec<(u32, u32, f32)>, // (source_id, target_id, weight)
    pub graph_indices: Vec<usize>,   // maps physics index -> graph node index
    pub config: ForceConfig,
    pub is_settled: bool,
    /// Simple xorshift32 RNG state for ambient Brownian motion.
    rng_state: u32,
    /// Drag constraint: (physics_index, world_target). When set, the node is
    /// lerped toward the target each tick with prev_pos zeroed so Verlet forces
    /// are suppressed. On release, the implicit velocity (pos − prev_pos) carries
    /// the cursor's fling direction.
    pub drag_constraint: Option<(usize, Vec2)>,
}

impl PhysicsState {
    pub fn new() -> Self {
        Self {
            positions: Vec::new(),
            prev_positions: Vec::new(),
            masses: Vec::new(),
            radii: Vec::new(),
            edges: Vec::new(),
            graph_indices: Vec::new(),
            config: ForceConfig::default(),
            is_settled: false,
            rng_state: 0xDEAD_BEEF,
            drag_constraint: None,
        }
    }

    /// Fast xorshift32 PRNG. Returns a float in [-1, 1].
    fn rand_f32(&mut self) -> f32 {
        self.rng_state ^= self.rng_state << 13;
        self.rng_state ^= self.rng_state >> 17;
        self.rng_state ^= self.rng_state << 5;
        // Map u32 to [-1, 1]
        (self.rng_state as f32 / u32::MAX as f32) * 2.0 - 1.0
    }

    /// Load physics state from the graph. Call after graph_engine_commit.
    pub fn load_from_graph(&mut self, graph: &crate::types::Graph) {
        let n = graph.nodes.len();
        self.positions.clear();
        self.prev_positions.clear();
        self.masses.clear();
        self.radii.clear();
        self.edges.clear();

        self.positions.reserve(n);
        self.prev_positions.reserve(n);
        self.masses.reserve(n);
        self.radii.reserve(n);

        for node in &graph.nodes {
            self.positions.push(node.pos);
            // Initialize prev_positions slightly behind current to give initial velocity
            self.prev_positions.push(node.pos - node.vel * 0.5);
            self.masses.push(node.weight.max(1.0));
            self.radii.push(node.radius);
        }

        // Identity mapping: physics index i == graph index i
        self.graph_indices = (0..n).collect();

        self.edges.reserve(graph.edges.len());
        for edge in &graph.edges {
            self.edges.push((edge.source, edge.target, edge.weight));
        }

        self.config.alpha = 1.0;
        self.is_settled = false;

        // Boost mass based on connectivity (hub nodes claim more space)
        let mut degree = vec![0u32; self.positions.len()];
        for &(src, tgt, _) in &self.edges {
            degree[src as usize] += 1;
            degree[tgt as usize] += 1;
        }
        for i in 0..self.masses.len() {
            self.masses[i] *= 1.0 + (degree[i] as f32).sqrt() * 0.3;
        }
    }

    /// Load physics state from graph, including only visible nodes.
    /// Builds a compact physics array and maps indices back to graph positions.
    pub fn load_from_graph_filtered(&mut self, graph: &crate::types::Graph) {
        self.positions.clear();
        self.prev_positions.clear();
        self.masses.clear();
        self.radii.clear();
        self.edges.clear();
        self.graph_indices.clear();

        // Build ID -> physics_index map for visible nodes only
        let mut id_to_phys: FxHashMap<u32, usize> = FxHashMap::default();

        for (graph_idx, node) in graph.nodes.iter().enumerate() {
            if !node.visible { continue; }
            let phys_idx = self.positions.len();
            id_to_phys.insert(node.id, phys_idx);
            self.positions.push(node.pos);
            self.prev_positions.push(node.pos - node.vel * 0.5);
            self.masses.push(node.weight.max(1.0));
            self.radii.push(node.radius);
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

        // Boost mass based on connectivity (hub nodes claim more space)
        let mut degree = vec![0u32; self.positions.len()];
        for &(src, tgt, _) in &self.edges {
            degree[src as usize] += 1;
            degree[tgt as usize] += 1;
        }
        for i in 0..self.masses.len() {
            self.masses[i] *= 1.0 + (degree[i] as f32).sqrt() * 0.3;
        }
    }

    /// Run one tick of the force simulation using Verlet integration.
    ///
    /// Verlet: next_pos = pos + (pos - prev_pos) * damping + acceleration * dt²
    /// The (pos - prev_pos) term implicitly preserves velocity/momentum from
    /// the previous tick, producing much smoother, more stable motion than Euler.
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
        let mut accelerations = vec![Vec2::ZERO; n];
        for i in 0..n {
            // Pass this node's radius so leaf-level forces account for visual size
            accelerations[i] += tree.compute_force(
                self.positions[i],
                self.radii[i],
                self.config.repulsion,
            ) / self.masses[i]; // F = ma, so a = F/m
        }

        // ── 4. Attraction along edges (Hooke's spring) ─────────────────
        for &(src, tgt, weight) in &self.edges {
            let si = src as usize;
            let ti = tgt as usize;
            if si >= n || ti >= n { continue; }

            let diff = self.positions[ti] - self.positions[si];
            let dist = diff.length().max(1.0);
            let displacement = dist - self.config.link_distance;
            let strength = self.config.attraction * weight;
            let f = diff.normalize_or_zero() * displacement * strength;

            accelerations[si] += f / self.masses[si];
            accelerations[ti] -= f / self.masses[ti];
        }

        // ── 5. Center gravity ───────────────────────────────────────────
        let center = Vec2::new(self.config.center_x, self.config.center_y);
        for i in 0..n {
            let to_center = center - self.positions[i];
            accelerations[i] += to_center * self.config.center_strength;
        }

        // ── 6. Ambient Brownian motion (never fully sleep) ──────────────
        // Inject tiny random perturbation that scales inversely with alpha.
        // When alpha is high (active layout), this is negligible.
        // When alpha is low (nearly settled), this creates organic floating drift.
        let ambient_strength = 0.3 * (1.0 - alpha.min(0.1) / 0.1);
        if ambient_strength > 0.01 {
            for i in 0..n {
                let rx = self.rand_f32() * ambient_strength;
                let ry = self.rand_f32() * ambient_strength;
                accelerations[i] += Vec2::new(rx, ry);
            }
        }

        // ── 7. Verlet integration with damping ──────────────────────────
        let damping = self.config.damping;
        let dt2_alpha = alpha; // Scale accelerations by alpha for cooling

        for i in 0..n {
            let current = self.positions[i];
            let prev = self.prev_positions[i];

            // Verlet: next = current + (current - prev) * damping + accel * dt²
            let inertia = (current - prev) * damping;

            // Clamp inertia to prevent explosions
            let speed = inertia.length();
            let clamped_inertia = if speed > 50.0 {
                inertia * (50.0 / speed)
            } else {
                inertia
            };

            let next = current + clamped_inertia + accelerations[i] * dt2_alpha;

            self.prev_positions[i] = current;
            self.positions[i] = next;
        }

        // ── 7.5. Collision resolution — prevent visual overlap ──────────
        // O(n²) pairwise check is fine for n < 500 (our target).
        // Only run while simulation is active to avoid wasting cycles.
        if alpha > 0.01 {
            let min_gap = 4.0; // Minimum gap between node edges in world units
            for i in 0..n {
                for j in (i + 1)..n {
                    let diff = self.positions[j] - self.positions[i];
                    let dist = diff.length();
                    let min_dist = self.radii[i] + self.radii[j] + min_gap;
                    if dist < min_dist {
                        // For coincident nodes, pick an arbitrary separation direction
                        let (direction, actual_dist) = if dist > 0.001 {
                            (diff / dist, dist)
                        } else {
                            (Vec2::new(1.0, 0.0), 0.0)
                        };
                        let overlap = (min_dist - actual_dist) * 0.5;
                        let push = direction * overlap;
                        self.positions[i] -= push;
                        self.positions[j] += push;
                    }
                }
            }
        }

        // ── 8. Apply drag constraint (after Verlet) ─────────────────────
        // Lerp dragged node toward cursor target. Setting prev_pos = pos
        // before the lerp zeros the Verlet inertia term so forces don't
        // fight the user's cursor. On release, the lerp delta becomes the
        // implicit velocity → natural fling.
        if let Some((drag_idx, target)) = self.drag_constraint {
            if drag_idx < n {
                let pos = self.positions[drag_idx];
                self.prev_positions[drag_idx] = pos; // zero external forces
                self.positions[drag_idx] = pos.lerp(target, 0.4);
            }
        }
    }

    /// Write updated positions back to graph nodes using graph_indices mapping.
    /// Also writes back implicit velocity (for persistence across filter changes).
    pub fn write_back(&self, graph: &mut crate::types::Graph) {
        for (phys_idx, &graph_idx) in self.graph_indices.iter().enumerate() {
            if phys_idx < self.positions.len() && graph_idx < graph.nodes.len() {
                graph.nodes[graph_idx].pos = self.positions[phys_idx];
                // Implicit velocity = current - prev
                graph.nodes[graph_idx].vel = self.positions[phys_idx] - self.prev_positions[phys_idx];
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

    fn make_verlet_state(positions: Vec<Vec2>) -> PhysicsState {
        let n = positions.len();
        PhysicsState {
            prev_positions: positions.clone(), // Zero initial velocity
            positions,
            masses: vec![1.0; n],
            radii: vec![8.0; n],
            edges: Vec::new(),
            graph_indices: (0..n).collect(),
            config: ForceConfig::default(),
            is_settled: false,
            rng_state: 0xDEAD_BEEF,
            drag_constraint: None,
        }
    }

    #[test]
    fn two_nodes_repel() {
        let mut state = make_verlet_state(vec![Vec2::new(0.0, 0.0), Vec2::new(10.0, 0.0)]);
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
        let mut state = make_verlet_state(vec![Vec2::new(0.0, 0.0), Vec2::new(500.0, 0.0)]);
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
        let mut state = make_verlet_state(vec![Vec2::new(100.0, 100.0), Vec2::new(200.0, 200.0)]);
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

    #[test]
    fn drag_constraint_moves_node_toward_target() {
        let mut state = make_verlet_state(vec![
            Vec2::new(100.0, 100.0),
            Vec2::new(300.0, 100.0),
        ]);
        state.config.center_strength = 0.0;
        state.config.repulsion = 0.0;
        state.config.alpha = 1.0;
        state.config.alpha_min = 0.0;

        // Drag node 0 toward (200, 200)
        state.drag_constraint = Some((0, Vec2::new(200.0, 200.0)));

        state.tick();

        // Node 0 should have moved toward target
        assert!(state.positions[0].x > 100.0,
            "Dragged node should move toward target x, got {}", state.positions[0].x);
        assert!(state.positions[0].y > 100.0,
            "Dragged node should move toward target y, got {}", state.positions[0].y);
        // Node 1 should be unaffected by drag (no forces)
        let node1_moved = (state.positions[1] - Vec2::new(300.0, 100.0)).length();
        assert!(node1_moved < 5.0,
            "Non-dragged node should barely move, moved {}", node1_moved);
    }

    #[test]
    fn drag_release_preserves_fling_velocity() {
        let mut state = make_verlet_state(vec![Vec2::new(100.0, 0.0)]);
        state.config.center_strength = 0.0;
        state.config.repulsion = 0.0;
        state.config.alpha = 1.0;
        state.config.alpha_min = 0.0;

        // Simulate dragging: apply constraint for a few ticks
        state.drag_constraint = Some((0, Vec2::new(200.0, 0.0)));
        for _ in 0..5 {
            state.tick();
        }
        let pos_at_release = state.positions[0];

        // Release: clear drag, tick once more
        state.drag_constraint = None;
        state.tick();

        // Node should continue moving right due to Verlet inertia (fling)
        assert!(state.positions[0].x > pos_at_release.x,
            "Node should fling right after release, pos {} vs release {}",
            state.positions[0].x, pos_at_release.x);
    }

    #[test]
    fn verlet_preserves_momentum() {
        // Give node 0 initial velocity by offsetting prev_position
        let mut state = PhysicsState::new();
        state.positions = vec![Vec2::new(100.0, 0.0)];
        state.prev_positions = vec![Vec2::new(95.0, 0.0)]; // Moving right at velocity 5
        state.masses = vec![1.0];
        state.radii = vec![8.0];
        state.graph_indices = vec![0];
        state.drag_constraint = None;
        state.config.center_strength = 0.0;
        state.config.repulsion = 0.0;
        state.config.alpha = 1.0;
        state.config.alpha_min = 0.0;

        state.tick();

        // Node should continue moving right due to momentum (Verlet inertia)
        assert!(state.positions[0].x > 100.0,
            "Node should continue moving right, got {}", state.positions[0].x);
    }

    #[test]
    fn large_node_repels_more() {
        // Two identical setups: node 0 at origin, node 1 nearby.
        // Setup A: node 0 has radius 8  (small)
        // Setup B: node 0 has radius 22 (large)
        // After a single tick, node 0 in setup B should be pushed further
        // from node 1 because effective_dist is smaller → force is stronger.
        //
        // We use a single tick to measure the raw force difference before
        // Verlet inertia accumulation muddies the comparison.

        let positions = vec![Vec2::new(0.0, 0.0), Vec2::new(50.0, 0.0)];

        // --- Setup A: small radius ---
        let mut state_a = make_verlet_state(positions.clone());
        state_a.radii[0] = 8.0;
        state_a.config.center_strength = 0.0;
        state_a.config.alpha = 1.0;
        state_a.config.alpha_min = 0.0;
        state_a.config.alpha_decay = 0.0; // No cooling so alpha stays constant

        // --- Setup B: large radius ---
        let mut state_b = make_verlet_state(positions);
        state_b.radii[0] = 22.0;
        state_b.config.center_strength = 0.0;
        state_b.config.alpha = 1.0;
        state_b.config.alpha_min = 0.0;
        state_b.config.alpha_decay = 0.0;

        // Single tick: measures immediate force-driven displacement
        state_a.tick();
        state_b.tick();

        // Node 0 moves left (negative x) in both cases.
        // With larger radius, the repulsion is stronger, so node 0
        // should be further left (more negative x) in setup B.
        assert!(
            state_b.positions[0].x < state_a.positions[0].x,
            "Large-radius node should be pushed further: B.x={} should be < A.x={}",
            state_b.positions[0].x,
            state_a.positions[0].x,
        );
    }

    #[test]
    fn overlapping_nodes_separated() {
        // Two nodes at the exact same position with radius 10 each.
        // After one tick the collision pass should push them apart to
        // at least radii[0] + radii[1] + min_gap = 10 + 10 + 4 = 24.
        let mut state = make_verlet_state(vec![
            Vec2::new(100.0, 100.0),
            Vec2::new(100.0, 100.0), // same position → zero distance
        ]);
        state.radii = vec![10.0, 10.0];
        // Disable everything except collision resolution
        state.config.repulsion = 0.0;
        state.config.center_strength = 0.0;
        state.config.attraction = 0.0;
        state.config.alpha = 1.0;
        state.config.alpha_min = 0.0;
        state.config.alpha_decay = 0.0; // Keep alpha constant

        state.tick();

        let dist = (state.positions[1] - state.positions[0]).length();
        let min_expected = 10.0 + 10.0 + 4.0; // radii sum + min_gap
        assert!(
            dist >= min_expected,
            "Overlapping nodes should be separated to at least {}, got {}",
            min_expected, dist,
        );
    }

    #[test]
    fn non_overlapping_nodes_unchanged() {
        // Two nodes 200 units apart with radius 8 each.
        // min_dist = 8 + 8 + 4 = 20, which is far less than 200.
        // Collision pass should not move them. With all other forces
        // disabled, positions should remain essentially unchanged.
        let mut state = make_verlet_state(vec![
            Vec2::new(0.0, 0.0),
            Vec2::new(200.0, 0.0),
        ]);
        state.radii = vec![8.0, 8.0];
        state.config.repulsion = 0.0;
        state.config.center_strength = 0.0;
        state.config.attraction = 0.0;
        state.config.alpha = 1.0;
        state.config.alpha_min = 0.0;
        state.config.alpha_decay = 0.0;

        let pos0_before = state.positions[0];
        let pos1_before = state.positions[1];

        state.tick();

        let drift0 = (state.positions[0] - pos0_before).length();
        let drift1 = (state.positions[1] - pos1_before).length();
        assert!(
            drift0 < 1.0,
            "Node 0 should barely move, drifted {}",
            drift0,
        );
        assert!(
            drift1 < 1.0,
            "Node 1 should barely move, drifted {}",
            drift1,
        );
    }

    #[test]
    fn radii_loaded_from_graph() {
        use crate::types::Graph;

        let mut graph = Graph::new();
        // weight 1.0 -> radius 8.0 (small)
        graph.add_node("a".into(), 0.0, 0.0, 0, 1.0, "A".into());
        // weight 5.0 -> radius 14.0 (medium)
        graph.add_node("b".into(), 10.0, 0.0, 0, 5.0, "B".into());
        // weight 15.0 -> radius 22.0 (large)
        graph.add_node("c".into(), 20.0, 0.0, 0, 15.0, "C".into());

        let mut state = PhysicsState::new();
        state.load_from_graph(&graph);

        assert_eq!(state.radii.len(), 3);
        assert_eq!(state.radii[0], 8.0, "weight 1 -> radius 8");
        assert_eq!(state.radii[1], 14.0, "weight 5 -> radius 14");
        assert_eq!(state.radii[2], 22.0, "weight 15 -> radius 22");
    }

    #[test]
    fn hub_node_has_boosted_mass() {
        use crate::types::Graph;

        let mut graph = Graph::new();
        // Node 0: the hub — will have 10 edges
        graph.add_node("hub".into(), 0.0, 0.0, 0, 1.0, "Hub".into());
        // Node 1: isolated — zero edges
        graph.add_node("isolated".into(), 100.0, 0.0, 0, 1.0, "Isolated".into());
        // Nodes 2..11: spokes connected to the hub
        for i in 0..10 {
            let name = format!("spoke_{}", i);
            graph.add_node(name.clone(), (i as f32) * 20.0, 50.0, 0, 1.0, name.clone());
        }

        // Connect all 10 spokes to the hub
        for i in 0..10 {
            let spoke_name = format!("spoke_{}", i);
            graph.add_edge("hub", &spoke_name, 0, 1.0);
        }

        let mut state = PhysicsState::new();
        state.load_from_graph(&graph);

        // Hub (index 0) has degree 10: mass = 1.0 * (1 + sqrt(10) * 0.3) ~= 1.949
        // Isolated (index 1) has degree 0: mass = 1.0 * (1 + sqrt(0) * 0.3) = 1.0
        assert!(
            state.masses[0] > state.masses[1],
            "Hub mass ({}) should be greater than isolated mass ({})",
            state.masses[0],
            state.masses[1],
        );

        // Verify the exact formula: hub degree = 10
        let expected_hub_mass = 1.0 * (1.0 + (10.0_f32).sqrt() * 0.3);
        assert!(
            (state.masses[0] - expected_hub_mass).abs() < 0.001,
            "Hub mass should be ~{}, got {}",
            expected_hub_mass,
            state.masses[0],
        );

        // Isolated node mass should remain 1.0 (no boost)
        assert!(
            (state.masses[1] - 1.0).abs() < 0.001,
            "Isolated mass should be 1.0, got {}",
            state.masses[1],
        );
    }

    #[test]
    fn degree_boost_increases_spacing() {
        // Two identical layouts: a center node surrounded by 8 neighbors.
        // Setup A: center node has degree-boosted mass (loaded from graph with edges).
        // Setup B: center node has base mass (loaded from graph without edges).
        // Both have attraction disabled so only repulsion acts.
        // The boosted-mass center in setup A repels neighbors more strongly,
        // producing larger average spacing after several ticks.
        use crate::types::Graph;

        // --- Setup A: center node is a hub with edges (gets mass boost) ---
        let mut graph_hub = Graph::new();
        graph_hub.add_node("center".into(), 300.0, 300.0, 0, 1.0, "Center".into());
        for i in 0..8 {
            let angle = (i as f32) * std::f32::consts::TAU / 8.0;
            let x = 300.0 + angle.cos() * 40.0;
            let y = 300.0 + angle.sin() * 40.0;
            let name = format!("n{}", i);
            graph_hub.add_node(name.clone(), x, y, 0, 1.0, name.clone());
            graph_hub.add_edge("center", &name, 0, 1.0);
        }

        let mut state_hub = PhysicsState::new();
        state_hub.load_from_graph(&graph_hub);
        // Disable attraction and centering so only repulsion matters
        state_hub.config.attraction = 0.0;
        state_hub.config.center_strength = 0.0;
        state_hub.config.alpha_decay = 0.0;

        // --- Setup B: same positions, no edges (no mass boost) ---
        let mut graph_no_hub = Graph::new();
        graph_no_hub.add_node("center".into(), 300.0, 300.0, 0, 1.0, "Center".into());
        for i in 0..8 {
            let angle = (i as f32) * std::f32::consts::TAU / 8.0;
            let x = 300.0 + angle.cos() * 40.0;
            let y = 300.0 + angle.sin() * 40.0;
            let name = format!("n{}", i);
            graph_no_hub.add_node(name.clone(), x, y, 0, 1.0, name.clone());
        }

        let mut state_no_hub = PhysicsState::new();
        state_no_hub.load_from_graph(&graph_no_hub);
        state_no_hub.config.attraction = 0.0;
        state_no_hub.config.center_strength = 0.0;
        state_no_hub.config.alpha_decay = 0.0;

        // Confirm the hub center actually has boosted mass
        assert!(
            state_hub.masses[0] > state_no_hub.masses[0],
            "Hub center mass ({}) should exceed no-hub center mass ({})",
            state_hub.masses[0],
            state_no_hub.masses[0],
        );

        // Run both for several ticks
        for _ in 0..10 {
            state_hub.tick();
            state_no_hub.tick();
        }

        // Measure average distance of neighbors from center in both setups
        let center_hub = state_hub.positions[0];
        let center_no = state_no_hub.positions[0];

        let avg_dist_hub: f32 = (1..9)
            .map(|i| (state_hub.positions[i] - center_hub).length())
            .sum::<f32>()
            / 8.0;

        let avg_dist_no: f32 = (1..9)
            .map(|i| (state_no_hub.positions[i] - center_no).length())
            .sum::<f32>()
            / 8.0;

        assert!(
            avg_dist_hub > avg_dist_no,
            "Hub setup neighbors should be further from center ({}) than no-hub setup ({})",
            avg_dist_hub,
            avg_dist_no,
        );
    }
}
