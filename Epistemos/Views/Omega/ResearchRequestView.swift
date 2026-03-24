import SwiftUI

// MARK: - Research Request View

/// Shows when the agent needs user research input to continue.
struct ResearchRequestView: View {
    @Environment(OrchestratorState.self) private var orchestrator

    @State private var responseText = ""

    var body: some View {
        if let request = orchestrator.researchPause.activeRequest {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .foregroundStyle(.purple)
                    Text("Research Needed")
                        .font(.headline)
                }

                // Questions
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(request.questions.enumerated()), id: \.offset) { index, question in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                            Text(question)
                                .font(.subheadline)
                        }
                    }
                }

                // Context
                if !request.context.isEmpty {
                    Text("Context: \(request.context)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Response input
                TextEditor(text: $responseText)
                    .font(.subheadline)
                    .frame(minHeight: 60, maxHeight: 120)
                    .padding(4)
                    .background(.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                // Buttons
                HStack {
                    Button("Skip") {
                        orchestrator.researchPause.skip()
                    }

                    Spacer()

                    Button("Provide Research") {
                        orchestrator.researchPause.provideResponse(responseText)
                        responseText = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
