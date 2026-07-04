import SwiftUI

// MARK: - FrictionHealthRow
//
// Settings diagnostic surfacing the writing-friction telemetry stream.
//
// FrictionMonitorService records editor friction on every keystroke and
// persists one FrictionWindow per editing session into EventStore's
// `friction_windows` table (frictionScore, pause rate, deletion density,
// burst-length CV, regression frequency). Until this row, NOTHING read those
// windows back — `EventStore.frictionWindows(limit:)` had no caller and the
// `friction.threshold` setting had no reader, so a live, persisted telemetry
// stream was collected into a void. This surfaces it (recent session count,
// the latest window's friction score, and how many sessions crossed the
// user's threshold), connecting a live producer to its first reader.
//
// Read-only. Mirrors the EditorBundleHealthRow / SearchFusionHealthRow shape
// and reuses the shared `SubstrateHealthMetricLine`; refresh is driven by the
// panel's `.substrateHealthPoll` clock, exactly like its sibling rows.

@MainActor
public struct FrictionHealthRow: View {

    @AppStorage("friction.enabled") private var frictionEnabled = true
    @AppStorage("friction.threshold") private var frictionThreshold = 1.5

    @State private var windows: [FrictionWindow] = []

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SubstrateHealthMetricLine(
                label: "Friction telemetry",
                symbol: "waveform.path.ecg",
                state: collectionState,
                detail: collectionDetail
            )
            SubstrateHealthMetricLine(
                label: "Latest session",
                symbol: "gauge.with.dots.needle.50percent",
                state: latestState,
                detail: latestDetail
            )
            SubstrateHealthMetricLine(
                label: "Above threshold",
                symbol: "chart.bar.doc.horizontal",
                state: aboveThresholdCount == 0 ? .pass : .partial,
                detail: aboveThresholdDetail
            )
        }
        .substrateHealthPoll { refresh() }
    }

    /// Re-read the persisted friction windows (most-recent first).
    public func refresh() {
        windows = EventStore.shared?.frictionWindows(limit: 200) ?? []
    }

    // MARK: - Display

    /// `frictionWindows(limit:)` returns windows most-recent first, so the head
    /// is the latest editing session.
    private var latest: FrictionWindow? { windows.first }

    private var collectionState: SubstrateHealthSignalState {
        guard frictionEnabled else { return .unavailable }
        return windows.isEmpty ? .partial : .pass
    }

    private var collectionDetail: String {
        guard frictionEnabled else { return "friction.enabled = false — collection off" }
        return windows.isEmpty
            ? "Enabled — no sessions recorded yet (edit a note to populate)"
            : "\(windows.count) session windows recorded"
    }

    private var latestState: SubstrateHealthSignalState {
        guard let latest else { return frictionEnabled ? .partial : .unavailable }
        return latest.frictionScore > frictionThreshold ? .partial : .pass
    }

    private var latestDetail: String {
        guard let latest else { return frictionEnabled ? "No sessions yet" : "Collection off" }
        let ago = Self.relativeTime(Date(timeIntervalSince1970: latest.windowEnd))
        return String(format: "friction score %.2f (%@)", latest.frictionScore, ago)
    }

    private var aboveThresholdCount: Int {
        windows.filter { $0.frictionScore > frictionThreshold }.count
    }

    private var aboveThresholdDetail: String {
        guard !windows.isEmpty else { return "No sessions to compare" }
        return String(
            format: "%d of %d sessions above threshold %.2f",
            aboveThresholdCount, windows.count, frictionThreshold
        )
    }

    private static func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 1 { return "just now" }
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3_600 { return "\(Int(interval / 60))m ago" }
        if interval < 86_400 { return "\(Int(interval / 3_600))h ago" }
        return "\(Int(interval / 86_400))d ago"
    }
}

#if DEBUG
#Preview("FrictionHealthRow") {
    FrictionHealthRow()
        .padding()
        .frame(width: 480)
}
#endif
