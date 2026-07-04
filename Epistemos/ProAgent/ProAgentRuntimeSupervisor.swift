#if !EPISTEMOS_APP_STORE
import Darwin
import Foundation
import Observation

/// Live connection facts for the Pro agent surface (Plan 1-PRO §1 topology).
/// The UI only ever talks to `uiBaseURL` (the OpenChamber web server); opencode
/// and (Phase 3) goosed sit behind the server's same-origin proxies.
struct ProAgentConnection: Equatable, Sendable {
    let uiBaseURL: URL
    let uiPort: Int
    let opencodePort: Int
    /// nil = the goose engine is not available this launch (binary missing or
    /// goosed failed readiness). Capability truth: the UI hides goose, never
    /// fakes it. The surface NEVER blocks on goose — opencode is the baseline.
    let goosePort: Int?
}

/// Transfers a just-created Process across the actor boundary so its blocking
/// `run()` (spawn) can execute OFF the main actor — proc.run() blocks on OS
/// code-signature validation of notarized binaries for hundreds of ms–seconds
/// and this class is @MainActor. Same proven shape as GooseSpawnBox
/// (hang-trace 2026-07-01: an inline @MainActor spawn froze the UI).
// SAFETY: immutable carrier used to hand a freshly-created Process across a
// concurrency boundary exactly once (spawn off-main); the Process is not
// mutated concurrently.
private struct ProAgentSpawnBox: @unchecked Sendable {
    let process: Process
}

/// Supervises the Pro agent surface's child processes (Plan 1-PRO §1/§12 R3-R4):
/// the OpenChamber web server (node) + the opencode engine, with a goosed slot
/// reserved for Phase 3. Modeled on `GooseRuntimeSupervisor`'s proven lifecycle
/// (status enum, off-main spawn, occupied-port honesty, termination identity
/// guards, orphan-cleanup tracking) — extended to a multi-child topology.
///
/// APP-SCOPED KEEP-ALIVE (Plan 1-PRO §13.5): unlike the old per-view goose
/// supervisor, this instance survives tab switches. Reloading the OpenChamber
/// SPA reboots it and kills the live session, so the children must keep running
/// while the app is open; `AppSupervisor`/orphan cleanup reaps them at quit.
@MainActor
@Observable
final class ProAgentRuntimeSupervisor {
    enum Status: Equatable, Sendable {
        case idle
        case unavailable(String)
        case starting
        case running(ProAgentConnection)
        case failed(String)
        case stopped
    }

    static let shared = ProAgentRuntimeSupervisor()

    nonisolated static let loopbackHost = "127.0.0.1"
    /// Ports are allocated from the ephemeral range ONLY. Two hard-won reasons:
    /// dynamic allocation avoids the occupied-port class entirely, and the range
    /// sits above the WHATWG fetch bad-port blocklist — the web server's own
    /// undici `fetch` REFUSES bad-listed ports (verified 2026-07-03: opencode on
    /// 4190/"sieve" made every SSE proxy hop die with `cause: bad port` while
    /// curl worked fine).
    nonisolated static let ephemeralPortRange: ClosedRange<Int> = 49_300...64_900
    nonisolated static let portAllocationAttempts = 48
    nonisolated static let readinessTimeout: Duration = .seconds(40)
    nonisolated static let healthProbeTimeout: TimeInterval = 5

    nonisolated private static let subprocessEnvironmentAllowlist: Set<String> = [
        "PATH", "HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE", "TERM", "TZ",
    ]
    /// Provider env keys bridged Keychain -> opencode child env at spawn
    /// (Plan 1-PRO §4.5 — keys live in Keychain, never in the binary or
    /// webview JS; the env crosses exactly one process boundary). Resolution
    /// rides the canonical AppBootstrap envVar->keychainKey mapping.
    nonisolated static let bridgedProviderEnvironmentKeys: [String] = [
        "ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GOOGLE_API_KEY", "PERPLEXITY_API_KEY",
        "OPENROUTER_API_KEY", "GROQ_API_KEY", "MISTRAL_API_KEY", "XAI_API_KEY",
        "DEEPSEEK_API_KEY", "HF_TOKEN",
    ]
    nonisolated private static let canonicalToolPathDirectories: [String] = [
        "/opt/homebrew/bin", "/opt/homebrew/sbin",
        "/usr/local/bin", "/usr/local/sbin",
        "/usr/bin", "/bin", "/usr/sbin", "/sbin",
    ]

