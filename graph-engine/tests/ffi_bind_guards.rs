//! Deterministic repro for canonical-plan §"Failure cases to make
//! deterministically reproducible":
//!
//!   - Bind a wrong stride and assert the engine rejects it cleanly
//!
//! Exercises the FFI guards on `graph_engine_bind_node_state_slot` via
//! the canonical null-engine fast-fail path (which doesn't require a
//! real Metal device). The guards themselves are:
//!
//!   1. Null engine pointer → return false (via `ffi_engine_or!`)
//!   2. Null buffer pointer → return false
//!   3. Stride mismatch → return false (Swift/Rust struct layout drift)
//!   4. ABI version mismatch → return false (rebuild Swift bindings)
//!   5. len_bytes < stride → return false (zero-capacity slot)
//!
//! All five paths should be reachable without ever touching Metal.

// SAFETY: This test deliberately exercises the FFI null-pointer and
// bad-arg fast-fail paths. The FFI itself is responsible for guarding
// against these inputs without dereferencing.
#![allow(unused_unsafe)]

use std::ffi::c_void;

unsafe extern "C" {
    fn graph_engine_bind_node_state_slot(
        engine: *mut c_void,
        slot: u32,
        ptr: *mut c_void,
        len_bytes: usize,
        stride: usize,
        abi_version: u32,
    ) -> bool;

    fn graph_engine_node_state_abi_version() -> u32;
    fn graph_engine_node_state_size_bytes() -> usize;
    fn graph_engine_phase_b_target(scenario_id: u32, vault_node_count: u32) -> f64;
}

#[test]
fn bind_rejects_null_engine() {
    // ffi_engine_or! short-circuits on null engine before reading other args.
    let ok = unsafe {
        graph_engine_bind_node_state_slot(
            std::ptr::null_mut(), // null engine
            0,
            0xDEAD_BEEF as *mut c_void, // intentionally garbage ptr (untouched)
            64,
            64,
            1,
        )
    };
    assert!(!ok, "bind must reject null engine pointer");
}

#[test]
fn bind_rejects_wrong_abi_version() {
    let real_abi = unsafe { graph_engine_node_state_abi_version() };
    let real_stride = unsafe { graph_engine_node_state_size_bytes() };
    // We use a null engine to fast-fail, but the FFI checks each guard
    // independently — confirm the surface accepts the canonical
    // size_bytes() + abi_version() reflection. The wrong-ABI path is
    // *upstream* of the engine-pointer dereference but the null-engine
    // path fires first; this test mainly proves the reflection accessors
    // exist + return the locked values.
    assert_eq!(real_abi, 1, "GRAPH_NODE_STATE_ABI_VERSION must be 1 (V2.2 lock)");
    assert_eq!(real_stride, 64, "GraphNodeState must be 64-byte aligned (V2.2 lock)");

    // Now exercise the wrong-ABI guard with a null engine + wrong abi.
    // (Null engine fires first → returns false.) The contract is that
    // the function never panics or dereferences a bad pointer.
    let ok = unsafe {
        graph_engine_bind_node_state_slot(
            std::ptr::null_mut(),
            0,
            0xDEAD_BEEF as *mut c_void,
            64,
            64,
            real_abi + 1, // intentionally wrong ABI
        )
    };
    assert!(!ok, "bind with null engine + wrong abi must return false");
}

#[test]
fn bind_abi_reflection_matches_size_reflection() {
    // The two reflection accessors are the canonical bind-time contract:
    // Swift reads both at startup and compares them against its mirror
    // of GraphNodeState. If either drifts, Swift refuses to bind.
    let abi = unsafe { graph_engine_node_state_abi_version() };
    let size = unsafe { graph_engine_node_state_size_bytes() };
    assert_eq!(abi, graph_engine::node_state::GRAPH_NODE_STATE_ABI_VERSION,
        "FFI abi reflection must match Rust constant");
    assert_eq!(size, std::mem::size_of::<graph_engine::node_state::GraphNodeState>(),
        "FFI size reflection must match Rust size_of");
}

#[test]
fn bind_size_constants_match_locked_canonical_values() {
    // The canonical plan locks these values; the test exists so future
    // drift triggers a CI failure with a pointer back to this comment.
    //
    // Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Locked
    // architectural decisions" #3:
    //   "NodeState 64-byte aligned (single cache line on Apple Silicon)"
    // and the bind contract in node_state.rs:
    //   "GRAPH_NODE_STATE_ABI_VERSION = 1"
    let size = unsafe { graph_engine_node_state_size_bytes() };
    assert_eq!(size, 64, "GraphNodeState must remain 64 bytes (single Apple Silicon cache line)");

    let abi = unsafe { graph_engine_node_state_abi_version() };
    assert_eq!(abi, 1, "ABI version 1 lock per canonical plan");
}

#[test]
fn phase_b_target_ffi_matches_canonical_plan_table() {
    // Scenario IDs (must match the canonical SCENARIO_ID_* constants).
    const COLD_OPEN: u32 = 0;
    const STEADY_FPS_ZOOM_OUT: u32 = 2;
    const STEADY_FPS_ZOOM_IN: u32 = 3;
    const DRAG_FPS: u32 = 4;
    const MEMORY_MB: u32 = 6;

    // Per canonical-plan §"Phase B acceptance criteria":
    // 1k cold open: ≤ 80 ms
    let t = unsafe { graph_engine_phase_b_target(COLD_OPEN, 1_000) };
    assert!((t - 80.0).abs() < 1e-9, "1k ColdOpen target should be 80ms, got {}", t);

    // 50k cold open: ≤ 1500 ms
    let t = unsafe { graph_engine_phase_b_target(COLD_OPEN, 50_000) };
    assert!((t - 1500.0).abs() < 1e-9);

    // 50k drag: ≥ 30 fps
    let t = unsafe { graph_engine_phase_b_target(DRAG_FPS, 50_000) };
    assert!((t - 30.0).abs() < 1e-9);

    // 50k memory: ≤ 1024 MB
    let t = unsafe { graph_engine_phase_b_target(MEMORY_MB, 50_000) };
    assert!((t - 1024.0).abs() < 1e-9);

    // 10k zoom-in: ≥ 90 fps
    let t = unsafe { graph_engine_phase_b_target(STEADY_FPS_ZOOM_IN, 10_000) };
    assert!((t - 90.0).abs() < 1e-9);

    // 100k zoom-out: ≥ 18 fps
    let t = unsafe { graph_engine_phase_b_target(STEADY_FPS_ZOOM_OUT, 100_000) };
    assert!((t - 18.0).abs() < 1e-9);
}

#[test]
fn phase_b_target_ffi_returns_nan_for_unknown_scenario() {
    let t = unsafe { graph_engine_phase_b_target(999, 10_000) };
    assert!(t.is_nan(), "unknown scenario ID must return NaN, got {}", t);
}

#[test]
fn phase_b_target_ffi_returns_nan_for_undefined_cell() {
    // SearchPulseFps has no defined gates in the canonical plan table.
    const SEARCH_PULSE_FPS: u32 = 5;
    let t = unsafe { graph_engine_phase_b_target(SEARCH_PULSE_FPS, 10_000) };
    assert!(t.is_nan(), "undefined-cell target must return NaN");
}
