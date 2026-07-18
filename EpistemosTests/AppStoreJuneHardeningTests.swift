import Foundation
import Testing

@Suite("App Store June hardening")
struct AppStoreJuneHardeningTests {
    @Test("June WebView recovery gates bridge JavaScript and cancels orphaned turns")
    func juneWebContentRecoveryIsLoadAndNavigationGuarded() throws {
        let surface = try loadMirroredSourceTextFile(
            "Epistemos/JuneAgent/JuneAgentSurfaceView.swift"
        )
        let gateway = try loadMirroredSourceTextFile(
            "Epistemos/JuneAgent/JuneAgentGateway.swift"
        )

        #expect(surface.contains("private(set) var pageReady = false"))
        #expect(surface.contains("private var activeNavigation: WKNavigation?"))
        #expect(surface.contains("guard self.pageReady, !webView.isLoading else"))
        #expect(surface.contains("func finishNavigation(_ navigation: WKNavigation?, succeeded: Bool) -> Bool"))
        #expect(surface.contains("guard let activeNavigation, navigation === activeNavigation else { return false }"))
        #expect(surface.contains("func beginNavigation(_ navigation: WKNavigation?, in webView: WKWebView)"))
        #expect(surface.contains("didStartProvisionalNavigation navigation: WKNavigation!"))
        #expect(surface.contains("beginNavigation(navigation, in: webView)"))
        #expect(surface.contains("func webViewWebContentProcessDidTerminate(_ webView: WKWebView)"))
        #expect(surface.contains("recoverAfterWebContentProcessTermination(in: webView)"))
        #expect(surface.contains("bridge?.gateway.cancelAllTurnsForSurfaceRecovery()"))
        #expect(surface.contains("activeNavigation = webView.load(URLRequest(url: entry))"))
        #expect(gateway.contains("func cancelAllTurnsForSurfaceRecovery()"))
        #expect(gateway.contains("approvals.denyPendingApprovals(sessionID: sessionID)"))
    }

    @Test("June native-to-WebKit delivery is serialized and byte bounded")
    func juneBridgeJavaScriptDispatchIsBoundedAndBatched() throws {
        let surface = try loadMirroredSourceTextFile(
            "Epistemos/JuneAgent/JuneAgentSurfaceView.swift"
        )

        #expect(surface.contains("private static let maxPendingBridgeJavaScriptCount = 256"))
        #expect(surface.contains("private static let maxPendingBridgeJavaScriptBytes = 2 * 1_024 * 1_024"))
        #expect(surface.contains("private static let bridgeJavaScriptBatchCount = 32"))
        #expect(surface.contains("private var pendingBridgeJavaScript: [String] = []"))
        #expect(surface.contains("private var pendingBridgeJavaScriptBytes = 0"))
        #expect(surface.contains("private var bridgeJavaScriptEvaluationInFlight = false"))
        #expect(surface.contains("private var bridgeJavaScriptDispatchGeneration = 0"))
        #expect(surface.contains("enqueueBridgeJavaScript(js, in: webView)"))
        #expect(surface.contains("private func flushBridgeJavaScript(in webView: WKWebView)"))
        #expect(surface.contains("webView.evaluateJavaScript(batchScript)"))
        #expect(surface.contains("generation == self.bridgeJavaScriptDispatchGeneration"))
        #expect(surface.contains("resetBridgeJavaScriptDispatch()"))
        #expect(surface.contains("recoverAfterBridgeJavaScriptFailure(in: webView"))
    }

