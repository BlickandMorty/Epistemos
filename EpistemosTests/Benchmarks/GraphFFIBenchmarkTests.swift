import Foundation
import Metal
import QuartzCore
import Testing
@testable import Epistemos

@MainActor
enum GraphFFIBaselineError: Error {
    case invalidSampleCount(Int)
    case invalidNodeCount(Int)
    case invalidFrameCount(Int)
    case missingMetalDevice
    case engineCreationFailed
    case missingRawHandle
    case emptySearchResults
    case missingNodeScreenPosition(String)
}

@MainActor
struct GraphBenchmarkFixture {
    let device: MTLDevice
    let layer: CAMetalLayer
    let engine: GraphEngine
    let handle: OpaquePointer
    let nodeIDs: [String]
    let edgeCount: Int
}

@MainActor
struct GraphFFIBaselineRunner {
    static let stableGeneratedAt = Date(timeIntervalSince1970: 1_777_680_000)
    static let expectedReportFilename =
        "2026-05-02t00-00-00-000z-r15-graph-ffi-bridge-baseline-graph_ffi_bridge_fixture_250.json"

    static func run(
        resultsDirectory: URL,
        generatedAt: Date = stableGeneratedAt,
        sampleCount: Int = 5,
        nodeCount: Int = 250
    ) throws -> URL {
        guard sampleCount > 0 else {
            throw GraphFFIBaselineError.invalidSampleCount(sampleCount)
        }
        guard nodeCount > 1 else {
            throw GraphFFIBaselineError.invalidNodeCount(nodeCount)
        }

        let samples = try measure(sampleCount: sampleCount, nodeCount: nodeCount)

        return try BenchmarkRunRecorder.record(
            suite: "R15 Graph FFI Bridge Baseline",
            measurement: "graph_ffi_bridge_fixture_250",
            unit: "nanoseconds_per_fixture_roundtrip",
            samples: samples.values,
            metadata: [
                "baseline_kind": "r15_pr7_graph_ffi_bridge",
                "fixture_status": "live_graph_engine_ffi_fixture",
                "graph_engine_authority": "GraphEngine(device:layer:)",
                "surface_set": "create_add_commit_search_position_visibility_force",
                "render_status": "not_live_render_frame_rate",
                "sample_source": "focused_xcode_test",
                "node_count": "\(nodeCount)",
                "edge_count": "\(fixtureEdgeCount(for: nodeCount))",
                "sample_count_target": "\(sampleCount)",
                "checksum": "\(samples.checksum)",
            ],
            generatedAt: generatedAt,
            resultsDirectory: resultsDirectory
        )
    }

    static func singleFixtureRoundTrip(nodeCount: Int = 40) throws -> Int {
        guard nodeCount > 1 else {
            throw GraphFFIBaselineError.invalidNodeCount(nodeCount)
        }

        let fixture = try makeFixture(nodeCount: nodeCount)
        let engine = fixture.engine
        let handle = fixture.handle
        let ids = fixture.nodeIDs

        let targetIndex = min(42, nodeCount - 1)
        let searchResults = engine.search(query: "Graph FFI Node \(targetIndex)", limit: 8)
        guard !searchResults.isEmpty else {
            throw GraphFFIBaselineError.emptySearchResults
        }

        let targetID = ids[targetIndex]
        var screenPosition = [Float](repeating: 0, count: 2)
        let foundPosition = screenPosition.withUnsafeMutableBufferPointer { buffer -> UInt8 in
            targetID.withCString { uuidPointer in
                graph_engine_node_screen_pos(handle, uuidPointer, buffer.baseAddress)
            }
        }
        guard foundPosition != 0 else {
            throw GraphFFIBaselineError.missingNodeScreenPosition(targetID)
        }

        for index in stride(from: 0, to: nodeCount, by: 17) {
            engine.setNodeVisible(uuid: ids[index], visible: false)
        }
        engine.refreshVisibility()
        for index in stride(from: 0, to: nodeCount, by: 17) {
            engine.setNodeVisible(uuid: ids[index], visible: true)
        }
        engine.refreshVisibility()

        let world = engine.screenToWorld(screenX: screenPosition[0], screenY: screenPosition[1])
        engine.pause()

        return searchResults.count
            &+ Int(foundPosition)
            &+ Int(screenPosition[0].rounded())
            &+ Int(screenPosition[1].rounded())
            &+ Int(world.x.rounded())
            &+ Int(world.y.rounded())
            &+ ids.reduce(0) { $0 &+ $1.utf8.count }
    }

