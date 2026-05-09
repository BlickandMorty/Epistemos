import Testing
@testable import Epistemos

private let isolatedInferenceDefaultsKeys = [
    "epistemos.localRoutingMode",
    "epistemos.chatAutoRouteToCloud",
    "epistemos.cloudAutoFallback",
    "epistemos.preferredLocalTextModelID",
    "epistemos.preferredChatModelSelection",
    "epistemos.activeAIProvider",
    "epistemos.cloudSetupHintShown",
    "epistemos.preferredCloudModel.openAI",
    "epistemos.preferredCloudModel.anthropic",
    "epistemos.preferredCloudModel.google",
    "epistemos.preferredCloudModel.zai",
    "epistemos.preferredCloudModel.kimi",
    "epistemos.preferredCloudModel.minimax",
    "epistemos.preferredCloudModel.deepseek",
]

private let triageInteractiveReleaseFixtureModelID = LocalTextModelID.qwen3_4B4Bit
private let triageThinkingReleaseFixtureModelID = LocalTextModelID.qwen3_4BThinking25074Bit
private let ggufCapableTestHardwareSnapshot = LocalHardwareCapabilitySnapshot(
    physicalMemoryBytes: 64_000_000_000,
    roundedMemoryGB: 64,
    maxRecommendedLocalContentLength: 28_000
)

