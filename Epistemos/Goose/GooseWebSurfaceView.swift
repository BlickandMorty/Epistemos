import SwiftUI
import WebKit

struct GooseWebSurfaceView: View {
    nonisolated private static let gooseUISurfaceCacheToken = UUID().uuidString
    nonisolated static let gooseUISchemeName =
        "epistemos-goose-\(gooseUISurfaceCacheToken.lowercased())"
    nonisolated private static let gooseUISurfaceHost =
        "app-\(gooseUISurfaceCacheToken.lowercased())"
    nonisolated private static let gooseUISurfaceVirtualBasePath =
        "/__epistemos-goose/\(gooseUISurfaceCacheToken)"

    var theme: EpistemosTheme = .nativeDefault
    /// The web hash route to display. Default `/?` (the Goose hub). The native Agent frame's nav rail
    /// drives this so a rail selection navigates the embedded WebView — navigation STRUCTURE only; the
    /// SPA still owns its content. A change re-points the loaded WebView via `loadGooseRoute`.
    var route: String = "/?"

    @State private var supervisor = GooseRuntimeSupervisor()
    @State private var acpBridge = GooseACPEventBridge()
    @State private var nativePromptBridge: GooseWebNativePromptBridge
    @State private var nativeAffordanceBridge: GooseWebNativeAffordanceBridge
    @State private var page: WebPage
    @State private var gooseUIServer: WorkSPAServer?
    @State private var secretKey: String
    @State private var showDetails = false
    @State private var runtimeHealthTask: Task<Void, Never>?
    @State private var trustedOrigins: GooseTrustedLoopbackOrigins
    // Step 3 per-route migration: the router defaults EVERY route to the WebView (the oracle) and
    // promotes a route to native only when explicitly enabled. `nativeModelsPresented` drives the
    // native Models sheet; the WebView keeps backing the route, unchanged, when not promoted.
    @State private var router = GooseSurfaceRouter()
    @State private var nativeModelsPresented = false
    // Review H1/H3: the supervisor reaching .running and the bridge finishing provider-sync are both
    // ASYNC and can arrive after the initial bounded poll gave up. These track which connection the
    // surface has already been driven for / reloaded after sync, so the status observers can drive
    // load + post-sync reload idempotently (no double-load on the fast path).
    @State private var drivenConnectionKey: String?
    @State private var reloadedSyncForConnectionKey: String?
    @State private var isRestarting = false
    // Single live source-of-truth for the route to display. The incoming `route` prop drives this via
    // `onChange`, but the async load chain (`.task → loadWhenReady`) and the provider-sync reload must
    // read the CURRENT desired route, not a value captured at view-appear time or a literal "/?". @State
    // storage is shared across struct re-creations, so even a stale captured `self` reads the live value
    // here — fixing rail clicks made during startup being dropped + the post-sync reload snapping to hub.
    @State private var activeRoute: String