    @Test("App Store June parks Google OAuth loopback callback server")
    func appStoreJuneParksGoogleOAuthLoopbackCallbackServer() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/CloudProviderAuthService.swift")
        let networkImportGuard = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: source,
            startingAt: "#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\nimport Network",
            endingBefore: "import os"
        ))
        let signInToGoogle = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: source,
            startingAt: "func signInToGoogle(",
            endingBefore: "private func refreshedCredentialIfNeeded"
        ))
        let masBranch = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: signInToGoogle,
            startingAt: "#if EPISTEMOS_APP_STORE || MAS_SANDBOX",
            endingBefore: "#else"
        ))
        let directBranch = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: signInToGoogle,
            startingAt: "#else",
            endingBefore: "#endif"
        ))
        let listenerGuard = try #require(source.range(
            of: "#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\nactor LocalOAuthCallbackServer"
        ))
        let listenerBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: source,
            startingAt: "actor LocalOAuthCallbackServer",
            endingBefore: "#endif"
        ))

        #expect(
            networkImportGuard.contains("import Network")
                && networkImportGuard.contains("#endif"),
            "The Network framework import must be compile-parked out of MAS builds."
        )
        #expect(
            masBranch.contains("throw CloudProviderAuthError.googleOAuthLoopbackUnavailableInAppStore")
                && !masBranch.contains("LocalOAuthCallbackServer")
                && !masBranch.contains("NWListener")
                && !masBranch.contains("NWConnection")
                && !masBranch.contains("127.0.0.1"),
            "MAS Google sign-in must fail closed before constructing a loopback callback listener."
        )
        #expect(
            directBranch.contains("LocalOAuthCallbackServer.start")
                && directBranch.contains(#""http://127.0.0.1:\(await callback.currentPort())/oauth2callback""#),
            "The direct lane keeps the desktop OAuth loopback implementation."
        )
        #expect(
            listenerGuard.lowerBound < source.range(of: "actor LocalOAuthCallbackServer")!.lowerBound
                && listenerBody.contains("NWListener")
                && listenerBody.contains("NWConnection")
                && listenerBody.contains(#"expectedHost: "127.0.0.1""#),
            "The local OAuth listener implementation must remain direct-lane only."
        )
    }

    @Test("App Store June local streams are bounded and split local thinking tags")
    func appStoreJuneLocalStreamsAreBoundedAndSplitLocalThinkingTags() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let context = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentConversationContext.swift")
        let appleFM = try loadMirroredSourceTextFile("Epistemos/QuickChat/AppleFMQuickChatBackend.swift")
        let gguf = try loadMirroredSourceTextFile("Epistemos/QuickChat/LocalGGUFQuickChatBackend.swift")
        let cloudScaffold = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneCloudEngine.swift")

        for (name, source) in [
            ("JuneAgentGateway", gateway),
            ("AppleFMQuickChatBackend", appleFM),
            ("JuneCloudEngine", cloudScaffold),
        ] {
            #expect(
                source.contains("AsyncThrowingStream(bufferingPolicy: .bufferingNewest(256))"),
                "\(name) must bound token/event streams; default unbounded AsyncThrowingStream is an OOM risk on 16 GB machines."
            )
        }
        #expect(
            gguf.contains("import EpistemosLlama")
                && gguf.contains("private let engine = LlamaLocalChatEngine()")
                && gguf.contains("var isAvailableInThisBuild: Bool { true }")
                && gguf.contains("AsyncThrowingStream(bufferingPolicy: .bufferingNewest(256))")
                && gguf.contains("engine.cancel()")
                && gguf.contains("unloadForMemoryPressure")
                && gguf.contains("private var isUnloading = false")
                && gguf.contains("guard !isGenerating, !isUnloading else { return false }")
                && gguf.contains("prepareMemoryPressureUnload()")
                && gguf.contains("finishUnload()"),
            "The linked GGUF adapter must keep generation bounded, cancellable, and unloadable under memory pressure."
        )

        let textEventStream = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "private static func textEventStream(",
            endingBefore: "private func agentCoreProviderName"
        ))
        #expect(
            textEventStream.contains("ThinkTagStreamRouter()")
                && textEventStream.contains(".thinkingDelta(emit.thinking)")
                && textEventStream.contains(".textDelta(emit.visible)"),
            "June local text streams must surface real inline thinking tags as thinking.delta without showing them as answer text."
        )
        #expect(
            context.contains("private struct LocalHistoryBudget")
                && context.contains("private static func localHistoryBudget(for modelID: String)")
                && context.contains("private static func localContextTokens(for modelID: String)")
                && context.contains("localHistoryBudget(for: modelID).maxMessages")
                && gateway.contains("JuneAgentConversationContext.boundedHistory(store.loadMessages(sessionID: sessionID), for: modelID)")
                && context.contains("maxTranscriptCharacters: 2_400")
                && context.contains("replyBudgetTokens: 384")
                && gateway.contains("JuneAgentConversationContext.localReplyBudgetTokens(for: modelID)")
                && context.contains("private static func isLocalModelID")
                && context.contains("GGUFModelCatalog.entry(id: modelID) != nil"),
            "June local lanes must budget history and reply size from the selected model's context window; a one-size local cap can still overflow lower-context models."
        )
    }

    @Test("bounded local June streams fail visibly instead of dropping tokens")
    func appStoreJuneLocalStreamBackpressureIsFailClosed() throws {
        let engineContract = try loadMirroredSourceTextFile(
            "LocalPackages/EpistemosLlama/Sources/EpistemosLlama/LocalChatEngine.swift"
        )
        let engine = try loadMirroredSourceTextFile(
            "LocalPackages/EpistemosLlama/Sources/EpistemosLlama/LlamaLocalChatEngine.swift"
        )
        let gguf = try loadMirroredSourceTextFile(
            "Epistemos/QuickChat/LocalGGUFQuickChatBackend.swift"
        )
        let gateway = try loadMirroredSourceTextFile(
            "Epistemos/JuneAgent/JuneAgentGateway.swift"
        )
        let textEventStream = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "private static func textEventStream(",
            endingBefore: "private func agentCoreProviderName"
        ))

        #expect(engineContract.contains("case streamBackpressure"))
        #expect(engine.contains("case .dropped:"))
        #expect(engine.contains("LocalChatEngineError.streamBackpressure"))
        #expect(gguf.contains("case .dropped:"))
        #expect(gguf.contains("case .streamBackpressure:"))
        #expect(gguf.contains("Local model output could not keep up with its bounded stream buffer"))
        #expect(textEventStream.contains("case .dropped:"))
        #expect(textEventStream.contains("June could not keep up with the bounded local-model output stream"))
        #expect(!engine.contains("AsyncThrowingStream(bufferingPolicy: .unbounded"))
        #expect(!gguf.contains("AsyncThrowingStream(bufferingPolicy: .unbounded"))
        #expect(!textEventStream.contains("AsyncThrowingStream(bufferingPolicy: .unbounded"))
    }

    @Test("App Store June typography uses regular UI fonts except Matrix Dots display headers")
    func appStoreJuneTypographyUsesRegularUIFontsExceptMatrixDotsDisplayHeaders() throws {
        let surface = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentSurfaceView.swift")
        let overlay = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: surface,
            startingAt: "private static func juneOverlayScript()",
            endingBefore: "private static func juneFontFaceCSS()"
        ))
        let fontFace = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: surface,
            startingAt: "private static func juneFontFaceCSS()",
            endingBefore: "/// Pins navigation"
        ))

        #expect(
            overlay.contains(#"--epistemos-ui-font: "ABC Diatype""#)
                && overlay.contains(#"--epistemos-display-font: "Epistemos Matrix Dots""#)
                && overlay.contains("--font-sans: var(--epistemos-ui-font);")
                && overlay.contains("--font-serif: var(--epistemos-ui-font);")
                && overlay.contains("--font-mono: \"Berkeley Mono\""),
            "June's body/sidebar/composer typography should return to the regular June/system stack, with serif reset away from display fonts."
        )
        #expect(
            overlay.contains("html, body, button, input, textarea, select, [contenteditable]")
                && overlay.contains(".sidebar, .agent-composer, .agent-composer *")
                && overlay.contains("font-family: var(--epistemos-ui-font) !important;"),
            "The broad webview override must point to the regular UI font, not a pixel/display face."
        )
        #expect(
            overlay.contains(".agent-hero-title,")
                && overlay.contains(".folders-heading h1,")
                && overlay.contains(".note-title,")
                && overlay.contains(".folder-detail-title,")
                && overlay.contains(".folder-detail-title-input,")
                && overlay.contains(".welcome-title {")
                && overlay.contains("font-family: var(--epistemos-display-font) !important;"),
            "Matrix Dots should be scoped to the landing greeting and large page/editor headers only."
        )
        #expect(
            overlay.contains(".sidebar-brand::after")
                && overlay.contains("font-family: var(--epistemos-ui-font) !important;")
                && !overlay.contains("Epistemos Workspace Pixel"),
            "Sidebar/chrome labels must stay regular UI text instead of inheriting the display font."
        )
        #expect(
            fontFace.contains(#"font-family: "Epistemos Matrix Dots""#)
                && fontFace.contains("MatrixDotsDemoRegular")
                && !fontFace.contains("ChonkyPixels"),
            "June's MAS overlay must load the Matrix Dots display font resource, not the old all-over pixel face."
        )
    }

    @Test("App Store June selected GGUF lane is in-process and explicitly downloadable")
    func appStoreJuneSelectedGGUFLaneIsInProcessAndExplicitlyDownloadable() throws {
        let gguf = try loadMirroredSourceTextFile("Epistemos/QuickChat/LocalGGUFQuickChatBackend.swift")
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let controller = try loadMirroredSourceTextFile("Epistemos/QuickChat/QuickChatController.swift")
        let stage = try loadMirroredSourceTextFile("Epistemos/QuickChat/QuickChatStageView.swift")
        let models = try loadMirroredSourceTextFile("Epistemos/QuickChat/QuickChatModels.swift")
        let specificGGUFRoute = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "if let entry = GGUFModelCatalog.entry(id: modelID) {",
            endingBefore: "// Legacy/unknown local id"
        ))
        let legacyLocalFallback = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "// Legacy/unknown local id",
            endingBefore: "private static func textEventStream"
        ))
        let prepareSelectedModel = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "private func prepareSelectedModel(_ id: String)",
            endingBefore: "func modelsPayload()"
        ))

        #expect(
            gguf.hasPrefix("#if EPISTEMOS_APP_STORE\nimport EpistemosLlama\n#endif")
                && gguf.contains("var isAvailableInThisBuild: Bool { true }")
                && gguf.contains("private let engine = LlamaLocalChatEngine()")
                && gguf.contains("GGUFModelCatalog.installedURL(for: entry)")
                && gguf.contains(".noLocalModelInstalled")
                && !gguf.contains("llama_decode")
                && !gguf.contains("llama_backend")
                && !gguf.contains("LlamaContext"),
            "The App Store GGUF seam must bind only the in-process facade; raw llama calls stay inside the pinned package."
        )
        #expect(
            gateway.contains("if localGGUF.isAvailableInThisBuild {\n            ids.append(contentsOf: GGUFModelCatalog.installedEntries().map(\\.id))")
                && gateway.contains("if localGGUF.isAvailableInThisBuild {\n            ids.append(contentsOf: GGUFModelCatalog.entries.map(\\.id))")
                && gateway.contains("localGGUFAvailable: localGGUF.isAvailableInThisBuild"),
            "June model lists must surface the selected GGUF catalog only through the linked backend."
        )
        #expect(
            specificGGUFRoute.contains("guard localGGUF.isAvailableInThisBuild else")
                && specificGGUFRoute.range(of: "guard localGGUF.isAvailableInThisBuild else")!.lowerBound
                    < specificGGUFRoute.range(of: "downloads.beginDownload(entry)")!.lowerBound,
            "A selected GGUF model must pass runtime availability before June starts its model-data download."
        )
        #expect(
            legacyLocalFallback.contains("guard localGGUF.isAvailableInThisBuild else")
                && legacyLocalFallback.contains("Local GGUF chat isn't available in this build")
                && !legacyLocalFallback.contains("makeAgentCoreCloudStream"),
            "Legacy local ids must stay on-device and never silently reroute to cloud."
        )
        #expect(
            prepareSelectedModel.contains("guard localGGUF.isAvailableInThisBuild else { return }")
                && prepareSelectedModel.range(of: "guard localGGUF.isAvailableInThisBuild else { return }")!.lowerBound
                    < prepareSelectedModel.range(of: "downloads.beginDownload(entry)")!.lowerBound,
            "Selecting GGUF must pass linked-runtime and memory gates before starting a model-data download."
        )
        #expect(
            !landing.contains("QuickChatStageView(")
                && !landing.contains("quickChatController")
                && !landing.contains("showLandingInlineCommand(.quickChat)")
                && !landing.contains(#"title: "ask""#)
                && controller.hasPrefix("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)")
                && stage.hasPrefix("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"),
            "Landing must not expose or compile in the old quick-chat transcript surface for MAS."
        )
        #expect(
            models.contains("No selected June local model is installed yet. Open June's model settings to download one."),
            "Missing-model copy must direct users to June's active local-model picker."
        )
    }

    @Test("App Store June per-message Prompt Forge is disabled and submit stays literal")
    func appStoreJunePerMessagePromptForgeIsDisabledAndSubmitStaysLiteral() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let promptForgeCase = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: #"case "prompt.forge_preview":"#,
            endingBefore: #"case "prompt.submit":"#
        ))
        let promptSubmitCase = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: #"case "prompt.submit":"#,
            endingBefore: #"case "session.interrupt":"#
        ))

        #expect(
            promptForgeCase.contains("Per-message Prompt Forge is disabled in the App Store build")
                && promptForgeCase.contains("Send keeps your prompt unchanged")
                && promptForgeCase.contains("replyError")
                && !promptForgeCase.contains("JunePromptForge")
                && !promptForgeCase.contains("Task.detached")
                && !gateway.contains("private let promptForge"),
            "The MAS gateway must reject stale per-message prompt-upgrade calls instead of doing hidden Prompt Forge work."
        )
        #expect(
            promptSubmitCase.contains("startTurn(sessionID: sessionID, prompt: text, requestedModelID: requestedModel)")
                && !promptSubmitCase.contains("promptForge")
                && !promptSubmitCase.contains("forge_preview"),
            "Normal June prompt.submit must pass the submitted text directly into the turn without invoking Prompt Forge."
        )
    }

    @Test("App Store June System Prompt Forge is disabled and never composes into turns")
    func appStoreJuneSystemPromptForgeIsDisabledAndNeverComposesIntoTurns() throws {
        let bridge = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentBridge.swift")
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let context = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentConversationContext.swift")
        let forge = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneSystemPromptForge.swift")
        let previewHandler = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: bridge,
            startingAt: "private func handleSystemPromptForgePreviewInvoke",
            endingBefore: "    private func handleGetNoteInvoke"
        ))
        let runtimeLayer = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: forge,
            startingAt: "static func runtimeLayer",
            endingBefore: "    private static func boundedPrompt"
        ))

        #expect(
            bridge.contains(#"cmd == "system_prompt_forge_preview""#)
                && bridge.contains("handleSystemPromptForgePreviewInvoke")
                && bridge.contains("JuneSystemPromptForge.previewPayload"),
            "Legacy System Prompt Forge commands may remain as compatibility stubs, but they must route to the disabled native shim."
        )
        #expect(
            previewHandler.contains("activeVaultURL: nil")
                && previewHandler.contains("resolveInvoke(callId: callId, result: payload.dictionary)")
                && !previewHandler.contains("Task.detached")
                && !previewHandler.contains("activeVaultURL()"),
            "The disabled preview path must not do background Prompt Forge work or active-vault grounding."
        )
        #expect(
            bridge.contains(#"case "system_prompt_forge_settings":"#)
                && bridge.contains(#"case "system_prompt_forge_save":"#)
                && bridge.contains(#"case "system_prompt_forge_reset":"#)
                && bridge.contains("JuneSystemPromptForge.savePayload"),
            "Settings/save/reset commands must stay stable for old web bundles while returning disabled payloads."
        )
        #expect(
            forge.contains(#"static let mode = "System Prompt Forge disabled in MAS""#)
                && forge.contains(#""disabled": true"#)
                && forge.contains("upgradedText: original")
                && forge.contains("changed: false")
                && forge.contains("patternsApplied: []")
                && forge.contains("citations: []"),
            "System Prompt Forge responses must report disabled/no-change payloads."
        )
        #expect(
            forge.contains("clearState()")
                && forge.contains("system-prompt-forge.json")
                && !forge.contains("try data.write")
                && !forge.contains("UserDefaults.standard"),
            "Save/reset must remove stale accepted layers instead of persisting new prompt-upgrade state."
        )
        #expect(
            runtimeLayer.contains("static func runtimeLayer(isLocal _: Bool) -> String")
                && runtimeLayer.contains("\"\"")
                && !forge.contains("<accepted_behavior>")
                && !forge.contains("JunePromptForge().previewPayload")
                && !forge.contains("modelID: JuneModelID.cloud"),
            "The runtime layer must be empty and must not retain dormant Prompt Forge upgrade work."
        )
        #expect(
            gateway.contains("JuneAgentConversationContext.localInstructions")
                && gateway.contains("JuneAgentConversationContext.agentCloudInstructions")
                && context.contains("behaviorBase(localBaseInstructions, isLocal: true)")
                && context.contains("behaviorBase(agentCloudBaseInstructions, isLocal: false)")
                && context.contains("JuneSystemPromptForge.runtimeLayer(isLocal: isLocal)"),
            "June may keep the behaviorBase seam, but the MAS System Prompt Forge shim must return no layer."
        )
    }

    @Test("App Store June approval responses require exact request ids")
    func appStoreJuneApprovalResponsesRequireExactRequestIDs() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let approvals = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentApprovalRegistry.swift")
        let toolBounds = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneToolEventBounds.swift")
        let approvalCase = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: #"case "approval.respond":"#,
            endingBefore: #"case "command.dispatch":"#
        ))
        let popHelper = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: approvals,
            startingAt: "func popPendingApprovalID",
            endingBefore: "@MainActor\n    func denyPendingApprovals"
        ))

        #expect(
            approvalCase.contains(#"let requestID = params["request_id"] as? String"#)
                && approvalCase.contains("JuneToolEventBounds.isBoundedToolProtocolID(requestID)")
                && toolBounds.contains("static let maxToolEventIDBytes = 128")
                && toolBounds.contains("value.utf8.count <= maxToolEventIDBytes")
                && toolBounds.contains("value.rangeOfCharacter(from: .controlCharacters) == nil")
                && approvalCase.contains("session_id, request_id, and bounded choice required"),
            "June approval responses must include a bounded native request_id before the agent is resumed."
        )
        #expect(
            popHelper.contains("func popPendingApprovalID(sessionID: String, requestID: String) -> Bool")
                && popHelper.contains("pending.sessionID == sessionID")
                && popHelper.contains("pendingApprovals.removeValue(forKey: requestID)")
                && !popHelper.contains("removeFirst()"),
            "The MAS gateway must resume only the exact approval request for the exact session, never the oldest pending approval."
        )
    }

    @Test("App Store June MAS tool policy is the single Swift allowlist authority")
    func appStoreJuneMASToolPolicyIsSingleSwiftAllowlistAuthority() throws {
        let policy = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneMASToolPolicy.swift")
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let allowlist = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: policy,
            startingAt: "static let allowedAgentToolNames: [String] = {",
            endingBefore: "static let allowedObservableCompositionToolNames"
        ))

        for required in [
            "vault.search",
            "vault.read",
            "vault.write",
            "vault.list",
            "pdf.to_markdown",
            "knowledge.recall",
            "web.search",
            "web.fetch",
            "http_fetch",
            "think",
        ] {
            #expect(allowlist.contains(#""\#(required)""#), "MAS June tool policy must include \(required)")
        }
        for forbidden in [
            "action.bash",
            "browser_use",
            "cli_passthrough",
            "code_execution",
            "computer_use",
            "delegate_task",
            "mcp_call",
            "process",
            "run_command",
            "shell",
            "stdio_mcp",
            "subprocess",
            "system.process",
            "terminal",
        ] {
            #expect(!allowlist.contains(#""\#(forbidden)""#), "MAS June tool policy must not include \(forbidden)")
        }
        #expect(
            policy.contains("precondition(")
                && policy.contains("names.allSatisfy(Self.isMASPermittedAgentToolName)")
                && policy.contains("forbiddenNameFragments")
                && policy.contains("containsForbiddenPackagedRuntimeName(normalized)")
                && policy.contains("matchedPrefixLength")
                && !policy.contains("dockerFragment"),
            "The MAS June tool policy must fail closed if a future allowlist edit adds parked runtime/tool names without materializing prohibited artifact strings."
        )
        #expect(
            gateway.contains("private nonisolated static let observableCompositionTools = JuneMASToolPolicy.allowedObservableCompositionToolNames")
                && gateway.contains("JuneMASToolPolicy.isAllowedAgentToolName(name)")
                && !gateway.contains(#"private nonisolated static let observableCompositionTools: Set<String> = ["#),
            "June's composition observer must use the same allowlist as execution so provenance cannot learn tools the MAS agent cannot run."
        )
    }

    @Test("App Store Settings has no extension installer or hosted MCP route")
    func appStoreSettingsHasNoExtensionInstallerOrHostedMCPRoute() throws {
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")

        let visibleSections = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: settings,
            startingAt: "static var visibleSections: [SettingsSection] {",
            endingBefore: "static func safeDetailSelection"
        ))
        let safeSelection = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: settings,
            startingAt: "static func safeDetailSelection",
            endingBefore: "var icon: String"
        ))
        let settingsDetail = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: settings,
            startingAt: "private var settingsDetail: some View",
            endingBefore: "private func toggleSidebar"
        ))

        #expect(
            !visibleSections.contains(".skills"),
            "App Store Settings must not include Extensions in the unconditional sidebar list."
        )
        #expect(
            safeSelection.contains("return visibleSections.contains(section) ? section : .general"),
            "Deep links to Extensions must resolve to a MAS-safe settings section in App Store builds."
        )
        #expect(
            settingsDetail.contains("case .skills: GeneralDetailView()")
                && !settingsDetail.contains("ExtensionsDetailView"),
            "The MAS settings detail switch must not reference the extension installer view as the active .skills destination."
        )
    }

    @Test("App Store project excludes parked runtime resources before scrub")
    func appStoreProjectExcludesParkedRuntimeResourcesBeforeScrub() throws {
        let project = try loadMirroredSourceTextFile("project.yml")
        let pbxproj = try loadMirroredSourceTextFile("Epistemos.xcodeproj/project.pbxproj")
        let appStoreTarget = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: project,
            startingAt: "  Epistemos-AppStore:",
            endingBefore: "  # AR1"
        ))
        let appStorePBXTarget = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: pbxproj,
            startingAt: "\t\tD30E77DBB7C16B42612B2335 /* Epistemos-AppStore */ = {",
            endingBefore: "/* End PBXNativeTarget section */"
        ))
        func appStorePBXPhaseID(named name: String) throws -> String {
            let phaseLine = try #require(appStorePBXTarget
                .components(separatedBy: .newlines)
                .first { $0.contains("/* \(name) */") })
            return try #require(phaseLine
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ")
                .first)
                .description
        }
        func pbxObjectBlock(id: String, name: String) throws -> String {
            try #require(AppStoreJuneSourceGuard.sourceSection(
                in: pbxproj,
                startingAt: "\t\t\(id) /* \(name) */ = {",
                endingBefore: "\n\t\t};"
            ))
        }
        let appStoreBuildRustPhase = try pbxObjectBlock(
            id: appStorePBXPhaseID(named: "Build Rust Engine"),
            name: "Build Rust Engine"
        )
        let appStoreRuntimeAssetsPhase = try pbxObjectBlock(
            id: appStorePBXPhaseID(named: "Bundle Runtime Assets"),
            name: "Bundle Runtime Assets"
        )
        let appStoreEpistemosSyncedGroupException = try #require(
            pbxproj
                .components(separatedBy: "/* PBXFileSystemSynchronizedBuildFileExceptionSet */ = {")
                .first {
                    $0.contains("target = D30E77DBB7C16B42612B2335 /* Epistemos-AppStore */;")
                        && $0.contains("Engine/ClaudeManagedRuntime.swift")
                }
        )
        let effectivePBXExceptions = Set(appStoreEpistemosSyncedGroupException
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasSuffix(",") }
            .map { String($0.dropLast()) })

        for requiredYAMLSourceExclude in [
            "ExperimentalAgent/ExperimentalGlassHostView.swift",
            "ExperimentalAgent/ExperimentalHostBridge.swift",
            "ExperimentalAgent/ExperimentalPerf.swift",
            "ExperimentalAgent/ExperimentalRuntimeSupervisor.swift",
            "ExperimentalAgent/ExperimentalStateBridge.swift",
            "ExperimentalAgent/ExperimentalSurfaceView.swift",
            "ExperimentalAgent/ExperimentalThemeBridge.swift",
            "Goose/GooseACPClient.swift",
            "Goose/GooseACPProtocol.swift",
            "Goose/GooseACPSourceProtocol.swift",
            "Goose/GooseInProcessACPServer.swift",
            "Goose/GooseProcessDiagnostics.swift",
            "Goose/GooseProviderKeyBridge.swift",
            "Goose/GooseRuntimeSupervisor.swift",
            "VaultMCP/VaultMCPCore.swift",
            "VaultMCP/VaultMCPHost.swift",
            "VaultMCP/VaultMCPServer.swift",
            "VaultMCP/VaultMCPTokenStore.swift",
            "Views/Settings/CLIDiscoveryHealthRow.swift",
            "Views/Settings/VaultMCPServerSettingsRow.swift",
            "Work/WorkAppContextSnapshot.swift",
            "Work/WorkNativeMCPServer.swift",
            "Work/WorkNativeToolExecutor.swift",
            "Work/WorkOpenCodeRuntime.swift",
            "Work/WorkPromptForgeContext.swift",
            "Work/WorkServerDiagnostics.swift",
            "Work/WorkSkillsProvisioner.swift",
            "Work/WorkToolMCPCore.swift",
            "Resources/Pyodide/**",
            "Resources/experimental-runtime/**",
            "Resources/opencode-runtime/**",
        ] {
            #expect(
                appStoreTarget.contains(requiredYAMLSourceExclude),
                "project.yml must keep \(requiredYAMLSourceExclude) out of the App Store synced source group."
            )
        }

        for requiredYAMLResourceExclude in [
            "Pyodide/**",
            "experimental-runtime/**",
            "opencode-runtime/**",
        ] {
            #expect(
                appStoreTarget.contains(requiredYAMLResourceExclude),
                "project.yml must keep \(requiredYAMLResourceExclude) out of App Store resources."
            )
        }

        #expect(
            appStorePBXTarget.contains("/* Build Rust Engine */")
                && appStorePBXTarget.contains("/* Bundle Runtime Assets */")
                && appStorePBXTarget.contains("/* Scrub Pro Frameworks */")
                && !appStorePBXTarget.contains("Bundle Test Source Mirror"),
            "The effective App Store app target must not inherit test-only source mirror phases."
        )
        #expect(
            appStoreBuildRustPhase.contains("MAS_SANDBOX=1 bash")
                && appStoreBuildRustPhase.contains("build-agent-core.sh")
                && !appStoreBuildRustPhase.contains("build-opencode-runtime.sh")
                && !appStoreBuildRustPhase.contains("build-experimental-web.sh"),
            "The effective App Store build phase must build MAS agent_core without staging parked OpenCode or Experimental runtimes."
        )
        #expect(
            appStoreRuntimeAssetsPhase.contains("bundle-app-runtime-assets.sh"),
            "The effective App Store runtime-assets phase must run the scrubber after resources are staged."
        )

        for requiredPBXException in [
            "ExperimentalAgent/ExperimentalGlassHostView.swift",
            "ExperimentalAgent/ExperimentalHostBridge.swift",
            "ExperimentalAgent/ExperimentalPerf.swift",
            "ExperimentalAgent/ExperimentalRuntimeSupervisor.swift",
            "ExperimentalAgent/ExperimentalStateBridge.swift",
            "ExperimentalAgent/ExperimentalSurfaceView.swift",
            "ExperimentalAgent/ExperimentalThemeBridge.swift",
            "Goose/GooseACPClient.swift",
            "Goose/GooseACPProtocol.swift",
            "Goose/GooseACPSourceProtocol.swift",
            "Goose/GooseInProcessACPServer.swift",
            "Goose/GooseProcessDiagnostics.swift",
            "Goose/GooseProviderKeyBridge.swift",
            "Goose/GooseRuntimeSupervisor.swift",
            "VaultMCP/VaultMCPCore.swift",
            "VaultMCP/VaultMCPHost.swift",
            "VaultMCP/VaultMCPServer.swift",
            "VaultMCP/VaultMCPTokenStore.swift",
            "Views/Settings/CLIDiscoveryHealthRow.swift",
            "Views/Settings/VaultMCPServerSettingsRow.swift",
            "Work/WorkAppContextSnapshot.swift",
            "Work/WorkNativeMCPServer.swift",
            "Work/WorkNativeToolExecutor.swift",
            "Work/WorkOpenCodeRuntime.swift",
            "Work/WorkPromptForgeContext.swift",
            "Work/WorkServerDiagnostics.swift",
            "Work/WorkSkillsProvisioner.swift",
            "Work/WorkToolMCPCore.swift",
            "\"Resources/Pyodide/README.md\"",
            "\"Resources/Pyodide/package.json\"",
            "\"Resources/Pyodide/pyodide-lock.json\"",
            "\"Resources/Pyodide/pyodide.asm.mjs\"",
            "\"Resources/Pyodide/pyodide.asm.wasm\"",
            "\"Resources/Pyodide/pyodide.js\"",
            "\"Resources/Pyodide/pyodide.mjs\"",
            "\"Resources/Pyodide/python_stdlib.zip\"",
            "\"Resources/experimental-runtime/bin/codex\"",
            "\"Resources/experimental-runtime/bin/node\"",
            "\"Resources/experimental-runtime/bin/rg\"",
            "\"Resources/experimental-runtime/experimental-web.tar.gz\"",
            "\"Resources/opencode-runtime/.bun-1.3.14-bun-darwin-aarch64\"",
            "\"Resources/opencode-runtime/.opencode-1.17.9-opencode-darwin-arm64\"",
            "\"Resources/opencode-runtime/bin/bun\"",
            "\"Resources/opencode-runtime/bin/omega_mcp_stdio\"",
            "\"Resources/opencode-runtime/bin/opencode\"",
        ] {
            #expect(
                effectivePBXExceptions.contains(requiredPBXException),
                "The effective Xcode project must exclude \(requiredPBXException) before bundle scrub runs."
            )
        }

        for ineffectiveDirectoryException in [
            "Resources/Pyodide",
            "\"Resources/experimental-runtime\"",
            "\"Resources/opencode-runtime\"",
        ] {
            #expect(
                !effectivePBXExceptions.contains(ineffectiveDirectoryException),
                "The App Store synced group must not rely on broad directory exceptions that Xcode still copies."
            )
        }
    }

    @Test("App Store compile-parks Work/OpenCode and Vault MCP executable local-server surfaces")
    func appStoreCompileParksWorkOpenCodeAndVaultMCPExecutableSurfaces() throws {
        let guardedSourcePaths = [
            "Epistemos/Work/WorkOpenCodeRuntime.swift",
            "Epistemos/Work/WorkNativeMCPServer.swift",
            "Epistemos/Work/WorkNativeToolExecutor.swift",
            "Epistemos/Work/WorkToolMCPCore.swift",
            "Epistemos/Work/WorkServerDiagnostics.swift",
            "Epistemos/Work/WorkSkillsProvisioner.swift",
            "Epistemos/Work/WorkAppContextSnapshot.swift",
            "Epistemos/Work/WorkPromptForgeContext.swift",
            "Epistemos/VaultMCP/VaultMCPCore.swift",
            "Epistemos/VaultMCP/VaultMCPHost.swift",
            "Epistemos/VaultMCP/VaultMCPServer.swift",
            "Epistemos/VaultMCP/VaultMCPTokenStore.swift",
            "Epistemos/Views/Settings/VaultMCPServerSettingsRow.swift",
        ]

        for path in guardedSourcePaths {
            let source = try loadMirroredSourceTextFile(path)
            let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(
                trimmed.hasPrefix("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"),
                "\(path) must compile-park its executable runtime surface in App Store/MAS Sandbox builds."
            )
            #expect(
                trimmed.hasSuffix("#endif"),
                "\(path) guard must close at EOF so no local-server/runtime helper leaks back into MAS."
            )
        }

        let registration = try loadMirroredSourceTextFile("Epistemos/Work/WorkNativeMCPRegistration.swift")
        let shell = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenCodeShell.swift")
        let runtime = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenCodeRuntime.swift")

        #expect(
            registration.contains("App Store builds keep this")
                && registration.contains("static let mcpPath = \"/mcp\"")
                && !registration.contains("NWListener")
                && !registration.contains("WorkToolMCPCore")
                && !registration.contains("WorkNativeMCPServer.mcpPath"),
            "MAS may keep the registration as inert validation data, but not a transport/server dependency."
        )
        #expect(
            shell.hasPrefix("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)")
                && shell.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("#endif"),
            "The OpenCode shell seam must be compile-parked for either MAS compile flag."
        )
        #expect(
            !runtime.contains("nonisolated struct WorkNativeMCPRegistration"),
            "The shared registration value must stay outside the parked OpenCode runtime file."
        )
    }

    @Test("App Store compile-parks Goose ACP local server but keeps June agent_core runner")
    func appStoreCompileParksGooseACPLocalServer() throws {
        let goose = try loadMirroredSourceTextFile("Epistemos/Goose/GooseInProcessACPServer.swift")
        let acpClient = try loadMirroredSourceTextFile("Epistemos/Goose/GooseACPClient.swift")
        let providerKeyBridge = try loadMirroredSourceTextFile("Epistemos/Goose/GooseProviderKeyBridge.swift")
        let masSupervisor = try loadMirroredSourceTextFile("Epistemos/Goose/GooseMASRuntimeSupervisor.swift")
        let directSupervisor = try loadMirroredSourceTextFile("Epistemos/Goose/GooseRuntimeSupervisor.swift")
        let serverGuard = try #require(goose.range(of: "#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"))
        let serverClass = try #require(goose.range(
            of: "nonisolated final class GooseInProcessACPServer",
            range: serverGuard.upperBound..<goose.endIndex
        ))
        let directSupervisorBranch = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: directSupervisor,
            startingAt: "#else // !(EPISTEMOS_APP_STORE || MAS_SANDBOX)",
            endingBefore: "#endif // !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"
        ))

        #expect(
            serverGuard.lowerBound < serverClass.lowerBound
                && goose.contains("nonisolated enum GooseInProcessACPFraming")
                && goose.contains("nonisolated struct GooseInProcessACPHTTPRequest"),
            "The legacy ACP server, websocket framing, and HTTP parser must remain direct-lane guarded for non-AppStore builds."
        )
        #expect(
            acpClient.hasPrefix("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\nimport Foundation")
                && acpClient.contains("GooseACPURLSessionWebSocketTransport")
                && acpClient.contains("URLSessionWebSocketTask")
                && providerKeyBridge.hasPrefix("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\nimport Foundation")
                && providerKeyBridge.contains("syncConfiguredProviderKeys(to client: GooseACPClient)"),
            "The Goose ACP WebSocket client and provider-key bridge are parked-lane support and must not compile into MAS."
        )
        #expect(
            masSupervisor.contains("final class GooseRuntimeSupervisor")
                && masSupervisor.contains("Goose runtime/surface is parked in the App Store build")
                && masSupervisor.contains("Use MAS June / Epdoc Assist.")
                && masSupervisor.contains("var acpWebSocketURL: URL? { nil }")
                && masSupervisor.contains("nonisolated static func acpWebSocketURL")
                && !masSupervisor.contains("GooseInProcessACPServer")
                && !masSupervisor.contains("runInProcessAgentCore")
                && !masSupervisor.contains(#"components.path += "/acp""#)
                && !masSupervisor.contains("EPISTEMOS_GOOSE_BACKEND")
                && !masSupervisor.contains("GooseSpawnBox")
                && !masSupervisor.contains("Process()")
                && !masSupervisor.contains("URLSession"),
            "The App Store supervisor must stay in a MAS-safe source file that cannot start, URL-build, or reference the parked ACP local server."
        )
        #expect(
            directSupervisorBranch.contains(#"components.path += "/acp""#)
                && directSupervisorBranch.contains("EPISTEMOS_GOOSE_BACKEND")
                && directSupervisorBranch.contains("GooseSpawnBox")
                && directSupervisorBranch.contains("Process()"),
            "Direct Goose subprocess and ACP URL construction must stay behind the non-MAS supervisor branch."
        )
    }

    @Test("Free V1 HTML Workspace regenerate stays hidden and cannot execute")
    func freeV1HTMLWorkspaceRegenerateStaysHiddenAndCannotExecute() throws {
        let editor = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        let regeneration = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorRegeneration.swift")

        let toolbarRegenerate = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: editor,
            startingAt: "#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\n            if ProductCapabilityPolicy.allowsHTMLWorkspaceRegeneration {\n                Button {\n                    openRegenerateSheet()",
            endingBefore: "Menu {"
        ))
        #expect(
            toolbarRegenerate.contains("if ProductCapabilityPolicy.allowsHTMLWorkspaceRegeneration {")
                && toolbarRegenerate.contains("Label(\"Regenerate\", systemImage: isRegenerating ? \"hourglass\" : \"wand.and.sparkles\")"),
            "The HTML Workspace Regenerate button must stay out of Free V1 even outside the App Store compile lane."
        )
        #expect(
            editor.contains("private var regenerateSheetBinding: Binding<Bool>")
                && editor.contains(".sheet(isPresented: regenerateSheetBinding)"),
            "A stale programmatic state change must not present the paid regenerate sheet in Free V1."
        )

        for marker in [
            "func openRegenerateSheet()",
            "func startRegenerateWithContextDirective(",
            "func runRegeneratePreset(",
            "func beginRegenerateSurfaceAttachingContextIfNeeded(",
            "func beginRegenerateSurface(instructionOverride:",
            "func copyRegeneratePrompt()",
            "func previewRegenerateStreamText()",
            "func applyPendingRegeneratePreview()",
            "func applyRegenerateStreamText()",
        ] {
            let body = try #require(AppStoreJuneSourceGuard.sourceSection(
                in: regeneration,
                startingAt: marker,
                endingBefore: "\n    func "
            ))
            #expect(
                body.contains("guard ProductCapabilityPolicy.allowsHTMLWorkspaceRegeneration else {")
                    && body.contains("parkRegenerateForUnavailableEdition()"),
                "\(marker) must park immediately when the paid regeneration capability is unavailable."
            )
        }

        let beginSurface = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: regeneration,
            startingAt: "func beginRegenerateSurface(instructionOverride:",
            endingBefore: "func clearPendingRegeneratePreview()"
        ))
        let parkRange = try #require(beginSurface.range(of: "parkRegenerateForUnavailableEdition()"))
        let streamRange = try #require(beginSurface.range(of: "gooseRegenerator.streamRegeneration("))
        #expect(
            parkRange.lowerBound < streamRange.lowerBound,
            "The Free V1 capability guard must precede the Goose-backed stream path in beginRegenerateSurface."
        )
        #expect(
            regeneration.contains("HTML Workspace regenerate is reserved for a future paid edition."),
            "Free V1 should state the honest paid-edition boundary without pointing users to another hidden AI surface."
        )
    }

    @Test("Free V1 debug launch cannot request the hidden agent page")
    func freeV1DebugLaunchCannotRequestHiddenAgentPage() throws {
        let landing = try loadMirroredSourceTextFile("Epistemos/Views/Landing/LandingView.swift")
        let debugLaunch = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: landing,
            startingAt: "#if DEBUG && !EPISTEMOS_APP_STORE",
            endingBefore: "#endif"
        ))

        #expect(
            debugLaunch.contains("if ProductCapabilityPolicy.isAvailable(.june),")
                && debugLaunch.contains("EPISTEMOS_OPEN_AGENT_ON_LAUNCH")
                && debugLaunch.contains("ui.homeContent = .agent"),
            "The debug-only agent launch switch must obey the same paid June policy as the landing route."
        )
    }

    @Test("App Store June nav exposes native Notes browser popover")
    func appStoreJuneNavExposesNativeNotesBrowserPopover() throws {
        let nav = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentNavBar.swift")
        let notesBrowser = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NotesBrowserView.swift")
        let sidebar = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NotesSidebar.swift")
        let popover = try loadMirroredSourceTextFile("Epistemos/Views/Shared/AppKitPopover.swift")

        #expect(
            nav.contains("@State private var showingNotes = false")
                && nav.contains(#"Image(systemName: "sidebar.leading")"#)
                && nav.contains(#"Text("Notes")"#)
                && nav.contains("showingNotes = true")
                && nav.contains(".appKitPopover(isPresented: $showingNotes, behavior: .semitransient)")
                && nav.contains("JuneNotesBrowserPopover()")
                && nav.contains("Browse and search notes"),
            "June needs a clear Notes toolbar button that opens a native popover instead of leaving note browsing hidden behind empty bridge no-ops."
        )
        #expect(
            nav.contains("NotesBrowserView()")
                && nav.contains(".withAppEnvironment(bootstrap)")
                && nav.contains(".modelContainer(bootstrap.modelContainer)")
                && notesBrowser.contains("SidebarShell(allPages: allPages, allFolders: allFolders)")
                && sidebar.contains(#"TextField("Search notes...", text: $notesUI.searchQuery)"#)
                && sidebar.contains("notesUI.collapseAllFolders()")
                && sidebar.contains("NoteWindowManager.shared.open(pageId: pageId"),
            "The June Notes popover must reuse the real Notes sidebar with search, folder expand/collapse, scrolling, and existing note-open behavior."
        )
        #expect(
            popover.contains("let popover = NSPopover()")
                && popover.contains("var behavior: NSPopover.Behavior")
                && popover.contains("behavior: NSPopover.Behavior = .transient")
                && popover.contains("popover.behavior = behavior")
                && !nav.contains("UtilityWindowManager.shared.show(.notes)"),
            "June should use the AppKit NSPopover path for this toolbar affordance, not the detached utility NSPanel."
        )
        let retiredMainChatMentionsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Epistemos/Views/Chat/NotesMentionDropdown.swift")
        #expect(
            !FileManager.default.fileExists(atPath: retiredMainChatMentionsURL.path)
                && nav.contains("behavior: .semitransient"),
            "The retired chat reference popover must stay absent while the independent June Notes popover keeps its native dismissal behavior."
        )
        #expect(
            nav.contains("@State private var speech = EpistemosSpeechSynthesizer.shared")
                && nav.contains("@Environment(UIState.self) private var ui")
                && nav.contains("@State private var kokoroDownloader = KokoroModelDownloadService.shared")
                && nav.contains("@State private var showingKokoroInstallPrompt = false")
                && nav.contains("EpistemosSpeechSynthesizer.isTextToSpeechAvailable()")
                && nav.contains("KokoroVoiceInstallPrompt()")
                && nav.contains(".environment(ui)")
                && nav.contains("showingKokoroInstallPrompt = true")
                && nav.contains("KokoroVoiceInstallPresentation.installSystemImage")
                && nav.contains("KokoroVoiceInstallPresentation.installHelp(")
                && nav.contains("KokoroVoiceInstallPresentation.unavailableAccessibilityLabel")
                && nav.contains("refreshReadAloudAvailability()")
                && nav.contains("window.__EPISTEMOS_READALOUD_REFRESH__")
                && !nav.contains(".disabled(!ttsAvailable && !speech.isSpeaking)")
                && nav.contains("JuneAgentSurfaceHolder.shared.bridge?.gateway.latestAssistantReply()")
                && nav.contains("speech.stop()")
                && nav.contains("EpistemosAgentReadAloud.readVisibleSurface(")
                && nav.contains("preferred: .juneLatestAssistantReply"),
            "Adding the native Notes popover must not regress the June read-aloud toolbar control or turn missing Kokoro into a dead disabled button."
        )
    }

    @Test("App Store June gateway echoes only bounded JSON-RPC ids")
    func appStoreJuneGatewayEchoesOnlyBoundedJSONRPCIDs() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let gatewayTypes = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneGatewayTypes.swift")
        let handleFrame = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "func handleFrame(_ raw: String)",
            endingBefore: "private func startTurn"
        ))
        let replyID = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gatewayTypes,
            startingAt: "nonisolated enum JuneGatewayReplyID",
            endingBefore: "nonisolated enum JuneEngineErrorText"
        ))

        #expect(
            handleFrame.contains(#"JuneGatewayReplyID(rawValue: frame["id"])"#)
                && handleFrame.contains("gateway frame rejected invalid json-rpc id")
                && handleFrame.contains("let id = rpcReplyID.jsonValue")
                && handleFrame.contains("let previewReplyID = rpcReplyID")
                && handleFrame.contains("self?.reply(id: previewReplyID.jsonValue")
                && !handleFrame.contains("let id = frame[\"id\"]")
                && !handleFrame.contains("JuneGatewayReplyID(id)"),
            "June gateway JSON-RPC replies must echo only sanitized ids, including async Prompt Forge responses."
        )
        #expect(
            replyID.contains("private static let maxStringBytes = 256")
                && replyID.contains("private static let maxSafeNumericMagnitude")
                && replyID.contains("init?(rawValue: Any?)")
                && replyID.contains("string.utf8.count <= Self.maxStringBytes")
                && replyID.contains("CFGetTypeID(number) != CFBooleanGetTypeID()")
                && replyID.contains("double.isFinite")
                && replyID.contains("abs(double) <= Self.maxSafeNumericMagnitude")
                && replyID.contains("return nil"),
            "JuneGatewayReplyID must reject oversized strings, booleans, non-finite numbers, unsafe magnitudes, and non-scalar ids before echoing into JS."
        )
    }

    @Test("App Store June bridge bounds session metadata and rejects model-sync failure")
    func appStoreJuneBridgeBoundsSessionMetadataAndRejectsModelSyncFailure() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentBridge.swift")
        let invokeCase = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: source,
            startingAt: "case Self.invokeChannel:",
            endingBefore: "case Self.eventsChannel:"
        ))
        let ensureBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: source,
            startingAt: "private func handleEnsureHermesBridgeSessionInvoke",
            endingBefore: "private func handleSetVeniceModelInvoke"
        ))

        #expect(
            invokeCase.contains(#"if cmd == "ensure_hermes_bridge_session" {"#)
                && invokeCase.contains("handleEnsureHermesBridgeSessionInvoke(callId: callId, args: args)")
                && ensureBody.contains("Self.boundedTitle(title)")
                && source.contains("private static func boundedTitle")
                && source.contains("prefix(160)")
                && ensureBody.contains("guard gateway.setSessionModel(model, for: sessionID) else")
                && ensureBody.contains("gateway.modelSelectionFailureMessage(model)")
                && ensureBody.contains("rejectInvoke(callId: callId")
                && !source.contains("_ = gateway.setSessionModel(model, for: sessionID)"),
            "June session ensure must bound titles and reject an exact-model sync failure instead of silently retaining the old model."
        )
    }

    @Test("App Store June bridge validates invoke call ids and payload size")
    func appStoreJuneBridgeValidatesInvokeCallIDsAndPayloadSize() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentBridge.swift")
        let invokeCase = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: source,
            startingAt: "case Self.invokeChannel:",
            endingBefore: "case Self.eventsChannel:"
        ))
        let validationHelpers = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: source,
            startingAt: "private static func validatedInvokeCallID",
            endingBefore: "private func handleSpeak"
        ))

        #expect(
            source.contains("private static let maxInvokeCommandBytes = 128")
                && source.contains("private static let maxInvokePayloadBytes = 1_000_000")
                && source.contains("private static let maxSafeJavaScriptInteger")
                && invokeCase.contains(#"Self.validatedInvokeCallID(body["callId"])"#)
                && invokeCase.contains("cmd.utf8.count <= Self.maxInvokeCommandBytes")
                && invokeCase.contains("Self.invokeArgsAreBounded(args)")
                && invokeCase.contains("invoke message failed payload bounds")
                && !invokeCase.contains(#"let callId = body["callId"] as? Int"#)
                && !invokeCase.contains("cmd.count <= 128"),
            "June invoke frames must validate safe call ids, command byte length, and args size before native work or JS reply."
        )
        #expect(
            validationHelpers.contains("int >= 0")
                && validationHelpers.contains("Double(int) <= maxSafeJavaScriptInteger")
                && validationHelpers.contains("guard !(rawValue is Bool)")
                && validationHelpers.contains("double.isFinite")
                && validationHelpers.contains("double.rounded(.towardZero) == double")
                && validationHelpers.contains("double <= maxSafeJavaScriptInteger")
                && validationHelpers.contains("JSONSerialization.isValidJSONObject(wrapper)")
                && validationHelpers.contains("JSONSerialization.data(withJSONObject: wrapper)")
                && validationHelpers.contains("data.count <= maxInvokePayloadBytes"),
            "Invoke validation helpers must reject booleans, non-finite or unsafe numeric ids, fractional ids, and oversized/unserializable args."
        )
    }

    @Test("App Store June bridge projects native notes and folders read-only")
    func appStoreJuneBridgeProjectsNativeNotesAndFoldersReadOnly() throws {
        let bridge = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentBridge.swift")

        #expect(
            bridge.contains(#"case "bootstrap_app":"#)
                && bridge.contains("return Self.bootstrapPayload()")
                && bridge.contains(#"case "list_notes":"#)
                && bridge.contains("Self.nativeNotesPayload(folderID: folderID)")
                && bridge.contains(#"case "list_folders":"#)
                && bridge.contains("return Self.nativeFoldersPayload()")
                && bridge.contains(#"if cmd == "get_note" {"#)
                && bridge.contains("handleGetNoteInvoke(callId: callId, args: args)")
                && bridge.contains("Self.nativeNoteDetailPayload(snapshot: snapshot, content: content)"),
            "June bootstrap/list/get-note invokes must use native SwiftData notes/folders instead of the old empty or fake payloads."
        )
        #expect(
            bridge.contains("private static let maxNativeNotesPayloadItems = 500")
                && bridge.contains("private static let maxNativeFoldersPayloadItems = 1_000")
                && bridge.contains("private static let maxNativeNotePreviewCharacters = 320")
                && bridge.contains("private static let maxNativeNoteContentCharacters = 120_000")
                && bridge.contains("SDPage.activePagesDescriptor")
                && bridge.contains("FetchDescriptor<SDFolder>")
                && bridge.contains("private struct NativeNoteSnapshot: Sendable")
                && bridge.contains("Task.detached(priority: .userInitiated)")
                && bridge.contains("SDPage.loadBodyAsyncFromPrimitives")
                && bridge.contains("boundedNativeNoteContent")
                && bridge.contains(#""readOnly": true"#),
            "Native notes/folders projection must be bounded, read-only, and detail body reads must leave the synchronous bridge path."
        )
        #expect(
            bridge.contains("private static func readOnlyNoteMutationPayload")
                && bridge.contains(#""June's web notes bridge is read-only in the MAS build.""#)
                && !bridge.contains(#"case "list_notes":\n            return ["items": [[String: Any]]()]"#)
                && !bridge.contains(#"case "list_folders", "list_session_folders""#)
                && !bridge.contains("page.loadBody(mapped: false, fast: true)")
                && !bridge.contains(#""filePath":"#)
                && !bridge.contains("vaultRelativeNotePath"),
            "The MAS bridge must not expose raw paths or pretend webview note mutations are durable native writes."
        )
    }

    @Test("App Store June bridge exposes vault skills without editable webview mutation")
    func appStoreJuneBridgeExposesVaultSkillsWithoutEditableWebviewMutation() throws {
        let bridge = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentBridge.swift")
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let rustBridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")
        let nightbrain = try loadMirroredSourceTextFile("agent_core/src/nightbrain/live.rs")
        let discovery = try loadMirroredSourceTextFile("agent_core/src/skill_discovery/mod.rs")
        let skillsCase = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: bridge,
            startingAt: #"case "hermes_bridge_skills":"#,
            endingBefore: #"case "delete_hermes_bridge_session":"#
        ))
        let skillsPayload = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: bridge,
            startingAt: "private static func skillsPayload()",
            endingBefore: "private static func skillDocumentPayload"
        ))
        let documentPayload = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: bridge,
            startingAt: "private static func skillDocumentPayload",
            endingBefore: "private static func unavailableSkillPayload"
        ))

        #expect(
            skillsCase.contains("Self.skillsPayload()")
                && skillsCase.contains(#"case "get_hermes_bridge_skill":"#)
                && skillsCase.contains(#"case "toggle_hermes_bridge_skill":"#),
            "June's Skills panel and slash commands must be wired to native bridge commands, not the old empty array no-op."
        )
        #expect(
            skillsPayload.contains("listRegisteredSkills(vaultPath: vaultPath)")
                && skillsPayload.contains("listRegisteredSkillsLocal(vaultPath: vaultPath)")
                && skillsPayload.contains(".filter(skillPassedPromotionGate)")
                && skillsPayload.contains(#""promotionStatus": "gate_passed""#)
                && skillsPayload.contains(#""enabled": skillEnabled(name: name)"#)
                && skillsPayload.contains(#""readOnly": true"#),
            "June must surface only gate-passed vault skills while keeping webview-loaded skill rows read-only."
        )
        #expect(
            documentPayload.contains("SkillVaultFileIO.readSkillMarkdown")
                && documentPayload.contains("skillPromotionGatePassed(name: name, vaultPath: vaultPath)")
                && documentPayload.contains(#""relativePath": "skills/\(name)/SKILL.md""#)
                && documentPayload.contains(#""readOnly": true"#),
            "Slash skill invocation must load bounded SKILL.md content only after the promotion gate and never expose editable webview mutation."
        )
        #expect(
            bridge.contains("minimumSkillPromotionUseCount: UInt32 = 4")
                && bridge.contains("minimumSkillPromotionSuccessRate = 0.75")
                && bridge.contains("skill.successRate.isFinite")
                && skillsCase.contains("let vaultPath = Self.selectedVaultPath()")
                && skillsCase.contains("Self.skillPromotionGatePassed(name: name, vaultPath: vaultPath)")
                && bridge.contains(#""withheld": true"#),
            "June's user-facing skill library must withhold unproven skills from list/open/toggle paths."
        )
        #expect(
            bridge.contains("private static func boundedSkillName")
                && bridge.contains("trimmed.count <= 128")
                && bridge.contains("case 0x2F, 0x5C, 0x3A"),
            "Skill bridge command payloads must validate path-like names before touching vault skill files."
        )
        #expect(
            rustBridge.contains("pub fn observe_composition(trace_json: String)")
                && rustBridge.contains("SkillDiscovery::new")
                && rustBridge.contains("validate_composition_trace_for_ffi")
                && rustBridge.contains("skill_discovery_outcome_payload")
                && rustBridge.contains(#""relative_path": format!("proposed_skills/{file_name}")"#),
            "The deterministic user-skill learning lane must expose bounded observe_composition FFI without leaking absolute proposal paths."
        )
        #expect(
            gateway.contains("observeComposition(traceJson: traceJSON)")
                && gateway.contains("Task.detached(priority: .utility)")
                && gateway.contains("boundedObservableCompositionTools")
                && gateway.contains("JuneMASToolPolicy.isAllowedAgentToolName(name)")
                && gateway.contains("sequence.count >= 2")
                && gateway.contains(#""user_accepted": true"#)
                && gateway.contains("data.count <= 64 * 1024"),
            "June must submit only successful, multi-tool, MAS-allowlisted composition traces to observe_composition on a background task."
        )
        #expect(
            nightbrain.contains("struct SkillEvolutionAnalysisTask")
                && nightbrain.contains(#"fn name(&self) -> &str"#)
                && nightbrain.contains(#""skill_evolution_analysis""#)
                && nightbrain.contains("run_skill_evolution_analysis(&data_dir, ctx).await")
                && nightbrain.contains("SKILL_EVOLUTION_ANALYSIS_REPORT_LIMIT: usize = 64")
                && nightbrain.contains("MAX_PROPOSED_SKILL_JSON_BYTES: u64 = 64 * 1024")
                && nightbrain.contains(#".join("skill_evolution_analysis")"#)
                && nightbrain.contains("SkillEvolutionAnalysisReport")
                && discovery.contains("default_skill_discovery_data_dir()")
                && discovery.contains(#"SEQUENCE_COUNTS_FILE_NAME: &str = "composition_counts.json""#)
                && discovery.contains("load_sequence_counts(&sequence_counts_path)")
                && discovery.contains("crate::util::atomic_write_json(&self.sequence_counts_path, &counts)")
                && discovery.contains("MAX_SEQUENCE_COUNTS_JSON_BYTES: u64 = 128 * 1024")
                && discovery.contains("frequency_counts_survive_reconstruction")
                && discovery.contains("corrupt_frequency_counts_do_not_promote_early"),
            "NightBrain skill_evolution_analysis must be a bounded review-queue body over the same SkillDiscovery proposal root, and SkillDiscovery frequency gates must survive relaunch without promoting corrupt ledgers."
        )
    }
}
