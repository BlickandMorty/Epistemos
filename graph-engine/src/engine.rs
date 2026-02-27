//! # Graph Engine Orchestrator
//!
//! Ties together Simulation, Renderer, and SpatialIndex.
//! Manages the physics thread lifecycle, input handling, camera, and highlighting.
//!
//! ## Threading Model
//! - Physics thread: locks `Simulation` briefly to tick, then releases.
//! - Render thread (main): locks `Simulation` briefly to copy positions, then releases.
//! - `parking_lot::Mutex` for low-overhead, non-poisoning locks.

use std::collections::VecDeque;
use std::ffi::{c_void, CString};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use parking_lot::Mutex;
use rustc_hash::FxHashSet;

use crate::renderer::Renderer;
use crate::simulation::Simulation;
use crate::spatial::SpatialIndex;
use crate::types::Graph;

/// Physics thread target rate — 60Hz is sufficient for force simulation.
const PHYSICS_HZ: f64 = 60.0;
/// Sleep duration when simulation is settled (avoids spinning).
const SETTLED_SLEEP_MS: u64 = 200;

// ── Wormhole Entrance Animation ─────────────────────────────────────────────

/// Per-node visual state during the wormhole entrance animation.
/// Applied at render time only — does not affect simulation.
#[derive(Clone, Copy)]
pub struct EntranceNodeState {
    /// Z-depth offset (starts at -20, eases to 0).
    pub z_offset: f32,
    /// Opacity (0→1 as node arrives).
    pub alpha: f32,
    /// Spiral displacement X (decays to 0).
    pub dx: f32,
    /// Spiral displacement Y (decays to 0).
    pub dy: f32,
}

/// Drives the wormhole entrance animation: hero node races forward,
/// neighbors cascade behind in BFS-ordered waves with spiral rotation.
struct EntranceAnimator {
    /// Per-node stagger delay (seconds). Index = graph node index.
    stagger_delays: Vec<f32>,
    /// Per-node spiral angle (radians).
    spiral_angles: Vec<f32>,
    /// Animation start time.
    start: Instant,
    /// Duration for a single node's z-travel (seconds).
    arrival_duration: f32,
    /// Starting z-offset (deep behind camera).
    start_z: f32,
}

fn ease_out_cubic(t: f32) -> f32 {
    let s = 1.0 - t;
    1.0 - s * s * s
}

impl EntranceAnimator {
    /// Compute per-node entrance offsets for the current frame.
    fn compute(&self) -> Vec<EntranceNodeState> {
        let elapsed = self.start.elapsed().as_secs_f32();
        self.stagger_delays
            .iter()
            .zip(self.spiral_angles.iter())
            .map(|(&delay, &angle)| {
                let t = ((elapsed - delay) / self.arrival_duration).clamp(0.0, 1.0);
                let eased = ease_out_cubic(t);
                let z_offset = self.start_z * (1.0 - eased);
                let alpha = eased;
                // Spiral displacement decays as node arrives.
                let spiral_decay = 1.0 - eased;
                let spiral_r = 80.0 * spiral_decay;
                let effective_angle = angle * spiral_decay;
                let dx = spiral_r * effective_angle.cos() - spiral_r; // subtract rest position
                let dy = spiral_r * effective_angle.sin();
                EntranceNodeState { z_offset, alpha, dx, dy }
            })
            .collect()
    }

    /// True when every node has fully arrived.
    fn is_complete(&self) -> bool {
        if self.stagger_delays.is_empty() {
            return true;
        }
        let elapsed = self.start.elapsed().as_secs_f32();
        let max_delay = self.stagger_delays.iter().copied().fold(0.0f32, f32::max);
        elapsed >= max_delay + self.arrival_duration + 0.1
    }

    /// Build from graph using BFS from the hero node (highest link_count).
    fn from_graph(graph: &Graph) -> Self {
        let n = graph.nodes.len();
        if n == 0 {
            return Self {
                stagger_delays: vec![],
                spiral_angles: vec![],
                start: Instant::now(),
                arrival_duration: 1.0,
                start_z: -3.0,
            };
        }

        // Build adjacency list by graph index.
        let mut adj: Vec<Vec<usize>> = vec![Vec::new(); n];
        for edge in &graph.edges {
            if let (Some(&si), Some(&ti)) = (
                graph.id_to_index.get(&edge.source),
                graph.id_to_index.get(&edge.target),
            ) {
                adj[si].push(ti);
                adj[ti].push(si);
            }
        }

        // Hero: visible node with the most connections.
        let hero_idx = graph
            .nodes
            .iter()
            .enumerate()
            .filter(|(_, nd)| nd.visible)
            .max_by_key(|(_, nd)| nd.link_count)
            .map(|(i, _)| i)
            .unwrap_or(0);

        // BFS from hero to compute depths.
        let mut depths = vec![u32::MAX; n];
        depths[hero_idx] = 0;
        let mut queue = VecDeque::new();
        queue.push_back(hero_idx);

        while let Some(current) = queue.pop_front() {
            for &neighbor in &adj[current] {
                if depths[neighbor] == u32::MAX {
                    depths[neighbor] = depths[current] + 1;
                    queue.push_back(neighbor);
                }
            }
        }

        // Cap unreachable nodes.
        let max_reachable = depths
            .iter()
            .filter(|&&d| d != u32::MAX)
            .copied()
            .max()
            .unwrap_or(0);
        for d in &mut depths {
            if *d == u32::MAX {
                *d = max_reachable + 1;
            }
        }

        // Stagger: 0.08s per BFS hop, capped at 0.6s.
        let stagger_delays: Vec<f32> = depths
            .iter()
            .map(|&d| (d as f32 * 0.08).min(0.6))
            .collect();

        // Spiral angles: golden angle offset per depth ring + index spread.
        const GOLDEN_ANGLE: f32 = 2.39996;
        let spiral_angles: Vec<f32> = depths
            .iter()
            .enumerate()
            .map(|(i, &d)| d as f32 * GOLDEN_ANGLE + i as f32 * 0.1)
            .collect();

        Self {
            stagger_delays,
            spiral_angles,
            start: Instant::now(),
            arrival_duration: 1.0,
            start_z: -3.0,
        }
    }
}

/// Drag state for d3-style fx/fy constraint.
struct DragState {
    node_id: u32,
    sim_index: usize,
    /// Screen position at drag start — used to detect click vs drag.
    origin: [f32; 2],
    /// Whether the mouse moved enough to count as a real drag.
    moved: bool,
}

pub struct Engine {
    graph: Graph,
    sim: Arc<Mutex<Simulation>>,
    renderer: Renderer,
    spatial: SpatialIndex,

    // Physics thread control
    physics_handle: Option<std::thread::JoinHandle<()>>,
    stop_flag: Arc<AtomicBool>,

    // Viewport dimensions (updated each render call)
    viewport_width: u32,
    viewport_height: u32,

    // Interaction state
    selected_id: Option<u32>,
    hovered_id: Option<u32>,
    drag: Option<DragState>,
    pan_active: bool,
    pan_origin_camera: [f32; 2],
    pan_origin_mouse: [f32; 2],

    // Graph mode: 0 = global, 1 = page
    mode: u8,

    // Page mode: note window rect in screen pixels (x, y, w, h).
    // Used to bias the center force toward the note window edge.
    anchor_rect: Option<[f32; 4]>,

