import Foundation

// MARK: - LSPTransport
//
// V2.3 first slice (2026-05-05) — the architectural seam between
// `LSPClient` and the underlying message transport. Refactored out of
// `LSPClient`'s previous concrete dependency on `LSPServerProcess` so a
// future in-process Rust LSP transport (tower-lsp + tree-sitter) can
// drop in without touching the client.
//
// **Doctrine alignment.** Per the post-recovery V2 plan §V2.3, the
// goal is "closes last subprocess in editor surface; tower-lsp +
// tree-sitter." This file lands the seam; the tower-lsp Rust crate
// arrives in a follow-up slice (see
// `docs/V2_3_LSP_MIGRATION_PLAN_2026_05_05.md`).
//
// The seam means LSPClient no longer cares whether its messages cross
// a stdio boundary to a `Process`-owned subprocess or stay in-process
// via FFI to a Rust crate. Switching transports becomes a one-line
// change at the call site.

/// Transport protocol that LSPClient depends on. Implementations
/// move LSP `LSPMessage` envelopes between Swift and an LSP server
/// (subprocess, in-process Rust, mock, etc.).
///
/// Conformance contract:
/// - `messages` MUST be `nonisolated` + cold + buffered (LSPClient
///   subscribes once via `startRouting()`; the transport must replay
///   or buffer missed messages until subscription).
/// - `send` and `shutdown` are `async` so actor-typed transports
///   (LSPServerProcess is `public actor`) can satisfy the contract
///   without dropping isolation. Class-typed transports just have
///   no-op async wrappers around their sync work; the cost is one
///   await suspension point per call.
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

// MARK: - LSPServerProcess conformance
//
// `LSPServerProcess` already satisfies the protocol shape — its
// public `messages: AsyncStream<LSPMessage>`, `send(_:)`, and
// `shutdown()` line up exactly. The conformance is empty + zero-cost.

extension LSPServerProcess: LSPTransport {}

// MARK: - InProcessLSPTransport stub (V2.3 follow-up landing zone)
//
// Placeholder transport that satisfies the LSPTransport protocol but
// has no LSP server behind it yet. Every `send` call records the
// outgoing message in `sentMessages` for tests/diagnostics and emits
// a `MethodNotFound` JSON-RPC error response on the messages stream.
//
// **Why ship the stub now.** Two reasons:
//   1. Proves the protocol seam works end-to-end — LSPClient can be
//      constructed against it, the routing loop runs, and a request
//      gets a (terminal) response without crashing or hanging.
//   2. Marks the integration point. When the Rust tower-lsp crate
//      lands, the `RustLSPTransport` (or rename of this stub) drops
//      its FFI calls into the `send` body; nothing in LSPClient or
//      the Swift surface needs to change.
//
// This is NOT shipped as a default LSPClient transport — it has to
// be explicitly constructed. LSPServerProcess remains the only
// production-wired transport until the Rust crate arrives.
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
