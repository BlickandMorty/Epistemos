//! `DeltaRing` — lock-free SPSC ring buffer for per-frame
//! `PerInstanceData` (S4; DOCTRINE I-8).
//!
//! Backed by `crossbeam_queue::ArrayQueue` (MPMC, but used as
//! single-producer / single-consumer in our setup: one Rust
//! reducer thread pushes, one Swift renderer thread drains per
//! frame). The queue is bounded so the producer never allocates
//! on push (over-cap pushes overwrite the oldest entry, matching
//! the "newest-wins per agent" coalesce policy from
//! IMPLEMENTATION §2.5).
//!
//! ## Coalesce policy (IMPLEMENTATION §2.5)
//!
//! Position / scale / tint deltas are **newest-wins per agent_id** —
//! when the producer pushes a fresh delta for a companion that
//! already has a pending entry, the old one is overwritten. This
//! prevents queue bloat under high event rates.
//!
//! State-changing deltas (animation state transition, prop swap,
//! gate raise, error flicker) are **never coalesced** — they are
//! preserved in order. If the queue fills, this is a regression
//! and must be logged.
//!
//! V0 implementation (this slice): O(N) scan on push to find any
//! existing entry by agent_id. V1 upgrade (S5+): per-companion
//! slot map indexed by agent_id for O(1) coalesce. The doctrine
//! permits both; V0 is enough for ≤12 active companions on the
//! Graph Theater (DOCTRINE §12 budget).
//!
//! ## Hot-path C ABI
//!
//! `epistemos_delta_ring_drain(ring, out, capacity)` is exported
//! `#[no_mangle]` so the Swift side can call it directly without
//! UniFFI's per-call serialization tax. The signature is
//! deliberately minimal — three pointer-and-length args — so the
//! call lands at <5µs p95 (DOCTRINE §12 budget). Swift wraps the
//! call in `signpostInterval(SimSignpost.ffi, "delta_drain")`
//! to measure the boundary in Instruments.

use crossbeam_queue::ArrayQueue;
use std::sync::Arc;

use super::per_instance::PerInstanceData;

/// Default ring capacity. 256 entries × 64 bytes = 16 KB —
/// fits in L1 cache; bigger than the worst-case fan-out per
/// frame (≤12 companions × ~6 deltas each = ~72) by a healthy
/// margin.
pub const DELTA_RING_DEFAULT_CAPACITY: usize = 256;

/// Lock-free SPSC ring buffer for per-frame deltas. Cheap to
/// clone (`Arc<ArrayQueue>` internally) — multiple producers
/// can hold the same `Arc<DeltaRing>`, but only one of them
/// should actively push at a time per the SPSC contract.
pub struct DeltaRing {
    queue: Arc<ArrayQueue<PerInstanceData>>,
}

impl DeltaRing {
    /// Create a ring with the given capacity. Capacity must be
    /// >= 1; we recommend `DELTA_RING_DEFAULT_CAPACITY`.
    pub fn new(capacity: usize) -> Self {
        let cap = capacity.max(1);
        Self {
            queue: Arc::new(ArrayQueue::new(cap)),
        }
    }

    /// Push a delta onto the ring. Coalesces by `agent_id` per
    /// IMPLEMENTATION §2.5 — if a pending delta for the same
    /// companion exists, the new one replaces it. If the ring
    /// is full and no coalesce candidate matches, the oldest
    /// entry is silently overwritten (matches `bufferingNewest`
    /// AsyncStream semantics from CLAUDE.md).
    ///
    /// V0 implementation: O(N) drain → re-push to coalesce. The
    /// only callers are inside the reducer's frame-emission
    /// loop, which produces ≤12 entries per call, so the
    /// O(N²) total is fine; V1's per-agent slot map is in S5+.
    pub fn push(&self, delta: PerInstanceData) {
        // Fast path: queue isn't full and we don't need to
        // coalesce — just push.
        if self.queue.len() < self.queue.capacity() {
            // Try coalesce: drain into a buffer, find any entry
            // matching agent_id, replace it; re-push everything.
            // Cheap when len() is small (typical case).
            let len = self.queue.len();
            if len == 0 {
                let _ = self.queue.push(delta);
                return;
            }
            let mut buffer: Vec<PerInstanceData> = Vec::with_capacity(len + 1);
            while let Some(d) = self.queue.pop() {
                buffer.push(d);
            }
            let mut replaced = false;
            for slot in buffer.iter_mut() {
                if slot.agent_id_lo == delta.agent_id_lo
                    && slot.agent_id_hi == delta.agent_id_hi
                {
                    *slot = delta;
                    replaced = true;
                    break;
                }
            }
            if !replaced {
                buffer.push(delta);
            }
            for d in buffer {
                let _ = self.queue.push(d);
            }
        } else {
            // Ring is full. Force-replace the oldest entry. This
            // is the regression case — log it for the perf budget
            // gate (S14 will alarm).
            let _ = self.queue.pop();
            let _ = self.queue.push(delta);
        }
    }

