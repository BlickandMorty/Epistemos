import Testing
import Foundation
@testable import Epistemos

@Suite("AnswerPacketEmitter — V6.2 first wiring (turn-completion audit sink)", .serialized)
struct AnswerPacketEmitterTests {

    /// Each test resets the global emitter so leftover packets from a
    /// previous test don't bleed in. `.serialized` ensures the suite
    /// doesn't race against the singleton.
    private func freshEmitter() async -> AnswerPacketEmitter {
        let emitter = AnswerPacketEmitter.shared
        await emitter.resetForTesting()
        return emitter
    }

    @Test("Newly-emitted packets land in the ring and update count")
    func emittedPacketsLandInRing() async {
        let emitter = await freshEmitter()

        let initialCount = await emitter.count
        #expect(initialCount == 0)

        let packet = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 100,
            outputTokens: 50
        )
        await emitter.emit(packet)

        let count = await emitter.count
        #expect(count == 1)

        let last = await emitter.last
        #expect(last?.id == packet.id)
    }

    @Test("turnCompletionStub builds a packet with V6.2 first-wiring defaults")
    func stubCarriesFirstWiringDefaults() {
        let packet = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 12,
            outputTokens: 34
        )

        // V6.2 first-wiring: schema present, but claims/signals are
        // empty until Rust-side FFI threads real values through.
        #expect(packet.claims.isEmpty)
        #expect(packet.residencySignals.isEmpty)
        // Attention mode starts at .unavailable per first-wiring contract;
        // a subsequent commit populates this from the live agent path.
        #expect(packet.attentionMode == .unavailable)
        // The placeholder ui label.
        #expect(packet.uiLabel == .plausibleButUnverified)
        // witnessedStateRef encodes the streaming-completion summary so
        // the audit trail can correlate the packet with the turn.
        #expect(packet.witnessedStateRef.contains("stop:end_turn"))
        #expect(packet.witnessedStateRef.contains("in:12"))
        #expect(packet.witnessedStateRef.contains("out:34"))
        // mutationEnvelopeRef matches the packet id so the audit graph
        // can join them on a single key.
        #expect(packet.mutationEnvelopeRef == packet.id)
    }

    @Test("Ring buffer evicts oldest packet beyond maxRingSize")
    func ringBufferEvictsOldest() async {
        let emitter = await freshEmitter()

        // Emit one more than the ring can hold.
        let total = AnswerPacketEmitter.maxRingSize + 5
        var firstId: String?
        for i in 0..<total {
            let packet = AnswerPacket.turnCompletionStub(
                stopReason: "end_turn",
                inputTokens: i,
                outputTokens: i
            )
            if i == 0 { firstId = packet.id }
            await emitter.emit(packet)
        }

        let count = await emitter.count
        #expect(count == AnswerPacketEmitter.maxRingSize,
            "ring must clamp at maxRingSize=\(AnswerPacketEmitter.maxRingSize)")

        // The very first packet must have been evicted.
        let recent = await emitter.recentPackets()
        #expect(!recent.contains { $0.id == firstId },
            "oldest packet must be evicted once ring overflows")

        // The monotonic counter survives eviction.
        let emittedTotal = await emitter.emittedTotal
        #expect(emittedTotal == total,
            "emittedTotal must keep counting past the ring cap, got \(emittedTotal)")
    }

    @Test("recentPackets returns chronological order (oldest first)")
    func recentPacketsChronological() async {
        let emitter = await freshEmitter()

        let a = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 1,
            outputTokens: 1
        )
        try? await Task.sleep(nanoseconds: 1_500_000) // ensure timestamp millisecond differs
        let b = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 2,
            outputTokens: 2
        )
        try? await Task.sleep(nanoseconds: 1_500_000)
        let c = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 3,
            outputTokens: 3
        )

        await emitter.emit(a)
        await emitter.emit(b)
        await emitter.emit(c)

        let recent = await emitter.recentPackets()
        #expect(recent.count == 3)
        #expect(recent.first?.id == a.id)
        #expect(recent.last?.id == c.id)
    }

    @Test("emittedTotal is monotonic across many emits")
    func emittedTotalIsMonotonic() async {
        let emitter = await freshEmitter()

        for i in 0..<10 {
            let packet = AnswerPacket.turnCompletionStub(
                stopReason: "end_turn",
                inputTokens: i,
                outputTokens: i
            )
            await emitter.emit(packet)
        }

        let total = await emitter.emittedTotal
        #expect(total == 10)
    }
}
