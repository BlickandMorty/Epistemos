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

nonisolated struct MutationOpLogReplayBundle: Codable, Equatable, Sendable {
    nonisolated struct Record: Codable, Equatable, Sendable {
        let mutationID: String
        let opLogSeq: UInt64
        let projectedAtMs: Int64
        let recordedAtMs: Int64?
        let traceID: String?
        let eventKind: String?
        let status: String?
        let artifactID: String?
        let artifactKind: String?
        let integrityHash: String?

        init(_ record: MutationOpLogReplayRecord) {
            mutationID = record.mutationID
            opLogSeq = record.opLogSeq
            projectedAtMs = Self.unixMilliseconds(from: record.projectedAt)
            recordedAtMs = record.recordedAt.map(Self.unixMilliseconds(from:))
            traceID = record.traceID
            eventKind = record.eventKind
            status = record.status
            artifactID = record.artifactID
            artifactKind = record.artifactKind
            integrityHash = record.integrityHash
        }

        private static func unixMilliseconds(from date: Date) -> Int64 {
            let milliseconds = date.timeIntervalSince1970 * 1_000
            guard milliseconds.isFinite else { return 0 }
            if milliseconds >= Double(Int64.max) { return Int64.max }
            if milliseconds <= Double(Int64.min) { return Int64.min }
            return Int64(milliseconds.rounded())
        }
    }

    nonisolated struct Duplicate: Codable, Equatable, Sendable {
        let mutationID: String
        let firstSeq: UInt64
        let duplicateSeq: UInt64

        init(_ duplicate: MutationOpLogReplayDuplicate) {
            mutationID = duplicate.mutationID
            firstSeq = duplicate.firstSeq
            duplicateSeq = duplicate.duplicateSeq
        }
    }

    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let source: String
    let cutoffSeq: UInt64?
    let highestReplayedSeq: UInt64?
    let replayedEntryCount: Int
    let recordCount: Int
    let duplicateCount: Int
    let ignoredNonProjectionCount: Int
    let records: [Record]
    let duplicates: [Duplicate]

    init(
        snapshot: MutationOpLogReplaySnapshot,
        source: String = "mutation-oplog-replay",
        schemaVersion: Int = Self.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.source = source
        cutoffSeq = snapshot.cutoffSeq
        highestReplayedSeq = snapshot.highestReplayedSeq
        replayedEntryCount = snapshot.records.count
            + snapshot.duplicates.count
            + snapshot.ignoredNonProjectionCount
        recordCount = snapshot.records.count
        duplicateCount = snapshot.duplicates.count
        ignoredNonProjectionCount = snapshot.ignoredNonProjectionCount
        records = snapshot.records.map(Record.init)
        duplicates = snapshot.duplicates.map(Duplicate.init)
    }

    func deterministicJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

nonisolated struct MutationOpLogReplayBundleVisibilityReport: Equatable, Sendable {
    nonisolated enum Status: String, Equatable, Sendable {
        case unavailable
        case empty
        case available
    }

    let status: Status
    let source: String
    let highestReplayedSeq: UInt64?
    let replayedEntryCount: Int
    let recordCount: Int
    let duplicateCount: Int
    let ignoredNonProjectionCount: Int
    let latestMutationID: String?

    var isEmpty: Bool {
        status == .empty || replayedEntryCount == 0
    }

    static let empty = MutationOpLogReplayBundleVisibilityReport(
        status: .empty,
        source: "settings-visibility",
        highestReplayedSeq: nil,
        replayedEntryCount: 0,
        recordCount: 0,
        duplicateCount: 0,
        ignoredNonProjectionCount: 0,
        latestMutationID: nil
    )

    static let unavailable = MutationOpLogReplayBundleVisibilityReport(
        status: .unavailable,
        source: "settings-visibility",
        highestReplayedSeq: nil,
        replayedEntryCount: 0,
        recordCount: 0,
        duplicateCount: 0,
        ignoredNonProjectionCount: 0,
        latestMutationID: nil
    )

    init(bundle: MutationOpLogReplayBundle) {
        let latestRecord = bundle.records.max { lhs, rhs in
            lhs.opLogSeq < rhs.opLogSeq
        }
        status = bundle.replayedEntryCount == 0 ? .empty : .available
        source = bundle.source
        highestReplayedSeq = bundle.highestReplayedSeq
        replayedEntryCount = bundle.replayedEntryCount
        recordCount = bundle.recordCount
        duplicateCount = bundle.duplicateCount
        ignoredNonProjectionCount = bundle.ignoredNonProjectionCount
        latestMutationID = latestRecord?.mutationID
    }

    private init(
        status: Status,
        source: String,
        highestReplayedSeq: UInt64?,
        replayedEntryCount: Int,
        recordCount: Int,
        duplicateCount: Int,
        ignoredNonProjectionCount: Int,
        latestMutationID: String?
    ) {
        self.status = status
        self.source = source
        self.highestReplayedSeq = highestReplayedSeq
        self.replayedEntryCount = replayedEntryCount
        self.recordCount = recordCount
        self.duplicateCount = duplicateCount
        self.ignoredNonProjectionCount = ignoredNonProjectionCount
        self.latestMutationID = latestMutationID
    }

    static func load(
        databaseURL: URL = MutationOpLogProjectionWorker.databaseURL(
            applicationSupportDirectory: FoundationSafety.userApplicationSupportDirectory()
        ),
        actorID: String = "oplog-replay-bundle-visibility"
    ) -> MutationOpLogReplayBundleVisibilityReport {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return .empty
        }

        do {
            let client = try RustOpLogFFIClient(databaseURL: databaseURL, actorID: actorID)
            return try MutationOpLogReplayBundleVisibilityReport(
                bundle: client.exportMutationReplayBundle(source: "settings-visibility")
            )
        } catch {
            return .unavailable
        }
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

    static func applyIncremental(
        snapshot: MutationOpLogReplaySnapshot,
        newEntries: [OpLogEntry],
        upToSeq cutoffSeq: UInt64? = nil
    ) -> MutationOpLogReplaySnapshot {
        if let priorCutoff = snapshot.cutoffSeq,
           let cutoffSeq,
           cutoffSeq < priorCutoff {
            preconditionFailure("incremental replay cannot lower an existing cutoff")
        }

        let effectiveCutoff = cutoffSeq ?? snapshot.cutoffSeq
        let sortedEntries = newEntries.sorted { lhs, rhs in
            if lhs.seq == rhs.seq {
                return lhs.lamport < rhs.lamport
            }
            return lhs.seq < rhs.seq
        }

        var records = snapshot.records
        var recordsByMutationID: [String: Int] = [:]
        for (index, record) in records.enumerated() where recordsByMutationID[record.mutationID] == nil {
            recordsByMutationID[record.mutationID] = index
        }
        var duplicates = snapshot.duplicates
        var ignoredNonProjectionCount = snapshot.ignoredNonProjectionCount
        var highestReplayedSeq = snapshot.highestReplayedSeq

        for entry in sortedEntries {
            if let effectiveCutoff, entry.seq > effectiveCutoff {
                continue
            }

            if let highestReplayedSeq, entry.seq <= highestReplayedSeq {
                // OpLog sequence numbers are unique; same-seq tail rows are stale overlap.
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
            cutoffSeq: effectiveCutoff,
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

    nonisolated func incrementalReplayMutationProjections(
        from snapshot: MutationOpLogReplaySnapshot,
        upToSeq cutoffSeq: UInt64? = nil
    ) throws -> MutationOpLogReplaySnapshot {
        let entries: [OpLogEntry]
        if let highestReplayedSeq = snapshot.highestReplayedSeq {
            entries = try iterate(after: highestReplayedSeq)
        } else {
            entries = try iterateAll()
        }
        return MutationOpLogReplay.applyIncremental(
            snapshot: snapshot,
            newEntries: entries,
            upToSeq: cutoffSeq
        )
    }

    nonisolated func exportMutationReplayBundle(
        upToSeq cutoffSeq: UInt64? = nil,
        source: String = "rust-oplog-ffi"
    ) throws -> MutationOpLogReplayBundle {
        try MutationOpLogReplayBundle(
            snapshot: replayMutationProjections(upToSeq: cutoffSeq),
            source: source
        )
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
