import AppKit
import SwiftUI
import WebKit


nonisolated enum WebKitCodeEditorBridge {
    static let messageHandlerName = "epistemosCodeEditor"
}

nonisolated enum WebKitCodeEditorPolicy {
    static let maxRenderedGutterLines = 20_000
    static let maxSyntaxHighlightCharacters = 120_000
    static let changeDebounceMilliseconds = 120
    static let highlightDebounceMilliseconds = 80
}

struct WebKitCodeEditorSelectionRequest: Equatable {
    let id = UUID()
    let range: NSRange
}


struct WebKitCodeEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var cursorLine: Int
    @Binding var cursorColumn: Int
    @Binding var totalLines: Int

    var language: String
    var theme: EpistemosTheme
    var fontSize: Double
    var wrapLines: Bool
    var showLineNumbers: Bool
    var selectionRequest: WebKitCodeEditorSelectionRequest?

    func makeCoordinator() -> Coordinator {
        Coordinator(
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
            EpdocEditorURLSchemeHandler(),
            forURLScheme: epdocEditorURLScheme
        )
        configuration.userContentController.add(
            context.coordinator,
            name: WebKitCodeEditorBridge.messageHandlerName
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        context.coordinator.loadEditor(into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.cursorLine = $cursorLine
        context.coordinator.cursorColumn = $cursorColumn
        context.coordinator.totalLines = $totalLines
        context.coordinator.update(
            webView: webView,
            text: text,
            language: language,
            theme: theme,
            fontSize: fontSize,
            wrapLines: wrapLines,
            showLineNumbers: showLineNumbers,
            selectionRequest: selectionRequest
        )
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.detach(from: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var text: Binding<String>
        var cursorLine: Binding<Int>
        var cursorColumn: Binding<Int>
        var totalLines: Binding<Int>
        weak var webView: WKWebView?

        private var hasLoadedEditor = false
        private var pendingState: WebKitCodeEditorState?
        private var pendingSelectionRequest: WebKitCodeEditorSelectionRequest?
        private var lastAppliedState: WebKitCodeEditorState?
        private var lastSelectionRequestID: UUID?
        private var isApplyingFromSwift = false
        private var isDetached = false
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

        func loadEditor(into webView: WKWebView) {
            isDetached = false
            loadGeneration += 1
            hasLoadedEditor = false
            pendingState = nil
            pendingSelectionRequest = nil
            lastAppliedState = nil
            lastSelectionRequestID = nil
            isApplyingFromSwift = false
            if let url = URL(string: "\(epdocEditorURLScheme):///code-editor.html") {
                webView.load(URLRequest(url: url))
            } else {
                webView.loadHTMLString(WebKitCodeEditorDocument.html, baseURL: nil)
            }
        }

        func detach(from webView: WKWebView) {
            isDetached = true
            loadGeneration += 1
            hasLoadedEditor = false
            pendingState = nil
            pendingSelectionRequest = nil
            isApplyingFromSwift = false
            webView.navigationDelegate = nil
            webView.configuration.userContentController.removeScriptMessageHandler(
                forName: WebKitCodeEditorBridge.messageHandlerName
            )
            webView.stopLoading()
            self.webView = nil
            lastAppliedState = nil
            lastSelectionRequestID = nil
        }

        func update(
            webView: WKWebView,
            text: String,
            language: String,
            theme: EpistemosTheme,
            fontSize: Double,
            wrapLines: Bool,
            showLineNumbers: Bool,
            selectionRequest: WebKitCodeEditorSelectionRequest?
        ) {
            guard !isDetached else { return }
            let palette = WebKitCodeEditorPalette(theme: theme)
            let state = WebKitCodeEditorState(
                text: text,
                language: language,
                theme: theme.isDark ? "dark" : "light",
                backgroundColor: palette.background.cssColorString,
                foregroundColor: palette.foreground.cssColorString,
                mutedColor: palette.muted.cssColorString,
                lineColor: palette.border.cssColorString,
                gutterColor: palette.gutter.cssColorString,
                selectionColor: palette.accent.cssColorString(opacity: theme.isDark ? 0.28 : 0.22),
                cursorLineColor: palette.accent.cssColorString(opacity: theme.isDark ? 0.10 : 0.08),
                accentColor: palette.accent.cssColorString,
                caretColor: palette.accent.cssColorString,
                fontSize: max(8, min(fontSize, 32)),
                wrapLines: wrapLines,
                showLineNumbers: showLineNumbers
            )
            if hasLoadedEditor, !webView.isLoading {
                apply(state: state, to: webView)
                apply(selectionRequest: selectionRequest, to: webView)
            } else {
                pendingState = state
                pendingSelectionRequest = selectionRequest
            }
        }

        private func apply(state: WebKitCodeEditorState, to webView: WKWebView) {
            guard !isDetached, hasLoadedEditor, !webView.isLoading else {
                pendingState = state
                return
            }
            guard state != lastAppliedState else { return }
            guard let json = state.jsonString else { return }
            let generation = loadGeneration
            let previousState = lastAppliedState
            isApplyingFromSwift = true
            let script = """
            (() => {
              if (!window.epistemosCodeEditor?.setState) { return false; }
              window.epistemosCodeEditor.setState(\(json));
              return true;
            })();
            """
            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self,
                      generation == self.loadGeneration,
                      !self.isDetached else { return }
                self.isApplyingFromSwift = false
                if error == nil, result as? Bool == true {
                    self.lastAppliedState = state
                } else {
                    self.lastAppliedState = previousState
                    self.pendingState = state
                }
            }
        }

        private func apply(selectionRequest: WebKitCodeEditorSelectionRequest?, to webView: WKWebView) {
            guard !isDetached, hasLoadedEditor, !webView.isLoading else {
                pendingSelectionRequest = selectionRequest
                return
            }
            guard let selectionRequest,
                  selectionRequest.id != lastSelectionRequestID else { return }
            let location = max(0, selectionRequest.range.location)
            let length = max(0, selectionRequest.range.length)
            let generation = loadGeneration
            let script = """
            (() => {
              if (!window.epistemosCodeEditor?.selectRange) { return false; }
              window.epistemosCodeEditor.selectRange(\(location), \(length));
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

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            guard !isDetached else { return }
            hasLoadedEditor = true
            flushPendingState(in: webView)
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
            // Content process crashed (OOM / renderer fault) — the code editor blanks. Log for crash
            // telemetry. Auto-recovery (reset + reload) is deferred pending per-editor data-loss
            // verification: a naive reload can autosave-overwrite with empty content (analyzed for the
            // Epdoc editor) — see the SS-FOLLOWON ledger.
            Log.notes.error(
                "Code editor web content process terminated \u{2014} editor blanked; reopen to recover")
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
            let scheme = navigationAction.request.url?.scheme
            if scheme == "about" || scheme == epdocEditorURLScheme {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard !isDetached,
                  message.name == WebKitCodeEditorBridge.messageHandlerName,
                  message.frameInfo.isMainFrame,
                  let payload = message.body as? [String: Any],
                  let kind = payload["kind"] as? String else { return }

            switch kind {
            case "ready":
                if let webView, !webView.isLoading {
                    hasLoadedEditor = true
                    flushPendingState(in: webView)
                }
            case "change":
                guard !isApplyingFromSwift,
                      let next = payload["text"] as? String else { return }
                text.wrappedValue = next
                if let applied = lastAppliedState {
                    lastAppliedState = applied.replacingText(next)
                }
                if let lineCount = payload["lineCount"] as? Int {
                    totalLines.wrappedValue = max(1, lineCount)
                }
                if let line = payload["line"] as? Int {
                    cursorLine.wrappedValue = max(1, line)
                }
                if let column = payload["column"] as? Int {
                    cursorColumn.wrappedValue = max(1, column)
                }
            case "cursor":
                if let line = payload["line"] as? Int {
                    cursorLine.wrappedValue = max(1, line)
                }
                if let column = payload["column"] as? Int {
                    cursorColumn.wrappedValue = max(1, column)
                }
            default:
                return
            }
        }
    }
}

private struct WebKitCodeEditorState: Equatable, Encodable {
    let text: String
    let language: String
    let theme: String
    let backgroundColor: String
    let foregroundColor: String
    let mutedColor: String
    let lineColor: String
    let gutterColor: String
    let selectionColor: String
    let cursorLineColor: String
    let accentColor: String
    let caretColor: String
    let fontSize: Double
    let wrapLines: Bool
    let showLineNumbers: Bool

    var jsonString: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func replacingText(_ nextText: String) -> WebKitCodeEditorState {
        WebKitCodeEditorState(
            text: nextText,
            language: language,
            theme: theme,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            mutedColor: mutedColor,
            lineColor: lineColor,
            gutterColor: gutterColor,
            selectionColor: selectionColor,
            cursorLineColor: cursorLineColor,
            accentColor: accentColor,
            caretColor: caretColor,
            fontSize: fontSize,
            wrapLines: wrapLines,
            showLineNumbers: showLineNumbers
        )
    }
}

private struct WebKitCodeEditorPalette {
    let background: NSColor
    let gutter: NSColor
    let foreground: NSColor
    let muted: NSColor
    let border: NSColor
    let accent: NSColor

    init(theme: EpistemosTheme) {
        let surfaceTheme = theme.surfaceVariant(.other)
        let base = MarkdownPreviewSurfaceStyle
            .canvasNSColor(for: surfaceTheme)
            .rgbSafeForCodeEditorTheme()
            .withAlphaComponent(1.0)
        let foreground = (surfaceTheme.isDark
            ? NSColor(deviceWhite: 0.95, alpha: 1.0)
            : surfaceTheme.resolved.foreground.nsColor
        ).rgbSafeForCodeEditorTheme()
        let muted = (surfaceTheme.isDark
            ? NSColor(deviceWhite: 0.78, alpha: 1.0)
            : surfaceTheme.resolved.mutedForeground.nsColor
        ).rgbSafeForCodeEditorTheme()
        let accent = surfaceTheme.resolved.accent.nsColor.rgbSafeForCodeEditorTheme()
        let border = (surfaceTheme.isDark
            ? accent.withAlphaComponent(0.18)
            : surfaceTheme.resolved.glassBorder.nsColor.withAlphaComponent(0.42)
        ).rgbSafeForCodeEditorTheme()

        self.background = base
        self.gutter = base.editorSidebarTint(isDark: surfaceTheme.isDark)
        self.foreground = Self.readable(foreground, on: base)
        self.muted = Self.readable(muted, on: self.gutter).withAlphaComponent(0.80)
        self.border = border
        self.accent = accent
    }

    private static func readable(_ preferred: NSColor, on background: NSColor) -> NSColor {
        if preferred.contrastRatio(against: background) >= 4.5 {
            return preferred
        }
        return (background.relativeLuminance < 0.46
            ? NSColor(deviceWhite: 0.92, alpha: 1.0)
            : NSColor(deviceWhite: 0.12, alpha: 1.0))
            .rgbSafeForCodeEditorTheme()
    }
}

private extension NSColor {
    var cssColorString: String {
        EpistemosWebThemeCSS.color(self)
    }

    func cssColorString(opacity overrideOpacity: CGFloat?) -> String {
        EpistemosWebThemeCSS.color(self, opacity: overrideOpacity)
    }

    func editorSidebarTint(isDark: Bool) -> NSColor {
        let tintSource: NSColor = isDark ? .white : .black
        let fraction: CGFloat = isDark ? 0.055 : 0.045
        return (blended(withFraction: fraction, of: tintSource) ?? self)
            .rgbSafeForCodeEditorTheme()
            .withAlphaComponent(1.0)
    }

    var relativeLuminance: CGFloat {
        let color = usingColorSpace(.sRGB) ?? self
        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.03928
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }
        return (0.2126 * channel(color.redComponent))
            + (0.7152 * channel(color.greenComponent))
            + (0.0722 * channel(color.blueComponent))
    }

    func contrastRatio(against other: NSColor) -> CGFloat {
        let first = relativeLuminance
        let second = other.relativeLuminance
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

nonisolated enum WebKitCodeEditorDocument {
    static let html = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
      <style>
        :root {
          color-scheme: light;
          --bg: #fbfbfb;
          --fg: #202124;
          --muted: #8b929c;
          --line: #eef0f3;
          --gutter: #f7f8fa;
          --selection: rgba(46, 111, 246, 0.22);
          --cursor-line: rgba(46, 111, 246, 0.08);
          --keyword: #8a3ffc;
          --string: #c4492d;
          --comment: #7a8594;
          --number: #1f7a5f;
          --type: #0b66c3;
          --property: #8b5a00;
        }

        html[data-theme="dark"] {
          color-scheme: dark;
          --bg: #15161b;
          --fg: #f2f3f5;
          --muted: #c8ced8;
          --line: rgba(138, 168, 255, 0.16);
          --gutter: #111218;
          --selection: rgba(112, 151, 255, 0.28);
          --cursor-line: rgba(112, 151, 255, 0.10);
          --number: #73c7a4;
          --type: #7bb7ff;
          --property: #dfb565;
        }

        html, body {
          margin: 0;
          width: 100%;
          height: 100%;
          overflow: hidden;
          background: var(--bg);
          color: var(--fg);
          font-family: Menlo, "SF Mono", "SFMono-Regular", Monaco, ui-monospace, Consolas, monospace;
          font-size: 15px;
          font-weight: 540;
          -webkit-font-smoothing: subpixel-antialiased;
          text-rendering: optimizeLegibility;
        }

        .shell {
          display: grid;
          grid-template-columns: 54px minmax(0, 1fr);
          width: 100%;
          height: 100%;
          background: var(--bg);
        }

        body.hide-gutter .shell {
          grid-template-columns: minmax(0, 1fr);
        }

        body.hide-gutter #gutter {
          display: none;
        }

        #gutter {
          overflow: hidden;
          user-select: none;
          background: var(--gutter);
          color: var(--muted);
          border-right: 1px solid var(--line);
          padding: 12px 8px 12px 0;
          text-align: right;
          box-sizing: border-box;
          white-space: pre;
          line-height: 1.45;
          font-variant-numeric: tabular-nums;
        }

        html[data-theme="dark"] #gutter {
          border-right: 0;
          box-shadow: inset -1px 0 rgba(138, 168, 255, 0.14);
          color: var(--muted);
        }

        .editor-wrap {
          position: relative;
          overflow: hidden;
          min-width: 0;
        }

        #highlight {
          display: none;
          position: absolute;
          inset: 0;
          margin: 0;
          padding: 12px 18px 32px 18px;
          box-sizing: border-box;
          overflow: hidden;
          pointer-events: none;
          color: var(--fg);
          line-height: 1.45;
          font: inherit;
          tab-size: 4;
          white-space: pre;
          word-break: normal;
          overflow-wrap: normal;
        }

        #highlight.wrap {
          white-space: pre-wrap;
          overflow-wrap: anywhere;
        }

        #highlight-code {
          display: block;
          min-width: 100%;
          width: max-content;
          box-sizing: border-box;
        }

        #highlight.wrap #highlight-code {
          width: auto;
        }

        #highlight .line {
          display: block;
          min-height: 1.45em;
        }

        #highlight .line.active {
          background: var(--cursor-line);
          box-shadow: -18px 0 0 var(--cursor-line), 18px 0 0 var(--cursor-line);
        }

        #highlight .keyword { color: var(--keyword); font-weight: 650; }
        #highlight .string { color: var(--string); }
        #highlight .comment { color: var(--comment); font-style: italic; }
        #highlight .number { color: var(--number); }
        #highlight .type { color: var(--type); }
        #highlight .property { color: var(--property); }

        #source {
          position: absolute;
          inset: 0;
          width: 100%;
          height: 100%;
          resize: none;
          border: 0;
          outline: none;
          padding: 12px 18px 32px 18px;
          box-sizing: border-box;
          overflow-x: auto;
          overflow-y: auto;
          background: transparent;
          color: var(--fg);
          -webkit-text-fill-color: var(--fg);
          caret-color: #2f6df6;
          font: inherit;
          line-height: 1.45;
          tab-size: 4;
          white-space: pre;
          word-break: normal;
          overflow-wrap: normal;
        }

        #source.wrap {
          white-space: pre-wrap;
          overflow-wrap: anywhere;
        }

        #source::selection {
          background: var(--selection);
        }

        #status {
          position: absolute;
          right: 12px;
          bottom: 8px;
          color: var(--muted);
          font-size: 11px;
          pointer-events: none;
          background: color-mix(in srgb, var(--bg) 86%, transparent);
          border-radius: 7px;
          padding: 3px 7px;
        }
      </style>
    </head>
    <body>
      <main class="shell">
        <pre id="gutter">1</pre>
        <section class="editor-wrap">
          <pre id="highlight" aria-hidden="true"><code id="highlight-code"></code></pre>
          <textarea id="source" spellcheck="false" autocorrect="off" autocapitalize="off" wrap="off"></textarea>
          <div id="status"></div>
        </section>
      </main>
      <script>
        (() => {
          const source = document.getElementById('source');
          const gutter = document.getElementById('gutter');
          const status = document.getElementById('status');
          const highlight = document.getElementById('highlight');
          const highlightCode = document.getElementById('highlight-code');
          const maxRenderedGutterLines = \(WebKitCodeEditorPolicy.maxRenderedGutterLines);
          const maxSyntaxHighlightCharacters = \(WebKitCodeEditorPolicy.maxSyntaxHighlightCharacters);
          const changeDebounceMilliseconds = \(WebKitCodeEditorPolicy.changeDebounceMilliseconds);
          const highlightDebounceMilliseconds = \(WebKitCodeEditorPolicy.highlightDebounceMilliseconds);
          const typingSettleMilliseconds = Math.max(260, highlightDebounceMilliseconds * 4);
          let lastText = '';
          let sendTimer = 0;
          let highlightTimer = 0;
          let editingTimer = 0;
          let lastRenderedLineCount = -1;
          let viewportOverscanLines = 48;

          function lineCount(text) {
            if (!text) return 1;
            let count = 1;
            for (let i = 0; i < text.length; i++) {
              if (text.charCodeAt(i) === 10) count++;
            }
            return count;
          }

          function cursorInfo() {
            const value = source.value;
            const offset = source.selectionStart || 0;
            let line = 1;
            let start = 0;
            for (let i = 0; i < offset; i++) {
              if (value.charCodeAt(i) === 10) {
                line++;
                start = i + 1;
              }
            }
            return { line, column: offset - start + 1 };
          }

          function escapeHTML(value) {
            return value
              .replaceAll('&', '&amp;')
              .replaceAll('<', '&lt;')
              .replaceAll('>', '&gt;');
          }

          function languageMode() {
            const language = (document.documentElement.dataset.language || '').toLowerCase();
            if (language.includes('swift')) return 'swift';
            if (language.includes('javascript') || language.includes('typescript') || language === 'js' || language === 'ts') return 'js';
            if (language.includes('css')) return 'css';
            if (language.includes('html') || language.includes('xml')) return 'html';
            if (language.includes('json')) return 'json';
            return 'plain';
          }

          function syntaxSpecs(mode) {
            const common = [
              { cls: 'comment', priority: 0, re: /\\/\\/.*|\\/\\*.*?\\*\\//g },
              { cls: 'string', priority: 1, re: /"(?:\\\\.|[^"\\\\])*"|'(?:\\\\.|[^'\\\\])*'|`(?:\\\\.|[^`\\\\])*`/g },
              { cls: 'number', priority: 3, re: /\\b\\d+(?:\\.\\d+)?\\b/g }
            ];
            if (mode === 'swift') {
              return common.concat([
                { cls: 'keyword', priority: 2, re: /\\b(actor|any|as|associatedtype|async|await|break|case|catch|class|continue|default|defer|do|else|enum|extension|false|for|func|guard|if|import|in|init|inout|is|let|nil|nonisolated|private|protocol|public|return|self|static|struct|switch|throws|true|try|var|where|while)\\b/g },
                { cls: 'type', priority: 4, re: /\\b[A-Z][A-Za-z0-9_]*\\b/g }
              ]);
            }
            if (mode === 'js') {
              return common.concat([
                { cls: 'keyword', priority: 2, re: /\\b(async|await|break|case|catch|class|const|continue|default|else|export|false|for|from|function|if|import|in|let|new|null|return|switch|this|throw|true|try|typeof|undefined|var|while|yield)\\b/g },
                { cls: 'type', priority: 4, re: /\\b[A-Z][A-Za-z0-9_]*\\b/g }
              ]);
            }
            if (mode === 'css') {
              return common.concat([
                { cls: 'keyword', priority: 2, re: /@[a-zA-Z-]+\\b/g },
                { cls: 'property', priority: 4, re: /\\b[-a-zA-Z]+(?=\\s*:)/g }
              ]);
            }
            if (mode === 'html') {
              return [
                { cls: 'comment', priority: 0, re: /<!--.*?-->/g },
                { cls: 'string', priority: 1, re: /"(?:\\\\.|[^"\\\\])*"|'(?:\\\\.|[^'\\\\])*'/g },
                { cls: 'keyword', priority: 2, re: /<\\/?[A-Za-z][A-Za-z0-9:-]*|\\/?>/g },
                { cls: 'property', priority: 4, re: /\\b[A-Za-z_:][-A-Za-z0-9_:.]*(?=\\s*=)/g }
              ];
            }
            if (mode === 'json') {
              return [
                { cls: 'property', priority: 1, re: /"(?:\\\\.|[^"\\\\])*"(?=\\s*:)/g },
                { cls: 'string', priority: 2, re: /"(?:\\\\.|[^"\\\\])*"/g },
                { cls: 'number', priority: 3, re: /\\b-?\\d+(?:\\.\\d+)?(?:e[+-]?\\d+)?\\b/gi },
                { cls: 'keyword', priority: 4, re: /\\b(true|false|null)\\b/g }
              ];
            }
            return [];
          }

          function lineHeightPixels() {
            const parsed = Number.parseFloat(window.getComputedStyle(source).lineHeight);
            return Number.isFinite(parsed) && parsed > 0 ? parsed : Math.max(1, (Number.parseFloat(source.style.fontSize) || 15) * 1.45);
          }

          function visibleLineWindow(lines) {
            if (source.classList.contains('wrap')) {
              return { start: 0, end: lines.length, topPad: 0, bottomPad: 0 };
            }
            const lineHeight = lineHeightPixels();
            const first = Math.max(0, Math.floor(source.scrollTop / lineHeight) - viewportOverscanLines);
            const visibleCount = Math.ceil(source.clientHeight / lineHeight) + viewportOverscanLines * 2;
            const end = Math.min(lines.length, first + Math.max(1, visibleCount));
            return {
              start: first,
              end,
              topPad: first * lineHeight,
              bottomPad: Math.max(0, (lines.length - end) * lineHeight)
            };
          }

          function highlightLine(line, specs) {
            if (specs.length === 0) return escapeHTML(line) || '&#8203;';
            const spans = [];
            for (const spec of specs) {
              spec.re.lastIndex = 0;
              let match;
              while ((match = spec.re.exec(line)) !== null) {
                if (match[0].length === 0) {
                  spec.re.lastIndex += 1;
                  continue;
                }
                spans.push({
                  start: match.index,
                  end: match.index + match[0].length,
                  cls: spec.cls,
                  priority: spec.priority
                });
              }
            }
            spans.sort((a, b) => a.start - b.start || a.priority - b.priority || b.end - a.end);
            let html = '';
            let cursor = 0;
            for (const span of spans) {
              if (span.start < cursor) continue;
              html += escapeHTML(line.slice(cursor, span.start));
              html += `<span class="${span.cls}">${escapeHTML(line.slice(span.start, span.end))}</span>`;
              cursor = span.end;
            }
            html += escapeHTML(line.slice(cursor));
            return html || '&#8203;';
          }

          function renderHighlight() {
            return;
            const value = source.value || '';
            const tooLarge = value.length > maxSyntaxHighlightCharacters;
            document.body.classList.toggle('plain-source', tooLarge);
            if (tooLarge) {
              highlightCode.textContent = '';
              return;
            }
            document.body.classList.remove('editing');
            const activeLine = cursorInfo().line;
            const specs = syntaxSpecs(languageMode());
            const lines = value.split('\\n');
            const windowInfo = visibleLineWindow(lines);
            const renderedLines = lines.slice(windowInfo.start, windowInfo.end);
            highlightCode.style.paddingTop = `${windowInfo.topPad}px`;
            highlightCode.style.paddingBottom = `${windowInfo.bottomPad}px`;
            highlightCode.innerHTML = renderedLines.map((line, index) => {
              const lineNumber = windowInfo.start + index + 1;
              const active = lineNumber === activeLine ? ' active' : '';
              return `<span class="line${active}">${highlightLine(line, specs)}</span>`;
            }).join('\\n');
            highlight.scrollTop = source.scrollTop;
            highlight.scrollLeft = source.scrollLeft;
          }

          function scheduleHighlight(delay = highlightDebounceMilliseconds) {
            window.clearTimeout(highlightTimer);
          }

          function syncScroll() {
            gutter.scrollTop = source.scrollTop;
            highlight.scrollTop = source.scrollTop;
            highlight.scrollLeft = source.scrollLeft;
          }

          function post(payload) {
            window.webkit.messageHandlers.epistemosCodeEditor.postMessage(payload);
          }

          function renderStatus(rebuildGutter = false) {
            const count = lineCount(source.value);
            if (rebuildGutter || count !== lastRenderedLineCount) {
              let lines = '';
              const rendered = Math.min(count, maxRenderedGutterLines);
              for (let i = 1; i <= rendered; i++) lines += i + '\\n';
              if (count > rendered) lines += '...\\n';
              gutter.textContent = lines;
              lastRenderedLineCount = count;
            }
            const cursor = cursorInfo();
            status.textContent = `Line ${cursor.line}  Col ${cursor.column} · ${count} lines`;
            post({ kind: 'cursor', line: cursor.line, column: cursor.column });
          }

          function enterTypingMode() {
            if (source.value.length > maxSyntaxHighlightCharacters) return;
            document.body.classList.add('editing');
            window.clearTimeout(editingTimer);
            editingTimer = window.setTimeout(() => {
              document.body.classList.remove('editing');
            }, typingSettleMilliseconds);
          }

          function scheduleChange() {
            window.clearTimeout(sendTimer);
            sendTimer = window.setTimeout(() => {
              lastText = source.value;
              const cursor = cursorInfo();
              post({
                kind: 'change',
                text: source.value,
                lineCount: lineCount(source.value),
                line: cursor.line,
                column: cursor.column
              });
            }, changeDebounceMilliseconds);
          }

          source.addEventListener('input', () => {
            renderStatus(false);
            enterTypingMode();
            scheduleChange();
          });
          source.addEventListener('scroll', () => {
            syncScroll();
            scheduleHighlight(20);
          });
          source.addEventListener('keyup', () => {
            renderStatus(false);
          });
          source.addEventListener('mouseup', () => {
            renderStatus(false);
            scheduleHighlight(20);
          });
          source.addEventListener('select', () => {
            renderStatus(false);
            scheduleHighlight(20);
          });

          window.epistemosCodeEditor = {
            setState(state) {
              document.documentElement.dataset.theme = state.theme || 'light';
              document.documentElement.dataset.language = state.language || 'plain';
              const rootStyle = document.documentElement.style;
              const setVar = (name, value) => {
                if (value) rootStyle.setProperty(name, value);
              };
              setVar('--bg', state.backgroundColor);
              setVar('--fg', state.foregroundColor);
              setVar('--muted', state.mutedColor);
              setVar('--line', state.lineColor);
              setVar('--gutter', state.gutterColor);
              setVar('--selection', state.selectionColor);
              setVar('--cursor-line', state.cursorLineColor);
              setVar('--keyword', state.accentColor);
              setVar('--type', state.accentColor);
              setVar('--property', state.accentColor);
              source.style.caretColor = state.caretColor || '#2f6df6';
              source.style.fontSize = `${state.fontSize || 15}px`;
              gutter.style.fontSize = `${Math.max(10, (state.fontSize || 15) - 3)}px`;
              source.classList.toggle('wrap', !!state.wrapLines);
              highlight.classList.toggle('wrap', !!state.wrapLines);
              source.setAttribute('wrap', state.wrapLines ? 'soft' : 'off');
              document.body.classList.toggle('hide-gutter', !state.showLineNumbers);
              if (source.value !== state.text) {
                source.value = state.text || '';
                lastText = source.value;
                renderStatus(true);
                scheduleHighlight(0);
              } else {
                renderStatus(false);
                if (!document.body.classList.contains('editing')) {
                  scheduleHighlight(0);
                }
              }
            },
            selectRange(location, length) {
              const start = Math.max(0, Math.min(source.value.length, location));
              const end = Math.max(start, Math.min(source.value.length, start + length));
              source.focus();
              source.setSelectionRange(start, end);
              renderStatus(false);
              scheduleHighlight(0);
            }
          };

          post({ kind: 'ready' });
        })();
      </script>
    </body>
    </html>
    """
}
