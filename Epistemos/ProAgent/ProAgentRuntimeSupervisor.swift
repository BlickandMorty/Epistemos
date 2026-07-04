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
        guard Self.resolvedWebRoot() != nil || Self.bundledWebTarball() != nil else {
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

        // Per-launch Basic-auth password for opencode (Plan 1-PRO §1 / R4). Set
        // in BOTH the opencode child (which enforces it) and the web server
        // (whose /api proxy sends it via auth-state-runtime). A local process
        // that finds the ephemeral opencodePort can no longer drive opencode's
        // shell/code-exec tools without this secret — the random port was
        // obscurity, this is authentication.
        let opencodePassword = GooseRuntimeSupervisor.randomSecretKey()

        status = .starting
        lifecycleTask = Task { [weak self, gooseChild, opencodePassword] in
            await self?.run(
                nodeBinary: nodeBinary,
                opencodeBinary: opencodeBinary,
                uiPort: uiPort,
                opencodePort: opencodePort,
                opencodePassword: opencodePassword,
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
        opencodeBinary: URL,
        uiPort: Int,
        opencodePort: Int,
        opencodePassword: String,
        gooseChild: (binary: URL, port: Int, secret: String)?
    ) async {
        // Resolve the web root: the bundled tarball (unpacked to AppSupport,
        // version-stamped — a structured tree can't ride the synchronized
        // resource copy, iter31 flattening lesson) wins over dev fallbacks.
        guard let webRoot = await Self.resolveWebRootUnpackingIfNeeded(diagnostics: { [weak self] message in
            Task { @MainActor in self?.recordDiagnostic(message) }
        }) else {
            status = .unavailable("OpenChamber web bundle could not be staged (tarball unpack failed and no dev checkout present).")
            return
        }
        // Perf doctrine §4: cold_open interval = start() -> .running.
        let coldOpenClockStart = ContinuousClock.now
        let coldOpenSignpostID = Sig.agentSurface.makeSignpostID()
        let coldOpenSignpostState = Sig.agentSurface.beginInterval("cold_open", id: coldOpenSignpostID)
        var coldOpenRecorded = false
        defer {
            if !coldOpenRecorded {
                Sig.agentSurface.endInterval("cold_open", coldOpenSignpostState)
            }
        }

        // Phase-5: reap children a CRASHED previous instance left behind
        // (identity-checked by pid + kernel start time; TERM then KILL).
        await ProAgentChildLedger.sweepStaleChildren { [weak self] message in
            Task { @MainActor in self?.recordDiagnostic(message) }
        }
        if Task.isCancelled { return }

        // Child 1: opencode engine (attach mode — the web server never spawns it).
        let opencodeProc = Process()
        opencodeProc.executableURL = opencodeBinary
        opencodeProc.arguments = ["serve", "--hostname", Self.loopbackHost, "--port", String(opencodePort)]
        opencodeProc.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        var opencodeEnv = Self.childEnvironment(binaryDirectories: [
            opencodeBinary.deletingLastPathComponent(),
        ])
        // MED-10: read provider keys OFF the main actor. A locked/contended
        // Keychain makes these ~10 synchronous loads stall the main thread on
        // the cold-open path the off-main spawn exists to protect.
        let providerEnv = await Task.detached(priority: .userInitiated) {
            Self.bridgedProviderEnvironment()
        }.value
        if Task.isCancelled { return }
        for (envVar, value) in providerEnv {
            opencodeEnv[envVar] = value
        }
        // Enforce Basic auth on the opencode server (Plan §1 / R4).
        opencodeEnv["OPENCODE_SERVER_PASSWORD"] = opencodePassword
        opencodeProc.environment = opencodeEnv

        // Child 2 (optional): goosed, env-configured per the R4 matrix — figment
        // GOOSE_* keys, TLS explicitly off (it DEFAULTS ON upstream), per-launch
        // secret held Swift-side + handed only to the proxy. Reuses the proven
        // GooseRuntimeSupervisor environment builder.
        // OPT-IN keyring bypass (default OFF): with the keyring on (matching the
        // proven GooseRuntimeSupervisor default), goosed prompts for the macOS
        // 'goose' keychain ACL on each launch of an unsigned/re-signed build,
        // which blocks a provider (e.g. cursor-agent, which has its own CLI
        // auth and needs no keychain secret). The owner may opt into reading
        // goose's own secret store from config instead —
        // EPISTEMOS_PRO_GOOSE_DISABLE_KEYRING=1 — to run/verify a goose turn
        // without the prompt. Production posture is UNCHANGED (flag absent →
        // keyring on); this does not touch Epistemos's Keychain-held keys.
        let proGooseDisableKeyring =
            ProcessInfo.processInfo.environment["EPISTEMOS_PRO_GOOSE_DISABLE_KEYRING"] == "1"
        var goosedProc: Process?
        if let gooseChild {
            let proc = Process()
            proc.executableURL = gooseChild.binary
            proc.arguments = ["agent"]
            proc.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
            // withUserToolPath: goosed spawns goose's configured CLI providers
            // (e.g. cursor-agent in ~/.local/bin) by bare name — add the user tool
            // dirs the launchd GUI PATH omits so those providers resolve. (goosed's
            // env is built by the shared GooseRuntimeSupervisor; augment its result
            // here rather than touch that MAS-shared file.)
            proc.environment = Self.withUserToolPath(GooseRuntimeSupervisor.processEnvironment(
                binary: gooseChild.binary,
                secretKey: gooseChild.secret,
                disableKeyring: proGooseDisableKeyring,
                goosedConfig: (host: Self.loopbackHost, port: gooseChild.port, tls: false)
            ))
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
        // The /api proxy authenticates to opencode with this (auth-state-runtime
        // reads OPENCODE_SERVER_PASSWORD and sends Basic auth). Same value as
        // the opencode child; the webview never sees it (server-side only).
        webEnv["OPENCODE_SERVER_PASSWORD"] = opencodePassword
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
            // Crash-durable child ledger (Phase 5): survives THIS process
            // dying so the next start can sweep.
            ProAgentChildLedger.record(pid: pid_t(opencodeProc.processIdentifier), name: "opencode")
            ProAgentChildLedger.record(pid: pid_t(webProc.processIdentifier), name: "openchamber-web")
            if let goosedProc {
                ProAgentChildLedger.record(pid: pid_t(goosedProc.processIdentifier), name: "goosed")
            }
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
                let coldOpenElapsed = ContinuousClock.now - coldOpenClockStart
                Sig.agentSurface.endInterval("cold_open", coldOpenSignpostState)
                coldOpenRecorded = true
                ProAgentPerfMetrics.shared.recordColdOpen(
                    milliseconds: Double(coldOpenElapsed.components.seconds) * 1_000
                        + Double(coldOpenElapsed.components.attoseconds) / 1e15
                )
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
            stopSurvivingChildrenAfterRequiredExit()
        case .running:
            status = .failed("\(childName) exited unexpectedly (exit \(statusCode)).")
            // MED-4: a required child (web/opencode) died — tear down the
            // SURVIVING siblings now. Otherwise a later start() overwrites their
            // still-live references in run() and orphans them (two web servers /
            // an unkillable node bound to its port).
            stopSurvivingChildrenAfterRequiredExit()
        default:
            break
        }
    }

    /// Terminate any still-live children after a required child exited, so the
    /// next start() spawns a clean set instead of leaking the survivors.
    private func stopSurvivingChildrenAfterRequiredExit() {
        goosedOutputTask?.cancel(); goosedOutputTask = nil
        webOutputTask?.cancel(); webOutputTask = nil
        opencodeOutputTask?.cancel(); opencodeOutputTask = nil
        gooseReadinessTask?.cancel(); gooseReadinessTask = nil
        if let goosedProcess { terminateTrackedProcess(goosedProcess) }
        goosedProcess = nil
        if let webProcess { terminateTrackedProcess(webProcess) }
        webProcess = nil
        if let opencodeProcess { terminateTrackedProcess(opencodeProcess) }
        opencodeProcess = nil
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
        ProAgentChildLedger.forget(pid: pid)
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
        pathEntries += userToolPathDirectories(home: base["HOME"])
        var seen: Set<String> = []
        env["PATH"] = pathEntries.filter { seen.insert($0).inserted }.joined(separator: ":")
        return env
    }

    /// User-installed CLI tool directories. goose's configured CLI-passthrough
    /// providers (e.g. cursor-agent, which lives in ~/.local/bin and authenticates
    /// via its OWN ~/.cursor state, NOT goose's keyring) are invoked by bare name,
    /// but a GUI-launched app inherits only the launchd PATH — which omits
    /// ~/.local/bin and ~/bin — so the spawn fails "command not found" and the
    /// provider silently produces no text. These are the user's own directories;
    /// adding them lets configured providers resolve without touching the
    /// library-injection denylist (DYLD_*/LD_PRELOAD stay stripped) or bridging
    /// any secret.
    nonisolated static func userToolPathDirectories(home: String?) -> [String] {
        guard let home, !home.isEmpty else { return [] }
        return ["\(home)/.local/bin", "\(home)/bin"]
    }

    /// Prepend the user tool dirs to an already-built PATH (for children whose env
    /// is built elsewhere, e.g. goosed via GooseRuntimeSupervisor.processEnvironment).
    nonisolated static func withUserToolPath(_ env: [String: String]) -> [String: String] {
        var out = env
        let home = env["HOME"] ?? ProcessInfo.processInfo.environment["HOME"]
        let userDirs = userToolPathDirectories(home: home)
        guard !userDirs.isEmpty else { return out }
        var entries = userDirs
        if let existing = out["PATH"] {
            entries += existing.split(separator: ":", omittingEmptySubsequences: true).map(String.init)
        }
        var seen: Set<String> = []
        out["PATH"] = entries.filter { seen.insert($0).inserted }.joined(separator: ":")
        return out
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

    /// opencode engine binary. Matched-triple pin FIRST (openchamber-runtime,
    /// staged by build-openchamber-web.sh at the SDK-matched version), then
    /// the Work lane's vendored runtime, then DEBUG developer installs.
    nonisolated static func resolvedOpencodeBinary(bundle: Bundle = .main) -> URL? {
        if let resources = bundle.resourceURL {
            // Named opencode-triple (not opencode): both lanes' bin/ trees
            // flatten to the Resources ROOT in the built app, and two files
            // named `opencode` are a "Multiple commands produce" build error
            // (hit live during packaging).
            let triplePinned = [
                resources.appendingPathComponent("openchamber-runtime/bin/opencode-triple"),
                resources.appendingPathComponent("opencode-triple"),
            ]
            if let pinned = firstExecutable(in: triplePinned) {
                return pinned
            }
        }
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

    // MARK: - Bundled web tarball unpack (packaging)

    nonisolated static func bundledWebTarball(bundle: Bundle = .main) -> URL? {
        guard let resources = bundle.resourceURL else { return nil }
        let candidates = [
            resources.appendingPathComponent("openchamber-runtime/openchamber-web.tar.gz"),
            // iter31: the synchronized resource copy can flatten subfolders.
            resources.appendingPathComponent("openchamber-web.tar.gz"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Unpacks the bundled web tarball to Application Support (stamped by the
    /// tarball's size+mtime so each staged version unpacks exactly once) and
    /// returns the served root. Falls back to the dev-checkout resolution when
    /// no tarball is bundled. Runs off the main actor (tar spawn + IO).
    nonisolated static func resolveWebRootUnpackingIfNeeded(
        bundle: Bundle = .main,
        diagnostics: @escaping @Sendable (String) -> Void = { _ in }
    ) async -> URL? {
        guard let tarball = bundledWebTarball(bundle: bundle) else {
            return resolvedWebRoot(bundle: bundle)
        }
        let fileManager = FileManager.default
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return resolvedWebRoot(bundle: bundle) }

        let destRoot = appSupport
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("OpenChamberWeb", isDirectory: true)
        let unpackedRoot = destRoot.appendingPathComponent("openchamber-web", isDirectory: true)
        let stampFile = destRoot.appendingPathComponent(".unpack-stamp")

        let attrs = try? fileManager.attributesOfItem(atPath: tarball.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let expectedStamp = "\(size)-\(Int(mtime))"

        if let existing = try? String(contentsOf: stampFile, encoding: .utf8),
           existing == expectedStamp,
           fileManager.fileExists(atPath: unpackedRoot.appendingPathComponent("server/index.js").path) {
            return unpackedRoot
        }

        diagnostics("[packaging] unpacking bundled web tarball (\(size / 1_048_576) MB) to Application Support…")
        let success = await Task.detached(priority: .userInitiated) { () -> Bool in
            let fm = FileManager.default
            try? fm.removeItem(at: unpackedRoot)
            try? fm.createDirectory(at: destRoot, withIntermediateDirectories: true)
            let tar = Process()
            tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            tar.arguments = ["-xzf", tarball.path, "-C", destRoot.path]
            do {
                try tar.run()
                tar.waitUntilExit()
                return tar.terminationStatus == 0
            } catch {
                return false
            }
        }.value

        guard success,
              fileManager.fileExists(atPath: unpackedRoot.appendingPathComponent("server/index.js").path) else {
            diagnostics("[packaging] tarball unpack FAILED — falling back to dev checkout resolution.")
            return resolvedWebRoot(bundle: bundle)
        }
        try? expectedStamp.write(to: stampFile, atomically: true, encoding: .utf8)
        diagnostics("[packaging] web bundle unpacked and stamped (\(expectedStamp)).")
        return unpackedRoot
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
