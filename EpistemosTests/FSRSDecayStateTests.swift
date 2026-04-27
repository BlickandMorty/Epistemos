import Foundation
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

    @Test("Retrievability decays exp(ln(0.9) * t / S) — t=S → R=0.9")
    func decayMatchesFSRSFormula() {
        let row = FSRSDecayRow(
            noteId: "note-2",
            lastReviewedAt: 0,
            memory: FSRSMemoryState(difficulty: 5.0, stability: 5.0, retrievability: 1.0)
        )
        // t = stability (5 days) → R should equal 0.9 by the FSRS formula
        let after5days = Date(timeIntervalSince1970: 5 * 86_400)
        let r = FSRSRetrievability.current(for: row, now: after5days)
        #expect(abs(r - 0.9) < 0.001,
                "R(t=S) MUST equal 0.9 — got \(r)")
    }

    @Test("isHighRisk returns true once R drops below 0.80")
    func highRiskThreshold() {
        let row = FSRSDecayRow(
            noteId: "note-3",
            lastReviewedAt: 0,
            memory: FSRSMemoryState(difficulty: 5.0, stability: 5.0, retrievability: 1.0)
        )
        // R(t=10d, S=5d) = exp(ln(0.9)*2) = 0.81
        // R(t=11d, S=5d) ≈ 0.789 → below threshold
        let day10 = Date(timeIntervalSince1970: 10 * 86_400)
        let day11 = Date(timeIntervalSince1970: 11 * 86_400)
        #expect(!FSRSRetrievability.isHighRisk(row, now: day10),
                "R(10d) ≈ 0.81 — above 0.80 threshold")
        #expect(FSRSRetrievability.isHighRisk(row, now: day11),
                "R(11d) ≈ 0.789 — below 0.80 threshold")
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

    @Test("topAtRisk returns notes ordered ascending by R")
    func topAtRiskOrdering() async {
        let store = FSRSDecayStore.shared
        await store.reset()
        // Three notes with stabilities such that 30 days from
        // lastReviewed gives different R values:
        //   stability=10 → R(30d) = exp(ln(0.9)*3) = 0.729
        //   stability=15 → R(30d) = exp(ln(0.9)*2) = 0.81 (NOT high-risk; > 0.80)
        //   stability= 5 → R(30d) = exp(ln(0.9)*6) = 0.531
        await store.upsert(FSRSDecayRow(
            noteId: "low-risk",
            lastReviewedAt: 0,
            memory: FSRSMemoryState(difficulty: 5, stability: 15, retrievability: 1.0)
        ))
        await store.upsert(FSRSDecayRow(
            noteId: "mid-risk",
            lastReviewedAt: 0,
            memory: FSRSMemoryState(difficulty: 5, stability: 10, retrievability: 1.0)
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
}
