import Foundation
import Testing

@Suite("MAS Workspace agent source guards")
nonisolated struct JuneWorkspaceAgentSourceGuardTests {
    @Test("selected GGUF models stay in June and download only through the guarded lane")
    func selectedGGUFModelsStayInJuneAndDownloadOnlyThroughGuardedLane() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let sessionStore = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneSessionStore.swift")
        let specificGGUFRoute = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "if let entry = GGUFModelCatalog.entry(id: modelID) {",
            endingBefore: "// Legacy/unknown local id"
        ))
        let prepareSelectedModel = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "private func prepareSelectedModel(_ id: String)",
            endingBefore: "func modelsPayload()"
        ))

        #expect(gateway.contains("func setDefaultModel(_ id: String) -> Bool"))
        #expect(gateway.contains("store.setModel(sessionID: currentSessionID, model: selected)"))
        #expect(gateway.contains("func setSessionModel(_ id: String, for sessionID: String) -> Bool"))
        #expect(gateway.contains("private func explicitlyAdmittedModelID(_ id: String) -> String?"))
        #expect(gateway.contains("return \"\\(entry.displayName) is connected to June, but it can't run on this Mac."))
        #expect(gateway.contains("return id\n        }\n        if let entry = GGUFModelCatalog.entry(id: id)"))
        #expect(gateway.contains("case \"command.dispatch\":"))
        #expect(gateway.contains("trimmed.hasPrefix(\"/model\")"))
        #expect(gateway.contains("modelID(fromModelCommand: command)"))
        #expect(gateway.contains("!setSessionModel(requestedModel, for: sessionID)"))
        #expect(gateway.contains("message: modelSelectionFailureMessage(requestedModel)"))
        #expect(gateway.contains("startTurn(sessionID: sessionID, prompt: text)"))
        #expect(!gateway.contains("_ = setSessionModel(requestedModelID, for: sessionID)"))
        #expect(gateway.contains("guard let selected = explicitlyAdmittedModelID(model) else"))
        #expect(gateway.contains("chosenModel = selected"))
        #expect(!gateway.contains("private func validModelID(_ id: String)"))
        #expect(sessionStore.contains("row[\"model\"] = model"))
        #expect(gateway.contains("if localGGUF.isAvailableInThisBuild {\n            ids.append(contentsOf: GGUFModelCatalog.installedEntries().map(\\.id))"))
        #expect(gateway.contains("if localGGUF.isAvailableInThisBuild {\n            ids.append(contentsOf: GGUFModelCatalog.entries.map(\\.id))"))
        #expect(gateway.contains("localGGUFAvailable: localGGUF.isAvailableInThisBuild"))
        #expect(
            specificGGUFRoute.contains("guard localGGUF.isAvailableInThisBuild else")
                && specificGGUFRoute.range(of: "guard localGGUF.isAvailableInThisBuild else")!.lowerBound
                    < specificGGUFRoute.range(of: "downloads.beginDownload(entry)")!.lowerBound,
            "GGUF model data must not download unless the in-process runtime is linked."
        )
        #expect(
            prepareSelectedModel.contains("guard localGGUF.isAvailableInThisBuild else { return }")
                && prepareSelectedModel.range(of: "guard localGGUF.isAvailableInThisBuild else { return }")!.lowerBound
                    < prepareSelectedModel.range(of: "downloads.beginDownload(entry)")!.lowerBound,
            "Direct model selection must pass runtime availability before starting model-data downloads."
        )
    }

    @Test("cloud routing is exact and legacy local ids remain on-device")
    func cloudRoutingIsExactAndLegacyLocalIDsRemainOnDevice() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let cloudCaseStart = try #require(gateway.range(of: "case JuneModelID.cloud:"))
        let defaultStart = try #require(gateway.range(of: "default:", range: cloudCaseStart.lowerBound..<gateway.endIndex))
        let cloudBlock = String(gateway[cloudCaseStart.lowerBound..<defaultStart.lowerBound])
        let fallbackBlock = String(gateway[defaultStart.lowerBound..<gateway.endIndex])

        #expect(cloudBlock.contains("makeAgentCoreCloudStream"))
        #expect(gateway.contains("GooseMASAgentCoreRunner"))
        #expect(gateway.contains("streamGooseMASAgentCoreRun"))
        #expect(!fallbackBlock.contains("makeAgentCoreCloudStream"),
                "Unknown or legacy local ids must fall back to on-device lanes, not cloud.")
        #expect(fallbackBlock.contains("guard localGGUF.isAvailableInThisBuild else"))
        #expect(fallbackBlock.contains("Local GGUF chat isn't available in this build"))
        #expect(fallbackBlock.contains("localGGUF.stream"))
    }

    @Test("local rows do not fake function calling to satisfy the picker")
    func localRowsDoNotFakeFunctionCalling() throws {
        let catalog = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentModelCatalog.swift")

        #expect(!catalog.contains("localPickerCapabilities"))
        #expect(!catalog.contains("\"capabilities\": Self.localPickerCapabilities"))
        #expect(catalog.contains("modelSupportsTools"))
        #expect(catalog.contains("epistemos-local-chat"))
        #expect(catalog.contains("\"capabilities\": [String]()"))
    }

    @Test("June cloud stream maps agent_core events to native June event frames")
    func cloudStreamMapsAgentCoreEvents() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")

        for required in [
            "case .textDelta(let delta):",
            "\"message.delta\"",
            "case .thinkingDelta(let delta):",
            "\"thinking.delta\"",
            "case .toolStarted(let id, let name, let inputJson):",
            "\"tool.start\"",
            "case .toolCompleted(let id, let name, let result, let isError):",
            "\"tool.complete\"",
            "case .permissionRequired(let id, let toolName, let inputJson, let riskLevel):",
            "\"approval.request\"",
            "case \"approval.respond\":",
        ] {
            #expect(gateway.contains(required), "Missing agent_core event bridge contract: \(required)")
        }

        #expect(!gateway.contains("bootstrap.cloudLLMClient.stream"),
                "June cloud turns must not bypass agent_core with direct chat streaming.")
    }

    @Test("catalog contains only the three selected permissive GGUF rows")
    func catalogContainsOnlySelectedPermissiveRows() throws {
        let catalog = try loadMirroredSourceTextFile("Epistemos/QuickChat/GGUFModelCatalog.swift")

        for required in [
            "qwen3-4b-instruct-q4km",
            "qwen3-8b-q4km",
            "qwen2.5-7b-instruct-q4km",
            "template: .chatML",
            "license: \"Apache-2.0\"",
        ] {
            #expect(catalog.contains(required), "Missing catalog contract: \(required)")
        }

        #expect(catalog.components(separatedBy: "GGUFCatalogEntry(").count - 1 == 3)
        #expect(!catalog.contains("phi-3.5-mini-instruct-q4km"))
        #expect(!catalog.contains("tinyllama-1.1b-chat-q4km"))
        #expect(catalog.contains("Llama 3.x is deliberately excluded"))
    }

    @Test("legacy receipt proxy is parked outside the MAS June product")
    func legacyReceiptProxyIsCompileParked() throws {
        let proxy = try loadMirroredSourceTextFile("Epistemos/AgentWorkspace/EpistemosProxyClient.swift")
        let subscription = try loadMirroredSourceTextFile("Epistemos/AgentWorkspace/AgentSubscriptionService.swift")
        let cloud = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneCloudEngine.swift")
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let project = try loadMirroredSourceTextFile("project.yml")

        for parked in [proxy, subscription, cloud] {
            #expect(parked.hasPrefix("#if EPISTEMOS_LEGACY_RECEIPT_PROXY\n"))
        }
        #expect(!project.contains("EPISTEMOS_LEGACY_RECEIPT_PROXY"))
        #expect(!gateway.contains("JuneCloudEngine"))
        #expect(!gateway.contains("EpistemosProxyClient"))
        #expect(gateway.contains("streamGooseMASAgentCoreRun"))
        #expect(gateway.contains("requireCloudDataConsent"))
    }

    @Test("June overlay preserves June branding, display font, and chat layout fixes")
    func juneOverlayContractsStayMounted() throws {
        let surface = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentSurfaceView.swift")

        for required in [
            "Self.juneOverlayScript()",
            "juneFontFaceCSS()",
            "juneDisplayFontDataURL()",
            "MatrixDotsDemoRegular.ttf",
            "Epistemos Matrix Dots",
            "agent-user-turn-body",
            "--epistemos-user-bubble-text",
            "--epistemos-user-bubble-bg",
            "caret-color: var(--foreground) !important",
            "Ask June anything, run / commands",
            ".sidebar-brand::after",
            "content: \"June\" !important",
            "app-shell[data-sidebar=\"expanded\"] .main-column",
            "Loading June",
            "The June agent bundle is missing from this build.",
        ] {
            #expect(surface.contains(required), "Missing June overlay contract: \(required)")
        }

        #expect(!surface.contains("replaceWorkspaceWords"))
        #expect(!surface.contains(".replace(/\\\\bJune\\\\b/g, \"Workspace\")"))
        #expect(!surface.contains("Ask Workspace anything"))
        #expect(!surface.contains("content: \"Workspace\" !important"))
        #expect(!surface.contains("app-shell[data-sidebar=\"collapsed\"] .agent-composer"))
        #expect(!surface.contains("--epistemos-composer-gutter"))
        #expect(!surface.contains("position: fixed !important"))
        #expect(!surface.contains("--sidebar-w-current"))
    }

    @Test("June web view delegate is installed before the first load")
    func juneWebViewRevealsOnColdOpen() throws {
        let surface = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentSurfaceView.swift")
        let load = try #require(surface.range(of: "webView.load(URLRequest(url: entry))"))
        let delegate = try #require(surface.range(of: "webView.navigationDelegate = JuneNavigationDelegate.shared"))
        let uiDelegate = try #require(surface.range(of: "webView.uiDelegate = JuneNavigationDelegate.shared"))
        let ensure = try #require(surface.range(of: "holder.ensureStarted(theme: ui.theme)"))
        let mount = try #require(surface.range(of: "mountedWebView = holder.webView"))
        let callback = try #require(surface.range(of: "JuneNavigationDelegate.shared.onFirstPaint = {"))

        #expect(delegate.lowerBound < load.lowerBound)
        #expect(uiDelegate.lowerBound < load.lowerBound)
        #expect(callback.lowerBound < ensure.lowerBound)
        #expect(ensure.lowerBound < mount.lowerBound)
        #expect(surface.contains("@State private var mountedWebView: WKWebView?"))
        #expect(surface.contains("June surface navigation finished"))
        #expect(surface.contains("didFailProvisionalNavigation"))
    }

    @Test("MAS June web bundle is required and bundle-only")
    func masJuneWebBundleIsRequiredAndBundleOnly() throws {
        let project = try loadMirroredSourceTextFile("project.yml")
        let bundler = try loadMirroredSourceTextFile("bundle-app-runtime-assets.sh")
        let assets = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneWebAssets.swift")
        let gate = try loadMirroredSourceTextFile("scripts/keelstone-release-gate.sh")

        #expect(project.contains("build-june-web.sh"))
        #expect(bundler.contains("is_complete_june_web_tree"))
        #expect(bundler.contains("dist/index.html"))
        #expect(bundler.contains("tauri-internals-shim.js"))
        #expect(bundler.contains("App Store build requires staged JuneWeb files"))
        #expect(assets.contains("Contents/Resources/JuneWeb"))
        #expect(!assets.contains("EPISTEMOS_JUNE_WEBROOT"))
        #expect(!assets.contains("devForkRoot"))
        #expect(!assets.contains("ProcessInfo.processInfo.environment"))
        #expect(gate.contains("Built App Store artifact includes JuneWeb/dist/index.html"))
        #expect(gate.contains("Built App Store artifact includes JuneWeb/tauri-internals-shim.js"))
    }

    @Test("user message text color follows the requested theme-pair matrix")
    func userMessageTextColorFollowsThemePairMatrix() throws {
        let theme = try loadMirroredSourceTextFile("Epistemos/Theme/EpistemosTheme.swift")

        for required in [
            "case .classic: .light",
            "case .classic: .oledSoft",
            "case .ember:   .tan",
            "case .ember:   .ember",
            "case .platinumViolet: .platinumViolet",
            "case .platinumViolet: .platinumVioletDark",
        ] {
            #expect(theme.contains(required), "Missing theme-pair mapping: \(required)")
        }

        for (caseName, expectedTextColor) in [
            (".systemLight", "userBubbleText: .hex(0xFFFFFF)"),
            (".systemDark", "userBubbleText: .hex(0x000000)"),
            (".light", "userBubbleText: .hex(0xFFFFFF)"),
            (".oled", "userBubbleText: .hex(0x000000)"),
            (".oledSoft", "userBubbleText: .hex(0x000000)"),
            (".tan", "userBubbleText: .hex(0xFFFFFF)"),
            (".ember", "userBubbleText: .hex(0xFFFFFF)"),
            (".platinumViolet", "userBubbleText: .hex(0xFFFFFF)"),
            (".platinumVioletDark", "userBubbleText: .hex(0xFFFFFF)"),
        ] {
            let block = try resolvedThemeCaseBlock(in: theme, caseName: caseName)
            #expect(block.contains(expectedTextColor), "Missing \(expectedTextColor) in \(caseName)")
        }
    }

    @Test("MAS toolbar exposes the requested controls")
    func toolbarPillHasOnlyRequestedControls() throws {
        let nav = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentNavBar.swift")
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")

        #expect(nav.contains("Button(action: onReturnHome)"))
        #expect(occurrences(of: "Button {", in: nav) == 4)
        #expect(nav.contains("JuneAgentIntents.newSession()"))
        #expect(nav.contains("showingAllChats = true"))
        #expect(nav.contains("JuneAllChatsSheet()"))
        #expect(nav.contains("showingNotes = true"))
        #expect(nav.contains("JuneNotesBrowserPopover()"))
        #expect(nav.contains("EpistemosAgentReadAloud.speak"))
        #expect(nav.contains("KokoroVoiceInstallPrompt()"))
        #expect(nav.contains("Image(systemName: \"chevron.left\")"))
        #expect(nav.contains("Image(systemName: \"plus.bubble\")"))
        #expect(nav.contains("Image(systemName: \"list.bullet.rectangle\")"))
        #expect(nav.contains("Image(systemName: \"sidebar.leading\")"))
        #expect(nav.contains("return ttsAvailable ? \"speaker.wave.2\""))
        #expect(!nav.contains("pillButton(title:"))
        #expect(!nav.contains("Font.custom(\"ChonkyPixels\""))
        #expect(root.contains("&& ui.homeContent == .greeting"))
        #expect(root.contains("|| showJuneAgentToolbarControls"))
    }

    @Test("native visible MAS copy consistently says June and chats")
    func nativeVisibleCopyUsesJune() throws {
        let chrome = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentChrome.swift")
        let perf = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentPerf.swift")
        let context = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentConversationContext.swift")
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let bridge = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentBridge.swift")
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingFeatureButtons.swift")
        let landingView = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(chrome.contains("\"No chats yet\""))
        #expect(chrome.contains("Text(\"Start a chat in June and it will appear here.\")"))
        #expect(chrome.contains(".navigationTitle(\"June chats\")"))
        #expect(chrome.contains("Button(\"New Chat\")"))
        #expect(perf.contains("LabeledContent(\"June surface\")"))
        #expect(context.contains("\"You are June, a helpful assistant inside Epistemos. \""))
        #expect(context.contains("\"You are June, a helpful on-device assistant inside Epistemos. \""))
        #expect(context.contains("who = \"June\""))
        #expect(gateway.contains("let title = rawTitle == \"New session\" ? \"New chat\" : rawTitle"))
        #expect(bridge.contains("return derived.isEmpty ? \"New chat\" : derived"))
        #expect(landing.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX\n            \"june\""))
        #expect(landing.contains("June — chat with Cloud Agent, Apple Intelligence, or your selected local models."))
        #expect(landing.contains("June is unavailable in this build."))
        #expect(landingView.contains("private var agentPageTitle: String"))
        #expect(landingView.contains("HomeEmbeddedPage(title: agentPageTitle)"))
        #expect(landingView.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX\n        \"June\""))
    }

    @Test("June exposes direct provider cloud models only for configured agent-tier MAS lanes")
    func juneExposesRequestedCloudProviders() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let catalog = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentModelCatalog.swift")
        let inference = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")

        for required in [
            "static let directCloudProviders = CloudModelProvider.juneAgentProviders",
            ".openAI",
            ".anthropic",
            "CloudTextModelID.juneAgentModels(for: provider)",
            "\"provider\": provider.rawValue",
            "\"name\": \"\\(provider.displayName) · \\(model.displayName)\"",
        ] {
            #expect(catalog.contains(required), "Missing June provider picker contract: \(required)")
        }
        #expect(!catalog.contains("static let directCloudProviders: [CloudModelProvider] = [.openAI, .anthropic, .google"))

        for required in [
            "CloudTextModelID(rawValue: modelID)",
            "makeAgentCoreCloudStream",
            "cloudModel.provider.supportsAgentTier",
            "CloudTextModelID.juneAgentModels(for: cloudModel.provider).contains(cloudModel)",
            "is not connected to MAS June",
            "JuneAgentModelCatalog.directCloudModelIDs(configuredOnly: true)",
        ] {
            #expect(gateway.contains(required), "Missing June provider routing contract: \(required)")
        }

        for required in [
            "case openAIGPT55 = \"openai:gpt-5.5\"",
            "case openAIGPT53Codex = \"openai:gpt-5.3-codex\"",
            "case anthropicClaudeFable5 = \"anthropic:claude-fable-5\"",
            "case anthropicClaudeOpus48 = \"anthropic:claude-opus-4-8\"",
            "case anthropicClaudeSonnet5 = \"anthropic:claude-sonnet-5\"",
            "case googleGemini31ProPreview = \"google:gemini-3.1-pro-preview\"",
            "case googleGemini31FlashLite = \"google:gemini-3.1-flash-lite\"",
            "case zaiGLM52 = \"zai:glm-5.2\"",
            "case kimiK27Code = \"kimi:kimi-k2.7-code\"",
            "case kimiK26 = \"kimi:kimi-k2.6\"",
            ".zai,",
            ".kimi,",
        ] {
            #expect(inference.contains(required), "Missing provider/model contract: \(required)")
        }
    }

    @Test("Settings separates requested cloud providers with account and API setup")
    func settingsExposeAccountAndAPICloudProviderSetup() throws {
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let shared = try loadMirroredSourceTextFile("Epistemos/Views/Shared/CloudProviderSetupCard.swift")
        let inference = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")

        for required in [
            "case cloudModels = \"Cloud Models\"",
            "case .cloudModels: CloudModelsSettingsView()",
            "ForEach(settingsProviders, id: \\.self)",
            "CloudProviderSettingsRow(",
            "OpenAIDeviceAuthorizationSheet",
            "signInToOpenAI",
            "importOpenAIAccount",
            "importAnthropicAccount",
            "signInToGoogle(configuration:",
            "Retry Claude Code Import",
            "Retry Google OAuth",
            "Paste + Save",
            "Save Typed Key",
            "inference.cloudModels(for: provider)",
            "Choose Google OAuth JSON",
            "Clear Google OAuth JSON",
            "Google Cloud project ID (not project number)",
            "CloudProviderSetupAutomation.loadGoogleOAuthClientConfigData()",
            "CloudProviderSetupAutomation.loadGoogleOAuthClientFilename()",
            "CloudProviderSetupAutomation.loadGoogleOAuthProjectIDDraft()",
            "CloudProviderSetupAutomation.persistGoogleOAuthProjectIDDraft(newValue)",
            "CloudProviderSetupAutomation.persistGoogleOAuthClientConfig(",
            "Removed the saved Google OAuth client JSON.",
            "Google OAuth client JSON verified.",
            "Verify live access before making this provider active.",
            ".disabled(!validationState.isVerified)",
        ] {
            #expect(settings.contains(required), "Missing Settings cloud setup contract: \(required)")
        }

        for required in [
            "supportsAccountConnection ? \"Legacy API Key\" : \"API Key\"",
            "Open Z.AI API Keys",
            "Open Moonshot API Keys",
        ] {
            #expect(inference.contains(required), "Missing provider setup copy contract: \(required)")
        }

        #expect(shared.contains("title: \"Open Verification Page\""))
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    private func resolvedThemeCaseBlock(in source: String, caseName: String) throws -> String {
        let buildResolved = try #require(source.range(of: "nonisolated private func buildResolved() -> ResolvedTheme"))
        let start = try #require(source.range(of: "\n        case \(caseName):", range: buildResolved.upperBound..<source.endIndex))
        let next = source.range(of: "\n        case .", range: start.upperBound..<source.endIndex)
        return String(source[start.lowerBound..<(next?.lowerBound ?? source.endIndex)])
    }
}
