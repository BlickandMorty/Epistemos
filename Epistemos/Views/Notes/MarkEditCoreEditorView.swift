import AppKit
import SwiftUI
import WebKit

#if canImport(MarkEditKit)
import MarkEditKit
#endif

nonisolated enum MarkEditCoreEditorBridge {
    static let messageHandlerName = "epistemosMarkEditCoreEditor"
    static let chunkScheme = "chunk-loader"
    static let resourceSubpath = "CoreEditor"
}

struct MarkEditCodeEditorRepresentable: View {
    @Binding var text: String
    @Binding var cursorLine: Int
    @Binding var cursorColumn: Int
    @Binding var totalLines: Int

    var language: String
    var theme: EpistemosTheme
    var fontSize: Double
    var wrapLines: Bool
    var showLineNumbers: Bool
    var showInvisibles: Bool
    var useSpaces: Bool
    var tabWidth: Int
    var selectionRequest: WebKitCodeEditorSelectionRequest?

    var body: some View {
        MarkEditCoreEditorRepresentable(
            mode: .code(language: language),
            text: $text,
            cursorLine: $cursorLine,
            cursorColumn: $cursorColumn,
            totalLines: $totalLines,
            theme: theme,
            fontSize: fontSize,
            wrapLines: wrapLines,
            showLineNumbers: showLineNumbers,
            showInvisibles: showInvisibles,
            useSpaces: useSpaces,
            tabWidth: tabWidth,
            selectionRequest: selectionRequest
        )
    }
}

struct MarkEditMarkdownEditorRepresentable: View {
    @Binding var text: String
    @Binding var cursorLine: Int
    @Binding var cursorColumn: Int
    @Binding var totalLines: Int

    var theme: EpistemosTheme
    var fontSize: Double
    var wrapLines: Bool
    var showLineNumbers: Bool
    var showInvisibles: Bool
    var useSpaces: Bool
    var tabWidth: Int
    var selectionRequest: WebKitCodeEditorSelectionRequest?

    var body: some View {
        #if canImport(MarkEditKit)
        MarkEditVerbatimMarkdownChromeRepresentable(
            text: $text,
            cursorLine: $cursorLine,
            cursorColumn: $cursorColumn,
            totalLines: $totalLines
        )
        #else
        MarkEditCoreEditorRepresentable(
            mode: .markdownChrome,
            text: $text,
            cursorLine: $cursorLine,
            cursorColumn: $cursorColumn,
            totalLines: $totalLines,
            theme: theme,
            fontSize: fontSize,
            wrapLines: wrapLines,
            showLineNumbers: showLineNumbers,
            showInvisibles: showInvisibles,
            useSpaces: useSpaces,
            tabWidth: tabWidth,
            selectionRequest: selectionRequest
        )
        #endif
    }
}

#if canImport(MarkEditKit)
private struct MarkEditVerbatimMarkdownChromeRepresentable: NSViewControllerRepresentable {
    @Binding var text: String
    @Binding var cursorLine: Int
    @Binding var cursorColumn: Int
    @Binding var totalLines: Int

    func makeCoordinator() -> MarkEditVerbatimMarkdownChromeCoordinator {
        MarkEditVerbatimMarkdownChromeCoordinator(
            text: $text,
            cursorLine: $cursorLine,
            cursorColumn: $cursorColumn,
            totalLines: $totalLines
        )
    }

    func makeNSViewController(context: Context) -> EditorViewController {
        let viewController = EditorViewController()
        context.coordinator.attach(to: viewController, initialText: text)
        return viewController
    }

    func updateNSViewController(_ viewController: EditorViewController, context: Context) {
        context.coordinator.text = $text
        context.coordinator.cursorLine = $cursorLine
        context.coordinator.cursorColumn = $cursorColumn
        context.coordinator.totalLines = $totalLines
        context.coordinator.update(viewController: viewController, externalText: text)
    }

    static func dismantleNSViewController(
        _ viewController: EditorViewController,
        coordinator: MarkEditVerbatimMarkdownChromeCoordinator
    ) {
        coordinator.detach()
    }
}

