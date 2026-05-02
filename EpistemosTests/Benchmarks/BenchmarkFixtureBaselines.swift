import Foundation
import Testing

nonisolated enum BenchmarkFixtureBaselineError: Error, Equatable {
    case invalidIterations(Int)
    case markdownParseFailed(UInt8)
}

nonisolated struct BenchmarkFixtureBaselineRunner {
    static let stableGeneratedAt = Date(timeIntervalSince1970: 1_777_593_600)

    static func run(
        resultsDirectory: URL,
        generatedAt: Date = stableGeneratedAt,
        iterations: Int = 7
    ) throws -> [URL] {
        guard iterations > 0 else {
            throw BenchmarkFixtureBaselineError.invalidIterations(iterations)
        }

        var outputURLs: [URL] = []
        outputURLs.reserveCapacity(3)
        outputURLs.append(try recordGraphPayloadBaseline(
            resultsDirectory: resultsDirectory,
            generatedAt: generatedAt,
            iterations: iterations
        ))
        outputURLs.append(try recordMarkdownParserBaseline(
            resultsDirectory: resultsDirectory,
            generatedAt: generatedAt,
            iterations: iterations
        ))
        outputURLs.append(try recordCodeTokenParserBaseline(
            resultsDirectory: resultsDirectory,
            generatedAt: generatedAt,
            iterations: iterations
        ))
        return outputURLs
    }

    private static func recordGraphPayloadBaseline(
        resultsDirectory: URL,
        generatedAt: Date,
        iterations: Int
    ) throws -> URL {
        let nodeCount = 750
        let samples = try measure(iterations: iterations) {
            buildGraphPayloadNodeCount(nodeCount)
        }

        return try BenchmarkRunRecorder.record(
            suite: "R15 Fixture Baselines",
            measurement: "graph_payload_construction_750_nodes",
            unit: "seconds",
            samples: samples.values,
            metadata: fixtureMetadata([
                "fixture_name": "graph_payload_construction",
                "payload_nodes": "\(nodeCount)",
                "payload_edges": "\(nodeCount - 1)",
                "checksum": "\(samples.checksum)",
            ]),
            generatedAt: generatedAt,
            resultsDirectory: resultsDirectory
        )
    }

    private static func recordMarkdownParserBaseline(
        resultsDirectory: URL,
        generatedAt: Date,
        iterations: Int
    ) throws -> URL {
        let sectionCount = 160
        let markdown = markdownFixture(sectionCount: sectionCount)
        let samples = try measure(iterations: iterations) {
            Int(try parseMarkdownSpanCount(markdown))
        }

        return try BenchmarkRunRecorder.record(
            suite: "R15 Fixture Baselines",
            measurement: "markdown_parser_160_sections",
            unit: "seconds",
            samples: samples.values,
            metadata: fixtureMetadata([
                "fixture_name": "markdown_parser",
                "payload_bytes": "\(markdown.utf8.count)",
                "payload_sections": "\(sectionCount)",
                "checksum": "\(samples.checksum)",
            ]),
            generatedAt: generatedAt,
            resultsDirectory: resultsDirectory
        )
    }

    private static func recordCodeTokenParserBaseline(
        resultsDirectory: URL,
        generatedAt: Date,
        iterations: Int
    ) throws -> URL {
        let lineCount = 1_200
        let code = swiftCodeFixture(lines: lineCount)
        let samples = try measure(iterations: iterations) {
            Int(parseCodeTokenCount(code, language: "swift"))
        }

        return try BenchmarkRunRecorder.record(
            suite: "R15 Fixture Baselines",
            measurement: "code_token_parser_1200_lines",
            unit: "seconds",
            samples: samples.values,
            metadata: fixtureMetadata([
                "fixture_name": "code_token_parser",
                "payload_bytes": "\(code.utf8.count)",
                "payload_lines": "\(lineCount)",
                "language": "swift",
                "checksum": "\(samples.checksum)",
            ]),
            generatedAt: generatedAt,
            resultsDirectory: resultsDirectory
        )
    }

    private static func fixtureMetadata(_ extra: [String: String]) -> [String: String] {
        var metadata = [
            "baseline_kind": "fixture_pr2_real",
            "fixture_status": "real_local_fixture",
            "sample_source": "focused_xcode_test",
        ]
        metadata.merge(extra) { _, new in new }
        return metadata
    }

    @inline(never)
    private static func measure(
        iterations: Int,
        body: () throws -> Int
    ) throws -> (values: [Double], checksum: Int) {
        var values: [Double] = []
        values.reserveCapacity(iterations)
        var checksum = 0

        for _ in 0..<iterations {
            let start = ContinuousClock.now
            checksum &+= try body()
            let duration = ContinuousClock.now - start
            values.append(duration.secondsAsDouble)
        }

        return (values, checksum)
    }

    @inline(never)
    private static func buildGraphPayloadNodeCount(_ nodeCount: Int) -> Int {
        struct GraphPayloadNode {
            let id: String
            let x: Float
            let y: Float
            let type: UInt8
            let linkCount: UInt32
            let label: String
        }

        struct GraphPayloadEdge {
            let source: String
            let target: String
            let kind: UInt8
        }

        var nodes: [GraphPayloadNode] = []
        var edges: [GraphPayloadEdge] = []
        nodes.reserveCapacity(nodeCount)
        edges.reserveCapacity(max(0, nodeCount - 1))

        for index in 0..<nodeCount {
            let id = "node-\(String(format: "%06d", index))"
            nodes.append(GraphPayloadNode(
                id: id,
                x: Float(index) * 0.125,
                y: Float(index) * 0.25,
                type: UInt8(index % 8),
                linkCount: UInt32(index % 13),
                label: "Fixture Node \(index)"
            ))

            if index > 0 {
                edges.append(GraphPayloadEdge(
                    source: "node-\(String(format: "%06d", index - 1))",
                    target: id,
                    kind: UInt8(index % 12)
                ))
            }
        }

        return nodes.reduce(edges.count) { partial, node in
            partial
                &+ node.id.utf8.count
                &+ node.label.utf8.count
                &+ Int(node.type)
                &+ Int(node.linkCount)
                &+ Int(node.x.rounded())
                &+ Int(node.y.rounded())
        }
    }

    @inline(never)
    private static func parseMarkdownSpanCount(_ markdown: String) throws -> UInt32 {
        try markdown.withCString { pointer in
            var spansPointer: UnsafeMutablePointer<StyleSpan>?
            var count: UInt32 = 0
            let result = markdown_parse(pointer, UInt32(markdown.utf8.count), &spansPointer, &count)
            if let spans = spansPointer {
                markdown_free_spans(spans, count)
            }
            guard result == 0 else {
                throw BenchmarkFixtureBaselineError.markdownParseFailed(result)
            }
            return count
        }
    }

    @inline(never)
    private static func parseCodeTokenCount(_ code: String, language: String) -> UInt32 {
        let maxTokens: UInt32 = 65_536
        let buffer = UnsafeMutablePointer<CodeToken>.allocate(capacity: Int(maxTokens))
        defer {
            buffer.deallocate()
        }

        return language.withCString { languagePointer in
            code.withCString { codePointer in
                markdown_parse_code_tokens(
                    codePointer,
                    UInt32(code.utf8.count),
                    languagePointer,
                    buffer,
                    maxTokens
                )
            }
        }
    }

    private static func markdownFixture(sectionCount: Int) -> String {
        var markdown = ""
        markdown.reserveCapacity(sectionCount * 96)
        for index in 0..<sectionCount {
            markdown += """
            ## Section \(index)

            Paragraph with **bold**, *italic*, `code`, [[wikilink-\(index)]], and #tag-\(index % 7).

            - Evidence item \(index)
            - Follow-up item \(index + 1)

            """
        }
        return markdown
    }

    private static func swiftCodeFixture(lines: Int) -> String {
        var code = "import Foundation\n\n"
        code.reserveCapacity(lines * 48)
        for index in 0..<lines {
            switch index % 6 {
            case 0:
                code += "struct FixtureItem\(index) {\n"
            case 1:
                code += "    let id: String = \"item_\(index)\"\n"
            case 2:
                code += "    let value: Int = \(index)\n"
            case 3:
                code += "    func score() -> Int { value * 2 }\n"
            case 4:
                code += "}\n\n"
            default:
                code += "let fixtureValue\(index) = FixtureItem\(max(0, index - 5))().score()\n"
            }
        }
        return code
    }
}

