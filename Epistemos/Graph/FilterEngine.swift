import Foundation

// MARK: - FilterEngine
// Manages graph visibility: which node/edge types are shown,
// and focus filtering (show only nodes connected to X).

@MainActor @Observable
final class FilterEngine {

    // MARK: - State

    /// Which node types are currently visible. Starts with all visible types active.
    private(set) var activeNodeTypes: Set<GraphNodeType> = Set(GraphNodeType.visibleCases)

    /// The node ID currently focused on, if any.
    private(set) var focusedNodeId: String?

    /// The set of node IDs connected to the focused node (including itself).
    private(set) var focusedConnected: Set<String>?

    // MARK: - Computed

    /// True if any filter is active (not all types shown, or focused).
    var isFiltered: Bool {
        activeNodeTypes.count != GraphNodeType.visibleCases.count
            || focusedNodeId != nil
    }

    // MARK: - Type Filter Methods

    /// Toggle a node type on or off.
    func toggleType(_ type: GraphNodeType) {
        if activeNodeTypes.contains(type) {
            activeNodeTypes.remove(type)
        } else {
            activeNodeTypes.insert(type)
        }
    }

    /// Reset to showing all node types.
    func showAllTypes() {
        activeNodeTypes = Set(GraphNodeType.visibleCases)
    }

    // MARK: - Focus Methods

    /// Focus on a specific node, showing only it and the provided connected set.
    func focusOn(nodeId: String, connectedSet: Set<String>) {
        focusedNodeId = nodeId
        focusedConnected = connectedSet
    }

    /// Clear focus filtering.
    func clearFocus() {
        focusedNodeId = nil
        focusedConnected = nil
    }

    // MARK: - Visibility Checks

    /// Check whether a node should be visible given all active filters.
    func isNodeVisible(_ node: GraphNodeRecord) -> Bool {
        // 1. Type filter
        guard activeNodeTypes.contains(node.type) else { return false }

        // 2. Focus filter
        if let connected = focusedConnected {
            guard connected.contains(node.id) else { return false }
        }

        return true
    }

    /// Check whether an edge should be visible.
    func isEdgeVisible(
        _ edge: GraphEdgeRecord,
        sourceVisible: Bool,
        targetVisible: Bool
    ) -> Bool {
        sourceVisible && targetVisible
    }

    /// Snapshot the current filter state for background FFI payload building.
    func snapshot() -> GraphFilterSnapshot {
        GraphFilterSnapshot(filter: self)
    }
}
