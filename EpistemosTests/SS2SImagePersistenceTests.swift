import Testing
import Foundation

@testable import Epistemos

// SS-2S A3 (owner 2026-06-20): a Prose-inserted image was an in-memory NSTextAttachment
// DROPPED on save (textView.string = literal md; the object-replacement char doesn't
// round-trip) = real data loss. Fix: persist the image as a managed asset under the notes'
// `assets/` dir and insert `![](assets/<name>)` md that survives save (and renders via the
// A1/A2 image path). Safe fallback to the legacy attachment if the store seam is unset.
@Suite("SS-2S A3 Prose image persistence")
struct SS2SImagePersistenceTests {

    @Test("an inserted image is stored as a managed asset + returns the md-relative path")
    func storeImageAssetPersists() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ss2s-a3-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try NoteFileStorage.withStorageDirectoryOverrideForTesting(tempRoot) {
            let data = Data("fake-png-bytes-but-deterministic".utf8)
            let rel = try #require(NoteFileStorage.storeImageAsset(data: data, originalFilename: "cat.png"))
            // The md-relative reference that survives save…
            #expect(rel.hasPrefix("assets/"))
            #expect(rel.hasSuffix(".png"))
            // …and the asset file actually exists on disk under the notes' assets/ dir,
            // with the exact bytes.
            let assetURL = tempRoot.appendingPathComponent(rel)
            #expect(FileManager.default.fileExists(atPath: assetURL.path))
            #expect((try? Data(contentsOf: assetURL)) == data)
            // Content-hashed → idempotent (same bytes → same path, no duplicate file).
            #expect(NoteFileStorage.storeImageAsset(data: data, originalFilename: "cat.png") == rel)
        }
    }

    @Test("an unknown/missing extension falls back to .png (never an unsafe name)")
    func unknownExtensionFallsBack() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ss2s-a3ext-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        try NoteFileStorage.withStorageDirectoryOverrideForTesting(tempRoot) {
            let rel = try #require(NoteFileStorage.storeImageAsset(
                data: Data([0x1, 0x2, 0x3]), originalFilename: "noext"))
            #expect(rel.hasSuffix(".png"))
        }
    }

    @Test("the Prose insert path serializes to md + keeps a safe fallback")
    func insertSerializesToMd() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Notes/ProseTextView2.swift")
        #expect(src.contains("self.storeImageAsset"))                          // persist seam used
        #expect(src.contains("replaceCharacters(in: insertRange, with: md)"))  // md inserted (survives save)
        #expect(src.contains("Safe fallback"))                                 // legacy fallback kept
    }
}
