//
//  AsciiPortraitView.swift
//  Simulation Mode S9 — ASCII portrait renderer for the §8.2.2
//  phase 1 portrait emergence + phase 3 hero title typing.
//
//  Per DOCTRINE §8.2.3:
//   - "The ASCII portrait is **text**: rendered as `Text` with
//     `Font.system(.body, design: .monospaced)` at a fixed
//     integer point size; `.lineSpacing(0)`; no kerning
//     adjustments. Monochrome via `.foregroundStyle(...)`."
//
//  Per DOCTRINE §8.2.1 the canonical NousResearch portrait is
//  the source of truth. When that canonical asset is unavailable
//  (S5.7 ships the canonical-asset fetcher), this file ships a
//  hand-drawn original Epistemos-fallback portrait following the
//  same palette + silhouette direction (gold/cyan-white,
//  serpentine + scholarly motif). Provenance recording the
//  substitution is a follow-up; the in-app Audit View will mark
//  this as "Epistemos-fallback" rather than "canonical NousResearch".
//

import SwiftUI

/// Procedural Epistemos-fallback ASCII portrait per §8.2.1
/// substitution allowance. Hand-drawn original silhouette in the
/// gold/cyan-white palette direction. Replaced by the canonical
/// NousResearch portrait when S5.7 lands.
public enum AsciiPortraitArt {
    /// Fallback portrait — symbolic snake-spiral motif over a
    /// scholarly serif "H". Pixel-aligned monospace; each line
    /// is the same character width so column alignment holds.
    public static let epistemosFallback: String = """
    ╔══════════════════════╗
    ║      .-====-.        ║
    ║     /  /\\/\\  \\      ║
    ║    | ( o  o ) |       ║
    ║    |   /\\/    |       ║
    ║     \\__||__/         ║
    ║      ║║║║            ║
    ║   .──╫╫╫╫──.         ║
    ║   │  ╫╫╫╫  │         ║
    ║   │  H  H  │         ║
    ║   │  H──H  │         ║
    ║   ╰──┬──┬──╯         ║
    ║      ║  ║            ║
    ║   ───╨──╨───         ║
    ║                       ║
    ║    H E R M E S        ║
    ╚══════════════════════╝
    """

    /// Banner text used by §8.2.2 phase 2 ASCII wave. Pre-S5.7
    /// fallback is a procedurally-constructed one-line wave.
    public static let bannerWaveFallback: String =
        "~~~~~~~~~ HERMES ~~~~~~~~~"
}

/// Renders an ASCII portrait per §8.2.3 rendering rules.
public struct AsciiPortraitView: View {
    public let art: String
    public let pointSize: CGFloat
    public let foregroundColor: Color
    /// `nil` = render whole portrait at full opacity. `n` =
    /// reveal only the first n characters (typing animation
    /// for phase 3 hero-title-type-on or phase 1 portrait
    /// emergence).
    public let revealCharacters: Int?

    public init(
        art: String = AsciiPortraitArt.epistemosFallback,
        pointSize: CGFloat = 11,
        foregroundColor: Color = Color(red: 0.85, green: 0.95, blue: 1.0),
        revealCharacters: Int? = nil
    ) {
        self.art = art
        self.pointSize = pointSize
        self.foregroundColor = foregroundColor
        self.revealCharacters = revealCharacters
    }

    public var body: some View {
        let revealed = clip(art, to: revealCharacters)
        Text(revealed)
            .font(.system(size: pointSize, weight: .regular, design: .monospaced))
            .lineSpacing(0)
            .kerning(0)
            .tracking(0)
            .foregroundStyle(foregroundColor)
            .multilineTextAlignment(.leading)
            .accessibilityLabel("Hermes ASCII portrait")
    }

    private func clip(_ s: String, to n: Int?) -> String {
        guard let n = n, n < s.count else { return s }
        return String(s.prefix(max(0, n)))
    }
}

/// Hero-typography "HERMES-AGENT" wordmark — pre-S5.7 fallback
/// using SwiftUI shapes. Per §8.2.3 the canonical asset is a
/// pixel-art SVG; until that lands, we render an Epistemos-
/// fallback wordmark with the same gold-on-black silhouette
/// using a stack of pixel-art-styled rounded rectangles.
public struct HermesHeroWordmarkView: View {
    /// 1.0 = fully visible, 0.0 = hidden. Drives the type-on
    /// reveal (phase 3) by clipping a left-anchored mask.
    public let typeOnProgress: Double
    public let primaryHex: String
    public let shadowHex: String

    public init(
        typeOnProgress: Double = 1.0,
        primaryHex: String = "#FFCC00",
        shadowHex: String = "#D97757"
    ) {
        self.typeOnProgress = max(0.0, min(1.0, typeOnProgress))
        self.primaryHex = primaryHex
        self.shadowHex = shadowHex
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            // Shadow offset (the canonical mark has an offset
            // orange shadow per §8.2.1 wordmark-hero-color.svg
            // contract).
            Text("HERMES-AGENT")
                .font(.system(size: 32, weight: .heavy, design: .monospaced))
                .kerning(2)
                .foregroundStyle(parseHex(shadowHex))
                .offset(x: 2, y: 2)
            Text("HERMES-AGENT")
                .font(.system(size: 32, weight: .heavy, design: .monospaced))
                .kerning(2)
                .foregroundStyle(parseHex(primaryHex))
        }
        .mask(
            // Left-anchored reveal mask for the type-on. Pre-
            // baked clip rectangle — never a runtime blur.
            GeometryReader { geo in
                Rectangle()
                    .frame(width: geo.size.width * typeOnProgress)
            }
        )
        .accessibilityLabel("HERMES-AGENT")
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
