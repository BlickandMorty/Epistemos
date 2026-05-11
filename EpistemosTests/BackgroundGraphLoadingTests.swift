import Testing
import SwiftData
@testable import Epistemos

// MARK: - Audit W1.8: Background Graph Loading

@Suite("Audit W1.8 — Background Graph Loading")
struct BackgroundGraphLoadingTests {

    // MARK: - Helpers

    @MainActor
    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SDGraphNode.self, SDGraphEdge.self, SDPage.self, SDFolder.self,
            SDChat.self, SDBlock.self, SDMessage.self, SDPageVersion.self,
            configurations: config
        )
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }

    // MARK: - loadFromRecords

    @Test("loadFromRecords populates store from Sendable records")
    @MainActor
    func loadFromRecordsPopulatesStore() {
        let store = GraphStore()

        let nodes = [
            GraphNodeRecord(
                id: "n1", type: .note, label: "Note 1", sourceId: "src-1",
                metadata: GraphNodeMetadata(), weight: 1.0, createdAt: .now,
                position: .zero, velocity: .zero
            ),
            GraphNodeRecord(
                id: "n2", type: .idea, label: "Idea 1", sourceId: nil,
                metadata: GraphNodeMetadata(), weight: 2.0, createdAt: .now,
                position: SIMD2(100, 200), velocity: .zero
            ),
        ]
        let edges = [
            GraphEdgeRecord(
                id: "e1", sourceNodeId: "n1", targetNodeId: "n2",
                type: .reference, weight: 1.0, createdAt: .now
            ),
        ]

        store.loadFromRecords(nodeRecords: nodes, edgeRecords: edges)

        #expect(store.nodeCount == 2)
        #expect(store.edgeCount == 1)
        #expect(store.nodes["n1"]?.label == "Note 1")
        #expect(store.nodes["n2"]?.position == SIMD2(100, 200))
    }

    @Test("loadFromRecords clears previous state")
    @MainActor
    func loadFromRecordsClearsPrevious() {
        let store = GraphStore()

        // First load
        let nodes1 = [
            GraphNodeRecord(
                id: "old", type: .note, label: "Old", sourceId: nil,
                metadata: GraphNodeMetadata(), weight: 1.0, createdAt: .now,
                position: .zero, velocity: .zero
            ),
        ]
        store.loadFromRecords(nodeRecords: nodes1, edgeRecords: [])
        #expect(store.nodeCount == 1)

        // Second load should replace
        let nodes2 = [
            GraphNodeRecord(
                id: "new1", type: .note, label: "New 1", sourceId: nil,
                metadata: GraphNodeMetadata(), weight: 1.0, createdAt: .now,
                position: .zero, velocity: .zero
            ),
            GraphNodeRecord(
                id: "new2", type: .idea, label: "New 2", sourceId: nil,
                metadata: GraphNodeMetadata(), weight: 1.0, createdAt: .now,
                position: .zero, velocity: .zero
            ),
        ]
        store.loadFromRecords(nodeRecords: nodes2, edgeRecords: [])

        #expect(store.nodeCount == 2)
        #expect(store.nodes["old"] == nil)
        #expect(store.nodes["new1"] != nil)
        #expect(store.nodes["new2"] != nil)
    }

    @Test("loadFromRecords skips edges with missing endpoints")
    @MainActor
    func loadFromRecordsSkipsDanglingEdges() {
        let store = GraphStore()
        let nodes = [
            GraphNodeRecord(
                id: "n1", type: .note, label: "N1", sourceId: nil,
                metadata: GraphNodeMetadata(), weight: 1.0, createdAt: .now,
                position: .zero, velocity: .zero
            ),
        ]
        // Edge referencing non-existent "n2"
        let edges = [
            GraphEdgeRecord(
                id: "e1", sourceNodeId: "n1", targetNodeId: "n2",
                type: .reference, weight: 1.0, createdAt: .now
            ),
        ]

        store.loadFromRecords(nodeRecords: nodes, edgeRecords: edges)

        #expect(store.nodeCount == 1)
        #expect(store.edgeCount == 0)
    }

    // MARK: - BackgroundGraphActor

    @Test("BackgroundGraphActor loads records from SwiftData on background thread")
    @MainActor
    func backgroundActorLoadsRecords() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        // Seed graph data
        let node1 = SDGraphNode(type: .note, label: "Alpha", sourceId: "p1")
        let node2 = SDGraphNode(type: .source, label: "Beta", sourceId: "s1")
        context.insert(node1)
        context.insert(node2)
        context.insert(SDGraphEdge(source: node1.id, target: node2.id, type: .reference))
        try context.save()

        // Load via background actor
        let actor = BackgroundGraphActor(modelContainer: container)
        let records = try await actor.loadRecords(positionHints: [:])

        #expect(records.nodes.count == 1)
        #expect(records.edges.isEmpty)

        // Verify node data was extracted correctly
        let alpha = records.nodes.first { $0.label == "Alpha" }
        #expect(alpha != nil)
        #expect(alpha?.type == .note)
        #expect(alpha?.sourceId == "p1")
        #expect(records.nodes.allSatisfy { $0.type != .source && $0.type != .quote && $0.type != .tag })
    }

    @Test("BackgroundGraphActor applies position hints")
    @MainActor
    func backgroundActorAppliesHints() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let node = SDGraphNode(type: .note, label: "Test", sourceId: nil)
        context.insert(node)
        try context.save()

        let expectedPos = SIMD2<Float>(42, 99)
        let actor = BackgroundGraphActor(modelContainer: container)
        let records = try await actor.loadRecords(positionHints: [node.id: expectedPos])

        #expect(records.nodes.count == 1)
        #expect(records.nodes[0].position == expectedPos)
    }

    @Test("BackgroundGraphActor returns empty for empty database")
    @MainActor
    func backgroundActorEmptyDatabase() async throws {
        let container = try makeTestContainer()
        let actor = BackgroundGraphActor(modelContainer: container)
        let records = try await actor.loadRecords(positionHints: [:])

        #expect(records.nodes.isEmpty)
        #expect(records.edges.isEmpty)
    }

    // MARK: - Async loadGraph integration

    @Test("async loadGraph populates store from background")
    @MainActor
    func asyncLoadGraphPopulatesStore() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        // Seed some nodes and edges
        let n1 = SDGraphNode(type: .note, label: "Page One", sourceId: "p1")
        let n2 = SDGraphNode(type: .source, label: "Swift Source", sourceId: "src-swift")
        context.insert(n1)
        context.insert(n2)
        context.insert(SDGraphEdge(source: n1.id, target: n2.id, type: .reference))
        try context.save()

        let graphState = GraphState()
        await graphState.loadGraph(container: container)

        #expect(graphState.isLoaded)
        #expect(graphState.store.nodeCount == 1)
        #expect(graphState.store.edgeCount == 0)
        #expect(graphState.graphDataVersion == 1)
    }

    @Test("async loadGraph rebuilds structural graph when persisted graph is empty")
    @MainActor
    func asyncLoadGraphBuildsStructuralGraphWhenStoreIsEmpty() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let page = SDPage(title: "Cold Open Note")
        context.insert(page)
        try context.save()

        let graphState = GraphState()
        await graphState.loadGraph(container: container)

        #expect(graphState.isLoaded)
        #expect(graphState.store.nodeCount == 1)
        #expect(graphState.store.nodes.values.first?.label == "Cold Open Note")
        #expect(graphState.graphDataVersion == 1)
    }

    @Test("concurrent async loadGraph callers coalesce to one recommit")
    @MainActor
    func concurrentAsyncLoadGraphCallsCoalesce() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let page = SDPage(title: "Concurrent Graph Load")
        context.insert(page)
        try context.save()

        let graphState = GraphState()

        async let first: Void = graphState.loadGraph(container: container)
        async let second: Void = graphState.loadGraph(container: container)
        _ = await (first, second)

        #expect(graphState.isLoaded)
        #expect(graphState.store.nodeCount == 1)
        #expect(graphState.graphDataVersion == 1)
    }

    @Test("fragile graph first-open wiring keeps async bootstrap and recommit hooks intact")
    func fragileGraphFirstOpenWiringKeepsAsyncBootstrapAndRecommitHooksIntact() throws {
        let controllerSource = try loadRepoTextFile("Epistemos/Views/Graph/HologramController.swift")
        let graphStateSource = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let graphViewSource = try loadRepoTextFile("Epistemos/Views/Graph/MetalGraphView.swift")

        #expect(controllerSource.contains("if autoLoadGraph, !hasActiveVault {\n            graphState.resetForVaultLifecycle()\n        }"),
                "Opening the graph with no active vault must leave the graph empty instead of rebuilding stale local records.")
        #expect(controllerSource.contains("if autoLoadGraph, hasActiveVault, !graphState.isLoaded, let modelContainer {"))
        #expect(controllerSource.contains("Task(priority: .utility) {"))
        #expect(controllerSource.contains("graphState.shouldSnapNextGlobalRecommitCamera = true\n            Task(priority: .utility)"),
                "First graph open loads persisted data asynchronously; without a snap request, .epdoc artifact graphs can load off-camera until the user searches.")
        #expect(controllerSource.contains("await graphState.loadGraph(container: modelContainer)"))
        #expect(controllerSource.contains("overlay = HologramOverlay("))
        #expect(controllerSource.contains("if autoLoadGraph, hasActiveVault, needsRefresh, let modelContainer {"))
        #expect(controllerSource.contains("let refreshedIncrementally = await graphState.refreshStructuralDataAsync(container: modelContainer)"))
        #expect(controllerSource.contains("if !refreshedIncrementally {"))
        #expect(controllerSource.contains("graphState.shouldSnapNextGlobalRecommitCamera = true"))
        #expect(controllerSource.contains("graphState.requestRecommit()"))

        #expect(graphStateSource.contains("guard !isLoaded, !isLoadingGraph else { return }"))
        #expect(graphStateSource.contains("store.loadFromRecords(nodeRecords: records.nodes, edgeRecords: records.edges)"))
        #expect(graphStateSource.contains("if store.nodeCount == 0, !isBuildingStructural {"))
        #expect(graphStateSource.contains("_ = await refreshStructuralDataAsync(container: container)"))
        #expect(graphStateSource.contains("if isLoaded {"))
        #expect(graphStateSource.contains("requestRecommit()"))

        #expect(graphViewSource.contains("if let graphState, lastGraphDataVersion != graphState.graphDataVersion {"))
        #expect(graphViewSource.contains("graph_engine_snap_camera_to_fit(engine)"))
        #expect(graphViewSource.contains("if window != nil, !isCommitted, graphState?.isLoaded == true {"))
    }

    @Test("document-launched graph command has a configured hologram controller")
    func documentLaunchedGraphCommandHasConfiguredHologramController() throws {
        let appSource = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let controllerSource = try loadRepoTextFile("Epistemos/Views/Graph/HologramController.swift")
        let didFinish = try #require(appSource.range(of: "func applicationDidFinishLaunching"))
        let didFinishBody = appSource[didFinish.lowerBound...]

        #expect(didFinishBody.contains("HologramController.shared.setup("),
                "Opening a .epdoc directly may skip the SwiftUI home scene; applicationDidFinishLaunching must still configure the graph overlay command.")
        #expect(didFinishBody.contains("installKnowledgeGraphMenuFallback()"),
                "NSDocument .epdoc windows need a native View-menu fallback because WindowGroup SwiftUI commands can appear without routing through document-only launches.")
        #expect(appSource.contains("private func installKnowledgeGraphMenuFallback()"),
                "The Knowledge Graph menu fallback must stay explicit and native instead of depending on an inactive WindowGroup command responder.")
        #expect(appSource.contains("item.target = self\n        item.action = #selector(toggleKnowledgeGraphFromMenu(_:))"),
                "The fallback should rebind the existing View menu item, not create a duplicate menu command.")
        #expect(appSource.contains("@objc private func toggleKnowledgeGraphFromMenu(_ sender: NSMenuItem) {\n        HologramController.shared.toggle()\n    }"),
                "The native Knowledge Graph fallback must open the full global graph; document focus belongs to the separate reveal action so users do not think graph nodes disappeared.")
        #expect(appSource.contains("Reveal Current Document in Graph"),
                "The .epdoc artifact reveal affordance should stay available as an explicit action, not overload the global Knowledge Graph command.")
        #expect(appSource.contains("(NSApp.delegate as? EpistemosAppDelegate)?\n                    .revealCurrentDocumentInKnowledgeGraph(nil)"),
                "The SwiftUI View menu must expose the document reveal action too; AppKit fallback insertion alone is too fragile at runtime.")
        #expect(appSource.contains("if let revealItem = viewMenu.items.first(where: { $0.title == \"Reveal Current Document in Graph\" })"),
                "The AppKit fallback should rebind the SwiftUI reveal menu item when it already exists, not leave it as a generic menuAction.")
        #expect(appSource.contains("revealItem.action = #selector(revealCurrentDocumentInKnowledgeGraph(_:))"),
                "The visible reveal item must route to the concrete AppKit selector in document-launched windows.")
        #expect(appSource.contains(".revealCurrentDocumentInKnowledgeGraph(nil)"),
                "The SwiftUI reveal command should still dispatch through the separate AppKit document action.")
        #expect(appSource.contains("@objc func revealCurrentDocumentInKnowledgeGraph(_ sender: Any?)"),
                "The focused .epdoc reveal path should remain explicit and test-pinned.")
        #expect(appSource.contains("HologramController.shared.revealDocument(epdoc.package.manifest.id)"),
                "The explicit document reveal action should focus the active .epdoc artifact.")
        #expect(appSource.contains("private func activeEpdocDocument() -> EpdocDocument?"),
                "The explicit document reveal action should resolve the active .epdoc through AppKit document/window state, not a global singleton side channel.")
        #expect(appSource.contains("let openEpdocs = NSDocumentController.shared.documents"),
                "The active .epdoc resolver should inspect AppKit's open document list when currentDocument is unavailable during menu dispatch.")
        #expect(appSource.contains("return window.isKeyWindow || window.isMainWindow"),
                "The active .epdoc resolver needs a key/main-window fallback because NSDocumentController.currentDocument can lag during direct document launches.")
        #expect(appSource.contains("return openEpdocs.count == 1 ? openEpdocs[0] : nil"),
                "Direct .epdoc launches commonly have exactly one package open; the reveal action should still find that document if AppKit has no key/main document yet.")
        #expect(controllerSource.contains("func toggle() {\n        ensureConfiguredFromSharedBootstrap()"),
                "The menu command must late-bind the graph overlay when launch timing skips the home scene setup path.")
        #expect(controllerSource.contains("func revealDocument(_ documentSourceId: String)"),
                ".epdoc graph launches need a document artifact reveal path, separate from legacy note revealPage.")
        #expect(controllerSource.contains("ensureOverlay(autoLoadGraph: false)"),
                "Document reveals should own graph loading so they can center the artifact after persisted records are available.")
        #expect(controllerSource.contains("await self.loadGraphForDocumentRevealIfNeeded()"),
                "Document reveals must wait for graph records before resolving the .document node.")
        #expect(controllerSource.contains("graphState.store.node(bySourceId: documentSourceId, type: .document)"),
                ".epdoc graph focus must target the persisted .document artifact, not legacy .note nodes.")
        #expect(controllerSource.contains("graphState.focusOnNode(node.id, depth: GraphOverlayModePolicy.focusDepth)"),
                "The document graph command should focus the artifact plus its connected concepts so users do not see an unrelated global graph.")
        #expect(controllerSource.contains("private func ensureConfiguredFromSharedBootstrap()"),
                "Document-only launches need a fallback setup path owned by HologramController, not duplicate command-menu wiring.")
        #expect(controllerSource.contains("guard graphState == nil, let bootstrap = AppBootstrap.shared else { return }"),
                "Late binding should only run when the overlay controller is actually unconfigured.")
        #expect(controllerSource.contains("if let screenObserver {\n            NotificationCenter.default.removeObserver(screenObserver)\n        }\n        observeScreenChanges()"),
                "Graph overlay setup is called from both app delegate and home scene, so screen observation must stay idempotent.")
    }

    @Test("Hologram sidebar lists graph-visible app artifacts")
    @MainActor
    func hologramSidebarListsGraphVisibleAppArtifacts() {
        let store = GraphStore()
        let note = GraphNodeRecord(
            id: "note-1",
            type: .note,
            label: "Notebook Note",
            sourceId: "note-source",
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        )
        let document = GraphNodeRecord(
            id: "document-1",
            type: .document,
            label: "Codex Loader Gate Smoke",
            sourceId: "epdoc-source",
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        )

        store.loadFromRecords(nodeRecords: [document, note], edgeRecords: [])

        let snapshot = HologramSidebarNotesTreeBuilder.build(store: store)

        #expect(snapshot.noteById["note-1"]?.label == "Notebook Note")
        #expect(snapshot.looseNoteIds == ["note-1"])
        #expect(snapshot.artifactById["document-1"]?.type == .document)
        #expect(snapshot.artifactById["document-1"]?.label == "Codex Loader Gate Smoke")
        #expect(snapshot.looseArtifactIds == ["document-1"])
    }

    @Test("Hologram sidebar source keeps artifact section wired")
    func hologramSidebarSourceKeepsArtifactSectionWired() throws {
        let sidebarSource = try loadRepoTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")

        #expect(sidebarSource.contains("let artifactById: [String: GraphNodeRecord]"),
                "The Hologram sidebar should index graph-visible .epdoc and app-level artifact nodes, not only legacy notes.")
        #expect(sidebarSource.contains("let looseArtifactIds: [String]"),
                "Standalone .epdoc artifacts should appear even when they are not nested under a folder.")
        #expect(sidebarSource.contains("let artifactTypes = Set(GraphNodeType.appLevelCases)"),
                "Artifact sidebar visibility should use the canonical app-level graph cases instead of a parallel hard-coded type list.")
        #expect(sidebarSource.contains("sectionHeader(\"Artifacts\")"),
                "The Notes tab must distinguish app artifacts from legacy note rows rather than showing an empty graph state.")
        #expect(sidebarSource.contains("snapshot.rootFolderIds.isEmpty\n                    && snapshot.looseNoteIds.isEmpty\n                    && snapshot.looseArtifactIds.isEmpty"),
                "The empty state should only appear when notes and app artifacts are both absent.")
        #expect(sidebarSource.contains("emptyState(\"No files in graph\", icon: \"doc.text.magnifyingglass\")"),
                "A graph containing only app artifacts should not say 'No notes in graph'.")
    }

    // MARK: - Edge Cases (Gate 4)

    @Test("BackgroundGraphActor handles Unicode labels (emoji, CJK, RTL)")
    @MainActor
    func unicodeLabels() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let emoji = SDGraphNode(type: .note, label: "🧠 Brain Dump 🔥", sourceId: nil)
        let cjk = SDGraphNode(type: .note, label: "知識グラフ", sourceId: nil)
        let rtl = SDGraphNode(type: .note, label: "مخطط المعرفة", sourceId: nil)
        let zwj = SDGraphNode(type: .note, label: "👨‍👩‍👧‍👦 Family", sourceId: nil)
        context.insert(emoji)
        context.insert(cjk)
        context.insert(rtl)
        context.insert(zwj)
        try context.save()

        let actor = BackgroundGraphActor(modelContainer: container)
        let records = try await actor.loadRecords(positionHints: [:])

        #expect(records.nodes.count == 4)
        let labels = Set(records.nodes.map(\.label))
        #expect(labels.contains("🧠 Brain Dump 🔥"))
        #expect(labels.contains("知識グラフ"))
        #expect(labels.contains("مخطط المعرفة"))
        #expect(labels.contains("👨‍👩‍👧‍👦 Family"))
    }

    @Test("BackgroundGraphActor skips hidden source and quote graph residue")
    @MainActor
    func backgroundActorSkipsHiddenGraphResidue() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let note = SDGraphNode(type: .note, label: "Visible Note", sourceId: "note-1")
        let source = SDGraphNode(type: .source, label: "Hidden Source", sourceId: "source-1")
        let quote = SDGraphNode(type: .quote, label: "Hidden Quote", sourceId: "quote-1")
        context.insert(note)
        context.insert(source)
        context.insert(quote)
        context.insert(SDGraphEdge(source: note.id, target: source.id, type: .reference))
        context.insert(SDGraphEdge(source: quote.id, target: source.id, type: .quotes))
        try context.save()

        let actor = BackgroundGraphActor(modelContainer: container)
        let records = try await actor.loadRecords(positionHints: [:])

        #expect(records.nodes.map(\.label) == ["Visible Note"])
        #expect(records.edges.isEmpty)
    }

    @Test("loadFromRecords with large node count")
    @MainActor
    func largeNodeCount() {
        let store = GraphStore()
        let count = 5000
        let nodes = (0..<count).map { i in
            GraphNodeRecord(
                id: "n\(i)", type: .note, label: "Node \(i)", sourceId: nil,
                metadata: GraphNodeMetadata(), weight: 1.0, createdAt: .now,
                position: .zero, velocity: .zero
            )
        }
        // Create a chain of edges: n0→n1→n2→...
        let edges = (0..<count - 1).map { i in
            GraphEdgeRecord(
                id: "e\(i)", sourceNodeId: "n\(i)", targetNodeId: "n\(i + 1)",
                type: .reference, weight: 1.0, createdAt: .now
            )
        }

        store.loadFromRecords(nodeRecords: nodes, edgeRecords: edges)

        #expect(store.nodeCount == count)
        #expect(store.edgeCount == count - 1)
        // Spot-check adjacency
        #expect(store.neighbors(of: "n500").count == 2) // n499 and n501
    }

    @Test("BackgroundGraphActor phyllotaxis positions for unhinted nodes")
    @MainActor
    func phyllotaxisPositioning() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        // Insert 3 nodes with no position hints
        for i in 0..<3 {
            context.insert(SDGraphNode(type: .note, label: "N\(i)", sourceId: nil))
        }
        try context.save()

        let actor = BackgroundGraphActor(modelContainer: container)
        let records = try await actor.loadRecords(positionHints: [:])

        #expect(records.nodes.count == 3)
        // First node at index 0: r = 120 * sqrt(0) = 0, so position should be (0, 0)
        let firstNode = records.nodes[0]
        #expect(firstNode.position == SIMD2<Float>(0, 0))
        // Second and third should be at non-zero positions
        #expect(records.nodes[1].position != .zero)
        #expect(records.nodes[2].position != .zero)
        // All positions should be distinct
        #expect(records.nodes[1].position != records.nodes[2].position)
    }
}
