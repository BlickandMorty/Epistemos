import Foundation
import Testing

@testable import Epistemos

/// T+8 Phase-S items 2 + 3 unit tests
/// (per `docs/CODE_EDITOR_POLISH_SCOPE.md`).
///
/// - `CodeEditorContentDebouncer` (item 2): coalesces rapid keystrokes
///   to a single delivery after the editor save quiet window.
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
        #expect(workspaceSource.contains("guard resolvedNoteMode(for: page, options: options) == .source else {"))
        #expect(workspaceSource.contains("private func availableNoteModes(for page: SDPage) -> [NoteWorkspaceMode]"))
        #expect(!workspaceSource.contains("epistemos.markdownLens"))
        #expect(!workspaceSource.contains("MarkdownDocumentLens"))
        #expect(workspaceSource.contains("let markdownPath = canonicalMarkdownSourcePath(for: page, fallbackPath: path)"))
        #expect(workspaceSource.contains(#"return SourceEditorRoute(filePath: markdownPath, language: "markdown")"#))
        #expect(workspaceSource.contains("private func activeVaultMarkdownSourcePath(for page: SDPage) -> String?"))
        #expect(workspaceSource.contains("page.filePath = filePath"))
        #expect(workspaceSource.contains("private func cachedSourceEditorContent(page: SDPage, route: SourceEditorRoute) -> String"))
        #expect(workspaceSource.contains("content: cachedSourceEditorContent(page: page, route: route)"))
        #expect(workspaceSource.contains("if CodeLanguage.isMarkdownDocument(path: filePath)"))
        #expect(workspaceSource.contains("private func persistSourceEditorContent("))
        #expect(workspaceSource.contains("private func persistMarkdownSourceEditorContent("))
        #expect(workspaceSource.contains("private func currentSourceRouteMatches(pageId: String, filePath: String) -> Bool"))
        #expect(workspaceSource.contains("let currentRoute = sourceFileRoute(for: currentPage)"))
        #expect(workspaceSource.contains("private struct SourceEditorPersistedContent"))
        #expect(workspaceSource.contains("SourceEditorPersistedContent(rawContent: content, filePath: filePath)"))
        #expect(workspaceSource.contains("SourceEditorPersistedContent(rawContent: loaded.body, filePath: filePath)"))
        #expect(!workspaceSource.contains("let lang = CodeLanguage.detectEditorLanguage(from: path)"))
        #expect(!workspaceSource.contains("CodeLanguage.detectEditorLanguage(from: filePath) != nil"))
    }

    @Test("Markdown Source route resolution stays lexical and IO-free")
    func markdownSourceRouteResolutionStaysLexicalAndIOFree() throws {
        let workspaceSource = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        guard let functionRange = workspaceSource.range(of: "private func activeVaultMarkdownSourcePath(for page: SDPage) -> String?"),
              let nextFunctionRange = workspaceSource.range(
                of: "private func sourceEditorRoute(for page: SDPage) -> SourceEditorRoute?",
                range: functionRange.upperBound..<workspaceSource.endIndex
              ) else {
            Issue.record("Failed to isolate activeVaultMarkdownSourcePath() in NoteDetailWorkspaceView.swift")
            return
        }

        let routeSource = String(workspaceSource[functionRange.lowerBound..<nextFunctionRange.lowerBound])
        #expect(workspaceSource.contains("private func lexicalFilePath(_ path: String) -> String"))
        #expect(routeSource.contains("let rootPath = lexicalFilePath(vaultURL.path)"))
        #expect(routeSource.contains("let candidatePath = lexicalFilePath(rootPath + \"/\" + normalizedPath)"))
        #expect(!routeSource.contains(".standardizedFileURL"))
        #expect(!routeSource.contains("resolvingSymlinksInPath"))
    }

    @Test("Code file identity badges expose language logos and labels")
    func codeFileIdentityBadgesExposeLanguageLogosAndLabels() {
        let swift = CodeFileIconResolver.identity(forFilePath: "/tmp/App.swift", language: "")
        #expect(swift.displayName == "Swift")
        #expect(swift.symbolName == "swift")
        #expect(swift.shortMark == "SW")

        let html = CodeFileIconResolver.identity(forFilePath: "/tmp/index.html", language: "")
        #expect(html.displayName == "HTML")
        #expect(html.symbolName == "chevron.left.forwardslash.chevron.right")

        let rust = CodeFileIconResolver.identity(forFilePath: "/tmp/lib.rs", language: "")
        #expect(rust.displayName == "Rust")
        #expect(rust.symbolName == "gearshape.2.fill")

        let yaml = CodeFileIconResolver.identity(forFilePath: nil, language: "yaml")
        #expect(yaml.displayName == "YAML")
        #expect(yaml.shortMark == "YML")

        let json = CodeFileIconResolver.identity(forFilePath: "/tmp/package.json", language: "")
        #expect(json.displayName == "JSON")
        #expect(json.symbolName == "curlybraces.square")
    }

    @Test("Code file rename preserves the existing file extension")
    func codeFileRenamePreservesExistingFileExtension() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Sync/VaultIndexActor.swift")
        let sidebar = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NotesSidebar.swift")
        let functionStart = try #require(source.range(of: "func renamePageFile(pageId: String, newTitle: String, vaultURL: URL) throws"))
        let functionEnd = try #require(
            source.range(
                of: "// MARK: - Handle Deletion",
                range: functionStart.upperBound..<source.endIndex
            )
        )
        let renameSource = source[functionStart.lowerBound..<functionEnd.lowerBound]

        #expect(renameSource.contains("let oldExtension = oldURL.pathExtension"))
        #expect(renameSource.contains("sanitizeFileBaseName(newTitle, preservingExtension: oldExtension)"))
        #expect(renameSource.contains("updateCodeSidecarAfterFileRename(oldURL: oldURL, newURL: newURL, vaultURL: vaultURL)"))
        #expect(renameSource.contains(#"oldExtension.isEmpty ? "\(newBaseName).md" : "\(newBaseName).\(oldExtension)""#))
        #expect(renameSource.contains(#""\(newBaseName)-\(suffix).md""#))
        #expect(renameSource.contains(#""\(newBaseName)-\(suffix).\(oldExtension)""#))
        #expect(renameSource.contains(#""\(newBaseName)-\(uuid8).\(oldExtension)""#))
        #expect(!renameSource.contains(#"appendingPathComponent("\(newBaseName).md")"#))
        #expect(!renameSource.contains(#"appendingPathComponent("\(newBaseName)-\(suffix).md")"#))
        #expect(sidebar.contains("private func preferredInitialMode(for page: SDPage) -> NoteWorkspaceMode"))
        #expect(sidebar.contains("openInEditor(pageId, initialMode: .source)"))
        #expect(sidebar.contains("page.needsVaultSync = isCodePage ? originalNeedsVaultSync : true"))
        #expect(sidebar.contains("if originalFilePath != nil"))
        #expect(sidebar.contains("page rename rollback after FS failure"))
        #expect(sidebar.contains("renamedPage.title == sanitized"))
    }

    @Test("MarkEdit Source mount defers SwiftUI binding line metrics")
    func markEditSourceMountDefersSwiftUIBindingLineMetrics() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
        guard let applyRange = source.range(of: "    private func apply(\n        text nextText: String,"),
              let pollingRange = source.range(
                of: "    private func startPolling(viewController: EditorViewController)",
                range: applyRange.upperBound..<source.endIndex
              ) else {
            Issue.record("Failed to isolate MarkEdit chrome apply path")
            return
        }

        let applySource = String(source[applyRange.lowerBound..<pollingRange.lowerBound])
        #expect(source.contains("private func scheduleLineCountUpdate(for text: String)"))
        #expect(source.contains("private func updateLineCountNow(for text: String)"))
        #expect(source.contains("await Task.yield()"))
        #expect(applySource.contains("scheduleLineCountUpdate(for: nextText)"))
        #expect(!applySource.contains("updateLineCount(for: nextText)"))
    }

    @Test("Markdown Source mounts from note fallback and enriches from raw source safely")
    func markdownSourceMountsFromNoteFallbackAndEnrichesFromRawSourceSafely() throws {
        let workspaceSource = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(workspaceSource.contains("private func seedMarkdownSourceSnapshot(for page: SDPage, route: SourceEditorRoute) -> String"),
                "Markdown Source should seed a same-page snapshot before any async file read can fail.")
        #expect(workspaceSource.contains("private func markdownSourceFallbackContent(for page: SDPage, filePath: String? = nil) -> String"),
                "Markdown Source fallback should be an explicit note-backed policy.")
        #expect(workspaceSource.contains("return markdownSourceFallbackContent(for: page, filePath: route.filePath)"),
                "Markdown Source must synchronously mount from persisted note state before async source snapshots arrive.")
        #expect(workspaceSource.contains("VaultIndexActor.buildMarkdownSource("),
                "Markdown Source fallback must preserve the same front-matter envelope as vault export.")
        #expect(workspaceSource.contains("let seededMarkdownSource = isMarkdownSource"),
                "Raw-source enrichment should know which fallback content it is allowed to replace.")
        #expect(workspaceSource.contains("onTextSnapshot: { latestContent in"),
                "Source text should update workspace state immediately instead of waiting for debounced persistence.")
        #expect(workspaceSource.contains("recordSourceEditorSnapshot(\n                                page: page,\n                                filePath: route.filePath,\n                                content: latestContent"),
                "The Source editor must feed latest text into the note workspace before lens switches.")
        #expect(workspaceSource.contains("private func recordSourceEditorSnapshot(page: SDPage, filePath: String, content: String)"),
                "Immediate Source snapshots should live in the note workspace, not as an extra editor storage layer.")
        #expect(workspaceSource.contains("modeBodySnapshot = NoteModeBodySnapshot(pageId: page.id, body: persistedContent.body)"),
                "Markdown Source snapshots must provide the front-matter-stripped body that Prose expects.")
        #expect(workspaceSource.contains("private func refreshMarkdownSourceSnapshot(for page: SDPage)"),
                "Document/Prose saves must refresh the raw Markdown Source snapshot instead of leaving stale frontmatter-only cache.")
        #expect(workspaceSource.contains("modeBodySnapshot = NoteModeBodySnapshot(pageId: pageId, body: markdown)\n        refreshMarkdownSourceSnapshot(for: page)"),
                "Document surface saves must refresh Source's raw Markdown cache immediately after accepting the new body.")
        #expect(workspaceSource.contains("case .document, .source, .preview:\n            return currentModeBodySnapshot(for: page.id) ?? persistedBodyFor(page)"),
                "Switching away from Source must flush the live Source snapshot instead of clobbering it with stale persisted body.")
        #expect(workspaceSource.contains("guard let currentPage = pages.first,"),
                "Raw-source enrichment must not overwrite unsynced note edits.")
        #expect(workspaceSource.contains("currentPage.needsVaultSync != true,"),
                "Raw-source enrichment must not overwrite unsynced note edits.")
        #expect(workspaceSource.contains("markdownSourceFallbackContent(for: currentPage, filePath: filePath) == seededMarkdownSource"),
                "Raw-source enrichment must not overwrite newer Prose or managed-editor text.")
        #expect(workspaceSource.contains("currentSourceRouteMatches(pageId: pageId, filePath: filePath)"),
                "Raw-source enrichment must validate against the resolved Source route, not a stale page.filePath.")
        #expect(workspaceSource.contains("codeFileBodySnapshot?.body(ifMatches: pageId, filePath: filePath) == seededMarkdownSource"),
                "Raw-source enrichment must not overwrite Source edits made after mounting.")
        #expect(workspaceSource.contains("if !isMarkdownSource {\n                codeFileBodySnapshot = CodeFileBodySnapshot("),
                "No-vault fallback should be special only for non-markdown code files; markdown already has a note snapshot.")
        #expect(workspaceSource.contains("page.needsVaultSync = true"),
                "Markdown Source saves should be note-backed first, matching Prose robustness.")
        #expect(workspaceSource.contains("private func saveCurrentNoteToDisk()"),
                "Save affordances should share one flush path.")
        #expect(workspaceSource.contains("save: saveCurrentNoteToDisk"),
                "Command-surface saves must flush the active editor before hitting disk.")
        #expect(workspaceSource.contains("Button(\"\") { saveCurrentNoteToDisk() }"),
                "Cmd-S must flush the active editor before hitting disk.")
        #expect(workspaceSource.contains("case .saveToDisk:\n            saveCurrentNoteToDisk()"),
                "The visible Save to Disk action must flush Source snapshots, not just call vaultSync directly.")
        #expect(workspaceSource.contains("MarkEditCoreEditorLiveTextRegistry.shared.fetchText("),
                "Source-mode saves should query the mounted editor instead of trusting a delayed host snapshot.")
        #expect(workspaceSource.contains("let saved = await enqueueSourceEditorPersistence("),
                "Source-mode saves should await the ordered markdown/code writer before a lens switch or teardown completes.")
        #expect(!workspaceSource.contains("case .saveToDisk:\n            vaultSync.savePage(pageId: pageId)"),
                "Save to Disk must not bypass the Source snapshot.")
        #expect(workspaceSource.contains("CodeEditorLineMetrics.lineCount(content)"),
                "Source status counts should reuse the non-allocating code editor line counter.")
        #expect(!workspaceSource.contains(#"return content.components(separatedBy: "\n").count"#),
                "Source status counts must not allocate a full line array.")
        #expect(!workspaceSource.contains("private struct CodeFileBodyLoadFailure"),
                "Markdown Source should not have a dedicated error state that can block the editor.")
        #expect(!workspaceSource.contains("private func needsRawMarkdownSourceSnapshot(page: SDPage, route: SourceEditorRoute) -> Bool"),
                "Markdown Source should not require disk content before mounting.")
        #expect(!workspaceSource.contains("rawMarkdownSourceFailureSurface"),
                "Markdown Source read failures should not replace the editor with an unavailable surface.")
        #expect(!workspaceSource.contains("rawMarkdownSourceLoadingSurface"),
                "Markdown Source should mount from note state instead of showing a blocking loader.")
        #expect(!workspaceSource.contains("Source Unavailable"),
                "Markdown Source should not expose CodeFileService read failures as a permanent source panel.")
        #expect(!workspaceSource.contains(#"message: "No active vault is available for this source file.""#),
                "Missing vault state must not hide markdown Source when note content is available.")
        #expect(!workspaceSource.contains("ui.theme.resolved.border.color.opacity(0.55)"),
                "Source header should stay flat instead of reintroducing a hard bottom rule.")
    }

    @Test("Markdown Source fallback serialization preserves front matter metadata")
    func markdownSourceFallbackSerializationPreservesFrontMatterMetadata() throws {
        let rendered = VaultIndexActor.buildMarkdownSource(
            pageId: "page-1",
            title: "Title: With Quotes \"Here\"",
            tags: ["source", "proof"],
            emoji: "spark",
            isJournal: true,
            journalDate: "2026-06-30",
            parentPageId: "parent-1",
            templateId: "template-1",
            frontMatter: [
                "capture": "web",
                "source_pdf": "papers/source.pdf",
                "title": "stale-title-should-not-win"
            ],
            body: "Body text"
        )

        let parsed = VaultIndexActor.parseFrontMatter(rendered)

        #expect(parsed.0["id"] == "page-1")
        #expect(parsed.0["title"] == "Title: With Quotes \"Here\"")
        #expect(parsed.0["tags"] == "source, proof")
        #expect(parsed.0["icon"] == "spark")
        #expect(parsed.0["journal"] == "true")
        #expect(parsed.0["date"] == "2026-06-30")
        #expect(parsed.0["parent"] == "parent-1")
        #expect(parsed.0["template"] == "template-1")
        #expect(parsed.0["capture"] == "web")
        #expect(parsed.0["source_pdf"] == "papers/source.pdf")
        #expect(parsed.1 == "Body text")
        #expect(try #require(rendered.range(of: "capture: web")).lowerBound
            < #require(rendered.range(of: "source_pdf: papers/source.pdf")).lowerBound)
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

    @Test("default quiet window is 900 ms to keep saves off active typing")
    func defaultQuietWindowIs900() {
        #expect(CodeEditorContentDebouncer.defaultQuietWindowMs == 900)
    }

    @Test("CodeEditorView wires CodeEditorContentDebouncer into the live text-change path")
    func codeEditorViewUsesCanonicalDebouncer() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let adapter = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
        let coordinator = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift")
        let workspace = try loadRepoTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(source.contains("@State private var contentDebouncer: CodeEditorContentDebouncer?"),
                "CodeEditorView must retain the Phase-S debouncer instead of leaving it as standalone scaffold.")
        #expect(source.contains("_ = ensureContentDebouncer()"),
                "CodeEditorView should construct the canonical debouncer when the editor appears.")
        #expect(source.contains("ensureContentDebouncer().enqueue(newText)"),
                "Text changes must enqueue into CodeEditorContentDebouncer, not bypass it with a local Task debounce.")
        #expect(source.contains("@State private var textSnapshotRevision: UInt64 = 0"))
        #expect(source.contains("guard textSnapshotTask == nil else { return }"),
                "Source snapshots should share one quiet-window worker instead of retaining one task/String revision per keystroke.")
        #expect(source.contains("guard scheduledRevision == textSnapshotRevision else { continue }"))
        #expect(!source.contains("private func scheduleTextSnapshotPublish(_ newText: String)"))
        #expect(source.contains("@State private var livePreviewRevision: UInt64 = 0"))
        #expect(source.contains("guard livePreviewTask == nil else { return }"))
        #expect(source.contains("guard scheduledRevision == livePreviewRevision else { continue }"))
        #expect(!source.contains("private func scheduleLivePreviewUpdate(for content: String)"))
        #expect(source.contains("@State private var outlineRefreshRevision: UInt64 = 0"))
        #expect(source.contains("guard outlineRefreshTask == nil else { return }"))
        #expect(source.contains("guard scheduledRevision == outlineRefreshRevision else { continue }"))
        #expect(!source.contains("private func scheduleOutlineRefresh(for content: String"))
        #expect(source.contains("let onTextSnapshot: ((String) -> Void)?"),
                "Hosts need an immediate live text snapshot separate from debounced persistence.")
        #expect(source.contains("let onEditStarted: (@MainActor () -> Void)?"))
        #expect(source.contains("onContentDirty: onEditStarted"))
        #expect(adapter.contains("var onContentDirty: (@MainActor () -> Void)?"))
        #expect(adapter.contains("context.coordinator.onContentDirty = onContentDirty"))
        #expect(coordinator.contains("var onContentDirty: (@MainActor () -> Void)?"))
        #expect(coordinator.contains("private var didReportPendingContentDirty = false"))
        #expect(coordinator.contains("self.onContentDirty?()"))
        #expect(adapter.contains("var liveTextQueryKey: UUID?"))
        #expect(adapter.contains("context.coordinator.registerLiveTextQuery(key: liveTextQueryKey, webView: webView)"))
        #expect(coordinator.contains("final class MarkEditCoreEditorLiveTextRegistry"))
        #expect(coordinator.contains("guard entries[registration.key]?.token == registration.token else { return }"))
        #expect(coordinator.contains("replaceFetch(for: liveTextRegistration)"))
        #expect(coordinator.contains("let retryEntry = entries[key], retryEntry.token == entry.token"))
        #expect(coordinator.contains("window.webModules?.core?.getEditorText?.()"))
        #expect(coordinator.contains("DispatchQueue.main.asyncAfter(deadline: .now() + 1)"))
        #expect(coordinator.contains("if (contentDirty.value)"))
        #expect(!coordinator.contains("if (contentDirty) {"))
        #expect(workspace.contains("onEditStarted: {\n                        markDocumentEditorDirtyBeforeDebouncedSave()"))
        #expect(workspace.contains("private func markEditorDirtyBeforeDebouncedSave()"))
        #expect(workspace.contains("private func markDocumentEditorDirtyBeforeDebouncedSave()"))
        #expect(workspace.contains("themeOverride: noteWorkspaceTheme,\n                onEditStarted: {\n                    markEditorDirtyBeforeDebouncedSave()"))
        #expect(workspace.contains("_ = noteSession.recordUserEdit(source: .user)"))
        #expect(workspace.contains("liveTextQueryKey: sourceEditorLiveTextQueryKey"))
        let liveQueryRange = try #require(workspace.range(of: "MarkEditCoreEditorLiveTextRegistry.shared.fetchText("))
        let sourcePersistRange = try #require(workspace.range(
            of: "let saved = await enqueueSourceEditorPersistence(",
            range: liveQueryRange.upperBound..<workspace.endIndex
        ))
        #expect(liveQueryRange.lowerBound < sourcePersistRange.lowerBound,
                "Lens-switch and teardown persistence must query the mounted Source buffer first.")
        #expect(workspace.contains("guard flushResult != .blocked else { return }"),
                "A failed final Source save must not be reported as a clean lease close.")
        #expect(workspace.contains("if liveContent == nil, hadDirtyLease"))
        #expect(workspace.contains("refusing to close or switch dirty Source without a live editor snapshot"),
                "Dirty Source must fail closed if teardown has already made an exact buffer query impossible.")
        #expect(workspace.contains("@State private var sourcePersistenceTask: Task<Bool, Never>?"))
        #expect(workspace.contains("let predecessor = sourcePersistenceTask"))
        #expect(workspace.contains("_ = await predecessor.value"),
                "Every Source write must await its predecessor so commit order matches enqueue order.")
        #expect(workspace.contains("if sourceEditorRevision == editorRevision"))
        #expect(workspace.contains("_ = noteSession.recordUserEdit(source: .user)"),
                "An older completed write must leave a newer edit dirty instead of declaring the session clean.")
        let liveTextChange = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: source,
            startingAt: ".onChange(of: text) { _, newText in",
            endingBefore: "            .onChange(of: initialContent)"
        ))
        let snapshotRange = try #require(liveTextChange.range(of: "scheduleTextSnapshotPublish()"))
        let enqueueRange = try #require(liveTextChange.range(of: "ensureContentDebouncer().enqueue(newText)"))
        #expect(snapshotRange.lowerBound < enqueueRange.lowerBound,
                "Source lens snapshots should update before the save debouncer can defer persistence.")
        #expect(!source.contains("try? await Task.sleep(for: .milliseconds(500))"),
                "The old ad-hoc 500ms content-change debounce should not remain in the editor text-change path.")
        let flushRange = try #require(source.range(of: "contentDebouncer?.flush(text)"))
        let detachRange = try #require(source.range(of: "contentDebouncer?.detach()"))
        #expect(flushRange.lowerBound < detachRange.lowerBound,
                "CodeEditorView must flush the visible Source text before detaching the debouncer during lens switches.")
        #expect(source.contains("if liveTextQueryKey == nil {\n                        contentDebouncer?.flush(text)"),
                "A workspace-owned live flush must not race a second stale host-snapshot write during teardown.")
    }

    @Test("MarkEdit Source engines flush latest text during teardown")
    func markEditSourceEnginesFlushLatestTextDuringTeardown() throws {
        let markEditChrome = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
        let coreEditorCoordinator = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift")
        let detachStart = try #require(coreEditorCoordinator.range(of: "func detach(from webView: WKWebView)"))
        let detachEnd = try #require(coreEditorCoordinator.range(
            of: "func registerLiveTextQuery(key: UUID?, webView: WKWebView)",
            range: detachStart.upperBound..<coreEditorCoordinator.endIndex
        ))
        let coreDetach = String(coreEditorCoordinator[detachStart.lowerBound..<detachEnd.lowerBound])

        let flushRange = try #require(markEditChrome.range(of: "flushCurrentTextBeforeDetach(from: viewController)"))
        let pollingCancelRange = try #require(markEditChrome.range(of: "pollingTask?.cancel()"))
        #expect(flushRange.lowerBound < pollingCancelRange.lowerBound,
                "Full MarkEdit markdown chrome must sample editor text before teardown cancels polling.")
        #expect(markEditChrome.contains("let nextText = await viewController.editorText"))
        #expect(markEditChrome.contains("applyObservedText(nextText)"))
        #expect(coreEditorCoordinator.contains(#"window.addEventListener("pagehide", () => postSnapshot("pagehide"));"#),
                "CoreEditor fallback should push a final snapshot when WebKit starts unloading the Source page.")
        #expect(coreDetach.contains("if hasLoadedEditor, !webView.isLoading"))
        #expect(coreDetach.contains("Self.requestCurrentEditorText(from: webView)"))
        #expect(coreDetach.contains("finalTextPromise.resume(returning: text.wrappedValue)"))
        let readyBranch = try #require(coreDetach.range(of: "if hasLoadedEditor, !webView.isLoading"))
        let liveQuery = try #require(coreDetach.range(
            of: "Self.requestCurrentEditorText(from: webView)",
            range: readyBranch.upperBound..<coreDetach.endIndex
        ))
        let fallbackBranch = try #require(coreDetach.range(
            of: "} else {",
            range: liveQuery.upperBound..<coreDetach.endIndex
        ))
        #expect(readyBranch.lowerBound < liveQuery.lowerBound && liveQuery.lowerBound < fallbackBranch.lowerBound,
                "Source teardown must not evaluate JavaScript against a loading or not-yet-ready CoreEditor page.")
    }

    @Test("MarkEdit Source terminal failure never injects into a loading page")
    func markEditSourceTerminalFailureStopsLoadingBeforePresentation() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift")
        let failureStart = try #require(source.range(of: "private func showLoadFailure("))
        let failureEnd = try #require(source.range(
            of: "private static func resetFailureMessage",
            range: failureStart.upperBound..<source.endIndex
        ))
        let failureSource = String(source[failureStart.lowerBound..<failureEnd.lowerBound])

        #expect(failureSource.contains("if webView.isLoading"))
        #expect(failureSource.contains("guard force else { return }"))
        #expect(failureSource.contains("terminalLoadFailureGeneration = loadGeneration"))
        #expect(failureSource.contains("webView.stopLoading()"))
        #expect(failureSource.contains("webView.loadHTMLString("))
        #expect(failureSource.contains("Self.loadFailureDocument(message: message)"))
        #expect(failureSource.contains("guard !webView.isLoading else { return }"))
        #expect(!failureSource.contains("force || !webView.isLoading"))
        #expect(!failureSource.contains("Painting on a mid-load"))
        #expect(source.contains("guard terminalLoadFailureGeneration != loadGeneration else { return }"))
        #expect(source.contains("terminalLoadFailureGeneration = nil"))
    }

    @Test("CodeEditorView feeds live preferences into MarkEdit CoreEditor")
    func codeEditorViewFeedsLivePreferencesIntoMarkEditCoreEditor() throws {
        let source = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let adapter = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorState.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorThemePalette.swift")

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
            + "\n"
            + loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorThemePalette.swift")
        let coordinator = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift")

        #expect(source.contains("MarkEditCodeEditorRepresentable("),
                "Code files must render through MarkEdit CoreEditor by default, with v1 kept as an explicit fallback.")
        #expect(source.contains("theme: codeEditorTheme"),
                "Epistemos theme changes and embedded-surface overrides must feed the CoreEditor adapter.")
        #expect(adapter.contains("AppTheme.epistemosSourceTheme(for: theme).editorTheme"),
                "CoreEditor should map Epistemos themes into MarkEdit source themes instead of falling back to a plain body surface.")
        #expect(adapter.contains("MarkEditCoreEditorThemePalette.current(theme: theme)"),
                "CoreEditor must also receive Epistemos theme tokens so Ember/Platinum do not paint generic built-in canvases.")
        #expect(adapter.contains("MarkEditCoreEditorThemeOverlay.script("),
                "CoreEditor should apply the Epistemos token overlay in-place with the existing no-reload theme switch.")
        #expect(adapter.contains("let surfaceTheme = theme"),
                "The CoreEditor palette must use the already-selected app surface; applying .surfaceVariant(.other) again drifts the preset themes.")
        #expect(!adapter.contains("let surfaceTheme = theme.surfaceVariant(.other)"),
                "The CoreEditor palette must not double-variant the active theme surface.")
        #expect(adapter.contains("window.__epistemosCoreEditorThemePalette"),
                "The web editor should expose the applied token payload for visual/debug verification.")
        #expect(adapter.contains(".cm-scroller::-webkit-scrollbar,"),
                "The CoreEditor scroll rail must be explicitly bound to the active Epistemos surface instead of WebKit's generic gray track.")
        #expect(adapter.contains(".cm-scroller::-webkit-scrollbar-track,"),
                "The CoreEditor scrollbar track must remain part of the editor canvas.")
        #expect(adapter.contains(".cm-scroller::-webkit-scrollbar-corner"),
                "The CoreEditor scrollbar corner must not reveal a separate embedded-panel color.")
        #expect(adapter.contains(".cm-scroller::-webkit-scrollbar-thumb"),
                "The CoreEditor scrollbar thumb must use an explicit Epistemos token rather than a browser default.")
        #expect(coordinator.contains("self.applyTheme(themeName: state.themeName, palette: state.themePalette, to: webView)"),
                "CoreEditor reset can repaint the built-in source theme; the Epistemos token overlay must be reapplied after reset succeeds.")
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

    @Test("CoreEditor lease transitions change read-only state in place")
    func coreEditorLeaseTransitionsChangeReadOnlyStateInPlace() throws {
        let state = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorState.swift")
        let coordinator = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift")
        let reloadSection = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: state,
            startingAt: "func requiresReload(comparedTo other: MarkEditCoreEditorState) -> Bool",
            endingBefore: "    private var clampedTabWidth"
        ))

        #expect(state.contains("func replacingEditable(_ nextIsEditable: Bool)"))
        #expect(!reloadSection.contains("isEditable != other.isEditable"))
        #expect(coordinator.contains("private func applyReadOnlyMode("))
        #expect(coordinator.contains("window.webModules.config.setReadOnlyMode("))
        #expect(coordinator.contains("window.editor.state.readOnly ==="))
        #expect(coordinator.contains("readOnlyApplicationGeneration"))
        #expect(coordinator.contains("state.isEditable != last.isEditable"))
    }

    @Test("CoreEditor process recovery never prefers an empty renderer over host text")
    func coreEditorProcessRecoveryNeverPrefersEmptyRendererOverHostText() throws {
        #expect(MarkEditCoreEditorCoordinator.preferredRecoveryText(
            hostText: "let host = true\n",
            stateText: ""
        ) == "let host = true\n")
        #expect(MarkEditCoreEditorCoordinator.preferredRecoveryText(
            hostText: "stale host\n",
            stateText: "let newer = true\n"
        ) == "let newer = true\n")

        let coordinator = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift")
        #expect(coordinator.contains("let recoveryState = pendingState ?? lastAppliedState ?? loadingState"))
        #expect(coordinator.contains("preferredRecoveryText("))
        #expect(coordinator.contains("loadEditor(into: webView, initialState: recoveredState)"))
        #expect(!coordinator.contains("editor blanked; reopen to recover"))
    }

    @Test("Code editors reset legacy invisibles-on installs back to a clean source view")
    func codeEditorsResetLegacyInvisiblesOnInstalls() throws {
        let codeEditor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let htmlWorkspace = try loadRepoTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")

        #expect(codeEditor.contains(#"@AppStorage("codeEditor.invisiblesDefaultReset.20260702") private var didResetInvisiblesDefault = false"#))
        #expect(codeEditor.contains("resetInvisiblesDefaultIfNeeded()"))
        #expect(codeEditor.contains("showInvisibles = false"))
        #expect(htmlWorkspace.contains(#"@AppStorage("codeEditor.invisiblesDefaultReset.20260702") private var didResetInvisiblesDefault = false"#))
        #expect(htmlWorkspace.contains("resetInvisiblesDefaultIfNeeded()"))
        #expect(htmlWorkspace.contains("sourceShowInvisibles = false"))
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
        #expect(source.contains(#".keyboardShortcut("f", modifiers: .command)"#),
                "The visible Source search bar must be reachable from Cmd-F.")
        #expect(source.contains(#".help("Find (Cmd-F)")"#),
                "The Source find affordance should advertise the shortcut it handles.")
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
        #expect(source.contains("semanticStatusCopyText"),
                "Cross-file definitions must expose an actionable target instead of a dead-end status.")
        #expect(source.contains("definitionTargetText(\n                            uri: definition.uri"),
                "Cross-file definition targets should include a concrete path/URI, line, and column.")
        #expect(source.contains("Copy definition target"),
                "The LSP status surface must expose a copy action for cross-file definitions.")
        #expect(!source.contains("cross-file navigation is not wired yet"),
                "Cross-file definition lookup must not regress to a non-actionable placeholder.")
    }

    @Test("Code editor large-file affordances stay on CoreEditor")
    func codeEditorLargeFileAffordancesStayOnCoreEditor() throws {
        let editor = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        let textUtilities = try loadRepoTextFile("Epistemos/Views/Notes/CodeEditorTextUtilities.swift")
        let adapter = try loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorView.swift")
            + "\n"
            + loadRepoTextFile("Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift")
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
        #expect(adapter.contains("document.addEventListener(\"selectionchange\", scheduleMetadataSnapshot, true)"),
                "Cursor/selection tracking should come from the CoreEditor bridge.")
        #expect(adapter.contains("document.addEventListener(\"input\", scheduleTextSnapshot, true)"),
                "Content snapshots must be driven by the input path, not by selection/cursor events.")
        #expect(adapter.contains("const textSnapshotDelays = {"),
                "Large CoreEditor buffers need adaptive text snapshot delays instead of per-frame full-document IPC.")
        #expect(adapter.contains("payload.text = text"),
                "Only explicit text snapshots should include the full editor buffer in the WK bridge payload.")
        #expect(!adapter.contains("setInterval(() => postSnapshot(\"snapshot\"), 250);"),
                "CoreEditor must not serialize the whole document on a fixed 250ms poll.")
        #expect(!editor.contains("textController?.textView"),
                "CodeEditorView must not depend on the old native text controller for the default MarkEdit surface.")
        #expect(!editor.contains("gutterView"),
                "The dormant fallback gutter must not be mounted on the production code path.")
        #expect(!editor.contains("CodeEditorLineMetrics.textWindow("),
                "Production code editor viewporting is owned by CoreEditor, not the old Swift text-window overlay.")
        #expect(!editor.contains("nonisolated enum CodeEditorLineMetrics"),
                "Pure text metrics should live outside the SwiftUI editor shell.")
        #expect(textUtilities.contains("nonisolated enum CodeEditorLineMetrics"))
        #expect(textUtilities.contains("nonisolated enum CodeEditorSearchEngine"))
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
