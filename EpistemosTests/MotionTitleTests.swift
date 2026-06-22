import Testing
import Foundation
@testable import Epistemos

/// Motion ontology (owner 2026-06-21 §317/§329) — the reusable "ASCII-typewriter + Apple-blur" title
/// motion (`MotionTitle`). Locks the contract: it COUPLES the two existing primitives into ONE reusable
/// component (not a one-off), is reduce-motion-safe, font-adaptive, display-only (never editors), and is
/// actually applied to a real display-only WORK title (the ASCII layer is strongest in WORK).
@Suite("Motion ontology — reusable ASCII-typewriter + blur title (MotionTitle)")
struct MotionTitleTests {
    @Test("MotionTitle couples ASCII typewriter + blur into one reusable, reduce-motion-safe component")
    func motionTitleContract() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Shared/MotionTitle.swift")
        #expect(src.contains("struct MotionTitle"))
        // Couples BOTH layers: the ASCII typewriter primitive + the blur reveal.
        #expect(src.contains("TypewriterASCIIRippleText("))
        #expect(src.contains(".motionReveal()"))
        // Reduce-motion-safe (static fallback) + font-adaptive (font is a parameter, not hardcoded).
        #expect(src.contains("accessibilityReduceMotion"))
        #expect(src.contains("var font: Font"))
        // Display-only contract is documented (never in editors).
        #expect(src.contains("DISPLAY-ONLY") || src.contains("never in editors") || src.contains("NEVER use in text-EDITING"))
    }

    @Test("MotionTitle is applied to a real display-only WORK title (not a dead component)")
    func appliedToWorkTitle() throws {
        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/WorkOpenCodeShellHealthRow.swift")
        #expect(row.contains("MotionTitle("))
    }
}
