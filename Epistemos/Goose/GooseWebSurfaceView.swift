import SwiftUI
import WebKit

struct GooseWebSurfaceView: View {
    nonisolated static let gooseUISchemeName = "epistemos-goose"

    var theme: EpistemosTheme = .nativeDefault

    @State private var supervisor = GooseRuntimeSupervisor()
    @State private var acpBridge = GooseACPEventBridge()
    @State private var nativePromptBridge: GooseWebNativePromptBridge
    @State private var nativeAffordanceBridge: GooseWebNativeAffordanceBridge
    @State private var page: WebPage
    @State private var secretKey: String
    @State private var showDetails = false

    init(theme: EpistemosTheme = .nativeDefault) {
        self.theme = theme
        let secretKey = GooseRuntimeSupervisor.randomSecretKey()
        let bootstrap = GooseWebBootstrap(
            baseURL: GooseRuntimeSupervisor.defaultBaseURL(),
            secretKey: secretKey
        )
        let nativePromptBridge = GooseWebNativePromptBridge()
        let nativeAffordanceBridge = GooseWebNativeAffordanceBridge()
        _nativePromptBridge = State(initialValue: nativePromptBridge)
        _nativeAffordanceBridge = State(initialValue: nativeAffordanceBridge)
        _secretKey = State(initialValue: secretKey)
        _page = State(initialValue: Self.makePage(
            bootstrap: bootstrap,
            gooseUIRoot: Self.resolvedGooseUIRoot(),
            nativePromptBridge: nativePromptBridge,
            nativeAffordanceBridge: nativeAffordanceBridge
        ))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WebView(page)
                .background(background)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showDetails {
                detailsPanel
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                detailsButton
                    .padding(.top, 10)
                    .padding(.trailing, 12)
            }
            nativeACPOverlay
        }
        .background(background)
        .animation(.snappy(duration: 0.16), value: showDetails)
        .task { await startSurface() }
        .onDisappear {
            supervisor.stop()
            nativePromptBridge.cancelPendingPrompts()
            Task { await acpBridge.disconnect() }
        }
    }

    private var background: Color {
        GooseSurfaceStyle.background(for: theme)
    }

    private var detailsButton: some View {
        Button { showDetails = true } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.mutedForeground)
                .frame(width: 30, height: 30)
                .background(Rectangle().fill(GooseSurfaceStyle.background(for: theme, role: .rail).opacity(0.92)))
                .overlay(Rectangle().stroke(theme.border.opacity(0.58), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Goose details")
        .accessibilityLabel("Goose details")
    }

    private var detailsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Goose")
                    .font(GooseSurfaceStyle.bodyFont(12, weight: .semibold))
                Spacer()
                Button { showDetails = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            detailRow("runtime", statusLabel)
            detailRow("native ACP", acpStatusLabel)
            detailRow("ACP", GooseRuntimeSupervisor.defaultBaseURL().absoluteString)
            detailRow("surface", Self.resolvedGooseUIIndex() == nil ? "UI bundle not staged" : "Goose Web UI")
            detailRow("custom ACP", customACPStatusLabel)
            HStack(spacing: 8) {
                Button { loadGooseRoute("/settings?section=models") } label: {
                    Label("Manage models", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
                .help("Open Goose models")
                Button { loadGooseRoute("/configure-providers") } label: {
                    Label("Providers", systemImage: "key")
                }
                .buttonStyle(.bordered)
                .help("Open Goose providers")
            }
            .font(GooseSurfaceStyle.bodyFont(10, weight: .semibold))
            if !acpBridge.unhandledDiagnostics.isEmpty {
                Divider().overlay(theme.border)
                ForEach(acpBridge.unhandledDiagnostics.suffix(4)) { diagnostic in
                    detailRow(
                        diagnostic.kind.rawValue,
                        "\(diagnostic.method) \(diagnostic.parameterSummary)"
                    )
                }
            }
            Divider().overlay(theme.border)
            ForEach(GooseWebBootShim.dispositionLedger.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                detailRow(key, value.rawValue)
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .background(GooseSurfaceStyle.background(for: theme, role: .rail).opacity(0.96))
        .overlay(Rectangle().stroke(theme.border.opacity(0.72), lineWidth: 1))
    }

    @ViewBuilder
    private var nativeACPOverlay: some View {
        if let permission = nativePromptBridge.pendingPermission {
            permissionOverlay(id: permission.id, request: permission.request) { optionID in
                nativePromptBridge.resolvePermission(promptID: permission.id, optionID: optionID)
            }
        } else if let elicitation = nativePromptBridge.pendingElicitation {
            elicitationOverlay(
                id: elicitation.id,
                request: elicitation.request,
                fields: elicitation.fields
            ) { action in
                switch action {
                case .accept(let values):
                    nativePromptBridge.acceptElicitation(promptID: elicitation.id, values: values)
                case .decline:
                    nativePromptBridge.declineElicitation(promptID: elicitation.id)
                case .cancel:
                    nativePromptBridge.cancelElicitation(promptID: elicitation.id)
                }
            }
        } else if let permission = acpBridge.pendingPermission {
            permissionOverlay(id: permission.id, request: permission.request) { optionID in
                acpBridge.resolvePermission(promptID: permission.id, optionID: optionID)
            }
        } else if let elicitation = acpBridge.pendingElicitation {
            elicitationOverlay(
                id: elicitation.id,
                request: elicitation.request,
                fields: elicitation.fields
            ) { action in
                switch action {
                case .accept(let values):
                    acpBridge.acceptElicitation(promptID: elicitation.id, values: values)
                case .decline:
                    acpBridge.declineElicitation(promptID: elicitation.id)
                case .cancel:
                    acpBridge.cancelElicitation(promptID: elicitation.id)
                }
            }
        }
    }

    private func permissionOverlay(
        id: String,
        request: GooseACPRequestPermissionRequest,
        onDecision: @escaping (String?) -> Void
    ) -> some View {
        promptOverlay {
            GooseACPPermissionPanel(
                promptID: id,
                request: request,
                theme: theme,
                onDecision: onDecision
            )
            .id(id)
        }
    }

    private func elicitationOverlay(
        id: String,
        request: GooseACPCreateElicitationRequest,
        fields: [GooseACPElicitationFormField],
        onAction: @escaping (GooseACPElicitationPanel.Action) -> Void
    ) -> some View {
        promptOverlay {
            GooseACPElicitationPanel(
                promptID: id,
                request: request,
                fields: fields,
                theme: theme,
                onAction: onAction
            )
            .id(id)
        }
    }

    private func promptOverlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            Spacer()
            content()
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(GooseSurfaceStyle.bodyFont(10, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
            Spacer(minLength: 0)
            Text(value)
                .font(GooseSurfaceStyle.bodyFont(10))
                .foregroundStyle(theme.resolved.foreground.color)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.trailing)
        }
    }

    private var statusLabel: String {
        switch supervisor.status {
        case .idle:
            return "idle"
        case .unavailable(let message):
            return "unavailable: \(message)"
        case .starting:
            return "starting"
        case .running(let connection):
            return "live: \(connection.baseURL.absoluteString)"
        case .failed(let message):
            return "error: \(message)"
        case .stopped:
            return "stopped"
        }
    }

    private var acpStatusLabel: String {
        switch acpBridge.status {
        case .idle:
            return "idle"
        case .connecting:
            return "connecting"
        case .connected(let agent):
            if let agent {
                return "\(agent.name) \(agent.version)"
            }
            return "connected"
        case .failed(let message):
            return "error: \(message)"
        case .disconnected:
            return "disconnected"
        }
    }

    private var customACPStatusLabel: String {
        acpBridge.unhandledDiagnostics.isEmpty
            ? "Goose ACP ready"
            : "blocked: \(acpBridge.unhandledDiagnostics.count)"
    }

    private func startSurface() async {
        supervisor.start(secretKey: secretKey)
        await loadWhenReady()
    }

    private func loadWhenReady() async {
        for _ in 0..<260 {
            switch supervisor.status {
            case .running(let connection):
                connectNativeACP(connection: connection)
                loadGooseUI(connection: connection)
                return
            case .unavailable, .failed:
                await acpBridge.disconnect()
                loadPlaceholder()
                return
            default:
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        loadPlaceholder()
    }

    private func connectNativeACP(connection: GooseRuntimeConnection) {
        guard let url = connection.acpWebSocketURL else { return }
        acpBridge.connect(url: url)
    }

    private func loadGooseUI(connection: GooseRuntimeConnection) {
        if let index = Self.resolvedGooseUIIndex() {
            _ = page.load(URLRequest(url: Self.bootURL(for: index)))
        } else {
            _ = page.load(html: Self.placeholderHTML(status: statusLabel, acpURL: connection.acpWebSocketURL?.absoluteString ?? ""))
        }
    }

    private func loadGooseRoute(_ route: String) {
        guard Self.resolvedGooseUIIndex() != nil else { return }
        _ = page.load(URLRequest(url: Self.routeURL(route)))
    }

    private func loadPlaceholder() {
        _ = page.load(html: Self.placeholderHTML(status: statusLabel, acpURL: ""))
    }

    private static func makePage(
        bootstrap: GooseWebBootstrap,
        gooseUIRoot: URL?,
        nativePromptBridge: GooseWebNativePromptBridge,
        nativeAffordanceBridge: GooseWebNativeAffordanceBridge
    ) -> WebPage {
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.defaultNavigationPreferences.allowsContentJavaScript = true
        configuration.userContentController.addScriptMessageHandler(
            nativePromptBridge,
            contentWorld: .page,
            name: "epistemosGoosePrompt"
        )
        configuration.userContentController.addScriptMessageHandler(
            nativeAffordanceBridge,
            contentWorld: .page,
            name: "epistemosGooseNative"
        )
        if let gooseUIRoot, let scheme = URLScheme(gooseUISchemeName) {
            configuration.urlSchemeHandlers[scheme] = WorkSPASchemeHandler(root: gooseUIRoot)
        }
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: GooseWebBootShim.bootstrapScript(for: bootstrap) + "\n" + nativeFeelScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        return WebPage(configuration: configuration, navigationDecider: GooseNavigationDecider())
    }

    @MainActor
    static func makeBootProbePage(
        bootstrap: GooseWebBootstrap,
        gooseUIRoot: URL,
        nativePromptBridge: GooseWebNativePromptBridge = GooseWebNativePromptBridge(),
        nativeAffordanceBridge: GooseWebNativeAffordanceBridge = GooseWebNativeAffordanceBridge()
    ) -> WebPage {
        makePage(
            bootstrap: bootstrap,
            gooseUIRoot: gooseUIRoot,
            nativePromptBridge: nativePromptBridge,
            nativeAffordanceBridge: nativeAffordanceBridge
        )
    }

    private static func resolvedGooseUIIndex() -> URL? {
        GooseWebUIResolver.indexURL()
    }

    private static func resolvedGooseUIRoot() -> URL? {
        resolvedGooseUIIndex()?.deletingLastPathComponent()
    }

    nonisolated static func bootURL(for _: URL) -> URL {
        URL(string: "\(gooseUISchemeName)://app/#/?")!
    }

    nonisolated static func routeURL(_ route: String) -> URL {
        let normalizedRoute = route.hasPrefix("/") ? route : "/\(route)"
        return URL(string: "\(gooseUISchemeName)://app/#\(normalizedRoute)")!
    }

    private static func placeholderHTML(status: String, acpURL: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            :root { color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; }
            body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: Canvas; color: CanvasText; }
            main { width: min(560px, calc(100vw - 48px)); }
            h1 { font-size: 16px; font-weight: 650; margin: 0 0 10px; }
            p { font-size: 13px; line-height: 1.45; margin: 0 0 8px; color: color-mix(in srgb, CanvasText 72%, transparent); }
            code { font-family: "SF Mono", ui-monospace, monospace; font-size: 12px; }
          </style>
        </head>
        <body>
          <main>
            <h1>Epistemos Goose</h1>
            <p><code>\(escapeHTML(status))</code></p>
            <p><code>\(escapeHTML(acpURL))</code></p>
          </main>
        </body>
        </html>
        """
    }

    private static func escapeHTML(_ raw: String) -> String {
        raw.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static let nativeFeelScript = """
    (() => {
      const style = document.createElement('style');
      style.textContent = `
        :root { color-scheme: light dark; }
        * { -webkit-font-smoothing: antialiased; }
        html, body { overscroll-behavior: none; cursor: default; }
        ::-webkit-scrollbar { width: 0; height: 0; }
      `;
      document.documentElement.appendChild(style);
    })();
    """
}

private struct GooseNavigationDecider: WebPage.NavigationDeciding {
    func decidePolicy(
        for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences
    ) async -> WKNavigationActionPolicy {
        guard let url = action.request.url else { return .cancel }
        switch url.scheme?.lowercased() {
        case "about", "file", GooseWebSurfaceView.gooseUISchemeName:
            return .allow
        case "http", "https", "ws", "wss":
            guard let host = url.host?.lowercased(),
                  host == "127.0.0.1" || host == "localhost" || host == "::1" else {
                return .cancel
            }
            return .allow
        default:
            return .cancel
        }
    }
}
