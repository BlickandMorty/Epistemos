// LatestAnswerPacketSink.swift
//
// V6.2 Option B (per `docs/audits/V6_2_PER_BUBBLE_BINDING_RESEARCH_2026_05_12.md`):
// MainActor-isolated mirror of the recent-packet window held by
// `AnswerPacketEmitter.shared`. SwiftUI views (MessageBubble in
// particular) need synchronous, observable access to recent packets
// — the bubble's view body can't `await` on an actor. This sink hops
// to the actor on `didEmitNotification` and republishes the snapshot
// on MainActor.
//
// Lookup contract: given a `ChatMessage.answerPacketId`, return the
// matching packet if it's still inside the bounded 32-packet ring,
// otherwise nil. Bubbles for older messages whose packet has aged
// out of the ring silently render no chip — that's the V6.2 first-
// wiring posture. Persisting the packet alongside the ChatMessage
// (so scrollback always renders the chip) is a follow-on commit
// that won't change this sink's API.
//
// Cross-references:
// - Epistemos/Engine/AnswerPacketEmitter.swift — the source of truth.
// - Epistemos/Views/Chat/MessageBubble.swift — the primary consumer.
// - docs/audits/V6_2_PER_BUBBLE_BINDING_RESEARCH_2026_05_12.md — the
//   architecture decision behind this sink.

import Foundation
import Observation
import os

@MainActor
@Observable
public final class LatestAnswerPacketSink {
    public static let shared = LatestAnswerPacketSink()

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "AnswerPacketSink"
    )

    /// Most-recent-first slice of the AnswerPacketEmitter ring. Bounded
    /// at `AnswerPacketEmitter.maxRingSize` (32) so this never grows
    /// unbounded under long sessions. Updated on
    /// `AnswerPacketEmitter.didEmitNotification` via the
    /// `start()`-armed observer.
    public private(set) var recentPackets: [AnswerPacket] = []

    /// Indexed lookup by packet id for O(1) per-bubble retrieval.
    /// Rebuilt whenever `recentPackets` updates.
    private var byId: [String: AnswerPacket] = [:]

    private var observer: NSObjectProtocol?

    private init() {}

    /// Wire the sink to the emitter's `didEmitNotification` so it
    /// auto-refreshes per emit. Call this once at app bootstrap; safe
    /// to call multiple times (idempotent — the observer is replaced).
    public func start() {
        if let existing = observer {
            NotificationCenter.default.removeObserver(existing)
        }
        observer = NotificationCenter.default.addObserver(
            forName: AnswerPacketEmitter.didEmitNotification,
            object: AnswerPacketEmitter.shared,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        // Prime the initial state so consumers that mount before the
        // first emit don't see an empty sink.
        Task { @MainActor in
            await refresh()
        }
        Self.log.notice("LatestAnswerPacketSink started")
    }

    /// Stop receiving emit notifications. Useful in tests; production
    /// callers should never need this.
    public func stop() {
        if let existing = observer {
            NotificationCenter.default.removeObserver(existing)
            observer = nil
        }
    }

    /// Refresh the sink from the emitter's current recent-packets
    /// list. Public so tests can drive it; production callers rely on
    /// the `didEmitNotification` observer wired in `start()`.
    ///
    /// Source ring is oldest-first; mirror as most-recent-first so
    /// the future "recent packets" panel can iterate in natural
    /// display order. The id-keyed dict is rebuilt fresh each call
    /// (the ring is bounded at 32 so this is a tiny cost).
    public func refresh() async {
        let canonical = await AnswerPacketEmitter.shared.recentPackets()
        recentPackets = canonical.reversed()
        byId = Dictionary(uniqueKeysWithValues: canonical.map { ($0.id, $0) })
    }

    /// O(1) per-bubble lookup. Returns nil for packet ids that have
    /// aged out of the bounded ring — bubbles for those messages
    /// render no chip per the V6.2 first-wiring posture.
    public func packet(for id: String) -> AnswerPacket? {
        byId[id]
    }
}

// Note: this file uses module-default MainActor isolation. The
// `@MainActor` is explicit on the class so the type is unambiguous
// even if the module default changes. `Observable` synthesis pairs
// cleanly with MainActor — the @Observable macro generates the
// MainActor-bound observation registrations.
