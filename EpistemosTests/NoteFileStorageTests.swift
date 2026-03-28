import AppKit
import Foundation
import Testing
@testable import Epistemos

@Suite("NoteFileStorage")
struct NoteFileStorageTests {
    private final class EventSink: @unchecked Sendable {
        private let lock = NSLock()
        private let continuation: AsyncStream<String>.Continuation

        nonisolated init(continuation: AsyncStream<String>.Continuation) {
            self.continuation = continuation
        }

        nonisolated func yield(_ value: String) {
            lock.lock()
            continuation.yield(value)
            lock.unlock()
        }

        nonisolated func finish() {
            lock.lock()
            continuation.finish()
            lock.unlock()
        }
    }

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

    @Test("readBody decodes UTF-16 note bodies without showing gibberish")
    func readBodyDecodesUtf16Bodies() throws {
        let pageId = makePageId()
        let bodyURL = NoteFileStorage.storageDirectory().appendingPathComponent("\(pageId).md")
        let content = "Kimi note line 1\nUnicode café 🚀"
        defer { NoteFileStorage.deleteBody(pageId: pageId) }

        guard let data = content.data(using: .utf16) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try data.write(to: bodyURL, options: .atomic)

        #expect(NoteFileStorage.readBody(pageId: pageId, mapped: false) == content)
        #expect(NoteFileStorage.readBody(pageId: pageId, mapped: true) == content)
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

    @Test("orphan cleanup removes only body files for missing pages")
    func orphanCleanupRemovesOnlyMissingPages() throws {
        let keepId = makePageId()
        let orphanId = makePageId()
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "note-storage-tests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let keepURL = tempDirectory.appendingPathComponent("\(keepId).md")
        let orphanURL = tempDirectory.appendingPathComponent("\(orphanId).md")
        let nonMarkdownURL = tempDirectory.appendingPathComponent(
            "note-storage-ignore-\(UUID().uuidString).txt"
        )
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        try "keep".write(to: keepURL, atomically: true, encoding: .utf8)
        try "orphan".write(to: orphanURL, atomically: true, encoding: .utf8)
        try "ignore".write(to: nonMarkdownURL, atomically: true, encoding: .utf8)

        let removed = NoteFileStorage.cleanupOrphanBodies(in: tempDirectory, validPageIds: [keepId])

        #expect(removed == [orphanId])
        #expect(FileManager.default.fileExists(atPath: keepURL.path))
        #expect(!FileManager.default.fileExists(atPath: orphanURL.path))
        #expect(FileManager.default.fileExists(atPath: nonMarkdownURL.path))
    }

    @Test("readBody migrates legacy rtfd bundle to markdown")
    func readBodyMigratesLegacyRTFD() throws {
        let pageId = makePageId()
        let bodyURL = NoteFileStorage.storageDirectory().appendingPathComponent("\(pageId).md")
        let richTextURL = NoteFileStorage.storageDirectory().appendingPathComponent("\(pageId).rtfd")
        defer {
            NoteFileStorage.deleteBody(pageId: pageId)
            try? FileManager.default.removeItem(at: richTextURL)
        }

        let legacyContent = NSAttributedString(string: "Legacy rich text\n\nEmoji 🚀")
        let wrapper = try legacyContent.fileWrapper(
            from: NSRange(location: 0, length: legacyContent.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
        )
        try wrapper.write(to: richTextURL, options: .atomic, originalContentsURL: nil)

        #expect(!NoteFileStorage.bodyExists(pageId: pageId))
        #expect(FileManager.default.fileExists(atPath: richTextURL.path))

        let migrated = NoteFileStorage.readBody(pageId: pageId)

        #expect(migrated == legacyContent.string)
        #expect(NoteFileStorage.bodyExists(pageId: pageId))
        #expect(!FileManager.default.fileExists(atPath: richTextURL.path))
        #expect(try String(contentsOf: bodyURL, encoding: .utf8) == legacyContent.string)
    }

    @Test("invalid page IDs do not create files")
    func invalidWriteDoesNotCreateFile() {
        let invalidId = "../bad"
        NoteFileStorage.writeBody(pageId: invalidId, content: "should-not-write")
        #expect(!NoteFileStorage.bodyExists(pageId: invalidId))
        #expect(NoteFileStorage.readBody(pageId: invalidId).isEmpty)
    }

    @Test("mutation queue serializes async writes")
    func mutationQueueSerializesAsyncWrites() async {
        let queue = NoteFileMutationQueue(label: "test.note-storage.async.\(UUID().uuidString)")
        let releaseFirst = DispatchSemaphore(value: 0)
        var continuation: AsyncStream<String>.Continuation!
        let stream = AsyncStream<String> { continuation = $0 }
        var iterator = stream.makeAsyncIterator()
        let sink = EventSink(continuation: continuation)

        let first = Task {
            await queue.performAsync {
                sink.yield("first-start")
                releaseFirst.wait()
                sink.yield("first-end")
            }
        }

        #expect(await iterator.next() == "first-start")

        let second = Task {
            await queue.performAsync {
                sink.yield("second")
            }
        }

        releaseFirst.signal()
        await first.value
        await second.value
        sink.finish()

        #expect(await iterator.next() == "first-end")
        #expect(await iterator.next() == "second")
    }

    @Test("mutation queue serializes sync flush behind async write")
    func mutationQueueSerializesSyncAfterAsync() async {
        let queue = NoteFileMutationQueue(label: "test.note-storage.sync.\(UUID().uuidString)")
        let releaseFirst = DispatchSemaphore(value: 0)
        var continuation: AsyncStream<String>.Continuation!
        let stream = AsyncStream<String> { continuation = $0 }
        var iterator = stream.makeAsyncIterator()
        let sink = EventSink(continuation: continuation)

        let first = Task {
            await queue.performAsync {
                sink.yield("first-start")
                releaseFirst.wait()
                sink.yield("first-end")
            }
        }

        #expect(await iterator.next() == "first-start")

        let second = Task {
            queue.performSync {
                sink.yield("sync")
            }
        }

        releaseFirst.signal()
        await first.value
        await second.value
        sink.finish()

        #expect(await iterator.next() == "first-end")
        #expect(await iterator.next() == "sync")
    }
}