@MainActor
private func makeIsolatedInferenceState(
    hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot = .current,
    keychainStore: TestKeychainStore = TestKeychainStore(),
    keychainLoad: (@Sendable (String) -> String?)? = nil,
    keychainSave: (@Sendable (String, String) -> Bool)? = nil,
    keychainDelete: (@Sendable (String) -> Void)? = nil
) -> InferenceState {
    let defaults = UserDefaults.standard
    let savedValues = isolatedInferenceDefaultsKeys.reduce(into: [String: Any?]()) { partialResult, key in
        partialResult[key] = defaults.object(forKey: key)
        defaults.removeObject(forKey: key)
    }
    defer {
        for key in isolatedInferenceDefaultsKeys {
            if let value = savedValues[key] ?? nil {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
    let resolvedKeychainLoad = keychainLoad ?? keychainStore.load(_:)
    let resolvedKeychainSave = keychainSave ?? keychainStore.save(_:_:)
    let resolvedKeychainDelete = keychainDelete ?? keychainStore.delete(_:)
    return InferenceState(
        hardwareCapabilitySnapshot: hardwareCapabilitySnapshot,
        keychainLoad: resolvedKeychainLoad,
        keychainSave: resolvedKeychainSave,
        keychainDelete: resolvedKeychainDelete
    )
}

@Suite("TriageService")
struct TriageServiceTests {

    @Test("empty string is a refusal")
    func emptyRefusal() {
        #expect(TriageService.isRefusalResponse(""))
    }

    @Test("whitespace-only string is a refusal")
    func whitespaceRefusal() {
        #expect(TriageService.isRefusalResponse("   \n  "))
    }

    @Test("generic and Apple refusals are detected")
    func refusalDetection() {
        #expect(TriageService.isRefusalResponse("I can't help with that request."))
        #expect(TriageService.isRefusalResponse("As a language model created by Apple, I am unable to assist with that."))
        #expect(!TriageService.isRefusalResponse("Bayesian updating revises beliefs in proportion to evidence."))
    }

    @Test("truncation detection catches short and abrupt responses")
    func truncationDetection() {
        #expect(TriageService.isTruncatedResponse("Yes"))
        #expect(TriageService.isTruncatedResponse("This response ends abruptly without punctuation"))
        #expect(!TriageService.isTruncatedResponse("This response is complete."))
        #expect(!TriageService.isTruncatedResponse("Here are the key points:\n- First item"))
    }

    @Test("fallback heuristic combines refusal and truncation checks")
    func fallbackHeuristic() {
        #expect(TriageService.shouldRetryWithLocalModel(""))
        #expect(TriageService.shouldRetryWithLocalModel("I cannot assist with that."))
        #expect(TriageService.shouldRetryWithLocalModel("Short"))
        #expect(!TriageService.shouldRetryWithLocalModel("This answer is complete, substantive, and properly finished."))
    }

    @Test("operation complexity ordering stays coherent")
    func complexityOrdering() {
        #expect(NotesOperation.grammarFix.baseComplexity < NotesOperation.summarize.baseComplexity)
        #expect(NotesOperation.summarize.baseComplexity <= NotesOperation.ask(query: "test").baseComplexity)
        #expect(NotesOperation.ask(query: "test").baseComplexity < NotesOperation.outline.baseComplexity)
        #expect(NotesOperation.outline.baseComplexity < NotesOperation.expand.baseComplexity)
        #expect(NotesOperation.expand.baseComplexity < NotesOperation.analyze.baseComplexity)
    }

    @Test("triage decisions expose labels and icons")
    func decisionPresentation() {
        #expect(!TriageDecision.appleIntelligence.label.isEmpty)
        #expect(!TriageDecision.localMLX.label.isEmpty)
        #expect(!TriageDecision.appleIntelligence.icon.isEmpty)
        #expect(!TriageDecision.localMLX.icon.isEmpty)
        #expect(TriageDecision.appleIntelligence.isOnDevice)
        #expect(TriageDecision.localMLX.isOnDevice)
    }

    @Test("routing stays Apple plus local without stale cloud modes or providers")
    func routingSurfaceRemainsTwoState() {
        let expectedProviders: [LLMProviderType] = [
            .appleIntelligence,
            .localGGUF,
            .localMLX,
            .openAI,
            .anthropic,
            .google,
            .zai,
            .kimi,
            .minimax,
            .deepseek,
        ]
        #expect(LocalRoutingMode.allCases == [.auto, .localOnly])
        #expect(LLMProviderType.allCases == expectedProviders)
    }

    @Test("routing summaries keep the local runtime primary in auto mode")
    func routingSummariesStayLocalFirst() {
        #expect(LocalRoutingMode.auto.summary.contains("local runtime primary"))
        #expect(LocalRoutingMode.auto.summary.contains("Apple Intelligence remains available"))
        #expect(LocalRoutingMode.localOnly.summary.contains("Apple Intelligence is bypassed"))
    }

    @Test("local routing errors no longer mention switch routing modes")
    func localRoutingErrorsUseCurrentArchitectureCopy() {
        #expect(LocalInferenceRoutingError.modelRequired.errorDescription?.contains("switch routing modes") == false)
        #expect(LocalInferenceRoutingError.modelRequired.errorDescription?.contains("installed local model") == false)
    }

    @Test("model load stalled error gives smaller-model guidance")
    func modelLoadStalledErrorUsesActionableCopy() {
        let description = LocalInferenceRoutingError
            .modelLoadStalled(modelID: LocalTextModelID.qwen25Coder7B.rawValue)
            .errorDescription
        #expect(description?.contains("Qwen 2.5 Coder 7B") == true)
        #expect(description?.contains("Qwen 3 4B") == true)
        #expect(description?.contains("timed out") == false)
    }

    @Test("chat model selection preserves cloud model raw values")
    func chatModelSelectionPreservesCloudModelRawValues() {
        let selection = ChatModelSelection(rawValue: "cloud:openai:gpt-5.4")
        #expect(selection == .cloud(.openAIGPT54))
        #expect(selection?.rawValue == "cloud:openai:gpt-5.4")
    }

    @Test("legacy cloud model selections migrate to supported cloud models")
    func legacyCloudModelSelectionsMigrateForward() {
        #expect(ChatModelSelection(rawValue: "cloud:openai:gpt-5.3") == .cloud(.openAIGPT54))
        #expect(ChatModelSelection(rawValue: "cloud:anthropic:claude-sonnet-4-6") == .cloud(.anthropicClaudeSonnet46))
        #expect(ChatModelSelection(rawValue: "cloud:google:gemini-1.5-pro") == .cloud(.googleGemini31ProPreview))
    }

    @MainActor
    @Test("visible cloud picker surfaces stay curated to the main providers")
    func visibleCloudPickerSurfacesStayCurated() {
        let inference = InferenceState()

        #expect(inference.cloudModels(for: .openAI) == [.openAIGPT54, .openAIGPT54Mini])
        #expect(inference.cloudModels(for: .anthropic) == [.anthropicClaudeOpus47, .anthropicClaudeSonnet46])
        #expect(inference.cloudModels(for: .google) == [.googleGemini31ProPreview, .googleGemini3FlashPreview])
        #expect(CloudModelProvider.preferredOrder == [.openAI, .anthropic, .google])
    }

    @Test("cloud models expose only their supported operating modes")
    func cloudModelsExposeSupportedOperatingModes() {
        #expect(CloudTextModelID.openAIGPT54.supportedOperatingModes == [.fast, .thinking, .pro, .agent])
        #expect(CloudTextModelID.openAIGPT54Mini.supportedOperatingModes == [.fast, .agent])
        #expect(CloudTextModelID.anthropicClaudeOpus47.supportedOperatingModes == [.fast, .thinking, .pro, .agent])
        #expect(CloudTextModelID.anthropicClaudeSonnet46.supportedOperatingModes == [.fast, .thinking, .agent])
        #expect(CloudTextModelID.googleGemini31ProPreview.supportedOperatingModes == [.fast, .thinking, .pro, .agent])
        #expect(CloudTextModelID.googleGemini3FlashPreview.supportedOperatingModes == [.fast, .agent])
        #expect(CloudTextModelID.zaiGLM5.supportedOperatingModes == [.fast, .thinking, .pro, .agent])
        #expect(CloudTextModelID.kimiK2Thinking.supportedOperatingModes == [.thinking, .pro, .agent])
        #expect(CloudTextModelID.minimaxM25HighSpeed.supportedOperatingModes == [.fast, .agent])
        #expect(CloudTextModelID.deepseekChat.supportedOperatingModes == [.fast, .agent])
        #expect(CloudTextModelID.deepseekReasoner.supportedOperatingModes == [.thinking, .pro, .agent])
    }

    @Test("cloud runtime capability matrix stays model aware")
    func cloudRuntimeCapabilityMatrixStaysModelAware() {
        #expect(CloudTextModelID.openAIGPT54.supportsNativeReasoningEffortControl)
        #expect(!CloudTextModelID.openAIO3.supportsNativeReasoningEffortControl)
        #expect(CloudTextModelID.anthropicClaudeSonnet46.supportsNativeReasoningEffortControl)
        #expect(CloudTextModelID.googleGemini31ProPreview.supportsNativeReasoningEffortControl)
        #expect(!CloudTextModelID.deepseekReasoner.supportsNativeReasoningEffortControl)

        #expect(CloudTextModelID.openAIGPT54.supportsProviderNativeFeatureControls)
        #expect(CloudTextModelID.anthropicClaudeSonnet46.supportsProviderNativeFeatureControls)
        #expect(CloudTextModelID.googleGemini31ProPreview.supportsProviderNativeFeatureControls)
        #expect(!CloudTextModelID.deepseekReasoner.supportsProviderNativeFeatureControls)
    }

    @Test("cloud models expose about-sheet metadata")
    func cloudModelsExposeAboutSheetMetadata() {
        #expect(CloudTextModelID.openAIGPT54.aboutSheetBadge == "OpenAI")
        #expect(CloudTextModelID.openAIGPT54.aboutSheetModeSummary == "Fast, Thinking, Pro, Inline Tools")
        #expect(CloudTextModelID.openAIGPT54.aboutSheetStructuredOutputSummary == "Structured JSON")
        #expect(
            CloudTextModelID.openAIGPT54.aboutSheetPurposeSummary
                == "Complex reasoning, coding, and tool-heavy professional work."
        )
        #expect(CloudTextModelID.kimiK25.aboutSheetStructuredOutputSummary == "Prompt JSON fallback")
        #expect(CloudTextModelID.deepseekReasoner.aboutSheetBadge == "DeepSeek")
    }

    @Test("visible chat mode copy reads as one fused chat with depth controls")
    func operatingModeCopyEmphasizesFusedChat() {
        #expect(EpistemosOperatingMode.pro.displayName == "Pro")
        #expect(EpistemosOperatingMode.agent.displayName == "Tools")
        #expect(EpistemosOperatingMode.fast.helpText.contains("same chat"))
        #expect(EpistemosOperatingMode.thinking.helpText.contains("same chat"))
        #expect(EpistemosOperatingMode.pro.helpText.contains("same chat"))
        #expect(EpistemosOperatingMode.agent.helpText.contains("this chat"))
    }

    @Test("inference state sanitizes unsupported cloud operating modes")
    @MainActor func inferenceStateSanitizesUnsupportedCloudOperatingModes() {
        let inference = makeIsolatedInferenceState(
            keychainLoad: { key in
                key == CloudModelProvider.openAI.apiKeyKeychainKey ? "sk-openai-test" : nil
            },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        inference.setPreferredChatModelSelection(.cloud(.openAIGPT54Mini))

        #expect(inference.availableOperatingModes == [.fast, .agent])
        #expect(inference.sanitizedOperatingMode(.thinking) == .fast)
        #expect(inference.sanitizedOperatingMode(.pro) == .fast)
    }

    @Test("shared chat mode sanitizer honors surface-specific available modes")
    @MainActor func sharedChatModeSanitizerHonorsSurfaceSpecificModes() {
        let inference = makeIsolatedInferenceState(
            keychainLoad: { key in
                key == CloudModelProvider.openAI.apiKeyKeychainKey ? "sk-openai-test" : nil
            },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        inference.setPreferredChatModelSelection(.cloud(.openAIGPT54))

        let noteSurfaceModes: [EpistemosOperatingMode] = [.fast, .thinking, .pro]
        #expect(
            MainChatOperatingModePreference.supportedModes(
                for: inference,
                availableModes: noteSurfaceModes
            ) == noteSurfaceModes
        )
        #expect(
            MainChatOperatingModePreference.sanitize(
                .agent,
                for: inference,
                availableModes: noteSurfaceModes
            ) == .fast
        )
        #expect(
            MainChatOperatingModePreference.sanitize(
                .thinking,
                for: inference,
                availableModes: noteSurfaceModes
            ) == .thinking
        )
    }

    @Test("main chat operating mode preference keeps tools visible on supported surfaces")
    @MainActor func mainChatOperatingModePreferenceKeepsToolsVisibleOnSupportedSurfaces() {
        let inference = makeIsolatedInferenceState(
            keychainLoad: { key in
                key == CloudModelProvider.openAI.apiKeyKeychainKey ? "sk-openai-test" : nil
            },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        inference.setPreferredChatModelSelection(.cloud(.openAIGPT54))

        #expect(
            MainChatOperatingModePreference.supportedModes(for: inference) == [.fast, .thinking, .pro, .agent]
        )
        #expect(
            MainChatOperatingModePreference.sanitize(.agent, for: inference) == .agent
        )
        #expect(
            MainChatOperatingModePreference.sanitize(.pro, for: inference) == .pro
        )
    }

    @Test("explicit local chat selection disables cloud auto-route presentation for chat surfaces")
    @MainActor func explicitLocalChatSelectionDisablesCloudAutoRoutePresentation() {
        let inference = makeIsolatedInferenceState(
            keychainLoad: { key in
                key == CloudModelProvider.openAI.apiKeyKeychainKey ? "sk-openai-test" : nil
            },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        let localModelID = LocalTextModelID.qwen3_4B4Bit.rawValue
        inference.setInstalledLocalTextModelIDs([localModelID])
        inference.setPreferredLocalTextModelID(localModelID)
        inference.chatAutoRouteToCloud = true
        inference.setPreferredChatModelSelection(.localMLX(localModelID))

        let effectiveSelection = inference.effectiveChatSurfaceSelection(for: .thinking)
        #expect(effectiveSelection == .localMLX(localModelID))
        #expect(inference.activeChatModelDisplayName == LocalTextModelID.qwen3_4B4Bit.displayName)
        #expect(
            inference.chatSurfaceRouteDescription(for: .thinking).headline
                == LocalTextModelID.qwen3_4B4Bit.compactDisplayName
        )
    }

    @Test("pinned always-thinking local model hides fast mode")
    @MainActor func pinnedAlwaysThinkingLocalModelHidesFastMode() {
        let inference = makeIsolatedInferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.deepseekR1Distill7B.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.deepseekR1Distill7B.rawValue)
        inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.deepseekR1Distill7B.rawValue))

        #expect(!inference.availableOperatingModes.contains(.fast))
        #expect(inference.availableOperatingModes.contains(.thinking))
        #expect(inference.sanitizedOperatingMode(.fast) == .thinking)
    }

    @Test("qwen coder is flagged as fast-incompatible")
    func qwenCoderIsFlaggedAsFastIncompatible() {
        #expect(LocalTextModelID.qwen25Coder7B.cannotDisableThinkingInFast)
    }

    @MainActor
    @Test("mlx client rejects fast mode for always-thinking families")
    func mlxClientRejectsFastModeForAlwaysThinkingFamilies() async throws {
        let paths = LocalModelPaths(
            rootDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(
            LocalModelCatalog.descriptor(for: LocalTextModelID.deepseekR1Distill7B.rawValue)
        )
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = makeIsolatedInferenceState()
        inference.setInstalledLocalTextModelIDs([descriptor.id])
        inference.setPreferredLocalTextModelID(descriptor.id)

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        await #expect(
            throws: LocalInferenceRoutingError.fastModeUnsupported(modelID: descriptor.id)
        ) {
            _ = try await client.generate(
                prompt: "Hello",
                systemPrompt: "Be brief.",
                maxTokens: 32
            )
        }
    }

    @Test("pinned local chat selection keeps pro and agent local even with cloud auto-route enabled")
    @MainActor func inferenceStateEffectiveChatSurfaceSelectionKeepsPinnedLocalSelection() {
        let inference = makeIsolatedInferenceState(
            keychainLoad: { key in
                key == CloudModelProvider.openAI.apiKeyKeychainKey ? "sk-openai-test" : nil
            },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_2B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_2B4Bit.rawValue)
        inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen35_2B4Bit.rawValue))
        inference.setChatAutoRouteToCloud(true)

        let expectedSelection = ChatModelSelection.localMLX(LocalTextModelID.qwen35_2B4Bit.rawValue)
        #expect(inference.effectiveChatSurfaceSelection(for: .fast) == expectedSelection)
        #expect(inference.effectiveChatSurfaceSelection(for: .thinking) == expectedSelection)
        #expect(inference.effectiveChatSurfaceSelection(for: .pro) == expectedSelection)
        #expect(inference.effectiveChatSurfaceSelection(for: .agent) == expectedSelection)
    }

    @Test("OpenAI auto route keeps GPT-5.4 as the thinking and pro workhorse")
    @MainActor func openAIAutoRouteKeepsGPT54ForThinkingAndPro() throws {
        let inference = makeIsolatedInferenceState(
            keychainLoad: { key in
                key == CloudModelProvider.openAI.apiKeyKeychainKey ? "sk-openai-test" : nil
            },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        inference.setActiveAIProvider(.openAI)
        inference.setChatAutoRouteToCloud(true)

        #expect(inference.preferredAutoRouteCloudModel(for: .fast) == .openAIGPT54Mini)
        #expect(inference.preferredAutoRouteCloudModel(for: .thinking) == .openAIGPT54)
        #expect(inference.preferredAutoRouteCloudModel(for: .pro) == .openAIGPT54)
    }

    @Test("configuring the auto-route cloud model keeps the current local chat selection")
    @MainActor func configuringAutoRouteCloudModelKeepsLocalSelection() {
        let inference = makeIsolatedInferenceState(
            keychainLoad: { key in
                key == CloudModelProvider.openAI.apiKeyKeychainKey ? "sk-openai-test" : nil
            },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        let localModelID = LocalTextModelID.qwen35_2B4Bit.rawValue
        inference.setInstalledLocalTextModelIDs([localModelID])
        inference.setPreferredLocalTextModelID(localModelID)
        inference.setPreferredChatModelSelection(.localMLX(localModelID))
        inference.setChatAutoRouteToCloud(true)

        inference.setPreferredCloudModel(.openAIGPT52)

        #expect(inference.preferredChatModelSelection == .localMLX(localModelID))
        #expect(inference.preferredCloudModel(for: .openAI) == .openAIGPT54)
        #expect(inference.preferredAutoRouteCloudModel(for: .pro) == .openAIGPT54)
    }

    @Test("cloud auto fallback persists across inference state reloads")
    @MainActor func cloudAutoFallbackPersistsAcrossInferenceStateReloads() {
        let defaults = UserDefaults.standard
        let key = "epistemos.cloudAutoFallback"
        let savedValue = defaults.object(forKey: key)
        defer {
            if let savedValue {
                defaults.set(savedValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.removeObject(forKey: key)

        let inference = InferenceState(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        inference.setCloudAutoFallback(true)

        let reloaded = InferenceState(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        #expect(reloaded.cloudAutoFallback)
    }

    @Test("chat auto route persists across inference state reloads")
    @MainActor func chatAutoRoutePersistsAcrossInferenceStateReloads() {
        let defaults = UserDefaults.standard
        let key = "epistemos.chatAutoRouteToCloud"
        let savedValue = defaults.object(forKey: key)
        defer {
            if let savedValue {
                defaults.set(savedValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.removeObject(forKey: key)

        let inference = InferenceState(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        inference.setChatAutoRouteToCloud(true)

        let reloaded = InferenceState(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        #expect(reloaded.chatAutoRouteToCloud)
    }

    @Test("stale Gemma 4 local selections auto-migrate to a runnable default")
    @MainActor func migrateStaleGemma4Selection() {
        let defaults = UserDefaults.standard
        let localKey = "epistemos.preferredLocalTextModelID"
        let selectionKey = "epistemos.preferredChatModelSelection"

        let savedLocal = defaults.object(forKey: localKey)
        let savedSelection = defaults.object(forKey: selectionKey)
        defer {
            if let savedLocal {
                defaults.set(savedLocal, forKey: localKey)
            } else {
                defaults.removeObject(forKey: localKey)
            }
            if let savedSelection {
                defaults.set(savedSelection, forKey: selectionKey)
            } else {
                defaults.removeObject(forKey: selectionKey)
            }
        }

        defaults.set(LocalTextModelID.gemma4_4B4Bit.rawValue, forKey: localKey)
        defaults.set(
            ChatModelSelection.localMLX(LocalTextModelID.gemma4_4B4Bit.rawValue).rawValue,
            forKey: selectionKey
        )

        InferenceState.migrateStaleGemma4Selection(defaults: defaults)

        #expect(
            defaults.string(forKey: localKey) == LocalTextModelID.qwen3_4B4Bit.rawValue
        )
        #expect(
            defaults.string(forKey: selectionKey)
                == ChatModelSelection.localMLX(LocalTextModelID.qwen3_4B4Bit.rawValue).rawValue
        )
    }

    @Test("Gemma 4 tiers are hidden from the interactive chat picker")
    func gemma4TiersHiddenFromPicker() {
        #expect(!LocalTextModelID.gemma4_2B4Bit.isReleaseValidatedForInteractiveChat)
        #expect(!LocalTextModelID.gemma4_4B4Bit.isReleaseValidatedForInteractiveChat)
        #expect(!LocalTextModelID.gemma4_27BA4B4Bit.isReleaseValidatedForInteractiveChat)
        #expect(!LocalTextModelID.gemma4_31BJANG.isReleaseValidatedForInteractiveChat)

        #expect(LocalTextModelID.gemma4_4B4Bit.isAwaitingSwiftRuntimeLoader)
        #expect(LocalTextModelID.gemma4_4B4Bit.releasePickerVisibilityReason?.contains("Swift MLX loader") == true)
    }

    @Test("model vault settings defer release-tier filtering to the shared inference targets builder")
    func modelVaultSettingsUseSharedReleaseTierFiltering() throws {
        let settingsSource = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ModelVaultsSettingsView.swift")
        let inferenceSource = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")

        #expect(settingsSource.contains("inference.modelVaultTargets()"))
        #expect(inferenceSource.contains("LocalModelCatalog.allDescriptors"))
        #expect(inferenceSource.contains("releaseSelectableInstalledLocalTextModelIDs.contains(descriptor.id)"))
        #expect(inferenceSource.contains("LocalTextModelID(rawValue: descriptor.id)"))
        #expect(inferenceSource.contains("model.isReleaseValidatedForInteractiveChat"))
    }

    @Test("Gemma 4 chat selection sanitizes to the runnable local default")
    @MainActor func gemma4ChatSelectionSanitizesToFallback() {
        let inference = makeIsolatedInferenceState()
        inference.setInstalledLocalTextModelIDs([])
        inference.setPreparedLocalTextModelIDs([])

        inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.gemma4_4B4Bit.rawValue))

        #expect(
            inference.preferredChatModelSelection
                == .localMLX(LocalTextModelID.qwen3_4B4Bit.rawValue)
        )
        #expect(inference.preferredLocalTextModelID == LocalTextModelID.qwen3_4B4Bit.rawValue)
    }

    @Test("persisted Gemma 4 chat selection normalizes on inference load")
    @MainActor func persistedGemma4ChatSelectionNormalizesOnLoad() {
        let defaults = UserDefaults.standard
        let localKey = "epistemos.preferredLocalTextModelID"
        let selectionKey = "epistemos.preferredChatModelSelection"
        let savedLocal = defaults.object(forKey: localKey)
        let savedSelection = defaults.object(forKey: selectionKey)
        defer {
            if let savedLocal {
                defaults.set(savedLocal, forKey: localKey)
            } else {
                defaults.removeObject(forKey: localKey)
            }
            if let savedSelection {
                defaults.set(savedSelection, forKey: selectionKey)
            } else {
                defaults.removeObject(forKey: selectionKey)
            }
        }

        defaults.set(LocalTextModelID.qwen3_4B4Bit.rawValue, forKey: localKey)
        defaults.set(
            ChatModelSelection.localMLX(LocalTextModelID.gemma4_4B4Bit.rawValue).rawValue,
            forKey: selectionKey
        )

        let inference = makeIsolatedInferenceState()
        inference.setInstalledLocalTextModelIDs([])
        inference.setPreparedLocalTextModelIDs([])

        #expect(
            inference.preferredChatModelSelection
                == .localMLX(LocalTextModelID.qwen3_4B4Bit.rawValue)
        )
    }

    @Test("legacy OpenAI GPT-5.2 preference migrates forward to GPT-5.4")
    @MainActor func migrateLegacyOpenAI52To54() {
        let defaults = UserDefaults.standard
        let preferredKey = "epistemos.preferredCloudModel.openAI"
        let selectionKey = "epistemos.preferredChatModelSelection"
        let migrationKey = "epistemos.migratedOpenAI52To54"

        let savedPreferred = defaults.object(forKey: preferredKey)
        let savedSelection = defaults.object(forKey: selectionKey)
        let savedMigration = defaults.object(forKey: migrationKey)
        defer {
            if let savedPreferred {
                defaults.set(savedPreferred, forKey: preferredKey)
            } else {
                defaults.removeObject(forKey: preferredKey)
            }
            if let savedSelection {
                defaults.set(savedSelection, forKey: selectionKey)
            } else {
                defaults.removeObject(forKey: selectionKey)
            }
            if let savedMigration {
                defaults.set(savedMigration, forKey: migrationKey)
            } else {
                defaults.removeObject(forKey: migrationKey)
            }
        }

        defaults.set(CloudTextModelID.openAIGPT52.rawValue, forKey: preferredKey)
        defaults.set(
            ChatModelSelection.cloud(.openAIGPT52).rawValue,
            forKey: selectionKey
        )
        defaults.removeObject(forKey: migrationKey)

        InferenceState.migrateLegacyOpenAI52To54(defaults: defaults)

        #expect(defaults.string(forKey: preferredKey) == CloudTextModelID.openAIGPT54.rawValue)
        #expect(
            defaults.string(forKey: selectionKey)
                == ChatModelSelection.cloud(.openAIGPT54).rawValue
        )
        #expect(defaults.bool(forKey: migrationKey))

        // Second run is a no-op even if the user later picks 5.2 manually.
        defaults.set(CloudTextModelID.openAIGPT52.rawValue, forKey: preferredKey)
        InferenceState.migrateLegacyOpenAI52To54(defaults: defaults)
        #expect(defaults.string(forKey: preferredKey) == CloudTextModelID.openAIGPT52.rawValue)
    }

    @Test("preferredCloudModel publishes through the observable mirror so pickers refresh")
    @MainActor func setPreferredCloudModelUpdatesObservableMirror() {
        let inference = InferenceState(
            keychainLoad: { key in
                key == CloudModelProvider.openAI.apiKeyKeychainKey ? "sk-test" : nil
            },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        // Seed a mid-tier preference, then flip to GPT-5.4 and assert
        // the observable mirror reflects it immediately (the bug was
        // picker reads going to UserDefaults without @Observable signal).
        inference.setPreferredCloudModel(.openAIGPT52)
        inference.setPreferredCloudModel(.openAIGPT54)

        #expect(inference.observedPreferredCloudModels[.openAI] == .openAIGPT54)
        #expect(inference.preferredCloudModel(for: .openAI) == .openAIGPT54)
    }

    @Test("chatReasoningTier persists across inference state reloads")
    @MainActor func chatReasoningTierPersistsAcrossReloads() {
        let defaults = UserDefaults.standard
        let key = "epistemos.chatReasoningTier"
        let savedValue = defaults.object(forKey: key)
        defer {
            if let savedValue {
                defaults.set(savedValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.removeObject(forKey: key)

        let first = InferenceState(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        // Default is `.medium` — the post-refactor middle tier,
        // equivalent to the old "Standard".
        #expect(first.chatReasoningTier == .medium)

        first.setChatReasoningTier(.heavy)

        let reloaded = InferenceState(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        #expect(reloaded.chatReasoningTier == .heavy)
    }

    @Test("effectiveModelLabel resolves Apple Intelligence to user-visible text")
    @MainActor func effectiveModelLabelResolvesAppleIntelligence() {
        let inference = InferenceState(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        inference.setPreferredChatModelSelection(.appleIntelligence)
        #expect(inference.effectiveModelLabel(for: .fast) == "Apple Intelligence")
    }

    @Test("effectiveModelLabel returns non-empty text for every operating mode")
    @MainActor func effectiveModelLabelAlwaysReturnsNonEmpty() {
        let inference = InferenceState(
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        for mode: EpistemosOperatingMode in [.fast, .thinking, .pro, .agent] {
            let label = inference.effectiveModelLabel(for: mode)
            #expect(!label.isEmpty, "label was empty for mode=\(mode)")
        }
    }

    @Test("effectiveModelLabel reflects Codex and Claude Code runtimes when account sessions back the model")
    @MainActor func effectiveModelLabelReflectsProviderNativeCodingRuntime() throws {
        let expiration = Date(timeIntervalSince1970: 1_888_888_888)
        let openAICredential = CloudProviderOAuthCredential(
            provider: .openAI,
            accessToken: "openai-access-token",
            refreshToken: "openai-refresh",
            expiresAt: expiration,
            clientID: OpenAICodexRuntimeMetadata.clientID,
            clientSecret: nil,
            projectID: nil,
            authMode: .openAICodex,
            accountLabel: "chatgpt@example.com"
        )
        let anthropicCredential = CloudProviderOAuthCredential(
            provider: .anthropic,
            accessToken: "anthropic-access-token",
            refreshToken: "anthropic-refresh",
            expiresAt: expiration,
            clientID: "claude-code-client",
            clientSecret: nil,
            projectID: nil,
            authMode: .anthropicClaudeCode,
            accountLabel: "claude@example.com"
        )
        let openAIEncoded = try #require(
            String(data: JSONEncoder().encode(openAICredential), encoding: .utf8)
        )
        let anthropicEncoded = try #require(
            String(data: JSONEncoder().encode(anthropicCredential), encoding: .utf8)
        )

        let inference = makeIsolatedInferenceState(
            keychainLoad: { key in
                switch key {
                case CloudModelProvider.openAI.oauthKeychainKey:
                    openAIEncoded
                case CloudModelProvider.anthropic.oauthKeychainKey:
                    anthropicEncoded
                default:
                    nil
                }
            },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )

        inference.setPreferredChatModelSelection(ChatModelSelection.cloud(CloudTextModelID.openAIGPT54))
        #expect(inference.effectiveModelLabel(for: EpistemosOperatingMode.agent) == "Codex GPT-5.4")
        #expect(
            inference.availableReasoningTiers(for: EpistemosOperatingMode.agent)
                == [.low, .medium, .high, .heavy]
        )
        #expect(
            inference.reasoningTierLabel(
                for: .heavy,
                operatingMode: EpistemosOperatingMode.agent
            ) == "Extra High"
        )

        inference.setPreferredChatModelSelection(
            ChatModelSelection.cloud(CloudTextModelID.anthropicClaudeSonnet46)
        )
        #expect(
            inference.effectiveModelLabel(for: EpistemosOperatingMode.agent)
                == "Claude Code Claude Sonnet 4.6"
        )
        #expect(
            inference.reasoningTierLabel(
                for: .heavy,
                operatingMode: EpistemosOperatingMode.agent
            ) == "Max"
        )
    }
}

@Suite("InferencePolicyEngine")
struct InferencePolicyEngineTests {

    @Test("auto mode uses Apple Intelligence for lightweight rewrite work")
    func autoUsesAppleForLightRewrite() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .noteChat,
                intent: .rewrite,
                contentLength: 240,
                promptLength: 180,
                contextBlockCount: 1,
                estimatedTokenLoad: 120,
                baseComplexity: 0.25,
                queryComplexity: 0.05,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: true,
                preferredChatModelSelection: .appleIntelligence
            )
        )

        #expect(decision.selectedRoute == .appleIntelligence)
    }

    @Test("heavier local work keeps the selected local tier")
    func heavierLocalWorkPicksBalancedTier() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .coding,
                contentLength: 2_400,
                promptLength: 2_200,
                contextBlockCount: 3,
                estimatedTokenLoad: 900,
                baseComplexity: 0.35,
                queryComplexity: 0.40,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: true,
                installed: [
                    .qwen35_2B4Bit,
                    .qwen35_4B4Bit,
                ]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.localSelection?.modelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(decision.localSelection?.reasoningMode == .fast)
    }

    @Test("explicit deep reasoning request keeps the local response mode in thinking")
    func explicitThinkingKeepsLocalThinkingMode() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .graph,
                intent: .graphAnalysis,
                contentLength: 6_000,
                promptLength: 5_500,
                contextBlockCount: 6,
                estimatedTokenLoad: 2_400,
                baseComplexity: 0.60,
                queryComplexity: 0.55,
                operatingMode: .thinking,
                requestedReasoningMode: .thinking,
                explicitThinkingRequested: true,
                explicitFastRequested: false,
                visibleThinkingRequested: true
            ),
            context: makeContext(
                appleAvailable: true,
                installed: [
                    .qwen35_2B4Bit,
                    .qwen35_4B4Bit,
                ]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.localSelection?.reasoningMode == .thinking)
        #expect(!decision.reasonCodes.contains(.explicitThinkingRequested))
    }

    @Test("thinking panel visibility does not force trivial prompts into thinking mode")
    func thinkingPanelVisibilityDoesNotForceThinkingMode() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: 32,
                promptLength: 16,
                contextBlockCount: 0,
                estimatedTokenLoad: 8,
                baseComplexity: 0.10,
                queryComplexity: 0.01,
                operatingMode: .thinking,
                requestedReasoningMode: .thinking,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: true
            ),
            context: makeContext(
                appleAvailable: false,
                installed: [.qwen35_2B4Bit, .qwen35_4B4Bit]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.localSelection?.reasoningMode == .fast)
    }

    @Test("thinking panel visibility does not block Apple for trivial prompts")
    func thinkingPanelVisibilityDoesNotBlockApple() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: 24,
                promptLength: 24,
                contextBlockCount: 0,
                estimatedTokenLoad: 12,
                baseComplexity: 0.10,
                queryComplexity: 0.01,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: true
            ),
            context: makeContext(
                appleAvailable: true,
                preferredChatModelSelection: .appleIntelligence
            )
        )

        #expect(decision.selectedRoute == .appleIntelligence)
    }

    @Test("freeform chat keeps the selected local tier for trivial local asks")
    func freeformChatKeepsSelectedLocalTierForTrivialLocalAsks() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: 32,
                promptLength: 32,
                contextBlockCount: 0,
                estimatedTokenLoad: 16,
                baseComplexity: 0.10,
                queryComplexity: 0.01,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                installed: [.qwen35_0_8B4Bit, .qwen35_2B4Bit, .qwen35_4B4Bit]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.localSelection?.modelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
    }

    @Test("preferred local model stays fixed for lightweight local work")
    func preferredLocalModelStaysFixedForLightweightWork() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .summarize,
                contentLength: 480,
                promptLength: 440,
                contextBlockCount: 1,
                estimatedTokenLoad: 180,
                baseComplexity: 0.20,
                queryComplexity: 0.08,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: true,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                installed: [
                    .qwen35_2B4Bit,
                    .qwen35_4B4Bit,
                ]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.localSelection?.modelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(!decision.reuseWarmModel)
    }

    @Test("explicit local selection survives cloud auto-route for local turns")
    func explicitLocalSelectionSurvivesCloudAutoRouteForLocalTurns() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: 120,
                promptLength: 96,
                contextBlockCount: 0,
                estimatedTokenLoad: 48,
                baseComplexity: 0.20,
                queryComplexity: 0.02,
                operatingMode: .thinking,
                requestedReasoningMode: .thinking,
                explicitThinkingRequested: true,
                explicitFastRequested: false,
                visibleThinkingRequested: true
            ),
            context: makeContext(
                appleAvailable: false,
                cloudAutoRouteEnabled: true,
                hasConfiguredCloudModels: true,
                preferredChatModelSelection: .localMLX(LocalTextModelID.qwen3_4B4Bit.rawValue),
                preferredLocalTextModelID: .qwen3_4B4Bit,
                installed: [.deepseekR1Distill7B, .qwen3_4B4Bit]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.localSelection?.modelID == LocalTextModelID.qwen3_4B4Bit.rawValue)
        #expect(decision.localSelection?.reasoningMode == .thinking)
        #expect(!decision.reasonCodes.contains(.cloudAutoRoute))
    }

    @Test("local only bypasses Apple Intelligence even for trivial work")
    func localOnlyBypassesApple() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .noteChat,
                intent: .rewrite,
                contentLength: 200,
                promptLength: 140,
                contextBlockCount: 1,
                estimatedTokenLoad: 100,
                baseComplexity: 0.25,
                queryComplexity: 0.05,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                routingMode: .localOnly,
                appleAvailable: true,
                installed: [.qwen35_2B4Bit]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.reasonCodes.contains(.localModeForced))
    }

    @Test("local only overrides an explicit Apple chat selection")
    func localOnlyOverridesExplicitAppleSelection() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .noteChat,
                intent: .rewrite,
                contentLength: 180,
                promptLength: 120,
                contextBlockCount: 1,
                estimatedTokenLoad: 90,
                baseComplexity: 0.25,
                queryComplexity: 0.04,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                routingMode: .localOnly,
                appleAvailable: true,
                preferredChatModelSelection: .appleIntelligence,
                installed: [.qwen35_4B4Bit]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.reasonCodes.contains(.localModeForced))
    }

    @Test("constrained runtime keeps the selected local tier")
    func constrainedRuntimeDownshiftsTier() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .coding,
                contentLength: 2_000,
                promptLength: 1_900,
                contextBlockCount: 2,
                estimatedTokenLoad: 700,
                baseComplexity: 0.35,
                queryComplexity: 0.35,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                installed: [
                    .qwen35_2B4Bit,
                    .qwen35_4B4Bit,
                ],
                runtimeConditions: LocalRuntimeConditions(
                    lowPowerModeEnabled: true,
                    appActive: false,
                    thermalState: .serious
                )
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.localSelection?.modelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(decision.reasonCodes.contains(.preferredLocalModelUsed))
    }

    @Test("light Apple requests are not kicked local solely for crossing the old content cliff")
    func lightAppleRequestsDoNotTripOldContentCliff() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: 6_100,
                promptLength: 48,
                contextBlockCount: 1,
                estimatedTokenLoad: 180,
                baseComplexity: 0.10,
                queryComplexity: 0.02,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: true,
                preferredChatModelSelection: .appleIntelligence
            )
        )

        #expect(decision.selectedRoute == .appleIntelligence)
    }

    @Test("auto cloud routing escalates pro chat to cloud when configured")
    func autoCloudRoutingEscalatesProChat() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .coding,
                contentLength: 1_400,
                promptLength: 1_200,
                contextBlockCount: 2,
                estimatedTokenLoad: 420,
                baseComplexity: 0.35,
                queryComplexity: 0.28,
                operatingMode: .pro,
                requestedReasoningMode: .thinking,
                explicitThinkingRequested: true,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                cloudAutoRouteEnabled: true,
                hasConfiguredCloudModels: true,
                preferredChatModelSelection: .appleIntelligence
            )
        )

        #expect(decision.selectedRoute == .cloud)
        #expect(decision.reasonCodes.contains(.cloudAutoRoute))
    }

    @Test("auto cloud routing still keeps fast chat local first")
    func autoCloudRoutingKeepsFastChatLocal() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: 48,
                promptLength: 48,
                contextBlockCount: 1,
                estimatedTokenLoad: 16,
                baseComplexity: 0.10,
                queryComplexity: 0.02,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: true,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                cloudAutoRouteEnabled: true,
                hasConfiguredCloudModels: true
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(!decision.reasonCodes.contains(.cloudAutoRoute))
    }

    @Test("auto fast coding routes to cloud when only unsafe or unsupported local fallbacks remain")
    func autoFastCodingRoutesToCloudWhenNoSafeLocalFallbackRemains() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .coding,
                contentLength: 1_800,
                promptLength: 1_500,
                contextBlockCount: 2,
                estimatedTokenLoad: 520,
                baseComplexity: 0.34,
                queryComplexity: 0.25,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                cloudAutoRouteEnabled: true,
                hasConfiguredCloudModels: true,
                preferredChatModelSelection: .appleIntelligence,
                installed: [
                    .gemma4_4B4Bit,
                    .deepseekR1Distill7B,
                    .qwen25Coder7B,
                    .gemma4_27BA4B4Bit,
                    .qwen36_35BA3B4Bit,
                ]
            )
        )

        #expect(decision.selectedRoute == .cloud)
        #expect(decision.localSelection == nil)
        #expect(decision.reasonCodes.contains(.cloudAutoRoute))
    }

    @Test("auto local routing picks the reasoning specialist for thinking work when available")
    func autoLocalRoutingPrefersReasonerForThinkingWork() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .graph,
                intent: .graphAnalysis,
                contentLength: 4_200,
                promptLength: 4_000,
                contextBlockCount: 5,
                estimatedTokenLoad: 1_600,
                baseComplexity: 0.52,
                queryComplexity: 0.40,
                operatingMode: .thinking,
                requestedReasoningMode: .thinking,
                explicitThinkingRequested: true,
                explicitFastRequested: false,
                visibleThinkingRequested: true
            ),
            context: makeContext(
                appleAvailable: false,
                cloudAutoRouteEnabled: true,
                hasConfiguredCloudModels: true,
                installed: [
                    .gemma4_4B4Bit,
                    .deepseekR1Distill7B,
                    .qwen25Coder7B,
                    .gemma4_27BA4B4Bit,
                    .qwen36_35BA3B4Bit,
                ]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.localSelection?.modelID == LocalTextModelID.deepseekR1Distill7B.rawValue)
        #expect(decision.localSelection?.reasoningMode == .thinking)
    }

    @Test("auto local routing promotes the compact qwen thinking tier before generic fallbacks")
    func autoLocalRoutingPrefersQwenThinkingCheckpointWhenDeepSeekIsAbsent() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .noteChat,
                intent: .noteAnalysis,
                contentLength: 3_400,
                promptLength: 2_900,
                contextBlockCount: 3,
                estimatedTokenLoad: 1_200,
                baseComplexity: 0.48,
                queryComplexity: 0.24,
                operatingMode: .thinking,
                requestedReasoningMode: .thinking,
                explicitThinkingRequested: true,
                explicitFastRequested: false,
                visibleThinkingRequested: true
            ),
            context: makeContext(
                appleAvailable: false,
                installed: [.qwen3_8B4Bit, .qwen3_4BThinking25074Bit, .gemma3_4BQAT4Bit]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.localSelection?.modelID == LocalTextModelID.qwen3_4BThinking25074Bit.rawValue)
        #expect(decision.localSelection?.reasoningMode == .thinking)
    }

    @Test("auto local routing uses Bonsai as the fast fallback when Gemma is absent")
    func autoLocalRoutingUsesBonsaiFallbackWhenGemmaMissing() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: 48,
                promptLength: 44,
                contextBlockCount: 1,
                estimatedTokenLoad: 18,
                baseComplexity: 0.10,
                queryComplexity: 0.02,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: true,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                installed: [.bonsai4B2Bit, .bonsai8B2Bit]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.localSelection?.modelID == LocalTextModelID.bonsai4B2Bit.rawValue)
    }

    @Test("auto local routing uses llama 3.2 for lightweight fast work before larger 16GB tiers")
    func autoLocalRoutingUsesLlamaForLightFastWork() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: 96,
                promptLength: 84,
                contextBlockCount: 1,
                estimatedTokenLoad: 40,
                baseComplexity: 0.12,
                queryComplexity: 0.04,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: true,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                installed: [.llama32_3BInstruct4Bit, .qwen3_8B4Bit, .gemma3_4BQAT4Bit]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.localSelection?.modelID == LocalTextModelID.llama32_3BInstruct4Bit.rawValue)
        #expect(decision.localSelection?.reasoningMode == .fast)
    }

    @Test("auto local routing prefers a non-Gemma fallback for general pro work (Gemma 4 excluded until loader ships)")
    func autoLocalRoutingPrefersFlagshipForGeneralProWork() {
        // Gemma 4 family was removed from TriageService.preferredOrder (and
        // the shipped-fallback) in the 2026-04-18 fix because the
        // MLX-Swift-LM Gemma 4 decoder isn't yet implemented — the old
        // expected-gemma4 behavior caused user-visible "Unsupported model
        // type: gemma4" errors on routed turns. With Gemma 4 demoted,
        // DeepSeek R1 7B is the preferred .pro-synthesis pick that fits
        // inside this test's 18GB hardware snapshot (qwen36_35BA3B4Bit is
        // filtered by supportedInstalledModels on 18GB). Installed list
        // keeps gemma4_27BA4B4Bit to prove the filter actually excludes
        // it when an alternative is available. When MLX-Swift-LM ships
        // a real Gemma 4 config decoder, restore Gemma 4 to preferredOrder
        // at the top of preferredAutomaticLocalModel and revert this.
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .synthesis,
                contentLength: 3_000,
                promptLength: 2_600,
                contextBlockCount: 4,
                estimatedTokenLoad: 1_100,
                baseComplexity: 0.48,
                queryComplexity: 0.28,
                operatingMode: .pro,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                installed: [.gemma4_27BA4B4Bit, .qwen36_35BA3B4Bit, .deepseekR1Distill7B]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.localSelection?.modelID != LocalTextModelID.gemma4_27BA4B4Bit.rawValue)
        #expect(decision.localSelection?.modelID != LocalTextModelID.gemma4_4B4Bit.rawValue)
    }

    @Test("auto local routing uses qwen 3 8B as the 16GB generalist pro tier when the flagship stack is absent")
    func autoLocalRoutingUsesQwen38BForGeneralProWork() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .synthesis,
                contentLength: 2_800,
                promptLength: 2_100,
                contextBlockCount: 3,
                estimatedTokenLoad: 920,
                baseComplexity: 0.46,
                queryComplexity: 0.26,
                operatingMode: .pro,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                installed: [.qwen3_8B4Bit, .deepseekR1Distill7B, .gemma3_4BQAT4Bit]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.localSelection?.modelID == LocalTextModelID.qwen3_8B4Bit.rawValue)
        #expect(decision.localSelection?.reasoningMode == .fast)
    }

    @Test("interactive routing treats oversized qwen tiers as unavailable on 18GB machines")
    func autoLocalRoutingTreatsOversizedQwenAsUnavailableOn18GBMachines() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .synthesis,
                contentLength: 2_400,
                promptLength: 1_400,
                contextBlockCount: 2,
                estimatedTokenLoad: 600,
                baseComplexity: 0.32,
                queryComplexity: 0.18,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                preferredChatModelSelection: .appleIntelligence,
                installed: [.qwen35_35BA3B4Bit]
            )
        )

        #expect(decision.localSelection == nil)
        #expect(decision.reasonCodes.contains(.noInstalledLocalModel))
    }

    @Test("fast local routing avoids always-thinking DeepSeek when a non-thinking fast tier is available")
    func fastLocalRoutingAvoidsAlwaysThinkingDeepSeek() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .synthesis,
                contentLength: 2_600,
                promptLength: 2_200,
                contextBlockCount: 3,
                estimatedTokenLoad: 900,
                baseComplexity: 0.34,
                queryComplexity: 0.24,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: true,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                installed: [.deepseekR1Distill7B, .qwen3_4B4Bit]
            )
        )

        #expect(decision.selectedRoute == .localMLX)
        #expect(decision.localSelection?.reasoningMode == .fast)
        #expect(decision.localSelection?.modelID == LocalTextModelID.qwen3_4B4Bit.rawValue)
    }

    @Test("preferred local selection skips fast-incompatible pinned model")
    func preferredLocalSelectionSkipsFastIncompatiblePinnedModel() {
        let engine = InferencePolicyEngine()

        let selection = engine.resolvedPreferredLocalSelection(
            in: makeContext(
                appleAvailable: false,
                preferredChatModelSelection: .localMLX(LocalTextModelID.deepseekR1Distill7B.rawValue),
                preferredLocalTextModelID: LocalTextModelID.deepseekR1Distill7B,
                installed: [.deepseekR1Distill7B]
            ),
            reasoningMode: .fast
        )

        #expect(selection == nil)
    }

    @Test("fast local routing refuses always-thinking fallback models when no fast-safe local tier exists")
    func fastLocalRoutingRefusesAlwaysThinkingFallbacks() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: 120,
                promptLength: 90,
                contextBlockCount: 1,
                estimatedTokenLoad: 80,
                baseComplexity: 0.12,
                queryComplexity: 0.08,
                operatingMode: .fast,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: true,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                cloudAutoRouteEnabled: true,
                hasConfiguredCloudModels: true,
                installed: [.deepseekR1Distill7B]
            )
        )

        #expect(decision.selectedRoute == .cloud)
        #expect(decision.localSelection == nil)
        #expect(decision.reasonCodes.contains(.cloudAutoRoute))
    }

    private func makeContext(
        routingMode: LocalRoutingMode = .auto,
        appleAvailable: Bool,
        cloudAutoRouteEnabled: Bool = false,
        hasConfiguredCloudModels: Bool = false,
        preferredChatModelSelection: ChatModelSelection = .localMLX(LocalTextModelID.qwen35_4B4Bit.rawValue),
        preferredLocalTextModelID: LocalTextModelID = .qwen35_4B4Bit,
        installed: [LocalTextModelID] = [.qwen35_2B4Bit, .qwen35_4B4Bit],
        runtimeConditions: LocalRuntimeConditions = LocalRuntimeConditions(
            lowPowerModeEnabled: false,
            appActive: true,
            thermalState: .nominal
        )
    ) -> InferencePolicyContext {
        InferencePolicyContext(
            routingMode: routingMode,
            appleIntelligenceAvailable: appleAvailable,
            cloudAutoRouteEnabled: cloudAutoRouteEnabled,
            hasConfiguredCloudModels: hasConfiguredCloudModels,
            preferredChatModelSelection: preferredChatModelSelection,
            preferredLocalTextModelID: preferredLocalTextModelID.rawValue,
            installedLocalTextModelIDs: Set(installed.map(\.rawValue)),
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 18_000_000_000,
                roundedMemoryGB: 18,
                maxRecommendedLocalContentLength: 8_000
            ),
            runtimeConditions: runtimeConditions
        )
    }
}

