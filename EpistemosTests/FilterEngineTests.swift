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
}
