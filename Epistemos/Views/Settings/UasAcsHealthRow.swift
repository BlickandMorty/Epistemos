import SwiftUI

// MARK: - UasAcsHealthRow
//
// W-10: UAS / ACS (Anchored Cognitive Substrate) status surface.
// The row is intentionally honest: address taxonomy and residency
// tiers are reachable, while production anchor lookup remains blocked
// until the MAS runtime uses the T14 anchor registry path directly.

@MainActor
public struct UasAcsHealthRow: View {
    @State private var snapshot: SubstrateHealthUnifiedSnapshot
    @State private var refreshTask: Task<Void, Never>?

    public init() {
        self._snapshot = State(initialValue: SubstrateHealthUnifiedClient.snapshot())
    }

    public var body: some View {
        let uas = snapshot.uasAcs
        VStack(alignment: .leading, spacing: 8) {
            SubstrateHealthMetricLine(
                label: "UAS address taxonomy",
                symbol: "point.3.connected.trianglepath.dotted",
                state: uas.ffiReachable ? .partial : .unavailable,
                detail: "\(uas.knownUasKinds.count) known kinds; \(uas.residencyTiers.count) residency tiers"
            )
            VerifiedFloorChipStrip(
                flag: "n/a",
                substrate: uas.productionAnchorLookupWired ? "anchor lookup" : "taxonomy only",
                productionWired: uas.productionAnchorLookupWired,
                falsifierPassed: false,
                falsifier: uas.falsifier,
                wiredToday: "UAS kind taxonomy, residency tiers, and copy counters are readable.",
                stillStub: "Production anchor lookup is not green until primary PASS evidence is tied to the MAS path."
            )
            SubstrateHealthMetricLine(
                label: "Copy counters",
                symbol: "arrow.triangle.2.circlepath",
                state: uas.ffiReachable ? .partial : .unavailable,
                detail: "copies=\(uas.copyCount) allocs=\(uas.allocCount) bytes=\(uas.bytesAllocated)"
            )
            SubstrateHealthMetricLine(
                label: "ACS anchor lookup",
                symbol: "lock.shield",
                state: uas.productionAnchorLookupWired ? .pass : .blocked,
                detail: uas.productionAnchorLookupWired
                    ? "production anchor lookup wired"
                    : "harness passed; production registry adapter pending"
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
#Preview("UasAcsHealthRow") {
    UasAcsHealthRow()
        .padding()
        .frame(width: 460)
}
#endif
