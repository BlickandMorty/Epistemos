import Foundation
import OSLog

// MARK: - LSPServerProcess
//
// Wave 9.8 follow-up of the Extended Program Plan
// (cross-ref epistemos_code_verdict.md §3 "Intelligence" layer).
//
// Owns a SourceKit-LSP / clangd / rust-analyzer subprocess + its
// stdin/stdout pipes + the encode-write / read-decode loop. Built
// directly on Foundation `Process` + `Pipe` so no SPM dependency
// addition is required (swift-subprocess would be cleaner but adds
// a build dep).
//
// Protocol surface:
//   - send(_ message:) async throws — encode + write to LSP stdin
//   - messages: AsyncStream<LSPMessage> — drains LSP stdout into
//     the typed envelope via LSPMessageCodec.decodeOne
//   - shutdown() — graceful Process.terminate + drain
//
// The LSP-specific high-level RPC layer (initialize / textDocument/
// didOpen / textDocument/hover / etc.) lives on top of this in a
// future LSPClient class. This commit ships the transport.

/// Errors the LSP transport can raise.
nonisolated public enum LSPServerError: Error, CustomStringConvertible {
    case launchFailed(underlying: Error)
    case writeFailed(underlying: Error)
    case decodeFailed(underlying: Error)
    case processTerminated(code: Int32?)

    public var description: String {
        switch self {
        case let .launchFailed(error):
            return "LSPServerProcess: failed to launch subprocess — \(error)"
        case let .writeFailed(error):
            return "LSPServerProcess: failed to write to stdin — \(error)"
        case let .decodeFailed(error):
            return "LSPServerProcess: codec error — \(error)"
        case let .processTerminated(code):
            return "LSPServerProcess: subprocess terminated (code \(code.map(String.init) ?? "n/a"))"
        }
    }
}

/// Configuration for launching the LSP subprocess.
nonisolated public struct LSPServerConfig: Sendable, Hashable {
    /// Absolute path to the LSP executable.
    /// Examples: `/usr/bin/xcrun` (with arguments `["sourcekit-lsp"]`)
    ///           `/opt/homebrew/bin/clangd`
    ///           `~/.cargo/bin/rust-analyzer`
    public let executableURL: URL
    /// Argument list passed to the executable.
    public let arguments: [String]
    /// Working directory the subprocess runs in. Usually the
    /// workspace root.
    public let workingDirectory: URL?
    /// Environment to merge over the inherited `ProcessInfo` env.
    public let environment: [String: String]

    public init(
        executableURL: URL,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String] = [:]
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environment = environment
    }

    /// Convenience: configures `xcrun sourcekit-lsp` from the active
    /// developer dir.
    public static func sourcekitLSP(workspaceRoot: URL? = nil) -> LSPServerConfig {
        LSPServerConfig(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: ["sourcekit-lsp"],
            workingDirectory: workspaceRoot
        )
    }
}

