import Foundation
import os
import Testing

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - R15(a) — AFM @Generable round-trip latency
//
// Per docs/RESEARCH_DOSSIER_TIER_3_4.md §R15: measures the cold and
// warm cost of `LanguageModelSession.respond(to:generating:)` across
// schema sizes (small / medium / large @Generable types).
//
// Disabled by default so CI skips them. Run manually:
//   xcodebuild test -scheme Epistemos \
//     -only-testing:EpistemosTests/AFMGenerableBenchTests
//
// All measurements emit `os_signpost` events tagged
// "com.epistemos.bench/afm" so Instruments can graph the histogram
// alongside thermal-state samples.

private let benchLog = OSSignposter(subsystem: "com.epistemos.bench", category: "afm")

@Suite("AFM @Generable round-trip", .disabled("Manual benchmark suite — run via Instruments"))
struct AFMGenerableBenchTests {

    @Test func smallSchemaRoundTrip() async throws {
        try requireAFM()
        let elapsed = await measure(label: "afm.small", iterations: 10) {
            // Concrete @Generable example placeholder. Wire to a real
            // schema like OntologyClassifier.SmallTopic when the test
            // moves out of "scaffold" status.
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(elapsed.median < 0.4)  // 400 ms ceiling — adjust per device
    }

    @Test func largeSchemaRoundTrip() async throws {
        try requireAFM()
        let elapsed = await measure(label: "afm.large", iterations: 5) {
            try? await Task.sleep(for: .milliseconds(40))
        }
        #expect(elapsed.median < 1.2)
    }

    // MARK: - Helpers

    private func requireAFM() throws {
        #if canImport(FoundationModels)
        if #unavailable(macOS 26.0) {
            throw BenchmarkError.unsupported
        }
        #else
        throw BenchmarkError.unsupported
        #endif
    }

    private func measure(
        label: StaticString,
        iterations: Int,
        body: () async -> Void
    ) async -> BenchmarkResult {
        var elapsed: [Double] = []
        elapsed.reserveCapacity(iterations)
        for _ in 0..<iterations {
            let start = ContinuousClock.now
            let interval = benchLog.beginInterval(label)
            await body()
            benchLog.endInterval(label, interval)
            let dur = ContinuousClock.now - start
            elapsed.append(dur.seconds)
        }
        return BenchmarkResult(samples: elapsed.sorted())
    }
}

enum BenchmarkError: Error { case unsupported }

struct BenchmarkResult {
    let samples: [Double]   // sorted ascending
    var median: Double {
        guard !samples.isEmpty else { return 0 }
        return samples[samples.count / 2]
    }
    var p95: Double {
        guard !samples.isEmpty else { return 0 }
        let idx = min(samples.count - 1, Int(Double(samples.count) * 0.95))
        return samples[idx]
    }
}

private extension Duration {
    var seconds: Double {
        let comps = components
        return Double(comps.seconds) + Double(comps.attoseconds) / 1e18
    }
}
