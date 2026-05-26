import SwiftUI
import WebKit

nonisolated enum WebKitCodeEditorBridge {
    static let messageHandlerName = "epistemosCodeEditor"
}

nonisolated enum WebKitCodeEditorPolicy {
    static let maxRenderedGutterLines = 20_000
    static let maxSyntaxHighlightCharacters = 250_000
    static let changeDebounceMilliseconds = 120
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
            selectionRequest: selectionRequest
        )
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: WebKitCodeEditorBridge.messageHandlerName
        )
        coordinator.webView = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var text: Binding<String>
        var cursorLine: Binding<Int>
        var cursorColumn: Binding<Int>
        var totalLines: Binding<Int>
        weak var webView: WKWebView?

        private var hasLoadedEditor = false
        private var pendingState: WebKitCodeEditorState?
        private var lastAppliedState: WebKitCodeEditorState?
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

        func loadEditor(into webView: WKWebView) {
            webView.loadHTMLString(WebKitCodeEditorDocument.html, baseURL: nil)
        }

        func update(
            webView: WKWebView,
            text: String,
            language: String,
            theme: EpistemosTheme,
            fontSize: Double,
            wrapLines: Bool,
            selectionRequest: WebKitCodeEditorSelectionRequest?
        ) {
            let state = WebKitCodeEditorState(
                text: text,
                language: language,
                theme: theme.isDark ? "dark" : "light",
                fontSize: max(8, min(fontSize, 32)),
                wrapLines: wrapLines
            )
            if hasLoadedEditor {
                apply(state: state, to: webView)
                apply(selectionRequest: selectionRequest, to: webView)
            } else {
                pendingState = state
            }
        }

        private func apply(state: WebKitCodeEditorState, to webView: WKWebView) {
            guard state != lastAppliedState else { return }
            lastAppliedState = state
            guard let json = state.jsonString else { return }
            isApplyingFromSwift = true
            webView.evaluateJavaScript("window.epistemosCodeEditor.setState(\(json));") { [weak self] _, _ in
                self?.isApplyingFromSwift = false
            }
        }

        private func apply(selectionRequest: WebKitCodeEditorSelectionRequest?, to webView: WKWebView) {
            guard let selectionRequest,
                  selectionRequest.id != lastSelectionRequestID else { return }
            lastSelectionRequestID = selectionRequest.id
            let location = max(0, selectionRequest.range.location)
            let length = max(0, selectionRequest.range.length)
            webView.evaluateJavaScript("window.epistemosCodeEditor.selectRange(\(location), \(length));")
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            hasLoadedEditor = true
            if let pendingState {
                apply(state: pendingState, to: webView)
                self.pendingState = nil
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.request.url?.scheme == "about" {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == WebKitCodeEditorBridge.messageHandlerName,
                  message.frameInfo.isMainFrame,
                  let payload = message.body as? [String: Any],
                  let kind = payload["kind"] as? String else { return }

            switch kind {
            case "ready":
                if let webView {
                    hasLoadedEditor = true
                    let state = pendingState ?? lastAppliedState
                    pendingState = nil
                    if let state {
                        lastAppliedState = nil
                        apply(state: state, to: webView)
                    }
                }
            case "change":
                guard !isApplyingFromSwift,
                      let next = payload["text"] as? String else { return }
                text.wrappedValue = next
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
    let fontSize: Double
    let wrapLines: Bool

    var jsonString: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
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
          --muted: #8f98a6;
          --line: #262832;
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
          font-family: ui-monospace, "SF Mono", Menlo, Monaco, Consolas, monospace;
        }

        .shell {
          display: grid;
          grid-template-columns: 54px minmax(0, 1fr);
          width: 100%;
          height: 100%;
          background: var(--bg);
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

        .editor-wrap {
          position: relative;
          overflow: hidden;
          min-width: 0;
        }

        #highlight {
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
        }

        #highlight.wrap {
          white-space: pre-wrap;
          overflow-wrap: anywhere;
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
          overflow: auto;
          background: transparent;
          color: transparent;
          -webkit-text-fill-color: transparent;
          caret-color: #2f6df6;
          font: inherit;
          line-height: 1.45;
          tab-size: 4;
          white-space: pre;
        }

        #source.wrap {
          white-space: pre-wrap;
          overflow-wrap: anywhere;
        }

        #source::selection {
          background: var(--selection);
        }

        body.plain-source #highlight {
          display: none;
        }

        body.plain-source #source {
          color: var(--fg);
          -webkit-text-fill-color: var(--fg);
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
          <textarea id="source" spellcheck="false" autocorrect="off" autocapitalize="off"></textarea>
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
          let lastText = '';
          let sendTimer = 0;

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
            const value = source.value || '';
            const tooLarge = value.length > maxSyntaxHighlightCharacters;
            document.body.classList.toggle('plain-source', tooLarge);
            if (tooLarge) {
              highlightCode.textContent = '';
              return;
            }
            const activeLine = cursorInfo().line;
            const specs = syntaxSpecs(languageMode());
            const lines = value.split('\\n');
            highlightCode.innerHTML = lines.map((line, index) => {
              const active = index + 1 === activeLine ? ' active' : '';
              return `<span class="line${active}">${highlightLine(line, specs)}</span>`;
            }).join('\\n');
            highlight.scrollTop = source.scrollTop;
            highlight.scrollLeft = source.scrollLeft;
          }

          function syncScroll() {
            gutter.scrollTop = source.scrollTop;
            highlight.scrollTop = source.scrollTop;
            highlight.scrollLeft = source.scrollLeft;
          }

          function post(payload) {
            window.webkit.messageHandlers.epistemosCodeEditor.postMessage(payload);
          }

          function renderLines() {
            const count = lineCount(source.value);
            let lines = '';
            const rendered = Math.min(count, maxRenderedGutterLines);
            for (let i = 1; i <= rendered; i++) lines += i + '\\n';
            if (count > rendered) lines += '...\\n';
            gutter.textContent = lines;
            const cursor = cursorInfo();
            status.textContent = `Line ${cursor.line}  Col ${cursor.column} · ${count} lines`;
            renderHighlight();
            post({ kind: 'cursor', line: cursor.line, column: cursor.column });
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
            renderLines();
            scheduleChange();
          });
          source.addEventListener('scroll', () => {
            syncScroll();
          });
          source.addEventListener('keyup', renderLines);
          source.addEventListener('mouseup', renderLines);
          source.addEventListener('select', renderLines);

          window.epistemosCodeEditor = {
            setState(state) {
              document.documentElement.dataset.theme = state.theme || 'light';
              document.documentElement.dataset.language = state.language || 'plain';
              source.style.fontSize = `${state.fontSize || 15}px`;
              gutter.style.fontSize = `${Math.max(10, (state.fontSize || 15) - 3)}px`;
              source.classList.toggle('wrap', !!state.wrapLines);
              highlight.classList.toggle('wrap', !!state.wrapLines);
              if (source.value !== state.text) {
                source.value = state.text || '';
                lastText = source.value;
                renderLines();
              } else {
                renderHighlight();
              }
            },
            selectRange(location, length) {
              const start = Math.max(0, Math.min(source.value.length, location));
              const end = Math.max(start, Math.min(source.value.length, start + length));
              source.focus();
              source.setSelectionRange(start, end);
              renderLines();
            }
          };

          post({ kind: 'ready' });
        })();
      </script>
    </body>
    </html>
    """
}
