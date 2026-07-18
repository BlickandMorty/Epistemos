import Foundation

// Observable selection state for the graph inspector.
@MainActor @Observable
final class NodeInspectorState {
    enum InspectorMode: Hashable {
        case overview
        case editor
    }

    var selectedNodeId: String?
    var selectedNode: GraphNodeRecord?
    var inspectorMode: InspectorMode = .overview

    func selectNode(_ node: GraphNodeRecord?) {
        guard let node else {
            clearSelection()
            return
        }
        guard node.id != selectedNodeId || selectedNode?.id != node.id else { return }

        selectedNodeId = node.id
        selectedNode = node
        inspectorMode = .overview
    }

    func clearSelection() {
        selectedNodeId = nil
        selectedNode = nil
        inspectorMode = .overview
    }
}
