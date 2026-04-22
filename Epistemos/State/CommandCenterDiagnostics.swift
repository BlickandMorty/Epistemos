import Foundation

// MARK: - Command Center Execution Diagnostics
//
// Authoritative runtime-truth mirror for the Agent Command Center inspector.
//
// Phase 5 contract: the inspector must display execution truth, not infer it
// from local UI state. Every field on this struct is either:
//   (a) populated by the CommandCenterRequestCompiler at compile time, carrying
//       requested-vs-resolved truth (brain, tools, policy, mention refs), or
//   (b) populated by runtime streaming events during execution, carrying authoritative
//       runtime events (turns, tokens, permissions, sub-agents, compaction, stop reason).
//
// No field on this struct is allowed to be derived from SwiftUI state or from
// heuristic guesses on the Swift side. If the inspector shows a number, that
// number came from either the compiler or the Rust streaming delegate.
//
// Rust control-plane boundary: when the Rust side gains a richer streaming
// contract (e.g. per-turn token deltas, resolved model ID in on_turn_started),
// that data feeds the same fields here — no shape changes needed at the inspector.

struct CommandCenterExecutionDiagnostics: Sendable {
    // ───── Compile-time truth ─────
    var compiledRequest: CompiledCommandCenterRequest?

    // ───── Execution lifecycle ─────
    var state: ExecutionState = .idle
    var startedAt: Date?
    var completedAt: Date?
    var stopReason: String?
    var errorClass: ErrorClass?
    var errorMessage: String?

    // ───── Running counters (source: Rust streaming delegate) ─────
    var currentTurn: Int = 0
    var currentMessageCount: Int = 0
    var tokenAccounting: TokenAccounting = TokenAccounting()

    // ───── Tool history (source: Rust streaming delegate) ─────
    var toolHistory: [ACCToolExecutionRecord] = []
    var activeToolName: String?
    var permissionDecisions: [PermissionDecisionRecord] = []

    // ───── Hierarchy (source: Rust streaming delegate onSubagentSpawned) ─────
    var hierarchyNodes: [AgentHierarchyNode] = []
    /// Root agent (overseer or main) for convenience display.
    var hierarchyRootId: String?

    // ───── Context window events (source: Rust streaming delegate) ─────
    var compactionEvents: [CompactionEvent] = []

    // ───── Fallback events (source: compiler + runtime) ─────
    var fallbackEvents: [FallbackEvent] = []

    /// Reset to idle state, preserving the compiled request summary but clearing
    /// all runtime counters. Called on new submission.
    mutating func resetForNewSubmission() {
        state = .idle
        startedAt = nil
        completedAt = nil
        stopReason = nil
        errorClass = nil
        errorMessage = nil
        currentTurn = 0
        currentMessageCount = 0
        tokenAccounting = TokenAccounting()
        toolHistory = []
        activeToolName = nil
        permissionDecisions = []
        hierarchyNodes = []
        hierarchyRootId = nil
        compactionEvents = []
        fallbackEvents = []
    }

    // MARK: - Requested vs Resolved Accessors
    //
    // These read directly off `compiledRequest` — the inspector uses them to
    // render the "requested vs resolved" tables.

    var requestedBrainLabel: String {
        guard let req = compiledRequest?.requestedBrain else { return "Auto" }
        return req.displayName
    }

    var resolvedBrainLabel: String {
        compiledRequest?.resolvedRuntime.resolved.displayName ?? "—"
    }

    var runtimeFallbackReason: String? {
        compiledRequest?.resolvedRuntime.fallbackReason
    }

    var requestedOperatingModeLabel: String {
        compiledRequest?.requestedOperatingMode.displayName ?? "—"
    }

    var effectiveOperatingModeLabel: String {
        compiledRequest?.resolvedExecutionPolicy.effectiveOperatingMode.displayName ?? "—"
    }

    var resolvedRouteLabel: String {
        guard let route = compiledRequest?.resolvedExecutionPolicy.route else { return "—" }
        switch route {
        case "local_only": return "Direct Chat"
        case "overseer_local_execution": return "Planned Tools"
        case "managed_agent_session": return "Managed Tools"
        default: return route
        }
    }

    var allowedToolCount: Int {
        compiledRequest?.allowedToolNames.count ?? 0
    }

    var totalToolCount: Int {
        compiledRequest?.resolvedToolPermissions.count ?? 0
    }

    var resolvedContextCount: Int {
        compiledRequest?.resolvedContextRefs.count ?? 0
    }

    var resolvedNoteCount: Int {
        compiledRequest?.resolvedContextRefs.filter {
            if case .note = $0 { return true }
            return false
        }.count ?? 0
    }

    var unresolvedMentionCount: Int {
        compiledRequest?.unresolvedMentions.count ?? 0
    }

    var executionPlanSummary: String? {
        compiledRequest?.resolvedExecutionPolicy.summary
    }

    /// Authoritative slash token to render in the inspector.
    ///
    /// Once a submission happens, the ACC clears `accState.activeSlashToken`
    /// (the input-bar chip), so the inspector MUST NOT read from live UI state
    /// for the requested command — the compiled request carries the truth.
    /// Returns nil when there is no compiled submission yet.
    var requestedSlashToken: SerializedSlashToken? {
        compiledRequest?.requestedSlashToken
    }

    var expertAllowlist: [String] {
        compiledRequest?.resolvedExecutionPolicy.expertAllowlist ?? []
    }

    var contextUsageFraction: Double {
        tokenAccounting.contextUsageFraction
    }

    // MARK: - Event Ingestion
    //
    // These mutators are called from ChatCoordinator.runCommandCenterRustAgentPath
    // as streaming events arrive from the Rust delegate. They are the ONLY way
    // runtime state should enter this struct — no inspector-side writes.

