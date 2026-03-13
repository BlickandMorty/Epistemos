// FFI entry points dereference raw pointers by design — safety is the C caller's contract.
#![allow(clippy::not_unsafe_ptr_arg_deref)]

pub mod block_kernel;
pub mod cluster;
pub mod cluster_cache;
pub mod code_highlight;
pub mod ecs;
pub mod edge_aggregation;
pub mod embedding;
pub mod engine;
pub mod forces;
pub mod markdown;
pub mod quadtree;
pub mod renderer;
pub mod search;
pub mod simulation;
pub mod spatial;
pub mod types;
pub mod version;

#[cfg(test)]
pub mod physics_audit_test;

#[cfg(test)]
pub mod graph_tests;

#[cfg(test)]
pub mod comprehensive_simulation_tests;

#[cfg(test)]
pub mod comprehensive_search_tests;

#[cfg(test)]
pub mod comprehensive_spatial_tests;

#[cfg(test)]
pub mod comprehensive_cluster_tests;

#[cfg(test)]
pub mod advanced_chaos_tests;

#[cfg(test)]
pub mod hardened_race_tests;

#[cfg(test)]
mod bench_tests;

#[cfg(test)]
mod edge_case_tests;

#[cfg(test)]
mod theme_ecs_tests;

// ── FFI Boundary ────────────────────────────────────────────────────────────
//
// Every function below is called from Swift via the C bridge header.
// Convention: all functions take `*mut engine::Engine` as the first argument.
// All pointer arguments are null-checked before dereference.
//
// String Lifetime Safety (audited 2026-03-01):
// All C string pointers (*const c_char) are copied into Rust-owned String/&str
// at the FFI boundary via ffi_cstr! macro (.to_str()) or CStr→.to_owned().
// No raw string pointers are stored beyond the function call scope.
// Swift's withCString closures are therefore safe — Rust never holds a reference
// after the function returns.

use std::ffi::{CStr, CString, c_char, c_void};

use crate::engine::Engine;

/// Null-guard for engine pointer in void-returning FFI functions.
macro_rules! ffi_engine {
    ($ptr:ident) => {
        if $ptr.is_null() {
            return;
        }
        #[allow(unused_unsafe)]
        let $ptr = unsafe { &mut *$ptr };
    };
}

/// Null-guard for engine pointer in value-returning FFI functions.
macro_rules! ffi_engine_or {
    ($ptr:ident, $default:expr) => {
        if $ptr.is_null() {
            return $default;
        }
        #[allow(unused_unsafe)]
        let $ptr = unsafe { &mut *$ptr };
    };
}

