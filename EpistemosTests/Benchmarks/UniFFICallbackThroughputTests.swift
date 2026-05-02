import Foundation
import Testing
@testable import Epistemos

nonisolated enum UniFFICallbackFixtureBaselineError: Error, Equatable {
    case invalidIterations(Int)
    case invalidSampleCount(Int)
    case callbackCountMismatch(expected: Int, actual: Int)
}

nonisolated struct UniFFICallbackFixtureBaselineRunner {
    static let stableGeneratedAt = Date(timeIntervalSince1970: 1_777_680_000)

    static func run(
        resultsDirectory: URL,
        generatedAt: Date = stableGeneratedAt,
        iterations: Int = 10_000,
        samples: Int = 7
    ) throws -> URL {
        guard iterations > 0 else {
            throw UniFFICallbackFixtureBaselineError.invalidIterations(iterations)
        }
        guard samples > 0 else {
            throw UniFFICallbackFixtureBaselineError.invalidSampleCount(samples)
        }

        let delegate = CountingAgentEventDelegate()
        let handle = FfiConverterCallbackInterfaceAgentEventDelegate_lower(delegate)
        var sampleValues: [Double] = []
        sampleValues.reserveCapacity(samples)

        for _ in 0..<samples {
            let start = ContinuousClock.now
            for _ in 0..<iterations {
                let lifted = try FfiConverterCallbackInterfaceAgentEventDelegate_lift(handle)
                lifted.onTextDelta(delta: "generated_uniffi_callback_handle")
            }
            let duration = ContinuousClock.now - start
            sampleValues.append(duration.secondsAsDouble * 1_000_000_000 / Double(iterations))
        }

        let expectedCallbacks = iterations * samples
        guard delegate.textDeltaCount == expectedCallbacks else {
            throw UniFFICallbackFixtureBaselineError.callbackCountMismatch(
                expected: expectedCallbacks,
                actual: delegate.textDeltaCount
            )
        }

        return try BenchmarkRunRecorder.record(
            suite: "R15 UniFFI Callback Baseline",
            measurement: "uniffi_callback_handle_roundtrip_10000",
            unit: "nanoseconds_per_call",
            samples: sampleValues,
            metadata: [
                "baseline_kind": "uniffi_callback_pr5_handle_fixture",
                "fixture_status": "generated_uniffi_callback_handle",
                "sample_source": "focused_xcode_test",
                "iterations_per_sample": "\(iterations)",
                "sample_count_target": "\(samples)",
                "callback_method": "AgentEventDelegate.onTextDelta",
                "handle_count": "1",
                "rust_loop_status": "not_true_rust_to_swift_loop",
                "future_gate": "true Rust callback-loop export requires generated UniFFI transport gate",
                "checksum": "\(delegate.byteChecksum)",
            ],
            generatedAt: generatedAt,
            resultsDirectory: resultsDirectory
        )
    }
}

@Suite("R15 UniFFI Callback Baseline")
nonisolated struct UniFFICallbackThroughputTests {
    @Test("generated callback handle runner writes finite decodable report")
    func generatedCallbackHandleRunnerWritesFiniteDecodableReport() throws {
        let configuration = configuredResultsDirectory()
        let resultsDirectory = configuration.url
        let shouldCleanUp = configuration.removeAfterRun
        defer {
            if shouldCleanUp {
                try? FileManager.default.removeItem(at: resultsDirectory)
            }
        }

        let outputURL = try UniFFICallbackFixtureBaselineRunner.run(resultsDirectory: resultsDirectory)
        let data = try Data(contentsOf: outputURL)
        let report = try JSONDecoder().decode(BenchmarkRunReport.self, from: data)

        #expect(outputURL.lastPathComponent == "2026-05-02t00-00-00-000z-r15-uniffi-callback-baseline-uniffi_callback_handle_roundtrip_10000.json")
        #expect(report.schema_version == 1)
        #expect(report.generated_at == "2026-05-02T00:00:00.000Z")
        #expect(report.suite == "R15 UniFFI Callback Baseline")
        #expect(report.measurement == "uniffi_callback_handle_roundtrip_10000")
        #expect(report.unit == "nanoseconds_per_call")
        #expect(report.sample_count == 7)
        #expect(report.samples.count == report.sample_count)
        for sample in report.samples {
            #expect(sample.isFinite)
            #expect(sample >= 0)
        }
        #expect(report.metadata["baseline_kind"] == "uniffi_callback_pr5_handle_fixture")
        #expect(report.metadata["fixture_status"] == "generated_uniffi_callback_handle")
        #expect(report.metadata["sample_source"] == "focused_xcode_test")
        #expect(report.metadata["iterations_per_sample"] == "10000")
        #expect(report.metadata["sample_count_target"] == "7")
        #expect(report.metadata["callback_method"] == "AgentEventDelegate.onTextDelta")
        #expect(report.metadata["rust_loop_status"] == "not_true_rust_to_swift_loop")
        #expect(report.metadata["checksum"]?.isEmpty == false)
    }

    @Test("generated callback handle runner rejects invalid counts")
    func generatedCallbackHandleRunnerRejectsInvalidCounts() throws {
        #expect(throws: UniFFICallbackFixtureBaselineError.invalidIterations(0)) {
            try UniFFICallbackFixtureBaselineRunner.run(
                resultsDirectory: FileManager.default.temporaryDirectory,
                iterations: 0
            )
        }

        #expect(throws: UniFFICallbackFixtureBaselineError.invalidSampleCount(0)) {
            try UniFFICallbackFixtureBaselineRunner.run(
                resultsDirectory: FileManager.default.temporaryDirectory,
                samples: 0
            )
        }
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

