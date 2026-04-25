import SwiftUI
import SwiftData

// MARK: - GraphInspectModeView
// Full-screen immersive visualization for selected node.
// Shows selected node + nested children + connected neighbors.
// Unrelated nodes are de-emphasized (dimmed/hidden).
// 5-layer depth parallax effect for premium feel.

struct GraphInspectModeView: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let modelContext: ModelContext

    @State private var isActive = false
    @State private var exitScale: CGFloat = 1.0
    
    // Layer depths for parallax effect (5 layers)
    private let layerDepths: [CGFloat] = [0.0, 0.15, 0.35, 0.6, 1.0]
    private let layerScales: [CGFloat] = [0.7, 0.85, 1.0, 1.15, 1.3]
    private let layerOpacities: [Double] = [0.15, 0.35, 1.0, 0.5, 0.2]
    
    var body: some View {
        ZStack {
            // Layer 0: Far background (unrelated nodes, very dim)
            if isActive {
                inspectLayer(depth: 0)
            }
            
            // Layer 1: Distant connected nodes
            if isActive {
                inspectLayer(depth: 1)
            }
            
            // Layer 2: Main content (selected + direct connections)
            inspectLayer(depth: 2)
            
            // Layer 3: Close foreground elements
            if isActive {
                inspectLayer(depth: 3)
            }
            
            // Layer 4: Very close effects (atmosphere)
            if isActive {
                inspectLayer(depth: 4)
            }
            
            // Exit button
            if isActive {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) {
                                exitScale = 0.95
                            }
                            Task { @MainActor in
                                if !reduceMotion {
                                    try? await Task.sleep(for: .milliseconds(100))
                                }
                                deactivateInspectMode()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(exitScale)
                    }
                    Spacer()
                }
            }
        }
        .onChange(of: graphState.selectedNodeId) { _, newId in
            if newId != nil && !isActive {
                // Auto-enter inspect mode when selecting a node
                withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85)) {
                    isActive = true
                }
            } else if newId == nil && isActive {
                // Auto-exit when deselecting
                deactivateInspectMode()
            }
        }
    }
    
    @ViewBuilder
    private func inspectLayer(depth: Int) -> some View {
        let scale = layerScales[depth]
        let opacity = layerOpacities[depth]
        
        ZStack {
            // Background dimming for focus
            if depth == 2 {
                Color.black
                    .opacity(isActive ? 0.15 : 0)
                    .ignoresSafeArea()
            }
            
            // Placeholder for actual graph layer rendering
            // In production, this would render the appropriate node subset
            // at the specified depth with parallax offset
            Circle()
                .fill(depth == 2 ? Color.accentColor : Color.gray)
                .frame(width: depth == 2 ? 200 : 100)
                .opacity(opacity)
                .scaleEffect(isActive ? scale : 0.5)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8), value: isActive)
    }

    private func deactivateInspectMode() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
            isActive = false
            exitScale = 1.0
        }
    }
}

// MARK: - GraphState Extension for Inspect Mode

extension GraphState {
    /// Enter immersive inspect mode for the currently selected node
    func enterInspectMode() {
        guard selectedNodeId != nil else { return }
        // The view observes selectedNodeId and auto-activates
        // This function can trigger additional setup if needed
    }
    
    /// Exit immersive inspect mode
    func exitInspectMode() {
        // The view observes selectedNodeId and auto-deactivates when cleared
        selectNode(nil)
    }
}
