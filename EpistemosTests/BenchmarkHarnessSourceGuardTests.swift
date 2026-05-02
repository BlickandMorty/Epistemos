import Foundation
import Testing

@Suite("R15 Benchmark Harness Source Guards")
nonisolated struct BenchmarkHarnessSourceGuardTests {
    @Test("manual R15 Swift benchmarks write machine-readable JSON results")
    func manualR15SwiftBenchmarksWriteMachineReadableResults() throws {
        let resultsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: resultsDirectory)
        }

        let outputURL = try BenchmarkRunRecorder.record(
            suite: "R15 Source Guard",
            measurement: "Recorder Contract",
            unit: "ms",
            samples: [3, 1, 2, 4],
            metadata: ["status": "contract-test"],
            generatedAt: Date(timeIntervalSince1970: 0),
            resultsDirectory: resultsDirectory
        )

        let data = try Data(contentsOf: outputURL)
        let report = try JSONDecoder().decode(BenchmarkRunReport.self, from: data)
        #expect(report.schema_version == 1)
        #expect(report.generated_at == "1970-01-01T00:00:00.000Z")
        #expect(report.suite == "R15 Source Guard")
        #expect(report.measurement == "Recorder Contract")
        #expect(report.unit == "ms")
        #expect(report.sample_count == 4)
        #expect(report.min == 1)
        #expect(report.max == 4)
        #expect(report.p50 == 2.5)
        #expect(report.p95 == 3.8499999999999996)
        #expect(report.p99 == 3.9699999999999998)
        #expect(report.samples == [1, 2, 3, 4])
        #expect(report.metadata["status"] == "contract-test")
    }

    @Test("recorder rejects empty and non-finite samples")
    func recorderRejectsInvalidSamples() throws {
        #expect(throws: BenchmarkRunRecorderError.emptySamples) {
            try BenchmarkRunRecorder.record(
                suite: "R15 Source Guard",
                measurement: "Empty",
                unit: "ms",
                samples: [],
                resultsDirectory: FileManager.default.temporaryDirectory
            )
        }

        #expect(throws: BenchmarkRunRecorderError.nonFiniteSample(.infinity)) {
            try BenchmarkRunRecorder.record(
                suite: "R15 Source Guard",
                measurement: "Infinity",
                unit: "ms",
                samples: [.infinity],
                resultsDirectory: FileManager.default.temporaryDirectory
            )
        }
    }

    @Test("R15 PR2 fixture baseline runner is real and not placeholder gated")
    @MainActor
    func r15PR2FixtureBaselineRunnerIsRealAndNotPlaceholderGated() throws {
        let source = try loadMirroredSourceTextFile("EpistemosTests/Benchmarks/BenchmarkFixtureBaselines.swift")

        #expect(source.contains("BenchmarkFixtureBaselineRunner"))
        #expect(source.contains("baseline_kind"))
        #expect(source.contains("fixture_pr2_real"))
        #expect(!source.contains("Task.sleep"))
        #expect(!source.localizedCaseInsensitiveContains("placeholder"))
        #expect(!source.contains("@Suite(\"R15 Fixture Baselines\", .disabled"))
    }

    @Test("R15 PR3 editor shell fixture baseline is real AppKit work")
    @MainActor
    func r15PR3EditorShellFixtureBaselineIsRealAppKitWork() throws {
        let source = try loadMirroredSourceTextFile("EpistemosTests/Benchmarks/EditorShellFixtureBaselineTests.swift")

        #expect(source.contains("EditorShellFixtureBaselineRunner"))
        #expect(source.contains("editor_shell_pr3_real"))
        #expect(source.contains("NSTextStorage"))
        #expect(source.contains("NSTextView"))
        #expect(!source.contains("Task.sleep"))
        #expect(!source.localizedCaseInsensitiveContains("placeholder"))
    }

    @Test("R15 PR4 sqlite-vec KNN benchmark points at the real Rust fixture")
    @MainActor
    func r15PR4SQLiteVecKNNBenchmarkPointsAtRealRustFixture() throws {
        let source = try loadMirroredSourceTextFile("EpistemosTests/Benchmarks/SQLiteVecKNNBenchTests.swift")

        #expect(source.contains("sqlite_vec_knn_100k_32d"))
        #expect(source.contains("real sqlite-vec vec0 KNN fixture"))
        #expect(source.contains("target_vector_count"))
        #expect(!source.contains("Task.sleep"))
        #expect(!source.localizedCaseInsensitiveContains("placeholder"))
    }

    @Test("R15 PR5 UniFFI callback fixture baseline uses generated callback handles honestly")
    @MainActor
    func r15PR5UniFFICallbackFixtureBaselineUsesGeneratedCallbackHandlesHonestly() throws {
        let source = try loadMirroredSourceTextFile("EpistemosTests/Benchmarks/UniFFICallbackThroughputTests.swift")

        #expect(source.contains("UniFFICallbackFixtureBaselineRunner"))
        #expect(source.contains("generated_uniffi_callback_handle"))
        #expect(source.contains("not_true_rust_to_swift_loop"))
        #expect(!source.contains("Task.sleep"))
        #expect(!source.localizedCaseInsensitiveContains("placeholder"))
        #expect(!source.contains("@Suite(\"UniFFI callback throughput\", .disabled"))
    }

    @Test("R15 PR6 MLX thermal policy baseline uses PowerGate honestly")
    @MainActor
    func r15PR6MLXThermalPolicyBaselineUsesPowerGateHonestly() throws {
        let source = try loadMirroredSourceTextFile("EpistemosTests/Benchmarks/MLXThermalBenchTests.swift")

        #expect(source.contains("MLXThermalPolicyBaselineRunner"))
        #expect(source.contains("PowerGate.deferSnapshot"))
        #expect(source.contains("mlx_thermal_policy_fixture"))
        #expect(source.contains("not_live_mlx_inference_tok_s"))
        #expect(!source.contains("Task.sleep"))
        #expect(!source.localizedCaseInsensitiveContains("placeholder"))
        #expect(!source.contains("@Suite(\"MLX thermal-pressure inference\", .disabled"))
    }

    @Test("R15 PR7 graph FFI baseline uses live GraphEngine bridge honestly")
    @MainActor
    func r15PR7GraphFFIBaselineUsesLiveGraphEngineBridgeHonestly() throws {
        let source = try loadMirroredSourceTextFile("EpistemosTests/Benchmarks/GraphFFIBenchmarkTests.swift")

        #expect(source.contains("GraphFFIBaselineRunner"))
        #expect(source.contains("GraphEngine(device:"))
        #expect(source.contains("graph_engine_node_screen_pos"))
        #expect(source.contains("live_graph_engine_ffi_fixture"))
        #expect(!source.contains("try? BenchmarkRunRecorder"))
        #expect(!source.localizedCaseInsensitiveContains("placeholder"))
        #expect(!source.contains("@Suite(\"Graph FFI Benchmarks\", .disabled"))
    }

    @Test("R15 PR8 live MLX token throughput baseline uses the real local runtime honestly")
    @MainActor
    func r15PR8LiveMLXTokenThroughputBaselineUsesRealLocalRuntimeHonestly() throws {
        let source = try loadMirroredSourceTextFile("EpistemosTests/Benchmarks/MLXThermalBenchTests.swift")

        #expect(source.contains("MLXLiveTokenThroughputBaselineRunner"))
        #expect(source.contains("MLXInferenceService(snapshot:"))
        #expect(source.contains("LocalMLXClient("))
        #expect(source.contains("live_mlx_token_throughput_fixture"))
        #expect(source.contains("EPISTEMOS_RUN_LIVE_MLX_TOKEN_BENCHMARK"))
        #expect(source.contains("not_five_min_thermal_soak"))
        #expect(!source.localizedCaseInsensitiveContains("placeholder"))
    }
}
