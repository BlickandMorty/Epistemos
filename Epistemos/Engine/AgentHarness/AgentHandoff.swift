import Foundation

/// Typed handoff model ported from Rowboat's agent-handoffs.ts. A handoff is
/// *not* just "spawn another agent" — it is a typed, bounded transformation
/// of context from one agent to the next. The three context types carry
/// different schemas and default history filters so sub-agent token usage
/// stays predictable.
nonisolated enum HandoffContextType: String, Codable, Hashable, Sendable {
    /// Linear pipeline: step N feeds step N+1. Last 10 history items kept.
    case pipeline
    /// Specialist task handoff with a focused context. Last 20 history items.
    case task
    /// Direct human-style transfer with minimal context scrubbing.
    case direct
}

extension HandoffContextType {
    var defaultHistoryWindow: Int {
        switch self {
        case .pipeline: 10
        case .task: 20
        case .direct: 40
        }
    }
}

/// Bounded shape of the per-turn context that flows into a handoff. The
/// filter closure on AgentHandoff trims this down before the sub-agent runs.
/// Messages are opaque strings here so this file stays framework-free — the
/// caller wraps their real AgentMessage / SDMessage type via a codable shim.
nonisolated struct HandoffInputData: Sendable {
    let inputHistory: [String]
    let preHandoffItems: [String]
    let newItems: [String]
    let runContext: [String: String]?

    init(
        inputHistory: [String],
        preHandoffItems: [String] = [],
        newItems: [String] = [],
        runContext: [String: String]? = nil
    ) {
        self.inputHistory = inputHistory
        self.preHandoffItems = preHandoffItems
        self.newItems = newItems
        self.runContext = runContext
    }

    func withTrimmedHistory(maxItems: Int) -> HandoffInputData {
        guard inputHistory.count > maxItems else { return self }
        return HandoffInputData(
            inputHistory: Array(inputHistory.suffix(maxItems)),
            preHandoffItems: preHandoffItems,
            newItems: newItems,
            runContext: runContext
        )
    }
}

/// Typed handoff definition. `targetAgentID` names the sub-agent to route
/// into; `toolName` is the OpenAI-function-safe slug the orchestrator
/// exposes for the model to call; `inputFilter` scrubs context down to what
/// the sub-agent actually needs.
nonisolated struct AgentHandoff: Sendable {
    let targetAgentID: String
    let contextType: HandoffContextType
    let toolName: String
    let inputFilter: @Sendable (HandoffInputData) -> HandoffInputData
    let onHandoff: @Sendable ([String: String]) async throws -> Void

    init(
        targetAgentID: String,
        contextType: HandoffContextType,
        toolNameOverride: String? = nil,
        inputFilter: (@Sendable (HandoffInputData) -> HandoffInputData)? = nil,
        onHandoff: @escaping @Sendable ([String: String]) async throws -> Void = { _ in }
    ) {
        self.targetAgentID = targetAgentID
        self.contextType = contextType
        self.toolName = toolNameOverride ?? AgentNameSanitizer.toolName(for: targetAgentID)
        self.inputFilter = inputFilter
            ?? AgentHandoff.defaultFilter(for: contextType)
        self.onHandoff = onHandoff
    }

    private static func defaultFilter(
        for contextType: HandoffContextType
    ) -> @Sendable (HandoffInputData) -> HandoffInputData {
        let window = contextType.defaultHistoryWindow
        return { data in
            data.withTrimmedHistory(maxItems: window)
        }
    }
}

/// OpenAI function-name compliance: function/tool names must match
/// `^[a-zA-Z0-9_-]{1,64}$`. Rowboat slugifies with the same allow-set and
/// caps at 50 chars — we mirror that to stay interop-safe if an OpenAI
/// backend ever appears behind AgentBackend.
nonisolated enum AgentNameSanitizer {
    static func toolName(for rawIdentifier: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        let replaced = String(rawIdentifier.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "_"
        })
        let collapsed = replaced.replacingOccurrences(
            of: "_+",
            with: "_",
            options: .regularExpression
        )
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        let capped = String(trimmed.prefix(50))
        return capped.isEmpty ? "agent_handoff" : capped
    }
}

/// Builds the synthesized system-style context message a pipeline step uses
/// to tell its successor where it sits in the larger run. Rowboat injects
/// this into newItems so each downstream agent can read step N-of-M without
/// any global state.
nonisolated enum PipelineContextMessageBuilder {
    static func message(
        pipelineName: String,
        currentStep: Int,
        totalSteps: Int,
        priorStepResultsJSON: String? = nil
    ) -> String {
        let stepDirection: String = {
            if currentStep + 1 == totalSteps {
                return "Final step. Return the complete pipeline result."
            }
            return "Continue toward the pipeline goal and hand results to the next step."
        }()
        let priorResults = priorStepResultsJSON ?? "No prior step results."
        return """
        Pipeline: \(pipelineName)
        Step: \(currentStep + 1)/\(totalSteps)
        \(stepDirection)
        Prior step results:
        \(priorResults)
        """
    }
}
