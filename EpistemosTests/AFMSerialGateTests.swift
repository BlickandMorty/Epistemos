import Testing
@testable import Epistemos

// AFMSerialGate is the serialization primitive behind AFMSessionPool.withSession.
// It exists to guarantee FoundationModels is never entered concurrently (verified
// crashes 2026-06-09 / 06-11: EXC_BREAKPOINT with two threads simultaneously in
// FoundationModels). These tests pin the serialization + failure-isolation
// contract the crash fix depends on.

@Suite("AFM Serial Gate")
struct AFMSerialGateTests {

    /// Tracks the peak number of bodies running at once.
    private actor ConcurrencyTracker {
        private var current = 0
        private(set) var peak = 0
        func enter() {
            current += 1
            peak = max(peak, current)
        }
        func leave() {
            current -= 1
        }
    }

    @Test("gate runs bodies strictly one at a time")
    func gateSerializesConcurrentBodies() async {
        let gate = AFMSerialGate()
        let tracker = ConcurrencyTracker()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    try? await gate.run {
                        await tracker.enter()
                        // Yield repeatedly: if the gate did NOT serialize, these
                        // suspension points would let other bodies interleave and
                        // push the peak above 1.
                        for _ in 0..<8 { await Task.yield() }
                        await tracker.leave()
                    }
                }
            }
        }

        #expect(await tracker.peak == 1, "bodies must never overlap")
    }

    @Test("a throwing body does not block the next in line")
    func gateIsolatesBodyFailures() async {
        let gate = AFMSerialGate()

        struct Boom: Error {}
        await #expect(throws: Boom.self) {
            try await gate.run { throw Boom() }
        }

        // The gate must still accept and complete subsequent work.
        let value = try? await gate.run { 42 }
        #expect(value == 42)
    }

    @Test("gate preserves each call's own return value")
    func gateReturnsPerCallResults() async {
        let gate = AFMSerialGate()
        var results: [Int] = []
        for i in 0..<5 {
            if let v = try? await gate.run({ i * 2 }) {
                results.append(v)
            }
        }
        #expect(results == [0, 2, 4, 6, 8])
    }
}
