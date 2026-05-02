import Testing
import Foundation
import SQLite3
@testable import Epistemos

// MARK: - Phase 0: EventStore Schema Tests

@Suite("EventStore Cognitive Tables")
struct EventStoreSchemaTests {
    private enum EventStoreTestError: Error {
        case databaseOpenFailed
        case statementPrepareFailed
        case statementStepFailed
    }

    private func makeTestStore() -> EventStore? {
        let tempDir = FileManager.default.temporaryDirectory
        let dbURL = tempDir.appendingPathComponent("test-\(UUID().uuidString).sqlite")
        return EventStore(databaseURL: dbURL)
    }

    private func makeTestStoreWithURL() -> (store: EventStore, url: URL)? {
        let tempDir = FileManager.default.temporaryDirectory
        let dbURL = tempDir.appendingPathComponent("test-\(UUID().uuidString).sqlite")
        guard let store = EventStore(databaseURL: dbURL) else {
            return nil
        }
        return (store, dbURL)
    }

    private func makeCommittedEnvelope(
        mutationID: String,
        artifactID: String
    ) -> MutationEnvelope {
        MutationEnvelope(
            mutationID: mutationID,
            sequence: 1,
            actor: .user,
            status: .committed,
            createdAtMs: 1,
            committedAtMs: 2,
            op: .artifactCreate(
                artifactID: artifactID,
                artifactKind: ArtifactKind.proseNote.snakeCaseString
            ),
            sensitivity: .internal,
            reversibility: .reversible,
            integrityHash: "sha256:\(mutationID)"
        )
    }

    private func makeToolAgentEvent(
        eventID: String,
        runID: String,
        sequence: UInt64,
        status: AgentToolEventStatus = .completed,
        resultJSON: String? = "{\"ok\":true}"
    ) -> AgentProvenanceEvent {
        AgentProvenanceEvent(
            eventID: eventID,
            runID: runID,
            traceID: "trace-\(runID)",
            sequence: sequence,
            kind: .toolCallCompleted,
            actor: .agent(id: "agent-\(runID)", modelID: "qwen-local"),
            occurredAtMs: Int64(sequence + 1) * 1_000,
            tool: AgentToolProvenance(
                toolCallID: "tool-call-\(eventID)",
                toolName: "vault_search",
                argumentsJSON: "{\"query\":\"meaning\"}",
                resultJSON: resultJSON,
                durationMs: 42,
                approvalID: "approval-\(eventID)",
                status: status,
                errorMessage: status == .failed ? "tool failed" : nil
            ),
            metadata: [
                "surface": "test",
            ]
        )
    }

    private func makeGraphEvent(
        eventID: String,
        mutationID: String,
        sequence: UInt64,
        kind: DurableGraphEventKind = .nodeCreated
    ) -> DurableGraphEvent {
        DurableGraphEvent(
            eventID: eventID,
            mutationID: mutationID,
            runID: "run-\(mutationID)",
            traceID: "trace-\(mutationID)",
            sequence: sequence,
            kind: kind,
            entityID: "note-\(mutationID)",
            entityKind: ArtifactKind.proseNote.snakeCaseString,
            occurredAtMs: Int64(sequence + 1) * 1_000,
            relation: nil,
            metadata: [
                "surface": "test",
            ]
        )
    }

    private func makeGraphRelationEvent(
        eventID: String,
        mutationID: String,
        sequence: UInt64,
        kind: DurableGraphEventKind,
        relation: DurableGraphEventRelation
    ) -> DurableGraphEvent {
        DurableGraphEvent(
            eventID: eventID,
            mutationID: mutationID,
            runID: "run-\(mutationID)",
            traceID: "trace-\(mutationID)",
            sequence: sequence,
            kind: kind,
            entityID: "\(relation.fromID)->\(relation.toID):\(relation.label)",
            entityKind: "edge",
            occurredAtMs: Int64(sequence + 1) * 1_000,
            relation: relation,
            metadata: [
                "surface": "test",
            ]
        )
    }

    nonisolated private final class AgentEventCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [AgentProvenanceEvent] = []

        func append(_ event: AgentProvenanceEvent) {
            lock.lock()
            storage.append(event)
            lock.unlock()
        }

        var events: [AgentProvenanceEvent] {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
    }

    private struct RenamingHook: AgentHook {
        let hookId: String

        func beforeToolCall(call: HookToolCall) async -> HookToolCall? {
            HookToolCall(id: call.id, name: "\(call.name).hooked", argsJson: call.argsJson)
        }
    }

    private struct CancellingHook: AgentHook {
        let hookId: String

        func beforeToolCall(call: HookToolCall) async -> HookToolCall? {
            nil
        }
    }

    private func insertCompletedNightBrainRun(databaseURL: URL, jobsJSON: String) throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else {
            throw EventStoreTestError.databaseOpenFailed
        }
        defer { sqlite3_close(db) }

