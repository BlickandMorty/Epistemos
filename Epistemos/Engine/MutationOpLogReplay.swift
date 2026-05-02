import Foundation

nonisolated struct MutationOpLogReplayRecord: Equatable, Sendable {
    let mutationID: String
    let opLogSeq: UInt64
    let projectedAt: Date
    let recordedAt: Date?
    let traceID: String?
    let eventKind: String?
    let status: String?
    let artifactID: String?
    let artifactKind: String?
    let integrityHash: String?
    let sourcePayloadJSON: String?
}

nonisolated struct MutationOpLogReplayDuplicate: Equatable, Sendable {
    let mutationID: String
    let firstSeq: UInt64
    let duplicateSeq: UInt64
}

nonisolated struct MutationOpLogReplaySnapshot: Equatable, Sendable {
    let cutoffSeq: UInt64?
    let highestReplayedSeq: UInt64?
    let records: [MutationOpLogReplayRecord]
    let duplicates: [MutationOpLogReplayDuplicate]
    let ignoredNonProjectionCount: Int

    var recordsByMutationID: [String: MutationOpLogReplayRecord] {
        Dictionary(uniqueKeysWithValues: records.map { ($0.mutationID, $0) })
    }
}

nonisolated enum MutationOpLogReplay {
    static func replay(
        _ entries: [OpLogEntry],
        upToSeq cutoffSeq: UInt64? = nil
    ) -> MutationOpLogReplaySnapshot {
        let sortedEntries = entries.sorted { lhs, rhs in
            if lhs.seq == rhs.seq {
                return lhs.lamport < rhs.lamport
            }
            return lhs.seq < rhs.seq
        }

        var records: [MutationOpLogReplayRecord] = []
        var recordsByMutationID: [String: Int] = [:]
        var duplicates: [MutationOpLogReplayDuplicate] = []
        var ignoredNonProjectionCount = 0
        var highestReplayedSeq: UInt64?

        for entry in sortedEntries {
            if let cutoffSeq, entry.seq > cutoffSeq {
                continue
            }
            highestReplayedSeq = entry.seq

            guard let record = record(from: entry) else {
                ignoredNonProjectionCount += 1
                continue
            }

            if let firstRecordIndex = recordsByMutationID[record.mutationID] {
                duplicates.append(MutationOpLogReplayDuplicate(
                    mutationID: record.mutationID,
                    firstSeq: records[firstRecordIndex].opLogSeq,
                    duplicateSeq: record.opLogSeq
                ))
                continue
            }

            recordsByMutationID[record.mutationID] = records.count
            records.append(record)
        }

        return MutationOpLogReplaySnapshot(
            cutoffSeq: cutoffSeq,
            highestReplayedSeq: highestReplayedSeq,
            records: records,
            duplicates: duplicates,
            ignoredNonProjectionCount: ignoredNonProjectionCount
        )
    }

    private static func record(from entry: OpLogEntry) -> MutationOpLogReplayRecord? {
        guard case .propSet(let nodeID, let key, let value) = entry.payload,
              key == MutationOpLogProjector.projectionKey,
              case .object(let fields) = value else {
            return nil
        }

        let mutationID = fields["mutation_id"]?.stringValue ?? nodeID
        guard !mutationID.isEmpty else { return nil }

        return MutationOpLogReplayRecord(
            mutationID: mutationID,
            opLogSeq: entry.seq,
            projectedAt: date(fromUnixMilliseconds: entry.tsUnixMs),
            recordedAt: fields["recorded_at_ms"]?.millisecondsValue.map(date(fromUnixMilliseconds:)),
            traceID: fields["trace_id"]?.stringValue,
            eventKind: fields["event_kind"]?.stringValue,
            status: fields["status"]?.stringValue,
            artifactID: fields["artifact_id"]?.stringValue,
            artifactKind: fields["artifact_kind"]?.stringValue,
            integrityHash: fields["integrity_hash"]?.stringValue,
            sourcePayloadJSON: fields["source_payload_json"]?.stringValue
        )
    }

    private static func date(fromUnixMilliseconds milliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1_000)
    }
}

extension RustOpLogFFIClient {
    nonisolated func replayMutationProjections(upToSeq cutoffSeq: UInt64? = nil) throws -> MutationOpLogReplaySnapshot {
        try MutationOpLogReplay.replay(iterateAll(), upToSeq: cutoffSeq)
    }
}

private extension OpLogJSONValue {
    nonisolated var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    nonisolated var millisecondsValue: Int64? {
        switch self {
        case .int(let value):
            return Int64(value)
        case .double(let value):
            guard value.isFinite,
                  value >= Double(Int64.min),
                  value <= Double(Int64.max) else {
                return nil
            }
            return Int64(value.rounded())
        default:
            return nil
        }
    }
}