/// Null-guard for C string pointer — returns empty &str on null.
macro_rules! ffi_cstr {
    ($ptr:ident) => {{
        if $ptr.is_null() {
            ""
        } else {
            unsafe { CStr::from_ptr($ptr) }.to_str().unwrap_or("")
        }
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
/// `edge_type`: 0-11 matching GraphEdgeType enum (0=reference, 4=cites, 9=contradicts, etc.).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_add_edge(
    engine: *mut Engine,
    source_uuid: *const c_char,
    target_uuid: *const c_char,
    weight: f32,
    edge_type: u8,
) {
    ffi_engine!(engine);
    let src = ffi_cstr!(source_uuid);
    let tgt = ffi_cstr!(target_uuid);
    engine.graph_mut().add_edge(src, tgt, weight, edge_type);
}

/// Batch-add nodes to the graph in a single FFI call.
/// All arrays must have length `count`. `uuids` and `labels` are arrays of
/// null-terminated UTF-8 C strings. `xs`, `ys`, `node_types`, `link_counts`
/// are parallel arrays of the same length.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_add_nodes_batch(
    engine: *mut Engine,
    uuids: *const *const c_char,
    xs: *const f32,
    ys: *const f32,
    node_types: *const u8,
    link_counts: *const u32,
    labels: *const *const c_char,
    count: u32,
) {
    ffi_engine!(engine);
    let count = count as usize;
    if count == 0
        || uuids.is_null()
        || labels.is_null()
        || xs.is_null()
        || ys.is_null()
        || node_types.is_null()
        || link_counts.is_null()
    {
        return;
    }
    let uuid_ptrs = unsafe { std::slice::from_raw_parts(uuids, count) };
    let label_ptrs = unsafe { std::slice::from_raw_parts(labels, count) };
    let xs = unsafe { std::slice::from_raw_parts(xs, count) };
    let ys = unsafe { std::slice::from_raw_parts(ys, count) };
    let types = unsafe { std::slice::from_raw_parts(node_types, count) };
    let links = unsafe { std::slice::from_raw_parts(link_counts, count) };

    let graph = engine.graph_mut();
    for i in 0..count {
        let uuid_str = if uuid_ptrs[i].is_null() {
            String::new()
        } else {
            unsafe { CStr::from_ptr(uuid_ptrs[i]) }
                .to_str()
                .unwrap_or("")
                .to_owned()
        };
        let label_str = if label_ptrs[i].is_null() {
            String::new()
        } else {
            unsafe { CStr::from_ptr(label_ptrs[i]) }
                .to_str()
                .unwrap_or("")
                .to_owned()
        };
        graph.add_node(uuid_str, xs[i], ys[i], types[i], links[i], label_str);
    }
}

/// Batch-add edges to the graph in a single FFI call.
/// `source_uuids` and `target_uuids` are arrays of `count` null-terminated C strings.
/// `weights` and `edge_types` are parallel arrays.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_add_edges_batch(
    engine: *mut Engine,
    source_uuids: *const *const c_char,
    target_uuids: *const *const c_char,
    weights: *const f32,
    edge_types: *const u8,
    count: u32,
) {
    ffi_engine!(engine);
    let count = count as usize;
    if count == 0
        || source_uuids.is_null()
        || target_uuids.is_null()
        || weights.is_null()
        || edge_types.is_null()
    {
        return;
    }
    let src_ptrs = unsafe { std::slice::from_raw_parts(source_uuids, count) };
    let tgt_ptrs = unsafe { std::slice::from_raw_parts(target_uuids, count) };
    let wts = unsafe { std::slice::from_raw_parts(weights, count) };
    let types = unsafe { std::slice::from_raw_parts(edge_types, count) };

    let graph = engine.graph_mut();
    for i in 0..count {
        let src = if src_ptrs[i].is_null() {
            ""
        } else {
            unsafe { CStr::from_ptr(src_ptrs[i]) }
                .to_str()
                .unwrap_or("")
        };
        let tgt = if tgt_ptrs[i].is_null() {
            ""
        } else {
            unsafe { CStr::from_ptr(tgt_ptrs[i]) }
                .to_str()
                .unwrap_or("")
        };
        graph.add_edge(src, tgt, wts[i], types[i]);
    }
}

/// Commit the graph: loads data into simulation, starts physics.
/// Call after `graph_engine_clear` + `add_node`/`add_edge` sequence.
/// `entrance`: if 1, uses degree-sorted spiral for initial node layout.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_commit(engine: *mut Engine, entrance: u8) {
    ffi_engine!(engine);
    engine.commit(entrance != 0);
}

/// Remove a node by UUID. Also removes all edges touching it.
/// Returns 1 if the node was found and removed, 0 otherwise.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_remove_node(engine: *mut Engine, uuid: *const c_char) -> u8 {
    ffi_engine_or!(engine, 0);
    let uuid_str = ffi_cstr!(uuid);
    u8::from(engine.graph_mut().remove_node(uuid_str))
}

/// Remove edges between two nodes by UUID (both directions).
/// Returns the number of edges removed.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_remove_edge(
    engine: *mut Engine,
    source_uuid: *const c_char,
    target_uuid: *const c_char,
) -> u32 {
    ffi_engine_or!(engine, 0);
    let src = ffi_cstr!(source_uuid);
    let tgt = ffi_cstr!(target_uuid);
    engine.graph_mut().remove_edges(src, tgt) as u32
}

/// Batch-remove nodes by UUID array.
/// Returns the count of nodes successfully removed.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_remove_nodes_batch(
    engine: *mut Engine,
    uuids: *const *const c_char,
    count: u32,
) -> u32 {
    ffi_engine_or!(engine, 0);
    let count = count as usize;
    if count == 0 || uuids.is_null() {
        return 0;
    }
    // SAFETY: caller guarantees `uuids` points to `count` valid pointers.
    let uuid_ptrs = unsafe { std::slice::from_raw_parts(uuids, count) };
    let graph = engine.graph_mut();
    let mut removed = 0u32;
    for i in 0..count {
        let uuid_str = if uuid_ptrs[i].is_null() {
            ""
        } else {
            // SAFETY: caller guarantees null-terminated UTF-8.
            unsafe { CStr::from_ptr(uuid_ptrs[i]) }
                .to_str()
                .unwrap_or("")
        };
        if graph.remove_node(uuid_str) {
            removed += 1;
        }
    }
    removed
}

