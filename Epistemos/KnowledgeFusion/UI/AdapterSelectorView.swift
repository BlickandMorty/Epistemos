import SwiftUI

// MARK: - AdapterSelectorView

/// Dropdown/picker for loading and unloading adapters.
/// Shows adapter name, type badge, quality score.
struct AdapterSelectorView: View {
    @Environment(KnowledgeFusionViewModel.self) private var vm

    var body: some View {
        Menu {
            Button {
                Task { await vm.deactivateAdapter() }
            } label: {
                Label("None (Base Model)", systemImage: "cpu")
            }

            Divider()

            ForEach(vm.installedAdapters) { adapter in
                Button {
                    Task { await vm.activateAdapter(adapter) }
                } label: {
                    HStack {
                        Label(adapter.name, systemImage: iconForType(adapter.type))
                        if adapter.isActive {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            if vm.installedAdapters.isEmpty {
                Text("No adapters installed")
                    .foregroundStyle(.secondary)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: currentIcon)
                    .font(.caption)
                Text(currentLabel)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.5), in: Capsule())
        }
        .menuStyle(.borderlessButton)
    }

    private var currentLabel: String {
        vm.activeAdapter?.name ?? "Base Model"
    }

    private var currentIcon: String {
        guard let adapter = vm.activeAdapter else { return "cpu" }
        return iconForType(adapter.type)
    }

    private func iconForType(_ type: AdapterType) -> String {
        switch type {
        case .knowledge: return "book.closed.fill"
        case .style: return "paintbrush.fill"
        case .tool: return "wrench.fill"
        case .kto: return "hand.thumbsup.fill"
        }
    }
}
