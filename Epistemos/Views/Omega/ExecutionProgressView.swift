import SwiftUI

// MARK: - Execution Progress View

/// Shows live progress of the current task: step list with status indicators,
/// expandable error details, and retry/reset actions.
struct ExecutionProgressView: View {
    @Environment(OrchestratorState.self) private var orchestrator

    @State private var expandedErrorStepId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !orchestrator.currentTaskDescription.isEmpty {
                Text(orchestrator.currentTaskDescription)
                    .font(.headline)
            }

            ForEach(orchestrator.taskGraph.steps) { step in
                stepRow(step)
            }

            // Action buttons after execution completes
            if !orchestrator.isExecuting && !orchestrator.isPlanning && !orchestrator.executionLog.isEmpty {
                actionButtons
            }
        }
    }

    @ViewBuilder
    private func stepRow(_ step: AgentStep) -> some View {
        let result = orchestrator.taskGraph.results[step.id]
        let isActive = result == nil && orchestrator.isExecuting
        let isFailed = result?.success == false

        VStack(alignment: .leading, spacing: 0) {
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

                // Error expand toggle
                if isFailed {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedErrorStepId = expandedErrorStepId == step.id ? nil : step.id
                        }
                    } label: {
                        Image(systemName: expandedErrorStepId == step.id ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                // Risk badge
                riskBadge(step.riskLevel)
            }
            .padding(.vertical, 4)

            // Expanded error details
            if isFailed, expandedErrorStepId == step.id, let result {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Error Details")
                        .font(.caption.bold())
                    Text(result.outputJson)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text("Arguments: \(step.argumentsJson)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.leading, 30)
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        let hasFailed = orchestrator.taskGraph.hasFailed
        HStack(spacing: 12) {
            if hasFailed {
                Button {
                    Task {
                        await orchestrator.retryTask()
                    }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button {
                orchestrator.reset()
            } label: {
                Label(hasFailed ? "Dismiss" : "Done", systemImage: hasFailed ? "xmark" : "checkmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.top, 4)
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
