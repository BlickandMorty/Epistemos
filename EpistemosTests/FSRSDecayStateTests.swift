import Foundation
import GRDB
import Testing

@testable import Epistemos

@Suite("FSRSDecayState (Phase 2)")
nonisolated struct FSRSDecayStateTests {

    @Test("Fresh row has retrievability ≈ 1.0 at t=0")
    func freshRetrievability() {
        let row = FSRSDecayRow(noteId: "note-1")
        let r = FSRSRetrievability.current(for: row, now: Date(timeIntervalSince1970: row.lastReviewedAt))
        #expect(r > 0.999, "fresh note should have R ≈ 1.0")
    }

    @Test("Retrievability reaches 0.9 at the stability horizon")
    func decayMatchesFSRSFormula() {
        let row = FSRSDecayRow(
            noteId: "note-2",
            lastReviewedAt: 0,
            memory: FSRSMemoryState(difficulty: 5.0, stability: 5.0, retrievability: 1.0)
        )
        // t = stability (5 days) -> R should equal 0.9 for both the
        // FSRS-6 Rust curve and the local Swift fallback.
        let after5days = Date(timeIntervalSince1970: 5 * 86_400)
        let r = FSRSRetrievability.current(for: row, now: after5days)
        #expect(abs(r - 0.9) < 0.001,
                "R(t=S) MUST equal 0.9 — got \(r)")
    }

    @Test("Current retrievability uses Rust FSRS curve when bridge is available")
    func currentRetrievabilityUsesRustCurveWhenAvailable() {
        let row = FSRSDecayRow(
            noteId: "note-rust-current",
            lastReviewedAt: 0,
            memory: FSRSMemoryState(difficulty: 5.0, stability: 10.0, retrievability: 1.0)
        )
        let day30 = Date(timeIntervalSince1970: 30 * 86_400)
        let current = FSRSRetrievability.current(for: row, now: day30)
        let swiftFallback = exp(log(0.9) * 3.0)

#if canImport(epistemos_coreFFI)
        let fsrsV6DefaultDecay = -0.1542
        let factor = pow(0.9, 1.0 / fsrsV6DefaultDecay) - 1.0
        let expectedRust = pow(1.0 + factor * 3.0, fsrsV6DefaultDecay)
        #expect(abs(current - expectedRust) < 0.001)
        #expect(abs(current - swiftFallback) > 0.02)
#else
        #expect(abs(current - swiftFallback) < 0.001)
#endif
    }

    @Test("isHighRisk returns true once R drops below 0.80")
    func highRiskThreshold() {
        let row = FSRSDecayRow(
            noteId: "note-3",
            lastReviewedAt: 0,
            memory: FSRSMemoryState(difficulty: 5.0, stability: 5.0, retrievability: 1.0)
        )
        // Day 10 stays above the 0.80 threshold under both the FSRS-6
        // Rust curve and the Swift fallback. Day 17 is below threshold
        // under both implementations.
        let day10 = Date(timeIntervalSince1970: 10 * 86_400)
        let day17 = Date(timeIntervalSince1970: 17 * 86_400)
        #expect(!FSRSRetrievability.isHighRisk(row, now: day10),
                "R(10d) is above the 0.80 threshold")
        #expect(FSRSRetrievability.isHighRisk(row, now: day17),
                "R(17d) is below the 0.80 threshold")
    }

    @Test("Store ensure(noteId:) is idempotent — second call returns same row")
    func storeEnsureIdempotent() async {
        let store = FSRSDecayStore.shared
        await store.reset()
        let r1 = await store.ensure(noteId: "idem-1")
        let r2 = await store.ensure(noteId: "idem-1")
        #expect(r1 == r2)
        await store.reset()
    }

    @Test("recordReview bumps reviews + resets R to 1.0 + sets lastGrade")
    func recordReviewSemantics() async {
        let store = FSRSDecayStore.shared
        await store.reset()
        await store.ensure(noteId: "rev-1")
        let now = Date()
        await store.recordReview(noteId: "rev-1", grade: .good, now: now)
        let row = await store.row(for: "rev-1")
        #expect(row?.reviews == 1)
        #expect(row?.lastGrade == .good)
        #expect(row?.memory.retrievability == 1.0,
                "review resets R to 1.0 (the user remembered it)")
        #expect(abs((row?.lastReviewedAt ?? 0) - now.timeIntervalSince1970) < 1.0)
        await store.reset()
    }

    @Test("recordReview uses Rust scheduler memory update when bridge is available")
    func recordReviewUsesRustSchedulerWhenAvailable() async {
        let store = FSRSDecayStore()
        let now = Date(timeIntervalSince1970: 789)
        await store.recordReview(noteId: "rust-scheduled", grade: .good, now: now)

        let row = await store.row(for: "rust-scheduled")
        #expect(row?.reviews == 1)
        #expect(row?.lastGrade == .good)
        #expect(row?.lastReviewedAt == 789)
        #expect(row?.memory.retrievability == 1.0)
#if canImport(epistemos_coreFFI)
        #expect(row?.memory.stability != FSRSMemoryState.initial.stability)
#endif
    }

    @Test("topAtRisk returns notes ordered ascending by R")
    func topAtRiskOrdering() async {
        let store = FSRSDecayStore.shared
        await store.reset()
        // Three notes with stabilities such that 30 days from lastReviewed
        // keeps low-risk above threshold and orders the two below-threshold
        // rows the same under both the Rust FSRS curve and Swift fallback.
        await store.upsert(FSRSDecayRow(
            noteId: "low-risk",
            lastReviewedAt: 0,
            memory: FSRSMemoryState(difficulty: 5, stability: 15, retrievability: 1.0)
        ))
        await store.upsert(FSRSDecayRow(
            noteId: "mid-risk",
            lastReviewedAt: 0,
            memory: FSRSMemoryState(difficulty: 5, stability: 8, retrievability: 1.0)
        ))
        await store.upsert(FSRSDecayRow(
            noteId: "high-risk",
            lastReviewedAt: 0,
            memory: FSRSMemoryState(difficulty: 5, stability: 5, retrievability: 1.0)
        ))
        let now = Date(timeIntervalSince1970: 30 * 86_400)
        let surfaced = await store.topAtRisk(limit: 10, now: now)
        // mid-risk + high-risk are below 0.80; low-risk is above
        #expect(surfaced.count == 2,
                "should surface 2 below-threshold notes; got \(surfaced.count)")
        #expect(surfaced.first?.noteId == "high-risk",
                "most-forgotten note (lowest R) should be first")
        #expect(surfaced.last?.noteId == "mid-risk")
        await store.reset()
    }

    @Test("GRDB migration is idempotent")
    func grdbMigrationIsIdempotent() throws {
        let queue = try DatabaseQueue(path: ":memory:")
        var migrator = DatabaseMigrator()
        FSRSDecayDatabase.registerMigration(&migrator)
        try migrator.migrate(queue)
        try migrator.migrate(queue)

        let tableExists = try queue.read { db in
            try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'fsrs_state')") ?? false
        }
        #expect(tableExists)
    }

    @Test("Configured GRDB store reloads persisted rows")
    func grdbStoreReloadsPersistedRows() async throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let store = FSRSDecayStore()
        try await store.configurePersistence(queue)

        let row = FSRSDecayRow(
            noteId: "persisted-note",
            lastReviewedAt: 123,
            memory: FSRSMemoryState(difficulty: 4, stability: 9, retrievability: 0.72),
            lastGrade: .hard,
            reviews: 7
        )
        await store.upsert(row)

        let reloaded = FSRSDecayStore()
        try await reloaded.configurePersistence(queue)
        #expect(await reloaded.row(for: "persisted-note") == row)
    }

    @Test("recordReview persists grade and review count")
    func recordReviewPersistsToGRDB() async throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let store = FSRSDecayStore()
        try await store.configurePersistence(queue)

        let now = Date(timeIntervalSince1970: 456)
        await store.recordReview(noteId: "reviewed-note", grade: .easy, now: now)

        let reloaded = FSRSDecayStore()
        try await reloaded.configurePersistence(queue)
        let row = await reloaded.row(for: "reviewed-note")
        #expect(row?.lastGrade == .easy)
        #expect(row?.reviews == 1)
        #expect(row?.lastReviewedAt == 456)
        #expect(row?.memory.retrievability == 1.0)
    }

    @Test("reset deletes persisted GRDB rows")
    func resetDeletesPersistedRows() async throws {
        let queue = try DatabaseQueue(path: ":memory:")
        let store = FSRSDecayStore()
        try await store.configurePersistence(queue)
        await store.upsert(FSRSDecayRow(noteId: "delete-me"))
        await store.reset()

        let count = try await queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM fsrs_state") ?? -1
        }
        #expect(count == 0)
    }
}
