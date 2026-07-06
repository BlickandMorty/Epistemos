#if !EPISTEMOS_APP_STORE
import Darwin
import Foundation
import Observation
import Security

/// Live connection facts for the Pro agent surface (Plan 1-PRO §1 topology).
/// The UI only ever talks to `uiBaseURL` (the OpenChamber web server); opencode
/// sits behind the server's same-origin proxy.
struct ProAgentConnection: Equatable, Sendable {
    let uiBaseURL: URL
    let uiPort: Int
    let opencodePort: Int
}

/// Transfers a just-created Process across the actor boundary so its blocking
/// `run()` (spawn) can execute OFF the main actor — proc.run() blocks on OS
/// code-signature validation of notarized binaries for hundreds of ms–seconds
/// and this class is @MainActor.
// SAFETY: immutable carrier used to hand a freshly-created Process across a
// concurrency boundary exactly once (spawn off-main); the Process is not
// mutated concurrently.
private struct ProAgentSpawnBox: @unchecked Sendable {
    let process: Process
}

private enum ProAgentProcessDiagnostics {
    nonisolated static let maxBufferedLineBytes = 16 * 1024
    nonisolated static let maxStoredDiagnosticCharacters = 4_096
    private nonisolated static let truncationSuffix = " ... [truncated]"

    nonisolated static func consume(
        from handle: FileHandle,
        record: @escaping @Sendable (String) async -> Void
    ) async {
        var buffer: [UInt8] = []
        buffer.reserveCapacity(maxBufferedLineBytes)
        var truncated = false

        do {
            for try await byte in handle.bytes {
                if byte == 10 || byte == 13 {
                    await emit(buffer: buffer, truncated: truncated, record: record)
                    buffer.removeAll(keepingCapacity: true)
                    truncated = false
                } else if buffer.count < maxBufferedLineBytes {
                    buffer.append(byte)
                } else {
                    truncated = true
                }
            }
        } catch {
            await emit(buffer: buffer, truncated: truncated, record: record)
            await emit(buffer: Array(error.localizedDescription.utf8), truncated: false, record: record)
            return
        }

        await emit(buffer: buffer, truncated: truncated, record: record)
    }

    private nonisolated static func boundedLine(buffer: [UInt8], truncated: Bool) -> String? {
        var text = String(decoding: buffer, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || truncated else { return nil }
        if truncated || text.count > maxStoredDiagnosticCharacters {
            let budget = max(0, maxStoredDiagnosticCharacters - truncationSuffix.count)
            text = String(text.prefix(budget)) + truncationSuffix
        } else {
            text = String(text.prefix(maxStoredDiagnosticCharacters))
        }
        return text.isEmpty ? nil : text
    }

    private nonisolated static func emit(
        buffer: [UInt8],
        truncated: Bool,
        record: @escaping @Sendable (String) async -> Void
    ) async {
        guard let line = boundedLine(buffer: buffer, truncated: truncated) else { return }
        await record(line)
    }
}

/// Supervises the Pro agent surface's child processes (Plan 1-PRO §1/§12 R3-R4):
/// the OpenChamber web server (node) + the opencode engine. Uses status enum,
/// off-main spawn, occupied-port honesty, termination identity guards, and
/// orphan-cleanup tracking for the two-child OpenCode topology.
///
/// APP-SCOPED KEEP-ALIVE (Plan 1-PRO §13.5): this instance survives tab
/// switches. Reloading the OpenChamber SPA reboots it and kills the live
/// session, so the children must keep running while the app is open;
/// `AppSupervisor`/orphan cleanup reaps them at quit.
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

