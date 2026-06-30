import SwiftUI
import WebKit

struct GooseWebSurfaceView: View {
    nonisolated static let gooseUISurfaceCacheToken = UUID().uuidString
    nonisolated static let gooseUISchemeName =
        "epistemos-goose-\(gooseUISurfaceCacheToken.lowercased())"
    nonisolated static let gooseUISurfaceHost =
        "app-\(gooseUISurfaceCacheToken.lowercased())"
    nonisolated static let gooseUISurfaceVirtualBasePath =
        "/__epistemos-goose/\(gooseUISurfaceCacheToken)"
    nonisolated static let maxGooseRouteCharacters = 4096
    nonisolated static let maxPlaceholderStatusCharacters = 512
    nonisolated static let initialRuntimeRetryDelayNanoseconds: UInt64 = 450_000_000
    nonisolated static let maximumRuntimeRetryDelayNanoseconds: UInt64 = 5_000_000_000
    nonisolated static let initialWebUIRenderRetryDelayNanoseconds: UInt64 = 300_000_000
    nonisolated static let maximumWebUIRenderRetryDelayNanoseconds: UInt64 = 3_000_000_000
    nonisolated static let webUINavigationTimeoutNanoseconds: UInt64 = 12_000_000_000
    nonisolated static let webUIRenderProbeCount = 80
    nonisolated static let webUIRenderProbeIntervalNanoseconds: UInt64 = 150_000_000
    nonisolated static let startingStatus = "Goose starting. Waiting for runtime and ACP."
    nonisolated static let waitingForACPStatus = "Goose Web UI waiting for runtime"
    nonisolated static let loadingWebUIStatus = "Loading Goose Web UI"

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
    @State private var pageBootstrapConnectionKey: String
    @State private var runtimeRetryTask: Task<Void, Never>?
    @State private var runtimeRetryAttempt = 0
    @State private var webUILoadTask: Task<Void, Never>?
    @State private var webUIRenderOverlayStatus: String?
    @State private var webUIRenderProbeLastResult: String?
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
    @State private var loadedUIForConnectionKey: String?
    @State private var reloadedSyncForConnectionKey: String?
    @State private var surfaceStarted = false
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
        _activeRoute = State(initialValue: Self.normalizedGooseRoute(route))
        let page = Self.makePage(
            bootstrap: bootstrap,
            gooseUIRoot: Self.resolvedGooseUIRoot(),
            nativePromptBridge: nativePromptBridge,
            nativeAffordanceBridge: nativeAffordanceBridge,
            trustedOrigins: trustedOrigins
        )
        _ = page.load(html: Self.placeholderHTML(status: Self.startingStatus, acpURL: ""))
        _page = State(initialValue: page)
        _pageBootstrapConnectionKey = State(initialValue: bootstrap.baseURL.absoluteString)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WebView(page)
                .background(background)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let webUIRenderOverlayStatus {
                webUIRenderOverlay(status: webUIRenderOverlayStatus)
            }
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
            let normalizedRoute = Self.normalizedGooseRoute(newRoute)
            activeRoute = normalizedRoute
            loadGooseRoute(normalizedRoute)
        }
        .onChange(of: acpBridge.status) { _, _ in
            handleBridgeStatusChange()
        }
        .onChange(of: acpBridge.providersSyncedGeneration) { _, _ in
            reloadSurfaceAfterProviderSync()
        }
        .onDisappear {
            runtimeHealthTask?.cancel()
            runtimeRetryTask?.cancel()
            runtimeRetryTask = nil
            webUILoadTask?.cancel()
            webUILoadTask = nil
            supervisor.stop()
            gooseUIServer?.stop()
            surfaceStarted = false
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
            if let webUIRenderProbeLastResult {
                detailRow("render probe", webUIRenderProbeLastResult)
            }
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

    private func webUIRenderOverlay(status: String) -> some View {
        ZStack {
            background
            VStack(alignment: .leading, spacing: 9) {
                Text("Epistemos Goose")
                    .font(GooseSurfaceStyle.bodyFont(16, weight: .semibold))
                    .foregroundStyle(theme.resolved.foreground.color)
                Text(status)
                    .font(GooseSurfaceStyle.bodyFont(12))
                    .foregroundStyle(theme.mutedForeground)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        guard !surfaceStarted else {
            if case .running(let connection) = supervisor.status {
                driveSurface(connection: connection)
            }
            return
        }
        surfaceStarted = true
        // Share the SAME registered-origin set with the affordance bridge so MCP-app launch URIs and
        // guest navigations are pinned to OUR server's exact loopback ports (review M1/M3), not any
        // loopback host. The reference is shared, so ports registered later (loadGooseUI) are visible.
        nativeAffordanceBridge.trustedLoopbackOrigins = trustedOrigins
        // Reset the per-connection drive guards: a reappear (.task re-runs) restarts the supervisor,
        // often on the SAME port/baseURL, so the new connection's key would otherwise match the stale
        // guard and driveSurface would skip the load. Resetting here re-drives every (re)appear.
        drivenConnectionKey = nil
        loadedUIForConnectionKey = nil
        reloadedSyncForConnectionKey = nil
        runtimeRetryTask?.cancel()
        runtimeRetryTask = nil
        runtimeRetryAttempt = 0
        webUILoadTask?.cancel()
        webUILoadTask = nil
        webUIRenderOverlayStatus = nil
        webUIRenderProbeLastResult = nil
        loadPlaceholder(status: Self.startingStatus)
        supervisor.start(secretKey: secretKey, allowPortFallback: true)
        await loadWhenReady()
    }

    private func restartSurface() async {
        guard !isRestarting else { return }   // L3: a fast double-tap must not overlap two restarts
        isRestarting = true
        defer { isRestarting = false }
        drivenConnectionKey = nil
        loadedUIForConnectionKey = nil
        reloadedSyncForConnectionKey = nil
        runtimeHealthTask?.cancel()
        runtimeHealthTask = nil
        runtimeRetryTask?.cancel()
        runtimeRetryTask = nil
        runtimeRetryAttempt = 0
        webUILoadTask?.cancel()
        webUILoadTask = nil
        webUIRenderOverlayStatus = nil
        webUIRenderProbeLastResult = nil
        gooseUIServer?.stop()
        gooseUIServer = nil
        await acpBridge.disconnect()
        nativePromptBridge.cancelPendingPrompts()
        loadPlaceholder(status: Self.startingStatus)
        supervisor.stop()
        supervisor.start(secretKey: secretKey, allowPortFallback: true)
        await loadWhenReady()
    }

    private func handleRuntimeStatusChange(_ status: GooseRuntimeSupervisor.Status) {
        switch status {
        case .running(let connection):
            runtimeRetryTask?.cancel()
            runtimeRetryTask = nil
            runtimeRetryAttempt = 0
            // H1: .running can arrive AFTER loadWhenReady's bounded poll gave up (goosed's readiness
            // budget is 45s, well past the 26s poll; serve on a slow cold start). Drive the surface
            // here too — idempotently, so the fast path where loadWhenReady already drove it never
            // double-loads. Without this the surface stuck permanently on the placeholder.
            driveSurface(connection: connection)
        case .failed(let message):
            drivenConnectionKey = nil
            loadedUIForConnectionKey = nil
            reloadedSyncForConnectionKey = nil
            runtimeHealthTask?.cancel()
            runtimeHealthTask = nil
            webUILoadTask?.cancel()
            webUILoadTask = nil
            webUIRenderOverlayStatus = nil
            webUIRenderProbeLastResult = nil
            gooseUIServer?.stop()
            gooseUIServer = nil
            Task { await acpBridge.disconnect() }
            nativePromptBridge.cancelPendingPrompts()
            loadPlaceholder(status: "Goose runtime retrying: \(message)")
            scheduleRuntimeRetry(reason: message)
        case .unavailable(let message):
            drivenConnectionKey = nil
            loadedUIForConnectionKey = nil
            reloadedSyncForConnectionKey = nil
            runtimeHealthTask?.cancel()
            runtimeHealthTask = nil
            runtimeRetryTask?.cancel()
            runtimeRetryTask = nil
            webUILoadTask?.cancel()
            webUILoadTask = nil
            webUIRenderOverlayStatus = nil
            webUIRenderProbeLastResult = nil
            gooseUIServer?.stop()
            gooseUIServer = nil
            Task { await acpBridge.disconnect() }
            nativePromptBridge.cancelPendingPrompts()
            loadPlaceholder(status: message)
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
        rebuildPageIfNeeded(for: connection)
        drivenConnectionKey = key
        connectNativeACP(connection: connection)
        webUILoadTask?.cancel()
        webUILoadTask = Task { await loadGooseUI(connection: connection) }
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
        case .connected:
            break
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
              loadedUIForConnectionKey == key,
              let gooseUIServer,
              case .running(let baseURL) = gooseUIServer.status else { return }
        reloadedSyncForConnectionKey = key
        // Reload to the CURRENT route, not a literal "/?" — otherwise this post-sync reload snaps the
        // WebView back to the hub while the native rail still highlights e.g. Sessions (rail/content desync).
        loadBootstrappedGooseUI(baseURL: baseURL, connection: connection, route: activeRoute)
    }

    private func loadWhenReady() async {
        for _ in 0..<260 {
            guard !Task.isCancelled else { return }
            switch supervisor.status {
            case .running(let connection):
                driveSurface(connection: connection)
                return
            case .failed(let message):
                await acpBridge.disconnect()
                nativePromptBridge.cancelPendingPrompts()
                loadPlaceholder(status: "Goose runtime retrying: \(message)")
                scheduleRuntimeRetry(reason: message)
                return
            case .unavailable(let message):
                await acpBridge.disconnect()
                nativePromptBridge.cancelPendingPrompts()
                loadPlaceholder(status: message)
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
            let bootstrap = GooseWebBootstrap(baseURL: connection.baseURL, secretKey: secretKey)
            let staticRoutes = Self.gooseStaticCompatibilityRoutes(
                bootstrappedIndexHTML: Self.bootstrappedGooseUIHTML(
                    indexURL: index,
                    bootstrap: bootstrap
                )
            )
            let server = WorkSPAServer(
                root: root,
                staticRoutes: staticRoutes,
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
            await loadGooseUIWhenReady(server, connection: connection, indexURL: index)
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
              case .running(let baseURL) = gooseUIServer.status,
              case .running(let connection) = supervisor.status else { return }
        loadBootstrappedGooseUI(baseURL: baseURL, connection: connection, route: route)
    }

    private func loadBootstrappedGooseUI(baseURL: URL, connection: GooseRuntimeConnection, route: String) {
        trustedOrigins.register(baseURL)
        trustedOrigins.register(connection.baseURL)
        trustedOrigins.register(connection.acpWebSocketURL)
        _ = page.load(URLRequest(url: Self.loopbackURL(baseURL: baseURL, route: route)))
    }

    private func loadPlaceholder(status: String? = nil, acpURL: String = "") {
        _ = page.load(html: Self.placeholderHTML(status: status ?? statusLabel, acpURL: acpURL))
    }

    private func rebuildPageIfNeeded(for connection: GooseRuntimeConnection) {
        let key = connection.baseURL.absoluteString
        guard pageBootstrapConnectionKey != key else { return }
        let bootstrap = GooseWebBootstrap(baseURL: connection.baseURL, secretKey: secretKey)
        let nextPage = Self.makePage(
            bootstrap: bootstrap,
            gooseUIRoot: Self.resolvedGooseUIRoot(),
            nativePromptBridge: nativePromptBridge,
            nativeAffordanceBridge: nativeAffordanceBridge,
            trustedOrigins: trustedOrigins
        )
        _ = nextPage.load(html: Self.placeholderHTML(
            status: Self.waitingForACPStatus,
            acpURL: connection.acpWebSocketURL?.absoluteString ?? ""
        ))
        page = nextPage
        pageBootstrapConnectionKey = key
    }

    private func scheduleRuntimeRetry(reason _: String) {
        guard runtimeRetryTask == nil else { return }
        let retryAttempt = runtimeRetryAttempt
        runtimeRetryAttempt += 1
        let delay = Self.runtimeRetryDelayNanoseconds(for: retryAttempt)
        runtimeRetryTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            runtimeRetryTask = nil
            drivenConnectionKey = nil
            loadedUIForConnectionKey = nil
            reloadedSyncForConnectionKey = nil
            runtimeHealthTask?.cancel()
            runtimeHealthTask = nil
            webUILoadTask?.cancel()
            webUILoadTask = nil
            webUIRenderOverlayStatus = nil
            webUIRenderProbeLastResult = nil
            gooseUIServer?.stop()
            gooseUIServer = nil
            await acpBridge.disconnect()
            nativePromptBridge.cancelPendingPrompts()
            loadPlaceholder(status: Self.startingStatus)
            supervisor.stop()
            supervisor.start(secretKey: secretKey, allowPortFallback: true)
            await loadWhenReady()
        }
    }

    private func loadGooseUIWhenReady(
        _ server: WorkSPAServer,
        connection: GooseRuntimeConnection,
        indexURL _: URL
    ) async {
        let connectionKey = connection.baseURL.absoluteString
        let acpURL = connection.acpWebSocketURL?.absoluteString ?? ""
        guard loadedUIForConnectionKey != connectionKey else { return }
        webUIRenderProbeLastResult = nil
        _ = page.load(html: Self.placeholderHTML(status: Self.waitingForACPStatus, acpURL: acpURL))
        var renderAttempt = 0
        while true {
            guard !Task.isCancelled else { return }
            switch server.status {
            case .running(let baseURL):
                if await Self.gooseUIReady(baseURL: baseURL),
                   await Self.runtimeHealthReady(baseURL: connection.baseURL) {
                    guard loadedUIForConnectionKey != connectionKey else { return }
                    trustedOrigins.register(baseURL)
                    trustedOrigins.register(connection.baseURL)
                    trustedOrigins.register(connection.acpWebSocketURL)
                    webUIRenderOverlayStatus = renderAttempt == 0
                        ? Self.loadingWebUIStatus
                        : "Goose Web UI render retry \(renderAttempt)"
                    // Read `activeRoute` at the actual load instant (not a value captured when this task
                    // began) so a rail click made WHILE the UI server was coming up is honored, not dropped.
                    let request = URLRequest(url: Self.loopbackURL(baseURL: baseURL, route: activeRoute))
                    webUIRenderOverlayStatus = nil
                    _ = page.load(request)
                    if await waitForRenderedGooseUI(connectionKey: connectionKey) {
                        loadedUIForConnectionKey = connectionKey
                        webUIRenderOverlayStatus = nil
                        webUIRenderProbeLastResult = "ready"
                        return
                    }
                    renderAttempt += 1
                    let delay = Self.webUIRenderRetryDelayNanoseconds(for: renderAttempt)
                    let probe = webUIRenderProbeLastResult ?? "blank"
                    webUIRenderOverlayStatus = "Goose Web UI stayed blank (\(probe)). Retrying."
                    if delay > 0 {
                        try? await Task.sleep(nanoseconds: delay)
                    }
                }
            case .failed(let message):
                webUIRenderOverlayStatus = nil
                webUIRenderProbeLastResult = nil
                _ = page.load(html: Self.placeholderHTML(status: "Goose Web UI server failed: \(message)", acpURL: acpURL))
                return
            case .stopped:
                webUIRenderOverlayStatus = nil
                webUIRenderProbeLastResult = nil
                return
            default:
                break
            }
            try? await Task.sleep(nanoseconds: 160_000_000)
        }
    }

    private func waitForRenderedGooseUI(connectionKey: String) async -> Bool {
        for _ in 0..<Self.webUIRenderProbeCount {
            guard !Task.isCancelled else { return false }
            if loadedUIForConnectionKey == connectionKey { return true }
            let result = await gooseUIRenderProbe()
            webUIRenderProbeLastResult = result
            if result == "ready" { return true }
            try? await Task.sleep(nanoseconds: Self.webUIRenderProbeIntervalNanoseconds)
        }
        return loadedUIForConnectionKey == connectionKey
    }

    private func gooseUIRenderProbe() async -> String {
        do {
            let value = try await page.callJavaScript(Self.gooseUIRenderProbeScript)
            return (value as? String) ?? "unexpected-probe-result"
        } catch {
            return "probe-error:\(Self.boundedPlaceholderStatus(error.localizedDescription))"
        }
    }

}
