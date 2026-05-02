import AppKit
import Foundation
import Testing

nonisolated enum EditorShellFixtureBaselineError: Error, Equatable {
    case invalidIterations(Int)
    case textKitUnavailable
}

@MainActor
enum EditorShellFixtureBaselineRunner {
    static let stableGeneratedAt = Date(timeIntervalSince1970: 1_777_593_600)

    static func run(
        resultsDirectory: URL,
        generatedAt: Date = stableGeneratedAt,
        iterations: Int = 5
    ) throws -> [URL] {
        guard iterations > 0 else {
            throw EditorShellFixtureBaselineError.invalidIterations(iterations)
        }

        var outputURLs: [URL] = []
        outputURLs.reserveCapacity(3)
        outputURLs.append(try recordMountAndLayoutBaseline(
            resultsDirectory: resultsDirectory,
            generatedAt: generatedAt,
            iterations: iterations
        ))
        outputURLs.append(try recordBatchInsertBaseline(
            resultsDirectory: resultsDirectory,
            generatedAt: generatedAt,
            iterations: iterations
        ))
        outputURLs.append(try recordViewportAttributeBaseline(
            resultsDirectory: resultsDirectory,
            generatedAt: generatedAt,
            iterations: iterations
        ))
        return outputURLs
    }

    private static func recordMountAndLayoutBaseline(
        resultsDirectory: URL,
        generatedAt: Date,
        iterations: Int
    ) throws -> URL {
        let lineCount = 1_800
        let markdown = editorMarkdownFixture(lineCount: lineCount)
        let samples = try measure(iterations: iterations) {
            let shell = try makeEditorShell(text: markdown)
            return shell.checksum
        }

        return try BenchmarkRunRecorder.record(
            suite: "R15 Editor Shell Baselines",
            measurement: "editor_shell_mount_layout_1800_lines",
            unit: "seconds",
            samples: samples.values,
            metadata: fixtureMetadata([
                "fixture_name": "editor_shell_mount_layout",
                "payload_bytes": "\(markdown.utf8.count)",
                "payload_lines": "\(lineCount)",
                "checksum": "\(samples.checksum)",
            ]),
            generatedAt: generatedAt,
            resultsDirectory: resultsDirectory
        )
    }

    private static func recordBatchInsertBaseline(
        resultsDirectory: URL,
        generatedAt: Date,
        iterations: Int
    ) throws -> URL {
        let initialLineCount = 900
        let insertCount = 96
        let markdown = editorMarkdownFixture(lineCount: initialLineCount)
        let insertedLine = "\n- captured editor-shell insertion with **bold** and [[link]]"
        let samples = try measure(iterations: iterations) {
            var shell = try makeEditorShell(text: markdown)
            guard let textStorage = shell.textView.textStorage,
                  let layoutManager = shell.textView.textLayoutManager,
                  let contentStorage = layoutManager.textContentManager as? NSTextContentStorage else {
                throw EditorShellFixtureBaselineError.textKitUnavailable
            }
            let storage: NSTextStorage = textStorage

            storage.beginEditing()
            for _ in 0..<insertCount {
                storage.replaceCharacters(in: NSRange(location: storage.length, length: 0), with: insertedLine)
            }
            storage.endEditing()
            layoutManager.ensureLayout(for: contentStorage.documentRange)
            shell.checksum = shell.textView.string.utf8.count + Int(layoutManager.usageBoundsForTextContainer.height.rounded())
            return shell.checksum
        }

        return try BenchmarkRunRecorder.record(
            suite: "R15 Editor Shell Baselines",
            measurement: "editor_shell_batch_insert_96_lines",
            unit: "seconds",
            samples: samples.values,
            metadata: fixtureMetadata([
                "fixture_name": "editor_shell_batch_insert",
                "payload_bytes": "\(markdown.utf8.count)",
                "payload_lines": "\(initialLineCount)",
                "insert_count": "\(insertCount)",
                "checksum": "\(samples.checksum)",
            ]),
            generatedAt: generatedAt,
            resultsDirectory: resultsDirectory
        )
    }

    private static func recordViewportAttributeBaseline(
        resultsDirectory: URL,
        generatedAt: Date,
        iterations: Int
    ) throws -> URL {
        let lineCount = 1_200
        let styledLineCount = 220
        let markdown = editorMarkdownFixture(lineCount: lineCount)
        let samples = try measure(iterations: iterations) {
            var shell = try makeEditorShell(text: markdown)
            guard let textStorage = shell.textView.textStorage,
                  let layoutManager = shell.textView.textLayoutManager,
                  let contentStorage = layoutManager.textContentManager as? NSTextContentStorage else {
                throw EditorShellFixtureBaselineError.textKitUnavailable
            }
            let storage: NSTextStorage = textStorage

            let ranges = viewportLineRanges(in: shell.textView.string, maxLines: styledLineCount)
            storage.beginEditing()
            for (index, range) in ranges.enumerated() {
                storage.addAttributes([
                    .foregroundColor: index.isMultiple(of: 2) ? NSColor.systemBlue : NSColor.systemGreen,
                    .font: NSFont.monospacedSystemFont(ofSize: 13, weight: index.isMultiple(of: 3) ? .semibold : .regular),
                ], range: range)
            }
            storage.endEditing()
            layoutManager.ensureLayout(for: contentStorage.documentRange)
            shell.checksum = ranges.reduce(shell.textView.string.utf8.count) { $0 + $1.length }
            return shell.checksum
        }

        return try BenchmarkRunRecorder.record(
            suite: "R15 Editor Shell Baselines",
            measurement: "editor_shell_viewport_attribute_220_lines",
            unit: "seconds",
            samples: samples.values,
            metadata: fixtureMetadata([
                "fixture_name": "editor_shell_viewport_attribute",
                "payload_bytes": "\(markdown.utf8.count)",
                "payload_lines": "\(lineCount)",
                "styled_lines": "\(styledLineCount)",
                "checksum": "\(samples.checksum)",
            ]),
            generatedAt: generatedAt,
            resultsDirectory: resultsDirectory
        )
    }