    nonisolated static let loopbackHost = AgentSurfaceRuntimeSupport.loopbackHost
    /// Ports are allocated from the ephemeral range ONLY. Two hard-won reasons:
    /// dynamic allocation avoids the occupied-port class entirely, and the range
    /// sits above the WHATWG fetch bad-port blocklist — the web server's own
    /// undici `fetch` REFUSES bad-listed ports (verified 2026-07-03: opencode on
    /// 4190/"sieve" made every SSE proxy hop die with `cause: bad port` while
    /// curl worked fine).
    nonisolated static let ephemeralPortRange = AgentSurfaceRuntimeSupport.ephemeralPortRange
    nonisolated static let portAllocationAttempts = AgentSurfaceRuntimeSupport.portAllocationAttempts
    nonisolated static let readinessTimeout: Duration = .seconds(40)
    nonisolated static let healthProbeTimeout: TimeInterval = 5
    nonisolated static let maxStatusMessageCharacters = 512
    nonisolated static let maxSubprocessEnvironmentValueCharacters =
        ProAgentSubprocessEnvironment.maxSubprocessEnvironmentValueCharacters
    nonisolated static let maxSubprocessPathCharacters =
        ProAgentSubprocessEnvironment.maxSubprocessPathCharacters
    nonisolated static let maxSubprocessPathEntryCharacters =
        ProAgentSubprocessEnvironment.maxSubprocessPathEntryCharacters
    nonisolated static let maxSubprocessPathEntries =
        ProAgentSubprocessEnvironment.maxSubprocessPathEntries
    /// Provider env keys bridged Keychain -> opencode child env at spawn
    /// (Plan 1-PRO §4.5 — keys live in Keychain, never in the binary or
    /// webview JS; the env crosses exactly one process boundary). Resolution
    /// rides the canonical AppBootstrap envVar->keychainKey mapping.
    nonisolated static let bridgedProviderEnvironmentKeys =
        AgentSurfaceRuntimeSupport.bridgedProviderEnvironmentKeys
    private(set) var status: Status = .idle
    private(set) var lastDiagnostic: String?

    private var webProcess: Process?
    private var opencodeProcess: Process?
    private var lifecycleTask: Task<Void, Never>?
    private var webOutputTask: Task<Void, Never>?
    private var opencodeOutputTask: Task<Void, Never>?

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

        // Per-launch Basic-auth password for opencode (Plan 1-PRO §1 / R4). Set
        // in BOTH the opencode child (which enforces it) and the web server
        // (whose /api proxy sends it via auth-state-runtime). A local process
        // that finds the ephemeral opencodePort can no longer drive opencode's
        // shell/code-exec tools without this secret — the random port was
        // obscurity, this is authentication.
        let opencodePassword = Self.randomSecretKey()

