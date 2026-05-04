import SwiftUI

/// Hero sigil that floats above the Hermes Agent hero typewriter on landing.
/// The mark is a public-domain caduceus drawn directly in SwiftUI Canvas, so
/// Hermes gets a real mythological identity without bundling NousResearch
/// marks before licensing is settled.
///
/// Implementation notes:
/// - `TimelineView(.animation)` drives the sheen deterministically; no
///   `repeatForever`.
/// - The sweep is gated on `accessibilityReduceMotion` per Invariant
///   I-14 — when reduce-motion is on, the sigil renders statically.
/// - All work stays on `@MainActor`; no Metal pass needed at this size.
///   If we later want a denser Metal-driven shimmer (e.g. iridescent
///   hue rotation), we can swap the Canvas pass without touching call sites.
struct HermesShimmeringSigil: View {
    var size: CGFloat = 84
    var accent: Color = HermesBrand.primary
    var halo: Bool = true
    /// Bumped externally on submit to fire a one-shot ring burst.
    /// The sigil watches this trigger and animates a fading ring
    /// outward whenever it changes.
    var burstTrigger: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared: Bool = false
    @State private var burstStartedAt: Date? = nil

    var body: some View {
        ZStack {
            if halo {
                haloLayer
            }
            burstRing
            figureLayer
        }
        .frame(width: size * 1.6, height: size * 1.6)
        .scaleEffect(hasAppeared || reduceMotion ? 1.0 : 0.55)
        .opacity(hasAppeared || reduceMotion ? 1.0 : 0.0)
        .onAppear {
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.66)) {
                    hasAppeared = true
                }
            }
        }
        .onChange(of: burstTrigger) { _, _ in
            guard !reduceMotion else { return }
            burstStartedAt = .now
        }
        .accessibilityElement()
        .accessibilityLabel("Hermes Agent sigil")
    }

    /// One-shot expanding ring fired by `burstTrigger`. Self-resets
    /// after ~700ms so re-firing is cheap.
    @ViewBuilder
    private var burstRing: some View {
        if let started = burstStartedAt, !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                let elapsed = context.date.timeIntervalSince(started)
                let duration: TimeInterval = 0.7
                let progress = min(1.0, max(0.0, elapsed / duration))
                if progress >= 1.0 {
                    Color.clear
                        .onAppear { burstStartedAt = nil }
                } else {
                    Circle()
                        .stroke(accent.opacity(0.65 * (1.0 - progress)), lineWidth: 2.0 * (1.0 - progress) + 0.5)
                        .frame(
                            width: size * (1.05 + 0.7 * progress),
                            height: size * (1.05 + 0.7 * progress)
                        )
                        .blur(radius: 0.5 + 1.5 * progress)
                }
            }
        }
    }

    // MARK: - Halo

    private var haloLayer: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? .infinity : 1.0 / 30.0)) { context in
            let phase = haloPhase(at: context.date)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.32 + 0.10 * phase),
                            accent.opacity(0.10),
                            .clear,
                        ],
                        center: .center,
                        startRadius: size * 0.25,
                        endRadius: size * 0.82
                    )
                )
                .blur(radius: 8 + 4 * phase)
                .frame(width: size * 1.45, height: size * 1.45)
        }
    }

    private func haloPhase(at date: Date) -> CGFloat {
        guard !reduceMotion else { return 0.0 }
        let t = date.timeIntervalSinceReferenceDate
        // Slow breathe: 4-second period, smoothed sine.
        let raw = sin(t * 2.0 * .pi / 4.0)
        return CGFloat((raw + 1.0) / 2.0)
    }

    // MARK: - Figure

    private var figureLayer: some View {
        Group {
            if reduceMotion {
                staticFigure
            } else {
                shimmeringFigure
            }
        }
        .frame(width: size, height: size)
    }

    private var staticFigure: some View {
        HermesCaduceusCanvas(accent: accent, shimmerPhase: 0, reduceMotion: true)
    }

    private var shimmeringFigure: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let phase = shimmerPhase(at: context.date)
            HermesCaduceusCanvas(accent: accent, shimmerPhase: phase, reduceMotion: false)
        }
    }

    private func shimmerPhase(at date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate
        // 3.2-second sweep period across the figure. Phase wraps -1...1.
        let period = 3.2
        let progress = (t.truncatingRemainder(dividingBy: period)) / period
        // Map 0...1 to a back-and-forth sweep across the figure: -1.4 ... 1.4
        return CGFloat(progress) * 2.8 - 1.4
    }

}

private struct HermesCaduceusCanvas: View {
    let accent: Color
    let shimmerPhase: CGFloat
    let reduceMotion: Bool

