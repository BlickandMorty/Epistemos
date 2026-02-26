use std::ffi::{c_char, c_void, CString};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use glam::Vec2;
use parking_lot::Mutex;

use crate::physics::PhysicsState;
use crate::renderer::Renderer;
use crate::spatial::SpatialIndex;
use crate::types::Graph;

// ── Callback types ──────────────────────────────────────────────────────────

/// Callback for node selected: uuid (null = deselected), context.
type NodeCallback = extern "C" fn(*const c_char, *mut c_void);

/// Callback for node right-clicked: uuid, screen_x, screen_y, context.
type NodeScreenCallback = extern "C" fn(*const c_char, f32, f32, *mut c_void);

/// Callback for hover: uuid (null = no hover), context.
type HoverCallback = extern "C" fn(*const c_char, *mut c_void);

/// Callback for labels updated: array of LabelPosition, count, context.
type LabelsCallback = extern "C" fn(*const LabelPosition, usize, *mut c_void);

/// Pre-calculated screen position for a visible node label.
#[repr(C)]
pub struct LabelPosition {
    pub uuid: *const c_char,
    pub screen_x: f32,
    pub screen_y: f32,
    pub radius: f32,
    pub alpha: f32,
}

struct CallbackSlot<F> {
    func: F,
    context: *mut c_void,
}

// Mark Send — the void* context is an Unmanaged Swift object whose lifecycle
// is guaranteed by the Coordinator (which outlives the engine).
unsafe impl<F> Send for CallbackSlot<F> {}

/// Position snapshot: a lightweight copy of positions that the render thread reads.
/// Physics thread writes to PhysicsState, then briefly locks to publish a snapshot.
/// This avoids holding the mutex for the entire O(n log n) physics tick.
pub struct SharedState {
    pub physics: Mutex<PhysicsState>,
    /// Latest positions snapshot. Updated by physics thread after each tick.
    pub positions: Mutex<Vec<Vec2>>,
    /// Implicit velocities (pos - prev_pos) for Verlet. Used to seed vel on filter changes.
    pub velocities: Mutex<Vec<Vec2>>,
    /// Maps physics snapshot index -> graph node index (for filtered physics).
    pub graph_indices: Mutex<Vec<usize>>,
    /// True when physics simulation has cooled down. Read by render thread (no lock needed).
    pub settled: AtomicBool,
    /// Drag constraint published by render thread, consumed by physics thread.
    /// (graph_index, world_target). Physics thread maps graph_index → physics_index.
    pub drag: Mutex<Option<(usize, Vec2)>>,
}

pub struct Engine {
    pub graph: Graph,
    pub width: u32,
    pub height: u32,
    pub shared: Arc<SharedState>,
    pub renderer: Option<Renderer>,
    physics_running: Arc<AtomicBool>,
    physics_handle: Option<std::thread::JoinHandle<()>>,

    // Interaction state
    pub selected_node_id: Option<u32>,
    pub hovered_node_id: Option<u32>,
    /// Node being dragged (internal id). Set on mouse_down hit, cleared on mouse_up.
    dragging_node_id: Option<u32>,
    /// World-space target for the dragged node (updated each mouse_dragged).
    drag_world_target: Vec2,

    // Callbacks
    on_node_selected: Option<CallbackSlot<NodeCallback>>,
    on_node_right_clicked: Option<CallbackSlot<NodeScreenCallback>>,
    on_node_hovered: Option<CallbackSlot<HoverCallback>>,
    on_labels_updated: Option<CallbackSlot<LabelsCallback>>,

    // Spatial index for O(log n) hit testing (click/hover detection)
    spatial_index: SpatialIndex,

    // Cached CStrings for callback UUID delivery (avoids per-frame allocation)
    uuid_cache: Vec<CString>,
}

impl Engine {
    pub fn new() -> Self {
        let shared = Arc::new(SharedState {
            physics: Mutex::new(PhysicsState::new()),
            positions: Mutex::new(Vec::new()),
            velocities: Mutex::new(Vec::new()),
            graph_indices: Mutex::new(Vec::new()),
            settled: AtomicBool::new(false),
            drag: Mutex::new(None),
        });

        Self {
            graph: Graph::new(),
            width: 800,
            height: 600,
            shared,
            renderer: None,
            physics_running: Arc::new(AtomicBool::new(false)),
            physics_handle: None,
            selected_node_id: None,
            hovered_node_id: None,
            dragging_node_id: None,
            drag_world_target: Vec2::ZERO,
            on_node_selected: None,
            on_node_right_clicked: None,
            on_node_hovered: None,
            on_labels_updated: None,
            spatial_index: SpatialIndex::new(),
            uuid_cache: Vec::new(),
        }
    }

