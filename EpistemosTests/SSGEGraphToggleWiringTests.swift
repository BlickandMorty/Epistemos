import Testing
import Foundation

@testable import Epistemos

// SS-GE (C) (owner 2026-06-21): "the tags + all the togglable things on the graph appearance setting —
// make sure they WORK; several I don't see at all... our checks have NOT been working." AUDIT FINDING:
// the graph appearance / lab toggles in GraphForceSettings are NOT dead — each flag they bind on
// GraphState is actually CONSUMED by the MetalGraphView renderer (verified). So the toggles affect
// what the graph renders (not do-nothing controls); the "don't see them" is discoverability (several
// live behind the "Laboratory" disclosure), not a dead wire.
//
// This is the regression guard the owner said was missing: it pins that each appearance/lab flag the
// settings expose remains consumed by the renderer. If a refactor ever drops a flag from the renderer,
// its toggle silently becomes a do-nothing control (a floor violation) — and this test goes red.
@Suite("SS-GE (C) — graph appearance/lab toggles are wired to the renderer")
struct SSGEGraphToggleWiringTests {

    /// Flags exposed as toggles/sliders in GraphForceSettings that must be read by the MetalGraphView
    /// renderer for the control to do anything. Verified consumed (1–3 occurrences each) at audit time.
    private static let rendererConsumedFlags = [
        "enableFluidDynamics",
        "enableTorsionalSprings",
        "enableElasticEdges",
        "enableOrbital",
        "labelMaxNodes",
        "labelFontSizePx",
    ]

    @Test("every audited appearance/lab flag is consumed by the MetalGraphView renderer (not dead)")
    func appearanceFlagsAreConsumedByRenderer() throws {
        let renderer = try loadMirroredSourceTextFile("Epistemos/Views/Graph/MetalGraphView.swift")
        for flag in Self.rendererConsumedFlags {
            #expect(
                renderer.contains(flag),
                "Graph appearance/lab flag '\(flag)' is no longer read by MetalGraphView — its toggle would be a do-nothing control"
            )
        }
    }

    @Test("the audited flags are actually exposed as controls in GraphForceSettings (no orphan flags)")
    func auditedFlagsAreExposedAsControls() throws {
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Graph/GraphForceSettings.swift")
        for flag in Self.rendererConsumedFlags {
            #expect(
                settings.contains(flag),
                "Flag '\(flag)' is consumed by the renderer but no longer surfaced as a control in GraphForceSettings"
            )
        }
    }
}
