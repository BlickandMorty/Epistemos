import Testing
import Foundation

@testable import Epistemos

// SS-GC item (3C, owner 2026-06-20): the principal toolbar PILL.
// KEEP it mounted on the graph — a principal ToolbarItem is load-bearing for the window's
// CURVED corners (drop it and the window regresses to square). So instead of blurring it
// fully away on the graph, its BUTTON SET becomes PAGE-RELEVANT: settings shows in BOTH
// states (≥1 button preserves the curve); the landing greeting + the recent-chats (history)
// button are landing-only (owner: "it caused issues; I only want it on the landing page").
@Suite("SS-GC toolbar pill (curve-preserving, page-relevant)")
struct SSGCPillTests {

    @Test("the principal pill stays mounted on the graph (load-bearing for the curved window)")
    func pillMountedOnGraph() throws {
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        // The principal ToolbarItem (the pill) + the embedded-graph branch of its gate are
        // both still present, so the pill mounts on the graph too → the window keeps its curve.
        #expect(root.contains("ToolbarItem(placement: .principal)"))
        #expect(root.contains("showEmbeddedGraphToolbarControls"))
    }

    @Test("settings shows in both states; the greeting + history are landing-only")
    func buttonSetIsPageRelevant() throws {
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        // settings sits OUTSIDE the landing-only guard (shows on graph too); the landing
        // greeting + history sit INSIDE `if !embeddedHomeGraphContentVisible` (landing-only).
        #expect(root.contains("settingsToolbarButton\n                    if !embeddedHomeGraphContentVisible {"))
        #expect(root.contains("landingGreetingToolbarButton"))
        #expect(root.contains("historyToolbarButton"))
    }
}
