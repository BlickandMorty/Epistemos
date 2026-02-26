mod engine;
mod physics;
mod renderer;
pub mod spatial;
mod types;

use std::ffi::{c_char, c_void, CStr};

pub use crate::engine::LabelPosition;

// ── FFI helper ──────────────────────────────────────────────────────────────

/// Safely cast an opaque pointer to an Engine reference.
/// Returns None if ptr is null.
#[inline]
fn get_engine<'a>(ptr: *mut c_void) -> Option<&'a mut engine::Engine> {
    if ptr.is_null() {
        None
    } else {
        Some(unsafe { &mut *(ptr as *mut engine::Engine) })
    }
}

// ── C-compatible structs for batch data loading ─────────────────────────────

/// Node data passed from Swift via C FFI.
#[repr(C)]
pub struct CNode {
    pub uuid: *const c_char,
    pub x: f32,
    pub y: f32,
    pub node_type: u8,
    pub weight: f32,
    pub label: *const c_char,
}

/// Edge data passed from Swift via C FFI.
#[repr(C)]
pub struct CEdge {
    pub source_uuid: *const c_char,
    pub target_uuid: *const c_char,
    pub edge_type: u8,
    pub weight: f32,
}

/// Physics configuration passed from Swift via C FFI.
/// All fields correspond to ForceConfig parameters.
#[repr(C)]
pub struct CPhysicsConfig {
    pub center_force: f32,
    pub repel_force: f32,
    pub link_force: f32,
    pub link_distance: f32,
    pub velocity_decay: f32,
    pub alpha_decay: f32,
}

// ── Lifecycle ───────────────────────────────────────────────────────────────

/// Create a new graph engine with Metal device and layer. Returns an opaque pointer.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_create(
    metal_device: *mut c_void,
    metal_layer: *mut c_void,
) -> *mut c_void {
    let mut engine = Box::new(engine::Engine::new());
    engine.init_renderer(metal_device, metal_layer);
    Box::into_raw(engine) as *mut c_void
}

/// Destroy the engine and free memory.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_destroy(ptr: *mut c_void) {
    if !ptr.is_null() {
        unsafe { drop(Box::from_raw(ptr as *mut engine::Engine)) };
    }
}

// ── Render ──────────────────────────────────────────────────────────────────

/// Render one frame. Called by MTKViewDelegate.draw().
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_render(ptr: *mut c_void) {
    if let Some(engine) = get_engine(ptr) {
        engine.render();
    }
}

/// Resize the viewport.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_resize(ptr: *mut c_void, width: u32, height: u32) {
    if let Some(engine) = get_engine(ptr) {
        engine.resize(width, height);
    }
}

// ── Data loading (batch FFI) ────────────────────────────────────────────────

/// Clear all nodes and edges from the graph.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_clear(ptr: *mut c_void) {
    if let Some(engine) = get_engine(ptr) {
        engine.graph.clear();
    }
}

/// Add a batch of nodes. `nodes` is a C array of CNode, `count` is the length.
/// Called once with all nodes before adding edges.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_add_nodes(ptr: *mut c_void, nodes: *const CNode, count: usize) {
    let Some(engine) = get_engine(ptr) else { return };
    if nodes.is_null() || count == 0 { return; }

    let slice = unsafe { std::slice::from_raw_parts(nodes, count) };
    engine.graph.nodes.reserve(count);

    for cn in slice {
        let uuid = if cn.uuid.is_null() {
            String::new()
        } else {
            unsafe { CStr::from_ptr(cn.uuid) }
                .to_string_lossy()
                .into_owned()
        };

        let label = if cn.label.is_null() {
            String::new()
        } else {
            unsafe { CStr::from_ptr(cn.label) }
                .to_string_lossy()
                .into_owned()
        };

        engine.graph.add_node(uuid, cn.x, cn.y, cn.node_type, cn.weight, label);
    }
}

/// Add a batch of edges. `edges` is a C array of CEdge, `count` is the length.
/// Must be called after add_nodes so UUIDs are resolvable.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_add_edges(ptr: *mut c_void, edges: *const CEdge, count: usize) {
    let Some(engine) = get_engine(ptr) else { return };
    if edges.is_null() || count == 0 { return; }

    let slice = unsafe { std::slice::from_raw_parts(edges, count) };
    engine.graph.edges.reserve(count);

    for ce in slice {
        if ce.source_uuid.is_null() || ce.target_uuid.is_null() { continue; }

        let src = unsafe { CStr::from_ptr(ce.source_uuid) }
            .to_string_lossy();
        let tgt = unsafe { CStr::from_ptr(ce.target_uuid) }
            .to_string_lossy();

        engine.graph.add_edge(&src, &tgt, ce.edge_type, ce.weight);
    }
}

