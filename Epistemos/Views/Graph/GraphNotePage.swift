import SwiftUI
import SwiftData

// MARK: - Graph Note Page (Phase 7 Step 4)
//
// Graph-native note surface: resolves an `SDPage` by the sourceId carried in
// a `GraphWorkspaceRoute.note(id:)` and reuses the canonical note workspace
// editor/chrome. No parallel note store is introduced — graph notes read and
// write the same `SDPage` as normal note tabs, while the embedded presentation
// keeps graph navigation inside the graph workspace.

struct GraphNotePage: View {
    let sourceId: String
    @Environment(GraphState.self) private var graphState
    @Query private var pages: [SDPage]

    @MainActor
    init(sourceId: String) {
        self.sourceId = sourceId
        _pages = Query(filter: #Predicate<SDPage> { $0.id == sourceId })
    }

    var body: some View {
        if pages.first != nil {
            NoteDetailWorkspaceView(pageId: sourceId, presentation: .embeddedGraph)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            notFoundFallback
        }
    }

    private var notFoundFallback: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("Note Not Found")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("No SDPage exists for \(sourceId)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            HStack(spacing: 8) {
                Button {
                    graphState.returnToCanvas()
                } label: {
                    Label("Canvas", systemImage: "circle.grid.3x3.fill")
                }
                Button {
                    graphState.requestGraphRebuild()
                } label: {
                    Label("Rebuild", systemImage: "arrow.trianglehead.2.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
