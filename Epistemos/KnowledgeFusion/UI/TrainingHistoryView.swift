import SwiftUI

// MARK: - TrainingHistoryView

/// List of past training runs with metrics and management actions.
struct TrainingHistoryView: View {
    @Environment(KnowledgeFusionViewModel.self) private var vm

    @State private var expandedId: UUID?

    @ScaledMetric(relativeTo: .caption2) private var typeBadgeSize: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Installed Adapters")
                .font(.headline)

            if vm.installedAdapters.isEmpty {
                ContentUnavailableView(
                    "No Adapters",
                    systemImage: "brain.head.profile",
                    description: Text("Train on a vault to create your first adapter.")
                )
            } else {
                List(vm.installedAdapters) { adapter in
                    adapterRow(adapter)
                }
                .listStyle(.inset)
            }
        }
        .frame(minHeight: 200)
    }

    @ViewBuilder
    private func adapterRow(_ adapter: AdapterRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                typeBadge(adapter.type)

                VStack(alignment: .leading, spacing: 2) {
                    Text(adapter.name)
                        .font(.callout.weight(.medium))
                    Text(adapter.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if let score = adapter.qualityScore {
                    Text(String(format: "%.0f%%", score * 100))
                        .font(.caption.monospaced())
                        .foregroundStyle(score > 0.7 ? .green : score > 0.4 ? .orange : .red)
                }

                if adapter.isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            if expandedId == adapter.id {
                expandedDetails(adapter)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy(duration: 0.2)) {
                expandedId = expandedId == adapter.id ? nil : adapter.id
            }
        }
        .contextMenu {
            Button("Activate") { Task { await vm.activateAdapter(adapter) } }
                .disabled(adapter.isActive)
            Button("Export") { exportAdapter(adapter) }
            Divider()
            Button("Delete", role: .destructive) {
                Task { @MainActor in
                    await requestAdapterDeleteAuthorization(adapter)
                }
            }
        }
    }

    @MainActor
    private func requestAdapterDeleteAuthorization(_ adapter: AdapterRecord) async {
        let target = KnowledgeFusionAdapterDeletionSovereignGate.adapter(name: adapter.name)
        let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
            KnowledgeFusionAdapterDeletionSovereignGate.requirement(for: target),
            reason: KnowledgeFusionAdapterDeletionSovereignGate.reason(for: target)
        ) ?? .denied(.authenticationFailed)

        guard outcome == .allowed else { return }

        await vm.deleteAdapter(adapter)
    }

    @ViewBuilder
    private func expandedDetails(_ adapter: AdapterRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            detailRow("Rank", "\(adapter.loraRank)")
            detailRow("Base Model", adapter.baseModel)
            detailRow("Source", adapter.sourceVault)
            detailRow("Examples", "\(adapter.trainingExamples)")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.leading, 28)
        .padding(.top, 4)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .frame(minWidth: 80, alignment: .leading)
            Text(value)
                .foregroundStyle(.primary)
        }
    }

    private func typeBadge(_ type: AdapterType) -> some View {
        Text(type.rawValue.prefix(1).uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: typeBadgeSize, height: typeBadgeSize)
            .background(colorForType(type), in: RoundedRectangle(cornerRadius: 4))
    }

    private func colorForType(_ type: AdapterType) -> Color {
        switch type {
        case .knowledge: return .blue
        case .style: return .purple
        case .tool: return .orange
        case .kto: return .green
        }
    }

    private func exportAdapter(_ adapter: AdapterRecord) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.data]
        panel.nameFieldStringValue = "\(adapter.name).\(AdapterExporter.bundleExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            _ = await vm.exportAdapter(adapter, outputURL: url)
        }
    }
}
