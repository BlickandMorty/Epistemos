import SwiftUI

enum ProcessDisclosureTone {
    case tool
    case evidence
    case thinking
    case write
    case success
    case warning
    case error

    func tint(theme: EpistemosTheme) -> Color {
        switch self {
        case .tool:
            return theme.resolved.accent.color
        case .evidence:
            return theme.isDark ? Color(red: 0.42, green: 0.86, blue: 0.72) : Color(red: 0.00, green: 0.50, blue: 0.42)
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

/// Reasoning-trace body used by every "thinking" surface (the main-chat inline
/// segment, the MiniChat / note / graph ThinkingTrailView, and the legacy
/// popover preview). Styled to read like ChatGPT's native thinking panel —
/// muted, proportional, airy prose rather than an 11pt monospaced code dump.
/// The content is lightly de-markdowned for display (raw `**`, `__`, leading
/// `#` heading hashes, and `>` quote carets removed) so a model's scratch-pad
/// markdown doesn't surface as literal syntax. Tool / skill payloads render via
/// `ProcessDisclosureDetailBlock` (still monospaced) and are unaffected.
struct ProcessDisclosureTextBlock: View {
    @Environment(UIState.self) private var ui

    let content: String
    let tone: ProcessDisclosureTone

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(tone.tint(theme: theme).opacity(theme.isDark ? 0.55 : 0.40))
                .frame(width: 2.5)

            Text(Self.displayText(for: content))
                .font(ClaudeAppTypography.assistantFont(size: 14))
                .foregroundStyle(theme.textSecondary)
                .lineSpacing(5)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Strip the most common raw-markdown artifacts from a reasoning trace so it
    /// reads as plain muted prose. Intentionally conservative: it only removes
    /// emphasis/heading/quote SYNTAX, never content, and preserves list markers
    /// and indentation so a numbered reasoning plan still reads as a list.
    static func displayText(for content: String) -> String {
        var collapsed: [String] = []
        var blankRun = 0
        for rawLine in content.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            // Strip bold / italic emphasis runs (**x**, __x__) → x.
            var line = rawLine
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "__", with: "")
            // Drop leading heading hashes ("### Plan" → "Plan") and quote carets,
            // preserving the line's original indentation (list nesting).
            let indent = line.prefix { $0 == " " || $0 == "\t" }
            var rest = Substring(line.dropFirst(indent.count))
            while rest.first == "#" || rest.first == ">" { rest = rest.dropFirst() }
            if (line.first == "#" || line.first == ">") || indent.isEmpty {
                line = String(rest).trimmingCharacters(in: .whitespaces)
            } else {
                line = String(indent) + String(rest.drop { $0 == " " })
            }

            // Collapse runs of blank lines into a single paragraph break.
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                blankRun += 1
                if blankRun <= 1 { collapsed.append("") }
            } else {
                blankRun = 0
                collapsed.append(line)
            }
        }
        return collapsed.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