    /// Initialize the Metal renderer. Called lazily on first draw.
    pub fn init_renderer(&mut self, device_ptr: *mut c_void, layer_ptr: *mut c_void) {
        self.renderer = Renderer::new(device_ptr, layer_ptr);
    }

    pub fn resize(&mut self, width: u32, height: u32) {
        self.width = width;
        self.height = height;

        // Update physics center to match viewport
        let mut phys = self.shared.physics.lock();
        phys.config.center_x = width as f32 / 2.0;
        phys.config.center_y = height as f32 / 2.0;
    }

    /// Start the dedicated physics thread. Called after commit().
    pub fn start_physics(&mut self) {
        if self.physics_running.load(Ordering::SeqCst) {
            return;
        }

        // Load graph data into physics state
        {
            let mut phys = self.shared.physics.lock();
            phys.load_from_graph(&self.graph);
            phys.config.center_x = self.width as f32 / 2.0;
            phys.config.center_y = self.height as f32 / 2.0;

            // Publish initial positions, velocities, and graph_indices
            let mut snap = self.shared.positions.lock();
            *snap = phys.positions.clone();
            drop(snap);
            // Initial velocities: pos - prev_pos
            let vels: Vec<Vec2> = phys.positions.iter().zip(phys.prev_positions.iter())
                .map(|(p, pp)| *p - *pp)
                .collect();
            let mut vel_snap = self.shared.velocities.lock();
            *vel_snap = vels;
            drop(vel_snap);
            let mut gi = self.shared.graph_indices.lock();
            *gi = phys.graph_indices.clone();
        }

        self.physics_running.store(true, Ordering::SeqCst);

        let shared = Arc::clone(&self.shared);
        let running = Arc::clone(&self.physics_running);

        self.physics_handle = Some(
            std::thread::Builder::new()
                .name("graph-physics".into())
                .spawn(move || {
                    let tick_duration = std::time::Duration::from_micros(8333); // ~120 Hz

                    let mut local_snap: Vec<Vec2> = Vec::new();
                    let mut local_gi: Vec<usize> = Vec::new();

                    let mut local_vel: Vec<Vec2> = Vec::new();

                    while running.load(Ordering::Relaxed) {
                        let start = std::time::Instant::now();

                        // 1. Lock physics, apply drag constraint, run tick, copy snapshot
                        let settled = {
                            let mut phys = shared.physics.lock();

                            // Read drag from render thread, map graph_index → physics_index
                            let drag = shared.drag.lock().clone();
                            if let Some((graph_idx, target)) = drag {
                                // Find physics index for this graph index
                                let phys_idx = phys.graph_indices.iter().position(|&gi| gi == graph_idx);
                                phys.drag_constraint = phys_idx.map(|pi| (pi, target));
                                // Keep simulation hot while dragging so neighbors react
                                if phys.config.alpha < 0.3 {
                                    phys.config.alpha = 0.3;
                                }
                                phys.is_settled = false;
                            } else {
                                phys.drag_constraint = None;
                            }

                            phys.tick();
                            local_snap.clear();
                            local_snap.extend_from_slice(&phys.positions);
                            // Compute implicit Verlet velocities: pos - prev_pos
                            local_vel.clear();
                            local_vel.reserve(phys.positions.len());
                            for i in 0..phys.positions.len() {
                                local_vel.push(phys.positions[i] - phys.prev_positions[i]);
                            }
                            local_gi.clear();
                            local_gi.extend_from_slice(&phys.graph_indices);
                            phys.is_settled
                        };
                        // Physics mutex is now released.

                        // 2. Briefly lock positions + velocities + graph_indices to publish (no physics lock held)
                        {
                            let mut snap = shared.positions.lock();
                            std::mem::swap(&mut *snap, &mut local_snap);
                        }
                        {
                            let mut vel = shared.velocities.lock();
                            std::mem::swap(&mut *vel, &mut local_vel);
                        }
                        {
                            let mut gi = shared.graph_indices.lock();
                            std::mem::swap(&mut *gi, &mut local_gi);
                        }

                        // 3. Publish settled flag (lock-free, read by render thread)
                        shared.settled.store(settled, Ordering::Relaxed);

                        if settled {
                            std::thread::sleep(std::time::Duration::from_millis(50));
                            continue;
                        }

                        let elapsed = start.elapsed();
                        if elapsed < tick_duration {
                            std::thread::sleep(tick_duration - elapsed);
                        }
                    }
                })
                .expect("Failed to spawn physics thread"),
        );
    }

