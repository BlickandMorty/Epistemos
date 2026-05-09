import Foundation
import SwiftData
import Testing
@testable import Epistemos

@Suite("Vault lifecycle reset", .serialized)
@MainActor
struct VaultLifecycleResetTests {
    @Test("graph lifecycle reset clears visible store, FFI queues, selection, and filters")
    func graphLifecycleResetClearsVisibleStoreAndQueues() {
        let state = GraphState()
        let now = Date()
        let node = GraphNodeRecord(
            id: "old-node",
            type: .note,
            label: "VAULT_A_ONLY",
            sourceId: "old-page",
            metadata: GraphNodeMetadata(),
            weight: 1,
            createdAt: now
        )
        let edge = GraphEdgeRecord(
            id: "old-edge",
            sourceNodeId: "old-node",
            targetNodeId: "old-node",
            type: .reference,
            weight: 1,
            createdAt: now
        )

        state.store.addNode(node)
        state.pendingNodeAdds = [node]
        state.pendingEdgeAdds = [edge]
        state.pendingNodeRemovals = ["old-node"]
        state.pendingEdgeRemovals = [("old-node", "old-node")]
        state.isLoaded = true
        state.hasPlayedEntrance = true
        state.needsRefresh = true
        state.shouldSnapNextGlobalRecommitCamera = true
        state.selectNode("old-node")
        state.selectedNodeScreenPoint = CGPoint(x: 4, y: 8)
        state.filter.searchFilter = "VAULT_A_ONLY"
        state.filter.applySearchFilter(store: state.store)
        state.filter.setModelFilter(profileId: "profile-a", vaultKey: "vault-a")
        state.filter.focusOn(nodeId: "old-node", connectedSet: ["old-node"])
        let previousGraphDataVersion = state.graphDataVersion

        state.resetForVaultLifecycle()

        #expect(state.store.nodeCount == 0)
        #expect(state.store.edgeCount == 0)
        #expect(state.pendingNodeAdds.isEmpty)
        #expect(state.pendingEdgeAdds.isEmpty)
        #expect(state.pendingNodeRemovals.isEmpty)
        #expect(state.pendingEdgeRemovals.isEmpty)
        #expect(!state.isLoaded)
        #expect(!state.hasPlayedEntrance)
        #expect(!state.needsRefresh)
        #expect(state.selectedNodeId == nil)
        #expect(state.selectedNodeScreenPoint == nil)
        #expect(!state.filter.isFiltered)
        #expect(state.graphDataVersion == previousGraphDataVersion + 1)
    }

    @Test("contextual shadows reset detaches stale Halo backend and clears visible hits")
    func contextualShadowsResetDetachesStaleBackendAndHits() {
        let state = ContextualShadowsState(isEnabledOverride: true)
        state.configureShadowSearch(EmptyShadowSearch())
        state.currentResults = [
            ContextualShadowsState.RecallHit(
                id: "old-page",
                title: "VAULT_A_ONLY",
                snippet: "old snippet",
                kind: .note,
                similarity: 0.9,
                source: "shadow"
            )
        ]
        state.isPanelVisible = true
        let previousRevision = state.haloSearchRevision

        state.resetForVaultLifecycle()

        #expect(state.haloSearchService == nil)
        #expect(state.currentResults.isEmpty)
        #expect(!state.isPanelVisible)
        #expect(state.haloSearchRevision == previousRevision + 1)
    }

    @Test("query engine reset clears visible search state and history")
    func queryEngineResetClearsVisibleSearchStateAndHistory() {
        let engine = QueryEngine()
        engine.currentQuery = "VAULT_A_ONLY"
        engine.errorMessage = "old error"
        engine.queryHistory = [
            QueryHistoryEntry(query: "VAULT_A_ONLY", resultCount: 1, timestamp: .now)
        ]

        engine.resetForVaultLifecycle()

        #expect(engine.currentQuery.isEmpty)
        #expect(engine.errorMessage == nil)
        #expect(engine.queryHistory.isEmpty)
    }

