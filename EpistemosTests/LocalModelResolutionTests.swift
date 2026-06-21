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

    // P0 (owner 2026-06-20): chat returned NO answer from ANY local model. Root cause in
    // `effectiveLocalTextModelID(for:)`: an UNCONDITIONAL `return installedFoundationModelID(for:
    // .fast)` inside the `hasInstalledFoundationModel` block returned nil when no Fast Gemma fit
    // (e.g. a 16 GB Mac with no Fast Gemma installed) — and that nil BYPASSED the Qwen/runnable-
    // local fall-through below it, so a tier whose own foundation wasn't installed resolved to
    // nil and stranded an installed, runnable Qwen → dead chat.
    //
    // The tier resolution is a private method gated on COMPUTED, hardware-dependent state
    // (simplifiedLineupActive + hasInstalledFoundationModel true while BOTH .fast and the tier's
    // foundation are absent), so a behavioral test would be fragile on this P0 path. Source-guard
    // the fix deterministically instead — same mirrored-source technique as `wiring()` above. The
    // owner verifies the real send on-device.
    @Test("a foundation tier whose own model isn't installed never returns a nil Fast baseline that strands a runnable Qwen")
    func tierWithoutFoundationDoesNotStrandRunnableLocal() throws {
        let state = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        // The buggy unconditional return must be GONE...
        #expect(
            !state.contains("return installedFoundationModelID(for: .fast)"),
            "the Fast-baseline return must be GUARDED, never an unconditional nil-return that strands Qwen")
        // ...replaced by a guarded return that only fires when a Fast baseline actually exists,
        // so a missing Fast Gemma FALLS THROUGH to the Qwen/runnable-local branch (non-nil).
        #expect(state.contains("if let fastBaseline = installedFoundationModelID(for: .fast) {"))
        #expect(state.contains("return fastBaseline"))
    }
}
