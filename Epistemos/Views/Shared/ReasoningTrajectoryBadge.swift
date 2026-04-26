import SwiftUI

// MARK: - ReasoningTrajectoryBadge
//
// Wave 9.3 — surfaces the agent reasoning quality classification that
// `agent_core/src/reasoning_metrics.rs` already computes after every
// agent session. The Rust side classifies into one of five buckets
// (Efficient / Exploratory / Hesitating / Stuck / Failed); this view
// renders the bucket as a colored pip + tooltip with the underlying
// loop count, error count, total tool calls, and efficiency scalar.
//
// Persistence path: `agent_core` returns `ReasoningTrajectoryMetricsFFI`
// at session end → `ChatCoordinator` calls `EventStore.saveSessionMetrics`
// → SQLite row in `session_metrics`. This view reads the row via
// `EventStore.loadSessionMetrics(sessionId:)` and renders. If no row
// exists yet (session in flight or pre-W9.3 history) the badge stays
// hidden — silent absence is preferable to a placeholder.
//
// Wire-up: drop `ReasoningTrajectoryBadge(sessionId: ...)` next to any
// session header in chat / session list / agent inspector. The badge
// auto-hides for missing sessions so it's safe to include in lists
// of mixed historical and in-flight sessions.

@MainActor
public struct ReasoningTrajectoryBadge: View {

    public let sessionId: String

    @State private var record: EventStore.SessionMetricsRecord?

    public init(sessionId: String) {
        self.sessionId = sessionId
    }

    public var body: some View {
        Group {
            if let record {
                badge(for: record)
                    .help(tooltip(for: record))
            } else {
                EmptyView()
            }
        }
        .task(id: sessionId) {
            record = EventStore.shared?.loadSessionMetrics(sessionId: sessionId)
        }
    }

    @ViewBuilder
    private func badge(for record: EventStore.SessionMetricsRecord) -> some View {
        let category = Category(classification: record.classification)
        HStack(spacing: 4) {
            Image(systemName: category.glyph)
                .font(.system(size: 10, weight: .semibold))
            Text(category.label)
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(category.color.opacity(0.18))
        )
        .overlay(
            Capsule()
                .strokeBorder(category.color.opacity(0.45), lineWidth: 0.5)
        )
        .foregroundStyle(category.color)
    }

    private func tooltip(for record: EventStore.SessionMetricsRecord) -> String {
        let parts = [
            "Reasoning: \(record.classification)",
            "Tool calls: \(record.totalCalls)",
            "Loops: \(record.loopCount)",
            "Errors: \(record.errorCount)",
            "Efficiency: \(String(format: "%.0f%%", record.efficiency * 100))",
        ]
        return parts.joined(separator: "\n")
    }
}

// MARK: - Category

extension ReasoningTrajectoryBadge {
    fileprivate enum Category {
        case efficient, exploratory, hesitating, stuck, failed, unknown

        init(classification: String) {
            switch classification.lowercased() {
            case "efficient":   self = .efficient
            case "exploratory": self = .exploratory
            case "hesitating":  self = .hesitating
            case "stuck":       self = .stuck
            case "failed":      self = .failed
            default:            self = .unknown
            }
        }

        var label: String {
            switch self {
            case .efficient:   return "Efficient"
            case .exploratory: return "Exploring"
            case .hesitating:  return "Hesitating"
            case .stuck:       return "Stuck"
            case .failed:      return "Failed"
            case .unknown:     return "Run"
            }
        }

        var glyph: String {
            switch self {
            case .efficient:   return "checkmark.circle.fill"
            case .exploratory: return "arrow.triangle.branch"
            case .hesitating:  return "exclamationmark.circle"
            case .stuck:       return "circle.dotted"
            case .failed:      return "xmark.circle.fill"
            case .unknown:     return "circle"
            }
        }

        var color: Color {
            switch self {
            case .efficient:   return .green
            case .exploratory: return .blue
            case .hesitating:  return .yellow
            case .stuck:       return .orange
            case .failed:      return .red
            case .unknown:     return .secondary
            }
        }
    }
}

#if DEBUG
#Preview("ReasoningTrajectoryBadge — fixture record") {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(["Efficient", "Exploratory", "Hesitating", "Stuck", "Failed"], id: \.self) { c in
            HStack {
                Text(c)
                    .frame(width: 100, alignment: .leading)
                ReasoningTrajectoryBadge.previewBadge(classification: c)
            }
        }
    }
    .padding(20)
}

extension ReasoningTrajectoryBadge {
    @ViewBuilder
    public static func previewBadge(classification: String) -> some View {
        let category = Category(classification: classification)
        HStack(spacing: 4) {
            Image(systemName: category.glyph)
                .font(.system(size: 10, weight: .semibold))
            Text(category.label)
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(category.color.opacity(0.18)))
        .overlay(Capsule().strokeBorder(category.color.opacity(0.45), lineWidth: 0.5))
        .foregroundStyle(category.color)
    }
}
#endif
