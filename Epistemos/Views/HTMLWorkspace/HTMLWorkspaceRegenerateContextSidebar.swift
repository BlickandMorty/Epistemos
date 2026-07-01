import AppKit
import SwiftUI

struct HTMLWorkspaceRegenerateContextSidebar: View {
    let contextItems: [HTMLWorkspaceRegenerateContextItem]
    let contextStatusText: String?
    let isRegenerating: Bool
    let isRefreshingContext: Bool
    let panelFill: Color
    let theme: EpistemosTheme
    let onPickContextItem: (HTMLWorkspaceRegenerateContextItem) -> Void

    private var mutedText: Color {
        theme.textTertiary
    }

    private var itemFill: Color {
        theme.resolved.card.color.opacity(theme.isDark ? 0.34 : 0.56)
    }

    private var pixelCaptionFont: Font {
        .system(size: 11, weight: .semibold, design: .monospaced)
    }

    private var pixelMicroFont: Font {
        .system(size: 10, weight: .medium, design: .monospaced)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "tray.full")
                    .foregroundStyle(theme.resolved.accent.color)
                Text("Workspace Context")
                    .font(pixelCaptionFont)
                    .foregroundStyle(theme.resolved.foreground.color)
                Spacer(minLength: 0)
                if isRefreshingContext {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.72)
                }
            }

            if let contextStatusText, !contextStatusText.isEmpty {
                Text(contextStatusText)
                    .font(.caption2)
                    .foregroundStyle(mutedText)
                    .lineLimit(3)
                    .truncationMode(.middle)
            }

            if contextItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(contextItems) { item in
                            contextButton(item)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(panelFill)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("No context attached")
                .font(pixelCaptionFont)
                .foregroundStyle(theme.resolved.foreground.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(itemFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func contextButton(_ item: HTMLWorkspaceRegenerateContextItem) -> some View {
        Button {
            onPickContextItem(item)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(pixelCaptionFont)
                    .foregroundStyle(theme.resolved.foreground.color)
                    .lineLimit(2)
                Text(item.snippet)
                    .font(.caption2)
                    .foregroundStyle(mutedText)
                    .lineLimit(4)
                Text(item.pageID)
                    .font(pixelMicroFont)
                    .foregroundStyle(mutedText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(itemFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isRegenerating || isRefreshingContext)
        .onDrag {
            NSItemProvider(object: item.dragPayload as NSString)
        }
        .help("Drag into the preview or click to apply context")
    }
}
