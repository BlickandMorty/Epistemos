import Foundation
import Testing
@testable import Epistemos

/// R-OKF — locks the bundle mapping + write: type derivation, deterministic
/// dates, collision-safe filenames, and a real on-disk round-trip.
@Suite("OKF bundle writer")
struct OKFBundleWriterTests {

    @Test("note() derives type from isJournal and formats dates as UTC ISO-8601")
    func mapperDerivesTypeAndDates() {
        let epoch = Date(timeIntervalSince1970: 0)
        let plain = OKFExporter.note(
            title: "T", body: "B", tags: ["x"],
            isJournal: false, createdAt: epoch, updatedAt: nil
        )
        #expect(plain.type == "note")
        #expect(plain.created == "1970-01-01T00:00:00Z")
        #expect(plain.updated == nil)

        let journal = OKFExporter.note(
            title: "Day", body: "", tags: [],
            isJournal: true, createdAt: nil, updatedAt: epoch
        )
        #expect(journal.type == "journal")
        #expect(journal.updated == "1970-01-01T00:00:00Z")
    }

    @Test("colliding titles get -2/-3 suffixes; nothing is overwritten")
    func fileNamesDedupeCollisions() {
        let notes = [
            OKFExporter.Note(title: "Foo"),
            OKFExporter.Note(title: "Foo"),
            OKFExporter.Note(title: "foo!"),  // also slugs to foo
            OKFExporter.Note(title: "Bar"),
        ]
        #expect(OKFBundleWriter.fileNames(for: notes) == ["foo.md", "foo-2.md", "foo-3.md", "bar.md"])
    }

    @Test("empty titles dedupe against the untitled fallback")
    func fileNamesUntitledDedupe() {
        let notes = [OKFExporter.Note(title: "  "), OKFExporter.Note(title: nil)]
        #expect(OKFBundleWriter.fileNames(for: notes) == ["untitled.md", "untitled-2.md"])
    }

    @Test("write() emits each note's markdown to disk with the computed names")
    func writeRoundTrips() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("okf-test-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: dir) }

        let notes = [
            OKFExporter.Note(type: "note", title: "Alpha", body: "first"),
            OKFExporter.Note(type: "note", title: "Alpha", body: "second"),  // collision
        ]
        let urls = try OKFBundleWriter.write(notes: notes, to: dir)

        #expect(urls.map { $0.lastPathComponent } == ["alpha.md", "alpha-2.md"])
        let first = try String(contentsOf: urls[0], encoding: .utf8)
        let second = try String(contentsOf: urls[1], encoding: .utf8)
        #expect(first.contains("title: Alpha"))
        #expect(first.contains("first"))
        #expect(second.contains("second"))
        // Both files exist on disk.
        #expect(fm.fileExists(atPath: urls[0].path))
        #expect(fm.fileExists(atPath: urls[1].path))
    }
}
