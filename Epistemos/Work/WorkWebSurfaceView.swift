import AppKit
import SwiftUI
import WebKit

// Owner target (2026-06-25): a flat, OpenCode-like Work host. The WebView fills the window; native Epistemos
// status chrome lives behind a side-panel toggle so capability stays present without wrapping the engine in an
// inset card. The bundled Work UI remains driven by local loopback runtimes and native MCP wiring.

struct WorkWebSurfaceView: View {
    /// Theme is passed in (the app passes `ui.theme`); defaults to the native theme so the view is
    /// self-contained + previewable without UIState.
    var theme: EpistemosTheme = .nativeDefault
    /// The active Epistemos vault root. When present, the Work runtime and native app-tool bridge root here so
    /// vault notes, note writes, skills, and graph context are the user's real app data, not a detached preview dir.
    var epistemosVaultRoot: URL?

    @State private var page = WebPage()
    @State private var supervisor = WorkRuntimeSupervisor()
    /// The Epistemos-managed loopback server that serves the OpenWork SPA to this WebView (owner: loopback-serve).
    @State private var spaServer: WorkSPAServer?
    /// The local OpenWork worker (apps/server runtime) — its URL+token seed the SPA so it auto-connects.
    @State private var workerSupervisor = WorkOpenWorkSupervisor()
    @State private var nativeMCPStatusLabel = "not started"
    @State private var showSurfaceDetails = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            webSurface
            if showSurfaceDetails {
                detailsPanel
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(2)
            } else {
                detailsToggle
                    .padding(.top, 10)
                    .padding(.trailing, 12)
                    .zIndex(1)
            }
        }
        .background(boxBackground)
        .animation(.snappy(duration: 0.16), value: showSurfaceDetails)
        .task { await startSurface() }
        .onChange(of: supervisorStatusKey) { _, _ in
            // Runtime-status changes only drive the no-SPA fallback (placeholder / loopback runtime).
            if Self.resolvedSPARoot() == nil { loadForStatus() }
        }
        .onDisappear {
            // Kill-on-teardown: don't leak the worker process or the loopback asset server when Work closes.
            workerSupervisor.stop()
            spaServer?.stop()
        }
    }

    // MARK: Native fused chrome (side-panel toggle)

    private var detailsToggle: some View {
        Button {
            showSurfaceDetails = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.mutedForeground)
                .frame(width: 30, height: 30)
                .background(
                    Rectangle()
                        .fill(WorkSurfaceStyle.background(for: theme, role: .rail).opacity(0.92))
                )
                .overlay(
                    Rectangle()
                        .stroke(theme.border.opacity(0.58), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help("Work details")
        .accessibilityLabel("Work details")
    }

    private var detailsPanel: some View {
        WorkWebSurfaceDetailsPanel(
            theme: theme,
            statusLabel: statusLabel,
            workerStatusLabel: workerStatusLabel,
            spaStatusLabel: spaStatusLabel,
            nativeMCPStatusLabel: nativeMCPStatusLabel,
            surfaceLabel: surfaceLabel,
            workspaceLabel: workspaceLabel,
            close: { showSurfaceDetails = false }
        )
    }

    // MARK: The flat web host (new WebView)

    private var webSurface: some View {
        WebView(page)
            .background(boxBackground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var boxBackground: Color { WorkSurfaceStyle.background(for: theme) }

    // MARK: Status + loading

    private var statusLabel: String {
        switch supervisor.status {
        case .idle: return "idle"
        case .unavailable: return "runtime not bundled"
        case .starting: return "starting runtime…"
        case .running: return "runtime live"
        case .failed: return "runtime error"
        case .stopped: return "stopped"
        }
    }

    private var workerStatusLabel: String {
        switch workerSupervisor.status {
        case .idle:
            return "idle"
        case .unavailable(let message):
            return "unavailable: \(message)"
        case .starting:
            return "starting"
        case .running(let baseURL, _):
            return "live: \(baseURL.absoluteString)"
        case .failed(let message):
            return "error: \(message)"
        case .stopped:
            return "stopped"
        }
    }

    private var spaStatusLabel: String {
        guard let spaServer else { return "not started" }
        switch spaServer.status {
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

    private var surfaceLabel: String {
        Self.resolvedSPARoot() == nil ? "Epistemos Work fallback" : "Epistemos Work surface"
    }

    private var workspaceLabel: String {
        epistemosVaultRoot?.path ?? "managed Work runtime workspace"
    }

    /// A stable key so `.onChange` fires on status transitions (Status isn't Hashable-by-default in views).
    private var supervisorStatusKey: String { statusLabel }

    private func startSurface() async {
        // Owner 2026-06-24: LOOPBACK-SERVE. When the OpenWork SPA is available, start the Epistemos-managed
        // loopback server and point the WebView at its real http origin (no env var, no custom scheme — the donor
        // app runs in its natural habitat). Otherwise fall back to the honest behavior: the live loopback OpenCode
        // runtime if bundled, else the themed placeholder.
        if let root = Self.resolvedSPARoot() {
            // Start the local OpenWork worker (the runtime) and seed its URL+token into the SPA so it
            // auto-connects (no manual "Connect custom remote"). nil bootstrap → SPA serves token-less (honest
            // connect-remote fallback if the worker can't start).
            let workRoot = Self.toolWorkspace(epistemosVaultRoot: epistemosVaultRoot)
            workerSupervisor.start(vaultRoot: workRoot)
            let bootstrap = await awaitWorkerBootstrap()
            nativeMCPStatusLabel = bootstrap == nil ? "worker unavailable" : "pending"
            // Reskin: serve the SPA with the Epistemos palette injected as a <style> (CSS-var override, no rebuild).
            let server = WorkSPAServer(
                root: root, bootstrap: bootstrap,
                reskinCSS: WorkSPAReskin.styleBlock(theme: theme.resolved))
            spaServer = server
            do {
                try server.start()
            } catch {
                _ = page.load(html: placeholderHTML)
                return
            }
            await loadSPAWhenReady(server)
            // W-R3: once the SPA is up + the worker is running, register the app-hosted native-tools MCP with the
            // worker's managed OpenCode so the agent can call the FULL native Epistemos tool surface (not just the
            // vault MCP). Runs AFTER the SPA renders → never blocks first paint. nil bootstrap = worker didn't
            // start → skip (honest: agent keeps the vault MCP only).
            if let bootstrap, let workRoot {
                await provisionNativeMCP(bootstrap: bootstrap, workspace: workRoot)
            } else if bootstrap != nil {
                nativeMCPStatusLabel = "workspace unavailable"
            }
        } else {
            nativeMCPStatusLabel = "fallback runtime"
            supervisor.start()
            loadForStatus()
        }
    }

    /// W-R3 option-B wiring (mechanism runtime-proven 2026-06-24): start the app-hosted native-tools MCP
    /// (`WorkNativeMCPHost`, production composed executor, rooted at the worker's workspace) and register it with
    /// the worker's managed OpenCode via `WorkOpenWorkProvisioner`. Best-effort + non-fatal: any failure leaves the
    /// agent with the vault MCP only. The native server MUST be listening before the POST (the worker blocks the
    /// registration on connecting it) — `startAndAwaitRegistration` guarantees that ordering.
    private func provisionNativeMCP(bootstrap: WorkSPABootstrap, workspace: URL) async {
        nativeMCPStatusLabel = "starting"
        guard let workerBaseURL = URL(string: bootstrap.workerURL) else {
            nativeMCPStatusLabel = "invalid worker URL"
            return
        }
        guard let registration = await WorkNativeMCPHost.shared.startAndAwaitRegistration(vaultRoot: workspace)
        else {
            nativeMCPStatusLabel = "native bridge unavailable"
            return
        }
        let registered = await WorkOpenWorkProvisioner.registerNativeMCP(
            workerBaseURL: workerBaseURL,
            workerToken: bootstrap.token,
            workspacePath: workspace.path,
            nativeURL: registration.url,
            nativeToken: registration.token)
        nativeMCPStatusLabel = registered ? "registered" : "registration failed"
    }

    /// Wait for the OpenWork worker to come up, then return its URL+token bootstrap; nil if it can't start
    /// (unavailable/failed/timeout) → the SPA serves token-less (honest "Connect custom remote" fallback).
    private func awaitWorkerBootstrap() async -> WorkSPABootstrap? {
        for _ in 0..<250 {
            switch workerSupervisor.status {
            case .running(let baseURL, let token):
                return WorkSPABootstrap(
                    workerURL: baseURL.absoluteString, token: token,
                    themePref: theme.isDark ? "dark" : "light")
            case .unavailable, .failed:
                return nil
            default:
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        return nil
    }

    /// The OpenWork worker's workspace root — an Epistemos-managed dir (created on demand).
    nonisolated static func toolWorkspace(epistemosVaultRoot: URL?) -> URL? {
        epistemosVaultRoot ?? workerWorkspace()
    }

    nonisolated private static func workerWorkspace() -> URL? {
        let fileManager = FileManager.default
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        else { return nil }
        let workspace = appSupport.appendingPathComponent("Epistemos/WorkRuntime/workspace", isDirectory: true)
        try? fileManager.createDirectory(at: workspace, withIntermediateDirectories: true)
        return workspace
    }

    /// Wait for the loopback server to bind, then load its base URL into the WebView; honest placeholder on timeout.
    private func loadSPAWhenReady(_ server: WorkSPAServer) async {
        for _ in 0..<60 {
            if case .running(let baseURL) = server.status {
                _ = page.load(URLRequest(url: baseURL))
                return
            }
            try? await Task.sleep(nanoseconds: 80_000_000)
        }
        _ = page.load(html: placeholderHTML)
    }

    private func loadForStatus() {
        // No-SPA fallback: the live loopback OpenCode runtime if running, else the themed placeholder.
        if case .running(let baseURL) = supervisor.status {
            var request = URLRequest(url: baseURL)
            if let auth = supervisor.auth {
                request.setValue(auth.basicAuthHeaderValue, forHTTPHeaderField: "Authorization")
            }
            _ = page.load(request)
        } else {
            _ = page.load(html: placeholderHTML)
        }
    }

    // MARK: Loopback-serve — the OpenWork SPA root (Epistemos-managed, NO env var)

    /// The built OpenWork SPA `dist/` Epistemos serves over loopback, if present — resolved from the
    /// Epistemos-managed Application Support location `Epistemos/WorkSPA/dist` (NO manual env var; resolves to the
    /// app's container when sandboxed, `~/Library/Application Support` for the non-sandboxed debug build). Release
    /// will populate it from a bundled copy / the runtime. nil → honest placeholder. A valid root has `index.html`.
    nonisolated static func resolvedSPARoot() -> URL? {
        let fileManager = FileManager.default
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        else { return nil }
        let root = appSupport.appendingPathComponent("Epistemos/WorkSPA/dist", isDirectory: true)
        return fileManager.fileExists(atPath: root.appendingPathComponent("index.html").path) ? root : nil
    }

    /// A themed placeholder so the flat host shows integrated content while the bundled Work UI is unavailable.
    private var placeholderHTML: String {
        let bg = Self.cssHex(WorkSurfaceStyle.backgroundNSColor(for: theme))
        let fg = Self.cssHex(theme.resolved.foreground.nsColor)
        let muted = Self.cssHex(theme.resolved.mutedForeground.nsColor)
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
          :root { color-scheme: \(theme.isDark ? "dark" : "light"); }
          html,body { margin:0; height:100%; background:\(bg); color:\(fg);
            font:14px ui-monospace,SFMono-Regular,Menlo,monospace; }
          .wrap { height:100%; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:8px; }
          .title { font-size:15px; font-weight:600; }
          .muted { color:\(muted); font-size:12px; }
        </style></head>
        <body><div class="wrap">
          <div class="title">Epistemos Work</div>
          <div class="muted">Local engine bridge over loopback</div>
          <div class="muted">Theme-aware native fallback; full Work surface loads when bundled</div>
        </div></body></html>
        """
    }

    private static func cssHex(_ color: NSColor) -> String {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int((srgb.redComponent * 255).rounded())
        let g = Int((srgb.greenComponent * 255).rounded())
        let b = Int((srgb.blueComponent * 255).rounded())
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}

private struct WorkWebSurfaceDetailsPanel: View {
    var theme: EpistemosTheme
    var statusLabel: String
    var workerStatusLabel: String
    var spaStatusLabel: String
    var nativeMCPStatusLabel: String
    var surfaceLabel: String
    var workspaceLabel: String
    var close: () -> Void

    private var accent: Color { theme.resolved.accent.color }
    private var panelBackground: Color { WorkSurfaceStyle.background(for: theme, role: .rail) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                Text("Epistemos Work")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.resolved.foreground.color)
                Spacer(minLength: 0)
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.mutedForeground)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close details")
                .accessibilityLabel("Close details")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Rectangle()
                .fill(theme.border.opacity(0.58))
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    detailRow("surface", surfaceLabel)
                    detailRow("runtime", statusLabel)
                    detailRow("worker", workerStatusLabel)
                    detailRow("spa", spaStatusLabel)
                    detailRow("native tools", nativeMCPStatusLabel)
                    detailRow("workspace", workspaceLabel, lineLimit: 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
            }
        }
        .frame(width: 304)
        .frame(maxHeight: .infinity)
        .background(panelBackground.opacity(0.98))
        .overlay(
            Rectangle()
                .stroke(theme.border.opacity(0.7), lineWidth: 1)
        )
    }

    private func detailRow(_ label: String, _ value: String, lineLimit: Int = 2) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.resolved.foreground.color.opacity(0.88))
                .lineLimit(lineLimit)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    WorkWebSurfaceView()
        .frame(width: 760, height: 520)
}