    @inline(never)
    private static func measure(sampleCount: Int, nodeCount: Int) throws -> (values: [Double], checksum: Int) {
        var values: [Double] = []
        values.reserveCapacity(sampleCount)
        var checksum = 0

        for _ in 0..<sampleCount {
            let start = ContinuousClock.now
            checksum &+= try singleFixtureRoundTrip(nodeCount: nodeCount)
            let duration = ContinuousClock.now - start
            values.append(duration.secondsAsDouble * 1_000_000_000)
        }

        return (values, checksum)
    }

    static func makeFixture(nodeCount: Int) throws -> GraphBenchmarkFixture {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw GraphFFIBaselineError.missingMetalDevice
        }

        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .bgra8Unorm
        layer.frame = CGRect(x: 0, y: 0, width: 512, height: 512)
        layer.drawableSize = CGSize(width: 512, height: 512)
        layer.maximumDrawableCount = 3

        guard let engine = GraphEngine(device: device, layer: layer) else {
            throw GraphFFIBaselineError.engineCreationFailed
        }
        guard let handle = engine.rawHandle else {
            throw GraphFFIBaselineError.missingRawHandle
        }

        engine.clear()
        let ids = makeNodeIDs(count: nodeCount)
        for index in ids.indices {
            engine.addNode(
                uuid: ids[index],
                x: Float(index % 25) * 5.0,
                y: Float(index / 25) * 5.0,
                nodeType: .note,
                linkCount: linkCount(for: index, nodeCount: nodeCount),
                label: "R15 Graph FFI Node \(index)"
            )
        }

        for index in 0..<(nodeCount - 1) {
            engine.addEdge(
                sourceUUID: ids[index],
                targetUUID: ids[index + 1],
                weight: 1.0,
                edgeType: UInt8(index % 12)
            )
        }

        for index in stride(from: 0, to: max(0, nodeCount - 8), by: 8) {
            engine.addEdge(
                sourceUUID: ids[index],
                targetUUID: ids[index + 8],
                weight: 0.35,
                edgeType: 4
            )
        }

        engine.commit(entrance: false)
        engine.setForceParams(
            linkDistance: 120,
            chargeStrength: -420,
            chargeRange: 420,
            linkStrength: 0.7
        )

        return GraphBenchmarkFixture(
            device: device,
            layer: layer,
            engine: engine,
            handle: handle,
            nodeIDs: ids,
            edgeCount: fixtureEdgeCount(for: nodeCount)
        )
    }

    static func fixtureEdgeCount(for nodeCount: Int) -> Int {
        var skipEdgeCount = 0
        for _ in stride(from: 0, to: max(0, nodeCount - 8), by: 8) {
            skipEdgeCount += 1
        }
        return max(0, nodeCount - 1) + skipEdgeCount
    }

    private static func makeNodeIDs(count: Int) -> [String] {
        var ids: [String] = []
        ids.reserveCapacity(count)
        for index in 0..<count {
            ids.append("r15-pr7-node-\(index)")
        }
        return ids
    }

    private static func linkCount(for index: Int, nodeCount: Int) -> UInt32 {
        if index == 0 || index == nodeCount - 1 {
            return 1
        }
        return index.isMultiple(of: 8) ? 3 : 2
    }
}

@MainActor
struct GraphRendererFPSBaselineRunner {
    static let stableGeneratedAt = GraphFFIBaselineRunner.stableGeneratedAt
    static let expectedReportFilename =
        "2026-05-02t00-00-00-000z-r15-renderer-fps-baseline-renderer_fps_thermal_soak.json"

