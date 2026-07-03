import SwiftUI

// Owner 2026-07-03: make the app feel ALIVE beyond the graph. A reusable animated
// "liquid" Metal backdrop — a subtle aurora / domain-warp gradient over a base tint,
// driven by the `auroraFlow` stitchable shader (Shaders/LiquidSurface.metal) through
// SwiftUI's ShaderLibrary + TimelineView. Confirmed loadable: the app ships a
// default.metallib (makeDefaultLibrary is used by CodeEditorView / MetalRuntimeManager).
//
// PERF CONTRACT (PhysicsModifiers.swift:8-13 — "zero cost when idle"): the caller MUST
// pass `active: !ui.windowOccluded` so the animation stops when the window is occluded;
// Reduce Motion also disables it. Otherwise idle CPU/GPU regresses.

extension View {
    /// Animated liquid Metal backdrop behind this view (aurora over `base`, tinted with
    /// `accent`). Falls back to a flat `base` fill when `active` is false or Reduce Motion
    /// is on.
    func liquidMetalBackground(
        base: Color,
        accent: Color,
        intensity: Double = 0.14,
        active: Bool = true
    ) -> some View {
        background {
            LiquidMetalSurface(base: base, accent: accent, intensity: intensity, active: active)
                .ignoresSafeArea()
        }
    }
}

struct LiquidMetalSurface: View {
    let base: Color
    let accent: Color
    var intensity: Double = 0.14
    var active: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if active && !reduceMotion {
            // ~30fps is plenty for a slow aurora and halves GPU/power vs display-rate.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
                Rectangle()
                    .fill(base)
                    .visualEffect { effect, proxy in
                        effect.colorEffect(
                            ShaderLibrary.auroraFlow(
                                .float(Float(t)),
                                .float2(proxy.size),
                                .color(accent),
                                .color(base),
                                .float(Float(intensity))
                            )
                        )
                    }
            }
        } else {
            base
        }
    }
}

extension View {
    /// A subtle moving liquid "sheen" sweep over this view's CONTENT (e.g. hero text) —
    /// makes a surface feel alive. Masked to the content's own alpha. Pass
    /// `active: !ui.windowOccluded` (Reduce Motion also disables it).
    func liquidShimmer(sheen: Color, intensity: Double = 0.16, active: Bool = true) -> some View {
        modifier(LiquidShimmer(sheen: sheen, intensity: intensity, active: active))
    }
}

private struct LiquidShimmer: ViewModifier {
    let sheen: Color
    var intensity: Double = 0.16
    var active: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if active && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
                content.visualEffect { effect, proxy in
                    effect.colorEffect(
                        ShaderLibrary.liquidSheen(
                            .float(Float(t)),
                            .float2(proxy.size),
                            .color(sheen),
                            .float(Float(intensity))
                        )
                    )
                }
            }
        } else {
            content
        }
    }
}
