use std::ffi::c_void;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use parking_lot::Mutex;

use crate::physics::PhysicsState;
use crate::renderer::Renderer;
use crate::types::Graph;

/// Shared state between the physics thread and the render/main thread.
pub struct SharedState {
    pub physics: Mutex<PhysicsState>,
}

pub struct Engine {
    pub graph: Graph,
    pub width: u32,
    pub height: u32,
    pub shared: Arc<SharedState>,
    pub renderer: Option<Renderer>,
    physics_running: Arc<AtomicBool>,
    physics_handle: Option<std::thread::JoinHandle<()>>,
}

impl Engine {
    pub fn new() -> Self {
        let shared = Arc::new(SharedState {
            physics: Mutex::new(PhysicsState::new()),
        });

        Self {
            graph: Graph::new(),
            width: 800,
            height: 600,
            shared,
            renderer: None,
            physics_running: Arc::new(AtomicBool::new(false)),
            physics_handle: None,
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
        }

        self.physics_running.store(true, Ordering::SeqCst);

        let shared = Arc::clone(&self.shared);
        let running = Arc::clone(&self.physics_running);

        self.physics_handle = Some(
            std::thread::Builder::new()
                .name("graph-physics".into())
                .spawn(move || {
                    let tick_duration = std::time::Duration::from_micros(8333); // ~120 Hz

                    while running.load(Ordering::Relaxed) {
                        let start = std::time::Instant::now();

                        {
                            let mut phys = shared.physics.lock();
                            phys.tick();
                            if phys.is_settled {
                                drop(phys);
                                std::thread::sleep(std::time::Duration::from_millis(50));
                                continue;
                            }
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

    /// Copy physics positions back to graph nodes (called before rendering).
    pub fn sync_positions(&mut self) {
        let phys = self.shared.physics.lock();
        phys.write_back(&mut self.graph);
    }

    pub fn render(&mut self) {
        // Sync positions from physics thread
        self.sync_positions();

        // Upload updated positions to GPU and draw
        if let Some(renderer) = &mut self.renderer {
            renderer.upload_graph(&self.graph);
            renderer.draw(self.width, self.height);
        }
    }
}

impl Drop for Engine {
    fn drop(&mut self) {
        self.stop_physics();
    }
}
