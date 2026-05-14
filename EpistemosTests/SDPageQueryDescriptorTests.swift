import Foundation
import SwiftData
import Testing
@testable import Epistemos

@Suite("SwiftData Query Descriptors")
@MainActor
struct SDPageQueryDescriptorTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([SDPage.self, SDFolder.self, SDChat.self, SDMessage.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("activePagesDescriptor excludes archived pages and sorts by updatedAt desc")
    func activePagesDescriptorFiltersAndSorts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let old = SDPage(title: "Old")
        old.updatedAt = Date(timeIntervalSince1970: 100)
        context.insert(old)

        let newest = SDPage(title: "Newest")
        newest.updatedAt = Date(timeIntervalSince1970: 300)
        context.insert(newest)

        let archived = SDPage(title: "Archived")
        archived.updatedAt = Date(timeIntervalSince1970: 400)
        archived.isArchived = true
        context.insert(archived)

        try context.save()

        let result = try context.fetch(SDPage.activePagesDescriptor)
        #expect(result.map(\.title) == ["Newest", "Old"])
    }

    @Test("activePagesDescriptor prefetches folder relationship")
    func activePagesDescriptorPrefetchesFolder() {
        let descriptor = SDPage.activePagesDescriptor

        #expect(descriptor.relationshipKeyPathsForPrefetching.count == 1)
        #expect(descriptor.relationshipKeyPathsForPrefetching.contains(where: { $0 == \SDPage.folder }))
    }

    @Test("pinnedPagesDescriptor returns pinned non-archived pages sorted by sortOrder")
    func pinnedPagesDescriptorFiltersAndSorts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let p2 = SDPage(title: "Pinned Two")
        p2.isPinned = true
        p2.sortOrder = 2
        context.insert(p2)

        let p1 = SDPage(title: "Pinned One")
        p1.isPinned = true
        p1.sortOrder = 1
        context.insert(p1)

        let archivedPinned = SDPage(title: "Archived Pinned")
        archivedPinned.isPinned = true
        archivedPinned.isArchived = true
        archivedPinned.sortOrder = 0
        context.insert(archivedPinned)

        try context.save()

        let result = try context.fetch(SDPage.pinnedPagesDescriptor)
        #expect(result.map(\.title) == ["Pinned One", "Pinned Two"])
    }

    @Test("journalDescriptor returns only journals sorted by createdAt desc")
    func journalDescriptorFiltersAndSorts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let older = SDPage(title: "Older Journal", isJournal: true, journalDate: "2026-01-01")
        older.createdAt = Date(timeIntervalSince1970: 100)
        context.insert(older)

        let newer = SDPage(title: "Newer Journal", isJournal: true, journalDate: "2026-01-02")
        newer.createdAt = Date(timeIntervalSince1970: 200)
        context.insert(newer)

        let nonJournal = SDPage(title: "Regular Note")
        context.insert(nonJournal)

        try context.save()

        let result = try context.fetch(SDPage.journalDescriptor)
        #expect(result.map(\.title) == ["Newer Journal", "Older Journal"])
    }

    @Test("searchDescriptor matches title text and excludes templates")
    func searchDescriptorMatchesAndExcludesTemplates() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let regular = SDPage(title: "Quantum Mechanics")
        regular.updatedAt = Date(timeIntervalSince1970: 200)
        context.insert(regular)

        let template = SDPage(title: "Quantum Template")
        template.templateId = "tpl-quantum"
        template.updatedAt = Date(timeIntervalSince1970: 300)
        context.insert(template)

        let unrelated = SDPage(title: "Classical Music")
        unrelated.updatedAt = Date(timeIntervalSince1970: 100)
        context.insert(unrelated)

        let archived = SDPage(title: "Quantum Archive")
        archived.isArchived = true
        archived.updatedAt = Date(timeIntervalSince1970: 400)
        context.insert(archived)

        try context.save()

        let result = try context.fetch(SDPage.searchDescriptor(query: "quantum"))
        #expect(result.count == 1)
        #expect(result.first?.title == "Quantum Mechanics")
    }

    @Test("byStageDescriptor filters on research stage")
    func byStageDescriptorFilters() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let stage2 = SDPage(title: "Stage 2")
        stage2.researchStage = 2
        context.insert(stage2)

        let stage3 = SDPage(title: "Stage 3")
        stage3.researchStage = 3
        context.insert(stage3)

        try context.save()

        let result = try context.fetch(SDPage.byStageDescriptor(stage: 2))
        #expect(result.map(\.title) == ["Stage 2"])
    }

    @Test("recentDescriptor applies fetch limit")
    func recentDescriptorRespectsLimit() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        for i in 0..<10 {
            let page = SDPage(title: "Note \(i)")
            page.updatedAt = Date(timeIntervalSince1970: Double(i))
            context.insert(page)
        }
        try context.save()

        let result = try context.fetch(SDPage.recentDescriptor(limit: 3))
        #expect(result.count == 3)
        #expect(result.first?.title == "Note 9")
    }

    @Test("daily brief context notes exclude templates and empty bodies")
    func dailyBriefContextNotesFilterTemplatesAndEmptyBodies() {
        let full = SDPage(title: "Full")
        full.body = "Body text"

        let whitespace = SDPage(title: "Whitespace")
        whitespace.body = "   \n"

        let template = SDPage(title: "Template")
        template.templateId = "tpl-1"
        template.body = "Template body"

        let second = SDPage(title: "Second")
        second.body = "Second body"

        let notes = DailyBriefState.recentContextNotes(
            pages: [full, whitespace, template, second],
            limit: 18
        )

        #expect(notes.map(\.page.title) == ["Full", "Second"])
        #expect(notes.map(\.body) == ["Body text", "Second body"])
    }

    @Test("daily brief snippet normalizes newlines and trims whitespace")
    func dailyBriefSnippetNormalizesWhitespace() {
        let snippet = DailyBriefState.normalizedSnippet(
            from: "\nLine one\nLine two   ",
            limit: 200
        )

        #expect(snippet == "Line one Line two")
    }

    @Test("page normalized body snippet trims and replaces newlines")
    func normalizedBodySnippetTrimsWhitespace() {
        let page = SDPage(title: "Snippet")
        page.body = "\nLine one\nLine two   "

        #expect(page.normalizedBodySnippet(limit: 200) == "Line one Line two")
    }

    @Test("templatesDescriptor returns only templates sorted by title")
    func templatesDescriptorFiltersAndSorts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let b = SDPage(title: "B Template")
        b.templateId = "tpl-b"
        context.insert(b)

        let a = SDPage(title: "A Template")
        a.templateId = "tpl-a"
        context.insert(a)

        let regular = SDPage(title: "Regular")
        context.insert(regular)

        try context.save()

        let result = try context.fetch(SDPage.templatesDescriptor)
        #expect(result.map(\.title) == ["A Template", "B Template"])
    }

    @Test("topLevelFoldersDescriptor returns only root folders sorted by sortOrder")
    func topLevelFoldersDescriptorFiltersAndSorts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let rootB = SDFolder(name: "B")
        rootB.sortOrder = 2
        context.insert(rootB)

        let rootA = SDFolder(name: "A")
        rootA.sortOrder = 1
        context.insert(rootA)

        let child = SDFolder(name: "Child")
        child.parent = rootA
        context.insert(child)

        try context.save()

        let result = try context.fetch(SDFolder.topLevelFoldersDescriptor)
        #expect(result.map(\.name) == ["A", "B"])
    }

    @Test("GraphBuilder folder descriptor prefetches pages and children")
    func graphBuilderFolderDescriptorPrefetchesRelationships() {
        let descriptor = GraphBuilder.folderDescriptor()

        #expect(descriptor.relationshipKeyPathsForPrefetching.count == 2)
        #expect(descriptor.relationshipKeyPathsForPrefetching.contains(where: { $0 == \SDFolder.pages }))
        #expect(descriptor.relationshipKeyPathsForPrefetching.contains(where: { $0 == \SDFolder.children }))
    }

    @Test("recentChatsDescriptor sorts chats by updatedAt desc")
    func recentChatsDescriptorSorts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let older = SDChat(title: "Older", chatType: "chat")
        older.updatedAt = Date(timeIntervalSince1970: 100)
        context.insert(older)

        let newer = SDChat(title: "Newer", chatType: "notes")
        newer.updatedAt = Date(timeIntervalSince1970: 200)
        context.insert(newer)

        try context.save()

        let result = try context.fetch(SDChat.recentChatsDescriptor)
        #expect(result.map(\.title) == ["Newer", "Older"])
    }

    @Test("byTypeDescriptor filters chats by chatType")
    func byTypeDescriptorFilters() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let notes = SDChat(title: "Notes Chat", chatType: "notes")
        context.insert(notes)

        let general = SDChat(title: "General Chat", chatType: "chat")
        context.insert(general)

        try context.save()

        let result = try context.fetch(SDChat.byTypeDescriptor(type: "notes"))
        #expect(result.count == 1)
        #expect(result.first?.title == "Notes Chat")
    }

    @Test("frontMatter invalidates cached value when backing data changes")
    func frontMatterInvalidatesWhenBackingDataChanges() throws {
        let page = SDPage(title: "Front Matter")
        page.frontMatter = ["title": "Original"]
        #expect(page.frontMatter["title"] == "Original")

        page.frontMatterData = try JSONEncoder().encode(["title": "Updated"])

        #expect(page.frontMatter["title"] == "Updated")
    }

    @Test("ideas invalidates cached value when backing data changes")
    func ideasInvalidateWhenBackingDataChanges() throws {
        let page = SDPage(title: "Ideas")
        page.ideas = [
            NoteIdea(type: .idea, title: "First", body: "first")
        ]
        #expect(page.ideas.map(\.title) == ["First"])

        page.ideasData = try JSONEncoder().encode([
            NoteIdea(type: .brainDump, title: "Second", body: "second")
        ])

        #expect(page.ideas.map(\.title) == ["Second"])
    }

    @Test("sd chat loaded messages preserve legacy analysis metadata")
    func sdChatLoadedMessagesPreserveLegacyAnalysisMetadata() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let chat = SDChat(title: "General Chat", chatType: "chat")
        let message = SDMessage(role: "assistant", content: "Answer")

        let dual = DualMessage(
            rawAnalysis: "Raw analysis",
            uncertaintyTags: [],
            modelVsDataFlags: [],
            laymanSummary: LaymanSummary(
                whatWasTried: "Tried",
                whatIsLikelyTrue: "True",
                confidenceExplanation: "Confident",
                whatCouldChange: "More data",
                whoShouldTrust: "Experts",
                sectionLabels: nil
            ),
            reflection: nil,
            arbitration: nil
        )
        let truth = TruthAssessment(
            overallTruthLikelihood: 0.82,
            signalInterpretation: "Strong",
            weaknesses: [],
            improvements: [],
            blindSpots: [],
            confidenceCalibration: "Calibrated",
            dataVsModelBalance: "Balanced",
            recommendedActions: []
        )

        message.updateAnalysis(
            dualMessage: dual,
            truthAssessment: truth,
            confidence: 0.82,
            evidenceGrade: .b,
            mode: .api
        )
        message.chat = chat

        context.insert(chat)
        context.insert(message)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<SDChat>()).first)
        let mapped = try #require(fetched.loadedMessages.first)

        #expect(mapped.dualMessage?.laymanSummary?.whatWasTried == "Tried")
        #expect(mapped.truthAssessment?.overallTruthLikelihood == 0.82)
        #expect(mapped.evidenceGrade == .b)
        #expect(mapped.mode == .api)
    }
}