    private(set) var status: Status = .idle
    private(set) var lastDiagnostic: String?

    private var webProcess: Process?
    private var opencodeProcess: Process?
    private var goosedProcess: Process?
    private var lifecycleTask: Task<Void, Never>?
    private var gooseReadinessTask: Task<Void, Never>?
    private var webOutputTask: Task<Void, Never>?
    private var opencodeOutputTask: Task<Void, Never>?
    private var goosedOutputTask: Task<Void, Never>?

    func start() {
        switch status {
        case .starting, .running:
            return
        default:
            break
        }

        guard let nodeBinary = Self.resolvedNodeBinary() else {
            status = .unavailable("Node runtime is not bundled or staged for this build.")
            return
        }
        guard let webRoot = Self.resolvedWebRoot() else {
            status = .unavailable("OpenChamber web bundle is not bundled or staged for this build.")
            return
        }
        guard let opencodeBinary = Self.resolvedOpencodeBinary() else {
            status = .unavailable("OpenCode runtime is not bundled or staged for this build.")
            return
        }
        guard let uiPort = Self.allocateLoopbackPort(),
              let opencodePort = Self.allocateLoopbackPort(excluding: [uiPort]) else {
            status = .failed("No free loopback port available for the agent surface.")
            return
        }

        // goose is the OPTIONAL second engine (Plan 1-PRO §0.3): resolve the
        // Work-lane-vendored goosed via the existing supervisor family; when
        // absent the surface runs opencode-only and the UI hides goose.
        var gooseChild: (binary: URL, port: Int, secret: String)?
        if let goosedBinary = GooseRuntimeSupervisor.resolvedGooseBinary(binaryName: "goosed"),
           let goosePort = Self.allocateLoopbackPort(excluding: [uiPort, opencodePort]) {
            gooseChild = (binary: goosedBinary, port: goosePort, secret: GooseRuntimeSupervisor.randomSecretKey())
        }

        status = .starting
        lifecycleTask = Task { [weak self, gooseChild] in
            await self?.run(
                nodeBinary: nodeBinary,
                webRoot: webRoot,
                opencodeBinary: opencodeBinary,
                uiPort: uiPort,
                opencodePort: opencodePort,
                gooseChild: gooseChild
            )
        }
    }

    func stop() {
        lifecycleTask?.cancel()
        lifecycleTask = nil
        gooseReadinessTask?.cancel()
        gooseReadinessTask = nil
        webOutputTask?.cancel()
        webOutputTask = nil
        opencodeOutputTask?.cancel()
        opencodeOutputTask = nil
        goosedOutputTask?.cancel()
        goosedOutputTask = nil
        if let webProcess {
            terminateTrackedProcess(webProcess)
        }
        webProcess = nil
        if let opencodeProcess {
            terminateTrackedProcess(opencodeProcess)
        }
        opencodeProcess = nil
        if let goosedProcess {
            terminateTrackedProcess(goosedProcess)
        }
        goosedProcess = nil
        switch status {
        case .starting, .running:
            status = .stopped
        default:
            break
        }
    }

    func markRuntimeFailed(_ message: String) {
        gooseReadinessTask?.cancel()
        gooseReadinessTask = nil
        if let webProcess {
            terminateTrackedProcess(webProcess)
            self.webProcess = nil
        }
        if let opencodeProcess {
            terminateTrackedProcess(opencodeProcess)
            self.opencodeProcess = nil
        }
        if let goosedProcess {
            terminateTrackedProcess(goosedProcess)
            self.goosedProcess = nil
        }
        switch status {
        case .starting, .running:
            status = .failed(GooseRuntimeSupervisor.boundedStatusMessage(message, fallback: "Agent runtime failed."))
        default:
            break
        }
    }

    // MARK: - Lifecycle

