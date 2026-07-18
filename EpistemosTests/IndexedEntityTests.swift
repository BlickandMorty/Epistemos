import Testing
@testable import Epistemos
import Foundation

@Suite("Retired AppEntity removal and retained data models")
struct IndexedEntityTests {

    @Test("paid Chat and BrainDump AppEntity surfaces are physically absent")
    func paidAppEntitySurfacesAreRemoved() throws {
        for retiredEntitySource in [
            "Epistemos/Intents/Entities/BrainDumpEntity.swift",
            "Epistemos/Intents/Entities/ChatEntity.swift",
        ] {
            let sourceURL = try sourceMirrorURL(for: retiredEntitySource)
            #expect(
                !FileManager.default.fileExists(atPath: sourceURL.path),
                "Free V1 must physically remove \(retiredEntitySource)."
            )
        }
    }

    @Test("historical chat and quarantine data remain independent of retired AppEntity bridges")
    func historicalDataModelsRemainAvailable() {
        let chat = SDChat(title: "My Chat", chatType: "chat")
        let entry = QuarantineEntry(
            id: "dump-1",
            kind: .rawThought,
            capturedAt: 1000,
            body: "Hello world",
            anchor: QuarantineAnchor(contextKind: "note", contextId: "note-1")
        )

        #expect(chat.title == "My Chat")
        #expect(chat.chatType == "chat")
        #expect(entry.id == "dump-1")
        #expect(entry.kind == .rawThought)
        #expect(entry.body == "Hello world")
        #expect(entry.anchor?.contextKind == "note")
        #expect(entry.anchor?.contextId == "note-1")
    }

    @Test("Free V1 physically removes the deferred Visual Intelligence intent bridge")
    func freeV1RemovesVisualIntelligenceIntentBridge() throws {
        let sourceURL = try sourceMirrorURL(for: "Epistemos/Intents/Schemas/VisualIntelligenceIntents.swift")

        #expect(
            !FileManager.default.fileExists(atPath: sourceURL.path),
            "Free V1 must not restore the Visual Intelligence intent bridge."
        )
    }
}
