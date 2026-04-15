import Testing
@testable import Epistemos
import Foundation

// MARK: - Graph Workspace Graph Chat Bridge Tests (Phase 7 Step 6)
//
// Step 6 wires the "Ask Graph Chat" context menu item to a typed intent
// event. The graph workspace does not own a second chat session store —
// `askGraphChat` builds a `GraphChatRequest` from the hovered node and
// the current route, then posts it on `.graphChatRequested`. Receivers
// (Agent Command Center, a future GraphChatState) react by prefilling
// their own composer.
//
// `askGraphChat` is @discardableResult and returns the same request it
// posts, so these tests assert on the return value. Verifying that
// NotificationCenter itself delivers the message is NotificationCenter's
// contract, not ours — skipping the observer subscription keeps the
// tests Swift 6 strict-concurrency clean.

@Suite("Graph Workspace — Graph Chat Bridge")
@MainActor
struct GraphWorkspaceGraphChatBridgeTests {

    private func makeNode(
        id: String,
        type: GraphNodeType,
        label: String,
        sourceId: String?
    ) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id,
            type: type,
            label: label,
            sourceId: sourceId,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        )
    }

    @Test("askGraphChat returns a typed request carrying graph + route context")
    func askGraphChatReturnsTypedRequest() {
        let gs = GraphState()
        gs.store.addNode(makeNode(
            id: "graph-node-chat-1",
            type: .note,
            label: "Design Review",
            sourceId: "sdpage-chat-1"
        ))
        gs.openNote("sdpage-chat-1")

        let request = gs.askGraphChat(nodeId: "graph-node-chat-1")

        #expect(request != nil)
        #expect(request?.graphNodeId == "graph-node-chat-1")
        #expect(request?.sourceId == "sdpage-chat-1")
        #expect(request?.nodeType == GraphNodeType.note.rawValue)
        #expect(request?.nodeLabel == "Design Review")
        #expect(request?.route == .note(id: "sdpage-chat-1"))
    }

    @Test("askGraphChat on a missing node returns nil")
    func askGraphChatMissingNodeReturnsNil() {
        let gs = GraphState()
        let returned = gs.askGraphChat(nodeId: "does-not-exist")
        #expect(returned == nil)
    }

    @Test("askGraphChat preserves the current route in the request")
    func askGraphChatCarriesCurrentRoute() {
        let gs = GraphState()
        gs.store.addNode(makeNode(
            id: "folder-node-1",
            type: .folder,
            label: "Projects",
            sourceId: "sdfolder-1"
        ))
        gs.openFolder("sdfolder-1")
        gs.openNote("sdpage-from-folder")

        let request = gs.askGraphChat(nodeId: "folder-node-1")

        #expect(request?.route == .note(id: "sdpage-from-folder"))
        #expect(request?.nodeType == GraphNodeType.folder.rawValue)
    }

    @Test("GraphChatRequest.fromNotification round-trips through userInfo")
    func graphChatRequestRoundTrip() {
        let original = GraphChatRequest(
            graphNodeId: "n1",
            sourceId: "s1",
            nodeType: "note",
            nodeLabel: "Label",
            route: .note(id: "s1")
        )
        let note = Notification(
            name: .graphChatRequested,
            object: nil,
            userInfo: [GraphChatRequest.userInfoKey: original]
        )

        let decoded = GraphChatRequest.fromNotification(note)
        #expect(decoded == original)
    }

    @Test("Metal context menu handler dispatches via graphState.askGraphChat")
    func metalContextMenuDispatchesViaGraphState() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Views/Graph/MetalGraphView.swift"
        )

        #expect(source.contains("contextMenuAskGraphChat"))
        #expect(source.contains("graphState?.askGraphChat(nodeId: id)"))
        #expect(!source.contains("No-op hook for Graph Chat integration"))
    }
}
