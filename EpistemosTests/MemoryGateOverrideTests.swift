import Testing
import Foundation
@testable import Epistemos

/// Owner 2026-06-18 — the P1.4 memory blocker now has an explicit "Run anyway"
/// override + a more accurate available-memory estimate. The honest blocker stays
/// the default; this locks the override state machine + the wiring so neither
/// regresses (per-feature hardening).
@Suite("Memory gate override")
struct MemoryGateOverrideTests {

    @MainActor
    @Test("force toggles on/off and ignores blank ids")
    func forceTogglesAndIgnoresBlank() {
        let inference = InferenceState()
        let id = "Qwen/Qwen3-8B-MLX-4bit"
        // Robust to any persisted state: clear, then drive the transitions.
        inference.setMemoryGateForced(id, forced: false)
        #expect(!inference.memoryGateForcedModelIDs.contains(id))
        inference.setMemoryGateForced(id, forced: true)
        #expect(inference.memoryGateForcedModelIDs.contains(id))
        inference.setMemoryGateForced("   ", forced: true)  // blank ignored
        #expect(!inference.memoryGateForcedModelIDs.contains("   "))
        inference.setMemoryGateForced(id, forced: false)
        #expect(!inference.memoryGateForcedModelIDs.contains(id))
    }

    @Test("the blocker honors the forced set; the estimate counts reclaimable + speculative")
    func wiringIsIntact() throws {
        let inference = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        // The blocker short-circuits to nil for a force-loaded model.
        #expect(inference.contains("if memoryGateForcedModelIDs.contains(modelID) { return nil }"))
        // The blocker + override target the SAME model id (shared resolver).
        #expect(inference.contains("func memoryGateModelID(for operatingMode: EpistemosOperatingMode) -> String?"))

        // Accuracy: available memory counts free + inactive + purgeable + speculative.
        let monitor = try loadMirroredSourceTextFile("Epistemos/Engine/LocalInferenceSerialController.swift")
        #expect(monitor.contains("statistics.speculative_count"))
    }
}
