import Foundation

struct ProvenanceConsoleSnapshot: Sendable, Equatable {
    let summaryPayload: GenUIPayload
    let retractionPayload: GenUIPayload
    let agentPayload: GenUIPayload
    let graphPayload: GenUIPayload
    let outboxPayload: GenUIPayload
    /// V2 Lane 1 (2026-05-05): Rust provenance surface. The live authority is
    /// the Cognitive DAG projection; the legacy ClaimLedger bridge is rendered
    /// only as compatibility context so we don't create a second source of truth.
    let rustLedgerPayload: GenUIPayload

    var payloads: [GenUIPayload] {
        [
            summaryPayload,
            rustLedgerPayload,
            retractionPayload,
            agentPayload,
            graphPayload,
            outboxPayload,
        ]
    }

    static let empty = ProvenanceConsoleSnapshot(
        summaryPayload: .keyValueTable(title: "Provenance Console", [
            ("status", "EventStore unavailable"),
            ("mode", "read-only")
        ]),
        retractionPayload: .provenanceTrace(title: "RetractionPropagated", events: []),
        agentPayload: .provenanceTrace(title: "AgentEvent", events: []),
        graphPayload: .provenanceTrace(title: "GraphEvent", events: []),
        outboxPayload: .keyValueTable(title: "MutationEnvelope projection", [
            ("status", "unavailable")
        ]),
        rustLedgerPayload: .keyValueTable(title: "Cognitive DAG Provenance (Rust)", [
            ("status", "FFI unavailable"),
            ("mode", "read-only")
        ])
    )
}

struct RetractionPropagatedProjection: Sendable, Equatable {
    let sequence: UInt64
    let triggerKind: String
    let triggeredBy: String
    let claimsMarkedAtRisk: Int
    let maxDepthReached: Int
    let depthCapped: Bool
}

struct ProvenanceConsoleProjectionService: Sendable {
    typealias EventStoreProvider = @Sendable () -> EventStore?
    typealias RetractionEventProvider = @Sendable (_ afterSequence: UInt64, _ limit: Int) -> [RetractionPropagatedProjection]

    private let eventStoreProvider: EventStoreProvider
    private let retractionEventProvider: RetractionEventProvider