/// Lightweight commit after incremental adds/removes.
/// Preserves node positions (no BFS layout, no pre-settle).
/// Use instead of `graph_engine_commit` for incremental topology changes.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_commit_incremental(engine: *mut Engine) {
    ffi_engine!(engine);
    engine.commit_incremental();
}

// ── Rendering ───────────────────────────────────────────────────────────────

/// Render one frame. Returns 1 if another frame is needed, 0 if GPU can idle.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_render(engine: *mut Engine, width: u32, height: u32) -> u32 {
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
pub extern "C" fn graph_engine_mouse_moved(engine: *mut Engine, screen_x: f32, screen_y: f32) {
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
pub extern "C" fn graph_engine_scroll(engine: *mut Engine, delta_x: f32, delta_y: f32) {
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
) {
    ffi_engine!(engine);
    engine.set_extended_force_params(velocity_decay, center_strength, collision_radius);
}

// ── Highlighting ────────────────────────────────────────────────────────────

/// Highlight a node and its neighbors (shift+click behavior).
/// `uuid`: null-terminated UTF-8 C string.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_highlight_neighbors(engine: *mut Engine, uuid: *const c_char) {
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
pub extern "C" fn graph_engine_search_highlight(engine: *mut Engine, query: *const c_char) {
    ffi_engine!(engine);
    let query_str = ffi_cstr!(query);
    engine.search_highlight(query_str);
}

/// Poll haptic event flag from the simulation.
/// Returns 0=None, 1=Light (alignment snap), 2=Heavy (collision).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_poll_haptic(engine: *mut Engine) -> u8 {
    ffi_engine_or!(engine, 0);
    engine.poll_haptic()
}

/// Enable/disable bullet-time search physics (slow-motion drift during search).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_search_active(engine: *mut Engine, active: u8) {
    ffi_engine!(engine);
    engine.set_search_active(active != 0);
}

/// Update laboratory physics toggles and tuning knobs.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_lab_params(
    engine: *mut Engine,
    enable_fluid: u8,
    enable_torsion: u8,
    enable_elastic: u8,
    enable_tension: u8,
    fluid_viscosity: f32,
    edge_elasticity: f32,
    torsion_rigidity: f32,
    boids_cohesion: f32,
    wind_x: f32,
    wind_y: f32,
    enable_orbital: u8,
    orbital_speed: f32,
) {
    ffi_engine!(engine);
    engine.set_lab_params(
        enable_fluid != 0,
        enable_torsion != 0,
        enable_elastic != 0,
        enable_tension != 0,
        fluid_viscosity,
        edge_elasticity,
        torsion_rigidity,
        boids_cohesion,
        wind_x,
        wind_y,
        enable_orbital != 0,
        orbital_speed,
    );
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
pub extern "C" fn graph_engine_center_on_node(engine: *mut Engine, uuid: *const c_char) {
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

/// User-controlled physics freeze: 1 = freeze (stop all forces), 0 = unfreeze (reheat).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_user_frozen(engine: *mut Engine, frozen: u8) {
    ffi_engine!(engine);
    engine.set_user_frozen(frozen != 0);
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

// ── Coordinate Conversion ───────────────────────────────────────────────────

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
        if !out_world_x.is_null() {
            *out_world_x = wx;
        }
        if !out_world_y.is_null() {
            *out_world_y = wy;
        }
    }
}

/// Get a node's screen pixel position by UUID.
/// Writes 2 floats (x, y) into `out`. Returns 1 if found, 0 if not.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_node_screen_pos(
    engine: *mut Engine,
    uuid: *const std::ffi::c_char,
    out: *mut f32,
) -> u8 {
    ffi_engine_or!(engine, 0);
    if uuid.is_null() || out.is_null() {
        return 0;
    }
    // SAFETY: `uuid` is a valid C string from Swift.
    let uuid_str = unsafe { std::ffi::CStr::from_ptr(uuid) };
    let Ok(uuid_str) = uuid_str.to_str() else {
        return 0;
    };
    let Some(pos) = engine.node_screen_pos(uuid_str) else {
        return 0;
    };
    // SAFETY: `out` points to caller-owned array of at least 2 floats.
    unsafe {
        *out.add(0) = pos[0];
        *out.add(1) = pos[1];
    }
    1
}

