import Foundation
import SwiftUI
import WebKit

@MainActor
final class MarkEditCoreEditorLiveTextRegistry {
    static let shared = MarkEditCoreEditorLiveTextRegistry()

    struct Registration: Equatable {
        let key: UUID
        let token: UUID
    }

    private struct Entry {
        let token: UUID
        let fetch: @MainActor () async -> String?
    }

    private var entries: [UUID: Entry] = [:]

    private init() {}

    func register(
        key: UUID,
        fetch: @escaping @MainActor () async -> String?
    ) -> Registration {
        let token = UUID()
        entries[key] = Entry(token: token, fetch: fetch)
        return Registration(key: key, token: token)
    }

    func unregister(_ registration: Registration) {
        guard entries[registration.key]?.token == registration.token else { return }
        entries.removeValue(forKey: registration.key)
    }

    func replaceFetch(
        for registration: Registration,
        fetch: @escaping @MainActor () async -> String?
    ) {
        guard entries[registration.key]?.token == registration.token else { return }
        entries[registration.key] = Entry(token: registration.token, fetch: fetch)
    }

    func fetchText(for key: UUID) async -> String? {
        guard let entry = entries[key] else { return nil }
        if let value = await entry.fetch() {
            return value
        }
        guard let retryEntry = entries[key], retryEntry.token == entry.token else { return nil }
        return await retryEntry.fetch()
    }
}

@MainActor
private final class MarkEditCoreEditorLiveTextQueryPromise {
    private enum State {
        case pending
        case resolved(String?)
    }

    private var state: State = .pending
    private var waiters: [CheckedContinuation<String?, Never>] = []

    func resume(returning value: String?) {
        guard case .pending = state else { return }
        state = .resolved(value)
        let currentWaiters = waiters
        waiters.removeAll(keepingCapacity: false)
        for waiter in currentWaiters {
            waiter.resume(returning: value)
        }
    }

    func value() async -> String? {
        switch state {
        case .resolved(let value):
            return value
        case .pending:
            return await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }
}

@MainActor
private final class MarkEditEpdocCheckpointQueryPromise {
    private enum State {
        case pending
        case resolved(MarkEditEpdocCheckpoint?)
    }

    private var state: State = .pending
    private var waiters: [CheckedContinuation<MarkEditEpdocCheckpoint?, Never>] = []

    func resume(returning value: MarkEditEpdocCheckpoint?) {
        guard case .pending = state else { return }
        state = .resolved(value)
        let currentWaiters = waiters
        waiters.removeAll(keepingCapacity: false)
        for waiter in currentWaiters {
            waiter.resume(returning: value)
        }
    }

    func value() async -> MarkEditEpdocCheckpoint? {
        switch state {
        case .resolved(let value):
            return value
        case .pending:
            return await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }
}

@MainActor
final class MarkEditCoreEditorCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKScriptMessageHandlerWithReply {
    var text: Binding<String>
    var cursorLine: Binding<Int>
    var cursorColumn: Binding<Int>
    var totalLines: Binding<Int>
    var onContentDirty: (@MainActor () -> Void)?
    weak var webView: WKWebView?

    private var hasLoadedEditor = false
    private var pendingState: MarkEditCoreEditorState?
    private var pendingSelectionRequest: CoreEditorSelectionRequest?
    private var loadingState: MarkEditCoreEditorState?
    private var lastAppliedState: MarkEditCoreEditorState?
    private var inFlightResetState: MarkEditCoreEditorState?
    private var lastSelectionRequestID: UUID?
    private var isApplyingFromSwift = false
    private var hasPendingEditorTextSnapshot = false
    private var didReportPendingContentDirty = false
    private var isDetached = false
    private var loadGeneration = 0
    private var bootstrapResetGeneration: Int?
    private var terminalLoadFailureGeneration: Int?
    private var readOnlyApplicationGeneration = 0
    private var lineWrappingApplicationGeneration = 0
    private var resetApplicationGeneration: UInt64 = 0
    private var liveTextRegistration: MarkEditCoreEditorLiveTextRegistry.Registration?
    private weak var epdocController: EpdocEditorChromeController?
    private var epdocLoadEpoch: Int?
    private var epdocDeltaMirror: MarkEditEpdocDeltaMirror?
    private var epdocMutationGeneration: UInt64 = 0
    private var contentWidthMode: NoteWidthMode = .wide

    init(
        text: Binding<String>,
        cursorLine: Binding<Int>,
        cursorColumn: Binding<Int>,
        totalLines: Binding<Int>,
        onContentDirty: (@MainActor () -> Void)? = nil
    ) {
        self.text = text
        self.cursorLine = cursorLine
        self.cursorColumn = cursorColumn
        self.totalLines = totalLines
        self.onContentDirty = onContentDirty
    }

    func attachEpdocController(_ controller: EpdocEditorChromeController?) {
        guard epdocController !== controller else { return }
        epdocController?.detachEditorDispatch()
        epdocController?.detachMarkdownSnapshotProvider()
        epdocController = controller
        epdocLoadEpoch = controller?.currentLoadEpoch
        guard let controller else { return }
        if epdocDeltaMirror == nil {
            epdocDeltaMirror = MarkEditEpdocDeltaMirror(
                text: controller.latestMarkdownSnapshot ?? text.wrappedValue
            )
        }
        controller.installEditorDispatch { [weak self] command in
            self?.dispatchEpdocCommand(command)
        }
        controller.installMarkdownSnapshotProvider { [weak self] in
            guard let self, let webView = self.webView else { return nil }
            return await self.fetchCurrentEditorText(from: webView)
        }
    }

    func updateContentWidth(_ mode: NoteWidthMode, in webView: WKWebView) {
        let normalized = mode.normalized
        let changed = normalized != contentWidthMode
        contentWidthMode = normalized
        guard hasLoadedEditor, changed else { return }
        applyContentWidth(normalized, in: webView)
    }

    func loadEditor(into webView: WKWebView, initialState: MarkEditCoreEditorState) {
        isDetached = false
        loadGeneration += 1
        readOnlyApplicationGeneration += 1
        hasLoadedEditor = false
        pendingState = nil
        pendingSelectionRequest = nil
        loadingState = initialState
        lastAppliedState = nil
        inFlightResetState = nil
        lastSelectionRequestID = nil
        isApplyingFromSwift = false
        hasPendingEditorTextSnapshot = false
        didReportPendingContentDirty = false
        bootstrapResetGeneration = nil
        terminalLoadFailureGeneration = nil
        resetApplicationGeneration &+= 1
        epdocMutationGeneration = 0
        if initialState.mode == .epdocMarkdown {
            let mirror = epdocDeltaMirror ?? MarkEditEpdocDeltaMirror(text: initialState.text)
            mirror.resetDocument(text: initialState.text)
            epdocDeltaMirror = mirror
        }
        let html = MarkEditCoreEditorDocument.html(for: initialState)
        webView.loadHTMLString(html, baseURL: MarkEditCoreEditorBridge.baseURL)
    }

