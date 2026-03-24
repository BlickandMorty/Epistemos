import SwiftUI

// MARK: - Omega Panel

/// Top-level Omega agent interface. Shows task input, execution progress, and history.
struct OmegaPanel: View {
    @Environment(OrchestratorState.self) private var orchestrator

    @State private var taskInput = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Omega")
                    .font(.title2.bold())
                Spacer()
                statusBadge
            }
            .padding()

            Divider()

            // Main content area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Execution progress (when active)
                    if orchestrator.isExecuting || !orchestrator.executionLog.isEmpty {
                        ExecutionProgressView()
                    }

                    // Confirmation sheet (when pending)
                    if orchestrator.confirmationGate.pendingConfirmation != nil {
                        ConfirmationSheet()
                    }

                    // Research pause (when active)
                    if orchestrator.researchPause.isPaused {
                        ResearchRequestView()
                    }

                    // Idle state
                    if !orchestrator.isExecuting && orchestrator.executionLog.isEmpty {
                        idleView
                    }
                }
                .padding()
            }

            Divider()

            // Task input bar
            TaskInputBar(text: $taskInput) {
                guard !taskInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                let task = taskInput
                taskInput = ""
                Task {
                    await orchestrator.submitTask(task)
                }
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let status = orchestrator.taskGraph.status
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)
            Text(status.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statusColor(_ status: TaskGraphStatus) -> Color {
        switch status {
        case .idle: .secondary
        case .planning: .orange
        case .awaitingConfirmation: .yellow
        case .executing: .blue
        case .completed: .green
        case .failed: .red
        case .paused: .purple
        }
    }

    @ViewBuilder
    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Omega Agent System")
                .font(.headline)
            Text("Enter a task to begin. Omega will plan and execute it through specialist agents.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