/// Get the cumulative drift (total distance traveled) for a node by UUID.
/// Returns the drift value, or -1.0 if the node isn't found.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_node_drift(
    engine: *mut Engine,
    uuid: *const std::ffi::c_char,
) -> f32 {
    ffi_engine_or!(engine, -1.0);
    if uuid.is_null() {
        return -1.0;
    }
    // SAFETY: `uuid` is a valid C string from Swift.
    let uuid_str = unsafe { std::ffi::CStr::from_ptr(uuid) };
    let Ok(uuid_str) = uuid_str.to_str() else {
        return -1.0;
    };
    engine.node_drift(uuid_str).unwrap_or(-1.0)
}

// ── Visibility (Lightweight Filtering) ──────────────────────────────────────

/// Toggle a node's visibility by UUID. Call `graph_engine_refresh_visibility`
/// once after all toggles to apply changes to renderer + simulation.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_node_visible(
    engine: *mut Engine,
    uuid: *const c_char,
    visible: u8,
) {
    ffi_engine!(engine);
    let uuid_str = ffi_cstr!(uuid);
    engine.set_node_visible(uuid_str, visible != 0);
}

/// Apply visibility changes: re-upload to renderer, reload simulation, reheat.
/// Preserves positions and velocities — lightweight alternative to full recommit.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_refresh_visibility(engine: *mut Engine) {
    ffi_engine!(engine);
    engine.refresh_visibility();
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

/// Set graph mode: 0 = global, 1 = page.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_mode(engine: *mut Engine, mode: u8) {
    ffi_engine!(engine);
    engine.set_mode(mode);
}

/// Set lite rendering mode: 0 = full (3D, effects), 1 = lite (2D flat, no glow).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_lite_mode(engine: *mut Engine, enabled: u8) {
    ffi_engine!(engine);
    engine.set_lite_mode(enabled != 0);
}

/// Set light/dark mode color palette: 0 = dark, 1 = light.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_light_mode(engine: *mut Engine, enabled: u8) {
    ffi_engine!(engine);
    engine.set_light_mode(enabled != 0);
}

/// Set quality level: 0 = Cinematic (full effects), 1 = Balanced (sphere shading, no glow/breathing),
/// 2 = Performance (flat circles). Replaces the binary lite_mode for finer control.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_quality_level(engine: *mut Engine, level: u8) {
    ffi_engine!(engine);
    engine.set_quality_level(level);
}

/// Set visual theme: 0 = Dialogue (default), 1 = Classic.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_visual_theme(engine: *mut Engine, theme: u8) {
    ffi_engine!(engine);
    engine.set_visual_theme(theme);
}

/// Set per-node color override by UUID. Pass alpha=0 to clear the override.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_node_color_override(
    engine: *mut Engine,
    uuid: *const c_char,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
) {
    ffi_engine!(engine);
    let uuid_str = ffi_cstr!(uuid);
    engine.set_node_color_override(uuid_str, r, g, b, a);
}

// ── 3D Orbit Camera ────────────────────────────────────────────────────────

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

/// Check if physics is completely disabled (static layout for large graphs).
/// Returns 1 if static (physics off), 0 if physics is active.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_is_static_layout(engine: *mut Engine) -> u8 {
    ffi_engine_or!(engine, 0);
    u8::from(engine.is_static_layout())
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

// ── Search ──────────────────────────────────────────────────────────────────

/// Search node labels with fuzzy matching. Returns a C array of results.
/// Caller must free with `graph_engine_free_search_results`.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_search(
    engine: *mut Engine,
    query: *const c_char,
    limit: u32,
    out_count: *mut u32,
) -> *mut search::SearchResult {
    ffi_engine_or!(engine, std::ptr::null_mut());
    let query_str = ffi_cstr!(query);

    let results = engine.search_index.search(query_str, limit as usize);

    unsafe {
        if !out_count.is_null() {
            *out_count = results.len() as u32;
        }
    }

    if results.is_empty() {
        return std::ptr::null_mut();
    }

    let ffi_results: Vec<search::SearchResult> = results
        .into_iter()
        .map(|(uuid, label, node_type, score)| search::SearchResult {
            uuid: CString::new(uuid).unwrap_or_default().into_raw(),
            label: CString::new(label).unwrap_or_default().into_raw(),
            node_type,
            score,
        })
        .collect();

    // into_boxed_slice guarantees capacity == len, avoiding UB in from_raw_parts.
    Box::into_raw(ffi_results.into_boxed_slice()) as *mut search::SearchResult
}

