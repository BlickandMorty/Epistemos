import Foundation
import Observation
import Security

// Step 5 (2026-06-24): supervises the local OpenWork WORKER — the `openwork-server` Bun binary (apps/server) that
// manages OpenCode + serves the OpenWork API on loopback. Launches it rooted at the app vault with a per-launch
// bearer token + permissive loopback CORS for the WebView, and exposes the base URL + token so `WorkSPAServer`
// seeds the SPA's localStorage → AUTO-CONNECT (no manual "Connect custom remote").
//
// HONEST: if the worker binary isn't staged/bundled, reports `.unavailable` and launches NOTHING (no fake server).
// Direct-distribution Pro sidecar (NOT MAS — the sandbox + hardened runtime block subprocess spawning). Mirrors the
// proven `WorkRuntimeSupervisor` Process+pipe+await-listening-line pattern, tailored to the OpenWork worker CLI.
@MainActor
@Observable
final class WorkOpenWorkSupervisor {
    enum Status: Equatable, Sendable {
        case idle
        case unavailable(String)
        case starting
        /// Live; the loopback base URL + the per-launch bearer token the SPA must use.
        case running(baseURL: URL, token: String)
        case failed(String)
        case stopped
    }

    private(set) var status: Status = .idle

    /// OpenWork's default worker port (`openwork-server --port`, default 8787) — matches the SPA's baked
    /// `VITE_OPENWORK_URL=http://localhost:8787`.
    nonisolated static let port = 8787
    static let listenTimeout: Duration = .seconds(20)

    private var process: Process?
    private var lifecycleTask: Task<Void, Never>?
    private var outputTask: Task<Void, Never>?
    private(set) var lastDiagnostic: String?

    // MARK: Lifecycle

    /// Launch the worker rooted at `vaultRoot`. Idempotent: a no-op while already starting/running.
    func start(vaultRoot: URL?) {
        switch status {
        case .starting, .running:
            return
        default:
            break
        }
        guard let binary = Self.resolvedWorkerBinary() else {
            status = .unavailable(
                "Epistemos Work preview runtime is not bundled on this build.")
            return
        }
        let token = Self.randomToken()
        status = .starting
        lifecycleTask = Task { [weak self] in
            await self?.run(binary: binary, token: token, vaultRoot: vaultRoot)
        }
    }

    func stop() {
        lifecycleTask?.cancel()
        lifecycleTask = nil
        outputTask?.cancel()
        outputTask = nil
        if let process, process.isRunning { process.terminate() }
        process = nil
        switch status {
        case .starting, .running:
            status = .stopped
        default:
            break
        }
    }

    private func run(binary: URL, token: String, vaultRoot: URL?) async {
        // W-R4: provision skills into `<workspace>/.opencode/skills/` BEFORE launch so OpenWork's Skills panel isn't
        // empty (no manual setup). No-op when there's nothing to provision (honest).
        if let vaultRoot { WorkSkillsProvisioner.provisionAll(workspace: vaultRoot) }
        let proc = Process()
        proc.executableURL = binary
        proc.arguments = Self.workerArguments(port: Self.port, token: token, vaultRoot: vaultRoot)
        // Put the bundled OpenCode runtime's bin dir on PATH so the worker's MANAGED OpenCode can spawn the
        // vendored `opencode`/`bun` (they're not on the system PATH).
        proc.environment = Self.workerEnvironment()

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
        } catch {
            status = .failed(WorkServerDiagnostics.statusMessage(
                for: error,
                fallback: "Failed to launch Epistemos Work preview runtime"
            ))
            return
        }

        // Race the "listening" line against a timeout, then keep draining output so logs cannot fill the pipe.
        let baseURL: URL? = await withCheckedContinuation { continuation in
            let state = WorkOpenWorkListeningState(continuation)
            outputTask = Task.detached { [weak self] in
                do {
                    for try await line in pipe.fileHandleForReading.bytes.lines {
                        if let url = Self.parseListeningURL(from: line) { await state.resume(url) }
                        let message = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !message.isEmpty { await self?.recordWorkerDiagnostic(message) }
                    }
                } catch {
                    // Teardown closes the pipe; process state drives lifecycle.
                }
                await state.resume(nil)
            }
            Task {
                try? await Task.sleep(for: Self.listenTimeout)
                await state.resume(nil)
            }
        }

