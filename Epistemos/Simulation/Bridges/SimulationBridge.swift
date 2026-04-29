//
//  SimulationBridge.swift
//  Simulation Mode S7 — Swift wrapper around the simulation
//  handle's UniFFI control surface.
//
//  Per DOCTRINE I-7 Swift never mutates simulation state — every
//  control-plane operation crosses this typed FFI boundary. Per
//  DOCTRINE I-8 this surface is **low-frequency** (room snapshots
//  only on lifecycle change); per-frame visual deltas continue
//  to cross via `crate::ffi::delta_ring` (see `DeltaRingBridge`).
//
//  S7 introduces this file (S4–S6 used the raw `UInt64` handle
//  + free `epistemosSimulation*` functions inline in views). The
//  multi-room theater needed enough state — rooms, agent→room
//  routing keys — that a typed wrapper became cleaner than
//  threading raw u64 + FFI calls through every view.
//

import Foundation

// MARK: - Stable routing key

/// Byte-equal mirror of the `(agent_id_lo, agent_id_hi)` pair on
/// `PerInstanceData`. Used as a per-frame routing key in the
/// multi-room renderer so we don't have to base32-decode ULID
/// strings for every delta.
public struct AgentIdKey: Hashable, Sendable {
    public let lo: UInt64
    public let hi: UInt64

    public nonisolated init(lo: UInt64, hi: UInt64) {
        self.lo = lo
        self.hi = hi
    }

    public nonisolated init(member: MemberFfi) {
        self.lo = member.idLo
        self.hi = member.idHi
    }

    public nonisolated init(perInstance data: PerInstanceData) {
        self.lo = data.agent_id_lo
        self.hi = data.agent_id_hi
    }
}

// MARK: - Strongly-typed mirrors

/// One companion in a multi-room theater room. Mirrors
/// `agent_core::simulation::sim::MemberFFI`.
public struct RoomMember: Identifiable, Sendable, Hashable {
    public var id: String { ulid }
    /// Crockford-base32 ULID of the companion.
    public let ulid: String
    /// (lo, hi) pair for fast per-frame routing.
    public let key: AgentIdKey

    public nonisolated init(ffi: MemberFfi) {
        self.ulid = ffi.id
        self.key = AgentIdKey(member: ffi)
    }
}

/// One active session in the multi-room theater. Mirrors
/// `agent_core::simulation::sim::RoomFFI`. Per DOCTRINE §3.3.1
/// v1.6 cardinality — one room per active session, regardless
/// of how many companions share that session.
public struct Room: Identifiable, Sendable, Hashable {
    public var id: String { sessionId }
    public let sessionId: String
    public let leadAgentUlid: String?
    public let members: [RoomMember]
    public let mode: String
    public let startedSeq: UInt64
    public let lastEventSeq: UInt64

    public nonisolated init(ffi: RoomFfi) {
        self.sessionId = ffi.sessionId
        self.leadAgentUlid = ffi.leadAgentId
        self.members = ffi.members.map(RoomMember.init(ffi:))
        self.mode = ffi.mode
        self.startedSeq = ffi.startedSeq
        self.lastEventSeq = ffi.lastEventSeq
    }
}

// MARK: - SimulationBridge

/// Typed wrapper around a Rust `Simulation` handle. The handle
/// is opaque (raw u64); the bridge is the only place Swift talks
/// to it via UniFFI.
///
/// Per DOCTRINE I-8 this is the control plane only — the
/// per-frame ring drain crosses `DeltaRingBridge` (raw C ABI),
/// NOT this surface.
///
/// Lifecycle: `init?(_:)` claims the handle ownership and
/// `deinit` releases it. The renderer / theater views borrow
/// (read-only) for as long as this bridge is alive.
public final class SimulationBridge {
    /// Raw u64 handle from `epistemos_simulation_create`. The
    /// per-frame `DeltaRingBridge` borrows this via
    /// `epistemos_simulation_delta_ring_handle` and uses the
    /// resulting raw `*const DeltaRing` pointer directly.
    nonisolated(unsafe) public let handle: UInt64

    /// Open a fresh simulation. Returns `nil` if the FFI surfaces
    /// a 0 handle (allocation failure or panic at construction).
    public init?() {
        let h = epistemosSimulationCreate()
        guard h != 0 else { return nil }
        self.handle = h
    }

    deinit {
        epistemosSimulationDestroy(handle: handle)
    }

    /// Snapshot the active rooms for the multi-room theater.
    /// Per DOCTRINE I-8 this is low-frequency: callers refresh
    /// only on session-lifecycle change, NOT every frame.
    public nonisolated func snapshotRooms() -> [Room] {
        epistemosSimulationActiveRooms(handle: handle).map(Room.init(ffi:))
    }

    /// Returns the raw `*const DeltaRing` handle for the per-frame
    /// drain path. The `DeltaRingBridge` consumes this directly.
    public nonisolated func deltaRingHandle() -> UInt64 {
        epistemosSimulationDeltaRingHandle(handle: handle)
    }

    /// Synthetic harness for previews — injects N mock companions
    /// each as a fresh `ParticipantJoined` event. Useful for
    /// theater previews without a real session.
    public nonisolated func injectTestCompanions(count: UInt32) {
        epistemosSimulationInjectTestCompanions(handle: handle, count: count)
    }

    /// Process an `AgentEvent` provided as JSON. Used by the
    /// preview shell + by S5+ to feed real provider streams.
    /// Returns `true` on successful parse + reduce.
    @discardableResult
    public nonisolated func processEventJson(_ json: String) -> Bool {
        epistemosSimulationProcessEventJson(handle: handle, eventJson: json)
    }
}
