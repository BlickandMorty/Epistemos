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

/// One companion's identity exposed to Swift. Carries both the
/// stringified ULID (for display / `Identifiable` keys) AND the
/// raw `(lo, hi)` u64 pair — the latter is byte-equal to
/// `PerInstanceData::agent_id_lo`/`agent_id_hi`, so the Swift
/// renderer can route per-frame deltas to rooms using the pair
/// as a hash key without base32-decoding the ULID string each
/// frame.
#[derive(uniffi::Record, Debug, Clone, PartialEq)]
pub struct MemberFFI {
    /// Stringified ULID — same format `CompanionId::Display`
    /// produces.
    pub id: String,
    /// Low 64 bits of the ULID. Matches
    /// `PerInstanceData::agent_id_lo` byte-for-byte.
    pub id_lo: u64,
    /// High 64 bits of the ULID. Matches
    /// `PerInstanceData::agent_id_hi` byte-for-byte.
    pub id_hi: u64,
}

impl MemberFFI {
    fn from_companion_id(id: CompanionId) -> Self {
        let bytes = id.0.to_bytes();
        let lo = u64::from_le_bytes(bytes[0..8].try_into().unwrap());
        let hi = u64::from_le_bytes(bytes[8..16].try_into().unwrap());
        Self { id: id.to_string(), id_lo: lo, id_hi: hi }
    }
}

/// Snapshot of one active multi-room session for the Swift
/// renderer. Mirrors `state::SessionMeta` minus the internal
/// fields the FFI doesn't need. One per active session per
/// DOCTRINE §3.3.1 v1.6 cardinality rule.
#[derive(uniffi::Record, Debug, Clone, PartialEq)]
pub struct RoomFFI {
    /// Stable session identifier (used as the chip row's
    /// `Identifiable.id` on the Swift side).
    pub session_id: String,
    /// Lead-agent companion id as a stringified ULID, or `None`
    /// if the session has no participants yet (transient — the
    /// session has just opened but no `ParticipantJoined` has
    /// fired yet).
    pub lead_agent_id: Option<String>,
    /// All members of this session (parent + sub-agents per
    /// §4.5; handoff sender + receiver per §4.3 share a
    /// session). Sorted by ULID for stable iteration.
    pub members: Vec<MemberFFI>,
    /// Session-mode discriminator: "Chat" / "ResearchJury" /
    /// "DeepDeliberation" / "Hermes" / "Custom". Mirrors
    /// `events::SessionMode` PascalCase stringification.
    pub mode: String,
    /// Reducer event_seq at which this session opened — defines
    /// chip-row ordering on the Swift side. Stable across
    /// replays.
    pub started_seq: u64,
    /// Reducer event_seq of the most recent event in this
    /// session — drives the chip-row "working-state pulse" gate
    /// per §3.3.1 v1.6.
    pub last_event_seq: u64,
}

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

    /// Snapshot the active rooms for the Swift multi-room
    /// theater. Per DOCTRINE I-8 this is the **control plane**
    /// (low-frequency: lifecycle changes only) — the per-frame
    /// path stays on the SPSC ring. Swift refreshes this on
    /// `SessionStarted` / `SessionCompleted` / `ParticipantJoined`
    /// signal, NOT every frame.
    pub fn snapshot_rooms(&self) -> Vec<RoomFFI> {
        let inner = match self.inner.lock() {
            Ok(g) => g,
            Err(p) => p.into_inner(),
        };
        inner
            .state
            .rooms()
            .into_iter()
            .map(|m| RoomFFI {
                session_id: m.session_id.as_str().to_string(),
                lead_agent_id: m.lead_agent.map(|id| id.to_string()),
                members: m
                    .members
                    .iter()
                    .copied()
                    .map(MemberFFI::from_companion_id)
                    .collect(),
                mode: serde_json::to_value(m.mode)
                    .ok()
                    .and_then(|v| v.as_str().map(str::to_string))
                    .unwrap_or_else(|| "unknown".to_string()),
                started_seq: m.started_seq,
                last_event_seq: m.last_event_seq,
            })
            .collect()
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
                // reflects the position update. The synthetic
                // harness cycles through the 5 head-shape slices
                // so the visual harness shows variety per
                // companion (block_compact, block_wide, orb,
                // sage, hermes_snake).
                let head_idx = (i % 5) as u8;
                {
                    let mut inner = sim.inner.lock().unwrap_or_else(|p| p.into_inner());
                    inner.state.set_head_shape(id, head_idx);
                }
                {
                    let inner = sim.inner.lock().unwrap_or_else(|p| p.into_inner());
                    if let Some(agent) = inner.state.agent(id) {
                        sim.delta_ring.push(agent.snapshot_for_render(head_idx));
                    }
                }
            }
        },
        ()
    );
}