/// Signal that data loading is complete. Positions nodes and starts physics.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_commit(ptr: *mut c_void) {
    let Some(engine) = get_engine(ptr) else { return };
    let count = engine.graph.nodes.len();
    if count == 0 { return; }

    // Place nodes in a circle if they're all at origin (fresh load)
    let all_at_origin = engine.graph.nodes.iter().all(|n| n.pos.x == 0.0 && n.pos.y == 0.0);
    if all_at_origin {
        let cx = engine.width as f32 / 2.0;
        let cy = engine.height as f32 / 2.0;
        let radius = (cx.min(cy)) * 0.6;
        for (i, node) in engine.graph.nodes.iter_mut().enumerate() {
            let angle = 2.0 * std::f32::consts::PI * (i as f32) / (count as f32);
            node.pos.x = cx + radius * angle.cos();
            node.pos.y = cy + radius * angle.sin();
        }
    }

    // Start physics simulation on dedicated thread
    engine.start_physics();

    // Pre-allocate GPU buffers with headroom and perform initial data upload
    if let Some(renderer) = &mut engine.renderer {
        renderer.allocate_buffers(&engine.graph);
    }
}

/// Query how many nodes are currently loaded.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_node_count(ptr: *mut c_void) -> u32 {
    get_engine(ptr).map_or(0, |e| e.graph.nodes.len() as u32)
}

/// Query how many edges are currently loaded.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_edge_count(ptr: *mut c_void) -> u32 {
    get_engine(ptr).map_or(0, |e| e.graph.edges.len() as u32)
}

// ── Visibility ─────────────────────────────────────────────────────────────

/// Set node visibility from a flat byte array (0 = hidden, nonzero = visible).
/// Array indices match node insertion order.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_visibility(
    ptr: *mut c_void,
    visible: *const u8,
    count: usize,
) {
    let Some(engine) = get_engine(ptr) else { return };
    if visible.is_null() || count == 0 { return; }

    let slice = unsafe { std::slice::from_raw_parts(visible, count) };
    for (i, node) in engine.graph.nodes.iter_mut().enumerate() {
        node.visible = if i < slice.len() { slice[i] != 0 } else { true };
    }

    // Rebuild physics with only visible nodes
    {
        let mut phys = engine.shared.physics.lock();
        phys.load_from_graph_filtered(&engine.graph);
    }

    // Re-upload buffers with only visible nodes
    if let Some(renderer) = &mut engine.renderer {
        renderer.upload_graph(&engine.graph);
    }
}

// ── Input handling ──────────────────────────────────────────────────────────

/// Pan the camera by (dx, dy) in screen pixels. Called from scroll/drag events.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_pan(ptr: *mut c_void, dx: f32, dy: f32) {
    if let Some(engine) = get_engine(ptr) {
        if let Some(renderer) = &mut engine.renderer {
            // Pan is inverse of scroll direction, scaled by zoom
            renderer.camera_offset.x -= dx / renderer.camera_zoom;
            renderer.camera_offset.y -= dy / renderer.camera_zoom;
        }
    }
}

/// Zoom the camera by a factor, centered at screen position (cx, cy).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_zoom(ptr: *mut c_void, factor: f32, cx: f32, cy: f32) {
    if let Some(engine) = get_engine(ptr) {
        if let Some(renderer) = &mut engine.renderer {
            let old_zoom = renderer.camera_zoom;
            let new_zoom = (old_zoom * factor).clamp(0.1, 10.0);

            // Zoom toward the cursor position:
            // Convert cursor screen pos to world pos at old zoom,
            // then adjust offset so that world point stays at cursor.
            let vp_w = engine.width as f32;
            let vp_h = engine.height as f32;
            let world_x = cx / old_zoom + renderer.camera_offset.x - vp_w / (2.0 * old_zoom);
            let world_y = cy / old_zoom + renderer.camera_offset.y - vp_h / (2.0 * old_zoom);

            renderer.camera_zoom = new_zoom;

            let new_world_x = cx / new_zoom + renderer.camera_offset.x - vp_w / (2.0 * new_zoom);
            let new_world_y = cy / new_zoom + renderer.camera_offset.y - vp_h / (2.0 * new_zoom);

            renderer.camera_offset.x += world_x - new_world_x;
            renderer.camera_offset.y += world_y - new_world_y;
        }
    }
}

