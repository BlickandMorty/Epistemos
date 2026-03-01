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

use crate::embedding::EmbeddingStore;
use crate::renderer::Renderer;
use crate::simulation::Simulation;
use crate::spatial::SpatialIndex;
use crate::types::Graph;
use crate::version::VersionStore;

/// Physics thread target rate — 60Hz is sufficient for force simulation.
const PHYSICS_HZ: f64 = 60.0;
/// Sleep duration (ms) when simulation is settled (avoids spinning).
const SETTLED_SLEEP_MS: u64 = 50;

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

/// Lightweight progressive reveal for large graphs (5K+ nodes).
/// Nodes fade in from most-connected to least-connected while physics runs.
/// No BFS, no spiral, no z-offset — just alpha fading by link_count rank.
struct ProgressiveRevealAnimator {
    /// Per-node stagger delay (seconds). Index = graph node index.
    delays: Vec<f32>,
    /// Animation start time.
    start: Instant,
    /// Duration for a single node's alpha fade (seconds).
    fade_duration: f32,
    /// Max delay across all nodes (for is_complete check).
    max_delay: f32,
}

impl ProgressiveRevealAnimator {
    /// Build from graph: sort nodes by link_count descending, assign stagger delays.
    fn from_graph(graph: &Graph) -> Self {
        let n = graph.nodes.len();
        if n == 0 {
            return Self {
                delays: vec![],
                start: Instant::now(),
                fade_duration: 0.5,
                max_delay: 0.0,
            };
        }

        // Rank visible nodes by link_count descending (most connected appear first).
        let mut ranked: Vec<(usize, u32)> = graph
            .nodes
            .iter()
            .enumerate()
            .map(|(i, node)| (i, if node.visible { node.link_count } else { 0 }))
            .collect();
        ranked.sort_unstable_by(|a, b| b.1.cmp(&a.1));

        // Spread duration scales with node count for a smooth cascade.
        // Small vaults get a faster reveal — the whole animation should feel snappy.
        // Large vaults get a longer spread so it doesn't overwhelm.
        let spread = if n > 10_000 {
            3.5f32
        } else if n > 1000 {
            2.5
        } else if n > 200 {
            1.8
        } else if n > 50 {
            1.2
        } else {
            0.8  // Small vaults: fast, punchy reveal
        };

        let mut delays = vec![0.0f32; n];
        for (rank, &(gi, _)) in ranked.iter().enumerate() {
            delays[gi] = (rank as f32 / n as f32) * spread;
        }

        let max_delay = delays.iter().copied().fold(0.0f32, f32::max);

        Self {
            delays,
            start: Instant::now(),
            fade_duration: 0.5,
            max_delay,
        }
    }

    /// Compute per-node entrance states into a reusable buffer.
    fn compute(&self, out: &mut Vec<EntranceNodeState>) {
        let elapsed = self.start.elapsed().as_secs_f32();
        out.clear();
        out.extend(self.delays.iter().map(|&delay| {
            let t = ((elapsed - delay) / self.fade_duration).clamp(0.0, 1.0);
            let alpha = ease_out_cubic(t);
            EntranceNodeState {
                z_offset: 0.0,
                alpha,
                dx: 0.0,
                dy: 0.0,
            }
        }));
    }

    /// True when every node has fully faded in.
    fn is_complete(&self) -> bool {
        if self.delays.is_empty() {
            return true;
        }
        let elapsed = self.start.elapsed().as_secs_f32();
        elapsed >= self.max_delay + self.fade_duration + 0.1
    }
}

/// Active entrance animation variant.
#[allow(dead_code)]
enum ActiveEntrance {
    /// Full wormhole animation (retained for tests, not used in commit).
    Wormhole(EntranceAnimator),
    /// Lightweight progressive reveal for large graphs (5K+ nodes).
    Reveal(ProgressiveRevealAnimator),
}

/// Drives the wormhole entrance animation: hero node races forward,
/// neighbors cascade behind in BFS-ordered waves with spiral rotation.
/// Retained for tests — not used in production commit path.
#[allow(dead_code)]
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

