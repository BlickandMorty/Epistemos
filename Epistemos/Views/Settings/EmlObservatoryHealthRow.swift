import SwiftUI

// MARK: - EmlObservatoryHealthRow
//
// W-07: EML observatory substrate visibility. Polls the unified Rust
// FFI once per second and reports whether the EML potential adapter is
// reachable. It does not claim the SAE live stream is product-wired.

@MainActor
public struct EmlObservatoryHealthRow: View {
    @State private var snapshot: SubstrateHealthUnifiedSnapshot
    @Environment(SubstrateHealthClock.self) private var healthClock: SubstrateHealthClock?

    public init() {
        self._snapshot = State(initialValue: SubstrateHealthUnifiedClient.snapshot())
    }

    public var body: some View {
        let eml = snapshot.emlObservatory
        VStack(alignment: .leading, spacing: 8) {
            SubstrateHealthMetricLine(
                label: "EML observatory",
                symbol: "waveform.path.ecg",
                state: eml.ffiReachable ? .partial : .unavailable,
                detail: eml.ffiReachable
                    ? "FFI reachable; SAE live stream not wired"
                    : unavailableDetail
            )
            VerifiedFloorChipStrip(
                flag: "n/a",
                substrate: eml.liveStreamWired ? "live stream" : "substrate self-test",
                productionWired: eml.liveStreamWired,
                falsifierPassed: false,
                falsifier: eml.falsifier,
                wiredToday: "EML observatory self-test values are projected from the unified FFI snapshot.",
                stillStub: "SAE live stream and primary F-ULP witness coupling are not production-green here."
            )
            SubstrateHealthMetricLine(
                label: "Augmented AUC",
                symbol: "chart.xyaxis.line",
                state: eml.augmentedAuc >= eml.aucBar && eml.ffiReachable ? .partial : .unavailable,
                detail: String(format: "auc=%.3f bar=%.2f sample=%d", eml.augmentedAuc, eml.aucBar, eml.sampleObservations)
            )
            SubstrateHealthMetricLine(
                label: "Potential summary",
                symbol: "function",
                state: eml.summaryCount > 0 ? .partial : .unavailable,
                detail: potentialDetail(eml)
            )
        }
        .substrateHealthPoll { if let unified = healthClock?.unified { snapshot = unified } }
    }

    private var unavailableDetail: String {
        snapshot.ffiErrorDescription ?? "agent_core FFI unavailable"
    }

    private func potentialDetail(_ eml: SubstrateHealthUnifiedSnapshot.EmlObservatory) -> String {
        let mean = eml.meanPotential.map { String(format: "%.3f", $0) } ?? "n/a"
        return "n=\(eml.summaryCount) pos=\(eml.summaryPositives) neg=\(eml.summaryNegatives) mean=\(mean)"
    }
}

#if DEBUG
#Preview("EmlObservatoryHealthRow") {
    EmlObservatoryHealthRow()
        .padding()
        .frame(width: 460)
}
#endif