    private static func fixtureMetadata(_ extra: [String: String]) -> [String: String] {
        var metadata = [
            "baseline_kind": "editor_shell_pr3_real",
            "fixture_status": "real_appkit_textkit_fixture",
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
            values.append(duration.editorShellSeconds)
        }

        return (values, checksum)
    }

    private struct EditorShell {
        let scrollView: NSScrollView
        let textView: NSTextView
        var checksum: Int
    }

    @inline(never)
    private static func makeEditorShell(text: String) throws -> EditorShell {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 920, height: 720))
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        let textView = NSTextView(usingTextLayoutManager: true)
        textView.frame = NSRect(x: 0, y: 0, width: 820, height: 1_000)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.textContainerInset = NSSize(width: 48, height: 32)
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.string = text
        scrollView.documentView = textView

        guard let layoutManager = textView.textLayoutManager,
              let contentStorage = layoutManager.textContentManager as? NSTextContentStorage else {
            throw EditorShellFixtureBaselineError.textKitUnavailable
        }
        layoutManager.ensureLayout(for: contentStorage.documentRange)
        let checksum = text.utf8.count + Int(layoutManager.usageBoundsForTextContainer.height.rounded())
        return EditorShell(scrollView: scrollView, textView: textView, checksum: checksum)
    }

    private static func viewportLineRanges(in text: String, maxLines: Int) -> [NSRange] {
        let nsText = text as NSString
        var ranges: [NSRange] = []
        ranges.reserveCapacity(maxLines)
        var location = 0

        while location < nsText.length, ranges.count < maxLines {
            let lineRange = nsText.lineRange(for: NSRange(location: location, length: 0))
            ranges.append(lineRange)
            let nextLocation = NSMaxRange(lineRange)
            guard nextLocation > location else { break }
            location = nextLocation
        }

        return ranges
    }

    private static func editorMarkdownFixture(lineCount: Int) -> String {
        var markdown = "# Editor Shell Fixture\n\n"
        markdown.reserveCapacity(lineCount * 74)
        for index in 0..<lineCount {
            switch index % 5 {
            case 0:
                markdown += "## Section \(index)\n"
            case 1:
                markdown += "Paragraph \(index) with **strong**, `code`, [[wikilink-\(index)]], and #tag-\(index % 11).\n"
            case 2:
                markdown += "- Evidence item \(index) with source [[source-\(index % 17)]].\n"
            case 3:
                markdown += "> Quoted observation \(index) that should still layout predictably.\n"
            default:
                markdown += "Follow-up sentence \(index) closes the shell fixture paragraph.\n\n"
            }
        }
        return markdown
    }
}

@MainActor
@Suite("R15 Editor Shell Fixture Baselines")
struct EditorShellFixtureBaselineTests {
    @Test("editor shell baseline runner writes finite decodable reports")
    func editorShellBaselineRunnerWritesFiniteDecodableReports() throws {
        let configuration = configuredResultsDirectory()
        let resultsDirectory = configuration.url
        let shouldCleanUp = configuration.removeAfterRun
        defer {
            if shouldCleanUp {
                try? FileManager.default.removeItem(at: resultsDirectory)
            }
        }

        let outputURLs = try EditorShellFixtureBaselineRunner.run(resultsDirectory: resultsDirectory)

        #expect(outputURLs.count == 3)
        for outputURL in outputURLs {
            let data = try Data(contentsOf: outputURL)
            let report = try JSONDecoder().decode(BenchmarkRunReport.self, from: data)
            #expect(report.schema_version == 1)
            #expect(report.suite == "R15 Editor Shell Baselines")
            #expect(report.unit == "seconds")
            #expect(report.sample_count == 5)
            #expect(report.samples.count == report.sample_count)
            for sample in report.samples {
                #expect(sample.isFinite)
            }
            #expect(report.min >= 0)
            #expect(report.max >= report.min)
            #expect(report.metadata["baseline_kind"] == "editor_shell_pr3_real")
            #expect(report.metadata["fixture_status"] == "real_appkit_textkit_fixture")
            #expect(report.metadata["sample_source"] == "focused_xcode_test")
            #expect(report.metadata["checksum"]?.isEmpty == false)
        }
    }

    @Test("editor shell baseline runner rejects invalid iteration counts")
    func editorShellBaselineRunnerRejectsInvalidIterationCounts() throws {
        #expect(throws: EditorShellFixtureBaselineError.invalidIterations(0)) {
            try EditorShellFixtureBaselineRunner.run(
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
    var editorShellSeconds: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
