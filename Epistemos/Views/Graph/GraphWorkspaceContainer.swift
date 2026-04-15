import SwiftUI
import SwiftData

struct GraphWorkspaceContainer: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    
    // Injected by the surrounding HologramOverlayHostedViewBuilder
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            // The Metal canvas naturally exists below this SwiftUI layer. 
            // We pass clicks through when on the .canvas route.
            switch graphState.currentRoute {
            case .canvas:
                Color.clear
                    .allowsHitTesting(false)
                
            case .note(let id):
                graphPageBackdrop
                
                // Placeholder for ProseEditorView (to be fully integrated in Step 4)
                VStack(spacing: 0) {
                    graphPageHeader(title: "Note: \(id)")
                    
                    Text("Graph Note Page Placeholder for \(id)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
            case .folder(let id):
                graphPageBackdrop
                
                // Placeholder for Folder list/thumbnail view (to be integrated in Step 5)
                VStack(spacing: 0) {
                    graphPageHeader(title: "Folder: \(id)")
                    
                    Text("Graph Folder Page Placeholder for \(id)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        // Ensure animations for route transitions are smooth
        .animation(.snappy(duration: 0.3, extraBounce: 0.1), value: graphState.currentRoute)
    }
    
    private var graphPageBackdrop: some View {
        // Obscures the 3D nodes while a page is open, maintaining spatial awareness softly.
        Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea()
            .allowsHitTesting(true) // Stops clicks from bleeding down into the MetalView
    }
    
    private func graphPageHeader(title: String) -> some View {
        HStack {
            Button(action: {
                graphState.returnToCanvas()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Graph")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding()
            
            Spacer()
            
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .padding()
            
            Spacer()
            
            // Layout balancer
            Color.clear.frame(width: 80, height: 1)
        }
        .background(.ultraThinMaterial)
    }
}
