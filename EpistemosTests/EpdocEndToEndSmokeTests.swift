import Foundation
import GRDB
import Testing

@testable import Epistemos

/// End-to-end integration test for the .epdoc Document save path —
/// the smoke harness called for in
/// `docs/audits/T+4_T+5_DEEP_AUDIT_2026-04-27.md` Tier 1 (option B).
///
/// What this verifies (and where prior per-component tests left gaps):
///   - `EpdocPackage` round-trips through `FileWrapper` byte-equal
///     (already covered in `EpdocPackageTests`)
///   - `EpdocDocument.fileWrapper(ofType:)` updates `manifest.updated_at`
///     and recomputes `content_hash`
///     (already covered in `EpdocDocumentTests`)
///   - **NEW** — A simulated content mutation flows through to
///     `ReadableBlocksIndex` so the FTS index reflects the saved doc.
    ///     This closes the prior F8 + F7 audit gap where the production
    ///     save path did not feed the FTS table.
///   - **NEW** — Search for a token in the document body returns the
///     correct artifact id + block id.
///
/// The test does NOT exercise the WKWebView pipeline (Tiptap onUpdate
/// → message → controller). That requires a live WebView and is
/// out of scope for a unit-test harness; the audit doc lists it as
/// a separate manual verification step.
@Suite("EpdocEndToEndSmoke (T+4 audit Tier-1 integration)")
nonisolated struct EpdocEndToEndSmokeTests {

    private static func makeMigratedQueue() throws -> DatabaseQueue {
        let queue = try DatabaseQueue(path: ":memory:")
        var migrator = DatabaseMigrator()
        ReadableBlocksIndex.registerMigration(&migrator)
        try migrator.migrate(queue)
        return queue
    }

    /// Build a minimal ProseMirror JSON document with a single
    /// paragraph block. Stable shape used across the smoke tests.
    private static func proseMirrorPayload(
        body: String,
        blockId: String = "block-001"
    ) -> Data {
        let json = """
        {
          "type": "doc",
          "content": [
            {
              "type": "paragraph",
              "attrs": { "blockId": "\(blockId)" },
              "content": [
                { "type": "text", "text": "\(body)" }
              ]
            }
          ]
        }
        """
        return Data(json.utf8)
    }

    /// Build an EpdocPackage with a one-block document.
    @MainActor
    private static func makeFixturePackage(
        artifactID: String,
        body: String,
        blockId: String
    ) -> EpdocPackage {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let manifest = EpdocManifest(
            id: artifactID,
            createdAt: now,
            updatedAt: now,
            title: "Smoke Doc \(artifactID)",
            contentHash: "sha256:placeholder",
            provenance: EpdocProvenance(producer: .human)
        )
        return EpdocPackage(
            manifest: manifest,
            contentJSON: proseMirrorPayload(body: body, blockId: blockId)
        )
    }

    /// Programmatic projector used by the smoke tests. This delegates to
    /// the production projector so the FTS smoke path does not drift
    /// from the `.epdoc` save path.
    @MainActor
    private static func extractReadableBlocks(
        from package: EpdocPackage
    ) throws -> [ReadableBlock] {
        ReadableBlocksProjector.project(
            contentJSON: package.contentJSON,
            artifactID: package.manifest.id,
            artifactKind: package.manifest.kind,
            documentTitle: package.manifest.title
        )
    }

    // MARK: - Round-trip

    @Test("Round-trip: package → FileWrapper → package preserves content hash and body")
    @MainActor
    func packageRoundTripsThroughFileWrapper() throws {
        let pkg = Self.makeFixturePackage(
            artifactID: "doc-rt-1",
            body: "the quick brown fox jumps over the lazy dog",
            blockId: "p-1"
        )
        let wrapper = try pkg.makeFileWrapper()
        let recovered = try EpdocPackage(fileWrapper: wrapper)

        // Manifest identity
        #expect(recovered.manifest.id == pkg.manifest.id)
        #expect(recovered.manifest.title == pkg.manifest.title)

        // Body byte-equality
        #expect(recovered.contentJSON == pkg.contentJSON,
                "content.pm.json bytes must round-trip verbatim through the FileWrapper bridge")
    }

    // MARK: - FTS integration after a "save"

    @Test("After save: ReadableBlocks projected from package land in FTS index and search returns hits")
    @MainActor
    func saveProjectsIntoReadableBlocksAndFTSReturnsHits() throws {
        let queue = try Self.makeMigratedQueue()

        let artifactID = "doc-save-fts-1"
        let pkg = Self.makeFixturePackage(
            artifactID: artifactID,
            body: "Kant's categorical imperative differs from utilitarian calculus",
            blockId: "intro-1"
        )

        let blocks = try Self.extractReadableBlocks(from: pkg)
        #expect(blocks.count == 1, "smoke fixture should produce one block")
        #expect(blocks.first?.blockID == "intro-1")
        #expect(blocks.first?.body.contains("categorical imperative") == true)

        try queue.write { db in
            try ReadableBlocksIndex.replaceAllForArtifact(
                artifactID,
                with: blocks,
                in: db
            )
            #expect(try ReadableBlocksIndex.count(forArtifact: artifactID, in: db) == 1)
        }

        try queue.read { db in
            let hits = try ReadableBlocksIndex.search("categorical", in: db)
            #expect(hits.count == 1, "FTS must return the saved block; got \(hits.count)")
            #expect(hits.first?.artifactID == artifactID)
            #expect(hits.first?.blockID == "intro-1")
            #expect(hits.first?.artifactKind == .document)
        }
    }

    @Test("After resave: replaceAllForArtifact purges old FTS entries and indexes new")
    @MainActor
    func resavePurgesAndReindexes() throws {
        let queue = try Self.makeMigratedQueue()
        let artifactID = "doc-resave-1"

        let revOne = Self.makeFixturePackage(
            artifactID: artifactID,
            body: "first revision contains alpha and bravo",
            blockId: "p-1"
        )
        let blocksOne = try Self.extractReadableBlocks(from: revOne)
        try queue.write { db in
            try ReadableBlocksIndex.replaceAllForArtifact(artifactID, with: blocksOne, in: db)
        }
        try queue.read { db in
            let alphaHits = try ReadableBlocksIndex.search("alpha", in: db)
            #expect(alphaHits.count == 1)
        }

        // Mutate content as if user typed in Tiptap; resave.
        let revTwo = Self.makeFixturePackage(
            artifactID: artifactID,
            body: "second revision contains charlie and delta",
            blockId: "p-1"
        )
        let blocksTwo = try Self.extractReadableBlocks(from: revTwo)
        try queue.write { db in
            try ReadableBlocksIndex.replaceAllForArtifact(artifactID, with: blocksTwo, in: db)
        }
        try queue.read { db in
            let staleAlpha = try ReadableBlocksIndex.search("alpha", in: db)
            #expect(staleAlpha.isEmpty,
                    "stale revision tokens MUST be purged on resave; found stragglers")
            let charlie = try ReadableBlocksIndex.search("charlie", in: db)
            #expect(charlie.count == 1,
                    "fresh revision tokens MUST be indexed")
        }
    }

    // MARK: - NSDocument fileWrapper recomputes the content_hash

    @Test("EpdocDocument.fileWrapper updates manifest content_hash on every save")
    @MainActor
    func fileWrapperRecomputesContentHash() throws {
        let pkg = Self.makeFixturePackage(
            artifactID: "doc-hash-1",
            body: "version one body",
            blockId: "p-1"
        )
        let doc = EpdocDocument()
        doc.package = pkg

        let wrapperOne = try doc.fileWrapper(ofType: "com.epistemos.epdoc")
        let manifestData = wrapperOne.fileWrappers?[EpdocPackageEntry.manifest]?.regularFileContents
        let manifestOne = try JSONDecoder().decode(
            EpdocManifest.self,
            from: manifestData ?? Data()
        )
        #expect(!manifestOne.contentHash.isEmpty, "save must populate content_hash")

        // Mutate the package, save again, hash MUST change.
        doc.setContentJSON(Self.proseMirrorPayload(body: "version two body", blockId: "p-1"))
        let wrapperTwo = try doc.fileWrapper(ofType: "com.epistemos.epdoc")
        let manifestTwo = try JSONDecoder().decode(
            EpdocManifest.self,
            from: wrapperTwo.fileWrappers?[EpdocPackageEntry.manifest]?.regularFileContents
                ?? Data()
        )
        #expect(manifestOne.contentHash != manifestTwo.contentHash,
                "mutating content.pm.json MUST change the content_hash")
        #expect(manifestTwo.updatedAt >= manifestOne.updatedAt,
                "manifest updated_at must monotonically advance across saves")
    }

    // MARK: - Multiple-block + heading round-trip

    // MARK: - F6 markdown shadow regeneration

    @Test("EpdocDocument.fileWrapper writes a fresh shadow.md on every save (audit gap F6)")
    @MainActor
    func fileWrapperRegeneratesMarkdownShadow() throws {
        let pkg = Self.makeFixturePackage(
            artifactID: "doc-shadow-1",
            body: "the categorical imperative",
            blockId: "p-1"
        )
        // Pre-condition — fixture has nil shadowMarkdown (the
        // package init didn't supply one).
        #expect(pkg.shadowMarkdown == nil,
                "fixture must start without a shadow")

        let doc = EpdocDocument()
        doc.package = pkg

        let wrapper = try doc.fileWrapper(ofType: "com.epistemos.epdoc")
        let projWrapper = wrapper.fileWrappers?[EpdocPackageEntry.projections]
        let shadowWrapper = projWrapper?.fileWrappers?[
            EpdocPackageEntry.Projection.shadowMarkdown
        ]
        #expect(shadowWrapper != nil,
                "projections/shadow.md MUST be written by fileWrapper(ofType:) — F6 close-out")

        let shadowBytes = shadowWrapper?.regularFileContents ?? Data()
        #expect(!shadowBytes.isEmpty,
                "regenerated shadow MUST carry projected text — got \(shadowBytes.count) bytes")
        let shadowText = String(data: shadowBytes, encoding: .utf8) ?? ""
        #expect(shadowText.contains("categorical imperative"),
                "shadow.md MUST surface the canonical content — got \"\(shadowText)\"")
    }

    @Test("Mutating content + resaving regenerates the shadow with the new body")
    @MainActor
    func resaveRefreshesShadow() throws {
        let pkg = Self.makeFixturePackage(
            artifactID: "doc-shadow-2",
            body: "first revision body",
            blockId: "p-1"
        )
        let doc = EpdocDocument()
        doc.package = pkg

        let wrapperOne = try doc.fileWrapper(ofType: "com.epistemos.epdoc")
        let shadowOne = wrapperOne.fileWrappers?[EpdocPackageEntry.projections]?
            .fileWrappers?[EpdocPackageEntry.Projection.shadowMarkdown]?
            .regularFileContents ?? Data()
        let textOne = String(data: shadowOne, encoding: .utf8) ?? ""
        #expect(textOne.contains("first revision"))

        // Mutate + resave.
        doc.setContentJSON(Self.proseMirrorPayload(body: "second revision body", blockId: "p-1"))
        let wrapperTwo = try doc.fileWrapper(ofType: "com.epistemos.epdoc")
        let shadowTwo = wrapperTwo.fileWrappers?[EpdocPackageEntry.projections]?
            .fileWrappers?[EpdocPackageEntry.Projection.shadowMarkdown]?
            .regularFileContents ?? Data()
        let textTwo = String(data: shadowTwo, encoding: .utf8) ?? ""

        #expect(!textTwo.contains("first revision"),
                "stale shadow body MUST be replaced — found \"\(textTwo)\"")
        #expect(textTwo.contains("second revision"),
                "fresh shadow MUST carry the new body — found \"\(textTwo)\"")
    }

    @Test("EpdocDocument.fileWrapper writes search_blocks.jsonl and plain.txt from canonical content")
    @MainActor
    func fileWrapperWritesReadableProjections() throws {
        let pkg = Self.makeFixturePackage(
            artifactID: "doc-search-blocks-1",
            body: "canonical readable projection",
            blockId: "p-readable"
        )
        let doc = EpdocDocument()
        doc.package = pkg

        let wrapper = try doc.fileWrapper(ofType: "com.epistemos.epdoc")
        let decoded = try EpdocPackage(fileWrapper: wrapper)

        let plainText = String(data: decoded.plainText ?? Data(), encoding: .utf8) ?? ""
        #expect(plainText.contains("canonical readable projection"),
                "plain.txt must be regenerated from canonical content.pm.json")

        let searchJSONL = String(data: decoded.searchBlocksJSONL ?? Data(), encoding: .utf8) ?? ""
        #expect(searchJSONL.contains("\"artifact_id\":\"doc-search-blocks-1\""),
                "search_blocks.jsonl must carry artifact_id")
        #expect(searchJSONL.contains("\"artifact_kind\":\"document\""),
                "search_blocks.jsonl must carry artifact_kind as stable lower_snake_case")
        #expect(searchJSONL.contains("\"block_id\":\"p-readable\""),
                "search_blocks.jsonl must carry block_id for exact search jumps")
        #expect(searchJSONL.contains("canonical readable projection"),
                "search_blocks.jsonl must be regenerated from canonical content.pm.json")
    }

    @Test("External or stale projection edits never overwrite canonical content")
    @MainActor
    func staleProjectionsDoNotOverwriteCanonicalContent() throws {
        var pkg = Self.makeFixturePackage(
            artifactID: "doc-shadow-external-1",
            body: "canonical source body",
            blockId: "p-canonical"
        )
        pkg.shadowMarkdown = Data("external shadow edit should not win".utf8)
        pkg.plainText = Data("stale plain projection should not win".utf8)
        pkg.searchBlocksJSONL = Data(#"{"body":"stale search projection should not win"}"#.utf8)

        let staleWrapper = try pkg.makeFileWrapper()
        let doc = EpdocDocument()
        try doc.read(from: staleWrapper, ofType: "com.epistemos.epdoc")

        let savedWrapper = try doc.fileWrapper(ofType: "com.epistemos.epdoc")
        let decoded = try EpdocPackage(fileWrapper: savedWrapper)

        #expect(decoded.contentJSON == pkg.contentJSON,
                "canonical content.pm.json must remain the source of truth")

        let shadow = String(data: decoded.shadowMarkdown ?? Data(), encoding: .utf8) ?? ""
        #expect(shadow.contains("canonical source body"),
                "shadow.md must regenerate from canonical content")
        #expect(!shadow.contains("external shadow edit"),
                "external shadow.md text must not overwrite canonical content")

        let plain = String(data: decoded.plainText ?? Data(), encoding: .utf8) ?? ""
        #expect(plain.contains("canonical source body"),
                "plain.txt must regenerate from canonical content")
        #expect(!plain.contains("stale plain projection"),
                "stale plain.txt text must not survive save")

        let search = String(data: decoded.searchBlocksJSONL ?? Data(), encoding: .utf8) ?? ""
        #expect(search.contains("canonical source body"),
                "search_blocks.jsonl must regenerate from canonical content")
        #expect(!search.contains("stale search projection"),
                "stale search_blocks.jsonl text must not survive save")
    }

    @Test("Multi-block document: heading + paragraph both project into FTS")
    @MainActor
    func multiBlockProjection() throws {
        let queue = try Self.makeMigratedQueue()
        let json = """
        {
          "type": "doc",
          "content": [
            {
              "type": "heading",
              "attrs": { "blockId": "h-1", "level": 1 },
              "content": [{ "type": "text", "text": "Critique of Pure Reason" }]
            },
            {
              "type": "paragraph",
              "attrs": { "blockId": "p-1" },
              "content": [{ "type": "text", "text": "synthetic a priori judgments are possible" }]
            }
          ]
        }
        """
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let manifest = EpdocManifest(
            id: "doc-multi-1",
            createdAt: now,
            updatedAt: now,
            title: "Kant Notes",
            contentHash: "sha256:placeholder",
            provenance: EpdocProvenance(producer: .human)
        )
        let pkg = EpdocPackage(manifest: manifest, contentJSON: Data(json.utf8))

        let blocks = try Self.extractReadableBlocks(from: pkg)
        #expect(blocks.count == 2, "expected heading + paragraph blocks")
        #expect(blocks.contains(where: { $0.blockKind == .heading }))
        #expect(blocks.contains(where: { $0.blockKind == .paragraph }))

        try queue.write { db in
            try ReadableBlocksIndex.replaceAllForArtifact("doc-multi-1", with: blocks, in: db)
        }
        try queue.read { db in
            let hHits = try ReadableBlocksIndex.search("Critique", in: db)
            #expect(hHits.contains(where: { $0.blockID == "h-1" }),
                    "heading text must be searchable")

            let pHits = try ReadableBlocksIndex.search("synthetic", in: db)
            #expect(pHits.count == 1, "paragraph text must be searchable")
            #expect(pHits.first?.blockID == "p-1")
        }
    }
}
