import AppKit
import Foundation
import Testing
@testable import Epistemos

private func loadRepoTextFileWithRetry(
    relativePath: String,
    testsFilePath: String,
    attempts: Int = 5
) throws -> String {
    _ = testsFilePath
    _ = attempts
    return try loadMirroredSourceTextFile(relativePath)
}

@Suite("Runtime Validation")
struct RuntimeValidationTests {
    private let inferenceDefaultsKeys = [
        "epistemos.localRoutingMode",
        "epistemos.preferredLocalTextModelID",
        "epistemos.preferredChatModelSelection",
        "epistemos.activeAIProvider",
        "epistemos.lastNonLocalAIProvider",
        "epistemos.openAIWebSearchEnabled",
        "epistemos.openAICodeInterpreterEnabled",
        "epistemos.anthropicExtendedThinkingEnabled",
        "epistemos.anthropicThinkingBudgetTokens",
        "epistemos.googleGroundingEnabled",
        "epistemos.cloudSetupHintShown",
        "epistemos.preferredCloudModel.openAI",
        "epistemos.preferredCloudModel.anthropic",
        "epistemos.preferredCloudModel.google",
        "epistemos.preferredCloudModel.zai",
        "epistemos.preferredCloudModel.kimi",
        "epistemos.preferredCloudModel.minimax",
        "epistemos.preferredCloudModel.deepseek",
    ]

    @MainActor
    private func withResetInferenceDefaults(
        _ body: () async throws -> Void
    ) async rethrows {
        let defaults = UserDefaults.standard
        let savedValues = inferenceDefaultsKeys.reduce(into: [String: Any?]()) { partialResult, key in
            partialResult[key] = defaults.object(forKey: key)
            defaults.removeObject(forKey: key)
        }
        defer {
            for key in inferenceDefaultsKeys {
                if let value = savedValues[key] ?? nil {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        try await body()
    }

    @MainActor
    @Test("cold bootstrap leaves the local runtime unloaded until the first real request")
    func coldBootstrapLeavesLocalRuntimeUnloaded() async {
        await withResetInferenceDefaults {
            let bootstrap = AppBootstrap()

            #expect(await bootstrap.localInferenceService.profilingSnapshot() == nil)
            #expect(bootstrap.localLLMClient.configSnapshot().provider == .localMLX)
            #expect(
                bootstrap.localLLMClient.configSnapshot().model
                    == (bootstrap.inferenceState.effectiveLocalTextModelID ?? "")
            )
        }
    }

    @MainActor
    @Test("inference keeps only local routing defaults after legacy cleanup")
    func inferenceKeepsOnlyLocalRoutingDefaults() async {
        await withResetInferenceDefaults {
            let inference = InferenceState()

            #expect(inference.routingMode == .auto)
            #expect(inference.preferredLocalTextModelID == LocalHardwareCapabilitySnapshot.current.recommendedLocalTextModelID.rawValue)
            #expect(
                inference.preferredChatModelSelection
                    == .localMLX(LocalHardwareCapabilitySnapshot.current.recommendedLocalTextModelID.rawValue)
            )
        }
    }

    @Test("inference migrates legacy secure cloud keys and selections forward")
    func inferenceMigratesLegacyCloudConfigurationForward() throws {
        let source = try loadRepoTextFile("Epistemos/State/InferenceState.swift")

        #expect(source.contains("migrateLegacyCloudAPIKeysIfNeeded()"))
        #expect(source.contains("epistemos.apiKey.openai"))
        #expect(source.contains("epistemos.apiKey.anthropic"))
        #expect(source.contains("epistemos.apiKey.google"))
        #expect(source.contains("migrateLegacyCloudSelection(defaults: defaults)"))
        #expect(source.contains("\"gpt-5.3\": .openAIGPT54"))
        #expect(source.contains("\"claude-sonnet-4-6\": .anthropicClaudeSonnet4"))
        #expect(source.contains("\"gemini-1.5-pro\": .googleGemini25Pro"))
        #expect(source.contains("case zai"))
        #expect(source.contains("case kimi"))
        #expect(source.contains("case minimax"))
        #expect(source.contains("case deepseek"))
        #expect(source.contains("\"epistemos.preferredCloudModel.\\(provider.rawValue)\""))
    }

    @Test("chat model selector uses a popover with an active provider and scoped cloud section")
    func chatModelSelectorUsesPopoverWithFoldableSections() throws {
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(rootView.contains("AnchoredPopoverButton("))
        #expect(rootView.contains("DisclosureGroup("))
        #expect(rootView.contains("\"Local Models\""))
        #expect(rootView.contains("\"Cloud Access\""))
        #expect(rootView.contains("\"Provider\""))
        #expect(rootView.contains("\"Temporary Chat\""))
        #expect(rootView.contains("ForEach(CloudModelProvider.preferredOrder"))
        #expect(rootView.contains("inference.activeAIProvider"))
        #expect(rootView.contains("ForEach(CloudTextModelID.models(for: provider)"))
    }

    @Test("root toolbar only mounts a principal item when there is visible content")
    func rootToolbarOnlyMountsPrincipalItemWhenVisible() throws {
        let rootView = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/RootView.swift",
            testsFilePath: #filePath
        )

        #expect(rootView.contains("if showLandingToolbarControls || activeHomeChat"))
        #expect(rootView.contains("ToolbarItem(placement: .principal)"))
        #expect(rootView.contains("if ui.homeTab == .home && !chat.messages.isEmpty && !chat.showLanding"))
        #expect(rootView.contains("ToolbarItem(placement: .navigation)"))
    }

    @MainActor
    @Test("warm relaunch bootstrap also starts without an eager local model load")
    func warmBootstrapAlsoStartsCold() async {
        let first = AppBootstrap()
        #expect(await first.localInferenceService.profilingSnapshot() == nil)

        let second = AppBootstrap()
        #expect(await second.localInferenceService.profilingSnapshot() == nil)
        #expect(AppBootstrap.shared === second)
    }

