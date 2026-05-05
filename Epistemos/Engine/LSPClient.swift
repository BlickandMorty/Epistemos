import Foundation
import OSLog

// MARK: - LSPClient
//
// Wave 9.8 follow-up of the Extended Program Plan
// (cross-ref `epistemos_code_verdict.md` §3 "Intelligence" layer:
//  SourceKit-LSP / clangd is the actual truth about the code).
//
// The high-level JSON-RPC 2.0 client that sits on top of the W9.8
// transport (`LSPServerProcess`). Implements just the subset the
// editor actually needs today:
//
//   - initialize / initialized handshake
//   - textDocument/didOpen / didClose / didChange (notifications)
//   - textDocument/hover (request)
//   - textDocument/definition (request)
//   - shutdown / exit
//
// Server-pushed notifications (e.g. textDocument/publishDiagnostics)
// surface through `notifications: AsyncStream<LSPMessage>`. The
// consumer iterates that stream to receive diagnostics without a
// delegate protocol.
//
// Per the V1 budget the W9.8 client is request-id matched + cooperative
// — no separate dispatch worker, no compression, no tracing. The Rust
// indexer (W9.7) is the heavy-lifting layer; this client exists to
// surface symbol semantics into the live editor.

// MARK: - Errors

nonisolated public enum LSPClientError: Error, CustomStringConvertible {
    /// The server returned a JSON-RPC error envelope.
    case serverError(LSPError)
    /// The server returned a response we couldn't parse.
    case decodeFailed(detail: String)
    /// The transport finished before our request received a response.
    case transportClosed
    /// The client called a method that requires `initialize()` first.
    case notInitialized
    /// initialize() was called more than once.
    case alreadyInitialized

    public var description: String {
        switch self {
        case let .serverError(error):
            return "LSPClient: server error code=\(error.code) message=\(error.message)"
        case let .decodeFailed(detail):
            return "LSPClient: decode failed — \(detail)"
        case .transportClosed:
            return "LSPClient: transport finished before response arrived"
        case .notInitialized:
            return "LSPClient: initialize() must complete before this call"
        case .alreadyInitialized:
            return "LSPClient: initialize() already called"
        }
    }
}

// MARK: - Request / response payloads (typed subset)

/// Minimal `InitializeResult`: we only care about the capabilities
/// blob today. Round-tripped as `LSPJSONValue` so we don't have to
/// pin the entire LSP `ServerCapabilities` schema.
nonisolated public struct LSPInitializeResult: Sendable, Equatable {
    public let capabilities: LSPJSONValue
}

/// Position in a text document. Zero-based per the LSP spec.
nonisolated public struct LSPPosition: Codable, Sendable, Hashable {
    public let line: Int
    public let character: Int
    public init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }
}

/// Range in a text document.
nonisolated public struct LSPRange: Codable, Sendable, Hashable {
    public let start: LSPPosition
    public let end: LSPPosition
    public init(start: LSPPosition, end: LSPPosition) {
        self.start = start
        self.end = end
    }
}

/// A textDocument/hover response.
///
/// LSP's `Hover.contents` can be a `MarkupContent`, a `MarkedString`,
/// or an array of either. We coerce to a single rendered string +
/// optional range so the editor's tooltip UI doesn't have to know LSP.
nonisolated public struct LSPHoverResult: Sendable, Equatable {
    public let contents: String
    public let range: LSPRange?
    public init(contents: String, range: LSPRange? = nil) {
        self.contents = contents
        self.range = range
    }
}

/// One textDocument/definition location.
nonisolated public struct LSPLocation: Codable, Sendable, Hashable {
    public let uri: String
    public let range: LSPRange
    public init(uri: String, range: LSPRange) {
        self.uri = uri
        self.range = range
    }
}

// MARK: - Client actor

