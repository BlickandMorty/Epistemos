import SwiftUI

struct HTMLWorkspacePreviewContextPicker: View {
    let contextItems: [HTMLWorkspaceRegenerateContextItem]
    let contextStatusText: String?
    let isRegenerating: Bool
    let isRefreshingContext: Bool
    let theme: EpistemosTheme
    let onPickContextItem: (HTMLWorkspaceRegenerateContextItem) -> Void

    private var pickerFill: Color {
        theme.resolved.card.color.opacity(theme.isDark ? 0.52 : 0.72)
    }

    private var pixelCaptionFont: Font {
        .system(size: 11, weight: .semibold, design: .monospaced)
    }

    var body: some View {
        Menu {
            if let contextStatusText, !contextStatusText.isEmpty {
                Text(contextStatusText)
                Divider()
            }

            if isRefreshingContext {
                Label("Refreshing context", systemImage: "arrow.triangle.2.circlepath")
            } else if contextItems.isEmpty {
                Label("No context attached", systemImage: "tray")
            } else {
                ForEach(contextItems) { item in
                    Button {
                        onPickContextItem(item)
                    } label: {
                        Label(item.title, systemImage: "doc.text")
                    }
                    .help(item.dragPayload)
                }
            }
        } label: {
            Label("Add Context", systemImage: "plus.square.on.square")
                .font(pixelCaptionFont)
                .foregroundStyle(theme.resolved.foreground.color)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(pickerFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(theme.isDark ? 0.18 : 0.08), radius: 8, y: 3)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(isRegenerating)
        .help("Pick read-only context for this preview surface")
        .opacity(isRefreshingContext ? 0.78 : 1)
    }
}
