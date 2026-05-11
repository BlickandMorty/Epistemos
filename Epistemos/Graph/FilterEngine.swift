import Foundation

// MARK: - FilterEngine
// Manages graph visibility: which node/edge types are shown,
// and focus filtering (show only nodes connected to X).

@MainActor @Observable
final class FilterEngine {

    // MARK: - State

    /// Which node types are currently visible. Starts with all visible types active.
    private(set) var activeNodeTypes: Set<GraphNodeType> = Set(GraphNodeType.visibleCases)
    /// Which edge types are currently visible. Starts with all graph-visible relationship types active.
    private(set) var activeEdgeTypes: Set<GraphEdgeType> = Set(GraphEdgeType.visibleCases)

    /// The node ID currently focused on, if any.
    private(set) var focusedNodeId: String?

    /// The set of node IDs connected to the focused node (including itself).
    private(set) var focusedConnected: Set<String>?

    // MARK: - Text Search Filter

    /// Live text search filter — nodes whose label doesn't match are hidden.
    /// Set from the graph sidebar search field as the user types.
    var searchFilter: String = ""

    /// Pre-computed set of node IDs that match the current search filter.
    /// Populated by `applySearchFilter(store:)` — O(1) lookup in isNodeVisible.
    private(set) var searchMatchedNodeIds: Set<String>?

    /// Whether a text search is active.
    var hasSearchFilter: Bool { searchMatchedNodeIds != nil }

    /// Recompute the matched node set from the current search text.
    /// Call this ONCE when the text changes, not per-node in the render loop.
    func applySearchFilter(store: GraphStore) {
        let query = searchFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            searchMatchedNodeIds = nil
            return
        }
        var matched = Set<String>()
        matched.reserveCapacity(store.nodes.count / 4)
        for (id, node) in store.nodes {
            if node.label.lowercased().contains(query) {
                matched.insert(id)
            }
        }
        searchMatchedNodeIds = matched
    }

    /// Clear the text search filter.
    func clearSearchFilter() {
        searchFilter = ""
        searchMatchedNodeIds = nil
    }

    // MARK: - Model Profile Filter (v2)

    /// When set, only nodes associated with this model profile's vault are shown.
    var selectedModelProfileId: String?

    /// The vault identity key to filter by (set when a model profile is activated).
    var selectedVaultFilter: String?

    // MARK: - Computed

    /// True if any filter is active (not all types shown, or focused).
    var isFiltered: Bool {
        activeNodeTypes.count != GraphNodeType.visibleCases.count
            || activeEdgeTypes.count != GraphEdgeType.visibleCases.count
            || focusedNodeId != nil
            || selectedModelProfileId != nil
            || !searchFilter.isEmpty
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

    /// Toggle an edge type on or off.
    func toggleEdgeType(_ type: GraphEdgeType) {
        if activeEdgeTypes.contains(type) {
            activeEdgeTypes.remove(type)
        } else {
            activeEdgeTypes.insert(type)
        }
    }

    /// Reset to showing all edge types.
    func showAllEdgeTypes() {
        activeEdgeTypes = Set(GraphEdgeType.visibleCases)
    }

    // MARK: - Vault Mode

    /// The set of node types visible before entering agent vault mode.
    private var savedNodeTypes: Set<GraphNodeType>?

    /// Apply agent vault mode — show only live agent-memory graph nodes.
    /// Source/quote nodes stay disconnected from production paths.
    func applyAgentVaultMode() {
        savedNodeTypes = activeNodeTypes
        activeNodeTypes = [.idea, .tag]
    }

    /// Restore human vault mode — show all standard node types.
    func applyHumanVaultMode() {
        activeNodeTypes = savedNodeTypes ?? Set(GraphNodeType.visibleCases)
        savedNodeTypes = nil
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

    // MARK: - Model Profile Filter (v2)

    /// Scope the graph to a specific model profile's vault.
    func setModelFilter(profileId: String?, vaultKey: String?) {
        selectedModelProfileId = profileId
        selectedVaultFilter = vaultKey
    }

    /// Clear model profile filter (show all nodes).
    func clearModelFilter() {
        selectedModelProfileId = nil
        selectedVaultFilter = nil
    }

    /// Reset all graph filters when the active vault truth changes.
    func resetForVaultLifecycle() {
        activeNodeTypes = Set(GraphNodeType.visibleCases)
        activeEdgeTypes = Set(GraphEdgeType.visibleCases)
        savedNodeTypes = nil
        clearFocus()
        clearSearchFilter()
        clearModelFilter()
    }

    // MARK: - Visibility Checks

    /// Check whether a node should be visible given all active filters.
    ///
    /// Per RCA13 P1-010 / RCA4-P1-007: previously this only checked
    /// type + focus, leaving `searchMatchedNodeIds` populated but
    /// unconsulted. Search filters silently lied — the user typed
    /// a query, the matched-set populated, but every non-matching
    /// node stayed visible because the renderer's isNodeVisible
    /// only saw type + focus. Now the search-filter branch
    /// participates in visibility.
    ///
    /// `selectedModelProfileId` / `selectedVaultFilter` still don't
    /// participate because `GraphNodeRecord` doesn't currently
    /// carry per-node model/vault provenance — a separate plumbing
    /// slice is needed before they can affect visibility.
    func isNodeVisible(_ node: GraphNodeRecord) -> Bool {
        // 1. Type filter
        guard activeNodeTypes.contains(node.type) else { return false }

        // 2. Focus filter
        if let connected = focusedConnected {
            guard connected.contains(node.id) else { return false }
        }

        // 3. Search filter — when set, only matched nodes pass
        if let matched = searchMatchedNodeIds {
            guard matched.contains(node.id) else { return false }
        }

        return true
    }

    /// Check whether an edge should be visible.
    func isEdgeVisible(
        _ edge: GraphEdgeRecord,
        sourceVisible: Bool,
        targetVisible: Bool
    ) -> Bool {
        sourceVisible && targetVisible && activeEdgeTypes.contains(edge.type)
    }

    /// Snapshot the current filter state for background FFI payload building.
    func snapshot() -> GraphFilterSnapshot {
        GraphFilterSnapshot(filter: self)
    }
}