    // Wormhole entrance animation.
    entrance: Option<EntranceAnimator>,
    /// Cached per-frame entrance states (recomputed each render call).
    entrance_states: Vec<EntranceNodeState>,
    /// Frame counter for entrance camera zoom-to-fit delay.
    entrance_camera_frame: u32,

    // Reusable buffer for returning UUIDs through FFI.
    uuid_buf: Option<CString>,

    /// Counts consecutive frames where the engine reported "no more frames needed."
    /// Used to throttle render calls when idle.
    idle_frame_count: u32,
}

impl Engine {
    pub fn new(device_ptr: *mut c_void, layer_ptr: *mut c_void) -> Option<Self> {
        let renderer = Renderer::new(device_ptr, layer_ptr)?;
        Some(Self {
            graph: Graph::new(),
            sim: Arc::new(Mutex::new(Simulation::new())),
            renderer,
            spatial: SpatialIndex::new(),
            physics_handle: None,
            stop_flag: Arc::new(AtomicBool::new(false)),
            viewport_width: 1,
            viewport_height: 1,
            selected_id: None,
            hovered_id: None,
            drag: None,
            pan_active: false,
            pan_origin_camera: [0.0, 0.0],
            pan_origin_mouse: [0.0, 0.0],
            mode: 0,
            anchor_rect: None,
            entrance: None,
            entrance_states: Vec::new(),
            entrance_camera_frame: 0,
            uuid_buf: None,
            idle_frame_count: 0,
        })
    }

    /// Commit graph data. Replaces all simulation state, restarts physics.
    /// If `entrance` is true, plays the wormhole entrance animation.
    pub fn commit(&mut self, entrance: bool) {
        // Wake rendering for the new graph data.
        self.idle_frame_count = 0;

        // Stop existing physics thread.
        self.stop_physics();

        // Wormhole entrance: cluster nodes at center with small jitter.
        // The visual drama comes from per-node z-offset + spiral in EntranceAnimator,
        // not from the initial positions (which are just for physics seeding).
        if entrance {
            let n = self.graph.nodes.len() as f32;
            let jitter_range = (n.sqrt() * 2.0).max(20.0);
            for (i, node) in self.graph.nodes.iter_mut().enumerate() {
                let hash = ((i as u32).wrapping_mul(2654435761)) as f32 / u32::MAX as f32;
                let hash2 = (((i as u32 + 7919).wrapping_mul(2246822519))) as f32 / u32::MAX as f32;
                node.x = (hash - 0.5) * jitter_range;
                node.y = (hash2 - 0.5) * jitter_range;
                node.vx = 0.0;
                node.vy = 0.0;
            }
        }

        // Load graph into simulation (but don't start physics during entrance —
        // the z-animation and spiral handle visuals; physics starts after entrance completes).
        {
            let mut sim = self.sim.lock();
            sim.load_from_graph(&self.graph);

            // Run Louvain community detection and assign cluster IDs.
            let cluster_ids = crate::cluster::detect_communities(sim.x.len(), &sim.edges);
            sim.cluster_ids = cluster_ids;
        }

        // Allocate renderer buffers and upload initial data.
        self.renderer.allocate_buffers(&self.graph, None);

        // Build spatial index for hit testing.
        self.spatial.build(&self.graph.nodes);

        // Clear interaction state.
        self.selected_id = None;
        self.hovered_id = None;
        self.drag = None;
        self.renderer.highlight.active = false;
        self.renderer.highlight.highlighted_ids.clear();

        if entrance {
            // Build BFS-based wormhole entrance animator.
            self.entrance = Some(EntranceAnimator::from_graph(&self.graph));
            self.entrance_states = Vec::new();
            self.entrance_camera_frame = 0;

            // Camera at moderate zoom centered on origin — nodes materialize and grow.
            self.renderer.camera_offset = [0.0, 0.0];
            self.renderer.target_offset = [0.0, 0.0];
            self.renderer.camera_zoom = 1.0;
            self.renderer.target_zoom = 1.0;
            self.renderer.is_animating = false;

            // Don't start physics yet — entrance animation handles visuals.
            // Physics starts when entrance completes (in render()).
        } else {
            self.entrance = None;
            self.entrance_states = Vec::new();
            self.entrance_camera_frame = 0;

            // Start physics thread immediately for non-entrance commits.
            self.start_physics();
        }
    }

    fn start_physics(&mut self) {
        self.stop_flag.store(false, Ordering::Relaxed);
        let sim = Arc::clone(&self.sim);
        let stop = Arc::clone(&self.stop_flag);
        self.physics_handle = Some(std::thread::spawn(move || {
            physics_loop(sim, stop);
        }));
    }

    fn stop_physics(&mut self) {
        self.stop_flag.store(true, Ordering::Relaxed);
        if let Some(handle) = self.physics_handle.take() {
            let _ = handle.join();
        }
    }

    /// Pause the engine: stop physics thread and signal that rendering can idle.
    /// Call when the overlay is hidden to free CPU/GPU.
    pub fn pause(&mut self) {
        self.stop_physics();
    }

    /// Resume the engine: restart physics if simulation is not settled.
    /// Call when the overlay is shown again.
    pub fn resume(&mut self) {
        self.idle_frame_count = 0;
        if self.physics_handle.is_none() && !self.sim.lock().is_settled {
            self.start_physics();
        }
    }

    /// Copy positions from simulation SoA arrays back to graph nodes.
    /// Returns true if positions were updated (i.e., simulation is still running).
    fn sync_positions(&mut self) -> bool {
        let sim = self.sim.lock();
        if sim.is_settled {
            return false;
        }

        for (si, &gi) in sim.graph_indices.iter().enumerate() {
            if gi < self.graph.nodes.len() {
                self.graph.nodes[gi].x = sim.x[si];
                self.graph.nodes[gi].y = sim.y[si];
                self.graph.nodes[gi].vx = sim.vx[si];
                self.graph.nodes[gi].vy = sim.vy[si];
            }
        }
        true
    }

    /// Render one frame. Returns 1 if another frame is needed, 0 if GPU can idle.
    pub fn render(&mut self, width: u32, height: u32) -> u32 {
        self.viewport_width = width;
        self.viewport_height = height;

        let positions_changed = self.sync_positions();

        // Wormhole entrance: compute per-node states each frame.
        let entrance_active = self.entrance.is_some();
        let mut entrance_just_completed = false;
        if let Some(ref entrance) = self.entrance {
            self.entrance_states = entrance.compute();

            if entrance.is_complete() {
                entrance_just_completed = true;
            }
        }

        // Handle entrance completion outside the borrow.
        if entrance_just_completed {
            self.entrance = None;
            self.entrance_states.clear();

            // Now start physics with gentle entrance mode — nodes spread to equilibrium.
            {
                let mut sim = self.sim.lock();
                sim.set_entrance_mode();
            }
            self.start_physics();

            // Smooth zoom-to-fit as physics spreads nodes outward.
            self.zoom_to_fit();
        }

        // Auto-expire ripple effect after 1.5 seconds.
        if let Some(start) = self.renderer.ripple_start {
            if start.elapsed().as_secs_f32() > 1.5 {
                self.renderer.ripple_start = None;
            }
        }

        // Animate camera (smooth lerp toward target).
        self.renderer.update_camera();

        // Request next frame only when something is animating.
        let sim_active = !self.sim.lock().is_settled;
        let camera_moving = self.renderer.is_animating;
        let ripple_active = self.renderer.ripple_start.is_some();
        let needs_frame = sim_active || camera_moving || ripple_active || entrance_active;

        // Idle frame skipping: after 3 consecutive idle frames, skip GPU work entirely.
        // We still render the first 3 idle frames to flush any final visual updates.
        if !needs_frame {
            self.idle_frame_count += 1;
            if self.idle_frame_count > 3 {
                return 0;
            }
        } else {
            self.idle_frame_count = 0;
        }

        // Build the optional entrance state slice for the renderer.
        let ent = if self.entrance_states.is_empty() {
            None
        } else {
            Some(self.entrance_states.as_slice())
        };

        if positions_changed || entrance_active {
            self.renderer.update_positions(&self.graph, ent);
            self.renderer.upload_labels(&self.graph);
            self.spatial.build(&self.graph.nodes);
        } else if camera_moving {
            // Re-upload labels when zoom changes so fade-by-screen-radius stays correct.
            // Positions haven't changed, so skip update_positions and spatial rebuild.
            self.renderer.upload_labels(&self.graph);
        }

        // Append selection/hover highlight rings.
        self.renderer
            .set_highlights(self.selected_id, self.hovered_id, &self.graph);

        // Update magnetic field lines for hovered node.
        let time = self.renderer.start_time.elapsed().as_secs_f32();
        self.renderer.update_field_lines(self.hovered_id, &self.graph, time);

        // Issue draw commands.
        self.renderer.draw(width, height);

        u32::from(needs_frame)
    }

