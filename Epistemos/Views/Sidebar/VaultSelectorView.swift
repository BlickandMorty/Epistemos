import SwiftUI

// MARK: - W9.7 — Vault selector (sidebar surface)
//
// Lists vault rows supplied by the caller. In v1 the notes sidebar
// only has a confirmed active-vault row, so it renders this view as
// read-only status. Selection becomes live only when the caller
// supplies a real switch handler and selectable vaults.
//
// Implementation note: this view is intentionally minimal — the
// full backing (security-scoped bookmark resolution, GRDB container
// swap, graph state reset) is owned by `VaultLifecycleService`
// and `VaultIndexActor` already. This view is just the SwiftUI
// surface that can trigger `onSelect(vault)` when the user picks a
// selectable row.
//
// Wiring: callers that have a real `VaultLifecycleService` switch
// path should pass `selectionEnabled: true` and an `onSelect`
// handler. Callers without that path should keep the surface read-only.

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
    let selectionEnabled: Bool
    let onSelect: ((Vault) -> Void)?
    @State private var isExpanded: Bool = true

    public init(
        vaults: [Vault],
        selectionEnabled: Bool = true,
        onSelect: ((Vault) -> Void)? = nil
    ) {
        self.vaults = vaults
        self.selectionEnabled = selectionEnabled
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
        if canSelect(vault), let onSelect {
            Button {
                onSelect(vault)
            } label: {
                rowContent(for: vault, isSelectable: true)
            }
            .buttonStyle(.plain)
        } else {
            rowContent(for: vault, isSelectable: false)
                .accessibilityElement(children: .combine)
        }
    }

    private func canSelect(_ vault: Vault) -> Bool {
        selectionEnabled && !vault.isActive && onSelect != nil
    }

    private func rowContent(for vault: Vault, isSelectable: Bool) -> some View {
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
        .opacity(isSelectable || vault.isActive ? 1.0 : 0.65)
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
