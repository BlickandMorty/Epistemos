import SwiftUI

enum AgentUnavailableReason {
    case appleIntelligenceNoAgent
    case localModelLacksAgentCapability
}

struct AgentModeUnavailableView: View {
    let reason: AgentUnavailableReason
    let modelName: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "cpu.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("Agent Mode Unavailable")
                .font(.title2.weight(.semibold))

            Text(explanationText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            HStack(spacing: 12) {
                Label(modelName, systemImage: "cpu")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.orange.opacity(0.12)))
                    .foregroundStyle(.orange)

                Label("No Agent", systemImage: "xmark.circle")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    .foregroundStyle(.secondary)
            }

            Text(suggestionText)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Button {
                UtilityWindowManager.shared.show(.settings)
            } label: {
                Label("Open Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var explanationText: String {
        switch reason {
        case .appleIntelligenceNoAgent:
            "Apple Intelligence provides fast local replies but does not support multi-step tool execution. Switch to a cloud or larger local model for full capabilities."
        case .localModelLacksAgentCapability:
            "\(modelName) does not support agentic tool use. Choose a larger local model (4B+ with tool support) or a cloud model."
        }
    }

    private var suggestionText: String {
        switch reason {
        case .appleIntelligenceNoAgent:
            "Cloud models (Claude, GPT, Gemini) support persistent sessions, tool execution, and memory. Larger local models like Qwen 3.5 4B+ also work."
        case .localModelLacksAgentCapability:
            "Models like Qwen 3.5 4B+, Devstral, or Mistral Small support local tool loops. Cloud models give the most capable experience."
        }
    }
}