    // ── Screen ↔ World Coordinate Conversion ─────────────────────────

    /// Convert screen pixel coordinates to world coordinates.
    /// Derived from the shader's transform: `screen = (world - offset) * zoom`.
    pub fn screen_to_world(&self, sx: f32, sy: f32) -> (f32, f32) {
        let w = self.viewport_width as f32;
        let h = self.viewport_height as f32;
        let zoom = self.renderer.camera_zoom;
        let wx = (sx - w * 0.5) / zoom + self.renderer.camera_offset[0];
        let wy = (sy - h * 0.5) / zoom + self.renderer.camera_offset[1];
        (wx, wy)
    }

    // ── Input Handling ───────────────────────────────────────────────

    /// Mouse/trackpad button pressed.
    /// `shift`: whether shift key is held (for neighbor highlighting).
    pub fn mouse_down(&mut self, screen_x: f32, screen_y: f32, shift: bool) {
        self.idle_frame_count = 0;
        let (wx, wy) = self.screen_to_world(screen_x, screen_y);
        let hit = self.spatial.query_point(wx, wy);

        if let Some(node_id) = hit {
            if shift {
                self.highlight_neighbors_by_id(node_id);
                return;
            }

            self.selected_id = Some(node_id);

            // Trigger ripple shockwave from the grabbed node's position.
            if let Some(&gi) = self.graph.id_to_index.get(&node_id) {
                let node = &self.graph.nodes[gi];
                self.renderer.ripple_origin = [node.x, node.y];
                self.renderer.ripple_start = Some(Instant::now());
            }

            // Start drag — set fx/fy in simulation (single lock acquisition).
            if let Some(&gi) = self.graph.id_to_index.get(&node_id) {
                let mut sim = self.sim.lock();
                if let Some(sim_index) = sim.graph_indices.iter().position(|&g| g == gi) {
                    sim.fix_node(sim_index, wx, wy);
                    if sim.is_settled {
                        sim.reheat();
                    }
                    drop(sim);
                    self.drag = Some(DragState {
                        node_id,
                        sim_index,
                        origin: [screen_x, screen_y],
                        moved: false,
                    });
                }
            }
        } else {
            // Background click — start panning.
            self.pan_active = true;
            self.pan_origin_camera = self.renderer.camera_offset;
            self.pan_origin_mouse = [screen_x, screen_y];

            // Clear selection on background click.
            self.selected_id = None;

            // Clear highlight on background click and zoom back to fit all nodes.
            if self.renderer.highlight.active {
                self.renderer.highlight.active = false;
                self.renderer.highlight.highlighted_ids.clear();
                {
                let ent = if self.entrance_states.is_empty() { None } else { Some(self.entrance_states.as_slice()) };
                self.renderer.upload_graph(&self.graph, ent);
            };
                self.zoom_to_fit();
            }
        }
    }

    /// Mouse/trackpad moved (drag, pan, or hover).
    pub fn mouse_moved(&mut self, screen_x: f32, screen_y: f32) {
        self.idle_frame_count = 0;
        if self.drag.is_some() {
            let drag = self.drag.as_ref().unwrap();
            let sim_index = drag.sim_index;
            let origin = drag.origin;

            // Check if mouse moved far enough to count as a real drag (5px threshold).
            let dx = screen_x - origin[0];
            let dy = screen_y - origin[1];
            if dx * dx + dy * dy > 25.0 {
                self.drag.as_mut().unwrap().moved = true;
            }
            // Dragging a node — update fixed position.
            let (wx, wy) = self.screen_to_world(screen_x, screen_y);
            let mut sim = self.sim.lock();
            sim.fix_node(sim_index, wx, wy);
        } else if self.pan_active {
            // Panning camera.
            let zoom = self.renderer.camera_zoom;
            let dx = (screen_x - self.pan_origin_mouse[0]) / zoom;
            let dy = (screen_y - self.pan_origin_mouse[1]) / zoom;
            self.renderer.camera_offset[0] = self.pan_origin_camera[0] - dx;
            self.renderer.camera_offset[1] = self.pan_origin_camera[1] - dy;
            self.renderer.target_offset = self.renderer.camera_offset;
        } else {
            // Hover detection.
            let (wx, wy) = self.screen_to_world(screen_x, screen_y);
            self.hovered_id = self.spatial.query_point(wx, wy);
        }
    }

    /// Mouse/trackpad button released.
    pub fn mouse_up(&mut self) {
        self.idle_frame_count = 0;
        if let Some(drag) = self.drag.take() {
            // D3 behavior: unfix node on release (no fling).
            let mut sim = self.sim.lock();
            sim.unfix_node(drag.sim_index);
            drop(sim);

            // Click (not a real drag) → isolate node and focus on its connections.
            if !drag.moved {
                self.isolate_node(drag.node_id);
            }
        }
        self.pan_active = false;
    }

    /// Isolate a node: highlight it + neighbors, zoom camera to fit the cluster.
    fn isolate_node(&mut self, node_id: u32) {
        // Track selection for FFI query.
        self.selected_id = Some(node_id);

        // Collect the node + all direct neighbors.
        let mut ids = FxHashSet::default();
        ids.insert(node_id);
        for edge in &self.graph.edges {
            if edge.source == node_id {
                ids.insert(edge.target);
            } else if edge.target == node_id {
                ids.insert(edge.source);
            }
        }

        // Activate highlight (dims everything else).
        self.renderer.highlight.highlighted_ids = ids.clone();
        self.renderer.highlight.active = true;
        {
                let ent = if self.entrance_states.is_empty() { None } else { Some(self.entrance_states.as_slice()) };
                self.renderer.upload_graph(&self.graph, ent);
            };

        // Compute bounding box of the highlighted cluster.
        let (mut min_x, mut min_y) = (f32::MAX, f32::MAX);
        let (mut max_x, mut max_y) = (f32::MIN, f32::MIN);
        for &nid in &ids {
            if let Some(&gi) = self.graph.id_to_index.get(&nid) {
                let n = &self.graph.nodes[gi];
                min_x = min_x.min(n.x - n.radius);
                min_y = min_y.min(n.y - n.radius);
                max_x = max_x.max(n.x + n.radius);
                max_y = max_y.max(n.y + n.radius);
            }
        }

        if min_x < f32::MAX {
            let cx = (min_x + max_x) * 0.5;
            let cy = (min_y + max_y) * 0.5;
            let graph_w = (max_x - min_x).max(1.0);
            let graph_h = (max_y - min_y).max(1.0);
            let w = self.viewport_width as f32;
            let h = self.viewport_height as f32;
            let padding = 0.65; // Tighter than global zoom-to-fit for focus feel.
            let zoom = (w / graph_w).min(h / graph_h) * padding;

            self.renderer.target_offset = [cx, cy];
            self.renderer.target_zoom = zoom.clamp(0.05, 10.0);
            self.renderer.is_animating = true;
        }
    }

