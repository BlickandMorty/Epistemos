import SwiftUI

// MARK: - EpdocCopilotTransform

/// Bounded document transforms the native .epdoc copilot may run today.
/// This deliberately follows the controlled GenUI shape: Swift owns the UI
/// and the closed command set; the prompt only selects among real editor
/// commands rather than inventing arbitrary document mutations.
nonisolated public enum EpdocCopilotTransform: String, CaseIterable, Sendable, Hashable, Identifiable {
    case visualMap
    case frontmatter
    case scatterplot
    case barChart
    case lineChart
    case studyCallout

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .visualMap: return "Visualize document"
        case .frontmatter: return "Add frontmatter"
        case .scatterplot: return "Scatterplot"
        case .barChart: return "Bar chart"
        case .lineChart: return "Line chart"
        case .studyCallout: return "Study callout"
        }
    }

    var subtitle: String {
        switch self {
        case .visualMap: return "derive graph"
        case .frontmatter: return "visible metadata"
        case .scatterplot: return "x/y evidence"
        case .barChart: return "counts"
        case .lineChart: return "trend"
        case .studyCallout: return "research note"
        }
    }

    var symbol: String {
        switch self {
        case .visualMap: return "flowchart"
        case .frontmatter: return "tag"
        case .scatterplot: return "chart.xyaxis.line"
        case .barChart: return "chart.bar"
        case .lineChart: return "chart.line.uptrend.xyaxis"
        case .studyCallout: return "lightbulb"
        }
    }

    public var command: EpdocEditorCommand {
        switch self {
        case .visualMap:
            return .runCommand(name: "insertEpdocGraphFromDocument", argsJSON: Self.emptyArgs)
        case .frontmatter:
            return .runCommand(name: "insertEpdocFrontmatter", argsJSON: Self.emptyArgs)
        case .scatterplot:
            return .insertSlashChoice(blockType: "chart-scatter")
        case .barChart:
            return .insertSlashChoice(blockType: "chart-bar")
        case .lineChart:
            return .insertSlashChoice(blockType: "chart-line")
        case .studyCallout:
            return .insertSlashChoice(blockType: "callout-tip")
        }
    }

    var response: String {
        switch self {
        case .visualMap: return "Inserted a graph derived from the live document structure."
        case .frontmatter: return "Added a visible YAML metadata block at the top if one was not already present."
        case .scatterplot: return "Inserted a structured scatterplot block you can edit in place."
        case .barChart: return "Inserted a structured bar chart block you can edit in place."
        case .lineChart: return "Inserted a structured line chart block you can edit in place."
        case .studyCallout: return "Inserted a study callout for the next claim, gap, or reminder."
        }
    }

    public static func resolve(prompt: String) -> EpdocCopilotTransform? {
        let normalized = prompt
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return allCases.first { transform in
            transform.aliases.contains { normalized.contains($0) }
        }
    }

    private var aliases: [String] {
        switch self {
        case .visualMap:
            return ["visual", "graph", "diagram", "map", "flow"]
        case .frontmatter:
            return ["frontmatter", "front matter", "metadata", "yaml", "properties"]
        case .scatterplot:
            return ["scatter", "scatterplot", "x y", "xy chart"]
        case .barChart:
            return ["bar chart", "bars", "histogram", "counts"]
        case .lineChart:
            return ["line chart", "trend", "timeline chart", "over time"]
        case .studyCallout:
            return ["callout", "study", "tip", "reminder", "note card"]
        }
    }

    private static let emptyArgs = Data("[]".utf8)
}

// MARK: - EpdocCopilotDockView

@MainActor
public struct EpdocCopilotDockView: View {
    public let wordCount: Int
    public let complexity: Double
    public let dispatch: @Sendable @MainActor (EpdocEditorCommand) -> Void
    public let onAskAgent: @Sendable @MainActor (String) -> Void
    public let freeformAgentEnabled: Bool

    @State private var isExpanded = false
    @State private var draft = ""
    @State private var messages = EpdocCopilotMessage.seed
    @FocusState private var promptFocused: Bool

