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

    @Test("simplified + foundation installed: the three Epistemos efforts are always offered (guards the 'only Fast' collapse)")
    @MainActor func simplifiedOffersThreeEffortsWithFoundationInstalled() {
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

        // A GGUF Gemma selection can't map to a LocalTextModelID, which used to
        // collapse the mode set to Fast-only (the owner's "I only see Fast"
        // report). With a foundation model installed the three branded efforts
        // are always offered.
        inference.setPreferredChatModelSelection(.localMLX(Self.b12))
        let modes = inference.availableOperatingModes
        #expect(modes.contains(.fast))
        #expect(modes.contains(.thinking))
        #expect(modes.contains(.pro))
    }

    @Test("simplified but NO foundation installed: modes stay model-derived (no forced Code tier — the no-churn gate)")
    @MainActor func simplifiedWithoutFoundationKeepsModelDerivedModes() {
        guard EpistemosFoundationLineup.simplifiedLineupActive else { return }

        // Legacy MLX-only setup (a Qwen the user still has, no foundation GGUF).
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3_4B4Bit.rawValue])
        inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen3_4B4Bit.rawValue))

        // The branded three-tier union only fires once a foundation GGUF is
        // installed, so a legacy model keeps its own capability-derived modes —
        // Code (.pro) is NOT forced on. This is the gate that keeps the change
        // from churning every legacy-model test.
        #expect(!inference.hasInstalledFoundationModel)
        #expect(!inference.availableOperatingModes.contains(.pro))
    }

    @Test("simplified: on a 16 GB Mac, a within-Fast 12B pick falls to the headroom-aware E4B (Fast stays quick, not pinned to 12B)")
    @MainActor func simplifiedFastFallsOffMemoryTight12BOn16GB() {
        guard EpistemosFoundationLineup.simplifiedLineupActive else { return }

        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 16_000_000_000,
                roundedMemoryGB: 16,
                maxRecommendedLocalContentLength: 8_000
            )
        )
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])
        inference.setInstalledLocalTextModelIDs([Self.e2b, Self.e4b, Self.b12])

        // Pin the 12B under Fast. It "fits" (16 GB ≥ 16 GB floor) but with NO
        // headroom — exactly the case that left every 16 GB user stuck on the
        // memory-tight 12B. Fast resolves to the headroom-aware E4B instead.
        inference.setPreferredChatModelSelection(.localMLX(Self.b12))
        #expect(inference.effectiveChatSurfaceSelection(for: .fast) == .localMLX(Self.e4b))
    }

    // MARK: - P1.5 Fast "three efforts" per-query sizing (pure policy)

    @Test("Fast effort sizing maps complexity bands to ascending sizes (3 candidates)")
    func fastEffortSizingThreeCandidates() {
        // trivial → smallest (index 0), medium → middle (1), hard → largest (2).
        #expect(EpistemosFastEffortSizing.candidateIndex(forComplexity: 0.0, candidateCount: 3) == 0)
        #expect(EpistemosFastEffortSizing.candidateIndex(forComplexity: 0.10, candidateCount: 3) == 0)
        #expect(EpistemosFastEffortSizing.candidateIndex(forComplexity: 0.45, candidateCount: 3) == 1)
        #expect(EpistemosFastEffortSizing.candidateIndex(forComplexity: 0.80, candidateCount: 3) == 2)
        // Threshold edges: 0.30 leaves the trivial band, 0.60 enters the hard band.
        #expect(EpistemosFastEffortSizing.candidateIndex(forComplexity: 0.30, candidateCount: 3) == 1)
        #expect(EpistemosFastEffortSizing.candidateIndex(forComplexity: 0.60, candidateCount: 3) == 2)
    }

    @Test("Fast effort sizing clamps a hard query onto the largest that fits (2 candidates)")
    func fastEffortSizingTwoCandidatesClamps() {
        // 16 GB Mac: only E2B + E4B fit with headroom, so a "hard" query collapses
        // onto the larger of the two rather than running off the end.
        #expect(EpistemosFastEffortSizing.candidateIndex(forComplexity: 0.10, candidateCount: 2) == 0)
        #expect(EpistemosFastEffortSizing.candidateIndex(forComplexity: 0.50, candidateCount: 2) == 1)
        #expect(EpistemosFastEffortSizing.candidateIndex(forComplexity: 0.95, candidateCount: 2) == 1)
    }

    @Test("Fast effort sizing is safe at the degenerate edges (1 candidate, out-of-range complexity)")
    func fastEffortSizingEdges() {
        // Nothing to size between → always index 0.
        #expect(EpistemosFastEffortSizing.candidateIndex(forComplexity: 0.9, candidateCount: 1) == 0)
        #expect(EpistemosFastEffortSizing.candidateIndex(forComplexity: 0.9, candidateCount: 0) == 0)
        // Complexity is clamped to [0, 1] before banding.
        #expect(EpistemosFastEffortSizing.candidateIndex(forComplexity: -0.5, candidateCount: 3) == 0)
        #expect(EpistemosFastEffortSizing.candidateIndex(forComplexity: 1.5, candidateCount: 3) == 2)
    }

    // MARK: - P1.5 Fast sizing wired into InferenceState

    @Test("simplified: on a roomy Mac, Fast sizes the model per query (trivial→E2B, medium→E4B, hard→12B)")
    @MainActor func simplifiedFastSizesPerQueryOnRoomyMac() {
        guard EpistemosFoundationLineup.simplifiedLineupActive else { return }

        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            )
        )
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])
        inference.setInstalledLocalTextModelIDs([Self.e2b, Self.e4b, Self.b12])

        // On 64 GB all three Gemma sizes fit with headroom, so the Fast default is
        // the 12B — the per-query "on the default" gate. Sizing then walks down
        // for easy queries and back up for hard ones.
        inference.setPreferredLocalTextModelID(Self.b12)
        #expect(inference.sizedFastLocalTextModelID(forComplexity: 0.05, operatingMode: .fast) == Self.e2b)
        #expect(inference.sizedFastLocalTextModelID(forComplexity: 0.45, operatingMode: .fast) == Self.e4b)
        #expect(inference.sizedFastLocalTextModelID(forComplexity: 0.85, operatingMode: .fast) == Self.b12)
    }

    @Test("simplified: on a 16 GB Mac, Fast sizing never reaches the memory-tight 12B (caps at E4B)")
    @MainActor func simplifiedFastSizingCapsAtE4BOn16GB() {
        guard EpistemosFoundationLineup.simplifiedLineupActive else { return }

        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 16_000_000_000,
                roundedMemoryGB: 16,
                maxRecommendedLocalContentLength: 8_000
            )
        )
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])
        inference.setInstalledLocalTextModelIDs([Self.e2b, Self.e4b, Self.b12])

        // Even a stored 12B resolves to the headroom-aware E4B default on 16 GB,
        // so sizing is "on the default" and walks E2B ↔ E4B. A hard query caps at
        // E4B — the 12B is never auto-selected on a memory-tight Mac.
        inference.setPreferredLocalTextModelID(Self.b12)
        #expect(inference.sizedFastLocalTextModelID(forComplexity: 0.05, operatingMode: .fast) == Self.e2b)
        #expect(inference.sizedFastLocalTextModelID(forComplexity: 0.95, operatingMode: .fast) == Self.e4b)
    }

    @Test("simplified: Fast sizing honors an explicit smaller within-Fast pick and never fires off-tier")
    @MainActor func simplifiedFastSizingHonorsExplicitPickAndTier() {
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

        // Deliberate within-Fast pick of the smallest size: NOT the tier default
        // (12B on 64 GB), so per-query sizing stands down and the pick is honored.
        inference.setPreferredLocalTextModelID(Self.e2b)
        #expect(inference.sizedFastLocalTextModelID(forComplexity: 0.9, operatingMode: .fast) == nil)

        // Sizing only applies to the Fast tier — Think/Code/Tools are untouched.
        inference.setPreferredLocalTextModelID(Self.b12)
        #expect(inference.sizedFastLocalTextModelID(forComplexity: 0.9, operatingMode: .thinking) == nil)
        #expect(inference.sizedFastLocalTextModelID(forComplexity: 0.9, operatingMode: .pro) == nil)
        #expect(inference.sizedFastLocalTextModelID(forComplexity: 0.9, operatingMode: .agent) == nil)
    }

    // MARK: - P1.4 Honest local-runtime memory gate (pure policy)

    @Test("memory gate: fits only when free + headroom covers the requirement")
    func memoryGateFits() {
        // headroomGB == 6: availableGB + 6 must reach requiredGB.
        #expect(LocalChatModelMemoryGate.fits(requiredGB: 8, availableGB: 5))   // 5+6 ≥ 8
        #expect(LocalChatModelMemoryGate.fits(requiredGB: 8, availableGB: 2))   // 2+6 == 8 (boundary, runnable)
        #expect(!LocalChatModelMemoryGate.fits(requiredGB: 8, availableGB: 1))  // 1+6 < 8
        #expect(!LocalChatModelMemoryGate.fits(requiredGB: 16, availableGB: 2)) // 12B/coder on a starved Mac
        #expect(LocalChatModelMemoryGate.fits(requiredGB: 16, availableGB: 64)) // roomy Mac
    }

    @Test("memory gate: missing data never blocks (honesty, not paranoia)")
    func memoryGateMissingDataNeverBlocks() {
        #expect(LocalChatModelMemoryGate.fits(requiredGB: 0, availableGB: 1))  // no requirement
        #expect(LocalChatModelMemoryGate.fits(requiredGB: 8, availableGB: 0))  // unknown availability
    }

    @Test("memory gate: blocker reason names the model, the need, and the way out")
    func memoryGateBlockerReason() {
        let reason = LocalChatModelMemoryGate.blockerReason(
            modelDisplayName: "Gemma 4 12B QAT GGUF",
            requiredGB: 16,
            availableGB: 2
        )
        #expect(reason.contains("Gemma 4 12B QAT GGUF"))
        #expect(reason.contains("16 GB needed"))
        #expect(reason.contains("2 GB free"))
        #expect(reason.contains("route to cloud"))
    }

    // MARK: - P1.4 wired into InferenceState (deterministic via injected health)

    private static func health(availableMemoryBytes: UInt64) -> LocalRuntimeHealthSnapshot {
        LocalRuntimeHealthSnapshot(
            requestedRuntimeKind: .gguf,
            resolvedRuntimeKind: .gguf,
            executionMode: .local,
            modelID: "test",
            artifactID: nil,
            fallbackMode: "none",
            executionPhase: "idle",
            timeToFirstTokenMS: nil,
            totalDurationMS: 0,
            tokensPerSecond: nil,
            outputTokenCount: 0,
            outputCharacterCount: 0,
            availableMemoryBytes: availableMemoryBytes,
            runtimeResourceURL: nil
        )
    }

    private static let gb: UInt64 = 1_073_741_824

    @Test("simplified: Code tier blocks Send when the 12B coder can't fit free memory, clears when it can")
    @MainActor func codeTierMemoryBlocker() {
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
        inference.setPreferredChatModelSelection(.localMLX(Self.e2b))

        // Code (.pro) resolves to the 16 GB coder. With ~2 GB free it can't load:
        // honest visible blocker, never a silent swap.
        inference.setLatestLocalRuntimeHealth(Self.health(availableMemoryBytes: 2 * Self.gb))
        let blocked = inference.localChatModelMemoryBlocker(for: .pro)
        #expect(blocked != nil)
        #expect(blocked?.contains("free memory") == true)

        // Free memory recovers → the blocker clears (Send re-enables).
        inference.setLatestLocalRuntimeHealth(Self.health(availableMemoryBytes: 32 * Self.gb))
        #expect(inference.localChatModelMemoryBlocker(for: .pro) == nil)
    }

    @Test("simplified: Fast gates on the SMALLEST installed size, so a query the E2B can answer is never blocked")
    @MainActor func fastTierGatesOnSmallestSize() {
        guard EpistemosFoundationLineup.simplifiedLineupActive else { return }

        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 16_000_000_000,
                roundedMemoryGB: 16,
                maxRecommendedLocalContentLength: 8_000
            )
        )
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])
        inference.setInstalledLocalTextModelIDs([Self.e2b, Self.e4b, Self.b12])
        inference.setPreferredChatModelSelection(.localMLX(Self.b12))

        // ~3 GB free: the E4B default (12 GB) would NOT fit (12 > 3+6), but the
        // E2B (8 GB) would (8 ≤ 3+6). Fast gates on the smallest, so Send stays
        // enabled — P1.5 can size down to the E2B for this query.
        inference.setLatestLocalRuntimeHealth(Self.health(availableMemoryBytes: 3 * Self.gb))
        #expect(inference.localChatModelMemoryBlocker(for: .fast) == nil)

        // Truly starved (~1 GB free): even the E2B (8 GB) can't load (8 > 1+6),
        // so Fast honestly blocks.
        inference.setLatestLocalRuntimeHealth(Self.health(availableMemoryBytes: 1 * Self.gb))
        #expect(inference.localChatModelMemoryBlocker(for: .fast) != nil)
    }

    // MARK: - Owner hotfix 2026-06-17 — Think/Code never resolve as a Fast Gemma

    @Test("Think presents as VibeThinker (and Code as the coder) even when only Fast Gemmas are installed — never a Fast Gemma 12B")
    @MainActor func thinkAndCodeNeverResolveAsFastGemma() {
        guard EpistemosFoundationLineup.simplifiedLineupActive else { return }

        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            )
        )
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])
        // Only the Fast-tier Gemmas are installed — NOT VibeThinker, NOT the coder.
        inference.setInstalledLocalTextModelIDs([Self.e2b, Self.e4b, Self.b12])
        // Stored pick is the Fast 12B — the exact id that used to leak into Think.
        inference.setPreferredChatModelSelection(.localMLX(Self.b12))

        // Think pins to VibeThinker (its representative), NOT the Fast 12B.
        #expect(inference.effectiveChatSurfaceSelection(for: .thinking) == .localMLX(Self.vibe))
        #expect(inference.effectiveChatSurfaceSelection(for: .thinking) != .localMLX(Self.b12))
        // Code pins to the coder, NOT the Fast 12B.
        #expect(inference.effectiveChatSurfaceSelection(for: .pro) == .localMLX(Self.coder))
        #expect(inference.effectiveChatSurfaceSelection(for: .pro) != .localMLX(Self.b12))
        // Their dedicated models aren't installed, so those surfaces are honestly
        // "not ready" (Send disabled) rather than silently serving a Fast Gemma.
        #expect(!inference.isChatSurfaceRuntimeReady(for: .thinking))
        #expect(!inference.isChatSurfaceRuntimeReady(for: .pro))
        // Fast itself still resolves to a real installed Gemma and stays ready.
        #expect(inference.effectiveChatSurfaceSelection(for: .fast) == .localMLX(Self.b12))
        #expect(inference.isChatSurfaceRuntimeReady(for: .fast))

        // Install VibeThinker → Think now binds to it (the normal tier path).
        inference.setInstalledLocalTextModelIDs([Self.e2b, Self.e4b, Self.b12, Self.vibe])
        #expect(inference.effectiveChatSurfaceSelection(for: .thinking) == .localMLX(Self.vibe))
        #expect(inference.isChatSurfaceRuntimeReady(for: .thinking))
    }

    // MARK: - Owner hotfix 2026-06-17b — Apple Intelligence preserved as a native route

    @Test("Apple Intelligence stays a distinct native route — not cloud, not overridden by the foundation-tier pin")
    @MainActor func appleIntelligencePreservedAsNativeRoute() {
        guard EpistemosFoundationLineup.simplifiedLineupActive else { return }

        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            )
        )
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])
        // Only the Fast Gemmas are installed — VibeThinker/coder absent (the case
        // the hotfix pin handles). A stored 12B is the would-be leak source.
        inference.setInstalledLocalTextModelIDs([Self.e2b, Self.e4b, Self.b12])
        inference.appleIntelligenceAvailable = true
        inference.setPreferredChatModelSelection(.appleIntelligence)

        // With Apple Intelligence picked + available, every tier resolves to it —
        // never a Fast Gemma (the pin only fires for .localMLX) and never cloud.
        for mode in [EpistemosOperatingMode.fast, .thinking, .pro] {
            #expect(inference.effectiveChatSurfaceSelection(for: mode) == .appleIntelligence)
            #expect(inference.isChatSurfaceRuntimeReady(for: mode))
        }

        // It is NOT counted as cloud.
        if case .cloud = inference.effectiveChatSurfaceSelection(for: .fast) {
            Issue.record("Apple Intelligence must never resolve as a cloud selection")
        }
    }

    // MARK: - P1.9 Fast effort visibility (low / medium / high)

    @Test("Fast effort bands map complexity to low/medium/high with stable thresholds")
    func fastEffortBands() {
        #expect(EpistemosFastEffortSizing.effort(forComplexity: 0.0) == .low)
        #expect(EpistemosFastEffortSizing.effort(forComplexity: 0.10) == .low)
        #expect(EpistemosFastEffortSizing.effort(forComplexity: 0.45) == .medium)
        #expect(EpistemosFastEffortSizing.effort(forComplexity: 0.85) == .high)
        // Threshold edges line up with candidateIndex bands.
        #expect(EpistemosFastEffortSizing.effort(forComplexity: 0.30) == .medium)
        #expect(EpistemosFastEffortSizing.effort(forComplexity: 0.60) == .high)
        // Clamped at the ends.
        #expect(EpistemosFastEffortSizing.effort(forComplexity: -1.0) == .low)
        #expect(EpistemosFastEffortSizing.effort(forComplexity: 2.0) == .high)
        // Labels.
        #expect(EpistemosFastEffortSizing.FastEffort.low.displayName == "Low")
        #expect(EpistemosFastEffortSizing.FastEffort.medium.displayName == "Medium")
        #expect(EpistemosFastEffortSizing.FastEffort.high.displayName == "High")
    }

    @Test("Fast effort route reason names the effort and the sized model; nil off-tier or on an explicit pick")
    @MainActor func fastEffortRouteReasonWiring() {
        guard EpistemosFoundationLineup.simplifiedLineupActive else { return }

        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            )
        )
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])
        inference.setInstalledLocalTextModelIDs([Self.e2b, Self.e4b, Self.b12])
        // On the Fast default (12B on 64 GB) → sizing applies.
        inference.setPreferredLocalTextModelID(Self.b12)

        let low = inference.fastEffortRouteReason(forComplexity: 0.05, operatingMode: .fast)
        #expect(low?.contains("Low effort") == true)
        #expect(low?.contains("E2B") == true)

        let high = inference.fastEffortRouteReason(forComplexity: 0.9, operatingMode: .fast)
        #expect(high?.contains("High effort") == true)
        #expect(high?.contains("12B") == true)

        // Off-tier → nil.
        #expect(inference.fastEffortRouteReason(forComplexity: 0.9, operatingMode: .thinking) == nil)

        // Explicit within-Fast pick → sizing stands down → nil.
        inference.setPreferredLocalTextModelID(Self.e2b)
        #expect(inference.fastEffortRouteReason(forComplexity: 0.9, operatingMode: .fast) == nil)
    }

    // MARK: - P1.8 Honest install-progress display (never frozen)

    @Test("install progress: 0 / absent / NaN map to an indeterminate 'Starting…' spinner")
    func installProgressStartingIsIndeterminate() {
        #expect(ModelInstallProgressDisplay.from(fraction: nil) == .indeterminate(status: "Starting…"))
        #expect(ModelInstallProgressDisplay.from(fraction: 0) == .indeterminate(status: "Starting…"))
        #expect(ModelInstallProgressDisplay.from(fraction: -0.2) == .indeterminate(status: "Starting…"))
        #expect(ModelInstallProgressDisplay.from(fraction: Double.nan) == .indeterminate(status: "Starting…"))
    }

    @Test("install progress: in-flight fractions are determinate with a truncated percent")
    func installProgressInFlightIsDeterminate() {
        #expect(ModelInstallProgressDisplay.from(fraction: 0.5) == .determinate(fraction: 0.5, percent: 50))
        #expect(ModelInstallProgressDisplay.from(fraction: 0.05) == .determinate(fraction: 0.05, percent: 5))
        // Truncates so a determinate bar never prematurely reads 100%.
        #expect(ModelInstallProgressDisplay.from(fraction: 0.999) == .determinate(fraction: 0.999, percent: 99))
    }

    @Test("install progress: 100% / overshoot map to 'Finalizing…' (verify + activate still running)")
    func installProgressFinalizingIsIndeterminate() {
        #expect(ModelInstallProgressDisplay.from(fraction: 1.0) == .indeterminate(status: "Finalizing…"))
        #expect(ModelInstallProgressDisplay.from(fraction: 1.5) == .indeterminate(status: "Finalizing…"))
    }

    @Test("install progress: accessibility percent is the bar value, 0 while indeterminate")
    func installProgressAccessibilityPercent() {
        #expect(ModelInstallProgressDisplay.from(fraction: 0.42).accessibilityPercent == 42)
        #expect(ModelInstallProgressDisplay.from(fraction: 0).accessibilityPercent == 0)
        #expect(ModelInstallProgressDisplay.from(fraction: 1.0).accessibilityPercent == 0)
    }
}
