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

    @Test("Agent run timeline replays RunEventLog rows in sequence order")
    func agentRunTimelineReplaysRunEventLogRowsInSequenceOrder() {
        let runID = "run-timeline"
        let toolDone = makeEvent(
            eventID: "event-tool-done",
            runID: runID,
            sequence: 2,
            kind: .toolCallCompleted,
            toolName: "vault_search"
        )
        let started = makeEvent(
            eventID: "event-started",
            runID: runID,
            sequence: 0,
            kind: .runStarted
        )
        let approval = makeEvent(
            eventID: "event-approval",
            runID: runID,
            sequence: 1,
            kind: .toolCallRequested,
            toolName: "vault_search"
        )

        let items = AgentRunTimelineItem.replayItems(from: [toolDone, started, approval])

        #expect(items.map(\.id) == ["event-started", "event-approval", "event-tool-done"])
        #expect(items.map(\.title) == ["Plan", "Approve", "Search done"])
        #expect(items[2].detail.contains("vault_search"))
    }

    @Test("Agent run timeline surfaces MissionPacket replay metadata")
    func agentRunTimelineSurfacesMissionPacketReplayMetadata() {
        let started = AgentProvenanceEvent(
            eventID: "event-mission-started",
            runID: "run-mission",
            traceID: nil,
            sequence: 0,
            kind: .runStarted,
            actor: .agent(id: "agent", modelID: "qwen-local"),
            occurredAtMs: 1_000,
            metadata: [
                "mission_packet_id": "mission-123",
                "agent_blueprint_model": "auto_constellation",
                "agent_blueprint_scope": "current_vault",
                "agent_blueprint_approval_mode": "approve_once_per_session"
            ]
        )

        let items = AgentRunTimelineItem.replayItems(from: [started])

        #expect(items.first?.title == "Plan")
        #expect(items.first?.detail.contains("mission=mission-123") == true)
        #expect(items.first?.detail.contains("model=auto_constellation") == true)
        #expect(items.first?.detail.contains("scope=current_vault") == true)
        #expect(items.first?.detail.contains("approval=approve_once_per_session") == true)
    }

    @MainActor
    @Test("RunEventLog records AnswerPacket metadata in replay order")
    func runEventLogRecordsAnswerPacketMetadataInReplayOrder() {
        var saved: [AgentProvenanceEvent] = []
        var now: Int64 = 1_000
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: {
                defer { now += 1 }
                return now
            },
            persist: { event in
                saved.append(event)
                return true
            }
        )
        let runID = "run-answer-packet"
        let actor = AgentProvenanceActor.agent(id: "agent", modelID: "qwen-local")

        #expect(recorder.recordRunEvent(
            runID: runID,
            traceID: nil,
            kind: .runStarted,
            actor: actor,
            metadata: ["source": "test"]
        ))
        #expect(recorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: .toolCallCompleted,
            actor: actor,
            toolCallID: "tool-1",
            toolName: "vault_search",
            argumentsJSON: #"{"query":"packet"}"#,
            resultJSON: #"{"ok":true}"#,
            durationMs: 17,
            approvalID: nil,
            status: .completed,
            metadata: ["source": "test"]
        ))
        #expect(recorder.recordRunEvent(
            runID: runID,
            traceID: nil,
            kind: .runCompleted,
            actor: actor,
            metadata: [
                "source": "test",
                "answer_packet_id": "packet-123",
                "answer_packet_ui_label": "verified",
                "answer_packet_attention_mode": "dynamic",
                "answer_packet_interrupt_bucket": "low"
            ]
        ))

        #expect(saved.map(\.sequence) == [0, 1, 2])
        #expect(saved.last?.metadata["answer_packet_id"] == "packet-123")

        let items = AgentRunTimelineItem.replayItems(from: saved.reversed())
        #expect(items.map(\.title) == ["Plan", "Search done", "Output"])
        #expect(items.last?.detail.contains("packet=packet-123") == true)
        #expect(items.last?.detail.contains("label=verified") == true)
        #expect(items.last?.detail.contains("bucket=low") == true)
    }

    @Test("Provenance Console projects AnswerPacket metadata from AgentEvent rows")
    func provenanceConsoleProjectsAnswerPacketMetadataFromAgentEventRows() throws {
        let store = try makeStore()
        let completed = AgentProvenanceEvent(
            eventID: "agent-event-provenance-packet",
            runID: "run-provenance-packet",
            traceID: "trace-provenance-packet",
            sequence: 7,
            kind: .runCompleted,
            actor: .agent(id: "agent-provenance", modelID: "qwen-local"),
            occurredAtMs: 7_000,
            tool: nil,
            metadata: [
                "answer_packet_id": "packet-provenance-123",
                "answer_packet_ui_label": "verified",
                "answer_packet_attention_mode": "dynamic",
                "answer_packet_interrupt_bucket": "low"
            ]
        )

        #expect(store.saveAgentEvent(completed))

        let snapshot = ProvenanceConsoleProjectionService(
            eventStoreProvider: { store }
        ).snapshot(limit: 5)

        guard case .provenanceChain(let events) = snapshot.agentPayload.body else {
            Issue.record("AgentEvent payload must render as provenanceTrace")
            return
        }
        let row = try #require(events.first)
        guard case .keyValues(let pairs) = row.body else {
            Issue.record("AgentEvent provenance row must render as keyValueTable")
            return
        }
        let values = Dictionary(uniqueKeysWithValues: pairs.map { ($0.key, $0.value) })

        #expect(values["answer packet"] == "packet-provenance-123")
        #expect(values["VRM label"] == "verified")
        #expect(values["attention mode"] == "dynamic")
        #expect(values["interrupt bucket"] == "low")
    }

    @Test("Provenance Console projects MissionPacket metadata from AgentEvent rows")
    func provenanceConsoleProjectsMissionPacketMetadataFromAgentEventRows() throws {
        let store = try makeStore()
        let started = AgentProvenanceEvent(
            eventID: "agent-event-provenance-mission",
            runID: "run-provenance-mission",
            traceID: "trace-provenance-mission",
            sequence: 1,
            kind: .runStarted,
            actor: .agent(id: "agent-provenance", modelID: "qwen-local"),
            occurredAtMs: 1_000,
            tool: nil,
            metadata: [
                "mission_packet_id": "mission-provenance-123",
                "agent_blueprint_name": "Research Assistant",
                "agent_blueprint_model": "auto_constellation",
                "agent_blueprint_scope": "current_vault",
                "agent_blueprint_approval_mode": "approve_once_per_session",
                "agent_blueprint_tools": "vault_search,local_summarize"
            ]
        )

        #expect(store.saveAgentEvent(started))

        let snapshot = ProvenanceConsoleProjectionService(
            eventStoreProvider: { store }
        ).snapshot(limit: 5)

        guard case .provenanceChain(let events) = snapshot.agentPayload.body else {
            Issue.record("AgentEvent payload must render as provenanceTrace")
            return
        }
        let row = try #require(events.first)
        guard case .keyValues(let pairs) = row.body else {
            Issue.record("AgentEvent provenance row must render as keyValueTable")
            return
        }
        let values = Dictionary(uniqueKeysWithValues: pairs.map { ($0.key, $0.value) })

        #expect(values["mission packet"] == "mission-provenance-123")
        #expect(values["blueprint"] == "Research Assistant")
        #expect(values["blueprint model"] == "auto_constellation")
        #expect(values["blueprint scope"] == "current_vault")
        #expect(values["approval mode"] == "approve_once_per_session")
        #expect(values["blueprint tools"] == "vault_search,local_summarize")
    }
}