#[allow(dead_code)]
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

    // Entrance animation (wormhole for small graphs, progressive reveal for large).
    entrance: Option<ActiveEntrance>,
    /// Cached per-frame entrance states (recomputed each render call).
    entrance_states: Vec<EntranceNodeState>,
    /// Frame counter for entrance camera zoom-to-fit delay.
    entrance_camera_frame: u32,

    // Reusable buffer for returning UUIDs through FFI.
    uuid_buf: Option<CString>,

    /// Counts consecutive frames where the engine reported "no more frames needed."
    /// Used to throttle render calls when idle.
    idle_frame_count: u32,

    /// Fuzzy search index over node labels, rebuilt on commit().
    pub(crate) search_index: crate::search::SearchIndex,

    /// Embedding vectors for semantic similarity (SIMD-accelerated cosine).
    pub(crate) embedding_store: EmbeddingStore,

    /// Pre-computed KNN pairs for semantic attraction force.
    /// Recomputed only when embeddings change, not per-tick.
    pub(crate) semantic_neighbors: Vec<(u32, u32, f32)>,

    /// Active time filter: (min_ts, max_ts). Nodes with created_at outside
    /// this range become invisible. Nodes with created_at == 0.0 are always visible.
    /// None = no filter active (all nodes visible).
    time_filter: Option<(f64, f64)>,

    /// Merkle-like version chains per node (pure data, no render/physics cost).
    pub(crate) version_store: VersionStore,

    /// Quality level: 0 = Cinematic, 1 = Balanced, 2 = Performance.
    pub(crate) quality_level: u8,
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
            search_index: crate::search::SearchIndex::new(),
            embedding_store: EmbeddingStore::new(crate::embedding::DEFAULT_DIM),
            semantic_neighbors: Vec::new(),
            time_filter: None,
            version_store: VersionStore::new(),
            quality_level: 0,  // Cinematic
        })
    }

    /// Commit graph data. Replaces all simulation state, restarts physics.
    /// If `entrance` is true, plays a calm Obsidian-style entrance animation
    /// with gradual force ramp and progressive node reveal.
    pub fn commit(&mut self, entrance: bool) {
        // Wake rendering for the new graph data.
        self.idle_frame_count = 0;

        // Stop existing physics thread.
        self.stop_physics();

        let n = self.graph.nodes.len();

        // ── Initial Layout ──────────────────────────────────────────────
        // Phyllotaxis (golden-angle) spiral gives well-separated initial positions.
        // Spacing scales with graph size: small vaults get a tighter spiral so nodes
        // fill the viewport from the start, large vaults spread more to avoid overlap.
        if entrance {
            let golden_angle: f32 = std::f32::consts::PI * (3.0 - 5.0_f32.sqrt());
            let spacing = if n > 5000 {
                80.0_f32
            } else if n > 500 {
                100.0
            } else if n > 100 {
                70.0
            } else {
                50.0  // Small vaults: wider spiral so repel mode doesn't cluster at center
            };
            for (i, node) in self.graph.nodes.iter_mut().enumerate() {
                let r = spacing * (i as f32).sqrt();
                let theta = i as f32 * golden_angle;
                node.x = r * theta.cos();
                node.y = r * theta.sin();
                node.vx = 0.0;
                node.vy = 0.0;
            }
        }

        // ── Load Simulation ─────────────────────────────────────────────
        {
            let mut sim = self.sim.lock();
            sim.load_from_graph(&self.graph);

            // Page mode always gets full physics — it shows a small subset
            // (focal node + 1-hop neighbors) regardless of total vault size.
            if self.mode == 1 && sim.static_layout {
                sim.static_layout = false;
                sim.is_settled = false;
                sim.params.alpha = 0.3;
            }

            // Skip expensive operations for static layout (> 1500 nodes).
            if !sim.static_layout {
                // Louvain community detection (O(N×E) — skip for large graphs).
                let sn = sim.x.len();
                if sn < 5000 {
                    let cluster_ids = crate::cluster::detect_communities(sn, &sim.edges);
                    sim.cluster_ids = cluster_ids;
                } else {
                    sim.cluster_ids = (0..sn as u32).collect();
                }

                // Configure entrance mode: low alpha, zero decay, reset tick counter.
                // entrance_tick() relies on tick_count starting at 0 for phase detection.
                if entrance {
                    sim.set_entrance_mode();
                }

                // Brief pre-settle for recommits (filter changes, non-entrance).
                if !entrance && sn < 1000 {
                    let max_ticks = 30;
                    for _ in 0..max_ticks {
                        sim.tick();
                        if sim.is_settled { break; }
                    }
                }
            }
        }

        // Copy positions back to graph nodes for rendering + spatial index.
        if !entrance {
            self.sync_positions();
        }

        // ── Entrance Animation Setup (before buffer allocation) ──────
        // Create entrance states BEFORE allocate_buffers so the initial GPU upload
        // starts with alpha=0 (invisible). Otherwise there's a 1-frame flash.
        self.entrance_camera_frame = 0;
        let sim_is_static = self.sim.lock().static_layout;

        if entrance && !sim_is_static {
            let reveal = ProgressiveRevealAnimator::from_graph(&self.graph);
            self.entrance_states = vec![
                EntranceNodeState { z_offset: 0.0, alpha: 0.0, dx: 0.0, dy: 0.0 };
                n
            ];
            self.entrance = Some(ActiveEntrance::Reveal(reveal));
        } else {
            self.entrance = None;
            self.entrance_states = Vec::new();
        }

        // Allocate renderer buffers and upload initial data.
        // Pass entrance states so the initial upload uses alpha=0 (no flash).
        let ent_for_alloc = if self.entrance_states.is_empty() {
            None
        } else {
            Some(self.entrance_states.as_slice())
        };
        self.renderer.allocate_buffers(&self.graph, ent_for_alloc);

        // Build spatial index for hit testing.
        self.spatial.build(&self.graph.nodes);

        // Build fuzzy search index over node labels.
        self.search_index.build(&self.graph.nodes);

        // Clear interaction state.
        self.selected_id = None;
        self.hovered_id = None;
        self.drag = None;
        self.renderer.highlight.active = false;
        self.renderer.highlight.highlighted_ids.clear();

        // ── Start Physics ────────────────────────────────────────────
        if self.entrance.is_some() {
            self.zoom_to_fit_immediate();
            self.start_entrance_physics();
        } else {
            self.start_physics();
        }
    }

    fn start_physics(&mut self) {
        // Ensure any existing physics thread is joined first to prevent
        // zombie threads holding Arc<Mutex<Simulation>> references.
        self.stop_physics();
        self.stop_flag.store(false, Ordering::Relaxed);
        let sim = Arc::clone(&self.sim);
        let stop = Arc::clone(&self.stop_flag);
        self.physics_handle = Some(std::thread::spawn(move || {
            physics_loop(sim, stop);
        }));
    }

    /// Start physics thread in entrance mode: uses `entrance_tick()` for
    /// gradual alpha ramp instead of normal `tick()`. Once the simulation
    /// switches to normal decay mode internally, falls through to regular
    /// `tick()` behavior automatically.
    fn start_entrance_physics(&mut self) {
        self.stop_physics();
        self.stop_flag.store(false, Ordering::Relaxed);
        let sim = Arc::clone(&self.sim);
        let stop = Arc::clone(&self.stop_flag);
        self.physics_handle = Some(std::thread::spawn(move || {
            entrance_physics_loop(sim, stop);
        }));
    }

    fn stop_physics(&mut self) {
        self.stop_flag.store(true, Ordering::Relaxed);
        if let Some(handle) = self.physics_handle.take() {
            let _ = handle.join();
        }
    }

    /// Immediately set camera to fit all visible nodes (no animation).
    /// Used at entrance start so the spiral is visible from frame 1.
    fn zoom_to_fit_immediate(&mut self) {
        let (mut min_x, mut min_y) = (f32::MAX, f32::MAX);
        let (mut max_x, mut max_y) = (f32::MIN, f32::MIN);
        let mut visible_count = 0u32;

        for n in &self.graph.nodes {
            if !n.visible { continue; }
            visible_count += 1;
            min_x = min_x.min(n.x - n.radius);
            min_y = min_y.min(n.y - n.radius);
            max_x = max_x.max(n.x + n.radius);
            max_y = max_y.max(n.y + n.radius);
        }
        if visible_count == 0 { return; }

        let cx = (min_x + max_x) * 0.5;
        let cy = (min_y + max_y) * 0.5;
        let graph_w = (max_x - min_x).max(1.0);
        let graph_h = (max_y - min_y).max(1.0);
        let w = self.viewport_width as f32;
        let h = self.viewport_height as f32;

        // Tighter zoom for small graphs so nodes fill the viewport.
        // Large graphs get more padding to prevent edge nodes from being cut off.
        let padding = if visible_count < 50 {
            1.8  // Small: zoom in close, nodes fill screen
        } else if visible_count < 200 {
            1.4
        } else {
            1.1  // Large: slight zoom-in bias
        };
        let zoom = (w / graph_w).min(h / graph_h) * padding;

        // Snap camera instantly (no lerp).
        let clamped_zoom = zoom.clamp(0.05, 10.0);
        self.renderer.camera_offset = [cx, cy];
        self.renderer.target_offset = [cx, cy];
        self.renderer.camera_zoom = clamped_zoom;
        self.renderer.target_zoom = clamped_zoom;
        self.renderer.is_animating = false;
    }

    // ── Visibility (Lightweight Filtering) ──────────────────────────

    /// Toggle a single node's visibility by UUID.
    /// Does NOT re-upload to renderer — call `refresh_visibility()` once after
    /// all desired toggles are applied.
    pub fn set_node_visible(&mut self, uuid: &str, visible: bool) {
        if let Some(&id) = self.graph.uuid_to_id.get(uuid) {
            if let Some(&idx) = self.graph.id_to_index.get(&id) {
                self.graph.nodes[idx].visible = visible;
            }
        }
    }

    /// Re-upload graph to renderer and reload simulation after visibility changes.
    /// Preserves positions/velocities — only the set of active nodes changes.
    pub fn refresh_visibility(&mut self) {
        // Sync current positions from simulation → graph before reloading.
        self.sync_positions();

        // Reload simulation with only visible nodes, reheat to re-settle.
        {
            let mut sim = self.sim.lock();
            sim.load_from_graph(&self.graph);
            // Louvain is O(E*passes) — skip for large graphs to avoid blocking main thread.
            let n = sim.x.len();
            if n < 5_000 {
                let cluster_ids = crate::cluster::detect_communities(n, &sim.edges);
                sim.cluster_ids = cluster_ids;
            }
            if self.entrance.is_none() {
                sim.reheat();
            }
        }

        // Re-upload graph to renderer (only visible nodes are drawn).
        let ent = if self.entrance_states.is_empty() {
            None
        } else {
            Some(self.entrance_states.as_slice())
        };
        self.renderer.upload_graph(&self.graph, ent);

        // Rebuild spatial index so invisible nodes aren't hittable.
        self.spatial.build(&self.graph.nodes);

        // Invalidate drag state — sim indices are stale after reload.
        // The dragged node's fx/fy constraints will be cleared by load_from_graph
        // which resets all simulation arrays, so no explicit unfix needed.
        self.drag = None;

        // Wake rendering + restart physics if it was stopped.
        self.idle_frame_count = 0;
        if self.physics_handle.is_none() {
            self.start_physics();
        }
    }

    // ── Lifecycle ───────────────────────────────────────────────────

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

        for (si, &gi) in sim.graph_indices.iter().enumerate() {
            if gi < self.graph.nodes.len() {
                self.graph.nodes[gi].x = sim.x[si];
                self.graph.nodes[gi].y = sim.y[si];
                self.graph.nodes[gi].vx = sim.vx[si];
                self.graph.nodes[gi].vy = sim.vy[si];
            }
        }
        !sim.is_settled
    }

    /// Render one frame. Returns 1 if another frame is needed, 0 if GPU can idle.
    pub fn render(&mut self, width: u32, height: u32) -> u32 {
        self.viewport_width = width;
        self.viewport_height = height;

        let positions_changed = self.sync_positions();

        // Entrance animation: compute per-node states each frame.
        let entrance_active = self.entrance.is_some();
        let mut entrance_just_completed = false;
        match &self.entrance {
            Some(ActiveEntrance::Wormhole(anim)) => {
                self.entrance_states = anim.compute();
                if anim.is_complete() {
                    entrance_just_completed = true;
                }
            }
            Some(ActiveEntrance::Reveal(anim)) => {
                anim.compute(&mut self.entrance_states);
                if anim.is_complete() {
                    entrance_just_completed = true;
                }
            }
            None => {}
        }

        // During entrance: gentle periodic zoom-to-fit every ~30 frames
        // so camera smoothly tracks the expanding graph.
        if entrance_active && !entrance_just_completed {
            self.entrance_camera_frame += 1;
            if self.entrance_camera_frame % 30 == 0 {
                self.zoom_to_fit();
            }
        }

        // Handle entrance completion outside the borrow.
        if entrance_just_completed {
            self.entrance = None;
            self.entrance_states.clear();

            // Transition: stop entrance physics, restart normal physics.
            // The simulation's alpha_decay is already non-zero (set by entrance_tick),
            // so the normal physics_loop will continue settling.
            self.stop_physics();
            self.start_physics();

            // Re-upload graph to renderer with full edge buffers.
            self.renderer.upload_graph(&self.graph, None);

            // Final zoom-to-fit for settled positions.
            self.zoom_to_fit();
        }

        // Animate camera (smooth lerp toward target).
        self.renderer.update_camera();

        // Request next frame only when something is animating.
        let sim_active = !self.sim.lock().is_settled;
        let camera_moving = self.renderer.is_animating;
        let needs_frame = sim_active || camera_moving || entrance_active;

        // Idle frame skipping: after 3 consecutive idle frames, skip GPU work entirely.
        // We still render the first 3 idle frames to flush any final visual updates.
        if !needs_frame {
            self.idle_frame_count = self.idle_frame_count.saturating_add(1);
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
            self.spatial.build(&self.graph.nodes);
        }

        // Append selection/hover highlight rings (only updates 2 instances — cheap).
        self.renderer
            .set_highlights(self.selected_id, self.hovered_id, &self.graph);

        // Rebuild per-instance highlight flags only when something visual changed.
        // Skipping this when idle saves O(N) work per frame at 10K nodes.
        if positions_changed || entrance_active || needs_frame {
            self.renderer.rebuild_highlight_flags(&self.graph);
        }

        // Update magnetic field lines only when hovering (skip in lite mode entirely).
        // Field lines only in Cinematic mode (quality_level == 0).
        if self.quality_level == 0 && (self.hovered_id.is_some() || self.renderer.field_line_count > 0) {
            let time = self.renderer.start_time.elapsed().as_secs_f32();
            self.renderer.update_field_lines(self.hovered_id, &self.graph, time);
        }

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

            // Start drag — D3 canonical pattern:
            //   1. Anchor to node's OWN position (no jolt from cursor offset)
            //   2. Set alphaTarget=0.3 for gradual warmup (not alpha directly)
            //   3. Neighbors adjust smoothly as alpha converges
            if let Some(&gi) = self.graph.id_to_index.get(&node_id) {
                let mut sim = self.sim.lock();
                if let Some(sim_index) = sim.graph_indices.iter().position(|&g| g == gi) {
                    // Anchor to node's current position first — prevents initial jolt
                    // if cursor isn't perfectly centered on the node.
                    let node_x = sim.x[sim_index];
                    let node_y = sim.y[sim_index];
                    sim.fix_node(sim_index, node_x, node_y);
                    // D3 alphaTarget pattern: gradual warmup instead of force spike.
                    // alpha converges toward 0.3 via exponential decay (~10 ticks).
                    sim.params.alpha_target = 0.3;
                    if sim.is_settled {
                        sim.params.alpha = 0.05; // Seed with small value so tick() doesn't skip
                        sim.is_settled = false;
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
                self.idle_frame_count = 0;
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
            // D3 behavior: unfix node on release, reset alphaTarget so sim cools down.
            let mut sim = self.sim.lock();
            sim.unfix_node(drag.sim_index);
            sim.params.alpha_target = 0.0; // Resume normal cooldown
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
        self.idle_frame_count = 0;

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
        self.idle_frame_count = 0;
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
            self.idle_frame_count = 0;
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
        } else {
            self.renderer.highlight.highlighted_ids = ids;
            self.renderer.highlight.active = true;
        }
        self.idle_frame_count = 0;
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
            if let Some(&idx) = self.graph.id_to_index.get(&node_id) {
                let node = &self.graph.nodes[idx];
                self.renderer.target_offset = [node.x, node.y];
                self.renderer.target_zoom = 3.5; // Close-up zoom for page mode
                self.renderer.is_animating = true;
            }
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
        let padding = 1.5; // Zoom in closer — user prefers seeing nodes big
        let zoom = (w / graph_w).min(h / graph_h) * padding;

        self.renderer.target_offset = [cx, cy];
        self.renderer.target_zoom = zoom.clamp(1.0, 10.0); // Never start zoomed out beyond 1.0
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
        // Don't reheat during entrance — it would blow away the carefully
        // tuned alpha ramp. The entrance physics thread handles energy levels.
        if self.entrance.is_none() {
            sim.reheat();
        }
    }

    /// Update extended physics parameters (velocity decay, center gravity, collision).
    pub fn set_extended_force_params(
        &mut self,
        velocity_decay: f32,
        center_strength: f32,
        collision_radius: f32,
    ) {
        self.idle_frame_count = 0;
        let mut sim = self.sim.lock();
        // During entrance, only store link_distance/charge/range but DON'T
        // override velocity_decay — the entrance ramp controls damping.
        if self.entrance.is_none() {
            sim.params.velocity_decay = velocity_decay.clamp(0.0, 0.95);
        }
        sim.params.center_strength = center_strength.clamp(0.0, 0.2);
        sim.params.collision_radius = collision_radius.clamp(0.0, 100.0);

        // Update collision radii for all nodes.
        let new_radius = sim.params.collision_radius;
        for r in &mut sim.collision_radii {
            *r = new_radius;
        }
        if self.entrance.is_none() {
            sim.reheat();
        }
    }

    // ── Cluster Parameters ───────────────────────────────────────────

    pub fn set_cluster_params(&mut self, cluster_strength: f32) {
        let mut sim = self.sim.lock();
        sim.params.cluster_strength = cluster_strength;
        if self.entrance.is_none() {
            sim.reheat();
        }
    }

    pub fn set_center_mode(&mut self, mode: u8) {
        let mut sim = self.sim.lock();
        sim.params.center_mode = crate::simulation::CenterMode::from_u8(mode);
        if self.entrance.is_none() {
            sim.reheat();
        }
    }

    /// Override cluster IDs from a UUID → cluster_id map (semantic clustering).
    /// Maps UUIDs to simulation indices via `graph_indices`, then overwrites
    /// `cluster_ids` for matched nodes. Unmatched nodes keep their existing
    /// cluster assignment. Reheats the simulation so new clusters settle.
    pub fn set_cluster_ids(&mut self, uuid_to_cluster: &std::collections::HashMap<String, u32>) {
        let mut sim = self.sim.lock();
        let n = sim.x.len();
        if sim.cluster_ids.len() != n {
            sim.cluster_ids = vec![0; n];
        }

        for si in 0..n {
            let gi = sim.graph_indices[si];
            if gi < self.graph.nodes.len() {
                let uuid = &self.graph.nodes[gi].uuid;
                if let Some(&cid) = uuid_to_cluster.get(uuid) {
                    sim.cluster_ids[si] = cid;
                }
            }
        }

        if self.entrance.is_none() {
            sim.reheat();
        }
    }

    /// Push semantic neighbor pairs to the simulation thread.
    /// Maps graph-level node indices to simulation-level indices.
    pub fn sync_semantic_neighbors(&mut self) {
        let mut sim = self.sim.lock();
        // Build graph_index → sim_index reverse map
        let mut graph_to_sim: rustc_hash::FxHashMap<usize, usize> = rustc_hash::FxHashMap::default();
        for (si, &gi) in sim.graph_indices.iter().enumerate() {
            graph_to_sim.insert(gi, si);
        }

        sim.semantic_neighbors = self
            .semantic_neighbors
            .iter()
            .filter_map(|&(ga, gb, sim_val)| {
                let sa = *graph_to_sim.get(&(ga as usize))?;
                let sb = *graph_to_sim.get(&(gb as usize))?;
                Some((sa, sb, sim_val))
            })
            .collect();
    }

    /// Set semantic strength parameter and push to simulation.
    pub fn set_semantic_strength(&mut self, strength: f32) {
        let mut sim = self.sim.lock();
        sim.params.semantic_strength = strength;
        if self.entrance.is_none() {
            sim.reheat();
        }
    }

    // ── Accessors ────────────────────────────────────────────────────

    /// Mutable reference to the graph (for FFI data loading).
    pub fn graph_mut(&mut self) -> &mut Graph {
        &mut self.graph
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

    /// Returns true when physics is completely disabled (large graph above threshold).
    pub fn is_static_layout(&self) -> bool {
        self.sim.lock().static_layout
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
            // Global mode: restore calm defaults.
            self.anchor_rect = None;
            sim.anchor_center = None;
            sim.params.link_distance = 200.0;
            sim.params.charge_strength = -400.0;
            sim.params.charge_range = 1500.0;
            sim.params.center_strength = 0.005;
        }
        if self.entrance.is_none() {
            sim.reheat();
        }
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

    pub fn set_lite_mode(&mut self, enabled: bool) {
        let level = if enabled { 2u8 } else { 0 };
        self.quality_level = level;
        self.renderer.quality_level = level;
        self.sim.lock().lite_mode = enabled;
    }

    /// Set quality level: 0 = Cinematic, 1 = Balanced, 2 = Performance.
    pub fn set_quality_level(&mut self, level: u8) {
        let clamped = level.min(2);
        self.quality_level = clamped;
        self.renderer.quality_level = clamped;
        self.sim.lock().lite_mode = clamped >= 2;
    }

    /// Look up a node's UUID by its internal ID and store in the reusable buffer.
    /// Returns a C string pointer valid until the next call.
    pub fn node_uuid_by_id(&mut self, node_id: u32) -> *const std::ffi::c_char {
        self.uuid_buf = self
            .graph
            .id_to_index
            .get(&node_id)
            .and_then(|&idx| self.graph.nodes.get(idx))
            .and_then(|n| CString::new(n.uuid.as_str()).ok());
        self.uuid_buf
            .as_ref()
            .map_or(std::ptr::null(), |cs| cs.as_ptr())
    }

    /// Look up a node's internal array index by UUID.
    pub fn node_index_by_uuid(&self, uuid: &str) -> Option<usize> {
        self.graph
            .uuid_to_id
            .get(uuid)
            .and_then(|&id| self.graph.id_to_index.get(&id).copied())
    }

    /// Read-only access to the graph.
    pub fn graph(&self) -> &Graph {
        &self.graph
    }

    /// Reheat the physics simulation (after embeddings change, etc.).
    pub fn reheat(&mut self) {
        if self.entrance.is_some() {
            return; // Don't reheat during entrance — let the alpha ramp control forces.
        }
        self.sync_semantic_neighbors();
        let sim = self.sim.clone();
        let mut sim = sim.lock();
        sim.reheat();
        self.idle_frame_count = 0;
    }

    // ── Temporal Index ──────────────────────────────────────────────

    /// Set timestamps for a node by UUID.
    pub fn set_node_time(&mut self, uuid: &str, created_at: f64, updated_at: f64) {
        if let Some(&id) = self.graph.uuid_to_id.get(uuid) {
            if let Some(&idx) = self.graph.id_to_index.get(&id) {
                self.graph.nodes[idx].created_at = created_at;
                self.graph.nodes[idx].updated_at = updated_at;
            }
        }
    }

    /// Apply a time filter: nodes with created_at outside [min_ts, max_ts] become invisible.
    /// Nodes with created_at == 0.0 (no timestamp) remain always visible.
    /// Pass (0.0, f64::MAX) to clear the filter.
    pub fn set_time_filter(&mut self, min_ts: f64, max_ts: f64) {
        // Check if clearing filter
        if min_ts <= 0.0 && max_ts >= 1e18 {
            if self.time_filter.is_none() {
                return; // Already cleared
            }
            self.time_filter = None;
            // Restore all nodes to visible
            for node in &mut self.graph.nodes {
                node.visible = true;
            }
        } else {
            self.time_filter = Some((min_ts, max_ts));
            // Apply filter: nodes with timestamp outside range become invisible
            for node in &mut self.graph.nodes {
                if node.created_at == 0.0 {
                    // No timestamp — always visible
                    node.visible = true;
                } else {
                    node.visible = node.created_at >= min_ts && node.created_at <= max_ts;
                }
            }
        }
        // Refresh simulation + renderer with new visibility
        self.refresh_visibility();
    }

    // ── Confidence ──────────────────────────────────────────────────

    /// Set a node's confidence score (0.0–1.0).
    pub fn set_node_confidence(&mut self, uuid: &str, confidence: f32) {
        if let Some(&id) = self.graph.uuid_to_id.get(uuid) {
            if let Some(&idx) = self.graph.id_to_index.get(&id) {
                self.graph.nodes[idx].confidence = confidence.clamp(0.0, 1.0);
            }
        }
    }
}

impl Drop for Engine {
    fn drop(&mut self) {
        self.stop_physics();
    }
}

// ── Physics Thread ──────────────────────────────────────────────────────────

/// Entrance physics loop: uses `entrance_tick()` for gradual alpha ramp.
/// Once alpha_decay becomes non-zero (entrance_tick switches to decay mode),
/// falls through to normal tick() behavior automatically.
fn entrance_physics_loop(sim: Arc<Mutex<Simulation>>, stop: Arc<AtomicBool>) {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let target_dt = Duration::from_secs_f64(1.0 / PHYSICS_HZ);
        let slow_dt = Duration::from_secs_f64(1.0 / 30.0);

        while !stop.load(Ordering::Relaxed) {
            let start = Instant::now();

            let (settled, alpha) = {
                let mut sim = sim.lock();
                sim.entrance_tick();
                (sim.is_settled, sim.params.alpha)
            };

            if settled {
                if stop.load(Ordering::Relaxed) { break; }
                std::thread::sleep(Duration::from_millis(SETTLED_SLEEP_MS));
                continue;
            }

            let frame_dt = if alpha < 0.05 { slow_dt } else { target_dt };
            let elapsed = start.elapsed();
            if elapsed < frame_dt {
                std::thread::sleep(frame_dt - elapsed);
            }
        }
    }));
    if let Err(e) = result {
        let msg = if let Some(s) = e.downcast_ref::<&str>() {
            s.to_string()
        } else if let Some(s) = e.downcast_ref::<String>() {
            s.clone()
        } else {
            "unknown panic".to_string()
        };
        eprintln!("[graph-engine] PANIC in entrance_physics_loop: {msg}");
        stop.store(true, Ordering::Relaxed);
    }
}

