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
        case .visualMap: return "HTML Workspace"
        case .frontmatter: return "Add frontmatter"
        case .scatterplot: return "Scatterplot"
        case .barChart: return "Bar chart"
        case .lineChart: return "Line chart"
        case .studyCallout: return "Study callout"
        }
    }

    var subtitle: String {
        switch self {
        case .visualMap: return "DOM visual"
        case .frontmatter: return "visible metadata"
        case .scatterplot: return "x/y evidence"
        case .barChart: return "counts"
        case .lineChart: return "trend"
        case .studyCallout: return "research note"
        }
    }

    var symbol: String {
        switch self {
        case .visualMap: return "rectangle.3.group"
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
            return .runCommand(name: "requestHTMLWorkspace", argsJSON: Self.emptyArgs)
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
        case .visualMap: return "Opened a sandboxed HTML Workspace for the visualization."
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
            return ["visual", "workspace", "html", "dom", "interactive", "graph", "diagram", "map", "flow"]
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

#if !EPISTEMOS_FREE_V1
@MainActor
public struct EpdocCopilotDockView: View {
    public let wordCount: Int
    public let dispatch: @Sendable @MainActor (EpdocEditorCommand) -> Void
    public let freeformAgentEnabled: Bool
    public let assistContext: JuneEpdocAssistContext?
    public let submitAssist: (@MainActor (String, JuneEpdocAssistContext) -> JuneEpdocAssistSubmissionResult)?
    public let stageAssistSuggestion: (@MainActor (String, JuneEpdocAssistContext) -> JuneEpdocAssistSuggestionStageResult)?

    @State private var isAssistOpen = false
    @State private var assistPrompt = ""
    @State private var assistStatus: String?
    @State private var assistSessionID: String?
    @State private var assistSuggestionDraft: EpdocSuggestionReviewDraft?

    public init(
        wordCount: Int,
        dispatch: @escaping @Sendable @MainActor (EpdocEditorCommand) -> Void,
        freeformAgentEnabled: Bool = false,
        assistContext: JuneEpdocAssistContext? = nil,
        submitAssist: (@MainActor (String, JuneEpdocAssistContext) -> JuneEpdocAssistSubmissionResult)? = nil,
        stageAssistSuggestion: (@MainActor (String, JuneEpdocAssistContext) -> JuneEpdocAssistSuggestionStageResult)? = nil
    ) {
        self.wordCount = wordCount
        self.dispatch = dispatch
        self.freeformAgentEnabled = freeformAgentEnabled
        self.assistContext = assistContext
        self.submitAssist = submitAssist
        self.stageAssistSuggestion = stageAssistSuggestion
    }

    public var body: some View {
        quickActions
            .padding(8)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.separator.opacity(0.55), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 4)
            .accessibilityIdentifier("epdoc-document-actions")
    }

    private var quickActions: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if isAssistOpen {
                HStack(spacing: 8) {
                    TextField("Ask Epdoc", text: $assistPrompt)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .frame(width: 260)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                        .onSubmit(submitAssistPrompt)
                    iconButton(
                        symbol: "paperplane.fill",
                        label: "Ask Epdoc",
                        help: "Send the note-scoped prompt to the paid Epdoc assistant."
                    ) {
                        submitAssistPrompt()
                    }
                    if assistSessionID != nil {
                        iconButton(
                            symbol: "sparkles",
                            label: "Stage assistant suggestion",
                            help: "Stage the latest structured assistant suggestion for review."
                        ) {
                            stageLatestAssistSuggestion()
                        }
                    }
                }
                if let assistStatus {
                    Text(assistStatus)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 320, alignment: .trailing)
                }
                if let assistSuggestionDraft {
                    HStack(spacing: 7) {
                        Text(assistSuggestionDraft.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        iconButton(
                            symbol: "checkmark",
                            label: "Accept assistant suggestion",
                            help: assistSuggestionDraft.summary
                        ) {
                            acceptAssistSuggestion()
                        }
                        iconButton(
                            symbol: "xmark",
                            label: "Reject assistant suggestion",
                            help: assistSuggestionDraft.summary
                        ) {
                            rejectAssistSuggestion()
                        }
                    }
                }
            }

            HStack(spacing: 7) {
                if assistContext != nil {
                    iconButton(
                        symbol: isAssistOpen ? "chevron.down" : "message.badge.waveform",
                        label: "June Epdoc Assist",
                        help: "Open June Epdoc Assist."
                    ) {
                        isAssistOpen.toggle()
                    }
                }

                ForEach([EpdocCopilotTransform.frontmatter]) { transform in
                    dockButton(
                        title: transform.title,
                        symbol: transform.symbol,
                        help: transform.response
                    ) {
                        dispatch(transform.command)
                    }
                }
            }
        }
    }

    private func submitAssistPrompt() {
        guard let assistContext, let submitAssist else {
            assistStatus = "June unavailable"
            return
        }
        let prompt = assistPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        switch submitAssist(prompt, assistContext) {
        case .submitted(let sessionID):
            assistSessionID = sessionID
            assistSuggestionDraft = nil
            assistPrompt = ""
            assistStatus = "Sent to June"
        case .busy(let sessionID):
            assistSessionID = sessionID
            assistStatus = "June is busy"
        case .unavailable(let message):
            assistStatus = message
        }
    }

    private func stageLatestAssistSuggestion() {
        guard let assistContext,
              let stageAssistSuggestion,
              let assistSessionID else {
            assistStatus = "No June session"
            return
        }
        switch stageAssistSuggestion(assistSessionID, assistContext) {
        case .staged(let draft):
            dispatch(draft.stageCommand)
            assistSuggestionDraft = draft
            assistStatus = "Suggestion staged"
        case .busy:
            assistStatus = "June is still responding"
        case .unavailable(let message):
            assistStatus = message
        }
    }

    private func acceptAssistSuggestion() {
        guard let draft = assistSuggestionDraft else { return }
        dispatch(draft.acceptCommand)
        assistSuggestionDraft = nil
        assistStatus = "Accept requested"
    }

    private func rejectAssistSuggestion() {
        guard let draft = assistSuggestionDraft else { return }
        dispatch(draft.rejectCommand)
        assistSuggestionDraft = nil
        assistStatus = "Reject requested"
    }

    private func dockButton(
        title: String,
        symbol: String,
        help: String,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule().strokeBorder(.separator.opacity(0.38), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func iconButton(
        symbol: String,
        label: String,
        help: String,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 30, height: 30)
                .background(.thinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.separator.opacity(0.38), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(label)
    }
}

#if DEBUG
#Preview("Epdoc Copilot Dock") {
    EpdocCopilotDockView(
        wordCount: 420,
        dispatch: { _ in }
    )
    .padding()
    .frame(width: 460)
}
#endif
#endif
