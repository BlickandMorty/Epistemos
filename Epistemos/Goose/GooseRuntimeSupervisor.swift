import Foundation
import Observation
import Security

struct GooseRuntimeConnection: Equatable, Sendable {
    let baseURL: URL
    let secretKey: String

    var acpWebSocketURL: URL? {
        GooseRuntimeSupervisor.acpWebSocketURL(base: baseURL, secretKey: secretKey)
    }
}

@MainActor
@Observable
final class GooseRuntimeSupervisor {
    enum Status: Equatable, Sendable {
        case idle
        case unavailable(String)
        case starting
        case running(GooseRuntimeConnection)
        case failed(String)
        case stopped
    }

    nonisolated static let defaultHost = "127.0.0.1"
    nonisolated static let defaultPort = 3284
    nonisolated static let listenTimeout: Duration = .seconds(20)
    /// `goosed agent` boots the full AppState (REST + gateways) and is slower to answer than the
    /// lean `goose serve`; give it a larger readiness budget. (Step 2 / Option B.)
    nonisolated static let goosedListenTimeout: Duration = .seconds(45)

    /// Goose runtime backend. `.serve` = lean ACP-only `goose serve` (DEFAULT — preserves the
    /// working WebView/ACP path). `.goosed` = full `goosed agent` (REST + ACP, Option B), selected
    /// by `EPISTEMOS_GOOSE_BACKEND=goosed`. Single-point rollback = unset the flag.
    nonisolated enum Backend: String, Sendable {
        case serve
        case goosed
    }

    nonisolated static var configuredBackend: Backend {
        ProcessInfo.processInfo.environment["EPISTEMOS_GOOSE_BACKEND"]?.lowercased() == "goosed"
            ? .goosed : .serve
    }

