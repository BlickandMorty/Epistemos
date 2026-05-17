import SwiftUI

@MainActor
public struct ActiveConstellationRow: View {
    @Environment(InferenceState.self) private var inference

    public init() {}

    private var models: [LocalAgentDiagnostics.ActiveConstellationModel] {
        LocalAgentDiagnostics.activeConstellationModels(
            activeAgentModelID: inference.effectiveLocalAgentTextModelID,
            activeChatModelID: inference.effectiveLocalTextModelID,
            latestRuntimeModelID: inference.latestLocalRuntimeHealth?.modelID,
            installedModelIDs: Set(inference.releaseSelectableInstalledLocalTextModelIDs)
        )
    }

    private var summary: String {
        let hot = models.filter { $0.state == .hot }.count
        let warm = models.filter { $0.state == .warm }.count
        let cold = models.filter { $0.state == .cold }.count
        return "\(hot) hot · \(warm) warm · \(cold) cold · \(LocalAgentDiagnostics.idleUnloadPolicySummary)"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "circle.hexagongrid.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active constellation")
                        .font(.system(size: 13, weight: .semibold))
                    Text(summary)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
            }

            if models.isEmpty {
                Text("No local-agent route table is available.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(models.prefix(6)) { model in
                        modelRow(model)
                    }
                    if models.count > 6 {
                        Text("+ \(models.count - 6) cold route candidates")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func modelRow(_ model: LocalAgentDiagnostics.ActiveConstellationModel) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: stateSystemImage(model.state))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(stateTint(model.state))
                .frame(width: 14, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(model.rolesSummary)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 4) {
                    chip(model.state.displayName, tint: stateTint(model.state))
                    chip(model.schemaMode, tint: model.schemaMode == "STRICT" ? .green : .orange)
                }
                Text(model.grammar.displayName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    @ViewBuilder
    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(tint.opacity(0.12), in: Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private func stateSystemImage(_ state: LocalAgentDiagnostics.ConstellationRuntimeState) -> String {
        switch state {
        case .hot: "flame.fill"
        case .warm: "bolt.circle.fill"
        case .cold: "circle"
        }
    }

    private func stateTint(_ state: LocalAgentDiagnostics.ConstellationRuntimeState) -> Color {
        switch state {
        case .hot: .green
        case .warm: .orange
        case .cold: .secondary
        }
    }
}

#Preview("ActiveConstellationRow") {
    ActiveConstellationRow()
        .padding()
}
