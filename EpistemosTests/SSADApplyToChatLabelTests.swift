import Testing
import Foundation

@testable import Epistemos

// SS-AD (owner 2026-06-20, "Settings apply-to-chat"): the adapter selector menu now names
// its action — a "Apply to local chat" section header — so it's clear that picking an
// adapter applies it to the next local response (it reloads the on-disk active adapter),
// rather than being an opaque list. Source-guarded (the menu is view-private).
@Suite("SS-AD apply-to-chat label")
struct SSADApplyToChatLabelTests {

    @Test("the adapter selector names the apply-to-chat action")
    func adapterSelectorNamesApplyToChat() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/KnowledgeFusion/UI/AdapterSelectorView.swift")
        #expect(src.contains("Section(\"Apply to local chat\")"))
    }
}
