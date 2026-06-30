import Foundation
import Observation

// PIVOT (2026-06-24, owner-confirmed: "OpenGUI is the harness/bridge thing"): the native Swift bridge to the
// OpenGUI Runtime, which harnesses MULTIPLE engines (the owner's Work Chat engine picker: OpenCode, Claude Code,
// Codex, Pi, … and later Goose/Hermes). Architecture proven end-to-end before this file existed:
//   • Runtime chain  — `createOpenGUI → diagnose → connect → sessions.create → onEvent → send → waitUntilIdle`
//     drives the bundled `opencode serve` and streams (spike: epistemos-opengui-spike.mjs, SPIKE_OK).
//   • NDJSON sidecar — `og-sidecar.mjs` wraps that chain behind line-delimited JSON on stdin/stdout, proven over
//     a real subprocess boundary (og-sidecar-drive.mjs, 38 forwarded events, EXIT 0).
//   • Multi-engine   — the SAME generic chain connects opencode + claude-code + codex (og-engines-probe.mjs).
// This supervisor is the Swift HALF of that contract: spawn `bun og-sidecar.mjs` (cwd = the OpenGUI clone, PATH
// carrying the bundled opencode + bun), write NDJSON commands, parse NDJSON frames, forward `event` frames to the
// native Work UI. The picker just passes a different `harnessId` to `init`/`sessions.create`.
//
// LIFECYCLE OWNERSHIP (lesson 2026-06-24 — see feedback_reap_only_processes_you_spawned): own ONLY our own child.
// `stop()` sends a best-effort `close` (lets the sidecar's `og.close()` + port-scoped cleanup reap its opencode) then
// terminates OUR bun `Process` — never a broad CLI-name kill that could hit the owner's other apps.
//
// HONESTY: EXPLICIT, VISIBLE sidecar (never hidden/default). When the OpenGUI sidecar/bun isn't resolvable it
// reports `.unavailable` and launches NOTHING. Runtime proof of THIS Swift bridge is OWED (owner runs ⌘R).

/// A sidecar reply (`{type:"reply", id, ok, data}`). `data` is the raw JSON of the reply's `data` field (Sendable)
/// so it never crosses an actor boundary as `[String: Any]`; typed accessors parse it on demand.
struct WorkOGReply: Sendable {
    let ok: Bool
    let data: Data?
}

/// A decoded NDJSON frame from the sidecar's stdout.
enum WorkOGFrame: Sendable, Equatable {
    case ready
    case reply(id: String, ok: Bool, data: Data?)
    case error(id: String?, message: String)
    case event(sessionId: String, event: Data)
    case harnessEvent(event: Data)   // permission.*/question.* (the native permission/question card channel)
}

enum WorkOGError: Error, Sendable, Equatable {
    case notRunning
    case encoding
    case timeout(String)
    case sidecar(String)
    case stopped
    case unavailable(String)
}

@MainActor
@Observable
final class WorkOpenGUISupervisor {
    enum Status: Equatable, Sendable {
        /// Not started.
        case idle
        /// The OpenGUI sidecar / bun isn't resolvable — honest inert (nothing launched).
        case unavailable(String)
        /// Spawned; awaiting the `ready` frame + `init`.
        case starting
        /// Live; the engines the runtime connected (the picker's available harnessIds).
        case running(connectedHarnesses: [String])
        /// Launch / init failed.
        case failed(String)
        /// Stopped by `stop()` / teardown.
        case stopped
    }

    /// Observable for the Work health row + engine picker (VISIBLE sidecar requirement).
    private(set) var status: Status = .idle
    /// Last non-fatal sidecar error (`{type:"error"}` with no matching request id).
    private(set) var lastError: String?
    /// Forwarded live session events: `(sessionId, rawEventJSON)`. The UI layer decodes the LiveSessionEvent.
    var onEvent: (@MainActor (String, Data) -> Void)?
    /// A permission request from the engine (HarnessEvent `permission.requested`) → render a native permission card.
    var onPermissionRequest: (@MainActor (WorkPermissionRequest) -> Void)?
    /// A permission request was cleared/resolved engine-side (HarnessEvent `permission.cleared`); arg = sessionID.
    var onPermissionCleared: (@MainActor (String) -> Void)?
    /// A question request from the engine (HarnessEvent `question.requested`) → render a native question card.
    var onQuestion: (@MainActor (WorkQuestionRequest) -> Void)?
    /// A question was cleared/resolved engine-side (HarnessEvent `question.cleared`); arg = sessionID.
    var onQuestionCleared: (@MainActor (String) -> Void)?

