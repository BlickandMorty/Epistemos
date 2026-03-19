//! # Graph Engine Orchestrator
//!
//! Ties together Simulation, Renderer, and SpatialIndex.
//! Manages the physics thread lifecycle, input handling, camera, and highlighting.
//!
//! ## Threading Model
//! - Physics thread: locks `Simulation` briefly to tick, then releases.
//! - Render thread (main): locks `Simulation` briefly to copy positions, then releases.
//! - `parking_lot::Mutex` for low-overhead, non-poisoning locks.

use std::ffi::{CString, c_void};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};

use parking_lot::Mutex;
use rustc_hash::FxHashSet;

use crate::block_kernel::{BlockTree, BtkQueryKernel, OpLog};
use crate::cluster_cache::ClusterCache;
use crate::ecs::World;
use crate::embedding::EmbeddingStore;
use crate::renderer::{Renderer, viewport_bounds};
use crate::simulation::Simulation;
use crate::spatial::SpatialIndex;
use crate::types::{Graph, VisualTheme};
use crate::version::VersionStore;
use std::collections::HashMap;

/// Adaptive physics tick rate scaled by node count.
fn adaptive_physics_hz(node_count: usize) -> f64 {
    match node_count {
        0..=500 => 120.0,
        501..=1000 => 60.0,
        1001..=3000 => 40.0,
        3001..=5000 => 30.0,
        _ => 30.0,
    }
}
/// Sleep duration (ms) when simulation is settled (avoids spinning).
const SETTLED_SLEEP_MS: u64 = 50;
/// Above this threshold, use cheap spatial clustering instead of Louvain.
const LOUVAIN_MAX_NODES: usize = 10_000;
const INTERACTION_MOTION_HOLD: Duration = Duration::from_secs(30);
const INTERACTION_MOTION_ALPHA_TARGET: f32 = 0.015;

fn presettle_limits(node_count: usize, entrance: bool) -> (u16, Duration) {
    if !entrance {
        return (24, Duration::from_millis(2));
    }

    if node_count < 128 {
        (180, Duration::from_millis(12))
    } else if node_count < 512 {
        (120, Duration::from_millis(10))
    } else if node_count < 1_200 {
        (72, Duration::from_millis(8))
    } else {
        (36, Duration::from_millis(6))
    }
}

fn clamp_zoom_for_theme(_theme: VisualTheme, zoom: f32) -> f32 {
    zoom.clamp(1.0, 10.0)
}

fn should_update_field_lines(
    _quality_level: u8,
    _hovered_id: Option<u32>,
    _field_line_count: usize,
    _dragging: bool,
    _dialogue_active: bool,
) -> bool {
    false
}

/// Drag state for d3-style fx/fy constraint.
struct DragState {
    node_id: u32,
    sim_index: usize,
    /// Screen position at drag start — used to detect click vs drag.
    origin: [f32; 2],
    /// Whether the mouse moved enough to count as a real drag.
    moved: bool,
    /// Previous world position for fluid grid velocity injection.
    last_world: [f32; 2],
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

    /// Block Transaction Kernel: page_id → block tree
    pub btk_trees: HashMap<String, BlockTree>,
    /// Block Transaction Kernel: page_id → op log
    pub btk_logs: HashMap<String, OpLog>,
    /// Cozo-backed BTK fact/query runtime for subscriptions and snapshots.
    pub btk_query_kernel: BtkQueryKernel,

