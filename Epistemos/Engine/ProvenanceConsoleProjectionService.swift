import Foundation

nonisolated struct ProvenanceConsoleSnapshot: Sendable, Equatable {
    let summaryPayload: GenUIPayload
    let retractionPayload: GenUIPayload
    let editSupersessionPayload: GenUIPayload
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
            editSupersessionPayload,
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
        editSupersessionPayload: .provenanceTrace(title: "AgentEditSuperseded", events: []),
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

nonisolated struct RetractionPropagatedProjection: Sendable, Equatable {
    let sequence: UInt64
    let triggerKind: String
    let triggeredBy: String
    let claimsMarkedAtRisk: Int
    let maxDepthReached: Int
    let depthCapped: Bool
}

nonisolated struct AgentEditSupersessionProjection: Sendable, Equatable {
    let artifactID: String
    let artifactTitle: String?
    let supersededMutationID: String
    let supersededByMutationID: String
    let runID: String?
    let sequence: UInt64
    let createdAtMs: Int64
}

nonisolated struct ProvenanceConsoleProjectionService: Sendable {
    typealias EventStoreProvider = @Sendable () -> EventStore?
    typealias RetractionEventProvider = @Sendable (_ afterSequence: UInt64, _ limit: Int) -> [RetractionPropagatedProjection]

    private static let projectionLimitMaximum = 200
    private static let displayValueMaximum = 256

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

        let boundedLimit = Self.boundedProjectionLimit(limit)
        let agentDiagnostics = eventStore.agentEventDiagnostics()
        let graphDiagnostics = eventStore.graphEventDiagnostics()
        let outboxDiagnostics = eventStore.mutationProjectionOutboxDiagnostics()
        let agentEvents = eventStore.recentAgentEvents(limit: boundedLimit)
        let graphEvents = eventStore.recentGraphEvents(limit: boundedLimit)
        let editSupersessions = Self.editSupersessionProjections(
            from: eventStore.recentMutationEnvelopes(limit: boundedLimit),
            limit: boundedLimit
        )
        let retractionEvents = subscribeRetractionEvents(afterSequence: 0, limit: boundedLimit)
        let rustLedgerSummary = RustProvenanceLedgerClient.summary()
        let cognitiveDagStats = RustCognitiveDagClient.stats()

        return ProvenanceConsoleSnapshot(
            summaryPayload: Self.summaryPayload(
                agentDiagnostics: agentDiagnostics,
                graphDiagnostics: graphDiagnostics,
                outboxDiagnostics: outboxDiagnostics,
                retractionEventCount: retractionEvents.count,
                editSupersessionCount: editSupersessions.count,
                rustLedger: rustLedgerSummary,
                cognitiveDag: cognitiveDagStats
            ),
            retractionPayload: GenUIPayload.provenanceTrace(
                title: "RetractionPropagated",
                events: retractionEvents.map(Self.retractionEventPayload),
                metadata: ["plane": "ClaimLedger"]
            ),
            editSupersessionPayload: GenUIPayload.provenanceTrace(
                title: "AgentEditSuperseded",
                events: editSupersessions.map(Self.editSupersessionEventPayload),
                metadata: ["plane": "MutationEnvelope"]
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
        let boundedLimit = Self.boundedProjectionLimit(limit)
        guard boundedLimit > 0 else { return [] }
        return Array(retractionEventProvider(afterSequence, boundedLimit).prefix(boundedLimit))
    }

    private static func boundedProjectionLimit(_ limit: Int) -> Int {
        max(0, min(limit, projectionLimitMaximum))
    }

    private static func summaryPayload(
        agentDiagnostics: EventStore.AgentEventDiagnostics,
        graphDiagnostics: EventStore.GraphEventDiagnostics,
        outboxDiagnostics: EventStore.MutationProjectionOutboxDiagnostics,
        retractionEventCount: Int,
        editSupersessionCount: Int,
        rustLedger: RustProvenanceLedgerSummary,
        cognitiveDag: RustCognitiveDagStats
    ) -> GenUIPayload {
        .keyValueTable(title: "Provenance Console", [
            ("mode", "read-only projection"),
            ("RunEventLog", "source event history"),
            ("MutationEnvelope", "\(outboxDiagnostics.totalRows) projection rows"),
            ("ClaimLedger (Swift)", "\(retractionEventCount) RetractionPropagated events"),
            ("Agent edit supersession", "\(editSupersessionCount) superseded edits"),
            ("Cognitive DAG (Rust)", cognitiveDagSummary(cognitiveDag)),
            ("Legacy ClaimLedger bridge", "\(rustLedger.claimCount) claims, \(rustLedger.evidenceCount) evidence, \(rustLedger.eventCount) events"),
            ("ACS verdict column", "visible; not linked until entries carry ACS record ids"),
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
        let trimmed = sanitizedDisplayValue(root, prefixLimit: 44)
        let prefix = String(trimmed.prefix(12)).trimmingCharacters(in: .whitespacesAndNewlines)
        return prefix.isEmpty ? "none" : prefix
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

    private static func editSupersessionProjections(
        from envelopes: [MutationEnvelope],
        limit: Int
    ) -> [AgentEditSupersessionProjection] {
        let boundedLimit = boundedProjectionLimit(limit)
        guard boundedLimit > 0 else { return [] }

        let agentEdits = envelopes.compactMap { envelope -> (artifact: EpdocArtifactRef, envelope: MutationEnvelope)? in
            guard envelope.status == .committed,
                  case .agent = envelope.actor,
                  case .artifactUpdate(let artifactID) = envelope.op,
                  let artifact = envelope.touchedArtifacts.first(where: { $0.id == artifactID }) else {
                return nil
            }
            return (artifact, envelope)
        }

        let grouped = Dictionary(grouping: agentEdits, by: { $0.artifact.id })
        let projections = grouped.values.flatMap { edits -> [AgentEditSupersessionProjection] in
            let ordered = edits.sorted { lhs, rhs in
                let lhsCommitted = lhs.envelope.committedAtMs ?? lhs.envelope.createdAtMs
                let rhsCommitted = rhs.envelope.committedAtMs ?? rhs.envelope.createdAtMs
                if lhsCommitted != rhsCommitted { return lhsCommitted < rhsCommitted }
                if lhs.envelope.sequence != rhs.envelope.sequence {
                    return lhs.envelope.sequence < rhs.envelope.sequence
                }
                return lhs.envelope.mutationID < rhs.envelope.mutationID
            }
            guard ordered.count > 1 else { return [] }
            return zip(ordered, ordered.dropFirst()).map { previous, next in
                AgentEditSupersessionProjection(
                    artifactID: next.artifact.id,
                    artifactTitle: next.artifact.title ?? previous.artifact.title,
                    supersededMutationID: previous.envelope.mutationID,
                    supersededByMutationID: next.envelope.mutationID,
                    runID: next.envelope.runID,
                    sequence: next.envelope.sequence,
                    createdAtMs: next.envelope.committedAtMs ?? next.envelope.createdAtMs
                )
            }
        }

        return Array(projections.sorted { lhs, rhs in
            if lhs.createdAtMs != rhs.createdAtMs { return lhs.createdAtMs < rhs.createdAtMs }
            if lhs.sequence != rhs.sequence { return lhs.sequence < rhs.sequence }
            return lhs.supersededByMutationID < rhs.supersededByMutationID
        }.suffix(boundedLimit))
    }

    private static func retractionEventPayload(_ event: RetractionPropagatedProjection) -> GenUIPayload {
        .keyValueTable(title: "RetractionPropagated #\(event.sequence)", [
            ("sequence", "\(event.sequence)"),
            ("trigger kind", displayValue(event.triggerKind)),
            ("trigger", short(event.triggeredBy)),
            ("ACS verdict", acsVerdictUnlinked()),
            ("claims at risk", "\(event.claimsMarkedAtRisk)"),
            ("max depth", "\(event.maxDepthReached)"),
            ("depth capped", event.depthCapped ? "true" : "false")
        ])
    }

    private static func editSupersessionEventPayload(_ event: AgentEditSupersessionProjection) -> GenUIPayload {
        .keyValueTable(title: "AgentEditSuperseded #\(event.sequence)", [
            ("artifact", displayValue(event.artifactTitle ?? event.artifactID)),
            ("artifact id", short(event.artifactID)),
            ("superseded", short(event.supersededMutationID)),
            ("superseded by", short(event.supersededByMutationID)),
            ("run", short(event.runID ?? "unknown")),
            ("occurred", "\(event.createdAtMs)ms"),
            ("mode", "EventStore-derived; no ClaimLedger write FFI")
        ])
    }

    private static func agentEventPayload(_ event: AgentProvenanceEvent) -> GenUIPayload {
        var pairs: [(String, String)] = [
            ("kind", event.kind.rawValue),
            ("event", short(event.eventID)),
            ("run", short(event.runID)),
            ("sequence", "\(event.sequence)"),
            ("actor", actorLabel(event.actor)),
            ("ACS verdict", acsVerdictUnlinked()),
            ("occurred", "\(event.occurredAtMs)ms")
        ]
        if let traceID = event.traceID, !traceID.isEmpty {
            pairs.append(("trace", short(traceID)))
        }
        if let tool = event.tool {
            pairs.append(("tool", displayValue(tool.toolName)))
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
            ("ACS verdict", acsVerdictUnlinked()),
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
            pairs.append(("label", displayValue(relation.label)))
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
            return "agent:\(short(id)) (\(displayValue(modelID)))"
        case .system:
            return "system"
        }
    }

    private static func displayValue(_ value: String) -> String {
        let trimmed = sanitizedDisplayValue(value, prefixLimit: displayValueMaximum + 32)
        guard !trimmed.isEmpty else { return "unknown" }
        guard trimmed.count > displayValueMaximum else { return trimmed }
        return String(trimmed.prefix(displayValueMaximum)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func short(_ value: String) -> String {
        let trimmed = sanitizedDisplayValue(value, prefixLimit: 44)
        guard trimmed.count > 12 else { return trimmed.isEmpty ? "unknown" : trimmed }
        let shortened = String(trimmed.prefix(12)).trimmingCharacters(in: .whitespacesAndNewlines)
        return shortened.isEmpty ? "unknown" : shortened
    }

    private static func sanitizedDisplayValue(_ value: String, prefixLimit: Int) -> String {
        let bounded = String(value.prefix(prefixLimit))
        var sanitized = ""
        sanitized.reserveCapacity(bounded.count)
        var previousWasSeparator = false

        for scalar in bounded.unicodeScalars {
            let isSeparator = CharacterSet.whitespacesAndNewlines.contains(scalar)
                || CharacterSet.controlCharacters.contains(scalar)
            if isSeparator {
                if !previousWasSeparator {
                    sanitized.append(" ")
                    previousWasSeparator = true
                }
            } else {
                sanitized.unicodeScalars.append(scalar)
                previousWasSeparator = false
            }
        }

        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func acsVerdictUnlinked() -> String {
        "not linked (no ACS record id)"
    }
}
