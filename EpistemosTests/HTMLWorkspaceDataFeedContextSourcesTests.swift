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

    @MainActor
    @Test("recent chat context source uses real persisted chat messages")
    func recentChatContextSourceUsesRealPersistedChatMessages() throws {
        let schema = Schema([SDPage.self, SDGraphNode.self, SDGraphEdge.self, SDBlock.self, SDChat.self, SDMessage.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let chat = SDChat(title: "Project Alpha Chat", chatType: "notes")
        chat.updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let userMessage = SDMessage(role: "user", content: "What changed in alpha?")
        let assistantMessage = SDMessage(role: "assistant", content: "Alpha decision recap from the real chat.")
        userMessage.chat = chat
        assistantMessage.chat = chat
        context.insert(chat)
        context.insert(userMessage)
        context.insert(assistantMessage)
        try context.save()

        let directResults = HTMLWorkspaceDataFeedContextSources.recentChatResults(
            query: "chat: alpha",
            modelContainer: container,
            limit: 5
        )
        #expect(directResults.map(\.pageID) == [chat.id])
        #expect(directResults.first?.contextKind == "recent_chat")
        #expect(directResults.first?.sourceLabel == "Recent chat")
        #expect(directResults.first?.snippet == "Alpha decision recap from the real chat.")
        #expect(directResults.first?.provenance.contains("SDChat / notes") == true)

        let genericResult = SearchResult(pageId: "note-a", title: "Generic", snippet: "generic", rank: 0.7)
        let triggeredResults = HTMLWorkspaceDataFeedContextSources.results(
            for: nil,
            searchResults: [genericResult],
            modelContainer: container,
            limit: 5,
            query: "recent chats alpha"
        )
        #expect(triggeredResults.map(\.pageID) == [chat.id])
        #expect(triggeredResults.first?.contextKind == "recent_chat")

        let explicitGraphResults = HTMLWorkspaceDataFeedContextSources.results(
            for: "graph_related_note",
            searchResults: [genericResult],
            modelContainer: container,
            limit: 5,
            query: "recent chats alpha"
        )
        #expect(explicitGraphResults.isEmpty)
    }

    @MainActor
    @Test("folder note context source emits real notes from matched folders")
    func folderNoteContextSourceEmitsRealNotesFromMatchedFolders() throws {
        let schema = Schema([SDPage.self, SDFolder.self, SDGraphNode.self, SDGraphEdge.self, SDBlock.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let research = SDFolder(name: "Research")
        let physics = SDFolder(name: "Physics")
        physics.parent = research
        research.children = [physics]
        let folderNote = SDPage(title: "Quantum Folder Note")
        folderNote.body = "real folder note body"
        folderNote.folder = physics
        folderNote.subfolder = "Research/Physics"
        let unrelated = SDPage(title: "Loose Note")
        unrelated.body = "not in folder"
        context.insert(research)
        context.insert(physics)
        context.insert(folderNote)
        context.insert(unrelated)
        try context.save()

        let folderResults = HTMLWorkspaceDataFeedContextSources.folderNoteResults(
            query: "folder: physics",
            modelContainer: container,
            limit: 5
        )
        #expect(folderResults.map(\.pageID) == [folderNote.id])
        #expect(folderResults.first?.contextKind == "folder_note")
        #expect(folderResults.first?.sourceLabel == "Folder: Research/Physics")
        #expect(folderResults.first?.provenance.contains("SDFolder/SDPage / folder:Research/Physics") == true)
        #expect(folderResults.first?.snippet == "real folder note body")

        let genericResult = SearchResult(pageId: unrelated.id, title: "Loose", snippet: "loose", rank: 0.7)
        let triggeredResults = HTMLWorkspaceDataFeedContextSources.results(
            for: nil,
            searchResults: [genericResult],
            modelContainer: container,
            limit: 5,
            query: "folder physics"
        )
        #expect(triggeredResults.map(\.pageID) == [folderNote.id])
        #expect(triggeredResults.first?.contextKind == "folder_note")

        let explicitGraphResults = HTMLWorkspaceDataFeedContextSources.results(
            for: "graph_related_note",
            searchResults: [genericResult],
            modelContainer: container,
            limit: 5,
            query: "folder physics"
        )
        #expect(explicitGraphResults.isEmpty)
    }

    @MainActor
    @Test("meeting note context source emits real saved meeting transcripts")
    func meetingNoteContextSourceEmitsRealSavedMeetingTranscripts() throws {
        let schema = Schema([SDPage.self, SDBlock.self, SDChat.self, SDMessage.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let meeting = SDPage(title: "Launch Review Meeting")
        meeting.body = "Launch review transcript with beta rollout decisions."
        meeting.frontMatter = [
            "source": "meeting_stt",
            "source_kind": "audio_transcript",
            "captured_at": "2026-07-01T12:00:00Z",
            "duration_seconds": "61",
            "stt_engine": "apple_speechanalyzer",
        ]
        let genericCapture = SDPage(title: "Web capture")
        genericCapture.body = "captured article"
        genericCapture.frontMatter = ["captured_at": "2026-07-01T13:00:00Z"]
        context.insert(meeting)
        context.insert(genericCapture)
        try context.save()

        let meetingResults = HTMLWorkspaceDataFeedContextSources.meetingNoteResults(
            query: "meeting: launch",
            modelContainer: container,
            limit: 5
        )
        #expect(meetingResults.map(\.pageID) == [meeting.id])
        #expect(meetingResults.first?.contextKind == "meeting_note")
        #expect(meetingResults.first?.sourceLabel == "Meeting note")
        #expect(meetingResults.first?.snippet == "Launch review transcript with beta rollout decisions.")
        #expect(meetingResults.first?.provenance.contains("TextCapturePipeline / meeting_stt / audio_transcript") == true)
        #expect(meetingResults.first?.provenance.contains("duration_seconds:61") == true)

        let genericResult = SearchResult(pageId: genericCapture.id, title: "Generic", snippet: "generic", rank: 0.7)
        let triggeredResults = HTMLWorkspaceDataFeedContextSources.results(
            for: nil,
            searchResults: [genericResult],
            modelContainer: container,
            limit: 5,
            query: "meeting notes launch"
        )
        #expect(triggeredResults.map(\.pageID) == [meeting.id])
        #expect(triggeredResults.first?.contextKind == "meeting_note")

        let explicitChatResults = HTMLWorkspaceDataFeedContextSources.results(
            for: "recent_chat",
            searchResults: [genericResult],
            modelContainer: container,
            limit: 5,
            query: "meeting notes launch"
        )
        #expect(explicitChatResults.isEmpty)
    }

    @Test("data feed refreshes use explicit context source providers")
    func dataFeedRefreshesUseExplicitContextSourceProviders() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceDataFeed.swift")

        #expect(source.contains("let contextResults = HTMLWorkspaceDataFeedContextSources.results("))
        #expect(source.contains("for: requiredContextKind"))
        #expect(source.contains("query: feed.normalizedQuery"))
        #expect(source.contains("contextResults: contextResults"))
    }

    @Test("freeform regenerate context refresh uses explicit context providers")
    func freeformRegenerateContextRefreshUsesExplicitContextProviders() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")

        #expect(source.contains("let contextResults = HTMLWorkspaceDataFeedContextSources.results("))
        #expect(source.contains("for: nil"))
        #expect(source.contains("query: feed.normalizedQuery"))
        #expect(source.contains("HTMLWorkspaceDataFeedRenderer.render(feed: feed, contextResults: contextResults)"))
    }
}
