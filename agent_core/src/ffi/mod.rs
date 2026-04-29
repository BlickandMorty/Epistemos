//! Hot-path FFI surface for Simulation Mode (S4; DOCTRINE I-7,
//! I-8 / IMPLEMENTATION §2.2).
//!
//! Per DOCTRINE I-8 the simulation has three FFI tiers:
//!
//!   1. **UniFFI** — control calls (companion creation, workspace
//!      switch, gift-box unwrap). Low-frequency, ergonomic. Lives
//!      in the simulation layer's `bridge.rs` exports, not here.
//!
//!   2. **SPSC ring buffer** — frame deltas (sprite position,
//!      animation frame, prop, palette tint). >100 Hz. **This
//!      module.** Zero-copy: Rust pushes `PerInstanceData` into
//!      the ring; Swift drains directly into a persistent
//!      `MTLBuffer`-backed pointer; the GPU reads that buffer in
//!      the next vertex shader invocation. UniFFI on this path
//!      is **forbidden** — every per-call serialization tax
//!      compounds at 120 Hz.
//!
//!   3. **IOSurface** — atlas textures (S10). Out of S4 scope.

pub mod delta_ring;
pub mod per_instance;

pub use delta_ring::{DeltaRing, DELTA_RING_DEFAULT_CAPACITY};
pub use per_instance::{PerInstanceData, StateFlags};