@MainActor
private final class MarkEditVerbatimMarkdownChromeCoordinator {
    var text: Binding<String>
    var cursorLine: Binding<Int>
    var cursorColumn: Binding<Int>
    var totalLines: Binding<Int>

    private weak var viewController: EditorViewController?
    private var lastAppliedText: String?
    private var isApplyingFromSwift = false
    private var pollingTask: Task<Void, Never>?

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

    func attach(to viewController: EditorViewController, initialText: String) {
        self.viewController = viewController
        apply(text: initialText, to: viewController, documentChanged: true)
        startPolling(viewController: viewController)
    }

    func update(viewController: EditorViewController, externalText: String) {
        self.viewController = viewController
        guard externalText != lastAppliedText else { return }
        apply(text: externalText, to: viewController, documentChanged: false)
    }

    func detach() {
        pollingTask?.cancel()
        pollingTask = nil
        viewController = nil
        lastAppliedText = nil
        isApplyingFromSwift = false
    }

    private func apply(
        text nextText: String,
        to viewController: EditorViewController,
        documentChanged: Bool
    ) {
        lastAppliedText = nextText
        updateLineCount(for: nextText)
        isApplyingFromSwift = true
        Task { @MainActor [weak self, weak viewController] in
            guard let self, let viewController else { return }
            await viewController.waitUntilLoaded()
            _ = try? await viewController.bridge.core.resetEditor(
                text: nextText,
                selectionRange: nil,
                documentChanged: documentChanged
            )
            self.isApplyingFromSwift = false
        }
    }

    private func startPolling(viewController: EditorViewController) {
        guard pollingTask == nil else { return }
        pollingTask = Task { @MainActor [weak self, weak viewController] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self, let viewController else { continue }
                await self.poll(viewController: viewController)
            }
        }
    }

    private func poll(viewController: EditorViewController) async {
        guard !isApplyingFromSwift,
              let nextText = await viewController.editorText,
              nextText != text.wrappedValue else { return }
        text.wrappedValue = nextText
        lastAppliedText = nextText
        updateLineCount(for: nextText)
    }

    private func updateLineCount(for text: String) {
        totalLines.wrappedValue = max(1, text.split(separator: "\n", omittingEmptySubsequences: false).count)
        cursorLine.wrappedValue = min(max(1, cursorLine.wrappedValue), totalLines.wrappedValue)
        cursorColumn.wrappedValue = max(1, cursorColumn.wrappedValue)
    }
}
#endif

private enum MarkEditCoreEditorMode: Equatable {
    case code(language: String)
    case markdownChrome

    var language: String {
        switch self {
        case .code(let language):
            return language
        case .markdownChrome:
            return "markdown"
        }
    }
}

private struct MarkEditCoreEditorRepresentable: NSViewRepresentable {
    var mode: MarkEditCoreEditorMode
    @Binding var text: String
    @Binding var cursorLine: Int
    @Binding var cursorColumn: Int
    @Binding var totalLines: Int

    var theme: EpistemosTheme
    var fontSize: Double
    var wrapLines: Bool
    var showLineNumbers: Bool
    var showInvisibles: Bool
    var useSpaces: Bool
    var tabWidth: Int
    var selectionRequest: WebKitCodeEditorSelectionRequest?

