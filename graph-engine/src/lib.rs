// FFI entry points dereference raw pointers by design — safety is the C caller's contract.
#![allow(clippy::not_unsafe_ptr_arg_deref)]

pub mod types;
pub mod quadtree;
pub mod forces;
pub mod simulation;
pub mod spatial;
pub mod renderer;
pub mod engine;
pub mod markdown;
pub mod cluster;

// ── FFI Boundary ────────────────────────────────────────────────────────────
//
// Every function below is called from Swift via the C bridge header.
// Convention: all functions take `*mut engine::Engine` as the first argument.
// All pointer arguments are null-checked before dereference.

use std::ffi::{c_char, c_void, CStr};

use crate::engine::Engine;

/// Null-guard for engine pointer in void-returning FFI functions.
macro_rules! ffi_engine {
    ($ptr:ident) => {
        if $ptr.is_null() { return; }
        #[allow(unused_unsafe)]
        let $ptr = unsafe { &mut *$ptr };
    };
}

/// Null-guard for engine pointer in value-returning FFI functions.
macro_rules! ffi_engine_or {
    ($ptr:ident, $default:expr) => {
        if $ptr.is_null() { return $default; }
        #[allow(unused_unsafe)]
        let $ptr = unsafe { &mut *$ptr };
    };
}

/// Null-guard for C string pointer — returns empty &str on null.
macro_rules! ffi_cstr {
    ($ptr:ident) => {{
        if $ptr.is_null() { "" } else { unsafe { CStr::from_ptr($ptr) }.to_str().unwrap_or("") }
    }};
}

// ── Lifecycle ───────────────────────────────────────────────────────────────

/// Create a new graph engine. Returns null on failure.
/// `device_ptr`: `MTLDevice` pointer.
/// `layer_ptr`:  `CAMetalLayer` pointer.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_create(
    device_ptr: *mut c_void,
    layer_ptr: *mut c_void,
) -> *mut Engine {
    match Engine::new(device_ptr, layer_ptr) {
        Some(engine) => Box::into_raw(Box::new(engine)),
        None => std::ptr::null_mut(),
    }
}

/// Destroy the engine and free all resources.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_destroy(engine: *mut Engine) {
    if !engine.is_null() {
        unsafe {
            drop(Box::from_raw(engine));
        }
    }
}

// ── Graph Data Loading ──────────────────────────────────────────────────────

/// Clear all nodes and edges (call before re-populating).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_clear(engine: *mut Engine) {
    ffi_engine!(engine);
    engine.graph_mut().clear();
}

/// Add a node to the graph.
/// `uuid`, `label`: null-terminated UTF-8 C strings.
/// `node_type`: 0–6 matching NodeType enum.
/// `link_count`: number of edges this node has (for radius sizing).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_add_node(
    engine: *mut Engine,
    uuid: *const c_char,
    x: f32,
    y: f32,
    node_type: u8,
    link_count: u32,
    label: *const c_char,
) {
    ffi_engine!(engine);
    let uuid_str = ffi_cstr!(uuid).to_owned();
    let label_str = ffi_cstr!(label).to_owned();
    engine
        .graph_mut()
        .add_node(uuid_str, x, y, node_type, link_count, label_str);
}

/// Add an edge between two nodes by UUID.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_add_edge(
    engine: *mut Engine,
    source_uuid: *const c_char,
    target_uuid: *const c_char,
    weight: f32,
) {
    ffi_engine!(engine);
    let src = ffi_cstr!(source_uuid);
    let tgt = ffi_cstr!(target_uuid);
    engine.graph_mut().add_edge(src, tgt, weight);
}

/// Commit the graph: loads data into simulation, starts physics.
/// Call after `graph_engine_clear` + `add_node`/`add_edge` sequence.
/// `entrance`: if 1, plays Obsidian-style entrance animation (nodes cluster at center, expand out).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_commit(engine: *mut Engine, entrance: u8) {
    ffi_engine!(engine);
    engine.commit(entrance != 0);
}

// ── Rendering ───────────────────────────────────────────────────────────────

/// Render one frame. Returns 1 if another frame is needed, 0 if GPU can idle.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_render(
    engine: *mut Engine,
    width: u32,
    height: u32,
) -> u32 {
    ffi_engine_or!(engine, 0);
    engine.render(width, height)
}

// ── Input Events ────────────────────────────────────────────────────────────

