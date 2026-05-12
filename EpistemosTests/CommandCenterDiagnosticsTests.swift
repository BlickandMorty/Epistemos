import Foundation
import Testing
@testable import Epistemos

// MARK: - Command Center Diagnostics Contract Tests
//
// These tests pin the Phase 5 contract for the inspector diagnostics shape:
//   - ingesting a compiled request preserves requested vs resolved
//   - streaming events mutate diagnostics in the same way the ChatCoordinator
//     mutates them at runtime
//   - resetForNewSubmission clears runtime state but preserves compile-time
//     shape
//   - fallback events are recorded whenever the runtime has to downgrade the
//     requested brain

@MainActor
struct CommandCenterDiagnosticsTests {

    // MARK: - Fixtures

    private static func makeCompiledRequest(
        requestedBrain: ACCBrainSelection? = nil,
        resolvedRuntime: ResolvedRuntime = ResolvedRuntime(
            requested: nil,
            resolved: .appleIntelligence,
            fallbackReason: nil
        ),
        allowedToolCount: Int = 0,
        totalToolCount: Int = 0,
        resolvedRefs: [ResolvedContextRef] = []
    ) -> CompiledCommandCenterRequest {
        let tools: [ResolvedToolPermission] = (0 ..< totalToolCount).map { idx in
            ResolvedToolPermission(
                toolName: "tool_\(idx)",
                agent: "notes",
                description: "",
                decision: idx < allowedToolCount ? .allow : .deny(reason: "not_enabled_by_user"),
                requiresConfirmation: false,
                destructive: false
            )
        }
        return CompiledCommandCenterRequest(
            contractVersion: CommandCenterRequestCompiler.contractVersion,
            compiledAt: Date(),
            query: "test",
            conversationHistory: nil,
            requestedSlashToken: nil,
            requestedOperatingMode: .agent,
            requestedBrain: requestedBrain.map(SerializedBrainSelection.init),
            requestedToolNames: Set(tools.prefix(allowedToolCount).map(\.toolName)),
            requestedMentions: [],
            resolvedRuntime: resolvedRuntime,
            resolvedToolPermissions: tools,
            resolvedContextRefs: resolvedRefs,
            resolvedExecutionPolicy: ResolvedExecutionPolicy(
                requestedOperatingMode: .agent,
                effectiveOperatingMode: .agent,
                route: "managed_agent_session",
                maxTurns: 8,
                maxReasoningSteps: 24,
                maxToolCalls: 32,
                maxOutputTokens: 32768,
                expertAllowlist: ["general"],
                summary: "stub summary"
            ),
            notesContext: nil,
            graphContext: nil
        )
    }

    // MARK: - Compile-time truth ingestion

    @Test("ingestCompiledRequest preserves requested brain identity and resolved brain label")
    func ingestCompiledRequestPreservesRequestedVsResolved() async throws {
        var diagnostics = CommandCenterExecutionDiagnostics()
        let requested: ACCBrainSelection = .local(
            modelId: "qwen35_4b",
            displayName: "Qwen 3.5 4B",
            supportsThinking: true,
            supportsVision: false,
            supportsTools: true
        )
        let compiled = Self.makeCompiledRequest(
            requestedBrain: requested,
            resolvedRuntime: ResolvedRuntime(
                requested: requested,
                resolved: .appleIntelligence,
                fallbackReason: "requested_brain_unavailable"
            )
        )
        diagnostics.ingestCompiledRequest(compiled)

        #expect(diagnostics.requestedBrainLabel == "Qwen 3.5 4B")
        #expect(diagnostics.resolvedBrainLabel == "Apple Intelligence")
        #expect(diagnostics.runtimeFallbackReason == "requested_brain_unavailable")
    }

    @Test("ingestCompiledRequest seeds a fallback event when runtime downgrades the brain")
    func ingestCompiledRequestSeedsFallbackEventOnBrainDowngrade() async throws {
        var diagnostics = CommandCenterExecutionDiagnostics()
        let requested: ACCBrainSelection = .local(
            modelId: "ghost",
            displayName: "Ghost",
            supportsThinking: false,
            supportsVision: false,
            supportsTools: false
        )
        let compiled = Self.makeCompiledRequest(
            requestedBrain: requested,
            resolvedRuntime: ResolvedRuntime(
                requested: requested,
                resolved: .appleIntelligence,
                fallbackReason: "requested_brain_unavailable"
            )
        )
        diagnostics.ingestCompiledRequest(compiled)

        #expect(diagnostics.fallbackEvents.count == 1)
        #expect(diagnostics.fallbackEvents[0].kind == .brain)
        #expect(diagnostics.fallbackEvents[0].from == "Ghost")
        #expect(diagnostics.fallbackEvents[0].to == "Apple Intelligence")
    }

