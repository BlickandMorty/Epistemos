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
                Image(systemName: "cpu")
                    .foregroundStyle(.blue)
                Text("Omega")
                    .font(.title2.bold())
                Spacer()
                statusBadge
                if orchestrator.isExecuting {
                    Button("Cancel") {
                        orchestrator.cancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()

            Divider()

            // Main content area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Planning indicator
                    if orchestrator.isPlanning {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Planning: \(orchestrator.currentTaskDescription)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Planning error
                    if let error = orchestrator.planningError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.subheadline)
                        }
                        .padding()
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Execution progress (when active or has results)
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
                    if !orchestrator.isExecuting && !orchestrator.isPlanning
                        && orchestrator.executionLog.isEmpty && orchestrator.planningError == nil {
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
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Omega Agent System")
                .font(.headline)
            Text("Enter a task below. Omega uses local AI to plan multi-step workflows and execute them through specialist agents.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Quick action suggestions
            VStack(spacing: 8) {
                Text("Try:")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
                quickActionButton("Open Safari and go to apple.com")
                quickActionButton("List files in my vault")
                quickActionButton("Search the web for MLX benchmarks")
                quickActionButton("Create a new note")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func quickActionButton(_ text: String) -> some View {
        Button {
            taskInput = ""
            Task {
                await orchestrator.submitTask(text)
            }
        } label: {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
