import SwiftUI

// MARK: - Model Graph Filter (v2)

/// Toggle section for filtering the knowledge graph by model profile.
/// Designed to be embedded in the graph overlay panel alongside existing
/// node type and edge type filters.
///
/// When a model is selected, the graph shows only nodes from that model's
/// vault (its knowledge base). Deselecting returns to the global view.
struct ModelGraphFilterView: View {
    let profileManager: ModelProfileManager
    let filterEngine: FilterEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Model Filter", systemImage: "cpu")
                    .font(.caption.bold())
                Spacer()
                if filterEngine.selectedModelProfileId != nil {
                    Button("Clear") {
                        filterEngine.clearModelFilter()
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            if profileManager.profiles.isEmpty {
                Text("No model profiles created")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(profileManager.profiles, id: \.id) { profile in
                    ModelFilterToggle(
                        profile: profile,
                        isSelected: filterEngine.selectedModelProfileId == profile.id,
                        onToggle: {
                            if filterEngine.selectedModelProfileId == profile.id {
                                filterEngine.clearModelFilter()
                            } else {
                                filterEngine.setModelFilter(
                                    profileId: profile.id,
                                    vaultKey: profile.vaultIdentityKey
                                )
                            }
                        }
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Individual Toggle

private struct ModelFilterToggle: View {
    let profile: SDModelProfile
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                Image(systemName: profile.isCloudModel ? "cloud.fill" : "cpu.fill")
                    .font(.caption2)
                    .foregroundStyle(profileColor)

                Text(profile.displayName)
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                Text(profile.vaultDisplayName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if !profile.adapterIds.isEmpty {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(
                isSelected ? Color.accentColor.opacity(0.08) : .clear,
                in: RoundedRectangle(cornerRadius: 4)
            )
        }
        .buttonStyle(.plain)
    }

    private var profileColor: Color {
        if profile.isCloudModel { return .blue }
        return .orange
    }
}