    /// Stop the physics thread.
    pub fn stop_physics(&mut self) {
        self.physics_running.store(false, Ordering::SeqCst);
        if let Some(handle) = self.physics_handle.take() {
            let _ = handle.join();
        }
    }

    /// Copy position + velocity snapshot to graph nodes (called before rendering).
    /// Uses graph_indices to map physics positions back to the correct graph nodes.
    /// Only locks the positions mutex briefly — does NOT contend with the full physics tick.
    pub fn sync_positions(&mut self) {
        let snap = self.shared.positions.lock();
        let vel = self.shared.velocities.lock();
        let gi = self.shared.graph_indices.lock();
        for (phys_idx, &graph_idx) in gi.iter().enumerate() {
            if phys_idx < snap.len() && graph_idx < self.graph.nodes.len() {
                self.graph.nodes[graph_idx].pos = snap[phys_idx];
                if phys_idx < vel.len() {
                    self.graph.nodes[graph_idx].vel = vel[phys_idx];
                }
            }
        }
    }

    // ── Interaction ────────────────────────────────────────────────────────

    /// Convert screen coordinates (AppKit space) to world coordinates.
    /// Uses the camera offset and zoom from the renderer.
    fn screen_to_world(&self, screen_x: f32, screen_y: f32) -> Vec2 {
        let renderer = match &self.renderer {
            Some(r) => r,
            None => return Vec2::new(screen_x, screen_y),
        };
        let vp_w = self.width as f32;
        let vp_h = self.height as f32;
        let zoom = renderer.camera_zoom;
        let offset = renderer.camera_offset;

        Vec2::new(
            screen_x / zoom + offset.x - vp_w / (2.0 * zoom),
            screen_y / zoom + offset.y - vp_h / (2.0 * zoom),
        )
    }

    /// O(log n) hit test using the spatial quadtree index.
    /// Returns the closest visible node whose padded radius contains `world_pos`.
    fn hit_test(&self, world_pos: Vec2) -> Option<u32> {
        self.spatial_index.query_point(world_pos.x, world_pos.y)
    }

    /// Handle mouse down. Returns true if a node was hit (caller should route
    /// subsequent drags to `mouse_dragged` instead of panning).
    pub fn mouse_down(&mut self, x: f32, y: f32, button: u8) -> bool {
        let world = self.screen_to_world(x, y);
        let hit = self.hit_test(world);

        if button == 0 {
            self.selected_node_id = hit;
            self.fire_node_selected(hit);

            // Start drag if we hit a node
            if hit.is_some() {
                self.dragging_node_id = hit;
                self.drag_world_target = world;
            } else {
                self.dragging_node_id = None;
            }
        } else if button == 1 {
            if let Some(node_id) = hit {
                self.fire_node_right_clicked(node_id, x, y);
            }
        }

        hit.is_some()
    }

    /// Update the drag target while dragging a node.
    pub fn mouse_dragged(&mut self, x: f32, y: f32) {
        if self.dragging_node_id.is_some() {
            self.drag_world_target = self.screen_to_world(x, y);
        }
    }

    /// Handle mouse up — release any dragged node.
    /// The Verlet integrator preserves the cursor's movement direction as fling velocity.
    pub fn mouse_up(&mut self, _x: f32, _y: f32) {
        if self.dragging_node_id.is_some() {
            self.dragging_node_id = None;
            // Clear drag constraint so physics thread stops applying it
            let mut drag = self.shared.drag.lock();
            *drag = None;
        }
    }

    pub fn mouse_moved(&mut self, x: f32, y: f32) {
        let world = self.screen_to_world(x, y);
        let hit = self.hit_test(world);

        if hit != self.hovered_node_id {
            self.hovered_node_id = hit;
            self.fire_node_hovered(hit);
        }
    }

    // ── Camera commands ────────────────────────────────────────────────────

