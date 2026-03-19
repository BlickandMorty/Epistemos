import Testing
@testable import Epistemos

@Suite("Knowledge Core Bridge")
struct KnowledgeCoreBridgeTests {

    @Test("outline diffs drain from the shared-memory ring")
    func outlineDiffsDrainFromRing() async throws {
        let bridge = try #require(KnowledgeCoreBridge(peerId: 11))
        let subscriptionId = await bridge.subscribeOutline(pageId: "page-1")
        #expect(subscriptionId != nil)

        let initial = await bridge.drainPayloads()
        #expect(initial.count == 1)
        #expect(initial.first?.kind == .outline)
        #expect(initial.first?.added.isEmpty == true)

        let ingested = await bridge.ingestDocument(
            pageId: "page-1",
            format: .markdown,
            text: "- First\n- Second"
        )
        #expect(ingested)

        let payloads = await bridge.drainPayloads()
        let payload = try #require(payloads.first)
        #expect(payload.kind == .outline)
        #expect(payload.added.count == 2)
        #expect(payload.updated.isEmpty)
        #expect(payload.removed.isEmpty)
        #expect(payload.added.map(\.content) == ["First", "Second"])
    }

    @Test("draining summaries advances tail and avoids duplicate delivery")
    func drainingSummariesAdvancesTail() async throws {
        let bridge = try #require(KnowledgeCoreBridge(peerId: 12))
        let subscriptionId = await bridge.subscribeTasks()
        #expect(subscriptionId != nil)

        let first = await bridge.drainSummaries()
        #expect(first.count == 1)
        #expect(first.first?.kind == .tasks)

        let second = await bridge.drainSummaries()
        #expect(second.isEmpty)
    }

    @Test("shadow runtime batches summaries onto MainActor state")
    func shadowRuntimeBatchesSummaries() async throws {
        let runtime = try await MainActor.run {
            try #require(KnowledgeCoreShadowRuntime(peerId: 13))
        }

        let subscriptionId = await runtime.subscribeOutline(pageId: "page-2")
        #expect(subscriptionId != nil)
        let ingested = await runtime.ingestDocument(
            pageId: "page-2",
            format: .markdown,
            text: "- Shadow"
        )
        #expect(ingested)

        try? await Task.sleep(for: .milliseconds(40))

        let totals = await MainActor.run {
            (runtime.totalBatches, runtime.totalFrames, runtime.lastBatch)
        }
        #expect(totals.0 >= 1)
        #expect(totals.1 >= 1)
        #expect(totals.2.last?.addedCount == 1)

        await MainActor.run {
            runtime.stop()
        }
    }

    @Test("bridge surfaces typed last error for staged mutation failures")
    func bridgeSurfacesTypedLastError() async throws {
        let bridge = try #require(KnowledgeCoreBridge(peerId: 14))

        let moved = await bridge.moveBlock(
            pageId: "page-3",
            blockId: "missing-block",
            parentId: nil,
            index: 0
        )
        #expect(moved == false)

        let error = await bridge.lastErrorSnapshot()
        #expect(error?.code == .missingNode)
        #expect(error?.message.contains("missing outline node") == true)
    }

    @Test("bridge exposes fail-fast backpressure policy and transport stats")
    func bridgeExposesBackpressurePolicyAndTransportStats() async throws {
        let bridge = try #require(
            KnowledgeCoreBridge(
                slotCount: 1,
                slotPayloadBytes: 4096,
                peerId: 15
            )
        )

        let policy = await bridge.backpressurePolicy()
        #expect(policy == .failFast)

        let subscriptionId = await bridge.subscribeOutline(pageId: "page-4")
        #expect(subscriptionId != nil)

        let blocked = await bridge.ingestDocument(
            pageId: "page-4",
            format: .markdown,
            text: "- blocked"
        )
        #expect(blocked == false)

        let stats = await bridge.transportStats()
        #expect(stats.publishedFrames == 1)
        #expect(stats.ringFullFailures == 1)
        #expect(stats.droppedFrames == 0)
        #expect(stats.coalescedFrames == 0)

        let error = await bridge.lastErrorSnapshot()
        #expect(error?.code == .ringFull)
    }
}