/// Set the texture-array slice index (0..4) for an agent.
/// Called by the Swift bridge when a companion is registered in
/// the simulation so the §10.5 fragment shader can sample the
/// correct head-shape slice. Indices follow
/// `Epistemos/Simulation/AtlasLoader.swift::AtlasHeadShape`:
///   0 = block_compact
///   1 = block_wide
///   2 = orb
///   3 = sage
///   4 = hermes_snake
#[uniffi::export]
pub fn epistemos_simulation_set_head_shape(
    handle: u64, agent_id: String, head_shape_index: u8,
) {
    if handle == 0 || head_shape_index > 4 {
        return;
    }
    ffi_guard_value!(
        {
            let Some(parsed) = CompanionId::parse(&agent_id) else { return; };
            let sim = unsafe { &*(handle as *const Simulation) };
            let mut inner = sim.inner.lock().unwrap_or_else(|p| p.into_inner());
            inner.state.set_head_shape(parsed, head_shape_index);
        },
        ()
    );
}

/// Snapshot the active rooms for the multi-room graph theater
/// (DOCTRINE §3.3.1 v1.6). Returns one `RoomFFI` per active
/// session in canonical `started_seq` order. Empty when zero
/// sessions are active — Swift renders the "No active agents"
/// empty state.
///
/// Per DOCTRINE I-8 this is the control plane: Swift calls it
/// on session-lifecycle change (low-frequency). The per-frame
/// path stays on the SPSC ring.
#[uniffi::export]
pub fn epistemos_simulation_active_rooms(handle: u64) -> Vec<RoomFFI> {
    if handle == 0 {
        return Vec::new();
    }
    ffi_guard_value!(
        {
            let sim = unsafe { &*(handle as *const Simulation) };
            sim.snapshot_rooms()
        },
        Vec::new()
    )
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

    #[test]
    fn active_rooms_with_null_handle_is_empty() {
        assert!(epistemos_simulation_active_rooms(0).is_empty());
    }

    #[test]
    fn active_rooms_reflects_open_sessions() {
        // §3.3.1 v1.6 acceptance: opening two sessions with
        // members produces two rooms; closing one drops it.
        let h = epistemos_simulation_create();

        // Open Kimi session, join its lead.
        let kimi_open = serde_json::json!({
            "type": "session_started",
            "payload": {
                "session_id": "kimi",
                "mode": "Chat"
            }
        })
        .to_string();
        assert!(epistemos_simulation_process_event_json(h, kimi_open));

        let kimi_lead = CompanionId::new_ulid();
        let kimi_join = serde_json::json!({
            "type": "participant_joined",
            "payload": {
                "agent_id": kimi_lead.to_string(),
                "role": "Orchestrator"
            }
        })
        .to_string();
        assert!(epistemos_simulation_process_event_json(h, kimi_join));

        let mid = epistemos_simulation_active_rooms(h);
        assert_eq!(mid.len(), 1);
        assert_eq!(mid[0].session_id, "kimi");
        assert_eq!(mid[0].lead_agent_id.as_deref(), Some(kimi_lead.to_string().as_str()));
        assert_eq!(mid[0].members.len(), 1);
        // The member's (lo, hi) pair must match the lo/hi
        // PerInstanceData would carry — the routing contract.
        let bytes = kimi_lead.0.to_bytes();
        let expected_lo = u64::from_le_bytes(bytes[0..8].try_into().unwrap());
        let expected_hi = u64::from_le_bytes(bytes[8..16].try_into().unwrap());
        assert_eq!(mid[0].members[0].id_lo, expected_lo);
        assert_eq!(mid[0].members[0].id_hi, expected_hi);
        assert_eq!(mid[0].members[0].id, kimi_lead.to_string());

        // Open Claude session.
        let claude_open = serde_json::json!({
            "type": "session_started",
            "payload": {
                "session_id": "claude",
                "mode": "Chat"
            }
        })
        .to_string();
        assert!(epistemos_simulation_process_event_json(h, claude_open));

        let two = epistemos_simulation_active_rooms(h);
        assert_eq!(two.len(), 2);
        // Order is by `started_seq` — Kimi (opened first) then
        // Claude.
        assert_eq!(two[0].session_id, "kimi");
        assert_eq!(two[1].session_id, "claude");

        // Close Kimi.
        let kimi_close = serde_json::json!({
            "type": "session_completed",
            "payload": {
                "session_id": "kimi",
                "summary": null
            }
        })
        .to_string();
        assert!(epistemos_simulation_process_event_json(h, kimi_close));

        let one = epistemos_simulation_active_rooms(h);
        assert_eq!(one.len(), 1);
        assert_eq!(one[0].session_id, "claude");

        epistemos_simulation_destroy(h);
    }
}
