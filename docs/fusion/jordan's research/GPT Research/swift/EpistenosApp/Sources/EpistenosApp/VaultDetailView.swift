import SwiftUI

struct VaultDetailView: View {
    @Bindable var vault: Vault
    @State private var unlocked = false
    @State private var gateMessage = "Locked"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(vault.name).font(.largeTitle.bold())
                Spacer()
                Button(unlocked ? "Lock" : "Unlock") { toggleLock() }
            }
            Text(gateMessage).foregroundStyle(unlocked ? .green : .secondary)
            AgentDashboardView()
            ResonanceGateView()
            Spacer()
        }
        .padding()
    }

    private func toggleLock() {
        if unlocked {
            unlocked = false
            vault.locked = true
            gateMessage = "Locked; agents terminated"
            return
        }
        BiometricGate.authenticate(reason: "Unlock vault \(vault.name)") { ok in
            Task { @MainActor in
                unlocked = ok
                vault.locked = !ok
                gateMessage = ok ? "Unlocked by biometric gate" : "Unlock denied"
            }
        }
    }
}
