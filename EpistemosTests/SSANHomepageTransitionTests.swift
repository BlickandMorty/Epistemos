import Testing
import Foundation

@testable import Epistemos

// SS-AN homepage→graph transition repair (owner high-priority). Step 1: the fold/squish
// is killed — no .scale transition on either branch, and setEmbeddedGraphVisible no
// longer double-fires its own withAnimation (the LandingView's single
// .animation(value: ui.homeContent) owns the timing). The "feels native, no flicker"
// confirmation is PENDING OWNER VERIFICATION (on-device visual feel).
@Suite("SS-AN homepage transition repair")
struct SSANHomepageTransitionTests {

    @Test("the home→graph transition has no .scale fold")
    func noScaleFold() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        #expect(
            !landing.contains(".scale(scale: 0.94)"),
            "the .scale(0.94) fold that squished the whole page must be gone"
        )
    }

    @Test("setEmbeddedGraphVisible does not double-fire its own animation")
    func noDoubleFireAnimation() throws {
        let app = try loadMirroredSourceTextFile("Epistemos/App/EpistemosApp.swift")
        #expect(
            !app.contains("withAnimation(.spring(response: 0.42, dampingFraction: 0.84, blendDuration: 0.1))"),
            "the home-content mutation must not be wrapped in withAnimation — the view owns timing"
        )
    }

    @Test("the home↔graph transition is an Apple blur-replace on a flat easeOut driver")
    func blurReplaceAndEaseOut() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        // Greeting/buttons blur away on removal; the graph blurs in on insertion.
        #expect(landing.contains("BlurFade(blur: 18, opacity: 0)"))   // greeting removal
        #expect(landing.contains("BlurFade(blur: 14, opacity: 0)"))   // graph insertion
        #expect(landing.contains(".asymmetric("))
        // Flat fast driver (no spring overshoot → no pop); reduceMotion still bypasses it.
        #expect(landing.contains("reduceMotion ? nil : .easeOut(duration: 0.28)"))
    }

    @Test("the graph pop-in gate and the racing AppKit alpha fade are gone")
    func noPopInGateOrAlphaRace() throws {
        let graph = try loadMirroredSourceTextFile("Epistemos/Views/Home/HomeGraphEmbeddedView.swift")
        #expect(!graph.contains("milliseconds(420)"),
                "the 420ms canvas-ready gate (graph blank → pop) must be gone")
        #expect(!graph.contains("NSAnimationContext"),
                "the racing 0.32s AppKit alpha fade must be gone — SwiftUI owns the one fade")
        #expect(!graph.contains("view.animator()"),
                "no AppKit alpha animation on the graph canvas — set alphaValue immediately")
    }

    @Test("the landing toolbar controls blur out via embeddedHomeGraphContentVisible")
    func toolbarControlsBlurOut() throws {
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        #expect(root.contains(".blur(radius: embeddedHomeGraphContentVisible ? 14 : 0)"))
        #expect(root.contains(".opacity(embeddedHomeGraphContentVisible ? 0 : 1)"))
        #expect(root.contains(".animation(.easeOut(duration: 0.28), value: embeddedHomeGraphContentVisible)"))
    }
}
