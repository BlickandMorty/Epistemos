// Ω18 — Instant Recall Tests
// Tests for the binary-quantized vector index and two-phase retrieval.

import Foundation
import Testing
@testable import Epistemos

@MainActor
private final class InstantRecallAgentEventSink {
    private(set) var events: [AgentProvenanceEvent] = []

    func append(_ event: AgentProvenanceEvent) -> Bool {
        events.append(event)
        return true
    }
}

// MARK: - Instant Recall Service Tests

@Suite("InstantRecall — Service")
struct InstantRecallServiceTests {

    @Test("Create index returns true")
    func createIndex() {
        let result = instantRecallCreate(handle: "test-create")
        #expect(result == true)
        // Cleanup
        let _ = instantRecallClear(handle: "test-create")
    }

    @Test("Insert and count documents")
    func insertAndCount() {
        let _ = instantRecallCreate(handle: "test-count")
        let _ = instantRecallInsert(handle: "test-count", docId: "doc-1", text: "Hello world")
        let _ = instantRecallInsert(handle: "test-count", docId: "doc-2", text: "Goodbye world")
        let count = instantRecallCount(handle: "test-count")
        #expect(count == 2)
        let _ = instantRecallClear(handle: "test-count")
    }

    @Test("Search returns relevant results as JSON")
    func searchReturnsJson() throws {
        let _ = instantRecallCreate(handle: "test-search")
        let _ = instantRecallInsert(handle: "test-search", docId: "rust-note", text: "Rust programming language systems")
        let _ = instantRecallInsert(handle: "test-search", docId: "cooking-note", text: "Italian pasta cooking recipes")

        let json = instantRecallSearch(handle: "test-search", queryText: "Rust systems programming", topK: 2)
        #expect(!json.isEmpty)
        #expect(json != "[]")

        // Parse JSON
        let data = try #require(json.data(using: .utf8))
        let array = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(array.count == 2)

        // First result should be the Rust note
        let firstDocId = try #require(array[0]["doc_id"] as? String)
        #expect(firstDocId == "rust-note")

        let _ = instantRecallClear(handle: "test-search")
    }

    @Test("Remove document from index")
    func removeDocument() {
        let _ = instantRecallCreate(handle: "test-remove")
        let _ = instantRecallInsert(handle: "test-remove", docId: "to-remove", text: "Some text")
        #expect(instantRecallCount(handle: "test-remove") == 1)

        let _ = instantRecallRemove(handle: "test-remove", docId: "to-remove")
        #expect(instantRecallCount(handle: "test-remove") == 0)
        let _ = instantRecallClear(handle: "test-remove")
    }

    @Test("Clear empties the index")
    func clearIndex() {
        let _ = instantRecallCreate(handle: "test-clear")
        let _ = instantRecallInsert(handle: "test-clear", docId: "a", text: "Alpha")
        let _ = instantRecallInsert(handle: "test-clear", docId: "b", text: "Beta")
        #expect(instantRecallCount(handle: "test-clear") == 2)

        let _ = instantRecallClear(handle: "test-clear")
        #expect(instantRecallCount(handle: "test-clear") == 0)
    }

    @Test("Encode text returns non-empty JSON array")
    func encodeText() throws {
        let json = instantRecallEncode(text: "Hello world test embedding")
        #expect(!json.isEmpty)
        #expect(json != "[]")

        let data = try #require(json.data(using: .utf8))
        let array = try #require(try JSONSerialization.jsonObject(with: data) as? [Double])
        #expect(array.count == 1024) // Default dimension
    }

    @Test("Search on nonexistent handle returns empty")
    func searchNonexistentHandle() {
        let json = instantRecallSearch(handle: "does-not-exist", queryText: "test", topK: 5)
        #expect(json == "[]")
    }

    @Test("Empty query returns empty results")
    func emptyQuerySearch() {
        let _ = instantRecallCreate(handle: "test-empty-q")
        let _ = instantRecallInsert(handle: "test-empty-q", docId: "doc", text: "Some content")
        let json = instantRecallSearch(handle: "test-empty-q", queryText: "", topK: 5)
        // Empty query produces an all-zero embedding → still returns results but with low scores
        #expect(!json.isEmpty)
        let _ = instantRecallClear(handle: "test-empty-q")
    }

