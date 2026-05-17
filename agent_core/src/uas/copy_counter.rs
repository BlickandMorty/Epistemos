//! `copy_counter` — substrate-floor allocator + copy tracking for the
//! F-UAS-ZeroCopy-Spine harness.
//!
//! Source:
//! - Driver §4.G ladder gate #2 + canonical doctrine §4 + falsifier
//!   `docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md` §2 + §4.
//! - Phase B blueprint `docs/audits/UAS_ACS_PHASE_B_BLUEPRINT_2026_05_17.md`
//!   §2.2 iter 30 → landed at iter 32 (reordered).
//!
//! # Phase B.G.B2 substrate
//!
//! Two complementary counting surfaces:
//!
//! 1. **Manual `track_copy` / `track_alloc` helpers**. Hot-path code suspected
//!    of copying can call these explicitly for discipline. Tests assert
//!    `current_copy_count() == 0` after running. This is the documentation-
//!    grade signal: production code should NEVER call `track_copy` on a hot
//!    path.
//!
//! 2. **`CountingAllocator` newtype wrapping `std::alloc::System`**. Test
//!    binaries can opt in via:
//!
//!    ```ignore
//!    #[global_allocator]
//!    static A: CountingAllocator = CountingAllocator::new();
//!    ```
//!
//!    Every allocation routed through `System` increments
//!    `current_alloc_count()`. The path-1 / path-2 / ... F-UAS-ZeroCopy
//!    integration tests (iter 33+) declare this allocator and assert
//!    zero allocations on designated hot paths.
//!
//! # The `with_tracking` block
//!
//! ```ignore
//! let (result, stats) = uas::copy_counter::with_tracking(|| {
//!     embedding_query(&buf)
//! });
//! assert_eq!(stats.copy_count, 0, "embedding_query must be zero-copy");
//! assert_eq!(stats.alloc_count, 0, "embedding_query must be allocation-free");
//! ```

use std::alloc::{GlobalAlloc, Layout, System};
use std::cell::Cell;
use std::sync::atomic::{AtomicUsize, Ordering};

thread_local! {
    static COPY_COUNT: Cell<usize> = const { Cell::new(0) };
}

// Allocator counters MUST be process-wide atomics — Rust's allocator runs
// before thread-locals are guaranteed initialized, so thread-local counters
// would panic or miscount during early allocations. Process-wide is the
// honest choice; per-test isolation is achieved by `reset_counters()` at
// iteration boundaries.
static ALLOC_COUNT: AtomicUsize = AtomicUsize::new(0);
static DEALLOC_COUNT: AtomicUsize = AtomicUsize::new(0);
static BYTES_ALLOCATED: AtomicUsize = AtomicUsize::new(0);

/// Increment the per-thread copy counter. Call from hot-path code suspected
/// of copying.
pub fn track_copy() {
    COPY_COUNT.with(|c| c.set(c.get().saturating_add(1)));
}

/// Number of times `track_copy` has been called on this thread since the
/// last `reset_counters` call.
pub fn current_copy_count() -> usize {
    COPY_COUNT.with(|c| c.get())
}

/// Number of allocations routed through `CountingAllocator` since the last
/// `reset_counters` call. Returns 0 if `CountingAllocator` is not the global
/// allocator for the current binary.
pub fn current_alloc_count() -> usize {
    ALLOC_COUNT.load(Ordering::Relaxed)
}

/// Number of deallocations routed through `CountingAllocator`.
pub fn current_dealloc_count() -> usize {
    DEALLOC_COUNT.load(Ordering::Relaxed)
}

/// Bytes allocated through `CountingAllocator` since last reset.
pub fn current_bytes_allocated() -> usize {
    BYTES_ALLOCATED.load(Ordering::Relaxed)
}

/// Reset both the thread-local copy counter and the process-wide allocator
/// counters. Call at iteration boundaries in the F-UAS-ZeroCopy-Spine
/// harness.
pub fn reset_counters() {
    COPY_COUNT.with(|c| c.set(0));
    ALLOC_COUNT.store(0, Ordering::Relaxed);
    DEALLOC_COUNT.store(0, Ordering::Relaxed);
    BYTES_ALLOCATED.store(0, Ordering::Relaxed);
}

