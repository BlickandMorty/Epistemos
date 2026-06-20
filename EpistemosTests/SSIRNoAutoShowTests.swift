import Testing
import Foundation

@testable import Epistemos

// SS-IR (owner 2026-06-20): the owner's "weird pixel box that overlays things" = Surface B
// (Contextual Shadows) auto-popping its panel mid-typing on any query hit. This slice stops the
// auto-open: a query still LIGHTS the button (payload published) but only KEEPS the panel visible
// if the user had already opened it; explicit openPanel() is the sole opener.
@Suite("SS-IR Surface B no longer auto-opens (de-invasive)")
struct SSIRNoAutoShowTests {

    // publishPayload (the async query-result path, private) must preserve-if-open, never force-open.
    @Test("publishPayload preserves an open panel but never auto-opens a closed one")
    func publishPayloadDoesNotAutoOpen() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/State/ContextualShadowsState.swift")
        // Global + scoped visibility are now AND-ed with prior visibility (preserve-if-open),
        // not a forced `= isVisible`. This is the fix for the box popping up while typing.
        #expect(src.contains("isPanelVisible = isVisible && isPanelVisible"))
        #expect(src.contains("scopedPanelVisibility[scopeKey] = isVisible && scopeWasOpen"))
        // The explicit opener still force-opens (so the lit button can be clicked open).
        #expect(src.contains("func openPanel()"))
        #expect(src.contains("isPanelVisible = true"))
    }
}