/// Mouse/trackpad button pressed.
/// `shift`: 1 if shift key held (for neighbor highlighting), 0 otherwise.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_mouse_down(
    engine: *mut Engine,
    screen_x: f32,
    screen_y: f32,
    shift: u8,
) {
    ffi_engine!(engine);
    engine.mouse_down(screen_x, screen_y, shift != 0);
}

/// Mouse/trackpad moved.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_mouse_moved(
    engine: *mut Engine,
    screen_x: f32,
    screen_y: f32,
) {
    ffi_engine!(engine);
    engine.mouse_moved(screen_x, screen_y);
}

/// Mouse/trackpad button released.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_mouse_up(engine: *mut Engine) {
    ffi_engine!(engine);
    engine.mouse_up();
}

/// Two-finger scroll: pan the camera.
/// `delta_x`, `delta_y`: scroll deltas in screen points.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_scroll(
    engine: *mut Engine,
    delta_x: f32,
    delta_y: f32,
) {
    ffi_engine!(engine);
    engine.scroll(delta_x, delta_y);
}

/// Pinch-to-zoom toward cursor position.
/// `magnification`: scale delta from NSEvent (e.g. +0.02 = 2% zoom in).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_magnify(
    engine: *mut Engine,
    screen_x: f32,
    screen_y: f32,
    magnification: f32,
) {
    ffi_engine!(engine);
    engine.magnify(screen_x, screen_y, magnification);
}

// ── Force Parameters ────────────────────────────────────────────────────────

/// Update the 4 user-adjustable force parameters and reheat the simulation.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_force_params(
    engine: *mut Engine,
    link_distance: f32,
    charge_strength: f32,
    charge_range: f32,
    link_strength: f32,
) {
    ffi_engine!(engine);
    engine.set_force_params(link_distance, charge_strength, charge_range, link_strength);
}

/// Update extended physics parameters.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_extended_force_params(
    engine: *mut Engine,
    velocity_decay: f32,
    center_strength: f32,
    collision_radius: f32,
    warmth: f32,
    orbital: f32,
) {
    ffi_engine!(engine);
    engine.set_extended_force_params(velocity_decay, center_strength, collision_radius, warmth, orbital);
}

// ── Highlighting ────────────────────────────────────────────────────────────

/// Highlight a node and its neighbors (shift+click behavior).
/// `uuid`: null-terminated UTF-8 C string.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_highlight_neighbors(
    engine: *mut Engine,
    uuid: *const c_char,
) {
    ffi_engine!(engine);
    let uuid_str = ffi_cstr!(uuid);
    engine.highlight_neighbors(uuid_str);
}

/// Clear neighbor highlighting.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_clear_highlight(engine: *mut Engine) {
    ffi_engine!(engine);
    engine.clear_highlight();
}

/// Highlight all nodes matching a search query (case-insensitive label match).
/// Empty query clears highlighting.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_search_highlight(
    engine: *mut Engine,
    query: *const c_char,
) {
    ffi_engine!(engine);
    let query_str = ffi_cstr!(query);
    engine.search_highlight(query_str);
}

// ── Camera ──────────────────────────────────────────────────────────────────

/// Animate camera to center on the centroid of visible nodes.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_center_camera(engine: *mut Engine) {
    ffi_engine!(engine);
    engine.center_camera();
}

/// Center camera on a specific node by UUID, zooming in moderately.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_center_on_node(
    engine: *mut Engine,
    uuid: *const c_char,
) {
    ffi_engine!(engine);
    let uuid_str = ffi_cstr!(uuid);
    engine.center_on_node(uuid_str);
}

/// Zoom to fit all visible nodes in the viewport.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_zoom_to_fit(engine: *mut Engine) {
    ffi_engine!(engine);
    engine.zoom_to_fit();
}

// ── Lifecycle ───────────────────────────────────────────────────────────────

/// Pause the engine: stop physics thread to free CPU when overlay is hidden.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_pause(engine: *mut Engine) {
    ffi_engine!(engine);
    engine.pause();
}

/// Resume the engine: restart physics thread when overlay is shown again.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_resume(engine: *mut Engine) {
    ffi_engine!(engine);
    engine.resume();
}

// ── Cluster Parameters ──────────────────────────────────────────────────────

/// Set cluster cohesion strength (0 = off, 1 = strong bubbles).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_cluster_params(engine: *mut Engine, cluster_strength: f32) {
    ffi_engine!(engine);
    engine.set_cluster_params(cluster_strength);
}

