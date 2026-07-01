import SwiftUI

struct HTMLWorkspacePreviewContextPicker: View {
    let contextItems: [HTMLWorkspaceRegenerateContextItem]
    let contextStatusText: String?
    let isRegenerating: Bool
    let isRefreshingContext: Bool
    let theme: EpistemosTheme
    let targetText: String
    let onOpenContextSearch: () -> Void
    let onRequestContextShortcut: (HTMLWorkspaceRegenerateContextShortcut) -> Void
    let onPickContextItem: (HTMLWorkspaceRegenerateContextItem) -> Void

    private var pickerFill: Color {
        theme.resolved.card.color.opacity(theme.isDark ? 0.52 : 0.72)
    }

    private var pixelCaptionFont: Font {
        .system(size: 11, weight: .semibold, design: .monospaced)
    }

    var body: some View {
        Menu {
            Button {
                onOpenContextSearch()
            } label: {
                Label("Search Context", systemImage: "magnifyingglass")
            }
            .disabled(isRefreshingContext)

            if !targetText.isEmpty {
                Text(targetText)
            }

            Divider()
            Section("Source Families") {
                ForEach(HTMLWorkspaceRegenerateContextShortcut.all) { shortcut in
                    Button {
                        onRequestContextShortcut(shortcut)
                    } label: {
                        Label(shortcut.title, systemImage: shortcut.systemImage)
                    }
                    .disabled(isRefreshingContext)
                    .help(shortcut.helpText)
                }
            }

            if let contextStatusText, !contextStatusText.isEmpty {
                Divider()
                Text(contextStatusText)
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
                        contextMenuLabel(for: item)
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

    private func contextMenuLabel(for item: HTMLWorkspaceRegenerateContextItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: item.systemImage)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .lineLimit(1)
                Text(item.contextDescriptor)
                    .font(.caption2)
                    .lineLimit(1)
                Text(item.provenanceDescriptor)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.rankDescriptor)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
    }
}
