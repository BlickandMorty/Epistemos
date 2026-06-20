import Testing
import Foundation

@testable import Epistemos

// SS-IR (owner 2026-06-20): the owner "couldn't see Instant Recall" because the Halo bubble only
// appeared when results existed. This slice makes it discoverable in a resting state — a faint,
// always-present bubble that opens a live panel (with an honest "no matches yet" empty state) even
// with zero hits — without disturbing the bright results-present affordance.
@Suite("SS-IR resting bubble discoverability")
struct SSIRRestingBubbleTests {

    @Test("resting states are discoverable; isVisible (results-present) is unchanged")
    func restingDiscoverableFlag() {
        // The faint resting bubble shows in dormant + sensing…
        #expect(HaloState.dormant.isRestingDiscoverable)
        #expect(HaloState.sensing.isRestingDiscoverable)
        // …but not once results are present (that's the bright `isVisible` path).
        #expect(!HaloState.available(count: 3).isRestingDiscoverable)
        // `isVisible` semantics are untouched (results-present only) so mount/dismantle elsewhere
        // is unaffected.
        #expect(!HaloState.dormant.isVisible)
        #expect(!HaloState.sensing.isVisible)
        #expect(HaloState.available(count: 1).isVisible)
    }

    // The resting bubble must be a LIVE entry point: openPanel opens from dormant/sensing, the
    // panel shows an honest empty state (not a blank box), and the button renders faintly at rest.
    @Test("openPanel opens from resting + the panel has a no-matches empty state")
    func restingBubbleIsLive() throws {
        let controller = try loadMirroredSourceTextFile("Epistemos/Engine/HaloController.swift")
        #expect(controller.contains("case .dormant, .sensing:"))
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Halo/ShadowPanelContent.swift")
        #expect(panel.contains("No matches yet"))
        #expect(panel.contains("controller.matches.isEmpty"))
        let button = try loadMirroredSourceTextFile("Epistemos/Views/Halo/HaloButton.swift")
        #expect(button.contains("isRestingDiscoverable"))
    }
}