/// LSP transport actor. Launches the subprocess + owns the read /
/// write loops. `messages` is an AsyncStream the consumer iterates
/// to receive decoded LSPMessage values.
public actor LSPServerProcess {

    public let config: LSPServerConfig
    private let log = Logger(subsystem: "com.epistemos", category: "LSPServerProcess")

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var messageContinuation: AsyncStream<LSPMessage>.Continuation?

    /// Async stream of decoded LSP messages from the server. Cold —
    /// no work happens until a consumer iterates. Iteration ends when
    /// the subprocess exits or `shutdown()` is called.
    public nonisolated let messages: AsyncStream<LSPMessage>

    public init(config: LSPServerConfig) {
        self.config = config
        // Build the AsyncStream synchronously in init. Actor init runs
        // before self is shared with any other isolation context, so
        // it's safe to set the actor-isolated `messageContinuation`
        // here without an `await`. AsyncStream.Continuation is Sendable.
        var continuation: AsyncStream<LSPMessage>.Continuation!
        self.messages = AsyncStream(bufferingPolicy: .bufferingNewest(256)) { c in
            continuation = c
        }
        self.messageContinuation = continuation
    }

    /// Launch the subprocess + start the read loop. Idempotent —
    /// subsequent calls after a successful launch are no-ops.
    public func launch() throws {
        if process?.isRunning == true { return }

        let proc = Process()
        proc.executableURL = config.executableURL
        proc.arguments = config.arguments
        if let cwd = config.workingDirectory {
            proc.currentDirectoryURL = cwd
        }
        var env = ProcessInfo.processInfo.environment
        for (k, v) in config.environment { env[k] = v }
        proc.environment = env

        let stdin = Pipe()
        let stdout = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        // Discard stderr by default; LSP servers chatter heavily.
        proc.standardError = Pipe()

        do {
            try proc.run()
        } catch {
            throw LSPServerError.launchFailed(underlying: error)
        }

        process = proc
        stdinPipe = stdin
        stdoutPipe = stdout
        startReadLoop()
        observeTermination(proc)
    }

    /// Send one message to the LSP server. Encodes via
    /// LSPMessageCodec + writes the framed bytes to stdin.
    public func send(_ message: LSPMessage) throws {
        guard let stdin = stdinPipe else {
            throw LSPServerError.writeFailed(
                underlying: NSError(
                    domain: "LSPServerProcess",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "subprocess not launched"]
                )
            )
        }
        let frame: Data
        do {
            frame = try LSPMessageCodec.encode(message)
        } catch {
            throw LSPServerError.decodeFailed(underlying: error)
        }
        do {
            try stdin.fileHandleForWriting.write(contentsOf: frame)
        } catch {
            throw LSPServerError.writeFailed(underlying: error)
        }
    }

    /// Gracefully terminate the subprocess + close pipes + finish
    /// the message stream.
    public func shutdown() {
        process?.terminate()
        try? stdinPipe?.fileHandleForWriting.close()
        messageContinuation?.finish()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
    }

    // MARK: - Read loop

    private func startReadLoop() {
        guard let stdout = stdoutPipe else { return }
        let handle = stdout.fileHandleForReading
        let log = self.log

        // Buffer is owned by the read loop; it accumulates partial
        // frames until LSPMessageCodec.decodeOne returns a complete
        // message.
        Task.detached { [weak self] in
            var buffer = Data()
            while true {
                let chunk: Data
                do {
                    let read = try handle.read(upToCount: 4096)
                    guard let r = read, !r.isEmpty else {
                        // EOF — server exited cleanly. Finish the
                        // stream.
                        await self?.finishStream()
                        return
                    }
                    chunk = r
                } catch {
                    log.warning("LSP read error: \(String(describing: error), privacy: .public)")
                    await self?.finishStream()
                    return
                }
                buffer.append(chunk)

                // Drain as many complete frames as the buffer holds.
                while true {
                    let result: LSPMessageCodec.DecodeResult
                    do {
                        result = try LSPMessageCodec.decodeOne(buffer: buffer)
                    } catch {
                        log.warning("LSP decode error: \(String(describing: error), privacy: .public)")
                        // Skip the malformed chunk by clearing the
                        // buffer; the connection is in a desync state
                        // either way.
                        buffer.removeAll()
                        break
                    }
                    switch result {
                    case .needMoreData:
                        // Wait for the next stdout chunk.
                        break
                    case .message(let msg, let consumed):
                        await self?.yield(msg)
                        buffer.removeFirst(consumed)
                        continue
                    }
                    break
                }
            }
        }
    }

    private func yield(_ message: LSPMessage) {
        messageContinuation?.yield(message)
    }

    private func finishStream() {
        messageContinuation?.finish()
    }

    private func observeTermination(_ proc: Process) {
        proc.terminationHandler = { [weak self] terminated in
            let code = terminated.terminationStatus
            Task { [weak self] in
                await self?.recordTermination(code: code)
            }
        }
    }

    private func recordTermination(code: Int32) {
        log.info("LSP subprocess exited with code \(code, privacy: .public)")
        messageContinuation?.finish()
    }
}