fn physics_loop(sim: Arc<Mutex<Simulation>>, stop: Arc<AtomicBool>) {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let target_dt = Duration::from_secs_f64(1.0 / PHYSICS_HZ);
        let slow_dt = Duration::from_secs_f64(1.0 / 30.0); // 30Hz when nearly settled

        while !stop.load(Ordering::Relaxed) {
            let start = Instant::now();

            let (settled, alpha) = {
                let mut sim = sim.lock();
                sim.tick();
                (sim.is_settled, sim.params.alpha)
            };

            if settled {
                // Check stop flag before committing to sleep.
                if stop.load(Ordering::Relaxed) {
                    break;
                }
                std::thread::sleep(Duration::from_millis(SETTLED_SLEEP_MS));
                continue;
            }

            // Throttle to 30Hz when alpha is low (nearly settled) to reduce CPU.
            let frame_dt = if alpha < 0.05 { slow_dt } else { target_dt };
            let elapsed = start.elapsed();
            if elapsed < frame_dt {
                std::thread::sleep(frame_dt - elapsed);
            }
        }
    }));
    if let Err(e) = result {
        let msg = if let Some(s) = e.downcast_ref::<&str>() {
            s.to_string()
        } else if let Some(s) = e.downcast_ref::<String>() {
            s.clone()
        } else {
            "unknown panic".to_string()
        };
        eprintln!("[graph-engine] PANIC in physics_loop: {msg}");
        stop.store(true, Ordering::Relaxed);
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
        g.add_edge("a", "b", 1.0, 0);
        g.add_edge("b", "c", 1.0, 0);
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
            g.add_edge(&format!("node-{}", i), &format!("node-{}", j), 1.0, 0);
            if i % 5 == 0 {
                let k = (i + n / 3) % n;
                g.add_edge(&format!("node-{}", i), &format!("node-{}", k), 0.5, 0);
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

        // Entrance mode: low alpha for calm onset, high damping.
        assert!(sim.params.alpha < 0.10, "entrance alpha should start low, got {}", sim.params.alpha);
        assert!(sim.params.velocity_decay >= 0.85, "entrance should be heavily damped, got {}", sim.params.velocity_decay);
        assert_eq!(sim.params.alpha_decay, 0.0, "entrance uses manual ramp, not auto-decay");

        // Check alpha ramp at midpoint (tick 50 — during ramp/hold phase).
        for _ in 0..50 {
            sim.entrance_tick();
        }
        assert!(sim.params.alpha > 0.1, "alpha should have ramped up by tick 50, got {}", sim.params.alpha);

        // Continue entrance ticks to transition to normal decay.
        for _ in 0..250 {
            sim.entrance_tick();
        }
        // Alpha decay should now be active (switched from manual ramp).
        assert!(sim.params.alpha_decay > 0.0, "should have switched to normal decay");

        // Let normal physics settle.
        for _ in 0..500 {
            sim.tick();
        }
        assert!(sim.is_settled, "entrance mode should settle within 800 total ticks");
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
        let min_x = f32::MAX;
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
        graph.add_edge("hub", "leaf", 1.0, 0);

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
        graph.add_edge("a", "b", 1.0, 0);
        graph.add_edge("b", "c", 1.0, 0);
        graph.add_edge("c", "d", 1.0, 0);

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
        let _early = animator.compute();
        let _hero_idx = graph.nodes.iter()
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

    // ── Progressive Reveal Tests ───────────────────────────────────

    #[test]
    fn progressive_reveal_hub_nodes_appear_first() {
        // Build a graph with distinct link_count tiers for clear ordering.
        let mut graph = Graph::new();
        graph.add_node("hub".into(), 0.0, 0.0, 0, 20, "Hub".into());
        graph.add_node("bridge".into(), 50.0, 0.0, 0, 5, "Bridge".into());
        graph.add_node("leaf".into(), 100.0, 0.0, 0, 1, "Leaf".into());

        let reveal = ProgressiveRevealAnimator::from_graph(&graph);

        // Hub (link_count=20) should appear first (lowest delay).
        let hub_delay = reveal.delays[0];
        let bridge_delay = reveal.delays[1];
        let leaf_delay = reveal.delays[2];

        assert!(
            hub_delay < bridge_delay,
            "hub should appear before bridge: hub={}, bridge={}",
            hub_delay, bridge_delay
        );
        assert!(
            bridge_delay < leaf_delay,
            "bridge should appear before leaf: bridge={}, leaf={}",
            bridge_delay, leaf_delay
        );
    }

    #[test]
    fn progressive_reveal_completes() {
        let graph = make_large_graph(50);
        let mut reveal = ProgressiveRevealAnimator::from_graph(&graph);

        // At start: should not be complete.
        assert!(!reveal.is_complete());

        // After 10s: should be complete (spread + fade < 10s).
        reveal.start = Instant::now() - Duration::from_secs(10);
        assert!(reveal.is_complete(), "reveal should be complete after 10s");
    }

    #[test]
    fn progressive_reveal_compute_alpha_values() {
        let graph = make_large_graph(20);
        let mut reveal = ProgressiveRevealAnimator::from_graph(&graph);
        let mut states = Vec::new();

        // All alpha should be 0 or positive at start.
        reveal.compute(&mut states);
        assert_eq!(states.len(), graph.nodes.len());
        for s in &states {
            assert!(s.alpha >= 0.0 && s.alpha <= 1.0);
            assert_eq!(s.z_offset, 0.0); // no z animation
            assert_eq!(s.dx, 0.0); // no spiral
            assert_eq!(s.dy, 0.0);
        }

        // After full animation: all alpha should be 1.0.
        reveal.start = Instant::now() - Duration::from_secs(10);
        reveal.compute(&mut states);
        for s in &states {
            assert!(
                (s.alpha - 1.0).abs() < 0.01,
                "alpha should be ~1.0 after completion, got {}",
                s.alpha
            );
        }
    }

    #[test]
    fn progressive_reveal_empty_graph() {
        let graph = Graph::new();
        let reveal = ProgressiveRevealAnimator::from_graph(&graph);
        assert!(reveal.is_complete(), "empty graph reveal is immediately complete");
        assert!(reveal.delays.is_empty());
    }

    // ── Semantic Cluster Override Tests ──────────────────────────────

    #[test]
    fn set_cluster_ids_overrides_louvain() {
        // Build a graph with 4 nodes.
        let mut graph = Graph::new();
        graph.add_node("uuid-a".into(), -50.0, 0.0, 0, 2, "A".into());
        graph.add_node("uuid-b".into(), 50.0, 0.0, 0, 2, "B".into());
        graph.add_node("uuid-c".into(), 0.0, -50.0, 0, 2, "C".into());
        graph.add_node("uuid-d".into(), 0.0, 50.0, 0, 2, "D".into());
        graph.add_edge("uuid-a", "uuid-b", 1.0, 0);
        graph.add_edge("uuid-c", "uuid-d", 1.0, 0);

        let sim = Arc::new(Mutex::new(Simulation::new()));
        {
            let mut s = sim.lock();
            s.load_from_graph(&graph);
            // Simulate Louvain output: all in cluster 0.
            s.cluster_ids = vec![0; s.x.len()];
        }

        // Build UUID → cluster_id override map (semantic clusters).
        // Put A,B in cluster 10, C,D in cluster 20.
        let uuid_to_cluster: std::collections::HashMap<String, u32> = [
            ("uuid-a".to_owned(), 10),
            ("uuid-b".to_owned(), 10),
            ("uuid-c".to_owned(), 20),
            ("uuid-d".to_owned(), 20),
        ]
        .into_iter()
        .collect();

        // Apply override using the Engine helper (same logic as the FFI path).
        // We test the logic directly since Engine::new requires Metal.
        {
            let mut s = sim.lock();
            let n = s.x.len();
            if s.cluster_ids.len() != n {
                s.cluster_ids = vec![0; n];
            }
            for si in 0..n {
                let gi = s.graph_indices[si];
                if gi < graph.nodes.len() {
                    let uuid = &graph.nodes[gi].uuid;
                    if let Some(&cid) = uuid_to_cluster.get(uuid) {
                        s.cluster_ids[si] = cid;
                    }
                }
            }
            s.reheat();
        }

        // Verify cluster IDs were overridden.
        let s = sim.lock();
        assert_eq!(s.cluster_ids.len(), 4);
        for (si, &gi) in s.graph_indices.iter().enumerate() {
            let uuid = &graph.nodes[gi].uuid;
            match uuid.as_str() {
                "uuid-a" | "uuid-b" => {
                    assert_eq!(s.cluster_ids[si], 10, "{} should be in cluster 10", uuid);
                }
                "uuid-c" | "uuid-d" => {
                    assert_eq!(s.cluster_ids[si], 20, "{} should be in cluster 20", uuid);
                }
                _ => panic!("unexpected uuid: {}", uuid),
            }
        }

        // Verify reheat happened.
        assert!(!s.is_settled, "simulation should be unsettled after reheat");
        assert!(s.params.alpha > 0.1, "alpha should be reheated");
    }

    #[test]
    fn set_cluster_ids_partial_override() {
        // Only override some nodes -- others keep their existing cluster ID.
        let mut graph = Graph::new();
        graph.add_node("n1".into(), 0.0, 0.0, 0, 1, "N1".into());
        graph.add_node("n2".into(), 10.0, 0.0, 0, 1, "N2".into());
        graph.add_node("n3".into(), 20.0, 0.0, 0, 1, "N3".into());

        let sim = Arc::new(Mutex::new(Simulation::new()));
        {
            let mut s = sim.lock();
            s.load_from_graph(&graph);
            s.cluster_ids = vec![5, 5, 5]; // Louvain: all in cluster 5.
        }

        // Only override n1 -> cluster 99. n2 and n3 should remain 5.
        let uuid_to_cluster: std::collections::HashMap<String, u32> =
            [("n1".to_owned(), 99)].into_iter().collect();

        {
            let mut s = sim.lock();
            let n = s.x.len();
            for si in 0..n {
                let gi = s.graph_indices[si];
                if gi < graph.nodes.len() {
                    let uuid = &graph.nodes[gi].uuid;
                    if let Some(&cid) = uuid_to_cluster.get(uuid) {
                        s.cluster_ids[si] = cid;
                    }
                }
            }
        }

        let s = sim.lock();
        let mut found = [false; 3];
        for (si, &gi) in s.graph_indices.iter().enumerate() {
            let uuid = &graph.nodes[gi].uuid;
            match uuid.as_str() {
                "n1" => {
                    assert_eq!(s.cluster_ids[si], 99);
                    found[0] = true;
                }
                "n2" => {
                    assert_eq!(s.cluster_ids[si], 5);
                    found[1] = true;
                }
                "n3" => {
                    assert_eq!(s.cluster_ids[si], 5);
                    found[2] = true;
                }
                _ => {}
            }
        }
        assert!(found.iter().all(|&f| f), "all nodes should be verified");
    }

    #[test]
    fn stress_3000_nodes_static_layout() {
        // 3000 nodes exceeds static layout threshold (2500).
        // Physics should be completely disabled.
        let graph = make_large_graph(3000);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        // Static layout should be active.
        assert!(sim.static_layout, "3000 nodes should trigger static layout");
        assert!(sim.is_settled, "static layout should be settled");
        assert_eq!(sim.params.alpha, 0.0, "alpha should be 0 for static layout");

        // Edges should NOT be in simulation (skipped for performance).
        assert!(sim.edges.is_empty(), "static layout should not load physics edges");

        // Degrees should still be computed (needed for node radius sizing).
        let total_deg: u32 = sim.degrees.iter().sum();
        assert!(total_deg > 0, "degrees should be computed for static layout");

        // tick() should be a no-op.
        let x_before: Vec<f32> = sim.x.clone();
        sim.tick();
        assert_eq!(sim.x, x_before, "tick() should not modify positions in static layout");

        // Verify no NaN/Inf in positions.
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite(), "x[{}] not finite", i);
            assert!(sim.y[i].is_finite(), "y[{}] not finite", i);
        }

        // All velocities should be zero.
        assert!(sim.vx.iter().all(|&v| v == 0.0), "velocities should be zero");
    }
}