@Suite("R15 Fixture Baselines")
nonisolated struct BenchmarkFixtureBaselineTests {
    @Test("fixture baseline runner writes finite decodable reports")
    func fixtureBaselineRunnerWritesFiniteDecodableReports() throws {
        let configuration = configuredResultsDirectory()
        let resultsDirectory = configuration.url
        let shouldCleanUp = configuration.removeAfterRun
        defer {
            if shouldCleanUp {
                try? FileManager.default.removeItem(at: resultsDirectory)
            }
        }

        let outputURLs = try BenchmarkFixtureBaselineRunner.run(resultsDirectory: resultsDirectory)

        #expect(outputURLs.count == 3)
        for outputURL in outputURLs {
            let data = try Data(contentsOf: outputURL)
            let report = try JSONDecoder().decode(BenchmarkRunReport.self, from: data)
            #expect(report.schema_version == 1)
            #expect(report.suite == "R15 Fixture Baselines")
            #expect(report.unit == "seconds")
            #expect(report.sample_count == 7)
            #expect(report.samples.count == report.sample_count)
            for sample in report.samples {
                #expect(sample.isFinite)
            }
            #expect(report.min >= 0)
            #expect(report.max >= report.min)
            #expect(report.metadata["baseline_kind"] == "fixture_pr2_real")
            #expect(report.metadata["fixture_status"] == "real_local_fixture")
            #expect(report.metadata["sample_source"] == "focused_xcode_test")
            #expect(report.metadata["checksum"]?.isEmpty == false)
        }
    }

    @Test("fixture baseline runner rejects invalid iteration counts")
    func fixtureBaselineRunnerRejectsInvalidIterationCounts() throws {
        #expect(throws: BenchmarkFixtureBaselineError.invalidIterations(0)) {
            try BenchmarkFixtureBaselineRunner.run(
                resultsDirectory: FileManager.default.temporaryDirectory,
                iterations: 0
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

private extension Duration {
    nonisolated var secondsAsDouble: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
