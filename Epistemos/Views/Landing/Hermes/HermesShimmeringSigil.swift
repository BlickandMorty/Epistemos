import SwiftUI

/// Hero sigil that floats above the "Hermes Agent" hero typewriter on
/// landing. SF Symbol base (`figure.stand.dress` by default — overridable)
/// rendered with a continuously-animated linear-gradient mask that sweeps
/// across the figure to read as a soft shimmer / shine.
///
/// Implementation notes:
/// - `TimelineView(.animation)` drives the sweep deterministically; no
///   explicit `withAnimation` so the sweep keeps moving even while
///   SwiftUI is otherwise idle.
/// - The sweep is gated on `accessibilityReduceMotion` per Invariant
///   I-14 — when reduce-motion is on, the sigil renders the figure in a
///   static accent gradient with no animation.
/// - All work stays on `@MainActor`; no Metal pass needed at this size.
///   If we later want a denser Metal-driven shimmer (e.g. iridescent
///   hue rotation), we can swap the mask for a Metal shader without
///   touching call sites.
struct HermesShimmeringSigil: View {
    var systemImageName: String = "figure.stand.dress"
    var size: CGFloat = 84
    var accent: Color = Color(hue: 0.55, saturation: 0.55, brightness: 0.95)
    var halo: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if halo {
                haloLayer
            }
            figureLayer
        }
        .frame(width: size * 1.6, height: size * 1.6)
        .accessibilityElement()
        .accessibilityLabel("Hermes Agent sigil")
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
        Image(systemName: systemImageName)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(
                LinearGradient(
                    colors: [accent, accent.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var shimmeringFigure: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let phase = shimmerPhase(at: context.date)
            Image(systemName: systemImageName)
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Image(systemName: systemImageName)
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .blendMode(.softLight)
                        .mask(shimmerMask(phase: phase))
                        .opacity(0.85)
                }
                .overlay {
                    Image(systemName: systemImageName)
                        .resizable()
                        .scaledToFit()
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .blendMode(.plusLighter)
                        .mask(shimmerMask(phase: phase, narrow: true))
                        .opacity(0.55)
                }
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

    private func shimmerMask(phase: CGFloat, narrow: Bool = false) -> some View {
        let band = narrow ? 0.18 : 0.32
        return LinearGradient(
            stops: [
                .init(color: .clear, location: max(0, phase - band)),
                .init(color: .white.opacity(narrow ? 1.0 : 0.85), location: max(0, min(1, phase))),
                .init(color: .clear, location: min(1, phase + band)),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#if DEBUG
#Preview("Shimmering Sigil") {
    HermesShimmeringSigil()
        .padding(40)
        .background(Color.black)
}
#endif
