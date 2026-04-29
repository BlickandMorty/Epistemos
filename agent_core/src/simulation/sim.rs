//! `Simulation` — bootstrap UniFFI surface (S4; DOCTRINE I-7,
//! I-8 / IMPLEMENTATION §2.2).
//!
//! Per DOCTRINE I-8 the FFI is a three-tier pyramid:
//!
//!   - **UniFFI** (this module) for low-frequency control.
//!   - **SPSC ring buffer** (`crate::ffi::delta_ring`) via raw
//!     C ABI for >100 Hz frame deltas. UniFFI is **forbidden**
//!     on that path.
//!   - **IOSurface** for atlas textures (S10).
//!
//! The Simulation struct is the boot-strap: Swift creates one
//! via `epistemos_simulation_create`, gets a u64 handle (Arc'd
//! `Simulation` cast to a raw pointer), and from it obtains a
//! second u64 — the raw `*const DeltaRing` — that the renderer
//! uses for per-frame drains via the C-ABI export. UniFFI never
//! appears in the per-frame path.
//!
//! This module follows the existing `crate::bridge` pattern:
//! free functions decorated with `#[uniffi::export]`, wrapped
//! in `ffi_guard_value!` so panics at the boundary surface as
//! safe defaults rather than aborting the macOS process under
//! `panic = "unwind"`.

use std::sync::{Arc, Mutex};

use crate::audit::{AuditLedger, FrameDelta};
use crate::companions::{CompanionId, ProviderRole};
use crate::events::AgentEvent;
use crate::ffi::{DeltaRing, DELTA_RING_DEFAULT_CAPACITY};

use super::reducer::reduce;
use super::state::SimulationState;

/// The simulation singleton handed to Swift via UniFFI. Owns
/// the canonical state, the SPSC delta ring, and an optional
/// audit ledger (None at S4 boot — Swift wires one up at S5+).
pub struct Simulation {
    inner: Mutex<SimulationInner>,
    delta_ring: Arc<DeltaRing>,
}

struct SimulationInner {
    state: SimulationState,
    audit: Option<AuditLedger>,
    next_seq: u64,
}

impl Simulation {
    pub fn new() -> Self {
        Self {
            inner: Mutex::new(SimulationInner {
                state: SimulationState::initial(),
                audit: None,
                next_seq: 0,
            }),
            delta_ring: Arc::new(DeltaRing::new(DELTA_RING_DEFAULT_CAPACITY)),
        }
    }

    /// Process one event: run the reducer, push the resulting
    /// per-instance snapshots onto the ring (one per touched
    /// agent), and record each `FrameDelta` to the audit ledger
    /// if attached.
    pub fn process_event(&self, event: &AgentEvent) -> Vec<FrameDelta> {
        let mut inner = match self.inner.lock() {
            Ok(g) => g,
            Err(p) => p.into_inner(), // tolerate a poisoned mutex; abort would be worse
        };
        inner.next_seq += 1;
        let seq = inner.next_seq;
        let deltas = reduce(&mut inner.state, event, seq);

        // Push one PerInstanceData per touched agent. The
        // reducer mutated state.agents; snapshot every agent
        // and let the ring's coalesce policy collapse to one
        // entry per id.
        for snap in inner.state.snapshot_all() {
            self.delta_ring.push(snap);
        }

        // Record deltas to the audit ledger (if attached).
        if let Some(ledger) = inner.audit.as_mut() {
            for d in &deltas {
                let _ = ledger.record_now(d.delta_id, d.origin.clone(), d.kind);
            }
        }
        deltas
    }

    pub fn delta_ring_arc(&self) -> Arc<DeltaRing> {
        Arc::clone(&self.delta_ring)
    }

    pub fn delta_ring_handle_u64(&self) -> u64 {
        Arc::as_ptr(&self.delta_ring) as u64
    }

    pub fn agent_count(&self) -> usize {
        match self.inner.lock() {
            Ok(g) => g.state.agent_count(),
            Err(p) => p.into_inner().state.agent_count(),
        }
    }
}

impl Default for Simulation {
    fn default() -> Self {
        Self::new()
    }
}

// =============================================================================
// FFI safety harness — mirrors `crate::bridge` macros so the
// boundary semantics are identical to the existing surface.
// =============================================================================

fn panic_payload_to_string(payload: Box<dyn std::any::Any + Send>) -> String {
    let msg = if let Some(s) = payload.downcast_ref::<&str>() {
        (*s).to_string()
    } else if let Some(s) = payload.downcast_ref::<String>() {
        s.clone()
    } else {
        "unknown panic".to_string()
    };
    std::mem::forget(payload);
    msg
}