    pub fn reset_camera(&mut self) {
        if let Some(r) = &mut self.renderer {
            r.target_offset = Vec2::ZERO;
            r.target_zoom = 1.0;
            r.is_animating = true;
        }
    }

    pub fn center_on_node(&mut self, uuid: &str) {
        let node_id = self.graph.uuid_to_id.get(uuid).copied();
        let node_idx = node_id.and_then(|id| self.graph.id_to_index.get(&id).copied());
        if let Some(idx) = node_idx {
            let node = &self.graph.nodes[idx];
            if let Some(r) = &mut self.renderer {
                r.target_offset = node.pos;
                if r.camera_zoom < 1.5 {
                    r.target_zoom = 2.0;
                }
                r.is_animating = true;
            }
        }
    }

    pub fn fit_all(&mut self) {
        let visible: Vec<&crate::types::Node> = self.graph.nodes.iter().filter(|n| n.visible).collect();
        if visible.is_empty() { return; }

        let mut min_x = f32::MAX;
        let mut min_y = f32::MAX;
        let mut max_x = f32::MIN;
        let mut max_y = f32::MIN;
        for n in &visible {
            min_x = min_x.min(n.pos.x);
            min_y = min_y.min(n.pos.y);
            max_x = max_x.max(n.pos.x);
            max_y = max_y.max(n.pos.y);
        }

        let bbox_w = (max_x - min_x).max(100.0);
        let bbox_h = (max_y - min_y).max(100.0);
        let center = Vec2::new((min_x + max_x) * 0.5, (min_y + max_y) * 0.5);

        let vp_w = self.width as f32;
        let vp_h = self.height as f32;
        let zoom_x = vp_w * 0.8 / bbox_w;
        let zoom_y = vp_h * 0.8 / bbox_h;
        let zoom = zoom_x.min(zoom_y).clamp(0.1, 5.0);

        if let Some(r) = &mut self.renderer {
            r.target_offset = center;
            r.target_zoom = zoom;
            r.is_animating = true;
        }
    }

    pub fn render(&mut self) {
        // Sync positions from the latest snapshot
        self.sync_positions();

        // Rebuild spatial index for O(log n) hit testing (click/hover)
        self.spatial_index.build(&self.graph.nodes);

        // Publish drag constraint for the physics thread.
        // We store graph_index so the physics thread can map to its own index.
        if let Some(node_id) = self.dragging_node_id {
            if let Some(&graph_idx) = self.graph.id_to_index.get(&node_id) {
                let mut drag = self.shared.drag.lock();
                *drag = Some((graph_idx, self.drag_world_target));
            }
        }

        // Advance camera animation BEFORE computing label positions.
        // This ensures labels and Metal rendering use the same camera state,
        // eliminating the 1-frame lag that caused labels to trail nodes during animation.
        if let Some(renderer) = &mut self.renderer {
            renderer.update_camera();
        }

        // Project visible node positions to screen and fire labels callback
        self.fire_labels_updated();

        // Update positions in pre-allocated GPU buffers, add highlights, and draw
        if let Some(renderer) = &mut self.renderer {
            renderer.update_positions(&self.graph);
            renderer.set_highlights(self.selected_node_id, self.hovered_node_id, &self.graph);
            renderer.draw(self.width, self.height);
        }
    }

    // ── Callback setters ──────────────────────────────────────────────────

    pub fn set_on_node_selected(&mut self, cb: NodeCallback, ctx: *mut c_void) {
        self.on_node_selected = Some(CallbackSlot { func: cb, context: ctx });
    }

    pub fn set_on_node_right_clicked(&mut self, cb: NodeScreenCallback, ctx: *mut c_void) {
        self.on_node_right_clicked = Some(CallbackSlot { func: cb, context: ctx });
    }

    pub fn set_on_node_hovered(&mut self, cb: HoverCallback, ctx: *mut c_void) {
        self.on_node_hovered = Some(CallbackSlot { func: cb, context: ctx });
    }

    pub fn set_on_labels_updated(&mut self, cb: LabelsCallback, ctx: *mut c_void) {
        self.on_labels_updated = Some(CallbackSlot { func: cb, context: ctx });
    }

    // ── Callback fire methods ─────────────────────────────────────────────

