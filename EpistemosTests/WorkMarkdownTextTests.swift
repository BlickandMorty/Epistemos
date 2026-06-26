import Foundation
import Testing
@testable import Epistemos

// Verifies the transcript markdown splitter (#5): prose vs fenced code, streaming-safe unclosed fence, empty filtering.
@Suite("Work markdown text — fenced-code split (transcript render)")
struct WorkMarkdownTextTests {
    private func fence(_ inner: String) -> String { "```\n\(inner)\n```" }

    @Test("plain prose → one prose segment")
    func plainProse() {
        #expect(WorkMarkdownText.parse("hello there") == [.prose("hello there")])
    }

    @Test("prose + code + prose → three ordered segments")
    func proseCodeProse() {
        let text = "before\n\(fence("let x = 1"))\nafter"
        #expect(WorkMarkdownText.parse(text) == [.prose("before"), .code("let x = 1"), .prose("after")])
    }

    @Test("unclosed trailing fence → in-progress code segment (streaming-safe)")
    func unclosedFence() {
        let text = "intro\n```\npartial code mid-stream"
        let segments = WorkMarkdownText.parse(text)
        #expect(segments.first == .prose("intro"))
        #expect(segments.last == .code("partial code mid-stream"))
    }

    @Test("empty / whitespace-only prose is filtered; empty code dropped")
    func filtersEmpty() {
        // leading blank lines around a code block shouldn't yield empty prose segments
        #expect(WorkMarkdownText.parse("\n\n\(fence("code"))\n\n") == [.code("code")])
        #expect(WorkMarkdownText.parse("").isEmpty)
    }

    @Test("inlineMarkdown never throws — literal fallback")
    func inlineFallback() {
        #expect(!String(WorkMarkdownText.inlineMarkdown("**bold** and `code`").characters).isEmpty)
        #expect(String(WorkMarkdownText.inlineMarkdown("plain").characters) == "plain")
    }
}
