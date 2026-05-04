//
//  HermesGoldHaloView.swift
//  Simulation Mode S9 — separate additive-blend gold halo per
//  DOCTRINE §5.7 + §8.2.2 phase 4.
//
//  CRITICAL per DOCTRINE §8.2.3:
//    "The gold halo is a **separate additive quad** with a
//    pre-baked soft texture — never a Gaussian blur of the
//    wordmark."
//
//  This view renders the halo as a SwiftUI `RadialGradient` —
//  i.e. the softness is in the gradient definition itself, not
//  produced by `.blur()` at render time. Pre-S5.7 (when the
//  canonical `effects/halo_hermes_gold.png` ships), this
//  procedural fallback is doctrine-allowed per §8.2.1.
//
//  Pulse animation per §8.2.2 phase 4: opacity 0 → 0.6 → 0.3,
//  then holds at 0.3 for the duration of the Hermes session.
//

import SwiftUI

/// Gold halo (additive overlay). Position the parent view
/// behind the wordmark + portrait area so the halo sits at the
/// correct z-order.
public struct HermesGoldHaloView: View {
    /// Current opacity — 0…1. The orchestrator drives this via
    /// SwiftUI animation; the halo never animates itself.
    public let opacity: Double
    public let centerHex: String
    public let edgeHex: String
    public let radius: CGFloat

    public init(
        opacity: Double = 0.3,
        centerHex: String = "#FFD659",
        edgeHex: String = "#0A0A1F",
        radius: CGFloat = 220
    ) {
        self.opacity = max(0.0, min(1.0, opacity))
        self.centerHex = centerHex
        self.edgeHex = edgeHex
        self.radius = radius
    }

    public var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: parseHex(centerHex).opacity(0.95), location: 0.0),
                        .init(color: parseHex(centerHex).opacity(0.55), location: 0.35),
                        .init(color: parseHex(centerHex).opacity(0.18), location: 0.65),
                        .init(color: parseHex(edgeHex).opacity(0.0),     location: 1.0),
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            .blendMode(.plusLighter) // additive — DOCTRINE §5.7
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func parseHex(_ hex: String) -> Color {
        guard hex.count == 7, hex.first == "#" else { return .yellow }
        var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0
        _ = Scanner(string: String(hex.dropFirst().prefix(2))).scanHexInt64(&r)
        _ = Scanner(string: String(hex.dropFirst(3).prefix(2))).scanHexInt64(&g)
        _ = Scanner(string: String(hex.dropFirst(5).prefix(2))).scanHexInt64(&b)
        return Color(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )
    }
}

/// Single-frame additive glare flash per §8.2.2 phase 6. Pre-
/// baked texture would ship as `effects/glare_hermes.png` per
/// the v1.4 asset pipeline; until then the procedural fallback
/// is a slim diagonal RadialGradient swept across the canvas.
public struct HermesGlareFlashView: View {
    /// 0…1 sweep position — 0 means the glare hasn't started,
    /// 1 means it has finished.
    public let progress: Double

    public init(progress: Double) {
        self.progress = max(0.0, min(1.0, progress))
    }

    public var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width
            let glareWidth: CGFloat = 80
            // Sweep range: from off-screen-left (-glareWidth) to
            // off-screen-right (width). progress maps that range.
            let xCenter = -glareWidth + (width + 2 * glareWidth) * progress
            let intensity = sin(progress * .pi) // 0→1→0
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.55 * intensity), location: 0.5),
                            .init(color: .clear, location: 1.0),
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: glareWidth, height: height)
                .blendMode(.plusLighter)
                .position(x: xCenter + glareWidth / 2, y: height / 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
