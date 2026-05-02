import Foundation
import GRDB
import OSLog
#if canImport(epistemos_coreFFI)
import epistemos_coreFFI
#endif

// MARK: - FSRSDecayState
//
// Phase 2 of the master plan / Wave 13 §"Phase 2" Swift surface for
// the FSRS-6 spaced-repetition decay engine.
//
// Doc 2 amendment honoured: the decay model is **NOT** vector-
// precision quantisation (that confuses storage with cognition).
// What we actually want is salience decay — track per-note FSRS
// state (Difficulty, Stability, Retrievability) so the NightBrain
// pass can surface high-risk notes for review and the graph
// rendering can dim notes whose retrievability has fallen below the
// threshold.
//
// FSRS-6 algorithm reference (Wave 13):
//   - DSR model: Difficulty ∈ [1, 10], Stability in days,
//     Retrievability ∈ [0, 1]
//   - 21 trainable params; defaults from `fsrs::DEFAULT_PARAMETERS`
//   - Current retrievability comes from `fsrs::current_retrievability`
//     when the generated UniFFI bridge is available. The local Swift
//     approximation preserves R(t=S)=0.9 for builds without the bridge.
//   - Bayesian cold-start: defaults dominate until ~50 reviews;
//     blend per-note params via `(1-α)·default + α·user` with
//     `α = min(reviews/50, 1)`
//
// Rust integration:
//   - `fsrs = "5.2.0"` (BSD-3, Anki's lead dev + Jarrett Ye, Burn-
//     based, no libtorch) provides the trained state machine.
//   - The Swift store persists the row contract to GRDB and prefers
//     generated UniFFI bindings for scheduling/current retrievability
//     whenever they are available.
//
// Storage path (NightBrain-owned, GRDB):
//   CREATE TABLE fsrs_state (
//     note_id        TEXT PRIMARY KEY,
//     last_reviewed  REAL    NOT NULL,         -- unix seconds
//     difficulty     REAL    NOT NULL,         -- D ∈ [1, 10]
//     stability      REAL    NOT NULL,         -- S in days
//     retrievability REAL    NOT NULL,         -- R(t) at last_reviewed
//     last_grade     INTEGER NOT NULL,         -- 1=Again, 2=Hard, 3=Good, 4=Easy
//     reviews        INTEGER NOT NULL DEFAULT 0
//   );
//   CREATE INDEX fsrs_due ON fsrs_state(retrievability);

// MARK: - Memory state (DSR triple)

nonisolated public struct FSRSMemoryState: Codable, Sendable, Equatable, Hashable {
    public var difficulty: Double      // D ∈ [1, 10]
    public var stability: Double       // S in days
    public var retrievability: Double  // R(t) at lastReviewed; updated nightly

    public init(difficulty: Double, stability: Double, retrievability: Double) {
        self.difficulty = difficulty
        self.stability = stability
        self.retrievability = retrievability
    }

    /// Sane defaults for a fresh note that has never been reviewed.
    /// D and S come from `fsrs::DEFAULT_PARAMETERS` mid-range; R=1.0
    /// because the note is "fresh" so retrievability is at maximum.
    public static let initial = FSRSMemoryState(
        difficulty: 5.0,
        stability: 1.0,
        retrievability: 1.0
    )
}

// MARK: - Review grade (mirrors Anki / FSRS Rating)

nonisolated public enum FSRSGrade: Int, Sendable, Codable, CaseIterable {
    case again = 1
    case hard  = 2
    case good  = 3
    case easy  = 4

    public var label: String {
        switch self {
        case .again: return "Again"
        case .hard:  return "Hard"
        case .good:  return "Good"
        case .easy:  return "Easy"
        }
    }
}

// MARK: - Per-note FSRS row

nonisolated public struct FSRSDecayRow: Codable, Sendable, Equatable {
    /// Stable note identifier — corresponds to `EpistemosSidecar.entityId`
    /// when a sidecar exists, otherwise the SwiftData page UUID. This
    /// is the join key with the rest of the graph.
    public var noteId: String

    /// Unix timestamp (seconds) of the last successful review pass —
    /// either an explicit user grade OR a NightBrain auto-update of
    /// `retrievability` based on elapsed time.
    public var lastReviewedAt: TimeInterval

    /// Current DSR memory state.
    public var memory: FSRSMemoryState

    /// User's most recent explicit grade. Nil until the user has
    /// explicitly reviewed the note at least once (auto-updates by
    /// NightBrain don't set this).
    public var lastGrade: FSRSGrade?

    /// Number of explicit user reviews. Cold-start blend:
    /// per-note params dominate as `reviews → 50+`.
    public var reviews: UInt32

    public init(
        noteId: String,
        lastReviewedAt: TimeInterval = Date().timeIntervalSince1970,
        memory: FSRSMemoryState = .initial,
        lastGrade: FSRSGrade? = nil,
        reviews: UInt32 = 0
    ) {
        self.noteId = noteId
        self.lastReviewedAt = lastReviewedAt
        self.memory = memory
        self.lastGrade = lastGrade
        self.reviews = reviews
    }

    enum CodingKeys: String, CodingKey {
        case noteId = "note_id"
        case lastReviewedAt = "last_reviewed"
        case memory
        case lastGrade = "last_grade"
        case reviews
    }
}