    /// Initial goosed swap runs http on loopback (PROVEN working; simplest, no cert plumbing).
    /// TLS is opt-in via EPISTEMOS_GOOSE_GOOSED_TLS=true and additionally requires the WKWebView
    /// pinned didReceiveAuthenticationChallenge delegate (follow-up; needed for secure-context MCP
    /// guest SDKs). Loopback http is safe here (secret-key-auth'd + nav-gated + 127.0.0.1 only).
    nonisolated static var goosedTLSEnabled: Bool {
        ProcessInfo.processInfo.environment["EPISTEMOS_GOOSE_GOOSED_TLS"]?.lowercased() == "true"
    }
    // A normal stop()+start() restart can leave the just-killed `goose serve`
    // momentarily bound to the port; wait this long for it to release before
    // declaring the port occupied by a foreign service.
    nonisolated static let portReleaseGrace: Duration = .seconds(2)
    nonisolated private static let subprocessEnvironmentAllowlist: Set<String> = [
        "PATH", "HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE", "TERM", "TZ",
        // Non-secret detection/host config so goose serve can perform its OWN
        // provider/CLI/agent detection for env-configured returning users. These
        // are NOT provider secrets (API keys stay in Keychain, mirrored via
        // GooseProviderKeyBridge). NB: GOOSE_MODE is deliberately excluded — it is
        // only honored via the explicit gooseMode parameter, not inherited env.
        "GOOSE_PROVIDER", "GOOSE_MODEL", "GOOSE_DEFAULT_PROVIDER", "GOOSE_DEFAULT_MODEL",
        "OLLAMA_HOST",
    ]
    // Canonical macOS tool directories unioned into the child PATH so goose serve's
    // PATH-based CLI/agent detection (codex/claude/cursor/gemini/ollama) and stdio
    // MCP extensions resolve even when launched from Finder/launchd with a truncated
    // PATH. Detection still happens entirely inside Goose; we only widen the search
    // path. Non-existent dirs are harmless (ignored by PATH lookup).
    nonisolated private static let canonicalToolPathDirectories: [String] = [
        "/opt/homebrew/bin", "/opt/homebrew/sbin",
        "/usr/local/bin", "/usr/local/sbin",
        "/usr/bin", "/bin", "/usr/sbin", "/sbin",
    ]
    nonisolated private static let homeRelativeToolDirectories: [String] = [
        ".local/bin", ".cargo/bin", ".bun/bin", ".deno/bin", "go/bin", ".npm-global/bin",
    ]
    nonisolated private static let allowedGooseModes: Set<String> = [
        "auto", "approve", "smart_approve", "chat",
    ]
    nonisolated private static let subprocessEnvironmentDenylist: Set<String> = [
        "LD_PRELOAD",
        "LD_LIBRARY_PATH",
        "LD_AUDIT",
        "DYLD_INSERT_LIBRARIES",
        "DYLD_LIBRARY_PATH",
        "DYLD_FALLBACK_LIBRARY_PATH",
        "DYLD_FRAMEWORK_PATH",
        "DYLD_FALLBACK_FRAMEWORK_PATH",
        "DYLD_PRINT_LIBRARIES",
        "MallocStackLogging",
        "MallocStackLoggingNoCompact",
        "MallocScribble",
        "MallocGuardEdges",
        "DEBUG",
        "NODE_OPTIONS",
        "NODE_PATH",
        "NODE_DEBUG",
        "PYTHONPATH",
        "PYTHONHOME",
        "PYTHONSTARTUP",
        "RUBYOPT",
        "RUBYLIB",
        "PERL5OPT",
        "PERL5LIB",
        "PERL5DB",
        // Provider credentials deliberately do not ride the process environment.
        // `GooseProviderKeyBridge` reads Epistemos Keychain entries and saves them
        // through Goose's own provider-config ACP path after the runtime connects.
        "OPENAI_API_KEY",
        "OPENAI_ACCESS_TOKEN",
        "OPENAI_AUTH_MODE",
        "OPENAI_CLIENT_VERSION",
        "ANTHROPIC_API_KEY",
        "ANTHROPIC_ACCESS_TOKEN",
        "ANTHROPIC_AUTH_MODE",
        "GOOGLE_API_KEY",
        "GEMINI_API_KEY",
        "GOOGLE_ACCESS_TOKEN",
        "GOOGLE_AUTH_MODE",
        "GOOGLE_PROJECT_ID",
        "PERPLEXITY_API_KEY",
        "OPENROUTER_API_KEY",
        "GLM_API_KEY",
        "ZHIPU_API_KEY",
        "ZAI_API_KEY",
        "MOONSHOT_API_KEY",
        "KIMI_API_KEY",
        "DEEPSEEK_API_KEY",
        "MINIMAX_API_KEY",
        "XAI_API_KEY",
        "CODESTRAL_API_KEY",
        "MISTRAL_API_KEY",
        "TOGETHER_API_KEY",
        "GROQ_API_KEY",
        "HF_TOKEN",
        "HUGGINGFACE_API_KEY",
    ]

    private(set) var status: Status = .idle
    private(set) var lastDiagnostic: String?

    private var process: Process?
    private var lifecycleTask: Task<Void, Never>?
    private var outputTask: Task<Void, Never>?

    func start(
        bundle: Bundle = .main,
        binary: URL? = nil,
        secretKey: String? = nil,
        gooseMode: String? = nil,
        homeDirectory: URL? = nil,
        port: Int = defaultPort,
        disableKeyring: Bool = false,
        builtins: [String] = ["developer"],
        healthCheck: @escaping @Sendable (URL) async -> Bool = GooseRuntimeSupervisor.healthCheck(base:)
    ) {
        switch status {
        case .starting, .running:
            return
        default:
            break
        }

        #if EPISTEMOS_APP_STORE
        status = .unavailable("Goose is available in the Pro / Developer-ID build.")
        #else
        let binaryName = (Self.configuredBackend == .goosed) ? "goosed" : "goose"
        guard let binary = binary ?? Self.resolvedGooseBinary(bundle: bundle, binaryName: binaryName) else {
            status = .unavailable("\(binaryName == "goosed" ? "goosed" : "Goose") runtime is not bundled or staged for this build.")
            return
        }
        let resolvedSecretKey = secretKey ?? Self.randomSecretKey()
        status = .starting
        lifecycleTask = Task { [weak self] in
            await self?.run(
                binary: binary,
                secretKey: resolvedSecretKey,
                gooseMode: gooseMode,
                homeDirectory: homeDirectory,
                port: port,
                disableKeyring: disableKeyring,
                builtins: builtins,
                healthCheck: healthCheck
            )
        }
        #endif
    }

