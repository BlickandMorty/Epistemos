import SwiftUI

enum MarkdownDocumentPresentationMode: String, CaseIterable, Identifiable, Sendable {
    case rendered
    case markdown

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .rendered: "Doc"
        case .markdown: "MD"
        }
    }

    var icon: String {
        switch self {
        case .rendered: "eye"
        case .markdown: "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct MarkdownDocumentModeToggle: View {
    @Binding var mode: MarkdownDocumentPresentationMode

    @Environment(UIState.self) private var ui

    var showsLabels = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MarkdownDocumentPresentationMode.allCases) { option in
                Button {
                    mode = option
                } label: {
                    HStack(spacing: showsLabels ? 5 : 0) {
                        Image(systemName: option.icon)
                            .font(.system(size: 11, weight: .semibold))
                        if showsLabels {
                            Text(option.title)
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .foregroundStyle(
                        mode == option
                            ? Color.white.opacity(0.92)
                            : theme.textTertiary
                    )
                    .padding(.horizontal, showsLabels ? 10 : 8)
                    .padding(.vertical, 6)
                    .background(
                        mode == option
                            ? theme.resolved.accent.color.opacity(theme.isDark ? 0.34 : 0.22)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .help(option == .rendered ? "Rendered document view" : "Raw markdown view")
            }
        }
        .padding(4)
        .background(
            theme.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(theme.border.opacity(0.7), lineWidth: 0.7)
        }
    }
}
