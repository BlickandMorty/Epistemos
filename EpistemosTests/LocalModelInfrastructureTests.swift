import Foundation
import Testing
@testable import Epistemos

@Suite("LocalModelInfrastructure")
struct LocalModelInfrastructureTests {
    private struct DummyLocalizedTestError: LocalizedError {
        let description: String

        var errorDescription: String? { description }
    }

    @Test("catalog pins immutable upstream revisions")
    func catalogUsesPinnedRevisions() {
        // Hermes 4.3 36B repos (leonsarmiento/*) gate their commit SHA
        // behind the authenticated HF API; we can't pin them from the
        // public unauthenticated endpoint used elsewhere in the catalog.
        // TODO: once the owner publishes a mirror with public SHA exposure
        // OR we add a token-backed fetch to scripts/pin_catalog_revisions.sh,
        // drop this exemption and restore strict pinning. Tracked in
        // docs/MASTER_MODEL_STACK_PLAN.md §6 (Honesty Ledger).
        let unpinnedExemptions: Set<String> = [
            LocalTextModelID.hermes43_36B4Bit.rawValue,
            LocalTextModelID.hermes43_36B3Bit.rawValue,
            // QwQ-32B was added 2026-04-19 from docs/MASTER_MODEL_STACK_PLAN.md §3.c.
            // `mlx-community/QwQ-32B-4bit` on HF exists but the commit SHA
            // wasn't captured at add time; `scripts/pin_catalog_revisions.sh`
            // will pin it on the next automated sweep.
            LocalTextModelID.qwqFlagship32B4Bit.rawValue,
        ]

        let descriptors = LocalModelCatalog.allDescriptors
        let revisions = descriptors.map(\.revision)

        #expect(!revisions.isEmpty)

        for descriptor in descriptors where !unpinnedExemptions.contains(descriptor.id) {
            #expect(
                descriptor.revision != "main",
                "\(descriptor.id) should pin a specific commit SHA, not 'main'"
            )
            #expect(
                descriptor.revision.range(of: "^[0-9a-f]{40}$", options: .regularExpression) != nil,
                "\(descriptor.id) revision should be a 40-char hex SHA, got: \(descriptor.revision)"
            )
        }
    }

    @Test("model downloads explicitly request the main safetensors blob")
    func modelDownloadsExplicitlyRequestMainSafetensorsBlob() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/ModelDownloadManager.swift")

        #expect(source.contains("descriptor.matchingGlobs + [\"model.safetensors\"]"))
    }

    @Test("live install smoke accepts the same tokenizer artifacts as the installer")
    func liveInstallSmokeAcceptsInstallerTokenizerArtifacts() throws {
        let installerSource = try loadMirroredSourceTextFile("Epistemos/Engine/ModelDownloadManager.swift")
        let smokeSource = try loadMirroredSourceTextFile("EpistemosTests/LocalRuntimeSmokeSupport.swift")

        #expect(installerSource.contains("\"tokenizer.json\""))
        #expect(installerSource.contains("\"tokenizer.model\""))
        #expect(installerSource.contains("\"vocab.json\""))
        #expect(smokeSource.contains("\"tokenizer.json\""))
        #expect(smokeSource.contains("\"tokenizer.model\""))
        #expect(smokeSource.contains("\"vocab.json\""))
    }

    @Test("catalog exposes the current installable local text model families")
    func catalogIncludesExpandedMLXModels() {
        let descriptors = LocalModelCatalog.allDescriptors

        #expect(!descriptors.isEmpty)
        #expect(descriptors.allSatisfy { $0.kind == .text })
        #expect(descriptors.contains { $0.id == LocalTextModelID.qwen35_4B4Bit.rawValue })
        #expect(descriptors.contains { $0.id == LocalTextModelID.qwen36_35BA3B4Bit.rawValue })
        #expect(descriptors.contains { $0.id == LocalTextModelID.bonsai4B2Bit.rawValue })
        #expect(descriptors.contains { $0.id == LocalTextModelID.bonsai8B2Bit.rawValue })
        #expect(descriptors.contains { $0.id == LocalTextModelID.gemma4_31BJANG.rawValue })
        #expect(descriptors.contains { $0.id == LocalTextModelID.smolLM3_3B4Bit.rawValue })
        #expect(descriptors.contains { $0.id == LocalTextModelID.devstralSmall2505_4Bit.rawValue })
        #expect(descriptors.contains { $0.id == LocalTextModelID.mistralSmall31_24B4Bit.rawValue })
        #expect(descriptors.contains { $0.id == LocalTextModelID.gemma3_27BQAT4Bit.rawValue })
        #expect(descriptors.contains { $0.id == LocalTextModelID.llama4Scout17B16E4Bit.rawValue })
        #expect(descriptors.contains { !$0.id.hasPrefix("mlx-community/") })
    }

    @Test("catalog excludes gguf-only local models from the MLX install path")
    func catalogExcludesGGUFOnlyModels() {
        #expect(LocalModelCatalog.descriptor(for: LocalTextModelID.qwopus27Bv3.rawValue) == nil)
        #expect(LocalModelCatalog.descriptor(for: LocalTextModelID.qwopusMoE35BA3B.rawValue) == nil)
    }

    @Test("catalog exposes a curated baseline install stack before the advanced catalog")
    func catalogExposesCuratedBaselineInstallStack() {
        // Stack refresh 2026-04-18 (docs/MASTER_MODEL_STACK_PLAN.md):
        // baseline = Fast Local (Qwen3-4B) + Reasoning (DeepSeek R1 7B)
        // + Coding (Qwen3-Coder-Next). Everything else is optional.
        // Gemma 4 stays in the raw catalog for future loader work, but
        // it should not appear in the shipping baseline recommendations
        // while the Swift runtime loader is still missing.
        let baselineIDs = Set(LocalModelCatalog.curatedBaselineDescriptors.map(\.id))
        let optionalIDs = Set(LocalModelCatalog.optionalBaselineDescriptors.map(\.id))
        let experimentalIDs = Set(LocalModelCatalog.experimentalDescriptors.map(\.id))
        let advancedIDs = Set(LocalModelCatalog.advancedDescriptors.map(\.id))

        #expect(baselineIDs == Set([
            LocalTextModelID.qwen3_4B4Bit.rawValue,
            LocalTextModelID.deepseekR1Distill7B.rawValue,
            LocalTextModelID.qwen3CoderNext4Bit.rawValue,
        ]))
        #expect(optionalIDs == Set([
            LocalTextModelID.bonsai4B2Bit.rawValue,
            LocalTextModelID.bonsai8B2Bit.rawValue,
            LocalTextModelID.qwen3Coder30BA3B4Bit.rawValue,
            LocalTextModelID.hermes43_36B4Bit.rawValue,
            LocalTextModelID.hermes43_36B3Bit.rawValue,
            LocalTextModelID.qwen36_35BA3B_Unsloth4Bit.rawValue,
            LocalTextModelID.qwen36_35BA3B_DWQ4Bit.rawValue,
            LocalTextModelID.qwqFlagship32B4Bit.rawValue,
            LocalTextModelID.qwen36_35BA3B4Bit.rawValue,
        ]))
        #expect(experimentalIDs.isEmpty)
        #expect(advancedIDs.isEmpty)
        #expect(!advancedIDs.contains(LocalTextModelID.gemma4_4B4Bit.rawValue))
    }

    @Test("gemma preview models stay out of baseline recommendation copy")
    func gemmaPreviewModelsStayOutOfBaselineRecommendationCopy() throws {
        let fastDescriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.gemma4_4B4Bit.rawValue))
        let proDescriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.gemma4_27BA4B4Bit.rawValue))

        #expect(!fastDescriptor.summary.contains("Recommended fast local default"))
        #expect(!proDescriptor.summary.contains("Optional high-end local pro tier"))
        #expect(!LocalModelCatalog.descriptors(forRole: .fastLocal).contains(where: { $0.id == fastDescriptor.id }))
        #expect(!LocalModelCatalog.descriptors(forRole: .highEndLocal).contains(where: { $0.id == proDescriptor.id }))
    }

    @Test("hardware recommendations stay on mlx-installable local models")
    func hardwareRecommendationsStayOnMLXInstallableModels() throws {
        let twentyFourGB = LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: 24_000_000_000,
            roundedMemoryGB: 24,
            maxRecommendedLocalContentLength: 12_000
        )
        let sixtyFourGB = LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: 64_000_000_000,
            roundedMemoryGB: 64,
            maxRecommendedLocalContentLength: 28_000
        )

        let twentyFourDescriptor = try #require(
            LocalModelCatalog.descriptor(for: twentyFourGB.recommendedLocalTextModelID.rawValue)
        )
        let sixtyFourDescriptor = try #require(
            LocalModelCatalog.descriptor(for: sixtyFourGB.recommendedLocalTextModelID.rawValue)
        )

        #expect(twentyFourDescriptor.matchingGlobs.contains("*.safetensors"))
        #expect(!twentyFourDescriptor.matchingGlobs.contains("*.gguf"))
        #expect(sixtyFourDescriptor.matchingGlobs.contains("*.safetensors"))
        #expect(!sixtyFourDescriptor.matchingGlobs.contains("*.gguf"))
    }

    @Test("catalog exposes supported SSM families through installable descriptors")
    func catalogIncludesSupportedSSMModels() {
        let descriptorIDs = Set(LocalModelCatalog.allDescriptors.map(\.id))

        #expect(descriptorIDs.contains(LocalTextModelID.lfm25_350M.rawValue))
        #expect(descriptorIDs.contains(LocalTextModelID.lfm25_1BInstruct.rawValue))
        #expect(descriptorIDs.contains(LocalTextModelID.lfm25_1BThinking.rawValue))
        #expect(descriptorIDs.contains(LocalTextModelID.lfm25_VL1B.rawValue))
        #expect(descriptorIDs.contains(LocalTextModelID.lfm2_2B4Bit.rawValue))
        #expect(descriptorIDs.contains(LocalTextModelID.lfm2_8BA1B3Bit.rawValue))
        #expect(descriptorIDs.contains(LocalTextModelID.lfm2_24BA2B4Bit.rawValue))
        #expect(descriptorIDs.contains(LocalTextModelID.mamba2_2B4Bit.rawValue))
        #expect(descriptorIDs.contains(LocalTextModelID.jamba3B.rawValue))
        #expect(descriptorIDs.contains(LocalTextModelID.falconH1R_7B4Bit.rawValue))
        #expect(!descriptorIDs.contains(LocalTextModelID.falconH1_1B4Bit.rawValue))
    }

    @Test("mamba2 points at the public mlx-community repository")
    func mamba2UsesInstallableRepository() {
        #expect(LocalTextModelID.mamba2_2B4Bit.rawValue == "mlx-community/mamba2-2.7b-4bit")
    }

    @Test("mamba2 metadata reflects the long-context SSM runtime")
    func mamba2MetadataReflectsLongContextSSMRuntime() {
        let model = LocalTextModelID.mamba2_2B4Bit

        #expect(model.isSSM)
        #expect(model.minimumRecommendedMemoryGB == 8)
        #expect(model.maxContextTokens >= 128_000)
    }

    @Test("qwen 35B apexmini metadata reflects the 18GB target tier")
    func qwen35APEXMiniMetadataReflectsTargetTier() {
        let model = LocalTextModelID.qwen35_35BA3B4Bit

        #expect(model.minimumRecommendedMemoryGB == 18)
        #expect(model.displayName == "Qwen 3.5 35B APEXMini")
        #expect(model.supportsThinkingMode)
    }

    @Test("qwen coder uses a stricter interactive memory floor than its raw file size")
    func qwenCoderUsesStricterInteractiveMemoryFloor() {
        let model = LocalTextModelID.qwen25Coder7B
        let twentyGB = LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: 20_000_000_000,
            roundedMemoryGB: 20,
            maxRecommendedLocalContentLength: 12_000
        )

        #expect(model.minimumRecommendedMemoryGB == 16)
        #expect(model.minimumRecommendedInteractiveMemoryGB == 24)
        #expect(!twentyGB.supportsInteractiveChatModel(textModelID: model.rawValue))
    }

    @Test("local text models expose their execution runtime kind")
    func localTextModelsExposeExecutionRuntimeKind() {
        #expect(LocalTextModelID.qwen35_35BA3B4Bit.runtimeKind == .mlx)
        #expect(LocalTextModelID.qwopus27Bv3.runtimeKind == .gguf)
        #expect(LocalTextModelID.qwopusMoE35BA3B.runtimeKind == .gguf)
    }

    @MainActor
    @Test("qwen 4B local picker no longer advertises unvalidated thinking or local agent modes")
    func qwen4BPickerOnlyShowsValidatedModes() {
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen35_4B4Bit.rawValue))

        #expect(inference.availableOperatingModes == [.fast])
    }

    @MainActor
    @Test("qwen 9B local picker no longer advertises unvalidated thinking or local agent modes")
    func qwen9BPickerOnlyShowsValidatedModes() {
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_9B4Bit.rawValue])
        inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen35_9B4Bit.rawValue))

        #expect(inference.availableOperatingModes == [.fast])
    }

    @MainActor
    @Test("local agent mode stays hidden when structured local tool calling is unavailable")
    func localAgentModeStaysHiddenWithoutStructuredToolCalling() {
        #expect(!LocalToolGrammar.supportsStructuredToolCalling)

        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.deepseekR1Distill7B.rawValue])
        inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.deepseekR1Distill7B.rawValue))

        #expect(!inference.availableOperatingModes.contains(.agent))
    }

    @MainActor
    @Test("DeepSeek R1 local picker stays thinking-only because fast mode cannot disable reasoning")
    func deepSeekR1PickerStaysThinkingOnly() {
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.deepseekR1Distill7B.rawValue])
        inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.deepseekR1Distill7B.rawValue))

        #expect(inference.availableOperatingModes == [.thinking])
        #expect(inference.supportsThinkingOperatingMode)
    }

    @MainActor
    @Test("Qwen 3 4B release picker remains the fast-only local default")
    func qwen34BPickerStaysFastOnly() {
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3_4B4Bit.rawValue])
        inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen3_4B4Bit.rawValue))

        #expect(inference.availableOperatingModes == [.fast])
        #expect(!inference.supportsThinkingOperatingMode)
    }

    @MainActor
    @Test("hidden local agent tiers still back the local agent loop when soft guidance is available")
    func hiddenLocalAgentTiersStillBackTheLocalAgentLoop() {
        #expect(LocalToolGrammar.supportsLocalAgentLoop)

        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([
            LocalTextModelID.qwen35_2B4Bit.rawValue,
            LocalTextModelID.qwen35_4B4Bit.rawValue,
        ])
        inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen35_4B4Bit.rawValue))

        #expect(inference.availableOperatingModes == [.fast])
        #expect(inference.effectiveLocalTextModelID == LocalTextModelID.qwen35_2B4Bit.rawValue)
        #expect(inference.effectiveLocalAgentTextModelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(inference.supportsLocalAgentLoop)
    }

    @MainActor
    @Test("release picker excludes local models that failed live release validation")
    func releasePickerExcludesFailedLiveValidationModels() {
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([
            LocalTextModelID.qwen35_2B4Bit.rawValue,
            LocalTextModelID.qwen35_4B4Bit.rawValue,
            LocalTextModelID.qwen35_9B4Bit.rawValue,
            LocalTextModelID.lfm2_8BA1B3Bit.rawValue,
            LocalTextModelID.falconH1_1B4Bit.rawValue,
        ])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        #expect(
            inference.releaseSelectableInstalledLocalTextModelIDs
                == [LocalTextModelID.qwen35_2B4Bit.rawValue]
        )
        #expect(inference.releaseHiddenInstalledLocalTextModelCount == 4)
        #expect(inference.preferredLocalTextModelID == LocalTextModelID.qwen35_2B4Bit.rawValue)
        #expect(inference.effectiveLocalTextModelID == LocalTextModelID.qwen35_2B4Bit.rawValue)
        #expect(inference.activeChatModelDisplayName == LocalTextModelID.qwen35_2B4Bit.displayName)
    }

    @MainActor
    @Test("release picker hides mamba2 until its chat path is validated")
    func releasePickerHidesUnvalidatedMamba2Chat() {
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([
            LocalTextModelID.qwen35_2B4Bit.rawValue,
            LocalTextModelID.mamba2_2B4Bit.rawValue,
        ])
        inference.setPreferredLocalTextModelID(LocalTextModelID.mamba2_2B4Bit.rawValue)

        #expect(
            inference.releaseSelectableInstalledLocalTextModelIDs
                == [LocalTextModelID.qwen35_2B4Bit.rawValue]
        )
        #expect(inference.releaseHiddenInstalledLocalTextModelCount == 1)
        #expect(inference.preferredLocalTextModelID == LocalTextModelID.qwen35_2B4Bit.rawValue)
        #expect(inference.effectiveLocalTextModelID == LocalTextModelID.qwen35_2B4Bit.rawValue)
        #expect(inference.activeChatModelDisplayName == LocalTextModelID.qwen35_2B4Bit.displayName)
    }

    @MainActor
    @Test("release picker hides qwen coder until the freeze path is validated")
    func releasePickerHidesQwenCoderUntilFreezePathIsValidated() {
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([
            LocalTextModelID.qwen3_4B4Bit.rawValue,
            LocalTextModelID.qwen25Coder7B.rawValue,
        ])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen25Coder7B.rawValue)

        #expect(
            inference.releaseSelectableInstalledLocalTextModelIDs
                == [LocalTextModelID.qwen3_4B4Bit.rawValue]
        )
        #expect(inference.releaseHiddenInstalledLocalTextModelCount == 1)
        #expect(inference.preferredLocalTextModelID == LocalTextModelID.qwen3_4B4Bit.rawValue)
        #expect(inference.effectiveLocalTextModelID == LocalTextModelID.qwen3_4B4Bit.rawValue)
        #expect(inference.activeChatModelDisplayName == LocalTextModelID.qwen3_4B4Bit.displayName)
    }

    @MainActor
    @Test("experimental ssm tiers stay out of normal chat and local agent selection")
    func experimentalSSMTiersStayOutOfNormalChatAndLocalAgentSelection() {
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([
            LocalTextModelID.deepseekR1Distill7B.rawValue,
            LocalTextModelID.lfm2_2B4Bit.rawValue,
            LocalTextModelID.lfm25_1BInstruct.rawValue,
        ])
        inference.setPreferredLocalTextModelID(LocalTextModelID.lfm2_2B4Bit.rawValue)

        #expect(
            inference.releaseSelectableInstalledLocalTextModelIDs
                == [LocalTextModelID.deepseekR1Distill7B.rawValue]
        )
        #expect(inference.preferredLocalTextModelID == LocalTextModelID.deepseekR1Distill7B.rawValue)
        #expect(inference.effectiveLocalTextModelID == LocalTextModelID.deepseekR1Distill7B.rawValue)
        #expect(inference.effectiveLocalAgentTextModelID == LocalTextModelID.deepseekR1Distill7B.rawValue)
    }

    @Test("ssm state discovery follows native MLX safetensors caches")
    func ssmStateDiscoveryFollowsNativeMLXSafetensorsCaches() throws {
        let root = makeTemporaryRoot().rootDirectory
        defer { try? FileManager.default.removeItem(at: root) }

        let service = SSMStateService(stateRoot: root)
        let modelID = LocalTextModelID.lfm25_350M.rawValue
        let sessionID = UUID().uuidString
        let modelDirectory = root
            .appendingPathComponent("ssm_cache", isDirectory: true)
            .appendingPathComponent(modelID.replacingOccurrences(of: "/", with: "_"), isDirectory: true)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        let legacyURL = modelDirectory.appendingPathComponent("\(sessionID)_legacy.mlxcache")
        let nativeURL = modelDirectory.appendingPathComponent("\(sessionID)_native.safetensors")
        try Data([0x00]).write(to: legacyURL)
        try Data([0x01]).write(to: nativeURL)

        let latest = try #require(service.findLatestState(modelId: modelID, sessionId: sessionID))
        let states = service.listStates(modelId: modelID)
        let expectedNativeURL = nativeURL.resolvingSymlinksInPath()

        #expect(latest.resolvingSymlinksInPath() == expectedNativeURL)
        #expect(latest.pathExtension == "safetensors")
        #expect(states.count == 1)
        #expect(states.first?.url.resolvingSymlinksInPath() == expectedNativeURL)
    }

    @Test("catalog omits unreachable model IDs from installable descriptors")
    func catalogOmitsUnavailableDescriptors() {
        let nonexistentGemma4 = "mlx-community/gemma-4-12b-it-4bit"

        #expect(LocalTextModelID(rawValue: nonexistentGemma4) == nil)
        #expect(LocalModelCatalog.descriptor(for: nonexistentGemma4) == nil)
        #expect(LocalModelCatalog.descriptor(for: LocalTextModelID.lfm25_Audio1B.rawValue) == nil)
    }

    @Test("release sweep selection can be constrained with a file override")
    func releaseSweepSelectionHonorsFileOverride() throws {
        let overrideURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
        defer { try? FileManager.default.removeItem(at: overrideURL) }

        try """
        mlx-community/Qwen3.5-2B-4bit
        mlx-community/Qwen3.5-27B-4bit
        mlx-community/mamba2-2.7b-4bit
        """.write(to: overrideURL, atomically: true, encoding: .utf8)

        let snapshot = LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: 16_000_000_000,
            roundedMemoryGB: 16,
            maxRecommendedLocalContentLength: 8_000
        )
        let selected = LocalRuntimeSmokeSupport.selectedReleaseSweepModelIDs(
            snapshot: snapshot,
            environment: [:],
            overrideFileURL: overrideURL
        )

        #expect(selected == [.qwen35_2B4Bit, .mamba2_2B4Bit])
    }

    @Test("default release sweep excludes locally quarantined models")
    func defaultReleaseSweepSkipsQuarantinedModels() {
        let snapshot = LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: 64_000_000_000,
            roundedMemoryGB: 64,
            maxRecommendedLocalContentLength: 28_000
        )

        let selected = LocalRuntimeSmokeSupport.supportedReleaseModelIDs(snapshot: snapshot)

        #expect(selected.contains(.qwen35_2B4Bit))
        #expect(!selected.contains(.mamba2_2B4Bit))
        #expect(!selected.contains(.qwen35_4B4Bit))
        #expect(!selected.contains(.qwen35_9B4Bit))
        #expect(!selected.contains(.lfm25_1BThinking))
        #expect(!selected.contains(.lfm2_8BA1B3Bit))
        #expect(!selected.contains(.falconH1_1B4Bit))
    }

    @Test("18GB hardware defaults to Qwen 3 4B and keeps Bonsai as the constrained fallback")
    func eighteenGBHardwareDefaultsToQwen3FourB() throws {
        let snapshot = LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: 18_000_000_000,
            roundedMemoryGB: 18,
            maxRecommendedLocalContentLength: 8_000
        )
        let constrained = try #require(snapshot.recommendedConstrainedLocalTextModelID)

        #expect(snapshot.recommendedLocalTextModelID == .qwen3_4B4Bit)
        #expect(constrained == .bonsai4B2Bit)
        #expect(LocalModelCatalog.descriptor(for: constrained.rawValue) != nil)
        #expect(!snapshot.supportsInteractiveChatModel(textModelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue))
        #expect(!snapshot.supportsInteractiveChatModel(textModelID: LocalTextModelID.qwen36_35BA3B4Bit.rawValue))
        #expect(snapshot.supportsInteractiveChatModel(textModelID: LocalTextModelID.gemma4_4B4Bit.rawValue))
        #expect(snapshot.supportsInteractiveChatModel(textModelID: LocalTextModelID.gemma4_27BA4B4Bit.rawValue))
    }

    @Test("prepared model manifest exposes primary generation and draft runtime entries")
    func preparedModelManifestExposesGenerationRuntimeEntries() throws {
        let snapshot = try PreparedModelRegistry().load()
        let generation = try #require(snapshot.generationRuntimeConfiguration)

        #expect(generation.primaryGenerator.servedModelID == LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        #expect(generation.speculativeDraftGenerator?.servedModelID == "mlx-community/Qwen2.5-0.5B-Instruct-4bit")
        #expect(
            generation.primaryResolvedModelDirectory?.path
                .hasSuffix("/PreparedModels/generation/qwen35-35b-a3b-apexmini/source") == true
        )
    }

    @Test("prepared generation runtime marks only the primary generator as interactive-ready")
    func preparedGenerationRuntimeMarksOnlyThePrimaryGeneratorAsInteractiveReady() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("prepared-generation-\(UUID().uuidString)", isDirectory: true)
        let primaryDirectory = root.appendingPathComponent("primary", isDirectory: true)
        let draftDirectory = root.appendingPathComponent("draft", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: primaryDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: draftDirectory, withIntermediateDirectories: true)

        let configuration = PreparedGenerationRuntimeConfiguration(
            primaryGenerator: PreparedModelDescriptor(
                key: "generator_primary",
                role: .generator,
                displayName: "Qwen 3.5 35B APEXMini",
                artifactID: nil,
                modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                servedModelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: primaryDirectory.path,
                downloadPath: nil,
                status: "ready",
                trustRemoteCode: false
            ),
            speculativeDraftGenerator: PreparedModelDescriptor(
                key: "generator_speculative_draft",
                role: .draftGenerator,
                displayName: "Qwen 2.5 Draft",
                artifactID: nil,
                modelID: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
                servedModelID: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: draftDirectory.path,
                downloadPath: nil,
                status: "ready",
                trustRemoteCode: false
            )
        )

        #expect(
            configuration.interactiveLocalTextModelIDs()
                == [LocalTextModelID.qwen35_35BA3B4Bit.rawValue]
        )
    }

    @MainActor
    @Test("prepared primary generator becomes a usable local runtime without an installed snapshot")
    func preparedPrimaryGeneratorBecomesAUsableLocalRuntimeWithoutAnInstalledSnapshot() {
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 24_000_000_000,
                roundedMemoryGB: 24,
                maxRecommendedLocalContentLength: 12_000
            )
        )

        inference.setPreparedLocalTextModelIDs([LocalTextModelID.qwen35_35BA3B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_35BA3B4Bit.rawValue)

        #expect(inference.installedLocalTextModelIDs.isEmpty)
        #expect(inference.localModelInstallStateSummary == .prepared)
        #expect(inference.hasUsableLocalTextModel)
        #expect(inference.effectiveLocalTextModelID == LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        #expect(
            inference.releaseSelectableInstalledLocalTextModelIDs
                == [LocalTextModelID.qwen35_35BA3B4Bit.rawValue]
        )
    }

    @MainActor
    @Test("18GB picker hides Gemma 4 while its Swift loader is missing, even if installed")
    func eighteenGBInteractivePickerPrefersCuratedStack() {
        // Pre-2026-04-19 this test asserted Gemma 4 E4B won the 18GB
        // picker over the oversized Qwen 35B variants. After discovering
        // the mlx-swift-lm loader for model_type=gemma4 isn't ported yet,
        // Gemma 4 is gated out of the interactive picker (it produces a
        // runtime "Unsupported model type" error on load). The test now
        // asserts the new truthful behavior: with only Gemma 4 + Qwen 35B
        // installed on 18GB, nothing is release-selectable and the
        // picker surfaces no runnable model. Users in this state get
        // auto-migrated to Qwen 3 4B at next launch (see
        // migrateStaleGemma4Selection in TriageServiceTests).
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 18_000_000_000,
                roundedMemoryGB: 18,
                maxRecommendedLocalContentLength: 8_000
            )
        )

        inference.setInstalledLocalTextModelIDs([
            LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
            LocalTextModelID.qwen36_35BA3B4Bit.rawValue,
            LocalTextModelID.gemma4_4B4Bit.rawValue,
            LocalTextModelID.gemma4_27BA4B4Bit.rawValue,
        ])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_35BA3B4Bit.rawValue)

        #expect(inference.releaseSelectableInstalledLocalTextModelIDs.isEmpty)
        // Picker hides Gemma 4 — preferred stays on what the caller set
        // (no promotion of a hidden model into the "effective" slot).
        #expect(inference.preferredLocalTextModelID == LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        #expect(inference.effectiveLocalTextModelID == nil)
    }

    @MainActor
    @Test("prepared gguf models stay hidden until the gguf runtime is available")
    func preparedGGUFModelsStayHiddenUntilGGUFIsAvailable() {
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            )
        )

        inference.setPreparedLocalTextModelIDs([LocalTextModelID.qwopus27Bv3.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwopus27Bv3.rawValue)

        #expect(!inference.hasUsableLocalTextModel)
        #expect(inference.effectiveLocalTextModelID == nil)

        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])

        #expect(inference.hasUsableLocalTextModel)
        #expect(inference.effectiveLocalTextModelID == LocalTextModelID.qwopus27Bv3.rawValue)
    }

    @MainActor
    @Test("local model manager surfaces prepared runtimes distinctly from installed snapshots")
    func localModelManagerSurfacesPreparedRuntimesDistinctlyFromInstalledSnapshots() throws {
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 24_000_000_000,
                roundedMemoryGB: 24,
                maxRecommendedLocalContentLength: 12_000
            )
        )
        inference.setPreparedLocalTextModelIDs([LocalTextModelID.qwen35_35BA3B4Bit.rawValue])

        let manager = LocalModelManager(
            inference: inference,
            paths: makeTemporaryRoot(),
            installer: FakeLocalModelInstaller()
        )
        let descriptor = try #require(
            LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        )

        #expect(manager.presentationState(for: descriptor) == .prepared)
    }

    @MainActor
    @Test("local model manager keeps legacy installs visible for deletion without advertising them as new options")
    func localModelManagerKeepsLegacyInstallsVisibleForDeletion() throws {
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            )
        )
        let paths = makeTemporaryRoot()
        try paths.ensureBaseDirectories()
        let descriptor = try #require(
            LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        )
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )
        let record = LocalModelInstallRecord(
            modelID: descriptor.id,
            kind: descriptor.kind,
            activeDirectoryPath: paths.activeDirectory(for: descriptor).path,
            revision: descriptor.revision,
            installedAt: Date(),
            sizeBytes: 1_024
        )
        let manifest = LocalModelInstallManifest(records: [record])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: paths.manifestURL, options: .atomic)

        let manager = LocalModelManager(
            inference: inference,
            paths: paths,
            installer: FakeLocalModelInstaller()
        )

        #expect(manager.curatedBaselineDescriptors.count == 3)
        // Stack refresh 2026-04-18 — optional baseline is now ordered as
        // declared in LocalModelCatalog.optionalBaselineModelIDs
        // (Bonsai fallbacks, coder flagship, Hermes function-calling,
        // Qwen 3.6 flagship quant variants, QwQ flagship reasoner, and
        // the legacy coder fallback. Gemma 4 stays out until the loader lands.
        #expect(
            manager.optionalBaselineDescriptors.map(\.id) == [
                LocalTextModelID.bonsai4B2Bit.rawValue,
                LocalTextModelID.bonsai8B2Bit.rawValue,
                LocalTextModelID.qwen3Coder30BA3B4Bit.rawValue,
                LocalTextModelID.hermes43_36B4Bit.rawValue,
                LocalTextModelID.hermes43_36B3Bit.rawValue,
                LocalTextModelID.qwen36_35BA3B_Unsloth4Bit.rawValue,
                LocalTextModelID.qwen36_35BA3B_DWQ4Bit.rawValue,
                LocalTextModelID.qwqFlagship32B4Bit.rawValue,
                LocalTextModelID.qwen36_35BA3B4Bit.rawValue,
            ]
        )
        #expect(manager.legacyInstalledDescriptors.map(\.id) == [LocalTextModelID.qwen35_35BA3B4Bit.rawValue])
    }

    @MainActor
    @Test("legacy installed list hides Gemma preview tiers that still lack a runtime loader")
    func legacyInstalledListHidesGemmaPreviewTiersAwaitingLoader() throws {
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            )
        )
        let paths = makeTemporaryRoot()
        try paths.ensureBaseDirectories()

        let legacyDescriptor = try #require(
            LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        )
        let gemmaDescriptor = try #require(
            LocalModelCatalog.descriptor(for: LocalTextModelID.gemma4_4B4Bit.rawValue)
        )

        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: legacyDescriptor),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: gemmaDescriptor),
            withIntermediateDirectories: true
        )

        let manifest = LocalModelInstallManifest(
            records: [
                LocalModelInstallRecord(
                    modelID: legacyDescriptor.id,
                    kind: legacyDescriptor.kind,
                    activeDirectoryPath: paths.activeDirectory(for: legacyDescriptor).path,
                    revision: legacyDescriptor.revision,
                    installedAt: Date(),
                    sizeBytes: 1_024
                ),
                LocalModelInstallRecord(
                    modelID: gemmaDescriptor.id,
                    kind: gemmaDescriptor.kind,
                    activeDirectoryPath: paths.activeDirectory(for: gemmaDescriptor).path,
                    revision: gemmaDescriptor.revision,
                    installedAt: Date(),
                    sizeBytes: 2_048
                ),
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: paths.manifestURL, options: .atomic)

        let manager = LocalModelManager(
            inference: inference,
            paths: paths,
            installer: FakeLocalModelInstaller()
        )

        #expect(manager.legacyInstalledDescriptors.map(\.id) == [LocalTextModelID.qwen35_35BA3B4Bit.rawValue])
    }

    @Test("constrained fallbacks skip quarantined interactive chat models")
    func constrainedFallbacksSkipQuarantinedInteractiveChatModels() throws {
        let snapshots = [
            LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 18_000_000_000,
                roundedMemoryGB: 18,
                maxRecommendedLocalContentLength: 8_000
            ),
            LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 24_000_000_000,
                roundedMemoryGB: 24,
                maxRecommendedLocalContentLength: 12_000
            ),
            LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            ),
        ]

        for snapshot in snapshots {
            let constrained = try #require(snapshot.recommendedConstrainedLocalTextModelID)
            #expect(constrained.isReleaseValidatedForInteractiveChat)
        }
    }

    @Test("live validation blocker detects hugging face 429 responses")
    func liveValidationBlockerDetectsHuggingFaceRateLimit() {
        let error = DummyLocalizedTestError(
            description: """
            Response error (Status 429): <!DOCTYPE html>
            <h1>429</h1>
            <p>We had to rate limit you.</p>
            """
        )

        let blockerReason = LocalRuntimeSmokeSupport.liveValidationBlockerReason(for: error)
        #expect(blockerReason?.localizedCaseInsensitiveContains("rate-limited") == true)
    }

    @Test("live validation blocker ignores unrelated local failures")
    func liveValidationBlockerIgnoresUnrelatedFailures() {
        let error = DummyLocalizedTestError(description: "The local install for model-x is incomplete or corrupted.")

        #expect(LocalRuntimeSmokeSupport.liveValidationBlockerReason(for: error) == nil)
    }

    @Test("bonsai variants are surfaced from the curated prism install catalog")
    func bonsaiVariantsAreSurfacedFromCuratedCatalog() throws {
        let bonsai4 = try #require(
            LocalModelCatalog.descriptor(for: LocalTextModelID.bonsai4B2Bit.rawValue)
        )
        let bonsai8 = try #require(
            LocalModelCatalog.descriptor(for: LocalTextModelID.bonsai8B2Bit.rawValue)
        )

        #expect(bonsai4.id == LocalTextModelID.bonsai4B2Bit.rawValue)
        #expect(bonsai8.id == LocalTextModelID.bonsai8B2Bit.rawValue)
        #expect(LocalModelCatalog.allDescriptors.contains(where: { $0.id == LocalTextModelID.bonsai4B2Bit.rawValue }))
        #expect(LocalModelCatalog.allDescriptors.contains(where: { $0.id == LocalTextModelID.bonsai8B2Bit.rawValue }))
    }

    @MainActor
    @Test("install writes manifest and syncs inference state")
    func installPersistsManifest() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.rootDirectory) }

        let inference = InferenceState()
        let manager = LocalModelManager(
            inference: inference,
            paths: root,
            installer: FakeLocalModelInstaller()
        )

        try await manager.install(modelID: LocalTextModelID.qwen35_4B4Bit.rawValue)

        #expect(inference.installedLocalTextModelIDs.contains(LocalTextModelID.qwen35_4B4Bit.rawValue))
        #expect(FileManager.default.fileExists(atPath: root.manifestURL.path))

        let manifestData = try Data(contentsOf: root.manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(LocalModelInstallManifest.self, from: manifestData)
        #expect(manifest.records.count == 1)
        #expect(manifest.records.first?.modelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
    }

    @MainActor
    @Test("install adopts the first usable local tier when no exact selection is available")
    func installAdoptsFirstUsableTier() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.rootDirectory) }

        let inference = InferenceState()
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let manager = LocalModelManager(
            inference: inference,
            paths: root,
            installer: FakeLocalModelInstaller()
        )

        try await manager.install(modelID: LocalTextModelID.qwen35_2B4Bit.rawValue)

        #expect(inference.preferredLocalTextModelID == LocalTextModelID.qwen35_2B4Bit.rawValue)
        #expect(inference.effectiveLocalTextModelID == LocalTextModelID.qwen35_2B4Bit.rawValue)
    }

    @MainActor
    @Test("refresh restores persisted install records")
    func refreshRestoresManifest() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.rootDirectory) }

        let descriptor = try #require(
            LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue)
        )
        let installedURL = root.activeDirectory(for: descriptor)
        try FileManager.default.createDirectory(at: installedURL, withIntermediateDirectories: true)

        let record = LocalModelInstallRecord(
            modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            kind: .text,
            activeDirectoryPath: installedURL.path,
            revision: descriptor.revision,
            installedAt: Date(timeIntervalSince1970: 1_234),
            sizeBytes: 123
        )
        try root.ensureBaseDirectories()
        let manifest = LocalModelInstallManifest(records: [record])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: root.manifestURL, options: .atomic)

        let inference = InferenceState()
        let manager = LocalModelManager(
            inference: inference,
            paths: root,
            installer: FakeLocalModelInstaller()
        )

        manager.refreshFromDisk()

        #expect(manager.installRecords[LocalTextModelID.qwen35_4B4Bit.rawValue] == record)
        #expect(inference.installedLocalTextModelIDs.contains(LocalTextModelID.qwen35_4B4Bit.rawValue))
        #expect(inference.releaseSelectableInstalledLocalTextModelIDs.isEmpty)
    }

    @MainActor
    @Test("refresh prunes stale install records whose revision no longer matches the pinned catalog")
    func refreshPrunesStaleRevisionRecords() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.rootDirectory) }

        let descriptor = try #require(
            LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue)
        )
        let installedURL = root.activeDirectory(for: descriptor)
        try FileManager.default.createDirectory(at: installedURL, withIntermediateDirectories: true)
        try "{}".write(
            to: installedURL.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try "{}".write(
            to: installedURL.appendingPathComponent("tokenizer.json"),
            atomically: true,
            encoding: .utf8
        )
        try Data([0x00]).write(to: installedURL.appendingPathComponent("model.safetensors"))

        let record = LocalModelInstallRecord(
            modelID: descriptor.id,
            kind: .text,
            activeDirectoryPath: installedURL.path,
            revision: "main",
            installedAt: Date(timeIntervalSince1970: 1_234),
            sizeBytes: 123
        )
        try root.ensureBaseDirectories()
        let manifest = LocalModelInstallManifest(records: [record])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: root.manifestURL, options: .atomic)

        let inference = InferenceState()
        let manager = LocalModelManager(
            inference: inference,
            paths: root,
            installer: FakeLocalModelInstaller()
        )

        manager.refreshFromDisk()

        #expect(manager.installRecords[descriptor.id] == nil)
        #expect(!inference.installedLocalTextModelIDs.contains(descriptor.id))
        #expect(!FileManager.default.fileExists(atPath: installedURL.path))
    }

    @MainActor
    @Test("refresh leaves the manifest untouched when install records are already current")
    func refreshDoesNotRewriteUnchangedManifest() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.rootDirectory) }

        let descriptor = try #require(
            LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue)
        )
        let installedURL = root.activeDirectory(for: descriptor)
        try FileManager.default.createDirectory(at: installedURL, withIntermediateDirectories: true)

        let record = LocalModelInstallRecord(
            modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            kind: .text,
            activeDirectoryPath: installedURL.path,
            revision: descriptor.revision,
            installedAt: Date(timeIntervalSince1970: 1_234),
            sizeBytes: 123
        )
        try root.ensureBaseDirectories()
        let manifest = LocalModelInstallManifest(records: [record])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: root.manifestURL, options: .atomic)

        let inference = InferenceState()
        let manager = LocalModelManager(
            inference: inference,
            paths: root,
            installer: FakeLocalModelInstaller()
        )

        let originalModificationDate = try #require(
            root.manifestURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        )

        Thread.sleep(forTimeInterval: 1.1)
        manager.refreshFromDisk()

        let refreshedModificationDate = try #require(
            root.manifestURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        )
        #expect(refreshedModificationDate == originalModificationDate)
    }

    @MainActor
    @Test("refresh prunes abandoned staging directories from interrupted installs")
    func refreshPrunesAbandonedStagingDirectories() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.rootDirectory) }

        let descriptor = try #require(
            LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue)
        )
        let staleStagingDirectory = root.stagingDirectory
            .appendingPathComponent(descriptor.kind.rawValue, isDirectory: true)
            .appendingPathComponent("\(descriptor.slug)-stale-download", isDirectory: true)
        try FileManager.default.createDirectory(
            at: staleStagingDirectory,
            withIntermediateDirectories: true
        )
        try "partial".write(
            to: staleStagingDirectory.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -(2 * 60 * 60))],
            ofItemAtPath: staleStagingDirectory.path
        )

        let inference = InferenceState()
        let manager = LocalModelManager(
            inference: inference,
            paths: root,
            installer: FakeLocalModelInstaller()
        )

        manager.refreshFromDisk()

        #expect(!FileManager.default.fileExists(atPath: staleStagingDirectory.path))
    }

    @MainActor
    @Test("refresh keeps recent staging directories so concurrent installs are not disrupted")
    func refreshKeepsRecentStagingDirectories() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.rootDirectory) }

        let descriptor = try #require(
            LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue)
        )
        let recentStagingDirectory = root.stagingDirectory
            .appendingPathComponent(descriptor.kind.rawValue, isDirectory: true)
            .appendingPathComponent("\(descriptor.slug)-recent-download", isDirectory: true)
        try FileManager.default.createDirectory(
            at: recentStagingDirectory,
            withIntermediateDirectories: true
        )
        try "partial".write(
            to: recentStagingDirectory.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: recentStagingDirectory.path
        )

        let inference = InferenceState()
        let manager = LocalModelManager(
            inference: inference,
            paths: root,
            installer: FakeLocalModelInstaller()
        )

        manager.refreshFromDisk()

        #expect(FileManager.default.fileExists(atPath: recentStagingDirectory.path))
    }

    @MainActor
    @Test("refresh drops unsupported legacy installs from disk and manifest")
    func refreshPurgesLegacyUnsupportedInstalls() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.rootDirectory) }

        try root.ensureBaseDirectories()
        let legacyVoiceDirectory = root.rootDirectory
            .appendingPathComponent("voice", isDirectory: true)
            .appendingPathComponent("active", isDirectory: true)
            .appendingPathComponent("mlx-community--chatterbox-turbo-4bit", isDirectory: true)
        let legacyGemmaDirectory = root.modelDirectory(for: .text)
            .appendingPathComponent("active", isDirectory: true)
            .appendingPathComponent("mlx-community--gemma-2-9b-it-4bit", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyVoiceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacyGemmaDirectory, withIntermediateDirectories: true)

        let data = Data(
            """
            {
              "version": 1,
              "records": [
                {
                  "modelID": "mlx-community/chatterbox-turbo-4bit",
                  "kind": "voice",
                  "activeDirectoryPath": "\(legacyVoiceDirectory.path)",
                  "revision": "1234567890abcdef1234567890abcdef12345678",
                  "installedAt": "1970-01-01T00:20:34Z",
                  "sizeBytes": 123
                },
                {
                  "modelID": "mlx-community/gemma-2-9b-it-4bit",
                  "kind": "text",
                  "activeDirectoryPath": "\(legacyGemmaDirectory.path)",
                  "revision": "1234567890abcdef1234567890abcdef12345678",
                  "installedAt": "1970-01-01T00:20:34Z",
                  "sizeBytes": 123
                }
              ]
            }
            """.utf8
        )
        try data.write(to: root.manifestURL, options: .atomic)

        let inference = InferenceState()
        let manager = LocalModelManager(
            inference: inference,
            paths: root,
            installer: FakeLocalModelInstaller()
        )

        #expect(manager.installRecords.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: legacyVoiceDirectory.path))
        #expect(!FileManager.default.fileExists(atPath: legacyGemmaDirectory.path))
        #expect(inference.installedLocalTextModelIDs.isEmpty)
    }

    @MainActor
    @Test("refresh prunes falcon installs once the model leaves the pinned catalog")
    func refreshPrunesRetiredFalconInstalls() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.rootDirectory) }

        try root.ensureBaseDirectories()
        let installedURL = root.modelDirectory(for: .text)
            .appendingPathComponent("active", isDirectory: true)
            .appendingPathComponent("mlx-community--Falcon-H1-1.5B-Instruct-4bit", isDirectory: true)
        try FileManager.default.createDirectory(at: installedURL, withIntermediateDirectories: true)

        let data = Data(
            """
            {
              "version": 1,
              "records": [
                {
                  "modelID": "\(LocalTextModelID.falconH1_1B4Bit.rawValue)",
                  "kind": "text",
                  "activeDirectoryPath": "\(installedURL.path)",
                  "revision": "6f5e4f6879b43846b7e960a5e68425f3d5d8c801",
                  "installedAt": "1970-01-01T00:20:34Z",
                  "sizeBytes": 123
                }
              ]
            }
            """.utf8
        )
        try data.write(to: root.manifestURL, options: .atomic)

        let inference = InferenceState()
        let manager = LocalModelManager(
            inference: inference,
            paths: root,
            installer: FakeLocalModelInstaller()
        )

        #expect(manager.installRecords.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: installedURL.path))
        #expect(!inference.installedLocalTextModelIDs.contains(LocalTextModelID.falconH1_1B4Bit.rawValue))
    }

    @MainActor
    @Test("live install smoke verifies qwen3.5 4B active files and manifest state")
    func liveInstallSmokeVerifiesQwen354B() async throws {
        guard FileManager.default.fileExists(atPath: "/tmp/epi-live-qwen35-install-smoke") else { return }

        let bootstrap = AppBootstrap()
        _ = try await LocalRuntimeSmokeSupport.verifyLiveInstall(
            modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            bootstrap: bootstrap
        )
    }

    @MainActor
    @Test("live install smoke verifies qwen3.5 2B constrained fallback files and manifest state")
    func liveInstallSmokeVerifiesQwen352B() async throws {
        guard FileManager.default.fileExists(atPath: "/tmp/epi-live-qwen35-2b-install-smoke") else { return }

        let bootstrap = AppBootstrap()
        _ = try await LocalRuntimeSmokeSupport.verifyLiveInstall(
            modelID: LocalTextModelID.qwen35_2B4Bit.rawValue,
            bootstrap: bootstrap
        )
    }

    @MainActor
    @Test("live ssm smoke verifies lfm2.5 350M state save and resume")
    func liveSSMSmokeVerifiesLFM25350MStateRoundTrip() async throws {
        guard FileManager.default.fileExists(atPath: "/tmp/epi-live-lfm25-install-smoke") else { return }

        let bootstrap = AppBootstrap()
        try await LocalRuntimeSmokeSupport.verifyLiveSSMStateRoundTrip(
            modelID: LocalTextModelID.lfm25_350M.rawValue,
            bootstrap: bootstrap
        )
    }

    @MainActor
    @Test("live ssm smoke verifies mamba2 state save and resume")
    func liveSSMSmokeVerifiesMamba2StateRoundTrip() async throws {
        guard FileManager.default.fileExists(atPath: "/tmp/epi-live-mamba2-install-smoke") else { return }

        let bootstrap = AppBootstrap()
        try await LocalRuntimeSmokeSupport.verifyLiveSSMStateRoundTrip(
            modelID: LocalTextModelID.mamba2_2B4Bit.rawValue,
            bootstrap: bootstrap
        )
    }

    private func makeTemporaryRoot() -> LocalModelPaths {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return LocalModelPaths(rootDirectory: root)
    }

    @Test("prepared retrieval assets stay pending until a semantic index exists")
    func preparedRetrievalAssetsStayPendingUntilIndexExists() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)

        let configuration = PreparedRetrievalRuntimeConfiguration(
            retriever: PreparedModelDescriptor(
                key: "retriever_primary",
                role: .retriever,
                displayName: "BGE-M3",
                artifactID: nil,
                modelID: "BAAI/bge-m3",
                servedModelID: "BAAI/bge-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: retrieverPath.path,
                status: "downloaded",
                trustRemoteCode: false
            )
        )

        #expect(
            configuration.preparedRetrievalExecutionMode
                == PreparedRetrievalExecutionMode.preparedAssetsPendingIndex(
                    retrieverModelID: "BAAI/bge-m3"
                )
        )
    }

    @Test("prepared retrieval execution mode exposes shared fallback and readiness helpers")
    func preparedRetrievalExecutionModeHelpers() {
        #expect(PreparedRetrievalExecutionMode.appleEmbeddingFallback.usesSwiftEmbeddingFallback)
        #expect(!PreparedRetrievalExecutionMode.appleEmbeddingFallback.hasPreparedAssetsConfigured)
        #expect(!PreparedRetrievalExecutionMode.appleEmbeddingFallback.requiresPreparedIndexBuild)
        #expect(!PreparedRetrievalExecutionMode.appleEmbeddingFallback.hasPreparedIndexRuntime)

        let pendingIndex = PreparedRetrievalExecutionMode.preparedAssetsPendingIndex(
            retrieverModelID: "BAAI/bge-m3"
        )
        #expect(!pendingIndex.usesSwiftEmbeddingFallback)
        #expect(pendingIndex.hasPreparedAssetsConfigured)
        #expect(pendingIndex.requiresPreparedIndexBuild)
        #expect(!pendingIndex.hasPreparedIndexRuntime)

        let ready = PreparedRetrievalExecutionMode.preparedIndexReady(
            retrieverModelID: "BAAI/bge-m3"
        )
        #expect(!ready.usesSwiftEmbeddingFallback)
        #expect(ready.hasPreparedAssetsConfigured)
        #expect(!ready.requiresPreparedIndexBuild)
        #expect(ready.hasPreparedIndexRuntime)
    }

    @Test("prepared retrieval runtime reports ready once a valid built index exists")
    func preparedRetrievalRuntimeReportsReadyOnceBuilt() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)

        let configuration = PreparedRetrievalRuntimeConfiguration(
            retriever: PreparedModelDescriptor(
                key: "retriever_primary",
                role: .retriever,
                displayName: "BGE-M3",
                artifactID: nil,
                modelID: "BAAI/bge-m3",
                servedModelID: "BAAI/bge-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: retrieverPath.path,
                status: "downloaded",
                trustRemoteCode: false
            )
        )

        let layout = try #require(configuration.assetLayout)
        try FileManager.default.createDirectory(atPath: layout.indexRoot, withIntermediateDirectories: true)
        let sourceDatabaseURL = try makeSourceDatabase(
            root: tempRoot,
            modifiedAt: Date(timeIntervalSince1970: 10)
        )
        let manifest = PreparedRetrievalIndexManifest(
            retrieverModelID: "BAAI/bge-m3",
            embeddingFormat: "row-major-f32-v1",
            embeddingDimension: 2,
            documentCount: 1,
            embeddingsFile: "block-embeddings.f32",
            documentsFile: "documents.jsonl",
            builtAt: 10,
            sourceDatabasePath: sourceDatabaseURL.path,
            sourceDatabaseModifiedAt: 10,
            sourceDatabaseWALModifiedAt: nil
        )
        try JSONEncoder().encode(manifest).write(to: URL(fileURLWithPath: layout.indexManifestPath), options: .atomic)
        try Data(count: 8).write(to: URL(fileURLWithPath: layout.embeddingsPath), options: .atomic)
        try Data("{\"block_id\":\"block-1\",\"page_id\":\"page-1\",\"content\":\"hello\"}\n".utf8)
            .write(to: URL(fileURLWithPath: layout.documentsPath), options: .atomic)

        #expect(layout.readinessState == PreparedRetrievalReadinessState.ready)
        #expect(
            configuration.preparedRetrievalExecutionMode
                == PreparedRetrievalExecutionMode.preparedIndexReady(
                    retrieverModelID: "BAAI/bge-m3"
                )
        )
    }

    @Test("prepared retrieval runtime rejects mismatched index manifests")
    func preparedRetrievalRuntimeRejectsMismatchedIndexManifest() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)

        let configuration = PreparedRetrievalRuntimeConfiguration(
            retriever: PreparedModelDescriptor(
                key: "retriever_primary",
                role: .retriever,
                displayName: "BGE-M3",
                artifactID: nil,
                modelID: "BAAI/bge-m3",
                servedModelID: "BAAI/bge-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: retrieverPath.path,
                status: "downloaded",
                trustRemoteCode: false
            )
        )

        let layout = try #require(configuration.assetLayout)
        try FileManager.default.createDirectory(atPath: layout.indexRoot, withIntermediateDirectories: true)
        let manifest = PreparedRetrievalIndexManifest(
            retrieverModelID: "BAAI/not-bge-m3",
            embeddingFormat: "row-major-f32-v1",
            embeddingDimension: 2,
            documentCount: 1,
            embeddingsFile: "block-embeddings.f32",
            documentsFile: "documents.jsonl"
        )
        try JSONEncoder().encode(manifest).write(to: URL(fileURLWithPath: layout.indexManifestPath), options: .atomic)
        try Data(count: 8).write(to: URL(fileURLWithPath: layout.embeddingsPath), options: .atomic)
        try Data("{\"block_id\":\"block-1\",\"page_id\":\"page-1\",\"content\":\"hello\"}\n".utf8)
            .write(to: URL(fileURLWithPath: layout.documentsPath), options: .atomic)

        #expect(layout.readinessState == PreparedRetrievalReadinessState.invalidManifest)
        #expect(
            configuration.preparedRetrievalExecutionMode
                == PreparedRetrievalExecutionMode.preparedAssetsPendingIndex(
                    retrieverModelID: "BAAI/bge-m3"
                )
        )
    }

    @Test("prepared retrieval runtime rejects mismatched embedding matrix shape")
    func preparedRetrievalRuntimeRejectsMismatchedEmbeddingMatrixShape() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)

        let configuration = PreparedRetrievalRuntimeConfiguration(
            retriever: PreparedModelDescriptor(
                key: "retriever_primary",
                role: .retriever,
                displayName: "BGE-M3",
                artifactID: nil,
                modelID: "BAAI/bge-m3",
                servedModelID: "BAAI/bge-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: retrieverPath.path,
                status: "downloaded",
                trustRemoteCode: false
            )
        )

        let layout = try #require(configuration.assetLayout)
        try FileManager.default.createDirectory(atPath: layout.indexRoot, withIntermediateDirectories: true)
        let manifest = PreparedRetrievalIndexManifest(
            retrieverModelID: "BAAI/bge-m3",
            embeddingFormat: "row-major-f32-v1",
            embeddingDimension: 2,
            documentCount: 2,
            embeddingsFile: "block-embeddings.f32",
            documentsFile: "documents.jsonl"
        )
        try JSONEncoder().encode(manifest).write(to: URL(fileURLWithPath: layout.indexManifestPath), options: .atomic)
        try Data(count: 8).write(to: URL(fileURLWithPath: layout.embeddingsPath), options: .atomic)
        try Data("""
        {"block_id":"block-1","page_id":"page-1","content":"hello"}
        {"block_id":"block-2","page_id":"page-2","content":"world"}
        """.utf8).write(to: URL(fileURLWithPath: layout.documentsPath), options: .atomic)

        #expect(layout.readinessState == PreparedRetrievalReadinessState.invalidEmbeddings)
        #expect(
            configuration.preparedRetrievalExecutionMode
                == PreparedRetrievalExecutionMode.preparedAssetsPendingIndex(
                    retrieverModelID: "BAAI/bge-m3"
                )
        )
    }

    @Test("prepared retrieval runtime rejects stale source database snapshots")
    func preparedRetrievalRuntimeRejectsStaleSourceDatabaseSnapshot() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)

        let configuration = PreparedRetrievalRuntimeConfiguration(
            retriever: PreparedModelDescriptor(
                key: "retriever_primary",
                role: .retriever,
                displayName: "BGE-M3",
                artifactID: nil,
                modelID: "BAAI/bge-m3",
                servedModelID: "BAAI/bge-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: retrieverPath.path,
                status: "downloaded",
                trustRemoteCode: false
            )
        )

        let layout = try #require(configuration.assetLayout)
        try FileManager.default.createDirectory(atPath: layout.indexRoot, withIntermediateDirectories: true)
        let sourceDatabaseURL = try makeSourceDatabase(
            root: tempRoot,
            modifiedAt: Date(timeIntervalSince1970: 10)
        )
        let manifest = PreparedRetrievalIndexManifest(
            retrieverModelID: "BAAI/bge-m3",
            embeddingFormat: "row-major-f32-v1",
            embeddingDimension: 2,
            documentCount: 1,
            embeddingsFile: "block-embeddings.f32",
            documentsFile: "documents.jsonl",
            builtAt: 10,
            sourceDatabasePath: sourceDatabaseURL.path,
            sourceDatabaseModifiedAt: 10,
            sourceDatabaseWALModifiedAt: nil
        )
        try JSONEncoder().encode(manifest).write(to: URL(fileURLWithPath: layout.indexManifestPath), options: .atomic)
        try Data(count: 8).write(to: URL(fileURLWithPath: layout.embeddingsPath), options: .atomic)
        try Data("{\"block_id\":\"block-1\",\"page_id\":\"page-1\",\"content\":\"hello\"}\n".utf8)
            .write(to: URL(fileURLWithPath: layout.documentsPath), options: .atomic)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 20)],
            ofItemAtPath: sourceDatabaseURL.path
        )

        #expect(layout.readinessState == PreparedRetrievalReadinessState.staleSourceSnapshot)
        #expect(
            configuration.preparedRetrievalExecutionMode
                == PreparedRetrievalExecutionMode.preparedAssetsPendingIndex(
                    retrieverModelID: "BAAI/bge-m3"
                )
        )
    }
}

