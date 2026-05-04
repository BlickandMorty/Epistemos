import Foundation

struct ProvenanceConsoleSnapshot: Sendable, Equatable {
    let summaryPayload: GenUIPayload
    let agentPayload: GenUIPayload
    let graphPayload: GenUIPayload
    let outboxPayload: GenUIPayload

    var payloads: [GenUIPayload] {
        [summaryPayload, agentPayload, graphPayload, outboxPayload]
    }

    static let empty = ProvenanceConsoleSnapshot(
        summaryPayload: .keyValueTable(title: "Provenance Console", [
            ("status", "EventStore unavailable"),
            ("mode", "read-only")
        ]),
        agentPayload: .provenanceTrace(title: "AgentEvent", events: []),
        graphPayload: .provenanceTrace(title: "GraphEvent", events: []),
        outboxPayload: .keyValueTable(title: "MutationEnvelope projection", [
            ("status", "unavailable")
        ])
    )
}

struct ProvenanceConsoleProjectionService: Sendable {
    typealias EventStoreProvider = @Sendable () -> EventStore?

    private let eventStoreProvider: EventStoreProvider

    init(eventStoreProvider: @escaping EventStoreProvider = { EventStore.shared }) {
        self.eventStoreProvider = eventStoreProvider
    }

    func snapshot(limit: Int = 40) -> ProvenanceConsoleSnapshot {
        guard let eventStore = eventStoreProvider() else {
            return .empty
        }

        let agentDiagnostics = eventStore.agentEventDiagnostics()
        let graphDiagnostics = eventStore.graphEventDiagnostics()
        let outboxDiagnostics = eventStore.mutationProjectionOutboxDiagnostics()
        let agentEvents = eventStore.recentAgentEvents(limit: limit)
        let graphEvents = eventStore.recentGraphEvents(limit: limit)

        return ProvenanceConsoleSnapshot(
            summaryPayload: Self.summaryPayload(
                agentDiagnostics: agentDiagnostics,
                graphDiagnostics: graphDiagnostics,
                outboxDiagnostics: outboxDiagnostics
            ),
            agentPayload: GenUIPayload.provenanceTrace(
                title: "AgentEvent",
                events: agentEvents.map(Self.agentEventPayload),
                metadata: ["plane": "AgentEvent"]
            ),
            graphPayload: GenUIPayload.provenanceTrace(
                title: "GraphEvent",
                events: graphEvents.map(Self.graphEventPayload),
                metadata: ["plane": "GraphEvent"]
            ),
            outboxPayload: Self.outboxPayload(outboxDiagnostics)
        )
    }

    private static func summaryPayload(
        agentDiagnostics: EventStore.AgentEventDiagnostics,
        graphDiagnostics: EventStore.GraphEventDiagnostics,
        outboxDiagnostics: EventStore.MutationProjectionOutboxDiagnostics
    ) -> GenUIPayload {
        .keyValueTable(title: "Provenance Console", [
            ("mode", "read-only projection"),
            ("RunEventLog", "source event history"),
            ("MutationEnvelope", "\(outboxDiagnostics.totalRows) projection rows"),
            ("AgentEvent", "\(agentDiagnostics.totalRows) events across \(agentDiagnostics.distinctRuns) runs"),
            ("GraphEvent", "\(graphDiagnostics.totalRows) events across \(graphDiagnostics.distinctMutations) mutations")
        ])
    }

    private static func outboxPayload(
        _ diagnostics: EventStore.MutationProjectionOutboxDiagnostics
    ) -> GenUIPayload {
        .keyValueTable(title: "MutationEnvelope projection", [
            ("total", "\(diagnostics.totalRows)"),
            ("pending", "\(diagnostics.pendingRows)"),
            ("leased", "\(diagnostics.leasedRows)"),
            ("projected", "\(diagnostics.projectedRows)"),
            ("dead-lettered", "\(diagnostics.deadLetteredRows)"),
            ("latest dead letter", diagnostics.latestDeadLetter?.mutationID ?? "none")
        ])
    }

    private static func agentEventPayload(_ event: AgentProvenanceEvent) -> GenUIPayload {
        var pairs: [(String, String)] = [
            ("kind", event.kind.rawValue),
            ("event", short(event.eventID)),
            ("run", short(event.runID)),
            ("sequence", "\(event.sequence)"),
            ("actor", actorLabel(event.actor)),
            ("occurred", "\(event.occurredAtMs)ms")
        ]
        if let traceID = event.traceID, !traceID.isEmpty {
            pairs.append(("trace", short(traceID)))
        }
        if let tool = event.tool {
            pairs.append(("tool", tool.toolName))
            pairs.append(("tool status", tool.status.rawValue))
        }
        return .keyValueTable(title: event.kind.rawValue, pairs)
    }

    private static func graphEventPayload(_ event: DurableGraphEvent) -> GenUIPayload {
        var pairs: [(String, String)] = [
            ("kind", event.kind.rawValue),
            ("event", short(event.eventID)),
            ("mutation", short(event.mutationID)),
            ("sequence", "\(event.sequence)"),
            ("occurred", "\(event.occurredAtMs)ms")
        ]
        if let runID = event.runID, !runID.isEmpty {
            pairs.append(("run", short(runID)))
        }
        if let traceID = event.traceID, !traceID.isEmpty {
            pairs.append(("trace", short(traceID)))
        }
        if let entityID = event.entityID, !entityID.isEmpty {
            pairs.append(("entity", short(entityID)))
        }
        if let relation = event.relation {
            pairs.append(("relation", "\(short(relation.fromID)) -> \(short(relation.toID))"))
            pairs.append(("label", relation.label))
        }
        return .keyValueTable(title: event.kind.rawValue, pairs)
    }

    private static func actorLabel(_ actor: AgentProvenanceActor) -> String {
        switch actor {
        case .user:
            return "user"
        case .agent(let id, let modelID):
            guard let modelID, !modelID.isEmpty else {
                return "agent:\(short(id))"
            }
            return "agent:\(short(id)) (\(modelID))"
        case .system:
            return "system"
        }
    }

    private static func short(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 12 else { return trimmed.isEmpty ? "unknown" : trimmed }
        return String(trimmed.prefix(12))
    }
}