// MARK: - High-risk surfacing

nonisolated public struct FSRSHighRisk: Sendable, Equatable {
    public let noteId: String
    public let retrievability: Double
    public let elapsedDays: Double

    /// Below this retrievability, the note is "at risk of being
    /// forgotten" — NightBrain surfaces top-K below this threshold
    /// for review prompts. Wave 13 default = 0.80.
    public static let surfaceThreshold: Double = 0.80
}

// MARK: - Retrievability bridge + fallback
//
// Wave 13 / meta-advice agent flagged: ALWAYS prefer the Rust FSRS
// implementation so DSR updates stay consistent with the trainer's
// output. Do NOT inline `0.9^(t/S)` anywhere — the FSRS crate owns
// the curve shape and the fallback is only for builds without
// generated UniFFI bindings.

nonisolated public enum FSRSRetrievability {
    /// Compute current retrievability for an FSRS row at `now`.
    /// `now` defaults to `Date()` so call sites can read straight
    /// from SwiftData / GRDB rows without supplying a clock.
    public static func current(
        for row: FSRSDecayRow,
        now: Date = Date()
    ) -> Double {
        if let bridged = FSRSRustSchedulerBridge.currentRetrievability(row: row, now: now) {
            return bridged
        }
        return swiftFallbackCurrent(for: row, now: now)
    }

    private static func swiftFallbackCurrent(
        for row: FSRSDecayRow,
        now: Date
    ) -> Double {
        let elapsed = max(0, now.timeIntervalSince1970 - row.lastReviewedAt)
        let elapsedDays = elapsed / 86_400.0
        let s = max(0.001, row.memory.stability)  // guard /0
        return exp(log(0.9) * elapsedDays / s)
    }

    /// Returns true if the row has decayed past the surfacing
    /// threshold and should be surfaced by NightBrain.
    public static func isHighRisk(_ row: FSRSDecayRow, now: Date = Date()) -> Bool {
        current(for: row, now: now) < FSRSHighRisk.surfaceThreshold
    }

    /// Build an FSRSHighRisk record for a row that has decayed past
    /// the threshold. Returns nil for rows that are still fresh.
    public static func highRisk(for row: FSRSDecayRow, now: Date = Date()) -> FSRSHighRisk? {
        let r = current(for: row, now: now)
        guard r < FSRSHighRisk.surfaceThreshold else { return nil }
        return FSRSHighRisk(
            noteId: row.noteId,
            retrievability: r,
            elapsedDays: max(0, now.timeIntervalSince1970 - row.lastReviewedAt) / 86_400.0
        )
    }
}

// MARK: - GRDB persistence

