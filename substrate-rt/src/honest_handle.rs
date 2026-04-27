//! W9.21 — Honest FFI for `substrate-rt` (PR2 of 4)
//!
//! Per `docs/RESEARCH_DOSSIER_TIER_3_4.md` §W9.21: replace raw
//! `Box::into_raw` lifecycle (lib.rs:61, 146) with `Arc::into_raw`
//! refcounted handles. The new `ering_handle_*` exports coexist with
//! the existing `ering_*` global API; PR4 (Swift cutover) migrates
//! consumers off the legacy path one call site at a time.
//!
//! ## Why honest matters here
//!
//! `substrate-rt`'s `EventRing` is the SPSC zero-copy event ring. The
//! current API uses `*mut EventRing` with a runtime SAFETY contract
//! ("caller must guarantee no concurrent push/drain in flight when
//! calling destroy"). That works but it's a runtime contract.
//!
//! With honest FFI: producer + consumer + destroyer each retain their
//! own Arc handle; the ring drops only when ALL handles release. The
//! refcount is the contract — no runtime invariant.
//!
//! `EventRing` is `Send + Sync` (the inner `Producer<GraphEvent>` and
//! `Consumer<GraphEvent>` are wrapped in `Mutex` per event_ring.rs),
//! so wrapping in `Arc` is sound.
//!
//! ## Lifecycle contract
//!
//! - `ering_handle_new(capacity)` → `*const EventRingHandle` with
//!   refcount 1 (caller owns)
//! - `ering_handle_retain(h)` increments refcount (used when sharing
//!   the handle across Swift threads / actors)
//! - `ering_handle_release(h)` decrements; ring drops at zero
//! - All operation methods take `*const EventRingHandle` and act on
//!   the inner `EventRing` via `&*handle` (no transfer of ownership)

use std::sync::Arc;

use crate::event_ring::EventRing;
use crate::graph_event::GraphEvent;

/// Opaque refcounted handle to an `EventRing`. Crosses the FFI
/// boundary as `*const EventRingHandle`. The Rust side never exposes
/// the inner ring directly to Swift.
pub struct EventRingHandle {
    ring: Arc<EventRing>,
}

/// Allocate a new ring with the given capacity. Returns a refcount-1
/// handle; null on zero capacity.
///
/// # Safety
/// Always safe to call. The returned pointer must be released via
/// `ering_handle_release` exactly enough times to bring its refcount
/// to zero. (Typically: one release per matching retain, plus one
/// for the original `_new` ownership.)
#[unsafe(no_mangle)]
pub extern "C" fn ering_handle_new(capacity: usize) -> *const EventRingHandle {
    let result = std::panic::catch_unwind(|| {
        if capacity == 0 {
            return std::ptr::null();
        }
        let ring = Arc::new(EventRing::with_capacity(capacity));
        Arc::into_raw(Arc::new(EventRingHandle { ring }))
    });
    result.unwrap_or(std::ptr::null())
}

/// Increment the handle's refcount.
///
/// # Safety
/// `handle` must be a pointer previously returned by `ering_handle_new`
/// (or a previous `ering_handle_retain`) and not yet fully released.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ering_handle_retain(handle: *const EventRingHandle) {
    if !handle.is_null() {
        // SAFETY: caller contract — handle is live.
        unsafe {
            Arc::increment_strong_count(handle);
        }
    }
}

/// Decrement the handle's refcount. When the refcount reaches zero,
/// the underlying `EventRing` drops.
///
/// # Safety
/// `handle` must be a pointer previously returned by `ering_handle_new`
/// or `ering_handle_retain` and not yet fully released. Idempotent on
/// null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ering_handle_release(handle: *const EventRingHandle) {
    if !handle.is_null() {
        // SAFETY: caller contract — handle is live, exactly-balanced
        // retain/release lineage.
        unsafe {
            Arc::decrement_strong_count(handle);
        }
    }
}

/// Try to push one event. Returns `true` on success, `false` if the
/// ring is full or `handle` / `event` is null. SPSC: one producer
/// thread total.
///
/// # Safety
/// `handle` must be a live `EventRingHandle` pointer. `event` must
/// be a valid `GraphEvent` reference.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ering_handle_try_push(
    handle: *const EventRingHandle,
    event: *const GraphEvent,
) -> bool {
    let result = std::panic::catch_unwind(|| {
        if handle.is_null() || event.is_null() {
            return false;
        }
        // SAFETY: caller contract — handle + event are live.
        let h = unsafe { &*handle };
        let event = unsafe { *event };
        h.ring.try_push(event)
    });
    result.unwrap_or(false)
}

/// Drain up to `max` events into `out`. Returns the number of events
/// written. SPSC: one consumer thread total. Safe to call concurrently
/// with `ering_handle_try_push` from a different thread.
///
/// # Safety
/// `handle` must be a live `EventRingHandle` pointer. `out` must
/// point to writable memory of at least `max * sizeof(GraphEvent)`
/// bytes.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ering_handle_drain(
    handle: *const EventRingHandle,
    out: *mut GraphEvent,
    max: usize,
) -> usize {
    let result = std::panic::catch_unwind(|| {
        if handle.is_null() || out.is_null() || max == 0 {
            return 0;
        }
        // SAFETY: caller contract — handle is live, `out` is at
        // least `max` GraphEvents long.
        let h = unsafe { &*handle };
        let slice = unsafe { std::slice::from_raw_parts_mut(out, max) };
        h.ring.drain(slice)
    });
    result.unwrap_or(0)
}

/// Approximate live event count. Snapshot only.
///
/// # Safety
/// `handle` must be a live `EventRingHandle` pointer.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn ering_handle_pending(handle: *const EventRingHandle) -> usize {
    let result = std::panic::catch_unwind(|| {
        if handle.is_null() {
            return 0;
        }
        // SAFETY: caller contract — handle is live.
        let h = unsafe { &*handle };
        h.ring.pending()
    });
    result.unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn handle_lifecycle_is_balanced() {
        let h = ering_handle_new(8);
        assert!(!h.is_null());
        unsafe {
            ering_handle_retain(h);
            ering_handle_release(h); // counters the retain
            ering_handle_release(h); // counters the original _new
        }
        // If unbalanced, miri / TSan flags. Smoke test: no panic.
    }

    #[test]
    fn handle_zero_capacity_is_null() {
        let h = ering_handle_new(0);
        assert!(h.is_null());
    }

    #[test]
    fn handle_push_and_drain_roundtrip() {
        let h = ering_handle_new(4);
        assert!(!h.is_null());
        let event = GraphEvent::default();
        let pushed = unsafe { ering_handle_try_push(h, &event) };
        assert!(pushed);
        let pending = unsafe { ering_handle_pending(h) };
        assert_eq!(pending, 1);
        let mut out = [GraphEvent::default(); 4];
        let n = unsafe { ering_handle_drain(h, out.as_mut_ptr(), 4) };
        assert_eq!(n, 1);
        unsafe { ering_handle_release(h) };
    }
}
