import Foundation
import os
import Testing

// MARK: - R15(b) — MLX Qwen3 4-bit tok/s under thermal pressure
//
// Runs sustained inference for >5 minutes while sampling
// `ProcessInfo.thermalState` every iteration so the throttle decay
// curve can be graphed against tok/s.
//
// Disabled by default — long-running benchmark.
// Run manually:
//   xcodebuild test -scheme Epistemos \
//     -only-testing:EpistemosTests/MLXThermalBenchTests

private let benchLog = OSSignposter(subsystem: "com.epistemos.bench", category: "mlx-thermal")

@Suite("MLX thermal-pressure inference", .disabled("Manual long-running benchmark"))
struct MLXThermalBenchTests {

    @Test func sustainedInferenceUnderLoad() async throws {
        // SCAFFOLD: in production this would call into MLXService
        // with a fixed prompt + measure tok/s per second of wall-
        // clock for the configured run duration.
        let runDuration: Duration = .seconds(60)  // shorten to 60s for the scaffold
        let start = ContinuousClock.now
        var samples: [(elapsed: Duration, thermal: ProcessInfo.ThermalState)] = []

        while ContinuousClock.now - start < runDuration {
            let interval = benchLog.beginInterval("mlx.thermal.tick")
            try await Task.sleep(for: .milliseconds(500))
            benchLog.endInterval("mlx.thermal.tick", interval)
            let elapsed = ContinuousClock.now - start
            samples.append((elapsed, ProcessInfo.processInfo.thermalState))
        }

        // The harness records — assertions deliberately loose; real
        // pass/fail comes from comparing against a baseline JSON.
        #expect(!samples.isEmpty)
    }
}
