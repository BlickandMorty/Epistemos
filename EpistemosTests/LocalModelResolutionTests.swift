import Testing
import Foundation
@testable import Epistemos

/// Owner #1 (no hidden GPT route) — locks the honest local-resolve trace: a picked
/// local model is either honored, or visibly substituted/unavailable with a reason,
/// never silently swapped for a different model or a cloud/GPT route.
@Suite("Local route honesty — the no-hidden-GPT local-resolve trace")
struct LocalModelResolutionTests {

    // MARK: pure summary logic (deterministic)

    @Test("usingPick has no warning; substituted + noLocalModel explain honestly")
    func summaries() {
        let honored = LocalModelResolutionState.usingPick(displayName: "Gemma 4 E4B")
        #expect(honored.summary == nil)
        #expect(honored.isHonoringPick)

        let sub = LocalModelResolutionState.substituted(
            pick: "Gemma 12B", using: "Qwen3 4B", reason: .exceedsMemory
        )
        #expect(sub.summary != nil)
        #expect(sub.summary?.contains("Gemma 12B") == true)
        #expect(sub.summary?.contains("Qwen3 4B") == true)
        #expect(sub.summary?.contains("too large") == true)
        #expect(!sub.isHonoringPick)

        let none = LocalModelResolutionState.noLocalModel(reason: .notInstalled)
        #expect(none.summary?.contains("No local model") == true)
        #expect(none.summary?.contains("never silently use a cloud model") == true)
        #expect(!none.isHonoringPick)
    }

    @Test("each unavailable reason has an honest phrase")
    func reasons() {
        #expect(LocalModelUnavailableReason.notInstalled.honestReason.contains("not installed"))
        #expect(LocalModelUnavailableReason.exceedsMemory.honestReason.contains("memory"))
        #expect(LocalModelUnavailableReason.awaitingSwiftLoader.honestReason.contains("loader"))
        #expect(LocalModelUnavailableReason.runtimeUnavailable.honestReason.contains("runtime"))
    }

    // MARK: behavioral (InferenceState)

    @MainActor
    @Test("an installed, resolved local pick is honored — no warning")
    func installedPickHonored() {
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen3_4B4Bit.rawValue)
        // sanitizedInteractive returns the pick unchanged → using-pick, no warning.
        #expect(inference.localModelResolutionState.isHonoringPick)
        #expect(inference.localModelResolutionSummary == nil)
    }

    @MainActor
    @Test("no installed local models → honest warning, never a silent fallback")
    func noModelsIsHonest() {
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([])
        // Nothing local resolves as the pick → NOT honoring-pick, and the summary
        // warns (so the surface is honestly "not ready", not a silent cloud route).
        #expect(!inference.localModelResolutionState.isHonoringPick)
        #expect(inference.localModelResolutionSummary != nil)
    }

    // MARK: wiring (mirrored-source)

    @Test("the diagnostic + visible row are wired and mounted in the health panel")
    func wiring() throws {
        let state = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        #expect(state.contains("var localModelResolutionState: LocalModelResolutionState"))
        #expect(state.contains("var localModelResolutionSummary: String?"))
        // The honest "honored" test is identity, not a normalized compare.
        #expect(state.contains("if effective == pickID {"))

        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/LocalRouteHonestyHealthRow.swift")
        #expect(row.contains("inference.localModelResolutionState"))

        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        #expect(panel.contains("LocalRouteHonestyHealthRow()"))
    }
}
