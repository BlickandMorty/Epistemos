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
        #expect(source.contains("Gemma 4 4B"))
    }

    @Test("release archive no longer strips linked agent dylibs or disables agent services")
    func releaseArchiveKeepsLinkedAgentDylibsAndServices() throws {
        let spec = try loadAuditSource("project.yml")
        let bootstrap = try loadAuditSource("Epistemos/App/AppBootstrap.swift")

        #expect(spec.contains(#"bash \"${SRCROOT}/build-rust.sh\""#))
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
