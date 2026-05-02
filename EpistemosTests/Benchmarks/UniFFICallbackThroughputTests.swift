import Foundation
import os
import Testing

// MARK: - R15(d) — UniFFI Rust → Swift callback throughput
//
// Per docs/RESEARCH_DOSSIER_TIER_3_4.md §R15: measures the
// peak Rust → Swift callback rate with a tight loop. The Rust
// side fires N callbacks; this harness records wall-clock
// from first callback to last.
//
// Disabled by default. Run manually:
//   xcodebuild test -scheme Epistemos \
//     -only-testing:EpistemosTests/UniFFICallbackThroughputTests

private let benchLog = OSSignposter(subsystem: "com.epistemos.bench", category: "uniffi")

@Suite("UniFFI callback throughput", .disabled("Manual benchmark"))
struct UniFFICallbackThroughputTests {

    @Test func tightCallbackLoop() async throws {
        // SCAFFOLD: bridge to a Rust-side benchmark function that
        // fires N callbacks back into a Swift closure. For now we
        // simulate the upper bound on Swift-only dispatch cost so
        // the harness compiles.
        let count = 10_000
        let start = ContinuousClock.now
        let interval = benchLog.beginInterval("uniffi.callback")
        for _ in 0..<count {
            // placeholder — real measurement would go through
            // RustShadowFFIClient or a dedicated bench bridge.
            _ = ContinuousClock.now
        }
        benchLog.endInterval("uniffi.callback", interval)
        let elapsed = ContinuousClock.now - start
        let perCallNanos = elapsed.seconds * 1e9 / Double(count)
        _ = try? BenchmarkRunRecorder.record(
            suite: "UniFFI callback throughput",
            measurement: "tight_callback_loop",
            unit: "nanoseconds_per_call",
            samples: [perCallNanos],
            metadata: [
                "status": "Swift-only dispatch placeholder until Rust callback bench gate",
                "iterations": "\(count)",
            ]
        )
        // Aim: < 5 microseconds per Rust → Swift callback.
        #expect(perCallNanos < 50_000)  // placeholder; real bar = 5_000
    }
}

private extension Duration {
    var seconds: Double {
        let comps = components
        return Double(comps.seconds) + Double(comps.attoseconds) / 1e18
    }
}