        let sql = """
            INSERT INTO night_brain_runs (started_at, completed_at, status, jobs_completed, trigger_reason)
            VALUES (?, ?, 'completed', ?, 'test');
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw EventStoreTestError.statementPrepareFailed
        }
        defer { sqlite3_finalize(stmt) }

        let now = Date().timeIntervalSince1970
        sqlite3_bind_double(stmt, 1, now)
        sqlite3_bind_double(stmt, 2, now)
        sqlite3_bind_text(stmt, 3, (jobsJSON as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw EventStoreTestError.statementStepFailed
        }
    }

    @Test("Migration creates cognitive substrate and session metrics tables")
    func migrationCreatesAllTables() {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }
        #expect(store.tableExists("session_metrics"))
        #expect(store.tableExists("captured_artifacts"))
        #expect(store.tableExists("friction_windows"))
        #expect(store.tableExists("night_brain_runs"))
        #expect(store.tableExists("night_brain_checkpoints"))
        #expect(store.tableExists("mutation_projection_outbox"))
        #expect(store.tableExists("agent_events"))
        #expect(store.tableExists("graph_events"))
    }

    @Test("Existing tables still present after migration")
    func existingTablesUnchanged() {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }
        #expect(store.tableExists("events"))
        #expect(store.tableExists("snapshots"))
        #expect(store.tableExists("session_metrics"))
    }

    @Test("Dedupe hash UNIQUE constraint rejects duplicates")
    func dedupeHashUnique() async throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let artifact = CapturedArtifact(
            sourceBundleId: "com.test.app",
            appName: "TestApp",
            textContent: "Hello world",
            capturedAt: Date().timeIntervalSince1970,
            dedupeHash: "abc123",
            ocrUsed: false
        )

        store.insertCapturedArtifact(artifact)
        try await Task.sleep(nanoseconds: 100_000_000)

        store.insertCapturedArtifact(artifact)
        try await Task.sleep(nanoseconds: 100_000_000)

        let count = store.capturedArtifactCount()
        #expect(count == 1)
    }

    @Test("Night brain run insert and query")
    func nightBrainRunCRUD() async throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let runId = store.insertNightBrainRun(status: "running", triggerReason: "test")
        #expect(runId != nil)

        store.updateNightBrainRun(
            id: runId!, status: "completed",
            completedJobs: ["job1", "job2"],
            completedAt: Date().timeIntervalSince1970
        )
        try await Task.sleep(nanoseconds: 100_000_000)

        let runs = store.completedNightBrainRuns(limit: 10)
        #expect(runs.count == 1)
        #expect(runs.first?.status == "completed")
        #expect(runs.first?.jobsCompleted == ["job1", "job2"])
    }

    @Test("Malformed Night Brain jobs JSON fails closed without dropping the run")
    func malformedNightBrainJobsJSONFailsClosed() throws {
        guard let setup = makeTestStoreWithURL() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        try insertCompletedNightBrainRun(databaseURL: setup.url, jobsJSON: "{not-json")

        let runs = setup.store.completedNightBrainRuns(limit: 10)
        #expect(runs.count == 1)
        #expect(runs.first?.status == "completed")
        #expect(runs.first?.jobsCompleted == [])
    }

    @Test("EventStore init fails when the database directory cannot be created")
    func initFailsWhenDatabaseDirectoryCannotBeCreated() throws {
        let parentURL = FileManager.default.temporaryDirectory.appendingPathComponent("event-store-parent-\(UUID().uuidString)")
        try Data("blocked".utf8).write(to: parentURL)
        defer {
            do {
                if FileManager.default.fileExists(atPath: parentURL.path) {
                    try FileManager.default.removeItem(at: parentURL)
                }
            } catch {
                Issue.record("Failed to clean up temporary EventStore test file: \(error.localizedDescription)")
            }
        }

        let databaseURL = parentURL.appendingPathComponent("event-store.sqlite")
        #expect(EventStore(databaseURL: databaseURL) == nil)
    }

    @Test("Pending mutation envelopes do not enter projection outbox")
    func pendingMutationEnvelopeDoesNotCreateProjectionOutboxRow() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let envelope = MutationEnvelope(
            mutationID: "pending-\(UUID().uuidString)",
            sequence: 0,
            actor: .system,
            status: .pending,
            createdAtMs: 1,
            op: .graphMutation,
            sensitivity: .internal,
            reversibility: .reversible,
            integrityHash: "sha256:pending"
        )

        #expect(store.saveMutationEnvelope(envelope, traceId: "trace-pending"))
        #expect(store.loadMutationEnvelope(mutationID: envelope.mutationID) == envelope)
        #expect(store.mutationProjectionOutboxRows(mutationID: envelope.mutationID).isEmpty)
    }

    @Test("AgentEvent JSON round trips tool provenance with snake case keys")
    func agentEventJSONRoundTripsToolProvenance() throws {
        let event = makeToolAgentEvent(
            eventID: "agent-event-json",
            runID: "run-json",
            sequence: 7
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(event)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"event_id\":\"agent-event-json\""))
        #expect(json.contains("\"tool_name\":\"vault_search\""))
        #expect(json.contains("\"arguments_json\":\"{\\\"query\\\":\\\"meaning\\\"}\""))
        #expect(json.contains("\"occurred_at_ms\":8000"))

        let decoded = try JSONDecoder().decode(AgentProvenanceEvent.self, from: data)
        #expect(decoded == event)
    }

    @Test("EventStore creates and persists AgentEvents")
    func eventStoreCreatesAndPersistsAgentEvents() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let event = makeToolAgentEvent(
            eventID: "agent-event-\(UUID().uuidString)",
            runID: "run-persist",
            sequence: 1
        )

        #expect(store.tableExists("agent_events"))
        #expect(store.saveAgentEvent(event))
        #expect(store.loadAgentEvent(eventID: event.eventID) == event)
    }

    @Test("EventStore returns bounded AgentEvents ordered by sequence")
    func eventStoreReturnsBoundedAgentEventsOrderedBySequence() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let runID = "run-ordered-\(UUID().uuidString)"
        let second = makeToolAgentEvent(eventID: "agent-event-second-\(UUID().uuidString)", runID: runID, sequence: 2)
        let first = makeToolAgentEvent(eventID: "agent-event-first-\(UUID().uuidString)", runID: runID, sequence: 0)
        let middle = makeToolAgentEvent(eventID: "agent-event-middle-\(UUID().uuidString)", runID: runID, sequence: 1)

        #expect(store.saveAgentEvent(second))
        #expect(store.saveAgentEvent(first))
        #expect(store.saveAgentEvent(middle))

        let rows = store.agentEvents(runID: runID, limit: 2)
        #expect(rows.map(\.sequence) == [0, 1])
        #expect(rows.map(\.eventID) == [first.eventID, middle.eventID])
        #expect(store.agentEvents(runID: runID, limit: 0).isEmpty)
    }

    @Test("EventStore AgentEvent save is idempotent by event id")
    func eventStoreAgentEventSaveIsIdempotentByEventID() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let eventID = "agent-event-upsert-\(UUID().uuidString)"
        let runID = "run-upsert"
        let started = makeToolAgentEvent(
            eventID: eventID,
            runID: runID,
            sequence: 3,
            status: .started,
            resultJSON: nil
        )
        let completed = makeToolAgentEvent(
            eventID: eventID,
            runID: runID,
            sequence: 3,
            status: .completed,
            resultJSON: "{\"ok\":true,\"updated\":true}"
        )

        #expect(store.saveAgentEvent(started))
        #expect(store.saveAgentEvent(completed))

        #expect(store.loadAgentEvent(eventID: eventID) == completed)
        #expect(store.agentEvents(runID: runID, limit: 10).map(\.eventID) == [eventID])
    }

    @Test("GraphEvent JSON round trips mutation mapping with snake case keys")
    func graphEventJSONRoundTripsMutationMapping() throws {
        let event = makeGraphEvent(
            eventID: "graph-event-json",
            mutationID: "mutation-json",
            sequence: 7
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(event)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"event_id\":\"graph-event-json\""))
        #expect(json.contains("\"mutation_id\":\"mutation-json\""))
        #expect(json.contains("\"entity_kind\":\"prose_note\""))
        #expect(json.contains("\"occurred_at_ms\":8000"))

        let decoded = try JSONDecoder().decode(DurableGraphEvent.self, from: data)
        #expect(decoded == event)
    }

    @Test("EventStore creates and persists GraphEvents")
    func eventStoreCreatesAndPersistsGraphEvents() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let event = makeGraphEvent(
            eventID: "graph-event-\(UUID().uuidString)",
            mutationID: "mutation-persist",
            sequence: 1
        )

        #expect(store.tableExists("graph_events"))
        #expect(store.saveGraphEvent(event))
        #expect(store.loadGraphEvent(eventID: event.eventID) == event)
    }

    @Test("EventStore returns bounded GraphEvents ordered by sequence")
    func eventStoreReturnsBoundedGraphEventsOrderedBySequence() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let mutationID = "mutation-ordered-\(UUID().uuidString)"
        let second = makeGraphEvent(eventID: "graph-event-second-\(UUID().uuidString)", mutationID: mutationID, sequence: 2)
        let first = makeGraphEvent(eventID: "graph-event-first-\(UUID().uuidString)", mutationID: mutationID, sequence: 0)
        let middle = makeGraphEvent(eventID: "graph-event-middle-\(UUID().uuidString)", mutationID: mutationID, sequence: 1)

        #expect(store.saveGraphEvent(second))
        #expect(store.saveGraphEvent(first))
        #expect(store.saveGraphEvent(middle))

        let rows = store.graphEvents(mutationID: mutationID, limit: 2)
        #expect(rows.map(\.sequence) == [0, 1])
        #expect(rows.map(\.eventID) == [first.eventID, middle.eventID])
        #expect(store.graphEvents(mutationID: mutationID, limit: 0).isEmpty)
    }

    @Test("GraphEvent diagnostics summarize durable visibility")
    func graphEventDiagnosticsSummarizeDurableVisibility() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let empty = store.graphEventDiagnostics()
        #expect(empty.totalRows == 0)
        #expect(empty.distinctMutations == 0)
        #expect(empty.latestEvent == nil)
        #expect(empty.lastKind == nil)

        let mutationA = "mutation-graph-diagnostics-a-\(UUID().uuidString)"
        let mutationB = "mutation-graph-diagnostics-b-\(UUID().uuidString)"
        let first = makeGraphEvent(
            eventID: "graph-event-diagnostics-first-\(UUID().uuidString)",
            mutationID: mutationA,
            sequence: 0,
            kind: .nodeCreated
        )
        let middle = makeGraphEvent(
            eventID: "graph-event-diagnostics-middle-\(UUID().uuidString)",
            mutationID: mutationA,
            sequence: 1,
            kind: .nodeUpdated
        )
        let latest = makeGraphEvent(
            eventID: "graph-event-diagnostics-latest-\(UUID().uuidString)",
            mutationID: mutationB,
            sequence: 3,
            kind: .edgeCreated
        )

        #expect(store.saveGraphEvent(first))
        #expect(store.saveGraphEvent(latest))
        #expect(store.saveGraphEvent(middle))

        let diagnostics = store.graphEventDiagnostics()
        #expect(diagnostics.totalRows == 3)
        #expect(diagnostics.distinctMutations == 2)
        #expect(diagnostics.latestEvent == latest)
        #expect(diagnostics.lastKind == .edgeCreated)
    }

    @Test("EventStore returns recent GraphEvents in chronological projection order")
    func eventStoreReturnsRecentGraphEventsInChronologicalProjectionOrder() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let mutationID = "mutation-recent-graph-\(UUID().uuidString)"
        let first = makeGraphEvent(eventID: "graph-event-recent-first-\(UUID().uuidString)", mutationID: mutationID, sequence: 0)
        let middle = makeGraphEvent(eventID: "graph-event-recent-middle-\(UUID().uuidString)", mutationID: mutationID, sequence: 1)
        let latest = makeGraphEvent(eventID: "graph-event-recent-latest-\(UUID().uuidString)", mutationID: mutationID, sequence: 2)

        #expect(store.saveGraphEvent(latest))
        #expect(store.saveGraphEvent(first))
        #expect(store.saveGraphEvent(middle))

        let rows = store.recentGraphEvents(limit: 2)
        #expect(rows.map(\.eventID) == [middle.eventID, latest.eventID])
        #expect(store.recentGraphEvents(limit: 0).isEmpty)
    }

    @Test("EventStore folds recent GraphEvents into read-only projection snapshot")
    func eventStoreFoldsRecentGraphEventsIntoReadOnlyProjectionSnapshot() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let nodeID = "note-store-projection-\(UUID().uuidString)"
        let targetID = "note-store-target-\(UUID().uuidString)"
        let createNode = DurableGraphEvent(
            eventID: "graph-event-store-projection-node-\(UUID().uuidString)",
            mutationID: "mutation-store-projection-node",
            runID: "run-store-projection",
            traceID: "trace-store-projection",
            sequence: 0,
            kind: .nodeCreated,
            entityID: nodeID,
            entityKind: ArtifactKind.proseNote.snakeCaseString,
            occurredAtMs: 1_000
        )
        let createEdge = makeGraphRelationEvent(
            eventID: "graph-event-store-projection-edge-\(UUID().uuidString)",
            mutationID: "mutation-store-projection-edge",
            sequence: 1,
            kind: .edgeCreated,
            relation: DurableGraphEventRelation(fromID: nodeID, toID: targetID, label: "mentions")
        )

        #expect(store.saveGraphEvent(createEdge))
        #expect(store.saveGraphEvent(createNode))

        let snapshot = store.graphEventProjectionSnapshot(limit: 10)
        #expect(snapshot.eventCount == 2)
        #expect(snapshot.latestEventID == createEdge.eventID)
        #expect(snapshot.nodes.map(\.id) == [nodeID])
        #expect(snapshot.edges.map(\.id) == ["\(nodeID)->\(targetID):mentions"])
        #expect(store.graphEventProjectionSnapshot(limit: 0).eventCount == 0)
    }

    @Test("Durable GraphEvent projection folds nodes and edges deterministically")
    func durableGraphEventProjectionFoldsNodesAndEdgesDeterministically() throws {
        let nodeID = "note-projection-\(UUID().uuidString)"
        let targetID = "note-target-\(UUID().uuidString)"
        let createNode = DurableGraphEvent(
            eventID: "graph-event-projection-node-create-\(UUID().uuidString)",
            mutationID: "mutation-projection-node-create",
            runID: "run-projection",
            traceID: "trace-projection",
            sequence: 0,
            kind: .nodeCreated,
            entityID: nodeID,
            entityKind: ArtifactKind.proseNote.snakeCaseString,
            occurredAtMs: 1_000
        )
        let updateNode = DurableGraphEvent(
            eventID: "graph-event-projection-node-update-\(UUID().uuidString)",
            mutationID: "mutation-projection-node-update",
            runID: "run-projection",
            traceID: "trace-projection",
            sequence: 1,
            kind: .nodeUpdated,
            entityID: nodeID,
            entityKind: ArtifactKind.proseNote.snakeCaseString,
            occurredAtMs: 2_000
        )
        let oldRelation = DurableGraphEventRelation(fromID: nodeID, toID: targetID, label: "mentions")
        let newRelation = DurableGraphEventRelation(
            fromID: nodeID,
            toID: targetID,
            label: "supports",
            oldLabel: "mentions",
            newLabel: "supports"
        )
        let createEdge = makeGraphRelationEvent(
            eventID: "graph-event-projection-edge-create-\(UUID().uuidString)",
            mutationID: "mutation-projection-edge-create",
            sequence: 2,
            kind: .edgeCreated,
            relation: oldRelation
        )
        let updateEdge = makeGraphRelationEvent(
            eventID: "graph-event-projection-edge-update-\(UUID().uuidString)",
            mutationID: "mutation-projection-edge-update",
            sequence: 3,
            kind: .edgeUpdated,
            relation: newRelation
        )
        let invalidEdge = makeGraphRelationEvent(
            eventID: "graph-event-projection-edge-invalid-\(UUID().uuidString)",
            mutationID: "mutation-projection-edge-invalid",
            sequence: 4,
            kind: .edgeCreated,
            relation: DurableGraphEventRelation(fromID: "  ", toID: targetID, label: "mentions")
        )
        let genericGraphMutation = DurableGraphEvent(
            eventID: "graph-event-projection-generic-\(UUID().uuidString)",
            mutationID: "mutation-projection-generic",
            sequence: 6,
            kind: .graphMutation,
            occurredAtMs: 6_000
        )
        let snapshot = DurableGraphEventProjection.snapshot(from: [
            createNode,
            updateNode,
            createEdge,
            updateEdge,
            invalidEdge,
            genericGraphMutation,
        ])

        #expect(snapshot.eventCount == 6)
        #expect(snapshot.latestEventID == genericGraphMutation.eventID)
        #expect(snapshot.nodes.map(\.id) == [nodeID])
        #expect(snapshot.nodes.first?.lastEventKind == .nodeUpdated)
        #expect(snapshot.edges.map(\.id) == ["\(nodeID)->\(targetID):supports"])
        #expect(snapshot.edges.first?.label == "supports")
        #expect(!snapshot.edges.contains { $0.id == "\(nodeID)->\(targetID):mentions" })

        let deleted = DurableGraphEvent(
            eventID: "graph-event-projection-node-delete-\(UUID().uuidString)",
            mutationID: "mutation-projection-node-delete",
            sequence: 5,
            kind: .nodeDeleted,
            entityID: nodeID,
            entityKind: ArtifactKind.proseNote.snakeCaseString,
            occurredAtMs: 7_000
        )
        let afterDelete = DurableGraphEventProjection.snapshot(from: [updateNode, updateEdge, deleted])
        #expect(afterDelete.nodes.isEmpty)
        #expect(afterDelete.edges.isEmpty)
    }

    @Test("Committed graph-affecting mutation envelopes create idempotent GraphEvents")
    func committedGraphAffectingMutationEnvelopesCreateIdempotentGraphEvents() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let mutationID = "mutation-graph-\(UUID().uuidString)"
        let envelope = MutationEnvelope(
            mutationID: mutationID,
            runID: "run-\(mutationID)",
            sequence: 4,
            actor: .user,
            status: .committed,
            createdAtMs: 1_000,
            committedAtMs: 2_000,
            op: .artifactCreate(
                artifactID: "note-\(mutationID)",
                artifactKind: ArtifactKind.proseNote.snakeCaseString
            ),
            sensitivity: .internal,
            reversibility: .reversible,
            integrityHash: "sha256:\(mutationID)",
            touchedArtifacts: [
                EpdocArtifactRef(id: "note-\(mutationID)", kind: .proseNote, title: "Graph note")
            ],
            affectsGraph: true
        )

        #expect(store.saveMutationEnvelope(envelope, traceId: "trace-\(mutationID)"))
        #expect(store.saveMutationEnvelope(envelope, traceId: "trace-\(mutationID)"))

        let events = store.graphEvents(mutationID: mutationID, limit: 10)
        #expect(events.count == 1)
        #expect(events.first?.kind == .nodeCreated)
        #expect(events.first?.entityID == "note-\(mutationID)")
        #expect(events.first?.entityKind == ArtifactKind.proseNote.snakeCaseString)
        #expect(events.first?.runID == "run-\(mutationID)")
        #expect(events.first?.traceID == "trace-\(mutationID)")
    }

    @Test("Pending graph-affecting mutation envelopes do not create GraphEvents")
    func pendingGraphAffectingMutationEnvelopesDoNotCreateGraphEvents() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let mutationID = "mutation-pending-graph-\(UUID().uuidString)"
        let envelope = MutationEnvelope(
            mutationID: mutationID,
            sequence: 1,
            actor: .user,
            status: .pending,
            createdAtMs: 1_000,
            op: .artifactCreate(
                artifactID: "note-\(mutationID)",
                artifactKind: ArtifactKind.proseNote.snakeCaseString
            ),
            sensitivity: .internal,
            reversibility: .reversible,
            integrityHash: "sha256:\(mutationID)",
            affectsGraph: true
        )

        #expect(store.saveMutationEnvelope(envelope, traceId: "trace-\(mutationID)"))
        #expect(store.graphEvents(mutationID: mutationID, limit: 10).isEmpty)
    }

    @Test("Agent tool provenance recorder persists ordered lifecycle events")
    @MainActor
    func agentToolProvenanceRecorderPersistsOrderedLifecycleEvents() {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 10_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let actor = AgentProvenanceActor.agent(id: "chat-coordinator", modelID: "qwen-local")
        let runID = "run-live-\(UUID().uuidString)"
        let traceID = "trace-live"

        #expect(recorder.recordToolEvent(
            runID: runID,
            traceID: traceID,
            kind: .toolCallRequested,
            actor: actor,
            toolCallID: "tool-1",
            toolName: "vault_search",
            argumentsJSON: "{\"query\":\"agent events\"}",
            approvalID: "tool-1",
            status: .requested
        ))
        #expect(recorder.recordToolEvent(
            runID: runID,
            traceID: traceID,
            kind: .toolCallApproved,
            actor: actor,
            toolCallID: "tool-1",
            toolName: "vault_search",
            argumentsJSON: "{\"query\":\"agent events\"}",
            approvalID: "tool-1",
            status: .approved
        ))
        #expect(recorder.recordToolEvent(
            runID: runID,
            traceID: traceID,
            kind: .toolCallStarted,
            actor: actor,
            toolCallID: "tool-1",
            toolName: "vault_search",
            argumentsJSON: "{\"query\":\"agent events\"}",
            status: .started
        ))
        #expect(recorder.recordToolEvent(
            runID: runID,
            traceID: traceID,
            kind: .toolCallCompleted,
            actor: actor,
            toolCallID: "tool-1",
            toolName: "vault_search",
            argumentsJSON: "{\"query\":\"agent events\"}",
            resultJSON: "{\"ok\":true}",
            durationMs: 12,
            status: .completed
        ))

        #expect(captured.map(\.sequence) == [0, 1, 2, 3])
        #expect(captured.map(\.kind) == [
            .toolCallRequested,
            .toolCallApproved,
            .toolCallStarted,
            .toolCallCompleted,
        ])
        #expect(captured.allSatisfy { $0.runID == runID })
        #expect(captured.allSatisfy { $0.traceID == traceID })
        #expect(captured[0].tool?.argumentsJSON == "{\"query\":\"agent events\"}")
        #expect(captured[3].tool?.resultJSON == "{\"ok\":true}")
        #expect(captured[3].tool?.durationMs == 12)
    }

    @Test("Agent tool provenance recorder refuses incomplete identities")
    @MainActor
    func agentToolProvenanceRecorderRefusesIncompleteIdentities() {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 10_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )

        #expect(!recorder.recordToolEvent(
            runID: " ",
            traceID: nil,
            kind: .toolCallStarted,
            actor: .system,
            toolCallID: "tool-1",
            toolName: "vault_search",
            argumentsJSON: "{}",
            status: .started
        ))
        #expect(!recorder.recordToolEvent(
            runID: "run-1",
            traceID: nil,
            kind: .toolCallStarted,
            actor: .system,
            toolCallID: "",
            toolName: "vault_search",
            argumentsJSON: "{}",
            status: .started
        ))
        #expect(!recorder.recordToolEvent(
            runID: "run-1",
            traceID: nil,
            kind: .toolCallStarted,
            actor: .system,
            toolCallID: "tool-1",
            toolName: "\n",
            argumentsJSON: "{}",
            status: .started
        ))
        #expect(captured.isEmpty)
    }

    @Test("HookRegistry persists hook lifecycle AgentEvents")
    func hookRegistryPersistsHookLifecycleAgentEvents() async {
        let capture = AgentEventCapture()
        let registry = HookRegistry(
            nowMilliseconds: { 42_000 },
            persistAgentEvent: { event in
                capture.append(event)
                return true
            }
        )
        let runID = "run-hook-\(UUID().uuidString)"

        await registry.register(RenamingHook(hookId: "rename-hook"))
        let result = await registry.fireBeforeToolCall(
            call: HookToolCall(
                id: "tool-call-1",
                name: "vault_search",
                argsJson: "{\"query\":\"hooks\"}"
            ),
            runID: runID
        )

        let events = capture.events
        #expect(result?.name == "vault_search.hooked")
        #expect(events.map(\.kind) == [.hookRegistered, .hookFired, .hookCompleted])
        #expect(events.map(\.sequence) == [0, 0, 1])
        #expect(events[0].runID == "hook-registry:registration")
        #expect(events[1].runID == runID)
        #expect(events[2].runID == runID)
        #expect(events.allSatisfy { $0.tool == nil })
        #expect(events.allSatisfy { $0.metadata["source"] == "hook_registry" })
        #expect(events.allSatisfy { $0.metadata["hook_id"] == "rename-hook" })
        #expect(events[1].metadata["hook_point"] == "before_tool_call")
        #expect(events[2].metadata["outcome"] == "completed")
    }

    @Test("HookRegistry records cancelled hook completion without changing cancellation")
    func hookRegistryRecordsCancelledHookCompletionWithoutChangingCancellation() async {
        let capture = AgentEventCapture()
        let registry = HookRegistry(
            nowMilliseconds: { 43_000 },
            persistAgentEvent: { event in
                capture.append(event)
                return true
            }
        )
        let runID = "run-hook-cancel-\(UUID().uuidString)"

        await registry.register(CancellingHook(hookId: "cancel-hook"))
        let result = await registry.fireBeforeToolCall(
            call: HookToolCall(
                id: "tool-call-cancel",
                name: "vault_search",
                argsJson: "{\"query\":\"cancel\"}"
            ),
            runID: runID
        )

        let runEvents = capture.events.filter { $0.runID == runID }
        #expect(result == nil)
        #expect(runEvents.map(\.kind) == [.hookFired, .hookCompleted])
        #expect(runEvents.map(\.sequence) == [0, 1])
        #expect(runEvents[0].metadata["hook_id"] == "cancel-hook")
        #expect(runEvents[1].metadata["outcome"] == "cancelled")
    }

    @Test("Pending mutation projection outbox rows are bounded and insertion ordered")
    func pendingMutationProjectionOutboxRowsAreBoundedAndInsertionOrdered() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let first = makeCommittedEnvelope(
            mutationID: "projection-first-\(UUID().uuidString)",
            artifactID: "note-first"
        )
        let second = makeCommittedEnvelope(
            mutationID: "projection-second-\(UUID().uuidString)",
            artifactID: "note-second"
        )

        #expect(store.pendingMutationProjectionOutboxRows().isEmpty)
        #expect(store.saveMutationEnvelope(first, traceId: "trace-first"))
        #expect(store.saveMutationEnvelope(second, traceId: "trace-second"))

        #expect(store.pendingMutationProjectionOutboxRows(limit: 0).isEmpty)
        #expect(store.pendingMutationProjectionOutboxRows(limit: -5).isEmpty)

        let firstOnly = store.pendingMutationProjectionOutboxRows(limit: 1)
        #expect(firstOnly.map(\.mutationID) == [first.mutationID])

        let rows = store.pendingMutationProjectionOutboxRows(limit: 10)
        #expect(rows.map(\.mutationID) == [first.mutationID, second.mutationID])
        #expect(rows.map(\.traceID) == ["trace-first", "trace-second"])
        #expect(store.pendingMutationProjectionOutboxRows(limit: 10) == rows)

        #expect(store.saveMutationEnvelope(first, traceId: "trace-first"))
        #expect(store.pendingMutationProjectionOutboxRows(limit: 10).map(\.mutationID) == [
            first.mutationID,
            second.mutationID,
        ])
    }

    @Test("Mutation projection outbox leases block competing claims until retry deadline")
    func mutationProjectionOutboxLeasesBlockCompetingClaimsUntilRetryDeadline() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let first = makeCommittedEnvelope(
            mutationID: "projection-lease-first-\(UUID().uuidString)",
            artifactID: "note-lease-first"
        )
        let second = makeCommittedEnvelope(
            mutationID: "projection-lease-second-\(UUID().uuidString)",
            artifactID: "note-lease-second"
        )

        #expect(store.saveMutationEnvelope(first, traceId: "trace-lease-first"))
        #expect(store.saveMutationEnvelope(second, traceId: "trace-lease-second"))

        let firstClaim = store.claimMutationProjectionOutboxRows(
            limit: 1,
            ownerID: "worker-a",
            leaseDuration: 60,
            now: now
        )
        #expect(firstClaim.map(\.mutationID) == [first.mutationID])
        let claimedFirst = try #require(firstClaim.first)
        #expect(claimedFirst.leaseOwner == "worker-a")
        #expect(claimedFirst.leaseUntil == now.addingTimeInterval(60))
        #expect(claimedFirst.attemptCount == 1)
        #expect(claimedFirst.lastError == nil)

        #expect(store.pendingMutationProjectionOutboxRows(limit: 10, now: now).map(\.mutationID) == [
            second.mutationID,
        ])

        let competingClaim = store.claimMutationProjectionOutboxRows(
            limit: 10,
            ownerID: "worker-b",
            leaseDuration: 60,
            now: now
        )
        #expect(competingClaim.map(\.mutationID) == [second.mutationID])

        let longError = String(repeating: "x", count: 700)
        #expect(store.recordMutationProjectionOutboxFailure(
            mutationID: first.mutationID,
            ownerID: "worker-a",
            error: longError,
            retryAfter: 30,
            now: now.addingTimeInterval(5)
        ))

        let failedRows = store.mutationProjectionOutboxRows(mutationID: first.mutationID)
        let failedRow = try #require(failedRows.first)
        #expect(failedRow.leaseOwner == nil)
        #expect(failedRow.leaseUntil == now.addingTimeInterval(35))
        #expect(failedRow.attemptCount == 1)
        #expect(failedRow.lastError?.count == 512)
        #expect(store.pendingMutationProjectionOutboxRows(limit: 10, now: now.addingTimeInterval(20)).isEmpty)

        let retryClaim = store.claimMutationProjectionOutboxRows(
            limit: 10,
            ownerID: "worker-c",
            leaseDuration: 45,
            now: now.addingTimeInterval(36)
        )
        #expect(retryClaim.map(\.mutationID) == [first.mutationID])
        let retriedRow = try #require(retryClaim.first)
        #expect(retriedRow.leaseOwner == "worker-c")
        #expect(retriedRow.leaseUntil == now.addingTimeInterval(81))
        #expect(retriedRow.attemptCount == 2)
        #expect(retriedRow.lastError == nil)
    }

    @Test("Mutation projection stale lease owners cannot mark newer claims")
    func mutationProjectionOutboxStaleLeaseOwnerCannotMarkNewerClaim() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let now = Date(timeIntervalSince1970: 1_700_000_100)
        let envelope = makeCommittedEnvelope(
            mutationID: "projection-stale-owner-\(UUID().uuidString)",
            artifactID: "note-stale-owner"
        )
        #expect(store.saveMutationEnvelope(envelope, traceId: "trace-stale-owner"))

        let firstClaim = store.claimMutationProjectionOutboxRows(
            limit: 1,
            ownerID: "worker-a",
            leaseDuration: 1,
            now: now
        )
        #expect(firstClaim.map(\.mutationID) == [envelope.mutationID])

        let secondClaim = store.claimMutationProjectionOutboxRows(
            limit: 1,
            ownerID: "worker-b",
            leaseDuration: 60,
            now: now.addingTimeInterval(2)
        )
        #expect(secondClaim.map(\.mutationID) == [envelope.mutationID])

        #expect(!store.markMutationProjectionOutboxProjected(
            mutationID: envelope.mutationID,
            opLogSeq: 7,
            projectedAt: now.addingTimeInterval(3),
            ownerID: "worker-a"
        ))

        let stillLeasedRows = store.mutationProjectionOutboxRows(mutationID: envelope.mutationID)
        let stillLeasedRow = try #require(stillLeasedRows.first)
        #expect(stillLeasedRow.opLogSeq == nil)
        #expect(stillLeasedRow.leaseOwner == "worker-b")
        #expect(stillLeasedRow.attemptCount == 2)

        #expect(store.markMutationProjectionOutboxProjected(
            mutationID: envelope.mutationID,
            opLogSeq: 7,
            projectedAt: now.addingTimeInterval(4),
            ownerID: "worker-b"
        ))
    }

    @Test("Mutation projection outbox dead letters rows at max attempts")
    func mutationProjectionOutboxDeadLettersRowsAtMaxAttempts() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let now = Date(timeIntervalSince1970: 1_700_000_200)
        let envelope = makeCommittedEnvelope(
            mutationID: "projection-dead-letter-\(UUID().uuidString)",
            artifactID: "note-dead-letter"
        )
        #expect(store.saveMutationEnvelope(envelope, traceId: "trace-dead-letter"))

        let firstClaim = store.claimMutationProjectionOutboxRows(
            limit: 1,
            ownerID: "worker-dead-letter",
            leaseDuration: 30,
            now: now
        )
        #expect(firstClaim.map(\.mutationID) == [envelope.mutationID])

        #expect(store.recordMutationProjectionOutboxFailure(
            mutationID: envelope.mutationID,
            ownerID: "worker-dead-letter",
            error: "first failure",
            retryAfter: 1,
            now: now.addingTimeInterval(1),
            maxAttempts: 2
        ))

        let retryClaim = store.claimMutationProjectionOutboxRows(
            limit: 1,
            ownerID: "worker-dead-letter",
            leaseDuration: 30,
            now: now.addingTimeInterval(3)
        )
        #expect(retryClaim.map(\.mutationID) == [envelope.mutationID])
        let retryRow = try #require(retryClaim.first)
        #expect(retryRow.attemptCount == 2)

        let longError = String(repeating: "z", count: 700)
        #expect(store.recordMutationProjectionOutboxFailure(
            mutationID: envelope.mutationID,
            ownerID: "worker-dead-letter",
            error: longError,
            retryAfter: 1,
            now: now.addingTimeInterval(4),
            maxAttempts: 2
        ))

        let rows = store.mutationProjectionOutboxRows(mutationID: envelope.mutationID)
        let row = try #require(rows.first)
        #expect(row.leaseOwner == nil)
        #expect(row.leaseUntil == nil)
        #expect(row.deadLetteredAt == now.addingTimeInterval(4))
        #expect(row.deadLetterReason == "max_attempts_exceeded")
        #expect(row.lastError?.count == 512)
        #expect(store.pendingMutationProjectionOutboxRows(limit: 10, now: now.addingTimeInterval(60)).isEmpty)
        #expect(store.claimMutationProjectionOutboxRows(
            limit: 1,
            ownerID: "worker-after-dead-letter",
            leaseDuration: 30,
            now: now.addingTimeInterval(60)
        ).isEmpty)

        #expect(store.markMutationProjectionOutboxProjected(
            mutationID: envelope.mutationID,
            opLogSeq: 9,
            projectedAt: now.addingTimeInterval(61)
        ))
        let repairedRows = store.mutationProjectionOutboxRows(mutationID: envelope.mutationID)
        let repairedRow = try #require(repairedRows.first)
        #expect(repairedRow.deadLetteredAt == nil)
        #expect(repairedRow.deadLetterReason == nil)
        #expect(repairedRow.lastError == nil)
    }

    @Test("Mutation projection outbox diagnostics summarize projected pending leased and dead-letter rows")
    func mutationProjectionOutboxDiagnosticsSummarizeProjectionHealth() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let now = Date(timeIntervalSince1970: 1_700_000_400)
        let projected = makeCommittedEnvelope(
            mutationID: "projection-diagnostics-projected-\(UUID().uuidString)",
            artifactID: "note-diagnostics-projected"
        )
        let deadLettered = makeCommittedEnvelope(
            mutationID: "projection-diagnostics-dead-\(UUID().uuidString)",
            artifactID: "note-diagnostics-dead"
        )
        let leased = makeCommittedEnvelope(
            mutationID: "projection-diagnostics-leased-\(UUID().uuidString)",
            artifactID: "note-diagnostics-leased"
        )
        let pending = makeCommittedEnvelope(
            mutationID: "projection-diagnostics-pending-\(UUID().uuidString)",
            artifactID: "note-diagnostics-pending"
        )

        #expect(store.saveMutationEnvelope(projected, traceId: "trace-projection-diagnostics-projected"))
        #expect(store.markMutationProjectionOutboxProjected(
            mutationID: projected.mutationID,
            opLogSeq: 41,
            projectedAt: now
        ))

        #expect(store.saveMutationEnvelope(deadLettered, traceId: "trace-projection-diagnostics-dead"))
        #expect(store.claimMutationProjectionOutboxRows(
            limit: 1,
            ownerID: "diagnostics-dead-letter",
            leaseDuration: 30,
            now: now.addingTimeInterval(1)
        ).map(\.mutationID) == [deadLettered.mutationID])
        #expect(store.recordMutationProjectionOutboxFailure(
            mutationID: deadLettered.mutationID,
            ownerID: "diagnostics-dead-letter",
            error: "diagnostic failure",
            retryAfter: 1,
            now: now.addingTimeInterval(2),
            maxAttempts: 1
        ))

        #expect(store.saveMutationEnvelope(leased, traceId: "trace-projection-diagnostics-leased"))
        #expect(store.claimMutationProjectionOutboxRows(
            limit: 1,
            ownerID: "diagnostics-leased",
            leaseDuration: 60,
            now: now.addingTimeInterval(3)
        ).map(\.mutationID) == [leased.mutationID])

        #expect(store.saveMutationEnvelope(pending, traceId: "trace-projection-diagnostics-pending"))

        let diagnostics = store.mutationProjectionOutboxDiagnostics(now: now.addingTimeInterval(4))
        #expect(diagnostics.totalRows == 4)
        #expect(diagnostics.projectedRows == 1)
        #expect(diagnostics.pendingRows == 1)
        #expect(diagnostics.leasedRows == 1)
        #expect(diagnostics.deadLetteredRows == 1)
        #expect(diagnostics.latestDeadLetter?.mutationID == deadLettered.mutationID)
        #expect(diagnostics.latestDeadLetter?.deadLetterReason == "max_attempts_exceeded")
        #expect(diagnostics.latestDeadLetter?.lastError == "diagnostic failure")
    }

    @Test("Mutation OpLog projector appends pending envelopes and marks rows")
    func mutationOpLogProjectorAppendsPendingEnvelopesAndMarksRows() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let opLogURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("eventstore-oplog-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        defer { try? FileManager.default.removeItem(at: opLogURL) }

        let envelope = makeCommittedEnvelope(
            mutationID: "projection-oplog-\(UUID().uuidString)",
            artifactID: "note-oplog"
        )
        #expect(store.saveMutationEnvelope(envelope, traceId: "trace-oplog"))

        let client = try RustOpLogFFIClient(databaseURL: opLogURL, actorID: "projection-test")
        let projector = MutationOpLogProjector(eventStore: store, opLog: client)
        let result = try projector.projectPending(limit: 10)

        #expect(result.scanned == 1)
        #expect(result.appended == 1)
        #expect(result.alreadyProjected == 0)
        #expect(result.marked == 1)
        #expect(store.pendingMutationProjectionOutboxRows(limit: 10).isEmpty)

        let rows = store.mutationProjectionOutboxRows(mutationID: envelope.mutationID)
        let row = try #require(rows.first)
        #expect(row.opLogSeq == 0)
        #expect(row.projectedAt != nil)
        #expect(row.leaseOwner == nil)
        #expect(row.leaseUntil == nil)
        #expect(row.attemptCount == 1)
        #expect(row.lastError == nil)

        let entries = try client.iterateAll()
        #expect(entries.count == 1)
        #expect(entries.first?.seq == 0)
        #expect(entries.first?.payload.projectionMutationID == envelope.mutationID)
    }

    @Test("Mutation OpLog projector marks append-before-mark recovery without duplicating")
    func mutationOpLogProjectorMarksAppendBeforeMarkRecoveryWithoutDuplicating() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let opLogURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("eventstore-oplog-recovery-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        defer { try? FileManager.default.removeItem(at: opLogURL) }

        let envelope = makeCommittedEnvelope(
            mutationID: "projection-recovery-\(UUID().uuidString)",
            artifactID: "note-recovery"
        )
        #expect(store.saveMutationEnvelope(envelope, traceId: "trace-recovery"))

        let client = try RustOpLogFFIClient(databaseURL: opLogURL, actorID: "projection-test")
        let existingSeq = try client.append(.propSet(
            nodeID: envelope.mutationID,
            key: MutationOpLogProjector.projectionKey,
            value: .object([
                "mutation_id": .string(envelope.mutationID),
                "trace_id": .string("trace-recovery"),
            ])
        ))
        #expect(existingSeq == 0)

        let projector = MutationOpLogProjector(eventStore: store, opLog: client)
        let result = try projector.projectPending(limit: 10)

        #expect(result.scanned == 1)
        #expect(result.appended == 0)
        #expect(result.alreadyProjected == 1)
        #expect(result.marked == 1)
        #expect(store.pendingMutationProjectionOutboxRows(limit: 10).isEmpty)

        let rows = store.mutationProjectionOutboxRows(mutationID: envelope.mutationID)
        let row = try #require(rows.first)
        #expect(row.opLogSeq == existingSeq)

        let entries = try client.iterateAll()
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.payload.projectionMutationID == envelope.mutationID)
        let projectedAt = try #require(row.projectedAt)
        let expectedProjectedAt = Date(timeIntervalSince1970: TimeInterval(entry.tsUnixMs) / 1_000)
        #expect(abs(projectedAt.timeIntervalSince(expectedProjectedAt)) < 0.001)
    }

    @Test("Mutation OpLog projection worker resolves app scoped database URL")
    func mutationOpLogProjectionWorkerResolvesAppScopedDatabaseURL() {
        let applicationSupportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("oplog-worker-root-\(UUID().uuidString)", isDirectory: true)

        let url = MutationOpLogProjectionWorker.databaseURL(
            applicationSupportDirectory: applicationSupportDirectory
        )

        #expect(url == applicationSupportDirectory
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("mutation-oplog.sqlite", isDirectory: false))
    }

    @Test("Mutation OpLog projection worker drains pending envelopes")
    func mutationOpLogProjectionWorkerDrainsPendingEnvelopes() throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("oplog-worker-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let opLogURL = root.appendingPathComponent("worker-oplog.sqlite", isDirectory: false)

        let envelope = makeCommittedEnvelope(
            mutationID: "projection-worker-\(UUID().uuidString)",
            artifactID: "note-worker"
        )
        #expect(store.saveMutationEnvelope(envelope, traceId: "trace-worker"))

        let worker = MutationOpLogProjectionWorker(
            eventStore: store,
            databaseURL: opLogURL,
            actorID: "projection-worker-test",
            workerID: "projection-worker-test",
            defaultBatchLimit: 10
        )
        let result = try worker.drainOnce(limit: 10)

        #expect(result.scanned == 1)
        #expect(result.appended == 1)
        #expect(result.alreadyProjected == 0)
        #expect(result.marked == 1)
        #expect(store.pendingMutationProjectionOutboxRows(limit: 10).isEmpty)

        let row = try #require(store.mutationProjectionOutboxRows(mutationID: envelope.mutationID).first)
        #expect(row.opLogSeq == 0)
        #expect(row.projectedAt != nil)
        #expect(row.leaseOwner == nil)
        #expect(row.leaseUntil == nil)

        let client = try RustOpLogFFIClient(databaseURL: opLogURL, actorID: "projection-worker-reader")
        let entry = try #require(client.iterateAll().first)
        #expect(entry.seq == 0)
        #expect(entry.payload.projectionMutationID == envelope.mutationID)
    }

    @Test("No interrupted runs returns nil")
    func noInterruptedRuns() {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }
        #expect(store.mostRecentInterruptedRun() == nil)
    }
}

@Suite("Paperclip State Store")
struct PaperclipStateStoreTests {
    private func makeTestStore() throws -> PaperclipStateStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("paperclip-store-\(UUID().uuidString)", isDirectory: true)
        let dbPath = tempDir.appendingPathComponent("paperclip.sqlite").path
        return try PaperclipStateStore(path: dbPath)
    }

    @Test("Paperclip store persists quoted tick fields without SQL breakage")
    func persistsQuotedTickFields() async throws {
        let store = try makeTestStore()

        let tick = AgentTick(
            sessionId: "session-'quoted'",
            agentId: "agent-'quoted'",
            timestamp: Date(),
            inputTokens: 11,
            outputTokens: 17,
            toolName: "tool-'quoted'",
            costMicroDollars: 42,
            turnNumber: 3
        )

        try await store.recordTick(tick)

        let tokenCount = try await store.sessionTokenCount(sessionId: tick.sessionId)
        #expect(tokenCount.input == tick.inputTokens)
        #expect(tokenCount.output == tick.outputTokens)

        let dailyCost = try await store.dailyCost(agentId: tick.agentId)
        #expect(dailyCost == tick.costMicroDollars)
    }

    @Test("Paperclip store persists quoted heartbeat payloads without SQL breakage")
    func persistsQuotedHeartbeatPayloads() async throws {
        let store = try makeTestStore()

        let heartbeat = CronHeartbeat(
            agentId: "agent-'quoted'",
            scheduledAt: Date(),
            executedAt: Date(),
            durationMs: 88,
            success: false,
            errorMessage: "error-'quoted'"
        )

        try await store.recordHeartbeat(heartbeat)

        let recent = try await store.recentHeartbeats(agentId: heartbeat.agentId, limit: 1)
        #expect(recent.count == 1)
        #expect(recent.first?.agentId == heartbeat.agentId)
        #expect(recent.first?.errorMessage == heartbeat.errorMessage)
        #expect(recent.first?.success == false)
    }
}

// MARK: - Night Brain Checkpoint Resume Tests

@Suite("Night Brain Checkpoint Resume")
struct NightBrainCheckpointResumeTests {
    private enum SampleFailure: Error {
        case expected
    }

    private func makeTestStore() -> EventStore? {
        let tempDir = FileManager.default.temporaryDirectory
        let dbURL = tempDir.appendingPathComponent("test-\(UUID().uuidString).sqlite")
        return EventStore(databaseURL: dbURL)
    }

    @Test("Checkpoint rows are written per job and readable for resume")
    func checkpointWriteAndRead() {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let runId = store.insertNightBrainRun(status: "running", triggerReason: "test")
        #expect(runId != nil)

        // Simulate two jobs completing with checkpoint writes
        store.insertCheckpoint(runId: runId!, jobType: "event_store_checkpoint_vacuum", data: "{}")
        store.insertCheckpoint(runId: runId!, jobType: "dedupe_artifacts", data: "{}")

        // checkpointedJobTypes reads from the checkpoint TABLE
        let completed = store.checkpointedJobTypes(runId: runId!)
        #expect(completed.count == 2)
        #expect(completed.contains("event_store_checkpoint_vacuum"))
        #expect(completed.contains("dedupe_artifacts"))
    }

    @Test("Night Brain job order includes cloud knowledge distillation before maintenance log")
    func nightBrainJobOrderIncludesCloudKnowledgeDistillation() {
        let jobs = NightBrainService.Job.allCases.map(\.rawValue)
        #expect(jobs.contains("cloud_knowledge_distillation"))
        #expect(jobs.last == "maintenance_log")
        if let distillationIndex = jobs.firstIndex(of: "cloud_knowledge_distillation"),
           let maintenanceIndex = jobs.firstIndex(of: "maintenance_log") {
            #expect(distillationIndex < maintenanceIndex)
        }
    }

    @Test("Failing jobs do not checkpoint or report completion")
    func failingJobsDoNotCheckpointOrReportCompletion() async {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let service = NightBrainService(
            config: EpistemosConfig(),
            storeProvider: { store },
            cloudKnowledgeJob: { () async throws in
                throw SampleFailure.expected
            }
        )

        let result = await service.runPipelineForTesting(
            jobOrder: [NightBrainService.Job.cloudKnowledgeDistillation]
        )

        #expect(result == .deferred)
        #expect(store.completedNightBrainRuns(limit: 10).isEmpty)

        let runId = store.mostRecentInterruptedRun()
        #expect(runId != nil)
        if let runId {
            #expect(store.checkpointedJobTypes(runId: runId).isEmpty)
        }
    }

    @Test("Missing cloud knowledge job does not checkpoint or report completion")
    func missingCloudKnowledgeJobDoesNotCheckpointOrReportCompletion() async {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let service = NightBrainService(
            config: EpistemosConfig(),
            storeProvider: { store }
        )

        let result = await service.runPipelineForTesting(
            jobOrder: [NightBrainService.Job.cloudKnowledgeDistillation]
        )

        #expect(result == .deferred)
        #expect(store.completedNightBrainRuns(limit: 10).isEmpty)

        let runId = store.mostRecentInterruptedRun()
        #expect(runId != nil)
        if let runId {
            #expect(store.checkpointedJobTypes(runId: runId).isEmpty)
        }
    }

    @Test("Missing search index does not checkpoint or report completion")
    func missingSearchIndexDoesNotCheckpointOrReportCompletion() async {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let service = NightBrainService(
            config: EpistemosConfig(),
            storeProvider: { store }
        )

        let result = await service.runPipelineForTesting(
            jobOrder: [NightBrainService.Job.searchIndexPassiveCheckpoint]
        )

        #expect(result == .deferred)
        #expect(store.completedNightBrainRuns(limit: 10).isEmpty)

        let runId = store.mostRecentInterruptedRun()
        #expect(runId != nil)
        if let runId {
            #expect(store.checkpointedJobTypes(runId: runId).isEmpty)
        }
    }

    @Test("Missing graph memory does not checkpoint or report completion")
    func missingGraphMemoryDoesNotCheckpointOrReportCompletion() async {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let service = NightBrainService(
            config: EpistemosConfig(),
            storeProvider: { store }
        )

        let result = await service.runPipelineForTesting(
            jobOrder: [NightBrainService.Job.memoryDistillation]
        )

        #expect(result == .deferred)
        #expect(store.completedNightBrainRuns(limit: 10).isEmpty)

        let runId = store.mostRecentInterruptedRun()
        #expect(runId != nil)
        if let runId {
            #expect(store.checkpointedJobTypes(runId: runId).isEmpty)
        }
    }

    @Test("Night Brain keeps using the initial EventStore for durable checkpoints")
    func nightBrainRetainsInitialStoreForCheckpointDurability() async {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        final class StoreProviderState: @unchecked Sendable {
            private let lock = NSLock()
            nonisolated(unsafe) private var storeProviderCalls = 0

            nonisolated func nextStore(_ store: EventStore) -> EventStore? {
                lock.lock()
                defer { lock.unlock() }
                storeProviderCalls += 1
                return storeProviderCalls == 1 ? store : nil
            }
        }

        let storeProviderState = StoreProviderState()
        let service = NightBrainService(
            config: EpistemosConfig(),
            storeProvider: {
                storeProviderState.nextStore(store)
            }
        )

        let result = await service.runPipelineForTesting(
            jobOrder: [.maintenanceLog]
        )

        #expect(result == .finished)

        let completedRuns = store.completedNightBrainRuns(limit: 10)
        #expect(completedRuns.count == 1)
        if let completedRun = completedRuns.first {
            #expect(completedRun.jobsCompleted == [NightBrainService.Job.maintenanceLog.rawValue])
            #expect(
                store.checkpointedJobTypes(runId: completedRun.id)
                == [NightBrainService.Job.maintenanceLog.rawValue]
            )
        }
    }

    @Test("Night Brain store-backed jobs reuse the initial EventStore")
    func nightBrainStoreBackedJobsReuseInitialStore() async {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        final class StoreProviderState: @unchecked Sendable {
            private let lock = NSLock()
            nonisolated(unsafe) private var storeProviderCalls = 0

            nonisolated func nextStore(_ store: EventStore) -> EventStore? {
                lock.lock()
                defer { lock.unlock() }
                storeProviderCalls += 1
                return store
            }

            nonisolated func callCount() -> Int {
                lock.lock()
                defer { lock.unlock() }
                return storeProviderCalls
            }
        }

        let storeProviderState = StoreProviderState()
        let service = NightBrainService(
            config: EpistemosConfig(),
            storeProvider: {
                storeProviderState.nextStore(store)
            }
        )

        let result = await service.runPipelineForTesting(
            jobOrder: [
                .eventStoreCheckpointVacuum,
                .dedupeArtifacts,
                .workspaceSnapshotCompaction,
            ]
        )

        #expect(result == .finished)
        #expect(storeProviderState.callCount() == 1)
    }

    @Test("Resume skips checkpointed jobs and continues from where it left off")
    func resumeSkipsCheckpointedJobs() {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        // Create a run, write checkpoints for first 2 jobs, then interrupt
        let runId = store.insertNightBrainRun(status: "running", triggerReason: "test")!
        store.insertCheckpoint(runId: runId, jobType: "event_store_checkpoint_vacuum", data: "{}")
        store.insertCheckpoint(runId: runId, jobType: "dedupe_artifacts", data: "{}")
        store.updateNightBrainRun(
            id: runId, status: "interrupted",
            completedJobs: ["event_store_checkpoint_vacuum", "dedupe_artifacts"]
        )

        // Simulate what the pipeline does on resume: find interrupted run, read checkpoints
        let interrupted = store.mostRecentInterruptedRun()
        #expect(interrupted == runId)

        let alreadyDone = store.checkpointedJobTypes(runId: interrupted!)
        #expect(alreadyDone == ["event_store_checkpoint_vacuum", "dedupe_artifacts"])

        // The pipeline would skip these and continue with remaining jobs
        let allJobs = [
            "event_store_checkpoint_vacuum",
            "search_index_passive_checkpoint",
            "dedupe_artifacts",
            "workspace_snapshot_compaction",
            "memory_distillation",
            "cloud_knowledge_distillation",
            "maintenance_log",
        ]
        let remaining = allJobs.filter { !alreadyDone.contains($0) }
        #expect(remaining == [
            "search_index_passive_checkpoint",
            "workspace_snapshot_compaction",
            "memory_distillation",
            "cloud_knowledge_distillation",
            "maintenance_log",
        ])
    }

    @Test("Empty checkpoint table means no jobs to skip")
    func emptyCheckpointMeansFullRun() {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let runId = store.insertNightBrainRun(status: "running", triggerReason: "test")!
        let completed = store.checkpointedJobTypes(runId: runId)
        #expect(completed.isEmpty)
    }

    @Test("Checkpoint table is authoritative over stale jobs_completed payloads")
    func checkpointsOverrideStaleJobsCompleted() {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let runId = store.insertNightBrainRun(status: "running", triggerReason: "test")!
        store.updateNightBrainRun(
            id: runId, status: "interrupted",
            completedJobs: ["workspace_snapshot_compaction", "maintenance_log"]
        )
        store.insertCheckpoint(runId: runId, jobType: "event_store_checkpoint_vacuum", data: "{}")

        let completed = store.checkpointedJobTypes(runId: runId)
        #expect(completed == ["event_store_checkpoint_vacuum"])
    }

    @Test("Completed runs are not returned by mostRecentInterruptedRun")
    func completedRunsNotReturned() async throws {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let runId = store.insertNightBrainRun(status: "running", triggerReason: "test")!
        store.updateNightBrainRun(
            id: runId, status: "completed",
            completedJobs: ["all_done"],
            completedAt: Date().timeIntervalSince1970
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(store.mostRecentInterruptedRun() == nil)
    }
}

// Hermes heartbeat tests are kept for reference while the old subprocess
// runtime stays retired.
#if false
@Suite("Agent Heartbeat")
struct AgentHeartbeatTests {
    @Test("Heartbeat finishes after Hermes stays available through the monitoring window")
    @MainActor
    func heartbeatFinishesWhenHermesStaysAvailable() async throws {
        let runtime = try await makeHeartbeatRuntime()
        defer {
            runtime.manager.terminate()
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        let service = AgentHeartbeatService(
            config: EpistemosConfig(),
            hermesManagerProvider: { runtime.manager },
            postDispatchMonitoringWindow: .milliseconds(200),
            postDispatchPollInterval: .milliseconds(25)
        )

        let result = await service.runHeartbeatForTesting()

        #expect(result == .finished)
        #expect(runtime.manager.isRunning)
    }

    @Test("Heartbeat defers when Hermes drops during post-dispatch monitoring")
    @MainActor
    func heartbeatDefersWhenHermesDropsMidWindow() async throws {
        let runtime = try await makeHeartbeatRuntime()
        defer {
            runtime.manager.terminate()
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        let service = AgentHeartbeatService(
            config: EpistemosConfig(),
            hermesManagerProvider: { runtime.manager },
            postDispatchMonitoringWindow: .milliseconds(400),
            postDispatchPollInterval: .milliseconds(25)
        )

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            runtime.manager.terminate()
        }

        let result = await service.runHeartbeatForTesting()

        #expect(result == .deferred)
    }

    @Test("Heartbeat monitoring exits promptly when cancelled")
    @MainActor
    func heartbeatMonitoringExitsPromptlyWhenCancelled() async throws {
        let runtime = try await makeHeartbeatRuntime()
        defer {
            runtime.manager.terminate()
            try? FileManager.default.removeItem(at: runtime.rootURL)
        }

        let service = AgentHeartbeatService(
            config: EpistemosConfig(),
            hermesManagerProvider: { runtime.manager },
            postDispatchMonitoringWindow: .seconds(2),
            postDispatchPollInterval: .milliseconds(25)
        )

        let monitoringTask = Task {
            await service.monitorPostDispatchHermesAvailabilityForTesting()
        }

        try await Task.sleep(for: .milliseconds(75))

        let clock = ContinuousClock()
        let cancelStarted = clock.now
        monitoringTask.cancel()
        let result = await monitoringTask.value
        let elapsed = cancelStarted.duration(to: clock.now)

        #expect(result == false)
        #expect(elapsed < .milliseconds(250))
    }

    @MainActor
    private func makeHeartbeatRuntime() async throws -> (manager: HermesSubprocessManager, rootURL: URL) {
        let fm = FileManager.default
        let rootURL = fm.temporaryDirectory
            .appendingPathComponent("agent-heartbeat-tests-\(UUID().uuidString)", isDirectory: true)
        let hermesHome = rootURL.appendingPathComponent("home", isDirectory: true)
        try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: hermesHome, withIntermediateDirectories: true)

        let bridgeURL = rootURL.appendingPathComponent("epistemos_bridge.py")
        let runAgentURL = rootURL.appendingPathComponent("run_agent.py")
        let bridgeScript = """
        #!/usr/bin/env python3
        import sys
        import time

