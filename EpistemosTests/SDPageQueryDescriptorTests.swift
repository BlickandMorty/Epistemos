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

        let research = SDChat(title: "Research Chat", chatType: "research")
        context.insert(research)

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

    @Test("chat message mapping preserves research timing and reasoning metadata")
    func chatMessageMappingPreservesResearchMetadata() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let chat = SDChat(title: "Research", chatType: "research")
        let message = SDMessage(role: "assistant", content: "Answer")
        let start = Date(timeIntervalSince1970: 1_234)

        message.reasoningText = "Thinking..."
        message.reasoningDuration = 2.5
        message.isResearchResult = true
        message.researchStartTime = start
        message.researchDuration = 42
        message.chat = chat

        context.insert(chat)
        context.insert(message)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<SDMessage>()).first)
        let mapped = fetched.chatMessage(chatId: chat.id)

        #expect(mapped.reasoningText == "Thinking...")
        #expect(mapped.reasoningDuration == 2.5)
        #expect(mapped.isResearchResult)
        #expect(mapped.researchStartTime == start)
        #expect(mapped.researchDuration == 42)
    }

    @Test("chat message mapping preserves an in-flight research timer before enrichment completes")
    func chatMessageMappingPreservesRunningResearchTimer() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let chat = SDChat(title: "Research", chatType: "research")
        let message = SDMessage(role: "assistant", content: "Streaming answer")
        let start = Date(timeIntervalSince1970: 5_678)

        message.isResearchResult = true
        message.researchStartTime = start
        message.researchDuration = nil
        message.chat = chat

        context.insert(chat)
        context.insert(message)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<SDMessage>()).first)
        let mapped = fetched.chatMessage(chatId: chat.id)

        #expect(mapped.isResearchResult)
        #expect(mapped.researchStartTime == start)
        #expect(mapped.researchDuration == nil)
    }
}
