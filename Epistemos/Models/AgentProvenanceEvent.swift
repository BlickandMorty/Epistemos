import Foundation

nonisolated public enum AgentProvenanceEventKind: String, Codable, Sendable, Hashable, CaseIterable {
    case runStarted = "run_started"
    case runCompleted = "run_completed"
    case routerDecision = "router_decision"
    case toolCallRequested = "tool_call_requested"
    case toolCallApproved = "tool_call_approved"
    case toolCallDenied = "tool_call_denied"
    case toolCallStarted = "tool_call_started"
    case toolCallCompleted = "tool_call_completed"
    case toolCallFailed = "tool_call_failed"
}

nonisolated public enum AgentProvenanceActor: Codable, Sendable, Hashable {
    case user
    case agent(id: String, modelID: String?)
    case system

    private enum CodingKeys: String, CodingKey {
        case kind
        case id
        case modelID = "model_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "user":
            self = .user
        case "agent":
            self = .agent(
                id: try c.decode(String.self, forKey: .id),
                modelID: try c.decodeIfPresent(String.self, forKey: .modelID)
            )
        case "system":
            self = .system
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: c,
                debugDescription: "Unknown AgentProvenanceActor kind: \(kind)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .user:
            try c.encode("user", forKey: .kind)
        case .agent(let id, let modelID):
            try c.encode("agent", forKey: .kind)
            try c.encode(id, forKey: .id)
            try c.encodeIfPresent(modelID, forKey: .modelID)
        case .system:
            try c.encode("system", forKey: .kind)
        }
    }
}

nonisolated public enum AgentToolEventStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case requested
    case approved
    case denied
    case started
    case completed
    case failed
}

nonisolated public struct AgentToolProvenance: Codable, Sendable, Hashable {
    public let toolCallID: String
    public let toolName: String
    public let argumentsJSON: String
    public let resultJSON: String?
    public let durationMs: UInt64?
    public let approvalID: String?
    public let status: AgentToolEventStatus
    public let errorMessage: String?

    public init(
        toolCallID: String,
        toolName: String,
        argumentsJSON: String,
        resultJSON: String?,
        durationMs: UInt64?,
        approvalID: String?,
        status: AgentToolEventStatus,
        errorMessage: String? = nil
    ) {
        self.toolCallID = toolCallID
        self.toolName = toolName
        self.argumentsJSON = argumentsJSON
        self.resultJSON = resultJSON
        self.durationMs = durationMs
        self.approvalID = approvalID
        self.status = status
        self.errorMessage = errorMessage
    }

    private enum CodingKeys: String, CodingKey {
        case toolCallID = "tool_call_id"
        case toolName = "tool_name"
        case argumentsJSON = "arguments_json"
        case resultJSON = "result_json"
        case durationMs = "duration_ms"
        case approvalID = "approval_id"
        case status
        case errorMessage = "error_message"
    }
}

nonisolated public struct AgentProvenanceEvent: Codable, Sendable, Hashable {
    public static let currentSchemaVersion: UInt32 = 1

    public let eventID: String
    public let runID: String
    public let traceID: String?
    public let sequence: UInt64
    public let kind: AgentProvenanceEventKind
    public let actor: AgentProvenanceActor
    public let occurredAtMs: Int64
    public let tool: AgentToolProvenance?
    public let metadata: [String: String]
    public let schemaVersion: UInt32

    public init(
        eventID: String,
        runID: String,
        traceID: String? = nil,
        sequence: UInt64,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        occurredAtMs: Int64,
        tool: AgentToolProvenance? = nil,
        metadata: [String: String] = [:],
        schemaVersion: UInt32 = Self.currentSchemaVersion
    ) {
        self.eventID = eventID
        self.runID = runID
        self.traceID = traceID
        self.sequence = sequence
        self.kind = kind
        self.actor = actor
        self.occurredAtMs = occurredAtMs
        self.tool = tool
        self.metadata = metadata
        self.schemaVersion = schemaVersion
    }

    private enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case runID = "run_id"
        case traceID = "trace_id"
        case sequence
        case kind
        case actor
        case occurredAtMs = "occurred_at_ms"
        case tool
        case metadata
        case schemaVersion = "schema_version"
    }
}