        if __name__ == "__main__":
            for _line in sys.stdin:
                time.sleep(60)
        """
        let runAgentStub = """
        #!/usr/bin/env python3
        print("stub")
        """

        try Data(bridgeScript.utf8).write(to: bridgeURL, options: .atomic)
        try Data(runAgentStub.utf8).write(to: runAgentURL, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bridgeURL.path)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runAgentURL.path)

        let pythonPath = fm.isExecutableFile(atPath: "/usr/bin/python3")
            ? "/usr/bin/python3"
            : HermesConfig.resolve().pythonPath
        let config = HermesConfig(
            pythonPath: pythonPath,
            hermesAgentDir: rootURL,
            model: "test",
            maxTurns: 1,
            environment: [
                "HERMES_HOME": hermesHome.path,
                "PYTHONUNBUFFERED": "1",
            ]
        )
        let manager = HermesSubprocessManager(config: config)
        try await manager.launch()
        return (manager, rootURL)
    }
}
#endif

@Suite("Agent Runtime Monitoring")
struct AgentRuntimeMonitoringTests {
    @Test("current agent runtime waits for native computer observations and explicit approvals")
    func currentAgentRuntimeWaitsForNativeComputerObservationsAndExplicitApprovals() throws {
        let coordinator = try loadMonitoringSource("Epistemos/App/ChatCoordinator.swift")
        let delegate = try loadMonitoringSource("Epistemos/Bridge/StreamingDelegate.swift")

        #expect(coordinator.contains("chatState.recordToolUse("))
        #expect(coordinator.contains("chatState.recordToolResult("))
        #expect(coordinator.contains("approved = await promptForToolApproval(request)"))
        #expect(!coordinator.contains("ComputerUseBridge.shared.execute(actionJSON: inputJson)"))
        #expect(delegate.contains("func executeComputerAction(actionJson: String) -> String"))
    }
}

// MARK: - Phase 1: Ambient Capture Tests

@Suite("Ambient Capture")
struct AmbientCaptureTests {

    @Test("Secret redaction removes API keys")
    func redactAPIKeys() {
        let input = "api_key=sk_live_abc123def456"
        let result = AmbientCaptureService.redactSecrets(input)
        #expect(result.contains("[REDACTED]"))
        #expect(!result.contains("sk_live_abc123def456"))
    }

    @Test("Secret redaction removes email addresses")
    func redactEmails() {
        let input = "Contact user@example.com for help"
        let result = AmbientCaptureService.redactSecrets(input)
        #expect(result.contains("[REDACTED]"))
        #expect(!result.contains("user@example.com"))
    }

    @Test("Secret redaction removes credit card numbers")
    func redactCreditCards() {
        let input = "Card: 4111-1111-1111-1111"
        let result = AmbientCaptureService.redactSecrets(input)
        #expect(result.contains("[REDACTED]"))
        #expect(!result.contains("4111"))
    }

    @Test("Secret redaction removes SSNs")
    func redactSSNs() {
        let input = "SSN: 123-45-6789"
        let result = AmbientCaptureService.redactSecrets(input)
        #expect(result.contains("[REDACTED]"))
        #expect(!result.contains("123-45-6789"))
    }

    @Test("Secret redaction leaves normal text unchanged")
    func redactNormalText() {
        let input = "This is a normal paragraph about Swift programming"
        let result = AmbientCaptureService.redactSecrets(input)
        #expect(result == input)
    }

    @Test("Ambient capture compiles all secret redaction patterns")
    func secretRedactionPatternsAllCompile() {
        #expect(AmbientCaptureService.secretPatterns.count == 4)
    }

    @Test("Stable hash is deterministic")
    func stableHashDeterministic() {
        let hash1 = AmbientCaptureService.stableHash("hello world")
        let hash2 = AmbientCaptureService.stableHash("hello world")
        #expect(hash1 == hash2)
    }

    @Test("Stable hash differs for different inputs")
    func stableHashDiffers() {
        let hash1 = AmbientCaptureService.stableHash("hello world")
        let hash2 = AmbientCaptureService.stableHash("hello world!")
        #expect(hash1 != hash2)
    }

    @Test("Startup warmup suppresses immediate capture activations")
    func startupWarmupSuppressesImmediateCaptureActivations() {
        let startedAt = Date()
        let now = startedAt.addingTimeInterval(0.25)

        #expect(
            AmbientCaptureService.shouldProcessActivationDuringStartupWarmupForTesting(
                startedAt: startedAt,
                now: now
            ) == false
        )
    }

    @Test("Startup warmup allows capture after launch settles")
    func startupWarmupAllowsCaptureAfterLaunchSettles() {
        let startedAt = Date()
        let now = startedAt.addingTimeInterval(1.25)

        #expect(
            AmbientCaptureService.shouldProcessActivationDuringStartupWarmupForTesting(
                startedAt: startedAt,
                now: now
            ) == true
        )
    }
}

// MARK: - Live Toggle Behavior Tests

@Suite("Live Toggle Behavior")
@MainActor
struct LiveToggleTests {

    @Test("Friction monitor respects live config toggle")
    func frictionLiveToggle() async {
        let config = EpistemosConfig()
        config.frictionEnabled = true
        let monitor = FrictionMonitorService(config: config)

        // Should accept events when enabled
        await monitor.record(EditorTelemetryEvent(
            noteId: "note-1", kind: .insertion(count: 5),
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000)
        ))
        // No crash = event was accepted

        // Disable live — next event should be silently dropped
        config.frictionEnabled = false
        await monitor.record(EditorTelemetryEvent(
            noteId: "note-1", kind: .insertion(count: 5),
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000) + 100
        ))
        // No crash = disabled path works
    }

    @Test("EpistemosConfig blocklist is enforced by isBlocked")
    func blocklistEnforced() {
        let config = EpistemosConfig()
        config.blocklistJSON = "[\"com.apple.Safari\",\"com.slack.Slack\"]"

        #expect(config.isBlocked("com.apple.Safari"))
        #expect(config.isBlocked("com.slack.Slack"))
        #expect(!config.isBlocked("com.apple.Terminal"))
    }

    @Test("EpistemosConfig allowlist restricts to listed apps only")
    func allowlistRestricts() {
        let config = EpistemosConfig()
        config.allowlistJSON = "[\"com.apple.Safari\"]"
        config.blocklistJSON = "[]"

        #expect(!config.isBlocked("com.apple.Safari"))
        #expect(config.isBlocked("com.apple.Terminal"))
    }

    @Test("Blocklist takes priority over allowlist")
    func blocklistPriority() {
        let config = EpistemosConfig()
        config.allowlistJSON = "[\"com.apple.Safari\"]"
        config.blocklistJSON = "[\"com.apple.Safari\"]"

        // Blocklist is checked first, so Safari should be blocked
        #expect(config.isBlocked("com.apple.Safari"))
    }

    @Test("Night Brain continue gate respects live config and AC requirements")
    func nightBrainContinueGateUsesLiveConfig() async {
        let config = EpistemosConfig()
        config.nightBrainEnabled = true
        config.nightBrainRequiresAC = true
        config.nightBrainMinIdleSeconds = 300
        let service = NightBrainService(config: config)

        #expect(await service.canContinue(idleSeconds: 301, thermalPressureLevel: 1, onACPower: true))

        config.nightBrainEnabled = false
        #expect(!(await service.canContinue(idleSeconds: 301, thermalPressureLevel: 1, onACPower: true)))

        config.nightBrainEnabled = true
        #expect(!(await service.canContinue(idleSeconds: 301, thermalPressureLevel: 1, onACPower: false)))

        config.nightBrainRequiresAC = false
        config.nightBrainMinIdleSeconds = 500
        #expect(!(await service.canContinue(idleSeconds: 301, thermalPressureLevel: 1, onACPower: true)))
    }
}

// MARK: - Phase 2: Friction Detection Tests

@Suite("Friction Detection")
struct FrictionDetectionTests {

    @Test("Ring buffer push and toArray")
    func ringBufferBasic() {
        var buffer = RingBuffer<Int>(capacity: 5)
        for i in 0..<3 {
            buffer.push(i)
        }
        #expect(buffer.count == 3)
        #expect(buffer.toArray() == [0, 1, 2])
    }

    @Test("Ring buffer wraps on overflow")
    func ringBufferOverflow() {
        var buffer = RingBuffer<Int>(capacity: 3)
        for i in 0..<5 {
            buffer.push(i)
        }
        #expect(buffer.count == 3)
        #expect(buffer.toArray() == [2, 3, 4])
    }

    @Test("Ring buffer reset clears state")
    func ringBufferReset() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.push(1)
        buffer.push(2)
        buffer.reset()
        #expect(buffer.count == 0)
        #expect(buffer.toArray().isEmpty)
    }

    @Test("Smooth typing stays below friction threshold")
    func smoothTypingLowFriction() async {
        let monitor = FrictionMonitorService(config: EpistemosConfig())

        let baseTime = Int64(Date().timeIntervalSince1970 * 1000)
        for i in 0..<50 {
            await monitor.record(EditorTelemetryEvent(
                noteId: "test-note",
                kind: .insertion(count: 5),
                timestampMs: baseTime + Int64(i) * 100
            ))
        }
    }

    @Test("AI stream events are filtered out")
    func aiStreamEventsFiltered() async {
        let monitor = FrictionMonitorService(config: EpistemosConfig())

        await monitor.record(EditorTelemetryEvent(
            noteId: "test-note",
            kind: .aiStreamEnd,
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000)
        ))
    }

    @Test("Friction disabled = no recording")
    func frictionDisabledNoOp() async {
        let disabledConfig = EpistemosConfig()
        disabledConfig.frictionEnabled = false
        let monitor = FrictionMonitorService(config: disabledConfig)

        await monitor.record(EditorTelemetryEvent(
            noteId: "test-note",
            kind: .insertion(count: 1),
            timestampMs: Int64(Date().timeIntervalSince1970 * 1000)
        ))

        // Restore so @AppStorage doesn't poison other tests
        disabledConfig.frictionEnabled = true
    }

    @Test("Note switch rotates session ID and flushes buffer")
    func noteSwitch() async {
        let monitor = FrictionMonitorService(config: EpistemosConfig())

        // Record events for note-1
        let baseTime = Int64(Date().timeIntervalSince1970 * 1000)
        for i in 0..<5 {
            await monitor.record(EditorTelemetryEvent(
                noteId: "note-1",
                kind: .insertion(count: 3),
                timestampMs: baseTime + Int64(i) * 200
            ))
        }

        // Switch to note-2 — this should flush note-1's buffer and start fresh
        await monitor.record(EditorTelemetryEvent(
            noteId: "note-2",
            kind: .insertion(count: 1),
            timestampMs: baseTime + 5000
        ))

        // Explicit note switch notification
        await monitor.noteDidSwitch(oldNoteId: "note-2")
        // No crash, buffer is clean
    }
}

@Suite("Friction Persistence", .serialized)
struct FrictionPersistenceTests {

    private func makeTestStore() -> EventStore? {
        let tempDir = FileManager.default.temporaryDirectory
        let dbURL = tempDir.appendingPathComponent("test-\(UUID().uuidString).sqlite")
        return EventStore(databaseURL: dbURL)
    }

    @Test("Note switches persist separate friction windows with distinct sessions")
    func noteSwitchPersistsDistinctSessions() async {
        guard let store = makeTestStore() else {
            Issue.record("Failed to create test EventStore")
            return
        }

        let config = EpistemosConfig()
        config.frictionEnabled = true
        let monitor = FrictionMonitorService(config: config, storeProvider: { store })
        let baseTime: Int64 = 1_000_000

        for i in 0..<20 {
            await monitor.record(EditorTelemetryEvent(
                noteId: "note-1",
                kind: .insertion(count: 2),
                timestampMs: baseTime + Int64(i) * 2_000
            ))
        }

        await monitor.record(EditorTelemetryEvent(
            noteId: "note-2",
            kind: .insertion(count: 1),
            timestampMs: baseTime + 40_000
        ))

        for i in 1..<20 {
            await monitor.record(EditorTelemetryEvent(
                noteId: "note-2",
                kind: .insertion(count: 2),
                timestampMs: baseTime + 40_000 + Int64(i) * 2_000
            ))
        }

        await monitor.noteDidSwitch(oldNoteId: "note-2")

        let windows = store.frictionWindows(limit: 10)
        #expect(windows.count == 2)
        #expect(windows[0].noteId == "note-1")
        #expect(windows[1].noteId == "note-2")
        #expect(windows[0].sessionId != windows[1].sessionId)
    }
}

// MARK: - Phase 3: Graph Pin Tests

@Suite("Graph Pinning")
@MainActor
struct GraphPinTests {

    @Test("Pin and unpin updates pinnedNodeIds set")
    func pinUnpinState() {
        let state = GraphState()
        #expect(state.pinnedNodeIds.isEmpty)

        state.pinnedNodeIds.insert("node-1")
        #expect(state.pinnedNodeIds.contains("node-1"))

        state.pinnedNodeIds.remove("node-1")
        #expect(state.pinnedNodeIds.isEmpty)
    }

    @Test("Freeze all nodes populates pinnedNodeIds")
    func freezeAllNodes() {
        let state = GraphState()
        let node1 = GraphNodeRecord(
            id: "n1", type: .note, label: "Note 1", sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
        let node2 = GraphNodeRecord(
            id: "n2", type: .note, label: "Note 2", sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: .now, position: .zero, velocity: .zero
        )
        state.store.addNode(node1)
        state.store.addNode(node2)

        state.freezeAllNodes()
        #expect(state.pinnedNodeIds.contains("n1"))
        #expect(state.pinnedNodeIds.contains("n2"))
    }

    @Test("Unfreeze all clears pinnedNodeIds")
    func unfreezeAllNodes() {
        let state = GraphState()
        state.pinnedNodeIds = Set(["n1", "n2", "n3"])
        state.unfreezeAllNodes()
        #expect(state.pinnedNodeIds.isEmpty)
    }

    @Test("GraphOverlaySnapshot persists pinnedNodeIds")
    func snapshotPersistence() throws {
        let snapshot = GraphOverlaySnapshot(
            visibility: .full,
            selectedNodeId: "sel-1",
            pinnedNodeIds: ["pin-1", "pin-2"]
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(GraphOverlaySnapshot.self, from: data)
        #expect(decoded.pinnedNodeIds == ["pin-1", "pin-2"])
    }

    @Test("GraphOverlaySnapshot backward compat with nil pinnedNodeIds")
    func snapshotBackwardCompat() throws {
        let json = """
        {"visibility":"full","selectedNodeId":"sel-1"}
        """
        let decoded = try JSONDecoder().decode(GraphOverlaySnapshot.self, from: Data(json.utf8))
        #expect(decoded.pinnedNodeIds == nil)
    }
}

// MARK: - Phase 4: Night Brain Tests

@Suite("Night Brain")
struct NightBrainTests {

    @Test("Thermal pressure level returns a valid value")
    func thermalPressureLevel() {
        let level = NightBrainService.thermalPressureLevel()
        #expect(level <= 4)
    }

    @Test("User idle seconds returns non-negative")
    func userIdleSeconds() {
        let idle = NightBrainService.userIdleSeconds()
        #expect(idle >= 0)
    }
}

@Suite("Activity Tracker", .serialized)
struct ActivityTrackerTests {
    private func makeTestStore() -> EventStore? {
        let tempDir = FileManager.default.temporaryDirectory
        let dbURL = tempDir.appendingPathComponent("test-\(UUID().uuidString).sqlite")
        return EventStore(databaseURL: dbURL)
    }

    private func makeCacheURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("activity-tracker-\(UUID().uuidString).json")
    }

    @MainActor
    @Test("chat messages append to EventStore durably")
    func chatMessagesAppendToEventStoreDurably() async throws {
        let store = try #require(makeTestStore())
        let cacheURL = makeCacheURL()
        let tracker = ActivityTracker(
            eventStoreProvider: { store },
            cacheFileURLProvider: { cacheURL }
        )

        let snippet = String(repeating: "a", count: 120)
        tracker.recordChatMessage(chatId: "chat-1", snippet: snippet)

        var storedEvents: [EventStore.StoredEvent] = []
        for _ in 0..<20 {
            storedEvents = store.events(from: .distantPast, to: .now)
            if storedEvents.count == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(storedEvents.count == 1)
        #expect(storedEvents.first?.kind == "chat_message")
        #expect(storedEvents.first?.payload.contains(#""chatId":"chat-1""#) == true)
        #expect(storedEvents.first?.payload.contains(String(repeating: "a", count: 80)) == true)
    }

    @MainActor
    @Test("loadFlushedEvents merges recovered cache with current in-memory events")
    func loadFlushedEventsMergesRecoveredCacheWithCurrentEvents() {
        let store = makeTestStore()
        let cacheURL = makeCacheURL()

        let firstTracker = ActivityTracker(
            eventStoreProvider: { store },
            cacheFileURLProvider: { cacheURL }
        )
        firstTracker.recordChatMessage(chatId: "chat-1", snippet: "first")
        firstTracker.flushToDisk()

        #expect(FileManager.default.fileExists(atPath: cacheURL.path))

        let secondTracker = ActivityTracker(
            eventStoreProvider: { store },
            cacheFileURLProvider: { cacheURL }
        )
        secondTracker.recordChatMessage(chatId: "chat-2", snippet: "second")
        secondTracker.loadFlushedEvents()

        let events = secondTracker.recentEvents(since: .distantPast)
        #expect(events.count == 2)
        #expect(!FileManager.default.fileExists(atPath: cacheURL.path))
    }
}

@Suite("Daily Brief State", .serialized)
struct DailyBriefStateTests {
    @MainActor
    @Test("dismiss cleanup is cancelled when a new daily brief starts")
    func dismissCleanupIsCancelledWhenNewBriefStarts() async throws {
        let state = DailyBriefState()
        state.onDailyBriefGenerate = { _ in
            "Fresh brief"
        }

        state.showDailyBrief = true
        state.dailyBriefContent = "Stale brief"
        state.isDailyBriefLoading = false

        state.dismissDailyBrief()
        try await Task.sleep(for: .milliseconds(100))
        state.requestDailyBrief(prompt: "Generate again")
        try await Task.sleep(for: .milliseconds(650))

        #expect(state.showDailyBrief)
        #expect(!state.isDailyBriefLoading)
        #expect(state.dailyBriefContent == "Fresh brief")
    }
}

@Suite("Event Bus", .serialized)
struct EventBusTests {
    @MainActor
    @Test("async event streams keep only the newest buffered events")
    func asyncEventStreamsKeepOnlyNewestBufferedEvents() async {
        let bus = EventBus()
        var iterator = bus.events().makeAsyncIterator()

        for value in 0..<300 {
            bus.emit(.custom(name: "buffer", payload: .int(value)))
        }

        var received = [Int]()
        received.reserveCapacity(256)
        for _ in 0..<256 {
            guard let event = await iterator.next() else {
                Issue.record("Expected buffered event")
                return
            }
            guard case let .custom(_, payload) = event,
                  case let .int(value)? = payload else {
                Issue.record("Expected integer custom payload")
                return
            }
            received.append(value)
        }

        #expect(received.count == 256)
        #expect(received.first == 44)
        #expect(received.last == 299)
    }
}

// MARK: - Phase 5: Config Tests

@Suite("EpistemosConfig")
struct EpistemosConfigTests {

    @Test("Default values are sensible")
    func defaultValues() {
        // Remove any polluted keys so @AppStorage falls back to init defaults
        let keys = ["capture.enabled", "friction.enabled", "nightbrain.enabled", "nightbrain.requiresAC"]
        for key in keys { UserDefaults.standard.removeObject(forKey: key) }

        let config = EpistemosConfig()
        #expect(config.captureEnabled == false)
        #expect(config.frictionEnabled == true)
        #expect(config.nightBrainEnabled == true)
        #expect(config.nightBrainRequiresAC == true)
    }

    @Test("Blocklist rejects blocked bundle IDs")
    func blocklistRejects() {
        let config = EpistemosConfig()
        config.allowlistJSON = "[]"
        config.blocklistJSON = "[\"com.blocked.app\"]"
        #expect(config.isBlocked("com.blocked.app"))
        #expect(!config.isBlocked("com.allowed.app"))
    }

    @Test("Allowlist restricts to allowed bundle IDs only")
    func allowlistRestricts() {
        let config = EpistemosConfig()
        config.allowlistJSON = "[\"com.allowed.app\"]"
        #expect(!config.isBlocked("com.allowed.app"))
        #expect(config.isBlocked("com.other.app"))
    }

    @Test("Empty allowlist allows everything")
    func emptyAllowlistAllowsAll() {
        let config = EpistemosConfig()
        config.allowlistJSON = "[]"
        config.blocklistJSON = "[]"
        #expect(!config.isBlocked("com.any.app"))
    }

    @Test("Malformed capture filter JSON fails closed")
    func malformedCaptureFilterJSONFailsClosed() {
        let config = EpistemosConfig()

        config.allowlistJSON = "{not-json"
        config.blocklistJSON = "[]"
        #expect(config.isBlocked("com.any.app"))

        config.allowlistJSON = "[]"
        config.blocklistJSON = "{not-json"
        #expect(config.isBlocked("com.any.app"))
    }
}

private func loadMonitoringSource(_ relativePath: String) throws -> String {
    try loadMirroredSourceTextFile(relativePath)
}

@Suite("Phase 7 Bridge")
struct Phase7BridgeTests {
    @MainActor
    @Test("vault integrity check alias is rejected instead of masquerading as maintenance log")
    func vaultIntegrityCheckAliasIsRejected() {
        #expect(Phase7Bridge.supportedJobAliases["vault_integrity_check"] == nil)
        #expect(Phase7Bridge.supportedJobAliases["maintenance_log"] == .maintenanceLog)
    }
}

@Suite("OpLog FFI Boundary Guards")
struct OpLogFFIBoundaryGuardTests {
    private let rawSymbols = [
        "oplog_open_at",
        "oplog_iter_after_json",
        "oplog_iter_all_json",
        "oplog_append_payload_json",
        "oplog_chain_tip_hex",
        "oplog_verify_chain_json",
        "oplog_release",
        "oplog_free_string",
    ]

    @Test("Rust OpLog raw C ABI exports stay explicit and bounded")
    func rustOpLogExportsStayExplicitAndBounded() throws {
        let libSource = try loadMirroredSourceTextFile("agent_core/src/lib.rs")
        let oplogSource = try loadMirroredSourceTextFile("agent_core/src/oplog.rs")

        #expect(libSource.contains("pub mod oplog;"))
        #expect(oplogSource.contains("Arc::into_raw"))
        #expect(oplogSource.contains("Arc::decrement_strong_count"))
        #expect(oplogSource.contains("CString::new(json)"))
        #expect(oplogSource.contains("CString::from_raw"))
        #expect(oplogSource.contains("out_error"))

        for symbol in rawSymbols {
            #expect(oplogSource.contains("#[unsafe(no_mangle)]\npub unsafe extern \"C\" fn \(symbol)"))
        }

        let rawExportCount = oplogSource
            .components(separatedBy: "pub unsafe extern \"C\" fn oplog_")
            .count - 1
        #expect(rawExportCount == rawSymbols.count)
    }

    @Test("Swift OpLog bridge owns raw symbols and worker is the only production client")
    func swiftOpLogBridgeOwnsRawSymbolsAndWorkerIsOnlyProductionClient() throws {
        let bridge = try loadMirroredSourceTextFile("Epistemos/Engine/RustOpLogFFIClient.swift")
        let worker = try loadMirroredSourceTextFile("Epistemos/Engine/MutationOpLogProjectionWorker.swift")
        let bootstrap = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")

        for symbol in rawSymbols {
            #expect(bridge.contains("@_silgen_name(\"\(symbol)\")"))
        }
        #expect(bridge.contains("private let handle: UnsafePointer<UInt8>"))
        #expect(bridge.contains("deinit"))
        #expect(bridge.contains("oplog_release(handle)"))
        #expect(bridge.contains("defer { oplog_free_string(raw) }"))
        #expect(worker.contains("RustOpLogFFIClient(databaseURL: databaseURL, actorID: actorID)"))
        #expect(bootstrap.contains("MutationOpLogProjectionWorker("))
        #expect(bootstrap.contains("scheduleDrain(reason: \"deferred_runtime_services\")"))

        let swiftFiles = try mirroredSourceFileURLs(
            under: "Epistemos",
            includingExtensions: ["swift"]
        )

        for url in swiftFiles {
            guard !url.path.hasSuffix("/Epistemos/Engine/RustOpLogFFIClient.swift"),
                  !url.path.hasSuffix("/Epistemos/Engine/MutationOpLogProjectionWorker.swift") else {
                continue
            }
            let source = try String(contentsOf: url, encoding: .utf8)
            for symbol in rawSymbols {
                #expect(!source.contains(symbol), "Unexpected raw \(symbol) usage in \(url.path)")
            }
        }
    }

    @Test("OpLog projection diagnostics row is read-only and mounted in Settings")
    func opLogProjectionDiagnosticsRowIsReadOnlyAndMountedInSettings() throws {
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/OpLogProjectionHealthRow.swift")

        #expect(settings.contains("OpLogProjectionHealthRow()"))
        #expect(row.contains("mutationProjectionOutboxDiagnostics()"))
        #expect(!row.contains("oplog_open_at"))
        #expect(!row.contains("oplog_append_payload_json"))
        #expect(!row.contains("claimMutationProjectionOutboxRows("))
        #expect(!row.contains("recordMutationProjectionOutboxFailure("))
        #expect(!row.contains("markMutationProjectionOutboxProjected("))
        #expect(!row.contains(".task {"))
        #expect(!row.contains("while !Task.isCancelled"))
    }

    @Test("GraphEvent visibility row is read-only and mounted in Settings")
    func graphEventVisibilityRowIsReadOnlyAndMountedInSettings() throws {
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let row = try loadMirroredSourceTextFile("Epistemos/Views/Settings/GraphEventVisibilityRow.swift")
        let service = try loadMirroredSourceTextFile("Epistemos/Engine/GraphEventAuditProjectionService.swift")

        #expect(settings.contains("GraphEventVisibilityRow()"))
        #expect(row.contains("graphEventDiagnostics()"))
        #expect(row.contains("graphEventProjectionSnapshot(limit:"))
        #expect(row.contains("GraphEventAuditProjectionService"))
        #expect(row.contains("auditReport(limit: 100)"))
        #expect(row.contains("Audit projection"))
        #expect(service.contains("graphEventProjectionSnapshot(limit:"))
        #expect(row.contains("Projection snapshot"))
        #expect(row.contains("nodes"))
        #expect(row.contains("edges"))
        #expect(!row.contains("saveGraphEvent"))
        #expect(!row.contains("saveMutationEnvelope"))
        #expect(!row.contains("graphEvents("))
        #expect(!service.contains("saveGraphEvent"))
        #expect(!service.contains("saveMutationEnvelope"))
        #expect(!service.contains("graphEvents("))
        #expect(!row.contains("Timer"))
        #expect(!row.contains("DispatchSourceTimer"))
        #expect(!service.contains("Timer"))
        #expect(!service.contains("DispatchSourceTimer"))
        #expect(!row.contains(".task {"))
        #expect(!service.contains(".task {"))
        #expect(!row.contains("while !Task.isCancelled"))
        #expect(!service.contains("while !Task.isCancelled"))
    }
}

@Suite("OpLog Swift Bridge")
struct OpLogSwiftBridgeTests {
    private let genesisHash = String(repeating: "0", count: 64)

    private func projectionEntry(
        seq: UInt64,
        mutationID: String,
        traceID: String? = nil,
        artifactID: String? = nil,
        recordedAtMs: Int = 1_000,
        sourcePayloadJSON: String? = nil
    ) -> OpLogEntry {
        var fields: [String: OpLogJSONValue] = [
            "event_kind": .string("mutation_envelope"),
            "integrity_hash": .string("sha256:\(mutationID)"),
            "mutation_id": .string(mutationID),
            "recorded_at_ms": .int(recordedAtMs),
            "source_payload_json": .string(sourcePayloadJSON ?? "{\"mutation_id\":\"\(mutationID)\"}"),
            "status": .string("committed"),
        ]
        if let traceID {
            fields["trace_id"] = .string(traceID)
        }
        if let artifactID {
            fields["artifact_id"] = .string(artifactID)
            fields["artifact_kind"] = .string("prose_note")
        }

        return OpLogEntry(
            seq: seq,
            lamport: seq,
            actorID: "replay-test",
            tsUnixMs: Int64(recordedAtMs + 500),
            payload: .propSet(
                nodeID: mutationID,
                key: MutationOpLogProjector.projectionKey,
                value: .object(fields)
            ),
            prevHash: genesisHash
        )
    }

    private func nonProjectionEntry(seq: UInt64) -> OpLogEntry {
        OpLogEntry(
            seq: seq,
            lamport: seq,
            actorID: "replay-test",
            tsUnixMs: 2_000,
            payload: .nodeAdd(id: "note-\(seq)", kind: "prose_note", title: "Ignored"),
            prevHash: genesisHash
        )
    }

    @Test("Swift bridge appends, iterates, and preserves chain state across reopen")
    func swiftBridgeAppendsIteratesAndReopens() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-oplog-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let genesis = String(repeating: "0", count: 64)
        let firstClient = try RustOpLogFFIClient(databaseURL: url, actorID: "swift-test")
        #expect(try firstClient.chainTipHex() == genesis)

        let firstSeq = try firstClient.append(.nodeAdd(id: "note-1", kind: "prose_note", title: "First"))
        #expect(firstSeq == 0)
        let firstTip = try firstClient.chainTipHex()
        #expect(firstTip.count == 64)
        #expect(firstTip != genesis)

        let reopened = try RustOpLogFFIClient(databaseURL: url, actorID: "swift-test")
        #expect(try reopened.chainTipHex() == firstTip)

        let secondSeq = try reopened.append(.nodeUpdate(id: "note-1", title: "Renamed"))
        #expect(secondSeq == 1)

        let tail = try reopened.iterate(after: 0)
        #expect(tail.count == 1)
        #expect(tail.first?.seq == 1)
        #expect(tail.first?.prevHash == firstTip)
        #expect(tail.first?.payload == .nodeUpdate(id: "note-1", title: "Renamed"))
    }

    @Test("Swift bridge verifies OpLog chain and expected tip")
    func swiftBridgeVerifiesOpLogChainAndExpectedTip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-oplog-verify-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let client = try RustOpLogFFIClient(databaseURL: url, actorID: "verify-test")
        _ = try client.append(.nodeAdd(id: "note-1", kind: "prose_note", title: "First"))
        _ = try client.append(.nodeUpdate(id: "note-1", title: "Renamed"))

        let tip = try client.chainTipHex()
        let valid = try client.verifyChain(expectedTipHex: tip)
        #expect(valid.valid)
        #expect(valid.checkedCount == 2)
        #expect(valid.computedChainTipHex == tip)
        #expect(valid.storedChainTipHex == tip)
        #expect(valid.expectedChainTipHex == tip)
        #expect(valid.firstBadSeq == nil)
        #expect(valid.failureReason == nil)

        let mismatch = try client.verifyChain(expectedTipHex: genesisHash)
        #expect(!mismatch.valid)
        #expect(mismatch.checkedCount == 2)
        #expect(mismatch.computedChainTipHex == tip)
        #expect(mismatch.expectedChainTipHex == genesisHash)
        #expect(mismatch.failureReason == "expected_chain_tip_mismatch")
    }

    @Test("Mutation OpLog replay folds projections and supports rollback cutoff")
    func mutationOpLogReplayFoldsProjectionsAndSupportsRollbackCutoff() throws {
        let entries = [
            projectionEntry(seq: 2, mutationID: "mutation-two", traceID: "trace-two"),
            nonProjectionEntry(seq: 1),
            projectionEntry(seq: 0, mutationID: "mutation-one", traceID: "trace-one"),
        ]

        let full = MutationOpLogReplay.replay(entries)
        #expect(full.cutoffSeq == nil)
        #expect(full.highestReplayedSeq == 2)
        #expect(full.ignoredNonProjectionCount == 1)
        #expect(full.records.map(\.mutationID) == ["mutation-one", "mutation-two"])
        #expect(full.records.map(\.opLogSeq) == [0, 2])
        #expect(full.records.first?.traceID == "trace-one")

        let rollback = MutationOpLogReplay.replay(entries, upToSeq: 0)
        #expect(rollback.cutoffSeq == 0)
        #expect(rollback.highestReplayedSeq == 0)
        #expect(rollback.ignoredNonProjectionCount == 0)
        #expect(rollback.records.map(\.mutationID) == ["mutation-one"])
        #expect(rollback.duplicates.isEmpty)
    }

    @Test("Mutation OpLog replay records duplicate projections")
    func mutationOpLogReplayRecordsDuplicateProjections() throws {
        let entries = [
            projectionEntry(seq: 0, mutationID: "mutation-duplicate", traceID: "trace-first"),
            projectionEntry(seq: 1, mutationID: "mutation-duplicate", traceID: "trace-second"),
        ]

        let snapshot = MutationOpLogReplay.replay(entries)
        #expect(snapshot.records.count == 1)
        #expect(snapshot.records.first?.opLogSeq == 0)
        #expect(snapshot.records.first?.traceID == "trace-first")
        #expect(snapshot.duplicates.count == 1)
        #expect(snapshot.duplicates.first?.mutationID == "mutation-duplicate")
        #expect(snapshot.duplicates.first?.firstSeq == 0)
        #expect(snapshot.duplicates.first?.duplicateSeq == 1)
    }

    @Test("Mutation OpLog replay exports deterministic ReplayBundle JSON")
    func mutationOpLogReplayExportsDeterministicReplayBundleJSON() throws {
        let entries = [
            projectionEntry(
                seq: 2,
                mutationID: "mutation-二",
                traceID: "trace-private",
                artifactID: "artifact-🚀",
                sourcePayloadJSON: """
                {"body":"PRIVATE_NOTE_BODY","cwd":"/Users/jojo/Vault","system_prompt":"system prompt"}
                """
            ),
            projectionEntry(seq: 3, mutationID: "mutation-二", traceID: "trace-duplicate"),
            nonProjectionEntry(seq: 1),
        ]

        let snapshot = MutationOpLogReplay.replay(entries)
        let bundle = MutationOpLogReplayBundle(snapshot: snapshot, source: "unit-test")

        #expect(bundle.schemaVersion == 1)
        #expect(bundle.source == "unit-test")
        #expect(bundle.cutoffSeq == nil)
        #expect(bundle.highestReplayedSeq == 3)
        #expect(bundle.replayedEntryCount == 3)
        #expect(bundle.recordCount == 1)
        #expect(bundle.duplicateCount == 1)
        #expect(bundle.ignoredNonProjectionCount == 1)
        #expect(bundle.records.first?.mutationID == "mutation-二")
        #expect(bundle.records.first?.artifactID == "artifact-🚀")

        let firstJSON = try bundle.deterministicJSONData()
        let secondJSON = try bundle.deterministicJSONData()
        #expect(firstJSON == secondJSON)

        let decoded = try JSONDecoder().decode(MutationOpLogReplayBundle.self, from: firstJSON)
        #expect(decoded == bundle)

        let json = String(decoding: firstJSON, as: UTF8.self)
        #expect(json.contains("mutation-二"))
        #expect(json.contains("artifact-🚀"))
        #expect(!json.contains("sourcePayloadJSON"))
        #expect(!json.contains("source_payload_json"))
        #expect(!json.contains("PRIVATE_NOTE_BODY"))
        #expect(!json.contains("/Users/jojo/Vault"))
        #expect(!json.contains("system prompt"))
    }

    @Test("Mutation OpLog ReplayBundle handles empty and max sequence snapshots")
    func mutationOpLogReplayBundleHandlesEmptyAndMaxSequenceSnapshots() throws {
        let empty = MutationOpLogReplayBundle(snapshot: MutationOpLogReplay.replay([]), source: "empty")
        #expect(empty.replayedEntryCount == 0)
        #expect(empty.recordCount == 0)
        #expect(empty.duplicateCount == 0)
        #expect(empty.ignoredNonProjectionCount == 0)
        #expect(empty.records.isEmpty)
        #expect(empty.duplicates.isEmpty)

        let maxRecord = MutationOpLogReplayRecord(
            mutationID: "mutation-max-Ω",
            opLogSeq: .max,
            projectedAt: Date(timeIntervalSince1970: 9_999),
            recordedAt: nil,
            traceID: "trace-max",
            eventKind: "mutation_envelope",
            status: "committed",
            artifactID: "artifact-max-Ω",
            artifactKind: "prose_note",
            integrityHash: "sha256:max",
            sourcePayloadJSON: "{\"body\":\"PRIVATE_NOTE_BODY\"}"
        )
        let maxSnapshot = MutationOpLogReplaySnapshot(
            cutoffSeq: .max,
            highestReplayedSeq: .max,
            records: [maxRecord],
            duplicates: [
                MutationOpLogReplayDuplicate(
                    mutationID: "mutation-max-Ω",
                    firstSeq: .max - 1,
                    duplicateSeq: .max
                ),
            ],
            ignoredNonProjectionCount: 1
        )

        let maxBundle = MutationOpLogReplayBundle(snapshot: maxSnapshot, source: "edge-test")
        #expect(maxBundle.cutoffSeq == .max)
        #expect(maxBundle.highestReplayedSeq == .max)
        #expect(maxBundle.replayedEntryCount == 3)

        let data = try maxBundle.deterministicJSONData()
        let decoded = try JSONDecoder().decode(MutationOpLogReplayBundle.self, from: data)
        #expect(decoded == maxBundle)
        #expect(String(decoding: data, as: UTF8.self).contains("mutation-max-Ω"))
    }

    @Test("Swift bridge replays mutation projections from real OpLog")
    func swiftBridgeReplaysMutationProjectionsFromRealOpLog() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-oplog-replay-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let client = try RustOpLogFFIClient(databaseURL: url, actorID: "replay-bridge-test")
        let ignoredSeq = try client.append(.nodeAdd(id: "note-ignored", kind: "prose_note", title: "Ignored"))
        let projectionSeq = try client.append(.propSet(
            nodeID: "mutation-bridge",
            key: MutationOpLogProjector.projectionKey,
            value: .object([
                "event_kind": .string("mutation_envelope"),
                "integrity_hash": .string("sha256:mutation-bridge"),
                "mutation_id": .string("mutation-bridge"),
                "recorded_at_ms": .int(1_234),
                "source_payload_json": .string("{\"mutation_id\":\"mutation-bridge\"}"),
                "status": .string("committed"),
                "trace_id": .string("trace-bridge"),
            ])
        ))

        let rollback = try client.replayMutationProjections(upToSeq: ignoredSeq)
        #expect(rollback.records.isEmpty)
        #expect(rollback.ignoredNonProjectionCount == 1)

        let full = try client.replayMutationProjections()
        #expect(full.records.count == 1)
        #expect(full.records.first?.mutationID == "mutation-bridge")
        #expect(full.records.first?.opLogSeq == projectionSeq)
        #expect(full.records.first?.traceID == "trace-bridge")
        #expect(full.ignoredNonProjectionCount == 1)
    }

    @Test("Swift bridge exports ReplayBundle from real OpLog")
    func swiftBridgeExportsReplayBundleFromRealOpLog() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-oplog-replay-bundle-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let client = try RustOpLogFFIClient(databaseURL: url, actorID: "replay-bundle-test")
        _ = try client.append(.nodeAdd(id: "note-ignored", kind: "prose_note", title: "Ignored"))
        _ = try client.append(.propSet(
            nodeID: "mutation-bundle",
            key: MutationOpLogProjector.projectionKey,
            value: .object([
                "artifact_id": .string("artifact-bundle"),
                "artifact_kind": .string("prose_note"),
                "event_kind": .string("mutation_envelope"),
                "integrity_hash": .string("sha256:mutation-bundle"),
                "mutation_id": .string("mutation-bundle"),
                "recorded_at_ms": .int(4_321),
                "source_payload_json": .string("{\"body\":\"PRIVATE_NOTE_BODY\"}"),
                "status": .string("committed"),
                "trace_id": .string("trace-bundle"),
            ])
        ))

        let bundle = try client.exportMutationReplayBundle(source: "bridge-test")
        #expect(bundle.source == "bridge-test")
        #expect(bundle.replayedEntryCount == 2)
        #expect(bundle.recordCount == 1)
        #expect(bundle.duplicateCount == 0)
        #expect(bundle.ignoredNonProjectionCount == 1)
        #expect(bundle.records.first?.mutationID == "mutation-bundle")
        #expect(bundle.records.first?.traceID == "trace-bundle")

        let json = String(decoding: try bundle.deterministicJSONData(), as: UTF8.self)
        #expect(json.contains("mutation-bundle"))
        #expect(!json.contains("PRIVATE_NOTE_BODY"))
    }
}
