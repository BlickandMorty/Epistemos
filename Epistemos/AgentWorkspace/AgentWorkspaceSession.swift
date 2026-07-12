import Foundation
import Observation
import OSLog

// Legacy Surface B session state from the pre-June MAS plan. The App Store
// build now ships MAS June as the only user-facing agent surface, so this
// transcript/runtime wrapper stays out of MAS builds. `AgentApprovalGate`
// remains below the guard because MAS June's approval registry still uses the
// tiny synchronization primitive.

#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)

nonisolated enum AgentTimelineItem: Identifiable, Equatable, Sendable, Codable {
    struct ToolCall: Equatable, Sendable, Codable {
        let id: String
        let name: String
        let inputJson: String
        var result: String?
        var isError: Bool
        var isRunning: Bool
    }

    case turnStarted(id: UUID, number: Int)
    case thinking(id: UUID, text: String)
    case assistantText(id: UUID, text: String)
    case tool(id: UUID, call: ToolCall)
    case notice(id: UUID, text: String)
    case completed(id: UUID, stopReason: String, inputTokens: Int, outputTokens: Int)

    var id: UUID {
        switch self {
        case .turnStarted(let id, _),
             .thinking(let id, _),
             .assistantText(let id, _),
             .tool(let id, _),
             .notice(let id, _),
             .completed(let id, _, _, _):
            return id
        }
    }
}

nonisolated struct AgentApprovalRequest: Identifiable, Equatable, Sendable {
    let id: String
    let toolName: String
    let inputJson: String
    let riskLevel: String
}

nonisolated struct AgentWorkspaceRun: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let objective: String
    let startedAt: Date
    var items: [AgentTimelineItem]
    var isActive: Bool

    init(objective: String) {
        self.id = UUID()
        self.objective = objective
        self.startedAt = Date()
        self.items = []
        self.isActive = true
    }
}

@MainActor
@Observable
final class AgentWorkspaceSession {
    private static let log = Logger(subsystem: "com.epistemos", category: "AgentWorkspace")

    /// Cloud provider slug for v1 dev runs (§3.1: swaps to the
    /// "epistemos-cloud" proxy provider when Phase 3's proxy is live —
    /// same stack, different base URL; key stays in Keychain either way).
    static let defaultProviderSlug = "claude_sonnet"

    private(set) var runs: [AgentWorkspaceRun] = []
    private(set) var isRunning = false
    var pendingApproval: AgentApprovalRequest?
    private(set) var lastTouchedFilePath: String?

    private let runner = GooseMASAgentCoreRunner()
    private var streamTask: Task<Void, Never>?
    private let approvalGate = AgentApprovalGate()

    var activeRun: AgentWorkspaceRun? {
        runs.last(where: \.isActive) ?? runs.last
    }

    init() {
        runs = Self.loadPersistedRuns()
    }

    // MARK: - Persistence (§3.1 — transcripts survive app restart)

    private static let maxPersistedRuns = 50