@Suite("App Intent Search Support")
struct AppIntentSearchSupportTests {
    @Test("sanitizeSnippet strips FTS highlight tags and trims surrounding whitespace")
    func sanitizeSnippetStripsHighlightMarkup() {
        #expect(AppIntentSearchSupport.sanitizeSnippet("  <b>Quantum</b> mechanics  ") == "Quantum mechanics")
        #expect(AppIntentSearchSupport.sanitizeSnippet("   ") == nil)
    }

    @Test("orderedMatches preserves rank order skips duplicates and respects availability")
    func orderedMatchesPreservesRankAndDeduplicates() {
        let results = [
            SearchResult(pageId: "page-2", title: "Two", snippet: "two", rank: 0.2),
            SearchResult(pageId: "page-1", title: "One", snippet: "<b>one</b>", rank: 0.3),
            SearchResult(pageId: "page-2", title: "Two duplicate", snippet: "ignored", rank: 0.4),
            SearchResult(pageId: "page-3", title: "Three", snippet: "three", rank: 0.5),
        ]

        let matches = AppIntentSearchSupport.orderedMatches(
            from: results,
            availablePageIds: ["page-1", "page-2"],
            limit: 5
        )

        #expect(matches == [
            IntentSearchHit(pageId: "page-2", snippet: "two"),
            IntentSearchHit(pageId: "page-1", snippet: "one"),
        ])
    }

    @Test("searchable tabs exclude deferred omega panel")
    func searchableTabsExcludeOmega() {
        #expect(AppIntentSearchSupport.searchableTabs == [.home, .notes, .settings])
    }

    @Test("retired omega tab falls back to the supported release home surface")
    func omegaTabFallsBackToHome() {
        #expect(NavTab.omega.releaseSupportedVariant == .home)
        #expect(NavTab.home.releaseSupportedVariant == .home)
        #expect(NavTab.notes.releaseSupportedVariant == .notes)
        #expect(NavTab.settings.releaseSupportedVariant == .settings)
    }

    @Test("panel identifier lookup still resolves omega for existing shortcuts")
    func panelIdentifierLookupStillResolvesOmega() async throws {
        let panels = try await PanelEntityQuery().entities(for: ["omega"])
        #expect(panels.map(\.id) == ["omega"])
    }

    @Test("note entity preview override uses the provided preview")
    func noteEntityUsesPreviewOverride() {
        let page = SDPage(title: "Quantum")
        page.body = "Full note body"

        let entity = page.toNoteEntity(contentPreview: "Matched preview")
        #expect(entity.content == "Matched preview")
    }

    @Test("journal entity preview override uses the provided snippet")
    func journalEntityUsesPreviewOverride() {
        let page = SDPage(title: "Journal")
        page.body = "Full journal body"

        let entity = page.toJournalEntity(markdownPreview: "Matched preview")
        #expect(entity.message == AttributedString("Matched preview"))
    }
}

