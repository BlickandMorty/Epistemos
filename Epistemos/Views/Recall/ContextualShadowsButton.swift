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
            if state.isEnabled, state.hasPanelPayload {
                Button {
                    state.openPanel()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: state.lastErrorMessage == nil ? "sparkles" : "exclamationmark.triangle")
                            .font(.system(size: 10, weight: .semibold))
                        if state.lastErrorMessage == nil {
                            Text("\(state.currentResults.count)")
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .foregroundStyle(state.lastErrorMessage == nil ? Color(nsColor: .tertiaryLabelColor) : Color.orange)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
                    )
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .help(state.lastErrorMessage ?? "Show \(state.currentResults.count) related from your vault")
                .accessibilityLabel(
                    state.lastErrorMessage == nil
                        ? "Show \(state.currentResults.count) related items from your vault"
                        : "Show contextual shadows error"
                )
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: state.currentResults.count)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: state.lastErrorMessage)
    }
}
