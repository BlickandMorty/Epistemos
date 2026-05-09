import Testing
@testable import Epistemos
import CoreSpotlight
import AppIntents
import Foundation

@Suite("Indexed Entity Definitions")
struct IndexedEntityTests {

    // MARK: - ChatEntity

    @Test("ChatEntity exists with expected properties")
    func chatEntityProperties() {
        let entity = ChatEntity(
            id: "chat-1",
            title: "Test Chat",
            chatType: "chat",
            linkedPageId: "page-1",
            contentPreview: "Recent answer",
            createdAt: Date(timeIntervalSince1970: 1000),
            updatedAt: Date(timeIntervalSince1970: 2000)
        )
        #expect(entity.id == "chat-1")
        #expect(entity.title == "Test Chat")
        #expect(entity.chatType == "chat")
        #expect(entity.linkedPageId == "page-1")
        #expect(entity.contentPreview == "Recent answer")
    }

    @Test("ChatEntity conforms to IndexedEntity")
    func chatEntityIndexedEntity() {
        let entity = ChatEntity(id: "chat-1", title: "Test", contentPreview: "Answer preview")
        let set = entity.attributeSet
        #expect(set.title == "Test")
        #expect(set.contentDescription == "Answer preview")
        #expect(set.kind == "Epistemos Chat")
    }

    @Test("SDChat toChatEntity conversion exists")
    func sdChatToChatEntity() {
        let chat = SDChat(title: "My Chat", chatType: "chat")
        let entity = chat.toChatEntity(contentPreview: " Latest turn ")
        #expect(entity.title == "My Chat")
        #expect(entity.chatType == "chat")
        #expect(entity.contentPreview == "Latest turn")
    }

    @Test("ChatEntityQuery result surfaces are bounded")
    func chatEntityQueryResultSurfacesAreBounded() async {
        let query = ChatEntityQuery()
        let ids = await (try? query.entities(for: ["nonexistent"])) ?? []
        #expect(ids.isEmpty)

        let matching = await (try? query.entities(matching: "no-such-chat-\(UUID().uuidString)")) ?? IntentItemCollection(items: [])
        #expect(matching.items.count <= 20)

        let suggested = await (try? query.suggestedEntities()) ?? IntentItemCollection(items: [])
        #expect(suggested.items.count <= 10)
    }

    // MARK: - BrainDumpEntity

    @Test("BrainDumpEntity exists with expected properties")
    func brainDumpEntityProperties() {
        let entity = BrainDumpEntity(
            id: "dump-1",
            kind: "rawThought",
            body: "Some thought",
            capturedAt: Date(timeIntervalSince1970: 1000),
            anchorContextKind: "chat",
            anchorContextId: "chat-1"
        )
        #expect(entity.id == "dump-1")
        #expect(entity.kind == "rawThought")
        #expect(entity.body == "Some thought")
        #expect(entity.anchorContextKind == "chat")
        #expect(entity.anchorContextId == "chat-1")
    }

    @Test("BrainDumpEntity conforms to IndexedEntity")
    func brainDumpEntityIndexedEntity() {
        let entity = BrainDumpEntity(id: "dump-1", kind: "rawThought", body: "A thought")
        let set = entity.attributeSet
        #expect(set.title == "Brain Dump: A thought")
        #expect(set.contentDescription == "A thought")
        #expect(set.kind == "Epistemos Brain Dump")
    }

    @Test("QuarantineEntry toBrainDumpEntity conversion exists")
    func quarantineEntryToBrainDumpEntity() {
        let entry = QuarantineEntry(
            id: "dump-1",
            kind: .rawThought,
            capturedAt: 1000,
            body: "Hello world",
            anchor: QuarantineAnchor(contextKind: "note", contextId: "note-1")
        )
        let entity = entry.toBrainDumpEntity()
        #expect(entity.id == "dump-1")
        #expect(entity.kind == "rawThought")
        #expect(entity.body == "Hello world")
        #expect(entity.anchorContextKind == "note")
        #expect(entity.anchorContextId == "note-1")
    }

    @Test("BrainDumpEntityQuery suggestedEntities is bounded")
    func brainDumpEntityQuerySuggestedBounded() async {
        let query = BrainDumpEntityQuery()
        let suggested = await (try? query.suggestedEntities()) ?? IntentItemCollection(items: [])
        #expect(suggested.items.count <= 10)
    }

    @Test("BrainDumpEntityQuery matching is bounded")
    func brainDumpEntityQueryMatchingBounded() async {
        let query = BrainDumpEntityQuery()
        let matching = await (try? query.entities(matching: "test")) ?? IntentItemCollection(items: [])
        #expect(matching.items.count <= 20)
    }

    @Test("Visual Intelligence intent bridge is deferred honestly on macOS")
    func visualIntelligenceIntentBridgeIsDeferredHonestlyOnMacOS() async throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Intents/Schemas/VisualIntelligenceIntents.swift")

        #expect(source.contains("macOS deferred facade"))
        #expect(source.contains("unavailableOnMacOSMessage"))
        #expect(source.contains("EPISTEMOS_ENABLE_VISUAL_INTELLIGENCE_INTENT"))
        #expect(source.contains("#if os(iOS) && canImport(VisualIntelligence) && EPISTEMOS_ENABLE_VISUAL_INTELLIGENCE_INTENT"))
        #expect(!source.localizedCaseInsensitiveContains("stub"))
        #expect(!source.contains("macOS code paths pass `nil` and get\n    /// `nil` back."))

        #if os(macOS)
        let results = await NoteVisualSearchService.search(imageData: Data("not-an-image".utf8))
        #expect(results.isEmpty)
        #expect(NoteVisualSearchService.unavailableOnMacOSMessage.contains("unavailable on macOS"))
        #endif
    }
}
