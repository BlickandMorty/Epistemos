import SwiftUI

// MARK: - SubstrateDriftMonitorHealthRow
//
// W-33: drift monitor row. It combines WBO accounting, DAG root, and
// UAS copy counters through a 1 Hz Rust FFI snapshot. It does not mark
// F-WBO-DriftLedger passed until a falsifier artifact exists.

@MainActor
public struct SubstrateDriftMonitorHealthRow: View {
    @State private var snapshot: SubstrateHealthUnifiedSnapshot
    @State private var refreshTask: Task<Void, Never>?

    public init() {
        self._snapshot = State(initialValue: SubstrateHealthUnifiedClient.snapshot())
    }

    public var body: some View {
        let drift = snapshot.driftMonitor
        VStack(alignment: .leading, spacing: 8) {
            SubstrateHealthMetricLine(
                label: "Substrate drift monitor",
                symbol: "waveform.path",
                state: drift.ffiReachable ? .partial : .unavailable,
                detail: "WBO appends=\(drift.wboAppendsAccounted) tier=\(drift.wboTier)"
            )
            VerifiedFloorChipStrip(
                flag: "n/a",
                substrate: drift.falsifierPassed ? "falsifier PASS" : "monitor only",
                substrateTint: drift.falsifierPassed ? .green : .orange
            )
            SubstrateHealthMetricLine(
                label: "Copy drift",
                symbol: "arrow.triangle.2.circlepath",
                state: drift.ffiReachable ? .partial : .unavailable,
                detail: "copies=\(drift.copyCount) allocs=\(drift.allocCount)"
            )
            SubstrateHealthMetricLine(
                label: "DAG root",
                symbol: "number",
                state: drift.dagRoot.isEmpty ? .unavailable : .partial,
                detail: drift.dagRoot.isEmpty ? "unavailable" : String(drift.dagRoot.prefix(16))
            )
            SubstrateHealthMetricLine(
                label: "F-WBO-DriftLedger",
                symbol: "checkmark.shield",
                state: drift.falsifierPassed ? .pass : .blocked,
                detail: drift.falsifierPassed ? "PASS artifact present" : "not passed on M2 Pro yet"
            )
        }
        .onAppear {
            refresh()
            startTimer()
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    private func refresh() {
        snapshot = SubstrateHealthUnifiedClient.snapshot()
    }

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
}

#if DEBUG
#Preview("SubstrateDriftMonitorHealthRow") {
    SubstrateDriftMonitorHealthRow()
        .padding()
        .frame(width: 460)
}
#endif