    func makeCoordinator() -> MarkEditCoreEditorCoordinator {
        MarkEditCoreEditorCoordinator(
            text: $text,
            cursorLine: $cursorLine,
            cursorColumn: $cursorColumn,
            totalLines: $totalLines
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.setURLSchemeHandler(
            MarkEditCoreEditorChunkLoader(),
            forURLScheme: MarkEditCoreEditorBridge.chunkScheme
        )
        configuration.userContentController.add(
            context.coordinator,
            name: MarkEditCoreEditorBridge.messageHandlerName
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        context.coordinator.loadEditor(into: webView, initialState: state)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.cursorLine = $cursorLine
        context.coordinator.cursorColumn = $cursorColumn
        context.coordinator.totalLines = $totalLines
        context.coordinator.update(
            webView: webView,
            state: state,
            selectionRequest: selectionRequest
        )
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: MarkEditCoreEditorCoordinator) {
        coordinator.detach(from: webView)
    }

    private var state: MarkEditCoreEditorState {
        MarkEditCoreEditorState(
            text: text,
            mode: mode,
            themeName: theme.isDark ? "github-dark" : "github-light",
            fontSize: max(8, min(fontSize, 32)),
            wrapLines: wrapLines,
            showLineNumbers: showLineNumbers,
            showInvisibles: showInvisibles,
            useSpaces: useSpaces,
            tabWidth: tabWidth
        )
    }
}

private final class MarkEditCoreEditorCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var text: Binding<String>
    var cursorLine: Binding<Int>
    var cursorColumn: Binding<Int>
    var totalLines: Binding<Int>
    weak var webView: WKWebView?

    private var hasLoadedEditor = false
    private var pendingState: MarkEditCoreEditorState?
    private var lastAppliedState: MarkEditCoreEditorState?
    private var lastSelectionRequestID: UUID?
    private var isApplyingFromSwift = false

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
        hasLoadedEditor = false
        pendingState = nil
        lastAppliedState = initialState
        let html = MarkEditCoreEditorDocument.html(for: initialState)
        webView.loadHTMLString(html, baseURL: URL(string: "https://epistemos-markedit.local/"))
    }

