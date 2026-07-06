#if EPISTEMOS_APP_STORE
import AppKit
import SwiftUI
import WebKit
import os

/// The MAS Agent room: the real vendored June web UI in a WKWebView, backed by
/// the in-process agent_core/local-engine gateway (Plan 1-MAS §1-§3).
///
/// Instant-open recipe (perf doctrine §1): the WKWebView + bridge live in a
/// process-lifetime holder — created eagerly on first mount, NEVER torn down
/// on tab-switch — with a placeholder shown until the SPA paints.
@MainActor
final class JuneAgentSurfaceHolder {
    static let shared = JuneAgentSurfaceHolder()

    private static let log = Logger(subsystem: "com.epistemos", category: "JuneAgentSurface")

    private(set) var webView: WKWebView?
    private(set) var bridge: JuneAgentBridge?
    private(set) var loadStarted = false
    private(set) var loadStartedAt: Date?
    var failureMessage: String?

    private init() {}

    /// Idempotent: builds the webview + bridge once and starts the load.
    /// `theme` seeds the Epistemos-theme bridge at creation; later switches
    /// re-apply live via `JuneAgentSurfaceView.applyEpistemosTheme(_:)`.
    func ensureStarted(theme: EpistemosTheme) {
        // A prior failed attempt must not shadow a later successful one — the
        // message reflects only the CURRENT attempt (stale-failure bug).
        failureMessage = nil
        guard webView == nil else { return }
        guard let location = JuneWebAssets.resolve() else {
            failureMessage = "The Workspace bundle is missing from this build."
            return
        }
        guard let shimSource = try? String(contentsOf: location.shimURL, encoding: .utf8) else {
            failureMessage = "The Workspace bridge shim could not be loaded."
            return
        }

        let bridge = JuneAgentBridge()
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(JuneSchemeHandler(root: location.distRoot), forURLScheme: JuneSchemeHandler.scheme)

        let ucc = config.userContentController
        // Order matters: host flag first, then persisted-UI seeds, then the shim.
        ucc.addUserScript(WKUserScript(
            source: "window.__EPISTEMOS_HOST__ = true;",
            injectionTime: .atDocumentStart, forMainFrameOnly: false
        ))
        // Read-aloud honest gate: the overlay only injects per-message speak
        // buttons when the shared on-device TTS is actually ready (no fake
        // button when Kokoro isn't installed). Computed native-side.
        ucc.addUserScript(WKUserScript(
            source: "window.__EPISTEMOS_TTS_AVAILABLE__ = \(EpistemosSpeechSynthesizer.isTextToSpeechAvailable() ? "true" : "false");",
            injectionTime: .atDocumentStart, forMainFrameOnly: true
        ))
        // Non-persistent store resets localStorage each launch; June's
        // first-run wizard (dictation/meeting permissions — not part of the
        // agent room) is skipped deterministically. Keys/version from the
        // pinned fork's src/lib/onboarding.ts.
        ucc.addUserScript(WKUserScript(
            source: """
            try {
              localStorage.setItem("june.onboarding.completedVersion", "7");
              localStorage.setItem("june.agent.riskAcknowledged", "true");
            } catch (e) {}
            """,
            injectionTime: .atDocumentStart, forMainFrameOnly: true
        ))
        // FULL Epistemos-theme bridge (owner 2026-07-04: June must visibly
        // match the app's theme — palette + accent, not just color scheme).
        // June's own Appearance picker re-themes the whole SPA from --brand
        // plus a per-scheme neutral ramp, so we override exactly that seam.
        // The localStorage write pins June's theme.ts to an explicit scheme so
        // its prefers-color-scheme listener never fights the bridge.
        ucc.addUserScript(WKUserScript(
            source: """
            window.__EPISTEMOS_THEME_APPLY__ = function (t) {
              try {
                var root = document.documentElement;
                var scheme = t.dark ? "dark" : "light";
                root.setAttribute("data-theme", scheme);
                try { localStorage.setItem("os-june:theme", scheme); } catch (e) {}
                for (var k in t.vars) root.style.setProperty(k, t.vars[k]);
              } catch (e) {}
            };
            window.__EPISTEMOS_THEME_APPLY__(\(JuneThemeBridge.payloadJSON(for: theme)));
            """,
            injectionTime: .atDocumentStart, forMainFrameOnly: true
        ))
        ucc.addUserScript(WKUserScript(source: shimSource, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        // R6 font substitution: June's commercial fonts (Berkeley Mono,
        // ABC Diatype, Martina Plantijn) are never served (scheme handler
        // 404s them); these local() faces keep the literal family names
        // resolving against Apple-bundled equivalents.
        ucc.addUserScript(WKUserScript(
            source: """
            (function () {
              var style = document.createElement("style");
              style.textContent = [
                '@font-face { font-family: "ABC Diatype"; src: local("Helvetica Neue"); font-weight: 400; }',
                '@font-face { font-family: "ABC Diatype"; src: local("Helvetica Neue Medium"); font-weight: 500; }',
                '@font-face { font-family: "Martina Plantijn"; src: local("Iowan Old Style"); }',
                '@font-face { font-family: "Berkeley Mono"; src: local("Menlo-Regular"); font-style: normal; }',
                '@font-face { font-family: "Berkeley Mono"; src: local("Menlo-Italic"); font-style: oblique; }',
              ].join("\\n");
              document.documentElement.appendChild(style);
            })();
            """,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true
        ))
        // Workspace overlay (MAS-only, no June source edits): rebrands visible
        // copy, keeps normal June/system UI fonts for body/sidebar/composer,
        // reserves Matrix Dots for the large landing/page headers, and pins the
        // chat layout fixes requested for light-mode bubbles, composer
        // caret/word wrapping, and sidebar alignment.
        ucc.addUserScript(WKUserScript(
            source: Self.workspaceOverlayScript(),
            injectionTime: .atDocumentEnd, forMainFrameOnly: true
        ))
        // Read-aloud overlay (my injection, NOT June src): adds a speak button
        // to each assistant turn's existing action bar. It only reads the
        // rendered reply text and posts it to the native `epistemosSpeak`
        // handler — NO audio, NO voice model, NO synthesis in JS. Honest gate:
        // nothing is injected unless native TTS is ready.
        ucc.addUserScript(WKUserScript(
            source: """
            (function () {
              // Live gate (not a one-time early-return): the native side updates
              // __EPISTEMOS_TTS_AVAILABLE__ + calls the refresh below when the
              // voice becomes ready mid-session, so read-aloud appears without an
              // app restart.
              function ttsReady() { return window.__EPISTEMOS_TTS_AVAILABLE__ === true; }
              function speak(text) {
                try {
                  window.webkit.messageHandlers.epistemosSpeak.postMessage({ action: "speak", text: text });
                } catch (e) {}
              }
              // Selected-text read-aloud: a floating pill on any selection →
              // posts the selection to native TTS. Reads text only; no audio.
              var pill = null;
              function hidePill() { if (pill) pill.style.display = "none"; }
              function ensurePill() {
                if (pill) return pill;
                pill = document.createElement("button");
                pill.type = "button";
                pill.className = "epistemos-read-selection";
                // Subtle light border so the dark pill stays delineated on
                // June's dark canvas (oklch 16.5% ≈ the pill's own tone) as well
                // as on light — the shadow alone is invisible in dark mode.
                pill.style.cssText = "position:fixed;z-index:2147483647;display:none;align-items:center;gap:6px;padding:5px 10px;border-radius:8px;border:0.5px solid rgba(255,255,255,0.18);background:rgba(30,30,32,0.94);color:#fff;font-size:12px;font-weight:600;cursor:pointer;box-shadow:0 4px 14px rgba(0,0,0,0.28);";
                pill.innerHTML = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M15.5 8.5a5 5 0 0 1 0 7"></path></svg><span>Read aloud</span>';
                pill.addEventListener("mousedown", function (e) { e.preventDefault(); });
                pill.addEventListener("click", function (e) {
                  e.preventDefault();
                  e.stopPropagation();
                  var sel = window.getSelection();
                  var text = sel ? sel.toString().trim() : "";
                  if (text) speak(text);
                  hidePill();
                });
                document.body.appendChild(pill);
                return pill;
              }
              function showSelectionPill() {
                if (!ttsReady()) { hidePill(); return; }
                var sel = window.getSelection();
                var text = sel && sel.rangeCount ? sel.toString().trim() : "";
                if (!text) { hidePill(); return; }
                var rect = sel.getRangeAt(0).getBoundingClientRect();
                if (!rect || (!rect.width && !rect.height)) { hidePill(); return; }
                var p = ensurePill();
                p.style.display = "inline-flex";
                var top = rect.top - 38;
                if (top < 6) top = rect.bottom + 8;
                p.style.top = top + "px";
                p.style.left = Math.max(6, Math.min(rect.left, window.innerWidth - 120)) + "px";
              }
              function setupSelection() {
                document.addEventListener("mouseup", function () { setTimeout(showSelectionPill, 10); });
                document.addEventListener("scroll", hidePill, true);
                document.addEventListener("mousedown", function (e) {
                  if (pill && e.target !== pill && !pill.contains(e.target)) hidePill();
                });
                // Dismiss on ANY deselect, incl. keyboard (arrow keys) — hide
                // only when the selection clears, so it never flickers mid-drag.
                document.addEventListener("selectionchange", function () {
                  var s = window.getSelection();
                  if (!s || !s.toString().trim()) hidePill();
                });
              }
              function addButton(turn) {
                if (!ttsReady()) return;
                if (!turn || turn.querySelector(".epistemos-read-aloud")) return;
                var actions = turn.querySelector(".agent-turn-actions-inner") || turn.querySelector(".agent-turn-actions");
                var body = turn.querySelector(".agent-assistant-turn-body");
                if (!actions || !body) return;
                var btn = document.createElement("button");
                btn.type = "button";
                btn.className = "agent-turn-action epistemos-read-aloud";
                btn.title = "Read aloud";
                btn.setAttribute("aria-label", "Read this reply aloud");
                btn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M15.5 8.5a5 5 0 0 1 0 7"></path><path d="M18.5 5.5a9 9 0 0 1 0 13"></path></svg>';
                btn.addEventListener("click", function (e) {
                  e.preventDefault();
                  e.stopPropagation();
                  var text = (body.innerText || body.textContent || "").trim();
                  if (text) speak(text);
                });
                actions.appendChild(btn);
              }
              function scan(root) {
                if (!root || !root.querySelectorAll) return;
                var turns = root.querySelectorAll(".agent-assistant-turn");
                for (var i = 0; i < turns.length; i++) addButton(turns[i]);
              }
              var obs = new MutationObserver(function (muts) {
                for (var i = 0; i < muts.length; i++) {
                  var nodes = muts[i].addedNodes || [];
                  for (var j = 0; j < nodes.length; j++) {
                    var n = nodes[j];
                    if (n.nodeType !== 1) continue;
                    // The turn container and its action bar / body can mount in
                    // separate ticks — so retry the enclosing turn too, or the
                    // button would be dropped when the container arrives first.
                    if (n.classList && n.classList.contains("agent-assistant-turn")) addButton(n);
                    else if (n.closest) { var t = n.closest(".agent-assistant-turn"); if (t) addButton(t); }
                    scan(n);
                  }
                  // If a React re-render of the turn drops our button (it's a
                  // child React doesn't own), re-add it to the same turn.
                  var removed = muts[i].removedNodes || [];
                  for (var r = 0; r < removed.length; r++) {
                    var rn = removed[r];
                    if (rn.nodeType === 1 && rn.classList && rn.classList.contains("epistemos-read-aloud")) {
                      var host = muts[i].target;
                      var rt = host && host.closest ? host.closest(".agent-assistant-turn") : null;
                      if (rt) addButton(rt);
                    }
                  }
                }
              });
              function start() {
                scan(document);
                setupSelection();
                if (document.body) obs.observe(document.body, { childList: true, subtree: true });
              }
              // Native calls this after flipping __EPISTEMOS_TTS_AVAILABLE__ so
              // buttons appear the moment the voice becomes ready (no restart).
              window.__EPISTEMOS_READALOUD_REFRESH__ = function () { scan(document); };
              if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
              else start();
            })();
            """,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true
        ))
        #if DEBUG
        ucc.addUserScript(WKUserScript(
            source: """
            (function () {
              function send(level, args) {
                try {
                  var text = Array.prototype.map.call(args, function (a) {
                    if (typeof a === "string") return a;
                    try { return JSON.stringify(a); } catch (e) { return String(a); }
                  }).join(" ");
                  window.webkit.messageHandlers.\(JuneAgentBridge.consoleChannel).postMessage(level + ": " + text);
                } catch (e) {}
              }
              var origError = console.error, origWarn = console.warn;
              console.error = function () { send("error", arguments); origError.apply(console, arguments); };
              console.warn = function () { send("warn", arguments); origWarn.apply(console, arguments); };
              window.addEventListener("error", function (e) {
                send("uncaught", [String(e.message)]);
              });
            })();
            """,
            injectionTime: .atDocumentStart, forMainFrameOnly: true
        ))
        ucc.add(bridge, name: JuneAgentBridge.consoleChannel)
        #endif
        ucc.add(bridge, name: JuneAgentBridge.invokeChannel)
        ucc.add(bridge, name: JuneAgentBridge.gatewayChannel)
        ucc.add(bridge, name: JuneAgentBridge.eventsChannel)
        ucc.add(bridge, name: JuneAgentBridge.speakChannel)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = JuneNavigationDelegate.shared
        webView.uiDelegate = JuneNavigationDelegate.shared
        // The bridged --background IS the Epistemos theme canvas, so overscroll
        // + pre-paint match the SPA exactly and the reveal stays seamless.
        webView.underPageBackgroundColor = JuneThemeBridge.backgroundNSColor(for: theme)
        // Pin prefers-color-scheme to the theme's own darkness from the first
        // paint (the .task re-pin lands later in the same runloop turn).
        webView.appearance = NSAppearance(named: theme.resolved.isDark ? .darkAqua : .aqua)
        bridge.runJS = { [weak webView] js in
            webView?.evaluateJavaScript(js) { _, error in
                if let error {
                    Self.log.warning("bridge JS eval failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        self.bridge = bridge
        self.webView = webView

        guard let entry = JuneSchemeHandler.entryURL else {
            failureMessage = "The Workspace entry URL is invalid."
            return
        }
        webView.load(URLRequest(url: entry))
        loadStarted = true
        loadStartedAt = Date()
        Self.log.info("June surface load started (root: \(location.distRoot.path, privacy: .public))")
    }

    private static func workspaceOverlayScript() -> String {
        let css = """
        \(workspaceFontFaceCSS())
        :root {
          --epistemos-ui-font: "ABC Diatype", -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
          --epistemos-display-font: "Epistemos Matrix Dots", "MatrixDotsDemoRegular", "MatrixTypeDisplay-Regular", var(--epistemos-ui-font);
          --font-sans: var(--epistemos-ui-font);
          --font-serif: var(--epistemos-ui-font);
          --font-mono: "Berkeley Mono", "SFMono-Regular", Consolas, "Liberation Mono", monospace;
        }
        html, body, button, input, textarea, select, [contenteditable],
        .app-shell, .workspace, .agent-workspace, .main-column, .main-panel,
        .sidebar, .agent-composer, .agent-composer * {
          font-family: var(--epistemos-ui-font) !important;
          letter-spacing: 0 !important;
        }
        .agent-hero-title,
        .folders-heading h1,
        .note-title,
        .folder-detail-title,
        .folder-detail-title-input,
        .welcome-title {
          font-family: var(--epistemos-display-font) !important;
          font-weight: 400 !important;
          letter-spacing: 0 !important;
        }
        .main-column, .main-panel, .main-panel-body, .workspace, .agent-workspace {
          min-width: 0 !important;
        }
        .agent-user-turn {
          align-items: flex-start !important;
          justify-content: flex-start !important;
          margin: 10px 0 16px !important;
          padding-right: clamp(16px, 8vw, 96px) !important;
          text-align: left !important;
        }
        .agent-user-turn-body {
          color: var(--epistemos-user-bubble-text) !important;
          background: var(--epistemos-user-bubble-bg) !important;
          border-color: color-mix(in srgb, var(--epistemos-user-bubble-bg) 72%, var(--foreground) 28%) !important;
          line-height: 1.5 !important;
          text-align: left !important;
          overflow-wrap: anywhere !important;
          word-break: normal !important;
        }
        .agent-user-turn-body * {
          color: var(--epistemos-user-bubble-text) !important;
        }
        html:not([data-theme="dark"]) .agent-user-turn-body {
          text-shadow: 0 1px 1px rgba(0, 0, 0, 0.22) !important;
        }
        .agent-assistant-turn {
          margin: 12px 0 18px !important;
          padding-right: clamp(16px, 7vw, 88px) !important;
          text-align: left !important;
        }
        .agent-assistant-turn-body {
          line-height: 1.55 !important;
          text-align: left !important;
          overflow-wrap: anywhere !important;
          word-break: normal !important;
        }
        .agent-turn-actions {
          margin-top: 6px !important;
        }
        .agent-composer-box,
        .agent-composer-editor,
        .agent-composer-editor-root {
          min-width: 0 !important;
          box-sizing: border-box !important;
        }
        .agent-composer-editor,
        .agent-composer-editor-root,
        .agent-composer-editor [contenteditable="true"] {
          caret-color: var(--foreground) !important;
          white-space: pre-wrap !important;
          overflow-wrap: anywhere !important;
          word-break: normal !important;
          line-height: 1.45 !important;
          text-align: left !important;
        }
        .agent-composer-editor:focus,
        .agent-composer-editor-root:focus {
          outline: none !important;
        }
        .agent-composer-editor p.is-editor-empty:first-child::before {
          content: "Ask Workspace anything, run / commands" !important;
        }
        .sidebar-brand {
          align-items: center !important;
          display: inline-flex !important;
          gap: 7px !important;
        }
        .sidebar-brand .sidebar-brand-mark {
          display: none !important;
        }
        .sidebar-brand::after {
          content: "Workspace" !important;
          color: currentColor !important;
          font-family: var(--epistemos-ui-font) !important;
          font-size: 13px !important;
          font-weight: 700 !important;
          letter-spacing: 0 !important;
          line-height: 18px !important;
        }
        .app-shell[data-sidebar="expanded"] .main-column {
          grid-column: 2 !important;
          min-width: 0 !important;
        }
        """
        let cssLiteral = JuneAgentBridge.jsStringLiteral(css)
        return """
        (function () {
          var styleId = "epistemos-workspace-overlay";
          function installStyle() {
            var style = document.getElementById(styleId);
            if (!style) {
              style = document.createElement("style");
              style.id = styleId;
              document.documentElement.appendChild(style);
            }
            style.textContent = \(cssLiteral);
          }

          function replaceWorkspaceWords(value) {
            if (!value || value.indexOf("June") === -1 && value.indexOf("JUNE") === -1 && value.indexOf("june") === -1) return value;
            return value
              .replace(/\\bJUNE\\b/g, "WORKSPACE")
              .replace(/\\bJune\\b/g, "Workspace")
              .replace(/\\bjune\\b/g, "workspace");
          }

          var skipTags = { SCRIPT: true, STYLE: true, NOSCRIPT: true, CODE: true, PRE: true };
          var watchedAttrs = ["aria-label", "title", "placeholder", "data-placeholder", "alt"];

          function renameElement(el) {
            if (!el || !el.getAttribute) return;
            for (var i = 0; i < watchedAttrs.length; i++) {
              var name = watchedAttrs[i];
              var value = el.getAttribute(name);
              var next = replaceWorkspaceWords(value);
              if (next !== value) el.setAttribute(name, next);
            }
          }

          function scan(root) {
            if (!root) return;
            if (root.nodeType === Node.TEXT_NODE) {
              var nextText = replaceWorkspaceWords(root.nodeValue);
              if (nextText !== root.nodeValue) root.nodeValue = nextText;
              return;
            }
            if (root.nodeType !== Node.ELEMENT_NODE && root.nodeType !== Node.DOCUMENT_NODE && root.nodeType !== Node.DOCUMENT_FRAGMENT_NODE) return;
            if (root.nodeType === Node.ELEMENT_NODE && skipTags[root.tagName]) return;
            if (root.nodeType === Node.ELEMENT_NODE) renameElement(root);
            var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT, {
              acceptNode: function (node) {
                if (node.nodeType === Node.ELEMENT_NODE && skipTags[node.tagName]) return NodeFilter.FILTER_REJECT;
                return NodeFilter.FILTER_ACCEPT;
              }
            });
            var node;
            while ((node = walker.nextNode())) {
              if (node.nodeType === Node.TEXT_NODE) {
                var next = replaceWorkspaceWords(node.nodeValue);
                if (next !== node.nodeValue) node.nodeValue = next;
              } else if (node.nodeType === Node.ELEMENT_NODE) {
                renameElement(node);
              }
            }
          }

          function keepCaretInsideEditor(event) {
            var target = event.target && event.target.closest ? event.target.closest(".agent-composer-editor, .agent-composer-editor-root") : null;
            if (!target) return;
            var selection = window.getSelection && window.getSelection();
            if (!selection || selection.rangeCount === 0 || target.contains(selection.anchorNode)) return;
            target.focus();
            var range = document.createRange();
            range.selectNodeContents(target);
            range.collapse(false);
            selection.removeAllRanges();
            selection.addRange(range);
          }

          var scanScheduled = false;
          function scanSoon(delay) {
            window.setTimeout(function () {
              if (scanScheduled) return;
              scanScheduled = true;
              window.requestAnimationFrame(function () {
                scanScheduled = false;
                installStyle();
                scan(document.body || document.documentElement);
              });
            }, delay);
          }

          function start() {
            installStyle();
            scan(document.body || document.documentElement);
            document.addEventListener("input", keepCaretInsideEditor, true);
            document.addEventListener("keyup", keepCaretInsideEditor, true);
            [120, 400, 1000, 2500, 5000].forEach(scanSoon);
            document.addEventListener("visibilitychange", function () { scanSoon(0); });
            window.addEventListener("focus", function () { scanSoon(0); });
            window.addEventListener("popstate", function () { scanSoon(0); });
          }

          if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
          else start();
        })();
        """
    }

    private static func workspaceFontFaceCSS() -> String {
        guard let dataURL = workspaceDisplayFontDataURL() else { return "" }
        return """
        @font-face { font-family: "Epistemos Matrix Dots"; src: url("\(dataURL)") format("truetype"); font-weight: 400; font-style: normal; font-display: swap; }
        """
    }

    private static func workspaceDisplayFontDataURL() -> String? {
        let bundles = [Bundle.main, Bundle(for: JuneAgentSurfaceHolder.self)] + Bundle.allBundles + Bundle.allFrameworks
        var seenBundlePaths = Set<String>()
        for bundle in bundles {
            guard seenBundlePaths.insert(bundle.bundleURL.path).inserted else { continue }
            let directURL = bundle.url(forResource: "MatrixDotsDemoRegular", withExtension: "ttf")
            let nestedURL = bundle.resourceURL?
                .appendingPathComponent("Fonts", isDirectory: true)
                .appendingPathComponent("MatrixDotsDemoRegular.ttf")
            for url in [directURL, nestedURL].compactMap({ $0 }) {
                guard let data = try? Data(contentsOf: url) else { continue }
                return "data:font/ttf;base64,\(data.base64EncodedString())"
            }
        }
        Self.log.warning("MatrixDotsDemoRegular.ttf not found for Workspace web overlay")
        return nil
    }
}

/// Pins navigation to the june:// origin; external links open in the default
/// browser (hardening doctrine §3.A — never weaken origin pinning).
@MainActor
private final class JuneNavigationDelegate: NSObject, WKNavigationDelegate {
    static let shared = JuneNavigationDelegate()

    private static let log = Logger(subsystem: "com.epistemos", category: "JuneAgentSurface")

    var onFirstPaint: (() -> Void)?

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if url.scheme == JuneSchemeHandler.scheme {
            decisionHandler(.allow)
            return
        }
        if url.scheme == "http" || url.scheme == "https" {
            NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Self.log.info("June surface navigation finished")
        onFirstPaint?()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Self.log.error(
            "June surface navigation failed: \(error.localizedDescription, privacy: .public)"
        )
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        Self.log.error(
            "June surface provisional navigation failed: \(error.localizedDescription, privacy: .public)"
        )
    }
}

extension JuneNavigationDelegate: WKUIDelegate {
    /// target=_blank / window.open: June routes its own externals through
    /// invoke commands, but stray blank-target anchors (e.g. library links in
    /// error UIs) must open in the default browser instead of dying silently.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url,
           url.scheme == "http" || url.scheme == "https" {
            NSWorkspace.shared.open(url)
        }
        return nil
    }
}

/// Maps the resolved Epistemos theme onto June's CSS token system.
///
/// June's own Appearance picker re-themes the entire SPA by overriding ONE
/// custom property (`--brand`) over a per-scheme neutral ramp (tokens.css), so
/// this bridge speaks exactly that language: `--brand` carries the Epistemos
/// accent and the core surface tokens carry the theme's palette. Every derived
/// tint/wash/hover in June (color-mix over --brand and the ramp) then follows
/// automatically. Values are concrete sRGB colors resolved natively — no June
/// source edits, no stylesheet patching.
@MainActor
enum JuneThemeBridge {
    /// JSON payload for `window.__EPISTEMOS_THEME_APPLY__`:
    /// `{"dark": Bool, "vars": {"--token": "rgb(...)"}}`.
    static func payloadJSON(for theme: EpistemosTheme) -> String {
        let resolved = theme.resolved
        let dark = resolved.isDark
        let background = cssColor(resolved.background, dark: dark)
        let foreground = cssColor(resolved.foreground, dark: dark)
        let card = cssColor(resolved.card, dark: dark)
        let muted = cssColor(resolved.muted, dark: dark)
        let border = cssColor(resolved.border, dark: dark)
        let vars: [String: String] = [
            "--brand": cssColor(resolved.accent, dark: dark),
            "--background": background,
            "--foreground": foreground,
            "--card": card,
            "--card-foreground": foreground,
            "--popover": card,
            "--popover-foreground": foreground,
            // June's primary = near-foreground fill with inverse text; mapping
            // to the theme's own fg/bg keeps that contrast on every palette.
            "--primary": foreground,
            "--primary-foreground": background,
            "--secondary": muted,
            "--secondary-foreground": foreground,
            "--muted": muted,
            "--muted-foreground": cssColor(resolved.mutedForeground, dark: dark),
            // June's --accent is its quiet hover FILL (not the brand color).
            "--accent": muted,
            "--accent-foreground": foreground,
            "--border": border,
            "--input": border,
            "--ring": border,
            "--selection": muted,
            "--sidebar": background,
            "--sidebar-foreground": foreground,
            "--sidebar-accent": muted,
            "--sidebar-border": border,
            "--epistemos-user-bubble-bg": cssColor(resolved.userBubbleBg, dark: dark),
            "--epistemos-user-bubble-text": cssColor(resolved.userBubbleText, dark: dark),
        ]
        let object: [String: Any] = ["dark": dark, "vars": vars]
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"dark\":\(dark ? "true" : "false"),\"vars\":{}}"
        }
        return json
    }

    /// The theme's canvas as a concrete sRGB color — shared by the placeholder,
    /// the webview underpage, and June's bridged `--background`.
    static func backgroundNSColor(for theme: EpistemosTheme) -> NSColor {
        let resolved = theme.resolved
        return sRGB(resolved.background.nsColor, dark: resolved.isDark)
    }

    private static func cssColor(_ token: EpistemosTheme.ResolvedColorToken, dark: Bool) -> String {
        let color = sRGB(token.nsColor, dark: dark)
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        let alpha = color.alphaComponent
        if alpha >= 0.999 { return "rgb(\(red), \(green), \(blue))" }
        return String(format: "rgba(%d, %d, %d, %.3f)", red, green, blue, alpha)
    }

    /// System-dynamic tokens (windowBackground / controlBackground) resolve
    /// per-appearance, so snapshot under the theme's own appearance.
    private static func sRGB(_ color: NSColor, dark: Bool) -> NSColor {
        var converted: NSColor?
        if let appearance = NSAppearance(named: dark ? .darkAqua : .aqua) {
            appearance.performAsCurrentDrawingAppearance {
                converted = color.usingColorSpace(.sRGB)
            }
        } else {
            converted = color.usingColorSpace(.sRGB)
        }
        // Unconvertible colors (pattern/catalog edge cases) fall back to June's
        // stock neutral canvas rather than crashing or going transparent.
        return converted ?? NSColor(
            red: dark ? 0.138 : 0.925,
            green: dark ? 0.135 : 0.918,
            blue: dark ? 0.128 : 0.902,
            alpha: 1
        )
    }
}

struct JuneAgentSurfaceView: View {
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var failureMessage: String?
    @State private var mountedWebView: WKWebView?
    @State private var retryAttempt = 0

    /// The live Epistemos theme canvas — identical to the bridged June
    /// `--background`, so the placeholder and the painted SPA are
    /// indistinguishable at reveal under every theme.
    private var juneCanvas: Color {
        Color(nsColor: JuneThemeBridge.backgroundNSColor(for: ui.theme))
    }

    var body: some View {
        ZStack {
            juneCanvas.ignoresSafeArea()
            if let failureMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(failureMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                    Button("Try Again") { retryAttempt += 1 }
                        .buttonStyle(.bordered)
                }
                .accessibilityElement(children: .combine)
            } else if let webView = mountedWebView ?? JuneAgentSurfaceHolder.shared.webView {
                JuneWebViewRepresentable(webView: webView)
                    .opacity(revealed ? 1 : 0)
                    .overlay { JuneAgentMascotOverlayHook() }
            }
            if failureMessage == nil && !revealed {
                ProgressView()
                    .controlSize(.small)
                    .tint(.secondary)
                    .accessibilityLabel("Loading Workspace")
            }
        }
        .onChange(of: ui.theme) { _, newTheme in
            Self.applyEpistemosTheme(newTheme)
        }
        .onAppear { Self.refreshReadAloudAvailability() }
        .task(id: retryAttempt) {
            let mountedAt = Date()
            let holder = JuneAgentSurfaceHolder.shared
            let isColdOpen = holder.webView == nil
            JuneNavigationDelegate.shared.onFirstPaint = {
                // Honor Reduce Motion like the rest of the app (LandingView) —
                // reveal instantly instead of fading.
                withAnimation(reduceMotion ? nil : .easeIn(duration: 0.15)) { revealed = true }
                Self.handOffFocus(to: holder.webView)
                if isColdOpen, let startedAt = holder.loadStartedAt {
                    // Budget contract [agent_surface].cold_open_ms_max (doctrine §4).
                    JuneAgentPerfMetrics.shared.recordColdOpen(
                        milliseconds: Date().timeIntervalSince(startedAt) * 1000
                    )
                }
            }
            holder.ensureStarted(theme: ui.theme)
            failureMessage = holder.failureMessage
            mountedWebView = holder.webView
            guard failureMessage == nil else { return }
            holder.webView?.navigationDelegate = JuneNavigationDelegate.shared
            holder.webView?.uiDelegate = JuneNavigationDelegate.shared
            // Re-push the live theme on every mount: the seed script covers the
            // cold boot, but a theme switched while another room was open must
            // land the moment the Agent room reappears.
            Self.applyEpistemosTheme(ui.theme)
            // Re-mounts after the first paint reveal immediately (warm path).
            if holder.webView?.isLoading == false && holder.loadStarted {
                revealed = true
                Self.handOffFocus(to: holder.webView)
                JuneAgentPerfMetrics.shared.recordWarmReopen(
                    milliseconds: Date().timeIntervalSince(mountedAt) * 1000
                )
            }
        }
        // Deliberately no teardown on disappear: the WebView stays warm across
        // tab switches (perf doctrine §1.5 / §3.2).
    }

    /// Pushes the live Epistemos theme into June: the NSAppearance pin (drives
    /// prefers-color-scheme from the THEME's own darkness, not the OS), the
    /// underpage canvas, and the full token-override payload. Idempotent —
    /// re-applying the same theme is a no-op visually.
    private static func applyEpistemosTheme(_ theme: EpistemosTheme) {
        let holder = JuneAgentSurfaceHolder.shared
        guard let webView = holder.webView else { return }
        webView.appearance = NSAppearance(named: theme.resolved.isDark ? .darkAqua : .aqua)
        webView.underPageBackgroundColor = JuneThemeBridge.backgroundNSColor(for: theme)
        holder.bridge?.runJS?(
            "window.__EPISTEMOS_THEME_APPLY__ && window.__EPISTEMOS_THEME_APPLY__(\(JuneThemeBridge.payloadJSON(for: theme)));"
        )
    }

    /// Re-push live TTS availability whenever the Agent room appears, so
    /// read-aloud surfaces the moment the voice becomes ready (e.g. the user
    /// installs it in Settings) — no app restart. No-op before the page loads.
    private static func refreshReadAloudAvailability() {
        let available = EpistemosSpeechSynthesizer.isTextToSpeechAvailable()
        JuneAgentSurfaceHolder.shared.bridge?.runJS?(
            "window.__EPISTEMOS_TTS_AVAILABLE__ = \(available ? "true" : "false"); "
                + "window.__EPISTEMOS_READALOUD_REFRESH__ && window.__EPISTEMOS_READALOUD_REFRESH__();"
        )
    }

    private static func handOffFocus(to webView: WKWebView?) {
        DispatchQueue.main.async {
            guard let webView, let window = webView.window else { return }
            window.makeFirstResponder(webView)
        }
    }
}

private struct JuneWebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#endif
