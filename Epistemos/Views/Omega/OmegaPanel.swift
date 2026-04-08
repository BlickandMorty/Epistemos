import SwiftUI

// MARK: - Omega Panel (Retired)
// All intelligence capabilities are unified in the main chat.

struct OmegaPanel: View {
    @Environment(OrchestratorState.self) private var orchestrator

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Unified Chat")
                .font(.title2.weight(.semibold))

            Text("All capabilities — tools, reasoning, and knowledge — are built into the main chat.\nSwitch to the Home panel and ask anything.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
