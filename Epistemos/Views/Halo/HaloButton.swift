import SwiftUI

// MARK: - HaloButton
//
// Wave 8.5 of the Extended Program Plan
// (cross-ref `ambient/EPISTEMOS_V1_DECISION.md` §"UI" → "Halo button").
//
// The visible glyph that surfaces the Shadows. Per the V1 decision:
//   - SF Symbol `sparkle.magnifyingglass` (no emoji, no icon clutter)
//   - 24×24 circle with `.ultraThinMaterial` background
//   - Spring animation `.spring(duration: 0.18, bounce: 0.2)` for
//     show/hide
//   - Hidden when state is `.dormant` or `.sensing` (no flicker
//     during typing)
//   - Reduced-motion respected (system handles via the spring API)

/// SwiftUI button overlaid on the editor's trailing edge that opens
/// the Halo panel. Bound to a `HaloController` so the visibility +
/// click handler stay in sync with the state machine.
public struct HaloButton: View {

    let controller: HaloController

    public init(controller: HaloController) {
        self.controller = controller
    }

    /// AR4 (Wave 14 Focus filters) — when the active Focus has the
    /// `muteHaloRecallChip` axis set, the chip stays hidden regardless
    /// of the underlying state machine. Read on every body evaluation
    /// so a SetFocusFilterIntent flip takes effect on the next render
    /// pass without a controller-level subscription.
    private var isMutedByFocus: Bool {
        UserDefaults.standard.bool(forKey: EpistemosFocusKeys.muteHaloRecallChip)
    }

    public var body: some View {
        let visible = controller.state.isVisible && !isMutedByFocus
        Button(action: { controller.openPanel() }) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 24, height: 24)
                .background(.ultraThinMaterial, in: .circle)
        }
        .buttonStyle(.plain)
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.85)
        .animation(.spring(duration: 0.18, bounce: 0.2), value: visible)
        .help("Show related notes & chats")
        .accessibilityLabel("Show contextual recall")
        .accessibilityHint("Reveals related notes and chats based on what you're typing")
    }
}
