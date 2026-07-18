import AppKit
import Foundation
import SwiftUI
import Testing
import WebKit
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX
#error("KEELSTONE App Store lens-switch tests must compile with EPISTEMOS_APP_STORE and MAS_SANDBOX.")
#endif

private actor MarkdownDocumentWriteGate {
    private var didStart = false
    private var didRelease = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func markStarted() {
        didStart = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func waitUntilStarted() async {
        guard !didStart else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func waitUntilReleased() async {
        guard !didRelease else { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func release() {
        didRelease = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

private final class MarkdownDocumentLensSwitchBundleToken {}

private func bundledRepositoryTextFixture(_ relativePath: String) throws -> String {
    let bundle = Bundle(for: MarkdownDocumentLensSwitchBundleToken.self)
    guard let resources = bundle.resourceURL else {
        throw CocoaError(.fileNoSuchFile)
    }
    let candidate = resources
        .appendingPathComponent("RepositorySourceFixtures", isDirectory: true)
        .appendingPathComponent(relativePath)
    return try String(contentsOf: candidate, encoding: .utf8)
}

@MainActor
private func firstDescendant<T: NSView>(of type: T.Type, in view: NSView) -> T? {
    if let match = view as? T { return match }
    for child in view.subviews {
        if let match = firstDescendant(of: type, in: child) {
            return match
        }
    }
    return nil
}

private enum JavaScriptBooleanEvaluationResult: Sendable {
    case value(Bool)
    case transportFailure
}

private final class JavaScriptBooleanEvaluationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<JavaScriptBooleanEvaluationResult, Never>?

    init(continuation: CheckedContinuation<JavaScriptBooleanEvaluationResult, Never>) {
        self.continuation = continuation
    }

    func resume(returning value: JavaScriptBooleanEvaluationResult) {
        lock.lock()
        let pendingContinuation = continuation
        continuation = nil
        lock.unlock()
        pendingContinuation?.resume(returning: value)
    }
}

@MainActor
private func evaluateBooleanOnce(
    _ script: String,
    in webView: WKWebView
) async -> JavaScriptBooleanEvaluationResult {
    await withCheckedContinuation { continuation in
        let gate = JavaScriptBooleanEvaluationGate(continuation: continuation)
        webView.evaluateJavaScript(script) { value, error in
            guard error == nil else {
                gate.resume(returning: .transportFailure)
                return
            }
            gate.resume(returning: .value(value as? Bool == true))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) {
            gate.resume(returning: .transportFailure)
        }
    }
}

@MainActor
private func evaluateBoolean(
    _ script: String,
    in webView: WKWebView,
    transportRetries: Int = 0
) async -> Bool {
    var retriesRemaining = max(0, transportRetries)
    while true {
        switch await evaluateBooleanOnce(script, in: webView) {
        case .value(let value):
            return value
        case .transportFailure where retriesRemaining > 0:
            retriesRemaining -= 1
            await Task.yield()
        case .transportFailure:
            return false
        }
    }
}

@MainActor
private func waitUntil(
    timeout: Duration,
    condition: @escaping @MainActor () async -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(25))
    }
    return await condition()
}

private func javaScriptStringLiteral(_ value: String) -> String {
    let data = try! JSONEncoder().encode(value)
    return String(data: data, encoding: .utf8)!
}

@Suite("KEELSTONE Markdown Document Lens Switching", .serialized)
@MainActor
struct MarkdownDocumentLensSwitchTests {
    @Test("visible editor surface owns flush routing even when Markdown Source exists")
    func visibleEditorSurfaceOwnsFlushRouting() {
        #expect(NoteEditorFlushOwner(activeMode: .source) == .source)
        #expect(NoteEditorFlushOwner(activeMode: .document) == .document)
        #expect(NoteEditorFlushOwner(activeMode: .edit) == .markdownBody)
        #expect(NoteEditorFlushOwner(activeMode: .preview) == .markdownBody)
    }

    @Test("Markdown notes expose Prose Preview and Source but not independent Epdoc")
    func markdownNotesExcludeIndependentEpdocSurface() {
        #expect(NoteWorkspaceMode.defaultMarkdown == .edit)
        #expect(
            NoteWorkspaceMode.markdownModes(hasSourceRoute: true)
                == [.edit, .preview, .source]
        )
        #expect(
            NoteWorkspaceMode.markdownModes(hasSourceRoute: false)
                == [.edit, .preview]
        )
    }

    @Test("CodeMirror transaction mirror preserves UTF-16 edits and rejects revision gaps")
    func codeMirrorTransactionMirrorPreservesUTF16Edits() {
        let initial = "A café ☕️ B\r\nSecond line"
        let mirror = MarkEditEpdocDeltaMirror(text: initial)
        let initialLength = (initial as NSString).length
        let emojiRange = (initial as NSString).range(of: "☕️")
        let replacement = "🧠"
        let replacementLength = (replacement as NSString).length

        #expect(
            mirror.apply(
                MarkEditEpdocTransaction(
                    documentInstance: "document-a",
                    revision: 1,
                    startUTF16Length: initialLength,
                    endUTF16Length: initialLength - emojiRange.length + replacementLength,
                    changes: [
                        MarkEditEpdocDeltaChange(
                            fromUTF16: emojiRange.location,
                            toUTF16: emojiRange.location + emojiRange.length,
                            insertedText: replacement
                        ),
                    ]
                )
            ) == .accepted
        )
        #expect(mirror.checkpointText() == "A café 🧠 B\r\nSecond line")

        guard let beforeGap = mirror.checkpointText() else {
            Issue.record("Expected a synchronized mirror before the revision-gap check")
            return
        }
        #expect(
            mirror.apply(
                MarkEditEpdocTransaction(
                    documentInstance: "document-a",
                    revision: 3,
                    startUTF16Length: (beforeGap as NSString).length,
                    endUTF16Length: (beforeGap as NSString).length + 1,
                    changes: [
                        MarkEditEpdocDeltaChange(
                            fromUTF16: (beforeGap as NSString).length,
                            toUTF16: (beforeGap as NSString).length,
                            insertedText: "!"
                        ),
                    ]
                )
            ) == .requiresCheckpoint
        )
        #expect(mirror.checkpointText() == nil)

        mirror.reconcile(
            text: beforeGap + "!",
            documentInstance: "document-a",
            revision: 3
        )
        #expect(mirror.checkpointText() == beforeGap + "!")
    }

    @Test("CodeMirror transaction mirror applies multi-range changes from the original document")
    func codeMirrorTransactionMirrorAppliesMultipleRangesInReverse() {
        let initial = "0123456789"
        let mirror = MarkEditEpdocDeltaMirror(text: initial)

        #expect(
            mirror.apply(
                MarkEditEpdocTransaction(
                    documentInstance: "document-b",
                    revision: 1,
                    startUTF16Length: 10,
                    endUTF16Length: 10,
                    changes: [
                        MarkEditEpdocDeltaChange(fromUTF16: 1, toUTF16: 3, insertedText: "ab"),
                        MarkEditEpdocDeltaChange(fromUTF16: 7, toUTF16: 9, insertedText: "xy"),
                    ]
                )
            ) == .accepted
        )
        #expect(mirror.checkpointText() == "0ab3456xy9")

        #expect(
            mirror.apply(
                MarkEditEpdocTransaction(
                    documentInstance: "stale-document",
                    revision: 2,
                    startUTF16Length: 10,
                    endUTF16Length: 11,
                    changes: [
                        MarkEditEpdocDeltaChange(fromUTF16: 10, toUTF16: 10, insertedText: "!")
                    ]
                )
            ) == .ignoredStaleInstance
        )
        #expect(mirror.checkpointText() == "0ab3456xy9")
    }

    @Test("hosted CodeMirror loads, edits, deletes, scrolls, and saves the Keelstone-scale Markdown")
    func hostedCodeMirrorHandlesKeelstoneScaleMarkdown() async throws {
        let fixture = try bundledRepositoryTextFixture(
            "docs/plans/keelstone/KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md"
        )
        #expect(fixture.utf8.count >= 450_000)
        #expect(fixture.split(whereSeparator: \.isWhitespace).count >= 60_000)

        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let pageID = "appstore-codemirror-large-document-\(UUID().uuidString)"
        var savedMarkdown: [String] = []
        coordinator.configure(
            pageId: pageID,
            title: "Keelstone Large Document",
            markdown: fixture,
            theme: .light,
            noteRelativePath: "notes/keelstone-large-document.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )

        let host = NSHostingView(
            rootView: MarkEditEpdocEditorRepresentable(
                controller: coordinator.controller,
                theme: .light
            )
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.alphaValue = 0.01
        window.contentView = host
        host.frame = window.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 960, height: 720)
        host.layoutSubtreeIfNeeded()
        window.orderBack(nil)
        defer {
            window.close()
            if let registration = coordinator.currentSurfaceRegistration() {
                coordinator.unregisterSurface(registration)
            }
        }

        guard let webView = firstDescendant(of: WKWebView.self, in: host) else {
            Issue.record("Expected the hosted Epdoc surface to create a WKWebView")
            return
        }
        let expectedUTF16Length = (fixture as NSString).length
        let clock = ContinuousClock()
        let loadStart = clock.now
        let becameReady = await waitUntil(timeout: .seconds(6)) {
            await evaluateBoolean(
                "Boolean(window.editor && window.editor.state.doc.length === \(expectedUTF16Length))",
                in: webView
            )
        }
        guard becameReady else {
            Issue.record("CodeMirror did not become ready with the exact large document")
            return
        }
        let initialSnapshot = await coordinator.controller.currentMarkdownSnapshotFromEditor()
        let loadDuration = loadStart.duration(to: clock.now)
        #expect(initialSnapshot == fixture)
        #expect(loadDuration < .seconds(2.5))
        #expect(!coordinator.controller.toolbarModel.isDirty)
        #expect(savedMarkdown.isEmpty)

        let sentinel = "\n\n<!-- EPISTEMOS-LARGE-DOC-SENTINEL café 🧠 -->"
        let sentinelLiteral = javaScriptStringLiteral(sentinel)
        let sentinelUTF16Length = (sentinel as NSString).length
        let editStart = clock.now
        let inserted = await evaluateBoolean(
            """
            (() => {
              const editor = window.editor;
              if (!editor) { return false; }
              const previousApplying = Boolean(window.__epistemosApplyingMarkEditState);
              window.__epistemosApplyingMarkEditState = true;
              try {
                const suffixFrom = Math.max(0, editor.state.doc.length - \(sentinelUTF16Length));
                if (editor.state.doc.sliceString(suffixFrom) !== \(sentinelLiteral)) {
                  const from = editor.state.doc.length;
                  editor.dispatch({ changes: { from, insert: \(sentinelLiteral) } });
                }
                const finalSuffixFrom = editor.state.doc.length - \(sentinelUTF16Length);
                return editor.state.doc.sliceString(finalSuffixFrom) === \(sentinelLiteral);
              } finally {
                window.__epistemosApplyingMarkEditState = previousApplying;
              }
            })()
            """,
            in: webView,
            transportRetries: 1
        )
        let editDuration = editStart.duration(to: clock.now)
        #expect(inserted)
        #expect(editDuration < .milliseconds(100))
        #expect(
            await waitUntil(timeout: .seconds(1)) {
                coordinator.controller.toolbarModel.isDirty
            }
        )

        let insertFlushStart = clock.now
        #expect(await coordinator.flushPendingMarkdown())
        let insertFlushDuration = insertFlushStart.duration(to: clock.now)
        #expect(insertFlushDuration < .seconds(1))
        #expect(savedMarkdown.last == fixture + sentinel)

        for fraction in [0.1, 0.5, 0.9] {
            let scrolled = await evaluateBoolean(
                """
                (() => {
                  const editor = window.editor;
                  if (!editor) { return false; }
                  const maximum = Math.max(0, editor.scrollDOM.scrollHeight - editor.scrollDOM.clientHeight);
                  editor.scrollDOM.scrollTop = maximum * \(fraction);
                  editor.requestMeasure();
                  return editor.visibleRanges.length > 0;
                })()
                """,
                in: webView
            )
            #expect(scrolled)
            try? await Task.sleep(for: .milliseconds(50))
            #expect(
                await evaluateBoolean(
                    "Boolean(window.editor && window.editor.visibleRanges.length > 0)",
                    in: webView
                )
            )
        }

        let deleteStart = clock.now
        let deleted = await evaluateBoolean(
            """
            (() => {
              const editor = window.editor;
              if (!editor || editor.state.doc.length < \(sentinelUTF16Length)) { return false; }
              const to = editor.state.doc.length;
              const from = to - \(sentinelUTF16Length);
              if (editor.state.doc.sliceString(from, to) === \(sentinelLiteral)) {
                editor.dispatch({ changes: { from, to, insert: "" } });
              }
              return editor.state.doc.length === \(expectedUTF16Length) &&
                editor.state.doc.sliceString(
                  Math.max(0, editor.state.doc.length - \(sentinelUTF16Length))
                ) !== \(sentinelLiteral);
            })()
            """,
            in: webView,
            transportRetries: 1
        )
        let deleteDuration = deleteStart.duration(to: clock.now)
        #expect(deleted)
        #expect(deleteDuration < .milliseconds(100))
        #expect(
            await waitUntil(timeout: .seconds(1)) {
                coordinator.controller.toolbarModel.isDirty
            }
        )
        #expect(await coordinator.flushPendingMarkdown())
        #expect(savedMarkdown.last == fixture)

        try? await Task.sleep(for: .milliseconds(1_500))
        let finalSnapshot = await coordinator.controller.currentMarkdownSnapshotFromEditor()
        #expect(finalSnapshot == fixture)
        #expect(finalSnapshot?.contains("EPISTEMOS-LARGE-DOC-SENTINEL") == false)
    }

    @Test("Document uses the CodeMirror canvas while retaining a legacy rollback engine")
    func documentUsesCodeMirrorCanvasWithLegacyRollback() {
        #expect(EpdocEditorCanvasEngine.productionDefault == .codeMirror)
        #expect(EpdocEditorCanvasEngine.legacyFallback == .legacyTiptap)

        let controller = EpdocEditorChromeController()
        let initialMarkdown = "# Initial\n\nBody\n"
        let editedMarkdown = "# Initial\n\nBody edited in CodeMirror.\n"
        var emittedMarkdown: [String] = []

        controller.loadInitialContent(
            Data(#"{"type":"doc","content":[{"type":"paragraph"}]}"#.utf8),
            title: "CodeMirror Epdoc",
            markdownSource: initialMarkdown
        )
        controller.onMarkdownChanged = { markdown, writeback in
            emittedMarkdown.append(markdown)
            #expect(writeback == nil)
        }

        controller.markCodeMirrorContentDirty()
        controller.acceptCodeMirrorMarkdownSnapshot(editedMarkdown)

        #expect(controller.toolbarModel.isDirty)
        #expect(controller.latestMarkdownSnapshot == editedMarkdown)
        #expect(emittedMarkdown == [editedMarkdown])
    }

    @Test("CodeMirror dirty edits flush from one exact Markdown checkpoint")
    func codeMirrorDirtyEditFlushesFromExactCheckpoint() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let initialMarkdown = "# Initial\n\nText that will be replaced.\n"
        let editedMarkdown = "# Initial\n\nUnicode replacement: café ☕️.\n"
        var editStarts = 0
        var snapshotRequests = 0
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "appstore-codemirror-exact-checkpoint",
            title: "Exact Checkpoint",
            markdown: initialMarkdown,
            theme: .light,
            noteRelativePath: "notes/appstore-codemirror-exact-checkpoint.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            onEditStarted: {
                editStarts += 1
            },
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.installEditorDispatch { _ in }
        coordinator.controller.installMarkdownSnapshotProvider {
            snapshotRequests += 1
            return editedMarkdown
        }
        coordinator.controller.handleBridgeMessage(.editorReady)

        coordinator.controller.markCodeMirrorContentDirty()

        #expect(coordinator.controller.toolbarModel.isDirty)
        #expect(savedMarkdown.isEmpty)

        let flushed = await coordinator.flushPendingMarkdown()

        #expect(flushed)
        #expect(editStarts == 1)
        #expect(snapshotRequests == 1)
        #expect(savedMarkdown == [editedMarkdown])
        #expect(coordinator.controller.toolbarModel.isDirty == false)
    }

    @Test("Document Save keeps dirty state until the exact CodeMirror write succeeds")
    func documentSaveKeepsDirtyUntilCodeMirrorWriteSucceeds() async throws {
        let chromeSource = try bundledRepositoryTextFixture(
            "Epistemos/Views/Epdoc/EpdocEditorChromeView.swift"
        )
        #expect(
            !chromeSource.contains(
                "controller.onSave()\n            controller.toolbarModel.isDirty = false"
            )
        )

        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let gate = MarkdownDocumentWriteGate()
        let initialMarkdown = "# Initial\n"
        let editedMarkdown = "# Initial\n\nDirty-only CodeMirror edit.\n"
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "appstore-codemirror-save-dirty",
            title: "Save Dirty",
            markdown: initialMarkdown,
            theme: .light,
            noteRelativePath: "notes/appstore-codemirror-save-dirty.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { markdown in
                savedMarkdown.append(markdown)
                await gate.markStarted()
                await gate.waitUntilReleased()
                return true
            }
        )
        coordinator.controller.installEditorDispatch { _ in }
        coordinator.controller.installMarkdownSnapshotProvider {
            editedMarkdown
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        coordinator.controller.markCodeMirrorContentDirty()

        coordinator.controller.onSave()
        await gate.waitUntilStarted()

        #expect(coordinator.controller.toolbarModel.isDirty)
        #expect(savedMarkdown == [editedMarkdown])

        await gate.release()
        #expect(
            await waitUntil(timeout: .seconds(1)) {
                coordinator.controller.toolbarModel.isDirty == false
            }
        )
        #expect(savedMarkdown == [editedMarkdown])
    }

    @Test("dirty-only CodeMirror page switch checkpoints the old page before replacement")
    func dirtyCodeMirrorPageSwitchCheckpointsOldPageFirst() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let initialMarkdown = "# Old page\n"
        let editedMarkdown = "# Old page\n\nTyped immediately before page switch.\n"
        var oldPageSaves: [String] = []
        var newPageSaves: [String] = []

        coordinator.configure(
            pageId: "appstore-codemirror-old-page",
            title: "Old Page",
            markdown: initialMarkdown,
            theme: .light,
            noteRelativePath: "notes/appstore-codemirror-old-page.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                oldPageSaves.append($0)
                return true
            }
        )
        coordinator.controller.installEditorDispatch { _ in }
        coordinator.controller.installMarkdownSnapshotProvider {
            editedMarkdown
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        coordinator.controller.handleBridgeMessage(.loadSettled, epoch: 1)
        coordinator.controller.markCodeMirrorContentDirty()

        coordinator.configure(
            pageId: "appstore-codemirror-new-page",
            title: "New Page",
            markdown: "# New page\n",
            theme: .light,
            noteRelativePath: "notes/appstore-codemirror-new-page.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                newPageSaves.append($0)
                return true
            }
        )

        #expect(
            await waitUntil(timeout: .seconds(1)) {
                oldPageSaves == [editedMarkdown]
                    && coordinator.currentSurfaceRegistration()?.pageId
                        == "appstore-codemirror-new-page"
            }
        )
        #expect(!oldPageSaves.contains(initialMarkdown))
        #expect(newPageSaves.isEmpty)
    }

    @Test("clean same-page external Markdown reaches the visible CodeMirror canvas")
    func cleanSamePageExternalMarkdownReachesVisibleCodeMirrorCanvas() {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let initialMarkdown = "# Initial\n"
        let externalMarkdown = "# Initial\n\nChanged outside Document mode.\n"
        var commands: [EpdocEditorCommand] = []

        coordinator.configure(
            pageId: "appstore-codemirror-clean-external",
            title: "Clean External",
            markdown: initialMarkdown,
            theme: .light,
            noteRelativePath: "notes/appstore-codemirror-clean-external.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        coordinator.controller.installEditorDispatch { command in
            commands.append(command)
        }
        coordinator.controller.handleBridgeMessage(.editorReady)
        commands.removeAll()

        coordinator.configure(
            pageId: "appstore-codemirror-clean-external",
            title: "Clean External",
            markdown: externalMarkdown,
            theme: .light,
            noteRelativePath: "notes/appstore-codemirror-clean-external.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )

        #expect(
            commands == [
                .setMarkdownForLoad(markdown: externalMarkdown, epoch: 2),
                .focusStart,
            ]
        )
        #expect(coordinator.controller.latestMarkdownSnapshot == externalMarkdown)
        #expect(!coordinator.controller.toolbarModel.isDirty)
    }

    @Test("Swift resets stay non-user without dropping visible CodeMirror transactions")
    func swiftResetsStayNonUserWithoutDroppingVisibleTransactions() throws {
        let coordinatorSource = try bundledRepositoryTextFixture(
            "Epistemos/Views/Notes/MarkEditCoreEditorCoordinator.swift"
        )

        #expect(
            coordinatorSource.contains(
                "const applying = Boolean(window.__epistemosApplyingMarkEditState);"
            )
        )
        #expect(
            !coordinatorSource.contains(
                "if (applying) {\n          scheduleMetadataSnapshot();\n          return;\n        }"
            )
        )
        #expect(
            !coordinatorSource.contains(
                "applying: false,\n            contentDirty: true"
            )
        )
        let transactionHandler = try #require(
            coordinatorSource.range(
                of: "if payload[\"kind\"] as? String == \"transaction\""
            )
        )
        let dirtyHandler = try #require(
            coordinatorSource.range(
                of: "if payload[\"contentDirty\"] as? Bool == true",
                range: transactionHandler.lowerBound..<coordinatorSource.endIndex
            )
        )
        #expect(
            !coordinatorSource[transactionHandler.lowerBound..<dirtyHandler.lowerBound]
                .contains("guard !applying")
        )
        #expect(coordinatorSource.contains("let mirrorTextBeforeReset = mirror.checkpointText()"))
        #expect(coordinatorSource.contains("mirror.replaceTextPreservingClock(mirrorTextBeforeReset)"))

        let initialMarkdown = "# Initial\n"
        let hostMarkdown = "# Host replacement\n"
        let userSuffix = "\nUser edit after replacement.\n"
        let mirror = MarkEditEpdocDeltaMirror(text: initialMarkdown)
        let firstUserEdit = MarkEditEpdocTransaction(
            documentInstance: "document-1",
            revision: 1,
            startUTF16Length: (initialMarkdown as NSString).length,
            endUTF16Length: (initialMarkdown.appending("First edit.\n") as NSString).length,
            changes: [
                MarkEditEpdocDeltaChange(
                    fromUTF16: (initialMarkdown as NSString).length,
                    toUTF16: (initialMarkdown as NSString).length,
                    insertedText: "First edit.\n"
                )
            ]
        )
        #expect(mirror.apply(firstUserEdit) == .accepted)

        mirror.replaceTextPreservingClock(hostMarkdown)
        let postResetUserEdit = MarkEditEpdocTransaction(
            documentInstance: "document-1",
            revision: 2,
            startUTF16Length: (hostMarkdown as NSString).length,
            endUTF16Length: (hostMarkdown.appending(userSuffix) as NSString).length,
            changes: [
                MarkEditEpdocDeltaChange(
                    fromUTF16: (hostMarkdown as NSString).length,
                    toUTF16: (hostMarkdown as NSString).length,
                    insertedText: userSuffix
                )
            ]
        )

        #expect(mirror.apply(postResetUserEdit) == .accepted)
        #expect(mirror.checkpointText() == hostMarkdown + userSuffix)
    }

    @Test("stale Document teardown cannot unregister a replacement surface")
    func staleDocumentTeardownCannotUnregisterReplacementSurface() async {
        let registry = MarkdownDocumentSurfaceSaveRegistry.shared
        let pageID = "appstore-document-registry-\(UUID().uuidString)"
        let staleToken = UUID()
        let replacementToken = UUID()
        var flushedOwner = ""

        registry.register(pageId: pageID, token: staleToken) {
            flushedOwner = "stale"
            return true
        }
        registry.register(pageId: pageID, token: replacementToken) {
            flushedOwner = "replacement"
            return true
        }
        registry.unregister(pageId: pageID, token: staleToken)

        let flushed = await registry.flush(pageId: pageID)
        registry.unregister(pageId: pageID, token: replacementToken)

        #expect(flushed == true)
        #expect(flushedOwner == "replacement")
    }

    @Test("reactivated Document coordinator survives its delayed stale teardown")
    func reactivatedDocumentCoordinatorSurvivesDelayedTeardown() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let pageID = "appstore-document-reactivation-\(UUID().uuidString)"

        coordinator.beginSurfaceAppearance()
        coordinator.configure(
            pageId: pageID,
            title: "Reactivated Document",
            markdown: "# Reactivated\n",
            theme: .light,
            noteRelativePath: "notes/reactivated-document.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        guard let staleRegistration = coordinator.currentSurfaceRegistration() else {
            Issue.record("Expected the first Document registration")
            return
        }

        coordinator.beginSurfaceAppearance()
        coordinator.configure(
            pageId: pageID,
            title: "Reactivated Document",
            markdown: "# Reactivated\n",
            theme: .light,
            noteRelativePath: "notes/reactivated-document.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        guard let activeRegistration = coordinator.currentSurfaceRegistration() else {
            Issue.record("Expected the reactivated Document registration")
            return
        }

        coordinator.unregisterSurface(staleRegistration)
        let flushed = await MarkdownDocumentSurfaceSaveRegistry.shared.flush(pageId: pageID)
        coordinator.unregisterSurface(activeRegistration)

        #expect(staleRegistration != activeRegistration)
        #expect(flushed == true)
    }

    @Test("App Store early Document edit survives lens switch before load-settled echo")
    func earlyDocumentEditSurvivesLensSwitchBeforeLoadSettledEcho() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let initialMarkdown = "# Initial\n"
        let editedMarkdown = "# Initial\n\nTyped before switching lenses.\n"
        let editedJSON = Data(
            #"{"type":"doc","content":[{"type":"heading","attrs":{"level":1},"content":[{"type":"text","text":"Initial"}]},{"type":"paragraph","content":[{"type":"text","text":"Typed before switching lenses."}]}]}"#.utf8
        )
        var snapshotRequests = 0
        var editStarts = 0
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "appstore-early-document-edit",
            title: "Initial",
            markdown: initialMarkdown,
            theme: .light,
            noteRelativePath: "notes/appstore-early-document-edit.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            onEditStarted: {
                editStarts += 1
            },
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.installEditorDispatch { _ in }
        coordinator.controller.installMarkdownSnapshotProvider {
            snapshotRequests += 1
            return editedMarkdown
        }
        coordinator.controller.handleBridgeMessage(.editorReady)

        // The user can type after WebKit has ended its local load transaction
        // but before the coalesced load-settled message reaches Swift.
        coordinator.controller.handleBridgeMessage(
            .contentDidChange(json: editedJSON),
            epoch: 1
        )

        let flushed = await coordinator.flushPendingMarkdown()

        #expect(flushed)
        #expect(editStarts == 1)
        #expect(snapshotRequests == 1)
        #expect(savedMarkdown == [editedMarkdown])
    }

    @Test("concurrent Document flushes preserve edit order and newest dirty state")
    func concurrentDocumentFlushesPreserveNewestEdit() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let gate = MarkdownDocumentWriteGate()
        let initialMarkdown = "# Initial\n"
        let firstMarkdown = "# Initial\n\nFirst edit.\n"
        let secondMarkdown = "# Initial\n\nSecond edit wins.\n"
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "appstore-document-write-order",
            title: "Write Order",
            markdown: initialMarkdown,
            theme: .light,
            noteRelativePath: "notes/write-order.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { markdown in
                savedMarkdown.append(markdown)
                if markdown == firstMarkdown {
                    await gate.markStarted()
                    await gate.waitUntilReleased()
                }
                return true
            }
        )

        coordinator.controller.onMarkdownChanged(firstMarkdown, nil)
        let firstFlush = Task { @MainActor in
            await coordinator.flushPendingMarkdown()
        }
        await gate.waitUntilStarted()

        coordinator.controller.onMarkdownChanged(secondMarkdown, nil)
        let joinedFlush = Task { @MainActor in
            await coordinator.flushPendingMarkdown()
        }
        await gate.release()

        #expect(await firstFlush.value)
        #expect(await joinedFlush.value)
        #expect(savedMarkdown == [firstMarkdown, secondMarkdown])
        #expect(coordinator.controller.toolbarModel.isDirty == false)
    }

    @Test("Document Markdown edits stay dirty until the Markdown source is flushed")
    func documentMarkdownEditsStayDirtyUntilMarkdownSourceFlushes() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let initialMarkdown = "# Initial\n\nText that will be deleted.\n"
        let deletedMarkdown = "# Initial\n\nText that will be .\n"
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "appstore-document-backspace-dirty",
            title: "Backspace Dirty",
            markdown: initialMarkdown,
            theme: .light,
            noteRelativePath: "notes/appstore-document-backspace-dirty.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )

        coordinator.controller.onMarkdownChanged(deletedMarkdown, nil)

        #expect(coordinator.controller.toolbarModel.isDirty)

        coordinator.configure(
            pageId: "appstore-document-backspace-dirty",
            title: "Backspace Dirty",
            markdown: initialMarkdown,
            theme: .light,
            noteRelativePath: "notes/appstore-document-backspace-dirty.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )

        #expect(await coordinator.flushPendingMarkdown())
        #expect(savedMarkdown == [deletedMarkdown])
        #expect(coordinator.controller.toolbarModel.isDirty == false)
    }
}
