import Foundation
import Testing
@testable import Epistemos

@Suite("NoteFileStorage")
struct NoteFileStorageTests {
    private func makePageId() -> String {
        "test-note-\(UUID().uuidString)"
    }

    @Test("storage directory exists and points to note-bodies")
    func storageDirectoryExists() {
        let dir = NoteFileStorage.storageDirectory()
        #expect(dir.lastPathComponent == "note-bodies")
        #expect(FileManager.default.fileExists(atPath: dir.path))
    }

    @Test("valid page IDs are accepted")
    func validPageIdsAccepted() {
        #expect(NoteFileStorage.isValidPageId("abc-123"))
        #expect(NoteFileStorage.isValidPageId(UUID().uuidString))
        #expect(NoteFileStorage.isValidPageId(String(repeating: "a", count: 256)))
    }

    @Test("invalid page IDs are rejected")
    func invalidPageIdsRejected() {
        let invalid = [
            "",
            "../secret",
            "folder/name",
            "folder\\name",
            "contains..dots",
            "null\0byte",
            String(repeating: "b", count: 257),
        ]
        for id in invalid {
            #expect(!NoteFileStorage.isValidPageId(id), "Expected invalid pageId: \(id)")
        }
    }

    @Test("write/read round trip preserves content")
    func writeReadRoundTrip() {
        let pageId = makePageId()
        defer { NoteFileStorage.deleteBody(pageId: pageId) }

        let content = """
        # Quantum Notes
        Line 1
        Line 2 with symbols !@# and emoji 🚀
        """

        NoteFileStorage.writeBody(pageId: pageId, content: content)

        #expect(NoteFileStorage.bodyExists(pageId: pageId))
        #expect(NoteFileStorage.readBody(pageId: pageId) == content)
    }

    @Test("mapped and non-mapped reads return same value")
    func mappedAndNormalReadsMatch() {
        let pageId = makePageId()
        defer { NoteFileStorage.deleteBody(pageId: pageId) }

        let content = "mapped-read-check \(UUID().uuidString)"
        NoteFileStorage.writeBody(pageId: pageId, content: content)

        let normal = NoteFileStorage.readBody(pageId: pageId, mapped: false)
        let mapped = NoteFileStorage.readBody(pageId: pageId, mapped: true)

        #expect(normal == mapped)
        #expect(mapped == content)
    }

    @Test("readBody returns empty string for missing file")
    func missingFileReadReturnsEmpty() {
        let pageId = makePageId()
        NoteFileStorage.deleteBody(pageId: pageId)
        #expect(NoteFileStorage.readBody(pageId: pageId).isEmpty)
    }

    @Test("readBodyData returns data for existing file and nil for missing")
    func readBodyDataBehavior() {
        let pageId = makePageId()
        defer { NoteFileStorage.deleteBody(pageId: pageId) }

        let content = "raw-bytes-content"
        NoteFileStorage.writeBody(pageId: pageId, content: content)

        let data = NoteFileStorage.readBodyData(pageId: pageId)
        #expect(data != nil)
        #expect(data == Data(content.utf8))

        let missing = NoteFileStorage.readBodyData(pageId: makePageId())
        #expect(missing == nil)
    }

    @Test("deleteBody removes file and clears existence check")
    func deleteBodyRemovesFile() {
        let pageId = makePageId()

        NoteFileStorage.writeBody(pageId: pageId, content: "temp")
        #expect(NoteFileStorage.bodyExists(pageId: pageId))

        NoteFileStorage.deleteBody(pageId: pageId)
        #expect(!NoteFileStorage.bodyExists(pageId: pageId))
        #expect(NoteFileStorage.readBody(pageId: pageId).isEmpty)
    }

    @Test("invalid page IDs do not create files")
    func invalidWriteDoesNotCreateFile() {
        let invalidId = "../bad"
        NoteFileStorage.writeBody(pageId: invalidId, content: "should-not-write")
        #expect(!NoteFileStorage.bodyExists(pageId: invalidId))
        #expect(NoteFileStorage.readBody(pageId: invalidId).isEmpty)
    }
}