/// Free search results allocated by `graph_engine_search`.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_free_search_results(results: *mut search::SearchResult, count: u32) {
    if results.is_null() {
        return;
    }
    // SAFETY: `results` and `count` were produced by `graph_engine_search` /
    // `graph_engine_search_semantic` via `Box::into_raw(boxed_slice)`.
    unsafe {
        let slice: &mut [search::SearchResult] =
            std::slice::from_raw_parts_mut(results, count as usize);
        for result in slice.iter() {
            if !result.uuid.is_null() {
                let _ = CString::from_raw(result.uuid as *mut _);
            }
            if !result.label.is_null() {
                let _ = CString::from_raw(result.label as *mut _);
            }
        }
        // Reconstruct the boxed slice and drop it to free the allocation.
        let to_drop: *mut [search::SearchResult] =
            std::ptr::slice_from_raw_parts_mut(results, count as usize);
        drop(Box::from_raw(to_drop));
    }
}

// ── Semantic Clustering ─────────────────────────────────────────────────────

/// Set semantic cluster IDs from Swift. Maps UUIDs to simulation indices
/// and overrides the Louvain-detected cluster_ids.
/// After setting, the existing force_cluster() will use these IDs.
///
/// `uuids`: array of `count` null-terminated UUID C strings.
/// `cluster_ids`: parallel array of `count` cluster IDs.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_cluster_ids(
    engine: *mut Engine,
    uuids: *const *const c_char,
    cluster_ids: *const u32,
    count: u32,
) {
    ffi_engine!(engine);
    let count = count as usize;
    if count == 0 || uuids.is_null() || cluster_ids.is_null() {
        return;
    }

    let uuid_ptrs = unsafe { std::slice::from_raw_parts(uuids, count) };
    let ids = unsafe { std::slice::from_raw_parts(cluster_ids, count) };

    // Build UUID → cluster_id map.
    let mut uuid_to_cluster = std::collections::HashMap::new();
    for i in 0..count {
        if uuid_ptrs[i].is_null() {
            continue;
        }
        let uuid_str = unsafe { CStr::from_ptr(uuid_ptrs[i]) }
            .to_str()
            .unwrap_or("")
            .to_owned();
        uuid_to_cluster.insert(uuid_str, ids[i]);
    }

    engine.set_cluster_ids(&uuid_to_cluster);
}

// ── Embeddings ──────────────────────────────────────────────────────────────

/// Set the embedding vector for a node (identified by UUID).
/// `data`: pointer to `dim` contiguous f32 values.
/// `dim`: dimension of the embedding (must match store dimension, typically 512).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_node_embedding(
    engine: *mut Engine,
    uuid: *const c_char,
    data: *const f32,
    dim: u32,
) {
    ffi_engine!(engine);
    let uuid_str = ffi_cstr!(uuid);
    if data.is_null() || dim == 0 {
        return;
    }
    let slice = unsafe { std::slice::from_raw_parts(data, dim as usize) };
    if let Some(idx) = engine.node_index_by_uuid(uuid_str) {
        engine.embedding_store.set(idx as u32, slice);
    }
}

/// Recompute the semantic neighbor pairs (KNN) from current embeddings.
/// Call this after batch-setting embeddings. The pairs are used by the
/// semantic attraction force each physics tick.
///
/// `k`: number of neighbors per node (typically 8).
/// `threshold`: minimum cosine similarity to include (typically 0.3).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_recompute_semantic_neighbors(
    engine: *mut Engine,
    k: u32,
    threshold: f32,
) {
    ffi_engine!(engine);
    engine.semantic_neighbors = engine.embedding_store.all_knn_pairs(k as usize, threshold);
    // Reheat physics so the new attraction forces take effect.
    engine.reheat();
}

/// Set semantic attraction strength (0 = off, 1 = strong).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_semantic_strength(engine: *mut Engine, strength: f32) {
    ffi_engine!(engine);
    engine.set_semantic_strength(strength);
}

// ── Temporal Index ──────────────────────────────────────────────────────────

/// Set timestamps for a node by UUID (Unix epoch seconds).
/// Pass 0.0 for created_at or updated_at to leave unset.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_node_time(
    engine: *mut Engine,
    uuid: *const c_char,
    created_at: f64,
    updated_at: f64,
) {
    ffi_engine!(engine);
    let uuid_str = ffi_cstr!(uuid);
    engine.set_node_time(uuid_str, created_at, updated_at);
}

/// Apply a time filter: nodes with created_at outside [min_ts, max_ts] become invisible.
/// Nodes with created_at == 0.0 (no timestamp) remain always visible.
/// Pass (0.0, very large number) to clear the filter.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_time_filter(engine: *mut Engine, min_ts: f64, max_ts: f64) {
    ffi_engine!(engine);
    engine.set_time_filter(min_ts, max_ts);
}