    init(
        eventStoreProvider: @escaping EventStoreProvider = { EventStore.shared },
        retractionEventProvider: @escaping RetractionEventProvider = { _, _ in [] }
    ) {
        self.eventStoreProvider = eventStoreProvider
        self.retractionEventProvider = retractionEventProvider
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
        let retractionEvents = subscribeRetractionEvents(afterSequence: 0, limit: limit)
        let rustLedgerSummary = RustProvenanceLedgerClient.summary()
        let cognitiveDagStats = RustCognitiveDagClient.stats()

        return ProvenanceConsoleSnapshot(
            summaryPayload: Self.summaryPayload(
                agentDiagnostics: agentDiagnostics,
                graphDiagnostics: graphDiagnostics,
                outboxDiagnostics: outboxDiagnostics,
                retractionEventCount: retractionEvents.count,
                rustLedger: rustLedgerSummary,
                cognitiveDag: cognitiveDagStats
            ),
            retractionPayload: GenUIPayload.provenanceTrace(
                title: "RetractionPropagated",
                events: retractionEvents.map(Self.retractionEventPayload),
                metadata: ["plane": "ClaimLedger"]
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
            outboxPayload: Self.outboxPayload(outboxDiagnostics),
            rustLedgerPayload: Self.rustLedgerPayload(
                rustLedgerSummary,
                cognitiveDag: cognitiveDagStats
            )
        )
    }

    func subscribeRetractionEvents(
        afterSequence: UInt64 = 0,
        limit: Int = 40
    ) -> [RetractionPropagatedProjection] {
        let boundedLimit = max(0, min(limit, 200))
        guard boundedLimit > 0 else { return [] }
        return Array(retractionEventProvider(afterSequence, boundedLimit).prefix(boundedLimit))
    }

    private static func summaryPayload(
        agentDiagnostics: EventStore.AgentEventDiagnostics,
        graphDiagnostics: EventStore.GraphEventDiagnostics,
        outboxDiagnostics: EventStore.MutationProjectionOutboxDiagnostics,
        retractionEventCount: Int,
        rustLedger: RustProvenanceLedgerSummary,
        cognitiveDag: RustCognitiveDagStats
    ) -> GenUIPayload {
        .keyValueTable(title: "Provenance Console", [
            ("mode", "read-only projection"),
            ("RunEventLog", "source event history"),
            ("MutationEnvelope", "\(outboxDiagnostics.totalRows) projection rows"),
            ("ClaimLedger (Swift)", "\(retractionEventCount) RetractionPropagated events"),
            ("Cognitive DAG (Rust)", cognitiveDagSummary(cognitiveDag)),
            ("Legacy ClaimLedger bridge", "\(rustLedger.claimCount) claims, \(rustLedger.evidenceCount) evidence, \(rustLedger.eventCount) events"),
            ("AgentEvent", "\(agentDiagnostics.totalRows) events across \(agentDiagnostics.distinctRuns) runs"),
            ("GraphEvent", "\(graphDiagnostics.totalRows) events across \(graphDiagnostics.distinctMutations) mutations")
        ])
    }

    private static func rustLedgerPayload(
        _ summary: RustProvenanceLedgerSummary,
        cognitiveDag: RustCognitiveDagStats
    ) -> GenUIPayload {
        .keyValueTable(title: "Cognitive DAG Provenance (Rust)", [
            ("source", "agent_core::cognitive_dag::dispatch::cognitive_dag_store"),
            ("mode", "read-only DAG-authoritative projection"),
            ("nodes", "\(cognitiveDag.nodeCount)"),
            ("edges", "\(cognitiveDag.edgeCount)"),
            ("schema", "\(cognitiveDag.schemaVersion)"),
            ("root", shortRoot(cognitiveDag.merkleRootHex)),
            ("legacy bridge", "\(summary.claimCount) claims, \(summary.evidenceCount) evidence, \(summary.eventCount) events"),
        ])
    }

    private static func cognitiveDagSummary(_ stats: RustCognitiveDagStats) -> String {
        if stats.isEmpty {
            return "empty (waiting for mirror writes)"
        }
        return "\(stats.nodeCount) nodes, \(stats.edgeCount) edges, root \(shortRoot(stats.merkleRootHex))"
    }

    private static func shortRoot(_ root: String) -> String {
        let prefix = root.prefix(12)
        return prefix.isEmpty ? "none" : String(prefix)
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

    private static func retractionEventPayload(_ event: RetractionPropagatedProjection) -> GenUIPayload {
        .keyValueTable(title: "RetractionPropagated #\(event.sequence)", [
            ("sequence", "\(event.sequence)"),
            ("trigger kind", event.triggerKind),
            ("trigger", short(event.triggeredBy)),
            ("claims at risk", "\(event.claimsMarkedAtRisk)"),
            ("max depth", "\(event.maxDepthReached)"),
            ("depth capped", event.depthCapped ? "true" : "false")
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
        appendMissionPacketFields(from: event.metadata, to: &pairs)
        appendAnswerPacketFields(from: event.metadata, to: &pairs)
        return .keyValueTable(title: event.kind.rawValue, pairs)
    }

    private static func appendMissionPacketFields(
        from metadata: [String: String],
        to pairs: inout [(String, String)]
    ) {
        guard let packetID = nonEmpty(metadata["mission_packet_id"]) else {
            return
        }

        pairs.append(("mission packet", packetID))
        if let blueprintName = nonEmpty(metadata["agent_blueprint_name"]) {
            pairs.append(("blueprint", blueprintName))
        }
        if let model = nonEmpty(metadata["agent_blueprint_model"]) ?? nonEmpty(metadata["model"]) {
            pairs.append(("blueprint model", model))
        }
        if let scope = nonEmpty(metadata["agent_blueprint_scope"]) {
            pairs.append(("blueprint scope", scope))
        }
        if let approvalMode = nonEmpty(metadata["agent_blueprint_approval_mode"]) {
            pairs.append(("approval mode", approvalMode))
        }
        if let tools = nonEmpty(metadata["agent_blueprint_tools"]) {
            pairs.append(("blueprint tools", tools))
        }
    }

    private static func appendAnswerPacketFields(
        from metadata: [String: String],
        to pairs: inout [(String, String)]
    ) {
        guard let packetID = nonEmpty(metadata["answer_packet_id"]) else {
            return
        }

        pairs.append(("answer packet", packetID))
        if let uiLabel = nonEmpty(metadata["answer_packet_ui_label"]) {
            pairs.append(("VRM label", uiLabel))
        }
        if let attentionMode = nonEmpty(metadata["answer_packet_attention_mode"]) {
            pairs.append(("attention mode", attentionMode))
        }
        if let interruptBucket = nonEmpty(metadata["answer_packet_interrupt_bucket"]) {
            pairs.append(("interrupt bucket", interruptBucket))
        }
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

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
