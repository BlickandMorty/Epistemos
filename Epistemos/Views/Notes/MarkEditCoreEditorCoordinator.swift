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
    private var lastSelectionRequestID: UUID?
    private var isApplyingFromSwift = false
    private var hasPendingEditorTextSnapshot = false
    private var didReportPendingContentDirty = false
    private var isDetached = false
    private var loadGeneration = 0
    private var bootstrapResetGeneration: Int?
    private var terminalLoadFailureGeneration: Int?
    private var readOnlyApplicationGeneration = 0
    private var liveTextRegistration: MarkEditCoreEditorLiveTextRegistry.Registration?

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

    func loadEditor(into webView: WKWebView, initialState: MarkEditCoreEditorState) {
        isDetached = false
        loadGeneration += 1
        readOnlyApplicationGeneration += 1
        hasLoadedEditor = false
        pendingState = nil
        pendingSelectionRequest = nil
        loadingState = initialState
        lastAppliedState = nil
        lastSelectionRequestID = nil
        isApplyingFromSwift = false
        hasPendingEditorTextSnapshot = false
        didReportPendingContentDirty = false
        bootstrapResetGeneration = nil
        terminalLoadFailureGeneration = nil
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
        let promise = Self.requestCurrentEditorText(from: webView)
        let value = await promise.value()
        guard !isDetached, generation == loadGeneration else { return nil }
        return value
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

    private func apply(state: MarkEditCoreEditorState, to webView: WKWebView) {
        guard !isDetached, hasLoadedEditor, !webView.isLoading else {
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

    private func resetEditor(
        to state: MarkEditCoreEditorState,
        in webView: WKWebView,
        documentChanged: Bool
    ) {
        guard !isDetached, hasLoadedEditor, !webView.isLoading else {
            pendingState = state
            return
        }
        guard let json = state.resetMessageJSON(documentChanged: documentChanged) else { return }
        isApplyingFromSwift = true
        let generation = loadGeneration
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
          setTimeout(() => { window.__epistemosApplyingMarkEditState = false; }, 0);
        }
        """
        webView.callAsyncJavaScript(script, in: nil, in: .page) { [weak self, weak webView] result in
            guard let self,
                  generation == self.loadGeneration,
                  !self.isDetached else { return }
            self.isApplyingFromSwift = false
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
                self.lastAppliedState = state
                if let webView {
                    self.flushPendingState(in: webView)
                }
            } else {
                self.lastAppliedState = previousState
                self.pendingState = state
                if let webView {
                    self.showLoadFailure(
                        in: webView,
                        message: "MarkEdit CoreEditor reset failed: \(Self.resetFailureMessage(result: scriptResult, error: scriptError))"
                    )
                }
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
        installSnapshotBridge(into: webView)
        let state = pendingState ?? loadingState
        pendingState = nil
        loadingState = nil
        if let state {
            applyTheme(themeName: state.themeName, palette: state.themePalette, to: webView)
            resetEditor(to: state, in: webView, documentChanged: true)
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
        let recoveryText = Self.preferredRecoveryText(
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
        if payload["contentDirty"] as? Bool == true {
            hasPendingEditorTextSnapshot = true
            if !isApplyingFromSwift, !applying, !didReportPendingContentDirty {
                didReportPendingContentDirty = true
                self.onContentDirty?()
            }
        }

        guard !isApplyingFromSwift, !applying,
              let next = payload["text"] as? String else { return }

        hasPendingEditorTextSnapshot = false
        didReportPendingContentDirty = false
        text.wrappedValue = next
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
        case ("api", "listFiles"):
            return []
        case ("api", "getPasteboardItems"):
            return "[]"
        case ("api", "getPasteboardString"),
             ("api", "getFileContent"),
             ("api", "getFileObject"),
             ("api", "getFileInfo"),
             ("foundationModels", "createSession"):
            return nil
        case ("api", "showAlert"):
            return 0
        case ("api", "showTextBox"):
            return nil
        case ("foundationModels", "availability"):
            return #"{"available":false}"#
        case ("foundationModels", "isResponding"):
            return false
        case ("foundationModels", "respondTo"):
            return #"{"content":"","error":"Foundation Models are unavailable in the embedded Source editor."}"#
        case ("preview", "show"):
            return #"{"handledBy":"epistemos-embedded-source"}"#
        case ("translation", "translate"):
            return #"{"error":"Translation is unavailable in the embedded Source editor."}"#
        case ("tokenizer", "tokenize"):
            return ["from": 0, "to": 0]
        case ("tokenizer", "moveWordBackward"),
             ("tokenizer", "moveWordForward"):
            return 0
        case ("history", "canUndo"),
             ("history", "canRedo"):
            return false
        case ("api", "saveDocument"),
             ("api", "closeDocument"),
             ("api", "showSavePanel"),
             ("api", "runService"),
             ("api", "openFile"),
             ("api", "createFile"),
             ("api", "deleteFile"),
             ("api", "moveFile"),
             ("api", "revealFile"):
            return false
        default:
            return nil
        }
    }

    private static let snapshotBridgeScript = """
    (() => {
      if (window.__epistemosMarkEditSnapshotInstalled) { return true; }
      window.__epistemosMarkEditSnapshotInstalled = true;

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

      document.addEventListener("input", scheduleTextSnapshot, true);
      document.addEventListener("keyup", scheduleMetadataSnapshot, true);
      document.addEventListener("mouseup", scheduleMetadataSnapshot, true);
      document.addEventListener("selectionchange", scheduleMetadataSnapshot, true);
      window.addEventListener("pagehide", () => postTextSnapshot("pagehide"));
      window.addEventListener("beforeunload", () => postTextSnapshot("beforeunload"));
      setInterval(() => {
        if (contentDirty.value) {
          scheduleTextSnapshot();
        } else {
          postSnapshot("cursor", { includeText: false });
        }
      }, 1000);
      setTimeout(() => postSnapshot("ready", { includeText: true }), 0);
      setTimeout(() => postSnapshot("ready", { includeText: true }), 250);
      return true;
    })();
    """
}
