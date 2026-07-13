import Foundation
import Testing

@Suite("App Store June substrate hardening")
struct AppStoreJuneSubstrateHardeningTests {
    @Test("App Store June model catalog keeps local chat and cloud thinking honest")
    func appStoreJuneModelCatalogKeepsLocalChatAndCloudThinkingHonest() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let source = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentModelCatalog.swift")
        let ggufCatalog = try loadMirroredSourceTextFile("Epistemos/QuickChat/GGUFModelCatalog.swift")
        let ggufBackend = try loadMirroredSourceTextFile("Epistemos/QuickChat/LocalGGUFQuickChatBackend.swift")
        let ggufDownloads = try loadMirroredSourceTextFile("Epistemos/QuickChat/QuickChatModelDownloadManager.swift")
        let inference = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        let modelsPayload = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: source,
            startingAt: "static func modelsPayload(",
            endingBefore: "static func cloudCapabilities("
        ))

        #expect(
            modelsPayload.contains(#""capabilities": [String](),"#),
            "MAS local Apple/GGUF rows must stay chat-tier and must not advertise tool/function-calling capabilities."
        )
        #expect(ggufCatalog.components(separatedBy: "GGUFCatalogEntry(").count - 1 == 3)
        #expect(ggufCatalog.contains(#"id: "qwen3-4b-instruct-q4km""#))
        #expect(ggufCatalog.contains(#"id: "qwen3-8b-q4km""#))
        #expect(ggufCatalog.contains(#"id: "qwen2.5-7b-instruct-q4km""#))
        #expect(!ggufCatalog.contains("phi-3.5-mini-instruct-q4km"))
        #expect(!ggufCatalog.contains("tinyllama-1.1b-chat-q4km"))
        #expect(ggufCatalog.contains("let revision: String"))
        #expect(ggufCatalog.contains("let sha256: String"))
        #expect(ggufCatalog.contains(#"revision: "bc640142c66e1fdd12af0bd68f40445458f3869b""#))
        #expect(ggufCatalog.contains(#"sha256: "7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5""#))
        #expect(ggufCatalog.contains(#"revision: "7c41481f57cb95916b40956ab2f0b139b296d974""#))
        #expect(ggufCatalog.contains(#"sha256: "d98cdcbd03e17ce47681435b5150e34c1417f50b5c0019dd560e4882c5745785""#))
        #expect(ggufCatalog.contains(#"revision: "8911e8a47f92bac19d6f5c64a2e2095bd2f7d031""#))
        #expect(ggufCatalog.contains(#"sha256: "65b8fcd92af6b4fefa935c625d1ac27ea29dcb6ee14589c55a8f115ceaaa1423""#))
        #expect(ggufCatalog.contains("resolve/\\(revision)/\\(fileName)"))
        #expect(!ggufCatalog.contains("resolve/main"))
        #expect(ggufDownloads.contains("let expected = entry.sha256"))
        #expect(!ggufDownloads.contains("fetchPublishedSHA256"))
        #expect(ggufDownloads.contains("private nonisolated struct VerificationReceipt: Codable"))
        #expect(ggufDownloads.contains("verifyExistingModel(entry, at: candidate)"))
        #expect(ggufDownloads.contains("case .installed, .downloading, .verifying:"))
        #expect(ggufDownloads.contains("guard byteCount == entry.approxDownloadBytes else"))
        #expect(ggufDownloads.contains("totalBytesWritten > entry.approxDownloadBytes"))
        let progressDelegate = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: ggufDownloads,
            startingAt: "didWriteData bytesWritten: Int64,",
            endingBefore: "nonisolated func urlSession(\n        _ session: URLSession,\n        task: URLSessionTask,"
        ))
        let progressEntry = try #require(progressDelegate.range(of: "guard let entryID = downloadTask.taskDescription else"))
        let absoluteCap = try #require(progressDelegate.range(of: "totalBytesWritten > entry.approxDownloadBytes"))
        let progressLengthGate = try #require(progressDelegate.range(of: "guard totalBytesExpectedToWrite > 0 else"))
        #expect(progressEntry.lowerBound < absoluteCap.lowerBound)
        #expect(absoluteCap.lowerBound < progressLengthGate.lowerBound)
        #expect(ggufDownloads.contains("if case .failed = states[entryID]"))
        #expect(ggufDownloads.contains("resumeData[entryID] = nil"))
        #expect(ggufCatalog.contains("static func unverifiedModelURL(for entry: GGUFCatalogEntry)"))
        #expect(ggufCatalog.contains("QuickChatModelDownloadManager.hasValidVerificationReceipt("))
        #expect(ggufBackend.contains("private let engine = LlamaLocalChatEngine()"))
        #expect(ggufBackend.contains("var isAvailableInThisBuild: Bool { true }"))
        #expect(!ggufBackend.contains("Retired local GGUF backend"))
        #expect(
            modelsPayload.contains(#""compact-context""#),
            "MAS local rows must carry the compact-context trait so Prompt Forge/UI can optimize for lower context windows."
        )
        #expect(
            gateway.contains("let ramProblem = GGUFModelCatalog.ramGate(for: entry)")
                && source.contains("No download will start")
                && gateway.contains("guard GGUFModelCatalog.ramGate(for: entry) == nil else { return }")
                && gateway.contains(#"can't run on this Mac. \(ramProblem.userCopy)"#),
            "June must make oversized GGUF rows honest before download/selection, not only after llama.cpp tries to load them."
        )
        #expect(
            source.contains("static func cloudCapabilities(")
                && source.contains("model.supportedOperatingModes.contains(.thinking)")
                && source.contains(#""supportsReasoningDeltas""#)
                && source.contains("model.supportsNativeReasoningEffortControl")
                && source.contains("private static func genericCloudCapabilities(")
                && source.contains(#""capabilities": genericCloudCapabilities(preferredConfiguredCloudModel)"#)
                && gateway.contains("preferredCachedConfiguredCloudModel()?.rawValue")
                && source.contains(#"return ["supportsFunctionCalling"]"#),
            "June cloud model rows must expose thinking/reasoning from the Swift model truth source, not from descriptive copy."
        )
        #expect(
            gateway.contains("preferredCachedConfiguredCloudModelID() ?? preferredLocalDefaultModelID() ?? JuneModelID.cloud")
                && gateway.contains("AppleFMQuickChatBackend.unavailability() == nil ? JuneModelID.appleFM : nil")
                && gateway.contains("clean App Store installs either produce an answer or surface one clear")
                && !gateway.contains("Best runnable local lane first"),
            "June's MAS default must use configured cloud first, then a runnable Apple Intelligence lane, with a clear cloud/configuration fallback."
        )
        #expect(
            gateway.contains("hasCachedCloudAccess(for: provider)")
                && gateway.contains("cachedConfiguredCloudProviders()")
                && source.contains("cachedConfiguredCloudProviders: Set<CloudModelProvider>")
                && source.contains("inference?.hasCachedCloudAccess(for: provider)")
                && inference.contains("func hasCachedCloudAccess(for provider: CloudModelProvider) -> Bool")
                && inference.contains("must never fall through to")
                && inference.contains("SecItemCopyMatching"),
            "June startup/model-catalog invokes must not synchronously read Keychain on the main actor while the webview is booting."
        )
        #expect(
            modelsPayload.contains(#""name": "Cloud Agent""#)
                && modelsPayload.contains("saved OpenAI or Anthropic API key")
                && modelsPayload.contains("go directly to the chosen provider")
                && modelsPayload.contains("enable its consent toggle in Settings")
                && !modelsPayload.contains("receipt-gated Epistemos Cloud proxy")
                && !modelsPayload.contains("Requires an active subscription"),
            "The generic June cloud row must describe only the active BYOK and consent-gated MAS route."
        )
        #expect(source.contains("Uses your saved OpenAI API key."))
        #expect(source.contains("Uses your saved Anthropic API key."))
        #expect(!source.contains("Uses your saved \\(provider.manualCredentialTitleLowercase) or account connection."))
        #expect(
            inference.contains("case .zaiGLM52, .zaiGLM5, .zaiGLM5Turbo, .zaiGLM47, .zaiGLM47Flash,")
                && inference.contains(".zaiGLM45Flash:")
                && inference.contains("case .openAI, .anthropic, .google, .zai:")
                && inference.contains(#"return tier == .heavy ? "Max" : tier.displayName"#),
            "GLM rows with Rust Z.AI thinking/effort extensions must expose native effort controls; Kimi keeps native thinking request support in Rust without fabricating low/medium/high UI effort tiers."
        )
    }

    @Test("June cloud consent is off by default, provider-specific, persistent, and revocable")
    @MainActor
    func juneCloudConsentIsProviderSpecificPersistentAndRevocable() throws {
        let suiteName = "EpistemosTests.JuneCloudConsent.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AgentCloudConsentStore(defaults: defaults)
        #expect(!store.hasConsent(for: .openAI))
        #expect(!store.hasConsent(for: .anthropic))

        store.setConsent(true, for: .openAI)
        #expect(store.hasConsent(for: .openAI))
        #expect(!store.hasConsent(for: .anthropic))
        #expect(AgentCloudConsentStore(defaults: defaults).hasConsent(for: .openAI))

        store.setConsent(false, for: .openAI)
        #expect(!store.hasConsent(for: .openAI))
        #expect(!AgentCloudConsentStore(defaults: defaults).hasConsent(for: .openAI))
    }

    @Test("App Store cloud setup uses Keychain API keys only")
    func appStoreCloudSetupUsesKeychainAPIKeysOnly() throws {
        let auth = try loadMirroredSourceTextFile("Epistemos/Engine/CloudProviderAuthService.swift")
        let llm = try loadMirroredSourceTextFile("Epistemos/Engine/LLMService.swift")
        let inference = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        let bootstrap = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let cloudSetup = try loadMirroredSourceTextFile("Epistemos/Views/Shared/CloudProviderSetupCard.swift")
        let gatewayTypes = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneGatewayTypes.swift")
        let catalog = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentModelCatalog.swift")
        let juneBridge = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentBridge.swift")
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let consent = try loadMirroredSourceTextFile("Epistemos/AgentWorkspace/AgentCloudConsent.swift")
        let juneBuildScript = try loadMirroredSourceTextFile("build-june-web.sh")
        let releaseGate = try loadMirroredSourceTextFile("scripts/keelstone-release-gate.sh")
        let ci = try loadMirroredSourceTextFile(".github/workflows/ci.yml")
        let bundleScan = try loadMirroredSourceTextFile("scripts/scan_appstore_bundle.sh")
        let claudeProvider = try loadMirroredSourceTextFile("agent_core/src/providers/claude.rs")
        let agentCoreBridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")
        let privacy = try loadMirroredSourceTextFile("Epistemos/Views/Settings/PrivacyDetailView.swift")
        let deployment = try loadMirroredSourceTextFile("Epistemos/Views/Settings/DeploymentProfileHealthRow.swift")
        let commandCenter = try loadMirroredSourceTextFile("Epistemos/State/AgentCommandCenterState.swift")
        let voiceDetail = try loadMirroredSourceTextFile("Epistemos/Views/Settings/VoiceSettingsDetailView.swift")
        let voicePicker = try loadMirroredSourceTextFile("Epistemos/Views/Shared/ModelVoicePickerSection.swift")
        let reviewNotes = try loadMirroredSourceTextFile("docs/MAS_APP_REVIEW_NOTES_2026_07_03.md")

        let resolvedCredentialType = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: auth,
            startingAt: "nonisolated enum CloudProviderResolvedCredential",
            endingBefore: "nonisolated enum AnthropicClaudeCodeImportResult"
        ))

        let resolvedCredential = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: auth,
            startingAt: "func resolvedCredential(",
            endingBefore: "    func importOpenAICodexCLIIfPresent()"
        ))
        let anthropicImport = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: auth,
            startingAt: "func importAnthropicClaudeCodeCredentials()",
            endingBefore: "    #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"
        ))
        let accountSupport = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: inference,
            startingAt: "var supportsAccountConnection: Bool",
            endingBefore: "    var manualCredentialTitle: String"
        ))
        let credentialSnapshot = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: inference,
            startingAt: "private nonisolated static func loadCloudCredentialSnapshot(",
            endingBefore: "    private struct CloudCredentialSnapshot"
        ))
        let oauthLookup = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: inference,
            startingAt: "func oauthCredential(for provider: CloudModelProvider)",
            endingBefore: "    func resolvedCloudCredential("
        ))
        let validation = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: inference,
            startingAt: "func validateCloudAccess(for provider: CloudModelProvider) async -> ConnectionTestResult",
            endingBefore: "    private func withCloudValidationTimeout("
        ))
        let environmentOverrides = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: bootstrap,
            startingAt: "nonisolated static func agentCoreEnvironmentOverrides(",
            endingBefore: "    nonisolated static func agentCoreKeychainKey("
        ))
        let environmentMappings = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: bootstrap,
            startingAt: "private nonisolated static let agentCoreEnvironmentKeyMappings",
            endingBefore: "    private nonisolated static let agentCoreEnvironmentScopeGate"
        ))
        let settingsAccountAction = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: settings,
            startingAt: "private func runAccountAction()",
            endingBefore: "    private func runProviderAction("
        ))
        let anthropicAuthorization = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: llm,
            startingAt: "private func applyAnthropicAuthorization(",
            endingBefore: "    /// Collects every enabled Anthropic server-side tool"
        ))
        let googleModelsRequest = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: llm,
            startingAt: "private func googleModelsRequest(",
            endingBefore: "    private func googleContentRequest("
        ))
        let juneProviders = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: inference,
            startingAt: "nonisolated static let juneAgentProviders",
            endingBefore: "    /// Whether a plain CHAT turn"
        ))
        let settingsProviders = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: settings,
            startingAt: "private var settingsProviders: [CloudModelProvider]",
            endingBefore: "    private var providerSetupDescription"
        ))
        let juneModels = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: inference,
            startingAt: "nonisolated static func juneAgentModels(for provider: CloudModelProvider)",
            endingBefore: "    nonisolated static func from(rawValueOrVendorID value: String)"
        ))
        let supportedModels = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: inference,
            startingAt: "private func supportedCloudModels(for provider: CloudModelProvider)",
            endingBefore: "    private var openAIUsesCodexAccountRuntime"
        ))
        let modelAdmission = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "private func agentCoreProviderName(modelID: String, cloudModel: CloudTextModelID?) throws -> String",
            endingBefore: "    private static func agentCoreSlug("
        ))
        let juneSettingsModelCommands = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: juneBridge,
            startingAt: "case \"list_venice_models\":",
            endingBefore: "        case \"check_recording_source_readiness\":"
        ))
        let juneModelSelectionHandler = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: juneBridge,
            startingAt: "private func handleSetVeniceModelInvoke(callId: Int, args: [String: Any])",
            endingBefore: "    private func resolveInvoke(callId: Int, result: Any?)"
        ))
        let claudeAuth = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: claudeProvider,
            startingAt: "enum ClaudeAuth",
            endingBefore: "pub struct ClaudeProvider"
        ))
        let claudeFromEnvironment = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: claudeProvider,
            startingAt: "fn from_env(model: &'static str) -> Self",
            endingBefore: "    pub fn opus()"
        ))
        let claudeAuthenticatedRequest = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: claudeProvider,
            startingAt: "fn authenticated_request(client: &Client, auth: &ClaudeAuth)",
            endingBefore: "fn message_to_api_json("
        ))
        let cloudStream = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "private func makeAgentCoreCloudStream(",
            endingBefore: "    /// Engine routing"
        ))
        let cloudProviderAdmission = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "private func agentCoreProviderName(modelID: String, cloudModel: CloudTextModelID?) throws -> String",
            endingBefore: "    private static func agentCoreSlug("
        ))
        let turnModelResolution = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "private func startTurn(sessionID: String, prompt: String)",
            endingBefore: "        // Give the engine the conversation"
        ))
        let defaultModelRepair = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "private func repairedDefaultModelID(_ id: String) -> String?",
            endingBefore: "    private func explicitlyAdmittedModelID"
        ))
        let streamRouting = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "private func makeStream(",
            endingBefore: "    private static func textEventStream("
        ))

        #expect(accountSupport.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX\n        false"))
        #expect(inference.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX\n        return nil\n        #else\n        guard supportsAccountConnection else { return nil }"))
        #expect(credentialSnapshot.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX\n            missingOAuthProviders.insert(provider)"))
        #expect(oauthLookup.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX\n        nil"))
        #expect(inference.contains("guard CloudModelProvider.activeProductProviders.contains(provider), credential == nil else { return false }"))
        #expect(consent.contains("static let shared = AgentCloudConsentStore()"))
        #expect(consent.contains("case .openAI") && consent.contains("api.openai.com (OpenAI)"))
        #expect(consent.contains("case .anthropic") && consent.contains("api.anthropic.com (Anthropic)"))
        #expect(consent.contains("func hasConsent(for provider: CloudModelProvider) -> Bool"))
        #expect(consent.contains("func setConsent(_ isGranted: Bool, for provider: CloudModelProvider)"))
        #expect(validation.contains("AgentCloudConsentStore.shared.hasConsent(for: provider)"))
        #expect(validation.contains("Nothing was sent."))
        #expect(llm.contains("guard AgentCloudConsentStore.shared.hasConsent(for: provider) else"))
        #expect(llm.contains("throw CloudLLMError.cloudConsentRequired(provider.displayName)"))
        #expect(llm.contains("case cloudConsentRequired(String)"))
        #expect(cloudSetup.contains(") async -> ConnectionTestResult"))
        #expect(cloudSetup.contains("return await inference.validateAPIKey(for: provider)"))
        #expect(!cloudSetup.contains("_ = await inference.validateAPIKey(for: provider)"))
        #expect(settings.contains("let result = await CloudProviderSetupAutomation.pasteAndSave("))
        #expect(!settings.contains("let didSave = await CloudProviderSetupAutomation.pasteAndSave("))
        #expect(settings.contains("private var cloudDataConsentControl: some View"))
        #expect(settings.contains("Allow June to send prompts and selected context to"))
        #expect(settings.contains("AgentCloudConsentStore.shared.setConsent"))
        #expect(cloudProviderAdmission.contains("try requireCloudDataConsent(for:"))
        #expect(cloudStream.contains("let providerName = try agentCoreProviderName"))
        #expect(cloudStream.contains("agentCoreRunner.streamGooseMASAgentCoreRun"))
        #expect(gatewayTypes.contains("Cloud data consent is off for"))
        #expect(gatewayTypes.contains("Settings > June Models"))
        #expect(privacy.contains("Provider-specific cloud consent is off by default and revocable"))
        #expect(reviewNotes.contains("Optional GGUF and Kokoro packages are model data, not executable code."))
        #expect(reviewNotes.contains("user-supplied OpenAI and Anthropic API keys are stored in macOS Keychain"))
        #expect(!reviewNotes.contains("does **not** include local model downloads, GGUF/llama"))
        #expect(resolvedCredential.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"))
        #expect(resolvedCredential.contains("return .apiKey(trimmedAPIKey)"))
        #expect(resolvedCredentialType.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"))
        #expect(resolvedCredentialType.contains("case googleOAuth(accessToken: String, projectID: String)"))
        #expect(resolvedCredentialType.contains("case anthropicOAuth(accessToken: String)"))
        #expect(anthropicImport.contains("Anthropic account-session import is unavailable in the App Store build. Use an Anthropic API key."))
        #expect(anthropicImport.contains("#else\n        let credentialsURL"))
        #expect(anthropicImport.contains(#".appendingPathComponent(".claude/.credentials.json")"#))
        #expect(auth.contains("No \\(provider.displayName) API key is saved yet."))
        #expect(environmentOverrides.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"))
        #expect(environmentOverrides.contains("overrides[\"ANTHROPIC_AUTH_MODE\"] = \"oauth\""))
        #expect(environmentOverrides.contains("overrides[\"GOOGLE_AUTH_MODE\"] = \"oauth\""))
        #expect(environmentMappings.contains("ANTHROPIC_API_KEY"))
        #expect(environmentMappings.contains("OPENAI_API_KEY"))
        #expect(environmentMappings.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\n        mappings.append(contentsOf:"))
        #expect(environmentMappings.contains("GOOGLE_API_KEY"))
        #expect(environmentMappings.contains("KIMI_API_KEY"))
        #expect(settings.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\n            if provider == .google"))
        #expect(settingsAccountAction.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX"))
        #expect(settingsAccountAction.contains("provider.credentialManagementURL"))
        #expect(juneProviders.contains("allCases.filter(\\.supportsAgentTier)"))
        #expect(!juneProviders.contains(".google"))
        #expect(catalog.contains("directCloudProviders = CloudModelProvider.juneAgentProviders"))
        #expect(catalog.contains("CloudTextModelID.juneAgentModels(for: provider)"))
        #expect(juneBridge.contains("CloudModelProvider.juneAgentProviders.contains { provider in"))
        #expect(juneBridge.contains("hasCachedCloudAccess(for: provider) == true"))
        #expect(juneBridge.contains("\"providerConfigured\": providerConfigured"))
        #expect(!juneBridge.contains("\"providerConfigured\": true"))
        #expect(settings.contains("ForEach(settingsProviders, id: \\.self)"))
        #expect(settingsProviders.contains("CloudModelProvider.juneAgentProviders"))
        #expect(settings.contains("inference.cloudModels(for: provider)"))
        #expect(settings.contains("Only providers connected to June appear here."))
        #expect(inference.contains("Use an OpenAI API key with MAS June. The key is stored in Apple Keychain."))
        #expect(inference.contains("Use an Anthropic API key with MAS June. The key is stored in Apple Keychain."))
        #expect(inference.contains("Google is not connected to MAS June."))
        #expect(!inference.contains("Local account/session import is parked outside the MAS product."))
        #expect(!inference.contains("Claude Code account-session import is parked outside the MAS product."))
        #expect(settings.contains("case .cloudModels: \"June Models\""))
        #expect(settings.contains("Text(section.displayTitle)"))
        #expect(settings.contains("Section(providerSetupTitle)"))
        #expect(settings.contains("\"June Provider Setup\""))
        #expect(juneModels.contains(".openAIGPT55"))
        #expect(juneModels.contains(".openAIO3Mini"))
        #expect(!juneModels.contains(".openAIO3,"))
        #expect(juneModels.contains(".anthropicClaudeSonnet46"))
        #expect(juneModels.contains(".anthropicClaudeOpus47"))
        #expect(juneModels.contains(".anthropicClaudeHaiku45"))
        #expect(juneModels.contains("case .google, .zai, .kimi, .minimax, .deepseek:\n            return []"))
        #expect(supportedModels.contains("CloudTextModelID.juneAgentModels(for: provider)"))
        #expect(modelAdmission.contains("CloudTextModelID.juneAgentModels(for: cloudModel.provider).contains(cloudModel)"))
        #expect(modelAdmission.contains("is not connected to MAS June"))
        #expect(juneSettingsModelCommands.contains("switch mode"))
        #expect(juneSettingsModelCommands.contains("case \"generation\":"))
        #expect(juneSettingsModelCommands.contains("\"models\": gateway.modelsPayload()"))
        #expect(juneSettingsModelCommands.contains("case \"transcription\":"))
        #expect(juneSettingsModelCommands.contains("\"name\": \"On-device dictation\""))
        #expect(juneBridge.contains("\"localDev\": true"))
        #expect(juneSettingsModelCommands.contains("default:"))
        #expect(juneSettingsModelCommands.contains("\"models\": [[String: Any]]()"))
        #expect(juneBridge.contains("if cmd == \"set_venice_model\""))
        #expect(juneModelSelectionHandler.contains("case \"generation\":"))
        #expect(juneModelSelectionHandler.contains("guard gateway.setDefaultModel(modelID) else"))
        #expect(juneModelSelectionHandler.contains("gateway.modelSelectionFailureMessage(modelID)"))
        #expect(gateway.contains("is connected to June, but it can't run on this Mac"))
        #expect(gateway.contains("Configure \\(cloudModel.provider.displayName) in Settings before selecting"))
        #expect(gateway.contains("!setSessionModel(requestedModel, for: sessionID)"))
        #expect(!gateway.contains("_ = setSessionModel(requestedModelID, for: sessionID)"))
        #expect(turnModelResolution.contains("store.model(for: sessionID)"))
        #expect(turnModelResolution.contains("let modelID = persisted ?? currentDefaultModelID()"))
        #expect(!turnModelResolution.contains("selectableModelIDs().contains"))
        #expect(!gateway.contains("private func repairedTurnModelID"))
        #expect(defaultModelRepair.contains("CloudTextModelID.juneAgentModels(for: cloudModel.provider).contains(cloudModel)"))
        #expect(defaultModelRepair.contains("return cloudModel.rawValue"))
        #expect(!defaultModelRepair.contains("preferredCloudModel(for: cloudModel.provider)"))
        #expect(streamRouting.contains("The selected model (\\(boundedID)) is not connected to MAS June."))
        #expect(!streamRouting.contains("Legacy/unknown local id"))
        #expect(juneModelSelectionHandler.contains("case \"transcription\":"))
        #expect(juneModelSelectionHandler.contains("guard modelID == \"local\" else"))
        #expect(juneModelSelectionHandler.contains("This model category is unavailable in MAS June."))
        #expect(juneBridge.contains("\"imageModel\": \"\""))
        #expect(juneBuildScript.contains("const imageGenerationAvailable = providerSettings.imageModel.trim().length > 0;"))
        #expect(juneBuildScript.contains("MAS_HOST_HIDDEN_SETTINGS_TABS"))
        #expect(juneBuildScript.contains("account.localDev ? \"June models\" : \"AI models\""))
        #expect(juneBuildScript.contains("label: \"June models\""))
        #expect(juneBuildScript.contains("using checked-in staged JuneWeb"))
        #expect(juneBuildScript.contains("bun install --frozen-lockfile --silent"))
        #expect(!juneBuildScript.contains("printf '*\\n' > \"$STAGE/.gitignore\""))
        #expect(releaseGate.contains("require_tree_contains()"))
        #expect(releaseGate.contains("Source checkout includes staged JuneWeb index"))
        #expect(releaseGate.contains("Source checkout includes staged JuneWeb shim"))
        #expect(ci.contains("Validate source-tree JuneWeb"))
        #expect(ci.contains("EPISTEMOS_JUNE_FORK: ${{ runner.temp }}/missing-june-donor"))
        #expect(releaseGate.contains("Staged JuneWeb visibly identifies the MAS model catalog as June models"))
        #expect(releaseGate.contains("Built App Store JuneWeb visibly identifies the MAS model catalog as June models"))
        #expect(releaseGate.contains("require_appstore_local_gguf_runtime"))
        #expect(releaseGate.contains("Contents/Frameworks/llama.framework/Versions/A/llama"))
        #expect(releaseGate.contains("otool -L"))
        #expect(releaseGate.contains("Built App Store artifact embeds June's in-process llama runtime"))
        #expect(releaseGate.contains("Built App Store executable links June's in-process llama runtime"))
        #expect(inference.contains("CloudModelProvider.juneAgentProviders.contains(provider) ? provider : .openAI"))
        #expect(inference.contains("nonisolated static let activeProductProviders = juneAgentProviders"))
        #expect(inference.contains("CloudModelProvider.juneAgentProviders.map { AIProviderSelection(cloudProvider: $0) }"))
        #expect(inference.contains("for provider in CloudModelProvider.activeProductProviders"))
        #expect(inference.contains("guard CloudModelProvider.activeProductProviders.contains(provider) else { return nil }"))
        #expect(inference.contains("guard CloudModelProvider.activeProductProviders.contains(provider) else { return false }"))
        #expect(inference.contains("return connectedModels.contains(model) ? model : model.provider.defaultChatModel"))
        #expect(inference.contains(".anthropicClaudeSonnet46\n            #else\n            .anthropicClaudeSonnet5"))
        #expect(anthropicAuthorization.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\n        case .anthropicOAuth"))
        #expect(googleModelsRequest.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\n        case .googleOAuth"))
        #expect(inference.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\n    /// Whether a plain CHAT turn"))
        #expect(llm.contains("private func requireActiveProductModel(_ model: CloudTextModelID) throws"))
        #expect(llm.contains("CloudTextModelID.juneAgentModels(for: model.provider).contains(model)"))
        #expect(llm.contains("throw CloudLLMError.modelNotConnectedToJune(model.displayName)"))
        #expect(llm.contains("is not connected to MAS June. Pick a model shown in June or MAS Settings."))
        #expect(llm.contains("access is missing. Add an API key in MAS Settings."))
        #expect(bundleScan.contains(#"\.claude/\.credentials\.json"#))
        #expect(bundleScan.contains("claude-cli/[0-9]"))
        #expect(bundleScan.contains(#"platform\.claude\.com/v1/oauth/token"#))
        #expect(claudeProvider.contains("#[cfg(not(feature = \"mas-build\"))]\nconst ANTHROPIC_OAUTH_BETA_HEADER"))
        #expect(claudeAuth.contains("#[cfg(not(feature = \"mas-build\"))]\n    OAuthAccessToken(String)"))
        #expect(claudeFromEnvironment.contains("#[cfg(feature = \"mas-build\")]\n        let auth = ClaudeAuth::ApiKey(api_key);"))
        #expect(claudeFromEnvironment.contains("#[cfg(not(feature = \"mas-build\"))]\n        let auth = resolve_claude_auth("))
        #expect(claudeAuthenticatedRequest.contains("#[cfg(not(feature = \"mas-build\"))]\n        ClaudeAuth::OAuthAccessToken"))
        #expect(claudeProvider.contains("#[cfg(not(feature = \"mas-build\"))]\nfn resolve_claude_auth("))
        #expect(agentCoreBridge.contains("#[cfg(feature = \"mas-build\")]\nfn instantiate_provider("))
        #expect(agentCoreBridge.contains("Unsupported MAS June provider/model:"))
        #expect(agentCoreBridge.contains("MAS June requires an explicit model from its OpenAI or Anthropic catalog."))
        #expect(agentCoreBridge.contains("is not connected to MAS June."))
        #expect(agentCoreBridge.contains("mas_provider_admission_matches_the_exact_june_catalog"))
        #expect(privacy.contains("June cloud-model API requests, only when you select an OpenAI or Anthropic model connected to June."))
        #expect(deployment.contains("private static let activeMASBoundaries"))
        #expect(deployment.contains("June in-process agent (OpenAI / Anthropic API keys)"))
        #expect(deployment.contains("Apple Intelligence / selected local GGUF chat lanes inside June"))
        #expect(deployment.contains("Active MAS June boundaries:"))
        #expect(commandCenter.contains("cloudBrain(preferredProviders: CloudModelProvider.activeProductProviders)"))
        #expect(!commandCenter.contains("preferredProviders: [.openAI, .anthropic, .google]"))
        #expect(voiceDetail.contains("KokoroVoiceProSettingsSection()"))
        #expect(voicePicker.contains("EpistemosSpeechSynthesizer.installedEnglishKokoroVoices()"))
        #expect(gatewayTypes.contains("Add an OpenAI or Anthropic API key in Settings"))
        #expect(catalog.contains("saved OpenAI or Anthropic API key"))
        #expect(catalog.contains("Uses your saved Anthropic API key."))
    }

    @Test("App Store June RuntimeRouter is cloud-first, witnessed, and local-chat honest")
    func appStoreJuneRuntimeRouterIsCloudFirstWitnessedAndLocalChatHonest() throws {
        let router = try loadMirroredSourceTextFile("Epistemos/LocalAgent/RuntimeRouter.swift")
        let executor = try loadMirroredSourceTextFile("Epistemos/Engine/RuntimeExecutor.swift")
        let confidence = try loadMirroredSourceTextFile("Epistemos/LocalAgent/ConfidenceRouter.swift")
        let routeProfiles = try loadMirroredSourceTextFile("Epistemos/State/InferenceState+RouteProfiles.swift")
        let lanesSection = try loadMirroredSourceTextFile("Epistemos/Views/Settings/RuntimeLanesSection.swift")
        let policyOrderGuard = try loadMirroredSourceTextFile("agent_core/tests/runtime_router_policy_order_source_guard.rs")
        let masPreferenceTable = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: router,
            startingAt: "#if EPISTEMOS_APP_STORE || MAS_SANDBOX\n    nonisolated public static let modelPreferenceTable",
            endingBefore: "    #else"
        ))
        let masAgentChain = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: masPreferenceTable,
            startingAt: "\"june.cloud-first.agent\": [",
            endingBefore: "        \"june.cloud-first.reasoning\": ["
        ))
        let openAI = try #require(masAgentChain.range(of: #".cloud(provider: "openai")"#))
        let claude = try #require(masAgentChain.range(of: #".cloud(provider: "claude")"#))
        let apple = try #require(masAgentChain.range(of: ".appleIntelligence"))
        let gguf = try #require(masAgentChain.range(of: ".gguf"))
        let stub = try #require(masAgentChain.range(of: ".stub"))
        let masKnownLanes = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: executor,
            startingAt: "#if EPISTEMOS_APP_STORE || MAS_SANDBOX\n    public static let knownLanes: [RuntimeLane]",
            endingBefore: "    #else"
        ))

        #expect(
            router.contains("modelPreferenceTable")
                && router.contains(#""june.cloud-first.agent""#)
                && openAI.lowerBound < apple.lowerBound
                && claude.lowerBound < apple.lowerBound
                && apple.lowerBound < gguf.lowerBound
                && gguf.lowerBound < stub.lowerBound,
            "June's MAS RuntimeRouter must prefer agentic cloud lanes before its admitted Apple Intelligence and GGUF chat fallbacks."
        )
        #expect(
            router.contains("toolCallMode: .none")
                && router.contains("grammarSupport: []")
                && router.contains("case .gguf:")
                && router.contains("if request.requiresTools && capability.toolCallMode == .none")
                && router.contains(".toolCallGrammarUnsupported"),
            "The local Apple/GGUF lanes must remain chat-tier and reject tool/grammar demands unless a real deterministic lane is admitted."
        )
        #expect(
            router.contains(#"let agenticCloud = provider == "openai" || provider == "claude""#)
                && router.contains("toolCallMode: agenticCloud ? .native : .none")
                && router.contains(#"grammarSupport: agenticCloud ? ["provider_native_tools"] : []"#),
            "RuntimeRouter cloud capability must not promote every cloud provider to the full agentic tool lane."
        )
        #expect(
            router.contains("RouteVerdict")
                && router.contains("recordAccept(verdict, role: packet.role)")
                && router.contains("recordReject(role: packet.role, reason: reason)")
                && router.contains("RuntimeRouter witness lanes do not execute model requests."),
            "RuntimeRouter must be a witnessed routing substrate, not a hidden executor or fallback."
        )
        #expect(
            confidence.contains("RuntimeRouter.defaultRouteProfiles().map")
                && routeProfiles.contains("RuntimeRouter.defaultRouteProfiles()")
                && lanesSection.contains("RuntimeLane.knownLanes.filter { $0 != .stub }")
                && lanesSection.contains("router.setLaneEnabled(lane, newValue)"),
            "Diagnostics and lane toggles must read the router's policy table instead of maintaining placeholders."
        )
        #expect(masKnownLanes.contains(#".cloud(provider: "openai")"#))
        #expect(masKnownLanes.contains(#".cloud(provider: "claude")"#))
        #expect(masKnownLanes.contains(".appleIntelligence"))
        #expect(masKnownLanes.contains(".gguf"))
        #expect(!masKnownLanes.contains("gemini"))
        #expect(!masKnownLanes.contains("zai"))
        #expect(!masKnownLanes.contains("kimi"))
        #expect(!masKnownLanes.contains("perplexity"))
        #expect(lanesSection.contains("Apple Intelligence and GGUF are chat-only; OpenAI and Anthropic drive June's agent loop."))
        #expect(
            policyOrderGuard.contains("mas_agent_chain_keeps_agentic_cloud_before_local_chat_fallbacks")
                && policyOrderGuard.contains("GGUF must stay after Apple Intelligence and before the internal stub"),
            "Rust source guards must enforce cloud-first MAS routing with the admitted local chat fallbacks."
        )
    }

    @Test("App Store June agent_core cloud path preserves native thinking deltas")
    func appStoreJuneAgentCoreCloudPathPreservesNativeThinkingDeltas() throws {
        let runner = try loadMirroredSourceTextFile("Epistemos/Goose/GooseMASAgentCoreRunner.swift")
        let providerSlug = try loadMirroredSourceTextFile("Epistemos/Goose/GooseMASAgentCoreProviderSlug.swift")
        let inference = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        let bridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")
        let openAI = try loadMirroredSourceTextFile("agent_core/src/providers/openai.rs")
        let claude = try loadMirroredSourceTextFile("agent_core/src/providers/claude.rs")
        let gemini = try loadMirroredSourceTextFile("agent_core/src/providers/gemini.rs")
        let openAICompatible = try loadMirroredSourceTextFile("agent_core/src/providers/openai_compatible.rs")
        let juneModels = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: inference,
            startingAt: "nonisolated static func juneAgentModels(for provider: CloudModelProvider)",
            endingBefore: "    nonisolated static func from(rawValueOrVendorID value: String)"
        ))

        #expect(
            runner.contains("enableThinking: true")
                && runner.contains(#"effort: "high""#)
                && runner.contains("func onThinkingDelta(thought: String)")
                && runner.contains("emit(.thinkingDelta(thought))"),
            "June's in-process MAS runner must request thinking and forward delegate thinking callbacks."
        )
        #expect(
            bridge.contains("Ok(StreamEvent::ThinkingDelta { text, .. })")
                && bridge.contains("delegate.on_thinking_delta(text)"),
            "agent_core bridge must forward provider thinking stream events to the Swift delegate."
        )
        for required in [
            ".openAIGPT55", ".openAIGPT54", ".openAIGPT54Mini", ".openAIGPT54Nano",
            ".openAIGPT52", ".openAIGPT41", ".openAIGPT41Mini", ".openAIO3Mini",
            ".anthropicClaudeSonnet46", ".anthropicClaudeOpus47", ".anthropicClaudeHaiku45",
        ] {
            #expect(juneModels.contains(required), "MAS June allowlist is missing exact model case: \(required)")
        }
        for required in [
            #"if lower.contains("gpt-5.5") { return "openai_gpt55" }"#,
            #"if lower.contains("gpt-5.4-nano") { return "openai_gpt54_nano" }"#,
            #"if lower.contains("gpt-5.4-mini") { return "openai_gpt54_mini" }"#,
            #"if lower.contains("gpt-5.4") { return "openai_gpt54" }"#,
            #"if lower.contains("gpt-5.2") { return "openai_gpt52" }"#,
            #"if lower.contains("gpt-4.1-mini") { return "openai_gpt41_mini" }"#,
            #"if lower.contains("gpt-4.1") { return "openai_gpt41" }"#,
            #"if lower.hasPrefix("o3-mini") || lower.contains(":o3-mini") { return "openai_o3_mini" }"#,
            #"if lower.contains("opus") { return "claude_opus" }"#,
            #"if lower.contains("sonnet") { return "claude_sonnet" }"#,
            #"if lower.contains("haiku") { return "claude_haiku" }"#,
        ] {
            #expect(providerSlug.contains(required), "MAS June model has no Swift agent_core slug mapping: \(required)")
        }
        for required in [
            #""openai" | "openai_gpt54" => Ok(Arc::new(OpenAIProvider::gpt54()))"#,
            #""openai_gpt55" => Ok(Arc::new(OpenAIProvider::gpt55()))"#,
            #""openai_gpt54_mini" => Ok(Arc::new(OpenAIProvider::gpt54_mini()))"#,
            #""openai_gpt54_nano" => Ok(Arc::new(OpenAIProvider::gpt54_nano()))"#,
            #""openai_gpt52" => Ok(Arc::new(OpenAIProvider::gpt52()))"#,
            #""openai_gpt41" => Ok(Arc::new(OpenAIProvider::gpt41()))"#,
            #""openai_gpt41_mini" => Ok(Arc::new(OpenAIProvider::gpt41_mini()))"#,
            #""openai_o3_mini" => Ok(Arc::new(OpenAIProvider::o3_mini()))"#,
            #""claude_sonnet" => Ok(Arc::new(ClaudeProvider::sonnet()))"#,
            #""claude_opus" => Ok(Arc::new(ClaudeProvider::opus()))"#,
            #""claude_haiku" => Ok(Arc::new(ClaudeProvider::haiku()))"#,
        ] {
            #expect(bridge.contains(required), "MAS June slug has no fixed agent_core constructor: \(required)")
        }
        for required in [
            #"Self::from_env("gpt-5.5", "gpt-5.5")"#,
            #"Self::from_env("gpt-5.4", "gpt-5.4")"#,
            #"Self::from_env("gpt-5.4-mini", "gpt-5.4-mini")"#,
            #"Self::from_env("gpt-5.4-nano", "gpt-5.4-nano")"#,
            #"Self::from_env("gpt-5.2", "gpt-5.2")"#,
            #"Self::from_env("gpt-4.1", "gpt-4.1")"#,
            #"Self::from_env("gpt-4.1-mini", "gpt-4.1-mini")"#,
            #"Self::from_env("o3-mini", "gpt-4o")"#,
        ] {
            #expect(openAI.contains(required), "MAS June OpenAI constructor changed its API-key model: \(required)")
        }
        #expect(claude.contains(#"Self::from_env("claude-sonnet-4-6")"#))
        #expect(claude.contains(#"Self::from_env("claude-opus-4-7")"#))
        #expect(claude.contains(#"Self::from_env("claude-haiku-4-5")"#))
        #expect(
            openAI.contains("response.reasoning_summary_text.delta")
                && openAI.contains("visible_reasoning_delta_ignores_raw_responses_reasoning_text"),
            "OpenAI Responses thinking must surface model-provided summaries while filtering raw private reasoning text."
        )
        #expect(
            openAI.contains("pub fn gpt53_codex()")
                && openAI.contains(#""gpt-5.3-codex""#)
                && openAI.contains("provider_native_thinking_gpt5_request_body_includes_summary_controls")
                && bridge.contains(#""openai_gpt53_codex" => Ok(Arc::new(OpenAIProvider::gpt53_codex()))"#)
                && providerSlug.contains(#"if lower.contains("gpt-5.3-codex") { return "openai_gpt53_codex" }"#),
            "Codex/GPT-5 model picker rows must route to native OpenAI reasoning models, not collapse to a legacy GPT-4o alias."
        )
        #expect(
            claude.contains("DeltaData::ThinkingDelta")
                && claude.contains("StreamEvent::ThinkingDelta"),
            "Anthropic/Claude thinking blocks must remain native StreamEvent::ThinkingDelta events."
        )
        #expect(
            gemini.contains("includeThoughts")
                && gemini.contains("part.thought == Some(true)")
                && gemini.contains("stream_chunk_exposes_thought_parts_as_thinking_delta"),
            "Gemini thought parts must request and preserve native thinking deltas."
        )
        #expect(
            openAICompatible.contains("openai_compatible_reasoning_delta_text")
                && openAICompatible.contains("reasoning_content")
                && openAICompatible.contains("kimi_stream_chunk_exposes_reasoning_content_as_thinking_delta")
                && openAICompatible.contains("provider_native_thinking_kimi_k27_code_uses_native_thinking_parameter")
                && openAICompatible.contains("provider_native_thinking_zai_request_extension_maps_thinking_and_effort")
                && openAICompatible.contains("RequestExtension::ZaiThinking"),
            "Kimi/ZAI/OpenAI-compatible reasoning fields must be routed into thinking deltas when providers emit them."
        )
        #expect(
            providerSlug.contains(#"return lower.contains("reasoner") ? "deepseek_reasoner" : "deepseek""#)
                && bridge.contains(#""deepseek_reasoner""#)
                && bridge.contains("provider_native_thinking_explicit_deepseek_reasoner_override_is_supported")
                && openAICompatible.contains("pub fn deepseek_reasoner()")
                && openAICompatible.contains(#""deepseek-reasoner""#)
                && openAICompatible.contains("provider_native_thinking_deepseek_chat_and_reasoner_are_distinct"),
            "DeepSeek Reasoner rows must route to the reasoning constructor instead of collapsing to the generic non-thinking DeepSeek chat model."
        )
    }

    @Test("App Store June agent callbacks expose only MAS June product truth")
    func appStoreJuneAgentCallbacksExposeOnlyMASJuneProductTruth() throws {
        let runner = try loadMirroredSourceTextFile("Epistemos/Goose/GooseMASAgentCoreRunner.swift")

        #expect(runner.contains("Epistemos/JuneAgentCore/agent-core-scratch"))
        #expect(runner.contains("Computer-use is unavailable in MAS June."))
        #expect(runner.contains("Background model training is unavailable in MAS June."))
        #expect(runner.contains("MAS June agent run failed"))
        #expect(!runner.contains("Epistemos/GooseMASAgentCore/agent-core-scratch"))
        #expect(!runner.contains("Pro-only"))
        #expect(!runner.contains("App Store Goose backend"))
        #expect(!runner.contains("NightBrain is unavailable"))
    }

    @Test("App Store June Swift provider slug admission is exact")
    func appStoreJuneSwiftProviderSlugAdmissionIsExact() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Goose/GooseMASAgentCoreProviderSlug.swift")
        let masBranch = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: source,
            startingAt: "#if EPISTEMOS_APP_STORE || MAS_SANDBOX",
            endingBefore: "        #else"
        ))

        for required in [
            #"case "openai:gpt-5.5": return "openai_gpt55""#,
            #"case "openai:gpt-5.4": return "openai_gpt54""#,
            #"case "openai:gpt-5.4-mini": return "openai_gpt54_mini""#,
            #"case "openai:gpt-5.4-nano": return "openai_gpt54_nano""#,
            #"case "openai:gpt-5.2": return "openai_gpt52""#,
            #"case "openai:gpt-4.1": return "openai_gpt41""#,
            #"case "openai:gpt-4.1-mini": return "openai_gpt41_mini""#,
            #"case "openai:o3-mini": return "openai_o3_mini""#,
            #"case "anthropic:claude-sonnet-4-6": return "claude_sonnet""#,
            #"case "anthropic:claude-opus-4-7": return "claude_opus""#,
            #"case "anthropic:claude-haiku-4-5": return "claude_haiku""#,
        ] {
            #expect(masBranch.contains(required), "MAS June Swift slug map is missing: \(required)")
        }
        for parked in ["gemini", "kimi", "deepseek", "minimax", "zai", "perplexity", "mistral", "grok", "gpt-4o", "openai:o1", "contains(\"/\")"] {
            #expect(!masBranch.contains(parked), "MAS June Swift slug map still admits parked signal: \(parked)")
        }
    }

    @Test("App Store June redacts vault roots from tool and approval payloads")
    func appStoreJuneRedactsVaultRootsFromToolAndApprovalPayloads() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let vaultScope = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentCoreVaultScope.swift")
        let toolBounds = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneToolEventBounds.swift")
        let vaultPath = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: vaultScope,
            startingAt: "static func vaultPathForAgentCore",
            endingBefore: "static func redactedVaultRootCandidates"
        ))
        let vaultRedaction = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: vaultScope,
            startingAt: "static func redactedVaultRootCandidates",
            endingBefore: "#endif"
        ))
        let eventLoop = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "case .toolStarted(let id, let name, let inputJson):",
            endingBefore: "case .complete(let stopReason"
        ))
        let redaction = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: toolBounds,
            startingAt: "static func boundedToolPayload",
            endingBefore: "#endif"
        ))

        #expect(
            eventLoop.contains("let boundedInput = JuneToolEventBounds.boundedToolPayload(inputJson)")
                && eventLoop.contains(#""input_json": boundedInput"#)
                && eventLoop.contains("let boundedResult = JuneToolEventBounds.boundedToolPayload(result)")
                && eventLoop.contains(#""result": boundedResult"#)
                && eventLoop.contains(#""input_json": JuneToolEventBounds.boundedToolPayload(inputJson)"#)
                && eventLoop.contains("JuneToolEventBounds.approvalDescription("),
            "June must redact and bound tool inputs/results and approval input_json before forwarding agent events to webview JS."
        )
        #expect(
            toolBounds.contains("static let maxToolEventIDBytes = 128")
                && toolBounds.contains("static let maxToolNameBytes = 128")
                && toolBounds.contains("static let maxToolRiskLevelBytes = 64")
                && toolBounds.contains("static func boundedToolMetadata")
                && toolBounds.contains("static func boundedToolProtocolID")
                && toolBounds.contains("static func isBoundedToolProtocolID")
                && gateway.contains("JuneToolEventBounds.isBoundedToolProtocolID(requestID)")
                && eventLoop.contains("guard let toolID = JuneToolEventBounds.boundedToolProtocolID(id) else { break }")
                && eventLoop.contains("let toolName = JuneToolEventBounds.boundedToolMetadata(")
                && eventLoop.contains("maxBytes: JuneToolEventBounds.maxToolNameBytes")
                && eventLoop.contains("guard !toolName.isEmpty else { break }")
                && eventLoop.contains("let explicitToolName = JuneToolEventBounds.boundedToolMetadata(")
                && eventLoop.contains(#"toolCalls.first { $0.id == toolID }?.name ?? "tool""#)
                && eventLoop.contains(#""tool_call_id": toolID"#)
                && eventLoop.contains(#""tool_name": toolName"#)
                && eventLoop.contains("let boundedToolName = JuneToolEventBounds.boundedToolMetadata(")
                && eventLoop.contains("let boundedRiskLevel = JuneToolEventBounds.boundedToolMetadata(")
                && eventLoop.contains("maxBytes: JuneToolEventBounds.maxToolRiskLevelBytes")
                && eventLoop.contains("guard !boundedRiskLevel.isEmpty else")
                && eventLoop.contains(#""tool_name": boundedToolName"#)
                && eventLoop.contains(#""risk_level": boundedRiskLevel"#),
            "Tool ids, names, and approval risk labels must be bounded before live JS events, approval descriptions, and durable replay."
        )
        #expect(
            vaultPath.contains("if let selectedVaultPath = watchedVaultPathForAgentCore()")
                && vaultPath.contains("return agentCoreScratchURL().path")
                && gateway.contains("vaultPath: JuneAgentCoreVaultScope.vaultPathForAgentCore()")
                && vaultScope.contains(".applicationSupportDirectory")
                && vaultScope.contains("Epistemos/JuneAgent/agent-core-scratch")
                && !vaultScope.contains("ProcessInfo.processInfo.environment")
                && !vaultScope.contains("EPISTEMOS_VAULT_PATH")
                && !vaultScope.contains("VAULT_PATH"),
            "June agent_core vault pathing must use only the selected watched vault or an app-support scratch vault, never ambient environment paths."
        )
        #expect(
            redaction.contains("maxToolPayloadBytes")
                && redaction.contains("toolPayloadTruncationMarker")
                && redaction.contains("let roots = JuneAgentCoreVaultScope.redactedVaultRootCandidates()")
                && redaction.contains("let lookaheadBytes = roots.reduce(0)")
                && redaction.contains("let scanLimit = maxToolPayloadBytes + lookaheadBytes")
                && redaction.contains("truncateUTF8(value, maxBytes: scanLimit, appendMarker: false)")
                && redaction.contains("redactKnownVaultRoots(in: scanned, roots: roots)")
                && redaction.contains("truncateUTF8(redacted, maxBytes: maxToolPayloadBytes")
                && redaction.contains("value.utf8.count > maxToolPayloadBytes")
                && vaultRedaction.contains("watchedVaultPathForAgentCore()")
                && vaultRedaction.contains("agentCoreScratchURL(createDirectory: false)")
                && vaultRedaction.contains("rootRedactionForms(for:")
                && vaultRedaction.contains(".standardizedFileURL")
                && vaultRedaction.contains(".resolvingSymlinksInPath()")
                && vaultRedaction.contains(".absoluteString")
                && vaultRedaction.contains("addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)")
                && vaultRedaction.contains("unique.sorted")
                && vaultRedaction.contains("left.count == right.count ? left < right : left.count > right.count")
                && !redaction.contains("ProcessInfo.processInfo.environment")
                && !redaction.contains("EPISTEMOS_VAULT_PATH")
                && !redaction.contains("VAULT_PATH")
                && !vaultRedaction.contains("ProcessInfo.processInfo.environment")
                && !vaultRedaction.contains("EPISTEMOS_VAULT_PATH")
                && !vaultRedaction.contains("VAULT_PATH")
                && redaction.contains(#"replacingOccurrences(of: path, with: "[vault]")"#)
                && redaction.contains("let bodyLimit = max(0, maxBytes - marker.utf8.count)")
                && redaction.contains("candidate.utf8.count > bodyLimit")
                && redaction.contains("let bounded = boundedToolPayload(inputJson)"),
            "Tool/approval payload redaction must cover raw, file-url, percent-encoded, and symlink-resolved selected/scratch roots, with byte-bounded truncation before JS exposure."
        )
    }

    @Test("App Store June persists reasoning and tool replay fields")
    func appStoreJunePersistsReasoningAndToolReplayFields() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let store = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneSessionStore.swift")
        let eventLoop = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "var full = \"\"",
            endingBefore: "} catch {"
        ))
        let boundedAppend = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "private static func appendBounded(",
            endingBefore: "    private static func persistedToolCallsJSON"
        ))
        let messagesPayload = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: store,
            startingAt: "func messagesPayload(sessionID: String)",
            endingBefore: "return [\"messages\": rows]"
        ))

        #expect(
            store.contains("let reasoning: String?")
                && store.contains("let toolCalls: String?")
                && store.contains("let toolCallID: String?")
                && store.contains("let toolName: String?")
                && store.contains("let answerPacketID: String?"),
            "June's durable session store must retain Hermes-compatible reasoning/tool/AnswerPacket fields, not only assistant text."
        )
        #expect(
            messagesPayload.contains(#"row["reasoning"] = reasoning"#)
                && messagesPayload.contains(#"row["reasoning_content"] = reasoning"#)
                && messagesPayload.contains(#"row["tool_calls"] = toolCalls"#)
                && messagesPayload.contains(#"row["tool_call_id"] = toolCallID"#)
                && messagesPayload.contains(#"row["tool_name"] = toolName"#)
                && messagesPayload.contains(#"row["answer_packet_id"] = answerPacketID"#),
            "hermes_bridge_session_messages must replay fields the June UI already knows how to render."
        )
        #expect(
            gateway.contains("private static let maxPersistedReasoningBytes = 64 * 1024")
                && gateway.contains("private static let maxPersistedToolResults = 64")
                && gateway.contains("private func emitTurnAnswerPacket(")
                && gateway.contains("AnswerPacket.turnCompletionStub")
                && gateway.contains("AnswerPacketEmitter.shared.emit(packet)")
                && gateway.contains("answerPacketAttentionMode(forJuneModelID: modelID)")
                && gateway.contains("return .unavailable")
                && eventLoop.contains("var fullByteCount = 0")
                && eventLoop.contains("var reasoningByteCount = 0")
                && eventLoop.contains("byteCount: &fullByteCount")
                && eventLoop.contains("byteCount: &reasoningByteCount")
                && eventLoop.contains(#"payload: ["text": acceptedText, "delta": acceptedText]"#)
                && eventLoop.contains(#"payload: ["text": acceptedReasoning, "delta": acceptedReasoning]"#)
                && !eventLoop.contains("full += delta")
                && !eventLoop.contains("full.utf8.count > Self.maxResponseBytes")
                && boundedAppend.contains("byteCount: inout Int")
                && boundedAppend.contains("for scalar in delta.unicodeScalars")
                && boundedAppend.contains("utf8ByteCount(for: scalar)")
                && boundedAppend.contains("if exhaustedBudget { byteCount = maxBytes }")
                && boundedAppend.contains("text.append(accepted)")
                && !boundedAppend.contains("var candidate = text + delta")
                && !boundedAppend.contains("candidate.removeLast()")
                && eventLoop.contains("Self.persistedToolCallsJSON(toolCalls)")
                && eventLoop.contains(#""answer_packet_id": packetID"#)
                && eventLoop.contains("answerPacketID: answerPacketID")
                && eventLoop.contains(#"role: "tool""#),
            "June must persist bounded thinking/tool/AnswerPacket evidence at turn finalization so relaunch replay matches the live stream."
        )
        #expect(
            gateway.contains(#"case "tool":"#)
                && gateway.contains(#"who = "Tool""#),
            "Tool-result replay messages must not be folded back into later prompts as if the user wrote them."
        )
    }

    @Test("App Store June ReplayBundle export FFI is bounded and subprocess-free")
    func appStoreJuneReplayBundleExportFFIIsBoundedAndSubprocessFree() throws {
        let bridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")
        let juneBridge = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentBridge.swift")
        let exportBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: bridge,
            startingAt: "pub fn export_replay_bundle_epbundle_bytes(",
            endingBefore: "/// Returns a JSON summary of the global routing accumulator."
        ))
        let nativeExportBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: juneBridge,
            startingAt: "private func exportReplayBundlePayload",
            endingBefore: "private static func boundedReplayToken"
        ))

        #expect(
            exportBody.contains("ReplayBundle::build")
                && exportBody.contains(".to_epbundle_bytes()")
                && exportBody.contains("Claim::new")
                && exportBody.contains("Evidence::new")
                && exportBody.contains(#""answer_packet_id""#)
                && exportBody.contains("bounded_replay_bundle_token"),
            "ReplayBundle export must use the native provenance builder with a non-empty bounded AnswerPacket evidence claim."
        )
        #expect(
            exportBody.contains("answer_packet:<id>")
                && exportBody.contains("does not claim answer correctness")
                && !exportBody.contains("Verified"),
            "ReplayBundle export must stay audit-only and must not fabricate a verified/correctness claim."
        )
        #expect(
            !exportBody.contains("Command::new")
                && !exportBody.contains("std::process")
                && !exportBody.contains("epistemos-trace")
                && !exportBody.contains("std::fs::write"),
            "MAS ReplayBundle export must return bytes through FFI, not invoke a verifier subprocess or write files behind the user's back."
        )
        #expect(
            bridge.contains("replay_bundle_export_ffi_mints_verifiable_epbundle_bytes")
                && bridge.contains("ReplayBundle::from_epbundle_bytes")
                && bridge.contains("verify_integrity()")
                && bridge.contains("replay_bundle_export_ffi_rejects_missing_answer_packet_id"),
            "The ReplayBundle FFI must keep focused Rust coverage for parse/verify success and fail-closed missing ids."
        )
        #expect(
            juneBridge.contains(#"case "june_export_replay_bundle":"#)
                && nativeExportBody.contains("gateway.store.loadMessages(sessionID: sessionID)")
                && nativeExportBody.contains("message.answerPacketID == answerPacketID")
                && nativeExportBody.contains("exportReplayBundleEpbundleBytes")
                && nativeExportBody.contains("NSSavePanel()")
                && nativeExportBody.contains("Data(bytes).write(to: url, options: [.atomic])")
                && !nativeExportBody.contains("Process(")
                && !nativeExportBody.contains("Command::new"),
            "June's native export command must verify stored AnswerPacket evidence, return through Rust FFI bytes, and save only through a user-mediated native panel."
        )
    }

    @Test("App Store June deterministic substrate gates are default-on with rollback")
    func appStoreJuneDeterministicSubstrateGatesAreDefaultOnWithRollback() throws {
        let registry = try loadMirroredSourceTextFile("agent_core/src/tools/registry.rs")
        let vault = try loadMirroredSourceTextFile("agent_core/src/storage/vault.rs")
        let eml = try loadMirroredSourceTextFile("agent_core/src/eml_rerank.rs")
        let schemaGate = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: registry,
            startingAt: "fn schema_gate_enabled() -> bool",
            endingBefore: "\n}\n\n#[cfg(not(feature = \"pro-build\"))]"
        ))
        let emlGate = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: vault,
            startingAt: "pub fn eml_rerank_enabled() -> bool",
            endingBefore: "/// The secondary signal"
        ))

        for (name, body) in [("schema", schemaGate), ("eml", emlGate)] {
            #expect(
                body.contains(#""0" | "false" | "no" | "off""#)
                    && body.contains("Err(_) => true")
                    && !body.contains(#"Ok("1" | "true" | "yes" | "on")"#),
                "\(name) gate must be default-on with explicit rollback values, not opt-in."
            )
        }
        #expect(
            registry.contains("schema_gate_validates_input_by_default_and_can_be_disabled")
                && registry.contains("std::env::remove_var(\"EPISTEMOS_SCHEMA_GATE_V1\")")
                && registry.contains("std::env::set_var(\"EPISTEMOS_SCHEMA_GATE_V1\", \"0\")")
                && registry.contains("expected a schema-gate rejection"),
            "Schema gate coverage must prove default rejection plus explicit rollback."
        )
        #expect(
            vault.contains("eml_rerank_is_flag_gated_and_fuses_excerpt_coverage")
                && vault.contains("default-on → excerpt-coverage fusion promotes B")
                && vault.contains("std::env::set_var(\"EPISTEMOS_EML_RERANK_V1\", \"0\")")
                && eml.contains("default is\n//! ON"),
            "EML rerank coverage must prove default-on vault grounding and explicit rollback."
        )
    }

    @Test("App Store June vault search confidence floor bounds raw BM25")
    func appStoreJuneVaultSearchConfidenceFloorBoundsRawBM25() throws {
        let ladder = try loadMirroredSourceTextFile("agent_core/src/tools/vault_search_ladder.rs")
        let registry = try loadMirroredSourceTextFile("agent_core/src/tools/registry.rs")
        let acceptBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: ladder,
            startingAt: "fn accept_above_floor",
            endingBefore: "/// Construct the canonical `vault.search` ladder"
        ))

        #expect(
            acceptBody.contains("let top_confidence")
                && acceptBody.contains("score_floor_confidence(r.score)")
                && acceptBody.contains("top_confidence >= floor"),
            "vault.search must compare bounded confidence against floors, not raw BM25 magnitude."
        )
        #expect(
            ladder.contains("pub(crate) fn score_floor_confidence(score: f64) -> f64")
                && ladder.contains("if score <= 1.0")
                && ladder.contains("(score / (score + 1.0)).clamp(0.0, 1.0)")
                && ladder.contains("t1_declines_representative_raw_bm25_after_confidence_mapping")
                && ladder.contains("ladder_maps_strong_raw_bm25_to_t1_confidence")
                && !ladder.contains("t1_accepts_raw_bm25_post_fix_c_floor_bypass_documenting"),
            "The confidence-floor guard must preserve legacy [0,1] fixtures while bounding raw BM25 and removing the documented bypass."
        )
        #expect(
            registry.contains("No notes matched with high enough confidence"),
            "June's vault search must keep an honest no-confident-answer outcome when all tiers decline."
        )
    }

    @Test("App Store June vault writes route through reversible effects")
    func appStoreJuneVaultWritesRouteThroughReversibleEffects() throws {
        let registry = try loadMirroredSourceTextFile("agent_core/src/tools/registry.rs")
        let effect = try loadMirroredSourceTextFile("agent_core/src/effect/mod.rs")
        let vaultApplier = try loadMirroredSourceTextFile("agent_core/src/effect/vault_applier.rs")
        let writeBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: registry,
            startingAt: "impl ToolHandler for VaultWriteHandler",
            endingBefore: "#[cfg(feature = \"pro-build\")]"
        ))

        #expect(
            writeBody.contains("Intent::VaultWrite")
                && writeBody.contains("VaultIntentApplier::new")
                && writeBody.contains("applier.apply(intent).await")
                && writeBody.contains("effect.compute_inverse")
                && writeBody.contains(#""effect_kind": effect_kind(&effect)"#)
                && writeBody.contains(#""inverse_kind": inverse_kind(&inverse)"#),
            "vault.write must route mutations through the reversible effect applier and expose non-secret effect metadata."
        )
        #expect(
            !writeBody.contains(".write(path, content, Some(&tags), append)"),
            "vault.write must not bypass the effect system with a direct backend write."
        )
        #expect(
            effect.contains("Effect::VaultWrote")
                && effect.contains("Inverse::RestoreVaultContent")
                && vaultApplier.contains("PriorState::WroteOverExisting")
                && vaultApplier.contains("body_sha256")
                && registry.contains("vault_write_effect_metadata_does_not_expose_prior_body"),
            "The effect path must preserve reversibility while tests prove prior note bodies are not returned to the agent/UI."
        )
    }

    @Test("App Store June context compiler bounds vault file ingestion")
    func appStoreJuneContextCompilerBoundsVaultFileIngestion() throws {
        let compiler = try loadMirroredSourceTextFile("agent_core/src/context_compiler.rs")
        let bridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")
        let readerBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: compiler,
            startingAt: "fn read_context_file",
            endingBefore: "fn split_sections"
        ))
        let markdownBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: compiler,
            startingAt: "fn markdown_files",
            endingBefore: "fn should_skip_context_dir"
        ))
        let skillBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: compiler,
            startingAt: "fn load_skill_summaries",
            endingBefore: "fn load_examples"
        ))
        let bridgeBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: bridge,
            startingAt: "pub fn compile_context_prompt_json",
            endingBefore: "/// Export a minimal canonical `.epbundle`"
        ))

        #expect(
            compiler.contains("const MAX_CONTEXT_FILE_BYTES: u64 = 64 * 1024")
                && compiler.contains("const MAX_MARKDOWN_FILES: usize = 512")
                && compiler.contains("TRUNCATED_CONTEXT_MARKER")
                && readerBody.contains(".take(MAX_CONTEXT_FILE_BYTES)")
                && readerBody.contains("metadata.len() > MAX_CONTEXT_FILE_BYTES"),
            "June context assembly must cap each vault file before UTF-8 decoding so large notes cannot inflate memory during grounding."
        )
        #expect(
            markdownBody.contains("files.len() >= MAX_MARKDOWN_FILES")
                && markdownBody.contains("pending.clear()")
                && compiler.contains("fn should_skip_context_dir")
                && compiler.contains(#"Some(".epistemos" | ".git" | ".obsidian" | "node_modules" | "target" | "build")"#),
            "June context assembly must cap recursive markdown discovery and skip private/cache/build directories."
        )
        #expect(
            skillBody.contains("skill_paths.truncate(MAX_MARKDOWN_FILES)")
                && compiler.contains("context_file_reader_caps_large_inputs")
                && compiler.contains("context_compiler_caps_skill_summary_count")
                && compiler.contains("markdown_files_skip_private_context_dirs")
                && compiler.contains("markdown_files_cap_large_vault_scans"),
            "June skill and RAG context loaders must carry source-level tests for bounded file bytes, bounded counts, and private directory skips."
        )
        #expect(
            bridgeBody.contains("ContextCompiler::new")
                && bridgeBody.contains("VaultIdentity::Personal")
                && bridgeBody.contains("compiled.assembled_prompt()")
                && bridgeBody.contains(#""source": "agent_core.context_compiler""#)
                && bridgeBody.contains(#""cache_breakpoints": compiled.cache_breakpoints"#)
                && !bridgeBody.contains(#""vault_path":"#),
            "The FFI bridge must expose the bounded Rust context compiler without echoing the absolute vault path into the JSON payload."
        )
        #expect(
            bridge.contains("compile_context_prompt_json_uses_bounded_context_compiler")
                && bridge.contains("compile_context_prompt_json_rejects_relative_vault_path"),
            "The FFI context compiler seam must have focused Rust tests for real assembly and fail-closed vault path validation."
        )
    }

    @Test("App Store June MAS PDF tool is root-confined and allowlisted")
    func appStoreJuneMASPDFToolIsRootConfinedAndAllowlisted() throws {
        let registry = try loadMirroredSourceTextFile("agent_core/src/tools/registry.rs")
        let runner = try loadMirroredSourceTextFile("Epistemos/Goose/GooseMASAgentCoreRunner.swift")
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let policy = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneMASToolPolicy.swift")
        let handlerBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: registry,
            startingAt: "impl ToolHandler for PdfToMarkdownTool",
            endingBefore: "struct ResolvedVaultPdf"
        ))
        let resolverBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: registry,
            startingAt: "fn resolve_vault_pdf_path",
            endingBefore: "fn path_to_str"
        ))

        #expect(
            registry.contains("fn register_phase_two_pdf_tools")
                && registry.contains("PdfToMarkdownTool::new(root)")
                && registry.contains("name: \"pdf.to_markdown\"")
                && registry.contains("risk_level: RiskLevel::ReadOnly")
                && registry.contains("tier: ToolTier::Agent"),
            "The MAS PDF converter must be a read-only, agent-tier tool registered only after the active vault root is known."
        )
        #expect(
            handlerBody.contains("crate::liteparse::pdf_to_markdown")
                && handlerBody.contains("bounded_pdf_tool_markdown")
                && handlerBody.contains(#""writes_vault": false"#)
                && !handlerBody.contains("std::process")
                && !handlerBody.contains("Command::new"),
            "The PDF tool must reuse the in-process LiteParse/EdgeParse seam, cap returned Markdown, and never spawn a sidecar."
        )
        #expect(
            resolverBody.contains("Component::Normal")
                && resolverBody.contains("!crate::liteparse::is_supported_pdf")
                && resolverBody.contains("candidate_metadata.file_type().is_symlink()")
                && resolverBody.contains("MAX_PDF_TOOL_INPUT_BYTES")
                && resolverBody.contains("canonical_pdf.starts_with(&canonical_root)")
                && !resolverBody.contains(#""vault_path":"#),
            "The PDF tool resolver must accept only vault-relative PDF paths, reject symlinks and oversized files, and avoid absolute vault-path payloads."
        )
        #expect(
            registry.contains("phase_two_pdf_tool_is_agent_only_and_root_gated")
                && registry.contains("pdf_to_markdown_rejects_absolute_and_traversal_paths")
                && registry.contains("pdf_to_markdown_rejects_oversized_pdf_before_parser")
                && registry.contains("pdf_to_markdown_parser_errors_do_not_leak_vault_root"),
            "Focused Rust tests must lock registration, path confinement, OOM bounds, and vault-root redaction."
        )
        #expect(
            policy.contains(#""pdf.to_markdown""#)
                && runner.contains("allowedToolNames: Self.allowedMASTools")
                && runner.contains("JuneMASToolPolicy.allowedAgentToolNames")
                && gateway.contains("JuneMASToolPolicy.allowedObservableCompositionToolNames")
                && gateway.contains("observableCompositionTools"),
            "June's MAS runner and replay observer must explicitly admit the canonical PDF tool name without widening the general tool surface."
        )
    }

    @Test("App Store June does not auto-discover arbitrary URL MCP servers")
    func appStoreJuneDoesNotAutoDiscoverArbitraryURLMCPServers() throws {
        let urlServers = try loadMirroredSourceTextFile("agent_core/src/mcp/url_servers.rs")
        let bridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")
        let runner = try loadMirroredSourceTextFile("Epistemos/Goose/GooseMASAgentCoreRunner.swift")

        #expect(
            urlServers.contains("cfg!(feature = \"pro-build\")")
                && urlServers.contains("url_mcp_discovery_is_disabled_for_mas_builds")
                && urlServers.contains("assert!(discover_url_mcp_servers().is_empty())"),
            "MAS builds must not auto-load user/project URL-MCP config files; fixed HTTPS allowlist admission must be explicit."
        )
        #expect(
            bridge.contains("MAS builds deliberately return")
                && bridge.contains("fixed HTTPS allowlist"),
            "The agent_core FFI bridge must document that URL-MCP discovery is Pro-only until MAS allowlist admission lands."
        )
        #expect(
            runner.contains("allowedToolNames: Self.allowedMASTools")
                && !runner.contains("stdio_mcp")
                && !runner.contains("cli_passthrough")
                && !runner.contains("code_execution"),
            "June's MAS runner must keep using the explicit tool-name allowlist and must not expose forbidden Pro-only tools."
        )
    }

    @Test("App Store final agent_core runner repeats June provider and consent admission")
    func appStoreFinalAgentCoreRunnerRepeatsProviderAndConsentAdmission() throws {
        let slugs = try loadMirroredSourceTextFile("Epistemos/Goose/GooseMASAgentCoreProviderSlug.swift")
        let runner = try loadMirroredSourceTextFile("Epistemos/Goose/GooseMASAgentCoreRunner.swift")

        #expect(slugs.contains("static func juneProvider(forResolvedSlug slug: String) -> CloudModelProvider?"))
        #expect(slugs.contains(#"case "openai", "openai_gpt55", "openai_gpt54""#))
        #expect(slugs.contains(#"case "claude_sonnet", "claude_opus", "claude_haiku""#))
        #expect(slugs.contains("default: nil"))
        #expect(runner.contains("GooseMASAgentCoreProviderSlug.juneProvider(forResolvedSlug: providerName)"))
        #expect(runner.contains("AgentCloudConsentStore.shared.hasConsent(for: provider)"))
        #expect(runner.contains("await MainActor.run"))
        #expect(runner.contains("Nothing was sent."))
        #expect(runner.range(of: "juneProvider(forResolvedSlug: providerName)")!.lowerBound
            < runner.range(of: "AppBootstrap.withScopedAgentCoreEnvironment")!.lowerBound)
    }
}
