import Foundation
import Observation
import Security

// SPIKE (2026-06-24, owner-greenlit): the native macOS-26 WorkRuntimeSupervisor.
//
// Canon Work shape: native Swift shell + controlled LOCAL Work runtime PROCESS + WKWebView surface + native
// bridge. This is the runtime-process tier — it launches the BUNDLED `opencode serve` as a headless HTTP/SSE
// server on loopback so the (later) WebView Work surface + native bridge drive ONE API seam. It fuses the
// donor lifecycle patterns inventoried in WORK_OPENWORK_PARITY_LEDGER (Row 7 managed-opencode + C11
// lifecycle/health-restart): free/loopback bind, per-launch bearer creds, startup-wait on the listening
// line, `/global/health` probe, kill-on-teardown.
//
// HONESTY (mirrors WorkOpenCodeShell): EXPLICIT, Pro-gated, VISIBLE sidecar for direct distribution — never
// hidden/default. When the bundled runtime is absent it reports `.unavailable` and launches NOTHING (no fake
// server). MAS is de-prioritized for Work; on a sandboxed build the runtime simply isn't bundled, so this
// stays honestly inert by construction.

/// Per-launch loopback credentials for the managed `opencode serve` (HTTP basic auth). Regenerated each start
/// so no long-lived secret lives in the WebView. Pure value type.
struct WorkRuntimeAuth: Equatable, Sendable {
    let username: String
    let password: String

    /// The `Authorization: Basic …` header value the native bridge injects into runtime requests.
    var basicAuthHeaderValue: String {
        let raw = "\(username):\(password)"
        return "Basic \(Data(raw.utf8).base64EncodedString())"
    }
}

@MainActor
@Observable
final class WorkRuntimeSupervisor {
    enum Status: Equatable, Sendable {
        /// Not started.
        case idle
        /// The bundled runtime is absent — honest inert (no server launched).
        case unavailable(String)
        /// Spawned; waiting for the listening line.
        case starting
        /// Live; the loopback base URL the WebView/native client drives.
        case running(baseURL: URL)
        /// Launch or health failed.
        case failed(String)
        /// Stopped by `stop()` / teardown.
        case stopped
    }

    /// Observable for the Work health row (VISIBLE sidecar requirement).
    private(set) var status: Status = .idle
    /// The per-launch credentials for the current run (nil until a run starts).
    private(set) var auth: WorkRuntimeAuth?

    /// How long to wait for `opencode serve` to print its listening line before failing.
    static let listenTimeout: Duration = .seconds(15)
    nonisolated static let maxSubprocessEnvironmentValueCharacters =
        WorkSubprocessEnvironment.maxSubprocessEnvironmentValueCharacters
    nonisolated static let maxSubprocessPathCharacters =
        WorkSubprocessEnvironment.maxSubprocessPathCharacters
    nonisolated static let maxSubprocessPathEntryCharacters =
        WorkSubprocessEnvironment.maxSubprocessPathEntryCharacters
    nonisolated static let maxSubprocessPathEntries =
        WorkSubprocessEnvironment.maxSubprocessPathEntries

    private var process: Process?
    private var lifecycleTask: Task<Void, Never>?
    private var outputTask: Task<Void, Never>?
    private(set) var lastDiagnostic: String?

    // MARK: Lifecycle

    /// Launch the managed runtime. Idempotent: a no-op while already starting/running.
    func start(bundle: Bundle = .main) {
        switch status {
        case .starting, .running:
            return
        default:
            break
        }
        guard let binary = WorkOpenCodeRuntime.bundledRuntimeURL(bundle: bundle) else {
            auth = nil
            status = .unavailable(
                "Epistemos Work runtime is not bundled yet; the runtime stays inert and no fake server is launched.")
            return
        }
        let credentials = WorkRuntimeAuth(username: Self.randomToken(), password: Self.randomToken())
        auth = credentials
        status = .starting
        lifecycleTask = Task { [weak self] in
            await self?.run(binary: binary, auth: credentials)
        }
    }

    /// Stop the runtime and reap the process (kill-on-teardown).
    func stop() {
        lifecycleTask?.cancel()
        lifecycleTask = nil
        outputTask?.cancel()
        outputTask = nil
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        switch status {
        case .starting, .running:
            status = .stopped
        default:
            break
        }
    }