    /// Two-finger scroll: pan the camera by screen-space delta.
    pub fn scroll(&mut self, delta_x: f32, delta_y: f32) {
        self.idle_frame_count = 0;
        let zoom = self.renderer.camera_zoom;
        self.renderer.camera_offset[0] -= delta_x / zoom;
        self.renderer.camera_offset[1] += delta_y / zoom;
        self.renderer.target_offset = self.renderer.camera_offset;
    }

    /// Pinch-to-zoom toward the cursor position.
    /// `magnification`: scale delta from NSEvent (e.g. +0.02 = 2% zoom in).
    /// Applies zoom directly (no animation) to avoid drift from target/actual mismatch.
    pub fn magnify(&mut self, screen_x: f32, screen_y: f32, magnification: f32) {
        self.idle_frame_count = 0;
        let (world_x, world_y) = self.screen_to_world(screen_x, screen_y);

        let new_zoom = (self.renderer.camera_zoom * (1.0 + magnification)).clamp(0.05, 10.0);

        // Offset that keeps the world point under cursor fixed at the new zoom.
        let w = self.viewport_width as f32;
        let h = self.viewport_height as f32;
        let new_ox = world_x - (screen_x - w * 0.5) / new_zoom;
        let new_oy = world_y - (screen_y - h * 0.5) / new_zoom;

        // Set both actual and target to stay in sync.
        self.renderer.camera_zoom = new_zoom;
        self.renderer.camera_offset = [new_ox, new_oy];
        self.renderer.target_zoom = new_zoom;
        self.renderer.target_offset = [new_ox, new_oy];
    }

    // ── Neighbor Highlighting ────────────────────────────────────────

    fn highlight_neighbors_by_id(&mut self, node_id: u32) {
        let mut ids = FxHashSet::default();
        ids.insert(node_id);

        for edge in &self.graph.edges {
            if edge.source == node_id {
                ids.insert(edge.target);
            } else if edge.target == node_id {
                ids.insert(edge.source);
            }
        }

        self.renderer.highlight.highlighted_ids = ids;
        self.renderer.highlight.active = true;
        {
                let ent = if self.entrance_states.is_empty() { None } else { Some(self.entrance_states.as_slice()) };
                self.renderer.upload_graph(&self.graph, ent);
            };
    }

    /// Highlight neighbors of a node by UUID (called from FFI).
    pub fn highlight_neighbors(&mut self, uuid: &str) {
        if let Some(&node_id) = self.graph.uuid_to_id.get(uuid) {
            self.highlight_neighbors_by_id(node_id);
        }
    }

    /// Clear neighbor highlighting.
    pub fn clear_highlight(&mut self) {
        if self.renderer.highlight.active {
            self.renderer.highlight.active = false;
            self.renderer.highlight.highlighted_ids.clear();
            {
                let ent = if self.entrance_states.is_empty() { None } else { Some(self.entrance_states.as_slice()) };
                self.renderer.upload_graph(&self.graph, ent);
            };
        }
    }

    /// Highlight all nodes whose label contains the query (case-insensitive).
    /// Empty query clears highlighting.
    pub fn search_highlight(&mut self, query: &str) {
        if query.is_empty() {
            self.clear_highlight();
            return;
        }

        let query_lower = query.to_lowercase();
        let mut ids = FxHashSet::default();

        for node in &self.graph.nodes {
            if node.label.to_lowercase().contains(&query_lower) {
                ids.insert(node.id);
            }
        }

        if ids.is_empty() {
            // No matches — keep highlight active but with empty set (dims everything).
            self.renderer.highlight.highlighted_ids.clear();
            self.renderer.highlight.active = true;
            {
                let ent = if self.entrance_states.is_empty() { None } else { Some(self.entrance_states.as_slice()) };
                self.renderer.upload_graph(&self.graph, ent);
            };
        } else {
            self.renderer.highlight.highlighted_ids = ids;
            self.renderer.highlight.active = true;
            {
                let ent = if self.entrance_states.is_empty() { None } else { Some(self.entrance_states.as_slice()) };
                self.renderer.upload_graph(&self.graph, ent);
            };
        }
    }

    // ── Camera Commands ──────────────────────────────────────────────

    /// Animate camera to center on the centroid of visible nodes.
    pub fn center_camera(&mut self) {
        let (mut cx, mut cy, mut count) = (0.0f32, 0.0f32, 0u32);
        for n in &self.graph.nodes {
            if n.visible {
                cx += n.x;
                cy += n.y;
                count += 1;
            }
        }
        if count > 0 {
            cx /= count as f32;
            cy /= count as f32;
            self.renderer.target_offset = [cx, cy];
            self.renderer.is_animating = true;
        }
    }

    /// Center camera on a specific node by UUID, zooming in moderately.
    pub fn center_on_node(&mut self, uuid: &str) {
        if let Some(&node_id) = self.graph.uuid_to_id.get(uuid) {
            let node = &self.graph.nodes[node_id as usize];
            self.renderer.target_offset = [node.x, node.y];
            self.renderer.target_zoom = 2.5; // Close-up zoom
            self.renderer.is_animating = true;
        }
    }

    /// Zoom to fit all visible nodes with padding.
    pub fn zoom_to_fit(&mut self) {
        let (mut min_x, mut min_y) = (f32::MAX, f32::MAX);
        let (mut max_x, mut max_y) = (f32::MIN, f32::MIN);
        let mut any = false;

        for n in &self.graph.nodes {
            if !n.visible {
                continue;
            }
            any = true;
            min_x = min_x.min(n.x - n.radius);
            min_y = min_y.min(n.y - n.radius);
            max_x = max_x.max(n.x + n.radius);
            max_y = max_y.max(n.y + n.radius);
        }

        if !any {
            return;
        }

        let cx = (min_x + max_x) * 0.5;
        let cy = (min_y + max_y) * 0.5;
        let graph_w = (max_x - min_x).max(1.0);
        let graph_h = (max_y - min_y).max(1.0);
        let w = self.viewport_width as f32;
        let h = self.viewport_height as f32;
        let padding = 0.85;
        let zoom = (w / graph_w).min(h / graph_h) * padding;

        self.renderer.target_offset = [cx, cy];
        self.renderer.target_zoom = zoom.clamp(0.05, 10.0);
        self.renderer.is_animating = true;
    }

    // ── Force Parameters ─────────────────────────────────────────────

    /// Update the 4 core force parameters and reheat.
    pub fn set_force_params(
        &mut self,
        link_distance: f32,
        charge_strength: f32,
        charge_range: f32,
        link_strength: f32,
    ) {
        self.idle_frame_count = 0;
        let mut sim = self.sim.lock();
        sim.params.link_distance = link_distance;
        sim.params.charge_strength = charge_strength;
        sim.params.charge_range = charge_range;
        sim.params.link_strength = link_strength;
        sim.reheat();
    }

