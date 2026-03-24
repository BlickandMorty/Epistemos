import SwiftUI

// MARK: - Execution Progress View

/// Shows live progress of the current task: step list with status indicators.
struct ExecutionProgressView: View {
    @Environment(OrchestratorState.self) private var orchestrator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !orchestrator.currentTaskDescription.isEmpty {
                Text(orchestrator.currentTaskDescription)
                    .font(.headline)
            }

            ForEach(orchestrator.taskGraph.steps) { step in
                stepRow(step)
            }
        }
    }

    @ViewBuilder
    private func stepRow(_ step: AgentStep) -> some View {
        let result = orchestrator.taskGraph.results[step.id]
        let isActive = result == nil && orchestrator.isExecuting

        HStack(spacing: 10) {
            // Status icon
            Group {
                if let result {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.success ? .green : .red)
                } else if isActive {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.description)
                    .font(.subheadline)
                HStack(spacing: 6) {
                    Text(step.assignedAgent)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.15))
                        .clipShape(Capsule())
                    Text(step.toolName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let result {
                        Text("\(result.durationMs)ms")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Risk badge
            riskBadge(step.riskLevel)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func riskBadge(_ level: RiskLevel) -> some View {
        Text(level.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(riskColor(level).opacity(0.15))
            .foregroundStyle(riskColor(level))
            .clipShape(Capsule())
    }

    private func riskColor(_ level: RiskLevel) -> Color {
        switch level {
        case .low: .green
        case .medium: .yellow
        case .high: .orange
        case .critical: .red
        }
    }
}
