import Foundation

@MainActor
final class AgentToolProvenanceRecorder: @unchecked Sendable {
    typealias Persist = @MainActor (AgentProvenanceEvent) -> Bool

    private var sequenceByRunID: [String: UInt64] = [:]
    private let nowMilliseconds: @MainActor () -> Int64
    private let persist: Persist

    init(
        nowMilliseconds: @escaping @MainActor () -> Int64 = {
            let milliseconds = Date().timeIntervalSince1970 * 1_000
            guard milliseconds.isFinite else { return 0 }
            return Int64(milliseconds.rounded())
        },
        persist: @escaping Persist = { event in
            EventStore.shared?.saveAgentEvent(event) ?? false
        }
    ) {
        self.nowMilliseconds = nowMilliseconds
        self.persist = persist
    }

    @discardableResult
    func recordRunEvent(
        runID: String,
        traceID: String?,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        metadata: [String: String] = [:]
    ) -> Bool {
        guard let identity = AgentRunProvenanceEventFactory.makeIdentity(runID: runID) else {
            return false
        }

        let sequence = sequenceByRunID[identity.runID] ?? 0
        guard sequence < UInt64.max else { return false }
        sequenceByRunID[identity.runID] = sequence + 1

        let event = AgentRunProvenanceEventFactory.makeRunEvent(
            identity: identity,
            sequence: sequence,
            traceID: traceID,
            kind: kind,
            actor: actor,
            occurredAtMs: nowMilliseconds(),
            metadata: metadata
        )
        return persist(event)
    }

    @discardableResult
    func recordToolEvent(
        runID: String,
        traceID: String?,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        toolCallID: String,
        toolName: String,
        argumentsJSON: String?,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        approvalID: String? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String] = [:]
    ) -> Bool {
        guard let identity = AgentToolProvenanceEventFactory.makeIdentity(
            runID: runID,
            toolCallID: toolCallID,
            toolName: toolName
        ) else {
            return false
        }

        let sequence = sequenceByRunID[identity.runID] ?? 0
        guard sequence < UInt64.max else { return false }
        sequenceByRunID[identity.runID] = sequence + 1

        let event = AgentToolProvenanceEventFactory.makeToolEvent(
            identity: identity,
            sequence: sequence,
            traceID: traceID,
            kind: kind,
            actor: actor,
            occurredAtMs: nowMilliseconds(),
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            approvalID: approvalID,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
        return persist(event)
    }
}

nonisolated final class AgentToolProvenanceSyncRecorder: @unchecked Sendable {
    typealias Persist = @Sendable (AgentProvenanceEvent) -> Bool
    typealias NowMilliseconds = @Sendable () -> Int64

    private var sequenceByRunID: [String: UInt64] = [:]
    private let sequenceLock = NSLock()
    private let nowMilliseconds: NowMilliseconds
    private let persist: Persist

    init(
        nowMilliseconds: @escaping NowMilliseconds = {
            let milliseconds = Date().timeIntervalSince1970 * 1_000
            guard milliseconds.isFinite else { return 0 }
            return Int64(milliseconds.rounded())
        },
        persist: @escaping Persist = { event in
            EventStore.shared?.saveAgentEvent(event) ?? false
        }
    ) {
        self.nowMilliseconds = nowMilliseconds
        self.persist = persist
    }

    @discardableResult
    func recordRunEvent(
        runID: String,
        traceID: String?,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        metadata: [String: String] = [:]
    ) -> Bool {
        guard let identity = AgentRunProvenanceEventFactory.makeIdentity(runID: runID),
              let sequence = nextSequence(for: identity.runID) else {
            return false
        }

        let event = AgentRunProvenanceEventFactory.makeRunEvent(
            identity: identity,
            sequence: sequence,
            traceID: traceID,
            kind: kind,
            actor: actor,
            occurredAtMs: nowMilliseconds(),
            metadata: metadata
        )
        return persist(event)
    }

    @discardableResult
    func recordToolEvent(
        runID: String,
        traceID: String?,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        toolCallID: String,
        toolName: String,
        argumentsJSON: String?,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        approvalID: String? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String] = [:]
    ) -> Bool {
        guard let identity = AgentToolProvenanceEventFactory.makeIdentity(
            runID: runID,
            toolCallID: toolCallID,
            toolName: toolName
        ),
              let sequence = nextSequence(for: identity.runID) else {
            return false
        }

        let event = AgentToolProvenanceEventFactory.makeToolEvent(
            identity: identity,
            sequence: sequence,
            traceID: traceID,
            kind: kind,
            actor: actor,
            occurredAtMs: nowMilliseconds(),
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            approvalID: approvalID,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
        return persist(event)
    }

    private func nextSequence(for runID: String) -> UInt64? {
        sequenceLock.lock()
        defer { sequenceLock.unlock() }

        let sequence = sequenceByRunID[runID] ?? 0
        guard sequence < UInt64.max else { return nil }
        sequenceByRunID[runID] = sequence + 1
        return sequence
    }
}

private nonisolated enum AgentRunProvenanceEventFactory {
    struct Identity: Sendable {
        let runID: String
    }

    static func makeIdentity(runID: String) -> Identity? {
        let trimmedRunID = runID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRunID.isEmpty else { return nil }
        return Identity(runID: trimmedRunID)
    }

    static func makeRunEvent(
        identity: Identity,
        sequence: UInt64,
        traceID: String?,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        occurredAtMs: Int64,
        metadata: [String: String]
    ) -> AgentProvenanceEvent {
        AgentProvenanceEvent(
            eventID: "agent-event:\(identity.runID):\(sequence)",
            runID: identity.runID,
            traceID: normalizedOptional(traceID),
            sequence: sequence,
            kind: kind,
            actor: actor,
            occurredAtMs: occurredAtMs,
            tool: nil,
            metadata: metadata
        )
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }
}

private nonisolated enum AgentToolProvenanceEventFactory {
    struct Identity: Sendable {
        let runID: String
        let toolCallID: String
        let toolName: String
    }

    static func makeIdentity(
        runID: String,
        toolCallID: String,
        toolName: String
    ) -> Identity? {
        let trimmedRunID = runID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToolCallID = toolCallID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToolName = toolName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRunID.isEmpty,
              !trimmedToolCallID.isEmpty,
              !trimmedToolName.isEmpty else {
            return nil
        }
        return Identity(
            runID: trimmedRunID,
            toolCallID: trimmedToolCallID,
            toolName: trimmedToolName
        )
    }

    static func makeToolEvent(
        identity: Identity,
        sequence: UInt64,
        traceID: String?,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        occurredAtMs: Int64,
        argumentsJSON: String?,
        resultJSON: String?,
        durationMs: UInt64?,
        approvalID: String?,
        status: AgentToolEventStatus,
        errorMessage: String?,
        metadata: [String: String]
    ) -> AgentProvenanceEvent {
        AgentProvenanceEvent(
            eventID: "agent-event:\(identity.runID):\(sequence)",
            runID: identity.runID,
            traceID: normalizedOptional(traceID),
            sequence: sequence,
            kind: kind,
            actor: actor,
            occurredAtMs: occurredAtMs,
            tool: AgentToolProvenance(
                toolCallID: identity.toolCallID,
                toolName: identity.toolName,
                argumentsJSON: normalizedOptional(argumentsJSON) ?? "{}",
                resultJSON: normalizedOptional(resultJSON),
                durationMs: durationMs,
                approvalID: normalizedOptional(approvalID),
                status: status,
                errorMessage: normalizedOptional(errorMessage)
            ),
            metadata: metadata
        )
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }
}
