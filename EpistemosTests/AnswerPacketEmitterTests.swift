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

    @Test("turnCompletionStub builds a packet with V6.2 canonical-product-surface defaults")
    func stubCarriesCanonicalProductSurfaceDefaults() {
        let packet = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 12,
            outputTokens: 34
        )

        // V6.2 canon (state: canonical-product-surface, landed
        // 2026-05-13): claims and residency come from the Rust
        // production caller, not the Swift stub. Every turn carries
        // at least one Empirical self-witness claim and one neutral
        // residency signal — these are the canon-required minimums.
        // The fallback Swift-only path (empty claims) only fires when
        // agent_coreFFI is unlinked.
        #if canImport(agent_coreFFI)
        #expect(!packet.claims.isEmpty,
            "Rust producer must emit at least one Empirical self-witness claim when agent_coreFFI is linked; got \(packet.claims.count) claims")
        #expect(packet.claims.contains { $0.kind == .empirical },
            "self-witness claim must be Empirical-kind; got kinds \(packet.claims.map(\.kind))")
        #expect(!packet.residencySignals.isEmpty,
            "Rust producer must emit at least one neutral residency signal when agent_coreFFI is linked")
        #else
        // Fallback path: when the FFI isn't linked the Swift stub
        // emits empty claims, matching the legacy V6.2 first-wiring
        // contract.
        #expect(packet.claims.isEmpty)
        #expect(packet.residencySignals.isEmpty)
        #endif

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

    #if canImport(agent_coreFFI)
    @Test("turnCompletionStub stamps the Swift-side interruptBucket on top of the Rust-produced packet")
    func stubStampsInterruptBucketOnRustProducedPacket() {
        // V6.2 §1.5: the Rust producer doesn't compute interruptBucket
        // (the Swift-side InterruptScoreCpu observers own it). The
        // consumer wiring must stamp the Swift-computed bucket onto
        // the decoded Rust packet so the audit channel carries both
        // the canonical claims AND the runtime bucket.
        let packet = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 50,
            outputTokens: 100,
            attentionMode: .dynamic,
            interruptBucket: .high
        )
        #expect(packet.interruptBucket == .high,
            "Swift-computed interruptBucket must survive the Rust round-trip; got \(packet.interruptBucket)")
        #expect(packet.attentionMode == .dynamic,
            "Caller-specified attentionMode must round-trip through the Rust producer")
    }

    @Test("turnCompletionStub: tool_use stop_reason produces a second Empirical claim documenting the tool call")
    func stubToolUseEmitsTwoEmpiricalClaims() {
        let packet = AnswerPacket.turnCompletionStub(
            stopReason: "tool_use",
            inputTokens: 25,
            outputTokens: 75,
            attentionMode: .dynamic
        )
        #expect(packet.claims.count == 2,
            "tool_use turn must carry two Empirical claims (self-witness + tool-use); got \(packet.claims.count)")
        #expect(packet.claims.allSatisfy { $0.kind == .empirical })
        #expect(packet.claims.contains { $0.text.contains("tool execution") },
            "one claim must document the tool execution; got texts \(packet.claims.map(\.text))")
    }

    @Test("turnCompletionStub: static_fallback attentionMode emits the doctrine-required acknowledgement claim")
    func stubStaticFallbackEmitsAckClaim() {
        let packet = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 25,
            outputTokens: 75,
            attentionMode: .staticFallback
        )
        // V6.2 doctrine: a static-fallback turn MUST carry a
        // StaticFallbackAcknowledged claim, otherwise the packet
        // fails `acknowledgesStaticFallback`.
        #expect(packet.claims.contains { $0.kind == .staticFallbackAcknowledged },
            "static_fallback packet must carry a StaticFallbackAcknowledged claim")
        #expect(packet.acknowledgesStaticFallback,
            "static_fallback packet must pass acknowledgesStaticFallback after Rust producer wiring")
        #expect(packet.attentionModeClaimsAreConsistent,
            "static_fallback packet must pass the attentionMode↔claim consistency invariant")
    }
    #endif

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

    @Test("Resolver: SSM local model → .staticFallback")
    func resolverSSMModelMapsToStaticFallback() {
        // Mamba2 is SSM (recurrent fixed-state, not quadratic attention).
        let mode = AnswerPacketEmitter.resolveAttentionMode(
            selection: .localMLX(LocalTextModelID.mamba2_2B4Bit.rawValue)
        )
        #expect(mode == .staticFallback,
            "Mamba2 must resolve as .staticFallback per V6.2 §1.4; got \(mode)")
    }

    @Test("Resolver: non-SSM local model → .dynamic")
    func resolverNonSSMModelMapsToDynamic() {
        // Qwen3 is a transformer with quadratic attention.
        let mode = AnswerPacketEmitter.resolveAttentionMode(
            selection: .localMLX(LocalTextModelID.qwen35_4B4Bit.rawValue)
        )
        #expect(mode == .dynamic,
            "Transformer must resolve as .dynamic per V6.2 §1.4; got \(mode)")
    }

    @Test("Resolver: cloud model → .dynamic")
    func resolverCloudModelMapsToDynamic() {
        // Any concrete CloudTextModelID variant — all cloud transformers
        // use quadratic attention and resolve as .dynamic. GPT-5.4 is
        // chosen here because the variant name is stable per
        // `CloudTextModelID` enum.
        let mode = AnswerPacketEmitter.resolveAttentionMode(
            selection: .cloud(.openAIGPT54)
        )
        #expect(mode == .dynamic,
            "Cloud transformer must resolve as .dynamic; got \(mode)")
    }

    @Test("Resolver: Apple Intelligence → .dynamic")
    func resolverAppleIntelligenceMapsToDynamic() {
        let mode = AnswerPacketEmitter.resolveAttentionMode(
            selection: .appleIntelligence
        )
        #expect(mode == .dynamic,
            "Apple Intelligence FoundationModels is transformer-based; got \(mode)")
    }

    @Test("Resolver: unknown localMLX id → .unavailable")
    func resolverUnknownLocalIdMapsToUnavailable() {
        let mode = AnswerPacketEmitter.resolveAttentionMode(
            selection: .localMLX("bogus-model-id-that-does-not-exist")
        )
        #expect(mode == .unavailable,
            "Unknown local model id must resolve as .unavailable; got \(mode)")
    }

    @Test("turnCompletionStub with interruptBucket parameter populates field")
    func stubAcceptsInterruptBucket() {
        let mediumPacket = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 10,
            outputTokens: 20,
            interruptBucket: .medium
        )
        #expect(mediumPacket.interruptBucket == .medium)

        let highPacket = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 10,
            outputTokens: 20,
            interruptBucket: .high
        )
        #expect(highPacket.interruptBucket == .high)

        // Default remains .unavailable for backward compatibility.
        let defaultPacket = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 10,
            outputTokens: 20
        )
        #expect(defaultPacket.interruptBucket == .unavailable)
    }

    @Test("AnswerPacket Codable round-trips with interruptBucket field")
    func answerPacketRoundTripsWithBucket() throws {
        let packet = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 10,
            outputTokens: 20,
            attentionMode: .staticFallback,
            interruptBucket: .medium
        )
        let encoded = try JSONEncoder().encode(packet)
        let decoded = try JSONDecoder().decode(AnswerPacket.self, from: encoded)
        #expect(decoded.interruptBucket == .medium)
        #expect(decoded.attentionMode == .staticFallback)
    }

    @Test("AnswerPacket Codable: missing interrupt_bucket decodes as .unavailable (backward-compat)")
    func legacyPacketDecodesUnavailableBucket() throws {
        // Simulate an older packet emitted before the V6.2 #4 schema
        // bump — JSON without the `interrupt_bucket` key. The decoder
        // must accept it and produce `.unavailable`.
        let legacyJSON = """
        {
            "id": "legacy-1",
            "claims": [],
            "residency_signals": [],
            "ui_label": "plausible_but_unverified",
            "attention_mode": "unavailable",
            "witnessed_state_ref": "stop:end_turn;in:0;out:0",
            "mutation_envelope_ref": "legacy-1"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AnswerPacket.self, from: legacyJSON)
        #expect(decoded.interruptBucket == .unavailable,
            "legacy packets without interrupt_bucket must decode as .unavailable; got \(decoded.interruptBucket)")
    }

    @Test("Emitter snapshot tracks count + first/last timestamps")
    func snapshotTracksTimestamps() async {
        let emitter = await freshEmitter()

        let empty = await emitter.snapshot()
        #expect(empty.count == 0)
        #expect(empty.totalEmitted == 0)
        #expect(empty.firstEmittedAt == nil)
        #expect(empty.lastEmittedAt == nil)
        #expect(empty.latest == nil)

        let packet = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 10,
            outputTokens: 20
        )
        await emitter.emit(packet)

        let single = await emitter.snapshot()
        #expect(single.count == 1)
        #expect(single.totalEmitted == 1)
        #expect(single.firstEmittedAt != nil)
        #expect(single.lastEmittedAt != nil)
        #expect(single.firstEmittedAt == single.lastEmittedAt,
            "first emit: firstAt and lastAt must be equal")
        #expect(single.latest?.id == packet.id)

        // Sleep a tick to ensure the second emit has a distinct
        // timestamp. We don't lock specific intervals here — just
        // require lastEmittedAt to move forward.
        try? await Task.sleep(nanoseconds: 2_000_000)

        let second = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 5,
            outputTokens: 10
        )
        await emitter.emit(second)

        let twoEmits = await emitter.snapshot()
        #expect(twoEmits.count == 2)
        #expect(twoEmits.totalEmitted == 2)
        #expect(twoEmits.firstEmittedAt == single.firstEmittedAt,
            "firstEmittedAt must be sticky across subsequent emits")
        #expect(twoEmits.lastEmittedAt != nil)
        if let firstAt = twoEmits.firstEmittedAt, let lastAt = twoEmits.lastEmittedAt {
            #expect(lastAt >= firstAt,
                "lastEmittedAt must advance with each emit")
        }
        #expect(twoEmits.latest?.id == second.id)
    }

    @Test("Snapshot modeCounts + bucketCounts track per-emit histograms")
    func snapshotTracksHistograms() async {
        let emitter = await freshEmitter()

        // Emit 3 dynamic + 1 staticFallback packet with different buckets.
        let plans: [(AttentionMode, InterruptBucket)] = [
            (.dynamic, .low),
            (.dynamic, .low),
            (.dynamic, .medium),
            (.staticFallback, .high),
        ]
        for (mode, bucket) in plans {
            let packet = AnswerPacket.turnCompletionStub(
                stopReason: "end_turn",
                inputTokens: 10,
                outputTokens: 20,
                attentionMode: mode,
                interruptBucket: bucket
            )
            await emitter.emit(packet)
        }

        let snap = await emitter.snapshot()

        // 4 emits total — sums must agree.
        #expect(snap.totalEmitted == 4)
        let modeSum = snap.modeCounts.values.reduce(0, +)
        let bucketSum = snap.bucketCounts.values.reduce(0, +)
        #expect(modeSum == snap.totalEmitted,
            "sum(modeCounts) must equal totalEmitted; got \(modeSum) vs \(snap.totalEmitted)")
        #expect(bucketSum == snap.totalEmitted,
            "sum(bucketCounts) must equal totalEmitted; got \(bucketSum) vs \(snap.totalEmitted)")

        // Per-mode + per-bucket breakdowns match the emit plan.
        #expect(snap.modeCounts[.dynamic] == 3)
        #expect(snap.modeCounts[.staticFallback] == 1)
        #expect(snap.modeCounts[.unavailable] ?? 0 == 0)
        #expect(snap.bucketCounts[.low] == 2)
        #expect(snap.bucketCounts[.medium] == 1)
        #expect(snap.bucketCounts[.high] == 1)
        #expect(snap.bucketCounts[.unavailable] ?? 0 == 0)
    }

    @Test("Histogram counters survive ring eviction (monotonic)")
    func histogramSurvivesRingEviction() async {
        let emitter = await freshEmitter()

        // Emit one more than the ring can hold; histogram counts must
        // still equal totalEmitted (they're monotonic, not bound by ring).
        let total = AnswerPacketEmitter.maxRingSize + 5
        for _ in 0..<total {
            await emitter.emit(AnswerPacket.turnCompletionStub(
                stopReason: "end_turn",
                inputTokens: 0,
                outputTokens: 1,
                attentionMode: .dynamic,
                interruptBucket: .low
            ))
        }

        let snap = await emitter.snapshot()
        #expect(snap.totalEmitted == total)
        #expect(snap.modeCounts[.dynamic] == total,
            "monotonic histogram must survive ring eviction; got \(snap.modeCounts[.dynamic] ?? 0)")
        #expect(snap.bucketCounts[.low] == total)
    }

    @Test("Snapshot Equatable supports change-detection in the diagnostics row")
    func snapshotEquatable() async {
        let emitter = await freshEmitter()

        let a = await emitter.snapshot()
        let b = await emitter.snapshot()
        #expect(a == b, "two snapshots of an unchanged emitter must be equal")

        await emitter.emit(AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 0,
            outputTokens: 1
        ))
        let c = await emitter.snapshot()
        #expect(a != c, "snapshot must compare unequal after emit changed state")
    }

    @Test("didEmitNotification is named correctly and unique")
    func notificationNameIsStable() {
        // Lock the wire-level notification name so downstream listeners
        // (the AnswerPacketHealthRow + any future replay-export consumer)
        // can subscribe to a stable identifier.
        #expect(
            AnswerPacketEmitter.didEmitNotification ==
                Notification.Name("com.epistemos.answerPacket.didEmit")
        )
    }

    @Test("turnCompletionStub with attentionMode parameter populates field")
    func stubAcceptsAttentionMode() {
        let staticPacket = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 10,
            outputTokens: 20,
            attentionMode: .staticFallback
        )
        #expect(staticPacket.attentionMode == .staticFallback)

        let dynamicPacket = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 10,
            outputTokens: 20,
            attentionMode: .dynamic
        )
        #expect(dynamicPacket.attentionMode == .dynamic)

        // Default remains .unavailable for backward compatibility with
        // first-wiring call sites that don't yet thread attentionMode.
        let defaultPacket = AnswerPacket.turnCompletionStub(
            stopReason: "end_turn",
            inputTokens: 10,
            outputTokens: 20
        )
        #expect(defaultPacket.attentionMode == .unavailable)
    }
}
