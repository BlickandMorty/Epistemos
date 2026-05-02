import Foundation

nonisolated struct MutationOpLogProjectionResult: Equatable, Sendable {
    var scanned: Int
    var appended: Int
    var alreadyProjected: Int
    var marked: Int

    static let empty = MutationOpLogProjectionResult(
        scanned: 0,
        appended: 0,
        alreadyProjected: 0,
        marked: 0
    )
}

nonisolated enum MutationOpLogProjectorError: Error, Equatable {
    case markFailed(mutationID: String, opLogSeq: UInt64)
}

/// Projects committed EventStore mutation-envelope outbox rows into the
/// append-only Rust OpLog. EventStore remains the source of truth; this
/// bridge only records an idempotent projection pointer for replay.
nonisolated final class MutationOpLogProjector: @unchecked Sendable {
    static let projectionKey = "mutation_projection"

    private struct ProjectedMutation: Sendable {
        let seq: UInt64
        let projectedAt: Date
    }

    private let eventStore: EventStore
    private let opLog: RustOpLogFFIClient
    private let workerID: String
    private let leaseDuration: TimeInterval
    private let retryDelay: TimeInterval
    private let maxAttempts: Int?

    init(
        eventStore: EventStore,
        opLog: RustOpLogFFIClient,
        workerID: String = "mutation-oplog-projector",
        leaseDuration: TimeInterval = 30,
        retryDelay: TimeInterval = 60,
        maxAttempts: Int? = 5
    ) {
        self.eventStore = eventStore
        self.opLog = opLog
        self.workerID = workerID
        self.leaseDuration = leaseDuration
        self.retryDelay = retryDelay
        self.maxAttempts = maxAttempts.flatMap { $0 > 0 && $0 <= Int(Int32.max) ? $0 : nil }
    }

    func projectPending(limit: Int = 100) throws -> MutationOpLogProjectionResult {
        let rows = eventStore.claimMutationProjectionOutboxRows(
            limit: limit,
            ownerID: workerID,
            leaseDuration: leaseDuration
        )
        guard !rows.isEmpty else { return .empty }

        var result = MutationOpLogProjectionResult(
            scanned: rows.count,
            appended: 0,
            alreadyProjected: 0,
            marked: 0
        )
        var projectedMutations = try indexedProjectedMutations()

        for row in rows {
            do {
                if let existing = projectedMutations[row.mutationID] {
                    try mark(row, projectedMutation: existing)
                    result.alreadyProjected += 1
                    result.marked += 1
                    continue
                }

                let seq = try opLog.append(Self.payload(for: row))
                let projectedMutation = ProjectedMutation(seq: seq, projectedAt: Date())
                projectedMutations[row.mutationID] = projectedMutation
                try mark(row, projectedMutation: projectedMutation)
                result.appended += 1
                result.marked += 1
            } catch {
                eventStore.recordMutationProjectionOutboxFailure(
                    mutationID: row.mutationID,
                    ownerID: workerID,
                    error: String(describing: error),
                    retryAfter: retryDelay,
                    maxAttempts: maxAttempts
                )
                throw error
            }
        }

        return result
    }

    private func indexedProjectedMutations() throws -> [String: ProjectedMutation] {
        var indexed: [String: ProjectedMutation] = [:]
        for entry in try opLog.iterateAll() {
            guard let mutationID = entry.payload.projectionMutationID,
                  indexed[mutationID] == nil else {
                continue
            }
            indexed[mutationID] = ProjectedMutation(
                seq: entry.seq,
                projectedAt: Self.dateFromUnixMilliseconds(entry.tsUnixMs)
            )
        }
        return indexed
    }

    private func mark(
        _ row: EventStore.MutationProjectionOutboxRow,
        projectedMutation: ProjectedMutation
    ) throws {
        guard eventStore.markMutationProjectionOutboxProjected(
            mutationID: row.mutationID,
            opLogSeq: projectedMutation.seq,
            projectedAt: projectedMutation.projectedAt,
            ownerID: workerID
        ) else {
            throw MutationOpLogProjectorError.markFailed(
                mutationID: row.mutationID,
                opLogSeq: projectedMutation.seq
            )
        }
    }

    static func payload(for row: EventStore.MutationProjectionOutboxRow) -> OpLogPayload {
        var fields: [String: OpLogJSONValue] = [
            "event_kind": .string(row.eventKind),
            "integrity_hash": .string(row.integrityHash),
            "mutation_id": .string(row.mutationID),
            "recorded_at_ms": unixMilliseconds(row.recordedAt),
            "source_payload_json": .string(row.payload),
            "status": .string(row.status),
        ]
        if let traceID = row.traceID {
            fields["trace_id"] = .string(traceID)
        }
        if let artifactID = row.artifactID {
            fields["artifact_id"] = .string(artifactID)
        }
        if let artifactKind = row.artifactKind {
            fields["artifact_kind"] = .string(artifactKind)
        }

        return .propSet(
            nodeID: row.mutationID,
            key: projectionKey,
            value: .object(fields)
        )
    }

    private static func unixMilliseconds(_ date: Date) -> OpLogJSONValue {
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite else { return .int(0) }
        if milliseconds >= Double(Int.max) {
            return .int(Int.max)
        }
        if milliseconds <= Double(Int.min) {
            return .int(Int.min)
        }
        return .int(Int(milliseconds.rounded()))
    }

    private static func dateFromUnixMilliseconds(_ milliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1_000)
    }
}
