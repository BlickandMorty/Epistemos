import AppKit
import Foundation
import GRDB
import SwiftData
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX
#error("KEELSTONE App Store lane tests must compile with EPISTEMOS_APP_STORE and MAS_SANDBOX.")
#endif

@Suite("KEELSTONE App Store Lane", .serialized)
@MainActor
struct AppStoreKeelstoneLaneTests {
    private final class SourceGuardBundleToken {}

    private let vaultBookmarkKey = "epistemos.vaultBookmark"
    private let lastVaultPathKey = "epistemos.lastVaultPath"

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(EpistemosSchema.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeTempDirectory(prefix: String = "keelstone-appstore") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeUncreatedTempDirectory(prefix: String = "keelstone-appstore-first-run") -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "AppStoreKeelstoneLaneTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        let bundle = Bundle(for: SourceGuardBundleToken.self)
        if let resources = bundle.resourceURL {
            let candidate = resources
                .appendingPathComponent("RepositorySourceFixtures", isDirectory: true)
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw CocoaError(
            .fileNoSuchFile,
            userInfo: [
                NSFilePathErrorKey: relativePath,
                NSLocalizedDescriptionKey: "Repository source fixture was not staged into the test bundle."
            ]
        )
    }

    private func sourceSection(in text: String, startingAt start: String, endingBefore end: String) -> String? {
        guard let startRange = text.range(of: start),
              let endRange = text[startRange.upperBound...].range(of: end) else {
            return nil
        }
        return String(text[startRange.lowerBound..<endRange.lowerBound])
    }

    @Test("App Store lane compiles the App Store surface")
    func appStoreLaneCompilesAppStoreSurface() {
        #expect(AppSurface.current == .appStore)
        #expect(AppSurface.current.isSandboxed)
        #expect(!AppSurface.current.allowsSubprocessCapabilities)
    }

    @Test("App Store reconciler does not conflict-copy its own identical live save")
    func appStoreReconcilerRejectsSelfWriteConflictCopy() {
        let incomingBody = "# Current\n\nPersisted from the live editor.\n"
        let staleBaseHash = SDPage.bodyHash("# Previous\n\nOlder base.\n")

        #expect(
            !VaultIndexActor.liveEditorBodyConflictsWithVaultBody(
                liveEditorBody: incomingBody,
                vaultBody: incomingBody,
                lastSyncedBodyHash: staleBaseHash
            )
        )
        #expect(
            VaultIndexActor.liveEditorBodyConflictsWithVaultBody(
                liveEditorBody: "# Current\n\nUnsaved local edit.\n",
                vaultBody: "# Current\n\nIndependent external edit.\n",
                lastSyncedBodyHash: staleBaseHash
            )
        )
        #expect(
            !VaultIndexActor.localDraftConflictsWithVaultBody(
                liveEditorBody: incomingBody,
                localDraftBody: "# Previous\n\nStale staged draft.\n",
                incomingBodyHash: SDPage.bodyHash(incomingBody),
                needsVaultSync: true
            )
        )
        #expect(
            VaultIndexActor.localDraftConflictsWithVaultBody(
                liveEditorBody: nil,
                localDraftBody: "# Current\n\nUnsaved staged draft.\n",
                incomingBodyHash: SDPage.bodyHash(incomingBody),
                needsVaultSync: true
            )
        )
        #expect(
            !VaultIndexActor.shouldNotifyEditorOfImportedVaultBody(
                liveEditorBody: incomingBody,
                localDraftBody: "# Previous\n\nStale staged draft.\n",
                vaultBody: incomingBody
            )
        )
        #expect(
            VaultIndexActor.shouldNotifyEditorOfImportedVaultBody(
                liveEditorBody: "# Previous\n\nClean editor base.\n",
                localDraftBody: "# Previous\n\nClean staged base.\n",
                vaultBody: incomingBody
            )
        )
        #expect(
            !VaultIndexActor.shouldNotifyEditorOfImportedVaultBody(
                liveEditorBody: nil,
                localDraftBody: incomingBody,
                vaultBody: incomingBody
            )
        )
    }

    @Test("App Store live-body lookup ignores stale unrelated text views")
    func appStoreLiveBodyLookupUsesMatchingProseEditor() {
        let rootView = NSView()

        let staleTextView = NSTextView()
        staleTextView.string = "# Previous\n\nStale generic text view.\n"
        rootView.addSubview(staleTextView)

        let (otherScrollView, otherEditor) = ProseTextView2.makeTextKit2()
        otherEditor.pageId = "other-page"
        otherEditor.string = "# Other\n\nUnrelated prose editor.\n"
        rootView.addSubview(otherScrollView)

        let (liveScrollView, liveEditor) = ProseTextView2.makeTextKit2()
        liveEditor.pageId = "target-page"
        liveEditor.string = "# Current\n\n[archive-self-write:live-marker]\n"
        rootView.addSubview(liveScrollView)

        #expect(
            NoteWindowManager.editorBody(in: rootView, matchingPageId: "target-page")
                == liveEditor.string
        )
    }

    @Test("App Store live-body lookup prefers the active same-page editor")
    func appStoreLiveBodyLookupUsesMatchingFirstResponder() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let rootView = NSView(frame: window.contentView?.bounds ?? .zero)
        window.contentView = rootView

        let (staleScrollView, staleEditor) = ProseTextView2.makeTextKit2()
        staleEditor.pageId = "target-page"
        staleEditor.string = "# Previous\n\nStale retained prose editor.\n"
        rootView.addSubview(staleScrollView)

        let (liveScrollView, liveEditor) = ProseTextView2.makeTextKit2()
        liveEditor.pageId = "target-page"
        liveEditor.string = "# Current\n\n[archive-self-write:active-marker]\n"
        rootView.addSubview(liveScrollView)

        #expect(window.makeFirstResponder(liveEditor))
        #expect(
            NoteWindowManager.editorBody(in: window, matchingPageId: "target-page")
                == liveEditor.string
        )
    }

    @Test("App Store local Prose saves do not impersonate external changes")
    func appStoreLocalProseSaveNotificationCarriesOrigin() {
        let savedBody = "# Current\n\n[archive-self-write:durable-local-save]\n"
        let localSave = NoteFileStorage.pageBodyChangeNotification(
            pageId: "target-page",
            origin: .localEditorSave,
            savedBody: savedBody
        )
        let externalChange = NoteFileStorage.pageBodyChangeNotification(
            pageId: "target-page",
            origin: .external,
            savedBody: nil
        )

        #expect(
            NoteDetailWorkspaceView.bodyChangeDisposition(
                for: localSave,
                currentEditorBody: savedBody
            ) == .acceptLocalSave(savedBody)
        )
        #expect(
            NoteDetailWorkspaceView.bodyChangeDisposition(
                for: localSave,
                currentEditorBody: "# Current\n\nUnsaved sibling edit.\n"
            ) == .externalChange
        )
        #expect(
            NoteDetailWorkspaceView.bodyChangeDisposition(
                for: externalChange,
                currentEditorBody: savedBody
            ) == .externalChange
        )
    }

    @Test("App Store Markdown Document keeps live stats after delayed placeholder fallback")
    func appStoreMarkdownDocumentKeepsLiveStatsAfterPlaceholderFallback() async throws {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = "# Loaded Markdown\n\nThe bridge reports real document statistics.\n"

        controller.loadInitialContent(
            emptyJSON,
            title: "Loaded Markdown",
            markdownSource: markdown
        )
        controller.installEditorDispatch { _ in }
        controller.handleBridgeMessage(.editorReady)
        controller.handleBridgeMessage(
            .documentStatsChanged(wordCount: 8, characterCount: 57),
            epoch: 1
        )

        try await Task.sleep(for: .milliseconds(350))

        #expect(controller.toolbarModel.wordCount == 8)
        #expect(controller.toolbarModel.characterCount == 57)
    }

    @Test("normal Epistemos scheme launches the MAS target")
    func normalEpistemosSchemeLaunchesMASTarget() throws {
        let project = try loadRepoTextFile("project.yml")
        let defaultScheme = try loadRepoTextFile("Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme")
        let defaultBuildAction = defaultScheme.components(separatedBy: "<TestAction").first ?? defaultScheme

        #expect(project.contains("  Epistemos:\n    build:\n      targets:\n        Epistemos-AppStore: all\n        EpistemosAppStoreKeelstoneTests: [test]"))
        #expect(!project.contains("Epistemos-LegacyDev"))
        #expect(!project.contains("Epistemos-Experimental"))
        #expect(!project.contains("EPISTEMOS_EXPERIMENTAL"))
        #expect(defaultScheme.contains("BlueprintName = \"Epistemos-AppStore\""))
        #expect(defaultScheme.contains("BuildableName = \"Epistemos-AppStore.app\""))
        #expect(defaultScheme.contains("BlueprintName = \"EpistemosAppStoreKeelstoneTests\""))
        #expect(!defaultScheme.contains("BlueprintName = \"Epistemos\""))
        #expect(!defaultScheme.contains("BlueprintName = \"EpistemosTests\""))
        #expect(!defaultScheme.contains("Epistemos-LegacyDev"))
        #expect(!defaultScheme.contains("Epistemos-Experimental"))
        #expect(defaultBuildAction.contains("BuildableName = \"EpistemosAppStoreKeelstoneTests.xctest\""))
        #expect(defaultBuildAction.contains("buildForRunning = \"NO\""))
        #expect(defaultBuildAction.contains("buildForArchiving = \"NO\""))
    }

    @Test("App Store privacy manifest covers container and user-selected vault timestamps")
    func appStorePrivacyManifestCoversUserSelectedVaultTimestamps() throws {
        let manifestText = try loadRepoTextFile("Epistemos/Resources/PrivacyInfo.xcprivacy")
        let manifestData = try #require(manifestText.data(using: .utf8))
        let manifest = try #require(
            PropertyListSerialization.propertyList(from: manifestData, format: nil)
                as? [String: Any]
        )
        let accessedTypes = try #require(
            manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]]
        )
        let fileTimestampEntry = try #require(accessedTypes.first {
            $0["NSPrivacyAccessedAPIType"] as? String
                == "NSPrivacyAccessedAPICategoryFileTimestamp"
        })
        let reasons = try #require(
            fileTimestampEntry["NSPrivacyAccessedAPITypeReasons"] as? [String]
        )

        #expect(Set(reasons) == ["C617.1", "3B52.1"])
    }

    @Test("App Store lane disables per-message Prompt Forge and submits literal prompts")
    func appStoreLaneDisablesPerMessagePromptForgeAndSubmitsLiteralPrompts() throws {
        let gateway = try loadRepoTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let inference = try loadRepoTextFile("Epistemos/State/InferenceState.swift")
        let promptForgeCase = try #require(sourceSection(
            in: gateway,
            startingAt: #"case "prompt.forge_preview":"#,
            endingBefore: #"case "prompt.submit":"#
        ))
        let promptSubmitCase = try #require(sourceSection(
            in: gateway,
            startingAt: #"case "prompt.submit":"#,
            endingBefore: #"case "session.interrupt":"#
        ))
        let turnFailureCatch = try #require(sourceSection(
            in: gateway,
            startingAt: "let described = JuneEngineErrorText.describe(error)",
            endingBefore: "self.approvals.denyPendingApprovals(sessionID: sessionID)"
        ))
        let streamCompletionCase = try #require(sourceSection(
            in: gateway,
            startingAt: "case .complete(let stopReason, let inputTokens, let outputTokens):",
            endingBefore: "case .error(let message):"
        ))
        let fallbackCompletionCase = try #require(sourceSection(
            in: gateway,
            startingAt: "let status = Task.isCancelled ? \"cancelled\" : \"ok\"",
            endingBefore: "Self.observeCompositionIfEligible("
        ))

        #expect(
            promptForgeCase.contains("Per-message Prompt Forge is disabled in the App Store build")
                && promptForgeCase.contains("Send keeps your prompt unchanged")
                && promptForgeCase.contains("replyError")
                && !promptForgeCase.contains("JunePromptForge")
                && !promptForgeCase.contains("Task.detached")
                && !gateway.contains("private let promptForge")
        )
        #expect(
            promptSubmitCase.contains("startTurn(sessionID: sessionID, prompt: text, requestedModelID: requestedModel)")
                && !promptSubmitCase.contains("promptForge")
                && !promptSubmitCase.contains("forge_preview")
        )
        #expect(turnFailureCatch.contains("let errorText"))
        #expect(turnFailureCatch.contains("self.store.appendMessage("))
        #expect(turnFailureCatch.contains("role: \"assistant\""))
        #expect(turnFailureCatch.contains("content: errorText"))
        #expect(turnFailureCatch.contains(#""status": "error""#))
        #expect(gateway.contains("private static func requireVisibleAssistantReply"))
        #expect(gateway.contains("private static func emptySuccessfulTurnMessage"))
        #expect(gateway.contains("June did not receive any reply text from the selected MAS model"))
        #expect(gateway.contains("Check Settings > June Models for cloud access, or choose Apple Intelligence or an installed local GGUF model in June"))
        #expect(!gateway.contains("Check Settings > Models, choose Cloud Agent"))
        #expect(bootstrap.contains("MAS June model stack:"))
        #expect(bootstrap.contains("local-gguf-runtime="))
        #expect(!bootstrap.contains("LocalGGUFQuickChatBackend.shared"))
        #expect(!bootstrap.contains("App-local model stack removed:"))
        #expect(inference.contains("Legacy MLX Selection (Unavailable)"))
        #expect(!inference.contains("Local Models Removed"))
        #expect(streamCompletionCase.contains("try Self.requireVisibleAssistantReply(full, modelID: modelID)"))
        let streamGuardIndex = try #require(streamCompletionCase.range(
            of: "try Self.requireVisibleAssistantReply(full, modelID: modelID)"
        )?.lowerBound)
        let streamEmitIndex = try #require(streamCompletionCase.range(of: "self.emit(")?.lowerBound)
        #expect(streamGuardIndex < streamEmitIndex)
        #expect(fallbackCompletionCase.contains("try Self.requireVisibleAssistantReply(full, modelID: modelID)"))
    }

    @Test("App Store lane accepts WebKit numeric JSON-RPC ids for June sessions")
    func appStoreLaneAcceptsWebKitNumericJSONRPCIDsForJuneSessions() throws {
        let gateway = JuneAgentGateway()
        var deliveredFrames: [String] = []
        gateway.deliver = { deliveredFrames.append($0) }

        gateway.handleFrame(#"{"jsonrpc":"2.0","id":1,"method":"session.create","params":{"title":"Smoke"}}"#)

        let reply = try #require(deliveredFrames.first)
        let data = try #require(reply.data(using: .utf8))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["id"] as? Int == 1)
        let result = try #require(object["result"] as? [String: Any])
        #expect(result["session_id"] as? String != nil)

        deliveredFrames.removeAll()
        gateway.handleFrame(#"{"jsonrpc":"2.0","id":true,"method":"session.create","params":{"title":"Rejected"}}"#)
        #expect(deliveredFrames.isEmpty)
    }

    @Test("App Store lane preserves safe agent_core FFI diagnostics")
    func appStoreLanePreservesSafeAgentCoreFFIDiagnostics() {
        let safe = EngineLogDiagnostics.logMessage(
            for: AgentErrorFfi.AgentError(message: "provider error: OPENAI_API_KEY is not configured"),
            fallback: "agent_core MAS run failed"
        )
        #expect(safe == "agent_core MAS run failed: provider error: OPENAI_API_KEY is not configured")
        #expect(!safe.contains("domain="))

        let pathBearing = EngineLogDiagnostics.logMessage(
            for: AgentErrorFfi.AgentError(message: "Failed to open vault: /Users/jojo/PrivateVault"),
            fallback: "agent_core MAS run failed"
        )
        #expect(pathBearing == "agent_core MAS run failed: Failed to open vault: <redacted-path>")
        #expect(!pathBearing.contains("domain="))
        #expect(!pathBearing.contains("/Users/jojo"))
        #expect(!pathBearing.contains("PrivateVault"))

        let credentialBearing = EngineLogDiagnostics.logMessage(
            for: AgentErrorFfi.AgentError(message: "provider rejected bearer sk-private-value"),
            fallback: "agent_core MAS run failed"
        )
        #expect(credentialBearing.contains("domain=Epistemos.AgentErrorFfi"))
        #expect(!credentialBearing.contains("sk-private-value"))

        let callbackPath = EngineLogDiagnostics.agentCoreCallbackMessage(
            "Failed to create session folder: /Users/jojo/PrivateVault/sessions",
            fallback: "agent_core MAS run failed"
        )
        #expect(callbackPath == "agent_core MAS run failed: Failed to create session folder: <redacted-path>")

        let callbackCredential = EngineLogDiagnostics.agentCoreCallbackMessage(
            "authorization bearer sk-private-value",
            fallback: "agent_core MAS run failed"
        )
        #expect(callbackCredential == "agent_core MAS run failed")
    }

    @Test("App Store lane scopes Keychain provider credentials only around agent_core calls")
    func appStoreLaneScopesKeychainProviderCredentialsOnlyAroundAgentCoreCalls() throws {
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let runner = try loadRepoTextFile("Epistemos/Goose/GooseMASAgentCoreRunner.swift")
        let callSection = try #require(sourceSection(
            in: runner,
            startingAt: "let task = Task",
            endingBefore: "continuation.onTermination"
        ))

        #expect(bootstrap.contains("static func withScopedAgentCoreEnvironment"))
        #expect(bootstrap.contains("clearAgentCoreEnvironment()"))
        #expect(bootstrap.contains("restoreEnvironmentVars(previous)"))
        #expect(callSection.contains("AppBootstrap.withScopedAgentCoreEnvironment"))
        #expect(callSection.contains("runAgentSession("))
        #expect(callSection.range(of: "AppBootstrap.withScopedAgentCoreEnvironment")?.lowerBound ?? callSection.endIndex
            < callSection.range(of: "runAgentSession(")?.lowerBound ?? callSection.startIndex)
        #expect(runner.contains("EngineLogDiagnostics.agentCoreCallbackMessage("))
        #expect(!runner.contains("func onError(message: String) {\n        emit(.error(message))"))
    }

    @Test("App Store lane disables System Prompt Forge runtime composition")
    func appStoreLaneDisablesSystemPromptForgeRuntimeComposition() throws {
        let bridge = try loadRepoTextFile("Epistemos/JuneAgent/JuneAgentBridge.swift")
        let context = try loadRepoTextFile("Epistemos/JuneAgent/JuneAgentConversationContext.swift")
        let forge = try loadRepoTextFile("Epistemos/JuneAgent/JuneSystemPromptForge.swift")
        let previewHandler = try #require(sourceSection(
            in: bridge,
            startingAt: "private func handleSystemPromptForgePreviewInvoke",
            endingBefore: "    private func handleGetNoteInvoke"
        ))
        let runtimeLayer = try #require(sourceSection(
            in: forge,
            startingAt: "static func runtimeLayer",
            endingBefore: "    private static func boundedPrompt"
        ))

        #expect(previewHandler.contains("activeVaultURL: nil"))
        #expect(!previewHandler.contains("Task.detached"))
        #expect(!previewHandler.contains("activeVaultURL()"))
        #expect(forge.contains(#"static let mode = "System Prompt Forge disabled in MAS""#))
        #expect(forge.contains(#""disabled": true"#))
        #expect(forge.contains("upgradedText: original"))
        #expect(forge.contains("changed: false"))
        #expect(forge.contains("clearState()"))
        #expect(!forge.contains("JunePromptForge().previewPayload"))
        #expect(!forge.contains("modelID: JuneModelID.cloud"))
        #expect(!forge.contains("<accepted_behavior>"))
        #expect(runtimeLayer.contains("\"\""))
        #expect(context.contains("JuneSystemPromptForge.runtimeLayer(isLocal: isLocal)"))
    }

    @Test("App Store lane release gate rejects archived JuneWeb Prompt Forge command drift")
    func appStoreLaneReleaseGateRejectsArchivedJuneWebPromptForgeCommandDrift() throws {
        let gate = try loadRepoTextFile("scripts/keelstone-release-gate.sh")

        #expect(gate.contains(#"system_prompt_forge|prompt\.forge_preview"#))
        #expect(gate.contains("Staged JuneWeb omits prompt-upgrade UI and send-review hooks"))
        #expect(gate.contains("Staged JuneWeb omits Hermes-branded send/session failure copy"))
        #expect(gate.contains("Hermes is not running"))
        #expect(gate.contains("Hermes RPC failed"))
        #expect(gate.contains("Raw Hermes trace"))
        #expect(gate.contains("Staged JuneWeb shim identifies the MAS in-process June gateway"))
        #expect(gate.contains("Staged JuneWeb fallback does not pretend a provider is configured"))
        #expect(gate.contains("Staged JuneWeb shim does not advertise a Hermes home"))
        #expect(gate.contains("Staged JuneWeb shim fails visibly if MAS host mode is absent"))
        #expect(gate.contains("Staged JuneWeb shim has no canned prompt.submit success path"))
        #expect(gate.contains(#"${APPSTORE_APP}/Contents/Resources/JuneWeb/dist"#))
        #expect(gate.contains("Built App Store JuneWeb omits prompt-upgrade UI and send-review hooks"))
        #expect(gate.contains("Built App Store JuneWeb omits Hermes-branded send/session failure copy"))
        #expect(gate.contains("Built App Store JuneWeb shim identifies the MAS in-process June gateway"))
        #expect(gate.contains("Built App Store JuneWeb fallback does not pretend a provider is configured"))
        #expect(gate.contains("Built App Store JuneWeb shim fails visibly if MAS host mode is absent"))
        #expect(gate.contains("Built App Store JuneWeb shim has no canned prompt.submit success path"))
        #expect(gate.contains("Built App Store JuneWeb shim does not advertise a generic in-process Hermes command"))
        #expect(gate.contains("require_appstore_local_gguf_runtime"))
        #expect(gate.contains("Contents/Frameworks/llama.framework/Versions/A/llama"))
        #expect(gate.contains("otool -L"))
        #expect(gate.contains("Built App Store artifact embeds June's in-process llama runtime"))
        #expect(gate.contains("Built App Store executable links June's in-process llama runtime"))
    }

    @Test("App Store lane keeps June startup off synchronous keychain reads")
    func appStoreLaneKeepsJuneStartupOffSynchronousKeychainReads() throws {
        let gateway = try loadRepoTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let catalog = try loadRepoTextFile("Epistemos/JuneAgent/JuneAgentModelCatalog.swift")
        let inference = try loadRepoTextFile("Epistemos/State/InferenceState.swift")
        let gatewayTypes = try loadRepoTextFile("Epistemos/JuneAgent/JuneGatewayTypes.swift")
        let auth = try loadRepoTextFile("Epistemos/Engine/CloudProviderAuthService.swift")
        let defaultModel = try #require(sourceSection(
            in: gateway,
            startingAt: "func currentDefaultModelID() -> String",
            endingBefore: "    private func preferredCachedConfiguredCloudModelID()"
        ))
        let cachedPreferred = try #require(sourceSection(
            in: gateway,
            startingAt: "private func preferredCachedConfiguredCloudModel() -> CloudTextModelID?",
            endingBefore: "    private func cachedConfiguredCloudProviders()"
        ))
        let cachedProviders = try #require(sourceSection(
            in: gateway,
            startingAt: "private func cachedConfiguredCloudProviders() -> Set<CloudModelProvider>",
            endingBefore: "    @discardableResult"
        ))
        let directCloudIDs = try #require(sourceSection(
            in: catalog,
            startingAt: "static func directCloudModelIDs(configuredOnly: Bool) -> [String]",
            endingBefore: "    private static func genericCloudCapabilities"
        ))

        #expect(defaultModel.contains("preferredCachedConfiguredCloudModelID() ?? preferredLocalDefaultModelID() ?? JuneModelID.cloud"))
        #expect(gateway.contains("private func preferredLocalDefaultModelID() -> String?"))
        #expect(gateway.contains("AppleFMQuickChatBackend.unavailability() == nil ? JuneModelID.appleFM : nil"))
        #expect(defaultModel.contains("clean App Store installs either produce an answer or surface one clear"))
        #expect(defaultModel.contains("repairedDefaultModelID(saved)"))
        #expect(defaultModel.contains("UserDefaults.standard.set(repaired, forKey: Self.defaultModelKey)"))
        #expect(defaultModel.contains("CloudTextModelID(rawValue: id) != nil"))
        #expect(defaultModel.contains("cloudModel.provider.supportsAgentTier"))
        #expect(defaultModel.contains("hasCachedCloudAccess(for: cloudModel.provider)"))
        #expect(defaultModel.contains("preferredCloudModel(for: cloudModel.provider).rawValue"))
        #expect(defaultModel.contains("never synchronously reads Keychain"))
        #expect(!defaultModel.contains("preferredConfiguredCloudModelID()"))
        #expect(gateway.contains("let rawModelID = persisted ?? currentDefaultModelID()"))
        #expect(gateway.contains("let modelID = repairedTurnModelID(rawModelID, sessionID: sessionID)"))
        #expect(gateway.contains("June rejected non-runnable default model"))
        #expect(gateway.contains("June rejected non-runnable session model"))
        #expect(gateway.contains("JuneAgentModelCatalog.directCloudModelIDs(configuredOnly: true)"))
        #expect(cachedPreferred.contains("inference.hasCachedCloudAccess(for: provider)"))
        #expect(cachedProviders.contains("inference.hasCachedCloudAccess(for: $0)"))
        #expect(directCloudIDs.contains("inference?.hasCachedCloudAccess(for: provider)"))
        #expect(directCloudIDs.contains("CloudTextModelID.juneAgentModels(for: provider)"))
        #expect(catalog.contains("static let directCloudProviders = CloudModelProvider.juneAgentProviders"))
        #expect(catalog.contains("cachedConfiguredCloudProviders: Set<CloudModelProvider>"))
        #expect(catalog.contains("saved OpenAI or Anthropic API key"))
        #expect(catalog.contains("Uses your saved OpenAI API key."))
        #expect(catalog.contains("Uses your saved Anthropic API key."))
        #expect(!catalog.contains("Uses your saved \\(provider.manualCredentialTitleLowercase) or account connection."))
        #expect(inference.contains("func hasCachedCloudAccess(for provider: CloudModelProvider) -> Bool"))
        #expect(inference.contains("must never fall through to"))
        #expect(inference.contains("SecItemCopyMatching"))
        #expect(gatewayTypes.contains("Add an OpenAI or Anthropic API key in Settings"))
        #expect(auth.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\n    case openAICodex"))
        #expect(auth.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\n    case openAIDeviceCodeRequestFailed"))
        #expect(auth.contains("Use a Google API key or an OpenAI API key"))
        #expect(inference.contains("Use OpenAI as the active cloud provider with an API key stored in Apple Keychain."))
    }

    @Test("App Store lane keeps clean Markdown Document switches read-only")
    func appStoreLaneKeepsCleanMarkdownDocumentSwitchesReadOnly() throws {
        let surface = try loadRepoTextFile("Epistemos/Views/Notes/MarkdownDocumentSurface.swift")
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let chrome = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let sharedTests = try loadRepoTextFile("EpistemosTests/EditorProvenanceStoreTests.swift")
        let bridgeTests = try loadRepoTextFile("EpistemosTests/EpdocEditorBridgeTests.swift")
        let flushSection = try #require(sourceSection(
            in: surface,
            startingAt: "func flushPendingMarkdown() async -> Bool",
            endingBefore: "func flushPendingProvenanceWrites() async"
        ))
        let currentEditorBodySection = try #require(sourceSection(
            in: workspace,
            startingAt: "private func currentEditorBody(for page: SDPage) -> String?",
            endingBefore: "@discardableResult\n    private func flushCurrentEditor"
        ))

        #expect(surface.contains("enum MarkdownDocumentSurfacePerformancePolicy"))
        #expect(surface.contains("static let autosaveQuietWindow: Duration = .seconds(2)"))
        #expect(surface.contains("reloadSamePageExternalMarkdown = false"))
        #expect(surface.contains("guard MarkdownDocumentSurfacePerformancePolicy.reloadSamePageExternalMarkdown else"))
        #expect(surface.contains("let isActive: Bool"))
        #expect(surface.contains(".onChange(of: isActive)"))
        #expect(surface.contains("pendingExternalMarkdownReload"))
        #expect(surface.contains("if isActive, let pending = pendingExternalMarkdownReload"))
        #expect(surface.contains("shouldRecoverCleanEmptyInitialLoad"))
        #expect(surface.contains("visibleMarkdownSnapshotIsEmptyOverNonEmptyHost(markdown)"))
        #expect(surface.contains("preferredNonEmptyRememberedMarkdown(hostMarkdown: markdown)"))
        #expect(surface.contains("controller.latestMarkdownSnapshot,\n            latestMarkdown,\n            hostMarkdown"))
        #expect(surface.contains("markdown: coordinator.markdownForAssistContext(hostMarkdown: markdown)"))
        #expect(surface.contains("guard isDirty else { return hostMarkdown }"))
        #expect(bridgeTests.contains("func cleanEpdocAssistContextUsesCanonicalHostMarkdown()"))
        #expect(surface.contains("let becameActive = !wasActive && isActive"))
        #expect(surface.contains("shouldRecoverVisibleBlankOnReactivation"))
        #expect(surface.contains("controller.toolbarModel.characterCount == 0"))
        #expect(surface.contains("shouldProbeVisibleMarkdownOnCleanReactivation"))
        #expect(surface.contains("requestCleanReactivationMarkdownProbe(expectedMarkdown: markdown)"))
        #expect(workspace.contains("let documentSurfaceIsAvailable = noteModeOptions(for: page).modes.contains(.document)"))
        #expect(workspace.contains("noteDocumentSurface(page: page, isActive: resolvedMode == .document)"))
        #expect(workspace.contains(".opacity(resolvedMode == .document ? 1 : 0)"))
        #expect(workspace.contains("noteNonDocumentEditorSurface(page: page, availableSize: availableSize)"))
        #expect(workspace.contains("isSpuriousCleanEmptySnapshot"))
        #expect(workspace.contains("lensSwitchBody(candidate: currentEditorBody(for: page), baseline: baseline)"))
        #expect(workspace.contains("ignored empty editor snapshot during lens switch"))
        #expect(workspace.contains("body.isEmpty && !persistedBody.isEmpty"))
        #expect(!workspace.contains("body.isEmpty && !persistedBody.isEmpty && !noteSession.state.needsWriteLease"))
        #expect(currentEditorBodySection.contains("switch resolvedNoteMode(for: page)"))
        #expect(currentEditorBodySection.contains("case .edit:\n            return NoteEditorViewFinder.findEditorTextView(for: pageId)?.string"))
        #expect(currentEditorBodySection.contains("case .document, .source, .preview:"))
        #expect(!currentEditorBodySection.hasPrefix("if let responder = NoteEditorViewFinder.findEditorTextView"))
        #expect(workspace.contains("isActive: isActive"))
        #expect(chrome.contains("pendingInitialMarkdownEmptyEchoRetries"))
        #expect(chrome.contains("pendingCleanReactivationMarkdownProbe"))
        #expect(chrome.contains("verifiedCleanReactivationMarkdown"))
        #expect(chrome.contains("requestCleanReactivationMarkdownProbe(expectedMarkdown: String)"))
        #expect(chrome.contains("guard verifiedCleanReactivationMarkdown != expectedMarkdown else"))
        #expect(chrome.contains("reloadMarkdownSourceForCleanReactivation"))
        #expect(chrome.contains("preferredNonEmptyMarkdownSource"))
        #expect(chrome.contains("markdownBodyIsEmpty"))
        #expect(chrome.contains("re-pushing non-empty Markdown source"))
        #expect(chrome.contains("Epdoc clean Markdown snapshot was empty; re-pushing non-empty host Markdown source"))
        #expect(chrome.contains("clean reactivation probe returned empty content"))
        #expect(chrome.contains("suppressing empty save over non-empty source"))
        #expect(chrome.contains("prepareForWebContentProcessRecovery"))
        #expect(chrome.contains("reloading editor with host Markdown recovery source"))
        #expect(chrome.contains("webView.load(URLRequest(url: url))"))
        #expect(chrome.contains("public func detachEditorDispatch()"))
        #expect(chrome.contains("editorIsReady = false"))
        #expect(chrome.contains("didPushInitialContent = false"))
        #expect(chrome.contains("pendingCleanReactivationMarkdownProbe = nil"))
        #expect(!chrome.contains("editor blanked; reopen the note to recover"))
        #expect(surface.contains("ignored empty direct editor snapshot over non-empty Markdown source"))
        #expect(surface.contains("Task.sleep(for: MarkdownDocumentSurfacePerformancePolicy.autosaveQuietWindow)"))
        #expect(flushSection.contains("let hadPendingSave = saveTask != nil"))
        #expect(flushSection.contains("guard hadPendingSave || hadOutstandingWrite || controller.toolbarModel.isDirty else"))
        #expect(flushSection.contains("let hasPendingMarkdownSnapshot = latestMarkdown != lastFlushedMarkdown"))
        #expect(flushSection.contains("if !hasPendingMarkdownSnapshot"))
        #expect(flushSection.contains("return true"))
        #expect(flushSection.contains("requestCurrentMarkdownSnapshotFromEditor()"))
        #expect(flushSection.contains("requestFreshMarkdownSnapshotIfPossible()"))
        #expect(surface.contains("private var markdownWriteTail: Task<Bool, Never>?"))
        #expect(surface.contains("_ = await predecessor.value"))
        #expect(surface.contains("if self.markdownRevision == revision"))
        #expect(surface.contains("private var markdownSaveWorkerGeneration: UInt64 = 0"))
        #expect(surface.contains("guard saveTask == nil else { return }"))
        #expect(surface.contains("guard debounceGeneration == self.markdownDebounceGeneration else { continue }"))
        #expect(surface.contains("let markdownToSave = self.latestMarkdown"))
        #expect(surface.contains("private func cancelMarkdownSaveWorker()"))
        #expect(!surface.contains("saveTask?.cancel()\n        saveTask = Task"))
        #expect(surface.contains("private var markdownFlushTask: Task<Bool, Never>?"))
        #expect(sharedTests.contains("cleanMarkdownDocumentSurfaceSwitchesDoNotSaveNormalizedSnapshots"))
        #expect(sharedTests.contains("samePageMarkdownUpdatesDoNotRemountTheRichDocumentTree"))
        #expect(sharedTests.contains("samePageMarkdownDocumentReloadsWhenAsyncBodyArrivesAfterEmptyMount"))
        #expect(sharedTests.contains("hiddenMarkdownDocumentSurfaceReloadsExternalLensChangesOnReactivation"))
        #expect(sharedTests.contains("hiddenMarkdownDocumentSurfaceRepushesNonEmptyMarkdownWhenBlankOnReactivation"))
        #expect(sharedTests.contains("hiddenMarkdownDocumentSurfaceProbesStaleStatsAndSuppressesBlankReactivationSnapshots"))
        #expect(sharedTests.contains("verifiedCleanMarkdownDocumentSurfaceReactivationSkipsRepeatedSnapshotProbe"))
        #expect(bridgeTests.contains("chromeControllerRepushesNonEmptyMarkdownSourceAfterEmptyInitialEcho"))
        #expect(bridgeTests.contains("markdownDocumentSurfaceReactivatesFromNonEmptyHostWhenWebKitSnapshotWasEmpty"))
        #expect(bridgeTests.contains("chromeControllerRecoversLastMarkdownSourceAfterWebContentTermination"))
        #expect(sharedTests.contains("| --- | --- |"))
        #expect(sharedTests.contains("savedMarkdown.isEmpty"))
    }

    @Test("App Store lane bounds Epdoc notebook manifest parsing on large normal notes")
    func appStoreLaneBoundsEpdocNotebookManifestParsingOnLargeNormalNotes() {
        let lateManifest = String(repeating: "ordinary body line\n", count: 5_000) + """
        ```epistemos-notebook
        version: 1
        tab: id=11111111-1111-4111-8111-111111111111 type=sheet version=1 title="Too Late" ref="dataset:late.dataset.md"
        ```
        """

        let parsed = EpdocNotebookManifest.parse(in: lateManifest)

        #expect(parsed.tabs.isEmpty)
        #expect(parsed.source == .none)
    }

    @Test("App Store lane keeps same-page Epdoc updates from remounting rich document state")
    func appStoreLaneKeepsSamePageEpdocUpdatesFromRemountingRichDocumentState() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []

        coordinator.configure(
            pageId: "same-page-appstore",
            title: "Same Page App Store",
            markdown: "| A | B |\n| - | - |\n| 1 | 2 |\n",
            theme: .light,
            noteRelativePath: "notes/same-page-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        commands.removeAll()

        coordinator.configure(
            pageId: "same-page-appstore",
            title: "Same Page App Store",
            markdown: "| A | B |\n| --- | --- |\n| 1 | 2 |\n\nExternal line\n",
            theme: .light,
            noteRelativePath: "notes/same-page-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands.isEmpty)
    }

    @Test("App Store lane reloads same-page Epdoc when async body arrives after empty mount")
    func appStoreLaneReloadsSamePageEpdocWhenAsyncBodyArrivesAfterEmptyMount() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        let loadedMarkdown = """
        ---
        title: Loaded Later
        ---

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        coordinator.configure(
            pageId: "same-page-empty-then-loaded-appstore",
            title: "Loaded Later",
            markdown: "",
            theme: .light,
            noteRelativePath: "notes/loaded-later.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        commands.removeAll()

        coordinator.configure(
            pageId: "same-page-empty-then-loaded-appstore",
            title: "Loaded Later",
            markdown: loadedMarkdown,
            theme: .light,
            noteRelativePath: "notes/loaded-later.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.setMarkdownForLoad(markdown: loadedMarkdown, epoch: 2), .focusStart])
        #expect(coordinator.controller.latestMarkdownSnapshot == loadedMarkdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @Test("App Store lane re-pushes non-empty Epdoc Markdown when initial bridge echo is empty")
    func appStoreLaneRepushesNonEmptyEpdocMarkdownAfterEmptyInitialEcho() {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = """
        ---
        title: App Store table
        ---

        | A | B |
        | - | - |
        | 1 | 2 |
        """
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []

        controller.onMarkdownChanged = { markdown, _ in
            savedMarkdown.append(markdown)
        }
        controller.loadInitialContent(emptyJSON, title: "App Store table", markdownSource: markdown)
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)
        commands.removeAll()

        controller.handleBridgeMessage(.markdownDidChange(markdown: "", writeback: nil), epoch: 1)

        #expect(savedMarkdown.isEmpty)
        #expect(controller.latestMarkdownSnapshot == markdown)
        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 1)])
    }

    @Test("App Store lane re-pushes Epdoc Markdown after clean post-load blank snapshot")
    func appStoreLaneRepushesEpdocMarkdownAfterCleanPostLoadBlankSnapshot() {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = """
        # App Store Post-load Blank Proof

        | A | B |
        | - | - |
        | 1 | 2 |
        """
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []

        controller.onMarkdownChanged = { markdown, _ in
            savedMarkdown.append(markdown)
        }
        controller.loadInitialContent(emptyJSON, title: "App Store Post-load Blank Proof", markdownSource: markdown)
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)
        controller.handleBridgeMessage(.markdownDidChange(markdown: markdown, writeback: nil), epoch: 1)
        controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()

        controller.handleBridgeMessage(.markdownDidChange(markdown: "", writeback: nil), epoch: 1)

        #expect(savedMarkdown.isEmpty)
        #expect(controller.latestMarkdownSnapshot == markdown)
        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 2), .focusStart])
    }

    @Test("App Store lane recovers Epdoc after WebKit blanking with last Markdown source")
    func appStoreLaneRecoversEpdocAfterWebKitBlankingWithLastMarkdownSource() {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let editedJSON = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Edited table"}]}]}"#
            .data(using: .utf8)!
        let loadedMarkdown = "| A | B |\n| - | - |\n| 1 | 2 |\n"
        let editedMarkdown = "| A | B |\n| - | - |\n| 3 | 4 |\n"
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []

        controller.onMarkdownChanged = { markdown, _ in
            savedMarkdown.append(markdown)
        }
        controller.loadInitialContent(emptyJSON, title: "App Store table", markdownSource: loadedMarkdown)
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)
        controller.handleBridgeMessage(.markdownDidChange(markdown: loadedMarkdown, writeback: nil), epoch: 1)
        controller.handleBridgeMessage(.contentDidChange(json: emptyJSON), epoch: 1)
        controller.handleBridgeMessage(.contentDidChange(json: editedJSON), epoch: 1)
        controller.handleBridgeMessage(.markdownDidChange(markdown: editedMarkdown, writeback: nil), epoch: 1)
        commands.removeAll()

        #expect(savedMarkdown == [editedMarkdown])
        #expect(controller.prepareForWebContentProcessRecovery())
        #expect(controller.currentLoadEpoch == 2)
        #expect(controller.latestMarkdownSnapshot == editedMarkdown)
        #expect(controller.toolbarModel.isDirty)

        controller.handleBridgeMessage(.editorReady)

        #expect(commands == [.setMarkdownForLoad(markdown: editedMarkdown, epoch: 2), .focusStart])
    }

    @Test("App Store lane reloads hidden Epdoc only when another lens changed markdown")
    func appStoreLaneReloadsHiddenEpdocOnlyWhenAnotherLensChangedMarkdown() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []

        coordinator.configure(
            pageId: "hidden-appstore",
            title: "Hidden App Store",
            markdown: "Alpha\n",
            theme: .light,
            noteRelativePath: "notes/hidden-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        commands.removeAll()

        coordinator.configure(
            pageId: "hidden-appstore",
            title: "Hidden App Store",
            markdown: "Alpha from source lens\n",
            theme: .light,
            noteRelativePath: "notes/hidden-appstore.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        #expect(commands.isEmpty)

        coordinator.configure(
            pageId: "hidden-appstore",
            title: "Hidden App Store",
            markdown: "Alpha from source lens\n",
            theme: .light,
            noteRelativePath: "notes/hidden-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(!commands.isEmpty)
    }

    @Test("App Store lane repushes hidden blank Epdoc on Document reactivation")
    func appStoreLaneRepushesHiddenBlankEpdocOnDocumentReactivation() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        let markdown = """
        # App Store Reactivation Proof

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        coordinator.configure(
            pageId: "hidden-blank-appstore",
            title: "Hidden Blank App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-blank-appstore.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()

        #expect(coordinator.controller.latestMarkdownSnapshot == markdown)
        #expect(coordinator.controller.toolbarModel.characterCount == 0)

        coordinator.configure(
            pageId: "hidden-blank-appstore",
            title: "Hidden Blank App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-blank-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 2), .focusStart])
        #expect(coordinator.controller.latestMarkdownSnapshot == markdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @Test("App Store Epdoc bridge flushes survive inactive display-link starvation")
    func appStoreEpdocBridgeFlushesSurviveInactiveDisplayLinkStarvation() throws {
        let chrome = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let scheduler = try #require(sourceSection(
            in: chrome,
            startingAt: "private func scheduleOutboundFlush()",
            endingBefore: "    @objc private func handleOutboundDisplayLinkTick"
        ))
        let flush = try #require(sourceSection(
            in: chrome,
            startingAt: "private func flushOutboundQueue()",
            endingBefore: "        // No explicit deinit"
        ))
        let shutdown = try #require(sourceSection(
            in: chrome,
            startingAt: "func shutdown()",
            endingBefore: "        nonisolated func userContentController("
        ))

        #expect(scheduler.contains("outboundFallbackTask = Task { @MainActor [weak self] in"))
        #expect(scheduler.contains("Task.sleep(for: EpdocOutboundFlushPolicy.occludedFallbackDelay)"))
        #expect(scheduler.contains("guard self.outboundFlushScheduled else { return }"))
        #expect(scheduler.contains("self.flushOutboundQueue()"))
        #expect(flush.contains("outboundFallbackTask?.cancel()"))
        #expect(flush.contains("outboundFallbackTask = nil"))
        #expect(shutdown.contains("outboundFallbackTask?.cancel()"))
        #expect(shutdown.contains("outboundFallbackTask = nil"))
    }

    @Test("App Store lane recovers hidden Epdoc when WebKit snapshot is empty but host Markdown is non-empty")
    func appStoreLaneRecoversHiddenEpdocWhenWebKitSnapshotIsEmptyButHostMarkdownIsNonEmpty() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        var commands: [EpdocEditorCommand] = []
        let markdown = """
        # App Store Host Recovery Source

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        coordinator.configure(
            pageId: "appstore-empty-webkit-reactivation",
            title: "App Store Host Recovery Source",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/appstore-empty-webkit-reactivation.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()

        coordinator.controller.loadInitialContent(
            emptyJSON,
            title: "App Store Host Recovery Source",
            markdownSource: ""
        )
        commands.removeAll()

        coordinator.configure(
            pageId: "appstore-empty-webkit-reactivation",
            title: "App Store Host Recovery Source",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/appstore-empty-webkit-reactivation.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 3), .focusStart])
        #expect(coordinator.controller.latestMarkdownSnapshot == markdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @Test("App Store lane re-pushes Epdoc Markdown after WebView remount")
    func appStoreLaneRepushesEpdocMarkdownAfterWebViewRemount() {
        let controller = EpdocEditorChromeController()
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = """
        # Remount Proof

        | A | B |
        | - | - |
        | 1 | 2 |
        """
        var commands: [EpdocEditorCommand] = []

        controller.loadInitialContent(emptyJSON, title: "Remount Proof", markdownSource: markdown)
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)
        commands.removeAll()

        controller.detachEditorDispatch()
        controller.installEditorDispatch { command in
            commands.append(command)
        }
        controller.handleBridgeMessage(.editorReady)

        #expect(commands == [.setMarkdownForLoad(markdown: markdown, epoch: 2), .focusStart])
        #expect(controller.latestMarkdownSnapshot == markdown)
        #expect(!controller.toolbarModel.isDirty)
    }

    @Test("App Store lane refuses empty direct Epdoc flush over non-empty Markdown")
    func appStoreLaneRefusesEmptyDirectEpdocFlushOverNonEmptyMarkdown() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var savedMarkdown: [String] = []
        let markdown = """
        # Direct Snapshot Proof

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        coordinator.configure(
            pageId: "direct-empty-snapshot-appstore",
            title: "Direct Snapshot Proof",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/direct-empty-snapshot-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.installMarkdownSnapshotProvider {
            ""
        }
        coordinator.controller.toolbarModel.isDirty = true

        let didFlush = await coordinator.flushPendingMarkdown()

        #expect(!didFlush)
        #expect(savedMarkdown.isEmpty)
        #expect(coordinator.controller.latestMarkdownSnapshot == markdown)
        #expect(coordinator.controller.toolbarModel.isDirty)
    }

    @Test("App Store lane probes stale Epdoc stats and suppresses blank reactivation snapshots")
    func appStoreLaneProbesStaleEpdocStatsAndSuppressesBlankReactivationSnapshots() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []
        var savedJSON: [Data] = []
        let emptyJSON = #"{"type":"doc","content":[{"type":"paragraph"}]}"#.data(using: .utf8)!
        let markdown = """
        # App Store Stale Stats Reactivation Proof

        | A | B |
        | - | - |
        | 1 | 2 |
        """

        coordinator.configure(
            pageId: "hidden-stale-stats-appstore",
            title: "Hidden Stale Stats App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-stale-stats-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.onContentChanged = { savedJSON.append($0) }
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.documentStatsChanged(wordCount: 8, characterCount: 72), epoch: 1)
        commands.removeAll()

        coordinator.configure(
            pageId: "hidden-stale-stats-appstore",
            title: "Hidden Stale Stats App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-stale-stats-appstore.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.configure(
            pageId: "hidden-stale-stats-appstore",
            title: "Hidden Stale Stats App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/hidden-stale-stats-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.flushDocumentSnapshot])

        coordinator.controller.handleBridgeMessage(.contentDidChange(json: emptyJSON), epoch: 1)
        coordinator.controller.handleBridgeMessage(.markdownDidChange(markdown: "", writeback: nil), epoch: 1)

        #expect(commands == [.flushDocumentSnapshot, .setMarkdownForLoad(markdown: markdown, epoch: 2), .focusStart])
        #expect(savedMarkdown.isEmpty)
        #expect(savedJSON.isEmpty)
        #expect(coordinator.controller.latestMarkdownSnapshot == markdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @Test("App Store lane skips repeated clean Epdoc reactivation probe after verified snapshot")
    func appStoreLaneSkipsRepeatedCleanEpdocReactivationProbeAfterVerifiedSnapshot() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        let markdown = """
        # App Store Verified Reactivation

        | A | B |
        | - | - |
        | 1 | 2 |
        """
        let normalizedMarkdown = markdown.replacingOccurrences(of: "| - | - |", with: "| --- | --- |")

        coordinator.configure(
            pageId: "verified-reactivation-appstore",
            title: "Verified Reactivation App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.documentStatsChanged(wordCount: 8, characterCount: 72), epoch: 1)
        commands.removeAll()

        coordinator.configure(
            pageId: "verified-reactivation-appstore",
            title: "Verified Reactivation App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation-appstore.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.configure(
            pageId: "verified-reactivation-appstore",
            title: "Verified Reactivation App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands == [.flushDocumentSnapshot])
        coordinator.controller.handleBridgeMessage(.markdownDidChange(markdown: normalizedMarkdown, writeback: nil), epoch: 1)
        commands.removeAll()

        coordinator.configure(
            pageId: "verified-reactivation-appstore",
            title: "Verified Reactivation App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation-appstore.md",
            isEditable: true,
            isActive: false,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.configure(
            pageId: "verified-reactivation-appstore",
            title: "Verified Reactivation App Store",
            markdown: markdown,
            theme: .light,
            noteRelativePath: "notes/verified-reactivation-appstore.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(commands.isEmpty)
        #expect(coordinator.controller.latestMarkdownSnapshot == normalizedMarkdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @Test("App Store lane keeps editor typing and surface switches off heavy outline paths")
    func appStoreLaneKeepsEditorTypingAndSurfaceSwitchesOffHeavyOutlinePaths() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let codeEditor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let codeDebouncer = try loadRepoTextFile("Epistemos/Engine/CodeEditorContentDebouncer.swift")
        let coreEditorCoordinator = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift")
        let proseTextView = try loadRepoTextFile("Epistemos/Views/Notes/ProseTextView2.swift")
        let proseBridge = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")
        let prose = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        let appCoordinator = try loadRepoTextFile("Epistemos/App/AppCoordinator.swift")
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let typingRefresh = try #require(sourceSection(
            in: workspace,
            startingAt: "private func refreshVisibleEditorMetrics()",
            endingBefore: "    private func scheduleMetricsRefresh("
        ))
        let metricsRefresh = try #require(sourceSection(
            in: workspace,
            startingAt: "private func scheduleMetricsRefresh(",
            endingBefore: "    private func snapshotEditorSelection()"
        ))

        #expect(workspace.contains("static let liveTypingMetricsQuietWindow: Duration = .milliseconds(900)"))
        #expect(workspace.contains("static let liveTypingRefreshesHeavyOutlines = false"))
        #expect(workspace.contains("static let graphEmbeddedInitialRefreshesHeavyOutlines = false"))
        #expect(workspace.contains("static let nonEditOutlineOverlayEnabled = false"))
        #expect(workspace.contains("try? await Task.sleep(for: NoteWorkspacePerformancePolicy.liveTypingMetricsQuietWindow)"))
        #expect(typingRefresh.contains("includeHeavyOutlines: NoteWorkspacePerformancePolicy.liveTypingRefreshesHeavyOutlines"))
        #expect(metricsRefresh.contains("includeHeavyOutlines: Bool = true"))
        #expect(metricsRefresh.contains("if includeHeavyOutlines && deterministicOutlineState.isEnabled"))
        #expect(metricsRefresh.contains("if includeHeavyOutlines {\n                // Slice 3 cutover"))
        #expect(workspace.contains("includeHeavyOutlines: shouldRunHeavyOutlineWork(for: page)"))
        #expect(workspace.contains("private func shouldRunHeavyOutlineWork(for page: SDPage) -> Bool"))
        #expect(workspace.contains("return NoteWorkspacePerformancePolicy.graphEmbeddedInitialRefreshesHeavyOutlines"))
        #expect(workspace.contains("if let page = pages.first,\n                   shouldMountOutlineOverlay(for: page)"))
        #expect(workspace.contains("private func shouldMountOutlineOverlay(for page: SDPage) -> Bool"))
        #expect(workspace.contains("guard !presentation.usesGraphEmbeddedChrome else {\n            return false\n        }"))
        #expect(workspace.contains("return NoteWorkspacePerformancePolicy.nonEditOutlineOverlayEnabled"))
        #expect(workspace.contains("case .edit:\n            return tocItems"))
        #expect(!workspace.contains("return tocItems.isEmpty ? nil : tocItems"))
        #expect(workspace.contains("return markdownSourceFallbackContent(for: page, filePath: route.filePath)"))
        #expect(codeEditor.contains("static let textSnapshotPublishDelay: Duration = .milliseconds(140)"))
        #expect(codeEditor.contains("private func scheduleTextSnapshotPublish()"))
        #expect(codeEditor.contains("@State private var textSnapshotRevision: UInt64 = 0"))
        #expect(codeEditor.contains("guard textSnapshotTask == nil else { return }"))
        #expect(codeEditor.contains("guard scheduledRevision == textSnapshotRevision else { continue }"))
        #expect(codeEditor.contains("try? await Task.sleep(for: CodeEditorPerformancePolicy.textSnapshotPublishDelay)"))
        #expect(codeEditor.contains("scheduleTextSnapshotPublish()"))
        #expect(!codeEditor.contains("textSnapshotTask?.cancel()\n        textSnapshotTask = Task"))
        #expect(codeEditor.contains("@State private var livePreviewRevision: UInt64 = 0"))
        #expect(codeEditor.contains("guard livePreviewTask == nil else { return }"))
        #expect(codeEditor.contains("guard scheduledRevision == livePreviewRevision else { continue }"))
        #expect(codeEditor.contains("scheduleLivePreviewUpdate()"))
        #expect(!codeEditor.contains("scheduleLivePreviewUpdate(for: newText)"))
        #expect(codeEditor.contains("@State private var outlineRefreshRevision: UInt64 = 0"))
        #expect(codeEditor.contains("guard outlineRefreshTask == nil else { return }"))
        #expect(codeEditor.contains("guard scheduledRevision == outlineRefreshRevision else { continue }"))
        #expect(codeEditor.contains("scheduleOutlineRefresh()"))
        #expect(!codeEditor.contains("scheduleOutlineRefresh(for: newText)"))
        #expect(codeDebouncer.contains("defaultQuietWindowMs: Int = 900"))
        #expect(proseTextView.contains("proseReparseDebounceWindow(characterCount: Int)"))
        #expect(proseTextView.contains("case ..<80_000:\n            0.16"))
        #expect(proseTextView.contains("default:\n            0.28"))
        #expect(proseTextView.contains("deadline: .now() + debounceWindow"))
        #expect(proseTextView.contains("static let renderedTableOverlayRefreshDelay: Duration = .milliseconds(220)"))
        #expect(proseBridge.contains("private var bindingSyncRevision: UInt64 = 0"))
        #expect(proseBridge.contains("private var dataDetectionRevision: UInt64 = 0"))
        #expect(proseBridge.contains("guard bindingSyncTask == nil else { return }"))
        #expect(proseBridge.contains("guard dataDetectionTask == nil else { return }"))
        #expect(proseBridge.contains("guard scheduledRevision == bindingSyncRevision else { continue }"))
        #expect(proseBridge.contains("guard scheduledRevision == dataDetectionRevision else { continue }"))
        #expect(proseBridge.contains("debouncedBindingSync()"))
        #expect(proseBridge.contains("scheduleDataDetection()"))
        #expect(!proseBridge.contains("debouncedBindingSync(newText)"))
        #expect(!proseBridge.contains("scheduleDataDetection(newText)"))
        #expect(prose.contains("let onEditStarted: @MainActor () -> Void"))
        #expect(prose.contains("guard newValue != lastPersistedBody else { return }\n            onEditStarted()"))
        #expect(workspace.contains("themeOverride: noteWorkspaceTheme,\n                onEditStarted: {\n                    markEditorDirtyBeforeDebouncedSave()"))
        #expect(!codeEditor.contains("if isEditable {\n                    onTextSnapshot?(newText)"))
        #expect(coreEditorCoordinator.contains("const textSnapshotDelays = {"))
        #expect(coreEditorCoordinator.contains("document.addEventListener(\"input\", scheduleTextSnapshot, true);"))
        #expect(coreEditorCoordinator.contains("document.addEventListener(\"selectionchange\", scheduleMetadataSnapshot, true);"))
        #expect(coreEditorCoordinator.contains("payload.text = text;"))
        #expect(coreEditorCoordinator.contains("let contentDirty = { value: false };"))
        #expect(coreEditorCoordinator.contains("contentDirty.value = true;"))
        #expect(coreEditorCoordinator.contains("if (contentDirty.value)"))
        #expect(!coreEditorCoordinator.contains("if (contentDirty) {"))
        #expect(coreEditorCoordinator.contains("private var didReportPendingContentDirty = false"))
        #expect(coreEditorCoordinator.contains("self.onContentDirty?()"))
        #expect(workspace.contains("onEditStarted: {\n                        markDocumentEditorDirtyBeforeDebouncedSave()"))
        #expect(workspace.contains("@State private var documentEditorRevision: UInt64 = 0"))
        #expect(!coreEditorCoordinator.contains("const contentDirty = false;"))
        #expect(coreEditorCoordinator.contains("hasPendingEditorTextSnapshot"))
        #expect(!coreEditorCoordinator.contains("setInterval(() => postSnapshot(\"snapshot\"), 250);"))
        #expect(appCoordinator.contains("private var pageChangeManifestRefreshTask: Task<Void, Never>?"))
        #expect(appCoordinator.contains("case .vaultPageChanged(let pageId):\n                self.scheduleAmbientManifestRefreshAfterPageMutation()"))
        #expect(appCoordinator.contains("private func scheduleAmbientManifestRefreshAfterPageMutation()"))
        #expect(appCoordinator.contains("try? await Task.sleep(for: .seconds(2))"))
        #expect(vaultSync.contains("private var graphPageMutationRefreshTask: Task<Void, Never>?"))
        #expect(vaultSync.contains("case .vaultPageChanged:\n            scheduleGraphRefreshAfterPageMutation()"))
        #expect(vaultSync.contains("private func scheduleGraphRefreshAfterPageMutation()"))
        #expect(!vaultSync.contains("private func publishVaultMutation(_ event: AppEvent) {\n        vaultMutationEpoch &+= 1\n        AppBootstrap.shared?.graphState.needsRefresh = true"))
    }

    @Test("App Store lane clears stale clean lens snapshots after persisted reload")
    func appStoreLaneClearsStaleCleanLensSnapshotsAfterPersistedReload() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let refresh = try #require(sourceSection(
            in: workspace,
            startingAt: "private func schedulePersistedBodyRefresh(for page: SDPage?)",
            endingBefore: "    private func persistedBodyFor("
        ))
        let invalidator = try #require(sourceSection(
            in: workspace,
            startingAt: "private func clearCleanModeBodySnapshotIfStale",
            endingBefore: "    private func persistedBodyFor("
        ))

        #expect(refresh.contains("modeBodySnapshot = nil"))
        #expect(refresh.contains("clearCleanModeBodySnapshotIfStale(for: pageId, reloadedBody: body)"))
        #expect(invalidator.contains("snapshot.pageId == pageId"))
        #expect(invalidator.contains("snapshot.body != reloadedBody"))
        #expect(invalidator.contains("let isEmptySnapshotOverLoadedBody = snapshot.body.isEmpty && !reloadedBody.isEmpty"))
        #expect(invalidator.contains("guard isEmptySnapshotOverLoadedBody || !noteSession.state.needsWriteLease else"))
        #expect(invalidator.contains("modeBodySnapshot = nil"))
    }

    @Test("App Store lane renders local editor sessions editable before onAppear")
    func appStoreLaneRendersLocalEditorSessionsEditableBeforeOnAppear() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let sessionMachine = try loadRepoTextFile("Epistemos/Views/Notes/NoteSessionStateMachine.swift")
        let focusedTests = try loadRepoTextFile("EpistemosTests/NoteSessionStateMachineTests.swift")
        let inputGate = try #require(sourceSection(
            in: workspace,
            startingAt: "private var editorSurfacesAcceptInput: Bool",
            endingBefore: "    private func shouldMountOutlineOverlay"
        ))

        #expect(inputGate.contains("noteSession.canWrite || noteSession.currentOwnerID == nil"))
        #expect(workspace.contains("isEditable: editorSurfacesAcceptInput"))
        #expect(!workspace.contains("isEditable: noteSession.canWrite"))
        #expect(workspace.contains("noteSession.configureLeaseStore("))
        #expect(workspace.contains("_ = noteSession.open()"))
        #expect(workspace.contains("@State private var noteSessionLifecycleGeneration: UInt64 = 0"))
        #expect(workspace.contains("noteSessionLifecycleGeneration &+= 1"))
        #expect(workspace.contains("let teardownGeneration = noteSessionLifecycleGeneration"))
        #expect(workspace.contains("guard noteSessionLifecycleGeneration == teardownGeneration else { return }"))
        #expect(workspace.contains("_ = noteSession.open()\n                _ = noteSession.acquireCleanLeaseHandoffIfAvailable()"))
        #expect(!workspace.contains("if presentation.usesGraphEmbeddedChrome {\n                    _ = noteSession.acquireCleanLeaseHandoffIfAvailable()"))
        #expect(workspace.contains("guard beginNoteSessionWrite(reason: .idleDebounce) else { return }"))
        #expect(workspace.contains("private func beginNoteSessionWrite(reason: NoteSessionSaveReason) -> Bool"))
        #expect(sessionMachine.contains("func registerSession(_ session: NoteSessionStateMachine)"))
        #expect(sessionMachine.contains("func acquireCleanLeaseHandoffIfAvailable() -> Bool"))
        #expect(sessionMachine.contains("func acquireOrHandoffCleanOwner("))
        #expect(sessionMachine.contains("ownerCanHandoffCleanly(noteID: noteID, ownerID: owner)"))
        #expect(sessionMachine.contains("refreshRegisteredSessions(for: noteID)"))
        #expect(sessionMachine.contains("clearInactiveStoredOwnerIfNeeded(noteID: noteID, sessionID: sessionID, store: store)"))
        #expect(sessionMachine.contains("activeSessionIDs"))
        #expect(sessionMachine.contains("activeSessionIDs.remove(ownerID)"))
        #expect(sessionMachine.contains("return false"))
        #expect(sessionMachine.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX"))
        #expect(sessionMachine.contains("MAS relaunches must not trust a persisted owner solely because a PID"))
        #expect(sessionMachine.contains("sessionID: String = NoteSessionLeaseRegistry.makeSessionID()"))
        #expect(focusedTests.contains("relaunchReclaimsOrphanedPersistedLeaseSoSourceStaysEditable"))
        #expect(focusedTests.contains("deallocatedCleanOwnerDoesNotKeepGraphSourceEditorsReadOnly"))
        #expect(focusedTests.contains("legacy-orphan"))
        #expect(sessionMachine.contains("resetInMemoryLeaseRegistryForTests"))
    }

    @Test("App Store lane retries restored Source reads after vault restore")
    func appStoreLaneRetriesRestoredSourceReadsAfterVaultRestore() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let refresh = try #require(sourceSection(
            in: workspace,
            startingAt: "private func scheduleCodeFileBodyRefresh(for page: SDPage?)",
            endingBefore: "    private func currentSourceRouteMatches(pageId: String, filePath: String) -> Bool"
        ))

        #expect(workspace.contains(".onChange(of: vaultSync.vaultURL?.standardizedFileURL.path)"))
        #expect(workspace.contains("schedulePersistedBodyRefresh(for: pages.first)\n                scheduleCodeFileBodyRefresh(for: pages.first)"))
        #expect(refresh.contains("guard let vaultURL = vaultSync.vaultURL else"))
        #expect(refresh.contains("codeFileBodySnapshot = CodeFileBodySnapshot"))
        #expect(!refresh.contains("refusing async code file read with no active vault"))
        #expect(refresh.contains("CodeFileService.readCodeFileAsync("))
        #expect(workspace.contains("let currentRoute = sourceEditorRoute(for: currentPage)"))
        #expect(!workspace.contains("let currentRoute = sourceFileRoute(for: currentPage)"))
    }

    @Test("App Store lane reclaims orphaned Source lease after relaunch")
    func appStoreLaneReclaimsOrphanedSourceLeaseAfterRelaunch() throws {
        NoteSessionStateMachine.resetLeaseRegistryForTests()
        let queue = try DatabaseQueue()
        let store = NoteSessionGRDBLeaseStore(databaseWriter: queue)

        let firstLaunch = NoteSessionStateMachine(noteID: "appstore-note-relaunch", sessionID: "legacy-orphan")
        firstLaunch.configureLeaseStore(store)
        #expect(firstLaunch.open())
        #expect(try store.ownerID(for: "appstore-note-relaunch") == "legacy-orphan")

        NoteSessionStateMachine.resetInMemoryLeaseRegistryForTests()

        let secondLaunch = NoteSessionStateMachine(noteID: "appstore-note-relaunch", sessionID: "second-launch")
        secondLaunch.configureLeaseStore(store)
        #expect(secondLaunch.open())
        #expect(secondLaunch.canWrite)
        #expect(try store.ownerID(for: "appstore-note-relaunch") == "second-launch")
    }

    @Test("App Store lane reclaims pid-shaped persisted Source lease after relaunch")
    func appStoreLaneReclaimsPidShapedPersistedSourceLeaseAfterRelaunch() throws {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        NoteSessionStateMachine.resetLeaseRegistryForTests()
        let queue = try DatabaseQueue()
        let store = NoteSessionGRDBLeaseStore(databaseWriter: queue)
        let oldOwner = "epistemos:\(ProcessInfo.processInfo.processIdentifier):stale-owner-from-previous-launch"

        let firstLaunch = NoteSessionStateMachine(noteID: "appstore-note-pid-relaunch", sessionID: oldOwner)
        firstLaunch.configureLeaseStore(store)
        #expect(firstLaunch.open())
        #expect(try store.ownerID(for: "appstore-note-pid-relaunch") == oldOwner)

        NoteSessionStateMachine.resetInMemoryLeaseRegistryForTests()

        let secondLaunch = NoteSessionStateMachine(noteID: "appstore-note-pid-relaunch", sessionID: "second-launch")
        secondLaunch.configureLeaseStore(store)
        #expect(secondLaunch.open())
        #expect(secondLaunch.canWrite)
        #expect(try store.ownerID(for: "appstore-note-pid-relaunch") == "second-launch")
        #else
        #expect(true)
        #endif
    }

    @Test("App Store lane lets graph embedded editor take a clean active lease")
    func appStoreLaneLetsGraphEmbeddedEditorTakeCleanActiveLease() {
        NoteSessionStateMachine.resetLeaseRegistryForTests()

        let owner = NoteSessionStateMachine(noteID: "appstore-note-clean-handoff", sessionID: "owner")
        let graph = NoteSessionStateMachine(noteID: "appstore-note-clean-handoff", sessionID: "graph")

        #expect(owner.open())
        #expect(!graph.open())
        #expect(graph.acquireCleanLeaseHandoffIfAvailable())
        #expect(!owner.canWrite)
        #expect(graph.canWrite)
    }

    @Test("App Store lane reclaims deallocated graph editor owner so Source stays editable")
    func appStoreLaneReclaimsDeallocatedGraphEditorOwnerSoSourceStaysEditable() {
        NoteSessionStateMachine.resetLeaseRegistryForTests()

        var owner: NoteSessionStateMachine? = NoteSessionStateMachine(
            noteID: "appstore-note-deallocated-owner",
            sessionID: "owner"
        )
        #expect(owner?.open() == true)
        owner = nil

        let graph = NoteSessionStateMachine(
            noteID: "appstore-note-deallocated-owner",
            sessionID: "graph"
        )
        #expect(graph.open())
        #expect(graph.canWrite)
    }

    @Test("App Store lane blocks graph embedded editor while owner is dirty")
    func appStoreLaneBlocksGraphEmbeddedEditorWhileOwnerIsDirty() {
        NoteSessionStateMachine.resetLeaseRegistryForTests()

        let owner = NoteSessionStateMachine(noteID: "appstore-note-dirty-handoff", sessionID: "owner")
        let graph = NoteSessionStateMachine(noteID: "appstore-note-dirty-handoff", sessionID: "graph")

        #expect(owner.open())
        _ = owner.recordUserEdit(source: .user)
        #expect(!graph.open())
        #expect(!graph.acquireCleanLeaseHandoffIfAvailable())
        #expect(owner.canWrite)
        #expect(!graph.canWrite)
    }

    @Test("App Store lane debounces transclusion overlay refreshes during prose typing")
    func appStoreLaneDebouncesTransclusionOverlayRefreshesDuringProseTyping() throws {
        let transclusion = try loadRepoTextFile("Epistemos/Views/Notes/TransclusionOverlayManager2.swift")
        let proseTextView = try loadRepoTextFile("Epistemos/Views/Notes/ProseTextView2.swift")
        let refreshAfterTextChange = try #require(sourceSection(
            in: transclusion,
            startingAt: "func refreshAfterTextChange()",
            endingBefore: "    func refreshForScroll()"
        ))
        let removeAll = try #require(sourceSection(
            in: transclusion,
            startingAt: "func removeAll()",
            endingBefore: "    private func configureOverlay("
        ))

        #expect(proseTextView.contains("static let transclusionOverlayRefreshDelay: Duration = .milliseconds(160)"))
        #expect(transclusion.contains("private var textChangeRefreshTask: Task<Void, Never>?"))
        #expect(refreshAfterTextChange.contains("textChangeRefreshTask?.cancel()"))
        #expect(refreshAfterTextChange.contains("Task.sleep(for: NoteEditorPerformancePolicy.transclusionOverlayRefreshDelay)"))
        #expect(refreshAfterTextChange.contains("self.refresh(recalculateDocumentState: true)"))
        #expect(!refreshAfterTextChange.contains("\n        refresh(recalculateDocumentState: true)"))
        #expect(removeAll.contains("textChangeRefreshTask?.cancel()"))
    }

    @Test("App Store lane skips unchanged Source snapshots before rewriting parent state")
    func appStoreLaneSkipsUnchangedSourceSnapshotsBeforeRewritingParentState() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let snapshot = try #require(sourceSection(
            in: workspace,
            startingAt: "private func recordSourceEditorSnapshot(page: SDPage, filePath: String, content: String)",
            endingBefore: "    @discardableResult\n    private func persistMarkdownSourceEditorContent("
        ))

        #expect(snapshot.contains("let existingSourceBody = codeFileBodySnapshot?.body(ifMatches: page.id, filePath: filePath)"))
        #expect(snapshot.contains("if existingSourceBody != content"))
        #expect(snapshot.contains("guard modeBodySnapshot?.body(ifMatches: page.id) != persistedContent.body else { return }"))
        #expect(snapshot.contains("modeBodySnapshot = NoteModeBodySnapshot(pageId: page.id, body: persistedContent.body)"))
    }

    @Test("App Store Source saves replace stale frontmatter snapshots with canonical page state")
    func appStoreSourceSavesReplaceStaleFrontmatterSnapshotsWithCanonicalPageState() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let sourceSave = try #require(sourceSection(
            in: workspace,
            startingAt: "private func persistMarkdownSourceEditorContent(",
            endingBefore: "    @discardableResult\n    private func saveMarkdownDocumentSurfaceContent"
        ))

        #expect(sourceSave.contains("persistedBody = persistedSourceBody"))
        #expect(sourceSave.contains("modeBodySnapshot = NoteModeBodySnapshot(pageId: pageId, body: persistedSourceBody)"))
        #expect(sourceSave.contains("refreshMarkdownSourceSnapshot(for: page)"))
        #expect(!sourceSave.contains("body: content"))
    }

    @Test("App Store Source title renames keep editor identity stable and reject stale captured paths")
    func appStoreSourceTitleRenamesKeepEditorIdentityStableAndRejectStaleCapturedPaths() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let sourceSurface = try #require(sourceSection(
            in: workspace,
            startingAt: "private func noteNonDocumentEditorSurface(page: SDPage, availableSize: CGSize)",
            endingBefore: "    /// Saves code file content back to disk"
        ))
        let sourceSave = try #require(sourceSection(
            in: workspace,
            startingAt: "private func persistMarkdownSourceEditorContent(",
            endingBefore: "    @discardableResult\n    private func saveMarkdownDocumentSurfaceContent"
        ))

        #expect(sourceSurface.contains(".id(page.id)"))
        #expect(!sourceSurface.contains(".id(\"\\(page.id)::\\(route.filePath)\")"))
        #expect(!sourceSave.contains("page.filePath = filePath"))
    }

    @Test("App Store lane does not double-schedule block mirrors before file-first saves")
    func appStoreLaneAvoidsDuplicateBlockMirrorWorkBeforeFileFirstSaves() throws {
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let prose = try loadRepoTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        let noteDraftStore = try loadRepoTextFile("Epistemos/Sync/NoteDraftStore.swift")
        let vaultSync = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let documentSave = try #require(sourceSection(
            in: workspace,
            startingAt: "private func saveMarkdownDocumentSurfaceContent(page: SDPage, markdown: String) async -> Bool",
            endingBefore: "    private func codeFileServiceForActiveVault("
        ))
        #expect(documentSave.contains("let editorRevision = documentEditorRevision"))
        #expect(documentSave.contains("if documentEditorRevision == editorRevision"))
        #expect(documentSave.contains("_ = noteSession.recordUserEdit(source: .user)"))
        let markdownSourceSave = try #require(sourceSection(
            in: workspace,
            startingAt: "private func persistMarkdownSourceEditorContent(",
            endingBefore: "    @discardableResult\n    private func saveMarkdownDocumentSurfaceContent"
        ))
        let editorFlush = try #require(sourceSection(
            in: workspace,
            startingAt: "private func flushCurrentEditor(reason: NoteSessionSaveReason = .explicitSave) async -> NoteEditorFlushResult",
            endingBefore: "    @discardableResult\n    private func beginNoteSessionWrite("
        ))
        let proseSave = try #require(sourceSection(
            in: prose,
            startingAt: "private func debouncedSave(_ newValue: String)",
            endingBefore: "    /// NOTE-4"
        ))
        let fileFirstSave = try #require(sourceSection(
            in: vaultSync,
            startingAt: "func savePageBodyFileFirst(pageId: String, body: String) async -> Bool",
            endingBefore: "    @discardableResult\n    func recoverDraftIfNewer"
        ))

        #expect(documentSave.contains("vaultSync.savePageBodyFileFirst(pageId: pageId, body: markdown)"))
        #expect(markdownSourceSave.contains("vaultSync.savePageBodyFileFirst(pageId: pageId, body: persistedSourceBody)"))
        #expect(markdownSourceSave.contains("persistedContent.applyMarkdownNoteState(to: page)"))
        #expect(editorFlush.contains("vaultSync.savePageBodyFileFirst(pageId: pageId, body: fullText)"))
        #expect(proseSave.contains("vaultSync.savePageBodyFileFirst(pageId: pageId, body: newValue)"))
        #expect(proseSave.contains("NoteDraftStore.deleteIfMatching(pageId: pageId, durableBody: newValue)"))
        #expect(noteDraftStore.contains("private static let fileLock = NSLock()"))
        #expect(noteDraftStore.contains("draftMatchesDurableBody(draftBody, durableBody: durableBody)"))
        #expect(!noteDraftStore.contains("!draftBody.isEmpty else { continue }"))
        #expect(noteDraftStore.contains("_ = deleteIfMatching(pageId: pageId, durableBody: draftBody)"))
        #expect(!noteDraftStore.contains("defer { try? FileManager.default.removeItem(at: item) }"))
        #expect(!documentSave.contains("stageBodyWrite(pageId: pageId, fullText: markdown)"))
        #expect(!markdownSourceSave.contains("stageBodyWrite(pageId: pageId, fullText: persistedSourceBody)"))
        #expect(!editorFlush.contains("stageBodyWrite(pageId: pageId, fullText: fullText)"))
        #expect(!documentSave.contains("try modelContext.save()"))
        #expect(!markdownSourceSave.contains("try modelContext.save()"))
        #expect(!editorFlush.contains("try modelContext.save()"))
        #expect(!proseSave.contains("page.applyInteractiveDerivedState(from: newValue)"))
        #expect(!proseSave.contains("scheduleBlockMirrorSync(pageId: pageId, body: newValue)"))
        #expect(!proseSave.contains("saveModelContext(reason: \"debounced save"))
        #expect(!documentSave.contains("BlockMirrorSyncCoordinator.shared.scheduleSync("))
        #expect(!markdownSourceSave.contains("BlockMirrorSyncCoordinator.shared.scheduleSync("))
        #expect(!markdownSourceSave.contains("CodeFileService.updateCodeFileAsync("))
        #expect(!markdownSourceSave.contains("vaultSync.savePage(pageId: pageId)"))
        #expect(!editorFlush.contains("BlockMirrorSyncCoordinator.shared.scheduleSync("))
        #expect(fileFirstSave.contains("scheduleBlockMirrorSync(pageId: pageId, body: stagedBody)"))
        #expect(fileFirstSave.contains("page.applyInteractiveDerivedState(from: stagedBody)"))
        #expect(fileFirstSave.contains("page.updatedAt = .now"))
        let exportIndex = try #require(fileFirstSave.range(of: "exportPage(pageId: pageId, to: vaultURL, bodyOverride: stagedBody)"))
        let derivedIndex = try #require(fileFirstSave.range(of: "page.applyInteractiveDerivedState(from: stagedBody)"))
        let titleIndex = try #require(fileFirstSave.range(of: "ProseEditorView.syncNoteTitleIfNeeded("))
        let saveIndex = try #require(fileFirstSave.range(of: "try context.save()"))
        let mirrorIndex = try #require(fileFirstSave.range(of: "scheduleBlockMirrorSync(pageId: pageId, body: stagedBody)"))
        #expect(exportIndex.lowerBound < derivedIndex.lowerBound)
        #expect(exportIndex.lowerBound < titleIndex.lowerBound)
        #expect(exportIndex.lowerBound < saveIndex.lowerBound)
        #expect(exportIndex.lowerBound < mirrorIndex.lowerBound)
        #expect(!fileFirstSave.contains("BlockMirror.sync(pageId: pageId, body: stagedBody"))
        #expect(vaultSync.contains("BlockMirrorSyncCoordinator.shared.scheduleSync("))
    }

    @Test("App Store lane keeps dirty graph rebuilds out of graph startup")
    func appStoreLaneDefersDirtyGraphRebuildsOffGraphStartup() throws {
        let graphState = try loadRepoTextFile("Epistemos/Graph/GraphState.swift")
        let graphStore = try loadRepoTextFile("Epistemos/Graph/GraphStore.swift")
        let backgroundTests = try loadRepoTextFile("EpistemosTests/BackgroundGraphLoadingTests.swift")
        let appSource = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let controller = try loadRepoTextFile("Epistemos/Views/Graph/HologramController.swift")
        let sidebar = try loadRepoTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        let embedded = try loadRepoTextFile("Epistemos/Views/Home/HomeGraphEmbeddedView.swift")
        let metalGraph = try loadRepoTextFile("Epistemos/Views/Graph/MetalGraphView.swift")
        let overlay = try loadRepoTextFile("Epistemos/Views/Graph/HologramOverlay.swift")
        let loadGraph = try #require(sourceSection(
            in: graphState,
            startingAt: "func loadGraph(container: ModelContainer) async",
            endingBefore: "    /// Synchronous load for callers"
        ))
        let structuralRefresh = try #require(sourceSection(
            in: graphState,
            startingAt: "func refreshStructuralDataAsync(container: ModelContainer) async -> Bool",
            endingBefore: "    private func applyIncrementalStructuralRefresh("
        ))
        let openNode = try #require(sourceSection(
            in: graphState,
            startingAt: "func openNode(_ id: String)",
            endingBefore: "    func openNote(_ sourceId: String)"
        ))
        let ensureOverlay = try #require(sourceSection(
            in: controller,
            startingAt: "private func ensureOverlay(autoLoadGraph: Bool = true)",
            endingBefore: "    private func loadGraphForDocumentRevealIfNeeded() async"
        ))
        let routeLeave = try #require(sourceSection(
            in: overlay,
            startingAt: "graphOpenStartTask?.cancel()",
            endingBefore: "        // Leaving canvas (note / folder route)"
        ))
        let routeVisibilitySync = try #require(sourceSection(
            in: overlay,
            startingAt: "private func syncGraphWorkspaceChromeVisibility(isCanvas: Bool)",
            endingBefore: "    // MARK: - Fullscreen Handling"
        ))
        let pinnedPanelTimerStart = try #require(sourceSection(
            in: overlay,
            startingAt: "private func startPinnedPanelTimer()",
            endingBefore: "    private func stopPinnedPanelTimer()"
        ))
        let embeddedRouteSync = try #require(sourceSection(
            in: embedded,
            startingAt: "private func syncEmbeddedRouteState(_ route: GraphWorkspaceRoute)",
            endingBefore: "    private func scheduleEmbeddedCanvasStart()"
        ))
        let sidebarRefresh = try #require(sourceSection(
            in: sidebar,
            startingAt: "private func refreshGraphSidebarCachesIfNeeded()",
            endingBefore: "    private var notesContent: some View"
        ))
        let bootstrapCommit = try #require(sourceSection(
            in: metalGraph,
            startingAt: "switch graphInitialRenderBootstrapState(",
            endingBefore: "        // Sync force params"
        ))
        let fullRecommit = try #require(sourceSection(
            in: metalGraph,
            startingAt: "        // Re-commit graph data when mode/filter changes",
            endingBefore: "        flushPendingInteractionInputs(engine: engine)"
        ))
        let scheduleFullCommit = try #require(sourceSection(
            in: metalGraph,
            startingAt: "private func scheduleFullGraphCommitIfNeeded(",
            endingBefore: "    private func applyPostFullCommitCameraAction"
        ))
        let viewWindowCommit = try #require(sourceSection(
            in: metalGraph,
            startingAt: "override func viewDidMoveToWindow()",
            endingBefore: "    private func refreshWindowObservers()"
        ))
        let fullOverlayCommit = try #require(sourceSection(
            in: overlay,
            startingAt: "        // Commit graph data after window is set up.",
            endingBefore: "        // Observe system appearance changes so the graph reacts"
        ))

        #expect(graphState.contains("func deferStructuralRefreshUntilGraphIsVisible()"))
        #expect(graphState.contains("pendingRebuild = true"))
        #expect(openNode.contains("case .note, .person, .project, .topic, .decision, .event, .resource:"))
        #expect(openNode.contains("selectNode(nil)\n            openNote(resolvedId)"))
        #expect(openNode.contains("case .folder:\n            selectNode(nil)\n            openFolder(resolvedId)"))
        #expect(!openNode.contains("case .person:\n            selectNode(id)"))
        #expect(!openNode.contains("case .resource:\n            selectNode(id)"))
        #expect(metalGraph.contains("GraphSurfaceInlineEditability.opensInlineToday(node.type)"))
        #expect(metalGraph.contains("contextOpenNode("))
        #expect(metalGraph.contains("graphState?.openNode(nodeId)"))
        #expect(metalGraph.contains("graphState?.openNode(uuid)"))
        #expect(!metalGraph.contains("graphState?.requestEditorMode = true\n        graphState?.selectNode(uuid)"))
        #expect(loadGraph.contains("if store.nodeCount == 0, !isBuildingStructural"))
        #expect(loadGraph.contains("deferStructuralRefreshUntilGraphIsVisible()"))
        #expect(!loadGraph.contains("if (needsRefresh || store.nodeCount == 0)"))
        #expect(structuralRefresh.contains("await store.loadFromRecordsCooperatively("))
        #expect(!structuralRefresh.contains("store.loadFromRecords(nodeRecords: records.nodes, edgeRecords: records.edges)"))
        #expect(graphStore.contains("let createdOrderTask = Task.detached(priority: .utility)"))
        #expect(graphStore.contains("_nodeIdsByCreatedAtDesc = await createdOrderTask.value"))
        #expect(backgroundTests.contains("func cooperativeRecordLoadingPreservesNewestFirstOrder()"))
        #expect(ensureOverlay.contains("if autoLoadGraph, hasActiveVault, needsRefresh, graphState.isLoaded"))
        #expect(ensureOverlay.contains("graphState.deferStructuralRefreshUntilGraphIsVisible()"))
        #expect(!ensureOverlay.contains("refreshStructuralDataAsync(container: modelContainer)"))
        #expect(appSource.contains("private static func ensureEmbeddedGraphLoadStarted(bootstrap: AppBootstrap)"))
        #expect(appSource.contains("ensureEmbeddedGraphLoadStarted(bootstrap: bootstrap)"))
        #expect(appSource.contains("Task(priority: .utility) {\n                await graphState.loadGraph(container: modelContainer)\n            }"))
        #expect(appSource.contains("graphState.deferStructuralRefreshUntilGraphIsVisible()"))
        #expect(routeLeave.contains("graphState.cancelOverlayPhysicsCycle()"))
        #expect(routeLeave.contains("metalView?.pauseEngine()"))
        #expect(routeLeave.contains("graphState.selectNode(nil)"))
        #expect(routeLeave.contains("inspectorState.clearSelection()"))
        #expect(routeVisibilitySync.contains("if isCanvas {\n            startPinnedPanelTimer()"))
        #expect(routeVisibilitySync.contains("stopPinnedPanelTimer()"))
        #expect(pinnedPanelTimerStart.contains("guard graphState.currentRoute.isCanvas else"))
        #expect(pinnedPanelTimerStart.contains("stopPinnedPanelTimer()"))
        #expect(embeddedRouteSync.contains("graphState.cancelOverlayPhysicsCycle()"))
        #expect(embeddedRouteSync.contains("quiesceEmbeddedInspectorWork()"))
        #expect(embedded.contains("private func quiesceEmbeddedInspectorWork()"))
        #expect(embedded.contains("graphState.selectNode(nil)\n        inspectorState.clearSelection()"))
        #expect(sidebar.contains("struct HologramSidebarCacheSnapshot: Sendable"))
        #expect(sidebar.contains("guard graphState.currentRoute.isCanvas else { return }"))
        #expect(sidebar.contains(".onChange(of: graphState.currentRoute) { _, route in"))
        #expect(sidebar.contains("cacheBuildTask?.cancel()"))
        #expect(sidebar.contains("updateGraphSearchResultsIfNeeded(for: queryText)"))
        #expect(sidebarRefresh.contains("let nodeRecords = Array(graphState.store.nodes.values)"))
        #expect(sidebarRefresh.contains("let edgeRecords = Array(graphState.store.edges.values)"))
        #expect(sidebarRefresh.contains("cacheBuildTask = Task(priority: .utility)"))
        #expect(sidebarRefresh.contains("await Task.yield()"))
        #expect(sidebarRefresh.contains("Task.detached(priority: .utility)"))
        #expect(sidebarRefresh.contains("HologramSidebarNotesTreeBuilder.buildCache("))
        #expect(!sidebarRefresh.contains("cachedNotesTreeSnapshot = HologramSidebarNotesTreeBuilder.build(store: graphState.store)"))
        #expect(metalGraph.contains("nonisolated struct GraphFullCommitPayload: Sendable"))
        #expect(metalGraph.contains("private var pendingFullGraphCommitVersion: Int?"))
        #expect(metalGraph.contains("private func scheduleFullGraphCommitIfNeeded("))
        #expect(metalGraph.contains("func scheduleGraphDataCommitIfNeeded(\n        isPageMode: Bool,\n        zoomToPageAfterCommit: Bool = false"))
        #expect(metalGraph.contains("Task.detached(priority: .utility)"))
        #expect(metalGraph.contains("makeVisibleNodeBatchPayloadFromSnapshot("))
        #expect(metalGraph.contains("makeVisibleEdgeBatchPayloadFromSnapshot("))
        #expect(scheduleFullCommit.contains("if pendingFullGraphCommitVersion == graphDataVersion"))
        #expect(scheduleFullCommit.contains("needsRender = false"))
        #expect(scheduleFullCommit.contains("pendingFullGraphCommitVersion = graphDataVersion"))
        #expect(bootstrapCommit.contains("scheduleFullGraphCommitIfNeeded(graphState: graphState, isPageMode: isPageMode)"))
        #expect(!bootstrapCommit.contains("commitGraphData()"))
        #expect(fullRecommit.contains("postCommitCameraAction: cameraAction"))
        #expect(!fullRecommit.contains("commitGraphData()"))
        #expect(viewWindowCommit.contains("scheduleGraphDataCommitIfNeeded(isPageMode: isPageMode)"))
        #expect(!viewWindowCommit.contains("commitGraphData()"))
        #expect(overlay.contains("graphView.scheduleGraphDataCommitIfNeeded(isPageMode:"))
        #expect(!overlay.contains("graphView.commitGraphData()"))
        #expect(fullOverlayCommit.contains("graphView.setAnchorRect(frame)"))
        #expect(fullOverlayCommit.contains("zoomToPageAfterCommit: isPageMode"))
        #expect(!fullOverlayCommit.contains("graphView.zoomInClose()"))
    }

    @Test("App Store Markdown Document dirty switch saves direct editor snapshot")
    func appStoreMarkdownDocumentDirtySwitchSavesDirectEditorSnapshot() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "appstore-fresh-snapshot-page",
            title: "App Store Fresh Snapshot Page",
            markdown: "Alpha\n",
            theme: .light,
            noteRelativePath: "notes/appstore-fresh-snapshot.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.installMarkdownSnapshotProvider {
            "Alpha typed before lens switch\n"
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        coordinator.controller.handleBridgeMessage(
            .contentDidChange(
                json:
                #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Alpha typed before lens switch"}]}]}"#
                    .data(using: .utf8)!
            ),
            epoch: 1
        )
        commands.removeAll()

        let flushed = await coordinator.flushPendingMarkdown()

        #expect(flushed)
        #expect(savedMarkdown == ["Alpha typed before lens switch\n"])
        #expect(commands.isEmpty)
    }

    @Test("App Store Markdown Document pending snapshot switches without webview snapshot flush")
    func appStoreMarkdownDocumentPendingSnapshotSwitchSkipsWebViewSnapshotFlush() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []
        var directSnapshotRequests = 0

        coordinator.configure(
            pageId: "appstore-pending-snapshot-page",
            title: "App Store Pending Snapshot Page",
            markdown: "Alpha\n",
            theme: .light,
            noteRelativePath: "notes/appstore-pending-snapshot.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.installMarkdownSnapshotProvider {
            directSnapshotRequests += 1
            return "Snapshot request should not be needed\n"
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()

        coordinator.controller.handleBridgeMessage(
            .markdownDidChange(markdown: "Alpha typed before lens switch\n", writeback: nil),
            epoch: 1
        )
        let flushed = await coordinator.flushPendingMarkdown()

        #expect(flushed)
        #expect(savedMarkdown == ["Alpha typed before lens switch\n"])
        #expect(directSnapshotRequests == 0)
        #expect(commands.isEmpty)
    }

    @Test("App Store Markdown Document clean switch does not save normalized table snapshot")
    func appStoreMarkdownDocumentCleanSwitchDoesNotSaveNormalizedTableSnapshot() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        var commands: [EpdocEditorCommand] = []
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "appstore-clean-switch-page",
            title: "App Store Clean Switch Page",
            markdown: "| A | B |\n| - | - |\n| 1 | 2 |\n",
            theme: .light,
            noteRelativePath: "notes/appstore-clean-switch.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.installMarkdownSnapshotProvider {
            "| A | B |\n| --- | --- |\n| 1 | 2 |\n"
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        commands.removeAll()

        let flushed = await coordinator.flushPendingMarkdown()

        #expect(flushed)
        #expect(savedMarkdown.isEmpty)
        #expect(commands.isEmpty)
    }

    @Test("App Store lane parks Codex account backend and local session import")
    func appStoreLaneParksCodexAccountBackendAndLocalSessionImport() throws {
        let authService = try loadRepoTextFile("Epistemos/Engine/CloudProviderAuthService.swift")
        let inference = try loadRepoTextFile("Epistemos/State/InferenceState.swift")
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let skills = try loadRepoTextFile("Epistemos/Vault/SkillDiscoveryCatalog.swift")
        let openAIProvider = try loadRepoTextFile("agent_core/src/providers/openai.rs")
        let bridge = try loadRepoTextFile("agent_core/src/bridge.rs")
        let scan = try loadRepoTextFile("scripts/scan_appstore_bundle.sh")
        let gate = try loadRepoTextFile("scripts/keelstone-release-gate.sh")

        #expect(authService.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"))
        #expect(authService.contains("throw CloudProviderAuthError.unsupportedOAuthProvider(.openAI)"))
        #expect(inference.contains("OpenAI local account import is unavailable in the App Store build"))
        #expect(inference.contains("private var openAIUsesCodexAccountRuntime: Bool"))
        #expect(inference.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX\n        false"))
        #expect(bootstrap.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"))
        #expect(bootstrap.contains("overrides[\"OPENAI_AUTH_MODE\"] = \"codex\""))
        #expect(settings.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)\n            if provider == .openAI"))
        #expect(settings.contains("ForEach(inference.cloudModels(for: provider), id: \\.self)"))
        #expect(skills.contains("#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)"))
        #expect(openAIProvider.contains("#[cfg(feature = \"mas-build\")]\n    fn from_env"))
        #expect(openAIProvider.contains("fn resolve_openai_auth(api_key: String) -> OpenAIAuth"))
        #expect(openAIProvider.contains("#[cfg(not(feature = \"mas-build\"))]\nconst OPENAI_CODEX_RESPONSES_API"))
        #expect(bridge.contains("#[cfg(not(feature = \"mas-build\"))]\n        \"openai_gpt53_codex\""))
        #expect(scan.contains("\\.codex/(auth|models_cache)\\.json"))
        #expect(scan.contains("backend-api/codex"))
        #expect(scan.contains("\\.claude/\\.credentials\\.json"))
        #expect(scan.contains("claude-cli/[0-9]"))
        #expect(scan.contains("platform\\.claude\\.com/v1/oauth/token"))
        #expect(gate.contains("require_appstore_no_parked_account_runtime_markers"))
    }

    @Test("App Store Settings coalesces rapid sidebar detail construction")
    func appStoreSettingsCoalescesRapidSidebarDetailConstruction() throws {
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/SettingsView.swift")

        #expect(settings.contains("@State private var detailSelection: SettingsSection?"))
        #expect(settings.contains(".task(id: selection)"))
        #expect(settings.contains("SettingsDetailNavigationPolicy.debounceMilliseconds"))
        #expect(settings.contains("switch SettingsSection.safeDetailSelection(for: detailSelection)"))
        #expect(settings.contains("transaction.disablesAnimations = true"))
    }

    @Test("App Store lane owns a visible read-aloud surface path")
    func appStoreLaneOwnsVisibleReadAloudSurfacePath() throws {
        let registry = try loadRepoTextFile("Epistemos/Engine/EpistemosVisibleReadAloud.swift")
        let helper = try loadRepoTextFile("Epistemos/Engine/EpistemosAgentReadAloud.swift")
        let readAloud = try loadRepoTextFile("Epistemos/Views/Shared/ReadAloudButton.swift")
        let juneSurface = try loadRepoTextFile("Epistemos/JuneAgent/JuneAgentSurfaceView.swift")
        let juneNav = try loadRepoTextFile("Epistemos/JuneAgent/JuneAgentNavBar.swift")
        let juneBridge = try loadRepoTextFile("Epistemos/JuneAgent/JuneAgentBridge.swift")
        let prose = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let codeEditor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let epdoc = try loadRepoTextFile("Epistemos/Views/Epdoc/EpdocBubbleMenuView.swift")
        let quickCapture = try loadRepoTextFile("Epistemos/Views/Capture/QuickCaptureView.swift")
        let meeting = try loadRepoTextFile("Epistemos/Views/Meeting/MeetingNoteView.swift")
        let settings = try loadRepoTextFile("Epistemos/Views/Settings/VoicePreferencesSection.swift")
        let preferences = try loadRepoTextFile("Epistemos/Engine/VoicePreferences.swift")
        let voiceDetail = try loadRepoTextFile("Epistemos/Views/Settings/VoiceSettingsDetailView.swift")
        let modelVoicePicker = try loadRepoTextFile("Epistemos/Views/Shared/ModelVoicePickerSection.swift")
        let kokoroSettings = try loadRepoTextFile("Epistemos/VoicePro/KokoroVoiceProSettingsSection.swift")
        let synthesizer = try loadRepoTextFile("Epistemos/Engine/EpistemosSpeechSynthesizer.swift")
        let runtimeLoader = try loadRepoTextFile("Epistemos/VoicePro/KokoroCoreMLRuntimeLoader.swift")
        let runtimeBridge = try loadRepoTextFile("Epistemos/VoicePro/KokoroCoreMLSynthesizer.swift")
        let pipeline = try loadRepoTextFile("LocalPackages/KokoroPipeline/Sources/KokoroPipeline/KokoroPipeline.swift")
        let appCommands = try loadRepoTextFile("Epistemos/App/EpistemosApp.swift")
        let landing = try loadRepoTextFile("Epistemos/Views/Landing/LandingView.swift")

        #expect(registry.contains("enum EpistemosVisibleReadAloudSurface"))
        #expect(registry.contains("case landingHome"))
        #expect(registry.contains("case juneLatestAssistantReply"))
        #expect(registry.contains("case proseNoteBody"))
        #expect(registry.contains("case codeEditor"))
        #expect(registry.contains("case epdocSelection"))
        #expect(registry.contains("case quickCapture"))
        #expect(registry.contains("case meetingTranscript"))
        #expect(registry.contains("case htmlWorkspaceSource"))
        #expect(registry.contains("final class EpistemosVisibleReadAloudRegistry"))
        #expect(registry.contains("func visibleText("))
        #expect(registry.contains("enum EpistemosReadAloudDiagnostics"))
        #expect(registry.contains("AppBootstrap.shared?.uiState.showToast"))
        #expect(!registry.contains("CGWindowList"))
        #expect(!registry.contains("screencapture"))
        #expect(!registry.contains("OCR"))

        #expect(helper.contains("static func readVisibleSurface("))
        #expect(helper.contains("Read visible surface requested preferred="))
        #expect(helper.contains("EpistemosVisibleReadAloudRegistry.shared.visibleText"))
        #expect(helper.contains("maxResponsiveReadVisibleCharacters"))
        #expect(helper.contains("responsiveReadVisibleText"))
        #expect(helper.contains("Read visible surface queued surface="))
        #expect(helper.contains("EpistemosReadAloudDiagnostics.showQueuedToast(surface: surface)"))
        #expect(helper.contains("EpistemosReadAloudDiagnostics.showUnavailableToast"))
        #expect(helper.contains("EpistemosReadAloudDiagnostics.showFailureToast"))
        #expect(registry.contains("activate: Bool = true"))
        #expect(registry.contains("showExcerptToast(surface:"))
        #expect(registry.contains("static func showQueuedToast(surface: EpistemosVisibleReadAloudSurface? = nil)"))
        #expect(readAloud.contains("public let surface: EpistemosVisibleReadAloudSurface?"))
        #expect(readAloud.contains("EpistemosReadAloudDiagnostics.showNoVisibleTextToast(surface: surface)"))
        #expect(readAloud.contains("EpistemosReadAloudDiagnostics.showUnavailableToast()"))
        #expect(readAloud.contains("EpistemosSpeechSynthesizer.logTextToSpeechReadiness("))
        #expect(readAloud.contains("EpistemosAgentReadAloud.responsiveReadVisibleText("))
        #expect(readAloud.contains("EpistemosReadAloudDiagnostics.showInputExcerptToast()"))
        #expect(readAloud.contains("EpistemosReadAloudDiagnostics.showQueuedToast(surface: surface)"))
        #expect(readAloud.contains("private var disabled: Bool {\n        false\n    }"))

        #expect(landing.contains("register(.landingHome)"))
        #expect(landing.contains("landingVisibleReadAloudText()"))
        #expect(landing.contains("unregister(.landingHome)"))
        #expect(juneSurface.contains("register(.juneLatestAssistantReply)"))
        #expect(juneSurface.contains("gateway.visibleAgentSurfaceReadAloudText()"))
        #expect(juneBridge.contains("handleSpeak(action:"))
        let juneGateway = try loadRepoTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        #expect(juneGateway.contains("func visibleAgentSurfaceReadAloudText() -> String?"))
        #expect(juneGateway.contains("June is open. Start a session"))
        #expect(juneGateway.contains("Latest user message: "))
        #expect(juneNav.contains("readVisibleSurface("))
        #expect(juneNav.contains("preferred: .juneLatestAssistantReply"))
        #expect(juneBridge.contains("surface: .juneLatestAssistantReply"))
        #expect(prose.contains("register(.proseNoteBody)"))
        #expect(prose.contains("currentEditorBody(for: page) ?? persistedBodyFor(page)"))
        #expect(prose.contains("private func noteReadAloudText(for page: SDPage) -> String"))
        #expect(prose.contains("let readAloudText = noteReadAloudText(for: page)"))
        #expect(prose.contains("markActive(.codeEditor)"))
        #expect(codeEditor.contains("register(.codeEditor, activate: false)"))
        #expect(!codeEditor.contains("EpistemosVisibleReadAloudRegistry.shared.markActive(.codeEditor)"))
        #expect(epdoc.contains("register(.epdocSelection)"))
        #expect(quickCapture.contains("register(.quickCapture)"))
        #expect(quickCapture.contains("private static let previewSignalQuietWindow: Duration = .milliseconds(120)"))
        #expect(quickCapture.contains("let nextSignals = await Task.detached(priority: .utility)"))
        #expect(meeting.contains("register(.meetingTranscript)"))
        let htmlWorkspace = try loadRepoTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        #expect(htmlWorkspace.contains("register(.htmlWorkspaceSource)"))
        #expect(htmlWorkspace.contains("HTMLWorkspaceReadAloudText.plainVisibleText"))
        #expect(htmlWorkspace.contains("unregister(.htmlWorkspaceSource)"))
        #expect(settings.contains("EpistemosAgentReadAloud.speak(preview)"))
        #expect(settings.contains("logTextToSpeechReadiness(context: \"settings-voice-preview\")"))
        #expect(settings.contains("accessibilityIdentifier(\"settings.voice.preview.\\(key)\")"))
        #expect(settings.contains("preview: \"Kokoro is ready.\""))
        #expect(settings.contains("if VoicePreferences.allowsReadAloudEffects"))
        #expect(preferences.contains("public nonisolated static var allowsReadAloudEffects"))
        #expect(preferences.contains("#if EPISTEMOS_APP_STORE || MAS_SANDBOX"))
        #expect(preferences.contains("public nonisolated static func shippedReadAloudEffect"))
        #expect(preferences.contains("false\n        #else\n        true"))
        #expect(preferences.contains(".clean\n        #else\n        requested"))
        #expect(preferences.contains("when Kokoro is installed and ready"))
        #expect(!preferences.contains("once native Kokoro playback is wired"))
        #expect(!preferences.contains("remains unavailable until native Kokoro playback is wired"))
        #expect(voiceDetail.contains("VoicePreferencesSection()"))
        #expect(voiceDetail.contains("KokoroVoiceProSettingsSection()"))
        #expect(voiceDetail.contains(".formStyle(.grouped)"))
        #expect(voiceDetail.contains(".scrollContentBackground(.hidden)"))
        #expect(voiceDetail.contains("logTextToSpeechReadiness(context: \"voice-settings-detail\")"))
        #expect(modelVoicePicker.contains("English default"))
        #expect(modelVoicePicker.contains("EpistemosSpeechSynthesizer.installedEnglishKokoroVoices()"))
        #expect(modelVoicePicker.contains("normalizeBoundVoiceIdentifier(against: englishVoices)"))
        #expect(modelVoicePicker.contains("normalizedEnglishKokoroVoiceIdentifier("))
        #expect(!modelVoicePicker.contains("personalVoiceAuthorization"))
        #expect(!modelVoicePicker.contains("requestPersonalVoiceAuthorization"))
        #expect(!modelVoicePicker.contains("voiceQualityHint()"))
        #expect(!modelVoicePicker.contains("AVSpeechUtteranceMinimumSpeechRate"))
        #expect(modelVoicePicker.contains("logTextToSpeechReadiness(context: \"settings-voice-model-preview\")"))
        #expect(modelVoicePicker.contains("accessibilityIdentifier(\"settings.voice.modelPreview\")"))
        #expect(modelVoicePicker.contains("previewText: String = \"Kokoro is ready.\""))
        #expect(kokoroSettings.contains("static let voiceSystemImage = \"waveform\""))
        #expect(!kokoroSettings.contains("waveform.badge.sparkles"))
        #expect(kokoroSettings.contains("logTextToSpeechReadiness(context: \"voice-settings-kokoro-section\")"))
        #expect(synthesizer.contains("static func logTextToSpeechReadiness("))
        #expect(synthesizer.contains("readinessLog.notice("))
        #expect(synthesizer.contains("Self.log.notice("))
        #expect(synthesizer.contains("Kokoro TTS queued chars="))
        #expect(synthesizer.contains("Kokoro TTS voice resolved requested="))
        #expect(synthesizer.contains("englishOnly=true"))
        #expect(synthesizer.contains("Kokoro TTS render started"))
        #expect(synthesizer.contains("Kokoro TTS render finished"))
        #expect(synthesizer.contains("Kokoro TTS playback started"))
        #expect(synthesizer.contains("Kokoro TTS playback completed"))
        #expect(!synthesizer.contains("_ = AVSpeechSynthesisVoice.speechVoices()"))
        #expect(synthesizer.contains("effectiveKokoroVoiceIdentifier("))
        #expect(synthesizer.contains("preferredEnglishKokoroVoiceIdentifier("))
        #expect(synthesizer.contains("normalizedEnglishKokoroVoiceIdentifier("))
        #expect(synthesizer.contains("installedEnglishKokoroVoices("))
        #expect(synthesizer.contains("installedEnglishIDs"))
        #expect(synthesizer.contains("VoicePreferences.shippedReadAloudEffect(requestedEffect)"))
        #expect(synthesizer.contains("Kokoro TTS using clean MAS effect requested="))
        #expect(synthesizer.contains("KokoroVoiceGateStatus.starterVoiceIdentifier"))
        #expect(synthesizer.contains("gateResolved="))
        #expect(synthesizer.contains("modelRoot="))
        #expect(synthesizer.contains("manifestValid="))
        #expect(synthesizer.contains("KokoroPipelineLinked="))
        #expect(synthesizer.contains("isTextToSpeechAvailable="))
        #expect(runtimeLoader.contains("KokoroCoreMLPipelineCache"))
        #expect(runtimeLoader.contains("pipelineCache.pipeline(for: resources)"))
        #expect(runtimeBridge.contains("responsiveDurationTokenCeiling = 32"))
        #expect(runtimeBridge.contains("responsiveDurationTokenLimit(from: resources.durationTokenSizes)"))
        #expect(!runtimeBridge.contains("maxTokenCount: resources.durationTokenSizes.max() ?? 512"))
        #expect(runtimeBridge.contains("englishPhonemeSymbols("))
        #expect(runtimeBridge.contains("englishPronunciationLexicon"))
        #expect(runtimeBridge.contains("approximateEnglishPhonemes(forWord:"))
        #expect(runtimeBridge.contains("isEnglishKokoroVoiceIdentifier(voiceIdentifier)"))
        #expect(pipeline.contains("Core ML models are loaded lazily on first use"))
        #expect(pipeline.contains("private var durationModels: [String: MLModel] = [:]"))
        #expect(pipeline.contains("private static func loadModel(at url: URL, computeUnits: MLComputeUnits) throws -> MLModel"))
        #expect(appCommands.contains("Button(\"Open Voice Settings\")"))
        #expect(appCommands.contains("showSettings(section: .voice)"))
        #expect(appCommands.contains("Button(\"Read Visible Surface\")"))
        #expect(appCommands.contains("EpistemosAgentReadAloud.readVisibleSurface()"))
        #expect(appCommands.contains(".keyboardShortcut(\"r\", modifiers: [.command, .shift])"))
        #expect(appCommands.contains("private enum KokoroLaunchProof"))
        #expect(appCommands.contains("--epistemos-run-kokoro-proof-on-launch"))
        #expect(appCommands.contains("epistemos.voice.runKokoroProofOnLaunchOnce"))
        #expect(appCommands.contains("phraseLanguage=en"))
        #expect(appCommands.contains("logTextToSpeechReadiness(context: \"launch-voice-proof\")"))
        #expect(appCommands.contains("EpistemosAgentReadAloud.speak(phrase)"))
        #expect(!appCommands.contains("AVSpeechSynthesizer("))
    }

    @Test("App Store Kokoro defaults to English voice and phoneme input")
    func appStoreKokoroDefaultsToEnglishVoiceAndPhonemeInput() throws {
        let voices = [
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: "ef_dora",
                displayName: "Dora",
                language: "Spanish · Female",
                quality: .premium
            ),
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: "am_michael",
                displayName: "Michael",
                language: "American English · Male",
                quality: .premium
            ),
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: "af_heart",
                displayName: "Heart",
                language: "American English · Female",
                quality: .premium
            )
        ]
        let mislabeledNonEnglishVoices = [
            EpistemosSpeechSynthesizer.VoiceOption(
                identifier: "ef_dora",
                displayName: "Dora",
                language: "American English · Female",
                quality: .premium
            )
        ]
        #expect(
            EpistemosSpeechSynthesizer.effectiveKokoroVoiceIdentifier(
                explicit: "am_michael",
                globalDefault: nil,
                installedVoices: voices
            ) == "am_michael"
        )
        #expect(
            EpistemosSpeechSynthesizer.effectiveKokoroVoiceIdentifier(
                explicit: "ef_dora",
                globalDefault: "com.apple.speech.synthesis.voice.not-kokoro",
                installedVoices: voices
            ) == KokoroVoiceGateStatus.starterVoiceIdentifier
        )
        #expect(
            EpistemosSpeechSynthesizer.effectiveKokoroVoiceIdentifier(
                explicit: "ef_dora",
                globalDefault: nil,
                installedVoices: mislabeledNonEnglishVoices
            ) == KokoroVoiceGateStatus.starterVoiceIdentifier
        )
        #expect(
            EpistemosSpeechSynthesizer.effectiveKokoroVoiceIdentifier(
                explicit: nil,
                globalDefault: nil,
                installedVoices: []
            ) == KokoroVoiceGateStatus.starterVoiceIdentifier
        )
        #expect(
            EpistemosSpeechSynthesizer.normalizedEnglishKokoroVoiceIdentifier(
                "am_michael",
                installedVoices: voices
            ) == "am_michael"
        )
        #expect(
            EpistemosSpeechSynthesizer.normalizedEnglishKokoroVoiceIdentifier(
                "ef_dora",
                installedVoices: voices
            ) == nil
        )
        #expect(
            EpistemosSpeechSynthesizer.normalizedEnglishKokoroVoiceIdentifier(
                "com.apple.speech.synthesis.voice.not-kokoro",
                installedVoices: voices
            ) == nil
        )
        let synthesizer = try loadRepoTextFile("Epistemos/Engine/EpistemosSpeechSynthesizer.swift")
        let runtimeBridge = try loadRepoTextFile("Epistemos/VoicePro/KokoroCoreMLSynthesizer.swift")
        #expect(synthesizer.contains(".filter(isEnglishKokoroVoiceOption)"))
        #expect(synthesizer.contains("return voices.first(where: isEnglishKokoroVoiceOption)?.identifier"))
        #expect(synthesizer.contains("normalizedEnglishKokoroVoiceIdentifier("))
        #expect(runtimeBridge.contains("private nonisolated static func isEnglishKokoroVoiceIdentifier"))
        #expect(runtimeBridge.contains("isEnglishKokoroVoiceIdentifier(voiceIdentifier)"))
        #expect(!runtimeBridge.contains(#""—", "\u{2010}""#))
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        #expect(!VoicePreferences.allowsReadAloudEffects)
        #expect(VoicePreferences.shippedReadAloudEffect(.pixelArt) == .clean)
        #else
        #expect(VoicePreferences.allowsReadAloudEffects)
        #expect(VoicePreferences.shippedReadAloudEffect(.pixelArt) == .pixelArt)
        #endif

        let symbols = ["k", "ˈ", "O", "ə", "ɹ", "ɪ", "z", " ", "ɛ", "d", "i", "."]
        let vocabulary = Dictionary(uniqueKeysWithValues: symbols.enumerated().map { ($0.element, Int32($0.offset + 1)) })
        let phonemes = KokoroCoreMLSynthesizer.englishPhonemeSymbols(
            for: "Kokoro is ready.",
            vocabulary: vocabulary
        )

        #expect(phonemes.contains("ə"))
        #expect(phonemes.contains("ɹ"))
        #expect(phonemes.contains("ɛ"))
        #expect(!phonemes.starts(with: ["k", "o", "k", "o", "r", "o"]))
    }

    @Test("App Store lane first-run and upgrade bootstrap matrix")
    func appStoreLaneFirstRunAndUpgradeBootstrapMatrix() throws {
        let freshVault = makeUncreatedTempDirectory()
        defer { try? FileManager.default.removeItem(at: freshVault) }

        #expect(FirstRunBootstrap.isFresh(at: freshVault))
        let freshReceipt = try FirstRunBootstrap.bootstrap(at: freshVault)
        #expect(freshReceipt.wasFresh)
        for relative in FirstRunBootstrap.scaffoldFolders {
            let folder = freshVault.appendingPathComponent(relative, isDirectory: true)
            var isDirectory: ObjCBool = false
            #expect(FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory))
            #expect(isDirectory.boolValue)
        }
        let secondReceipt = try FirstRunBootstrap.bootstrap(at: freshVault)
        #expect(!secondReceipt.wasFresh)
        #expect(secondReceipt.metadata.createdAt == freshReceipt.metadata.createdAt)

        let partialVault = makeUncreatedTempDirectory(prefix: "keelstone-appstore-partial")
        defer { try? FileManager.default.removeItem(at: partialVault) }
        try FileManager.default.createDirectory(
            at: partialVault.appendingPathComponent("notes", isDirectory: true),
            withIntermediateDirectories: true
        )
        #expect(FirstRunBootstrap.isFresh(at: partialVault))
        let partialReceipt = try FirstRunBootstrap.bootstrap(at: partialVault)
        #expect(partialReceipt.wasFresh)
        #expect(partialReceipt.createdFolders.count == FirstRunBootstrap.scaffoldFolders.count - 1)
    }

    @Test("App Store lane rejects stale and non-security-scoped startup bookmarks")
    func appStoreLaneRejectsInvalidStartupBookmarks() {
        let stale = VaultSyncService.startupBookmarkValidationForTesting(
            bookmarkExists: true,
            resolvedURL: URL(fileURLWithPath: "/tmp/vault", isDirectory: true),
            isStale: true,
            usedSecurityScope: true,
            accessGranted: true,
            isReadable: true,
            requiresSecurityScopedVaultAccess: true
        )
        #expect(!stale.isReadyForAutomaticRestore)
        #expect(stale.failureReason == "Saved vault bookmark is stale and must be re-selected.")

        let plain = VaultSyncService.startupBookmarkValidationForTesting(
            bookmarkExists: true,
            resolvedURL: URL(fileURLWithPath: "/tmp/vault", isDirectory: true),
            isStale: false,
            usedSecurityScope: false,
            accessGranted: true,
            isReadable: true,
            requiresSecurityScopedVaultAccess: true
        )
        #expect(!plain.isReadyForAutomaticRestore)
        #expect(plain.failureReason == "Saved vault bookmark is not security-scoped and must be re-selected.")
    }

    @Test("App Store lane checks startup bookmark readability while security scope is active")
    func appStoreLaneChecksStartupBookmarkReadabilityWhileScopeIsActive() {
        let vaultURL = URL(fileURLWithPath: "/tmp/appstore-scoped-vault", isDirectory: true)
        var scopeActive = false
        var checkedExistsWhileScoped = false
        var checkedReadableWhileScoped = false
        var stoppedAfterReadabilityCheck = false

        let validation = VaultSyncService.scopedStartupBookmarkValidationForTesting(
            resolvedURL: vaultURL,
            isStale: false,
            usedSecurityScope: true,
            accessSecurityScope: { _ in
                scopeActive = true
                return true
            },
            stopSecurityScope: { _ in
                #expect(checkedExistsWhileScoped)
                #expect(checkedReadableWhileScoped)
                stoppedAfterReadabilityCheck = true
                scopeActive = false
            },
            fileExists: { path in
                #expect(path == vaultURL.path)
                #expect(scopeActive)
                checkedExistsWhileScoped = true
                return true
            },
            isReadableFile: { path in
                #expect(path == vaultURL.path)
                #expect(scopeActive)
                checkedReadableWhileScoped = true
                return true
            },
            requiresSecurityScopedVaultAccess: true
        )

        #expect(validation.bookmarkExists)
        #expect(validation.isReadyForAutomaticRestore)
        #expect(validation.failureReason == nil)
        #expect(stoppedAfterReadabilityCheck)
        #expect(scopeActive == false)
    }

    @Test("App Store lane defers vault-source warnings before ready bookmark restore")
    func appStoreLaneDefersVaultSourceWarningsBeforeReadyBookmarkRestore() {
        let report = AppBootstrap.startupIntegrityReportForTesting(
            samplePageIds: [],
            readBodyData: { _ in Data("ok".utf8) },
            eventStoreAvailable: true,
            vaultBookmarkValidation: VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: true,
                failureReason: nil
            ),
            pageSnapshots: [
                StartupIntegrityPageSnapshot(
                    id: "vault-backed-note",
                    filePath: "/Users/example/Vault/Note.md",
                    hasInlineBody: false,
                    hasMeaningfulMetadata: true
                )
            ],
            bodyFileExists: { _ in false },
            filePathReadable: { _ in false }
        )

        #expect(report.unrecoverablePageIds.isEmpty)
        #expect(!report.shouldBlockAutomaticVaultRestore)
        #expect(AppBootstrap.startupIntegrityToastForTesting(report: report) == nil)
    }

    @Test("App Store lane retries transient MAS bookmark preflight instead of warning")
    func appStoreLaneRetriesTransientMASBookmarkPreflightInsteadOfWarning() {
        let report = AppBootstrap.startupIntegrityReportForTesting(
            samplePageIds: [],
            readBodyData: { _ in Data("ok".utf8) },
            eventStoreAvailable: true,
            vaultBookmarkValidation: VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: false,
                failureReason: "Saved vault bookmark points to a missing or unreadable directory."
            ),
            pageSnapshots: [
                StartupIntegrityPageSnapshot(
                    id: "vault-backed-note",
                    filePath: "/Users/example/Vault/Note.md",
                    hasInlineBody: false,
                    hasMeaningfulMetadata: true
                )
            ],
            bodyFileExists: { _ in false },
            filePathReadable: { _ in false }
        )

        #expect(report.vaultBookmarkExists)
        #expect(!report.vaultBookmarkReadyForAutomaticRestore)
        #expect(!report.vaultBookmarkBlocksAutomaticRestore)
        #expect(report.unrecoverablePageIds.isEmpty)
        #expect(!report.shouldBlockAutomaticVaultRestore)
        #expect(AppBootstrap.startupIntegrityToastForTesting(report: report) == nil)
    }

    @Test("App Store lane lets saved vault restore repair managed body cache gaps")
    func appStoreLaneLetsSavedVaultRestoreRepairManagedBodyCacheGaps() {
        let report = AppBootstrap.startupIntegrityReportForTesting(
            samplePageIds: ["managed-body-ok", "managed-body-missing"],
            readBodyData: { pageId in
                pageId == "managed-body-ok" ? Data("ok".utf8) : nil
            },
            eventStoreAvailable: true,
            vaultBookmarkValidation: VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: false,
                failureReason: "Saved vault bookmark points to a missing or unreadable directory."
            )
        )

        #expect(report.corruptedPageIds == ["managed-body-missing"])
        #expect(report.vaultBookmarkExists)
        #expect(!report.vaultBookmarkBlocksAutomaticRestore)
        #expect(!report.shouldBlockAutomaticVaultRestore)
        #expect(AppBootstrap.startupIntegrityToastForTesting(report: report) == nil)
    }

    @Test("App Store lane startup restore failure preserves local vault state")
    func appStoreLaneStartupRestoreFailurePreservesLocalVaultState() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let restoreFailureHandler = try #require(sourceSection(
            in: source,
            startingAt: "private func handleRestoreFailure(",
            endingBefore: "private nonisolated static func suspiciousVaultRestoreReconfirmationReason"
        ))

        #expect(!restoreFailureHandler.contains("clearVaultData()"))
        #expect(restoreFailureHandler.contains("preserving local vault state"))
    }

    @Test("App Store bookmark timeout does not wait for blocked synchronous resolution")
    func appStoreBookmarkResolutionTimeoutIsNonStructured() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let bootstrap = try loadRepoTextFile("Epistemos/App/AppBootstrap.swift")
        let timeoutResolver = try #require(sourceSection(
            in: source,
            startingAt: "private nonisolated static func resolveVaultBookmarkWithTimeout(",
            endingBefore: "private func clearDerivedLocalStateForRecovery()"
        ))

        #expect(source.contains("private nonisolated final class VaultBookmarkResolutionRace"))
        #expect(source.contains("private var continuation: CheckedContinuation<ResolvedVaultBookmark, Error>?"))
        #expect(timeoutResolver.contains("withCheckedThrowingContinuation"))
        #expect(timeoutResolver.contains("Task.detached"))
        #expect(timeoutResolver.contains("race.resume(.failure(VaultBookmarkResolutionError.timedOut))"))
        #expect(!timeoutResolver.contains("withThrowingTaskGroup"))
        #expect(!timeoutResolver.contains("group.cancelAll()"))
        #expect(source.contains("func startupBookmarkValidationWithTimeout() async -> VaultBookmarkStartupValidation"))
        #expect(source.contains("private var pendingStartupResolvedBookmark:"))
        #expect(source.contains("cached.bookmarkData == data"))
        #expect(source.contains("resolvedBookmark = cached.resolvedBookmark"))
        #expect(source.contains("pendingStartupResolvedBookmark = nil"))
        #expect(bootstrap.components(separatedBy: "await vaultSync.startupBookmarkValidationWithTimeout()").count == 2)
        #expect(bootstrap.contains("let vaultBookmarkValidation = report.vaultBookmarkValidation"))
    }

    @Test("App Store lane preserves saved bookmark on transient restore failures")
    func appStoreLanePreservesBookmarkOnTransientRestoreFailures() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let lostScopeBranch = try #require(sourceSection(
            in: source,
            startingAt: "if !gained {",
            endingBefore: "let isReadableVault = await readableVaultURLAfterSecurityScopeSettle(url)"
        ))
        let missingDirectoryBranch = try #require(sourceSection(
            in: source,
            startingAt: "if !isReadableVault {",
            endingBefore: "if isStale {"
        ))

        #expect(lostScopeBranch.contains("Security scope not granted for vault bookmark"))
        #expect(missingDirectoryBranch.contains("Vault directory not found or readable at"))
        #expect(source.contains("readableVaultURLAfterSecurityScopeSettle"))
        #expect(source.contains("isReadableVaultDirectory"))
        #expect(!lostScopeBranch.contains("defaults.removeObject(forKey: Self.bookmarkKey)"))
        #expect(!missingDirectoryBranch.contains("defaults.removeObject(forKey: Self.bookmarkKey)"))
    }

    @Test("App Store automatic restore failures never delete persisted vault selection")
    func appStoreAutomaticRestoreFailuresNeverDeletePersistedVaultSelection() throws {
        let source = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let automaticRestore = try #require(sourceSection(
            in: source,
            startingAt: "let resolvedBookmark: ResolvedVaultBookmark",
            endingBefore: "        // Pass scopeAlreadyAcquired=true"
        ))

        #expect(!automaticRestore.contains("defaults.removeObject(forKey: Self.bookmarkKey)"))
        #expect(automaticRestore.contains("preserving the saved vault selection for retry"))
        #expect(automaticRestore.contains("reason: reason,\n                bookmarkExists: true"))
    }

    @Test("App Store lane does not stack vault-source-loss warnings while a bookmark exists")
    func appStoreLaneDefersVaultSourceLossWarningsForBlockedBookmarksToo() {
        let report = AppBootstrap.startupIntegrityReportForTesting(
            samplePageIds: [],
            readBodyData: { _ in Data("ok".utf8) },
            eventStoreAvailable: true,
            vaultBookmarkValidation: VaultBookmarkStartupValidation(
                bookmarkExists: true,
                isReadyForAutomaticRestore: false,
                failureReason: "Saved vault bookmark is stale and must be re-selected."
            ),
            pageSnapshots: [
                StartupIntegrityPageSnapshot(
                    id: "vault-backed-note",
                    filePath: "/Users/example/Vault/Note.md",
                    hasInlineBody: false,
                    hasMeaningfulMetadata: true
                )
            ],
            bodyFileExists: { _ in false },
            filePathReadable: { _ in false }
        )

        #expect(report.vaultBookmarkBlocksAutomaticRestore)
        #expect(report.unrecoverablePageIds.isEmpty)
        let toast = AppBootstrap.startupIntegrityToastForTesting(report: report)
        #expect(toast?.message.contains("Saved vault bookmark is stale and must be re-selected.") == true)
        #expect(toast?.message.contains("no body file or vault source") == false)
    }

    @Test("App Store lane keeps graph inspector preview read-only")
    func appStoreLaneKeepsHologramInspectorPreviewReadOnly() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Graph/HologramNodeInspector.swift")
        let previewBody = try #require(sourceSection(
            in: source,
            startingAt: "private func noteEditorBody(pageId: String)",
            endingBefore: "private func loadEditorPreview(pageId: String)"
        ))

        #expect(previewBody.contains("CodeInspectorPreview(content: editorText"))
        #expect(previewBody.contains("formattedMarkdownView(editorText)"))
        #expect(previewBody.contains("loadEditorPreview(pageId: pageId)"))
        #expect(previewBody.contains("loadEditorPreview(pageId: newId)"))
        #expect(source.contains("private enum HologramInspectorPreviewPolicy"))
        #expect(source.contains("static let maxBodyCharacters = 24_000"))
        #expect(source.contains("Task(priority: HologramInspectorPreviewPolicy.loadPriority)"))
        #expect(source.contains("guard graphState.currentRoute.isCanvas else"))
        #expect(source.contains("cancelEditorPreview()"))
        #expect(source.contains("HologramInspectorPreviewPolicy.boundedBody("))
        #expect(!previewBody.contains(".onChange(of: editorText)"))
        #expect(!previewBody.contains("flushEditorIfNeeded(pageId:"))
        #expect(!previewBody.contains("debouncedEditorSave(pageId:"))
        #expect(!source.contains("private func debouncedEditorSave"))
        #expect(!source.contains("private func markPageDirty"))
        #expect(!source.contains("NoteFileStorage.stageBodyForImmediateRead(pageId: pageId"))
        #expect(!source.contains("savePageBodyFileFirst(pageId: pageId"))
        #expect(!source.contains("BlockMirrorSyncCoordinator.shared.scheduleSync("))
        #expect(source.contains("private func loadEditorPreviewSnapshot(pageId: String) async -> EditorPreviewSnapshot"))
        #expect(source.contains("Task.detached(priority: HologramInspectorPreviewPolicy.loadPriority)"))
        #expect(!source.contains("Task.detached(priority: .userInitiated)"))
        #expect(!source.contains("NoteWindowManager.shared.currentBody(for: pageId)"))
    }

    @Test("App Store file-first title renames converge without duplicate vault files")
    func appStoreFileFirstTitleRenamesConvergeWithoutDuplicateVaultFiles() async throws {
        let vaultSyncSource = try loadRepoTextFile("Epistemos/Sync/VaultSyncService.swift")
        let liveRenamePath = try #require(
            sourceSection(
                in: vaultSyncSource,
                startingAt: "func renamePageFile(pageId: String, newTitle: String) -> Task<String?, Never>?",
                endingBefore: "    func renameDirectory(from oldRelativePath: String, to newRelativePath: String) -> Bool"
            )
        )
        #expect(liveRenamePath.contains("VaultIndexActor.renamePageFileOnDisk("))
        #expect(!liveRenamePath.contains("actor?.renamePageFile("))

        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-appstore-title-rename")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        service.setVaultURLForTesting(vaultURL)
        let pageId = try #require(
            await service.createPage(title: "Untitled", body: "")
        )
        let page = try #require(
            try context.fetch(FetchDescriptor<SDPage>())
                .first(where: { $0.id == pageId })
        )

        for revision in 1...3 {
            // Source-mode snapshots reapply parsed frontmatter metadata before
            // the file-first service gives the first H1 canonical title priority.
            // Repeating that sequence must converge on one file, not re-export
            // a stale pre-rename path and dedupe a new copy per keystroke.
            page.title = "Frontmatter Title"
            try context.save()
            #expect(
                await service.savePageBodyFileFirst(
                    pageId: pageId,
                    body: "# Canonical H1\n\nRevision \(revision)"
                )
            )
            let canonicalURL = vaultURL.appendingPathComponent("Canonical H1.md")
            #expect(page.filePath == canonicalURL.path)
            #expect(FileManager.default.fileExists(atPath: canonicalURL.path))
            #expect(!context.hasChanges)
            try await Task.sleep(for: .milliseconds(150))
        }

        let markdownFiles = try FileManager.default.contentsOfDirectory(
            at: vaultURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension.lowercased() == "md" }
        #expect(markdownFiles.map(\.lastPathComponent) == ["Canonical H1.md"])
        #expect(
            try String(contentsOf: markdownFiles[0], encoding: .utf8)
                .contains("Revision 3")
        )

        let refreshedPage = try #require(
            try context.fetch(FetchDescriptor<SDPage>())
                .first(where: { $0.id == pageId })
        )
        let refreshedPath = try #require(refreshedPage.filePath)
        let refreshedURL = URL(fileURLWithPath: refreshedPath)
            .resolvingSymlinksInPath()
        let enumeratedURL = markdownFiles[0].resolvingSymlinksInPath()
        #expect(refreshedURL == enumeratedURL)
    }

    @Test("App Store lane refuses plain bookmark fallback when persisting vault selection")
    func appStoreLaneRefusesPlainBookmarkFallback() throws {
        let container = try makeContainer()
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-appstore-bookmark")
        defer { try? FileManager.default.removeItem(at: vaultURL) }

        service.setRequiresSecurityScopedVaultAccessForTesting(true)
        service.setBookmarkDataWriterForTesting { _, options in
            if options.contains(.withSecurityScope) {
                throw CocoaError(.fileReadUnknown)
            }
            return Data("plain-bookmark".utf8)
        }

        let didPersist = service.persistVaultSelection(vaultURL)

        #expect(!didPersist)
        #expect(defaults.data(forKey: vaultBookmarkKey) == nil)
        #expect(defaults.string(forKey: lastVaultPathKey) == nil)
        #expect(!defaults.bool(forKey: "epistemos.hasEverConnectedAVault"))
    }

    @Test("App Store lane freezes writes when the mounted vault root disappears")
    func appStoreLaneRootUnavailabilityFreezesWrites() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let defaults = makeIsolatedDefaults()
        let service = VaultSyncService(modelContainer: container, userDefaults: defaults)
        let vaultURL = try makeTempDirectory(prefix: "keelstone-appstore-unavailable")
        defer {
            service.stopWatching(preserveData: true)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        defaults.set(Data("bookmark".utf8), forKey: vaultBookmarkKey)
        let page = SDPage(title: "Unavailable Root")
        context.insert(page)
        try context.save()

        service.setVaultURLForTesting(vaultURL)
        service.setInitialImportCompletedForTesting(true)
        try FileManager.default.removeItem(at: vaultURL)

        service.handleVaultVolumeUnavailableForTesting(
            vaultURL: vaultURL,
            reason: "appstore lane root unavailable"
        )

        #expect(service.vaultURL == nil)
        #expect(!service.isWatching)
        #expect(service.recoveryIssue?.reason == "appstore lane root unavailable")
        #expect(defaults.data(forKey: vaultBookmarkKey) == Data("bookmark".utf8))
        #expect(try context.fetch(FetchDescriptor<SDPage>()).count == 1)
        #expect(await service.savePageBodyFileFirst(pageId: page.id, body: "edited") == false)
    }
}
