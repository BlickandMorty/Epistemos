import Testing
@testable import Epistemos

/// Locks the Fast/Think/Code foundation lineup (2026-06-16 pivot). Pure,
/// deterministic logic — no InferenceState / hardware / flag dependency — so it
/// guards the source of truth the simplified picker, Settings tier display, and
/// mode→model binding all read from.
@Suite("Epistemos Foundation Lineup")
struct EpistemosFoundationLineupTests {

    // MARK: - Model ids (must match GemmaQATRuntimeLadder.candidates)
    private static let e2b = "google/gemma-4-E2B-it-qat-q4_0-gguf"
    private static let e4b = "google/gemma-4-E4B-it-qat-q4_0-gguf"
    private static let b12 = "google/gemma-4-12B-it-qat-q4_0-gguf"
    private static let coder = "yuxinlu1/gemma-4-12B-coder-fable5-composer2.5-v1-GGUF"
    private static let vibe = "oussaber/VibeThinker-3B-Q4_K_M-GGUF"

    @Test("tier is derived from the GGUF runtime stage")
    func tierDerivedFromStage() {
        #expect(GemmaQATRuntimeStage.firstRuntimeHarness.epistemosTier == .fast)
        #expect(GemmaQATRuntimeStage.nextScaleLane.epistemosTier == .fast)
        #expect(GemmaQATRuntimeStage.proFlagshipCandidate.epistemosTier == .fast)
        #expect(GemmaQATRuntimeStage.reasoningSpecialist.epistemosTier == .think)
        #expect(GemmaQATRuntimeStage.specialistCoderFineTune.epistemosTier == .code)
    }

    @Test("there are exactly three tiers with branded names")
    func threeBrandedTiers() {
        #expect(EpistemosModelTier.allCases == [.fast, .think, .code])
        #expect(EpistemosModelTier.fast.displayName == "Epistemos Fast")
        #expect(EpistemosModelTier.think.displayName == "Epistemos Think")
        #expect(EpistemosModelTier.code.displayName == "Epistemos Code")
        #expect(EpistemosModelTier.fast.shortName == "Fast")
    }

    @Test("Fast tier is the three Gemma sizes, smallest→largest")
    func fastTierIsGemmaSizes() {
        let fast = EpistemosFoundationLineup.candidates(for: .fast).map(\.id)
        #expect(fast == [Self.e2b, Self.e4b, Self.b12])
    }

    @Test("Think is VibeThinker, Code is the coder — one model each")
    func thinkAndCodeSingleModels() {
        #expect(EpistemosFoundationLineup.candidates(for: .think).map(\.id) == [Self.vibe])
        #expect(EpistemosFoundationLineup.candidates(for: .code).map(\.id) == [Self.coder])
    }

    @Test("foundation model id set is exactly the five GGUF models")
    func foundationModelIDSet() {
        let ids = EpistemosFoundationLineup.foundationModelIDs
        #expect(ids.count == 5)
        #expect(ids == Set([Self.e2b, Self.e4b, Self.b12, Self.coder, Self.vibe]))
    }

    @Test("tier lookup by model id resolves the right tier")
    func tierForModelID() {
        #expect(EpistemosFoundationLineup.tier(forModelID: Self.e2b) == .fast)
        #expect(EpistemosFoundationLineup.tier(forModelID: Self.b12) == .fast)
        #expect(EpistemosFoundationLineup.tier(forModelID: Self.vibe) == .think)
        #expect(EpistemosFoundationLineup.tier(forModelID: Self.coder) == .code)
        #expect(EpistemosFoundationLineup.tier(forModelID: "mlx-community/Qwen3.5-4B-4bit") == nil)
    }

    @Test("representative model: Fast→smallest Gemma, Think→VibeThinker, Code→coder")
    func representativeModelID() {
        #expect(EpistemosFoundationLineup.representativeModelID(for: .fast) == Self.e2b)
        #expect(EpistemosFoundationLineup.representativeModelID(for: .think) == Self.vibe)
        #expect(EpistemosFoundationLineup.representativeModelID(for: .code) == Self.coder)
    }

