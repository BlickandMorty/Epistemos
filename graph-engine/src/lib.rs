mod engine;
mod physics;
mod types;

use std::ffi::{c_char, c_void, CStr};

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

// ── Lifecycle ───────────────────────────────────────────────────────────────

/// Create a new graph engine. Returns an opaque pointer.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_create(
    _metal_device: *mut c_void,
    _metal_layer: *mut c_void,
) -> *mut c_void {
    let engine = Box::new(engine::Engine::new());
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
