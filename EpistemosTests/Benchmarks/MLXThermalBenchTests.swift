import Foundation
import Testing
@testable import Epistemos

@MainActor
enum MLXThermalPolicyBaselineError: Error {
    case invalidSampleCount(Int)
    case invalidDecisionsPerSample(Int)
    case policyMismatch(String, PowerGate.DeferSnapshot, PowerGate.DeferSnapshot)
}

@MainActor
struct MLXThermalPolicyBaselineRunner {
    static let stableGeneratedAt = Date(timeIntervalSince1970: 1_777_680_000)
    static let expectedReportFilename =
        "2026-05-02t00-00-00-000z-r15-mlx-thermal-policy-baseline-mlx_thermal_policy_snapshot_1000.json"

    static func run(
        resultsDirectory: URL,
        generatedAt: Date = stableGeneratedAt,
        sampleCount: Int = 9,
        decisionsPerSample: Int = 1_000
    ) throws -> URL {
        guard sampleCount > 0 else {
            throw MLXThermalPolicyBaselineError.invalidSampleCount(sampleCount)
        }
        guard decisionsPerSample > 0 else {
            throw MLXThermalPolicyBaselineError.invalidDecisionsPerSample(decisionsPerSample)
        }

        let samples = try measure(
            sampleCount: sampleCount,
            decisionsPerSample: decisionsPerSample
        )

        return try BenchmarkRunRecorder.record(
            suite: "R15 MLX Thermal Policy Baseline",
            measurement: "mlx_thermal_policy_snapshot_1000",
            unit: "nanoseconds_per_decision",
            samples: samples.values,
            metadata: [
                "baseline_kind": "r15_pr6_mlx_thermal_policy",
                "fixture_status": "mlx_thermal_policy_fixture",
                "live_inference_status": "not_live_mlx_inference_tok_s",
                "sample_source": "focused_xcode_test",
                "thermal_authority": "PowerGate.deferSnapshot",
                "product_surface": "mlx_dispatch_backpressure",
                "future_gate": "live_mlx_token_throughput_thermal_soak",
                "scenario_count": "\(scenarios.count)",
                "decisions_per_sample": "\(decisionsPerSample)",
                "checksum": "\(samples.checksum)",
            ],
            generatedAt: generatedAt,
            resultsDirectory: resultsDirectory
        )
    }

    static func canonicalScenarioReasonMap() throws -> [String: String] {
        var result: [String: String] = [:]
        result.reserveCapacity(scenarios.count)

        for scenario in scenarios {
            let snapshot = PowerGate.deferSnapshot(
                lowPowerModeEnabled: scenario.lowPowerModeEnabled,
                thermalState: scenario.thermalState,
                battery: scenario.battery,
                memoryPressureActive: scenario.memoryPressureActive
            )
            guard snapshot == scenario.expectedSnapshot else {
                throw MLXThermalPolicyBaselineError.policyMismatch(
                    scenario.name,
                    scenario.expectedSnapshot,
                    snapshot
                )
            }
            result[scenario.name] = snapshot.reason?.rawValue ?? "allow"
        }

        return result
    }

    @inline(never)
    private static func measure(
        sampleCount: Int,
        decisionsPerSample: Int
    ) throws -> (values: [Double], checksum: Int) {
        var values: [Double] = []
        values.reserveCapacity(sampleCount)
        var checksum = 0

        for sampleIndex in 0..<sampleCount {
            let start = ContinuousClock.now
            for decisionIndex in 0..<decisionsPerSample {
                let scenario = scenarios[(sampleIndex + decisionIndex) % scenarios.count]
                checksum &+= try evaluate(scenario, decisionIndex: decisionIndex)
            }
            let duration = ContinuousClock.now - start
            values.append(duration.secondsAsDouble * 1_000_000_000 / Double(decisionsPerSample))
        }

        return (values, checksum)
    }

    @inline(never)
    private static func evaluate(_ scenario: ThermalPolicyScenario, decisionIndex: Int) throws -> Int {
        let snapshot = PowerGate.deferSnapshot(
            lowPowerModeEnabled: scenario.lowPowerModeEnabled,
            thermalState: scenario.thermalState,
            battery: scenario.battery,
            memoryPressureActive: scenario.memoryPressureActive
        )
        guard snapshot == scenario.expectedSnapshot else {
            throw MLXThermalPolicyBaselineError.policyMismatch(
                scenario.name,
                scenario.expectedSnapshot,
                snapshot
            )
        }

        return decisionIndex
            &+ scenario.name.utf8.count
            &+ (snapshot.shouldDefer ? 31 : 7)
            &+ (snapshot.reason?.rawValue.utf8.count ?? 0)
    }