/// JSON-RPC 2.0 client over an `LSPTransport`. Owns the request id
/// counter + pending response continuations. Server-pushed
/// notifications fan out via `notifications: AsyncStream<LSPMessage>`.
///
/// **V2.3 (2026-05-05) refactor:** the client previously held a
/// concrete `LSPServerProcess`; it now holds `any LSPTransport` so
/// the future tower-lsp Rust transport can drop in without touching
/// LSPClient. The `process` accessor stays for backward compat —
/// callers that constructed against `LSPServerProcess` still get
/// the same interface.
public actor LSPClient {

    /// The underlying transport. May be `LSPServerProcess` (subprocess
    /// transport — production today) or `InProcessLSPTransport` (Swift
    /// stub) or a future Rust-backed transport.
    public let transport: any LSPTransport
    private let log = Logger(subsystem: "com.epistemos", category: "LSPClient")

    private var nextRequestId: Int = 1
    private var pending: [Int: CheckedContinuation<LSPMessage, Error>] = [:]
    private var initialized = false

    /// Async stream of every server-pushed notification — diagnostics,
    /// progress, log messages. Cold; iterate to receive.
    public nonisolated let notifications: AsyncStream<LSPMessage>
    private let notificationContinuation: AsyncStream<LSPMessage>.Continuation

    /// Backward-compatible accessor. Callers that need the concrete
    /// `LSPServerProcess` (e.g. to call `launch()`) can downcast.
    /// New code should use `transport` directly.
    public var process: LSPServerProcess? {
        transport as? LSPServerProcess
    }

    public init(transport: any LSPTransport) {
        self.transport = transport
        var continuation: AsyncStream<LSPMessage>.Continuation!
        self.notifications = AsyncStream(bufferingPolicy: .bufferingNewest(256)) { c in
            continuation = c
        }
        self.notificationContinuation = continuation
    }

    /// Backward-compatible convenience init — preserves the pre-V2.3
    /// `LSPClient(process: ...)` call site shape so existing callers +
    /// tests don't have to change.
    public init(process: LSPServerProcess) {
        self.init(transport: process)
    }

    /// Spawn the message-routing loop. Call exactly once after the
    /// transport is launched (so `transport.messages` actually produces).
    public func startRouting() {
        let stream = transport.messages
        Task {
            for await msg in stream {
                self.routeIncoming(msg)
            }
            // Transport finished — fail every pending request so the
            // caller doesn't hang forever.
            self.failAllPending(.transportClosed)
            self.notificationContinuation.finish()
        }
    }

    private func routeIncoming(_ msg: LSPMessage) {
        switch msg {
        case .responseSuccess(let id, _),
             .responseError(let id?, _):
            guard case .int(let intId) = id, let cont = pending.removeValue(forKey: intId) else {
                // Response for an id we don't know about — drop quietly.
                // String ids aren't in our request space (we always
                // send int ids).
                return
            }
            cont.resume(returning: msg)
        case .responseError(nil, let error):
            log.warning("LSP server returned error response without id: \(error.message, privacy: .public)")
        case .request:
            // Server requests are rare for SourceKit-LSP / clangd
            // (workspace/configuration etc.). For now surface them
            // through the notifications stream so the host can decide
            // whether to respond. Future: ack with `MethodNotFound`
            // automatically.
            notificationContinuation.yield(msg)
        case .notification:
            notificationContinuation.yield(msg)
        }
    }

    private func failAllPending(_ error: LSPClientError) {
        for (_, cont) in pending {
            cont.resume(throwing: error)
        }
        pending.removeAll()
    }

    private func mintRequestId() -> Int {
        defer { nextRequestId += 1 }
        return nextRequestId
    }

    // MARK: - Request envelope

    /// Send a typed request, wait for the matching response.
    ///
    /// Order of operations matters under Swift Concurrency: we have to
    /// (a) install the pending continuation BEFORE the server can see
    /// the request (otherwise an immediate response races and the
    /// router drops it), and (b) we can't `await` inside the
    /// `withCheckedThrowingContinuation` closure. Solution: park the
    /// continuation in `pending` synchronously, then `await` the
    /// transport send. If send fails, pull the pending entry out and
    /// resume it with the same error so this method returns the
    /// canonical send error rather than dangling forever.
    private func request(method: String, params: LSPJSONValue?) async throws -> LSPJSONValue {
        let id = mintRequestId()
        let msg = LSPMessage.request(id: .int(id), method: method, params: params)
        let response: LSPMessage = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<LSPMessage, Error>) in
            pending[id] = cont
            // Spawn the send into a new task so we don't deadlock
            // ourselves on the actor queue waiting for our own send to
            // finish — the actor is single-threaded, but `process.send`
            // hops to the transport actor which is independent.
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.transport.send(msg)
                } catch {
                    await self.failPending(id: id, error: error)
                }
            }
        }
        switch response {
        case .responseSuccess(_, let result):
            return result
        case .responseError(_, let error):
            throw LSPClientError.serverError(error)
        default:
            throw LSPClientError.decodeFailed(detail: "unexpected envelope kind for response: \(response)")
        }
    }

    /// Pull a pending continuation out + fail it with the given error.
    /// Used by the request-side spawn when transport send throws.
    private func failPending(id: Int, error: Error) {
        if let cont = pending.removeValue(forKey: id) {
            cont.resume(throwing: error)
        }
    }

    /// Send a fire-and-forget notification.
    private func notify(method: String, params: LSPJSONValue?) async throws {
        try await transport.send(.notification(method: method, params: params))
    }

    // MARK: - High-level RPCs

    /// initialize / initialized handshake. The server must process the
    /// initialize request before any other request; LSP is strict.
    public func initialize(workspaceRoot: URL? = nil) async throws -> LSPInitializeResult {
        if initialized {
            throw LSPClientError.alreadyInitialized
        }
        var params: [String: LSPJSONValue] = [:]
        params["processId"] = .int(Int(ProcessInfo.processInfo.processIdentifier))
        params["clientInfo"] = .object([
            "name": .string("Epistemos"),
            "version": .string("1.0"),
        ])
        params["capabilities"] = .object([
            "textDocument": .object([
                "hover": .object(["contentFormat": .array([.string("markdown"), .string("plaintext")])]),
                "definition": .object(["linkSupport": .bool(false)]),
                "synchronization": .object([
                    "didSave": .bool(false),
                    "willSave": .bool(false),
                    "dynamicRegistration": .bool(false),
                ]),
                "publishDiagnostics": .object(["versionSupport": .bool(true)]),
            ]),
            "workspace": .object([
                "configuration": .bool(false),
                "didChangeConfiguration": .object(["dynamicRegistration": .bool(false)]),
            ]),
        ])
        if let workspaceRoot {
            params["rootUri"] = .string(workspaceRoot.absoluteString)
        } else {
            params["rootUri"] = .null
        }

        let result = try await request(method: "initialize", params: .object(params))

        // Per the LSP spec, the client MUST send `initialized` as a
        // notification once it has processed the initialize result.
        try await notify(method: "initialized", params: .object([:]))
        initialized = true

        guard case .object(let dict) = result, let capabilities = dict["capabilities"] else {
            throw LSPClientError.decodeFailed(detail: "initialize result missing capabilities")
        }
        return LSPInitializeResult(capabilities: capabilities)
    }

    public func didOpen(uri: URL, languageId: String, version: Int, text: String) async throws {
        try requireInitialized()
        let params: LSPJSONValue = .object([
            "textDocument": .object([
                "uri": .string(uri.absoluteString),
                "languageId": .string(languageId),
                "version": .int(version),
                "text": .string(text),
            ]),
        ])
        try await notify(method: "textDocument/didOpen", params: params)
    }

    public func didChange(uri: URL, version: Int, fullText: String) async throws {
        try requireInitialized()
        // Full-text didChange is the simplest contentChanges shape.
        // Incremental updates via Range are a future commit once the
        // editor tracks edit deltas.
        let params: LSPJSONValue = .object([
            "textDocument": .object([
                "uri": .string(uri.absoluteString),
                "version": .int(version),
            ]),
            "contentChanges": .array([
                .object([
                    "text": .string(fullText),
                ]),
            ]),
        ])
        try await notify(method: "textDocument/didChange", params: params)
    }

    public func didClose(uri: URL) async throws {
        try requireInitialized()
        let params: LSPJSONValue = .object([
            "textDocument": .object([
                "uri": .string(uri.absoluteString),
            ]),
        ])
        try await notify(method: "textDocument/didClose", params: params)
    }

    public func hover(uri: URL, line: Int, character: Int) async throws -> LSPHoverResult? {
        try requireInitialized()
        let params: LSPJSONValue = .object([
            "textDocument": .object(["uri": .string(uri.absoluteString)]),
            "position": .object([
                "line": .int(line),
                "character": .int(character),
            ]),
        ])
        let result = try await request(method: "textDocument/hover", params: params)
        return Self.parseHover(result)
    }

    public func definition(uri: URL, line: Int, character: Int) async throws -> [LSPLocation] {
        try requireInitialized()
        let params: LSPJSONValue = .object([
            "textDocument": .object(["uri": .string(uri.absoluteString)]),
            "position": .object([
                "line": .int(line),
                "character": .int(character),
            ]),
        ])
        let result = try await request(method: "textDocument/definition", params: params)
        return Self.parseDefinition(result)
    }

    public func shutdownAndExit() async throws {
        // Per LSP: shutdown is a request (server replies null); exit
        // is a notification (no reply). The server should terminate
        // its own process after exit.
        _ = try? await request(method: "shutdown", params: nil)
        try? await notify(method: "exit", params: nil)
        await transport.shutdown()
        notificationContinuation.finish()
    }

    private func requireInitialized() throws {
        if !initialized { throw LSPClientError.notInitialized }
    }

    // MARK: - Response parsers

    /// Coerce LSP's `Hover.contents` (MarkupContent | MarkedString |
    /// MarkedString[]) into a single rendered string. Defensive against
    /// every spec-allowed shape.
    static func parseHover(_ value: LSPJSONValue) -> LSPHoverResult? {
        guard case .object(let dict) = value else { return nil }
        guard let contentsValue = dict["contents"] else { return nil }

        let rendered: String
        switch contentsValue {
        case .string(let s):
            rendered = s
        case .object(let inner):
            // MarkupContent — { kind: "markdown" | "plaintext", value: String }
            if case .string(let v) = inner["value"] ?? .null { rendered = v }
            // MarkedString — { language: String, value: String }
            else if case .string(let v) = inner["value"] ?? .null { rendered = v }
            else { return nil }
        case .array(let items):
            // MarkedString[] — render line-joined
            var parts: [String] = []
            for item in items {
                switch item {
                case .string(let s): parts.append(s)
                case .object(let inner):
                    if case .string(let v) = inner["value"] ?? .null { parts.append(v) }
                default: continue
                }
            }
            rendered = parts.joined(separator: "\n\n")
        default:
            return nil
        }

        let range: LSPRange?
        if let rangeValue = dict["range"] {
            range = Self.parseRange(rangeValue)
        } else {
            range = nil
        }
        return LSPHoverResult(contents: rendered, range: range)
    }

    /// Coerce a LSP range object → `LSPRange?`.
    static func parseRange(_ value: LSPJSONValue) -> LSPRange? {
        guard case .object(let dict) = value,
              case .object(let startObj) = dict["start"] ?? .null,
              case .int(let startLine) = startObj["line"] ?? .null,
              case .int(let startChar) = startObj["character"] ?? .null,
              case .object(let endObj) = dict["end"] ?? .null,
              case .int(let endLine) = endObj["line"] ?? .null,
              case .int(let endChar) = endObj["character"] ?? .null else {
            return nil
        }
        return LSPRange(
            start: LSPPosition(line: startLine, character: startChar),
            end: LSPPosition(line: endLine, character: endChar)
        )
    }

    /// LSP `Definition` can be `Location | Location[]`. Always return
    /// an array so the caller doesn't have to switch.
    static func parseDefinition(_ value: LSPJSONValue) -> [LSPLocation] {
        switch value {
        case .object:
            if let single = parseLocation(value) { return [single] }
            return []
        case .array(let items):
            return items.compactMap { parseLocation($0) }
        case .null:
            return []
        default:
            return []
        }
    }

    private static func parseLocation(_ value: LSPJSONValue) -> LSPLocation? {
        guard case .object(let dict) = value,
              case .string(let uri) = dict["uri"] ?? .null,
              let rangeValue = dict["range"],
              let range = parseRange(rangeValue) else {
            return nil
        }
        return LSPLocation(uri: uri, range: range)
    }
}
