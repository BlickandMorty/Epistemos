import Foundation
import Testing

@Suite("App Store June hardening")
struct AppStoreJuneHardeningTests {
    @Test("App Store Goose agent_core stream uses bounded buffering")
    func appStoreGooseAgentCoreStreamUsesBoundedBuffering() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Goose/GooseInProcessACPServer.swift")
        let runnerBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: source,
            startingAt: "func streamGooseMASAgentCoreRun(",
            endingBefore: "private final class GooseMASAgentCoreDelegate"
        ))
        let acpVaultPath = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: source,
            startingAt: "private func vaultPathForAgentCore() -> String",
            endingBefore: "private func ensureThirdPartyAIConsentForPrompt"
        ))

        #expect(
            source.contains("GooseMASAgentCoreVaultPaths.fallbackScratchPath")
                && source.contains(".applicationSupportDirectory")
                && source.contains("agent-core-scratch")
                && !source.contains("NSHomeDirectory()"),
            "MAS agent_core must never default an empty vault path to the user's home directory."
        )
        #expect(
            acpVaultPath.contains("GooseMASAgentCoreVaultPaths.fallbackScratchPath"),
            "The older Goose ACP path must share the same Application Support scratch fallback as the MAS runner."
        )
        #expect(
            runnerBody.contains("AsyncThrowingStream(bufferingPolicy: .bufferingNewest(256))"),
            "MAS agent_core event streams must be bounded; unbounded streams can retain hostile or runaway cloud/tool deltas."
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
            ("LocalGGUFQuickChatBackend", gguf),
            ("JuneCloudEngine", cloudScaffold),
        ] {
            #expect(
                source.contains("AsyncThrowingStream(bufferingPolicy: .bufferingNewest(256))"),
                "\(name) must bound token/event streams; default unbounded AsyncThrowingStream is an OOM risk on 16 GB machines."
            )
        }

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

    @Test("App Store June typography uses regular UI fonts except Matrix Dots display headers")
    func appStoreJuneTypographyUsesRegularUIFontsExceptMatrixDotsDisplayHeaders() throws {
        let surface = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentSurfaceView.swift")
        let overlay = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: surface,
            startingAt: "private static func workspaceOverlayScript()",
            endingBefore: "private static func workspaceFontFaceCSS()"
        ))
        let fontFace = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: surface,
            startingAt: "private static func workspaceFontFaceCSS()",
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

    @Test("App Store June GGUF local lane rejects concurrent generations")
    func appStoreJuneGGUFLocalLaneRejectsConcurrentGenerations() throws {
        let gguf = try loadMirroredSourceTextFile("Epistemos/QuickChat/LocalGGUFQuickChatBackend.swift")
        let catalog = try loadMirroredSourceTextFile("Epistemos/QuickChat/GGUFModelCatalog.swift")
        let models = try loadMirroredSourceTextFile("Epistemos/QuickChat/QuickChatModels.swift")
        let preflightBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gguf,
            startingAt: "let fullPrompt = entry.template.apply",
            endingBefore: "guard beginGeneration()"
        ))

        #expect(
            gguf.contains("private var isGenerating = false")
                && gguf.contains("guard beginGeneration()")
                && gguf.contains("QuickChatError.engineUnavailable(.localModelBusy)")
                && gguf.contains("private func finishGeneration()"),
            "June's shared GGUF lane must reject concurrent local turns instead of letting multiple requests race one loaded model."
        )
        #expect(
            gguf.contains("private var unloadAfterGeneration = false")
                && gguf.contains("shouldUnloadImmediatelyForMemoryPressure()")
                && gguf.contains("engine.cancel()")
                && gguf.contains("unloaded after memory-pressure cancellation"),
            "Memory pressure during a GGUF turn must cancel the active generation and unload after it exits, not race an unload against inference."
        )
        #expect(
            preflightBody.contains("GGUFModelCatalog.estimatedTokens(for: fullPrompt)")
                && preflightBody.contains("GGUFModelCatalog.promptFits(")
                && preflightBody.contains("continuation.finish(throwing: QuickChatError.exceededContextWindow)")
                && catalog.contains("nonisolated static func estimatedTokens(for text: String) -> Int")
                && catalog.contains("promptTokenEstimate + replyBudgetTokens <= entry.defaultContextTokens"),
            "GGUF local turns must reject obvious context-window overflow before loading model bytes, especially on 16 GB machines."
        )
        #expect(
            catalog.contains("static let constrainedMachineGB = 18.0")
                && catalog.contains("static let constrainedWorkingSetFraction = 0.34")
                && catalog.contains("nonisolated static func workingSetLimitGB(physicalGB: Double) -> Double")
                && catalog.contains("physicalGB <= constrainedMachineGB")
                && catalog.contains("physicalGB * constrainedWorkingSetFraction"),
            "16 GB-class Macs must keep GGUF residency to a stricter working-set budget so 7B/8B local rows do not push the app into swap."
        )
        #expect(
            models.contains("case localModelBusy")
                && models.contains("already answering another request"),
            "The local busy guard must surface honest user copy instead of a generic generation failure."
        )
    }

    @Test("App Store June Prompt Forge is local, visible, and vault-honest")
    func appStoreJunePromptForgeIsLocalVisibleAndVaultHonest() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let forge = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JunePromptForge.swift")

        #expect(
            gateway.contains(#"case "prompt.forge_preview":"#),
            "June must expose a pre-submit Prompt Forge preview RPC instead of silently rewriting prompt.submit."
        )
        #expect(
            forge.contains(#"mode: "On-device deterministic Prompt Forge""#),
            "Prompt Forge must honestly label the MAS/local preview lane."
        )
        #expect(
            gateway.contains("Task.detached(priority: .userInitiated)")
                && forge.contains("struct JunePromptForgePayload: Sendable"),
            "Prompt Forge vault scanning and assembly must stay off the MainActor and cross back through a sendable payload."
        )
        #expect(
            forge.contains("No matching active-vault notes were found. Do not invent vault citations."),
            "Prompt Forge must fail closed on vault grounding and never fabricate citations."
        )
        #expect(
            forge.contains(#""contextStrategy": contextStrategy"#)
                && forge.contains("Compact local profile")
                && forge.contains("profile.maxCitations"),
            "Prompt Forge must expose and enforce the selected engine's local/cloud context budget instead of treating local models like cloud-scale context windows."
        )
        #expect(
            forge.contains("rustCompiledContext")
                && forge.contains("compileContextPromptJson")
                && forge.contains("citations(fromRustRagContext")
                && forge.contains("Injected bounded Rust ContextCompiler vault context")
                && forge.contains("vaultCitations("),
            "Prompt Forge must prefer the bounded Rust ContextCompiler FFI path while retaining the existing Swift scanner as a fallback."
        )
        #expect(
            forge.contains("startAccessingSecurityScopedResource()")
                && forge.contains("stopAccessingSecurityScopedResource()"),
            "Prompt Forge vault reads must be balanced around security-scoped access."
        )
    }

    @Test("App Store June System Prompt Forge is visible, persisted atomically, and lane honest")
    func appStoreJuneSystemPromptForgeIsVisiblePersistedAtomicallyAndLaneHonest() throws {
        let bridge = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentBridge.swift")
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let context = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentConversationContext.swift")
        let forge = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneSystemPromptForge.swift")

        #expect(
            bridge.contains(#"cmd == "system_prompt_forge_preview""#)
                && bridge.contains("handleSystemPromptForgePreviewInvoke")
                && bridge.contains("Task.detached(priority: .userInitiated)")
                && bridge.contains("JuneSystemPromptForge.previewPayload"),
            "System Prompt Forge preview must be visible through a native bridge command and run bounded assembly off the MainActor."
        )
        #expect(
            bridge.contains(#"case "system_prompt_forge_settings":"#)
                && bridge.contains(#"case "system_prompt_forge_save":"#)
                && bridge.contains(#"case "system_prompt_forge_reset":"#)
                && bridge.contains("activeVaultURL()"),
            "The Settings surface must have native settings/save/reset commands and active-vault grounding authority must stay native-side."
        )
        #expect(
            forge.contains("JunePromptForge().previewPayload")
                && forge.contains("modelID: JuneModelID.cloud")
                && forge.contains("No active-vault behavior notes matched. Do not invent vault citations."),
            "System Prompt Forge must reuse the already-bounded Prompt Forge vault citation path instead of cloning or fabricating grounding."
        )
        #expect(
            forge.contains("try data.write(to: url, options: [.atomic])")
                && forge.contains(".applicationSupportDirectory")
                && !forge.contains("UserDefaults.standard"),
            "Accepted system behavior is user data and should be persisted atomically under Application Support, not as a UserDefaults blob."
        )
        #expect(
            forge.contains("Local lane override: this model is chat-tier only")
                && forge.contains("Cloud lane contract: cloud is the agentic lane")
                && forge.contains("<accepted_behavior>"),
            "Runtime behavior composition must preserve local chat-tier honesty while allowing cloud agentic behavior through the accepted layer."
        )
        #expect(
            gateway.contains("JuneAgentConversationContext.localInstructions")
                && gateway.contains("JuneAgentConversationContext.agentCloudInstructions")
                && context.contains("behaviorBase(localBaseInstructions, isLocal: true)")
                && context.contains("behaviorBase(agentCloudBaseInstructions, isLocal: false)")
                && context.contains("JuneSystemPromptForge.runtimeLayer(isLocal: isLocal)"),
            "June's accepted System Prompt Forge layer must actually compose into local and cloud gateway instructions."
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
        let mainChatMentions = try loadMirroredSourceTextFile("Epistemos/Views/Chat/NotesMentionDropdown.swift")
        #expect(
            mainChatMentions.contains("private let popover = NSPopover()")
                && mainChatMentions.contains("popover.behavior = .semitransient")
                && nav.contains("behavior: .semitransient"),
            "The June Notes popover should match the regular chat native NSPopover dismissal behavior."
        )
        #expect(
            nav.contains("@State private var speech = EpistemosSpeechSynthesizer.shared")
                && nav.contains("EpistemosSpeechSynthesizer.isTextToSpeechAvailable()")
                && nav.contains("JuneAgentSurfaceHolder.shared.bridge?.gateway.latestAssistantReply()")
                && nav.contains("speech.stop()")
                && nav.contains("_ = speech.speak(text)"),
            "Adding the native Notes popover must not regress the existing June read-aloud toolbar control."
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
                && replyID.contains("rawValue is Bool")
                && replyID.contains("double.isFinite")
                && replyID.contains("abs(double) <= Self.maxSafeNumericMagnitude")
                && replyID.contains("return nil"),
            "JuneGatewayReplyID must reject oversized strings, booleans, non-finite numbers, unsafe magnitudes, and non-scalar ids before echoing into JS."
        )
    }

    @Test("App Store June bridge bounds invoke-written session titles")
    func appStoreJuneBridgeBoundsInvokeWrittenSessionTitles() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentBridge.swift")
        let ensureBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: source,
            startingAt: #"case "ensure_hermes_bridge_session":"#,
            endingBefore: #"case "delete_hermes_bridge_session":"#
        ))

        #expect(
            ensureBody.contains("Self.boundedTitle(title)")
                && source.contains("private static func boundedTitle")
                && source.contains("prefix(160)"),
            "June bridge invoke payloads must cap web-provided session titles before writing the durable store."
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
            endingBefore: #"case "ensure_hermes_bridge_session":"#
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
                && gateway.contains("observableCompositionTools.contains(name)")
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
