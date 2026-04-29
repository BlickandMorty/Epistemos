//
//  GraphTheaterViewModel.swift
//  Simulation Mode S7 — observable state for the multi-room
//  graph theater (DOCTRINE §3.3, §3.3.1, §3.3.3 v1.6).
//
//  Holds the active rooms snapshot, the current theater mode
//  (overview vs drill-in), and the agent-id → room routing map
//  the renderer uses to bucket per-frame deltas.
//
//  Per DOCTRINE I-8 the rooms snapshot is fetched on session
//  lifecycle change (low-frequency control plane). The S7 minimum
//  viable polls on a 4 Hz cadence — well below the per-frame
//  budget and easy to replace with an event-driven push when
//  the audit ledger gains a "lifecycle event" channel.
//

import Foundation
import Observation
import SwiftUI

/// Theater mode per DOCTRINE §3.3.3 v1.6.
public enum TheaterMode: Equatable, Sendable {
    /// Multi-tile glanceable view; default when ≥ 2 sessions
    /// are active. No chat input, no inspector — just sprite
    /// motion + working-state badges + per-room title strip.
    case overview
    /// One session expanded full-canvas with the inspector +
    /// timeline + chat input chrome; other rooms collapse to a
    /// thumbnail strip on the right edge.
    case drillIn(sessionId: String)
}

@MainActor
@Observable
public final class GraphTheaterViewModel {
    /// Active rooms snapshot from `SimulationBridge.snapshotRooms()`.
    /// Refreshed on the polling cadence + on every public
    /// `refresh()` call.
    public private(set) var rooms: [Room] = []

    /// Theater mode. `.overview` is canonical when ≥ 2 rooms;
    /// when only one room is active, `.drillIn` IS overview
    /// per §3.3.3 v1.6 (the layout collapses naturally).
    public var mode: TheaterMode = .overview

    /// Agent (lo, hi) → session_id routing map. Built whenever
    /// `rooms` refreshes; the renderer reads this per-frame to
    /// route `PerInstanceData` entries to the correct viewport
    /// tile. O(1) lookup so it's safe on the hot path.
    public private(set) var routingMap: [AgentIdKey: String] = [:]

    /// Wall-clock at which `rooms` was last refreshed. Used to
    /// gate the chip-row "working-state pulse" (≤ 30 s threshold
    /// per §3.3.1 v1.6) against `last_event_seq` deltas.
    public private(set) var lastRefreshAt: Date = .distantPast

    private weak var bridge: SimulationBridge?
    private var pollTask: Task<Void, Never>?

    /// Polling interval. 250 ms (4 Hz) is well below the chip
    /// row's 30 s pulse window; cheap enough that we can tolerate
    /// a refetch even when nothing changes.
    public static let pollInterval: Duration = .milliseconds(250)

    public init(bridge: SimulationBridge) {
        self.bridge = bridge
        refresh()
    }

    /// Begin polling. Idempotent — calling twice is a no-op.
    /// The polling task self-terminates when the bridge is
    /// deallocated (weak capture), so callers don't need to
    /// pair this with a `stopPolling()` for shutdown safety.
    public func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard let bridge = await self?.bridge else { return }
                let snapshot = bridge.snapshotRooms()
                await MainActor.run {
                    self?.applySnapshot(snapshot)
                }
            }
        }
    }

    public func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Force an immediate refresh. Use when the caller knows a
    /// lifecycle event just fired (e.g. after
    /// `processEventJson` returns true) and doesn't want to
    /// wait for the next poll tick.
    public func refresh() {
        guard let bridge = bridge else { return }
        applySnapshot(bridge.snapshotRooms())
    }

    /// Toggle the focused session. Calling with the currently
    /// focused id collapses back to overview; calling with a
    /// different id swaps drill-in target without re-entering
    /// overview.
    public func toggleFocus(sessionId: String) {
        switch mode {
        case .overview:
            mode = .drillIn(sessionId: sessionId)
        case .drillIn(let current) where current == sessionId:
            mode = .overview
        case .drillIn:
            mode = .drillIn(sessionId: sessionId)
        }
    }

    /// Compute the current frame layout given the drawable
    /// bounds in *points*. The renderer scales to physical
    /// pixels.
    public func layout(in bounds: CGRect) -> [RoomTileLayout] {
        switch mode {
        case .overview:
            return RoomTilingLayout.overview(bounds: bounds, rooms: rooms)
        case .drillIn(let sessionId):
            return RoomTilingLayout.drillIn(
                bounds: bounds, rooms: rooms, focusedSessionId: sessionId
            )
        }
    }

    // MARK: - Internal

    private func applySnapshot(_ next: [Room]) {
        self.rooms = next
        self.lastRefreshAt = Date()
        var map: [AgentIdKey: String] = [:]
        map.reserveCapacity(next.reduce(0) { $0 + $1.members.count })
        for room in next {
            for member in room.members {
                map[member.key] = room.sessionId
            }
        }
        self.routingMap = map
        // Auto-correct the mode if the focused session no longer
        // exists (closed under our feet). Falls back to overview.
        if case .drillIn(let sessionId) = mode,
           !next.contains(where: { $0.sessionId == sessionId })
        {
            mode = .overview
        }
    }
}
