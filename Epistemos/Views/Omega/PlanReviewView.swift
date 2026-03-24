import SwiftUI

// MARK: - Plan Review View

/// Shows the execution plan as an editable step list before execution begins.
struct PlanReviewView: View {
    @Environment(OrchestratorState.self) private var orchestrator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundStyle(.blue)
                Text("Execution Plan")
                    .font(.headline)
                Spacer()
                Text("\(orchestrator.taskGraph.steps.count) steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(orchestrator.taskGraph.steps.enumerated()), id: \.element.id) { index, step in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .frame(width: 20)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.description)
                            .font(.subheadline)
                        Text("\(step.assignedAgent) → \(step.toolName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 2)
            }

            HStack {
                Button("Cancel") {
                    orchestrator.cancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Execute") {
                    Task {
                        await orchestrator.executePlan()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
