import AppKit
import SwiftUI
import WebKit

#if canImport(MarkEditKit)
import MarkEditKit
#endif

nonisolated enum MarkEditCoreEditorBridge {
    static let messageHandlerName = "epistemosMarkEditCoreEditor"
    static let nativeMessageHandlerName = "bridge"
    static let chunkScheme = "chunk-loader"
    static let resourceSubpath = "CoreEditor"
    static let baseURL = URL(string: "http://localhost/")
}

struct CoreEditorSelectionRequest: Equatable {
    let id = UUID()
    let range: NSRange
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
    var selectionRequest: CoreEditorSelectionRequest?

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
    var filePath: String?
    var selectionRequest: CoreEditorSelectionRequest?

    var body: some View {
        #if canImport(MarkEditKit)
        MarkEditVerbatimMarkdownChromeRepresentable(
            text: $text,
            cursorLine: $cursorLine,
            cursorColumn: $cursorColumn,
            totalLines: $totalLines,
            theme: theme,
            filePath: filePath
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

    var theme: EpistemosTheme
    var filePath: String?

    func makeCoordinator() -> MarkEditVerbatimMarkdownChromeCoordinator {
        MarkEditVerbatimMarkdownChromeCoordinator(
            text: $text,
            cursorLine: $cursorLine,
            cursorColumn: $cursorColumn,
            totalLines: $totalLines,
            theme: theme,
            filePath: filePath
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
        context.coordinator.theme = theme
        context.coordinator.filePath = filePath
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
    var theme: EpistemosTheme
    var filePath: String?

    private weak var viewController: EditorViewController?
    private var document: EditorDocument?
    private var lastAppliedText: String?
    private var applyingText: String?
    private var isApplyingFromSwift = false
    private var applyTask: Task<Void, Never>?
    private var applyGeneration = 0
    private var pollingTask: Task<Void, Never>?
    private var chromeTask: Task<Void, Never>?
    private var themeTask: Task<Void, Never>?
    private var lastAppliedTheme: EpistemosTheme?

    init(
        text: Binding<String>,
        cursorLine: Binding<Int>,
        cursorColumn: Binding<Int>,
        totalLines: Binding<Int>,
        theme: EpistemosTheme,
        filePath: String?
    ) {
        self.text = text
        self.cursorLine = cursorLine
        self.cursorColumn = cursorColumn
        self.totalLines = totalLines
        self.theme = theme
        self.filePath = filePath
    }

    func attach(to viewController: EditorViewController, initialText: String) {
        self.viewController = viewController
        EditorPreloader.shared.registerExternalViewController(viewController)
        configureDocument(for: viewController, text: initialText)
        configureChromeWhenWindowReady(for: viewController)
        applyThemeIfNeeded(to: viewController, force: true)
        apply(text: initialText, to: viewController, documentChanged: true)
        startPolling(viewController: viewController)
    }

    func update(viewController: EditorViewController, externalText: String) {
        self.viewController = viewController
        configureDocument(for: viewController, text: externalText)
        configureChromeWhenWindowReady(for: viewController)
        applyThemeIfNeeded(to: viewController)
        guard externalText != lastAppliedText,
              externalText != applyingText else { return }
        apply(text: externalText, to: viewController, documentChanged: false)
    }

    func detach() {
        applyGeneration += 1
        applyTask?.cancel()
        applyTask = nil
        pollingTask?.cancel()
        pollingTask = nil
        chromeTask?.cancel()
        chromeTask = nil
        themeTask?.cancel()
        themeTask = nil
        if let viewController {
            EditorPreloader.shared.unregisterExternalViewController(viewController)
        }
        viewController = nil
        document = nil
        lastAppliedText = nil
        applyingText = nil
        isApplyingFromSwift = false
        lastAppliedTheme = nil
    }

    private func configureDocument(for viewController: EditorViewController, text: String) {
        let editorDocument = document ?? EditorDocument()
        document = editorDocument
        editorDocument.stringValue = text
        if let filePath,
           !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            editorDocument.fileURL = URL(fileURLWithPath: filePath)
        }
        if viewController.representedObject as? EditorDocument !== editorDocument {
            viewController.representedObject = editorDocument
        }
    }

    private func configureChromeWhenWindowReady(for viewController: EditorViewController) {
        guard chromeTask == nil else { return }
        chromeTask = Task { @MainActor [weak self, weak viewController] in
            for _ in 0..<20 {
                guard let self, let viewController, !Task.isCancelled else { return }
                if viewController.view.window != nil {
                    viewController.configureToolbar()
                    self.chromeTask = nil
                    return
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            self?.chromeTask = nil
        }
    }

    private func applyThemeIfNeeded(to viewController: EditorViewController, force: Bool = false) {
        guard force || lastAppliedTheme != theme else { return }
        lastAppliedTheme = theme
        let nextTheme = AppTheme.epistemosSourceTheme(for: theme)
        let backgroundColor = theme.resolved.background.nsColor
        themeTask?.cancel()
        themeTask = Task { @MainActor [weak self, weak viewController] in
            guard let viewController else { return }
            await viewController.waitUntilLoaded()
            guard !Task.isCancelled else { return }
            viewController.webBackgroundColor = backgroundColor
            viewController.setTheme(nextTheme, animated: false)
            self?.themeTask = nil
        }
    }

    private func apply(
        text nextText: String,
        to viewController: EditorViewController,
        documentChanged: Bool
    ) {
        applyGeneration += 1
        let generation = applyGeneration
        applyTask?.cancel()
        applyingText = nextText
        updateLineCount(for: nextText)
        document?.stringValue = nextText
        isApplyingFromSwift = true
        applyTask = Task { @MainActor [weak self, weak viewController] in
            guard let self else { return }
            defer {
                if generation == self.applyGeneration {
                    self.isApplyingFromSwift = false
                    self.applyingText = nil
                    self.applyTask = nil
                }
            }

            guard let viewController, !Task.isCancelled else { return }
            await viewController.waitUntilLoaded()
            guard !Task.isCancelled else { return }

            do {
                _ = try await viewController.bridge.core.resetEditor(
                    text: nextText,
                    selectionRange: nil,
                    documentChanged: documentChanged
                )
                guard generation == self.applyGeneration, !Task.isCancelled else { return }
                self.lastAppliedText = nextText
            } catch {
                guard generation == self.applyGeneration else { return }
                self.lastAppliedText = nil
            }
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
        document?.stringValue = nextText
        lastAppliedText = nextText
        updateLineCount(for: nextText)
    }

    private func updateLineCount(for text: String) {
        totalLines.wrappedValue = max(1, text.split(separator: "\n", omittingEmptySubsequences: false).count)
        cursorLine.wrappedValue = min(max(1, cursorLine.wrappedValue), totalLines.wrappedValue)
        cursorColumn.wrappedValue = max(1, cursorColumn.wrappedValue)
    }
}

private extension AppTheme {
    static func epistemosSourceTheme(for theme: EpistemosTheme) -> AppTheme {
        switch theme {
        case .tan, .sunset:
            return .SolarizedLight
        case .ember:
            return .SolarizedDark
        case .nocturne:
            return .NightOwl
        case .oled, .oledSoft, .systemDark, .platinumVioletDark:
            return .XcodeDark
        case .systemLight, .light, .sunny, .platinumViolet:
            return .GitHubLight
        }
    }
}
#endif

enum MarkEditCoreEditorMode: Equatable {
    case code(language: String)
    case markdownChrome

    var configMode: String {
        switch self {
        case .code:
            return "code"
        case .markdownChrome:
            return "markdown"
        }
    }

    var configCodeLanguage: String? {
        switch self {
        case .code(let language):
            return language
        case .markdownChrome:
            return nil
        }
    }

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
    var selectionRequest: CoreEditorSelectionRequest?

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
        configuration.userContentController.addScriptMessageHandler(
            context.coordinator,
            contentWorld: .page,
            name: MarkEditCoreEditorBridge.nativeMessageHandlerName
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
        let sourceDefaults = MarkEditCoreEditorSourceDefaults.current(
            mode: mode,
            theme: theme,
            fallbackFontSize: fontSize
        )
        MarkEditCoreEditorState(
            text: text,
            mode: mode,
            themeName: sourceDefaults.themeName,
            fontFace: sourceDefaults.fontFace,
            fontSize: sourceDefaults.fontSize,
            lineHeight: sourceDefaults.lineHeight,
            wrapLines: wrapLines,
            showLineNumbers: showLineNumbers,
            showInvisibles: showInvisibles,
            useSpaces: useSpaces,
            tabWidth: tabWidth
        )
    }
}

private struct MarkEditCoreEditorSourceDefaults: Equatable {
    let themeName: String
    let fontFace: WebFontFace
    let fontSize: Double
    let lineHeight: Double

    static func current(
        mode: MarkEditCoreEditorMode,
        theme: EpistemosTheme,
        fallbackFontSize: Double
    ) -> MarkEditCoreEditorSourceDefaults {
        MarkEditCoreEditorSourceDefaults(
            themeName: themeName(for: theme),
            fontFace: fontFace(for: mode),
            fontSize: fontSize(for: mode, fallbackFontSize: fallbackFontSize),
            lineHeight: lineHeight
        )
    }

    private static func themeName(for theme: EpistemosTheme) -> String {
        #if canImport(MarkEditKit)
        AppTheme.epistemosSourceTheme(for: theme).editorTheme
        #else
        theme.isDark ? "xcode-dark" : "xcode-light"
        #endif
    }

    private static func fontFace(for mode: MarkEditCoreEditorMode) -> WebFontFace {
        #if canImport(MarkEditKit)
        if mode == .markdownChrome {
            return AppPreferences.Editor.fontStyle.webFontFace
        }
        #endif
        return WebFontFace(family: "SF Mono", weight: nil, style: nil)
    }

    private static func fontSize(for mode: MarkEditCoreEditorMode, fallbackFontSize: Double) -> Double {
        #if canImport(MarkEditKit)
        if mode == .markdownChrome {
            return AppPreferences.Editor.fontSize
        }
        #endif
        return max(8, min(fallbackFontSize, 32))
    }

    private static var lineHeight: Double {
        #if canImport(MarkEditKit)
        AppPreferences.Editor.lineHeight.multiplier
        #else
        1.5
        #endif
    }
}

private final class MarkEditCoreEditorCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKScriptMessageHandlerWithReply {
    var text: Binding<String>
    var cursorLine: Binding<Int>
    var cursorColumn: Binding<Int>
    var totalLines: Binding<Int>
    weak var webView: WKWebView?

    private var hasLoadedEditor = false
    private var pendingState: MarkEditCoreEditorState?
    private var loadingState: MarkEditCoreEditorState?
    private var lastAppliedState: MarkEditCoreEditorState?
    private var lastSelectionRequestID: UUID?
    private var isApplyingFromSwift = false
    private var loadGeneration = 0

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
        loadGeneration += 1
        hasLoadedEditor = false
        pendingState = nil
        loadingState = initialState
        lastAppliedState = nil
        lastSelectionRequestID = nil
        isApplyingFromSwift = false
        let html = MarkEditCoreEditorDocument.html(for: initialState)
        webView.loadHTMLString(html, baseURL: MarkEditCoreEditorBridge.baseURL)
    }

    func detach(from webView: WKWebView) {
        loadGeneration += 1
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
        hasLoadedEditor = false
        pendingState = nil
        loadingState = nil
        lastAppliedState = nil
        lastSelectionRequestID = nil
        isApplyingFromSwift = false
    }

    func update(
        webView: WKWebView,
        state: MarkEditCoreEditorState,
        selectionRequest: CoreEditorSelectionRequest?
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
        resetEditor(to: state, in: webView, documentChanged: false)
    }

    private func resetEditor(
        to state: MarkEditCoreEditorState,
        in webView: WKWebView,
        documentChanged: Bool
    ) {
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
            guard let self, generation == self.loadGeneration else { return }
            self.isApplyingFromSwift = false
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

    private func waitForCoreEditorReady(
        in webView: WKWebView,
        generation: Int,
        attempt: Int = 0
    ) {
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
                  !self.hasLoadedEditor else { return }

            if (result as? Bool) == true {
                self.finishLoadingEditor(in: webView)
                return
            }

            guard attempt < 160 else {
                self.showLoadFailure(in: webView, message: "MarkEdit CoreEditor failed to load. Check CoreEditor chunks, the chunk-loader scheme, and the MarkEdit native bridge.")
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak webView] in
                guard let self,
                      let webView,
                      generation == self.loadGeneration,
                      !self.hasLoadedEditor else { return }
                self.waitForCoreEditorReady(in: webView, generation: generation, attempt: attempt + 1)
            }
        }
    }

    private func finishLoadingEditor(in webView: WKWebView) {
        hasLoadedEditor = true
        installSnapshotBridge(into: webView)
        let state = pendingState ?? loadingState
        pendingState = nil
        loadingState = nil
        if let state {
            resetEditor(to: state, in: webView, documentChanged: true)
        }
    }

    private func showLoadFailure(in webView: WKWebView, message: String) {
        hasLoadedEditor = false
        isApplyingFromSwift = false
        let messageJSON = message.jsonString ?? "\"MarkEdit CoreEditor failed to load.\""
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
        waitForCoreEditorReady(in: webView, generation: loadGeneration)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
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

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
    ) {
        guard message.name == MarkEditCoreEditorBridge.nativeMessageHandlerName,
              message.frameInfo.isMainFrame else {
            replyHandler(nil, nil)
            return
        }
        replyHandler(nil, nil)
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

struct MarkEditCoreEditorState: Equatable {
    let text: String
    let mode: MarkEditCoreEditorMode
    let themeName: String
    let fontFace: WebFontFace
    let fontSize: Double
    let lineHeight: Double
    let wrapLines: Bool
    let showLineNumbers: Bool
    let showInvisibles: Bool
    let useSpaces: Bool
    let tabWidth: Int

    func resetMessageJSON(documentChanged: Bool) -> String? {
        MarkEditCoreEditorResetMessage(
            text: text,
            selectionRange: nil,
            documentChanged: documentChanged
        ).jsonString
    }

    var configJSON: String? {
        MarkEditCoreEditorConfig(
            text: text,
            theme: themeName,
            fontFace: fontFace,
            fontSize: fontSize,
            showLineNumbers: showLineNumbers,
            showActiveLineIndicator: true,
            invisiblesBehavior: showInvisibles ? "always" : "never",
            readOnlyMode: false,
            typewriterMode: false,
            focusMode: false,
            lineWrapping: wrapLines,
            lineHeight: lineHeight,
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
            searchNormalizers: nil,
            epistemosMode: mode.configMode,
            epistemosCodeLanguage: mode.configCodeLanguage
        ).jsonString
    }

    func replacingText(_ nextText: String) -> MarkEditCoreEditorState {
        MarkEditCoreEditorState(
            text: nextText,
            mode: mode,
            themeName: themeName,
            fontFace: fontFace,
            fontSize: fontSize,
            lineHeight: lineHeight,
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
    let epistemosMode: String
    let epistemosCodeLanguage: String?
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
