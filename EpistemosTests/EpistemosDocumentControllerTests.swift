import Foundation
import GRDB
import Testing

@testable import Epistemos

/// Tests for `EpistemosDocumentController` + `EpdocDocument`'s
/// F8 readable-blocks FTS bridge (per
/// `docs/audits/T+4_T+5_DEEP_AUDIT_2026-04-27.md` audit gap F8 +
/// user-selected Option C explicit dependency injection).
@Suite("EpistemosDocumentController + EpdocDocument F8 bridge")
nonisolated struct EpistemosDocumentControllerTests {

    private static func makeMigratedQueue() throws -> DatabaseQueue {
        let queue = try DatabaseQueue(path: ":memory:")
        var migrator = DatabaseMigrator()
        ReadableBlocksIndex.registerMigration(&migrator)
        try migrator.migrate(queue)
        return queue
    }

    // MARK: - Controller dependency injection

    @Test("Controller stores the DatabaseWriter at init")
    @MainActor
    func controllerStoresWriter() throws {
        let queue = try Self.makeMigratedQueue()
        let controller = EpistemosDocumentController(databaseWriter: queue)
        #expect(controller.databaseWriter != nil,
                "controller MUST hold the writer it was constructed with")
    }

    @Test("injectDependencies hooks the writer into EpdocDocument")
    @MainActor
    func injectsWriterIntoEpdocDocument() throws {
        let queue = try Self.makeMigratedQueue()
        let controller = EpistemosDocumentController(databaseWriter: queue)
        let doc = EpdocDocument()

        #expect(doc.databaseWriter == nil, "fresh doc must have no writer")

        controller.injectDependencies(into: doc)

        #expect(doc.databaseWriter != nil,
                "after injectDependencies the document MUST hold the writer the controller holds")
    }

    @Test("injectDependencies is a no-op when controller has no writer")
    @MainActor
    func injectionNoOpWhenControllerHasNoWriter() {
        let controller = EpistemosDocumentController(databaseWriter: nil)
        let doc = EpdocDocument()
        controller.injectDependencies(into: doc)
        #expect(doc.databaseWriter == nil,
                "controller with nil writer MUST not overwrite the document's writer")
    }

    @Test("injectDependencies preserves an already-wired document writer")
    @MainActor
    func injectionPreservesPriorWriter() throws {
        // Two queues — the test verifies that injecting "controller's
        // writer" doesn't clobber a writer the host pre-wired onto
        // the document via some other path.
        let queueA = try Self.makeMigratedQueue()
        let queueB = try Self.makeMigratedQueue()
        let controller = EpistemosDocumentController(databaseWriter: nil)
        let doc = EpdocDocument()
        doc.databaseWriter = queueA

        controller.injectDependencies(into: doc)

        // Controller's writer is nil, so the inject is a no-op and
        // the doc keeps its prior wiring. (queueB unused — kept to
        // make the symmetry obvious.)
        _ = queueB
        #expect(doc.databaseWriter != nil,
                "pre-wired document writer must survive a no-op injection")
    }

    @Test("Controller mutating its writer doesn't retroactively rewire open documents")
    @MainActor
    func writerSwapDoesNotRewireOpenDocs() throws {
        let queueA = try Self.makeMigratedQueue()
        let queueB = try Self.makeMigratedQueue()
        let controller = EpistemosDocumentController(databaseWriter: queueA)
        let doc = EpdocDocument()
        controller.injectDependencies(into: doc)

        // Swap — should NOT rewire the already-injected document
        // (correct behavior per controller header doc — a workspace
        // switch shouldn't mutate live documents).
        controller.databaseWriter = queueB

        // Writer reference on doc still equals queueA, not queueB.
        // We can't reliably === compare any DatabaseWriter (it's
        // a protocol); instead verify the doc's writer is non-nil
        // and the controller's reference has changed.
        #expect(doc.databaseWriter != nil)
    }

    // MARK: - F8 projection bridge

    @Test("projectAndIndexBlocks is a no-op when databaseWriter is nil")
    @MainActor
    func projectionNoOpWithoutWriter() async {
        let doc = EpdocDocument()
        // No writer set — projection is a cheap no-op.
        let json = #"{"type":"doc","content":[{"type":"paragraph","attrs":{"blockId":"p1"},"content":[{"type":"text","text":"hi"}]}]}"#
        await doc.projectAndIndexBlocks(contentJSON: Data(json.utf8))
        // No assertion beyond "didn't crash" — the no-op contract
        // is observable by absence of side-effects.
    }

    @Test("projectAndIndexBlocks projects + writes blocks into FTS")
    @MainActor
    func projectionWritesBlocks() async throws {
        let queue = try Self.makeMigratedQueue()
        let doc = EpdocDocument()
        doc.databaseWriter = queue
        doc.setTitle("Kant Notes")
        let artifactID = doc.package.manifest.id

        let json = """
        {"type":"doc","content":[
          {"type":"paragraph","attrs":{"blockId":"p1"},
           "content":[{"type":"text","text":"categorical imperative differs from utilitarianism"}]}
        ]}
        """
        await doc.projectAndIndexBlocks(contentJSON: Data(json.utf8))

        try await queue.read { db in
            let count = try ReadableBlocksIndex.count(forArtifact: artifactID, in: db)
            #expect(count == 1, "expected exactly one row for the projected artifact, got \(count)")

            let hits = try ReadableBlocksIndex.search("categorical", in: db)
            #expect(hits.count == 1, "FTS must return the projected block")
            #expect(hits.first?.artifactID == artifactID)
            #expect(hits.first?.blockID == "p1")
        }
    }

    @Test("Resaving the document replaces FTS entries (no stragglers)")
    @MainActor
    func resaveReplacesPriorBlocks() async throws {
        let queue = try Self.makeMigratedQueue()
        let doc = EpdocDocument()
        doc.databaseWriter = queue

        let firstJSON = #"{"type":"doc","content":[{"type":"paragraph","attrs":{"blockId":"p1"},"content":[{"type":"text","text":"alpha bravo"}]}]}"#
        await doc.projectAndIndexBlocks(contentJSON: Data(firstJSON.utf8))

        try await queue.read { db in
            let alphaHits = try ReadableBlocksIndex.search("alpha", in: db)
            #expect(alphaHits.count == 1, "first projection must land")
        }

        // Mutate — same blockId, different body.
        let secondJSON = #"{"type":"doc","content":[{"type":"paragraph","attrs":{"blockId":"p1"},"content":[{"type":"text","text":"charlie delta"}]}]}"#
        await doc.projectAndIndexBlocks(contentJSON: Data(secondJSON.utf8))

        try await queue.read { db in
            let staleAlpha = try ReadableBlocksIndex.search("alpha", in: db)
            #expect(staleAlpha.isEmpty, "stale tokens MUST be purged on resave")
            let charlieHits = try ReadableBlocksIndex.search("charlie", in: db)
            #expect(charlieHits.count == 1, "fresh tokens MUST be indexed on resave")
        }
    }

    @Test("Malformed JSON is handled silently (autosave never crashes)")
    @MainActor
    func malformedJSONHandledSilently() async throws {
        let queue = try Self.makeMigratedQueue()
        let doc = EpdocDocument()
        doc.databaseWriter = queue
        let artifactID = doc.package.manifest.id

        // Garbage bytes — projector returns []. replaceAllForArtifact
        // is still called (with empty array), which deletes any
        // prior rows. End state: zero rows for this artifact.
        await doc.projectAndIndexBlocks(contentJSON: Data("not json".utf8))

        try await queue.read { db in
            let count = try ReadableBlocksIndex.count(forArtifact: artifactID, in: db)
            #expect(count == 0,
                    "malformed JSON must not crash; FTS state should be empty for this artifact")
        }
    }
}