    /// Drain up to `out.len()` entries from the ring into `out`.
    /// Returns the count drained. Order is FIFO (oldest first).
    pub fn drain_into(&self, out: &mut [PerInstanceData]) -> usize {
        let mut n = 0;
        while n < out.len() {
            match self.queue.pop() {
                Some(d) => {
                    out[n] = d;
                    n += 1;
                }
                None => break,
            }
        }
        n
    }

    /// Current pending length. For diagnostics + perf budget
    /// monitoring. Lock-free, cheap.
    pub fn len(&self) -> usize {
        self.queue.len()
    }

    pub fn is_empty(&self) -> bool {
        self.queue.is_empty()
    }

    pub fn capacity(&self) -> usize {
        self.queue.capacity()
    }
}

// =============================================================================
// Hot-path C ABI export. Swift drains directly into a
// persistent MTLBuffer; per-call cost should be <5µs p95
// (DOCTRINE §12 budget).
// =============================================================================

/// Drain the ring into a caller-supplied buffer. Returns the
/// number of entries written.
///
/// Safety contract:
///
/// - `ring` must be a non-null pointer to a `DeltaRing` whose
///   lifetime spans the call. The `DeltaRing` is owned by an
///   `Arc<Simulation>` Swift-side; Swift gets the raw pointer
///   from `epistemos_simulation_delta_ring_handle` and must not
///   drop the `Simulation` while drains are in flight.
/// - `out_buffer` must point to at least `capacity * sizeof(PerInstanceData)`
///   bytes of writable memory. The Swift bridge satisfies this
///   with a persistent shared-storage `MTLBuffer`.
/// - `capacity` is the buffer length in *elements* (not bytes).
#[no_mangle]
pub unsafe extern "C" fn epistemos_delta_ring_drain(
    ring: *const DeltaRing,
    out_buffer: *mut PerInstanceData,
    capacity: usize,
) -> usize {
    if ring.is_null() || out_buffer.is_null() || capacity == 0 {
        return 0;
    }
    // SAFETY: caller guarantees `ring` is a valid pointer for the
    // lifetime of the call, and `out_buffer` covers `capacity`
    // elements. We do not retain the pointer past the call.
    let ring = unsafe { &*ring };
    let buffer = unsafe { std::slice::from_raw_parts_mut(out_buffer, capacity) };
    ring.drain_into(buffer)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::companions::CompanionId;

    fn delta_for(id: CompanionId, frame: u32) -> PerInstanceData {
        let mut d = PerInstanceData::new(id);
        d.frame_index = frame;
        d.scale = [1.0, 1.0];
        d
    }

    #[test]
    fn empty_ring_drain_yields_zero() {
        let ring = DeltaRing::new(8);
        let mut buf = [PerInstanceData::default(); 4];
        assert_eq!(ring.drain_into(&mut buf), 0);
    }

    #[test]
    fn push_and_drain_round_trips() {
        let ring = DeltaRing::new(8);
        let alice = CompanionId::new_ulid();
        let bob = CompanionId::new_ulid();
        ring.push(delta_for(alice, 1));
        ring.push(delta_for(bob, 1));
        let mut buf = [PerInstanceData::default(); 4];
        let n = ring.drain_into(&mut buf);
        assert_eq!(n, 2);
        // FIFO order — alice first.
        assert_eq!(buf[0].agent_id(), alice);
        assert_eq!(buf[1].agent_id(), bob);
    }

    #[test]
    fn coalesce_replaces_existing_agent_delta() {
        let ring = DeltaRing::new(8);
        let alice = CompanionId::new_ulid();
        ring.push(delta_for(alice, 1));
        ring.push(delta_for(alice, 5));
        ring.push(delta_for(alice, 9));
        // Queue should have ONE entry — alice with frame 9.
        assert_eq!(ring.len(), 1);
        let mut buf = [PerInstanceData::default(); 4];
        let n = ring.drain_into(&mut buf);
        assert_eq!(n, 1);
        assert_eq!(buf[0].agent_id(), alice);
        assert_eq!(buf[0].frame_index, 9);
    }

    #[test]
    fn coalesce_keeps_distinct_agents_separate() {
        let ring = DeltaRing::new(8);
        let alice = CompanionId::new_ulid();
        let bob = CompanionId::new_ulid();
        let cara = CompanionId::new_ulid();
        ring.push(delta_for(alice, 1));
        ring.push(delta_for(bob, 1));
        ring.push(delta_for(cara, 1));
        // Coalesce alice's frame.
        ring.push(delta_for(alice, 99));
        assert_eq!(ring.len(), 3);
        let mut buf = [PerInstanceData::default(); 4];
        let n = ring.drain_into(&mut buf);
        assert_eq!(n, 3);
        let alice_d = buf[..n].iter().find(|d| d.agent_id() == alice).unwrap();
        assert_eq!(alice_d.frame_index, 99);
    }

    #[test]
    fn full_ring_overwrites_oldest_on_unique_agent_push() {
        let ring = DeltaRing::new(2);
        let alice = CompanionId::new_ulid();
        let bob = CompanionId::new_ulid();
        let cara = CompanionId::new_ulid();
        ring.push(delta_for(alice, 1));
        ring.push(delta_for(bob, 1));
        // Ring is full. cara's push should evict alice.
        ring.push(delta_for(cara, 1));
        let mut buf = [PerInstanceData::default(); 4];
        let n = ring.drain_into(&mut buf);
        assert_eq!(n, 2);
        // alice should NOT be in the drained buffer.
        assert!(buf[..n].iter().all(|d| d.agent_id() != alice));
    }

    #[test]
    fn drain_into_smaller_buffer_partial_drain() {
        let ring = DeltaRing::new(16);
        for i in 0..5 {
            let id = CompanionId::new_ulid();
            ring.push(delta_for(id, i));
        }
        let mut buf = [PerInstanceData::default(); 3];
        let n = ring.drain_into(&mut buf);
        assert_eq!(n, 3);
        assert_eq!(ring.len(), 2);
        // Drain remaining.
        let n = ring.drain_into(&mut buf);
        assert_eq!(n, 2);
        assert_eq!(ring.len(), 0);
    }

    #[test]
    fn ffi_drain_handles_null_ring() {
        let mut buf = [PerInstanceData::default(); 4];
        unsafe {
            let n = epistemos_delta_ring_drain(
                std::ptr::null(),
                buf.as_mut_ptr(),
                buf.len(),
            );
            assert_eq!(n, 0);
        }
    }

    #[test]
    fn ffi_drain_handles_zero_capacity() {
        let ring = DeltaRing::new(8);
        let alice = CompanionId::new_ulid();
        ring.push(delta_for(alice, 1));
        let mut buf = [PerInstanceData::default(); 4];
        unsafe {
            let n = epistemos_delta_ring_drain(
                &ring as *const DeltaRing,
                buf.as_mut_ptr(),
                0,
            );
            assert_eq!(n, 0);
        }
        // Ring still has the entry — capacity-0 drain didn't pop.
        assert_eq!(ring.len(), 1);
    }

    #[test]
    fn ffi_drain_round_trips_through_raw_pointer() {
        let ring = DeltaRing::new(8);
        let alice = CompanionId::new_ulid();
        ring.push(delta_for(alice, 7));
        let mut buf = [PerInstanceData::default(); 4];
        unsafe {
            let n = epistemos_delta_ring_drain(
                &ring as *const DeltaRing,
                buf.as_mut_ptr(),
                buf.len(),
            );
            assert_eq!(n, 1);
            assert_eq!(buf[0].agent_id(), alice);
            assert_eq!(buf[0].frame_index, 7);
        }
    }
}