    private static let scenarios: [ThermalPolicyScenario] = [
        ThermalPolicyScenario(
            name: "nominal-ac-power",
            lowPowerModeEnabled: false,
            thermalState: .nominal,
            battery: .init(onBattery: false, percent: 100, isCharging: false),
            memoryPressureActive: false,
            expectedSnapshot: .init(shouldDefer: false, reason: nil)
        ),
        ThermalPolicyScenario(
            name: "fair-ac-power",
            lowPowerModeEnabled: false,
            thermalState: .fair,
            battery: .init(onBattery: false, percent: 100, isCharging: false),
            memoryPressureActive: false,
            expectedSnapshot: .init(shouldDefer: false, reason: nil)
        ),
        ThermalPolicyScenario(
            name: "thermal-serious",
            lowPowerModeEnabled: false,
            thermalState: .serious,
            battery: .init(onBattery: false, percent: 100, isCharging: false),
            memoryPressureActive: false,
            expectedSnapshot: .init(shouldDefer: true, reason: .thermal)
        ),
        ThermalPolicyScenario(
            name: "thermal-critical",
            lowPowerModeEnabled: false,
            thermalState: .critical,
            battery: .init(onBattery: false, percent: 100, isCharging: false),
            memoryPressureActive: false,
            expectedSnapshot: .init(shouldDefer: true, reason: .thermal)
        ),
        ThermalPolicyScenario(
            name: "low-power-precedence",
            lowPowerModeEnabled: true,
            thermalState: .critical,
            battery: .init(onBattery: true, percent: 12, isCharging: false),
            memoryPressureActive: true,
            expectedSnapshot: .init(shouldDefer: true, reason: .lowPower)
        ),
        ThermalPolicyScenario(
            name: "battery-low",
            lowPowerModeEnabled: false,
            thermalState: .nominal,
            battery: .init(onBattery: true, percent: 32, isCharging: false),
            memoryPressureActive: false,
            expectedSnapshot: .init(shouldDefer: true, reason: .battery)
        ),
        ThermalPolicyScenario(
            name: "memory-pressure-after-thermal-clear",
            lowPowerModeEnabled: false,
            thermalState: .nominal,
            battery: .init(onBattery: false, percent: 100, isCharging: false),
            memoryPressureActive: true,
            expectedSnapshot: .init(shouldDefer: true, reason: .memoryPressure)
        ),
        ThermalPolicyScenario(
            name: "charging-low-percent",
            lowPowerModeEnabled: false,
            thermalState: .nominal,
            battery: .init(onBattery: false, percent: 15, isCharging: true),
            memoryPressureActive: false,
            expectedSnapshot: .init(shouldDefer: false, reason: nil)
        ),
        ThermalPolicyScenario(
            name: "fair-battery-healthy",
            lowPowerModeEnabled: false,
            thermalState: .fair,
            battery: .init(onBattery: true, percent: 80, isCharging: false),
            memoryPressureActive: false,
            expectedSnapshot: .init(shouldDefer: false, reason: nil)
        ),
    ]
}

private struct ThermalPolicyScenario {
    let name: String
    let lowPowerModeEnabled: Bool
    let thermalState: ProcessInfo.ThermalState
    let battery: PowerGate.BatterySnapshot
    let memoryPressureActive: Bool
    let expectedSnapshot: PowerGate.DeferSnapshot
}

