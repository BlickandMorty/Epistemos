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

    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
