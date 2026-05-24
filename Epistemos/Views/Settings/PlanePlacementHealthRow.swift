import SwiftUI

// MARK: - PlanePlacementHealthRow
//
// Terminal G dependency row. It keeps five-plane placement visible
// without pretending NodeKind has plane fields before T14 lands.

@MainActor
public struct PlanePlacementHealthRow: View {
    @State private var snapshot: SubstrateHealthUnifiedSnapshot
    @State private var refreshTask: Task<Void, Never>?

    public init() {
        self._snapshot = State(initialValue: SubstrateHealthUnifiedClient.snapshot())
    }

    public var body: some View {
        let plane = snapshot.planePlacement
        VStack(alignment: .leading, spacing: 8) {
            SubstrateHealthMetricLine(
                label: "Plane placement",
                symbol: "square.stack.3d.up",
                state: plane.planeFieldsWired ? .pass : .blocked,
                detail: plane.planeFieldsWired ? planeSummary(plane) : "blocked on \(plane.dependency)"
            )
            VerifiedFloorChipStrip(
                flag: "n/a",
                substrate: plane.planeFieldsWired ? "five-plane counts" : "Terminal G dependency",
                substrateTint: plane.planeFieldsWired ? .green : .red
            )
            SubstrateHealthMetricLine(
                label: "Unplaced nodes",
                symbol: "questionmark.diamond",
                state: plane.unplacedCount == 0 && plane.planeFieldsWired ? .pass : .blocked,
                detail: "\(plane.unplacedCount) DAG nodes lack plane fields today"
            )
            SubstrateHealthMetricLine(
                label: "Five planes",
                symbol: "rectangle.split.3x1",
                state: plane.planeFieldsWired ? .pass : .blocked,
                detail: planeSummary(plane)
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

    private func planeSummary(_ p: SubstrateHealthUnifiedSnapshot.PlanePlacement) -> String {
        "state=\(p.stateCount) episodic=\(p.episodicCount) assembly=\(p.assemblyCount) controller=\(p.controllerCount) verification=\(p.verificationCount)"
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
#Preview("PlanePlacementHealthRow") {
    PlanePlacementHealthRow()
        .padding()
        .frame(width: 460)
}
#endif
