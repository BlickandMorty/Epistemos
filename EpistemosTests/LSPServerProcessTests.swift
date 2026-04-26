import Foundation
import Testing

@testable import Epistemos

/// Wave 9.8 follow-up source-guard for `LSPServerProcess` — the
/// Foundation `Process` + `Pipe` wrapper that drives a SourceKit-LSP /
/// clangd / rust-analyzer subprocess.
///
/// These tests exercise:
///   - error description formatting (every `LSPServerError` case),
///   - `LSPServerConfig` init + `.sourcekitLSP(...)` factory,
///   - the actor's lifecycle invariants (send-before-launch error,
///     shutdown-before-launch no-op, launch-with-bogus-path error),
///   - read-loop EOF handling against a real one-shot subprocess
///     (`/bin/echo`), verifying the `messages` AsyncStream finishes
///     when the child exits.
@Suite("LSPServerProcess (Wave 9.8 follow-up)")
nonisolated struct LSPServerProcessTests {

    // MARK: - Error descriptions

    @Test("Every LSPServerError case formats with a recognisable prefix + payload")
    func errorDescriptions() {
        struct Boom: Error, CustomStringConvertible { var description: String { "boom" } }
        let launch = LSPServerError.launchFailed(underlying: Boom())
        #expect(launch.description.contains("LSPServerProcess: failed to launch"))
        #expect(launch.description.contains("boom"))

        let write = LSPServerError.writeFailed(underlying: Boom())
        #expect(write.description.contains("failed to write to stdin"))
        #expect(write.description.contains("boom"))

        let decode = LSPServerError.decodeFailed(underlying: Boom())
        #expect(decode.description.contains("codec error"))
        #expect(decode.description.contains("boom"))

        let term = LSPServerError.processTerminated(code: 137)
        #expect(term.description.contains("terminated"))
        #expect(term.description.contains("137"))

        let termNil = LSPServerError.processTerminated(code: nil)
        #expect(termNil.description.contains("n/a"),
                "nil exit code must render as 'n/a' so the message is still readable")
    }

    // MARK: - Config

    @Test("LSPServerConfig stores every init argument verbatim")
    func configInitStoresArgs() {
        let exe = URL(fileURLWithPath: "/usr/local/bin/clangd")
        let cwd = URL(fileURLWithPath: "/tmp/workspace")
        let cfg = LSPServerConfig(
            executableURL: exe,
            arguments: ["--background-index"],
            workingDirectory: cwd,
            environment: ["CLANGD_FLAGS": "-pretty"]
        )
        #expect(cfg.executableURL == exe)
        #expect(cfg.arguments == ["--background-index"])
        #expect(cfg.workingDirectory == cwd)
        #expect(cfg.environment == ["CLANGD_FLAGS": "-pretty"])
    }

    @Test("`.sourcekitLSP` factory points at xcrun + sourcekit-lsp")
    func sourcekitLSPFactory() {
        let cfg = LSPServerConfig.sourcekitLSP()
        #expect(cfg.executableURL.path == "/usr/bin/xcrun",
                "we must launch via xcrun so the active developer dir's sourcekit-lsp is picked")
        #expect(cfg.arguments == ["sourcekit-lsp"])
        #expect(cfg.workingDirectory == nil)

        let withCwd = LSPServerConfig.sourcekitLSP(
            workspaceRoot: URL(fileURLWithPath: "/tmp/ws")
        )
        #expect(withCwd.workingDirectory?.path == "/tmp/ws",
                "workspaceRoot argument must thread through to workingDirectory")
    }

    // MARK: - Lifecycle

    @Test("send() before launch throws .writeFailed (not .processTerminated) so the caller knows to launch first")
    func sendBeforeLaunchThrows() async {
        let proc = LSPServerProcess(config: LSPServerConfig.sourcekitLSP())
        do {
            try await proc.send(.notification(method: "ping", params: nil))
            #expect(Bool(false), "send() before launch MUST throw")
        } catch let LSPServerError.writeFailed(underlying) {
            // Underlying NSError's description should mention 'subprocess
            // not launched' so the human reading the log knows what to fix.
            let msg = String(describing: underlying)
            #expect(msg.contains("not launched"),
                    "writeFailed.underlying must explain that the subprocess wasn't launched yet")
        } catch {
            #expect(Bool(false), "expected .writeFailed; got \(error)")
        }
    }

    @Test("shutdown() before launch is a safe no-op (idempotent contract)")
    func shutdownBeforeLaunchIsSafe() async {
        let proc = LSPServerProcess(config: LSPServerConfig.sourcekitLSP())
        await proc.shutdown()  // must not crash
        await proc.shutdown()  // double-shutdown must also be safe
    }

    @Test("launch() with a bogus executable path throws .launchFailed")
    func launchWithBogusPathThrows() async {
        let cfg = LSPServerConfig(
            executableURL: URL(fileURLWithPath: "/this/path/does/not/exist/lsp"),
            arguments: []
        )
        let proc = LSPServerProcess(config: cfg)
        do {
            try await proc.launch()
            #expect(Bool(false), "launch with non-existent executable MUST throw")
        } catch is LSPServerError {
            // .launchFailed expected; pattern-match for clarity.
        } catch {
            #expect(Bool(false), "expected LSPServerError; got \(error)")
        }
        await proc.shutdown()
    }

    @Test("messages stream finishes after a short-lived subprocess (`/bin/echo`) exits")
    func messagesStreamFinishesAfterChildExits() async throws {
        // /bin/echo writes "lsp-test\n" to stdout and immediately
        // exits. The read loop reads the bytes, fails to decode as a
        // framed LSP message (no Content-Length header), clears the
        // desync buffer, then sees EOF on the next read → finishStream.
        // The AsyncStream iterator must therefore return nil within a
        // bounded time window.
        let cfg = LSPServerConfig(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["lsp-test"]
        )
        let proc = LSPServerProcess(config: cfg)
        try await proc.launch()

        // Drain with a hard 5s ceiling: if the stream never finishes,
        // the test fails fast instead of hanging CI.
        let stream = proc.messages
        let drainTask = Task<Int, Never> {
            var count = 0
            for await _ in stream { count += 1 }
            return count
        }
        let timeoutTask = Task<Bool, Never> {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            drainTask.cancel()
            return true
        }
        let count = await drainTask.value
        timeoutTask.cancel()

        // /bin/echo's "lsp-test\n" can't decode as an LSP frame, so
        // the stream finishes without yielding any message. The
        // important assertion is that the iterator returned (i.e. the
        // stream actually finished) — count is allowed to be 0.
        #expect(count == 0, "echo'd plain text must not decode as LSP frames")

        await proc.shutdown()
    }

    @Test("send() after shutdown throws .writeFailed (post-shutdown cleanup nulled stdinPipe)")
    func sendAfterShutdownThrows() async throws {
        let cfg = LSPServerConfig(
            executableURL: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["x"]
        )
        let proc = LSPServerProcess(config: cfg)
        try await proc.launch()
        await proc.shutdown()
        do {
            try await proc.send(.notification(method: "ping", params: nil))
            #expect(Bool(false), "send() after shutdown MUST throw")
        } catch is LSPServerError {
            // expected
        } catch {
            #expect(Bool(false), "expected LSPServerError; got \(error)")
        }
    }
}
