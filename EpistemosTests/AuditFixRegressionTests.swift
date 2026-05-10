import Foundation
import Testing
@testable import Epistemos

@Suite("Audit Fix Regression")
struct AuditFixRegressionTests {
    @Test("skill evolution uses SkillTraceEvent and accepts live harness traces")
    func skillEvolutionUsesSkillTraceEventAndLiveHarnessTraces() throws {
        let source = try loadAuditSource("Epistemos/Vault/SkillEvolutionService.swift")

        #expect(source.contains("SkillTraceEvent"))
        #expect(source.contains("lastPathComponent == \"trace.json\""))
        #expect(source.contains("pathExtension == \"jsonl\""))
        #expect(source.contains("loadHarnessTraceSessions()"))
    }

    @Test("vault registry and session browser expose the shared helpers required by vault services")
    func vaultRegistryAndSessionBrowserExposeSharedHelpers() throws {
        let registry = try loadAuditSource("Epistemos/Vault/VaultRegistry.swift")
        let browser = try loadAuditSource("Epistemos/Vault/SessionBrowser.swift")

        #expect(registry.contains("static let shared = VaultRegistry()"))
        #expect(registry.contains("func resolveVaultPath(for identity: VaultIdentity) -> String?"))
        #expect(browser.contains("static let shared = SessionBrowser()"))
        #expect(browser.contains("var sessionId: String { id }"))
        #expect(browser.contains("var sessions: [SessionInfo] { groups.flatMap(\\.sessions) }"))
        #expect(browser.contains("func refreshSessions(for vaultIdentity: VaultIdentity)"))
    }

