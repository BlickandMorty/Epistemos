import Testing
import Foundation

@testable import Epistemos

// SS-ALIVE cohesive feel-alive animation (owner 2026-06-20). The Landing↔Chat swap at
// RootView.HomeRouter no longer "folds" via .scale — it uses the same Apple blur-replace
// (BlurFade) as the SS-AN homepage greeting↔graph transition, on the one flat easeOut
// driver, so the whole app breathes one way. The "feels native, cohesive, no pop/squish"
// confirmation is PENDING OWNER VERIFICATION (on-device visual feel).
@Suite("SS-ALIVE cohesive transition")
struct SSALIVETransitionTests {

    @Test("the reusable blur-fade transition exists for content swaps")
    func blurFadeTransitionExists() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Landing/BlurFade.swift")
        #expect(src.contains("static func blurFade("))
        #expect(src.contains("active: BlurFade(blur: radius, opacity: 0)"))
        #expect(src.contains("identity: BlurFade(blur: 0, opacity: 1)"))
    }

    @Test("the Landing↔Chat swap has no .scale fold")
    func noScaleFold() throws {
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        #expect(
            !root.contains(".scale(scale: 0.99)"),
            "the .scale(0.99) fold on the Landing↔Chat swap must be gone — it's a blur-fade now"
        )
    }

    @Test("the Landing↔Chat swap is the cohesive blur-fade on a flat easeOut driver")
    func blurFadeOnEaseOut() throws {
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        // Both branches use the shared blur-fade transition.
        #expect(root.contains(".transition(.blurFade())"))
        // Flat fast driver (no spring overshoot → no pop); reduceMotion bypasses it.
        #expect(root.contains(".animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: showChat)"))
    }
}
