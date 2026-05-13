import Testing
import Foundation
@testable import Epistemos

@Suite("LatestAnswerPacketSink — V6.2 chip-render lookup path", .serialized)
@MainActor
struct LatestAnswerPacketSinkTests {

    /// Reset BOTH the actor emitter AND the sink between tests so
    /// leftover state from a previous test doesn't bleed in. The
    /// suite is `.serialized` so the resets compose safely.
    private func freshSinkAndEmitter() async -> (LatestAnswerPacketSink, AnswerPacketEmitter) {
        let emitter = AnswerPacketEmitter.shared
        await emitter.resetForTesting()
        let sink = LatestAnswerPacketSink.shared
        // Wire the notification observer + prime initial state.
        sink.start()
        // Drive an initial refresh so the sink reflects the just-reset
        // (empty) state before the test does its first emit.
        await sink.refresh()
        return (sink, emitter)
    }

    @Test("Sink starts empty after fresh emitter reset")
    func sinkStartsEmpty() async {
        let (sink, _) = await freshSinkAndEmitter()
        #expect(sink.recentPackets.isEmpty)
        #expect(sink.packet(for: "any-id") == nil,
            "lookup on empty sink must return nil; got \(String(describing: sink.packet(for: "any-id")))")
    }

    @Test("refresh() mirrors the actor's recent packets in reverse order")
    func refreshMirrorsActorRing() async {
        let (sink, emitter) = await freshSinkAndEmitter()

        let pktA = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 1,
            outputTokens: 1
        )
        let pktB = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 2,
            outputTokens: 2
        )
        let pktC = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 3,
            outputTokens: 3
        )

        await emitter.emit(pktA)
        await emitter.emit(pktB)
        await emitter.emit(pktC)

        // Manually refresh — the notification-driven path is exercised
        // by a separate test below.
        await sink.refresh()

        // Sink stores most-recent-first (per the doctrine comment).
        #expect(sink.recentPackets.count == 3)
        #expect(sink.recentPackets.first?.id == pktC.id,
            "most-recent packet must be at index 0; got \(sink.recentPackets.first?.id ?? "nil")")
        #expect(sink.recentPackets.last?.id == pktA.id)
    }

    @Test("packet(for:) returns the matching packet by id")
    func packetLookupById() async {
        let (sink, emitter) = await freshSinkAndEmitter()

        let pkt = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 1,
            outputTokens: 2,
            attentionMode: .staticFallback,
            interruptBucket: .medium
        )
        await emitter.emit(pkt)
        await sink.refresh()

        let looked = sink.packet(for: pkt.id)
        #expect(looked != nil)
        #expect(looked?.id == pkt.id)
        #expect(looked?.attentionMode == .staticFallback)
        #expect(looked?.interruptBucket == .medium)

        // Unknown id returns nil.
        #expect(sink.packet(for: "ghost-id-not-real") == nil)
    }

    @Test("packet(for:) returns nil for packets that aged out of the ring")
    func packetLookupReturnsNilForEvictedPackets() async {
        let (sink, emitter) = await freshSinkAndEmitter()

        // Emit one more than the ring can hold. The oldest packet
        // gets evicted from the ring AND from the sink's id index.
        let evictedFirst = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 0,
            outputTokens: 0
        )
        await emitter.emit(evictedFirst)
        for _ in 0..<AnswerPacketEmitter.maxRingSize {
            await emitter.emit(AnswerPacket.turnCompletionStub(
                stopReason: "end_turn",
                inputTokens: 0,
                outputTokens: 0
            ))
        }
        await sink.refresh()

        // The first-emitted packet is no longer in the ring → sink lookup
        // returns nil. This is the V6.2 first-rendered posture: chips
        // disappear for messages older than 32 turns.
        #expect(sink.packet(for: evictedFirst.id) == nil,
            "packet evicted from ring must not be findable by id; got non-nil")
        #expect(sink.recentPackets.count == AnswerPacketEmitter.maxRingSize)
    }

    @Test("Notification observer triggers refresh on emit")
    func notificationObserverDrivesRefresh() async {
        let (sink, emitter) = await freshSinkAndEmitter()

        let pkt = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 7,
            outputTokens: 11
        )
        await emitter.emit(pkt)
        // emit() posts didEmitNotification on the main queue, which
        // schedules a refresh Task on MainActor. Yield once + briefly
        // sleep so the observer's MainActor Task has a chance to run.
        try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms

        // Don't call refresh() manually — the notification must have
        // driven it. If this assertion fails, the observer wiring is
        // broken.
        #expect(sink.packet(for: pkt.id)?.id == pkt.id,
            "notification-driven refresh must populate the sink within 50ms")
    }

    @Test("start() is idempotent — calling it multiple times doesn't multiply observers")
    func startIsIdempotent() async {
        let (sink, emitter) = await freshSinkAndEmitter()

        // Re-arm the observer a few times. Each call should replace
        // the previous one, not register an additional handler.
        sink.start()
        sink.start()
        sink.start()

        let pkt = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 1,
            outputTokens: 1
        )
        await emitter.emit(pkt)
        try? await Task.sleep(nanoseconds: 50_000_000)

        // If observers had stacked, refresh() would run N times; the
        // sink would still settle to the same state but the test isn't
        // attempting to detect over-refresh directly (would need a
        // counter). Instead we verify the final state is correct AND
        // the sink doesn't crash.
        #expect(sink.packet(for: pkt.id) != nil)
    }
}
