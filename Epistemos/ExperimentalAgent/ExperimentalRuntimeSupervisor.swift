#if EPISTEMOS_EXPERIMENTAL && EPISTEMOS_APP_STORE
#error("EPISTEMOS_EXPERIMENTAL is a Developer-ID lane and must never coexist with EPISTEMOS_APP_STORE")
#endif

#if EPISTEMOS_EXPERIMENTAL
import Darwin
import Foundation
import Observation

/// Live connection facts for the Experimental agent surface (1Code embed).
/// The WKWebView only ever talks to `uiBaseURL` — the headless backend serves
/// the SPA, tRPC (HTTP batch + ws subscriptions), /push, /host and /healthz on
/// this one same-origin port.
struct ExperimentalConnection: Equatable, Sendable {
    let uiBaseURL: URL
    let uiPort: Int
}

/// The staged web root, normalized across the two layouts we can boot from:
/// the packaged tarball (server/ + dist/ + node_modules/) and the DEBUG fork
/// checkout (headless/dist/* + out/renderer + node_modules).
struct ExperimentalWebRoot: Equatable, Sendable {
    let serverEntry: URL   // headless index.cjs
    let distDirectory: URL // built renderer SPA
    let workingDirectory: URL // node cwd; node_modules resolution walks up from serverEntry
    let shimScript: URL    // onecode-shim.js (injected as a WKUserScript)
}

// SAFETY: immutable carrier used to hand a freshly-created Process across a
// concurrency boundary exactly once (spawn off-main); the Process is not
// mutated concurrently. proc.run() blocks on OS code-signature validation of
// notarized binaries for hundreds of ms–seconds — never spawn on @MainActor
// (ProAgent hang-trace 2026-07-01).
private struct ExperimentalSpawnBox: @unchecked Sendable {
    let process: Process
}

/// Supervises the Experimental surface's headless 1Code backend (one Node
/// child; node-pty/git/engine CLIs are ITS children). Modeled on
/// `ProAgentRuntimeSupervisor` and reusing its proven statics directly:
/// port allocation (49300–64900, above the WHATWG fetch bad-port blocklist),
/// env allowlist, the time-bounded Keychain→env bridge, and the shared pinned
/// Node resolution (`openchamber-runtime/bin/node` — one binary, two surfaces).
///
/// APP-SCOPED KEEP-ALIVE: survives tab switches — reloading the SPA kills the
/// live agent session (§0 rule), so the backend keeps running while the app is
/// open; the child ledger + termination handlers reap it at quit/crash.
@MainActor
@Observable
final class ExperimentalRuntimeSupervisor {
    enum Status: Equatable, Sendable {
        case idle
        case unavailable(String)
        case starting
        case running(ExperimentalConnection)
        case failed(String)
        case stopped
    }

    static let shared = ExperimentalRuntimeSupervisor()

    nonisolated static let readinessTimeout: Duration = .seconds(40)
    nonisolated static let healthProbeTimeout: TimeInterval = 5
    /// §16: upstream launches with --max-old-space-size=8192 — oversized beside
    /// Epistemos + engine children on 16 GB. Start mid-band; tune under soak.
    nonisolated static let backendHeapMB = 3_072

    private(set) var status: Status = .idle
    private(set) var lastDiagnostic: String?
    /// The resolved onecode-shim.js path for the running backend — the surface
    /// view reads it to inject the WKUserScript @documentStart.
    private(set) var currentShimScript: URL?

    private var backendProcess: Process?
    private var lifecycleTask: Task<Void, Never>?
    private var outputTask: Task<Void, Never>?
    /// The /host ws bridge servicing native dialogs for the backend (rows 7-8
    /// of the fork's PATCH_LEDGER — the folder pickers' native path).
    private var hostBridge: ExperimentalHostBridge?

    func start() {
        switch status {
        case .starting, .running:
            return
        default:
            break
        }
        guard let nodeBinary = ProAgentRuntimeSupervisor.resolvedNodeBinary() else {
            status = .unavailable("Shared Node runtime is not bundled or staged for this build.")
            return
        }
        guard let uiPort = ProAgentRuntimeSupervisor.allocateLoopbackPort() else {
            status = .failed("No free loopback port available for the Experimental surface.")
            return
        }
        status = .starting
        lastDiagnostic = nil
        lifecycleTask?.cancel()
        lifecycleTask = Task { [weak self] in
            await self?.run(nodeBinary: nodeBinary, uiPort: uiPort)
        }
    }

    func stop() {
        lifecycleTask?.cancel()
        lifecycleTask = nil
        outputTask?.cancel()
        outputTask = nil
        hostBridge?.disconnect()
        hostBridge = nil
        if let process = backendProcess, process.isRunning {
            process.terminationHandler = nil
            process.terminate()
            ProAgentChildLedger.forget(pid: process.processIdentifier)
        }
        backendProcess = nil
        status = .stopped
    }

