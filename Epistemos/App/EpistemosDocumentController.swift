import AppKit
import GRDB

// MARK: - EpistemosDocumentController
//
// T+4 audit gap F8 (per `docs/audits/T+4_T+5_DEEP_AUDIT_2026-04-27.md`)
// + future multi-vault future-proofing (`docs/_consolidated/`).
//
// Custom `NSDocumentController` subclass that holds the
// `DatabaseWriter` for the readable-blocks FTS index and injects
// it into freshly-created `EpdocDocument` instances right after
// AppKit instantiates them. This is **Option C** from the audit
// close-out: explicit dependency injection (vs Option B's static
// singleton) so:
//
// 1. Multi-vault future-proof — different documents can be bound
//    to different vault databases. A singleton would force "one
//    DB per process," which collapses the moment a user opens a
//    Personal vault and a Work vault in two windows.
//
// 2. Swift 6 strict concurrency — `DatabaseWriter` is `Sendable`
//    by construction; a singleton would force `@MainActor` boxing
//    or fragile `nonisolated(unsafe)` workarounds.
//
// 3. Testable — tests construct an in-memory `DatabaseQueue`,
//    instantiate `EpistemosDocumentController(databaseWriter:
//    queue)`, and verify behavior in isolation. No global state.
//
// 4. Compile-time wiring — forget to install this controller and
//    the build still works (NSDocument falls back to the default
//    NSDocumentController), but `EpdocDocument.databaseWriter`
//    stays `nil` and the FTS index simply doesn't update on save
//    (graceful degradation, not a crash).
//
// Apple lifecycle (per NSDocumentController docs):
//
//   "The first instance of NSDocumentController or any of its
//    subclasses created during the launch of an application
//    becomes the shared document controller."
//
// AppBootstrap therefore must instantiate this class BEFORE any
// code touches `NSDocumentController.shared`. The canonical hook
// is `EpistemosAppDelegate.applicationWillFinishLaunching(_:)`.

@MainActor
public final class EpistemosDocumentController: NSDocumentController {

    /// The writer used to persist the readable-blocks FTS index
    /// for any `EpdocDocument` this controller instantiates.
    /// `DatabaseWriter` (rather than `DatabasePool`) so tests can
    /// pass an in-memory `DatabaseQueue`.
    ///
    /// Mutable so the host can swap it on vault change without
    /// rebuilding the whole controller — the next document opened
    /// after the swap picks up the new writer; documents that are
    /// already open continue using whatever they were wired with
    /// (correct behavior — a workspace switch shouldn't rewire a
    /// live document mid-edit).
    public var databaseWriter: (any DatabaseWriter)?

    /// Designated initialiser. Pass `nil` (or omit) when the host
    /// hasn't built its database yet — the controller becomes a
    /// passthrough to NSDocumentController and `EpdocDocument`s
    /// open without FTS integration. Set `databaseWriter` later
    /// once the pool is ready.
    public init(databaseWriter: (any DatabaseWriter)? = nil) {
        self.databaseWriter = nil
        super.init()
        // NSDocumentController is singleton-shaped AppKit plumbing. If a
        // shared controller already exists, `super.init()` can hand back that
        // shared instance; assign after `super.init()` so the final object is
        // wired, not the pre-super allocation shell.
        self.databaseWriter = databaseWriter
    }

    /// AppKit-required init for nib loading. We don't ship from a
    /// nib so this is just plumbing — the writer stays nil until
    /// the host sets it post-load.
    public required init?(coder: NSCoder) {
        self.databaseWriter = nil
        super.init(coder: coder)
    }

    // MARK: - Factory overrides

    /// Open path — called by NSDocumentController when the user
    /// picks a `.epdoc` file via File > Open or double-clicks one
    /// in Finder.
    public override func makeDocument(
        withContentsOf url: URL,
        ofType typeName: String
    ) throws -> NSDocument {
        let doc = try super.makeDocument(withContentsOf: url, ofType: typeName)
        injectDependencies(into: doc)
        return doc
    }

    /// New-document path — called by File > New.
    public override func makeUntitledDocument(
        ofType typeName: String
    ) throws -> NSDocument {
        let doc = try super.makeUntitledDocument(ofType: typeName)
        injectDependencies(into: doc)
        return doc
    }

    /// Restoration / template path — called when AppKit reconstructs
    /// a document from a saved frame or duplicates one. Same
    /// injection contract.
    public override func makeDocument(
        for urlOrNil: URL?,
        withContentsOf contentsURL: URL,
        ofType typeName: String
    ) throws -> NSDocument {
        let doc = try super.makeDocument(
            for: urlOrNil,
            withContentsOf: contentsURL,
            ofType: typeName
        )
        injectDependencies(into: doc)
        return doc
    }

    // MARK: - Dependency injection

    /// Hand the current `databaseWriter` to any document that knows
    /// what to do with it. Public + extracted from the override
    /// methods so tests can drive injection without going through
    /// the AppKit factory plumbing.
    ///
    /// Idempotent: setting the same writer twice is a no-op. If
    /// `databaseWriter` is nil, the document's existing writer is
    /// preserved (so a host can pre-wire a document, then assign
    /// it to this controller without losing the wiring).
    public func injectDependencies(into document: NSDocument) {
        guard let writer = databaseWriter else { return }
        if let epdoc = document as? EpdocDocument {
            epdoc.databaseWriter = writer
        }
    }
}
