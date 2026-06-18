import Testing
import Foundation

/// P1.11 — locks that the runtime picker UI is driven by the rebuilt
/// EpistemosRuntimePicker model (explicit per-tier picks), not the old
/// operating-mode Tier rows. Behavioral coverage of the model lives in
/// EpistemosRuntimePickerTests; this guards the RootView wiring.
@Suite("Runtime picker panel wiring")
struct RuntimePickerPanelSourceGuardTests {

    @Test("the picker panel renders explicit picks from EpistemosRuntimePicker")
    func panelUsesRuntimePicker() throws {
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")

        // The rebuilt panel + its model-driven options.
        #expect(root.contains("foundationPickerSection"))
        #expect(root.contains("EpistemosRuntimePicker.options(for: tier, environment: runtimePickerEnvironment)"))
        // Selecting a pick pins the tier mode + the model (real switch, not fake).
        #expect(root.contains("func selectRuntimePick"))
        #expect(root.contains("inference.setPreferredChatModelSelection(.localMLX(option.id))"))

        // The old Tier section's mode-row loop is no longer the picker body
        // (it was replaced by foundationPickerSection in simplifiedRuntimePopover).
        #expect(!root.contains("popoverSectionTitle(\"Tier\")"))
    }
}
