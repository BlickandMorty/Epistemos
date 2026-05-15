import Foundation
import Testing
@testable import Epistemos

@Suite("FilterEngine")
@MainActor
struct FilterEngineTests {

    // MARK: - Helpers

    /// Create a minimal node record for testing.
    private func makeNode(
        id: String,
        type: GraphNodeType = .note,
        created: Date = .now
    ) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id,
            type: type,
            label: id,
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: created,
            position: .zero,
            velocity: .zero
        )
    }

    /// Create a minimal edge record for testing.
    private func makeEdge(
        source: String,
        target: String,
        type: GraphEdgeType = .reference
    ) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: "\(source)-\(target)",
            sourceNodeId: source,
            targetNodeId: target,
            type: type,
            weight: 1.0,
            createdAt: .now
        )
    }

    // MARK: - Tests

    @Test("all types visible by default")
    func allTypesVisibleByDefault() {
        let engine = FilterEngine()
        let node = makeNode(id: "n1", type: .note)

        #expect(engine.isNodeVisible(node))
        #expect(!engine.isFiltered)
    }

    @Test("app-level artifact nodes are visible by default")
    func appLevelArtifactNodesVisibleByDefault() {
        let engine = FilterEngine()
        for type in [GraphNodeType.proseNote, .document, .code, .output] {
            #expect(engine.isNodeVisible(makeNode(id: type.rawValue, type: type)),
                    "\(type) must not disappear behind the default graph type filter")
        }
    }

    @Test("toggle type hides and shows")
    func toggleTypeHidesAndShows() {
        let engine = FilterEngine()
        let noteNode = makeNode(id: "n1", type: .note)
        let thinkerNode = makeNode(id: "n2", type: .source)

        // Toggle .note off
        engine.toggleType(.note)
        #expect(!engine.isNodeVisible(noteNode))
        #expect(engine.isNodeVisible(thinkerNode))

        // Toggle .note back on
        engine.toggleType(.note)
        #expect(engine.isNodeVisible(noteNode))
    }

    @Test("set type visibility is idempotent")
    func setTypeVisibilityIsIdempotent() {
        let engine = FilterEngine()
        let folderNode = makeNode(id: "folder", type: .folder)

        // Folder is OFF by default per user direction 2026-05-15.
        // First setType(.folder, isVisible: true) → changes state.
        #expect(!engine.isNodeVisible(folderNode))
        #expect(engine.setType(.folder, isVisible: true))
        #expect(engine.isNodeVisible(folderNode))
        // Setting visible-when-visible is a no-op.
        #expect(!engine.setType(.folder, isVisible: true))
        // Toggling back off.
        #expect(engine.setType(.folder, isVisible: false))
        #expect(!engine.isNodeVisible(folderNode))
        // No-op when already invisible.
        #expect(!engine.setType(.folder, isVisible: false))
    }

    @Test("graph node visibility preferences hide folders without losing content nodes")
    func graphNodeVisibilityPreferencesHideFoldersWithoutLosingContentNodes() {
        let defaults = UserDefaults.standard
        let key = "epistemos.graph.visibleNodeTypes"
        let previous = defaults.object(forKey: key)
        defaults.removeObject(forKey: key)
        defer {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let graph = GraphState()
        graph.applyContentFocusedNodeVisibility()

        #expect(!graph.isNodeTypeVisible(.folder))
        #expect(GraphState.userFilterableNodeTypes == GraphNodeType.visibleCases)
        #expect(graph.isNodeTypeVisible(.note))
        #expect(graph.isNodeTypeVisible(.chat))
        #expect(graph.isNodeTypeVisible(.idea))
        #expect(graph.isNodeTypeVisible(.document))
    }

    @Test("graph node visibility hides selected node without deleting store identity")
    func graphNodeVisibilityHidesSelectedNodeWithoutDeletingStoreIdentity() {
        let defaults = UserDefaults.standard
        let key = "epistemos.graph.visibleNodeTypes"
        let previous = defaults.object(forKey: key)
        defaults.removeObject(forKey: key)
        defer {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let graph = GraphState()
        // Per user direction 2026-05-15, `.folder` is OFF by default —
        // enable it explicitly here so the node is actually selectable
        // before exercising the hide-clears-selection contract.
        graph.setNodeTypeVisibility(.folder, isVisible: true)
        let folder = makeNode(id: "folder", type: .folder)
        graph.store.addNode(folder)
        graph.selectNode(folder.id)

        graph.setNodeTypeVisibility(.folder, isVisible: false)

        #expect(graph.selectedNodeId == nil)
        #expect(graph.store.nodes[folder.id] != nil)
        #expect(!graph.isNodeTypeVisible(.folder))
    }

    @Test("show all types resets filter")
    func showAllTypesResetsFilter() {
        let engine = FilterEngine()
        engine.toggleType(.note)
        #expect(engine.isFiltered)

        engine.showAllTypes()
        #expect(!engine.isFiltered)
    }

    @Test("focus filter limits to connected set")
    func focusFilterLimitsToConnectedSet() {
        let engine = FilterEngine()
        let nodeA = makeNode(id: "a")
        let nodeC = makeNode(id: "c")

        engine.focusOn(nodeId: "center", connectedSet: ["center", "a", "b"])

        #expect(engine.isNodeVisible(nodeA))
        #expect(!engine.isNodeVisible(nodeC))
    }

    @Test("clear focus restores all")
    func clearFocusRestoresAll() {
        let engine = FilterEngine()
        let nodeC = makeNode(id: "c")

        engine.focusOn(nodeId: "center", connectedSet: ["center", "a"])
        #expect(!engine.isNodeVisible(nodeC))

        engine.clearFocus()
        #expect(engine.isNodeVisible(nodeC))
        #expect(!engine.isFiltered)
    }

    @Test("edge visible only if both endpoints visible")
    func edgeVisibleOnlyIfBothEndpointsVisible() {
        let engine = FilterEngine()
        let edge = makeEdge(source: "a", target: "b")

        #expect(engine.isEdgeVisible(edge, sourceVisible: true, targetVisible: true))
        #expect(!engine.isEdgeVisible(edge, sourceVisible: true, targetVisible: false))
        #expect(!engine.isEdgeVisible(edge, sourceVisible: false, targetVisible: true))
        #expect(!engine.isEdgeVisible(edge, sourceVisible: false, targetVisible: false))
    }

    @Test("edge type filter hides toggled-off edge types")
    func edgeTypeFilterHidesDisabledTypes() {
        let engine = FilterEngine()
        let edge = makeEdge(source: "a", target: "b", type: .cites)

        #expect(engine.isEdgeVisible(edge, sourceVisible: true, targetVisible: true))

        engine.toggleEdgeType(.cites)
        #expect(!engine.isEdgeVisible(edge, sourceVisible: true, targetVisible: true))

        engine.showAllEdgeTypes()
        #expect(engine.isEdgeVisible(edge, sourceVisible: true, targetVisible: true))
    }

    @Test("app-level artifact edges are visible by default")
    func appLevelArtifactEdgesVisibleByDefault() {
        let engine = FilterEngine()
        for type in GraphEdgeType.appLevelCases {
            let edge = makeEdge(source: "a", target: "b", type: type)
            #expect(engine.isEdgeVisible(edge, sourceVisible: true, targetVisible: true),
                    "\(type) must not disappear behind the default graph edge filter")
        }
    }

    @Test("agent vault mode excludes disabled source and quote nodes")
    func agentVaultModeExcludesDisabledSourceAndQuoteNodes() {
        let engine = FilterEngine()

        engine.applyAgentVaultMode()

        #expect(engine.activeNodeTypes.contains(.idea))
        #expect(engine.activeNodeTypes.contains(.tag))
        #expect(!engine.activeNodeTypes.contains(.source))
        #expect(!engine.activeNodeTypes.contains(.quote))
    }

    // MARK: - RCA-P1-010 second pass — vault filter visibility (2026-05-13)

    /// Helper for vault-filter tests: nodes carry an explicit
    /// `originVaultKey` so the filter has provenance to check.
    private func makeVaultNode(
        id: String,
        vaultKey: String?
    ) -> GraphNodeRecord {
        var metadata = GraphNodeMetadata()
        metadata.originVaultKey = vaultKey
        return GraphNodeRecord(
            id: id,
            type: .note,
            label: id,
            sourceId: nil,
            metadata: metadata,
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        )
    }

    @Test("vault filter inactive: every node passes regardless of originVaultKey")
    func vaultFilterInactiveAllowsEveryNode() {
        let engine = FilterEngine()
        let alpha = makeVaultNode(id: "alpha", vaultKey: "vault-A")
        let beta = makeVaultNode(id: "beta", vaultKey: "vault-B")
        let orphan = makeVaultNode(id: "orphan", vaultKey: nil)

        #expect(engine.selectedVaultFilter == nil)
        #expect(engine.isNodeVisible(alpha))
        #expect(engine.isNodeVisible(beta))
        #expect(engine.isNodeVisible(orphan))
    }

    @Test("vault filter active + matching key: matched nodes visible")
    func vaultFilterActiveMatchedNodesVisible() {
        let engine = FilterEngine()
        engine.setModelFilter(profileId: "profile-A", vaultKey: "vault-A")
        let alpha = makeVaultNode(id: "alpha", vaultKey: "vault-A")
        #expect(engine.isNodeVisible(alpha),
            "nodes with originVaultKey == selectedVaultFilter must remain visible")
    }

    @Test("vault filter active + mismatched key: node hidden")
    func vaultFilterActiveMismatchHides() {
        let engine = FilterEngine()
        engine.setModelFilter(profileId: "profile-A", vaultKey: "vault-A")
        let beta = makeVaultNode(id: "beta", vaultKey: "vault-B")
        #expect(!engine.isNodeVisible(beta),
            "nodes whose declared originVaultKey doesn't match the filter must be hidden")
    }

    @Test("vault filter active + nil originVaultKey: lenient passthrough")
    func vaultFilterActiveNilOriginPasses() {
        // Lenient nil-passthrough contract — nodes without a declared
        // vault key still pass when a vault filter is active. This
        // prevents the partial-rollout footgun where every node would
        // get hidden the moment a vault filter was selected, before
        // the originVaultKey field was populated at every creation
        // site. See GraphNodeMetadata.originVaultKey doc.
        let engine = FilterEngine()
        engine.setModelFilter(profileId: "profile-A", vaultKey: "vault-A")
        let orphan = makeVaultNode(id: "orphan", vaultKey: nil)
        #expect(engine.isNodeVisible(orphan),
            "nil originVaultKey must pass through vault filter (lenient nil-passthrough)")
    }

    @Test("vault filter clear returns to all-visible state")
    func vaultFilterClearRestoresVisibility() {
        let engine = FilterEngine()
        engine.setModelFilter(profileId: "profile-A", vaultKey: "vault-A")
        let beta = makeVaultNode(id: "beta", vaultKey: "vault-B")
        #expect(!engine.isNodeVisible(beta))

        engine.clearModelFilter()
        #expect(engine.selectedVaultFilter == nil)
        #expect(engine.isNodeVisible(beta),
            "after clearModelFilter, mismatched nodes must be visible again")
    }

    @Test("GraphFilterSnapshot mirrors vault-filter visibility decision")
    func snapshotMirrorsVaultFilter() {
        let engine = FilterEngine()
        engine.setModelFilter(profileId: "profile-A", vaultKey: "vault-A")
        let snapshot = engine.snapshot()

        let alpha = makeVaultNode(id: "alpha", vaultKey: "vault-A")
        let beta = makeVaultNode(id: "beta", vaultKey: "vault-B")
        let orphan = makeVaultNode(id: "orphan", vaultKey: nil)

        // Snapshot's visibility must match the engine's exactly so
        // background-renderer paths return the same answer as the
        // MainActor path.
        #expect(snapshot.isNodeVisible(alpha) == engine.isNodeVisible(alpha))
        #expect(snapshot.isNodeVisible(beta) == engine.isNodeVisible(beta))
        #expect(snapshot.isNodeVisible(orphan) == engine.isNodeVisible(orphan))
    }
}
