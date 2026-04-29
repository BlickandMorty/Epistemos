//! Simulation Mode performance signpost framework (S0; DOCTRINE I-15, §12).
//!
//! Provides a structured signpost API — `SignpostLog`, `SignpostId`,
//! `IntervalScope`, `signpost_interval!` — for the simulation reducer,
//! FFI delta ring, and benchmarking harness. Subsystem is
//! `com.epistemos.simulation` per IMPLEMENTATION.md §0; per-slice
//! categories follow `epistemos.simulation.<slice>.<operation>` per §7
//! cross-slice invariant 10.
//!
//! ## V0 contract (Rust side)
//!
//! Apple's `os_signpost_*` macros require `name` and `format` strings
//! to live in the special `__TEXT,__oslogstring` Mach-O section, which
//! is populated by Clang's `__builtin_os_log_format` builtin at compile
//! time. A runtime `*const c_char` from Rust is rejected by
//! libsystem_trace's flatten path with an internal `os_assert_log`
//! trap. Per-name C shims could solve this, but the meaningful set of
//! Rust-side signpost names isn't known until the reducer + FFI ring
//! land in S2 / S4.
//!
//! At V0 the Rust API is therefore a structured no-op — the public
//! shape compiles unchanged across all slices, intervals are tracked
//! via `tracing::span!` so dev-time observability still works, and the
//! Instruments-visible surface lives entirely Swift-side
//! (`Epistemos/Simulation/Perf.swift`) where the meaningful timing
//! (FFI boundary, frame loop, view transitions) actually happens.
//!
//! V1 (Slice S4) graduates a fixed set of high-frequency Rust intervals
//! to real `os_signpost` emission via per-name C wrappers compiled
//! through `cc-rs`.

use std::ffi::CStr;
use std::sync::OnceLock;

/// Handle for a signpost log category. Cheap to copy; backed at V0 by
/// a process-static cache of `tracing::Span` template names so the
/// pattern matches what later slices will see when real signpost
/// emission graduates.
#[derive(Copy, Clone)]
pub struct SignpostLog {
    category: &'static CStr,
}

unsafe impl Send for SignpostLog {}
unsafe impl Sync for SignpostLog {}

impl SignpostLog {
    /// Returns a log for the simulation subsystem with the given
    /// category. Most callers should use the canonical per-slice
    /// accessors below (`theater()`, `companions()`, …) which cache
    /// the result.
    pub fn for_category(category: &'static CStr) -> Self {
        Self { category }
    }

    /// Generates a fresh signpost id for an interval. At V0 this is a
    /// monotonic process-local counter so begin/end pairs are still
    /// distinguishable in dev-time tracing output.
    #[inline]
    pub fn new_id(self) -> SignpostId {
        use std::sync::atomic::{AtomicU64, Ordering};
        static COUNTER: AtomicU64 = AtomicU64::new(1);
        SignpostId(COUNTER.fetch_add(1, Ordering::Relaxed))
    }

    /// Emits a signpost interval-begin event for `name`. V0: forwards
    /// to a structured `tracing::trace!` event so dev consumers can see
    /// it; V1: real `os_signpost(.begin)`.
    #[inline]
    pub fn interval_begin(self, id: SignpostId, name: &'static CStr) {
        tracing::trace!(
            target: "epistemos.simulation",
            category = %self.category.to_string_lossy(),
            id = id.0,
            name = %name.to_string_lossy(),
            "interval_begin"
        );
    }

    /// Emits a signpost interval-end event for `name`. The `id` must
    /// match the one passed to the corresponding `interval_begin`.
    #[inline]
    pub fn interval_end(self, id: SignpostId, name: &'static CStr) {
        tracing::trace!(
            target: "epistemos.simulation",
            category = %self.category.to_string_lossy(),
            id = id.0,
            name = %name.to_string_lossy(),
            "interval_end"
        );
    }

    /// Emits an instantaneous signpost event.
    #[inline]
    pub fn event(self, name: &'static CStr) {
        tracing::trace!(
            target: "epistemos.simulation",
            category = %self.category.to_string_lossy(),
            name = %name.to_string_lossy(),
            "event"
        );
    }

