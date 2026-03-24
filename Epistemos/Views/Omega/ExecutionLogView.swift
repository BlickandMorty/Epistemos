import SwiftUI

// MARK: - Execution Log View

/// Historical view of past execution results.
struct ExecutionLogView: View {
    @Environment(OrchestratorState.self) private var orchestrator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Execution Log")
                    .font(.headline)
                Spacer()
                Text("\(orchestrator.executionLog.count) results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if orchestrator.executionLog.isEmpty {
                Text("No executions yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(orchestrator.executionLog, id: \.stepId) { result in
                    HStack(spacing: 8) {
                        Image(systemName: result.success ? "checkmark.circle" : "xmark.circle")
                            .foregroundStyle(result.success ? .green : .red)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            if let error = result.error {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Text(String(result.outputJson.prefix(100)))
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Text("\(result.durationMs)ms")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