    @Test("code editor stays editor-only and drops inline assistant chrome")
    func codeEditorStaysEditorOnlyAndDropsInlineAssistantChrome() throws {
        let source = try loadAuditSource("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(source.contains(".onDisappear {"))
        #expect(!source.contains("AIPartnerService("))
        #expect(!source.contains("CodeAskBarService("))
        #expect(!source.contains("InlineSuggestionOverlay("))
    }

    @Test("SSM persistence is surfaced in settings and bound back into conversation persistence")
    func ssmPersistenceIsSurfacedAndBoundBackIntoConversationPersistence() throws {
        let settings = try loadAuditSource("Epistemos/Views/Settings/CognitiveSettingsSection.swift")
        let bootstrap = try loadAuditSource("Epistemos/App/AppBootstrap.swift")
        let persistence = try loadAuditSource("Epistemos/Vault/ConversationPersistence.swift")

        #expect(settings.contains("Toggle(\"Enable SSM State Persistence\""))
        #expect(settings.contains("Toggle(\"Save After Each Turn\""))
        #expect(settings.contains("ssmMaxSnapshotsPerModel"))
        #expect(bootstrap.contains("ConversationPersistence.shared.bindSSMStatePath"))
        #expect(bootstrap.contains("UUID(uuidString: sessionID)"))
        #expect(persistence.contains("static let shared = ConversationPersistence("))
    }

    @Test("night brain wires vault-backed lifecycle jobs from app bootstrap")
    func nightBrainWiresVaultBackedLifecycleJobsFromAppBootstrap() throws {
        let bootstrap = try loadAuditSource("Epistemos/App/AppBootstrap.swift")

        #expect(bootstrap.contains("vaultPathProvider: { @MainActor [weak vaultSync] in"))
        #expect(bootstrap.contains("vaultSync?.vaultURL?.path"))
        #expect(bootstrap.contains("ssmStateServiceProvider: { @MainActor [weak self] in"))
    }

    @Test("night brain stale fallback runs the pipeline inline before recording success")
    func nightBrainStaleFallbackRunsPipelineInlineBeforeRecordingSuccess() throws {
        let bootstrap = try loadAuditSource("Epistemos/App/AppBootstrap.swift")
        let service = try loadAuditSource("Epistemos/State/NightBrainService.swift")

        let fallbackStart = try #require(bootstrap.range(of: "if NightBrainScheduler.shouldRunFallbackInline()"))
        let fallbackTail = bootstrap[fallbackStart.lowerBound...]
        let fallbackEnd = try #require(fallbackTail.range(of: "#endif"))
        let fallbackBlock = String(fallbackTail[..<fallbackEnd.upperBound])

        #expect(service.contains("func runInlineFallback() async -> PipelineResult"))
        #expect(fallbackBlock.contains("await self?._nightBrain?.runInlineFallback()"))
        #expect(fallbackBlock.contains("case .finished"))
        #expect(!fallbackBlock.contains("await self?._nightBrain?.start()"))
        let runInline = try #require(fallbackBlock.range(of: "runInlineFallback()"))
        let recordSuccess = try #require(fallbackBlock.range(of: "NightBrainScheduler.recordSuccessfulRun()"))
        #expect(runInline.lowerBound < recordSuccess.lowerBound)
    }

    @Test("night brain pruning reads the live SSM snapshot cap instead of a fresh default config")
    func nightBrainPruningReadsLiveSSMSnapshotCap() throws {
        let source = try loadAuditSource("Epistemos/State/NightBrainService.swift")

        #expect(source.contains("config.ssmMaxSnapshotsPerModel"))
        #expect(!source.contains("EpistemosConfig().ssmMaxSnapshotsPerModel"))
    }

    @Test("cloud tool approval and native computer-use roundtrip stay wired")
    func cloudToolApprovalAndComputerUseRoundTripStayWired() throws {
        let coordinator = try loadAuditSource("Epistemos/App/ChatCoordinator.swift")
        let delegate = try loadAuditSource("Epistemos/Bridge/StreamingDelegate.swift")
        let bubble = try loadAuditSource("Epistemos/Views/Chat/MessageBubble.swift")
        let rustBridge = try loadAuditSource("agent_core/src/bridge.rs")
        let agentLoop = try loadAuditSource("agent_core/src/agent_loop.rs")

        #expect(coordinator.contains("approved = await promptForToolApproval(request)"))
        #expect(coordinator.contains("chatState.recordToolUse("))
        #expect(coordinator.contains("chatState.recordToolResult("))
        #expect(!coordinator.contains("ComputerUseBridge.shared.execute(actionJSON: inputJson)"))
        #expect(bubble.contains("ToolExecutionPreviewList("))
        #expect(delegate.contains("func executeComputerAction(actionJson: String) -> String"))
        #expect(rustBridge.contains("fn execute_computer_action(&self, action_json: String) -> String;"))
        #expect(agentLoop.contains("delegate.execute_computer_action(input_json.clone())"))
    }

    @Test("chat coordinator auto-approved permissions do not append a fake approval banner")
    func autoApprovedPermissionsDoNotAppendFakeApprovalBanner() throws {
        let coordinator = try loadAuditSource("Epistemos/App/ChatCoordinator.swift")

        #expect(coordinator.contains("case .autoAllow:"))
        #expect(coordinator.contains("approved = true"))
        #expect(!coordinator.contains("case .autoAllow:\n                        approved = await promptForToolApproval(request)"))
        #expect(!coordinator.contains("case .autoAllow:\n                        chatState.appendStreamingText"))
    }

    @Test("command center rust agent path prompts for human-gated tool permission")
    func commandCenterRustAgentPathPromptsForHumanGatedToolPermission() throws {
        let coordinator = try loadAuditSource("Epistemos/App/ChatCoordinator.swift")
        let functionStart = try #require(coordinator.range(of: "private func runCommandCenterRustAgentPath("))
        let functionTail = coordinator[functionStart.lowerBound...]
        let permissionStart = try #require(functionTail.range(of: "case .permissionRequired(let request):"))
        let permissionTail = functionTail[permissionStart.lowerBound...]
        let permissionEnd = try #require(permissionTail.range(of: "case .complete("))
        let permissionBlock = String(permissionTail[..<permissionEnd.lowerBound])

        #expect(permissionBlock.contains("if request.requiresHumanApproval"))
        #expect(permissionBlock.contains("approved = await promptForToolApproval(request)"))
        #expect(permissionBlock.contains("approved = true"))
        #expect(permissionBlock.contains("decision: request.requiresHumanApproval"))
        #expect(permissionBlock.contains("approved ? .approvedByUser : .deniedByUser"))
        #expect(!permissionBlock.contains("approved = !request.requiresHumanApproval"))
        #expect(!permissionBlock.contains("decision: approved ? .approvedAutoReadOnly : .deniedByPolicy"))
    }

    @Test("approval prompts name the persistent permission group and point to quick setup presets")
    func approvalPromptsNameThePersistentPermissionGroupAndPointToQuickSetupPresets() throws {
        let coordinator = try loadAuditSource("Epistemos/App/ChatCoordinator.swift")
        let authority = try loadAuditSource("Epistemos/Engine/AgentHarness/AgentAuthority.swift")

        #expect(coordinator.contains("Always Allow \\(authorityCategory.displayName)"))
        #expect(coordinator.contains("Authority → Less Interruptions"))
        #expect(coordinator.contains("Use Less Interruptions"))
        #expect(coordinator.contains("AgentAuthorityQuickSetupPreset.lessInterruptions.decisions"))
        #expect(authority.contains("enum AgentAuthorityQuickSetupPreset"))
        #expect(authority.contains("case lessInterruptions = \"Less Interruptions\""))
    }

    @Test("agent tool approvals route through SwiftUI queue instead of NSAlert")
    func agentToolApprovalsRouteThroughSwiftUIQueueInsteadOfNSAlert() throws {
        let coordinator = try loadAuditSource("Epistemos/App/ChatCoordinator.swift")
        let approvalModal = try loadAuditSource("Epistemos/Views/Approval/ApprovalModalView.swift")
        let bootstrap = try loadAuditSource("Epistemos/App/AppBootstrap.swift")
        let environment = try loadAuditSource("Epistemos/App/AppEnvironment.swift")
        let app = try loadAuditSource("Epistemos/App/EpistemosApp.swift")

        #expect(approvalModal.contains("enum ChatApprovalResolution"))
        #expect(approvalModal.contains("@MainActor @Observable"))
        #expect(approvalModal.contains("final class ChatApprovalQueue"))
        #expect(approvalModal.contains("var pendingApproval: ApprovalModalView.PendingApproval?"))
        #expect(approvalModal.contains("func enqueue("))
        #expect(approvalModal.contains("withCheckedContinuation"))
        #expect(approvalModal.contains("func resolve("))
        #expect(approvalModal.contains("case applyLessInterruptions"))

        #expect(bootstrap.contains("let chatApprovalQueue = ChatApprovalQueue()"))
        #expect(environment.contains(".environment(bootstrap.chatApprovalQueue)"))
        #expect(app.contains("Binding<ApprovalModalView.PendingApproval?>"))
        #expect(app.contains("bootstrap.chatApprovalQueue.pendingApproval"))
        #expect(app.contains("bootstrap.chatApprovalQueue.resolve"))
        #expect(app.contains(".interactiveDismissDisabled(true)"))

        #expect(coordinator.contains("bootstrap.chatApprovalQueue.enqueue("))
        #expect(coordinator.contains("toolApprovalPromptChoice(for resolution: ChatApprovalResolution)"))
        #expect(coordinator.contains("promptUserForBudgetGateApproval"))
        #expect(coordinator.contains("request.isBudgetGate"))
        #expect(coordinator.contains("authorityCategoryLabel: \"Session budget\""))
        #expect(!coordinator.contains("let alert = NSAlert()"))
        #expect(!coordinator.contains("beginSheetModal"))
        #expect(!coordinator.contains("runModal()"))
    }

    @MainActor
    @Test("chat approval queue resolves modal decisions without hanging continuations")
    func chatApprovalQueueResolvesModalDecisions() async throws {
        let queue = ChatApprovalQueue()

        let first = Task { @MainActor in
            await queue.enqueue(
                sessionId: "session-a",
                toolName: "shell.execute",
                argsJSON: "{}",
                deadline: Date().addingTimeInterval(60),
                summary: nil,
                authorityCategoryLabel: nil
            )
        }
        let firstApproval = try await nextPendingApproval(from: queue)
        queue.resolve(firstApproval, decision: .applyLessInterruptions)
        #expect(await first.value == .applyLessInterruptions)
        #expect(queue.pendingApproval == nil)

        let timeout = Task { @MainActor in
            await queue.enqueue(
                sessionId: "session-b",
                toolName: "file.write",
                argsJSON: "{}",
                deadline: Date(),
                summary: nil,
                authorityCategoryLabel: nil
            )
        }
        let timeoutApproval = try await nextPendingApproval(from: queue)
        queue.resolve(timeoutApproval, decision: .timedOut)
        #expect(await timeout.value == .deny)

        let held = Task { @MainActor in
            await queue.enqueue(
                sessionId: "session-c",
                toolName: "browser.click",
                argsJSON: "{}",
                deadline: Date().addingTimeInterval(60),
                summary: nil,
                authorityCategoryLabel: nil
            )
        }
        let heldApproval = try await nextPendingApproval(from: queue)
        let overlapping = await queue.enqueue(
            sessionId: "session-d",
            toolName: "browser.type",
            argsJSON: "{}",
            deadline: Date().addingTimeInterval(60),
            summary: nil,
            authorityCategoryLabel: nil
        )
        #expect(overlapping == .deny)
        queue.resolve(heldApproval, decision: .approveOnce)
        #expect(await held.value == .allowOnce)
    }

    @Test("managed tools use an application-support scratch vault instead of crashing when no vault is attached")
    func managedToolsUseApplicationSupportScratchVaultWhenNoVaultIsAttached() throws {
        let coordinator = try loadAuditSource("Epistemos/App/ChatCoordinator.swift")
        let bridge = try loadAuditSource("Epistemos/Bridge/ToolTierBridge.swift")
        let extensions = try loadAuditSource("Epistemos/Engine/Extensions.swift")

        #expect(extensions.contains("managedToolRuntimeVaultDirectory"))
        #expect(extensions.contains("ManagedToolRuntime"))
        #expect(extensions.contains("ScratchVault"))
        #expect(coordinator.contains("FoundationSafety.managedToolRuntimeVaultDirectory"))
        #expect(bridge.contains("FoundationSafety.managedToolRuntimeVaultDirectory"))
    }

    @Test("session context preview opens the vault read-only so tool runs do not trip an index writer lock")
    func sessionContextPreviewOpensTheVaultReadOnlySoToolRunsDoNotTripAnIndexWriterLock() throws {
        let bridge = try loadAuditSource("agent_core/src/bridge.rs")
        let vault = try loadAuditSource("agent_core/src/storage/vault.rs")
        let commandCenter = try loadAuditSource("agent_core/src/command_center.rs")

        #expect(bridge.contains("VaultStore::open_read_only(&vault_path)"))
        #expect(vault.contains("pub fn open_read_only(vault_root: &str) -> Result<Self, VaultError>"))
        #expect(commandCenter.contains("VaultStore::open_read_only(vault_path)"))
    }

    @Test("main chat no longer narrates approval banners into the assistant answer stream")
    func mainChatNoLongerNarratesApprovalBannersIntoAssistantAnswerStream() throws {
        let coordinator = try loadAuditSource("Epistemos/App/ChatCoordinator.swift")

        #expect(!coordinator.contains("**Approval required:**"))
        #expect(!coordinator.contains("**Denied:**"))
        #expect(!coordinator.contains("**Denied by policy:**"))
        #expect(!coordinator.contains("case .permissionRequired(let request):\n                receivedAgentContent = true"))
    }

    @Test("implicit vault note lookups use a separate provenance contract from attached context")
    func implicitVaultNoteLookupsUseSeparateProvenanceContract() throws {
        let coordinator = try loadAuditSource("Epistemos/App/ChatCoordinator.swift")

        #expect(coordinator.contains("buildRequestedVaultLookupContractSection"))
        #expect(coordinator.contains("Do not describe those notes as attached files or uploads."))
        #expect(coordinator.contains("let hasAttachedUserContext"))
        #expect(coordinator.contains("let hasRequestedVaultLookup"))
    }

    @Test("explicit vault read requests keep lookup discipline even when note context is also attached")
    func explicitVaultReadRequestsKeepLookupDisciplineEvenWhenContextIsAttached() throws {
        let coordinator = try loadAuditSource("Epistemos/App/ChatCoordinator.swift")

        #expect(coordinator.contains("Self.mergedContextSections("))
        #expect(coordinator.contains("hasAttachedUserContext ? Self.buildRequiredAttachmentContractSection() : nil"))
        #expect(coordinator.contains("hasRequestedVaultLookup ? Self.buildRequestedVaultLookupContractSection() : nil"))
        #expect(coordinator.contains("queryRequiresVerifiedVaultRead"))
        #expect(coordinator.contains("Do not open with a provenance sentence like \"I found it in your notes\""))
        #expect(coordinator.contains("say plainly that you couldn't find or read the note in the user's notes"))
        #expect(coordinator.contains("I couldn't find a note titled"))
        #expect(coordinator.contains("I couldn't read \\\""))
        #expect(!coordinator.contains("so I won't pretend the lookup succeeded"))
        #expect(coordinator.contains("Conversation history or attached context may mention the same note"))
    }

    @Test("explicit file operations keep exact user paths stable across runtime prompts")
    func explicitFileOperationsKeepExactUserPathsStable() throws {
        let coordinator = try loadAuditSource("Epistemos/App/ChatCoordinator.swift")

        #expect(coordinator.contains("let hasRequestedFileOperation"))
        #expect(coordinator.contains("buildRequestedFileOperationContractSection"))
        #expect(coordinator.contains("If the user already provided a path, use that exact path."))
        #expect(coordinator.contains("File tools can use explicit filesystem paths the user provided"))
        #expect(coordinator.contains("including absolute paths and ~/ home expansion"))
        #expect(coordinator.contains("Do not invent alternate file names, directories, or fallback paths."))
        #expect(coordinator.contains("Do not rewrite absolute paths into vault-relative guesses"))
        #expect(coordinator.contains("If the user asks you to write a file and then read it back, do the write first and then read that same exact path."))
        #expect(coordinator.contains("If the exact requested path fails, explain that exact failure instead of pretending a nearby path worked."))
        #expect(coordinator.contains("hasRequestedFileOperation ? Self.buildRequestedFileOperationContractSection() : nil"))
    }

    @Test("explicit note writes keep a real vault_write contract across runtime prompts")
    func explicitNoteWritesKeepAVaultWriteContractAcrossRuntimePrompts() throws {
        let coordinator = try loadAuditSource("Epistemos/App/ChatCoordinator.swift")
        let promptBuilder = try loadAuditSource("Epistemos/LocalAgent/LocalAgentPromptBuilder.swift")

        #expect(coordinator.contains("let hasRequestedNoteWriteOperation"))
        #expect(coordinator.contains("queryContainsExplicitNoteWriteOperation"))
        #expect(coordinator.contains("buildRequestedNoteWriteContractSection"))
        #expect(coordinator.contains("Use `vault_write` to create or update the note"))
        #expect(coordinator.contains("If the user asks you to create or update a note and then read it back"))
        #expect(promptBuilder.contains("For vault note creation or updates, use vault_write"))
        #expect(promptBuilder.contains("Do not claim a note was created, updated, or read back"))
    }

    @Test("embedded rust dylibs still ad hoc sign when hosted tests disable app signing")
    func embeddedRustDylibsStillAdHocSignWithoutAppSigning() throws {
        let helper = try loadAuditSource("embed-and-sign-rust-dylib.sh")

        #expect(helper.contains("if [ \"${CODE_SIGNING_ALLOWED:-NO}\" != \"YES\" ]; then"))
        #expect(helper.contains("codesign --force --sign - --timestamp=none \"$DEST_DYLIB\""))
    }

    @Test("live SSM smoke keeps a hard main-actor timeout guard")
    func liveSSMSmokeKeepsHardTimeoutGuard() throws {
        let source = try loadAuditSource("EpistemosTests/LocalRuntimeSmokeSupport.swift")

        #expect(source.contains("static func verifyLiveSSMStateRoundTrip("))
        #expect(source.contains("withTimedMainActorBridge(seconds: 180)"))
    }

    @Test("live SSM smoke only enters the round-trip path for preinstalled models")
    func liveSSMSmokeRequiresPreinstalledModels() throws {
        let source = try loadAuditSource("EpistemosTests/LocalRuntimeSmokeSupport.swift")

        #expect(source.contains("bootstrap.localModelManager.refreshFromDisk()"))
        #expect(source.contains("guard bootstrap.localModelManager.installRecords[modelID] != nil else {"))
        #expect(source.contains("LOCAL_SSM_SMOKE skipped model="))
        #expect(source.contains("reason=preinstalled model required"))
    }

    @Test("model profile creation sheet avoids retired Hermes local labels")
    func modelProfileCreationSheetAvoidsRetiredHermesLabels() throws {
        let source = try loadAuditSource("Epistemos/Views/ModelProfiles/ModelProfileCreationSheet.swift")

        #expect(!source.contains("Hermes 3 8B"))
        #expect(!source.contains("Gemma 4 4B"))
        #expect(source.contains("Qwen 3 4B"))
        #expect(source.contains("Bonsai 4B"))
    }

    @Test("release archive no longer strips linked agent dylibs or disables agent services")
    func releaseArchiveKeepsLinkedAgentDylibsAndServices() throws {
        let spec = try loadAuditSource("project.yml")
        let bootstrap = try loadAuditSource("Epistemos/App/AppBootstrap.swift")

        #expect(spec.contains(#"bash \"${SRCROOT}/build-rust.sh\""#))
        #expect(spec.contains(#"bash \"${SRCROOT}/build-syntax-core.sh\""#))
        #expect(spec.contains(#"bash \"${SRCROOT}/build-omega-mcp.sh\""#))
        #expect(spec.contains(#"bash \"${SRCROOT}/build-omega-ax.sh\""#))
        #expect(spec.contains(#"bash \"${SRCROOT}/build-epistemos-core.sh\""#))
        #expect(spec.contains(#"bash \"${SRCROOT}/build-agent-core.sh\""#))
        #expect(!spec.contains("SHIP_MODE=release"))
        #expect(!spec.contains("skipping agent crates"))
        #expect(bootstrap.contains("static let agentsEnabled = true"))
        #expect(!bootstrap.contains("static let agentsEnabled = false"))
    }

    @Test("inference state skips blocking keychain warmup while hosted tests boot")
    func inferenceStateSkipsBlockingKeychainWarmupDuringTests() throws {
        let source = try loadAuditSource("Epistemos/State/InferenceState.swift")

        #expect(source.contains("private nonisolated static let isRunningTests"))
        #expect(source.contains("private nonisolated static func defaultKeychainLoad"))
        #expect(source.contains("private nonisolated static func defaultKeychainSave"))
        #expect(source.contains("private nonisolated static func defaultKeychainDelete"))
        #expect(source.contains("guard !isRunningTests else { return nil }"))
        #expect(source.contains("guard !isRunningTests else { return false }"))
        #expect(source.contains("keychainLoad: @escaping (String) -> String? = InferenceState.defaultKeychainLoad"))
    }

    @MainActor
    @Test("session graph generation decodes the current Rust session graph payload")
    func sessionGraphGenerationDecodesCurrentRustSessionGraphPayload() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessionFolder = root.appendingPathComponent("session_knowledge_graph", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "".write(
            to: sessionFolder.appendingPathComponent("transcript.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        try """
        # Summary

        ## Key Decisions
        Keep the release build fail-closed.
        """.write(
            to: sessionFolder.appendingPathComponent("summary.md"),
            atomically: true,
            encoding: .utf8
        )

        let graphJSON = try generate_session_graph(sessionFolder: sessionFolder.path)
        let graphData = try decodeGraphData(from: Data(graphJSON.utf8))

        #expect(graphData.nodes.contains(where: { $0.id == "session_session_knowledge_graph" }))
    }

    @Test("vault lifecycle merge writes a vault graph after filling missing session graphs")
    func vaultLifecycleMergeWritesVaultGraph() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessionsRoot = root.appendingPathComponent("sessions", isDirectory: true)
        let sessionFolder = sessionsRoot.appendingPathComponent("2026-04-09_release_audit", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try """
        {
          "id": "release-audit-session",
          "model": "gemma-4-4b",
          "provider": "local",
          "started_at": "2026-04-09T18:00:00Z",
          "status": "completed",
          "turn_count": 3
        }
        """.write(
            to: sessionFolder.appendingPathComponent("session.json"),
            atomically: true,
            encoding: .utf8
        )
        try """
        {"content":"We used the release checklist and graph audit.","tool_calls":[{"name":"vault_search"}]}
        """.write(
            to: sessionFolder.appendingPathComponent("transcript.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        try """
        # Summary

        ## Key Decisions
        Restore the buttery graph camera baseline.
        """.write(
            to: sessionFolder.appendingPathComponent("summary.md"),
            atomically: true,
            encoding: .utf8
        )

        let lifecycle = VaultLifecycleService(vaultPath: root.path)
        await lifecycle.mergeVaultGraphs()

        let mergedGraphURL = root.appendingPathComponent("vault_graph.json")
        #expect(FileManager.default.fileExists(atPath: mergedGraphURL.path))

        let mergedGraph = try String(contentsOf: mergedGraphURL, encoding: .utf8)
        #expect(mergedGraph.contains("\"nodes\""))
        #expect(mergedGraph.contains("\"edges\""))
    }
}

private func loadAuditSource(_ relativePath: String) throws -> String {
    try loadMirroredSourceTextFile(relativePath)
}

@MainActor
private func nextPendingApproval(
    from queue: ChatApprovalQueue
) async throws -> ApprovalModalView.PendingApproval {
    for _ in 0..<100 {
        if let pendingApproval = queue.pendingApproval {
            return pendingApproval
        }
        await Task.yield()
    }
    throw ChatApprovalQueueTestError.pendingApprovalNeverArrived
}

private enum ChatApprovalQueueTestError: Error {
    case pendingApprovalNeverArrived
}