    @Test("no fallback event is emitted when the requested brain is honored")
    func noFallbackEventWhenBrainHonored() async throws {
        var diagnostics = CommandCenterExecutionDiagnostics()
        let compiled = Self.makeCompiledRequest(
            requestedBrain: .appleIntelligence,
            resolvedRuntime: ResolvedRuntime(
                requested: .appleIntelligence,
                resolved: .appleIntelligence,
                fallbackReason: nil
            )
        )
        diagnostics.ingestCompiledRequest(compiled)
        #expect(diagnostics.fallbackEvents.isEmpty)
    }

    // MARK: - Runtime event ingestion

    @Test("recordTurnStarted updates current turn and message count")
    func recordTurnStartedUpdatesCounters() async throws {
        var diagnostics = CommandCenterExecutionDiagnostics()
        diagnostics.recordTurnStarted(turn: 3, messageCount: 10)
        #expect(diagnostics.currentTurn == 3)
        #expect(diagnostics.currentMessageCount == 10)
    }

    @Test("recordToolExecution appends to toolHistory (ordered)")
    func recordToolExecutionAppendsOrdered() async throws {
        var diagnostics = CommandCenterExecutionDiagnostics()
        diagnostics.recordToolExecution(ACCToolExecutionRecord(
            id: "t1", toolName: "vault.read", inputSummary: "", resultSummary: "ok",
            durationMs: 120, isError: false
        ))
        diagnostics.recordToolExecution(ACCToolExecutionRecord(
            id: "t2", toolName: "vault.write", inputSummary: "", resultSummary: "err",
            durationMs: 240, isError: true
        ))
        #expect(diagnostics.toolHistory.count == 2)
        #expect(diagnostics.toolHistory[0].toolName == "vault.read")
        #expect(diagnostics.toolHistory[1].isError)
    }

    @Test("recordPermissionDecision tracks every permission_id the runtime raised")
    func recordPermissionDecisionTracksAll() async throws {
        var diagnostics = CommandCenterExecutionDiagnostics()
        diagnostics.recordPermissionDecision(
            CommandCenterExecutionDiagnostics.PermissionDecisionRecord(
                id: "p1",
                toolName: "vault.read",
                riskLevel: "readOnly",
                decision: .approvedAutoReadOnly,
                at: Date()
            )
        )
        diagnostics.recordPermissionDecision(
            CommandCenterExecutionDiagnostics.PermissionDecisionRecord(
                id: "p2",
                toolName: "vault.write",
                riskLevel: "modification",
                decision: .deniedByPolicy,
                at: Date()
            )
        )
        #expect(diagnostics.permissionDecisions.count == 2)
        #expect(diagnostics.permissionDecisions[0].decision == .approvedAutoReadOnly)
        #expect(diagnostics.permissionDecisions[1].decision == .deniedByPolicy)
    }

    @Test("recordSubagentSpawned grows the hierarchy list and stamps an overseer/main root")
    func recordSubagentSpawnedGrowsHierarchy() async throws {
        var diagnostics = CommandCenterExecutionDiagnostics()
        diagnostics.recordSubagentSpawned(id: "agent_root", role: "main_agent")
        diagnostics.recordSubagentSpawned(id: "agent_child_1", role: "sub_agent")
        diagnostics.recordSubagentSpawned(id: "agent_child_2", role: "sub_agent")

        #expect(diagnostics.hierarchyNodes.count == 3)
        #expect(diagnostics.hierarchyRootId == "agent_root")
        #expect(diagnostics.hierarchyNodes[1].parentId == "agent_root")
        #expect(diagnostics.hierarchyNodes[2].parentId == "agent_root")
        #expect(diagnostics.hierarchyNodes[0].role == .mainAgent)
        #expect(diagnostics.hierarchyNodes[1].role == .subAgent)
    }