    var body: some View {
        Canvas { context, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            let originX = (canvasSize.width - side) / 2
            let originY = (canvasSize.height - side) / 2
            let rect = CGRect(x: originX, y: originY, width: side, height: side)

            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
            }

            func ellipse(center x: CGFloat, _ y: CGFloat, radius: CGFloat) -> Path {
                Path(ellipseIn: CGRect(
                    x: rect.minX + rect.width * x - side * radius,
                    y: rect.minY + rect.height * y - side * radius,
                    width: side * radius * 2,
                    height: side * radius * 2
                ))
            }

            let staffWidth = max(2, side * 0.045)
            let serpentWidth = max(2, side * 0.04)
            let wingWidth = max(1.5, side * 0.032)

            var staff = Path()
            staff.move(to: point(0.5, 0.16))
            staff.addLine(to: point(0.5, 0.86))
            context.stroke(
                staff,
                with: .color(accent.opacity(0.9)),
                style: StrokeStyle(lineWidth: staffWidth, lineCap: .round)
            )
            context.stroke(
                staff,
                with: .color(.white.opacity(0.18)),
                style: StrokeStyle(lineWidth: max(1, staffWidth * 0.36), lineCap: .round)
            )

            context.fill(ellipse(center: 0.5, 0.12, radius: 0.055), with: .color(accent.opacity(0.9)))
            context.fill(ellipse(center: 0.5, 0.12, radius: 0.026), with: .color(.white.opacity(0.22)))
            context.fill(ellipse(center: 0.5, 0.88, radius: 0.035), with: .color(accent.opacity(0.8)))

            var leftWing = Path()
            leftWing.move(to: point(0.46, 0.23))
            leftWing.addCurve(to: point(0.16, 0.16), control1: point(0.34, 0.12), control2: point(0.22, 0.11))
            leftWing.addCurve(to: point(0.32, 0.31), control1: point(0.20, 0.25), control2: point(0.24, 0.31))
            leftWing.addCurve(to: point(0.46, 0.25), control1: point(0.38, 0.31), control2: point(0.42, 0.28))

            var rightWing = Path()
            rightWing.move(to: point(0.54, 0.23))
            rightWing.addCurve(to: point(0.84, 0.16), control1: point(0.66, 0.12), control2: point(0.78, 0.11))
            rightWing.addCurve(to: point(0.68, 0.31), control1: point(0.80, 0.25), control2: point(0.76, 0.31))
            rightWing.addCurve(to: point(0.54, 0.25), control1: point(0.62, 0.31), control2: point(0.58, 0.28))

            context.stroke(leftWing, with: .color(accent.opacity(0.78)), style: StrokeStyle(lineWidth: wingWidth, lineCap: .round, lineJoin: .round))
            context.stroke(rightWing, with: .color(accent.opacity(0.78)), style: StrokeStyle(lineWidth: wingWidth, lineCap: .round, lineJoin: .round))
            context.stroke(leftWing, with: .color(.white.opacity(0.13)), style: StrokeStyle(lineWidth: max(1, wingWidth * 0.38), lineCap: .round, lineJoin: .round))
            context.stroke(rightWing, with: .color(.white.opacity(0.13)), style: StrokeStyle(lineWidth: max(1, wingWidth * 0.38), lineCap: .round, lineJoin: .round))

            var leftSerpent = Path()
            leftSerpent.move(to: point(0.41, 0.28))
            leftSerpent.addCurve(to: point(0.61, 0.43), control1: point(0.20, 0.34), control2: point(0.78, 0.36))
            leftSerpent.addCurve(to: point(0.39, 0.58), control1: point(0.45, 0.50), control2: point(0.22, 0.50))
            leftSerpent.addCurve(to: point(0.58, 0.73), control1: point(0.58, 0.66), control2: point(0.74, 0.66))

            var rightSerpent = Path()
            rightSerpent.move(to: point(0.59, 0.28))
            rightSerpent.addCurve(to: point(0.39, 0.43), control1: point(0.80, 0.34), control2: point(0.22, 0.36))
            rightSerpent.addCurve(to: point(0.61, 0.58), control1: point(0.55, 0.50), control2: point(0.78, 0.50))
            rightSerpent.addCurve(to: point(0.42, 0.73), control1: point(0.42, 0.66), control2: point(0.26, 0.66))

            let serpentStyle = StrokeStyle(lineWidth: serpentWidth, lineCap: .round, lineJoin: .round)
            context.stroke(leftSerpent, with: .color(accent.opacity(0.92)), style: serpentStyle)
            context.stroke(rightSerpent, with: .color(HermesBrand.primaryMuted.opacity(0.88)), style: serpentStyle)
            context.stroke(leftSerpent, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: max(1, serpentWidth * 0.34), lineCap: .round, lineJoin: .round))
            context.stroke(rightSerpent, with: .color(.white.opacity(0.16)), style: StrokeStyle(lineWidth: max(1, serpentWidth * 0.34), lineCap: .round, lineJoin: .round))

            context.fill(ellipse(center: 0.41, 0.27, radius: 0.034), with: .color(accent.opacity(0.95)))
            context.fill(ellipse(center: 0.59, 0.27, radius: 0.034), with: .color(HermesBrand.primaryMuted.opacity(0.92)))

            if !reduceMotion {
                let normalizedPhase = max(0, min(1, (shimmerPhase + 1.4) / 2.8))
                let shimmerX = rect.minX + rect.width * (normalizedPhase * 1.3 - 0.18)
                var sheen = Path()
                sheen.move(to: CGPoint(x: shimmerX, y: rect.minY + rect.height * 0.12))
                sheen.addLine(to: CGPoint(x: shimmerX + rect.width * 0.34, y: rect.minY + rect.height * 0.88))
                context.stroke(
                    sheen,
                    with: .color(.white.opacity(0.34)),
                    style: StrokeStyle(lineWidth: max(1, side * 0.028), lineCap: .round)
                )
            }
        }
    }
}

#if DEBUG
#Preview("Shimmering Sigil") {
    HermesShimmeringSigil()
        .padding(40)
        .background(Color.black)
}
#endif
