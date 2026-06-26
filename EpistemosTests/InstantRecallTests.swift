import Testing
@testable import Epistemos

@Suite("InstantRecall")
@MainActor
struct InstantRecallTests {
    @Test("indexes notes and returns ranked matches")
    func indexesNotesAndReturnsRankedMatches() {
        let service = InstantRecallService()
        service.indexNote(noteId: "rust", text: "Rust systems programming and memory safety")
        service.indexNote(noteId: "pasta", text: "Italian pasta sauce and cooking notes")

        let results = service.search(queryText: "Rust memory", topK: 1)

        #expect(service.isReady)
        #expect(service.documentCount == 2)
        #expect(results.map(\.docId) == ["rust"])
        #expect(service.lastResults.map(\.docId) == ["rust"])
        #expect(service.searchCount == 1)
        #expect(service.lastSearchLatencyMs >= 0)
    }

    @Test("empty note bodies remove indexed documents")
    func emptyNoteBodiesRemoveIndexedDocuments() {
        let service = InstantRecallService()
        service.indexNote(noteId: "transient", text: "Bayesian evidence and posterior updates")
        #expect(service.documentCount == 1)

        service.indexNote(noteId: "transient", text: "   \n  ")

        #expect(service.documentCount == 0)
        #expect(service.search(queryText: "Bayesian evidence").isEmpty)
    }

    @Test("initial snapshot provider hydrates on first search")
    func initialSnapshotProviderHydratesOnFirstSearch() {
        let service = InstantRecallService()
        service.configureInitialSnapshotProvider {
            [
                (id: "posterior", text: "Hidden Markov models and posterior decoding"),
                (id: "recipe", text: "Apple pie recipe and cinnamon filling"),
            ]
        }

        let results = service.search(queryText: "posterior decoding", topK: 5)

        #expect(service.documentCount == 2)
        #expect(results.first?.docId == "posterior")
    }

    @Test("async search shares the same index and metrics")
    func asyncSearchSharesIndexAndMetrics() async {
        let service = InstantRecallService()
        service.indexNote(noteId: "context", text: "Contextual search retrieves vault evidence")

        let results = await service.searchAsync(query: "vault evidence", topK: 5)

        #expect(results.first?.docId == "context")
        #expect(service.searchCount == 1)
        #expect(service.averageSearchLatencyMs >= 0)
        #expect(service.maxSearchLatencyMs >= service.lastSearchLatencyMs)
    }

    @Test("clear index resets documents results and metrics")
    func clearIndexResetsDocumentsResultsAndMetrics() {
        let service = InstantRecallService()
        service.indexNote(noteId: "doc", text: "Fast recall over local notes")
        _ = service.search(queryText: "recall notes")

        service.clearIndex()

        #expect(service.documentCount == 0)
        #expect(service.lastResults.isEmpty)
        #expect(service.searchCount == 0)
        #expect(service.averageSearchLatencyMs == 0)
        #expect(service.maxSearchLatencyMs == 0)
    }
}
