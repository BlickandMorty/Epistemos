import SwiftUI
import SwiftData

// MARK: - Graph Note Page (Phase 7 Step 4)
//
// Graph-native note surface: resolves an `SDPage` by the sourceId carried in
// a `GraphWorkspaceRoute.note(id:)` and embeds the real TextKit 2 editor via
// `ProseEditorView`. No parallel note store is introduced — the graph page
// reads and writes the same `SDPage` as the home note tabs, so edits here
// propagate everywhere through the existing vault sync pipeline.
//
// Per Step 4 (minimum viable): the graph note page owns its own per-instance
// `NoteChatState`, matching the home `NoteDetailWorkspaceView` pattern at
// `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`. That means AI chat
// started from a graph page is isolated from whatever chat is running in a
// home tab for the same note — sharing the chat instance across surfaces is
// a later refinement. Note *content* (SDPage.body) is still canonical and
// fully shared.

struct GraphNotePage: View {
    let sourceId: String
    @Query private var pages: [SDPage]
    @State private var noteChatState: NoteChatState

    @MainActor
    init(sourceId: String) {
        self.sourceId = sourceId
        _pages = Query(filter: #Predicate<SDPage> { $0.id == sourceId })
        _noteChatState = State(initialValue: NoteChatState(pageId: sourceId))
    }

    var body: some View {
        if let page = pages.first {
            ProseEditorView(page: page, navigationContext: .graph)
                .environment(noteChatState)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
