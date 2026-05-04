import AppKit
import CryptoKit
import Foundation
import GRDB
import OSLog
import SwiftUI
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

    /// Audit gap F8 close-out (`docs/audits/T+4_T+5_DEEP_AUDIT_2026-04-27.md`).
    /// Database writer used to refresh the readable-blocks FTS
    /// index on every save. Injected by
    /// `EpistemosDocumentController.injectDependencies(into:)`
    /// (Option C - explicit dependency injection per audit
    /// close-out). When nil the FTS update silently skips so
    /// tests / preview hosts can construct EpdocDocument without
    /// wiring a database.
    public var databaseWriter: (any DatabaseWriter)?

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

    /// Explicitly keep writes synchronous.
    ///
    /// NSDocument defaults to synchronous writes, but making that
    /// explicit here prevents a future subclass or build-flag change
    /// from silently enabling async writes. The `assumeIsolated` calls
    /// in `read(from:ofType:)` and `fileWrapper(ofType:)` are only safe
    /// while this document's read/write path is synchronous and on the
    /// main thread. If async writing is ever needed, those methods must
    /// first be refactored to use an immutable Sendable snapshot instead.
    nonisolated public override func canAsynchronouslyWrite(
        to url: URL,
        ofType typeName: String,
        for saveOperation: NSDocument.SaveOperationType
    ) -> Bool { false }

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
            let pkg = try EpdocPackage(fileWrapper: fileWrapper)
            // This class returns false from canAsynchronouslyWrite, keeping
            // all read/write calls synchronous on the main thread. The
            // assumeIsolated call is valid under that constraint; if async
            // writes are ever enabled this line must be replaced with an
            // actor-safe snapshot pattern.
            MainActor.assumeIsolated { self.package = pkg }
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
        // canAsynchronouslyWrite returns false for this class, so writes
        // stay synchronous on the main thread. The assumeIsolated snapshot
        // is valid under that constraint; must be revisited if async writes
        // are ever enabled.
        let pkgSnapshot = MainActor.assumeIsolated { self.package }
        let contentHash = Self.contentHash(of: pkgSnapshot.contentJSON)
        let updated = EpdocManifest(
            id: pkgSnapshot.manifest.id,
            kind: pkgSnapshot.manifest.kind,
            schemaVersion: pkgSnapshot.manifest.schemaVersion,
            createdAt: pkgSnapshot.manifest.createdAt,
            updatedAt: now,
            title: pkgSnapshot.manifest.title,
            contentHash: contentHash,
            provenance: pkgSnapshot.manifest.provenance
        )
        var pkgCopy = pkgSnapshot
        pkgCopy.manifest = updated

        // Audit gap F6 close-out
        // (`docs/audits/T+4_T+5_DEEP_AUDIT_2026-04-27.md`) +
        // implementation plan section 151 - "Markdown shadow regenerates
        // from canonical on every save." Project the freshly-saved
        // ProseMirror JSON into a Markdown shadow and stash it on
        // the LOCAL package copy so `EpdocPackage.makeFileWrapper()`
        // writes it under `projections/shadow.md`. Failure
        // (unparseable ProseMirror JSON) clears the shadow rather
        // than carrying stale bytes into the next save.
        // Bidirectional sync is forbidden - external `shadow.md`
        // edits are imported as a reviewable conversion, never
        // silently overwriting `content.pm.json` (per implementation
        // plan section 153). Mutates `pkgCopy` (local) - the document's
        // own `package` stays MainActor-bound and untouched from
        // this nonisolated method.
        let regeneratedShadow =
            ProseMirrorMarkdownProjector.project(jsonData: pkgCopy.contentJSON)
        pkgCopy.shadowMarkdown = regeneratedShadow.flatMap { $0.data(using: .utf8) }

        let readableBlocks = ReadableBlocksProjector.project(
            contentJSON: pkgCopy.contentJSON,
            artifactID: pkgCopy.manifest.id,
            artifactKind: pkgCopy.manifest.kind,
            documentTitle: pkgCopy.manifest.title
        )
        pkgCopy.plainText = ReadableBlocksProjector.plainText(from: readableBlocks)
        pkgCopy.searchBlocksJSONL = try? ReadableBlocksProjector.encodeSearchBlocksJSONL(readableBlocks)

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

    // MARK: - F8 readable-blocks projection
    //
    // Audit gap F8 close-out - every successful save extracts the
    // ProseMirror content into block-level rows and refreshes the
    // universal FTS index (`readable_blocks_fts`) for this
    // artifact. The Tier 3 split is deliberate:
    //
    //   1. `projectAndIndexBlocks(contentJSON:)` is `@MainActor
    //      async` - projection happens synchronously on MainActor
    //      (the document's manifest is MainActor-bound), then the
    //      FTS write awaits off-actor on the GRDB writer queue.
    //
    //   2. The autosave closure inside `makeWindowControllers()`
    //      spawns a `Task` to fire this asynchronously so the
    //      300 ms debounced save path doesn't block on disk I/O.
    //
    //   3. When `databaseWriter` is nil (no host wiring) the call
    //      is a cheap no-op so unit tests + previews can omit DB
    //      construction.
    //
    // The unified DatabaseWriter is injected by
    // `EpistemosDocumentController.injectDependencies(into:)`
    // (Option C explicit injection per audit close-out).

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "EpdocDocument"
    )

    /// Project the supplied ProseMirror JSON into `[ReadableBlock]`
    /// rows + replace the FTS index entries for this artifact.
    /// No-op when `databaseWriter` is nil.
    ///
    /// Errors during the FTS write are logged but never re-thrown:
    /// autosave must never crash the host app over a search-index
    /// hiccup. The next save retries the projection so transient
    /// failures self-heal.
    public func projectAndIndexBlocks(contentJSON: Data) async {
        guard let writer = databaseWriter else { return }

        // Synchronous projection on MainActor - the manifest
        // accessors are MainActor-bound. Snapshot Sendable values
        // before the await so the post-resume closure doesn't
        // race the document's mutable state.
        let artifactID = package.manifest.id
        let artifactKind = package.manifest.kind
        let documentTitle = package.manifest.title
        let blocks = ReadableBlocksProjector.project(
            contentJSON: contentJSON,
            artifactID: artifactID,
            artifactKind: artifactKind,
            documentTitle: documentTitle
        )

        do {
            try await writer.write { db in
                try ReadableBlocksIndex.replaceAllForArtifact(
                    artifactID,
                    with: blocks,
                    in: db
                )
            }
        } catch {
            Self.log.warning(
                "readable_blocks FTS update failed for artifact \(artifactID, privacy: .public): \(String(describing: error), privacy: .public)"
            )
        }
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

    // MARK: - Window presentation
    //
    // Audit gap F1 close-out (T+4_T+5_DEEP_AUDIT_2026-04-27.md).
    // Without `makeWindowControllers()`, NSDocument loaded the
    // package into memory but presented no window. This override
    // hosts the SwiftUI `EpdocEditorChromeView` inside an
    // NSHostingController + NSWindowController and wires the
    // controller's autosave pipeline back into NSDocument's
    // dirty-tracking so every Tiptap keystroke advances the
    // document's change count and the standard NSDocument
    // autosave-in-place cadence (every 250 ms) coordinates with
    // iCloud / Time Machine / Versions for free.

    nonisolated public override func makeWindowControllers() {
        MainActor.assumeIsolated {
            let chromeController = EpdocEditorChromeController()

            // Audit gap F4 + F5 close-out - every Tiptap onUpdate
            // routed via the chrome controller's `onContentChanged`
            // sink, debounced 300 ms by `EpdocEditorSavePipeline`,
            // and delivered to `setContentJSON(_:)` which mutates
            // `package.contentJSON` + flips the dirty flag.
            //
            // Audit gap F8 close-out - additionally fire the
            // readable-blocks projection so the universal FTS
            // index reflects the freshly-saved content. The Task
            // spawn keeps the disk write off the @MainActor save
            // path while the projection itself stays MainActor.
            chromeController.attachAutosavePipeline { [weak self] json in
                guard let self else { return }
                self.setContentJSON(json)
                Task { [weak self] in
                    await self?.projectAndIndexBlocks(contentJSON: json)
                }
            }

            let chromeView = EpdocEditorChromeView(controller: chromeController)
            let hostingController = NSHostingController(rootView: chromeView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = self.package.manifest.title.isEmpty
                ? "Untitled"
                : self.package.manifest.title
            window.setContentSize(NSSize(width: 1024, height: 768))
            window.minSize = NSSize(width: 480, height: 320)
            window.styleMask.insert([.resizable, .titled, .closable, .miniaturizable])
            // Per-document autosave name keeps each .epdoc's window
            // frame separate. The id from the manifest is stable
            // across renames (per ArtifactHeader contract).
            window.setFrameAutosaveName(
                "EpdocDocumentWindow.\(self.package.manifest.id)"
            )

            let windowController = NSWindowController(window: window)
            self.addWindowController(windowController)
        }
    }
}
