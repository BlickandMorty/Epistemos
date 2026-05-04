//! Bolt Graph FFI — typed buffer layout for batch node/edge transfer.
//!
//! This module provides an alternative FFI path to the existing per-pointer
//! `graph_engine_add_nodes_batch` / `graph_engine_add_edges_batch` functions.
//! Instead of parallel pointer arrays, callers pass a contiguous array of
//! `#[repr(C)]` record structs — enabling zero-copy reads on the Swift side
//! and simpler buffer management.
//!
//! Gated behind the `bolt-graph` cargo feature (default off).

use std::ffi::CStr;

use crate::engine::Engine;

// ── Typed Buffer Structs ────────────────────────────────────────────────────

/// Contiguous node record for batch loading via the Bolt path.
/// String fields use borrowed (ptr, len) pairs — the caller must keep the
/// backing memory alive for the duration of the `bolt_graph_load_nodes` call.
#[repr(C)]
#[derive(Clone, Copy)]
pub struct BoltNodeRecord {
    /// UTF-8 string pointer for the node UUID (borrowed, not null-terminated required).
    pub id_ptr: *const u8,
    /// Byte length of the UUID string.
    pub id_len: u32,
    /// UTF-8 string pointer for the node label (borrowed).
    pub label_ptr: *const u8,
    /// Byte length of the label string.
    pub label_len: u32,
    /// Node type enum value (0=Note … 13=Resource).
    pub node_type: u8,
    /// Initial X position in world space.
    pub x: f32,
    /// Initial Y position in world space.
    pub y: f32,
    /// Node size hint (link count for radius sizing).
    pub size: f32,
    /// Packed RGBA color (0xRRGGBBAA). Currently reserved for future use.
    pub color_rgba: u32,
}

/// Contiguous edge record for batch loading via the Bolt path.
/// Uses index-based addressing into the node array passed in the same commit.
#[repr(C)]
#[derive(Clone, Copy)]
pub struct BoltEdgeRecord {
    /// Index into the node array for the source node.
    pub source_idx: u32,
    /// Index into the node array for the target node.
    pub target_idx: u32,
    /// Edge type enum value (0=reference … 11=questions).
    pub edge_type: u8,
    /// Edge weight.
    pub weight: f32,
}

/// Output-only position record written by `bolt_graph_query_positions`.
#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct BoltPositionRecord {
    pub x: f32,
    pub y: f32,
}

// ── Helper: extract a &str from a (ptr, len) pair ───────────────────────────

/// Safely extract a UTF-8 `&str` from a raw `(ptr, len)` pair.
/// Returns `""` on null pointer or invalid UTF-8.
fn bolt_str<'a>(ptr: *const u8, len: u32) -> &'a str {
    if ptr.is_null() || len == 0 {
        return "";
    }
    // SAFETY: Caller guarantees `ptr` is valid for `len` bytes and the backing
    // memory is alive for the duration of this FFI call. We validate UTF-8.
    let bytes = unsafe { std::slice::from_raw_parts(ptr, len as usize) };
    std::str::from_utf8(bytes).unwrap_or("")
}

// ── FFI Functions ───────────────────────────────────────────────────────────

/// Load a contiguous array of `BoltNodeRecord` structs into the graph.
///
/// The caller must ensure `buffer_ptr` points to at least `count` valid
/// `BoltNodeRecord` structs and that all string pointers within are alive
/// for the duration of this call.
#[unsafe(no_mangle)]
pub extern "C" fn bolt_graph_load_nodes(
    engine: *mut Engine,
    buffer_ptr: *const BoltNodeRecord,
    count: u32,
) {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        if engine.is_null() || buffer_ptr.is_null() || count == 0 {
            return;
        }
        // SAFETY: Caller guarantees `engine` is a valid, non-null Engine pointer.
        let engine = unsafe { &mut *engine };
        let count = count as usize;
        // SAFETY: Caller guarantees `buffer_ptr` points to `count` contiguous
        // BoltNodeRecord structs with valid alignment and lifetime.
        let records = unsafe { std::slice::from_raw_parts(buffer_ptr, count) };

        let graph = engine.graph_mut();
        for rec in records {
            let uuid = bolt_str(rec.id_ptr, rec.id_len).to_owned();
            let label = bolt_str(rec.label_ptr, rec.label_len).to_owned();
            graph.add_node(uuid, rec.x, rec.y, rec.node_type, rec.size as u32, label);
        }
    }));
    if result.is_err() {
        eprintln!("bolt_graph_load_nodes: panic caught");
    }
}