@Suite("Overseer Complexity Router")
struct OverseerComplexityRouterTests {
    @Test("simple main chat stays local only with no tool budget")
    @MainActor func simpleMainChatStaysLocalOnly() {
        let inference = makeIsolatedInferenceState(
            hardwareCapabilitySnapshot: ggufCapableTestHardwareSnapshot
        )
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3_8B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen3_8B4Bit.rawValue)
        inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen3_8B4Bit.rawValue))

        let router = OverseerComplexityRouter(inference: inference)
        let executionPlan = router.planForMainChat(
            query: "Explain determinism in one concise paragraph.",
            contentLength: 43,
            operatingMode: .fast,
            hasExplicitContext: false,
            attachmentCount: 0,
            notesContext: nil,
            conversationHistory: nil
        )

        #expect(executionPlan.route == .localOnly)
        #expect(executionPlan.localOperatingMode == .fast)
        #expect(executionPlan.plan.route == .localOnly)
        #expect(executionPlan.plan.depthBudget.maxToolCalls == 0)
        #expect(executionPlan.plan.toolPermissions.isEmpty)
    }

    @Test("complex coding chat produces an overseer local execution plan")
    @MainActor func complexCodingChatProducesOverseerLocalExecutionPlan() {
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3CoderNext4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen3CoderNext4Bit.rawValue)

        let router = OverseerComplexityRouter(inference: inference)
        let executionPlan = router.planForMainChat(
            query: "Review this Swift and Rust architecture, identify the migration risks, then use the vault and search tools only if needed to propose the safest execution order.",
            contentLength: 3_400,
            operatingMode: .agent,
            hasExplicitContext: true,
            attachmentCount: 2,
            notesContext: "Architecture context",
            conversationHistory: "User: Keep this local-first."
        )

        #expect(executionPlan.route == .overseerLocalExecution)
        #expect(executionPlan.localOperatingMode == .agent)
        #expect(executionPlan.plan.route == .overseerLocalExecution)
        #expect(executionPlan.plan.depthBudget.maxToolCalls > 0)
        #expect(executionPlan.plan.maskPlan.expertAllowlist.contains("reasoning.code"))
        #expect(executionPlan.plan.toolPermissions.contains(where: { $0.mode == .allow || $0.mode == .ask }))
    }

    @Test("drive scale monitoring escalates to a managed agent session")
    @MainActor func driveScaleMonitoringEscalatesToManagedAgentSession() {
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3CoderNext4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen3CoderNext4Bit.rawValue)

        let router = OverseerComplexityRouter(inference: inference)
        let executionPlan = router.planForMainChat(
            query: "Watch Gmail, Calendar, Drive, Reddit, and Twitter/X for a few hours, summarize everything important, and keep iterating until you have a final executive briefing.",
            contentLength: 7_200,
            operatingMode: .agent,
            hasExplicitContext: true,
            attachmentCount: 4,
            notesContext: "Workspace dossier",
            conversationHistory: "User: this can run for a while."
        )

        #expect(executionPlan.route == .managedAgentSession)
        #expect(executionPlan.plan.route == .managedAgentSession)
        #expect(executionPlan.plan.depthBudget.maxTurns >= 10)
        #expect(executionPlan.plan.depthBudget.maxToolCalls >= 8)
        #expect(!executionPlan.plan.toolPermissions.isEmpty)
        #expect(executionPlan.allowedToolNames.contains("search_web"))
        #expect(executionPlan.allowedToolNames.contains("write_file"))
    }

    @Test("cloud file-path reads escalate to a managed tools session")
    @MainActor func cloudFilePathReadsEscalateToManagedAgentSession() {
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3_8B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen3_8B4Bit.rawValue)
        inference.setPreferredChatModelSelection(.cloud(.openAIGPT54))

        let router = OverseerComplexityRouter(inference: inference)
        let executionPlan = router.planForMainChat(
            query: "Use tools to read the local file /tmp/epistemos-audit/out_of_vault_read.txt and tell me its first line exactly.",
            contentLength: 109,
            operatingMode: .thinking,
            hasExplicitContext: false,
            attachmentCount: 0,
            notesContext: nil,
            conversationHistory: nil
        )

        #expect(executionPlan.route == .managedAgentSession)
        #expect(executionPlan.plan.route == .managedAgentSession)
        #expect(executionPlan.allowedToolNames.contains("read_file"))
    }

    @Test("cloud note-seeking turns with resolved vault context escalate to a managed tools session")
    @MainActor func cloudNoteSeekingTurnsWithResolvedVaultContextEscalateToManagedAgentSession() {
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3_8B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen3_8B4Bit.rawValue)
        inference.setPreferredChatModelSelection(.cloud(.openAIGPT54))

        let router = OverseerComplexityRouter(inference: inference)
        let executionPlan = router.planForMainChat(
            query: "read my essay on determinism and summarize it",
            contentLength: 44,
            operatingMode: .thinking,
            hasExplicitContext: true,
            attachmentCount: 0,
            notesContext: "Resolved note context",
            conversationHistory: nil
        )

        #expect(executionPlan.route == .managedAgentSession)
        #expect(executionPlan.plan.route == .managedAgentSession)
        #expect(
            executionPlan.allowedToolNames.contains("vault_read") ||
            executionPlan.allowedToolNames.contains("readpagecontent")
        )
    }

    @Test("cloud essay lookup turns escalate to a managed tools session before note resolution")
    @MainActor func cloudEssayLookupTurnsEscalateToManagedAgentSessionBeforeResolution() {
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3_8B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen3_8B4Bit.rawValue)
        inference.setPreferredChatModelSelection(.cloud(.openAIGPT54))

        let router = OverseerComplexityRouter(inference: inference)
        let executionPlan = router.planForMainChat(
            query: "read my essay on determinism and summarize it",
            contentLength: 44,
            operatingMode: .thinking,
            hasExplicitContext: false,
            attachmentCount: 0,
            notesContext: nil,
            conversationHistory: nil
        )

        #expect(executionPlan.route == .managedAgentSession)
        #expect(executionPlan.plan.route == .managedAgentSession)
        #expect(
            executionPlan.allowedToolNames.contains("vault_search") ||
            executionPlan.allowedToolNames.contains("list_notes")
        )
        #expect(
            executionPlan.allowedToolNames.contains("vault_read") ||
            executionPlan.allowedToolNames.contains("readpagecontent")
        )
    }

    @Test("agent route uses a hidden local agent tier when no release-visible chat tier is available")
    @MainActor func agentRouteUsesHiddenLocalAgentTierWhenNeeded() {
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let router = OverseerComplexityRouter(inference: inference)
        let executionPlan = router.planForMainChat(
            query: "Review this Swift architecture, use the vault tools if needed, and propose the safest local execution plan.",
            contentLength: 2_600,
            operatingMode: .agent,
            hasExplicitContext: true,
            attachmentCount: 1,
            notesContext: "Architecture context",
            conversationHistory: "User: keep this local if possible."
        )

        #expect(inference.effectiveLocalTextModelID == nil)
        #expect(inference.effectiveLocalAgentTextModelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(executionPlan.route == .overseerLocalExecution)
        #expect(executionPlan.plan.route == .overseerLocalExecution)
    }

    @Test("explicit agent mode does not downgrade simple asks into local-only chat")
    @MainActor func explicitAgentModeDoesNotDowngradeSimpleAsks() {
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3CoderNext4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen3CoderNext4Bit.rawValue)

        let router = OverseerComplexityRouter(inference: inference)
        let executionPlan = router.planForMainChat(
            query: "What changed in this note?",
            contentLength: 25,
            operatingMode: .agent,
            hasExplicitContext: false,
            attachmentCount: 0,
            notesContext: nil,
            conversationHistory: nil
        )

        #expect(executionPlan.route == .overseerLocalExecution)
        #expect(executionPlan.localOperatingMode == .agent)
        #expect(executionPlan.plan.route == .overseerLocalExecution)
        #expect(executionPlan.plan.depthBudget.maxToolCalls > 0)
        #expect(!executionPlan.plan.toolPermissions.isEmpty)
    }

    @Test("ask tools use native approval instead of typed approval phrases")
    @MainActor func askToolsUseNativeApprovalInsteadOfTypedApprovalPhrases() {
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3_8B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen3_8B4Bit.rawValue)
        inference.setPreferredChatModelSelection(.cloud(.openAIGPT54))

        let router = OverseerComplexityRouter(inference: inference)
        let executionPlan = router.planForMainChat(
            query: "Research hegemony from political, cultural, and social theory, then write a manifesto.",
            contentLength: 96,
            operatingMode: .fast,
            hasExplicitContext: false,
            attachmentCount: 0,
            notesContext: nil,
            conversationHistory: nil
        )

        let prompt = executionPlan.additionalSystemPrompt()
        let prohibitedTypedApprovalPhrase = ["approve", "web search"].joined(separator: " ")
        let obsoleteAskToolPrompt = [
            "Treat any tool marked ask as requiring human approval",
            "before sensitive reads or writes.",
        ].joined(separator: " ")
        #expect(executionPlan.route == .managedAgentSession)
        #expect(prompt.contains("call the tool anyway; Epistemos will show the native approval card"))
        #expect(prompt.contains("Do not ask the user to type an approval phrase"))
        #expect(!prompt.contains(obsoleteAskToolPrompt))
        #expect(!prompt.contains(prohibitedTypedApprovalPhrase))
    }
}

