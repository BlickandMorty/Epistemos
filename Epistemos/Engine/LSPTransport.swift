import Foundation

// MARK: - LSPTransport
//
// V2.3 close-out (2026-05-05) — the architectural seam between
// `LSPClient` and the underlying message transport. Production
// transport is `RustLSPTransport` (in-process Rust LSP runtime via
// agent_core FFI); this protocol lets mocks + future implementations
// drop in without touching LSPClient.
//
// **Doctrine alignment.** Per the post-recovery V2 plan §V2.3, the
// goal "closes last subprocess in editor surface" is satisfied: the
// previous subprocess transport (`LSPServerProcess`) was deleted at
// V2.3 close-out and the in-process Rust runtime is the only shipped
// LSP path.

/// Transport protocol that LSPClient depends on. Implementations
/// move LSP `LSPMessage` envelopes between Swift and an LSP server
/// (in-process Rust runtime, mock, future implementations).
///
/// Conformance contract:
/// - `messages` MUST be `nonisolated` + cold + buffered (LSPClient
///   subscribes once via `startRouting()`; the transport must replay
///   or buffer missed messages until subscription).
/// - `send` and `shutdown` are `async` so actor-typed transports
///   (e.g. `RustLSPTransport` is `public actor`) can satisfy the
///   contract without dropping isolation. Class-typed transports
///   just have no-op async wrappers around their sync work; the
///   cost is one await suspension point per call.
/// - `send` MUST be `throws` so transport-side I/O failures surface
///   to the caller (LSPClient pulls pending continuations out and
///   resumes them with the send error so requests don't hang).
/// - `shutdown` MUST be idempotent — LSPClient may call it on its
///   way out + the host may also call it for orderly teardown.
nonisolated public protocol LSPTransport: Sendable {
    /// Async stream of every server-pushed `LSPMessage` (responses,
    /// notifications, server-side requests). Cold; LSPClient iterates
    /// it via `startRouting()`.
    nonisolated var messages: AsyncStream<LSPMessage> { get }

    /// Encode + send a single `LSPMessage` to the server. Throws on
    /// transport-side I/O failure; the caller maps thrown errors back
    /// to per-request error continuations.
    func send(_ message: LSPMessage) async throws

    /// Graceful teardown. Idempotent.
    func shutdown() async
}

// MARK: - InProcessLSPTransport stub
//
// Test-only / lifecycle-test transport that satisfies the
// `LSPTransport` protocol with no LSP server behind it. Every `send`
// call records the outgoing message in an audit log and emits a
// `MethodNotFound` JSON-RPC error response. Used by lifecycle-guard
// tests that want to exercise the LSPClient state machine without
// running an actual LSP server.
//
// Production callers use `RustLSPTransport` (the in-process Rust
// LSP runtime).
public actor InProcessLSPTransport: LSPTransport {

    public nonisolated let messages: AsyncStream<LSPMessage>
    private let messageContinuation: AsyncStream<LSPMessage>.Continuation

    /// Diagnostic — every message ever sent through this transport,
    /// in order. Useful for tests + a future "what did Swift send?"
    /// audit row. Accessed via `sentLogSnapshot()` (actor-bound).
    private var sentMessages: [LSPMessage] = []

    public init() {
        var continuation: AsyncStream<LSPMessage>.Continuation!
        self.messages = AsyncStream(bufferingPolicy: .bufferingNewest(256)) { c in
            continuation = c
        }
        self.messageContinuation = continuation
    }

    public func send(_ message: LSPMessage) async throws {
        sentMessages.append(message)
        // Stub behavior: echo a MethodNotFound error response for
        // every request, ack notifications silently. When the
        // tower-lsp Rust transport lands, this body becomes:
        //   try await ffi.lsp_send(message.toJsonString())
        // and the messages stream is fed by the FFI's response
        // channel.
        if case .request(let id, let method, _) = message {
            let error = LSPError(
                code: -32601, // JSON-RPC MethodNotFound
                message: "InProcessLSPTransport stub: \(method) not implemented yet",
                data: nil
            )
            messageContinuation.yield(.responseError(id: id, error: error))
        }
        // Notifications + responses-from-Swift are no-ops in stub mode.
    }

    public func shutdown() async {
        messageContinuation.finish()
    }

    /// Snapshot the recorded send log. Actor-bound.
    public func sentLogSnapshot() -> [LSPMessage] {
        sentMessages
    }

    /// Count of messages this transport has seen. Cheap actor-bound
    /// accessor used by diagnostics.
    public func sentCount() -> Int {
        sentMessages.count
    }
}