    func detach(from webView: WKWebView) {
        if let liveTextRegistration {
            let finalTextPromise: MarkEditCoreEditorLiveTextQueryPromise
            if hasLoadedEditor, !webView.isLoading {
                finalTextPromise = Self.requestCurrentEditorText(from: webView)
            } else {
                finalTextPromise = MarkEditCoreEditorLiveTextQueryPromise()
                finalTextPromise.resume(returning: text.wrappedValue)
            }
            MarkEditCoreEditorLiveTextRegistry.shared.replaceFetch(for: liveTextRegistration) {
                await finalTextPromise.value()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                MarkEditCoreEditorLiveTextRegistry.shared.unregister(liveTextRegistration)
            }
            self.liveTextRegistration = nil
        }
        isDetached = true
        loadGeneration += 1
        readOnlyApplicationGeneration += 1
        hasLoadedEditor = false
        pendingState = nil
        pendingSelectionRequest = nil
        loadingState = nil
        inFlightResetState = nil
        isApplyingFromSwift = false
        hasPendingEditorTextSnapshot = false
        didReportPendingContentDirty = false
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: MarkEditCoreEditorBridge.messageHandlerName
        )
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: MarkEditCoreEditorBridge.nativeMessageHandlerName,
            contentWorld: .page
        )
        webView.stopLoading()
        epdocController?.detachEditorDispatch()
        epdocController?.detachMarkdownSnapshotProvider()
        epdocController = nil
        epdocLoadEpoch = nil
        epdocDeltaMirror = nil
        epdocMutationGeneration = 0
        resetApplicationGeneration &+= 1
        self.webView = nil
        lastAppliedState = nil
        lastSelectionRequestID = nil
        bootstrapResetGeneration = nil
        terminalLoadFailureGeneration = nil
    }

    func registerLiveTextQuery(key: UUID?, webView: WKWebView) {
        if liveTextRegistration?.key == key { return }
        if let liveTextRegistration {
            MarkEditCoreEditorLiveTextRegistry.shared.unregister(liveTextRegistration)
            self.liveTextRegistration = nil
        }
        guard let key else { return }
        liveTextRegistration = MarkEditCoreEditorLiveTextRegistry.shared.register(key: key) { [weak self, weak webView] in
            guard let self, let webView else { return nil }
            return await self.fetchCurrentEditorText(from: webView)
        }
    }

    private func fetchCurrentEditorText(from webView: WKWebView) async -> String? {
        guard !isDetached, hasLoadedEditor, !webView.isLoading else { return nil }
        let generation = loadGeneration
        if let epdocController {
            let checkpoint = await Self.requestEpdocCheckpoint(from: webView).value()
            guard !isDetached,
                  generation == loadGeneration,
                  let checkpoint else { return nil }
            let mirror = epdocDeltaMirror ?? MarkEditEpdocDeltaMirror(text: checkpoint.text)
            mirror.reconcile(
                text: checkpoint.text,
                documentInstance: checkpoint.documentInstance,
                revision: checkpoint.revision
            )
            epdocDeltaMirror = mirror
            hasPendingEditorTextSnapshot = false
            didReportPendingContentDirty = false
            if let applied = lastAppliedState ?? inFlightResetState {
                lastAppliedState = applied.replacingText(checkpoint.text)
            }
            if let pendingState {
                self.pendingState = pendingState.replacingText(checkpoint.text)
            }
            epdocController.reconcileCodeMirrorMarkdownCheckpoint(checkpoint.text)
            return checkpoint.text
        }
        let promise = Self.requestCurrentEditorText(from: webView)
        let value = await promise.value()
        guard !isDetached, generation == loadGeneration else { return nil }
        return value
    }

    private static func requestEpdocCheckpoint(
        from webView: WKWebView
    ) -> MarkEditEpdocCheckpointQueryPromise {
        let promise = MarkEditEpdocCheckpointQueryPromise()
        webView.evaluateJavaScript("window.__epistemosMarkEditCheckpoint?.()") { value, error in
            guard error == nil,
                  let payload = value as? [String: Any] else {
                promise.resume(returning: nil)
                return
            }
            promise.resume(returning: MarkEditEpdocCheckpoint(payload: payload))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            promise.resume(returning: nil)
        }
        return promise
    }

    private static func requestCurrentEditorText(
        from webView: WKWebView
    ) -> MarkEditCoreEditorLiveTextQueryPromise {
        let promise = MarkEditCoreEditorLiveTextQueryPromise()
        webView.evaluateJavaScript("window.webModules?.core?.getEditorText?.()") { value, error in
            guard error == nil, let value = value as? String else {
                promise.resume(returning: nil)
                return
            }
            promise.resume(returning: value)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            promise.resume(returning: nil)
        }
        return promise
    }

    private func dispatchEpdocCommand(_ command: EpdocEditorCommand) {
        guard let webView, !isDetached else { return }
        switch command {
        case .setMarkdown(let markdown):
            applyEpdocMarkdown(markdown, epoch: epdocController?.currentLoadEpoch, in: webView)
        case .setMarkdownForLoad(let markdown, let epoch):
            epdocLoadEpoch = epoch
            applyEpdocMarkdown(markdown, epoch: epoch, in: webView)
        case .replaceDocumentTitle(_, let epoch):
            epdocLoadEpoch = epoch
            guard let markdown = epdocController?.latestMarkdownSnapshot else { return }
            applyEpdocMarkdown(markdown, epoch: epoch, in: webView)
        case .setContent, .setContentForLoad:
            guard let markdown = epdocController?.latestMarkdownSnapshot else { return }
            applyEpdocMarkdown(markdown, epoch: epdocController?.currentLoadEpoch, in: webView)
        case .flushDocumentSnapshot:
            flushEpdocMarkdownSnapshot(from: webView)
        case .focusStart:
            evaluateEpdocScript(Self.focusStartScript, in: webView)
        case .focusEnd:
            evaluateEpdocScript(Self.focusEndScript, in: webView)
        case .dismissSlashMenu, .dismissBubbleMenu:
            evaluateEpdocScript("window.editor?.focus();", in: webView)
        case .insertSlashChoice(let blockType):
            dispatchEpdocSlashChoice(blockType, in: webView)
        case .runCommand(let name, let argsJSON):
            dispatchEpdocRunCommand(name, argsJSON: argsJSON, in: webView)
        case .setContentWidth(let mode):
            updateContentWidth(mode, in: webView)
        case .setFindQuery(let query, let caseSensitive):
            updateEpdocSearch(query: query, replacement: nil, caseSensitive: caseSensitive, in: webView)
        case .findNext(let query, let caseSensitive):
            updateEpdocSearch(query: query, replacement: nil, caseSensitive: caseSensitive, in: webView)
            callEpdocJavaScript(
                "return window.webModules?.search?.findNext?.({ search });",
                arguments: ["search": query],
                in: webView
            )
        case .findPrevious(let query, let caseSensitive):
            updateEpdocSearch(query: query, replacement: nil, caseSensitive: caseSensitive, in: webView)
            callEpdocJavaScript(
                "return window.webModules?.search?.findPrevious?.({ search });",
                arguments: ["search": query],
                in: webView
            )
        case .replaceCurrent(let query, let replacement, let caseSensitive):
            updateEpdocSearch(
                query: query,
                replacement: replacement,
                caseSensitive: caseSensitive,
                in: webView
            )
            evaluateEpdocScript("window.webModules?.search?.replaceNext?.();", in: webView)
        case .replaceAll(let query, let replacement, let caseSensitive):
            updateEpdocSearch(
                query: query,
                replacement: replacement,
                caseSensitive: caseSensitive,
                in: webView
            )
            evaluateEpdocScript("window.webModules?.search?.replaceAll?.();", in: webView)
        case .clearFindHighlights:
            evaluateEpdocScript("window.webModules?.search?.setState?.({ enabled: false });", in: webView)
        case .applySuggestion,
             .acceptSuggestion,
             .rejectSuggestion:
            break
        }
    }