@MainActor
final class TriageIntegrationMockLLMClient: LLMClientProtocol {
    var generateCalls: [(prompt: String, systemPrompt: String?, maxTokens: Int)] = []
    var streamCalls: [(prompt: String, systemPrompt: String?, maxTokens: Int)] = []

    var generateResult: Result<String, Error> = .success("mock-generate")
    var streamTokens: [String] = ["mock-stream"]
    var streamError: (any Error)?

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        generateCalls.append((prompt, systemPrompt, maxTokens))
        switch generateResult {
        case .success(let output):
            return output
        case .failure(let error):
            throw error
        }
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        streamCalls.append((prompt, systemPrompt, maxTokens))
        let tokens = streamTokens
        let error = streamError

        return AsyncThrowingStream { continuation in
            Task {
                for token in tokens {
                    continuation.yield(token)
                }
                if let error {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(
            provider: .localMLX,
            model: LocalTextModelID.qwen35_4B4Bit.rawValue,
            reasoningMode: .fast
        )
    }

}

@MainActor
final class TriageIntegrationMockCloudLLMClient: LLMClientProtocol {
    var generateCalls: [(prompt: String, systemPrompt: String?, maxTokens: Int)] = []
    var streamCalls: [(prompt: String, systemPrompt: String?, maxTokens: Int)] = []

    var generateResult: Result<String, Error> = .success("mock-cloud-generate")
    var streamTokens: [String] = ["mock-cloud-stream"]

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        generateCalls.append((prompt, systemPrompt, maxTokens))
        switch generateResult {
        case .success(let output):
            return output
        case .failure(let error):
            throw error
        }
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        streamCalls.append((prompt, systemPrompt, maxTokens))
        let tokens = streamTokens
        return AsyncThrowingStream { continuation in
            Task {
                for token in tokens {
                    continuation.yield(token)
                }
                continuation.finish()
            }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(provider: .openAI, model: CloudTextModelID.openAIGPT54.vendorModelID, reasoningMode: .fast)
    }
}

@MainActor
final class RecordingConfigurableLocalLLMClient: LocalConfigurableLLMClient {
    struct GenerateRequest: Equatable {
        let prompt: String
        let systemPrompt: String?
        let maxTokens: Int
        let reasoningMode: LocalReasoningMode
        let modelID: String?
        let steeringHintsJSON: String?
    }

    struct StreamRequest: Equatable {
        let prompt: String
        let systemPrompt: String?
        let maxTokens: Int
        let reasoningMode: LocalReasoningMode
        let modelID: String?
        let steeringHintsJSON: String?
    }

    var generateRequests: [GenerateRequest] = []
    var streamRequests: [StreamRequest] = []
    var generateResult = "mock-generate"

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast,
            modelID: nil
        )
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast,
            modelID: nil
        )
    }

    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
    ) async throws -> String {
        generateRequests.append(
            GenerateRequest(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                modelID: modelID,
                steeringHintsJSON: steeringHintsJSON
            )
        )
        return generateResult
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?,
        steeringHintsJSON: String?
    ) -> AsyncThrowingStream<String, Error> {
        streamRequests.append(
            StreamRequest(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                modelID: modelID,
                steeringHintsJSON: steeringHintsJSON
            )
        )
        return AsyncThrowingStream<String, Error> { continuation in
            continuation.finish()
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(provider: .localMLX, model: "", reasoningMode: .fast)
    }
}