private final class CountingAgentEventDelegate: AgentEventDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var _textDeltaCount = 0
    private var _byteChecksum = 0

    nonisolated var textDeltaCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _textDeltaCount
    }

    nonisolated var byteChecksum: Int {
        lock.lock()
        defer { lock.unlock() }
        return _byteChecksum
    }

    nonisolated func onThinkingDelta(thought: String) {}

    nonisolated func onTextDelta(delta: String) {
        lock.lock()
        _textDeltaCount += 1
        _byteChecksum &+= delta.utf8.count
        lock.unlock()
    }

    nonisolated func onToolInputDelta(index: UInt32, partialJson: String) {}

    nonisolated func onToolStarted(toolUseId: String, name: String, inputJson: String) {}

    nonisolated func onToolCompleted(toolUseId: String, result: String, isError: Bool) {}

    nonisolated func onSubagentSpawned(agentId: String, role: String) {}

    nonisolated func onPermissionRequired(permissionId: String, toolName: String, inputJson: String, riskLevel: String) {}

    nonisolated func onContextCompacting(currentTokens: UInt32) {}

    nonisolated func onContextCompacted(newMessageCount: UInt32) {}

    nonisolated func onTurnStarted(turnNumber: UInt32, messageCount: UInt32) {}

    nonisolated func onComplete(stopReason: String, inputTokens: UInt32, outputTokens: UInt32) {}

    nonisolated func onError(message: String) {}

    nonisolated func executeComputerAction(actionJson: String) -> String {
        "{\"success\":false,\"reason\":\"benchmark_delegate\"}"
    }

    nonisolated func waitForPermission(permissionId: String) -> Bool {
        false
    }

    nonisolated func askUserQuestion(questionJson: String) -> String {
        "{\"response\":\"\",\"choice_index\":null}"
    }

    nonisolated func perceiveApp(appName: String, depth: String) -> String {
        "{\"elements\":[],\"screenshot_path\":null,\"latency_ms\":0}"
    }

    nonisolated func interactWithApp(actionJson: String) -> String {
        "{\"success\":false,\"element_found\":false,\"action_performed\":false}"
    }

    nonisolated func startScreenWatch(watchJson: String) -> String {
        "{\"triggered\":false,\"reason\":\"benchmark_delegate\",\"elapsed_ms\":0}"
    }

    nonisolated func manageSsmState(actionJson: String) -> String {
        "{\"success\":false,\"state_size_mb\":0,\"layers\":0,\"dtype\":\"none\",\"duration_ms\":0,\"states\":[]}"
    }

    nonisolated func generateConstrained(prompt: String, grammarJson: String) -> String {
        "{\"output\":\"\",\"tokens_generated\":0,\"constraint_violations_masked\":0}"
    }

    nonisolated func generateImage(prompt: String, aspectRatio: String) -> String {
        "{\"error\":\"benchmark_delegate\"}"
    }

    nonisolated func triggerNightbrainJob(jobType: String, priority: String) -> String {
        "{\"job_id\":\"benchmark\",\"status\":\"skipped\",\"estimated_duration_s\":0}"
    }

    nonisolated func getPartnerContext(noteId: String, cursorOffset: UInt32) -> String {
        "{\"matches\":[],\"complexity\":0,\"suggestions\":[]}"
    }
}

private extension Duration {
    nonisolated var secondsAsDouble: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