    /// How long to wait for the sidecar's `ready` frame before failing.
    static let readyTimeout: Duration = .seconds(20)

    /// Where the sidecar runs from + writes runtime state (dev: the research clone; ship: a bundled copy).
    let sidecarRoot: URL
    let dataDir: String

    private var process: Process?
    private var stdin: FileHandle?
    private var lifecycleTask: Task<Void, Never>?
    private var readTask: Task<Void, Never>?
    private var stderrTask: Task<Void, Never>?
    private var readyContinuation: CheckedContinuation<Void, Error>?
    private var readyTimeoutTask: Task<Void, Never>?
    private var pending: [String: CheckedContinuation<WorkOGReply, Error>] = [:]
    private var requestTimeouts: [String: Task<Void, Never>] = [:]
    private var idCounter: Int = 0

    /// `sidecarRoot` = the OpenGUI clone dir holding `og-sidecar.mjs`. Defaults from
    /// `EPISTEMOS_OPENGUI_SIDECAR_ROOT` (dev) so the supervisor never hardcodes a machine path.
    init(sidecarRoot: URL? = nil, dataDir: String? = nil) {
        self.sidecarRoot = sidecarRoot
            ?? Self.defaultSidecarRoot()
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.dataDir = dataDir ?? Self.defaultDataDir()
    }

    // MARK: Lifecycle

    /// Spawn the sidecar, await `ready`, then `init` the runtime against `repo` for the given `harnesses`.
    /// Idempotent: a no-op while already starting/running.
    func start(repo: String, harnesses: [String] = ["opencode"], bundle: Bundle = .main) {
        switch status {
        case .starting, .running:
            return
        default:
            break
        }
        guard let bun = Self.resolveBun(bundle: bundle) else {
            status = .unavailable("Epistemos Work runtime is not available on this build.")
            return
        }
        let entry = sidecarRoot.appendingPathComponent("og-sidecar.mjs")
        guard FileManager.default.fileExists(atPath: entry.path) else {
            status = .unavailable("Epistemos Work runtime bridge is missing at \(entry.path).")
            return
        }
        status = .starting
        lifecycleTask = Task { [weak self] in
            await self?.run(bun: bun, entry: entry, repo: repo, harnesses: harnesses, bundle: bundle)
        }
    }

    /// Stop the sidecar: best-effort `close` (lets it reap its opencode), then terminate OUR bun process only.
    func stop() {
        lifecycleTask?.cancel(); lifecycleTask = nil
        readyTimeoutTask?.cancel(); readyTimeoutTask = nil
        // Best-effort close so the sidecar's `og.close()` runs before we terminate the process.
        if let stdin {
            try? stdin.write(contentsOf: Data("{\"id\":\"_close\",\"cmd\":\"close\"}\n".utf8))
            try? stdin.close()
        }
        stdin = nil
        readTask?.cancel(); readTask = nil
        stderrTask?.cancel(); stderrTask = nil
        if let process, process.isRunning { process.terminate() } // OUR child only
        process = nil
        // Fail any in-flight requests so awaiters don't hang.
        for (_, task) in requestTimeouts { task.cancel() }
        requestTimeouts.removeAll()
        for (_, cont) in pending { cont.resume(throwing: WorkOGError.stopped) }
        pending.removeAll()
        if let rc = readyContinuation { readyContinuation = nil; rc.resume(throwing: WorkOGError.stopped) }
        switch status {
        case .starting, .running: status = .stopped
        default: break
        }
    }

