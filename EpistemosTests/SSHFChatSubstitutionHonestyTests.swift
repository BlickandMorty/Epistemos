import Testing
import Foundation

@testable import Epistemos

// SS-HF (owner 2026-06-20): no-hidden-fallback / de-black-box — a model
// substitution must remain explicit in inference state. Point-of-use UI must
// consume this same state instead of hiding substitutions.
@Suite("SS-HF — model substitution state stays explicit")
struct SSHFChatSubstitutionHonestyTests {

    @MainActor
    @Test("an uninstalled-Gemma pick with Qwen installed exposes a SUBSTITUTED state + honest summary")
    func substitutionStateIsExposedForTheChatNote() {
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3_4B4Bit.rawValue])
        // A real Gemma QAT GGUF candidate that is NOT installed (only Qwen is).
        inference.setPreferredLocalTextModelID("google/gemma-4-E4B-it-qat-q4_0-gguf")
        // The chat reads exactly this state to render its point-of-use note: SUBSTITUTED (the pick
        // is not honored as-selected — Qwen runs instead) with a non-nil honest summary.
        guard case .substituted = inference.localModelResolutionState else {
            Issue.record("expected .substituted when the pick is uninstalled and the installed Qwen runs")
            return
        }
        #expect(inference.localModelResolutionSummary != nil)
    }
}