@Suite("Extraction and Message Regressions")
struct ExtractionAndMessageRegressionTests {
    @Test("note extraction tolerates missing sources payload")
    func extractionResultDecodesWithoutSources() throws {
        let data = Data(#"{"tags":[{"name":"Quantum","description":null}]}"#.utf8)
        let decoded = try JSONDecoder().decode(ExtractionResult.self, from: data)

        #expect(decoded.sources == nil)
        #expect(decoded.tags?.map(\.name) == ["Quantum"])
    }

    @Test("chat insight extraction tolerates missing shared sources payload")
    func insightExtractionDecodesWithoutSharedSources() throws {
        let data = Data(#"{"ideas":[{"summary":"Key idea","evidenceGrade":"B","relatedEntities":["Bayes"]}]}"#.utf8)
        let decoded = try JSONDecoder().decode(InsightExtractionResult.self, from: data)

        #expect(decoded.sourcesShared == nil)
        #expect(decoded.ideas.map(\.summary) == ["Key idea"])
    }

    @Test("SDMessage chat mapping preserves error and vault briefing flags")
    @MainActor func sdMessagePreservesFlags() {
        let message = SDMessage(role: "assistant", content: "Hello")
        message.isError = true
        message.isVaultBriefing = true

        let mapped = message.chatMessage(chatId: "chat-1")
        #expect(mapped.isError)
        #expect(mapped.isVaultBriefing)
    }
}
