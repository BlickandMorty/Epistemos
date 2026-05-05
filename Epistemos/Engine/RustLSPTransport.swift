import Foundation
import os

// MARK: - V2.3 Stage C: RustLSPTransport
//
// In-process Swift transport that conforms to `LSPTransport` and
// drives the Rust `LspKernel` via the FFI exports landed in V2.3
// Stage B.
//
// **Architectural payoff:** the V2.3 sentence "closes last subprocess
// in editor surface" is now literally true. No `Process`, no `Pipe`,
// no stdin/stdout draining — every LSP message crosses the FFI
// boundary in-process to a Rust LspKernel. The previous subprocess
// transport (`LSPServerProcess`) was deleted at V2.3 close-out.
//
// **Doctrine alignment** (cognitive DAG doctrine §10): keeping this
// transport in-process satisfies the "no subprocess or bloat" intent.
// The hand-rolled Rust LspKernel uses zero new Cargo deps — the wire
// format is small enough to write directly until Stage 2 adds
// hover/definition + tree-sitter.
//
// **FFI usage shape:**
//   - `send(_:)` encodes the LSPMessage → JSON-RPC string → calls
//     `lspSendMessageJson` → returns immediately (response is
//     queued on the kernel's outbox for the next poll).
//   - `messages` AsyncStream is fed by an internal Task that
//     polls `lspPollResponseJson` on a 5ms interval, decodes each
//     non-empty response into an LSPMessage, and yields onto the
//     stream.
//   - `shutdown()` cancels the poll task + finishes the stream.

#if canImport(agent_coreFFI)

/// In-process LSP transport that drives the Rust `LspKernel` via
/// agent_core FFI. Conforms to `LSPTransport` so any `LSPClient
/// (transport:)` call site can use it directly.
///
/// The transport is `actor`-typed because it owns the poll task and
/// the messages-stream continuation; both must be accessed under
/// actor isolation. The protocol's `messages` requirement is
/// `nonisolated` because it's a `let` populated in init.
public actor RustLSPTransport: LSPTransport {

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "RustLSPTransport"
    )

    // MARK: - LSPTransport conformance

    public nonisolated let messages: AsyncStream<LSPMessage>
    private let messageContinuation: AsyncStream<LSPMessage>.Continuation

    private var pollTask: Task<Void, Never>?
    private var isShutdown: Bool = false

    /// Poll interval in nanoseconds. The Rust kernel queues responses
    /// synchronously inside `send`, so this only matters for
    /// server-initiated notifications (which Phase 1 doesn't issue).
    /// 5ms is a reasonable budget — Swift's CooperativeRunloop sleeps
    /// these consistently without overshoot, and the per-poll FFI cost
    /// is well under 1µs.
    private let pollIntervalNanos: UInt64

    public init(pollIntervalNanos: UInt64 = 5_000_000) {
        self.pollIntervalNanos = pollIntervalNanos
        var continuation: AsyncStream<LSPMessage>.Continuation!
        self.messages = AsyncStream(bufferingPolicy: .bufferingNewest(256)) { c in
            continuation = c
        }
        self.messageContinuation = continuation
    }

    /// Spawn the polling loop. Must be called once after init —
    /// LSPClient.startRouting() drives this implicitly via the actor's
    /// own `startRouting()`, but for direct callers (tests, custom
    /// surfaces) the poll loop is opt-in.
    public func startPolling() {
        guard pollTask == nil, !isShutdown else { return }
        let interval = pollIntervalNanos
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let drained = await self.drainOnePoll()
                if !drained {
                    try? await Task.sleep(nanoseconds: interval)
                }
            }
        }
    }

    /// Pull every queued response from the kernel + yield onto the
    /// messages stream. Returns true if at least one message was
    /// drained (skip the sleep; there might be more) or false if the
    /// outbox was empty.
    private func drainOnePoll() async -> Bool {
        var drained = false
        while !isShutdown {
            let json: String
            do {
                json = try lspPollResponseJson()
            } catch {
                Self.log.error("RustLSPTransport poll FFI failed: \(String(describing: error), privacy: .public)")
                return drained
            }
            if json.isEmpty {
                return drained
            }
            drained = true
            // Decode the JSON-RPC envelope into a Swift LSPMessage.
            // The Rust kernel encodes via the same JSON-RPC 2.0 wire
            // format Swift's LSPMessage Codable uses, so a single
            // JSONDecoder roundtrip works.
            let data = Data(json.utf8)
            do {
                let message = try JSONDecoder.lspCanonical.decode(LSPMessage.self, from: data)
                messageContinuation.yield(message)
            } catch {
                Self.log.error("RustLSPTransport could not decode FFI response: \(String(describing: error), privacy: .public); raw=\(json, privacy: .public)")
            }
        }
        return drained
    }

    // MARK: - LSPTransport methods

    public func send(_ message: LSPMessage) async throws {
        try checkNotShutdown()
        let body = try JSONEncoder.lspCanonical.encode(message)
        guard let json = String(data: body, encoding: .utf8) else {
            throw RustLSPTransportError.encodingFailed
        }
        do {
            _ = try lspSendMessageJson(envelopeJson: json)
        } catch {
            throw RustLSPTransportError.ffiCallFailed(detail: String(describing: error))
        }
        // Drain immediately so the response (which the kernel queues
        // synchronously inside send for any request) shows up on the
        // messages stream without waiting for the next poll tick.
        // Notifications don't queue a response so this is a cheap
        // no-op for them.
        _ = await drainOnePoll()
    }

    public func shutdown() async {
        guard !isShutdown else { return }
        isShutdown = true
        pollTask?.cancel()
        pollTask = nil
        // Drain any final queued messages so the consumer sees them
        // before the stream finishes.
        _ = await drainOnePoll()
        messageContinuation.finish()
    }

    /// Diagnostic — current LSP kernel lifecycle state per the FFI.
    /// Used by Settings → Diagnostics + by tests asserting lifecycle
    /// ordering.
    public nonisolated func lifecycleStateDebug() -> String {
        lspLifecycleStateDebug()
    }

    // MARK: - Private

    private func checkNotShutdown() throws {
        if isShutdown {
            throw RustLSPTransportError.transportShutdown
        }
    }
}

