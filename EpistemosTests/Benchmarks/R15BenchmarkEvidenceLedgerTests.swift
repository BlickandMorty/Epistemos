import Foundation
import Testing

nonisolated struct R15BenchmarkEvidenceExpectation {
    let filename: String
    let suite: String
    let measurement: String
    let unit: String
    let sampleCount: Int
    let requiredMetadata: [String: String]
}

nonisolated enum R15BenchmarkEvidenceLedgerError: Error, CustomStringConvertible {
    case unexpectedExpectationCount(Int)
    case duplicateFilename(String)
    case invalidFilename(String)
    case missingClosedBaseline(String)
    case missingMetadata(filename: String, key: String, expected: String, actual: String?)
    case forbiddenOpenBaselineClosed(String)

    var description: String {
        switch self {
        case .unexpectedExpectationCount(let count):
            return "Expected 10 closed R15 baselines, found \(count)"
        case .duplicateFilename(let filename):
            return "Duplicate R15 benchmark evidence filename: \(filename)"
        case .invalidFilename(let filename):
            return "R15 benchmark evidence filename is not a JSON artifact: \(filename)"
        case .missingClosedBaseline(let measurement):
            return "Missing closed R15 benchmark evidence measurement: \(measurement)"
        case .missingMetadata(let filename, let key, let expected, let actual):
            return "\(filename) metadata \(key) expected \(expected), got \(actual ?? "nil")"
        case .forbiddenOpenBaselineClosed(let filename):
            return "\(filename) must not be listed as a closed R15 baseline artifact yet"
        }
    }
}

