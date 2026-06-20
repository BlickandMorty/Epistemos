import SwiftUI

// MARK: - CognitiveWeightClassHealthRow
//
// W-30: badge surface for the four cognitive weight classes.

@MainActor
public struct CognitiveWeightClassHealthRow: View {
    @State private var snapshot: SubstrateHealthUnifiedSnapshot
    @State private var refreshTask: Task<Void, Never>?

    public init() {
        self._snapshot = State(initialValue: SubstrateHealthUnifiedClient.snapshot())
    }

    public var body: some View {
        let weight = snapshot.cognitiveWeight
        VStack(alignment: .leading, spacing: 8) {
            SubstrateHealthMetricLine(
                label: "Cognitive weight classes",
                symbol: "scalemass",
                state: weight.ffiReachable ? .partial : .unavailable,
                detail: "\(weight.classes.count) classes; policy enforcement \(weight.policyEnforcementWired ? "wired" : "not wired")"
            )
            VerifiedFloorChipStrip(
                flag: "n/a",
                substrate: weight.policyEnforcementWired ? "enforced" : "badges only",
                productionWired: weight.policyEnforcementWired,
                falsifierPassed: false,
                falsifier: weight.falsifier,
                wiredToday: "Cognitive weight badges and ranges are visible from the unified health snapshot.",
                stillStub: "Policy enforcement is not a green claim until WBO policy authority has a primary PASS witness."
            )
            HStack(spacing: 6) {
                ForEach(weight.classes) { weightClass in
                    weightBadge(weightClass)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            SubstrateHealthMetricLine(
                label: "Policy authority",
                symbol: "checkmark.shield",
                state: weight.policyEnforcementWired ? .pass : .blocked,
                detail: weight.policyEnforcementWired
                    ? "policy-grade gates wired"
                    : "badge taxonomy visible; enforcement remains T17/T14 follow-up"
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

    @ViewBuilder
    private func weightBadge(_ weightClass: SubstrateHealthUnifiedSnapshot.WeightClass) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(weightClass.badge)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            Text(weightClass.label)
                .font(.system(size: 10, weight: .medium))
            Text(weightClass.range)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(weightClass.policyAuthority ? "authority" : "badge only")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: 70, alignment: .leading)
        .background(weightTint(weightClass).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(weightTint(weightClass).opacity(0.35), lineWidth: 0.8)
        }
        .foregroundStyle(weightTint(weightClass))
    }

    private func weightTint(_ weightClass: SubstrateHealthUnifiedSnapshot.WeightClass) -> Color {
        switch weightClass.badge {
        case "W1": .secondary
        case "W2": .blue
        case "W3": .orange
        case "W4": .red
        default: .secondary
        }
    }

    private func refresh() {
        // SS-SH: fetch OFF the MainActor so the 1Hz poll never blocks the panel.
        Task { snapshot = await SubstrateHealthUnifiedClient.snapshotAsync() }
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
#Preview("CognitiveWeightClassHealthRow") {
    CognitiveWeightClassHealthRow()
        .padding()
        .frame(width: 460)
}
#endif
