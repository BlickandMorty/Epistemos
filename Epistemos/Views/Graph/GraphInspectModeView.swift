import SwiftUI
import SwiftData

// MARK: - GraphInspectModeView
// Deferred inspect-mode shell. The v1 graph overlay uses `MetalGraphView`
// plus `HologramNodeInspector`; this shell must not render synthetic graph
// layers until it is wired to real graph subsets.

struct GraphInspectModeView: View {
    @Environment(GraphState.self) private var graphState
    let modelContext: ModelContext

    var body: some View {
        let _ = graphState.selectedNodeId
        EmptyView()
            .accessibilityHidden(true)
    }
}

// MARK: - GraphState Extension for Inspect Mode

extension GraphState {
    /// Deferred v1 compatibility hook. The visible graph inspector is
    /// `HologramNodeInspector`; this hook intentionally does not mount UI.
    func enterInspectMode() {
        guard selectedNodeId != nil else { return }
    }
    
    /// Clear the selected node when callers ask to exit the deferred shell.
    func exitInspectMode() {
        selectNode(nil)
    }
}
