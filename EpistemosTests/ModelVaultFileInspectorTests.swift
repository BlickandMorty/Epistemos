import Testing
import Foundation
@testable import Epistemos

/// Owner 2026-06-18 (per-model vaults) — locks the REAL on-disk probe that
/// replaced the generic "Present in compiled vaults" rows: existing files report
/// true size + mtime; missing files report honest `exists: false`; the byte
/// formatter is deterministic.
@Suite("Model vault file inspector")
struct ModelVaultFileInspectorTests {

    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-vault-probe-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("probes real size + existence; missing files are honestly absent")
    func probeReadsRealStatus() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Write two of the four canonical files; leave the other two missing.
        let profileBody = String(repeating: "x", count: 2048)
        try profileBody.write(
            to: dir.appendingPathComponent("knowledge_profile.md"),
            atomically: true,
            encoding: .utf8
        )
        try "hello".write(
            to: dir.appendingPathComponent("instructions.md"),
            atomically: true,
            encoding: .utf8
        )

        let files = ModelVaultFileInspector.probe(directory: dir)
        #expect(files.count == 4)  // always the canonical four, present or not

        let profile = try #require(files.first { $0.name == "knowledge_profile.md" })
        #expect(profile.exists)
        #expect(profile.sizeBytes == 2048)
        #expect(profile.modifiedAt != nil)

        let instructions = try #require(files.first { $0.name == "instructions.md" })
        #expect(instructions.exists)
        #expect(instructions.sizeBytes == 5)

        // The two we never wrote are honestly absent (no fake "present").
        let conceptIndex = try #require(files.first { $0.name == "concept_index.md" })
        #expect(!conceptIndex.exists)
        #expect(conceptIndex.sizeBytes == 0)
        #expect(conceptIndex.modifiedAt == nil)

        #expect(ModelVaultFileInspector.anyCompiled(files))
        #expect(ModelVaultFileInspector.totalBytes(files) == 2053)  // 2048 + 5
    }

    @Test("a never-compiled directory reports all-absent, not an error")
    func missingDirectoryIsHonest() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-vault-absent-\(UUID().uuidString)", isDirectory: true)
        let files = ModelVaultFileInspector.probe(directory: missing)
        #expect(files.count == 4)
        #expect(files.allSatisfy { !$0.exists })
        #expect(!ModelVaultFileInspector.anyCompiled(files))
        #expect(ModelVaultFileInspector.totalBytes(files) == 0)
    }

    @Test("preview collapses whitespace, truncates long files, and skips missing/blank")
    func previewReadsContent() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Multi-line content → single collapsed line.
        let multiline = "# Instructions\n\nBe concise.\n  Prefer Swift.\n"
        let multiURL = dir.appendingPathComponent("instructions.md")
        try multiline.write(to: multiURL, atomically: true, encoding: .utf8)
        let preview = try #require(ModelVaultFileInspector.preview(of: multiURL))
        #expect(preview == "# Instructions Be concise. Prefer Swift.")
        #expect(!preview.contains("\n"))

        // Long content → truncated with an ellipsis.
        let longURL = dir.appendingPathComponent("long.md")
        try String(repeating: "a", count: 500).write(to: longURL, atomically: true, encoding: .utf8)
        let longPreview = try #require(ModelVaultFileInspector.preview(of: longURL, maxChars: 50))
        #expect(longPreview.count == 51)  // 50 + the ellipsis
        #expect(longPreview.hasSuffix("…"))

        // Blank file → nil (no empty preview row).
        let blankURL = dir.appendingPathComponent("blank.md")
        try "   \n\t  ".write(to: blankURL, atomically: true, encoding: .utf8)
        #expect(ModelVaultFileInspector.preview(of: blankURL) == nil)

        // Missing file → nil, never a throw.
        #expect(ModelVaultFileInspector.preview(of: dir.appendingPathComponent("nope.md")) == nil)
    }

    @Test("byte formatter is deterministic across B / KB / MB")
    func formatsBytes() {
        #expect(ModelVaultFileInspector.formatBytes(0) == "0 B")
        #expect(ModelVaultFileInspector.formatBytes(512) == "512 B")
        #expect(ModelVaultFileInspector.formatBytes(2048) == "2 KB")
        #expect(ModelVaultFileInspector.formatBytes(1024 * 1024) == "1.0 MB")
        #expect(ModelVaultFileInspector.formatBytes(-5) == "0 B")  // never negative
    }
}
