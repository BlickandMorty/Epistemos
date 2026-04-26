//! # `substrate-rt`
//!
//! Zero-copy hot-path event ring for the Swift host.
//!
//! Per `docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 5
//! (cross-ref dpp §5.1-5.6 Sprint 4: zero-copy FFI carve-out).
//!
//! ## Why this crate exists
//!
//! UniFFI is fine for cold-path control APIs (open vault, run agent
//! turn) but its per-call overhead — argument lifting / lowering,
//! Box/Arc bookkeeping, an actor hop on the Swift side — is too high
//! for the highest-frequency events: cursor moves, edit deltas, layout
//! updates, MCP token chunks, agent frame ticks. Sprint 0 signpost
//! data identified ~5-10 such events that dominate per-frame FFI cost.
//!
//! `substrate-rt` carves those events out into a dedicated `repr(C)`
//! single-producer single-consumer ring buffer. The Rust producer
//! pushes 64-byte POD events with a single Release atomic store; the
//! Swift `EventDrain` actor calls `ering_drain` once per frame and
//! reads them in bulk via Acquire load — no per-event boundary cost.
//!
//! ## Canonical dependency choice (per Wave 5 research)
//!
//! - [`rtrb`] 0.3.x for the SPSC primitive. Lock-free; uses
//!   Release-on-store / Acquire-on-load internally; designed for the
//!   audio-thread → UI-thread handoff pattern that mirrors our
//!   Rust → Swift `@MainActor` consumer.
//! - [`crossbeam-utils::CachePadded`] for head/tail atomic alignment.
//!   Auto-detects Apple Silicon's 128-byte L2 cache line; hand-rolled
//!   `#[repr(align(64))]` would false-share on M-series CPUs.
//! - `#[repr(C)]` + `Copy` (no `Drop`) for `GraphEvent` so `rtrb`'s
//!   `write_chunk_uninit` is sound across the FFI boundary.

pub mod event_ring;
pub mod graph_event;

pub use event_ring::{EventRing, EventRingError};
pub use graph_event::GraphEvent;

// ---------------------------------------------------------------------------
// C ABI surface
// ---------------------------------------------------------------------------

/// Allocate a new ring with the given capacity. Returns an opaque pointer
/// the Swift caller stores; pass it back to `ering_try_push` / `ering_drain`
/// / `ering_destroy`. Capacity is rounded UP to the next power of two by
/// `rtrb` for fast modulo.
///
/// Returns null on allocation failure or zero capacity.
///
/// SAFETY: caller is responsible for calling `ering_destroy` exactly once
/// with the same pointer to release the underlying ring + slot storage.
#[unsafe(no_mangle)]
pub extern "C" fn ering_new(capacity: usize) -> *mut EventRing {
    let result = std::panic::catch_unwind(|| {
        if capacity == 0 {
            return std::ptr::null_mut();
        }
        let ring = EventRing::with_capacity(capacity);
        Box::into_raw(Box::new(ring))
    });
    result.unwrap_or(std::ptr::null_mut())
}

/// Try to push one event. Returns `true` on success, `false` if the ring
/// is full. Non-blocking. Safe to call concurrently with `ering_drain` from
/// a different thread (SPSC: one producer thread total).
///
/// SAFETY: `ring` must be a valid pointer returned from `ering_new` and
/// not yet destroyed. `event` must be a valid `GraphEvent` reference.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ering_try_push(
    ring: *mut EventRing,
    event: *const GraphEvent,
) -> bool {
    let result = std::panic::catch_unwind(|| {
        if ring.is_null() || event.is_null() {
            return false;
        }
        // SAFETY: caller contract above.
        let ring = unsafe { &*ring };
        let event = unsafe { *event };
        ring.try_push(event)
    });
    result.unwrap_or(false)
}

/// Drain up to `max` events into `out`. Returns the number of events
/// actually written. Non-blocking. Safe to call concurrently with
/// `ering_try_push` from a different thread (SPSC: one consumer thread total).
///
/// SAFETY: `ring` must be a valid pointer returned from `ering_new` and
/// not yet destroyed. `out` must point to writable memory of at least
/// `max * sizeof(GraphEvent)` bytes.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ering_drain(
    ring: *mut EventRing,
    out: *mut GraphEvent,
    max: usize,
) -> usize {
    let result = std::panic::catch_unwind(|| {
        if ring.is_null() || out.is_null() || max == 0 {
            return 0;
        }
        // SAFETY: caller contract above.
        let ring = unsafe { &*ring };
        let slice = unsafe { std::slice::from_raw_parts_mut(out, max) };
        ring.drain(slice)
    });
    result.unwrap_or(0)
}

/// Approximate live event count (producer pushes ahead of consumer
/// drains). Snapshot only — by the time the caller reads the value, the
/// real count may have changed. Useful for diagnostics + back-pressure
/// heuristics, not for correctness decisions.
///
/// SAFETY: `ring` must be a valid pointer returned from `ering_new` and
/// not yet destroyed.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ering_pending(ring: *mut EventRing) -> usize {
    let result = std::panic::catch_unwind(|| {
        if ring.is_null() {
            return 0;
        }
        // SAFETY: caller contract above.
        let ring = unsafe { &*ring };
        ring.pending()
    });
    result.unwrap_or(0)
}

/// Release the ring + its slot storage. Idempotent on null.
///
/// SAFETY: `ring` must be a pointer previously returned by `ering_new`
/// and not previously destroyed. Caller must guarantee no concurrent
/// `ering_try_push` / `ering_drain` is in flight.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ering_destroy(ring: *mut EventRing) {
    if ring.is_null() {
        return;
    }
    let _ = std::panic::catch_unwind(|| {
        // SAFETY: caller contract above.
        unsafe { drop(Box::from_raw(ring)) };
    });
}