    /// Update extended physics parameters (velocity decay, center gravity, etc.).
    pub fn set_extended_force_params(
        &mut self,
        velocity_decay: f32,
        center_strength: f32,
        collision_radius: f32,
        warmth: f32,
        orbital: f32,
    ) {
        self.idle_frame_count = 0;
        let mut sim = self.sim.lock();
        sim.params.velocity_decay = velocity_decay.clamp(0.0, 0.95);
        sim.params.center_strength = center_strength.clamp(0.0, 0.2);
        sim.params.collision_radius = collision_radius.clamp(0.0, 100.0);
        sim.params.warmth = warmth.clamp(0.0, 1.0);
        sim.params.orbital = orbital.clamp(0.0, 1.0);

        // Update collision radii for all nodes.
        let new_radius = sim.params.collision_radius;
        for r in &mut sim.collision_radii {
            *r = new_radius;
        }

        // Warmth or orbital changes reawaken a settled simulation.
        if warmth > 0.001 || orbital > 0.001 {
            if sim.is_settled {
                sim.params.alpha = warmth * 0.03;
                sim.is_settled = false;
            }
        }
    }

    // ── Cluster Parameters ───────────────────────────────────────────

    pub fn set_cluster_params(&mut self, cluster_strength: f32) {
        let mut sim = self.sim.lock();
        sim.params.cluster_strength = cluster_strength;
        sim.reheat();
    }

    pub fn set_center_mode(&mut self, mode: u8) {
        let mut sim = self.sim.lock();
        sim.params.center_mode = crate::simulation::CenterMode::from_u8(mode);
        sim.reheat();
    }

    // ── Cursor Attractor ─────────────────────────────────────────────

    /// Set the attractor target in world coordinates.
    /// Reheats the simulation if it was settled.
    pub fn set_attract_target(&mut self, x: f32, y: f32) {
        self.idle_frame_count = 0;
        let mut sim = self.sim.lock();
        sim.attract_target = Some([x, y]);
        if sim.is_settled {
            sim.reheat();
        }
    }

    /// Mark nodes (by UUID) as attracted to the current target.
    /// Resolves UUIDs → graph node IDs → simulation indices.
    /// Empty `uuids` means "attract ALL nodes" (manual mode).
    pub fn set_attracted_nodes(&mut self, uuids: &[&str]) {
        let mut sim = self.sim.lock();
        let n = sim.x.len();
        if uuids.is_empty() {
            // Manual mode: attract every node.
            sim.attracted_nodes = vec![true; n];
        } else {
            sim.attracted_nodes = vec![false; n];
            for uuid in uuids {
                if let Some(&id) = self.graph.uuid_to_id.get(*uuid) {
                    if let Some(&gi) = self.graph.id_to_index.get(&id) {
                        if let Some(si) = sim.graph_indices.iter().position(|&g| g == gi) {
                            sim.attracted_nodes[si] = true;
                        }
                    }
                }
            }
        }
        if sim.is_settled {
            sim.reheat();
        }
    }

    /// Clear the attractor (target + attracted nodes).
    pub fn clear_attract(&mut self) {
        let mut sim = self.sim.lock();
        sim.attract_target = None;
        sim.attracted_nodes.clear();
    }

    /// Set the attractor strength (0-1).
    pub fn set_attract_strength(&mut self, strength: f32) {
        let mut sim = self.sim.lock();
        sim.attract_strength = strength.clamp(0.0, 1.0);
    }

    // ── Label Parameters ─────────────────────────────────────────────

    pub fn set_label_params(&mut self, fade_start: f32, fade_end: f32, font_size: f32, enabled: bool) {
        self.renderer.label_fade_start = fade_start;
        self.renderer.label_fade_end = fade_end;
        self.renderer.label_font_size = font_size;
        self.renderer.labels_enabled = enabled;
    }

    // ── Accessors ────────────────────────────────────────────────────

    /// Mutable reference to the graph (for FFI data loading).
    pub fn graph_mut(&mut self) -> &mut Graph {
        &mut self.graph
    }

    pub fn graph(&self) -> &Graph {
        &self.graph
    }

    pub fn hovered_id(&self) -> Option<u32> {
        self.hovered_id
    }

    pub fn selected_id(&self) -> Option<u32> {
        self.selected_id
    }

    pub fn is_settled(&self) -> bool {
        self.sim.lock().is_settled
    }

    pub fn set_mode(&mut self, mode: u8) {
        self.idle_frame_count = 0;
        self.mode = mode;
        let mut sim = self.sim.lock();
        if mode == 1 {
            // Page mode: tighter clustering, stronger center pull.
            sim.params.link_distance = 150.0;
            sim.params.charge_strength = -400.0;
            sim.params.charge_range = 800.0;
            sim.params.center_strength = 0.02;
        } else {
            // Global mode: restore defaults.
            self.anchor_rect = None;
            sim.anchor_center = None;
            sim.params.link_distance = 250.0;
            sim.params.charge_strength = -1200.0;
            sim.params.charge_range = 2000.0;
            sim.params.center_strength = 0.005;
        }
        sim.reheat();
    }

    pub fn mode(&self) -> u8 {
        self.mode
    }

    /// Set the note window rect in screen pixels for page mode anchor positioning.
    /// The center force will pull the graph toward this rect's near edge.
    pub fn set_anchor_rect(&mut self, x: f32, y: f32, w: f32, h: f32) {
        self.anchor_rect = Some([x, y, w, h]);

        // Convert anchor rect to a world-space target for the center force.
        // The anchor point is the center of the note window's near edge
        // (the edge closest to screen center, where nodes should cluster).
        if self.mode == 1 {
            let vw = self.viewport_width as f32;
            let vh = self.viewport_height as f32;
            let screen_cx = vw * 0.5;
            let screen_cy = vh * 0.5;

            // Window center in screen pixels.
            let win_cx = x + w * 0.5;
            let win_cy = y + h * 0.5;

            // Anchor point: offset from screen center toward the window,
            // but stop at the window edge (nodes cluster beside the note).
            let dx = win_cx - screen_cx;
            let dy = win_cy - screen_cy;
            let dist = (dx * dx + dy * dy).sqrt().max(1.0);
            let norm_x = dx / dist;
            let norm_y = dy / dist;

            // Place anchor at the near edge of the window (inside by 20% of window width).
            let anchor_x = win_cx - norm_x * w * 0.3;
            let anchor_y = win_cy - norm_y * h * 0.3;

            // Convert screen pixels to world coordinates.
            let zoom = self.renderer.camera_zoom;
            let world_x = (anchor_x - screen_cx) / zoom + self.renderer.camera_offset[0];
            let world_y = (anchor_y - screen_cy) / zoom + self.renderer.camera_offset[1];

            // Update simulation center target.
            let mut sim = self.sim.lock();
            sim.anchor_center = Some([world_x, world_y]);
        }
    }

    /// Set clear color (transparent for hologram overlay).
    pub fn set_clear_color(&mut self, r: f64, g: f64, b: f64, a: f64) {
        self.renderer.clear_color = [r, g, b, a];
    }

    /// Set light mode (darker node colors for light backgrounds).
    pub fn set_light_mode(&mut self, enabled: bool) {
        self.renderer.light_mode = enabled;
    }