    func stop() {
        lifecycleTask?.cancel()
        lifecycleTask = nil
        outputTask?.cancel()
        outputTask = nil
        if let process {
            terminateTrackedProcess(process)
        }
        process = nil
        switch status {
        case .starting, .running:
            status = .stopped
        default:
            break
        }
    }

    func markRuntimeFailed(_ message: String) {
        if let process {
            terminateTrackedProcess(process)
            self.process = nil
        }
        switch status {
        case .starting, .running:
            status = .failed(message)
        default:
            break
        }
    }

    private func run(
        binary: URL,
        secretKey: String,
        gooseMode: String?,
        homeDirectory: URL?,
        port: Int,
        disableKeyring: Bool,
        builtins: [String],
        healthCheck: @escaping @Sendable (URL) async -> Bool
    ) async {
        // Step 2 / Option B: select backend (default .serve preserves the working path byte-for-byte).
        let backend = Self.configuredBackend
        let tls = (backend == .goosed) && Self.goosedTLSEnabled
        // Step-2 review FINDING 1: goosed-over-TLS needs BOTH a fingerprint-pinned readiness probe AND
        // the WKWebView cert-pin challenge handler (deferred follow-on). goosed with no cert paths
        // generates a self-signed cert, so an UNPINNED `URLSession.shared` probe fails the handshake
        // and the WebView would refuse to load https://goosed — a partial-TLS path is still broken.
        // Until the full pinning lands, honor the opt-in flag by FAILING FAST with an honest message
        // instead of launching into a 45s silent "not healthy" hang. http loopback (the default) is
        // the proven, secure-context path. This guard also closes FINDING 3's latent footgun: past
        // here `tls` is always false, so GOOSE_TLS is only ever written as false on the goosed path.
        if tls {
            status = .unavailable(
                "goosed TLS (EPISTEMOS_GOOSE_GOOSED_TLS=true) is not yet supported — it requires the "
                + "loopback cert-pinning delegate. Unset the flag to use the proven http loopback path."
            )
            return
        }
        let scheme = tls ? "https" : "http"
        let defaultBaseURL = Self.defaultBaseURL(port: port, scheme: scheme)
        let readinessTimeout = (backend == .goosed) ? Self.goosedListenTimeout : Self.listenTimeout
        // goosed has no /health (uses /status); lean serve uses the passed healthCheck (/health).
        let effectiveHealthCheck: @Sendable (URL) async -> Bool
        if backend == .goosed {
            effectiveHealthCheck = { await Self.goosedStatusCheck(base: $0) }
        } else {
            effectiveHealthCheck = healthCheck
        }
        if await effectiveHealthCheck(defaultBaseURL) {
            // The port is currently answering. On a user-initiated restart this is
            // usually our own just-terminated server still releasing the
            // socket, not a foreign occupant. Poll for it to go down within a
            // bounded grace window; only fail if it stays up the whole time (a real
            // foreign Goose-compatible service never releases here).
            let releaseDeadline = ContinuousClock.now.advanced(by: Self.portReleaseGrace)
            var released = false
            while ContinuousClock.now < releaseDeadline {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 100_000_000)
                if await effectiveHealthCheck(defaultBaseURL) == false {
                    released = true
                    break
                }
            }
            if !released {
                status = .failed(Self.occupiedPortMessage(base: defaultBaseURL))
                return
            }
        }

