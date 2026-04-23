import SwiftUI

enum ProcessDisclosureTone {
    case tool
    case thinking
    case write
    case success
    case warning
    case error

    func tint(theme: EpistemosTheme) -> Color {
        switch self {
        case .tool:
            return theme.resolved.accent.color
        case .thinking:
            return theme.isDark ? Color(red: 0.76, green: 0.68, blue: 0.98) : Color(red: 0.42, green: 0.32, blue: 0.76)
        case .write:
            return theme.chatStrongForeground
        case .success:
            return theme.success
        case .warning:
            return .orange
        case .error:
            return theme.error
        }
    }
}

struct ProcessDisclosureHeader<Summary: View, Trailing: View>: View {
    @Environment(UIState.self) private var ui

    private let title: String
    private let tone: ProcessDisclosureTone
    private let isExpanded: Bool?
    private let action: (() -> Void)?
    private let summary: Summary
    private let trailing: Trailing

    private var theme: EpistemosTheme { ui.theme }

    init(
        title: String,
        tone: ProcessDisclosureTone,
        isExpanded: Bool? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder summary: () -> Summary,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.tone = tone
        self.isExpanded = isExpanded
        self.action = action
        self.summary = summary()
        self.trailing = trailing()
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    row
                }
                .buttonStyle(.plain)
            } else {
                row
            }
        }
    }

    private var row: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let isExpanded {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }

            Text("[\(title.uppercased())]")
                .font(ClaudeAppTypography.monoFont(size: 10, weight: .semibold))
                .foregroundStyle(tone.tint(theme: theme))

            summary
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

extension ProcessDisclosureHeader where Trailing == EmptyView {
    init(
        title: String,
        tone: ProcessDisclosureTone,
        isExpanded: Bool? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder summary: () -> Summary
    ) {
        self.init(
            title: title,
            tone: tone,
            isExpanded: isExpanded,
            action: action,
            summary: summary,
            trailing: { EmptyView() }
        )
    }
}

struct ProcessDisclosureDivider: View {
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Rectangle()
            .fill(theme.glassBorder.opacity(theme.isDark ? 0.62 : 0.34))
            .frame(height: 1)
    }
}

struct ProcessDisclosureDetailBlock: View {
    @Environment(UIState.self) private var ui

    let title: String?
    let content: String
    let tone: ProcessDisclosureTone

    private var theme: EpistemosTheme { ui.theme }
    private var contentColor: Color {
        switch tone {
        case .thinking:
            return theme.textSecondary
        case .error:
            return theme.error
        default:
            return theme.resolved.foreground.color
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(tone.tint(theme: theme).opacity(theme.isDark ? 0.82 : 0.58))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 5) {
                if let title, !title.isEmpty {
                    Text(title.uppercased())
                        .font(ClaudeAppTypography.monoFont(size: 10, weight: .semibold))
                        .foregroundStyle(tone.tint(theme: theme).opacity(0.88))
                }

                Text(content)
                    .font(ClaudeAppTypography.monoFont(size: 11))
                    .foregroundStyle(contentColor)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ProcessDisclosureTextBlock: View {
    @Environment(UIState.self) private var ui

    let content: String
    let tone: ProcessDisclosureTone

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(tone.tint(theme: theme).opacity(theme.isDark ? 0.82 : 0.58))
                .frame(width: 2)

            Text(content)
                .font(ClaudeAppTypography.monoFont(size: 11))
                .foregroundStyle(theme.textSecondary)
                .lineSpacing(4)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
