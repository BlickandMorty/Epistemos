import Foundation
import os
import Testing

// MARK: - Code Editor Benchmark Tests
//
// os_signpost-based timing harness for code editor FFI surfaces.
// Measures keystroke-to-highlight latency components, file open time
// simulation, and Markdown parser FFI overhead at various document sizes.
//
// Disabled by default so CI skips them. Run manually:
//   xcodebuild test -scheme Epistemos -only-testing:EpistemosTests/CodeEditorBenchmarkTests

private let benchLog = OSSignposter(subsystem: "com.epistemos.bench", category: "editor")
private let benchLogger = Logger(subsystem: "com.epistemos.bench", category: "editor")

@Suite("Code Editor Benchmarks", .disabled("Manual benchmark suite — run via Instruments"))
struct CodeEditorBenchmarkTests {

    // MARK: - Helpers

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

    private func syntheticSwiftFile(lines: Int) -> String {
        var result = "import Foundation\n\n"
        for i in 0..<lines {
            switch i % 6 {
            case 0:
                result += "struct Item\(i) {\n"
            case 1:
                result += "    var name: String = \"item_\(i)\"\n"
            case 2:
                result += "    var value: Int = \(i)\n"
            case 3:
                result += "    func compute() -> Int { value * 2 }\n"
            case 4:
                result += "}\n\n"
            default:
                result += "// Line \(i): synthetic benchmark content\n"
            }
        }
        return result
    }

    private func parseCodeTokens(_ code: String, language: String = "swift") -> UInt32 {
        let maxTokens: UInt32 = 65_536
        let buffer = UnsafeMutablePointer<CodeToken>.allocate(capacity: Int(maxTokens))
        defer { buffer.deallocate() }

        return language.withCString { languagePtr in
            code.withCString { codePtr in
                markdown_parse_code_tokens(
                    codePtr,
                    UInt32(code.utf8.count),
                    languagePtr,
                    buffer,
                    maxTokens
                )
            }
        }
    }

    // MARK: - 1. Markdown Parse at Editor Scales

    @Test func markdownParse1K() {
        let markdown = (0..<250).map { i in
            "## Section \(i)\n\nParagraph with **bold** and `code` text.\n\n"
        }.joined()
        #expect(markdown.count > 1000)

        let median = measure("markdown_parse_editor_1K_lines") {
            guard let cStr = markdown.cString(using: .utf8) else { return }
            var spansPtr: UnsafeMutablePointer<StyleSpan>?
            var count: UInt32 = 0
            let result = markdown_parse(cStr, UInt32(cStr.count - 1), &spansPtr, &count)
            if result == 0, let spans = spansPtr {
                markdown_free_spans(spans, count)
            }
        }
        #expect(median < 0.5, "Markdown parse for ~1K lines should complete in < 500ms")
    }

    @Test func markdownParse10K() {
        let markdown = (0..<2500).map { i in
            "## Section \(i)\n\nParagraph with **bold** and `code` text.\n\n"
        }.joined()

        let median = measure("markdown_parse_editor_10K_lines", iterations: 5) {
            guard let cStr = markdown.cString(using: .utf8) else { return }
            var spansPtr: UnsafeMutablePointer<StyleSpan>?
            var count: UInt32 = 0
            let result = markdown_parse(cStr, UInt32(cStr.count - 1), &spansPtr, &count)
            if result == 0, let spans = spansPtr {
                markdown_free_spans(spans, count)
            }
        }
        #expect(median < 2.0, "Markdown parse for ~10K lines should complete in < 2s")
    }

    @Test func markdownParse50K() {
        let markdown = (0..<12500).map { i in
            "## Section \(i)\n\nParagraph with **bold** and `code` text.\n\n"
        }.joined()

        let median = measure("markdown_parse_editor_50K_lines", iterations: 3) {
            guard let cStr = markdown.cString(using: .utf8) else { return }
            var spansPtr: UnsafeMutablePointer<StyleSpan>?
            var count: UInt32 = 0
            let result = markdown_parse(cStr, UInt32(cStr.count - 1), &spansPtr, &count)
            if result == 0, let spans = spansPtr {
                markdown_free_spans(spans, count)
            }
        }
        #expect(median < 10.0, "Markdown parse for ~50K lines should complete in < 10s")
    }

