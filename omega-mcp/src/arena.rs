//! Per-frame bumpalo arena for the MCP dispatcher hot path.
//!
//! Wave 6.2 follow-up of the Extended Program Plan
//! (cross-ref dpp §6.3 + Wave 6 research finding: "one arena per
//! worker thread, NOT one global; Bump is !Sync by design — sharing
//! it requires a Mutex that destroys the win").
//!
//! Mirrors the agent_core/src/arenas/frame.rs pattern. Each crate
//! that wants per-frame allocation gets its own thread_local Bump so
//! the cross-crate path stays direct (no shared Mutex / Arc).
//!
//! ## Use pattern
//!
//! ```ignore
//! use crate::arena;
//!
//! arena::with_frame(|bump| {
//!     // every allocation from `bump` is bump-pointer; no malloc.
//!     // arena is reset (O(1)) before this closure runs.
//! });
//! ```
//!
//! Reset is O(1). Capacity grows once on first heavy frame and stays
//! warm across resets — bumpalo keeps the largest chunk per its
//! documented `Bump::reset` semantics.

use std::cell::RefCell;

use bumpalo::Bump;

/// Initial chunk capacity per worker thread. Sized for the median
/// MCP dispatch (parsed JSON-RPC envelope + a few format buffers).
/// Grows on demand if a single dispatch exceeds it.
pub const FRAME_ARENA_INITIAL_CAPACITY: usize = 4 * 1024;

thread_local! {
    static FRAME_ARENA: RefCell<Bump> =
        RefCell::new(Bump::with_capacity(FRAME_ARENA_INITIAL_CAPACITY));
}

/// Run the closure with a fresh per-thread arena. The arena is reset
/// (bump-pointer rewound to zero) BEFORE the closure runs, so callers
/// always see a freshly empty arena.
///
/// SAFETY: this borrow_muts the thread_local — calling `with_frame`
/// recursively from the same thread (e.g. a tool callback that itself
/// dispatches) panics with "already borrowed". The MCP dispatcher
/// hot path is a LEAF call: parse → route → format → return.
pub fn with_frame<R>(f: impl FnOnce(&Bump) -> R) -> R {
    FRAME_ARENA.with(|cell| {
        let mut arena = cell.borrow_mut();
        arena.reset();
        f(&arena)
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use bumpalo::collections::String as BumpString;

    #[test]
    fn arena_reset_returns_to_same_address() {
        let first = with_frame(|bump| bump.alloc(0u32) as *const u32 as usize);
        let second = with_frame(|bump| bump.alloc(0u32) as *const u32 as usize);
        assert_eq!(
            first, second,
            "after reset, the next same-size alloc must land at the same chunk offset"
        );
    }

    #[test]
    fn arena_supports_bump_string_collection() {
        let length = with_frame(|bump| {
            let mut s: BumpString = BumpString::new_in(bump);
            for i in 0..50 {
                s.push_str(&format!("{i},"));
            }
            s.len()
        });
        assert!(length > 50);
    }

    #[test]
    fn nested_with_frame_panics() {
        let result = std::panic::catch_unwind(|| {
            with_frame(|_outer| {
                with_frame(|_inner| {});
            });
        });
        assert!(
            result.is_err(),
            "nested with_frame on the same thread must panic — leaf frames only"
        );
    }
}