    private static func transcriptURL() -> URL? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) else { return nil }
        let dir = base.appendingPathComponent("AgentWorkspace", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("transcripts.json")
    }

    private static func loadPersistedRuns() -> [AgentWorkspaceRun] {
        guard let url = transcriptURL(),
              let data = try? Data(contentsOf: url),
              var decoded = try? JSONDecoder().decode([AgentWorkspaceRun].self, from: data) else {
            return []
        }
        // A run persisted mid-flight (crash/quit) is no longer active.
        for index in decoded.indices { decoded[index].isActive = false }
        return decoded
    }

    private func persistRuns() {
        guard let url = Self.transcriptURL() else { return }
        let bounded = Array(runs.suffix(Self.maxPersistedRuns))
        // Encode off the main actor; the value type is Sendable.
        Task.detached(priority: .utility) {
            guard let data = try? JSONEncoder().encode(bounded) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - Run lifecycle

    func start(objective rawObjective: String, vaultPath: String) {
        let objective = rawObjective.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !objective.isEmpty, !isRunning else { return }

        let run = AgentWorkspaceRun(objective: objective)
        runs.append(run)
        isRunning = true

        let runID = run.id
        let sessionID = "surface-b-\(runID.uuidString.prefix(8))"
        // NEVER default to $HOME: session startup indexes the vault path
        // recursively (measured: unbounded crawl). Empty vault → bounded
        // scratch inside the container.
        let boundedVaultPath = Self.boundedVaultPath(from: vaultPath)

        let stream = runner.streamGooseMASAgentCoreRun(
            sessionID: sessionID,
            prompt: objective,
            systemPrompt: nil,
            maxTokens: 8_192,
            providerName: Self.defaultProviderSlug,
            vaultPath: boundedVaultPath,
            permissionHandler: { [weak self] request in
                Self.blockingApprovalDecision(session: self, request: request)
            }
        )

        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in stream {
                    self.apply(event, to: runID)
                }
            } catch {
                self.append(.notice(id: UUID(), text: "Run failed: \(error.localizedDescription)"), to: runID)
            }
            self.finish(runID: runID)
        }
        _ = run
    }

    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        // Unblock any parked permission wait as a denial.
        if let pending = pendingApproval {
            resolveApproval(id: pending.id, approved: false)
        }
    }

    func resolveApproval(id: String, approved: Bool) {
        pendingApproval = nil
        approvalGate.deliver(id: id, approved: approved)
    }

    // MARK: - Event application

    private func apply(_ event: GooseMASAgentCoreRunEvent, to runID: UUID) {
        switch event {
        case .textDelta(let delta):
            appendOrExtendText(delta, to: runID)
        case .thinkingDelta(let delta):
            appendOrExtendThinking(delta, to: runID)
        case .toolStarted(let id, let name, let inputJson):
            append(.tool(id: UUID(), call: .init(
                id: id, name: name, inputJson: inputJson,
                result: nil, isError: false, isRunning: true
            )), to: runID)
            rememberTouchedFile(name: name, inputJson: inputJson)
        case .toolCompleted(let id, _, let result, let isError):
            completeTool(callID: id, result: result, isError: isError, in: runID)
        case .permissionRequired(let id, let toolName, let inputJson, let riskLevel):
            pendingApproval = AgentApprovalRequest(
                id: id, toolName: toolName, inputJson: inputJson, riskLevel: riskLevel
            )
        case .complete(let stopReason, let inputTokens, let outputTokens):
            append(.completed(
                id: UUID(), stopReason: stopReason,
                inputTokens: inputTokens, outputTokens: outputTokens
            ), to: runID)
        case .error(let message):
            append(.notice(id: UUID(), text: message), to: runID)
        }
    }

    private func finish(runID: UUID) {
        if let index = runs.firstIndex(where: { $0.id == runID }) {
            runs[index].isActive = false
        }
        isRunning = false
        pendingApproval = nil
        streamTask = nil
        persistRuns()
    }

    private func append(_ item: AgentTimelineItem, to runID: UUID) {
        guard let index = runs.firstIndex(where: { $0.id == runID }) else { return }
        runs[index].items.append(item)
    }

    private func appendOrExtendText(_ delta: String, to runID: UUID) {
        guard let index = runs.firstIndex(where: { $0.id == runID }) else { return }
        if case .assistantText(let id, let text) = runs[index].items.last {
            runs[index].items[runs[index].items.count - 1] = .assistantText(id: id, text: text + delta)
        } else {
            runs[index].items.append(.assistantText(id: UUID(), text: delta))
        }
    }

    private func appendOrExtendThinking(_ delta: String, to runID: UUID) {
        guard let index = runs.firstIndex(where: { $0.id == runID }) else { return }
        if case .thinking(let id, let text) = runs[index].items.last {
            runs[index].items[runs[index].items.count - 1] = .thinking(id: id, text: text + delta)
        } else {
            runs[index].items.append(.thinking(id: UUID(), text: delta))
        }
    }

    private func completeTool(callID: String, result: String, isError: Bool, in runID: UUID) {
        guard let runIndex = runs.firstIndex(where: { $0.id == runID }) else { return }
        for (itemIndex, item) in runs[runIndex].items.enumerated().reversed() {
            if case .tool(let id, var call) = item, call.id == callID {
                call.result = result
                call.isError = isError
                call.isRunning = false
                runs[runIndex].items[itemIndex] = .tool(id: id, call: call)
                return
            }
        }
    }

    private func rememberTouchedFile(name: String, inputJson: String) {
        guard name.hasPrefix("vault.") else { return }
        guard let data = inputJson.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        if let path = (object["path"] ?? object["file_path"] ?? object["file"]) as? String {
            lastTouchedFilePath = path
        }
    }

    // MARK: - Blocking approval bridge

    /// Runs on the runner's FFI thread: parks until the user decides in the
    /// approval sheet (or the run is cancelled → deny). Never called on the
    /// main actor — the runner invokes it from agent_core's thread pool.
    private nonisolated static func blockingApprovalDecision(
        session: AgentWorkspaceSession?,
        request: GooseMASAgentCorePermissionRequest
    ) -> Bool {
        guard let session else { return false }
        let approval = AgentApprovalRequest(
            id: request.id,
            toolName: request.toolName,
            inputJson: request.inputJson,
            riskLevel: request.riskLevel
        )
        let gate = session.approvalGate
        Task { @MainActor in
            session.pendingApproval = approval
        }
        return gate.awaitDecision(id: request.id)
    }

    private static func boundedVaultPath(from candidate: String) -> String {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != NSHomeDirectory(),
           FileManager.default.fileExists(atPath: trimmed) {
            return trimmed
        }
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-workspace-scratch", isDirectory: true)
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        return scratch.path
    }
}

#endif // !(EPISTEMOS_APP_STORE || MAS_SANDBOX) -- legacy AgentWorkspaceSession parked in MAS

// SAFETY: all mutable state (decisions) is guarded by the NSCondition on
// every access; awaitDecision parks the runner's FFI thread (never main) until
// deliver() signals from the main actor. Shared by MAS June and the parked
// legacy AgentWorkspace session.
nonisolated final class AgentApprovalGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var decisions: [String: Bool] = [:]

    func deliver(id: String, approved: Bool) {
        condition.lock()
        decisions[id] = approved
        condition.broadcast()
        condition.unlock()
    }

    /// Blocks the calling (FFI) thread until a decision lands or the
    /// 10-minute deadline passes (deadline → deny; never wedge the agent).
    func awaitDecision(id: String) -> Bool {
        condition.lock()
        defer { condition.unlock() }
        let deadline = Date().addingTimeInterval(600)
        while Date() < deadline {
            if let decision = decisions.removeValue(forKey: id) {
                return decision
            }
            condition.wait(until: min(deadline, Date().addingTimeInterval(1)))
        }
        return false
    }
}
