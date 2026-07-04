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
    func ensureStarted() {
        // A prior failed attempt must not shadow a later successful one — the
        // message reflects only the CURRENT attempt (stale-failure bug).
        failureMessage = nil
        guard webView == nil else { return }
        guard let location = JuneWebAssets.resolve() else {
            failureMessage = "The June agent bundle is missing from this build."
            return
        }
        guard let shimSource = try? String(contentsOf: location.shimURL, encoding: .utf8) else {
            failureMessage = "The June bridge shim could not be loaded."
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

        let webView = WKWebView(frame: .zero, configuration: config)
        // June's own canvas (main.css --background: light oklch 95.13% warm /
        // dark oklch 16.5% warm) so overscroll + pre-paint match the SPA and
        // the reveal is seamless in both appearances.
        webView.underPageBackgroundColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.138, green: 0.135, blue: 0.128, alpha: 1)
                : NSColor(red: 0.925, green: 0.918, blue: 0.902, alpha: 1)
        }
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
            failureMessage = "The June entry URL is invalid."
            return
        }
        webView.load(URLRequest(url: entry))
        loadStarted = true
        loadStartedAt = Date()
        Self.log.info("June surface load started (root: \(location.distRoot.path, privacy: .public))")
    }
}

/// Pins navigation to the june:// origin; external links open in the default
/// browser (hardening doctrine §3.A — never weaken origin pinning).
@MainActor
private final class JuneNavigationDelegate: NSObject, WKNavigationDelegate {
    static let shared = JuneNavigationDelegate()

    var onFirstPaint: (() -> Void)?

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
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
        onFirstPaint?()
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

struct JuneAgentSurfaceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var failureMessage: String?
    @State private var retryAttempt = 0

    /// June's own canvas (main.css --background) so the placeholder and the
    /// painted SPA are indistinguishable at reveal in both appearances.
    private var juneCanvas: Color {
        colorScheme == .dark
            ? Color(red: 0.138, green: 0.135, blue: 0.128)
            : Color(red: 0.925, green: 0.918, blue: 0.902)
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
            } else if let webView = JuneAgentSurfaceHolder.shared.webView {
                JuneWebViewRepresentable(webView: webView)
                    .opacity(revealed ? 1 : 0)
                    .overlay { JuneAgentMascotOverlayHook() }
            }
            if failureMessage == nil && !revealed {
                ProgressView()
                    .controlSize(.small)
                    .tint(.secondary)
                    .accessibilityLabel("Loading the agent")
            }
        }
        .onChange(of: colorScheme) { _, scheme in
            Self.applyAppearance(scheme, to: JuneAgentSurfaceHolder.shared.webView)
        }
        .task(id: retryAttempt) {
            let mountedAt = Date()
            let holder = JuneAgentSurfaceHolder.shared
            let isColdOpen = holder.webView == nil
            holder.ensureStarted()
            failureMessage = holder.failureMessage
            guard failureMessage == nil else { return }
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
            holder.webView?.navigationDelegate = JuneNavigationDelegate.shared
            holder.webView?.uiDelegate = JuneNavigationDelegate.shared
            // Pin June's prefers-color-scheme to the app's resolved theme
            // (RootView .preferredColorScheme), NOT the OS — otherwise a dark
            // Epistemos theme on a light OS would render June light.
            Self.applyAppearance(colorScheme, to: holder.webView)
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

    /// Entering the Agent room hands keyboard focus to June so the composer is
    /// immediately typeable — deferred a tick so the representable is attached
    /// to the window, and only when it actually is (never steals focus from
    /// another window).
    /// Makes June's `prefers-color-scheme` follow the Epistemos theme by
    /// pinning the webview's NSAppearance to the SwiftUI-resolved scheme.
    private static func applyAppearance(_ scheme: ColorScheme, to webView: WKWebView?) {
        webView?.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
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