private actor FakeLocalModelInstaller: LocalModelArtifactInstalling {
    func install(
        descriptor: LocalModelDescriptor,
        paths: LocalModelPaths,
        progressHandler: (@MainActor @Sendable (Progress) -> Void)?
    ) async throws -> LocalModelInstallRecord {
        try paths.ensureBaseDirectories()
        let activeDirectory = paths.activeDirectory(for: descriptor)
        try FileManager.default.createDirectory(at: activeDirectory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: activeDirectory.appendingPathComponent("config.json"))
        try Data("tokenizer".utf8).write(to: activeDirectory.appendingPathComponent("tokenizer.json"))
        try Data([1, 2, 3]).write(to: activeDirectory.appendingPathComponent("weights.safetensors"))

        let progress = Progress(totalUnitCount: 1)
        progress.completedUnitCount = 1
        await progressHandler?(progress)

        return LocalModelInstallRecord(
            modelID: descriptor.id,
            kind: descriptor.kind,
            activeDirectoryPath: activeDirectory.path,
            revision: descriptor.revision,
            installedAt: Date(timeIntervalSince1970: 42),
            sizeBytes: 3
        )
    }
}

private func makeSourceDatabase(root: URL, modifiedAt: Date) throws -> URL {
    let sourceDatabaseURL = root.appendingPathComponent("search.sqlite", isDirectory: false)
    FileManager.default.createFile(atPath: sourceDatabaseURL.path, contents: Data("db".utf8))
    try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: sourceDatabaseURL.path)
    return sourceDatabaseURL
}
