import Foundation
import Testing
@testable import Epistemos

@Suite("Provenance Console source guards")
struct ProvenanceConsoleSourceGuardTests {
    @Test("Provenance Console doctrine lives in fusion and names the four planes")
    func doctrineLivesInFusionAndNamesFourPlanes() throws {
        let doctrine = try loadMirroredSourceTextFile("docs/fusion/PROVENANCE_CONSOLE_DOCTRINE_2026_05_04.md")

        for phrase in [
            "RunEventLog",
            "MutationEnvelope",
            "RetractionPropagated",
            "AgentEvent",
            "GraphEvent",
            "GenUIDispatcher",
            "read-only projection",
            "MAS feature trio",
        ] {
            #expect(doctrine.contains(phrase), "Doctrine must contain \(phrase)")
        }
    }

    @Test("EventStore exposes bounded recent AgentEvent projection reads")
    func eventStoreExposesBoundedRecentAgentEventProjectionReads() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/State/EventStore.swift")
        let projectionReader = try context(
            around: "nonisolated func recentAgentEvents(limit: Int = 100) -> [AgentProvenanceEvent]",
            in: source,
            followingLines: 32
        )

        #expect(projectionReader.contains("Self.agentEventReadLimitMaximum"))
        #expect(projectionReader.contains("ORDER BY occurred_at DESC, sequence DESC, id DESC"))
        #expect(projectionReader.contains("return Array(events.reversed())"))
        assertForbiddenTokensAbsent(
            [
                "saveAgentEvent(",
                "saveMutationEnvelope",
                "saveGraphEvent(",
                "insertGraphEvent",
                "claimMutationProjectionOutboxRows(",
                "markMutationProjectionOutboxProjected(",
                "recordMutationProjectionOutboxFailure(",
                "DispatchSourceTimer",
                "repeatForever",
            ],
            in: projectionReader,
            label: "EventStore.recentAgentEvents"
        )
    }

    @Test("Provenance Console projection is GenUI-first and read-only")
    func projectionIsGenUIFirstAndReadOnly() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/ProvenanceConsoleProjectionService.swift")
        let codepack = try loadMirroredSourceTextFile("docs/research/PLAN_3_PROVENANCE_CODEPACK_2026_06_28.md")

        #expect(source.contains("func snapshot(limit: Int = 40) -> ProvenanceConsoleSnapshot"))
        #expect(source.contains("private static let projectionLimitMaximum = 200"))
        #expect(source.contains("private static let displayValueMaximum = 256"))
        #expect(source.contains("let boundedLimit = Self.boundedProjectionLimit(limit)"))
        #expect(source.contains("eventStore.recentAgentEvents(limit: boundedLimit)"))
        #expect(source.contains("eventStore.recentGraphEvents(limit: boundedLimit)"))
        #expect(source.contains("subscribeRetractionEvents(afterSequence: 0, limit: boundedLimit)"))
        #expect(source.contains("pairs.append((\"tool\", displayValue(tool.toolName)))"))
        #expect(source.contains("pairs.append((\"label\", displayValue(relation.label)))"))
        #expect(source.contains("agent:\\(short(id)) (\\(displayValue(modelID)))"))
        #expect(source.contains("func subscribeRetractionEvents("))
        #expect(source.contains("RetractionPropagatedProjection"))
        #expect(source.contains("GenUIPayload.provenanceTrace("))
        #expect(source.contains("(\"ACS verdict\""))
        #expect(source.contains("ACS verdict column"))
        #expect(codepack.contains("refreshes `ProvenanceConsoleProjectionService.snapshot(limit:)` in a cancellable"))
        assertForbiddenTokensAbsent(
            [
                "saveAgentEvent(",
                "saveMutationEnvelope",
                "saveGraphEvent(",
                "claimMutationProjectionOutboxRows(",
                "markMutationProjectionOutboxProjected(",
                "recordMutationProjectionOutboxFailure(",
                "Button(role: .destructive)",
                "Timer",
                "DispatchSourceTimer",
                "repeatForever",
            ],
            in: source,
            label: "ProvenanceConsoleProjectionService"
        )
    }

    @Test("Provenance Console clamps projection limits at the service boundary")
    func projectionLimitsAreClampedAtServiceBoundary() {
        let service = ProvenanceConsoleProjectionService(
            eventStoreProvider: { nil },
            retractionEventProvider: { _, limit in
                (0..<(limit + 25)).map { index in
                    RetractionPropagatedProjection(
                        sequence: UInt64(index),
                        triggerKind: "claim",
                        triggeredBy: "claim-\(index)",
                        claimsMarkedAtRisk: 1,
                        maxDepthReached: 1,
                        depthCapped: false
                    )
                }
            }
        )

        #expect(service.subscribeRetractionEvents(limit: 10_000).count == 200)
        #expect(service.subscribeRetractionEvents(limit: -10).isEmpty)
        #expect(service.subscribeRetractionEvents(limit: 3).map(\.sequence) == [0, 1, 2])
    }

    @Test("Provenance Console bounds untrusted display strings")
    func projectionBoundsUntrustedDisplayStrings() throws {
        let store = try makeStore()
        let longModelID = String(repeating: "m", count: 400)
        let longToolName = String(repeating: "t", count: 400)
        let longRelationLabel = String(repeating: "r", count: 400)

        let event = AgentProvenanceEvent(
            eventID: "provenance-console-long-agent-\(UUID().uuidString)",
            runID: "provenance-console-long-run",
            sequence: 1,
            kind: .toolCallCompleted,
            actor: .agent(id: "agent-long-display", modelID: longModelID),
            occurredAtMs: 1_000,
            tool: AgentToolProvenance(
                toolCallID: "tool-long-display",
                toolName: longToolName,
                argumentsJSON: "{}",
                resultJSON: "{}",
                durationMs: 1,
                approvalID: nil,
                status: .completed
            )
        )
        let graphEvent = DurableGraphEvent(
            eventID: "provenance-console-long-graph-\(UUID().uuidString)",
            mutationID: "provenance-console-long-mutation",
            sequence: 1,
            kind: .edgeCreated,
            occurredAtMs: 1_000,
            relation: DurableGraphEventRelation(
                fromID: "source-node-for-long-relation",
                toID: "target-node-for-long-relation",
                label: longRelationLabel
            )
        )

        #expect(store.saveAgentEvent(event))
        #expect(store.saveGraphEvent(graphEvent))

        let snapshot = ProvenanceConsoleProjectionService(eventStoreProvider: { store }).snapshot(limit: 10)
        let agentRows = try keyValueRows(in: firstTraceEvent(in: snapshot.agentPayload))
        let graphRows = try keyValueRows(in: firstTraceEvent(in: snapshot.graphPayload))

        #expect(agentRows["tool"] == String(longToolName.prefix(256)))
        #expect(graphRows["label"] == String(longRelationLabel.prefix(256)))
        #expect(agentRows["actor"] == "agent:\(String("agent-long-display".prefix(12))) (\(String(longModelID.prefix(256))))")
    }

    @Test("Settings mounts a read-only Provenance Console routed through GenUIDispatcher")
    func settingsMountsReadOnlyProvenanceConsole() throws {
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        let view = try loadMirroredSourceTextFile("Epistemos/Views/Settings/ProvenanceConsoleView.swift")
        let dispatcher = try loadMirroredSourceTextFile("Epistemos/Engine/GenUIDispatcher.swift")

        #expect(settings.contains("case provenance = \"Provenance Console\""))
        #expect(settings.contains("case .provenance: ProvenanceConsoleView()"))
        #expect(view.contains("_snapshot = State(initialValue: .empty)"))
        #expect(view.contains("Task.detached(priority: .utility)"))
        #expect(view.contains("service.snapshot(limit: 40)"))
        #expect(view.contains(".onDisappear { cancelRefresh() }"))
        #expect(view.contains("GenUIDispatcher.shared.render(payload)"))
        #expect(view.contains(".onAppear { refresh() }"))
        #expect(dispatcher.contains("ProvenanceTraceGenUIView(payload: payload)"))
        assertForbiddenTokensAbsent(
            [
                "Button(role: .destructive)",
                "saveAgentEvent(",
                "saveMutationEnvelope",
                "saveGraphEvent(",
                "claimMutationProjectionOutboxRows(",
                "markMutationProjectionOutboxProjected(",
                "recordMutationProjectionOutboxFailure(",
                "Timer",
                "DispatchSourceTimer",
                "repeatForever",
            ],
            in: view,
            label: "ProvenanceConsoleView"
        )
    }

    private func context(
        around marker: String,
        in source: String,
        followingLines: Int
    ) throws -> String {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.firstIndex(where: { $0.contains(marker) }) else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSDebugDescriptionErrorKey: "Missing marker: \(marker)"])
        }
        let end = min(lines.count, start + followingLines + 1)
        return lines[start..<end].joined(separator: "\n")
    }

    private func assertForbiddenTokensAbsent(
        _ tokens: [String],
        in source: String,
        label: String
    ) {
        for token in tokens {
            #expect(!source.contains(token), "\(label) must not contain \(token)")
        }
    }

    private func makeStore() throws -> EventStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("provenance-console-\(UUID().uuidString).sqlite")
        return try #require(EventStore(databaseURL: url))
    }

    private func firstTraceEvent(in payload: GenUIPayload) throws -> GenUIPayload {
        guard case .provenanceChain(let events) = payload.body,
              let first = events.first else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSDebugDescriptionErrorKey: "Missing provenance event payload"])
        }
        return first
    }

    private func keyValueRows(in payload: GenUIPayload) throws -> [String: String] {
        guard case .keyValues(let rows) = payload.body else {
            throw CocoaError(.fileReadUnknown, userInfo: [NSDebugDescriptionErrorKey: "Missing key-value payload"])
        }
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.key, $0.value) })
    }
}
