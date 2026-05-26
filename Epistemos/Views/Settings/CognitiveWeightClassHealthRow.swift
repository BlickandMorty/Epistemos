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
        let displayClasses = weight.classes.isEmpty ? Self.fallbackClasses : weight.classes
        VStack(alignment: .leading, spacing: 8) {
            SubstrateHealthMetricLine(
                label: "Cognitive weight classes",
                symbol: "scalemass",
                state: weight.ffiReachable ? .partial : .unavailable,
                detail: "\(displayClasses.count) classes; policy enforcement \(weight.policyEnforcementWired ? "wired" : "not wired")"
            )
            VerifiedFloorChipStrip(
                flag: "n/a",
                substrate: weight.policyEnforcementWired ? "enforced" : "badges only",
                substrateTint: .orange
            )
            HStack(spacing: 6) {
                ForEach(displayClasses) { weightClass in
                    weightBadge(weightClass)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            SubstrateHealthMetricLine(
                label: "Policy authority",
                symbol: "checkmark.shield",
                state: weight.policyEnforcementWired ? .pass : .partial,
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

    private static let fallbackClasses: [SubstrateHealthUnifiedSnapshot.WeightClass] = [
        .init(badge: "W1", label: "light", className: "soft", range: "0.00-0.30", policyAuthority: false),
        .init(badge: "W2", label: "medium", className: "preferred", range: "0.31-0.60", policyAuthority: false),
        .init(badge: "W3", label: "heavy", className: "strong_anchor", range: "0.61-0.85", policyAuthority: false),
        .init(badge: "W4", label: "extreme", className: "policy_grade", range: "0.86-1.00", policyAuthority: false),
    ]
}

#if DEBUG
#Preview("CognitiveWeightClassHealthRow") {
    CognitiveWeightClassHealthRow()
        .padding()
        .frame(width: 460)
}
#endif