/// Load a contiguous array of `BoltEdgeRecord` structs into the graph.
///
/// `source_idx` and `target_idx` refer to the index of the node within the
/// most recent `bolt_graph_load_nodes` batch. The caller must ensure nodes
/// are loaded before edges in the same commit sequence.
///
/// Edges whose source/target indices reference nodes not found in the graph
/// are silently skipped.
#[unsafe(no_mangle)]
pub extern "C" fn bolt_graph_load_edges(
    engine: *mut Engine,
    buffer_ptr: *const BoltEdgeRecord,
    count: u32,
    node_uuids: *const *const std::ffi::c_char,
    node_uuid_count: u32,
) {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        if engine.is_null() || buffer_ptr.is_null() || count == 0 {
            return;
        }
        // SAFETY: Caller guarantees `engine` is a valid, non-null Engine pointer.
        let engine = unsafe { &mut *engine };
        let count = count as usize;
        // SAFETY: Caller guarantees `buffer_ptr` points to `count` contiguous
        // BoltEdgeRecord structs.
        let records = unsafe { std::slice::from_raw_parts(buffer_ptr, count) };

        // Build UUID lookup from the parallel node_uuids array so we can
        // resolve index-based edge references to UUID strings.
        let uuid_count = node_uuid_count as usize;
        let uuid_strs: Vec<&str> = if node_uuids.is_null() || uuid_count == 0 {
            Vec::new()
        } else {
            // SAFETY: Caller guarantees `node_uuids` points to `uuid_count`
            // valid C string pointers.
            let ptrs = unsafe { std::slice::from_raw_parts(node_uuids, uuid_count) };
            ptrs.iter()
                .map(|&p| {
                    if p.is_null() {
                        ""
                    } else {
                        // SAFETY: Caller guarantees these are valid null-terminated
                        // UTF-8 C strings alive for the call duration.
                        unsafe { CStr::from_ptr(p) }.to_str().unwrap_or("")
                    }
                })
                .collect()
        };

        let graph = engine.graph_mut();
        for rec in records {
            let si = rec.source_idx as usize;
            let ti = rec.target_idx as usize;
            if si >= uuid_strs.len() || ti >= uuid_strs.len() {
                continue;
            }
            let src = uuid_strs[si];
            let tgt = uuid_strs[ti];
            if src.is_empty() || tgt.is_empty() {
                continue;
            }
            graph.add_edge(src, tgt, rec.weight, rec.edge_type);
        }
    }));
    if result.is_err() {
        eprintln!("bolt_graph_load_edges: panic caught");
    }
}

/// Fill a pre-allocated buffer with current node positions.
///
/// Returns the number of positions written (≤ `max_count`).
/// Positions are written in internal node-array order.
#[unsafe(no_mangle)]
pub extern "C" fn bolt_graph_query_positions(
    engine: *mut Engine,
    out_ptr: *mut BoltPositionRecord,
    max_count: u32,
) -> u32 {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| -> u32 {
        if engine.is_null() || out_ptr.is_null() || max_count == 0 {
            return 0;
        }
        // SAFETY: Caller guarantees `engine` is a valid, non-null Engine pointer.
        let engine = unsafe { &mut *engine };
        let nodes = &engine.graph_mut().nodes;
        let write_count = nodes.len().min(max_count as usize);
        // SAFETY: Caller guarantees `out_ptr` points to a buffer with room for
        // at least `max_count` BoltPositionRecord structs.
        let out = unsafe { std::slice::from_raw_parts_mut(out_ptr, write_count) };
        for (i, node) in nodes.iter().enumerate().take(write_count) {
            out[i] = BoltPositionRecord {
                x: node.x,
                y: node.y,
            };
        }
        write_count as u32
    }));
    match result {
        Ok(n) => n,
        Err(_) => {
            eprintln!("bolt_graph_query_positions: panic caught");
            0
        }
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bolt_node_record_is_repr_c() {
        assert_eq!(
            std::mem::align_of::<BoltNodeRecord>(),
            std::mem::align_of::<*const u8>()
        );
        assert!(std::mem::size_of::<BoltNodeRecord>() > 0);
    }

    #[test]
    fn bolt_edge_record_is_repr_c() {
        assert!(std::mem::size_of::<BoltEdgeRecord>() > 0);
    }

    #[test]
    fn bolt_position_record_layout() {
        assert_eq!(
            std::mem::size_of::<BoltPositionRecord>(),
            std::mem::size_of::<f32>() * 2
        );
    }

    #[test]
    fn bolt_str_null_ptr() {
        assert_eq!(bolt_str(std::ptr::null(), 10), "");
    }

    #[test]
    fn bolt_str_zero_len() {
        let data = b"hello";
        assert_eq!(bolt_str(data.as_ptr(), 0), "");
    }

    #[test]
    fn bolt_str_valid() {
        let data = b"hello world";
        assert_eq!(bolt_str(data.as_ptr(), 5), "hello");
    }

    #[test]
    fn bolt_str_invalid_utf8() {
        let data: [u8; 3] = [0xFF, 0xFE, 0xFD];
        assert_eq!(bolt_str(data.as_ptr(), 3), "");
    }

    #[test]
    fn load_nodes_null_engine() {
        let rec = BoltNodeRecord {
            id_ptr: std::ptr::null(),
            id_len: 0,
            label_ptr: std::ptr::null(),
            label_len: 0,
            node_type: 0,
            x: 0.0,
            y: 0.0,
            size: 0.0,
            color_rgba: 0,
        };
        bolt_graph_load_nodes(std::ptr::null_mut(), &rec, 1);
    }

    #[test]
    fn load_edges_null_engine() {
        let rec = BoltEdgeRecord {
            source_idx: 0,
            target_idx: 0,
            edge_type: 0,
            weight: 1.0,
        };
        bolt_graph_load_edges(std::ptr::null_mut(), &rec, 1, std::ptr::null(), 0);
    }

    #[test]
    fn query_positions_null_engine() {
        let mut buf = [BoltPositionRecord::default(); 4];
        let n = bolt_graph_query_positions(std::ptr::null_mut(), buf.as_mut_ptr(), 4);
        assert_eq!(n, 0);
    }
}