        status = .starting
        lifecycleTask = Task { [weak self, opencodePassword] in
            await self?.run(
                nodeBinary: nodeBinary,
                opencodeBinary: opencodeBinary,
                uiPort: uiPort,
                opencodePort: opencodePort,
                opencodePassword: opencodePassword
            )
        }
    }

    func stop() {
        lifecycleTask?.cancel()
        lifecycleTask = nil
        webOutputTask?.cancel()
        webOutputTask = nil
        opencodeOutputTask?.cancel()
        opencodeOutputTask = nil
        if let webProcess {
            terminateTrackedProcess(webProcess)
        }
        webProcess = nil
        if let opencodeProcess {
            terminateTrackedProcess(opencodeProcess)
        }
        opencodeProcess = nil
        switch status {
        case .starting, .running:
            status = .stopped
        default:
            break
        }
    }

    func markRuntimeFailed(_ message: String) {
        if let webProcess {
            terminateTrackedProcess(webProcess)
            self.webProcess = nil
        }
        if let opencodeProcess {
            terminateTrackedProcess(opencodeProcess)
            self.opencodeProcess = nil
        }
        switch status {
        case .starting, .running:
            status = .failed(Self.boundedStatusMessage(message, fallback: "Agent runtime failed."))
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
        opencodePassword: String
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
        // MED-10 + cold-start hang fix: read provider keys OFF the main actor
        // AND time-bounded. A locked/contended Keychain — or a first-launch ACL
        // authorization prompt on a freshly-built binary — makes these
        // synchronous loads block forever; awaiting them unbounded wedges the
        // ENTIRE child-spawn sequence (spindump-confirmed). Bound the wait so a
        // stuck Keychain degrades to "spawn without bridged keys" instead of a
        // dead agent surface.
        let providerEnv = await Self.bridgedProviderEnvironment(
            timeout: .seconds(4),
            onTimeout: { [weak self] in
                Task { @MainActor in
                    self?.recordDiagnostic(
                        "[provider-env] Keychain bridge timed out (>4s) — spawning opencode WITHOUT bridged provider keys. "
                        + "The Keychain is likely awaiting ACL authorization; grant it once so provider keys reach opencode.")
                }
            }
        )
        if Task.isCancelled { return }
        for (envVar, value) in providerEnv {
            opencodeEnv[envVar] = value
        }
        // Enforce Basic auth on the opencode server (Plan §1 / R4).
        opencodeEnv["OPENCODE_SERVER_PASSWORD"] = opencodePassword
        // EPISTEMOS MCP vault fusion (owner-approved 2026-07-04): register the
        // active app vault as a stdio MCP so the Pro agent can search + cite the
        // user's notes/skills. Vault content reaches the agent's cloud providers
        // (owner-consented). Reuses the proven Work-lane merge-preserving writer
        // (preserves user-installed opencode MCPs across relaunch). Best-effort:
        // no active vault OR missing bundled server -> no OPENCODE_CONFIG (the
        // honest no-vault state; never roots at an empty default).
        var fusionConfigPath: String?
        var fusionVaultRoot: String?
        if let vaultURL = AppBootstrap.shared?.vaultSync.vaultURL,
           let serverURL = WorkOpenCodeRuntime.bundledMcpServerURL(),
           let configPath = WorkOpenCodeRuntime.writeMergedFusionConfig(
               stdioServerPath: serverURL.path, vaultRoot: vaultURL.path, nativeMCP: nil) {
            fusionConfigPath = configPath
            fusionVaultRoot = vaultURL.path
            opencodeEnv["OPENCODE_CONFIG"] = configPath
            opencodeEnv["EPISTEMOS_VAULT_ROOT"] = vaultURL.path
        }
        opencodeProc.environment = opencodeEnv

        // Child 2: OpenChamber web server (serves the vendored SPA + runtime
        // routes, proxies /api/* to opencode). EPISTEMOS_EMBED=1 activates the
        // fork's patch-ledger runtime stubs.
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
        // OpenChamber's MCP/config/status routes read process.env.OPENCODE_CONFIG.
        // Keep them pointed at the same merge-preserving fusion config as the
        // opencode child, otherwise the UI can report/configure a different MCP
        // store than the engine is actually using.
        if let fusionConfigPath {
            webEnv["OPENCODE_CONFIG"] = fusionConfigPath
        }
        if let fusionVaultRoot {
            webEnv["EPISTEMOS_VAULT_ROOT"] = fusionVaultRoot
        }
        webEnv["EPISTEMOS_EMBED"] = "1"
        webProc.environment = webEnv

        let opencodePipe = Pipe()
        opencodeProc.standardOutput = opencodePipe
        opencodeProc.standardError = opencodePipe
        let webPipe = Pipe()
        webProc.standardOutput = webPipe
        webProc.standardError = webPipe

        opencodeProcess = opencodeProc
        webProcess = webProc
        installTerminationHandler(on: opencodeProc, childName: "opencode")
        installTerminationHandler(on: webProc, childName: "OpenChamber web server")

        do {
            // Spawn OFF the main actor — see ProAgentSpawnBox. Children spawn
            // sequentially in one detached hop (spawn cost is signature validation,
            // not ordering-sensitive; the web server retries opencode readiness itself).
            let boxes = (
                ProAgentSpawnBox(process: opencodeProc),
                ProAgentSpawnBox(process: webProc)
            )
            try await Task.detached(priority: .userInitiated) {
                try boxes.0.process.run()
                try boxes.1.process.run()
            }.value
            #if !MAS_SANDBOX
            AppBootstrap.shared?.orphanCleanup.track(opencodeProc)
            AppBootstrap.shared?.orphanCleanup.track(webProc)
            #endif
            // Crash-durable child ledger (Phase 5): survives THIS process
            // dying so the next start can sweep.
            ProAgentChildLedger.record(pid: pid_t(opencodeProc.processIdentifier), name: "opencode")
            ProAgentChildLedger.record(pid: pid_t(webProc.processIdentifier), name: "openchamber-web")
        } catch {
            status = .failed(Self.boundedStatusMessage(
                "Failed to launch the agent runtime: \(error.localizedDescription)"
            ))
            if opencodeProc.isRunning { terminateTrackedProcess(opencodeProc) }
            if webProc.isRunning { terminateTrackedProcess(webProc) }
            opencodeProcess = nil
            webProcess = nil
            return
        }

        beginDiagnosticsCapture(opencodePipe: opencodePipe, webPipe: webPipe)

        guard let uiBaseURL = Self.baseURL(port: uiPort) else {
            status = .failed("Could not form the agent surface URL.")
            return
        }

        // Single readiness probe covers both children: the web server's /health
        // reports its own status AND isOpenCodeReady.
        let deadline = ContinuousClock.now.advanced(by: Self.readinessTimeout)
        while ContinuousClock.now < deadline {
            if Task.isCancelled { return }
            if await Self.healthCheck(uiBaseURL: uiBaseURL) {
                status = .running(ProAgentConnection(
                    uiBaseURL: uiBaseURL,
                    uiPort: uiPort,
                    opencodePort: opencodePort
                ))
                let coldOpenElapsed = ContinuousClock.now - coldOpenClockStart
                Sig.agentSurface.endInterval("cold_open", coldOpenSignpostState)
                coldOpenRecorded = true
                ProAgentPerfMetrics.shared.recordColdOpen(
                    milliseconds: Double(coldOpenElapsed.components.seconds) * 1_000
                        + Double(coldOpenElapsed.components.attoseconds) / 1e15
                )
                return
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        status = .failed("Agent runtime did not become healthy within \(Self.readinessTimeout).")
        stopChildrenAfterFailedStart()
    }

    private func stopChildrenAfterFailedStart() {
        if let webProcess {
            terminateTrackedProcess(webProcess)
            self.webProcess = nil
        }
        if let opencodeProcess {
            terminateTrackedProcess(opencodeProcess)
            self.opencodeProcess = nil
        }
        webOutputTask?.cancel()
        webOutputTask = nil
        opencodeOutputTask?.cancel()
        opencodeOutputTask = nil
    }

    private func installTerminationHandler(on process: Process, childName: String) {
        process.terminationHandler = { [weak self] exited in
            Task { @MainActor in
                self?.handleChildExit(exited, childName: childName, statusCode: exited.terminationStatus)
            }
        }
    }

    private func handleChildExit(_ exited: Process, childName: String, statusCode: Int32) {
        // Identity guard: a previous child's termination handler can fire after
        // a restart already brought up a new child. React only to processes we
        // currently own.
        let ownsExited = (exited === webProcess) || (exited === opencodeProcess)
        guard ownsExited else {
            untrack(exited)
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
        webOutputTask?.cancel(); webOutputTask = nil
        opencodeOutputTask?.cancel(); opencodeOutputTask = nil
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

    private func beginDiagnosticsCapture(opencodePipe: Pipe, webPipe: Pipe) {
        opencodeOutputTask = Task.detached { [weak self] in
            guard let recorder = self else { return }
            await ProAgentProcessDiagnostics.consume(from: opencodePipe.fileHandleForReading) { message in
                await recorder.recordDiagnostic("[opencode] \(message)")
            }
        }
        webOutputTask = Task.detached { [weak self] in
            guard let recorder = self else { return }
            await ProAgentProcessDiagnostics.consume(from: webPipe.fileHandleForReading) { message in
                await recorder.recordDiagnostic("[web] \(message)")
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
        AgentSurfaceRuntimeSupport.baseURL(port: port)
    }

    // MARK: - Port allocation

    nonisolated static func allocateLoopbackPort(excluding: Set<Int> = []) -> Int? {
        AgentSurfaceRuntimeSupport.allocateLoopbackPort(excluding: excluding)
    }

    // MARK: - Binary / bundle resolution

    /// Sanitized child environment: allowlisted inherited vars only (never
    /// provider secrets — those stay in Keychain), with PATH rebuilt from the
    /// child's own binary directories + canonical tool dirs.
    nonisolated static func childEnvironment(
        binaryDirectories: [URL],
        base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        AgentSurfaceRuntimeSupport.childEnvironment(binaryDirectories: binaryDirectories, base: base)
    }

    /// Node runtime resolution. Release builds resolve ONLY trusted bundled
    /// locations; DEBUG adds developer-machine fallbacks. Never resolve an
    /// executable from cwd-influenced paths in a shipped build.
    nonisolated static func resolvedNodeBinary(bundle: Bundle = .main) -> URL? {
        AgentSurfaceRuntimeSupport.resolvedNodeBinary(bundle: bundle)
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
        AgentSurfaceRuntimeSupport.firstExecutable(in: candidates)
    }

    nonisolated static func boundedStatusMessage(
        _ message: String,
        fallback: String = "Agent runtime failed."
    ) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? fallback : trimmed
        guard value.count > maxStatusMessageCharacters else { return value }
        return String(value.prefix(maxStatusMessageCharacters))
    }

    nonisolated static func randomSecretKey() -> String {
        AgentSurfaceRuntimeSupport.randomSecretKey()
    }

    nonisolated static func isLoopbackTCPPortAvailable(_ port: Int) -> Bool {
        AgentSurfaceRuntimeSupport.isLoopbackTCPPortAvailable(port)
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

    /// Keychain -> env bridge for the opencode child.
    nonisolated static func bridgedProviderEnvironment(
        keychainLoad: (String) -> String? = { Keychain.load(for: $0) }
    ) -> [String: String] {
        AgentSurfaceRuntimeSupport.bridgedProviderEnvironment(keychainLoad: keychainLoad)
    }

    /// Time-bounded provider-env bridge. `bridgedProviderEnvironment` performs a
    /// handful of SYNCHRONOUS Keychain reads (`SecItemCopyMatching`), and on a
    /// freshly-built / re-signed binary the first read can trigger an ACL
    /// authorization prompt that blocks INDEFINITELY (measured: a cold-launch
    /// spindump showed the entire child-spawn thread parked in `Keychain.load`,
    /// so opencode + node never started and the surface hung on
    /// "Agent starting"). Off-main (MED-10) alone doesn't help: `run()` awaits
    /// this before spawning, so an unbounded read wedges the whole runtime.
    ///
    /// Race the (uncancellable) reads against a deadline via detached, UNawaited
    /// tasks + a checked continuation resumed exactly once by a latch — a
    /// structured task group can't be used because it would suspend at scope
    /// exit waiting for the still-blocked read. On timeout we spawn WITHOUT the
    /// bridged keys; opencode can authenticate interactively. The blocked read
    /// is harmless — it no-ops when it returns.
    nonisolated static func bridgedProviderEnvironment(
        timeout: Duration,
        onTimeout: @escaping @Sendable () -> Void
    ) async -> [String: String] {
        await AgentSurfaceRuntimeSupport.bridgedProviderEnvironment(timeout: timeout, onTimeout: onTimeout)
    }
}
#endif