    @Test("startup warmups only schedule Metal shader warmup outside tests and debug builds")
    func startupWarmupsStayLazyInTestsAndDebugBuilds() throws {
        #expect(
            !AppBootstrap.shouldScheduleMetalShaderWarmupAtLaunch(
                isRunningTests: true,
                isDebugBuild: false
            )
        )
        #expect(
            !AppBootstrap.shouldScheduleMetalShaderWarmupAtLaunch(
                isRunningTests: false,
                isDebugBuild: true
            )
        )
        #expect(
            AppBootstrap.shouldScheduleMetalShaderWarmupAtLaunch(
                isRunningTests: false,
                isDebugBuild: false
            )
        )

        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/AppBootstrap.swift",
            testsFilePath: #filePath
        )
        #expect(!source.contains("shouldPrewarmHermesAtLaunch"))
        #expect(!source.contains("shouldSuperviseHermesAtLaunch"))
    }

    @Test("test hosts route application support paths into a temporary runtime root")
    func testHostsRouteApplicationSupportPathsIntoTemporaryRuntimeRoot() {
        let appSupport = FoundationSafety.userApplicationSupportDirectory().standardizedFileURL
        let tempRoot = FileManager.default.temporaryDirectory.standardizedFileURL
        let noteBodies = NoteFileStorage.storageDirectory().standardizedFileURL

        #expect(appSupport.path.hasPrefix(tempRoot.path))
        #expect(appSupport.lastPathComponent == "Application Support")
        #expect(noteBodies.path.hasPrefix(appSupport.path))
        #expect(noteBodies.path.contains("/Epistemos/note-bodies"))
    }

    @Test("test-safe application support routing stays centralized")
    func testSafeApplicationSupportRoutingStaysCentralized() throws {
        let extensions = try loadRepoTextFile("Epistemos/Engine/Extensions.swift")
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let noteFileStorage = try loadRepoTextFile("Epistemos/Sync/NoteFileStorage.swift")
        let searchIndex = try loadRepoTextFile("Epistemos/Sync/SearchIndexService.swift")
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let paperclipStore = try loadRepoTextFile("Epistemos/State/PaperclipStateStore.swift")
        let localModels = try loadRepoTextFile("Epistemos/Engine/LocalModelInfrastructure.swift")
        let traceCollector = try loadRepoTextFile("Epistemos/Harness/TraceCollector.swift")
        let harnessRegistry = try loadRepoTextFile("Epistemos/Harness/HarnessRegistry.swift")
        let progressStore = try loadRepoTextFile("Epistemos/Harness/ProgressStore.swift")
        let shadowGit = try loadRepoTextFile("Epistemos/Omega/Safety/ShadowGitCheckpoint.swift")
        let watchdog = try loadRepoTextFile("Epistemos/State/MainThreadWatchdog.swift")
        let pageEditorCache = try loadRepoTextFile("Epistemos/Views/Notes/PageEditorCache.swift")
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let moLoRA = try loadRepoTextFile("Epistemos/KnowledgeFusion/Adapters/MoLoRARouter.swift")

        #expect(extensions.contains("Epistemos-TestRuntime"))
        #expect(extensions.contains("XCTestConfigurationFilePath"))
        #expect(appBootstrap.contains("let usesInMemoryModelStore = Self.isRunningTests"))
        #expect(appBootstrap.contains("ModelConfiguration(isStoredInMemoryOnly: usesInMemoryModelStore)"))

        for source in [
            noteFileStorage,
            searchIndex,
            vaultSync,
            paperclipStore,
            localModels,
            traceCollector,
            harnessRegistry,
            progressStore,
            shadowGit,
            watchdog,
            pageEditorCache,
            app,
            moLoRA,
        ] {
            #expect(source.contains("FoundationSafety.userApplicationSupportDirectory"))
        }
    }

    @Test("paperclip store uses bound SQLite statements and explicit rollback")
    func paperclipStoreUsesBoundStatementsAndRollback() throws {
        let paperclipStore = try loadRepoTextFile("Epistemos/State/PaperclipStateStore.swift")

        #expect(!paperclipStore.contains("_ = try? exec(\"COMMIT;\")"))
        #expect(!paperclipStore.contains("VALUES ('\\(tick.sessionId)'"))
        #expect(!paperclipStore.contains("VALUES ('\\(heartbeat.agentId)'"))
        #expect(paperclipStore.contains("try exec(\"ROLLBACK;\")"))
        #expect(paperclipStore.contains("sqlite3_bind_text"))
        #expect(paperclipStore.contains("sqlite3_bind_double"))
        #expect(paperclipStore.contains("sqlite3_bind_int64"))
    }

    @Test("capture config avoids silent JSON fallback for allowlist and blocklist")
    func captureConfigAvoidsSilentJSONFallback() throws {
        let config = try loadRepoTextFile("Epistemos/State/EpistemosConfig.swift")

        #expect(!config.contains("(try? JSONDecoder().decode([String].self, from: Data(allowlistJSON.utf8))) ?? []"))
        #expect(!config.contains("(try? JSONDecoder().decode([String].self, from: Data(blocklistJSON.utf8))) ?? []"))
        #expect(!config.contains("(try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? \"[]\""))
        #expect(config.contains("EpistemosConfig: failed to decode capture allowlist JSON"))
        #expect(config.contains("EpistemosConfig: failed to decode capture blocklist JSON"))
        #expect(config.contains("EpistemosConfig: failed to encode capture filter JSON"))
        #expect(config.contains("private func decodeBundleList"))
    }

    @MainActor
    @Test("thinking operating mode sanitizes unsupported chat model selections")
    func thinkingOperatingModeSanitizesUnsupportedSelections() async {
        await withResetInferenceDefaults {
            let inference = InferenceState()
            inference.setInstalledLocalTextModelIDs([
                LocalTextModelID.qwen35_4B4Bit.rawValue,
                LocalTextModelID.smolLM3_3B4Bit.rawValue,
            ])

            inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen35_4B4Bit.rawValue))
            #expect(!inference.supportsThinkingOperatingMode)
            #expect(inference.sanitizedOperatingMode(.thinking) == .fast)

            inference.setPreferredChatModelSelection(.appleIntelligence)
            #expect(!inference.supportsThinkingOperatingMode)
            #expect(inference.sanitizedOperatingMode(.thinking) == .fast)

            inference.setPreferredLocalTextModelID(LocalTextModelID.smolLM3_3B4Bit.rawValue)
            inference.setPreferredChatModelSelection(.cloud(.openAIGPT54Mini))
            #expect(!inference.supportsThinkingOperatingMode)
            #expect(inference.sanitizedOperatingMode(.thinking) == .fast)
        }
    }

    @MainActor
    @Test("thinking operating mode stays off for local models without verified responsive thinking support")
    func thinkingOperatingModeStaysOffForUnverifiedThinkingLocalModels() async {
        await withResetInferenceDefaults {
            let inference = InferenceState()
            inference.setInstalledLocalTextModelIDs([
                LocalTextModelID.qwen35_0_8B4Bit.rawValue,
                LocalTextModelID.qwen35_2B4Bit.rawValue,
                LocalTextModelID.qwen35_9B4Bit.rawValue,
            ])

            inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen35_0_8B4Bit.rawValue))
            #expect(!inference.supportsThinkingOperatingMode)
            #expect(inference.availableOperatingModes == [.fast])

            inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen35_2B4Bit.rawValue))
            #expect(!inference.supportsThinkingOperatingMode)
            #expect(inference.availableOperatingModes == [.fast])

            inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen35_9B4Bit.rawValue))
            #expect(!inference.supportsThinkingOperatingMode)
            #expect(inference.availableOperatingModes == [.fast])
        }
    }

    @MainActor
    @Test("thinking operating mode stays off for installed local models without verified think support")
    func thinkingOperatingModeStaysOffForInstalledNonThinkingLocalModels() async {
        await withResetInferenceDefaults {
            let inference = InferenceState()
            inference.setInstalledLocalTextModelIDs([LocalTextModelID.smolLM3_3B4Bit.rawValue])
            inference.setPreferredLocalTextModelID(LocalTextModelID.smolLM3_3B4Bit.rawValue)
            inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.smolLM3_3B4Bit.rawValue))

            #expect(!inference.supportsThinkingOperatingMode)
            #expect(inference.sanitizedOperatingMode(.thinking) == .fast)
        }
    }

    @MainActor
    @Test("available operating modes match the active chat selection")
    func availableOperatingModesMatchTheActiveSelection() async {
        await withResetInferenceDefaults {
            let inference = InferenceState()
            inference.setInstalledLocalTextModelIDs([
                LocalTextModelID.qwen35_4B4Bit.rawValue,
                LocalTextModelID.smolLM3_3B4Bit.rawValue,
            ])

            inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen35_4B4Bit.rawValue))
            #expect(inference.availableOperatingModes == [.fast])

            inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.smolLM3_3B4Bit.rawValue))
            #expect(inference.availableOperatingModes == [.fast])

            inference.setPreferredChatModelSelection(.appleIntelligence)
            #expect(inference.availableOperatingModes == [.fast])

            inference.setPreferredChatModelSelection(.cloud(.openAIGPT54Mini))
            #expect(inference.availableOperatingModes == [.fast])
        }
    }

    @Test("18 GB hardware supports both 4B and 9B local Qwen tiers")
    func hardwareSupportIncludes9BOn18GBMachines() {
        let snapshot = LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: 18_000_000_000,
            roundedMemoryGB: 18,
            maxRecommendedLocalContentLength: 10_000
        )

        #expect(snapshot.supports(textModelID: LocalTextModelID.qwen35_4B4Bit.rawValue))
        #expect(snapshot.supports(textModelID: LocalTextModelID.qwen35_9B4Bit.rawValue))
    }

    @Test("composer surfaces route runtime controls through the consolidated popover")
    func composerSurfacesUseConsolidatedRuntimePopover() throws {
        let chatInputBar = try loadRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(chatInputBar.contains("operatingMode: operatingModeBinding"))
        #expect(landing.contains("operatingMode: operatingModeBinding"))
        #expect(miniChat.contains("operatingMode: operatingModeBinding"))
        #expect(!chatInputBar.contains("OperatingModeSelectorView("))
        #expect(!landing.contains("OperatingModeSelectorView("))
        #expect(!miniChat.contains("OperatingModeSelectorView("))
    }

    @Test("inference exposes observable cloud credential cache and validation state")
    func inferenceExposesObservableCloudCredentialCacheAndValidationState() throws {
        let source = try loadRepoTextFile("Epistemos/State/InferenceState.swift")

        #expect(source.contains("private(set) var cachedCloudAPIKeys"))
        #expect(source.contains("private(set) var cachedCloudOAuthCredentials"))
        #expect(source.contains("private(set) var cloudProviderValidationStates"))
        #expect(source.contains("func validateCloudAccess(for provider: CloudModelProvider) async -> ConnectionTestResult"))
        #expect(source.contains("func validateAPIKey(for provider: CloudModelProvider) async -> ConnectionTestResult"))
        #expect(source.contains("cloudProviderValidationStates[provider] = .checking"))
        #expect(source.contains("cloudProviderValidationStates[provider] = .unchecked"))
        #expect(source.contains("cloudProviderValidationStates[provider] = .missing"))
        #expect(source.contains("cachedCloudAPIKeys[provider] = trimmed"))
    }

    @Test("cloud key validation checks provider auth before probing a model")
    func cloudKeyValidationChecksProviderAuthBeforeProbingAModel() throws {
        let llmService = try loadRepoTextFile("Epistemos/Engine/LLMService.swift")
        let inference = try loadRepoTextFile("Epistemos/State/InferenceState.swift")

        #expect(llmService.contains("if let model"))
        #expect(llmService.contains("providerAuthorizationRequest"))
        #expect(llmService.contains("openAIRequestURL(path: \"/models\", credential: credential)"))
        #expect(llmService.contains("https://api.anthropic.com/v1/models"))
        #expect(llmService.contains("generativelanguage.googleapis.com/v1beta/models"))
        #expect(inference.contains("case .anthropic:\n            .anthropicClaudeSonnet4"))
    }

    @Test("inference settings surface exposes key validation and provider guidance")
    func inferenceSettingsSurfaceExposesValidationAndGuidance() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let sharedCard = try loadRepoTextFile("Epistemos/Views/Shared/CloudProviderSetupCard.swift")

        #expect(source.contains("Check Access"))
        #expect(source.contains("statusBadge"))
        #expect(source.contains("setupHelpText"))
        #expect(source.contains("securely in the Apple Keychain"))
        #expect(sharedCard.contains("provider.manualCredentialTitle"))
        #expect(sharedCard.contains("Button(\"Paste + Save\")"))
    }

    #if false
    @Test("agent runtime panel uses a glass-native shell instead of the old flat split pane")
    func agentRuntimePanelUsesGlassNativeShell() throws {}

    @Test("agent runtime panel surfaces Hermes command actions in the native UI")
    func agentRuntimePanelSurfacesHermesCommandActions() throws {}

    @Test("agent runtime status pulse avoids repeat forever animation drift")
    func agentRuntimeStatusPulseAvoidsRepeatForeverAnimationDrift() throws {}

    @Test("agent runtime prepares harness state before recording intent and runs completion hooks")
    func agentRuntimeRunsHarnessLifecycleHooksInOrder() throws {}
    #endif

    @Test("xcode build graph regenerates and links epistemos core integrity bindings")
    func xcodeBuildGraphRegeneratesEpistemosCoreBindings() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let spec = try loadRepoTextFile("project.yml")
        let patcher = try loadRepoTextFile("patch-uniffi-bindings.py")
        let buildScript = try loadRepoTextFile("build-epistemos-core.sh")
        let embedAndSignHelper = try loadRepoTextFile("embed-and-sign-rust-dylib.sh")
        let bundleAssetsScript = try loadRepoTextFile("bundle-app-runtime-assets.sh")

        #expect(
            project.contains(
                "bash \\\"${SRCROOT}/build-rust.sh\\\" && bash \\\"${SRCROOT}/build-omega-mcp.sh\\\" && bash \\\"${SRCROOT}/build-omega-ax.sh\\\" && bash \\\"${SRCROOT}/build-epistemos-core.sh\\\""
            )
        )
        #expect(project.contains("Bundle Runtime Assets"))
        #expect(project.contains("bash \\\"${SRCROOT}/bundle-app-runtime-assets.sh\\\""))
        #expect(project.contains("-lepistemos_core"))
        #expect(project.contains("-lomega_mcp"))
        #expect(project.contains("-lomega_ax"))
        #expect(project.contains("epistemos_coreFFI"))
        #expect(project.contains("\"@executable_path\","))
        #expect(project.contains("\"@loader_path/../Frameworks\","))
        #expect(spec.contains(#"script: "bash \"${SRCROOT}/build-rust.sh\" && bash \"${SRCROOT}/build-omega-mcp.sh\" && bash \"${SRCROOT}/build-omega-ax.sh\" && bash \"${SRCROOT}/build-epistemos-core.sh\" && bash \"${SRCROOT}/build-agent-core.sh\"""#))
        #expect(spec.contains("name: Bundle Runtime Assets"))
        #expect(spec.contains("bash \"${SRCROOT}/bundle-app-runtime-assets.sh\""))
        #expect(spec.contains("-lepistemos_core"))
        #expect(spec.contains("epistemos_coreFFI"))
        #expect(spec.contains("@executable_path"))
        #expect(spec.contains("@loader_path/../Frameworks"))
        #expect(!project.contains("SHIP_MODE=release"))
        #expect(!spec.contains("SHIP_MODE=release"))
        #expect(patcher.contains("nonisolated public var errorDescription"))
        #expect(patcher.contains("nonisolated(unsafe)"))
        #expect(patcher.contains("nonisolated(unsafe) let pointer = self.pointer"))
        #expect(patcher.contains("((?:(?:open|public|private|fileprivate|internal|final|indirect)\\s+)*)((?:class|struct|enum|protocol|extension)\\b)"))
        #expect(patcher.contains("((?:(?:open|public|private|fileprivate|internal|override|final)\\s+)*)((?:static|class)\\s+)?func\\s"))
        #expect(buildScript.contains("rm -f \"$TARGET_BUILD_DIR/PackageFrameworks/libepistemos_core.dylib\""))
        #expect(buildScript.contains("embed-and-sign-rust-dylib.sh"))
        #expect(embedAndSignHelper.contains("codesign --force --sign"))
        #expect(embedAndSignHelper.contains("EXPANDED_CODE_SIGN_IDENTITY"))
        #expect(!buildScript.contains("cp ../build-rust/libepistemos_core.dylib \"$TARGET_BUILD_DIR/PackageFrameworks/libepistemos_core.dylib\""))
        #expect(bundleAssetsScript.contains("KnowledgeFusion/Training/scripts/train_knowledge.py"))
        #expect(bundleAssetsScript.contains("KnowledgeFusion/Training/scripts/train_style.py"))
        #expect(bundleAssetsScript.contains("KnowledgeFusion/Alignment/scripts/train_kto.py"))
        #expect(bundleAssetsScript.contains("KnowledgeFusion/MoLoRA/molora_inference.py"))
        #expect(bundleAssetsScript.contains("KnowledgeFusion/MoLoRA/sgmm_kernel.py"))
        #expect(bundleAssetsScript.contains("KnowledgeFusion/MOHAWK/eval_bfcl.py"))
        #expect(bundleAssetsScript.contains("KnowledgeFusion/MOHAWK/embodied_data/bfcl_eval_macos.jsonl"))
    }

    @Test("structured diagnostic logger keeps fire-and-forget writes alive")
    func structuredDiagnosticLoggerRetainsFireAndForgetWrites() throws {
        let source = try loadRepoTextFile("Epistemos/State/MainThreadWatchdog.swift")

        #expect(source.contains("queue.async {"))
        #expect(!source.contains("queue.async { [weak self] in"))
        #expect(source.contains("self.appendLine(entry)"))
    }

    @Test("structured diagnostic logger avoids silent file persistence fallbacks")
    func structuredDiagnosticLoggerAvoidsSilentFilePersistenceFallbacks() throws {
        let source = try loadRepoTextFile("Epistemos/State/MainThreadWatchdog.swift")

        #expect(!source.contains("try? FileManager.default.createDirectory("))
        #expect(!source.contains("guard let data = try? Data(contentsOf: logFileURL),"))
        #expect(!source.contains("guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),"))
        #expect(!source.contains("if let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),"))
        #expect(!source.contains("try? FileManager.default.removeItem(at: rotatedURL)"))
        #expect(!source.contains("try? FileManager.default.moveItem(at: logFileURL, to: rotatedURL)"))
        #expect(!source.contains("if let handle = try? FileHandle(forWritingTo: logFileURL)"))
        #expect(!source.contains("try? entry.write(to: logFileURL)"))
        #expect(source.contains("Structured diagnostics: failed to create log directory"))
        #expect(source.contains("Structured diagnostics: failed to load recent events"))
        #expect(source.contains("Structured diagnostics: failed to encode event"))
        #expect(source.contains("Structured diagnostics: failed to append log entry"))
        #expect(source.contains("private nonisolated func ensureLogDirectoryExists()"))
        #expect(source.contains("private nonisolated func shouldRotateLogFile() throws -> Bool"))
        #expect(source.contains("private nonisolated func rotateLogFile() throws"))
    }

    @Test("main thread watchdog coalesces queued delayed callbacks before logging")
    func mainThreadWatchdogCoalescesQueuedDelayedCallbacksBeforeLogging() throws {
        let source = try loadRepoTextFile("Epistemos/State/MainThreadWatchdog.swift")

        #expect(source.contains("struct HangBurstTracker"))
        #expect(source.contains("hangCoalescingDelay"))
        #expect(source.contains("scheduleHangBurstEmission"))
        #expect(source.contains("coalesced samples"))
        #expect(!source.contains("consecutive:"))
    }

    @Test("app bootstrap skips main thread watchdog install under tests")
    func appBootstrapSkipsWatchdogInstallUnderTests() throws {
        let source = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        #expect(source.contains("if !Self.isRunningTests && !PowerGuard.shared.shouldDisableBackground {"))
        #expect(source.contains("MainThreadWatchdog.install()"))
    }

    @Test("Rust build scripts force panic abort under thread sanitizer builds")
    func rustBuildScriptsForcePanicAbortUnderThreadSanitizerBuilds() throws {
        let graphEngine = try loadRepoTextFile("build-rust.sh")
        let omegaMcp = try loadRepoTextFile("build-omega-mcp.sh")
        let omegaAx = try loadRepoTextFile("build-omega-ax.sh")
        let epistemosCore = try loadRepoTextFile("build-epistemos-core.sh")

        for script in [graphEngine, omegaMcp, omegaAx, epistemosCore] {
            #expect(script.contains("ENABLE_THREAD_SANITIZER"))
            #expect(script.contains("CARGO_PROFILE_DEV_PANIC=abort"))
            #expect(script.contains("RUSTFLAGS"))
            #expect(script.contains("-C panic=abort"))
        }
    }

    @Test("omega ffi crates build and embed dylibs instead of static archives")
    func omegaFFICratesBuildAndEmbedDylibsInsteadOfStaticArchives() throws {
        let project = try loadRepoTextFile("Epistemos.xcodeproj/project.pbxproj")
        let omegaMcp = try loadRepoTextFile("build-omega-mcp.sh")
        let omegaAx = try loadRepoTextFile("build-omega-ax.sh")

        #expect(project.contains("-lomega_mcp"))
        #expect(project.contains("-lomega_ax"))
        #expect(project.contains("omega_mcpFFI"))
        #expect(project.contains("omega_axFFI"))
        #expect(!project.contains("$(SRCROOT)/build-rust/libomega_mcp.a"))
        #expect(!project.contains("$(SRCROOT)/build-rust/libomega_ax.a"))

        for script in [omegaMcp, omegaAx] {
            #expect(script.contains("cargo build --target aarch64-apple-darwin"))
            #expect(script.contains("cargo build --target x86_64-apple-darwin"))
            #expect(script.contains("lipo -create"))
            #expect(script.contains(".dylib\""))
            #expect(script.contains("install_name_tool -id"))
            #expect(script.contains("FRAMEWORKS_FOLDER_PATH"))
            #expect(script.contains("embed-and-sign-rust-dylib.sh"))
            #expect(script.contains("rm -f ../build-rust/lib"))
            #expect(!script.contains("cp \"$LIB_PATH\" ../build-rust/libomega_mcp.a"))
            #expect(!script.contains("cp \"$LIB_PATH\" ../build-rust/libomega_ax.a"))
        }
    }

    @Test("graph engine and epistemos core build universal darwin artifacts")
    func graphEngineAndEpistemosCoreBuildUniversalDarwinArtifacts() throws {
        let graphEngine = try loadRepoTextFile("build-rust.sh")
        let epistemosCore = try loadRepoTextFile("build-epistemos-core.sh")

        for script in [graphEngine, epistemosCore] {
            #expect(script.contains("cargo build --target aarch64-apple-darwin"))
            #expect(script.contains("cargo build --target x86_64-apple-darwin"))
            #expect(script.contains("lipo -create"))
        }
    }

    @Test("shadow git checkpoint subprocess remains cancellation-safe")
    func shadowGitCheckpointSubprocessRemainsCancellationSafe() throws {
        let source = try loadRepoTextFile("Epistemos/Omega/Safety/ShadowGitCheckpoint.swift")

        #expect(source.contains("ThrowingProcessContinuationState<Void>()"))
        #expect(source.contains("withTaskCancellationHandler"))
        #expect(source.contains("TimeoutError(seconds: timeoutSeconds)"))
        #expect(source.contains("state.terminate()"))
        #expect(source.contains("state.resume(throwing: CancellationError())"))
    }

    @Test("subprocess timeout watchdogs stop cleanly on cancellation")
    func subprocessTimeoutWatchdogsStopCleanlyOnCancellation() throws {
        let sourcePaths = [
            "Epistemos/Omega/Safety/ShadowGitCheckpoint.swift",
            "Epistemos/KnowledgeFusion/Alignment/KTOTrainer.swift",
            "Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift",
            "Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift",
            "Epistemos/KnowledgeFusion/PythonEnvironmentManager.swift",
        ]

        for path in sourcePaths {
            let source = try loadRepoTextFile(path)
            #expect(!source.contains("try? await Task.sleep(for: .seconds(timeoutSeconds))"))
            #expect(source.contains("catch is CancellationError"))
        }
    }

    @Test("epistemos core durability and instant recall exports stay fail-closed")
    func epistemosCoreDurabilityAndInstantRecallExportsStayFailClosed() throws {
        let source = try loadRepoTextFile("epistemos-core/src/uniffi_exports.rs")
        let udl = try loadRepoTextFile("epistemos-core/uniffi/epistemos_core.udl")
        let noteStorage = try loadRepoTextFile("Epistemos/Sync/NoteFileStorage.swift")

        #expect(source.contains("libc::F_FULLFSYNC"))
        #expect(!source.contains("libc::fsync("))
        #expect(source.contains("fn with_recall_indices_mut<R>("))
        #expect(source.contains("fn with_recall_indices<R>("))
        #expect(!source.contains("RECALL_INDICES.lock().unwrap()"))
        #expect(source.contains("with_recall_indices_mut(false"))
        #expect(source.contains("with_recall_indices(\"[]\".to_string()"))
        #expect(source.contains("with_recall_indices(0"))
        #expect(source.contains("pub enum TextNormalizationError"))
        #expect(source.contains("pub fn sanitize_and_normalize(input: String) -> Result<String, TextNormalizationError>"))
        #expect(!source.contains("Returns empty string on rejection"))
        #expect(udl.contains("[Throws=TextNormalizationError]"))
        #expect(noteStorage.contains("try sanitizeAndNormalize(input: value)"))
        #expect(!noteStorage.contains("uniffi_epistemos_core_checksum_func_sanitize_and_normalize()"))
    }

    @Test("activity tracker lane avoids unchecked sendable on simple local state containers")
    func activityTrackerLaneAvoidsUncheckedSendableOnSimpleLocalStateContainers() throws {
        let activityTracker = try loadRepoTextFile("Epistemos/State/ActivityTracker.swift")
        let substrateTypes = try loadRepoTextFile("Epistemos/State/CognitiveSubstrateTypes.swift")

        #expect(!activityTracker.contains("@unchecked Sendable"))
        #expect(activityTracker.contains("actor ActivityFlagState"))
        #expect(!substrateTypes.contains("@unchecked Sendable"))
        #expect(substrateTypes.contains("struct RingBuffer<T: Sendable>: Sendable"))
    }

    @Test("event store graph builder and branded ids avoid unchecked sendable wrappers")
    func eventStoreGraphBuilderAndBrandedIdsAvoidUncheckedSendableWrappers() throws {
        let eventStore = try loadRepoTextFile("Epistemos/State/EventStore.swift")
        let graphBuilder = try loadRepoTextFile("Epistemos/Graph/GraphBuilder.swift")
        let brandedTypes = try loadRepoTextFile("Epistemos/Models/BrandedTypes.swift")

        #expect(!eventStore.contains("@unchecked Sendable"))
        #expect(eventStore.contains("final class EventStore: Sendable"))
        #expect(eventStore.contains("executeRequired(\"PRAGMA journal_mode=WAL;\")"))
        #expect(eventStore.contains("pragmaTextValue(\"PRAGMA journal_mode;\")?.lowercased() == \"wal\""))
        #expect(!graphBuilder.contains("@unchecked Sendable"))
        #expect(graphBuilder.contains("final class GraphBuilder: Sendable"))
        #expect(!brandedTypes.contains("@unchecked Sendable"))
        #expect(brandedTypes.contains("struct ChatId: BrandedId, Sendable"))
        #expect(brandedTypes.contains("struct MessageId: BrandedId, Sendable"))
    }

    @Test("note image display payload avoids unchecked sendable wrappers")
    func noteImageDisplayPayloadAvoidsUncheckedSendableWrappers() throws {
        let noteImageProcessor = try loadRepoTextFile("Epistemos/Views/Notes/NoteImageProcessor.swift")

        #expect(!noteImageProcessor.contains("@unchecked Sendable"))
        #expect(noteImageProcessor.contains("struct DisplayImage: Sendable"))
    }

    @Test("remaining production concurrency wrappers narrow unsafe state instead of unchecked sendable")
    func remainingProductionConcurrencyWrappersNarrowUnsafeStateInsteadOfUncheckedSendable() throws {
        let llmService = try loadRepoTextFile("Epistemos/Engine/LLMService.swift")
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let moLoRA = try loadRepoTextFile("Epistemos/KnowledgeFusion/MoLoRA/MoLoRAInferenceService.swift")
        let searchIndex = try loadRepoTextFile("Epistemos/Sync/SearchIndexService.swift")

        #expect(!llmService.contains("@unchecked Sendable"))
        #expect(llmService.contains("struct ProcessActivityToken: Sendable"))
        #expect(!graphState.contains("@unchecked Sendable"))
        #expect(graphState.contains("final class EngineHandleState: Sendable"))
        #expect(!moLoRA.contains("@unchecked Sendable"))
        #expect(moLoRA.contains("final class MoLoRAReadBufferState: Sendable"))
        #expect(!searchIndex.contains("@unchecked Sendable"))
        #expect(searchIndex.contains("private final class OffloadedSearchState<T: Sendable>: Sendable"))
        #expect(searchIndex.contains("private final class OffloadedSearchStateBox<T: Sendable>: Sendable"))
        #expect(searchIndex.contains("private final class SQLiteCancellationContext: Sendable"))
        #expect(searchIndex.contains("func passiveCheckpoint() throws"))
        #expect(searchIndex.contains("db.checkpoint(.passive)"))
        #expect(searchIndex.contains("case journalModeRejected(String)"))
    }

    @Test("night brain now checkpoints the search index during idle maintenance")
    func nightBrainCheckpointsSearchIndexDuringIdleMaintenance() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let nightBrain = try loadRepoTextFile("Epistemos/State/NightBrainService.swift")

        #expect(bootstrap.contains("searchIndexProvider: { @MainActor [weak vaultSync] in"))
        #expect(nightBrain.contains("case searchIndexPassiveCheckpoint = \"search_index_passive_checkpoint\""))
        #expect(nightBrain.contains("guard let searchIndex = await MainActor.run(body: { searchIndexProvider() }) else {"))
        #expect(nightBrain.contains("throw JobExecutionError.missingSearchIndex"))
        #expect(nightBrain.contains("try searchIndex.passiveCheckpoint()"))
        #expect(!nightBrain.contains("try? searchIndex?.passiveCheckpoint()"))
    }

    @Test("vault parser uses nonisolated UniFFI helpers without main actor hops")
    func vaultParserUsesNonisolatedRustHelpersWithoutMainActorHops() throws {
        let parser = try loadRepoTextFile("Epistemos/KnowledgeFusion/DataIngestion/VaultParser.swift")

        #expect(parser.contains("let classification = classifyDocument(content: rawText)"))
        #expect(parser.contains("let filtered = filterBoilerplate(content: rawText)"))
        #expect(!parser.contains("await MainActor.run { classifyDocument(content: rawText) }"))
        #expect(!parser.contains("await MainActor.run { filterBoilerplate(content: rawText) }"))
    }

    @Test("test helper probes avoid unchecked sendable wrappers")
    func testHelperProbesAvoidUncheckedSendableWrappers() throws {
        let omegaAgentTests = try loadRepoTextFile("EpistemosTests/OmegaAgentTests.swift")
        let noteEditorLayoutTests = try loadRepoTextFile("EpistemosTests/NoteEditorLayoutTests.swift")
        let noteFileStorageTests = try loadRepoTextFile("EpistemosTests/NoteFileStorageTests.swift")
        let pipelineServiceTests = try loadRepoTextFile("EpistemosTests/PipelineServiceTests.swift")
        let vaultSyncAuditTests = try loadRepoTextFile("EpistemosTests/VaultSyncServiceAuditTests.swift")
        let textKit2FoundationTests = try loadRepoTextFile("EpistemosTests/TextKit2FoundationTests.swift")

        #expect(!omegaAgentTests.contains("@unchecked Sendable"))
        #expect(omegaAgentTests.contains("private final class NotificationFlag: Sendable"))
        #expect(!noteEditorLayoutTests.contains("@unchecked Sendable"))
        #expect(noteEditorLayoutTests.contains("private final class LayoutNotificationCounts: Sendable"))
        #expect(!noteFileStorageTests.contains("@unchecked Sendable"))
        #expect(noteFileStorageTests.contains("private final class EventSink: Sendable"))
        #expect(!pipelineServiceTests.contains("@unchecked Sendable"))
        #expect(pipelineServiceTests.contains("private final class ActivityProbe: Sendable"))
        #expect(!vaultSyncAuditTests.contains("@unchecked Sendable"))
        #expect(vaultSyncAuditTests.contains("final class ManagedBodyCountProbe: Sendable"))
        #expect(!textKit2FoundationTests.contains("@unchecked Sendable"))
        #expect(textKit2FoundationTests.contains("private final class NotificationRecorder: Sendable"))
    }

    @Test("startup integrity check runs before automatic vault restore")
    func startupIntegrityCheckRunsBeforeAutomaticVaultRestore() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(bootstrap.contains("struct StartupIntegrityReport: Sendable"))
        #expect(bootstrap.contains("func performStartupIntegrityCheck() async -> StartupIntegrityReport"))
        #expect(bootstrap.contains("static func startupIntegritySamplePageIdsForTesting"))
        #expect(bootstrap.contains("static func startupIntegrityReportForTesting"))
        #expect(bootstrap.contains("vaultSync.startupBookmarkValidation()"))
        #expect(bootstrap.contains("func runAutomaticVaultRestoreAfterLaunchIfNeeded() async"))
        #expect(bootstrap.contains("let report = await performStartupIntegrityCheck()"))
        #expect(bootstrap.contains("guard !report.shouldBlockAutomaticVaultRestore else"))
        #expect(bootstrap.contains("vaultSync.restoreVaultFromBookmark()"))
        #expect(app.contains("await bootstrap.runAutomaticVaultRestoreAfterLaunchIfNeeded()"))
        #expect(vaultSync.contains("func startupBookmarkValidation() -> VaultBookmarkStartupValidation"))
    }

    @Test("launch integrity gate lives above RootView and owns automatic vault restore")
    func launchIntegrityGateLivesAboveRootViewAndOwnsAutomaticVaultRestore() throws {
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(app.contains("private struct LaunchIntegrityGateView<Content: View>: View"))
        #expect(app.contains("await bootstrap.runAutomaticVaultRestoreAfterLaunchIfNeeded()"))
        #expect(app.contains("await bootstrap.performPrimaryLaunchInitialization()"))
        #expect(app.contains("LaunchIntegrityGateView(bootstrap: bootstrap)"))
        #expect(!rootView.contains("performStartupIntegrityCheck"))
        #expect(!rootView.contains("restoreVaultFromBookmark"))
    }

    @Test("initial vault import is offloaded through a nonisolated helper")
    func initialVaultImportIsOffloadedThroughNonisolatedHelper() throws {
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(vaultSync.contains("await Self.performInitialImport("))
        #expect(vaultSync.contains("private nonisolated static func performInitialImport("))
        #expect(vaultSync.contains("private nonisolated static func rebuildInstantRecallIndex("))
    }

    @Test("shared scheme keeps test bundle out of normal app builds")
    func sharedSchemeKeepsTestBundleOutOfNormalAppBuilds() throws {
        let scheme = try loadRepoTextFile("Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme")
        let spec = try loadRepoTextFile("project.yml")
        let buildAction = scheme.components(separatedBy: "<TestAction").first ?? scheme

        #expect(spec.contains("targets:\n        Epistemos: all"))
        #expect(!spec.contains("EpistemosTests: test"))
        #expect(scheme.contains("BlueprintName = \"EpistemosTests\""))
        #expect(scheme.contains("buildForTesting = \"YES\""))
        #expect(scheme.contains("buildForRunning = \"YES\""))
        #expect(scheme.contains("buildForProfiling = \"YES\""))
        #expect(scheme.contains("buildForArchiving = \"YES\""))
        #expect(!buildAction.contains("BuildableName = \"EpistemosTests.xctest\""))
    }

    @Test("installed local fallback prefers the strongest supported model on the current hardware")
    func installedLocalFallbackPrefersTheStrongestSupportedModel() throws {
        let manager = try loadRepoTextFile("Epistemos/Engine/LocalModelInfrastructure.swift")

        #expect(manager.contains("guard let modelID = inference.releaseSelectableInstalledLocalTextModelIDs.last else {"))
        #expect(!manager.contains(".first(where: { installRecords[$0] != nil && inference.hardwareCapabilitySnapshot.supports(textModelID: $0) })"))
    }

    @Test("local model refresh only persists the manifest when cleanup changes records")
    func localModelRefreshOnlyPersistsManifestWhenCleanupChangesRecords() throws {
        let manager = try loadRepoTextFile("Epistemos/Engine/LocalModelInfrastructure.swift")

        #expect(manager.contains("let removedLegacyInstalls = purgeLegacyNonQwenInstalls()"))
        #expect(manager.contains("let removedMissingInstalls = pruneMissingInstalls()"))
        #expect(manager.contains("let removedStaleRevisionInstalls = pruneStaleRevisionInstalls()"))
        #expect(manager.contains("if removedLegacyInstalls || removedMissingInstalls || removedStaleRevisionInstalls {"))
        #expect(manager.contains("private func pruneMissingInstalls() -> Bool"))
        #expect(manager.contains("private func pruneStaleRevisionInstalls() -> Bool"))
        #expect(manager.contains("guard prunedRecords != installRecords else { return false }"))
        #expect(!manager.contains("try? persistManifest()"))
    }

    @Test("bootstrap throttles local model refreshes and the local runtime serializes request turns")
    func bootstrapThrottlesRefreshAndRuntimeSerializesTurns() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let runtime = try loadRepoTextFile("Epistemos/Engine/MLXInferenceService.swift")

        #expect(bootstrap.contains("private final class LocalModelRefreshThrottle"))
        #expect(bootstrap.contains("private let localModelRefreshThrottle: LocalModelRefreshThrottle"))
        #expect(bootstrap.contains("let localModelRefreshThrottle = LocalModelRefreshThrottle("))
        #expect(bootstrap.contains("localModelRefreshThrottle.refreshIfNeeded()"))
        #expect(!bootstrap.contains("prepareForRequest: {\n                localModelManager.refreshFromDisk()"))
        #expect(!bootstrap.contains("prepareForRouting: {\n                localModelManager.refreshFromDisk()"))

        #expect(runtime.contains("actor LocalMLXRequestGate"))
        #expect(runtime.contains("private let requestGate = LocalMLXRequestGate()"))
        #expect(runtime.contains("await requestGate.acquire()"))
        #expect(runtime.contains("await requestGate.release()"))
        #expect(runtime.contains("let idleMemoryPolicy: LocalMLXMemoryPolicy"))
        #expect(runtime.contains("private func applyActiveMemoryPolicy"))
        #expect(runtime.contains("private func applyIdleMemoryPolicy"))
        #expect(runtime.contains("applyActiveMemoryPolicy(policy)"))
        #expect(runtime.contains("applyIdleMemoryPolicy(policy)"))
    }

    @Test("streaming local mlx path preserves and persists ssm sessions")
    func streamingLocalMLXPathPreservesAndPersistsSSMSessions() throws {
        let runtime = try loadRepoTextFile("Epistemos/Engine/MLXInferenceService.swift")

        #expect(runtime.contains("if isSSM,\n                       let existing = self.persistentSSMSession,"))
        #expect(runtime.contains("self.persistentSSMSession = session"))
        #expect(runtime.contains("let resumed = await self.resumeSSMState("))
        #expect(runtime.contains("SSM stream resumed with cached state"))
        #expect(runtime.contains("await self.notifySSMStateService("))
    }

    @Test("chat and note chat release oversized streaming buffers after reset paths")
    func chatAndNoteChatReleaseOversizedStreamingBuffersAfterResetPaths() throws {
        let chatState = try loadRepoTextFile("Epistemos/State/ChatState.swift")
        let noteChatState = try loadRepoTextFile("Epistemos/State/NoteChatState.swift")

        #expect(chatState.contains("private func releaseStreamingTextStorage()"))
        #expect(chatState.contains("streamingText.removeAll(keepingCapacity: false)"))
        #expect(chatState.contains("streamBuffer.reset(releaseCapacity: true)"))

        #expect(noteChatState.contains("private func clearResponseTextBuffer()"))
        #expect(noteChatState.contains("responseText.removeAll(keepingCapacity: false)"))
        #expect(noteChatState.contains("private func resetStreamBuffer(releaseCapacity: Bool = false)"))
        #expect(noteChatState.contains("resetStreamBuffer(releaseCapacity: true)"))
        #expect(noteChatState.contains("responseText.reserveCapacity(16_384)"))
    }

    @Test("bootstrap refreshes prepared retrieval runtime state on app activation")
    func bootstrapRefreshesPreparedRetrievalRuntimeStateOnActivation() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(bootstrap.contains("private func applyPreparedRetrievalRuntimeConfiguration(_ configuration: PreparedRetrievalRuntimeConfiguration?)"))
        #expect(bootstrap.contains("private func refreshPreparedRetrievalRuntimeConfigurationIfNeeded()"))
        #expect(bootstrap.contains("preparedModelRegistry.load()"))
        #expect(bootstrap.contains("queryEngine.applyPreparedRetrievalRuntimeConfiguration(configuration)"))
        #expect(bootstrap.contains("graphState.applyPreparedRetrievalRuntimeConfiguration(configuration)"))
        #expect(bootstrap.contains("self?.refreshPreparedRetrievalRuntimeConfigurationIfNeeded()"))
    }

    @MainActor
    @Test("bootstrap loads the prepared model registry")
    func bootstrapLoadsPreparedModelRegistry() async {
        let bootstrap = AppBootstrap()

        #expect(bootstrap.preparedModelRegistryState.primaryRetriever?.servedModelID == "BAAI/bge-m3")
        #expect(bootstrap.preparedModelRegistryState.lastErrorMessage == nil)
    }

    @MainActor
    @Test("bootstrap propagates prepared retrieval assets into the live graph and query runtime")
    func bootstrapPropagatesPreparedRetrievalAssets() async throws {
        let bootstrap = AppBootstrap()

        #expect(bootstrap.preparedModelRegistryState.primaryRetriever?.servedModelID == "BAAI/bge-m3")

        let graphAssets = try #require(bootstrap.graphState.preparedRetrievalRuntimeConfiguration)
        let queryAssets = try #require(bootstrap.queryEngine.preparedRetrievalRuntimeConfiguration)
        let embeddingAssets = try #require(bootstrap.graphState.embeddingService.preparedRetrievalRuntimeConfiguration)

        #expect(graphAssets.retriever.servedModelID == "BAAI/bge-m3")
        #expect(graphAssets.retriever.resolvedDownloadPath?.hasSuffix("/PreparedModels/retrieval/bge-m3/source") == true)
        #expect(queryAssets == graphAssets)
        #expect(embeddingAssets == graphAssets)
    }

    @MainActor
    @Test("bootstrap surfaces the prepared retrieval runtime state from the live asset layout")
    func bootstrapSurfacesThePreparedRetrievalRuntimeStateFromTheLiveAssetLayout() async throws {
        let bootstrap = AppBootstrap()
        let configuration = try #require(bootstrap.preparedModelRegistryState.retrievalRuntimeConfiguration)
        let layout = try #require(configuration.assetLayout)

        #expect(layout.retrieverSourceRoot.hasSuffix("/PreparedModels/retrieval/bge-m3/source"))
        if let manifest = layout.indexManifest {
            #expect(FileManager.default.fileExists(atPath: layout.embeddingsPath))
            #expect(FileManager.default.fileExists(atPath: layout.documentsPath))
            #expect(manifest.documentCount > 8)
            #expect(manifest.sourceDatabasePath?.hasSuffix("/Epistemos/search.sqlite") == true)
            #expect(manifest.sourceDatabaseModifiedAt != nil)
        } else {
            #expect(!layout.isBuilt)
        }

        let allowedModes: [PreparedRetrievalExecutionMode] = [
            .preparedIndexReady(retrieverModelID: "BAAI/bge-m3"),
            .preparedAssetsPendingIndex(retrieverModelID: "BAAI/bge-m3"),
            .appleEmbeddingFallback,
        ]
        #expect(allowedModes.contains(where: { $0 == bootstrap.graphState.preparedRetrievalExecutionMode }))
        #expect(allowedModes.contains(where: { $0 == bootstrap.queryEngine.preparedRetrievalExecutionMode }))
        #expect(allowedModes.contains(where: { $0 == bootstrap.graphState.embeddingService.preparedRetrievalExecutionMode }))
    }

    @Test("settings inference surface does not refresh local models on open")
    func settingsInferenceSurfaceDoesNotRefreshOnOpen() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(settings.contains("Button(\"Refresh\")"))
        #expect(!settings.contains(".onAppear {\n            localModelManager.refreshFromDisk()"))
        #expect(!settings.contains(".task {\n            localModelManager.refreshFromDisk()"))
    }

    @Test("settings and retired omega surfaces avoid invalid runtime symbols and stale progress chrome")
    func settingsAndOmegaSurfacesAvoidInvalidRuntimeSymbolsAndProgressScaling() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let omega = try loadRepoTextFile("Epistemos/Views/Omega/OmegaPanel.swift")

        #expect(!settings.contains("memorychip.slash"))
        #expect(settings.contains("exclamationmark.triangle"))

        #expect(omega.contains("Text(\"Unified Chat\")"))
        #expect(omega.contains("All capabilities"))
        #expect(!omega.contains("ProgressView()"))
        #expect(!omega.contains(".scaleEffect(0.7)"))
    }

    @Test("chat, note, graph, and settings surfaces defer on-appear state mutations off the active view update")
    func statefulSurfacesDeferOnAppearMutations() throws {
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let chatView = try loadRepoTextFile("Epistemos/Views/Chat/ChatView.swift")
        let noteSidebar = try loadRepoTextFile("Epistemos/Views/Notes/NoteChatSidebar.swift")
        let chatSidebar = try loadRepoTextFile("Epistemos/Views/Chat/ChatSidebarView.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(miniChat.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(chatView.contains(".onAppear {\n                    Task { @MainActor in"))
        #expect(noteSidebar.contains(".onAppear {\n                Task { @MainActor in"))
        #expect(chatSidebar.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(settings.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(inspector.contains(".onAppear {\n            Task { @MainActor in"))
        #expect(workspace.contains(".onAppear {\n                Task { @MainActor in"))
    }

    @Test("settings window keeps a native source-list layout with a persistent sidebar toggle")
    func settingsWindowUsesNativeSourceListChrome() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let utilityManager = try loadRepoTextFile("Epistemos/App/UtilityWindowManager.swift")

        #expect(settings.contains(".listStyle(.sidebar)"))
        #expect(settings.contains("Image(systemName: \"sidebar.left\")"))
        #expect(settings.contains("ToolbarItem(placement: .navigation)"))
        #expect(settings.contains("toggleSidebar()"))
        #expect(utilityManager.contains("toolbar.showsBaselineSeparator = false"))
        #expect(utilityManager.contains("panel.toolbarStyle = .unifiedCompact"))
    }

    @Test("utility panels activate and order front when shown")
    func utilityPanelsActivateAndOrderFrontWhenShown() throws {
        let utilityManager = try loadRepoTextFile("Epistemos/App/UtilityWindowManager.swift")

        #expect(utilityManager.contains("NSApp.activate(ignoringOtherApps: true)"))
        #expect(utilityManager.contains("window.orderFrontRegardless()"))
        #expect(utilityManager.contains("window.makeKeyAndOrderFront(nil)"))
    }

    @Test("retired omega settings no longer advertise old training experiments")
    func omegaSettingsTrainingCopyStaysExperimentalAndTraceFocused() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/OmegaSettingsDetailView.swift")
        let appSettings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(settings.contains("Agent settings are now part of the main chat configuration."))
        #expect(!settings.contains("Overnight adapter training (Experimental)"))
        #expect(!settings.contains("Embodied data capture (Experimental)"))
        #expect(appSettings.contains("Knowledge Fusion (Experimental)"))
    }

    @Test("omega automation support retains backend permission plumbing and plist disclosure")
    func omegaSurfacesExposeAutomationPermission() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/OmegaSettingsDetailView.swift")
        let panel = try loadRepoTextFile("Epistemos/Views/Omega/OmegaPanel.swift")
        let permissions = try loadRepoTextFile("Epistemos/Omega/OmegaPermissions.swift")
        let infoPlist = try loadRepoTextFile("Epistemos-Info.plist")

        #expect(settings.contains("Agent settings are now part of the main chat configuration."))
        #expect(panel.contains("Unified Chat"))

        #expect(permissions.contains("func requestAutomationAccess() async"))
        #expect(permissions.contains("func automationPermissionState(promptIfNeeded: Bool) async -> Bool"))
        #expect(permissions.contains("func openAutomationSettings()"))
        #expect(permissions.contains("ensureAutomationTargetIsRunning()"))
        #expect(permissions.contains("com.apple.systemevents"))

        #expect(infoPlist.contains("NSAppleEventsUsageDescription"))
    }

    @Test("advanced settings surfaces explain what the feature actually does")
    func advancedSettingsSurfacesExplainWhatTheFeatureActuallyDoes() throws {
        let omega = try loadRepoTextFile("Epistemos/Views/Settings/OmegaSettingsDetailView.swift")
        let cognitive = try loadRepoTextFile("Epistemos/Views/Settings/CognitiveSettingsSection.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(omega.contains("Agent settings are now part of the main chat configuration."))
        #expect(cognitive.contains("Stores compact activity artifacts"))
        #expect(cognitive.contains("No keystroke logging"))
        #expect(settings.contains("Routing decides which model path handles each request"))
        #expect(settings.contains("Your vault is the on-disk markdown workspace"))
    }

    @Test("knowledge fusion copy explains adapters without claiming a new base model")
    func knowledgeFusionCopyExplainsAdaptersWithoutClaimingANewBaseModel() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let trainOnVault = try loadRepoTextFile("Epistemos/KnowledgeFusion/UI/TrainOnVaultView.swift")
        let feedback = try loadRepoTextFile("Epistemos/KnowledgeFusion/UI/FeedbackIndicatorView.swift")

        #expect(settings.contains("Knowledge Fusion trains adapters on top of your local model"))
        #expect(settings.contains("It does not replace the base model"))
        #expect(trainOnVault.contains("This is personalization for your installed local model"))
        #expect(feedback.contains("Accepts and rejects are lightweight preference signals"))
    }

    @Test("note editor still suppresses binding sync churn during AI token flushes")
    func noteEditorStillSuppressesStreamingBindingChurn() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")

        #expect(source.contains("var isFlushingTokens = false"))
        #expect(source.contains("guard !isFlushingTokens else { return }"))
        #expect(source.contains("Task.sleep(for: .milliseconds(300))"))
    }

    @Test("query runtime hot path avoids legacy full-match node sorting")
    func queryRuntimeHotPathAvoidsLegacyFullMatchNodeSorting() throws {
        let source = try loadRepoTextFile("Epistemos/Engine/QueryRuntime.swift")

        #expect(!source.contains("Array(graphStore.nodes.values)"))
        #expect(!source.contains("Array(graphStore.edges.values)"))
        #expect(!source.contains("Set(graphStore.nodes.keys)"))
        #expect(!source.contains("graphStore.nodes.values.compactMap"))
        #expect(!source.contains("graphStore.edgesByNode[scopedNodeID]"))
        #expect(!source.contains("graphStore.nodes.values.filter"))
        #expect(!source.contains("from: graphStore.nodes.values"))
        #expect(!source.contains("results.sort { $0.createdAt > $1.createdAt }"))
        #expect(source.contains("graphStore.nodes(matchingLabelContains: labelContains, types: filter.types)"))
        #expect(source.contains("graphStore.edges(for: scopedNodeID)"))
        #expect(source.contains("graphStore.nodes(matchingLabelContains: text)"))
        #expect(source.contains("graphStore.firstNode(ofType: type)?.id"))
        #expect(source.contains("graphStore.forEachNodeNewestFirst(ofTypes: filter.types)"))
        #expect(source.contains("graphStore.forEachNodeNewestFirst { node in"))
        #expect(!source.contains("graphStore.nodes.values.first { $0.type == type }"))
        #expect(!source.contains("graphStore.adjacency[$0.id]"))
        #expect(!source.contains("graphStore.adjacency[$1.id]"))
        #expect(!source.contains("graphStore.nodes[$0.id]?.createdAt"))
        #expect(!source.contains("graphStore.nodes[$1.id]?.createdAt"))
        #expect(!source.contains("graphStore.nodes[$0.id]?.updatedAt"))
        #expect(!source.contains("graphStore.nodes[$1.id]?.updatedAt"))
        #expect(source.contains("if $0.connectionCount == $1.connectionCount"))
        #expect(source.contains("return $0.connectionCount > $1.connectionCount"))
        #expect(source.contains("let a = $0.createdAt"))
        #expect(source.contains("let b = $1.createdAt"))
        #expect(source.contains("let a = $0.updatedAt"))
        #expect(source.contains("let b = $1.updatedAt"))
    }

    @Test("graph store source lookup uses the direct source index")
    func graphStoreSourceLookupUsesDirectSourceIndex() throws {
        let source = try loadRepoTextFile("Epistemos/Graph/GraphStore.swift")

        #expect(source.contains("private var _sourceLookup: [SourceLookupKey: String] = [:]"))
        #expect(source.contains("let key = SourceLookupKey(sourceId: sourceId, type: type)"))
        #expect(source.contains("_sourceLookup[key]"))
        #expect(!source.contains("nodes.values.first { $0.sourceId == sourceId && $0.type == type }"))
    }

    @Test("graph store type lookup uses the direct type index")
    func graphStoreTypeLookupUsesDirectTypeIndex() throws {
        let source = try loadRepoTextFile("Epistemos/Graph/GraphStore.swift")

        #expect(source.contains("private var _typeLookup: [GraphNodeType: Set<String>] = [:]"))
        #expect(source.contains("(_typeLookup[type] ?? []).compactMap { nodes[$0] }"))
        #expect(source.contains("func nodes(ofTypes types: [GraphNodeType]) -> [GraphNodeRecord]"))
        #expect(source.contains("guard let nodeID = _typeLookup[type]?.first else { return nil }"))
        #expect(!source.contains("nodes.values.filter { $0.type == type }"))
    }

    @Test("semantic clustering stays behind apple fallback and the shared embedding boundary")
    func semanticClusteringStaysBehindAppleFallbackAndSharedEmbeddingBoundary() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let clustering = try loadRepoTextFile("Epistemos/Graph/SemanticClusterService.swift")
        let embeddings = try loadRepoTextFile("Epistemos/Graph/EmbeddingService.swift")
        let infrastructure = try loadRepoTextFile("Epistemos/Engine/LocalModelInfrastructure.swift")
        let controls = try loadRepoTextFile("Epistemos/Views/Graph/GraphFloatingControls.swift")

        #expect(graphState.contains("var semanticClusteringAvailable: Bool"))
        #expect(graphState.contains("guard semanticClusteringAvailable else"))
        #expect(graphState.contains("func canRunFallbackSemanticSearch() -> Bool"))
        #expect(graphState.contains("func semanticSearch(query: String, limit: Int = 20)"))
        #expect(graphState.contains("for hit in semanticSearch(query: query, limit: limit)"))
        #expect(graphState.contains("embeddingService.computeFallbackSemanticClusters(store: store)"))
        #expect(!clustering.contains("NLEmbedding.wordEmbedding"))
        #expect(infrastructure.contains("var usesSwiftEmbeddingFallback: Bool"))
        #expect(embeddings.contains("swiftEmbeddingFallbackActive = preparedRetrievalExecutionMode.usesSwiftEmbeddingFallback"))
        #expect(embeddings.contains("preparedQueryEmbeddingActive = preparedRetrievalExecutionMode.hasPreparedIndexRuntime"))
        #expect(embeddings.contains("guard swiftEmbeddingFallbackActive || preparedQueryEmbeddingActive else { return nil }"))
        #expect(embeddings.contains("guard swiftEmbeddingFallbackActive else { return [:] }"))
        #expect(graphState.contains("private func preparedSemanticSearch(query: String, limit: Int) -> [GraphStore.SearchHit]?"))
        #expect(graphState.contains("manifestPath.withCString"))
        #expect(graphState.contains("graph_engine_load_prepared_retrieval_index(engine, $0)"))
        #expect(graphState.contains("graph_engine_prepared_retrieval_search("))
        #expect(!controls.contains("semanticClusterToggle"))
        #expect(!controls.contains(".disabled(!available)"))
    }

    @Test("fallback semantic query path requires a populated matching Rust embedding store")
    func fallbackSemanticQueryPathRequiresPopulatedMatchingRustStore() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let queryRuntime = try loadRepoTextFile("Epistemos/Engine/QueryRuntime.swift")

        #expect(graphState.contains("func canRunFallbackSemanticSearch() -> Bool"))
        #expect(graphState.contains("func semanticSearch(query: String, limit: Int = 20)"))
        #expect(graphState.contains("graph_engine_embedding_count(engine) > 0"))
        #expect(graphState.contains("Int(graph_engine_embedding_dimension(engine)) == embeddingService.dimension"))
        #expect(queryRuntime.contains("graphState.semanticSearch(query: query, limit: limit)"))
    }

    @Test("native semantic runtime exposes an explicit dimension reset boundary")
    func nativeSemanticRuntimeExposesDimensionResetBoundary() throws {
        let rustFFI = try loadRepoTextFile("graph-engine/src/lib.rs")
        let header = try loadRepoTextFile("graph-engine-bridge/graph_engine.h")
        let swiftWrapper = try loadRepoTextFile("Epistemos/Graph/GraphEngine.swift")

        #expect(rustFFI.contains("pub extern \"C\" fn graph_engine_embedding_dimension"))
        #expect(rustFFI.contains("pub extern \"C\" fn graph_engine_reset_embedding_dimension"))
        #expect(header.contains("uint32_t graph_engine_embedding_dimension(Engine* engine);"))
        #expect(header.contains("uint8_t graph_engine_reset_embedding_dimension(Engine* engine, uint32_t dim);"))
        #expect(swiftWrapper.contains("func semanticEmbeddingDimension() -> Int"))
        #expect(swiftWrapper.contains("func resetSemanticEmbeddingDimension(to dimension: Int) -> Bool"))
    }

    @Test("retired graph ffi controls stay out of the live bridge surface")
    func retiredGraphFFIControlsStayRemoved() throws {
        let rustFFI = try loadRepoTextFile("graph-engine/src/lib.rs")
        let header = try loadRepoTextFile("graph-engine-bridge/graph_engine.h")

        let retiredExports = [
            "graph_engine_set_lite_mode",
            "graph_engine_set_time_filter",
            "graph_engine_add_version",
            "graph_engine_get_version_count",
            "graph_engine_dialogue_open",
            "graph_engine_dialogue_close",
            "graph_engine_dialogue_set_streaming",
            "graph_engine_dialogue_screen_rect",
            "graph_engine_dialogue_node_screen_pos",
            "graph_engine_dialogue_is_active",
        ]

        for symbol in retiredExports {
            #expect(!rustFFI.contains(symbol))
            #expect(!header.contains(symbol))
        }
    }

    @Test("live local ai surfaces stay free of sidecar residue")
    func liveLocalAISurfacesStayFreeOfSidecarResidue() throws {
        let llm = try loadRepoTextFile("Epistemos/Engine/LLMService.swift")
        let triage = try loadRepoTextFile("Epistemos/Engine/TriageService.swift")
        let inference = try loadRepoTextFile("Epistemos/State/InferenceState.swift")

        for banned in [
            "LocalSidecar",
            "mlx-openai-server",
            "http://127.0.0.1",
        ] {
            #expect(!llm.contains(banned))
            #expect(!triage.contains(banned))
            #expect(!inference.contains(banned))
        }
    }

    @Test("native cleanup fallback grep uses word boundaries for legacy runtime bans")
    func nativeCleanupFallbackGrepUsesWordBoundaries() throws {
        let scan = try loadRepoTextFile("scripts/audit/native_cleanup_scan.sh")

        #expect(scan.contains(#"\\breasoner\\b"#))
        #expect(scan.contains(#"\\bSSE\\b"#))
        #expect(!scan.contains("|SSE'"))
        #expect(scan.contains("ast-grep scan --rule"))
        #expect(scan.contains("${ROOT_DIR}/Epistemos/Engine"))
        #expect(scan.contains("${ROOT_DIR}/Epistemos/Graph"))
        #expect(scan.contains("${ROOT_DIR}/Epistemos/Views/Graph"))
        #expect(scan.contains("periphery scan --project Epistemos.xcodeproj --schemes Epistemos --targets Epistemos --format xcode"))
        #expect(scan.contains("cd '${ROOT_DIR}/graph-engine' && cargo machete"))
    }

    @Test("chat coordinator caches manifest note search fields off the main actor")
    func chatCoordinatorCachesManifestNoteSearchFieldsOffTheMainActor() throws {
        let coordinator = try loadRepoTextFile("Epistemos/App/ChatCoordinator.swift")

        #expect(coordinator.contains("private struct PreparedManifestSearchEntry"))
        #expect(coordinator.contains("private nonisolated static func preparedManifestSearchEntries("))
        #expect(coordinator.contains("private nonisolated static func autoMatchedReferencedNoteIDs("))
        #expect(coordinator.contains("private nonisolated static func noteSearchScore("))
        #expect(coordinator.contains("let preparedEntries = preparedManifestSearchEntries(for: manifest)"))
        #expect(coordinator.contains("let entriesByPageID = Dictionary("))
    }

    @Test("prepared retrieval scorer uses a dedicated candidate list ffi")
    func preparedRetrievalScorerUsesDedicatedCandidateListFFI() throws {
        let queryRuntime = try loadRepoTextFile("Epistemos/Engine/QueryRuntime.swift")
        let rustFFI = try loadRepoTextFile("graph-engine/src/lib.rs")
        let header = try loadRepoTextFile("graph-engine-bridge/graph_engine.h")

        #expect(queryRuntime.contains("graph_engine_prepared_retrieval_score_page_ids("))
        #expect(queryRuntime.contains("graph_engine_free_prepared_retrieval_candidates(list)"))
        #expect(queryRuntime.contains("result.page_id"))
        #expect(!queryRuntime.contains("graph_engine_free_search_results(results, count)"))
        #expect(header.contains("GraphEnginePreparedRetrievalCandidate"))
        #expect(header.contains("GraphEnginePreparedRetrievalCandidateList"))
        #expect(header.contains("graph_engine_free_prepared_retrieval_candidates"))
        #expect(rustFFI.contains("pub struct GraphEnginePreparedRetrievalCandidate"))
        #expect(rustFFI.contains("pub struct GraphEnginePreparedRetrievalCandidateList"))
        #expect(rustFFI.contains("pub extern \"C\" fn graph_engine_free_prepared_retrieval_candidates"))
    }

    @Test("strict verification suite keeps compiler and purge gates wired")
    func strictVerificationSuiteKeepsCompilerAndPurgeGatesWired() throws {
        let verify = try loadRepoTextFile("scripts/audit/verify.sh")
        let cleanupSuite = try loadRepoTextFile("scripts/audit/cleanup_suite.sh")

        #expect(verify.contains("cargo clippy --manifest-path graph-engine/Cargo.toml --all-targets --all-features -- -D warnings -D dead_code"))
        #expect(verify.contains("cargo test --manifest-path graph-engine/Cargo.toml"))
        #expect(verify.contains("native_cleanup_scan.sh"))
        #expect(verify.contains("OTHER_SWIFT_FLAGS='\\$(inherited) -Xfrontend -strict-concurrency=complete'"))
        #expect(verify.contains("MallocStackLogging=1"))
        #expect(verify.contains("leaks Epistemos"))
        #expect(verify.contains("powermetrics --samplers gpu_power"))
        #expect(cleanupSuite.contains("./scripts/audit/verify.sh"))
    }

    @Test("landing surface no longer mounts live cursor fx overlays or controls")
    func landingSurfaceNoLongerMountsLiveCursorFXOverlaysOrControls() throws {
        let landingView = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let rootView = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let pageShell = try loadRepoTextFile("Epistemos/Views/Shell/PageShell.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let uiState = try loadRepoTextFile("Epistemos/State/UIState.swift")
        let liquidGreeting = try loadRepoTextFile("Epistemos/Views/Landing/LiquidGreeting.swift")

        #expect(!landingView.contains("currentCursorSurface"))
        #expect(!landingView.contains("landingWakeVocabulary"))
        #expect(!landingView.contains("ui.landingCursorVisibilityMode.shows(on: surface)"))
        #expect(!landingView.contains("pointerState.registerTap(at: value.location)"))
        #expect(!landingView.contains("LandingASCIIWakeField"))
        #expect(!landingView.contains("LandingPointerState"))
        #expect(!rootView.contains("Cursor FX"))
        #expect(!rootView.contains("LandingCursorControlsView"))
        #expect(!rootView.contains("cursorVisible"))
        #expect(!settings.contains("Cursor Visibility"))
        #expect(!settings.contains("Cursor Animation"))
        #expect(!liquidGreeting.contains("cursorBlinkLoop"))
        #expect(!liquidGreeting.contains("cursorVisible"))
        #expect(!pageShell.contains("cursorVisible"))
        #expect(!uiState.contains("var landingCursorAnimationEnabled"))
        #expect(!uiState.contains("var landingCursorVisibilityMode"))
        #expect(uiState.contains("\"epistemos.landingCursorAnimationEnabled\""))
    }

    @Test("command palette source files are removed from the app")
    func commandPaletteSourceFilesAreRemoved() throws {
        let repoRoot = try sourceMirrorRootURL()

        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Landing/CommandPaletteOverlay.swift").path))
        #expect(!FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Epistemos/Views/Landing/CommandPaletteWindowController.swift").path))
    }

    @Test("search index uses a user-initiated query queue for interactive full text search")
    func searchIndexUsesUserInitiatedQueryQueueForInteractiveSearch() throws {
        let searchIndex = try loadRepoTextFile("Epistemos/Sync/SearchIndexService.swift")

        #expect(searchIndex.contains("DatabasePool"))
        #expect(searchIndex.contains("label: \"com.epistemos.search-index.query\""))
        #expect(searchIndex.contains("attributes: .concurrent"))
        #expect(searchIndex.contains("try await offloadSearch { [self] cancellation in"))
        #expect(searchIndex.contains("private final class OffloadedSearchStateBox"))
        #expect(searchIndex.contains("private struct OffloadedSearchCancellationProbe"))
        #expect(searchIndex.contains("private final class SQLiteCancellationContext"))
        #expect(searchIndex.contains("func check() throws"))
        #expect(searchIndex.contains("try cancellation.check()"))
        #expect(searchIndex.contains("let cancellation = OffloadedSearchCancellationProbe {"))
        #expect(searchIndex.contains("currentState.isCancelled()"))
        #expect(searchIndex.contains("return try await withTaskCancellationHandler"))
        #expect(searchIndex.contains("stateBox.cancel()"))
        #expect(searchIndex.contains("private nonisolated static func withSQLiteCancellation"))
        #expect(searchIndex.contains("sqlite3_progress_handler("))
    }

    @Test("notes sidebar caches title matches outside the render path")
    func notesSidebarCachesTitleMatchesOutsideRenderPath() throws {
        let sidebar = try loadRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")

        #expect(sidebar.contains("enum NotesSidebarSearchCachePolicy"))
        #expect(sidebar.contains("static let maxCachedQueries = 12"))
        #expect(sidebar.contains("@State private var titleSearchResults: [SidebarPageItem] = []"))
        #expect(sidebar.contains("@State private var cachedPageSearchCatalog: [SidebarPageSearchCatalogEntry] = []"))
        #expect(sidebar.contains("@State private var cachedPageSearchCatalogById: [String: SidebarPageSearchCatalogEntry] = [:]"))
        #expect(sidebar.contains("@State private var cachedPageSearchTrigramIndex = TrigramSearchIndex<String>()"))
        #expect(sidebar.contains("@State private var cachedTitleSearchResultIDsByQuery: [String: [String]] = [:]"))
        #expect(sidebar.contains("@State private var cachedBodySearchResultsByQuery: [String: [SidebarPageItem]] = [:]"))
        #expect(sidebar.contains("@State private var cachedTitleSearchQueryOrder: [String] = []"))
        #expect(sidebar.contains("@State private var cachedBodySearchQueryOrder: [String] = []"))
        #expect(sidebar.contains("refreshTitleSearchResults(query: notesUI.searchQuery)"))
        #expect(sidebar.contains("titleSearchResults + uniqueBodyMatches"))
        #expect(sidebar.contains("cachedPageSearchTrigramIndex.rebuild("))
        #expect(sidebar.contains("private func longestCachedTitleSearchPrefixIDs(for query: String) -> [String]?"))
        #expect(sidebar.contains("let matchedIDs = cachedTitleSearchResultIDsByQuery[normalizedQuery] ?? {"))
        #expect(sidebar.contains("let candidateIDs = longestCachedTitleSearchPrefixIDs(for: normalizedQuery)"))
        #expect(sidebar.contains("cachedPageSearchTrigramIndex.orderedCandidates(for: normalizedQuery)"))
        #expect(sidebar.contains("NotesSidebarSearchCachePolicy.store("))
        #expect(sidebar.contains("guard normalizedQuery.count >= 3 else"))
        #expect(sidebar.contains("if let cached = cachedBodySearchResultsByQuery[normalizedQuery]"))
        #expect(sidebar.contains("cache: &cachedBodySearchResultsByQuery"))
        #expect(sidebar.contains("private func refreshTitleSearchResults(query: String)"))
    }

    @Test("graph selection ignores redundant same-node picks")
    func graphSelectionIgnoresRedundantSameNodePicks() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let graphStore = try loadRepoTextFile("Epistemos/Graph/GraphStore.swift")
        let inspectorState = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        #expect(graphState.contains("guard selectedNodeId != id else { return }"))
        #expect(graphStore.contains("func neighborLabels(of nodeId: String) -> [String]"))
        #expect(graphStore.contains("private var neighborLabelsCache: [String: [String]] = [:]"))
        #expect(graphStore.contains("if let cached = neighborLabelsCache[nodeId]"))
        #expect(inspectorState.contains("let linkedLabels = store.neighborLabels(of: nodeId)"))
        #expect(!inspectorState.contains("store.neighbors(of: node.id).map(\\.label)"))
    }

    @Test("graph selection tracking throttles inspector position churn")
    func graphSelectionTrackingThrottlesInspectorPositionChurn() throws {
        let metalView = try loadRepoTextFile("Epistemos/Views/Graph/MetalGraphView.swift")
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")

        #expect(metalView.contains("nonisolated enum GraphInteractionRenderPolicy"))
        #expect(metalView.contains("static func selectedNodePublishDistance(isInteracting: Bool) -> CGFloat"))
        #expect(metalView.contains("static func selectedNodeSampleIntervalFrames(isInteracting: Bool) -> Int"))
        #expect(metalView.contains("private var sampledSelectedNodeId: String?"))
        #expect(metalView.contains("private var lastPublishedSelectedNodeScreenPoint: CGPoint?"))
        #expect(metalView.contains("private var selectedNodeScreenPointSampleFrame = 0"))
        #expect(metalView.contains("private func resetSelectedNodeScreenPointTracking(for graphState: GraphState?)"))
        #expect(metalView.contains("let selectedNodeSampleIntervalFrames = GraphInteractionRenderPolicy.selectedNodeSampleIntervalFrames("))
        #expect(metalView.contains("selectedNodeScreenPointSampleFrame % selectedNodeSampleIntervalFrames == 0"))
        #expect(metalView.contains("let shouldSampleSelectedNodeScreenPoint ="))
        #expect(metalView.contains("graphState?.selectedNodeScreenPoint == nil"))
        #expect(metalView.contains("lastPublishedSelectedNodeScreenPoint == nil"))
        #expect(metalView.contains("let publishDistance = GraphInteractionRenderPolicy.selectedNodePublishDistance("))
        #expect(metalView.contains("if delta > publishDistance"))
        #expect(overlay.contains("private var inspectorRepositionTask: Task<Void, Never>?"))
        #expect(overlay.contains("private var lastQueuedInspectorAnchor: CGPoint?"))
        #expect(overlay.contains("private var lastQueuedInspectorMode: NodeInspectorState.InspectorMode?"))
        #expect(overlay.contains("Reposition immediately"))
        #expect(overlay.contains("private func shouldQueueInspectorReposition("))
        #expect(overlay.contains("private var lastInspectorFrame: CGRect?"))
        #expect(overlay.contains("private func shouldApplyInspectorFrame(_ targetFrame: CGRect) -> Bool"))
    }

    @Test("graph overlay toolbar defaults to a bottom anchor before drag repositioning")
    func graphOverlayToolbarDefaultsToBottomAnchorBeforeDragRepositioning() throws {
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")

        #expect(overlay.contains("controlsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor"))
        #expect(!overlay.contains("controlsView.topAnchor.constraint(equalTo: contentView.topAnchor"))
    }

    @Test("graph full-show paths restore immersive chrome after mini mode")
    func graphFullShowPathsRestoreImmersiveChromeAfterMiniMode() throws {
        let controller = try loadRepoTextFile("Epistemos/Views/Graph/HologramController.swift")
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")

        #expect(controller.contains("private func presentFullOverlay()"))
        #expect(controller.contains("if overlay?.isMinimized == true"))
        #expect(controller.contains("overlay?.restore()"))
        #expect(controller.contains("overlay?.show()"))
        #expect(controller.contains("func show()"))
        #expect(controller.contains("presentFullOverlay()"))
        #expect(controller.contains("func revealPage(_ pageId: String)"))
        #expect(overlay.contains("if isMinimized {"))
        #expect(overlay.contains("restore()"))
        #expect(overlay.contains("restoreImmersiveChromeIfNeeded(window, metalView: metalView)"))
    }

    @Test("graph overlay bounds hidden Metal retention with a scheduled teardown")
    func graphOverlayBoundsHiddenMetalRetentionWithAScheduledTeardown() throws {
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")

        #expect(overlay.contains("private var hiddenTeardownTask: Task<Void, Never>?"))
        #expect(overlay.contains("cancelScheduledTeardown()"))
        #expect(overlay.contains("scheduleHiddenTeardown()"))
        #expect(overlay.contains("self?.metalView?.pauseEngine()"))
        #expect(overlay.contains("self?.scheduleHiddenTeardown()"))
        #expect(overlay.contains("GraphOverlayRetentionPolicy.hiddenTeardownDelay"))
        #expect(overlay.contains("guard !self.isMinimized, self.window?.isVisible != true else { return }"))
    }

    @Test("metal graph view wakes idle renderer on power mode changes")
    func metalGraphViewWakesIdleRendererOnPowerModeChanges() throws {
        let metalView = try loadRepoTextFile("Epistemos/Views/Graph/MetalGraphView.swift")

        #expect(metalView.contains("private nonisolated(unsafe) var powerModeObserver: (any NSObjectProtocol)?"))
        #expect(metalView.contains("refreshPowerModeObserver()"))
        #expect(metalView.contains("PowerGuard.modeDidChangeNotification"))
        #expect(metalView.contains("private func applyPowerModeGraphOverrides()"))
        #expect(metalView.contains("graph_engine_set_quality_level(engine, graphState.qualityLevel)"))
        #expect(metalView.contains("pushForceParams()"))
        #expect(metalView.contains("pushExtendedForceParams()"))
        #expect(metalView.contains("self?.applyPowerModeGraphOverrides()"))
    }

    @Test("graph pause path releases drawables and resume restores them before rendering")
    func graphPausePathReleasesDrawablesAndResumeRestoresThem() throws {
        let metalView = try loadRepoTextFile("Epistemos/Views/Graph/MetalGraphView.swift")

        #expect(metalView.contains("layer.maximumDrawableCount = 2"))
        #expect(metalView.contains("func pauseEngine()"))
        #expect(metalView.contains("metalLayer?.drawableSize = .zero"))
        #expect(metalView.contains("func resumeEngine()"))
        #expect(metalView.contains("updateMetalLayerBackingProperties()"))
    }

    @Test("graph renderer keeps the 6.5 camera smoothing baseline")
    func graphRendererKeepsTheSnappyCameraBaseline() throws {
        let renderer = try loadRepoTextFile("graph-engine/src/renderer.rs")

        #expect(renderer.contains("const CAMERA_LAMBDA: f32 = 6.5;"))
    }

    @Test("graph sidebar caches notes tree snapshots across selection churn")
    func graphSidebarCachesNotesTreeSnapshotsAcrossSelectionChurn() throws {
        let sidebar = try loadRepoTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")

        #expect(sidebar.contains("@State private var cachedNotesTreeSnapshot"))
        #expect(sidebar.contains("@State private var cachedNotesTreeTopologyVersion = -1"))
        #expect(sidebar.contains("refreshNotesTreeSnapshotIfNeeded()"))
        #expect(sidebar.contains("cachedNotesTreeTopologyVersion != topologyVersion"))
        #expect(sidebar.contains("let snapshot = cachedNotesTreeSnapshot"))
    }

    @Test("graph exposes node chat in the sidebar with the shared ask bar")
    func graphExposesNodeChatInTheSidebarWithTheSharedAskBar() throws {
        let sidebar = try loadRepoTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")
        let state = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        #expect(sidebar.contains("enum SidebarTab { case notes, query, chat }"))
        #expect(sidebar.contains("case .chat"))
        #expect(sidebar.contains("AssistantToolbarAskBar("))
        #expect(state.contains("enum InspectorMode: Hashable { case profile, editor }"))
        #expect(!inspector.contains("Text(\"Chat\").tag(NodeInspectorState.InspectorMode.chat)"))
        #expect(!inspector.contains("else if inspectorState.inspectorMode == .chat"))
        #expect(!inspector.contains("AssistantToolbarAskBar("))
        #expect(overlay.contains("let sidebarRoot = HologramSearchSidebar("))
    }

    @Test("graph chat transcript uses the mini-chat assistant formatting path")
    func graphChatTranscriptUsesMiniChatAssistantFormattingPath() throws {
        let sidebar = try loadRepoTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        let messageBubble = try loadRepoTextFile("Epistemos/Views/Chat/MessageBubble.swift")

        #expect(sidebar.contains("AssistantTranscriptChrome"))
        #expect(sidebar.contains("TaggedMarkdownTextView(content: displayText, theme: theme)"))
        #expect(sidebar.contains(".frame(maxWidth: .infinity, alignment: .trailing)"))
        #expect(messageBubble.contains("struct AssistantTranscriptChrome"))
    }

    @Test("graph node inspector keeps summary generation off the immediate selection turn")
    func graphNodeInspectorKeepsSummaryGenerationOffImmediateSelectionTurn() throws {
        let inspectorState = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")
        let inspectorView = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")

        #expect(!inspectorState.contains("summaryKickoffTask"))
        #expect(inspectorState.contains("func ensureSummary(for node: GraphNodeRecord, store: GraphStore, modelContext: ModelContext)"))
        #expect(inspectorState.contains("summaryTask?.cancel()"))
        #expect(inspectorState.contains("guard !Task.isCancelled, selectedNodeId == node.id else { return }"))
        #expect(inspectorView.contains("guard newSection == .summary else { return }"))
        #expect(inspectorView.contains("inspectorState.ensureSummary(for: node, store: graphState.store, modelContext: modelContext)"))
    }

    @Test("graph summaries still prefer Apple Intelligence before local Qwen fallback")
    func graphSummariesStayAppleFirst() throws {
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        #expect(inspector.contains("Try Apple Intelligence first for a fast on-device summary, then local Qwen."))
        #expect(inspector.contains("AppleIntelligenceService.shared.generate("))
    }

    @Test("node inspector derives profiles off the main actor and caches them by node version")
    func nodeInspectorDerivesProfilesOffTheMainActorAndCachesThemByNodeVersion() throws {
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        #expect(inspector.contains("private var profileCache: [ProfileCacheKey: DialogueNodeProfile] = [:]"))
        #expect(inspector.contains("let derived = await Task.detached(priority: .userInitiated)"))
        #expect(inspector.contains("let normalizedBody = noteBody.trimmingCharacters(in: .whitespacesAndNewlines)"))
        #expect(inspector.contains("let freqKeywords = focusKeywords("))
        #expect(inspector.contains("self.profileCache[cacheKey] = derived"))
        #expect(inspector.contains("if let cachedProfile = profileCache[cacheKey]"))
        #expect(inspector.contains("displayedSummary = full"))
        #expect(!inspector.contains("Task.sleep(for: .milliseconds(16))"))
    }

    @Test("node inspector chat expands folder descendants and linked graph context")
    func nodeInspectorChatExpandsFolderDescendantsAndLinkedGraphContext() throws {
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")

        #expect(inspector.contains("let predicate = #Predicate<SDFolder> { $0.id == folderID }"))
        #expect(inspector.contains("return subfolder == relativePath || (!nestedPrefix.isEmpty && subfolder.hasPrefix(nestedPrefix))"))
        #expect(inspector.contains("Items loaded for context:"))
        #expect(inspector.contains("Connected graph context:"))
        #expect(inspector.contains("Treat folder context as a bundle of descendant notes and relationships"))
    }

    @Test("note picker uses a dedicated split context panel instead of the cramped mention dropdown")
    func notePickerUsesDedicatedSplitContextPanel() throws {
        let popover = try loadRepoTextFile("Epistemos/Views/Chat/NotesMentionDropdown.swift")

        #expect(popover.contains("if style == .notePicker"))
        #expect(popover.contains("notePickerSidebar"))
        #expect(popover.contains("Attach exactly what this turn should know."))
        #expect(popover.contains("Attach the vault retrieval index for this turn."))
        #expect(popover.contains("Searches titles, folders, tags, and indexed body snippets."))
        #expect(popover.contains("final class ComposerReferencePopoverCoordinator"))
        #expect(popover.contains("private let popover = NSPopover()"))
        #expect(popover.contains("self.popover.show("))
        #expect(popover.contains("await Task.yield()"))
        #expect(popover.contains("guard let self, let anchorView, anchorView.window != nil"))
        #expect(!popover.contains("GeometryReader { proxy in"))
    }

    @Test("note editor keeps markdown tables as plain editor text")
    func noteEditorKeepsMarkdownTablesAsPlainEditorText() throws {
        let tk2 = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")

        #expect(tk2.contains("tv.usesRenderedTableOverlays = false"))
        #expect(tk2.contains("tv.markdownDelegate.usesRenderedTableOverlays = false"))
        #expect(!tk2.contains("coord.renderedTableOverlayManager = RenderedTableOverlayManager2("))
    }

    @Test("mini chat stays a real resizable window without the removed palette shell")
    func miniChatStaysARealResizableWindowWithoutPaletteShell() throws {
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let controller = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatWindowController.swift")

        #expect(controller.contains("styleMask: [.titled, .closable, .resizable, .fullSizeContentView]"))
        #expect(controller.contains("window.maxSize = NSSize(width: 1600, height: 1400)"))
        #expect(miniChat.contains(".padding(.horizontal, 28)"))
        #expect(miniChat.contains(".padding(.top, 18)"))
        #expect(miniChat.contains(".padding(.bottom, 20)"))
        #expect(miniChat.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
        #expect(!miniChat.contains("AssistantSurfaceChrome(theme: theme, metrics: surfaceMetrics)"))
        #expect(miniChat.contains("static let messageColumnMaxWidth: CGFloat = 560"))
        #expect(miniChat.contains("MiniChatBubble(message: msg)\n                                            .frame(maxWidth: .infinity)"))
        #expect(miniChat.contains("HStack {\n                            Spacer(minLength: 0)"))
        #expect(miniChat.contains("}\n                        .frame(maxWidth: .infinity)"))
        #expect(miniChat.contains(".background(theme.userBubbleBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))"))
        #expect(miniChat.contains(".frame(maxWidth: MiniChatLayout.userBubbleMaxWidth, alignment: .leading)"))
        #expect(miniChat.contains(".frame(maxWidth: .infinity, alignment: .trailing)"))
    }

    @Test("mini chat launches in its own real window and keeps main-chat styling cues")
    func miniChatUsesDedicatedWindowAndCompactMainChatLayout() throws {
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let statusBar = try loadRepoTextFile("Epistemos/App/StatusBar.swift")
        let intents = try loadRepoTextFile("Epistemos/Intents/Custom/NavigationIntents.swift")
        let sidebar = try loadRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let chatView = try loadRepoTextFile("Epistemos/Views/Chat/ChatView.swift")
        let windowController = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatWindowController.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(app.contains("MiniChatWindowController.shared.openNewChat()"))
        #expect(statusBar.contains("MiniChatWindowController.shared.openNewChat()"))
        #expect(intents.contains("MiniChatWindowController.shared.show()"))
        #expect(sidebar.contains("MiniChatWindowController.shared.openNewChat()"))
        #expect(!app.contains("CommandPaletteWindowController"))
        #expect(!statusBar.contains("CommandPaletteWindowController"))
        #expect(!intents.contains("CommandPaletteWindowController"))
        #expect(!sidebar.contains("CommandPaletteWindowController"))

        #expect(app.contains(".keyboardShortcut(\"3\", modifiers: .command)"))
        #expect(landing.contains(".keyboardShortcut(\"3\", modifiers: .command)"))
        #expect(landing.contains("CommandHint(modIcon: \"command\", key: \"3\", label: \"Mini Chat\", theme: theme)"))
        #expect(chatView.contains("Label(\"Open in Mini Chat\""))
        #expect(chatView.contains("openCurrentChatInMiniChat()"))
        #expect(chatView.contains("MiniChatWindowController.shared.openChat(chatId)"))

        #expect(windowController.contains("let window = NSWindow("))
        #expect(!windowController.contains(".nonactivatingPanel"))
        #expect(!windowController.contains(".utilityWindow"))
        #expect(!windowController.contains("let panel = NSPanel("))
        #expect(windowController.contains("WindowPresentationPolicy.applyModularZoomBehavior("))
        #expect(windowController.contains("minimumContentSize: Self.minimumContentSize"))
        #expect(windowController.contains("window.maxSize = NSSize(width: 1600, height: 1400)"))
        #expect(windowController.contains("window.tabbingMode = .preferred"))
        #expect(windowController.contains("window.tabbingIdentifier = \"epistemos-mini-chat-tabs\""))
        #expect(!windowController.contains(".padding(22)"))

        #expect(miniChat.contains("ChatComposerTextEditor("))
        #expect(miniChat.contains(".assistantComposerChrome("))
        #expect(miniChat.contains("TaggedMarkdownTextView("))
        #expect(miniChat.contains(".frame(maxWidth: MiniChatLayout.userBubbleMaxWidth, alignment: .leading)"))
    }

    @Test("mini chat uses native macOS tab groups and loads app-wide chats by chat id")
    func miniChatUsesNativeMacOSTabGroupsAndLoadsAppWideChatsByChatId() throws {
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let threadState = try loadRepoTextFile("Epistemos/State/ThreadState.swift")
        let windowController = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatWindowController.swift")

        #expect(!miniChat.contains("MiniChatTabBar"))
        #expect(!miniChat.contains("threadState.activeMiniChatThread()"))
        #expect(miniChat.contains("Recent Chats"))
        #expect(miniChat.contains("MiniChatWindowController.shared.openNewChat()"))
        #expect(miniChat.contains("MiniChatWindowController.shared.openChat("))
        #expect(threadState.contains("func upsertMiniChatSession("))
        #expect(threadState.contains("func miniChatSession(id: String) -> ChatThread?"))
        #expect(windowController.contains("window.tabbingIdentifier = \"epistemos-mini-chat-tabs\""))
        #expect(windowController.contains("existingWindow.addTabbedWindow(window, ordered: .above)"))
    }

    @Test("main chat pipeline stays aligned with the compact chat streaming path")
    func mainChatPipelineMatchesCompactChatStreamingPath() throws {
        let pipeline = try loadRepoTextFile("Epistemos/Engine/PipelineService.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let triage = try loadRepoTextFile("Epistemos/Engine/TriageService.swift")

        #expect(pipeline.contains("localSurface: .miniChat"))
        #expect(miniChat.contains("localSurface: .miniChat"))
        #expect(!pipeline.contains("Response too short"))
        #expect(!pipeline.contains("No response received"))
        #expect(!pipeline.contains("finalVisibleAnswer.count >= 10"))
        #expect(triage.contains("if prefersDedicatedLocalChatRouting("))
        #expect(triage.contains("case .mainChat, .miniChat:"))
    }

    @Test("chat surfaces expose operating mode selection and keep agent routing in main chat only")
    func chatSurfacesExposeOperatingModeSelectionAndRouteOnlyAgentModeThroughOmega() throws {
        let inference = try loadRepoTextFile("Epistemos/State/InferenceState.swift")
        let chatInput = try loadRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let chatView = try loadRepoTextFile("Epistemos/Views/Chat/ChatView.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let chatState = try loadRepoTextFile("Epistemos/State/ChatState.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let pipeline = try loadRepoTextFile("Epistemos/Engine/PipelineService.swift")

        #expect(inference.contains("enum EpistemosOperatingMode"))
        #expect(chatInput.contains("operatingMode: operatingModeBinding"))
        #expect(landing.contains("operatingMode: operatingModeBinding"))
        #expect(miniChat.contains("operatingMode: operatingModeBinding"))
        #expect(chatState.contains("enum MainChatSubmissionRouter"))
        #expect(chatState.contains("case .agent"))
        #expect(chatView.contains("MainChatSubmissionRouter.submit("))
        #expect(landing.contains("MainChatSubmissionRouter.submit("))
        #expect(miniChat.contains("let modes = inference.availableOperatingModes.filter { $0 != .agent }"))
        #expect(!chatState.contains("ResearchComplexityGate.handoffMessage("))
        #expect(!chatState.contains("await orchestrator.submitTask(\"research: \\(cleaned)\")"))
        #expect(!miniChat.contains("ResearchComplexityGate.hasExplicitResearchPrefix(trimmed)"))
        #expect(!miniChat.contains("ResearchComplexityGate.requiresResearch(trimmed)"))
        #expect(!miniChat.contains("await orchestrator.submitTask(trimmed)"))
        #expect(pipeline.contains("operatingMode: EpistemosOperatingMode = .fast"))
        #expect(pipeline.contains("operatingMode: operatingMode"))
    }

    @Test("compact chat surfaces keep operating mode controls reachable with a horizontal control strip")
    func compactChatSurfacesKeepModeControlsReachable() throws {
        let chatInput = try loadRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(chatInput.contains("ComposerControlStrip"))
        #expect(landing.contains("ComposerControlStrip"))
        #expect(miniChat.contains("ComposerControlStrip"))
        #expect(chatInput.contains("ScrollViewReader"))
        #expect(chatInput.contains("composer-control-strip-leading"))
        #expect(chatInput.contains("resetScrollPosition(using: proxy)"))
        #expect(chatInput.contains(".onChange(of: resetKey)"))
        #expect(chatInput.contains("ComposerControlStrip(spacing: 8, resetKey: composerControlResetKey)"))
        #expect(landing.contains("resetKey: composerControlResetKey"))
        #expect(miniChat.contains("ComposerControlStrip(spacing: 8, resetKey: composerControlResetKey)"))

        #expect(chatInput.contains("LocalModelToolbarMenu("))
        #expect(!chatInput.contains("ComposerContextShortcutBar("))
        #expect(chatInput.contains("ComposerAttachmentEntryHints.mainChatPlaceholder"))

        #expect(landing.contains("landingInferenceControl"))
        #expect(!landing.contains("ComposerContextShortcutBar("))
        #expect(landing.contains("ComposerAttachmentEntryHints.landingPlaceholder"))

        #expect(miniChat.contains("LocalModelToolbarMenu("))
        #expect(!miniChat.contains("ComposerContextShortcutBar("))
        #expect(miniChat.contains("ComposerAttachmentEntryHints.mainChatPlaceholder"))
    }

    @Test("main chat transcript resubmits reuse sanitized operating mode state")
    func mainChatTranscriptResubmitsReuseSanitizedOperatingModeState() throws {
        let chatView = try loadRepoTextFile("Epistemos/Views/Chat/ChatView.swift")

        #expect(chatView.contains("inference.sanitizedOperatingMode("))
        #expect(chatView.contains(".onAppear {"))
        #expect(chatView.contains("sanitizeStoredOperatingMode()"))
        #expect(chatView.contains(".onChange(of: inference.supportsThinkingOperatingMode)"))
        #expect(chatView.contains("private func sanitizeStoredOperatingMode()"))
    }

    @Test("apple fallback preserves the available response when local qwen is unavailable")
    func appleFallbackKeepsVisibleResponseWhenLocalFallbackFails() throws {
        let triage = try loadRepoTextFile("Epistemos/Engine/TriageService.swift")

        #expect(triage.contains("Log.engine.info(\"Local model fallback also failed — using Apple Intelligence response\")"))
        #expect(triage.contains("continuation.yield(result)"))
        #expect(!triage.contains("if !Self.isRefusalResponse(result)"))
        #expect(triage.contains("selectedRoute: .appleIntelligence"))
        #expect(triage.contains("localSelection: localSelection.selection"))
    }

    @Test("chat model selection can explicitly force Apple Intelligence")
    func chatModelSelectionCanExplicitlyForceAppleIntelligence() throws {
        let inference = try loadRepoTextFile("Epistemos/State/InferenceState.swift")
        let triage = try loadRepoTextFile("Epistemos/Engine/TriageService.swift")
        let root = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(inference.contains("enum ChatModelSelection"))
        #expect(inference.contains("case appleIntelligence"))
        #expect(inference.contains("var preferredChatModelSelection"))
        #expect(triage.contains("preferredChatModelSelection"))
        #expect(triage.contains("selectedRoute: .appleIntelligence"))
        #expect(root.contains("Apple Intelligence"))
        #expect(root.contains("setPreferredChatModelSelection("))
    }

    @Test("chat model selector scopes cloud models to the active provider and shows configuration guidance")
    func chatModelSelectorAlwaysExposesCloudModelsAndShowsConfigurationGuidance() throws {
        let root = try loadRepoTextFile("Epistemos/App/RootView.swift")

        #expect(root.contains("title: \"Cloud Access\""))
        #expect(root.contains("title: \"Provider\""))
        #expect(root.contains("title: \"Models\""))
        #expect(root.contains("ForEach(CloudModelProvider.preferredOrder"))
        #expect(root.contains("inference.activeCloudProvider"))
        #expect(root.contains("isEnabled: providerConfigured"))
        #expect(root.contains("\"Local Only\""))
        #expect(root.contains("subtitle: cloudAccessSubtitle"))
        #expect(root.contains("return \"Finish setup to unlock\""))
        #expect(root.contains("CloudProviderSetupCard("))
        #expect(root.contains("isExpanded: $showsCloudProviderOptions"))
        #expect(root.contains("showsDismissTip: inference.shouldShowCloudSetupHint"))
    }

    @Test("provider setup automation extends beyond settings into landing and onboarding")
    func providerSetupAutomationExtendsBeyondSettings() throws {
        let root = try loadRepoTextFile("Epistemos/App/RootView.swift")
        let setupAssistant = try loadRepoTextFile("Epistemos/Views/Onboarding/SetupAssistantView.swift")
        let sharedCard = try loadRepoTextFile("Epistemos/Views/Shared/CloudProviderSetupCard.swift")

        #expect(root.contains("CloudProviderSetupCard("))
        #expect(setupAssistant.contains("CloudProviderSetupCard("))
        #expect(setupAssistant.contains("ForEach(CloudModelProvider.preferredOrder"))
        #expect(sharedCard.contains("provider.accountActionTitle"))
        #expect(sharedCard.contains("provider.manualCredentialTitle"))
        #expect(sharedCard.contains("Button(\"Paste + Save\")"))
        #expect(sharedCard.contains("Button(\"Open Inference Settings\")"))
        #expect(sharedCard.contains("Button(provider.documentationActionTitle)"))
    }

    @Test("chat file picker defers panel presentation and reads files under a security scope")
    func chatFilePickerDefersPanelPresentationAndReadsFilesUnderASecurityScope() throws {
        let chatInput = try loadRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")

        #expect(chatInput.contains("await Task.yield()"))
        #expect(chatInput.contains("panel.beginSheetModal(for: window, completionHandler: handler)"))
        #expect(chatInput.contains("panel.begin(completionHandler: handler)"))
        #expect(chatInput.contains("url.startAccessingSecurityScopedResource()"))
        #expect(chatInput.contains("url.stopAccessingSecurityScopedResource()"))
    }

    @Test("instant recall rebuild leaves the heavy vault watcher work off the main actor")
    func instantRecallRebuildLeavesWatcherWorkOffTheMainActor() throws {
        let service = try loadRepoTextFile("Epistemos/KnowledgeFusion/InstantRecallService.swift")
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(service.contains("func rebuildIndexAsync(notes: [(id: String, text: String)]) async"))
        #expect(service.contains("Task.detached(priority: .utility)"))
        #expect(vaultSync.contains("await service.rebuildIndexAsync(notes: notes)"))
        #expect(!vaultSync.contains("instantRecallService.rebuildIndex(notes: notes)"))
    }

    @Test("composer reference popover keeps result rendering lazy for smooth scrolling")
    func composerReferencePopoverKeepsResultRenderingLazy() throws {
        let popover = try loadRepoTextFile("Epistemos/Views/Chat/NotesMentionDropdown.swift")

        #expect(popover.contains("LazyVStack(alignment: .leading, spacing: 0)"))
    }

    @Test("mini chat reference picker skips chat fetches while empty-query browsing is active")
    func miniChatReferencePickerSkipsChatFetchesWhileBrowsing() throws {
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")

        #expect(miniChat.contains("private var trimmedMentionFilter: String"))
        #expect(miniChat.contains("let shouldSearchChats = !trimmedMentionFilter.isEmpty"))
        #expect(miniChat.contains("filter: trimmedMentionFilter"))
        #expect(miniChat.contains("chats: shouldSearchChats ? recentChats() : []"))
        #expect(miniChat.contains("threads: shouldSearchChats ? threadState.chatThreads : []"))
    }

    @Test("composer note pickers observe vault sync manifest updates instead of relying on bootstrap singleton state")
    func composerNotePickersObserveVaultSyncManifestUpdates() throws {
        let chatInput = try loadRepoTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let coordinator = try loadRepoTextFile("Epistemos/App/AppCoordinator.swift")
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")

        #expect(chatInput.contains("vaultSync.ambientManifest ?? AppBootstrap.shared?.ambientManifest"))
        #expect(chatInput.contains("manifest: ambientManifest"))
        #expect(!chatInput.contains("manifest: AppBootstrap.shared?.ambientManifest"))

        #expect(miniChat.contains("vaultSync.ambientManifest ?? AppBootstrap.shared?.ambientManifest"))
        #expect(miniChat.contains("manifest: ambientManifest"))
        #expect(!miniChat.contains("manifest: AppBootstrap.shared?.ambientManifest"))

        #expect(landing.contains("vaultSync.ambientManifest ?? AppBootstrap.shared?.ambientManifest"))
        #expect(landing.contains("manifest: ambientManifest"))
        #expect(!landing.contains("manifest: AppBootstrap.shared?.ambientManifest"))

        #expect(vaultSync.contains("var ambientManifest: VaultManifest?"))
        #expect(coordinator.contains("vaultSync.ambientManifest = manifest"))
    }

    @Test("composer reference search caches manifest page ids between query updates")
    func composerReferenceSearchCachesManifestPageIDsBetweenQueryUpdates() throws {
        let popover = try loadRepoTextFile("Epistemos/Views/Chat/NotesMentionDropdown.swift")

        #expect(popover.contains("private var cachedManifestGeneratedAt: Date?"))
        #expect(popover.contains("private var cachedManifestEntryCount = 0"))
        #expect(popover.contains("private var cachedManifestPageIDs = Set<String>()"))
        #expect(popover.contains("let manifestPageIDs = pageIDs(in: manifest)"))
    }

    @Test("scroll-heavy composer pickers use reduced-overdraw chrome")
    func scrollHeavyComposerPickersUseReducedOverdrawChrome() throws {
        let popover = try loadRepoTextFile("Epistemos/Views/Chat/NotesMentionDropdown.swift")

        #expect(popover.contains("private var usesReducedOverdrawChrome: Bool"))
        #expect(popover.contains("if usesReducedOverdrawChrome"))
        #expect(popover.contains(".clipped()"))
        #expect(popover.contains("theme.resolved.background.color.opacity(0.94)"))
    }

    @Test("node inspector profile copy avoids synthetic knowledge cluster filler text")
    func nodeInspectorProfileCopyAvoidsSyntheticKnowledgeClusterFillerText() throws {
        let inspectorState = try loadRepoTextFile("Epistemos/Views/Graph/NodeInspectorState.swift")
        let inspectorView = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")

        #expect(!inspectorState.contains("is part of a connected knowledge cluster"))
        #expect(inspectorView.contains("if !p.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty"))
    }

    @Test("regex-backed presentation helpers avoid force-try compilation")
    func regexBackedPresentationHelpersAvoidForceTryCompilation() throws {
        let files = [
            "Epistemos/Sync/BlockPropertyParser.swift",
            "Epistemos/Views/Chat/ChatView.swift",
            "Epistemos/Views/Chat/TaggedMarkdownTextView.swift",
            "Epistemos/Views/Notes/MarkdownContentStorage.swift",
            "Epistemos/Views/Notes/MarkdownEditorStyle.swift",
            "Epistemos/Views/Notes/OutlineNavigatorView.swift",
            "Epistemos/Theme/EpistemosTheme.swift",
            "Epistemos/Theme/GlassModifiers.swift",
        ]

        for file in files {
            let source = try loadRepoTextFile(file)
            #expect(!source.contains("try!"), "\(file) should not use try! for regex or detector setup")
        }
    }

    @Test("block mirror similarity avoids quadratic edit-distance buffers")
    func blockMirrorSimilarityAvoidsQuadraticEditDistanceBuffers() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/BlockMirror.swift")

        #expect(!source.contains("Array(lhs.utf16)"))
        #expect(!source.contains("Array(rhs.utf16)"))
        #expect(!source.contains("var previous = Array(0...right.count)"))
        #expect(!source.contains("var current = Array(repeating: 0, count: right.count + 1)"))
    }

    @Test("read only note windows use the shared app environment helper")
    func readOnlyNoteWindowsUseSharedAppEnvironmentHelper() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/NoteWindowManager.swift")

        #expect(source.contains("ReadOnlyVersionView(title: title, versionBody: body, dateLabel: dateStr)\n            .withAppEnvironment(bootstrap)"))
        #expect(!source.contains("ReadOnlyVersionView(title: title, versionBody: body, dateLabel: dateStr)\n            .environment(bootstrap.uiState)"))
    }

    @Test("time machine duplicate page IDs log instead of asserting")
    func timeMachineDuplicatePageIDsLogInsteadOfAsserting() throws {
        let source = try loadRepoTextFile("Epistemos/State/TimeMachineService.swift")

        #expect(source.contains("Self.log.fault"))
        #expect(!source.contains("assertionFailure(message)"))
    }

    @Test("time machine persistence avoids silent fetch and count failures")
    func timeMachinePersistenceAvoidsSilentFailures() throws {
        let source = try loadRepoTextFile("Epistemos/State/TimeMachineService.swift")

        #expect(!source.contains("let version = try? context.fetch(versionDesc).first"))
        #expect(!source.contains("if let chats = try? context.fetch(chatDesc)"))
        #expect(!source.contains("let msgCount = (try? context.fetchCount(msgDesc)) ?? 0"))
        #expect(!source.contains("state.graphStats.nodeCount = (try? context.fetchCount(nodeDesc)) ?? 0"))
        #expect(!source.contains("state.graphStats.edgeCount = (try? context.fetchCount(edgeDesc)) ?? 0"))
        #expect(!source.contains("let currentPages = (try? context.fetch(FetchDescriptor<SDPage>())) ?? []"))
        #expect(!source.contains("let currentChatCount = (try? context.fetchCount(FetchDescriptor<SDChat>())) ?? 0"))
        #expect(!source.contains("let currentNodeCount = (try? context.fetchCount(FetchDescriptor<SDGraphNode>())) ?? 0"))
        #expect(!source.contains("let currentEdgeCount = (try? context.fetchCount(FetchDescriptor<SDGraphEdge>())) ?? 0"))
        #expect(source.contains("private func fetchFirst<T: PersistentModel>("))
        #expect(source.contains("private func fetchAll<T: PersistentModel>("))
        #expect(source.contains("private func fetchCount<T: PersistentModel>("))
        #expect(source.contains("Self.log.error(\"TimeMachine: failed to fetch \\(label"))
        #expect(source.contains("label: \"note version\""))
        #expect(source.contains("label: \"chats\""))
        #expect(source.contains("label: \"chat message count\""))
        #expect(source.contains("label: \"node count\""))
        #expect(source.contains("label: \"edge count\""))
        #expect(source.contains("label: \"current pages\""))
        #expect(source.contains("label: \"current chat count\""))
        #expect(source.contains("label: \"current graph node count\""))
        #expect(source.contains("label: \"current graph edge count\""))
    }

    @Test("vault index actor avoids silent import and manifest fallback paths")
    func vaultIndexActorAvoidsSilentRuntimeFallbacks() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/VaultIndexActor.swift")

        #expect(!source.contains("guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),"))
        #expect(!source.contains("if let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),"))
        #expect(!source.contains("let currentPages = (try? modelContext.fetch(FetchDescriptor<SDPage>())) ?? []"))
        #expect(!source.contains("if let existingFolders = try? modelContext.fetch(existingFolderDescriptor)"))
        #expect(!source.contains("if let insight = try? modelContext.fetch(insightDesc).first"))
        #expect(!source.contains("let existingWithId = (try? modelContext.fetch(idDescriptor)) ?? []"))
        #expect(!source.contains("guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {"))
        #expect(!source.contains("guard let pages = try? modelContext.fetch(descriptor) else { return [] }"))
        #expect(!source.contains("let folderNames = (try? modelContext.fetch(folderDescriptor))?.map(\\.name) ?? []"))
        #expect(!source.contains("let changedPageCount = (try? modelContext.fetchCount(descriptor)) ?? 0"))
        #expect(!source.contains("try? modelContext.save()"))
        #expect(source.contains("private func fetchAll<T: PersistentModel>("))
        #expect(source.contains("private func fetchFirst<T: PersistentModel>("))
        #expect(source.contains("private func fetchCount<T: PersistentModel>("))
        #expect(source.contains("private func saveContext("))
        #expect(source.contains("private nonisolated static func contentModificationDate("))
    }

    @Test("custom secondary windows opt out of AppKit state restoration")
    func customSecondaryWindowsOptOutOfAppKitStateRestoration() throws {
        let noteWindowManager = try loadRepoTextFile("Epistemos/Views/Notes/NoteWindowManager.swift")
        let miniChatWindowController = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatWindowController.swift")
        let utilityWindowManager = try loadRepoTextFile("Epistemos/App/UtilityWindowManager.swift")
        let graphOverlayPanel = try loadRepoTextFile("Epistemos/Views/Graph/GraphOverlayPanel.swift")
        let quitSavePanel = try loadRepoTextFile("Epistemos/Views/Landing/QuitSavePanelController.swift")

        #expect(noteWindowManager.contains("window.isRestorable = false"))
        #expect(miniChatWindowController.contains("window.isRestorable = false"))
        #expect(utilityWindowManager.contains("panel.isRestorable = false"))
        #expect(graphOverlayPanel.contains("isRestorable = false"))
        #expect(quitSavePanel.contains("scrim.isRestorable = false"))
        #expect(quitSavePanel.contains("floatingPanel.isRestorable = false"))
    }

    @Test("graph overlay full-screen presentation uses an immersive topmost window mode")
    func graphOverlayFullScreenPresentationUsesImmersiveTopmostWindowMode() throws {
        let graphOverlayPanel = try loadRepoTextFile("Epistemos/Views/Graph/GraphOverlayPanel.swift")
        let hologramOverlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")

        #expect(graphOverlayPanel.contains("enum GraphOverlayPanelPresentation"))
        #expect(graphOverlayPanel.contains("case immersiveOverlay"))
        #expect(graphOverlayPanel.contains("case floatingPanel"))
        #expect(graphOverlayPanel.contains("level = .screenSaver"))
        #expect(graphOverlayPanel.contains("level = .floating"))

        #expect(hologramOverlay.contains("window.applyPresentation(.immersiveOverlay)"))
        #expect(hologramOverlay.contains("window.applyPresentation(.floatingPanel)"))
        #expect(hologramOverlay.contains("orderFrontRegardless()"))
    }

    @Test("app delegate disables AppKit state restoration in favor of workspace restore")
    func appDelegateDisablesAppKitStateRestorationInFavorOfWorkspaceRestore() throws {
        let source = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(source.contains("func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {\n        false\n    }"))
        #expect(source.contains("func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {\n        false\n    }"))
    }

    @Test("bootstrap and persistence helpers avoid force-trap fallbacks")
    func bootstrapAndPersistenceHelpersAvoidForceTrapFallbacks() throws {
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let feedbackLogger = try loadRepoTextFile("Epistemos/KnowledgeFusion/Alignment/FeedbackLogger.swift")
        let mcpBridge = try loadRepoTextFile("Epistemos/Omega/MCPBridge.swift")
        let activityTracker = try loadRepoTextFile("Epistemos/State/ActivityTracker.swift")
        let eventStore = try loadRepoTextFile("Epistemos/State/EventStore.swift")
        let adapterRegistry = try loadRepoTextFile("Epistemos/KnowledgeFusion/Adapters/AdapterRegistry.swift")
        let skillManifest = try loadRepoTextFile("Epistemos/KnowledgeFusion/SkillGeneration/SkillManifest.swift")
        let pythonEnvironmentManager = try loadRepoTextFile("Epistemos/KnowledgeFusion/PythonEnvironmentManager.swift")
        let knowledgeFusionViewModel = try loadRepoTextFile("Epistemos/KnowledgeFusion/UI/KnowledgeFusionViewModel.swift")
        let trainingScheduler = try loadRepoTextFile("Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift")
        let qualityCurator = try loadRepoTextFile("Epistemos/KnowledgeFusion/SyntheticData/QualityCurator.swift")
        let experienceReplayBuffer = try loadRepoTextFile("Epistemos/KnowledgeFusion/Training/ExperienceReplayBuffer.swift")
        let chatSidebar = try loadRepoTextFile("Epistemos/Views/Chat/ChatSidebarView.swift")
        let dataDetectionService = try loadRepoTextFile("Epistemos/Engine/DataDetectionService.swift")
        let queryParser = try loadRepoTextFile("Epistemos/Engine/QueryParser.swift")
        let structuredQueryParser = try loadRepoTextFile("Epistemos/Engine/StructuredQueryParser.swift")

        #expect(!appBootstrap.contains("try! ModelContainer("))
        #expect(!feedbackLogger.contains("try! JSONSerialization.data"))
        #expect(!feedbackLogger.contains("String(data: data, encoding: .utf8)!"))
        #expect(!mcpBridge.contains(".first!"))
        #expect(!activityTracker.contains(".first!"))
        #expect(!eventStore.contains(".first!"))
        #expect(!adapterRegistry.contains(".first!"))
        #expect(!skillManifest.contains(".first!"))
        #expect(!pythonEnvironmentManager.contains(".first!"))
        #expect(!knowledgeFusionViewModel.contains(".first!"))
        #expect(!trainingScheduler.contains(".first!"))
        #expect(!qualityCurator.contains("String(data: data, encoding: .utf8)!"))
        #expect(!experienceReplayBuffer.contains("String(data: data, encoding: .utf8)!"))
        #expect(!chatSidebar.contains("calendar.date(byAdding: .day, value: -1, to: startOfToday)!"))
        #expect(!chatSidebar.contains("calendar.date(byAdding: .day, value: -7, to: startOfToday)!"))
        #expect(!dataDetectionService.contains("URL(string: \"webcal://\")!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .day, value: -1, to: now)!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .day, value: -7, to: now)!"))
        #expect(!queryParser.contains("calendar.date(byAdding: .month, value: -1, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .day, value: -1, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .day, value: -7, to: now)!"))
        #expect(!structuredQueryParser.contains("calendar.date(byAdding: .month, value: -1, to: now)!"))
    }

    @Test("activity tracker crash recovery stays wired and fail-closed")
    func activityTrackerCrashRecoveryStaysWiredAndFailClosed() throws {
        let activityTracker = try loadRepoTextFile("Epistemos/State/ActivityTracker.swift")
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let app = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(activityTracker.contains("NoteFileStorage.writeTextAtomically(text, to: url, itemLabel: Self.flushFileLabel)"))
        #expect(activityTracker.contains("events = Array((loaded + events).suffix(Self.maxEvents))"))
        #expect(!activityTracker.contains("try? await Task.sleep(for: .seconds(2))"))
        #expect(!activityTracker.contains("return try? context.fetch(descriptor).first?.title"))
        #expect(!activityTracker.contains("try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)"))
        #expect(appBootstrap.contains("activityTracker.loadFlushedEvents()"))
        #expect(app.contains("bootstrap.activityTracker.flushToDisk()"))
    }

    @Test("workspace summary persistence avoids silent fetch save and sleep failures")
    func workspaceSummaryPersistenceAvoidsSilentFailures() throws {
        let workspaceSummary = try loadRepoTextFile("Epistemos/State/WorkspaceSummaryService.swift")

        #expect(!workspaceSummary.contains("try? await Task.sleep(for: interval)"))
        #expect(!workspaceSummary.contains("try? context.save()"))
        #expect(!workspaceSummary.contains("return try? context.fetch(FetchDescriptor<SDWorkspace>())"))
        #expect(!workspaceSummary.contains("return try? modelContainer.mainContext.fetch(descriptor).first?.title"))
        #expect(workspaceSummary.contains("Summary storage save failed"))
        #expect(workspaceSummary.contains("Summary timestamp fetch failed"))
        #expect(workspaceSummary.contains("Summary page-title fetch failed"))
    }

    @Test("workspace summary output is sanitized before persistence and prompt reuse")
    func workspaceSummaryOutputIsSanitizedBeforePersistenceAndPromptReuse() throws {
        let workspaceSummary = try loadRepoTextFile("Epistemos/State/WorkspaceSummaryService.swift")
        let coordinator = try loadRepoTextFile("Epistemos/App/ChatCoordinator.swift")
        let workspaceService = try loadRepoTextFile("Epistemos/State/WorkspaceService.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(workspaceSummary.contains("UserFacingModelOutput.finalVisibleText(from: raw)"))
        #expect(workspaceSummary.contains("Self.sanitizedSummaryText(from: summary)"))
        #expect(coordinator.contains("private nonisolated static func sanitizedWorkspaceContextValue("))
        #expect(coordinator.contains("if let summary = sanitizedWorkspaceContextValue(workspace.summary)"))
        #expect(workspaceService.contains("var sanitizedIntentSummary: String"))
        #expect(workspaceService.contains("UserFacingModelOutput.finalVisibleText(from: intentSummary)"))
        #expect(landing.contains("info.sanitizedIntentSummary"))
        #expect(appBootstrap.contains("workspaceService.welcomeBack?.intentSummary = WelcomeBackInfo.cleanedSummaryText(from: ws.summary)"))
    }

    @Test("welcome back info strips reasoning artifacts from restored summaries")
    func welcomeBackInfoStripsReasoningArtifactsFromRestoredSummaries() {
        let info = WelcomeBackInfo(
            intentSummary: "<think>debug trace</think>\nShip mode summary is ready.",
            userNote: "",
            noteCount: 1,
            chatCount: 0,
            graphWasOpen: false,
            sessionMinutes: 10,
            editedNoteTitles: []
        )

        #expect(info.sanitizedIntentSummary == "Ship mode summary is ready.")
        #expect(!info.displayText.contains("<think>"))
        #expect(info.displayText.contains("Ship mode summary is ready."))
    }

    @Test("app bootstrap startup recovery avoids silent fetch delete and timer failures")
    func appBootstrapStartupRecoveryAvoidsSilentFailures() throws {
        let appBootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(!appBootstrap.contains("guard let pages = try? context.fetch(FetchDescriptor<SDPage>()) else {"))
        #expect(!appBootstrap.contains("if let ws = try? modelContainer.mainContext.fetch("))
        #expect(!appBootstrap.contains("try? await Task.sleep(for: Self.primaryLaunchInitializationPollInterval)"))
        #expect(!appBootstrap.contains("try? await Task.sleep(for: Self.deferredRuntimeServicesDelay)"))
        #expect(!appBootstrap.contains("try? fm.removeItem(at: appSupport.appendingPathComponent(name))"))
        #expect(!appBootstrap.contains("try? fm.removeItem(at: file)"))
        #expect(!appBootstrap.contains("guard let pages = try? modelContainer.mainContext.fetch(descriptor) else { return [] }"))
        #expect(appBootstrap.contains("Startup integrity snapshot failed"))
        #expect(appBootstrap.contains("Welcome-back summary fetch failed"))
        #expect(appBootstrap.contains("Instant Recall seed snapshot failed"))
        #expect(appBootstrap.contains("Database reset cleanup failed"))
    }

    @Test("model profile persistence avoids silent save failures")
    func modelProfilePersistenceAvoidsSilentSaveFailures() throws {
        let manager = try loadRepoTextFile("Epistemos/State/ModelProfileManager.swift")

        #expect(!manager.contains("try? context.save()"))
        #expect(manager.contains("Failed to persist model profile"))
    }

    @Test("UIState landing greeting persistence avoids silent JSON and timer failures")
    func uiStateLandingGreetingPersistenceAvoidsSilentFailures() throws {
        let uiState = try loadRepoTextFile("Epistemos/State/UIState.swift")

        #expect(!uiState.contains("let decodedGreetings = try? JSONDecoder().decode("))
        #expect(!uiState.contains("guard let encodedGreetings = try? JSONEncoder().encode(landingCustomGreetings) else"))
        #expect(!uiState.contains("try? await Task.sleep(for: .seconds(type == .error ? 5 : 3))"))
        #expect(!uiState.contains("guard let pages = try? context.fetch(descriptor), !pages.isEmpty else { return [] }"))
        #expect(!uiState.contains("if let ws = try? context.fetch("))
        #expect(uiState.contains("UIState: failed to decode custom landing greetings"))
        #expect(uiState.contains("UIState: failed to encode custom landing greetings"))
        #expect(uiState.contains("UIState: toast dismissal sleep failed"))
        #expect(uiState.contains("LandingGreetingResolver: failed to fetch recent pages"))
        #expect(uiState.contains("LandingGreetingResolver: failed to fetch workspace summary"))
    }

    @Test("workspace service persistence avoids silent fetch decode and timer failures")
    func workspaceServicePersistenceAvoidsSilentFailures() throws {
        let workspaceService = try loadRepoTextFile("Epistemos/State/WorkspaceService.swift")

        #expect(!workspaceService.contains("try? await Task.sleep(for: .milliseconds(200))"))
        #expect(!workspaceService.contains("try? await Task.sleep(for: .seconds(self?.autoSaveInterval ?? 300))"))
        #expect(!workspaceService.contains("let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first"))
        #expect(!workspaceService.contains("guard let workspace = try? context.fetch(FetchDescriptor(predicate: predicate)).first"))
        #expect(!workspaceService.contains("let snapshot = try? JSONDecoder().decode(WorkspaceSnapshot.self, from: workspace.snapshotData)"))
        #expect(!workspaceService.contains("return (try? modelContainer.mainContext.fetch(descriptor)) ?? []"))
        #expect(workspaceService.contains("Workspace auto-save: failed to fetch auto-save workspace"))
        #expect(workspaceService.contains("Workspace auto-restore: failed to fetch auto-save workspace"))
        #expect(workspaceService.contains("Workspace diff: failed to decode saved snapshot"))
        #expect(workspaceService.contains("Workspace list: failed to fetch saved workspaces"))
    }

    @Test("EventStore persistence avoids silent directory and JSON fallback failures")
    func eventStorePersistenceAvoidsSilentDirectoryAndJSONFallbackFailures() throws {
        let eventStore = try loadRepoTextFile("Epistemos/State/EventStore.swift")

        #expect(!eventStore.contains("try? FileManager.default.createDirectory("))
        #expect(!eventStore.contains("(try? String(data: JSONEncoder().encode(completedJobs), encoding: .utf8)) ?? \"[]\""))
        #expect(!eventStore.contains("(try? JSONDecoder().decode([String].self, from: Data(jobsJSON.utf8))) ?? []"))
        #expect(!eventStore.contains("(try? String(data: payloadEncoder.encode(dict), encoding: .utf8)) ?? \"{}\""))
        #expect(!eventStore.contains("guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]) else { return \"{}\" }"))
        #expect(eventStore.contains("EventStore: failed to create database directory"))
        #expect(eventStore.contains("EventStore: failed to encode Night Brain jobs_completed payload"))
        #expect(eventStore.contains("EventStore: failed to decode Night Brain jobs_completed payload"))
        #expect(eventStore.contains("EventStore: failed to encode event payload"))
        #expect(eventStore.contains("let payloadObject: [String: Any] = ["))
        #expect(eventStore.contains("let data = try JSONSerialization.data(withJSONObject: payloadObject, options: [.sortedKeys])"))
        #expect(eventStore.contains("private nonisolated static func excludeParentDirectoryFromSpotlight"))
        #expect(eventStore.contains("throw CocoaError(.fileWriteUnknown)"))
    }

    @Test("theme capture and settings helpers avoid user-facing force unwrap traps")
    func themeCaptureAndSettingsHelpersAvoidUserFacingForceUnwrapTraps() throws {
        let embodiedCapture = try loadRepoTextFile("Epistemos/KnowledgeFusion/SyntheticData/EmbodiedCaptureService.swift")
        let themeSource = try loadRepoTextFile("Epistemos/Theme/EpistemosTheme.swift")

        #expect(!embodiedCapture.contains("handle.write(line.data(using: .utf8)!)"))
        #expect(embodiedCapture.contains("guard let lineData = line.data(using: .utf8) else {"))

        #expect(!themeSource.contains("preconditionFailure(\"Missing resolved theme cache"))
        #expect(themeSource.contains("Self.resolvedCache[self] ?? buildResolved()"))
    }

    @Test("supervisor network health has no hardcoded remote endpoint")
    func supervisorNetworkHealthHasNoHardcodedRemoteEndpoint() throws {
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(!appSupervisor.contains("https://api.anthropic.com"))
    }

    @Test("supervisor network health avoids remote HTTP polling")
    func supervisorNetworkHealthAvoidsRemoteHTTPPolling() throws {
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(appSupervisor.contains("import Network"))
        #expect(appSupervisor.contains("NWPathMonitor"))
        #expect(!appSupervisor.contains("https://api.anthropic.com"))
        #expect(!appSupervisor.contains("URLRequest(url: url, timeoutInterval: 5.0)"))
        #expect(!appSupervisor.contains("request.httpMethod = \"HEAD\""))
        #expect(!appSupervisor.contains("URLSession.shared.data(for: request)"))
    }

    @Test("supervisor manual restart path stays generic and logs unknown subsystems")
    func supervisorManualRestartPathStaysGeneric() throws {
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(appSupervisor.contains("Self.log.notice(\"Manual restart of '\\(name)': \\(reason)\")"))
        #expect(appSupervisor.contains("pendingRestartTasks.removeValue(forKey: name)?.cancel()"))
        #expect(appSupervisor.contains("if let spec = childSpecs.first(where: { $0.id == name })"))
        #expect(appSupervisor.contains("Self.log.warning(\"Unknown subsystem for restart: \\(name)\")"))
    }

    @Test("supervisor escalation triggers orphan cleanup")
    func supervisorEscalationTriggersOrphanCleanup() throws {
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(appSupervisor.contains("AppBootstrap.shared?.orphanCleanup.cleanupAll()"))
    }

    @Test("supervisor latches start and ignores stale child exits")
    func supervisorLatchesStartAndIgnoresStaleChildExits() throws {
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(appSupervisor.contains("private var isRunning = false"))
        #expect(appSupervisor.contains("guard !isRunning else { return }"))
        #expect(appSupervisor.contains("guard childGenerations[childId] == generation else {"))
        #expect(!appSupervisor.contains("guard supervisorTask == nil else { return }"))
    }

    @Test("supervisor cancels pending restart tasks on stop and manual restart")
    func supervisorCancelsPendingRestartTasks() throws {
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(appSupervisor.contains("private var pendingRestartTasks: [String: Task<Void, Never>] = [:]"))
        #expect(appSupervisor.contains("for task in pendingRestartTasks.values {"))
        #expect(appSupervisor.contains("pendingRestartTasks.removeValue(forKey: name)?.cancel()"))
        #expect(appSupervisor.contains("pendingRestartTasks.removeValue(forKey: dependent.id)?.cancel()"))
    }

    #if false
    @Test("Hermes subprocess lifecycle is tracked by orphan cleanup")
    func hermesSubprocessLifecycleIsTrackedByOrphanCleanup() throws {}

    @Test("orphan cleanup skips signal handler registration under tests")
    func orphanCleanupSkipsSignalHandlerRegistrationUnderTests() throws {
        let orphanCleanup = try loadRepoTextFile("Epistemos/State/OrphanSubprocessCleanup.swift")

        #expect(orphanCleanup.contains("processInfoEnvironment[\"XCTestConfigurationFilePath\"] == nil"))
        #expect(orphanCleanup.contains("cleanupLog.info(\"Skipping subprocess signal handlers under tests\")"))
    }

    @Test("orphan cleanup snapshots descendant process trees before termination")
    func orphanCleanupSnapshotsDescendantProcessTrees() throws {
        let orphanCleanup = try loadRepoTextFile("Epistemos/State/OrphanSubprocessCleanup.swift")

        #expect(orphanCleanup.contains("snapshotTrackedProcessTreePIDs()"))
        #expect(orphanCleanup.contains("proc_listchildpids(parentPID, &buffer, Int32(bufferSize))"))
        #expect(orphanCleanup.contains("func cleanupProcessTree(rootPID: pid_t)"))
    }

    @Test("Hermes termination uses process-tree cleanup instead of a fake process-group API")
    func hermesTerminationUsesProcessTreeCleanup() throws {}
    #endif

    @Test("Night Brain retains a durable EventStore reference for the full run")
    func nightBrainRetainsDurableEventStoreReference() throws {
        let nightBrain = try loadRepoTextFile("Epistemos/State/NightBrainService.swift")

        #expect(nightBrain.contains("let (store, runId, alreadyCompleted) ="))
        #expect(nightBrain.contains("guard let store, let runId else {"))
        #expect(!nightBrain.contains("storeProvider()?.updateNightBrainRun("))
    }

    @Test("Night Brain store-backed jobs no longer re-query storeProvider mid-run")
    func nightBrainStoreBackedJobsNoLongerRequeryStoreProvider() throws {
        let nightBrain = try loadRepoTextFile("Epistemos/State/NightBrainService.swift")

        #expect(nightBrain.contains("try await executeJob(job, store: store)"))
        #expect(!nightBrain.contains("storeProvider()?.walCheckpointVacuum()"))
        #expect(!nightBrain.contains("storeProvider()?.deduplicateArtifacts()"))
        #expect(!nightBrain.contains("storeProvider()?.compactSnapshots(olderThanDays: 30)"))
    }

    @Test("Night Brain cloud knowledge distillation defers when the job is not wired")
    func nightBrainCloudKnowledgeRequiresConfiguredJob() throws {
        let nightBrain = try loadRepoTextFile("Epistemos/State/NightBrainService.swift")

        #expect(nightBrain.contains("private let hasCloudKnowledgeJob: Bool"))
        #expect(nightBrain.contains("self.hasCloudKnowledgeJob = cloudKnowledgeJob != nil"))
        #expect(nightBrain.contains("throw JobExecutionError.missingCloudKnowledgeJob"))
    }

    @Test("Cloud Knowledge prompt injection is wired into live Apple and cloud model paths")
    func cloudKnowledgePromptInjectionIsWiredIntoLiveRuntimePaths() throws {
        let store = try loadRepoTextFile("Epistemos/KnowledgeFusion/KnowledgeProfileStore.swift")
        let llmService = try loadRepoTextFile("Epistemos/Engine/LLMService.swift")
        let apple = try loadRepoTextFile("Epistemos/Engine/AppleIntelligenceService.swift")

        #expect(store.contains("func augmentedSystemPrompt("))
        #expect(store.contains("case .compact"))
        #expect(llmService.contains("private func knowledgeAwareSystemPrompt(from systemPrompt: String?, modelID: String) async -> String?"))
        #expect(llmService.contains("try await knowledgeProfileStore.augmentedSystemPrompt("))
        #expect(apple.contains("modelID: \"apple-intelligence\""))
        #expect(apple.contains("private func knowledgeAwareSystemPrompt(from systemPrompt: String?) async -> String?"))
    }

    @Test("note persistence paths avoid silent try-question-mark fallbacks")
    func notePersistencePathsAvoidSilentTryQuestionMarkFallbacks() throws {
        let noteChat = try loadRepoTextFile("Epistemos/State/NoteChatState.swift")
        let pageEditorCache = try loadRepoTextFile("Epistemos/Views/Notes/PageEditorCache.swift")

        #expect(!noteChat.contains("guard let sdChat = (try? context.fetch(descriptor))?.first else { return }"))
        #expect(!noteChat.contains("let existing = try? context.fetch("))
        #expect(noteChat.contains("Failed to load persisted note chat"))
        #expect(noteChat.contains("Failed to fetch existing persisted note chat"))

        #expect(!pageEditorCache.contains("try? data.write(to: url, options: .atomic)"))
        #expect(!pageEditorCache.contains("guard let data = try? Data(contentsOf: url),"))
        #expect(pageEditorCache.contains("DiskStyleCache: failed to decode cache entry"))
        #expect(pageEditorCache.contains("DiskStyleCache: failed to write cache entry"))
    }

    @Test("note insight and shell surfaces avoid silent persistence and cancellation fallbacks")
    func noteInsightAndShellSurfacesAvoidSilentFallbacks() throws {
        let noteInsight = try loadRepoTextFile("Epistemos/Engine/NoteInsightService.swift")
        let sidebar = try loadRepoTextFile("Epistemos/Views/Notes/NotesSidebar.swift")
        let inspector = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let timeMachine = try loadRepoTextFile("Epistemos/Views/Landing/TimeMachineView.swift")

        #expect(!noteInsight.contains("let existing = try? context.fetch("))
        #expect(!noteInsight.contains("try? context.save()"))
        #expect(!noteInsight.contains("return try? context.fetch("))

        #expect(!sidebar.contains("return try? modelContext.fetch(descriptor).first"))
        #expect(!sidebar.contains("try? modelContext.save()"))
        #expect(!sidebar.contains("if let insight = try? modelContext.fetch(insightDesc).first"))

        #expect(!inspector.contains("try? await Task.sleep(for: .seconds(1))"))
        #expect(!inspector.contains("if let page = try? modelContext.fetch(desc).first"))
        #expect(!inspector.contains("try? modelContext.save()"))

        #expect(!timeMachine.contains("guard let data = try? JSONEncoder().encode(snapshot) else { return }"))
        #expect(!timeMachine.contains("try? context?.save()"))
        #expect(!timeMachine.contains("try? await Task.sleep(for: .milliseconds(150))"))
    }

    @Test("landing and vault runtime surfaces avoid silent startup and fetch fallbacks")
    func landingAndVaultRuntimeSurfacesAvoidSilentFallbacks() throws {
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")
        let vaultIndexActor = try loadRepoTextFile("Epistemos/Sync/VaultIndexActor.swift")

        #expect(!landing.contains("try? await Task.sleep(for: .milliseconds(800))"))
        #expect(!landing.contains("try? await Task.sleep(for: .milliseconds(16))"))
        #expect(!landing.contains("try? bootstrap.modelContainer.mainContext.save()"))
        #expect(!landing.contains("try? await Task.sleep(for: .milliseconds(100))"))
        #expect(!landing.contains("return (try? modelContext.fetch(descriptor)) ?? []"))
        #expect(landing.contains("LandingView: failed to fetch recent chats"))
        #expect(landing.contains("LandingView: failed to save welcome-back summary note"))

        #expect(!vaultIndexActor.contains("try? url.resourceValues(forKeys: [.contentModificationDateKey])"))
        #expect(!vaultIndexActor.contains("try? modelContext.fetch(fetchDescriptor)"))
        #expect(!vaultIndexActor.contains("try? modelContext.fetchCount(countDescriptor)"))
        #expect(!vaultIndexActor.contains("try? modelContext.save()"))
        #expect(!vaultIndexActor.contains("try? Data(contentsOf: url, options: [.mappedIfSafe])"))
        #expect(vaultIndexActor.contains("private func fetchAll<T: PersistentModel>("))
        #expect(vaultIndexActor.contains("private func fetchFirst<T: PersistentModel>("))
        #expect(vaultIndexActor.contains("private func fetchCount<T: PersistentModel>("))
        #expect(vaultIndexActor.contains("private func saveContext("))
        #expect(vaultIndexActor.contains("private nonisolated static func contentModificationDate("))
    }

    @Test("chat vault and mini chat runtime surfaces avoid silent fetch save and timer fallbacks")
    func chatVaultAndMiniChatRuntimeSurfacesAvoidSilentFallbacks() throws {
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let coordinator = try loadRepoTextFile("Epistemos/App/ChatCoordinator.swift")
        let miniChat = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let miniChatWindowController = try loadRepoTextFile("Epistemos/Views/MiniChat/MiniChatWindowController.swift")
        let queryRuntime = try loadRepoTextFile("Epistemos/Engine/QueryRuntime.swift")
        let vaultMutator = try loadRepoTextFile("Epistemos/Vault/VaultChatMutator.swift")
        let vaultRegistry = try loadRepoTextFile("Epistemos/Vault/VaultRegistry.swift")

        #expect(!vaultSync.contains("let pages = (try? context.fetch(FetchDescriptor<SDPage>())) ?? []"))
        #expect(!vaultSync.contains("guard (try? context.fetch(descriptor).first) != nil else { return nil }"))
        #expect(!vaultSync.contains("if let page = try? context.fetch(desc).first, let result = exportResult"))
        #expect(!vaultSync.contains("guard let dirtyPages = try? context.fetch(dirtyDescriptor),"))
        #expect(!vaultSync.contains("try? await Task.sleep(for: .seconds(interval))"))
        #expect(!vaultSync.contains("try? await Task.sleep(for: .seconds(300))"))
        #expect(!vaultSync.contains("try? await Task.sleep(for: .seconds(2))"))
        #expect(!vaultSync.contains("if let latest = try? context.fetch(versionDesc).first, latest.body == currentBody { return }"))
        #expect(!vaultSync.contains("guard let totalCount = try? context.fetchCount(countDesc),"))
        #expect(vaultSync.contains("private func fetchAll<T: PersistentModel>("))
        #expect(vaultSync.contains("private func fetchFirst<T: PersistentModel>("))
        #expect(vaultSync.contains("private nonisolated static func fetchBackgroundAll<T: PersistentModel>("))

        #expect(!coordinator.contains("if let sdChat = try? context.fetch(descriptor).first {"))
        #expect(!coordinator.contains("guard let chat = try? context.fetch(descriptor).first else { return [] }"))
        #expect(!coordinator.contains("let allWorkspaces: [SDWorkspace] = (try? context.fetch(FetchDescriptor<SDWorkspace>())) ?? []"))
        #expect(!coordinator.contains("if let chats = try? context.fetch(chatDesc) {"))
        #expect(!coordinator.contains("if let folders = try? context.fetch(folderDesc),"))
        #expect(!coordinator.contains("if let existing = try? context.fetch(descriptor).first {"))
        #expect(coordinator.contains("ChatCoordinator: failed to fetch"))

        #expect(!miniChat.contains("if let chat = try? modelContext.fetch(descriptor).first {"))
        #expect(!miniChat.contains("return try? modelContext.fetch(descriptor).first"))
        #expect(!miniChat.contains("guard let pages = try? modelContext.fetch(descriptor) else { return [] }"))
        #expect(!miniChat.contains("return (try? modelContext.fetch(descriptor)) ?? []"))
        #expect(!miniChat.contains("if let existing = try? modelContext.fetch(descriptor).first {"))
        #expect(miniChat.contains("MiniChatView: failed to fetch"))

        #expect(!miniChatWindowController.contains("guard let page = try? bootstrap.modelContainer.mainContext.fetch(descriptor).first else { return nil }"))
        #expect(miniChatWindowController.contains("MiniChatWindowController: failed to fetch active note attachment"))

        #expect(!queryRuntime.contains("let results = (try? searchIndex.search(query: query, limit: limit)) ?? []"))
        #expect(!queryRuntime.contains("let blockResults = (try? searchIndex.searchBlocks(query: query, limit: limit)) ?? []"))
        #expect(queryRuntime.contains("QueryRuntime: failed to search"))

        #expect(!vaultMutator.contains("let before = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? defaultMemoryBody(for: targetVault)"))
        #expect(!vaultMutator.contains("try? await Task.sleep(for: .seconds(timeoutSeconds))"))
        #expect(vaultMutator.contains("VaultChatMutator: failed to read staged memory file"))

        #expect(!vaultRegistry.contains("guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),"))
        #expect(vaultRegistry.contains("VaultRegistry: failed to inspect modification date"))
    }

    @Test("cloud standard chats stay on the standard pipeline unless agent mode is explicitly selected")
    func cloudStandardChatsStayOnStandardPipelineUnlessAgentModeIsSelected() throws {
        let coordinator = try loadRepoTextFile("Epistemos/App/ChatCoordinator.swift")

        #expect(coordinator.contains("if mode == .api, operatingMode == .agent"))
        #expect(coordinator.contains("pipeline.run("))
        #expect(coordinator.contains("operatingMode: operatingMode"))
    }

    @Test("workspace and attachment-heavy chats keep lightweight workspace context on the default path")
    func workspaceAndAttachmentHeavyChatsKeepLightweightWorkspaceContextOnTheDefaultPath() throws {
        let coordinator = try loadRepoTextFile("Epistemos/App/ChatCoordinator.swift")

        #expect(coordinator.contains("let hasExplicitContext = Self.queryContainsExplicitContext("))
        #expect(coordinator.contains("let hasExplicitUserContext = hasExplicitContext || !userAttachments.isEmpty"))
        #expect(coordinator.contains("let shouldInjectWorkspaceContext = isSessionQuery || !hasExplicitUserContext"))
        #expect(coordinator.contains("buildRequiredAttachmentContractSection()"))
        #expect(coordinator.contains("if deepContext {"))
        #expect(coordinator.contains("[Today's Conversations]"))
    }

    @Test("note chat always treats the current note body as primary context")
    func noteChatAlwaysTreatsTheCurrentNoteBodyAsPrimaryContext() throws {
        let source = try loadRepoTextFile("Epistemos/State/NoteChatState.swift")

        #expect(source.contains("The note content provided in the prompt is the exact live document the user is editing right now."))
        #expect(source.contains("Do not ask the user to paste the note again"))
        #expect(source.contains("Request: \\(trimmed)"))
        #expect(source.contains("systemPrompt: nil"))
    }

    @Test("code editor release path keeps only the focused ask-bar mode")
    func codeEditorReleasePathKeepsOnlyTheFocusedAskBarMode() throws {
        let codeEditor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let askBar = try loadRepoTextFile("Epistemos/Views/Notes/InlineResponseHighlighter.swift")

        #expect(codeEditor.contains("static let availableAskBarResponseModes: [CodeAskBarResponseMode] = [.focused]"))
        #expect(codeEditor.contains("private func sanitizedAskBarResponseMode("))
        #expect(askBar.contains("if availableModes.count > 1"))
    }

    @Test("harness perf hotspots reuse shared timestamp helpers")
    func harnessPerfHotspotsReuseSharedHelpers() throws {
        let progressStore = try loadRepoTextFile("Epistemos/Harness/ProgressStore.swift")
        let harnessRegistry = try loadRepoTextFile("Epistemos/Harness/HarnessRegistry.swift")
        let harnessLab = try loadRepoTextFile("Epistemos/Harness/HarnessLab.swift")

        #expect(progressStore.contains("private static func sortedSessionDirectories("))
        #expect(progressStore.contains("private static func sessionDirectoryEntries("))

        #expect(harnessRegistry.contains("private nonisolated static func timestampString("))
        #expect(!harnessRegistry.contains("ISO8601DateFormatter().string(from: Date())"))

        #expect(harnessLab.contains("private enum HarnessLabTime"))
        #expect(harnessLab.contains("static func timestampString("))
        #expect(!harnessLab.contains("ISO8601DateFormatter().string(from: Date())"))
    }

    @Test("landing perf seams share explicit delay helpers")
    func landingAndAdminPerfSeamsShareExplicitDelayHelpers() throws {
        let overlay = try loadRepoTextFile("Epistemos/Views/Landing/SessionIntelligenceOverlay.swift")
        let workspaceSwitcher = try loadRepoTextFile("Epistemos/Views/Landing/WorkspaceSwitcherOverlay.swift")

        #expect(overlay.contains("private enum SessionIntelligenceOverlayTiming"))
        #expect(overlay.contains("private func pause(_ duration: Duration) async -> Bool"))
        #expect(!overlay.contains("try? await Task.sleep(for: .milliseconds(100))"))
        #expect(!overlay.contains("try? await Task.sleep(for: .milliseconds(150))"))
        #expect(overlay.contains("descriptor.fetchLimit = 1"))

        #expect(workspaceSwitcher.contains("private enum WorkspaceSwitcherOverlayTiming"))
        #expect(workspaceSwitcher.contains("private func performAfterDismiss("))
        #expect(workspaceSwitcher.contains("private func pause(_ duration: Duration) async -> Bool"))
        #expect(!workspaceSwitcher.contains("try? await Task.sleep(for: .milliseconds(150))"))
    }

    #if false
    @Test("omega note and checkpoint surfaces avoid silent persistence fallbacks")
    func omegaNoteAndCheckpointSurfacesAvoidSilentFallbacks() throws {}
    #endif

    @Test("python setup subprocess helpers stream process output off the main actor")
    func pythonAndHermesSetupSubprocessHelpersStreamOutputOffMain() throws {
        let pythonEnvironmentManager = try loadRepoTextFile("Epistemos/KnowledgeFusion/PythonEnvironmentManager.swift")

        #expect(pythonEnvironmentManager.contains("private nonisolated func executeProcess("))
        #expect(pythonEnvironmentManager.contains("DispatchQueue.global(qos: .utility).async"))
        #expect(pythonEnvironmentManager.contains("let execution = try await executeProcess("))
        #expect(pythonEnvironmentManager.contains("stdoutHandle?.readabilityHandler = { handle in"))
        #expect(pythonEnvironmentManager.contains("stderrHandle?.readabilityHandler = { handle in"))
        #expect(pythonEnvironmentManager.contains("process.terminationHandler = { proc in"))
        #expect(!pythonEnvironmentManager.contains("runProcessCaptureSync("))
        #expect(!pythonEnvironmentManager.contains("process.waitUntilExit()"))
    }

    #if false
    @Test("Hermes health check requires a live bridge ping before reporting healthy")
    func hermesHealthCheckRequiresLiveBridgePing() throws {}
    #endif

    @Test("long-lived subprocess continuations have timeout and cancellation escape hatches")
    func longLivedSubprocessContinuationsHaveTimeoutAndCancellationEscapeHatches() throws {
        let pythonEnvironmentManager = try loadRepoTextFile("Epistemos/KnowledgeFusion/PythonEnvironmentManager.swift")
        let audioTranscriber = try loadRepoTextFile("Epistemos/KnowledgeFusion/DataIngestion/AudioTranscriber.swift")
        let qLoRATrainer = try loadRepoTextFile("Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift")
        let ktoTrainer = try loadRepoTextFile("Epistemos/KnowledgeFusion/Alignment/KTOTrainer.swift")
        let vaultMutator = try loadRepoTextFile("Epistemos/Vault/VaultChatMutator.swift")

        #expect(pythonEnvironmentManager.contains("withTaskCancellationHandler"))
        #expect(pythonEnvironmentManager.contains("ThrowingProcessContinuationState<PythonProcessExecution>()"))
        #expect(pythonEnvironmentManager.contains("TimeoutError(seconds: timeoutSeconds)"))

        #expect(audioTranscriber.contains("withTaskCancellationHandler"))
        #expect(audioTranscriber.contains("ThrowingProcessContinuationState<String>()"))
        #expect(audioTranscriber.contains("TimeoutError(seconds: timeoutSeconds)"))

        #expect(qLoRATrainer.contains("withTaskCancellationHandler"))
        #expect(qLoRATrainer.contains("ThrowingProcessContinuationState<Void>()"))
        #expect(qLoRATrainer.contains("TimeoutError(seconds: timeoutSeconds)"))
        #expect(qLoRATrainer.contains("defer { activeProcess = nil }"))

        #expect(ktoTrainer.contains("withTaskCancellationHandler"))
        #expect(ktoTrainer.contains("ThrowingProcessContinuationState<Void>()"))
        #expect(ktoTrainer.contains("TimeoutError(seconds: timeoutSeconds)"))

        #expect(vaultMutator.contains("withTaskCancellationHandler"))
        #expect(vaultMutator.contains("ThrowingProcessContinuationState<String>()"))
        #expect(vaultMutator.contains("TimeoutError(seconds: timeoutSeconds)"))
        #expect(!vaultMutator.contains("process.waitUntilExit()"))
    }

    @Test("setup and harness subprocess helpers terminate on cancellation")
    func setupAndHarnessSubprocessHelpersTerminateOnCancellation() throws {
        let completionChecker = try loadRepoTextFile("Epistemos/Harness/CompletionChecker.swift")
        let harnessLab = try loadRepoTextFile("Epistemos/Harness/HarnessLab.swift")
        let evalSandbox = try loadRepoTextFile("Epistemos/Harness/EvalSandbox.swift")

        #expect(completionChecker.contains("withTaskCancellationHandler"))
        #expect(completionChecker.contains("ProcessContinuationState<ProcessResult>()"))
        #expect(completionChecker.contains("Cancelled \\(executable)"))

        #expect(harnessLab.contains("withTaskCancellationHandler"))
        #expect(harnessLab.contains("ProcessContinuationState<ProcessResult>()"))
        #expect(harnessLab.contains("Cancelled proposer agent"))

        #expect(evalSandbox.contains("withTaskCancellationHandler"))
        #expect(evalSandbox.contains("ProcessContinuationState<ProcessResult>()"))
        #expect(evalSandbox.contains("Cancelled sandboxed command"))
    }

    @Test("main actor capture and vault helpers offload blocking subprocess waits")
    func mainActorCaptureAndVaultHelpersOffloadBlockingSubprocessWaits() throws {
        let vaultMutator = try loadRepoTextFile("Epistemos/Vault/VaultChatMutator.swift")
        let embodiedCapture = try loadRepoTextFile("Epistemos/KnowledgeFusion/SyntheticData/EmbodiedCaptureService.swift")
        let screenCapture = try loadRepoTextFile("Epistemos/Omega/Vision/ScreenCaptureService.swift")

        #expect(vaultMutator.contains("private nonisolated func runGitOffMain("))
        #expect(vaultMutator.contains("try await runGitOffMain("))
        #expect(vaultMutator.contains("DispatchQueue.global(qos: .utility).async"))

        #expect(embodiedCapture.contains("private nonisolated func captureScreenshotOffMain("))
        #expect(embodiedCapture.contains("await captureScreenshotOffMain("))

        #expect(screenCapture.contains("private nonisolated func restartReplayd("))
        #expect(screenCapture.contains("await restartReplayd("))
    }

    #if false
    @Test("Agent heartbeat monitors Hermes after dispatch instead of blind sleeping to completion")
    func agentHeartbeatMonitorsHermesAfterDispatch() throws {}

    @Test("Agent heartbeat monitoring handles cancellation explicitly")
    func agentHeartbeatMonitoringHandlesCancellationExplicitly() throws {}
    #endif

    @Test("Supervisor background sleep paths no longer swallow cancellation")
    func supervisorBackgroundSleepPathsNoLongerSwallowCancellation() throws {
        let appSupervisor = try loadRepoTextFile("Epistemos/State/AppSupervisor.swift")

        #expect(!appSupervisor.contains("try? await Task.sleep(for: .seconds(60))"))
        #expect(!appSupervisor.contains("try? await Task.sleep(for: .seconds(interval))"))
        #expect(!appSupervisor.contains("try? await Task.sleep(for: .seconds(delay))"))
        #expect(appSupervisor.contains("catch is CancellationError"))
    }

    @Test("Ambient capture runtime paths no longer swallow debounce or parse failures")
    func ambientCaptureRuntimePathsNoLongerSwallowFailures() throws {
        let ambientCapture = try loadRepoTextFile("Epistemos/State/AmbientCaptureService.swift")

        #expect(!ambientCapture.contains("try? await Task.sleep(nanoseconds: 300_000_000)"))
        #expect(!ambientCapture.contains("let tree = try? JSONSerialization.jsonObject(with: data) as? [String: Any]"))
        #expect(!ambientCapture.contains("return patterns.compactMap { try? NSRegularExpression(pattern: $0) }"))
        #expect(ambientCapture.contains("AmbientCapture: failed to decode AX tree JSON"))
        #expect(ambientCapture.contains("failed to compile secret redaction pattern"))
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadRepoTextFileWithRetry(relativePath: relativePath, testsFilePath: #filePath)
    }
}

@Suite("Inference Cloud Selection", .serialized)
struct InferenceCloudSelectionTests {
    private let inferenceDefaultsKeys = [
        "epistemos.localRoutingMode",
        "epistemos.preferredLocalTextModelID",
        "epistemos.preferredChatModelSelection",
        "epistemos.activeAIProvider",
        "epistemos.lastNonLocalAIProvider",
        "epistemos.openAIWebSearchEnabled",
        "epistemos.openAICodeInterpreterEnabled",
        "epistemos.anthropicExtendedThinkingEnabled",
        "epistemos.anthropicThinkingBudgetTokens",
        "epistemos.googleGroundingEnabled",
        "epistemos.cloudSetupHintShown",
        "epistemos.preferredCloudModel.openAI",
        "epistemos.preferredCloudModel.anthropic",
        "epistemos.preferredCloudModel.google",
        "epistemos.preferredCloudModel.zai",
        "epistemos.preferredCloudModel.kimi",
        "epistemos.preferredCloudModel.minimax",
        "epistemos.preferredCloudModel.deepseek",
    ]

    @MainActor
    private func withResetInferenceDefaults(
        _ body: () async throws -> Void
    ) async rethrows {
        let defaults = UserDefaults.standard
        let savedValues = inferenceDefaultsKeys.reduce(into: [String: Any?]()) { partialResult, key in
            partialResult[key] = defaults.object(forKey: key)
            defaults.removeObject(forKey: key)
        }
        defer {
            for key in inferenceDefaultsKeys {
                if let value = savedValues[key] ?? nil {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        try await body()
    }

    @MainActor
    private func withSavedAPIKey(
        for provider: CloudModelProvider,
        _ body: () async throws -> Void
    ) async rethrows {
        let originalValue = Keychain.load(for: provider.apiKeyKeychainKey)
        defer {
            if let originalValue {
                _ = Keychain.save(originalValue, for: provider.apiKeyKeychainKey)
            } else {
                Keychain.delete(for: provider.apiKeyKeychainKey)
            }
        }
        try await body()
    }

    @MainActor
    @Test("unconfigured cloud selection falls back to local qwen")
    func unconfiguredCloudSelectionFallsBackToLocalQwen() async {
        await withSavedAPIKey(for: .openAI) {
            Keychain.delete(for: CloudModelProvider.openAI.apiKeyKeychainKey)

            await withResetInferenceDefaults {
                let inference = InferenceState()
                let fallback = ChatModelSelection.localMLX(inference.preferredLocalTextModelID)

                inference.setPreferredChatModelSelection(.cloud(.openAIGPT54))

                #expect(inference.preferredChatModelSelection == fallback)
            }
        }
    }

    @MainActor
    @Test("active AI provider scopes cloud models and remembers the last model per provider")
    func activeAIProviderScopesCloudModelsAndRemembersProviderModels() async {
        await withResetInferenceDefaults {
            var keychainValues: [String: String] = [
                CloudModelProvider.openAI.apiKeyKeychainKey: "openai-test-key",
                CloudModelProvider.anthropic.apiKeyKeychainKey: "anthropic-test-key",
                CloudModelProvider.zai.apiKeyKeychainKey: "zai-test-key",
                CloudModelProvider.kimi.apiKeyKeychainKey: "kimi-test-key",
                CloudModelProvider.minimax.apiKeyKeychainKey: "minimax-test-key",
                CloudModelProvider.deepseek.apiKeyKeychainKey: "deepseek-test-key",
            ]
            let inference = InferenceState(
                keychainLoad: { keychainValues[$0] },
                keychainSave: { value, key in
                    keychainValues[key] = value
                    return true
                },
                keychainDelete: { keychainValues.removeValue(forKey: $0) }
            )

            #expect(inference.activeAIProvider == .openAI)
            #expect(inference.activeCloudProvider == .openAI)
            #expect(inference.activeCloudModels == CloudTextModelID.models(for: .openAI))

            inference.setPreferredChatModelSelection(.cloud(.openAIGPT54Mini))
            inference.setActiveAIProvider(.anthropic)

            #expect(inference.activeAIProvider == .anthropic)
            #expect(inference.activeCloudProvider == .anthropic)
            #expect(inference.activeCloudModels == CloudTextModelID.models(for: .anthropic))
            #expect(inference.preferredChatModelSelection == .cloud(.anthropicClaudeSonnet4))

            inference.setPreferredChatModelSelection(.cloud(.anthropicClaudeHaiku35))
            inference.setActiveAIProvider(.localOnly)
            #expect(inference.preferredChatModelSelection == .localMLX(inference.preferredLocalTextModelID))

            inference.setActiveAIProvider(.anthropic)
            #expect(inference.preferredChatModelSelection == .localMLX(inference.preferredLocalTextModelID))

            inference.setPreferredChatModelSelection(.cloud(.anthropicClaudeHaiku35))
            inference.setActiveAIProvider(.openAI)
            inference.setActiveAIProvider(.anthropic)
            #expect(inference.preferredChatModelSelection == .cloud(.anthropicClaudeHaiku35))

            inference.setActiveAIProvider(.deepseek)
            #expect(inference.activeCloudProvider == .deepseek)
            #expect(inference.activeCloudModels == CloudTextModelID.models(for: .deepseek))
        }
    }

    @MainActor
    @Test("cloud mode toggle keeps local-only routing explicit and restores the last cloud provider")
    func cloudModeToggleKeepsLocalOnlyRoutingExplicit() async {
        await withResetInferenceDefaults {
            var keychainValues: [String: String] = [
                CloudModelProvider.openAI.apiKeyKeychainKey: "openai-test-key",
                CloudModelProvider.anthropic.apiKeyKeychainKey: "anthropic-test-key",
            ]
            let inference = InferenceState(
                keychainLoad: { keychainValues[$0] },
                keychainSave: { value, key in
                    keychainValues[key] = value
                    return true
                },
                keychainDelete: { keychainValues.removeValue(forKey: $0) }
            )

            #expect(inference.activeAIProvider == .openAI)
            inference.setPreferredChatModelSelection(.cloud(.anthropicClaudeSonnet4))
            inference.setActiveAIProvider(.anthropic)
            #expect(inference.activeAIProvider == .anthropic)

            inference.setCloudModelsEnabled(false)
            #expect(inference.activeAIProvider == .localOnly)
            #expect(inference.preferredChatModelSelection == .localMLX(inference.preferredLocalTextModelID))

            inference.setCloudModelsEnabled(true)
            #expect(inference.activeAIProvider == .anthropic)
        }
    }

    @MainActor
    @Test("provider runtime controls and Firecrawl key persist through inference state")
    func providerRuntimeControlsAndFirecrawlKeyPersistThroughInferenceState() async {
        await withResetInferenceDefaults {
            var keychainValues: [String: String] = [:]
            let inference = InferenceState(
                keychainLoad: { keychainValues[$0] },
                keychainSave: { value, key in
                    keychainValues[key] = value
                    return true
                },
                keychainDelete: { keychainValues.removeValue(forKey: $0) }
            )

            #expect(!inference.openAIWebSearchEnabled)
            #expect(!inference.openAICodeInterpreterEnabled)
            #expect(!inference.anthropicExtendedThinkingEnabled)
            #expect(inference.anthropicThinkingBudgetTokens == 8_000)
            #expect(!inference.googleGroundingEnabled)
            #expect(inference.firecrawlAPIKey() == nil)

            inference.setOpenAIWebSearchEnabled(true)
            inference.setOpenAICodeInterpreterEnabled(true)
            inference.setAnthropicExtendedThinkingEnabled(true)
            inference.setAnthropicThinkingBudgetTokens(12_288)
            inference.setGoogleGroundingEnabled(true)
            _ = inference.setFirecrawlAPIKey("fc-test-key")

            #expect(inference.openAIWebSearchEnabled)
            #expect(inference.openAICodeInterpreterEnabled)
            #expect(inference.anthropicExtendedThinkingEnabled)
            #expect(inference.anthropicThinkingBudgetTokens == 12_288)
            #expect(inference.googleGroundingEnabled)
            #expect(inference.firecrawlAPIKey() == "fc-test-key")

            _ = inference.setFirecrawlAPIKey("")
            #expect(inference.firecrawlAPIKey() == nil)
        }
    }

    @MainActor
    @Test("cloud setup hint shows once and stays dismissed after first-use guidance")
    func cloudSetupHintShowsOnceAndPersistsDismissal() async {
        await withResetInferenceDefaults {
            var keychainValues: [String: String] = [:]
            let inference = InferenceState(
                keychainLoad: { keychainValues[$0] },
                keychainSave: { value, key in
                    keychainValues[key] = value
                    return true
                },
                keychainDelete: { keychainValues.removeValue(forKey: $0) }
            )

            #expect(inference.shouldShowCloudSetupHint)
            inference.markCloudSetupHintShown()
            #expect(!inference.shouldShowCloudSetupHint)

            let reloaded = InferenceState(
                keychainLoad: { keychainValues[$0] },
                keychainSave: { value, key in
                    keychainValues[key] = value
                    return true
                },
                keychainDelete: { keychainValues.removeValue(forKey: $0) }
            )
            #expect(!reloaded.shouldShowCloudSetupHint)
        }
    }

    @Test("inference settings keep openai first cloud controls advanced mode and remind-later hints")
    func inferenceSettingsKeepOpenAIFirstCloudControlsAndHints() throws {
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )

        #expect(settings.contains("Settings Mode"))
        #expect(settings.contains("Regular"))
        #expect(settings.contains("Advanced"))
        #expect(settings.contains("Enable Cloud Models"))
        #expect(settings.contains("Active Cloud"))
        #expect(settings.contains("Other Cloud Providers"))
        #expect(settings.contains("OpenAI Recommended"))
        #expect(settings.contains("Remind Me Later"))
        #expect(settings.contains("API Key (manual)"))
        #expect(settings.contains("showCloudSetupHint"))
        #expect(settings.contains("cloudSetupHintPopover"))
        #expect(settings.contains("CloudHintPopover"))
        #expect(inference.contains("cloudSetupHintShownDefaultsKey"))
        #expect(inference.contains("shouldShowCloudSetupHint"))
        #expect(inference.contains("markCloudSetupHintShown"))
        #expect(inference.contains("setCloudModelsEnabled"))
        #expect(inference.contains("lastNonLocalAIProviderDefaultsKey"))
    }

    @Test("OpenAI OAuth checking has a hard timeout and explicit retry affordances")
    func openAIOAuthCheckingHasTimeoutAndRetryAffordances() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )
        let sharedCard = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Shared/CloudProviderSetupCard.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("openAISignInTimeout: Duration = .seconds(90)"))
        #expect(authService.contains("Task.sleep(for: timeout)"))
        #expect(authService.contains("throw CloudProviderAuthError.openAIDeviceCodeTimedOut"))
        #expect(settings.contains("Retry OpenAI Sign In"))
        #expect(sharedCard.contains("Retry OpenAI Sign In"))
    }

    @Test("OpenAI Codex auth and validation routes carry the required client version")
    func openAICodexAuthAndValidationRoutesCarryTheRequiredClientVersion() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let llmService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/LLMService.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("enum OpenAICodexRuntimeMetadata"))
        #expect(authService.contains("static let clientVersion"))
        #expect(authService.contains("URLQueryItem(name: \"client_version\""))
        #expect(llmService.contains("OpenAICodexRuntimeMetadata.url(appendingClientVersionTo:"))
        #expect(llmService.contains("/backend-api/codex"))
    }

    @Test("OpenAI OAuth shows the device code directly in the app")
    func openAIOAuthShowsTheDeviceCodeDirectlyInTheApp() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )
        let sharedCard = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Shared/CloudProviderSetupCard.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("onDeviceCodeReady"))
        #expect(inference.contains("onDeviceCodeReady"))
        #expect(settings.contains("@State private var openAIDeviceAuthorization"))
        #expect(settings.contains("OpenAIDeviceAuthorizationSheet"))
        #expect(sharedCard.contains("struct OpenAIDeviceAuthorizationSheet"))
        #expect(sharedCard.contains("Copy Code"))
        #expect(sharedCard.contains("Open Verification Page"))
    }

    @Test("Anthropic import surfaces account status, retry, and connected account details")
    func anthropicImportSurfacesAccountStatusRetryAndConnectedAccountDetails() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )
        let sharedCard = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Shared/CloudProviderSetupCard.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("AnthropicClaudeCodeImportResult"))
        #expect(authService.contains("func anthropicClaudeCodeCredential(from data: Data)"))
        #expect(authService.contains("accountLabel: Self.inferredAnthropicAccountLabel"))
        #expect(inference.contains("cloudProviderValidationStates[.anthropic] = .checking"))
        #expect(inference.contains("Connected as \\(accountLabel)."))
        #expect(inference.contains("No account session connected"))
        #expect(settings.contains("Retry Claude Code Import"))
        #expect(settings.contains("CloudProviderAccountConnectionRow"))
        #expect(sharedCard.contains("Retry Claude Code Import"))
        #expect(sharedCard.contains("CloudProviderAccountConnectionRow"))
    }

    @Test("Google OAuth surfaces timeout, retry, and connected account confirmation")
    func googleOAuthSurfacesTimeoutRetryAndConnectedAccountConfirmation() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )
        let sharedCard = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Shared/CloudProviderSetupCard.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("googleSignInTimeout: Duration = .seconds(90)"))
        #expect(authService.contains("waitForAuthorizationResult(timeout: googleSignInTimeout)"))
        #expect(authService.contains("resolveFailureIfNeeded(CloudProviderAuthError.googleAuthorizationTimedOut)"))
        #expect(authService.contains("fetchGoogleAccountLabel"))
        #expect(authService.contains("func googleAccountLabel(fromUserInfoData data: Data)"))
        #expect(inference.contains("recordCloudProviderValidationFailure"))
        #expect(inference.contains("Connected as \\(accountLabel)."))
        #expect(settings.contains("Retry Google OAuth"))
        #expect(settings.contains("CloudProviderAccountConnectionRow"))
        #expect(sharedCard.contains("Retry Google OAuth"))
    }

    @Test("OAuth provider settings require verified access before activation")
    func oauthProviderSettingsRequireVerifiedAccessBeforeActivation() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )
        let sharedCard = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Shared/CloudProviderSetupCard.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("func openAIAccountLabel(fromAccessToken token: String) -> String?"))
        #expect(inference.contains("var isVerified: Bool"))
        #expect(inference.contains("\"Saved\""))
        #expect(inference.contains("\"Verified\""))
        #expect(inference.contains("This check times out after 90 seconds."))
        #expect(inference.contains("Run a live check before making this provider active."))
        #expect(inference.contains("CloudProviderAccountConnectionState"))
        #expect(inference.contains("If OpenAI asks you to enable access first"))
        #expect(inference.contains("Claude Code needs to be signed in first"))
        #expect(settings.contains(".disabled(!validationState.isVerified)"))
        #expect(settings.contains("Verify live access before making this provider active."))
        #expect(inference.contains("Connect Google OAuth first with the Desktop-app client JSON from Google Cloud Console and the matching Google Cloud project ID"))
        #expect(sharedCard.contains("Verify live access before making this provider active."))
    }

    @Test("legacy keys and Google draft auth inputs surface explicit validation feedback")
    func legacyKeysAndGoogleDraftAuthInputsSurfaceExplicitValidationFeedback() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )
        let sharedCard = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Shared/CloudProviderSetupCard.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("let projectID = (container[\"project_id\"] as? String)?"))
        #expect(!authService.contains("guard !projectID.isEmpty"))
        #expect(inference.contains("func resetCloudProviderValidationState(for provider: CloudModelProvider)"))
        #expect(inference.contains("No Codex account session was found in ~/.codex/auth.json."))
        #expect(inference.contains("cloudProviderValidationStates[.openAI] = .invalid"))
        #expect(inference.contains("Paste or type a non-empty"))
        #expect(inference.contains("Clipboard doesn't contain a non-empty"))
        #expect(settings.contains("Couldn't read the selected Google OAuth client JSON file."))
        #expect(settings.contains("Choose the Google OAuth client JSON you downloaded from Google Cloud Console for a Desktop app before connecting Google OAuth."))
        #expect(settings.contains("Enter the Google Cloud project ID for the same project where Gemini API is enabled before connecting Google OAuth."))
        #expect(settings.contains("Google OAuth client JSON verified."))
        #expect(settings.contains("Clear Google OAuth JSON"))
        #expect(settings.contains("CloudProviderSetupAutomation.loadGoogleOAuthClientConfigData()"))
        #expect(settings.contains("CloudProviderSetupAutomation.loadGoogleOAuthClientFilename()"))
        #expect(settings.contains("CloudProviderSetupAutomation.loadGoogleOAuthProjectIDDraft()"))
        #expect(settings.contains("CloudProviderSetupAutomation.persistGoogleOAuthProjectIDDraft(newValue)"))
        #expect(settings.contains("CloudProviderSetupAutomation.persistGoogleOAuthClientConfig("))
        #expect(settings.contains("Removed the saved Google OAuth client JSON."))
        #expect(sharedCard.contains("storedGoogleOAuthClientConfiguration()"))
        #expect(sharedCard.contains("result = await inference.signInToGoogle(configuration: configuration)"))
        #expect(inference.contains("Clipboard doesn't contain a non-empty"))
    }

    @Test("Google OAuth setup copy explains the exact JSON file and project ID")
    func googleOAuthSetupCopyExplainsTheExactJSONFileAndProjectID() throws {
        let authService = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/CloudProviderAuthService.swift",
            testsFilePath: #filePath
        )
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )
        let sharedCard = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Shared/CloudProviderSetupCard.swift",
            testsFilePath: #filePath
        )

        #expect(authService.contains("installed.client_id"))
        #expect(authService.contains("installed.client_secret"))
        #expect(settings.contains("Choose Google OAuth JSON"))
        #expect(settings.contains("Google Cloud project ID (not project number)"))
        #expect(settings.contains("Choose the OAuth client JSON you downloaded from Google Cloud Console after creating an OAuth client ID for a Desktop app."))
        #expect(settings.contains("Enter the Google Cloud project ID for the same Gemini-enabled project."))
        #expect(inference.contains("create an OAuth client ID for a Desktop app"))
        #expect(sharedCard.contains("Google OAuth client JSON"))
        #expect(sharedCard.contains("Google Cloud project ID"))
    }

    @Test("saved provider access exposes a visible top-level check action")
    func savedProviderAccessExposesAVisibleTopLevelCheckAction() throws {
        let inference = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )
        let sharedCard = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Shared/CloudProviderSetupCard.swift",
            testsFilePath: #filePath
        )

        #expect(inference.contains("Tap Check Access before making this provider active."))
        #expect(settings.contains("if hasOAuthSession || hasSavedAPIKey"))
        #expect(settings.contains("Button(validationState.isVerified ? \"Re-check Access\" : \"Check Access\")"))
        #expect(settings.contains("Task { _ = await inference.validateCloudAccess(for: provider) }"))
        #expect(sharedCard.contains("if hasConfiguredAccess"))
        #expect(sharedCard.contains("Button(validationState.isVerified ? \"Re-check Access\" : \"Check Access\")"))
        #expect(sharedCard.contains("Task { _ = await inference.validateCloudAccess(for: provider) }"))
    }

    @Test("inference settings support regular and advanced presentation")
    func inferenceSettingsSupportRegularAndAdvancedPresentation() throws {
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )

        #expect(settings.contains("@AppStorage(\"epistemos.inferenceAdvancedSettingsEnabled\")"))
        #expect(settings.contains("Settings Mode"))
        #expect(settings.contains("Text(\"Regular\")"))
        #expect(settings.contains("Text(\"Advanced\")"))
        #expect(settings.contains("if showsAdvancedSettings"))
        #expect(settings.contains("Enable Cloud Models"))
        #expect(settings.contains("Active Cloud"))
        #expect(settings.contains("Other Cloud Providers"))
    }

    @Test("settings hints support native popovers and remind-later actions")
    func settingsHintsSupportNativePopoversAndRemindLaterActions() throws {
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/SettingsView.swift",
            testsFilePath: #filePath
        )

        #expect(settings.contains("SettingsHelpHeader"))
        #expect(settings.contains("CloudHintPopover"))
        #expect(settings.contains("showSettingsModeHint"))
        #expect(settings.contains("showRoutingHint"))
        #expect(settings.contains("showLocalAIHint"))
        #expect(settings.contains("showOtherCloudProvidersHint"))
        #expect(settings.contains("showResponseTokensHint"))
        #expect(settings.contains("Button(\"Remind Me Later\")"))
        #expect(settings.contains("Button(\"Got It\")"))
        #expect(settings.contains("questionmark.circle"))
        #expect(settings.contains(".popover("))
    }

    @Test("runtime popover uses available operating modes instead of disabled all-cases")
    func runtimePopoverUsesAvailableOperatingModesInsteadOfDisabledAllCases() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/RootView.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("ForEach(displayedOperatingModes"))
        #expect(!source.contains("ForEach(EpistemosOperatingMode.allCases"))
        #expect(source.contains(".easeInOut(duration: 0.15)"))
    }

    @MainActor
    @Test("clearing the active cloud provider key sanitizes the selected chat model")
    func clearingActiveCloudProviderKeySanitizesSelectedChatModel() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/State/InferenceState.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("guard let activeCloudProvider = provider.cloudProvider else"))
        #expect(source.contains("guard hasConfiguredCloudAccess(for: activeCloudProvider) else"))
        #expect(source.contains("persistPreferredChatModelSelection(.localMLX(preferredLocalTextModelID))"))
    }

    #if false
    @Test("agent runtime route supports account-backed cloud credentials")
    func agentRuntimeRouteSupportsAccountBackedCloudCredentials() throws {}
    #endif

    @Test("vault registry and session browser expose shared helpers for vault services")
    func vaultRegistryAndSessionBrowserExposeSharedHelpersForVaultServices() throws {
        let registry = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Vault/VaultRegistry.swift",
            testsFilePath: #filePath
        )
        let browser = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Vault/SessionBrowser.swift",
            testsFilePath: #filePath
        )

        #expect(registry.contains("static let shared = VaultRegistry()"))
        #expect(registry.contains("func resolveVaultPath(for identity: VaultIdentity) -> String?"))
        #expect(browser.contains("static let shared = SessionBrowser()"))
        #expect(browser.contains("var sessions: [SessionInfo]"))
        #expect(browser.contains("func refreshSessions(for vaultIdentity: VaultIdentity)"))
        #expect(browser.contains("var sessionId: String { id }"))
    }

    @Test("skill evolution uses dedicated trace models and live trace inputs")
    func skillEvolutionUsesDedicatedTraceModelsAndLiveTraceInputs() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Vault/SkillEvolutionService.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("struct SkillTraceEvent"))
        #expect(!source.contains("struct TraceEvent"))
        #expect(source.contains("lastPathComponent == \"trace.json\""))
        #expect(source.contains("pathExtension == \"jsonl\""))
        #expect(source.contains("SkillMutationProposal(from: decodedProposal)"))
    }

    @Test("chat coordinator prompts before non-read-only tools and leaves computer execution to the bridge delegate")
    func chatCoordinatorPromptsBeforeNonReadOnlyToolsAndLeavesComputerExecutionToDelegate() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/ChatCoordinator.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("approved = await promptForToolApproval(request)"))
        #expect(source.contains("capturedDelegate?.resolvePermission(permissionId: request.id, approved: approved)"))
        #expect(source.contains("private func promptForToolApproval(_ request: AgentPermissionRequest) async -> Bool"))
        #expect(!source.contains("ComputerUseBridge.shared.execute(actionJSON: inputJson)"))
        #expect(!source.contains("Auto-approve for now"))
    }

    @Test("streaming delegate and rust agent loop return native computer-use results")
    func streamingDelegateAndRustAgentLoopReturnNativeComputerUseResults() throws {
        let swift = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Bridge/StreamingDelegate.swift",
            testsFilePath: #filePath
        )
        let bridge = try loadRepoTextFileWithRetry(
            relativePath: "agent_core/src/bridge.rs",
            testsFilePath: #filePath
        )
        let loop = try loadRepoTextFileWithRetry(
            relativePath: "agent_core/src/agent_loop.rs",
            testsFilePath: #filePath
        )

        #expect(swift.contains("func executeComputerAction(actionJson: String) -> String"))
        #expect(swift.contains("await ComputerUseBridge.shared.execute(actionJSON: actionJson)"))
        #expect(bridge.contains("fn execute_computer_action(&self, action_json: String) -> String;"))
        #expect(loop.contains("delegate.execute_computer_action(input_json.clone())"))
    }

    @Test("code editor tears down AI partner sessions and mounts inline suggestions")
    func codeEditorTearsDownAIPartnerSessionsAndMountsInlineSuggestions() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/CodeEditorView.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains(".onDisappear"))
        #expect(source.contains("aiPartner.endSession()"))
        #expect(source.contains("InlineSuggestionOverlay("))
    }

    @Test("code editor binds note chat prompts to the live code buffer")
    func codeEditorBindsNoteChatPromptsToTheLiveCodeBuffer() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Notes/CodeEditorView.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("bindNoteChatContext(with: text)"))
        #expect(source.contains("noteChatState?.noteBodyProvider = { capturedText }"))
        #expect(source.contains("noteChatState?.graphStateProvider = { capturedGraphState }"))
        #expect(source.contains("clearNoteChatContextBindings()"))
    }

    @Test("model vault settings reflect configured cloud providers and installed local models")
    func modelVaultSettingsReflectConfiguredCloudProvidersAndInstalledLocalModels() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/ModelVaultsSettingsView.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("@Environment(InferenceState.self)"))
        #expect(source.contains("inference.configuredCloudProviders"))
        #expect(source.contains("inference.releaseSelectableInstalledLocalTextModelIDs"))
        #expect(source.contains("private func configuredTargets() -> [ModelVaultTarget]"))
    }

    @Test("mlx ssm reuse stays scoped to the active chat session")
    func mlxSSMReuseStaysScopedToTheActiveChatSession() throws {
        let source = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Engine/MLXInferenceService.swift",
            testsFilePath: #filePath
        )

        #expect(source.contains("private var persistentSSMSessionID: String?"))
        #expect(source.contains("persistentSSMModelID == request.modelID"))
        #expect(source.contains("persistentSSMSessionID == activeSessionID"))
        #expect(source.contains("persistentSSMSessionID = activeSessionID"))
    }

    @Test("cognitive settings expose SSM persistence controls and bootstrap uses shared config")
    func cognitiveSettingsExposeSSMPersistenceControlsAndBootstrapUsesSharedConfig() throws {
        let settings = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/Views/Settings/CognitiveSettingsSection.swift",
            testsFilePath: #filePath
        )
        let bootstrap = try loadRepoTextFileWithRetry(
            relativePath: "Epistemos/App/AppBootstrap.swift",
            testsFilePath: #filePath
        )

        #expect(settings.contains("Section(\"SSM State Persistence\")"))
        #expect(settings.contains("Toggle(\"Enable SSM State Persistence\""))
        #expect(settings.contains("Toggle(\"Save After Each Turn\""))
        #expect(settings.contains("Stepper(value: $config.ssmMaxSnapshotsPerModel"))
        #expect(bootstrap.contains("ssmStateService.activate(enabled: epistemosConfig.ssmStatePersistenceEnabled)"))
        #expect(!bootstrap.contains("EpistemosConfig().ssmStatePersistenceEnabled"))
    }
}