/// Errors specific to the Rust-backed LSP transport. Maps the FFI's
/// failure modes onto a Swift-side enum so callers can pattern-match
/// without dynamic casts.
nonisolated public enum RustLSPTransportError: Error, CustomStringConvertible {
    case transportShutdown
    case encodingFailed
    case ffiCallFailed(detail: String)

    public var description: String {
        switch self {
        case .transportShutdown:
            return "RustLSPTransport: transport already shutdown"
        case .encodingFailed:
            return "RustLSPTransport: could not encode LSPMessage to JSON"
        case let .ffiCallFailed(detail):
            return "RustLSPTransport: FFI call failed — \(detail)"
        }
    }
}

#else

// Stub implementation for tests / builds that don't link agent_coreFFI.
// Mirrors the public API so callers can `#if canImport(agent_coreFFI)`
// at most one level higher (or rely on this empty stub returning
// shutdown errors).

public actor RustLSPTransport: LSPTransport {
    public nonisolated let messages: AsyncStream<LSPMessage>
    private let messageContinuation: AsyncStream<LSPMessage>.Continuation

    public init(pollIntervalNanos: UInt64 = 5_000_000) {
        var continuation: AsyncStream<LSPMessage>.Continuation!
        self.messages = AsyncStream(bufferingPolicy: .bufferingNewest(256)) { c in
            continuation = c
        }
        self.messageContinuation = continuation
        _ = pollIntervalNanos
    }

    public func startPolling() {}

    public func send(_ message: LSPMessage) async throws {
        _ = message
        throw RustLSPTransportError.ffiCallFailed(detail: "agent_coreFFI not linked")
    }

    public func shutdown() async {
        messageContinuation.finish()
    }

    public nonisolated func lifecycleStateDebug() -> String {
        "ffi_unavailable"
    }
}

nonisolated public enum RustLSPTransportError: Error, CustomStringConvertible {
    case transportShutdown
    case encodingFailed
    case ffiCallFailed(detail: String)

    public var description: String {
        switch self {
        case .transportShutdown:
            return "RustLSPTransport: transport already shutdown"
        case .encodingFailed:
            return "RustLSPTransport: could not encode LSPMessage to JSON"
        case let .ffiCallFailed(detail):
            return "RustLSPTransport: FFI call failed — \(detail)"
        }
    }
}

#endif
