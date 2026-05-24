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
    @State private var snapshot: EidosMetrics.Snapshot

    public init() {
        self._snapshot = State(initialValue: EidosMetrics.shared.snapshot())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: backendIcon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(backendTint)
                Text("Retrieved by Eidos")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                Spacer(minLength: 0)
                Text(backendChip)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(backendTint.opacity(0.18))
                    )
                    .overlay(
                        Capsule().stroke(backendTint.opacity(0.34), lineWidth: 0.75)
                    )
                    .foregroundStyle(backendTint)
            }
            if snapshot.lastQueryAt == nil {
                Text("No Eidos retrieve has run yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                metricRow(label: "Citations", value: "\(snapshot.lastCitationCount)")
                metricRow(label: "Last latency", value: latencyLabel)
                metricRow(label: "p95 latency", value: p95Label)
                if let err = snapshot.lastErrorDescription {
                    metricRow(label: "Last error", value: err, valueTint: .red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear { refresh() }
        .onReceive(
            NotificationCenter.default.publisher(
                for: EidosMetrics.didChangeNotification,
                object: EidosMetrics.shared
            )
        ) { _ in
            Task { @MainActor in refresh() }
        }
    }

    public func refresh() {
        snapshot = EidosMetrics.shared.snapshot()
    }

    // MARK: - Honest language

    private var backendIcon: String {
        switch snapshot.lastBackend {
        case .real:    return "lock.shield.fill"
        case .fixture: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private var backendTint: Color {
        switch snapshot.lastBackend {
        case .real:    return .green
        case .fixture: return .orange
        case .unknown: return .secondary
        }
    }

    private var backendChip: String {
        switch snapshot.lastBackend {
        case .real:    return "production vault"
        case .fixture: return "fixture corpus"
        case .unknown: return "no query yet"
        }
    }

    private var latencyLabel: String {
        let ms = snapshot.lastLatencyMs
        if ms < 1 { return String(format: "%.2f ms", ms) }
        if ms < 100 { return String(format: "%.1f ms", ms) }
        return String(format: "%.0f ms", ms)
    }

    private var p95Label: String {
        guard snapshot.sampleCount > 0 else { return "0 samples" }
        let ms = snapshot.p95LatencyMs
        let labelMs = ms < 1
            ? String(format: "%.2f ms", ms)
            : (ms < 100 ? String(format: "%.1f ms", ms) : String(format: "%.0f ms", ms))
        return "\(labelMs) over \(snapshot.sampleCount)"
    }

    @ViewBuilder
    private func metricRow(label: String, value: String, valueTint: Color? = nil) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(valueTint ?? .primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
