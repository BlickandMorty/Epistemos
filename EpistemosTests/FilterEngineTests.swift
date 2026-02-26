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
        target: String
    ) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: "\(source)-\(target)",
            sourceNodeId: source,
            targetNodeId: target,
            type: .wikilink,
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

    @Test("toggle type hides and shows")
    func toggleTypeHidesAndShows() {
        let engine = FilterEngine()
        let noteNode = makeNode(id: "n1", type: .note)
        let thinkerNode = makeNode(id: "n2", type: .thinker)

        // Toggle .note off
        engine.toggleType(.note)
        #expect(!engine.isNodeVisible(noteNode))
        #expect(engine.isNodeVisible(thinkerNode))

        // Toggle .note back on
        engine.toggleType(.note)
        #expect(engine.isNodeVisible(noteNode))
    }

    @Test("show only type isolates one type")
    func showOnlyTypeIsolatesOneType() {
        let engine = FilterEngine()
        let noteNode = makeNode(id: "n1", type: .note)
        let paperNode = makeNode(id: "n2", type: .paper)

        engine.showOnlyType(.paper)
        #expect(!engine.isNodeVisible(noteNode))
        #expect(engine.isNodeVisible(paperNode))
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

    @Test("timeline filter hides future nodes")
    func timelineFilterHidesFutureNodes() {
        let engine = FilterEngine()
        let now = Date()
        let pastNode = makeNode(id: "past", created: now.addingTimeInterval(-3600))
        let futureNode = makeNode(id: "future", created: now.addingTimeInterval(3600))

        engine.setTimelineDate(now)

        #expect(engine.isNodeVisible(pastNode))
        #expect(!engine.isNodeVisible(futureNode))
    }

    @Test("hide node makes it invisible")
    func hideNodeMakesItInvisible() {
        let engine = FilterEngine()
        let node = makeNode(id: "n1", type: .note)

        #expect(engine.isNodeVisible(node))
        engine.hideNode("n1")
        #expect(!engine.isNodeVisible(node))
        #expect(engine.isFiltered)
    }

    @Test("unhide node restores visibility")
    func unhideNodeRestoresVisibility() {
        let engine = FilterEngine()
        let node = makeNode(id: "n1", type: .note)

        engine.hideNode("n1")
        #expect(!engine.isNodeVisible(node))

        engine.unhideNode("n1")
        #expect(engine.isNodeVisible(node))
    }

    @Test("clear hidden restores all hidden nodes")
    func clearHiddenRestoresAll() {
        let engine = FilterEngine()
        let nodeA = makeNode(id: "a", type: .note)
        let nodeB = makeNode(id: "b", type: .thinker)

        engine.hideNode("a")
        engine.hideNode("b")
        #expect(!engine.isNodeVisible(nodeA))
        #expect(!engine.isNodeVisible(nodeB))

        engine.clearHidden()
        #expect(engine.isNodeVisible(nodeA))
        #expect(engine.isNodeVisible(nodeB))
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
}
