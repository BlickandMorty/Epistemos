//! Thread-local per-frame `bumpalo::Bump` arena.
//!
//! Per Wave 6 plan dpp §6.3 + canonical research finding:
//! "One arena per worker thread, NOT one global. `Bump` is `!Sync` by
//! design — sharing it requires a `Mutex` that destroys the win."

use std::cell::RefCell;

use bumpalo::Bump;

/// Initial capacity for each thread's frame arena. Sized to cover a
/// typical MCP dispatch call (parsed JSON sub-tree + a few format
/// buffers + scratch strings). Smaller per-thread footprint than the
/// dpp's "16 MB per frame" target because we have many worker threads;
/// each arena grows on demand if a single call exceeds this.
///
/// Sized for the median tool call: a 4 KB initial allocation covers
/// the dispatcher header + small payload without immediately requiring
/// a chunk grow.
pub const FRAME_ARENA_INITIAL_CAPACITY: usize = 4 * 1024;

thread_local! {
    static FRAME_ARENA: RefCell<Bump> =
        RefCell::new(Bump::with_capacity(FRAME_ARENA_INITIAL_CAPACITY));
}

/// Run the closure with a fresh per-thread frame arena. The arena is
/// reset (bump-pointer rewound to zero) BEFORE the closure runs, so
/// callers always see a freshly empty arena.
///
/// Reset is O(1) — bumpalo just moves the pointer back, the underlying
/// chunk storage is reused. Allocations from previous frames become
/// invalid the moment `with_frame` returns; the borrow checker enforces
/// the lifetime contract via the `&Bump` reference passed to the closure.
///
/// The arena's allocated chunk capacity GROWS over time as it sees
/// larger frames, but never shrinks. After a few hot frames the arena
/// reaches steady-state capacity and no further chunk allocations occur.
///
/// SAFETY: this is `RefCell::borrow_mut` on a thread-local — calling
/// `with_frame` recursively from the same thread (e.g. a tool callback
/// that itself calls `with_frame`) panics with "already borrowed".
/// The hot paths that use this are LEAF frames: dispatch a tool, format
/// a response, return.
pub fn with_frame<R>(f: impl FnOnce(&Bump) -> R) -> R {
    FRAME_ARENA.with(|arena_cell| {
        let mut arena = arena_cell.borrow_mut();
        arena.reset();
        f(&arena)
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use bumpalo::collections::String as BumpString;

    #[test]
    fn frame_arena_resets_between_calls() {
        // Reset semantics are best verified via address-equality: after
        // reset, the SAME-size allocation should land at the SAME
        // address inside the same warm chunk (bump pointer rewound).
        // bumpalo's `allocated_bytes()` reports CHUNK CAPACITY, not
        // current usage — that's why `reset` is O(1) (chunks reused,
        // not freed) and why `allocated_bytes` doesn't drop after reset.

        let first_addr = with_frame(|arena| {
            let slot: &mut u32 = arena.alloc(0u32);
            slot as *const u32 as usize
        });
        let second_addr = with_frame(|arena| {
            let slot: &mut u32 = arena.alloc(0u32);
            slot as *const u32 as usize
        });
        assert_eq!(
            first_addr, second_addr,
            "after reset, the next same-size alloc must land at the same chunk offset (bump-pointer rewind)"
        );
    }

    #[test]
    fn frame_arena_handles_large_then_small_alloc_cycle() {
        // Force a large allocation, then reset, then a tiny one — the
        // call sequence must not panic. bumpalo 3.16's `reset()` keeps
        // the LARGEST chunk and drops smaller ones, so total capacity
        // may either rise or fall after reset; we only assert that
        // subsequent allocations continue to work without panic.
        with_frame(|arena| {
            let _giant: bumpalo::collections::Vec<u8> =
                bumpalo::collections::Vec::with_capacity_in(64 * 1024, arena);
        });
        let small_succeeded = with_frame(|arena| {
            let mut s: BumpString = BumpString::new_in(arena);
            s.push_str("hi");
            !s.is_empty()
        });
        assert!(small_succeeded);
    }

    #[test]
    fn frame_arena_strings_can_be_built_inside_closure() {
        let length = with_frame(|arena| {
            let mut s: BumpString = BumpString::new_in(arena);
            for i in 0..100 {
                s.push_str(&format!("{i},"));
            }
            s.len()
        });
        assert!(length > 100, "BumpString should accept many push_str calls");
    }

    #[test]
    fn nested_with_frame_panics() {
        let result = std::panic::catch_unwind(|| {
            with_frame(|_outer| {
                with_frame(|_inner| {
                    // Should panic: RefCell::borrow_mut on already-borrowed.
                });
            });
        });
        assert!(
            result.is_err(),
            "nested with_frame on the same thread must panic — leaf frames only"
        );
    }

    #[test]
    fn separate_threads_have_independent_arenas() {
        use std::sync::atomic::{AtomicUsize, Ordering};
        use std::sync::Arc;
        use std::thread;

        let counter = Arc::new(AtomicUsize::new(0));
        let mut handles = vec![];
        for _ in 0..4 {
            let c = Arc::clone(&counter);
            let handle = thread::spawn(move || {
                with_frame(|arena| {
                    let _v: bumpalo::collections::Vec<u32> =
                        bumpalo::collections::Vec::with_capacity_in(256, arena);
                    c.fetch_add(arena.allocated_bytes(), Ordering::SeqCst);
                });
            });
            handles.push(handle);
        }
        for h in handles {
            h.join().unwrap();
        }
        // Four threads each made non-zero allocations independently.
        assert!(counter.load(Ordering::SeqCst) > 0);
    }
}
