import SwiftUI

// MARK: - Omega Panel (Retired)
// Agent interactions now go through main chat via Rust agent_core.

struct OmegaPanel: View {
    @Environment(OrchestratorState.self) private var orchestrator

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Agent Mode")
                .font(.title2.weight(.semibold))

            Text("Agent capabilities are now built into the main chat.\nSwitch to the Home panel and ask anything.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
