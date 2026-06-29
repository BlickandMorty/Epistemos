import Foundation
import Network
import os
import Security

// W-R3 transport (2026-06-24): the loopback `/mcp` HTTP server that BINDS OpenCode's `epistemos-native`
// remote-MCP registration (W-R2, written by `WorkOpenCodeRuntime.mergedOpenCodeConfigJSON`) to
// `WorkToolMCPCore` (the in-app bridge that exposes the FULL native Epistemos tool set — owner requirement
// W-R3 "every native tool expressed to OpenCode").
//
// This is the missing seam between two pieces that already exist:
//   - W-R2 config:  mcp["epistemos-native"] = {type:remote, url:"http://127.0.0.1:<port>/mcp",
//                   headers:{Authorization:"Bearer <token>"}}
//   - W-R3 core:    WorkToolMCPCore.handle(requestJSON:)  (initialize / tools/list / tools/call)
// This server is what listens on that URL, authenticates the bearer, and feeds request bodies to the core.
//
// SECURITY / CANON: loopback-ONLY bind (`requiredInterfaceType = .loopback` — never a routable interface),
// per-launch random bearer token (regenerated each construction; never persisted), and an Origin allowlist
// (defense-in-depth for any browser-originated request; non-browser clients like OpenCode/Bun send no Origin
// and are allowed). Mirrors the proven in-repo `LocalModelServer` Network.framework pattern (loopback
// NWListener + minimal HTTP/1.1 parser); the security/routing/framing logic lives in PURE static helpers so
// it is unit-testable without a socket.
//
// The loopback socket path is exercised by WorkNativeMCPServerTests. The remaining owner-run proof is the live
// OpenCode client handshake (`tools/list`/`tools/call`) against this registered endpoint during a real Work send.
nonisolated final class WorkNativeMCPServer: @unchecked Sendable {
    enum Status: Equatable, Sendable {
        case idle
        case starting
        /// Live; carries the registration the OpenCode-config writer consumes (url + bearer token).
        case running(WorkNativeMCPRegistration)
        case failed(String)
        case stopped
    }

    /// The pure security+routing decision for one request (no network — fully testable).
    enum RouteOutcome: Equatable, Sendable {
        case unauthorized
        case notFound
        case methodNotAllowed
        case dispatch
    }

    /// The single MCP endpoint path. The W-R2 config URL ends in this.
    static let mcpPath = "/mcp"

    private static let logger = Logger(subsystem: "com.epistemos.server", category: "WorkNativeMCPServer")
    private static let maxRequestBytes = 8 * 1024 * 1024 // 8 MB cap on a single request

    private let core: WorkToolMCPCore
    private let token: String
    /// MCP Streamable HTTP session id — assigned once per server instance, returned on responses as
    /// `Mcp-Session-Id` so the OpenCode client binds the session (the spec assigns it on `initialize`; returning it
    /// on every dispatch response is tolerated and simplest for a single-session tool server).
    private let sessionID = WorkNativeMCPServer.randomToken()
    private let queue = DispatchQueue(label: "com.epistemos.worknativemcp", qos: .userInitiated)
    private var listener: NWListener?

    private let statusLock = NSLock()
    private var _status: Status = .idle

    /// Thread-safe current status; `.running` exposes the registration to feed `mergedOpenCodeConfigJSON`.
    var status: Status { statusLock.withLock { _status } }
    private func setStatus(_ newValue: Status) { statusLock.withLock { _status = newValue } }

    init(
        executor: @escaping LocalAgentToolExecutor,
        distribution: ToolSurfacePolicy.Distribution = .currentBuild,
        nativeToolVaultPath: String? = nil,
        appContextStore: WorkAppContextStore? = nil,
        token: String = WorkNativeMCPServer.randomToken()
    ) {
        let appContextProvider: (@Sendable () -> WorkAppContextSnapshot?)?
        if let appContextStore {
            appContextProvider = { @Sendable in appContextStore.snapshot }
        } else {
            appContextProvider = nil
        }
        self.core = WorkToolMCPCore(
            executor: executor,
            distribution: distribution,
            nativeToolVaultPath: nativeToolVaultPath,
            appContextProvider: appContextProvider
        )
        self.token = token
    }

    // MARK: - Lifecycle

    /// Bind an ephemeral loopback port and begin serving. Idempotent: a no-op if already listening.
    func start() throws {
        guard listener == nil else { return }
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback // never a routable interface
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params) // `on: .any` → ephemeral port
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                if let port = listener.port?.rawValue {
                    let registration = WorkNativeMCPRegistration(
                        url: "http://127.0.0.1:\(port)\(Self.mcpPath)",
                        token: self.token)
                    self.setStatus(.running(registration))
                    Self.logger.info("WorkNativeMCPServer ready on 127.0.0.1:\(port, privacy: .public)\(Self.mcpPath, privacy: .public)")
                } else {
                    self.setStatus(.failed("listener ready but no bound port"))
                }
            case .failed(let error):
                Self.logger.error("listener failed: \(error.localizedDescription, privacy: .public)")
                self.setStatus(.failed(error.localizedDescription))
            case .cancelled:
                self.setStatus(.stopped)
            default:
                break
            }
        }
        setStatus(.starting)
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
        setStatus(.stopped)
    }

    // MARK: - Connection handling (mirrors LocalModelServer)

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, accumulated: Data())
    }

    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                Self.logger.debug("receive error: \(error.localizedDescription, privacy: .public)")
                connection.cancel()
                return
            }
            var buffer = accumulated
            if let data { buffer.append(data) }

            if buffer.count > Self.maxRequestBytes {
                self.respond(connection, Self.httpResponse(status: 413, json: #"{"error":"request too large"}"#))
                return
            }

            switch WorkMCPHTTPRequest.parse(buffer, maxContentLength: Self.maxRequestBytes) {
            case .needMore:
                if isComplete {
                    connection.cancel()
                } else {
                    self.receive(connection, accumulated: buffer)
                }
            case .tooLarge:
                self.respond(connection, Self.httpResponse(status: 413, json: #"{"error":"request too large"}"#))
            case .invalid:
                self.respond(connection, Self.httpResponse(status: 400, json: #"{"error":"bad request"}"#))
            case .complete(let request):
                self.handle(request, on: connection)
            }
        }
    }

    private func handle(_ request: WorkMCPHTTPRequest, on connection: NWConnection) {
        switch Self.routeOutcome(method: request.method, path: request.path, headers: request.headers, token: token) {
        case .unauthorized:
            respond(connection, Self.httpResponse(status: 401, json: #"{"error":"unauthorized"}"#))
        case .notFound:
            respond(connection, Self.httpResponse(status: 404, json: #"{"error":"not found"}"#))
        case .methodNotAllowed:
            respond(connection, Self.httpResponse(status: 405, json: #"{"error":"method not allowed"}"#))
        case .dispatch:
            let requestJSON = String(data: request.body, encoding: .utf8) ?? "{}"
            // MCP Streamable HTTP: a JSON-RPC NOTIFICATION (has `method`, no `id` — e.g. `notifications/initialized`)
            // expects 202 Accepted with NO body, not a JSON-RPC response. Dispatching it to the core would return an
            // error envelope and break the handshake.
            if Self.isNotification(requestJSON: requestJSON) {
                respond(connection, Self.acceptedResponse(sessionID: sessionID))
                return
            }
            Task { [weak self] in
                guard let self else { return }
                let responseJSON = await self.core.handle(requestJSON: requestJSON)
                self.respond(connection, Self.httpResponse(status: 200, json: responseJSON, sessionID: self.sessionID))
            }
        }
    }

    private func respond(_ connection: NWConnection, _ data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
    }

    // MARK: - Pure, testable helpers (security + routing + framing)

    /// The full security + routing decision for one request. Order: path → method → origin+auth.
    static func routeOutcome(method: String, path: String, headers: [String: String], token: String) -> RouteOutcome {
        let normalizedPath = path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? path
        guard normalizedPath == mcpPath else { return .notFound }
        guard method.uppercased() == "POST" else { return .methodNotAllowed }
        guard isAllowedOrigin(headers: headers), isAuthorized(headers: headers, token: token) else {
            return .unauthorized
        }
        return .dispatch
    }

    /// Extract the bearer token from an `Authorization: Bearer <token>` header (case-insensitive scheme).
    static func bearerToken(from headers: [String: String]) -> String? {
        guard let value = headers["authorization"] else { return nil }
        let parts = value.split(separator: " ", maxSplits: 1)
        guard parts.count == 2, parts[0].lowercased() == "bearer" else { return nil }
        let token = parts[1].trimmingCharacters(in: .whitespaces)
        return token.isEmpty ? nil : token
    }

    static func isAuthorized(headers: [String: String], token: String) -> Bool {
        guard !token.isEmpty, let presented = bearerToken(from: headers) else { return false }
        return constantTimeEquals(presented, token)
    }

    /// Non-browser clients (OpenCode/Bun) send no Origin → allow. A browser-set Origin must be loopback.
    static func isAllowedOrigin(headers: [String: String]) -> Bool {
        guard let origin = headers["origin"], !origin.isEmpty else { return true }  // non-browser client → no Origin
        // Parse the Origin's HOST and EXACT-match loopback. A substring check would wrongly allow
        // `http://127.0.0.1.evil.com` / `http://localhost.evil.com` (DNS-rebinding-style host spoof). Fail
        // closed on an unparseable Origin. (Defense-in-depth; the per-launch bearer token is the primary gate.)
        guard let components = URLComponents(string: origin),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host?.lowercased() else {
            return false
        }
        return host == "127.0.0.1" || host == "localhost" || host == "::1" || host == "[::1]"
    }

    /// Length-checked, branch-flat comparison so token verification doesn't leak length/prefix via timing.
    static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let lhsBytes = Array(lhs.utf8)
        let rhsBytes = Array(rhs.utf8)
        guard lhsBytes.count == rhsBytes.count else { return false }
        var difference: UInt8 = 0
        for index in lhsBytes.indices {
            difference |= lhsBytes[index] ^ rhsBytes[index]
        }
        return difference == 0
    }

    /// Frame a complete HTTP/1.1 response (Connection: close) around a JSON body.
    static func httpResponse(status: Int, json: String, sessionID: String? = nil) -> Data {
        let body = Data(json.utf8)
        var header = "HTTP/1.1 \(status) \(reason(status))\r\n"
        header += "Content-Type: application/json\r\n"
        header += "Cache-Control: no-store\r\n"
        if status == 405 { header += "Allow: POST\r\n" }
        if let sessionID { header += "Mcp-Session-Id: \(sessionID)\r\n" }
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n\r\n"
        var data = Data(header.utf8)
        data.append(body)
        return data
    }

    /// 202 Accepted with NO body — the MCP Streamable HTTP reply to a JSON-RPC notification.
    static func acceptedResponse(sessionID: String? = nil) -> Data {
        var header = "HTTP/1.1 202 Accepted\r\n"
        header += "Cache-Control: no-store\r\n"
        if let sessionID { header += "Mcp-Session-Id: \(sessionID)\r\n" }
        header += "Content-Length: 0\r\n"
        header += "Connection: close\r\n\r\n"
        return Data(header.utf8)
    }

    /// True iff `requestJSON` is a JSON-RPC notification: a `method` present with NO `id` (per JSON-RPC 2.0,
    /// notifications carry no id and MUST NOT be answered with a response object).
    static func isNotification(requestJSON: String) -> Bool {
        guard let data = requestJSON.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return obj["method"] != nil && obj["id"] == nil
    }

    static func reason(_ status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 413: return "Payload Too Large"
        default: return "Status"
        }
    }

    static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        // SAFETY: fixed-size buffer sized to `bytes.count`; SecRandomCopyBytes fills exactly that many bytes.
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess {
            return Data(bytes).base64EncodedString()
        }
        // Fallback to UUID entropy if the RNG is somehow unavailable.
        return (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
    }
}

// MARK: - Minimal HTTP/1.1 request parser

// `nonisolated` so the pure parser is callable from the NWConnection receive queue (a nonisolated context),
// matching `LocalModelServer.HTTPRequest` (which is private to that file, hence this dedicated copy). All
// fields are `let` value types → Sendable + Equatable.
nonisolated struct WorkMCPHTTPRequest: Equatable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    enum ParseResult: Equatable {
        case needMore
        case tooLarge
        case invalid
        case complete(WorkMCPHTTPRequest)
    }

    /// Parse a buffer into a complete request, or report that more bytes are needed (headers not terminated
    /// yet, or body shorter than Content-Length).
    static func parse(_ buffer: Data, maxContentLength: Int? = nil) -> ParseResult {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = buffer.range(of: separator) else { return .needMore }
        let headerData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return .invalid }

        var lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return .invalid }
        lines.removeFirst()
        let requestParts = requestLine.split(separator: " ")
        guard requestParts.count >= 2 else { return .invalid }
        let method = String(requestParts[0])
        let rawPath = String(requestParts[1])
        let path = rawPath.split(separator: "?", maxSplits: 1).first.map(String.init) ?? rawPath

        var headers: [String: String] = [:]
        var sawContentLength = false
        for line in lines where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if key == "content-length" {
                if sawContentLength { return .invalid }
                sawContentLength = true
            }
            headers[key] = value
        }

        let contentLength: Int
        if let rawContentLength = headers["content-length"] {
            guard let parsed = Int(rawContentLength), parsed >= 0 else { return .invalid }
            if let maxContentLength, parsed > maxContentLength { return .tooLarge }
            contentLength = parsed
        } else {
            contentLength = 0
        }
        let bodyStart = range.upperBound
        let available = buffer.distance(from: bodyStart, to: buffer.endIndex)
        if available < contentLength { return .needMore }
        let body = contentLength > 0
            ? buffer.subdata(in: bodyStart..<buffer.index(bodyStart, offsetBy: contentLength))
            : Data()

        return .complete(WorkMCPHTTPRequest(method: method, path: path, headers: headers, body: body))
    }
}