    private func run(nodeBinary: URL, uiPort: Int) async {
        await ProAgentChildLedger.sweepStaleChildren { [weak self] line in
            Task { @MainActor in self?.recordDiagnostic(line) }
        }

        guard let webRoot = await Self.resolveWebRootUnpackingIfNeeded(diagnostics: { [weak self] line in
            Task { @MainActor in self?.recordDiagnostic(line) }
        }) else {
            status = .unavailable("Experimental web bundle is not bundled or staged for this build.")
            return
        }
        currentShimScript = webRoot.shimScript

        var environment = ProAgentRuntimeSupervisor.childEnvironment(
            binaryDirectories: [nodeBinary.deletingLastPathComponent()]
        )
        // Keychain reads can hang forever on a first-launch ACL prompt — race
        // them (4s) and spawn without keys on timeout (ProAgent doctrine).
        let bridged = await ProAgentRuntimeSupervisor.bridgedProviderEnvironment(
            timeout: .seconds(4)
        ) { [weak self] in
            Task { @MainActor in
                self?.recordDiagnostic("[keychain] provider-env bridge timed out — starting without bridged keys")
            }
        }
        environment.merge(bridged) { _, new in new }
        // P1 (§8): prefer the user's own `claude` CLI (with their OAuth) — probe absolute
        // locations (GUI apps get only the launchd PATH). The backend resolver honors this
        // and falls back to the bundled binary when unset.
        if let claudeBinary = Self.resolveSystemClaudeBinary() {
            environment["EPISTEMOS_CLAUDE_BINARY"] = claudeBinary
            recordDiagnostic("[cli] using system claude: \(claudeBinary)")
        }
        environment["EPISTEMOS_ONECODE_PORT"] = String(uiPort)
        environment["EPISTEMOS_ONECODE_PACKAGED"] = "1"
        environment["EPISTEMOS_ONECODE_USER_DATA"] = Self.userDataDirectory().path
        environment["EPISTEMOS_ONECODE_RENDERER"] = webRoot.distDirectory.path
        environment["EPISTEMOS_ONECODE_VERSION"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

        let process = Process()
        process.executableURL = nodeBinary
        process.arguments = ["--max-old-space-size=\(Self.backendHeapMB)", webRoot.serverEntry.path]
        process.currentDirectoryURL = webRoot.workingDirectory
        process.environment = environment
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        let spawnBox = ExperimentalSpawnBox(process: process)
        let spawnError: String? = await Task.detached(priority: .userInitiated) {
            do {
                try spawnBox.process.run()
                return nil
            } catch {
                return String(describing: error)
            }
        }.value
        if let spawnError {
            status = .failed("Backend spawn failed: \(spawnError)")
            return
        }

        backendProcess = process
        ProAgentChildLedger.record(pid: process.processIdentifier, name: "experimental-backend")
        installTerminationHandler(on: process)
        beginOutputCapture(outputPipe)

        guard let uiBaseURL = ProAgentRuntimeSupervisor.baseURL(port: uiPort) else {
            status = .failed("Could not form the surface base URL.")
            stop()
            return
        }

        let deadline = ContinuousClock.now + Self.readinessTimeout
        var ready = false
        while ContinuousClock.now < deadline, !Task.isCancelled {
            if await Self.healthCheck(uiBaseURL: uiBaseURL) {
                ready = true
                break
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        guard ready else {
            status = .failed("Backend did not become healthy within \(Self.readinessTimeout).")
            stop()
            return
        }

        let bridge = ExperimentalHostBridge(uiPort: uiPort)
        bridge.connect()
        hostBridge = bridge
        status = .running(ExperimentalConnection(uiBaseURL: uiBaseURL, uiPort: uiPort))
    }

    private func installTerminationHandler(on process: Process) {
        process.terminationHandler = { [weak self] exited in
            let code = exited.terminationStatus
            let pid = exited.processIdentifier
            Task { @MainActor in
                guard let self, self.backendProcess === exited else { return }
                ProAgentChildLedger.forget(pid: pid)
                self.backendProcess = nil
                self.hostBridge?.disconnect()
                self.hostBridge = nil
                if case .stopped = self.status { return }
                self.status = .failed("Backend exited unexpectedly (code \(code)).")
            }
        }
    }

    private func beginOutputCapture(_ pipe: Pipe) {
        outputTask?.cancel()
        outputTask = Task.detached(priority: .utility) { [weak self] in
            let handle = pipe.fileHandleForReading
            while !Task.isCancelled {
                let data = handle.availableData
                if data.isEmpty { break }
                if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                    let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !line.isEmpty {
                        Task { @MainActor in self?.recordDiagnostic(String(line.suffix(500))) }
                    }
                }
            }
        }
    }

    private func recordDiagnostic(_ message: String) {
        lastDiagnostic = message
    }

    // MARK: - Health

    nonisolated static func healthCheck(uiBaseURL: URL) async -> Bool {
        var request = URLRequest(url: uiBaseURL.appendingPathComponent("healthz"))
        request.timeoutInterval = healthProbeTimeout
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
        return String(data: data, encoding: .utf8)?.contains("\"ok\":true") == true
    }

    // MARK: - Web root resolution

    /// §8 CLI detect: first existing+executable `claude` in the canonical install
    /// locations (a GUI app inherits only the launchd PATH, so probe absolute paths).
    /// Returns nil when none is installed → the backend uses its bundled binary.
    nonisolated static func resolveSystemClaudeBinary() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.bun/bin/claude",
        ]
        let fm = FileManager.default
        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }

    nonisolated static func userDataDirectory() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        let dir = base
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("ExperimentalAgent", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated static func bundledWebTarball(bundle: Bundle = .main) -> URL? {
        guard let resources = bundle.resourceURL else { return nil }
        let candidates = [
            resources.appendingPathComponent("experimental-runtime/experimental-web.tar.gz"),
            // The synchronized resource copy can flatten subfolders (iter31 lesson).
            resources.appendingPathComponent("experimental-web.tar.gz"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Unpacks the bundled tarball to Application Support (size+mtime stamped —
    /// each staged version unpacks exactly once), or falls back to the DEBUG
    /// fork checkout for instant dev boots. Mirrors the ProAgent unpack recipe.
    nonisolated static func resolveWebRootUnpackingIfNeeded(
        bundle: Bundle = .main,
        diagnostics: @escaping @Sendable (String) -> Void = { _ in }
    ) async -> ExperimentalWebRoot? {
        let fileManager = FileManager.default

        if let tarball = bundledWebTarball(bundle: bundle),
           let appSupport = try? fileManager.url(
               for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
           ) {
            let destRoot = appSupport
                .appendingPathComponent("Epistemos", isDirectory: true)
                .appendingPathComponent("ExperimentalWeb", isDirectory: true)
            let unpackedRoot = destRoot.appendingPathComponent("experimental-web", isDirectory: true)
            let stampFile = destRoot.appendingPathComponent(".unpack-stamp")
            let serverEntry = unpackedRoot.appendingPathComponent("server/index.cjs")

            let attrs = try? fileManager.attributesOfItem(atPath: tarball.path)
            let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
            let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let expectedStamp = "\(size)-\(Int(mtime))"

            let alreadyUnpacked = (try? String(contentsOf: stampFile, encoding: .utf8)) == expectedStamp
                && fileManager.fileExists(atPath: serverEntry.path)
            if !alreadyUnpacked {
                diagnostics("[packaging] unpacking experimental web tarball (\(size / 1_048_576) MB)…")
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
                guard success, fileManager.fileExists(atPath: serverEntry.path) else {
                    diagnostics("[packaging] tarball unpack FAILED — trying dev fallback.")
                    return devForkWebRoot()
                }
                try? expectedStamp.write(to: stampFile, atomically: true, encoding: .utf8)
                diagnostics("[packaging] experimental web bundle unpacked (\(expectedStamp)).")
            }
            return ExperimentalWebRoot(
                serverEntry: serverEntry,
                distDirectory: unpackedRoot.appendingPathComponent("dist", isDirectory: true),
                workingDirectory: unpackedRoot,
                shimScript: unpackedRoot.appendingPathComponent("server/onecode-shim.js")
            )
        }
        return devForkWebRoot()
    }

    /// DEBUG-only: boot straight from the fork checkout (no tarball round trip).
    nonisolated static func devForkWebRoot() -> ExperimentalWebRoot? {
        #if DEBUG
        var candidates: [URL] = []
        if let override = ProcessInfo.processInfo.environment["EPISTEMOS_EXPERIMENTAL_FORK_ROOT"], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override, isDirectory: true))
        }
        candidates.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Downloads/Epistemos/.research-clones/1code", isDirectory: true)
        )
        let fileManager = FileManager.default
        for fork in candidates {
            let serverEntry = fork.appendingPathComponent("headless/dist/index.cjs")
            let dist = fork.appendingPathComponent("out/renderer", isDirectory: true)
            if fileManager.fileExists(atPath: serverEntry.path),
               fileManager.fileExists(atPath: dist.appendingPathComponent("index.html").path) {
                return ExperimentalWebRoot(
                    serverEntry: serverEntry,
                    distDirectory: dist,
                    workingDirectory: fork,
                    shimScript: fork.appendingPathComponent("headless/dist/onecode-shim.js")
                )
            }
        }
        return nil
        #else
        return nil
        #endif
    }
}
#endif
