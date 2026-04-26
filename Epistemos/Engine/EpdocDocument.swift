import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

// MARK: - EpdocDocument
//
// Wave 7.1 follow-up of the Extended Program Plan
// (cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §3-4
//  + Wave 7.1 research finding: "NSDocument + NSFileWrapper(directoryWithFileWrappers)
//  + UTType conformance to com.apple.package — the only path that gets you
//  Finder-as-single-file + Quick Look + sandbox file coordination + autosave-in-place
//  for free").
//
// Wraps the W7.1 `EpdocPackage` FileWrapper bridge as an `NSDocument`
// subclass so the standard macOS Open / Save / Versions / Restore /
// Share Sheet flows work out of the box. Per the V1 decision §"What
// Epistemos V1 *is*" the .epdoc bundle becomes a real macOS document
// type the user sees as a single icon in Finder.
//
// To complete the Finder integration the project.yml MUST also declare:
//
//     UTExportedTypeDeclarations:
//       - UTTypeIdentifier: com.epistemos.epdoc
//         UTTypeConformsTo: [com.apple.package, public.composite-content]
//         UTTypeTagSpecification:
//           public.filename-extension: [epdoc]
//     CFBundleDocumentTypes:
//       - CFBundleTypeName: Epistemos Document
//         LSItemContentTypes: [com.epistemos.epdoc]
//         LSHandlerRank: Owner
//         CFBundleTypeRole: Editor
//         NSDocumentClass: $(PRODUCT_MODULE_NAME).EpdocDocument
//
// That project.yml edit is the ONE remaining manual step; it's
// out-of-scope for this commit because the project policy is "edit
// xcodegen, not the .xcodeproj directly" and project.yml mutations
// regenerate the entire pbxproj.
public final class EpdocDocument: NSDocument, @unchecked Sendable {

    /// The in-memory representation of this document's package.
    /// Created by `init(type:)` for new documents and overwritten by
    /// `read(from:ofType:)` when loading from disk.
    public var package: EpdocPackage

    public override init() {
        // NSDocument's designated init for new documents. Build a
        // tiny empty manifest + minimal ProseMirror JSON shell so
        // the package is consumable by the Tiptap bridge (W7.2)
        // immediately after creation.
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let manifest = EpdocManifest(
            id: UUID().uuidString,
            kind: .document,
            schemaVersion: EpdocManifest.currentSchemaVersion,
            createdAt: now,
            updatedAt: now,
            title: "Untitled",
            contentHash: "",
            provenance: EpdocProvenance(producer: .human)
        )
        let emptyDoc = #"{"type":"doc","content":[]}"#.data(using: .utf8)!
        self.package = EpdocPackage(manifest: manifest, contentJSON: emptyDoc)
        super.init()
    }

    nonisolated public override class var autosavesInPlace: Bool {
        // Per the V1 decision §"performance budget": "AI streaming
        // token batch save: every 250ms" — autosave-in-place lets
        // NSDocument coordinate that cadence with iCloud / Time
        // Machine / Versions for free.
        true
    }

    nonisolated public override class var preservesVersions: Bool {
        // Versions browser support so the user can recover prior
        // states without our own diff machinery.
        true
    }

    /// Tell NSDocument we read + write canonical UTI(s). Readable +
    /// writable type lists are normally driven by Info.plist's
    /// CFBundleDocumentTypes; isNativeType() is the runtime probe
    /// NSDocument uses for the type-coercion fast path.
    nonisolated public override class func isNativeType(_ type: String) -> Bool {
        type == "com.epistemos.epdoc"
    }

    // MARK: - Read / write via FileWrapper

    nonisolated public override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        guard typeName == "com.epistemos.epdoc" else {
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileReadCorruptFileError,
                userInfo: [NSLocalizedDescriptionKey: "Unrecognised type: \(typeName)"]
            )
        }
        // Delegate the directory-wrapper decode to the W7.1 bridge.
        // Any EpdocPackageError from there bubbles up as the load
        // failure NSDocument shows the user.
        do {
            self.package = try EpdocPackage(fileWrapper: fileWrapper)
        } catch {
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileReadCorruptFileError,
                userInfo: [
                    NSLocalizedDescriptionKey: "Couldn't open .epdoc package",
                    NSUnderlyingErrorKey: error,
                ]
            )
        }
    }

    nonisolated public override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        guard typeName == "com.epistemos.epdoc" else {
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileWriteUnsupportedSchemeError,
                userInfo: [NSLocalizedDescriptionKey: "Unrecognised type: \(typeName)"]
            )
        }
        // Refresh updated_at AND recompute content_hash so the manifest
        // pins the bytes we're about to persist.
        //
        // COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md §3 specifies the
        // hash field as `blake3::Hash`. Adding a blake3 SPM dep is a
        // separate decision (matches the W9.7 reconciliation rationale —
        // both Swift sides currently lean on CryptoKit's built-in
        // SHA-256). Until the blake3 swap, SHA-256(contentJSON) is the
        // canonical content_hash and the manifest field doubles as a
        // versioning + tamper-evidence anchor.
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let contentHash = Self.contentHash(of: package.contentJSON)
        let updated = EpdocManifest(
            id: package.manifest.id,
            kind: package.manifest.kind,
            schemaVersion: package.manifest.schemaVersion,
            createdAt: package.manifest.createdAt,
            updatedAt: now,
            title: package.manifest.title,
            contentHash: contentHash,
            provenance: package.manifest.provenance
        )
        var pkgCopy = package
        pkgCopy.manifest = updated
        return try pkgCopy.makeFileWrapper()
    }

    /// Lowercase-hex SHA-256 of the canonical content bytes. Used by
    /// `fileWrapper(ofType:)` to seed `manifest.contentHash` on every
    /// save; downstream tools rely on this field to detect divergence
    /// between an in-memory editor view and the on-disk truth.
    nonisolated static func contentHash(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Mutation helpers

    /// Replace the canonical ProseMirror JSON. Triggers the standard
    /// NSDocument dirty-tracking + autosave cadence.
    public func setContentJSON(_ data: Data) {
        package.contentJSON = data
        updateChangeCount(.changeDone)
    }

    /// Update the document title + dirty-mark.
    public func setTitle(_ title: String) {
        let manifest = package.manifest
        package.manifest = EpdocManifest(
            id: manifest.id,
            kind: manifest.kind,
            schemaVersion: manifest.schemaVersion,
            createdAt: manifest.createdAt,
            updatedAt: manifest.updatedAt,
            title: title,
            contentHash: manifest.contentHash,
            provenance: manifest.provenance
        )
        updateChangeCount(.changeDone)
    }
}
