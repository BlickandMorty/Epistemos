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

        let triggeredGraphResults = HTMLWorkspaceDataFeedContextSources.results(
            for: nil,
            searchResults: anchoredSearch,
            modelContainer: container,
            limit: 5,
            query: "graph related anchor"
        )
        #expect(triggeredGraphResults.map(\.pageID) == [related.id])
        #expect(triggeredGraphResults.first?.contextKind == "graph_related_note")

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
    @Test("free V1 HTML workspace hides persisted chat context")
    func recentChatContextSourceIsHiddenInFreeV1() throws {
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
        #expect(directResults.isEmpty)

        let genericResult = SearchResult(pageId: "note-a", title: "Generic", snippet: "generic", rank: 0.7)
        let triggeredResults = HTMLWorkspaceDataFeedContextSources.results(
            for: nil,
            searchResults: [genericResult],
            modelContainer: container,
            limit: 5,
            query: "recent chats alpha"
        )
        #expect(triggeredResults.isEmpty)

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

    @MainActor
    @Test("note context source upgrades vault search hits into source-labelled notes")
    func noteContextSourceUpgradesVaultSearchHitsIntoSourceLabelledNotes() throws {
        let schema = Schema([SDPage.self, SDBlock.self, SDChat.self, SDMessage.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let note = SDPage(title: "Alpha Note")
        note.summary = "short alpha summary"
        note.body = "long alpha note body"
        context.insert(note)
        try context.save()

        let searchResults = [
            SearchResult(pageId: note.id, title: "Search Alpha", snippet: "search snippet", rank: 0.9),
            SearchResult(pageId: "search-only-note", title: "Search Only", snippet: "search-only snippet", rank: 0.8),
        ]
        let noteResults = HTMLWorkspaceDataFeedContextSources.noteResults(
            query: "note: alpha",
            searchResults: searchResults,
            modelContainer: container,
            limit: 5
        )
        #expect(noteResults.map(\.pageID) == [note.id, "search-only-note"])
        #expect(noteResults.first?.title == "Alpha Note")
        #expect(noteResults.first?.snippet == "short alpha summary")
        #expect(noteResults.first?.contextKind == "note")
        #expect(noteResults.first?.sourceLabel == "Note")
        #expect(noteResults.first?.provenance.contains("SDPage / query:note: alpha") == true)
        #expect(noteResults.last?.snippet == "search-only snippet")

        let triggeredResults = HTMLWorkspaceDataFeedContextSources.results(
            for: nil,
            searchResults: searchResults,
            modelContainer: container,
            limit: 5,
            query: "notes alpha"
        )
        #expect(triggeredResults.first?.contextKind == "note")

        let explicitChatResults = HTMLWorkspaceDataFeedContextSources.results(
            for: "recent_chat",
            searchResults: searchResults,
            modelContainer: container,
            limit: 5,
            query: "notes alpha"
        )
        #expect(explicitChatResults.isEmpty)
    }

    @MainActor
    @Test("web clip context source emits real clipped web notes")
    func webClipContextSourceEmitsRealClippedWebNotes() throws {
        let schema = Schema([SDPage.self, SDBlock.self, SDChat.self, SDMessage.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let clip = SDPage(title: "Example Article")
        clip.body = "Readable clipped web article body."
        clip.frontMatter = [
            "source": "web",
            "source_kind": "web_clip",
            "source_title": "Example Article",
            "source-url": "https://example.com/articles/a#section",
            "captured_at": "2026-07-01T14:00:00Z",
        ]
        let meeting = SDPage(title: "Meeting")
        meeting.body = "meeting transcript"
        meeting.frontMatter = [
            "source": "meeting_stt",
            "source_kind": "audio_transcript",
        ]
        context.insert(clip)
        context.insert(meeting)
        try context.save()

        let clipResults = HTMLWorkspaceDataFeedContextSources.webClipResults(
            query: "web clip example",
            modelContainer: container,
            limit: 5
        )
        #expect(clipResults.map(\.pageID) == [clip.id])
        #expect(clipResults.first?.contextKind == "web_clip")
        #expect(clipResults.first?.sourceLabel == "Web clip: example.com")
        #expect(clipResults.first?.snippet == "Readable clipped web article body.")
        #expect(clipResults.first?.provenance.contains("WebClipperMarkdownBuilder / web / web_clip") == true)
        #expect(clipResults.first?.provenance.contains("url:https://example.com/articles/a#section") == true)

        let genericResult = SearchResult(pageId: meeting.id, title: "Generic", snippet: "generic", rank: 0.7)
        let triggeredResults = HTMLWorkspaceDataFeedContextSources.results(
            for: nil,
            searchResults: [genericResult],
            modelContainer: container,
            limit: 5,
            query: "clips example"
        )
        #expect(triggeredResults.map(\.pageID) == [clip.id])
        #expect(triggeredResults.first?.contextKind == "web_clip")

        let explicitChatResults = HTMLWorkspaceDataFeedContextSources.results(
            for: "recent_chat",
            searchResults: [genericResult],
            modelContainer: container,
            limit: 5,
            query: "clips example"
        )
        #expect(explicitChatResults.isEmpty)
    }

    @MainActor
    @Test("PDF note context source emits real imported PDF and arXiv notes")
    func pdfNoteContextSourceEmitsRealImportedPDFAndArxivNotes() throws {
        let schema = Schema([SDPage.self, SDBlock.self, SDChat.self, SDMessage.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)

        let arxiv = SDPage(title: "Attention Paper")
        arxiv.body = "Transformer abstract and parsed full text."
        arxiv.frontMatter = [
            "source": "arxiv",
            "source_kind": "pdf",
            "source_pdf": "arXiv/2401.12345.pdf",
            "arxiv_id": "2401.12345",
            "authors": "A. Researcher",
            "categories": "cs.CL",
        ]
        let imported = SDPage(title: "Manual PDF")
        imported.body = "Converted manual PDF body."
        imported.frontMatter = [
            "source_kind": "pdf",
            "source_pdf": "Imported/Manual.pdf",
        ]
        let generic = SDPage(title: "Loose")
        generic.body = "not a pdf"
        context.insert(arxiv)
        context.insert(imported)
        context.insert(generic)
        try context.save()

        let arxivResults = HTMLWorkspaceDataFeedContextSources.pdfNoteResults(
            query: "arxiv: 2401.12345",
            modelContainer: container,
            limit: 5
        )
        #expect(arxivResults.map(\.pageID) == [arxiv.id])
        #expect(arxivResults.first?.contextKind == "pdf_note")
        #expect(arxivResults.first?.sourceLabel == "arXiv paper: 2401.12345")
        #expect(arxivResults.first?.provenance.contains("ArxivIngestService / arxiv / pdf") == true)
        #expect(arxivResults.first?.provenance.contains("source_pdf:arXiv/2401.12345.pdf") == true)

        let pdfResults = HTMLWorkspaceDataFeedContextSources.pdfNoteResults(
            query: "pdf manual",
            modelContainer: container,
            limit: 5
        )
        #expect(pdfResults.map(\.pageID) == [imported.id])
        #expect(pdfResults.first?.sourceLabel == "Imported PDF")
        #expect(pdfResults.first?.provenance.contains("LiteParsePDFImportController / pdf") == true)

        let genericResult = SearchResult(pageId: generic.id, title: "Generic", snippet: "generic", rank: 0.7)
        let triggeredResults = HTMLWorkspaceDataFeedContextSources.results(
            for: nil,
            searchResults: [genericResult],
            modelContainer: container,
            limit: 5,
            query: "papers transformer"
        )
        #expect(triggeredResults.map(\.pageID) == [arxiv.id])
        #expect(triggeredResults.first?.contextKind == "pdf_note")
    }

    @MainActor
    @Test("provenance claim context source emits real persisted answer packet claims")
    func provenanceClaimContextSourceEmitsRealPersistedAnswerPacketClaims() throws {
        let verifiedClaim = Claim(
            id: "claim-active",
            text: "Tool execution completed with a bounded success witness.",
            status: .active,
            createdAtMs: 1_800_000_001,
            kind: .empirical,
            acsAnchor: AcsAnchor(
                anchorId: "anchor-claim-active",
                theoremId: "E1",
                plane: .controller,
                residency: .verifiedFloor,
                activePacketId: "packet-verified",
                salience: 0.9
            )
        )
        let inactiveClaim = Claim(
            id: "claim-retracted",
            text: "Retracted claim should not enter regenerate context.",
            status: .retracted,
            createdAtMs: 1_800_000_000,
            kind: .speculative
        )
        let packet = AnswerPacket(
            id: "packet-verified",
            claims: [inactiveClaim, verifiedClaim],
            uiLabel: .verified,
            attentionMode: .dynamic,
            interruptBucket: .high,
            witnessedStateRef: "stop:end_turn",
            mutationEnvelopeRef: "mutation-packet-verified"
        )
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("html-workspace-claims-\(UUID().uuidString).jsonl")
        let store = AnswerPacketStore(fileURL: storeURL)
        defer { try? FileManager.default.removeItem(at: storeURL) }
        try store.append(packet)

        let claimResults = HTMLWorkspaceDataFeedContextSources.provenanceClaimResults(
            query: "claims tool execution",
            limit: 5,
            store: store
        )
        #expect(claimResults.map(\.pageID) == ["answer-packet:packet-verified:claim:claim-active"])
        #expect(claimResults.first?.contextKind == "provenance_claim")
        #expect(claimResults.first?.title == "Empirical claim")
        #expect(claimResults.first?.sourceLabel == "Provenance claim: Verified")
        #expect(claimResults.first?.snippet == "Tool execution completed with a bounded success witness.")
        #expect(claimResults.first?.provenance.contains("AnswerPacketStore / packet:packet-verified") == true)
        #expect(claimResults.first?.provenance.contains("claim:claim-active") == true)
        #expect(claimResults.first?.provenance.contains("acs:anchor-claim-active:E1") == true)

        let triggeredResults = HTMLWorkspaceDataFeedContextSources.results(
            for: nil,
            searchResults: [SearchResult(pageId: "note-a", title: "Generic", snippet: "generic", rank: 0.7)],
            modelContainer: nil,
            limit: 5,
            query: "provenance claims"
        )
        #expect(triggeredResults.isEmpty)
        #expect(HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: "claims tool execution") == "provenance_claim")
    }

    @MainActor
    @Test("freeform query source classifier mirrors explicit context providers")
    func freeformQuerySourceClassifierMirrorsExplicitContextProviders() {
        #expect(HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: "captures alpha") == "recent_capture")
        #expect(HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: "note: alpha") == "note")
        #expect(HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: "pdf manual") == "pdf_note")
        #expect(HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: "folder: physics") == "folder_note")
        #expect(HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: "meeting notes launch") == "meeting_note")
        #expect(HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: "web clip example") == "web_clip")
        #expect(HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: "recent chats alpha") == nil)
        #expect(HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: "provenance claims") == "provenance_claim")
        #expect(HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: "graph related anchor") == "graph_related_note")
        #expect(HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: "plain substrate search") == nil)
    }

    @MainActor
    @Test("standalone context source classifier separates local reads from vault search reads")
    func standaloneContextSourceClassifierSeparatesLocalReadsFromVaultSearchReads() {
        for kind in ["recent_capture", "note", "pdf_note", "folder_note", "meeting_note", "web_clip", "provenance_claim"] {
            #expect(HTMLWorkspaceDataFeedContextSources.usesStandaloneContextSource(kind))
        }
        #expect(!HTMLWorkspaceDataFeedContextSources.usesStandaloneContextSource("recent_chat"))
        #expect(!HTMLWorkspaceDataFeedContextSources.usesStandaloneContextSource("graph_related_note"))
        #expect(!HTMLWorkspaceDataFeedContextSources.usesStandaloneContextSource(nil))
    }

    @Test("data feed refreshes use explicit context source providers")
    func dataFeedRefreshesUseExplicitContextSourceProviders() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceDataFeed.swift")

        #expect(source.contains("let contextResults = HTMLWorkspaceDataFeedContextSources.results("))
        #expect(source.contains("for: requiredContextKind"))
        #expect(source.contains("HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: feed.normalizedQuery)"))
        #expect(source.contains("HTMLWorkspaceDataFeedContextSources.usesStandaloneContextSource(requiredContextKind)"))
        #expect(source.contains("scheduleStandaloneRefresh(feed: feed, requiredContextKind: requiredContextKind, reason: reason)"))
        #expect(source.contains("query: feed.normalizedQuery"))
        #expect(source.contains("contextResults: contextResults"))
        #expect(source.contains("private func stampPackageContentRevision()"))
        #expect(source.contains("package.manifest.contentHash = package.currentContentHash"))
        #expect(source.contains("stampPackageContentRevision()"))
    }

    @Test("freeform regenerate context refresh uses explicit context providers")
    func freeformRegenerateContextRefreshUsesExplicitContextProviders() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")

        #expect(source.contains("let contextResults = HTMLWorkspaceDataFeedContextSources.results("))
        #expect(source.contains("for: requiredContextKind"))
        #expect(source.contains("let requiredContextKind = HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: feed.normalizedQuery)"))
        #expect(source.contains("HTMLWorkspaceDataFeedContextSources.usesStandaloneContextSource(requiredContextKind)"))
        #expect(source.contains("requiredContextKind: preset.requiredContextKind"))
        #expect(source.contains("attachStandaloneRegenerateContext(feed: feed, requiredContextKind: requiredContextKind)"))
        #expect(source.contains("query: feed.normalizedQuery"))
        #expect(source.contains("requiredContextKind: requiredContextKind"))
    }
}