        if Task.isCancelled { return }
        if let baseURL {
            status = .running(baseURL: baseURL, token: token)
        } else {
            status = .failed("Epistemos Work preview runtime did not report a listening URL within \(Self.listenTimeout).")
            if proc.isRunning { proc.terminate() }
            outputTask?.cancel()
            outputTask = nil
        }
    }

    private func recordWorkerDiagnostic(_ message: String) {
        lastDiagnostic = message
    }

    private func handleProcessExit(statusCode: Int32) {
        switch status {
        case .starting:
            status = .failed("Epistemos Work preview runtime exited before it became ready (exit \(statusCode)).")
        case .running:
            status = .failed("Epistemos Work preview runtime exited unexpectedly (exit \(statusCode)).")
        default:
            break
        }
    }

    // MARK: Pure, testable helpers

    /// The worker argv: loopback host, the matching port, permissive loopback CORS (so the WebView's SPA origin can
    /// call it), the per-launch bearer token, and the vault as the workspace root.
    nonisolated static func workerArguments(port: Int, token: String, vaultRoot: URL?) -> [String] {
        // `--approval auto`: the worker DEFAULTS to MANUAL approval (donor config.ts → `?? "manual"`), which
        // dead-ends EVERY agent write (file writes, `mcp.add`, …) at an approval gate that has NO UI in our embed
        // → it waits `timeoutMs` then resolves denied → 403. The worker is loopback-only with a per-launch token,
        // launched + owned by Epistemos, and PERMISSIONS are the native shell's job (canon: the native bridge owns
        // Work runtime ⇄ Epistemos permissions/state) — so the redundant OpenWork gate is set to auto. This is also
        // what lets W-R2 register the `epistemos-native` MCP via `POST /workspace/:id/mcp` (an `mcp.add` write).
        var args = ["--host", "127.0.0.1", "--port", String(port), "--cors", "*", "--token", token,
                    "--approval", "auto"]
        if let vaultRoot { args += ["--workspace", vaultRoot.path] }
        return args
    }

    /// Parse the base URL from "OpenWork server listening on http://127.0.0.1:8787". Accepts only the expected
    /// loopback HTTP worker port and normalizes to `localhost` (ATS auto-exempts the `localhost` name; a raw IP
    /// literal can be ATS-blocked in the WebView).
    nonisolated static func parseListeningURL(from line: String) -> URL? {
        guard line.lowercased().contains("listening") else { return nil }
        guard let match = line.range(of: #"https?://[^\s]+"#, options: .regularExpression) else { return nil }
        let raw = line[match].trimmingCharacters(in: CharacterSet(charactersIn: "/.,;)\""))
        guard let components = URLComponents(string: raw),
              components.scheme?.lowercased() == "http",
              let host = components.host,
              components.port == Self.port,
              components.path.isEmpty || components.path == "/" else { return nil }
        guard host == "127.0.0.1" || host == "localhost" || host == "::1" else { return nil }
        return URL(string: "http://localhost:\(Self.port)")
    }

    /// The worker binary: staged App Support `Epistemos/WorkRuntime/openwork-server` (debug) → bundled Resources
    /// (release). nil → honest `.unavailable`.
    nonisolated static func resolvedWorkerBinary() -> URL? {
        let fileManager = FileManager.default
        if let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            let staged = appSupport.appendingPathComponent("Epistemos/WorkRuntime/openwork-server")
            if fileManager.isExecutableFile(atPath: staged.path) { return staged }
        }
        return Bundle.main.url(forResource: "openwork-server", withExtension: nil)
    }

    /// The worker's env. CRITICAL (donor `cli.ts`): the worker ONLY spawns its managed OpenCode when
    /// `OPENWORK_MANAGE_OPENCODE=1` — otherwise the workspace gets NO OpenCode base URL and the SPA shows
    /// `opencode_unconfigured / "OpenCode base URL is missing for this workspace"` (the owner's observed error).
    /// We also point it straight at the bundled `opencode` via `OPENWORK_OPENCODE_BIN` (cli.ts feeds this to the
    /// spawn as `bin`, more robust than PATH) and prepend its dir to PATH so opencode's own child lookups (e.g.
    /// `bun`) resolve — both vendored binaries are NOT on the system PATH.
    nonisolated static func workerEnvironment(bundle: Bundle = .main) -> [String: String] {
        let opencodeBin = WorkOpenCodeRuntime.bundledRuntimeURL(bundle: bundle)?.path
        return workerEnvironment(opencodeBin: opencodeBin, base: ProcessInfo.processInfo.environment)
    }

    /// Pure (testable): turn on worker-managed OpenCode + point it at the bundled binary. `OPENWORK_MANAGE_OPENCODE`
    /// is the switch the worker checks; `OPENWORK_OPENCODE_BIN` is the exact binary it spawns; PATH gets the bin's
    /// dir so opencode resolves its own sidecars.
    nonisolated static func workerEnvironment(opencodeBin: String?, base: [String: String]) -> [String: String] {
        var env = base
        env["OPENWORK_MANAGE_OPENCODE"] = "1"
        if let bin = opencodeBin, !bin.isEmpty {
            env["OPENWORK_OPENCODE_BIN"] = bin
            let dir = (bin as NSString).deletingLastPathComponent
            if !dir.isEmpty {
                let existing = env["PATH"] ?? ""
                env["PATH"] = existing.isEmpty ? dir : "\(dir):\(existing)"
            }
        }
        return env
    }

    /// W-R2/W-R3 ON THE WORKER PATH (recipe verified against the donor 2026-06-24): the worker spawns its OWN
    /// managed OpenCode and OVERRIDES `OPENCODE_CONFIG` with its runtime-DB-built config (`cli.ts` →
    /// `writeOpenworkRuntimeConfigFile` → `runtimeMcpMap`), so env-var injection of our fusion config can NOT
    /// reach it. The supported path is to REGISTER the app-hosted native MCP over the worker's HTTP API:
    /// `POST <worker>/workspace/<id>/mcp` (bearer token) → `addMcp` writes it to the runtime DB → the managed
    /// OpenCode picks it up on (lazy) spawn. This builds that POST body. The `config` shape mirrors the W-R3
    /// `epistemos-native` remote-MCP block (`WorkOpenCodeRuntime.mergedOpenCodeConfigJSON(nativeMCP:)`) and is
    /// accepted by the worker's `validateMcpConfig` (remote ⇒ requires only an http(s) `url`; extra keys allowed).
    /// `url` must be the loopback `http://localhost:<port>/mcp` (ATS-safe name, http allowed by the validator).
    nonisolated static func nativeMCPRegistrationBody(url: String, token: String) -> Data? {
        guard WorkNativeMCPRegistration(url: url, token: token).isTrustedLoopbackMCP else { return nil }
        let body: [String: Any] = [
            "name": "epistemos-native",
            "config": [
                "type": "remote",
                "url": url,
                "headers": ["Authorization": "Bearer \(token)"],
                "enabled": true,
            ],
        ]
        return try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    /// Q3 id-discovery for option B: parse the worker's workspaces-list response and return the `id` of the
    /// workspace whose `path` matches `vaultPath` (the worker registers the vault via `--workspace`). Each entry
    /// is serialized as `{ "id", "path", … }` under a top-level `"workspaces"` array (donor server.ts
    /// `serializeWorkspace`; the `{ …, workspaces: [...] }` responses). Avoids replicating the donor's sha256 path
    /// derivation. Resolution-tolerant: trailing-slash-normalized match, then a single-entry fallback (the worker
    /// registers exactly the vault, so a one-item list IS the vault). nil if absent/unparseable.
    nonisolated static func workspaceID(fromWorkspacesJSON data: Data, matchingPath vaultPath: String) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = root["workspaces"] as? [[String: Any]] else { return nil }
        func normalized(_ path: String) -> String {
            path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
        }
        let target = normalized(vaultPath)
        for entry in list {
            if let path = entry["path"] as? String, normalized(path) == target,
               let id = entry["id"] as? String { return id }
        }
        // The worker registers exactly the vault via `--workspace`, so a single-entry list IS the vault even if
        // path resolution (e.g. a symlinked root) made the strings differ.
        if list.count == 1, let id = list[0]["id"] as? String { return id }
        return nil
    }

    nonisolated private static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        // SAFETY: fixed-size buffer sized to `bytes.count`; SecRandomCopyBytes fills exactly that many bytes.
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess {
            return Data(bytes).base64EncodedString()
        }
        return (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
    }
}

private actor WorkOpenWorkListeningState {
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
