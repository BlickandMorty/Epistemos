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
}