    init(theme: EpistemosTheme = .nativeDefault, route: String = "/?") {
        self.theme = theme
        self.route = route
        let secretKey = GooseRuntimeSupervisor.randomSecretKey()
        let bootstrap = GooseWebBootstrap(
            baseURL: GooseRuntimeSupervisor.defaultBaseURL(),
            secretKey: secretKey
        )
        let nativePromptBridge = GooseWebNativePromptBridge()
        let nativeAffordanceBridge = GooseWebNativeAffordanceBridge()
        let trustedOrigins = GooseTrustedLoopbackOrigins()
        _nativePromptBridge = State(initialValue: nativePromptBridge)
        _nativeAffordanceBridge = State(initialValue: nativeAffordanceBridge)
        _secretKey = State(initialValue: secretKey)
        _trustedOrigins = State(initialValue: trustedOrigins)
        _activeRoute = State(initialValue: route)
        _page = State(initialValue: Self.makePage(
            bootstrap: bootstrap,
            gooseUIRoot: Self.resolvedGooseUIRoot(),
            nativePromptBridge: nativePromptBridge,
            nativeAffordanceBridge: nativeAffordanceBridge,
            trustedOrigins: trustedOrigins
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
        .sheet(isPresented: $nativeModelsPresented) {
            // Promoted-only: defaults to .web so this sheet never opens unless the Models route is
            // explicitly enabled. Reuses the SAME live acpBridge connection (no second spawn).
            GooseNativeModelsView(bridge: acpBridge)
                .frame(minWidth: 480, minHeight: 380)
        }
        .task { await startSurface() }
        .onChange(of: supervisor.status) { _, status in
            handleRuntimeStatusChange(status)
        }
        .onChange(of: route) { _, newRoute in
            // Native nav-rail drove the route: record it as the live desired route (so a change made
            // before the UI server is running is NOT lost — the load chain reads `activeRoute`), then
            // re-point the loaded WebView (no-op until the UI server is running).
            activeRoute = newRoute
            loadGooseRoute(newRoute)
        }
        .onChange(of: acpBridge.status) { _, _ in
            handleBridgeStatusChange()
        }
        .onChange(of: acpBridge.providersSyncedGeneration) { _, _ in
            reloadSurfaceAfterProviderSync()
        }
        .onDisappear {
            runtimeHealthTask?.cancel()
            supervisor.stop()
            gooseUIServer?.stop()
            nativePromptBridge.cancelPendingPrompts()
            nativeAffordanceBridge.closeAllApps()
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
            detailRow("native ACP Goose", nativeACPStatusLabel)
            detailRow("ACP", GooseRuntimeSupervisor.defaultBaseURL().absoluteString)
            detailRow("surface", Self.resolvedGooseUIIndex() == nil ? "UI bundle not staged" : "Goose Web UI")
            detailRow("UI origin", gooseUIServerStatusLabel)
            detailRow("custom ACP Goose", customACPStatusLabel)
            HStack(spacing: 8) {
                Button {
                    if router.isNative(.models) {
                        nativeModelsPresented = true
                    } else {
                        loadGooseRoute(GooseSurfaceRoute.models.webRoute)
                    }
                } label: {
                    Label("Manage models", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
                .help(router.isNative(.models) ? "Open native models picker" : "Open Goose models")
                Button { loadGooseRoute("/configure-providers") } label: {
                    Label("Providers", systemImage: "key")
                }
                .buttonStyle(.bordered)
                .help("Open Goose providers")
                if canRestartSurface {
                    Button { Task { await restartSurface() } } label: {
                        Label("Restart", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .help("Restart Goose")
                }
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

    private var nativeACPStatusLabel: String {
        switch acpBridge.status {
        case .idle:
            return "idle"
        case .connecting:
            return "connecting"
        case .connected(let agent):
            if let agent {
                if agent.name.localizedCaseInsensitiveContains("goose") {
                    return "ready (\(agent.version))"
                }
                return "ready (\(agent.name) \(agent.version))"
            }
            return "ready"
        case .failed(let message):
            return "error: \(message)"
        case .disconnected:
            return "disconnected"
        }
    }

    private var customACPStatusLabel: String {
        // HONESTY (deep-hardening 2026-06-29 H/false-ready): this row showed "ready" even when
        // the ACP bridge was idle/connecting/FAILED/disconnected (diagnostics-only check). Gate
        // on the real bridge status like nativeACPStatusLabel — "ready" ONLY when connected.
        switch acpBridge.status {
        case .idle:
            return "idle"
        case .connecting:
            return "connecting"
        case .connected:
            // L1: when genuinely connected the row reads exactly "custom ACP Goose ready" (the owner's
            // required string). Benign diagnostics (unhandled notifications / serverError entries that
            // KEEP the connection alive) must not flip it off "ready" — they are surfaced separately in
            // the diagnostics rows below. False-green is still prevented: "ready" requires .connected.
            return "ready"
        case .failed(let message):
            return "error: \(message)"
        case .disconnected:
            return "disconnected"
        }
    }

    private var gooseUIServerStatusLabel: String {
        guard let gooseUIServer else { return "not started" }
        switch gooseUIServer.status {
        case .idle:
            return "idle"
        case .starting:
            return "starting"
        case .running(let baseURL):
            return "live: \(baseURL.absoluteString)"
        case .failed(let message):
            return "error: \(message)"
        case .stopped:
            return "stopped"
        }
    }

    private var canRestartSurface: Bool {
        switch supervisor.status {
        case .failed, .stopped:
            return true
        default:
            return false
        }
    }

    private func startSurface() async {
        // Share the SAME registered-origin set with the affordance bridge so MCP-app launch URIs and
        // guest navigations are pinned to OUR server's exact loopback ports (review M1/M3), not any
        // loopback host. The reference is shared, so ports registered later (loadGooseUI) are visible.
        nativeAffordanceBridge.trustedLoopbackOrigins = trustedOrigins
        // Reset the per-connection drive guards: a reappear (.task re-runs) restarts the supervisor,
        // often on the SAME port/baseURL, so the new connection's key would otherwise match the stale
        // guard and driveSurface would skip the load. Resetting here re-drives every (re)appear.
        drivenConnectionKey = nil
        reloadedSyncForConnectionKey = nil
        supervisor.start(secretKey: secretKey)
        await loadWhenReady()
    }

    private func restartSurface() async {
        guard !isRestarting else { return }   // L3: a fast double-tap must not overlap two restarts
        isRestarting = true
        defer { isRestarting = false }
        drivenConnectionKey = nil
        reloadedSyncForConnectionKey = nil
        runtimeHealthTask?.cancel()
        runtimeHealthTask = nil
        gooseUIServer?.stop()
        gooseUIServer = nil
        await acpBridge.disconnect()
        nativePromptBridge.cancelPendingPrompts()
        loadPlaceholder()
        supervisor.stop()
        supervisor.start(secretKey: secretKey)
        await loadWhenReady()
    }

    private func handleRuntimeStatusChange(_ status: GooseRuntimeSupervisor.Status) {
        switch status {
        case .running(let connection):
            // H1: .running can arrive AFTER loadWhenReady's bounded poll gave up (goosed's readiness
            // budget is 45s, well past the 26s poll; serve on a slow cold start). Drive the surface
            // here too — idempotently, so the fast path where loadWhenReady already drove it never
            // double-loads. Without this the surface stuck permanently on the placeholder.
            driveSurface(connection: connection)
        case .failed, .unavailable:
            drivenConnectionKey = nil
            reloadedSyncForConnectionKey = nil
            runtimeHealthTask?.cancel()
            runtimeHealthTask = nil
            gooseUIServer?.stop()
            gooseUIServer = nil
            Task { await acpBridge.disconnect() }
            nativePromptBridge.cancelPendingPrompts()
            loadPlaceholder()
        default:
            break
        }
    }

    /// Idempotently connect the native ACP bridge + load the Web UI for a running connection. Safe to
    /// call from BOTH `loadWhenReady` (fast path) and the supervisor-status observer (late `.running`)
    /// — the `drivenConnectionKey` guard makes the surface load exactly once per connection.
    private func driveSurface(connection: GooseRuntimeConnection) {
        let key = connection.baseURL.absoluteString
        guard drivenConnectionKey != key else { return }
        drivenConnectionKey = key
        connectNativeACP(connection: connection)
        Task { await loadGooseUI(connection: connection) }
    }

    /// Review H2: the ACP bridge can terminally fail (N consecutive reconnects during a brief goose
    /// blip) while the supervisor stays `.running`. Provider key-sync only runs on a fresh connect, so
    /// a stuck-failed bridge means credentials never re-mirror and the picker/Auth break with nothing
    /// re-driving it. Re-drive the connect when the bridge is down but the runtime is healthy.
    /// `connect()` is idempotent (its `connectionKey` guard is cleared on terminal fail), so this is a
    /// no-op while connecting/connected and fires only once per terminal-fail transition.
    private func handleBridgeStatusChange() {
        guard case .running(let connection) = supervisor.status else { return }
        switch acpBridge.status {
        case .failed, .disconnected:
            connectNativeACP(connection: connection)
        default:
            break
        }
    }

    /// Review H3: the SPA may read Goose's provider/credential state BEFORE the native key-sync
    /// mirrored the keys, caching an empty / "Failed to load provider credentials" result that never
    /// self-heals. Once the sync completes, reload the SPA so it re-reads the populated state. Once
    /// per connection, so a mid-use reconnect-resync never disrupts active navigation.
    private func reloadSurfaceAfterProviderSync() {
        guard case .running(let connection) = supervisor.status else { return }
        let key = connection.baseURL.absoluteString
        guard reloadedSyncForConnectionKey != key,
              let gooseUIServer,
              case .running(let baseURL) = gooseUIServer.status else { return }
        reloadedSyncForConnectionKey = key
        // Reload to the CURRENT route, not a literal "/?" — otherwise this post-sync reload snaps the
        // WebView back to the hub while the native rail still highlights e.g. Sessions (rail/content desync).
        _ = page.load(URLRequest(url: Self.loopbackURL(baseURL: baseURL, route: activeRoute)))
    }

    private func loadWhenReady() async {
        for _ in 0..<260 {
            guard !Task.isCancelled else { return }
            switch supervisor.status {
            case .running(let connection):
                driveSurface(connection: connection)
                return
            case .unavailable, .failed:
                await acpBridge.disconnect()
                nativePromptBridge.cancelPendingPrompts()
                loadPlaceholder()
                return
            default:
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        // H1: don't strand on a dead placeholder — the supervisor may still be coming up (goosed can
        // exceed this poll budget). The supervisor-status observer (.running → driveSurface) loads the
        // surface when readiness finally arrives. Show the honest "starting" placeholder meanwhile.
        loadPlaceholder()
    }

    private func connectNativeACP(connection: GooseRuntimeConnection) {
        guard let url = connection.acpWebSocketURL else { return }
        acpBridge.connect(url: url)
    }

    private func loadGooseUI(connection: GooseRuntimeConnection) async {
        if let index = Self.resolvedGooseUIIndex() {
            beginRuntimeHealthMonitor(connection: connection)
            let root = index.deletingLastPathComponent()
            let server = WorkSPAServer(
                root: root,
                staticRoutes: Self.gooseStaticCompatibilityRoutes(),
                advertisedHost: "127.0.0.1"
            )
            gooseUIServer?.stop()
            gooseUIServer = server
            do {
                try server.start()
            } catch {
                _ = page.load(html: Self.placeholderHTML(status: "Goose Web UI server failed: \(error.localizedDescription)", acpURL: connection.acpWebSocketURL?.absoluteString ?? ""))
                return
            }
            // H1: register the live loopback origins this surface may navigate to — the
            // goose/goosed server and the WorkSPA UI server. Any other loopback page is denied.
            trustedOrigins.register(connection.baseURL)
            trustedOrigins.register(connection.acpWebSocketURL)
            if case .running(let uiBaseURL) = server.status {
                trustedOrigins.register(uiBaseURL)
            }
            await loadGooseUIWhenReady(server, acpURL: connection.acpWebSocketURL?.absoluteString ?? "")
        } else {
            _ = page.load(html: Self.placeholderHTML(status: statusLabel, acpURL: connection.acpWebSocketURL?.absoluteString ?? ""))
        }
    }

    private func beginRuntimeHealthMonitor(connection: GooseRuntimeConnection) {
        runtimeHealthTask?.cancel()
        runtimeHealthTask = Task { [baseURL = connection.baseURL] in
            var missedChecks = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                if await GooseRuntimeSupervisor.healthCheck(base: baseURL) {
                    missedChecks = 0
                } else {
                    missedChecks += 1
                    if missedChecks >= 2 {
                        supervisor.markRuntimeFailed("Goose health check failed after the Web UI loaded.")
                        return
                    }
                }
            }
        }
    }

    private func loadGooseRoute(_ route: String) {
        guard let gooseUIServer,
              case .running(let baseURL) = gooseUIServer.status else { return }
        _ = page.load(URLRequest(url: Self.loopbackURL(baseURL: baseURL, route: route)))
    }

    private func loadPlaceholder() {
        _ = page.load(html: Self.placeholderHTML(status: statusLabel, acpURL: ""))
    }

    private static func makePage(
        bootstrap: GooseWebBootstrap,
        gooseUIRoot: URL?,
        nativePromptBridge: GooseWebNativePromptBridge,
        nativeAffordanceBridge: GooseWebNativeAffordanceBridge,
        trustedOrigins: GooseTrustedLoopbackOrigins
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
            configuration.urlSchemeHandlers[scheme] = WorkSPASchemeHandler(
                root: gooseUIRoot,
                virtualBasePath: gooseUISurfaceVirtualBasePath
            )
        }
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: GooseWebBootShim.bootstrapScript(for: bootstrap) + "\n" + nativeFeelScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        // Pin loopback navigation to OUR servers: the goose/goosed origin is known now; the
        // WorkSPA UI-server origin is registered when it starts (loadGooseUI). H1.
        trustedOrigins.register(bootstrap.baseURL)
        return WebPage(configuration: configuration, navigationDecider: GooseNavigationDecider(trustedOrigins: trustedOrigins))
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
            nativeAffordanceBridge: nativeAffordanceBridge,
            trustedOrigins: GooseTrustedLoopbackOrigins()
        )
    }

    private static func resolvedGooseUIIndex() -> URL? {
        GooseWebUIResolver.indexURL()
    }

    private static func resolvedGooseUIRoot() -> URL? {
        resolvedGooseUIIndex()?.deletingLastPathComponent()
    }

    nonisolated static func bootURL(for _: URL) -> URL {
        surfaceURL(hashRoute: "/?")
    }

    nonisolated static func routeURL(_ route: String) -> URL {
        let normalizedRoute = route.hasPrefix("/") ? route : "/\(route)"
        return surfaceURL(hashRoute: normalizedRoute)
    }

    nonisolated static func loopbackURL(baseURL: URL, route: String) -> URL {
        let normalizedRoute = route.hasPrefix("/") ? route : "/\(route)"
        var absolute = baseURL.absoluteString
        if !absolute.hasSuffix("/") {
            absolute += "/"
        }
        // review C-L1: percent-encode the route fragment (a future route with stray chars must not be
        // able to make URL(string:) return nil) and fall back to the always-valid baseURL instead of
        // force-unwrapping.
        let fragment = normalizedRoute.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? ""
        return URL(string: "\(absolute)?v=\(gooseUISurfaceCacheToken)#\(fragment)") ?? baseURL
    }

    nonisolated static func gooseStaticCompatibilityRoutes() -> [WorkSPAStaticRoute] {
        [
            WorkSPAStaticRoute(
                path: "/agent/list_apps",
                contentType: "application/json; charset=utf-8",
                body: Data(#"{"apps":[]}"#.utf8)
            ),
        ]
    }

    nonisolated private static func surfaceURL(hashRoute: String) -> URL {
        // review C-L1: percent-encode the route fragment and degrade to the route-less surface URL
        // instead of force-unwrapping; the final fileURL fallback is unreachable (the base is built
        // from known-valid constants) but keeps this non-force-unwrapping.
        let base = "\(gooseUISchemeName)://\(gooseUISurfaceHost)\(gooseUISurfaceVirtualBasePath)/?v=\(gooseUISurfaceCacheToken)"
        let fragment = hashRoute.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? ""
        return URL(string: "\(base)#\(fragment)") ?? URL(string: base) ?? URL(fileURLWithPath: "/")
    }

    private func loadGooseUIWhenReady(_ server: WorkSPAServer, acpURL: String) async {
        for _ in 0..<80 {
            guard !Task.isCancelled else { return }
            switch server.status {
            case .running(let baseURL):
                // Read `activeRoute` at the actual load instant (not a value captured when this task
                // began) so a rail click made WHILE the UI server was coming up is honored, not dropped.
                _ = page.load(URLRequest(url: Self.loopbackURL(baseURL: baseURL, route: activeRoute)))
                return
            case .failed(let message):
                _ = page.load(html: Self.placeholderHTML(status: "Goose Web UI server failed: \(message)", acpURL: acpURL))
                return
            default:
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }
        _ = page.load(html: Self.placeholderHTML(status: "Goose Web UI server timed out", acpURL: acpURL))
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

/// SECURITY (deep-hardening 2026-06-29 H1): the trusted loopback origins (the WorkSPA UI
/// server + the goose/goosed server) are the ONLY http/ws origins the surface may navigate
/// to. Allowing ANY 127.0.0.1/localhost/::1 page would let a foreign local page (reached via
/// a plain link or tool/MCP-influenced `window.location`) inherit the injected boot shim —
/// including `getSecretKey()` and the native FS bridge. We pin to the exact registered ports.
final class GooseTrustedLoopbackOrigins: @unchecked Sendable {
    private let lock = NSLock()
    private var ports: Set<Int> = []

    static func isLoopback(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "127.0.0.1" || host == "localhost" || host == "::1"
    }

    func register(_ url: URL?) {
        guard let url, let port = url.port, Self.isLoopback(url.host) else { return }
        lock.lock(); ports.insert(port); lock.unlock()
    }

    func isAllowed(_ url: URL) -> Bool {
        guard Self.isLoopback(url.host), let port = url.port else { return false }
        lock.lock(); defer { lock.unlock() }
        return ports.contains(port)
    }
}

private struct GooseNavigationDecider: WebPage.NavigationDeciding {
    let trustedOrigins: GooseTrustedLoopbackOrigins

    func decidePolicy(
        for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences
    ) async -> WKNavigationActionPolicy {
        guard let url = action.request.url else { return .cancel }
        switch url.scheme?.lowercased() {
        // The trusted Goose surface only ever loads via its custom scheme and the
        // loopback http server (handled below). `file:` is never used and is
        // needless local-file navigation surface, so it is not allow-listed.
        case "about", GooseWebSurfaceView.gooseUISchemeName:
            return .allow
        case "http", "https", "ws", "wss":
            // Loopback alone is NOT enough — must be one of OUR registered server ports.
            return trustedOrigins.isAllowed(url) ? .allow : .cancel
        default:
            return .cancel
        }
    }
}
