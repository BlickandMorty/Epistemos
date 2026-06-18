import Testing
@testable import Epistemos

/// Owner 2026-06-18 — Unsloth Gemma 4 12B at 2-bit (UD-Q2_K_XL) — a big 12B that
/// fits a 16 GB Mac. Locks its provenance + that it's a Think-tier explicit-only
/// pick (NOT Fast — its big-model-low-memory profile would break Fast sizing).
@Suite("Gemma 4 12B 2-bit candidate")
struct Gemma12B2BitCandidateTests {

    private let id = "unsloth/gemma-4-12b-it-GGUF"

    @Test("Think-tier Gemma GGUF candidate with real 2-bit provenance, gated at 10 GB")
    func candidateIsWiredWithProvenance() {
        let candidate = GemmaQATRuntimeLadder.candidates.first { $0.id == id }
        #expect(candidate != nil)
        #expect(candidate?.stage == .gemmaTwelveBLowMemory)
        #expect(candidate?.stage.epistemosTier == .think)     // Think, not Fast
        #expect(candidate?.minimumRecommendedMemoryGB == 10)
        #expect(candidate?.familyName == "Gemma 4 QAT GGUF")  // it IS Gemma
        #expect(candidate?.runtimeLane == "gguf_llama_cpp_offline")
        #expect(candidate?.expectedFilename == "gemma-4-12b-it-UD-Q2_K_XL.gguf")
        #expect(candidate?.expectedFileBytes == 4_661_418_400)
        #expect(candidate?.expectedSHA256 == "19ab0f2dbe76aa2dae227054c9d777dc96f11688282d705738cb9c4c70bed489")
    }

    @Test("NOT in Fast (no sizing pollution); IS in Think; default unchanged")
    func notFastDefaultUnchanged() {
        #expect(EpistemosFoundationLineup.foundationModelIDs.contains(id))
        #expect(EpistemosFoundationLineup.candidates(for: .fast).allSatisfy { $0.id != id })
        #expect(EpistemosFoundationLineup.candidates(for: .think).contains { $0.id == id })
        #expect(EpistemosFoundationLineup.defaultChatModelID != id)
    }

    @Test("fits a 16 GB Mac — selectable in the Think picker, not blocked")
    func fitsAndSelectableOn16GB() {
        let opts = EpistemosRuntimePicker.options(
            for: .think,
            environment: .init(installedModelIDs: [id], freeMemoryGB: 16, appleIntelligenceAvailable: false)
        )
        let opt = opts.first { $0.id == id }
        #expect(opt?.isSelectable == true)   // 16 + 6 >= 10 → fits (the point of 2-bit)
        #expect(opt?.blockedReason == nil)
    }
}