    @Test("operating modes bind to tiers; Tools/agent has no model tier")
    func operatingModeTierBinding() {
        #expect(EpistemosOperatingMode.fast.epistemosModelTier == .fast)
        #expect(EpistemosOperatingMode.thinking.epistemosModelTier == .think)
        #expect(EpistemosOperatingMode.pro.epistemosModelTier == .code)
        #expect(EpistemosOperatingMode.agent.epistemosModelTier == nil)
    }

    @Test("simplified lineup migrates a stored legacy Qwen selection onto the foundation lineup")
    @MainActor func simplifiedMigratesLegacySelectionOffQwen() {
        // Guard: this behavior only holds under the simplified lineup (the
        // default). If a runner sets EPISTEMOS_SIMPLIFIED_LINEUP=0, no migration.
        guard EpistemosFoundationLineup.simplifiedLineupActive else { return }

        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            )
        )
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])

        let gemmaE2B = "google/gemma-4-E2B-it-qat-q4_0-gguf"
        let qwen = LocalTextModelID.qwen3_4B4Bit.rawValue

        // Pin a legacy Qwen while a foundation GGUF is installed.
        inference.setInstalledLocalTextModelIDs([gemmaE2B, qwen])
        inference.setPreferredLocalTextModelID(qwen)

        // The effective model migrates to the foundation lineup (never Qwen).
        #expect(inference.effectiveLocalTextModelID == gemmaE2B)

        // Without any foundation installed, the legacy selection is kept
        // (nothing breaks before the foundation package is installed).
        inference.setInstalledLocalTextModelIDs([qwen])
        inference.setPreferredLocalTextModelID(qwen)
        #expect(inference.effectiveLocalTextModelID == qwen)
    }

    @Test("simplified: an explicit within-Fast Gemma size pick is respected, never bumped to the tier default")
    @MainActor func simplifiedRespectsWithinFastGemmaPick() {
        guard EpistemosFoundationLineup.simplifiedLineupActive else { return }

        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            )
        )
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])
        inference.setInstalledLocalTextModelIDs([Self.e2b, Self.e4b, Self.b12, Self.vibe, Self.coder])

        // Smallest Gemma pinned under Fast. The 64 GB cross-tier Fast default is
        // the largest-that-fits-with-headroom (the 12B), so this proves an
        // explicit within-tier pick is NOT silently bumped up.
        inference.setPreferredChatModelSelection(.localMLX(Self.e2b))
        #expect(inference.effectiveChatSurfaceSelection(for: .fast) == .localMLX(Self.e2b))

        // The largest Gemma is likewise respected when pinned.
        inference.setPreferredChatModelSelection(.localMLX(Self.b12))
        #expect(inference.effectiveChatSurfaceSelection(for: .fast) == .localMLX(Self.b12))
    }

    @Test("simplified: switching modes rebinds to the tier's foundation model (Fast→Gemma, Think→VibeThinker, Code→coder)")
    @MainActor func simplifiedModeSwitchBindsToTierFoundationModel() {
        guard EpistemosFoundationLineup.simplifiedLineupActive else { return }

        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            )
        )
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])
        inference.setInstalledLocalTextModelIDs([Self.e2b, Self.e4b, Self.b12, Self.vibe, Self.coder])

        // User pinned a specific Gemma (Fast tier). Switching the operating mode
        // to a different tier rebinds to THAT tier's foundation model — the
        // honesty guarantee that a Think/Code mode never silently serves a Fast
        // model (and never the removed Qwen). VibeThinker/coder are reached via
        // the installed+hardware-supported path, not the route-proof gate, so
        // this holds for the receipt-pending Think/Code models too.
        inference.setPreferredChatModelSelection(.localMLX(Self.e2b))
        #expect(inference.effectiveChatSurfaceSelection(for: .fast) == .localMLX(Self.e2b))       // within-tier pick kept
        #expect(inference.effectiveChatSurfaceSelection(for: .thinking) == .localMLX(Self.vibe))  // → VibeThinker
        #expect(inference.effectiveChatSurfaceSelection(for: .pro) == .localMLX(Self.coder))      // → coder
    }
}
