import SwiftUI

// MARK: - Confirmation Sheet

/// Modal for high/critical risk operations requiring user approval.
struct ConfirmationSheet: View {
    @Environment(OrchestratorState.self) private var orchestrator

    var body: some View {
        if let request = orchestrator.confirmationGate.pendingConfirmation {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Confirmation Required")
                        .font(.headline)
                }

                // Details
                VStack(alignment: .leading, spacing: 8) {
                    detailRow("Action", request.description)
                    detailRow("Tool", request.toolName)
                    detailRow("Risk", request.riskLevel.rawValue.capitalized)
                }

                // Arguments preview
                if !request.argumentsJson.isEmpty && request.argumentsJson != "{}" {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Arguments")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(request.argumentsJson)
                            .font(.caption.monospaced())
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                // Buttons
                HStack {
                    Button("Deny") {
                        orchestrator.confirmationGate.deny()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Approve") {
                        orchestrator.confirmationGate.approve()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.subheadline)
        }
    }
}
