import Foundation
import Testing

@testable import Epistemos

@Suite("Epdoc markdown write-through")
nonisolated struct EpdocMarkdownWriteThroughTests {
    private static func sampleManifest(id: String = "doc-123") -> EpdocManifest {
        EpdocManifest(
            id: id,
            kind: .document,
            schemaVersion: EpdocManifest.currentSchemaVersion,
            createdAt: 1_700_000_000_000,
            updatedAt: 1_700_000_001_000,
            title: "Research: \"Delta\"",
            contentHash: "manifest-hash",
            provenance: EpdocProvenance(
                producer: .human,
                generatedByRun: "run-123",
                toolId: "epdoc-editor"
            ),
            metadata: [
                "Display Mode": "wide",
            ]
        )
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("epdoc-md-write-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test("JSON-only mode does not write vault markdown")
    func jsonOnlySkips() throws {
        let vaultURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        let request = EpdocMarkdownWriteThroughRequest(
            mode: .jsonOnly,
            vaultURL: vaultURL,
            manifest: Self.sampleManifest(),
            markdown: "# Heading\n",
            contentJSONHash: "json-hash"
        )

        #expect(EpdocMarkdownWriteThrough.writeIfEnabled(request) == .skipped(.jsonOnly))
        #expect(!FileManager.default.fileExists(
            atPath: vaultURL.appendingPathComponent("notes", isDirectory: true).path
        ))
    }

    @Test("Dual-write mode writes canonical markdown with Epdoc frontmatter")
    func dualWriteExportsMarkdown() throws {
        let vaultURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        let manifest = Self.sampleManifest()
        let targetURL = vaultURL
            .appendingPathComponent("notes", isDirectory: true)
            .appendingPathComponent("doc-123.md")
        let request = EpdocMarkdownWriteThroughRequest(
            mode: .dualWrite,
            vaultURL: vaultURL,
            manifest: manifest,
            markdown: "# Heading\n\nBody",
            contentJSONHash: "json-hash"
        )

        #expect(EpdocMarkdownWriteThrough.shouldAttemptWrite(request))
        #expect(EpdocMarkdownWriteThrough.writeIfEnabled(request) == .wrote(targetURL))

        let written = try String(contentsOf: targetURL, encoding: .utf8)
        let (frontMatter, body) = VaultIndexActor.parseFrontMatter(written)
        #expect(frontMatter["_epdoc_id"] == "doc-123")
        #expect(frontMatter["_epdoc_kind"] == "document")
        #expect(frontMatter["title"] == "Research: \"Delta\"")
        #expect(frontMatter["_epdoc_content_json_hash"] == "json-hash")
        #expect(frontMatter["_epdoc_metadata_display_mode"] == "wide")
        #expect(frontMatter["_width"] == nil)
        #expect(body == "# Heading\n\nBody")
        #expect(written.hasSuffix("Body\n"))
    }

    @Test("Dual-write persists explicit note width in existing Epdoc frontmatter")
    func dualWriteExportsExplicitWidth() throws {
        let vaultURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        let manifest = Self.sampleManifest()
        let targetURL = vaultURL
            .appendingPathComponent("notes", isDirectory: true)
            .appendingPathComponent("doc-123.md")
        let request = EpdocMarkdownWriteThroughRequest(
            mode: .dualWrite,
            vaultURL: vaultURL,
            manifest: manifest,
            markdown: "# Heading\n\nBody",
            contentJSONHash: "json-hash",
            widthMode: .custom(px: 1_040)
        )

        #expect(EpdocMarkdownWriteThrough.writeIfEnabled(request) == .wrote(targetURL))

        let written = try String(contentsOf: targetURL, encoding: .utf8)
        let (frontMatter, body) = VaultIndexActor.parseFrontMatter(written)
        #expect(frontMatter["_width"] == "1040px")
        #expect(body == "# Heading\n\nBody")
    }

    @Test("Dual-write skips when the JS markdown snapshot is unavailable")
    func missingMarkdownSnapshotSkips() throws {
        let vaultURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        let request = EpdocMarkdownWriteThroughRequest(
            mode: .dualWrite,
            vaultURL: vaultURL,
            manifest: Self.sampleManifest(),
            markdown: nil,
            contentJSONHash: "json-hash"
        )

        #expect(!EpdocMarkdownWriteThrough.shouldAttemptWrite(request))
        #expect(EpdocMarkdownWriteThrough.writeIfEnabled(request) == .skipped(.missingMarkdownSnapshot))
    }

    @Test("Markdown-canonical mode writes the same Epdoc-owned vault markdown")
    func markdownCanonicalModeWritesCanonicalMarkdown() throws {
        let vaultURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        let targetURL = vaultURL
            .appendingPathComponent("notes", isDirectory: true)
            .appendingPathComponent("doc-123.md")
        let request = EpdocMarkdownWriteThroughRequest(
            mode: .markdownCanonical,
            vaultURL: vaultURL,
            manifest: Self.sampleManifest(),
            markdown: "# Heading\n\nBody",
            contentJSONHash: "json-hash"
        )

        #expect(EpdocMarkdownWriteThrough.shouldAttemptWrite(request))
        #expect(EpdocMarkdownWriteThrough.writeIfEnabled(request) == .wrote(targetURL))
        let written = try String(contentsOf: targetURL, encoding: .utf8)
        #expect(written.contains(#"_epdoc_id: "doc-123""#))
        #expect(written.contains(#"_epdoc_content_json_hash: "json-hash""#))
        #expect(written.hasSuffix("# Heading\n\nBody\n"))
    }

    @Test("Existing authored frontmatter is not overwritten by the Phase A writer")
    func authoredFrontmatterSkips() throws {
        let vaultURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        let request = EpdocMarkdownWriteThroughRequest(
            mode: .dualWrite,
            vaultURL: vaultURL,
            manifest: Self.sampleManifest(),
            markdown: "---\ntitle: User Owned\n---\nBody",
            contentJSONHash: "json-hash"
        )

        #expect(!EpdocMarkdownWriteThrough.shouldAttemptWrite(request))
        #expect(
            EpdocMarkdownWriteThrough.writeIfEnabled(request)
                == .skipped(.markdownAlreadyHasFrontmatter)
        )
    }

    @Test("Epdoc markdown source exports are reserved from SDPage import")
    func epdocFrontmatterSkipsVaultNoteImport() {
        #expect(VaultIndexActor.isEpdocMarkdownSource(["_epdoc_id": "doc-123"]))
        #expect(!VaultIndexActor.isEpdocMarkdownSource(["_epdoc_id": "   "]))
        #expect(!VaultIndexActor.isEpdocMarkdownSource(["id": "normal-note"]))
    }

    @Test("Markdown-canonical load reads only the Epdoc-owned body")
    func markdownCanonicalLoadReadsEpdocOwnedBody() throws {
        let vaultURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        let manifest = Self.sampleManifest()
        let request = EpdocMarkdownWriteThroughRequest(
            mode: .markdownCanonical,
            vaultURL: vaultURL,
            manifest: manifest,
            markdown: "# Canonical\n\n[[Note]]\n",
            contentJSONHash: "json-hash",
            widthMode: .wide
        )
        let targetURL = vaultURL
            .appendingPathComponent("notes", isDirectory: true)
            .appendingPathComponent("doc-123.md")
        #expect(EpdocMarkdownWriteThrough.writeIfEnabled(request) == .wrote(targetURL))

        let result = EpdocMarkdownWriteThrough.loadCanonicalMarkdownIfEnabled(
            mode: .markdownCanonical,
            vaultURL: vaultURL,
            manifestID: manifest.id
        )

        #expect(result == .loaded(
            markdown: "# Canonical\n\n[[Note]]\n",
            url: targetURL,
            widthMode: .wide
        ))
    }

    @Test("Markdown-canonical load refuses non-Epdoc or mismatched markdown files")
    func markdownCanonicalLoadRequiresMatchingEpdocID() throws {
        let vaultURL = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: vaultURL) }
        let notesURL = vaultURL.appendingPathComponent("notes", isDirectory: true)
        try FileManager.default.createDirectory(at: notesURL, withIntermediateDirectories: true)

        let targetURL = notesURL.appendingPathComponent("doc-123.md")
        try AtomicVaultWriter.writeSynchronously("title: no frontmatter\n\nBody", to: targetURL)
        #expect(
            EpdocMarkdownWriteThrough.loadCanonicalMarkdownIfEnabled(
                mode: .markdownCanonical,
                vaultURL: vaultURL,
                manifestID: "doc-123"
            ) == .skipped(.missingEpdocFrontmatter)
        )

        try AtomicVaultWriter.writeSynchronously(
            """
        ---
        _epdoc_id: "other-doc"
        ---

        Body
        """,
            to: targetURL
        )
        #expect(
            EpdocMarkdownWriteThrough.loadCanonicalMarkdownIfEnabled(
                mode: .markdownCanonical,
                vaultURL: vaultURL,
                manifestID: "doc-123"
            ) == .skipped(.epdocIDMismatch)
        )
    }
}
