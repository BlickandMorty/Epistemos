// EidosRetrievedSection.swift
//
// Terminal A 2026-05-23 — W-48 Brain Panel "Retrieved by Eidos" surface.
//
// Compact, embeddable section that surfaces the most recent
// `EidosBridge.retrieve(...)` outcome: backend, manifest_id (short),
// citation count, latency, and the chip-strip honest language.
//
// Designed to be embedded inside `ChatBrainPanelView` AND any other
// surface that wants a glance at Eidos's last contribution. Reads
// from `EidosMetrics.shared` only — does not call any FFI itself.
//
// **7-Law focus:** Law 7 Witness (surfaces the active-substrate
// retrieve outcome verbatim from EidosMetrics, no recomputation).
// **Tier:** Tier 1 (MAS).

import SwiftUI

@MainActor
public struct EidosRetrievedSection: View {
    @Environment(UIState.self) private var ui
    @State private var eidosSnapshot: EidosMetrics.Snapshot
    @State private var vaultSnapshot: VaultRecallMetrics.Snapshot

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.mainChat) }

    public init() {
        self._eidosSnapshot = State(initialValue: EidosMetrics.shared.snapshot())
        self._vaultSnapshot = State(initialValue: VaultRecallMetrics.shared.snapshot())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: backendIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(backendTint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Evidence Intake")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Eidos + VaultRecall")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(backendChip)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(backendTint.opacity(0.18)))
                    .overlay(Capsule().stroke(backendTint.opacity(0.34), lineWidth: 0.75))
                    .foregroundStyle(backendTint)
            }

            if eidosSnapshot.lastQueryAt == nil, vaultSnapshot.lastQueryAt == nil {
                Text("No evidence query has run yet for this launch.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if eidosSnapshot.lastQueryAt != nil {
                    GroupBox("Eidos") {
                        VStack(alignment: .leading, spacing: 6) {
                            metricRow(label: "Citations", value: "\(eidosSnapshot.lastCitationCount)")
                            metricRow(label: "Last latency", value: eidosLatencyLabel)
                            metricRow(label: "p95 latency", value: eidosP95Label)
                            if let err = eidosSnapshot.lastErrorDescription {
                                metricRow(label: "Last error", value: err, valueTint: .red)
                            }
                        }
                        .padding(.top, 2)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .groupBoxStyle(EidosEvidenceGroupBoxStyle(theme: theme))
                } else if vaultSnapshot.lastQueryAt != nil {
                    GroupBox("Eidos") {
                        VStack(alignment: .leading, spacing: 6) {
                            metricRow(label: "Citation gate", value: "not invoked", valueTint: .orange)
                            Text("VaultRecall produced candidates. Eidos will show citations here when the answer path asks for closed evidence validation.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 2)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .groupBoxStyle(EidosEvidenceGroupBoxStyle(theme: theme))
                }

                if vaultSnapshot.lastQueryAt != nil {
                    GroupBox("VaultRecall") {
                        VStack(alignment: .leading, spacing: 6) {
                            metricRow(label: "Backend", value: vaultBackendLabel, valueTint: vaultTint)
                            metricRow(label: "Retained", value: "\(vaultSnapshot.lastCandidatesRetained)")
                            metricRow(label: "Last latency", value: vaultLatencyLabel)
                            if !vaultSnapshot.lastSignalSummary.isEmpty {
                                metricRow(label: "Signals", value: vaultSignalsLabel)
                            }
                            if let pageGather = vaultSnapshot.lastPageGather {
                                metricRow(label: "PageGather", value: pageGather.scheduleLabel ?? pageGather.source)
                            }
                            if let err = vaultSnapshot.lastErrorDescription {
                                metricRow(label: "Last error", value: err, valueTint: .red)
                            }
                        }
                        .padding(.top, 2)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .groupBoxStyle(EidosEvidenceGroupBoxStyle(theme: theme))
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .eidosEvidenceCard(theme: theme, emphasized: true)
        .onAppear { refresh() }
        .onReceive(
            NotificationCenter.default.publisher(
                for: EidosMetrics.didChangeNotification,
                object: EidosMetrics.shared
            )
        ) { _ in
            Task { @MainActor in refresh() }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: VaultRecallMetrics.didChangeNotification,
                object: VaultRecallMetrics.shared
            )
        ) { _ in
            Task { @MainActor in refresh() }
        }
    }

    public func refresh() {
        eidosSnapshot = EidosMetrics.shared.snapshot()
        vaultSnapshot = VaultRecallMetrics.shared.snapshot()
    }

    // MARK: - Honest language

    private var backendIcon: String {
        if eidosSnapshot.lastQueryAt != nil {
            switch eidosSnapshot.lastBackend {
            case .real:    return "lock.shield.fill"
            case .fixture: return "exclamationmark.triangle.fill"
            case .unknown: return "questionmark.circle"
            }
        }
        if vaultSnapshot.lastQueryAt != nil {
            switch vaultSnapshot.lastBackend {
            case .real: return "checkmark.shield.fill"
            case .stub: return "wrench.and.screwdriver.fill"
            case .unknown: return "questionmark.circle"
            }
        }
        return "questionmark.circle"
    }

    private var backendTint: Color {
        if eidosSnapshot.lastQueryAt != nil {
            switch eidosSnapshot.lastBackend {
            case .real:    return .green
            case .fixture: return .orange
            case .unknown: return .secondary
            }
        }
        if vaultSnapshot.lastQueryAt != nil {
            return vaultTint
        }
        return .secondary
    }

    private var backendChip: String {
        if eidosSnapshot.lastQueryAt != nil {
            switch eidosSnapshot.lastBackend {
            case .real:    return "Eidos real"
            case .fixture: return "Eidos fixture"
            case .unknown: return "Eidos unknown"
            }
        }
        if vaultSnapshot.lastQueryAt != nil {
            return "VaultRecall \(vaultBackendLabel)"
        }
        return "no query yet"
    }

    private var eidosLatencyLabel: String {
        latencyLabel(eidosSnapshot.lastLatencyMs)
    }

    private var vaultLatencyLabel: String {
        latencyLabel(vaultSnapshot.lastLatencyMs)
    }

    private func latencyLabel(_ ms: Double) -> String {
        if ms < 1 { return String(format: "%.2f ms", ms) }
        if ms < 100 { return String(format: "%.1f ms", ms) }
        return String(format: "%.0f ms", ms)
    }

    private var eidosP95Label: String {
        guard eidosSnapshot.sampleCount > 0 else { return "0 samples" }
        let ms = eidosSnapshot.p95LatencyMs
        let labelMs = ms < 1
            ? String(format: "%.2f ms", ms)
            : (ms < 100 ? String(format: "%.1f ms", ms) : String(format: "%.0f ms", ms))
        return "\(labelMs) over \(eidosSnapshot.sampleCount)"
    }

    private var vaultBackendLabel: String {
        switch vaultSnapshot.lastBackend {
        case .real: return "real path"
        case .stub: return "scaffold"
        case .unknown: return "unknown"
        }
    }

    private var vaultTint: Color {
        switch vaultSnapshot.lastBackend {
        case .real: return .green
        case .stub: return .orange
        case .unknown: return .secondary
        }
    }

    private var vaultSignalsLabel: String {
        vaultSnapshot.lastSignalSummary
            .map(\.rawValue)
            .sorted()
            .joined(separator: ", ")
    }

    @ViewBuilder
    private func metricRow(label: String, value: String, valueTint: Color? = nil) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(valueTint ?? .primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct EidosEvidenceGroupBoxStyle: GroupBoxStyle {
    let theme: EpistemosTheme

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            configuration.label
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(theme.textTertiary)
            configuration.content
        }
        .padding(10)
        .eidosEvidenceCard(theme: theme, emphasized: false)
    }
}

private struct EidosEvidenceCardModifier: ViewModifier {
    let theme: EpistemosTheme
    let emphasized: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        content
            .background {
                ZStack {
                    shape.fill(theme.card.opacity(theme.isDark ? (emphasized ? 0.70 : 0.52) : (emphasized ? 0.82 : 0.66)))
                    shape.fill(theme.resolved.foreground.color.opacity(theme.isDark ? 0.024 : 0.014))
                }
            }
            .overlay {
                shape.strokeBorder(theme.border.opacity(emphasized ? 0.60 : 0.42), lineWidth: 0.75)
            }
    }
}

private extension View {
    func eidosEvidenceCard(theme: EpistemosTheme, emphasized: Bool) -> some View {
        modifier(EidosEvidenceCardModifier(theme: theme, emphasized: emphasized))
    }
}