    private func applyEpdocMarkdown(_ markdown: String, epoch: Int?, in webView: WKWebView) {
        guard hasLoadedEditor, !webView.isLoading,
              let currentState = lastAppliedState ?? pendingState ?? loadingState else {
            return
        }
        let mirror = epdocDeltaMirror ?? MarkEditEpdocDeltaMirror(text: markdown)
        epdocDeltaMirror = mirror
        if hasPendingEditorTextSnapshot {
            guard let liveMarkdown = mirror.checkpointText() else {
                flushEpdocMarkdownSnapshot(from: webView)
                return
            }
            settleEpdocMarkdownApplication(
                liveMarkdown,
                epoch: epoch,
                didApply: true
            )
            return
        }
        let nextState = currentState.replacingText(markdown)
        let mirrorTextBeforeReset = mirror.checkpointText()
        let mutationGenerationBeforeReset = epdocMutationGeneration
        mirror.replaceTextPreservingClock(markdown)
        let settle: @MainActor (Bool) -> Void = { [weak self] didApply in
            guard let self else { return }
            guard didApply else {
                if self.epdocMutationGeneration == mutationGenerationBeforeReset {
                    if let mirrorTextBeforeReset {
                        mirror.replaceTextPreservingClock(mirrorTextBeforeReset)
                    } else {
                        mirror.invalidate()
                    }
                }
                return
            }
            let settledMarkdown = self.epdocMutationGeneration == mutationGenerationBeforeReset
                ? markdown
                : mirror.checkpointText() ?? markdown
            self.settleEpdocMarkdownApplication(
                settledMarkdown,
                epoch: epoch,
                didApply: true
            )
        }
        guard currentState.text != markdown else {
            settle(true)
            return
        }
        resetEditor(
            to: nextState,
            in: webView,
            documentChanged: true,
            completion: settle
        )
    }

    private func settleEpdocMarkdownApplication(
        _ markdown: String,
        epoch: Int?,
        didApply: Bool
    ) {
        guard didApply, let controller = epdocController else { return }
        controller.handleBridgeMessage(
            .markdownDidChange(markdown: markdown, writeback: nil),
            epoch: epoch
        )
        controller.handleBridgeMessage(.loadSettled, epoch: epoch)
    }

    private func flushEpdocMarkdownSnapshot(from webView: WKWebView) {
        let epoch = epdocLoadEpoch ?? epdocController?.currentLoadEpoch
        Task { @MainActor [weak self, weak webView] in
            guard let self, let webView,
                  let markdown = await self.fetchCurrentEditorText(from: webView),
                  let controller = self.epdocController else { return }
            controller.handleBridgeMessage(
                .markdownDidChange(markdown: markdown, writeback: nil),
                epoch: epoch
            )
        }
    }

    private func dispatchEpdocSlashChoice(_ blockType: String, in webView: WKWebView) {
        let script: String?
        switch blockType {
        case "blockquote":
            script = "window.webModules?.format?.toggleBlockquote?.();"
        case "bullet-list":
            script = "window.webModules?.format?.toggleBullet?.();"
        case "numbered-list":
            script = "window.webModules?.format?.toggleNumbering?.();"
        case "task-list":
            script = "window.webModules?.format?.toggleTodo?.();"
        case "math-display":
            script = "window.webModules?.format?.insertMathBlock?.();"
        case "table-3x3":
            script = "window.webModules?.format?.insertTable?.({ columnName: 'Column', itemName: 'Item' });"
        case "divider":
            script = "window.webModules?.format?.insertHorizontalRule?.();"
        default:
            script = nil
        }
        guard let script else { return }
        evaluateEpdocScript(script, in: webView)
    }

    private func dispatchEpdocRunCommand(_ name: String, argsJSON: Data, in webView: WKWebView) {
        let script: String?
        switch name {
        case "toggleBold":
            script = "window.webModules?.format?.toggleBold?.();"
        case "toggleItalic":
            script = "window.webModules?.format?.toggleItalic?.();"
        case "toggleStrike":
            script = "window.webModules?.format?.toggleStrikethrough?.();"
        case "toggleCode":
            script = "window.webModules?.format?.toggleInlineCode?.();"
        case "toggleCodeBlock":
            script = "window.webModules?.format?.insertCodeBlock?.();"
        case "toggleHighlight":
            script = Self.toggleHighlightScript
        case "setParagraph":
            script = "window.webModules?.format?.toggleHeading?.({ level: 0 });"
        case "setHeadingLevel":
            guard let level = Self.firstCommandArgument(in: argsJSON)?["level"] as? Int,
                  (1...6).contains(level) else { return }
            callEpdocJavaScript(
                "window.webModules?.format?.toggleHeading?.({ level });",
                arguments: ["level": level],
                in: webView
            )
            return
        case "setLink":
            guard let href = Self.firstCommandArgument(in: argsJSON)?["href"] as? String else { return }
            callEpdocJavaScript(
                "window.webModules?.format?.insertHyperLink?.({ title: '', url: href, prefix: '' });",
                arguments: ["href": href],
                in: webView
            )
            return
        case "insertEpdocImage":
            guard let arguments = Self.firstCommandArgument(in: argsJSON),
                  let src = arguments["src"] as? String else { return }
            let alt = arguments["alt"] as? String ?? ""
            insertEpdocMarkdown("![\(alt)](\(src))", in: webView)
            return
        default:
            script = nil
        }
        guard let script else { return }
        evaluateEpdocScript(script, in: webView)
    }

