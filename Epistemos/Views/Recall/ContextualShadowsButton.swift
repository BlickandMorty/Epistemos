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

    var scopeKind: RecallContextKind?
    var scopeID: String?

    private var payload: ContextualShadowsState.RecallPayload {
        state.payload(kind: scopeKind, originDocId: scopeID)
    }

    var body: some View {
        Group {
            if state.isEnabled, payload.hasPanelPayload {
                Button {
                    state.openPanel(kind: scopeKind, originDocId: scopeID)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: payload.errorMessage == nil ? "sparkles" : "exclamationmark.triangle")
                            .font(.system(size: 10, weight: .semibold))
                        if payload.errorMessage == nil {
                            Text("\(payload.results.count)")
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .foregroundStyle(payload.errorMessage == nil ? Color(nsColor: .tertiaryLabelColor) : Color.orange)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
                    )
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .help(payload.errorMessage ?? "Show \(payload.results.count) related from your vault")
                .accessibilityLabel(
                    payload.errorMessage == nil
                        ? "Show \(payload.results.count) related items from your vault"
                        : "Show contextual shadows error"
                )
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: payload.results.count)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: payload.errorMessage)
    }
}
