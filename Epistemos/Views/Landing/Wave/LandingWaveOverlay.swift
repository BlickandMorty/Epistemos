import SwiftUI

/// Full-surface Metal wave layer + tap-to-dismiss scrim.
///
/// This overlay used to host a compact flat search bar, but the search
/// UI has moved into the landing greeting itself — `LiquidGreeting`
/// backspaces away, types `search: `, and accepts typed input inline.
/// The overlay's only responsibility now is rendering the liquid wave
/// behind everything and forwarding outside-bar clicks to `onDismiss`.
struct LandingWaveOverlay: View {
    @Binding var isActive: Bool
    let clickLocation: CGPoint?
    let cursorDirection: CGVector
    let dropTrigger: Int
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UIState.self) private var ui

    var body: some View {
        ZStack {
            // ── Scrim: invisible, full-surface tap → dismiss ──
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            // ── Wave layer: Metal renderer; hit-testing disabled so the
            //                scrim underneath still receives outside taps ──
            if !reduceMotion, !ui.windowOccluded {
                LandingWaveMetalView(
                    isActive: isActive,
                    reduceMotion: reduceMotion,
                    dropTrigger: dropTrigger,
                    clickLocation: clickLocation,
                    cursorDirection: cursorDirection
                )
                .allowsHitTesting(false)
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }
}
