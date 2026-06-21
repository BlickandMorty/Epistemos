import Testing
import Foundation

@testable import Epistemos

// SS-HF (owner 2026-06-20): no-hidden-fallback / de-black-box — a model substitution (the chat P0
// fix runs the installed Qwen when the picked model isn't installed) must be visible AT THE POINT
// OF USE (in the chat), not only in the Settings LocalRouteHonestyRow. A real runnable model, never
// a stub — but never hidden either. This guards both the DATA (the substituted state is exposed)
// and the WIRING (the composer surfaces it).
@Suite("SS-HF — chat surfaces the model substitution at point of use")
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

    @Test("ChatInputBar surfaces the substitution in the composer (not only the Settings health row)")
    func chatComposerWiresTheSubstitutionNote() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        // A composer note reads the SAME substitution state + summary LocalRouteHonestyRow uses…
        #expect(src.contains("private var localModelSubstitutionNote: String?"))
        #expect(src.contains("case .substituted = inference.localModelResolutionState"))
        #expect(src.contains("return inference.localModelResolutionSummary"))
        // …and it actually renders in the composer (gated to .localMLX + to not stack with the
        // memory blocker), so the substitution is honest where the user sends.
        #expect(src.contains("case .localMLX = inference.effectiveChatSurfaceSelection"))
        #expect(src.contains("let substitution = localModelSubstitutionNote"))
    }
}
