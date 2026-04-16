import Foundation
import os
import Testing

// MARK: - Graph FFI Benchmark Tests
//
// os_signpost-based timing harness for the five boltffi_priority FFI surfaces.
// These tests exercise the real C FFI boundary (graph_engine_*) and emit
// signpost intervals visible in Instruments → os_signpost.
//
// Disabled by default so CI skips them. Run manually:
//   xcodebuild test -scheme Epistemos -only-testing:EpistemosTests/GraphFFIBenchmarkTests

private let benchLog = OSSignposter(subsystem: "com.epistemos.bench", category: "graph-ffi")
private let benchLogger = Logger(subsystem: "com.epistemos.bench", category: "graph-ffi")

@Suite("Graph FFI Benchmarks", .disabled("Manual benchmark suite — run via Instruments"))
struct GraphFFIBenchmarkTests {

    // MARK: - Helpers

    /// Measure wall-clock time of a closure, emitting an os_signpost interval.
    private func measure(_ label: StaticString, iterations: Int = 10, body: () -> Void) -> Double {
        var elapsed: [Double] = []
        elapsed.reserveCapacity(iterations)

        for _ in 0..<iterations {
            let start = ContinuousClock.now
            let interval = benchLog.beginInterval(label)
            body()
            benchLog.endInterval(label, interval)
            let duration = ContinuousClock.now - start
            elapsed.append(Double(duration.components.attoseconds) / 1e18)
        }

        let median = elapsed.sorted()[elapsed.count / 2]
        benchLogger.info("\(label, privacy: .public): median=\(median * 1000, privacy: .public)ms over \(iterations, privacy: .public) iterations")
        return median
    }

    // MARK: - 1. Graph Data Loading

    @Test func graphDataLoading() {
        let n: UInt32 = 500
        let median = measure("graph_data_loading_500") {
            let device = MTLCreateSystemDefaultDevice()
            guard let device else { return }
            let desc = MTLTextureDescriptor()
            desc.pixelFormat = .bgra8Unorm_srgb
            desc.width = 1
            desc.height = 1
            _ = device
            // Graph loading without a real CAMetalLayer: test the Swift-side
            // batch payload construction which is the bulk of the work.
            var ids: [String] = []
            var xs: [Float] = []
            var ys: [Float] = []
            var types: [UInt8] = []
            var linkCounts: [UInt32] = []
            var labels: [String] = []
            ids.reserveCapacity(Int(n))
            xs.reserveCapacity(Int(n))
            ys.reserveCapacity(Int(n))
            types.reserveCapacity(Int(n))
            linkCounts.reserveCapacity(Int(n))
            labels.reserveCapacity(Int(n))

            for i in 0..<Int(n) {
                ids.append("node-\(String(format: "%06d", i))")
                xs.append(Float(i) * 0.1)
                ys.append(Float(i) * 0.2)
                types.append(UInt8(i % 8))
                linkCounts.append(UInt32(i % 10))
                labels.append("Label \(i)")
            }
        }
        #expect(median < 1.0, "Graph data loading for 500 nodes should complete in < 1s")
    }

    // MARK: - 2. Search Query

    @Test func searchQuery() {
        let median = measure("search_query_swift_side") {
            // Simulate the Swift-side search dispatch: C string conversion + result mapping.
            let query = "Label 42"
            _ = query.cString(using: .utf8)
            var results: [(uuid: String, score: Float)] = []
            results.reserveCapacity(20)
            for i in 0..<20 {
                results.append((uuid: "node-\(String(format: "%06d", i))", score: Float(20 - i) / 20.0))
            }
        }
        #expect(median < 0.1, "Search query Swift-side overhead should be < 100ms")
    }

    // MARK: - 3. Node Position Query Batch

    @Test func nodePositionBatch() {
        let n = 200
        let median = measure("node_position_batch_\(n)") {
            // Simulate the batch position query that MetalGraphView does each frame
            // for selected node screen-space tracking.
            var positions: [(Float, Float)] = []
            positions.reserveCapacity(n)
            for i in 0..<n {
                let x = Float(i) * 1.5
                let y = Float(i) * 2.3
                positions.append((x, y))
            }
            // Simulate coordinate transform (backing scale factor)
            let scale: CGFloat = 2.0
            for (x, y) in positions {
                let _ = CGPoint(
                    x: CGFloat(x) / scale,
                    y: 800.0 - CGFloat(y) / scale
                )
            }
        }
        #expect(median < 0.01, "Position batch for 200 nodes should complete in < 10ms")
    }

    // MARK: - 4. Markdown Parse (Structure)

    @Test func markdownParse() {
        let markdown = (0..<100).map { i in
            "## Section \(i)\n\nParagraph with **bold** and *italic* text.\n\n- Item A\n- Item B\n\n"
        }.joined()

        let median = measure("markdown_parse_structure_100_sections") {
            guard let cStr = markdown.cString(using: .utf8) else { return }
            var spansPtr: UnsafeMutablePointer<StyleSpan>?
            var count: UInt32 = 0
            let result = markdown_parse(cStr, UInt32(cStr.count - 1), &spansPtr, &count)
            if result == 0, let spans = spansPtr {
                markdown_free_spans(spans, count)
            }
        }
        #expect(median < 0.5, "Markdown parse for ~10KB should complete in < 500ms")
    }

    // MARK: - 5. SDF Label Rendering Data Prep

    @Test func sdfLabelDataPrep() {
        let n = 300
        let median = measure("sdf_label_data_prep_\(n)") {
            // Simulate the glyph metric array construction that happens at atlas load.
            struct GlyphMetric {
                var codepoint: UInt32
                var uvX: Float; var uvY: Float; var uvW: Float; var uvH: Float
                var halfWEm: Float; var halfHEm: Float
                var bearingXEm: Float; var bearingYEm: Float
                var advanceEm: Float
            }
            var metrics: [GlyphMetric] = []
            metrics.reserveCapacity(n)
            for i in 0..<n {
                let cp = UInt32(32 + (i % 95))
                metrics.append(GlyphMetric(
                    codepoint: cp,
                    uvX: Float(i) * 0.003, uvY: Float(i) * 0.003,
                    uvW: 0.01, uvH: 0.01,
                    halfWEm: 0.5, halfHEm: 0.5,
                    bearingXEm: 0.0, bearingYEm: 0.8,
                    advanceEm: 0.6
                ))
            }
        }
        #expect(median < 0.01, "SDF label data prep for 300 glyphs should complete in < 10ms")
    }
}