// ── Confidence ─────────────────────────────────────────────────────────────

/// Set a node's confidence score (0.0–1.0) from enrichment pipeline.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_node_confidence(
    engine: *mut Engine,
    uuid: *const c_char,
    confidence: f32,
) {
    ffi_engine!(engine);
    let uuid_str = ffi_cstr!(uuid);
    engine.set_node_confidence(uuid_str, confidence);
}

/// Semantic search: find nodes most similar to a query embedding.
/// Returns a C array of SearchResult (same type as text search).
/// Caller must free with `graph_engine_free_search_results`.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_semantic_search(
    engine: *mut Engine,
    query_data: *const f32,
    dim: u32,
    limit: u32,
    out_count: *mut u32,
) -> *mut search::SearchResult {
    ffi_engine_or!(engine, std::ptr::null_mut());
    if query_data.is_null() || dim == 0 {
        unsafe {
            if !out_count.is_null() {
                *out_count = 0;
            }
        }
        return std::ptr::null_mut();
    }

    let query_vec = unsafe { std::slice::from_raw_parts(query_data, dim as usize) };
    let hits = engine
        .embedding_store
        .search(query_vec, limit as usize, 0.0);

    unsafe {
        if !out_count.is_null() {
            *out_count = hits.len() as u32;
        }
    }

    if hits.is_empty() {
        return std::ptr::null_mut();
    }

    let ffi_results: Vec<search::SearchResult> = hits
        .into_iter()
        .filter_map(|hit| {
            let node = engine.graph().nodes.get(hit.node_index as usize)?;
            Some(search::SearchResult {
                uuid: CString::new(node.uuid.as_str())
                    .unwrap_or_default()
                    .into_raw(),
                label: CString::new(node.label.as_str())
                    .unwrap_or_default()
                    .into_raw(),
                node_type: node.node_type as u8,
                score: hit.similarity,
            })
        })
        .collect();

    Box::into_raw(ffi_results.into_boxed_slice()) as *mut search::SearchResult
}

// ── Version Chain ──────────────────────────────────────────────────────────

/// Add a version to a node's hash-linked version chain.
/// Returns 1 on success, 0 if orphan/duplicate rejected.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_add_version(
    engine: *mut Engine,
    node_uuid: *const c_char,
    hash: u64,
    parent_hash: u64,
    timestamp: f64,
) -> u8 {
    ffi_engine_or!(engine, 0);
    let uuid = ffi_cstr!(node_uuid);
    if engine
        .version_store
        .add_version(uuid, hash, parent_hash, timestamp)
    {
        1
    } else {
        0
    }
}

/// Get the number of versions in a node's chain.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_get_version_count(
    engine: *mut Engine,
    node_uuid: *const c_char,
) -> u32 {
    ffi_engine_or!(engine, 0);
    let uuid = ffi_cstr!(node_uuid);
    engine.version_store.version_count(uuid)
}

// ── Block Transaction Kernel (BTK) ───────────────────────────────────────────

/// Initialize BTK for a page. Call once when a page is opened.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_init(engine: *mut Engine, page_id: *const c_char) -> u8 {
    ffi_engine_or!(engine, 0);
    let page_id = ffi_cstr!(page_id);
    if page_id.is_empty() {
        return 0;
    }

    engine
        .btk_trees
        .entry(page_id.to_string())
        .or_insert_with(block_kernel::BlockTree::new);
    engine
        .btk_logs
        .entry(page_id.to_string())
        .or_insert_with(block_kernel::op_log::OpLog::new);
    1
}

/// BlockFFI struct for loading existing blocks from Swift
#[repr(C)]
pub struct BlockFFI {
    pub id: [u8; 16],        // UUID as 16 bytes
    pub parent_id: [u8; 16], // Zero = no parent
    pub content_ptr: *const c_char,
    pub depth: u16,
    pub order: u32,
}