@Suite("TriageService Integration", .serialized)
struct TriageServiceIntegrationTests {

    @Test("notes triage uses Apple Intelligence for simple transforms in Auto mode")
    @MainActor func notesSimpleOperationsUseAppleIntelligence() {
        let triage = makeService(appleAvailable: true)

        #expect(triage.triage(operation: .grammarFix, contentLength: 240) == .appleIntelligence)
        #expect(triage.triage(operation: .summarize, contentLength: 240) == .appleIntelligence)
        #expect(triage.triage(operation: .rewrite, contentLength: 240) == .appleIntelligence)
        #expect(triage.triage(operation: .ask(query: "What is the core point of this note?"), contentLength: 240) == .appleIntelligence)
    }

    @Test("notes triage uses local qwen for deeper work")
    @MainActor func notesComplexOperationsUseLocal() {
        let triage = makeService(
            appleAvailable: true,
            localInstalled: [LocalTextModelID.qwen3_4B4Bit.rawValue]
        )

        #expect(triage.triage(operation: .continueWriting, contentLength: 1_000) == .localMLX)
        #expect(triage.triage(operation: .analyze, contentLength: 2_000) == .localMLX)
        #expect(triage.triage(operation: .expand, contentLength: 4_000) == .localMLX)
    }

    @Test("Apple unavailable routes notes work to local qwen")
    @MainActor func notesAppleUnavailableUsesLocal() {
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [LocalTextModelID.qwen3_4B4Bit.rawValue]
        )

