import SwiftUI

/// SwiftUI container that replaces the legacy `NSPopover` path on landing.
///
/// Layout order (bottom → top):
///   1. **Scrim layer** — invisible full-surface shape that accepts clicks
///      outside the bar and forwards them to `onDismiss`. Captures the ESC key.
///   2. **Metal wave layer** — the liquid ASCII surface. Hit-testing disabled
///      so background clicks fall through to the scrim.
///   3. **Bar layer** — the compact flat search bar chrome hosting the caller-
///      provided content. Positioned at the click point, clamped to the safe
///      area so it can never hang off-screen.
///
/// The host is responsible for:
///   - Keeping `isActive` mapped to `showingSearchPopover`.
///   - Passing `clickLocation` in the overlay's own coordinate space.
///   - Populating `content` with the existing landing-search surface.
///   - Firing haptics via `LandingWaveHaptics.fireBeat(...)` at click time.
struct LandingWaveOverlay<Content: View>: View {
    @Binding var isActive: Bool
    let clickLocation: CGPoint?
    let cursorDirection: CGVector
    let dropTrigger: Int
    var onDismiss: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UIState.self) private var ui

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                // ── Scrim (full-surface dismiss) ──
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onDismiss() }

                // ── Wave layer ──
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

                // ── Bar layer ──
                let barWidth = resolvedBarWidth(in: proxy.size)
                let anchor = resolvedBarAnchor(in: proxy.size, barWidth: barWidth)
                content()
                    .frame(width: barWidth, alignment: .center)
                    .offset(x: anchor.x, y: anchor.y)
                    .transition(reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .scale(scale: LandingWaveDesign.barEmergenceScale, anchor: .center)
                                .combined(with: .opacity)
                                .combined(with: .offset(y: LandingWaveDesign.barEmergenceOffset)),
                            removal: .opacity
                        )
                    )
            }
        }
        .ignoresSafeArea()
    }

    private func resolvedBarWidth(in surface: CGSize) -> CGFloat {
        min(LandingWaveDesign.barMaxWidth, max(LandingWaveDesign.barMinWidth, surface.width - 48))
    }

    /// Target offset for the bar's top-left corner. Horizontal: centered on
    /// the click. Vertical: anchored a little above the click so the bar
    /// appears to rise out of the wave, not drop onto the cursor. Both axes
    /// clamp to a 24pt inset from the window edges.
    private func resolvedBarAnchor(in surface: CGSize, barWidth: CGFloat) -> CGPoint {
        let click = clickLocation ?? CGPoint(x: surface.width / 2, y: surface.height / 2)
        // Estimate bar height for clamping. Use the design constant as the
        // lower bound even though content may be taller; the clamping is
        // about leaving *some* room, not pixel-perfect fit.
        let estimatedHeight: CGFloat = 260
        let desiredX = click.x - barWidth / 2
        let desiredY = click.y - estimatedHeight * 0.65
        let clampedX = min(max(desiredX, 24), max(24, surface.width - barWidth - 24))
        let clampedY = min(max(desiredY, 24), max(24, surface.height - estimatedHeight - 24))
        return CGPoint(x: clampedX, y: clampedY)
    }
}