// ── Mouse events (hit testing / selection) ──────────────────────────────

/// Handle mouse down at screen position (x, y). button: 0=left, 1=right.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_mouse_down(ptr: *mut c_void, x: f32, y: f32, button: u8) {
    if let Some(engine) = get_engine(ptr) {
        engine.mouse_down(x, y, button);
    }
}

/// Handle mouse up at screen position (x, y).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_mouse_up(ptr: *mut c_void, x: f32, y: f32) {
    if let Some(engine) = get_engine(ptr) {
        engine.mouse_up(x, y);
    }
}

/// Handle mouse moved at screen position (x, y). Used for hover detection.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_mouse_moved(ptr: *mut c_void, x: f32, y: f32) {
    if let Some(engine) = get_engine(ptr) {
        engine.mouse_moved(x, y);
    }
}

// ── Callback registration ──────────────────────────────────────────────────

/// Register a callback for node selection. uuid is null when deselected.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_on_node_selected(
    ptr: *mut c_void,
    cb: extern "C" fn(*const c_char, *mut c_void),
    ctx: *mut c_void,
) {
    if let Some(engine) = get_engine(ptr) {
        engine.set_on_node_selected(cb, ctx);
    }
}

/// Register a callback for right-click on a node.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_on_node_right_clicked(
    ptr: *mut c_void,
    cb: extern "C" fn(*const c_char, f32, f32, *mut c_void),
    ctx: *mut c_void,
) {
    if let Some(engine) = get_engine(ptr) {
        engine.set_on_node_right_clicked(cb, ctx);
    }
}

/// Register a callback for hover changes. uuid is null when nothing is hovered.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_on_node_hovered(
    ptr: *mut c_void,
    cb: extern "C" fn(*const c_char, *mut c_void),
    ctx: *mut c_void,
) {
    if let Some(engine) = get_engine(ptr) {
        engine.set_on_node_hovered(cb, ctx);
    }
}

/// Register a callback for label position updates (fired every frame).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_on_labels_updated(
    ptr: *mut c_void,
    cb: extern "C" fn(*const LabelPosition, usize, *mut c_void),
    ctx: *mut c_void,
) {
    if let Some(engine) = get_engine(ptr) {
        engine.set_on_labels_updated(cb, ctx);
    }
}

// ── Camera commands ────────────────────────────────────────────────────────

/// Reset camera to origin with zoom 1.0 (animated).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_reset_camera(ptr: *mut c_void) {
    if let Some(engine) = get_engine(ptr) { engine.reset_camera(); }
}

/// Animate camera to center on a specific node by UUID.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_center_on_node(ptr: *mut c_void, uuid: *const c_char) {
    let Some(engine) = get_engine(ptr) else { return };
    if uuid.is_null() { return; }
    let uuid_str = unsafe { CStr::from_ptr(uuid) }.to_string_lossy();
    engine.center_on_node(&uuid_str);
}

/// Animate camera to fit all visible nodes in view.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_fit_all(ptr: *mut c_void) {
    if let Some(engine) = get_engine(ptr) { engine.fit_all(); }
}

// ── Physics configuration ──────────────────────────────────────────────────

/// Update physics simulation parameters. Takes effect on the next tick.
/// Reheats the simulation so changes are visible.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_physics_config(ptr: *mut c_void, config: *const CPhysicsConfig) {
    let Some(engine) = get_engine(ptr) else { return };
    if config.is_null() { return; }
    let cfg = unsafe { &*config };

    let mut phys = engine.shared.physics.lock();
    phys.config.center_strength = cfg.center_force;
    phys.config.repulsion = cfg.repel_force;
    phys.config.attraction = cfg.link_force;
    phys.config.link_distance = cfg.link_distance;
    phys.config.velocity_decay = cfg.velocity_decay;
    phys.config.alpha_decay = cfg.alpha_decay;

    // Reheat so the user sees the change immediately
    phys.reheat();
}

/// Get the current physics config values (for populating UI on launch).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_get_physics_config(ptr: *mut c_void, out: *mut CPhysicsConfig) {
    let Some(engine) = get_engine(ptr) else { return };
    if out.is_null() { return; }

    let phys = engine.shared.physics.lock();
    let cfg = unsafe { &mut *out };
    cfg.center_force = phys.config.center_strength;
    cfg.repel_force = phys.config.repulsion;
    cfg.link_force = phys.config.attraction;
    cfg.link_distance = phys.config.link_distance;
    cfg.velocity_decay = phys.config.velocity_decay;
    cfg.alpha_decay = phys.config.alpha_decay;
}