    private func insertEpdocMarkdown(_ markdown: String, in webView: WKWebView) {
        callEpdocJavaScript(
            """
            if (!window.editor) { return false; }
            const state = window.editor.state;
            window.editor.dispatch(state.replaceSelection(markdown));
            window.editor.focus();
            return true;
            """,
            arguments: ["markdown": markdown],
            in: webView
        )
    }

    private func applyContentWidth(_ mode: NoteWidthMode, in webView: WKWebView) {
        let widthRule: String
        let maxWidthRule: String
        switch mode.normalized {
        case .wide:
            widthRule = "calc(100% - 120px)"
            maxWidthRule = "none"
        case .normal, .custom:
            maxWidthRule = mode.cssMaxWidthValue
            widthRule = "min(calc(100% - 120px), \(maxWidthRule))"
        }
        callEpdocJavaScript(
            """
            let style = document.getElementById('epistemos-epdoc-width');
            if (!style) {
              style = document.createElement('style');
              style.id = 'epistemos-epdoc-width';
              document.head.appendChild(style);
            }
            style.textContent = `.cm-content { width: ${widthRule}; max-width: ${maxWidth}; margin-inline: auto; }`;
            window.editor?.requestMeasure?.();
            """,
            arguments: [
                "widthRule": widthRule,
                "maxWidth": maxWidthRule,
            ],
            in: webView
        )
    }

    private func updateEpdocSearch(
        query: String,
        replacement: String?,
        caseSensitive: Bool,
        in webView: WKWebView
    ) {
        callEpdocJavaScript(
            """
            window.webModules?.search?.updateQuery?.({
              options: {
                search: query,
                caseSensitive,
                diacriticInsensitive: false,
                wholeWord: false,
                literal: true,
                regexp: false,
                refocus: false,
                replace: replacement ?? '',
              },
            });
            """,
            arguments: [
                "query": query,
                "replacement": replacement ?? "",
                "caseSensitive": caseSensitive,
            ],
            in: webView
        )
    }

