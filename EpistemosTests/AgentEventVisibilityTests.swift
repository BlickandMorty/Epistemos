import Foundation
import Testing
@testable import Epistemos

@Suite("AgentEvent Settings Visibility")
struct AgentEventVisibilityTests {
    private func makeStore() throws -> EventStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-event-visibility-\(UUID().uuidString).sqlite")
        return try #require(EventStore(databaseURL: url))
    }

    private func makeEvent(
        eventID: String,
        runID: String,
        sequence: UInt64,
        kind: AgentProvenanceEventKind,
        toolName: String? = nil
    ) -> AgentProvenanceEvent {
        let tool = toolName.map {
            AgentToolProvenance(
                toolCallID: "tool-call-\(eventID)",
                toolName: $0,
                argumentsJSON: #"{"query":"visibility"}"#,
                resultJSON: #"{"ok":true}"#,
                durationMs: 12,
                approvalID: "approval-\(eventID)",
                status: .completed
            )
        }
        return AgentProvenanceEvent(
            eventID: eventID,
            runID: runID,
            traceID: "trace-\(runID)",
            sequence: sequence,
            kind: kind,
            actor: .agent(id: "agent-\(runID)", modelID: "qwen-local"),
            occurredAtMs: Int64(sequence + 1) * 1_000,
            tool: tool,
            metadata: ["surface": "agent-event-visibility-test"]
        )
    }

    @Test("AgentEvent diagnostics summarize rows, runs, tools, and latest event")
    func agentEventDiagnosticsSummarizeRowsRunsToolsAndLatestEvent() throws {
        let store = try makeStore()
        #expect(store.agentEventDiagnostics() == .empty)

        let first = makeEvent(
            eventID: "agent-event-visibility-1",
            runID: "run-a",
            sequence: 0,
            kind: .toolCallCompleted,
            toolName: "vault_search"
        )
        let latest = makeEvent(
            eventID: "agent-event-visibility-2",
            runID: "run-b",
            sequence: 1,
            kind: .hookCompleted
        )

        #expect(store.saveAgentEvent(first))
        #expect(store.saveAgentEvent(latest))

        let diagnostics = store.agentEventDiagnostics()
        #expect(diagnostics.totalRows == 2)
        #expect(diagnostics.distinctRuns == 2)
        #expect(diagnostics.distinctTools == 1)
        #expect(diagnostics.lastKind == .hookCompleted)
        #expect(diagnostics.latestEvent?.eventID == latest.eventID)
        #expect(diagnostics.latestEvent?.tool == nil)
    }

    @Test("EventStore returns recent AgentEvents in chronological projection order")
    func eventStoreReturnsRecentAgentEventsInChronologicalProjectionOrder() throws {
        let store = try makeStore()

        let first = makeEvent(
            eventID: "agent-event-recent-first",
            runID: "run-recent-a",
            sequence: 0,
            kind: .runStarted
        )
        let middle = makeEvent(
            eventID: "agent-event-recent-middle",
            runID: "run-recent-b",
            sequence: 1,
            kind: .toolCallCompleted,
            toolName: "vault_search"
        )
        let latest = makeEvent(
            eventID: "agent-event-recent-latest",
            runID: "run-recent-c",
            sequence: 2,
            kind: .runCompleted
        )

        #expect(store.saveAgentEvent(latest))
        #expect(store.saveAgentEvent(first))
        #expect(store.saveAgentEvent(middle))

        let rows = store.recentAgentEvents(limit: 2)
        #expect(rows.map(\.eventID) == [middle.eventID, latest.eventID])
        #expect(store.recentAgentEvents(limit: 0).isEmpty)
    }
}