        let proc = Process()
        proc.executableURL = binary
        // goosed `agent` takes NO flags (configured via env, loads the developer builtin
        // automatically); lean `goose serve` takes --host/--port/--with-builtin.
        proc.arguments = (backend == .goosed)
            ? ["agent"]
            : Self.serveArguments(host: Self.defaultHost, port: port, builtins: builtins)
        var goosedConfig: (host: String, port: Int, tls: Bool)?
        if backend == .goosed {
            goosedConfig = (host: Self.defaultHost, port: port, tls: tls)
        } else {
            goosedConfig = nil
        }
        proc.environment = Self.processEnvironment(
            binary: binary,
            secretKey: secretKey,
            gooseMode: gooseMode,
            homeDirectory: homeDirectory,
            disableKeyring: disableKeyring,
            goosedConfig: goosedConfig
        )

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        process = proc
        proc.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.handleProcessExit(statusCode: process.terminationStatus)
            }
        }

        do {
            try proc.run()
            AppBootstrap.shared?.orphanCleanup.track(proc)
        } catch {
            let name = (backend == .goosed) ? "`goosed agent`" : "`goose serve`"
            status = .failed("Failed to launch \(name): \(error.localizedDescription)")
            return
        }

        let baseURL = await waitForReady(
            port: port,
            pipe: pipe,
            baseURL: defaultBaseURL,
            timeout: readinessTimeout,
            healthCheck: effectiveHealthCheck
        )
        if Task.isCancelled { return }
        guard let baseURL else {
            let name = (backend == .goosed) ? "`goosed agent`" : "`goose serve`"
            status = .failed("\(name) did not become healthy within \(readinessTimeout).")
            terminateTrackedProcess(proc)
            outputTask?.cancel()
            outputTask = nil
            return
        }
        status = .running(GooseRuntimeConnection(baseURL: baseURL, secretKey: secretKey))
    }

    private func waitForReady(
        port: Int,
        pipe: Pipe,
        baseURL: URL,
        timeout: Duration,
        healthCheck: @escaping @Sendable (URL) async -> Bool
    ) async -> URL? {
        return await withCheckedContinuation { continuation in
            let state = GooseRuntimeReadyState(continuation)
            outputTask = Task.detached { [weak self] in
                do {
                    for try await line in pipe.fileHandleForReading.bytes.lines {
                        let message = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !message.isEmpty {
                            await self?.recordDiagnostic(message)
                        }
                    }
                } catch {
                    // Teardown closes the pipe; process state drives lifecycle.
                }
                await state.resume(nil)
            }

            Task {
                let deadline = ContinuousClock.now.advanced(by: timeout)
                while ContinuousClock.now < deadline {
                    if await healthCheck(baseURL) {
                        await state.resume(baseURL)
                        return
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                await state.resume(nil)
            }
        }
    }

    private func recordDiagnostic(_ message: String) {
        lastDiagnostic = message
    }

    private func handleProcessExit(statusCode: Int32) {
        if let process {
            untrack(process)
        }
        switch status {
        case .starting:
            status = .failed("Goose exited before ACP became ready (exit \(statusCode)).")
        case .running:
            status = .failed("Goose exited unexpectedly (exit \(statusCode)).")
        default:
            break
        }
    }

    private func terminateTrackedProcess(_ process: Process) {
        let pid = pid_t(process.processIdentifier)
        if pid > 0 {
            AppBootstrap.shared?.orphanCleanup.cleanupProcessTree(rootPID: pid)
        }
        if process.isRunning {
            process.terminate()
        }
        untrack(process)
    }

    private func untrack(_ process: Process) {
        let pid = pid_t(process.processIdentifier)
        guard pid > 0 else { return }
        AppBootstrap.shared?.orphanCleanup.untrack(pid)
    }

    nonisolated static func serveArguments(
        host: String,
        port: Int,
        builtins: [String]
    ) -> [String] {
        var args = ["serve", "--host", host, "--port", String(port)]
        for builtin in builtins where !builtin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            args += ["--with-builtin", builtin]
        }
        return args
    }

    nonisolated static func processEnvironment(
        binary: URL,
        secretKey: String,
        gooseMode: String? = nil,
        homeDirectory: URL? = nil,
        disableKeyring: Bool = false,
        goosedConfig: (host: String, port: Int, tls: Bool)? = nil,
        base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var env = base.filter { key, _ in
            subprocessEnvironmentAllowlist.contains(key) &&
                !subprocessEnvironmentDenylist.contains(key)
        }
        env["GOOSE_SERVER__SECRET_KEY"] = secretKey
        // Step 2 / Option B: goosed `agent` reads host/port/tls from the env (figment GOOSE_ prefix),
        // unlike `goose serve`'s CLI flags.
        if let goosedConfig {
            env["GOOSE_HOST"] = goosedConfig.host
            env["GOOSE_PORT"] = String(goosedConfig.port)
            env["GOOSE_TLS"] = goosedConfig.tls ? "true" : "false"
        }
        if let mode = gooseMode?.trimmingCharacters(in: .whitespacesAndNewlines),
           allowedGooseModes.contains(mode) {
            env["GOOSE_MODE"] = mode
        }
        if let homeDirectory {
            env["HOME"] = homeDirectory.path
        }
        if disableKeyring {
            env["GOOSE_DISABLE_KEYRING"] = "true"
        }
        let binDir = binary.deletingLastPathComponent().path
        let home = env["HOME"] ?? base["HOME"] ?? NSHomeDirectory()
        let existingComponents = (env["PATH"] ?? "").split(separator: ":").map(String.init)
        let homeDirs = Self.homeRelativeToolDirectories.map { "\(home)/\($0)" }
        var orderedPath: [String] = []
        var seenPath: Set<String> = []
        for dir in [binDir] + existingComponents + Self.canonicalToolPathDirectories + homeDirs
        where !dir.isEmpty && seenPath.insert(dir).inserted {
            orderedPath.append(dir)
        }
        env["PATH"] = orderedPath.joined(separator: ":")
        return env
    }

    nonisolated static func parseListeningURL(from line: String, expectedPort: Int) -> URL? {
        let lower = line.lowercased()
        guard lower.contains("acp server"),
              lower.contains("starting") || lower.contains("listening") else {
            return nil
        }

        let patterns = [
            #"https?://[^\s]+"#,
            #"(?:127\.0\.0\.1|localhost):\d+"#,
        ]
        for pattern in patterns {
            guard let range = line.range(of: pattern, options: .regularExpression) else { continue }
            var raw = String(line[range]).trimmingCharacters(in: CharacterSet(charactersIn: "/.,;)\""))
            if !raw.hasPrefix("http://"), !raw.hasPrefix("https://") {
                raw = "http://\(raw)"
            }
            guard let components = URLComponents(string: raw),
                  components.scheme?.lowercased() == "http",
                  let host = components.host,
                  components.port == expectedPort,
                  components.path.isEmpty || components.path == "/" else { continue }
            guard host == "127.0.0.1" || host == "localhost" else { continue }
            return URL(string: "http://\(host):\(expectedPort)")
        }
        return nil
    }

    nonisolated static func defaultBaseURL(port: Int = defaultPort, scheme: String = "http") -> URL {
        URL(string: "\(scheme)://\(defaultHost):\(port)")!
    }

    /// goosed has no `/health` (404); its readiness/health endpoint is `/status` (200). (Step 2.)
    nonisolated static func goosedStatusCheck(base: URL) async -> Bool {
        var request = URLRequest(url: base.appendingPathComponent("status"))
        request.timeoutInterval = 2
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return false }
        // Step-2 review FINDING 2: require the literal "ok" body (goosed's /status returns exactly
        // that — routes/status.rs), matching the lean-serve /health check. A bare 200 would treat any
        // unrelated server answering /status as ours (over-conservative port refusal AND a narrow
        // window where a foreign 200 could be mistaken for "ready").
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "ok"
    }

    nonisolated static func occupiedPortMessage(base: URL) -> String {
        "Port \(base.port ?? defaultPort) already has a running Goose-compatible service. Stop it before opening Epistemos Goose."
    }

    nonisolated static func healthURL(base: URL) -> URL {
        base.appendingPathComponent("health")
    }

    nonisolated static func acpWebSocketURL(base: URL, secretKey: String) -> URL? {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        switch components.scheme?.lowercased() {
        case "http":
            components.scheme = "ws"
        case "https":
            components.scheme = "wss"
        default:
            return nil
        }
        components.path = components.path.replacingOccurrences(of: #"/+$"#, with: "", options: .regularExpression)
        components.path += "/acp"
        components.percentEncodedQuery = "token=\(percentEncodedACPToken(secretKey))"
        return components.url
    }

    nonisolated private static func percentEncodedACPToken(_ token: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return token.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    nonisolated static var hostCargoTargetTriple: String {
        #if arch(arm64)
        "aarch64-apple-darwin"
        #elseif arch(x86_64)
        "x86_64-apple-darwin"
        #else
        ""
        #endif
    }

    nonisolated static func resolvedGooseBinary(
        bundle: Bundle? = .main,
        appSupportDirectory: URL? = defaultAppSupportDirectory(),
        currentDirectory: String = FileManager.default.currentDirectoryPath,
        binaryName: String = "goose"
    ) -> URL? {
        let fileManager = FileManager.default
        for candidate in gooseBinaryCandidates(
            bundle: bundle,
            appSupportDirectory: appSupportDirectory,
            currentDirectory: currentDirectory,
            binaryName: binaryName
        ) {
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    nonisolated static func gooseBinaryCandidates(
        bundle: Bundle? = .main,
        appSupportDirectory: URL? = defaultAppSupportDirectory(),
        currentDirectory: String = FileManager.default.currentDirectoryPath,
        binaryName: String = "goose"
    ) -> [URL] {
        var candidates: [URL] = []
        if let appSupportDirectory {
            candidates.append(appSupportDirectory.appendingPathComponent("Epistemos/GooseRuntime/\(binaryName)"))
        }
        if let bundled = bundle?.url(forResource: binaryName, withExtension: nil) {
            candidates.append(bundled)
        }

        // Process-cwd-relative checkout binaries are a dev-only convenience and are
        // EXECUTED (proc.run) by resolvedGooseBinary. Since the process cwd is
        // influenceable in some launch contexts, never let a shipped build resolve a
        // goose binary from `<cwd>/.research-clones/...` — that would be
        // code-execution-from-cwd. Release builds resolve only the trusted
        // AppSupport/bundle candidates above (where the runtime is actually staged);
        // DEBUG keeps the checkout candidates for local dev + the live test suites.
        // (Thermonuclear finding: binary-resolution candidate safety.)
        #if DEBUG
        let checkoutTarget = URL(fileURLWithPath: currentDirectory)
            .appendingPathComponent(".research-clones/work/goose/target")
        if !hostCargoTargetTriple.isEmpty {
            candidates.append(checkoutTarget.appendingPathComponent("\(hostCargoTargetTriple)/release/\(binaryName)"))
            candidates.append(checkoutTarget.appendingPathComponent("\(hostCargoTargetTriple)/debug/\(binaryName)"))
        }
        candidates.append(checkoutTarget.appendingPathComponent("release/\(binaryName)"))
        candidates.append(checkoutTarget.appendingPathComponent("debug/\(binaryName)"))
        #endif
        return candidates
    }

    nonisolated private static func defaultAppSupportDirectory() -> URL? {
        try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
    }

    nonisolated static func randomSecretKey() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess {
            return Data(bytes).base64EncodedString()
        }
        return (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
    }

    nonisolated static func healthCheck(base: URL) async -> Bool {
        do {
            let (data, response) = try await URLSession.shared.data(from: healthURL(base: base))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "ok"
        } catch {
            return false
        }
    }
}

private actor GooseRuntimeReadyState {
    private var continuation: CheckedContinuation<URL?, Never>?

    init(_ continuation: CheckedContinuation<URL?, Never>) {
        self.continuation = continuation
    }

    func resume(_ url: URL?) {
        let continuation = self.continuation
        self.continuation = nil
        continuation?.resume(returning: url)
    }
}