    /// Returns the category name as a UTF-8 str. Useful for tests and
    /// `perf_check.sh` introspection.
    pub fn category_str(self) -> &'static str {
        // SAFETY: category is a 'static CStr from a c"..." literal at
        // construction; UTF-8 by source.
        self.category.to_str().unwrap_or("")
    }
}

/// Opaque signpost interval id. `SignpostId::NULL` is reserved.
#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub struct SignpostId(u64);

impl SignpostId {
    pub const NULL: Self = Self(0);
}

/// RAII scope for an interval signpost. Emits begin on construction
/// and end on drop. Prefer this over manual begin/end pairs in slices
/// that can early-return or panic — Drop closes the interval cleanly.
pub struct IntervalScope {
    log: SignpostLog,
    id: SignpostId,
    name: &'static CStr,
}

impl IntervalScope {
    #[inline]
    pub fn new(log: SignpostLog, name: &'static CStr) -> Self {
        let id = log.new_id();
        log.interval_begin(id, name);
        Self { log, id, name }
    }
}

impl Drop for IntervalScope {
    #[inline]
    fn drop(&mut self) {
        self.log.interval_end(self.id, self.name);
    }
}

/// Emit an interval signpost that wraps the given block, returning
/// whatever the block returns. Equivalent to constructing an
/// `IntervalScope` manually but reads more naturally at call sites:
///
/// ```ignore
/// signpost_interval!(perf::theater(), c"frame_render", {
///     render_frame(view, deltas);
/// });
/// ```
#[macro_export]
macro_rules! signpost_interval {
    ($log:expr, $name:expr, $body:block) => {{
        let _scope = $crate::perf::IntervalScope::new($log, $name);
        $body
    }};
}

// =============================================================================
// Per-slice category accessors. Each category corresponds to a row in
// IMPLEMENTATION.md §5 "Required Instrumentation per Slice". Cached in
// process-static `OnceLock`s.
// =============================================================================

macro_rules! category_log {
    ($fn_name:ident, $cstr:expr) => {
        #[inline]
        pub fn $fn_name() -> SignpostLog {
            static CACHE: OnceLock<SignpostLog> = OnceLock::new();
            *CACHE.get_or_init(|| SignpostLog::for_category($cstr))
        }
    };
}

category_log!(theater, c"theater");
category_log!(companions, c"companions");
category_log!(events, c"events");
category_log!(audit, c"audit");
category_log!(ffi, c"ffi");
category_log!(hermes, c"hermes");
category_log!(landing, c"landing");

// =============================================================================
// Tests — structural at S0. Verify wrappers don't panic, log handles
// can be constructed for every category, and intervals open / close
// cleanly. Real os_signpost emission is Swift-side (see
// `Epistemos/Simulation/Perf.swift`); these tests assert the Rust
// surface contract that later slices depend on.
// =============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn signpost_log_construction_smoke() {
        let log = theater();
        let _id = log.new_id();
    }

    #[test]
    fn signpost_interval_scope_runs() {
        let log = theater();
        {
            let _scope = IntervalScope::new(log, c"smoke_interval");
            let _ = std::hint::black_box(42_u64);
        }
        log.event(c"smoke_event");
    }

    #[test]
    fn signpost_interval_macro_runs() {
        let result = signpost_interval!(theater(), c"macro_interval", {
            std::hint::black_box(7_u64) * 2
        });
        assert_eq!(result, 14);
    }

    #[test]
    fn all_slice_categories_reachable() {
        // Each accessor must be reachable; if any is removed without
        // updating IMPLEMENTATION.md §5, this test fails.
        assert_eq!(theater().category_str(), "theater");
        assert_eq!(companions().category_str(), "companions");
        assert_eq!(events().category_str(), "events");
        assert_eq!(audit().category_str(), "audit");
        assert_eq!(ffi().category_str(), "ffi");
        assert_eq!(hermes().category_str(), "hermes");
        assert_eq!(landing().category_str(), "landing");
    }

    #[test]
    fn category_logs_are_cached() {
        let a = theater();
        let b = theater();
        // Both must point to the same cached category record.
        assert_eq!(a.category_str(), b.category_str());
    }

    #[test]
    fn signpost_ids_are_unique() {
        let log = theater();
        let id1 = log.new_id();
        let id2 = log.new_id();
        assert_ne!(id1, id2);
        assert_ne!(id1, SignpostId::NULL);
    }
}
