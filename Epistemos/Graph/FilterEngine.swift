import Foundation

// MARK: - FilterEngine
// Manages graph visibility: which node/edge types are shown,
// focus filtering (show only nodes connected to X), and timeline filtering.
// Consumed by the SpriteKit scene to decide which nodes to render each frame.

@MainActor @Observable
final class FilterEngine {

    // MARK: - State

    /// Which node types are currently visible. Starts with all types active.
    private(set) var activeNodeTypes: Set<GraphNodeType> = Set(GraphNodeType.allCases)

    /// The node ID currently focused on, if any.
    private(set) var focusedNodeId: String?

    /// The set of node IDs connected to the focused node (including itself).
    private(set) var focusedConnected: Set<String>?

    /// Individually hidden node IDs (via right-click "Hide This Node").
    private(set) var hiddenNodeIds: Set<String> = []

    /// Timeline cutoff date. Nodes created after this date are hidden.
    private(set) var timelineDate: Date?

    // MARK: - Computed

    /// True if any filter is active (not all types shown, or focused, or timeline set, or nodes hidden).
    var isFiltered: Bool {
        activeNodeTypes.count != GraphNodeType.allCases.count
            || focusedNodeId != nil
            || timelineDate != nil
            || !hiddenNodeIds.isEmpty
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

    /// Explicitly set a node type active or inactive.
    func setTypeActive(_ type: GraphNodeType, active: Bool) {
        if active {
            activeNodeTypes.insert(type)
        } else {
            activeNodeTypes.remove(type)
        }
    }

    /// Reset to showing all node types.
    func showAllTypes() {
        activeNodeTypes = Set(GraphNodeType.allCases)
    }

    /// Show only a single node type, hiding all others.
    func showOnlyType(_ type: GraphNodeType) {
        activeNodeTypes = [type]
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

    // MARK: - Hide Individual Nodes

    /// Hide a single node by ID (right-click "Hide This Node").
    func hideNode(_ nodeId: String) {
        hiddenNodeIds.insert(nodeId)
    }

    /// Unhide a previously hidden node.
    func unhideNode(_ nodeId: String) {
        hiddenNodeIds.remove(nodeId)
    }

    /// Clear all individually hidden nodes.
    func clearHidden() {
        hiddenNodeIds.removeAll()
    }

    // MARK: - Timeline

    /// Set the timeline cutoff date. Pass nil to clear.
    func setTimelineDate(_ date: Date?) {
        timelineDate = date
    }

    // MARK: - Visibility Checks

    /// Check whether a node should be visible given all active filters.
    /// Checks type filter, then focus filter, then timeline filter — short-circuits on first fail.
    func isNodeVisible(_ node: GraphNodeRecord) -> Bool {
        // 1. Individually hidden nodes
        guard !hiddenNodeIds.contains(node.id) else { return false }

        // 2. Type filter
        guard activeNodeTypes.contains(node.type) else { return false }

        // 3. Focus filter
        if let connected = focusedConnected {
            guard connected.contains(node.id) else { return false }
        }

        // 4. Timeline filter
        if let cutoff = timelineDate {
            guard node.createdAt <= cutoff else { return false }
        }

        return true
    }

    /// Check whether an edge should be visible.
    /// An edge is visible only if both its source and target endpoints are visible.
    func isEdgeVisible(
        _ edge: GraphEdgeRecord,
        sourceVisible: Bool,
        targetVisible: Bool
    ) -> Bool {
        sourceVisible && targetVisible
    }

    // MARK: - Counts

    /// Count of visible nodes per type in the given store.
    func visibleCount(in store: GraphStore) -> [GraphNodeType: Int] {
        var counts: [GraphNodeType: Int] = [:]
        for node in store.nodes.values {
            if isNodeVisible(node) {
                counts[node.type, default: 0] += 1
            }
        }
        return counts
    }

    /// Total count of nodes per type in the given store (ignoring filters).
    func totalCount(in store: GraphStore) -> [GraphNodeType: Int] {
        var counts: [GraphNodeType: Int] = [:]
        for node in store.nodes.values {
            counts[node.type, default: 0] += 1
        }
        return counts
    }
}