    mutating func ingestCompiledRequest(_ request: CompiledCommandCenterRequest) {
        self.compiledRequest = request
        // Seed max context tokens from the resolved execution policy's depth budget.
        self.tokenAccounting.maxContextTokens = request.resolvedExecutionPolicy.maxOutputTokens * 4
        // Seed a fallback event if the runtime had to downgrade the brain.
        if let reason = request.resolvedRuntime.fallbackReason {
            self.fallbackEvents.append(
                FallbackEvent(
                    at: request.compiledAt,
                    from: request.resolvedRuntime.requested?.displayName ?? "auto",
                    to: request.resolvedRuntime.resolved.displayName,
                    reason: reason,
                    kind: .brain
                )
            )
        }
    }

    mutating func markCompiling() {
        self.state = .compiling
    }

    mutating func markRunning() {
        self.state = .running
        self.startedAt = Date()
    }

    mutating func markCompleted(stopReason: String?, inputTokens: Int, outputTokens: Int) {
        self.state = .completed
        self.completedAt = Date()
        self.stopReason = stopReason
        self.tokenAccounting.inputTokens = inputTokens
        self.tokenAccounting.outputTokens = outputTokens
    }

    mutating func markFailed(errorClass: ErrorClass, message: String) {
        self.state = .failed
        self.completedAt = Date()
        self.errorClass = errorClass
        self.errorMessage = message
    }

    mutating func markCancelled() {
        self.state = .failed
        self.completedAt = Date()
        self.errorClass = .cancellation
    }

    mutating func recordTurnStarted(turn: Int, messageCount: Int) {
        self.currentTurn = turn
        self.currentMessageCount = messageCount
    }

    mutating func recordActiveTool(name: String?) {
        self.activeToolName = name
    }

    mutating func recordToolExecution(_ record: ACCToolExecutionRecord) {
        self.toolHistory.append(record)
    }

    mutating func recordPermissionDecision(_ decision: PermissionDecisionRecord) {
        self.permissionDecisions.append(decision)
    }

    mutating func recordSubagentSpawned(id: String, role: String) {
        let now = Date()
        let hierarchicalRole = HierarchicalAgentRole(rawValue: role) ?? .subAgent
        let parentId = hierarchyRootId
        let node = AgentHierarchyNode(
            id: id,
            role: hierarchicalRole,
            parentId: parentId,
            spawnedAt: now,
            turns: 0
        )
        hierarchyNodes.append(node)
        if hierarchyRootId == nil, hierarchicalRole != .subAgent {
            hierarchyRootId = id
        }
    }

    mutating func recordContextCompacting(tokens: Int) {
        compactionEvents.append(
            CompactionEvent(
                at: Date(),
                tokensBeforeCompaction: tokens,
                messagesAfter: nil
            )
        )
    }

    mutating func recordContextCompacted(messageCount: Int) {
        // Attach to the most recent open compaction event if present.
        if let lastIdx = compactionEvents.indices.last,
           compactionEvents[lastIdx].messagesAfter == nil {
            compactionEvents[lastIdx].messagesAfter = messageCount
        }
    }
}

// MARK: - Supporting Types

extension CommandCenterExecutionDiagnostics {
    enum ExecutionState: String, Sendable {
        case idle
        case compiling
        case running
        case completed
        case failed
    }

    enum ErrorClass: String, Sendable {
        case cancellation
        case providerFailure
        case toolFailure
        case permissionDenied
        case contextOverflow
        case planningFailed
        case runtimeUnavailable
        case unknown
    }

    struct TokenAccounting: Sendable, Equatable {
        var inputTokens: Int = 0
        var outputTokens: Int = 0
        var estimatedContextTokens: Int = 0
        var maxContextTokens: Int = 0

        var totalTokens: Int { inputTokens + outputTokens }

        var contextUsageFraction: Double {
            guard maxContextTokens > 0 else { return 0 }
            return min(1, Double(estimatedContextTokens) / Double(maxContextTokens))
        }
    }

    struct PermissionDecisionRecord: Sendable, Identifiable, Equatable {
        /// permission_id from Rust.
        let id: String
        let toolName: String
        let riskLevel: String
        let decision: Decision
        let at: Date

        enum Decision: String, Sendable, Equatable {
            case approvedAutoReadOnly
            case approvedByUser
            case deniedByUser
            case deniedByPolicy
        }
    }

    struct AgentHierarchyNode: Sendable, Identifiable, Equatable {
        /// agent_id from Rust onSubagentSpawned.
        let id: String
        let role: HierarchicalAgentRole
        let parentId: String?
        let spawnedAt: Date
        var turns: Int
    }

    struct CompactionEvent: Sendable, Identifiable, Equatable {
        let id: String
        let at: Date
        let tokensBeforeCompaction: Int
        var messagesAfter: Int?

        init(
            id: String = UUID().uuidString,
            at: Date,
            tokensBeforeCompaction: Int,
            messagesAfter: Int?
        ) {
            self.id = id
            self.at = at
            self.tokensBeforeCompaction = tokensBeforeCompaction
            self.messagesAfter = messagesAfter
        }
    }

    struct FallbackEvent: Sendable, Identifiable, Equatable {
        let id: String
        let at: Date
        let from: String
        let to: String
        let reason: String
        let kind: Kind

        init(
            id: String = UUID().uuidString,
            at: Date,
            from: String,
            to: String,
            reason: String,
            kind: Kind
        ) {
            self.id = id
            self.at = at
            self.from = from
            self.to = to
            self.reason = reason
            self.kind = kind
        }

        enum Kind: String, Sendable, Equatable {
            case brain
            case tool
            case provider
            case policy
        }
    }
}
