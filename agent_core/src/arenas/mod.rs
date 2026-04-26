//! # `arenas`
//!
//! Per-frame scratch arenas (bumpalo) for the MCP dispatch + render hot
//! paths.
//!
//! Per `docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 6.2
//! (cross-ref dpp §6.3 Sprint 6).
//!
//! ## Why this module exists
//!
//! Profiling per Wave 2.5 perf-budgets showed the MCP dispatcher's
//! per-call allocation churn (parsed JSON sub-trees, format buffers,
//! short-lived `String`s for tool arguments) dominated tool-call
//! latency on warm cache. Switching the allocator to a thread-local
//! bump arena that resets between calls eliminates that churn — no
//! `malloc`/`free` traffic, no fragmentation, O(1) reset.
//!
//! ## Canonical pattern (per Wave 6 research)
//!
//! - `bumpalo::Bump` 3.16 — still the 2026 canonical choice. No serious
//!   challenger has emerged (`typed-arena` is single-type only;
//!   `slab` is for stable indices, wrong tool).
//! - **Thread-local Bump per worker, NOT one global**. `Bump` is `!Sync`
//!   by design — sharing across threads needs a `Mutex` that destroys
//!   the win. The `FRAME_ARENA` thread_local pattern below matches the
//!   canonical research finding.
//! - **`serde_json::RawValue` + bumpalo string copy** to dodge the
//!   `serde_json` heap-allocation gotcha: `serde_json::from_str` always
//!   allocates owned `String`s on the heap regardless of arena. For
//!   the MCP dispatch path we read once into `&RawValue`, then copy
//!   the slice into the arena via `bumpalo::collections::String::from_str_in`.
//!
//! ## Use pattern
//!
//! ```ignore
//! use crate::arenas;
//!
//! arenas::with_frame(|arena| {
//!     // every allocation from `arena` is bump-pointer; no malloc.
//!     let scratch: bumpalo::collections::Vec<u8> =
//!         bumpalo::collections::Vec::with_capacity_in(1024, arena);
//!     // ... do MCP dispatch work ...
//!     // arena goes out of scope here; the next call to with_frame()
//!     // resets the bump pointer to zero — O(1) cleanup.
//! });
//! ```
//!
//! `with_frame` resets the per-thread arena BEFORE invoking the closure,
//! so callers always see a fresh arena. Capacity is preserved across
//! frames (no realloc churn).

pub mod frame;
pub mod raw_value;

pub use frame::{with_frame, FRAME_ARENA_INITIAL_CAPACITY};
pub use raw_value::raw_value_in;