    private func run(binary: URL, auth: WorkRuntimeAuth) async {
        let proc = Process()
        proc.executableURL = binary
        proc.arguments = Self.serveArguments(host: WorkOpenCodeRuntime.loopbackHost)
        proc.environment = Self.processEnvironment(runtimeBinary: binary, auth: auth)

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
                fallback: "Failed to launch `opencode serve`"
            ))
            return
        }

        // Race the listening line against a timeout, but keep draining output after startup so logs cannot fill the pipe.
        let listened: URL? = await withCheckedContinuation { continuation in
            let state = WorkRuntimeListeningState(continuation)
            outputTask = Task.detached { [weak self] in
                do {
                    for try await line in pipe.fileHandleForReading.bytes.lines {
                        if let url = Self.parseListeningURL(from: line) { await state.resume(url) }
                        let message = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !message.isEmpty { await self?.recordRuntimeDiagnostic(message) }
                    }
                } catch {
                    // Teardown closes the pipe; `process` state drives lifecycle.
                }
                await state.resume(nil)
            }
            Task {
                try? await Task.sleep(for: Self.listenTimeout)
                await state.resume(nil)
            }
        }

        if Task.isCancelled { return }
        if let baseURL = listened {
            status = .running(baseURL: baseURL)
        } else {
            status = .failed("`opencode serve` did not report a listening URL within \(Self.listenTimeout).")
            if proc.isRunning { proc.terminate() }
            outputTask?.cancel()
            outputTask = nil
        }
    }

    private func recordRuntimeDiagnostic(_ message: String) {
        lastDiagnostic = message
    }

    private func handleProcessExit(statusCode: Int32) {
        switch status {
        case .starting:
            status = .failed("Epistemos Work runtime exited before it became ready (exit \(statusCode)).")
        case .running:
            status = .failed("Epistemos Work runtime exited unexpectedly (exit \(statusCode)).")
        default:
            break
        }
    }

    // MARK: Pure, testable helpers

    /// The argv for the headless server, pinned to loopback. (No `--cors *`: the WebView serves the UI
    /// same-origin via a custom URL scheme, so the runtime origin stays tight — ledger Row 7.)
    nonisolated static func serveArguments(host: String) -> [String] {
        ["serve", "--hostname", host]
    }

    /// Sanitized child env: allowlisted inherited vars only, rebuilt PATH rooted at the bundled runtime's
    /// bin dir (so `opencode` finds its sibling `bun`), and explicit per-launch loopback basic-auth creds.
    nonisolated static func processEnvironment(
        runtimeBinary: URL,
        auth: WorkRuntimeAuth,
        base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var env = WorkSubprocessEnvironment.childEnvironment(
            binaryDirectories: [runtimeBinary.deletingLastPathComponent()],
            base: base
        )
        env["OPENCODE_SERVER_USERNAME"] = auth.username
        env["OPENCODE_SERVER_PASSWORD"] = auth.password
        return env
    }

    /// Parse the loopback base URL from a server startup line like
    /// `opencode server listening on http://127.0.0.1:4096`. Returns nil for non-listening or non-loopback lines.
    nonisolated static func parseListeningURL(from line: String) -> URL? {
        guard line.lowercased().contains("listening") else { return nil }
        guard let match = line.range(of: #"https?://[^\s]+"#, options: .regularExpression) else { return nil }
        let trimmed = line[match].trimmingCharacters(in: CharacterSet(charactersIn: "/.,;)\""))
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "http",
              let host = components.host,
              let port = components.port,
              (1024...65535).contains(port),
              components.path.isEmpty || components.path == "/" else { return nil }
        guard host == "127.0.0.1" || host == "localhost" || host == "::1" else { return nil }
        return URL(string: "http://\(host == "::1" ? "[::1]" : host):\(port)")
    }

    /// The health endpoint the supervisor / native bridge probes (ledger C11: `/global/health`).
    nonisolated static func healthURL(base: URL) -> URL {
        base.appendingPathComponent("global").appendingPathComponent("health")
    }

    nonisolated private static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        // SAFETY: fixed-size buffer sized to `bytes.count`; SecRandomCopyBytes fills exactly that many bytes.
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if result == errSecSuccess {
            return Data(bytes).base64EncodedString()
        }
        // Fallback to UUID entropy if the RNG is somehow unavailable.
        return (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
    }
}

private actor WorkRuntimeListeningState {
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
