import SwiftUI

/// Data MED-3 diagnostic — surfaces whether the vault is receiving saves.
///
/// A sustained export-failure streak means the vault volume/path became
/// unreachable (a network/USB volume dropped, the folder was moved) and recent
/// edits aren't reaching disk. The edits are NOT lost — they stay pending and
/// retry on the next tick / on reconnect — but the user/admin should know saves
/// aren't currently landing. Read-only; matches the other Settings health rows.
@MainActor
struct VaultSaveHealthRow: View {
    @State private var streak = 0
    @State private var lastError: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: healthy
                ? "externaldrive.fill.badge.checkmark"
                : "externaldrive.trianglebadge.exclamationmark")
                .foregroundStyle(healthy ? Color.green : Color.orange)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("Vault save")
                    .font(.system(size: 12, weight: .semibold))
                Text(healthy
                    ? "Notes are saving to the vault normally."
                    : "Vault unreachable — recent edits aren't reaching disk. They stay pending and retry automatically when it reconnects.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if !healthy, let lastError {
                    Text(lastError)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .onAppear(perform: refresh)
        .task {
            // Light poll while the Settings sheet is open (mirrors the other rows).
            while !Task.isCancelled {
                refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var healthy: Bool { streak < 2 }

    private func refresh() {
        let service = AppBootstrap.shared?.vaultSync
        streak = service?.vaultSaveFailureStreak ?? 0
        lastError = service?.lastVaultSaveError
    }
}
