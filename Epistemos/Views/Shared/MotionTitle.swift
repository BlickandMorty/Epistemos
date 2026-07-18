import SwiftUI

nonisolated struct EditorTitleRevealKey: Hashable, Sendable {
    let documentID: String
    let surface: String
    let activationGeneration: UInt64
}

/// THE reusable "ASCII-typewriter + Apple-blur" title motion (owner 2026-06-21 §317/§329) — the signature
/// "time-machine" motion ontology as ONE reusable component, not a one-off. It COUPLES the two primitives
/// the app already has into a single titled motion: the ASCII typewriter reveal (`TypewriterASCIIRippleText`)
/// layered with the Apple-blur reveal (`MotionReveal`) — the owner's "blur + this = a layered meta animation".
///
/// CONTRACT (mirrors `MotionReveal`):
/// - DISPLAY-ONLY. NEVER use in text-EDITING areas (the message bar / editors) — titles, settings, agent
///   surfaces, and other non-editing reveals only.
/// - Reduce-motion-safe: both layers fall back to static text/opacity under `accessibilityReduceMotion`.
/// - Font-adaptive: pass the context-appropriate font (NOT one fixed title font everywhere) — same motion
///   ontology, per-context font, per the owner's "scale to many fonts incl. smaller body fonts".
/// - Anchored on TITLES (the primary anchor); available app-wide as the motion accent, strongest in WORK
///   (the ASCII/pixel-art surface).
/// Net: the single reusable typewriter+ASCII+blur title motion — tasteful, signature-not-spammy, never in editors.
struct MotionTitle: View {
    let text: String
    var font: Font = .title3.weight(.semibold)
    var color: Color = .primary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UIState.self) private var ui: UIState?

    var body: some View {
        Group {
            if reduceMotion || ui?.windowOccluded == true {
                // Reduce-motion: plain static title, no typewriter, no ripple.
                Text(text)
                    .font(font)
                    .foregroundStyle(color)
            } else {
                // The ASCII-typewriter layer (it animates once per `text` value, not per re-render).
                TypewriterASCIIRippleText(text: text, font: font, color: color)
            }
        }
        // …coupled with the Apple-blur reveal — the layered "meta animation" (also reduce-motion-safe).
        .motionReveal()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
