import SwiftUI

// Centralizes the Work surface's fonts for the OpenCode-TUI-minimal PIXEL reskin (owner's emphasized visual target:
// "pixel/mono accents"). Epistemos already bundles + registers these (EpistemosFont.registerFonts):
//   • body  = JetBrainsMono-Regular (PS name = EpistemosTheme.monoFontName) — a READABLE monospace for transcript /
//     input / picker labels (dense but readable; the OpenCode-TUI feel).
//   • pixel = ChonkyPixels (PS name verified by existing Font.custom usage) — the PIXEL identity, for ACCENTS only
//     (header title, status, badges) so readability never suffers.
// The reskin pass swaps the Work views' `.system(…, design: .monospaced)` → `WorkPixelFont.body(…)` and pixel-izes
// the accents → `WorkPixelFont.pixel(…)`. Font.custom silently falls back to the system font if a face is missing, so
// this is safe even on a build where a face didn't register.
enum WorkPixelFont {
    /// Readable monospace body (transcript, input, picker labels).
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("JetBrainsMono-Regular", size: size).weight(weight)
    }

    /// Pixel accent (header title, status, badges) — the pixel identity; use sparingly, never for long body text.
    static func pixel(_ size: CGFloat) -> Font {
        Font.custom("ChonkyPixels", size: size)
    }
}
