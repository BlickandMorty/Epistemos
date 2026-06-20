import Testing
import Foundation
@testable import Epistemos

/// SS-X (owner 2026-06-19, "the bottom message bar still shows think/pro/tools —
/// old options I thought I simplified"): the legacy split toolbar must NOT render
/// on the main chat bar when the simplified lineup is active (the default). The
/// flat inlineRuntimePickerTrigger + Settings carry those controls, so this is a
/// de-duplication, not a deletion.
@Suite("Chat message-bar de-muddify (SS-X)")
struct ChatBarSimplifyTests {

    @Test("simplified lineup is active by default (env opt-out only)")
    func simplifiedDefaultsOn() {
        let optedOut = ProcessInfo.processInfo.environment["EPISTEMOS_SIMPLIFIED_LINEUP"] == "0"
        #expect(EpistemosFoundationLineup.simplifiedLineupActive == !optedOut)
    }

    @Test("the legacy split toolbar is gated on !simplifiedLineupActive in the main bar")
    func splitToolbarGatedInMainBar() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        // The legacy ChatBrainPickerMenu(preferSplitToolbarControls:true) — the
        // Think/Code/Tools/Pro row — must be wrapped in the simplified-lineup gate,
        // not rendered unconditionally next to the flat picker.
        #expect(src.contains("if !EpistemosFoundationLineup.simplifiedLineupActive"))
        #expect(src.contains("preferSplitToolbarControls: true"))
        // The flat trigger that replaces it stays unconditional.
        #expect(src.contains("inlineRuntimePickerTrigger"))
    }
}
