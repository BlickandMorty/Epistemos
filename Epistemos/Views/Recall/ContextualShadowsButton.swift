import SwiftUI

// MARK: - ContextualShadowsButton
// Patch 7 / AMBIENT_RECALL_WIRING_PLAN.md §5 — subtle composer-corner button
// that surfaces the recall panel when ambient hits exist. Hidden entirely
// when the V0 flag is OFF or `currentResults` is empty so the composer
// chrome reads as inert in cold state.
//
// No animations beyond `.transition(.opacity)`, gated on `reduceMotion`.
// The button uses tertiaryLabel-equivalent foreground so it does not steal
// attention from the primary composer affordances.

struct ContextualShadowsButton: View {
    @Environment(ContextualShadowsState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if state.isEnabled, !state.currentResults.isEmpty {
                Button {
                    state.openPanel()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(state.currentResults.count)")
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
                    )
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Show \(state.currentResults.count) related from your vault")
                .accessibilityLabel("Show \(state.currentResults.count) related items from your vault")
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: state.currentResults.count)
    }
}
