//! Epistenos Agent Core — shared substrate for the Vault-Gated Agent Swarm.
//!
//! This crate provides the foundational data structures and IPC primitives that
//! enable the main app, XPC services, and simulation companion to share state
//! inside the macOS App Sandbox.  All shared memory is file-backed (mmap)
//! inside the App Group container — never `shm_open`, which is prohibited by
//! Mac App Store review.
//!
//! ## Modules
//!
//! - `arena` — Zero-copy ring buffer mapped into shared memory.  Used by the
//!   control plane (XPC messages carry only sequence numbers; payloads live here).
//! - `arena::container` — App Group container path resolution via `NSFileManager`.
//!
//! ## Safety
//!
//! Every `unsafe` block has a `// SAFETY:` comment.  The crate relies on
//! `#[repr(C)]` layouts and atomic Release-Acquire ordering for lock-free
//! single-producer / single-consumer rings.

#![deny(unused_crate_dependencies)]
#![deny(unused_must_use)]
#![warn(missing_docs)]

pub mod arena;

// Re-export the most common types for downstream convenience.
pub use arena::{
    Arena, ArenaHeader, ArenaError, ArtefactRef, MappedArena, RequestSlot,
    ResponseSlot, MAX_ARTEFACT_REFS, INLINE_REQ_BYTES, INLINE_RSP_BYTES,
    SLOT_COUNT, ARENA_MAGIC, ARENA_VERSION, STATE_PENDING, STATE_READY,
    STATE_CONSUMED,
};
pub use arena::container::AppGroupContainer;
