import Testing
@testable import Epistemos

/// Owner 2026-06-18 — LiquidAI LFM2.5-8B-A1B GGUF (light general MoE, ~1B active)
/// wired into the GGUF lane as a Think-tier, explicit-only pick. Locks its
/// provenance + that it does NOT join the Fast Gemma effort-sizing ladder.
@Suite("LFM2.5-8B-A1B MoE candidate")
struct LFM25MoECandidateTests {

    private let id = "LiquidAI/LFM2.5-8B-A1B-GGUF"

    @Test("Think-tier GGUF candidate with real provenance, gated at 10 GB")
    func candidateIsWiredWithProvenance() {
        let candidate = GemmaQATRuntimeLadder.candidates.first { $0.id == id }
        #expect(candidate != nil)
        #expect(candidate?.stage == .liquidGeneralMoe)
        #expect(candidate?.stage.epistemosTier == .think)   // Think, not Fast
        #expect(candidate?.minimumRecommendedMemoryGB == 10)
        #expect(candidate?.familyName == "LFM2.5 GGUF")      // NOT Gemma
        #expect(candidate?.runtimeLane == "gguf_llama_cpp_offline")
        #expect(candidate?.expectedFilename == "LFM2.5-8B-A1B-Q4_K_M.gguf")
        #expect(candidate?.expectedFileBytes == 5_155_564_768)
        #expect(candidate?.expectedSHA256 == "4923ec14f06b968b74d663e5949867d2d9c3bf13a20b8be1a9f9af39989b2bb0")
    }

    @Test("installable; NOT a Fast candidate (no Gemma sizing pollution); Think default stays VibeThinker")
    func notFastThinkDefaultUnchanged() {
        #expect(EpistemosFoundationLineup.foundationModelIDs.contains(id))
        // Critical: it must NOT be in the Fast tier (that would pollute the
        // Gemma effort-sizing ladder), and IT IS in the Think tier.
        #expect(EpistemosFoundationLineup.candidates(for: .fast).allSatisfy { $0.id != id })
        #expect(EpistemosFoundationLineup.candidates(for: .think).contains { $0.id == id })
        // The lighter VibeThinker stays the Think representative/default.
        #expect(EpistemosFoundationLineup.representativeModelID(for: .think) != id)
        #expect(EpistemosFoundationLineup.defaultChatModelID != id)
    }

    @Test("fits a 16 GB Mac — selectable in the Think picker, not blocked")
    func fitsAndSelectableOn16GB() {
        let opts = EpistemosRuntimePicker.options(
            for: .think,
            environment: .init(installedModelIDs: [id], freeMemoryGB: 16, appleIntelligenceAvailable: false)
        )
        let opt = opts.first { $0.id == id }
        #expect(opt != nil)
        #expect(opt?.isSelectable == true)        // 16 + 6 >= 10 → fits, MAS-viable
        #expect(opt?.blockedReason == nil)
    }
}
