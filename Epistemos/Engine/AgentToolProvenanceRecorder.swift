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
        let trimmedRunID = runID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToolCallID = toolCallID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToolName = toolName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRunID.isEmpty,
              !trimmedToolCallID.isEmpty,
              !trimmedToolName.isEmpty else {
            return false
        }

        let sequence = sequenceByRunID[trimmedRunID] ?? 0
        guard sequence < UInt64.max else { return false }
        sequenceByRunID[trimmedRunID] = sequence + 1

        let event = AgentProvenanceEvent(
            eventID: "agent-event:\(trimmedRunID):\(sequence)",
            runID: trimmedRunID,
            traceID: normalizedOptional(traceID),
            sequence: sequence,
            kind: kind,
            actor: actor,
            occurredAtMs: nowMilliseconds(),
            tool: AgentToolProvenance(
                toolCallID: trimmedToolCallID,
                toolName: trimmedToolName,
                argumentsJSON: normalizedOptional(argumentsJSON) ?? "{}",
                resultJSON: normalizedOptional(resultJSON),
                durationMs: durationMs,
                approvalID: normalizedOptional(approvalID),
                status: status,
                errorMessage: normalizedOptional(errorMessage)
            ),
            metadata: metadata
        )
        return persist(event)
    }

    private func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }
}