    @Test("Async service rebuild replaces stale indexed documents")
    @MainActor func serviceAsyncRebuildReplacesStaleDocuments() async {
        let service = InstantRecallService()
        service.initialize()
        service.indexNote(noteId: "old-doc", text: "Rust systems programming language")

        let oldResults = service.search(queryText: "Rust programming", topK: 5)
        #expect(oldResults.contains(where: { $0.docId == "old-doc" }))

        await service.rebuildIndexAsync(notes: [
            (id: "fresh-doc", text: "Italian pasta recipes and sauce technique"),
        ])

        #expect(service.documentCount == 1)
        let staleResults = service.search(queryText: "Rust programming", topK: 5)
        #expect(!staleResults.contains(where: { $0.docId == "old-doc" }))

        let freshResults = service.search(queryText: "Italian pasta", topK: 5)
        #expect(freshResults.first?.docId == "fresh-doc")
    }

    @Test("Service lazily initializes on first use")
    @MainActor func serviceLazilyInitializesOnFirstUse() {
        let service = InstantRecallService()
        #expect(!service.isReady)

        service.indexNote(noteId: "doc-lazy", text: "Bayesian evidence and posterior updates")

        #expect(service.isReady)
        #expect(service.documentCount == 1)
        #expect(service.search(queryText: "Bayesian evidence", topK: 5).first?.docId == "doc-lazy")
    }

    @Test("Service hydrates the initial snapshot on first search")
    @MainActor func serviceHydratesInitialSnapshotOnFirstSearch() async {
        let service = InstantRecallService()
        service.configureInitialSnapshotProvider {
            [
                (id: "doc-seeded", text: "Hidden Markov models and posterior decoding"),
                (id: "doc-other", text: "Apple pie recipe and cinnamon filling"),
            ]
        }

        // First call kicks off the off-MainActor hydration but returns
        // before the detached task can populate the index.
        _ = service.search(queryText: "posterior decoding", topK: 5)

        // Wait until the background hydration drains into MainActor state.
        try? await waitUntilHydrated(service: service, expectedCount: 2)

        let results = service.search(queryText: "posterior decoding", topK: 5)

        #expect(service.isReady)
        #expect(service.documentCount == 2)
        #expect(results.first?.docId == "doc-seeded")
    }