    public init(
        wordCount: Int,
        complexity: Double,
        dispatch: @escaping @Sendable @MainActor (EpdocEditorCommand) -> Void,
        onAskAgent: @escaping @Sendable @MainActor (String) -> Void,
        freeformAgentEnabled: Bool = false
    ) {
        self.wordCount = wordCount
        self.complexity = complexity
        self.dispatch = dispatch
        self.onAskAgent = onAskAgent
        self.freeformAgentEnabled = freeformAgentEnabled
    }

    public var body: some View {
        Group {
            if isExpanded {
                expandedDock
                    .transition(.scale(scale: 0.96, anchor: .bottomTrailing).combined(with: .opacity))
            } else {
                collapsedButton
                    .transition(.scale(scale: 0.96, anchor: .bottomTrailing).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.18), value: isExpanded)
        .accessibilityIdentifier("epdoc-copilot-dock")
    }

    private var collapsedButton: some View {
        Button {
            isExpanded = true
            promptFocused = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .symbolRenderingMode(.hierarchical)
                Text("Ask Epdoc")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.separator.opacity(0.56), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help("Ask Epdoc to transform this document")
    }

    private var expandedDock: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            transcript
            quickActions
            promptRow
        }
        .frame(width: 382)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.separator.opacity(0.55), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 5)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("Epdoc Copilot")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(wordCount) words · complexity \(Int((complexity * 100).rounded()))%")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                isExpanded = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Close Epdoc Copilot")
        }
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(messages.suffix(4))) { message in
                EpdocCopilotMessageBubble(message: message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
            ForEach(EpdocCopilotTransform.allCases.prefix(4)) { transform in
                Button {
                    apply(transform, userText: transform.title)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: transform.symbol)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(transform.title)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Text(transform.subtitle)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.separator.opacity(0.38), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var promptRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask for a diagram, chart, callout, or frontmatter", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.background.opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.separator.opacity(0.36), lineWidth: 0.5)
                )
                .focused($promptFocused)
                .onSubmit(submitPrompt)

            Button(action: submitPrompt) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("Send")
        }
    }

    private func submitPrompt() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        if let transform = EpdocCopilotTransform.resolve(prompt: text) {
            apply(transform, userText: text)
        } else {
            messages.append(.user(text))
            if freeformAgentEnabled {
                onAskAgent(text)
                messages.append(.assistant("Sent to the document agent. The dock's safe built-in transforms are diagrams, charts, callouts, and frontmatter."))
            } else {
                messages.append(.assistant("Free-form document editing is not wired yet. I can run the safe built-in transforms today: diagrams, charts, callouts, and frontmatter."))
            }
        }
    }

    private func apply(_ transform: EpdocCopilotTransform, userText: String) {
        messages.append(.user(userText))
        dispatch(transform.command)
        messages.append(.assistant(transform.response))
    }
}

private struct EpdocCopilotMessage: Identifiable, Hashable {
    enum Role: Hashable {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String

    static let seed: [EpdocCopilotMessage] = [
        .assistant("I can transform this doc with bounded native actions: visual maps, charts, callouts, and visible metadata."),
    ]

    static func user(_ text: String) -> EpdocCopilotMessage {
        EpdocCopilotMessage(role: .user, text: text)
    }

    static func assistant(_ text: String) -> EpdocCopilotMessage {
        EpdocCopilotMessage(role: .assistant, text: text)
    }
}

@MainActor
private struct EpdocCopilotMessageBubble: View {
    let message: EpdocCopilotMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 34) }
            Text(message.text)
                .font(.system(size: 12))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(backgroundShape)
            if message.role == .assistant { Spacer(minLength: 34) }
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        if message.role == .user {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background.opacity(0.58))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.separator.opacity(0.3), lineWidth: 0.5)
                )
        }
    }
}

#if DEBUG
#Preview("Epdoc Copilot Dock") {
    EpdocCopilotDockView(
        wordCount: 420,
        complexity: 0.38,
        dispatch: { _ in },
        onAskAgent: { _ in }
    )
    .padding()
    .frame(width: 460)
}
#endif
