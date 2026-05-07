import AppKit
import Foundation
import Testing

@testable import Epistemos

/// Wave 7.1 follow-up source-guard for `EpdocDocument`.
@MainActor
@Suite("EpdocDocument (Wave 7.1 follow-up)")
struct EpdocDocumentTests {

    // MARK: - Class metadata

    @Test("EpdocDocument autosaves in place + preserves versions per V1 budget")
    func documentAutosaveAndVersions() {
        #expect(EpdocDocument.autosavesInPlace == true,
                "autosavesInPlace MUST be true so NSDocument coordinates 250 ms autosave with iCloud / Time Machine / Versions per the V1 budget")
        #expect(EpdocDocument.preservesVersions == true,
                "preservesVersions MUST be true so the user gets the Versions browser for free")
    }

    @Test("EpdocDocument declares the canonical com.epistemos.epdoc UTI")
    func documentDeclaresCanonicalUTI() {
        #expect(EpdocDocument.isNativeType("com.epistemos.epdoc"),
                "EpdocDocument must own the canonical com.epistemos.epdoc UTI")
        #expect(EpdocDocument.isNativeType("public.text") == false,
                "EpdocDocument must NOT own unrelated types — keeps Open dialogs honest")
        // readableTypes / writableTypes(for:) are driven by Info.plist
        // CFBundleDocumentTypes (the project.yml follow-up). isNativeType
        // is the runtime probe NSDocument uses inside the type-coercion
        // fast path; that's what we guard here.
    }

    // MARK: - init builds a usable empty package

    @Test("EpdocDocument default init produces a consumable empty package")
    func defaultInitProducesEmptyPackage() {
        let doc = EpdocDocument()
        #expect(doc.package.manifest.title == "Untitled")
        #expect(doc.package.manifest.kind == .document)
        // The default contentJSON must parse as a valid empty
        // ProseMirror doc so the Tiptap bridge (W7.2) can consume it
        // immediately on first edit.
        let parsed = try? JSONSerialization.jsonObject(with: doc.package.contentJSON)
        #expect(parsed != nil,
                "default contentJSON must parse as JSON so Tiptap can setContent it")
        let text = String(data: doc.package.contentJSON, encoding: .utf8) ?? ""
        #expect(text.contains(#""type":"paragraph""#),
                "new .epdoc packages should include an empty paragraph so Tiptap shows a caret + placeholder instead of a blank web view.")
    }

    // MARK: - read / write round-trip via FileWrapper

    @Test("read(from:ofType:) accepts the canonical UTI + decodes a real package")
    func readDecodesFileWrapper() throws {
        // Build a fully-formed package + serialise to a FileWrapper,
        // then have a fresh EpdocDocument read it back.
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let manifest = EpdocManifest(
            id: "01HMV5K2K9XJ4N0AAAA",
            kind: .document,
            schemaVersion: EpdocManifest.currentSchemaVersion,
            createdAt: now,
            updatedAt: now,
            title: "Imported",
            contentHash: "blake3-x",
            provenance: EpdocProvenance(producer: .human)
        )
        let original = EpdocPackage(
            manifest: manifest,
            contentJSON: #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!,
            shadowMarkdown: "# Imported\n".data(using: .utf8)
        )
        let wrapper = try original.makeFileWrapper()

        let doc = EpdocDocument()
        try doc.read(from: wrapper, ofType: "com.epistemos.epdoc")

        #expect(doc.package.manifest.id == "01HMV5K2K9XJ4N0AAAA")
        #expect(doc.package.manifest.title == "Imported")
        #expect(doc.package.shadowMarkdown == "# Imported\n".data(using: .utf8))
    }

    @Test("read(from:ofType:) rejects unknown UTI")
    func readRejectsUnknownUTI() throws {
        let wrapper = FileWrapper(directoryWithFileWrappers: [:])
        let doc = EpdocDocument()
        do {
            try doc.read(from: wrapper, ofType: "public.text")
            #expect(Bool(false), "must reject unknown UTI")
        } catch {
            // expected
        }
    }

    @Test("read(from:ofType:) bubbles a corrupt package as NSFileReadCorruptFileError")
    func readBubblesCorrupt() {
        // Empty directory wrapper has no manifest.json — should fail.
        let empty = FileWrapper(directoryWithFileWrappers: [:])
        let doc = EpdocDocument()
        do {
            try doc.read(from: empty, ofType: "com.epistemos.epdoc")
            #expect(Bool(false), "must throw on missing manifest")
        } catch let error as NSError {
            #expect(error.domain == NSCocoaErrorDomain)
            #expect(error.code == NSFileReadCorruptFileError,
                    "missing manifest must surface as NSFileReadCorruptFileError so the user-facing alert is meaningful")
        }
    }

    @Test("fileWrapper(ofType:) round-trips through EpdocPackage byte-equal")
    func writeRoundTrips() throws {
        let doc = EpdocDocument()
        doc.setTitle("Round Trip")
        doc.setContentJSON(#"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"hello"}]}]}"#.data(using: .utf8)!)

        let wrapper = try doc.fileWrapper(ofType: "com.epistemos.epdoc")
        // Decode via the same EpdocPackage bridge to verify byte-equal.
        let decoded = try EpdocPackage(fileWrapper: wrapper)
        #expect(decoded.manifest.title == "Round Trip")
        #expect(decoded.contentJSON == doc.package.contentJSON,
                "contentJSON MUST round-trip byte-equal — content_hash validity depends on it")
    }

    @Test("fileWrapper(ofType:) bumps updated_at on write")
    func writeBumpsUpdatedAt() throws {
        let doc = EpdocDocument()
        let createdBefore = doc.package.manifest.updatedAt
        // Tiny sleep so the write happens at a strictly-later millisecond.
        Thread.sleep(forTimeInterval: 0.01)
        let wrapper = try doc.fileWrapper(ofType: "com.epistemos.epdoc")
        let decoded = try EpdocPackage(fileWrapper: wrapper)
        #expect(decoded.manifest.updatedAt >= createdBefore,
                "fileWrapper(ofType:) must refresh updated_at to the write moment so external sync sees the change")
    }

    @Test("fileWrapper(ofType:) recomputes manifest.contentHash from the canonical contentJSON")
    func writeRecomputesContentHash() throws {
        let doc = EpdocDocument()
        // Default init seeds manifest.contentHash to "" (no hash yet
        // because the body is the empty {"type":"doc","content":[]} shell).
        #expect(doc.package.manifest.contentHash == "",
                "fresh EpdocDocument should start with empty contentHash; first save populates it")

        // Mutate to a known body so we can assert the exact hex.
        let body = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        doc.setContentJSON(body)

        let wrapper = try doc.fileWrapper(ofType: "com.epistemos.epdoc")
        let decoded = try EpdocPackage(fileWrapper: wrapper)
        let actualHash = decoded.manifest.contentHash
        #expect(!actualHash.isEmpty,
                "save MUST populate contentHash so downstream tools can detect divergence between memory + disk")
        #expect(actualHash.count == 64,
                "SHA-256 hex digest is 64 chars; got \(actualHash.count)")
        #expect(actualHash.allSatisfy { "0123456789abcdef".contains($0) },
                "contentHash must be lowercase hex; got \(actualHash)")

        // Determinism — re-saving the same body produces the same hash.
        let wrapper2 = try doc.fileWrapper(ofType: "com.epistemos.epdoc")
        let decoded2 = try EpdocPackage(fileWrapper: wrapper2)
        #expect(decoded.manifest.contentHash == decoded2.manifest.contentHash,
                "saving the same bytes twice MUST produce the same hash")

        // Sensitivity — changing the body produces a different hash.
        doc.setContentJSON(#"{"type":"doc","content":[]}"#.data(using: .utf8)!)
        let wrapper3 = try doc.fileWrapper(ofType: "com.epistemos.epdoc")
        let decoded3 = try EpdocPackage(fileWrapper: wrapper3)
        #expect(decoded.manifest.contentHash != decoded3.manifest.contentHash,
                "changing the content body MUST change contentHash")
    }

    @Test("fileWrapper(ofType:) rejects unknown UTI")
    func writeRejectsUnknownUTI() {
        let doc = EpdocDocument()
        do {
            _ = try doc.fileWrapper(ofType: "public.text")
            #expect(Bool(false), "must reject unknown UTI")
        } catch {
            // expected
        }
    }

    // MARK: - Mutation helpers

    @Test("setContentJSON marks the document dirty")
    func setContentMarksDirty() {
        let doc = EpdocDocument()
        #expect(doc.isDocumentEdited == false, "fresh doc starts clean")
        doc.setContentJSON("{}".data(using: .utf8)!)
        #expect(doc.isDocumentEdited,
                "setContentJSON must call updateChangeCount(.changeDone) so autosave fires")
    }

    @Test("setTitle marks the document dirty + persists to manifest")
    func setTitleMarksDirty() {
        let doc = EpdocDocument()
        doc.setTitle("Renamed")
        #expect(doc.package.manifest.title == "Renamed")
        #expect(doc.isDocumentEdited)
    }

    @Test("storeImageAsset writes package-local media without bloating contentJSON")
    func storeImageAssetWritesPackageLocalMedia() throws {
        let doc = EpdocDocument()
        let originalContent = doc.package.contentJSON
        let image = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a])

        let src = doc.storeImageAsset(
            data: image,
            originalFilename: "diagram.PNG",
            mimeType: "image/png"
        )

        #expect(src.hasPrefix("assets/image-"))
        #expect(src.hasSuffix(".png"))
        #expect(!src.hasPrefix("data:"),
                "Saved .epdoc documents should insert package-local image references, not base64 data URLs.")
        #expect(doc.package.contentJSON == originalContent,
                "Adding an image asset must not stuff binary bytes into content.pm.json.")
        let name = try #require(src.split(separator: "/").last.map(String.init))
        #expect(doc.package.assets[name] == image)

        let wrapper = try doc.fileWrapper(ofType: "com.epistemos.epdoc")
        let decoded = try EpdocPackage(fileWrapper: wrapper)
        #expect(decoded.assets[name] == image,
                "Package-local media must round-trip through the .epdoc FileWrapper bridge.")
    }

    @Test("resolveEditorAsset serves only flat package asset names")
    func resolveEditorAssetServesOnlyFlatPackageAssets() {
        let doc = EpdocDocument()
        let image = Data([0x47, 0x49, 0x46])
        let src = doc.storeImageAsset(
            data: image,
            originalFilename: "sample.gif",
            mimeType: "image/gif"
        )

        let resolved = doc.resolveEditorAsset(relativePath: src)
        #expect(resolved?.data == image)
        #expect(resolved?.mimeType == "image/gif")
        #expect(doc.resolveEditorAsset(relativePath: "assets/../sample.gif") == nil)
        #expect(doc.resolveEditorAsset(relativePath: "assets/nested/sample.gif") == nil)
        #expect(doc.resolveEditorAsset(relativePath: "editor.js") == nil)
    }
}
