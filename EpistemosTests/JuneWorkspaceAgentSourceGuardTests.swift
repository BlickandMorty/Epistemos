import Foundation
import Testing

@Suite("MAS Workspace agent source guards")
nonisolated struct JuneWorkspaceAgentSourceGuardTests {
    @Test("local model selection updates the visible session and remains selectable while downloading")
    func localModelSelectionPersistsToCurrentSession() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")

        #expect(gateway.contains("func setModel(sessionID: String, model: String?)"))
        #expect(gateway.contains("store.setModel(sessionID: currentSessionID, model: id)"))
        #expect(gateway.contains("func setSessionModel(_ id: String, for sessionID: String) -> Bool"))
        #expect(gateway.contains("case \"command.dispatch\":"))
        #expect(gateway.contains("trimmed.hasPrefix(\"/model\")"))
        #expect(gateway.contains("modelID(fromModelCommand: command)"))
        #expect(gateway.contains("startTurn(sessionID: sessionID, prompt: text, requestedModelID: requestedModel)"))
        #expect(gateway.contains("selectableModelIDs().contains(model)"))
        #expect(gateway.contains("selectableModelIDs().contains($0) ? $0 : nil"))
        #expect(gateway.contains("row[\"model\"] = model"))
        #expect(gateway.contains("downloads.beginDownload(entry)"))
        #expect(gateway.contains("return available.first { $0 != JuneModelID.cloud } ?? JuneModelID.cloud"),
                "Cloud must never be the silent default while a local lane is available.")
    }

    @Test("cloud routing is an exact lane, not the fallback for unknown local ids")
    func cloudRoutingIsExactOnly() throws {
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
        #expect(fallbackBlock.contains("return localGGUF.stream"))
    }

    @Test("local rows do not fake function calling to satisfy the picker")
    func localRowsDoNotFakeFunctionCalling() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")

        #expect(!gateway.contains("localPickerCapabilities"))
        #expect(!gateway.contains("\"capabilities\": Self.localPickerCapabilities"))
        #expect(gateway.contains("modelSupportsTools"))
        #expect(gateway.contains("epistemos-local-chat"))
        #expect(gateway.contains("\"capabilities\": [String]()"))
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

    @Test("catalog includes Phi and permissive Llama-family instruct GGUF rows")
    func catalogIncludesRequestedPermissiveRows() throws {
        let catalog = try loadMirroredSourceTextFile("Epistemos/QuickChat/GGUFModelCatalog.swift")

        for required in [
            "case phi3",
            "case llamaChat",
            "phi-3.5-mini-instruct-q4km",
            "bartowski/Phi-3.5-mini-instruct-GGUF",
            "Phi-3.5-mini-instruct-Q4_K_M.gguf",
            "license: \"MIT\"",
            "tinyllama-1.1b-chat-q4km",
            "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
            "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf",
            "template: .llamaChat",
            "license: \"Apache-2.0\"",
        ] {
            #expect(catalog.contains(required), "Missing catalog contract: \(required)")
        }

        #expect(catalog.contains("<|system|>\\n\\(instructions)<|end|>\\n"))
        #expect(catalog.contains("<|user|>\\n\\(userPrompt)</s>\\n<|assistant|>\\n"))
        #expect(catalog.contains("Llama 3.x is deliberately excluded"))
    }

    @Test("cloud testing seam mints or accepts real DEBUG proxy sessions only")
    func debugCloudTestingSeamIsRealAndDebugOnly() throws {
        let proxy = try loadMirroredSourceTextFile("Epistemos/AgentWorkspace/EpistemosProxyClient.swift")
        let cloud = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneCloudEngine.swift")

        #expect(proxy.contains("func sessionForCloudRequest() async throws -> EpistemosProxySession?"))
        #expect(proxy.contains("#if DEBUG"))
        #expect(proxy.contains("EPISTEMOS_PROXY_DEV_TOKEN"))
        #expect(proxy.contains("EPISTEMOS_PROXY_DEV_SESSION_TOKEN"))
        #expect(proxy.contains("v1/auth/dev-session"))
        #expect(proxy.contains("[\"scope\": \"chat.completions\"]"))
        #expect(cloud.contains("try await EpistemosProxyClient.shared.sessionForCloudRequest()"))
        #expect(!cloud.contains("EpistemosProxyClient.shared.currentSession()"),
                "Cloud lane should use the testable StoreKit-or-DEBUG session seam.")
    }

    @Test("Workspace overlay owns visible rebrand, pixel font, and chat layout fixes")
    func workspaceOverlayContractsStayMounted() throws {
        let surface = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentSurfaceView.swift")

        for required in [
            "Self.workspaceOverlayScript()",
            "ChonkyPixels.ttf",
            "Epistemos Workspace Pixel",
            "replaceWorkspaceWords",
            ".replace(/\\\\bJune\\\\b/g, \"Workspace\")",
            "agent-user-turn-body",
            "--epistemos-user-bubble-text",
            "--epistemos-user-bubble-bg",
            "caret-color: var(--foreground) !important",
            "Ask Workspace anything, run / commands",
            "data-placeholder",
            ".sidebar-brand::after",
            "content: \"Workspace\" !important",
            "app-shell[data-sidebar=\"expanded\"] .main-column",
            "Loading Workspace",
            "The Workspace bundle is missing from this build.",
        ] {
            #expect(surface.contains(required), "Missing Workspace overlay contract: \(required)")
        }

        #expect(!surface.contains("app-shell[data-sidebar=\"collapsed\"] .agent-composer"))
        #expect(!surface.contains("--epistemos-composer-gutter"))
        #expect(!surface.contains("position: fixed !important"))
        #expect(!surface.contains("--sidebar-w-current"))

        #expect(!surface.contains("The June agent bundle is missing from this build."))
        #expect(!surface.contains("The June bridge shim could not be loaded."))
        #expect(!surface.contains("The June entry URL is invalid."))
    }

    @Test("Workspace web view delegate is installed before the first load")
    func workspaceWebViewRevealsOnColdOpen() throws {
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

        for (caseStart, expectedTextColor) in [
            ("        case .systemLight:\n            return ResolvedTheme(", "userBubbleText: .hex(0xFFFFFF)"),
            ("        case .systemDark:\n            return ResolvedTheme(", "userBubbleText: .hex(0x000000)"),
            ("        case .light:\n            return ResolvedTheme(", "userBubbleText: .hex(0xFFFFFF)"),
            ("        case .oled:\n            return ResolvedTheme(", "userBubbleText: .hex(0x000000)"),
            ("        case .oledSoft:\n            return ResolvedTheme(", "userBubbleText: .hex(0x000000)"),
            ("        case .tan:\n            return ResolvedTheme(", "userBubbleText: .hex(0xFFFFFF)"),
            ("        case .ember:\n            return ResolvedTheme(", "userBubbleText: .hex(0xFFFFFF)"),
            ("        case .platinumViolet:\n            return ResolvedTheme(", "userBubbleText: .hex(0xFFFFFF)"),
            ("        case .platinumVioletDark:\n            return ResolvedTheme(", "userBubbleText: .hex(0xFFFFFF)"),
        ] {
            let block = try resolvedThemeCaseBlock(in: theme, startingWith: caseStart)
            #expect(block.contains(expectedTextColor), "Missing \(expectedTextColor) in \(caseStart)")
        }
    }

    @Test("MAS toolbar pill exposes exactly the requested controls")
    func toolbarPillHasOnlyRequestedControls() throws {
        let nav = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentNavBar.swift")
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")

        #expect(occurrences(of: "pillButton(title: \"", in: nav) == 3)
        #expect(nav.contains("pillButton(title: \"Epistemos\""))
        #expect(nav.contains("pillButton(title: \"New Chat\""))
        #expect(nav.contains("pillButton(title: \"All Chats\""))
        #expect(nav.contains("Font.custom(\"ChonkyPixels\""))
        #expect(!nav.contains("speaker.wave.2"))
        #expect(!nav.contains("EpistemosSpeechSynthesizer.shared"))
        #expect(root.contains("&& ui.homeContent == .greeting"))
        #expect(root.contains("|| showJuneAgentToolbarControls"))
    }

    @Test("native visible MAS copy says Workspace and chats")
    func nativeVisibleCopyUsesWorkspace() throws {
        let chrome = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentChrome.swift")
        let perf = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentPerf.swift")
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let bridge = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentBridge.swift")
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingFeatureButtons.swift")

        #expect(chrome.contains("\"No chats yet\""))
        #expect(chrome.contains("Text(\"Start a chat in Workspace and it will appear here.\")"))
        #expect(chrome.contains(".navigationTitle(\"Workspace chats\")"))
        #expect(chrome.contains("Button(\"New Chat\")"))
        #expect(perf.contains("LabeledContent(\"Workspace surface\")"))
        #expect(gateway.contains("\"You are Workspace, a helpful on-device assistant inside Epistemos. \""))
        #expect(gateway.contains("let title = rawTitle == \"New session\" ? \"New chat\" : rawTitle"))
        #expect(bridge.contains("return derived.isEmpty ? \"New chat\" : derived"))
        #expect(landing.contains("Workspace - chat with on-device models"))
    }

    @Test("Workspace exposes direct provider cloud models for the five requested providers")
    func workspaceExposesRequestedCloudProviders() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let inference = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")

        for required in [
            "private static let directCloudProviders: [CloudModelProvider]",
            ".openAI",
            ".anthropic",
            ".google",
            ".zai",
            ".kimi",
            "CloudTextModelID(rawValue: modelID)",
            "makeAgentCoreCloudStream",
            "CloudTextModelID.models(for: provider)",
            "\"provider\": provider.rawValue",
            "\"name\": \"\\(provider.displayName) · \\(model.displayName)\"",
        ] {
            #expect(gateway.contains(required), "Missing Workspace provider picker contract: \(required)")
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
            "ForEach(CloudModelProvider.preferredOrder, id: \\.self)",
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
            "CloudTextModelID.models(for: provider)",
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

    private func resolvedThemeCaseBlock(in source: String, startingWith caseStart: String) throws -> String {
        let start = try #require(source.range(of: caseStart))
        let next = source.range(of: "\n        case .", range: start.upperBound..<source.endIndex)
        return String(source[start.lowerBound..<(next?.lowerBound ?? source.endIndex)])
    }
}
