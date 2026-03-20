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

    @Test("outline payload decoding covers added updated and removed sections")
    func outlinePayloadDecodingCoversAllSections() async throws {
        let bridge = try #require(KnowledgeCoreBridge(peerId: 16))
        let subscriptionId = await bridge.subscribeOutline(pageId: "page-sections")
        #expect(subscriptionId != nil)

        _ = await bridge.drainPayloads()

        let insertedA = await bridge.insertBlock(
            pageId: "page-sections",
            blockId: "block-a",
            parentId: nil,
            index: 0,
            content: "A"
        )
        #expect(insertedA)

        let insertedB = await bridge.insertBlock(
            pageId: "page-sections",
            blockId: "block-b",
            parentId: nil,
            index: 1,
            content: "B"
        )
        #expect(insertedB)

        let inserts = await bridge.drainPayloads()
        #expect(inserts.count == 2)
        #expect(inserts.flatMap(\.added).map(\.blockId) == ["block-a", "block-b"])

        let moved = await bridge.moveBlock(
            pageId: "page-sections",
            blockId: "block-b",
            parentId: nil,
            index: 0
        )
        #expect(moved)

        let updates = await bridge.drainPayloads()
        let updatePayload = try #require(updates.last)
        #expect(updatePayload.updated.count == 1)
        #expect(updatePayload.updated.first?.blockId == "block-b")
        #expect(updatePayload.added.isEmpty)
        #expect(updatePayload.removed.isEmpty)

        let deleted = await bridge.deleteBlock(pageId: "page-sections", blockId: "block-b")
        #expect(deleted)

        let removals = await bridge.drainPayloads()
        let removalPayload = try #require(removals.last)
        #expect(removalPayload.removed.count == 1)
        #expect(removalPayload.removed.first?.blockId == "block-b")
        #expect(removalPayload.added.isEmpty)
        #expect(removalPayload.updated.isEmpty)
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
            (
                runtime.totalBatches,
                runtime.totalFrames,
                runtime.lastBatch,
                runtime.lastDrainDurationNs,
                runtime.totalDrainDurationNs,
                runtime.totalApplyDurationNs
            )
        }
        #expect(totals.0 >= 1)
        #expect(totals.1 >= 1)
        #expect(totals.2.last?.addedCount == 1)
        #expect(totals.3 > 0)
        #expect(totals.4 >= totals.3)
        #expect(totals.5 >= 0)

        await MainActor.run {
            runtime.stop()
        }
    }

    @Test("shadow runtime reuses projected strings across repeated row applies")
    func shadowRuntimeReusesProjectedStrings() async throws {
        let runtime = try await MainActor.run {
            try #require(KnowledgeCoreShadowRuntime(peerId: 17))
        }

        let subscriptionId = await runtime.subscribeOutline(pageId: "page-cache")
        #expect(subscriptionId != nil)
        _ = await runtime.ingestDocument(
            pageId: "page-cache",
            format: .markdown,
            text: "- Alpha\n- Beta"
        )

        try? await Task.sleep(for: .milliseconds(40))

        let firstStats = await MainActor.run {
            (
                runtime.projectedRowCount,
                runtime.stringCacheHits,
                runtime.stringCacheMisses
            )
        }

        #expect(firstStats.0 == 2)
        #expect(firstStats.2 > 0)

        let updated = await runtime.ingestDocument(
            pageId: "page-cache",
            format: .markdown,
            text: "- Beta\n- Alpha"
        )
        #expect(updated)

        try? await Task.sleep(for: .milliseconds(40))

        let secondStats = await MainActor.run {
            (
                runtime.projectedRowCount,
                runtime.stringCacheHits,
                runtime.stringCacheMisses
            )
        }

        #expect(secondStats.0 == 2)
        #expect(secondStats.1 > firstStats.1)
        #expect(secondStats.2 >= firstStats.2)

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