@Suite("R15 MLX thermal policy baseline")
@MainActor
struct MLXThermalBenchTests {
    @Test("MLX thermal policy baseline writes finite decodable report")
    func mlxThermalPolicyBaselineWritesFiniteDecodableReport() throws {
        let configuration = configuredResultsDirectory()
        let resultsDirectory = configuration.url
        let shouldCleanUp = configuration.removeAfterRun
        defer {
            if shouldCleanUp {
                try? FileManager.default.removeItem(at: resultsDirectory)
            }
        }

        let outputURL = try MLXThermalPolicyBaselineRunner.run(resultsDirectory: resultsDirectory)

        #expect(outputURL.lastPathComponent == MLXThermalPolicyBaselineRunner.expectedReportFilename)

        let data = try Data(contentsOf: outputURL)
        let report = try JSONDecoder().decode(BenchmarkRunReport.self, from: data)
        #expect(report.schema_version == 1)
        #expect(report.generated_at == "2026-05-02T00:00:00.000Z")
        #expect(report.suite == "R15 MLX Thermal Policy Baseline")
        #expect(report.measurement == "mlx_thermal_policy_snapshot_1000")
        #expect(report.unit == "nanoseconds_per_decision")
        #expect(report.sample_count == 9)
        #expect(report.samples.count == report.sample_count)
        for sample in report.samples {
            #expect(sample.isFinite)
            #expect(sample >= 0)
        }
        #expect(report.max >= report.min)
        #expect(report.metadata["baseline_kind"] == "r15_pr6_mlx_thermal_policy")
        #expect(report.metadata["fixture_status"] == "mlx_thermal_policy_fixture")
        #expect(report.metadata["live_inference_status"] == "not_live_mlx_inference_tok_s")
        #expect(report.metadata["thermal_authority"] == "PowerGate.deferSnapshot")
        #expect(report.metadata["future_gate"] == "live_mlx_token_throughput_thermal_soak")
        #expect(report.metadata["scenario_count"] == "9")
        #expect(report.metadata["decisions_per_sample"] == "1000")
        #expect(report.metadata["checksum"]?.isEmpty == false)
    }

    @Test("MLX thermal policy baseline rejects invalid counts")
    func mlxThermalPolicyBaselineRejectsInvalidCounts() throws {
        do {
            try MLXThermalPolicyBaselineRunner.run(
                resultsDirectory: FileManager.default.temporaryDirectory,
                sampleCount: 0
            )
            Issue.record("Expected invalidSampleCount for zero samples")
        } catch MLXThermalPolicyBaselineError.invalidSampleCount(let count) {
            #expect(count == 0)
        } catch {
            Issue.record("Expected invalidSampleCount, got \(error)")
        }

        do {
            try MLXThermalPolicyBaselineRunner.run(
                resultsDirectory: FileManager.default.temporaryDirectory,
                decisionsPerSample: 0
            )
            Issue.record("Expected invalidDecisionsPerSample for zero decisions")
        } catch MLXThermalPolicyBaselineError.invalidDecisionsPerSample(let count) {
            #expect(count == 0)
        } catch {
            Issue.record("Expected invalidDecisionsPerSample, got \(error)")
        }
    }

    @Test("MLX thermal policy scenarios preserve canonical PowerGate precedence")
    func mlxThermalPolicyScenariosPreserveCanonicalPowerGatePrecedence() throws {
        let reasonMap = try MLXThermalPolicyBaselineRunner.canonicalScenarioReasonMap()

        #expect(reasonMap["nominal-ac-power"] == "allow")
        #expect(reasonMap["fair-ac-power"] == "allow")
        #expect(reasonMap["thermal-serious"] == PowerGate.DeferReason.thermal.rawValue)
        #expect(reasonMap["thermal-critical"] == PowerGate.DeferReason.thermal.rawValue)
        #expect(reasonMap["low-power-precedence"] == PowerGate.DeferReason.lowPower.rawValue)
        #expect(reasonMap["battery-low"] == PowerGate.DeferReason.battery.rawValue)
        #expect(reasonMap["memory-pressure-after-thermal-clear"] == PowerGate.DeferReason.memoryPressure.rawValue)
        #expect(reasonMap["charging-low-percent"] == "allow")
        #expect(reasonMap["fair-battery-healthy"] == "allow")
    }

    private func configuredResultsDirectory() -> (url: URL, removeAfterRun: Bool) {
        if let override = ProcessInfo.processInfo.environment["EPISTEMOS_BENCHMARK_RESULTS_DIR"] {
            return (URL(fileURLWithPath: override, isDirectory: true), false)
        }

        let repoResultsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("benchmarks", isDirectory: true)
            .appendingPathComponent("results", isDirectory: true)
        if FileManager.default.fileExists(atPath: repoResultsDirectory.path) {
            return (repoResultsDirectory, false)
        }

        return (
            FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true),
            true
        )
    }
}

private extension Duration {
    nonisolated var secondsAsDouble: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
