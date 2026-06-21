import SwiftUI

/// MOTION-LANGUAGE TRIAD (owner 2026-06-21) — the reusable BLUR-REVEAL, the Apple-blur layer of the
/// triad (blur + ASCII typewriter + micro-motions). `BlurFade` already provides the blur-reveal as a
/// `.transition`; this is the missing piece: a blur-reveal ON APPEAR that any TITLE or DISPLAY-ONLY
/// surface (labels, headers, section subtitles, status lines) can apply uniformly via `.motionReveal()`.
///
/// Aesthetic matches `BlurFade`: **blur + opacity only** — no scale fold, no spring pop, no flicker
/// (the owner's "Apple blur the owner loves"). Reduce-motion snaps straight to the final state. Pair
/// with `TypewriterASCIIRippleText` for the ASCII-typewriter layer; together they are the triad.
///
/// BALANCE RULE (owner): noticeable-not-bloated — a single short blur-in, the app's signature reveal.
/// **DISPLAY-ONLY: never apply this in text-EDITING areas** (Prose/code/composer) — motion belongs on
/// titles + non-interactive text, per the motion-language directive.
struct MotionReveal: ViewModifier {
    var blur: CGFloat = 10
    var duration: Double = 0.5
    var delay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    func body(content: Content) -> some View {
        content
            .blur(radius: (revealed || reduceMotion) ? 0 : blur)
            .opacity((revealed || reduceMotion) ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { revealed = true; return }
                withAnimation(.easeOut(duration: duration).delay(delay)) {
                    revealed = true
                }
            }
    }
}

extension View {
    /// Apply the motion-language blur-reveal on appear (TITLES + DISPLAY-ONLY surfaces; NEVER in text
    /// editors). Reduce-motion-safe. The reusable Apple-blur layer of the motion triad.
    func motionReveal(blur: CGFloat = 10, duration: Double = 0.5, delay: Double = 0) -> some View {
        modifier(MotionReveal(blur: blur, duration: duration, delay: delay))
    }
}