    private func evaluateEpdocScript(_ script: String, in webView: WKWebView) {
        guard hasLoadedEditor, !webView.isLoading else { return }
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func callEpdocJavaScript(
        _ script: String,
        arguments: [String: Any],
        in webView: WKWebView
    ) {
        guard hasLoadedEditor, !webView.isLoading else { return }
        webView.callAsyncJavaScript(
            script,
            arguments: arguments,
            in: nil,
            in: .page
        ) { _ in }
    }

    private static func firstCommandArgument(in data: Data) -> [String: Any]? {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        return array.first
    }

    func update(
        webView: WKWebView,
        state: MarkEditCoreEditorState,
        selectionRequest: CoreEditorSelectionRequest?
    ) {
        guard !isDetached else { return }
        if hasLoadedEditor, !webView.isLoading {
            apply(state: state, to: webView)
            apply(selectionRequest: selectionRequest, to: webView)
        } else {
            pendingState = state
            pendingSelectionRequest = selectionRequest
        }
    }

    private func apply(state incomingState: MarkEditCoreEditorState, to webView: WKWebView) {
        var state = incomingState
        guard !isDetached, hasLoadedEditor, !webView.isLoading else {
            pendingState = state
            return
        }
        if epdocController != nil, hasPendingEditorTextSnapshot {
            guard let mirroredText = epdocDeltaMirror?.checkpointText() else {
                pendingState = state
                return
            }
            state = state.replacingText(mirroredText)
            if let applied = lastAppliedState {
                lastAppliedState = applied.replacingText(mirroredText)
            }
        }
        guard !isApplyingFromSwift else {
            pendingState = state
            return
        }
        if let lastAppliedState, state.requiresReload(comparedTo: lastAppliedState) {
            guard !(hasPendingEditorTextSnapshot && state.text == lastAppliedState.text) else {
                pendingState = state
                return
            }
            loadEditor(into: webView, initialState: state)
            return
        }

        // #7: apply a theme flip IN-PLACE (no reload) so keystrokes typed while
        // toggling appearance aren't lost. `requiresReload` no longer treats
        // themeName as a reload trigger; instead push the new palette through
        // the live CoreEditor config bridge and advance lastAppliedState's
        // themeName so the equality guard below doesn't also fire a redundant
        // resetEditor for a theme-only delta.
        if let last = lastAppliedState,
           state.themeName != last.themeName || state.themePalette != last.themePalette {
            applyTheme(themeName: state.themeName, palette: state.themePalette, to: webView)
            lastAppliedState = last.replacingTheme(
                name: state.themeName,
                palette: state.themePalette
            )
        }

        if let last = lastAppliedState,
           state.isEditable != last.isEditable {
            applyReadOnlyMode(
                isReadOnly: !state.isEditable,
                desiredState: state,
                to: webView
            )
            lastAppliedState = last.replacingEditable(state.isEditable)
        }

        if let last = lastAppliedState,
           state.wrapLines != last.wrapLines {
            applyLineWrapping(
                enabled: state.wrapLines,
                desiredState: state,
                to: webView
            )
            lastAppliedState = last.replacingLineWrapping(state.wrapLines)
        }

        guard state != lastAppliedState else { return }
        resetEditor(to: state, in: webView, documentChanged: false)
    }

    private func applyTheme(
        themeName: String,
        palette: MarkEditCoreEditorThemePalette,
        to webView: WKWebView
    ) {
        guard !isDetached, hasLoadedEditor, !webView.isLoading else { return }
        guard let script = MarkEditCoreEditorThemeOverlay.script(
            themeName: themeName,
            palette: palette
        ) else { return }
        webView.evaluateJavaScript(script)
    }

    private func applyReadOnlyMode(
        isReadOnly: Bool,
        desiredState: MarkEditCoreEditorState,
        to webView: WKWebView
    ) {
        guard !isDetached, hasLoadedEditor, !webView.isLoading else { return }
        readOnlyApplicationGeneration += 1
        let applicationGeneration = readOnlyApplicationGeneration
        let currentLoadGeneration = loadGeneration
        let readOnlyLiteral = isReadOnly ? "true" : "false"
        let script = """
        (() => {
          if (!window.webModules?.config?.setReadOnlyMode || !window.editor) {
            return false;
          }
          window.webModules.config.setReadOnlyMode(\(readOnlyLiteral));
          return window.editor.state.readOnly === \(readOnlyLiteral);
        })();
        """
        webView.evaluateJavaScript(script) { [weak self, weak webView] result, error in
            guard let self,
                  let webView,
                  !self.isDetached,
                  currentLoadGeneration == self.loadGeneration,
                  applicationGeneration == self.readOnlyApplicationGeneration else { return }
            guard error == nil, result as? Bool == true else {
                let currentState = self.lastAppliedState ?? desiredState
                self.lastAppliedState = currentState.replacingEditable(!desiredState.isEditable)
                let retryState = (self.pendingState ?? currentState)
                    .replacingEditable(desiredState.isEditable)
                self.pendingState = retryState
                guard !self.hasPendingEditorTextSnapshot else { return }
                self.pendingState = nil
                self.loadEditor(into: webView, initialState: retryState)
                return
            }
        }
    }

    private func applyLineWrapping(
        enabled: Bool,
        desiredState: MarkEditCoreEditorState,
        to webView: WKWebView
    ) {
        guard !isDetached, hasLoadedEditor, !webView.isLoading else {
            pendingState = desiredState
            return
        }
        lineWrappingApplicationGeneration += 1
        let applicationGeneration = lineWrappingApplicationGeneration
        let currentLoadGeneration = loadGeneration
        let script = """
        if (!window.webModules?.config?.setLineWrapping || !window.config) {
          return false;
        }
        window.webModules.config.setLineWrapping({ enabled: enabled });
        return window.config.lineWrapping === enabled;
        """
        webView.callAsyncJavaScript(
            script,
            arguments: ["enabled": enabled],
            in: nil,
            in: .page
        ) { [weak self, weak webView] result in
            guard let self,
                  let webView,
                  !self.isDetached,
                  currentLoadGeneration == self.loadGeneration,
                  applicationGeneration == self.lineWrappingApplicationGeneration else { return }

            let didApply: Bool
            switch result {
            case .success(let value):
                didApply = value as? Bool == true
            case .failure:
                didApply = false
            }
            guard !didApply else { return }

            let currentState = self.lastAppliedState ?? desiredState
            self.lastAppliedState = currentState.replacingLineWrapping(!desiredState.wrapLines)
            let retryState = (self.pendingState ?? currentState)
                .replacingLineWrapping(desiredState.wrapLines)
            self.pendingState = retryState
            guard !self.hasPendingEditorTextSnapshot else { return }
            self.pendingState = nil
            self.loadEditor(into: webView, initialState: retryState)
        }
    }

    private func resetEditor(
        to state: MarkEditCoreEditorState,
        in webView: WKWebView,
        documentChanged: Bool,
        completion: (@MainActor (Bool) -> Void)? = nil
    ) {
        guard !isDetached, hasLoadedEditor, !webView.isLoading else {
            pendingState = state
            completion?(false)
            return
        }
        guard let json = state.resetMessageJSON(documentChanged: documentChanged) else {
            completion?(false)
            return
        }
        isApplyingFromSwift = true
        resetApplicationGeneration &+= 1
        let resetGeneration = resetApplicationGeneration
        inFlightResetState = state
        let generation = loadGeneration
        let mutationGeneration = epdocMutationGeneration
        let previousState = lastAppliedState
        let expectedLength = state.text.utf16.count
        let script = """
        if (!window.webModules?.core?.resetEditor) {
          return { ok: false, error: "CoreEditor resetEditor bridge is missing" };
        }
        if (!window.webModules?.core?.getEditorText) {
          return { ok: false, error: "CoreEditor getEditorText bridge is missing" };
        }
        window.__epistemosApplyingMarkEditState = true;
        try {
          const resetResult = await window.webModules.core.resetEditor(\(json));
          await new Promise(resolve => {
            let settled = false;
            const finish = () => {
              if (settled) { return; }
              settled = true;
              resolve();
            };
            requestAnimationFrame(() => requestAnimationFrame(finish));
            setTimeout(finish, 100);
          });
          const editorText = window.webModules.core.getEditorText();
          const renderedText = document.querySelector(".cm-content")?.textContent ?? "";
          const lineCount = window.editor?.state?.doc?.lines ?? 0;
          if (\(expectedLength) > 0 && editorText.length === 0) {
            return {
              ok: false,
              error: "CoreEditor reset completed with empty editor text",
              resetResult,
              renderedLength: renderedText.length,
              lineCount,
            };
          }
          // NOTE (audit 2026-07-01): do NOT fail on renderedText.length === 0.
          // CodeMirror 6 viewport-virtualizes — it renders ZERO line DOM until the
          // WKWebView has a layout size (offscreen / zero-height / collapsed pane /
          // fresh mount / large doc with deferred measure). editorText being non-empty
          // is the real success gate (checked above); the old renderedText===0 branch
          // fired a FALSE failure -> showLoadFailure() wiped #editor with no recovery
          // path = permanent blank/broken code editor. renderedLength stays below for
          // diagnostics only; CM self-heals on the next resize/requestMeasure.
          return {
            ok: resetResult === true,
            resetResult,
            editorLength: editorText.length,
            renderedLength: renderedText.length,
            lineCount,
          };
        } catch (error) {
          return {
            ok: false,
            error: String(error?.stack || error?.message || error),
          };
        } finally {
          window.__epistemosApplyingMarkEditState = false;
        }
        """
        webView.callAsyncJavaScript(script, in: nil, in: .page) { [weak self, weak webView] result in
            guard let self,
                  generation == self.loadGeneration,
                  resetGeneration == self.resetApplicationGeneration,
                  !self.isDetached else { return }
            self.isApplyingFromSwift = false
            self.inFlightResetState = nil
            if webView?.isLoading == true {
                self.lastAppliedState = previousState
                self.pendingState = state
                return
            }
            let scriptResult: Any?
            let scriptError: Error?
            switch result {
            case .success(let value):
                scriptResult = value
                scriptError = nil
            case .failure(let error):
                scriptResult = nil
                scriptError = error
            }
            if let report = scriptResult as? [String: Any],
               report["ok"] as? Bool == true {
                if let webView {
                    self.applyTheme(themeName: state.themeName, palette: state.themePalette, to: webView)
                }
                if state.mode == .epdocMarkdown,
                   mutationGeneration != self.epdocMutationGeneration {
                    if let mirroredText = self.epdocDeltaMirror?.checkpointText() {
                        self.lastAppliedState = state.replacingText(mirroredText)
                    } else {
                        self.lastAppliedState = previousState
                        self.pendingState = self.pendingState ?? state
                    }
                } else {
                    self.lastAppliedState = state
                }
                if let webView {
                    self.flushPendingState(in: webView)
                }
                completion?(true)
            } else {
                self.lastAppliedState = previousState
                self.pendingState = state
                if let webView {
                    self.showLoadFailure(
                        in: webView,
                        message: "MarkEdit CoreEditor reset failed: \(Self.resetFailureMessage(result: scriptResult, error: scriptError))"
                    )
                }
                completion?(false)
            }
        }
    }

    private func apply(selectionRequest: CoreEditorSelectionRequest?, to webView: WKWebView) {
        guard !isDetached, hasLoadedEditor, !webView.isLoading else {
            pendingSelectionRequest = selectionRequest
            return
        }
        guard let selectionRequest,
              selectionRequest.id != lastSelectionRequestID else { return }
        let from = max(0, selectionRequest.range.location)
        let to = from + max(0, selectionRequest.range.length)
        let generation = loadGeneration
        let script = """
        (() => {
          if (!window.MarkEdit?.editorAPI) { return false; }
          window.MarkEdit.editorAPI.setSelections([{ from: \(from), to: \(to) }]);
          window.webModules?.selection?.scrollToSelection?.();
          return true;
        })();
        """
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self,
                  generation == self.loadGeneration,
                  !self.isDetached else { return }
            if error == nil, result as? Bool == true {
                self.lastSelectionRequestID = selectionRequest.id
            } else {
                self.pendingSelectionRequest = selectionRequest
            }
        }
    }