/// Load existing blocks from Swift (migration from SDBlock).
/// blocks_ptr is a pointer to an array of BlockFFI structs.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_load_blocks(
    engine: *mut Engine,
    page_id: *const c_char,
    blocks_ptr: *const BlockFFI,
    count: u32,
) -> u8 {
    ffi_engine_or!(engine, 0);
    let page_id_str = ffi_cstr!(page_id);
    if page_id_str.is_empty() || blocks_ptr.is_null() {
        return 0;
    }

    let tree = engine
        .btk_trees
        .entry(page_id_str.to_string())
        .or_insert_with(block_kernel::BlockTree::new);
    let log = engine
        .btk_logs
        .entry(page_id_str.to_string())
        .or_insert_with(block_kernel::op_log::OpLog::new);

    // SAFETY: Swift passes a valid array of `count` BlockFFI structs.
    let blocks = unsafe { std::slice::from_raw_parts(blocks_ptr, count as usize) };

    for b in blocks {
        let content = if b.content_ptr.is_null() {
            String::new()
        } else {
            // SAFETY: Swift passes a valid null-terminated UTF-8 string; lifetime spans this loop iteration.
            unsafe { CStr::from_ptr(b.content_ptr) }
                .to_str()
                .unwrap_or("")
                .to_string()
        };

        let block_id = block_kernel::BlockId(b.id);
        let parent_id = if b.parent_id == [0u8; 16] {
            None
        } else {
            Some(block_kernel::BlockId(b.parent_id))
        };

        let op = block_kernel::Op::InsertBlock {
            block_id,
            parent_id,
            position: b.order,
            content,
            depth: b.depth,
        };
        tree.apply(&op);
        log.append(op);
    }

    1
}

/// Translate a text edit into block ops and apply them.
/// Returns the number of ops applied.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_translate_edit(
    engine: *mut Engine,
    page_id: *const c_char,
    edit_offset: u32,
    old_length: u32,
    new_text: *const c_char,
) -> u32 {
    ffi_engine_or!(engine, 0);
    let page_id_str = ffi_cstr!(page_id);
    let new_text_str = ffi_cstr!(new_text);

    let ops = {
        let tree = match engine.btk_trees.get(page_id_str) {
            Some(t) => t,
            None => return 0,
        };
        block_kernel::translator::translate_edit(tree, edit_offset, old_length, new_text_str)
    };

    let count = ops.len() as u32;

    // Apply ops to both tree and log
    if let Some(tree) = engine.btk_trees.get_mut(page_id_str) {
        if let Some(log) = engine.btk_logs.get_mut(page_id_str) {
            for op in ops {
                tree.apply(&op);
                log.append(op);
            }
        }
    }

    count
}

/// Get the current markdown projection for a page.
/// Returns a C string that must be freed with graph_engine_free_string.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_get_markdown(
    engine: *mut Engine,
    page_id: *const c_char,
) -> *const c_char {
    ffi_engine_or!(engine, std::ptr::null());
    let page_id_str = ffi_cstr!(page_id);

    let tree = match engine.btk_trees.get(page_id_str) {
        Some(t) => t,
        None => return std::ptr::null(),
    };

    let md = block_kernel::projection::project(tree);
    match CString::new(md) {
        Ok(cs) => cs.into_raw(),
        Err(_) => std::ptr::null(),
    }
}

/// Free a string returned by graph_engine_btk_get_markdown.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_free_string(s: *mut c_char) {
    if !s.is_null() {
        // SAFETY: `s` was allocated by CString::into_raw in graph_engine_btk_get_markdown.
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}

/// Directly update a block's content by block_id (16-byte UUID).
/// Used for transclusion edits where the block may belong to a different page.
/// Returns 1 on success, 0 on failure.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_update_block(
    engine: *mut Engine,
    page_id: *const c_char,
    block_id_bytes: *const u8,
    new_content: *const c_char,
) -> u8 {
    ffi_engine_or!(engine, 0);
    let page_id_str = ffi_cstr!(page_id);
    if page_id_str.is_empty() || block_id_bytes.is_null() {
        return 0;
    }
    let content_str = ffi_cstr!(new_content);

    // SAFETY: block_id_bytes points to 16 bytes from Swift.
    let mut id_arr = [0u8; 16];
    unsafe {
        std::ptr::copy_nonoverlapping(block_id_bytes, id_arr.as_mut_ptr(), 16);
    }
    let block_id = block_kernel::op::BlockId(id_arr);

    let op = block_kernel::op::Op::UpdateBlock {
        block_id,
        content: content_str.to_string(),
    };

    if let Some(tree) = engine.btk_trees.get_mut(page_id_str) {
        tree.apply(&op);
        if let Some(log) = engine.btk_logs.get_mut(page_id_str) {
            log.append(op);
        }
        1
    } else {
        0
    }
}

// ── BTK Queries ─────────────────────────────────────────────────────────────

