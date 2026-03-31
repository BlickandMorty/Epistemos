import SwiftUI

// MARK: - Semantic Zoom Controller (Omega-6)

/// 5-level semantic zoom for agent execution graph visualization.
///
/// Each zoom level reveals progressively more detail:
/// 1. Overview — task + agents only (bird's eye)
/// 2. Agents — task + agents + tool categories
/// 3. Steps — all execution steps visible
/// 4. Tools — steps + individual tools
/// 5. Detail — everything including results and metadata
enum SemanticZoomLevel: Int, CaseIterable, Sendable {
    case overview = 1
    case agents = 2
    case steps = 3
    case tools = 4
    case detail = 5

    var label: String {
        switch self {
        case .overview: "Overview"
        case .agents: "Agents"
        case .steps: "Steps"
        case .tools: "Tools"
        case .detail: "Detail"
        }
    }

    /// Whether to show text labels at this zoom level.
    var showsLabels: Bool {
        self.rawValue >= SemanticZoomLevel.steps.rawValue
    }

    /// Whether to show result nodes at this zoom level.
    var showsResults: Bool {
        self.rawValue >= SemanticZoomLevel.detail.rawValue
    }

    /// Whether to show dependency edges at this zoom level.
    var showsDependencies: Bool {
        self.rawValue >= SemanticZoomLevel.steps.rawValue
    }

    /// Minimum node weight to display at this zoom level.
    var minWeight: Double {
        switch self {
        case .overview: 0.8
        case .agents: 0.5
        case .steps: 0.3
        case .tools: 0.1
        case .detail: 0.0
        }
    }
}

// MARK: - Zoom Controls View

/// Inline zoom control strip for the graph view.
struct SemanticZoomControlStrip: View {
    @Binding var level: SemanticZoomLevel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SemanticZoomLevel.allCases, id: \.self) { zoom in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        level = zoom
                    }
                } label: {
                    Text("\(zoom.rawValue)")
                        .font(.caption2.monospacedDigit())
                        .frame(width: 20, height: 20)
                        .background(
                            level == zoom ? Color.accentColor : Color.secondary.opacity(0.2),
                            in: Circle()
                        )
                        .foregroundStyle(level == zoom ? .white : .primary)
                }
                .buttonStyle(.plain)
                .help(zoom.label)
            }
        }
    }
}