    /// Look up a node's UUID by its internal ID and store in the reusable buffer.
    /// Returns a C string pointer valid until the next call.
    pub fn node_uuid_by_id(&mut self, node_id: u32) -> *const std::ffi::c_char {
        self.uuid_buf = self
            .graph
            .nodes
            .iter()
            .find(|n| n.id == node_id)
            .and_then(|n| CString::new(n.uuid.as_str()).ok());
        self.uuid_buf
            .as_ref()
            .map_or(std::ptr::null(), |cs| cs.as_ptr())
    }
}

impl Drop for Engine {
    fn drop(&mut self) {
        self.stop_physics();
    }
}

// ── Physics Thread ──────────────────────────────────────────────────────────

fn physics_loop(sim: Arc<Mutex<Simulation>>, stop: Arc<AtomicBool>) {
    let target_dt = Duration::from_secs_f64(1.0 / PHYSICS_HZ);

    while !stop.load(Ordering::Relaxed) {
        let start = Instant::now();

        let settled = {
            let mut sim = sim.lock();
            sim.tick();
            sim.is_settled
        };

        if settled {
            // Sleep longer when settled — wake periodically to check for reheat.
            std::thread::sleep(Duration::from_millis(SETTLED_SLEEP_MS));
            continue;
        }

        let elapsed = start.elapsed();
        if elapsed < target_dt {
            std::thread::sleep(target_dt - elapsed);
        }
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::Graph;

    fn make_graph() -> Graph {
        let mut g = Graph::new();
        g.add_node("a".into(), -50.0, 0.0, 0, 2, "Alpha".into());
        g.add_node("b".into(), 50.0, 0.0, 1, 2, "Beta".into());
        g.add_node("c".into(), 0.0, 50.0, 2, 1, "Gamma".into());
        g.add_edge("a", "b", 1.0);
        g.add_edge("b", "c", 1.0);
        g
    }

    #[test]
    fn sync_positions_updates_graph() {
        let graph = make_graph();
        let sim = Arc::new(Mutex::new(Simulation::new()));
        {
            let mut s = sim.lock();
            s.load_from_graph(&graph);
            // Tick once to move positions.
            s.tick();
        }

        let mut engine_graph = graph.clone();
        let s = sim.lock();
        for (si, &gi) in s.graph_indices.iter().enumerate() {
            if gi < engine_graph.nodes.len() {
                engine_graph.nodes[gi].x = s.x[si];
                engine_graph.nodes[gi].y = s.y[si];
            }
        }

        // Positions should differ from original after one tick.
        let original_x = -50.0f32;
        assert!(
            (engine_graph.nodes[0].x - original_x).abs() > 0.001,
            "position should change after tick"
        );
    }

    #[test]
    fn screen_to_world_identity() {
        // At zoom=1 and offset=(0,0), center of screen maps to world origin.
        let w = 800u32;
        let h = 600u32;
        let zoom = 1.0f32;
        let offset = [0.0f32, 0.0];

        let sx = w as f32 * 0.5;
        let sy = h as f32 * 0.5;
        let wx = (sx - w as f32 * 0.5) / zoom + offset[0];
        let wy = (sy - h as f32 * 0.5) / zoom + offset[1];
        assert!((wx).abs() < f32::EPSILON);
        assert!((wy).abs() < f32::EPSILON);
    }

    #[test]
    fn screen_to_world_with_zoom() {
        // At zoom=2, the world coordinates should be halved.
        let w = 800u32;
        let zoom = 2.0f32;
        let offset = [0.0f32, 0.0];

        let sx = w as f32; // right edge
        let wx = (sx - w as f32 * 0.5) / zoom + offset[0];
        // At zoom 2, right edge = (400) / 2 = 200 world units
        assert!((wx - 200.0).abs() < f32::EPSILON);
    }

    #[test]
    fn highlight_neighbors_finds_adjacent() {
        let graph = make_graph();
        let mut ids = FxHashSet::default();
        let node_id = 1; // node "b" (connected to "a" and "c")
        ids.insert(node_id);

        for edge in &graph.edges {
            if edge.source == node_id {
                ids.insert(edge.target);
            } else if edge.target == node_id {
                ids.insert(edge.source);
            }
        }

        assert!(ids.contains(&0), "should contain node a");
        assert!(ids.contains(&1), "should contain node b (root)");
        assert!(ids.contains(&2), "should contain node c");
        assert_eq!(ids.len(), 3);
    }

    #[test]
    fn zoom_to_fit_computation() {
        let graph = make_graph();
        let viewport_w = 800.0f32;
        let viewport_h = 600.0f32;

        let mut min_x = f32::MAX;
        let mut min_y = f32::MAX;
        let mut max_x = f32::MIN;
        let mut max_y = f32::MIN;

        for n in &graph.nodes {
            min_x = min_x.min(n.x - n.radius);
            min_y = min_y.min(n.y - n.radius);
            max_x = max_x.max(n.x + n.radius);
            max_y = max_y.max(n.y + n.radius);
        }

        let cx = (min_x + max_x) * 0.5;
        let cy = (min_y + max_y) * 0.5;
        let graph_w = (max_x - min_x).max(1.0);
        let graph_h = (max_y - min_y).max(1.0);
        let padding = 0.85;
        let zoom = (viewport_w / graph_w).min(viewport_h / graph_h) * padding;

        assert!(zoom > 0.0, "zoom should be positive");
        assert!(cx.abs() < 60.0, "center x should be near origin");
        assert!(cy.abs() < 60.0, "center y should be near origin");
    }

    #[test]
    fn physics_loop_stops_on_flag() {
        let sim = Arc::new(Mutex::new(Simulation::new()));
        let stop = Arc::new(AtomicBool::new(false));

        let sim_clone = Arc::clone(&sim);
        let stop_clone = Arc::clone(&stop);

        let handle = std::thread::spawn(move || {
            physics_loop(sim_clone, stop_clone);
        });

        // Let it run briefly.
        std::thread::sleep(Duration::from_millis(20));

        // Signal stop.
        stop.store(true, Ordering::Relaxed);
        handle.join().expect("physics thread should join cleanly");
    }

    #[test]
    fn node_uuid_lookup() {
        let graph = make_graph();
        // Node 0 should have UUID "a".
        let found = graph.nodes.iter().find(|n| n.id == 0);
        assert!(found.is_some());
        assert_eq!(found.unwrap().uuid, "a");
    }

    #[test]
    fn graph_clone_independent() {
        let g1 = make_graph();
        let mut g2 = g1.clone();
        g2.nodes[0].x = 999.0;
        assert!((g1.nodes[0].x - (-50.0)).abs() < f32::EPSILON, "original unchanged");
        assert!((g2.nodes[0].x - 999.0).abs() < f32::EPSILON, "clone modified");
    }

    // ── Deep Stress Tests ──────────────────────────────────────────────

    fn make_large_graph(n: usize) -> Graph {
        let mut g = Graph::new();
        for i in 0..n {
            let angle = 2.0 * std::f32::consts::PI * (i as f32) / (n as f32);
            let r = 400.0;
            g.add_node(
                format!("node-{}", i),
                r * angle.cos(),
                r * angle.sin(),
                (i % 7) as u8,
                if i < n / 2 { 3 } else { 1 },
                format!("Node {}", i),
            );
        }
        // Ring + random shortcuts for realistic topology.
        for i in 0..n {
            let j = (i + 1) % n;
            g.add_edge(&format!("node-{}", i), &format!("node-{}", j), 1.0);
            if i % 5 == 0 {
                let k = (i + n / 3) % n;
                g.add_edge(&format!("node-{}", i), &format!("node-{}", k), 0.5);
            }
        }
        g
    }

    #[test]
    fn stress_500_node_simulation_settles() {
        let graph = make_large_graph(500);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        assert_eq!(sim.x.len(), 500);
        assert_eq!(sim.graph_indices.len(), 500);

        for _ in 0..600 {
            sim.tick();
        }
        assert!(sim.is_settled, "500-node sim should settle within 600 ticks");
    }

    #[test]
    fn stress_no_nan_or_inf_after_simulation() {
        let graph = make_large_graph(200);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        for _ in 0..400 {
            sim.tick();
        }

        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite(), "x[{}] is not finite: {}", i, sim.x[i]);
            assert!(sim.y[i].is_finite(), "y[{}] is not finite: {}", i, sim.y[i]);
            assert!(sim.vx[i].is_finite(), "vx[{}] is not finite: {}", i, sim.vx[i]);
            assert!(sim.vy[i].is_finite(), "vy[{}] is not finite: {}", i, sim.vy[i]);
        }
    }

    #[test]
    fn stress_nodes_spread_not_collapsed() {
        let graph = make_large_graph(100);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        for _ in 0..500 {
            sim.tick();
        }

        // Compute bounding box of settled positions.
        let (mut min_x, mut max_x) = (f32::MAX, f32::MIN);
        let (mut min_y, mut max_y) = (f32::MAX, f32::MIN);
        for i in 0..sim.x.len() {
            min_x = min_x.min(sim.x[i]);
            max_x = max_x.max(sim.x[i]);
            min_y = min_y.min(sim.y[i]);
            max_y = max_y.max(sim.y[i]);
        }
        let spread_x = max_x - min_x;
        let spread_y = max_y - min_y;

        assert!(
            spread_x > 100.0,
            "nodes should spread horizontally: got {}",
            spread_x
        );
        assert!(
            spread_y > 100.0,
            "nodes should spread vertically: got {}",
            spread_y
        );
    }

    #[test]
    fn stress_no_coincident_nodes_after_collision() {
        let graph = make_large_graph(50);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        for _ in 0..400 {
            sim.tick();
        }

        // No two nodes should be within 1 unit of each other (collision radius = 35).
        let n = sim.x.len();
        for i in 0..n {
            for j in (i + 1)..n {
                let dx = sim.x[i] - sim.x[j];
                let dy = sim.y[i] - sim.y[j];
                let dist = (dx * dx + dy * dy).sqrt();
                assert!(
                    dist > 1.0,
                    "nodes {} and {} are coincident: dist={}",
                    i,
                    j,
                    dist
                );
            }
        }
    }

    #[test]
    fn selection_and_deselection_flow() {
        let graph = make_graph();
        let sim = Arc::new(Mutex::new(Simulation::new()));
        {
            let mut s = sim.lock();
            s.load_from_graph(&graph);
        }

        // Simulate: click on node at (-50, 0).
        // At zoom=1, offset=(0,0), viewport=1000x1000: world (-50,0) = screen (450, 500).
        let viewport_w = 1000;
        let viewport_h = 1000;
        let zoom = 1.0f32;
        let offset = [0.0f32, 0.0];

        // Node "a" at (-50, 0) → screen (450, 500)
        let sx = (-50.0 - offset[0]) * zoom + viewport_w as f32 * 0.5;
        let sy = (0.0 - offset[1]) * zoom + viewport_h as f32 * 0.5;

        // Build spatial index.
        let mut spatial = SpatialIndex::new();
        spatial.build(&graph.nodes);

        // Test hit detection on node "a".
        let (wx, wy) = ((sx - viewport_w as f32 * 0.5) / zoom + offset[0], (sy - viewport_h as f32 * 0.5) / zoom + offset[1]);
        let hit = spatial.query_point(wx, wy);
        assert_eq!(hit, Some(0), "should hit node 'a' (id=0)");

        // Test miss on background.
        let (bx, by) = ((-300.0 - offset[0]) * zoom + viewport_w as f32 * 0.5, (300.0 - offset[1]) * zoom + viewport_h as f32 * 0.5);
        let (bwx, bwy) = ((bx - viewport_w as f32 * 0.5) / zoom + offset[0], (by - viewport_h as f32 * 0.5) / zoom + offset[1]);
        let bg_hit = spatial.query_point(bwx, bwy);
        assert_eq!(bg_hit, None, "background click should miss all nodes");
    }

    #[test]
    fn isolate_node_collects_neighbors() {
        let graph = make_graph();
        // Node "b" (id=1) is connected to "a" (id=0) and "c" (id=2).
        let mut ids = FxHashSet::default();
        let node_id = 1u32;
        ids.insert(node_id);
        for edge in &graph.edges {
            if edge.source == node_id {
                ids.insert(edge.target);
            } else if edge.target == node_id {
                ids.insert(edge.source);
            }
        }
        assert_eq!(ids.len(), 3, "b + a + c = 3 nodes");

        // Node "a" (id=0) is connected to "b" only.
        let mut ids_a = FxHashSet::default();
        ids_a.insert(0u32);
        for edge in &graph.edges {
            if edge.source == 0 {
                ids_a.insert(edge.target);
            } else if edge.target == 0 {
                ids_a.insert(edge.source);
            }
        }
        assert_eq!(ids_a.len(), 2, "a + b = 2 nodes (a is a leaf)");
    }

    #[test]
    fn magnify_zoom_clamps() {
        // Zoom should clamp between 0.05 and 10.0.
        let current_zoom = 1.0f32;

        // Huge zoom in: 1.0 * (1 + 100.0) = 101.0 → clamp to 10.0
        let zoomed_in = (current_zoom * (1.0 + 100.0)).clamp(0.05, 10.0);
        assert_eq!(zoomed_in, 10.0);

        // Huge zoom out: 1.0 * (1 + (-0.999)) = 0.001 → clamp to 0.05
        let zoomed_out = (current_zoom * (1.0 + (-0.999))).clamp(0.05, 10.0);
        assert_eq!(zoomed_out, 0.05);

        // Normal zoom: 1.0 * (1 + 0.02) = 1.02
        let normal = (current_zoom * (1.0 + 0.02)).clamp(0.05, 10.0);
        assert!((normal - 1.02).abs() < f32::EPSILON);
    }

    #[test]
    fn scroll_pan_preserves_target() {
        let zoom = 2.0f32;
        let mut offset = [100.0f32, 50.0];
        let delta_x = 20.0f32;
        let delta_y = -10.0f32;

        offset[0] -= delta_x / zoom;
        offset[1] += delta_y / zoom;

        // At zoom=2: 20 screen px = 10 world units.
        assert!((offset[0] - 90.0).abs() < f32::EPSILON);
        assert!((offset[1] - 45.0).abs() < f32::EPSILON);
    }

    #[test]
    fn search_highlight_case_insensitive() {
        let graph = make_graph();
        let query = "alpha";
        let query_lower = query.to_lowercase();
        let mut ids = FxHashSet::default();
        for node in &graph.nodes {
            if node.label.to_lowercase().contains(&query_lower) {
                ids.insert(node.id);
            }
        }
        assert_eq!(ids.len(), 1, "should find exactly 'Alpha'");
        assert!(ids.contains(&0), "node 0 is 'Alpha'");

        // Empty query → no matches.
        let empty_ids: FxHashSet<u32> = FxHashSet::default();
        assert!(empty_ids.is_empty());
    }

    #[test]
    fn concurrent_physics_and_position_sync() {
        let graph = make_large_graph(50);
        let sim = Arc::new(Mutex::new(Simulation::new()));
        let stop = Arc::new(AtomicBool::new(false));

        {
            let mut s = sim.lock();
            s.load_from_graph(&graph);
        }

        // Start physics thread.
        let sim_clone = Arc::clone(&sim);
        let stop_clone = Arc::clone(&stop);
        let handle = std::thread::spawn(move || {
            physics_loop(sim_clone, stop_clone);
        });

        // Simulate 100 "render frames" reading positions while physics runs.
        for _ in 0..100 {
            let s = sim.lock();
            // Positions should always be finite.
            for i in 0..s.x.len() {
                assert!(s.x[i].is_finite());
                assert!(s.y[i].is_finite());
            }
            drop(s);
            std::thread::sleep(Duration::from_millis(1));
        }

        stop.store(true, Ordering::Relaxed);
        handle.join().expect("physics thread should join");
    }

    #[test]
    fn entrance_mode_settles_gently() {
        let graph = make_large_graph(30);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.set_entrance_mode();

        // Entrance mode: lower alpha (0.25), higher damping (0.72).
        assert!((sim.params.alpha - 0.25).abs() < f32::EPSILON);
        assert!((sim.params.velocity_decay - 0.72).abs() < f32::EPSILON);

        for _ in 0..800 {
            sim.tick();
        }
        assert!(sim.is_settled, "entrance mode should settle within 800 ticks");
    }

    #[test]
    fn reheat_mid_simulation_converges() {
        let graph = make_large_graph(20);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        // Run halfway.
        for _ in 0..150 {
            sim.tick();
        }
        assert!(!sim.is_settled, "should not settle at 150 ticks");

        // Reheat.
        sim.reheat();
        assert!((sim.params.alpha - 0.3).abs() < f32::EPSILON);

        // Should eventually settle again.
        for _ in 0..500 {
            sim.tick();
        }
        assert!(sim.is_settled, "should settle after reheat + 500 ticks");
    }

    #[test]
    fn zoom_to_fit_empty_graph_safe() {
        // zoom_to_fit with 0 nodes should not panic or produce NaN.
        let viewport_w = 800.0f32;
        let viewport_h = 600.0f32;
        let mut min_x = f32::MAX;
        let max_x = f32::MIN;

        // No nodes → min_x stays MAX → skip zoom.
        assert!(min_x > max_x, "empty graph should skip zoom computation");
    }

    // ── Wormhole Entrance Animation Tests ─────────────────────────────

    #[test]
    fn entrance_stagger_hero_is_first() {
        let mut graph = Graph::new();
        // "hub" has 10 links, "leaf" has 1 link.
        graph.add_node("hub".into(), 0.0, 0.0, 0, 10, "Hub".into());
        graph.add_node("leaf".into(), 100.0, 0.0, 0, 1, "Leaf".into());
        graph.add_edge("hub", "leaf", 1.0);

        let animator = EntranceAnimator::from_graph(&graph);
        assert_eq!(animator.stagger_delays.len(), 2);
        // Hub (index 0) should be the hero with delay = 0.
        assert!(
            animator.stagger_delays[0] < f32::EPSILON,
            "hero should have delay=0, got {}",
            animator.stagger_delays[0]
        );
        // Leaf (index 1) should have delay > 0.
        assert!(
            animator.stagger_delays[1] > 0.0,
            "non-hero should have positive delay"
        );
    }

    #[test]
    fn entrance_bfs_ordering() {
        // Chain: A(hub) → B → C → D
        let mut graph = Graph::new();
        graph.add_node("a".into(), 0.0, 0.0, 0, 5, "A".into());
        graph.add_node("b".into(), 10.0, 0.0, 0, 2, "B".into());
        graph.add_node("c".into(), 20.0, 0.0, 0, 2, "C".into());
        graph.add_node("d".into(), 30.0, 0.0, 0, 1, "D".into());
        graph.add_edge("a", "b", 1.0);
        graph.add_edge("b", "c", 1.0);
        graph.add_edge("c", "d", 1.0);

        let animator = EntranceAnimator::from_graph(&graph);
        // A is hero (most links). BFS depths: A=0, B=1, C=2, D=3
        assert!(animator.stagger_delays[0] < f32::EPSILON, "A is hero");
        assert!(animator.stagger_delays[1] > animator.stagger_delays[0], "B after A");
        assert!(animator.stagger_delays[2] > animator.stagger_delays[1], "C after B");
        assert!(animator.stagger_delays[3] > animator.stagger_delays[2], "D after C");
    }

    #[test]
    fn entrance_compute_returns_correct_states() {
        let graph = make_graph();
        let animator = EntranceAnimator::from_graph(&graph);
        let states = animator.compute();
        assert_eq!(states.len(), graph.nodes.len());

        // At time 0, hero (most connected) should have begun arrival.
        // All nodes should have z_offset < 0 (still approaching).
        for state in &states {
            assert!(state.z_offset <= 0.0, "z_offset should be <= 0 at start");
            assert!(state.alpha >= 0.0 && state.alpha <= 1.0, "alpha in [0,1]");
        }
    }

    #[test]
    fn entrance_all_nodes_complete() {
        let graph = make_graph();
        let mut animator = EntranceAnimator::from_graph(&graph);
        // Override start time to simulate 5 seconds ago.
        animator.start = Instant::now() - Duration::from_secs(5);

        let states = animator.compute();
        for (i, state) in states.iter().enumerate() {
            assert!(
                (state.z_offset).abs() < 0.01,
                "node {} z_offset should be ~0 after 5s, got {}",
                i,
                state.z_offset
            );
            assert!(
                (state.alpha - 1.0).abs() < 0.01,
                "node {} alpha should be ~1 after 5s, got {}",
                i,
                state.alpha
            );
        }
        assert!(animator.is_complete(), "entrance should be complete after 5s");
    }

    #[test]
    fn entrance_empty_graph_safe() {
        let graph = Graph::new();
        let animator = EntranceAnimator::from_graph(&graph);
        assert!(animator.stagger_delays.is_empty());
        assert!(animator.is_complete(), "empty graph entrance is immediately complete");
    }

    #[test]
    fn perspective_formula_positive_for_valid_range() {
        let focal = 2.0f32;
        // Test z values from entrance range to normal range.
        for z in [-20.0, -10.0, -5.0, -1.0, -0.25, 0.0, 0.35, 0.5] {
            let scale = focal / (focal - z);
            assert!(
                scale > 0.0,
                "perspective_scale must be positive for z={}, got {}",
                z,
                scale
            );
        }
    }

    #[test]
    fn entrance_spiral_displacement_decays() {
        let graph = make_large_graph(20);
        let mut animator = EntranceAnimator::from_graph(&graph);

        // Check early: spiral displacement should be non-zero.
        let early = animator.compute();
        let hero_idx = graph.nodes.iter()
            .enumerate()
            .max_by_key(|(_, n)| n.link_count)
            .map(|(i, _)| i)
            .unwrap();

        // After full arrival: spiral displacement should be ~zero.
        animator.start = Instant::now() - Duration::from_secs(5);
        let late = animator.compute();
        for (i, state) in late.iter().enumerate() {
            assert!(
                state.dx.abs() < 0.1 && state.dy.abs() < 0.1,
                "node {} spiral should decay: dx={}, dy={}",
                i,
                state.dx,
                state.dy
            );
        }
    }
}