macro_rules! ffi_guard_value {
    ($body:expr, $default:expr) => {{
        match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| $body)) {
            Ok(v) => v,
            Err(payload) => {
                let msg = panic_payload_to_string(payload);
                tracing::error!("[ffi/sim] PANIC at simulation boundary: {}", msg);
                $default
            }
        }
    }};
}

// =============================================================================
// UniFFI exports. Free-function pattern matching `crate::bridge`.
// =============================================================================

/// Create a new `Simulation` and return a u64 handle (raw
/// pointer to a leaked `Arc<Simulation>`). Swift retains
/// exactly one reference until it calls
/// `epistemos_simulation_destroy`.
#[uniffi::export]
pub fn epistemos_simulation_create() -> u64 {
    ffi_guard_value!(
        {
            let sim = Arc::new(Simulation::new());
            Arc::into_raw(sim) as u64
        },
        0
    )
}

/// Reclaim the leaked Arc. Calling with `0` is a no-op.
/// Calling twice is undefined — Swift must guard.
#[uniffi::export]
pub fn epistemos_simulation_destroy(handle: u64) {
    if handle == 0 {
        return;
    }
    ffi_guard_value!(
        {
            // SAFETY: `handle` was returned by Arc::into_raw on
            // the matching `Simulation`. We re-take ownership
            // here and drop it.
            let _ = unsafe { Arc::from_raw(handle as *const Simulation) };
        },
        ()
    )
}

/// Returns a raw `*const DeltaRing` cast to u64 so the Swift
/// renderer can call `epistemos_delta_ring_drain` directly
/// without UniFFI per-frame overhead.
///
/// Safety contract for the caller:
/// - The returned pointer is valid only while the corresponding
///   `Simulation` (referenced by `handle`) is alive.
/// - Swift MUST NOT call `epistemos_simulation_destroy(handle)`
///   while drains are in flight.
#[uniffi::export]
pub fn epistemos_simulation_delta_ring_handle(handle: u64) -> u64 {
    if handle == 0 {
        return 0;
    }
    ffi_guard_value!(
        {
            // SAFETY: `handle` is a valid `*const Simulation`
            // (Arc raw pointer) per the contract on
            // `epistemos_simulation_create`. We borrow but do
            // not consume the Arc here.
            let sim = unsafe { &*(handle as *const Simulation) };
            sim.delta_ring_handle_u64()
        },
        0
    )
}

/// Synthetic harness for the S4 acceptance gate "feed 5 mock
/// companions through the reducer; see 5 colored rectangles."
/// Inserts `count` companions and emits `ParticipantJoined`
/// events for each so the reducer pushes their initial
/// `PerInstanceData` snapshots onto the ring.
#[uniffi::export]
pub fn epistemos_simulation_inject_test_companions(handle: u64, count: u32) {
    if handle == 0 {
        return;
    }
    ffi_guard_value!(
        {
            let sim = unsafe { &*(handle as *const Simulation) };
            for i in 0..count {
                let id = CompanionId::new_ulid();
                let ev = AgentEvent::ParticipantJoined {
                    agent_id: id,
                    role: ProviderRole::Worker,
                };
                sim.process_event(&ev);
                // Spread positions so the renderer paints them
                // in distinct slots. Integer-only per I-16.
                {
                    let mut inner = sim.inner.lock().unwrap_or_else(|p| p.into_inner());
                    if let Some(agent) = inner.state.agent_mut(id) {
                        agent.position = [40.0 + (i as f32) * 80.0, 60.0];
                    }
                }
                // Re-snapshot the moved companion so the ring
                // reflects the position update.
                {
                    let inner = sim.inner.lock().unwrap_or_else(|p| p.into_inner());
                    if let Some(agent) = inner.state.agent(id) {
                        sim.delta_ring.push(agent.snapshot_for_render());
                    }
                }
            }
        },
        ()
    );
}

