import SwiftUI

// MARK: - W9.7 — Vault selector (sidebar surface)
//
// Lists the vaults the user has registered (one per model per the
// LIVING_VAULT_ARCHITECTURE: each model has its own vault + graph)
// and lets the user switch the active vault from a single sidebar
// row.
//
// Implementation note: this view is intentionally minimal — the
// full backing (security-scoped bookmark resolution, GRDB container
// swap, graph state reset) is owned by `VaultLifecycleService`
// and `VaultIndexActor` already. This view is just the SwiftUI
// surface that triggers `onSelect(vault)` when the user picks a
// row.
//
// Wiring: drop into `NotesSidebar.swift` next to
// `ModelVaultsSidebarSection`. `onSelect` should trigger the
// existing `VaultLifecycleService.switchVault(to:)` path so the
// container swap, NotesUI reset, and ambient manifest refresh all
// fire in canonical order.

@MainActor
public struct VaultSelectorView: View {

    public struct Vault: Identifiable, Hashable, Sendable {
        public let id: String
        public let displayName: String
        public let modelTag: String?
        public let isActive: Bool

        public init(id: String, displayName: String, modelTag: String?, isActive: Bool) {
            self.id = id
            self.displayName = displayName
            self.modelTag = modelTag
            self.isActive = isActive
        }
    }

    let vaults: [Vault]
    let onSelect: (Vault) -> Void
    @State private var isExpanded: Bool = true

    public init(vaults: [Vault], onSelect: @escaping (Vault) -> Void) {
        self.vaults = vaults
        self.onSelect = onSelect
    }

    public var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(vaults) { vault in
                    row(for: vault)
                }
            }
        } label: {
            Label("Vaults", systemImage: "tray.2")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func row(for vault: Vault) -> some View {
        Button {
            guard !vault.isActive else { return }
            onSelect(vault)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: vault.isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(vault.isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                VStack(alignment: .leading, spacing: 0) {
                    Text(vault.displayName)
                        .font(.callout)
                        .lineLimit(1)
                    if let tag = vault.modelTag {
                        Text(tag)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    VaultSelectorView(
        vaults: [
            .init(id: "v1", displayName: "Default", modelTag: "claude-opus-4-7", isActive: true),
            .init(id: "v2", displayName: "LocalAgent Lab", modelTag: "qwen-3.5-9b", isActive: false),
            .init(id: "v3", displayName: "Research", modelTag: "perplexity-sonar-pro", isActive: false),
        ],
        onSelect: { _ in }
    )
    .padding()
    .frame(width: 220)
}
#endif
