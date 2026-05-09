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
        quickActions
            .padding(8)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.separator.opacity(0.55), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 4)
            .accessibilityIdentifier("epdoc-document-actions")
    }

    private var quickActions: some View {
        HStack(spacing: 7) {
            ForEach([EpdocCopilotTransform.visualMap, .frontmatter]) { transform in
                Button {
                    dispatch(transform.command)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: transform.symbol)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 16)
                        Text(transform.title)
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
                .help(transform.response)
            }
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