    private func run(
        nodeBinary: URL,
        webRoot: URL,
        opencodeBinary: URL,
        uiPort: Int,
        opencodePort: Int,
        gooseChild: (binary: URL, port: Int, secret: String)?
    ) async {
        // Child 1: opencode engine (attach mode — the web server never spawns it).
        let opencodeProc = Process()
        opencodeProc.executableURL = opencodeBinary
        opencodeProc.arguments = ["serve", "--hostname", Self.loopbackHost, "--port", String(opencodePort)]
        opencodeProc.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        var opencodeEnv = Self.childEnvironment(binaryDirectories: [
            opencodeBinary.deletingLastPathComponent(),
        ])
        for (envVar, value) in Self.bridgedProviderEnvironment() {
            opencodeEnv[envVar] = value
        }
        opencodeProc.environment = opencodeEnv

        // Child 2 (optional): goosed, env-configured per the R4 matrix — figment
        // GOOSE_* keys, TLS explicitly off (it DEFAULTS ON upstream), per-launch
        // secret held Swift-side + handed only to the proxy. Reuses the proven
        // GooseRuntimeSupervisor environment builder.
        var goosedProc: Process?
        if let gooseChild {
            let proc = Process()
            proc.executableURL = gooseChild.binary
            proc.arguments = ["agent"]
            proc.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
            proc.environment = GooseRuntimeSupervisor.processEnvironment(
                binary: gooseChild.binary,
                secretKey: gooseChild.secret,
                goosedConfig: (host: Self.loopbackHost, port: gooseChild.port, tls: false)
            )
            goosedProc = proc
        }

        // Child 3: OpenChamber web server (serves the vendored SPA + runtime routes,
        // proxies /api/* to opencode and /goose/* to goosed). EPISTEMOS_EMBED=1
        // activates the fork's patch-ledger runtime stubs.
        let webProc = Process()
        webProc.executableURL = nodeBinary
        webProc.arguments = [
            webRoot.appendingPathComponent("server/index.js").path,
            "--port", String(uiPort),
            "--host", Self.loopbackHost,
        ]
        webProc.currentDirectoryURL = webRoot
        var webEnv = Self.childEnvironment(binaryDirectories: [
            nodeBinary.deletingLastPathComponent(),
            opencodeBinary.deletingLastPathComponent(),
        ])
        webEnv["OPENCODE_PORT"] = String(opencodePort)
        webEnv["OPENCODE_SKIP_START"] = "true"
        webEnv["EPISTEMOS_EMBED"] = "1"
        if let gooseChild {
            // The secret crosses exactly one boundary: supervisor -> web server
            // process env, where the /goose/* proxy attaches it upstream. It
            // never reaches the webview.
            webEnv["EPISTEMOS_GOOSE_PORT"] = String(gooseChild.port)
            webEnv["EPISTEMOS_GOOSE_SECRET"] = gooseChild.secret
        }
        webProc.environment = webEnv

        let opencodePipe = Pipe()
        opencodeProc.standardOutput = opencodePipe
        opencodeProc.standardError = opencodePipe
        let webPipe = Pipe()
        webProc.standardOutput = webPipe
        webProc.standardError = webPipe
        let goosedPipe = Pipe()
        if let goosedProc {
            goosedProc.standardOutput = goosedPipe
            goosedProc.standardError = goosedPipe
        }

        opencodeProcess = opencodeProc
        webProcess = webProc
        goosedProcess = goosedProc
        installTerminationHandler(on: opencodeProc, childName: "opencode")
        installTerminationHandler(on: webProc, childName: "OpenChamber web server")
        if let goosedProc {
            installTerminationHandler(on: goosedProc, childName: "goosed")
        }

        do {
            // Spawn OFF the main actor — see ProAgentSpawnBox. Children spawn
            // sequentially in one detached hop (spawn cost is signature validation,
            // not ordering-sensitive; the web server retries opencode readiness itself).
            let boxes = (
                ProAgentSpawnBox(process: opencodeProc),
                ProAgentSpawnBox(process: webProc),
                goosedProc.map(ProAgentSpawnBox.init(process:))
            )
            try await Task.detached(priority: .userInitiated) {
                try boxes.0.process.run()
                try boxes.2?.process.run()
                try boxes.1.process.run()
            }.value
            #if !MAS_SANDBOX
            AppBootstrap.shared?.orphanCleanup.track(opencodeProc)
            AppBootstrap.shared?.orphanCleanup.track(webProc)
            if let goosedProc {
                AppBootstrap.shared?.orphanCleanup.track(goosedProc)
            }
            #endif
        } catch {
            status = .failed(GooseRuntimeSupervisor.boundedStatusMessage(
                "Failed to launch the agent runtime: \(error.localizedDescription)"
            ))
            if opencodeProc.isRunning { terminateTrackedProcess(opencodeProc) }
            if webProc.isRunning { terminateTrackedProcess(webProc) }
            if let goosedProc, goosedProc.isRunning { terminateTrackedProcess(goosedProc) }
            opencodeProcess = nil
            webProcess = nil
            goosedProcess = nil
            return
        }

        beginDiagnosticsCapture(opencodePipe: opencodePipe, webPipe: webPipe, goosedPipe: goosedProc != nil ? goosedPipe : nil)

        guard let uiBaseURL = Self.baseURL(port: uiPort) else {
            status = .failed("Could not form the agent surface URL.")
            return
        }

        // Single readiness probe covers the BASELINE children: the web server's
        // /health reports its own status AND isOpenCodeReady. goose is optional
        // and must never delay the surface — it joins via a late re-emit below.
        let deadline = ContinuousClock.now.advanced(by: Self.readinessTimeout)
        while ContinuousClock.now < deadline {
            if Task.isCancelled { return }
            if await Self.healthCheck(uiBaseURL: uiBaseURL) {
                status = .running(ProAgentConnection(
                    uiBaseURL: uiBaseURL,
                    uiPort: uiPort,
                    opencodePort: opencodePort,
                    goosePort: nil
                ))
                if let gooseChild {
                    beginGooseReadinessWatch(uiPort: uiPort, opencodePort: opencodePort, uiBaseURL: uiBaseURL, goosePort: gooseChild.port)
                }
                return
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        status = .failed("Agent runtime did not become healthy within \(Self.readinessTimeout).")
        stopChildrenAfterFailedStart()
    }

    /// goosed boots the full AppState and can take tens of seconds; watch its
    /// /status off the critical path and re-emit `.running` with the goose port
    /// once it answers (capability truth: advertise goose only when it is real).
    private func beginGooseReadinessWatch(uiPort: Int, opencodePort: Int, uiBaseURL: URL, goosePort: Int) {
        gooseReadinessTask?.cancel()
        gooseReadinessTask = Task { [weak self] in
            let gooseBase = GooseRuntimeSupervisor.defaultBaseURL(port: goosePort)
            let deadline = ContinuousClock.now.advanced(by: GooseRuntimeSupervisor.goosedListenTimeout)
            while ContinuousClock.now < deadline {
                if Task.isCancelled { return }
                if await GooseRuntimeSupervisor.goosedStatusCheck(base: gooseBase) {
                    guard let self else { return }
                    if case .running = self.status, self.goosedProcess != nil {
                        self.status = .running(ProAgentConnection(
                            uiBaseURL: uiBaseURL,
                            uiPort: uiPort,
                            opencodePort: opencodePort,
                            goosePort: goosePort
                        ))
                    }
                    return
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            guard let self else { return }
            self.recordDiagnostic("[goosed] did not become healthy within \(GooseRuntimeSupervisor.goosedListenTimeout) — goose engine disabled this launch.")
            if let goosedProcess = self.goosedProcess {
                self.terminateTrackedProcess(goosedProcess)
                self.goosedProcess = nil
            }
        }
    }

    private func stopChildrenAfterFailedStart() {
        gooseReadinessTask?.cancel()
        gooseReadinessTask = nil
        if let webProcess {
            terminateTrackedProcess(webProcess)
            self.webProcess = nil
        }
        if let opencodeProcess {
            terminateTrackedProcess(opencodeProcess)
            self.opencodeProcess = nil
        }
        if let goosedProcess {
            terminateTrackedProcess(goosedProcess)
            self.goosedProcess = nil
        }
        webOutputTask?.cancel()
        webOutputTask = nil
        opencodeOutputTask?.cancel()
        opencodeOutputTask = nil
        goosedOutputTask?.cancel()
        goosedOutputTask = nil
    }

    private func installTerminationHandler(on process: Process, childName: String) {
        process.terminationHandler = { [weak self] exited in
            Task { @MainActor in
                self?.handleChildExit(exited, childName: childName, statusCode: exited.terminationStatus)
            }
        }
    }

    private func handleChildExit(_ exited: Process, childName: String, statusCode: Int32) {
        // Identity guard (GooseRuntimeSupervisor review C-M1): a PREVIOUS child's
        // termination handler can fire after a restart already brought up a new
        // child. React only to processes we currently own.
        let ownsExited = (exited === webProcess) || (exited === opencodeProcess) || (exited === goosedProcess)
        guard ownsExited else {
            untrack(exited)
            return
        }

        // goose is the optional engine: its death DEGRADES the surface (goose
        // hidden, opencode untouched) instead of failing it.
        if exited === goosedProcess {
            goosedProcess = nil
            untrack(exited)
            gooseReadinessTask?.cancel()
            gooseReadinessTask = nil
            recordDiagnostic("[goosed] exited (exit \(statusCode)) — goose engine disabled until the next surface start.")
            if case .running(let connection) = status, connection.goosePort != nil {
                status = .running(ProAgentConnection(
                    uiBaseURL: connection.uiBaseURL,
                    uiPort: connection.uiPort,
                    opencodePort: connection.opencodePort,
                    goosePort: nil
                ))
            }
            return
        }

        if exited === webProcess { webProcess = nil }
        if exited === opencodeProcess { opencodeProcess = nil }
        untrack(exited)
        switch status {
        case .starting:
            status = .failed("\(childName) exited before the agent surface became ready (exit \(statusCode)).")
        case .running:
            status = .failed("\(childName) exited unexpectedly (exit \(statusCode)).")
        default:
            break
        }
    }

    private func terminateTrackedProcess(_ process: Process) {
        process.terminationHandler = nil
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

    private func beginDiagnosticsCapture(opencodePipe: Pipe, webPipe: Pipe, goosedPipe: Pipe?) {
        opencodeOutputTask = Task.detached { [weak self] in
            guard let recorder = self else { return }
            await GooseProcessDiagnostics.consume(from: opencodePipe.fileHandleForReading) { message in
                await recorder.recordDiagnostic("[opencode] \(message)")
            }
        }
        webOutputTask = Task.detached { [weak self] in
            guard let recorder = self else { return }
            await GooseProcessDiagnostics.consume(from: webPipe.fileHandleForReading) { message in
                await recorder.recordDiagnostic("[web] \(message)")
            }
        }
        if let goosedPipe {
            goosedOutputTask = Task.detached { [weak self] in
                guard let recorder = self else { return }
                await GooseProcessDiagnostics.consume(from: goosedPipe.fileHandleForReading) { message in
                    await recorder.recordDiagnostic("[goosed] \(message)")
                }
            }
        }
    }

    private func recordDiagnostic(_ message: String) {
        lastDiagnostic = message
    }

    // MARK: - Readiness / health

    /// The OpenChamber /health endpoint returns a rich JSON document. Ready means
    /// the server itself answers `"status":"ok"` AND it can reach opencode
    /// (`"isOpenCodeReady":true`) — one probe, both children verified.
    nonisolated static func healthCheck(uiBaseURL: URL) async -> Bool {
        var request = URLRequest(url: uiBaseURL.appendingPathComponent("health"))
        request.timeoutInterval = healthProbeTimeout
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        let statusOK = (payload["status"] as? String) == "ok"
        let openCodeReady = (payload["isOpenCodeReady"] as? Bool) == true
        return statusOK && openCodeReady
    }

    /// Web-server-only liveness (ignores opencode) for the surface's ongoing
    /// health monitor: the SPA + fs/git/terminal routes live on the web server,
    /// so a live server with a briefly-restarting opencode should degrade, not
    /// tear the whole surface down.
    nonisolated static func webServerAlive(uiBaseURL: URL) async -> Bool {
        var request = URLRequest(url: uiBaseURL.appendingPathComponent("health"))
        request.timeoutInterval = healthProbeTimeout
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return (payload["status"] as? String) == "ok"
    }

    nonisolated static func baseURL(port: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = loopbackHost
        components.port = port
        return components.url
    }

    // MARK: - Port allocation

    nonisolated static func allocateLoopbackPort(excluding: Set<Int> = []) -> Int? {
        for _ in 0..<portAllocationAttempts {
            let candidate = Int.random(in: ephemeralPortRange)
            guard !excluding.contains(candidate) else { continue }
            if GooseRuntimeSupervisor.isLoopbackTCPPortAvailable(candidate) {
                return candidate
            }
        }
        return nil
    }

    // MARK: - Binary / bundle resolution

    /// Sanitized child environment: allowlisted inherited vars only (never
    /// provider secrets — those stay in Keychain), with PATH rebuilt from the
    /// child's own binary directories + canonical tool dirs. Mirrors the
    /// GooseRuntimeSupervisor / agent_core subprocess-hardening posture.
    nonisolated static func childEnvironment(
        binaryDirectories: [URL],
        base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var env: [String: String] = [:]
        for (key, value) in base where subprocessEnvironmentAllowlist.contains(key) {
            env[key] = value
        }
        var pathEntries: [String] = binaryDirectories.map(\.path)
        if let inherited = base["PATH"] {
            pathEntries += inherited.split(separator: ":", omittingEmptySubsequences: true).map(String.init)
        }
        pathEntries += canonicalToolPathDirectories
        var seen: Set<String> = []
        env["PATH"] = pathEntries.filter { seen.insert($0).inserted }.joined(separator: ":")
        return env
    }

    /// Node runtime resolution. Release builds resolve ONLY trusted bundled
    /// locations; DEBUG adds developer-machine fallbacks (same candidate-safety
    /// posture as GooseRuntimeSupervisor.gooseBinaryCandidates — never resolve
    /// an executable from cwd-influenced paths in a shipped build).
    nonisolated static func resolvedNodeBinary(bundle: Bundle = .main) -> URL? {
        var candidates: [URL] = []
        if let resources = bundle.resourceURL {
            candidates.append(resources.appendingPathComponent("openchamber-runtime/bin/node"))
            candidates.append(resources.appendingPathComponent("node"))
        }
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["EPISTEMOS_NODE_BINARY"], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override))
        }
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/node"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/node"))
        #endif
        return firstExecutable(in: candidates)
    }

