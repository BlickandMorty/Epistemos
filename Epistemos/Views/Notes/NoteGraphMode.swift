import SwiftUI
import SwiftData

// MARK: - In-Note Graph Mode
// Overlays the knowledge graph directly inside a note window.
// Activated via Cmd+G. The note content dims with a vignette and the graph
// materializes on top, centered on the current note's node.
// Tapping a node navigates to that note in the same window.

struct NoteGraphOverlay: View {
    let pageId: String
    @Binding var isActive: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var graphOpacity: Double = 0
    @State private var vignetteOpacity: Double = 0

    var body: some View {
        ZStack {
            // Dark vignette overlay
            Color.black
                .opacity(vignetteOpacity * 0.6)
                .ignoresSafeArea()

            // Metal graph view (NSViewRepresentable)
            NoteGraphMetalView(pageId: pageId, onNodeTap: handleNodeTap)
                .opacity(graphOpacity)
                .ignoresSafeArea()

            // Close button (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismissGraph()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                    .help("Close Graph (Esc)")
                }
                Spacer()
            }
            .opacity(graphOpacity)
        }
        .onAppear { animateIn() }
        .onExitCommand { dismissGraph() }
    }

    private func animateIn() {
        // Phase 1: Vignette fades in (0-0.3s)
        withAnimation(.easeIn(duration: 0.3)) {
            vignetteOpacity = 1.0
        }
        // Phase 2: Graph materializes (0.3-0.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) {
                graphOpacity = 1.0
            }
        }
    }

    private func dismissGraph() {
        // Reverse animation
        withAnimation(.easeIn(duration: 0.3)) {
            graphOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                vignetteOpacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isActive = false
        }
    }

    private func handleNodeTap(_ sourceId: String) {
        // Navigate to the tapped note in the same window
        dismissGraph()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NoteWindowManager.shared.open(pageId: sourceId, fromPageId: pageId)
        }
    }
}

// MARK: - Metal Graph View (NSViewRepresentable)
// Wraps MetalGraphNSView for use inside the in-note graph overlay.
// Creates its own engine instance, loads graph data, and centers on the
// current note's node. Node taps are forwarded to the SwiftUI layer via
// the coordinator pattern.

struct NoteGraphMetalView: NSViewRepresentable {
    let pageId: String
    let onNodeTap: (String) -> Void

    func makeNSView(context: Context) -> MetalGraphNSView {
        guard let bootstrap = AppBootstrap.shared else {
            return MetalGraphNSView(frame: .zero)
        }

        let graphView = MetalGraphNSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        graphView.graphState = bootstrap.graphState
        graphView.isOverlayMode = true
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        graphView.isLightMode = !isDark
        graphView.applyOverlayMode()

        // Load graph data if needed
        if !bootstrap.graphState.isLoaded {
            bootstrap.graphState.loadGraph(context: bootstrap.modelContainer.mainContext)
        }

        // Commit graph data and center on current note's node
        graphView.commitGraphData()

        // Find the node for this page and center/highlight it
        if let nodeId = bootstrap.graphState.store.nodes.values.first(where: { $0.sourceId == pageId })?.id {
            graphView.isolateNode(nodeId)
        }

        // Wire node tap callback through coordinator
        let coordinator = context.coordinator
        graphView.onNodeTap = { sourceId in
            coordinator.onNodeTap?(sourceId)
        }
        coordinator.onNodeTap = onNodeTap
        coordinator.graphView = graphView

        return graphView
    }

    func updateNSView(_ nsView: MetalGraphNSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var onNodeTap: ((String) -> Void)?
        weak var graphView: MetalGraphNSView?
    }
}