    private func run(bun: URL, entry: URL, repo: String, harnesses: [String], bundle: Bundle) async {
        let proc = Process()
        proc.executableURL = bun
        proc.arguments = [entry.lastPathComponent]
        proc.currentDirectoryURL = sidecarRoot
        // Give this launch a UNIQUE opencode port so the sidecar's port-scoped reapOpencode only ever kills THIS launch's
        // opencode (never the owner's other opencode, which runs on different ports). nil → sidecar default 4096.
        proc.environment = Self.processEnvironment(
            bundle: bundle, bunDir: bun.deletingLastPathComponent(), opencodePort: Self.freeTCPPort())

        let inPipe = Pipe(); let outPipe = Pipe(); let errPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        stdin = inPipe.fileHandleForWriting
        process = proc

        do {
            try proc.run()
        } catch {
            status = .failed(WorkServerDiagnostics.statusMessage(
                for: error,
                fallback: "Failed to launch Epistemos Work runtime"
            ))
            return
        }
        startReading(outPipe.fileHandleForReading)
        startDrainingStderr(errPipe.fileHandleForReading)

        do {
            try await awaitReady(timeout: Self.readyTimeout)
            if Task.isCancelled { return }
            let ids = try await initRuntime(repo: repo, harnesses: harnesses)
            if Task.isCancelled { return }
            status = .running(connectedHarnesses: ids)
        } catch {
            status = .failed("Epistemos Work runtime init failed: \(error)")
            stop()
        }
    }

    // MARK: Commands (NDJSON request/reply)