/// Process an event provided as JSON. Used by the synthetic
/// harness + by S5+ to feed real provider streams once the
/// FFI bridge for `AgentEvent` lands.
#[uniffi::export]
pub fn epistemos_simulation_process_event_json(handle: u64, event_json: String) -> bool {
    if handle == 0 {
        return false;
    }
    ffi_guard_value!(
        {
            let sim = unsafe { &*(handle as *const Simulation) };
            match serde_json::from_str::<AgentEvent>(&event_json) {
                Ok(event) => {
                    sim.process_event(&event);
                    true
                }
                Err(e) => {
                    tracing::warn!(
                        target: "epistemos.simulation",
                        error = %e,
                        "process_event_json: parse failure"
                    );
                    false
                }
            }
        },
        false
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::events::{MessageId, SessionId, SessionMode};

    #[test]
    fn create_destroy_round_trip() {
        let h = epistemos_simulation_create();
        assert_ne!(h, 0);
        epistemos_simulation_destroy(h);
        // Destroying 0 is a no-op.
        epistemos_simulation_destroy(0);
    }

    #[test]
    fn delta_ring_handle_is_stable_across_calls() {
        let h = epistemos_simulation_create();
        let r1 = epistemos_simulation_delta_ring_handle(h);
        let r2 = epistemos_simulation_delta_ring_handle(h);
        assert_eq!(r1, r2);
        assert_ne!(r1, 0);
        epistemos_simulation_destroy(h);
    }

    #[test]
    fn delta_ring_handle_with_null_returns_zero() {
        assert_eq!(epistemos_simulation_delta_ring_handle(0), 0);
    }

    #[test]
    fn inject_test_companions_populates_ring() {
        let h = epistemos_simulation_create();
        epistemos_simulation_inject_test_companions(h, 5);
        // Validate ring has entries via the C-ABI drain.
        let ring_handle = epistemos_simulation_delta_ring_handle(h);
        let mut buf = vec![crate::ffi::PerInstanceData::default(); 16];
        let n = unsafe {
            crate::ffi::delta_ring::epistemos_delta_ring_drain(
                ring_handle as *const _,
                buf.as_mut_ptr(),
                buf.len(),
            )
        };
        assert_eq!(n, 5);
        // All 5 should have distinct ULIDs.
        let ids: std::collections::HashSet<_> =
            buf[..n].iter().map(|d| d.agent_id()).collect();
        assert_eq!(ids.len(), 5);
        epistemos_simulation_destroy(h);
    }

    #[test]
    fn inject_companions_lays_out_positions_integer_only() {
        let h = epistemos_simulation_create();
        epistemos_simulation_inject_test_companions(h, 3);
        let ring_handle = epistemos_simulation_delta_ring_handle(h);
        let mut buf = vec![crate::ffi::PerInstanceData::default(); 16];
        let n = unsafe {
            crate::ffi::delta_ring::epistemos_delta_ring_drain(
                ring_handle as *const _,
                buf.as_mut_ptr(),
                buf.len(),
            )
        };
        assert_eq!(n, 3);
        for d in &buf[..n] {
            // Position values must be integer per I-16 (the
            // vertex shader snaps too, but the source should
            // already be integer).
            assert!(d.position[0].fract() == 0.0);
            assert!(d.position[1].fract() == 0.0);
            // Scale is integer 1×.
            assert_eq!(d.scale, [1.0, 1.0]);
        }
        epistemos_simulation_destroy(h);
    }

    #[test]
    fn process_event_json_accepts_canonical_agent_event() {
        let h = epistemos_simulation_create();
        let alice = CompanionId::new_ulid();
        let evt = AgentEvent::SessionStarted {
            session_id: SessionId::new("s1"),
            mode: SessionMode::Chat,
        };
        let json = serde_json::to_string(&evt).unwrap();
        let ok = epistemos_simulation_process_event_json(h, json);
        assert!(ok);
        // ParticipantJoined to bring alice into the state.
        let evt2 = AgentEvent::ParticipantJoined {
            agent_id: alice,
            role: ProviderRole::Worker,
        };
        let json2 = serde_json::to_string(&evt2).unwrap();
        let ok2 = epistemos_simulation_process_event_json(h, json2);
        assert!(ok2);
        // Now MessageStarted on alice.
        let evt3 = AgentEvent::MessageStarted {
            message_id: MessageId::new("m"),
            agent_id: alice,
        };
        let json3 = serde_json::to_string(&evt3).unwrap();
        let ok3 = epistemos_simulation_process_event_json(h, json3);
        assert!(ok3);
        epistemos_simulation_destroy(h);
    }

    #[test]
    fn process_event_json_rejects_malformed() {
        let h = epistemos_simulation_create();
        let ok = epistemos_simulation_process_event_json(h, "not json".to_string());
        assert!(!ok);
        epistemos_simulation_destroy(h);
    }

    #[test]
    fn null_handle_inject_is_safe_noop() {
        // Should not panic / segfault.
        epistemos_simulation_inject_test_companions(0, 5);
        let _ = epistemos_simulation_process_event_json(0, "{}".to_string());
    }
}
