import SwiftUI

@MainActor
public struct LocalAgentDiagnosticsHealthRow: View {
    @Environment(InferenceState.self) private var inference
    @State private var snapshot: LocalAgentDiagnostics.Snapshot

    public init() {
        self._snapshot = State(initialValue: LocalAgentDiagnostics.snapshot())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local agent diagnostics")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Strict grammar, schema drift, and constellation routing")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            diagnosticRow(
                label: "Strict-grammar status",
                value: snapshot.strictGrammarSummary,
                systemImage: snapshot.strictMaskingAvailable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                accent: snapshot.strictMaskingAvailable ? .green : .orange
            )
            diagnosticRow(
                label: "Schema-drift detector",
                value: snapshot.schemaDriftSummary,
                systemImage: snapshot.totalSchemaDriftEvents == 0 ? "checkmark.circle" : "waveform.path.ecg",
                accent: snapshot.totalSchemaDriftEvents == 0 ? .green : .orange
            )
            diagnosticRow(
                label: "Soft-guidance fallback",
                value: snapshot.softGuidanceSummary,
                systemImage: snapshot.totalSoftGuidanceToolPlans == 0 ? "arrow.triangle.2.circlepath" : "arrow.down.forward.circle",
                accent: snapshot.totalSoftGuidanceToolPlans == 0 ? .secondary : .orange
            )
            diagnosticRow(
                label: "Constellation health",
                value: constellationHealthDetail,
                systemImage: inference.supportsLocalAgentLoop ? "circle.hexagongrid.fill" : "circle.hexagongrid",
                accent: inference.supportsLocalAgentLoop ? .green : .secondary
            )

            if !snapshot.modelCounters.isEmpty {
                Divider().padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent model counters")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(snapshot.modelCounters.prefix(3)) { counter in
                        modelCounterRow(counter)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear(perform: refresh)
        .onReceive(
            NotificationCenter.default.publisher(for: LocalAgentDiagnostics.didChangeNotification)
        ) { _ in
            refresh()
        }
    }

    private var constellationHealthDetail: String {
        var parts = [snapshot.constellationSummary]
        if let activeModelID = inference.effectiveLocalAgentTextModelID {
            let activeName = LocalTextModelID(rawValue: activeModelID)?.displayName ?? activeModelID
            let grammar = LocalToolGrammar.nativeGrammar(forModelID: activeModelID).displayName
            parts.append("active=\(activeName) · \(grammar)")
        } else {
            parts.append("active=none")
        }
        parts.append(snapshot.hotRoleSummary)
        return parts.joined(separator: " · ")
    }

    private func refresh() {
        snapshot = LocalAgentDiagnostics.snapshot()
    }

    @ViewBuilder
    private func diagnosticRow(
        label: String,
        value: String,
        systemImage: String,
        accent: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(accent)
                .frame(width: 14, alignment: .center)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func modelCounterRow(_ counter: LocalAgentDiagnostics.ModelCounter) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "cpu")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .center)
            Text(counter.displayName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Text(counter.grammarDisplayName)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text("strict \(counter.strictGrammarFallbacks) · soft \(counter.softGuidanceToolPlans) · drift \(counter.schemaDriftEvents)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

#Preview("LocalAgentDiagnosticsHealthRow") {
    LocalAgentDiagnosticsHealthRow()
        .padding()
}