    /// Send a command + await its `reply` frame (matched by id). Per-request timeout so a stuck sidecar can't hang.
    @discardableResult
    func request(_ cmd: String, _ args: [String: Any] = [:], timeout: Duration = .seconds(30)) async throws -> WorkOGReply {
        let id = nextID()
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<WorkOGReply, Error>) in
            pending[id] = cont
            requestTimeouts[id] = Task { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.failPending(id, WorkOGError.timeout(cmd))
            }
            do {
                try writeLine(try Self.encodeCommand(id: id, cmd: cmd, args: args))
            } catch {
                pending[id] = nil
                requestTimeouts[id]?.cancel(); requestTimeouts[id] = nil
                cont.resume(throwing: error)
            }
        }
    }

    /// `init` the runtime → the connected harnessIds (the engines the picker can offer).
    @discardableResult
    func initRuntime(repo: String, harnesses: [String]) async throws -> [String] {
        let reply = try await request("init", ["repo": repo, "harnesses": harnesses, "dataDir": dataDir])
        guard reply.ok else { throw WorkOGError.sidecar("init returned ok=false") }
        return try Self.validatedConnectedHarnesses(reply.data)
    }

    /// Create a session on a chosen engine (the picker passes `harnessId`).
    @discardableResult
    func createSession(title: String, harnessId: String = "opencode") async throws -> String {
        let reply = try await request("sessions.create", ["title": title, "harnessId": harnessId])
        guard reply.ok, let sid = Self.stringField(reply.data, key: "sessionId") else {
            throw WorkOGError.sidecar("sessions.create returned no sessionId")
        }
        return sid
    }

    func send(_ text: String, sessionId: String, model: String? = nil, agent: String? = nil, variant: String? = nil) async throws {
        var args: [String: Any] = ["sessionId": sessionId, "text": text, "whileBusy": "wait"]
        // `model` is the composite `providerID/modelID` picker id → rebuild the `SelectedModel {providerID, modelID}`
        // OBJECT opencode's prompt API expects (a bare string is ignored → silent fallback to the default model).
        if let model, let parts = WorkEngineResources.splitSelectionID(model) {
            args["model"] = ["providerID": parts.providerID, "modelID": parts.modelID]
        }
        if let agent { args["agent"] = agent }
        if let variant { args["variant"] = variant }
        let reply = try await request("send", args, timeout: .seconds(120))
        try Self.requireOK(reply, command: "send")
    }

    func waitUntilIdle(sessionId: String, timeoutMs: Int = 90_000) async throws {
        let reply = try await request(
            "waitIdle", ["sessionId": sessionId, "timeoutMs": timeoutMs],
            timeout: .milliseconds(timeoutMs + 10_000))
        try Self.requireOK(reply, command: "waitIdle")
    }

    /// Open an existing session by id on a chosen engine → its (namespaced) session id (recents → reopen).
    @discardableResult
    func openSession(_ sessionId: String, harnessId: String = "opencode") async throws -> String {
        let reply = try await request("sessions.open", ["sessionId": sessionId, "harnessId": harnessId])
        guard reply.ok, let sid = Self.stringField(reply.data, key: "sessionId") else {
            throw WorkOGError.sidecar("sessions.open returned no sessionId")
        }
        return sid
    }

    /// Cancel a running turn (SessionHandle.abort) — the native stop button.
    func abort(sessionId: String) async throws {
        let reply = try await request("abort", ["sessionId": sessionId])
        try Self.requireOK(reply, command: "abort")
    }

    /// Reply to a permission card (allow once/always or deny). Maps the native decision → the runtime wire value
    /// ("once"|"always"|"reject"); `sessionId` is the permission request's sessionID (raw engine id, used as-is).
    func respondPermission(
        harnessId: String = "opencode", sessionId: String, permissionId: String, decision: WorkPermissionDecision
    ) async throws {
        let response: String
        switch decision {
        case .allowOnce: response = "once"
        case .allowAlways: response = "always"
        case .reject: response = "reject"
        }
        let reply = try await request("respondPermission", [
            "harnessId": harnessId, "sessionId": sessionId, "permissionId": permissionId, "response": response])
        try Self.requireOK(reply, command: "respondPermission")
    }

    /// Answer a question card. `answers` is one entry per prompt (each = the selected option labels / a custom string).
    func respondQuestion(
        harnessId: String = "opencode", requestId: String, answers: [[String]]
    ) async throws {
        let reply = try await request("respondQuestion", [
            "harnessId": harnessId, "requestId": requestId, "answers": answers])
        try Self.requireOK(reply, command: "respondQuestion")
    }

    /// Dismiss a question card without answering.
    func rejectQuestion(harnessId: String = "opencode", requestId: String) async throws {
        let reply = try await request("rejectQuestion", ["harnessId": harnessId, "requestId": requestId])
        try Self.requireOK(reply, command: "rejectQuestion")
    }

    /// The diagnosed-READY engine ids (the multi-engine picker's roster — engines that can connect in this env).
    func diagnose() async throws -> [String] {
        let reply = try await request("diagnose")
        try Self.requireOK(reply, command: "diagnose")
        guard let data = reply.data,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let harnesses = obj["harnesses"] as? [[String: Any]] else { return [] }
        return harnesses.compactMap { ($0["ready"] as? Bool) == true ? ($0["harnessId"] as? String) : nil }
    }

    /// Lazily connect an additional engine on selection (the roster is registered at init; OpenCode connects first).
    /// Merges the newly-connected id into `status.connectedHarnesses`. Returns the connected ids.
    @discardableResult
    func connect(_ harnessId: String) async throws -> [String] {
        let reply = try await request("connect", ["harnessId": harnessId])
        guard reply.ok else { throw WorkOGError.sidecar("connect failed for \(harnessId)") }
        let connected = Self.stringArray(reply.data, key: "connectedHarnessIds")
        if case .running(let existing) = status {
            status = .running(connectedHarnesses: existing + connected.filter { !existing.contains($0) })
        }
        return connected
    }

    /// List the engine's existing sessions → native WorkSessions (recents/rail). Empty on failure (never throws up).
    func listSessions(harnessId: String = "opencode", workspaceID: String) async throws -> [WorkSession] {
        let reply = try await request("sessions.list", ["harnessId": harnessId])
        try Self.requireOK(reply, command: "sessions.list")
        guard let data = reply.data else { return [] }
        return WorkSessionMapper.workSessions(fromSidecarListJSON: data, workspaceID: workspaceID)
    }

    /// An engine's models / agents / commands (HarnessHandle.loadResources) → the compact model/agent picker + slash-commands.
    func loadResources(harnessId: String = "opencode") async throws -> WorkEngineResources {
        let reply = try await request("loadResources", ["harnessId": harnessId])
        guard reply.ok else { throw WorkOGError.sidecar("loadResources returned ok=false") }
        return WorkEngineResourcesDecoder.decode(reply.data)
    }

    /// A session's transcript history (SessionHandle.messages) as raw JSON, for later native projection into the transcript.
    func messages(sessionId: String, limit: Int? = nil, before: String? = nil) async throws -> Data? {
        var args: [String: Any] = ["sessionId": sessionId]
        if let limit = Self.sanitizedMessagesLimit(limit) { args["limit"] = limit }
        if let before { args["before"] = before }
        let reply = try await request("messages", args)
        try Self.requireOK(reply, command: "messages")
        return reply.data
    }

    // MARK: Stream reading

    private func startReading(_ handle: FileHandle) {
        readTask = Task.detached { [weak self] in
            do {
                for try await line in handle.bytes.lines {
                    await self?.handleLine(line)
                }
            } catch {
                // EOF / read error → fall through to teardown notification.
            }
            await self?.handleEOF()
        }
    }

    /// Drain sidecar stderr so diagnostics can never fill the pipe and deadlock the NDJSON control channel.
    private func startDrainingStderr(_ handle: FileHandle) {
        stderrTask = Task.detached { [weak self] in
            do {
                for try await line in handle.bytes.lines {
                    let message = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !message.isEmpty { await self?.recordSidecarDiagnostic(message) }
                }
            } catch {
                // Teardown closes the pipe; stdout EOF is the lifecycle signal.
            }
        }
    }

    private func recordSidecarDiagnostic(_ message: String) {
        lastError = message
    }

    private func handleLine(_ line: String) {
        guard let frame = Self.decodeFrame(line) else { return }
        switch frame {
        case .ready:
            if let rc = readyContinuation {
                readyContinuation = nil
                readyTimeoutTask?.cancel(); readyTimeoutTask = nil
                rc.resume()
            }
        case .reply(let id, let ok, let data):
            resolvePending(id, .success(WorkOGReply(ok: ok, data: data)))
        case .error(let id, let message):
            if let id, pending[id] != nil {
                resolvePending(id, .failure(WorkOGError.sidecar(message)))
            } else {
                lastError = message
            }
        case .event(let sessionId, let event):
            onEvent?(sessionId, event)
        case .harnessEvent(let event):
            routeHarnessEvent(event)
        }
    }

    /// Route a forwarded HarnessEvent (permission.*/question.*) to the native callbacks. Lenient: unknown types no-op.
    private func routeHarnessEvent(_ data: Data) {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let type = obj["type"] as? String else { return }
        switch type {
        case "permission.requested":
            if let request = WorkPermissionRequestDecoder.decode(any: obj) { onPermissionRequest?(request) }
        case "permission.cleared":
            if let sid = Self.nonEmptyString(obj["sessionID"]) ?? Self.nonEmptyString(obj["sessionId"]) {
                onPermissionCleared?(sid)
            }
        case "question.requested":
            if let request = WorkQuestionRequestDecoder.decode(any: obj) { onQuestion?(request) }
        case "question.cleared":
            if let sid = Self.nonEmptyString(obj["sessionID"]) ?? Self.nonEmptyString(obj["sessionId"]) {
                onQuestionCleared?(sid)
            }
        default:
            break
        }
    }

    private func handleEOF() {
        guard case .running = status else {
            if case .starting = status {
                let error = WorkOGError.sidecar("Epistemos Work runtime exited before ready.")
                status = .failed("Epistemos Work runtime exited before ready.")
                failReady(error)
                failAllPending(error)
            }
            return
        }
        failAllPending(WorkOGError.sidecar("Epistemos Work runtime exited."))
        status = .stopped
    }

    private func resolvePending(_ id: String, _ result: Result<WorkOGReply, Error>) {
        guard let cont = pending[id] else { return }
        pending[id] = nil
        requestTimeouts[id]?.cancel(); requestTimeouts[id] = nil
        cont.resume(with: result)
    }

    private func failPending(_ id: String, _ error: Error) {
        resolvePending(id, .failure(error))
    }

    private func failAllPending(_ error: Error) {
        for (_, task) in requestTimeouts { task.cancel() }
        requestTimeouts.removeAll()
        let continuations = pending.values
        pending.removeAll()
        for cont in continuations {
            cont.resume(throwing: error)
        }
    }

    private func awaitReady(timeout: Duration) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            readyContinuation = cont
            readyTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.failReady(WorkOGError.timeout("ready"))
            }
        }
    }

    private func failReady(_ error: Error) {
        guard let rc = readyContinuation else { return }
        readyContinuation = nil
        rc.resume(throwing: error)
    }

    private func writeLine(_ line: String) throws {
        guard let stdin else { throw WorkOGError.notRunning }
        guard let data = line.data(using: .utf8) else { throw WorkOGError.encoding }
        try stdin.write(contentsOf: data)
    }

    private func nextID() -> String {
        idCounter += 1
        return "r\(idCounter)"
    }

    // MARK: Pure, testable helpers

    /// The child env: inherit, then PREPEND the bundled OpenCode runtime bin dir + Resources + bun's dir to PATH.
    /// No secrets injected — OpenCode reads its own `~/.local/share/opencode/auth.json` (carries over).
    nonisolated static func processEnvironment(
        bundle: Bundle = .main,
        bunDir: URL,
        opencodePort: Int? = nil,
        base: [String: String] = ProcessInfo.processInfo.environment,
        resourcesOverride: URL? = nil
    ) -> [String: String] {
        var env = base
        let resources = resourcesOverride ?? bundle.resourceURL
        var prefix: [String] = []
        func appendPrefix(_ path: String?) {
            guard let path, !path.isEmpty, !prefix.contains(path) else { return }
            prefix.append(path)
        }
        appendPrefix(WorkOpenCodeRuntime.resolveRuntimeURL(inResources: resources)?.deletingLastPathComponent().path)
        appendPrefix(resources?.path)
        appendPrefix(bunDir.path)
        let existing = env["PATH"] ?? ""
        env["PATH"] = (prefix + (existing.isEmpty ? [] : [existing])).joined(separator: ":")
        // Unique per-launch opencode port → the sidecar's reapOpencode (reads OPENGUI_OPENCODE_PORT) is genuinely
        // spawn-scoped, and the opencode-bridge's LOCAL_SERVER_PORT reads the SAME var at import. nil → sidecar default 4096.
        if let opencodePort, isValidManagedOpencodePort(opencodePort) {
            env["OPENGUI_OPENCODE_PORT"] = String(opencodePort)
        }
        return env
    }

    nonisolated static func isValidManagedOpencodePort(_ port: Int) -> Bool {
        port > 1024 && port <= 65535
    }

    /// A free TCP port on loopback (bind :0 → read OS-assigned → close), for a UNIQUE per-launch OPENGUI_OPENCODE_PORT so
    /// the sidecar's port-scoped reap can't hit the owner's other opencode. nil on any failure → caller falls back to the
    /// sidecar default (4096). Tiny TOCTOU window between close + the bridge's later bind is handled by the bridge's own
    /// port-in-use / stale-server detection.
    nonisolated static func freeTCPPort() -> Int? {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0                          // 0 → OS assigns a free port
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { return nil }
        var assigned = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &assigned) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &len)
            }
        }
        guard named == 0 else { return nil }
        let port = Int(UInt16(bigEndian: assigned.sin_port))
        return isValidManagedOpencodePort(port) ? port : nil
    }

    /// Encode `{id, cmd, ...args}` as a single NDJSON line (trailing newline included).
    nonisolated static func encodeCommand(id: String, cmd: String, args: [String: Any]) throws -> String {
        var obj = args
        obj["id"] = id
        obj["cmd"] = cmd
        let data = try JSONSerialization.data(withJSONObject: obj)
        guard let str = String(data: data, encoding: .utf8) else { throw WorkOGError.encoding }
        return str + "\n"
    }

    /// Decode one stdout line into a frame; nil for blank / non-JSON / unknown lines (sidecar diagnostics go to stderr).
    nonisolated static func decodeFrame(_ line: String) -> WorkOGFrame? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let type = obj["type"] as? String else { return nil }
        switch type {
        case "ready":
            return .ready
        case "reply":
            guard let id = nonEmptyString(obj["id"]) else { return nil }
            return .reply(id: id, ok: obj["ok"] as? Bool ?? false, data: subJSON(obj["data"]))
        case "error":
            return .error(id: obj["id"] as? String, message: obj["message"] as? String ?? "unknown")
        case "event":
            guard let sessionId = nonEmptyString(obj["sessionId"]),
                  let event = subJSON(obj["event"]) else { return nil }
            return .event(sessionId: sessionId, event: event)
        case "harnessEvent":
            guard let event = subJSON(obj["event"]) else { return nil }
            return .harnessEvent(event: event)
        default:
            return nil
        }
    }

    nonisolated static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : string
    }

    nonisolated static func sanitizedMessagesLimit(_ limit: Int?) -> Int? {
        guard let limit, limit > 0 else { return nil }
        return min(limit, 500)
    }

    nonisolated static func requireOK(_ reply: WorkOGReply, command: String) throws {
        guard reply.ok else { throw WorkOGError.sidecar("\(command) returned ok=false") }
    }

    /// Re-serialize a nested JSON object/array field to `Data` (Sendable); nil for scalars/missing.
    nonisolated static func subJSON(_ value: Any?) -> Data? {
        guard let value, JSONSerialization.isValidJSONObject(value) else { return nil }
        return try? JSONSerialization.data(withJSONObject: value)
    }

    nonisolated static func stringArray(_ data: Data?, key: String) -> [String] {
        guard let data, let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [] }
        return (obj[key] as? [String]) ?? []
    }

    nonisolated static func stringField(_ data: Data?, key: String) -> String? {
        guard let data, let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return obj[key] as? String
    }

    nonisolated static func validatedConnectedHarnesses(_ data: Data?) throws -> [String] {
        let ids = stringArray(data, key: "connectedHarnessIds")
        if !ids.isEmpty { return ids }
        let details = initErrorsSummary(data).map { ": \($0)" } ?? "."
        throw WorkOGError.sidecar("init connected no Work engines\(details)")
    }

    nonisolated static func initErrorsSummary(_ data: Data?) -> String? {
        guard let data,
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let errors = obj["errors"] as? [Any],
              !errors.isEmpty else { return nil }
        let parts = errors.prefix(3).map { raw -> String in
            if let string = raw as? String { return string }
            if let object = raw as? [String: Any] {
                let harness = (object["harnessId"] as? String) ?? (object["id"] as? String)
                let message = (object["error"] as? String) ?? (object["message"] as? String)
                    ?? String(describing: object)
                if let harness, !harness.isEmpty { return "\(harness): \(message)" }
                return message
            }
            return String(describing: raw)
        }
        return parts.joined(separator: "; ")
    }

    /// Resolve bundled `bun` from the same directory as the bundled OpenCode runtime, or from a flattened Resources root.
    nonisolated static func resolveBundledBun(inResources resources: URL?) -> URL? {
        guard let resources else { return nil }
        if let runtime = WorkOpenCodeRuntime.resolveRuntimeURL(inResources: resources) {
            let sibling = runtime.deletingLastPathComponent().appendingPathComponent("bun")
            if FileManager.default.isExecutableFile(atPath: sibling.path) {
                return sibling
            }
        }
        let bundled = resources.appendingPathComponent("bun")
        return FileManager.default.isExecutableFile(atPath: bundled.path) ? bundled : nil
    }

    /// Resolve `bun`: bundled runtime sibling / flattened `Resources/bun`, then common install dirs. `/usr/bin/env bun`
    /// won't work for `executableURL`, so fall back to the first existing known path. nil → `.unavailable`.
    nonisolated static func resolveBun(bundle: Bundle = .main) -> URL? {
        if let bundled = resolveBundledBun(inResources: bundle.resourceURL),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        for candidate in ["/opt/homebrew/bin/bun", "/usr/local/bin/bun",
                          NSHomeDirectory() + "/.bun/bin/bun"] {
            if FileManager.default.isExecutableFile(atPath: candidate) { return URL(fileURLWithPath: candidate) }
        }
        return nil
    }

    /// Dev default for the OpenGUI clone dir: `EPISTEMOS_OPENGUI_SIDECAR_ROOT` if set, else (DEBUG only) the research
    /// clone so ⌘R "just works" without scheme env config. Ship bundles the sidecar (this fallback is debug + best-effort).
    nonisolated static func defaultSidecarRoot(
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        if let path = env["EPISTEMOS_OPENGUI_SIDECAR_ROOT"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        #if DEBUG
        let devClone = NSHomeDirectory() + "/Downloads/Epistemos/.research-clones/work/opengui"
        if FileManager.default.fileExists(atPath: devClone + "/og-sidecar.mjs") {
            return URL(fileURLWithPath: devClone, isDirectory: true)
        }
        #endif
        return nil
    }

    /// Runtime-state dir under Application Support (created on demand by the sidecar).
    nonisolated static func defaultDataDir() -> String {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false))
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("Epistemos/OpenGUIRuntime", isDirectory: true).path
    }
}
