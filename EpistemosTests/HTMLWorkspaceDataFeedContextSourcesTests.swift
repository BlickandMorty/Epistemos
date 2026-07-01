import Foundation
import SwiftData
import Testing

@testable import Epistemos

@Suite("HTML Workspace data feed context sources")
nonisolated struct HTMLWorkspaceDataFeedContextSourcesTests {
    @MainActor
    @Test("graph related note context source follows persisted note graph edges only")
    func graphRelatedNoteContextSourceFollowsPersistedNoteGraphEdgesOnly() throws {
        let schema = Schema([SDPage.self, SDGraphNode.self, SDGraphEdge.self, SDBlock.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let anchor = SDPage(title: "Anchor Note")
        anchor.body = "anchor body"
        let related = SDPage(title: "Related Note")
        related.body = "related body from graph"
        let generic = SDPage(title: "Generic Note")
        generic.body = "generic body"
        context.insert(anchor)
        context.insert(related)
        context.insert(generic)

        let anchorNode = SDGraphNode(type: .note, label: "Anchor Node", sourceId: anchor.id)
        let relatedNode = SDGraphNode(type: .note, label: "Related Node", sourceId: related.id)
        let genericNode = SDGraphNode(type: .note, label: "Generic Node", sourceId: generic.id)
        context.insert(anchorNode)
        context.insert(relatedNode)
        context.insert(genericNode)
        context.insert(SDGraphEdge(source: anchorNode.id, target: relatedNode.id, type: .related, weight: 2))
        try context.save()

        let anchoredSearch = [
            SearchResult(pageId: anchor.id, title: "Anchor", snippet: "anchor", rank: 0.8),
            SearchResult(pageId: generic.id, title: "Generic", snippet: "generic", rank: 0.7),
        ]
        let relatedResults = HTMLWorkspaceDataFeedContextSources.graphRelatedNoteResults(
            searchResults: anchoredSearch,
            modelContainer: container,
            limit: 5
        )

        #expect(relatedResults.map(\.pageID) == [related.id])
        #expect(relatedResults.first?.contextKind == "graph_related_note")
        #expect(relatedResults.first?.sourceLabel == "Graph related note")
        #expect(relatedResults.first?.provenance.contains("SDGraphNode/SDGraphEdge / related") == true)
        #expect(relatedResults.first?.provenance.contains("Anchor Note") == true)
        #expect(relatedResults.first?.snippet == "related body from graph")

        let requiredGraphResults = HTMLWorkspaceDataFeedContextSources.results(
            for: "graph_related_note",
            searchResults: [SearchResult(pageId: generic.id, title: "Generic", snippet: "generic", rank: 0.7)],
            modelContainer: container,
            limit: 5
        )
        #expect(requiredGraphResults.isEmpty)

        let defaultResults = HTMLWorkspaceDataFeedContextSources.results(
            for: nil,
            searchResults: [SearchResult(pageId: generic.id, title: "Generic", snippet: "generic", rank: 0.7)],
            modelContainer: container,
            limit: 5
        )
        #expect(defaultResults.map(\.pageID) == [generic.id])
        #expect(defaultResults.first?.contextKind == "vault_record")
    }

    @Test("data feed refreshes use explicit context source providers")
    func dataFeedRefreshesUseExplicitContextSourceProviders() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceDataFeed.swift")

        #expect(source.contains("let contextResults = HTMLWorkspaceDataFeedContextSources.results("))
        #expect(source.contains("for: requiredContextKind"))
        #expect(source.contains("contextResults: contextResults"))
    }
}