nonisolated enum R15BenchmarkEvidenceLedger {
    static let closedBaselineExpectations: [R15BenchmarkEvidenceExpectation] = [
        .init(
            filename: "2026-05-01t00-00-00-000z-r15-fixture-baselines-graph_payload_construction_750_nodes.json",
            suite: "R15 Fixture Baselines",
            measurement: "graph_payload_construction_750_nodes",
            unit: "seconds",
            sampleCount: 7,
            requiredMetadata: [
                "baseline_kind": "fixture_pr2_real",
                "fixture_status": "real_local_fixture",
            ]
        ),
        .init(
            filename: "2026-05-01t00-00-00-000z-r15-fixture-baselines-markdown_parser_160_sections.json",
            suite: "R15 Fixture Baselines",
            measurement: "markdown_parser_160_sections",
            unit: "seconds",
            sampleCount: 7,
            requiredMetadata: [
                "baseline_kind": "fixture_pr2_real",
                "fixture_status": "real_local_fixture",
            ]
        ),
        .init(
            filename: "2026-05-01t00-00-00-000z-r15-fixture-baselines-code_token_parser_1200_lines.json",
            suite: "R15 Fixture Baselines",
            measurement: "code_token_parser_1200_lines",
            unit: "seconds",
            sampleCount: 7,
            requiredMetadata: [
                "baseline_kind": "fixture_pr2_real",
                "fixture_status": "real_local_fixture",
            ]
        ),
        .init(
            filename: "2026-05-01t00-00-00-000z-r15-editor-shell-baselines-editor_shell_mount_layout_1800_lines.json",
            suite: "R15 Editor Shell Baselines",
            measurement: "editor_shell_mount_layout_1800_lines",
            unit: "seconds",
            sampleCount: 5,
            requiredMetadata: [
                "baseline_kind": "editor_shell_pr3_real",
                "fixture_status": "real_appkit_textkit_fixture",
            ]
        ),
        .init(
            filename: "2026-05-01t00-00-00-000z-r15-editor-shell-baselines-editor_shell_viewport_attribute_220_lines.json",
            suite: "R15 Editor Shell Baselines",
            measurement: "editor_shell_viewport_attribute_220_lines",
            unit: "seconds",
            sampleCount: 5,
            requiredMetadata: [
                "baseline_kind": "editor_shell_pr3_real",
                "fixture_status": "real_appkit_textkit_fixture",
            ]
        ),
        .init(
            filename: "2026-05-01t00-00-00-000z-r15-editor-shell-baselines-editor_shell_batch_insert_96_lines.json",
            suite: "R15 Editor Shell Baselines",
            measurement: "editor_shell_batch_insert_96_lines",
            unit: "seconds",
            sampleCount: 5,
            requiredMetadata: [
                "baseline_kind": "editor_shell_pr3_real",
                "fixture_status": "real_appkit_textkit_fixture",
            ]
        ),
        .init(
            filename: "2026-05-01t00-00-00-000z-r15-sqlite-vec-knn-sqlite_vec_knn_100k_32d.json",
            suite: "sqlite-vec KNN",
            measurement: "sqlite_vec_knn_100k_32d",
            unit: "seconds",
            sampleCount: 16,
            requiredMetadata: [
                "status": "real sqlite-vec vec0 KNN fixture",
                "target_vector_count": "100000",
                "dimensions": "32",
            ]
        ),
        .init(
            filename: "2026-05-02t00-00-00-000z-r15-uniffi-callback-baseline-uniffi_callback_handle_roundtrip_10000.json",
            suite: "R15 UniFFI Callback Baseline",
            measurement: "uniffi_callback_handle_roundtrip_10000",
            unit: "nanoseconds_per_call",
            sampleCount: 7,
            requiredMetadata: [
                "baseline_kind": "uniffi_callback_pr5_handle_fixture",
                "fixture_status": "generated_uniffi_callback_handle",
                "rust_loop_status": "not_true_rust_to_swift_loop",
            ]
        ),
        .init(
            filename: "2026-05-02t00-00-00-000z-r15-mlx-thermal-policy-baseline-mlx_thermal_policy_snapshot_1000.json",
            suite: "R15 MLX Thermal Policy Baseline",
            measurement: "mlx_thermal_policy_snapshot_1000",
            unit: "nanoseconds_per_decision",
            sampleCount: 9,
            requiredMetadata: [
                "baseline_kind": "r15_pr6_mlx_thermal_policy",
                "fixture_status": "mlx_thermal_policy_fixture",
                "live_inference_status": "not_live_mlx_inference_tok_s",
            ]
        ),
        .init(
            filename: "2026-05-02t00-00-00-000z-r15-graph-ffi-bridge-baseline-graph_ffi_bridge_fixture_250.json",
            suite: "R15 Graph FFI Bridge Baseline",
            measurement: "graph_ffi_bridge_fixture_250",
            unit: "nanoseconds_per_fixture_roundtrip",
            sampleCount: 5,
            requiredMetadata: [
                "baseline_kind": "r15_pr7_graph_ffi_bridge",
                "fixture_status": "live_graph_engine_ffi_fixture",
                "render_status": "not_live_render_frame_rate",
            ]
        ),
    ]

    static let forbiddenOpenBaselineFilenames: Set<String> = [
        "2026-05-02t00-00-00-000z-r15-mlx-live-token-throughput-baseline-mlx_live_token_throughput_deepseek7b_32.json",
        "2026-05-02t00-00-00-000z-r15-renderer-fps-baseline-renderer_fps_thermal_soak.json",
        "2026-05-02t00-00-00-000z-r15-true-rust-callback-loop-baseline-true_rust_callback_loop.json",
    ]

    static func validateClosedBaselineLedger() throws {
        guard closedBaselineExpectations.count == 10 else {
            throw R15BenchmarkEvidenceLedgerError.unexpectedExpectationCount(
                closedBaselineExpectations.count
            )
        }

        var filenames = Set<String>()
        for expectation in closedBaselineExpectations {
            guard expectation.filename.hasSuffix(".json") else {
                throw R15BenchmarkEvidenceLedgerError.invalidFilename(expectation.filename)
            }
            guard filenames.insert(expectation.filename).inserted else {
                throw R15BenchmarkEvidenceLedgerError.duplicateFilename(expectation.filename)
            }
            if forbiddenOpenBaselineFilenames.contains(expectation.filename) {
                throw R15BenchmarkEvidenceLedgerError.forbiddenOpenBaselineClosed(expectation.filename)
            }
            try validateRequiredMetadata(expectation)
        }
    }

    static func validateOpenBaselineClaimsRemainOpen() throws {
        for filename in forbiddenOpenBaselineFilenames {
            if closedBaselineExpectations.contains(where: { $0.filename == filename }) {
                throw R15BenchmarkEvidenceLedgerError.forbiddenOpenBaselineClosed(filename)
            }
        }

        try requireMeasurement("uniffi_callback_handle_roundtrip_10000", metadataKey: "rust_loop_status", value: "not_true_rust_to_swift_loop")
        try requireMeasurement("mlx_thermal_policy_snapshot_1000", metadataKey: "live_inference_status", value: "not_live_mlx_inference_tok_s")
        try requireMeasurement("graph_ffi_bridge_fixture_250", metadataKey: "render_status", value: "not_live_render_frame_rate")
    }

    private static func validateRequiredMetadata(
        _ expectation: R15BenchmarkEvidenceExpectation
    ) throws {
        guard !expectation.requiredMetadata.isEmpty else {
            throw R15BenchmarkEvidenceLedgerError.missingMetadata(
                filename: expectation.filename,
                key: "baseline marker",
                expected: "non-empty metadata",
                actual: nil
            )
        }
        for (key, expectedValue) in expectation.requiredMetadata where expectedValue.isEmpty {
            throw R15BenchmarkEvidenceLedgerError.missingMetadata(
                filename: expectation.filename,
                key: key,
                expected: "non-empty value",
                actual: expectedValue
            )
        }
    }

    private static func requireMeasurement(
        _ measurement: String,
        metadataKey: String,
        value: String
    ) throws {
        guard let expectation = closedBaselineExpectations.first(where: { $0.measurement == measurement }) else {
            throw R15BenchmarkEvidenceLedgerError.missingClosedBaseline(measurement)
        }
        let actualValue = expectation.requiredMetadata[metadataKey]
        guard actualValue == value else {
            throw R15BenchmarkEvidenceLedgerError.missingMetadata(
                filename: expectation.filename,
                key: metadataKey,
                expected: value,
                actual: actualValue
            )
        }
    }
}

@Suite("R15 Benchmark Evidence Ledger")
nonisolated struct R15BenchmarkEvidenceLedgerTests {
    @Test("committed R15 benchmark ledger names only closed evidence")
    func committedR15BenchmarkLedgerNamesOnlyClosedEvidence() throws {
        try R15BenchmarkEvidenceLedger.validateClosedBaselineLedger()
    }

    @Test("open R15 live baseline claims remain explicitly open")
    func openR15LiveBaselineClaimsRemainExplicitlyOpen() throws {
        try R15BenchmarkEvidenceLedger.validateOpenBaselineClaimsRemainOpen()
    }
}
