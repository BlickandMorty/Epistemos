import SwiftUI

struct ModeSwitcherControl: View {
    let modeStore: SidebarModeStore

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SidebarMode.allCases) { mode in
                Button {
                    modeStore.select(mode)
                } label: {
                    Label(mode.shortLabel, systemImage: mode.systemImage)
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            mode == modeStore.currentMode
                                ? Color.accentColor.opacity(0.18)
                                : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(mode == modeStore.currentMode ? .primary : .secondary)
                .keyboardShortcut(keyEquivalent(for: mode), modifiers: .command)
                .help(helpText(for: mode))
            }
        }
        .padding(3)
        .background(.quaternary.opacity(0.55), in: Capsule())
    }

    private func keyEquivalent(for mode: SidebarMode) -> KeyEquivalent {
        switch mode {
        case .myVault:
            "1"
        case .modelVaults:
            "2"
        case .system:
            "3"
        }
    }

    private func helpText(for mode: SidebarMode) -> String {
        switch mode {
        case .myVault:
            "Show My Vault"
        case .modelVaults:
            "Show Model Vaults"
        case .system:
            "Show System"
        }
    }
}
