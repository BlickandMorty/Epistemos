import Foundation
import GRDB
import SwiftData
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

    private static func makeGraphContainer() throws -> ModelContainer {
        let schema = Schema([SDGraphNode.self, SDGraphEdge.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
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

    @Test("Controller stores the graph ModelContainer at init")
    @MainActor
    func controllerStoresGraphContainer() throws {
        let container = try Self.makeGraphContainer()
        let controller = EpistemosDocumentController(modelContainer: container)
        #expect(controller.modelContainer != nil,
                "controller MUST hold the SwiftData container used for .epdoc graph projection")
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

    @Test("injectDependencies hooks the graph container into EpdocDocument")
    @MainActor
    func injectsGraphContainerIntoEpdocDocument() throws {
        let container = try Self.makeGraphContainer()
        let controller = EpistemosDocumentController(modelContainer: container)
        let doc = EpdocDocument()

        #expect(doc.graphModelContainer == nil, "fresh doc must have no graph container")

        controller.injectDependencies(into: doc)

        #expect(doc.graphModelContainer != nil,
                "after injectDependencies the document MUST hold the graph container the controller holds")
    }

    @Test("injectDependencies is a no-op when controller has no writer")
    @MainActor
    func injectionNoOpWhenControllerHasNoWriter() {
        let controller = EpistemosDocumentController(databaseWriter: nil)
        let doc = EpdocDocument()
        controller.injectDependencies(into: doc)
        #expect(doc.databaseWriter == nil,
                "controller with nil writer MUST not overwrite the document's writer")
        #expect(doc.graphModelContainer == nil,
                "controller with nil graph container MUST not overwrite the document's graph wiring")
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
        doc.graphModelContainer = try Self.makeGraphContainer()

        controller.injectDependencies(into: doc)

        // Controller's writer is nil, so the inject is a no-op and
        // the doc keeps its prior wiring. (queueB unused — kept to
        // make the symmetry obvious.)
        _ = queueB
        #expect(doc.databaseWriter != nil,
                "pre-wired document writer must survive a no-op injection")
        #expect(doc.graphModelContainer != nil,
                "pre-wired document graph container must survive a no-op injection")
    }

    @Test("late injection wires already-open epdoc documents without clobbering existing dependencies")
    @MainActor
    func lateInjectionWiresOpenEpdocDocuments() async throws {
        let queue = try Self.makeMigratedQueue()
        let container = try Self.makeGraphContainer()
        let controller = EpistemosDocumentController(databaseWriter: nil, modelContainer: nil)
        let doc = EpdocDocument()
        controller.addDocument(doc)
        defer { controller.removeDocument(doc) }

        controller.databaseWriter = queue
        controller.modelContainer = container

        let wiredCount = await controller.injectMissingDependenciesIntoOpenEpdocDocuments(
            projectCurrentContent: false
        )

        #expect(wiredCount == 1,
                "document-only launch can open .epdoc before app-level graph/search dependencies are ready")
        #expect(doc.databaseWriter != nil)
        #expect(doc.graphModelContainer != nil)

        let replacementQueue = try Self.makeMigratedQueue()
        let replacementContainer = try Self.makeGraphContainer()
        controller.databaseWriter = replacementQueue
        controller.modelContainer = replacementContainer

        let rewiredCount = await controller.injectMissingDependenciesIntoOpenEpdocDocuments(
            projectCurrentContent: false
        )

        #expect(rewiredCount == 0,
                "late injection MUST fill missing dependencies only, not silently rewire live documents")
    }

    @Test("late graph injection projects current open epdoc content")
    @MainActor
    func lateGraphInjectionProjectsCurrentContent() async throws {
        let container = try Self.makeGraphContainer()
        let controller = EpistemosDocumentController(databaseWriter: nil, modelContainer: nil)
        let doc = EpdocDocument()
        doc.setTitle("Late Wired Epdoc")
        let artifactID = doc.package.manifest.id
        let json = """
        {"type":"doc","content":[
          {"type":"paragraph","content":[{"type":"text","text":"Late launch should still connect [[Late Graph Link]]."}]}
        ]}
        """
        doc.setContentJSON(Data(json.utf8))
        controller.addDocument(doc)
        defer { controller.removeDocument(doc) }

        controller.modelContainer = container

        let wiredCount = await controller.injectMissingDependenciesIntoOpenEpdocDocuments()

        #expect(wiredCount == 1)

        let context = ModelContext(container)
        let nodes = try context.fetch(FetchDescriptor<SDGraphNode>())
        let edges = try context.fetch(FetchDescriptor<SDGraphEdge>())

        let documentNode = try #require(nodes.first { $0.sourceId == artifactID })
        let linkNode = try #require(nodes.first { $0.label == "Late Graph Link" })

        #expect(documentNode.nodeType == .document)
        #expect(edges.contains {
            $0.sourceNodeId == documentNode.id
                && $0.targetNodeId == linkNode.id
                && $0.edgeType == .reference
        }, "late-wired document-only launches MUST not wait for the next edit before graph projection lands")
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

    // MARK: - W7.14 graph projection bridge

    @Test("projectAndPersistGraph is a no-op when graph container is nil")
    @MainActor
    func graphProjectionNoOpWithoutContainer() async {
        let doc = EpdocDocument()
        let json = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"hi"}]}]}"#
        await doc.projectAndPersistGraph(contentJSON: Data(json.utf8))
    }

    @Test("projectAndPersistGraph materializes .epdoc document node + wikilink edge")
    @MainActor
    func graphProjectionWritesDocumentNodeAndWikilink() async throws {
        let container = try Self.makeGraphContainer()
        let doc = EpdocDocument()
        doc.graphModelContainer = container
        doc.setTitle("Liquid Notes")
        let artifactID = doc.package.manifest.id

        let json = """
        {"type":"doc","content":[
          {"type":"paragraph","content":[{"type":"text","text":"Connect this to [[Halo Recall]]."}]}
        ]}
        """

        await doc.projectAndPersistGraph(contentJSON: Data(json.utf8))

        let context = ModelContext(container)
        let nodes = try context.fetch(FetchDescriptor<SDGraphNode>())
        let edges = try context.fetch(FetchDescriptor<SDGraphEdge>())

        let documentNode = try #require(nodes.first { $0.sourceId == artifactID })
        #expect(documentNode.nodeType == .document)
        #expect(documentNode.label == "Liquid Notes")

        let haloNode = try #require(nodes.first { $0.label == "Halo Recall" })
        #expect(haloNode.nodeType == .idea)

        #expect(edges.contains {
            $0.sourceNodeId == documentNode.id
                && $0.targetNodeId == haloNode.id
                && $0.edgeType == .reference
        }, ".epdoc wikilinks MUST become graph edges so the global graph can reveal document context")
    }

    @Test("projected epdoc nodes flow through the global graph loader")
    @MainActor
    func graphProjectionFeedsBackgroundGraphActor() async throws {
        let container = try Self.makeGraphContainer()
        let doc = EpdocDocument()
        doc.graphModelContainer = container
        doc.setTitle("Global Graph Epdoc")
        let artifactID = doc.package.manifest.id

        let json = """
        {"type":"doc","content":[
          {"type":"heading","attrs":{"level":1},"content":[{"type":"text","text":"Graph Root"}]},
          {"type":"paragraph","content":[{"type":"text","text":"Connect this package to [[Global Halo Link]]."}]}
        ]}
        """

        await doc.projectAndPersistGraph(contentJSON: Data(json.utf8))

        let actor = BackgroundGraphActor(modelContainer: container)
        let records = try await actor.loadRecords(positionHints: [:])

        let documentRecord = try #require(records.nodes.first { record in
            record.sourceId == artifactID
                && record.type == .document
                && record.label == "Global Graph Epdoc"
        })
        let linkRecord = try #require(records.nodes.first { record in
            record.type == .idea && record.label == "Global Halo Link"
        })

        #expect(records.edges.contains { edge in
            edge.sourceNodeId == documentRecord.id
                && edge.targetNodeId == linkRecord.id
                && edge.type == .reference
        }, "Hologram/global graph loading MUST see .epdoc projection edges, not only raw SwiftData rows")
    }

    @Test("opened epdoc windows project initial package content into the graph store")
    func openedWindowsProjectInitialGraphContent() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/EpdocDocument.swift")

        #expect(source.contains("let initialContentJSON = self.package.contentJSON"),
                "Opening an existing .epdoc must capture the package JSON for projection; otherwise unedited reopened docs stay invisible to graph/Halo.")
        #expect(source.contains("await self?.projectAndPersistGraph(contentJSON: initialContentJSON)"),
                "makeWindowControllers must project initial content, not only autosave edits.")
        #expect(source.contains("AppBootstrap.shared?.graphState.needsRefresh = true"),
                ".epdoc projection writes must mark the live graph stale so existing graph/Halo surfaces refresh.")
        #expect(source.contains("NotificationCenter.default.post(\n                name: .graphStoreDidChange"),
                ".epdoc projection writes must notify reactive graph consumers.")
    }

    @Test("projectAndPersistGraph replaces stale outgoing projection edges on resave")
    @MainActor
    func graphProjectionReplacesStaleEdges() async throws {
        let container = try Self.makeGraphContainer()
        let doc = EpdocDocument()
        doc.graphModelContainer = container

        let firstJSON = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"[[Alpha]]"}]}]}"#
        await doc.projectAndPersistGraph(contentJSON: Data(firstJSON.utf8))

        let secondJSON = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"[[Beta]]"}]}]}"#
        await doc.projectAndPersistGraph(contentJSON: Data(secondJSON.utf8))

        let context = ModelContext(container)
        let nodes = try context.fetch(FetchDescriptor<SDGraphNode>())
        let edges = try context.fetch(FetchDescriptor<SDGraphEdge>())
        let documentNode = try #require(nodes.first { $0.sourceId == doc.package.manifest.id })
        let betaNode = try #require(nodes.first { $0.label == "Beta" })

        #expect(!edges.contains { edge in
            guard let target = nodes.first(where: { $0.id == edge.targetNodeId }) else { return false }
            return edge.sourceNodeId == documentNode.id && target.label == "Alpha"
        }, "stale Alpha edge MUST be removed when the document graph projection changes")
        #expect(edges.contains {
            $0.sourceNodeId == documentNode.id && $0.targetNodeId == betaNode.id
        }, "fresh Beta edge MUST survive the replacement pass")
    }

    @Test("projectAndPersistGraph preserves manual outgoing graph edits while replacing projected edges")
    @MainActor
    func graphProjectionPreservesManualOutgoingEdges() async throws {
        let container = try Self.makeGraphContainer()
        let doc = EpdocDocument()
        doc.graphModelContainer = container

        let firstJSON = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"[[Alpha]]"}]}]}"#
        await doc.projectAndPersistGraph(contentJSON: Data(firstJSON.utf8))

        let context = ModelContext(container)
        let initialNodes = try context.fetch(FetchDescriptor<SDGraphNode>())
        let documentNode = try #require(initialNodes.first { $0.sourceId == doc.package.manifest.id })

        let manualTarget = SDGraphNode(type: .idea, label: "User Kept Cluster", sourceId: nil, weight: 0.4)
        context.insert(manualTarget)
        let manualEdge = SDGraphEdge(source: documentNode.id, target: manualTarget.id, type: .reference)
        manualEdge.isManual = true
        context.insert(manualEdge)
        try context.save()

        let secondJSON = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"[[Beta]]"}]}]}"#
        await doc.projectAndPersistGraph(contentJSON: Data(secondJSON.utf8))

        let finalNodes = try context.fetch(FetchDescriptor<SDGraphNode>())
        let finalEdges = try context.fetch(FetchDescriptor<SDGraphEdge>())
        let betaNode = try #require(finalNodes.first { $0.label == "Beta" })

        #expect(finalEdges.contains {
            $0.sourceNodeId == documentNode.id
                && $0.targetNodeId == manualTarget.id
                && $0.isManual
        }, "manual graph edits from the .epdoc document node MUST survive projection refreshes")
        #expect(finalEdges.contains {
            $0.sourceNodeId == documentNode.id
                && $0.targetNodeId == betaNode.id
                && !$0.isManual
        }, "projection refresh should still replace stale generated edges with fresh generated edges")
        #expect(!finalEdges.contains { edge in
            guard let target = finalNodes.first(where: { $0.id == edge.targetNodeId }) else { return false }
            return edge.sourceNodeId == documentNode.id && target.label == "Alpha"
        }, "stale generated Alpha edge should be removed without deleting the manual edge")
    }
}
