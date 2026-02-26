use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use glam::Vec2;
use parking_lot::Mutex;

use crate::physics::PhysicsState;
use crate::renderer::Renderer;
use crate::types::Graph;

/// Position snapshot: a lightweight copy of positions that the render thread reads.
/// Physics thread writes to PhysicsState, then briefly locks to publish a snapshot.
/// This avoids holding the mutex for the entire O(n log n) physics tick.
pub struct SharedState {
    pub physics: Mutex<PhysicsState>,
    /// Latest positions snapshot. Updated by physics thread after each tick.
    pub positions: Mutex<Vec<Vec2>>,
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
}

impl Engine {
    pub fn new() -> Self {
        let shared = Arc::new(SharedState {
            physics: Mutex::new(PhysicsState::new()),
            positions: Mutex::new(Vec::new()),
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

            // Publish initial positions
            let mut snap = self.shared.positions.lock();
            *snap = phys.positions.clone();
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

                    while running.load(Ordering::Relaxed) {
                        let start = std::time::Instant::now();

                        // 1. Lock physics, run tick, copy positions to local buffer, unlock
                        let settled = {
                            let mut phys = shared.physics.lock();
                            phys.tick();
                            local_snap.clear();
                            local_snap.extend_from_slice(&phys.positions);
                            phys.is_settled
                        };
                        // Physics mutex is now released.

                        // 2. Briefly lock positions to publish snapshot (no physics lock held)
                        {
                            let mut snap = shared.positions.lock();
                            std::mem::swap(&mut *snap, &mut local_snap);
                        }

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

    /// Copy position snapshot to graph nodes (called before rendering).
    /// Only locks the positions mutex briefly — does NOT contend with the full physics tick.
    pub fn sync_positions(&mut self) {
        let snap = self.shared.positions.lock();
        let n = snap.len().min(self.graph.nodes.len());
        for i in 0..n {
            self.graph.nodes[i].pos = snap[i];
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

    /// Linear scan hit test over all visible nodes. Returns the closest node within radius.
    fn hit_test(&self, world_pos: Vec2) -> Option<u32> {
        let mut best: Option<(u32, f32)> = None;
        for node in &self.graph.nodes {
            if !node.visible {
                continue;
            }
            let dist = (world_pos - node.pos).length();
            let hit_radius = node.radius * 1.5; // 50% padding for touch targets
            if dist < hit_radius {
                if best.is_none() || dist < best.unwrap().1 {
                    best = Some((node.id, dist));
                }
            }
        }
        best.map(|(id, _)| id)
    }

    pub fn mouse_down(&mut self, x: f32, y: f32, button: u8) {
        let world = self.screen_to_world(x, y);
        let hit = self.hit_test(world);

        if button == 0 {
            // Left click
            self.selected_node_id = hit;
            // Callbacks will be added in Task 4
        } else if button == 1 {
            // Right click
            // Right-click callback will be added in Task 4
        }
    }

    pub fn mouse_up(&mut self, _x: f32, _y: f32) {
        // Node dragging will be added later if needed
    }

    pub fn mouse_moved(&mut self, x: f32, y: f32) {
        let world = self.screen_to_world(x, y);
        let hit = self.hit_test(world);

        if hit != self.hovered_node_id {
            self.hovered_node_id = hit;
            // Hover callback will be added in Task 4
        }
    }

    pub fn render(&mut self) {
        // Sync positions from the latest snapshot
        self.sync_positions();

        // Update positions in pre-allocated GPU buffers and draw
        if let Some(renderer) = &mut self.renderer {
            renderer.update_positions(&self.graph);
            renderer.draw(self.width, self.height);
        }
    }
}

impl Drop for Engine {
    fn drop(&mut self) {
        self.stop_physics();
    }
}
