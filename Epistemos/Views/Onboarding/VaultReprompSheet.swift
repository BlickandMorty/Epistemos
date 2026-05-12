import SwiftUI

// MARK: - VaultReprompSheet (ISSUE-2026-05-12-002)
//
// Per-launch sheet that re-prompts the user to connect a vault folder
// when SetupAssistant has completed but no vault is selected. This
// closes the silent-failure gap from ISSUE-2026-05-12-001: a user who
// skipped vault selection during onboarding currently has no recurring
// prompt to set it up, so Halo + Shadow indexing stay invisibly off.
//
// Behavior:
// - Fires once per cold launch when `vaultSync.vaultURL == nil`
// - User can dismiss (sets per-session flag) and continue without a vault
// - Re-fires on the next cold launch — gentle persistent reminder
// - "Select Vault Folder" button calls the existing
//   VaultSyncService.selectVaultFolder helper
//
// Not modal. The user can keep using the app without picking a vault;
// they'll just keep seeing this sheet on next launch until they do.

struct VaultReprompSheet: View {
    let onSelectVault: () -> Void
    let onDismiss: () -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "externaldrive.badge.plus")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(theme.resolved.accent.color)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connect a Vault Folder")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Without a folder, Halo recall and search won't work")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Body explanation
            VStack(alignment: .leading, spacing: 8) {
                Text("What this means:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                bulletRow(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    text: "Your notes still work — they're stored internally"
                )
                bulletRow(
                    icon: "xmark.circle.fill",
                    iconColor: .secondary,
                    text: "Halo, Shadow indexing, and vault search are silently off"
                )
                bulletRow(
                    icon: "folder.fill",
                    iconColor: theme.resolved.accent.color,
                    text: "Picking a folder turns those features on and writes notes there as Markdown files"
                )
            }
            .padding(12)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            // Hint
            Text("You can pick a new empty folder (recommended) or an existing folder of Markdown notes.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // Actions
            HStack(spacing: 8) {
                Button(action: onDismiss) {
                    Text("Continue Without a Vault")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Button(action: onSelectVault) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12, weight: .medium))
                        Text("Select Vault Folder")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.resolved.accent.color)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .frame(minHeight: 320)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connect a vault folder. Halo recall and search require a folder on disk to index your notes.")
    }

    @ViewBuilder
    private func bulletRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
