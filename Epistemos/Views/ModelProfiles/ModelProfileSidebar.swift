import SwiftUI

// MARK: - Model Profile Sidebar (v2)

/// Sidebar section showing all model profiles with quick-switch toggles.
/// Appears in the main sidebar alongside notes and graph sections.
///
/// Each profile shows: model name, vault name, adapter count, active indicator.
/// Tapping a profile activates it (scopes graph + inference to that profile).
struct ModelProfileSidebar: View {
    let profileManager: ModelProfileManager

    @State private var showingCreationSheet = false

    var body: some View {
        Section {
            ForEach(profileManager.profiles, id: \.id) { profile in
                ModelProfileRow(
                    profile: profile,
                    isActive: profileManager.activeProfile?.id == profile.id,
                    onActivate: {
                        if profileManager.activeProfile?.id == profile.id {
                            profileManager.deactivate()
                        } else {
                            profileManager.activate(profile)
                        }
                    }
                )
            }

            Button {
                showingCreationSheet = true
            } label: {
                Label("New Model Profile", systemImage: "plus.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        } header: {
            HStack {
                Text("Models")
                    .font(.caption.bold())
                Spacer()
                Text("\(profileManager.profiles.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .sheet(isPresented: $showingCreationSheet) {
            ModelProfileCreationSheet(profileManager: profileManager)
        }
    }
}

// MARK: - Profile Row

struct ModelProfileRow: View {
    let profile: SDModelProfile
    let isActive: Bool
    let onActivate: () -> Void

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: 8) {
                // Type indicator
                Image(systemName: profile.isCloudModel ? "cloud.fill" : "cpu.fill")
                    .font(.caption)
                    .foregroundStyle(isActive ? .white : .secondary)
                    .frame(width: 20, height: 20)
                    .background(
                        isActive ? Color.accentColor : Color.secondary.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 4)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.displayName)
                        .font(.caption.bold())
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(profile.vaultDisplayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if !profile.adapterIds.isEmpty {
                            Text("\(profile.adapterIds.count) adapters")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                if isActive {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}
