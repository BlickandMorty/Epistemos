import Testing
@testable import Epistemos

/// P1.11 — locks the rebuilt picker's selection/gating truth: Fast offers the
/// Gemma sizes + Apple Intelligence, gating is honest (installed + fits memory),
/// blocked picks still appear with a reason, and Think/Code each offer one model.
@Suite("Epistemos runtime picker")
struct EpistemosRuntimePickerTests {

    private func env(
        installed: Set<String>,
        freeGB: Double,
        ai: Bool = false,
        headroom: Double = 2
    ) -> EpistemosRuntimePicker.Environment {
        .init(installedModelIDs: installed, freeMemoryGB: freeGB, headroomGB: headroom, appleIntelligenceAvailable: ai)
    }

    @Test("Fast offers the Gemma sizes plus Apple Intelligence (4th pick)")
    func fastOffersGemmaSizesPlusAppleIntelligence() {
        let fast = EpistemosFoundationLineup.candidates(for: .fast)
        #expect(!fast.isEmpty)  // lineup present
        let options = EpistemosRuntimePicker.options(
            for: .fast,
            environment: env(installed: [], freeGB: 8, ai: true)
        )
        #expect(options.count == fast.count + 1)              // sizes + Apple Intelligence
        #expect(options.last?.isAppleIntelligence == true)
        #expect(options.last?.id == EpistemosRuntimePicker.appleIntelligenceID)
        #expect(options.dropLast().allSatisfy { !$0.isAppleIntelligence })
    }

    @Test("an installed model that fits memory is selectable; one that doesn't is blocked but shown")
    func memoryGatingIsHonest() {
        let fast = EpistemosFoundationLineup.candidates(for: .fast)
        let smallest = fast.first!   // lowest minimumRecommendedMemoryGB
        let largest = fast.last!     // highest

        // Plenty of memory, smallest installed → selectable.
        let plenty = EpistemosRuntimePicker.options(
            for: .fast,
            environment: env(installed: [smallest.id], freeGB: 64)
        )
        let smallOpt = plenty.first { $0.id == smallest.id }
        #expect(smallOpt?.isSelectable == true)
        #expect(smallOpt?.blockedReason == nil)

        // Largest installed but only a sliver of memory → shown, blocked w/ reason.
        let tight = EpistemosRuntimePicker.options(
            for: .fast,
            environment: env(installed: [largest.id], freeGB: 1)
        )
        let bigOpt = tight.first { $0.id == largest.id }
        #expect(bigOpt != nil)                       // NOT hidden
        #expect(bigOpt?.isInstalled == true)
        #expect(bigOpt?.isSelectable == false)
        #expect(bigOpt?.blockedReason?.contains("Needs") == true)
    }

    @Test("a not-installed model is shown with an install hint, not selectable")
    func notInstalledIsShownWithHint() {
        let fast = EpistemosFoundationLineup.candidates(for: .fast)
        let options = EpistemosRuntimePicker.options(for: .fast, environment: env(installed: [], freeGB: 64))
        let any = options.first { !$0.isAppleIntelligence }
        #expect(any?.isInstalled == false)
        #expect(any?.isSelectable == false)
        #expect(any?.blockedReason == "Not installed — tap to install")
        _ = fast
    }

    @Test("Apple Intelligence selectable only when available")
    func appleIntelligenceGating() {
        let on = EpistemosRuntimePicker.options(for: .fast, environment: env(installed: [], freeGB: 8, ai: true))
        #expect(on.last?.isSelectable == true)
        #expect(on.last?.blockedReason == nil)
        let off = EpistemosRuntimePicker.options(for: .fast, environment: env(installed: [], freeGB: 8, ai: false))
        #expect(off.last?.isSelectable == false)
        #expect(off.last?.blockedReason == "Not available on this Mac")
    }

    @Test("Think and Code each offer their foundation model and no Apple Intelligence")
    func thinkAndCodeHaveNoAppleIntelligence() {
        for tier in [EpistemosModelTier.think, .code] {
            let options = EpistemosRuntimePicker.options(for: tier, environment: env(installed: [], freeGB: 64))
            #expect(!options.isEmpty)
            #expect(options.allSatisfy { !$0.isAppleIntelligence })
            #expect(options.allSatisfy { $0.tier == tier })
        }
    }

    @Test("Qwen 3 8B is a visible explicit Think pick, memory-gated (not a silent fallback)")
    func qwen8BIsExplicitThinkPick() {
        let qwenID = "Qwen/Qwen3-8B-MLX-4bit"

        // Installed + plenty of memory → a selectable, visible Think option.
        let ok = EpistemosRuntimePicker.options(
            for: .think,
            environment: env(installed: [qwenID], freeGB: 64)
        )
        let qwen = ok.first { $0.id == qwenID }
        #expect(qwen != nil)                  // visible, not hidden
        #expect(qwen?.title == "Qwen 3 8B")
        #expect(qwen?.tier == .think)
        #expect(qwen?.isSelectable == true)
        #expect(qwen?.isAppleIntelligence == false)

        // Installed but no memory → still shown, honestly blocked (P1.4), not silent.
        let tight = EpistemosRuntimePicker.options(
            for: .think,
            environment: env(installed: [qwenID], freeGB: 2)
        )
        let blocked = tight.first { $0.id == qwenID }
        #expect(blocked?.isInstalled == true)
        #expect(blocked?.isSelectable == false)
        #expect(blocked?.blockedReason?.contains("Needs") == true)

        // It is NOT offered under Fast or Code (Think only).
        #expect(EpistemosRuntimePicker.options(for: .fast, environment: env(installed: [qwenID], freeGB: 64))
            .allSatisfy { $0.id != qwenID })
        #expect(EpistemosRuntimePicker.options(for: .code, environment: env(installed: [qwenID], freeGB: 64))
            .allSatisfy { $0.id != qwenID })
    }

    @Test("cleanTitle simplifies the verbose GGUF display names")
    func cleanTitleSimplifies() {
        #expect(EpistemosRuntimePicker.cleanTitle(for: "Gemma 4 E2B QAT GGUF") == "Gemma 2B")
        #expect(EpistemosRuntimePicker.cleanTitle(for: "Gemma 4 E4B QAT GGUF") == "Gemma 4B")
        #expect(EpistemosRuntimePicker.cleanTitle(for: "Gemma 4 12B QAT GGUF") == "Gemma 12B")
        #expect(EpistemosRuntimePicker.cleanTitle(for: "Gemma 4 12B Coder QAT GGUF") == "Gemma 12B Coder")
    }
}
