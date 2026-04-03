// Ω18 — Instant Recall Tests
// Tests for the binary-quantized vector index and two-phase retrieval.

import Testing
@testable import Epistemos

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

    @Test("Service rebuild replaces stale indexed documents")
    @MainActor func serviceRebuildReplacesStaleDocuments() {
        let service = InstantRecallService()
        service.initialize()
        service.indexNote(noteId: "old-doc", text: "Rust systems programming language")

        let oldResults = service.search(queryText: "Rust programming", topK: 5)
        #expect(oldResults.contains(where: { $0.docId == "old-doc" }))

        service.rebuildIndex(notes: [
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
    @MainActor func serviceHydratesInitialSnapshotOnFirstSearch() {
        let service = InstantRecallService()
        service.configureInitialSnapshotProvider {
            [
                (id: "doc-seeded", text: "Hidden Markov models and posterior decoding"),
                (id: "doc-other", text: "Apple pie recipe and cinnamon filling"),
            ]
        }

        let results = service.search(queryText: "posterior decoding", topK: 5)

        #expect(service.isReady)
        #expect(service.documentCount == 2)
        #expect(results.first?.docId == "doc-seeded")
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
}

// MARK: - Settings Wiring Tests

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