        #expect(triage.triage(operation: .grammarFix, contentLength: 100) == .localMLX)
    }

    @Test("general brainstorm uses Apple Intelligence for lightweight work")
    @MainActor func generalBrainstormUsesAppleIntelligence() {
        let triage = makeService(appleAvailable: true)
        #expect(triage.triageGeneral(operation: .brainstorm, contentLength: 500) == .appleIntelligence)
    }

    @Test("general higher-complexity work uses local qwen")
    @MainActor func generalComplexUsesLocal() {
        let triage = makeService(
            appleAvailable: true,
            localInstalled: [LocalTextModelID.qwen3_4B4Bit.rawValue]
        )

        #expect(
            triage.triageGeneral(
                operation: .chatResponse(query: "Compare Bayesian and evidential decision theory."),
                contentLength: 5_000
            ) == .localMLX
        )
    }

    @Test("local only bypasses Apple Intelligence")
    @MainActor func localOnlyForcesLocalQwen() {
        let triage = makeService(
            appleAvailable: true,
            localInstalled: [LocalTextModelID.qwen3_4B4Bit.rawValue],
            routingMode: .localOnly
        )

        #expect(triage.triage(operation: .grammarFix, contentLength: 100) == .localMLX)
        #expect(
            triage.triageGeneral(
                operation: .chatResponse(query: "Explain coherentism."),
                contentLength: 400
            ) == .localMLX
        )
    }

    @Test("direct triage calls do not mutate lastDecision")
    @MainActor func triageCallsDoNotMutateLastDecision() {
        let triage = makeService(appleAvailable: true)

        _ = triage.triage(operation: .grammarFix, contentLength: 50)
        _ = triage.triageGeneral(operation: .brainstorm, contentLength: 50)
        #expect(triage.lastDecision == nil)
    }

    @Test("notes generate uses local path and records maxTokens default")
    @MainActor func notesGenerateUsesLocalPath() async throws {
        let llm = TriageIntegrationMockLLMClient()
        llm.generateResult = .success("local-response")
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [triageInteractiveReleaseFixtureModelID.rawValue],
            localLLMService: llm
        )

        let output = try await triage.generate(
            prompt: "Prompt A",
            systemPrompt: "System A",
            operation: .analyze,
            contentLength: 1_800
        )

        #expect(output == "local-response")
        #expect(triage.lastDecision == .localMLX)
        #expect(llm.generateCalls.count == 1)
        #expect(llm.generateCalls[0].prompt == "Prompt A")
        let systemPrompt = try #require(llm.generateCalls[0].systemPrompt)
        #expect(systemPrompt.contains("local Epistemos assistant running on-device"))
        #expect(systemPrompt.contains("System A"))
        #expect(llm.generateCalls[0].maxTokens == 4096)
    }

    @Test("notes stream uses local path and yields all chunks")
    @MainActor func notesStreamUsesLocalPath() async {
        let llm = TriageIntegrationMockLLMClient()
        llm.streamTokens = ["alpha", " ", "beta"]
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [triageInteractiveReleaseFixtureModelID.rawValue],
            localLLMService: llm
        )

        let stream = triage.stream(
            prompt: "Prompt C",
            systemPrompt: "System C",
            operation: .expand,
            contentLength: 900
        )
        let outcome = await LocalRuntimeSmokeSupport.collect(stream)

        #expect(outcome.tokens == ["alpha", " ", "beta"])
        #expect(outcome.error == nil)
        #expect(triage.lastDecision == .localMLX)
        #expect(llm.streamCalls.count == 1)
        #expect(llm.streamCalls[0].maxTokens == 0)
    }

    @Test("local generate strips reasoning artifacts before returning assistant text")
    @MainActor func localGenerateStripsReasoningArtifacts() async throws {
        let llm = TriageIntegrationMockLLMClient()
        llm.generateResult = .success("""
        <think>I should inspect the framing.</think>

        Final Answer:
        Use the more constrained interpretation unless the note context defines the term explicitly.
        """)
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [triageInteractiveReleaseFixtureModelID.rawValue],
            routingMode: .localOnly,
            localLLMService: llm
        )

        let output = try await triage.generateGeneral(
            prompt: "Explain the phrase.",
            systemPrompt: nil,
            operation: .chatResponse(query: "Explain the phrase."),
            contentLength: 19
        )

        #expect(
            output == "Use the more constrained interpretation unless the note context defines the term explicitly."
        )
    }

    @Test("local stream suppresses thinking prelude and emits the final answer only")
    @MainActor func localStreamSuppressesThinkingPrelude() async {
        let llm = TriageIntegrationMockLLMClient()
        llm.streamTokens = [
            "Thinking Process:\n",
            "I should compare the historical and modern senses first.\n\n",
            "Final Answer:\n",
            "It usually refers to the modern US-led imperial order rather than the British Empire itself.",
        ]
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [triageInteractiveReleaseFixtureModelID.rawValue],
            routingMode: .localOnly,
            localLLMService: llm
        )

        let stream = triage.streamGeneral(
            prompt: "Explain the phrase.",
            systemPrompt: nil,
            operation: .chatResponse(query: "Explain the phrase."),
            contentLength: 19
        )
        let outcome = await LocalRuntimeSmokeSupport.collect(stream)

        #expect(
            outcome.tokens.joined()
                == "It usually refers to the modern US-led imperial order rather than the British Empire itself."
        )
        #expect(outcome.error == nil)
        let systemPrompt = try? #require(llm.streamCalls.first?.systemPrompt)
        #expect(systemPrompt?.contains("local Epistemos assistant running on-device") == true)
    }

    @Test("fast local stream injects a no-think directive into the baseline system prompt")
    @MainActor func fastLocalStreamInjectsNoThinkDirective() async {
        let llm = RecordingConfigurableLocalLLMClient()
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [triageInteractiveReleaseFixtureModelID.rawValue],
            routingMode: .localOnly,
            localLLMService: llm
        )

        let stream = triage.streamGeneral(
            prompt: "Answer directly.",
            systemPrompt: nil,
            operation: .chatResponse(query: "Answer directly."),
            contentLength: 16,
            operatingMode: .fast
        )
        _ = await LocalRuntimeSmokeSupport.collect(stream)

        let request = llm.streamRequests.first
        let systemPrompt = request?.systemPrompt
        #expect(systemPrompt?.contains("/no_think") == true)
    }

    @Test("thinking local stream instructs reasoning-capable models to hide reasoning in think tags")
    @MainActor func thinkingLocalStreamInjectsHiddenReasoningTagContract() async {
        let llm = RecordingConfigurableLocalLLMClient()
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [triageThinkingReleaseFixtureModelID.rawValue],
            routingMode: .localOnly,
            localLLMService: llm
        )

        let stream = triage.streamGeneral(
            prompt: "Analyze the essay.",
            systemPrompt: nil,
            operation: .chatResponse(query: "Analyze the essay."),
            contentLength: 64,
            operatingMode: .thinking
        )
        _ = await LocalRuntimeSmokeSupport.collect(stream)

        let systemPrompt = llm.streamRequests.first?.systemPrompt
        #expect(systemPrompt?.contains("emit that reasoning inside <think>...</think> tags") == true)
        #expect(systemPrompt?.contains("Put the final user-facing answer only after </think>.") == true)
    }

    @Test("local path injects a baseline local system prompt when none is provided")
    @MainActor func localPathInjectsBaselineLocalSystemPrompt() async throws {
        let llm = TriageIntegrationMockLLMClient()
        llm.generateResult = .success("local-response")
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [triageInteractiveReleaseFixtureModelID.rawValue],
            routingMode: .localOnly,
            localLLMService: llm
        )

        _ = try await triage.generateGeneral(
            prompt: "What tools do you have?",
            systemPrompt: nil,
            operation: .chatResponse(query: "What tools do you have?"),
            contentLength: 24
        )

        let systemPrompt = try #require(llm.generateCalls.first?.systemPrompt)
        #expect(
            systemPrompt.localizedCaseInsensitiveContains(
                "do not claim to have browsing, external tool use, research mode"
            )
        )
        #expect(systemPrompt.contains("local Epistemos assistant running on-device"))
    }

    @Test("local path adds model specific guidance for coding and multimodal tiers")
    @MainActor func localPathAddsModelSpecificGuidance() async throws {
        let codingLLM = RecordingConfigurableLocalLLMClient()
        let codingTriage = makeService(
            appleAvailable: false,
            localInstalled: [LocalTextModelID.qwen3CoderNext4Bit.rawValue],
            routingMode: .localOnly,
            localLLMService: codingLLM
        )

        _ = try await codingTriage.generateGeneral(
            prompt: "Fix the parser regression.",
            systemPrompt: nil,
            operation: .chatResponse(query: "Fix the parser regression."),
            contentLength: 26
        )

        let codingPrompt = try #require(codingLLM.generateRequests.first?.systemPrompt)
        #expect(codingPrompt.contains("Prioritize concrete, runnable code"))
        #expect(codingPrompt.contains("prefer structured tool use"))

        let multimodalLLM = RecordingConfigurableLocalLLMClient()
        let multimodalTriage = makeService(
            appleAvailable: false,
            localInstalled: [LocalTextModelID.gemma3_4BQAT4Bit.rawValue],
            routingMode: .localOnly,
            localLLMService: multimodalLLM
        )

        _ = try await multimodalTriage.generateGeneral(
            prompt: "Describe what is visible.",
            systemPrompt: nil,
            operation: .chatResponse(query: "Describe what is visible."),
            contentLength: 24
        )

        let multimodalPrompt = try #require(multimodalLLM.generateRequests.first?.systemPrompt)
        #expect(multimodalPrompt.contains("If image attachments are present"))
    }

    @Test("missing local model throws in local only mode")
    @MainActor func missingModelThrowsWhenLocalIsRequired() async {
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [],
            routingMode: .localOnly
        )

        await #expect(throws: LocalInferenceRoutingError.modelRequired) {
            try await triage.generateGeneral(
                prompt: "Explain coherentism.",
                operation: .chatResponse(query: "Explain coherentism."),
                contentLength: 200
            )
        }
    }

    @Test("triage refreshes local model state before local-only requests")
    @MainActor func triageRefreshesLocalModelStateBeforeLocalOnlyRequests() async throws {
        let llm = TriageIntegrationMockLLMClient()
        llm.generateResult = .success("local-response")
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([])
        inference.setPreferredLocalTextModelID(triageInteractiveReleaseFixtureModelID.rawValue)

        let triage = TriageService(
            inference: inference,
            localLLMService: llm,
            prepareForRouting: {
                inference.setInstalledLocalTextModelIDs([triageInteractiveReleaseFixtureModelID.rawValue])
            }
        )

        let result = try await triage.generateGeneral(
            prompt: "Summarize this note.",
            operation: .chatResponse(query: "Summarize this note."),
            contentLength: 64
        )

        #expect(result == "local-response")
        #expect(llm.generateCalls.count == 1)
    }

    @Test("explicit cloud selection bypasses Apple and local triage for general generation")
    @MainActor func explicitCloudSelectionBypassesAppleAndLocal() async throws {
        let store = TestKeychainStore(values: [
            CloudModelProvider.openAI.apiKeyKeychainKey: "test-openai-key",
        ])
        let cloud = TriageIntegrationMockCloudLLMClient()
        cloud.generateResult = .success("cloud answer")

        let triage = makeService(
            appleAvailable: true,
            localInstalled: [LocalTextModelID.qwen3_4B4Bit.rawValue],
            selectedChatModel: .cloud(.openAIGPT54),
            cloudLLMService: cloud,
            keychainStore: store
        )

        let result = try await triage.generateGeneral(
            prompt: "Use the cloud model",
            systemPrompt: "System",
            operation: .chatResponse(query: "Use the cloud model"),
            contentLength: 19
        )

        #expect(result == "cloud answer")
        #expect(cloud.generateCalls.count == 1)
        #expect(triage.lastDecision == .cloud)
    }

    @Test("notes pro mode can auto-route to the configured cloud provider")
    @MainActor func notesProModeCanAutoRouteToCloud() async {
        let store = TestKeychainStore(values: [
            CloudModelProvider.openAI.apiKeyKeychainKey: "test-openai-key",
        ])
        let inference = makeIsolatedInferenceState(keychainStore: store)
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([triageInteractiveReleaseFixtureModelID.rawValue])
        inference.setPreferredLocalTextModelID(triageInteractiveReleaseFixtureModelID.rawValue)
        inference.setPreferredChatModelSelection(.appleIntelligence)
        inference.setChatAutoRouteToCloud(true)

        let cloud = TriageIntegrationMockCloudLLMClient()
        cloud.streamTokens = ["cloud note answer"]

        let triage = TriageService(
            inference: inference,
            localLLMService: TriageIntegrationMockLLMClient(),
            cloudLLMService: cloud
        )

        let stream = triage.stream(
            prompt: "Current note body.\n\nRequest: Compare these arguments.",
            operation: .ask(query: "Compare these arguments."),
            contentLength: 72,
            query: "Compare these arguments.",
            operatingMode: .pro
        )
        let outcome = await LocalRuntimeSmokeSupport.collect(stream)

        #expect(outcome.error == nil)
        #expect(outcome.tokens.joined() == "cloud note answer")
        #expect(cloud.streamCalls.count == 1)
        #expect(triage.lastDecision == .cloud)
    }

    @Test("thinking chat routes through the effective cloud selection when no usable local tier remains")
    @MainActor func thinkingChatUsesEffectiveCloudSelectionWhenNoUsableLocalTierRemains() async {
        let store = TestKeychainStore(values: [
            CloudModelProvider.openAI.apiKeyKeychainKey: "test-openai-key",
        ])
        let inference = makeIsolatedInferenceState(keychainStore: store)
        inference.appleIntelligenceAvailable = false
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)
        inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen35_4B4Bit.rawValue))
        inference.setActiveAIProvider(.openAI)
        inference.setChatAutoRouteToCloud(true)

        #expect(inference.effectiveChatSurfaceSelection(for: .thinking) == .cloud(.openAIGPT54))

        let local = TriageIntegrationMockLLMClient()
        local.streamTokens = ["local fallback"]

        let cloud = TriageIntegrationMockCloudLLMClient()
        cloud.streamTokens = ["cloud answer"]

        let triage = TriageService(
            inference: inference,
            localLLMService: local,
            cloudLLMService: cloud
        )

        let stream = triage.streamGeneral(
            prompt: "Trace this carefully.",
            operation: .chatResponse(query: "Trace this carefully."),
            contentLength: 21,
            operatingMode: .thinking
        )
        let outcome = await LocalRuntimeSmokeSupport.collect(stream)

        #expect(outcome.error == nil)
        #expect(outcome.tokens.joined() == "cloud answer")
        #expect(cloud.streamCalls.count == 1)
        #expect(local.streamCalls.isEmpty)
        #expect(triage.lastDecision == .cloud)
    }

    @Test("cloud fallback chain starts with the active provider route and then configured backups")
    @MainActor func cloudFallbackChainOrdersConfiguredBackups() {
        let store = TestKeychainStore(values: [
            CloudModelProvider.openAI.apiKeyKeychainKey: "test-openai-key",
            CloudModelProvider.anthropic.apiKeyKeychainKey: "test-anthropic-key",
        ])
        let inference = makeIsolatedInferenceState(
            keychainLoad: store.load(_:),
            keychainSave: store.save(_:_:),
            keychainDelete: store.delete(_:)
        )

        inference.setPreferredChatModelSelection(.cloud(.openAIGPT54))

        #expect(inference.cloudFallbackChain(for: .fast) == [.openAIGPT54])
    }

    @Test("cloud generation fails fast when the selected provider access is missing")
    @MainActor func cloudGenerationFailsFastWhenProviderAccessIsMissing() async {
        let cloud = TriageIntegrationMockCloudLLMClient()
        let triage = makeService(
            appleAvailable: true,
            localInstalled: [LocalTextModelID.qwen3_4B4Bit.rawValue],
            selectedChatModel: .cloud(.openAIGPT54),
            cloudLLMService: cloud
        )

        do {
            _ = try await triage.generateGeneral(
                prompt: "Use the cloud model",
                systemPrompt: "System",
                operation: .chatResponse(query: "Use the cloud model"),
                contentLength: 19
            )
            Issue.record("Expected missing provider access error")
        } catch let error as CloudLLMError {
            switch error {
            case .missingAccess(let provider):
                #expect(provider == CloudModelProvider.openAI.displayName)
            default:
                Issue.record("Expected missingAccess, got \(error)")
            }
        } catch {
            Issue.record("Expected CloudLLMError, got \(error)")
        }

        #expect(cloud.generateCalls.isEmpty)
    }

    @Test("cloud streaming fails fast when the selected provider access is missing")
    @MainActor func cloudStreamingFailsFastWhenProviderAccessIsMissing() async {
        let cloud = TriageIntegrationMockCloudLLMClient()
        let triage = makeService(
            appleAvailable: true,
            localInstalled: [LocalTextModelID.qwen3_4B4Bit.rawValue],
            selectedChatModel: .cloud(.openAIGPT54),
            cloudLLMService: cloud
        )

        do {
            let stream = triage.streamGeneral(
                prompt: "Use the cloud model",
                systemPrompt: "System",
                operation: .chatResponse(query: "Use the cloud model"),
                contentLength: 19
            )
            for try await _ in stream {
                Issue.record("Expected stream to fail before yielding output")
            }
            Issue.record("Expected missing provider access error")
        } catch let error as CloudLLMError {
            switch error {
            case .missingAccess(let provider):
                #expect(provider == CloudModelProvider.openAI.displayName)
            default:
                Issue.record("Expected missingAccess, got \(error)")
            }
        } catch {
            Issue.record("Expected CloudLLMError, got \(error)")
        }

        #expect(cloud.streamCalls.isEmpty)
    }

    @Test("explicit local streaming bypasses the selected cloud model")
    @MainActor func explicitLocalStreamingBypassesSelectedCloudModel() async {
        let store = TestKeychainStore(values: [
            CloudModelProvider.openAI.apiKeyKeychainKey: "test-openai-key",
        ])
        let local = TriageIntegrationMockLLMClient()
        local.streamTokens = ["local", " answer"]

        let cloud = TriageIntegrationMockCloudLLMClient()
        cloud.streamTokens = ["cloud answer"]

        let triage = makeService(
            appleAvailable: true,
            localInstalled: [triageInteractiveReleaseFixtureModelID.rawValue],
            localLLMService: local,
            selectedChatModel: .cloud(.openAIGPT54),
            cloudLLMService: cloud,
            keychainStore: store
        )

        let stream = triage.streamGeneralLocally(
            prompt: "Use the local runtime",
            systemPrompt: "Follow the local overseer plan.",
            operation: .chatResponse(query: "Use the local runtime"),
            contentLength: 21
        )
        let outcome = await LocalRuntimeSmokeSupport.collect(stream)

        #expect(outcome.tokens.joined() == "local answer")
        #expect(outcome.error == nil)
        #expect(local.streamCalls.count == 1)
        #expect(cloud.streamCalls.isEmpty)
        let systemPrompt = try? #require(local.streamCalls.first?.systemPrompt)
        #expect(systemPrompt?.contains("local Epistemos assistant running on-device") == true)
        #expect(systemPrompt?.contains("Follow the local overseer plan.") == true)
    }

    @Test("explicit local streaming forwards steering hints to the configurable runtime")
    @MainActor func explicitLocalStreamingForwardsSteeringHints() async {
        let local = RecordingConfigurableLocalLLMClient()
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [triageInteractiveReleaseFixtureModelID.rawValue],
            localLLMService: local
        )
        let hintsJSON = #"{"kv_policy_hint":"flush_all","depth_budget":{"max_turns":2,"max_reasoning_steps":4,"max_tool_calls":1,"max_output_tokens":512}}"#

        let stream = triage.streamGeneralLocally(
            prompt: "Use the local runtime",
            systemPrompt: "Follow the local overseer plan.",
            operation: .chatResponse(query: "Use the local runtime"),
            contentLength: 21,
            steeringHintsJSON: hintsJSON
        )
        let outcome = await LocalRuntimeSmokeSupport.collect(stream)

        #expect(outcome.error == nil)
        #expect(local.streamRequests.count == 1)
        #expect(local.streamRequests.first?.steeringHintsJSON == hintsJSON)
    }

    @Test("explicit local streaming caps output tokens to the steering budget")
    @MainActor func explicitLocalStreamingCapsOutputTokensToSteeringBudget() async {
        let local = RecordingConfigurableLocalLLMClient()
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [triageInteractiveReleaseFixtureModelID.rawValue],
            localLLMService: local
        )
        let hintsJSON = #"{"kv_policy_hint":"flush_all","depth_budget":{"max_turns":2,"max_reasoning_steps":4,"max_tool_calls":1,"max_output_tokens":512}}"#

        let stream = triage.streamGeneralLocally(
            prompt: "ping",
            systemPrompt: "Answer plainly.",
            operation: .chatResponse(query: "ping"),
            contentLength: 4,
            steeringHintsJSON: hintsJSON
        )
        let outcome = await LocalRuntimeSmokeSupport.collect(stream)

        #expect(outcome.error == nil)
        #expect(local.streamRequests.count == 1)
        #expect(local.streamRequests.first?.maxTokens == 512)
    }

    @Test("missing cloud provider keys are cached after the initial miss")
    @MainActor func missingCloudProviderKeysAreCachedAfterTheInitialMiss() {
        let loadCounts = LockedStringIntMap()
        let store = TestKeychainStore()
        let provider = CloudModelProvider.openAI

        let inference = makeIsolatedInferenceState(
            keychainLoad: { key in
                loadCounts.increment(key)
                return store.load(key)
            },
            keychainSave: store.save(_:_:),
            keychainDelete: store.delete(_:)
        )

        let startupLoads = loadCounts.value(for: provider.apiKeyKeychainKey)
        #expect(startupLoads >= 1)
        #expect(inference.apiKey(for: provider) == nil)
        #expect(inference.apiKey(for: provider) == nil)
        #expect(loadCounts.value(for: provider.apiKeyKeychainKey) == startupLoads)

        #expect(inference.setAPIKey("test-openai-key", for: provider))
        let loadsAfterSave = loadCounts.value(for: provider.apiKeyKeychainKey)
        #expect(inference.apiKey(for: provider) == "test-openai-key")
        #expect(loadCounts.value(for: provider.apiKeyKeychainKey) == loadsAfterSave)
    }

    @Test("refusal detection is case-insensitive and prefix-bounded")
    func refusalCaseInsensitivityAndPrefixWindow() {
        #expect(TriageService.isRefusalResponse("I CANNOT ASSIST WITH THIS REQUEST."))

        let longPrefix = String(repeating: "valid-content ", count: 45)
        let buried = longPrefix + "I cannot assist with this request."
        #expect(!TriageService.isRefusalResponse(buried))
    }

    @Test("truncation detection accepts terminal bracket and quote")
    func truncationTerminalCharactersAccepted() {
        #expect(!TriageService.isTruncatedResponse("The quoted sentence is complete.'"))
        #expect(!TriageService.isTruncatedResponse("The bracketed citation is complete.]"))
    }

    @Test("live smoke verifies installed 4B qwen, auto/local routing, thinking stream, and notes plus graph memory")
    @MainActor func liveQwen35Smoke() async throws {
        guard FileManager.default.fileExists(atPath: "/tmp/epi-live-local-qwen35-smoke") else { return }
        try await LocalRuntimeSmokeSupport.runLiveQwen35Smoke()
    }

    @MainActor
    @Test("local runtime tuning unloads faster and uses lower cache budgets on low power")
    func lowPowerRuntimeTuningIsMoreAggressive() {
        let snapshot = LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: 18_000_000_000,
            roundedMemoryGB: 18,
            maxRecommendedLocalContentLength: 8_000
        )

        let normal = LocalMLXRuntimeTuning.runtimePolicy(
            snapshot: snapshot,
            conditions: LocalRuntimeConditions(
                lowPowerModeEnabled: false,
                appActive: true,
                thermalState: .nominal
            )
        )
        let lowPower = LocalMLXRuntimeTuning.runtimePolicy(
            snapshot: snapshot,
            conditions: LocalRuntimeConditions(
                lowPowerModeEnabled: true,
                appActive: true,
                thermalState: .nominal
            )
        )

        #expect(lowPower.idleUnloadDelay < normal.idleUnloadDelay)
        #expect(lowPower.memoryPolicy.cacheLimitBytes < normal.memoryPolicy.cacheLimitBytes)
        #expect(lowPower.memoryPolicy.memoryLimitBytes <= normal.memoryPolicy.memoryLimitBytes)
        #expect(normal.idleUnloadDelay == .seconds(6))
        #expect(lowPower.idleUnloadDelay == .seconds(3))
    }

    @MainActor
    @Test("idle local runtime keeps a much smaller cache budget than active inference")
    func idleRuntimeBudgetIsMuchSmallerThanActiveInferenceBudget() {
        let snapshot = LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: 18_000_000_000,
            roundedMemoryGB: 18,
            maxRecommendedLocalContentLength: 8_000
        )

        let policy = LocalMLXRuntimeTuning.runtimePolicy(
            snapshot: snapshot,
            conditions: LocalRuntimeConditions(
                lowPowerModeEnabled: false,
                appActive: true,
                thermalState: .nominal
            )
        )

        #expect(policy.idleMemoryPolicy.cacheLimitBytes < policy.memoryPolicy.cacheLimitBytes)
        #expect(policy.idleMemoryPolicy.memoryLimitBytes < policy.memoryPolicy.memoryLimitBytes)
        #expect(policy.idleMemoryPolicy.cacheLimitBytes <= 128_000_000)
    }

    @MainActor
    @Test("background thermal pressure tightens local runtime budgets on 18GB machines")
    func backgroundThermalPressureTightensRuntimeBudgets() {
        let snapshot = LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: 18_000_000_000,
            roundedMemoryGB: 18,
            maxRecommendedLocalContentLength: 8_000
        )

        let normalConditions = LocalRuntimeConditions(
            lowPowerModeEnabled: false,
            appActive: true,
            thermalState: .nominal
        )
        let constrainedConditions = LocalRuntimeConditions(
            lowPowerModeEnabled: true,
            appActive: false,
            thermalState: .serious
        )

        let normalPolicy = LocalMLXRuntimeTuning.runtimePolicy(
            snapshot: snapshot,
            conditions: normalConditions
        )
        let constrainedPolicy = LocalMLXRuntimeTuning.runtimePolicy(
            snapshot: snapshot,
            conditions: constrainedConditions
        )
        let normalBudget = LocalMLXRuntimeTuning.contentBudget(
            snapshot: snapshot,
            conditions: normalConditions,
            reasoningMode: .fast
        )
        let constrainedBudget = LocalMLXRuntimeTuning.contentBudget(
            snapshot: snapshot,
            conditions: constrainedConditions,
            reasoningMode: .fast
        )

        #expect(constrainedPolicy.idleUnloadDelay < normalPolicy.idleUnloadDelay)
        #expect(constrainedPolicy.memoryPolicy.cacheLimitBytes < normalPolicy.memoryPolicy.cacheLimitBytes)
        #expect(constrainedPolicy.memoryPolicy.memoryLimitBytes < normalPolicy.memoryPolicy.memoryLimitBytes)
        #expect(constrainedBudget.totalBudget < normalBudget.totalBudget)
        #expect(constrainedBudget.promptBudget < normalBudget.promptBudget)
    }

    @MainActor
    @Test("constrained runtime keeps the chosen local model but disables automatic local routing")
    func constrainedRuntimeKeepsChosenModel() {
        let inference = makeIsolatedInferenceState()
        inference.setInstalledLocalTextModelIDs([
            LocalTextModelID.qwen3_4B4Bit.rawValue,
            LocalTextModelID.qwen3_8B4Bit.rawValue,
        ])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen3_8B4Bit.rawValue)
        inference.setLocalRuntimeConditions(
            LocalRuntimeConditions(
                lowPowerModeEnabled: false,
                appActive: true,
                thermalState: .nominal
            )
        )

        #expect(inference.effectiveLocalTextModelID == LocalTextModelID.qwen3_8B4Bit.rawValue)
        #expect(inference.canRouteToLocalMLX(contentLength: 4_000))

        inference.setLocalRuntimeConditions(
            LocalRuntimeConditions(
                lowPowerModeEnabled: true,
                appActive: false,
                thermalState: .serious
            )
        )

        #expect(inference.effectiveLocalTextModelID == LocalTextModelID.qwen3_8B4Bit.rawValue)
        #expect(!inference.canRouteToLocalMLX(contentLength: 4_000))
    }

    @Test("preferred local tier is used for simple local work")
    @MainActor func preferredTierIsUsedForSimpleLocalWork() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let small = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_2B4Bit.rawValue))
        let balanced = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        for descriptor in [small, balanced] {
            try FileManager.default.createDirectory(
                at: paths.activeDirectory(for: descriptor),
                withIntermediateDirectories: true
            )
        }

        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)
        inference.setInstalledLocalTextModelIDs([small.id, balanced.id])

        let runtime = RecordingLocalMLXRuntime()
        let localClient = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: localClient)

        _ = try await triage.generateGeneral(
            prompt: "Summarize this in two sentences.",
            systemPrompt: "Be concise.",
            operation: .chatResponse(query: "Summarize this in two sentences."),
            contentLength: 31
        )

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.modelID == inference.effectiveLocalTextModelID)
    }

    @MainActor
    @Test("plain debugging phrasing does not force local thinking mode")
    func debuggingCueDoesNotForceThinkingMode() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: triageInteractiveReleaseFixtureModelID.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setPreferredLocalTextModelID(descriptor.id)
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: client)

        _ = try await triage.generateGeneral(
            prompt: "Debug this query path and tell me the most likely bug.",
            systemPrompt: "Be direct.",
            operation: .chatResponse(query: "Debug this query path and tell me the most likely bug."),
            contentLength: 54
        )

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.reasoningMode == .fast)
    }

    @MainActor
    @Test("step by step phrasing alone does not force local thinking mode")
    func stepByStepCueDoesNotForceThinkingMode() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: triageInteractiveReleaseFixtureModelID.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setPreferredLocalTextModelID(descriptor.id)
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: client)

        _ = try await triage.generateGeneral(
            prompt: "Explain step by step how this parser works.",
            systemPrompt: "Be clear.",
            operation: .chatResponse(query: "Explain step by step how this parser works."),
            contentLength: 43
        )

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.reasoningMode == .fast)
    }

    @MainActor
    @Test("explicit reasoning phrasing alone does not force local thinking mode")
    func explicitReasoningCueStaysFast() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: triageInteractiveReleaseFixtureModelID.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setPreferredLocalTextModelID(descriptor.id)
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: client)

        _ = try await triage.generateGeneral(
            prompt: "Show your reasoning and compare both implementations.",
            systemPrompt: "Be thorough.",
            operation: .chatResponse(query: "Show your reasoning and compare both implementations."),
            contentLength: 53
        )

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.reasoningMode == .fast)
    }

    @MainActor
    @Test("configured thinking mode preserves the caller system prompt and runtime mode")
    func configuredThinkingModePreservesLocalThinkingRequests() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: triageThinkingReleaseFixtureModelID.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .localOnly
        inference.setPreferredLocalTextModelID(descriptor.id)
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: client)

        _ = try await triage.generateGeneral(
            prompt: "Compare these two parser implementations and recommend one.",
            systemPrompt: "Be helpful.",
            operation: .chatResponse(query: "Compare these two parser implementations and recommend one."),
            contentLength: 58,
            operatingMode: .thinking
        )

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.reasoningMode == .thinking)
        let systemPrompt = try #require(request.systemPrompt)
        #expect(systemPrompt.contains("local Epistemos assistant running on-device"))
    }

    @MainActor
    @Test("preferred local tier stays stable across hard and short requests")
    func preferredTierStaysStableAcrossRequests() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let small = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_2B4Bit.rawValue))
        let balanced = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        let strong = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_9B4Bit.rawValue))
        for descriptor in [small, balanced, strong] {
            try FileManager.default.createDirectory(
                at: paths.activeDirectory(for: descriptor),
                withIntermediateDirectories: true
            )
        }

        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_2B4Bit.rawValue)
        inference.setInstalledLocalTextModelIDs([small.id, balanced.id, strong.id])

        let runtime = RecordingLocalMLXRuntime()
        let localClient = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: localClient)

        let hardPrompt = String(repeating: "Compare competing interpretations of this code path and identify failure modes. ", count: 80)
        _ = try await triage.generateGeneral(
            prompt: hardPrompt,
            systemPrompt: "Think through the tradeoffs before answering.",
            operation: .chatResponse(query: "Think step by step about competing code paths and failure modes."),
            contentLength: hardPrompt.count,
            operatingMode: .thinking
        )

        let firstRequest = try #require(await runtime.lastGenerateRequest)
        #expect(firstRequest.reasoningMode == .thinking)

        _ = try await triage.generateGeneral(
            prompt: "Give me the short practical takeaway.",
            systemPrompt: "Be direct.",
            operation: .chatResponse(query: "Give me the short practical takeaway."),
            contentLength: 36
        )

        let secondRequest = try #require(await runtime.lastGenerateRequest)
        #expect(secondRequest.modelID == firstRequest.modelID)
    }

    @MainActor
    @Test("preferred installed tier stays active for local requests")
    func preferredInstalledTierStaysActive() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let small = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_2B4Bit.rawValue))
        let balanced = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        for descriptor in [small, balanced] {
            try FileManager.default.createDirectory(
                at: paths.activeDirectory(for: descriptor),
                withIntermediateDirectories: true
            )
        }

        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)
        inference.setInstalledLocalTextModelIDs([small.id, balanced.id])

        let runtime = RecordingLocalMLXRuntime()
        let localClient = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: localClient)

        _ = try await triage.generateGeneral(
            prompt: "Summarize this in two sentences.",
            systemPrompt: "Be concise.",
            operation: .chatResponse(query: "Summarize this in two sentences."),
            contentLength: 31
        )

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.modelID == inference.effectiveLocalTextModelID)
    }

    @MainActor
    @Test("local client uses installed preferred local model")
    func usesInstalledPreferredModel() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen3_4B4Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = makeIsolatedInferenceState()
        inference.setPreferredLocalTextModelID(descriptor.id)
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        let output = try await client.generate(prompt: "Hello", systemPrompt: "System", maxTokens: 123)

        #expect(output == "local-generate")
        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.modelID == descriptor.id)
        #expect(request.modelDirectory == paths.activeDirectory(for: descriptor))
        #expect(request.prompt == "Hello")
        let systemPrompt = try #require(request.systemPrompt)
        #expect(systemPrompt == "System")
        #expect(request.maxTokens == 123)
    }

    @Test("local request preserves uncapped output when the caller leaves maxTokens at zero")
    func localRequestPreservesUncappedOutput() {
        let request = LocalMLXRequest(
            modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/qwen"),
            prompt: "Explain the tradeoffs in detail.",
            systemPrompt: "Be thorough.",
            maxTokens: 0,
            reasoningMode: .fast,
            steeringHintsJSON: nil,
            imageURLs: []
        )

        #expect(request.resolvedMaxTokens == nil)
    }

    @MainActor
    @Test("thinking local stream uses a bounded default output budget when the chat cap is unset")
    func thinkingLocalStreamUsesBoundedDefaultOutputBudgetWhenChatCapIsUnset() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.deepseekR1Distill7B.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setPreferredLocalTextModelID(descriptor.id)
        inference.setInstalledLocalTextModelIDs([descriptor.id])
        inference.setChatOutputTokens(0)

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: client)

        let stream = triage.streamGeneral(
            prompt: "Compare these references and give me the real takeaway.",
            systemPrompt: "Think carefully, then answer directly.",
            operation: .chatResponse(query: "Compare these references and give me the real takeaway."),
            contentLength: 55,
            operatingMode: .thinking
        )
        _ = await LocalRuntimeSmokeSupport.collect(stream)

        let request = try #require(await runtime.lastStreamRequest)
        #expect(request.reasoningMode == .thinking)
        #expect(request.maxTokens == 8192)
    }

    @MainActor
    @Test("local client prepares residency before generating with MLX")
    func localClientPreparesResidencyBeforeGenerating() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen3_4B4Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = makeIsolatedInferenceState()
        inference.setPreferredLocalTextModelID(descriptor.id)
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let events = LocalRuntimeEventRecorder()
        let client = LocalMLXClient(
            runtime: runtime,
            inference: inference,
            paths: paths,
            prepareForRequest: {
                await events.record("prepare-local")
            }
        )

        _ = try await client.generate(prompt: "Hello", systemPrompt: nil, maxTokens: 64)

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.modelID == descriptor.id)
        #expect(await events.snapshot() == ["prepare-local"])
    }

    @Test("local mlx request gate serializes overlapping turns")
    func localMLXRequestGateSerializesOverlappingTurns() async {
        let gate = LocalMLXRequestGate()
        let events = LocalRuntimeEventRecorder()

        async let first: Void = {
            await gate.acquire()
            await events.record("first-acquired")
            try? await Task.sleep(for: .milliseconds(40))
            await events.record("first-releasing")
            await gate.release()
        }()

        async let second: Void = {
            try? await Task.sleep(for: .milliseconds(5))
            await gate.acquire()
            await events.record("second-acquired")
            await gate.release()
        }()

        _ = await (first, second)
        #expect(await events.snapshot() == [
            "first-acquired",
            "first-releasing",
            "second-acquired",
        ])
    }

    @Test("local mlx request gate drops cancelled waiters before handoff")
    func localMLXRequestGateDropsCancelledWaiters() async throws {
        let gate = LocalMLXRequestGate()
        await gate.acquire()

        let cancelledWaiter = Task {
            await gate.acquire()
        }

        try? await Task.sleep(for: .milliseconds(10))
        cancelledWaiter.cancel()
        try? await Task.sleep(for: .milliseconds(10))

        await gate.release()

        let thirdWaiter = Task {
            await gate.acquire()
            await gate.release()
            return "acquired"
        }

        let result = try await withTimeout(seconds: 0.2) {
            await thirdWaiter.value
        }

        #expect(result == "acquired")
    }

    @Test("thinking mode does not hard-cap long-form local output to 1024 tokens")
    func thinkingModeDoesNotHardCapLongFormOutput() throws {
        let request = LocalMLXRequest(
            modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/qwen"),
            prompt: "Produce a detailed research analysis.",
            systemPrompt: "Think deeply and be comprehensive.",
            maxTokens: 6000,
            reasoningMode: .thinking,
            steeringHintsJSON: nil,
            imageURLs: []
        )

        let resolvedMaxTokens = try #require(request.resolvedMaxTokens)
        #expect(resolvedMaxTokens > 1024)
        #expect(resolvedMaxTokens <= 6000)
        #expect(resolvedMaxTokens == max(1, Int(6000 * ThermalMonitor.currentTokenBudgetMultiplier())))
    }

    @Test("thinking-capable qwen requests map template thinking mode from the request reasoning mode")
    func localQwenRequestsMapTemplateThinkingMode() {
        let request = LocalMLXRequest(
            modelID: LocalTextModelID.qwen35_27B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/qwen27"),
            prompt: "Answer directly.",
            systemPrompt: nil,
            maxTokens: 256,
            reasoningMode: .thinking,
            steeringHintsJSON: nil,
            imageURLs: []
        )

        #expect(request.chatTemplateContext?["enable_thinking"] == true)
    }

    @Test("fast-mode Qwen requests explicitly disable thinking across smaller Qwen 3.5 variants")
    func fastModeQwenRequestsExplicitlyDisableThinking() {
        let smallQwenRequest = LocalMLXRequest(
            modelID: LocalTextModelID.qwen35_0_8B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/qwen08"),
            prompt: "Answer directly.",
            systemPrompt: nil,
            maxTokens: 256,
            reasoningMode: .fast,
            steeringHintsJSON: nil,
            imageURLs: []
        )
        let mediumQwenRequest = LocalMLXRequest(
            modelID: LocalTextModelID.qwen35_2B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/qwen2"),
            prompt: "Answer directly.",
            systemPrompt: nil,
            maxTokens: 256,
            reasoningMode: .fast,
            steeringHintsJSON: nil,
            imageURLs: []
        )

        #expect(smallQwenRequest.chatTemplateContext?["enable_thinking"] == false)
        #expect(mediumQwenRequest.chatTemplateContext?["enable_thinking"] == false)
    }

    @Test("qwen25 coder participates in the thinking loop guard")
    func qwen25CoderRequiresThinkingLoopGuard() {
        #expect(LocalTextModelID.qwen25Coder7B.requiresThinkingLoopGuard)
    }

    @Test("Qwen 3.6 thinking requests preserve reasoning state across turns")
    func qwen36ThinkingRequestsPreserveReasoningState() {
        let request = LocalMLXRequest(
            modelID: LocalTextModelID.qwen36_35BA3B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/qwen36"),
            prompt: "Think carefully and continue the same chain of thought.",
            systemPrompt: nil,
            maxTokens: 512,
            reasoningMode: .thinking,
            steeringHintsJSON: nil,
            imageURLs: []
        )

        #expect(request.chatTemplateContext?["enable_thinking"] == true)
        #expect(request.chatTemplateContext?["preserve_thinking"] == true)
    }

    @Test("qwen 4b thinking loop mitigation only enables for the looping tier")
    func qwen4BThinkingLoopMitigationOnlyEnablesForLoopingTier() {
        let guardedRequest = LocalMLXRequest(
            modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/qwen"),
            prompt: "Think carefully.",
            systemPrompt: nil,
            maxTokens: 256,
            reasoningMode: .thinking,
            steeringHintsJSON: nil,
            imageURLs: []
        )
        let fastRequest = LocalMLXRequest(
            modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/qwen"),
            prompt: "Answer directly.",
            systemPrompt: nil,
            maxTokens: 256,
            reasoningMode: .fast,
            steeringHintsJSON: nil,
            imageURLs: []
        )
        let largerThinkingRequest = LocalMLXRequest(
            modelID: LocalTextModelID.qwen35_27B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/qwen27"),
            prompt: "Think carefully.",
            systemPrompt: nil,
            maxTokens: 256,
            reasoningMode: .thinking,
            steeringHintsJSON: nil,
            imageURLs: []
        )

        #expect(LocalMLXLoopMitigation.isEnabled(for: guardedRequest))
        #expect(!LocalMLXLoopMitigation.isEnabled(for: fastRequest))
        #expect(!LocalMLXLoopMitigation.isEnabled(for: largerThinkingRequest))
    }

    @Test("qwen 4b thinking loop guard trips on repeated long chunks")
    func qwen4BThinkingLoopGuardTripsOnRepeatedLongChunks() {
        let request = LocalMLXRequest(
            modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/qwen"),
            prompt: "Think carefully.",
            systemPrompt: nil,
            maxTokens: 256,
            reasoningMode: .thinking,
            steeringHintsJSON: nil,
            imageURLs: []
        )
        var guardrail = LocalMLXLoopGuard(request: request)
        let repeatedChunk = "Let me reason through the same intermediate chain in detail before answering."

        var detection: LocalMLXLoopDetection?
        for _ in 0..<5 {
            detection = guardrail.record(chunk: repeatedChunk)
        }

        #expect(detection?.reason == .repeatedChunk)
    }

    @Test("qwen 4b thinking loop mitigation appends a user-visible fallback when no answer escapes")
    func qwen4BThinkingLoopMitigationAppendsUserVisibleFallback() {
        let request = LocalMLXRequest(
            modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/qwen"),
            prompt: "Think carefully.",
            systemPrompt: nil,
            maxTokens: 256,
            reasoningMode: .thinking,
            steeringHintsJSON: nil,
            imageURLs: []
        )
        let rawLoopingOutput = "<think>repeating the same hidden reasoning forever without closing the loop"
        let mitigated = LocalMLXLoopMitigation.appendFallbackIfNeeded(
            to: rawLoopingOutput,
            for: request
        )
        let visible = UserFacingModelOutput.finalVisibleText(from: mitigated)

        #expect(visible.contains("Qwen 3.5 4B thinking mode was stopped"))
        #expect(visible.contains("Fast mode"))
    }

    @Test("deepseek thinking mitigation appends a fallback when output is only a structured reasoning plan")
    func deepSeekThinkingMitigationAppendsFallbackForStructuredReasoningPlan() {
        let request = LocalMLXRequest(
            modelID: LocalTextModelID.deepseekR1Distill7B.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/deepseek"),
            prompt: "Summarize the essay.",
            systemPrompt: nil,
            maxTokens: 8192,
            reasoningMode: .thinking,
            steeringHintsJSON: nil,
            imageURLs: []
        )
        let rawReasoningPlan = """
        1. Query:
        - Summarize the key findings of these academic references on neuroscience and free will.

        2. Detailed Analysis with chunk_reduce:
        Input Text: The list of references formatted into a text file.
        Instructions: Extract key points from methodology, findings, and implications.
        Reduce Strategy: Select only the most relevant passages.

        3. Pattern Identification:
        - After processing, identify recurring themes such as readiness potentials and unconscious processing.

        This approach will efficiently summarize the references and surface common research threads.
        """

        let mitigated = LocalMLXLoopMitigation.appendFallbackIfNeeded(
            to: rawReasoningPlan,
            for: request
        )
        let visible = UserFacingModelOutput.finalVisibleText(from: mitigated)

        #expect(visible.contains("DeepSeek R1 7B thinking mode was stopped"))
        #expect(visible.contains("Fast mode"))
    }

    @Test("non-qwen local requests do not inject template thinking flags")
    func nonQwenLocalRequestsDoNotInjectTemplateThinkingFlags() {
        let request = LocalMLXRequest(
            modelID: LocalTextModelID.smolLM3_3B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/smollm3"),
            prompt: "Answer directly.",
            systemPrompt: nil,
            maxTokens: 256,
            reasoningMode: .thinking,
            steeringHintsJSON: nil,
            imageURLs: []
        )

        #expect(request.chatTemplateContext == nil)
    }

    @Test("cancelled local stream stop keeps completed output when text was produced")
    func cancelledLocalStreamStopKeepsCompletedOutput() {
        #expect(
            MLXInferenceService.shouldTreatCancelledStopAsCompletion(
                outputCharacterCount: 128,
                chunkCount: 6
            )
        )
    }

    @Test("cancelled local stream stop still cancels when no output was produced")
    func cancelledLocalStreamStopWithoutOutputStillCancels() {
        #expect(
            !MLXInferenceService.shouldTreatCancelledStopAsCompletion(
                outputCharacterCount: 0,
                chunkCount: 0
            )
        )
    }

    @Test("cancelled completed local runs profile as stop")
    func cancelledCompletedLocalRunsProfileAsStop() {
        #expect(
            MLXInferenceService.normalizedStopReason(
                .cancelled,
                outputCharacterCount: 128,
                chunkCount: 6
            ) == .stop
        )
    }

    @Test("empty cancelled local runs remain cancelled")
    func emptyCancelledLocalRunsRemainCancelled() {
        #expect(
            MLXInferenceService.normalizedStopReason(
                .cancelled,
                outputCharacterCount: 0,
                chunkCount: 0
            ) == .cancelled
        )
    }

    @Test("local mlx streaming emits any postprocessed fallback suffix")
    func trailingPostprocessedDeltaEmitsFallbackSuffix() {
        let raw = "<think>looping forever"
        let final = LocalMLXLoopMitigation.appendFallbackIfNeeded(
            to: raw,
            for: LocalMLXRequest(
                modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
                modelDirectory: URL(fileURLWithPath: "/tmp/qwen"),
                prompt: "Think carefully.",
                systemPrompt: nil,
                maxTokens: 256,
                reasoningMode: .thinking,
                steeringHintsJSON: nil,
                imageURLs: []
            )
        )

        let delta = MLXInferenceService.trailingPostprocessedDelta(
            finalText: final,
            alreadyEmitted: raw
        )

        #expect(delta?.contains("Final answer:") == true)
        #expect(delta?.contains("thinking mode was stopped") == true)
    }

    @MainActor
    @Test("local client falls back to the sanitized visible model when the preferred tier is unavailable")
    func fallsBackToSanitizedVisibleModelWhenPreferredTierIsUnavailable() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let installed = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_2B4Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: installed),
            withIntermediateDirectories: true
        )

        let inference = makeIsolatedInferenceState()
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)
        inference.setInstalledLocalTextModelIDs([installed.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        let output = try await client.generate(prompt: "Hello", systemPrompt: nil, maxTokens: 64)
        let request = try #require(await runtime.lastGenerateRequest)

        #expect(output == "local-generate")
        #expect(request.modelID == inference.effectiveLocalTextModelID)
    }

    @MainActor
    @Test("manual local selection falls back to the current sanitized visible tier")
    func manualSelectionFallsBackToSanitizedVisibleTier() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let smallest = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_0_8B4Bit.rawValue))
        let smaller = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_2B4Bit.rawValue))
        for descriptor in [smallest, smaller] {
            try FileManager.default.createDirectory(
                at: paths.activeDirectory(for: descriptor),
                withIntermediateDirectories: true
            )
        }

        let inference = makeIsolatedInferenceState()
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)
        inference.setInstalledLocalTextModelIDs([smallest.id, smaller.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        let output = try await client.generate(prompt: "Hello", systemPrompt: nil, maxTokens: 64)
        let request = try #require(await runtime.lastGenerateRequest)

        #expect(output == "local-generate")
        #expect(request.modelID == inference.effectiveLocalTextModelID)
    }

    @MainActor
    @Test("local stream preserves the caller system prompt and keeps the requested runtime mode")
    func streamPreservesSystemPromptAndReasoningMode() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen3_4BThinking25074Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = makeIsolatedInferenceState()
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        let stream = client.stream(
            prompt: "Explain tides.",
            systemPrompt: "Think first, then answer.",
            maxTokens: 256,
            reasoningMode: .thinking
        )
        for try await _ in stream {
            break
        }

        let request = try #require(await runtime.lastStreamRequest)
        let systemPrompt = try #require(request.systemPrompt)
        #expect(systemPrompt == "Think first, then answer.")
        #expect(request.reasoningMode == .thinking)
    }

    @MainActor
    @Test("local client prefers prepared generation directories over missing installed snapshots")
    func localClientPrefersPreparedGenerationDirectories() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen3_4B4Bit.rawValue))
        let preparedDirectory = paths.rootDirectory
            .appendingPathComponent("prepared-primary", isDirectory: true)
        try FileManager.default.createDirectory(at: preparedDirectory, withIntermediateDirectories: true)

        let inference = makeIsolatedInferenceState()
        inference.setPreferredLocalTextModelID(descriptor.id)
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        client.configurePreparedGenerationRuntime(
            PreparedGenerationRuntimeConfiguration(
                primaryGenerator: PreparedModelDescriptor(
                    key: "generator_primary",
                    role: .generator,
                    displayName: "Qwen 3 4B",
                    artifactID: nil,
                    modelID: descriptor.id,
                    servedModelID: descriptor.id,
                    adapterPath: nil,
                    expectedAdapterBaseModelID: nil,
                    baseModelID: nil,
                    baseSnapshotPath: nil,
                    mergeOutputPath: nil,
                    mlxOutputPath: preparedDirectory.path,
                    downloadPath: nil,
                    status: "prepared",
                    trustRemoteCode: false
                ),
                speculativeDraftGenerator: nil
            )
        )

        _ = try await client.generate(prompt: "Hello", systemPrompt: nil, maxTokens: 64)
        let request = try #require(await runtime.lastGenerateRequest)

        #expect(request.modelDirectory.standardizedFileURL == preparedDirectory.standardizedFileURL)
    }

    @MainActor
    @Test("local client errors when no usable local model is installed")
    func errorsWithoutInstalledModel() async {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let inference = makeIsolatedInferenceState()
        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        await #expect(throws: LocalInferenceRoutingError.modelRequired) {
            try await client.generate(prompt: "Hello", systemPrompt: nil, maxTokens: 32)
        }
    }

    @MainActor
    @Test("mlx client rejects gguf-only selections explicitly")
    func mlxClientRejectsGGUFOnlySelectionsExplicitly() async {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let inference = makeIsolatedInferenceState(
            hardwareCapabilitySnapshot: ggufCapableTestHardwareSnapshot
        )
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])
        inference.setPreparedLocalTextModelIDs([LocalTextModelID.qwopus27Bv3.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwopus27Bv3.rawValue)

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        await #expect(throws: LocalInferenceRoutingError.runtimeUnavailable) {
            try await client.generate(prompt: "Hello", systemPrompt: nil, maxTokens: 32)
        }
    }

    @MainActor
    @Test("local client snapshot uses the distinct local provider identity")
    func snapshotUsesDistinctLocalIdentity() {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let inference = makeIsolatedInferenceState()
        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        #expect(client.configSnapshot().provider == .localMLX)
    }

    @MainActor
    private func makeService(
        appleAvailable: Bool,
        localInstalled: [String] = [],
        routingMode: LocalRoutingMode = .auto,
        localLLMService: (any LLMClientProtocol)? = nil,
        selectedChatModel: ChatModelSelection? = nil,
        cloudLLMService: (any LLMClientProtocol)? = nil,
        keychainStore: TestKeychainStore = TestKeychainStore()
    ) -> TriageService {
        let inference = makeIsolatedInferenceState(keychainStore: keychainStore)
        inference.appleIntelligenceAvailable = appleAvailable
        inference.routingMode = routingMode
        inference.setInstalledLocalTextModelIDs(Set(localInstalled))
        if let firstInstalled = localInstalled.first {
            inference.setPreferredLocalTextModelID(firstInstalled)
        }
        if let selectedChatModel {
            if case .cloud = selectedChatModel {
                inference.preferredChatModelSelection = selectedChatModel
            } else {
                inference.setPreferredChatModelSelection(selectedChatModel)
            }
        }

        return TriageService(
            inference: inference,
            localLLMService: localLLMService,
            cloudLLMService: cloudLLMService
        )
    }

    private func temporaryLocalModelPaths() -> LocalModelPaths {
        LocalModelPaths(
            rootDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
    }
}

