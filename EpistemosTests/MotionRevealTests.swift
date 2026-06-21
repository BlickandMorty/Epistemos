import Testing
import Foundation
@testable import Epistemos

/// Motion-language triad (owner 2026-06-21) — the reusable blur-reveal (`MotionReveal`). Locks the
/// contract: reduce-motion-safe, display-only (never editors), the BlurFade aesthetic (blur + opacity,
/// no scale/spring), a reusable `.motionReveal()` modifier, and that it's actually applied to a real
/// display-only title (not a dead component).
@Suite("Motion language — reusable blur-reveal (triad)")
struct MotionRevealTests {
    @Test("motionReveal: reduce-motion-safe, display-only, BlurFade aesthetic, reusable modifier")
    func motionRevealContract() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Shared/MotionReveal.swift")
        #expect(src.contains("func motionReveal("))
        #expect(src.contains("accessibilityReduceMotion"))           // reduce-motion respected
        #expect(src.contains("DISPLAY-ONLY") || src.contains("never apply this in text-EDITING"))
        // Apple-blur aesthetic only — blur + opacity, NO scale fold / spring pop (owner's "Apple blur").
        #expect(src.contains(".blur(radius:") && src.contains(".opacity("))
        // No scale fold / spring pop in the ANIMATION (the comment may mention them by name).
        #expect(!src.contains(".scaleEffect(") && !src.contains(".spring("))
    }

    @Test("a display-only act title applies the motion reveal (not a dead component)")
    func appliedToActTitle() throws {
        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ActOsaurusHealthRow.swift")
        #expect(row.contains(".motionReveal()"))
    }
}