    fn fire_node_selected(&self, node_id: Option<u32>) {
        let Some(cb) = &self.on_node_selected else { return };
        match node_id {
            Some(id) => {
                if let Some(node) = self.graph.nodes.iter().find(|n| n.id == id) {
                    let cstr = CString::new(node.uuid.as_str()).unwrap_or_default();
                    (cb.func)(cstr.as_ptr(), cb.context);
                }
            }
            None => {
                (cb.func)(std::ptr::null(), cb.context);
            }
        }
    }

    fn fire_node_right_clicked(&self, node_id: u32, screen_x: f32, screen_y: f32) {
        let Some(cb) = &self.on_node_right_clicked else { return };
        if let Some(node) = self.graph.nodes.iter().find(|n| n.id == node_id) {
            let cstr = CString::new(node.uuid.as_str()).unwrap_or_default();
            (cb.func)(cstr.as_ptr(), screen_x, screen_y, cb.context);
        }
    }

    fn fire_node_hovered(&self, node_id: Option<u32>) {
        let Some(cb) = &self.on_node_hovered else { return };
        match node_id {
            Some(id) => {
                if let Some(node) = self.graph.nodes.iter().find(|n| n.id == id) {
                    let cstr = CString::new(node.uuid.as_str()).unwrap_or_default();
                    (cb.func)(cstr.as_ptr(), cb.context);
                }
            }
            None => {
                (cb.func)(std::ptr::null(), cb.context);
            }
        }
    }

    fn fire_labels_updated(&mut self) {
        let Some(cb) = &self.on_labels_updated else { return };
        let renderer = match &self.renderer {
            Some(r) => r,
            None => return,
        };

        let physics_settled = self.shared.settled.load(Ordering::Relaxed);
        let camera_still = !renderer.is_animating;

        // While things are moving, send an empty array to hide all labels.
        // This avoids the 1-frame async lag between Metal rendering and CATextLayer updates.
        if !physics_settled || !camera_still {
            (cb.func)(std::ptr::null(), 0, cb.context);
            return;
        }

        let zoom = renderer.camera_zoom;
        let offset = renderer.camera_offset;
        let vp_w = self.width as f32;
        let vp_h = self.height as f32;

        // Rebuild UUID cache if node count changed
        if self.uuid_cache.len() != self.graph.nodes.len() {
            self.uuid_cache = self.graph.nodes.iter()
                .map(|n| CString::new(n.uuid.as_str()).unwrap_or_default())
                .collect();
        }

        // Obsidian-style LOD: only show labels when zoomed in enough that the node
        // has a meaningful screen-space size. High-weight nodes appear first.
        // Cap total labels to prevent CATextLayer thrash.
        const MAX_LABELS: usize = 40;
        const MIN_SCREEN_RADIUS: f32 = 8.0; // Node must be ≥8px on screen to show label

        let mut positions: Vec<LabelPosition> = Vec::new();
        for (i, node) in self.graph.nodes.iter().enumerate() {
            if !node.visible { continue; }

            let screen_radius = node.radius * zoom;

            // Skip labels entirely when node is too small on screen
            if screen_radius < MIN_SCREEN_RADIUS { continue; }

            // World -> screen (in drawable pixels)
            let sx = (node.pos.x - offset.x) * zoom + vp_w * 0.5;
            let sy = (node.pos.y - offset.y) * zoom + vp_h * 0.5;

            // Skip if off-screen (with generous margin)
            if sx < -100.0 || sx > vp_w + 100.0 || sy < -100.0 || sy > vp_h + 100.0 {
                continue;
            }

            // Alpha ramps up as node grows on screen: fade in between 8px and 16px
            let size_alpha = ((screen_radius - MIN_SCREEN_RADIUS) / MIN_SCREEN_RADIUS).clamp(0.0, 1.0);
            // Weight boost: heavier nodes are slightly more opaque
            let weight_boost = if node.weight > 5.0 { 1.0 } else { 0.7 };
            let alpha = size_alpha * weight_boost;
            if alpha < 0.01 { continue; }

            positions.push(LabelPosition {
                uuid: self.uuid_cache[i].as_ptr(),
                screen_x: sx,
                screen_y: sy,
                radius: screen_radius,
                alpha,
            });

            if positions.len() >= MAX_LABELS { break; }
        }

        (cb.func)(positions.as_ptr(), positions.len(), cb.context);
    }
}

impl Drop for Engine {
    fn drop(&mut self) {
        self.stop_physics();
    }
}