/// Snapshot of every counter at a moment in time.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct CopyStats {
    pub copy_count: usize,
    pub alloc_count: usize,
    pub dealloc_count: usize,
    pub bytes_allocated: usize,
}

impl CopyStats {
    /// Capture the current values of every counter.
    pub fn capture() -> Self {
        Self {
            copy_count: current_copy_count(),
            alloc_count: current_alloc_count(),
            dealloc_count: current_dealloc_count(),
            bytes_allocated: current_bytes_allocated(),
        }
    }

    /// `true` if no copies AND no allocations happened.
    pub fn is_zero_copy_and_zero_alloc(&self) -> bool {
        self.copy_count == 0 && self.alloc_count == 0
    }
}

/// Run `f` with counters reset to 0; return `(f result, counter delta)`.
pub fn with_tracking<F, R>(f: F) -> (R, CopyStats)
where
    F: FnOnce() -> R,
{
    reset_counters();
    let result = f();
    let stats = CopyStats::capture();
    (result, stats)
}

/// Counting allocator wrapping `std::alloc::System`. Opt-in by declaring as
/// `#[global_allocator]` in a test binary.
///
/// # Safety
///
/// This allocator delegates every call to `System`; safety properties are
/// inherited unchanged. Counters are process-wide atomics so multi-thread
/// allocation is correctly counted.
pub struct CountingAllocator;

impl CountingAllocator {
    /// Construct a fresh allocator instance.
    pub const fn new() -> Self {
        Self
    }
}

impl Default for CountingAllocator {
    fn default() -> Self {
        Self::new()
    }
}

unsafe impl GlobalAlloc for CountingAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let p = unsafe { System.alloc(layout) };
        if !p.is_null() {
            ALLOC_COUNT.fetch_add(1, Ordering::Relaxed);
            BYTES_ALLOCATED.fetch_add(layout.size(), Ordering::Relaxed);
        }
        p
    }

    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        unsafe { System.dealloc(ptr, layout) };
        DEALLOC_COUNT.fetch_add(1, Ordering::Relaxed);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn track_copy_increments_thread_local() {
        reset_counters();
        assert_eq!(current_copy_count(), 0);
        track_copy();
        track_copy();
        track_copy();
        assert_eq!(current_copy_count(), 3);
    }

    #[test]
    fn reset_counters_zeros_copy_count() {
        track_copy();
        track_copy();
        assert!(current_copy_count() >= 2);
        reset_counters();
        assert_eq!(current_copy_count(), 0);
    }

    #[test]
    fn with_tracking_captures_delta() {
        let (result, stats) = with_tracking(|| {
            track_copy();
            track_copy();
            42
        });
        assert_eq!(result, 42);
        assert_eq!(stats.copy_count, 2);
    }

    #[test]
    fn copy_stats_is_zero_predicate() {
        let zero = CopyStats::default();
        assert!(zero.is_zero_copy_and_zero_alloc());
        let with_copy = CopyStats { copy_count: 1, ..Default::default() };
        assert!(!with_copy.is_zero_copy_and_zero_alloc());
        let with_alloc = CopyStats { alloc_count: 1, ..Default::default() };
        assert!(!with_alloc.is_zero_copy_and_zero_alloc());
    }

    #[test]
    fn counting_allocator_is_constructible() {
        // Substrate-floor smoke test: the allocator type exists and is
        // const-constructible. Production wire-up via #[global_allocator]
        // declaration in test binaries lives in those binaries; this
        // module ships the type.
        const _A: CountingAllocator = CountingAllocator::new();
        let _b: CountingAllocator = Default::default();
    }

    #[test]
    fn with_tracking_returns_function_result() {
        let (greeting, _) = with_tracking(|| "hello".to_string());
        // `to_string` does an allocation — visible in alloc_count IF the
        // global_allocator is CountingAllocator, but here it isn't (lib
        // tests use System directly). The result is what we're checking.
        assert_eq!(greeting, "hello");
    }
}
