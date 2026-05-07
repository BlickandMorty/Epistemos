import Foundation
import Testing

@testable import Epistemos

/// T+8 Phase-S items 2 + 3 unit tests
/// (per `docs/CODE_EDITOR_POLISH_SCOPE.md`).
///
/// - `CodeEditorContentDebouncer` (item 2): coalesces rapid keystrokes
///   to a single delivery after a 300 ms quiet window.
/// - `OutlineParserCache` (item 3): hash-keyed memoization of
///   `OutlineParser.parse` so repeated refreshes on unchanged content
///   short-circuit instead of re-walking the document.
@Suite("Code editor Phase-S polish (T+8 items 2 + 3)")
nonisolated struct CodeEditorPolishTests {

    // MARK: - OutlineParserCache (item 3)

    @Test("Cache hits when (content, language) unchanged")
    @MainActor
    func cacheHitsOnIdenticalCall() {
        let cache = OutlineParserCache()
        let content = """
        // a
        func foo() {}
        struct Bar {}
        """
        let first = cache.parse(content: content, language: "swift")
        let second = cache.parse(content: content, language: "swift")
        let third = cache.parse(content: content, language: "swift")

        #expect(first.count == second.count, "cached returns must equal first parse")
        #expect(second == third, "every repeat must return the memoized value")
        #expect(cache.misses == 1, "exactly one miss for the first call — got \(cache.misses)")
        #expect(cache.hits == 2, "subsequent identical calls must hit — got \(cache.hits)")
    }

    @Test("Cache misses + reparses when content changes")
    @MainActor
    func cacheMissesOnContentChange() {
        let cache = OutlineParserCache()
        _ = cache.parse(content: "func a() {}", language: "swift")
        _ = cache.parse(content: "func b() {}", language: "swift")
        _ = cache.parse(content: "func c() {}", language: "swift")
        #expect(cache.misses == 3, "each distinct content must miss — got \(cache.misses)")
        #expect(cache.hits == 0)
    }

    @Test("Cache misses when language changes on identical content")
    @MainActor
    func cacheMissesOnLanguageChange() {
        let cache = OutlineParserCache()
        let content = "// header"
        _ = cache.parse(content: content, language: "swift")
        _ = cache.parse(content: content, language: "rust")
        #expect(cache.misses == 2, "language-only switch must invalidate the memo")
    }

    @Test("invalidate forces a re-parse on the next call")
    @MainActor
    func invalidateForcesMiss() {
        let cache = OutlineParserCache()
        let content = "func foo() {}"
        _ = cache.parse(content: content, language: "swift")
        #expect(cache.misses == 1)
        cache.invalidate()
        _ = cache.parse(content: content, language: "swift")
        #expect(cache.misses == 2, "invalidate must drop the memo so the next call misses")
        #expect(cache.hits == 0, "invalidate clears the in-flight value too — second call cannot hit")
    }

    // MARK: - CodeEditorContentDebouncer (item 2)

    @Test("Debouncer fires once after the quiet window for rapid enqueues")
    @MainActor
    func debouncerCoalescesRapidEnqueues() async throws {
        // Use a short window so the test stays under a second.
        let window: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(60)
        var deliveries: [String] = []
        let debouncer = CodeEditorContentDebouncer(
            quietWindow: window
        ) { latest in
            deliveries.append(latest)
        }

        // Simulate 5 rapid keystrokes.
        debouncer.enqueue("h")
        debouncer.enqueue("he")
        debouncer.enqueue("hel")
        debouncer.enqueue("hell")
        debouncer.enqueue("hello")

        // Wait long enough for the debouncer to fire.
        try await Task.sleep(for: .milliseconds(150))

        #expect(deliveries.count == 1,
                "5 rapid enqueues must coalesce into 1 delivery — got \(deliveries.count): \(deliveries)")
        #expect(deliveries.first == "hello",
                "delivery must carry the LATEST text (\"hello\") — got \(deliveries.first ?? "nil")")
    }

    @Test("Debouncer fires twice when typing is separated by a quiet window")
    @MainActor
    func debouncerSplitsAfterQuietWindow() async throws {
        let window: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(40)
        var deliveries: [String] = []
        let debouncer = CodeEditorContentDebouncer(
            quietWindow: window
        ) { latest in
            deliveries.append(latest)
        }

        debouncer.enqueue("first")
        try await Task.sleep(for: .milliseconds(120))
        debouncer.enqueue("second")
        try await Task.sleep(for: .milliseconds(120))

        #expect(deliveries.count == 2,
                "two bursts separated by quiet window must each fire — got \(deliveries.count): \(deliveries)")
        #expect(deliveries == ["first", "second"])
    }

    @Test("detach stops the subscription so subsequent enqueues are dropped")
    @MainActor
    func debouncerDetachStopsDelivery() async throws {
        let window: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(40)
        var deliveries: [String] = []
        let debouncer = CodeEditorContentDebouncer(
            quietWindow: window
        ) { latest in
            deliveries.append(latest)
        }
        debouncer.detach()
        debouncer.enqueue("ignored")
        try await Task.sleep(for: .milliseconds(100))
        #expect(deliveries.isEmpty,
                "after detach() the closure must never fire — got \(deliveries)")
    }

    @Test("default quiet window is 300 ms (matches CODE_EDITOR_POLISH_SCOPE.md)")
    func defaultQuietWindowIs300() {
        #expect(CodeEditorContentDebouncer.defaultQuietWindowMs == 300)
    }

    @Test("CodeEditorView wires CodeEditorContentDebouncer into the live text-change path")
    func codeEditorViewUsesCanonicalDebouncer() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(source.contains("@State private var contentDebouncer: CodeEditorContentDebouncer?"),
                "CodeEditorView must retain the Phase-S debouncer instead of leaving it as standalone scaffold.")
        #expect(source.contains("let debouncer = contentDebouncer ?? CodeEditorContentDebouncer"),
                "CodeEditorView should construct the canonical debouncer in its coordinator setup path.")
        #expect(source.contains("debouncer?.enqueue(newText)"),
                "Text changes must enqueue into CodeEditorContentDebouncer, not bypass it with a local Task debounce.")
        #expect(!source.contains("try? await Task.sleep(for: .milliseconds(500))"),
                "The old ad-hoc 500ms content-change debounce should not remain in the editor text-change path.")
    }

    @Test("CodeEditorView uses native SourceEditor affordances for line numbers, invisibles, and indentation")
    func codeEditorViewUsesNativeSourceEditorAffordances() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(source.contains("showGutter: showLineGutter"),
                "Line numbers should use CodeEditSourceEditor's native left gutter, not a permanently disabled SourceEditor gutter.")
        #expect(source.contains("showFoldingRibbon: showLineGutter && showFoldingRibbon"),
                "Folding arrows should use the native SourceEditor ribbon and stay gated by the line-number gutter.")
        #expect(source.contains("private var invisibleCharactersConfiguration"),
                "The existing Show Invisibles toggle must feed a real SourceEditor invisible-character configuration.")
        #expect(source.contains("invisibleCharactersConfiguration: invisibleCharactersConfiguration"),
                "SourceEditorConfiguration must consume the Show Invisibles preference.")
        #expect(source.contains("indentOption: useSpaces ? .spaces(count: tabWidth) : .tab"),
                "The existing Use Spaces preference must drive CodeEditSourceEditor's tab insertion behavior.")
        #expect(source.contains(#"Toggle("Folding Arrows", isOn: $showFoldingRibbon)"#),
                "The native folding ribbon should be user-toggleable from the editor view menu.")
        #expect(source.contains(#"@AppStorage("epistemos.codeEditor.showIndentationGuides") private var showIndentationGuides = true"#),
                "Indent guides should be a first-class code-editor preference, not an always-on fake overlay.")
        #expect(source.contains(#"Toggle("Indent Guides", isOn: $showIndentationGuides)"#),
                "The user must be able to toggle VS Code-style indentation guides from the editor view menu.")
        #expect(source.contains("coordinator.applyIndentationGuideMetrics(font: editorFont, tabWidth: tabWidth)"),
                "Indent guides must align to the live font metrics and tab width preference.")
        #expect(source.contains("Self.visibleIndentColumnCount("),
                "Initial indent-guide metrics must derive from the public SourceEditor indentation option.")
        #expect(source.contains("case .spaces(let count):"),
                "Indent guide setup should inspect SourceEditor's public spaces-count case instead of package-internal fields.")
    }

    @Test("Segmented indentation guides align to real editor metrics, not fixed decorative offsets")
    func segmentedIndentationGuidesUseEditorMetrics() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/SegmentedIndentationGuideView.swift")

        #expect(source.contains("func applyEditorMetrics(font: NSFont, tabWidth: Int, leadingTextInset: CGFloat)"),
                "The VS Code-style guides should consume the live editor font, tab width, and leading text inset.")
        #expect(source.contains(#"(" " as NSString).size(withAttributes: [.font: font]).width"#),
                "Guide columns should be computed from the actual monospaced space width.")
        #expect(source.contains("indentWidth = nextIndentWidth"),
                "Guide spacing should follow the editor metrics instead of a hard-coded 16px column.")
        #expect(source.contains("leadingTextInset + CGFloat(level) * indentWidth"),
                "Guide drawing should be offset by the CodeEdit text inset so the lines sit under indented code.")
        #expect(!source.contains("let x = CGFloat(level) * indentWidth"),
                "The old inset-free guide placement would make indentation guides feel detached from the code text.")
    }

    @Test("CodeEditorView syntax theme does not collapse semantic tokens into plain body text")
    func codeEditorViewSyntaxThemeKeepsSemanticContrast() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(source.contains(#"keywords: .init(color: normalized(NSColor(hex: "AD3DA4")), bold: true)"#))
        #expect(source.contains(#"types: .init(color: normalized(NSColor(hex: "0B4F79")))"#))
        #expect(source.contains(#"strings: .init(color: normalized(NSColor(hex: "C41A16")))"#))
        #expect(source.contains(#"keywords: .init(color: normalized(NSColor(hex: "FF7AB2")), bold: true)"#))
        #expect(source.contains(#"types: .init(color: normalized(NSColor(hex: "6BDFFF")))"#))
        #expect(source.contains(#"strings: .init(color: normalized(NSColor(hex: "FF8170")))"#))
        #expect(source.contains("private let useMinimalTheme = false"),
                "The live editor should default to the semantic native theme, not the no-highlight fallback.")
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }
}