/// Set center force mode: 0 = attract, 1 = off, 2 = repel.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_center_mode(engine: *mut Engine, mode: u8) {
    ffi_engine!(engine);
    engine.set_center_mode(mode);
}

// ── Cursor Attractor ────────────────────────────────────────────────────────

/// Set the attractor target in world coordinates.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_attract_target(engine: *mut Engine, x: f32, y: f32) {
    ffi_engine!(engine);
    engine.set_attract_target(x, y);
}

/// Set the attractor target from screen coordinates (auto-converts to world).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_attract_target_screen(
    engine: *mut Engine,
    screen_x: f32,
    screen_y: f32,
) {
    ffi_engine!(engine);
    let (wx, wy) = engine.screen_to_world(screen_x, screen_y);
    engine.set_attract_target(wx, wy);
}

/// Convert screen pixel coordinates to world coordinates.
/// Writes world-space x/y into the out pointers.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_screen_to_world(
    engine: *mut Engine,
    screen_x: f32,
    screen_y: f32,
    out_world_x: *mut f32,
    out_world_y: *mut f32,
) {
    ffi_engine!(engine);
    let (wx, wy) = engine.screen_to_world(screen_x, screen_y);
    unsafe {
        if !out_world_x.is_null() { *out_world_x = wx; }
        if !out_world_y.is_null() { *out_world_y = wy; }
    }
}

/// Mark nodes (by UUID) as attracted to the current target.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_attracted_nodes(
    engine: *mut Engine,
    uuids: *const *const c_char,
    count: u32,
) {
    ffi_engine!(engine);
    if uuids.is_null() || count == 0 {
        engine.set_attracted_nodes(&[]);
        return;
    }
    let uuid_strs: Vec<&str> = (0..count as usize)
        .filter_map(|i| {
            let ptr = unsafe { *uuids.add(i) };
            if ptr.is_null() { return None; }
            unsafe { CStr::from_ptr(ptr) }.to_str().ok()
        })
        .collect();
    engine.set_attracted_nodes(&uuid_strs);
}

/// Clear the attractor (target + attracted nodes).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_clear_attract(engine: *mut Engine) {
    ffi_engine!(engine);
    engine.clear_attract();
}

/// Set the attractor strength (0-1).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_attract_strength(engine: *mut Engine, strength: f32) {
    ffi_engine!(engine);
    engine.set_attract_strength(strength);
}

// ── Display Settings ────────────────────────────────────────────────────────

/// Set the clear color (use transparent for hologram overlay).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_clear_color(
    engine: *mut Engine,
    r: f64,
    g: f64,
    b: f64,
    a: f64,
) {
    ffi_engine!(engine);
    engine.set_clear_color(r, g, b, a);
}

/// Set light mode (darker node colors for light backgrounds).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_light_mode(engine: *mut Engine, enabled: u8) {
    ffi_engine!(engine);
    engine.set_light_mode(enabled != 0);
}

/// Set graph mode: 0 = global, 1 = page.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_mode(engine: *mut Engine, mode: u8) {
    ffi_engine!(engine);
    engine.set_mode(mode);
}

/// Set the note window rect in screen pixels for page mode anchor positioning.
/// Nodes will cluster near this rect instead of dead center.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_anchor_rect(
    engine: *mut Engine,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
) {
    ffi_engine!(engine);
    engine.set_anchor_rect(x, y, w, h);
}

// ── Queries ─────────────────────────────────────────────────────────────────

/// Check if the simulation has settled (alpha < alpha_min).
/// Returns 1 if settled, 0 if still running.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_is_settled(engine: *mut Engine) -> u8 {
    ffi_engine_or!(engine, 1);
    u8::from(engine.is_settled())
}

/// Get the UUID of the currently hovered node.
/// Returns null if no node is hovered.
/// The pointer is valid until the next call to any UUID query function.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_hovered_node_uuid(engine: *mut Engine) -> *const c_char {
    ffi_engine_or!(engine, std::ptr::null());
    match engine.hovered_id() {
        Some(id) => engine.node_uuid_by_id(id),
        None => std::ptr::null(),
    }
}

/// Get the UUID of the currently selected node.
/// Returns null if no node is selected.
/// The pointer is valid until the next call to any UUID query function.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_selected_node_uuid(engine: *mut Engine) -> *const c_char {
    ffi_engine_or!(engine, std::ptr::null());
    match engine.selected_id() {
        Some(id) => engine.node_uuid_by_id(id),
        None => std::ptr::null(),
    }
}