    static func isExplicitlyEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        sentinelPath: String = "/tmp/epi-renderer-fps-benchmark"
    ) -> Bool {
        environment["EPISTEMOS_RUN_RENDERER_FPS_BENCHMARK"] == "1"
            || fileManager.fileExists(atPath: sentinelPath)
    }

    static func run(
        resultsDirectory: URL,
        generatedAt: Date = stableGeneratedAt,
        sampleCount: Int = 5,
        nodeCount: Int = 250,
        framesPerSample: Int = 120,
        warmupFrames: Int = 12,
        width: UInt32 = 512,
        height: UInt32 = 512
    ) throws -> URL {
        guard sampleCount > 0 else {
            throw GraphFFIBaselineError.invalidSampleCount(sampleCount)
        }
        guard nodeCount > 1 else {
            throw GraphFFIBaselineError.invalidNodeCount(nodeCount)
        }
        guard framesPerSample > 0 else {
            throw GraphFFIBaselineError.invalidFrameCount(framesPerSample)
        }
        guard warmupFrames >= 0 else {
            throw GraphFFIBaselineError.invalidFrameCount(warmupFrames)
        }

        let measured = try measure(
            sampleCount: sampleCount,
            nodeCount: nodeCount,
            framesPerSample: framesPerSample,
            warmupFrames: warmupFrames,
            width: width,
            height: height
        )

        return try BenchmarkRunRecorder.record(
            suite: "R15 Renderer FPS Baseline",
            measurement: "renderer_fps_thermal_soak",
            unit: "frames_per_second",
            samples: measured.values,
            metadata: [
                "baseline_kind": "r15_pr11_renderer_fps",
                "fixture_status": "live_graph_renderer_frame_rate_fixture",
                "renderer_authority": "GraphEngine.render(width:height:)",
                "layer_status": "offscreen_cAMetalLayer_drawable",
                "render_status": "live_render_frame_rate",
                "thermal_soak_status": "not_five_min_thermal_soak",
                "sample_source": "focused_xcode_test_explicit_opt_in",
                "node_count": "\(nodeCount)",
                "edge_count": "\(GraphFFIBaselineRunner.fixtureEdgeCount(for: nodeCount))",
                "frames_per_sample": "\(framesPerSample)",
                "warmup_frames": "\(warmupFrames)",
                "sample_count_target": "\(sampleCount)",
                "needs_more_frame_count": "\(measured.needsMoreFrameCount)",
                "future_gate": "five_min_manual_thermal_soak_release_floor",
                "checksum": "\(measured.checksum)",
            ],
            generatedAt: generatedAt,
            resultsDirectory: resultsDirectory
        )
    }

    @inline(never)
    private static func measure(
        sampleCount: Int,
        nodeCount: Int,
        framesPerSample: Int,
        warmupFrames: Int,
        width: UInt32,
        height: UInt32
    ) throws -> (values: [Double], checksum: Int, needsMoreFrameCount: Int) {
        let fixture = try GraphFFIBaselineRunner.makeFixture(nodeCount: nodeCount)
        var checksum = fixture.nodeIDs.reduce(fixture.edgeCount) { $0 &+ $1.utf8.count }
        var needsMoreFrameCount = 0

        for _ in 0..<warmupFrames {
            if fixture.engine.render(width: width, height: height) {
                needsMoreFrameCount += 1
            }
        }

        var values: [Double] = []
        values.reserveCapacity(sampleCount)
        for _ in 0..<sampleCount {
            let start = ContinuousClock.now
            for _ in 0..<framesPerSample {
                if fixture.engine.render(width: width, height: height) {
                    needsMoreFrameCount += 1
                }
            }
            let duration = (ContinuousClock.now - start).secondsAsDouble
            let fps = Double(framesPerSample) / max(duration, .leastNonzeroMagnitude)
            values.append(fps)
            checksum &+= Int(fps.rounded()) &+ needsMoreFrameCount
        }

        fixture.engine.pause()
        return (values, checksum, needsMoreFrameCount)
    }
}

@Suite("R15 Graph FFI bridge baseline")
@MainActor
struct GraphFFIBenchmarkTests {
    @Test("Graph FFI bridge baseline writes finite decodable report")
    func graphFFIBridgeBaselineWritesFiniteDecodableReport() throws {
        let configuration = configuredResultsDirectory()
        let resultsDirectory = configuration.url
        let shouldCleanUp = configuration.removeAfterRun
        defer {
            if shouldCleanUp {
                try? FileManager.default.removeItem(at: resultsDirectory)
            }
        }

        let outputURL = try GraphFFIBaselineRunner.run(resultsDirectory: resultsDirectory)

        #expect(outputURL.lastPathComponent == GraphFFIBaselineRunner.expectedReportFilename)

        let data = try Data(contentsOf: outputURL)
        let report = try JSONDecoder().decode(BenchmarkRunReport.self, from: data)
        #expect(report.schema_version == 1)
        #expect(report.generated_at == "2026-05-02T00:00:00.000Z")
        #expect(report.suite == "R15 Graph FFI Bridge Baseline")
        #expect(report.measurement == "graph_ffi_bridge_fixture_250")
        #expect(report.unit == "nanoseconds_per_fixture_roundtrip")
        #expect(report.sample_count == 5)
        #expect(report.samples.count == report.sample_count)
        for sample in report.samples {
            #expect(sample.isFinite)
            #expect(sample >= 0)
        }
        #expect(report.max >= report.min)
        #expect(report.metadata["baseline_kind"] == "r15_pr7_graph_ffi_bridge")
        #expect(report.metadata["fixture_status"] == "live_graph_engine_ffi_fixture")
        #expect(report.metadata["graph_engine_authority"] == "GraphEngine(device:layer:)")
        #expect(report.metadata["surface_set"] == "create_add_commit_search_position_visibility_force")
        #expect(report.metadata["render_status"] == "not_live_render_frame_rate")
        #expect(report.metadata["node_count"] == "250")
        #expect(report.metadata["sample_count_target"] == "5")
        #expect(report.metadata["checksum"]?.isEmpty == false)
    }