    func detach(from webView: WKWebView) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: MarkEditCoreEditorBridge.messageHandlerName
        )
        self.webView = nil
        hasLoadedEditor = false
        pendingState = nil
        lastAppliedState = nil
        lastSelectionRequestID = nil
        isApplyingFromSwift = false
    }

    func update(
        webView: WKWebView,
        state: MarkEditCoreEditorState,
        selectionRequest: WebKitCodeEditorSelectionRequest?
    ) {
        if hasLoadedEditor {
            apply(state: state, to: webView)
            apply(selectionRequest: selectionRequest, to: webView)
        } else {
            pendingState = state
        }
    }

    private func apply(state: MarkEditCoreEditorState, to webView: WKWebView) {
        if let lastAppliedState, state.requiresReload(comparedTo: lastAppliedState) {
            loadEditor(into: webView, initialState: state)
            return
        }

        guard state != lastAppliedState else { return }
        lastAppliedState = state
        guard let json = state.resetMessageJSON else { return }
        isApplyingFromSwift = true
        let script = """
        (async () => {
          if (!window.webModules?.core?.resetEditor) { return false; }
          window.__epistemosApplyingMarkEditState = true;
          try {
            await window.webModules.core.resetEditor(\(json));
            return true;
          } finally {
            setTimeout(() => { window.__epistemosApplyingMarkEditState = false; }, 0);
          }
        })();
        """
        webView.evaluateJavaScript(script) { [weak self] _, _ in
            self?.isApplyingFromSwift = false
        }
    }

    private func apply(selectionRequest: WebKitCodeEditorSelectionRequest?, to webView: WKWebView) {
        guard let selectionRequest,
              selectionRequest.id != lastSelectionRequestID else { return }
        lastSelectionRequestID = selectionRequest.id
        let from = max(0, selectionRequest.range.location)
        let to = from + max(0, selectionRequest.range.length)
        let script = """
        (() => {
          if (!window.MarkEdit?.editorAPI) { return false; }
          window.MarkEdit.editorAPI.setSelections([{ from: \(from), to: \(to) }]);
          window.webModules?.selection?.scrollToSelection?.();
          return true;
        })();
        """
        webView.evaluateJavaScript(script)
    }

    private func installSnapshotBridge(into webView: WKWebView) {
        webView.evaluateJavaScript(Self.snapshotBridgeScript)
    }

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        hasLoadedEditor = true
        installSnapshotBridge(into: webView)
        if let pendingState {
            self.pendingState = nil
            apply(state: pendingState, to: webView)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        let scheme = navigationAction.request.url?.scheme
        if scheme == "about" || scheme == MarkEditCoreEditorBridge.chunkScheme {
            decisionHandler(.allow)
            return
        }
        if navigationAction.navigationType == .other {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == MarkEditCoreEditorBridge.messageHandlerName,
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
      setInterval(() => postSnapshot("snapshot"), 250);
      setTimeout(() => postSnapshot("ready"), 0);
      setTimeout(() => postSnapshot("ready"), 250);
      return true;
    })();
    """
}

private struct MarkEditCoreEditorState: Equatable {
    let text: String
    let mode: MarkEditCoreEditorMode
    let themeName: String
    let fontSize: Double
    let wrapLines: Bool
    let showLineNumbers: Bool
    let showInvisibles: Bool
    let useSpaces: Bool
    let tabWidth: Int

    var resetMessageJSON: String? {
        MarkEditCoreEditorResetMessage(
            text: text,
            selectionRange: nil,
            documentChanged: false
        ).jsonString
    }

    var configJSON: String? {
        MarkEditCoreEditorConfig(
            text: text,
            theme: themeName,
            fontFace: .init(family: "SF Mono", weight: nil, style: nil),
            fontSize: fontSize,
            showLineNumbers: showLineNumbers,
            showActiveLineIndicator: true,
            invisiblesBehavior: showInvisibles ? "always" : "never",
            readOnlyMode: false,
            typewriterMode: false,
            focusMode: false,
            lineWrapping: wrapLines,
            lineHeight: 1.45,
            suggestWhileTyping: false,
            standardDirectories: [:],
            runtimeInfo: .current,
            defaultLineBreak: "\n",
            tabKeyBehavior: tabKeyBehavior,
            indentUnit: indentUnit,
            localizable: nil,
            autoCharacterPairs: true,
            indentBehavior: "line",
            headerFontSizeDiffs: nil,
            visibleWhitespaceCharacter: nil,
            visibleLineBreakCharacter: nil,
            searchNormalizers: nil
        ).jsonString
    }

    func replacingText(_ nextText: String) -> MarkEditCoreEditorState {
        MarkEditCoreEditorState(
            text: nextText,
            mode: mode,
            themeName: themeName,
            fontSize: fontSize,
            wrapLines: wrapLines,
            showLineNumbers: showLineNumbers,
            showInvisibles: showInvisibles,
            useSpaces: useSpaces,
            tabWidth: tabWidth
        )
    }

    func requiresReload(comparedTo other: MarkEditCoreEditorState) -> Bool {
        mode != other.mode ||
            themeName != other.themeName ||
            fontSize != other.fontSize ||
            wrapLines != other.wrapLines ||
            showLineNumbers != other.showLineNumbers ||
            showInvisibles != other.showInvisibles ||
            useSpaces != other.useSpaces ||
            clampedTabWidth != other.clampedTabWidth
    }

    private var clampedTabWidth: Int {
        max(1, min(tabWidth, 8))
    }

    private var indentUnit: String {
        useSpaces ? String(repeating: " ", count: clampedTabWidth) : "\t"
    }

    private var tabKeyBehavior: Int {
        guard useSpaces else { return 0 }
        switch clampedTabWidth {
        case 2:
            return 1
        case 4:
            return 2
        default:
            return 3
        }
    }
}

private struct MarkEditCoreEditorConfig: Encodable {
    let text: String
    let theme: String
    let fontFace: MarkEditCoreEditorFontFace
    let fontSize: Double
    let showLineNumbers: Bool
    let showActiveLineIndicator: Bool
    let invisiblesBehavior: String
    let readOnlyMode: Bool
    let typewriterMode: Bool
    let focusMode: Bool
    let lineWrapping: Bool
    let lineHeight: Double
    let suggestWhileTyping: Bool
    let standardDirectories: [String: String]
    let runtimeInfo: MarkEditCoreEditorRuntimeInfo?
    let defaultLineBreak: String?
    let tabKeyBehavior: Int?
    let indentUnit: String?
    let localizable: [String: String]?
    let autoCharacterPairs: Bool
    let indentBehavior: String
    let headerFontSizeDiffs: [Double]?
    let visibleWhitespaceCharacter: String?
    let visibleLineBreakCharacter: String?
    let searchNormalizers: [String: String]?
}

private struct MarkEditCoreEditorFontFace: Encodable {
    let family: String
    let weight: String?
    let style: String?
}

private struct MarkEditCoreEditorRuntimeInfo: Encodable {
    let appVersion: String
    let appBuild: String
    let osVersion: String
    let webkitVersion: String

    static var current: MarkEditCoreEditorRuntimeInfo {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return MarkEditCoreEditorRuntimeInfo(
            appVersion: version,
            appBuild: build,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            webkitVersion: ""
        )
    }
}

private struct MarkEditCoreEditorSelectionRange: Encodable {
    let anchor: Int
    let head: Int
}

private struct MarkEditCoreEditorResetMessage: Encodable {
    let text: String
    let selectionRange: MarkEditCoreEditorSelectionRange?
    let documentChanged: Bool
}

private extension Encodable {
    var jsonString: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private enum MarkEditCoreEditorDocument {
    static func html(for state: MarkEditCoreEditorState) -> String {
        guard let template = templateHTML,
              let configJSON = state.configJSON else {
            return fallbackHTML
        }
        return template
            .replacingOccurrences(of: "/chunk-loader/", with: "\(MarkEditCoreEditorBridge.chunkScheme)://")
            .replacingOccurrences(of: "\"{{EDITOR_CONFIG}}\"", with: configJSON)
            .replacingOccurrences(of: "\"{{USER_SETTINGS}}\"", with: "{}")
    }

    private static var templateHTML: String? {
        if let url = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: MarkEditCoreEditorBridge.resourceSubpath
        ),
           let html = try? String(contentsOf: url, encoding: .utf8) {
            return html
        }

        if let url = Bundle.main.url(forResource: "index", withExtension: "html"),
           let html = try? String(contentsOf: url, encoding: .utf8) {
            return html
        }

        let repoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Epistemos/Resources")
            .appendingPathComponent(MarkEditCoreEditorBridge.resourceSubpath)
            .appendingPathComponent("index.html")
        return try? String(contentsOf: repoURL, encoding: .utf8)
    }

    private static let fallbackHTML = """
    <!doctype html>
    <html>
    <body style="font: 13px -apple-system; padding: 16px;">
      MarkEdit CoreEditor bundle is missing.
    </body>
    </html>
    """
}

private final class MarkEditCoreEditorChunkLoader: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              let relativePath = Self.relativePath(for: url),
              let fileURL = Self.fileURL(relativePath: relativePath),
              let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(Self.error(for: urlSchemeTask.request.url))
            return
        }

        let mimeType = Self.mimeTypes[fileURL.pathExtension.lowercased()] ?? "application/octet-stream"
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Access-Control-Allow-Origin": "*",
                "Content-Type": mimeType,
            ]
        ) ?? URLResponse(
            url: url,
            mimeType: mimeType,
            expectedContentLength: data.count,
            textEncodingName: "utf-8"
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private static func relativePath(for url: URL) -> String? {
        guard url.scheme == MarkEditCoreEditorBridge.chunkScheme,
              let host = url.host,
              !host.isEmpty else { return nil }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.isEmpty ? host : "\(host)/\(path)"
    }

    private static func fileURL(relativePath: String) -> URL? {
        let filename = URL(fileURLWithPath: relativePath).lastPathComponent
        let candidates = [
            Bundle.main.resourceURL?
                .appendingPathComponent(MarkEditCoreEditorBridge.resourceSubpath, isDirectory: true)
                .appendingPathComponent(relativePath),
            Bundle.main.resourceURL?
                .appendingPathComponent(relativePath),
            Bundle.main.url(forResource: filename, withExtension: nil),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Epistemos/Resources")
                .appendingPathComponent(MarkEditCoreEditorBridge.resourceSubpath)
                .appendingPathComponent(relativePath),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Epistemos/Resources")
                .appendingPathComponent(relativePath),
        ].compactMap { $0 }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func error(for url: URL?) -> NSError {
        NSError(
            domain: "MarkEditCoreEditorChunkLoader",
            code: 1,
            userInfo: [NSURLErrorKey: url?.absoluteString ?? ""]
        )
    }

    private static let mimeTypes = [
        "js": "text/javascript",
        "css": "text/css",
        "woff2": "font/woff2",
    ]
}
