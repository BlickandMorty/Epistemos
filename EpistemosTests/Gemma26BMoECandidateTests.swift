import Testing
@testable import Epistemos

/// Owner 2026-06-18 — the Unsloth Gemma 4 26B-A4B MoE QAT GGUF wired into the
/// Pro GGUF runtime lane as an installable, memory-gated, explicit-only Fast
/// pick. Locks the candidate's provenance + gating so it can't regress.
@Suite("Gemma 4 26B-A4B MoE candidate")
struct Gemma26BMoECandidateTests {

    private let id = "unsloth/gemma-4-26B-A4B-it-qat-GGUF"

    @Test("the 26B-A4B MoE is a Fast-tier GGUF candidate with real provenance, gated at 18 GB")
    func candidateIsWiredWithProvenance() {
        let candidate = GemmaQATRuntimeLadder.candidates.first { $0.id == id }
        #expect(candidate != nil)
        #expect(candidate?.stage == .moeFlagshipCandidate)
        #expect(candidate?.stage.epistemosTier == .fast)
        #expect(candidate?.minimumRecommendedMemoryGB == 18)
        #expect(candidate?.runtimeLane == "gguf_llama_cpp_offline")
        // Real HF provenance (the integrity gate needs these exact).
        #expect(candidate?.expectedFilename == "gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf")
        #expect(candidate?.expectedFileBytes == 14_249_045_120)
        #expect(candidate?.expectedSHA256 == "dcf179a91153e3a7ece792e48ef872180d9d6ef9b7677f0a0bd3e83cfe624d5e")
    }

    @Test("installable, but NOT the default and never auto-routed (explicit-only)")
    func installableButNotDefault() {
        #expect(EpistemosFoundationLineup.foundationModelIDs.contains(id))
        // The Fast default stays the smallest Gemma (E2B), never the 26B.
        #expect(EpistemosFoundationLineup.defaultChatModelID != id)
        #expect(EpistemosFoundationLineup.representativeModelID(for: .fast) != id)
    }

    @Test("appears in the Fast picker, honestly memory-gated (blocked on a small Mac, shown not hidden)")
    func appearsInPickerMemoryGated() {
        let tight = EpistemosRuntimePicker.options(
            for: .fast,
            environment: .init(installedModelIDs: [id], freeMemoryGB: 4, appleIntelligenceAvailable: false)
        )
        let opt = tight.first { $0.id == id }
        #expect(opt != nil)                       // visible, never hidden
        #expect(opt?.isInstalled == true)
        #expect(opt?.isSelectable == false)       // 4 + 6 headroom < 18 → blocked
        #expect(opt?.blockedReason?.contains("Needs") == true)  // honest reason ("Run anyway" overrides)

        // With plenty of memory it becomes selectable.
        let roomy = EpistemosRuntimePicker.options(
            for: .fast,
            environment: .init(installedModelIDs: [id], freeMemoryGB: 64, appleIntelligenceAvailable: false)
        )
        #expect(roomy.first { $0.id == id }?.isSelectable == true)
    }
}