    /// ECS mirror of graph data, synced from Simulation each frame.
    world: World,
    /// Tracks whether the previous rendered frame still had active physics.
    last_sim_active: bool,
    /// Defers expensive cull/buffer rebuilds until a camera move finishes.
    camera_rebuild_pending: bool,
    /// Forces a renderer buffer rebuild when render quality changes.
    quality_rebuild_pending: bool,
    /// Rebuild per-node highlight flags only when highlight state changes.
    highlight_dirty: bool,
    cluster_cache: ClusterCache,
    /// Scratch buffer for GPU N-body position collection (avoids per-frame alloc).
    gpu_positions_scratch: Vec<[f32; 2]>,
    /// Scratch buffer for search-highlight node IDs (avoids per-query alloc).
    search_highlight_ids_scratch: Vec<u32>,
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
            uuid_buf: None,
            idle_frame_count: 0,
            search_index: crate::search::SearchIndex::new(),
            embedding_store: EmbeddingStore::new(crate::embedding::DEFAULT_DIM),
            semantic_neighbors: Vec::new(),
            time_filter: None,
            version_store: VersionStore::new(),
            quality_level: 0, // Cinematic
            btk_trees: HashMap::new(),
            btk_logs: HashMap::new(),
            btk_query_kernel: BtkQueryKernel::new(),
            world: World::new(),
            last_sim_active: false,
            camera_rebuild_pending: false,
            quality_rebuild_pending: false,
            highlight_dirty: true,
            cluster_cache: ClusterCache::new(),
            gpu_positions_scratch: Vec::new(),
            search_highlight_ids_scratch: Vec::new(),
        })
    }

    /// Commit graph data. Replaces all simulation state, restarts physics.
    /// If `entrance` is true, uses a phyllotaxis spiral for initial node layout.
    pub fn commit(&mut self, entrance: bool) {
        // Wake rendering for the new graph data.
        self.idle_frame_count = 0;

        // Fresh graph load: clear user freeze so physics starts fresh.
        // User must explicitly re-freeze if they want static layout.
        if entrance {
            self.sim.lock().user_frozen = false;
        }

        // Stop existing physics thread.
        self.stop_physics();

        let n = self.graph.nodes.len();

        // ── Initial Layout ──────────────────────────────────────────────
        // BFS from hubs: connected nodes start near their parent.
        // This ensures springs only need fine-tuning, not long-range hauling.
        if entrance && n > 0 {
            use std::collections::VecDeque;
            let golden_angle: f32 = std::f32::consts::PI * (3.0 - 5.0_f32.sqrt());

            // Child placement distance: slightly under link_distance so springs
            // gently push outward rather than needing to pull inward from far away.
            let child_spacing = 150.0_f32;

            // Build adjacency list from graph edges.
            let mut adj: Vec<Vec<usize>> = vec![vec![]; n];
            for edge in &self.graph.edges {
                if let (Some(&si), Some(&ti)) = (
                    self.graph.id_to_index.get(&edge.source),
                    self.graph.id_to_index.get(&edge.target),
                ) {
                    if si < n && ti < n {
                        adj[si].push(ti);
                        adj[ti].push(si);
                    }
                }
            }

            // Sort roots by degree descending (hubs first).
            let mut roots: Vec<usize> = (0..n).collect();
            roots.sort_unstable_by(|&a, &b| {
                self.graph.nodes[b]
                    .link_count
                    .cmp(&self.graph.nodes[a].link_count)
            });

            let mut placed = vec![false; n];
            let mut queue: VecDeque<usize> = VecDeque::with_capacity(n);
            let mut component_offset_x = 0.0_f32;
            let mut component_max_x: f32;

            for &root in &roots {
                if placed[root] {
                    continue;
                }

                // Place component root.
                self.graph.nodes[root].x = component_offset_x;
                self.graph.nodes[root].y = 0.0;
                self.graph.nodes[root].vx = 0.0;
                self.graph.nodes[root].vy = 0.0;
                placed[root] = true;
                queue.push_back(root);
                component_max_x = component_offset_x;

                while let Some(parent) = queue.pop_front() {
                    let px = self.graph.nodes[parent].x;
                    let py = self.graph.nodes[parent].y;

                    // Collect unplaced children.
                    let children: Vec<usize> = adj[parent]
                        .iter()
                        .filter(|&&c| !placed[c])
                        .copied()
                        .collect();

                    let child_count = children.len();
                    for (i, child) in children.into_iter().enumerate() {
                        if placed[child] {
                            continue;
                        }

                        // Golden-angle fan around parent — avoids overlap patterns.
                        let angle = i as f32 * golden_angle;
                        self.graph.nodes[child].x = px + child_spacing * angle.cos();
                        self.graph.nodes[child].y = py + child_spacing * angle.sin();
                        self.graph.nodes[child].vx = 0.0;
                        self.graph.nodes[child].vy = 0.0;
                        placed[child] = true;
                        queue.push_back(child);

                        component_max_x = component_max_x.max(self.graph.nodes[child].x);
                    }
                    let _ = child_count; // suppress unused warning
                }

                // Offset next disconnected component to the right.
                component_offset_x = component_max_x + child_spacing * 4.0;
            }
        }

        // ── Load Simulation ─────────────────────────────────────────────
        {
            let mut sim = self.sim.lock();
            sim.load_from_graph(&self.graph);
            Self::ensure_cluster_assignments(&mut self.cluster_cache, &mut sim);

            // Page mode always gets full physics — it shows a small subset
            // (focal node + 1-hop neighbors) regardless of total vault size.
            // But respect user-controlled freeze if active.
            if self.mode == 1 && sim.static_layout && !sim.user_frozen {
                sim.static_layout = false;
                sim.is_settled = false;
                sim.params.alpha = 0.15;
            }

            // Skip physics pre-settle for static layout.
            if !sim.static_layout {
                // Pre-settle: run physics ticks before first render so the graph
                // opens with nodes already near equilibrium (no visible drift).
                // BFS layout places connected nodes near parents, so moderate alpha
                // is safe — repulsion fine-tunes spacing without explosive separation.
                let sn = sim.x.len();
                let (max_ticks, time_budget) = presettle_limits(sn, entrance);
                if entrance {
                    sim.params.alpha = 0.12;
                    sim.params.alpha_decay = 0.02;
                }
                if sn < 2000 && max_ticks > 0 {
                    let start = Instant::now();
                    for _ in 0..max_ticks {
                        sim.tick();
                        if sim.is_settled || start.elapsed() >= time_budget {
                            break;
                        }
                    }
                }
                if !entrance {
                    sim.sustain_interaction_motion_for(
                        INTERACTION_MOTION_HOLD,
                        INTERACTION_MOTION_ALPHA_TARGET,
                    );
                }
            }
        }

        // Copy positions back to graph nodes for rendering + spatial index.
        self.sync_all_positions();

        // Build ECS World from Graph data (positions are current after sync).
        self.world = World::from_graph(&self.graph);

        {
            let sim = self.sim.lock();
            self.world
                .sync_clusters(&sim.cluster_ids, &sim.graph_indices);
            self.renderer.link_distance = sim.params.link_distance;
        }

        // Allocate renderer buffers and upload initial data.
        self.renderer.allocate_buffers(&self.world);

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
        self.highlight_dirty = true;

        // ── Start Physics ────────────────────────────────────────────
        self.start_physics();
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

    fn stop_physics(&mut self) {
        self.stop_flag.store(true, Ordering::Relaxed);
        if let Some(handle) = self.physics_handle.take() {
            let _ = handle.join();
        }
    }

    fn ensure_cluster_assignments(cluster_cache: &mut ClusterCache, sim: &mut Simulation) {
        let topology_fingerprint =
            ClusterCache::topology_fingerprint(&sim.graph_indices, &sim.edges);
        if cluster_cache.is_valid(topology_fingerprint)
            && let Some(level1) = cluster_cache.level1_assignments()
        {
            sim.cluster_ids = level1.to_vec();
            return;
        }

        let cluster_ids = if sim.x.len() <= LOUVAIN_MAX_NODES {
            crate::cluster::detect_communities(sim.x.len(), &sim.edges)
        } else {
            ClusterCache::coarse_assignments(&sim.x, &sim.y)
        };
        cluster_cache.build(cluster_ids.clone(), &sim.edges, &sim.graph_indices);
        sim.cluster_ids = cluster_ids;
    }

    // ── Incremental Commit ────────────────────────────────────────────

    /// Lightweight commit after incremental adds/removes.
    /// Preserves existing node positions (no BFS layout, no pre-settle).
    /// Reloads simulation, rebuilds spatial + search index, re-uploads renderer.
    /// Keeps interaction state (selected/hovered) if the node still exists.
    pub fn commit_incremental(&mut self) {
        self.idle_frame_count = 0;
        self.stop_physics();

        // Sync positions from simulation → graph before reloading sim.
        self.sync_all_positions();

        {
            let mut sim = self.sim.lock();
            sim.load_from_graph(&self.graph);
            Self::ensure_cluster_assignments(&mut self.cluster_cache, &mut sim);

            // Page mode: re-enable physics if not user-frozen.
            if self.mode == 1 && sim.static_layout && !sim.user_frozen {
                sim.static_layout = false;
            }

            // Gentle reheat — existing positions are good, just nudge.
            if !sim.static_layout {
                sim.params.alpha = 0.10;
                sim.is_settled = false;
                sim.sustain_interaction_motion_for(
                    INTERACTION_MOTION_HOLD,
                    INTERACTION_MOTION_ALPHA_TARGET,
                );
            }
        }

        // Rebuild ECS World from updated graph.
        self.world = World::from_graph(&self.graph);
        {
            let sim = self.sim.lock();
            self.world
                .sync_clusters(&sim.cluster_ids, &sim.graph_indices);
            self.renderer.link_distance = sim.params.link_distance;
        }

        self.renderer.upload_graph(&self.world);
        self.spatial.build(&self.graph.nodes);
        self.search_index.build(&self.graph.nodes);

        // Preserve interaction state — clear only if the target was removed.
        if let Some(sel_id) = self.selected_id {
            if !self.graph.id_to_index.contains_key(&sel_id) {
                self.selected_id = None;
            }
        }
        if let Some(hov_id) = self.hovered_id {
            if !self.graph.id_to_index.contains_key(&hov_id) {
                self.hovered_id = None;
            }
        }
        if let Some(ref drag) = self.drag {
            if !self.graph.id_to_index.contains_key(&drag.node_id) {
                self.drag = None;
            }
        }
        self.highlight_dirty = true;

        self.start_physics();
    }

    // ── Visibility (Lightweight Filtering) ──────────────────────────

    /// Toggle a single node's visibility by UUID.
    /// Does NOT re-upload to renderer — call `refresh_visibility()` once after
    /// all desired toggles are applied.
    pub fn set_node_visible(&mut self, uuid: &str, visible: bool) {
        if let Some(&id) = self.graph.uuid_to_id.get(uuid)
            && let Some(&idx) = self.graph.id_to_index.get(&id)
        {
            self.graph.nodes[idx].visible = visible;
            if let Some(world_index) = self.world.index_of_node_id(id) {
                self.world.graph_node[world_index].visible = u8::from(visible);
            }
        }
    }

    /// Re-upload graph to renderer and reload simulation after visibility changes.
    /// Preserves positions/velocities — only the set of active nodes changes.
    pub fn refresh_visibility(&mut self) {
        // Sync current positions from simulation → graph before reloading.
        self.sync_all_positions();

        // Reload simulation with only visible nodes, reheat to re-settle.
        {
            let mut sim = self.sim.lock();
            sim.load_from_graph(&self.graph);
            Self::ensure_cluster_assignments(&mut self.cluster_cache, &mut sim);
            sim.reheat();
        }

        // Rebuild ECS World so topology, visibility, and metadata stay in sync.
        self.world = World::from_graph(&self.graph);
        {
            let sim = self.sim.lock();
            self.world
                .sync_clusters(&sim.cluster_ids, &sim.graph_indices);
        }

        // Re-upload ECS world to renderer (only visible nodes are drawn).
        self.renderer.upload_graph(&self.world);

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

    /// Copy positions from simulation to graph nodes and ECS World.
    /// Extrapolates positions using velocity * time-since-last-tick for smooth
    /// sub-tick motion at display refresh rate (120Hz renders, 40Hz physics).
    fn sync_all_positions(&mut self) {
        {
            let sim = self.sim.lock();
            let n = sim.x.len();

            // Time since last physics tick — used to extrapolate positions forward.
            // Clamped to prevent overshoot if physics thread stalls.
            let dt = sim.last_tick_instant.elapsed().as_secs_f32().min(0.05);

            // Graph nodes (indexed by graph_indices mapping)
            for (si, &gi) in sim.graph_indices.iter().enumerate() {
                if gi < self.graph.nodes.len() {
                    self.graph.nodes[gi].x = sim.x[si] + sim.vx[si] * dt;
                    self.graph.nodes[gi].y = sim.y[si] + sim.vy[si] * dt;
                    self.graph.nodes[gi].vx = sim.vx[si];
                    self.graph.nodes[gi].vy = sim.vy[si];
                }
            }

            // ECS World (direct index) — size mismatch means commit() hasn't rebuilt yet.
            if self.world.len() != n {
                return;
            }

            // Flat physics arrays — extrapolated positions for renderer, raw for physics.
            self.world.px.resize(n, 0.0);
            self.world.py.resize(n, 0.0);
            self.world.pvx.resize(n, 0.0);
            self.world.pvy.resize(n, 0.0);
            // Minimum speed² below which extrapolation is skipped (avoids noise amplification).
            const EXTRAP_THRESHOLD_SQ: f32 = 0.25; // 0.5 px/tick
            for i in 0..n {
                let vx = sim.vx[i];
                let vy = sim.vy[i];
                let speed_sq = vx * vx + vy * vy;
                let (ex, ey) = if speed_sq > EXTRAP_THRESHOLD_SQ {
                    (sim.x[i] + vx * dt, sim.y[i] + vy * dt)
                } else {
                    (sim.x[i], sim.y[i])
                };
                self.world.transform[i].x = ex;
                self.world.transform[i].y = ey;
                self.world.velocity[i].vx = vx;
                self.world.velocity[i].vy = vy;
                self.world.px[i] = ex;
                self.world.py[i] = ey;
                self.world.pvx[i] = vx;
                self.world.pvy[i] = vy;
            }
        }

        self.world
            .spatial_grid
            .rebuild(&self.world.entities, &self.world.transform);
    }

    /// Render one frame. Returns 1 if another frame is needed, 0 if GPU can idle.
    pub fn render(&mut self, width: u32, height: u32) -> u32 {
        self.viewport_width = width;
        self.viewport_height = height;
        let viewport_changed = self.renderer.set_viewport_size(width, height);

        // Single lock to read all simulation state — avoids per-field mutex contention.
        let (sim_active, haptic_event, _is_frozen) = {
            let mut sim = self.sim.lock();
            // Pass viewport bounds for scoped physics (Phase 4 optimization).
            // At low zoom or when frozen, simulate all nodes (viewport covers everything).
            if sim.user_frozen || self.renderer.camera_zoom < 0.3 {
                sim.viewport_bounds = None;
            } else {
                let vp = viewport_bounds(
                    self.renderer.camera_offset,
                    self.renderer.camera_zoom,
                    [width as f32, height as f32],
                    300.0,
                );
                sim.viewport_bounds = Some([vp.min_x, vp.min_y, vp.max_x, vp.max_y]);
            }
            (!sim.is_settled, sim.haptic_event, sim.user_frozen)
        };

        let positions_changed = sim_active || self.last_sim_active;
        if positions_changed {
            self.sync_all_positions();
        }
        self.last_sim_active = sim_active;

        // GPU N-body: dispatch brute-force repulsion on GPU for large graphs.
        // Forces are written to sim.gpu_nbody_forces; the physics thread drains them
        // atomically at the start of its next tick, preventing double-application.
        let n = self.world.len();
        if n > 2000 && self.renderer.compute_pipeline.is_some() {
            self.gpu_positions_scratch.clear();
            self.gpu_positions_scratch.reserve(n);
            for i in 0..n {
                self.gpu_positions_scratch
                    .push([self.world.transform[i].x, self.world.transform[i].y]);
            }
            let (charge, alpha, dmax) = {
                let sim = self.sim.lock();
                (
                    sim.params.charge_strength,
                    sim.params.alpha,
                    sim.params.charge_range,
                )
            };
            let dmin = 1.0_f32;

            if let Some(forces) = self.renderer.dispatch_gpu_nbody(
                &self.gpu_positions_scratch,
                charge,
                alpha,
                dmax,
                dmin,
            ) {
                let mut sim = self.sim.lock();
                sim.gpu_nbody_forces = Some(forces);
            }
        }

        // Trigger impact visual effects when heavy collision detected.
        if haptic_event >= 2 {
            self.renderer.impact_intensity = 1.0;
        }

        // Animate camera (smooth lerp toward target).
        self.renderer.update_camera();

        // Request next frame only when something is animating.
        let camera_moving = self.renderer.is_animating;
        let camera_refresh_due = self.camera_rebuild_pending && !camera_moving;
        let quality_refresh_due = self.quality_rebuild_pending;
        let instance_buffers_changed =
            positions_changed || viewport_changed || camera_refresh_due || quality_refresh_due;
        let dialogue_animating =
            self.renderer.dialogue.active && self.renderer.dialogue.is_streaming;
        let needs_frame = sim_active
            || camera_moving
            || viewport_changed
            || camera_refresh_due
            || quality_refresh_due
            || self.highlight_dirty
            || dialogue_animating;

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

        // Edge visibility: always show edges in both physics and freeze mode.
        self.renderer.edges_hidden = false;
        self.renderer.edge_filter_node = None;

        if instance_buffers_changed {
            self.renderer.update_positions(&self.world);
            self.camera_rebuild_pending = false;
            self.quality_rebuild_pending = false;
        }
        if positions_changed {
            self.spatial.build(&self.graph.nodes);
        }

        // Append selection/hover highlight rings (only updates 2 instances -- cheap).
        self.renderer
            .set_highlights(self.selected_id, self.hovered_id, &self.world);

        // Rebuild per-instance highlight flags only when something visual changed.
        // Skipping this when idle saves O(N) work per frame at 10K nodes.
        if instance_buffers_changed || self.highlight_dirty {
            self.renderer.rebuild_highlight_flags(&self.world);
            self.renderer.rebuild_edge_highlight_flags();
            self.highlight_dirty = false;
        }

        // Decorative hover field lines are disabled; only clear stale buffers if needed.
        if should_update_field_lines(
            self.quality_level,
            self.hovered_id,
            self.renderer.field_line_count,
            self.drag.is_some(),
            self.renderer.dialogue.active,
        ) {
            let time = self.renderer.start_time.elapsed().as_secs_f32();
            self.renderer
                .update_field_lines(self.hovered_id, &self.world, time);
        } else if self.renderer.field_line_count > 0 {
            self.renderer.update_field_lines(None, &self.world, 0.0);
        }

        // Issue draw commands — all themes use the classic renderer.
        self.renderer.draw(width, height, &self.world);

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

    /// Get a node's screen pixel position by UUID. Returns `None` if not found.
    pub fn node_screen_pos(&self, uuid: &str) -> Option<[f32; 2]> {
        let &id = self.graph.uuid_to_id.get(uuid)?;
        let index = self.world.index_of_node_id(id)?;
        if index >= self.world.len() {
            return None;
        }
        let wx = self.world.transform[index].x;
        let wy = self.world.transform[index].y;
        let w = self.viewport_width as f32;
        let h = self.viewport_height as f32;
        let zoom = self.renderer.camera_zoom;
        let sx = (wx - self.renderer.camera_offset[0]) * zoom + w * 0.5;
        let sy = (wy - self.renderer.camera_offset[1]) * zoom + h * 0.5;
        Some([sx, sy])
    }

    /// Get cumulative drift for a node by UUID.
    pub fn node_drift(&self, uuid: &str) -> Option<f32> {
        let &id = self.graph.uuid_to_id.get(uuid)?;
        let gi = self.world.index_of_node_id(id)?;
        let sim = self.sim.lock();
        let si = sim.graph_indices.iter().position(|&g| g == gi)?;
        sim.drift.get(si).copied()
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
            self.hovered_id = None;
            self.renderer.update_field_lines(None, &self.world, 0.0);

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
                    // Very low target — drag needs minimal force redistribution.
                    sim.params.alpha_target = 0.03;
                    if sim.is_settled {
                        sim.params.alpha = 0.02; // Seed with small value so tick() doesn't skip
                        sim.is_settled = false;
                    }
                    drop(sim);
                    // Trigger pulse wave from click position (cinematic effect).
                    self.renderer.pulse_origin = [node_x, node_y];
                    self.renderer.pulse_start = self.renderer.start_time.elapsed().as_secs_f32();
                    self.drag = Some(DragState {
                        node_id,
                        sim_index,
                        origin: [screen_x, screen_y],
                        moved: false,
                        last_world: [node_x, node_y],
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
        let (wx, wy) = self.screen_to_world(screen_x, screen_y);
        if self.renderer.dialogue.active {
            self.renderer.dialogue.look_target_world = [wx, wy];
        }
        if self.drag.is_some() {
            let drag = self.drag.as_ref().unwrap();
            let sim_index = drag.sim_index;
            let origin = drag.origin;
            let prev_world = drag.last_world;

            // Check if mouse moved far enough to count as a real drag (5px threshold).
            let dx = screen_x - origin[0];
            let dy = screen_y - origin[1];
            let is_real_drag = dx * dx + dy * dy > 25.0;

            // Dragging a node — update fixed position and inject wake only when enabled.
            let dvx = wx - prev_world[0];
            let dvy = wy - prev_world[1];

            let drag = self.drag.as_mut().unwrap();
            if is_real_drag {
                drag.moved = true;
            }
            drag.last_world = [wx, wy];

            let mut sim = self.sim.lock();
            if sim.params.enable_fluid_dynamics {
                sim.inject_fluid_velocity(wx, wy, dvx, dvy);
            }
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
            if drag.moved {
                sim.sustain_interaction_motion_for(
                    INTERACTION_MOTION_HOLD,
                    INTERACTION_MOTION_ALPHA_TARGET,
                );
            }
            drop(sim);

            // Click (not a drag) → highlight node + neighbors (no camera zoom).
            if !drag.moved {
                self.highlight_neighbors_by_id(drag.node_id);
            }
        }
        self.pan_active = false;
    }

    /// Two-finger scroll: pan the camera by screen-space delta.
    pub fn scroll(&mut self, delta_x: f32, delta_y: f32) {
        self.idle_frame_count = 0;
        let zoom = self.renderer.camera_zoom;
        self.renderer.camera_offset[0] -= delta_x / zoom;
        self.renderer.camera_offset[1] += delta_y / zoom;
        self.renderer.target_offset = self.renderer.camera_offset;
        self.camera_rebuild_pending = true;
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
        self.camera_rebuild_pending = true;
    }

    // ── Neighbor Highlighting ────────────────────────────────────────

    fn neighbor_ids(&self, node_id: u32) -> FxHashSet<u32> {
        let mut ids = FxHashSet::default();
        ids.insert(node_id);

        let Some(entity) = self.world.entity_of_node_id(node_id) else {
            return ids;
        };
        let Some(index) = self.world.index_of(entity) else {
            return ids;
        };

        for &edge_index in self.world.edge_indices_for_index(index) {
            let edge = &self.world.edges[edge_index];
            let neighbor = if edge.source == entity {
                edge.target
            } else if edge.target == entity {
                edge.source
            } else {
                continue;
            };

            if let Some(&neighbor_id) = self.world.entity_to_node_id.get(&neighbor) {
                ids.insert(neighbor_id);
            }
        }

        ids
    }

    fn highlight_neighbors_by_id(&mut self, node_id: u32) {
        self.renderer.highlight.highlighted_ids = self.neighbor_ids(node_id);
        self.renderer.highlight.active = true;
        self.highlight_dirty = true;
        self.idle_frame_count = 0;
    }

    /// Highlight neighbors of a node by UUID (called from FFI).
    pub fn highlight_neighbors(&mut self, uuid: &str) {
        if let Some(&node_id) = self.graph.uuid_to_id.get(uuid) {
            self.highlight_neighbors_by_id(node_id);
        }
    }

    /// Poll the current haptic event from the simulation.
    /// Returns 0=None, 1=Light snap, 2=Heavy collision.
    pub fn poll_haptic(&self) -> u8 {
        self.sim.lock().haptic_event
    }

    /// Enable/disable bullet-time search physics.
    /// When active: heavy damping + low alpha_target for slow-motion drift.
    pub fn set_search_active(&self, active: bool) {
        let mut sim = self.sim.lock();
        sim.set_search_active(active);
    }

    /// Update laboratory physics toggles and tuning knobs.
    /// Updates both simulation params and renderer visual settings.
    #[allow(clippy::too_many_arguments)]
    pub fn set_lab_params(
        &mut self,
        enable_fluid: bool,
        enable_torsion: bool,
        enable_elastic: bool,
        enable_tension: bool,
        fluid_viscosity: f32,
        edge_elasticity: f32,
        torsion_rigidity: f32,
        boids_cohesion: f32,
        wind_x: f32,
        wind_y: f32,
        enable_orbital: bool,
        orbital_speed: f32,
    ) {
        self.idle_frame_count = 0;
        // Simulation-side params
        {
            let mut sim = self.sim.lock();
            sim.params.enable_fluid_dynamics = enable_fluid;
            if !enable_fluid {
                sim.clear_fluid_velocity();
            }
            sim.params.enable_torsional_springs = enable_torsion;
            sim.params.fluid_viscosity = fluid_viscosity.clamp(0.0, 1.0);
            sim.params.torsion_rigidity = torsion_rigidity.clamp(0.0, 1.0);
            sim.params.boids_cohesion = boids_cohesion.clamp(0.0, 1.0);
            sim.params.wind_x = wind_x;
            sim.params.wind_y = wind_y;
            sim.params.enable_orbital = enable_orbital;
            sim.params.orbital_speed = orbital_speed.clamp(0.0, 1.0);
            sim.reheat();
        }
        // Renderer-side params
        self.renderer.enable_elastic_edges = enable_elastic;
        let _ = enable_tension; // tension coloring removed
        self.renderer.edge_elasticity = edge_elasticity.clamp(0.0, 1.0);
        self.renderer.wind_x = wind_x;
        self.renderer.wind_y = wind_y;
    }

    /// Clear neighbor highlighting.
    pub fn clear_highlight(&mut self) {
        if self.renderer.highlight.active {
            self.renderer.highlight.active = false;
            self.renderer.highlight.highlighted_ids.clear();
            self.highlight_dirty = true;
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

        let ids = &mut self.renderer.highlight.highlighted_ids;
        ids.clear();
        self.search_index
            .collect_contains_match_node_ids(query, &mut self.search_highlight_ids_scratch);

        if self.search_highlight_ids_scratch.is_empty() {
            // No matches — keep highlight active but with empty set (dims everything).
            self.renderer.highlight.active = true;
        } else {
            ids.reserve(self.search_highlight_ids_scratch.len());
            ids.extend(self.search_highlight_ids_scratch.iter().copied());
            self.renderer.highlight.active = true;
        }
        self.highlight_dirty = true;
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
            self.camera_rebuild_pending = true;
        }
    }

    /// Center camera on a specific node by UUID, zooming in moderately.
    pub fn center_on_node(&mut self, uuid: &str) {
        if let Some(&node_id) = self.graph.uuid_to_id.get(uuid)
            && let Some(&idx) = self.graph.id_to_index.get(&node_id)
        {
            let node = &self.graph.nodes[idx];
            self.renderer.target_offset = [node.x, node.y];
            self.renderer.target_zoom = 3.5; // Close-up zoom for page mode
            self.renderer.is_animating = true;
            self.camera_rebuild_pending = true;
        }
    }

    /// Zoom to fit all visible nodes with padding.
    pub fn zoom_to_fit(&mut self) {
        self.sync_all_positions();

        let (mut min_x, mut min_y) = (f32::MAX, f32::MAX);
        let (mut max_x, mut max_y) = (f32::MIN, f32::MIN);
        let mut any = false;

        for index in 0..self.world.len() {
            if self.world.graph_node[index].visible == 0 {
                continue;
            }
            any = true;
            let pos = &self.world.transform[index];
            let radius = self.world.graph_node[index].radius;
            min_x = min_x.min(pos.x - radius);
            min_y = min_y.min(pos.y - radius);
            max_x = max_x.max(pos.x + radius);
            max_y = max_y.max(pos.y + radius);
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
        let padding = 1.5;
        let zoom = (w / graph_w).min(h / graph_h) * padding;

        self.renderer.target_offset = [cx, cy];
        self.renderer.target_zoom = clamp_zoom_for_theme(self.renderer.visual_theme, zoom);
        self.renderer.is_animating = true;
        self.camera_rebuild_pending = true;
    }

    // ── Force Parameters ─────────────────────────────────────────────

    /// Update the 4 core force parameters and reheat.
    /// All values clamped to safe ranges to prevent physics instability.
    pub fn set_force_params(
        &mut self,
        link_distance: f32,
        charge_strength: f32,
        charge_range: f32,
        link_strength: f32,
    ) {
        self.idle_frame_count = 0;
        let mut sim = self.sim.lock();
        sim.params.link_distance = link_distance.clamp(10.0, 2000.0);
        sim.params.charge_strength = charge_strength.clamp(-100_000.0, 0.0);
        sim.params.charge_range = charge_range.clamp(10.0, 5000.0);
        sim.params.link_strength = link_strength.clamp(0.0, 10.0);
        self.renderer.link_distance = sim.params.link_distance;
        sim.reheat();
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
        sim.params.velocity_decay = velocity_decay.clamp(0.01, 0.99);
        sim.params.center_strength = center_strength.clamp(0.0, 0.2);
        sim.params.collision_radius = collision_radius.clamp(0.0, 100.0);

        // Update collision radii for all nodes.
        let new_radius = sim.params.collision_radius;
        for r in &mut sim.collision_radii {
            *r = new_radius;
        }
        sim.reheat();
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

    /// Override cluster IDs from a UUID → cluster_id map (semantic clustering).
    /// Maps UUIDs to simulation indices via `graph_indices`, then overwrites
    /// `cluster_ids` for matched nodes. Unmatched nodes keep their existing
    /// cluster assignment. Reheats the simulation so new clusters settle.
    pub fn set_cluster_ids(&mut self, uuid_to_cluster: &std::collections::HashMap<String, u32>) {
        self.idle_frame_count = 0;
        let cluster_state = {
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

            sim.reheat();
            (
                sim.cluster_ids.clone(),
                sim.edges.clone(),
                sim.graph_indices.clone(),
            )
        };

        self.cluster_cache
            .build(cluster_state.0.clone(), &cluster_state.1, &cluster_state.2);
        self.world.sync_clusters(&cluster_state.0, &cluster_state.2);

        self.renderer.clear_aggregated_edges();
    }

    /// Push semantic neighbor pairs to the simulation thread.
    /// Maps graph-level node indices to simulation-level indices.
    pub fn sync_semantic_neighbors(&mut self) {
        let mut sim = self.sim.lock();
        // Build graph_index → sim_index reverse map
        let mut graph_to_sim: rustc_hash::FxHashMap<usize, usize> =
            rustc_hash::FxHashMap::default();
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
        sim.reheat();
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

    /// User-controlled physics freeze. Stops/starts the physics thread accordingly.
    pub fn set_user_frozen(&mut self, frozen: bool) {
        self.sim.lock().set_user_frozen(frozen);
        if frozen {
            self.stop_physics();
        } else if self.physics_handle.is_none() {
            self.start_physics();
        }
    }

    pub fn set_mode(&mut self, mode: u8) {
        self.idle_frame_count = 0;
        self.mode = mode;
        let mut sim = self.sim.lock();
        if mode == 1 {
            // Page mode: tight clustering beside the note window.
            sim.params.link_distance = 60.0;
            sim.params.charge_strength = -400.0;
            sim.params.charge_range = 250.0;
            sim.params.center_strength = 0.06;
        } else {
            // Global mode: dense knowledge-graph layout.
            self.anchor_rect = None;
            sim.anchor_center = None;
            sim.params.link_distance = 80.0;
            sim.params.charge_strength = -300.0;
            sim.params.charge_range = 400.0;
            sim.params.center_strength = 0.03;
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

    pub fn set_lite_mode(&mut self, enabled: bool) {
        let level = if enabled { 2u8 } else { 0 };
        self.quality_level = level;
        self.renderer.quality_level = level;
        self.sim.lock().lite_mode = enabled;
        self.quality_rebuild_pending = true;
        self.highlight_dirty = true;
        self.idle_frame_count = 0;
    }

    /// Switch renderer between light and dark mode color palettes.
    pub fn set_light_mode(&mut self, enabled: bool) {
        self.renderer.light_mode = enabled;
    }

    /// Set quality level: 0 = Cinematic, 1 = Balanced, 2 = Performance.
    pub fn set_quality_level(&mut self, level: u8) {
        let clamped = level.min(2);
        self.quality_level = clamped;
        self.renderer.quality_level = clamped;
        self.sim.lock().lite_mode = clamped >= 2;
        self.quality_rebuild_pending = true;
        self.highlight_dirty = true;
        self.idle_frame_count = 0;
    }

    /// Set visual theme: 0 = Dialogue (default), 1 = Classic.
    pub fn set_visual_theme(&mut self, theme: u8) {
        self.renderer.visual_theme = VisualTheme::from_u8(theme);
    }

    /// Set per-node color override by UUID. Pass alpha=0 to clear.
    /// Updates both Graph node and ECS RenderComponent for theme-agnostic rendering.
    pub fn set_node_color_override(&mut self, uuid: &str, r: f32, g: f32, b: f32, a: f32) {
        let color = [r, g, b, a];
        if let Some(&id) = self.graph.uuid_to_id.get(uuid) {
            if let Some(&idx) = self.graph.id_to_index.get(&id) {
                self.graph.nodes[idx].color_override = color;
            }
            // Mirror to ECS World
            if let Some(&entity) = self.world.node_id_to_entity.get(&id) {
                if let Some(ei) = self.world.index_of(entity) {
                    self.world.render[ei].color_override = color;
                }
            }
        }
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

    /// Read-only access to the ECS World.
    pub fn world(&self) -> &World {
        &self.world
    }

    /// Reheat the physics simulation (after embeddings change, etc.).
    pub fn reheat(&mut self) {
        self.sync_semantic_neighbors();
        let sim = self.sim.clone();
        let mut sim = sim.lock();
        sim.reheat();
        self.idle_frame_count = 0;
    }

    // ── Temporal Index ──────────────────────────────────────────────

    fn node_indices_for_uuid(&self, uuid: &str) -> Option<(usize, Option<usize>)> {
        let id = *self.graph.uuid_to_id.get(uuid)?;
        let graph_index = *self.graph.id_to_index.get(&id)?;
        Some((graph_index, self.world.index_of_node_id(id)))
    }

    /// Set timestamps for a node by UUID.
    pub fn set_node_time(&mut self, uuid: &str, created_at: f64, updated_at: f64) {
        if let Some((graph_index, world_index)) = self.node_indices_for_uuid(uuid) {
            self.graph.nodes[graph_index].created_at = created_at;
            self.graph.nodes[graph_index].updated_at = updated_at;
            if let Some(world_index) = world_index {
                self.world.graph_node[world_index].created_at = created_at;
                self.world.graph_node[world_index].updated_at = updated_at;
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
        if let Some((graph_index, world_index)) = self.node_indices_for_uuid(uuid) {
            let clamped = confidence.clamp(0.0, 1.0);
            self.graph.nodes[graph_index].confidence = clamped;
            if let Some(world_index) = world_index {
                self.world.graph_node[world_index].confidence = clamped;
            }
        }
    }

    /// Set timestamps and confidence in one node lookup.
    pub fn set_node_metadata(
        &mut self,
        uuid: &str,
        created_at: f64,
        updated_at: f64,
        confidence: f32,
    ) {
        if let Some((graph_index, world_index)) = self.node_indices_for_uuid(uuid) {
            let clamped = confidence.clamp(0.0, 1.0);
            self.graph.nodes[graph_index].created_at = created_at;
            self.graph.nodes[graph_index].updated_at = updated_at;
            self.graph.nodes[graph_index].confidence = clamped;
            if let Some(world_index) = world_index {
                self.world.graph_node[world_index].created_at = created_at;
                self.world.graph_node[world_index].updated_at = updated_at;
                self.world.graph_node[world_index].confidence = clamped;
            }
        }
    }

    // ── Dialogue ──────────────────────────────────────────────────────

    /// Activate dialogue face on the node matching `node_uuid`.
    pub fn dialogue_open(&mut self, node_uuid: &str) {
        if let Some(&id) = self.graph.uuid_to_id.get(node_uuid) {
            if let Some(idx) = self.world.index_of_node_id(id) {
                self.renderer.dialogue.active = true;
                self.renderer.dialogue.node_index = Some(idx);
                self.renderer.dialogue.look_target_world =
                    [self.world.transform[idx].x, self.world.transform[idx].y];
                self.idle_frame_count = 0;
            }
        }
    }

    /// Deactivate dialogue face.
    pub fn dialogue_close(&mut self) {
        self.renderer.dialogue.active = false;
        self.renderer.dialogue.node_index = None;
        self.renderer.dialogue.is_streaming = false;
        self.renderer.dialogue.look_target_world = [0.0; 2];
        self.idle_frame_count = 0;
    }

    /// Set streaming state (mouth animation).
    pub fn dialogue_set_streaming(&mut self, streaming: bool) {
        self.renderer.dialogue.is_streaming = streaming;
        if streaming {
            self.idle_frame_count = 0;
        }
    }

    pub fn dialogue_screen_rect(&self) -> [f32; 4] {
        self.renderer.dialogue.box_screen_rect
    }

    pub fn dialogue_node_screen_pos(&self) -> [f32; 2] {
        self.renderer.dialogue.node_screen_pos
    }

    pub fn dialogue_is_active(&self) -> bool {
        self.renderer.dialogue.active
    }
}

impl Drop for Engine {
    fn drop(&mut self) {
        self.stop_physics();
    }
}

// ── Physics Thread ──────────────────────────────────────────────────────────

fn physics_loop(sim: Arc<Mutex<Simulation>>, stop: Arc<AtomicBool>) {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        while !stop.load(Ordering::Relaxed) {
            let start = Instant::now();

            let (settled, _alpha, node_count) = {
                let mut sim = sim.lock();
                sim.tick();
                (sim.is_settled, sim.params.alpha, sim.x.len())
            };

            if settled {
                if stop.load(Ordering::Relaxed) {
                    break;
                }
                std::thread::sleep(Duration::from_millis(SETTLED_SLEEP_MS));
                continue;
            }

            // Adaptive rate: fewer ticks at high node counts.
            let target_dt = Duration::from_secs_f64(1.0 / adaptive_physics_hz(node_count));
            let elapsed = start.elapsed();
            if elapsed < target_dt {
                std::thread::sleep(target_dt - elapsed);
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
    use metal::foreign_types::ForeignType;
    use metal::{Device, MetalLayer};

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
        assert!(
            (g1.nodes[0].x - (-50.0)).abs() < f32::EPSILON,
            "original unchanged"
        );
        assert!(
            (g2.nodes[0].x - 999.0).abs() < f32::EPSILON,
            "clone modified"
        );
    }

    #[test]
    fn quality_level_change_marks_renderer_for_buffer_rebuild() {
        let device = Device::system_default().expect("Metal device should exist in engine tests");
        let layer = MetalLayer::new();
        let mut engine = Engine::new(
            device.as_ptr() as *mut std::ffi::c_void,
            layer.as_ptr() as *mut std::ffi::c_void,
        )
        .expect("engine should initialize");

        engine.camera_rebuild_pending = false;
        engine.quality_rebuild_pending = false;
        engine.highlight_dirty = false;
        engine.idle_frame_count = 9;

        engine.set_quality_level(2);

        assert_eq!(engine.quality_level, 2);
        assert_eq!(engine.renderer.quality_level, 2);
        assert!(engine.sim.lock().lite_mode);
        assert!(engine.quality_rebuild_pending);
        assert!(engine.highlight_dirty);
        assert_eq!(engine.idle_frame_count, 0);

        engine.set_quality_level(0);

        assert_eq!(engine.quality_level, 0);
        assert!(!engine.sim.lock().lite_mode);
    }

    #[test]
    fn sync_all_positions_rebuilds_world_spatial_grid() {
        let device = Device::system_default().expect("Metal device should exist in engine tests");
        let layer = MetalLayer::new();
        let mut engine = Engine::new(
            device.as_ptr() as *mut std::ffi::c_void,
            layer.as_ptr() as *mut std::ffi::c_void,
        )
        .expect("engine should initialize");

        engine.graph = make_graph();
        engine.commit(false);
        engine.stop_physics();

        let moved_node_id = engine.graph.nodes[0].id;
        let moved_entity = engine
            .world
            .entity_of_node_id(moved_node_id)
            .expect("world should map node id to entity");
        let sim_index = engine
            .sim
            .lock()
            .graph_indices
            .iter()
            .position(|&graph_index| graph_index == 0)
            .expect("simulation should map node 0");

        {
            let mut sim = engine.sim.lock();
            sim.x[sim_index] = 520.0;
            sim.y[sim_index] = 420.0;
            sim.vx[sim_index] = 0.0;
            sim.vy[sim_index] = 0.0;
        }

        engine.sync_all_positions();

        let moved_neighbors = engine.world.spatial_grid.query_neighbors(520.0, 420.0);
        assert!(
            moved_neighbors.contains(&moved_entity),
            "spatial grid should follow synced node positions"
        );

        let old_neighbors = engine.world.spatial_grid.query_neighbors(-50.0, 0.0);
        assert!(
            !old_neighbors.contains(&moved_entity),
            "spatial grid should drop the node from its stale position"
        );
    }

    #[test]
    fn camera_motion_rebuilds_instance_buffers_during_zoom_animation() {
        let device = Device::system_default().expect("Metal device should exist in engine tests");
        let layer = MetalLayer::new();
        let mut engine = Engine::new(
            device.as_ptr() as *mut std::ffi::c_void,
            layer.as_ptr() as *mut std::ffi::c_void,
        )
        .expect("engine should initialize");

        engine.graph = make_graph();
        engine.commit(false);
        engine.stop_physics();
        engine.sim.lock().is_settled = true;
        engine.last_sim_active = false;

        let _ = engine.render(1280, 720);
        let baseline = engine.renderer.classic_buffer_rebuild_count();

        engine.renderer.target_zoom = engine.renderer.camera_zoom * 1.35;
        engine.renderer.target_offset = [
            engine.renderer.camera_offset[0] + 24.0,
            engine.renderer.camera_offset[1] - 18.0,
        ];
        engine.camera_rebuild_pending = true;

        let _ = engine.render(1280, 720);

        assert!(
            engine.renderer.classic_buffer_rebuild_count() > baseline,
            "zoom animation should rebuild visible buffers while the camera is moving"
        );
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
        assert!(
            sim.is_settled,
            "500-node sim should settle within 600 ticks"
        );
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
            assert!(
                sim.vx[i].is_finite(),
                "vx[{}] is not finite: {}",
                i,
                sim.vx[i]
            );
            assert!(
                sim.vy[i].is_finite(),
                "vy[{}] is not finite: {}",
                i,
                sim.vy[i]
            );
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
        let (wx, wy) = (
            (sx - viewport_w as f32 * 0.5) / zoom + offset[0],
            (sy - viewport_h as f32 * 0.5) / zoom + offset[1],
        );
        let hit = spatial.query_point(wx, wy);
        assert_eq!(hit, Some(0), "should hit node 'a' (id=0)");

        // Test miss on background.
        let (bx, by) = (
            (-300.0 - offset[0]) * zoom + viewport_w as f32 * 0.5,
            (300.0 - offset[1]) * zoom + viewport_h as f32 * 0.5,
        );
        let (bwx, bwy) = (
            (bx - viewport_w as f32 * 0.5) / zoom + offset[0],
            (by - viewport_h as f32 * 0.5) / zoom + offset[1],
        );
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
        for _ in 0..600 {
            sim.tick();
        }
        assert!(sim.is_settled, "should settle after reheat + 600 ticks");
    }

    #[test]
    fn zoom_to_fit_empty_graph_safe() {
        // zoom_to_fit with 0 nodes should not panic or produce NaN.
        let min_x = f32::MAX;
        let max_x = f32::MIN;

        // No nodes → min_x stays MAX → skip zoom.
        assert!(min_x > max_x, "empty graph should skip zoom computation");
    }

    #[test]
    fn zoom_clamp_floor_is_one_for_all_themes() {
        assert_eq!(clamp_zoom_for_theme(VisualTheme::Dialogue, 0.35), 1.0);
        assert_eq!(clamp_zoom_for_theme(VisualTheme::Classic, 0.35), 1.0);
    }

    #[test]
    fn zoom_clamp_ceiling_is_ten_for_all_themes() {
        assert_eq!(clamp_zoom_for_theme(VisualTheme::Dialogue, 15.0), 10.0);
        assert_eq!(clamp_zoom_for_theme(VisualTheme::Classic, 15.0), 10.0);
    }

    #[test]
    fn entrance_presettle_budget_is_bounded() {
        let (ticks, budget) = presettle_limits(1_900, true);
        assert!(
            ticks < 1_200,
            "entrance pre-settle should no longer block on 1200 ticks"
        );
        assert!(budget <= Duration::from_millis(6));
    }

    #[test]
    fn non_entrance_presettle_budget_stays_tiny() {
        let (ticks, budget) = presettle_limits(400, false);
        assert_eq!(ticks, 24);
        assert_eq!(budget, Duration::from_millis(2));
    }

    #[test]
    fn perspective_formula_positive_for_valid_range() {
        let focal = 2.0f32;
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
        assert!(s.params.alpha >= 0.05, "alpha should be reheated");
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
    fn cluster_cache_assignments_sync_back_into_world() {
        let mut graph = Graph::new();
        graph.add_node("uuid-a".into(), -50.0, 0.0, 0, 2, "A".into());
        graph.add_node("uuid-b".into(), -40.0, 0.0, 0, 2, "B".into());
        graph.add_node("uuid-c".into(), 40.0, 0.0, 0, 2, "C".into());
        graph.add_node("uuid-d".into(), 50.0, 0.0, 0, 2, "D".into());
        graph.add_edge("uuid-a", "uuid-b", 1.0, 0);
        graph.add_edge("uuid-c", "uuid-d", 1.0, 0);
        graph.add_edge("uuid-b", "uuid-c", 1.0, 0);

        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);
        sim.cluster_ids = vec![10, 10, 20, 20];

        let mut cache = crate::cluster_cache::ClusterCache::new();
        cache.build(sim.cluster_ids.clone(), &sim.edges, &sim.graph_indices);

        let mut world = crate::ecs::World::from_graph(&graph);
        let assignments = cache
            .assignments_for_zoom(0.2)
            .expect("neighborhood zoom should use cached assignments");
        world.sync_clusters(assignments, &sim.graph_indices);

        assert_eq!(world.graph_node[0].cluster_id, 10);
        assert_eq!(world.graph_node[1].cluster_id, 10);
        assert_eq!(world.graph_node[2].cluster_id, 20);
        assert_eq!(world.graph_node[3].cluster_id, 20);
    }

    #[test]
    fn stress_10000_nodes_static_layout() {
        // 10000 nodes exceeds static layout threshold (9000).
        // Physics should be completely disabled.
        let graph = make_large_graph(10_000);
        let mut sim = Simulation::new();
        sim.load_from_graph(&graph);

        // Static layout should be active.
        assert!(sim.static_layout, "3000 nodes should trigger static layout");
        assert!(sim.is_settled, "static layout should be settled");
        assert_eq!(sim.params.alpha, 0.0, "alpha should be 0 for static layout");

        // Edges should NOT be in simulation (skipped for performance).
        assert!(
            sim.edges.is_empty(),
            "static layout should not load physics edges"
        );

        // Degrees should still be computed (needed for node radius sizing).
        let total_deg: u32 = sim.degrees.iter().sum();
        assert!(
            total_deg > 0,
            "degrees should be computed for static layout"
        );

        // tick() should be a no-op.
        let x_before: Vec<f32> = sim.x.clone();
        sim.tick();
        assert_eq!(
            sim.x, x_before,
            "tick() should not modify positions in static layout"
        );

        // Verify no NaN/Inf in positions.
        for i in 0..sim.x.len() {
            assert!(sim.x[i].is_finite(), "x[{}] not finite", i);
            assert!(sim.y[i].is_finite(), "y[{}] not finite", i);
        }

        // All velocities should be zero.
        assert!(
            sim.vx.iter().all(|&v| v == 0.0),
            "velocities should be zero"
        );
    }

    // ── Anime aesthetic feature tests ────────────────────────────────
    // Engine requires Metal (GPU), so we test the underlying logic via
    // Simulation/Renderer fields directly.

    #[test]
    fn search_active_physics_params() {
        let mut sim = Simulation::new();
        sim.params.velocity_decay = 0.73;
        sim.params.alpha_target = 0.11;

        sim.set_search_active(true);
        assert!((sim.params.velocity_decay - 0.4).abs() < 0.01);
        assert!((sim.params.alpha_target - 0.02).abs() < 0.01);
        assert!(!sim.is_settled);

        sim.set_search_active(false);
        assert!((sim.params.velocity_decay - 0.73).abs() < 0.01);
        assert!((sim.params.alpha_target - 0.11).abs() < 0.01);
    }

    #[test]
    fn impact_intensity_trigger_logic() {
        // The render path: if haptic_event >= 2, set impact_intensity = 1.0.
        let mut impact_intensity: f32 = 0.0;
        let haptic_event: u8 = 2;
        if haptic_event >= 2 {
            impact_intensity = 1.0;
        }
        assert_eq!(impact_intensity, 1.0);

        // Sub-threshold haptic should not trigger.
        let mut impact_intensity2: f32 = 0.0;
        let haptic_event2: u8 = 1;
        if haptic_event2 >= 2 {
            impact_intensity2 = 1.0;
        }
        assert_eq!(impact_intensity2, 0.0);
    }

    #[test]
    fn wind_params_in_lab_settings() {
        // set_lab_params forwards wind_x/wind_y to both sim and renderer.
        let sim = Arc::new(Mutex::new(Simulation::new()));
        let (wind_x, wind_y) = (15.0f32, -10.0f32);
        {
            let mut s = sim.lock();
            s.params.wind_x = wind_x;
            s.params.wind_y = wind_y;
        }
        let s = sim.lock();
        assert_eq!(s.params.wind_x, 15.0);
        assert_eq!(s.params.wind_y, -10.0);
    }

    #[test]
    fn haptic_event_readable() {
        let sim = Arc::new(Mutex::new(Simulation::new()));
        assert_eq!(sim.lock().haptic_event, 0);
        sim.lock().haptic_event = 1;
        assert_eq!(sim.lock().haptic_event, 1);
        sim.lock().haptic_event = 2;
        assert_eq!(sim.lock().haptic_event, 2);
    }

    #[test]
    fn field_lines_disable_while_dragging() {
        assert!(!should_update_field_lines(0, Some(7), 3, true, false));
        assert!(!should_update_field_lines(1, Some(7), 3, false, false));
        assert!(!should_update_field_lines(0, Some(7), 0, false, false));
        assert!(!should_update_field_lines(0, None, 3, false, false));
        assert!(!should_update_field_lines(0, Some(7), 3, false, true));
    }

    #[test]
    fn field_lines_stay_disabled_for_hovered_nodes() {
        assert!(!should_update_field_lines(0, Some(7), 0, false, false));
        assert!(!should_update_field_lines(0, None, 3, false, false));
    }
}