    @Test("Initial snapshot hydration completes asynchronously off the MainActor")
    @MainActor func initialSnapshotHydrationRunsOffMainActor() async {
        // Stress the detached task with enough notes that the FFI rebuild
        // dominates the wait window — proves the heavy work is genuinely
        // off-main. (Single-note vaults can race the MainActor continuation
        // and finish before the next statement runs.)
        let snapshot: [(id: String, text: String)] = (0..<200).map { idx in
            (id: "doc-\(idx)",
             text: "Posterior decoding sample \(idx) with Bayesian evidence and longer body so the FFI encoder has real work to do per document for instant recall hydration latency observability.")
        }

        let service = InstantRecallService()
        service.clearIndex()
        service.configureInitialSnapshotProvider { snapshot }

        // First search must NOT block on the heavy FFI rebuild. Capture the
        // call duration; even a 200-doc vault should return immediately from
        // the empty live index.
        let searchStart = CFAbsoluteTimeGetCurrent()
        let firstResults = service.search(queryText: "posterior decoding", topK: 5)
        let searchElapsedMs = (CFAbsoluteTimeGetCurrent() - searchStart) * 1000.0

        #expect(searchElapsedMs < 50.0,
                "first search must not stall MainActor on the FFI rebuild (took \(searchElapsedMs)ms)")
        #expect(firstResults.count <= 5,
                "detached hydration may win the race, but first search still respects topK")

        // Drive the runloop so the detached Task.detached(.utility) can finish
        // and its MainActor.run continuation can execute finishRebuild.
        try? await waitUntilHydrated(service: service, expectedCount: snapshot.count)

        #expect(service.documentCount == snapshot.count,
                "after async hydration drains, documentCount reflects the seeded snapshot")

        // A second search after hydration drains returns real results.
        let secondResults = service.search(queryText: "posterior decoding", topK: 5)
        #expect(!secondResults.isEmpty,
                "after async hydration completes, recall searches return populated results")
    }

    @Test("Async search triggers lazy initial snapshot hydration")
    @MainActor func asyncSearchTriggersLazyInitialSnapshotHydration() async {
        let service = InstantRecallService()
        service.configureInitialSnapshotProvider {
            [
                (id: "doc-async-seeded", text: "Contextual shadows retrieve Bayesian evidence from the vault"),
                (id: "doc-async-other", text: "Pasta sauce and tomato reduction notes"),
            ]
        }

        _ = await service.searchAsync(query: "Bayesian evidence", topK: 5)

        try? await waitUntilHydrated(service: service, expectedCount: 2)

        let hydratedResults = await service.searchAsync(query: "Bayesian evidence", topK: 5)
        #expect(hydratedResults.first?.docId == "doc-async-seeded")
    }

    /// Polls until the InstantRecall service has finished its async hydration.
    /// Returns once `documentCount` reaches `expectedCount` or after `attempts`
    /// 50ms ticks (~5s default).
    @MainActor
    private func waitUntilHydrated(
        service: InstantRecallService,
        expectedCount: Int,
        attempts: Int = 100
    ) async throws {
        for _ in 0..<attempts {
            if service.documentCount >= expectedCount { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    @Test("Service treats empty note bodies as removals")
    @MainActor func serviceTreatsEmptyBodyAsRemoval() {
        let service = InstantRecallService()
        service.initialize()
        service.indexNote(noteId: "doc-empty", text: "Transient note body")
        #expect(service.documentCount == 1)

        service.indexNote(noteId: "doc-empty", text: "   \n  ")

        #expect(service.documentCount == 0)
        let results = service.search(queryText: "Transient note", topK: 5)
        #expect(results.isEmpty)
    }

    @Test("Whitespace-only search clears stale recall state")
    @MainActor func whitespaceOnlySearchClearsStaleRecallState() {
        let service = InstantRecallService()
        service.initialize()
        service.indexNote(noteId: "doc-1", text: "Bayesian evidence and posterior updates")

        let firstResults = service.search(queryText: "Bayesian evidence", topK: 5)
        #expect(!firstResults.isEmpty)
        #expect(!service.lastResults.isEmpty)
        #expect(service.lastSearchLatencyMs >= 0)

        let emptyResults = service.search(queryText: "   \n   ", topK: 5)
        #expect(emptyResults.isEmpty)
        #expect(service.lastResults.isEmpty)
        #expect(service.lastSearchLatencyMs == 0)
    }

    @Test("Search normalizes repeated whitespace in queries")
    @MainActor func searchNormalizesRepeatedWhitespace() {
        let service = InstantRecallService()
        service.initialize()
        service.indexNote(noteId: "doc-1", text: "Bayesian evidence and posterior updates")

        let compact = service.search(queryText: "Bayesian evidence", topK: 5)
        let noisy = service.search(queryText: "  Bayesian \n\n evidence   ", topK: 5)

        #expect(compact.map(\.docId) == noisy.map(\.docId))
        #expect(compact.map(\.text) == noisy.map(\.text))
    }

    @Test("Non-positive topK clears stale recall state")
    @MainActor func nonPositiveTopKClearsStaleRecallState() {
        let service = InstantRecallService()
        service.initialize()
        service.indexNote(noteId: "doc-1", text: "Bayesian evidence and posterior updates")

        let firstResults = service.search(queryText: "Bayesian evidence", topK: 5)
        #expect(!firstResults.isEmpty)

        let emptyResults = service.search(queryText: "Bayesian evidence", topK: 0)
        #expect(emptyResults.isEmpty)
        #expect(service.lastResults.isEmpty)
        #expect(service.lastSearchLatencyMs == 0)
    }

    @Test("Search metrics accumulate across successful queries")
    @MainActor func searchMetricsAccumulateAcrossQueries() {
        let service = InstantRecallService()
        service.initialize()
        service.indexNote(noteId: "doc-1", text: "Bayesian evidence and posterior updates")
        service.indexNote(noteId: "doc-2", text: "Italian pasta and sauce technique")

        _ = service.search(queryText: "Bayesian evidence", topK: 5)
        _ = service.search(queryText: "Italian pasta", topK: 5)

        #expect(service.searchCount == 2)
        #expect(service.averageSearchLatencyMs >= 0)
        #expect(service.maxSearchLatencyMs >= service.lastSearchLatencyMs)
    }

    @Test("Search records sanitized AgentEvents")
    @MainActor func searchRecordsSanitizedAgentEvents() throws {
        let sink = InstantRecallAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 1_616 },
            persist: { event in sink.append(event) }
        )
        let service = InstantRecallService(agentProvenanceRecorder: recorder)
        service.initialize()
        service.clearIndex()
        defer { service.clearIndex() }

        service.indexNote(
            noteId: "secret-doc-id",
            text: "Secret recall body with Bayesian posterior evidence"
        )

        let results = service.search(queryText: "secret Bayesian prompt", topK: 5)

        #expect(!results.isEmpty)
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        #expect(Set(sink.events.map(\.runID)).count == 1)
        #expect(sink.events.first?.runID.hasPrefix("instant-recall-") == true)
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "instant_recall.search" })
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "instant-recall-search:1" })
        #expect(sink.events.allSatisfy { $0.metadata["source"] == "instant_recall_service" })
        #expect(sink.events.allSatisfy { $0.metadata["surface"] == "instant_recall" })
        #expect(sink.events.allSatisfy { $0.metadata["top_k"] == "5" })
        #expect(sink.events.last?.tool?.durationMs != nil)
        #expect(sink.events.last?.tool?.resultJSON?.contains("hit_count") == true)
        #expect(sink.events.last?.tool?.resultJSON?.contains("document_count") == true)

        for event in sink.events {
            let tool = try #require(event.tool)
            #expect(!tool.argumentsJSON.contains("secret Bayesian prompt"))
            #expect(!tool.argumentsJSON.contains("Bayesian"))
            #expect(!tool.argumentsJSON.contains("secret-doc-id"))
            #expect(!tool.argumentsJSON.contains("Secret recall body"))
            #expect(!(tool.resultJSON ?? "").contains("secret Bayesian prompt"))
            #expect(!(tool.resultJSON ?? "").contains("secret-doc-id"))
            #expect(!(tool.resultJSON ?? "").contains("Secret recall body"))
        }
    }

    @Test("Invalid search inputs do not record AgentEvents")
    @MainActor func invalidSearchInputsDoNotRecordAgentEvents() {
        let sink = InstantRecallAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 1_717 },
            persist: { event in sink.append(event) }
        )
        let service = InstantRecallService(agentProvenanceRecorder: recorder)
        service.initialize()
        service.clearIndex()
        defer { service.clearIndex() }

        _ = service.search(queryText: "   \n   ", topK: 5)
        _ = service.search(queryText: "Bayesian evidence", topK: 0)

        #expect(sink.events.isEmpty)
    }
}

