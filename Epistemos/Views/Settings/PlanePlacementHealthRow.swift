import SwiftUI

// MARK: - PlanePlacementHealthRow
//
// T14 five-plane UAS witness row. The Rust DAG schema now carries
// UAS address, ACS anchor, runtime plane, and residency metadata on
// every NodeKind variant. This row reads the unified substrate-health
// FFI snapshot so the visible counts stay honest.

@MainActor
// UAS: settings/plane-placement-health-row
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CurrentApp
public struct PlanePlacementHealthRow: View {
    @State private var snapshot: SubstrateHealthUnifiedSnapshot
    @Environment(SubstrateHealthClock.self) private var healthClock: SubstrateHealthClock?

    public init() {
        self._snapshot = State(initialValue: SubstrateHealthUnifiedClient.snapshot())
    }

    public var body: some View {
        let plane = snapshot.planePlacement
        VStack(alignment: .leading, spacing: 8) {
            SubstrateHealthMetricLine(
                label: "Plane placement",
                symbol: "square.stack.3d.up",
                state: placementState(plane),
                detail: placementDetail(plane)
            )
            VerifiedFloorChipStrip(
                flag: "n/a",
                substrate: chipLabel(plane),
                productionWired: plane.planeFieldsWired && plane.ffiReachable,
                falsifierPassed: false,
                falsifier: plane.falsifier,
                wiredToday: "T14 plane fields and per-plane counts are visible when agent_core FFI is reachable.",
                stillStub: "Green requires schema-conforming primary PASS evidence for the production placement path."
            )
            SubstrateHealthMetricLine(
                label: "Unplaced nodes",
                symbol: "questionmark.diamond",
                state: unplacedState(plane),
                detail: "\(plane.unplacedCount) DAG nodes lack plane fields"
            )
            SubstrateHealthMetricLine(
                label: "Five planes",
                symbol: "rectangle.split.3x1",
                state: placementState(plane),
                detail: planeSummary(plane)
            )
        }
        .substrateHealthPoll { if let unified = healthClock?.unified { snapshot = unified } }
    }

    private func placementState(
        _ p: SubstrateHealthUnifiedSnapshot.PlanePlacement
    ) -> SubstrateHealthSignalState {
        guard p.ffiReachable else { return .unavailable }
        return p.planeFieldsWired ? .pass : .blocked
    }

    private func unplacedState(
        _ p: SubstrateHealthUnifiedSnapshot.PlanePlacement
    ) -> SubstrateHealthSignalState {
        guard p.ffiReachable else { return .unavailable }
        guard p.planeFieldsWired else { return .blocked }
        return p.unplacedCount == 0 ? .pass : .partial
    }

    private func planeSummary(_ p: SubstrateHealthUnifiedSnapshot.PlanePlacement) -> String {
        "state=\(p.stateCount) episodic=\(p.episodicCount) assembly=\(p.assemblyCount) controller=\(p.controllerCount) verification=\(p.verificationCount)"
    }

    private func placementDetail(_ p: SubstrateHealthUnifiedSnapshot.PlanePlacement) -> String {
        guard p.ffiReachable else { return "agent_core FFI unavailable" }
        return p.planeFieldsWired ? planeSummary(p) : "blocked on \(p.dependency)"
    }

    private func chipLabel(_ p: SubstrateHealthUnifiedSnapshot.PlanePlacement) -> String {
        guard p.ffiReachable else { return "FFI unavailable" }
        return p.planeFieldsWired ? "read-only counts" : "Terminal G dependency"
    }
}

#if DEBUG
#Preview("PlanePlacementHealthRow") {
    PlanePlacementHealthRow()
        .padding()
        .frame(width: 460)
}
#endif