    @Test("Graph FFI bridge fixture reaches live search and node position surfaces")
    func graphFFIBridgeFixtureReachesLiveSearchAndNodePositionSurfaces() throws {
        let checksum = try GraphFFIBaselineRunner.singleFixtureRoundTrip(nodeCount: 32)

        #expect(checksum != 0)
    }

    @Test("Graph FFI bridge baseline rejects invalid counts")
    func graphFFIBridgeBaselineRejectsInvalidCounts() throws {
        do {
            _ = try GraphFFIBaselineRunner.run(
                resultsDirectory: FileManager.default.temporaryDirectory,
                sampleCount: 0
            )
            Issue.record("Expected invalidSampleCount for zero samples")
        } catch GraphFFIBaselineError.invalidSampleCount(let count) {
            #expect(count == 0)
        } catch {
            Issue.record("Expected invalidSampleCount, got \(error)")
        }

        do {
            _ = try GraphFFIBaselineRunner.run(
                resultsDirectory: FileManager.default.temporaryDirectory,
                nodeCount: 1
            )
            Issue.record("Expected invalidNodeCount for one node")
        } catch GraphFFIBaselineError.invalidNodeCount(let count) {
            #expect(count == 1)
        } catch {
            Issue.record("Expected invalidNodeCount, got \(error)")
        }
    }

    @Test("renderer FPS baseline writes finite decodable report when explicitly enabled")
    func rendererFPSBaselineWritesFiniteDecodableReportWhenExplicitlyEnabled() throws {
        guard GraphRendererFPSBaselineRunner.isExplicitlyEnabled() else {
            return
        }

        let configuration = configuredResultsDirectory()
        let resultsDirectory = configuration.url
        let shouldCleanUp = configuration.removeAfterRun
        defer {
            if shouldCleanUp {
                try? FileManager.default.removeItem(at: resultsDirectory)
            }
        }

        let outputURL = try GraphRendererFPSBaselineRunner.run(resultsDirectory: resultsDirectory)

        #expect(outputURL.lastPathComponent == GraphRendererFPSBaselineRunner.expectedReportFilename)

        let data = try Data(contentsOf: outputURL)
        let report = try JSONDecoder().decode(BenchmarkRunReport.self, from: data)
        #expect(report.schema_version == 1)
        #expect(report.generated_at == "2026-05-02T00:00:00.000Z")
        #expect(report.suite == "R15 Renderer FPS Baseline")
        #expect(report.measurement == "renderer_fps_thermal_soak")
        #expect(report.unit == "frames_per_second")
        #expect(report.sample_count == 5)
        #expect(report.samples.count == report.sample_count)
        for sample in report.samples {
            #expect(sample.isFinite)
            #expect(sample > 0)
        }
        #expect(report.max >= report.min)
        #expect(report.metadata["baseline_kind"] == "r15_pr11_renderer_fps")
        #expect(report.metadata["fixture_status"] == "live_graph_renderer_frame_rate_fixture")
        #expect(report.metadata["renderer_authority"] == "GraphEngine.render(width:height:)")
        #expect(report.metadata["layer_status"] == "offscreen_cAMetalLayer_drawable")
        #expect(report.metadata["render_status"] == "live_render_frame_rate")
        #expect(report.metadata["thermal_soak_status"] == "not_five_min_thermal_soak")
        #expect(report.metadata["sample_source"] == "focused_xcode_test_explicit_opt_in")
        #expect(report.metadata["node_count"] == "250")
        #expect(report.metadata["frames_per_sample"] == "120")
        #expect(report.metadata["warmup_frames"] == "12")
        #expect(report.metadata["checksum"]?.isEmpty == false)
    }

    @Test("renderer FPS baseline rejects invalid counts")
    func rendererFPSBaselineRejectsInvalidCounts() throws {
        do {
            _ = try GraphRendererFPSBaselineRunner.run(
                resultsDirectory: FileManager.default.temporaryDirectory,
                sampleCount: 0
            )
            Issue.record("Expected invalidSampleCount for zero samples")
        } catch GraphFFIBaselineError.invalidSampleCount(let count) {
            #expect(count == 0)
        } catch {
            Issue.record("Expected invalidSampleCount, got \(error)")
        }

        do {
            _ = try GraphRendererFPSBaselineRunner.run(
                resultsDirectory: FileManager.default.temporaryDirectory,
                framesPerSample: 0
            )
            Issue.record("Expected invalidFrameCount for zero frames")
        } catch GraphFFIBaselineError.invalidFrameCount(let count) {
            #expect(count == 0)
        } catch {
            Issue.record("Expected invalidFrameCount, got \(error)")
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

private extension Duration {
    nonisolated var secondsAsDouble: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