    /// The vendored OpenChamber web package root (contains server/, dist/,
    /// node_modules/, package.json). Release: bundled resources only. DEBUG:
    /// env override, then the developer fork checkout.
    nonisolated static func resolvedWebRoot(bundle: Bundle = .main) -> URL? {
        let fileManager = FileManager.default
        var candidates: [URL] = []
        if let resources = bundle.resourceURL {
            candidates.append(resources.appendingPathComponent("openchamber-web", isDirectory: true))
        }
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["EPISTEMOS_OPENCHAMBER_WEB_ROOT"], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override, isDirectory: true))
        }
        candidates.append(
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("dev/openchamber-epistemos/packages/web", isDirectory: true)
        )
        #endif
        for candidate in candidates {
            let serverEntry = candidate.appendingPathComponent("server/index.js")
            let dist = candidate.appendingPathComponent("dist/index.html")
            if fileManager.fileExists(atPath: serverEntry.path), fileManager.fileExists(atPath: dist.path) {
                return candidate
            }
        }
        return nil
    }

    /// opencode engine binary. First choice is the Work lane's vendored runtime
    /// (already bundled by build-opencode-runtime.sh — reuse, don't re-vendor);
    /// DEBUG adds the developer install.
    nonisolated static func resolvedOpencodeBinary(bundle: Bundle = .main) -> URL? {
        if let bundled = WorkOpenCodeRuntime.bundledRuntimeURL(bundle: bundle) {
            return bundled
        }
        #if DEBUG
        let home = FileManager.default.homeDirectoryForCurrentUser
        return firstExecutable(in: [
            home.appendingPathComponent(".opencode/bin/opencode"),
            URL(fileURLWithPath: "/opt/homebrew/bin/opencode"),
            URL(fileURLWithPath: "/usr/local/bin/opencode"),
        ])
        #else
        return nil
        #endif
    }

    nonisolated private static func firstExecutable(in candidates: [URL]) -> URL? {
        let fileManager = FileManager.default
        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate.path) {
            return candidate
        }
        return nil
    }

    /// Keychain -> env bridge for the opencode child (goosed keeps its own
    /// config/keyring path — never fed keys through env, matching the goose
    /// supervisor's denylist doctrine).
    nonisolated static func bridgedProviderEnvironment(
        keychainLoad: (String) -> String? = { Keychain.load(for: $0) }
    ) -> [String: String] {
        var env: [String: String] = [:]
        for envVar in bridgedProviderEnvironmentKeys {
            guard let keychainKey = AppBootstrap.agentCoreKeychainKey(forEnvironmentKey: envVar),
                  let raw = keychainLoad(keychainKey) else { continue }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value.utf8.count <= 4_096, !value.utf8.contains(0) else { continue }
            env[envVar] = value
        }
        return env
    }
}
#endif
