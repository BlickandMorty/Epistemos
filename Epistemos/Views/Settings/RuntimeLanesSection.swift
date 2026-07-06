import SwiftUI

public struct RuntimeLanesSection: View {
    private let router = RuntimeRouter.shared
    @State private var laneStates: [String: Bool] = Dictionary(
        uniqueKeysWithValues: RuntimeLanesSection.userVisibleLanes().map {
            ($0.stableID, RuntimeRouter.shared.isLaneEnabled($0))
        }
    )

    public init() {}

    public static func userVisibleLanes() -> [RuntimeLane] {
        // The stub lane is an internal "no real executor present" marker.
        RuntimeLane.knownLanes.filter { $0 != .stub }
    }

    public var body: some View {
        Section {
            ForEach(Self.userVisibleLanes(), id: \.stableID) { lane in
                Toggle(
                    lane.displayName,
                    isOn: Binding(
                        get: { laneStates[lane.stableID] ?? router.isLaneEnabled(lane) },
                        set: { newValue in
                            laneStates[lane.stableID] = newValue
                            router.setLaneEnabled(lane, newValue)
                        }
                    )
                )
            }
        } header: {
            Text("Runtime Lanes")
        } footer: {
            Text(".stub is an internal \"no real executor present\" marker and is intentionally hidden.")
        }
    }
}