    @Test("recordContextCompacting + recordContextCompacted attaches messages_after to the open event")
    func compactionEventsPairUp() async throws {
        var diagnostics = CommandCenterExecutionDiagnostics()
        diagnostics.recordContextCompacting(tokens: 28_000)
        diagnostics.recordContextCompacted(messageCount: 14)

        #expect(diagnostics.compactionEvents.count == 1)
        #expect(diagnostics.compactionEvents[0].tokensBeforeCompaction == 28_000)
        #expect(diagnostics.compactionEvents[0].messagesAfter == 14)
    }

    // MARK: - Lifecycle

    @Test("markRunning → markCompleted transitions through the expected execution states")
    func lifecycleStateTransitions() async throws {
        var diagnostics = CommandCenterExecutionDiagnostics()
        #expect(diagnostics.state == .idle)
        diagnostics.markCompiling()
        #expect(diagnostics.state == .compiling)
        diagnostics.markRunning()
        #expect(diagnostics.state == .running)
        #expect(diagnostics.startedAt != nil)
        diagnostics.markCompleted(stopReason: "end_turn", inputTokens: 1200, outputTokens: 800)
        #expect(diagnostics.state == .completed)
        #expect(diagnostics.stopReason == "end_turn")
        #expect(diagnostics.tokenAccounting.inputTokens == 1200)
        #expect(diagnostics.tokenAccounting.outputTokens == 800)
        #expect(diagnostics.tokenAccounting.totalTokens == 2000)
    }

    @Test("markFailed records error class and message")
    func failureRecordsErrorClass() async throws {
        var diagnostics = CommandCenterExecutionDiagnostics()
        diagnostics.markFailed(errorClass: .providerFailure, message: "rate limit")
        #expect(diagnostics.state == .failed)
        #expect(diagnostics.errorClass == .providerFailure)
        #expect(diagnostics.errorMessage == "rate limit")
    }

    // MARK: - P2 regression pin: diagnostics-driven command intent

    @Test("diagnostics.requestedSlashToken is sourced from compiled request, not live UI state")
    func requestedSlashTokenReadsFromCompiledRequest() async throws {
        var diagnostics = CommandCenterExecutionDiagnostics()

        // Pre-compile: no slash token available.
        #expect(diagnostics.requestedSlashToken == nil)

        // Ingest a compiled request carrying a /plan token.
        let request = ACCCommandRequest(
            query: "plan a new feature",
            slashToken: .builtinMode(.plan),
            mentions: [],
            enabledToolNames: [],
            brainOverride: nil,
            operatingMode: .agent,
            graphContext: nil
        )
        let compiler = CommandCenterRequestCompiler(
            dependencies: CommandCenterRequestCompiler.Dependencies(
                findNotesByTitle: { _ in [] },
                fetchNoteBodies: { _ in [] },
                searchIndex: { _ in [] },
                availableBrains: { [.appleIntelligence] },
                preferredAutoBrain: { .appleIntelligence },
                vaultPath: { "" }
            )
        )
        let compiled = await compiler.compile(request: request, conversationHistory: nil)
        diagnostics.ingestCompiledRequest(compiled)

        // After ingest, the inspector must be able to render the intent from
        // diagnostics alone — even though the live command bar will have
        // cleared its activeSlashToken by this point.
        #expect(diagnostics.requestedSlashToken != nil)
        #expect(diagnostics.requestedSlashToken?.identifier == "plan")
        #expect(diagnostics.requestedSlashToken?.displayName == "Plan")
    }

    @Test("resetForNewSubmission clears runtime counters but compiledRequest stays null")
    func resetForNewSubmissionClearsRuntime() async throws {
        var diagnostics = CommandCenterExecutionDiagnostics()
        diagnostics.recordTurnStarted(turn: 5, messageCount: 12)
        diagnostics.recordToolExecution(ACCToolExecutionRecord(
            toolName: "vault.read", inputSummary: "", resultSummary: "",
            durationMs: 10, isError: false
        ))
        diagnostics.markRunning()

        diagnostics.resetForNewSubmission()
        #expect(diagnostics.state == .idle)
        #expect(diagnostics.currentTurn == 0)
        #expect(diagnostics.currentMessageCount == 0)
        #expect(diagnostics.toolHistory.isEmpty)
        #expect(diagnostics.hierarchyNodes.isEmpty)
        #expect(diagnostics.compactionEvents.isEmpty)
    }
}
