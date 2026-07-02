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
    @Environment(UIState.self) private var ui
    @Environment(ContextualShadowsState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var scopeKind: RecallContextKind?
    var scopeID: String?

    private var theme: EpistemosTheme {
        ui.theme
    }

    private var payload: ContextualShadowsState.RecallPayload {
        state.payload(kind: scopeKind, originDocId: scopeID)
    }

    var body: some View {
        Group {
            if state.isEnabled, payload.hasPanelPayload {
                Button {
                    state.openPanel(kind: scopeKind, originDocId: scopeID)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: payload.errorMessage == nil ? "sparkles" : "exclamationmark.triangle")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text("IR")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .monospacedDigit()
                        if payload.errorMessage == nil {
                            Text(payload.isSearching ? "..." : "\(payload.results.count)")
                                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(payload.errorMessage == nil ? theme.textPrimary : Color.orange)
                    .background { recallChipBackground }
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(helpText)
                .accessibilityLabel(accessibilityText)
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: payload.results.count)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: payload.errorMessage)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: payload.isSearching)
    }

    private var helpText: String {
        if let errorMessage = payload.errorMessage {
            return errorMessage
        }
        if payload.isSearching {
            return "Searching related items"
        }
        return "Show \(payload.results.count) related from your vault"
    }

    private var accessibilityText: String {
        if payload.isSearching {
            return "Searching related items from your vault"
        }
        if payload.errorMessage != nil {
            return "Show contextual shadows error"
        }
        return "Show \(payload.results.count) related items from your vault"
    }

    private var recallChipBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return shape
            .fill(.regularMaterial)
            .overlay {
                shape.fill(theme.card.opacity(theme.isDark ? 0.74 : 0.9))
            }
            .overlay {
                shape.strokeBorder(
                    payload.errorMessage == nil
                        ? theme.resolved.accent.color.opacity(theme.isDark ? 0.5 : 0.34)
                        : Color.orange.opacity(0.5),
                    lineWidth: 1
                )
            }
            .shadow(color: .black.opacity(theme.isDark ? 0.22 : 0.12), radius: 10, x: 0, y: 6)
    }
}
