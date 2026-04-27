import Foundation
import os
import Testing

// MARK: - R15(c) — sqlite-vec KNN p50/p95/p99 at production scale
//
// Per docs/RESEARCH_DOSSIER_TIER_3_4.md §R15: measures vector
// search latency at 100k vectors using the existing GRDB
// connection. 768-dim embeddings (matches default embedding model).
//
// Disabled by default — fixture build is expensive.
// Run manually:
//   xcodebuild test -scheme Epistemos \
//     -only-testing:EpistemosTests/SQLiteVecKNNBenchTests

private let benchLog = OSSignposter(subsystem: "com.epistemos.bench", category: "knn")

@Suite("sqlite-vec KNN", .disabled("Manual benchmark — needs 100k-vector fixture"))
struct SQLiteVecKNNBenchTests {

    @Test func knnAt100k() async throws {
        // SCAFFOLD: build a 100k vector fixture, perform 1000 queries,
        // record p50/p95/p99. Wire to the existing
        // RustShadowFFIClient KNN entry point once the fixture
        // generator lives somewhere reusable.
        let queryCount = 100
        var samples: [Double] = []
        samples.reserveCapacity(queryCount)
        for _ in 0..<queryCount {
            let start = ContinuousClock.now
            let interval = benchLog.beginInterval("knn.query")
            try await Task.sleep(for: .microseconds(100))  // placeholder
            benchLog.endInterval("knn.query", interval)
            let dur = ContinuousClock.now - start
            samples.append(dur.seconds)
        }
        let sorted = samples.sorted()
        let p50 = sorted[sorted.count / 2]
        let p95 = sorted[Int(Double(sorted.count) * 0.95)]
        // Aim: p95 < 50 ms at 100k vectors. Adjust with real fixture.
        #expect(p50 < 0.05)
        #expect(p95 < 0.1)
    }
}

private extension Duration {
    var seconds: Double {
        let comps = components
        return Double(comps.seconds) + Double(comps.attoseconds) / 1e18
    }
}