    private func installSnapshotBridge(into webView: WKWebView) {
        guard !isDetached, hasLoadedEditor, !webView.isLoading else { return }
        webView.evaluateJavaScript(Self.snapshotBridgeScript)
    }

    private func flushPendingState(in webView: WKWebView) {
        guard !isDetached, !webView.isLoading else { return }
        if let pendingState {
            self.pendingState = nil
            apply(state: pendingState, to: webView)
        }
        if let pendingSelectionRequest {
            self.pendingSelectionRequest = nil
            apply(selectionRequest: pendingSelectionRequest, to: webView)
        }
    }

    private func waitForCoreEditorReady(
        in webView: WKWebView,
        generation: Int,
        attempt: Int = 0
    ) {
        guard !isDetached,
              generation == loadGeneration,
              !hasLoadedEditor else { return }

        guard !webView.isLoading else {
            retryCoreEditorReadyCheck(in: webView, generation: generation, attempt: attempt + 1)
            return
        }

        let script = """
        Boolean(
          window.webModules?.core?.resetEditor &&
          window.webModules?.core?.getEditorText &&
          window.MarkEdit?.editorAPI
        );
        """
        webView.evaluateJavaScript(script) { [weak self, weak webView] result, _ in
            guard let self,
                  let webView,
                  generation == self.loadGeneration,
                  !self.isDetached,
                  !webView.isLoading,
                  !self.hasLoadedEditor else { return }

            if (result as? Bool) == true {
                self.finishLoadingEditor(in: webView)
                return
            }

            self.retryCoreEditorReadyCheck(in: webView, generation: generation, attempt: attempt + 1)
        }
    }

