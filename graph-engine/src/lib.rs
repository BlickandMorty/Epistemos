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
pub mod knowledge_core;
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
use crate::knowledge_core::archived::SubscriptionKind as KnowledgeSubscriptionKind;
use crate::knowledge_core::{
    DocumentFormat, KnowledgeCore, KnowledgeCoreBackpressurePolicy, KnowledgeCoreError,
    KnowledgeCoreErrorCode,
};

#[repr(C)]
pub struct GraphEngineByteBuffer {
    /// Pointer to an owned byte region allocated by Rust.
    pub ptr: *mut u8,
    /// Number of initialized bytes available at `ptr`.
    pub len: u64,
    /// Allocation capacity for reconstructing the Rust Vec during free.
    pub capacity: u64,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct GraphEngineStringSlice {
    /// Borrowed UTF-8 pointer into an archived payload buffer.
    pub ptr: *const u8,
    /// Byte length of the borrowed string.
    pub len: u32,
}

#[repr(C)]
pub struct GraphEngineSharedMemoryRegion {
    /// Base pointer of a mapped shared-memory region owned by Rust.
    pub ptr: *mut u8,
    /// Total mapped byte length.
    pub len: u64,
}

#[repr(C)]
pub struct GraphEngineRingLayout {
    pub head_offset: u64,
    pub tail_offset: u64,
    pub slots_offset: u64,
    pub slot_stride: u64,
    pub slot_payload_offset: u64,
    pub slot_count: u32,
    pub slot_payload_bytes: u32,
}

#[repr(C)]
pub struct BtkSubscriptionRowFFI {
    /// Page identifier for the row.
    pub page_id: GraphEngineStringSlice,
    /// Block identifier for the row.
    pub block_id: GraphEngineStringSlice,
    /// Parent block identifier when applicable.
    pub parent_id: GraphEngineStringSlice,
    /// Linked target identifier when applicable.
    pub target_id: GraphEngineStringSlice,
    /// Block content for outline/link rows.
    pub content: GraphEngineStringSlice,
    /// Property key for property rows.
    pub property_key: GraphEngineStringSlice,
    /// Property value for property rows.
    pub property_value: GraphEngineStringSlice,
    /// Task marker such as TODO or DONE.
    pub task_marker: GraphEngineStringSlice,
    /// Fractional sort key or block order key.
    pub order_key: GraphEngineStringSlice,
    /// Outline depth for hierarchical rows.
    pub depth: u16,
    /// Link reference type when the row comes from a link traversal.
    pub ref_type: u8,
    /// Nonzero when the task is completed.
    pub task_done: u8,
    /// Traversal hop count for link rows.
    pub hop_count: u8,
}

#[repr(C)]
pub struct KnowledgeQueryRowFFI {
    /// 0=block, 1=task, 2=property, 3=link.
    pub row_kind: u8,
    pub _pad: [u8; 3],
    pub page_id: GraphEngineStringSlice,
    pub block_id: GraphEngineStringSlice,
    pub parent_id: GraphEngineStringSlice,
    pub target_id: GraphEngineStringSlice,
    pub content: GraphEngineStringSlice,
    pub property_key: GraphEngineStringSlice,
    pub property_value: GraphEngineStringSlice,
    pub task_marker: GraphEngineStringSlice,
    pub order_key: GraphEngineStringSlice,
    pub depth: u16,
    pub ref_type: u8,
    pub task_done: u8,
}

#[repr(C)]
pub struct KnowledgePayloadSummaryFFI {
    pub tx_id: u64,
    pub subscription_id: u64,
    /// 0=outline, 1=tasks, 2=properties, 3=links, 255=invalid.
    pub kind: u8,
    pub _pad: [u8; 3],
    pub added_count: u32,
    pub updated_count: u32,
    pub removed_count: u32,
}

#[repr(C)]
pub struct KnowledgeCoreTransportStatsFFI {
    pub published_frames: u64,
    pub dropped_frames: u64,
    pub coalesced_frames: u64,
    pub ring_full_failures: u64,
}

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

fn empty_byte_buffer() -> GraphEngineByteBuffer {
    GraphEngineByteBuffer {
        ptr: std::ptr::null_mut(),
        len: 0,
        capacity: 0,
    }
}

fn empty_shared_region() -> GraphEngineSharedMemoryRegion {
    GraphEngineSharedMemoryRegion {
        ptr: std::ptr::null_mut(),
        len: 0,
    }
}

fn byte_buffer_from_vec(mut bytes: Vec<u8>) -> GraphEngineByteBuffer {
    let buffer = GraphEngineByteBuffer {
        ptr: bytes.as_mut_ptr(),
        len: bytes.len() as u64,
        capacity: bytes.capacity() as u64,
    };
    std::mem::forget(bytes);
    buffer
}

fn sync_btk_query_kernel(engine: &mut Engine, page_id: &str) {
    if let (Some(tree), Some(log)) = (engine.btk_trees.get(page_id), engine.btk_logs.get(page_id)) {
        engine.btk_query_kernel.sync_page(page_id, tree, log);
    }
}

fn with_subscription_payload<T>(
    data: *const u8,
    len: u64,
    f: impl FnOnce(&crate::block_kernel::query_kernel::ArchivedSubscriptionPayload) -> T,
) -> Option<T> {
    if data.is_null() || len == 0 {
        return None;
    }
    // SAFETY: Caller provides a stable byte slice produced by graph_engine_btk_*_subscription().
    let bytes = unsafe { std::slice::from_raw_parts(data, len as usize) };
    let payload = rkyv::access::<
        crate::block_kernel::query_kernel::ArchivedSubscriptionPayload,
        rkyv::rancor::Error,
    >(bytes)
    .ok()?;
    Some(f(payload))
}

fn with_knowledge_payload<T>(
    data: *const u8,
    len: u64,
    f: impl FnOnce(&crate::knowledge_core::archived::ArchivedQueryDiffEnvelope) -> T,
) -> Option<T> {
    if data.is_null() || len == 0 {
        return None;
    }
    // SAFETY: Caller provides a stable byte slice from a mapped ring slot or
    // a Rust-owned archived payload. `rkyv::access` validates the archive
    // before producing the borrowed view.
    let bytes = unsafe { std::slice::from_raw_parts(data, len as usize) };
    let payload = rkyv::access::<
        crate::knowledge_core::archived::ArchivedQueryDiffEnvelope,
        rkyv::rancor::Error,
    >(bytes)
    .ok()?;
    Some(f(payload))
}

fn fill_string_slice(out: &mut GraphEngineStringSlice, value: &str) {
    out.ptr = value.as_ptr();
    out.len = value.len() as u32;
}

fn clear_string_slice(out: &mut GraphEngineStringSlice) {
    out.ptr = std::ptr::null();
    out.len = 0;
}

fn string_slice(value: &str) -> GraphEngineStringSlice {
    GraphEngineStringSlice {
        ptr: value.as_ptr(),
        len: value.len() as u32,
    }
}

fn empty_string_slice() -> GraphEngineStringSlice {
    GraphEngineStringSlice {
        ptr: std::ptr::null(),
        len: 0,
    }
}

fn kc_fail_with(core: &mut KnowledgeCore, code: KnowledgeCoreErrorCode, message: &str) -> u8 {
    core.set_last_error(code, message);
    0
}

fn kc_finish_result(core: &mut KnowledgeCore, result: Result<(), KnowledgeCoreError>) -> u8 {
    match result {
        Ok(()) => {
            core.clear_last_error();
            1
        }
        Err(error) => {
            core.set_last_error_from(&error);
            0
        }
    }
}

fn kc_finish_subscription(
    core: &mut KnowledgeCore,
    result: Result<u64, KnowledgeCoreError>,
) -> u64 {
    match result {
        Ok(subscription_id) => {
            core.clear_last_error();
            subscription_id
        }
        Err(error) => {
            core.set_last_error_from(&error);
            0
        }
    }
}

fn archived_knowledge_kind_code(
    kind: &crate::knowledge_core::archived::ArchivedSubscriptionKind,
) -> u16 {
    match kind {
        crate::knowledge_core::archived::ArchivedSubscriptionKind::Outline => {
            KnowledgeSubscriptionKind::Outline.code()
        }
        crate::knowledge_core::archived::ArchivedSubscriptionKind::Tasks => {
            KnowledgeSubscriptionKind::Tasks.code()
        }
        crate::knowledge_core::archived::ArchivedSubscriptionKind::Properties => {
            KnowledgeSubscriptionKind::Properties.code()
        }
        crate::knowledge_core::archived::ArchivedSubscriptionKind::Links => {
            KnowledgeSubscriptionKind::Links.code()
        }
    }
}

fn reset_knowledge_summary(out: &mut KnowledgePayloadSummaryFFI) {
    out.tx_id = 0;
    out.subscription_id = 0;
    out.kind = u8::MAX;
    out._pad = [0; 3];
    out.added_count = 0;
    out.updated_count = 0;
    out.removed_count = 0;
}

fn reset_knowledge_row(out: &mut KnowledgeQueryRowFFI) {
    out.row_kind = u8::MAX;
    out._pad = [0; 3];
    clear_string_slice(&mut out.page_id);
    clear_string_slice(&mut out.block_id);
    clear_string_slice(&mut out.parent_id);
    clear_string_slice(&mut out.target_id);
    clear_string_slice(&mut out.content);
    clear_string_slice(&mut out.property_key);
    clear_string_slice(&mut out.property_value);
    clear_string_slice(&mut out.task_marker);
    clear_string_slice(&mut out.order_key);
    out.depth = 0;
    out.ref_type = 0;
    out.task_done = 0;
}

fn fill_knowledge_row_from_archived(
    out_row: &mut KnowledgeQueryRowFFI,
    archived_row: &crate::knowledge_core::archived::ArchivedQueryRow,
) {
    reset_knowledge_row(out_row);
    match archived_row {
        crate::knowledge_core::archived::ArchivedQueryRow::Block(row) => {
            out_row.row_kind = 0;
            fill_string_slice(&mut out_row.page_id, row.page_id.as_str());
            fill_string_slice(&mut out_row.block_id, row.block_id.as_str());
            fill_string_slice(&mut out_row.parent_id, row.parent_id.as_str());
            fill_string_slice(&mut out_row.order_key, row.order_key.as_str());
            fill_string_slice(&mut out_row.content, row.content.as_str());
            out_row.depth = row.depth.to_native();
        }
        crate::knowledge_core::archived::ArchivedQueryRow::Task(row) => {
            out_row.row_kind = 1;
            fill_string_slice(&mut out_row.page_id, row.page_id.as_str());
            fill_string_slice(&mut out_row.block_id, row.block_id.as_str());
            fill_string_slice(&mut out_row.task_marker, row.marker.as_str());
            out_row.task_done = u8::from(row.done);
        }
        crate::knowledge_core::archived::ArchivedQueryRow::Property(row) => {
            out_row.row_kind = 2;
            fill_string_slice(&mut out_row.page_id, row.page_id.as_str());
            fill_string_slice(&mut out_row.block_id, row.block_id.as_str());
            fill_string_slice(&mut out_row.property_key, row.key.as_str());
            fill_string_slice(&mut out_row.property_value, row.value.as_str());
        }
        crate::knowledge_core::archived::ArchivedQueryRow::Link(row) => {
            out_row.row_kind = 3;
            fill_string_slice(&mut out_row.page_id, row.page_id.as_str());
            fill_string_slice(&mut out_row.block_id, row.block_id.as_str());
            fill_string_slice(&mut out_row.target_id, row.target_id.as_str());
            out_row.ref_type = row.ref_type;
        }
    }
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

/// Set quality level: 0 = Cinematic (full effects), 1 = Balanced (static depth, no glow/breathing),
/// 2 = Performance (straight edges, lighter static shading). Replaces the binary lite_mode.
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

/// Batch-set node timestamps + confidence from parallel arrays.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_set_node_metadata_batch(
    engine: *mut Engine,
    uuids: *const *const c_char,
    created_ats: *const f64,
    updated_ats: *const f64,
    confidences: *const f32,
    count: u32,
) {
    ffi_engine!(engine);
    let count = count as usize;
    if count == 0
        || uuids.is_null()
        || created_ats.is_null()
        || updated_ats.is_null()
        || confidences.is_null()
    {
        return;
    }

    // SAFETY: caller guarantees parallel arrays of `count` items.
    let uuid_ptrs = unsafe { std::slice::from_raw_parts(uuids, count) };
    // SAFETY: caller guarantees parallel arrays of `count` items.
    let created = unsafe { std::slice::from_raw_parts(created_ats, count) };
    // SAFETY: caller guarantees parallel arrays of `count` items.
    let updated = unsafe { std::slice::from_raw_parts(updated_ats, count) };
    // SAFETY: caller guarantees parallel arrays of `count` items.
    let confidences = unsafe { std::slice::from_raw_parts(confidences, count) };

    for i in 0..count {
        let uuid_str = if uuid_ptrs[i].is_null() {
            ""
        } else {
            // SAFETY: caller guarantees null-terminated UTF-8 strings.
            unsafe { CStr::from_ptr(uuid_ptrs[i]) }
                .to_str()
                .unwrap_or("")
        };
        engine.set_node_metadata(uuid_str, created[i], updated[i], confidences[i]);
    }
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

    sync_btk_query_kernel(engine, page_id_str);

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

    sync_btk_query_kernel(engine, page_id_str);

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
        sync_btk_query_kernel(engine, page_id_str);
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

/// Free a byte buffer returned by graph_engine_btk_take_subscription_update or snapshot APIs.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_free_bytes(buffer: GraphEngineByteBuffer) {
    if buffer.ptr.is_null() || buffer.capacity == 0 {
        return;
    }
    // SAFETY: Buffer originates from Vec::into_raw_parts-equivalent in byte_buffer_from_vec.
    unsafe {
        let _ = Vec::from_raw_parts(buffer.ptr, buffer.len as usize, buffer.capacity as usize);
    }
}

// ── Knowledge Core (Shared-Memory Reactive FFI) ────────────────────────────

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_create(
    slot_count: u32,
    slot_payload_bytes: u32,
    peer_id: u64,
) -> *mut KnowledgeCore {
    match KnowledgeCore::new(slot_count as usize, slot_payload_bytes as usize, peer_id) {
        Ok(core) => Box::into_raw(Box::new(core)),
        Err(_) => std::ptr::null_mut(),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_destroy(core: *mut KnowledgeCore) {
    if !core.is_null() {
        unsafe {
            drop(Box::from_raw(core));
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_ring_region(
    core: *mut KnowledgeCore,
) -> GraphEngineSharedMemoryRegion {
    if core.is_null() {
        return empty_shared_region();
    }
    let core = unsafe { &mut *core };
    let region = core.shared_region();
    GraphEngineSharedMemoryRegion {
        ptr: region.ptr,
        len: region.len,
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_ring_layout(core: *mut KnowledgeCore) -> GraphEngineRingLayout {
    if core.is_null() {
        return GraphEngineRingLayout {
            head_offset: 0,
            tail_offset: 0,
            slots_offset: 0,
            slot_stride: 0,
            slot_payload_offset: 0,
            slot_count: 0,
            slot_payload_bytes: 0,
        };
    }
    let core = unsafe { &mut *core };
    let layout = core.ring_layout();
    GraphEngineRingLayout {
        head_offset: layout.head_offset,
        tail_offset: layout.tail_offset,
        slots_offset: layout.slots_offset,
        slot_stride: layout.slot_stride,
        slot_payload_offset: layout.slot_payload_offset,
        slot_count: layout.slot_count,
        slot_payload_bytes: layout.slot_payload_bytes,
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_ring_head(core: *mut KnowledgeCore) -> u64 {
    if core.is_null() {
        return 0;
    }
    let core = unsafe { &mut *core };
    core.load_head()
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_ring_tail(core: *mut KnowledgeCore) -> u64 {
    if core.is_null() {
        return 0;
    }
    let core = unsafe { &mut *core };
    core.load_tail()
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_ring_set_tail(core: *mut KnowledgeCore, tail: u64) {
    if core.is_null() {
        return;
    }
    let core = unsafe { &mut *core };
    core.store_tail(tail);
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_subscribe_outline(
    core: *mut KnowledgeCore,
    page_id: *const c_char,
) -> u64 {
    if core.is_null() {
        return 0;
    }
    let core = unsafe { &mut *core };
    let page_id = ffi_cstr!(page_id);
    if page_id.is_empty() {
        core.set_last_error(
            KnowledgeCoreErrorCode::InvalidArgument,
            "outline subscriptions require a non-empty page id",
        );
        return 0;
    }
    let result = core.subscribe_outline(page_id);
    kc_finish_subscription(core, result)
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_subscribe_tasks(
    core: *mut KnowledgeCore,
    page_id: *const c_char,
) -> u64 {
    if core.is_null() {
        return 0;
    }
    let core = unsafe { &mut *core };
    let page_id = if page_id.is_null() {
        None
    } else {
        Some(ffi_cstr!(page_id))
    };
    if matches!(page_id, Some("")) {
        core.set_last_error(
            KnowledgeCoreErrorCode::InvalidArgument,
            "task subscriptions use either nil or a non-empty page id",
        );
        return 0;
    }
    let result = core.subscribe_tasks(page_id);
    kc_finish_subscription(core, result)
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_subscribe_properties(
    core: *mut KnowledgeCore,
    page_id: *const c_char,
    key: *const c_char,
) -> u64 {
    if core.is_null() {
        return 0;
    }
    let core = unsafe { &mut *core };
    let page_id = if page_id.is_null() {
        None
    } else {
        Some(ffi_cstr!(page_id))
    };
    let key = if key.is_null() {
        None
    } else {
        Some(ffi_cstr!(key))
    };
    if matches!(page_id, Some("")) || matches!(key, Some("")) {
        core.set_last_error(
            KnowledgeCoreErrorCode::InvalidArgument,
            "property subscriptions use nil or non-empty page/key values",
        );
        return 0;
    }
    let result = core.subscribe_properties(page_id, key);
    kc_finish_subscription(core, result)
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_unsubscribe(
    core: *mut KnowledgeCore,
    subscription_id: u64,
) -> u8 {
    if core.is_null() {
        return 0;
    }
    let core = unsafe { &mut *core };
    if core.unsubscribe(subscription_id) {
        core.clear_last_error();
        1
    } else {
        kc_fail_with(
            core,
            KnowledgeCoreErrorCode::InvalidArgument,
            "subscription id was not registered",
        )
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_ingest_document(
    core: *mut KnowledgeCore,
    page_id: *const c_char,
    format: u8,
    text: *const c_char,
) -> u8 {
    if core.is_null() {
        return 0;
    }
    let Some(format) = DocumentFormat::from_ffi(format) else {
        let core = unsafe { &mut *core };
        return kc_fail_with(
            core,
            KnowledgeCoreErrorCode::InvalidArgument,
            "document format must be 0 (markdown) or 1 (org)",
        );
    };
    let core = unsafe { &mut *core };
    let page_id = ffi_cstr!(page_id);
    if page_id.is_empty() {
        return kc_fail_with(
            core,
            KnowledgeCoreErrorCode::InvalidArgument,
            "ingest_document requires a non-empty page id",
        );
    }
    let result = core.ingest_document(page_id, format, ffi_cstr!(text));
    kc_finish_result(core, result)
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_insert_block(
    core: *mut KnowledgeCore,
    page_id: *const c_char,
    block_id: *const c_char,
    parent_id: *const c_char,
    index: u32,
    content: *const c_char,
) -> u8 {
    if core.is_null() {
        return 0;
    }
    let core = unsafe { &mut *core };
    let page_id = ffi_cstr!(page_id);
    let block_id = ffi_cstr!(block_id);
    if page_id.is_empty() || block_id.is_empty() {
        return kc_fail_with(
            core,
            KnowledgeCoreErrorCode::InvalidArgument,
            "insert_block requires non-empty page and block ids",
        );
    }
    let parent = if parent_id.is_null() {
        None
    } else {
        Some(ffi_cstr!(parent_id))
    };
    if matches!(parent, Some("")) {
        return kc_fail_with(
            core,
            KnowledgeCoreErrorCode::InvalidArgument,
            "insert_block uses nil or a non-empty parent id",
        );
    }
    let result = core.insert_block(
        page_id,
        block_id,
        parent,
        index as usize,
        ffi_cstr!(content),
    );
    kc_finish_result(core, result)
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_move_block(
    core: *mut KnowledgeCore,
    page_id: *const c_char,
    block_id: *const c_char,
    new_parent_id: *const c_char,
    index: u32,
) -> u8 {
    if core.is_null() {
        return 0;
    }
    let core = unsafe { &mut *core };
    let page_id = ffi_cstr!(page_id);
    let block_id = ffi_cstr!(block_id);
    if page_id.is_empty() || block_id.is_empty() {
        return kc_fail_with(
            core,
            KnowledgeCoreErrorCode::InvalidArgument,
            "move_block requires non-empty page and block ids",
        );
    }
    let parent = if new_parent_id.is_null() {
        None
    } else {
        Some(ffi_cstr!(new_parent_id))
    };
    if matches!(parent, Some("")) {
        return kc_fail_with(
            core,
            KnowledgeCoreErrorCode::InvalidArgument,
            "move_block uses nil or a non-empty parent id",
        );
    }
    let result = core.move_block(page_id, block_id, parent, index as usize);
    kc_finish_result(core, result)
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_delete_block(
    core: *mut KnowledgeCore,
    page_id: *const c_char,
    block_id: *const c_char,
) -> u8 {
    if core.is_null() {
        return 0;
    }
    let core = unsafe { &mut *core };
    let page_id = ffi_cstr!(page_id);
    let block_id = ffi_cstr!(block_id);
    if page_id.is_empty() || block_id.is_empty() {
        return kc_fail_with(
            core,
            KnowledgeCoreErrorCode::InvalidArgument,
            "delete_block requires non-empty page and block ids",
        );
    }
    let result = core.delete_block(page_id, block_id);
    kc_finish_result(core, result)
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_last_error_code(core: *mut KnowledgeCore) -> u8 {
    if core.is_null() {
        return KnowledgeCoreErrorCode::InvalidArgument as u8;
    }
    let core = unsafe { &mut *core };
    core.last_error_code()
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_last_error_message(
    core: *mut KnowledgeCore,
) -> GraphEngineStringSlice {
    if core.is_null() {
        return empty_string_slice();
    }
    let core = unsafe { &mut *core };
    string_slice(core.last_error_message())
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_backpressure_policy(core: *mut KnowledgeCore) -> u8 {
    if core.is_null() {
        return KnowledgeCoreBackpressurePolicy::FailFast as u8;
    }
    let core = unsafe { &mut *core };
    core.backpressure_policy() as u8
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_transport_stats(
    core: *mut KnowledgeCore,
) -> KnowledgeCoreTransportStatsFFI {
    if core.is_null() {
        return KnowledgeCoreTransportStatsFFI {
            published_frames: 0,
            dropped_frames: 0,
            coalesced_frames: 0,
            ring_full_failures: 0,
        };
    }
    let core = unsafe { &mut *core };
    let stats = core.transport_stats();
    KnowledgeCoreTransportStatsFFI {
        published_frames: stats.published_frames,
        dropped_frames: stats.dropped_frames,
        coalesced_frames: stats.coalesced_frames,
        ring_full_failures: stats.ring_full_failures,
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_subscription_kind(kind: u16) -> u8 {
    match kind {
        x if x == KnowledgeSubscriptionKind::Outline.code() => 0,
        x if x == KnowledgeSubscriptionKind::Tasks.code() => 1,
        x if x == KnowledgeSubscriptionKind::Properties.code() => 2,
        x if x == KnowledgeSubscriptionKind::Links.code() => 3,
        _ => u8::MAX,
    }
}

/// Read the archived tx id from a knowledge-core payload.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_payload_tx_id(data: *const u8, len: u64) -> u64 {
    with_knowledge_payload(data, len, |payload| payload.tx_id.to_native()).unwrap_or(0)
}

/// Read the archived subscription id from a knowledge-core payload.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_payload_subscription_id(data: *const u8, len: u64) -> u64 {
    with_knowledge_payload(data, len, |payload| payload.subscription_id.to_native()).unwrap_or(0)
}

/// Read the archived subscription kind code from a knowledge-core payload.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_payload_kind(data: *const u8, len: u64) -> u16 {
    with_knowledge_payload(data, len, |payload| {
        archived_knowledge_kind_code(&payload.kind)
    })
    .unwrap_or(u16::MAX)
}

/// Read all archived summary metadata in one validated pass.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_payload_summary(
    data: *const u8,
    len: u64,
    out: *mut KnowledgePayloadSummaryFFI,
) -> u8 {
    if out.is_null() {
        return 0;
    }

    with_knowledge_payload(data, len, |payload| {
        // SAFETY: `out` points to caller-owned storage for one `KnowledgePayloadSummaryFFI`.
        let out_summary = unsafe { &mut *out };
        reset_knowledge_summary(out_summary);
        out_summary.tx_id = payload.tx_id.to_native();
        out_summary.subscription_id = payload.subscription_id.to_native();
        out_summary.kind =
            graph_engine_kc_subscription_kind(archived_knowledge_kind_code(&payload.kind));
        out_summary.added_count = payload.added.len() as u32;
        out_summary.updated_count = payload.updated.len() as u32;
        out_summary.removed_count = payload.removed.len() as u32;
        1
    })
    .unwrap_or(0)
}

/// Row count for section 0=added, 1=updated, 2=removed.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_payload_row_count(data: *const u8, len: u64, section: u8) -> u32 {
    with_knowledge_payload(data, len, |payload| match section {
        0 => payload.added.len(),
        1 => payload.updated.len(),
        2 => payload.removed.len(),
        _ => 0,
    } as u32)
    .unwrap_or(0)
}

/// Read one archived row from section 0=added, 1=updated, 2=removed.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_payload_row(
    data: *const u8,
    len: u64,
    section: u8,
    index: u32,
    out: *mut KnowledgeQueryRowFFI,
) -> u8 {
    if out.is_null() {
        return 0;
    }

    with_knowledge_payload(data, len, |payload| {
        let archived_row = match section {
            0 => payload.added.get(index as usize),
            1 => payload.updated.get(index as usize),
            2 => payload.removed.get(index as usize),
            _ => None,
        };
        let Some(archived_row) = archived_row else {
            return 0;
        };

        // SAFETY: `out` points to caller-owned storage for one `KnowledgeQueryRowFFI`.
        let out_row = unsafe { &mut *out };
        fill_knowledge_row_from_archived(out_row, archived_row);
        1
    })
    .unwrap_or(0)
}

/// Read a contiguous batch of archived rows from section 0=added, 1=updated, 2=removed.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_kc_payload_rows(
    data: *const u8,
    len: u64,
    section: u8,
    start_index: u32,
    out: *mut KnowledgeQueryRowFFI,
    max_rows: u32,
) -> u32 {
    if out.is_null() || max_rows == 0 {
        return 0;
    }

    with_knowledge_payload(data, len, |payload| {
        let rows = match section {
            0 => &payload.added,
            1 => &payload.updated,
            2 => &payload.removed,
            _ => return 0,
        };

        let start = start_index as usize;
        if start >= rows.len() {
            return 0;
        }

        let write_count = usize::min(max_rows as usize, rows.len() - start);
        // SAFETY: `out` points to caller-owned storage for at least `max_rows`
        // `KnowledgeQueryRowFFI` values, and `write_count <= max_rows`.
        let out_rows = unsafe { std::slice::from_raw_parts_mut(out, write_count) };
        for (out_row, archived_row) in out_rows
            .iter_mut()
            .zip(rows.iter().skip(start).take(write_count))
        {
            fill_knowledge_row_from_archived(out_row, archived_row);
        }
        write_count as u32
    })
    .unwrap_or(0)
}

/// Register an outline subscription for a page.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_subscribe_outline(
    engine: *mut Engine,
    page_id: *const c_char,
) -> u64 {
    ffi_engine_or!(engine, 0);
    let page_id = ffi_cstr!(page_id);
    if page_id.is_empty() {
        return 0;
    }
    engine.btk_query_kernel.subscribe_outline(page_id)
}

/// Register a property subscription. Pass NULL for `value` to match any value for the key.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_subscribe_property(
    engine: *mut Engine,
    key: *const c_char,
    value: *const c_char,
) -> u64 {
    ffi_engine_or!(engine, 0);
    let key = ffi_cstr!(key);
    if key.is_empty() {
        return 0;
    }
    let value = (!value.is_null()).then(|| ffi_cstr!(value));
    engine
        .btk_query_kernel
        .subscribe_property_equals(key, value)
}

/// Register a link traversal subscription rooted at `block_id`.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_subscribe_links(
    engine: *mut Engine,
    block_id: *const c_char,
    max_depth: u8,
) -> u64 {
    ffi_engine_or!(engine, 0);
    let block_id = ffi_cstr!(block_id);
    if block_id.is_empty() {
        return 0;
    }
    engine
        .btk_query_kernel
        .subscribe_links(block_id, max_depth.max(1))
}

/// Remove a BTK subscription.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_unsubscribe(engine: *mut Engine, subscription_id: u64) -> u8 {
    ffi_engine_or!(engine, 0);
    if engine.btk_query_kernel.unsubscribe(subscription_id) {
        1
    } else {
        0
    }
}

/// Return the latest archived diff for a subscription and clear its pending state.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_take_subscription_update(
    engine: *mut Engine,
    subscription_id: u64,
) -> GraphEngineByteBuffer {
    ffi_engine_or!(engine, empty_byte_buffer());
    match engine.btk_query_kernel.take_update(subscription_id) {
        Some(bytes) => byte_buffer_from_vec(bytes),
        None => empty_byte_buffer(),
    }
}

/// Return an archived snapshot of a subscription at a historical BTK transaction version.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_snapshot_subscription(
    engine: *mut Engine,
    subscription_id: u64,
    version: u64,
) -> GraphEngineByteBuffer {
    ffi_engine_or!(engine, empty_byte_buffer());
    match engine
        .btk_query_kernel
        .snapshot_bytes(subscription_id, version, &engine.btk_logs)
    {
        Some(bytes) => byte_buffer_from_vec(bytes),
        None => empty_byte_buffer(),
    }
}

/// Latest BTK query-kernel transaction sequence.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_latest_subscription_seq(engine: *mut Engine) -> u64 {
    ffi_engine_or!(engine, 0);
    engine.btk_query_kernel.latest_seq()
}

/// Read the archived payload version from a BTK subscription buffer.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_payload_version(data: *const u8, len: u64) -> u64 {
    with_subscription_payload(data, len, |payload| payload.version.to_native()).unwrap_or(0)
}

/// Read the archived payload kind from a BTK subscription buffer.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_payload_kind(data: *const u8, len: u64) -> u8 {
    with_subscription_payload(data, len, |payload| payload.kind).unwrap_or(0)
}

/// Row count for section 0=added, 1=updated, 2=removed.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_payload_row_count(
    data: *const u8,
    len: u64,
    section: u8,
) -> u32 {
    with_subscription_payload(data, len, |payload| match section {
        0 => payload.added.len(),
        1 => payload.updated.len(),
        2 => payload.removed.len(),
        _ => 0,
    } as u32)
    .unwrap_or(0)
}

/// Read one row from section 0=added, 1=updated, 2=removed.
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_btk_payload_row(
    data: *const u8,
    len: u64,
    section: u8,
    index: u32,
    out: *mut BtkSubscriptionRowFFI,
) -> u8 {
    if out.is_null() {
        return 0;
    }
    with_subscription_payload(data, len, |payload| {
        let archived_row = match section {
            0 => payload.added.get(index as usize),
            1 => payload.updated.get(index as usize),
            2 => payload.removed.get(index as usize),
            _ => None,
        };
        let Some(archived_row) = archived_row else {
            return 0;
        };

        // SAFETY: `out` is caller-owned memory for one BtkSubscriptionRowFFI.
        let out_row = unsafe { &mut *out };
        fill_string_slice(&mut out_row.page_id, archived_row.page_id.as_str());
        fill_string_slice(&mut out_row.block_id, archived_row.block_id.as_str());
        fill_string_slice(&mut out_row.parent_id, archived_row.parent_id.as_str());
        fill_string_slice(&mut out_row.target_id, archived_row.target_id.as_str());
        fill_string_slice(&mut out_row.content, archived_row.content.as_str());
        fill_string_slice(
            &mut out_row.property_key,
            archived_row.property_key.as_str(),
        );
        fill_string_slice(
            &mut out_row.property_value,
            archived_row.property_value.as_str(),
        );
        fill_string_slice(&mut out_row.task_marker, archived_row.task_marker.as_str());
        fill_string_slice(&mut out_row.order_key, archived_row.order_key.as_str());
        out_row.depth = archived_row.depth.to_native();
        out_row.ref_type = archived_row.ref_type;
        out_row.task_done = u8::from(archived_row.task_done);
        out_row.hop_count = archived_row.hop_count;
        1
    })
    .unwrap_or(0)
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

#[cfg(test)]
mod knowledge_core_ffi_tests {
    use std::ffi::CString;
    use std::hint::black_box;
    use std::time::Instant;

    use super::{
        GraphEngineRingLayout, GraphEngineSharedMemoryRegion, GraphEngineStringSlice,
        KnowledgePayloadSummaryFFI, KnowledgeQueryRowFFI, graph_engine_kc_backpressure_policy,
        graph_engine_kc_create, graph_engine_kc_destroy, graph_engine_kc_ingest_document,
        graph_engine_kc_last_error_code, graph_engine_kc_last_error_message,
        graph_engine_kc_move_block, graph_engine_kc_payload_kind, graph_engine_kc_payload_row,
        graph_engine_kc_payload_row_count, graph_engine_kc_payload_rows,
        graph_engine_kc_payload_subscription_id, graph_engine_kc_payload_summary,
        graph_engine_kc_payload_tx_id, graph_engine_kc_ring_head, graph_engine_kc_ring_layout,
        graph_engine_kc_ring_region, graph_engine_kc_subscribe_outline,
        graph_engine_kc_subscription_kind, graph_engine_kc_transport_stats,
    };

    #[repr(C)]
    struct TestSlotHeader {
        len: u32,
        kind: u16,
        flags: u16,
        version: u64,
    }

    #[test]
    fn knowledge_core_payload_accessors_roundtrip_archived_rows() {
        let core = graph_engine_kc_create(4, 2048, 77);
        assert!(!core.is_null());

        let page = CString::new("page-1").expect("page id should be valid");
        let text = CString::new("- First\n- Second").expect("text should be valid");
        let subscription_id = graph_engine_kc_subscribe_outline(core, page.as_ptr());
        assert_ne!(subscription_id, 0);
        assert_eq!(
            graph_engine_kc_ingest_document(core, page.as_ptr(), 0, text.as_ptr()),
            1
        );

        let region = graph_engine_kc_ring_region(core);
        let layout = graph_engine_kc_ring_layout(core);
        assert_eq!(graph_engine_kc_ring_head(core), 2);

        let (initial_ptr, initial_len) = slot_payload(&region, &layout, 0);
        assert_eq!(
            graph_engine_kc_payload_row_count(initial_ptr, initial_len, 0),
            0
        );

        let (payload_ptr, payload_len) = slot_payload(&region, &layout, 1);
        let mut summary = empty_summary();
        assert_eq!(
            graph_engine_kc_payload_summary(payload_ptr, payload_len, &mut summary),
            1
        );
        assert_eq!(summary.tx_id, 1);
        assert_eq!(summary.subscription_id, subscription_id);
        assert_eq!(summary.kind, 0);
        assert_eq!(summary.added_count, 2);
        assert_eq!(summary.updated_count, 0);
        assert_eq!(summary.removed_count, 0);
        assert_eq!(graph_engine_kc_payload_tx_id(payload_ptr, payload_len), 1);
        assert_eq!(
            graph_engine_kc_payload_subscription_id(payload_ptr, payload_len),
            subscription_id
        );
        let raw_kind = graph_engine_kc_payload_kind(payload_ptr, payload_len);
        assert_eq!(graph_engine_kc_subscription_kind(raw_kind), 0);
        assert_eq!(
            graph_engine_kc_payload_row_count(payload_ptr, payload_len, 0),
            2
        );

        let mut first_row = empty_row();
        let mut second_row = empty_row();
        assert_eq!(
            graph_engine_kc_payload_row(payload_ptr, payload_len, 0, 0, &mut first_row),
            1
        );
        assert_eq!(
            graph_engine_kc_payload_row(payload_ptr, payload_len, 0, 1, &mut second_row),
            1
        );
        assert_eq!(first_row.row_kind, 0);
        assert_eq!(second_row.row_kind, 0);
        assert_eq!(decode(first_row.page_id), "page-1");
        assert_eq!(decode(second_row.page_id), "page-1");

        let mut contents = [decode(first_row.content), decode(second_row.content)];
        contents.sort();
        assert_eq!(contents, ["First".to_string(), "Second".to_string()]);

        let mut batched_rows = [empty_row(), empty_row()];
        assert_eq!(
            graph_engine_kc_payload_rows(
                payload_ptr,
                payload_len,
                0,
                0,
                batched_rows.as_mut_ptr(),
                batched_rows.len() as u32,
            ),
            2
        );
        let mut batched_contents = [
            decode(batched_rows[0].content),
            decode(batched_rows[1].content),
        ];
        batched_contents.sort();
        assert_eq!(
            batched_contents,
            ["First".to_string(), "Second".to_string()]
        );

        graph_engine_kc_destroy(core);
    }

    #[test]
    fn knowledge_core_reports_missing_node_failures() {
        let core = graph_engine_kc_create(4, 2048, 91);
        assert!(!core.is_null());

        let page = CString::new("page-missing").expect("page id should be valid");
        let block = CString::new("missing-block").expect("block id should be valid");

        assert_eq!(
            graph_engine_kc_move_block(core, page.as_ptr(), block.as_ptr(), std::ptr::null(), 0),
            0
        );
        assert_eq!(graph_engine_kc_last_error_code(core), 6);
        assert_eq!(
            decode(graph_engine_kc_last_error_message(core)),
            "missing outline node: missing-block"
        );

        graph_engine_kc_destroy(core);
    }

    #[test]
    fn knowledge_core_reports_ring_backpressure() {
        let core = graph_engine_kc_create(1, 2048, 92);
        assert!(!core.is_null());

        let page = CString::new("page-full").expect("page id should be valid");
        let text = CString::new("- Filled").expect("text should be valid");

        let subscription_id = graph_engine_kc_subscribe_outline(core, page.as_ptr());
        assert_ne!(subscription_id, 0);
        assert_eq!(graph_engine_kc_ring_head(core), 1);

        assert_eq!(
            graph_engine_kc_ingest_document(core, page.as_ptr(), 0, text.as_ptr()),
            0
        );
        assert_eq!(graph_engine_kc_last_error_code(core), 2);
        assert_eq!(
            decode(graph_engine_kc_last_error_message(core)),
            "shared-memory ring is full"
        );
        assert_eq!(graph_engine_kc_backpressure_policy(core), 0);
        let stats = graph_engine_kc_transport_stats(core);
        assert_eq!(stats.published_frames, 1);
        assert_eq!(stats.ring_full_failures, 1);
        assert_eq!(stats.dropped_frames, 0);
        assert_eq!(stats.coalesced_frames, 0);

        graph_engine_kc_destroy(core);
    }

    #[test]
    #[ignore = "benchmark"]
    fn benchmark_knowledge_core_payload_summary_accessor() {
        let core = graph_engine_kc_create(4, 4096, 93);
        assert!(!core.is_null());

        let page = CString::new("page-bench").expect("page id should be valid");
        let text = CString::new("- Alpha\n- Beta\n- Gamma\n- Delta").expect("text should be valid");
        let subscription_id = graph_engine_kc_subscribe_outline(core, page.as_ptr());
        assert_ne!(subscription_id, 0);
        assert_eq!(
            graph_engine_kc_ingest_document(core, page.as_ptr(), 0, text.as_ptr()),
            1
        );

        let region = graph_engine_kc_ring_region(core);
        let layout = graph_engine_kc_ring_layout(core);
        let (payload_ptr, payload_len) = slot_payload(&region, &layout, 1);
        let iterations = 200_000u32;

        let start_scalar = Instant::now();
        for _ in 0..iterations {
            black_box(graph_engine_kc_payload_tx_id(payload_ptr, payload_len));
            black_box(graph_engine_kc_payload_subscription_id(
                payload_ptr,
                payload_len,
            ));
            let raw_kind = black_box(graph_engine_kc_payload_kind(payload_ptr, payload_len));
            black_box(graph_engine_kc_subscription_kind(raw_kind));
            black_box(graph_engine_kc_payload_row_count(
                payload_ptr,
                payload_len,
                0,
            ));
            black_box(graph_engine_kc_payload_row_count(
                payload_ptr,
                payload_len,
                1,
            ));
            black_box(graph_engine_kc_payload_row_count(
                payload_ptr,
                payload_len,
                2,
            ));
        }
        let scalar_elapsed = start_scalar.elapsed();

        let start_summary = Instant::now();
        for _ in 0..iterations {
            let mut summary = empty_summary();
            black_box(graph_engine_kc_payload_summary(
                payload_ptr,
                payload_len,
                &mut summary,
            ));
            black_box(summary.tx_id);
            black_box(summary.subscription_id);
            black_box(summary.kind);
            black_box(summary.added_count);
            black_box(summary.updated_count);
            black_box(summary.removed_count);
        }
        let summary_elapsed = start_summary.elapsed();

        eprintln!(
            "knowledge_core_payload_summary scalar_ns_per_decode={} summary_ns_per_decode={} speedup_x={:.2}",
            scalar_elapsed.as_nanos() / u128::from(iterations),
            summary_elapsed.as_nanos() / u128::from(iterations),
            scalar_elapsed.as_secs_f64() / summary_elapsed.as_secs_f64()
        );

        graph_engine_kc_destroy(core);
    }

    #[test]
    #[ignore = "benchmark"]
    fn benchmark_knowledge_core_payload_rows_batch_accessor() {
        let core = graph_engine_kc_create(4, 4096, 94);
        assert!(!core.is_null());

        let page = CString::new("page-batch").expect("page id should be valid");
        let text = CString::new("- One\n- Two\n- Three\n- Four").expect("text should be valid");
        let subscription_id = graph_engine_kc_subscribe_outline(core, page.as_ptr());
        assert_ne!(subscription_id, 0);
        assert_eq!(
            graph_engine_kc_ingest_document(core, page.as_ptr(), 0, text.as_ptr()),
            1
        );

        let region = graph_engine_kc_ring_region(core);
        let layout = graph_engine_kc_ring_layout(core);
        let (payload_ptr, payload_len) = slot_payload(&region, &layout, 1);
        let row_count = graph_engine_kc_payload_row_count(payload_ptr, payload_len, 0);
        assert_eq!(row_count, 4);
        let iterations = 50_000u32;

        let start_scalar = Instant::now();
        for _ in 0..iterations {
            for index in 0..row_count {
                let mut row = empty_row();
                black_box(graph_engine_kc_payload_row(
                    payload_ptr,
                    payload_len,
                    0,
                    index,
                    &mut row,
                ));
                black_box(row.row_kind);
                black_box(row.content.len);
            }
        }
        let scalar_elapsed = start_scalar.elapsed();

        let start_batch = Instant::now();
        for _ in 0..iterations {
            let mut rows = [empty_row(), empty_row(), empty_row(), empty_row()];
            let written = graph_engine_kc_payload_rows(
                payload_ptr,
                payload_len,
                0,
                0,
                rows.as_mut_ptr(),
                row_count,
            );
            black_box(written);
            for row in rows.iter().take(written as usize) {
                black_box(row.row_kind);
                black_box(row.content.len);
            }
        }
        let batch_elapsed = start_batch.elapsed();

        eprintln!(
            "knowledge_core_payload_rows scalar_ns_per_payload={} batch_ns_per_payload={} speedup_x={:.2}",
            scalar_elapsed.as_nanos() / u128::from(iterations),
            batch_elapsed.as_nanos() / u128::from(iterations),
            scalar_elapsed.as_secs_f64() / batch_elapsed.as_secs_f64()
        );

        graph_engine_kc_destroy(core);
    }

    fn slot_payload(
        region: &GraphEngineSharedMemoryRegion,
        layout: &GraphEngineRingLayout,
        sequence: u64,
    ) -> (*const u8, u64) {
        let slot_index = (sequence % u64::from(layout.slot_count)) as usize;
        let slot_offset = layout.slots_offset as usize + (slot_index * layout.slot_stride as usize);
        let payload_offset = layout.slot_payload_offset as usize;
        // SAFETY: The region and layout come from `graph_engine_kc_ring_region/layout`
        // for the same core, and the test only reads published slots below `head`.
        let slot_base = unsafe { region.ptr.add(slot_offset) };
        // SAFETY: Slot headers are written by Rust with `repr(C)` layout.
        let header = unsafe { &*slot_base.cast::<TestSlotHeader>() };
        assert!(header.len as u32 <= layout.slot_payload_bytes);
        let payload_ptr = unsafe { slot_base.add(payload_offset) };
        (payload_ptr.cast::<u8>(), u64::from(header.len))
    }

    fn empty_row() -> KnowledgeQueryRowFFI {
        KnowledgeQueryRowFFI {
            row_kind: u8::MAX,
            _pad: [0; 3],
            page_id: empty_slice(),
            block_id: empty_slice(),
            parent_id: empty_slice(),
            target_id: empty_slice(),
            content: empty_slice(),
            property_key: empty_slice(),
            property_value: empty_slice(),
            task_marker: empty_slice(),
            order_key: empty_slice(),
            depth: 0,
            ref_type: 0,
            task_done: 0,
        }
    }

    fn empty_summary() -> KnowledgePayloadSummaryFFI {
        KnowledgePayloadSummaryFFI {
            tx_id: 0,
            subscription_id: 0,
            kind: u8::MAX,
            _pad: [0; 3],
            added_count: 0,
            updated_count: 0,
            removed_count: 0,
        }
    }

    fn empty_slice() -> GraphEngineStringSlice {
        GraphEngineStringSlice {
            ptr: std::ptr::null(),
            len: 0,
        }
    }

    fn decode(slice: GraphEngineStringSlice) -> String {
        if slice.ptr.is_null() || slice.len == 0 {
            return String::new();
        }
        let bytes = unsafe { std::slice::from_raw_parts(slice.ptr, slice.len as usize) };
        std::str::from_utf8(bytes)
            .expect("slice should be valid utf-8")
            .to_string()
    }
}
