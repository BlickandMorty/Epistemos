import SwiftUI

// Owner #1 (no hidden GPT route) — VISIBLE local-resolve trace (rule #8). Shows
// whether the user's local PICK is honored, was substituted for a different
// installed model (and why), or whether nothing local is ready — so "local shows
// GPT / I picked X but got Y" is never silent. Reads InferenceState from the
// environment (same pattern as LocalAgentDiagnosticsHealthRow).
struct LocalRouteHonestyHealthRow: View {
    @Environment(InferenceState.self) private var inference

    var body: some View {
        let state = inference.localModelResolutionState
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: icon(for: state))
                    .foregroundStyle(tint(for: state))
                Text("Local route honesty")
                    .font(.callout.weight(.medium))
                Spacer(minLength: 0)
            }
            Text(state.summary ?? "Your local pick resolves — local stays local, never a silent cloud route.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func icon(for state: LocalModelResolutionState) -> String {
        switch state {
        case .usingPick: "checkmark.seal"
        case .substituted: "arrow.triangle.swap"
        case .noLocalModel: "exclamationmark.triangle"
        }
    }

    private func tint(for state: LocalModelResolutionState) -> Color {
        switch state {
        case .usingPick: .green
        case .substituted: .orange
        case .noLocalModel: .red
        }
    }
}
