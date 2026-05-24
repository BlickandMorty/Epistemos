import SwiftUI

// MARK: - EidosHealthRow
//
// Wiring #1 (T10 Eidos → QueryRuntime) settings diagnostic.
// Mirrors `SearchFusionHealthRow` shape so the Settings sheet keeps a
// consistent diagnostic vocabulary across retrieval surfaces.
//
// Surfaces:
//   - flag state (`EPISTEMOS_EIDOS_V0` UserDefaults / env)
//   - last query latency
//   - p95 latency over the most recent ~200 samples
//   - last citation count
//   - total queries served this process
//   - last error (if any)
//
// Reads from `EidosMetrics.shared`. Refresh is event-driven via
// `EidosMetrics.didChangeNotification` — no polling needed.

@MainActor
public struct EidosHealthRow: View {

    @State private var snapshot: EidosMetrics.Snapshot
    @State private var refreshTask: Task<Void, Never>?

    public init() {
        self._snapshot = State(initialValue: EidosMetrics.shared.snapshot())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "Eidos V0 flag",
                symbol: "flag.fill",
                ok: snapshot.isFlagEnabled,
                detail: flagDetail
            )
            VerifiedFloorChipStrip(
                flag: snapshot.isFlagEnabled ? "on" : "off",
                substrate: chipSubstrateLabel,
                substrateTint: chipSubstrateTint
            )
            row(
                label: "Last query",
                symbol: "clock",
                ok: snapshot.lastQueryAt != nil && snapshot.lastErrorDescription == nil,
                detail: lastQueryDetail
            )
            row(
                label: "p95 latency",
                symbol: "chart.line.uptrend.xyaxis",
                ok: snapshot.sampleCount > 0 && snapshot.p95LatencyMs <= 30.0,
                detail: p95Detail
            )
            row(
                label: "Last citation count",
                symbol: "quote.bubble",
                ok: snapshot.lastCitationCount > 0 || !snapshot.isFlagEnabled,
                detail: lastCitationDetail
            )
            if let err = snapshot.lastErrorDescription {
                row(
                    label: "Last error",
                    symbol: "exclamationmark.triangle",
                    ok: false,
                    detail: err
                )
            }
        }
        .onAppear {
            refresh()
            startTimer()
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
        .onReceive(NotificationCenter.default.publisher(
            for: EidosMetrics.didChangeNotification,
            object: EidosMetrics.shared
        )) { _ in
            Task { @MainActor in
                refresh()
            }
        }
    }

    public func refresh() {
        snapshot = EidosMetrics.shared.snapshot()
    }

    // MARK: - Backend-aware chip language (Terminal A 2026-05-23 W-46.1)
    //
    // Honest chip-strip language: the substrate chip reflects which
    // retriever actually produced the most recent packet. Per PR #57
    // chip-strip pattern + WRV "Verified" bar, the row must not claim
    // "working against vault" when the last packet came from fixture.

    private var flagDetail: String {
        if !snapshot.isFlagEnabled {
            return "EPISTEMOS_EIDOS_V0 off (legacy FTS/RRF path)"
        }
        switch snapshot.lastBackend {
        case .real:
            return "EPISTEMOS_EIDOS_V0 on — production vault binding active"
        case .fixture:
            return "EPISTEMOS_EIDOS_V0 on (fixture path active)"
        case .unknown:
            return "EPISTEMOS_EIDOS_V0 on — no query observed yet"
        }
    }

    private var chipSubstrateLabel: String {
        switch snapshot.lastBackend {
        case .real:    return "production-vault"
        case .fixture: return "fixture"
        case .unknown: return "unknown"
        }
    }

    private var chipSubstrateTint: Color {
        switch snapshot.lastBackend {
        case .real:    return .green
        case .fixture: return .orange
        case .unknown: return .secondary
        }
    }

    private var lastCitationDetail: String {
        if snapshot.lastQueryAt == nil { return "(no Eidos query yet)" }
        switch snapshot.lastBackend {
        case .real:
            return "\(snapshot.lastCitationCount) citation(s) from real vault corpus"
        case .fixture:
            return "\(snapshot.lastCitationCount) citation(s) from fixture corpus, not vault"
        case .unknown:
            return "\(snapshot.lastCitationCount) citation(s) — backend unknown"
        }
    }

    // MARK: - Periodic refresh (from unify-substrate-health 2026-05-23)
    //
    // 1 Hz refresh so chip strip + backend label stay live without polling
    // on the consumer side. Cancelled on view disappear.

    private func startTimer() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                refresh()
            }
        }
    }

    private var lastQueryDetail: String {
        if let err = snapshot.lastErrorDescription, snapshot.lastQueryAt == nil {
            return "Error: \(err)"
        }
        guard let date = snapshot.lastQueryAt else {
            return snapshot.isFlagEnabled
                ? "No queries yet — run a search to populate"
                : "Flag off — Eidos path not exercised"
        }
        let elapsed = formatLatency(snapshot.lastLatencyMs)
        let ago = Self.relativeTime(date)
        return "\(elapsed) (\(ago)) — \(snapshot.totalQueries) total"
    }

    private var p95Detail: String {
        guard snapshot.sampleCount > 0 else { return "0 samples" }
        return "\(formatLatency(snapshot.p95LatencyMs)) over \(snapshot.sampleCount) samples"
    }

    private func formatLatency(_ ms: Double) -> String {
        if ms < 1.0 { return String(format: "%.2f ms", ms) }
        if ms < 100.0 { return String(format: "%.1f ms", ms) }
        return String(format: "%.0f ms", ms)
    }

    private static func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 1 { return "just now" }
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3_600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3_600))h ago"
    }

    @ViewBuilder
    private func row(label: String, symbol: String, ok: Bool, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.red))
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