    @Test("Reset Everything clears SwiftData rows, managed bodies, and runtime caches")
    func resetEverythingClearsSwiftDataRowsBodiesAndRuntimeCaches() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("vault-lifecycle-reset-\(UUID().uuidString)", isDirectory: true)
        let noteBodiesURL = root.appendingPathComponent("note-bodies", isDirectory: true)
        try FileManager.default.createDirectory(at: noteBodiesURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try await NoteFileStorage.withStorageDirectoryOverrideForTesting(noteBodiesURL, operation: { @MainActor in
            let previousShared = AppBootstrap.shared
            let bootstrap = AppBootstrap()
            AppBootstrap.shared = bootstrap
            defer {
                AppBootstrap.shared = previousShared
            }

            let context = bootstrap.modelContainer.mainContext
            let page = SDPage(title: "VAULT_A_ONLY")
            let block = SDBlock(pageId: page.id, content: "VAULT_A_ONLY", depth: 0, order: 0)
            let chat = SDChat(title: "Old vault chat")
            let message = SDMessage(role: "user", content: "VAULT_A_ONLY")
            message.chat = chat
            let graphNode = SDGraphNode(type: .note, label: "VAULT_A_ONLY", sourceId: page.id)
            let graphEdge = SDGraphEdge(source: graphNode.id, target: graphNode.id, type: .reference)

            context.insert(page)
            context.insert(SDFolder(name: "Old Vault"))
            context.insert(block)
            context.insert(chat)
            context.insert(message)
            context.insert(SDPageVersion(pageId: page.id, title: page.title, body: "VAULT_A_ONLY", wordCount: 1))
            context.insert(SDNoteInsight(pageId: page.id, contentHash: "old"))
            context.insert(graphNode)
            context.insert(graphEdge)
            context.insert(SDWorkspace(name: "Old Workspace", isAutoSave: true))
            context.insert(SDModelProfile())
            try context.save()

            NoteFileStorage.writeBody(pageId: page.id, content: "VAULT_A_ONLY")
            let visibleGraphNode = GraphNodeRecord(
                id: "old-visible-node",
                type: .note,
                label: "VAULT_A_ONLY",
                sourceId: page.id,
                metadata: GraphNodeMetadata(),
                weight: 1,
                createdAt: .now
            )
            bootstrap.graphState.store.addNode(visibleGraphNode)
            bootstrap.queryEngine.currentQuery = "VAULT_A_ONLY"
            bootstrap.queryEngine.queryHistory = [
                QueryHistoryEntry(query: "VAULT_A_ONLY", resultCount: 1, timestamp: .now)
            ]
            bootstrap.contextualShadowsState.configureShadowSearch(EmptyShadowSearch())
            bootstrap.contextualShadowsState.currentResults = [
                ContextualShadowsState.RecallHit(
                    id: page.id,
                    title: "VAULT_A_ONLY",
                    snippet: "old",
                    kind: .note,
                    similarity: 1,
                    source: "shadow"
                )
            ]

            await bootstrap.resetAllData()

            #expect(try modelCount(SDPage.self, in: context) == 0)
            #expect(try modelCount(SDFolder.self, in: context) == 0)
            #expect(try modelCount(SDBlock.self, in: context) == 0)
            #expect(try modelCount(SDChat.self, in: context) == 0)
            #expect(try modelCount(SDMessage.self, in: context) == 0)
            #expect(try modelCount(SDPageVersion.self, in: context) == 0)
            #expect(try modelCount(SDNoteInsight.self, in: context) == 0)
            #expect(try modelCount(SDGraphNode.self, in: context) == 0)
            #expect(try modelCount(SDGraphEdge.self, in: context) == 0)
            #expect(try modelCount(SDWorkspace.self, in: context) == 0)
            #expect(try modelCount(SDModelProfile.self, in: context) == 0)
            #expect(!NoteFileStorage.bodyExists(pageId: page.id))
            #expect(bootstrap.graphState.store.nodeCount == 0)
            #expect(bootstrap.graphState.store.edgeCount == 0)
            #expect(bootstrap.queryEngine.currentQuery.isEmpty)
            #expect(bootstrap.queryEngine.queryHistory.isEmpty)
            #expect(bootstrap.contextualShadowsState.haloSearchService == nil)
            #expect(bootstrap.contextualShadowsState.currentResults.isEmpty)
            #expect(bootstrap.uiState.needsSetup)
            #expect(bootstrap.uiState.activePanel == .home)
        })
    }

    private func modelCount<T: PersistentModel>(_ model: T.Type, in context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<T>()).count
    }
}

private actor EmptyShadowSearch: ShadowSearchServicing {
    func search(text: String, domain: ShadowDomain, limit: Int) async -> [ShadowHit] {
        []
    }
}
