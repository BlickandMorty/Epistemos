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

    @Test("Markdown chrome routing includes MDX and language IDs")
    func markdownChromeRoutingIncludesMdxAndLanguageIDs() throws {
        #expect(CodeLanguage.isMarkdownDocument(path: "/tmp/README.MD"))
        #expect(CodeLanguage.isMarkdownDocument(path: "/tmp/research.markdown"))
        #expect(CodeLanguage.isMarkdownDocument(path: "/tmp/component.mdx"))
        #expect(CodeLanguage.isMarkdownDocument(filePath: nil, language: "mdx"))
        #expect(CodeLanguage.isMarkdownDocument(filePath: nil, language: " Markdown \n"))
        #expect(CodeLanguage.detect(from: "/tmp/README.md") == nil)
        #expect(CodeLanguage.detectEditorLanguage(from: "/tmp/README.md") == "markdown")
        #expect(CodeLanguage.detectEditorLanguage(from: "/tmp/research.markdown") == "markdown")
        #expect(CodeLanguage.detectEditorLanguage(from: "/tmp/component.MDX") == "markdown")
        #expect(CodeLanguage.detect(from: "/tmp/plain.txt") == nil)
        #expect(!CodeLanguage.isMarkdownDocument(filePath: "/tmp/Package.swift", language: "swift"))

        let workspaceSource = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        #expect(workspaceSource.contains("private func sourceEditorRoute(for page: SDPage) -> SourceEditorRoute?"))
        #expect(workspaceSource.contains("guard resolvedNoteMode(for: page) == .source else {"))
        #expect(workspaceSource.contains("private func availableNoteModes(for page: SDPage) -> [NoteWorkspaceMode]"))
        #expect(!workspaceSource.contains("epistemos.markdownLens"))
        #expect(!workspaceSource.contains("MarkdownDocumentLens"))
        #expect(workspaceSource.contains(#"return SourceEditorRoute(filePath: path, language: "markdown")"#))
        #expect(workspaceSource.contains("private func cachedSourceEditorContent(page: SDPage, route: SourceEditorRoute) -> String"))
        #expect(workspaceSource.contains("content: cachedSourceEditorContent(page: page, route: route)"))
        #expect(workspaceSource.contains("if !CodeLanguage.isMarkdownDocument(path: filePath)"))
        #expect(workspaceSource.contains("private struct SourceEditorPersistedContent"))
        #expect(workspaceSource.contains("SourceEditorPersistedContent(rawContent: content, filePath: filePath)"))
        #expect(workspaceSource.contains("SourceEditorPersistedContent(rawContent: loaded.body, filePath: filePath)"))
        #expect(!workspaceSource.contains("let lang = CodeLanguage.detectEditorLanguage(from: path)"))
        #expect(!workspaceSource.contains("CodeLanguage.detectEditorLanguage(from: filePath) != nil"))
    }

    @Test("Markdown Source waits for a raw source snapshot before mounting editor")
    func markdownSourceWaitsForRawSourceSnapshotBeforeMountingEditor() throws {
        let workspaceSource = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(workspaceSource.contains("private struct CodeFileBodyLoadFailure"),
                "Markdown Source load failures need scoped state instead of silently falling back to page.body.")
        #expect(workspaceSource.contains("private func needsRawMarkdownSourceSnapshot(page: SDPage, route: SourceEditorRoute) -> Bool"),
                "Markdown Source should have an explicit raw-snapshot gate before mounting the editor.")
        #expect(workspaceSource.contains("rawMarkdownSourceFailureSurface(message: failureMessage, route: route)"),
                "Read failures should render an error surface, not a body-only editor.")
        #expect(workspaceSource.contains("rawMarkdownSourceLoadingSurface(route: route)"),
                "Markdown Source should show a loading surface while the raw disk snapshot is pending.")
        #expect(workspaceSource.contains("return codeFileBodySnapshot?.body(ifMatches: page.id, filePath: route.filePath) == nil"),
                "The gate must be satisfied only by a raw snapshot for the same page and file path.")
        #expect(workspaceSource.contains("if needsRawMarkdownSourceSnapshot(page: page, route: route) {\n            return 0\n        }"),
                "Status counts should not be derived from prose fallback content while raw Source is pending.")
        #expect(workspaceSource.contains(#"message: "No active vault is available for this source file.""#),
                "Without a vault, markdown Source must report failure rather than treating page.body as raw source.")
        #expect(!workspaceSource.contains("if CodeLanguage.isMarkdownDocument(path: filePath) {\n                codeFileBodySnapshot = CodeFileBodySnapshot(\n                    pageId: page.id,\n                    filePath: filePath,\n                    body: page.body"),
                "Markdown Source must not synthesize a raw snapshot from the stripped page body.")
    }

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

    @Test("flush delivers the latest text before a lens switch detaches the debouncer")
    @MainActor
    func debouncerFlushesBeforeDetach() async throws {
        let window: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(200)
        var deliveries: [String] = []
        let debouncer = CodeEditorContentDebouncer(
            quietWindow: window
        ) { latest in
            deliveries.append(latest)
        }

        debouncer.enqueue("stale")
        debouncer.flush("latest")
        debouncer.detach()
        try await Task.sleep(for: .milliseconds(260))

        #expect(deliveries == ["latest"],
                "flush must synchronously save the visible editor text before detach drops pending debounce work.")
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
        #expect(source.contains("_ = ensureContentDebouncer()"),
                "CodeEditorView should construct the canonical debouncer when the editor appears.")
        #expect(source.contains("ensureContentDebouncer().enqueue(newText)"),
                "Text changes must enqueue into CodeEditorContentDebouncer, not bypass it with a local Task debounce.")
        #expect(!source.contains("try? await Task.sleep(for: .milliseconds(500))"),
                "The old ad-hoc 500ms content-change debounce should not remain in the editor text-change path.")
        let flushRange = try #require(source.range(of: "contentDebouncer?.flush(text)"))
        let detachRange = try #require(source.range(of: "contentDebouncer?.detach()"))
        #expect(flushRange.lowerBound < detachRange.lowerBound,
                "CodeEditorView must flush the visible Source text before detaching the debouncer during lens switches.")
    }

    @Test("CodeEditorView feeds live preferences into MarkEdit CoreEditor")
    func codeEditorViewFeedsLivePreferencesIntoMarkEditCoreEditor() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let adapter = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorState.swift")

        #expect(source.contains("showLineNumbers: showLineGutter"),
                "Line numbers must be passed to MarkEdit CoreEditor from Epistemos chrome.")
        #expect(source.contains("showInvisibles: showInvisibles"),
                "The existing Show Invisibles preference must feed the CoreEditor config.")
        #expect(source.contains("useSpaces: useSpaces"),
                "The existing Use Spaces preference must feed the CoreEditor config.")
        #expect(source.contains("tabWidth: tabWidth"),
                "The existing Tab Width preference must feed the CoreEditor config.")
        #expect(source.contains(#"Toggle("Show Invisibles", isOn: $showInvisibles)"#),
                "The user must be able to toggle invisibles from the editor view menu.")
        #expect(!source.contains("SourceEditor("),
                "The old native SourceEditor fallback must not remain in the production code surface.")
        #expect(adapter.contains(#"invisiblesBehavior: showInvisibles ? "always" : "never""#))
        #expect(adapter.contains("indentUnit: indentUnit"))
        #expect(adapter.contains("tabKeyBehavior: tabKeyBehavior"))
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

    @Test("MarkEdit CoreEditor syntax theme does not collapse code into plain body text")
    func markEditCoreEditorSyntaxThemeKeepsSemanticContrast() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let adapter = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorState.swift")

        #expect(source.contains("MarkEditCodeEditorRepresentable("),
                "Code files must render through MarkEdit CoreEditor by default, with v1 kept as an explicit fallback.")
        #expect(source.contains("theme: codeEditorTheme"),
                "Epistemos theme changes and embedded-surface overrides must feed the CoreEditor adapter.")
        #expect(adapter.contains("AppTheme.epistemosSourceTheme(for: theme).editorTheme"),
                "CoreEditor should map Epistemos themes into MarkEdit source themes instead of falling back to a plain body surface.")
        #expect(adapter.contains(#"theme.isDark ? "xcode-dark" : "xcode-light""#),
                "The non-MarkEdit fallback still needs a real code syntax theme.")
        #expect(adapter.contains(#"WebFontFace(family: "SF Mono", weight: nil, style: nil)"#),
                "The code lane should keep a monospaced editor face through CoreEditor config.")
        #expect(adapter.contains("AppPreferences.Editor.fontSize"),
                "Markdown Source should inherit MarkEdit's editor font size.")
        #expect(adapter.contains("AppPreferences.Editor.lineHeight.multiplier"),
                "Markdown and code Source should inherit MarkEdit's editor line-height preference.")
        #expect(adapter.contains("fontFace != other.fontFace"),
                "Changing editor font face must reload CoreEditor so metrics and wrapping repaint.")
        #expect(adapter.contains("lineHeight != other.lineHeight"),
                "Changing MarkEdit line height must reload CoreEditor so visual metrics repaint.")
        #expect(adapter.contains("showActiveLineIndicator: true"),
                "CoreEditor should preserve editor affordances that distinguish code from prose.")
        #expect(adapter.contains("lineWrapping: wrapLines"),
                "The existing code-editor wrap preference must reach CoreEditor.")
        #expect(!source.contains("private let useMinimalTheme = false"),
                "The old native minimal-theme switch must not be the default code syntax gate anymore.")
    }

    @Test("Code editor search engine finds forward matches and wraps")
    func codeEditorSearchFindsForwardAndWraps() {
        let text = "alpha beta alpha"

        let first = CodeEditorSearchEngine.find(
            in: text,
            query: "alpha",
            caseSensitive: true,
            direction: .forward,
            currentRange: nil
        )
        #expect(first == NSRange(location: 0, length: 5))

        let second = CodeEditorSearchEngine.find(
            in: text,
            query: "alpha",
            caseSensitive: true,
            direction: .forward,
            currentRange: first
        )
        #expect(second == NSRange(location: 11, length: 5))

        let wrapped = CodeEditorSearchEngine.find(
            in: text,
            query: "alpha",
            caseSensitive: true,
            direction: .forward,
            currentRange: second
        )
        #expect(wrapped == NSRange(location: 0, length: 5))
    }

    @Test("Code editor search engine finds backward matches and wraps")
    func codeEditorSearchFindsBackwardAndWraps() {
        let text = "alpha beta alpha"

        let last = CodeEditorSearchEngine.find(
            in: text,
            query: "alpha",
            caseSensitive: true,
            direction: .backward,
            currentRange: nil
        )
        #expect(last == NSRange(location: 11, length: 5))

        let first = CodeEditorSearchEngine.find(
            in: text,
            query: "alpha",
            caseSensitive: true,
            direction: .backward,
            currentRange: last
        )
        #expect(first == NSRange(location: 0, length: 5))

        let wrapped = CodeEditorSearchEngine.find(
            in: text,
            query: "alpha",
            caseSensitive: true,
            direction: .backward,
            currentRange: first
        )
        #expect(wrapped == NSRange(location: 11, length: 5))
    }

    @Test("Code editor search case sensitivity is explicit")
    func codeEditorSearchHonorsCaseSensitivity() {
        let text = "Needle needle"

        let insensitive = CodeEditorSearchEngine.find(
            in: text,
            query: "needle",
            caseSensitive: false,
            direction: .forward,
            currentRange: nil
        )
        #expect(insensitive == NSRange(location: 0, length: 6))

        let sensitive = CodeEditorSearchEngine.find(
            in: text,
            query: "needle",
            caseSensitive: true,
            direction: .forward,
            currentRange: nil
        )
        #expect(sensitive == NSRange(location: 7, length: 6))
    }

    @Test("Code editor search ignores not-found cursor scaffold")
    func codeEditorSearchIgnoresNotFoundCursorRange() {
        let text = "alpha beta alpha"

        let forward = CodeEditorSearchEngine.find(
            in: text,
            query: "alpha",
            caseSensitive: true,
            direction: .forward,
            currentRange: NSRange(location: NSNotFound, length: 0)
        )
        #expect(forward == NSRange(location: 0, length: 5))

        let backward = CodeEditorSearchEngine.find(
            in: text,
            query: "alpha",
            caseSensitive: true,
            direction: .backward,
            currentRange: NSRange(location: NSNotFound, length: 0)
        )
        #expect(backward == NSRange(location: 11, length: 5))
    }

    @Test("Code editor line metrics handle large buffers without splitting")
    func codeEditorLineMetricsHandleLargeBuffers() {
        let largeBuffer = String(repeating: "let value = 1\n", count: 100_000)

        #expect(CodeEditorLineMetrics.lineCount(largeBuffer) == 100_001)
    }

    @Test("Code editor line metrics extract visible text windows by cached UTF16 offsets")
    func codeEditorLineMetricsExtractVisibleTextWindows() throws {
        let text = "one\n  two\r\n    three\nfour"
        let offsets = CodeEditorLineMetrics.lineStartUTF16Offsets(in: text)
        let window = try #require(CodeEditorLineMetrics.textWindow(
            in: text,
            lineRange: 2...3,
            lineStartUTF16Offsets: offsets
        ))

        #expect(window.baseLineNumber == 2)
        #expect(window.text == "  two\r\n    three\n")
    }

    @Test("Code editor large-file policy bounds viewport work")
    func codeEditorLargeFilePolicyBoundsViewportWork() throws {
        #expect(CodeEditorLargeFilePolicy.usesViewportScopedIndentGuides(
            characterCount: 100_000,
            lineCount: 500
        ))
        #expect(CodeEditorLargeFilePolicy.usesViewportScopedIndentGuides(
            characterCount: 10,
            lineCount: 10_000
        ))

        let range = try #require(CodeEditorLargeFilePolicy.visibleLineRange(
            visibleRect: NSRect(x: 0, y: 170_000, width: 900, height: 1_700),
            lineHeight: 17,
            lineCount: 100_000,
            maximumLineCount: 400
        ))

        #expect(range.lowerBound >= 9_700)
        #expect(range.upperBound <= 10_400)
        #expect((range.upperBound - range.lowerBound + 1) <= 400)
    }

    @Test("Code line gutter visible range stays viewport scoped for huge files")
    func codeLineGutterVisibleRangeStaysViewportScoped() throws {
        let visible = try #require(CodeLineGutterView.visibleLineRange(
            lineCount: 100_000,
            lineHeight: 17,
            topInset: 0,
            scrollOffset: -170_000,
            dirtyRect: NSRect(x: 0, y: 0, width: 48, height: 1_700)
        ))

        #expect(visible.lowerBound >= 9_900)
        #expect(visible.upperBound <= 10_200)
        #expect((visible.upperBound - visible.lowerBound + 1) <= 120)
    }

    @Test("CodeEditorView search bar executes real selection, not a visible stub")
    func codeEditorSearchBarExecutesSelection() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(source.contains("CodeEditorSearchEngine.find("),
                "The visible find bar must execute a real wrapped search instead of only accepting query text.")
        #expect(source.contains("requestEditorSelection(match)"),
                "Search results must be selected through the active editor bridge.")
        #expect(source.contains("webKitSelectionRequest = WebKitCodeEditorSelectionRequest(range: range)"),
                "The v1 fallback must receive the same explicit selection requests as CoreEditor.")
        #expect(source.contains("activeSearchRange = nil"),
                "Changing text/query/case should invalidate the stale search anchor.")
        #expect(!source.contains("_ = direction"),
                "The old placeholder search implementation must not remain reachable.")
    }

    @Test("Code editor semantic LSP position clamps to document lines")
    func codeEditorSemanticLSPPositionClampsToLiveText() {
        let text = "let first = 1\nlet emoji = \"\u{1F9E0}\"\n"
        let firstLine = CodeEditorSemanticLSP.lspPosition(
            text: text,
            oneBasedLine: 1,
            oneBasedColumn: 5
        )
        #expect(firstLine == LSPPosition(line: 0, character: 4))

        let secondLineEnd = CodeEditorSemanticLSP.lspPosition(
            text: text,
            oneBasedLine: 2,
            oneBasedColumn: 200
        )
        #expect(secondLineEnd.line == 1)
        #expect(secondLineEnd.character == "let emoji = \"\u{1F9E0}\"".utf16.count)

        let beyondEOF = CodeEditorSemanticLSP.lspPosition(
            text: text,
            oneBasedLine: 99,
            oneBasedColumn: 99
        )
        #expect(beyondEOF.line == 2)
        #expect(beyondEOF.character == 0)
    }

    @Test("Code editor semantic LSP summarizes hover without leaking raw newlines")
    func codeEditorSemanticLSPSummarizesHover() {
        let hover = LSPHoverResult(contents: "\n```rust\nfn answer() -> i32\n```\n\nfunction_item\n")
        let summary = CodeEditorSemanticLSP.summarizedHover(hover)

        #expect(summary?.contains("fn answer() -> i32") == true)
        #expect(summary?.contains("function_item") == true)
        #expect(summary?.contains("\n") == false)
    }

    @Test("Code editor semantic LSP maps definition ranges to editor selection ranges")
    func codeEditorSemanticLSPMapsDefinitionRangeToNSRange() throws {
        let text = "fn answer() -> i32 { 42 }\nfn main() { answer(); }\n"
        let definitionRange = LSPRange(
            start: LSPPosition(line: 0, character: 3),
            end: LSPPosition(line: 0, character: 9)
        )
        let nsRange = try #require(CodeEditorSemanticLSP.nsRange(for: definitionRange, in: text))

        #expect(nsRange.location == 3)
        #expect(nsRange.length == 6)
        #expect((text as NSString).substring(with: nsRange) == "answer")
    }

    @Test("Code editor semantic LSP bridge returns Rust hover when FFI is linked")
    func codeEditorSemanticLSPBridgeReturnsRustHover() async throws {
        #if canImport(agent_coreFFI)
        let text = "fn answer() -> i32 { 42 }\nfn main() { answer(); }\n"
        let summary = try await CodeEditorSemanticLSP.hoverSummary(
            text: text,
            language: "rust",
            filePath: "/tmp/epistemos-code-editor-semantic.rs",
            cursorLine: 2,
            cursorColumn: 13
        )

        #expect(summary?.contains("answer") == true)
        #expect(summary?.contains("function_item") == true)
        #expect(summary?.contains("fn answer()") == true)
        #else
        #expect(CodeEditorSemanticLSP.supportsLanguage(language: "rust"))
        #expect(!CodeEditorSemanticLSP.canRun(language: "rust"),
                "Rust language support must not enable a runnable-looking LSP action when agent_coreFFI is absent.")
        #endif
    }

    @Test("Code editor semantic LSP bridge returns Rust definition when FFI is linked")
    func codeEditorSemanticLSPBridgeReturnsRustDefinition() async throws {
        #if canImport(agent_coreFFI)
        let text = "fn answer() -> i32 { 42 }\nfn main() { answer(); }\n"
        let definition = try await CodeEditorSemanticLSP.definitionLocation(
            text: text,
            language: "rust",
            filePath: "/tmp/epistemos-code-editor-definition.rs",
            cursorLine: 2,
            cursorColumn: 13
        )

        #expect(definition?.range.start.line == 0)
        #expect(definition?.range.start.character == 3)
        let nsRange = try #require(definition.flatMap { CodeEditorSemanticLSP.nsRange(for: $0.range, in: text) })
        #expect((text as NSString).substring(with: nsRange).contains("answer"))
        #else
        #expect(CodeEditorSemanticLSP.supportsLanguage(language: "rust"))
        #expect(!CodeEditorSemanticLSP.canRun(language: "rust"),
                "Definition lookup must stay gated when the in-process Rust runtime is unavailable.")
        #endif
    }

    @Test("Code editor semantic LSP gates visible actions on runtime availability")
    func codeEditorSemanticLSPGatesVisibleActionsOnRuntimeAvailability() throws {
        #if canImport(agent_coreFFI)
        #expect(CodeEditorSemanticLSP.runtimeAvailable)
        #expect(CodeEditorSemanticLSP.canRun(language: "rust"))
        #expect(CodeEditorSemanticLSP.canRun(language: "swift"))
        #else
        #expect(!CodeEditorSemanticLSP.runtimeAvailable)
        #expect(!CodeEditorSemanticLSP.canRun(language: "rust"))
        #expect(!CodeEditorSemanticLSP.canRun(language: "swift"))
        #expect(CodeEditorSemanticLSP.unavailableMessage(language: "rust").contains("not linked"))
        #endif

        #expect(!CodeEditorSemanticLSP.canRun(language: "python"))

        let source = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        #expect(source.contains("static var runtimeAvailable"))
        #expect(source.contains("#if canImport(agent_coreFFI)"))
        #expect(source.contains("static func canRun(language: String) -> Bool"))
        #expect(source.contains(".disabled(!CodeEditorSemanticLSP.canRun(language: language) || semanticStatusIsLoading)"))
        #expect(!source.contains(".disabled(!CodeEditorSemanticLSP.isSupported(language: language)"))
    }

    @Test("CodeEditorView exposes on-demand LSP without enabling the deferred sidebar")
    func codeEditorViewExposesOnDemandLSPOnly() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(source.contains("static let semanticSidebarEnabled = false"),
                "The unfinished semantic sidebar must remain gated for v1.")
        #expect(source.contains("requestSemanticHover()"),
                "The code editor must expose an on-demand symbol inspection action.")
        #expect(source.contains("RustLSPTransport(pollIntervalNanos: pollIntervalNanos)"),
                "The visible symbol action must use the canonical in-process Rust LSP transport.")
        #expect(source.contains("try await client.didOpen(uri: uri, languageId: languageId, version: 1, text: text)"),
                "The LSP bridge must open the live editor buffer before requesting hover.")
        #expect(source.contains("try await client.hover("),
                "The on-demand bridge must call the real LSP hover request, not fabricate diagnostics.")
        #expect(source.contains(".disabled(!CodeEditorSemanticLSP.canRun(language: language) || semanticStatusIsLoading)"),
                "Unsupported languages must not show an installed-looking runnable LSP action.")
        #expect(source.contains("semanticLSPStatusOverlay"),
                "LSP results and unavailable states need a visible, dismissible status surface.")
        #expect(source.contains("requestSemanticDefinition()"),
                "The verified LSP definition substrate should be reachable through an explicit user action.")
        #expect(source.contains("try await client.definition("),
                "Definition lookup must call the real LSP definition request.")
        #expect(source.contains("requestEditorSelection(definitionRange)"),
                "Same-file definitions must select the real definition range through the active editor bridge.")
    }

    @Test("Code editor large-file affordances stay on CoreEditor")
    func codeEditorLargeFileAffordancesStayOnCoreEditor() throws {
        let editor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let adapter = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
        let guides = try loadRepoTextFile("Epistemos/Views/Notes/SegmentedIndentationGuideView.swift")
        let gutter = try loadRepoTextFile("Epistemos/Views/Notes/CodeLineGutter.swift")

        #expect(editor.contains("enum CodeEditorLargeFilePolicy"),
                "The editor needs a named large-file policy instead of scattered magic thresholds.")
        #expect(editor.contains("MarkEditCodeEditorRepresentable("),
                "Large code files should use the MarkEdit CoreEditor engine by default, with v1 only behind the legacy toggle.")
        #expect(editor.contains("showLineNumbers: showLineGutter"),
                "The Epistemos line-number toggle must route into CoreEditor config.")
        #expect(adapter.contains("const lineCount = state.doc.lines"),
                "CoreEditor should report line counts from CodeMirror doc metadata instead of Swift splitting large buffers on cursor movement.")
        #expect(adapter.contains("requestAnimationFrame(() => {"),
                "CoreEditor snapshots should be frame-coalesced rather than running per-event heavyweight work.")
        #expect(adapter.contains("document.addEventListener(\"selectionchange\", scheduleSnapshot, true)"),
                "Cursor/selection tracking should come from the CoreEditor bridge.")
        #expect(!editor.contains("textController?.textView"),
                "CodeEditorView must not depend on the old native text controller for the default MarkEdit surface.")
        #expect(!editor.contains("gutterView"),
                "The dormant fallback gutter must not be mounted on the production code path.")
        #expect(!editor.contains("CodeEditorLineMetrics.textWindow("),
                "Production code editor viewporting is owned by CoreEditor, not the old Swift text-window overlay.")
        #expect(guides.contains("lineRange: ClosedRange<Int>? = nil"),
                "Indent guide parsing should support viewport-scoped line windows.")
        #expect(guides.contains("baseLineNumber: Int = 1"),
                "Indent guide parsing must preserve absolute line numbers when it receives a sliced text window.")
        #expect(guides.contains("if let lineRange, lineNumber > lineRange.upperBound {\n                break\n            }"),
                "Viewport-scoped parsing should stop after the requested line window.")
        #expect(gutter.contains("private var numberStringCache: [Int: NSString] = [:]"),
                "The fallback gutter should cache visible line numbers lazily instead of prebuilding one string per line.")
        #expect(!gutter.contains("for n in (lineCount + 1)...clamped"),
                "Growing the gutter line count must not allocate strings for every line in a huge file.")
    }

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }
}
