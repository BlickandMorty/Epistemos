import SwiftData
import SwiftUI

struct AgentPlanEditorView: View {
    @Binding var text: String

    @Environment(\.modelContext) private var modelContext
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui

    let pageId: String
    var presentationMode: MarkdownDocumentPresentationMode = .rendered

    var body: some View {
        Group {
            switch presentationMode {
            case .rendered:
                renderedEditor
            case .markdown:
                markdownEditor
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(ui.theme.border.opacity(0.6), lineWidth: 0.8)
        }
    }

    private var renderedEditor: some View {
        ProseEditorRepresentable2(
            text: $text,
            pageId: pageId,
            pageBody: text,
            isFocused: false,
            theme: ui.theme,
            isEditable: true,
            isFocusMode: false,
            modelContext: modelContext,
            onWikilinkClick: nil,
            onBlockRefClick: nil,
            noteChatState: nil,
            onPageFlush: { _, currentText in
                if currentText != text {
                    text = currentText
                }
            },
            graphState: graphState,
            outlineFoldMode: .expanded
        )
    }

    private var markdownEditor: some View {
        TextEditor(text: $text)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(ui.theme.textPrimary)
            .scrollContentBackground(.hidden)
            .padding(10)
            .background(ui.theme.resolved.background.color.opacity(ui.theme.isDark ? 0.6 : 0.9))
            .textSelection(.enabled)
    }
}
