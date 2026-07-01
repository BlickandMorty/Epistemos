import Foundation
import SwiftUI
import WebKit

final class MarkEditCoreEditorCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKScriptMessageHandlerWithReply {
    var text: Binding<String>
    var cursorLine: Binding<Int>
    var cursorColumn: Binding<Int>
    var totalLines: Binding<Int>
    weak var webView: WKWebView?

    private var hasLoadedEditor = false
    private var pendingState: MarkEditCoreEditorState?
    private var pendingSelectionRequest: CoreEditorSelectionRequest?
    private var loadingState: MarkEditCoreEditorState?
    private var lastAppliedState: MarkEditCoreEditorState?
    private var lastSelectionRequestID: UUID?
    private var isApplyingFromSwift = false
    private var isDetached = false
    private var loadGeneration = 0
    private var bootstrapResetGeneration: Int?

    init(
        text: Binding<String>,
        cursorLine: Binding<Int>,
        cursorColumn: Binding<Int>,
        totalLines: Binding<Int>
    ) {
        self.text = text
        self.cursorLine = cursorLine
        self.cursorColumn = cursorColumn
        self.totalLines = totalLines
    }

    func loadEditor(into webView: WKWebView, initialState: MarkEditCoreEditorState) {
        isDetached = false
        loadGeneration += 1
        hasLoadedEditor = false
        pendingState = nil
        pendingSelectionRequest = nil
        loadingState = initialState
        lastAppliedState = nil
        lastSelectionRequestID = nil
        isApplyingFromSwift = false
        bootstrapResetGeneration = nil
        let html = MarkEditCoreEditorDocument.html(for: initialState)
        webView.loadHTMLString(html, baseURL: MarkEditCoreEditorBridge.baseURL)
    }

    func detach(from webView: WKWebView) {
        isDetached = true
        loadGeneration += 1
        hasLoadedEditor = false
        pendingState = nil
        pendingSelectionRequest = nil
        loadingState = nil
        isApplyingFromSwift = false
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
            loadEditor(into: webView, initialState: state)
            return
        }

        guard state != lastAppliedState else { return }
        resetEditor(to: state, in: webView, documentChanged: false)
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
          if (\(expectedLength) > 0 && renderedText.length === 0) {
            return {
              ok: false,
              error: "CoreEditor reset completed with no rendered CodeMirror text",
              resetResult,
              editorLength: editorText.length,
              lineCount,
            };
          }
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
            showLoadFailure(in: webView, message: "MarkEdit CoreEditor failed to load. Check CoreEditor chunks, the chunk-loader scheme, and the MarkEdit native bridge.")
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
            resetEditor(to: state, in: webView, documentChanged: true)
        } else {
            flushPendingState(in: webView)
        }
    }

    private func showLoadFailure(in webView: WKWebView, message: String) {
        guard !isDetached, !webView.isLoading else { return }
        hasLoadedEditor = false
        isApplyingFromSwift = false
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
            return host == "localhost" || host == "127.0.0.1" || host == "::1"
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
        guard !isApplyingFromSwift, !applying,
              let next = payload["text"] as? String else { return }

        text.wrappedValue = next
        if let applied = lastAppliedState {
            lastAppliedState = applied.replacingText(next)
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
            bootstrapEditorAfterNativeLoadNotification()
        }

        replyHandler(Self.nativeBridgeReply(moduleName: moduleName, methodName: methodName), nil)
    }

    private func bootstrapEditorAfterNativeLoadNotification() {
        guard !isDetached,
              bootstrapResetGeneration != loadGeneration,
              let webView else { return }

        bootstrapResetGeneration = loadGeneration
        let generation = loadGeneration
        let script = """
        if (!window.webModules?.core?.resetEditor) {
          return { ok: false, error: "CoreEditor resetEditor bridge is missing after native load" };
        }
        const config = window.config || window.MarkEdit?.editorConfig || {};
        const text = typeof config.text === "string" ? config.text : "";
        const resetResult = await window.webModules.core.resetEditor({
          text,
          selectionRange: null,
          documentChanged: true,
        });
        return {
          ok: resetResult === true,
          resetResult,
          editorLength: window.webModules?.core?.getEditorText?.()?.length ?? 0,
          renderedLength: document.querySelector(".cm-content")?.textContent?.length ?? 0,
        };
        """
        webView.callAsyncJavaScript(script, in: nil, in: .page) { [weak self, weak webView] result in
            guard let self,
                  generation == self.loadGeneration,
                  !self.isDetached else { return }

            switch result {
            case .success(let report as [String: Any]) where report["ok"] as? Bool == true:
                if let webView, !webView.isLoading {
                    self.waitForCoreEditorReady(in: webView, generation: generation)
                }
            case .success(let report):
                if let webView, !webView.isLoading {
                    self.showLoadFailure(
                        in: webView,
                        message: "MarkEdit CoreEditor bootstrap reset failed: \(report)"
                    )
                }
            case .failure(let error):
                if let webView, !webView.isLoading {
                    self.showLoadFailure(
                        in: webView,
                        message: "MarkEdit CoreEditor bootstrap reset failed: \(error.localizedDescription)"
                    )
                }
            }
        }
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
      let pending = { value: false };

      const postSnapshot = (kind) => {
        try {
          if (!window.editor || !window.webModules?.core?.getEditorText) { return; }
          const text = window.webModules.core.getEditorText();
          const state = window.editor.state;
          const head = state.selection.main.head;
          const line = state.doc.lineAt(head);
          const column = head - line.from + 1;
          const lineCount = state.doc.lines;
          if (
            kind !== "ready" &&
            text === lastText &&
            line.number === lastLine &&
            column === lastColumn &&
            lineCount === lastLineCount
          ) {
            return;
          }
          lastText = text;
          lastLine = line.number;
          lastColumn = column;
          lastLineCount = lineCount;
          window.webkit?.messageHandlers?.epistemosMarkEditCoreEditor?.postMessage({
            kind,
            text,
            line: line.number,
            column,
            lineCount,
            applying: Boolean(window.__epistemosApplyingMarkEditState),
          });
        } catch (error) {
          console.error("[Epistemos] MarkEdit snapshot failed", error);
        }
      };

      const scheduleSnapshot = () => {
        if (pending.value) { return; }
        pending.value = true;
        requestAnimationFrame(() => {
          pending.value = false;
          postSnapshot("snapshot");
        });
      };

      document.addEventListener("input", scheduleSnapshot, true);
      document.addEventListener("keyup", scheduleSnapshot, true);
      document.addEventListener("mouseup", scheduleSnapshot, true);
      document.addEventListener("selectionchange", scheduleSnapshot, true);
      window.addEventListener("pagehide", () => postSnapshot("pagehide"));
      setInterval(() => postSnapshot("snapshot"), 250);
      setTimeout(() => postSnapshot("ready"), 0);
      setTimeout(() => postSnapshot("ready"), 250);
      return true;
    })();
    """
}