@Suite("LLMService Local Snapshots")
struct LLMServiceLocalSnapshotTests {
    @Test("config snapshot keeps local mode fast")
    @MainActor func configSnapshotKeepsFastMode() {
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = true
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen3_4B4Bit.rawValue)

        let llm = LLMService(inference: inference)
        let snapshot = llm.configSnapshot()

        #expect(snapshot.provider == .localMLX)
        #expect(snapshot.model == LocalTextModelID.qwen3_4B4Bit.rawValue)
        #expect(snapshot.reasoningMode == .fast)
    }

    @Test("local snapshots use the selected tier instead of the last routed tier")
    @MainActor func localSnapshotsUseSelectedTier() {
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = true
        inference.setInstalledLocalTextModelIDs([
            LocalTextModelID.qwen3_4B4Bit.rawValue,
            LocalTextModelID.qwen3_8B4Bit.rawValue,
        ])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen3_8B4Bit.rawValue)

        let llm = LLMService(inference: inference)
        let snapshot = llm.configSnapshot()

        #expect(snapshot.provider == .localMLX)
        #expect(snapshot.model == LocalTextModelID.qwen3_8B4Bit.rawValue)
    }

    @Test("local snapshots stay in fast mode")
    @MainActor func localSnapshotsStayFast() {
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = true
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen3_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen3_4B4Bit.rawValue)

        let llm = LLMService(inference: inference)
        let snapshot = llm.configSnapshot()

        #expect(snapshot.provider == .localMLX)
        #expect(snapshot.reasoningMode == .fast)
    }
}

private actor RecordingLocalMLXRuntime: LocalMLXRuntime {
    var lastGenerateRequest: LocalMLXRequest?
    var lastStreamRequest: LocalMLXRequest?
    var unloadCount = 0

    func generate(request: LocalMLXRequest) async throws -> String {
        lastGenerateRequest = request
        return "local-generate"
    }

    func stream(request: LocalMLXRequest) async -> AsyncThrowingStream<String, Error> {
        lastStreamRequest = request
        return AsyncThrowingStream { continuation in
            continuation.yield("local")
            continuation.finish()
        }
    }

    func unload() async {
        unloadCount += 1
    }

    func profilingSnapshot() async -> LocalMLXRunProfile? {
        nil
    }
}

private actor LocalRuntimeEventRecorder {
    private var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }

    func snapshot() -> [String] {
        events
    }
}
