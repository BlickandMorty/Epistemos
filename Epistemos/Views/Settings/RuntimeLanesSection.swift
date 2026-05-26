import SwiftUI

// MARK: - RuntimeLanesSection (Phase 2 Terminal T1 — 2026-05-24)
//
// Settings → Inference → Runtime Lanes. One toggle per
// `RuntimeLane.knownLanes` entry. Flipping a lane OFF persists to
// UserDefaults via `RuntimeRouter.setLaneEnabled(_:_:)` and causes
// the next routing decision through that lane to emit an honest
// `.escalate(from: lane, to: ..., reason: .laneDisabled)` entry — not
// a silent fallback. That property is the acceptance gate for §T1:
// "MLX lane flippable OFF in Settings without breaking chat (falls
//  through to GGUF or cloud with honest 'escalation' log entry)."
//
// Self-contained section so the 2,700-line `SettingsView.swift` only
// needs a single-line include, which keeps the diff narrow next to
// other terminals editing the same file.

@MainActor
public struct RuntimeLanesSection: View {
    @State private var router = RuntimeRouter.shared
    @State private var laneStates: [String: Bool]
    private let lanes: [RuntimeLane]

    public init(lanes: [RuntimeLane] = RuntimeLanesSection.userVisibleLanes()) {
        self.lanes = lanes
        let initial = Dictionary(
            uniqueKeysWithValues: lanes.map { ($0.stableID, RuntimeRouter.shared.isLaneEnabled($0)) }
        )
        self._laneStates = State(initialValue: initial)
    }

    /// Lanes the user can meaningfully toggle. Excludes `.stub` which
    /// is an internal "no real executor present" marker — toggling it
    /// has no user-facing effect and would only confuse the surface.
    public static func userVisibleLanes() -> [RuntimeLane] {
        RuntimeLane.knownLanes.filter { $0 != .stub }
    }

    public var body: some View {
        Section("Runtime Lanes") {
            VStack(alignment: .leading, spacing: 8) {
                Text("MLX is one lane among several. Flip a lane OFF to make the router escalate through the next lane in the chain — escalations are logged honestly, never silent fallbacks.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 4)

            ForEach(lanes, id: \.stableID) { lane in
                Toggle(isOn: bindingForLane(lane)) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(lane.displayName)
                                .font(.body)
                            laneTierBadge(lane)
                        }
                        Text(laneSubtitle(lane))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
        }
    }

    private func bindingForLane(_ lane: RuntimeLane) -> Binding<Bool> {
        Binding(
            get: { laneStates[lane.stableID] ?? router.isLaneEnabled(lane) },
            set: { newValue in
                laneStates[lane.stableID] = newValue
                router.setLaneEnabled(lane, newValue)
            }
        )
    }

    @ViewBuilder
    private func laneTierBadge(_ lane: RuntimeLane) -> some View {
        let capability = RuntimeRouter.defaultStubCapability(for: lane)
        Text(capability.tier.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(badgeColor(for: capability.tier).opacity(0.18))
            )
            .foregroundStyle(badgeColor(for: capability.tier))
    }

    private func badgeColor(for tier: ResidencyTier) -> Color {
        switch tier {
        case .currentApp: return .green
        case .verifiedFloor: return .blue
        case .capabilityCeiling: return .purple
        }
    }

    private func laneSubtitle(_ lane: RuntimeLane) -> String {
        let capability = RuntimeRouter.defaultStubCapability(for: lane)
        let toolMode = capability.toolCallMode.displayName
        let latency = capability.latencyClass.displayName
        let context = capability.contextWindow > 0
            ? "ctx \(formatContext(capability.contextWindow))"
            : "ctx —"
        return "\(latency) · tools \(toolMode) · \(context)"
    }

    private func formatContext(_ n: Int) -> String {
        if n >= 1_000 { return "\(n / 1_000)k" }
        return "\(n)"
    }
}