    // MARK: - 2. Code Token Parse via FFI

    @Test func codeTokenParse1K() {
        let code = syntheticSwiftFile(lines: 1000)

        let median = measure("code_token_parse_1K_lines") {
            _ = parseCodeTokens(code)
        }
        #expect(median < 0.1, "Code token parse for 1K lines should complete in < 100ms")
    }

    @Test func codeTokenParse10K() {
        let code = syntheticSwiftFile(lines: 10000)

        let median = measure("code_token_parse_10K_lines", iterations: 5) {
            _ = parseCodeTokens(code)
        }
        #expect(median < 1.0, "Code token parse for 10K lines should complete in < 1s")
    }

    // MARK: - 3. String Binding Simulation (the O(n) path)

    @Test func stringBindingSync1K() {
        let code = syntheticSwiftFile(lines: 1000)

        let median = measure("string_binding_sync_1K") {
            let nsString = code as NSString
            _ = nsString.length
            _ = nsString.substring(with: NSRange(location: 0, length: min(500, nsString.length)))
            let copy = String(code)
            _ = copy.count
        }
        #expect(median < 0.01, "String binding sync for 1K lines should complete in < 10ms")
    }

    @Test func stringBindingSync10K() {
        let code = syntheticSwiftFile(lines: 10000)

        let median = measure("string_binding_sync_10K") {
            let nsString = code as NSString
            _ = nsString.length
            _ = nsString.substring(with: NSRange(location: 0, length: min(500, nsString.length)))
            let copy = String(code)
            _ = copy.count
        }
        #expect(median < 0.05, "String binding sync for 10K lines should complete in < 50ms")
    }

    @Test func stringBindingSync50K() {
        let code = syntheticSwiftFile(lines: 50000)

        let median = measure("string_binding_sync_50K", iterations: 5) {
            let nsString = code as NSString
            _ = nsString.length
            _ = nsString.substring(with: NSRange(location: 0, length: min(500, nsString.length)))
            let copy = String(code)
            _ = copy.count
        }
        #expect(median < 0.2, "String binding sync for 50K lines should complete in < 200ms")
    }

    // MARK: - 4. NSAttributedString Attribute Application (Viewport Batch)

    @Test func attributeApplication() {
        let viewportText = String(repeating: "func compute(_ x: Int) -> Bool { return x > 0 }\n", count: 60)
        let storage = NSTextStorage(string: viewportText)

        struct TokenSpan {
            let location: Int
            let length: Int
            let color: NSColor
        }

        var spans: [TokenSpan] = []
        spans.reserveCapacity(300)
        var offset = 0
        let lineLen = 49
        for _ in 0..<60 {
            spans.append(TokenSpan(location: offset, length: 4, color: .systemPurple))
            spans.append(TokenSpan(location: offset + 13, length: 3, color: .systemBlue))
            spans.append(TokenSpan(location: offset + 21, length: 4, color: .systemBlue))
            spans.append(TokenSpan(location: offset + 29, length: 6, color: .systemPurple))
            offset += lineLen
        }

        let median = measure("attribute_application_viewport_60_lines") {
            storage.beginEditing()
            for span in spans {
                let range = NSRange(location: span.location, length: span.length)
                guard range.upperBound <= storage.length else { continue }
                storage.addAttribute(.foregroundColor, value: span.color, range: range)
            }
            storage.endEditing()
        }
        #expect(median < 0.016, "Attribute application for 60-line viewport should complete in < 16ms (one frame)")
    }

    // MARK: - 5. Memory Growth Simulation (Repeated Edit + Parse)

    @Test func repeatedEditParseMemory() {
        var code = syntheticSwiftFile(lines: 1000)

        let median = measure("repeated_edit_parse_100_iterations", iterations: 3) {
            for i in 0..<100 {
                let insertion = "\n    let x\(i) = \(i) // inserted line\n"
                let insertionPoint = code.index(code.startIndex, offsetBy: min(500, code.count))
                code.insert(contentsOf: insertion, at: insertionPoint)

                _ = parseCodeTokens(code)
            }
        }
        #expect(median < 10.0, "100 edit-parse cycles on 1K-line file should complete in < 10s")
    }
}
