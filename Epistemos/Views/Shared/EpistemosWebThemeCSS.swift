import AppKit

enum EpistemosWebThemeCSS {
    static func color(
        _ token: EpistemosTheme.ResolvedColorToken,
        opacity overrideOpacity: CGFloat? = nil
    ) -> String {
        color(token.nsColor, opacity: overrideOpacity)
    }

    static func color(_ color: NSColor, opacity overrideOpacity: CGFloat? = nil) -> String {
        let rgbColor = color.usingColorSpace(.sRGB)
            ?? color.usingColorSpace(.deviceRGB)
            ?? color.usingColorSpace(.extendedSRGB)
            ?? color
        let red = Int((rgbColor.redComponent * 255).rounded())
        let green = Int((rgbColor.greenComponent * 255).rounded())
        let blue = Int((rgbColor.blueComponent * 255).rounded())
        let alpha = overrideOpacity ?? rgbColor.alphaComponent

        if alpha >= 0.999 {
            return String(format: "#%02X%02X%02X", red, green, blue)
        }
        return String(format: "rgba(%d, %d, %d, %.3f)", red, green, blue, alpha)
    }
}
