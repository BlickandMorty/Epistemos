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
pub mod search;
pub mod embedding;
pub mod version;

// ── FFI Boundary ────────────────────────────────────────────────────────────
//
// Every function below is called from Swift via the C bridge header.
// Convention: all functions take `*mut engine::Engine` as the first argument.
// All pointer arguments are null-checked before dereference.

use std::ffi::{c_char, c_void, CStr, CString};

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
) {
    ffi_engine!(engine);
    engine.set_extended_force_params(velocity_decay, center_strength, collision_radius);
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
        if !out_world_x.is_null() { *out_world_x = wx; }
        if !out_world_y.is_null() { *out_world_y = wy; }
    }
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

    let mut ffi_results: Vec<search::SearchResult> = results
        .into_iter()
        .map(|(uuid, label, node_type, score)| search::SearchResult {
            uuid: CString::new(uuid).unwrap_or_default().into_raw(),
            label: CString::new(label).unwrap_or_default().into_raw(),
            node_type,
            score,
        })
        .collect();

    ffi_results.shrink_to_fit(); // Ensure capacity == len for safe Vec::from_raw_parts in free
    let ptr = ffi_results.as_mut_ptr();
    std::mem::forget(ffi_results);
    ptr
}

/// Free search results allocated by `graph_engine_search`.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_free_search_results(
    results: *mut search::SearchResult,
    count: u32,
) {
    if results.is_null() {
        return;
    }
    unsafe {
        let slice = std::slice::from_raw_parts_mut(results, count as usize);
        for result in slice.iter() {
            if !result.uuid.is_null() {
                let _ = CString::from_raw(result.uuid as *mut _);
            }
            if !result.label.is_null() {
                let _ = CString::from_raw(result.label as *mut _);
            }
        }
        let _ = Vec::from_raw_parts(results, count as usize, count as usize);
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
    engine.semantic_neighbors = engine
        .embedding_store
        .all_knn_pairs(k as usize, threshold);
    // Reheat physics so the new attraction forces take effect.
    engine.reheat();
}

/// Set semantic attraction strength (0 = off, 1 = strong).
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_semantic_strength(
    engine: *mut Engine,
    strength: f32,
) {
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
pub extern "C" fn graph_engine_set_time_filter(
    engine: *mut Engine,
    min_ts: f64,
    max_ts: f64,
) {
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

    let mut ffi_results: Vec<search::SearchResult> = hits
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

    ffi_results.shrink_to_fit(); // Ensure capacity == len for safe Vec::from_raw_parts in free
    let ptr = ffi_results.as_mut_ptr();
    std::mem::forget(ffi_results);
    ptr
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
    if engine.version_store.add_version(uuid, hash, parent_hash, timestamp) {
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
