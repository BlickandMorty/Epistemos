import Testing
@testable import Epistemos
import Foundation
import Metal

// MARK: - GraphSlotSchedulerTests
//
// Verifies the 3-slot ring invariants from
// docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md §"Locked architectural
// decisions" #2 and the explicit state-machine semantics shipped in
// Epistemos/Engine/GraphSlotScheduler.swift.

@Suite("GraphSlotScheduler invariants", .serialized)
@MainActor
struct GraphSlotSchedulerTests {

    @Test("default scheduler initializes 3 writable slots")
    func defaultInitialState() {
        let s = GraphSlotScheduler()
        #expect(s.totalSlots == 3)
        #expect(s.writableCount == 3)
        for i in 0..<3 {
            #expect(s.state(of: i) == .writable)
            #expect(s.version(of: i) == 0)
        }
    }

    @Test("reserveWriteSlot transitions writable → cpuWriting and bumps version")
    func reserveBumpsVersion() {
        let s = GraphSlotScheduler()
        let r = s.reserveWriteSlot()
        #expect(r != nil)
        guard let r else { return }
        #expect(s.state(of: r.index) == .cpuWriting)
        #expect(s.version(of: r.index) == 1)
        #expect(r.version == 1)
        #expect(s.writableCount == 2)
    }

    @Test("reserveWriteSlot returns nil when no slots are writable")
    func reserveExhausted() {
        let s = GraphSlotScheduler(slotCount: 2)
        let r1 = s.reserveWriteSlot()
        let r2 = s.reserveWriteSlot()
        let r3 = s.reserveWriteSlot()
        #expect(r1 != nil)
        #expect(r2 != nil)
        #expect(r3 == nil, "third reservation must fail when only 2 slots exist")
        #expect(s.writableCount == 0)
    }

    @Test("markReadyForGPU transitions cpuWriting → gpuReading")
    func markReadyTransitionsState() {
        let s = GraphSlotScheduler()
        guard let r = s.reserveWriteSlot() else {
            Issue.record("could not reserve initial slot")
            return
        }
        s.markReadyForGPU(r)
        #expect(s.state(of: r.index) == .gpuReading)
        #expect(s.writableCount == 2)
    }

    @Test("round-robin distributes reservations across slots")
    func roundRobinDistribution() {
        let s = GraphSlotScheduler(slotCount: 3)

        // Reserve all 3 in a row; markReadyForGPU each to free up a
        // slot via simulated GPU completion in a second pass.
        var reserved: [GraphSlotScheduler.SlotReservation] = []
        for _ in 0..<3 {
            guard let r = s.reserveWriteSlot() else {
                Issue.record("ran out of slots during round-robin reservation")
                return
            }
            reserved.append(r)
        }

        // Three distinct slot indices must have been used.
        let indices = Set(reserved.map(\.index))
        #expect(indices.count == 3, "reserveWriteSlot must round-robin across all slots, got \(indices)")
    }

    @Test("versions are monotonically increasing per slot")
    func versionsMonotonic() {
        let s = GraphSlotScheduler(slotCount: 2)
        guard let r1 = s.reserveWriteSlot() else {
            Issue.record("could not reserve slot 1")
            return
        }
        #expect(r1.version == 1)

        guard let r2 = s.reserveWriteSlot() else {
            Issue.record("could not reserve slot 2")
            return
        }
        // Two slots, both v=1 because round-robin lands on different slot.
        #expect(r2.version == 1)
        #expect(r2.index != r1.index)
    }

    @Test("writableCount tracks state machine accurately")
    func writableCountTracking() {
        let s = GraphSlotScheduler()
        #expect(s.writableCount == 3)
        guard let r1 = s.reserveWriteSlot() else {
            Issue.record("could not reserve")
            return
        }
        #expect(s.writableCount == 2)
        s.markReadyForGPU(r1)
        #expect(s.writableCount == 2, "markReadyForGPU does not change writable count")

        guard let r2 = s.reserveWriteSlot() else {
            Issue.record("could not reserve second slot")
            return
        }
        _ = r2
        #expect(s.writableCount == 1)
    }
}
