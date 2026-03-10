import Testing
import AppKit
import os
@testable import Epistemos

// MARK: - TK1 vs TK2 Performance Benchmarks
// Comparative timing tests for TextKit 1 (MarkdownTextStorage) vs TextKit 2
// (ProseTextView2 + MarkdownContentStorage). Uses ContinuousClock for high-
// resolution wall-clock measurement. Results are informational — logged via
// os.Logger — with no strict pass/fail thresholds.

private let benchLog = Logger(subsystem: "com.epistemos.tests", category: "TK2Benchmark")

// MARK: - Markdown Generator

private func generateMarkdown(lines: Int) -> String {
    var parts: [String] = []
    parts.reserveCapacity(lines)
    for i in 0..<lines {
        switch i % 10 {
        case 0: parts.append("# Heading \(i)")
        case 1: parts.append("Normal paragraph with **bold** and *italic* text.")
        case 2: parts.append("- List item with `inline code`")
        case 3: parts.append("> Blockquote with [[wikilink]]")
        case 4: parts.append("- [ ] Task item \(i)")
        case 5: parts.append("Another paragraph with ~~strikethrough~~ and [link](url).")
        case 6: parts.append("## Sub Heading \(i)")
        case 7: parts.append("```swift")
        case 8: parts.append("let value = \(i)")
        default: parts.append("```")
        }
    }
    return parts.joined(separator: "\n")
}

// MARK: - TK1 / TK2 Load Helpers

/// Load content into a TK1 MarkdownTextStorage and return the elapsed duration.
private func tk1Load(_ content: String) -> Duration {
    let clock = ContinuousClock()
    let elapsed = clock.measure {
        let storage = MarkdownTextStorage()
        storage.isDark = false
        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: content)
        storage.endEditing()
    }
    return elapsed
}

/// Load content into a TK2 ProseTextView2 and return the elapsed duration.
private func tk2Load(_ content: String) -> Duration {
    let clock = ContinuousClock()
    let elapsed = clock.measure {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.textStorage?.setAttributedString(NSAttributedString(string: content))
        tv.reparseAndInvalidate()
    }
    return elapsed
}

// MARK: - Suite: TK2 Benchmarks

@Suite("TK2 Benchmark — TK1 vs TK2 Performance")
struct TextKit2BenchmarkTests {

    // MARK: - Initial Load 1K

    @Test("Initial load — 1K lines")
    @MainActor func initialLoad1K() {
        let content = generateMarkdown(lines: 1_000)
        let tk1Time = tk1Load(content)
        let tk2Time = tk2Load(content)

        benchLog.info("1K load — TK1=\(tk1Time), TK2=\(tk2Time)")
        #expect(true, "1K load — TK1=\(tk1Time), TK2=\(tk2Time)")
    }

    // MARK: - Initial Load 10K

    @Test("Initial load — 10K lines")
    @MainActor func initialLoad10K() {
        let content = generateMarkdown(lines: 10_000)
        let tk1Time = tk1Load(content)
        let tk2Time = tk2Load(content)

        benchLog.info("10K load — TK1=\(tk1Time), TK2=\(tk2Time)")
        #expect(true, "10K load — TK1=\(tk1Time), TK2=\(tk2Time)")
    }

    // MARK: - Per-Keystroke Highlight

    @Test("Per-keystroke highlight — 100 keystrokes")
    @MainActor func perKeystrokeHighlight() {
        let content = generateMarkdown(lines: 500)
        let clock = ContinuousClock()

        // TK1: load then insert 100 characters one at a time
        let tk1Storage = MarkdownTextStorage()
        tk1Storage.isDark = false
        tk1Storage.beginEditing()
        tk1Storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: content)
        tk1Storage.endEditing()

        let tk1Time = clock.measure {
            for i in 0..<100 {
                let loc = min(i, tk1Storage.length)
                tk1Storage.beginEditing()
                tk1Storage.replaceCharacters(in: NSRange(location: loc, length: 0), with: "x")
                tk1Storage.endEditing()
            }
        }

        // TK2: load then insert 100 characters one at a time
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.textStorage?.setAttributedString(NSAttributedString(string: content))
        tv.reparseAndInvalidate()

        let tk2Time = clock.measure {
            for i in 0..<100 {
                guard let ts = tv.textStorage else { break }
                let loc = min(i, ts.length)
                ts.replaceCharacters(in: NSRange(location: loc, length: 0), with: "x")
                tv.reparseAndInvalidate()
            }
        }

        benchLog.info("100 keystrokes — TK1=\(tk1Time), TK2=\(tk2Time)")
        #expect(true, "100 keystrokes — TK1=\(tk1Time), TK2=\(tk2Time)")
    }

    // MARK: - Page Swap

    @Test("Page swap — 20 round-trips between 2 pages")
    @MainActor func pageSwap() {
        let page1 = generateMarkdown(lines: 200)
        let page2 = generateMarkdown(lines: 300)
        let clock = ContinuousClock()

        // TK1: uses PageStoragePool
        let tk1Time = clock.measure {
            for _ in 0..<20 {
                _ = PageStoragePool.shared.getOrCreate(
                    pageId: "bench-p1", bodyText: page1, isDark: false
                )
                _ = PageStoragePool.shared.getOrCreate(
                    pageId: "bench-p2", bodyText: page2, isDark: false
                )
            }
        }

        // TK2: in-place replaceCharacters on a single view
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.textStorage?.setAttributedString(NSAttributedString(string: page1))
        tv.reparseAndInvalidate()

        let tk2Time = clock.measure {
            for i in 0..<20 {
                let body = (i % 2 == 0) ? page2 : page1
                guard let ts = tv.textStorage else { break }
                ts.replaceCharacters(
                    in: NSRange(location: 0, length: ts.length), with: body
                )
                tv.reparseAndInvalidate()
            }
        }

        // Cleanup pool entries
        PageStoragePool.shared.remove(pageId: "bench-p1")
        PageStoragePool.shared.remove(pageId: "bench-p2")

        benchLog.info("20 page swaps — TK1=\(tk1Time), TK2=\(tk2Time)")
        #expect(true, "20 page swaps — TK1=\(tk1Time), TK2=\(tk2Time)")
    }
}
