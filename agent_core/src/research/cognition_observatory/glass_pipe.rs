//! Source:
//! - `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3.26 —
//!   "ActivationInterceptor 'Glass Pipe' (injected Metal compute kernel
//!   + ring buffer + atomic write index)".
//! - `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md`
//!   — full Glass Pipe spec (injected MTLComputePipelineState that copies
//!   activations into a `device float*` ring buffer with `atomic_uint`
//!   write index; Swift control-room reader walks the ring asynchronously).
//!
//! # Wave J2 sub-feature #2 — Glass Pipe (ActivationInterceptor)
//!
//! Fixed-size circular buffer with an atomic write index. The Metal-side
//! kernel writes into the buffer with `atomic_fetch_add_explicit` on the
//! write index; the Swift control-room reader walks back from the current
//! write index to read the last N samples.
//!
//! The Rust mirror here is the substrate floor for the control-room
//! reader (the Metal write half lives in Swift / Metal). It uses
//! [`std::sync::atomic::AtomicUsize`] for the write index so multiple
//! Rust-side writers (e.g. a Rust runtime that calls into Metal via FFI
//! and also writes via Rust) can share the buffer without locking.
//!
//! ## Difference from J1 #6 [`super::super::ternary::activation_tap`]
//!
//! - **ActivationTap** (J1 #6): per-step snapshots, single-thread
//!   `VecDeque`, FIFO eviction at capacity. Suited for control-room
//!   replay where each call site logs one snapshot per step.
//! - **Glass Pipe** (J2 #2): per-element streaming into a flat ring with
//!   atomic write index. Suited for the hot-path Metal kernel that
//!   writes thousands of fp32 values per token without per-write
//!   allocations or per-write locks.

use serde::{Deserialize, Serialize};
use std::sync::atomic::{AtomicUsize, Ordering};

#[derive(Debug)]
pub struct GlassPipe {
    capacity: usize,
    buffer: Vec<f32>,
    write_index: AtomicUsize,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum GlassPipeError {
    ZeroCapacity,
    /// `read_recent(n)` was called with `n > capacity`. The reader can
    /// only see at most `capacity` samples.
    ReadOverflow { requested: usize, capacity: usize },
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct GlassPipeReadout {
    /// Samples in oldest-to-newest order. Length `<= capacity` always.
    pub samples: Vec<f32>,
    /// Absolute write index at the time of the readout. Lets a polling
    /// reader detect dropped samples by comparing against the previous
    /// readout's `write_index`.
    pub write_index: usize,
}

impl GlassPipe {
    pub fn new(capacity: usize) -> Result<Self, GlassPipeError> {
        if capacity == 0 {
            return Err(GlassPipeError::ZeroCapacity);
        }
        Ok(Self {
            capacity,
            buffer: vec![0.0; capacity],
            write_index: AtomicUsize::new(0),
        })
    }

    pub fn capacity(&self) -> usize {
        self.capacity
    }

    pub fn write_index(&self) -> usize {
        self.write_index.load(Ordering::Acquire)
    }

    /// Write one sample. Returns the absolute write index assigned to
    /// this sample. Safe to call concurrently from multiple writers as
    /// long as each writer respects the slot lifecycle (no destructive
    /// writes mid-read).
    ///
    /// Per `EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md`, the Metal kernel
    /// is responsible for the same atomic-fetch-add pattern. This Rust
    /// path mirrors that contract so a hybrid Rust+Metal pipeline can
    /// share one [`GlassPipe`].
    pub fn write(&mut self, value: f32) -> usize {
        let idx = self.write_index.fetch_add(1, Ordering::AcqRel);
        let slot = idx % self.capacity;
        self.buffer[slot] = value;
        idx
    }

    /// Read the last `n` samples in oldest-to-newest order. Errors if
    /// `n > capacity`. If fewer than `n` samples have been written so far,
    /// the returned `samples` length equals the actual write count.
    pub fn read_recent(&self, n: usize) -> Result<GlassPipeReadout, GlassPipeError> {
        if n > self.capacity {
            return Err(GlassPipeError::ReadOverflow {
                requested: n,
                capacity: self.capacity,
            });
        }
        let write_index = self.write_index.load(Ordering::Acquire);
        let count = n.min(write_index);
        let mut samples = Vec::with_capacity(count);
        if count == 0 {
            return Ok(GlassPipeReadout { samples, write_index });
        }
        let start = write_index - count;
        for i in 0..count {
            let slot = (start + i) % self.capacity;
            samples.push(self.buffer[slot]);
        }
        Ok(GlassPipeReadout { samples, write_index })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zero_capacity_rejected() {
        let err = GlassPipe::new(0).unwrap_err();
        assert_eq!(err, GlassPipeError::ZeroCapacity);
    }

    #[test]
    fn write_index_increments_per_write() {
        let mut pipe = GlassPipe::new(4).unwrap();
        for i in 0..3 {
            let idx = pipe.write(i as f32);
            assert_eq!(idx, i);
        }
        assert_eq!(pipe.write_index(), 3);
    }

    #[test]
    fn read_before_any_write_returns_empty_samples() {
        let pipe = GlassPipe::new(4).unwrap();
        let r = pipe.read_recent(3).unwrap();
        assert!(r.samples.is_empty());
        assert_eq!(r.write_index, 0);
    }

    #[test]
    fn read_recent_after_partial_fill_returns_actual_count() {
        let mut pipe = GlassPipe::new(4).unwrap();
        pipe.write(10.0);
        pipe.write(20.0);
        let r = pipe.read_recent(3).unwrap();
        assert_eq!(r.samples, vec![10.0, 20.0]);
        assert_eq!(r.write_index, 2);
    }

    #[test]
    fn read_recent_after_wraparound_returns_last_n() {
        let mut pipe = GlassPipe::new(4).unwrap();
        for v in 0..10 {
            pipe.write(v as f32);
        }
        let r = pipe.read_recent(4).unwrap();
        assert_eq!(r.samples, vec![6.0, 7.0, 8.0, 9.0]);
        assert_eq!(r.write_index, 10);
    }

    #[test]
    fn read_overflow_errors() {
        let pipe = GlassPipe::new(3).unwrap();
        let err = pipe.read_recent(4).unwrap_err();
        assert_eq!(err, GlassPipeError::ReadOverflow { requested: 4, capacity: 3 });
    }

    #[test]
    fn write_index_persists_across_wraparound() {
        let mut pipe = GlassPipe::new(2).unwrap();
        for _ in 0..5 {
            pipe.write(1.0);
        }
        assert_eq!(pipe.write_index(), 5);
    }

    #[test]
    fn readout_serializes_through_serde_json() {
        let mut pipe = GlassPipe::new(3).unwrap();
        pipe.write(1.0);
        pipe.write(2.0);
        let r = pipe.read_recent(2).unwrap();
        let json = serde_json::to_string(&r).unwrap();
        let back: GlassPipeReadout = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn read_recent_zero_returns_empty_with_current_index() {
        let mut pipe = GlassPipe::new(4).unwrap();
        pipe.write(99.0);
        let r = pipe.read_recent(0).unwrap();
        assert!(r.samples.is_empty());
        assert_eq!(r.write_index, 1);
    }
}