/// Query all BTK trees for blocks matching a property filter.
/// Returns newline-separated page_ids that contain at least one matching block.
/// Result must be freed with graph_engine_free_string.
/// op: 0=eq, 1=neq, 2=lt, 3=gt, 4=lte, 5=gte, 6=contains
/// val_type: 0=string, 1=float, 2=int, 3=bool
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_query_property(
    engine: *mut Engine,
    key: *const c_char,
    op: u8,
    val_type: u8,
    val_str: *const c_char,
) -> *const c_char {
    ffi_engine_or!(engine, std::ptr::null());
    let key_str = ffi_cstr!(key);
    let val_raw = ffi_cstr!(val_str);

    let value = match val_type {
        0 => block_kernel::op::PropertyValue::String(val_raw.to_string()),
        1 => match val_raw.parse::<f32>() {
            Ok(f) => block_kernel::op::PropertyValue::Float(f),
            Err(_) => return std::ptr::null(),
        },
        2 => match val_raw.parse::<i64>() {
            Ok(i) => block_kernel::op::PropertyValue::Int(i),
            Err(_) => return std::ptr::null(),
        },
        3 => block_kernel::op::PropertyValue::Bool(val_raw == "true"),
        _ => return std::ptr::null(),
    };

    let mut matching_pages = Vec::new();
    for (page_id, tree) in &engine.btk_trees {
        if tree.has_matching_property(key_str, op, &value) {
            matching_pages.push(page_id.clone());
        }
    }

    if matching_pages.is_empty() {
        return std::ptr::null();
    }

    let result = matching_pages.join("\n");
    match CString::new(result) {
        Ok(cs) => cs.into_raw(),
        Err(_) => std::ptr::null(),
    }
}

/// Query all BTK trees for blocks matching a depth filter.
/// Returns newline-separated page_ids that contain at least one matching block.
/// Result must be freed with graph_engine_free_string.
/// op: 0=eq, 1=neq, 2=lt, 3=gt, 4=lte, 5=gte
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_query_depth(
    engine: *mut Engine,
    op: u8,
    depth: u32,
) -> *const c_char {
    ffi_engine_or!(engine, std::ptr::null());

    let depth16 = depth.min(u16::MAX as u32) as u16;
    let mut matching_pages = Vec::new();
    for (page_id, tree) in &engine.btk_trees {
        if tree.has_matching_depth(op, depth16) {
            matching_pages.push(page_id.clone());
        }
    }

    if matching_pages.is_empty() {
        return std::ptr::null();
    }

    let result = matching_pages.join("\n");
    match CString::new(result) {
        Ok(cs) => cs.into_raw(),
        Err(_) => std::ptr::null(),
    }
}

// ── Dialogue ────────────────────────────────────────────────────────────────

/// Open dialogue on a node (activates face geometry + dialogue box).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_dialogue_open(engine: *mut Engine, node_uuid: *const c_char) {
    ffi_engine!(engine);
    let uuid = ffi_cstr!(node_uuid);
    engine.dialogue_open(uuid);
}

/// Close dialogue (deactivates face + box).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_dialogue_close(engine: *mut Engine) {
    ffi_engine!(engine);
    engine.dialogue_close();
}

/// Set streaming state (animates mouth when true).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_dialogue_set_streaming(engine: *mut Engine, streaming: u8) {
    ffi_engine!(engine);
    engine.dialogue_set_streaming(streaming != 0);
}

/// Get dialogue box screen rect (x, y, w, h) for SwiftUI overlay positioning.
/// Writes 4 floats into `out`.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_dialogue_screen_rect(engine: *mut Engine, out: *mut f32) {
    ffi_engine!(engine);
    if out.is_null() {
        return;
    }
    let rect = engine.dialogue_screen_rect();
    // SAFETY: `out` points to caller-owned array of at least 4 floats.
    unsafe {
        *out.add(0) = rect[0];
        *out.add(1) = rect[1];
        *out.add(2) = rect[2];
        *out.add(3) = rect[3];
    }
}

/// Get dialogue node screen position (x, y).
/// Writes 2 floats into `out`.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_dialogue_node_screen_pos(engine: *mut Engine, out: *mut f32) {
    ffi_engine!(engine);
    if out.is_null() {
        return;
    }
    let pos = engine.dialogue_node_screen_pos();
    // SAFETY: `out` points to caller-owned array of at least 2 floats.
    unsafe {
        *out.add(0) = pos[0];
        *out.add(1) = pos[1];
    }
}

/// Check if dialogue is currently active.
/// Returns 1 if active, 0 if not.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_dialogue_is_active(engine: *mut Engine) -> u8 {
    ffi_engine_or!(engine, 0);
    u8::from(engine.dialogue_is_active())
}