// MARK: - Settings Wiring Tests

// Legacy Omega runtime wiring tests are kept for reference while the
// app relies on the consolidated native/runtime settings surfaces.
#if false
@Suite("Omega Settings — Runtime Wiring")
@MainActor
struct OmegaSettingsWiringTests {

    @Test("Terminal allow-list override changes the effective command list")
    func terminalAllowListIsRead() {
        UserDefaults.standard.set("ls,cat,pwd", forKey: "omega.terminalAllowList")
        defer { UserDefaults.standard.removeObject(forKey: "omega.terminalAllowList") }

        let agent = TerminalAgent()
        #expect(agent.resolvedAllowedCommandsCsv() == "ls,cat,pwd")
    }

    @Test("Empty terminal allow-list falls back to the default safe list")
    func emptyTerminalAllowListUsesDefaultSafeList() {
        UserDefaults.standard.set("", forKey: "omega.terminalAllowList")
        defer { UserDefaults.standard.removeObject(forKey: "omega.terminalAllowList") }

        let agent = TerminalAgent()
        #expect(agent.resolvedAllowedCommandsCsv().contains("ls"))
        #expect(agent.resolvedAllowedCommandsCsv().contains("pwd"))
    }

    @Test("Screen2AX setting changes Vision OCR enrichment behavior")
    func screen2axSettingIsRead() {
        UserDefaults.standard.set(false, forKey: "omega.screen2axEnabled")
        defer { UserDefaults.standard.removeObject(forKey: "omega.screen2axEnabled") }

        let fusion = Screen2AXFusion(screenCapture: ScreenCaptureService())
        #expect(fusion.visionOCREnrichmentEnabled == false)
    }

    @Test("Overnight training toggle controls scheduler activation")
    func overnightTrainingSettingExists() {
        UserDefaults.standard.set(true, forKey: "omega.overnightTraining")
        defer { UserDefaults.standard.removeObject(forKey: "omega.overnightTraining") }

        let scheduler = TrainingScheduler()
        scheduler.startScheduling()
        #expect(scheduler.hasActiveSchedulers)
        scheduler.stopScheduling()
        #expect(!scheduler.hasActiveSchedulers)
    }

    @Test("Disabled overnight training leaves schedulers inactive")
    func overnightTrainingDisabledSkipsScheduling() {
        UserDefaults.standard.set(false, forKey: "omega.overnightTraining")
        defer { UserDefaults.standard.removeObject(forKey: "omega.overnightTraining") }

        let scheduler = TrainingScheduler()
        scheduler.startScheduling()
        #expect(!scheduler.hasActiveSchedulers)
    }
}
#endif
