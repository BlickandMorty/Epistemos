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

    @Test("borrowed projection drains scalar rows without materializing Swift strings")
    func borrowedProjectionDrainsScalarRowsWithoutMaterializingStrings() async throws {
        let bridge = try #require(KnowledgeCoreBridge(peerId: 23))
        let subscriptionId = await bridge.subscribeOutline(pageId: "page-borrowed")
        #expect(subscriptionId != nil)
        _ = await bridge.drainPayloads()

        let markdown = "# Borrowed\n- Body"
        let ingested = await bridge.ingestDocument(
            pageId: "page-borrowed",
            format: .markdown,
            text: markdown
        )
        #expect(ingested)

        let projection = await bridge.drainBorrowedProjections()
        let payload = try #require(projection.payloads.first)
        #expect(projection.summaries.count == 1)
        #expect(payload.summary.kind == .outline)
        #expect(projection.projectedRowCount == 2)
        #expect(projection.materializedStringCount == 0)
        #expect(payload.added.map(\.rowKind) == [.block, .block])
        #expect(payload.added.map(\.contentByteCount) == ["# Borrowed", "Body"].map(\.utf8.count))
        #expect(payload.added.allSatisfy { $0.blockIdHash != 0 })
        #expect(payload.added.allSatisfy { $0.orderKeyHash != 0 })
        #expect(projection.projectedStringBytes >= "# BorrowedBody".utf8.count)

        let afterBorrowedDrain = await bridge.drainPayloads()
        #expect(afterBorrowedDrain.isEmpty)
    }

    @MainActor
    @Test("runtime adapter stays off until deterministic feature flag is enabled")
    func runtimeAdapterRequiresDeterministicFlag() async throws {
        let bridge = try #require(KnowledgeCoreBridge(peerId: 18))
        let subscriptionId = await bridge.subscribeOutline(pageId: "page-adapter-off")
        #expect(subscriptionId != nil)
        _ = await bridge.drainPayloads()

        let ingested = await bridge.ingestDocument(
            pageId: "page-adapter-off",
            format: .markdown,
            text: "- Adapter Off"
        )
        #expect(ingested)
        let payloads = await bridge.drainPayloads()
        #expect(payloads.isEmpty == false)

        var applied: [KnowledgeCorePayloadSnapshot] = []
        let adapter = KnowledgeCoreRuntimeAdapter(flags: .disabled) { payload in
            applied.append(payload)
        }

        let result = adapter.apply(payloads)
        #expect(applied.isEmpty)
        #expect(result.appliedCount == 0)
        #expect(result.fallbackCount == payloads.count)
        #expect(result.fallbackReasons == Array(repeating: .disabled, count: payloads.count))
    }

    @MainActor
    @Test("runtime adapter applies real outline payloads when deterministic flag is enabled")
    func runtimeAdapterAppliesRealOutlinePayloadsWhenEnabled() async throws {
        let bridge = try #require(KnowledgeCoreBridge(peerId: 19))
        let subscriptionId = await bridge.subscribeOutline(pageId: "page-adapter-on")
        #expect(subscriptionId != nil)
        _ = await bridge.drainPayloads()

        let ingested = await bridge.ingestDocument(
            pageId: "page-adapter-on",
            format: .markdown,
            text: "- Adapter On"
        )
        #expect(ingested)
        let payloads = await bridge.drainPayloads()
        let payload = try #require(payloads.first)
        #expect(payload.kind == .outline)
        #expect(payload.added.map(\.content) == ["Adapter On"])

        var applied: [KnowledgeCorePayloadSnapshot] = []
        let adapter = KnowledgeCoreRuntimeAdapter(flags: deterministicRuntimeFlagsEnabled()) { payload in
            applied.append(payload)
        }

        let result = adapter.apply(payloads)
        #expect(result.appliedCount == payloads.count)
        #expect(result.fallbackCount == 0)
        #expect(result.fallbackReasons.isEmpty)
        #expect(applied == payloads)
    }

    @MainActor
    @Test("runtime adapter falls back for unsupported payload kinds")
    func runtimeAdapterFallsBackForUnsupportedPayloadKinds() {
        let payload = KnowledgeCorePayloadSnapshot(
            txId: 1,
            subscriptionId: 99,
            kind: .tasks,
            added: [],
            updated: [],
            removed: []
        )
        var applied: [KnowledgeCorePayloadSnapshot] = []
        let adapter = KnowledgeCoreRuntimeAdapter(flags: deterministicRuntimeFlagsEnabled()) { payload in
            applied.append(payload)
        }

        let result = adapter.apply([payload])
        #expect(applied.isEmpty)
        #expect(result.appliedCount == 0)
        #expect(result.fallbackCount == 1)
        #expect(result.fallbackReasons == [.unsupportedKind])
    }

    @MainActor
    @Test("runtime binding applies only registered subscription payloads")
    func runtimeBindingAppliesOnlyRegisteredSubscriptionPayloads() async throws {
        let bridge = try #require(KnowledgeCoreBridge(peerId: 20))
        let registeredSubscription = try #require(await bridge.subscribeOutline(pageId: "page-binding-registered"))
        let unregisteredSubscription = try #require(await bridge.subscribeOutline(pageId: "page-binding-unregistered"))
        _ = await bridge.drainPayloads()

        let ingestedRegistered = await bridge.ingestDocument(
            pageId: "page-binding-registered",
            format: .markdown,
            text: "- Registered"
        )
        #expect(ingestedRegistered)
        let ingestedUnregistered = await bridge.ingestDocument(
            pageId: "page-binding-unregistered",
            format: .markdown,
            text: "- Unregistered"
        )
        #expect(ingestedUnregistered)

        let payloads = await bridge.drainPayloads()
        #expect(Set(payloads.map(\.subscriptionId)) == [registeredSubscription, unregisteredSubscription])

        var applied: [KnowledgeCorePayloadSnapshot] = []
        let binding = KnowledgeCoreRuntimeBinding(flags: deterministicRuntimeFlagsEnabled())
        binding.register(subscriptionId: registeredSubscription) { payload in
            applied.append(payload)
        }

        let result = binding.apply(payloads)
        #expect(applied.map(\.subscriptionId) == [registeredSubscription])
        #expect(applied.first?.added.map(\.content) == ["Registered"])
        #expect(result.appliedCount == 1)
        #expect(result.fallbackCount == 1)
        #expect(result.fallbackReasons == [.unregisteredSubscription])
    }

    @MainActor
    @Test("runtime binding unregisters subscription sinks before applying payloads")
    func runtimeBindingUnregistersSubscriptionSinks() {
        let payload = KnowledgeCorePayloadSnapshot(
            txId: 2,
            subscriptionId: 41,
            kind: .outline,
            added: [],
            updated: [],
            removed: []
        )
        var applied: [KnowledgeCorePayloadSnapshot] = []
        let binding = KnowledgeCoreRuntimeBinding(flags: deterministicRuntimeFlagsEnabled())
        binding.register(subscriptionId: 41) { payload in
            applied.append(payload)
        }
        binding.unregister(subscriptionId: 41)

        let result = binding.apply([payload])
        #expect(applied.isEmpty)
        #expect(result.appliedCount == 0)
        #expect(result.fallbackCount == 1)
        #expect(result.fallbackReasons == [.unregisteredSubscription])
    }

    @Test("TOC items compare by document position, not generated identity")
    func tocItemsCompareByContentAndPosition() {
        let first = TOCItem(level: 1, title: "Same", charOffset: 4, kind: .heading)
        let second = TOCItem(level: 1, title: "Same", charOffset: 4, kind: .heading)

        #expect(first == second)
    }

    @MainActor
    @Test("deterministic outline projection stays dormant when feature flag is disabled")
    func deterministicOutlineProjectionStaysDormantWhenDisabled() async {
        let state = KnowledgeCoreOutlineProjectionState(flags: .disabled, peerId: 21)
        let fallbackHeadings = TOCParser.parse("# Dormant")

        let result = await state.refresh(
            pageId: "page-outline-disabled",
            markdown: "# Dormant",
            fallbackHeadings: fallbackHeadings
        )

        #expect(result == .empty)
        #expect(state.items.isEmpty)
        #expect(state.lastAppliedTxId == nil)
    }

    @MainActor
    @Test("deterministic outline projection applies real bridge payloads to TOC state")
    func deterministicOutlineProjectionAppliesRealBridgePayloads() async {
        let state = KnowledgeCoreOutlineProjectionState(
            flags: deterministicRuntimeFlagsEnabled(),
            peerId: 22
        )
        let firstMarkdown = "# Heading\nBody\n## Second"
        let firstFallbackHeadings = TOCParser.parse(firstMarkdown)

        let firstResult = await state.refresh(
            pageId: "page-outline-state",
            markdown: firstMarkdown,
            fallbackHeadings: firstFallbackHeadings
        )

        #expect(firstResult.appliedCount == 1)
        #expect(firstResult.fallbackCount == 0)
        #expect(state.lastAppliedTxId != nil)
        #expect(state.items.map(\.title) == ["Heading", "Second"])
        #expect(state.items.map(\.charOffset) == firstFallbackHeadings.map(\.charOffset))

        let updatedMarkdown = "# Heading\n## Third"
        let updatedFallbackHeadings = TOCParser.parse(updatedMarkdown)
        let updatedResult = await state.refresh(
            pageId: "page-outline-state",
            markdown: updatedMarkdown,
            fallbackHeadings: updatedFallbackHeadings
        )

        #expect(updatedResult.appliedCount == 1)
        #expect(updatedResult.fallbackCount == 0)
        #expect(state.items.map(\.title) == ["Heading", "Third"])
        #expect(state.items.map(\.charOffset) == updatedFallbackHeadings.map(\.charOffset))
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

    private func deterministicRuntimeFlagsEnabled() -> EpistemosRuntimeFeatureFlags {
        EpistemosRuntimeFeatureFlags(
            deterministicKnowledgeCoreRuntime: true,
            borrowedKnowledgeRows: false,
            rawThoughtsBulkLane: false,
            staticArtifactRouting: false,
            graphEdgePrefetch: false
        )
    }
}