    private func retryCoreEditorReadyCheck(
        in webView: WKWebView,
        generation: Int,
        attempt: Int
    ) {
        guard attempt < 160 else {
            showLoadFailure(
                in: webView,
                message: "MarkEdit CoreEditor failed to load. Check CoreEditor chunks, the chunk-loader scheme, and the MarkEdit native bridge.",
                force: true
            )
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak webView] in
            guard let self,
                  let webView,
                  generation == self.loadGeneration,
                  !self.isDetached,
                  !self.hasLoadedEditor else { return }
            self.waitForCoreEditorReady(in: webView, generation: generation, attempt: attempt)
        }
    }

    private func finishLoadingEditor(in webView: WKWebView) {
        guard !isDetached, !webView.isLoading else { return }
        hasLoadedEditor = true
        applyContentWidth(contentWidthMode, in: webView)
        installSnapshotBridge(into: webView)
        let state = pendingState ?? loadingState
        pendingState = nil
        loadingState = nil
        if let state {
            applyTheme(themeName: state.themeName, palette: state.themePalette, to: webView)
            if let epdocController {
                resetEditor(
                    to: state,
                    in: webView,
                    documentChanged: true
                ) { [weak self, weak epdocController] didApply in
                    guard didApply,
                          let self,
                          !self.isDetached,
                          self.epdocController === epdocController else { return }
                    epdocController?.handleBridgeMessage(.editorReady)
                }
            } else {
                resetEditor(to: state, in: webView, documentChanged: true)
            }
        } else {
            flushPendingState(in: webView)
        }
    }

    private func showLoadFailure(in webView: WKWebView, message: String, force: Bool = false) {
        guard !isDetached else { return }
        hasLoadedEditor = false
        isApplyingFromSwift = false
        if webView.isLoading {
            guard force else { return }
            terminalLoadFailureGeneration = loadGeneration
            webView.stopLoading()
            webView.loadHTMLString(
                Self.loadFailureDocument(message: message),
                baseURL: nil
            )
            return
        }
        guard !webView.isLoading else { return }
        let messageData = try? JSONEncoder().encode(message)
        let messageJSON = messageData.flatMap { String(data: $0, encoding: .utf8) } ?? "\"MarkEdit CoreEditor failed to load.\""
        let script = """
        (() => {
          const target = document.querySelector('#editor') || document.body;
          target.innerHTML = '';
          const message = document.createElement('pre');
          message.textContent = \(messageJSON);
          message.style.margin = '16px';
          message.style.whiteSpace = 'pre-wrap';
          message.style.font = '13px -apple-system, BlinkMacSystemFont, sans-serif';
          target.appendChild(message);
          return true;
        })();
        """
        webView.evaluateJavaScript(script)
    }

    private static func loadFailureDocument(message: String) -> String {
        let escaped = message
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8">
            <meta name="color-scheme" content="light dark">
            <style>
              :root { color-scheme: light dark; }
              body { margin: 16px; background: Canvas; color: CanvasText; }
              pre { margin: 0; white-space: pre-wrap; font: 13px -apple-system, BlinkMacSystemFont, sans-serif; }
            </style>
          </head>
          <body><pre>\(escaped)</pre></body>
        </html>
        """
    }

    private static func resetFailureMessage(result: Any?, error: Error?) -> String {
        if let error {
            return error.localizedDescription
        }
        if let report = result as? [String: Any],
           let message = report["error"] as? String,
           !message.isEmpty {
            return message
        }
        if let report = result as? [String: Any] {
            return "unexpected reset report \(report)"
        }
        return "unexpected reset result \(String(describing: result))"
    }

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        guard !isDetached else { return }
        guard terminalLoadFailureGeneration != loadGeneration else { return }
        waitForCoreEditorReady(in: webView, generation: loadGeneration)
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        guard !isDetached else { return }
        hasLoadedEditor = false
        isApplyingFromSwift = false
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        guard !isDetached else { return }
        hasLoadedEditor = false
        isApplyingFromSwift = false
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard !isDetached else { return }
        let recoveryState = pendingState ?? lastAppliedState ?? loadingState
        guard let recoveryState else {
            Log.notes.error(
                "MarkEdit code editor web content process terminated; no host editor state is available for safe recovery"
            )
            return
        }
        let hadPendingEditorTextSnapshot = hasPendingEditorTextSnapshot
        let recoveryText = epdocDeltaMirror?.checkpointText() ?? Self.preferredRecoveryText(
            hostText: text.wrappedValue,
            stateText: recoveryState.text
        )
        let recoveredState = recoveryState.replacingText(recoveryText)
        loadEditor(into: webView, initialState: recoveredState)
        if hadPendingEditorTextSnapshot {
            Log.notes.error(
                "MarkEdit code editor web content process terminated; reloading with the last host snapshot after an unsnapshotted edit signal"
            )
        } else {
            Log.notes.error(
                "MarkEdit code editor web content process terminated; reloading with the last host snapshot"
            )
        }
    }

    nonisolated static func preferredRecoveryText(hostText: String, stateText: String) -> String {
        stateText.isEmpty && !hostText.isEmpty ? hostText : stateText
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard !isDetached else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(Self.isAllowedNavigation(navigationAction) ? .allow : .cancel)
    }

    private static func isAllowedNavigation(_ navigationAction: WKNavigationAction) -> Bool {
        guard let url = navigationAction.request.url else {
            return navigationAction.navigationType == .other
        }
        guard let scheme = url.scheme?.lowercased() else { return false }

        switch scheme {
        case "about":
            return true
        case MarkEditCoreEditorBridge.chunkScheme:
            return url.host == "chunks"
        case "http", "https":
            guard let host = url.host?.lowercased() else { return false }
            let isLocalhost = host == "localhost" || host == "127.0.0.1" || host == "::1"
            // Allow only the editor's OWN programmatic load (.other), not user link
            // clicks — a clicked localhost link against a live local server could
            // otherwise navigate the editor webview and corrupt its text buffer
            // (bridge audit 2026-07-03, LOW).
            return isLocalhost && navigationAction.navigationType == .other
        default:
            return false
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard !isDetached,
              message.name == MarkEditCoreEditorBridge.messageHandlerName,
              message.frameInfo.isMainFrame,
              let payload = message.body as? [String: Any] else { return }

        if let lineCount = payload["lineCount"] as? Int {
            totalLines.wrappedValue = max(1, lineCount)
        }
        if let line = payload["line"] as? Int {
            cursorLine.wrappedValue = max(1, line)
        }
        if let column = payload["column"] as? Int {
            cursorColumn.wrappedValue = max(1, column)
        }

        let applying = payload["applying"] as? Bool ?? false
        if payload["kind"] as? String == "transaction",
           epdocController != nil {
            hasPendingEditorTextSnapshot = true
            let mirror = epdocDeltaMirror ?? MarkEditEpdocDeltaMirror(text: text.wrappedValue)
            epdocDeltaMirror = mirror
            let result: MarkEditEpdocDeltaApplyResult
            if let transaction = MarkEditEpdocTransaction(payload: payload) {
                result = mirror.apply(transaction)
            } else {
                mirror.invalidate()
                result = .requiresCheckpoint
            }
            switch result {
            case .accepted, .requiresCheckpoint:
                epdocMutationGeneration &+= 1
                didReportPendingContentDirty = true
                onContentDirty?()
            case .ignoredDuplicate, .ignoredStaleInstance:
                break
            }
            return
        }
        if payload["contentDirty"] as? Bool == true {
            hasPendingEditorTextSnapshot = true
            let isEpdocDirtyEdge = epdocController != nil && payload["kind"] as? String == "dirty"
            if !isApplyingFromSwift,
               !applying,
               (isEpdocDirtyEdge || !didReportPendingContentDirty) {
                didReportPendingContentDirty = true
                self.onContentDirty?()
            }
        }

        guard !isApplyingFromSwift, !applying,
              let next = payload["text"] as? String else { return }

        hasPendingEditorTextSnapshot = false
        didReportPendingContentDirty = false
        if let epdocController {
            let epoch = epdocLoadEpoch ?? epdocController.currentLoadEpoch
            epdocController.handleBridgeMessage(
                .markdownDidChange(markdown: next, writeback: nil),
                epoch: epoch
            )
        } else {
            text.wrappedValue = next
        }
        if let applied = lastAppliedState {
            lastAppliedState = applied.replacingText(next)
        }
        if let pendingState {
            self.pendingState = pendingState.replacingText(next)
        }
        if let webView {
            flushPendingState(in: webView)
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
    ) {
        guard !isDetached else {
            replyHandler(nil, nil)
            return
        }
        guard message.name == MarkEditCoreEditorBridge.nativeMessageHandlerName,
              message.frameInfo.isMainFrame,
              let payload = message.body as? [String: Any] else {
            replyHandler(nil, nil)
            return
        }

        let moduleName = payload["moduleName"] as? String
        let methodName = payload["methodName"] as? String

        if moduleName == "core", methodName == "notifyWindowDidLoad" {
            beginCoreEditorReadyCheckAfterNativeLoadNotification()
        }

        replyHandler(Self.nativeBridgeReply(moduleName: moduleName, methodName: methodName), nil)
    }

    private func beginCoreEditorReadyCheckAfterNativeLoadNotification() {
        guard !isDetached,
              bootstrapResetGeneration != loadGeneration,
              let webView else { return }

        bootstrapResetGeneration = loadGeneration
        waitForCoreEditorReady(in: webView, generation: loadGeneration)
    }

    private static func nativeBridgeReply(moduleName: String?, methodName: String?) -> Any? {
        switch (moduleName, methodName) {
        case ("preview", "show"):
            return #"{"handledBy":"epistemos-embedded-source"}"#
        case ("tokenizer", "tokenize"):
            return ["from": 0, "to": 0]
        case ("tokenizer", "moveWordBackward"),
             ("tokenizer", "moveWordForward"):
            return 0
        case ("history", "canUndo"),
             ("history", "canRedo"):
            return false
        default:
            return nil
        }
    }

    private static let focusStartScript = """
    (() => {
      if (!window.editor || !window.MarkEdit?.editorAPI) { return false; }
      window.MarkEdit.editorAPI.setSelections([{ from: 0, to: 0 }]);
      window.editor.focus();
      window.webModules?.selection?.scrollToSelection?.();
      return true;
    })();
    """

    private static let focusEndScript = """
    (() => {
      if (!window.editor || !window.MarkEdit?.editorAPI) { return false; }
      const end = window.editor.state.doc.length;
      window.MarkEdit.editorAPI.setSelections([{ from: end, to: end }]);
      window.editor.focus();
      window.webModules?.selection?.scrollToSelection?.();
      return true;
    })();
    """

    private static let toggleHighlightScript = """
    (() => {
      if (!window.editor) { return false; }
      const state = window.editor.state;
      const range = state.selection.main;
      const selected = state.sliceDoc(range.from, range.to);
      const body = selected.length > 0 ? selected : 'highlight';
      const inserted = `==${body}==`;
      window.editor.dispatch({
        changes: { from: range.from, to: range.to, insert: inserted },
        selection: { anchor: range.from + 2, head: range.from + 2 + body.length },
      });
      window.editor.focus();
      return true;
    })();
    """

    private static let snapshotBridgeScript = """
    (() => {
      if (window.__epistemosMarkEditSnapshotInstalled) { return true; }
      window.__epistemosMarkEditSnapshotInstalled = true;

      const isEpdoc = window.config?.epistemosMode === "epdoc";

      let lastText = null;
      let lastLine = -1;
      let lastColumn = -1;
      let lastLineCount = -1;
      const textSnapshotDelays = {
        small: 240,
        medium: 420,
        large: 700,
      };
      const metadataPending = { value: false };
      let textSnapshotTimer = null;
      let contentDirty = { value: false };
      const documentInstance = globalThis.crypto?.randomUUID?.()
        ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`;
      let transactionRevision = 0;

      window.__epistemosMarkEditCheckpoint = () => {
        if (!window.editor || !window.webModules?.core?.getEditorText) { return null; }
        const text = window.webModules.core.getEditorText();
        lastText = text;
        contentDirty.value = false;
        return {
          text,
          documentInstance,
          revision: transactionRevision,
        };
      };

      const textSnapshotDelay = () => {
        const length = window.editor?.state?.doc?.length ?? 0;
        if (length >= 80000) { return textSnapshotDelays.large; }
        if (length >= 20000) { return textSnapshotDelays.medium; }
        return textSnapshotDelays.small;
      };

      const postSnapshot = (kind, options = {}) => {
        try {
          if (!window.editor || !window.webModules?.core?.getEditorText) { return; }
          const includeText = options.includeText === true;
          const text = includeText ? window.webModules.core.getEditorText() : null;
          const state = window.editor.state;
          const head = state.selection.main.head;
          const line = state.doc.lineAt(head);
          const column = head - line.from + 1;
          const lineCount = state.doc.lines;
          if (
            kind !== "ready" &&
            !contentDirty.value &&
            (!includeText || text === lastText) &&
            line.number === lastLine &&
            column === lastColumn &&
            lineCount === lastLineCount
          ) {
            return;
          }
          if (includeText) {
            lastText = text;
            contentDirty.value = false;
          }
          lastLine = line.number;
          lastColumn = column;
          lastLineCount = lineCount;
          const payload = {
            kind,
            line: line.number,
            column,
            lineCount,
            applying: Boolean(window.__epistemosApplyingMarkEditState),
            contentDirty: contentDirty.value,
          };
          if (includeText) {
            payload.text = text;
          }
          window.webkit?.messageHandlers?.epistemosMarkEditCoreEditor?.postMessage(payload);
        } catch (error) {
          console.error("[Epistemos] MarkEdit snapshot failed", error);
        }
      };

      const postTextSnapshot = (kind) => {
        if (textSnapshotTimer !== null) {
          clearTimeout(textSnapshotTimer);
          textSnapshotTimer = null;
        }
        postSnapshot(kind, { includeText: true });
      };

      const scheduleMetadataSnapshot = () => {
        if (metadataPending.value) { return; }
        metadataPending.value = true;
        requestAnimationFrame(() => {
          metadataPending.value = false;
          postSnapshot("cursor", { includeText: false });
        });
      };

      const scheduleTextSnapshot = () => {
        contentDirty.value = true;
        scheduleMetadataSnapshot();
        if (textSnapshotTimer !== null) {
          clearTimeout(textSnapshotTimer);
        }
        textSnapshotTimer = setTimeout(() => {
          postTextSnapshot("snapshot");
        }, textSnapshotDelay());
      };

      const postTransactions = (update) => {
        const applying = Boolean(window.__epistemosApplyingMarkEditState);
        for (const transaction of update.transactions) {
          if (!transaction.docChanged) { continue; }
          const changes = [];
          transaction.changes.iterChanges((fromA, toA, _fromB, _toB, inserted) => {
            changes.push({
              fromUTF16: fromA,
              toUTF16: toA,
              insertedText: inserted.sliceString(
                0,
                inserted.length,
                transaction.startState.lineBreak
              ),
            });
          });
          transactionRevision += 1;
          contentDirty.value = true;
          const head = transaction.newSelection.main.head;
          const line = transaction.newDoc.lineAt(head);
          window.webkit?.messageHandlers?.epistemosMarkEditCoreEditor?.postMessage({
            kind: "transaction",
            documentInstance,
            revision: transactionRevision,
            startUTF16Length: transaction.startState.doc.length,
            endUTF16Length: transaction.newDoc.length,
            changes,
            line: line.number,
            column: head - line.from + 1,
            lineCount: transaction.newDoc.lines,
            applying,
            contentDirty: true,
          });
        }
        scheduleMetadataSnapshot();
      };

      if (
        isEpdoc &&
        window.MarkEdit?.addExtension &&
        window.MarkEdit?.codemirror?.view?.EditorView?.updateListener
      ) {
        const listener = window.MarkEdit.codemirror.view.EditorView.updateListener.of(update => {
          if (update.docChanged) {
            postTransactions(update);
          }
        });
        window.MarkEdit.addExtension(listener);
      } else {
        document.addEventListener("input", scheduleTextSnapshot, true);
      }
      document.addEventListener("keyup", scheduleMetadataSnapshot, true);
      document.addEventListener("mouseup", scheduleMetadataSnapshot, true);
      document.addEventListener("selectionchange", scheduleMetadataSnapshot, true);
      if (!isEpdoc) {
        window.addEventListener("pagehide", () => postTextSnapshot("pagehide"));
        window.addEventListener("beforeunload", () => postTextSnapshot("beforeunload"));
        setInterval(() => {
          if (contentDirty.value) {
            scheduleTextSnapshot();
          } else {
            postSnapshot("cursor", { includeText: false });
          }
        }, 1000);
      }
      setTimeout(() => postSnapshot("ready", { includeText: !isEpdoc }), 0);
      setTimeout(() => postSnapshot("ready", { includeText: !isEpdoc }), 250);
      return true;
    })();
    """
}