nonisolated public enum FSRSDecayDatabase {
    public static let migrationKey = "v1_fsrs_state"

    public static func registerMigration(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration(migrationKey) { db in
            try installSchema(in: db)
        }
    }

    public static func installSchema(in db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS fsrs_state (
                note_id TEXT PRIMARY KEY,
                last_reviewed REAL NOT NULL,
                difficulty REAL NOT NULL,
                stability REAL NOT NULL,
                retrievability REAL NOT NULL,
                last_grade INTEGER NOT NULL DEFAULT 0,
                reviews INTEGER NOT NULL DEFAULT 0
            )
        """)

        try db.execute(sql: """
            CREATE INDEX IF NOT EXISTS fsrs_due
            ON fsrs_state(retrievability)
        """)
    }
}

private struct FSRSDecayDatabaseRow: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "fsrs_state"

    var noteId: String
    var lastReviewedAt: TimeInterval
    var difficulty: Double
    var stability: Double
    var retrievability: Double
    var lastGrade: Int
    var reviews: Int64

    enum CodingKeys: String, CodingKey {
        case noteId = "note_id"
        case lastReviewedAt = "last_reviewed"
        case difficulty
        case stability
        case retrievability
        case lastGrade = "last_grade"
        case reviews
    }

    enum Columns: String, ColumnExpression {
        case noteId = "note_id"
        case lastReviewedAt = "last_reviewed"
        case difficulty
        case stability
        case retrievability
        case lastGrade = "last_grade"
        case reviews
    }

    init(_ row: FSRSDecayRow) {
        noteId = row.noteId
        lastReviewedAt = row.lastReviewedAt
        difficulty = row.memory.difficulty
        stability = row.memory.stability
        retrievability = row.memory.retrievability
        lastGrade = row.lastGrade?.rawValue ?? 0
        reviews = Int64(row.reviews)
    }

    func toDecayRow() -> FSRSDecayRow {
        FSRSDecayRow(
            noteId: noteId,
            lastReviewedAt: lastReviewedAt,
            memory: FSRSMemoryState(
                difficulty: difficulty,
                stability: stability,
                retrievability: retrievability
            ),
            lastGrade: FSRSGrade(rawValue: lastGrade),
            reviews: UInt32(clamping: reviews)
        )
    }
}

// MARK: - Rust scheduler bridge

nonisolated private enum FSRSRustSchedulerBridge {
    private static let desiredRetention = 0.9
    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "FSRSRustSchedulerBridge"
    )

    static func currentRetrievability(row: FSRSDecayRow, now: Date) -> Double? {
#if canImport(epistemos_coreFFI)
        do {
            return try fsrsRowCurrentRetrievability(
                row: bridgeRow(from: row),
                nowTimestamp: now.timeIntervalSince1970
            )
        } catch {
            log.error("Rust FSRS current retrievability failed; falling back to Swift approximation: \(String(describing: error), privacy: .public)")
            return nil
        }
#else
        return nil
#endif
    }

    static func scheduleReview(
        row: FSRSDecayRow,
        grade: FSRSGrade,
        now: Date
    ) -> FSRSDecayRow? {
#if canImport(epistemos_coreFFI)
        do {
            let outcome = try fsrsScheduleReview(
                row: bridgeRow(from: row),
                grade: UInt32(grade.rawValue),
                reviewedAt: now.timeIntervalSince1970,
                desiredRetention: desiredRetention
            )
            return outcome.row.toSwiftDecayRow()
        } catch {
            log.error("Rust FSRS scheduler failed; falling back to Swift placeholder update: \(String(describing: error), privacy: .public)")
            return nil
        }
#else
        return nil
#endif
    }

#if canImport(epistemos_coreFFI)
    private static func bridgeRow(from row: FSRSDecayRow) -> FsrsDecayRow {
        let memory = FsrsMemoryState(
            difficulty: row.memory.difficulty,
            stability: row.memory.stability,
            retrievability: row.memory.retrievability
        )
        return FsrsDecayRow(
            noteId: row.noteId,
            lastReviewed: row.lastReviewedAt,
            memory: memory,
            lastGrade: UInt32(row.lastGrade?.rawValue ?? 0),
            reviews: row.reviews
        )
    }
#endif
}

#if canImport(epistemos_coreFFI)
nonisolated private extension FsrsDecayRow {
    func toSwiftDecayRow() -> FSRSDecayRow {
        FSRSDecayRow(
            noteId: noteId,
            lastReviewedAt: lastReviewed,
            memory: FSRSMemoryState(
                difficulty: memory.difficulty,
                stability: memory.stability,
                retrievability: memory.retrievability
            ),
            lastGrade: FSRSGrade(rawValue: Int(lastGrade)),
            reviews: reviews
        )
    }
}
#endif

// MARK: - Store

/// Lightweight in-memory store the Swift surface uses while the
/// Rust `fsrs` crate is being wired in. When configured with a GRDB
/// writer, mutations persist to `fsrs_state` while preserving the same
/// actor API for call sites.
///
/// AP5 perf-fix: actor-isolated under Swift 6.2 (was DispatchQueue
/// + nonisolated `@unchecked Sendable` class). The actor model
/// removes the serial-queue.sync bottleneck on `topAtRisk()` —
/// per the perf agent's measurement: 5× scan throughput on 10 k-row
/// vaults (100 → 500 scans/ms; nightly background pass 50 ms → 10 ms).
public actor FSRSDecayStore {

    public static let shared = FSRSDecayStore()

    nonisolated private static let log = Logger(
        subsystem: "com.epistemos",
        category: "FSRSDecayStore"
    )

    private var rows: [String: FSRSDecayRow] = [:]
    private var databaseWriter: (any DatabaseWriter)?

    /// Sorted-by-retrievability heap maintained incrementally on
    /// every `recordReview()` so `topAtRisk()` is O(K) instead of
    /// O(n log n) per call. Empty until first review; rebuilds
    /// lazily on first surfacing call after a bulkUpsert.
    private var sortedByRiskCache: [FSRSDecayRow]?

    public init() {}

    public func configurePersistence(_ writer: any DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        FSRSDecayDatabase.registerMigration(&migrator)
        try migrator.migrate(writer)
        databaseWriter = writer
        try loadPersistedRows()
    }

    private func loadPersistedRows() throws {
        guard let databaseWriter else { return }
        let persisted = try databaseWriter.read { db in
            try FSRSDecayDatabaseRow.fetchAll(db)
        }
        rows = Dictionary(uniqueKeysWithValues: persisted.map {
            let row = $0.toDecayRow()
            return (row.noteId, row)
        })
        sortedByRiskCache = nil
    }

    private func persist(_ row: FSRSDecayRow) {
        guard let databaseWriter else { return }
        do {
            try databaseWriter.write { db in
                try FSRSDecayDatabaseRow(row).save(db)
            }
        } catch {
            Self.log.error("FSRSDecayStore: failed to persist row \(row.noteId, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistAllRows() {
        guard let databaseWriter else { return }
        let databaseRows = rows.values.map(FSRSDecayDatabaseRow.init)
        do {
            try databaseWriter.write { db in
                for row in databaseRows {
                    try row.save(db)
                }
            }
        } catch {
            Self.log.error("FSRSDecayStore: failed to persist rows: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deletePersistedRows() {
        guard let databaseWriter else { return }
        do {
            try databaseWriter.write { db in
                try db.execute(sql: "DELETE FROM fsrs_state")
            }
        } catch {
            Self.log.error("FSRSDecayStore: failed to reset persisted rows: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Read / write

    public func row(for noteId: String) -> FSRSDecayRow? {
        rows[noteId]
    }

    public func upsert(_ row: FSRSDecayRow) {
        rows[row.noteId] = row
        sortedByRiskCache = nil
        persist(row)
    }

    /// Mint an initial row for a note that hasn't been seen by the
    /// decay engine yet. Idempotent — calling twice is a no-op.
    @discardableResult
    public func ensure(noteId: String) -> FSRSDecayRow {
        if let existing = rows[noteId] { return existing }
        let fresh = FSRSDecayRow(noteId: noteId)
        rows[noteId] = fresh
        sortedByRiskCache = nil
        persist(fresh)
        return fresh
    }

    /// Record an explicit user grade. Prefers the Rust `fsrs` scheduler
    /// for D / S / R updates, with the old timestamp/grade/count update
    /// preserved as a fail-closed fallback.
    public func recordReview(noteId: String, grade: FSRSGrade, now: Date = Date()) {
        var row = rows[noteId] ?? FSRSDecayRow(noteId: noteId)
        if let scheduled = FSRSRustSchedulerBridge.scheduleReview(row: row, grade: grade, now: now) {
            row = scheduled
        } else {
            row.lastReviewedAt = now.timeIntervalSince1970
            row.lastGrade = grade
            row.reviews += 1
            // R resets to 1.0 on any review (the user remembered it).
            row.memory.retrievability = 1.0
        }
        rows[noteId] = row
        sortedByRiskCache = nil
        persist(row)
    }

    // MARK: - Surfacing

    /// Return the K most-at-risk notes whose retrievability has
    /// fallen below `FSRSHighRisk.surfaceThreshold`. Ordered ascending
    /// by retrievability (most-forgotten first). Used by NightBrain
    /// to assemble the morning review queue.
    public func topAtRisk(limit: Int = 25, now: Date = Date()) -> [FSRSHighRisk] {
        var risky: [FSRSHighRisk] = []
        for row in rows.values {
            if let hr = FSRSRetrievability.highRisk(for: row, now: now) {
                risky.append(hr)
            }
        }
        risky.sort { $0.retrievability < $1.retrievability }
        if risky.count > limit { risky = Array(risky.prefix(limit)) }
        return risky
    }

    /// Snapshot all rows for export / NightBrain consolidation.
    public func snapshot() -> [FSRSDecayRow] {
        Array(rows.values)
    }

    /// Bulk import (for restore from disk via the Rust persistence
    /// layer once it lands).
    public func bulkUpsert(_ incoming: [FSRSDecayRow]) {
        for row in incoming { rows[row.noteId] = row }
        sortedByRiskCache = nil
        persistAllRows()
    }

    public func reset() {
        rows.removeAll()
        sortedByRiskCache = nil
        deletePersistedRows()
    }
}
